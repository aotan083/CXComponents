# TCListView 設計書

作者: aotan083
日付: 2026-10-31
版: 1.1

---

## 1. 目的

TShellListView（LCL）を元に、Windows のエクスプローラーの右側と同じように使えるファイル一覧を作る。フォームに置くだけで、開く・コピー・移動・削除・名前の変更・新規作成・ドラッグ＆ドロップ・右クリックメニュー・自動更新・戻る／進むが動くようにする。

- ファイルの操作（コピー・移動・削除・名前の変更・貼り付け・ドロップ）は、できるだけシェル（Windows）に任せる。上書きの確認や進み具合の表示もシェルが行う。
- 表示の更新は、フォルダーの変更通知に任せる（操作のあとに自分で読み直さない）。
- 状態の変化（フォルダー・選択）は、アイドル時にまとめて1回ずつ知らせる。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `CListView.pas` | cx（実行時） | `TCItemInfo`、`TCListView`、`BuildRenamedPath` |
| `CShellNotify.pas` | cx（実行時） | シェルの変更通知（9章） |
| `CShellMenu.pas` | cx（実行時） | シェルのコマンド実行・右クリックメニュー・独自項目・名前の変更（10章） |
| `CShellDragDrop.pas` | cx（実行時） | アプリ内ドラッグの情報・ドロップの禁止判定・ログ（11章） |
| `CShellOleDrop.pas` | cx（実行時） | OLE のドロップの受け側（12章） |
| `CShellOleDrag.pas` | cx（実行時） | OLE のドラッグの送り側（13章） |
| `uCXReg.pas` | cxdsgn（設計時） | パレット [CX] への登録（`RegisterComponents('CX', [TCTreeView, TCListView, ...])`） |
| `cx_icons.lrs` | cxdsgn（設計時） | アイコン（`TCListView`・`TCListView_150`・`TCListView_200`） |

- 9〜13章の共通部品は TCTreeView も使う。TCTreeView の設計書はここを参照する。
- `CListView` の uses：`Classes, SysUtils, Controls, ComCtrls, ShellCtrls, Windows, ActiveX, ShlObj, ShellAPI, Messages, Graphics, Dialogs, Forms, Clipbrd, LMessages, LazUTF8, ExtCtrls, CommCtrl, Menus, CShellNotify, CShellMenu, CShellDragDrop, CShellOleDrop, CShellOleDrag`
- 自然順の比較は `shlwapi.dll` の `StrCmpLogicalW` を external で宣言して使う。
- `CListView` に initialization・finalization はない。

## 3. 型

```pascal
TCItemInfo = class
public
  IsDir: Boolean;
  DateStr: string;   // 更新日時（YYYY/MM/DD HH:NN）
end;

TCListView = class(TShellListView)

function BuildRenamedPath(const AOldPath, ADisplayName, ANewName: string): string;
```

`BuildRenamedPath`：`OldPath`（末尾の区切りを除く）のフォルダー ＋ `ANewName`。フォルダーならそのまま。ファイルで、拡張子があり、表示名が実ファイル名と違い、表示名が拡張子なしの実ファイル名と同じなら、元の拡張子を足す（拡張子を表示しない設定のとき）。

## 4. フィールド

| 名前 | 型 | 初期値 | 中身 |
|---|---|---|---|
| `FOnFolderChanged`・`FOnSelectionChanged` | `TNotifyEvent` | nil | イベント |
| `FLastRoot` | `string` | '' | 前に知らせたときの `Root` |
| `FSelectionDirty` | `Boolean` | `False` | 選択の変化を知らせる待ち |
| `FSortColumn` | `Integer` | 2 | 並べ替えの列（0 名前・1 サイズ・2 種類・3 更新日時） |
| `FSortAscending` | `Boolean` | `True` | 昇順 |
| `FInResize` | `Boolean` | `False` | 列幅の調整中 |
| `FColumnResizePending` | `Boolean` | `False` | 列幅の調整を予約済み |
| `FSortPending` | `Boolean` | `False` | 並べ替えを予約済み |
| `FLastColWidths` | `array[0..3] of Integer` | -1 | 自動調整で最後に設定した列幅（手で変えたかの判定用） |
| `FUserSizedColumns` | `Boolean` | `False` | ユーザーが列幅を手で変えた |
| `FNotifyRootID`・`FNotifyParentID` | `ULONG` | 0 | 変更通知の登録 ID（`Root` 直下・`Root` の親） |
| `FNotifyRoot` | `string` | '' | 通知を登録している `Root` |
| `FNotifyTimer` | `TTimer` | 300ms・止めておく | 通知の間引き |
| `FSelectNewItems` | `Boolean` | `False` | 次の読み直しで、新しく現れた項目を選ぶ |
| `FDragArmed` | `Boolean` | `False` | 項目の上でボタンが押された |
| `FDragButton` | `TMouseButton` | | ドラッグを始めたボタン |
| `FDragStartPt` | `TPoint` | | 押した位置 |
| `FDropHilite` | `TListItem` | nil | ドロップ先として枠を描く項目 |
| `FDragTimer` | `TTimer` | 80ms・止めておく | ドラッグ中の自動スクロール |
| `FOleTarget` | `TCShellOleDropTarget` | nil | OLE のドロップ先 |
| `FOleDragOver` | `Boolean` | `False` | ほかからのドラッグが上にある |
| `FPendingChanges` | `TStringList` | 空 | 行単位で反映する変更（文字列 = パス1 ＋ #1 ＋ パス2、Objects = イベント） |
| `FNeedFullRefresh` | `Boolean` | `False` | 行単位で反映できない変更があった |
| `FItemInfo` | `TStringList` | 空（大文字小文字を区別しない、重複は無視、Objects を持つ） | 名前 → `TCItemInfo` |
| `FItemInfoRoot` | `string` | '' | `FItemInfo` を作ったときの `Root` |
| `FHistory` | `TStringList` | 空 | フォルダーの履歴（古い順） |
| `FHistIndex` | `Integer` | -1 | 履歴の今の位置 |
| `FHistSkip` | `string` | '' | 戻る・進むで移動中のフォルダー（履歴に足さない） |
| `FMaxHistory` | `Integer` | 20 | 履歴の上限 |
| `FInXButton` | `Boolean` | `False` | `WM_XBUTTONUP` の処理中 |
| `FExtraItemMenu`・`FExtraBackgroundMenu` | `TPopupMenu` | nil | 右クリックメニューに足す項目 |
| `FExtraMenuPosition` | `TCExtraMenuPosition` | `empBottom` | 足す位置 |
| `FLastViewStyle` | `TViewStyle` | `vsReport` | 前に確かめた表示形式 |

