# TCPageControl 取扱説明書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 概要とクラス

ブラウザ（Firefox・Edge など）のように、タイトルバーの位置にタブを並べた画面を作る部品です。

```
+-----------------------------------------------------------------------------+
| [左の部品] キャプション [◀][タブ1 ×][タブ2 ×]…[▶][＋]  [∨][右の部品] [─][□][×] |  ← TCTitleBar
+-----------------------------------------------------------------------------+
|                                                                             |
|   表示中のページ（TCTabSheet）                                              |
|   （Button、Memo など）                                                     |
|                                                                             |
+-----------------------------------------------------------------------------+
```

| 部品 | 役割 |
|---|---|
| TCTitleBar | フォームのタイトルバーの代わりになるパネル。最小化・最大化・閉じるボタンを持ち、ドラッグでフォームを動かせる |
| TCPageControl | タブコントロール。TPageControl と同じ名前のプロパティ・イベントで使える。単体でも、TCTitleBar と組み合わせても使える |
| TCTabSheet | タブ1枚分のページ。部品はこの上に置く |

- TCPageControl の `TitleBar` に TCTitleBar を指定すると、タブ列がタイトルバーの中に入る。
- タブには、［×］（閉じる）、［＋］（新しいタブ）、［∨］（タブの一覧）、ドラッグでの並べ替え、右クリックメニュー、その場での名前の変更、アイコンが付いている。
- フォームに置いてオブジェクトインスペクタで設定するだけで動く。アプリが書くのは、ボタンやメニューを押したときの処理だけ。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX（TCTitleBar・TCPageControl。TCTabSheet はパレットに出ない） |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCPageControl` | `uCPageControl` | cx | `TCustomControl` | ブラウザのようなタブコントロール。TPageControl と同じ名前のプロパティ・イベントで使える |
| `TCTabSheet` | `uCPageControl` | cx | `TCustomControl` | タブ1枚分のページ。この上に部品を置く。`TCPageControl` の上にだけ置ける。パレットには出ない |
| `TCTitleBar` | `uCTitleBar` | cx | `TCustomPanel` | フォームのタイトルバーの代わりになるパネル。最小化・最大化・閉じるボタンを持つ |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCTabShape` | `uCPageControl` | タブの形。`tsRectangle`（四角）・`tsRounded`（角丸） |
| `TCTabMenuItem` | `uCPageControl` | 右クリックメニューの標準の項目。`tmiNew`（新しいタブ）・`tmiClose`（タブを閉じる）・`tmiRename`（タブ名の変更） |
| `TCTabMenuItems` | `uCPageControl` | `set of TCTabMenuItem` |
| `TCNewPageEvent` | `uCPageControl` | `procedure(Sender: TObject; APage: TCTabSheet) of object`。`OnNewPage` の型 |
| `TCPageCloseEvent` | `uCPageControl` | `procedure(Sender: TObject; APage: TCTabSheet; var CanClose: Boolean) of object`。`OnPageClose` の型 |
| `TCPageRenameEvent` | `uCPageControl` | `procedure(Sender: TObject; APage: TCTabSheet; var ACaption: string; var CanRename: Boolean) of object`。`OnPageRename` の型 |
| `TCPageMovedEvent` | `uCPageControl` | `procedure(Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer) of object`。`OnPageMoved` の型 |
| `TCTabControlOptions` | `ComCtrls`（LCL） | `Options` の型。値は 3.1 の下の表 |
| `TTabChangingEvent` | `ComCtrls`（LCL） | `procedure(Sender: TObject; var AllowChange: Boolean) of object`。`OnChanging` の型 |
| `TTabGetImageEvent` | `ComCtrls`（LCL） | `procedure(Sender: TObject; TabIndex: Integer; var ImageIndex: Integer) of object`。`OnGetImageIndex` の型 |

- フォームに置くと、uses に `uCPageControl`・`uCTitleBar` が自動で入る。
- フォームに置くと、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

## 2. フォームに置いて動かすまで

### 2.1 タイトルバーにタブを並べる

1. パレット [CX] から、TCTitleBar をフォームに置く。上端に置かれる（`Align = alTop`）。
2. パレット [CX] から、TCPageControl をフォームに置き、`Align` を `alClient` にする。
3. TCPageControl の `TitleBar` に、TCTitleBar を選ぶ。タブ列がタイトルバーの中に入る。
4. フォームの `BorderStyle` を `bsSizeable`（既定値）か `bsSingle` にする。
5. TCPageControl を右クリックし、「新しいページ」を選ぶ。ページが末尾に追加され、表示中になる。
6. オブジェクトインスペクタで、ページの `Caption`（タブの文字）を設定する。
7. 表示中のページの上に、ボタンなどの部品を置く。
8. 5～7 をページの数だけ繰り返す。
9. ［＋］で作ったタブに部品を置くときは、TCPageControl のイベントタブの `OnNewPage` をダブルクリックして処理を書く（10.1）。
10. 実行する。Windows のタイトルバーが消え、TCTitleBar がタイトルバーとして働く。

