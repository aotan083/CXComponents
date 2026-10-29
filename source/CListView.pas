{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
unit CListView;

{$mode objfpc}{$H+}
{$WARN 4055 OFF} // 順序型⇔ポインターの変換（Win32 API の引数のため意図的）

interface

uses
  Classes, SysUtils, Controls, ComCtrls, ShellCtrls, Windows, ActiveX,
  ShlObj, ShellAPI, Messages, Graphics, Dialogs, Forms, Clipbrd, LMessages,
  LazUTF8, ExtCtrls, CommCtrl, Menus, CShellNotify, CShellMenu, CShellDragDrop, CShellOleDrop, CShellOleDrag;

type

  { TCListView }

  // 項目情報（並べ替え・表示用に、フォルダー列挙時にまとめて取得して保持する）
  TCItemInfo = class
  public
    IsDir: Boolean;
    DateStr: string; // 更新日時（YYYY/MM/DD HH:NN）
  end;

  TCListView = class(TShellListView)
  private
    FOnFolderChanged: TNotifyEvent;    // フォルダー変更イベント
    FOnSelectionChanged: TNotifyEvent; // 選択変更イベント
    FLastRoot: string;                 // 前回通知時の Root（変更検出用）
    FSelectionDirty: Boolean;          // 選択変更の通知待ちフラグ
    FSortColumn: Integer;
    FSortAscending: Boolean;
    FInResize: Boolean; // リサイズループ防止フラグ
    FColumnResizePending: Boolean; // 列幅再計算の予約済みフラグ（重複予約防止）
    FSortPending: Boolean;         // 並べ替えの予約済みフラグ（重複予約防止）
    FLastColWidths: array[0..3] of Integer; // 自動調整で最後に設定した列幅（手動変更の検出用）
    FUserSizedColumns: Boolean;    // ユーザーが列幅を手動で変えたら True（自動調整を止める）

    // --- フォルダー変更監視 ---
    FNotifyRootID: ULONG;          // Root 直下の変更通知の登録ID
    FNotifyParentID: ULONG;        // Root の親の変更通知の登録ID（Root 自体の削除・名前変更の検出用）
    FNotifyRoot: string;           // 通知を登録している Root
    FNotifyTimer: TTimer;          // 通知の間引き用（最後の通知から一定時間後に1回だけ更新）
    FSelectNewItems: Boolean;      // 次回更新時に、新しく現れた項目を選択状態にする（貼り付け・ドロップ後）

    // --- D&D ---
    FDragArmed: Boolean;           // マウスボタンが項目の上で押された（一定距離動いたらドラッグ開始）
    FDragButton: TMouseButton;     // ドラッグを始めたボタン（左 or 右）
    FDragStartPt: TPoint;
    FDropHilite: TListItem;        // ドロップ候補として強調表示中の項目
    FDragTimer: TTimer;            // ドラッグ中の自動スクロール用
    // --- 他のアプリ（エクスプローラー等）からのドロップ（OLE） ---
    FOleTarget: TCShellOleDropTarget;
    FOleDragOver: Boolean;         // 他のアプリからのドラッグが上に乗っている
    function OleResolveDrop(const AScreenPt: TPoint): string;
    procedure OleDropLeave;
    procedure OleDropped(const AFolder: string);
    // ドラッグを開始する（リストビュー自身のマウス処理が終わった後に、メッセージ経由で呼ぶ）
    procedure StartOleDrag;

    // ドロップ先フォルダーを決める（空白部分・ファイル項目 = Root、フォルダー項目 = そのフォルダー）
    procedure SetDropHilite(AItem: TListItem);
    // ドロップ候補の周りに枠を描く（WM_PAINT の後に呼ぶ）
    procedure DrawDropFrame;
    procedure DragTimerTick({%H-}Sender: TObject);

    procedure RegisterFolderNotify;
    procedure UnregisterFolderNotify;
    procedure HandleShellNotify(AWParam: WPARAM; ALParam: LPARAM);
    // 変更通知を行単位で反映する（削除・名前変更・内容更新）。反映できない変更があれば全件読み直す
    procedure ApplyPendingChanges;
    // 名前（Caption）から項目を探す
    function FindItemByName(const AName: string): TListItem;
    // シェル経由の名前変更（非同期）
    procedure DoAsyncRename(Data: PtrInt);
    procedure NotifyTimerTick({%H-}Sender: TObject);
    // 表示中のフォルダーが消えた場合、存在する親フォルダーまで遡って表示する
    procedure NavigateToExistingParent;

    function GetAutoFitNameColumn: Boolean;
    procedure SetAutoFitNameColumn(AValue: Boolean);

    procedure NotifyFolderChanged; // フォルダー変更イベントの呼び出し
    // Root と選択の変化を検出して、イベントをまとめて1回ずつ発行する
    procedure CheckStateChanged;
    procedure InternalAppIdle(Sender: TObject; var Done: Boolean);
    // ソート用の比較関数
    function CompareItems(Item1, Item2: TListItem): Integer;
    procedure ApplySort; // ソート実行ヘルパー
    procedure PopulateFileDateTimes; // 全アイテムへ更新日時を補完

  private
    // --- 変更通知の差分反映 ---
    FPendingChanges: TStringList;  // Strings = パス1 + #1 + パス2、Objects = イベント
    FNeedFullRefresh: Boolean;     // 行単位で反映できない変更があった（全件読み直す）
    // --- 項目情報のキャッシュ（並べ替えでディスクへ問い合わせないため） ---
    // （メソッドの後にフィールドを置くため、可視性セクションを開き直す）
    FItemInfo: TStringList;        // 名前 → TCItemInfo（表示中フォルダーの全項目）
    FItemInfoRoot: string;         // キャッシュを作ったときの Root
    // 表示中フォルダーを1回だけ列挙して、全項目のフォルダー判定・更新日時を取得する
    procedure RebuildItemInfo;
    // 名前から項目情報を得る（Root が変わっていれば作り直す）。見つからなければ nil
    function FindItemInfo(const AName: string): TObject;

    procedure DisplayShellContextMenu(const APath: string; const APoint: TPoint; IsFolderContext: Boolean);
    function PerformFileOperation(AOp: UINT; const ASource, ADest: string; AAllowUndo: Boolean = True): Boolean;
    function GetPIDLFromPath(const APath: string): PItemIDList;
    procedure DoAsyncRefresh(Data: PtrInt);
    procedure DoAsyncSort(Data: PtrInt);
    procedure DoAsyncColumnResize(Data: PtrInt); // ← 追加：列幅再計算を非同期化
    procedure InternalOnEdited(Sender: TObject; Item: TListItem; var S: string);
    procedure DoColumnClick(Sender: TObject; AColumn: TListColumn);
    procedure DoAddItemHandler(Sender: TObject; const APath: string; const AItem: TRawByteSearchRec; var CanAdd: Boolean);

    // 独自作成メソッド
    function CreateNewFolderInRoot: string;
    function CreateNewFileInRoot(const AExtension: string = '.txt'): string;
    procedure FocusAndRenamePath(const APath: string);
  private
    // --- 戻る・進む（フォルダーの履歴） ---
    FHistory: TStringList;         // 移動したフォルダーの履歴（古い順）
    FHistIndex: Integer;           // 履歴上の現在位置（-1 = 履歴なし）
    FHistSkip: string;             // 戻る・進むで移動中のフォルダー（履歴に追加しない）
    FMaxHistory: Integer;
    FInXButton: Boolean;           // WM_XBUTTONUP の処理中（同時に届く WM_APPCOMMAND を二重に処理しない）
    // --- 右クリックメニューへの独自項目 ---
    FExtraItemMenu: TPopupMenu;
    FExtraBackgroundMenu: TPopupMenu;
    FExtraMenuPosition: TCExtraMenuPosition;
    procedure SetExtraItemMenu(AValue: TPopupMenu);
    procedure SetExtraBackgroundMenu(AValue: TPopupMenu);
  private
    // --- 表示形式 ---
    FLastViewStyle: TViewStyle;    // 前回確認した表示形式（変更検出用）
    // 右クリックメニューに「表示」「並べ替え」のサブメニューを追加する（空白部分）
    procedure AddViewSortMenus(AMenu: HMENU; ABaseID: UINT);
    procedure RecordHistory(const APath: string);
    function HistoryGo(ADelta: Integer): Boolean;
    procedure SetMaxHistory(AValue: Integer);
  protected
    procedure DoContextPopup(MousePos: TPoint; var Handled: Boolean); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DblClick; override;
    procedure Resize; override;

    procedure DoSelectItem(AItem: TListItem; ASelected: Boolean); override;

    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure WndProc(var Message: TLMessage); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // フォルダー移動の窓口。内部の移動はすべてここを通す。
    // （リンクした ShellTreeView など外部からの Root 変更も、イベントは同様に発行される）
    function NavigateTo(const APath: string): Boolean;
    // 親フォルダーへ移動（ドライブのルートでは何もしない）
    function NavigateUp: Boolean;

    // 選択項目を削除する（APermanent = False: ごみ箱へ移動、True: 完全削除）
    procedure DeleteSelectedFiles(APermanent: Boolean = False);
    // 選択項目をクリップボードへコピー／切り取り（シェルのコマンドで実行）
    procedure CopySelected;
    procedure CutSelected;
    // 表示中のフォルダーへ貼り付け（シェルのコマンドで実行）
    procedure PasteToRoot;
    // すべて選択
    procedure SelectAllItems;
    procedure RenameSelectedFile;
    function GetSelectedFilePath: string;
    // 選択中の全項目のフルパスを取得する（ステータスバー等向け）
    procedure GetSelectedPaths(AList: TStrings);
    // 名前列を残り幅に自動で合わせるか。
    // ユーザーが列幅を手動で変えると False になる。True を設定すると自動調整を再開する。
    property AutoFitNameColumn: Boolean read GetAutoFitNameColumn write SetAutoFitNameColumn;
    // 次回の表示更新で、新しく現れた項目を選択状態にする（貼り付け・ドロップの直前に呼ぶ）
    procedure SelectNewItemsOnNextRefresh;
    // --- 戻る・進む ---
    // 履歴の1つ前／次のフォルダーへ移動する。存在しなくなったフォルダーは履歴から除いて飛ばす。
    // マウスの戻る／進むボタンでも呼ばれる（リンクした TCTreeView の上でのボタンを含む）。
    function GoBack: Boolean;
    function GoForward: Boolean;
    function CanGoBack: Boolean;
    function CanGoForward: Boolean;
    // 履歴を消去する（現在のフォルダーだけを残す）
    procedure ClearHistory;
    // --- 表示形式・並べ替え ---
    // 表示形式を切り替える（vsReport = 詳細、vsIcon = 大アイコン、vsSmallIcon = 小アイコン、vsList = 一覧）。
    // ViewStyle に直接設定してもよい（アイドル時に検出して表示を作り直す）
    procedure SetView(AStyle: TViewStyle);
    // 並べ替える（AColumn：0 = 名前、1 = サイズ、2 = 種類、3 = 更新日時）
    procedure SortBy(AColumn: Integer; AAscending: Boolean);
    property SortColumn: Integer read FSortColumn;
    property SortAscending: Boolean read FSortAscending;
    // 履歴の上限件数（既定 20、最小 2）。超えたら古いものから削除する。
    property MaxHistory: Integer read FMaxHistory write SetMaxHistory;
  published
    // 右クリックメニューに追加する独自メニュー（項目の上／空白部分）。処理は各メニュー項目の OnClick に書く
    property ExtraItemMenu: TPopupMenu read FExtraItemMenu write SetExtraItemMenu;
    property ExtraBackgroundMenu: TPopupMenu read FExtraBackgroundMenu write SetExtraBackgroundMenu;
    // 独自メニューを追加する位置（empTop = 先頭、empBottom = 末尾）
    property ExtraMenuPosition: TCExtraMenuPosition read FExtraMenuPosition write FExtraMenuPosition default empBottom;
    // Root が変わったとき（ダブルクリック、Enter、BackSpace、ツリー連動など）
    property OnFolderChanged: TNotifyEvent read FOnFolderChanged write FOnFolderChanged;
    // 選択項目が変わったとき（複数選択の変化は1回にまとめて通知）
    property OnSelectionChanged: TNotifyEvent read FOnSelectionChanged write FOnSelectionChanged;
  end;

// 名前変更後のフルパスを、表示名ではなく実際のファイル名を元に組み立てる
function BuildRenamedPath(const AOldPath, ADisplayName, ANewName: string): string;

implementation

// Windows エクスプローラーと同等の自然順ソートを行う API 宣言
function StrCmpLogicalW(psz1, psz2: PWideChar): Integer; stdcall; external 'shlwapi.dll';

// 表示名が「拡張子なしの実ファイル名」になっている場合（将来の拡張子非表示）は、
// 入力された新しい名前に元の拡張子を補う。
// 表示名が実ファイル名と同じ（現状）なら、入力された名前をそのまま使う。
// フォルダーは拡張子の補完を行わない。
function BuildRenamedPath(const AOldPath, ADisplayName, ANewName: string): string;
var
  OldPath, ActualName, Ext: string;
begin
  OldPath := ExcludeTrailingPathDelimiter(AOldPath);
  ActualName := ExtractFileName(OldPath);
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(OldPath)) + ANewName;

  if DirectoryExists(OldPath) then Exit;

  Ext := ExtractFileExt(ActualName);
  if (Ext <> '') and (ADisplayName <> ActualName) and
     (ADisplayName = ChangeFileExt(ActualName, '')) then
    Result := Result + Ext;
