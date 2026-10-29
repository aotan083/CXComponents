# TCPageControl 設計書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 目的

ブラウザ（Firefox）のように、タイトルバーの位置にタブを並べた画面を、フォームに部品を置き、オブジェクトインスペクタで設定するだけ（コードを書かずに）作れるようにする。

- タブコントロール（TCPageControl）は単体でも使える（タイトルバーに載せない通常の使い方）。
- タイトルバー部品（TCTitleBar）に載せると、タブとタイトルバーが一体に見える。
- アプリが書くのは、ボタンやメニューを押したときの、アプリ固有の処理だけ。

## 2. 基本方針

| No | 方針 |
|---|---|
| 1 | 部品は「タイトルバー担当（TCTitleBar）」と「タブコントロール（TCPageControl）」の2つに分ける |
| 2 | プロパティ・型・イベント・メソッドの名前は、基準にする LCL 部品に合わせる。基準部品にない機能だけ独自の名前にし、本書では「独自」と書く |
| 3 | 基準にする LCL 部品：TCTitleBar＝TPanel、TCPageControl＝TPageControl、TCTabSheet＝TTabSheet |
| 4 | テーマは MetaDarkStyle に任せる。部品は自分でテーマを判定しない。描画にはシステム色（`clBtnFace`・`clBtnText`・`clWindow` など）を使う。設計時に固定の色を指定したときはその色を使う |
| 5 | Windows 11 だけを対象にする（Windows のバージョンを判定するチェックは入れない）。Windows 以外では TCTitleBar はフォームに手を入れず、普通のパネルとして動く（最小化・最大化・閉じるボタンは出さない） |
| 6 | TCMonacoEditor・TCTabBrowser の内蔵タブとは「画面の切り替え＝TCPageControl、その中のファイルなど＝各部品の内蔵タブ」で使い分ける |

## 3. 構成

### 3.1 クラス

| クラス | 元のクラス | ユニット | パレット | 役割 |
|---|---|---|---|---|
| `TCTitleBar` | `TCustomPanel` | `uCTitleBar` | CX | タイトルバー担当。フォームのタイトルバーを取り除き、その位置に自分を置く |
| `TCPageControl` | `TCustomControl` | `uCPageControl` | CX | タブコントロール本体。タブ列とページの集まり |
| `TCTabSheet` | `TCustomControl` | `uCPageControl` | 登録しない | タブ1枚分のページ。TCPageControl の設計時メニューで作る |
| `TCTabStrip` | `TCustomControl` | `uCPageControl` | 内部用 | タブ列の描画と操作。TCPageControl が中に持つ |
| `TCTabListPopup` | `TCustomForm` | `uCPageControl`（implementation） | 内部用 | ［∨］で開くタブ一覧 |
| `TCTabListView` | `TCustomControl` | `uCPageControl`（implementation） | 内部用 | タブ一覧の中身（行を描く） |

**TCPageControl を TPageControl から作らない理由**：Windows 版の LCL では、TPageControl のタブは Windows 標準のタブ部品で描かれる。標準のタブ部品では、ダーク表示、各タブの［×］、［＋］［∨］、ドラッグでの並べ替え、タイトルバーへの載せ替えを自由に描けない。そのため `TCustomControl` から作り、名前と型だけを TPageControl に合わせる。

### 3.2 ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCTitleBar.pas` | cx（実行時） | `TCTitleBar`、interface `ICTitleBarDragArea`・`ICTitleBarDesignHit`、共用の関数（`CXScale96`・`CXBlendColor`・`CXSymbolFontName`・`CXSymbol`・`CXSetSymbolFont`・`CTitleBarHookChild`） |
| `uCPageControl.pas` | cx（実行時） | `TCPageControl`、`TCTabSheet`、`TCTabStrip`、`TCTabListPopup`、`TCTabListView` |
| `uCPageControl_reg.pas` | cxdsgn（設計時） | `Register`（パレット CX への登録）、コンポーネントエディタ、選択の変化でページを切り替える処理 |
| `cpagecontrol_icon.lrs` | cxdsgn（設計時） | アイコン（9.1） |

- `uCPageControl` は `uCTitleBar` を使う（逆向きはない）。
- `uCTitleBar` の uses：`Windows`（Windows のときだけ。`Types` の `Rect`・`Point` を隠さないよう先に書く）、`Classes, SysUtils, Types, Controls, ExtCtrls, Graphics, Forms, LCLType, LCLIntf, LMessages, LCLProc`。implementation で `ShellApi`（Windows のとき）、`LazUTF8`。
- `uCPageControl` の uses：`Windows`（同上）、`Classes, SysUtils, Types, Math, Controls, Graphics, Forms, StdCtrls, ExtCtrls, Menus, ComCtrls, ImgList, LCLType, LCLIntf, LMessages, LCLProc, uCTitleBar`。
- `uCPageControl` の initialization：`RegisterClass(TCTabSheet)`。
- `uCPageControl_reg` の uses：`Windows`（同上）、`Classes, SysUtils, Controls, Forms, LResources, ComponentEditors, PropEdits, uCTitleBar, uCPageControl`。

## 4. 使い方の形（コードを書かない手順）

1. フォームに TCTitleBar を置く（自動で `Align = alTop`）。
2. フォームに TCPageControl を置き、`Align = alClient` にする。
3. TCPageControl の `TitleBar` に TCTitleBar を選ぶ → タブ列がタイトルバーの中に移る。
4. TCPageControl を右クリック →「新しいページ」でページを作り、部品を置く。
5. タイトルバーに TToolBar や TSpeedButton を置くときは、`Align = alLeft`・`alRight` で置く。タブ列はその間の残りの幅に入る。

単体で使うときは、1 と 3 を行わない。タブ列は TCPageControl の上（または下）に出る。

---

## 5. TCPageControl

### 5.1 画面の並び

```
[◀][タブ1][タブ2]…[タブn][▶][＋]          [∨]
```

| 部分 | 出す条件 |
|---|---|
| ［◀］［▶］ | タブの合計の幅がタブ列に入りきらないときだけ |
| ［＋］ | `Options` に `nboShowAddTabButton` があるとき。最後のタブのすぐ右（入りきらないときは［▶］の右） |
| ［∨］ | `ShowTabListButton = True` のとき。タブ列の右端 |
| 各タブの［×］ | `Options` に `nboShowCloseButtons` があるとき。すべてのタブに出す |

タブは1段だけ。

### 5.2 プロパティ

「LCL」列：○＝TPageControl と同じ名前・型・意味、独自＝独自のもの。

| 名前 | 型 | 既定値 | 公開 | LCL | 中身 |
|---|---|---|---|---|---|
| `ActivePage` | `TCTabSheet` | nil | published | ○ | 表示中のページ |
| `ActivePageIndex` | `Integer` | -1 | public | ○ | 表示中のページの番号（0 から） |
| `PageCount` | `Integer` | 0 | public（読み） | ○ | ページの数 |
| `Pages[Index]` | `TCTabSheet` | ― | public（読み） | ○ | ページ |
| `TabIndex` | `Integer` | -1 | published | ○ | `ActivePageIndex` と同じ値（読み書きとも `FPageIndex` そのもの。LCL の TCustomTabControl と同じ） |
| `Images` | `TCustomImageList` | nil | published | ○ | タブのアイコン |
| `ImagesWidth` | `Integer` | 0 | published | ○ | アイコンの幅（0＝画像リストの幅） |
| `TabPosition` | `TTabPosition` | `tpTop` | published | ○ | `tpTop`・`tpBottom` だけ。`tpLeft`・`tpRight` は `tpTop` として出す。`TitleBar` を指定したときは使わない |
| `TabHeight` | `Smallint` | 0 | published（0 より大きいときだけ保存） | ○ | タブの高さ（0＝自動。単体は 28、タイトルバー内はタイトルバーの高さ − 6。96dpi のとき） |
| `TabWidth` | `Smallint` | 0 | published（0 より大きいときだけ保存） | ○ | タブの幅（0＝文字に合わせる。上限は `TabMaxWidth`） |
| `Options` | `TCTabControlOptions` | `[nboShowCloseButtons, nboShowAddTabButton, nboKeyboardTabSwitch]` | published | ○ | 下の表。既定値は LCL と違う（LCL は `[]`）。置いただけで［×］・［＋］・Ctrl+Tab が使えるようにするため |
| `TabShape` | `TCTabShape` | `tsRectangle` | published | 独自 | タブの形。`tsRounded` は上の角を丸くする（`TabPosition = tpBottom` なら下の角） |
| `TabMaxWidth` | `Integer` | 240 | published | 独自 | `TabWidth = 0` のときのタブの最大の幅（96dpi のとき）。超える文字は「…」 |
| `ShowTabListButton` | `Boolean` | `True` | published | 独自 | ［∨］を出す |
| `NewPageCaption` | `string` | '新しいタブ' | published（既定値と違うときだけ保存） | 独自 | ［＋］・メニューで作ったタブの文字 |
| `TabMenuItems` | `TCTabMenuItems` | `[tmiNew, tmiClose, tmiRename]` | published | 独自 | 右クリックメニューに出す標準の項目 |
| `TabPopupMenu` | `TPopupMenu` | nil | published | 独自 | タブの右クリックメニューに足すアプリのメニュー |
| `TabListPopupMenu` | `TPopupMenu` | nil | published | 独自 | タブ一覧の上に足すアプリのメニュー |
| `PopupPage` | `TCTabSheet` | nil | public（読み） | 独自 | 右クリックされたタブのページ（空き部分なら nil） |
| `TitleBar` | `TCTitleBar` | nil | published | 独自 | タブ列を載せるタイトルバー |
| `TabStrip` | `TCTabStrip` | ― | public（読み） | 独自 | 中のタブ列 |
| `Color` | `TColor` | `clBtnFace` | published | 独自 | タブ列の背景色（単体時）。TPageControl では非公開だが、自分で描くので公開する |
| `ParentColor` | `Boolean` | `False` | published | ○ | |
| ほか | ― | ― | published | ○ | `Align, Anchors, BorderSpacing, BiDiMode, Constraints, DragCursor, DragKind, DragMode, Enabled, Font, ParentBiDiMode, ParentFont, ParentShowHint, PopupMenu, ShowHint, TabOrder, TabStop, Visible` |

