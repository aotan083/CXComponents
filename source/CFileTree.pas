{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ CFileTree - TCFileTree：指定したフォルダー（RootPath）を根にして、フォルダーとファイルを1本のツリーに並べる
  設計書: docs\TCFileTree_Design.md
  環境: Lazarus 4.8 / 5.0 RC1 / FPC 3.2.2 / Windows 11 x64
  ・コピー・切取り・貼付け・削除・名前の変更・フォルダー作成・ドラッグ＆ドロップ・右クリックメニュー
  ・ダブルクリックで開く（.url は TargetBrowser、.lnk はリンク先で振り分け、テキストは TargetEditor）
  ・ファイル操作はシェルに任せ、表示の更新はフォルダーの変更通知に任せる }
unit CFileTree;

{$mode objfpc}{$H+}
{$WARN 4055 OFF} // 順序型⇔ポインターの変換（Win32 API の引数のため意図的）

interface

uses
  Classes, SysUtils, Controls, ComCtrls, Windows, ActiveX, ShlObj, ShellAPI, Messages,
  Graphics, Dialogs, Forms, LMessages, ExtCtrls, Menus, CommCtrl,
  uCmonacos, uCsEditor, uCTabBrowser,
  SyncObjs, CShellMenu, CShellDragDrop, CShellOleDrop, CShellOleDrag;

const
  { フォルダーの変更を知らせるウィンドウメッセージ（監視のスレッド → TCFileTree） }
  WM_CFT_WATCH = WM_USER + $5B3;

type
  { TCFtWatcher }

  { 根のフォルダー配下の、ファイル・フォルダーの増減・名前の変更を、ReadDirectoryChangesW で監視するスレッド。
    シェルの変更通知（SHChangeNotifyRegister）は、サブフォルダーの中の変更が届かないため使わない。
    変わった項目の「親フォルダー」のパスをためて、WM_CFT_WATCH で知らせる（受け取る側が TakePaths で取り出す） }
  TCFtWatcher = class(TThread)
  private
    FRoot: string;
    FWnd: HWND;
    FDir: THandle;
    FLock: TCriticalSection;
    FPaths: TStringList;
    FOverflow: Boolean;
    FPosted: Boolean;
    procedure AddPath(const AParent: string);
    procedure PostNudge;
  protected
    procedure Execute; override;
  public
    constructor Create(const ARoot: string; AWnd: HWND);
    destructor Destroy; override;
    // 止める（スレッドの終わりまで待つ）
    procedure Stop;
    // ためた親フォルダーのパスを取り出す。多すぎて取りこぼしたときは AOverflow = True（全体を更新する）
    procedure TakePaths(ADest: TStrings; out AOverflow: Boolean);
  end;

  { 名前の変更の受け渡し（ノードへのポインタは持たず、パスで持つ） }
  PFtRenameInfo = ^TFtRenameInfo;
  TFtRenameInfo = record
    OldPath: string;
    NewPath: string;
    ParentPath: string;
  end;

  { 右クリックメニューの項目 }
  TCFtMenu = (fmCopy, fmCut, fmPaste, fmRename, fmDelete, fmShowInExplorer, fmCopyPath,
    fmNewFolder, fmTextOpen, fmTextOpenNew, fmTextSide, fmWebOpen, fmWebOpenNew,
    fmWebSide, fmOpenProgram, fmShowHidden, fmWindowsMenu);

  { TCFileNode }

  { TCFileTree のノード。フォルダーかファイルかと、アイコンの番号を持つ }
  TCFileNode = class(TTreeNode)
  public
    IsDir: Boolean;         // フォルダーなら True
    IconIndex: Integer;     // システムアイコンの番号（IconLoaded のとき有効）
    IconLoaded: Boolean;
  end;

  { TCFileTree }

  TCFileTree = class(TCustomTreeView)
  private
    FRootPath: string;
    FShowHidden: Boolean;
    FTargetEditor: TControl;
    FSideEditor: TControl;
    FTargetBrowser: TCTabBrowser;
    FSideBrowser: TCTabBrowser;
    FRootDirty: Boolean;           // 窓が無い間に RootPath・ShowHidden が変えられた（次の CreateWnd で作り直す）
    FIsRefreshing: Boolean;

    // --- フォルダー変更監視 ---
    FWatcher: TCFtWatcher;
    FNotifyTimer: TTimer;
    FPendingPaths: TStringList;
    FRefreshAll: Boolean;

    // --- D&D ---
    FDragArmed: Boolean;
    FDragStartPt: TPoint;
    FDragButton: TMouseButton;
    FDragPaths: TStringList;
    FClickPath: string;
    FDropHilite: TTreeNode;
    FHoverNode: TTreeNode;
    FHoverSince: QWord;
    FDragTimer: TTimer;
    FOleTarget: TCShellOleDropTarget;
    FOleDragOver: Boolean;

    // --- アイコン ---
    FSysSmallImages: HIMAGELIST;
    FIconCache: TStringList;

    // --- 選択 ---
    FInFixSelection: Boolean;

    // --- 右クリックメニュー ---
    FMenu: TPopupMenu;
    FMenuItems: array[TCFtMenu] of TMenuItem;
    FMenuPos: TPoint;
    FNewFolderPath: string;

    procedure SetRootPath(const AValue: string);
    procedure SetShowHidden(AValue: Boolean);
    procedure SetTargetEditor(AValue: TControl);
    procedure SetSideEditor(AValue: TControl);
    procedure SetTargetBrowser(AValue: TCTabBrowser);
    procedure SetSideBrowser(AValue: TCTabBrowser);
    function EditorAcceptable(AValue, AOther: TControl): Boolean;

    // ツリーを作る・読む
    procedure BuildTree;
    function AddEntry(AParent: TTreeNode; const AName: string; AIsDir: Boolean): TTreeNode;
    function ReadDirEntries(const APath: string; ADirs, AFiles: TStringList): Boolean;
    procedure LoadChildren(ANode: TTreeNode);
    procedure MergeChildren(ANode: TTreeNode);
    procedure ApplyRefresh(ATargets: TStrings; AAll: Boolean);
    procedure CollectExpandedPaths(ANode: TTreeNode; APaths: TStrings);

    // 変更通知
    procedure StartWatch;
    procedure StopWatch;
    procedure HandleWatch;
    procedure NotifyTimerTick({%H-}Sender: TObject);

    // パス・探索
    function FindNodeByPath(const APath: string): TTreeNode;
    function FolderPathOf(ANode: TTreeNode): string;
    function IsNodeSelected(ANode: TTreeNode): Boolean;
    procedure GetSelectedNodes(AList: TList);

    // アイコン
    function NodeIconIndex(ANode: TCFileNode): Integer;

    // 操作
    procedure InternalOnEdited({%H-}Sender: TObject; Node: TTreeNode; var S: string);
    procedure DoAsyncRename(Data: PtrInt);
    procedure DoAsyncEdit({%H-}Data: PtrInt);
    function SelectedItemPaths(APaths: TStrings): Boolean;

    // 開く
    function TextTargetOf(const APath: string): string;
    function WebUrlOf(const APath: string): string;
    procedure OpenNodeByDefault(ANode: TTreeNode);
    procedure OpenInEditor(const APath: string; ANewTab: Boolean; AEditor: TControl);
    procedure OpenInBrowser(const AUrl: string; ANewTab: Boolean; ABrowser: TCTabBrowser);
    procedure ExecuteAssociated(const APath: string);

    // 右クリックメニュー
    procedure BuildMenu;
    procedure UpdateMenuState;
    procedure MenuClick(Sender: TObject);
    procedure DisplayShellContextMenu(APaths: TStrings; const AScreenPt: TPoint);
    function GetPIDLFromPath(const APath: string): PItemIDList;
    function AddNewSubmenu(AMenu: HMENU; const AFolder: string): IContextMenu;

    // D&D
    function OleResolveDrop(const AScreenPt: TPoint): string;
    procedure OleDropLeave;
    procedure OleDropped(const AFolder: string);
    procedure SetDropHilite(ANode: TTreeNode);
    procedure DragTimerTick({%H-}Sender: TObject);
  protected
    procedure DoCreateNodeClass(var NewNodeClass: TTreeNodeClass); override;
    function CanExpand(Node: TTreeNode): Boolean; override;
    function CanEdit(Node: TTreeNode): Boolean; override;
    procedure DoSelectionChanged; override;
    function GetBuiltinIconSize: TSize; override;
    function DrawBuiltinIcon(ANode: TTreeNode; ARect: TRect): TSize; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure DoContextPopup(MousePos: TPoint; var Handled: Boolean); override;
    procedure DblClick; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure WndProc(var Message: TLMessage); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // ノードのフルパス（根は RootPath）
    function GetPathFromNode(ANode: TTreeNode): string;
    function IsRootNode(ANode: TTreeNode): Boolean;
    function IsDirNode(ANode: TTreeNode): Boolean;
    // 選んでいるノードのパス（なければ ''）
    function SelectedPath: string;
    // 選んでいる項目すべてのパス（同じフォルダーの中のものだけ）
    procedure GetSelectedPaths(APaths: TStrings);
    procedure CopySelected;
    procedure CutSelected;
    procedure PasteToSelected;
    procedure DeleteSelected(APermanent: Boolean = False);
    procedure RenameSelected;
    procedure NewFolder;
    // 開いているフォルダーをすべて、ディスクの今に合わせる（F5 と同じ）
    procedure RefreshTree;
  published
    property RootPath: string read FRootPath write SetRootPath;
    property ShowHidden: Boolean read FShowHidden write SetShowHidden default False;
    property TargetEditor: TControl read FTargetEditor write SetTargetEditor;
    property TargetBrowser: TCTabBrowser read FTargetBrowser write SetTargetBrowser;
    property SideEditor: TControl read FSideEditor write SetSideEditor;
    property SideBrowser: TCTabBrowser read FSideBrowser write SetSideBrowser;
    // LCL 標準のうち、使ってよいもの
    property Align;
    property Anchors;
    property BorderSpacing;
    property BorderStyle;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property Indent;
    property ParentColor default False;
    property ParentFont;
    property ShowHint;
    property Hint;
    property TabOrder;
    property TabStop default True;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnSelectionChanged;
    property OnExpanded;
    property OnCollapsed;
  end;

implementation

uses
  uCXLang, Clipbrd, IniFiles, LazUTF8;

{ ---------- Windows の関数（宣言の違いで困らないよう、ここで宣言する） ---------- }

// エクスプローラーと同じ自然順の比較
function StrCmpLogicalW(psz1, psz2: PWideChar): Integer; stdcall; external 'shlwapi.dll';

const
  CFtSHGFI_SMALLICON         = $000000001;
  CFtSHGFI_USEFILEATTRIBUTES = $000000010;
  CFtSHGFI_SYSICONINDEX      = $000004000;

  CFtFILE_LIST_DIRECTORY = $0001;
  CFtFILE_NOTIFY_CHANGE_FILE_NAME = $00000001;
  CFtFILE_NOTIFY_CHANGE_DIR_NAME = $00000002;
  CFtWatchBufBytes = 65536;      // 監視のバッファの大きさ
  CFtMaxQueued = 5000;           // 監視のスレッドがためる親フォルダーの数の上限（超えたら全体を更新する）
  CFtMaxPending = 200;           // 更新候補がこれを超えたら全体を更新する
  CFtTextProbeBytes = 8192;      // テキストかどうかを調べるために読むバイト数
  CFtHoverOpenMs = 700;          // ドラッグ中に同じフォルダーの上に留まって、自動で開くまでの時間