end;

{ TCListView }

constructor TCListView.Create(AOwner: TComponent);
var
  NewCol: TListColumn;
  i: Integer;
begin
  inherited Create(AOwner);
  ReadOnly := True;
  // ドラッグは一定距離マウスを動かしたときに自前で開始する（クリック・名前変更との誤作動を防ぐ）
  DragMode := dmManual;
  ViewStyle := vsReport;
  MultiSelect := True;
  FInResize := False;

  // 基底クラス（TShellListView）の列幅自動調整を止める。
  // 基底側は Resize のたびにスクロールバー込みの Width を基準に列幅を再設定するため、
  // 縦スクロールバー表示中に横スクロールバーが出入りして Resize が循環し、
  // 自前の列幅調整（DoAsyncColumnResize）とも書き換え合ってチラつく。
  AutoSizeColumns := False;

  // 描画のダブルバッファは、LCL の DoubleBuffered ではなく
  // Windows リストビュー自身の仕組み（LVS_EX_DOUBLEBUFFER）を使う（CreateWnd で設定）

  ObjectTypes := [otFolders, otNonFolders];
  OnEdited := @InternalOnEdited;
  OnColumnClick := @DoColumnClick;
  OnAddItem := @DoAddItemHandler;

  FSortColumn := 2;
  FSortAscending := True;
  FLastViewStyle := vsReport;
  // アイコン表示でも並べ替えの順に自動で整列する
  IconOptions.AutoArrange := True;

  // --------------------------------------------------
  // ヘッダー列名をすべて日本語表記に揃える
  // --------------------------------------------------
  if Columns.Count >= 1 then Columns[0].Caption := '名前';
  if Columns.Count >= 2 then Columns[1].Caption := 'サイズ';
  if Columns.Count >= 3 then Columns[2].Caption := '種類';

  // 4番目の列（Index 3）として「更新日時」を追加
  NewCol := Columns.Add;
  NewCol.Caption := '更新日時';
  NewCol.Width := 140;
  NewCol.Alignment := taLeftJustify;

  FPendingChanges := TStringList.Create;
  FNeedFullRefresh := False;

  FItemInfo := TStringList.Create;
  FItemInfo.CaseSensitive := False;
  FItemInfo.Duplicates := dupIgnore;
  FItemInfo.OwnsObjects := True;
  FItemInfoRoot := '';

  FHistory := TStringList.Create;
  FHistIndex := -1;
  FHistSkip := '';
  FMaxHistory := 20;
  FExtraItemMenu := nil;
  FExtraBackgroundMenu := nil;
  FExtraMenuPosition := empBottom;

  FLastRoot := '';
  FSelectionDirty := False;
  FUserSizedColumns := False;
  for i := Low(FLastColWidths) to High(FLastColWidths) do
    FLastColWidths[i] := -1; // 未設定（初回の自動調整は必ず行う）

  FNotifyRootID := 0;
  FNotifyParentID := 0;
  FNotifyRoot := '';
  FSelectNewItems := False;
  FNotifyTimer := TTimer.Create(Self);
  FNotifyTimer.Enabled := False;
  FNotifyTimer.Interval := 300;
  FNotifyTimer.OnTimer := @NotifyTimerTick;

  FDragArmed := False;
  FDropHilite := nil;
  FDragTimer := TTimer.Create(Self);
  FDragTimer.Enabled := False;
  FDragTimer.Interval := 80;
  FDragTimer.OnTimer := @DragTimerTick;

  // Root の変化は、変更元（内部の移動・ツリー連動・フォーム側からの設定）に関係なく
  // アイドル時にまとめて検出する。Root の書き込みは基底クラスで仮想化されていないため。
  Application.AddOnIdleHandler(@InternalAppIdle);
end;

destructor TCListView.Destroy;
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
  // 未実行の非同期呼び出し（DoAsyncSort 等）を取り消し、破棄後の実行を防ぐ
  Application.RemoveAsyncCalls(Self);
  Application.RemoveOnIdleHandler(@InternalAppIdle);
  inherited Destroy;
  FreeAndNil(FItemInfo);
  FreeAndNil(FPendingChanges);
  FreeAndNil(FHistory);
end;

// ---------------------------------------------------------------
// フォルダー変更監視
// ---------------------------------------------------------------

procedure TCListView.CreateWnd;
const
  CLVS_EX_DOUBLEBUFFER = $00010000;
begin
  inherited CreateWnd;
  // Windows リストビューのダブルバッファを有効にする（チラつき防止・描画の軽量化）
  SendMessage(Handle, LVM_SETEXTENDEDLISTVIEWSTYLE, CLVS_EX_DOUBLEBUFFER, CLVS_EX_DOUBLEBUFFER);
  // ハンドルが作り直されたら登録し直す（通知・ドロップの宛先がハンドルのため）
  RegisterFolderNotify;
  if not (csDesigning in ComponentState) then
    FOleTarget := OleDropRegister(Handle, @OleResolveDrop, @OleDropLeave, @OleDropped);
end;

procedure TCListView.DestroyWnd;
begin
  UnregisterFolderNotify;
  OleDropRevoke(Handle, FOleTarget);
  inherited DestroyWnd;
end;

procedure TCListView.RegisterFolderNotify;
const
  ListEvents = CSHCNE_CREATE or CSHCNE_DELETE or CSHCNE_MKDIR or CSHCNE_RMDIR or
               CSHCNE_RENAMEITEM or CSHCNE_RENAMEFOLDER or CSHCNE_UPDATEDIR or
               CSHCNE_UPDATEITEM or CSHCNE_ATTRIBUTES;
var
  ParentPath: string;
begin
  UnregisterFolderNotify;
  if csDesigning in ComponentState then Exit;
  if not HandleAllocated then Exit;
  if (Root = '') or not DirectoryExists(Root) then Exit;

  FNotifyRoot := Root;
  // Root 直下のみ（サブフォルダーは含めない）
  FNotifyRootID := ShellNotifyRegisterPath(Handle, Root, False, ListEvents);

  // Root 自体の削除・名前変更は、親フォルダー側の変更として通知される
  ParentPath := ExtractFileDir(ExcludeTrailingPathDelimiter(Root));
  if (ParentPath <> '') and
     not SameText(ExcludeTrailingPathDelimiter(ParentPath), ExcludeTrailingPathDelimiter(Root)) then
    FNotifyParentID := ShellNotifyRegisterPath(Handle, ParentPath, False,
      CSHCNE_RMDIR or CSHCNE_RENAMEFOLDER or CSHCNE_DELETE);
end;

procedure TCListView.UnregisterFolderNotify;
begin
  ShellNotifyDeregister(FNotifyRootID);
  ShellNotifyDeregister(FNotifyParentID);
  FNotifyRoot := '';
