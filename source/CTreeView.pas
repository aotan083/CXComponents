{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
unit CTreeView;

{$mode objfpc}{$H+}
{$WARN 4055 OFF} // 順序型⇔ポインターの変換（Win32 API の引数のため意図的）

interface

uses
  Classes, SysUtils, Controls, ComCtrls, ShellCtrls, Windows, ActiveX,
  ShlObj, ShellAPI, Messages, Graphics, Dialogs, Forms, LMessages,
  ExtCtrls, Menus, CommCtrl, CShellNotify, CShellMenu, CShellDragDrop, CShellOleDrop, CShellOleDrag;

type
  PRenameInfo = ^TRenameInfo;
  TRenameInfo = record
    OldPath: string;
    NewPath: string;
    ParentPath: string; // TTreeNodeへの生ポインタは保持せず、パスで管理する
  end;

  // ノードの種類
  TCNodeKind = (
    nkNormal,    // 通常のフォルダー・ドライブ
    nkGroup,     // グループ（クイックアクセス、PC、ネットワーク、Linux）。実体のパスを持たない
    nkShortcut   // 近道（ピン留めフォルダー、OneDrive、共有フォルダー、WSL）。実在のフォルダーを指す
  );
  // グループの種類（アイコンの取得に使う）
  TCGroupKind = (gkNone, gkQuickAccess, gkPC, gkNetwork, gkLinux);

  { TCTreeNode }

  // TCTreeView のノード。近道・グループの情報を持つ
  TCTreeNode = class(TShellTreeNode)
  public
    Kind: TCNodeKind;
    Group: TCGroupKind;
    RealPath: string;      // 近道の指す実在のフォルダー（nkShortcut のみ）
    IconIndex: Integer;    // システムアイコンの番号（IconLoaded = True のとき有効）
    IconLoaded: Boolean;
    // 近道・グループとして初期化する（フォルダー扱いにする）
    procedure InitSpecial(AKind: TCNodeKind; AGroup: TCGroupKind; const ARealPath: string);
  end;

  { TCTreeView }

  TCTreeView = class(TShellTreeView)
  private
    FIsRefreshing: Boolean; // Refresh多重実行防止フラグ

    // --- フォルダー変更監視 ---
    FNotifyID: ULONG;              // 変更通知の登録ID（PC 配下全体を1件で登録）
    FNotifyTimer: TTimer;          // 通知の間引き用（最後の通知から一定時間後に1回だけ更新）
    FPendingPaths: TStringList;    // 更新が必要かもしれないフォルダーのパス（重複なし）
    FRefreshAll: Boolean;          // ツリー全体（ドライブ一覧を含む）を更新する

    // --- D&D ---
    FDragArmed: Boolean;           // マウスボタンがノードの上で押された（一定距離動いたらドラッグ開始）
    FDragStartPt: TPoint;
    FDragNodePath: string;         // ドラッグ対象のフォルダー（押した位置のノード）
    FDragButton: TMouseButton;     // ドラッグを始めたボタン（左 or 右）
    FDropHilite: TTreeNode;        // ドロップ候補として強調表示中のノード
    FHoverNode: TTreeNode;         // 自動展開用：カーソルが乗っているノード
    FHoverSince: QWord;            // 自動展開用：乗り始めた時刻
    FDragTimer: TTimer;            // ドラッグ中の自動スクロール・自動展開用
    // --- 他のアプリ（エクスプローラー等）からのドロップ（OLE） ---
    FOleTarget: TCShellOleDropTarget;
    FOleDragOver: Boolean;         // 他のアプリからのドラッグが上に乗っている
    function OleResolveDrop(const AScreenPt: TPoint): string;
    procedure OleDropLeave;
    procedure OleDropped(const AFolder: string);

    procedure SetDropHilite(ANode: TTreeNode);
    procedure DragTimerTick({%H-}Sender: TObject);

    procedure RegisterFolderNotify;
    procedure UnregisterFolderNotify;
    procedure HandleShellNotify(AWParam: WPARAM; ALParam: LPARAM);
    procedure NotifyTimerTick({%H-}Sender: TObject);
    // 展開状態・選択状態を保ったまま更新する。
    // AAll = True ならツリー全体、False なら ATargets のうち展開中のノードだけ。
    procedure RefreshKeepingState(ATargets: TStrings; AAll: Boolean);
    // サブフォルダーがあるか（「＞」の表示用。隠しフォルダーは ObjectTypes に従う）
    function FolderHasSubFolders(const APath: string): Boolean;

    // Shell APIを使用してフォルダのコンテキストメニュー（IContextMenu）を表示
    procedure DisplayShellContextMenu(const APath: string; const APoint: TPoint);
    // SHFileOperationW を用いたファイル・フォルダ操作 (コピー/移動/削除)
    function PerformFileOperation(AOp: UINT; const ASource, ADest: string; AAllowUndo: Boolean = True): Boolean;
    // フルパスから PIDL (ItemIDList) を取得するヘルパー関数
    function GetPIDLFromPath(const APath: string): PItemIDList;
    // イベントハンドラ（ノードの編集完了時）
    procedure InternalOnEdited(Sender: TObject; Node: TTreeNode; var S: string);

    procedure DoAsyncRename(Data: PtrInt);

    // パス文字列から該当ノードを探す（リネーム完了後などにノードを再特定するため）
    // APreferRoot：この起点（ドライブ・近道のパス）の配下を優先して探す
    function FindNodeForPath(const APath: string; const APreferRoot: string = ''): TTreeNode;

    // 現在表示（展開）されているノードだけをまとめて更新（F5）
    procedure DoRefreshVisibleNodes;
  private
    FInXButton: Boolean; // WM_XBUTTONUP の処理中（同時に届く WM_APPCOMMAND を二重に処理しない）
    // マウスの戻る／進むボタン：リンクした TCListView の履歴で移動する（ADir：-1 = 戻る、+1 = 進む）
    procedure TreeHistoryGo(ADir: Integer);
  private
    // --- 右クリックメニューへの独自項目 ---
    FExtraItemMenu: TPopupMenu;
    FExtraBackgroundMenu: TPopupMenu;
    FExtraMenuPosition: TCExtraMenuPosition;
    procedure SetExtraItemMenu(AValue: TPopupMenu);
    procedure SetExtraBackgroundMenu(AValue: TPopupMenu);
    // 空白部分の右クリック：独自メニュー（ExtraBackgroundMenu）だけを表示する
    procedure DisplayBackgroundMenu(const APoint: TPoint);
  private
    // --- 近道ノード ---
    FShowQuickAccess: Boolean;
    FShowOneDrive: Boolean;
    FShowNetwork: Boolean;
    FShowLinux: Boolean;
    FNetworkFolders: TStringList;
    FSysSmallImages: HIMAGELIST;   // システムの小アイコン一覧（近道・グループのアイコン描画用）
    // ツリーの最上位（近道・グループ・ドライブ）を作り直す
    procedure BuildTopLevel;
    // 最上位の作り直し＋展開・選択の復元（プロパティ変更時）
    procedure RebuildTopLevel;
    function AddGroupNode(const ACaption: string; AGroup: TCGroupKind): TTreeNode;
    function AddShortcutNode(AParent: TTreeNode; const ACaption, APath: string): TTreeNode;
    // パスの起点になるノード（ドライブ、近道）を集める。ドライブが先
    procedure GetPathRootNodes(AList: TList);
    // ノードが属する起点ノード（ドライブ・近道）
    function PathRootOf(ANode: TTreeNode): TTreeNode;
    // 起点ノードの配下から、パスに一致するノードを探す
    function FindNodeUnder(ARoot: TTreeNode; const ATarget: string): TTreeNode;
    // パスに一致するノードをすべて集める（ドライブ配下と近道配下の両方にある場合がある）
    procedure FindNodesForPath(const APath: string; AResult: TList);
    // 展開状態の記録用のキー（グループはパスがないため名前で区別する）
    function NodeKey(ANode: TTreeNode): string;
    function SpecialIconIndex(ANode: TCTreeNode): Integer;
    procedure SetShowQuickAccess(AValue: Boolean);
    procedure SetShowOneDrive(AValue: Boolean);
    procedure SetShowNetwork(AValue: Boolean);
    procedure SetShowLinux(AValue: Boolean);
    procedure SetNetworkFolders(AValue: TStrings);
    function GetNetworkFolders: TStrings;
    procedure NetworkFoldersChanged(Sender: TObject);
    function GetCPath: string;
    procedure SetCPath(const AValue: string);
    // フォルダー名の並べ替え（エクスプローラーと同じ自然順。リスト表示と同じ比べ方）
    function CompareFolderNames(Item1, Item2: TFileItem): Integer;
  protected
    procedure DoCreateNodeClass(var NewNodeClass: TTreeNodeClass); override;
    function CanExpand(Node: TTreeNode): Boolean; override;
    function NodeHasChildren(Node: TTreeNode): Boolean; override;
    procedure DoSelectionChanged; override;
    function DrawBuiltInIcon(ANode: TTreeNode; ARect: TRect): TSize; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure DoContextPopup(MousePos: TPoint; var Handled: Boolean); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure WndProc(var Message: TLMessage); override;
    // ドライブノードはインプレース編集（名前変更）させない
    function CanEdit(Node: TTreeNode): Boolean; override;

    // ドラッグ & ドロップ関連のオーバーライド
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    // ドロップ候補の周りに枠を描く
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // ドライブ（C:\ や \\server\share）を表すノードか
    function IsDriveNode(Node: TTreeNode): Boolean;
    // 選択ノードの削除処理（APermanent = False: ごみ箱へ移動、True: 完全削除）
    procedure DeleteSelectedFolder(APermanent: Boolean = False);
    // 選択フォルダーをクリップボードへコピー／切り取り（シェルのコマンドで実行）
    procedure CopySelectedFolder;
    procedure CutSelectedFolder;
    // 選択フォルダーの中へ貼り付け（シェルのコマンドで実行）
    procedure PasteToSelectedFolder;
    // 選択ノードの名前変更処理
    procedure RenameSelectedFolder;
    // ノードのフルパス。近道は実在のフォルダー、グループ（PC 等）は空文字
    function GetPathFromNode(ANode: TTreeNode): string; reintroduce;
    // 近道（ピン留めフォルダー、OneDrive、共有フォルダー、WSL）・グループ（クイックアクセス、PC、ネットワーク、Linux）のノードか
    function IsSpecialNode(Node: TTreeNode): Boolean;
    function IsGroupNode(Node: TTreeNode): Boolean;
    function IsShortcutNode(Node: TTreeNode): Boolean;
    // 選択中のフォルダー。設定すると、ドライブ（PC）の配下をたどって展開・選択する
    property Path: string read GetCPath write SetCPath;
  published
    // 近道ノードの表示（既定はすべて表示）
    property ShowQuickAccess: Boolean read FShowQuickAccess write SetShowQuickAccess default True;
    property ShowOneDrive: Boolean read FShowOneDrive write SetShowOneDrive default True;
    property ShowNetwork: Boolean read FShowNetwork write SetShowNetwork default True;
    property ShowLinux: Boolean read FShowLinux write SetShowLinux default True;
    // 「ネットワーク」の下に並べる共有フォルダー（\\サーバー\共有名 を1行に1つ）
    property NetworkFolders: TStrings read GetNetworkFolders write SetNetworkFolders;
    // 右クリックメニューに追加する独自メニュー（ノードの上／空白部分）。処理は各メニュー項目の OnClick に書く
    property ExtraItemMenu: TPopupMenu read FExtraItemMenu write SetExtraItemMenu;
    property ExtraBackgroundMenu: TPopupMenu read FExtraBackgroundMenu write SetExtraBackgroundMenu;
    // 独自メニューを追加する位置（empTop = 先頭、empBottom = 末尾）
    property ExtraMenuPosition: TCExtraMenuPosition read FExtraMenuPosition write FExtraMenuPosition default empBottom;
  end;

// パスがドライブのルート（C:\ や \\server\share）か
function IsDriveRootPath(const APath: string): Boolean;

implementation

uses
  CListView, ComObj, Variants, Registry;

// エクスプローラーと同じ自然順の比較（リスト表示と同じ）
function StrCmpLogicalW(psz1, psz2: PWideChar): Integer; stdcall; external 'shlwapi.dll';

const
  CSHGFI_SMALLICON         = $000000001;
  CSHGFI_PIDL              = $000000008;
  CSHGFI_USEFILEATTRIBUTES = $000000010;
  CSHGFI_SYSICONINDEX      = $000004000;
  CCSIDL_NETWORK = $0012;
  // クイックアクセス
  CQuickAccessParse = 'shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}';

type
  TCSHFileInfoW = record
    hIcon: HICON;
    iIcon: Integer;
    dwAttributes: DWORD;
    szDisplayName: array[0..259] of WideChar;
    szTypeName: array[0..79] of WideChar;
  end;

function _SHGetFileInfoW(pszPath: PWideChar; dwFileAttributes: DWORD; var psfi: TCSHFileInfoW;
  cbFileInfo: UINT; uFlags: UINT): PtrUInt; stdcall;
  external 'shell32.dll' name 'SHGetFileInfoW';
function _SHParseDisplayName(pszName: PWideChar; pbc: Pointer; out ppidl: PItemIDList;
  sfgaoIn: ULONG; out psfgaoOut: ULONG): HRESULT; stdcall;
  external 'shell32.dll' name 'SHParseDisplayName';
function _SHGetSpecialFolderLocation(hwndOwner: HWND; nFolder: Integer;
  out ppidl: PItemIDList): HRESULT; stdcall;
  external 'shell32.dll' name 'SHGetSpecialFolderLocation';

// クイックアクセスのフォルダー（ピン留め。エクスプローラーの設定によっては、よく使うフォルダーも含む）
procedure GetQuickAccessFolders(ANames, APaths: TStrings);
var
  Shell, Folder, FItems, It: OleVariant;
  i, n: Integer;
  P, Nm: string;
begin
  try
    Shell := CreateOleObject('Shell.Application');
    Folder := Shell.NameSpace(WideString(CQuickAccessParse));
    FItems := Folder.Items;
    n := FItems.Count;
    for i := 0 to n - 1 do
    begin
      It := FItems.Item(i);
      if not It.IsFolder then Continue;
      P := String(WideString(It.Path));
      Nm := String(WideString(It.Name));
      // 実在のフォルダーだけ（ZIP・仮想フォルダーは除く）
      if (P = '') or not DirectoryExists(P) then Continue;
      ANames.Add(Nm);
      APaths.Add(P);
    end;
  except
    // 取得できない環境では、クイックアクセスを表示しない
  end;
end;

// OneDrive のフォルダー（入っていなければ空文字）
function GetOneDrivePath: string;
begin
  Result := SysUtils.GetEnvironmentVariable('OneDrive');
  if Result = '' then
    Result := SysUtils.GetEnvironmentVariable('OneDriveConsumer');
  if (Result <> '') and not DirectoryExists(Result) then
    Result := '';
end;

// WSL のディストリビューション名（登録情報から取得。WSL を起動しないよう、存在確認はしない）
procedure GetWslDistros(ANames: TStrings);
const
  LxssKey = 'Software\Microsoft\Windows\CurrentVersion\Lxss';
var
  R: TRegistry;
  Keys: TStringList;
  i: Integer;
  Nm: string;
begin
  try
    R := TRegistry.Create(KEY_READ);
    Keys := TStringList.Create;
    try
      R.RootKey := HKEY_CURRENT_USER;
      if not R.OpenKeyReadOnly(LxssKey) then Exit;
      R.GetKeyNames(Keys);
      R.CloseKey;
      for i := 0 to Keys.Count - 1 do
      begin
        if not R.OpenKeyReadOnly(LxssKey + '\' + Keys[i]) then Continue;
        Nm := '';
        if R.ValueExists('DistributionName') then
          Nm := R.ReadString('DistributionName');
        R.CloseKey;
        if Nm <> '' then
          ANames.Add(Nm);
      end;
    finally
      Keys.Free;
      R.Free;
    end;
  except
    // 取得できない環境では、Linux を表示しない
  end;
end;

{ TCTreeNode }

procedure TCTreeNode.InitSpecial(AKind: TCNodeKind; AGroup: TCGroupKind; const ARealPath: string);
begin
  Kind := AKind;
  Group := AGroup;
  RealPath := ExcludeTrailingPathDelimiter(ARealPath);
  IconLoaded := False;
  FFileInfo.Name := Text;
  FFileInfo.Attr := faDirectory;
end;

const
  // マウスの戻る／進むボタン
  CWM_XBUTTONUP  = $020C;
  CWM_APPCOMMAND = $0319;
  CMK_XBUTTON1 = $0020;
  CMK_XBUTTON2 = $0040;
  CAPPCOMMAND_BROWSER_BACKWARD = 1;
  CAPPCOMMAND_BROWSER_FORWARD  = 2;

// マウスの戻る／進むボタンの判定。-1 = 戻る、+1 = 進む、0 = それ以外
function XButtonDirection(AMsg: Cardinal; AWParam: WPARAM; ALParam: LPARAM): Integer;
var
  Cmd: Integer;
begin
  Result := 0;
  if AMsg = CWM_XBUTTONUP then
  begin
    if (HIWORD(DWORD(AWParam)) = 1) or ((AWParam and CMK_XBUTTON1) <> 0) then Result := -1
    else if (HIWORD(DWORD(AWParam)) = 2) or ((AWParam and CMK_XBUTTON2) <> 0) then Result := 1;
  end
  else if AMsg = CWM_APPCOMMAND then
  begin
    Cmd := HIWORD(DWORD(ALParam)) and $0FFF;
    if Cmd = CAPPCOMMAND_BROWSER_BACKWARD then Result := -1
    else if Cmd = CAPPCOMMAND_BROWSER_FORWARD then Result := 1;
  end;
end;

const
  // 通知が大量に届いたら、個別に追わずツリー全体を更新する
  MaxPendingPaths = 200;

function IsDriveRootPath(const APath: string): Boolean;
var
  P: string;
begin
  P := ExcludeTrailingPathDelimiter(APath);
  Result := (P <> '') and SameText(P, ExtractFileDrive(APath));
end;

{ TCTreeView }

constructor TCTreeView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // フォルダーの並びをエクスプローラーと同じ自然順にする（記号 → 数字 → 英字 …）
  FileSortType := fstCustom;
  OnSortCompare := @CompareFolderNames;
  FShowQuickAccess := True;
  FShowOneDrive := True;
  FShowNetwork := True;
  FShowLinux := True;
  FNetworkFolders := TStringList.Create;
  FNetworkFolders.OnChange := @NetworkFoldersChanged;
  FSysSmallImages := 0;
  FExtraItemMenu := nil;
  FExtraBackgroundMenu := nil;
  FExtraMenuPosition := empBottom;
  ReadOnly := False;         // インプレース編集を許可
  // ドラッグは一定距離マウスを動かしたときに自前で開始する（クリック・名前変更との誤作動を防ぐ）
  DragMode := dmManual;
  ShowButtons := True;
  ShowLines := False;
  ShowRoot := True;
  RightClickSelect := True;
  OnEdited := @InternalOnEdited; // 編集完了イベントを設定

  FIsRefreshing := False;

  FNotifyID := 0;
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
  FDropHilite := nil;
  FHoverNode := nil;
  FDragTimer := TTimer.Create(Self);
  FDragTimer.Enabled := False;
  FDragTimer.Interval := 80;
  FDragTimer.OnTimer := @DragTimerTick;
end;

destructor TCTreeView.Destroy;
begin
  if FNotifyTimer <> nil then
    FNotifyTimer.Enabled := False;
  if FDragTimer <> nil then
    FDragTimer.Enabled := False;
  // 自分がドラッグ元のまま破棄される場合に備えて解除する
  ShellDragAbandon(Self);
  if FOleTarget <> nil then
  begin
    if HandleAllocated then
      OleDropRevoke(Handle, FOleTarget)
    else
      OleDropRevoke(0, FOleTarget);
  end;
  UnregisterFolderNotify;

  // 自分宛にキューされている未実行の非同期呼び出し（DoAsyncRenameなど）を取り消す。
  // これをしないと、破棄後にキューが実行されて解放済みオブジェクトへアクセスしクラッシュし得る。
  Application.RemoveAsyncCalls(Self);

  FreeAndNil(FPendingPaths);
  inherited Destroy;
  FreeAndNil(FNetworkFolders);
end;

procedure TCTreeView.CreateWnd;
begin
  inherited CreateWnd;
  if not (csDesigning in ComponentState) then
  begin
    // 空文字を指定することで、PC 直下の全物理ドライブ（C:, D:, J:等）がルートに列挙されます
    Root := '';
    // 最上位（クイックアクセス、OneDrive、PC とドライブ、ネットワーク、Linux）を作る
    BuildTopLevel;
    // ハンドルが作り直されたら登録し直す（通知・ドロップの宛先がハンドルのため）
    RegisterFolderNotify;
    FOleTarget := OleDropRegister(Handle, @OleResolveDrop, @OleDropLeave, @OleDropped);
  end;
end;

procedure TCTreeView.DestroyWnd;
begin
  UnregisterFolderNotify;
  OleDropRevoke(Handle, FOleTarget);
  inherited DestroyWnd;
end;

// ---------------------------------------------------------------
// フォルダー変更監視
// ---------------------------------------------------------------

procedure TCTreeView.RegisterFolderNotify;
const
  TreeEvents = CSHCNE_MKDIR or CSHCNE_RMDIR or CSHCNE_RENAMEFOLDER or
               CSHCNE_UPDATEDIR or CSHCNE_DRIVEEVENTS;
begin
  UnregisterFolderNotify;
  if csDesigning in ComponentState then Exit;
  if not HandleAllocated then Exit;
  // PC（全ドライブ）配下をまとめて1件で監視し、関係のないパスは受信側で捨てる
  FNotifyID := ShellNotifyRegisterSpecial(Handle, CCSIDL_DRIVES, True, TreeEvents);
end;

procedure TCTreeView.UnregisterFolderNotify;
begin
  ShellNotifyDeregister(FNotifyID);
end;

procedure TCTreeView.TreeHistoryGo(ADir: Integer);
begin
  if not (ShellListView is TCListView) then Exit;
  if ADir < 0 then
    TCListView(ShellListView).GoBack
  else
    TCListView(ShellListView).GoForward;
end;

procedure TCTreeView.WndProc(var Message: TLMessage);
var
  Dir: Integer;
begin
  // マウスの戻る／進むボタン：リンクした TCListView の履歴で移動する
  Dir := XButtonDirection(Message.Msg, Message.WParam, Message.LParam);
  if Dir <> 0 then
  begin
    ShellDragLog('Tree XButton msg=' + IntToHex(Message.Msg, 4) + ' dir=' + IntToStr(Dir) +
      ' linked=' + BoolToStr(ShellListView is TCListView, True));
    if Message.Msg = CWM_APPCOMMAND then
    begin
      if not FInXButton then
        TreeHistoryGo(Dir);
      Message.Result := 1;
      Exit;
    end;
    FInXButton := True;
    try
      inherited WndProc(Message);
    finally
      FInXButton := False;
    end;
    TreeHistoryGo(Dir);
    Message.Result := 1;
    Exit;
  end;
  if Message.Msg = WM_CSHELLNOTIFY then
  begin
    HandleShellNotify(Message.WParam, Message.LParam);
    Message.Result := 0;
    Exit;
  end;
  inherited WndProc(Message);
end;

procedure TCTreeView.HandleShellNotify(AWParam: WPARAM; ALParam: LPARAM);
var
  Event: LongInt;
  P1, P2: string;

  // 変更があったフォルダーの「親」を更新候補にする（子ノードの増減が起きる場所）
  procedure AddParentOf(const P: string);
  var
    X, ParentPath: string;
  begin
    if P = '' then Exit;
    X := ExcludeTrailingPathDelimiter(P);
    ParentPath := ExcludeTrailingPathDelimiter(ExtractFileDir(X));
    if (ParentPath <> '') and not SameText(ParentPath, X) then
      FPendingPaths.Add(ParentPath);
  end;

begin
  if not ShellNotifyDecode(AWParam, ALParam, Event, P1, P2) then Exit;
  if csDestroying in ComponentState then Exit;

  if (Event and CSHCNE_DRIVEEVENTS) <> 0 then
    // ドライブの追加・取り外し：ドライブ一覧から作り直す
    FRefreshAll := True
  else if not FRefreshAll then
  begin
    AddParentOf(P1);
    AddParentOf(P2);
    // フォルダー自体の内容更新通知は、そのフォルダー自身も候補にする
    if (Event and CSHCNE_UPDATEDIR) <> 0 then
    begin
      if P1 <> '' then FPendingPaths.Add(ExcludeTrailingPathDelimiter(P1));
    end;

    if FPendingPaths.Count > MaxPendingPaths then
    begin
      FPendingPaths.Clear;
      FRefreshAll := True;
    end;
  end;

  // 最後の通知から一定時間待って1回だけ更新する（タイマーを掛け直す）
  FNotifyTimer.Enabled := False;
  FNotifyTimer.Enabled := True;
end;

procedure TCTreeView.NotifyTimerTick({%H-}Sender: TObject);
var
  Targets: TStringList;
  All: Boolean;
begin
  // 名前の編集中・ドラッグ中・更新中は保留（タイマーは止めず、次の周期で再判定する）
  // （ドロップ先として強調表示中のノードが作り直されないよう、他のコントロールからのドラッグ中も保留）
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
      RefreshKeepingState(Targets, All);
  finally
    Targets.Free;
  end;
end;

function TCTreeView.FolderHasSubFolders(const APath: string): Boolean;
var
  FindData: WIN32_FIND_DATAW;
  H: HANDLE;
  ItemName: string; // Name は TComponent.Name と重複するため使わない
begin
  Result := False;
  FindData := Default(WIN32_FIND_DATAW);
  if APath = '' then Exit;
  // 260 文字を超えるパスにも対応する
  H := FindFirstFileW(PWideChar(ShellLongPathW(IncludeTrailingPathDelimiter(APath) + '*')), FindData);
  if H = INVALID_HANDLE_VALUE then Exit;
  try
    repeat
      if (FindData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then Continue;
      ItemName := String(UnicodeString(PWideChar(@FindData.cFileName[0])));
      if (ItemName = '.') or (ItemName = '..') then Continue;
      // 隠しフォルダーは ObjectTypes に従う
      if (not (otHidden in ObjectTypes)) and
         ((FindData.dwFileAttributes and FILE_ATTRIBUTE_HIDDEN) <> 0) then Continue;
      Exit(True);
    until not FindNextFileW(H, FindData);
  finally
    Windows.FindClose(H);
  end;
end;

procedure TCTreeView.RefreshKeepingState(ATargets: TStrings; AAll: Boolean);
var
  ExpandedPaths: TStringList;
  SelectedPath, P, ParentPath: string;
  Node, Child: TTreeNode;
  i, m: Integer;
  Matches: TList;
  SelRootPath: string;

  procedure CollectExpanded(ANode: TTreeNode);
  var
    C: TTreeNode;
  begin
    if ANode = nil then Exit;
    if ANode.Expanded then
      ExpandedPaths.Add(NodeKey(ANode));
    C := ANode.GetFirstChild;
    while C <> nil do
    begin
      CollectExpanded(C);
      C := C.GetNextSibling;
    end;
  end;

  // 作り直された子ノードのうち、元々開いていたものを開き直す
  procedure RestoreExpanded(ANode: TTreeNode);
  var
    C: TTreeNode;
  begin
    if ANode = nil then Exit;
    if ExpandedPaths.IndexOf(NodeKey(ANode)) < 0 then Exit;
    ANode.Expanded := True;
    C := ANode.GetFirstChild;
    while C <> nil do
    begin
      RestoreExpanded(C);
      C := C.GetNextSibling;
    end;
  end;

begin
  if FIsRefreshing then Exit;
  if csDestroying in ComponentState then Exit;

  FIsRefreshing := True;
  ExpandedPaths := TStringList.Create;
  Matches := TList.Create;
  try
    ExpandedPaths.CaseSensitive := False;
    ExpandedPaths.Sorted := True;
    ExpandedPaths.Duplicates := dupIgnore;

    SelRootPath := '';
    if Selected <> nil then
    begin
      SelectedPath := ExcludeTrailingPathDelimiter(GetPathFromNode(Selected));
      if PathRootOf(Selected) <> nil then
        SelRootPath := ExcludeTrailingPathDelimiter(GetPathFromNode(PathRootOf(Selected)));
    end
    else
      SelectedPath := '';

    Node := Items.GetFirstNode;
    while Node <> nil do
    begin
      CollectExpanded(Node);
      Node := Node.GetNextSibling;
    end;

    try
      Items.BeginUpdate;
      try
        if AAll then
        begin
          // ドライブ一覧・近道を含めて作り直し、展開状態を戻す
          BuildTopLevel;
          Node := Items.GetFirstNode;
          while Node <> nil do
          begin
            RestoreExpanded(Node);
            Node := Node.GetNextSibling;
          end;
        end
        else
        begin
          for i := 0 to ATargets.Count - 1 do
          begin
            // 前のノードの Refresh でノードが作り直されている場合があるため、毎回パスから探す。
            // 同じフォルダーがドライブ配下と近道配下の両方にある場合は、両方を更新する
            Matches.Clear;
            FindNodesForPath(ATargets[i], Matches);
            for m := 0 to Matches.Count - 1 do
            begin
            Node := TTreeNode(Matches[m]);
            // 畳まれているノードは作り直さず、「＞」の表示だけ最新にする。
            // 以前に読み込んだ子ノードは破棄し、次に開いたときに最新の内容で読み込ませる。
            if not Node.Expanded then
            begin
              if Node.Count > 0 then
                Node.DeleteChildren;
              Node.HasChildren := FolderHasSubFolders(GetPathFromNode(Node));
              Continue;
            end;

            Refresh(Node);
            Node.Expanded := True;
            Child := Node.GetFirstChild;
            while Child <> nil do
            begin
              RestoreExpanded(Child);
              Child := Child.GetNextSibling;
            end;
            end;
          end;
        end;

        // 選択状態を復元。選択していたフォルダーが消えた場合は、存在する親まで遡る
        if SelectedPath <> '' then
        begin
          if (Selected = nil) or
             not SameText(ExcludeTrailingPathDelimiter(GetPathFromNode(Selected)), SelectedPath) then
          begin
            P := SelectedPath;
            while P <> '' do
            begin
              Node := FindNodeForPath(P, SelRootPath);
              if Node <> nil then
              begin
                Selected := Node;
                Break;
              end;
              ParentPath := ExcludeTrailingPathDelimiter(ExtractFileDir(P));
              if SameText(ParentPath, P) then Break;
              P := ParentPath;
            end;
          end;
        end;
      finally
        Items.EndUpdate;
      end;
    except
      // 更新中の例外がメッセージ処理全体に波及しないよう握りつぶす（次の通知・F5で再試行される）
    end;
  finally
    Matches.Free;
    ExpandedPaths.Free;
    FIsRefreshing := False;
  end;
end;

// ---------------------------------------------------------------

// ---------------------------------------------------------------
// 近道ノード（クイックアクセス、OneDrive、PC、ネットワーク、Linux）
// ---------------------------------------------------------------

procedure TCTreeView.DoCreateNodeClass(var NewNodeClass: TTreeNodeClass);
begin
  inherited DoCreateNodeClass(NewNodeClass);
  NewNodeClass := TCTreeNode;
end;

function TCTreeView.IsSpecialNode(Node: TTreeNode): Boolean;
begin
  Result := (Node is TCTreeNode) and (TCTreeNode(Node).Kind <> nkNormal);
end;

function TCTreeView.IsGroupNode(Node: TTreeNode): Boolean;
begin
  Result := (Node is TCTreeNode) and (TCTreeNode(Node).Kind = nkGroup);
end;

function TCTreeView.IsShortcutNode(Node: TTreeNode): Boolean;
begin
  Result := (Node is TCTreeNode) and (TCTreeNode(Node).Kind = nkShortcut);
end;

function TCTreeView.GetPathFromNode(ANode: TTreeNode): string;
begin
  if ANode = nil then Exit('');
  if IsGroupNode(ANode) then Exit('');
  if IsShortcutNode(ANode) then
    Exit(IncludeTrailingPathDelimiter(TCTreeNode(ANode).RealPath));
  Result := inherited GetPathFromNode(ANode);
end;

function TCTreeView.NodeKey(ANode: TTreeNode): string;
begin
  if IsGroupNode(ANode) then
    Result := '#group:' + ANode.Text
  else
    Result := ExcludeTrailingPathDelimiter(GetPathFromNode(ANode));
end;

function TCTreeView.AddGroupNode(const ACaption: string; AGroup: TCGroupKind): TTreeNode;
begin
  Result := Items.Add(nil, ACaption);
  TCTreeNode(Result).InitSpecial(nkGroup, AGroup, '');
  Result.HasChildren := True;
end;

function TCTreeView.AddShortcutNode(AParent: TTreeNode; const ACaption, APath: string): TTreeNode;
begin
  if AParent = nil then
    Result := Items.Add(nil, ACaption)
  else
    Result := Items.AddChild(AParent, ACaption);
  TCTreeNode(Result).InitSpecial(nkShortcut, gkNone, APath);
  Result.HasChildren := True;
end;

procedure TCTreeView.BuildTopLevel;
var
  Names, Paths: TStringList;
  DriveNodes: TList;
  N, FirstDrive, G, QA, OD: TTreeNode;
  i: Integer;
  P: string;
begin
  if csDesigning in ComponentState then Exit;
  DriveNodes := TList.Create;
  Names := TStringList.Create;
  Paths := TStringList.Create;
  Items.BeginUpdate;
  try
    // 1. ドライブ（継承元の処理で最上位に並ぶ）
    PopulateWithBaseFiles;
    N := Items.GetFirstNode;
    while N <> nil do
    begin
      DriveNodes.Add(N);
      N := N.GetNextSibling;
    end;
    if DriveNodes.Count > 0 then
      FirstDrive := TTreeNode(DriveNodes[0])
    else
      FirstDrive := nil;

    // 2. クイックアクセス（ドライブより前）
    QA := nil;
    if FShowQuickAccess then
    begin
      GetQuickAccessFolders(Names, Paths);
      if Names.Count > 0 then
      begin
        if FirstDrive <> nil then
          QA := Items.Insert(FirstDrive, 'クイックアクセス')
        else
          QA := Items.Add(nil, 'クイックアクセス');
        TCTreeNode(QA).InitSpecial(nkGroup, gkQuickAccess, '');
        QA.HasChildren := True;
        for i := 0 to Names.Count - 1 do
          AddShortcutNode(QA, Names[i], Paths[i]);
      end;
    end;

    // 3. OneDrive（ドライブより前）
    if FShowOneDrive then
    begin
      P := GetOneDrivePath;
      if P <> '' then
      begin
        if FirstDrive <> nil then
          OD := Items.Insert(FirstDrive, 'OneDrive')
        else
          OD := Items.Add(nil, 'OneDrive');
        TCTreeNode(OD).InitSpecial(nkShortcut, gkNone, P);
        OD.HasChildren := True;
      end;
    end;

    // 4. PC（ドライブをこの下にまとめる。常に表示）
    G := nil;
    if DriveNodes.Count > 0 then
    begin
      G := AddGroupNode('PC', gkPC);
      for i := 0 to DriveNodes.Count - 1 do
        TTreeNode(DriveNodes[i]).MoveTo(G, naAddChild);
    end;

    // 5. ネットワーク（登録した共有フォルダー）
    if FShowNetwork and (FNetworkFolders.Count > 0) then
    begin
      N := AddGroupNode('ネットワーク', gkNetwork);
      for i := 0 to FNetworkFolders.Count - 1 do
      begin
        P := Trim(FNetworkFolders[i]);
        if P <> '' then
          AddShortcutNode(N, ExcludeTrailingPathDelimiter(P), P);
      end;
    end;

    // 6. Linux（WSL）
    if FShowLinux then
    begin
      Names.Clear;
      GetWslDistros(Names);
      if Names.Count > 0 then
      begin
        N := AddGroupNode('Linux', gkLinux);
        for i := 0 to Names.Count - 1 do
          AddShortcutNode(N, Names[i], '\\wsl.localhost\' + Names[i]);
      end;
    end;

    // クイックアクセスと PC は開いておく（エクスプローラーと同じ）
    if QA <> nil then QA.Expanded := True;
    if G <> nil then G.Expanded := True;
  finally
    Items.EndUpdate;
    Paths.Free;
    Names.Free;
    DriveNodes.Free;
  end;
end;

procedure TCTreeView.RebuildTopLevel;
begin
  if [csDesigning, csLoading, csDestroying] * ComponentState <> [] then Exit;
  if not HandleAllocated then Exit;
  RefreshKeepingState(nil, True);
end;

procedure TCTreeView.GetPathRootNodes(AList: TList);
var
  N, C: TTreeNode;
  Others: TList;
  i: Integer;
begin
  Others := TList.Create;
  try
    N := Items.GetFirstNode;
    while N <> nil do
    begin
      if IsGroupNode(N) then
      begin
        C := N.GetFirstChild;
        while C <> nil do
        begin
          if IsShortcutNode(C) then Others.Add(C) else AList.Add(C);
          C := C.GetNextSibling;
        end;
      end
      else if IsShortcutNode(N) then
        Others.Add(N)
      else
        AList.Add(N);
      N := N.GetNextSibling;
    end;
    // ドライブが先、近道が後
    for i := 0 to Others.Count - 1 do
      AList.Add(Others[i]);
  finally
    Others.Free;
  end;
end;

function TCTreeView.PathRootOf(ANode: TTreeNode): TTreeNode;
begin
  Result := ANode;
  if (Result = nil) or IsGroupNode(Result) then Exit(nil);
  while (Result.Parent <> nil) and not IsGroupNode(Result.Parent) do
    Result := Result.Parent;
end;

function TCTreeView.FindNodeUnder(ARoot: TTreeNode; const ATarget: string): TTreeNode;
var
  Node: TTreeNode;
  P: string;
begin
  Result := nil;
  if ARoot = nil then Exit;
  P := ExcludeTrailingPathDelimiter(GetPathFromNode(ARoot));
  if P = '' then Exit;
  if SameText(P, ATarget) then Exit(ARoot);
  if not SameText(Copy(ATarget, 1, Length(P) + 1), P + PathDelim) then Exit;
  // 起点の配下：パスの前方が一致するノードの子だけをたどる
  Node := ARoot.GetFirstChild;
  while Node <> nil do
  begin
    P := ExcludeTrailingPathDelimiter(GetPathFromNode(Node));
    if (P <> '') and SameText(P, ATarget) then
      Exit(Node);
    if (P <> '') and SameText(Copy(ATarget, 1, Length(P) + 1), P + PathDelim) then
      Node := Node.GetFirstChild
    else
      Node := Node.GetNextSibling;
  end;
end;

procedure TCTreeView.FindNodesForPath(const APath: string; AResult: TList);
var
  Roots: TList;
  i: Integer;
  N: TTreeNode;
  Target: string;
begin
  if APath = '' then Exit;
  Target := ExcludeTrailingPathDelimiter(APath);
  Roots := TList.Create;
  try
    GetPathRootNodes(Roots);
    for i := 0 to Roots.Count - 1 do
    begin
      N := FindNodeUnder(TTreeNode(Roots[i]), Target);
      if (N <> nil) and (AResult.IndexOf(N) < 0) then
        AResult.Add(N);
    end;
  finally
    Roots.Free;
  end;
end;

function TCTreeView.CanExpand(Node: TTreeNode): Boolean;
begin
  // グループ：子ノード（ドライブ・近道）は作ったまま使う（読み直さない）
  if IsGroupNode(Node) then
    Exit(Node.Count > 0);
  // 近道：実在のフォルダーの中身を読み込む
  if IsShortcutNode(Node) then
  begin
    Items.BeginUpdate;
    try
      Node.DeleteChildren;
      try
        PopulateTreeNodeWithFiles(Node, IncludeTrailingPathDelimiter(TCTreeNode(Node).RealPath));
      except
        // 接続できない共有フォルダー等
      end;
    finally
      Items.EndUpdate;
    end;
    Result := Node.Count > 0;
    if not Result then Node.HasChildren := False;
    Exit;
  end;
  Result := inherited CanExpand(Node);
end;

function TCTreeView.NodeHasChildren(Node: TTreeNode): Boolean;
begin
  if IsGroupNode(Node) then
    Exit(Node.Count > 0);
  // 近道は、開くまで中身を調べない（共有フォルダー・WSL で待たされないため）
  if IsShortcutNode(Node) then
    Exit(True);
  Result := inherited NodeHasChildren(Node);
end;

procedure TCTreeView.DoSelectionChanged;
var
  N: TCTreeNode;
begin
  if IsSpecialNode(Selected) then
  begin
    N := TCTreeNode(Selected);
    // 近道：リストを実在のフォルダーへ移動する。グループ：リストは変えない（開閉するだけ）
    if (N.Kind = nkShortcut) and (ShellListView <> nil) then
    begin
      try
        if ShellListView is TCListView then
          TCListView(ShellListView).NavigateTo(IncludeTrailingPathDelimiter(N.RealPath))
        else if DirectoryExists(N.RealPath) then
          ShellListView.Root := IncludeTrailingPathDelimiter(N.RealPath);
      except
        // 接続できない共有フォルダー等
      end;
    end;
    if Assigned(OnSelectionChanged) then
      OnSelectionChanged(Self);
    Exit;
  end;
  inherited DoSelectionChanged;
end;

function TCTreeView.SpecialIconIndex(ANode: TCTreeNode): Integer;
var
  SFI: TCSHFileInfoW;
  W: UnicodeString;
  PIDL: PItemIDList;
  Attr: ULONG;
  H: PtrUInt;
begin
  if ANode.IconLoaded then Exit(ANode.IconIndex);
  Result := -1;
  SFI := Default(TCSHFileInfoW);
  H := 0;
  PIDL := nil;
  try
    case ANode.Kind of
      nkShortcut:
        begin
          W := UnicodeString(ANode.RealPath);
          if Copy(ANode.RealPath, 1, 2) = '\\' then
            // 共有フォルダー・WSL：ディスクへアクセスしない（待たされないため）一般的なフォルダーのアイコン
            H := _SHGetFileInfoW(PWideChar(W), FILE_ATTRIBUTE_DIRECTORY, SFI, SizeOf(SFI),
              CSHGFI_SYSICONINDEX or CSHGFI_SMALLICON or CSHGFI_USEFILEATTRIBUTES)
          else
            H := _SHGetFileInfoW(PWideChar(W), 0, SFI, SizeOf(SFI),
              CSHGFI_SYSICONINDEX or CSHGFI_SMALLICON);
        end;
      nkGroup:
        begin
          case ANode.Group of
            gkPC: _SHGetSpecialFolderLocation(0, CCSIDL_DRIVES, PIDL);
            gkNetwork: _SHGetSpecialFolderLocation(0, CCSIDL_NETWORK, PIDL);
            gkQuickAccess:
              begin
                W := CQuickAccessParse;
                Attr := 0;
                if Failed(_SHParseDisplayName(PWideChar(W), nil, PIDL, 0, Attr)) then PIDL := nil;
              end;
          else
            PIDL := nil; // Linux 等：一般的なフォルダーのアイコン
          end;
          if PIDL <> nil then
            H := _SHGetFileInfoW(PWideChar(PIDL), 0, SFI, SizeOf(SFI),
              CSHGFI_PIDL or CSHGFI_SYSICONINDEX or CSHGFI_SMALLICON)
          else
          begin
            W := 'folder';
            H := _SHGetFileInfoW(PWideChar(W), FILE_ATTRIBUTE_DIRECTORY, SFI, SizeOf(SFI),
              CSHGFI_SYSICONINDEX or CSHGFI_SMALLICON or CSHGFI_USEFILEATTRIBUTES);
          end;
        end;
    end;
    if H <> 0 then
    begin
      if FSysSmallImages = 0 then
        FSysSmallImages := HIMAGELIST(H);
      Result := SFI.iIcon;
    end;
  finally
    if PIDL <> nil then
      CoTaskMemFree(PIDL);
  end;
  ANode.IconIndex := Result;
  ANode.IconLoaded := True;
end;

function TCTreeView.DrawBuiltInIcon(ANode: TTreeNode; ARect: TRect): TSize;
var
  Idx, CX, CY, Y: Integer;
begin
  if not IsSpecialNode(ANode) then
  begin
    Result := inherited DrawBuiltInIcon(ANode, ARect);
    Exit;
  end;
  Result := GetBuiltinIconSize;
  Idx := SpecialIconIndex(TCTreeNode(ANode));
  if (Idx < 0) or (FSysSmallImages = 0) then Exit;
  CX := 16;
  CY := 16;
  ImageList_GetIconSize(FSysSmallImages, CX, CY);
  Y := ARect.Top + ((ARect.Bottom - ARect.Top) - CY) div 2;
  ImageList_Draw(FSysSmallImages, Idx, Canvas.Handle, ARect.Left, Y, ILD_TRANSPARENT);
end;

function TCTreeView.CompareFolderNames(Item1, Item2: TFileItem): Integer;
var
  W1, W2: UnicodeString;
begin
  W1 := UnicodeString(Item1.FileInfo.Name);
  W2 := UnicodeString(Item2.FileInfo.Name);
  Result := StrCmpLogicalW(PWideChar(W1), PWideChar(W2));
end;

function TCTreeView.GetCPath: string;
begin
  Result := GetPathFromNode(Selected);
end;

procedure TCTreeView.SetCPath(const AValue: string);
var
  Target, P, CP: string;
  Roots: TList;
  i, BestLen: Integer;
  Node, Child, Found: TTreeNode;
begin
  if AValue = '' then Exit;
  Target := ExcludeTrailingPathDelimiter(ExpandFileName(AValue));
  if not DirectoryExists(Target) then Exit;

  // 起点を選ぶ：ドライブを優先し、なければ（共有フォルダー・WSL 等）一致する最長の近道
  Node := nil;
  BestLen := -1;
  Roots := TList.Create;
  try
    GetPathRootNodes(Roots);
    for i := 0 to Roots.Count - 1 do
    begin
      P := ExcludeTrailingPathDelimiter(GetPathFromNode(TTreeNode(Roots[i])));
      if P = '' then Continue;
      if SameText(P, Target) or SameText(Copy(Target, 1, Length(P) + 1), P + PathDelim) then
      begin
        if IsDriveNode(TTreeNode(Roots[i])) and not IsShortcutNode(TTreeNode(Roots[i])) then
        begin
          Node := TTreeNode(Roots[i]);
          Break;
        end;
        if Length(P) > BestLen then
        begin
          BestLen := Length(P);
          Node := TTreeNode(Roots[i]);
        end;
      end;
    end;
  finally
    Roots.Free;
  end;
  if Node = nil then Exit;

  // 階層を1つずつ開いてたどる
  Items.BeginUpdate;
  try
    while True do
    begin
      P := ExcludeTrailingPathDelimiter(GetPathFromNode(Node));
      if SameText(P, Target) then Break;
      Node.Expanded := True;
      Found := nil;
      Child := Node.GetFirstChild;
      while Child <> nil do
      begin
        CP := ExcludeTrailingPathDelimiter(GetPathFromNode(Child));
        if SameText(CP, Target) or SameText(Copy(Target, 1, Length(CP) + 1), CP + PathDelim) then
        begin
          Found := Child;
          Break;
        end;
        Child := Child.GetNextSibling;
      end;
      if Found = nil then Break; // 隠しフォルダー等で見つからない：たどれたところまで
      Node := Found;
    end;
  finally
    Items.EndUpdate;
  end;
  Selected := Node;
  Node.MakeVisible;
end;

procedure TCTreeView.SetShowQuickAccess(AValue: Boolean);
begin
  if FShowQuickAccess = AValue then Exit;
  FShowQuickAccess := AValue;
  RebuildTopLevel;
end;

procedure TCTreeView.SetShowOneDrive(AValue: Boolean);
begin
  if FShowOneDrive = AValue then Exit;
  FShowOneDrive := AValue;
  RebuildTopLevel;
end;

procedure TCTreeView.SetShowNetwork(AValue: Boolean);
begin
  if FShowNetwork = AValue then Exit;
  FShowNetwork := AValue;
  RebuildTopLevel;
end;

procedure TCTreeView.SetShowLinux(AValue: Boolean);
begin
  if FShowLinux = AValue then Exit;
  FShowLinux := AValue;
  RebuildTopLevel;
end;

function TCTreeView.GetNetworkFolders: TStrings;
begin
  Result := FNetworkFolders;
end;

procedure TCTreeView.SetNetworkFolders(AValue: TStrings);
begin
  FNetworkFolders.Assign(AValue); // OnChange で作り直す
end;

procedure TCTreeView.NetworkFoldersChanged(Sender: TObject);
begin
  if FShowNetwork then
    RebuildTopLevel;
end;

function TCTreeView.IsDriveNode(Node: TTreeNode): Boolean;
begin
  Result := (Node <> nil) and IsDriveRootPath(GetPathFromNode(Node));
end;

function TCTreeView.CanEdit(Node: TTreeNode): Boolean;
begin
  // ドライブ・近道・グループは名前変更の対象外
  Result := inherited CanEdit(Node) and not IsDriveNode(Node) and not IsSpecialNode(Node);
end;

function TCTreeView.GetPIDLFromPath(const APath: string): PItemIDList;
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

procedure TCTreeView.DisplayShellContextMenu(const APath: string; const APoint: TPoint);
var
  FolderPIDL, FullPIDL, ChildPIDL: PItemIDList;
  DesktopFolder, ParentFolder: IShellFolder;
  ContextMenu: IContextMenu;
  HMenuPopup: HMENU;
  MenuCmd: UINT;
  ScreenPt: TPoint;
  ParentPath, Verb: string;
  ExtraItems: TList;
begin
  if APath = '' then Exit;
  ExtraItems := TList.Create;
  try

  ParentPath := ExtractFilePath(ExcludeTrailingPathDelimiter(APath));
  if ParentPath = '' then ParentPath := APath;

  FolderPIDL := GetPIDLFromPath(ParentPath);
  if FolderPIDL = nil then Exit;

  try
    if Succeeded(SHGetDesktopFolder(DesktopFolder)) then
    begin
      if Succeeded(DesktopFolder.BindToObject(FolderPIDL, nil, IID_IShellFolder, Pointer(ParentFolder))) then
      begin
        FullPIDL := GetPIDLFromPath(APath);
        if FullPIDL <> nil then
        begin
          ChildPIDL := ILFindLastID(FullPIDL);
          if Succeeded(ParentFolder.GetUIObjectOf(0, 1, ChildPIDL, IID_IContextMenu, nil, Pointer(ContextMenu))) then
          begin
            HMenuPopup := CreatePopupMenu;
            if HMenuPopup <> 0 then
            begin
              try
                if Succeeded(ContextMenu.QueryContextMenu(HMenuPopup, 0, 1, $7FFF, CMF_NORMAL)) then
                begin
                  // アプリの独自メニュー（ノードの上）を追加する
                  ExtraMenuInsert(HMenuPopup, FExtraItemMenu, FExtraMenuPosition, Self, ExtraItems);

                  ScreenPt := ClientToScreen(APoint);
                  // 「送る」などのサブメニューが正しく表示されるよう、共通部品で表示する
                  MenuCmd := TrackShellContextMenu(Handle, HMenuPopup, ContextMenu, ScreenPt.X, ScreenPt.Y);
                  if ExtraMenuClick(ExtraItems, MenuCmd) then
                  begin
                    // 独自メニューの項目：その項目の OnClick を呼んだ
                    MenuCmd := 0;
                    Verb := '';
                  end
                  else if MenuCmd <> 0 then
                    Verb := ShellMenuVerb(ContextMenu, MenuCmd - 1)
                  else
                    Verb := '';

                  if SameText(Verb, 'rename') then
                    // シェルの「名前の変更」はこの画面では動かないため、自前の名前変更に切り替える
                    RenameSelectedFolder
                  else if MenuCmd <> 0 then
                  begin
                    // エクスプローラーと同じく、作業フォルダー（項目があるフォルダー）を渡して実行する
                    ShellInvokeMenuCommand(ContextMenu, Handle, MenuCmd - 1, ParentPath);
                    // 表示の更新はフォルダー変更監視に任せる
                  end;
                end;
              finally
                DestroyMenu(HMenuPopup);
              end;
            end;
          end;
          CoTaskMemFree(FullPIDL);
        end;
      end;
    end;
  finally
    CoTaskMemFree(FolderPIDL);
  end;
  finally
    ExtraItems.Free;
  end;
end;

// ワイド文字版（W版）で実行する。
// ANSI版に UTF-8 文字列を渡すと日本語パスで失敗するため。
function TCTreeView.PerformFileOperation(AOp: UINT; const ASource, ADest: string;
  AAllowUndo: Boolean): Boolean;
var
  ShOp: SHFILEOPSTRUCTW;
  SourceBuf, DestBuf: WideString;
begin
  ShOp := Default(SHFILEOPSTRUCTW);

  // 末尾の #0#0 は、変換後も二重ヌル終端として残る
  SourceBuf := WideString(ASource + #0#0);
  DestBuf := WideString(ADest + #0#0);

  ShOp.Wnd := Handle;
  ShOp.wFunc := AOp;
  ShOp.pFrom := PWideChar(SourceBuf);
  if ADest <> '' then
    ShOp.pTo := PWideChar(DestBuf);
  // AAllowUndo = False（完全削除）でも、確認ダイアログは表示される
  if AAllowUndo then
    ShOp.fFlags := FOF_ALLOWUNDO
  else
    ShOp.fFlags := 0;

  Result := (SHFileOperationW(@ShOp) = 0) and (not ShOp.fAnyOperationsAborted);
end;

procedure TCTreeView.DoContextPopup(MousePos: TPoint; var Handled: Boolean);
var
  Node: TTreeNode;
  FolderPath: string;
begin
  Node := GetNodeAt(MousePos.X, MousePos.Y);
  if Node <> nil then
  begin
    Selected := Node;
    FolderPath := GetPathFromNode(Node);
    DisplayShellContextMenu(FolderPath, MousePos);
  end
  else
    // 空白部分：独自メニュー（ExtraBackgroundMenu）だけを表示する
    DisplayBackgroundMenu(MousePos);
  // コンポーネント自身の PopupMenu は使わない
  Handled := True;
  inherited DoContextPopup(MousePos, Handled);
end;

procedure TCTreeView.DisplayBackgroundMenu(const APoint: TPoint);
var
  HMenuPopup: HMENU;
  MenuCmd: UINT;
  ScreenPt: TPoint;
  ExtraItems: TList;
begin
  if FExtraBackgroundMenu = nil then Exit;
  ExtraItems := TList.Create;
  try
    HMenuPopup := CreatePopupMenu;
    if HMenuPopup = 0 then Exit;
    try
      if ExtraMenuInsert(HMenuPopup, FExtraBackgroundMenu, FExtraMenuPosition, Self, ExtraItems) = 0 then Exit;
      ScreenPt := ClientToScreen(APoint);
      MenuCmd := TrackShellContextMenu(Handle, HMenuPopup, nil, ScreenPt.X, ScreenPt.Y);
      ExtraMenuClick(ExtraItems, MenuCmd);
    finally
      DestroyMenu(HMenuPopup);
    end;
  finally
    ExtraItems.Free;
  end;
end;

procedure TCTreeView.SetExtraItemMenu(AValue: TPopupMenu);
begin
  if FExtraItemMenu = AValue then Exit;
  if FExtraItemMenu <> nil then FExtraItemMenu.RemoveFreeNotification(Self);
  FExtraItemMenu := AValue;
  if FExtraItemMenu <> nil then FExtraItemMenu.FreeNotification(Self);
end;

procedure TCTreeView.SetExtraBackgroundMenu(AValue: TPopupMenu);
begin
  if FExtraBackgroundMenu = AValue then Exit;
  if FExtraBackgroundMenu <> nil then FExtraBackgroundMenu.RemoveFreeNotification(Self);
  FExtraBackgroundMenu := AValue;
  if FExtraBackgroundMenu <> nil then FExtraBackgroundMenu.FreeNotification(Self);
end;

procedure TCTreeView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FExtraItemMenu then FExtraItemMenu := nil;
    if AComponent = FExtraBackgroundMenu then FExtraBackgroundMenu := nil;
  end;
end;

procedure TCTreeView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  // Ctrl + C / X / V（選択フォルダーが対象・貼り付け先）
  if (ssCtrl in Shift) and (Key in [VK_C, VK_X, VK_V]) then
  begin
    case Key of
      VK_C: CopySelectedFolder;
      VK_X: CutSelectedFolder;
      VK_V: PasteToSelectedFolder;
    end;
    Key := 0;
    inherited KeyDown(Key, Shift);
    Exit;
  end;

  case Key of
    VK_F2:
      begin
        RenameSelectedFolder;
        Key := 0;
      end;
    VK_DELETE:
      begin
        // Shift + Delete は完全削除
        DeleteSelectedFolder(ssShift in Shift);
        Key := 0;
      end;
    VK_F5:
      begin
        // 手動更新（ネットワークドライブ等、変更通知が届かない場合の手段）
        DoRefreshVisibleNodes;
        Key := 0;
      end;
  end;
  inherited KeyDown(Key, Shift);
end;

procedure TCTreeView.RenameSelectedFolder;
begin
  // ドライブノードは名前変更の対象外
  if (Selected <> nil) and not IsDriveNode(Selected) and not IsSpecialNode(Selected) then
  begin
    Selected.EditText;
  end;
end;

procedure TCTreeView.DeleteSelectedFolder(APermanent: Boolean);
var
  FolderPath: string;
begin
  if Selected = nil then Exit;
  // ドライブ・近道・グループは削除の対象外
  if IsDriveNode(Selected) or IsSpecialNode(Selected) then Exit;

  FolderPath := GetPathFromNode(Selected);
  // 表示の更新はフォルダー変更監視に任せる
  if FolderPath <> '' then
    PerformFileOperation(FO_DELETE, ExcludeTrailingPathDelimiter(FolderPath), '', not APermanent);
end;

procedure TCTreeView.CopySelectedFolder;
var
  L: TStringList;
  FolderPath: string;
begin
  if Selected = nil then Exit;
  FolderPath := GetPathFromNode(Selected);
  if FolderPath = '' then Exit;
  L := TStringList.Create;
  try
    L.Add(ExcludeTrailingPathDelimiter(FolderPath));
    if IsDriveNode(Selected) then
      L[0] := IncludeTrailingPathDelimiter(L[0]); // "C:" は "C:" にする
    ShellInvokeVerbOnItems(Handle, L, 'copy');
  finally
    L.Free;
  end;
end;

procedure TCTreeView.CutSelectedFolder;
var
  L: TStringList;
  FolderPath: string;
begin
  if Selected = nil then Exit;
  // ドライブ・近道・グループは切り取りの対象外
  if IsDriveNode(Selected) or IsSpecialNode(Selected) then Exit;
  FolderPath := GetPathFromNode(Selected);
  if FolderPath = '' then Exit;
  L := TStringList.Create;
  try
    L.Add(ExcludeTrailingPathDelimiter(FolderPath));
    ShellInvokeVerbOnItems(Handle, L, 'cut');
  finally
    L.Free;
  end;
end;

procedure TCTreeView.PasteToSelectedFolder;
var
  FolderPath: string;
begin
  if Selected = nil then Exit;
  FolderPath := GetPathFromNode(Selected);
  // 表示の更新はフォルダー変更監視に任せる
  if FolderPath <> '' then
    ShellInvokeVerbOnFolder(Handle, FolderPath, 'paste');
end;

// パスからノードを探す。ツリー全体をたどらず、パスの前方が一致するノードの子だけを辿る。
// （まだ読み込まれていない＝展開されたことのない階層にあるノードは見つからない）
function TCTreeView.FindNodeForPath(const APath: string; const APreferRoot: string): TTreeNode;
var
  Target, Pref: string;
  Roots: TList;
  i, Pass: Integer;
  R: TTreeNode;
begin
  Result := nil;
  if APath = '' then Exit;
  Target := ExcludeTrailingPathDelimiter(APath);
  Pref := ExcludeTrailingPathDelimiter(APreferRoot);
  Roots := TList.Create;
  try
    GetPathRootNodes(Roots);
    // 1回目：優先する起点だけ、2回目：すべて（ドライブが先）
    for Pass := 1 to 2 do
    begin
      if (Pass = 1) and (Pref = '') then Continue;
      for i := 0 to Roots.Count - 1 do
      begin
        R := TTreeNode(Roots[i]);
        if (Pass = 1) and not SameText(ExcludeTrailingPathDelimiter(GetPathFromNode(R)), Pref) then Continue;
        Result := FindNodeUnder(R, Target);
        if Result <> nil then Exit;
      end;
    end;
  finally
    Roots.Free;
  end;
end;

procedure TCTreeView.DoAsyncRename(Data: PtrInt);
var
  Info: PRenameInfo;
begin
  {$push}{$hints off}
  Info := PRenameInfo(Data);
  {$pop}
  try
    // 実行時点で既にコンポーネントが破棄中なら何もしない
    // (Application.RemoveAsyncCallsで通常は防げるが、念のための二重ガード)
    if csDestroying in ComponentState then Exit;

    // シェル経由で名前を変更する（使用中などで失敗した場合は、シェルが理由を表示する）。
    // 成功時の表示更新はフォルダー変更監視に任せる。
    if not ShellRenameItem(Handle, Info^.OldPath, ExtractFileName(Info^.NewPath)) then
    begin
      // 失敗時は、編集で変わったノードの表示を元に戻すため、親フォルダーを読み直す
      FPendingPaths.Add(ExcludeTrailingPathDelimiter(Info^.ParentPath));
      FNotifyTimer.Enabled := False;
      FNotifyTimer.Enabled := True;
    end;
  finally
    Dispose(Info);
  end;
end;

procedure TCTreeView.InternalOnEdited({%H-}Sender: TObject; Node: TTreeNode; var S: string);
var
  OldPath, NewPath, ParentDir: string;
  Info: PRenameInfo;
begin
  if (Node = nil) or (S = '') then Exit;

  // ドライブノードは名前変更の対象外（CanEditで防いでいるが念のため）
  if IsDriveNode(Node) then
  begin
    S := Node.Text;
    Exit;
  end;

  // 1. 禁則文字チェック
  if ContainsInvalidChar(S) then
  begin
    ShowMessage('フォルダ名に以下の文字は使用できません:' + sLineBreak + '\ / : * ? " < > |');
    S := Node.Text;
    Exit;
  end;

  // 変更前のパスは表示名ではなく、ノードが持つ実際のパスから取得する
  OldPath := ExcludeTrailingPathDelimiter(GetPathFromNode(Node));
  if OldPath = '' then Exit;

  ParentDir := ExtractFilePath(OldPath);
  NewPath := IncludeTrailingPathDelimiter(ParentDir) + S;

  if NewPath <> OldPath then
  begin
    New(Info);
    Info^.OldPath := OldPath;
    Info^.NewPath := NewPath;
    Info^.ParentPath := ParentDir;
    // 実際のリネームも非同期で行う（編集終了処理と競合させない）
    {$push}{$hints off}
    Application.QueueAsyncCall(@DoAsyncRename, PtrInt(Info));
    {$pop}
  end;
end;

procedure TCTreeView.DoRefreshVisibleNodes;
var
  ExpandedPaths: TStringList; // Refresh前に「開いていたノード」のパスを記憶しておく
  SelectedPath, SelRootPath: string;

  // Refresh前の展開状態を再帰的に収集
  procedure CollectExpanded(ANode: TTreeNode);
  var
    Child: TTreeNode;
  begin
    if ANode = nil then Exit;
    if ANode.Expanded then
      ExpandedPaths.Add(NodeKey(ANode));

    Child := ANode.GetFirstChild;
    while Child <> nil do
    begin
      CollectExpanded(Child);
      Child := Child.GetNextSibling;
    end;
  end;

  // 元々「開いていた」ノードだけをRefreshし、Refresh後に開き直す
  // （開いていなかったノードは触らない＝無駄な列挙をしない）
  procedure RefreshAndRestore(ANode: TTreeNode);
  var
    Child: TTreeNode;
  begin
    if ANode = nil then Exit;
    if ExpandedPaths.IndexOf(NodeKey(ANode)) < 0 then
      Exit; // 元々畳まれていたノードはそのまま（無理に開かない）

    Refresh(ANode);        // 子ノードを作り直す（作り直された子は畳まれた状態で生成される）
    ANode.Expanded := True; // 元々開いていたので開き直す

    // 作り直された後の新しい子ノードを取得してから再帰する
    Child := ANode.GetFirstChild;
    while Child <> nil do
    begin
      RefreshAndRestore(Child);
      Child := Child.GetNextSibling;
    end;
  end;

var
  Node: TTreeNode;
begin
  if FIsRefreshing then Exit; // 多重実行防止
  if csDestroying in ComponentState then Exit;

  FIsRefreshing := True;
  try
    ExpandedPaths := TStringList.Create;
    try
      ExpandedPaths.Sorted := True;
      ExpandedPaths.Duplicates := dupIgnore;

      SelRootPath := '';
      if Selected <> nil then
      begin
        SelectedPath := ExcludeTrailingPathDelimiter(GetPathFromNode(Selected));
        if PathRootOf(Selected) <> nil then
          SelRootPath := ExcludeTrailingPathDelimiter(GetPathFromNode(PathRootOf(Selected)));
      end
      else
        SelectedPath := '';

      // 1. 現在の展開状態・選択状態を記憶
      Node := Items.GetFirstNode;
      while Node <> nil do
      begin
        CollectExpanded(Node);
        Node := Node.GetNextSibling;
      end;

      try
        Items.BeginUpdate;
        try
          // 2. 記憶した範囲だけRefreshし、開き直す
          Node := Items.GetFirstNode;
          while Node <> nil do
          begin
            RefreshAndRestore(Node);
            Node := Node.GetNextSibling;
          end;

          // 3. 選択状態を復元（対象がRefresh後もまだ存在すれば）
          if SelectedPath <> '' then
          begin
            Node := FindNodeForPath(SelectedPath, SelRootPath);
            if Node <> nil then
              Selected := Node;
          end;
        finally
          Items.EndUpdate;
        end;
      except
        // Refresh中の例外がメッセージ処理全体に波及しないよう握りつぶす（次回のF5で再試行される）
      end;
    finally
      ExpandedPaths.Free;
    end;
  finally
    FIsRefreshing := False;
  end;
end;

// ---------------------------------------------------------------
// D&D（ドラッグの開始は OLE。アプリ内・他のアプリへのドラッグとも同じ仕組み）
// ---------------------------------------------------------------

procedure TCTreeView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Node: TTreeNode;
begin
  inherited MouseDown(Button, Shift, X, Y);
  FDragArmed := False;
  // 左／右ボタンでドラッグできる（右ドラッグはメニュー付きのドロップ）
  if not (Button in [mbLeft, mbRight]) or IsEditing then Exit;

  Node := GetNodeAt(X, Y);
  // ドライブ・仮想フォルダーはドラッグできない
  if (Node = nil) or IsDriveNode(Node) or IsSpecialNode(Node) then Exit;
  FDragNodePath := GetPathFromNode(Node);
  if FDragNodePath = '' then Exit;

  FDragArmed := True;
  FDragButton := Button;
  FDragStartPt.X := X; // Point() は Windows ユニットの型 POINT と衝突するため使わない
  FDragStartPt.Y := Y;
end;

procedure TCTreeView.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  L: TStringList;
  Effect: DWORD;
  Dropped: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  if not FDragArmed then Exit;
  if ((FDragButton = mbLeft) and not (ssLeft in Shift)) or
     ((FDragButton = mbRight) and not (ssRight in Shift)) then
  begin
    FDragArmed := False;
    Exit;
  end;

  // 一定距離動いたらドラッグ開始（ドラッグするのは1フォルダーのみ）
  if (Abs(X - FDragStartPt.X) >= GetSystemMetrics(SM_CXDRAG)) or
     (Abs(Y - FDragStartPt.Y) >= GetSystemMetrics(SM_CYDRAG)) then
  begin
    FDragArmed := False;
    L := TStringList.Create;
    try
      L.Add(ExcludeTrailingPathDelimiter(FDragNodePath));
      // アプリ内のドロップ先で禁止判定に使うため、ドラッグ中の項目を登録しておく
      ShellDragBegin(Self, L);
      try
        // OLE のドラッグを開始する（ドロップ・取り消しまでここで待つ）。
        // コピー／移動はドロップ先（シェル）が行う。表示の更新はフォルダー変更監視に任せる。
        Dropped := ShellDoDragDrop(Handle, L, False, Effect);
        ShellDragLog('TCTreeView.DoDragDrop dropped=' + BoolToStr(Dropped, True) +
          ' effect=' + IntToStr(Effect));
      finally
        ShellDragEnd;
        // ボタンを離した通知はドラッグ処理が受け取っているため、マウスの捕捉を解放しておく
        ReleaseCapture;
      end;
    finally
      L.Free;
    end;
  end;
end;

procedure TCTreeView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FDragArmed := False;
  inherited MouseUp(Button, Shift, X, Y);
end;

// ドロップ候補の強調表示は、Paint の後に自前で枠を描く
procedure TCTreeView.SetDropHilite(ANode: TTreeNode);
begin
  if FDropHilite = ANode then Exit;
  FDropHilite := ANode;
  // 枠を描き直す（前の枠を消し、新しい枠を描く）
  Invalidate;
end;

procedure TCTreeView.Paint;
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

// --- ドロップの受け付け（OLE：他のアプリ・アプリ内のどちらからのドラッグも） ---

function TCTreeView.OleResolveDrop(const AScreenPt: TPoint): string;
var
  Pt: TPoint;
  Node: TTreeNode;
begin
  Result := '';
  if not HandleAllocated then Exit;
  FOleDragOver := True;
  FDragTimer.Enabled := True; // 自動スクロール・自動展開

  // ドロップ先はノードのフォルダー（実体のパスを持たない仮想フォルダーは拒否）
  Pt := ScreenToClient(AScreenPt);
  Node := GetNodeAt(Pt.X, Pt.Y);
  if Node <> nil then
    Result := GetPathFromNode(Node);

  // アプリ内から始めたドラッグは、禁止判定（自分自身・配下、同じフォルダーへの移動）を行う
  if (Result <> '') and ShellDragIsActive and
     (ShellDecideDropEffect(ShellDragPaths, Result, ShellDragKeyState) = cdeNone) then
    Result := '';

  if Result <> '' then
    SetDropHilite(Node)
  else
    SetDropHilite(nil);
end;

procedure TCTreeView.OleDropLeave;
begin
  FOleDragOver := False;
  FDragTimer.Enabled := False;
  FHoverNode := nil;
  SetDropHilite(nil);
end;

procedure TCTreeView.OleDropped(const {%H-}AFolder: string);
begin
  // 表示の更新はフォルダー変更監視に任せる
end;

procedure TCTreeView.DragTimerTick({%H-}Sender: TObject);
const
  Margin = 20;
  ExpandDelay = 700; // ms：この時間ノードの上に留まったら自動展開
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

  // 2. 同じノードの上に一定時間留まったら展開する
  Node := GetNodeAt(Pt.X, Pt.Y);
  if Node <> FHoverNode then
  begin
    FHoverNode := Node;
    FHoverSince := GetTickCount64;
  end
  else if (Node <> nil) and not Node.Expanded and Node.HasChildren and
          (GetTickCount64 - FHoverSince >= ExpandDelay) then
  begin
    Node.Expanded := True;
    FHoverSince := GetTickCount64;
  end;
end;


end.