## 5. 宣言

```pascal
public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  function NavigateTo(const APath: string): Boolean;
  function NavigateUp: Boolean;
  procedure DeleteSelectedFiles(APermanent: Boolean = False);
  procedure CopySelected;
  procedure CutSelected;
  procedure PasteToRoot;
  procedure SelectAllItems;
  procedure RenameSelectedFile;
  function GetSelectedFilePath: string;
  procedure GetSelectedPaths(AList: TStrings);
  property AutoFitNameColumn: Boolean read GetAutoFitNameColumn write SetAutoFitNameColumn;
  procedure SelectNewItemsOnNextRefresh;
  function GoBack: Boolean;
  function GoForward: Boolean;
  function CanGoBack: Boolean;
  function CanGoForward: Boolean;
  procedure ClearHistory;
  procedure SetView(AStyle: TViewStyle);
  procedure SortBy(AColumn: Integer; AAscending: Boolean);
  property SortColumn: Integer read FSortColumn;
  property SortAscending: Boolean read FSortAscending;
  property MaxHistory: Integer read FMaxHistory write SetMaxHistory;
published
  property ExtraItemMenu: TPopupMenu read FExtraItemMenu write SetExtraItemMenu;
  property ExtraBackgroundMenu: TPopupMenu read FExtraBackgroundMenu write SetExtraBackgroundMenu;
  property ExtraMenuPosition: TCExtraMenuPosition read FExtraMenuPosition write FExtraMenuPosition default empBottom;
  property OnFolderChanged: TNotifyEvent read FOnFolderChanged write FOnFolderChanged;
  property OnSelectionChanged: TNotifyEvent read FOnSelectionChanged write FOnSelectionChanged;
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
```

## 6. 作る・壊す

Create：

1. `ReadOnly := True`、`DragMode := dmManual`（ドラッグは自分で始める）、`ViewStyle := vsReport`、`MultiSelect := True`。
2. `AutoSizeColumns := False`（基底の列幅の自動調整を止める。基底は Resize のたびにスクロールバー込みの幅で列幅を設定し直すため、縦スクロールバーがあるときに横スクロールバーが出入りして Resize が循環し、自前の調整とも書き換え合ってちらつく）。
3. `ObjectTypes := [otFolders, otNonFolders]`、`OnEdited := InternalOnEdited`、`OnColumnClick := DoColumnClick`、`OnAddItem := DoAddItemHandler`。
4. `FSortColumn := 2`、`FSortAscending := True`、`FLastViewStyle := vsReport`、`IconOptions.AutoArrange := True`。
5. 列：0〜2 の見出しを「名前」「サイズ」「種類」にし、4番目「更新日時」（幅 140、左寄せ）を足す。
6. 4章のフィールドを作り、初期値を入れる。
7. `Application.AddOnIdleHandler(InternalAppIdle)`（`Root` の書き込みは基底で仮想化されていないので、変化はアイドル時に見つける）。

Destroy：タイマーを止める → `ShellDragAbandon(Self)` → OLE のドロップ先の登録を外す → `UnregisterFolderNotify` → `Application.RemoveAsyncCalls(Self)` → `RemoveOnIdleHandler` → `inherited` → `FItemInfo`・`FPendingChanges`・`FHistory` を解放。

CreateWnd：`inherited` のあと、`LVM_SETEXTENDEDLISTVIEWSTYLE` で `LVS_EX_DOUBLEBUFFER`（$00010000）を有効にする（LCL の `DoubleBuffered` ではなく、Windows のリストビュー自身の仕組みを使う）。`RegisterFolderNotify`。設計時でなければ `OleDropRegister(Handle, OleResolveDrop, OleDropLeave, OleDropped)`。

DestroyWnd：`UnregisterFolderNotify`、`OleDropRevoke`、`inherited`。

## 7. 処理

### 7.1 状態の変化を知らせる（CheckStateChanged）

`InternalAppIdle` から呼ぶ（`Done` は変えない）。設計時・壊している途中は何もしない。

1. `Root` が `FLastRoot` と違う（末尾の区切りは無視）：`FLastRoot := Root`、`RecordHistory(Root)`、`FSelectionDirty := True`、`FNotifyTimer` を止めて `RegisterFolderNotify`（監視を新しいフォルダーへ付け替える）、`OnFolderChanged`。
2. `ViewStyle` が `FLastViewStyle` と違う：覚え直し、`QueueAsyncCall(DoAsyncRefresh)`（アイコンの大きさが変わるため作り直す）。詳細表示になったら列幅の調整も予約する。
3. `FSelectionDirty` なら戻して `OnSelectionChanged`。

- `DoSelectItem`：`inherited` のあと `FSelectionDirty := True`（複数選択では項目ごとに呼ばれるので、フラグだけ立てる）。

### 7.2 移動

| 手続き | 処理 |
|---|---|
| `NavigateTo(P)` | `P` が空・存在しない・今と同じなら `False`。`Root := P`、`True`（イベントは 7.1） |
| `NavigateUp` | `Root` の親。ドライブのルートなら `False`。`NavigateTo(親)` |
| `NavigateToExistingParent` | `Root` から親へたどり、最初に存在するフォルダーへ `NavigateTo`。たどれなければ何もしない |

### 7.3 履歴

