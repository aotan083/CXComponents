# TCFileTree 設計書

作者: aotan083
日付: 2026-11-05
版: 1.0

---

## 1. 目的

指定したフォルダー（`RootPath`）を根にして、フォルダーとファイルを1本のツリーに並べる部品。VS Code のエクスプローラーと同じ見た目で、TCListView なしに使える。フォームに置いてプロパティをつなぐだけで、次が動くようにする。

- フォルダー・ファイルの作成（フォルダー作成、貼り付け、ほかのアプリからのドロップ）、移動、コピー、削除、名前の変更（マウスとキー）。
- ドラッグ＆ドロップ（ツリーの中、ほかのアプリとの間）。
- 右クリックメニュー（8章の並び）。
- ダブルクリックで開く：`.url` は `TargetBrowser`、`.lnk` はリンク先を見て、テキストなら `TargetEditor`。ほかのテキストは `TargetEditor`、テキストでないものは OS の関連付け。
- 選んだファイルを、TCMonacoEditor・TCsEditor へドラッグ＆ドロップすると、新しいタブで、ファイルの数だけ開く（フォルダーは何もしない）。これはエディター側の既存の動きで、この部品は何も足さない（7.10）。
- 根は `RootPath`（既定値 `C:\`）。根より上のフォルダーへは移動できない。上へ行きたいときは `RootPath` を変える。
- F5 で、開いているフォルダーを最新にする。ほかのアプリで増減したものは、変更通知で自動でも更新される（エディターの「名前を付けて保存」で作ったファイルも出る）。

方針：

- ファイル操作はシェル（Windows）に任せ、表示の更新はフォルダーの変更の監視に任せる（監視の方法は 7.5）。
- 最上位のグループ（クイックアクセス・PC・ネットワーク・Linux）は持たない。根のフォルダーが最上位の1ノード。
- アプリ側にコードを書かせない。開き先は、フォームに置いた部品をプロパティでつなぐだけ（イベントで自由に動かせる口は作らない）。
- TCTreeView・TCListView は変えない。この部品は別の部品として作る。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `CFileTree.pas` | cx（実行時） | 型、`TCFileNode`、`TCFileTree` |
| `CShellMenu.pas`・`CShellDragDrop.pas`・`CShellOleDrop.pas`・`CShellOleDrag.pas` | cx（実行時） | 共通部品（既存。変更しない）。`CShellNotify.pas` は使わない（7.5） |
| `uCFileTreeReg.pas` | cxdsgn（設計時） | パレット [CX] への登録 |
| `cfiletree_icon.lrs` | cxdsgn（設計時） | アイコン（`TCFileTree`・`TCFileTree_150`・`TCFileTree_200`） |
| `uCXLang.pas` | cx | 文字列の追加（10章） |

- interface の uses：`Classes, SysUtils, Controls, ComCtrls, Windows, ActiveX, ShlObj, ShellAPI, Messages, Graphics, Dialogs, Forms, LMessages, ExtCtrls, Menus, CommCtrl, uCmonacos, uCsEditor, uCTabBrowser, SyncObjs, CShellMenu, CShellDragDrop, CShellOleDrop, CShellOleDrag`
- implementation の uses：`uCXLang, Clipbrd, IniFiles, LazUTF8`
- external で宣言するもの：`StrCmpLogicalW`（shlwapi）、`SHGetFileInfoW`・`SHGetSpecialFolderLocation`（shell32）、`CoCreateInstance`（ole32）、`ReadDirectoryChangesW`・`CancelIoEx`（kernel32）。名前を付けて独自に宣言する（FPC 側の宣言に頼らない）。
- `.lnk` のリンク先を読む処理（`IShellLinkW`・`IPersistFile` の宣言と、`CBResolveLink` と同じ処理）と、`.url` の URL を読む処理（`CBReadUrlFile` と同じ処理）は、`uCbookmark.pas` の implementation にあるものと同じ内容を `CFileTree.pas` の implementation に書く（`uCbookmark.pas` は変えない）。名前は `FtResolveLink`・`FtReadUrlFile`。ファイルのパスから `file:///` の URL を作る処理も同様（`FtPathToFileUrl`）。
- initialization・finalization はない。

## 3. 型と定数

```pascal
TCFileNode = class(TTreeNode)
public
  IsDir: Boolean;         // フォルダーなら True
  IconIndex: Integer;     // システムアイコンの番号（IconLoaded のとき有効）
  IconLoaded: Boolean;
end;
```

- ノードの `Text` は、ファイル名・フォルダー名（親のパスは含まない）。パスは持たず、`GetPathFromNode` で、親をたどって作る（名前の変更で子のパスが古くならないように）。

| 定数 | 値 | 中身 |
|---|---|---|
| `WM_CFT_WATCH` | `WM_USER + $5B3` | 監視のスレッドから `TCFileTree` への、「変更があった」知らせ（7.5） |
| `CFtWatchBufBytes` | 65536 | 監視のバッファの大きさ |
| `CFtMaxQueued` | 5000 | 監視のスレッドがためる親フォルダーの数の上限（超えたら全体を更新する） |
| `CFtNewFirstId`・`CFtNewLastId` | `$8200`・`$BFFF` | 「新規作成」のコマンドIDの範囲（項目メニューの 1〜$7FFF と重ならない。7.9） |
| `CFtMaxPending` | 200 | 更新候補がこれを超えたら全体を更新する |
| `CFtTextProbeBytes` | 8192 | テキストかどうかを調べるために読むバイト数 |
| `CFtHoverOpenMs` | 700 | ドラッグ中に同じフォルダーの上に留まって、自動で開くまでの時間 |
| `CFtMenuCount` | 17 | 右クリックメニューの項目数（区切り線を除く） |

## 4. フィールド