**Options（`TCTabControlOptions`。LCL の型をそのまま使う）**

| 値 | 動作 |
|---|---|
| `nboShowCloseButtons` | 各タブに［×］を出す |
| `nboShowAddTabButton` | ［＋］を出す |
| `nboKeyboardTabSwitch` | Ctrl+Tab・Ctrl+Shift+Tab でタブを切り替える |
| `nboDoChangeOnSetIndex` | コードで `ActivePage`・`ActivePageIndex`・`TabIndex` を変えたときも `OnChanging`・`OnChange` を出す（`OnChanging` で取りやめられたら変えない）。ないときは、コードで変えても出さない |
| `nboMultiLine` | 使わない（タブは1段） |
| `nboHidePageListPopup` | 使わない（一覧は `ShowTabListButton` で切り替える） |

**型**

```pascal
TCTabShape = (tsRectangle, tsRounded);
TCTabMenuItem  = (tmiNew, tmiClose, tmiRename);
TCTabMenuItems = set of TCTabMenuItem;
TCNewPageEvent    = procedure(Sender: TObject; APage: TCTabSheet) of object;
TCPageCloseEvent  = procedure(Sender: TObject; APage: TCTabSheet; var CanClose: Boolean) of object;
TCPageRenameEvent = procedure(Sender: TObject; APage: TCTabSheet; var ACaption: string; var CanRename: Boolean) of object;
TCPageMovedEvent  = procedure(Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer) of object;
```

**`PopupMenu` ではなく `TabPopupMenu` を持つ理由**：LCL の `PopupMenu` は部品全体の右クリックで出るため、ページの中（エディタなど）を右クリックしたときにもタブのメニューが出てしまう。タブ列だけのメニューとして別に持つ。`PopupMenu` は LCL の標準どおり残す。

resourcestring（interface）：`rsCTabNew = '新しいタブ'`、`rsCTabClose = 'タブを閉じる'`、`rsCTabRename = 'タブ名の変更'`、`rsCTabNewPageCaption = '新しいタブ'`、`rsCTabCannotHaveParent = '%s の親にできるのは TCPageControl だけです（%s は指定できません）'`

### 5.3 メソッド

| 名前 | LCL | 中身 |
|---|---|---|
| `function AddTabSheet: TCTabSheet` | ○ | Owner は自分の Owner（なければ自分）で作り、`Caption := NewPageCaption`、`Parent := Self`（末尾に入る）。表示中のページは変えない（ページが0枚だったときだけ、LCL と同じく最初のページが表示中になる）。`OnNewPage` は出さない |
| `function FindNextPage(CurPage: TCTabSheet; GoForward, CheckTabVisible: Boolean): TCTabSheet` | ○ | 次（前）のページ。端では反対側に回る。`CurPage` が見つからなければ、前へは先頭から、次へは末尾から数える。一周して見つからなければ nil |
| `procedure SelectNextPage(GoForward: Boolean)` | ○ | `SelectNextPage(GoForward, True)` |
| `procedure SelectNextPage(GoForward: Boolean; CheckTabVisible: Boolean)` | ○ | `FindNextPage` で見つけたページが今と違えば `ActivePage := ページ` |
| `function IndexOfTabAt(X, Y: Integer): Integer` / `(P: TPoint)` | ○ | 座標をタブ列の座標に直し（`- FStrip.Left`・`- FStrip.Top`）、見えているタブの `TabIndex`。なければ -1 |
| `function IndexOfPageAt(X, Y: Integer): Integer` / `(P: TPoint)` | ○ | 同じく、そのタブの `PageIndex` |
| `function IndexOf(APage: TPersistent): Integer` | ○ | `FPages.IndexOf`（`FPages` が nil なら -1） |
| `procedure Clear` | ○ | `FClearing := True` の間に、後ろから全ページを `Free`。`FPageIndex := -1`、`PageChanged`。表示中があって、読み込み中・設計時・壊している途中でなければ `Change`。`OnPageClose` は出さない |
| `function TabRect(AIndex: Integer): TRect` | ○ | `AIndex` はページの番号。タブ列の `TabRectOf` をタブ列の位置だけずらして返す。見えていなければ空 |
| `procedure EditPageCaption(APage: TCTabSheet)` | 独自 | ページがない・隠れていれば何もしない。編集中なら先にそれを確定。`EnsureVisible`、`BeginEdit`（5.5.4） |

- 座標は、タブ列を持つ部品の座標（単体なら TCPageControl、`TitleBar` 指定時は TCTitleBar）。
- ページの削除は LCL と同じく `APage.Free`、並べ替えは `APage.PageIndex := n`。どちらも `OnPageClose`・`OnPageMoved` は出さない（画面の操作のときだけ出す）。

### 5.4 イベント

| 名前 | 型 | LCL | 出るとき |
|---|---|---|---|
| `OnChange` | `TNotifyEvent` | ○ | 表示中のページが変わった後 |
| `OnChanging` | `TTabChangingEvent` | ○ | 表示中のページが変わる前。`AllowChange := False` で取りやめ |
| `OnGetImageIndex` | `TTabGetImageEvent` | ○ | タブを描く前（`GetImageIndex` の中）。アイコンを変えたいとき |
| `OnNewPage` | `TCNewPageEvent` | 独自 | ［＋］・右クリックメニューでタブを作った後 |
| `OnPageClose` | `TCPageCloseEvent` | 独自 | ［×］・右クリックメニュー・タブ一覧の［×］で閉じる前。`CanClose := False` で取りやめ |
| `OnPageRename` | `TCPageRenameEvent` | 独自 | その場編集で文字を確定する前。`ACaption` を書き換えられる。`CanRename := False` で取りやめ |
| `OnPageMoved` | `TCPageMovedEvent` | 独自 | ドラッグでタブを動かした後 |
| `OnContextPopup`・`OnDragDrop`・`OnDragOver`・`OnEndDrag`・`OnEnter`・`OnExit`・`OnMouseDown`・`OnMouseEnter`・`OnMouseLeave`・`OnMouseMove`・`OnMouseUp`・`OnMouseWheel`・`OnMouseWheelDown`・`OnMouseWheelUp`・`OnResize`・`OnStartDrag` | ― | ○ | 標準どおり |

**LCL の `OnCloseTabClicked` を持たない理由**：これは「［×］が押された」ことを知らせるだけで、閉じるのはアプリの仕事になる。コードを書かずに使うという目的に合わないため、［×］で自動で閉じ、取りやめたいときだけ `OnPageClose` を使う。同じことを2通りでできる形を避けるため作らない。

### 5.5 動作

#### 5.5.1 タブを作る（DoAddButtonClick）

1. `CanChange` が `False`（`OnChanging` で取りやめ）なら作らない。
2. Owner は自分の Owner（なければ自分）で `TCTabSheet.Create`、`Caption := NewPageCaption`、`Parent := Self`（末尾に入る）。
3. 表示中でなければ `InternalSetPageIndex(新しいページの番号)`。
4. `FStrip.EnsureVisible(新しいページ)`、`Change`（`OnChange`）、`OnNewPage`。

右クリックメニュー「新しいタブ」（`DoMenuNewClick`）も同じ。

#### 5.5.2 タブを閉じる（ClosePageByUser）

| 操作 | 対象 |
|---|---|
| タブの［×］（`DoCloseButtonClick`） | そのタブ（表示中に切り替えずに閉じる） |
| 右クリック「タブを閉じる」（`DoMenuCloseClick`） | 右クリックしたタブ |
| タブ一覧の［×］（`DoTabListCloseClick`） | その行のタブ |

手順：ページがなければ終わる → `CanClose := True` で `OnPageClose` → `True` ならページを `Free`。