| 手続き | 処理 |
|---|---|
| `RecordHistory(P)` | 末尾の区切りを除く。空なら終わる。`FHistSkip` と同じなら空にして終わる（戻る・進むで移動した）。今の位置と同じなら終わる。今の位置より後ろを捨て、末尾に足し、上限を超えたら先頭から消し、`FHistIndex` を末尾にする |
| `HistoryGo(d)` | `i := FHistIndex + d` から `d` の向きに探す。存在して今と違うフォルダーなら、`FHistIndex := i`、`FHistSkip := そのフォルダー`、`Root := そのフォルダー`、`True`。存在しない・今と同じものは履歴から消して次を探す（戻る向きなら `FHistIndex` も 1 減らす） |
| `GoBack`・`GoForward` | `HistoryGo(-1)`・`HistoryGo(+1)` |
| `CanGoBack` | `FHistIndex > 0` |
| `CanGoForward` | `0 <= FHistIndex < FHistory.Count - 1` |
| `ClearHistory` | 空にして `RecordHistory(Root)` |
| `SetMaxHistory(v)` | 2 未満なら 2。超えた分を先頭から消し、`FHistIndex` を合わせる |

### 7.4 マウスの戻る・進むボタン（WndProc）

`XButtonDirection(Msg, WParam, LParam)`：`WM_XBUTTONUP`（$020C）なら、WParam の上位ワードが 1 か `MK_XBUTTON1`（$20）で -1、2 か `MK_XBUTTON2`（$40）で +1。`WM_APPCOMMAND`（$0319）なら、LParam の上位ワード `and $0FFF` が `APPCOMMAND_BROWSER_BACKWARD`（1）で -1、`APPCOMMAND_BROWSER_FORWARD`（2）で +1。

- `WM_APPCOMMAND`：`FInXButton` でなければ `GoBack`・`GoForward`。`Result := 1`。
- `WM_XBUTTONUP`：`FInXButton := True` で `inherited`（既定の処理が `WM_APPCOMMAND` を送るので、二重にならないように）、そのあと `GoBack`・`GoForward`、`Result := 1`。

WndProc はほかに、`CM_CSTARTDRAG`（`WM_USER + $5A2`）で `StartOleDrag`、`WM_PAINT` で `FDropHilite` があれば `inherited` のあと `DrawDropFrame`、`WM_CSHELLNOTIFY` で `HandleShellNotify` を受ける。

### 7.5 変更通知

`RegisterFolderNotify`：前の登録を外す。設計時・ハンドルなし・`Root` が空か存在しないなら終わる。`FNotifyRoot := Root`。

- `Root` 直下（サブフォルダーは含めない）を、`CREATE, DELETE, MKDIR, RMDIR, RENAMEITEM, RENAMEFOLDER, UPDATEDIR, UPDATEITEM, ATTRIBUTES` で登録。
- `Root` 自体の削除・名前変更は親の変更として届くので、親（ルートでなければ）を `RMDIR, RENAMEFOLDER, DELETE` で登録。

`HandleShellNotify`：

1. `ShellNotifyDecode` でイベントとパス2つを取り出す。壊している途中なら終わる。
2. どちらのパスも「`Root` そのもの」でも「`Root` の直下」でもなければ捨てる。
3. 削除・名前変更・内容更新（`DELETE, RMDIR, RENAMEITEM, RENAMEFOLDER, UPDATEITEM, ATTRIBUTES`）なら、パス1が `Root` そのものなら `FNeedFullRefresh := True`、ほかは `FPendingChanges` に足す。それ以外のイベント（作成など）は `FNeedFullRefresh := True`。
4. `FPendingChanges` が 100 を超えたら `FNeedFullRefresh := True`。
5. `FNotifyTimer` を掛け直す（最後の通知から 300ms 後に1回だけ）。

`NotifyTimerTick`：

1. 名前の編集中・LCL のドラッグ中・アプリ内ドラッグ中・ほかからのドラッグが上にあるときは保留（タイマーは止めず、次の周期で判定し直す）。
2. タイマーを止める。壊している途中なら終わる。
3. `Root` が存在しなくなっていれば、待ちを捨てて `NavigateToExistingParent`。
4. `FNeedFullRefresh` なら、待ちを捨てて `DoAsyncRefresh(0)`。
5. `FPendingChanges` があれば `ApplyPendingChanges`。

`ApplyPendingChanges`（`Items.BeginUpdate` の間に、待ちを順に）：

| イベント | 処理 |
|---|---|
| 削除（`DELETE`・`RMDIR`） | パス1が直下なら、その名前の行を消す（`FDropHilite` なら nil にする） |
| 名前変更、両方とも直下 | 元の名前の行があれば、新しい名前の行がなければ `Caption` を変え、あれば全件読み直し。元の名前の行がなく、新しい名前の行もなければ全件読み直し（あれば名前の編集で変わっているので何もしない） |
| 名前変更、パス1だけ直下 | ほかへ移動（ごみ箱を含む）：その行を消す |
| 名前変更、ほかから来た | 全件読み直し（アイコンなどを作る必要があるため） |
| 内容更新（`UPDATEITEM`・`ATTRIBUTES`） | パス1が直下なら、その行があれば `FindFirstFileW` でサイズを取り直して `SubItems[0]` に入れる（フォルダーは除く）。行がなければ全件読み直し |
| ほか | 全件読み直し |

全件読み直しになったら、そこでやめて `DoAsyncRefresh(0)`。最後まで行けたら `PopulateFileDateTimes`、`ApplySort`、`FSelectionDirty := True`。

- 行の検索 `FindItemByName` は `Caption` を大文字小文字を区別せずに比べる。
- サイズの表記 `FormatShellSize`：1024 未満 '%d bytes'、1MB 未満 '%d kB'、1GB 未満 '%d MB'、ほかは '%.1n GB'（TShellListView と同じ形式）。

### 7.6 読み直し（DoAsyncRefresh）

ハンドルなし・壊している途中なら何もしない。

1. `SelectNew := FSelectNewItems` を取り出して戻す。待ちを捨てる。今の `FSelectionDirty` を覚える。
2. 選択している全項目のパス、フォーカス項目のパス、先頭に見えている項目（`TopItem`）のパスを覚える。`SelectNew` なら、今ある全項目のパスも覚える。
3. `WM_SETREDRAW(False)` の間に、`Root` を空にしてから元に戻して読み直す（`Root` が空なら `Refresh`）。`PopulateFileDateTimes`、`ApplySort`。
4. `SelectNew` なら、選択するパスを「前になかった項目」に置き換え、フォーカスのパスを空にする。
5. 選択するパスの項目を選び、フォーカス項目を戻す（`SelectNew` なら最初に選んだ項目にフォーカス）。
6. `SelectNew` でなく、戻した数が前と同じなら、`FSelectionDirty` を覚えた値に戻す（選択が変わらなければ `OnSelectionChanged` を出さない）。
7. スクロール位置：`SelectNew` ならフォーカス項目を見えるようにする。ほかは、一度末尾を見えるようにしてから前の先頭の項目を見えるようにする（その項目が先頭に来る）。
8. `WM_SETREDRAW(True)`、`RedrawWindow(RDW_INVALIDATE or RDW_ALLCHILDREN or RDW_UPDATENOW)`。