### 2.2 タブだけを使う

1. TCPageControl だけをフォームに置き、`Align` を `alClient` にする。`TitleBar` は空のままにする。
2. 2.1 の 5～9 と同じようにページを作る。
3. 実行する。タブ列は TCPageControl の上端（`TabPosition = tpBottom` なら下端）に出る。

### 2.3 タイトルバーだけを使う

1. TCTitleBar だけをフォームに置く。
2. 実行する。キャプション・最小化・最大化・閉じるボタン・ドラッグでの移動が使える。

### 2.4 タイトルバーに部品を置く

1. TCTitleBar の上に、TButton・TSpeedButton・TImage・TToolBar などを置く。
2. 部品の `Align` を `alLeft` か `alRight` にする。

```
[alLeft の部品…][キャプション][タブ列][alRight の部品…][─][□][×]
```

- `Align` が `alNone` のままだと、置いた位置によっては、最小化・最大化・閉じるボタンの上に重なる。
- TSpeedButton は、`Flat = True` だとマウスを乗せたときだけ枠が出る。見分けがつかないときは、`Flat` を `False` にするか、アイコンか `Caption` を付ける。

## 3. TCPageControl

### 3.1 プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `ActivePage` | `TCTabSheet` | 読み・書き | 表示中のページ。書くと切り替わる |
| `ActivePageIndex` | `Integer` | 読み・書き | 表示中のページの番号（0 から。ページがないときは -1）。書くと切り替わる。実行時だけ |
| `TabIndex` | `Integer` | 読み・書き | `ActivePageIndex` と同じ |
| `PageCount` | `Integer` | 読み | ページの数。実行時だけ |
| `Pages[Index]` | `TCTabSheet` | 読み | ページ。実行時だけ |
| `PopupPage` | `TCTabSheet` | 読み | 右クリックされたページ（タブ列の空き部分なら nil）。`TabPopupMenu` の項目の `OnClick` の中で使う。実行時だけ |
| `Images` | `TCustomImageList` | 読み・書き | タブのアイコン |
| `ImagesWidth` | `Integer` | 読み・書き | アイコンの幅（表示スケール 100% のときの px）。0（既定値）なら `Images` の幅 |
| `TabPosition` | `TTabPosition` | 読み・書き | タブ列の位置。`tpTop`（既定値）・`tpBottom`。`tpLeft`・`tpRight` は `tpTop` と同じ。タイトルバーの中では使わない |
| `TabHeight` | `Smallint` | 読み・書き | タブの高さ。0（既定値）なら自動 |
| `TabWidth` | `Smallint` | 読み・書き | タブの幅。0（既定値）なら文字に合わせる |
| `TabMaxWidth` | `Integer` | 読み・書き | `TabWidth = 0` のときの最大の幅（既定値は 240）。入りきらない文字は「…」 |
| `TabShape` | `TCTabShape` | 読み・書き | タブの形。`tsRectangle`（既定値。四角）・`tsRounded`（角丸） |
| `Options` | `TCTabControlOptions` | 読み・書き | 動きの設定（下の表）。既定値は `[nboShowCloseButtons, nboShowAddTabButton, nboKeyboardTabSwitch]` |
| `ShowTabListButton` | `Boolean` | 読み・書き | ［∨］（タブの一覧）を出すか（既定値は `True`） |
| `NewPageCaption` | `string` | 読み・書き | ［＋］・メニューで作ったタブの名前（既定値は '新しいタブ'） |
| `TabMenuItems` | `TCTabMenuItems` | 読み・書き | 右クリックメニューに出す標準の項目（既定値は `[tmiNew, tmiClose, tmiRename]`） |
| `TabPopupMenu` | `TPopupMenu` | 読み・書き | タブの右クリックメニューに足す項目。標準の項目の下に、区切り線を挟んで出る |
| `TabListPopupMenu` | `TPopupMenu` | 読み・書き | タブの一覧の上に足す項目（サブメニューは出ない） |
| `TitleBar` | `TCTitleBar` | 読み・書き | タブ列を入れるタイトルバー。空ならタブ列は TCPageControl の中に出る |
| `Color` | `TColor` | 読み・書き | タブ列の背景色（タブだけを使うとき。既定値は `clBtnFace`） |
| `Align` | `TAlign` | 読み・書き | 親の中での配置 |
| `Anchors` | `TAnchors` | 読み・書き | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `AnchorSideBottom` | `TAnchorSide` | 読み・書き | 下の辺を、どの部品のどこに合わせるか |
| `AnchorSideLeft` | `TAnchorSide` | 読み・書き | 左の辺を、どの部品のどこに合わせるか |
| `AnchorSideRight` | `TAnchorSide` | 読み・書き | 右の辺を、どの部品のどこに合わせるか |
| `AnchorSideTop` | `TAnchorSide` | 読み・書き | 上の辺を、どの部品のどこに合わせるか |
| `BiDiMode` | `TBiDiMode` | 読み・書き | 右から左に並べるか |
| `BorderSpacing` | `TControlBorderSpacing` | 読み・書き | 周りの余白 |
| `Constraints` | `TSizeConstraints` | 読み・書き | 大きさの上限・下限 |
| `Cursor` | `TCursor` | 読み・書き | 上に来たときのマウスカーソル |
| `DragCursor` | `TCursor` | 読み・書き | ドラッグ中のマウスカーソル |
| `DragKind` | `TDragKind` | 読み・書き | ドラッグの種類（ドラッグ＆ドロップか、ドッキングか） |
| `DragMode` | `TDragMode` | 読み・書き | ドラッグを自動で始めるか |
| `Enabled` | `Boolean` | 読み・書き | 使えるか |
| `Font` | `TFont` | 読み・書き | タブの文字 |
| `Height` | `Integer` | 読み・書き | 高さ |
| `HelpContext` | `THelpContext` | 読み・書き | ヘルプの番号 |
| `HelpKeyword` | `string` | 読み・書き | ヘルプのキーワード |
| `HelpType` | `THelpType` | 読み・書き | ヘルプを番号で引くか（`htContext`）、キーワードで引くか（`htKeyword`） |
| `Hint` | `TTranslateString` | 読み・書き | ヒントの文字 |
| `Left` | `Integer` | 読み・書き | 左端の位置 |
| `Name` | `TComponentName` | 読み・書き | 部品の名前 |
| `ParentBiDiMode` | `Boolean` | 読み・書き | 親の `BiDiMode` を使うか |
| `ParentColor` | `Boolean` | 読み・書き | 親の色を使うか（既定値は `False`） |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `ParentShowHint` | `Boolean` | 読み・書き | 親の `ShowHint` を使うか |
| `PopupMenu` | `TPopupMenu` | 読み・書き | ページの何もない所を右クリックしたときに出すメニュー |
| `ShowHint` | `Boolean` | 読み・書き | ヒントを出すか |
| `TabOrder` | `TTabOrder` | 読み・書き | Tab キーで移る順番 |
| `TabStop` | `Boolean` | 読み・書き | Tab キーで止まるか |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値 |
| `Top` | `Integer` | 読み・書き | 上端の位置 |
| `Visible` | `Boolean` | 読み・書き | 表示するか |
| `Width` | `Integer` | 読み・書き | 幅 |

