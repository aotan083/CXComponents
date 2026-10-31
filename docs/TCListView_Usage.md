# TCListView 取扱説明書

作者: aotan083
日付: 2026-10-31
版: 1.1

---

## 1. 概要とクラス

Windows のエクスプローラーの右側と同じように使える、ファイルとフォルダーの一覧です。フォームに置くだけで、開く・コピー・移動・削除・名前の変更・新しいフォルダーの作成・ドラッグ＆ドロップ・右クリックメニューが、エクスプローラーと同じように動きます。アプリ側でコードを書く必要はありません。

```
名前              サイズ    種類     更新日時
-------------------------------------------------------
images                      フォルダ  2026/10/19 21:30
README.md          4 kB     md       2026/10/19 22:05
sample.pas        12 kB     pas      2026/10/18 10:12
```

- 表示形式は、詳細・大アイコン・小アイコン・一覧の4つ。
- 列見出しをクリックすると並べ替える（フォルダーが常に先）。
- 戻る・進む（フォルダーの履歴）に対応している。マウスの戻る・進むボタンも使える。
- ほかのアプリやエクスプローラーでファイルが変わると、表示も自動で更新される。
- TCTreeView（フォルダーのツリー）とつなぐと、ツリーで選んだフォルダーの中身を表示する。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCListView` | `CListView` | cx | `TShellListView`（LCL、`ShellCtrls`） | エクスプローラーの右側と同じように使える、ファイルとフォルダーの一覧。開く・コピー・移動・削除・名前の変更・新しいフォルダーの作成・ドラッグ＆ドロップ・右クリックメニューが、コードを書かずに動く |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCExtraMenuPosition` | `CShellMenu` | 右クリックメニューに足す項目の位置。`empTop`（メニューの先頭）・`empBottom`（メニューの末尾） |

- フォームに置くと、uses に `CListView` が自動で入る。
- フォームに置くと、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。`ExtraMenuPosition` に値を入れるときは、uses に `CShellMenu` も書く。

## 2. フォームに置いて動かすまで

### 2.1 一覧だけを使う

1. パレット [CX] から、TCListView をフォームに置く。
2. オブジェクトインスペクタの `Root` に、最初に表示するフォルダーを入れる（実行時に `NavigateTo` で指定してもよい）。
3. 表示中のフォルダーを画面に出すときは、イベントタブの `OnFolderChanged` をダブルクリックして処理を書く（6.1）。
4. 実行する。ダブルクリック・Enter でフォルダーに入り、BackSpace で親に戻る。

### 2.2 TCTreeView（フォルダーのツリー）とつなぐ

1. TCTreeView と TCListView をフォームに置く。
2. TCListView の `ShellTreeView` に、TCTreeView を選ぶ。
3. 実行する。ツリーでフォルダーを選ぶと、一覧がそのフォルダーに移る（一覧で移っても、ツリーの選択は変わらない）。

## 3. 表示

### 3.1 列（詳細表示）

| 列 | 見出し | 中身 |
|---|---|---|
| 0 | 名前 | ファイル名・フォルダー名（拡張子を含む）。残りの幅に自動で合わせる |
| 1 | サイズ | ファイルの大きさ（bytes・kB・MB・GB） |
| 2 | 種類 | 拡張子。フォルダーは「フォルダ」 |
| 3 | 更新日時 | YYYY/MM/DD HH:NN |

### 3.2 表示形式

| `ViewStyle` | 表示 |
|---|---|
| `vsReport` | 詳細（既定値） |
| `vsIcon` | 大アイコン |
| `vsSmallIcon` | 小アイコン |
| `vsList` | 一覧 |

- 表示形式はフォルダーごとには覚えず、一覧全体で1つ。

### 3.3 並べ替え

- 起動したときは、種類の昇順（同じ種類の中は名前の順）。
- 名前は、エクスプローラーと同じ自然順（数字を数の大きさで比べる）で並べる。
- フォルダーは、どの列で並べ替えても、いつも先に並ぶ。

## 4. プロパティ

