{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
unit CShellOleDrag;

{
  アプリからのドラッグを開始する部品（OLE の送り側）。
  TCListView / TCTreeView から使う。

  仕組み：
    - ドラッグする項目のデータ（IDataObject）を、エクスプローラーと同じくシェルから取得する。
    - SHDoDragDrop でドラッグを開始する。
      → Esc での取り消し、右ドラッグ、ドラッグ画像はシェルが扱う。
      → ドロップ先（エクスプローラー、デスクトップ、別EXE、アプリ内）が
        コピー／移動・上書き確認などをすべて行う。送り側では何もしない。

  FPC 側の宣言との食い違いを避けるため、OLE のインターフェースと API はここで独自に宣言する。
}

{$mode objfpc}{$H+}

interface

uses
  Windows, SysUtils, Classes, ShlObj, ActiveX, CShellDragDrop;

const
  CDROPEFFECT_NONE = 0;
  CDROPEFFECT_COPY = 1;
  CDROPEFFECT_MOVE = 2;
  CDROPEFFECT_LINK = 4;

// APaths の項目（すべて同じフォルダー内にあること）のドラッグを開始し、ドロップされるまで待つ。
// AUseWindowImage = True なら、ウィンドウ（リストビュー）にドラッグ画像を作らせる。
// 戻り値：ドロップされたら True（ADropEffect にドロップ先が行った動作）、取り消されたら False。
function ShellDoDragDrop(AWnd: HWND; APaths: TStrings; AUseWindowImage: Boolean;
  out ADropEffect: DWORD): Boolean;

implementation

type
  // IDragSourceHelper（独自宣言）
  ICDragSourceHelper = interface(IUnknown)
    ['{DE5BF786-477A-11D2-839D-00C04FD918D0}']
    function InitializeFromBitmap(pshdi: Pointer; const pDataObject: IUnknown): HResult; stdcall;
    function InitializeFromWindow(hwnd: HWND; ppt: PPoint; const pDataObject: IUnknown): HResult; stdcall;
  end;

const
  IID_ICDataObject: TGUID = '{0000010E-0000-0000-C000-000000000046}';
  CLSID_CDragDropHelper: TGUID = '{4657278A-411B-11D2-839A-00C04FD918D0}';
  CDRAGDROP_S_DROP = HRESULT($00040100);

function _ILCreateFromPathW(pszPath: PWideChar): PItemIDList; stdcall;
  external 'shell32.dll' name 'ILCreateFromPathW';
function _ILFindLastID(pidl: PItemIDList): PItemIDList; stdcall;
  external 'shell32.dll' name 'ILFindLastID';
function _SHBindToParent(pidl: PItemIDList; const riid: TGUID; out ppv;
  out ppidlLast: PItemIDList): HRESULT; stdcall;
  external 'shell32.dll' name 'SHBindToParent';
function _SHDoDragDrop(hwnd: HWND; pdata: Pointer; pdsrc: Pointer; dwEffect: DWORD;
  out pdwEffect: DWORD): HRESULT; stdcall;
  external 'shell32.dll' name 'SHDoDragDrop';

// 項目のデータ（IDataObject）をシェルから取得する
function GetShellDataObject(AWnd: HWND; APaths: TStrings): IUnknown;
var
  Full, Children: array of PItemIDList;
  Parent: IShellFolder;
  Last: PItemIDList;
  W: UnicodeString;
  i, n: Integer;
begin
  Result := nil;
  if (APaths = nil) or (APaths.Count = 0) then Exit;
  n := APaths.Count;
  Full := nil;
  Children := nil;
  SetLength(Full, n);
  SetLength(Children, n);
  for i := 0 to n - 1 do
    Full[i] := nil;
  try
    for i := 0 to n - 1 do
    begin
      W := UnicodeString(ExcludeTrailingPathDelimiter(APaths[i]));
      Full[i] := _ILCreateFromPathW(PWideChar(W));
      if Full[i] = nil then Exit;
    end;
    // 先頭の項目の親フォルダーを取得（全項目が同じ親である前提）
    if Failed(_SHBindToParent(Full[0], IID_IShellFolder, Parent, Last)) or (Parent = nil) then Exit;
    Children[0] := Last;
    for i := 1 to n - 1 do
      Children[i] := _ILFindLastID(Full[i]);
    if Failed(Parent.GetUIObjectOf(AWnd, n, Children[0], IID_ICDataObject, nil, Pointer(Result))) then
      Result := nil;
  finally
    for i := 0 to n - 1 do
      if Full[i] <> nil then
        CoTaskMemFree(Full[i]);
  end;
end;

function ShellDoDragDrop(AWnd: HWND; APaths: TStrings; AUseWindowImage: Boolean;
  out ADropEffect: DWORD): Boolean;
var
  Data: IUnknown;
  Helper: ICDragSourceHelper;
  Pt: TPoint;
  HR: HRESULT;
begin
  Result := False;
  ADropEffect := CDROPEFFECT_NONE;

  Data := GetShellDataObject(AWnd, APaths);
  if Data = nil then
  begin
    ShellDragLog('OLE DoDragDrop: data object not available');
    Exit;
  end;

  // ドラッグ画像：リストビューは、選択項目の画像をウィンドウ自身に作らせる。
  // それ以外は SHDoDragDrop が既定の画像を作る。
  if AUseWindowImage then
  begin
    Helper := nil;
    if Succeeded(CoCreateInstance(CLSID_CDragDropHelper, nil, CLSCTX_INPROC_SERVER,
      ICDragSourceHelper, Helper)) and (Helper <> nil) then
    begin
      GetCursorPos(Pt);
      try
        Helper.InitializeFromWindow(AWnd, @Pt, Data);
      except
        // 画像が作れなくてもドラッグは続ける
      end;
    end;
  end;

  // ドラッグを開始する（ドロップ・取り消しまで、ここで待つ）。
  // 送り側の IDropSource は SHDoDragDrop の既定のもの（左右ボタン・Esc を扱う）を使う。
  HR := _SHDoDragDrop(AWnd, Pointer(Data), nil,
    CDROPEFFECT_COPY or CDROPEFFECT_MOVE or CDROPEFFECT_LINK, ADropEffect);
  Result := HR = CDRAGDROP_S_DROP;
  ShellDragLog('OLE DoDragDrop: hr=' + IntToHex(HR, 8) + ' effect=' + IntToStr(ADropEffect) +
    ' count=' + IntToStr(APaths.Count) + ' first=' + APaths[0]);
  // 移動の場合も、元の項目の削除はドロップ先（シェル）が行う。送り側では何もしない。
end;

end.