**`Options` の値**

| 値 | 中身 |
|---|---|
| `nboShowCloseButtons` | タブに［×］を出す |
| `nboShowAddTabButton` | ［＋］を出す |
| `nboKeyboardTabSwitch` | Ctrl+Tab・Ctrl+Shift+Tab で切り替える |
| `nboDoChangeOnSetIndex` | コードで表示ページを変えたときも、`OnChanging`・`OnChange` を出す |

### 3.2 メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | ― | 作る。コードで作るときに使う（10.9） |
| `AddTabSheet` | ― | `TCTabSheet` | 末尾にページを足して返す。表示ページは変えない。イベントは出さない |
| `Clear` | ― | ― | すべてのページを削除する。`OnPageClose` は出ない |
| `IndexOf` | `APage: TPersistent` | `Integer` | そのページの番号。ないときは -1 |
| `FindNextPage` | `CurPage: TCTabSheet; GoForward, CheckTabVisible: Boolean` | `TCTabSheet` | 次（`GoForward = False` なら前）のページを返す。端では反対側に回る。`CheckTabVisible = True` なら `TabVisible = False` のページを飛ばす |
| `SelectNextPage` | `GoForward: Boolean` | ― | 次（前）のページを表示する。`TabVisible = False` のページは飛ばす |
| `SelectNextPage` | `GoForward, CheckTabVisible: Boolean` | ― | 次（前）のページを表示する |
| `IndexOfTabAt` | `X, Y: Integer` | `Integer` | その位置のタブの番号（見えているタブだけで数える）。ないときは -1 |
| `IndexOfTabAt` | `P: TPoint` | `Integer` | 同じ（位置を `TPoint` で渡す） |
| `IndexOfPageAt` | `X, Y: Integer` | `Integer` | その位置のタブのページ番号。ないときは -1 |
| `IndexOfPageAt` | `P: TPoint` | `Integer` | 同じ（位置を `TPoint` で渡す） |
| `TabRect` | `AIndex: Integer` | `TRect` | そのタブの位置と大きさ |
| `EditPageCaption` | `APage: TCTabSheet` | ― | そのタブの名前を、タブの上で編集する状態にする |

- `IndexOfTabAt`・`IndexOfPageAt`・`TabRect` の位置は、タブだけを使うときは TCPageControl の中の位置、タイトルバーの中では TCTitleBar の中の位置。