### 7.7 項目の情報と並べ替え

| 手続き | 処理 |
|---|---|
| `RebuildItemInfo` | `FItemInfo` を空にし、`FItemInfoRoot := Root`。`Root` を `FindFirstFileW`（`ShellLongPathW` で長いパスに対応）で1回だけ列挙し、'.'・'..' を除いて、フォルダーか・更新日時（ローカル時刻、'%.4d/%.2d/%.2d %.2d:%.2d'）を `TCItemInfo` に入れる。最後に `Sorted := True`（二分探索できるように） |
| `FindItemInfo(名前)` | `FItemInfoRoot` が今の `Root` と違えば作り直す。名前で探して返す。なければ nil |
| `PopulateFileDateTimes` | `RebuildItemInfo` のあと、全項目の `SubItems` を3つ以上にし、情報があれば、フォルダーで種類が空か 'ファイル フォルダー' なら 'フォルダ' にし、更新日時が違えば入れ直す |
| `CompareItems(A, B)` | フォルダーか（情報がなければ `DirectoryExists`）で、フォルダーを先にする。列 0 は名前を `StrCmpLogicalW`。ほかは `SubItems[列 - 1]` を `StrCmpLogicalW`、同じなら名前で比べる。降順なら符号を逆にする |
| `ApplySort` | `CustomSort(SortCompareProc, Self)`（`SortCompareProc` は `CompareItems` を呼ぶ） |
| `DoAddItemHandler` | `CanAdd := True`。並べ替えを予約していなければ予約する（`QueueAsyncCall(DoAsyncSort)`。項目ごとに並べ替えないように） |
| `DoAsyncSort` | 予約を戻し、`PopulateFileDateTimes`、`ApplySort` |
| `DoColumnClick(列)` | 同じ列なら昇順・降順を反転、違う列ならその列の昇順。`ApplySort` |
| `SortBy(列, 昇順)` | 列が 0〜3 でなければ何もしない。入れて `ApplySort` |
| `SetView(v)` | 同じなら何もしない。`ViewStyle := v`（作り直しは 7.1） |

### 7.8 列幅

- `Resize`：`inherited` のあと、設計時でなく、列が4つ以上で、詳細表示で、予約していなければ `QueueAsyncCall(DoAsyncColumnResize)`（同期で行うと Windows のヘッダーの内部処理と競合し、TSplitter のドラッグ中の大きさの変更を妨げるため。スクロールバーの出入りで Resize が続いても1回にまとめる）。
- `DoAsyncColumnResize`：予約を戻す。調整中・列が4つ未満・壊している途中・詳細表示でない・`FUserSizedColumns` なら何もしない。前回設定した列幅（`FLastColWidths`）と今の列幅が1つでも違えば、ユーザーが手で変えたとして `FUserSizedColumns := True` で終わる。名前の列の幅 = `ClientWidth - (列1 + 列2 + 列3) - 4`（ちょうどにすると横スクロールバーが出て循環するので 4 残す。最小 60）。違うときだけ入れ、4列の幅を `FLastColWidths` に覚える。
- `AutoFitNameColumn` の読みは `not FUserSizedColumns`。`True` を書くと、`FLastColWidths` を -1 に戻し、ハンドルがあれば調整を予約する。

### 7.9 開く・名前の変更・新規作成

| 手続き | 処理 |
|---|---|
| `DblClick` | `OnDblClick` があれば `inherited` だけ。ほかは、フォーカス項目（なければマウスの下の項目）が、フォルダーなら `NavigateTo`、ファイルなら `ShellExecuteW('open')`。戻り値が 32 以下なら 'ファイルを開けませんでした。エラーコード: %d' を出す。最後に `inherited` |
| `RenameSelectedFile` | 選択があれば `ReadOnly := False`、`EditCaption` |
| `InternalOnEdited` | `ReadOnly := True`。空なら終わる。`ContainsInvalidChar` なら 'ファイル名に以下の文字は使用できません:' ＋ 改行 ＋ '\ / : * ? " < > \|' を出して元に戻す。元のパスは項目の実際のパス（表示名ではない）、新しいパスは `BuildRenamedPath`。違えば `TListRenameJob`（元のパス・新しい名前）を作って `QueueAsyncCall(DoAsyncRename)`（名前の編集の終わりの処理と競合しないように） |
| `DoAsyncRename` | 壊している途中でなければ `ShellRenameItem`。失敗したら（シェルが理由を出す）表示を戻すため `DoAsyncRefresh(0)`。成功の表示更新は変更通知に任せる |
| `CreateNewFolderInRoot` | `Root` に '新しいフォルダー'、あれば '新しいフォルダー (2)'、(3)… の空いている名前で `CreateDir`。作ったパスを返す |
| `CreateNewFileInRoot(拡張子)` | 同じく '新規テキスト ドキュメント' ＋ 拡張子（あれば ' (n)'）で空のファイルを作る |
| `FocusAndRenamePath(P)` | `DoAsyncRefresh(0)` で読み直し、`P` の項目を選び、フォーカスし、見えるようにし、`ReadOnly := False`、`EditCaption` |

### 7.10 キー（KeyDown）

| キー | 処理 |
|---|---|
| BackSpace（Shift なし） | `NavigateUp` が `True` なら `Key := 0` |
| Enter（Shift なし） | `DblClick`、`Key := 0` |
| Ctrl+Shift+N | `CreateNewFolderInRoot`、できたら `FocusAndRenamePath`、`Key := 0` |
| Ctrl+Shift+2・4・5・6 | `SetView(vsIcon・vsSmallIcon・vsList・vsReport)`、`Key := 0` |
| Ctrl+A | `SelectAllItems`、`Key := 0` |
| Ctrl+C・Ctrl+X・Ctrl+V | `CopySelected`・`CutSelected`・`PasteToRoot`、`Key := 0` |
| F5 | `QueueAsyncCall(DoAsyncRefresh)`、`Key := 0` |
| F2 | `RenameSelectedFile`、`Key := 0` |
| Delete | `DeleteSelectedFiles(Shift があるか)`、`Key := 0` |