### 4.1 この部品で足したもの

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `ExtraItemMenu` | `TPopupMenu` | 読み・書き | 項目の上で右クリックしたときに、メニューへ足す項目 |
| `ExtraBackgroundMenu` | `TPopupMenu` | 読み・書き | 何もない所で右クリックしたときに、メニューへ足す項目 |
| `ExtraMenuPosition` | `TCExtraMenuPosition` | 読み・書き | 足す項目の位置。`empTop`：メニューの先頭。`empBottom`（既定値）：メニューの末尾 |
| `AutoFitNameColumn` | `Boolean` | 読み・書き | 名前の列を、残りの幅に自動で合わせるか（既定値は `True`）。列の幅を手で変えると `False` になる。`True` を書くと自動に戻る。実行時だけ |
| `MaxHistory` | `Integer` | 読み・書き | 戻る・進むの履歴の上限（既定値は 20。最小は 2）。超えたら古いものから消す。実行時だけ |
| `SortColumn` | `Integer` | 読み | 並べ替えている列（既定値は 2）。0：名前、1：サイズ、2：種類、3：更新日時。実行時だけ |
| `SortAscending` | `Boolean` | 読み | 昇順なら `True`。実行時だけ |

### 4.2 TShellListView から引き継いだもの

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Align` | `TAlign` | 読み・書き | 親の中での配置 |
| `Anchors` | `TAnchors` | 読み・書き | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `AnchorSideBottom` | `TAnchorSide` | 読み・書き | 下の辺を、どの部品のどこに合わせるか |
| `AnchorSideLeft` | `TAnchorSide` | 読み・書き | 左の辺を、どの部品のどこに合わせるか |
| `AnchorSideRight` | `TAnchorSide` | 読み・書き | 右の辺を、どの部品のどこに合わせるか |
| `AnchorSideTop` | `TAnchorSide` | 読み・書き | 上の辺を、どの部品のどこに合わせるか |
| `BorderSpacing` | `TControlBorderSpacing` | 読み・書き | 周りの余白 |
| `BorderStyle` | `TBorderStyle` | 読み・書き | 枠の線を出すか |
| `BorderWidth` | `TBorderWidth` | 読み・書き | 枠の内側の余白 |
| `Color` | `TColor` | 読み・書き | 背景色（既定値は `clWindow`） |
| `Constraints` | `TSizeConstraints` | 読み・書き | 大きさの上限・下限 |
| `Cursor` | `TCursor` | 読み・書き | 上に来たときのマウスカーソル |
| `DragCursor` | `TCursor` | 読み・書き | ドラッグ中のマウスカーソル |
| `Enabled` | `Boolean` | 読み・書き | 使えるか |
| `Font` | `TFont` | 読み・書き | 文字 |
| `Height` | `Integer` | 読み・書き | 高さ |
| `HelpContext` | `THelpContext` | 読み・書き | ヘルプの番号 |
| `HelpKeyword` | `string` | 読み・書き | ヘルプのキーワード |
| `HelpType` | `THelpType` | 読み・書き | ヘルプを番号で引くか（`htContext`）、キーワードで引くか（`htKeyword`） |
| `HideSelection` | `Boolean` | 読み・書き | フォーカスがないときに、選択の色を消すか |
| `Hint` | `TTranslateString` | 読み・書き | ヒントの文字 |
| `LargeImages` | `TCustomImageList` | 読み・書き | 大アイコンの画像 |
| `LargeImagesWidth` | `Integer` | 読み・書き | 大アイコンの幅 |
| `Left` | `Integer` | 読み・書き | 左端の位置 |
| `Mask` | `string` | 読み・書き | 表示するファイルの絞り込み（例：`*.md`） |
| `MaskCaseSensitivity` | `TMaskCaseSensitivity` | 読み・書き | `Mask` で大文字・小文字を区別するか |
| `MultiSelect` | `Boolean` | 読み・書き | 複数の項目を選べるか（既定値は `True`） |
| `Name` | `TComponentName` | 読み・書き | 部品の名前 |
| `ObjectTypes` | `TObjectTypes` | 読み・書き | 表示するものの種類（既定値は `[otFolders, otNonFolders]`）。隠しファイルも出すときは `otHidden` を足す |
| `ParentColor` | `Boolean` | 読み・書き | 親の色を使うか（既定値は `False`） |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `ParentShowHint` | `Boolean` | 読み・書き | 親の `ShowHint` を使うか |
| `Root` | `string` | 読み・書き | 表示中のフォルダーのフルパス。書くと、そのフォルダーを表示する。末尾に `\` が付くことと付かないことがあるので、比べるときは `ExcludeTrailingPathDelimiter` でそろえる。コードから移るときは `NavigateTo` を使う |
| `RowSelect` | `Boolean` | 読み・書き | 選択の色を行全体に付けるか |
| `ScrollBars` | `TScrollStyle` | 読み・書き | スクロールバーの出し方 |
| `ShellTreeView` | `TCustomShellTreeView` | 読み・書き | つなぐツリー。TCTreeView を選ぶと、ツリーで選んだフォルダーを表示する |
| `ShowColumnHeaders` | `Boolean` | 読み・書き | 列の見出しを出すか |
| `ShowHint` | `Boolean` | 読み・書き | ヒントを出すか |
| `SmallImages` | `TCustomImageList` | 読み・書き | 小アイコンの画像 |
| `SmallImagesWidth` | `Integer` | 読み・書き | 小アイコンの幅 |
| `StateImages` | `TCustomImageList` | 読み・書き | 項目の状態のアイコン |
| `TabOrder` | `TTabOrder` | 読み・書き | Tab キーで移る順番 |
| `TabStop` | `Boolean` | 読み・書き | Tab キーで止まるか |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値 |
| `ToolTips` | `Boolean` | 読み・書き | 入りきらない項目の名前を、マウスを乗せたときに出すか |
| `Top` | `Integer` | 読み・書き | 上端の位置 |
| `ViewStyle` | `TViewStyle` | 読み・書き | 表示形式（3.2）。書くと `SetView` と同じ |
| `Visible` | `Boolean` | 読み・書き | 表示するか |
| `Width` | `Integer` | 読み・書き | 幅 |

## 5. メソッド

### 5.1 フォルダーの移動

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | ― | 作る。コードで作るときに使う（10.11） |
| `NavigateTo` | `const APath: string` | `Boolean` | そのフォルダーを表示する。ない、または表示中と同じなら `False` |
| `NavigateUp` | ― | `Boolean` | 親フォルダーを表示する。ドライブのルート（`C:\` など）では何もしない（`False`） |
| `GoBack` | ― | `Boolean` | 履歴の1つ前のフォルダーへ戻る。移ったら `True`。なくなったフォルダーは飛ばす |
| `GoForward` | ― | `Boolean` | 履歴の1つ次のフォルダーへ進む。移ったら `True`。なくなったフォルダーは飛ばす |
| `CanGoBack` | ― | `Boolean` | 戻れるなら `True` |
| `CanGoForward` | ― | `Boolean` | 進めるなら `True` |
| `ClearHistory` | ― | ― | 履歴を消す（表示中のフォルダーだけ残す） |

- 戻った後に別のフォルダーへ移ると、進む側の履歴は消える（エクスプローラーと同じ）。

### 5.2 ファイルの操作

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `CopySelected` | ― | ― | 選んでいる項目をクリップボードへコピーする（Ctrl+C と同じ。エクスプローラーに貼り付けられる） |
| `CutSelected` | ― | ― | 選んでいる項目を切り取る（Ctrl+X と同じ。貼り付けると移動になる） |
| `PasteToRoot` | ― | ― | 表示中のフォルダーへ貼り付ける（Ctrl+V と同じ）。同じフォルダーへ貼り付けると「～ - コピー」になる。貼り付けた項目が選ばれる |
| `DeleteSelectedFiles` | `APermanent: Boolean = False` | ― | 選んでいる項目を削除する。`False`：ごみ箱へ。`True`：完全に削除。どちらも確認を出す |
| `RenameSelectedFile` | ― | ― | 選んでいる項目の名前の変更を始める（F2 と同じ）。変えられなかったときは、Windows が理由を出し、名前を元に戻す |

### 5.3 表示形式・並べ替え

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `SetView` | `AStyle: TViewStyle` | ― | 表示形式を変える（3.2） |
| `SortBy` | `AColumn: Integer; AAscending: Boolean` | ― | 並べ替える。`AColumn`：0：名前、1：サイズ、2：種類、3：更新日時。フォルダーはいつも先 |

### 5.4 選択

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `SelectAllItems` | ― | ― | すべて選ぶ（Ctrl+A と同じ） |
| `GetSelectedFilePath` | ― | `string` | 選んでいる先頭の項目のフルパス。選んでいなければ '' |
| `GetSelectedPaths` | `AList: TStrings` | ― | 選んでいるすべての項目のフルパスを `AList` に入れる（先に `AList` を空にする） |
| `SelectNewItemsOnNextRefresh` | ― | ― | 次に表示を更新したとき、新しく現れた項目を選ぶ。アプリでファイルを作ったときなどに使う（10.9） |

### 5.5 ユニットの関数

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `BuildRenamedPath` | `const AOldPath, ADisplayName, ANewName: string` | `string` | 名前を変えた後のフルパスを作る。拡張子を表示しない設定のときも、元の拡張子を補う |

## 6. イベント

### 6.1 この部品で足したもの

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnFolderChanged` | `Sender: TObject` | 表示中のフォルダー（`Root`）が変わった |
| `OnSelectionChanged` | `Sender: TObject` | 選んでいる項目が変わった |

