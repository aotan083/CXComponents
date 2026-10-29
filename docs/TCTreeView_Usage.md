# TCTreeView 取扱説明書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 概要とクラス

Windows のエクスプローラーの左側と同じように使える、フォルダーのツリー表示です。フォームに置くだけで、フォルダーのコピー・移動・削除・名前の変更・ドラッグ＆ドロップ・右クリックメニューがエクスプローラーと同じように動きます。アプリ側でコードを書く必要はありません。

```
v クイックアクセス
    デスクトップ
    ダウンロード
    ドキュメント
  OneDrive
v PC
  > ローカル ディスク (C:)
  > (D:)
v ネットワーク
    \\nas\share
> Linux
```

- 最上位に、クイックアクセス、OneDrive、PC（全ドライブ）、ネットワーク、Linux（WSL）を並べる（エクスプローラーと同じ並び）。
- フォルダーの並びはエクスプローラーと同じ（数字を数の大きさで比べる自然順）。
- ほかのアプリやエクスプローラーでフォルダーが変わると、表示も自動で更新される。
- TCListView（ファイル一覧）とつなぐと、ツリーで選んだフォルダーの中身が一覧に表示される。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCTreeView` | `CTreeView` | cx | `TShellTreeView`（LCL、`ShellCtrls`） | エクスプローラーの左側と同じように使えるフォルダーのツリー。コピー・移動・削除・名前の変更・ドラッグ＆ドロップ・右クリックメニューが、コードを書かずに動く |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCExtraMenuPosition` | `CShellMenu` | 右クリックメニューに足す項目の位置。`empTop`（メニューの先頭）・`empBottom`（メニューの末尾） |

- フォームに置くと、uses に `CTreeView` が自動で入る。
- フォームに置くと、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。`ExtraMenuPosition` に値を入れるときは、uses に `CShellMenu` も書く。

## 2. フォームに置いて動かすまで

### 2.1 ツリーだけを使う

1. パレット [CX] から、TCTreeView をフォームに置く。
2. 実行する。クイックアクセス・OneDrive・PC（全ドライブ）・ネットワーク・Linux（WSL）が表示される。

### 2.2 TCListView（ファイル一覧）とつなぐ

1. TCTreeView と TCListView をフォームに置く。
2. TCListView の `ShellTreeView` に、TCTreeView を選ぶ。
3. 実行する。ツリーでフォルダーを選ぶと、一覧がそのフォルダーに移る（一覧で移っても、ツリーの選択は変わらない）。

### 2.3 表示する項目を選ぶ

1. オブジェクトインスペクタの `ShowQuickAccess`・`ShowOneDrive`・`ShowNetwork`・`ShowLinux` で、表示・非表示を決める（PC はいつも表示する）。
2. 「ネットワーク」の下に共有フォルダーを並べるときは、`NetworkFolders` に `\\サーバー\共有名` の形で1行に1つ書く。

## 3. ツリーの構成

| 並び | 項目 | 種類 | 押したとき | 表示の切り替え |
|---|---|---|---|---|
| 1 | クイックアクセス | グループ | 開閉するだけ | `ShowQuickAccess` |
| 1-1 | └ ピン留めしたフォルダー（デスクトップ、ダウンロードなど） | 近道 | そのフォルダーを選ぶ | （グループと同じ） |
| 2 | OneDrive | 近道 | OneDrive のフォルダーを選ぶ | `ShowOneDrive` |
| 3 | PC | グループ | 開閉するだけ | なし（いつも表示） |
| 3-1 | └ ドライブ（C:、D: など） | ドライブ | そのドライブを選ぶ | ― |
| 4 | ネットワーク | グループ | 開閉するだけ | `ShowNetwork` |
| 4-1 | └ 共有フォルダー（`NetworkFolders` に書いたもの） | 近道 | その共有フォルダーを選ぶ | ― |
| 5 | Linux | グループ | 開閉するだけ | `ShowLinux` |
| 5-1 | └ WSL のディストリビューション（`\\wsl.localhost\Ubuntu` など） | 近道 | そのフォルダーを選ぶ | ― |

