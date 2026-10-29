{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
unit CShellOleDrop;

{
  エクスプローラー等（他のアプリ）からのドロップを受け取る部品（OLE の受け側）。
  TCListView / TCTreeView から使う。

  仕組み：
    - コントロールのウィンドウを OLE のドロップ先として登録する（RegisterDragDrop）。
    - マウス位置のドロップ先フォルダー（または ZIP）を、コントロールに問い合わせる。
    - そのフォルダーについてシェルが持つドロップ先（IDropTarget）を取り出し、処理をそのまま転送する。
      → コピー／移動の判定、右ドラッグのメニュー、上書き確認、ZIP への追加は、
        すべてエクスプローラーと同じ動作になる。
    - エクスプローラーのドラッグ画像も表示する（IDropTargetHelper）。

  FPC 側の宣言との食い違いを避けるため、OLE のインターフェースと API はここで独自に宣言する。
}

{$mode objfpc}{$H+}
{$WARN 4055 OFF} // 順序型⇔ポインターの変換（Win32 API の引数のため意図的）

interface

uses
  Windows, SysUtils, Classes, ShlObj, ActiveX, CShellDragDrop;

type
  // マウス位置（スクリーン座標）のドロップ先フォルダー（または ZIP）を返す。ドロップできない場所は ''。
  // コントロールは、この中で強調表示・自動スクロールの開始も行う。
  TOleResolveDropFunc = function(const AScreenPt: TPoint): string of object;
  // ドラッグがコントロールの外に出た・取り消された・ドロップされた（強調表示を消す）
  TOleDropLeaveProc = procedure of object;
  // ドロップされた（実行直前に呼ばれる）
  TOleDroppedProc = procedure(const AFolder: string) of object;

  // IDropTarget（独自宣言。GUID は Windows と同じ）
  ICDropTarget = interface(IUnknown)
    ['{00000122-0000-0000-C000-000000000046}']
    function DragEnter(const dataObj: IUnknown; grfKeyState: DWORD; pt: TPoint;
      var dwEffect: DWORD): HResult; stdcall;
    function DragOver(grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
    function DragLeave: HResult; stdcall;
    function Drop(const dataObj: IUnknown; grfKeyState: DWORD; pt: TPoint;
      var dwEffect: DWORD): HResult; stdcall;
  end;

  { TCShellOleDropTarget }

  TCShellOleDropTarget = class(TInterfacedObject, ICDropTarget)
  private
    FWnd: HWND;
    FOnResolve: TOleResolveDropFunc;
    FOnLeave: TOleDropLeaveProc;
    FOnDropped: TOleDroppedProc;
    FData: IUnknown;            // ドラッグ中のデータ（IDataObject）
    FShellTarget: ICDropTarget; // 現在のドロップ先フォルダーについてのシェルのドロップ先
    FShellFolder: string;       // FShellTarget のフォルダー
    FHelper: IUnknown;          // IDropTargetHelper（ドラッグ画像の表示）
    procedure SwitchTarget(const AFolder: string; grfKeyState: DWORD; pt: TPoint;
      var dwEffect: DWORD);
    procedure ReleaseShellTarget;
  public
    constructor Create(AWnd: HWND; AOnResolve: TOleResolveDropFunc;
      AOnLeave: TOleDropLeaveProc; AOnDropped: TOleDroppedProc);
    // コントロール側の破棄・ハンドル破棄時に呼ぶ（以後、コントロールのメソッドを呼ばない）
    procedure Detach;
    // ICDropTarget
    function DragEnter(const dataObj: IUnknown; grfKeyState: DWORD; pt: TPoint;
      var dwEffect: DWORD): HResult; stdcall;
    function DragOver(grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
    function DragLeave: HResult; stdcall;
    function Drop(const dataObj: IUnknown; grfKeyState: DWORD; pt: TPoint;
      var dwEffect: DWORD): HResult; stdcall;
  end;

// ウィンドウを OLE のドロップ先として登録する。成功時は登録したオブジェクトを返す（失敗時 nil）。
function OleDropRegister(AWnd: HWND; AOnResolve: TOleResolveDropFunc;
  AOnLeave: TOleDropLeaveProc; AOnDropped: TOleDroppedProc): TCShellOleDropTarget;
// 登録を解除する（ATarget は nil になる）
procedure OleDropRevoke(AWnd: HWND; var ATarget: TCShellOleDropTarget);

implementation

type
  // IDropTargetHelper（独自宣言）
  ICDropTargetHelper = interface(IUnknown)
    ['{4657278B-411B-11D2-839A-00C04FD918D0}']
    function DragEnter(hwndTarget: HWND; const pDataObject: IUnknown; var ppt: TPoint;
      dwEffect: DWORD): HResult; stdcall;
    function DragLeave: HResult; stdcall;
    function DragOver(var ppt: TPoint; dwEffect: DWORD): HResult; stdcall;
    function Drop(const pDataObject: IUnknown; var ppt: TPoint; dwEffect: DWORD): HResult; stdcall;
    function Show(fShow: BOOL): HResult; stdcall;
  end;

const
  CLSID_CDragDropHelper: TGUID = '{4657278A-411B-11D2-839A-00C04FD918D0}';
  IID_ICDropTarget: TGUID = '{00000122-0000-0000-C000-000000000046}';
  CDROPEFFECT_NONE = 0;

function _OleInitialize(pvReserved: Pointer): HRESULT; stdcall;
  external 'ole32.dll' name 'OleInitialize';
procedure _OleUninitialize; stdcall;
  external 'ole32.dll' name 'OleUninitialize';
function _RegisterDragDrop(hwnd: HWND; pDropTarget: Pointer): HRESULT; stdcall;
  external 'ole32.dll' name 'RegisterDragDrop';
function _RevokeDragDrop(hwnd: HWND): HRESULT; stdcall;
  external 'ole32.dll' name 'RevokeDragDrop';
function _ILCreateFromPathW(pszPath: PWideChar): PItemIDList; stdcall;
  external 'shell32.dll' name 'ILCreateFromPathW';
function _SHBindToParent(pidl: PItemIDList; const riid: TGUID; out ppv;
  out ppidlLast: PItemIDList): HRESULT; stdcall;
  external 'shell32.dll' name 'SHBindToParent';

var
  GOleInitialized: Boolean = False;

// フォルダー（または ZIP）について、シェルが持つドロップ先を取得する
function GetShellDropTarget(AWnd: HWND; const APath: string): ICDropTarget;
var
  W: UnicodeString;
  PIDL, Last: PItemIDList;
  Parent: IShellFolder;
  P: string;
begin
  Result := nil;
  if APath = '' then Exit;
  P := ExcludeTrailingPathDelimiter(APath);
  if (Length(P) = 2) and (P[2] = ':') then
    P := P + '\'; // "C:" は "C:\" にする
  W := UnicodeString(P);
  PIDL := _ILCreateFromPathW(PWideChar(W));
  if PIDL = nil then Exit;
  try
    if Failed(_SHBindToParent(PIDL, IID_IShellFolder, Parent, Last)) or (Parent = nil) then Exit;
    if Failed(Parent.GetUIObjectOf(AWnd, 1, Last, IID_ICDropTarget, nil, Pointer(Result))) then
      Result := nil;
  finally
    CoTaskMemFree(PIDL);
  end;
end;

{ TCShellOleDropTarget }

constructor TCShellOleDropTarget.Create(AWnd: HWND; AOnResolve: TOleResolveDropFunc;
  AOnLeave: TOleDropLeaveProc; AOnDropped: TOleDroppedProc);
var
  H: ICDropTargetHelper;
begin
  inherited Create;
  FWnd := AWnd;
  FOnResolve := AOnResolve;
  FOnLeave := AOnLeave;
  FOnDropped := AOnDropped;
  // ドラッグ画像の表示用（取得できなくても動作には影響しない）
  H := nil;
  if Succeeded(CoCreateInstance(CLSID_CDragDropHelper, nil, CLSCTX_INPROC_SERVER,
    ICDropTargetHelper, H)) then
    FHelper := H;
end;

procedure TCShellOleDropTarget.Detach;
begin
  FOnResolve := nil;
  FOnLeave := nil;
  FOnDropped := nil;
  ReleaseShellTarget;
  FData := nil;
end;

procedure TCShellOleDropTarget.ReleaseShellTarget;
begin
  if FShellTarget <> nil then
  begin
    try
      FShellTarget.DragLeave;
    except
    end;
    FShellTarget := nil;
  end;
  FShellFolder := '';
end;

procedure TCShellOleDropTarget.SwitchTarget(const AFolder: string; grfKeyState: DWORD;
  pt: TPoint; var dwEffect: DWORD);
var
  Allowed: DWORD;
begin
  Allowed := dwEffect; // ドラッグ元が許可している動作
  if not SameText(AFolder, FShellFolder) then
  begin
    // ドロップ先フォルダーが変わった：前のシェルのドロップ先から離れ、新しいほうに入る
    ReleaseShellTarget;
    if AFolder <> '' then
    begin
      FShellTarget := GetShellDropTarget(FWnd, AFolder);
      FShellFolder := AFolder;
      if FShellTarget <> nil then
      begin
        if Failed(FShellTarget.DragEnter(FData, grfKeyState, pt, dwEffect)) then
          dwEffect := CDROPEFFECT_NONE;
        Exit;
      end;
    end;
    dwEffect := CDROPEFFECT_NONE;
    Exit;
  end;

  // 同じフォルダーの上を移動中
  if FShellTarget <> nil then
  begin
    dwEffect := Allowed;
    if Failed(FShellTarget.DragOver(grfKeyState, pt, dwEffect)) then
      dwEffect := CDROPEFFECT_NONE;
  end
  else
    dwEffect := CDROPEFFECT_NONE;
end;

function TCShellOleDropTarget.DragEnter(const dataObj: IUnknown; grfKeyState: DWORD;
  pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
var
  Folder: string;
  P: TPoint;
  Allowed: DWORD;
begin
  Result := S_OK;
  try
    FData := dataObj;
    Allowed := dwEffect;
    FShellFolder := '';
    FShellTarget := nil;
    if Assigned(FOnResolve) then
      Folder := FOnResolve(pt)
    else
      Folder := '';
    SwitchTarget(Folder, grfKeyState, pt, dwEffect);
    ShellDragLog('OLE DragEnter folder=' + Folder + ' effect=' + IntToStr(dwEffect));
    if FHelper <> nil then
    begin
      P := pt;
      ICDropTargetHelper(FHelper).DragEnter(FWnd, dataObj, P, dwEffect);
    end;
    if Allowed = 0 then dwEffect := CDROPEFFECT_NONE;
  except
    dwEffect := CDROPEFFECT_NONE;
    Result := E_UNEXPECTED;
  end;
end;

function TCShellOleDropTarget.DragOver(grfKeyState: DWORD; pt: TPoint;
  var dwEffect: DWORD): HResult; stdcall;
var
  Folder: string;
  P: TPoint;
begin
  Result := S_OK;
  try
    if Assigned(FOnResolve) then
      Folder := FOnResolve(pt)
    else
      Folder := '';
    SwitchTarget(Folder, grfKeyState, pt, dwEffect);
    if FHelper <> nil then
    begin
      P := pt;
      ICDropTargetHelper(FHelper).DragOver(P, dwEffect);
    end;
  except
    dwEffect := CDROPEFFECT_NONE;
    Result := E_UNEXPECTED;
  end;
end;

function TCShellOleDropTarget.DragLeave: HResult; stdcall;
begin
  Result := S_OK;
  try
    ShellDragLog('OLE DragLeave');
    ReleaseShellTarget;
    if FHelper <> nil then
      ICDropTargetHelper(FHelper).DragLeave;
    FData := nil;
    if Assigned(FOnLeave) then
      FOnLeave;
  except
    Result := E_UNEXPECTED;
  end;
end;

function TCShellOleDropTarget.Drop(const dataObj: IUnknown; grfKeyState: DWORD;
  pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
var
  Folder: string;
  P: TPoint;
  Target: ICDropTarget;
begin
  Result := S_OK;
  try
    if FHelper <> nil then
    begin
      P := pt;
      ICDropTargetHelper(FHelper).Drop(dataObj, P, dwEffect);
    end;

    // 強調表示を消す
    if Assigned(FOnLeave) then
      FOnLeave;

    Folder := FShellFolder;
    Target := FShellTarget;
    FShellTarget := nil; // Drop を渡したら、DragLeave は送らない
    FShellFolder := '';

    if (Target <> nil) and (Folder <> '') then
    begin
      ShellDragLog('OLE Drop folder=' + Folder);
      if Assigned(FOnDropped) then
        FOnDropped(Folder);
      // コピー／移動・右ドラッグのメニュー・ZIP への追加などは、シェルがすべて行う
      Result := Target.Drop(dataObj, grfKeyState, pt, dwEffect);
      ShellDragLog('OLE Drop result=' + IntToStr(Result) + ' effect=' + IntToStr(dwEffect));
    end
    else
      dwEffect := CDROPEFFECT_NONE;
  except
    dwEffect := CDROPEFFECT_NONE;
    Result := E_UNEXPECTED;
  end;
  FData := nil;
end;

// ---------------------------------------------------------------

function OleDropRegister(AWnd: HWND; AOnResolve: TOleResolveDropFunc;
  AOnLeave: TOleDropLeaveProc; AOnDropped: TOleDroppedProc): TCShellOleDropTarget;
var
  Intf: ICDropTarget;
  HR: HRESULT;
begin
  Result := nil;
  if AWnd = 0 then Exit;
  Result := TCShellOleDropTarget.Create(AWnd, AOnResolve, AOnLeave, AOnDropped);
  // 登録中はシステムが参照を持つ。こちらも Result を保持するため、参照を1つ加えておく
  Result._AddRef;
  Intf := Result;
  HR := _RegisterDragDrop(AWnd, Pointer(Intf));
  Intf := nil;
  if Failed(HR) then
  begin
    ShellDragLog('RegisterDragDrop failed hr=' + IntToHex(HR, 8));
    Result.Detach;
    Result._Release;
    Result := nil;
  end;
end;

procedure OleDropRevoke(AWnd: HWND; var ATarget: TCShellOleDropTarget);
begin
  if ATarget = nil then Exit;
  ATarget.Detach;
  if AWnd <> 0 then
    _RevokeDragDrop(AWnd); // システムの参照が外れる
  ATarget._Release;        // OleDropRegister で加えた参照を外す（0 になれば解放される）
  ATarget := nil;
end;

initialization
  // OLE のドロップ受付には OleInitialize が必要（既に初期化済みなら S_FALSE が返る）
  GOleInitialized := Succeeded(_OleInitialize(nil));

finalization
  if GOleInitialized then
    _OleUninitialize;

end.