- どちらも、変わった理由（マウス、キー、ツリー、コード）に関係なく、変わるたびに1回ずつ出る。アプリの手が空いたとき（アイドル時）に出る。
- `OnFolderChanged` は、ダブルクリック・Enter・BackSpace・ツリーでの選択・`NavigateTo`・`NavigateUp`・`GoBack`・`GoForward`（マウスの戻る・進むボタンを含む）・表示中のフォルダーが消えて親へ移ったときに出る。F5 や自動更新では出ない。
- `OnSelectionChanged` は、Shift・Ctrl・Ctrl+A での複数選択の変化を1回にまとめる。フォルダーを移った直後（選択がなくなる）にも出る。自動更新で選択が変わらなければ出ない。

### 6.2 TShellListView から引き継いだもの

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnChange` | `Sender: TObject; Item: TListItem; Change: TItemChange` | 項目が変わった |
| `OnClick` | `Sender: TObject` | クリックされた |
| `OnContextPopup` | `Sender: TObject; MousePos: TPoint; var Handled: Boolean` | 右クリックメニューを出す直前。`Handled := True` で出さない |
| `OnDblClick` | `Sender: TObject` | ダブルクリックされた。これを設定すると、部品のダブルクリックの動き（フォルダーへ移る、ファイルを開く）は行わない |
| `OnDeletion` | `Sender: TObject; Item: TListItem` | 項目が一覧から消える |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | LCL のドラッグ（アプリの中の部品どうし）でドロップされた |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | LCL のドラッグで、ドラッグしている物が上に来た。`Accept` で受けるかを決める |
| `OnEditing` | `Sender: TObject; Item: TListItem; var AllowEdit: Boolean` | 名前の変更を始める前。`AllowEdit := False` で取りやめる |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | LCL のドラッグが終わった |
| `OnFileAdded` | `Sender: TObject; Item: TListItem` | ファイルを項目として足した後 |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | キーが押された |
| `OnKeyPress` | `Sender: TObject; var Key: Char` | 文字のキーが押された |
| `OnKeyUp` | `Sender: TObject; var Key: Word; Shift: TShiftState` | キーが離された |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが押された |
| `OnMouseEnter` | `Sender: TObject` | マウスが上に入った |
| `OnMouseLeave` | `Sender: TObject` | マウスが外に出た |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | マウスが動いた |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが離された |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | ホイールが回された |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが手前に回された |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが奥に回された |
| `OnMouseWheelHorz` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | 横のホイールが回された |
| `OnMouseWheelLeft` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | 横のホイールが左に回された |
| `OnMouseWheelRight` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | 横のホイールが右に回された |
| `OnResize` | `Sender: TObject` | 大きさが変わった |
| `OnSelectItem` | `Sender: TObject; Item: TListItem; Selected: Boolean` | 項目1つの選択が変わった（複数選択では項目ごとに出る。まとめて知るときは `OnSelectionChanged`） |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | LCL のドラッグを始めた |
| `OnUTF8KeyPress` | `Sender: TObject; var UTF8Key: TUTF8Char` | 文字のキーが押された（UTF-8 の1文字） |

- ファイルのコピー・移動・削除・名前の変更を知らせるイベントはない。表示は部品が自動で更新する。
- 部品が使っているキー（Enter・BackSpace・Delete・Shift+Delete・F2・F5・Ctrl+A・Ctrl+C・Ctrl+X・Ctrl+V・Ctrl+Shift+N・Ctrl+Shift+2・4・5・6）を、`OnKeyDown` やフォームの `OnKeyDown`（`KeyPreview = True`）で `Key := 0` にすると、部品の動作が止まる。

## 7. 操作

### 7.1 キー

| キー | 動作 |
|---|---|
| Enter | 選んでいる項目を開く（フォルダーは移動、ファイルは関連付けられたアプリで開く） |
| BackSpace | 親フォルダーへ移動 |
| Ctrl+C | コピー |
| Ctrl+X | 切り取り |
| Ctrl+V | 表示中のフォルダーへ貼り付け |
| Ctrl+A | すべて選ぶ |
| Ctrl+Shift+N | 新しいフォルダーを作り、名前の変更を始める |
| Ctrl+Shift+2 | 大アイコン |
| Ctrl+Shift+4 | 小アイコン |
| Ctrl+Shift+5 | 一覧 |
| Ctrl+Shift+6 | 詳細 |
| Delete | ごみ箱へ移動（確認あり） |
| Shift+Delete | 完全に削除（確認あり） |
| F2 | 名前の変更 |
| F5 | 最新の状態に更新（すべて読み直す） |

### 7.2 マウス

| 操作 | 動作 |
|---|---|
| ダブルクリック | フォルダーは移動、ファイルは開く（`OnDblClick` を設定したときは、そちらだけ） |
| 列見出しのクリック | その列で並べ替える（もう一度クリックすると昇順・降順が切り替わる） |
| 列の境目のドラッグ | 列の幅を変える（以後、名前の列の自動調整は止まる） |
| マウスの戻るボタン | 履歴の1つ前のフォルダーへ |
| マウスの進むボタン | 履歴の1つ次のフォルダーへ |

### 7.3 右クリックメニュー

| 場所 | メニュー |
|---|---|
| 項目の上 | エクスプローラーと同じメニュー（開く、送る、切り取り、コピー、削除、名前の変更、プロパティなど）＋ `ExtraItemMenu` の項目 |
| 何もない所 | 表示（大アイコン・小アイコン・一覧・詳細）、並べ替え（名前・サイズ・種類・更新日時、昇順・降順）、新規フォルダー、新規テキスト ドキュメント、貼り付け ＋ エクスプローラーと同じメニュー ＋ `ExtraBackgroundMenu` の項目 |

- 同じ TPopupMenu を `ExtraItemMenu` と `ExtraBackgroundMenu` の両方に設定してもよい。
- 表示する直前に項目の有効・無効を変えたいときは、TPopupMenu の `OnPopup` に書く。
- 「名前の変更」を選ぶと、F2 と同じ名前の変更が始まる。
- メニューから起動するアプリには、エクスプローラーと同じく作業フォルダーが渡される（何もない所：表示中のフォルダー、項目の上：その項目があるフォルダー）。

### 7.4 ドラッグ＆ドロップ

| 項目 | 動作 |
|---|---|
| 相手 | アプリ内（一覧 ⇔ 一覧、一覧 ⇔ ツリー）、エクスプローラー・デスクトップ・ほかのアプリと双方向 |
| ドラッグの開始 | 項目の上でボタンを押し、少し動かす。対象は選んでいるすべての項目 |
| コピーか移動か | エクスプローラーと同じ。同じドライブなら移動、別のドライブならコピー。Ctrl でコピー、Shift で移動、Alt でショートカットを作る |
| 右ボタンでドラッグ | ドロップしたときにメニュー（ここにコピー、ここに移動、ショートカットを作成など）を出す |
| ドロップ先 | フォルダーの項目：そのフォルダー、ZIP：ZIP に追加、何もない所・ファイルの項目：表示中のフォルダー |
| できない操作 | 自分自身・自分の中のフォルダーへのドロップ、同じフォルダーへの移動（Ctrl を押したコピーは「～ - コピー」になる） |
| ドラッグ中 | ドロップ先を枠で強調、上下の端で自動スクロール |
| 取りやめ | Esc |

コピー・移動・上書きの確認・進み具合の表示は、エクスプローラーと同じく Windows が行う。

## 8. 自動更新

- ほかのアプリやエクスプローラーで、表示中のフォルダーの中身が変わると、表示が自動で更新される。
- 更新しても、選択（複数でも）、フォーカス、スクロールの位置は保たれる。貼り付け・ドロップした後は、追加された項目が選ばれる。
- 表示中のフォルダーが消えた場合は、残っている親フォルダーを表示する。
- 名前の変更中・ドラッグ中は、終わるまで更新を待つ。

## 9. 注意

### 9.1 変えないでください

次のプロパティは部品の中で使っている。値を変えると、正しく動かなくなる。

| 名前 | 理由 |
|---|---|
| `OnEdited` | 名前の変更に使っている |
| `OnColumnClick` | 列見出しのクリックでの並べ替えに使っている |
| `OnAddItem` | 読み込んだ後の並べ替えと更新日時に使っている |
| `DragMode` | `dmManual` のままにする（ドラッグ＆ドロップは部品が自分で行う） |
| `AutoSizeColumns` | `False` のままにする（`True` にすると、大きさを変えたときに表示がちらつき続ける） |
| `ReadOnly` | 名前の変更の開始・終了で、部品が切り替える |
| `PopupMenu` | 使わない（設定しても出ない）。メニューは `ExtraItemMenu`・`ExtraBackgroundMenu` で追加する |

### 9.2 そのほか

- Windows 専用。
- 管理者として実行したアプリと通常のアプリの間では、ドラッグ＆ドロップできない（Windows の制限）。
- ネットワークドライブでは、変更の通知が届かないことがある。そのときは F5 で更新する。
- 260 文字を超えるパスは、表示できない。
- 1つのフォルダーに 1,000 件程度までのファイルを想定している。
- ファイルが追加されたときは、すべて読み直す。
- ツリーから一覧へドラッグすると、ボタンを押した時点で一覧がそのフォルダーに切り替わるため、自分自身へのドロップとして扱われ、ドロップできない。
- 一覧で移動しても、ツリーの選択は変わらない。
## 10. 使い方の例

### 10.1 表示中のフォルダーを出し、戻る・進むボタンを切り替える

```pascal
procedure TForm1.CListView1FolderChanged(Sender: TObject);
begin
  Edit1.Text := CListView1.Root;
  btnBack.Enabled := CListView1.CanGoBack;
  btnForward.Enabled := CListView1.CanGoForward;