### 3.3 イベント

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnChanging` | `Sender: TObject; var AllowChange: Boolean` | 表示ページが変わる前。`AllowChange := False` で取りやめる |
| `OnChange` | `Sender: TObject` | 表示ページが変わった後 |
| `OnNewPage` | `Sender: TObject; APage: TCTabSheet` | ［＋］・メニューでタブを作った後。`APage` は作ったページ |
| `OnPageClose` | `Sender: TObject; APage: TCTabSheet; var CanClose: Boolean` | ［×］・メニュー・一覧でタブを閉じる前。`CanClose := False` で取りやめる |
| `OnPageRename` | `Sender: TObject; APage: TCTabSheet; var ACaption: string; var CanRename: Boolean` | 名前の編集を決める前。`ACaption` は新しい名前（変えられる）。`CanRename := False` で取りやめる |
| `OnPageMoved` | `Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer` | ドラッグでタブを動かした後 |
| `OnGetImageIndex` | `Sender: TObject; TabIndex: Integer; var ImageIndex: Integer` | タブを描く前。`ImageIndex` に使うアイコンの番号を入れられる |
| `OnContextPopup` | `Sender: TObject; MousePos: TPoint; var Handled: Boolean` | 右クリックメニューを出す直前。`Handled := True` で出さない |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | ドロップされた |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | ドラッグしている物が上に来た。`Accept` で受けるかを決める |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | ドラッグが終わった |
| `OnEnter` | `Sender: TObject` | フォーカスが入った |
| `OnExit` | `Sender: TObject` | フォーカスが出た |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが押された |
| `OnMouseEnter` | `Sender: TObject` | マウスが上に入った |
| `OnMouseLeave` | `Sender: TObject` | マウスが外に出た |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | マウスが動いた |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが離された |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | ホイールが回された |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが手前に回された |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが奥に回された |
| `OnResize` | `Sender: TObject` | 大きさが変わった |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | ドラッグを始めた |

### 3.4 呼ばれる順番

| 操作 | 順番 |
|---|---|
| タブを押して切り替える | `OnChanging` → `OnChange` |
| ［＋］・メニューで新しいタブを作る | `OnChanging` → `OnChange` → `OnNewPage` |
| 表示中のタブを［×］で閉じる | `OnPageClose` → `OnChange` |
| 表示中でないタブを［×］で閉じる | `OnPageClose` |
| タブをドラッグで動かす | `OnPageMoved` |

- 表示中のタブを閉じると、右隣のタブを表示する（右隣がなければ左隣）。最後の1枚も閉じられ、ページは0枚になる。
- `OnChanging` で `AllowChange := False` にすると、切り替わらず、後のイベントも出ない（［＋］では、タブも作られない）。

### 3.5 イベントが出ないとき

| とき | 中身 |
|---|---|
| 設計時 | フォームデザイナでの操作 |
| 起動 | .lfm を読み込むとき |
| コードで表示ページを変えた | `ActivePage`・`ActivePageIndex`・`TabIndex` に書いたとき。`Options` に `nboDoChangeOnSetIndex` を入れると、`OnChanging`・`OnChange` が出る |
| コードでページを削除・並べ替えた | `APage.Free`・`APage.PageIndex := n`・`Clear`。`OnPageClose`・`OnPageMoved` は出ない |

## 4. TCTabSheet

### 4.1 プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Caption` | `TCaption` | 読み・書き | タブの文字 |
| `ImageIndex` | `TImageIndex` | 読み・書き | アイコンの番号。-1（既定値）ならアイコンなし |
| `PageIndex` | `Integer` | 読み・書き | ページの位置。書くと並べ替わる（`OnPageMoved` は出ない） |
| `TabVisible` | `Boolean` | 読み・書き | `False` でタブを隠す（ページは残る）。既定値は `True` |
| `TabIndex` | `Integer` | 読み | 見えているタブだけで数えた番号。隠れていれば -1。実行時だけ |
| `PageControl` | `TCPageControl` | 読み・書き | 入っている TCPageControl。書くと、その TCPageControl の末尾のページになる。実行時だけ |
| `Color` | `TColor` | 読み・書き | ページの背景色（既定値は `clWindow`） |
| `BorderWidth` | `TBorderWidth` | 読み・書き | ページの内側の余白 |
| `ChildSizing` | `TControlChildSizing` | 読み・書き | 中の部品の並べ方 |
| `ClientHeight` | `Integer` | 読み・書き | 内側の高さ |
| `ClientWidth` | `Integer` | 読み・書き | 内側の幅 |
| `Cursor` | `TCursor` | 読み・書き | 上に来たときのマウスカーソル |
| `Enabled` | `Boolean` | 読み・書き | 使えるか |
| `Font` | `TFont` | 読み・書き | ページの上の部品が使う文字 |
| `HelpContext` | `THelpContext` | 読み・書き | ヘルプの番号 |
| `HelpKeyword` | `string` | 読み・書き | ヘルプのキーワード |
| `HelpType` | `THelpType` | 読み・書き | ヘルプを番号で引くか（`htContext`）、キーワードで引くか（`htKeyword`） |
| `Hint` | `TTranslateString` | 読み・書き | ヒントの文字 |
| `Name` | `TComponentName` | 読み・書き | 部品の名前 |
| `ParentColor` | `Boolean` | 読み・書き | 親の色を使うか（既定値は `False`） |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `ParentShowHint` | `Boolean` | 読み・書き | 親の `ShowHint` を使うか |
| `PopupMenu` | `TPopupMenu` | 読み・書き | ページの上を右クリックしたときに出すメニュー |
| `ShowHint` | `Boolean` | 読み・書き | ヒントを出すか |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値 |

