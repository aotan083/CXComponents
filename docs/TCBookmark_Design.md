# TCBookmark 設計書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 目的

Firefox のブックマーク画面のような、ブックマーク管理の部品を作る。フォームに置き、`TargetBrowser`・`TargetEditor` を選ぶだけで（コードを書かずに）、ブックマークから TCTabBrowser・TCMonacoEditor で開けるようにする。

| No | 方針 |
|---|---|
| 1 | 部品は TCBookmark の1つ。検索ボックス（`TEdit`）とツリー（`TCBookmarkTree`）を中に持つ複合部品 |
| 2 | 開く先は `TargetBrowser`・`TargetEditor`。設定されていなければ、その開く先のメニューを灰色にする |
| 3 | データは保存先のフォルダーの JSON。変わるたびにすぐ保存する（アプリが保存のコードを書かない） |
| 4 | インポート・エクスポートは Netscape Bookmark File Format（HTML）だけ。ブラウザの内部ファイルは読み書きしない |
| 5 | 色はシステム色だけを使う（MetaDarkStyle がダーク用に切り替える）。部品は自分でテーマを判定しない |
| 6 | TCTabBrowser・TCMonacoEditor には手を入れず、公開されている API だけを使う |
| 7 | ドラッグは LCL のドラッグの仕組み（`BeginDrag`・`OnDragOver`・`OnDragDrop`・`OnEndDrag`）を使わず、マウスの通知で自分で行う。LCL の仕組みでは、離したときの通知の順番・有無が当てにならず、動かないことがあったため |
| 8 | 外からの D&D の受け取りは、ユニットの中の小さな `IDropTarget` で行う（CShellOleDrop は使わない） |
| 9 | マウス・キー・メニューの操作は、protected の virtual メソッド（14章）を呼ぶだけにする。継承したクラスから直接呼んで確かめられるようにする |

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCbookmark.pas` | cx（実行時） | 3章の型・クラスと、保存・読み込み・インポート・エクスポート・D&D |
| `uCbookmark_reg.pas` | cxdsgn（設計時） | `Register`：`RegisterComponents('CX', [TCBookmark])`。initialization で `{$I cbookmark_icon.lrs}` |
| `cbookmark_icon.lrs` | cxdsgn（設計時） | アイコン（リソース名 `tcbookmark`・`tcbookmark_150`・`tcbookmark_200`（IDE は大文字小文字を区別せずに探す）。24・36・48px の PNG。白い紙に青い栞を重ねた絵） |

- `uCbookmark` の uses：`Windows, Classes, SysUtils, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls, Menus, Graphics, Dialogs, LCLType, ActiveX, uCmonacos, uCTabBrowser`
- implementation の uses：`ShellApi, ShlObj, Clipbrd, IniFiles, fpjson, jsonparser, base64, DateUtils, Math, LazUTF8`
- `uCbookmark_reg` の uses：`Classes, LResources, uCbookmark`
- `{$mode objfpc}{$H+}`。
- Windows の API（`OleInitialize`・`RegisterDragDrop`・`RevokeDragDrop`・`ReleaseStgMedium`・`DragQueryFileW`・`CreateIconFromResourceEx`・`MoveFileExW`・`SHDoDragDrop`・`SHCreateStdEnumFmtEtc`・`ILCreateFromPathW`・`SHBindToParent`・`CoCreateInstance`・`RegisterClipboardFormatW`・WinINet の `InternetOpenW`・`InternetOpenUrlW`・`InternetReadFile`・`InternetCloseHandle`・`InternetSetOptionW`・`HttpQueryInfoW`）は、FPC の宣言の違いで困らないよう、`CB` を付けた名前でユニットの中で `external` 宣言する。`IDropTarget`（`ICBDropTarget`）・`IDataObject`（`ICBDataObject`）・`IShellLinkW`（`ICBShellLinkW`）・`IPersistFile`（`ICBPersistFile`）・`FILEDESCRIPTORW`（`TCBFileDescriptorW`）も、Windows の定義どおりの並びで宣言する。

**initialization**

1. `GLiveBookmarks := TFPList.Create`（生きている TCBookmark の一覧。favicon を取り終えたときに、部品がまだあるかを確かめる）。
2. `OleInitialize(nil)`（`RegisterDragDrop` に要る。済んでいれば何もしない）。
3. クリップボードの形式を登録：`UniformResourceLocatorW`（`GCfUrlW`）・`FileGroupDescriptorW`（`GCfFileGroupW`）・`FileContents`（`GCfFileContents`）・`UniformResourceLocator`（`GCfUrlA`）。

**finalization**：`FreeAndNil(GLiveBookmarks)`。

## 3. 型とクラス

```pascal
TCBookmarkKind = (bkUrl, bkFile, bkFolder, bkSeparator);
TCBookmarkTarget = (btBrowser, btEditor);
TCBookmarkDropPos = (bdpBefore, bdpInside, bdpAfter);
```

| クラス | 元のクラス | 公開 | 役割 |
|---|---|---|---|
| `TCBookmark` | `TCustomPanel` | パレット | 部品本体 |
| `TCBookmarkItem` | `TObject` | public | ブックマーク1件（4章） |
| `TCBookmarkTree` | `TTreeView` | 内部用 | ツリー。ドラッグ中の位置の線・枠を描く。外からの D&D の受け取りを登録する（6.3） |
| `TCBookmarkDropTarget` | `TInterfacedObject`, `ICBDropTarget` | 内部用 | 外からの D&D の受け取り（11.1） |
| `TCBookmarkFaviconThread` | `TThread` | 内部用 | favicon を裏で取りに行く（8.3） |
| `TCBookmarkUrlData` | `TInterfacedObject`, `ICBDataObject` | 内部用 | アプリの外へ URL をドラッグするときに渡すデータ（11.3） |
| `TCBControlAccess` | `TControl` | 内部用 | 同じアプリの部品の `DragOver`・`DragDrop`（protected）を呼ぶための継承 |

追加・編集のダイアログは、`TForm.CreateNew` でその場で作る（専用のクラス・.lfm は持たない。10.2）。

## 4. TCBookmarkItem

```pascal
TCBookmarkItem = class
private
  FKind: TCBookmarkKind;
  FName: string;
  FLocation: string;      // URL かファイルパス
  FExpanded: Boolean;
  FAddDate: TDateTime;    // Create で Now
  FParent: TCBookmarkItem;
  FItems: TFPList;        // 子。フォルダーのときだけ Create で作る
  FFileMissing: Boolean;
  FNode: TTreeNode;       // 今表示しているツリーの行。BuildTree のたびに入れ直す（無ければ nil）
public
  constructor Create(AKind: TCBookmarkKind);
  destructor Destroy; override;          // 子を全部 Free してから FItems を Free
  procedure InsertChild(AIndex: Integer; AItem: TCBookmarkItem);
  procedure RemoveChild(AItem: TCBookmarkItem);
  function IsDescendantOf(AItem: TCBookmarkItem): Boolean;
  function Clone: TCBookmarkItem;
  function DescendantCount: Integer;
  property Kind: TCBookmarkKind read FKind;
  property Name: string read FName write FName;
  property Location: string read FLocation write FLocation;
  property Expanded: Boolean read FExpanded write FExpanded;
  property AddDate: TDateTime read FAddDate;
  property Parent: TCBookmarkItem read FParent;
  property Count: Integer read GetCount;               // FItems = nil なら 0
  property Items[AIndex: Integer]: TCBookmarkItem read GetItem; default;
  property Index: Integer read GetIndex;               // 親の FItems.IndexOf。親が無ければ -1
  property FileMissing: Boolean read FFileMissing;