end;

procedure TForm1.btnBackClick(Sender: TObject);
begin
  CListView1.GoBack;
end;

procedure TForm1.btnForwardClick(Sender: TObject);
begin
  CListView1.GoForward;
end;

procedure TForm1.btnUpClick(Sender: TObject);
begin
  CListView1.NavigateUp;
end;
```

### 10.2 TEdit をアドレスバーにする

```pascal
uses
  LCLType;   // VK_RETURN

procedure TForm1.Edit1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    if not CListView1.NavigateTo(Edit1.Text) then
      Edit1.Text := CListView1.Root;   // ないパスなら元に戻す
    Key := 0;
  end;
end;
```

### 10.3 選んだ項目をステータスバーに出す

```pascal
procedure TForm1.CListView1SelectionChanged(Sender: TObject);
var
  Path: string;
begin
  case CListView1.SelCount of
    0: StatusBar1.SimpleText := '';
    1: begin
         Path := CListView1.GetSelectedFilePath;
         if DirectoryExists(Path) then
           StatusBar1.SimpleText := 'フォルダー: ' + Path
         else
           StatusBar1.SimpleText := 'ファイル: ' + Path;
       end;
  else
    StatusBar1.SimpleText := IntToStr(CListView1.SelCount) + ' 個の項目を選択';
  end;
