# TCTreeView 設計書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 目的

TShellTreeView（LCL）を元に、Windows のエクスプローラーの左側と同じように使えるフォルダーのツリーを作る。フォームに置くだけで、コピー・移動・削除・名前の変更・ドラッグ＆ドロップ・右クリックメニュー・自動更新が動くようにする。

- 最上位に、クイックアクセス・OneDrive・PC（全ドライブ）・ネットワーク・Linux（WSL）を並べる。
- ファイルの操作はシェル（Windows）に任せ、表示の更新はフォルダーの変更通知に任せる。
- フォルダーの並びはエクスプローラーと同じ自然順にする。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `CTreeView.pas` | cx（実行時） | 型、`TCTreeNode`、`TCTreeView`、`IsDriveRootPath` |
| `CShellNotify.pas`・`CShellMenu.pas`・`CShellDragDrop.pas`・`CShellOleDrop.pas`・`CShellOleDrag.pas` | cx（実行時） | 共通部品。中身は TCListView 設計書の 9〜13章 |
| `uCXReg.pas` | cxdsgn（設計時） | パレット [CX] への登録（並びの先頭） |
| `cx_icons.lrs` | cxdsgn（設計時） | アイコン（`TCTreeView`・`TCTreeView_150`・`TCTreeView_200`） |

- interface の uses：`Classes, SysUtils, Controls, ComCtrls, ShellCtrls, Windows, ActiveX, ShlObj, ShellAPI, Messages, Graphics, Dialogs, Forms, LMessages, ExtCtrls, Menus, CommCtrl, CShellNotify, CShellMenu, CShellDragDrop, CShellOleDrop, CShellOleDrag`
- implementation の uses：`CListView, ComObj, Variants, Registry`（`CListView` は戻る・進むと、近道を選んだときの一覧の移動に使う）。
- external で宣言するもの：`StrCmpLogicalW`（shlwapi）、`SHGetFileInfoW`・`SHParseDisplayName`・`SHGetSpecialFolderLocation`（shell32。名前を付けて独自に宣言）。
- initialization・finalization はない。

## 3. 型と定数

```pascal
PRenameInfo = ^TRenameInfo;
TRenameInfo = record
  OldPath: string;
  NewPath: string;
  ParentPath: string;   // ノードへのポインタは持たず、パスで持つ
end;

TCNodeKind = (nkNormal, nkGroup, nkShortcut);
TCGroupKind = (gkNone, gkQuickAccess, gkPC, gkNetwork, gkLinux);

TCTreeNode = class(TShellTreeNode)
public
  Kind: TCNodeKind;
  Group: TCGroupKind;
  RealPath: string;      // 近道の指す実在のフォルダー（nkShortcut のとき）
  IconIndex: Integer;    // システムアイコンの番号（IconLoaded のとき有効）
  IconLoaded: Boolean;
  procedure InitSpecial(AKind: TCNodeKind; AGroup: TCGroupKind; const ARealPath: string);
end;

function IsDriveRootPath(const APath: string): Boolean;
```

| 種類 | 中身 |
|---|---|
| `nkNormal` | 普通のフォルダー・ドライブ |
| `nkGroup` | グループ（クイックアクセス、PC、ネットワーク、Linux）。実在のパスを持たない |
| `nkShortcut` | 近道（ピン留めしたフォルダー、OneDrive、共有フォルダー、WSL）。実在のフォルダーを指す |

