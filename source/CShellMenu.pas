{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
unit CShellMenu;

{
  シェルのコマンド実行・右クリックメニュー表示の共通部品。
  TCListView / TCTreeView から使う。

  - ShellInvokeVerbOnItems  : 複数の項目に対してシェルのコマンド（copy / cut / delete 等）を実行
  - ShellInvokeVerbOnFolder : フォルダーに対してシェルのコマンド（paste 等）を実行
  - TrackShellContextMenu   : 右クリックメニューを表示する。
                              「送る」など、開いた時点で中身が作られるサブメニューが
                              正しく表示されるよう、メニュー関連のメッセージをシェルへ転送する。
                              シェルの項目を LCL が TMenuItem と誤って読まないよう、
                              メニュー関連のメッセージは LCL へ渡さない
  - ShellMenuVerb           : 選ばれたメニュー項目のコマンド名（'rename' 等）を取得
  - ExtraMenuInsert / ExtraMenuClick : アプリの TPopupMenu の項目を右クリックメニューへ追加し、
                              選ばれたら その項目の OnClick を呼ぶ
}

{$mode objfpc}{$H+}
{$WARN 4055 OFF} // 順序型⇔ポインターの変換（Win32 API の引数のため意図的）

interface

uses
  Windows, SysUtils, Classes, ShlObj, ActiveX, Menus;

type
  // 右クリックメニューに独自項目を追加する位置
  TCExtraMenuPosition = (empTop, empBottom);

const
  // 独自項目に割り当てるコマンドIDの先頭（シェルの項目 1〜$7FFF と重ならない範囲）
  CEXTRA_MENU_FIRST_ID = $8100;

// APaths の項目（すべて同じフォルダー内にあること）に対して AVerb を実行する。
// AShift = True は Shift キーを押しながら実行した扱い（delete なら完全削除）。
function ShellInvokeVerbOnItems(AWnd: HWND; APaths: TStrings; const AVerb: string;
  AShift: Boolean = False): Boolean;
// フォルダー AFolder に対して AVerb を実行する（paste なら、そのフォルダーの中へ貼り付け）
function ShellInvokeVerbOnFolder(AWnd: HWND; const AFolder, AVerb: string): Boolean;
// 右クリックメニューを表示し、選ばれたコマンドID（0 は未選択）を返す
function TrackShellContextMenu(AWnd: HWND; AMenu: HMENU; ACM: IContextMenu;
  AScreenX, AScreenY: Integer): UINT;
// QueryContextMenu で割り当てたコマンドの相対ID（コマンドID - idCmdFirst）から、コマンド名を得る
function ShellMenuVerb(ACM: IContextMenu; ACmdOffset: UINT): string;
// ファイル名・フォルダー名に使えない文字（\ / : * ? " < > |）が含まれているか
function ContainsInvalidChar(const AText: string): Boolean;
// シェル経由で名前を変更する（エクスプローラーと同じ動作。失敗時はシェルが理由を表示する）。
// ANewName は拡張子を含む新しい名前（フォルダー部分は含まない）
function ShellRenameItem(AWnd: HWND; const APath, ANewName: string): Boolean;
// 260 文字を超えるパスでも Win32 API が扱えるよう、必要なら \\?\ を付けたワイド文字列を返す
function ShellLongPathW(const APath: string): UnicodeString;

// APopup の項目を AMenu（Windows のメニュー）の先頭／末尾へ、区切り線付きで追加する。
// 追加前に APopup.OnPopup を呼ぶ（PopupComponent に AComponent を設定）。
// 追加したコマンド項目は AItems に入る（ExtraMenuClick で使う）。戻り値は追加した項目数。
function ExtraMenuInsert(AMenu: HMENU; APopup: TPopupMenu; APosition: TCExtraMenuPosition;
  AComponent: TComponent; AItems: TList): Integer;
// 選ばれたコマンドIDが独自項目なら、その項目の OnClick を呼んで True を返す
function ExtraMenuClick(AItems: TList; ACmd: UINT): Boolean;

// 右クリックメニューで選ばれたシェルの項目（コマンドの相対ID）を実行する。
// エクスプローラーと同じく、作業フォルダー（ADirectory）を渡す。
// 登録アプリのコマンドの %V（空白部分のメニュー）や、アプリのカレントフォルダーがこのフォルダーになる。
function ShellInvokeMenuCommand(ACM: IContextMenu; AWnd: HWND; ACmdOffset: UINT;
  const ADirectory: string): Boolean;

implementation

uses
  LazUTF8, LCLProc; // LCLProc：ShortCutToText

type
  // FPC 側の宣言有無に依存しないよう、ここで独自に宣言する
  ICShellContextMenu2 = interface(IContextMenu)
    ['{000214F4-0000-0000-C000-000000000046}']
    function HandleMenuMsg(uMsg: UINT; WParam: WPARAM; LParam: LPARAM): HResult; stdcall;
  end;

  ICShellContextMenu3 = interface(ICShellContextMenu2)
    ['{BCFCE0A0-EC17-11D0-8D10-00A0C90F2719}']
    function HandleMenuMsg2(uMsg: UINT; WParam: WPARAM; LParam: LPARAM;
      out plResult: LRESULT): HResult; stdcall;
  end;

const
  CSHGDN_INFOLDER   = $0001;
  CSHGDN_FORPARSING = $8000;
  CCMIC_MASK_SHIFT_DOWN = $10000000;
  CGCS_VERBW = $00000004;
  CGWLP_WNDPROC = -4;

function _ILCreateFromPathW(pszPath: PWideChar): PItemIDList; stdcall;
  external 'shell32.dll' name 'ILCreateFromPathW';
function _SHBindToParent(pidl: PItemIDList; const riid: TGUID; out ppv;
  out ppidlLast: PItemIDList): HRESULT; stdcall;
  external 'shell32.dll' name 'SHBindToParent';
function _ILFindLastID(pidl: PItemIDList): PItemIDList; stdcall;
  external 'shell32.dll' name 'ILFindLastID';
function _CallWindowProcW(lpPrevWndFunc: Pointer; hWnd: HWND; Msg: UINT;
  wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
  external 'user32.dll' name 'CallWindowProcW';
{$ifdef CPU64}
function _SetWindowLongPtrW(hWnd: HWND; nIndex: Integer; dwNewLong: PtrInt): PtrInt; stdcall;
  external 'user32.dll' name 'SetWindowLongPtrW';
{$else}
function _SetWindowLongPtrW(hWnd: HWND; nIndex: Integer; dwNewLong: PtrInt): PtrInt; stdcall;
  external 'user32.dll' name 'SetWindowLongW';
{$endif}

function ContainsInvalidChar(const AText: string): Boolean;
const
  InvalidChars: array[1..9] of Char = ('\', '/', ':', '*', '?', '"', '<', '>', '|');
var
  i: Integer;
begin
  Result := False;
  for i := Low(InvalidChars) to High(InvalidChars) do
    if Pos(InvalidChars[i], AText) > 0 then
      Exit(True);
end;

function ShellLongPathW(const APath: string): UnicodeString;
begin
  Result := UnicodeString(APath);
  // 通常の API は 260 文字（MAX_PATH）未満が前提。余裕を見て 248 文字以上で付ける
  if (Length(Result) >= 248) and (Copy(Result, 1, 4) <> '\\?\') then
  begin
    if Copy(Result, 1, 2) = '\\' then
      Result := '\\?\UNC\' + Copy(Result, 3, MaxInt)   // \\server\share → \\?\UNC\server\share
    else
      Result := '\\?\' + Result;
  end;
end;

function ShellRenameItem(AWnd: HWND; const APath, ANewName: string): Boolean;
var
  W, WName: UnicodeString;
  PIDL, Last, NewPIDL: PItemIDList;
  Parent: IShellFolder;
begin
  Result := False;
  if (APath = '') or (ANewName = '') then Exit;
  W := UnicodeString(ExcludeTrailingPathDelimiter(APath));
  PIDL := _ILCreateFromPathW(PWideChar(W));
  if PIDL = nil then Exit;
  try
    if Failed(_SHBindToParent(PIDL, IID_IShellFolder, Parent, Last)) or (Parent = nil) then Exit;
    WName := UnicodeString(ANewName);
    NewPIDL := nil;
    // FORPARSING：拡張子を含む実際の名前として扱う（拡張子の表示設定に左右されない）
    Result := Succeeded(Parent.SetNameOf(AWnd, Last, PWideChar(WName),
      CSHGDN_INFOLDER or CSHGDN_FORPARSING, NewPIDL));
    if NewPIDL <> nil then
      CoTaskMemFree(NewPIDL);
  finally
    CoTaskMemFree(PIDL);
  end;
end;

// ---------------------------------------------------------------
// コマンド実行
// ---------------------------------------------------------------

function InvokeVerb(ACM: IContextMenu; AWnd: HWND; const AVerb: string;
  AShift: Boolean): Boolean;
var
  Menu: HMENU;
  ICI: TCMInvokeCommandInfo;
  AnsiVerb: AnsiString;
begin
  Result := False;
  if ACM = nil then Exit;
  AnsiVerb := AnsiString(AVerb);

  // コマンド名で実行する前に QueryContextMenu を呼んでおく（呼ばないと動かない実装があるため）
  Menu := CreatePopupMenu;
  if Menu = 0 then Exit;
  try
    if Failed(ACM.QueryContextMenu(Menu, 0, 1, $7FFF, CMF_NORMAL)) then Exit;

    ICI := Default(TCMInvokeCommandInfo);
    ICI.cbSize := SizeOf(ICI);
    ICI.hwnd := AWnd;
    ICI.lpVerb := PAnsiChar(AnsiVerb);
    ICI.nShow := SW_SHOWNORMAL;
    if AShift then
      ICI.fMask := ICI.fMask or CCMIC_MASK_SHIFT_DOWN;
    Result := Succeeded(ACM.InvokeCommand(ICI));
  finally
    DestroyMenu(Menu);
  end;
end;

function ShellInvokeVerbOnItems(AWnd: HWND; APaths: TStrings; const AVerb: string;
  AShift: Boolean): Boolean;
var
  Full, Children: array of PItemIDList;
  Parent: IShellFolder;
  CM: IContextMenu;
  Last: PItemIDList;
  W: UnicodeString;
  i, n: Integer;
begin
  Result := False;
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
      W := UnicodeString(APaths[i]);
      Full[i] := _ILCreateFromPathW(PWideChar(W));
      if Full[i] = nil then Exit;
    end;

    // 先頭の項目の親フォルダーを取得（全項目が同じ親である前提）
    if Failed(_SHBindToParent(Full[0], IID_IShellFolder, Parent, Last)) or (Parent = nil) then Exit;
    Children[0] := Last;
    for i := 1 to n - 1 do
      Children[i] := _ILFindLastID(Full[i]);

    CM := nil;
    if Failed(Parent.GetUIObjectOf(AWnd, n, Children[0], IID_IContextMenu, nil, Pointer(CM))) then Exit;
    Result := InvokeVerb(CM, AWnd, AVerb, AShift);
  finally
    for i := 0 to n - 1 do
      if Full[i] <> nil then
        CoTaskMemFree(Full[i]);
  end;
end;

function ShellInvokeVerbOnFolder(AWnd: HWND; const AFolder, AVerb: string): Boolean;
var
  L: TStringList;
begin
  Result := False;
  if AFolder = '' then Exit;
  L := TStringList.Create;
  try
    // フォルダー自体を項目として扱う（ドライブのルートは「PC」が親になる）
    L.Add(ExcludeTrailingPathDelimiter(AFolder));
    if (Length(L[0]) = 2) and (L[0][2] = ':') then
      L[0] := L[0] + '\'; // "C:" は "C:\" にする
    Result := ShellInvokeVerbOnItems(AWnd, L, AVerb, False);
  finally
    L.Free;
  end;
end;

// ---------------------------------------------------------------
// 右クリックメニュー表示
// ---------------------------------------------------------------

var
  // メニューはモーダルで同時に1つしか表示されないため、ユニット内で保持する
  GMenuCM2: ICShellContextMenu2 = nil;
  GMenuCM3: ICShellContextMenu3 = nil;
  GOldWndProc: PtrInt = 0;

// シェルの右クリックメニューを出している間だけ差し替えるウィンドウ手続き。
//   1. メニュー関連のメッセージ（WM_INITMENUPOPUP・WM_MENUCHAR・メニューの WM_DRAWITEM・WM_MEASUREITEM）は
//      シェルへ渡す（「送る」「新規作成」など、開いたときに中身が作られるサブメニューのため）。
//   2. シェルが処理しなかったメニュー関連のメッセージと WM_MENUSELECT は、LCL の元の手続きへ渡さず
//      Windows の既定の処理（DefWindowProcW）だけを行う。
//      LCL はメニュー項目に付いた値（項目ごとの付加情報）を TMenuItem とみなして読むため、
//      シェルが自分用の値を入れた項目（「新規作成」など）で例外になる。このメニューは LCL の
//      TPopupMenu ではないので、LCL が処理する必要はない。
//   3. ほかのメッセージは元の手続きへ渡す。
function MenuHookProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  R: LRESULT;
  IsMenuMsg: Boolean;
begin
  // WM_MENUSELECT（カーソルが項目に乗った）：LCL へ渡さない（上の 2）
  if uMsg = WM_MENUSELECT then
  begin
    Result := DefWindowProcW(hWnd, uMsg, wParam, lParam);
    Exit;
  end;

  IsMenuMsg := False;
  case uMsg of
    WM_INITMENUPOPUP, WM_MENUCHAR:
      IsMenuMsg := True;
    WM_DRAWITEM:
      IsMenuMsg := (lParam <> 0) and (PDrawItemStruct(lParam)^.CtlType = ODT_MENU);
    WM_MEASUREITEM:
      IsMenuMsg := (lParam <> 0) and (PMeasureItemStruct(lParam)^.CtlType = ODT_MENU);
  end;

  if IsMenuMsg then
  begin
    try
      if GMenuCM3 <> nil then
      begin
        R := 0;
        if Succeeded(GMenuCM3.HandleMenuMsg2(uMsg, wParam, lParam, R)) then
        begin
          Result := R;
          Exit;
        end;
      end
      else if (GMenuCM2 <> nil) and (uMsg <> WM_MENUCHAR) then
      begin
        if Succeeded(GMenuCM2.HandleMenuMsg(uMsg, wParam, lParam)) then
        begin
          if uMsg = WM_INITMENUPOPUP then
            Result := 0
          else
            Result := 1; // WM_DRAWITEM / WM_MEASUREITEM は処理済み（TRUE）を返す
          Exit;
        end;
      end;
    except
      // シェル拡張側の例外でアプリを落とさない
    end;
    // シェルが処理しなかったメニュー関連のメッセージ：LCL へ渡さず、既定の処理だけを行う（上の 2）
    Result := DefWindowProcW(hWnd, uMsg, wParam, lParam);
    Exit;
  end;

  // メニューと関係のないメッセージ：元の手続きへ渡す（上の 3）
  Result := _CallWindowProcW(Pointer(GOldWndProc), hWnd, uMsg, wParam, lParam);
end;

function TrackShellContextMenu(AWnd: HWND; AMenu: HMENU; ACM: IContextMenu;
  AScreenX, AScreenY: Integer): UINT;
var
  Hooked: Boolean;
begin
  GMenuCM2 := nil;
  GMenuCM3 := nil;
  if ACM <> nil then
    if not Supports(ACM, ICShellContextMenu3, GMenuCM3) then
      Supports(ACM, ICShellContextMenu2, GMenuCM2);

  // シェルのメニュー（ACM が nil でない）を出すときは、IContextMenu2/3 の有無にかかわらず、
  // 表示中だけウィンドウ手続きを差し替える（メニュー関連のメッセージを LCL へ流さないため）。
  // 独自項目だけのメニュー（ACM = nil）は、項目に付いた値が 0 で LCL が読んでも問題ないため差し替えない
  Hooked := ACM <> nil;
  if Hooked then
    GOldWndProc := _SetWindowLongPtrW(AWnd, CGWLP_WNDPROC, PtrInt(@MenuHookProc));
  try
    Result := UINT(TrackPopupMenu(AMenu, TPM_LEFTALIGN or TPM_RIGHTBUTTON or TPM_RETURNCMD,
      AScreenX, AScreenY, 0, AWnd, nil));
  finally
    if Hooked then
    begin
      _SetWindowLongPtrW(AWnd, CGWLP_WNDPROC, GOldWndProc);
      GOldWndProc := 0;
    end;
    GMenuCM2 := nil;
    GMenuCM3 := nil;
  end;
end;

function ShellMenuVerb(ACM: IContextMenu; ACmdOffset: UINT): string;
var
  Buf: array[0..255] of WideChar;
begin
  Result := '';
  if ACM = nil then Exit;
  Buf[0] := #0;
  try
    if Succeeded(ACM.GetCommandString(ACmdOffset, CGCS_VERBW, nil,
      PAnsiChar(@Buf[0]), Length(Buf))) then
      Result := String(UnicodeString(PWideChar(@Buf[0])));
  except
    // コマンド名を返さない（例外を出す）シェル拡張もあるため無視する
    Result := '';
  end;
end;

// ---------------------------------------------------------------
// 独自項目の追加（アプリの TPopupMenu）
// ---------------------------------------------------------------

procedure AddExtraItems(AMenu: HMENU; AParent: TMenuItem; var APos: Integer; AItems: TList);
var
  i, SubPos: Integer;
  Item: TMenuItem;
  Sub: HMENU;
  Flags: UINT;
  S: string;
  W: UnicodeString;
begin
  for i := 0 to AParent.Count - 1 do
  begin
    Item := AParent.Items[i];
    if not Item.Visible then Continue;
    if Item.IsLine then
      InsertMenuW(AMenu, UINT(APos), MF_BYPOSITION or MF_SEPARATOR, 0, nil)
    else
    begin
      S := Item.Caption;
      if Item.ShortCut <> 0 then
        S := S + #9 + ShortCutToText(Item.ShortCut); // ショートカットは表示のみ
      W := UTF8ToUTF16(S);
      Flags := MF_BYPOSITION or MF_STRING;
      if not Item.Enabled then Flags := Flags or MF_GRAYED;
      if Item.Checked then Flags := Flags or MF_CHECKED;
      if Item.Count > 0 then
      begin
        // サブメニュー（親メニューを破棄すると一緒に破棄される）
        Sub := CreatePopupMenu;
        SubPos := 0;
        AddExtraItems(Sub, Item, SubPos, AItems);
        InsertMenuW(AMenu, UINT(APos), Flags or MF_POPUP, PtrUInt(Sub), PWideChar(W));
      end
      else
      begin
        InsertMenuW(AMenu, UINT(APos), Flags, PtrUInt(CEXTRA_MENU_FIRST_ID + AItems.Count), PWideChar(W));
        AItems.Add(Item);
      end;
    end;
    Inc(APos);
  end;
end;

function ExtraMenuInsert(AMenu: HMENU; APopup: TPopupMenu; APosition: TCExtraMenuPosition;
  AComponent: TComponent; AItems: TList): Integer;
var
  Before, InsPos, Start: Integer;
  SepAdded: Boolean;
begin
  Result := 0;
  if (AMenu = 0) or (APopup = nil) or (AItems = nil) then Exit;

  // 表示の直前：アプリ側で項目の有効／無効・表示／非表示を切り替えられるようにする
  APopup.PopupComponent := AComponent;
  if Assigned(APopup.OnPopup) then
    APopup.OnPopup(APopup);

  Before := GetMenuItemCount(AMenu);
  if Before < 0 then Before := 0;
  SepAdded := False;
  if APosition = empTop then
    InsPos := 0
  else
  begin
    InsPos := Before;
    if Before > 0 then
    begin
      InsertMenuW(AMenu, UINT(InsPos), MF_BYPOSITION or MF_SEPARATOR, 0, nil);
      Inc(InsPos);
      SepAdded := True;
    end;
  end;

  Start := InsPos;
  AddExtraItems(AMenu, APopup.Items, InsPos, AItems);
  Result := InsPos - Start;

  if Result = 0 then
  begin
    // 表示する項目がなかった：入れた区切り線を取り除く
    if SepAdded then
      DeleteMenu(AMenu, UINT(Before), MF_BYPOSITION);
    Exit;
  end;
  // 先頭に追加した場合は、シェルの項目との間に区切り線を入れる
  if (APosition = empTop) and (Before > 0) then
    InsertMenuW(AMenu, UINT(InsPos), MF_BYPOSITION or MF_SEPARATOR, 0, nil);
end;

type
  // CMINVOKECOMMANDINFOEX（独自宣言。Unicode のパスを渡すため）
  {$push}{$packrecords c}
  TCCMInvokeCommandInfoEx = record
    cbSize: DWORD;
    fMask: DWORD;
    hwnd: HWND;
    lpVerb: PAnsiChar;
    lpParameters: PAnsiChar;
    lpDirectory: PAnsiChar;
    nShow: Integer;
    dwHotKey: DWORD;
    hIcon: THandle;
    lpTitle: PAnsiChar;
    lpVerbW: PWideChar;
    lpParametersW: PWideChar;
    lpDirectoryW: PWideChar;
    lpTitleW: PWideChar;
    ptInvoke: TPoint;
  end;
  {$pop}
  PCCMInvokeCommandInfo = ^TCMInvokeCommandInfo;

const
  CCMIC_MASK_UNICODE = $00004000;

function ShellInvokeMenuCommand(ACM: IContextMenu; AWnd: HWND; ACmdOffset: UINT;
  const ADirectory: string): Boolean;
var
  ICI: TCCMInvokeCommandInfoEx;
  Dir: string;
  DirA: AnsiString;
  DirW: UnicodeString;
begin
  Result := False;
  if ACM = nil then Exit;
  Dir := ADirectory;
  // "C:" は "C:\" にする（ドライブのルート）
  if (Length(Dir) = 2) and (Dir[2] = ':') then
    Dir := Dir + '\';
  DirW := UTF8ToUTF16(Dir);
  DirA := UTF8ToWinCP(Dir);

  ICI := Default(TCCMInvokeCommandInfoEx);
  ICI.cbSize := SizeOf(ICI);
  ICI.fMask := CCMIC_MASK_UNICODE;
  ICI.hwnd := AWnd;
  {$push}{$hints off} // 順序型⇔ポインターの変換（Win32 API の仕様どおり）
  ICI.lpVerb := PAnsiChar(PtrUInt(ACmdOffset));
  ICI.lpVerbW := PWideChar(PtrUInt(ACmdOffset));
  {$pop}
  if Dir <> '' then
  begin
    ICI.lpDirectory := PAnsiChar(DirA);
    ICI.lpDirectoryW := PWideChar(DirW);
  end;
  ICI.nShow := SW_SHOWNORMAL;
  try
    Result := Succeeded(ACM.InvokeCommand(PCCMInvokeCommandInfo(@ICI)^));
  except
    // シェル拡張側の例外でアプリを落とさない
    Result := False;
  end;
end;

function ExtraMenuClick(AItems: TList; ACmd: UINT): Boolean;
var
  Idx: Integer;
begin
  Result := False;
  if (AItems = nil) or (ACmd < CEXTRA_MENU_FIRST_ID) then Exit;
  Idx := Integer(ACmd - CEXTRA_MENU_FIRST_ID);
  if Idx >= AItems.Count then Exit;
  TMenuItem(AItems[Idx]).Click;
  Result := True;
end;

end.