| 名前 | 型 | 初期値 | 中身 |
|---|---|---|---|
| `FRootPath` | `string` | `C:\` | 根のフォルダー（末尾の区切りなし。ドライブの根は `C:\`） |
| `FShowHidden` | `Boolean` | `False` | 隠し・システム属性の項目を出す |
| `FTargetEditor`・`FSideEditor` | `TControl` | nil | 開き先のエディター（`TCMonacoEditor` か `TCsEditor`） |
| `FTargetBrowser`・`FSideBrowser` | `TCTabBrowser` | nil | 開き先のブラウザー |
| `FRootDirty` | `Boolean` | `False` | 窓が無い間に `RootPath`・`ShowHidden` が変えられた（次の `CreateWnd` で作り直す） |
| `FIsRefreshing` | `Boolean` | `False` | 更新中（多重に実行しない） |
| `FWatcher` | `TCFtWatcher` | nil | 変更の監視のスレッド（根のフォルダー配下全体。7.5） |
| `FNotifyTimer` | `TTimer` | 300ms・止めておく | 通知の間引き |
| `FPendingPaths` | `TStringList` | 空（大文字小文字を区別しない、並べる、重複は無視） | 更新が要るかもしれないフォルダー |
| `FRefreshAll` | `Boolean` | `False` | 開いているフォルダーをすべて更新する |
| `FDragArmed`・`FDragStartPt`・`FDragButton` | | | ドラッグの準備（押したボタンと位置） |
| `FDragPaths` | `TStringList` | 空 | ドラッグするパス（押したときの選択） |
| `FClickPath` | `string` | '' | 複数選択の中の項目を、修飾キーなしで押したときのパス（動かさずに離したら、その1つだけの選択にする） |
| `FDropHilite` | `TTreeNode` | nil | ドロップ先として枠を描くノード |
| `FHoverNode`・`FHoverSince` | | | 自動で開くための、乗っているノードと乗り始めた時刻 |
| `FDragTimer` | `TTimer` | 80ms・止めておく | ドラッグ中の自動スクロール・自動で開く |
| `FOleTarget` | `TCShellOleDropTarget` | nil | OLE のドロップ先 |
| `FOleDragOver` | `Boolean` | `False` | ほかからのドラッグが上にある |
| `FSysSmallImages` | `HIMAGELIST` | 0 | システムの小アイコンの一覧 |
| `FIconCache` | `TStringList` | 空（大文字小文字を区別しない、並べる） | 拡張子 → アイコン番号（`Objects` に番号を入れる） |
| `FInFixSelection` | `Boolean` | `False` | `DoSelectionChanged` で選択を直している途中・複数選択を戻している途中（再入しない） |
| `FMenu` | `TPopupMenu` | 作る | 右クリックメニュー（8章） |
| `FMenuItems` | `array[TCFtMenu] of TMenuItem` | 作る | メニューの各項目 |
| `FMenuPos` | `TPoint` | | メニューを出した画面上の位置（`windows メニュー` を同じ位置に出すため） |
| `FNewFolderPath` | `string` | '' | 作ったばかりのフォルダー（名前の編集を始めるため） |

```pascal
TCFtMenu = (fmCopy, fmCut, fmPaste, fmRename, fmDelete, fmShowInExplorer, fmCopyPath,
  fmNewFolder, fmTextOpen, fmTextOpenNew, fmTextSide, fmWebOpen, fmWebOpenNew,
  fmWebSide, fmOpenProgram, fmShowHidden, fmWindowsMenu);
```

## 5. 宣言

```pascal
public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  function GetPathFromNode(ANode: TTreeNode): string;
  function IsRootNode(ANode: TTreeNode): Boolean;
  function IsDirNode(ANode: TTreeNode): Boolean;
  function SelectedPath: string;
  procedure GetSelectedPaths(APaths: TStrings);
  procedure CopySelected;
  procedure CutSelected;
  procedure PasteToSelected;
  procedure DeleteSelected(APermanent: Boolean = False);
  procedure RenameSelected;
  procedure NewFolder;
  procedure RefreshTree;
published
  property RootPath: string read FRootPath write SetRootPath;
  property ShowHidden: Boolean read FShowHidden write SetShowHidden default False;
  property TargetEditor: TControl read FTargetEditor write SetTargetEditor;
  property TargetBrowser: TCTabBrowser read FTargetBrowser write SetTargetBrowser;
  property SideEditor: TControl read FSideEditor write SetSideEditor;
  property SideBrowser: TCTabBrowser read FSideBrowser write SetSideBrowser;
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
```

- 土台は `TCustomTreeView`（`TShellTreeView` は使わない）。LCL 標準のプロパティ・イベントのうち、次だけを published に出す。
  - プロパティ：`Align`・`Anchors`・`BorderSpacing`・`BorderStyle`・`Color`・`Constraints`・`Enabled`・`Font`・`Indent`・`ParentColor`・`ParentFont`・`ShowHint`・`Hint`・`TabOrder`・`TabStop`・`Visible`。
  - イベント：`OnClick`・`OnDblClick`・`OnEnter`・`OnExit`・`OnKeyDown`・`OnKeyPress`・`OnKeyUp`・`OnMouseDown`・`OnMouseMove`・`OnMouseUp`・`OnMouseWheel`・`OnSelectionChanged`・`OnExpanded`・`OnCollapsed`。
  - `PopupMenu` は出さない（右クリックメニューはこの部品が持つ）。
- この部品独自のイベントは持たない。
- `SelectedPath`：`Selected` のパス。なければ ''。`GetSelectedPaths`：選んでいる項目すべてのパス（同じフォルダーの中のものだけ。7.4）。

## 6. 作る・壊す

Create：

1. `Options` に `tvoAllowMultiselect` を足す。`ReadOnly := False`、`ShowButtons := True`、`ShowLines := False`、`ShowRoot := True`、`RightClickSelect := False`（右クリックの選択は 7.9 で自分で行う）、`DragMode := dmManual`、`SortType := stNone`（並べるのは自分）、`OnEdited := InternalOnEdited`。
2. 4章の初期値（`FRootPath := 'C:\'`）。タイマー2つ、`FPendingPaths`、`FIconCache`、`FDragPaths` を作る。
3. `FMenu` を作り、8章の項目を並べる。

Destroy：タイマーを止める → `ShellDragAbandon(Self)` → OLE のドロップ先の登録を外す → `StopWatch` → `Application.RemoveAsyncCalls(Self)` → 作ったものを解放 → `inherited`。

CreateWnd：`inherited` のあと、設計時でなければ：

1. 次のどちらかのときだけ、ツリーを作る：項目が1つもなく `FRootPath` が空でない（最初に窓ができたとき）、または `FRootDirty`（`FRootDirty := False`）。→ `BuildTree`。
2. `StartWatch`、`OleDropRegister(Handle, OleResolveDrop, OleDropLeave, OleDropped)`（窓が作り直されるたびに登録し直す。監視のスレッドの通知先がウィンドウのハンドルのため）。