end;
```

| 手続き | 処理 |
|---|---|
| `InsertChild(I, It)` | `FItems` が無ければ何もしない。`I` が範囲の外なら末尾。入れて `It.FParent := Self` |
| `RemoveChild(It)` | `FItems` から外す（解放しない）。親が自分なら `FParent := nil` |
| `IsDescendantOf(A)` | 親をたどって `A` があれば `True`。自分自身・nil は `False` |
| `Clone` | 種類・名前・場所・開閉・登録日時・`FFileMissing` を写し、子も `Clone` して入れる（親は nil、`FNode` は写さない） |
| `DescendantCount` | 子ごとに 1 + 子の `DescendantCount` |

- 一番上の入れ物は、名前のない `Root`（`bkFolder`、`FExpanded = True`）。画面には `Root` の子から出す。
- `TCBookmark` は `FKind`・`FFileMissing` などのフィールドを直接書く（同じユニットの中のため）。

## 5. TCBookmark の宣言とフィールド

### 5.1 宣言

```pascal
protected
  procedure CreateWnd; override;
  procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  procedure DoItemClick(AItem: TCBookmarkItem); virtual;
  procedure DoMenuOpen(AItem: TCBookmarkItem; ATarget: TCBookmarkTarget; ANewTab: Boolean); virtual;
  procedure DoMenuEdit(AItem: TCBookmarkItem); virtual;
  procedure DoMenuDelete(AItem: TCBookmarkItem); virtual;
  procedure DoMenuCut(AItem: TCBookmarkItem); virtual;
  procedure DoMenuCopy(AItem: TCBookmarkItem); virtual;
  procedure DoMenuPaste(AItem: TCBookmarkItem); virtual;
  procedure DoMenuAddBookmark(AItem: TCBookmarkItem); virtual;
  procedure DoMenuAddFolder(AItem: TCBookmarkItem); virtual;
  procedure DoMenuAddSeparator(AItem: TCBookmarkItem); virtual;
  procedure DoDropItem(AItem, ATarget: TCBookmarkItem; APos: TCBookmarkDropPos); virtual;
  procedure DoDropFiles(const AFiles: TStrings; ATarget: TCBookmarkItem; APos: TCBookmarkDropPos); virtual;
  procedure DoDropUrl(const AUrl, ATitle: string; ATarget: TCBookmarkItem; APos: TCBookmarkDropPos); virtual;
public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  function ImportFromFile(const AFileName: string): Boolean;
  function ExportToFile(const AFileName: string): Boolean;
  procedure ImportWithDialog;
  procedure ExportWithDialog;
  function AddBookmark(AParent: TCBookmarkItem; AIndex: Integer; const AName, ALocation: string): TCBookmarkItem;
  function AddFolder(AParent: TCBookmarkItem; AIndex: Integer; const AName: string): TCBookmarkItem;
  function AddSeparator(AParent: TCBookmarkItem; AIndex: Integer): TCBookmarkItem;
  procedure DeleteItem(AItem: TCBookmarkItem);
  function MoveItem(AItem, ANewParent: TCBookmarkItem; ANewIndex: Integer): Boolean;
  procedure OpenItem(AItem: TCBookmarkItem; ATarget: TCBookmarkTarget; ANewTab: Boolean);
  property Root: TCBookmarkItem read FRoot;
  property Selected: TCBookmarkItem read GetSelected;          // ItemOfNode(FTree.Selected)
  property SearchText: string read GetSearchText write SetSearchText;
  property DragItem: TCBookmarkItem read FDragItem;
published
  property TargetBrowser: TCTabBrowser read FTargetBrowser write SetTargetBrowser;
  property TargetEditor: TCMonacoEditor read FTargetEditor write SetTargetEditor;
  property BookmarkFolder: string read FBookmarkFolder write SetBookmarkFolder stored IsBookmarkFolderStored;
  property BookmarkFile: string read FBookmarkFile write SetBookmarkFile stored IsBookmarkFileStored;
  property OnChange: TNotifyEvent read FOnChange write FOnChange;
  property OnSelectionChange: TNotifyEvent read FOnSelectionChange write FOnSelectionChange;
  property Align; Anchors; BorderSpacing; Constraints; Enabled; Font; ParentFont; ShowHint; TabOrder; TabStop; Visible;

// ユニットの関数
function CBClassifyLocation(const S: string; out AKind: TCBookmarkKind; out ALocation: string): Boolean;
function CBPathToFileUrl(const APath: string): string;
function CBFileUrlToPath(const AUrl: string): string;
function CBHostOf(const AUrl: string): string;
```

- `IsBookmarkFolderStored`：`FBookmarkFolder <> 'bookmark'`。`IsBookmarkFileStored`：`FBookmarkFile <> 'bookmarks.json'`。

### 5.2 フィールド

| 名前 | 型 | 初期値 | 中身 |
|---|---|---|---|
| `FSearch` | `TEdit` | Create で作る | 検索ボックス |
| `FTree` | `TCBookmarkTree` | Create で作る | ツリー |
| `FImages` | `TImageList` | Create で作る | アイコン（`SM_CXSMICON`×`SM_CYSMICON`） |
| `FMenu` | `TPopupMenu` | Create で作る | 右クリックメニュー |
| `FMiTextOpen` ～ `FMiExport` | `TMenuItem` | Create で作る | メニューの 14 項目（10.1） |
| `FRoot` | `TCBookmarkItem` | Create で作る | 一番上の入れ物 |
| `FTargetBrowser`・`FTargetEditor` | | nil | 開く先 |
| `FOnChange`・`FOnSelectionChange` | `TNotifyEvent` | nil | イベント |
| `FLastSel` | `TCBookmarkItem` | nil | 最後に `OnSelectionChange` で知らせた選択（比べるだけ） |
| `FDataDir` | `string` | `UpdatePaths` | 保存先のフォルダー（最後に `\`） |
| `FIconDir` | `string` | `UpdatePaths` | `FDataDir + 'icons\'` |
| `FBookmarkFolder` | `string` | 'bookmark' | `BookmarkFolder` |
| `FBookmarkFile` | `string` | 'bookmarks.json' | `BookmarkFile` |
| `FDataLoaded` | `Boolean` | `False` | 読み込んだ |
| `FSaveErrorShown` | `Boolean` | `False` | 保存の失敗を知らせた（起動中に1回だけ） |
| `FUpdating` | `Boolean` | `False` | ツリーを作っている・壊している間（開閉・選択の通知を無視する） |
| `FSearching` | `Boolean` | `False` | 検索中（一覧を表示している） |
| `FSearchKey` | `UnicodeString` | '' | 検索の文字（`CBNormalize` したもの） |
| `FSearchTimer` | `TTimer` | 300ms・止めておく | 入力の後に検索する |
| `FDragItem` | `TCBookmarkItem` | nil | ドラッグしている項目（`DragItem`） |
| `FDragStarted` | `Boolean` | `False` | 押してからドラッグした（離したときにクリックにしない） |
| `FDragArmed` | `Boolean` | `False` | 項目の上で左ボタンを押した（しきい値を超えたらドラッグを始める） |
| `FDragActive` | `Boolean` | `False` | 部品の中のドラッグ中 |
| `FDragStartPt` | `TPoint` | | 押した位置 |
| `FDownItem` | `TCBookmarkItem` | nil | 押した位置の項目 |
| `FDropOk` | `Boolean` | `False` | 最後に確かめた位置に落とせる |
| `FDropTargetItem` | `TCBookmarkItem` | nil | 最後に確かめた落とす位置の項目（nil = 一番下） |
| `FDropPos` | `TCBookmarkDropPos` | | 最後に確かめた落とす位置 |
| `FDragTimer` | `TTimer` | 100ms・止めておく | ドラッグ中の自動スクロール・フォルダーを開く |
| `FHoverItem` | `TCBookmarkItem` | nil | 中に入れる位置で止まっているフォルダー |
| `FHoverStart` | `QWord` | | 止まり始めた時刻 |
| `FExtDragging` | `Boolean` | `False` | 外からの D&D 中 |
| `FAppTarget` | `TControl` | nil | ドラッグ中、マウスの下にある同じアプリの部品 |
| `FAppAccept` | `Boolean` | `False` | その部品の `OnDragOver` が受けると答えた |
| `FOleDragging` | `Boolean` | `False` | 自分で始めた OLE のドラッグ中（自分のツリーでは受けない） |
| `FPopupItem` | `TCBookmarkItem` | nil | 右クリックした項目（nil = 何も無い所） |
| `FClip` | `TCBookmarkItem` | nil | コピーした写し（持ち主は TCBookmark） |
| `FCutItem` | `TCBookmarkItem` | nil | 切り取った項目（元の場所に残っている） |
| `FIconKeys` | `TStringList`（並べ替え） | 空 | ファイルのアイコン：キー → `FImages` の番号 |
| `FHostIcons` | `TStringList`（並べ替え） | 空 | favicon：ホスト → `FImages` の番号（-1 = 無い） |
| `FBaseIconsMade` | `Boolean` | `False` | 地球儀・フォルダーのアイコンを作った |
| `FGlobeIndex`・`FFolderIndex`・`FFolderOpenIndex` | `Integer` | -1 | そのアイコンの番号 |
| `FFetchTried` | `TStringList`（並べ替え） | 空 | 起動中に取りに行ったホスト |
| `FFetchQueue` | `TStringList` | 空 | 順番待ちのホスト |
| `FFetchRunning` | `Integer` | 0 | 取りに行っている数 |
| `FPendingFiles` | `TStringList` | 空 | ドロップされたファイル（後で登録する） |
| `FPendingUrl`・`FPendingTitle` | `string` | '' | ドロップされた URL とタイトル |
| `FPendingTarget` | `TCBookmarkItem` | nil | ドロップの位置の項目 |
| `FPendingPos` | `TCBookmarkDropPos` | | ドロップの位置 |
| `FPendingIsUrl` | `Boolean` | `False` | ドロップされたのが URL |
| `FDlgName`・`FDlgLoc` | `TEdit` | nil | ダイアログの入力欄（出している間だけ） |
| `FDlgOk` | `TButton` | nil | ダイアログの［OK］（出している間だけ） |
| `FDlgWithLoc` | `Boolean` | | ダイアログに場所の欄がある |