最後に `inherited KeyDown`。

### 7.11 ファイルの操作

| 手続き | 処理 |
|---|---|
| `CopySelected`・`CutSelected` | `GetSelectedPaths` があれば `ShellInvokeVerbOnItems(Handle, 一覧, 'copy'・'cut')` |
| `PasteToRoot` | `Root` があれば `SelectNewItemsOnNextRefresh`、`ShellInvokeVerbOnFolder(Handle, Root, 'paste')`（同じフォルダーへはシェルが「〜 - コピー」にする） |
| `DeleteSelectedFiles(完全)` | 選択の全パスを #0 で区切ってつなぎ、`PerformFileOperation(FO_DELETE, …, '', not 完全)` |
| `PerformFileOperation` | `SHFILEOPSTRUCTW`（W 版。日本語のパスのため）。元・先は末尾に #0#0。`FOF_RENAMEONCOLLISION`、ごみ箱に入れるときは `FOF_ALLOWUNDO` も。完全削除でも確認は出る |
| `SelectAllItems` | 全項目を選ぶ |
| `GetSelectedFilePath` | 選択の先頭の項目のパス（なければ ''） |
| `GetSelectedPaths(L)` | `L` を空にして、選んでいる全項目のパスを入れる |
| `SelectNewItemsOnNextRefresh` | `FSelectNewItems := True` |

表示の更新はすべて変更通知に任せる。

### 7.12 右クリックメニュー

`DoContextPopup`：マウスの下に項目があれば、それを選んで `DisplayShellContextMenu(その項目のパス, 位置, False)`。なければ `DisplayShellContextMenu(Root, 位置, True)`。`Handled := True`（部品の `PopupMenu` は使わない）。

`DisplayShellContextMenu(P, 位置, 何もない所)`：

1. 作業フォルダー `TargetDir`：何もない所なら `P`、項目なら `P` のフォルダー。
2. `TargetDir` の `IShellFolder` を取る。何もない所なら `CreateViewObject(IID_IContextMenu)`、項目なら `GetUIObjectOf(1 項目, IID_IContextMenu)`。
3. `QueryContextMenu(メニュー, 0, 1, $7FFF, CMF_NORMAL)`。戻り値の下位ワード ＋ 1 を `CmdNewFolder`、その次を `CmdNewFile`、その次を `CmdPaste` にする。
4. 何もない所なら、先頭に「新規フォルダー(&N)」「新規テキスト ドキュメント(&T)」「貼り付け(&P)」（クリップボードに `CF_HDROP` がなければ灰色）と区切り線を入れ、さらに先頭に「表示(&V)」「並べ替え(&O)」と区切り線を入れる（`AddViewSortMenus(メニュー, CmdPaste + 1)`）。
5. `ExtraMenuInsert`（何もない所は `ExtraBackgroundMenu`、項目は `ExtraItemMenu`）。
6. `TrackShellContextMenu` で出す。
7. 選ばれたもの：0 なら何もしない。独自の項目なら `ExtraMenuClick`。`CmdNewFolder`・`CmdNewFile` なら作って `FocusAndRenamePath`。`CmdPaste` なら `PasteToRoot`。何もない所で `CmdPaste + 1`〜`+ 10` なら 7.12 の表。ほかはシェルの項目：コマンド名が 'rename' なら `RenameSelectedFile`（シェルの名前の変更はこの画面では動かないため）。'paste' なら `SelectNewItemsOnNextRefresh` してから、`ShellInvokeMenuCommand(…, TargetDir)` で実行。

`AddViewSortMenus` の項目（`ABaseID` からの番号）：

| 番号 | 表示 | 処理 |
|---|---|---|
| +0 | 大アイコン(&R) | `SetView(vsIcon)` |
| +1 | 小アイコン(&N) | `SetView(vsSmallIcon)` |
| +2 | 一覧(&L) | `SetView(vsList)` |
| +3 | 詳細(&D) | `SetView(vsReport)` |
| +4〜+7 | 名前(&N)・サイズ(&S)・種類(&T)・更新日時(&D) | `SortBy(列, 今の昇順・降順)` |
| +8 | 昇順(&A) | `SortBy(今の列, True)` |
| +9 | 降順(&E) | `SortBy(今の列, False)` |

今の表示形式・列・昇順降順にチェックを付ける。「並べ替え」の列と昇順の間に区切り線。

### 7.13 ドラッグ＆ドロップ

送り側：

1. `MouseDown`：`inherited` のあと、左・右ボタンで、編集中でなく、項目の上なら `FDragArmed := True`、ボタンと位置を覚える（右ドラッグはメニュー付きのドロップ）。
2. `MouseMove`：`FDragArmed` で、そのボタンが離されていればやめる。`SM_CXDRAG`・`SM_CYDRAG` 以上動いたら `FDragArmed := False`、`PostMessage(CM_CSTARTDRAG)`（マウスの処理の中で始めると、リストビューがマウスを捕まえたままになり、ドロップ先が切り替わらないため、処理が終わってから始める）。
3. `StartOleDrag`：ハンドルなし・壊している途中、またはボタンがもう離されていれば何もしない。選択のパスがなければ終わる。`ReleaseCapture`、`ShellDragBegin(Self, パス)`、`ShellDoDragDrop(Handle, パス, True, Effect)`（リストビュー自身にドラッグ画像を作らせる）、`ShellDragEnd`、`ReleaseCapture`。コピー・移動はドロップ先が行い、表示の更新は変更通知に任せる。
4. `MouseUp`：`FDragArmed := False`、`inherited`。

受け側（`OleResolveDrop`。12章から呼ばれる）：