- 表示していないページは見えなくなる（`Visible = False`）。TCMonacoEditor は、初めて表示されたときに起動する。

### 4.2 メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | ― | 作る。`PageControl` に TCPageControl を入れると、そのページになる（10.9）。TCPageControl 以外を親にすると例外 |

### 4.3 イベント

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnShow` | `Sender: TObject` | このページが表示された |
| `OnHide` | `Sender: TObject` | このページが表示されなくなった |
| `OnContextPopup` | `Sender: TObject; MousePos: TPoint; var Handled: Boolean` | 右クリックメニューを出す直前。`Handled := True` で出さない |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | ドロップされた |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | ドラッグしている物が上に来た。`Accept` で受けるかを決める |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | ドラッグが終わった |
| `OnEnter` | `Sender: TObject` | フォーカスが入った |
| `OnExit` | `Sender: TObject` | フォーカスが出た |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが押された |
| `OnMouseEnter` | `Sender: TObject` | マウスが上に入った |
| `OnMouseLeave` | `Sender: TObject` | マウスが外に出た |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | マウスが動いた |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが離された |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | ホイールが回された |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが手前に回された |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが奥に回された |
| `OnResize` | `Sender: TObject` | 大きさが変わった |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | ドラッグを始めた |

## 5. TCTitleBar

### 5.1 プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Caption` | `TCaption` | 読み・書き | タイトルバーに出す文字。空のときはフォームの `Caption` を出す（タスクバーには、いつもフォームの `Caption` が出る） |
| `Hooked` | `Boolean` | 読み | タイトルバーとして働いているか。実行時だけ |
| `Color` | `TColor` | 読み・書き | 背景色（既定値は `clBtnFace`） |
| `BevelInner` | `TPanelBevel` | 読み・書き | 内側の枠線 |
| `BevelOuter` | `TPanelBevel` | 読み・書き | 外側の枠線（既定値は `bvNone`） |
| `BevelWidth` | `TBevelWidth` | 読み・書き | 枠線の太さ |
| `BorderSpacing` | `TControlBorderSpacing` | 読み・書き | 周りの余白 |
| `Constraints` | `TSizeConstraints` | 読み・書き | 大きさの上限・下限 |
| `Cursor` | `TCursor` | 読み・書き | 上に来たときのマウスカーソル |
| `Enabled` | `Boolean` | 読み・書き | 使えるか |
| `Font` | `TFont` | 読み・書き | `Caption` の文字 |
| `Height` | `Integer` | 読み・書き | 高さ（既定値は 40） |
| `HelpContext` | `THelpContext` | 読み・書き | ヘルプの番号 |
| `HelpKeyword` | `string` | 読み・書き | ヘルプのキーワード |
| `HelpType` | `THelpType` | 読み・書き | ヘルプを番号で引くか（`htContext`）、キーワードで引くか（`htKeyword`） |
| `Hint` | `TTranslateString` | 読み・書き | ヒントの文字 |
| `Name` | `TComponentName` | 読み・書き | 部品の名前 |
| `ParentColor` | `Boolean` | 読み・書き | 親の色を使うか（既定値は `False`） |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `ParentShowHint` | `Boolean` | 読み・書き | 親の `ShowHint` を使うか |
| `PopupMenu` | `TPopupMenu` | 読み・書き | 右クリックで出すメニュー（タイトルバーとして働いていないとき） |
| `ShowHint` | `Boolean` | 読み・書き | ヒントを出すか |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値 |
| `Visible` | `Boolean` | 読み・書き | 表示するか |

**最小化・最大化・閉じるボタン**（フォームの `BorderIcons` で決まる）

| `BorderIcons` | 最小化 | 最大化 | 閉じる |
|---|---|---|---|
| `biSystemMenu`・`biMinimize`・`biMaximize` | 表示 | 表示 | 表示 |
| `biSystemMenu`・`biMinimize` | 表示 | 無効 | 表示 |
| `biSystemMenu`・`biMaximize` | 無効 | 表示 | 表示 |
| `biSystemMenu` だけ | なし | なし | 表示 |
| `biSystemMenu` なし | なし | なし | なし |