## 6. 作る・壊す

### 6.1 Create

1. `inherited`。`ControlStyle` から `csSetCaption`・`csAcceptsControls` を外す。`SetTextBuf('')`、`BevelOuter`・`BevelInner := bvNone`、250×300。
2. `FRoot` を作る（`FExpanded := True`）。`FBookmarkFolder := 'bookmark'`、`FBookmarkFile := 'bookmarks.json'`、`UpdatePaths`。
3. `FIconKeys`・`FHostIcons`・`FFetchTried` を並べ替えありで、`FFetchQueue`・`FPendingFiles` を作る。
4. `FImages`（持ち主は Self、大きさは `SM_CXSMICON`・`SM_CYSMICON`）。
5. `FSearch`：`csNoDesignSelectable`、`Align := alTop`、`TextHint := 'ブックマークを検索'`、`OnChange := SearchChange`、`OnKeyDown := SearchKeyDown`。
6. `FTree`：`FBM := Self`、`csNoDesignSelectable`、`Align := alClient`、`BorderStyle := bsNone`、`ReadOnly := True`（名前の変更はダイアログで行う）、`RowSelect := True`、`ShowLines := False`、`ShowRoot := True`、`HideSelection := False`、`ToolTips := False`、`ScrollBars := ssAutoBoth`、`Options + [tvoNoDoubleClickExpand]`（左クリックで開閉するため）、`Images := FImages`。イベント：`OnMouseDown`・`OnMouseUp`・`OnMouseMove`・`OnKeyDown`・`OnExpanded`・`OnCollapsed`・`OnAdvancedCustomDrawItem`（`TreeDrawItem`）・`OnChange`（`TreeSelChange`）。
7. `FMenu`（`OnPopup := MenuPopup`）に 10.1 の項目を作り、`FTree.PopupMenu := FMenu`。
8. `FSearchTimer`（300ms）・`FDragTimer`（100ms）を止めた状態で作る。
9. `GLiveBookmarks.Add(Self)`。

- Create ではデータを読まない（6.2）。

### 6.2 CreateWnd

`inherited`。`FDataLoaded` でなく設計時でもなければ、`FDataLoaded := True`、`LoadData`、`BuildTree`。

- 初めてウィンドウを作るときに読むのは、.lfm から `BookmarkFolder`・`BookmarkFile` を読み終えた後にするため。

### 6.3 TCBookmarkTree

| 手続き | 処理 |
|---|---|
| `CreateWnd` | `inherited`。実行時なら、`FDropTarget` が無ければ `TCBookmarkDropTarget.Create(FBM)` を作り、`RegisterDragDrop(Handle, FDropTarget)` |
| `DestroyWnd` | `FDropTarget` があれば `RevokeDragDrop(Handle)`。`inherited` |
| `ShowIndicator(It, Pos)` | 同じなら何もしない。覚えて `Invalidate` |
| `HideIndicator` | 出していれば消して `Invalidate` |
| `Paint` | `inherited` の後、出していれば `clHighlight`・太さ 2 で描く。`It.FNode` があれば：前は行の上端、後は行の下端に、文字の左 4px から右端まで横線。中は行を枠で囲む。`It` が nil（一番下）なら、最後に見えている行の下端に横線（行が無ければ y=2） |

- `FDropTarget` はインターフェースで持つ（ツリーが消えると参照が外れて解放される）。

### 6.4 Destroy

1. `GLiveBookmarks.Remove(Self)`（取り終えた favicon のスレッドが触らないようにする）。
2. `Application.RemoveAsyncCalls(Self)`（予約したドロップの登録を取り消す）。
3. `FUpdating := True`（ツリーを壊す間の開閉の通知を無視する）。
4. `FCutItem := nil`、`FClip`・`FRoot`・5.2 の `TStringList` を解放。
5. `inherited`。

### 6.5 Notification・開く先

- `SetTargetBrowser`・`SetTargetEditor`：前の値から `RemoveFreeNotification`、新しい値に `FreeNotification`。
- `Notification`：`opRemove` で開く先が消えたら nil にする。

## 7. データ

### 7.1 保存先（UpdatePaths）

1. `D := Trim(FBookmarkFolder)`。ドライブ名が無く、`\` で始まらなければ、EXE のフォルダーの後ろにつなぐ。
2. `FDataDir := IncludeTrailingPathDelimiter(ExpandFileName(D))`、`FIconDir := FDataDir + 'icons\'`。
3. `Trim(FBookmarkFile) = ''` なら 'bookmarks.json'。

`SetBookmarkFolder`・`SetBookmarkFile`：違えば入れて `UpdatePaths`、`ReloadData`。

`ReloadData`：設計時・.lfm の読み込み中・まだ読んでいないなら何もしない（初めて表示されたときに新しい場所から読む）。読んだ後なら：

1. 項目を指すフィールド（`FCutItem`・`FDragItem`・`FDownItem`・`FDropTargetItem`・`FPopupItem`・`FHoverItem`・`FPendingTarget`）を nil、`FDropOk := False`。
2. `FUpdating` の間に `FTree.Items.Clear`（古い項目を指す行を先に消す）。
3. `FRoot` を作り直す。`FHostIcons`・`FFetchTried` を空にする（favicon のフォルダーも変わるため）。
4. `LoadData`、`BuildTree`、`OnChange`、`CheckSelection`。

### 7.2 読み込み（LoadData）

1. `UpdatePaths`。`F := FDataDir + FBookmarkFile`。無ければ何もしない。
2. `CBReadFileText(F)`（UTF-8 の BOM は外す）→ `GetJSON`。`TJSONObject` でなければ例外。`items` が配列なら `ReadJsonItems(FRoot, items)`。
3. 例外が出たら：`FRoot` を空で作り直し、`F` を `F + '.broken-' + yyyymmddhhnnss` に名前を変え、「ブックマークを読み込めませんでした。元のファイルは （名前） に残しました。」（`mtWarning`）。壊れたファイルを空のデータで上書きしないため。
4. `RefreshMissing(FRoot, True)`。