end;
```

### 10.4 表示形式と並べ替えをボタンで変える

```pascal
procedure TForm1.btnIconClick(Sender: TObject);
begin
  CListView1.SetView(vsIcon);     // 大アイコン
  CListView1.SortBy(3, False);    // 更新日時の新しい順
end;
```

### 10.5 決まった種類のファイルだけを出す

```pascal
CListView1.Mask := '*.md;*.txt';   // Markdown とテキストだけ（「;」で区切って複数書ける）
```

### 10.6 ダブルクリックしたファイルを、自分のアプリで開く

```pascal
procedure TForm1.CListView1DblClick(Sender: TObject);
var
  Path: string;
begin
  // OnDblClick を設定すると、部品のダブルクリックの動きは行わない。フォルダーへの移動も自分で書く
  Path := CListView1.GetSelectedFilePath;
  if Path = '' then
    Exit;
  if DirectoryExists(Path) then
    CListView1.NavigateTo(Path)
  else
    Memo1.Lines.LoadFromFile(Path);
end;
```

### 10.7 選んだファイルを、エディタで次々に見る

クリックや矢印キーで項目を移るたびに、そのファイルを TCMonacoEditor に開く。

```pascal
{ 1つ選んだら、ファイルをエディタに開く }
procedure TForm1.CListView1SelectionChanged(Sender: TObject);
var
  Path: string;