type
  { ReadDirectoryChangesW が返す FILE_NOTIFY_INFORMATION（Windows の定義どおり） }
  PFtNotifyInfo = ^TFtNotifyInfo;
  TFtNotifyInfo = record
    NextEntryOffset: DWORD;
    Action: DWORD;
    FileNameLength: DWORD;   // バイト数
    FileName: array[0..0] of WideChar;
  end;

  TCFtSHFileInfoW = record
    hIcon: HICON;
    iIcon: Integer;
    dwAttributes: DWORD;
    szDisplayName: array[0..259] of WideChar;
    szTypeName: array[0..79] of WideChar;
  end;

  { .lnk のリンク先を読むための IShellLinkW・IPersistFile（Windows の定義どおりの並び） }
  IFtShellLinkW = interface(IUnknown)
    ['{000214F9-0000-0000-C000-000000000046}']
    function GetPath(pszFile: PWideChar; cch: Integer; pfd: Pointer; fFlags: DWORD): HResult; stdcall;
    function GetIDList(out ppidl: Pointer): HResult; stdcall;
    function SetIDList(pidl: Pointer): HResult; stdcall;
    function GetDescription(pszName: PWideChar; cch: Integer): HResult; stdcall;
    function SetDescription(pszName: PWideChar): HResult; stdcall;
    function GetWorkingDirectory(pszDir: PWideChar; cch: Integer): HResult; stdcall;
    function SetWorkingDirectory(pszDir: PWideChar): HResult; stdcall;
    function GetArguments(pszArgs: PWideChar; cch: Integer): HResult; stdcall;
    function SetArguments(pszArgs: PWideChar): HResult; stdcall;
    function GetHotkey(out pwHotkey: Word): HResult; stdcall;
    function SetHotkey(wHotkey: Word): HResult; stdcall;
    function GetShowCmd(out piShowCmd: Integer): HResult; stdcall;
    function SetShowCmd(iShowCmd: Integer): HResult; stdcall;
    function GetIconLocation(pszIconPath: PWideChar; cch: Integer; out piIcon: Integer): HResult; stdcall;
    function SetIconLocation(pszIconPath: PWideChar; iIcon: Integer): HResult; stdcall;
    function SetRelativePath(pszPathRel: PWideChar; dwReserved: DWORD): HResult; stdcall;
    function Resolve(wnd: HWND; fFlags: DWORD): HResult; stdcall;
    function SetPath(pszFile: PWideChar): HResult; stdcall;
  end;

  { IShellExtInit・IContextMenu2（独自宣言。標準の「新規作成」に、作る先のフォルダーを教え、中身を作らせるため） }
  IFtShellExtInit = interface(IUnknown)
    ['{000214E8-0000-0000-C000-000000000046}']
    function Initialize(pidlFolder: PItemIDList; pdtobj: Pointer; hkeyProgID: HKEY): HResult; stdcall;
  end;

  IFtContextMenu2 = interface(IContextMenu)
    ['{000214F4-0000-0000-C000-000000000046}']
    function HandleMenuMsg(uMsg: UINT; WParam: WPARAM; LParam: LPARAM): HResult; stdcall;
  end;

  IFtPersistFile = interface(IUnknown)
    ['{0000010B-0000-0000-C000-000000000046}']
    function GetClassID(out classID: TGUID): HResult; stdcall;
    function IsDirty: HResult; stdcall;
    function Load(pszFileName: PWideChar; dwMode: DWORD): HResult; stdcall;
    function Save(pszFileName: PWideChar; fRemember: BOOL): HResult; stdcall;
    function SaveCompleted(pszFileName: PWideChar): HResult; stdcall;
    function GetCurFile(out ppszFileName: PWideChar): HResult; stdcall;
  end;

const
  CLSID_FtShellLink: TGUID = '{00021401-0000-0000-C000-000000000046}';
  CFtSLR_NO_UI = $0001;
  // 標準の「新規作成」のハンドラー（CNewMenu）と、そのコマンドIDの範囲（項目メニューの 1〜$7FFF と重ならない）
  CLSID_FtNewMenu: TGUID = '{D969A300-E7FF-11D0-A93B-00A0C90F2719}';
  CFtNewFirstId = $8200;
  CFtNewLastId = $BFFF;

function _SHGetFileInfoW(pszPath: PWideChar; dwFileAttributes: DWORD; var psfi: TCFtSHFileInfoW;
  cbFileInfo: UINT; uFlags: UINT): PtrUInt; stdcall;
  external 'shell32.dll' name 'SHGetFileInfoW';
function _SHGetSpecialFolderLocation(hwndOwner: HWND; nFolder: Integer;
  out ppidl: PItemIDList): HRESULT; stdcall;
  external 'shell32.dll' name 'SHGetSpecialFolderLocation';
function _ReadDirectoryChangesW(hDirectory: THandle; lpBuffer: Pointer; nBufferLength: DWORD;
  bWatchSubtree: BOOL; dwNotifyFilter: DWORD; lpBytesReturned: PDWORD; lpOverlapped: Pointer;
  lpCompletionRoutine: Pointer): BOOL; stdcall;
  external 'kernel32.dll' name 'ReadDirectoryChangesW';
function _CancelIoEx(hFile: THandle; lpOverlapped: Pointer): BOOL; stdcall;
  external 'kernel32.dll' name 'CancelIoEx';
function _CoCreateInstance(const rclsid: TGUID; pUnkOuter: IUnknown; dwClsContext: DWORD;
  const riid: TGUID; out ppv): HRESULT; stdcall;
  external 'ole32.dll' name 'CoCreateInstance';

{ ---------- 文字・パスの道具 ---------- }

{ 大文字小文字を区別せずに同じか }
function FtSameText(const A, B: string): Boolean;
begin
  Result := UTF8CompareText(A, B) = 0;
end;