1. `Root` が空・ハンドルなしなら ''。`FOleDragOver := True`、`FDragTimer` を動かす。
2. マウスの下の項目がフォルダーか ZIP なら、そのパスがドロップ先で、その項目に枠を描く。ほかは `Root`（枠なし）。
3. アプリ内から始めたドラッグで `ShellDecideDropEffect(ShellDragPaths, 先, ShellDragKeyState) = cdeNone` なら ''（枠なし）。
4. `SetDropHilite`。

| 手続き | 処理 |
|---|---|
| `OleDropLeave` | `FOleDragOver := False`、タイマーを止め、枠を消す |
| `OleDropped(先)` | 先が `Root` なら `SelectNewItemsOnNextRefresh` |
| `SetDropHilite` | 変わったら入れて `Invalidate` |
| `DrawDropFrame` | `WM_PAINT` のあと、`FDropHilite` の `DisplayRect(drBounds)` に `clHighlight` の2pxの枠を `GetDC` で描く |
| `DragTimerTick` | ドラッグ中でなければ止めて枠を消す。マウスが外（上下は 20px の余裕）なら止める。上端・下端から 20px 以内なら `WM_VSCROLL`（`SB_LINEUP`・`SB_LINEDOWN`） |

## 8. 戻る・進むをツリーで使う

TCTreeView の上でマウスの戻る・進むボタンを押したときは、TCTreeView が、つないでいる TCListView の `GoBack`・`GoForward` を呼ぶ（TCTreeView 設計書）。

---

## 9. 共通部品：CShellNotify（変更通知）

```pascal
const
  WM_CSHELLNOTIFY = WM_USER + $5A1;
  CSHCNE_RENAMEITEM = $00000001;  CSHCNE_CREATE = $00000002;  CSHCNE_DELETE = $00000004;
  CSHCNE_MKDIR = $00000008;       CSHCNE_RMDIR = $00000010;   CSHCNE_MEDIAINSERTED = $00000020;
  CSHCNE_MEDIAREMOVED = $00000040; CSHCNE_DRIVEREMOVED = $00000080; CSHCNE_DRIVEADD = $00000100;
  CSHCNE_ATTRIBUTES = $00000800;  CSHCNE_UPDATEDIR = $00001000; CSHCNE_UPDATEITEM = $00002000;
  CSHCNE_RENAMEFOLDER = $00020000;
  CSHCNE_DRIVEEVENTS = CSHCNE_MEDIAINSERTED or CSHCNE_MEDIAREMOVED or CSHCNE_DRIVEREMOVED or CSHCNE_DRIVEADD;
  CCSIDL_DRIVES = $0011;

function ShellNotifyRegisterPath(AWnd: HWND; const APath: string; ARecursive: Boolean; AEvents: LongInt): ULONG;
function ShellNotifyRegisterSpecial(AWnd: HWND; ACSIDL: Integer; ARecursive: Boolean; AEvents: LongInt): ULONG;
procedure ShellNotifyDeregister(var AID: ULONG);
function ShellNotifyDecode(AWParam: WPARAM; ALParam: LPARAM; out AEvent: LongInt; out APath1, APath2: string): Boolean;
```

- 登録は `SHChangeNotifyRegister(AWnd, SHCNRF_InterruptLevel or SHCNRF_ShellLevel or SHCNRF_NewDelivery, AEvents, WM_CSHELLNOTIFY, 1, エントリ)`。ほかのアプリによる変更も受け、共有メモリで受け取る。登録は必ず1件ずつ（複数を1回で登録すると解除が正しく動かないため）。
- パスは `ILCreateFromPathW`、特殊フォルダーは `SHGetSpecialFolderLocation` で PIDL にし、登録したら解放する（登録時に複製されるため）。
- `ShellNotifyDeregister`：ID が 0 でなければ `SHChangeNotifyDeregister` して 0 にする。
- `ShellNotifyDecode`：`SHChangeNotification_Lock` でイベントと PIDL 2つを取り、`SHGetPathFromIDListEx`（32768 文字のバッファ。長いパスに対応）でパスにし、`Unlock`。パスにできない項目は ''。
- shell32 の関数は、FPC の宣言と食い違わないよう、名前を付けて独自に宣言する。

## 10. 共通部品：CShellMenu（コマンド・メニュー）

```pascal
type
  TCExtraMenuPosition = (empTop, empBottom);
const
  CEXTRA_MENU_FIRST_ID = $8100;   // 独自項目のコマンド ID の先頭（シェルの 1〜$7FFF と重ならない）

function ShellInvokeVerbOnItems(AWnd: HWND; APaths: TStrings; const AVerb: string; AShift: Boolean = False): Boolean;
function ShellInvokeVerbOnFolder(AWnd: HWND; const AFolder, AVerb: string): Boolean;
function TrackShellContextMenu(AWnd: HWND; AMenu: HMENU; ACM: IContextMenu; AScreenX, AScreenY: Integer): UINT;
function ShellMenuVerb(ACM: IContextMenu; ACmdOffset: UINT): string;
function ContainsInvalidChar(const AText: string): Boolean;
function ShellRenameItem(AWnd: HWND; const APath, ANewName: string): Boolean;
function ShellLongPathW(const APath: string): UnicodeString;
function ExtraMenuInsert(AMenu: HMENU; APopup: TPopupMenu; APosition: TCExtraMenuPosition; AComponent: TComponent; AItems: TList): Integer;
function ExtraMenuClick(AItems: TList; ACmd: UINT): Boolean;
function ShellInvokeMenuCommand(ACM: IContextMenu; AWnd: HWND; ACmdOffset: UINT; const ADirectory: string): Boolean;
```