end;

const
  // ドラッグ開始の予約（リストビュー自身のマウス処理が終わってから開始するため）
  CM_CSTARTDRAG = WM_USER + $5A2;
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
    // 上位ワード = ボタン番号（1 = 戻る、2 = 進む）。LCL が下位ワードのキー状態にしている場合にも対応
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

procedure TCListView.WndProc(var Message: TLMessage);
var
  Dir: Integer;
begin
  // マウスの戻る／進むボタン（WM_XBUTTONUP、または Windows が変換した WM_APPCOMMAND）
  Dir := XButtonDirection(Message.Msg, Message.WParam, Message.LParam);
  if Dir <> 0 then
  begin
    ShellDragLog('XButton msg=' + IntToHex(Message.Msg, 4) + ' wParam=' + IntToHex(Message.WParam, 8) +
      ' dir=' + IntToStr(Dir) + ' histIndex=' + IntToStr(FHistIndex) + ' count=' + IntToStr(FHistory.Count));
    if Message.Msg = CWM_APPCOMMAND then
    begin
      // WM_XBUTTONUP の既定処理から送られてきたものは処理済み
      if not FInXButton then
        if Dir < 0 then GoBack else GoForward;
      Message.Result := 1;
      Exit;
    end;
    FInXButton := True;
    try
      inherited WndProc(Message);
    finally
      FInXButton := False;
    end;
    if Dir < 0 then GoBack else GoForward;
    Message.Result := 1;
    Exit;
  end;
  if Message.Msg = CM_CSTARTDRAG then
  begin
    StartOleDrag;
    Message.Result := 0;
    Exit;
  end;
  if (Message.Msg = WM_PAINT) and (FDropHilite <> nil) then
  begin
    inherited WndProc(Message);
    DrawDropFrame;
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

procedure TCListView.HandleShellNotify(AWParam: WPARAM; ALParam: LPARAM);
var
  Event: LongInt;
  P1, P2, R: string;

  // 表示中フォルダーそのもの、または直下の項目か
  function IsRelevant(const P: string): Boolean;
  var
    X: string;
  begin
    Result := False;
    if P = '' then Exit;
    X := ExcludeTrailingPathDelimiter(P);
    Result := SameText(X, R) or
              SameText(ExcludeTrailingPathDelimiter(ExtractFileDir(X)), R);
  end;