`ReadJsonItems(親, 配列)`：オブジェクトごとに `type` が `url`・`file`・`folder`・`separator` なら作り、知らない `type` は読み飛ばす。`name`・`location`・`expanded`・`added`（`CBIsoToDate`。0 なら `Now`）を入れ、親の末尾に入れる。`folder` は `items` を同じ手続きで読む。

### 7.3 保存（SaveData）

1. 設計時なら何もしない。
2. `{"version": 1, "items": WriteJsonItems(FRoot)}` を `FormatJSON` で文字にする。
3. `ForceDirectories(FDataDir)`。`F + '.tmp'` に書き、`MoveFileExW(tmp, F, MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH)`（書いている途中で止まっても壊れない）。失敗は例外。
4. 例外は受け、`FSaveErrorShown` でなければ立てて「ブックマークを保存できません：（理由）」（`mtError`）。

`WriteJsonItems`：URL・ファイルは `type`・`name`・`location`・`added`、フォルダーは `type`・`name`・`expanded`・`added`・`items`、区切り線は `type` だけ。`added` は `CBDateToIso`（`yyyy-mm-ddThh:nn:ss`）。

### 7.4 変わった後の共通の処理（Changed）

`Changed(選ぶ項目)`：`BuildTree` → `SelectItem` → `SaveData` → `OnChange` → `CheckSelection`。足す・編集・消す・動かす・貼り付け・インポート・ドロップはすべてこれで終える。

- フォルダーの開閉は `SaveData` だけ（`OnChange` は出さない。8.1）。

### 7.5 選択の通知

| 手続き | 処理 |
|---|---|
| `TreeSelChange` | `FUpdating` なら何もしない。`CheckSelection` |
| `CheckSelection` | `FUpdating`・壊している途中なら何もしない。`GetSelected` が `FLastSel` と同じなら何もしない。違えば覚えて `OnSelectionChange` |

- ツリーを作り直している間は知らせず、作り直した後に1回だけ比べる（`Changed`・`SearchTimer`・`ReloadData` の最後）。

### 7.6 リンク先の確認（RefreshMissing）

`RefreshMissing(It, ADeep)`：`It` がファイルなら `FFileMissing := not FileExists`。フォルダーなら、子のファイルを確かめ、`ADeep` なら子のフォルダーも同じ手続き。

| 呼ぶ時点 | 呼び方 |
|---|---|
| 読み込んだとき | `RefreshMissing(FRoot, True)` |
| フォルダーを開いたとき | `RefreshMissing(フォルダー, False)` |
| 貼り付けたとき | `RefreshMissing(写し, True)` |
| 登録・編集・ドロップ | 作るときに `FileExists` で入れる |
| 開くとき | `OpenItem` で確かめ直す |

## 8. 表示

### 8.1 ツリー

| 手続き | 処理 |
|---|---|
| `BuildTree` | `MakeBaseIcons`。`FUpdating` の間に `BeginUpdate`・`Clear`・`ClearNodes(FRoot)`（全項目の `FNode := nil`）。検索中なら `AddMatches(FRoot)`、でなければ `AddNodes(nil, FRoot)`。`EndUpdate`。`FTree.DragMode := dmManual` |
| `AddNodes(親の行, It)` | 子ごとに `AddChildObject(親の行, 名前, 子)`、`子.FNode := 行`。フォルダーなら、子を足してから `Expanded := 子.FExpanded`。`SetNodeLook` |
| `AddMatches(It)` | フォルダーは中へ。URL・ファイルで、`CBNormalize(名前)` か `CBNormalize(場所)` に `FSearchKey` を含むものを、一番上に1列で足す |
| `SetNodeLook(行, It)` | `ImageIndex`・`SelectedIndex := IconIndexOf(It, 行.Expanded)`、`StateIndex := -1`。区切り線なら `Height := Max(6, DefaultItemHeight div 2)` |
| `UpdateAllIcons` | すべての行に `SetNodeLook`、`Invalidate` |
| `SelectItem(It)` | `It.FNode` があれば選び、`MakeVisible` |
| `TreeExpanded` | `FUpdating`・検索中なら何もしない。フォルダーなら `FExpanded := True`、`RefreshMissing(It, False)`、`SetNodeLook`、`Invalidate`、`SaveData` |
| `TreeCollapsed` | 同じ条件で `FExpanded := False`、`SetNodeLook`、`SaveData` |

### 8.2 自分で描く行（TreeDrawItem）

`cdPrePaint` のときだけ。

- 区切り線：行の四角を、選ばれていれば `clHighlight`、でなければツリーの色で塗り、真ん中の高さに `clGrayText` の 1px の線を、アイコンの左から右端 −8px（96dpi 換算）まで引く。`DefaultDraw`・`PaintImages := False`。
- リンク先が無いファイル：行を塗り（選ばれていれば `clHighlight`・文字 `clHighlightText`、でなければツリーの色・文字 `clGrayText`）、アイコンを `FImages.Draw` で描き、名前を `TextOut`。`DefaultDraw`・`PaintImages := False`。

- 自分で描く理由：区切り線は行の高さを変えるため。無いファイルは、`Canvas.Font.Color` を変えるだけでは TTreeView の描画で色が効かなかったため。

### 8.3 アイコン

| 手続き | 処理 |
|---|---|
| `MakeBaseIcons` | 1 回だけ。地球儀の絵を `TBitmap`（背景 `clFuchsia`、線は青 `$00A06A2E`。円・縦長の楕円・横線 3 本）で描いて `AddMasked`。フォルダーのアイコンを `AddShellIcon('folder', FILE_ATTRIBUTE_DIRECTORY, SHGFI_USEFILEATTRIBUTES)` と、`SHGFI_OPENICON` 付きで足す（開いたものが取れなければ閉じたものを使う） |
| `AddShellIcon(パス, 属性, 旗)` | `SHGetFileInfoW(SHGFI_ICON or SHGFI_SMALLICON or 旗)` のアイコンを `TIcon` 経由で `FImages.AddIcon`（ハンドルは `TIcon` が解放する）。取れなければ -1 |
| `FileIconIndex(パス)` | 拡張子（無ければ '.txt'）でキー 'e:' + 拡張子。.exe・.ico・.lnk でファイルがあれば 'p:' + パス（ファイルごと）。覚えていればそれ。なければ、'p:' は `AddShellIcon(パス, 0, 0)`、'e:' は `AddShellIcon('x' + 拡張子, FILE_ATTRIBUTE_NORMAL, SHGFI_USEFILEATTRIBUTES)` |
| `HostIconFile(ホスト)` | `FIconDir + CBHostFileKey(ホスト)` の .png、無ければ .ico。どちらも無ければ '' |
| `HostIconIndex(ホスト)` | 覚えていればそれ（-1 も覚える）。ファイルがあれば `CBIconFromBytes(中身, FImages.Width)` を `AddIcon` |
| `IconIndexOf(It, 開)` | URL：`HostIconIndex`、-1 なら地球儀。ファイル：`FileIconIndex`。フォルダー：開閉で 2 つ。区切り線：-1 |

`CBIconFromBytes(中身, 大きさ)`：PNG（先頭 `89 50 4E 47`）なら全体を `CreateIconFromResourceEx(…, True, $00030000, 大きさ, 大きさ, 0)`。ICO（先頭 `00 00 01 00`）なら、中の画像のうち大きさ以上で一番小さいもの（無ければ一番大きいもの。幅 0 は 256）の部分を同じ関数に渡す。それ以外・範囲の外は 0。

**favicon を取りに行く**