- **グループ**は、実在のフォルダーを持たない見出し。選んでも一覧は変わらない。
- **近道**は、実在のフォルダーを指す。開くと、そのフォルダーのサブフォルダーが表示される。
- グループ・近道・ドライブは、削除・切り取り・名前の変更・ドラッグはできない。近道とドライブは、コピー・貼り付け・ドロップ先には使える。

## 4. プロパティ

### 4.1 この部品で足したもの・動きを変えたもの

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Path` | `string` | 読み・書き | 選んでいるフォルダーのフルパス。近道は指しているフォルダー。グループを選んでいるときは ''。書くと、そのフォルダーまで開いて選ぶ（ないパスは無視）。実行時だけ |
| `ShowQuickAccess` | `Boolean` | 読み・書き | クイックアクセスを表示するか（既定値は `True`）。フォルダーが1つもないときは表示されない |
| `ShowOneDrive` | `Boolean` | 読み・書き | OneDrive を表示するか（既定値は `True`）。OneDrive が入っていないときは表示されない |
| `ShowNetwork` | `Boolean` | 読み・書き | ネットワークを表示するか（既定値は `True`）。`NetworkFolders` が空なら表示されない |
| `ShowLinux` | `Boolean` | 読み・書き | Linux（WSL）を表示するか（既定値は `True`）。WSL が入っていないときは表示されない |
| `NetworkFolders` | `TStrings` | 読み・書き | 「ネットワーク」の下に並べる共有フォルダー。1行に1つ、`\\サーバー\共有名` の形で書く |
| `ExtraItemMenu` | `TPopupMenu` | 読み・書き | フォルダーの上で右クリックしたときに、メニューへ足す項目 |
| `ExtraBackgroundMenu` | `TPopupMenu` | 読み・書き | 何もない所で右クリックしたときに出す項目 |
| `ExtraMenuPosition` | `TCExtraMenuPosition` | 読み・書き | 足す項目の位置。`empTop`：メニューの先頭。`empBottom`（既定値）：メニューの末尾 |

- `ShowQuickAccess` などの表示の切り替えと `NetworkFolders` の変更は、実行中でもすぐに反映される。開いている状態と選択は保たれる。

### 4.2 TShellTreeView から引き継いだもの

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Align` | `TAlign` | 読み・書き | 親の中での配置 |
| `Anchors` | `TAnchors` | 読み・書き | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `AnchorSideBottom` | `TAnchorSide` | 読み・書き | 下の辺を、どの部品のどこに合わせるか |
| `AnchorSideLeft` | `TAnchorSide` | 読み・書き | 左の辺を、どの部品のどこに合わせるか |
| `AnchorSideRight` | `TAnchorSide` | 読み・書き | 右の辺を、どの部品のどこに合わせるか |
| `AnchorSideTop` | `TAnchorSide` | 読み・書き | 上の辺を、どの部品のどこに合わせるか |
| `AutoExpand` | `Boolean` | 読み・書き | 選んだ項目を自動で開くか |
| `BackgroundColor` | `TColor` | 読み・書き | 背景色 |
| `BorderSpacing` | `TControlBorderSpacing` | 読み・書き | 周りの余白 |
| `BorderStyle` | `TBorderStyle` | 読み・書き | 枠の線を出すか |
| `BorderWidth` | `TBorderWidth` | 読み・書き | 枠の内側の余白 |
| `Color` | `TColor` | 読み・書き | 色 |
| `Constraints` | `TSizeConstraints` | 読み・書き | 大きさの上限・下限 |
| `Cursor` | `TCursor` | 読み・書き | 上に来たときのマウスカーソル |
| `Enabled` | `Boolean` | 読み・書き | 使えるか |
| `ExpandCollapseMode` | `TTreeViewExpandCollapseMode` | 読み・書き | クリック・ダブルクリックで開閉するときの決まり |
| `ExpandSignColor` | `TColor` | 読み・書き | 開閉の印の色 |
| `ExpandSignType` | `TTreeViewExpandSignType` | 読み・書き | 開閉の印の形 |
| `Font` | `TFont` | 読み・書き | 文字 |
| `Height` | `Integer` | 読み・書き | 高さ |
| `HelpContext` | `THelpContext` | 読み・書き | ヘルプの番号 |
| `HelpKeyword` | `string` | 読み・書き | ヘルプのキーワード |
| `HelpType` | `THelpType` | 読み・書き | ヘルプを番号で引くか（`htContext`）、キーワードで引くか（`htKeyword`） |
| `HideSelection` | `Boolean` | 読み・書き | フォーカスがないときに、選択の色を消すか |
| `Hint` | `TTranslateString` | 読み・書き | ヒントの文字 |
| `HotTrack` | `Boolean` | 読み・書き | マウスを乗せた項目を強調するか |
| `Images` | `TCustomImageList` | 読み・書き | 項目のアイコン（空ならシステムのアイコンを描く） |
| `Indent` | `Integer` | 読み・書き | 1段ごとの字下げの幅 |
| `Left` | `Integer` | 読み・書き | 左端の位置 |
| `MultiSelectStyle` | `TMultiSelectStyle` | 読み・書き | 複数選択のしかた（`Options` に `tvoAllowMultiselect` を入れたとき） |
| `Name` | `TComponentName` | 読み・書き | 部品の名前 |
| `ObjectTypes` | `TObjectTypes` | 読み・書き | 表示するものの種類（既定値は `[otFolders]`）。隠しフォルダーも出すときは `otHidden` を足す |
| `Options` | `TTreeViewOptions` | 読み・書き | 動きと見た目の設定。`tvoReadOnly` は入れない、`tvoRightClickSelect` は外さない（名前の変更・右クリックメニューが正しく動かなくなる） |
| `ParentColor` | `Boolean` | 読み・書き | 親の色を使うか（既定値は `False`） |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `ParentShowHint` | `Boolean` | 読み・書き | 親の `ShowHint` を使うか |
| `RowSelect` | `Boolean` | 読み・書き | 選択の色を行全体に付けるか |
| `ScrollBars` | `TScrollStyle` | 読み・書き | スクロールバーの出し方 |
| `SelectionColor` | `TColor` | 読み・書き | 選択の色 |
| `ShellListView` | `TCustomShellListView` | 読み・書き | つないでいる一覧。ふつうは TCListView の `ShellTreeView` 側で設定する |
| `ShowButtons` | `Boolean` | 読み・書き | 開閉の印を出すか |
| `ShowHint` | `Boolean` | 読み・書き | ヒントを出すか |
| `ShowLines` | `Boolean` | 読み・書き | 線を出すか |
| `ShowRoot` | `Boolean` | 読み・書き | 一番上の項目にも線と開閉の印を出すか |
| `StateImages` | `TCustomImageList` | 読み・書き | 項目の状態のアイコン |
| `TabOrder` | `TTabOrder` | 読み・書き | Tab キーで移る順番 |
| `TabStop` | `Boolean` | 読み・書き | Tab キーで止まるか（既定値は `True`） |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値 |
| `ToolTips` | `Boolean` | 読み・書き | 入りきらない項目の名前を、マウスを乗せたときに出すか |
| `Top` | `Integer` | 読み・書き | 上端の位置 |
| `TreeLineColor` | `TColor` | 読み・書き | 線の色 |
| `TreeLinePenStyle` | `TPenStyle` | 読み・書き | 線の種類 |
| `Visible` | `Boolean` | 読み・書き | 表示するか |
| `Width` | `Integer` | 読み・書き | 幅 |