begin
  if not ShellNotifyDecode(AWParam, ALParam, Event, P1, P2) then Exit;
  if csDestroying in ComponentState then Exit;

  R := ExcludeTrailingPathDelimiter(Root);
  if R = '' then Exit;

  // 関係のないパスの通知は捨てる
  if not (IsRelevant(P1) or IsRelevant(P2)) then Exit;

  // 行単位で反映できる変更（削除・名前変更・内容更新）は記録し、それ以外は全件読み直しにする
  if (Event and (CSHCNE_DELETE or CSHCNE_RMDIR or CSHCNE_RENAMEITEM or CSHCNE_RENAMEFOLDER or
                 CSHCNE_UPDATEITEM or CSHCNE_ATTRIBUTES)) <> 0 then
  begin
    // 表示中フォルダー自体の変更は、全件読み直し（または親フォルダーへの移動）で扱う
    if SameText(ExcludeTrailingPathDelimiter(P1), R) then
      FNeedFullRefresh := True
    else
      FPendingChanges.AddObject(P1 + #1 + P2, TObject(PtrInt(Event)));
  end
  else
    FNeedFullRefresh := True;

  // 変更が多すぎる場合は、行単位で追わずに全件読み直す
  if FPendingChanges.Count > 100 then
    FNeedFullRefresh := True;

  // 最後の通知から一定時間待って1回だけ更新する（タイマーを掛け直す）
  FNotifyTimer.Enabled := False;
  FNotifyTimer.Enabled := True;
end;

function TCListView.FindItemByName(const AName: string): TListItem;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Items.Count - 1 do
    if SameText(Items[i].Caption, AName) then
      Exit(Items[i]);
end;

// ファイルサイズの表記（TShellListView と同じ形式）
function FormatShellSize(ASize: Int64): string;
const
  KB = Int64(1024);
  MB = Int64(1024) * 1024;
  GB = Int64(1024) * 1024 * 1024;
begin
  if ASize < KB then
    Result := Format('%s bytes', [IntToStr(ASize)])
  else if ASize < MB then
    Result := Format('%s kB', [IntToStr(ASize div KB)])
  else if ASize < GB then
    Result := Format('%s MB', [IntToStr(ASize div MB)])
  else
    Result := Format('%s GB', [Format('%.1n', [ASize / GB])]);
end;

procedure TCListView.ApplyPendingChanges;
var
  i, Sep: Integer;
  Ev: LongInt;
  P1, P2, R, Entry: string;
  Item: TListItem;
  NeedFull: Boolean;
  W32Data: WIN32_FIND_DATAW; // FindData は TCustomListView のメソッド名と重複するため使わない
  H: HANDLE;

  function InRoot(const P: string): Boolean;
  begin
    Result := (P <> '') and
      SameText(ExcludeTrailingPathDelimiter(ExtractFileDir(ExcludeTrailingPathDelimiter(P))), R);
  end;

begin
  R := ExcludeTrailingPathDelimiter(Root);
  NeedFull := False;
  W32Data := Default(WIN32_FIND_DATAW);

  Items.BeginUpdate;
  try
    for i := 0 to FPendingChanges.Count - 1 do
    begin
      Entry := FPendingChanges[i];
      Ev := LongInt(PtrInt(FPendingChanges.Objects[i]));
      Sep := Pos(#1, Entry);
      P1 := Copy(Entry, 1, Sep - 1);
      P2 := Copy(Entry, Sep + 1, MaxInt);

      if (Ev and (CSHCNE_DELETE or CSHCNE_RMDIR)) <> 0 then
      begin
        // 削除：その行を消す
        if InRoot(P1) then
        begin
          Item := FindItemByName(ExtractFileName(ExcludeTrailingPathDelimiter(P1)));
          if Item <> nil then
          begin
            if Item = FDropHilite then FDropHilite := nil;
            Item.Delete;
          end;
        end;
      end
      else if (Ev and (CSHCNE_RENAMEITEM or CSHCNE_RENAMEFOLDER)) <> 0 then
      begin
        if InRoot(P1) and InRoot(P2) then
        begin
          // 表示中フォルダー内での名前変更：その行の名前だけを変える
          Item := FindItemByName(ExtractFileName(ExcludeTrailingPathDelimiter(P1)));
          if Item = nil then
          begin
            // 名前の編集で既に新しい名前になっている場合は、何もしなくてよい
            if FindItemByName(ExtractFileName(ExcludeTrailingPathDelimiter(P2))) = nil then
              NeedFull := True;
          end
          else if FindItemByName(ExtractFileName(ExcludeTrailingPathDelimiter(P2))) <> nil then
            NeedFull := True // 同名の行が既にある（上書き等）
          else
            Item.Caption := ExtractFileName(ExcludeTrailingPathDelimiter(P2));
        end
        else if InRoot(P1) then
        begin
          // 他のフォルダーへ移動（ごみ箱への削除を含む）：その行を消す
          Item := FindItemByName(ExtractFileName(ExcludeTrailingPathDelimiter(P1)));
          if Item <> nil then
          begin
            if Item = FDropHilite then FDropHilite := nil;
            Item.Delete;
          end;
        end
        else
          // 他のフォルダーから移動してきた（追加）：アイコン等の作成が必要なため全件読み直す
          NeedFull := True;
      end
      else if (Ev and (CSHCNE_UPDATEITEM or CSHCNE_ATTRIBUTES)) <> 0 then
      begin
        // 内容の更新：その行のサイズを更新する（更新日時は後でまとめて反映）
        if InRoot(P1) then
        begin
          Item := FindItemByName(ExtractFileName(ExcludeTrailingPathDelimiter(P1)));
          if Item = nil then
            NeedFull := True // まだ一覧にない（作成直後など）
          else
          begin
            H := FindFirstFileW(PWideChar(ShellLongPathW(ExcludeTrailingPathDelimiter(P1))), W32Data);
            if H <> INVALID_HANDLE_VALUE then
            begin
              Windows.FindClose(H);
              if ((W32Data.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) = 0) and
                 (Item.SubItems.Count > 0) then
                Item.SubItems[0] := FormatShellSize(
                  (Int64(W32Data.nFileSizeHigh) shl 32) or W32Data.nFileSizeLow);
            end;
          end;
        end;
      end
      else
        NeedFull := True;

      if NeedFull then Break;
    end;
  finally
    Items.EndUpdate;
  end;

  FPendingChanges.Clear;

  if NeedFull then
  begin
    DoAsyncRefresh(0);
    Exit;
  end;

  // 更新日時・種類を反映し、並べ替え直す（いずれもディスクへの問い合わせは列挙1回のみ）
  PopulateFileDateTimes;
  ApplySort;
  FSelectionDirty := True;
end;

// シェル経由の名前変更（名前の編集終了処理と競合しないよう非同期で行う）
type
  TListRenameJob = class
  public
    OldPath: string;
    NewName: string;
  end;

procedure TCListView.DoAsyncRename(Data: PtrInt);
var
  Job: TListRenameJob;
begin
  Job := TListRenameJob(Data);
  try
    if csDestroying in ComponentState then Exit;
    // 成功時の表示更新はフォルダー変更監視に任せる。
    // 失敗時はシェルが理由を表示するので、表示を元に戻すため読み直す
    if not ShellRenameItem(Handle, Job.OldPath, Job.NewName) then
      DoAsyncRefresh(0);
  finally
    Job.Free;
  end;
end;

procedure TCListView.NotifyTimerTick({%H-}Sender: TObject);
begin
  // 名前の編集中・ドラッグ中は保留（タイマーは止めず、次の周期で再判定する）
  // （ドロップ先として強調表示中の項目が作り直されないよう、他のコントロールからのドラッグ中も保留）
  if IsEditing or Dragging or ShellDragIsActive or FOleDragOver then Exit;

  FNotifyTimer.Enabled := False;
  if csDestroying in ComponentState then Exit;

  if (Root <> '') and not DirectoryExists(Root) then
  begin
    FPendingChanges.Clear;
    FNeedFullRefresh := False;
    NavigateToExistingParent;
  end
  else if FNeedFullRefresh then
  begin
    FPendingChanges.Clear;
    FNeedFullRefresh := False;
    DoAsyncRefresh(0);
  end
  else if FPendingChanges.Count > 0 then
    // 削除・名前変更・内容更新だけなら、その行だけを更新する（全件は読み直さない）
    ApplyPendingChanges;
end;

procedure TCListView.NavigateToExistingParent;
var
  P, ParentPath: string;
begin
  P := ExcludeTrailingPathDelimiter(Root);
  while P <> '' do
  begin
    ParentPath := ExcludeTrailingPathDelimiter(ExtractFileDir(P));
    if (ParentPath = '') or SameText(ParentPath, P) then
    begin
      // これ以上遡れない（ドライブごと消えた等）
      P := '';
      Break;
    end;
    P := ParentPath;
    if DirectoryExists(P) then Break;
  end;

  if P <> '' then
    NavigateTo(IncludeTrailingPathDelimiter(P));
end;

procedure TCListView.SelectNewItemsOnNextRefresh;
begin
  FSelectNewItems := True;
end;

procedure TCListView.NotifyFolderChanged;
begin
  if Assigned(FOnFolderChanged) then
    FOnFolderChanged(Self);
end;

procedure TCListView.CheckStateChanged;
begin
  if [csDesigning, csDestroying] * ComponentState <> [] then Exit;

  // 1. フォルダー変更（末尾の区切り文字の有無は同一とみなす）
  if not SameText(ExcludeTrailingPathDelimiter(Root), ExcludeTrailingPathDelimiter(FLastRoot)) then
  begin
    FLastRoot := Root;
    RecordHistory(Root);
    FSelectionDirty := True; // フォルダーが変われば選択も変わる
    // 監視対象を新しいフォルダーに付け替える
    FNotifyTimer.Enabled := False;
    RegisterFolderNotify;
    NotifyFolderChanged;
  end;

  // 2. 表示形式の変更（アイコンの大きさが変わるため、表示を作り直す）
  if ViewStyle <> FLastViewStyle then
  begin
    FLastViewStyle := ViewStyle;
    Application.QueueAsyncCall(@DoAsyncRefresh, 0);
    if (ViewStyle = vsReport) and not FColumnResizePending then
    begin
      FColumnResizePending := True;
      Application.QueueAsyncCall(@DoAsyncColumnResize, 0);
    end;
  end;

  // 3. 選択変更
  if FSelectionDirty then
  begin
    FSelectionDirty := False;
    if Assigned(FOnSelectionChanged) then
      FOnSelectionChanged(Self);
  end;
end;

procedure TCListView.InternalAppIdle({%H-}Sender: TObject; var {%H-}Done: Boolean);
begin
  CheckStateChanged;
  // Done は変更しない（他の OnIdle ハンドラに干渉しないため）
end;

procedure TCListView.DoSelectItem(AItem: TListItem; ASelected: Boolean);
begin
  inherited DoSelectItem(AItem, ASelected);
  // 複数選択時は項目ごとに呼ばれるため、ここではフラグだけ立てる
  FSelectionDirty := True;
end;

function TCListView.NavigateTo(const APath: string): Boolean;
begin
  Result := False;
  if (APath = '') or not DirectoryExists(APath) then Exit;
  if SameText(ExcludeTrailingPathDelimiter(APath), ExcludeTrailingPathDelimiter(Root)) then Exit;

  Root := APath;
  Result := True;
  // イベントは CheckStateChanged（アイドル時）で発行する
end;

function TCListView.NavigateUp: Boolean;
var
  Current, ParentPath: string;
begin
  Result := False;
  if Root = '' then Exit;

  Current := ExcludeTrailingPathDelimiter(Root);
  ParentPath := ExtractFileDir(Current);
  // ドライブのルート（C:\ 等）では親がないので何もしない
  if (ParentPath = '') or SameText(ExcludeTrailingPathDelimiter(ParentPath), Current) then Exit;

  Result := NavigateTo(ParentPath);
end;

// ---------------------------------------------------------------
// 戻る・進む
// ---------------------------------------------------------------

procedure TCListView.RecordHistory(const APath: string);
var
  P: string;
begin
  P := ExcludeTrailingPathDelimiter(APath);
  if P = '' then Exit;
  // 戻る・進むによる移動は、位置を移動済みなので追加しない
  if (FHistSkip <> '') and SameText(P, FHistSkip) then
  begin
    FHistSkip := '';
    Exit;
  end;
  FHistSkip := '';
  if (FHistIndex >= 0) and SameText(FHistory[FHistIndex], P) then Exit;
  // 現在位置より後ろ（進む側）は捨てる
  while FHistory.Count > FHistIndex + 1 do
    FHistory.Delete(FHistory.Count - 1);
  FHistory.Add(P);
  while FHistory.Count > FMaxHistory do
    FHistory.Delete(0);
  FHistIndex := FHistory.Count - 1;
end;

function TCListView.HistoryGo(ADelta: Integer): Boolean;
var
  i: Integer;
  P, Cur: string;
begin
  Result := False;
  Cur := ExcludeTrailingPathDelimiter(Root);
  i := FHistIndex + ADelta;
  while (i >= 0) and (i < FHistory.Count) do
  begin
    P := FHistory[i];
    if DirectoryExists(P) and not SameText(P, Cur) then
    begin
      FHistIndex := i;
      FHistSkip := P;
      Root := IncludeTrailingPathDelimiter(P);
      Exit(True);
    end;
    // 存在しない（または現在と同じ）フォルダーは履歴から除いて次を探す
    FHistory.Delete(i);
    if ADelta < 0 then
    begin
      Dec(FHistIndex);
      Dec(i);
    end;
  end;
end;

function TCListView.GoBack: Boolean;
begin
  Result := HistoryGo(-1);
end;

function TCListView.GoForward: Boolean;
begin
  Result := HistoryGo(+1);
end;

function TCListView.CanGoBack: Boolean;
begin
  Result := FHistIndex > 0;
end;

function TCListView.CanGoForward: Boolean;
begin
  Result := (FHistIndex >= 0) and (FHistIndex < FHistory.Count - 1);
end;

procedure TCListView.ClearHistory;
begin
  FHistory.Clear;
  FHistIndex := -1;
  FHistSkip := '';
  RecordHistory(Root);
end;

procedure TCListView.SetMaxHistory(AValue: Integer);
begin
  if AValue < 2 then AValue := 2;
  FMaxHistory := AValue;
  while FHistory.Count > FMaxHistory do
  begin
    FHistory.Delete(0);
    if FHistIndex > 0 then Dec(FHistIndex);
  end;
end;

// ---------------------------------------------------------------
// 右クリックメニューへの独自項目
// ---------------------------------------------------------------

procedure TCListView.SetExtraItemMenu(AValue: TPopupMenu);
begin
  if FExtraItemMenu = AValue then Exit;
  if FExtraItemMenu <> nil then FExtraItemMenu.RemoveFreeNotification(Self);
  FExtraItemMenu := AValue;
  if FExtraItemMenu <> nil then FExtraItemMenu.FreeNotification(Self);
end;

procedure TCListView.SetExtraBackgroundMenu(AValue: TPopupMenu);
begin
  if FExtraBackgroundMenu = AValue then Exit;
  if FExtraBackgroundMenu <> nil then FExtraBackgroundMenu.RemoveFreeNotification(Self);
  FExtraBackgroundMenu := AValue;
  if FExtraBackgroundMenu <> nil then FExtraBackgroundMenu.FreeNotification(Self);
end;

procedure TCListView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FExtraItemMenu then FExtraItemMenu := nil;
    if AComponent = FExtraBackgroundMenu then FExtraBackgroundMenu := nil;
  end;
end;

procedure TCListView.GetSelectedPaths(AList: TStrings);
var
  i: Integer;
  Path: string;
begin
  if AList = nil then Exit;
  AList.Clear;
  for i := 0 to Items.Count - 1 do
  begin
    if Items[i].Selected then
    begin
      Path := GetPathFromItem(Items[i]);
      if Path <> '' then
        AList.Add(Path);
    end;
  end;
end;

// 安全なリサイズ処理（Name列のみ伸縮）
// 列幅の再計算はここで同期的に行わず、QueueAsyncCallで後回しにする。
// （同期的に行うと、Win32ヘッダーコントロールの内部処理と競合し、
//   TSplitterによるライブドラッグ中の外枠リサイズを妨げてしまうため）
procedure TCListView.Resize;
begin
  inherited Resize;

  if (csDesigning in ComponentState) or (Columns.Count < 4) then Exit;
  // 列幅の自動調整は詳細表示のときだけ
  if ViewStyle <> vsReport then Exit;

  // 予約済みなら重ねて予約しない（スクロールバーの出入りで Resize が連発しても1回にまとめる）
  if FColumnResizePending then Exit;
  FColumnResizePending := True;
  Application.QueueAsyncCall(@DoAsyncColumnResize, 0);
end;

procedure TCListView.DoAsyncColumnResize({%H-}Data: PtrInt);
const
  // 列幅の合計を表示幅ちょうどにすると横スクロールバーが出て表示高さが変わり、
  // 再び Resize → 再計算 と循環するため、わずかに余白を残す
  ColumnMargin = 4;
  MinNameWidth = 60;
var
  NewNameWidth, i: Integer;
begin
  FColumnResizePending := False;
  if FInResize or (Columns.Count < 4) then Exit;
  if csDestroying in ComponentState then Exit;
  if ViewStyle <> vsReport then Exit;
  // ユーザーが列幅を手動で変えた後は自動調整しない（エクスプローラーと同じ）
  if FUserSizedColumns then Exit;

  // 前回自動調整した列幅から変わっていれば、ユーザーが手動で変えたとみなす。
  // （列の境界をドラッグ中に横スクロールバーが出入りして Resize が走っても、ここで止まる）
  if FLastColWidths[0] >= 0 then
  begin
    for i := 0 to 3 do
    begin
      if Columns[i].Width <> FLastColWidths[i] then
      begin
        FUserSizedColumns := True;
        Exit;
      end;
    end;
  end;

  FInResize := True;
  try
    // Windows エクスプローラーのファイル名列と同様、
    // 残りスペースをそのまま「名前」列に割り当てる
    NewNameWidth := ClientWidth - (Columns[1].Width + Columns[2].Width + Columns[3].Width) - ColumnMargin;
    if NewNameWidth < MinNameWidth then
      NewNameWidth := MinNameWidth;

    // 値が変わらないときは設定しない（設定自体が再描画・スクロールバー再計算を誘発するため）
    if Columns[0].Width <> NewNameWidth then
      Columns[0].Width := NewNameWidth;

    // 実際に反映された列幅を記録する（次回の手動変更検出用）
    for i := 0 to 3 do
      FLastColWidths[i] := Columns[i].Width;
  finally
    FInResize := False;
  end;
end;

function TCListView.GetAutoFitNameColumn: Boolean;
begin
  Result := not FUserSizedColumns;
end;

procedure TCListView.SetAutoFitNameColumn(AValue: Boolean);
var
  i: Integer;
begin
  FUserSizedColumns := not AValue;
  if AValue then
  begin
    // 記録をリセットして、次の調整を必ず行う
    for i := Low(FLastColWidths) to High(FLastColWidths) do
      FLastColWidths[i] := -1;
    if HandleAllocated and not FColumnResizePending then
    begin
      FColumnResizePending := True;
      Application.QueueAsyncCall(@DoAsyncColumnResize, 0);
    end;
  end;
end;

// Windows API を直接使い、フォルダー・ファイル問わず更新日時（YYYY/MM/DD HH:NN）を一括設定
procedure TCListView.RebuildItemInfo;
var
  W32Data: WIN32_FIND_DATAW; // FindData は TCustomListView のメソッド名と重複するため使わない
  H: HANDLE;
  ItemName: string; // Name は TComponent.Name と重複するため使わない
  Info: TCItemInfo;
  LocalFileTime: TFileTime;
  SystemTime: TSystemTime;
begin
  W32Data := Default(WIN32_FIND_DATAW);
  LocalFileTime := Default(TFileTime);
  SystemTime := Default(TSystemTime);
  FItemInfo.Clear;
  FItemInfoRoot := Root;
  if Root = '' then Exit;

  // 表示中フォルダーを1回だけ列挙する（項目ごとのディスク問い合わせをなくす）
  FItemInfo.Sorted := False;
  H := FindFirstFileW(PWideChar(ShellLongPathW(IncludeTrailingPathDelimiter(Root) + '*')), W32Data);
  if H <> INVALID_HANDLE_VALUE then
  begin
    try
      repeat
        ItemName := String(UnicodeString(PWideChar(@W32Data.cFileName[0])));
        if (ItemName = '.') or (ItemName = '..') then Continue;
        Info := TCItemInfo.Create;
        Info.IsDir := (W32Data.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) <> 0;
        if FileTimeToLocalFileTime(W32Data.ftLastWriteTime, LocalFileTime) and
           FileTimeToSystemTime(LocalFileTime, SystemTime) then
          Info.DateStr := Format('%.4d/%.2d/%.2d %.2d:%.2d',
            [SystemTime.wYear, SystemTime.wMonth, SystemTime.wDay,
             SystemTime.wHour, SystemTime.wMinute])
        else
          Info.DateStr := '';
        FItemInfo.AddObject(ItemName, Info);
      until not FindNextFileW(H, W32Data);
    finally
      Windows.FindClose(H);
    end;
  end;
  // まとめて並べ替えてから、二分探索できる状態にする
  FItemInfo.Sorted := True;
end;

function TCListView.FindItemInfo(const AName: string): TObject;
var
  Idx: Integer;
begin
  Result := nil;
  if not SameText(ExcludeTrailingPathDelimiter(FItemInfoRoot), ExcludeTrailingPathDelimiter(Root)) then
    RebuildItemInfo;
  Idx := FItemInfo.IndexOf(AName);
  if Idx >= 0 then
    Result := FItemInfo.Objects[Idx];
end;

// 全項目の「種類」（フォルダー）と「更新日時」を設定する。
// フォルダーの列挙は RebuildItemInfo の1回だけで、項目ごとにディスクへ問い合わせない。
procedure TCListView.PopulateFileDateTimes;
var
  i: Integer;
  Info: TCItemInfo;
  Item: TListItem;
begin
  RebuildItemInfo;
  Items.BeginUpdate;
  try
    for i := 0 to Items.Count - 1 do
    begin
      Item := Items[i];
      Info := TCItemInfo(FindItemInfo(Item.Caption));

      // SubItems の要素数を調整（SubItems[0]:Size, SubItems[1]:Type, SubItems[2]:更新日時）
      while Item.SubItems.Count < 3 do
        Item.SubItems.Add('');

      if Info = nil then Continue;

      // フォルダーかつ種類が空欄（または既定の表記）なら "フォルダ" にする
      if Info.IsDir and ((Item.SubItems[1] = '') or (Item.SubItems[1] = 'ファイル フォルダー')) then
        Item.SubItems[1] := 'フォルダ';

      if Item.SubItems[2] <> Info.DateStr then
        Item.SubItems[2] := Info.DateStr;
    end;
  finally
    Items.EndUpdate;
  end;
end;

// 新規フォルダー作成の実装
function TCListView.CreateNewFolderInRoot: string;
var
  NewPath: string;
  Counter: Integer;
begin
  Result := '';
  if Root = '' then Exit;

  NewPath := IncludeTrailingPathDelimiter(Root) + '新しいフォルダー';
  if DirectoryExists(NewPath) then
  begin
    Counter := 2;
    repeat
      NewPath := IncludeTrailingPathDelimiter(Root) + Format('新しいフォルダー (%d)', [Counter]);
      Inc(Counter);
    until not DirectoryExists(NewPath);
  end;

  if CreateDir(NewPath) then
    Result := NewPath;
end;

// 新規ファイル作成の実装
function TCListView.CreateNewFileInRoot(const AExtension: string): string;
var
  NewPath: string;
  Counter: Integer;
  F: TextFile;
begin
  Result := '';
  if Root = '' then Exit;

  NewPath := IncludeTrailingPathDelimiter(Root) + '新規テキスト ドキュメント' + AExtension;
  if FileExists(NewPath) then
  begin
    Counter := 2;
    repeat
      NewPath := IncludeTrailingPathDelimiter(Root) + Format('新規テキスト ドキュメント (%d)%s', [Counter, AExtension]);
      Inc(Counter);
    until not FileExists(NewPath);
  end;

  try
    AssignFile(F, NewPath);
    Rewrite(F);
    CloseFile(F);
    Result := NewPath;
  except
    Result := '';
  end;
end;

// 指定パスのアイテムをフォーカスして名前変更状態（リネーム）にする
procedure TCListView.FocusAndRenamePath(const APath: string);
var
  i: Integer;
  TargetItem: TListItem;
begin
  if APath = '' then Exit;

  DoAsyncRefresh(0);

  TargetItem := nil;
  for i := 0 to Items.Count - 1 do
  begin
    if SameText(GetPathFromItem(Items[i]), APath) then
    begin
      TargetItem := Items[i];
      Break;
    end;
  end;

  if TargetItem <> nil then
  begin
    Selected := TargetItem;
    ItemFocused := TargetItem;
    TargetItem.MakeVisible(False);
    ReadOnly := False;
    TargetItem.EditCaption;
  end;
end;

// エクスプローラー基準のソート
function TCListView.CompareItems(Item1, Item2: TListItem): Integer;
var
  Info1, Info2: TCItemInfo;
  IsDir1, IsDir2: Boolean;
  Str1, Str2: string;
begin
  Result := 0;
  if (Item1 = nil) or (Item2 = nil) then Exit;

  // フォルダー判定はキャッシュから行う（ディスクへ問い合わせない）
  Info1 := TCItemInfo(FindItemInfo(Item1.Caption));
  Info2 := TCItemInfo(FindItemInfo(Item2.Caption));
  if Info1 <> nil then IsDir1 := Info1.IsDir else IsDir1 := DirectoryExists(GetPathFromItem(Item1));
  if Info2 <> nil then IsDir2 := Info2.IsDir else IsDir2 := DirectoryExists(GetPathFromItem(Item2));

  if IsDir1 and not IsDir2 then
    Exit(-1);
  if not IsDir1 and IsDir2 then
    Exit(1);

  if FSortColumn = 0 then
  begin
    Result := StrCmpLogicalW(PWideChar(UnicodeString(Item1.Caption)), PWideChar(UnicodeString(Item2.Caption)));
  end
  else
  begin
    if Item1.SubItems.Count >= FSortColumn then
      Str1 := Item1.SubItems[FSortColumn - 1]
    else
      Str1 := '';

    if Item2.SubItems.Count >= FSortColumn then
      Str2 := Item2.SubItems[FSortColumn - 1]
    else
      Str2 := '';

    Result := StrCmpLogicalW(PWideChar(UnicodeString(Str1)), PWideChar(UnicodeString(Str2)));

    if Result = 0 then
      Result := StrCmpLogicalW(PWideChar(UnicodeString(Item1.Caption)), PWideChar(UnicodeString(Item2.Caption)));
  end;

  if not FSortAscending then
    Result := -Result;
end;

function SortCompareProc(Item1, Item2: TListItem; OptionalParam: PtrInt): Integer; stdcall;
var
  LView: TCListView;
begin
  LView := TCListView(OptionalParam);
  Result := LView.CompareItems(Item1, Item2);
end;

procedure TCListView.ApplySort;
begin
  CustomSort(@SortCompareProc, PtrInt(Self));
end;

procedure TCListView.DoAddItemHandler({%H-}Sender: TObject; const {%H-}APath: string; const {%H-}AItem: TRawByteSearchRec; var CanAdd: Boolean);
begin
  CanAdd := True;
  // 項目ごとに予約すると件数分だけ並べ替えが走るため、1回にまとめる
  if FSortPending then Exit;
  FSortPending := True;
  Application.QueueAsyncCall(@DoAsyncSort, 0);
end;

procedure TCListView.DoAsyncSort({%H-}Data: PtrInt);
begin
  FSortPending := False;
  if csDestroying in ComponentState then Exit;
  PopulateFileDateTimes;
  ApplySort;
end;

procedure TCListView.DoColumnClick({%H-}Sender: TObject; AColumn: TListColumn);
begin
  if FSortColumn = AColumn.Index then
    FSortAscending := not FSortAscending
  else
  begin
    FSortColumn := AColumn.Index;
    FSortAscending := True;
  end;

  ApplySort;
end;

function TCListView.GetPIDLFromPath(const APath: string): PItemIDList;
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

function TCListView.PerformFileOperation(AOp: UINT; const ASource, ADest: string;
  AAllowUndo: Boolean): Boolean;
var
  ShOp: SHFILEOPSTRUCTW;
  SourceBuf, DestBuf: WideString;
begin
  ShOp := Default(SHFILEOPSTRUCTW);

  SourceBuf := WideString(ASource + #0#0);
  DestBuf := WideString(ADest + #0#0);

  ShOp.Wnd := Handle;
  ShOp.wFunc := AOp;
  ShOp.pFrom := PWideChar(SourceBuf);
  if ADest <> '' then
    ShOp.pTo := PWideChar(DestBuf);

  // AAllowUndo = False（完全削除）でも、確認ダイアログは表示される
  if AAllowUndo then
    ShOp.fFlags := FOF_ALLOWUNDO or FOF_RENAMEONCOLLISION
  else
    ShOp.fFlags := FOF_RENAMEONCOLLISION;

  Result := (SHFileOperationW(@ShOp) = 0) and (not ShOp.fAnyOperationsAborted);
end;

function TCListView.GetSelectedFilePath: string;
var
  SelItem: TListItem;
begin
  Result := '';
  SelItem := Selected;
  if SelItem <> nil then
  begin
    Result := GetPathFromItem(SelItem);
  end;
end;

procedure TCListView.DblClick;
var
  Pt: TPoint;
  TargetItem: TListItem;
  Path: string;
  Res: PtrInt;
begin
  // プログラム側で OnDblClick が設定されている場合は、そちらを優先する
  // （既定のファイル起動／フォルダー移動処理は行わない）
  if Assigned(OnDblClick) then
  begin
    inherited DblClick;
    Exit;
  end;

  TargetItem := ItemFocused;

  if TargetItem = nil then
  begin
    Pt := ScreenToClient(Mouse.CursorPos);
    TargetItem := GetItemAt(Pt.X, Pt.Y);
  end;

  if TargetItem <> nil then
  begin
    Path := GetPathFromItem(TargetItem);
    if Path <> '' then
    begin
      if DirectoryExists(Path) then
      begin
        NavigateTo(Path);
      end
      else if FileExists(Path) then
      begin
        Res := PtrInt(ShellExecuteW(0, 'open', PWideChar(UnicodeString(Path)), nil, nil, SW_SHOWNORMAL));
        if Res <= 32 then
        begin
          ShowMessage('ファイルを開けませんでした。エラーコード: ' + IntToStr(Res));
        end;
      end;
    end;
  end;

  inherited DblClick;
end;

procedure TCListView.RenameSelectedFile;
begin
  if Selected <> nil then
  begin
    ReadOnly := False;
    try
      Selected.EditCaption;
    finally
    end;
  end;
end;

procedure TCListView.InternalOnEdited({%H-}Sender: TObject; Item: TListItem; var S: string);
var
  OldPath, NewPath: string;
  Job: TListRenameJob;
begin
  ReadOnly := True;

  if (Item = nil) or (S = '') then Exit;

  if ContainsInvalidChar(S) then
  begin
    ShowMessage('ファイル名に以下の文字は使用できません:' + sLineBreak + '\ / : * ? " < > |');
    S := Item.Caption;
    Exit;
  end;

  // 変更前のパスは表示名ではなく、項目が持つ実際のパスから取得する。
  // 変更後のパスも実ファイル名を元に組み立てる（Item.Caption はこの時点ではまだ変更前の表示名）。
  OldPath := GetPathFromItem(Item);
  if OldPath = '' then Exit;

  NewPath := BuildRenamedPath(OldPath, Item.Caption, S);

  if NewPath <> ExcludeTrailingPathDelimiter(OldPath) then
  begin
    // シェル経由で名前を変更する（使用中などで失敗した場合は、シェルが理由を表示する）。
    // 名前の編集終了処理と競合しないよう、非同期で行う
    Job := TListRenameJob.Create;
    Job.OldPath := ExcludeTrailingPathDelimiter(OldPath);
    Job.NewName := ExtractFileName(NewPath);
    Application.QueueAsyncCall(@DoAsyncRename, PtrInt(Job));
  end;
end;

const
  // 「表示」「並べ替え」メニューのコマンド数（表示 4 ＋ 並べ替えの列 4 ＋ 昇順・降順 2）
  CViewSortMenuCount = 10;

procedure TCListView.AddViewSortMenus(AMenu: HMENU; ABaseID: UINT);
const
  ViewCaptions: array[0..3] of string = ('大アイコン(&R)', '小アイコン(&N)', '一覧(&L)', '詳細(&D)');
  ViewStyles: array[0..3] of TViewStyle = (vsIcon, vsSmallIcon, vsList, vsReport);
  SortCaptions: array[0..3] of string = ('名前(&N)', 'サイズ(&S)', '種類(&T)', '更新日時(&D)');
var
  SubView, SubSort: HMENU;
  i: Integer;
  Flags: UINT;
begin
  SubView := CreatePopupMenu;
  for i := 0 to 3 do
  begin
    Flags := MF_STRING;
    if ViewStyle = ViewStyles[i] then Flags := Flags or MF_CHECKED;
    AppendMenuW(SubView, Flags, ABaseID + UINT(i), PWideChar(UTF8ToUTF16(ViewCaptions[i])));
  end;

  SubSort := CreatePopupMenu;
  for i := 0 to 3 do
  begin
    Flags := MF_STRING;
    if FSortColumn = i then Flags := Flags or MF_CHECKED;
    AppendMenuW(SubSort, Flags, ABaseID + 4 + UINT(i), PWideChar(UTF8ToUTF16(SortCaptions[i])));
  end;
  AppendMenuW(SubSort, MF_SEPARATOR, 0, nil);
  Flags := MF_STRING;
  if FSortAscending then Flags := Flags or MF_CHECKED;
  AppendMenuW(SubSort, Flags, ABaseID + 8, PWideChar(UTF8ToUTF16('昇順(&A)')));
  Flags := MF_STRING;
  if not FSortAscending then Flags := Flags or MF_CHECKED;
  AppendMenuW(SubSort, Flags, ABaseID + 9, PWideChar(UTF8ToUTF16('降順(&E)')));

  // 先頭に挿入：表示、並べ替え、区切り線
  InsertMenuW(AMenu, 0, MF_BYPOSITION or MF_POPUP, PtrUInt(SubView), PWideChar(UTF8ToUTF16('表示(&V)')));
  InsertMenuW(AMenu, 1, MF_BYPOSITION or MF_POPUP, PtrUInt(SubSort), PWideChar(UTF8ToUTF16('並べ替え(&O)')));
  InsertMenuW(AMenu, 2, MF_BYPOSITION or MF_SEPARATOR, 0, nil);
end;

procedure TCListView.SetView(AStyle: TViewStyle);
begin
  if ViewStyle = AStyle then Exit;
  ViewStyle := AStyle;
  // 表示の作り直しは CheckStateChanged（アイドル時）で行う
end;

procedure TCListView.SortBy(AColumn: Integer; AAscending: Boolean);
begin
  if (AColumn < 0) or (AColumn > 3) then Exit;
  FSortColumn := AColumn;
  FSortAscending := AAscending;
  ApplySort;
end;

procedure TCListView.DisplayShellContextMenu(const APath: string; const APoint: TPoint; IsFolderContext: Boolean);
var
  FolderPIDL, FullPIDL, ChildPIDL: PItemIDList;
  DesktopFolder, ParentFolder: IShellFolder;
  ContextMenu: IContextMenu;
  HMenuPopup: HMENU;
  MenuCmd: UINT;
  ScreenPt: TPoint;
  TargetDir, CreatedPath, Verb: string;
  HRes: HRESULT;
  CmdNewFolder, CmdNewFile, CmdPaste: UINT;
  CanPaste: Boolean;
  ExtraItems: TList;
begin
  if APath = '' then Exit;
  ExtraItems := TList.Create;
  try

  if IsFolderContext then
    TargetDir := APath
  else
    TargetDir := ExtractFilePath(ExcludeTrailingPathDelimiter(APath));

  FolderPIDL := GetPIDLFromPath(TargetDir);
  if FolderPIDL = nil then Exit;

  try
    if Succeeded(SHGetDesktopFolder(DesktopFolder)) then
    begin
      if Succeeded(DesktopFolder.BindToObject(FolderPIDL, nil, IID_IShellFolder, Pointer(ParentFolder))) then
      begin
        ContextMenu := nil;

        if IsFolderContext then
        begin
          ParentFolder.CreateViewObject(Handle, IID_IContextMenu, Pointer(ContextMenu));
        end
        else
        begin
          FullPIDL := GetPIDLFromPath(APath);
          if FullPIDL <> nil then
          begin
            ChildPIDL := ILFindLastID(FullPIDL);
            ParentFolder.GetUIObjectOf(0, 1, ChildPIDL, IID_IContextMenu, nil, Pointer(ContextMenu));
            CoTaskMemFree(FullPIDL);
          end;
        end;

        if ContextMenu <> nil then
        begin
          HMenuPopup := CreatePopupMenu;
          if HMenuPopup <> 0 then
          begin
            try
              HRes := ContextMenu.QueryContextMenu(HMenuPopup, 0, 1, $7FFF, CMF_NORMAL);
              if Succeeded(HRes) then
              begin
                CmdNewFolder := (HRes and $FFFF) + 1;
                CmdNewFile   := CmdNewFolder + 1;
                CmdPaste     := CmdNewFile + 1;

                if IsFolderContext then
                begin
                  CanPaste := IsClipboardFormatAvailable(CF_HDROP);

                  InsertMenuW(HMenuPopup, 0, MF_BYPOSITION or MF_STRING, CmdNewFolder, PWideChar(UTF8ToUTF16('新規フォルダー(&N)')));
                  InsertMenuW(HMenuPopup, 1, MF_BYPOSITION or MF_STRING, CmdNewFile, PWideChar(UTF8ToUTF16('新規テキスト ドキュメント(&T)')));

                  if CanPaste then
                    InsertMenuW(HMenuPopup, 2, MF_BYPOSITION or MF_STRING, CmdPaste, PWideChar(UTF8ToUTF16('貼り付け(&P)')))
                  else
                    InsertMenuW(HMenuPopup, 2, MF_BYPOSITION or MF_STRING or MF_GRAYED, CmdPaste, PWideChar(UTF8ToUTF16('貼り付け(&P)')));

                  InsertMenuW(HMenuPopup, 3, MF_BYPOSITION or MF_SEPARATOR, 0, nil);
                  // 先頭に「表示」「並べ替え」（エクスプローラーと同じ位置）
                  AddViewSortMenus(HMenuPopup, CmdPaste + 1);
                end;

                // アプリの独自メニュー（項目の上／空白部分）を追加する
                if IsFolderContext then
                  ExtraMenuInsert(HMenuPopup, FExtraBackgroundMenu, FExtraMenuPosition, Self, ExtraItems)
                else
                  ExtraMenuInsert(HMenuPopup, FExtraItemMenu, FExtraMenuPosition, Self, ExtraItems);

                ScreenPt := ClientToScreen(APoint);
                // 「送る」などのサブメニューが正しく表示されるよう、共通部品で表示する
                MenuCmd := TrackShellContextMenu(Handle, HMenuPopup, ContextMenu, ScreenPt.X, ScreenPt.Y);

                if MenuCmd = 0 then
                  // 何も選ばれなかった
                else if ExtraMenuClick(ExtraItems, MenuCmd) then
                  // 独自メニューの項目：その項目の OnClick を呼んだ
                else if MenuCmd = CmdNewFolder then
                begin
                  CreatedPath := CreateNewFolderInRoot;
                  if CreatedPath <> '' then
                    FocusAndRenamePath(CreatedPath);
                end
                else if MenuCmd = CmdNewFile then
                begin
                  CreatedPath := CreateNewFileInRoot('.txt');
                  if CreatedPath <> '' then
                    FocusAndRenamePath(CreatedPath);
                end
                else if MenuCmd = CmdPaste then
                begin
                  PasteToRoot;
                end
                else if IsFolderContext and (MenuCmd >= CmdPaste + 1) and (MenuCmd <= CmdPaste + CViewSortMenuCount) then
                begin
                  // 「表示」「並べ替え」
                  case MenuCmd - CmdPaste of
                    1: SetView(vsIcon);
                    2: SetView(vsSmallIcon);
                    3: SetView(vsList);
                    4: SetView(vsReport);
                    5..8: SortBy(Integer(MenuCmd - CmdPaste) - 5, FSortAscending);
                    9: SortBy(FSortColumn, True);
                    10: SortBy(FSortColumn, False);
                  end;
                end
                else
                begin
                  Verb := ShellMenuVerb(ContextMenu, MenuCmd - 1);
                  if SameText(Verb, 'rename') then
                    // シェルの「名前の変更」はこの画面では動かないため、自前の名前変更に切り替える
                    RenameSelectedFile
                  else
                  begin
                    if SameText(Verb, 'paste') then
                      SelectNewItemsOnNextRefresh;
                    // エクスプローラーと同じく、作業フォルダー（表示中のフォルダー）を渡して実行する
                    ShellInvokeMenuCommand(ContextMenu, Handle, MenuCmd - 1, TargetDir);
                    // 表示の更新はフォルダー変更監視に任せる
                  end;
                end;
              end;
            finally
              DestroyMenu(HMenuPopup);
            end;
          end;
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

procedure TCListView.DoContextPopup(MousePos: TPoint; var Handled: Boolean);
var
  Item: TListItem;
  Path: string;
begin
  Item := GetItemAt(MousePos.X, MousePos.Y);
  if Item <> nil then
  begin
    Selected := Item;
    Path := GetPathFromItem(Item);
    DisplayShellContextMenu(Path, MousePos, False);
  end
  else
  begin
    Path := Root;
    DisplayShellContextMenu(Path, MousePos, True);
  end;
  Handled := True;
  inherited DoContextPopup(MousePos, Handled);
end;

procedure TCListView.KeyDown(var Key: Word; Shift: TShiftState);
var
  CreatedPath: string;
begin
  // 1. BackSpace で親フォルダーへ移動
  if (Key = VK_BACK) and (Shift = []) then
  begin
    if NavigateUp then
      Key := 0;
  end
  // 2. ENTER で選択項目を開く
  else if (Key = VK_RETURN) and (Shift = []) then
  begin
    DblClick;
    Key := 0;
  end
  // 3. Ctrl + Shift + N で新規フォルダー作成
  else if (ssCtrl in Shift) and (ssShift in Shift) and (Key = VK_N) then
  begin
    CreatedPath := CreateNewFolderInRoot;
    if CreatedPath <> '' then
      FocusAndRenamePath(CreatedPath);
    Key := 0;
  end
  // 表示形式の切り替え（エクスプローラーと同じキー）
  else if (ssCtrl in Shift) and (ssShift in Shift) and
          ((Key = Ord('2')) or (Key = Ord('4')) or (Key = Ord('5')) or (Key = Ord('6'))) then
  begin
    case Key of
      Ord('2'): SetView(vsIcon);
      Ord('4'): SetView(vsSmallIcon);
      Ord('5'): SetView(vsList);
      Ord('6'): SetView(vsReport);
    end;
    Key := 0;
  end
  // 4. Ctrl + A ですべて選択
  else if (ssCtrl in Shift) and (Key = VK_A) then
  begin
    SelectAllItems;
    Key := 0;
  end
  // 5. Ctrl + C でコピー
  else if (ssCtrl in Shift) and (Key = VK_C) then
  begin
    CopySelected;
    Key := 0;
  end
  // 6. Ctrl + X で切り取り
  else if (ssCtrl in Shift) and (Key = VK_X) then
  begin
    CutSelected;
    Key := 0;
  end
  // 7. Ctrl + V で貼り付け
  else if (ssCtrl in Shift) and (Key = VK_V) then
  begin
    PasteToRoot;
    Key := 0;
  end
  // 6. F5 で最新情報に更新
  else if Key = VK_F5 then
  begin
    Application.QueueAsyncCall(@DoAsyncRefresh, 0);
    Key := 0;
  end
  // 7. F2 で名前の変更
  else if Key = VK_F2 then
  begin
    RenameSelectedFile;
    Key := 0;
  end
  // 8. Delete で削除（Shift + Delete は完全削除）
  else if Key = VK_DELETE then
  begin
    DeleteSelectedFiles(ssShift in Shift);
    Key := 0;
  end;

  inherited KeyDown(Key, Shift);
end;

procedure TCListView.DeleteSelectedFiles(APermanent: Boolean);
var
  i: Integer;
  DeletePaths: string;
begin
  if SelCount = 0 then Exit;

  DeletePaths := '';
  for i := 0 to Items.Count - 1 do
  begin
    if Items[i].Selected then
      DeletePaths := DeletePaths + GetPathFromItem(Items[i]) + #0;
  end;

  // 表示の更新はフォルダー変更監視に任せる
  if DeletePaths <> '' then
    PerformFileOperation(FO_DELETE, DeletePaths, '', not APermanent);
end;

procedure TCListView.CopySelected;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    GetSelectedPaths(L);
    if L.Count > 0 then
      ShellInvokeVerbOnItems(Handle, L, 'copy');
  finally
    L.Free;
  end;
end;

procedure TCListView.CutSelected;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    GetSelectedPaths(L);
    if L.Count > 0 then
      ShellInvokeVerbOnItems(Handle, L, 'cut');
  finally
    L.Free;
  end;
end;

procedure TCListView.PasteToRoot;
begin
  if Root = '' then Exit;
  // 貼り付けた項目は、監視による更新時に選択状態にする
  SelectNewItemsOnNextRefresh;
  // 同じフォルダーへの貼り付けは、シェルが「〜 - コピー」の名前で複製する
  ShellInvokeVerbOnFolder(Handle, Root, 'paste');
end;

procedure TCListView.SelectAllItems;
var
  i: Integer;
begin
  Items.BeginUpdate;
  try
    for i := 0 to Items.Count - 1 do
      Items[i].Selected := True;
  finally
    Items.EndUpdate;
  end;
end;

// 表示中フォルダーの内容を読み直す（監視による更新・F5・新規作成後に使う）。
// 選択状態（複数）・フォーカス・スクロール位置を復元する。
// 貼り付け・ドロップの後（SelectNewItemsOnNextRefresh 済み）は、新しく現れた項目を選択する。
procedure TCListView.DoAsyncRefresh({%H-}Data: PtrInt);
var
  CurrentRoot, FocusedPath, TopPath, P: string;
  SelectedPaths, OldPaths: TStringList;
  i, TopIndex, RestoredCount: Integer;
  FocusItem: TListItem;
  SelectNew, WasDirty: Boolean;

  function NewSortedList: TStringList;
  begin
    Result := TStringList.Create;
    Result.CaseSensitive := False;
    Result.Sorted := True;
    Result.Duplicates := dupIgnore;
  end;

begin
  if not HandleAllocated then Exit;
  if csDestroying in ComponentState then Exit;

  SelectNew := FSelectNewItems;
  FSelectNewItems := False;
  // 全件読み直すので、行単位の反映待ちは不要になる
  FPendingChanges.Clear;
  FNeedFullRefresh := False;
  WasDirty := FSelectionDirty;

  SelectedPaths := NewSortedList;
  OldPaths := NewSortedList;
  try
    // 1. 更新前の状態を記憶
    GetSelectedPaths(SelectedPaths);
    if ItemFocused <> nil then
      FocusedPath := GetPathFromItem(ItemFocused)
    else
      FocusedPath := '';
    if TopItem <> nil then
      TopPath := GetPathFromItem(TopItem)
    else
      TopPath := '';
    if SelectNew then
      for i := 0 to Items.Count - 1 do
        OldPaths.Add(GetPathFromItem(Items[i]));

    SendMessage(Handle, WM_SETREDRAW, WPARAM(False), 0);
    try
      // 2. 読み直し
      CurrentRoot := Root;
      if CurrentRoot <> '' then
      begin
        Root := '';
        Root := CurrentRoot;
      end
      else
        Refresh;

      PopulateFileDateTimes;
      ApplySort;

      // 3. 貼り付け・ドロップ後は、新しく現れた項目を選択対象にする
      if SelectNew then
      begin
        SelectedPaths.Clear;
        FocusedPath := '';
        for i := 0 to Items.Count - 1 do
        begin
          P := GetPathFromItem(Items[i]);
          if OldPaths.IndexOf(P) < 0 then
            SelectedPaths.Add(P);
        end;
      end;

      // 4. 選択・フォーカスを復元
      FocusItem := nil;
      TopIndex := -1;
      RestoredCount := 0;
      for i := 0 to Items.Count - 1 do
      begin
        P := GetPathFromItem(Items[i]);
        if SelectedPaths.IndexOf(P) >= 0 then
        begin
          Items[i].Selected := True;
          Inc(RestoredCount);
          if SelectNew and (FocusItem = nil) then
            FocusItem := Items[i];
        end;
        if (FocusedPath <> '') and SameText(P, FocusedPath) then
          FocusItem := Items[i];
        if (TopPath <> '') and SameText(P, TopPath) then
          TopIndex := i;
      end;
      if FocusItem <> nil then
        ItemFocused := FocusItem;

      // 選択内容が更新前と同じなら、選択変更イベントは出さない
      if (not SelectNew) and (RestoredCount = SelectedPaths.Count) then
        FSelectionDirty := WasDirty;

      // 5. スクロール位置を復元（貼り付け後は、選択した先頭の項目が見えるようにする）
      if SelectNew and (FocusItem <> nil) then
        FocusItem.MakeVisible(False)
      else if (TopIndex >= 0) and (Items.Count > 0) then
      begin
        // 一度末尾を表示してから目的の項目を表示すると、その項目が先頭に来る
        Items[Items.Count - 1].MakeVisible(False);
        Items[TopIndex].MakeVisible(False);
      end;
    finally
      SendMessage(Handle, WM_SETREDRAW, WPARAM(True), 0);
      RedrawWindow(Handle, nil, 0, RDW_INVALIDATE or RDW_ALLCHILDREN or RDW_UPDATENOW);
    end;
  finally
    SelectedPaths.Free;
    OldPaths.Free;
  end;
  // ツリー側の更新は、ツリー自身のフォルダー変更監視に任せる
end;

// ---------------------------------------------------------------
// D&D（ドラッグの開始は OLE。アプリ内・他のアプリへのドラッグとも同じ仕組み）
// ---------------------------------------------------------------

procedure TCListView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  // 項目の上で左／右ボタンが押されたら、ドラッグの準備だけしておく（右ドラッグはメニュー付きのドロップ）
  FDragArmed := (Button in [mbLeft, mbRight]) and not IsEditing and (GetItemAt(X, Y) <> nil);
  FDragButton := Button;
  FDragStartPt.X := X; // Point() は Windows ユニットの型 POINT と衝突するため使わない
  FDragStartPt.Y := Y;
end;

procedure TCListView.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if not FDragArmed then Exit;
  if ((FDragButton = mbLeft) and not (ssLeft in Shift)) or
     ((FDragButton = mbRight) and not (ssRight in Shift)) then
  begin
    FDragArmed := False;
    Exit;
  end;

  // 一定距離動いたらドラッグ開始。
  // ここ（マウス移動の処理中）で直接始めると、リストビューがマウスを捕捉したままになり、
  // ドロップ先がリスト表示から切り替わらない（エクスプローラー等へドロップできない）。
  // そのため、リストビュー自身のマウス処理が終わった後に開始する。
  if (Abs(X - FDragStartPt.X) >= GetSystemMetrics(SM_CXDRAG)) or
     (Abs(Y - FDragStartPt.Y) >= GetSystemMetrics(SM_CYDRAG)) then
  begin
    FDragArmed := False;
    PostMessage(Handle, CM_CSTARTDRAG, 0, 0);
  end;
end;

procedure TCListView.StartOleDrag;
var
  L: TStringList;
  Effect: DWORD;
  Dropped: Boolean;
  VKey: Integer;
begin
  if not HandleAllocated or (csDestroying in ComponentState) then Exit;
  // ボタンが既に離されていたら、ドラッグしない（クリックだった）
  if FDragButton = mbRight then VKey := VK_RBUTTON else VKey := VK_LBUTTON;
  if GetKeyState(VKey) >= 0 then Exit;

  L := TStringList.Create;
  try
    GetSelectedPaths(L);
    if L.Count = 0 then Exit;
    // リストビューのマウス捕捉を解放してから、ドラッグを開始する
    ReleaseCapture;
    // アプリ内のドロップ先で禁止判定に使うため、ドラッグ中の項目を登録しておく
    ShellDragBegin(Self, L);
    try
      // OLE のドラッグを開始する（ドロップ・取り消しまでここで待つ）。
      // コピー／移動はドロップ先（シェル）が行う。表示の更新はフォルダー変更監視に任せる。
      Dropped := ShellDoDragDrop(Handle, L, True, Effect);
      ShellDragLog('TCListView.DoDragDrop dropped=' + BoolToStr(Dropped, True) +
        ' effect=' + IntToStr(Effect));
    finally
      ShellDragEnd;
      ReleaseCapture;
    end;
  finally
    L.Free;
  end;
end;

procedure TCListView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FDragArmed := False;
  inherited MouseUp(Button, Shift, X, Y);
end;

// ドロップ候補の強調表示は、WM_PAINT の後に自前で枠を描く（DrawDropFrame）
procedure TCListView.SetDropHilite(AItem: TListItem);
begin
  if FDropHilite = AItem then Exit;
  FDropHilite := AItem;
  // 枠を描き直す（前の枠を消し、新しい枠を描く）
  if HandleAllocated then
    Invalidate;
end;

procedure TCListView.DrawDropFrame;
var
  R: TRect;
  DC: HDC;
  Br: HBRUSH;
begin
  if (FDropHilite = nil) or not HandleAllocated then Exit;
  R := FDropHilite.DisplayRect(drBounds);
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;
  DC := GetDC(Handle);
  if DC = 0 then Exit;
  Br := CreateSolidBrush(ColorToRGB(clHighlight));
  try
    // 2px の枠
    FrameRect(DC, R, Br);
    InflateRect(R, -1, -1);
    FrameRect(DC, R, Br);
  finally
    DeleteObject(Br);
    ReleaseDC(Handle, DC);
  end;
end;

// --- ドロップの受け付け（OLE：他のアプリ・アプリ内のどちらからのドラッグも） ---

function TCListView.OleResolveDrop(const AScreenPt: TPoint): string;
var
  Pt: TPoint;
  Item, Hilite: TListItem;
  P: string;
begin
  Result := '';
  if (Root = '') or not HandleAllocated then Exit;
  FOleDragOver := True;
  FDragTimer.Enabled := True; // 端での自動スクロール

  // ドロップ先：フォルダー項目 = そのフォルダー、ZIP = その ZIP、それ以外 = 表示中のフォルダー
  Pt := ScreenToClient(AScreenPt);
  Item := GetItemAt(Pt.X, Pt.Y);
  Result := Root;
  Hilite := nil;
  if Item <> nil then
  begin
    P := GetPathFromItem(Item);
    if (P <> '') and (DirectoryExists(P) or SameText(ExtractFileExt(P), '.zip')) then
    begin
      Result := P;
      Hilite := Item;
    end;
  end;

  // アプリ内から始めたドラッグは、禁止判定（自分自身・配下、同じフォルダーへの移動）を行う
  if ShellDragIsActive and
     (ShellDecideDropEffect(ShellDragPaths, Result, ShellDragKeyState) = cdeNone) then
  begin
    Result := '';
    Hilite := nil;
  end;
  SetDropHilite(Hilite);
end;

procedure TCListView.OleDropLeave;
begin
  FOleDragOver := False;
  FDragTimer.Enabled := False;
  SetDropHilite(nil);
end;

procedure TCListView.OleDropped(const AFolder: string);
begin
  // 表示中のフォルダーへのドロップなら、追加された項目を選択状態にする
  if SameText(ExcludeTrailingPathDelimiter(AFolder), ExcludeTrailingPathDelimiter(Root)) then
    SelectNewItemsOnNextRefresh;
end;

procedure TCListView.DragTimerTick({%H-}Sender: TObject);
const
  Margin = 20;
var
  Pt: TPoint;
begin
  if not (ShellDragIsActive or FOleDragOver) or not HandleAllocated then
  begin
    FDragTimer.Enabled := False;
    SetDropHilite(nil);
    Exit;
  end;

  Pt := ScreenToClient(Mouse.CursorPos);
  // カーソルが外に出ていたら止める（戻ってきたら DragOver で再開する）
  if (Pt.X < 0) or (Pt.X >= ClientWidth) or (Pt.Y < -Margin) or (Pt.Y >= ClientHeight + Margin) then
  begin
    FDragTimer.Enabled := False;
    Exit;
  end;

  // 上下の端に近ければ1行ずつスクロール
  if Pt.Y < Margin then
    SendMessage(Handle, WM_VSCROLL, SB_LINEUP, 0)
  else if Pt.Y >= ClientHeight - Margin then
    SendMessage(Handle, WM_VSCROLL, SB_LINEDOWN, 0);
end;


end.