**タイトルバーとして働く条件**

| 条件 | 中身 |
|---|---|
| 置き場所 | フォームに直接置いたとき（パネルなどの上に置くと、普通のパネル） |
| フォームの枠 | フォームの `BorderStyle` が `bsSizeable`・`bsSingle` のとき |
| 数 | 1つのフォームに1つだけ。設計時に2つ目を置こうとすると、置かれない |
| 時 | 実行時だけ（設計時はボタンを表示するだけ） |

### 5.2 メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | ― | 作る |

### 5.3 イベント

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnClick` | `Sender: TObject` | クリックされた |
| `OnDblClick` | `Sender: TObject` | ダブルクリックされた |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが押された |
| `OnMouseEnter` | `Sender: TObject` | マウスが上に入った |
| `OnMouseLeave` | `Sender: TObject` | マウスが外に出た |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | マウスが動いた |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが離された |
| `OnResize` | `Sender: TObject` | 大きさが変わった |

- タイトルバーとして働いているときは、何も置いていない場所（キャプションを含む）は Windows のタイトルバーとして扱う（ドラッグで移動、ダブルクリックで最大化、右クリックでシステムメニュー）。そこではマウスのイベントは出ない。

## 6. 操作

### 6.1 実行時

| 部分 | 操作 |
|---|---|
| キャプション | TCTitleBar の `Caption` を表示する。空のときはフォームの `Caption` を表示する。長い文字は「…」で省略する。操作は空き部分と同じ |
| タブ | 押すとそのページを表示する。ドラッグで並べ替えられる（ドラッグ中に Esc、またはタブ列の外で離すと取りやめ） |
| タブの［×］ | そのタブを閉じる |
| ［＋］ | 末尾に新しいタブを作り、表示する |
| ［◀］［▶］ | タブが入りきらないときだけ出る。押すと1枚分ずつスクロールする。タブ列の上でマウスホイールでもスクロールする |
| ［∨］ | タブの一覧を出す。行を押すとそのタブを表示し、行の［×］でそのタブを閉じる |
| 最小化・最大化・閉じる | Windows のタイトルバーと同じ。最大化ボタンにマウスを乗せると、スナップレイアウトが出る |
| 空き部分 | ドラッグでフォームの移動、ダブルクリックで最大化／元に戻す、画面端へのスナップ、右クリックでシステムメニュー |
| 上端 | ドラッグで上方向に大きさを変えられる |
| Ctrl+Tab | 次のタブ（端では先頭に戻る） |
| Ctrl+Shift+Tab | 前のタブ（端では末尾に戻る） |

**右クリックメニュー**

| 右クリックした場所 | 出る項目 |
|---|---|
| タブの上 | 新しいタブ・タブを閉じる・タブ名の変更 → `TabPopupMenu` の項目 |
| 単体時のタブ列の空き部分 | 新しいタブ → `TabPopupMenu` の項目 |
| タイトルバー内のタブ列の空き部分 | Windows のシステムメニュー |

- 右クリックでは、表示するタブは変わらない。
- 「タブ名の変更」は、タブの上で文字をそのまま編集する。Enter かフォーカスを外すと確定、Esc で取りやめ。空のまま確定すると元の名前に戻る。

### 6.2 設計時（フォームデザイナ）

| 操作 | 動作 |
|---|---|
| タブをクリック | そのページを表示する。表示したページが選ばれた状態になる |
| タブ列の［◀］［▶］をクリック | スクロールする |
| オブジェクトインスペクタでページ（またはページの中の部品）を選ぶ | そのページを表示する |
| 右クリック →「新しいページ」 | ページを末尾に追加して表示する |
| 右クリック →「ページの削除」 | 表示中のページを削除する |
| 右クリック →「次のページ」「前のページ」 | 次（前）のページを表示する |
| TCPageControl をダブルクリック | 何もしない |

- 設計時は、タブ列の［＋］［∨］［×］は表示だけで、押しても動かない。
- 設計時は、TCTitleBar はタイトルバーとして働かない（ボタンを表示するだけ）。実行すると働く。
- 設計時に表示していたページが、起動したときにも表示される（`ActivePage` が .lfm に保存されるため）。
- ページの順番は、TCTabSheet の `PageIndex` で変える。

### 6.3 よく使う設定

| したいこと | 設定 |
|---|---|
| タブの［×］を出さない | `Options` から `nboShowCloseButtons` を外す |
| ［＋］を出さない | `Options` から `nboShowAddTabButton` を外す |
| Ctrl+Tab で切り替えない | `Options` から `nboKeyboardTabSwitch` を外す |
| ［∨］を出さない | `ShowTabListButton` を `False` にする |
| 右クリックメニューの標準の項目を減らす | `TabMenuItems` から `tmiNew`・`tmiClose`・`tmiRename` を外す |
| 右クリックメニューにアプリの項目を足す | TPopupMenu を置いて項目を作り、`TabPopupMenu` に選ぶ |
| タブの一覧の上にアプリの項目を足す | TPopupMenu を置いて項目を作り、`TabListPopupMenu` に選ぶ |
| 新しく作るタブの名前を変える | `NewPageCaption` に入れる |
| タブにアイコンを付ける | TImageList を置いて `Images` に選び、各 TCTabSheet の `ImageIndex` に番号を入れる |
| タブの形を角丸にする | `TabShape` を `tsRounded` にする |
| タブを下に出す（単体時） | `TabPosition` を `tpBottom` にする |
| タブの幅をそろえる | `TabWidth` に幅を入れる |
| タイトルバーの文字を変える | TCTitleBar の `Caption` に入れる。空ならフォームの `Caption` が出る |
| コードで表示ページを変えたときもイベントを出す | `Options` に `nboDoChangeOnSetIndex` を入れる |

## 7. キー操作

Ctrl+Tab・Ctrl+Shift+Tab は、次の順番で届く。

| 順番 | 処理 |
|---|---|
| 1 | フォームの `OnKeyDown`（`KeyPreview = True` のとき）。`Key := 0` にすると、タブは切り替わらない |
| 2 | TCPageControl のタブの切り替え |

- タブ名の編集中に、フォームの `OnKeyDown` で Enter・Esc を `Key := 0` にすると、確定・取りやめができなくなる。
- TCMonacoEditor・TCTabBrowser など WebView2 を使う部品にフォーカスがあるときは、キーをその部品が受ける。

## 8. 表示

### 8.1 色（ダーク／ライト）

システム色だけで描く。ダーク／ライトの切り替えは、アプリ側の MetaDarkStyle などに任せる。

| 部分 | 色 |
|---|---|
| タブ列の背景 | 単体時：TCPageControl の `Color`（既定値 `clBtnFace`）。タイトルバー内：TCTitleBar の `Color`（既定値 `clBtnFace`） |
| 表示中のタブ | `clWindow`、文字 `clWindowText` |
| 表示中でないタブ | タブ列の背景、文字 `clBtnText` |
| マウスを乗せたタブ・ボタン | 背景色に `clBtnText` を少し混ぜた色 |
| ページの背景 | TCTabSheet の `Color`（既定値 `clWindow`） |
| ページが0枚のときのページの場所 | `clWindow` |
| タイトルバーの文字・記号 | `clBtnText`（フォームが非アクティブのときは `clGrayText`） |
| 閉じるボタンにマウスを乗せたとき | 赤（#C42B1C）、記号は白（ダークでも同じ） |

ボタンの記号は、Segoe Fluent Icons（なければ Segoe MDL2 Assets）の字で描く。

### 8.2 表示スケール（高 DPI）

Windows の表示スケール（125%、150% など）に合わせて、タブ・ボタン・タイトルバーの大きさを自動で拡大する（フォームの `Scaled = True` のとき）。倍率の違うモニターへ移したときも、移した先の倍率で描き直す。

- アイコンを拡大するには、TImageList の `Scaled` を `True` にし、大きさ違いの画像を用意する。
- `ImagesWidth` は 100% のときの値のまま指定する。

## 9. TPageControl との違い

| 項目 | TPageControl | TCPageControl |
|---|---|---|
| タブの描画 | Windows 標準のタブ部品が描く | 部品が自分で描く |
| ダーク表示 | Windows 標準のタブ部品の表示になる | MetaDarkStyle に追従する（システム色で描く） |
| タイトルバーにタブを載せる | できない | TCTitleBar と組み合わせてできる |
| ［×］閉じるボタン | 押されたことを知らせるだけ（`OnCloseTabClicked`）。閉じる処理はアプリが書く | 押すと自動で閉じる。取りやめたいときだけ `OnPageClose` を使う |
| ［＋］新しいタブ | なし | あり（末尾に作る。`OnNewPage`） |
| ［∨］タブ一覧 | なし | あり（各行に［×］付き） |
| ドラッグで並べ替え | なし | あり（`OnPageMoved`） |
| 右クリックメニュー | アプリが作る | 標準の項目を内蔵。アプリの項目を `TabPopupMenu` で追加できる |
| タブ名の変更 | なし | タブの上でその場で編集する（`OnPageRename`） |
| タブが多いとき | 複数段（`MultiLine`）、またはスクロール | 1段のみ。［◀▶］とマウスホイールでスクロール |
| タブの位置 | 上・下・左・右 | 上・下のみ |
| タブの形 | `Style`（タブ・ボタン形） | `TabShape`（四角・角丸） |
| `Options` の既定値 | 空（何も有効でない） | ［×］・［＋］・Ctrl+Tab が最初から有効 |
| 背景色（`Color`） | 指定できない | タブ列・ページとも指定できる |
| 持たないもの | ― | `MultiLine`、`RaggedRight`、`ScrollOpposite`、`Style`、`HotTrack`、`ShowTabs`、`OnCloseTabClicked`、ドッキング関係（`DockSite` など） |
| 対応OS | LCL が動くOSすべて | Windows 11 |

### 9.1 注意

- 1つの TCTitleBar に入れられる TCPageControl は1つだけ。別の TCPageControl の `TitleBar` に同じ TCTitleBar を選ぶと、前の TCPageControl のタブ列は元の位置に戻る。
- 設計時に1つのフォームへ2つ目の TCTitleBar を置こうとすると「TCTitleBar は1つのフォームに1つだけ置けます」と出て、置かれない。
- `Form.WindowProc` を差し替えているアプリでも、TCTitleBar は動く。
## 10. 使い方の例

### 10.1 ［＋］・メニューで作ったタブに TMemo を置く

```pascal
procedure TForm1.CPageControl1NewPage(Sender: TObject; APage: TCTabSheet);
var
  M: TMemo;