| 関数 | 処理 |
|---|---|
| `ShellInvokeVerbOnItems` | 各パスを `ILCreateFromPathW`。先頭の親を `SHBindToParent` で取り（全項目が同じ親である前提）、子の PIDL（2つ目からは `ILFindLastID`）で `GetUIObjectOf(IID_IContextMenu)`。`InvokeVerb`：先に `QueryContextMenu` を呼んでから（呼ばないと動かない実装があるため）、`lpVerb` にコマンド名（AnsiString）、`AShift` なら `CMIC_MASK_SHIFT_DOWN`（$10000000）で `InvokeCommand` |
| `ShellInvokeVerbOnFolder` | フォルダー自体を項目として扱う（"C:" は "C:\" にする。ドライブのルートは「PC」が親になる）。`ShellInvokeVerbOnItems` |
| `TrackShellContextMenu` | `ACM` が nil でなければ、出している間だけ `AWnd` のウィンドウ手続きを `SetWindowLongPtrW(GWLP_WNDPROC)` で差し替える（`ACM` が nil のとき、つまり独自項目だけのメニューは差し替えない）。差し替えた手続き（`MenuHookProc`）は次のとおり。1. `WM_INITMENUPOPUP`・`WM_MENUCHAR`・メニューの `WM_DRAWITEM`・`WM_MEASUREITEM` は、`ACM` が `IContextMenu3` を持てば `HandleMenuMsg2`、`IContextMenu2` を持てば `HandleMenuMsg`（`WM_MENUCHAR` を除く）へ渡す（「送る」「新規作成」など、開いたときに中身が作られるサブメニューのため。例外は握りつぶす）。シェルが処理したら、その結果を返して終わる。2. 1 でシェルが処理しなかったもの、どちらも持たないとき、および `WM_MENUSELECT` は、LCL の元の手続きへ渡さず `DefWindowProcW` だけを行う（LCL はメニュー項目に付いた値を `TMenuItem` とみなして読むため、シェルが値を入れた項目（「新規作成」など）で例外になる）。3. ほかのメッセージは元の手続きへ渡す。`TrackPopupMenu(TPM_LEFTALIGN or TPM_RIGHTBUTTON or TPM_RETURNCMD)` で選ばれた ID を返す（0 は選ばれなかった）。最後に元に戻す。メニューを出している間、`Application.Hint` は更新されない |
| `ShellMenuVerb` | `GetCommandString(相対 ID, GCS_VERBW)` で 256 文字まで。例外・失敗は '' |
| `ContainsInvalidChar` | `\ / : * ? " < > \|` のどれかがあれば `True` |
| `ShellRenameItem` | `SHBindToParent` で親を取り、`SetNameOf(AWnd, 子, 新しい名前, SHGDN_INFOLDER or SHGDN_FORPARSING)`（拡張子を含む実際の名前として扱う）。成功なら `True`（失敗の理由はシェルが出す） |
| `ShellLongPathW` | 248 文字以上で `\\?\` がなければ、`\\` で始まるなら `\\?\UNC\` ＋ 先頭2文字を除いたもの、ほかは `\\?\` ＋ パス |
| `ExtraMenuInsert` | `APopup.PopupComponent := AComponent`、`OnPopup` があれば呼ぶ（アプリが項目の状態を変えられるように）。末尾に足すときは、元の項目があれば区切り線を入れてから足す。`AddExtraItems`：見える項目を順に、区切り線はそのまま、文字の項目は `Caption`（ショートカットがあれば #9 ＋ `ShortCutToText`）、使えなければ灰色、`Checked` ならチェック。子があればサブメニューを作って中を足す。子のない項目は ID `CEXTRA_MENU_FIRST_ID + AItems.Count` で足し、`AItems` に入れる。足した数を返す。0 なら入れた区切り線を消す。先頭に足したときは、元の項目があれば間に区切り線を入れる。アイコンは出さない |
| `ExtraMenuClick` | ID が `CEXTRA_MENU_FIRST_ID` 以上で、`AItems` の範囲なら、その項目の `Click` を呼んで `True` |
| `ShellInvokeMenuCommand` | `CMINVOKECOMMANDINFOEX` を独自に宣言して使う（Unicode のパスを渡すため）。`fMask := CMIC_MASK_UNICODE`、`lpVerb`・`lpVerbW` に相対 ID、作業フォルダー（"C:" は "C:\"）を `lpDirectory`（ANSI）・`lpDirectoryW` に入れて `InvokeCommand`。例外は `False` |

## 11. 共通部品：CShellDragDrop（ドラッグの情報・禁止判定）

```pascal
type
  TCDropEffect = (cdeNone, cdeCopy, cdeMove);
var
  ShellDragTrace: Boolean = False;
procedure ShellDragLog(const AMsg: string);
procedure ShellDragBegin(ASource: TControl; APaths: TStrings);
procedure ShellDragEnd;
procedure ShellDragAbandon(ASource: TControl);
function ShellDragIsActive: Boolean;
function ShellDragPaths: TStrings;
function ShellDragKeyState: TShiftState;
function ShellDecideDropEffect(APaths: TStrings; const ATargetFolder: string; AShift: TShiftState): TCDropEffect;
```

- ドラッグの受け渡しはすべて OLE（12・13章）。このユニットは、アプリ内から始めたドラッグの情報（ドラッグ元と項目のパス）を持つことと、禁止の判定（枠を描くかの判定）だけを受け持つ。
- `ShellDragLog`：`ShellDragTrace` が `True` のときだけ、`%TEMP%\cshell_dd.log` に 'hh:nn:ss.zzz ' ＋ 文を追記する（不具合を調べるため。失敗しても止めない）。
- `ShellDragBegin`：前の情報を消し、ドラッグ元とパスの写しを持つ。`ShellDragEnd`：消す。`ShellDragAbandon(元)`：その部品がドラッグ元なら消す（ドラッグ元のまま壊されるとき）。
- `ShellDragIsActive`：ドラッグ元があり、パスが1つ以上。
- `ShellDragKeyState`：`GetKeyState` で Ctrl・Shift。
- `ShellDecideDropEffect`：
  1. パスがない、先が空なら `cdeNone`。先はフォルダーか、存在する .zip（ZIP への追加）でなければ `cdeNone`。
  2. Ctrl ならコピー、Shift なら移動、どちらもなければ、先頭のパスと先のドライブが同じなら移動、違えばコピー。
  3. 禁止：パスにドライブのルートがある、先と同じ、先が自分の配下、のどれかなら `cdeNone`。ZIP でなく、全部が先と同じフォルダーにあり、移動なら `cdeNone`（コピーは「〜 - コピー」になるのでよい）。
- finalization で、パスの一覧を解放する。

## 12. 共通部品：CShellOleDrop（OLE のドロップの受け側）

```pascal
type
  TOleResolveDropFunc = function(const AScreenPt: TPoint): string of object;  // ドロップ先（'' はできない）
  TOleDropLeaveProc = procedure of object;
  TOleDroppedProc = procedure(const AFolder: string) of object;
  ICDropTarget = interface(IUnknown) ['{00000122-0000-0000-C000-000000000046}'] ... end;
  TCShellOleDropTarget = class(TInterfacedObject, ICDropTarget)