## 5. メソッド

### 5.1 TCTreeView のメソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | ― | 作る。コードで作るときに使う（10.7） |
| `GetPathFromNode` | `ANode: TTreeNode` | `string` | 項目のフルパス。近道は指しているフォルダー、グループは '' |
| `IsDriveNode` | `Node: TTreeNode` | `Boolean` | ドライブ（`C:\` や `\\server\share`）なら `True` |
| `IsSpecialNode` | `Node: TTreeNode` | `Boolean` | 近道かグループなら `True` |
| `IsShortcutNode` | `Node: TTreeNode` | `Boolean` | 近道（ピン留めしたフォルダー、OneDrive、共有フォルダー、WSL）なら `True` |
| `IsGroupNode` | `Node: TTreeNode` | `Boolean` | グループ（クイックアクセス、PC、ネットワーク、Linux）なら `True` |
| `CopySelectedFolder` | ― | ― | 選んでいるフォルダーをクリップボードへコピーする（Ctrl+C と同じ） |
| `CutSelectedFolder` | ― | ― | 選んでいるフォルダーを切り取る（Ctrl+X と同じ）。ドライブ・近道・グループは対象外 |
| `PasteToSelectedFolder` | ― | ― | 選んでいるフォルダーの中へ貼り付ける（Ctrl+V と同じ） |
| `DeleteSelectedFolder` | `APermanent: Boolean = False` | ― | 選んでいるフォルダーを削除する。`False`：ごみ箱へ。`True`：完全に削除。確認を出す。ドライブ・近道・グループは対象外 |
| `RenameSelectedFolder` | ― | ― | 選んでいるフォルダーの名前の変更を始める（F2 と同じ）。ドライブ・近道・グループは対象外 |

### 5.2 ユニットの関数

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `IsDriveRootPath` | `const APath: string` | `Boolean` | パスがドライブのルート（`C:\` や `\\server\share`）なら `True` |

## 6. イベント

この部品で足したイベントはない。TShellTreeView から引き継いだものは、次のとおり。

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnAddItem` | `Sender: TObject; const ABasePath: String; const AFileInfo: TSearchRec; var CanAdd: Boolean` | フォルダーを項目として足す前。`CanAdd := False` で足さない |
| `OnAdvancedCustomDraw` | `Sender: TCustomTreeView; const ARect: TRect; Stage: TCustomDrawStage; var DefaultDraw: Boolean` | 全体を描く各段階 |
| `OnAdvancedCustomDrawItem` | `Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean` | 項目を描く各段階 |
| `OnChange` | `Sender: TObject; Node: TTreeNode` | 選んでいるフォルダーが変わった（クリック、キー、`Path` への書き込み、表示中のフォルダーが消えて親に移ったとき） |
| `OnChanging` | `Sender: TObject; Node: TTreeNode; var AllowChange: Boolean` | 選択が変わる前。`AllowChange := False` で取りやめる |
| `OnClick` | `Sender: TObject` | クリックされた |
| `OnCollapsed` | `Sender: TObject; Node: TTreeNode` | 項目が閉じた |
| `OnCollapsing` | `Sender: TObject; Node: TTreeNode; var AllowCollapse: Boolean` | 項目が閉じる前。`AllowCollapse := False` で取りやめる |
| `OnCustomDraw` | `Sender: TCustomTreeView; const ARect: TRect; var DefaultDraw: Boolean` | 全体を描く前 |
| `OnCustomDrawItem` | `Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState; var DefaultDraw: Boolean` | 項目を描く前 |
| `OnDblClick` | `Sender: TObject` | ダブルクリックされた |
| `OnEditing` | `Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean` | 名前の変更を始める前。`AllowEdit := False` で取りやめる |
| `OnEnter` | `Sender: TObject` | フォーカスが入った |
| `OnExit` | `Sender: TObject` | フォーカスが出た |
| `OnExpanded` | `Sender: TObject; Node: TTreeNode` | 項目が開いた |
| `OnExpanding` | `Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean` | 項目が開く前。`AllowExpansion := False` で取りやめる |
| `OnGetImageIndex` | `Sender: TObject; Node: TTreeNode` | 項目のアイコンの番号を決めるとき（`Images` を使うとき） |
| `OnGetSelectedIndex` | `Sender: TObject; Node: TTreeNode` | 選んだ項目のアイコンの番号を決めるとき（`Images` を使うとき） |
| `OnHasChildren` | `Sender: TCustomTreeView; ANode: TTreeNode` → `Boolean` | 項目に開閉の印を出すかを決めるとき（ドライブと通常のフォルダー） |
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
| `OnSelectionChanged` | `Sender: TObject` | 選択が変わった |
| `OnShowHint` | `Sender: TObject; HintInfo: PHintInfo` | ヒントを出す直前 |
| `OnUTF8KeyPress` | `Sender: TObject; var UTF8Key: TUTF8Char` | 文字のキーが押された（UTF-8 の1文字） |