- `Free` で `RemovePage` が呼ばれる（5.6）。表示中のタブを閉じたときは右隣（なければ左隣）を表示し、`OnChange` を出す（`OnChanging` は出さない。閉じることは決まっているため）。
- ページが0枚になってもよい（TPageControl と同じ）。

#### 5.5.3 右クリックメニュー（ShowTabMenu）

| 右クリックした場所 | 出す項目 |
|---|---|
| タブの上 | 「新しいタブ」「タブを閉じる」「タブ名の変更」（`TabMenuItems` にあるものだけ）→ 区切り線 → `TabPopupMenu` の項目 |
| 単体時のタブ列の空き部分 | 「新しいタブ」→ 区切り線 → `TabPopupMenu` の項目 |
| タイトルバー内のタブ列の空き部分 | Windows 標準のシステムメニュー（空き部分はタイトルバーと同じ扱い。7.5） |

手順：

1. `FPopupPage := APage`（空き部分なら nil）。右クリックではタブを表示中に切り替えない。
2. メニュー `FMenu`（なければ作る）の項目を消して作り直す。標準の項目は `TabMenuItems` に従う（「タブを閉じる」「タブ名の変更」はタブの上のときだけ）。
3. `TabPopupMenu` に項目があれば、先に `TabPopupMenu.OnPopup` を呼ぶ（アプリが項目の状態を変えられるように）。標準の項目があれば区切り線を足す。`FMenu.Images := TabPopupMenu.Images`、`CopyMenuItems`。
4. 項目が0なら出さない。`PopupComponent := Self` にして `Popup`。

`CopyMenuItems`：元の項目ごとに写しを作り、`Caption`・`Enabled`・`Visible`・`Checked`・`RadioItem`・`GroupIndex`・`ImageIndex`・`ShortCut`・`Hint`・`Default` を写す。`Tag` に元の項目を入れる。子があれば子も写す。区切り線でない末端の項目は `OnClick := MenuAppItemClick`（→ `DoAppMenuItemClick(元の項目, FPopupPage)` → `FPopupPage := APage`、`AItem.Click`。`OnClick` の `Sender` は元の項目、`Action` も元の項目のものが動く）。

#### 5.5.4 タブ名の変更（その場編集）

- 右クリック「タブ名の変更」（`DoMenuRenameClick`）または `EditPageCaption` で始める。
- `TCTabStrip.BeginEdit(APage)`：タブの文字の位置（アイコンと［×］を除いた範囲。幅は最小 40）に `TEdit`（`bsSingle`、Font は TCPageControl の Font）を重ね、今の文字を入れ、フォーカスして全選択する。タブの文字は描かない。
- Enter または入力欄からフォーカスが外れたら確定（`DoEditCaptionConfirm(入力欄の文字)`）、Esc で取りやめ（`DoEditCaptionCancel`）。
- 確定：編集中でなければ終わる。ページを覚えて `EndEdit`。文字が空なら何もしない（元のまま）。`CanRename := True` で `OnPageRename(Page, S, CanRename)`。`CanRename` で `S` が空でなければ `Caption := S`。
- 編集中にタブ列が左クリックされたときも、先に確定する。
- `EndEdit` は入力欄を隠し、`Application.QueueAsyncCall(FreeEditAsync)` で後から解放する（入力欄のイベントの中から解放しないように）。

#### 5.5.5 ドラッグでの移動

- タブの上で左ボタンを押した時点で、そのタブを表示中にする（`DoTabClick`）。取りやめられて表示中にならなければドラッグもしない。表示中になったら、ドラッグするページと押した位置を覚える。
- `Mouse.DragThreshold` 以上動いたらドラッグを始める。`Application.AddOnKeyDownBeforeHandler(DragKeyDown)` を付け、自動スクロールのタイマー（50ms）を動かす。
- ドラッグ中は、落とす位置（`DropIndexAt`：見えているタブの中央より左なら、そのタブの前。どれでもなければ末尾）に `clHighlight` の縦線（幅2）を描く。
- 自動スクロール：マウスがタブ列の見える範囲の左端・右端から `CPC_AUTOSCROLL` 以内なら、10（96dpi）ずつスクロールして落とす位置を計算し直す。
- 離したとき（`FinishDrag`）：ドラッグを終え（`CancelDrag`）、タブ列の外なら何もしない。落とす位置をページの番号に直し（末尾なら `PageCount`）、元の番号より後ろなら 1 引く。同じなら何もしない。`MovePage(ページ, 新しい番号)` のあと `OnPageMoved(ページ, 元の番号, 新しい番号)`。
- ドラッグ中に Esc：`Key := 0`、`CancelDrag`（キーの受け取りを外し、状態を戻し、`MouseCapture := False`）。
- LCL の `DragMode`・`DragKind`（ほかの部品へのドラッグ＆ドロップ）とは別の仕組み。

#### 5.5.6 スクロール

- ［◀］［▶］を押すと1枚分ずつスクロールする（`ScrollStep`：［▶］は、右端が見える範囲を超える最初のタブの右端に合わせる。［◀］は、左端が見える範囲より左にある最後のタブの左端に合わせる）。押し続けると繰り返す（最初 400ms、その後 100ms ごと）。
- タブ列の上でマウスホイールを回すとスクロールする（入りきらないときだけ。上で［◀］、下で［▶］と同じ）。
- 表示中のタブが変わったとき、タブ列の幅が変わったときは、表示中のタブが見える位置までスクロールする（`EnsureVisible`）。
- 端まで行ったボタンは無効表示にする。

#### 5.5.7 タブ一覧（［∨］）

- ［∨］を押すと、タブ列の下（［∨］の右端にそろえる）に一覧を出す（`ShowTabList`。設計時は何もしない。出ていれば閉じる）。一覧が閉じた直後（300ms 以内）の押下は、閉じる操作として扱い、開き直さない。
- 上から：`TabListPopupMenu` の項目（子を持つ項目は出さない）→ 区切り線 → すべてのタブ（並び順。アイコン＋文字＋［×］）。
- 表示中のタブの行は太字。
- 行を押す → `DoTabListItemClick`（そのタブを表示中にする）、一覧を閉じる。
- 行の［×］を押す → `DoTabListCloseClick`（5.5.2）。一覧は閉じずに行を減らす（続けて閉じられる）。
- `TabListPopupMenu` の項目を押す → 元の項目の `Click`、一覧を閉じる。
- 一覧の外を押す（一覧が非アクティブになる）、Esc → 一覧を閉じる。
- 幅は 300（96dpi）。高さは行の数に合わせる（枠線の分を含める）。画面に入りきらないときだけ縦スクロールする（`TScrollBox` の中に `TCTabListView` を置く）。
- 行の幅は、窓を出した後（`DoShow`）と、窓の大きさが変わったとき（`ScrollResize`）に、窓の中の幅に合わせ直す（初めて開くときは、出す前の時点では窓の幅が反映されていないため）。
- `TCTabListPopup` は `TCustomForm` を `CreateNew(nil)` で作る：`BorderStyle := bsNone`、`ShowInTaskBar := stNever`、`FormStyle := fsStayOnTop`、`KeyPreview := True`、枠線はフォームの `BorderWidth := 1` と `Color := clBtnShadow` で描く。中に `TScrollBox`（`alClient`、枠なし、横スクロールなし、`clWindow`）と `TCTabListView` を置く。`CreateParams` で `WS_POPUP`・`WS_EX_TOOLWINDOW`、`WndParent` を TCPageControl のフォームにする。`DoShow` で、`dwmapi.dll` の `DwmSetWindowAttribute(Handle, 33 {DWMWA_WINDOW_CORNER_PREFERENCE}, DWMWCP_ROUND)` を呼んで角を丸くする。
- 一覧はフォームが持ち主の窓なので、一覧へ移ってもタイトルバーはアクティブのままに見せる（7.4 の `WM_ACTIVATE`）。

#### 5.5.8 キーボード（KeyDownBefore）

`Application.AddOnKeyDownBeforeHandler` で受ける（フォーカスのある部品より先に届く）。

1. `nboKeyboardTabSwitch` がない、Tab でない、Shift の状態が `[ssCtrl]`・`[ssCtrl, ssShift]` でない、ページが0、のどれかなら何もしない。
2. `IsKeyTarget(Sender)` でなければ何もしない。
3. フォームの `KeyPreview` が `True` なら、先にフォームの `KeyDown` を呼ぶ。`Key = 0` になったら何もしない（アプリの処理を優先する）。
4. 次（Shift があれば前）の、`TabVisible` のページを `FindNextPage` で探す。`Key := 0`。見つかって今と違えば `UserSelectPage`（`OnChanging`・`OnChange`）。

`IsKeyTarget(AFocused)`：

- 自分が見えていて使える、`AFocused` が `TControl` で、同じフォームにある、が前提。
- フォーカスのある部品を自分が含んでいれば `True`。
- ほかの TCPageControl が含んでいれば `False`（そちらが受ける）。
- どれにも含まれないときは、フォームの `Components` の中で最初に見つかった、見えている TCPageControl が受ける。