function OleDropRegister(AWnd: HWND; AOnResolve: TOleResolveDropFunc; AOnLeave: TOleDropLeaveProc; AOnDropped: TOleDroppedProc): TCShellOleDropTarget;
procedure OleDropRevoke(AWnd: HWND; var ATarget: TCShellOleDropTarget);
```

仕組み：部品のウィンドウを `RegisterDragDrop` でドロップ先にし、マウスの位置のドロップ先（フォルダーか ZIP）を部品に聞き、そのフォルダーについてシェルが持つドロップ先（`IDropTarget`）を取り出して、処理をそのまま渡す。コピー／移動の判定、右ドラッグのメニュー、上書きの確認、ZIP への追加は、すべてエクスプローラーと同じになる。ドラッグ画像は `IDropTargetHelper`（CLSID `{4657278A-411B-11D2-839A-00C04FD918D0}`）で出す（作れなくても動く）。OLE の interface と API は、FPC の宣言との食い違いを避けるため独自に宣言する。

| 手続き | 処理 |
|---|---|
| `GetShellDropTarget(AWnd, P)` | "C:" は "C:\" にする。`SHBindToParent` で親を取り、`GetUIObjectOf(IID_ICDropTarget)` |
| `SwitchTarget(先, …)` | 先が前と違えば、前のシェルのドロップ先から `DragLeave` して捨て、新しい先のものを取って `DragEnter`（失敗なら効果なし）。先が '' か取れなければ効果なし。同じ先の上なら、ドラッグ元が許した効果で `DragOver` |
| `DragEnter` | データを持ち、先を聞いて `SwitchTarget`、ヘルパーの `DragEnter`。ドラッグ元が何も許していなければ効果なし |
| `DragOver` | 先を聞いて `SwitchTarget`、ヘルパーの `DragOver` |
| `DragLeave` | シェルのドロップ先を捨て、ヘルパーの `DragLeave`、データを捨て、部品の `OnLeave` |
| `Drop` | ヘルパーの `Drop`、部品の `OnLeave`（枠を消す）。シェルのドロップ先と先を取り出して空にする（`Drop` を渡したら `DragLeave` は送らない）。あれば部品の `OnDropped(先)` を呼んでから、シェルの `Drop` に渡す。なければ効果なし |
| `Detach` | 部品の手続きを外し、シェルのドロップ先とデータを捨てる（部品を壊すとき・ハンドルを壊すとき。以後部品を呼ばない） |
| `OleDropRegister` | ハンドルが 0 なら nil。作って `_AddRef`（部品も参照を持つため）、`RegisterDragDrop`。失敗なら `Detach`・`_Release` して nil |
| `OleDropRevoke` | nil なら何もしない。`Detach`、ハンドルがあれば `RevokeDragDrop`（システムの参照が外れる）、`_Release`、nil にする |

- どの手続きも例外を外へ出さない（効果なし・`E_UNEXPECTED` を返す）。
- initialization で `OleInitialize(nil)`（成功したら finalization で `OleUninitialize`）。

## 13. 共通部品：CShellOleDrag（OLE のドラッグの送り側）

```pascal
const
  CDROPEFFECT_NONE = 0; CDROPEFFECT_COPY = 1; CDROPEFFECT_MOVE = 2; CDROPEFFECT_LINK = 4;
function ShellDoDragDrop(AWnd: HWND; APaths: TStrings; AUseWindowImage: Boolean; out ADropEffect: DWORD): Boolean;
```

1. 項目のデータ（`IDataObject`）をシェルから取る：各パス（末尾の区切りを除く）を PIDL にし、先頭の親を `SHBindToParent`（全項目が同じ親である前提）、`GetUIObjectOf(IID_IDataObject)`。取れなければ `False`。
2. `AUseWindowImage` なら、`IDragSourceHelper`（独自宣言）の `InitializeFromWindow(AWnd, カーソル位置, データ)` で、ウィンドウ（リストビュー）にドラッグ画像を作らせる。ほかは `SHDoDragDrop` が既定の画像を作る。
3. `SHDoDragDrop(AWnd, データ, nil, COPY or MOVE or LINK, 効果)`。ドロップまで待つ。送り側の `IDropSource` は既定のもの（左右ボタン・Esc を扱う）。`DRAGDROP_S_DROP`（$00040100）ならドロップされたとして `True`。
4. 移動でも、元の項目を消すのはドロップ先（シェル）。送り側は何もしない。

## 14. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| `OnFolderChanged`・`OnSelectionChanged` が出ない・多い | `CheckStateChanged`（7.1）、`DoAsyncRefresh` の 6（7.6） |
| ほかのアプリで変えても更新されない | `RegisterFolderNotify`・`HandleShellNotify` の 2（7.5）。ネットワークドライブは通知が届かないことがある |
| 更新で選択が消える・スクロールが戻る | `DoAsyncRefresh`（7.6） |
| 並べ替えが遅い | `FindItemInfo` で作り直しが続いていないか（7.7） |
| 大きさを変えるとちらつく | `AutoSizeColumns`、`DoAsyncColumnResize` の余白（6章、7.8） |
| エクスプローラーへドロップできない | `MouseMove` の `PostMessage(CM_CSTARTDRAG)`、`StartOleDrag` の `ReleaseCapture`（7.13） |
| 「送る」のサブメニューが空 | `TrackShellContextMenu` の差し替え（10章） |
| 右クリックメニューで、カーソルを合わせると例外で止まる（「新規作成」など） | `TrackShellContextMenu` の差し替えで、メニュー関連のメッセージが LCL へ流れていないか（10章） |
| 日本語のパスで失敗する | W 版の API を使っているか（`PerformFileOperation`、`ShellInvokeMenuCommand`） |
| D&D の動きを追いたい | `ShellDragTrace := True` にして `%TEMP%\cshell_dd.log` を見る（11章） |