- `InitSpecial`：種類・グループを入れ、`RealPath` は末尾の区切りを除いて入れ、`IconLoaded := False`、`FFileInfo.Name := Text`、`FFileInfo.Attr := faDirectory`（フォルダーとして扱う）。
- `IsDriveRootPath(P)`：末尾の区切りを除いたものが空でなく、`ExtractFileDrive(P)` と同じなら `True`（`C:\`、`\\server\share`）。

定数：

| 名前 | 値 | 中身 |
|---|---|---|
| `CQuickAccessParse` | 'shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}' | クイックアクセス |
| `CCSIDL_NETWORK` | $0012 | ネットワーク |
| `MaxPendingPaths` | 200 | 更新候補がこれを超えたら全体を更新する |
| `CWM_XBUTTONUP`・`CWM_APPCOMMAND` | $020C・$0319 | マウスの戻る・進むボタン |

## 4. フィールド

| 名前 | 型 | 初期値 | 中身 |
|---|---|---|---|
| `FIsRefreshing` | `Boolean` | `False` | 更新中（多重に実行しない） |
| `FNotifyID` | `ULONG` | 0 | 変更通知の登録 ID（PC 配下全体を1件） |
| `FNotifyTimer` | `TTimer` | 300ms・止めておく | 通知の間引き |
| `FPendingPaths` | `TStringList` | 空（大文字小文字を区別しない、並べる、重複は無視） | 更新が要るかもしれないフォルダー |
| `FRefreshAll` | `Boolean` | `False` | ツリー全体（ドライブ一覧を含む）を更新する |
| `FDragArmed`・`FDragStartPt`・`FDragNodePath`・`FDragButton` | | | ドラッグの準備（押したノードのパスとボタン） |
| `FDropHilite` | `TTreeNode` | nil | ドロップ先として枠を描くノード |
| `FHoverNode`・`FHoverSince` | | | 自動で開くための、乗っているノードと乗り始めた時刻 |
| `FDragTimer` | `TTimer` | 80ms・止めておく | ドラッグ中の自動スクロール・自動で開く |
| `FOleTarget` | `TCShellOleDropTarget` | nil | OLE のドロップ先 |
| `FOleDragOver` | `Boolean` | `False` | ほかからのドラッグが上にある |
| `FInXButton` | `Boolean` | `False` | `WM_XBUTTONUP` の処理中 |
| `FExtraItemMenu`・`FExtraBackgroundMenu` | `TPopupMenu` | nil | 右クリックメニューに足す項目 |
| `FExtraMenuPosition` | `TCExtraMenuPosition` | `empBottom` | 足す位置 |
| `FShowQuickAccess`・`FShowOneDrive`・`FShowNetwork`・`FShowLinux` | `Boolean` | `True` | 最上位の表示 |
| `FNetworkFolders` | `TStringList` | 空。`OnChange := NetworkFoldersChanged` | ネットワークの下に並べる共有フォルダー |
| `FSysSmallImages` | `HIMAGELIST` | 0 | システムの小アイコンの一覧（近道・グループのアイコンを描く） |

## 5. 宣言

```pascal
public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  function IsDriveNode(Node: TTreeNode): Boolean;
  procedure DeleteSelectedFolder(APermanent: Boolean = False);
  procedure CopySelectedFolder;
  procedure CutSelectedFolder;
  procedure PasteToSelectedFolder;
  procedure RenameSelectedFolder;
  function GetPathFromNode(ANode: TTreeNode): string; reintroduce;
  function IsSpecialNode(Node: TTreeNode): Boolean;
  function IsGroupNode(Node: TTreeNode): Boolean;
  function IsShortcutNode(Node: TTreeNode): Boolean;
  property Path: string read GetCPath write SetCPath;
published
  property ShowQuickAccess: Boolean read FShowQuickAccess write SetShowQuickAccess default True;
  property ShowOneDrive: Boolean read FShowOneDrive write SetShowOneDrive default True;
  property ShowNetwork: Boolean read FShowNetwork write SetShowNetwork default True;
  property ShowLinux: Boolean read FShowLinux write SetShowLinux default True;
  property NetworkFolders: TStrings read GetNetworkFolders write SetNetworkFolders;
  property ExtraItemMenu: TPopupMenu read FExtraItemMenu write SetExtraItemMenu;
  property ExtraBackgroundMenu: TPopupMenu read FExtraBackgroundMenu write SetExtraBackgroundMenu;
  property ExtraMenuPosition: TCExtraMenuPosition read FExtraMenuPosition write FExtraMenuPosition default empBottom;
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
  function CanEdit(Node: TTreeNode): Boolean; override;
  procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
  procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  procedure Paint; override;