- WebView2 を使う部品（TCMonacoEditor、TCTabBrowser など）にフォーカスがあるときは、キーをブラウザ側が受けるので届かない。
- その場編集中の Enter・Esc も、`KeyPreview = True` なら先にフォームの `OnKeyDown` に届く。そこで `Key := 0` にされると確定・取りやめが効かない（取説に書いてある）。

### 5.6 内部の手続き

| 手続き | 処理 |
|---|---|
| `Create` | `ControlStyle` から `csAcceptsControls`（TCPageControl 自体には置けない。置いた部品は表示中のページに入る）・`csSetCaption` を除く。`FPages`、既定値、`FImageChangeLink`、`Color := clBtnFace`、`ParentColor := False`、`TabStop := True`。タブ列 `FStrip := TCTabStrip.Create(Self)`、`Align := alTop`、`Parent := Self`。既定の大きさ 300 × 200（`GetControlClassDefaultSize`）。設計時でなければ `AddOnKeyDownBeforeHandler(KeyDownBefore)` |
| `Destroy` | キーの受け取りを外す。タブ一覧を解放。`FClearing := True` で全ページを後ろから `Free`。`FPages` を解放。タブ列がタイトルバーにあれば `Parent := nil`。`FImageChangeLink` を解放。`inherited` |
| `SetActivePage(v)` | `v` がこの部品のページでなければ何もしない。`SetActivePageIndex(IndexOf(v))` |
| `SetActivePageIndex(v)` | 範囲外・同じなら何もしない。読み込み中は `FPageIndex := v` だけ。`nboDoChangeOnSetIndex` があって `CanChange` が `False` なら何もしない。`InternalSetPageIndex(v)`。設計時・読み込み中・壊している途中でなく `nboDoChangeOnSetIndex` があれば `Change` |
| `InternalSetPageIndex(v)` | イベントを出さずに表示中を変える。`FPageIndex := v`、`UpdateDesignerFlags`、読み込み中でなければ `ShowCurrentPage(前の番号)`。表示中があれば `LayoutTabs`・`EnsureVisible`。タブ列とタブ一覧を描き直す |
| `ShowCurrentPage(Old)` | 新しいページを `Visible := True`。前のページの部品にフォーカスがあり、実行時なら、新しいページの最初の部品（`FindNextControl`）か、なければ自分にフォーカスを移す。ほかのページを `Visible := False`。全ページに `RefreshShowing` |
| `UpdateDesignerFlags` | 表示中のページだけ `csNoDesignVisible` を外し、ほかには付ける（LCL と同じ） |
| `CanChange` | 設計時・壊している途中でなければ `OnChanging` を呼び、その結果 |
| `Change` | 読み込み中・壊している途中でなければ `OnChange` |
| `PageChanged` | 壊している途中でなければ `FStrip.LayoutTabs`、タブ一覧を描き直す（文字・アイコン・設定が変わったとき） |
| `GetImageIndex(i)` | 範囲外なら -1。ページの `ImageIndex` を入れて `OnGetImageIndex` を呼ぶ |
| `UserSelectPage(P)` | 画面の操作で表示する。ないか同じなら何もしない。設計時は 9章。実行時は `CanChange` → `InternalSetPageIndex` → `Change` |
| `InsertPage(P)` | すでにあれば終わる。末尾に足す。表示中がなければ、このページを表示中にする（読み込み中でなければ `ShowCurrentPage`）。`UpdateDesignerFlags`、`PageChanged` |
| `RemovePage(P)` | なければ終わる。`FStrip.PageRemoved(P)`（マウス・ドラッグ・編集の状態を消す）。`FPopupPage` が `P` なら nil。一覧から消す。壊している途中ならここで終わる。すぐに `LayoutTabs`（タブ列が消えたページを覚えたまま描いたり調べたりしないように）。表示中だったら、`Clear` 中は -1、それ以外は `FindVisibleNear` の番号を `InternalSetPageIndex`、`Clear` 中・読み込み中・設計時でなければ `Change`。表示中より前のページなら `FPageIndex` を 1 減らす。`UpdateDesignerFlags`、`PageChanged`、表示中がなければ `Invalidate` |
| `FindVisibleNear(i)` | `i` から後ろで最初の `TabVisible`、なければ `i` より前で最後の `TabVisible`、なければ -1 |
| `MovePage(P, n)` | `n` を `0..PageCount-1` に収め、同じなら終わる。`FPages.Move`、表示中のページの番号を合わせ直す。`UpdateDesignerFlags`、`PageChanged`、設計時なら `OwnerFormDesignerModified` |
| `SetTitleBar(v)` | 同じなら終わる。前のものの通知を外す。`v` に別の TCPageControl のタブ列があれば、その TCPageControl の `TitleBar := nil`（1つのタイトルバーに1つだけ）。通知を付けて入れ、`UpdateStripPlace` |
| `UpdateStripPlace` | タイトルバーがあれば、タブ列を `Align := alNone`・`Parent := TitleBar`・`TitleBar.ReAlign`。なければ `Parent := Self`、`TabPosition = tpBottom` なら `alBottom`、ほかは `alTop`。前の親がタイトルバーで変わったら、前の親を `ReAlign`。`Visible := True`、`LayoutTabs`。置き場所が変わったら、自分を `ReAlign`・`Invalidate`・`ShowCurrentPage(-1)`（タイトルバーを外したとき、TCPageControl に枠だけが残らないように） |
| `Notification` | `opRemove` で `Images` なら `SetImages(nil)`、`TabPopupMenu`・`TabListPopupMenu` なら nil、`TitleBar` なら nil にして `UpdateStripPlace` |
| `GetChildren` | Owner が `Root` のページを並び順に渡す（`PageIndex` は保存しないため、.lfm の順が並び順になる） |
| `Loaded` | `inherited`。表示中がなくページがあれば 0、範囲外なら末尾にする。`UpdateDesignerFlags`、`ShowCurrentPage(-1)`、`UpdateStripPlace` |
| `Paint` | 表示中がなければ `clWindow`、あれば `Color` で全体を塗る（ページが0枚でも部品の範囲が分かるように） |
| `SetImages` | 前のものから変更通知と解放通知を外し、新しいものに付ける。`PageChanged` |
| `SetTabHeight`・`SetTabWidth` | 負なら 0。変わったら `PageChanged` |
| `SetTabMaxWidth` | 1 未満なら 1。変わったら `PageChanged` |
| `SetImagesWidth`・`SetOptions`・`SetShowTabListButton`・`SetTabShape` | 変わったら `PageChanged` |
| `SetTabPosition` | 変わったら `UpdateStripPlace` |
| `CMFontChanged` | `PageChanged` |
| `CMColorChanged` | タブ列と自分を描き直す |
| `DoAutoAdjustLayout` | 表示スケールが変わったとき、保存される `TabHeight`・`TabWidth` を倍率に合わせる（`TabMaxWidth` は 96dpi 基準のまま）。`PageChanged` |

### 5.7 表示（96dpi のときの大きさ。`CXScale96` で拡大する）

| 定数 | 値 | 中身 |
|---|---|---|
| `CPC_PAD` | 8 | タブの左右の余白 |
| `CPC_ICON_GAP` | 4 | アイコンと文字の間 |
| `CPC_CLOSE_SIZE` | 16 | ［×］の領域 |
| `CPC_CLOSE_HIT` | 20 | ［×］の押せる範囲 |
| `CPC_CLOSE_GAP` | 4 | 文字と［×］の間 |
| `CPC_TAB_MIN` | 60 | タブの最小の幅 |
| `CPC_ARROW_W` | 24 | ［◀］［▶］の幅 |
| `CPC_BUTTON_W` | 28 | ［＋］［∨］の幅 |
| `CPC_TAB_GAP` | 2 | タブ同士の間 |
| `CPC_RADIUS` | 6 | 角丸の半径 |
| `CPC_TAB_H` | 28 | 単体時の既定のタブの高さ |
| `CPC_TITLE_GAP` | 6 | タイトルバー内のタブの高さ＝タイトルバーの高さ − 6 |
| `CPC_SYMBOL` | 10 | 記号の字の高さ |
| `CPC_SYMBOL_S` | 8 | ［×］の記号の字の高さ |
| `CPC_LIST_W` | 300 | タブ一覧の幅 |
| `CPC_LIST_ROW` | 28 | タブ一覧の1行の高さ |
| `CPC_AUTOSCROLL` | 20 | ドラッグ中の自動スクロールが始まる、端からの距離 |

記号の字のコード：`SYM_LEFT = $E76B`、`SYM_RIGHT = $E76C`、`SYM_ADD = $E710`、`SYM_DOWN = $E70D`、`SYM_CLOSE = $E8BB`。

### 5.8 配色（すべてシステム色。MetaDarkStyle がダーク用に切り替える）