- TCListView とつないでいるときは、TCListView の `OnFolderChanged` だけを使えば足りる。
- フォルダーのコピー・移動・削除・名前の変更を知らせるイベントはない。表示は部品が自動で更新する。
- 部品が使っているキー（Ctrl+C・Ctrl+X・Ctrl+V・Delete・Shift+Delete・F2・F5）を、`OnKeyDown` やフォームの `OnKeyDown`（`KeyPreview = True`）で `Key := 0` にすると、部品の動作が止まる。

## 7. 操作

### 7.1 キー

| キー | 動作 |
|---|---|
| Ctrl+C | 選んでいるフォルダーをコピー |
| Ctrl+X | 選んでいるフォルダーを切り取り（ドライブ・近道・グループは対象外） |
| Ctrl+V | 選んでいるフォルダーの中へ貼り付け |
| Delete | ごみ箱へ移動（確認あり。ドライブ・近道・グループは対象外） |
| Shift+Delete | 完全に削除（確認あり） |
| F2 | 名前の変更（ドライブ・近道・グループは対象外） |
| F5 | 開いている項目を最新の状態に更新 |

### 7.2 マウス

| 操作 | 動作 |
|---|---|
| ダブルクリック | 開く／閉じる |
| ゆっくり2回クリック | 名前の変更 |
| マウスの戻るボタン | つないでいる TCListView の履歴で、1つ前のフォルダーへ |
| マウスの進むボタン | つないでいる TCListView の履歴で、1つ次のフォルダーへ |