```

## 6. 作る・壊す

Create：

1. `FileSortType := fstCustom`、`OnSortCompare := CompareFolderNames`（自然順）。
2. 4章の初期値。
3. `ReadOnly := False`（名前の変更をさせる）、`DragMode := dmManual`（ドラッグは自分で始める）、`ShowButtons := True`、`ShowLines := False`、`ShowRoot := True`、`RightClickSelect := True`、`OnEdited := InternalOnEdited`。
4. タイマー2つを作る。

Destroy：タイマーを止める → `ShellDragAbandon(Self)` → OLE のドロップ先の登録を外す → `UnregisterFolderNotify` → `Application.RemoveAsyncCalls(Self)`（後から `DoAsyncRename` が動かないように） → `FPendingPaths` を解放 → `inherited` → `FNetworkFolders` を解放。

CreateWnd：`inherited` のあと、設計時でなければ、`Root := ''`（PC 直下の全ドライブ）、`BuildTopLevel`、`RegisterFolderNotify`、`OleDropRegister(Handle, OleResolveDrop, OleDropLeave, OleDropped)`。

DestroyWnd：`UnregisterFolderNotify`、`OleDropRevoke`、`inherited`。

`DoCreateNodeClass`：`inherited` のあと `NewNodeClass := TCTreeNode`。

## 7. 処理

### 7.1 最上位を作る（BuildTopLevel）

設計時は何もしない。`Items.BeginUpdate` の間に：

1. `PopulateWithBaseFiles`（基底の処理でドライブが最上位に並ぶ）。並んだドライブのノードを覚える。
2. クイックアクセス（`ShowQuickAccess`）：`GetQuickAccessFolders` で名前とパスを取り、1つ以上あれば最初のドライブの前に「クイックアクセス」（`nkGroup`・`gkQuickAccess`、`HasChildren := True`）を入れ、その子に近道を足す。
3. OneDrive（`ShowOneDrive`）：`GetOneDrivePath` が空でなければ、最初のドライブの前に「OneDrive」（`nkShortcut`）を入れる。
4. PC：ドライブがあれば「PC」（`nkGroup`・`gkPC`）を末尾に足し、ドライブのノードをすべてその子に移す（`MoveTo(G, naAddChild)`）。常に出す。
5. ネットワーク（`ShowNetwork` で `NetworkFolders` が1つ以上）：「ネットワーク」（`gkNetwork`）を足し、空でない行ごとに、末尾の区切りを除いた文字で近道を足す。
6. Linux（`ShowLinux`）：`GetWslDistros` で名前があれば「Linux」（`gkLinux`）を足し、名前ごとに '\\wsl.localhost\' ＋ 名前 の近道を足す。
7. クイックアクセスと PC は開いておく（エクスプローラーと同じ）。

| 手続き | 処理 |
|---|---|
| `GetQuickAccessFolders(名前, パス)` | `CreateOleObject('Shell.Application').NameSpace(CQuickAccessParse).Items` を順に見て、フォルダーで、パスが空でなく実在するもの（ZIP・仮想フォルダーは除く）だけ足す。例外なら何も足さない（クイックアクセスを出さない） |
| `GetOneDrivePath` | 環境変数 `OneDrive`、なければ `OneDriveConsumer`。存在しなければ '' |
| `GetWslDistros(名前)` | `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss` の子キーの `DistributionName`。WSL を起動しないよう、存在は確かめない。例外なら何も足さない |
| `AddGroupNode(文字, グループ)` | 末尾に足し、`InitSpecial(nkGroup, グループ, '')`、`HasChildren := True` |
| `AddShortcutNode(親, 文字, パス)` | 親の子（親が nil なら最上位）に足し、`InitSpecial(nkShortcut, gkNone, パス)`、`HasChildren := True` |
| `RebuildTopLevel` | 設計時・読み込み中・壊している途中・ハンドルなしなら何もしない。`RefreshKeepingState(nil, True)` |
| `SetShowQuickAccess`・`SetShowOneDrive`・`SetShowNetwork`・`SetShowLinux` | 変わったら入れて `RebuildTopLevel` |
| `SetNetworkFolders` | `Assign`（`OnChange` で作り直す） |
| `NetworkFoldersChanged` | `ShowNetwork` なら `RebuildTopLevel` |

### 7.2 ノードの種類とパス

| 手続き | 処理 |
|---|---|
| `IsSpecialNode` | `TCTreeNode` で `Kind <> nkNormal` |
| `IsGroupNode`・`IsShortcutNode` | `Kind = nkGroup`・`nkShortcut` |
| `IsDriveNode` | `IsDriveRootPath(GetPathFromNode(Node))` |
| `GetPathFromNode` | nil・グループは ''。近道は `RealPath` ＋ 区切り。ほかは `inherited` |
| `NodeKey` | 開いている状態を覚えるためのキー。グループは '#group:' ＋ 文字、ほかはパス（末尾の区切りなし） |
| `GetPathRootNodes(一覧)` | パスの起点（ドライブ・近道）を集める。最上位とグループの子を見て、近道は後回しにし、ドライブが先 |
| `PathRootOf(N)` | グループでなければ、親がグループか nil になるまでたどった起点 |
| `FindNodeUnder(起点, パス)` | 起点のパスが目的と同じなら起点。目的が起点の配下でなければ nil。子を見て、同じなら返し、前方が一致する子なら下へ、ほかは次の兄弟へ（読み込まれていない階層は見つからない） |
| `FindNodesForPath(パス, 結果)` | すべての起点で `FindNodeUnder` し、見つかったものを重ならないように集める（ドライブの下と近道の下の両方にあることがある） |
| `FindNodeForPath(パス, 優先する起点)` | 1回目は優先する起点だけ、2回目はすべての起点（ドライブが先）で `FindNodeUnder`。最初に見つかったもの |
| `GetCPath`（`Path` の読み） | `GetPathFromNode(Selected)` |
| `SetCPath`（`Path` の書き） | 空なら何もしない。`ExpandFileName` して末尾の区切りを除き、存在しなければ何もしない。起点を選ぶ（目的と同じか配下で、近道でないドライブがあればそれ。なければ一致する最長の近道）。起点から、目的と同じか前方が一致する子を開いてたどる（見つからなければ、たどれた所まで）。`Selected := ノード`、`MakeVisible` |

### 7.3 開く・印・選択

| 手続き | 処理 |
|---|---|
| `CanExpand(N)` | グループ：子があれば `True`（作ったまま使い、読み直さない）。近道：子を消し、`PopulateTreeNodeWithFiles(N, RealPath ＋ 区切り)`（接続できない共有フォルダーなどの例外は無視）。子がなければ `HasChildren := False`。ほかは `inherited` |
| `NodeHasChildren(N)` | グループ：子があれば `True`。近道：`True`（開くまで中を調べない。共有フォルダー・WSL で待たされないため）。ほかは `inherited` |
| `DoSelectionChanged` | 選んだのが近道なら、`ShellListView` が `TCListView` なら `NavigateTo(RealPath)`、ほかの一覧なら存在すれば `Root := RealPath`（例外は無視）。グループなら一覧は変えない。どちらも `OnSelectionChanged` を呼んで終わる（基底の処理はしない）。普通のノードは `inherited` |
| `CanEdit(N)` | `inherited` で、ドライブ・近道・グループでなければ `True` |
| `CompareFolderNames(A, B)` | 名前を `StrCmpLogicalW`（自然順） |
| `FolderHasSubFolders(P)` | `FindFirstFileW`（`ShellLongPathW`）で、'.'・'..' 以外のフォルダーが1つでもあれば `True`。隠しフォルダーは `ObjectTypes` に `otHidden` がなければ数えない |

### 7.4 アイコン（近道・グループ）

`DrawBuiltInIcon`：近道・グループでなければ `inherited`。ほかは `SpecialIconIndex` の番号を、`FSysSmallImages` から `ImageList_Draw(…, ILD_TRANSPARENT)` で、枠の縦の中央に描く。大きさは `GetBuiltinIconSize` を返す。

`SpecialIconIndex(N)`：読み込み済みならその番号。ほかは：

| ノード | 取り方 |
|---|---|
| 近道で '\\' で始まる（共有フォルダー・WSL） | `SHGetFileInfoW(パス, FILE_ATTRIBUTE_DIRECTORY, SHGFI_SYSICONINDEX or SHGFI_SMALLICON or SHGFI_USEFILEATTRIBUTES)`（ディスクに触れない一般のフォルダーのアイコン） |
| ほかの近道 | `SHGetFileInfoW(パス, 0, SHGFI_SYSICONINDEX or SHGFI_SMALLICON)` |
| PC | `SHGetSpecialFolderLocation(CSIDL_DRIVES)` の PIDL で `SHGFI_PIDL` |
| ネットワーク | `CSIDL_NETWORK`（$0012）の PIDL |
| クイックアクセス | `SHParseDisplayName(CQuickAccessParse)` の PIDL |
| Linux など | 'folder' を `FILE_ATTRIBUTE_DIRECTORY`・`SHGFI_USEFILEATTRIBUTES` で（一般のフォルダーのアイコン） |

戻り値（イメージリストのハンドル）が 0 でなければ、`FSysSmallImages` が 0 のときに入れ、`iIcon` を番号にする。PIDL は解放する。番号と `IconLoaded := True` を覚える。

### 7.5 変更通知

`RegisterFolderNotify`：前の登録を外す。設計時・ハンドルなしなら終わる。PC（`CCSIDL_DRIVES`）配下全体を、サブフォルダーも含めて1件で、`MKDIR, RMDIR, RENAMEFOLDER, UPDATEDIR, DRIVEEVENTS` で登録する（関係のないパスは受けたほうで捨てる）。

`HandleShellNotify`：

1. `ShellNotifyDecode`。壊している途中なら終わる。
2. ドライブのイベント（`DRIVEEVENTS`）なら `FRefreshAll := True`。
3. ほか（`FRefreshAll` でなければ）：パス1・パス2の親を `FPendingPaths` に足す（子の増減が起きる場所）。`UPDATEDIR` なら、パス1自身も足す。200 を超えたら空にして `FRefreshAll := True`。
4. `FNotifyTimer` を掛け直す。

`NotifyTimerTick`：名前の編集中・LCL のドラッグ中・更新中・アプリ内ドラッグ中・ほかからのドラッグが上にあるときは保留（ドロップ先として強調しているノードが作り直されないように）。タイマーを止め、`FRefreshAll` と `FPendingPaths` を取り出して空にし、どちらかあれば `RefreshKeepingState(候補, 全体)`。

### 7.6 状態を保った更新（RefreshKeepingState）

更新中・壊している途中なら何もしない。`FIsRefreshing := True`。

1. 選んでいるノードのパスと、その起点のパスを覚える。全ノードを見て、開いているもののキー（`NodeKey`）を覚える。
2. `Items.BeginUpdate` の間に：
   - 全体なら `BuildTopLevel` して、最上位から、覚えたキーのノードを開き直す（`RestoreExpanded`：キーがなければそこで止め、あれば開いて子へ）。
   - 候補なら、各パスについて `FindNodesForPath`（前のノードの更新で作り直されていることがあるので毎回探す。両方にあれば両方）。閉じているノードは作り直さず、子があれば消して、`HasChildren := FolderHasSubFolders`（次に開いたときに最新で読み込ませる）。開いているノードは `Refresh(ノード)`、開き直し、子を `RestoreExpanded`。
   - 選択を戻す：選んでいたパスと今の選択が違えば、そのパスから親へたどり、`FindNodeForPath(パス, 起点)` で見つかった最初のノードを選ぶ（消えていたら、残っている親）。
3. 例外は握りつぶす（次の通知・F5 でやり直される）。`FIsRefreshing := False`。

### 7.7 F5（DoRefreshVisibleNodes）

更新中・壊している途中なら何もしない。選択と起点、開いているノードのキーを覚え、`Items.BeginUpdate` の間に、最上位から `RefreshAndRestore`（キーがあれば `Refresh` して開き直し、新しい子へ。閉じていたノードは触らない）。覚えた選択のパスのノードがあれば選び直す。例外は握りつぶす。

### 7.8 戻る・進む（WndProc）

`XButtonDirection` は TCListView と同じ判定（TCListView 設計書 7.4）。

- `WM_APPCOMMAND`：`FInXButton` でなければ `TreeHistoryGo(向き)`。`Result := 1`。
- `WM_XBUTTONUP`：`FInXButton := True` で `inherited`、そのあと `TreeHistoryGo(向き)`、`Result := 1`。
- `TreeHistoryGo`：`ShellListView` が `TCListView` なら、その `GoBack`・`GoForward`。

WndProc はほかに、`WM_CSHELLNOTIFY` で `HandleShellNotify` を受ける。

### 7.9 キー（KeyDown）

| キー | 処理 |
|---|---|
| Ctrl+C・Ctrl+X・Ctrl+V | `CopySelectedFolder`・`CutSelectedFolder`・`PasteToSelectedFolder`、`Key := 0`、`inherited`、終わる |
| F2 | `RenameSelectedFolder`、`Key := 0` |
| Delete | `DeleteSelectedFolder(Shift があるか)`、`Key := 0` |
| F5 | `DoRefreshVisibleNodes`、`Key := 0`（ネットワークなど通知が届かないとき） |

最後に `inherited KeyDown`。

### 7.10 フォルダーの操作

| 手続き | 処理 |
|---|---|
| `CopySelectedFolder` | 選んでいるノードのパスがあれば、`ShellInvokeVerbOnItems(Handle, [パス], 'copy')`（ドライブは区切りを付けて "C:\" にする） |
| `CutSelectedFolder` | ドライブ・近道・グループは何もしない。`ShellInvokeVerbOnItems(…, 'cut')` |
| `PasteToSelectedFolder` | パスがあれば `ShellInvokeVerbOnFolder(Handle, パス, 'paste')` |
| `DeleteSelectedFolder(完全)` | ドライブ・近道・グループは何もしない。`PerformFileOperation(FO_DELETE, パス, '', not 完全)` |
| `PerformFileOperation` | `SHFILEOPSTRUCTW`（W 版）。元・先は末尾に #0#0。ごみ箱に入れるときだけ `FOF_ALLOWUNDO`。完全削除でも確認は出る |
| `RenameSelectedFolder` | ドライブ・近道・グループでなければ `Selected.EditText` |
| `InternalOnEdited(N, S)` | 空なら終わる。ドライブなら元に戻す。`ContainsInvalidChar` なら 'フォルダ名に以下の文字は使用できません:' ＋ 改行 ＋ '\ / : * ? " < > \|' を出して元に戻す。元のパスはノードの実際のパス、新しいパスは親 ＋ `S`。違えば `TRenameInfo` を `New` して `QueueAsyncCall(DoAsyncRename)` |
| `DoAsyncRename` | 壊している途中でなければ `ShellRenameItem(Handle, 元, 新しい名前)`。失敗したら（シェルが理由を出す）、ノードの表示を戻すため親を `FPendingPaths` に足してタイマーを掛け直す。最後に `Dispose` |

表示の更新は変更通知に任せる。

### 7.11 右クリックメニュー

`DoContextPopup`：マウスの下にノードがあれば、選んで `DisplayShellContextMenu(パス, 位置)`。なければ `DisplayBackgroundMenu(位置)`。`Handled := True`（部品の `PopupMenu` は使わない）。

`DisplayShellContextMenu(P, 位置)`：

1. P が空なら終わる。親のパス（なければ P）の `IShellFolder` を取り、P の子の PIDL で `GetUIObjectOf(IID_IContextMenu)`。
2. `QueryContextMenu(メニュー, 0, 1, $7FFF, CMF_NORMAL)`、`ExtraMenuInsert(…, ExtraItemMenu, …)`、`TrackShellContextMenu`。
3. 独自の項目なら `ExtraMenuClick`。ほかでコマンド名が 'rename' なら `RenameSelectedFolder`（シェルの名前の変更はこの画面では動かないため）。ほかは `ShellInvokeMenuCommand(…, 親のパス)`（作業フォルダーとして親を渡す）。

`DisplayBackgroundMenu`：`ExtraBackgroundMenu` がなければ何もしない。空のメニューに `ExtraMenuInsert` し、0 なら出さない。`TrackShellContextMenu(…, nil, …)`、`ExtraMenuClick`。

`SetExtraItemMenu`・`SetExtraBackgroundMenu`：解放通知を付け替える。`Notification`：解放されたら nil にする。

### 7.12 ドラッグ＆ドロップ

送り側：

1. `MouseDown`：`inherited` のあと、`FDragArmed := False`。左・右ボタンで編集中でなく、ノードがドライブ・近道・グループでなく、パスがあれば、`FDragArmed := True`、パス・ボタン・位置を覚える。
2. `MouseMove`：`FDragArmed` でボタンが離されていればやめる。`SM_CXDRAG`・`SM_CYDRAG` 以上動いたら `FDragArmed := False`、`ShellDragBegin(Self, [パス])`、`ShellDoDragDrop(Handle, [パス], False, Effect)`（既定のドラッグ画像）、`ShellDragEnd`、`ReleaseCapture`。対象は押したフォルダー1つ。
3. `MouseUp`：`FDragArmed := False`、`inherited`。

受け側（`OleResolveDrop`）：

1. ハンドルなしなら ''。`FOleDragOver := True`、`FDragTimer` を動かす。
2. マウスの下のノードのパス（グループは ''）がドロップ先。
3. アプリ内から始めたドラッグで `ShellDecideDropEffect(…) = cdeNone` なら ''。
4. 先があればそのノード、なければ nil を `SetDropHilite`。

| 手続き | 処理 |
|---|---|
| `OleDropLeave` | `FOleDragOver := False`、タイマーを止め、`FHoverNode := nil`、枠を消す |
| `OleDropped` | 何もしない（表示の更新は変更通知に任せる） |
| `SetDropHilite` | 変わったら入れて `Invalidate` |
| `Paint` | `inherited` のあと、`FDropHilite` が見えていれば `DisplayRect(True)` に `clHighlight` の2pxの枠 |
| `DragTimerTick` | ドラッグ中でなければ止めて枠を消す。マウスが外（上下は 20px の余裕）なら止める。上端・下端から 20px 以内なら `WM_VSCROLL`（1行）。同じノードの上に 700ms 留まり、閉じていて子があれば開く |

## 8. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| クイックアクセス・OneDrive・Linux が出ない | `GetQuickAccessFolders`・`GetOneDrivePath`・`GetWslDistros`（7.1） |
| 共有フォルダー・WSL で待たされる | `NodeHasChildren`・`SpecialIconIndex` でディスクに触れていないか（7.3、7.4） |
| 更新で開いている状態・選択が消える | `RefreshKeepingState`・`NodeKey`（7.6、7.2） |
| `Path` に入れても選ばれない | `SetCPath` の起点の選び方、隠しフォルダー（7.2） |
| 名前の変更が戻る | `DoAsyncRename` の失敗（7.10） |
| エクスプローラーからドロップできない | `CreateWnd` の `OleDropRegister`、`OleResolveDrop`（6章、7.12） |
| 戻る・進むボタンが効かない | `ShellListView` に TCListView をつないでいるか（7.8） |
| D&D の動きを追いたい | TCListView 設計書 11章の `ShellDragTrace` |