begin
  M := TMemo.Create(APage);
  M.Parent := APage;
  M.Align := alClient;
end;
```

### 10.2 閉じる前に確かめる

```pascal
procedure TForm1.CPageControl1PageClose(Sender: TObject; APage: TCTabSheet;
  var CanClose: Boolean);
begin
  CanClose := MessageDlg(APage.Caption + ' を閉じますか？',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;
```

### 10.3 表示中のタブが変わったら、タイトルに出す

```pascal
procedure TForm1.CPageControl1Change(Sender: TObject);
begin
  if CPageControl1.ActivePage <> nil then
    CTitleBar1.Caption := CPageControl1.ActivePage.Caption + ' - MyApp'
  else
    CTitleBar1.Caption := 'MyApp';
end;
```

### 10.4 コードでページを作る・表示する・閉じる

```pascal
procedure TForm1.Button1Click(Sender: TObject);
var
  P: TCTabSheet;
begin
  P := CPageControl1.AddTabSheet;   // 末尾に作る（表示ページは変わらない）
  P.Caption := 'ログ';
  CPageControl1.ActivePage := P;    // 表示する
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  if CPageControl1.ActivePage <> nil then
    CPageControl1.ActivePage.Free;  // 閉じる（OnPageClose は出ない）
end;
```

### 10.5 右クリックメニューにアプリの項目を足す

1. TPopupMenu をフォームに置き、項目（例：「名前を表示」）を作る。
2. TCPageControl の `TabPopupMenu` に、その TPopupMenu を選ぶ。
3. 項目の `OnClick` に、次の処理を書く。

```pascal
procedure TForm1.MenuItemShowNameClick(Sender: TObject);
begin
  if CPageControl1.PopupPage <> nil then   // 右クリックされたタブ
    ShowMessage(CPageControl1.PopupPage.Caption);
end;
```

### 10.6 名前の変更で、空白を取り除く・同じ名前を断る

```pascal
procedure TForm1.CPageControl1PageRename(Sender: TObject; APage: TCTabSheet;
  var ACaption: string; var CanRename: Boolean);
var
  i: Integer;
begin
  ACaption := Trim(ACaption);
  for i := 0 to CPageControl1.PageCount - 1 do
    if (CPageControl1.Pages[i] <> APage) and (CPageControl1.Pages[i].Caption = ACaption) then
    begin
      ShowMessage('同じ名前のタブがあります');
      CanRename := False;
      Exit;
    end;
end;
```

### 10.7 変更のあったタブのアイコンを変える

```pascal
// ImageList1：0 = 保存済み、1 = 変更あり。CPageControl1.Images に ImageList1 を選んでおく
procedure TForm1.SetPageModified(APage: TCTabSheet; AModified: Boolean);
begin
  if AModified then
    APage.ImageIndex := 1    // 書くと、タブがすぐに描き直される
  else
    APage.ImageIndex := 0;
end;
```

### 10.8 キーで次・前のタブへ移る

```pascal
CPageControl1.SelectNextPage(True);    // 次のタブ（端では先頭に戻る）
CPageControl1.SelectNextPage(False);   // 前のタブ（端では末尾に戻る）
```

### 10.9 コードで作る

```pascal
uses
  uCPageControl, uCTitleBar;

procedure TForm1.FormCreate(Sender: TObject);
var
  TB: TCTitleBar;
  PC: TCPageControl;
  P: TCTabSheet;
begin
  TB := TCTitleBar.Create(Self);
  TB.Parent := Self;                   // フォームに直接置く（上端に置かれる）

  PC := TCPageControl.Create(Self);
  PC.Parent := Self;
  PC.Align := alClient;
  PC.TitleBar := TB;                   // タブ列をタイトルバーの中に入れる
  PC.OnNewPage := @CPageControl1NewPage;   // 10.1 の処理を使う

  P := TCTabSheet.Create(Self);
  P.Caption := 'ホーム';
  P.PageControl := PC;                 // PC の末尾のページになる
  PC.ActivePage := P;
end;
```