- 戻る・進むボタンは、`ShellListView` に TCListView をつないでいるときだけ動く。

### 7.3 右クリックメニュー

| 場所 | メニュー |
|---|---|
| フォルダーの上 | エクスプローラーと同じメニュー（開く、送る、切り取り、コピー、削除、名前の変更、プロパティなど）＋ `ExtraItemMenu` の項目 |
| 何もない所 | `ExtraBackgroundMenu` の項目だけ（未設定なら何も出ない） |

- アプリ独自の項目を足すには、フォームに TPopupMenu を置いて項目を作り、`ExtraItemMenu`（または `ExtraBackgroundMenu`）に設定する。
- 処理は、各メニュー項目の `OnClick` に書く。対象のフォルダーは `Path` で取れる（右クリックしたフォルダーが選ばれるため）。
- 表示する直前に項目の有効・無効を変えたいときは、TPopupMenu の `OnPopup` に書く。
- メニューに反映されるもの：`Caption`、サブメニュー、区切り線（`Caption = '-'`）、`Enabled`、`Visible`、`Checked`、ショートカットの表示。アイコンは表示されない。
- 同じ TPopupMenu を `ExtraItemMenu` と `ExtraBackgroundMenu` の両方に設定してもよい。
- 「名前の変更」を選ぶと、F2 と同じ名前の変更が始まる。
- メニューから起動するアプリには、エクスプローラーと同じく、右クリックしたフォルダーの親フォルダーが作業フォルダーとして渡される。

