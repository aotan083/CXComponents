# TCTabBar 設計書

作者: aotan083
日付: 2026-11-24
版: 1.0

---

**動作環境**：Lazarus 5.0 以降（FPC 3.2.2）。Lazarus 4.8 以前は対象外。

## 1. 目的

ページを持たない、タブ列だけの部品を作る。エディタ（TCsEditor・TCMonacoEditor）のタブのように、画面の切り替えをアプリが行う使い方のためのもの。今まで使っていたサードパーティのタブ部品を、CX の部品に置き換えて、サードパーティへの依存をなくす。

- タブ列の描画・スクロール・ドラッグでの並べ替え・［×］・［＋］・［∨］・タブ一覧・タイトルバーへの載せ替えは、TCPageControl のタブ列（`TCTabStrip`）をそのまま使う。作り直さない。
- そのため `TCTabBar` は `TCPageControl` を継ぎ、ページの場所を持たない高さ（＝タブ列の高さ）で使う。タブ 1 つ = `TCTabSheet` 1 枚（ページの中身は使わない）。
- エディタが必要とする機能（変更ありの印・タブごとの色・色の指定・表示中のタブの線・区切り線・ヒント・中ボタンで閉じる・タブ列の外へのドラッグの通知）は、`TCPageControl`・`TCTabSheet` に足す（すべて既定値では何も変わらない）。
- ［×］・［＋］は、自動では何もしない。アプリに知らせるだけにする（タブを足す・消すのはアプリが決める）。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCPageControl.pas` | cx（実行時） | `TCTabBar`（`TCPageControl` の後ろ）、`TCTabIndexEvent`・`TCTabDragOutEvent`・`TCStripColorKind`（型）。`TCPageControl`・`TCTabSheet`・`TCTabStrip` の追加（3章） |
| `design\uCPageControl_reg.pas` | cxdsgn（設計時） | パレット [CX] への登録（`RegisterComponents('CX', [TCTitleBar, TCPageControl, TCTabBar])`）。アイコンは `source\res\cpagecontrol_icon.lrs`（`TCTabBar`・`TCTabBar_150`・`TCTabBar_200`。24・36・48px） |

- ユニットは増やさない。サードパーティのタブ部品のパッケージへの依存は、cx から外す。

## 3. 継いだクラスへの追加

### 3.1 TCTabSheet

| 名前 | 型 | 既定値 | 中身 |
|---|---|---|---|
| `FModified` / `Modified` | `Boolean` | `False` | 変更あり。変わると `PageControl.PageChanged`（描き直し） |
| `FTabColorActive` / `TabColorActive` | `TColor` | `clDefault` | このタブだけの、表示中のときの背景色 |
| `FTabColorOver` / `TabColorOver` | `TColor` | `clDefault` | このタブだけの、マウスを乗せたときの背景色 |

public（実行時だけ）。`Hint` は、`TControl` のものを使う。

### 3.2 TCPageControl

| 名前 | 中身 |
|---|---|
| `FStripColors[TCStripColorKind]` | 色の指定。`sckActive`・`sckActiveText`・`sckText`・`sckModifiedText`・`sckHot`・`sckButton` は `clDefault`、`sckSeparator` は `clNone`。published の `ActiveTabColor`・`ActiveTextColor`・`TabTextColor`・`ModifiedTextColor`・`HotTabColor`・`ButtonColor`・`SeparatorColor` が、`index 0..6` で読み書きする（`GetStripColor`・`SetStripColor`）。変わると `FStrip.Invalidate` |
| `ActiveMarkSize`・`ActiveMarkColor`・`ActiveMarkAtBottom` | 表示中のタブの線。0・`clHighlight`・`False`。変わると `FStrip.Invalidate` |
| `DoTabDragOut(APage, AScreenPos, ATarget)`・`DoStripMouseUp(AButton, AShift, X, Y)`・`DoStripLayouted` | protected virtual。何もしない。`TCTabBar` が上書きする（4章） |

- `PageChanged` の最後で `DoStripLayouted` を呼ぶ。

### 3.3 TCTabStrip

| 手続き | 変更 |
|---|---|
| コンストラクタ | `ParentShowHint := False`、`ShowHint := True`（タブのヒントを出すため。`Hint` が空なら何も出ない） |
| `PaintTab` | 背景：表示中は `clWindow` →（`ActiveTabColor`）→（`TCTabSheet.TabColorActive`）。マウスを乗せた・押したときは、混ぜた色 →（`TabColorOver` → `HotTabColor`）。表示中のタブの線（`ActiveMarkSize > 0` のとき、背景の後に `ActiveMarkColor` で塗る）。文字：既存の決め方のあと、`ActiveTextColor`／`TabTextColor`、変更ありは `ModifiedTextColor`（設計時の隠れたタブは除く）。［×］：`ButtonColor`（なければタブの文字の色）。`Modified` で、マウスが［×］の上にないときは、半径 `CPC_DOT_R`（4）の塗りつぶした円 |
| `PaintButton` | 記号の色に `ButtonColor` を使う |
| `Paint` | `SeparatorColor <> clNone` のとき、各タブの右の隙間に縦線（上下 6px を除く）。どちらかが表示中のタブなら出さない |
| `MouseMove` | マウスを乗せたタブが変わったとき、`Hint := タブの Hint`（タブでなければ ''） |
| `MouseUp` | 中ボタン：`nboShowCloseButtons` があり、タブの上なら `DoCloseButtonClick`（`DoStripMouseUp` は呼ばない）。左ボタン：今までの処理のあとに `DoStripMouseUp`（ドラッグの終わりのあとも） |
| `FinishDrag` | タブ列の外で離したときは、並べ替えをせず、`DoTabDragOut(ページ, ClientToScreen(P), FindDragTarget(画面の位置, True))` |

## 4. TCTabBar

```pascal
TCTabBar = class(TCPageControl)
private
  FOnTabClick: TCTabIndexEvent;
  FOnTabPlusClick: TNotifyEvent;
  FOnTabMouseUp: TMouseEvent;
  FOnTabDragOut: TCTabDragOutEvent;
  function GetTabCount: Integer;                 // PageCount
  function GetTab(AIndex: Integer): TCTabSheet;  // Pages[AIndex]
  procedure FitHeight;