| 部分 | 色 |
|---|---|
| タブ列の背景 | 単体時：TCPageControl の `Color`。タイトルバー内：TCTitleBar の `Color` |
| 表示中のタブ | `clWindow`、文字 `clWindowText` |
| 表示中でないタブ | 背景なし（タブ列の背景）、文字 `clBtnText` |
| マウスが乗ったタブ・ボタン | 背景色に `clBtnText` を 10% 混ぜた色（`CXBlendColor`） |
| 押している間 | 背景色に `clBtnText` を 20% 混ぜた色 |
| ［×］にマウスが乗ったとき | ［×］の 16 × 16 の部分だけ、タブの背景（なければタブ列の背景）に `clBtnText` を 20% 混ぜた色（形は `TabShape` に合わせる） |
| 設計時の隠れたタブ | 文字 `clGrayText` |
| `Font.Color` を指定したとき | `clDefault`・`clWindowText` 以外なら、その色で文字を描く |
| ドラッグ中の縦線 | `clHighlight` |
| 無効のボタン | 記号 `clGrayText` |
| ページの背景 | TCTabSheet の `Color`（既定値 `clWindow`） |
| ページが0枚（表示中がない）のときのページの場所 | `clWindow` |

- `tsRounded` のタブは、`RoundRect` で塗ったあと、ページの側（上のタブなら下側）の角を四角で塗り直す。
- ボタンの記号（◀ ▶ ＋ ∨ ×）は、Segoe Fluent Icons（なければ Segoe MDL2 Assets）の字で描く（どの倍率でもにじまないため）。描くときは `CXSetSymbolFont` で、新しい字の設定に名前と高さ（ピクセル）だけを入れて Canvas に写す（TCPageControl の Font を写した Canvas の名前・高さを書き換える作りだと、Font の大きさを変えたときに記号の高さが変わらず、大きな記号の真ん中だけが切り取られて点に見えるため）。字がどちらもないときは線で描く。

### 5.9 TPageControl にあって TCPageControl に持たないもの

| 名前 | 持たない理由 |
|---|---|
| `MultiLine` | タブは1段だけ |
| `RaggedRight` | 複数段のときの並べ方の指定のため |
| `ScrollOpposite` | 複数段のときの並べ方の指定のため |
| `Style`（`tsTabs`・`tsButtons`・`tsFlatButtons`） | 見た目は `TabShape` で決める |
| `HotTrack` | マウスが乗ったタブは常に色を変える |
| `ShowTabs` | タブ列を隠す使い方は対象外 |
| `OnCloseTabClicked` | ［×］で自動で閉じ、取りやめは `OnPageClose` で行うため（5.4） |
| `DockSite`・`OnDockDrop`・`OnDockOver`・`OnEndDock`・`OnStartDock`・`OnUnDock`・`OnGetDockCaption`・`OnGetSiteInfo` | ドッキングは対象外 |

### 5.10 操作を受けたときの処理（protected・virtual）

マウスやキーで操作されたときの処理は、次のメソッドにまとめる。タブ列（TCTabStrip）はマウス・キーを受けたらこれを呼ぶだけで、処理は書かない。

| メソッド | 呼ばれる操作 | 処理 |
|---|---|---|
| `DoTabClick(APage)` | タブを左クリック | `UserSelectPage(APage)` |
| `DoAddButtonClick` | ［＋］ | 5.5.1 |
| `DoCloseButtonClick(APage)` | タブの［×］ | `ClosePageByUser`（5.5.2） |
| `DoMenuNewClick` | 右クリック「新しいタブ」 | `DoAddButtonClick` |
| `DoMenuCloseClick(APage)` | 右クリック「タブを閉じる」 | `ClosePageByUser` |
| `DoMenuRenameClick(APage)` | 右クリック「タブ名の変更」 | `EditPageCaption(APage)` |
| `DoAppMenuItemClick(AItem, APage)` | 右クリックメニューの `TabPopupMenu` の項目 | `PopupPage := APage`、`AItem.Click` |
| `DoTabListItemClick(APage)` | タブ一覧の行 | `UserSelectPage(APage)` |
| `DoTabListCloseClick(APage)` | タブ一覧の行の［×］ | `ClosePageByUser` |
| `DoEditCaptionConfirm(AText)` | 名前の編集中に Enter・フォーカスが外れた | 5.5.4 の確定 |
| `DoEditCaptionCancel` | 名前の編集中に Esc | `EndEdit` |

---

## 6. TCTabSheet

| 名前 | 型 | 既定値 | 公開 | LCL | 中身 |
|---|---|---|---|---|---|
| `Caption` | `TCaption` | '' | published | ○ | タブの文字 |
| `ImageIndex` | `TImageIndex` | -1 | published | ○ | アイコンの番号（-1＝なし） |
| `PageIndex` | `Integer` | ― | published（保存しない） | ○ | ページの位置。書くと `MovePage`。保存しないのは LCL と同じで、並び順は .lfm に書かれたページの順で決まる |
| `TabVisible` | `Boolean` | `True` | published | ○ | `False` でタブを出さない（ページは残る） |
| `TabIndex` | `Integer` | ― | public（読み） | ○ | 見えているタブだけで数えた番号（隠れていれば -1） |
| `PageControl` | `TCPageControl` | ― | public | ○ | 入っている TCPageControl（書くと `Parent := 値`） |
| `Color` | `TColor` | `clWindow` | published | 独自 | ページの背景色。TTabSheet では非公開だが、自分で描くので公開する |
| `ParentColor` | `Boolean` | `False` | published | ○ | |
| `Left`・`Top`・`Width`・`Height` | ― | ― | published（保存しない） | ○ | 大きさは TCPageControl が決める |
| ほか | ― | ― | published | ○ | `BorderWidth, ChildSizing, ClientHeight, ClientWidth, Enabled, Font, ParentFont, ParentShowHint, PopupMenu, ShowHint, OnContextPopup, OnDragDrop, OnDragOver, OnEndDrag, OnEnter, OnExit, OnHide, OnMouseDown, OnMouseEnter, OnMouseLeave, OnMouseMove, OnMouseUp, OnMouseWheel, OnMouseWheelDown, OnMouseWheelUp, OnResize, OnShow, OnStartDrag` |

**ControlStyle（LCL の TCustomPage・TCustomTabControl と同じ）**

| 部品 | ControlStyle | 意味 |
|---|---|---|
| TCTabSheet | `csAcceptsControls`・`csDesignFixedBounds`・`csNoDesignVisible`・`csNoFocus` を足す | 部品を置けるのはページだけ。設計時にページを動かしたり大きさを変えたりできない |
| TCTabSheet（表示中のページ） | `csNoDesignVisible` を外す（`UpdateDesignerFlags`） | 設計画面には表示中のページだけを出す |
| TCPageControl | `csAcceptsControls` を除く | TCPageControl 自体には部品を置けない |

**手続き**

| 手続き | 処理 |
|---|---|
| `Create` | 上の ControlStyle、`FImageIndex := -1`、`FTabVisible := True`、`Color := clWindow`、`ParentColor := False`、`Align := alClient`、`Caption := ''`、`Visible := False` |
| `Destroy` | 親が TCPageControl なら `Parent := nil`（一覧から外す）、`inherited` |
| `SetParent(v)` | 同じなら終わる。`v` が nil でも TCPageControl でもなければ `EInvalidOperation`（`rsCTabCannotHaveParent`）。前の親から `RemovePage`、`inherited SetParent`、新しい親に `InsertPage` |
| `GetTabIndex` | 親がないか隠れていれば -1。前にある見えているページの数 |
| `SetImageIndex` | 変わったら `PageControl.PageChanged` |
| `SetTabVisible(v)` | 変わったら入れる。実行時（設計時・読み込み中でない）で、表示中のページを隠したら `FindVisibleNear` のページを `InternalSetPageIndex` して `Change`（LCL と同じ）。表示中がないときに見せたら、そのページを表示中にして `Change`。最後に `PageChanged` |
| `IsControlVisible`・`HandleObjectShouldBeVisible` | `inherited` が `True` で、親が TCPageControl なら、表示中のページのときだけ `True`（LCL の TCustomPage と同じ。設計時に `ActivePage` を変えたときもフォームの表示が変わるように） |
| `RefreshShowing` | 壊している途中でなければ `UpdateControlState`・`Invalidate` |
| `Paint` | `Color` で全体を塗る |
| `CMVisibleChanged` | `inherited` のあと、見えたら `OnShow`、隠れたら `OnHide` |
| `CMTextChanged` | `PageControl.PageChanged` |

**表示中でないページの扱い**（LCL の `TCustomTabControl.ShowCurrentPage` と同じ）

- 表示中のページは `Visible := True`、ほかは `Visible := False`（5.6 `ShowCurrentPage`）。
- 独自の仕組み（ウィンドウを残したまま見えない位置に置くなど）は作らない。
- TCMonacoEditor は、表示される（Showing）まで WebView2 を作らずに待ち、それまでに設定した本文などは部品の中に預かる。そのため、表示中でないページに置いても、初めて表示されたときに起動して正しく動く。