### 7.4 ドラッグ＆ドロップ

| 項目 | 動作 |
|---|---|
| 相手 | アプリ内（ツリー ⇔ ツリー、ツリー ⇔ 一覧）、エクスプローラー・デスクトップ・ほかのアプリと双方向 |
| ドラッグの開始 | フォルダーの上でボタンを押し、少し動かす。対象は押したフォルダー1つ（ドライブ・近道・グループは不可） |
| コピーか移動か | エクスプローラーと同じ。同じドライブなら移動、別のドライブならコピー。Ctrl でコピー、Shift で移動、Alt でショートカットを作る |
| 右ボタンでドラッグ | ドロップしたときにメニュー（ここにコピー、ここに移動、ショートカットを作成など）を出す |
| ドロップ先 | ドロップした所のフォルダー |
| できない操作 | 自分自身・自分の中のフォルダーへのドロップ、同じフォルダーへの移動 |
| ドラッグ中 | ドロップ先を枠で強調、上下の端で自動スクロール、0.7 秒止めると自動で開く |
| 取りやめ | Esc |

コピー・移動・上書きの確認・進み具合の表示は、エクスプローラーと同じく Windows が行う。

## 8. 自動更新

- ほかのアプリやエクスプローラーでフォルダーが追加・削除・名前変更されると、表示が自動で更新される。開いている状態と選択は保たれる。
- USB メモリなどのドライブを抜き差しすると、ドライブの一覧が更新される。
- 選んでいたフォルダーが消えた場合は、残っている親フォルダーが選ばれる。
- 名前の変更中・ドラッグ中は、終わるまで更新を待つ。
- 同じフォルダーが2か所にある場合（クイックアクセスと PC の下の両方にあるデスクトップなど）は、両方とも更新される。

## 9. 注意

### 9.1 変えないでください

次のプロパティは部品の中で使っている。値を変えると、正しく動かなくなる。

| 名前 | 理由 |
|---|---|
| `Root` | 常に空文字（全ドライブ）で使う。選んでいるフォルダーは `Path` で取る |
| `FileSortType`・`OnSortCompare` | フォルダーの並び（自然順）に使っている |
| `OnEdited` | 名前の変更に使っている |
| `DragMode` | `dmManual` のままにする（ドラッグ＆ドロップは部品が自分で行う） |
| `ReadOnly` | `False` のままにする（`True` にすると名前の変更ができない） |
| `RightClickSelect` | `True` のままにする（右クリックしたフォルダーをメニューの対象にするため） |
| `PopupMenu` | 使わない（設定しても出ない）。メニューは `ExtraItemMenu`・`ExtraBackgroundMenu` で追加する |

### 9.2 そのほか

- Windows 専用。
- 管理者として実行したアプリと通常のアプリの間では、ドラッグ＆ドロップできない（Windows の制限）。
- ネットワーク上の共有フォルダーと WSL のフォルダーは、変更の通知が届かないことがある。そのときは F5 で更新する。
- 260 文字を超えるパスは、一部の機能（表示など）で扱えない。
- 近道には、実在のフォルダーだけを表示する。ホーム、ギャラリー、ごみ箱などは表示しない。
- クイックアクセスには、エクスプローラーの設定によって「よく使うフォルダー」も含まれる。ピン留めを変えた内容は、ツリーを作り直したとき（ドライブの抜き差し、表示の切り替え、アプリの再起動）に反映される。
- 一覧で移動しても、ツリーの選択は変わらない。
## 10. 使い方の例

### 10.1 選んだフォルダーをフォームのタイトルに出す

