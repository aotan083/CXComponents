# TCPairSplitter 設計書

作者: aotan083
日付: 2026-11-08
版: 1.0

---

**動作環境**：Lazarus 5.0 以降（FPC 3.2.2）。Lazarus 4.8 以前は対象外。

## 1. 目的と方針

- TPairSplitter と同じ使い方の、2 つの側（Side1・Side2）と境目を 1 つにまとめた部品。
- 追加すること：①側ごとに隠す・出す（片方を隠すともう片方が全体に広がり、出すと元に戻る。両方は隠せない）、②境目の青い線（TCSplitter と同じ見た目。色は設計時に変えられる）、③設計時のドラッグ。
- 標準の TPairSplitter は、Windows では LCL の共通の実装（`WSPairSplitter`）で、側を `Align`、境目を内側の `TSplitter` で作っている。境目の色や側の隠し方を変えられないため、`TCustomPairSplitter` を継がず、自分で作る。
- 側の位置と大きさは、`Align` を使わず、TCPairSplitter が `SetBounds` で決める（側を隠したときの広がり・戻りと、境目の位置を、1 か所の計算で決めるため）。
- 境目は子の部品にせず、TCPairSplitter 自身が描いて、マウスを受ける（設計時のドラッグを、TCSideBar で動作確認済みの仕組み〔CM_DESIGNHITTEST〕で行うため）。

### 1.1 含めないもの

- 側を 3 つ以上にすること（側の中に別の TCPairSplitter を置く）。
- ドラッグ中に、別ウィンドウの線だけを動かす方式（`ResizeStyle`。TCSideBar にはある）。ドラッグ中は、側の大きさを動かしながら描き直す。
- 標準の `PairSplitter` ユニットの `TPairSplitterType` との互換（名前の衝突を避けるため、`TCPairSplitterType`・`cpsHorizontal`・`cpsVertical` にした）。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCSplitter.pas` | cx（実行時） | `TCSplitter`（既存）、`TCPairSplitterType`、`TCPairSplitterSide`、`TCPairSplitter`。このユニットの initialization で `RegisterClass(TCPairSplitterSide)`（.lfm から側を読み込むため） |
| `uCXReg.pas`（`source\design`） | cxdsgn（設計時） | パレット [CX] への登録（`RegisterComponents('CX', [..., TCPairSplitter, ...])`）と、`RegisterNoIcon([TCPairSplitterSide])` |
| `csplitter_icon.lrs`（`source\res`） | cxdsgn（設計時） | アイコン（`TCSplitter`・`TCSplitter_150`・`TCSplitter_200` と、`TCPairSplitter`・`TCPairSplitter_150`・`TCPairSplitter_200`）。`uCXReg` の initialization で `{$I csplitter_icon.lrs}` |

- `uCSplitter` の uses：`Classes, SysUtils, Types, Math, Controls, ExtCtrls, Graphics, LCLType, LCLIntf, LCLProc, LMessages`。
- パッケージは、cx と cxdsgn の 2 つのまま。`.pas` も増やさない（TCSplitter と同じユニットに入れる）。

## 3. 型と宣言

```pascal
type
  TCPairSplitterType = (cpsHorizontal, cpsVertical);

  TCPairSplitterSide = class(TCustomPanel)        { 1 つの側 }
  private
    function GetSplitter: TCPairSplitter;
  protected
    procedure SetParent(AParent: TWinControl); override;
    procedure SetVisible(Value: Boolean); override;
    procedure Paint; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    property Splitter: TCPairSplitter read GetSplitter;
  published
    property ChildSizing, Color, Constraints, Cursor, Enabled, ParentColor, ParentShowHint,
      PopupMenu, ShowHint, Visible, OnMouseDown, OnMouseEnter, OnMouseLeave, OnMouseMove, OnMouseUp,
      OnMouseWheel, OnMouseWheelDown, OnMouseWheelUp, OnResize;
  end;

  TCPairSplitter = class(TCustomControl)
  private
    FSides: array[0..1] of TCPairSplitterSide;
    FSplitterType: TCPairSplitterType;
    FPosition: Integer;               { 側 1 の大きさ。隠している間も覚えておく }
    FSplitterWidth: Integer;          { 境目の太さ（96dpi のときの値） }
    FHighlightColor: TColor;
    FSplitCursor: TCursor;
    FOnMoved: TNotifyEvent;
    FNoCreateSides: Boolean;
    FHot, FDragging: Boolean;
    FDragStartAxis, FDragStartPos: Integer;
    FLayouting: Boolean;
    FDesignerPressLeft: Boolean;
  public
    property Sides[Index: Integer]: TCPairSplitterSide; { 範囲外は EListError }
    property Side1, Side2: TCPairSplitterSide;
  published
    property Align, Anchors, BorderSpacing, Constraints, Enabled, ParentShowHint, PopupMenu, ShowHint, Visible;
    property Color default clBtnFace;
    property SplitterType: TCPairSplitterType default cpsHorizontal;
    property Position: Integer;                       { 既定値なし（いつも保存する） }
    property SplitterWidth: Integer default 5;
    property HighlightColor: TColor default clHighlight;
    property SplitCursor: TCursor default crDefault;
    property OnMoved: TNotifyEvent;
    { OnMouse*、OnResize、OnChangeBounds }
  end;