protected
  procedure DoTabClick(APage: TCTabSheet); override;
  procedure DoAddButtonClick; override;
  procedure DoMenuNewClick; override;
  procedure DoTabDragOut(APage: TCTabSheet; const AScreenPos: TPoint; ATarget: TControl); override;
  procedure DoStripMouseUp(AButton: TMouseButton; AShift: TShiftState; X, Y: Integer); override;
  procedure DoStripLayouted; override;
  procedure Loaded; override;
public
  constructor Create(TheOwner: TComponent); override;
  function AddTab(const ACaption: string; AData: PtrInt = 0; AModified: Boolean = False): TCTabSheet;
  procedure ClearTabs;
  property TabCount: Integer read GetTabCount;
  property Tabs[AIndex: Integer]: TCTabSheet read GetTab;
published
  property Align default alTop;
  property Options default [nboShowCloseButtons, nboShowAddTabButton];
  property ShowTabListButton default False;
  property TabStop default False;
  property OnTabClick: TCTabIndexEvent read FOnTabClick write FOnTabClick;
  property OnTabPlusClick: TNotifyEvent read FOnTabPlusClick write FOnTabPlusClick;
  property OnTabMouseUp: TMouseEvent read FOnTabMouseUp write FOnTabMouseUp;
  property OnTabDragOut: TCTabDragOutEvent read FOnTabDragOut write FOnTabDragOut;