---

## 7. TCTitleBar

### 7.1 プロパティ

| 名前 | 型 | 既定値 | 中身 |
|---|---|---|---|
| `Align` | `TAlign` | `alTop` | `alTop` に固定（`SetAlign` でほかの値は無視） |
| `Height` | `Integer` | 40（96dpi） | タイトルバーの高さ（`GetControlClassDefaultSize` は 300 × 40） |
| `Color` | `TColor` | `clBtnFace` | 背景色 |
| `ParentColor` | `Boolean` | `False` | |
| `Caption` | `TCaption` | '' | タイトルバーに出す文字（7.2）。空ならフォームの `Caption`。両方空なら出さない。タスクバーには常にフォームの `Caption` が出る |
| `Font` | `TFont` | ― | `Caption` の文字 |
| `BevelOuter` | `TPanelBevel` | `bvNone` | 枠線 |
| `Hooked` | `Boolean` | ― | public（読み）。フォームに組み込んでいるか |
| ほか | ― | ― | `Anchors, BevelInner, BevelWidth, BorderSpacing, Constraints, Enabled, ParentFont, ParentShowHint, PopupMenu, ShowHint, Visible, OnClick, OnDblClick, OnMouseDown, OnMouseEnter, OnMouseLeave, OnMouseMove, OnMouseUp, OnResize` |

`Create`：`ControlStyle` に `csAcceptsControls` を足し `csSetCaption` を除く。`Align := alTop`、`BevelOuter := bvNone`、`Color := clBtnFace`、`ParentColor := False`、アクティブ表示、`Caption := ''`、既定の大きさ。`Destroy`：`Application.RemoveAsyncCalls(Self)`。

独自のプロパティ・メソッド・イベントは `Hooked` だけ。public の `FormActivated`・`FormCaptionChanged`・`FormStateChanged`・`SetMaxButtonHot`・`SetMaxButtonDown`・`MaxButtonScreenRect`・`ScreenPointInSelf`・`IsDragPointScreen` は、ウィンドウの横取りの処理から呼ぶもの（アプリは使わない）。

最小化・最大化・閉じるボタンの有無は、フォームの `BorderIcons` に従う（`ButtonState`）。

| `BorderIcons` | 最小化 | 最大化 | 閉じる |
|---|---|---|---|
| `biSystemMenu`・`biMinimize`・`biMaximize` | 表示 | 表示 | 表示 |
| `biSystemMenu`・`biMinimize` | 表示 | 無効表示（押せない） | 表示 |
| `biSystemMenu`・`biMaximize` | 無効表示（押せない） | 表示 | 表示 |
| `biSystemMenu` だけ | 出さない | 出さない | 表示 |
| `biSystemMenu` なし | 出さない | 出さない | 出さない |

- 型：`TCTitleButton = (ctbNone, ctbMinimize, ctbMaximize, ctbClose)`、`TCTitleButtonState = (ctsHidden, ctsDisabled, ctsEnabled)`。
- 無効表示のボタンは、記号を `clGrayText` で描き、マウスを乗せても色を変えない。
- `biMaximize` がないときは、空き部分のダブルクリックで最大化せず、最大化ボタンでスナップレイアウトも出さない（Windows 標準と同じ）。

### 7.2 画面の並び

```
[alLeft の部品…][キャプション][タブ列（TitleBar 指定時）][alRight の部品…][─][□][×]
```

- 右端に最小化・最大化・閉じるボタンの領域（各 幅 46 × タイトルバーの高さ、96dpi）を取る。`AdjustClientRect` でボタンの領域を右から除くので、`alRight` の部品はその左に並ぶ。
- キャプションの領域は、`alLeft` の部品のすぐ右に置く。`AdjustClientRect` で、キャプションの幅も左から除く。
- タブ列（TCTabStrip）は、`TitleBar` で結び付けられたとき TCTitleBar の子になる。位置は TCTitleBar が `AlignControls` の中で決める（`Align` は `alNone`。キャプションの右から `alRight` の部品の左まで）。TCTitleBar は、子のうち `ICTitleBarDragArea` を持つものをタブ列として扱う。`AlignControls` は再入しない（`FAligning`）。

**キャプション**

| 項目 | 中身 |
|---|---|
| 出す文字（`DisplayCaption`） | `Caption` が空でなければ `Caption`。空ならフォーム（`GetParentForm`）の `Caption`。両方空なら出さない |
| 幅（`CaptionWidthFor`） | 文字の幅＋左右の余白 8（96dpi）。上限 200（96dpi）。超える文字は終わりを「…」。出す文字がないときは幅 0 |
| 位置 | 縦は中央、左寄せ |
| 文字 | `Font`。色は、フォームが非アクティブ（設計時を除く）なら `clGrayText`、`Font.Color` が `clDefault`・`clWindowText` なら `clBtnText`、ほかは `Font.Color` |
| フォームの `Caption` の変更 | 組み込んでいるときは、横取りした `WM_SETTEXT` を通常どおり処理した後に `FormCaptionChanged`（幅を計算し直して並べ直し、描き直す）。設計時は描くたびにフォームの `Caption` を読み、幅が変わっていたら `Application.QueueAsyncCall(AsyncRealign)` で並べ直す |
| マウス | 空き部分と同じ（7.5） |

- キャプションをタブ列の左に置く理由：タブ列は右へ伸び、右端に［∨］が付く。中央や右に置くと、タブが増えたときに重なるため。
- `Caption` が空のときにフォームの `Caption` を出す理由：フォームの `Caption` にファイル名などを入れているアプリが、コードを書かずにタイトルバーに出せる。タスクバーの名前とも一致する。

定数（96dpi）：`CTB_BUTTON_W = 46`、`CTB_CAPTION_PAD = 8`、`CTB_CAPTION_MAX = 200`、`CTB_SYMBOL_H = 10`、`CTB_DEFAULT_H = 40`。

### 7.3 フォームへの組み込み（Windows のときだけ）

- 組み込む条件（`CanHookForm`）：実行時（設計時でない）、`Parent` がフォーム（`TCustomForm`）、フォームの `BorderStyle` が `bsSizeable`・`bsSingle`、フォームのハンドルがある、フォームの直下のほかの TCTitleBar がまだ組み込んでいない（.lfm に2つあっても、組み込むのは1つ目だけ。2つ目は普通のパネル）、`SetWindowSubclass` などが読み込める。
- 組み込む時点：TCTitleBar のウィンドウが作られたとき（`CreateWnd`）。フォームのウィンドウが作り直されると子も作り直されるので、そのたびに組み込み直す。
- `CreateWnd`：`inherited` のあと、実行時で API が読み込めれば、自分のウィンドウを横取りし（`SUBCLASS_ID_SELF = $43544253`）、`HookForm`、`ReAlign`。
- `HookForm`：組み込み済みか `CanHookForm` が `False` なら終わる。フォームのウィンドウを `SetWindowSubclass`（`SUBCLASS_ID_FORM = $43544246`）で横取りする（アプリが `Form.WindowProc` を使っていても競合しない）。できたら `FHooked := True`、アクティブかを `GetActiveWindow` で覚え、`FrameChanged`。
- `DestroyWnd`：`UnhookForm`（横取りを外して `FrameChanged`）、自分のウィンドウの横取りも外し、`inherited`。
- `FrameChanged`：`SetWindowPos(SWP_FRAMECHANGED or SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE)` で枠を計算し直させ、続けて、最小化中でなければ、フォームの `InvalidateClientRectCache(True)`、今の中身の大きさで `WM_SIZE`（最大化中は `SIZE_MAXIMIZED`、ほかは `SIZE_RESTORED`）を送り、`ReAlign`。`SWP_FRAMECHANGED` だけではウィンドウの大きさが変わらないので `WM_SIZE` が届かず、LCL が前の大きさのまま部品を並べて、フォームの下に余白が残るため。外したとき・画面の倍率が変わったとき（`WM_DPICHANGED`）も同じ。
- 外す時点：TCTitleBar のウィンドウが破棄されるとき（`DestroyWnd` → `UnhookForm`）。フォームのウィンドウが `WM_NCDESTROY` を受けたときも外す。
- 設計時は組み込まない。ボタンは非アクティブの表示で描き、配置の確認だけできる。
- `SetWindowSubclass`・`RemoveWindowSubclass`・`DefSubclassProc` は `comctl32.dll` から名前で探し、なければ番号（410・412・413）で探す（`LoadSubclassApi`）。`GetSystemMetricsForDpi`・`GetDpiForWindow` は `user32.dll` から探す（なければ `GetSystemMetrics`・画面の DPI を使う）。

**1つのフォームに1つだけ**