| 手続き | 処理 |
|---|---|
| `RequestFavicon(ホスト)` | ホストが空・設計時・ファイルがある・起動中に取りに行った（`FFetchTried`）なら何もしない。`FFetchTried` と `FFetchQueue` に足し、`StartNextFetch` |
| `StartNextFetch` | `FFetchRunning < 4` で待ちがある間、先頭を取り出し、`Inc(FFetchRunning)`、スレッドを作って `Start` |
| `TCBookmarkFaviconThread.Execute` | `InternetOpenW('CXBookmark', PRECONFIG)`、接続・受信の待ち 10 秒。`https://（ホスト）/favicon.ico` を `RELOAD・NO_UI・NO_COOKIES` で開き、状態が 200 のときだけ 8KB ずつ読む（512KB を超えたら捨てる）。例外は受けて中身なし。最後に `Synchronize(Done)` |
| `Done` | `GLiveBookmarks` に部品がまだあれば `FaviconArrived` |
| `FaviconArrived(ホスト, 中身)` | `Dec(FFetchRunning)`。中身があり、まだファイルが無ければ `SaveHostIcon`・`UpdateAllIcons`。`StartNextFetch` |
| `SaveHostIcon(ホスト, 中身)` | PNG・ICO でなければ捨てる。`ForceDirectories(FIconDir)`、もう一方の拡張子のファイルを消して書く（失敗は黙って抜ける）。`FHostIcons` の覚えを消す（読み直させる） |

- スレッドは `FreeOnTerminate`。部品を壊しても待たない（`Done` で確かめる）。

## 9. 項目を作る・入れる・開く

### 9.1 作る・入れる

| 手続き | 処理 |
|---|---|
| `NewLink(名前, 場所)` | `CBClassifyLocation` で決められなければ nil。項目を作り、名前は `Trim(名前)`、空ならファイル名（URL は URL）。ファイルは `FFileMissing`、URL は `RequestFavicon(CBHostOf)` |
| `InsertPos(It, out 親, out 位置)` | `It` が nil・ツリーに無い → `Root` の末尾。フォルダー → その中の末尾。それ以外 → `It` の親の `It.Index + 1` |
| `DropDest(的, 位置, out 親, out 位置)` | 的が nil・ツリーに無い → `Root` の末尾。前 → 的の親の `的.Index`。後 → `的.Index + 1`。中 → フォルダーならその末尾、それ以外は後と同じ |
| `DoInsert(親, 位置, It)` | 親が nil なら `Root`。`InsertChild`。`Root` でなければ親の `FExpanded := True`（入れたフォルダーを開く） |
| `MoveInternal(It, 新しい親, 位置)` | `It` が nil・`Root`・ツリーに無い、新しい親がフォルダーでない・ツリーに無い、新しい親が `It` 自身か配下なら `False`。位置が範囲の外なら末尾。同じ親で前から後ろへ動かすときは位置を 1 引く（外した分）。外して `DoInsert`。`True` |
| `IsInTree(It)` | 親をたどった一番上が `FRoot` か（消した項目・写しを見分ける） |

### 9.2 公開メソッド

| メソッド | 処理 |
|---|---|
| `AddBookmark` | `NewLink`。nil なら nil を返す。親が nil・フォルダーでない・ツリーに無ければ `Root`。`DoInsert`、`Changed(足した項目)` |
| `AddFolder`・`AddSeparator` | 作って同じように入れ、`Changed` |
| `DeleteItem(It)` | nil・`Root`・ツリーに無ければ何もしない。`FCutItem`・`FLastSel`・`FDragItem`・`FDownItem`・`FDropTargetItem` が `It` か配下なら nil（`FDropTargetItem` のときは `FDropOk := False` も）。次に選ぶ項目は、同じ親の同じ位置（次）、無ければ最後、無ければ親（`Root` なら nil）。外して `Free`、`Changed(次)` |
| `MoveItem` | `MoveInternal` が `True` なら `Changed(It)` |
| `OpenItem(It, 先, 新)` | URL・ファイル以外は何もしない。ファイルは `FFileMissing` を確かめ直して `Invalidate`。無ければ「ファイルがありません：（パス）」（`mtWarning`）で抜ける。`btEditor` は `TargetEditor` があり、ファイルのときだけ `OpenInEditor`。`btBrowser` は `TargetBrowser` があれば、URL はそのまま、ファイルは `CBPathToFileUrl` して `OpenInBrowser` |

### 9.3 開く

`OpenInEditor(パス, 新)`（TCMonacoEditor の `OpenFile`・`FindPage`・`ActiveIndex`・`Modified`・`LoadFromFile`・`SetFocus` を使う）：

1. 新しいタブ：`OpenFile(パス) >= 0` なら `SetFocus`（開いていれば、そのタブに切り替えるだけ。TCMonacoEditor の決まり）。終わり。
2. `FindPage(パス) >= 0` なら、`ActiveIndex` にして `SetFocus`。終わり。`LoadFromFile` は、別のタブで開いているファイルを読まずにエラーにするため、先に確かめる。
3. `Modified` なら「保存されていない変更があります。新しいタブで開きますか？」（はい・いいえ）。はいなら `OpenFile`・`SetFocus`。終わり。`LoadFromFile` は変更を確かめずに捨てるため、ここで聞く。変更を捨てて読む選択肢は出さない。
4. `LoadFromFile(パス)` が `True` なら `SetFocus`。

- 例外は受けて「開けません：（パス : 理由）」（`mtError`）。

`OpenInBrowser(URL, 新)`：新しいタブなら `TargetBrowser.Add(URL)`、でなければ `Navigate(URL)`（タブが無ければ TCTabBrowser が作る）。例外は受けて「開けません：（URL : 理由）」。

- ファイルを TCTabBrowser で開くときに `LoadFromFile` を使わない理由：新しいタブで開く方法が無く、`%`・`#` を含むパスを正しく渡せないため。

### 9.4 ユニットの関数

| 関数 | 処理 |
|---|---|
| `CBClassifyLocation` | `Trim`。空なら `False`。`file:` で始まれば `bkFile`、`CBFileUrlToPath`（空でなければ `True`）。`://` を含めば `bkUrl`。`英字 + ':' + ('\' か '/')` か `\\` で始まれば `bkFile`（`/` → `\`）。それ以外は `False` |
| `CBPathToFileUrl` | 1 文字ずつ `\` → `/`、`%` → `%25`、`#` → `%23`、空白 → `%20`。`//` で始まれば `'file:' + S`、でなければ `'file:///' + S` |
| `CBFileUrlToPath` | `file:///` を外す。`file://` なら `//` + 残り。`CBPercentDecode`（バイト単位）、`/` → `\` |
| `CBHostOf` | `://` の後ろから、`/ ? # \` の前まで。`@` があればその後ろ。小文字。`://` が無ければ '' |
| `CBHostFileKey` | ホストの `: \ / * ? " < > \|` を `_` にする（アイコンのファイル名） |
| `CBNormalize` | UTF-16 にして、全角 `！`〜`～`（$FF01〜$FF5E）を半角へ、全角空白を半角空白へ、`WideLowerCase` |
| `CBHtmlEscape` | `& < > "` を文字参照にする |
| `CBHtmlDecode` | `&amp; &lt; &gt; &quot; &apos; &nbsp;`（空白）、`&#nnn;`・`&#xhh;`（$FFFF まで）を戻す |
| `CBReadUrlFile` | .url を `TIniFile` で開き、`[InternetShortcut]` の `URL`。読めなければ '' |
| `CBResolveLink` | `CoCreateInstance(CLSID_ShellLink)` → `IPersistFile.Load` → `Resolve(0, SLR_NO_UI)` → `GetPath`。失敗は '' |

## 10. 操作

### 10.1 右クリックメニュー

項目（`Tag` は `MenuClick` で使う番号）：Text開く(1)・Text新しいタブで開く(2)・―・Browserで開く(3)・Browserで新しいタブで開く(4)・―・ブックマークを編集(5)・ブックマークを削除(6)・―・切取り(7)・コピー(8)・貼り付け(9)・―・ブックマークを追加(10)・フォルダーを追加(11)・区切り線(12)・―・インポート...(13)・エクスポート...(14)。文字は `resourcestring`。