begin
  if CListView1.SelCount <> 1 then
    Exit;
  Path := CListView1.GetSelectedFilePath;
  if (Path <> '') and not DirectoryExists(Path) then
    CMonacoEditor1.OpenFile(Path);
end;

{ ダブルクリック・Enter で、関連付けられたアプリが開かないようにする }
procedure TForm1.CListView1DblClick(Sender: TObject);
var
  Path: string;
begin
  // OnDblClick を設定すると、部品のダブルクリックの動き（フォルダーへ移る、ファイルを開く）は行わない。
  // フォルダーへの移動だけ自分で書く。ファイルは選んだ時点でエディタに開いているので、何もしない
  Path := CListView1.GetSelectedFilePath;
  if DirectoryExists(Path) then
    CListView1.NavigateTo(Path);
end;
```

- `OnDblClick` を設定しないと、ダブルクリック・Enter のときに、関連付けられたアプリ（テキストエディタなど）でも同じファイルが開く。同じファイルを2つのアプリで開くと、保存できないことがある。
- `OnDblClick` を空にすると、ファイルは開かなくなるが、フォルダーにも入れなくなる。フォルダーに入るには、上のように `NavigateTo` を書く。
- TCMonacoEditor の `OpenFile` は、いつも新しいタブで開く。選んだファイルの数だけタブが増える。

### 10.8 右クリックメニューにアプリの項目を足す

1. TPopupMenu をフォームに置き、項目（例：「送る」）を作る。
2. TCListView の `ExtraItemMenu` に、その TPopupMenu を選ぶ。
3. TPopupMenu の `OnPopup` と、項目の `OnClick` に、次の処理を書く。

```pascal
{ 1つだけ選んでいるときだけ有効にする }
procedure TForm1.PopupMenu1Popup(Sender: TObject);
begin
  mnuSend.Enabled := CListView1.SelCount = 1;