- 設計時（新しい親が設計時のとき）：2つ目を置こうとしたら、`SetParent` で例外「TCTitleBar は1つのフォームに1つだけ置けます」（`rsCTitleBarOnlyOne`）を出して置くのをやめる。置き先（`Parent`）がフォーム・TCTitleBar・パネルなどのどれでも確かめる。置き先のフォーム（`GetParentForm`）の中のすべての部品（パネルの中なども含む）をたどり（`HasOtherTitleBar`）、自分以外の TCTitleBar があれば2つ目とみなす。フォームが読み込み中（`csLoading`）のときは確かめない（2つ入った既存の .lfm も開けるように）。
- 実行時：7.3 の最初の条件のとおり、組み込むのは1つ目だけ。

### 7.4 横取りするメッセージ（フォームのウィンドウ）

| メッセージ | 処理 |
|---|---|
| `WM_NCCALCSIZE`（`wParam <> 0`） | 上端の値を覚えて標準の計算をし、上端を元に戻す（タイトルバーの分を取り除き、左右下の枠は残す）。最大化中は、上端を枠の太さ（`FrameThickness`：`SM_CYFRAME` ＋ `SM_CXPADDEDBORDER`、DPI に合わせる）だけ内側にし、`AdjustForAutoHideTaskbar` |
| `WM_NCHITTEST` | 7.5 |
| `WM_NCMOUSEMOVE` | 最大化ボタンの上（`HTMAXBUTTON`）かを `SetMaxButtonHot` で伝える。上なら `TrackMouseEvent(TME_LEAVE or TME_NONCLIENT)` |
| `WM_NCMOUSELEAVE` | `SetMaxButtonHot(False)`、`SetMaxButtonDown(False)` |
| `WM_NCLBUTTONDOWN`・`WM_NCLBUTTONDBLCLK`（`HTMAXBUTTON`） | 標準の処理に渡さない（旧式のボタンが描かれるため）。`SetMaxButtonDown(True)`、0 を返す |
| `WM_NCLBUTTONUP`（`HTMAXBUTTON`） | 押していたら `SetMaxButtonDown(False)`、最大化中なら `SC_RESTORE`、ほかは `SC_MAXIMIZE` を `PostMessage`。0 を返す。`HTMAXBUTTON` でなければ `SetMaxButtonDown(False)` |
| `WM_ACTIVATE` | 標準の処理のあと、非アクティブになったときは、移った先がフォームを持ち主とする窓（タブ一覧など）ならアクティブのまま、ほかは非アクティブとして `FormActivated` |
| `WM_SIZE` | 標準の処理のあと `FormStateChanged`（最大化・元に戻すで最大化ボタンの記号を切り替える） |
| `WM_SETTEXT` | 標準の処理のあと `FormCaptionChanged` |
| `WM_ERASEBKGND` | 標準の処理のあと、`FillFormRemainder`：LCL が塗らない部分（フォームの `Height` より下・`Width` より右）をフォームの `Brush` で塗る。LCL はフォームの背景を `Rect(0, 0, Width, Height)` だけ塗るが、LCL の `Height` は「ウィンドウの高さ − 標準のタイトルバーと枠」で、タイトルバーを取り除いた分だけ中身より小さいため、塗らないと下に帯が残る |
| `WM_DPICHANGED`（$02E0） | 標準の処理のあと `FrameChanged` |
| `WM_NCDESTROY` | 横取りを外し、`FHooked := False` |

`AdjustForAutoHideTaskbar`：タスクバーを自動で隠す設定（`SHAppBarMessage(ABM_GETSTATE)` に `ABS_AUTOHIDE`）のとき、そのモニターの各辺について `ABM_GETAUTOHIDEBAREX`（$0B）で自動で隠れるタスクバーがあれば、その辺を 1px 空ける（最大化中にタスクバーを出せるように）。

### 7.5 マウスの位置の判定

判定は、マウスの下にあるウィンドウから順に行う。

| 場所 | 判定 | 起きること |
|---|---|---|
| ウィンドウを持つ子部品（TButton、TToolBar、TEdit など） | その部品が普通に受ける | 部品の動作 |
| ウィンドウを持たない子部品（TImage、TLabel、TSpeedButton など） | TCTitleBar が `HTCLIENT` | 部品の動作（`ControlAtPos` で調べる。`DragChildAt`） |
| タブ列のタブ・［◀▶＋∨×］ | タブ列が `HTCLIENT` | タブの動作 |
| タブ列の空き部分 | タブ列が `HTTRANSPARENT`（`ICTitleBarDragArea.IsDragArea` が `True`） | 下の「空き部分」と同じ |
| 最小化ボタン・閉じるボタン | TCTitleBar が `HTCLIENT` | TCTitleBar がマウスを受け、`SC_MINIMIZE`・`SC_CLOSE` を送る |
| 最大化ボタン | TCTitleBar が `HTTRANSPARENT` → フォームが `HTMAXBUTTON`（最大化ボタンが使えるとき） | Windows 11 のスナップレイアウトが出る。押すと最大化／元に戻す |
| 上端の枠の太さの範囲（最大化中を除く。`bsSizeable` のときだけ） | TCTitleBar が `HTTRANSPARENT` → フォームが `HTTOP`（左端から枠の太さ × 2 以内は `HTTOPLEFT`、右端から同じく `HTTOPRIGHT`） | 上方向のサイズ変更 |
| キャプションの領域、ほかの空き部分 | TCTitleBar が `HTTRANSPARENT` → フォームが `HTCAPTION` | ドラッグで移動、ダブルクリックで最大化／元に戻す、画面端へのスナップ、右クリックでシステムメニュー |

- フォームの `WM_NCHITTEST`：標準の判定が `HTCLIENT` 以外（左右下の枠など）ならそのまま。マウスがタイトルバーの外ならそのまま。ほかは上の表の最後の3行の判定。
- タイトルバー自身のウィンドウ（`SelfSubclassProc`）：組み込んでいるとき、`IsDragPointScreen` なら `HTTRANSPARENT`、ほかは `HTCLIENT`。
- タブ列のウィンドウ（`ChildSubclassProc`。`SUBCLASS_ID_CHILD = $43544243`）：親がタイトルバーで組み込んでいて、`IsDragArea` なら `HTTRANSPARENT`。タブ列の `CreateWnd`・`DestroyWnd` で `CTitleBarHookChild(Self, True/False)` を呼ぶ（設計時・ハンドルがない・API がないときは何もしない）。
- 空き部分では、TCTitleBar・TCPageControl の `OnClick` などのマウスのイベントは出ない（Windows のタイトルバーとして扱われるため）。

**interface（`uCTitleBar` で定義）**

```pascal
ICTitleBarDragArea = interface
  ['{6B0F3D2E-8A41-4C77-9E35-2B7C1D5A9F10}']
  function IsDragArea(const P: TPoint): Boolean;   // P はその部品のクライアント座標
end;

ICTitleBarDesignHit = interface
  ['{0E7C5B61-3F2A-4D8B-A1C9-58D6E4F2B370}']
  function DesignHitTest(const P: TPoint): Boolean;
  procedure DesignMouseDown(Button: TMouseButton; Shift: TShiftState; const P: TPoint);
end;
```

TCTabStrip が両方を持つ。`IsDragArea` は、ドラッグ中・編集中なら `False`、ほかは何もない場所なら `True`。

**共用の関数**

| 関数 | 中身 |
|---|---|
| `CXScale96(AControl, ASize)` | 96dpi 基準の大きさを、部品のあるフォーム（`GetParentDesignControl`）の `PixelsPerInch` で計算する。フォームにまだ置かれていない（.lfm の読み込み中など）ときは画面の倍率。LCL の `Scale96ToForm` はそのとき例外になるため使わない |
| `CXBlendColor(ABase, AMix, APercent)` | 2つの色を RGB ごとに `APercent` の割合で混ぜる |
| `CXSymbolFontName` | 'Segoe Fluent Icons'、なければ 'Segoe MDL2 Assets'、どちらもなければ ''（1回だけ調べて覚える） |
| `CXSymbol(ACode)` | Unicode の1文字を UTF-8 の文字列にする |
| `CXSetSymbolFont(ACanvas, AName, AHeightPx, AColor)` | 新しい `TFont` に名前・高さ（ピクセル）・色だけを入れて Canvas に写す |
| `CTitleBarHookChild(AChild, AHook)` | 上のとおり |

### 7.6 最小化・最大化・閉じるボタンの描画

| 状態 | 背景 | 記号 |
|---|---|---|
| 通常 | なし | `clBtnText`（非アクティブのときは `clGrayText`） |
| マウスが乗った（最小化・最大化） | `Color` に `clBtnText` を 10% 混ぜた色 | `clBtnText` |
| 押している間（最小化・最大化） | `Color` に `clBtnText` を 20% 混ぜた色 | `clBtnText` |
| マウスが乗った（閉じる） | #C42B1C（`TColor($1C2BC4)`。Windows 標準の赤・固定） | 白 |
| 押している間（閉じる） | #C42B1C を 80% の明るさにした色 | 白 |

記号：最小化 U+E921、最大化 U+E922、元に戻す U+E923、閉じる U+E8BB。