`TreeMouseDown`（右ボタン）：押した行を選ぶ（何も無い所なら選択を外す）。`FPopupItem := その項目`。

`MenuPopup`：`FPopupItem := GetSelected`（キーボードでメニューを出したときも同じ）。

| 項目 | 使える条件 |
|---|---|
| Text 系 | `TargetEditor` があり、ファイル |
| Browser 系 | `TargetBrowser` があり、URL かファイル |
| 編集 | 項目があり、区切り線でない |
| 削除・切取り・コピー | 項目がある |
| 貼り付け | 検索中でなく、`FClip` か `FCutItem` がある |
| 追加 3 つ・インポート | 検索中でない |
| エクスポート | いつも |

`MenuClick`：`FPopupItem` がツリーに無ければ nil にして、番号の処理（14章・`ImportWithDialog`・`ExportWithDialog`）を呼ぶ。

### 10.2 追加・編集のダイアログ（EditDialog）

`EditDialog(題, var 名前, var 場所, 場所あり)`：

1. `TForm.CreateNew(GetParentForm(Self))`、`bsDialog`、`poOwnerFormCenter`、幅 440（96dpi 換算。以下同じ）。
2. 「名前」のラベルと `FDlgName`。場所ありなら「URL またはファイルパス」のラベルと `FDlgLoc`。どちらも `OnChange := DlgChange`。
3. ［OK］（`FDlgOk`、`mrOk`、`Default`）と［キャンセル］（`mrCancel`、`Cancel`）を右下に並べる。`ActiveControl := FDlgName`、`DlgChange(nil)`。
4. `ShowModal = mrOk` なら、`Trim` した値を返して `True`。
5. finally で `FDlgName`・`FDlgLoc`・`FDlgOk := nil`、`Free`。

`DlgChange`：`FDlgOk.Enabled := (名前が空でない) and (場所なし or CBClassifyLocation(場所))`。

### 10.3 キー

`TreeKeyDown`：ドラッグ中なら、Esc で `EndInternalDrag(False)`、どのキーも `Key := 0` で抜ける。

| キー | 処理 |
|---|---|
| Enter | `DoItemClick(選択)` |
| Delete | 選択があれば `DoMenuDelete` |
| F2 | 区切り線以外なら `DoMenuEdit` |
| Ctrl+X・Ctrl+C | `DoMenuCut`・`DoMenuCopy` |
| Ctrl+V | 検索中でなく、写しか切取りがあれば `DoMenuPaste(選択)` |
| Ctrl+F | `FSearch.SetFocus`、`SelectAll` |

`SearchKeyDown`：Esc → `SetSearchText('')`。↓・Enter → 行があれば、選択が無ければ最初の行を選び、ツリーへフォーカス。どちらも `Key := 0`。

### 10.4 検索

| 手続き | 処理 |
|---|---|
| `SearchChange` | `FSearchTimer` を止めて動かし直す（入力の 300ms 後） |
| `SearchTimer` | 止める。設計時なら何もしない。`K := CBNormalize(Trim(文字))`。`K` と検索中かが前と同じなら何もしない。選択を覚え、`FSearchKey := K`、`FSearching := K <> ''`、`BuildTree`、`SelectItem(覚えた項目)`、`CheckSelection` |
| `SetSearchText` | `FSearch.Text := 値`（`OnChange` でタイマーが動く）。タイマーを止めて、すぐ `SearchTimer(nil)` |

- 検索中にできない操作（貼り付け・追加・インポート・ドラッグでの移動・外からのドロップ）は、メニューを灰色にし、14章の手続きの頭でも `FSearching` なら抜ける。入れる位置が決まらないため。

## 11. ドラッグ＆ドロップ

### 11.1 外からのドロップ（TCBookmarkDropTarget）

| メソッド | 処理 |
|---|---|
| `DragEnter` | 検索中でなく、自分の OLE のドラッグ中でもなく、`CF_HDROP`・`UniformResourceLocatorW`・`CF_UNICODETEXT`（`://` を含む）のどれかがあれば受ける。受けるなら `FExtDragging := True`、`BeginDragTimer`、効果を選ぶ（リンクがあればリンク、無ければコピー）。受けなければ効果なし |
| `DragOver` | 受けないなら効果なし。`CalcDrop` できれば `ShowIndicator`・効果を選ぶ。できなければ `HideIndicator`・効果なし |
| `DragLeave` | `HideIndicator`、`FExtDragging := False`、`EndDragTimer`、受けない状態に戻す |
| `Drop` | 同じ後片付けの後、`CalcDrop` できなければ効果なし。`CF_HDROP` があればファイル名を `FPendingFiles` へ（`DragQueryFileW`）。無ければ URL を `UniformResourceLocatorW`、無ければ `CF_UNICODETEXT`（`://` を含む 1 行目）から取り、`FPendingIsUrl`・`FPendingUrl`・`FPendingTitle`（`FileGroupDescriptorW` の最初のファイル名から .url を外したもの）。何も無ければ効果なし。位置を `FPendingTarget`・`FPendingPos` に覚え、`Application.QueueAsyncCall(AsyncExternalDrop)` |

- ドロップの処理の中で登録しない理由：確認のメッセージ（11.2 の件数）で、ドラッグ元のアプリ（エクスプローラー等）を止めないため。

`AsyncExternalDrop`：`FPendingTarget` がツリーに無ければ nil。URL なら `DoDropUrl`、ファイルなら写した一覧で `DoDropFiles`。後片付け。

### 11.2 ファイル・URL の登録

`DoDropFiles(ファイル, 的, 位置)`：

1. 空・検索中なら何もしない。
2. ファイルごとに、.lnk のリンク先がフォルダーならリンク先、フォルダーなら `CountDirEntries(フォルダー, MaxInt div 2)` を足し合わせる。500 を超えたら「n 件を登録しますか？」。いいえなら抜ける。
3. `DropDest` で入れる親と位置を決め、砂時計のカーソルで、ファイルごとに `ItemFromPath(ファイル, True)` を順に入れる（位置を 1 ずつ進める）。
4. 1 つでも入れたら `Changed(最後に入れた項目)`。

`ItemFromPath(パス, リンクをたどる)`：