{ 根のパスを整える：空なら ''。ExpandFileName して、末尾の区切りを除く（C:\ のような、ドライブの根は区切りを残す） }
function FtNormalizeRoot(const P: string): string;
begin
  Result := '';
  if Trim(P) = '' then Exit;
  Result := ExpandFileName(Trim(P));
  while (Length(Result) > 1) and (Result[Length(Result)] in ['\', '/']) do
  begin
    if (Length(Result) = 3) and (Result[2] = ':') then Break;
    Delete(Result, Length(Result), 1);
  end;
end;

{ パスの末尾の区切りを除く（C:\ のような、ドライブの根は残す） }
function FtTrimTail(const P: string): string;
begin
  Result := P;
  while (Length(Result) > 1) and (Result[Length(Result)] in ['\', '/']) do
  begin
    if (Length(Result) = 3) and (Result[2] = ':') then Break;
    Delete(Result, Length(Result), 1);
  end;
end;

{ C:\ や \\server\share のようなドライブの根か }
function FtIsDriveRoot(const P: string): Boolean;
var
  X: string;
begin
  X := ExcludeTrailingPathDelimiter(P);
  Result := (X <> '') and SameText(X, ExtractFileDrive(P));
end;

{ 名前の自然順の並べ替え }
function FtCompareNames(List: TStringList; Index1, Index2: Integer): Integer;
var
  W1, W2: UnicodeString;
begin
  W1 := UTF8Decode(List[Index1]);
  W2 := UTF8Decode(List[Index2]);
  Result := StrCmpLogicalW(PWideChar(W1), PWideChar(W2));
end;

{ ファイルのパスから file:/// の URL を作る（日本語はそのまま） }
function FtPathToFileUrl(const APath: string): string;
var
  I: Integer;
  S: string;
begin
  S := '';
  for I := 1 to Length(APath) do
    case APath[I] of
      '\': S := S + '/';
      '%': S := S + '%25';
      '#': S := S + '%23';
      ' ': S := S + '%20';
    else
      S := S + APath[I];
    end;
  if Copy(S, 1, 2) = '//' then
    Result := 'file:' + S          { \\server\share → file://server/share }
  else
    Result := 'file:///' + S;
end;

{ .url の中の URL を読む }
function FtReadUrlFile(const AFileName: string): string;
var
  Ini: TIniFile;
begin
  Result := '';
  try
    Ini := TIniFile.Create(AFileName);
    try
      Result := Trim(Ini.ReadString('InternetShortcut', 'URL', ''));
    finally
      Ini.Free;
    end;
  except
    Result := '';
  end;
end;

{ .lnk のリンク先を読む（画面を出さない）。読めなければ '' }
function FtResolveLink(const AFileName: string): string;
var
  Unk: IUnknown;
  SL: IFtShellLinkW;
  PF: IFtPersistFile;
  Buf: array[0..MAX_PATH * 2] of WideChar;
  W: UnicodeString;
begin
  Result := '';
  try
    if _CoCreateInstance(CLSID_FtShellLink, nil, 1 { CLSCTX_INPROC_SERVER }, IUnknown, Unk) <> S_OK then Exit;
    if Unk.QueryInterface(IFtShellLinkW, SL) <> S_OK then Exit;
    if SL.QueryInterface(IFtPersistFile, PF) <> S_OK then Exit;
    W := UTF8Decode(AFileName);
    if PF.Load(PWideChar(W), 0) <> S_OK then Exit;
    SL.Resolve(0, CFtSLR_NO_UI);
    FillChar(Buf, SizeOf(Buf), 0);
    if SL.GetPath(@Buf[0], Length(Buf) - 1, nil, 0) <> S_OK then Exit;
    Result := UTF8Encode(UnicodeString(PWideChar(@Buf[0])));
  except
    Result := '';
  end;
end;

{ テキストか：先頭の CFtTextProbeBytes バイトに NUL（0x00）が無ければテキスト。
  空のファイル、UTF-16 の BOM（FF FE・FE FF）で始まるものもテキスト。読めなければ False }
function FtIsTextFile(const APath: string): Boolean;
var
  FS: TFileStream;
  Buf: array[0..CFtTextProbeBytes - 1] of Byte;
  N, I: Integer;
begin
  Result := False;
  try
    FS := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
    try
      N := FS.Read(Buf[0], SizeOf(Buf));
    finally
      FS.Free;
    end;
  except
    Exit;
  end;
  if N = 0 then Exit(True);
  if (N >= 2) and (((Buf[0] = $FF) and (Buf[1] = $FE)) or ((Buf[0] = $FE) and (Buf[1] = $FF))) then Exit(True);
  for I := 0 to N - 1 do
    if Buf[I] = 0 then Exit(False);
  Result := True;
end;

{ http:// か https:// で始まるか }
function FtIsWebUrl(const S: string): Boolean;
begin
  Result := (LowerCase(Copy(S, 1, 7)) = 'http://') or (LowerCase(Copy(S, 1, 8)) = 'https://');
end;

{ ---------- エディター・ブラウザーの呼び分け（TCMonacoEditor と TCsEditor は同じ名前のメソッドを持つ） ---------- }

function EdFindPage(E: TControl; const P: string): Integer;
begin
  if E is TCMonacoEditor then Result := TCMonacoEditor(E).FindPage(P)
  else if E is TCsEditor then Result := TCsEditor(E).FindPage(P)
  else Result := -1;
end;

procedure EdSetActive(E: TControl; AIndex: Integer);
begin
  if E is TCMonacoEditor then TCMonacoEditor(E).ActiveIndex := AIndex
  else if E is TCsEditor then TCsEditor(E).ActiveIndex := AIndex;
end;

function EdModified(E: TControl): Boolean;
begin
  if E is TCMonacoEditor then Result := TCMonacoEditor(E).Modified
  else if E is TCsEditor then Result := TCsEditor(E).Modified
  else Result := False;
end;

function EdOpenFile(E: TControl; const P: string): Integer;
begin
  if E is TCMonacoEditor then Result := TCMonacoEditor(E).OpenFile(P)
  else if E is TCsEditor then Result := TCsEditor(E).OpenFile(P)
  else Result := -1;
end;

function EdLoadFile(E: TControl; const P: string): Boolean;
begin
  if E is TCMonacoEditor then Result := TCMonacoEditor(E).LoadFromFile(P)
  else if E is TCsEditor then Result := TCsEditor(E).LoadFromFile(P)
  else Result := False;
end;

procedure EdFocus(E: TControl);
begin
  if (E is TWinControl) and TWinControl(E).CanFocus then TWinControl(E).SetFocus;
end;

{ ================================================================== }
{ TCFileTree                                                         }
{ ================================================================== }

constructor TCFileTree.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRootPath := 'C:\';
  FShowHidden := False;
  Options := Options + [tvoAllowMultiselect];
  ReadOnly := False;           // 名前の変更をさせる
  DragMode := dmManual;        // ドラッグは一定距離動いたときに自分で始める
  ShowButtons := True;
  ShowLines := False;
  ShowRoot := True;
  RightClickSelect := False;   // 右クリックの選択は DoContextPopup で自分で行う
  OnEdited := @InternalOnEdited;

  FIsRefreshing := False;
  FWatcher := nil;
  FRefreshAll := False;
  FPendingPaths := TStringList.Create;
  FPendingPaths.CaseSensitive := False;
  FPendingPaths.Sorted := True;
  FPendingPaths.Duplicates := dupIgnore;
  FNotifyTimer := TTimer.Create(Self);
  FNotifyTimer.Enabled := False;
  FNotifyTimer.Interval := 300;
  FNotifyTimer.OnTimer := @NotifyTimerTick;

  FDragArmed := False;
  FDragPaths := TStringList.Create;
  FDropHilite := nil;
  FHoverNode := nil;
  FDragTimer := TTimer.Create(Self);
  FDragTimer.Enabled := False;
  FDragTimer.Interval := 80;
  FDragTimer.OnTimer := @DragTimerTick;

  FSysSmallImages := 0;
  FIconCache := TStringList.Create;
  FIconCache.CaseSensitive := False;
  FIconCache.Sorted := True;
  FIconCache.Duplicates := dupIgnore;

  BuildMenu;
end;

destructor TCFileTree.Destroy;
begin
  if FNotifyTimer <> nil then FNotifyTimer.Enabled := False;
  if FDragTimer <> nil then FDragTimer.Enabled := False;
  // 自分がドラッグ元のまま破棄される場合に備えて解除する
  ShellDragAbandon(Self);
  if FOleTarget <> nil then
  begin
    if HandleAllocated then
      OleDropRevoke(Handle, FOleTarget)
    else
      OleDropRevoke(0, FOleTarget);
  end;
  StopWatch;
  // 自分宛にキューされている未実行の非同期呼び出し（DoAsyncRename・DoAsyncEdit）を取り消す
  Application.RemoveAsyncCalls(Self);
  FreeAndNil(FPendingPaths);
  FreeAndNil(FDragPaths);
  FreeAndNil(FIconCache);
  inherited Destroy;
end;

procedure TCFileTree.CreateWnd;
begin
  inherited CreateWnd;
  if not (csDesigning in ComponentState) then
  begin
    // ツリーを作るのは、項目が無いとき（最初に窓ができたとき）と、窓が無い間に RootPath・ShowHidden が
    // 変えられたときだけ（設計書 6章）。ドック・切り離しなどで窓が作り直されただけのときは、項目に手を付けない
    if FRootDirty or ((Items.Count = 0) and (FRootPath <> '')) then
    begin
      FRootDirty := False;
      BuildTree;
    end;
    StartWatch;
    FOleTarget := OleDropRegister(Handle, @OleResolveDrop, @OleDropLeave, @OleDropped);
  end;
end;

procedure TCFileTree.DestroyWnd;
begin
  StopWatch;
  OleDropRevoke(Handle, FOleTarget);
  inherited DestroyWnd;
end;

procedure TCFileTree.DoCreateNodeClass(var NewNodeClass: TTreeNodeClass);
begin
  inherited DoCreateNodeClass(NewNodeClass);
  NewNodeClass := TCFileNode;
end;

procedure TCFileTree.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FTargetEditor then FTargetEditor := nil;
    if AComponent = FSideEditor then FSideEditor := nil;
    if AComponent = FTargetBrowser then FTargetBrowser := nil;
    if AComponent = FSideBrowser then FSideBrowser := nil;
  end;
end;

{ ------------------------------------------------------------------ }
{ プロパティ                                                          }
{ ------------------------------------------------------------------ }

procedure TCFileTree.SetRootPath(const AValue: string);
var
  N: string;
begin
  N := FtNormalizeRoot(AValue);
  if N = FRootPath then Exit;
  FRootPath := N;
  if (csLoading in ComponentState) or (csDesigning in ComponentState) or not HandleAllocated then
  begin
    FRootDirty := True;   // 次の CreateWnd で作る
    Exit;
  end;
  BuildTree;
  StartWatch;
end;

procedure TCFileTree.SetShowHidden(AValue: Boolean);
begin
  if FShowHidden = AValue then Exit;
  FShowHidden := AValue;
  if (csLoading in ComponentState) or (csDesigning in ComponentState) then Exit;
  if not HandleAllocated then
  begin
    FRootDirty := True;
    Exit;
  end;
  RefreshTree;
end;

{ 開き先のエディターに入れてよいか：TCMonacoEditor か TCsEditor で、もう一方と同じクラス }
function TCFileTree.EditorAcceptable(AValue, AOther: TControl): Boolean;
begin
  if AValue = nil then Exit(True);
  if not ((AValue is TCMonacoEditor) or (AValue is TCsEditor)) then Exit(False);
  Result := (AOther = nil) or (AOther.ClassType = AValue.ClassType);
end;

procedure TCFileTree.SetTargetEditor(AValue: TControl);
begin
  if FTargetEditor = AValue then Exit;
  if not EditorAcceptable(AValue, FSideEditor) then Exit;
  if FTargetEditor <> nil then FTargetEditor.RemoveFreeNotification(Self);
  FTargetEditor := AValue;
  if FTargetEditor <> nil then FTargetEditor.FreeNotification(Self);
end;

procedure TCFileTree.SetSideEditor(AValue: TControl);
begin
  if FSideEditor = AValue then Exit;
  if not EditorAcceptable(AValue, FTargetEditor) then Exit;
  if FSideEditor <> nil then FSideEditor.RemoveFreeNotification(Self);
  FSideEditor := AValue;
  if FSideEditor <> nil then FSideEditor.FreeNotification(Self);
end;

procedure TCFileTree.SetTargetBrowser(AValue: TCTabBrowser);
begin
  if FTargetBrowser = AValue then Exit;
  if FTargetBrowser <> nil then FTargetBrowser.RemoveFreeNotification(Self);
  FTargetBrowser := AValue;
  if FTargetBrowser <> nil then FTargetBrowser.FreeNotification(Self);
end;

procedure TCFileTree.SetSideBrowser(AValue: TCTabBrowser);
begin
  if FSideBrowser = AValue then Exit;
  if FSideBrowser <> nil then FSideBrowser.RemoveFreeNotification(Self);
  FSideBrowser := AValue;
  if FSideBrowser <> nil then FSideBrowser.FreeNotification(Self);
end;

{ ------------------------------------------------------------------ }
{ ツリーを作る・子の読み込み・並び                                       }
{ ------------------------------------------------------------------ }

function TCFileTree.AddEntry(AParent: TTreeNode; const AName: string; AIsDir: Boolean): TTreeNode;
begin
  Result := Items.AddChild(AParent, AName);
  TCFileNode(Result).IsDir := AIsDir;
  TCFileNode(Result).IconLoaded := False;
  Result.HasChildren := AIsDir;
end;

procedure TCFileTree.BuildTree;
var
  RootNode: TTreeNode;
  RootName: string;
begin
  if csDesigning in ComponentState then Exit;
  Items.BeginUpdate;
  try
    Items.Clear;
    if (FRootPath = '') or not DirectoryExists(FRootPath) then Exit;
    RootName := ExtractFileName(FRootPath);
    if RootName = '' then RootName := FRootPath;
    RootNode := AddEntry(nil, RootName, True);
    RootNode.Expand(False);   // CanExpand で子が読み込まれる
  finally
    Items.EndUpdate;
  end;
end;

procedure TCFileTree.RefreshTree;
begin
  ApplyRefresh(nil, True);
end;

{ フォルダーの中身を読む。フォルダー・ファイルを別々に、自然順で並べて返す。読めなければ False }
function TCFileTree.ReadDirEntries(const APath: string; ADirs, AFiles: TStringList): Boolean;
var
  H: THandle;
  FD: TWin32FindDataW;
  EntryName: string;
begin
  Result := False;
  ADirs.Clear;
  AFiles.Clear;
  FD := Default(TWin32FindDataW);
  H := FindFirstFileW(PWideChar(ShellLongPathW(IncludeTrailingPathDelimiter(APath) + '*')), FD);
  if H = INVALID_HANDLE_VALUE then Exit;
  try
    repeat
      EntryName := UTF8Encode(UnicodeString(PWideChar(@FD.cFileName[0])));
      if (EntryName = '.') or (EntryName = '..') then Continue;
      if (not FShowHidden) and ((FD.dwFileAttributes and (FILE_ATTRIBUTE_HIDDEN or FILE_ATTRIBUTE_SYSTEM)) <> 0) then
        Continue;
      if (FD.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
        ADirs.Add(EntryName)
      else
        AFiles.Add(EntryName);
    until not FindNextFileW(H, FD);
  finally
    Windows.FindClose(H);
  end;
  ADirs.CustomSort(@FtCompareNames);
  AFiles.CustomSort(@FtCompareNames);
  Result := True;
end;

{ 子を読み込む（初めて開くとき）。フォルダー → ファイルの順 }
procedure TCFileTree.LoadChildren(ANode: TTreeNode);
var
  Dirs, Files: TStringList;
  I: Integer;
begin
  Dirs := TStringList.Create;
  Files := TStringList.Create;
  try
    try
      if not ReadDirEntries(GetPathFromNode(ANode), Dirs, Files) then Exit;
    except
      Exit;
    end;
    Items.BeginUpdate;
    try
      for I := 0 to Dirs.Count - 1 do AddEntry(ANode, Dirs[I], True);
      for I := 0 to Files.Count - 1 do AddEntry(ANode, Files[I], False);
    finally
      Items.EndUpdate;
    end;
  finally
    Files.Free;
    Dirs.Free;
  end;
end;

function TCFileTree.CanExpand(Node: TTreeNode): Boolean;
begin
  if not (Node is TCFileNode) then Exit(inherited CanExpand(Node));
  if not TCFileNode(Node).IsDir then Exit(False);
  if Node.Count = 0 then LoadChildren(Node);
  if Node.Count = 0 then
  begin
    Node.HasChildren := False;   // 空のフォルダーは、開く印を消す
    Exit(False);
  end;
  Result := inherited CanExpand(Node);
end;

{ 開いているフォルダーの中身を、いまのディスクに合わせる。
  残ったノードは、開いている状態・選択がそのまま残る（消えた分を消し、増えた分を足し、並びを合わせる） }
procedure TCFileTree.MergeChildren(ANode: TTreeNode);
var
  Dirs, Files, Lookup, Existing: TStringList;
  Child, Next: TTreeNode;
  I, Idx, Pos: Integer;
  Remove: TList;

  procedure PlaceEntry(const AName: string; AIsDir: Boolean);
  var
    N: TTreeNode;
  begin
    if Existing.Find(AName, Pos) then
      N := TTreeNode(Existing.Objects[Pos])
    else
      N := AddEntry(ANode, AName, AIsDir);
    if N.Index <> Idx then N.Index := Idx;
    Inc(Idx);
  end;

begin
  Dirs := TStringList.Create;
  Files := TStringList.Create;
  Lookup := TStringList.Create;
  Existing := TStringList.Create;
  Remove := TList.Create;
  try
    Lookup.CaseSensitive := False;
    Lookup.Sorted := True;
    Lookup.Duplicates := dupIgnore;
    Existing.CaseSensitive := False;
    Existing.Sorted := True;
    Existing.Duplicates := dupIgnore;

    if not ReadDirEntries(GetPathFromNode(ANode), Dirs, Files) then
    begin
      // 読めない（消えた・アクセス拒否）：子を全部消す
      ANode.DeleteChildren;
      ANode.HasChildren := False;
      Exit;
    end;
    for I := 0 to Dirs.Count - 1 do Lookup.AddObject(Dirs[I], TObject(PtrInt(1)));
    for I := 0 to Files.Count - 1 do Lookup.AddObject(Files[I], TObject(PtrInt(0)));

    Items.BeginUpdate;
    try
      // 1. ディスクに無い子（または、フォルダーとファイルが入れ替わったもの）を消す
      Child := ANode.GetFirstChild;
      while Child <> nil do
      begin
        if not Lookup.Find(Child.Text, Pos) or
           ((PtrInt(Lookup.Objects[Pos]) = 1) <> TCFileNode(Child).IsDir) then
          Remove.Add(Child);
        Child := Child.GetNextSibling;
      end;
      for I := 0 to Remove.Count - 1 do TTreeNode(Remove[I]).Delete;

      // 2. 残った子を名前で引けるようにする
      Child := ANode.GetFirstChild;
      while Child <> nil do
      begin
        Next := Child.GetNextSibling;
        Existing.AddObject(Child.Text, Child);
        Child := Next;
      end;

      // 3. フォルダー → ファイルの順に、足りない分を足し、並びを合わせる
      Idx := 0;
      for I := 0 to Dirs.Count - 1 do PlaceEntry(Dirs[I], True);
      for I := 0 to Files.Count - 1 do PlaceEntry(Files[I], False);
    finally
      Items.EndUpdate;
    end;
    if ANode.Count = 0 then ANode.HasChildren := False;
  finally
    Remove.Free;
    Existing.Free;
    Lookup.Free;
    Files.Free;
    Dirs.Free;
  end;
end;

{ 開いているフォルダーのパスを、上から順に集める }
procedure TCFileTree.CollectExpandedPaths(ANode: TTreeNode; APaths: TStrings);
var
  C: TTreeNode;
begin
  if ANode = nil then Exit;
  if (ANode is TCFileNode) and TCFileNode(ANode).IsDir and ANode.Expanded then
  begin
    APaths.Add(GetPathFromNode(ANode));
    C := ANode.GetFirstChild;
    while C <> nil do
    begin
      CollectExpandedPaths(C, APaths);
      C := C.GetNextSibling;
    end;
  end;
end;

{ 更新する。AAll = True なら開いているフォルダーすべて、False なら ATargets のうち見つかったものだけ。
  保留はしない（保留は NotifyTimerTick が行う） }
procedure TCFileTree.ApplyRefresh(ATargets: TStrings; AAll: Boolean);
var
  Paths: TStringList;
  I: Integer;
  N: TTreeNode;
begin
  if FIsRefreshing or (csDestroying in ComponentState) then Exit;
  if not HandleAllocated then Exit;
  FIsRefreshing := True;
  try
    Paths := TStringList.Create;
    try
      try
        Items.BeginUpdate;
        try
          if AAll then
          begin
            // 根が無くなっていたら、空のツリーにする
            if (FRootPath = '') or not DirectoryExists(FRootPath) then
            begin
              BuildTree;
              Exit;
            end;
            CollectExpandedPaths(Items.GetFirstNode, Paths);
          end
          else if ATargets <> nil then
            Paths.AddStrings(ATargets);

          for I := 0 to Paths.Count - 1 do
          begin
            N := FindNodeByPath(Paths[I]);   // 前の更新で作り直されることがあるので、毎回探す
            if (N = nil) or not (N is TCFileNode) or not TCFileNode(N).IsDir then Continue;
            if N.Expanded then
              MergeChildren(N)
            else
            begin
              // 閉じているフォルダーは作り直さず、次に開いたときに最新を読む
              N.DeleteChildren;
              N.HasChildren := True;
            end;
          end;
        finally
          Items.EndUpdate;
        end;
      except
        // 更新中の例外は握りつぶす（次の通知・F5 でやり直される）
      end;
    finally
      Paths.Free;
    end;
  finally
    FIsRefreshing := False;
  end;
end;

{ ------------------------------------------------------------------ }
{ パス・探索・選択                                                      }
{ ------------------------------------------------------------------ }

function TCFileTree.GetPathFromNode(ANode: TTreeNode): string;
begin
  if ANode = nil then Exit('');
  if ANode.Parent = nil then Exit(FRootPath);
  Result := IncludeTrailingPathDelimiter(GetPathFromNode(ANode.Parent)) + ANode.Text;
end;

function TCFileTree.IsRootNode(ANode: TTreeNode): Boolean;
begin
  Result := (ANode <> nil) and (ANode.Parent = nil);
end;

function TCFileTree.IsDirNode(ANode: TTreeNode): Boolean;
begin
  Result := (ANode is TCFileNode) and TCFileNode(ANode).IsDir;
end;

{ 読み込み済みのノードの中から、パスのノードを探す。読み込まれていない階層は見つからない（nil） }
function TCFileTree.FindNodeByPath(const APath: string): TTreeNode;
var
  X, Prefix, Rest, Part: string;
  N, C: TTreeNode;
  P: Integer;
begin
  Result := nil;
  N := Items.GetFirstNode;
  if (N = nil) or (APath = '') then Exit;
  X := FtTrimTail(APath);
  if FtSameText(X, FRootPath) then Exit(N);
  Prefix := IncludeTrailingPathDelimiter(FRootPath);
  if not FtSameText(Copy(X, 1, Length(Prefix)), Prefix) then Exit;
  Rest := Copy(X, Length(Prefix) + 1, MaxInt);
  while Rest <> '' do
  begin
    P := Pos('\', Rest);
    if P = 0 then
    begin
      Part := Rest;
      Rest := '';
    end
    else
    begin
      Part := Copy(Rest, 1, P - 1);
      Rest := Copy(Rest, P + 1, MaxInt);
    end;
    if Part = '' then Continue;
    C := N.GetFirstChild;
    while (C <> nil) and not FtSameText(C.Text, Part) do C := C.GetNextSibling;
    if C = nil then Exit;
    N := C;
  end;
  Result := N;
end;

{ 貼り付け・作成の先のフォルダー：フォルダーなら自分、ファイルなら親、nil なら根 }
function TCFileTree.FolderPathOf(ANode: TTreeNode): string;
begin
  if ANode = nil then Exit(FRootPath);
  if IsDirNode(ANode) then Result := GetPathFromNode(ANode)
  else Result := GetPathFromNode(ANode.Parent);
end;

function TCFileTree.IsNodeSelected(ANode: TTreeNode): Boolean;
begin
  Result := (ANode <> nil) and ((ANode = Selected) or ANode.MultiSelected);
end;

{ 選んでいるノードを、見える順に集める }
procedure TCFileTree.GetSelectedNodes(AList: TList);
var
  I, J: Integer;
  N: TTreeNode;
begin
  AList.Clear;
  if SelectionCount > 0 then
  begin
    for I := 0 to Integer(SelectionCount) - 1 do AList.Add(Selections[I]);
  end
  else if Selected <> nil then
    AList.Add(Selected);
  // 見える順（AbsoluteIndex の昇順）に並べる
  for I := 1 to AList.Count - 1 do
  begin
    N := TTreeNode(AList[I]);
    J := I - 1;
    while (J >= 0) and (TTreeNode(AList[J]).AbsoluteIndex > N.AbsoluteIndex) do
    begin
      AList[J + 1] := AList[J];
      Dec(J);
    end;
    AList[J + 1] := N;
  end;
end;

function TCFileTree.SelectedPath: string;
begin
  Result := GetPathFromNode(Selected);
end;

procedure TCFileTree.GetSelectedPaths(APaths: TStrings);
var
  L: TList;
  I: Integer;
begin
  APaths.Clear;
  L := TList.Create;
  try
    GetSelectedNodes(L);
    for I := 0 to L.Count - 1 do APaths.Add(GetPathFromNode(TTreeNode(L[I])));
  finally
    L.Free;
  end;
end;

{ 選べるのは、同じフォルダーの中の項目だけ。選んだものの親が違うものは、選択から外す }
procedure TCFileTree.DoSelectionChanged;
var
  L: TList;
  I: Integer;
  Sel: TTreeNode;
begin
  if (not FInFixSelection) and (SelectionCount > 1) then
  begin
    FInFixSelection := True;
    L := TList.Create;
    try
      Sel := Selected;
      if Sel <> nil then
      begin
        for I := 0 to Integer(SelectionCount) - 1 do L.Add(Selections[I]);
        for I := 0 to L.Count - 1 do
          if (TTreeNode(L[I]) <> Sel) and (TTreeNode(L[I]).Parent <> Sel.Parent) then
            TTreeNode(L[I]).MultiSelected := False;
      end;
    finally
      L.Free;
      FInFixSelection := False;
    end;
  end;
  inherited DoSelectionChanged;
end;

{ ------------------------------------------------------------------ }
{ アイコン                                                             }
{ ------------------------------------------------------------------ }

function TCFileTree.NodeIconIndex(ANode: TCFileNode): Integer;
var
  SFI: TCFtSHFileInfoW;
  W: UnicodeString;
  Ext, CacheKey: string;
  H: PtrUInt;
  CPos: Integer;
begin
  if ANode.IconLoaded then Exit(ANode.IconIndex);
  Result := -1;
  SFI := Default(TCFtSHFileInfoW);
  H := 0;
  CacheKey := '';   // 空でなければ、取れた番号をこの名前で覚える
  if ANode.IsDir then
    CacheKey := '\folder'
  else
  begin
    Ext := LowerCase(ExtractFileExt(ANode.Text));
    // .exe・.ico・.lnk はファイルごとにアイコンが違うので、覚えない
    if not ((Ext = '.exe') or (Ext = '.ico') or (Ext = '.lnk')) then
      CacheKey := 'x' + Ext;
  end;

  if (CacheKey <> '') and FIconCache.Find(CacheKey, CPos) then
    Result := PtrInt(FIconCache.Objects[CPos])
  else
  begin
    if ANode.IsDir then
    begin
      // フォルダー：ディスクに触れない一般のフォルダーのアイコン
      W := 'folder';
      H := _SHGetFileInfoW(PWideChar(W), FILE_ATTRIBUTE_DIRECTORY, SFI, SizeOf(SFI),
        CFtSHGFI_SYSICONINDEX or CFtSHGFI_SMALLICON or CFtSHGFI_USEFILEATTRIBUTES);
    end
    else if CacheKey = '' then
    begin
      // ファイルごとのアイコン
      W := UTF8Decode(GetPathFromNode(ANode));
      H := _SHGetFileInfoW(PWideChar(W), 0, SFI, SizeOf(SFI),
        CFtSHGFI_SYSICONINDEX or CFtSHGFI_SMALLICON);
    end
    else
    begin
      // 拡張子ごと：ディスクに触れない
      W := UTF8Decode(CacheKey);
      H := _SHGetFileInfoW(PWideChar(W), FILE_ATTRIBUTE_NORMAL, SFI, SizeOf(SFI),
        CFtSHGFI_SYSICONINDEX or CFtSHGFI_SMALLICON or CFtSHGFI_USEFILEATTRIBUTES);
    end;
    if H <> 0 then
    begin
      if FSysSmallImages = 0 then FSysSmallImages := HIMAGELIST(H);
      Result := SFI.iIcon;
      if CacheKey <> '' then FIconCache.AddObject(CacheKey, TObject(PtrInt(Result)));
    end;
  end;
  ANode.IconIndex := Result;
  ANode.IconLoaded := True;
end;

function TCFileTree.GetBuiltinIconSize: TSize;
begin
  Result.cx := GetSystemMetrics(SM_CXSMICON);
  Result.cy := GetSystemMetrics(SM_CYSMICON);
end;

function TCFileTree.DrawBuiltinIcon(ANode: TTreeNode; ARect: TRect): TSize;
var
  Idx, CX, CY, Y: Integer;
begin
  if not (ANode is TCFileNode) then
  begin
    Result := inherited DrawBuiltinIcon(ANode, ARect);
    Exit;
  end;
  Result := GetBuiltinIconSize;
  Idx := NodeIconIndex(TCFileNode(ANode));
  if (Idx < 0) or (FSysSmallImages = 0) then Exit;
  CX := 16;
  CY := 16;
  ImageList_GetIconSize(FSysSmallImages, CX, CY);
  Y := ARect.Top + ((ARect.Bottom - ARect.Top) - CY) div 2;
  ImageList_Draw(FSysSmallImages, Idx, Canvas.Handle, ARect.Left, Y, ILD_TRANSPARENT);
end;

{ ------------------------------------------------------------------ }
{ 変更通知                                                             }
{ ------------------------------------------------------------------ }

{ --- 監視のスレッド --- }

constructor TCFtWatcher.Create(const ARoot: string; AWnd: HWND);
begin
  FRoot := ARoot;
  FWnd := AWnd;
  FLock := TCriticalSection.Create;
  FPaths := TStringList.Create;
  FPaths.CaseSensitive := False;
  FPaths.Sorted := True;
  FPaths.Duplicates := dupIgnore;
  // 監視するフォルダーを開く（FILE_FLAG_BACKUP_SEMANTICS が無いと、フォルダーは開けない）
  FDir := CreateFileW(PWideChar(ShellLongPathW(ARoot)), CFtFILE_LIST_DIRECTORY,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING,
    FILE_FLAG_BACKUP_SEMANTICS, 0);
  inherited Create(False);
end;

destructor TCFtWatcher.Destroy;
begin
  if FDir <> INVALID_HANDLE_VALUE then CloseHandle(FDir);
  FPaths.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TCFtWatcher.AddPath(const AParent: string);
begin
  FLock.Enter;
  try
    if FPaths.Count >= CFtMaxQueued then
      FOverflow := True   // 多すぎる：個別に覚えず、全体の更新にする
    else
      FPaths.Add(AParent);
  finally
    FLock.Leave;
  end;
end;

{ 受け取る側に知らせる（取り出されるまでは、1回だけ） }
procedure TCFtWatcher.PostNudge;
var
  DoPost: Boolean;
begin
  FLock.Enter;
  try
    DoPost := not FPosted;
    FPosted := True;
  finally
    FLock.Leave;
  end;
  if DoPost then PostMessage(FWnd, WM_CFT_WATCH, 0, 0);
end;

procedure TCFtWatcher.TakePaths(ADest: TStrings; out AOverflow: Boolean);
begin
  FLock.Enter;
  try
    ADest.Assign(FPaths);
    FPaths.Clear;
    AOverflow := FOverflow;
    FOverflow := False;
    FPosted := False;
  finally
    FLock.Leave;
  end;
end;

procedure TCFtWatcher.Execute;
const
  // 増減・名前の変更だけ（ファイルの中身・日付の変更は、表示に関係ないので受けない）
  Filter = CFtFILE_NOTIFY_CHANGE_FILE_NAME or CFtFILE_NOTIFY_CHANGE_DIR_NAME;
var
  Buf: array[0..CFtWatchBufBytes - 1] of Byte;
  Bytes: DWORD;
  P: PByte;
  Info: PFtNotifyInfo;
  W: UnicodeString;
  Full: string;
  Fails: Integer;
begin
  Fails := 0;
  if FDir = INVALID_HANDLE_VALUE then
    Fails := 5   // 開けなかった：全体の更新を頼んで終わる
  else
    while not Terminated do
    begin
      Bytes := 0;
      if _ReadDirectoryChangesW(FDir, @Buf[0], SizeOf(Buf), True, Filter, @Bytes, nil, nil) then
      begin
        Fails := 0;
        if Bytes = 0 then
        begin
          // バッファがあふれた：個別には分からないので、全体の更新にする
          FLock.Enter;
          try
            FOverflow := True;
          finally
            FLock.Leave;
          end;
        end
        else
        begin
          P := @Buf[0];
          repeat
            Info := PFtNotifyInfo(P);
            SetString(W, PWideChar(@Info^.FileName[0]), Info^.FileNameLength div SizeOf(WideChar));
            Full := IncludeTrailingPathDelimiter(FRoot) + UTF8Encode(W);
            AddPath(FtTrimTail(ExtractFileDir(Full)));   // 子の増減が起きる場所＝親フォルダー
            if Info^.NextEntryOffset = 0 then Break;
            Inc(P, Info^.NextEntryOffset);
          until False;
        end;
        PostNudge;
      end
      else
      begin
        if Terminated then Break;
        Inc(Fails);
        if Fails >= 5 then Break;   // 根が消えた・取り外された等
        Sleep(200);
      end;
    end;
  if (Fails >= 5) and not Terminated then
  begin
    FLock.Enter;
    try
      FOverflow := True;
    finally
      FLock.Leave;
    end;
    PostNudge;
  end;
end;

{ 止める。読み取りの待ちを取り消して、スレッドの終わりまで待つ }
procedure TCFtWatcher.Stop;
begin
  Terminate;
  if FDir <> INVALID_HANDLE_VALUE then
    // 取り消しが、読み取りを始める前に当たることがあるので、終わるまで繰り返す
    repeat
      _CancelIoEx(FDir, nil);
    until WaitForSingleObject(Handle, 50) = WAIT_OBJECT_0
  else
    WaitFor;
end;

{ --- TCFileTree 側 --- }

procedure TCFileTree.StartWatch;
begin
  StopWatch;
  if csDesigning in ComponentState then Exit;
  if not HandleAllocated then Exit;
  if (FRootPath = '') or not DirectoryExists(FRootPath) then Exit;
  // 根のフォルダー配下全体を、サブフォルダーも含めて1つのスレッドで監視する
  FWatcher := TCFtWatcher.Create(FRootPath, Handle);
end;

procedure TCFileTree.StopWatch;
begin
  if FWatcher <> nil then
  begin
    FWatcher.Stop;
    FreeAndNil(FWatcher);
  end;
end;

procedure TCFileTree.WndProc(var Message: TLMessage);
begin
  if Message.Msg = WM_CFT_WATCH then
  begin
    HandleWatch;
    Message.Result := 0;
    Exit;
  end;
  inherited WndProc(Message);
end;

{ 監視のスレッドから知らされた、変わったフォルダー（親）を、更新の候補にする }
procedure TCFileTree.HandleWatch;
var
  L: TStringList;
  Over: Boolean;
  I: Integer;
begin
  if (FWatcher = nil) or (csDestroying in ComponentState) then Exit;
  L := TStringList.Create;
  try
    FWatcher.TakePaths(L, Over);
    if Over then FRefreshAll := True;
    if not FRefreshAll then
      for I := 0 to L.Count - 1 do
        if FindNodeByPath(L[I]) <> nil then   // まだ読み込んでいないフォルダーの変更は捨てる（開いたときに最新を読む）
          FPendingPaths.Add(L[I]);
    if FPendingPaths.Count > CFtMaxPending then
    begin
      FPendingPaths.Clear;
      FRefreshAll := True;
    end;
    if FRefreshAll or (FPendingPaths.Count > 0) then
    begin
      // 最後の通知から一定時間待って1回だけ更新する（タイマーを掛け直す）
      FNotifyTimer.Enabled := False;
      FNotifyTimer.Enabled := True;
    end;
  finally
    L.Free;
  end;
end;

procedure TCFileTree.NotifyTimerTick({%H-}Sender: TObject);
var
  Targets: TStringList;
  All: Boolean;
begin
  // 名前の編集中・ドラッグ中・更新中は保留（タイマーは止めず、次の周期で再判定する）
  // （ドロップ先として強調表示中のノードが作り直されないよう、ほかからのドラッグ中も保留）
  if IsEditing or Dragging or FIsRefreshing or ShellDragIsActive or FOleDragOver then Exit;
  FNotifyTimer.Enabled := False;
  if csDestroying in ComponentState then Exit;
  All := FRefreshAll;
  FRefreshAll := False;
  Targets := TStringList.Create;
  try
    Targets.Assign(FPendingPaths);
    FPendingPaths.Clear;
    if All or (Targets.Count > 0) then
      ApplyRefresh(Targets, All);
  finally
    Targets.Free;
  end;
end;

{ ------------------------------------------------------------------ }
{ ファイル・フォルダーの操作                                             }
{ ------------------------------------------------------------------ }

{ 選んでいる項目のパスを集める。空か、根を含むときは False }
function TCFileTree.SelectedItemPaths(APaths: TStrings): Boolean;
var
  L: TList;
  I: Integer;
begin
  Result := False;
  APaths.Clear;
  L := TList.Create;
  try
    GetSelectedNodes(L);
    if L.Count = 0 then Exit;
    for I := 0 to L.Count - 1 do
    begin
      if IsRootNode(TTreeNode(L[I])) then Exit;
      APaths.Add(GetPathFromNode(TTreeNode(L[I])));
    end;
    Result := True;
  finally
    L.Free;
  end;
end;

procedure TCFileTree.CopySelected;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    if SelectedItemPaths(L) then ShellInvokeVerbOnItems(Handle, L, 'copy');
  finally
    L.Free;
  end;
end;

procedure TCFileTree.CutSelected;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    if SelectedItemPaths(L) then ShellInvokeVerbOnItems(Handle, L, 'cut');
  finally
    L.Free;
  end;
end;

procedure TCFileTree.PasteToSelected;
var
  F: string;
begin
  F := FolderPathOf(Selected);
  if (F <> '') and DirectoryExists(F) then ShellInvokeVerbOnFolder(Handle, F, 'paste');
end;

procedure TCFileTree.DeleteSelected(APermanent: Boolean);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    // 確認はシェルが出す。ごみ箱に入れる（Shift を押したときは完全に削除）
    if SelectedItemPaths(L) then ShellInvokeVerbOnItems(Handle, L, 'delete', APermanent);
  finally
    L.Free;
  end;
end;

function TCFileTree.CanEdit(Node: TTreeNode): Boolean;
begin
  Result := inherited CanEdit(Node) and not IsRootNode(Node);
end;

procedure TCFileTree.RenameSelected;
begin
  if (SelectionCount > 1) or (Selected = nil) or IsRootNode(Selected) then Exit;
  Selected.EditText;
end;

procedure TCFileTree.InternalOnEdited({%H-}Sender: TObject; Node: TTreeNode; var S: string);
var
  OldPath, NewPath, ParentDir: string;
  Info: PFtRenameInfo;
begin
  if Node = nil then Exit;
  if (S = '') or IsRootNode(Node) or (S = Node.Text) then
  begin
    S := Node.Text;
    Exit;
  end;
  // 禁則文字
  if ContainsInvalidChar(S) then
  begin
    ShowMessage(CXT(sFtErrBadChars) + sLineBreak + '\ / : * ? " < > |');
    S := Node.Text;
    Exit;
  end;
  // 変更前のパスは、ノードの実際のパスから取る（この時点で Node.Text はまだ古い名前）
  OldPath := GetPathFromNode(Node);
  if OldPath = '' then Exit;
  ParentDir := ExtractFilePath(OldPath);
  NewPath := IncludeTrailingPathDelimiter(ParentDir) + S;
  if NewPath <> OldPath then
  begin
    New(Info);
    Info^.OldPath := OldPath;
    Info^.NewPath := NewPath;
    Info^.ParentPath := ParentDir;
    // 実際の名前の変更も非同期で行う（編集終了の処理と競合させない）
    {$push}{$hints off}
    Application.QueueAsyncCall(@DoAsyncRename, PtrInt(Info));
    {$pop}
  end;
end;

procedure TCFileTree.DoAsyncRename(Data: PtrInt);
var
  Info: PFtRenameInfo;
begin
  {$push}{$hints off}
  Info := PFtRenameInfo(Data);
  {$pop}
  try
    if csDestroying in ComponentState then Exit;
    // シェル経由で名前を変更する（使用中などで失敗した場合は、シェルが理由を出す）。
    // 成功したときの表示の更新は、フォルダーの変更通知に任せる
    if not ShellRenameItem(Handle, Info^.OldPath, ExtractFileName(Info^.NewPath)) then
    begin
      // 失敗したら、編集で変わったノードの表示を戻すため、親フォルダーを読み直す
      FPendingPaths.Add(FtTrimTail(Info^.ParentPath));
      FNotifyTimer.Enabled := False;
      FNotifyTimer.Enabled := True;
    end;
  finally
    Dispose(Info);
  end;
end;

procedure TCFileTree.NewFolder;
var
  ParentDir, Base, Cand: string;
  PNode, Child: TTreeNode;
  N: Integer;
begin
  ParentDir := FolderPathOf(Selected);
  if (ParentDir = '') or not DirectoryExists(ParentDir) then Exit;
  // 名前：新しいフォルダー、実在すれば ' (2)'、' (3)'… を付けた、まだ無いもの
  Base := CXT(sBmNewFolder);
  Cand := Base;
  N := 2;
  while FileExists(IncludeTrailingPathDelimiter(ParentDir) + Cand) or
        DirectoryExists(IncludeTrailingPathDelimiter(ParentDir) + Cand) do
  begin
    Cand := Base + ' (' + IntToStr(N) + ')';
    Inc(N);
  end;
  Cand := IncludeTrailingPathDelimiter(ParentDir) + Cand;
  if not CreateDirectoryW(PWideChar(ShellLongPathW(Cand)), nil) then
  begin
    ShowMessage(Format(CXT(sFtErrCreateFolder), [Cand]));
    Exit;
  end;
  // 表示：作る先を開いて、読み直し、作ったフォルダーを選んで名前の編集を始める
  PNode := FindNodeByPath(ParentDir);
  if PNode = nil then Exit;
  PNode.Expand(False);
  MergeChildren(PNode);
  Child := FindNodeByPath(Cand);
  if Child = nil then Exit;
  ClearSelection;
  Selected := Child;
  Child.MakeVisible;
  FNewFolderPath := Cand;
  Application.QueueAsyncCall(@DoAsyncEdit, 0);
end;

procedure TCFileTree.DoAsyncEdit(Data: PtrInt);
var
  N: TTreeNode;
begin
  if csDestroying in ComponentState then Exit;
  if FNewFolderPath = '' then Exit;
  N := FindNodeByPath(FNewFolderPath);
  FNewFolderPath := '';
  if (N <> nil) and CanFocus then
  begin
    SetFocus;
    N.EditText;
  end;
end;

{ ------------------------------------------------------------------ }
{ 開く                                                                 }
{ ------------------------------------------------------------------ }

{ テキストとして開くファイルのパス（なければ ''）。.lnk はリンク先がテキストのときそのパス }
function TCFileTree.TextTargetOf(const APath: string): string;
var
  Ext, T: string;
begin
  Result := '';
  Ext := LowerCase(ExtractFileExt(APath));
  if Ext = '.url' then Exit;
  if Ext = '.lnk' then
  begin
    T := FtResolveLink(APath);
    if (T <> '') and FileExists(T) and FtIsTextFile(T) then Result := T;
    Exit;
  end;
  if FileExists(APath) and FtIsTextFile(APath) then Result := APath;
end;

{ Web で開く URL（なければ ''）。.url は中の URL、.lnk はリンク先が http(s) のときだけ、ほかは file:/// }
function TCFileTree.WebUrlOf(const APath: string): string;
var
  Ext, T: string;
begin
  Result := '';
  Ext := LowerCase(ExtractFileExt(APath));
  if Ext = '.url' then
    Result := FtReadUrlFile(APath)
  else if Ext = '.lnk' then
  begin
    T := FtResolveLink(APath);
    if FtIsWebUrl(T) then Result := T;
  end
  else
    Result := FtPathToFileUrl(APath);
end;

{ 関連付けのプログラムで開く（OS の設定にまかせる） }
procedure TCFileTree.ExecuteAssociated(const APath: string);
var
  W, Dir, Verb: UnicodeString;
  R: PtrUInt;
begin
  W := UTF8Decode(APath);
  Dir := UTF8Decode(ExtractFilePath(APath));
  Verb := 'open';
  R := PtrUInt(ShellExecuteW(0, PWideChar(Verb), PWideChar(W), nil, PWideChar(Dir), SW_SHOWNORMAL));
  if R <= 32 then
    ShowMessage(Format(CXT(sBmOpenError), [APath + ' : ' + IntToStr(R)]));
end;

procedure TCFileTree.OpenInEditor(const APath: string; ANewTab: Boolean; AEditor: TControl);
var
  I: Integer;
begin
  if (AEditor = nil) or (APath = '') then Exit;
  try
    if ANewTab then
    begin
      // すでに開いていれば、そのタブへ切り替えるだけ（エディターの決まり）
      if EdOpenFile(AEditor, APath) >= 0 then EdFocus(AEditor);
      Exit;
    end;
    // 1. どこかのタブで開いていれば、そのタブにする
    I := EdFindPage(AEditor, APath);
    if I >= 0 then
    begin
      EdSetActive(AEditor, I);
      EdFocus(AEditor);
      Exit;
    end;
    // 2. 表示中のタブが未保存なら聞く。はい＝新しいタブ、いいえ＝開かない
    if EdModified(AEditor) then
    begin
      if MessageDlg(CXT(sBmUnsaved), mtConfirmation, [mbYes, mbNo], 0) = mrYes then
        if EdOpenFile(AEditor, APath) >= 0 then EdFocus(AEditor);
      Exit;
    end;
    // 3. 表示中のタブに読み込む
    if EdLoadFile(AEditor, APath) then EdFocus(AEditor);
  except
    on E: Exception do ShowMessage(Format(CXT(sBmOpenError), [APath + ' : ' + E.Message]));
  end;
end;

procedure TCFileTree.OpenInBrowser(const AUrl: string; ANewTab: Boolean; ABrowser: TCTabBrowser);
begin
  if (ABrowser = nil) or (AUrl = '') then Exit;
  try
    if ANewTab or (ABrowser.Count = 0) then
      ABrowser.Add(AUrl)
    else
      ABrowser.Navigate(AUrl);
  except
    on E: Exception do ShowMessage(Format(CXT(sBmOpenError), [AUrl + ' : ' + E.Message]));
  end;
end;

{ ダブルクリック・Enter で開く }
procedure TCFileTree.OpenNodeByDefault(ANode: TTreeNode);
var
  P, Ext, T, U: string;
begin
  if (ANode = nil) or IsDirNode(ANode) then Exit;
  P := GetPathFromNode(ANode);
  if not FileExists(P) then
  begin
    ShowMessage(Format(CXT(sBmFileMissing), [P]));
    Exit;
  end;
  Ext := LowerCase(ExtractFileExt(P));
  if Ext = '.url' then
  begin
    U := FtReadUrlFile(P);
    if U = '' then Exit;
    if FTargetBrowser <> nil then OpenInBrowser(U, False, FTargetBrowser)
    else ExecuteAssociated(P);
  end
  else if Ext = '.lnk' then
  begin
    T := FtResolveLink(P);
    if FtIsWebUrl(T) and (FTargetBrowser <> nil) then
      OpenInBrowser(T, False, FTargetBrowser)
    else if (T <> '') and (FTargetEditor <> nil) and FileExists(T) and FtIsTextFile(T) then
      OpenInEditor(T, False, FTargetEditor)
    else
      ExecuteAssociated(P);
  end
  else if (FTargetEditor <> nil) and FtIsTextFile(P) then
    OpenInEditor(P, False, FTargetEditor)
  else
    ExecuteAssociated(P);
end;

procedure TCFileTree.DblClick;
var
  Pt: TPoint;
  N: TTreeNode;
begin
  inherited DblClick;
  Pt := ScreenToClient(Mouse.CursorPos);
  N := GetNodeAt(Pt.X, Pt.Y);
  if (N <> nil) and not IsDirNode(N) then OpenNodeByDefault(N);
end;

{ ------------------------------------------------------------------ }
{ キー                                                                 }
{ ------------------------------------------------------------------ }

procedure TCFileTree.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if IsEditing then
  begin
    inherited KeyDown(Key, Shift);
    Exit;
  end;
  if ssCtrl in Shift then
    case Key of
      Ord('C'): begin CopySelected; Key := 0; Exit; end;
      Ord('X'): begin CutSelected; Key := 0; Exit; end;
      Ord('V'): begin PasteToSelected; Key := 0; Exit; end;
    end;
  case Key of
    VK_F2: begin RenameSelected; Key := 0; end;
    VK_DELETE: begin DeleteSelected(ssShift in Shift); Key := 0; end;
    VK_F5: begin RefreshTree; Key := 0; end;
    VK_RETURN:
      if (Selected <> nil) and not IsDirNode(Selected) then
      begin
        OpenNodeByDefault(Selected);
        Key := 0;
      end;
  end;
  if Key <> 0 then inherited KeyDown(Key, Shift);
end;

{ ------------------------------------------------------------------ }
{ 右クリックメニュー                                                     }
{ ------------------------------------------------------------------ }

procedure TCFileTree.BuildMenu;

  procedure Add(AId: TCFtMenu; AText: string; ACheck: Boolean);
  var
    M: TMenuItem;
  begin
    M := TMenuItem.Create(FMenu);
    M.Caption := AText;
    M.Tag := Ord(AId);
    M.OnClick := @MenuClick;
    M.ShowAlwaysCheckable := ACheck;
    FMenu.Items.Add(M);
    FMenuItems[AId] := M;
  end;

  procedure Sep;
  var
    M: TMenuItem;
  begin
    M := TMenuItem.Create(FMenu);
    M.Caption := '-';
    FMenu.Items.Add(M);
  end;

begin
  FMenu := TPopupMenu.Create(Self);
  Add(fmCopy, CXT(sFtMenuCopy), False);
  Add(fmCut, CXT(sFtMenuCut), False);
  Add(fmPaste, CXT(sFtMenuPaste), False);
  Add(fmRename, CXT(sFtMenuRename), False);
  Add(fmDelete, CXT(sFtMenuDelete), False);
  Sep;
  Add(fmShowInExplorer, CXT(sFtMenuShowInExplorer), False);
  Add(fmCopyPath, CXT(sFtMenuCopyPath), False);
  Sep;
  Add(fmNewFolder, CXT(sFtMenuNewFolder), False);
  Sep;
  Add(fmTextOpen, CXT(sFtMenuTextOpen), False);
  Add(fmTextOpenNew, CXT(sFtMenuTextOpenNew), False);
  Add(fmTextSide, CXT(sFtMenuSide), False);
  Sep;
  Add(fmWebOpen, CXT(sFtMenuWebOpen), False);
  Add(fmWebOpenNew, CXT(sFtMenuWebOpenNew), False);
  Add(fmWebSide, CXT(sFtMenuSide), False);
  Sep;
  Add(fmOpenProgram, CXT(sFtMenuOpenProgram), False);
  Sep;
  Add(fmShowHidden, CXT(sFtMenuShowHidden), True);
  Sep;
  Add(fmWindowsMenu, CXT(sFtMenuWindowsMenu), False);
end;

{ 選択に合わせて、項目を使える・使えないにする }
procedure TCFileTree.UpdateMenuState;
var
  L: TList;
  N, I: Integer;
  HasRoot, IsFile: Boolean;
  First: TTreeNode;
  P: string;
  ClipOk: Boolean;
begin
  L := TList.Create;
  try
    GetSelectedNodes(L);
    N := L.Count;
    HasRoot := False;
    First := nil;
    if N > 0 then First := TTreeNode(L[0]);
    for I := 0 to N - 1 do
      if IsRootNode(TTreeNode(L[I])) then HasRoot := True;
  finally
    L.Free;
  end;
  IsFile := (N = 1) and (First <> nil) and not IsDirNode(First);
  P := '';
  if IsFile then P := GetPathFromNode(First);
  ClipOk := IsClipboardFormatAvailable(CF_HDROP);

  FMenuItems[fmCopy].Enabled := (N >= 1) and not HasRoot;
  FMenuItems[fmCut].Enabled := (N >= 1) and not HasRoot;
  FMenuItems[fmPaste].Enabled := ClipOk and (FRootPath <> '');
  FMenuItems[fmRename].Enabled := (N = 1) and not HasRoot;
  FMenuItems[fmDelete].Enabled := (N >= 1) and not HasRoot;
  FMenuItems[fmShowInExplorer].Enabled := N >= 1;
  FMenuItems[fmCopyPath].Enabled := N >= 1;
  FMenuItems[fmNewFolder].Enabled := (FRootPath <> '') and DirectoryExists(FRootPath);
  FMenuItems[fmTextOpen].Enabled := IsFile and (FTargetEditor <> nil) and (TextTargetOf(P) <> '');
  FMenuItems[fmTextOpenNew].Enabled := FMenuItems[fmTextOpen].Enabled;
  FMenuItems[fmTextSide].Enabled := IsFile and (FSideEditor <> nil) and (TextTargetOf(P) <> '');
  FMenuItems[fmWebOpen].Enabled := IsFile and (FTargetBrowser <> nil) and (WebUrlOf(P) <> '');
  FMenuItems[fmWebOpenNew].Enabled := FMenuItems[fmWebOpen].Enabled;
  FMenuItems[fmWebSide].Enabled := IsFile and (FSideBrowser <> nil) and (WebUrlOf(P) <> '');
  FMenuItems[fmOpenProgram].Enabled := IsFile;
  FMenuItems[fmShowHidden].Enabled := True;
  FMenuItems[fmShowHidden].Checked := FShowHidden;
  FMenuItems[fmWindowsMenu].Enabled := N >= 1;
end;

procedure TCFileTree.MenuClick(Sender: TObject);
var
  Id: TCFtMenu;
  L: TStringList;
  P, T, U, S: string;
  W, Dir, Verb, Params: UnicodeString;
  I: Integer;
begin
  Id := TCFtMenu(TMenuItem(Sender).Tag);
  P := SelectedPath;
  case Id of
    fmCopy: CopySelected;
    fmCut: CutSelected;
    fmPaste: PasteToSelected;
    fmRename: RenameSelected;
    fmDelete: DeleteSelected(False);
    fmShowInExplorer:
      if P <> '' then
      begin
        Verb := 'open';
        if IsDirNode(Selected) then
        begin
          W := UTF8Decode(P);
          ShellExecuteW(0, PWideChar(Verb), PWideChar(W), nil, nil, SW_SHOWNORMAL);
        end
        else
        begin
          W := 'explorer.exe';
          Params := '/select,"' + UTF8Decode(P) + '"';
          ShellExecuteW(0, PWideChar(Verb), PWideChar(W), PWideChar(Params), nil, SW_SHOWNORMAL);
        end;
      end;
    fmCopyPath:
      begin
        L := TStringList.Create;
        try
          GetSelectedPaths(L);
          S := '';
          for I := 0 to L.Count - 1 do
          begin
            if I > 0 then S := S + LineEnding;
            S := S + L[I];
          end;
          if S <> '' then Clipboard.AsText := S;
        finally
          L.Free;
        end;
      end;
    fmNewFolder: NewFolder;
    fmTextOpen: OpenInEditor(TextTargetOf(P), False, FTargetEditor);
    fmTextOpenNew: OpenInEditor(TextTargetOf(P), True, FTargetEditor);
    fmTextSide:
      begin
        T := TextTargetOf(P);
        if (T <> '') and (FSideEditor <> nil) then
        begin
          FSideEditor.Visible := True;
          OpenInEditor(T, True, FSideEditor);
        end;
      end;
    fmWebOpen: OpenInBrowser(WebUrlOf(P), False, FTargetBrowser);
    fmWebOpenNew: OpenInBrowser(WebUrlOf(P), True, FTargetBrowser);
    fmWebSide:
      begin
        U := WebUrlOf(P);
        if (U <> '') and (FSideBrowser <> nil) then
        begin
          FSideBrowser.Visible := True;
          OpenInBrowser(U, True, FSideBrowser);
        end;
      end;
    fmOpenProgram:
      if P <> '' then
      begin
        W := UTF8Decode(P);
        Dir := UTF8Decode(ExtractFilePath(P));
        Verb := 'open';
        ShellExecuteW(0, PWideChar(Verb), PWideChar(W), nil, PWideChar(Dir), SW_SHOWNORMAL);
      end;
    fmShowHidden: ShowHidden := not FShowHidden;
    fmWindowsMenu:
      begin
        L := TStringList.Create;
        try
          GetSelectedPaths(L);
          DisplayShellContextMenu(L, FMenuPos);
        finally
          L.Free;
        end;
      end;
  end;
end;

procedure TCFileTree.DoContextPopup(MousePos: TPoint; var Handled: Boolean);
var
  Node: TTreeNode;
  R: TRect;
begin
  Handled := True;   // 部品の PopupMenu は使わない
  if (MousePos.X < 0) or (MousePos.Y < 0) then
  begin
    // キーボード（メニューキー）：選んでいるノードの位置に出す
    Node := Selected;
    if Node <> nil then
    begin
      R := Node.DisplayRect(True);
      MousePos.X := R.Left + 8;
      MousePos.Y := R.Bottom;
    end
    else
    begin
      MousePos.X := 8;
      MousePos.Y := 8;
    end;
  end
  else
    Node := GetNodeAt(MousePos.X, MousePos.Y);

  // マウスの下のノードが選択に入っていなければ、そのノードだけを選ぶ（入っていれば選択はそのまま）
  if Node = nil then
    ClearSelection
  else if not IsNodeSelected(Node) then
  begin
    ClearSelection;
    Selected := Node;
  end;
  FMenuPos := ClientToScreen(MousePos);
  UpdateMenuState;
  FMenu.PopUp(FMenuPos.X, FMenuPos.Y);
end;

function TCFileTree.GetPIDLFromPath(const APath: string): PItemIDList;
var
  DesktopFolder: IShellFolder;
  Eaten, Attr: ULONG;
  WidePath: WideString;
begin
  Result := nil;
  Attr := 0;
  if Succeeded(SHGetDesktopFolder(DesktopFolder)) then
  begin
    WidePath := WideString(APath);
    DesktopFolder.ParseDisplayName(0, nil, PWideChar(WidePath), Eaten, Result, Attr);
  end;
end;

{ 項目メニューには「新規作成」が無い（背景のメニューにしか無い）ので、標準の「新規作成」（CNewMenu）を
  AFolder を作る先にして作り、AMenu の最後の項目（プロパティ）の前に差し込む。差し込めたら、コマンドを実行するための
  IContextMenu を返す（コマンドIDは CFtNewFirstId〜CFtNewLastId）。できなければ nil }
function TCFileTree.AddNewSubmenu(AMenu: HMENU; const AFolder: string): IContextMenu;
var
  Unk: IUnknown;
  CM: IContextMenu;
  Init: IFtShellExtInit;
  CM2: IFtContextMenu2;
  PIDL: PItemIDList;
  Tmp: HMENU;
  MI: MENUITEMINFOW;
  Buf: array[0..255] of WideChar;
  At: Integer;
begin
  Result := nil;
  PIDL := GetPIDLFromPath(AFolder);
  if PIDL = nil then Exit;
  try
    if Failed(_CoCreateInstance(CLSID_FtNewMenu, nil, CLSCTX_INPROC_SERVER, IUnknown, Unk)) then Exit;
    if Failed(Unk.QueryInterface(IContextMenu, CM)) then Exit;
    if Failed(Unk.QueryInterface(IFtShellExtInit, Init)) then Exit;
    if Failed(Init.Initialize(PIDL, nil, 0)) then Exit;   // 作る先のフォルダー
    Tmp := CreatePopupMenu;
    if Tmp = 0 then Exit;
    try
      if Failed(CM.QueryContextMenu(Tmp, 0, CFtNewFirstId, CFtNewLastId, CMF_NORMAL)) then Exit;
      FillChar(MI, SizeOf(MI), 0);
      FillChar(Buf, SizeOf(Buf), 0);
      MI.cbSize := SizeOf(MI);
      MI.fMask := MIIM_STRING or MIIM_SUBMENU;
      MI.dwTypeData := @Buf[0];
      MI.cch := Length(Buf) - 1;
      if not GetMenuItemInfoW(Tmp, 0, True, @MI) then Exit;
      if MI.hSubMenu = 0 then Exit;
      // サブメニューの中身（フォルダー・ショートカット・テキスト ドキュメント…）は、開く前にシェルに作らせておく
      if Succeeded(CM.QueryInterface(IFtContextMenu2, CM2)) then
        CM2.HandleMenuMsg(WM_INITMENUPOPUP, WPARAM(MI.hSubMenu), 0);
      RemoveMenu(Tmp, 0, MF_BYPOSITION);   // サブメニューを壊さずに外す
      At := GetMenuItemCount(AMenu) - 1;
      if At < 0 then At := 0;
      InsertMenuW(AMenu, At, MF_BYPOSITION or MF_POPUP or MF_STRING, UINT_PTR(MI.hSubMenu), @Buf[0]);
      InsertMenuW(AMenu, At + 1, MF_BYPOSITION or MF_SEPARATOR, 0, nil);
      Result := CM;
    finally
      DestroyMenu(Tmp);
    end;
  finally
    CoTaskMemFree(PIDL);
  end;
end;

{ エクスプローラーでその項目を右クリックしたときと同じメニューを出す（選んだ項目すべてに対して）。
  「送る」「新規作成」などは、共通部品の TrackShellContextMenu が IContextMenu2/3 で動かす }
procedure TCFileTree.DisplayShellContextMenu(APaths: TStrings; const AScreenPt: TPoint);
var
  ParentPIDL: PItemIDList;
  Fulls: array of PItemIDList;
  Children: array of PItemIDList;
  DesktopFolder, ParentFolder: IShellFolder;
  CM, NewCM: IContextMenu;
  HM: HMENU;
  Cmd: UINT;
  ParentPath, Verb, WorkDir: string;
  I, N: Integer;
  Ok: Boolean;
begin
  N := APaths.Count;
  if N = 0 then Exit;
  NewCM := nil;
  SetLength(Fulls, N);
  SetLength(Children, N);
  for I := 0 to N - 1 do Fulls[I] := nil;
  ParentPIDL := nil;
  try
    // 親フォルダー：ドライブの根なら「PC」、ほかは親のパス
    if (N = 1) and FtIsDriveRoot(APaths[0]) then
    begin
      _SHGetSpecialFolderLocation(0, CSIDL_DRIVES, ParentPIDL);
      WorkDir := APaths[0];
    end
    else
    begin
      ParentPath := ExtractFilePath(ExcludeTrailingPathDelimiter(APaths[0]));
      if ParentPath = '' then Exit;
      ParentPIDL := GetPIDLFromPath(ParentPath);
      WorkDir := ParentPath;
    end;
    if ParentPIDL = nil then Exit;
    if Failed(SHGetDesktopFolder(DesktopFolder)) then Exit;
    if Failed(DesktopFolder.BindToObject(ParentPIDL, nil, IID_IShellFolder, Pointer(ParentFolder))) then Exit;
    Ok := True;
    for I := 0 to N - 1 do
    begin
      Fulls[I] := GetPIDLFromPath(APaths[I]);
      if Fulls[I] = nil then begin Ok := False; Break; end;
      Children[I] := ILFindLastID(Fulls[I]);
    end;
    if not Ok then Exit;
    if Failed(ParentFolder.GetUIObjectOf(0, N, Children[0], IID_IContextMenu, nil, Pointer(CM))) then Exit;
    HM := CreatePopupMenu;
    if HM = 0 then Exit;
    try
      if Succeeded(CM.QueryContextMenu(HM, 0, 1, $7FFF, CMF_NORMAL)) then
      begin
        // フォルダー1つ（根も）を選んでいるときは、標準の「新規作成」を差し込む（項目のメニューには無いため）。
        // 作る先は、そのフォルダーの中
        if (N = 1) and DirectoryExists(APaths[0]) then
          NewCM := AddNewSubmenu(HM, APaths[0]);
        Cmd := TrackShellContextMenu(Handle, HM, CM, AScreenPt.X, AScreenPt.Y);
        if (Cmd >= CFtNewFirstId) and (Cmd <= CFtNewLastId) then
        begin
          // 「新規作成」の項目
          if NewCM <> nil then
            ShellInvokeMenuCommand(NewCM, Handle, Cmd - CFtNewFirstId, APaths[0]);
        end
        else if Cmd <> 0 then
        begin
          Verb := ShellMenuVerb(CM, Cmd - 1);
          if SameText(Verb, 'rename') then
            RenameSelected   // シェルの「名前の変更」はこの画面では動かないため、自前の名前変更にする
          else
            // エクスプローラーと同じく、作業フォルダーを渡して実行する（表示の更新は変更通知に任せる）
            ShellInvokeMenuCommand(CM, Handle, Cmd - 1, WorkDir);
        end;
      end;
    finally
      DestroyMenu(HM);
    end;
  finally
    for I := 0 to N - 1 do
      if Fulls[I] <> nil then CoTaskMemFree(Fulls[I]);
    if ParentPIDL <> nil then CoTaskMemFree(ParentPIDL);
  end;
end;

{ ------------------------------------------------------------------ }
{ ドラッグ＆ドロップ                                                     }
{ ------------------------------------------------------------------ }

procedure TCFileTree.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Node: TTreeNode;
  Saved: TList;
  I: Integer;
  Keep: Boolean;
begin
  FDragArmed := False;
  FClickPath := '';
  Node := GetNodeAt(X, Y);
  // 複数選択の中の項目を、修飾キーなしで押したときは、選択を保つ（ドラッグでまとめて動かせるように）。
  // 動かさずに離したら、その1つだけの選択にする（MouseUp）
  Keep := (Button = mbLeft) and ([ssCtrl, ssShift] * Shift = []) and (Node <> nil) and
          IsNodeSelected(Node) and (SelectionCount > 1) and not IsEditing;
  Saved := TList.Create;
  try
    if Keep then
      for I := 0 to Integer(SelectionCount) - 1 do Saved.Add(Selections[I]);
    inherited MouseDown(Button, Shift, X, Y);
    if Keep then
    begin
      FInFixSelection := True;
      try
        for I := 0 to Saved.Count - 1 do TTreeNode(Saved[I]).MultiSelected := True;
      finally
        FInFixSelection := False;
      end;
      FClickPath := GetPathFromNode(Node);
    end;
  finally
    Saved.Free;
  end;

  // 左・右ボタンで、編集中でなく、押した位置にノードがあり、根でなければ、ドラッグの準備
  if not (Button in [mbLeft, mbRight]) or IsEditing then Exit;
  if (Node = nil) or IsRootNode(Node) then Exit;
  FDragPaths.Clear;
  if IsNodeSelected(Node) then
    GetSelectedPaths(FDragPaths)
  else
    FDragPaths.Add(GetPathFromNode(Node));
  if FDragPaths.Count = 0 then Exit;
  FDragArmed := True;
  FDragButton := Button;
  FDragStartPt.X := X;
  FDragStartPt.Y := Y;
end;

procedure TCFileTree.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Effect: DWORD;
begin
  inherited MouseMove(Shift, X, Y);
  if not FDragArmed then Exit;
  if ((FDragButton = mbLeft) and not (ssLeft in Shift)) or
     ((FDragButton = mbRight) and not (ssRight in Shift)) then
  begin
    FDragArmed := False;
    Exit;
  end;
  // 一定距離動いたらドラッグ開始
  if (Abs(X - FDragStartPt.X) >= GetSystemMetrics(SM_CXDRAG)) or
     (Abs(Y - FDragStartPt.Y) >= GetSystemMetrics(SM_CYDRAG)) then
  begin
    FDragArmed := False;
    FClickPath := '';
    // アプリ内のドロップ先で禁止判定に使うため、ドラッグ中の項目を登録しておく
    ShellDragBegin(Self, FDragPaths);
    try
      // OLE のドラッグを開始する（ドロップ・取り消しまでここで待つ）。
      // コピー・移動はドロップ先（シェル）が行う。表示の更新は変更通知に任せる
      ShellDoDragDrop(Handle, FDragPaths, False, Effect);
    finally
      ShellDragEnd;
      // ボタンを離した通知はドラッグ処理が受け取っているため、マウスの捕捉を解放しておく
      ReleaseCapture;
    end;
  end;
end;

procedure TCFileTree.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Node: TTreeNode;
begin
  FDragArmed := False;
  if FClickPath <> '' then
  begin
    // 複数選択の中の項目を押して動かさずに離した：その1つだけの選択にする
    Node := FindNodeByPath(FClickPath);
    FClickPath := '';
    if Node <> nil then
    begin
      ClearSelection;
      Selected := Node;
    end;
  end;
  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TCFileTree.SetDropHilite(ANode: TTreeNode);
begin
  if FDropHilite = ANode then Exit;
  FDropHilite := ANode;
  Invalidate;
end;

procedure TCFileTree.Paint;
var
  R: TRect;
begin
  inherited Paint;
  if (FDropHilite = nil) or not FDropHilite.IsVisible then Exit;
  R := FDropHilite.DisplayRect(True);
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;
  // 2px の枠（選択色）
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clHighlight;
  Canvas.FrameRect(R);
  InflateRect(R, -1, -1);
  Canvas.FrameRect(R);
end;

{ ドロップ先のフォルダー：フォルダーの上ならそのフォルダー、ファイルの上ならその親、何も無い所は根 }
function TCFileTree.OleResolveDrop(const AScreenPt: TPoint): string;
var
  Pt: TPoint;
  Node, HiNode: TTreeNode;
begin
  Result := '';
  if not HandleAllocated then Exit;
  FOleDragOver := True;
  FDragTimer.Enabled := True;   // 自動スクロール・自動で開く

  Pt := ScreenToClient(AScreenPt);
  Node := GetNodeAt(Pt.X, Pt.Y);
  HiNode := nil;
  if Node = nil then
  begin
    if (FRootPath <> '') and DirectoryExists(FRootPath) then Result := FRootPath;
  end
  else if IsDirNode(Node) then
  begin
    Result := GetPathFromNode(Node);
    HiNode := Node;
  end
  else
  begin
    HiNode := Node.Parent;
    Result := GetPathFromNode(HiNode);
  end;

  // アプリ内から始めたドラッグは、禁止判定（自分自身・配下、同じフォルダーへの移動）を行う
  if (Result <> '') and ShellDragIsActive and
     (ShellDecideDropEffect(ShellDragPaths, Result, ShellDragKeyState) = cdeNone) then
    Result := '';

  if Result <> '' then
    SetDropHilite(HiNode)
  else
    SetDropHilite(nil);
end;

procedure TCFileTree.OleDropLeave;
begin
  FOleDragOver := False;
  FDragTimer.Enabled := False;
  FHoverNode := nil;
  SetDropHilite(nil);
end;

procedure TCFileTree.OleDropped(const {%H-}AFolder: string);
begin
  // 表示の更新は変更通知に任せる
end;

procedure TCFileTree.DragTimerTick({%H-}Sender: TObject);
const
  Margin = 20;
var
  Pt: TPoint;
  Node: TTreeNode;
begin
  if not (ShellDragIsActive or FOleDragOver) or not HandleAllocated then
  begin
    FDragTimer.Enabled := False;
    SetDropHilite(nil);
    FHoverNode := nil;
    Exit;
  end;
  Pt := ScreenToClient(Mouse.CursorPos);
  // カーソルが外に出ていたら止める（戻ってきたら DragOver で再開する）
  if (Pt.X < 0) or (Pt.X >= ClientWidth) or (Pt.Y < -Margin) or (Pt.Y >= ClientHeight + Margin) then
  begin
    FHoverNode := nil;
    FDragTimer.Enabled := False;
    Exit;
  end;
  // 1. 上下の端に近ければ1行ずつスクロール
  if Pt.Y < Margin then
    SendMessage(Handle, WM_VSCROLL, SB_LINEUP, 0)
  else if Pt.Y >= ClientHeight - Margin then
    SendMessage(Handle, WM_VSCROLL, SB_LINEDOWN, 0);
  // 2. 同じフォルダーの上に一定時間留まったら開く
  Node := GetNodeAt(Pt.X, Pt.Y);
  if Node <> FHoverNode then
  begin
    FHoverNode := Node;
    FHoverSince := GetTickCount64;
  end
  else if (Node <> nil) and IsDirNode(Node) and not Node.Expanded and Node.HasChildren and
          (GetTickCount64 - FHoverSince >= CFtHoverOpenMs) then
  begin
    Node.Expanded := True;
    FHoverSince := GetTickCount64;
  end;
end;

end.