```pascal
procedure TForm1.CTreeView1Change(Sender: TObject; Node: TTreeNode);
begin
  if CTreeView1.Path <> '' then
    Caption := CTreeView1.Path
  else
    Caption := 'MyApp';   // グループを選んでいる
end;
```

### 10.2 表示する項目を決める

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  CTreeView1.ShowOneDrive := False;              // OneDrive を出さない
  CTreeView1.ShowLinux := False;                 // Linux を出さない
  CTreeView1.NetworkFolders.Add('\\nas\share');  // ネットワークの下に共有フォルダーを出す
end;
```

### 10.3 指定したフォルダーまで開いて選び、その中も開く

```pascal
procedure TForm1.Button1Click(Sender: TObject);
begin
  CTreeView1.Path := 'C:\Work';
  if CTreeView1.Selected <> nil then
    CTreeView1.Selected.Expand(False);
end;
```

### 10.4 ボタン・メニューからフォルダーを操作する

```pascal
procedure TForm1.ButtonCopyClick(Sender: TObject);
begin
  CTreeView1.CopySelectedFolder;          // Ctrl+C と同じ
end;

procedure TForm1.ButtonPasteClick(Sender: TObject);
begin
  CTreeView1.PasteToSelectedFolder;       // Ctrl+V と同じ
end;

procedure TForm1.ButtonDeleteClick(Sender: TObject);
begin
  CTreeView1.DeleteSelectedFolder;        // ごみ箱へ（確認あり）
end;

procedure TForm1.ButtonRenameClick(Sender: TObject);
begin
  CTreeView1.RenameSelectedFolder;        // F2 と同じ
end;
```

### 10.5 右クリックメニューにアプリの項目を足す

1. TPopupMenu をフォームに置き、項目（例：「ここでコマンドプロンプトを開く」）を作る。
2. TCTreeView の `ExtraItemMenu` に、その TPopupMenu を選ぶ。
3. 項目の `OnClick` に、次の処理を書く。右クリックしたフォルダーが選ばれるので、対象は `Path` で取れる。

```pascal
uses
  Process;

procedure TForm1.MenuItemCmdClick(Sender: TObject);
begin
  if CTreeView1.Path <> '' then
    with TProcess.Create(nil) do
    try
      Executable := 'cmd.exe';
      CurrentDirectory := CTreeView1.Path;
      Execute;
    finally
      Free;
    end;
end;
```

- 表示する直前に項目の有効・無効を変えるときは、TPopupMenu の `OnPopup` に書く。
- メニューに反映されるのは、`Caption`・サブメニュー・区切り線（`Caption = '-'`）・`Enabled`・`Visible`・`Checked`・ショートカットの表示。アイコンは表示されない。

### 10.6 選んでいる項目の種類で、ボタンを使える・使えないにする

```pascal
procedure TForm1.CTreeView1Change(Sender: TObject; Node: TTreeNode);
var
  N: TTreeNode;
  Normal: Boolean;
begin
  N := CTreeView1.Selected;
  // 通常のフォルダー（ドライブ・近道・グループ以外）だけ、削除・名前の変更ができる
  Normal := (N <> nil) and not CTreeView1.IsSpecialNode(N) and not CTreeView1.IsDriveNode(N);
  ButtonDelete.Enabled := Normal;
  ButtonRename.Enabled := Normal;
  ButtonPaste.Enabled := (N <> nil) and not CTreeView1.IsGroupNode(N);
end;
```

### 10.7 コードで作る

```pascal
uses
  CTreeView, CListView;

procedure TForm1.FormCreate(Sender: TObject);
var
  T: TCTreeView;
  L: TCListView;
begin
  T := TCTreeView.Create(Self);
  T.Parent := Self;
  T.Align := alLeft;
  T.Width := 250;

  L := TCListView.Create(Self);
  L.Parent := Self;
  L.Align := alClient;
  L.ShellTreeView := T;     // ツリーで選んだフォルダーを一覧に出す
end;
```