end;
```

| 手続き | 処理 |
|---|---|
| `Create` | `inherited`。`Options := [nboShowCloseButtons, nboShowAddTabButton]`、`ShowTabListButton := False`、`TabStop := False`、`Align := alTop` |
| `AddTab` | `AddTabSheet`（末尾に足す。表示中のタブは変えない）で作り、`Caption`・`Tag := AData`・`Modified` を入れて返す |
| `ClearTabs` | `Clear` |
| `DoTabClick(APage)` | `inherited`（表示中にする。`OnChanging`・`OnChange`）のあと、`OnTabClick(Self, IndexOf(APage))` |
| `DoAddButtonClick`・`DoMenuNewClick` | `OnTabPlusClick(Self)` を呼ぶだけ（空のページは作らない。`OnNewPage` も出さない） |
| `DoTabDragOut` | `OnTabDragOut(Self, IndexOf(APage), AScreenPos, ATarget)` |
| `DoStripMouseUp` | `OnTabMouseUp(Self, AButton, AShift, X, Y)` |
| `DoStripLayouted`・`Loaded` | `FitHeight`：`TitleBar` がなく、タブ列の高さ（`TabStrip.Height`）が 0 より大きく、自分の `Height` と違えば、`Height := TabStrip.Height` |

- ［×］・右クリックの「タブを閉じる」・タブ一覧の［×］は、TCPageControl の `ClosePageByUser`（`OnPageClose` → `CanClose` なら `Free`）のまま。アプリは `CanClose := False` にして、あとで自分で閉じる。
- ページ（`TCTabSheet`）は、表示中の 1 枚だけが見える状態になるが、自分の高さがタブ列の高さと同じなので、ページの場所は 0 になる。

## 5. 確認すること（見どころ）

| 症状 | 見る場所 |
|---|---|
| 高さがタブ列より大きい・小さい | `FitHeight`・`DoStripLayouted`。`TitleBar` を指定していないか |
| ［×］を押してもタブが消えない | `OnPageClose` で `CanClose := False` にしていないか。アプリが閉じているか |
| ［＋］でタブが増えない | `OnTabPlusClick` で、アプリが `AddTab` しているか |
| 色が変わらない | `clDefault` のままではないか。`ActiveTabColor` と `TabColorActive` の強さ（3.3） |
| 「●」が出ない | `Modified` と `nboShowCloseButtons`（［×］を出していないと出ない） |
| 線が出ない | `ActiveMarkSize > 0` か |
| ヒントが出ない | `TCTabSheet.Hint` が空でないか |
| タブを外へ出しても `OnTabDragOut` が来ない | Esc で取り消していないか。タブ列の外で離したか。`FinishDrag` |
| タブ列のドラッグの途中でタブを消して落ちる | `OnTabDragOut`・`OnPageClose` の中で消さず、`QueueAsyncCall` で後から消す |

## 6. この版の変更（1.0）

### 6.1 今と変更後（TCsEditor・TCMonacoEditor のタブ列）

| No | 項目 | 今の動作・問題点 | 変更後（1.0） | 変える理由 | リスク |
|---|---|---|---|---|---|
| 1 | タブ列の部品 | サードパーティのタブ部品。直せない。タイトルバーに載せられない | `TCTabBar`（CX の部品。TCPageControl のタブ列を使う） | サードパーティを減らす。CX の部品と、見た目・操作をそろえる | 見た目・細かい動きが、それまでのタブ部品と少し違う（4.6 の表） |
| 2 | 公開している型 | `TCMTabBinder.Tabs`・`Attach(Ed, ATabs)` の型が、サードパーティのタブ部品の型 | `TCTabBar` | 1 のため | これを使っているアプリは、型を直す必要がある |
| 3 | タブを並べ替えたあとの処理 | `OnTabDropQuery`（落とす前に、文書の並びを入れ替える）と `OnTabMove` | `OnPageMoved`（タブ列を並べ替えたあとに、文書の並びを合わせる） | TCTabBar は並べ替えのあとに知らせる | 並べ替え直後の、タブと文書の対応を、実機で確かめる |
| 4 | タブの移動 | LCL のドラッグの `OnEndDrag`（`Target`、左ボタンの確認） | `OnTabDragOut`（離した画面の位置・その位置の部品。Esc で取り消したときは来ない） | 自前のドラッグ（マウスのキャプチャ）に変わるため | 別のエディタへの移動・アプリの外へ出す動作は、実機で確かめる |
| 5 | 変更ありの印 | 題名の後ろの「 *」 | 同じ（`Modified` の「●」は、使わない。使いたいアプリは `Modified` を使える） | 見た目を変えない | なし |
| 6 | 閉じる | ［×］・中ボタンで `OnTabClose` | ［×］・中ボタン・右クリックの「タブを閉じる」・タブ一覧の［×］で `OnPageClose` | 同じ処理にまとまる | 右クリックのメニュー・タブ一覧が使える（TCPageControl の機能） |
| 7 | サードパーティのタブ部品のパッケージ | cx が必要とする | 不要（cx.lpk から外す） | サードパーティを減らす | なし |

### 6.2 直す所

| No | ファイル | 変更 |
|---|---|---|
| 1 | `uCPageControl.pas` | 3 章の追加。`TCTabBar`。中ボタンで閉じる |
| 2 | `CMonacoTabs.pas` | サードパーティのタブ部品の型を `TCTabBar` に。ハンドラを `PageClose`・`PageMoved`・`TabDragOut` に。`MainButtonDown` を消す |
| 3 | `uCmonacos.pas`・`uCsEditor.pas` | サードパーティのタブ部品の型を `TCTabBar` に。色・形・アイコンの設定を新しいプロパティに。タブの文字は `Screen.SystemFont`（`ParentFont := False` のとき、そのときの `Font` が残るため） |
| 4 | `packages\cx.lpk` | 必要パッケージから、サードパーティのタブ部品のパッケージを外す |
| 5 | `source\design\uCPageControl_reg.pas` | `TCTabBar` を登録 |

- 確認したこと（Lazarus 5.0 RC1、Windows 11）：TCTabBar だけの確認用プログラムで、色・線・「●」・区切り線・スクロール・［＋］・［×］・中ボタン・並べ替え・タブ列の外へのドラッグ。TCsEditor のデモで、［＋］・並べ替え・［×］。TCMonacoEditor のデモで、［＋］・並べ替え・［×］。
- 確認していないこと：別の TCsEditor へタブを移す動作・タブをアプリの外へ出す動作（実機）、ヒントの表示、TCMonacoEditor で並べ替えたあとの文書の対応。