- 最小化・閉じるは TCTitleBar の `MouseDown`・`MouseUp` で押した表示をし、同じボタンの上で離したら `SC_MINIMIZE`・`SC_CLOSE` を送る。最大化はフォームの横取り（7.4）で扱う。

### 7.7 DPI

大きさはすべて 96dpi 基準で持ち、`CXScale96` で拡大する。モニター間の移動で倍率が変わったときは、枠の計算し直し（`FrameChanged`）と描き直しを行う。

---

## 8. TCPageControl と TCTitleBar の連携

| 項目 | 中身 |
|---|---|
| 結び付け | TCPageControl の `TitleBar` に TCTitleBar を指定する |
| タブ列の移動 | 指定するとタブ列の `Parent` を TCTitleBar にする。解除（nil）すると TCPageControl に戻す（5.6 `UpdateStripPlace`） |
| タブ列の位置 | `TitleBar` 指定中は `TabPosition` を使わず、TCPageControl はページだけを出す |
| 1つのタイトルバーに結び付けられる TCPageControl | 1つだけ。別の TCPageControl が同じ TCTitleBar を指定したら、前の結び付けを外す |
| 片方が破棄されたとき | `Notification` で結び付けを外す（例外を出さない） |
| タイトルバー内のタブ列の背景 | TCTitleBar の `Color` |
| タイトルバー内のタブの高さ | `TabHeight`（0 ならタイトルバーの高さ − 6）。タブはタイトルバーの下端にそろえる |

---

## 9. 設計時（Lazarus IDE）

| 項目 | 中身 |
|---|---|
| パレット | CX（`RegisterComponents('CX', [TCTitleBar, TCPageControl])`、`RegisterNoIcon([TCTabSheet])`） |
| 右クリックメニュー（`TCPageControlEditor`。TCPageControl と TCTabSheet の両方に登録） | 0「新しいページ」、1「ページの削除」、2「次のページ」、3「前のページ」（resourcestring `rsCPCNewPage`・`rsCPCDelPage`・`rsCPCNextPage`・`rsCPCPrevPage`） |
| 新しいページ | `Name := CreateUniqueComponentName('TCTabSheet')`（CTabSheet1、CTabSheet2…）、Owner は TCPageControl の Owner、`Caption := Name`、`Parent := TCPageControl`、`ActivePage := 新しいページ`、`PersistentAdded`、`Modified` |
| ページの削除 | 先に TCPageControl を選ぶ（消すページを選んだままだと、IDE が消えた部品を触るため）。`DeletePersistent(ページ)`。このあとエディタ自身に触れない（ページの上で右クリックしたときは、エディタもページと一緒に IDE が破棄するため。「変更あり」の印は IDE が付ける。LCL の TNotebookComponentEditor と同じ） |
| 次のページ・前のページ | `FindNextPage(ActivePage, 向き, False)` のページを `ActivePage` にし、選んで、`Modified` |
| ダブルクリック（`Edit`） | 何もしない（既定ではメニューの1番目「新しいページ」が動き、ページが増えてしまうため） |
| 設計時のタブ列 | ［＋］［∨］［×］は表示だけで、押しても動かない |
| 設計時の表示中でないページ | 設計画面に出さない（6章 ControlStyle） |
| TCTitleBar | 組み込まず、ボタンを表示するだけ。1つのフォームに2つ目は置けない（7.3） |

**設計時のタブのクリック**

- Lazarus のデザイナは、マウスの下の部品を探し、フォームが持ち主の部品までさかのぼる。TCTabStrip は TCPageControl が持ち主なので、マウスを受ける部品は、単体時は TCPageControl、`TitleBar` 指定時は TCTitleBar になる。
- デザイナはその部品に `CM_DESIGNHITTEST` を送り、0 より大きいときだけ、その部品の `MouseDown`・`MouseMove`・`MouseUp` を呼ぶ（ほかは部品の選択・移動）。
- そのため、TCPageControl と TCTitleBar の両方で `CM_DESIGNHITTEST` を受け、座標をタブ列の座標に直してタブ列の `DesignHitTest` に聞く（タブと［◀］［▶］の上なら 1、ほかは 0）。`MouseDown` も設計時はタブ列の `DesignMouseDown` に渡す（タブなら `DoTabClick`、［◀］［▶］ならスクロール）。
- 設計時に `UserSelectPage` でページを切り替えたら、`InternalSetPageIndex` のあと、フォームの `Designer.SelectOnlyThisComponent(ActivePage)` で表示したページを選び、フォーム全体（子も含む。`RedrawWindow(RDW_INVALIDATE or RDW_ERASE or RDW_ALLCHILDREN)`）を描き直させ（選択の印はデザイナがフォームを描くときに描き足すので、前のページの部品の印が残らないように）、`OwnerFormDesignerModified`（`ActivePage` を .lfm に保存するため）。
- 設計時は `OnChanging`・`OnChange` を出さない（LCL と同じ）。

**オブジェクトインスペクタで選んだページへの切り替え**

- IDE は、オブジェクトインスペクタで部品を選ぶと、親をたどって TTabSheet・TPage を表示中にするが、名前で調べているので TCTabSheet には効かない。
- そのため `Register` のときに `GlobalDesignHook.AddHandlerSetSelection` で選択の変化を受ける処理（`TCPageControlSelectionHandler.SetSelection`）を登録し、finalization で外す（IDE の終了時は `GlobalDesignHook` が先に破棄されていることがあるので、あるときだけ外す）。
- 受けたら、選択の1つ目（`TControl` のとき。設計時で、壊している途中でないもの）から親をたどり、TCTabSheet で親が TCPageControl なら、`ActivePage` をそのページにする（入れ子なら外側まですべて。すでに表示中なら何もしない）。たどる途中で壊している途中の部品があれば終わる。切り替えたらフォームを描き直させる。
- .lfm の保存内容は変えない（「変更あり」の印は付けない。IDE の TPageControl の切り替えと同じ）。

### 9.1 パレットのアイコン

| 部品 | 絵 |
|---|---|
| TCTitleBar | ウィンドウの上の部分。横長の帯の右端に「─ □ ×」の3つの小さな記号、左に短い線（キャプションの代わり）。帯の下に、ウィンドウの中身を表す薄い四角を少し見せる |
| TCPageControl | 上に3つのタブ（左から2つ目が表示中で、下の四角とつながっている）、3つ目のタブの右に小さな「＋」。下に、ページを表す四角 |

| 項目 | 中身 |
|---|---|
| 背景 | 透明 |
| 色 | 線は濃い灰色、表示中のタブ・帯は青（TCSideBar のアイコンと同じ色）、ページの四角は白に濃い灰色の枠 |
| 線の太さ | 24px で 1px、36px で 2px、48px で 2px。大きさごとに描く（縮小しない） |
| 形式 | PNG（32 ビット、透明あり） |

| 画面の倍率 | 大きさ | TCTitleBar | TCPageControl |
|---|---|---|---|
| 100% | 24 × 24 | `tctitlebar.png` | `tcpagecontrol.png` |
| 150% | 36 × 36 | `tctitlebar_150.png` | `tcpagecontrol_150.png` |
| 200% | 48 × 48 | `tctitlebar_200.png` | `tcpagecontrol_200.png` |

- リソース名は PNG のファイル名から拡張子を除いたもの（大文字・小文字は区別されない）。Lazarus のパレットは、クラス名と同じ名前、倍率 150%・200% では `_150`・`_200` を付けた名前を探す。
- `cpagecontrol_icon.lrs` は `lazres cpagecontrol_icon.lrs tctitlebar.png tctitlebar_150.png tctitlebar_200.png tcpagecontrol.png tcpagecontrol_150.png tcpagecontrol_200.png` で作る。
- `uCPageControl_reg` の initialization で `{$I cpagecontrol_icon.lrs}`。

---

## 10. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| フォームの下に帯・余白が残る | `WM_ERASEBKGND` の `FillFormRemainder`、`FrameChanged` の `WM_SIZE`（7.3、7.4） |
| タイトルバーで移動・最大化ができない | `WM_NCHITTEST` の判定、`SelfSubclassProc`・`ChildSubclassProc`（7.5） |
| 設計時にタブを押しても切り替わらない | 両方の `CM_DESIGNHITTEST`、タブ列の `DesignHitTest`（9章） |
| 設計時に前のページの選択の印が残る | `UserSelectPage` の設計時の描き直し、`SetSelection` の描き直し（9章） |
| ページを消したら Access violation | エディタの `DeleteActivePage` の順番（9章）、`RemovePage` のすぐの `LayoutTabs`（5.6） |
| 置いた部品がページでなくフォームに入る | `UpdateDesignerFlags`（5.6） |
| Ctrl+Tab が効かない | `KeyDownBefore`・`IsKeyTarget`（5.5.8） |
| 記号が点に見える | `CXSetSymbolFont`（5.8） |
| タイトルバーを外したら枠だけが残る | `UpdateStripPlace` の最後（5.6） |
| 2つ目の TCTitleBar が置けてしまう | `SetParent` の `HasOtherTitleBar`（7.3） |