| パス | 作る項目 |
|---|---|
| フォルダー（`C:` は `C:\` にする） | フォルダー。名前はフォルダー名（ドライブならパス）。`AddDirContents` で中身を入れる |
| .url で URL が読める | `NewLink(.url を除いた名前, URL)` |
| .lnk（たどるときだけ）でリンク先が読める | リンク先がフォルダーなら `ItemFromPath(リンク先, False)` の名前を .lnk を除いた名前にする。ファイルならファイルの項目（名前は .lnk を除いた名前、場所はリンク先） |
| それ以外 | ファイル。名前はファイル名 |

`AddDirContents(フォルダー, パス)`：`FindFirst` で、`.`・`..` を除き、フォルダー（シンボリックリンク・ジャンクションは除く）とファイルに分け、それぞれ大文字小文字を区別せずに並べる。フォルダーを先に、同じ手続きで中身を入れる。ファイルは `ItemFromPath(…, False)`（中の .lnk はたどらない。同じ所を何度も回らないため）。

`CountDirEntries(パス, 上限)`：`.`・`..` を除いて数え、リンクでないフォルダーは中も数える。上限を超えたら止める。

`DoDropUrl(URL, タイトル, 的, 位置)`：検索中なら何もしない。`NewLink(タイトル, URL)`、`DropDest`、`DoInsert`、`Changed`。

### 11.3 部品の中のドラッグ

| 手続き | 処理 |
|---|---|
| `TreeMouseDown`（左） | `FDragStarted`・`FDragArmed := False`、`FDownItem := nil`。［▶］の上なら抜ける。`FDownItem := 押した行の項目`。項目があり検索中でなければ `FDragArmed := True`、位置を覚える |
| `TreeMouseMove` | ドラッグ中なら `DragMoveTo`。`FDragArmed` でなければ抜ける。左ボタンが離れていれば `FDragArmed := False`。押した位置から `SM_CXDRAG`・`SM_CYDRAG` 以上動いたら、`FDownItem` がツリーにあるときだけ始める：`FDragActive`・`FDragStarted := True`、`FDragItem := FDownItem`（選択ではなく押した項目）、`FTree.MouseCapture := True`（外で離しても `MouseUp` を受ける）、`FAppTarget := nil`、`BeginDragTimer`、`DragMoveTo` |
| `TreeMouseUp`（左） | `FDragArmed := False`。ドラッグ中なら `EndInternalDrag(True)`。ドラッグした後なら `FDragStarted := False` で抜ける（クリックにしない）。Shift・Ctrl・Alt があれば抜ける。［▶］の上なら抜ける（TTreeView が開閉する）。離した行の項目が `FDownItem` と同じときだけ `DoItemClick` |
| `CalcDrop(X, Y, out 的, out 位置)` | 検索中なら `False`。行が無ければ的 nil（一番下）・`True`。フォルダーは高さの上 1/4 で前、下 1/4 で後、ほかは中。フォルダー以外は上半分で前、下半分で後 |
| `CanDropItem(ドラッグ, 的, 位置)` | ドラッグがツリーに無い、的がドラッグ自身なら `False`。`DropDest` の親がドラッグ自身か配下なら `False` |
| `UpdateInternalDrag(X, Y)` | ツリーの中で `CalcDrop` と `CanDropItem` が通れば、`FDropOk := True`、的・位置を覚え、`ShowIndicator`、カーソル `crDrag`。でなければ `HideIndicator`、`crNoDrop` |
| `EndInternalDrag(落とす)` | `FDragActive`・`FDragArmed := False`、`MouseCapture := False`、カーソルを戻す。落とさないなら `FDropOk := False`。同じアプリの部品の上なら 11.4。`FinishInternalDrop` |
| `FinishInternalDrop` | `FDragItem := nil`、`HideIndicator`、`EndDragTimer`。`FDropOk` で、的が nil かツリーにあれば `DoDropItem(項目, 的, 位置)` |

- 離したときは、最後に線・枠を出した位置に入れる（見えている位置と同じにするため）。

`DragTimer`（100ms、`BeginDragTimer` で `FHoverItem := nil` にして動かす）：

1. マウスがツリーの横の範囲にあり、上端から 16px（96dpi 換算）以内なら `WM_VSCROLL SB_LINEUP`、下端から 16px 以内なら `SB_LINEDOWN`。
2. 部品の中のドラッグ中で、マウスがツリーの中なら `UpdateInternalDrag`（スクロールしたら線を出し直す）。
3. `CalcDrop` が閉じたフォルダーの中なら、同じフォルダーで 1000ms 続いたら `Expanded := True`（開閉の通知で保存される）。

### 11.4 外へのドラッグ

`DragMoveTo(X, Y)`（X・Y はツリーの座標）：

| マウスの位置 | 処理 |
|---|---|
| ツリーの中 | `LeaveAppTarget`、`UpdateInternalDrag` |
| 同じアプリ（`WindowFromPoint` のウィンドウのプロセスが自分） | `FDropOk := False`、`HideIndicator`。`FindDragTarget(画面の位置, False)` の部品（TCBookmark とその中の部品は除く。`IsOwnPart`）。前と違えば `LeaveAppTarget` して `dsDragEnter`、同じなら `dsDragMove`。部品があれば `TCBControlAccess(部品).DragOver(Self, X, Y, 状態, FAppAccept)`。受けるなら `crDrag`、でなければ `crNoDrop` |
| アプリの外 | `LeaveAppTarget`。`CanOleDrag(FDragItem)`（URL か、ある ファイル）なら `StartOleDrag`、でなければ `crNoDrop`（ドラッグは続ける） |

`LeaveAppTarget`：`FAppTarget` があれば外し、`DragOver(…, dsDragLeave, …)` を知らせる。

`EndInternalDrag` の同じアプリの部品：落とすときで `FAppAccept` なら、部品を外してから `DragDrop(Self, X, Y)`（例外は `Application.HandleException`）。`FinishInternalDrop` の前に呼ぶので、`OnDragDrop` の中でも `DragItem` が使える。落とさないなら `LeaveAppTarget`。

`StartOleDrag`：

1. 部品の中のドラッグを終える（`FDragActive`・`FDragArmed`・`FDropOk := False`、`MouseCapture := False`、`HideIndicator`、`EndDragTimer`、カーソルを戻す）。TCBookmark のデータは変えない。
2. `FOleDragging := True`（自分のツリーでは受けない。11.1）。
3. URL：`TCBookmarkUrlData.Create(名前, URL)` を、効果 コピー・リンクで `SHDoDragDrop(FTree.Handle, …)`。
4. ファイル：`CBGetShellDataObject`（`ILCreateFromPathW` → `SHBindToParent` → `GetUIObjectOf(IDataObject)`。エクスプローラーと同じシェルのデータ）を、効果 リンクだけで `SHDoDragDrop`（ショートカットができ、コピー・移動はされない）。
5. finally で `FOleDragging := False`、`FDragItem := nil`。

- `SHDoDragDrop` は、落とす・取りやめるまで戻らない。Esc・右ボタンはシェルが扱う。ドラッグの絵は出さない。
- OLE のドラッグに移った後は、LCL の部品へは渡せない（OLE のドラッグは LCL の部品に届かない）。

`TCBookmarkUrlData`：

| 番号 | 形式 | 中身 |
|---|---|---|
| 0 | `FileGroupDescriptorW` | ファイル 1 つ。`dwFlags := FD_LINKUI（$8000）`、名前は `CBSafeFileName(名前, ホスト) + '.url'` |
| 1 | `FileContents`（`lindex` 0 か -1） | `[InternetShortcut]` CRLF `URL=（CBUrlToAscii(URL)）` CRLF（ANSI） |
| 2・4 | `UniformResourceLocatorW`・`CF_UNICODETEXT` | URL（UTF-16、#0 付き） |
| 3 | `UniformResourceLocator` | `CBUrlToAscii(URL)`（#0 付き） |

- どれも `TYMED_HGLOBAL`。`GetData` で毎回 `GlobalAlloc` して渡す（受けた側が解放する）。`QueryGetData` は形式があれば `S_OK`。`EnumFormatEtc` は `DATADIR_GET` だけ `SHCreateStdEnumFmtEtc`。`GetDataHere`・`GetCanonicalFormatEtc`・`SetData` は `E_NOTIMPL`、`DAdvise` 系は `OLE_E_ADVISENOTSUPPORTED`。
- `CBSafeFileName`：`Trim`、`\ / : * ? " < > |` と制御文字を `_`、末尾の `.`・空白を除く、200 文字まで。空ならホストの `CBHostFileKey`、それも空なら 'link'。
- `CBUrlToAscii`：128 以上のバイトを `%XX` にする。

## 12. インポート・エクスポート

### 12.1 インポート

`ImportFromFile(F)`：

1. `CBReadFileText`。読めなければ「インポートできません：（理由）」で `False`。
2. フォルダー「インポート yyyy-mm-dd」（開いた状態）を作り、`ParseHtml(中身, フォルダー)`。
3. 入れた URL・ファイルが 0 件ならフォルダーを解放して `False`。
4. `Root` の末尾に入れ、`Changed(フォルダー)`、`True`。

`ParseHtml(S, 入れ先)`：`<` から次の `>` までを 1 つのタグとして読む（引用符の中の `>` は飛ばす。`<!-- -->` は飛ばす。タグ名は英数字、大文字小文字を区別しない）。入れる親は積み上げ（Stack）の一番上（空なら入れ先）。