end;

{ 選んでいる項目を処理する }
procedure TForm1.mnuSendClick(Sender: TObject);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    CListView1.GetSelectedPaths(L);
    // L の各ファイルを処理する
  finally
    L.Free;
  end;
end;
```

- 対象は、項目の上なら `GetSelectedPaths`・`GetSelectedFilePath`、何もない所なら `Root` で取れる。
- メニューに反映されるのは、`Caption`・サブメニュー・区切り線（`Caption = '-'`）・`Enabled`・`Visible`・`Checked`・ショートカットの表示。アイコンは表示されない。

### 10.9 アプリで作ったファイルを、一覧で選ばれた状態にする

```pascal
procedure TForm1.btnNewMemoClick(Sender: TObject);
var
  S: TStringList;
begin
  CListView1.SelectNewItemsOnNextRefresh;   // 次の更新で、新しく現れた項目を選ぶ
  S := TStringList.Create;
  try
    S.Text := 'メモ';
    S.SaveToFile(IncludeTrailingPathDelimiter(CListView1.Root) + 'memo.txt');
  finally
    S.Free;
  end;
end;
```

### 10.10 指定したフォルダーより上に行かせない

この機能は部品にはない。`OnFolderChanged` の中で `Root` を確かめ、範囲の外なら戻す。

```pascal
const
  TopFolder = 'C:\Work';

procedure TForm1.CListView1FolderChanged(Sender: TObject);
var
  Cur, Top: string;
begin
  Cur := ExcludeTrailingPathDelimiter(CListView1.Root);
  Top := ExcludeTrailingPathDelimiter(TopFolder);
  if SameText(Cur, Top) or SameText(Copy(Cur, 1, Length(Top) + 1), Top + PathDelim) then
    Exit;
  CListView1.NavigateTo(TopFolder);   // 範囲の外に出たら戻す
end;
```

- 範囲の外のフォルダーが一瞬表示されてから戻る。戻る・進むの履歴にも、範囲の外のフォルダーが残る。

### 10.11 コードで作る

```pascal
uses
  CListView;

procedure TForm1.FormCreate(Sender: TObject);
var
  L: TCListView;
begin
  L := TCListView.Create(Self);
  L.Parent := Self;
  L.Align := alClient;
  L.OnFolderChanged := @CListView1FolderChanged;   // 10.1 の処理を使う
  L.NavigateTo('C:\Work');
end;
```