- それ以外（AnchorDocking でのドック・切り離しなどで窓が作り直されたとき）は、項目に手を付けない。開いている状態・選択・スクロールの位置が残る（TCTreeView 設計書 6章と同じ）。

DestroyWnd：`StopWatch`、`OleDropRevoke`、`inherited`。

`DoCreateNodeClass`：`inherited` のあと `NewNodeClass := TCFileNode`。

`Notification`：`TargetEditor`・`TargetBrowser`・`SideEditor`・`SideBrowser` の部品が解放されたら、そのプロパティを nil にする。

## 7. 処理

### 7.1 ツリーを作る・根の変更

`NormalizeRoot(P)`：空なら ''。`ExpandFileName` して、末尾の区切りを除く（ドライブの根 `C:\` と `\\server\share` は区切りを残す）。

| 手続き | 処理 |
|---|---|
| `SetRootPath(P)` | `NormalizeRoot` した値が今と同じなら何もしない。入れて、読み込み中・設計時・ハンドルなしなら `FRootDirty := True` にして終わる（次の `CreateWnd` で作る）。それ以外は `BuildTree` して `StartWatch` |
| `SetShowHidden(V)` | 変わったら入れる。読み込み中・設計時は終わり。ハンドルなしなら `FRootDirty := True`。それ以外は `RefreshTree`（開いている状態・選択を保つ） |
| `BuildTree` | 設計時は何もしない。`Items.BeginUpdate` の間に `Items.Clear`。`FRootPath` が空、または実在しなければそのまま終わり（空のツリー）。実在すれば、根のノードを1つ足す（`IsDir := True`、`HasChildren := True`、`Text` は `ExtractFileName(FRootPath)`、空ならパス全体）。根を `Expand(False)` する（7.2 で子が読み込まれる） |
| `RefreshTree` | `ApplyRefresh(nil, True)`（7.5）。開いているフォルダーをすべて、ディスクの今に合わせる。F5 と同じ（7.7）。変更通知が届かない場所（ネットワークなど）でも最新になる |

- 根より上へは移動できない：ツリーに根より上のノードは作らない。ドラッグ＆ドロップのドロップ先もツリーの中だけ（何もない所は根）。上のフォルダーを見たいときは `RootPath` を変える。
- `RootPath` が空、または実在しないときは、空のツリーになる（既定値の `C:\` は実在するので、そのまま使える）。

### 7.2 子の読み込みと並び

`ReadDirEntries(パス, 結果のフォルダー, 結果のファイル)`：`FindFirstFileW(ShellLongPathW(パス + '\*'))` で読み、`.`・`..` は除く。`FShowHidden` が `False` なら、`FILE_ATTRIBUTE_HIDDEN` か `FILE_ATTRIBUTE_SYSTEM` のものは除く。名前は `UTF8Encode(cFileName)` で入れる。ディレクトリ属性のものはフォルダー、ほかはファイル。それぞれ `StrCmpLogicalW`（自然順）で並べる。読めなければ（アクセス拒否など）`False`。

| 手続き | 処理 |
|---|---|
| `CanExpand(N)` | `TCFileNode` でフォルダーなら、子がないとき `LoadChildren(N)` し、子が1つもなければ `HasChildren := False` にして `False`。ファイルは `False`。ほかは `inherited` |
| `LoadChildren(N)` | `ReadDirEntries(GetPathFromNode(N), …)`。`Items.BeginUpdate` の間に、フォルダー → ファイルの順に `AddChild`（フォルダーは `IsDir := True`・`HasChildren := True`、ファイルは `IsDir := False`・`HasChildren := False`）。例外は無視 |
| `MergeChildren(N)` | 開いているフォルダーの中身を、いまのディスクに合わせる。`ReadDirEntries` の結果と、`N` の子を名前で（大文字小文字を区別せず）突き合わせる。ディスクにない子は（子孫ごと）消す。ない名前は足す。最後に、結果の並び（フォルダー → ファイル）の順に、各ノードの `Index` を合わせる。残ったノードは、開いている状態・選択がそのまま残る。読めなければ子を全部消し、`HasChildren := False` |
| `IsRootNode(N)` | `N <> nil` で `N.Parent = nil` |
| `IsDirNode(N)` | `TCFileNode` で `IsDir` |

### 7.3 パスと探索

| 手続き | 処理 |
|---|---|
| `GetPathFromNode(N)` | nil は ''。根は `FRootPath`。ほかは、親のパス ＋ 区切り（親のパスが区切りで終わっていなければ） ＋ `N.Text` |
| `FindNodeByPath(パス)` | 根から、パスの各部分を、読み込み済みの子の中で（大文字小文字を区別せず）探す。読み込まれていない階層は見つからない（nil） |
| `FolderPathOf(N)` | 貼り付け・作成の先のフォルダー：フォルダーなら自分のパス、ファイルなら親のパス、nil なら `FRootPath` |
| `SelectedPath` | `GetPathFromNode(Selected)` |
| `GetSelectedPaths(一覧)` | 選んでいるノードすべてのパスを、見える順に入れる |

### 7.4 選択（同じフォルダーの中だけ）

選べるのは、同じフォルダーの中の項目だけ（シェルのコピー・移動・削除・D&D が「同じフォルダーの中の項目」を前提にしているため）。

`DoSelectionChanged`：`FInFixSelection` なら終わり。`FInFixSelection := True` にして、`Selected` と親が違う選択ノードの選択を外す（`Selected` の親が nil のときは、`Selected` 以外をすべて外す）。戻して、`inherited`（`OnSelectionChanged`）。

### 7.5 変更通知

シェルの変更通知（`SHChangeNotifyRegister`）は使わない。根の直下の変更は届くが、サブフォルダーの中の変更が届かないため（確認用アプリで確かめた）。代わりに、`ReadDirectoryChangesW` で根の配下全体を、サブフォルダーも含めて監視する。

`TCFtWatcher`（監視のスレッド。`TThread`）：

- `Create(根のパス, ウィンドウのハンドル)`：根のフォルダーを `CreateFileW`（`FILE_LIST_DIRECTORY`、`FILE_SHARE_READ or WRITE or DELETE`、`FILE_FLAG_BACKUP_SEMANTICS`）で開き、すぐ動き出す。
- `Execute`：`Terminated` になるまで、`ReadDirectoryChangesW(ハンドル, バッファ 64KB, サブフォルダーも含める, FILE_NOTIFY_CHANGE_FILE_NAME or FILE_NOTIFY_CHANGE_DIR_NAME)` を繰り返す（待ちは同期）。ファイルの中身・日付の変更は受けない（表示に関係しないため）。
  - 戻ったら、`FILE_NOTIFY_INFORMATION` を順に読み、`根 ＋ 相対パス` の「親フォルダー」を、重複なしでためる（子の増減が起きる場所）。ためたあと、`WM_CFT_WATCH` を Post する（取り出されるまでは1回だけ）。
  - バッファがあふれた（0 バイトで戻った）、ためた数が `CFtMaxQueued`（5000）を超えた、読み取りが連続 5 回失敗した（根が消えた・取り外された）ときは、`FOverflow := True`（受け側は全体の更新にする）にして Post する。
- `TakePaths(一覧, 取りこぼし)`：ためた親フォルダーを取り出して空にし、`FOverflow` を返して戻す（排他制御つき）。
- `Stop`：`Terminate` し、`CancelIoEx` で読み取りの待ちを取り消して、スレッドの終わりまで待つ（取り消しが読み取りの前に当たることがあるので、終わるまで繰り返す）。

`StartWatch`：前の監視を止める。設計時・ハンドルなし・`FRootPath` が空か実在しなければ終わる。`TCFtWatcher.Create(FRootPath, Handle)`。`StopWatch`：`Stop` して解放する。

`HandleWatch`（`WM_CFT_WATCH`）：

1. `TakePaths`。取りこぼしがあれば `FRefreshAll := True`。
2. ほかは（`FRefreshAll` でなければ）、取り出した親フォルダーのうち、`FindNodeByPath` で見つかったもの（読み込み済みのもの）だけを `FPendingPaths` に足す。読み込んでいないフォルダーの変更は捨てる（開いたときに最新を読む。根が `C:\` のように大きくても、関係のない変更で更新が走らない）。
3. `CFtMaxPending` を超えたら空にして `FRefreshAll := True`。
4. 何かあれば `FNotifyTimer` を掛け直す。

`NotifyTimerTick`：名前の編集中・LCL のドラッグ中・更新中・アプリ内ドラッグ中（`ShellDragIsActive`）・ほかからのドラッグが上にあるときは保留（ドロップ先の強調が消えないように）。タイマーを止め、`FRefreshAll` と `FPendingPaths` を取り出して空にし、`ApplyRefresh(候補, 全体)` を呼ぶ。

- エディターの「名前を付けて保存」で、開いているフォルダーにファイルを作った場合も、監視でそのフォルダーが候補になり、表示される（閉じているフォルダーは、開いたときに最新を読む）。根の外に保存したものは出ない。

`ApplyRefresh(候補, 全体)`（`RefreshTree` からも呼ぶ。保留はしない）：

- 更新中・壊している途中なら何もしない。`FIsRefreshing := True`、`Items.BeginUpdate` の間に：
  - 全体なら、開いているフォルダーのパスを上から集め、順に `FindNodeByPath` して `MergeChildren`（前の更新で消えたノードは見つからなければ飛ばす）。根が実在しなければ `BuildTree`（空になる）。
  - 候補なら、各パスを `FindNodeByPath` して、見つかったフォルダーについて：開いていれば `MergeChildren`、閉じていれば子を消して `HasChildren := True`（次に開いたときに最新を読む）。
- 例外は握りつぶす（次の通知・F5 でやり直される）。`FIsRefreshing := False`。

### 7.6 アイコン

`DrawBuiltinIcon`：`TCFileNode` でなければ `inherited`。ほかは `NodeIconIndex` の番号を、`FSysSmallImages` から `ImageList_Draw(…, ILD_TRANSPARENT)` で、枠の縦の中央に描く。大きさは `GetBuiltinIconSize` を返す。`GetBuiltinIconSize`：`GetSystemMetrics(SM_CXSMICON)`・`SM_CYSMICON`。

`NodeIconIndex(N)`：読み込み済みならその番号。ほかは、`SHGetFileInfoW`（`SHGFI_SYSICONINDEX or SHGFI_SMALLICON`）で取る。

| ノード | 取り方 |
|---|---|
| フォルダー（根も） | 名前 'folder'、`FILE_ATTRIBUTE_DIRECTORY`、`SHGFI_USEFILEATTRIBUTES` を付ける（ディスクに触れない）。`FIconCache` の '\folder' に覚える |
| `.exe`・`.ico`・`.lnk` | パス、属性 0、`SHGFI_USEFILEATTRIBUTES` なし（ファイルごとのアイコン）。キャッシュしない |
| ほかのファイル | 拡張子（なければ ''）で `FIconCache` を引く。なければ 'x' ＋ 拡張子、`FILE_ATTRIBUTE_NORMAL`、`SHGFI_USEFILEATTRIBUTES` を付けて取り、覚える |

戻り値（イメージリストのハンドル）が 0 でなければ、`FSysSmallImages` が 0 のときに入れ、`iIcon` を番号にする。番号と `IconLoaded := True` をノードに覚える。

### 7.7 キー（KeyDown）

| キー | 処理 |
|---|---|
| Ctrl+C・Ctrl+X・Ctrl+V | `CopySelected`・`CutSelected`・`PasteToSelected`、`Key := 0`、終わる（編集中は何もしない） |
| F2 | `RenameSelected`、`Key := 0` |
| Delete | `DeleteSelected(Shift があるか)`、`Key := 0` |
| F5 | `RefreshTree`（開いているフォルダーをすべて最新にする）、`Key := 0` |
| Enter | `Selected` がファイルなら 7.9 の `OpenNodeByDefault`、`Key := 0`。フォルダーは開閉 |

最後に `inherited KeyDown`（`Key = 0` なら何もしない）。名前の編集中は、キーを編集欄に任せる。

### 7.8 ファイル・フォルダーの操作

| 手続き | 処理 |
|---|---|
| `CopySelected` | 選択のパスを集める。空か根を含むなら終わる。`ShellInvokeVerbOnItems(Handle, 一覧, 'copy')` |
| `CutSelected` | 同じ条件で `'cut'` |
| `PasteToSelected` | `ShellInvokeVerbOnFolder(Handle, FolderPathOf(Selected), 'paste')`。フォルダーを選んでいなければ、選んでいるファイルの親、何も選んでいなければ根 |
| `DeleteSelected(完全)` | 空か根を含むなら終わる。`ShellInvokeVerbOnItems(Handle, 一覧, 'delete', 完全)`（確認はシェルが出す。ごみ箱に入れる） |
| `RenameSelected` | 選択が1つで、根でなければ `Selected.EditText` |
| `CanEdit(N)` | `inherited` で、根でなければ `True` |
| `InternalOnEdited(N, var S)` | `S` が空か、元と同じなら `S` を元に戻して終わる。`ContainsInvalidChar(S)` なら `CXT(sFtErrBadChars)` ＋ 改行 ＋ '\ / : * ? " < > \|' を出して、元に戻す。違えば、`TRenameInfo` を `New`（元のパス＝`GetPathFromNode(N)`、新しいパス＝親のパス ＋ `S`、`ParentPath`＝親のパス）して `QueueAsyncCall(DoAsyncRename)` |
| `DoAsyncRename` | 壊している途中でなければ `ShellRenameItem(Handle, 元, 新しい名前)`。失敗したら（シェルが理由を出す）、表示を戻すため親を `FPendingPaths` に足してタイマーを掛け直す。最後に `Dispose` |
| `NewFolder` | 作る先は `FolderPathOf(Selected)`。名前は `CXT(sBmNewFolder)`、実在すれば ' (2)'、' (3)'… を付けた、まだないもの。`CreateDirectoryW(ShellLongPathW(パス))` に失敗したら `Format(CXT(sFtErrCreateFolder), [パス])` を出して終わる。成功したら、作る先のノードを `Expand(False)`、`MergeChildren`、作ったフォルダーのノードを選んで `MakeVisible`、`FNewFolderPath` に覚えて `QueueAsyncCall(DoAsyncEdit)`（名前の編集を始める） |
| `DoAsyncEdit` | `FNewFolderPath` のノードを `FindNodeByPath` で探し、見つかれば `EditText`。`FNewFolderPath := ''` |

`TRenameInfo` は TCTreeView と同じ形（`OldPath`・`NewPath`・`ParentPath`）を `CFileTree.pas` に別に宣言する（名前は `TFtRenameInfo`・`PFtRenameInfo`）。

表示の更新は変更通知に任せる（7.5）。

### 7.9 右クリックメニューと開く

#### ダブルクリックで開く（DblClick）

`inherited` のあと、マウスの下のノード（`ScreenToClient(Mouse.CursorPos)` と `GetNodeAt`）がファイルなら `OpenNodeByDefault`。フォルダーは LCL の開閉のまま。

`OpenNodeByDefault(N)`：パス P、拡張子（小文字）E。

| 条件 | 動き |
|---|---|
| E = '.url' | `FtReadUrlFile(P)` が空でなければ `OpenInBrowser(URL, 表示中のタブ, TargetBrowser)`（`TargetBrowser` が nil なら `ShellExecuteW(P)`）。空なら何もしない |
| E = '.lnk' | `T := FtResolveLink(P)`。'http://'・'https://' で始まれば、'.url' と同じ。実在するテキストファイルで `TargetEditor` があれば `OpenInEditor(T, 表示中のタブ, TargetEditor)`。ほかは `ShellExecuteW(P)` |
| ほか | `IsTextFile(P)` で `TargetEditor` があれば `OpenInEditor(P, 表示中のタブ, TargetEditor)`。ほかは `ShellExecuteW(P)`（OS の関連付け） |

- `ShellExecuteW(0, 'open', P, nil, 作業フォルダー＝親, SW_SHOWNORMAL)`。戻り値が 32 以下なら `Format(CXT(sBmOpenError), [P + ' : ' + エラー番号])` を出す。
- 開く前に `FileExists(P)` を確かめ、なければ `Format(CXT(sBmFileMissing), [P])` を出して開かない。

`IsTextFile(P)`：ファイルの先頭 `CFtTextProbeBytes` バイトを読む。長さ 0 なら `True`。先頭が UTF-16 の BOM（FF FE か FE FF）なら `True`。NUL（0x00）が1つでもあれば `False`、なければ `True`。読めなければ `False`。

#### 開き方（エディター・ブラウザー）

| 手続き | 処理 |
|---|---|
| `OpenInEditor(P, 新規タブ, E)` | `E` は `TCMonacoEditor` か `TCsEditor`（どちらも同じ名前のメソッド）。TCBookmark の `OpenInEditor` と同じ動き：新規タブなら `E.OpenFile(P)`（すでに開いていればそのタブへ）して `SetFocus`。表示中のタブなら、(1) `E.FindPage(P)` が 0 以上なら `E.ActiveIndex` にして `SetFocus`。(2) `E.Modified` なら `CXT(sBmUnsaved)` で聞き、はいなら `E.OpenFile(P)`、いいえなら開かない。(3) ほかは `E.LoadFromFile(P)` して `SetFocus`。例外は `Format(CXT(sBmOpenError), [P + ' : ' + メッセージ])` を出す |
| `OpenInBrowser(URL, 新規タブ, B)` | 新規タブなら `B.Add(URL)`、表示中のタブなら `B.Count = 0` のとき `B.Add(URL)`、ほかは `B.Navigate(URL)`。例外は同じく `sBmOpenError` |

- `TCMonacoEditor` と `TCsEditor` の呼び分けは、`E is TCMonacoEditor` / `E is TCsEditor` で行う（`FindPage`・`ActiveIndex`・`Modified`・`OpenFile`・`LoadFromFile`・`SetFocus` を、それぞれ2つの分岐で呼ぶ小さな手続きにまとめる）。

#### 「開く先」のプロパティ

| 手続き | 処理 |
|---|---|
| `SetTargetEditor(V)`・`SetSideEditor(V)` | `V` が nil か、`TCMonacoEditor`・`TCsEditor` のどちらかで、かつ（`FTargetEditor`・`FSideEditor` のもう一方が nil でなければ）もう一方と同じクラスのときだけ入れる（ほかは今の値のまま）。解放通知を付け替える |
| `SetTargetBrowser(V)`・`SetSideBrowser(V)` | 入れて、解放通知を付け替える |

- エディターの種類をまたぐ組み合わせ（Monaco と TCsEditor）は受け付けない。

#### 右クリックメニュー

`DoContextPopup`：`Handled := True`（`PopupMenu` は使わない）。マウスの下にノードがあり、選択に入っていなければ、選択をすべて外してそのノードだけを選ぶ（入っていれば選択はそのまま）。ノードがなければ選択をすべて外す。`FMenuPos` に画面の位置を覚え、`UpdateMenuState`、`FMenu.PopUp(画面の位置)`。

`UpdateMenuState`：選択のノード数 n、そのうち根を含むか、最初のノード F（n = 1 のとき）で決める。

| 項目 | 使える条件 |
|---|---|
| コピー・切取り | n ≥ 1 で、根を含まない |
| 貼付け | クリップボードにファイル（`CF_HDROP`）がある |
| 名前の変更 | n = 1 で、根でない |
| 削除 | n ≥ 1 で、根を含まない |
| エクスプローラーで表示 | n ≥ 1 |
| パスのコピー | n ≥ 1 |
| フォルダ作成 | いつでも（`FRootPath` が実在するとき） |
| text開く・text新規タブで開く | n = 1 でファイル、`FTargetEditor` がある、`TextTargetOf(P) <> ''` |
| text 横に並べて表示 | n = 1 でファイル、`FSideEditor` がある、`TextTargetOf(P) <> ''` |
| Web開く・Web新規タブで開く | n = 1 でファイル、`FTargetBrowser` がある、`WebUrlOf(P) <> ''` |
| Web 横に並べて表示 | n = 1 でファイル、`FSideBrowser` がある、`WebUrlOf(P) <> ''` |
| プログラムで開く | n = 1 でファイル |
| 隠しファイルを表示 | いつでも。`UpdateMenuState` で、`Checked := FShowHidden` にする |
| windows メニュー | n ≥ 1 |

`TextTargetOf(P)`（開くファイルのパス。なければ ''）：E が '.lnk' なら、`FtResolveLink(P)` が実在するテキストファイルのときそのパス、ほかは ''。E が '.url' なら ''。ほかは `IsTextFile(P)` のとき P。

`WebUrlOf(P)`（開く URL。なければ ''）：E が '.url' なら `FtReadUrlFile(P)`。E が '.lnk' なら、リンク先が 'http://'・'https://' で始まるときその URL、ほかは ''。ほかは `FtPathToFileUrl(P)`。

| 項目 | 動き |
|---|---|
| コピー・切取り・貼付け・名前の変更 | 7.8 の同名の手続き |
| 削除 | `DeleteSelected(False)`（ごみ箱に入れる。確認はシェルが出す）。完全に削除するときは Shift+Delete（7.7） |
| エクスプローラーで表示 | フォルダーなら `ShellExecuteW(0, 'open', パス)`。ファイルなら `ShellExecuteW(0, 'open', 'explorer.exe', '/select,"' + パス + '"')`。選択の最初のノードで行う |
| パスのコピー | 選択のパス（根を含む）を、1行に1つ、`Clipboard.AsText` に入れる（複数なら改行区切り） |
| フォルダ作成 | `NewFolder` |
| text開く | `OpenInEditor(TextTargetOf(P), False, FTargetEditor)` |
| text新規タブで開く | `OpenInEditor(TextTargetOf(P), True, FTargetEditor)` |
| text 横に並べて表示 | `OpenInEditor(TextTargetOf(P), True, FSideEditor)`。開く前に `FSideEditor.Visible := True` |
| Web開く | `OpenInBrowser(WebUrlOf(P), False, FTargetBrowser)` |
| Web新規タブで開く | `OpenInBrowser(WebUrlOf(P), True, FTargetBrowser)` |
| Web 横に並べて表示 | `OpenInBrowser(WebUrlOf(P), True, FSideBrowser)`。開く前に `FSideBrowser.Visible := True` |
| プログラムで開く | `ShellExecuteW(P)`（OS の関連付け。`.lnk` は `.lnk` 自体を実行する） |
| 隠しファイルを表示 | `ShowHidden := not FShowHidden`（`SetShowHidden` 経由。表示中のフォルダーを、開いている状態・選択を保ったまま読み直す）。このプロパティを、アプリが保存して次回に使うかは、アプリ側で決める |
| windows メニュー | `DisplayShellContextMenu(選択のパス一覧, FMenuPos)` |

`DisplayShellContextMenu`：エクスプローラーでその項目を右クリックしたときと同じメニューを出す。フォルダーとファイルで中身が違い（ファイルは「開く」「メモ帳で編集」「プログラムから開く」など、フォルダーは「展開」「新しいタブで開く」など）、Git・VLC・TortoiseGit・Code など、PC に登録されたアプリの項目も出る。Windows 11 の短いメニューではなく、従来の完全なメニュー（`QueryContextMenu` に `CMF_NORMAL`）。処理は TCTreeView の `DisplayShellContextMenu`（TCTreeView 設計書 7.11）と同じ。違いは次のとおり。

- パスは1つではなく、選択のパスすべて（同じフォルダーの中。7.4）。親フォルダーの `IShellFolder` から、それぞれの子の PIDL を配列にして `GetUIObjectOf(IID_IContextMenu)` に渡す。
- 根を含むときは、根を1つだけ（親は根の親フォルダー）。
- 独自の項目を足す処理（`ExtraMenuInsert`・`ExtraMenuClick`）は使わない。
- フォルダー1つ（根も）を選んでいるときだけ、標準の「新規作成」を差し込む。項目のメニュー（`GetUIObjectOf`）には「新規作成」が無く、フォルダーの背景のメニューにしか無いため（確認用アプリで確かめた）。`AddNewSubmenu(メニュー, フォルダー)`：
  1. `CoCreateInstance(CLSID_NewMenu {D969A300-E7FF-11D0-A93B-00A0C90F2719})` で `IContextMenu` を作り、`IShellExtInit.Initialize(フォルダーの PIDL, nil, 0)` で、作る先のフォルダーを教える。
  2. 空のメニューに、`QueryContextMenu(…, CFtNewFirstId = $8200, CFtNewLastId = $BFFF, CMF_NORMAL)`（項目メニューの 1〜$7FFF と重ならない）。できた先頭の項目（「新規作成」とそのサブメニュー）を取り出す。
  3. サブメニューの中身（フォルダー・ショートカット・テキスト ドキュメントなど）を、`IContextMenu2.HandleMenuMsg(WM_INITMENUPOPUP, サブメニュー, 0)` で、開く前に作らせておく。
  4. `RemoveMenu`（サブメニューを壊さずに外す）して、項目メニューの最後の項目（プロパティ）の前に、「新規作成」と区切り線を差し込む。
  選ばれたコマンドID が `$8200〜$BFFF` なら、`ShellInvokeMenuCommand(新規作成の IContextMenu, Handle, ID − $8200, フォルダーのパス)`。ほかは項目のメニューのコマンド。
- 複数選択・ファイルを選んでいるときは、「新規作成」は差し込まない（エクスプローラーでも出ない）。
- 「送る」「新規作成」など、開いたときに中身をシェルが作るサブメニューも動く。共通部品の `TrackShellContextMenu` が、`IContextMenu2/3` で、メニューのメッセージ（`WM_INITMENUPOPUP`・`WM_DRAWITEM`・`WM_MEASUREITEM`・`WM_MENUCHAR`）をシェルへ渡すため。この部品は、`QueryContextMenu` の結果の `IContextMenu` をそのまま渡すだけで、別の処理は要らない。
- 「新規作成」で作る先は、選んだフォルダーの中。作ったファイル・フォルダーは、変更の監視（7.5）で表示される。確認用アプリで、選んだフォルダーの中にでき、親にはできないことを確かめた。
- 「送る」は、選んだ項目すべてを送る（複数選択のとき、同じフォルダーの中の項目すべてが `IContextMenu` に入っているため）。
- コマンド名が 'rename' なら `RenameSelected`、'delete' ならシェルに任せる（`ShellInvokeMenuCommand`）、ほかも `ShellInvokeMenuCommand(…, 親のパス)`。

### 7.10 ドラッグ＆ドロップ

送り側：

1. `MouseDown`：
   - 左ボタンで、修飾キーなしで、押した位置のノードがすでに選択に入っていて、選択が2つ以上のとき：`inherited` を呼ばず（選択を保つ）、`SetFocus`、`FClickPath` にそのパスを覚える。
   - それ以外：`inherited`、`FClickPath := ''`。
   - どちらも、左・右ボタンで、編集中でなく、押した位置にノードがあり、根でなければ：`FDragArmed := True`、ボタンと位置を覚え、`FDragPaths` に選択のパスを入れる（押したノードが選択に入っていなければ、そのノード1つ）。
2. `MouseMove`：`FDragArmed` でボタンが離されていればやめる。`SM_CXDRAG`・`SM_CYDRAG` 以上動いたら `FDragArmed := False`、`FClickPath := ''`、`ShellDragBegin(Self, FDragPaths)`、`ShellDoDragDrop(Handle, FDragPaths, False, Effect)`、`ShellDragEnd`、`ReleaseCapture`。
3. `MouseUp`：`FDragArmed := False`。`FClickPath` が空でなければ、選択をすべて外してそのノード1つを選び、`FClickPath := ''`。`inherited`。

受け側（`OleResolveDrop`）：

1. ハンドルなしなら ''。`FOleDragOver := True`、`FDragTimer` を動かす。
2. マウスの下のノードがフォルダーならそのパス、ファイルならその親のパス、ノードがなければ `FRootPath`。これがドロップ先。
3. アプリ内から始めたドラッグで `ShellDecideDropEffect(ShellDragPaths, ドロップ先, ShellDragKeyState) = cdeNone` なら ''。
4. ドロップ先があれば、そのフォルダーのノード（ファイルの上なら親のノード、何もなければ nil）を `SetDropHilite`。

| 手続き | 処理 |
|---|---|
| `OleDropLeave` | `FOleDragOver := False`、タイマーを止め、`FHoverNode := nil`、枠を消す |
| `OleDropped` | 何もしない（表示の更新は変更通知に任せる） |
| `SetDropHilite` | 変わったら入れて `Invalidate` |
| `Paint` | `inherited` のあと、`FDropHilite` が見えていれば `DisplayRect(True)` に `clHighlight` の2pxの枠 |
| `DragTimerTick` | ドラッグ中でなければ止めて枠を消す。マウスが外（上下は 20px の余裕）なら止める。上端・下端から 20px 以内なら `WM_VSCROLL`（1行）。同じフォルダーのノードの上に `CFtHoverOpenMs` 留まり、閉じていて子があれば開く |

- ドロップされたファイル・フォルダーのコピー・移動は、シェル（OLE のドロップ先）が行う。ファイル・フォルダーを作る操作（ほかのアプリからのドロップ、貼り付け）も同じ。

ほかの部品・アプリへのドロップ：

- ドラッグするのは、エクスプローラーと同じ形のデータ（ファイルの一覧）。ドロップ先の動きは、ドロップ先が決める。
- TCMonacoEditor・TCsEditor にドロップすると、エディターの既存の動き（`OpenDroppedFiles = True` が既定）で、`MultiDocument = True` なら新しいタブで、選んだファイルの数だけ開く。すでに開いているファイルは、そのタブへ切り替える。フォルダーは無視される。この部品は、エディター側に何も足さない。
- エディターが開くだけで、元のファイルは動かさない（ドロップ先が「移動」を返しても、この部品は何も消さない）。

## 8. 右クリックメニューの並び

| 順 | 項目（ID） | 文字（日本語／English） |
|---|---|---|
| 1 | `fmCopy` | コピー／Copy |
| 2 | `fmCut` | 切取り／Cut |
| 3 | `fmPaste` | 貼付け／Paste |
| 4 | `fmRename` | 名前の変更／Rename |
| 5 | `fmDelete` | 削除／Delete |
| | ー区切り線ー | |
| 6 | `fmShowInExplorer` | エクスプローラーで表示／Show in Explorer |
| 7 | `fmCopyPath` | パスのコピー／Copy Path |
| | ー区切り線ー | |
| 8 | `fmNewFolder` | フォルダ作成／New Folder |
| | ー区切り線ー | |
| 9 | `fmTextOpen` | text開く／Open as Text |
| 10 | `fmTextOpenNew` | text新規タブで開く／Open as Text in New Tab |
| 11 | `fmTextSide` | 横に並べて表示／Open Side by Side |
| | ー区切り線ー | |
| 12 | `fmWebOpen` | Web開く／Open as Web |
| 13 | `fmWebOpenNew` | Web新規タブで開く／Open as Web in New Tab |
| 14 | `fmWebSide` | 横に並べて表示／Open Side by Side |
| | ー区切り線ー | |
| 15 | `fmOpenProgram` | プログラムで開く／Open with Associated Program |
| | ー区切り線ー | |
| 16 | `fmShowHidden` | 隠しファイルを表示／Show Hidden Files（チェック付き） |
| | ー区切り線ー | |
| 17 | `fmWindowsMenu` | windowsメニュー／Windows Menu |

- 区切り線は 6 つ。使えない項目は灰色にする（7.9 の表）。
- 項目には、アクセラレーターキー（`&`）は付けない。

## 9. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| ツリーが空 | `RootPath` が実在するか、`NormalizeRoot`・`BuildTree`（7.1） |
| ファイルが出ない・隠しファイルが出る | `ReadDirEntries` の属性の判定、`ShowHidden`（7.2） |
| 展開が遅い | `LoadChildren` の対象フォルダーの大きさ。閉じたフォルダーを読んでいないか（7.2、7.5） |
| 外で変えても表示が変わらない | `StartWatch` で監視を始めたか、`HandleWatch` で捨てていない（読み込み済みのフォルダーか）か、`NotifyTimerTick` の保留条件（7.5） |
| 更新で開いている状態・選択が消える | `MergeChildren` が作り直していないか（7.2） |
| ドック・切り離しのあと、最初の状態に戻る | `CreateWnd` の作る条件（6章） |
| 複数選択が1つに戻る | `DoSelectionChanged`（7.4）、`MouseDown` の複数選択の扱い（7.10） |
| 右クリックで選択が消える | `DoContextPopup` の選択の扱い。`RightClickSelect` が `False` か（6章、7.9） |
| 開き先が灰色 | `TargetEditor`・`SideEditor` が同じ種類か、`IsTextFile`（7.9） |
| エクスプローラーからドロップできない | `CreateWnd` の `OleDropRegister`、`OleResolveDrop`（6章、7.10） |
| windows メニューの「送る」「新規作成」が空・動かない | `TrackShellContextMenu` に `IContextMenu` を渡しているか（`IContextMenu2/3` の取得を妨げていないか）、`ShellInvokeMenuCommand` の作業フォルダー（7.9）。フォルダーを選んで「新規作成」したとき、そのフォルダーの中にできるか（親にできていないか） |
| エディターへドロップしても開かない | エディターの `OpenDroppedFiles`・`OnFileDrop`、`ShellDoDragDrop` に渡したパス（7.10）。エクスプローラーからのドロップで開くか |
| 保存したファイルが出ない | 保存先が根の配下か、監視が届いているか（`TCFtWatcher`・`HandleWatch`）、`NotifyTimerTick` の保留条件（7.5）。届かない場所は F5 |
| 名前の変更が戻る | `DoAsyncRename` の失敗、`InternalOnEdited` の判定（7.8） |
| アイコンが違う | `NodeIconIndex` の拡張子ごとのキャッシュ（7.6） |
| D&D の動きを追いたい | TCListView 設計書 11章の `ShellDragTrace` |

## 10. 文字列（uCXLang.pas に足す）

`TCXStr` の末尾（`sBmHtmlFilter` の後）に、次の順で足す。`CXTable` にも同じ順で足す。`%` の並びは日本語と English で同じにする。

| ID | 日本語 | English |
|---|---|---|
| `sFtMenuCopy` | コピー | Copy |
| `sFtMenuCut` | 切取り | Cut |
| `sFtMenuPaste` | 貼付け | Paste |
| `sFtMenuRename` | 名前の変更 | Rename |
| `sFtMenuDelete` | 削除 | Delete |
| `sFtMenuShowInExplorer` | エクスプローラーで表示 | Show in Explorer |
| `sFtMenuCopyPath` | パスのコピー | Copy Path |
| `sFtMenuNewFolder` | フォルダ作成 | New Folder |
| `sFtMenuTextOpen` | text開く | Open as Text |
| `sFtMenuTextOpenNew` | text新規タブで開く | Open as Text in New Tab |
| `sFtMenuSide` | 横に並べて表示 | Open Side by Side |
| `sFtMenuWebOpen` | Web開く | Open as Web |
| `sFtMenuWebOpenNew` | Web新規タブで開く | Open as Web in New Tab |
| `sFtMenuOpenProgram` | プログラムで開く | Open with Associated Program |
| `sFtMenuShowHidden` | 隠しファイルを表示 | Show Hidden Files |
| `sFtMenuWindowsMenu` | windowsメニュー | Windows Menu |
| `sFtErrBadChars` | ファイル名・フォルダー名に以下の文字は使用できません: | The following characters cannot be used in a file or folder name: |
| `sFtErrCreateFolder` | フォルダーを作れませんでした：%s | Could not create the folder: %s |

- 既存の文字列を使うもの：`sBmUnsaved`（未保存の確認）、`sBmOpenError`（開けなかった）、`sBmFileMissing`（ファイルがない）、`sBmNewFolder`（新しいフォルダーの名前）。
- `fmTextSide` と `fmWebSide` は同じ文字（`sFtMenuSide`）を使う。

## 11. 直す所

| No | ファイル | 変更 |
|---|---|---|
| 1 | `source\CFileTree.pas` | 新規。2〜7章（作成済み） |
| 2 | `source\design\uCFileTreeReg.pas` | 新規。パレット [CX] に `TCFileTree` を登録。アイコンは `cfiletree_icon.lrs`（`tcfiletree`・`tcfiletree_150`・`tcfiletree_200`）を読み込む（`uCbookmark_reg.pas` と同じ形）（作成済み） |
| 3 | `source\res\cfiletree_icon.lrs` | 新規（作成済み。24・36・48px の PNG から `lazres` で作った。絵は仮のもの。差し替えるときは、同じ名前の PNG から作り直す） |
| 4 | `source\uCXLang.pas` | 10章の文字列を足す |
| 5 | `packages\cx.lpk`・`packages\cx.pas` | `CFileTree` を足す（作成済み） |
| 6 | `packages\cxdsgn.lpk`・`packages\cxdsgn.pas` | `uCFileTreeReg` と `cfiletree_icon.lrs` を足す（作成済み） |
| 7 | `docs\CXLang_Design.md` | 5章の表に、10章の文字列を足す |
| 8 | ほかのファイル | 変更なし（`CTreeView.pas`・`CListView.pas`・`uCbookmark.pas`・共通部品は変えない） |

- テスト仕様は別文書（`docs\test_docs\TCFileTree_Test.md`）。取説は `docs\TCFileTree_Usage.md`。