```

| 定数・既定値 | 値 | 中身 |
|---|---|---|
| `cLineWidth96`（TCSplitter と共通） | 2 | 青い線の太さ（96dpi） |
| 既定の大きさ | 90 × 90 | `GetControlClassDefaultSize`（TPairSplitter と同じ） |
| `Position` の既定 | 45 | TPairSplitter と同じ |
| `SplitterWidth` の既定 | 5 | TSplitter の既定の太さと同じ |

## 4. 側（TCPairSplitterSide）

| 項目 | 動き |
|---|---|
| `Create` | `TCustomPanel` の `csSetCaption` を外し、`csAcceptsControls` を付ける。`BevelOuter`・`BevelInner` は `bvNone`。`Caption` は空 |
| `SetParent` | 親が `TCPairSplitter` なら、`AddSide`（側の一覧に入れる）。古い親からは `RemoveSide` で外す。ただし、親が壊れる途中・デザイナが削除している途中（`wcfDesignerDeleting`）は、入れ直さない（TPairSplitterSide と同じ） |
| `Destroy` | `inherited` の前に、親の `TCPairSplitter.RemoveSide(Self)`（設計時に側を消したとき、新しい側を作り直すため） |
| `SetVisible(Value)` | ①隠す（`Value = False`）で、親があり、読み込み中でなく、**もう片方がすでに隠れている**（`OtherSideHidden`）なら、何もせず終わる（両方は隠せない）。②`inherited SetVisible`。③親の `ApplyLayout`（並べ直す）。`Show`・`Hide` は、`Visible` を変えるので、同じ決まりになる |
| `Paint` | 設計時だけ、点線の枠（`psDash`、`clGrayText`） |

## 5. 境目（TCPairSplitter）

### 5.1 側の管理

| 手続き | 処理 |
|---|---|
| `Create` | `csAcceptsControls` を外し、`csCaptureMouse`・`csClickEvents` を付ける。既定値を入れる。`Color := clBtnFace`。実行時（設計時でない）は `CreateSides` |
| `CreateWnd` | `CreateSides`、`inherited`、`ApplyLayout`（設計時は、窓ができたときに側を作る。TPairSplitter と同じ） |
| `Loaded` | `inherited`、`CreateSides`、`ApplyLayout` |
| `CreateSides` | 読み込み中・破棄中・`FNoCreateSides` のときは何もしない。側が足りなければ、`TCPairSplitterSide.Create(Owner)` を作って `Parent := Self`（保存・読み込みのため、側の Owner は境目の Owner） |
| `AddSide` | 空いている方（`FSides[0]`、なければ `FSides[1]`）に入れ、`ApplyLayout`。2 つとも埋まっていれば `EInvalidOperation` |
| `RemoveSide` | 一覧から外す。設計時（`csDesigning`）で、破棄中でも、デザイナの削除中でもなければ、`CreateSides`（新しい側を作る） |
| `OtherSideHidden(ASide)` | もう片方の側があり、その `Visible` が `False` か |
| `ChildClassAllowed` | `TCPairSplitterSide` の子クラスだけ |
| `Destroy` | `FNoCreateSides := True`、`inherited`（壊れる途中で側を作り直さない） |

### 5.2 並べ方（`ApplyLayout`）

`FLayouting`（再入を防ぐ）が真・側が 2 つそろっていない・読み込み中・破棄中のときは、何もしない。

| 状態 | 処理 |
|---|---|
| 両方見える（左右） | `P := ClampPos(FPosition)`、`B := BarSize`。側 1 を `SetBounds(0, 0, P, 高さ)`、側 2 を `SetBounds(P + B, 0, 幅 − P − B（0 以上）, 高さ)` |
| 両方見える（上下） | 側 1 を `SetBounds(0, 0, 幅, P)`、側 2 を `SetBounds(0, P + B, 幅, 高さ − P − B（0 以上）)` |
| 側 1 だけ見える | 側 1 を `SetBounds(0, 0, 幅, 高さ)` |
| 側 2 だけ見える | 側 2 を `SetBounds(0, 0, 幅, 高さ)` |

最後に `Invalidate`。隠れている側は触らない。`FPosition` は、隠している間も、並べ直しでも変えない（出したとき、元の大きさに戻るため）。

呼ぶところ：`Resize`（全体の大きさが変わったとき）、`Loaded`・`CreateWnd`、`AddSide`、側の `SetVisible`、`SetPosition`・`SetSplitterType`・`SetSplitterWidth`、`DoAutoAdjustLayout`、ドラッグ中。

### 5.3 範囲（`ClampPos`・`BarSize`・`BarRect`）

| 関数 | 処理 |
|---|---|
| `Total` | 分ける向きの全体の大きさ（左右なら `ClientWidth`、上下なら `ClientHeight`） |
| `BarSize` | `Max(1, Scale96ToFont(FSplitterWidth))` |
| `BarShown` | 側が 2 つあり、両方 `Visible` か |
| `ClampPos(v)` | 下限 `Min1` = `Max(1, 側 1 の Constraints の最小の幅（上下なら高さ）)`、側 2 の下限 `Min2` も同じ。上限 `MaxP` = `Total − BarSize − Min2`。`v` を `Min1` 以上にし、次に `MaxP` 以下にし、最後に 0 以上にする（上限が優先） |
| `BarRect` | `BarShown` でなければ空。そうでなければ、`P := ClampPos(FPosition)` から `BarSize` の幅（左右なら `Rect(P, 0, P + B, 高さ)`、上下なら `Rect(0, P, 幅, P + B)`） |

### 5.4 プロパティの書き込み

| プロパティ | 処理 |
|---|---|
| `Position` | 0 より小さければ 0。同じ値なら何もしない。`FPosition` を入れて `ApplyLayout`。読むと `FPosition`（大きすぎる値も、そのまま返す） |
| `SplitterType` | 同じ値なら何もしない。入れて `ApplyLayout` |
| `SplitterWidth` | 1 より小さければ 1。同じ値なら何もしない。入れて `ApplyLayout` |
| `HighlightColor` | 同じ値なら何もしない。入れて `Invalidate` |
| `SplitCursor` | 入れるだけ（次にマウスが境目の上で動いたとき効く） |

### 5.5 表示スケール（`DoAutoAdjustLayout`）

`inherited` のあと、`lapAutoAdjustWithoutHorizontalScrolling`・`lapAutoAdjustForDPI` なら、`FPosition` を、分ける向きに合わせて `Round(FPosition * AXProportion)`（左右）・`Round(FPosition * AYProportion)`（上下）にして `ApplyLayout`。`FSplitterWidth` は 96dpi の値のまま持ち、`BarSize` で拡大する。

### 5.6 描画（`Paint`）

1. `Color` で全体を塗る（側が覆っていない部分、つまり境目の領域が見える）。
2. `BarRect` が空なら終わる。
3. 実行時で、マウスが境目の上（`FHot`）またはドラッグ中（`FDragging`）なら、`CXSplitLineColor(HighlightColor)` で、境目の中央に `Max(1, Scale96ToFont(cLineWidth96))` の太さの線（左右なら縦線、上下なら横線）を塗る。
4. そうでなければ（ふだん、設計時）、境目の中央に 1px の `clBtnShadow` の線。

### 5.7 マウス

| 手続き | 処理 |
|---|---|
| `MouseDown` | 左ボタンで、境目（`BarRect`）の上なら、`FDragging := True`、`MouseCapture := True`（設計時は、デザイナが `MouseDown` を直接呼ぶのでキャプチャされないため）、押した位置（分ける向きの軸）と、そのときの `ClampPos(FPosition)` を覚える。`Invalidate` |
| `MouseMove` | ドラッグ中なら、`NewPos := ClampPos(開始時の位置 + (今の位置 − 押した位置))`。`FPosition` と違えば、`FPosition := NewPos`、`ApplyLayout`。ドラッグ中でなければ、境目の上かで `FHot` を変えて描き直し、カーソルを変える（上なら `SplitCursor`、`crDefault` のときは左右なら `crHSplit`・上下なら `crVSplit`。上でなければ `crDefault`） |
| `MouseUp` | 左ボタンで、ドラッグ中なら、ドラッグを終え（`MouseCapture := False`）、位置が開始時と違うかを調べ、`Invalidate`。設計時は、違えば `OwnerFormDesignerModified(Self)`（.lfm に `Position` を保存するため）、そして `FDesignerPressLeft := True`。実行時は、違えば `OnMoved` |
| `MouseLeave` | ドラッグ中でなければ、`FHot := False`、カーソルを `crDefault` に戻し、描き直す |
| `CaptureChanged` | ドラッグ中に、キャプチャが外れ、左ボタンがまだ押されている（Alt+Tab など）なら、ドラッグをやめる（位置は変えない） |

### 5.8 設計時のマウス（`CMDesignHitTest`）

TCSideBar と同じ決まり（TCSideBar_Design.md の CM_DESIGNHITTEST の説明）。デザイナは、マウスが押された・動いた・離されたたびにこのメッセージを送り、結果が 1 なら TCPairSplitter の `MouseDown`・`MouseMove`・`MouseUp` を呼び、0 ならデザイナ自身が処理する。

| 順 | 条件 | 結果 |
|---|---|---|
| 1 | いずれかのボタンが押されている | `FDesignerPressLeft := False`（新しく押された。デザイナが押下中の状態を作り直す） |
| 2 | ドラッグ中 | 1（どこでも、最後まで受け取る） |
| 3 | `FDesignerPressLeft` が真で、ボタンが押されていない | 1（ドラッグを終えた後の移動を、デザイナに渡さない。渡すと、デザイナが「部品から引きずっている」と判断し、範囲選択の枠が出る） |
| 4 | 境目（`BarRect`）の上 | 1 |
| 5 | それ以外 | 0（デザイナが、側や TCPairSplitter を選ぶ） |

## 6. 決めていること

| 項目 | 決めたこと |
|---|---|
| 作り方 | `TCustomPairSplitter` を継がない。側は `SetBounds`、境目は自分で描く |
| 側の型 | `TCustomPanel`（色・子の部品・`ChildSizing`・ポップアップが使える）。`TPairSplitterSide` は継がない |
| 側を隠す | `SetVisible` を上書きして、片方が隠れていれば断る。隠した側が、全体を譲る（並べ直しで決める） |
| 両方を隠す | できない。後から隠す側が断られる。全体は `TCPairSplitter.Visible` で隠す |
| 読み込み中 | 側の `Visible` の読み込みでは、断らない（.lfm の順番に左右されないため） |
| `Position` | 隠している間も、大きすぎるときも、値は変えない（表示のときだけ収める）。全体の大きさが変わると、側 1 は変わらず、側 2 が伸び縮みする |
| 側の数 | 2 つ。設計時に側を消すと、作り直す |
| 側の Owner | 境目の Owner（フォームに保存して読み込めるように） |
| 境目の線 | ふだんは 1px の灰色。実行時にマウスを乗せたとき・ドラッグ中は、`HighlightColor` の 2px（TCSplitter と同じ）。設計時は灰色のまま |
| ドラッグ | 動かしながら側の大きさを変える。`OnMoved` は、離したとき、位置が変わっていれば 1 回 |
| 設計時のドラッグ | `CMDesignHitTest` と、`OwnerFormDesignerModified`（TCSideBar と同じ） |
| 型の名前 | 標準の `PairSplitter` と一緒に使っても衝突しないよう、`TCPairSplitterType`・`cpsHorizontal`・`cpsVertical` |

## 7. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| 側が作られない（設計時） | `CreateWnd` の `CreateSides`。読み込み中・Owner が読み込み中ではないか（5.1） |
| 側を隠したのに、もう片方が広がらない | 側の `SetVisible` が親の `ApplyLayout` を呼んでいるか。`FLayouting` が真のままではないか |
| 側が隠れない | もう片方がすでに隠れていないか（両方は隠せない） |
| `Position` が思った値にならない | `ClampPos`（側の `Constraints` の最小・側 2 の下限）。`Position` を読むと、大きすぎる値もそのまま返す |
| 境目がドラッグできない | 片方の側が隠れていないか（境目が出ない）。設計時は `CMDesignHitTest` |
| 設計時にドラッグした位置が保存されない | `MouseUp` の `OwnerFormDesignerModified`。位置が開始時と違っているか |
| ドラッグの後、設計時に範囲選択の枠が出る | `FDesignerPressLeft`（5.8 の 3） |
| 線の色が変わらない | `HighlightColor`。設計時は線が灰色（実行時の色） |

## 8. この版の変更（1.0。新しく作る）

新しい部品 TCPairSplitter を作る。既存の部品の動きは、変えない。変えるファイルは、次のとおり。

| ファイル | 変更 |
|---|---|
| `source/uCSplitter.pas` | `TCPairSplitterType`・`TCPairSplitterSide`・`TCPairSplitter` と、initialization の `RegisterClass` を足す。uses に `LCLIntf`・`LCLProc` を足す。`TCSplitter` は変えない |
| `source/design/uCXReg.pas` | `TCPairSplitter` を登録し、`RegisterNoIcon([TCPairSplitterSide])`。uses に `PropEdits` を足す |
| `source/res/csplitter_icon.lrs` | アイコン 3 つ（`TCPairSplitter`・`_150`・`_200`）を足す |
| `docs/TCPairSplitter_Usage.md`・`TCPairSplitter_Design.md`、`docs/en` の同名 | 新規 |
| `README.md`・`README.ja.md` | 部品の表と説明に TCPairSplitter を足す（指示があってから） |