| タグ | 処理 |
|---|---|
| `<DL>` | 直前の `<H3>` のフォルダーがあればそれを、積み上げが空なら入れ先を、それ以外は今の親を積む。直前のフォルダーを忘れる |
| `</DL>` | 積み上げから 1 つ下ろす |
| `<H3>` | `</h3` までの文字（タグを外し、文字参照を戻す）を名前にしたフォルダーを作る。`ADD_DATE`（1970 年からの秒）があれば登録日時。今の親に入れ、直前のフォルダーとして覚える |
| `<A>` | 直前のフォルダーを忘れる。`HREF`（文字参照を戻す）・`ICON`・`</a` までの文字を読む。`ICON` が `data:…;base64,…` で、そのホストのアイコンがまだ無ければ、先に `SaveHostIcon`（取りに行かないようにするため）。`NewLink(文字, HREF)`（決められなければ読み飛ばす）。`ADD_DATE` があれば登録日時。今の親に入れ、数える |
| `<HR>` | 直前のフォルダーを忘れる。区切り線を入れる |

- 閉じタグの無い書き方（`<DT>`・`<p>`）は、ほかのタグとして無視される。
- `CBTagAttr(タグ, 名前)`：`名前=` の前が空白のものだけを探す（`ICON` と `ICON_URI` を取り違えない）。値は `"…"`・`'…'`・空白か `>` まで。

`ImportWithDialog`：`TOpenDialog`（HTML のフィルター、`ofFileMustExist`）。`ImportFromFile` が `False` で、ファイルがあれば「ブックマークが見つかりませんでした。」。

### 12.2 エクスポート

`ExportToFile(F)`：`TStringList`（`LineBreak := CRLF`）に次を書き、`CBWriteFileText`（UTF-8、BOM なし）。書けなければ「エクスポートできません：（理由）」で `False`。

```html
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
    （WriteLevel(Root, 4 文字の字下げ)）
</DL><p>
```

| 種類 | 書くもの |
|---|---|
| URL | `<DT><A HREF="URL" ADD_DATE="秒" ICON="data:image/png;base64,…">名前</A>`（アイコンのファイルがあるときだけ ICON。.ico は `data:image/x-icon`） |
| ファイル | `<DT><A HREF="（CBPathToFileUrl）" ADD_DATE="秒">名前</A>` |
| 区切り線 | `<HR>` |
| フォルダー | `<DT><H3 ADD_DATE="秒">名前</H3>`、`<DL><p>`、中身（字下げ +4）、`</DL><p>` |

- 名前・HREF は `CBHtmlEscape`。`ADD_DATE` は `DateTimeToUnix`。

`ExportWithDialog`：`TSaveDialog`（HTML のフィルター、既定の拡張子 html、名前 bookmarks.html、`ofOverwritePrompt`）。

## 13. 切取り・コピー・貼り付け

| 手続き | 処理 |
|---|---|
| `DoMenuCut(It)` | ツリーに無ければ何もしない。`FClip` を解放、`FCutItem := It`（元の場所に残す）、`CBPutClipboardText(It)` |
| `DoMenuCopy(It)` | `FClip` を解放、`FCutItem := nil`、`FClip := It.Clone`（フォルダーは中身ごと）、`CBPutClipboardText(It)` |
| `DoMenuPaste(It)` | 検索中なら何もしない。`It` がツリーに無ければ nil。`InsertPos`。切取りなら：`FCutItem` がツリーに無ければ取り消して抜ける。入れる親が `FCutItem` 自身か配下なら何もしない。`FCutItem := nil`、`MoveInternal` できたら `Changed`。コピーなら：`FClip.Clone`（何度でも貼れるように写しの写し）、`RefreshMissing(写し, True)`、`DoInsert`、`Changed` |
| `CBPutClipboardText(It)` | URL・ファイルの場所を集め（フォルダーは中を順に）、CRLF でつないで `Clipboard.AsText`。1 つも無ければ入れない。クリップボードの例外は無視する |

## 14. 操作を受けたときの処理（protected）

マウス・キー・メニュー・ドロップは、次のメソッドを呼ぶだけにする。

| メソッド | 呼ばれる操作 | 処理 |
|---|---|---|
| `DoItemClick(It)` | 左クリック・Enter | フォルダー：検索中でなく行があれば開閉を切り替える。URL：`TargetBrowser` があれば `OpenItem(btBrowser, False)`。ファイル：`TargetEditor` があれば `OpenItem(btEditor, False)`。区切り線・nil：何もしない |
| `DoMenuOpen(It, 先, 新)` | 開く 4 項目 | `OpenItem` |
| `DoMenuEdit(It)` | 編集・F2 | 区切り線・ツリーに無ければ何もしない。フォルダーは「フォルダー名を編集」で名前だけ。URL・ファイルは「ブックマークを編集」で名前と場所。場所を `CBClassifyLocation` し、種類・場所を入れ替える（種類が変わってもよい）。ファイルは `FFileMissing`、URL はホストが変わったら `RequestFavicon`。`Changed(It)` |
| `DoMenuDelete(It)` | 削除・Delete | フォルダーだけ「フォルダー「名前」と中の n 件を削除しますか？」（`DescendantCount`）。はいなら `DeleteItem` |
| `DoMenuCut`・`DoMenuCopy`・`DoMenuPaste` | 切取り・コピー・貼り付け | 13章 |
| `DoMenuAddBookmark(It)` | ブックマークを追加 | 検索中なら何もしない。「ブックマークを追加」（空）。`NewLink`、`InsertPos`、`DoInsert`、`Changed` |
| `DoMenuAddFolder(It)` | フォルダーを追加 | 「フォルダーを追加」（最初は「新しいフォルダー」）。同じように入れる |
| `DoMenuAddSeparator(It)` | 区切り線 | 区切り線を同じように入れる |
| `DoDropItem(It, 的, 位置)` | 部品の中のドラッグ | 検索中・`CanDropItem` が通らなければ何もしない。`DropDest`、`MoveInternal` できたら `Changed(It)` |
| `DoDropFiles`・`DoDropUrl` | 外からのドロップ | 11.2 |

## 15. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| 起動しても何も出ない | `CreateWnd` の `FDataLoaded`、`LoadData` の場所（7.1・7.2） |
| 保存されない | `SaveData` の `MoveFileExW`、`FSaveErrorShown`（7.3）。EXE の場所に書けるか |
| bookmarks.json.broken-… ができる | `LoadData` の例外（JSON の形）（7.2） |
| `OnSelectionChange` が多い・出ない | `FUpdating` と `CheckSelection` を呼ぶ場所（7.5） |
| 無いファイルが灰色にならない | `RefreshMissing` を呼ぶ時点（7.6）、`TreeDrawItem`（8.2） |
| favicon が出ない | `RequestFavicon` の `FFetchTried`、スレッドの状態 200・中身の形、`SaveHostIcon`（8.3） |
| ドラッグで動かない | `TreeMouseMove` のしきい値、`CanDropItem`、`FinishInternalDrop` の `FDropOk`（11.3） |
| 外からドロップできない | `TCBookmarkTree.CreateWnd` の `RegisterDragDrop`、`DragEnter` の条件（検索中・自分の OLE のドラッグ中）（11.1） |
| ドロップしたのに登録されない | `AsyncExternalDrop`、`FPendingTarget` がツリーにあるか（11.1） |
| 外へドラッグできない | `DragMoveTo` の `WindowFromPoint`、`CanOleDrag`、`CBGetShellDataObject`（11.4） |
| 同じアプリの部品に渡らない | `FindDragTarget`・`IsOwnPart`、部品の `OnDragOver`（11.4） |
| ファイルが別のタブで開かれない・エラー | `OpenInEditor` の順番（9.3） |
| インポートで件数が 0 | `ParseHtml` のタグの読み方、`NewLink` で決められない HREF（12.1） |
