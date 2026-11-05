# TCExpandPanel 設計書

作者: aotan083
日付: 2026-11-05
版: 1.0

---

## 1. 目的

VS Code のエクスプローラーのような「タイトルバー付きの伸縮するパネル」を、2つの部品にする。

- **TCRollout**：伸縮する 1 つのパネル。タイトルバー（矢印・Caption・右側のボタン）と中身（部品を置ける領域）を持つ。単体でも使える。
- **TCExpandPanel**：TCRollout を複数並べる入れ物。`AddPanel` で追加する。開いたパネルが余った場所を分け合う。

```pascal
CExpandPanel1.AddPanel(CRollout1);
CExpandPanel1.AddPanel(CRollout2);
```

- タイトルバーは TCRollout が自分で描く。右側のボタンは `Buttons` に登録する（部品を貼らない）。
- ボタンに `DropDownMenu`（TPopupMenu）を指定すると、押したときにそのメニューを出す。
- 伸縮の向き（Top / Bottom / Left / Right）は、TCRollout の `HeaderPosition` で決める。
- 開閉は、なめらかに大きさが変わる（アニメーション。切り替えられる）。
- ボタンは、いつも出すか、タイトルバーにマウスが乗ったときだけ出すかを選べる。
- 入れ物の中身が溢れたときは、スクロールバーが出てスクロールできる（切り替えられる）。
- 色はシステム色だけを使う（ダーク／ライトはアプリ側の MetaDarkStyle などに任せる）。

### 1.1 この版に含めないもの

- 入れ物の中で、パネルの境界をドラッグして大きさを変えること（入れ物のスプリッター）。大きさは `ExpandedSize`・`Fill` で決める。単体の TCRollout を `Align = alTop` などで置く場合は、標準の TSplitter を使える。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCExpandPanel.pas` | cx（実行時） | 型、`TCRolloutButton`、`TCRolloutButtons`、`TCRollout`、`TCExpandPanel` |
| `uCExpandPanelReg.pas`（`source\design`） | cxdsgn（設計時） | パレット [CX] への登録、コンポーネントエディタ `TCExpandPanelEditor` |
| `cexpandpanel_icon.lrs` | cxdsgn（設計時） | アイコン（`TCExpandPanel`・`TCRollout`、それぞれ `_150`・`_200`）。`uCExpandPanelReg` の initialization で `{$I cexpandpanel_icon.lrs}` |

- `uCExpandPanel` の uses：`Classes, SysUtils, Types, LCLType, LCLIntf, LMessages, Controls, Graphics, GraphType, Forms, Menus, ImgList, ExtCtrls, uCXLang`（`ExtCtrls` はアニメーションの `TTimer`）
- `uCExpandPanel` の initialization：`RegisterClass(TCRollout)`（.lfm から読み込めるようにする）。
- `uCExpandPanelReg` の uses：`Classes, SysUtils, LResources, ComponentEditors, PropEdits, uCExpandPanel`
- パッケージの更新：`cx.lpk` に `uCExpandPanel`、`cxdsgn.lpk` に `uCExpandPanelReg` を足す（`cx.pas`・`cxdsgn.pas` の uses と登録も同じ）。
- 文字は `uCXLang` の `CXT` で日本語・英語を出す。足す文字は 1 つ：`sEpErrChild`（TCExpandPanel に TCRollout 以外を入れたとき）。Ja `TCExpandPanel には TCRollout だけを入れられます` / En `Only a TCRollout can be placed on a TCExpandPanel`（`uCXLang` の「H. TCPageControl・TCSideBar・TCTitleBar」の並びに足す）。

## 3. 型と定数

```pascal
TCRolloutHeaderPosition = (hpTop, hpBottom, hpLeft, hpRight);
TCExpandOrientation = (eoVertical, eoHorizontal);
TCRolloutButtonsShow = (bsAlways, bsHover);   // ボタンをいつも出す／タイトルバーにマウスが乗ったときだけ出す
TCRolloutButtonEvent = procedure(Sender: TObject; Index: Integer) of object;
TCRolloutExpandingEvent = procedure(Sender: TObject; var Allow: Boolean) of object;
```

100% のときの大きさ（implementation。描くたびに `Scale96ToFont` で拡大する）：

| 名前 | 値 | 中身 |
|---|---|---|
| `cButtonInset96` | 2 | ボタンの枠と強調表示の間の余白 |
| `cButtonGap96` | 2 | ボタン同士の間 |
| `cEdgePad96` | 4 | タイトルバーの端の余白 |
| `cTextPad96` | 6 | 矢印・ボタンと文字の間 |
| `cArrowSize96` | 8 | 矢印の大きさ |
| `cButtonRadius96` | 4 | 強調表示の角の丸み |
| `cFillMin96` | 60 | `Fill` のパネルの、中身の最小の大きさ（これより小さくならず、足りなければスクロール） |
| `cScrollLine96` | 24 | スクロールの 1 行（矢印を押したときの量。マウスホイール 1 目盛りは 3 行） |

アニメーションの間隔は、定数 `cAnimInterval = 15`（ミリ秒）。

## 4. TCRolloutButton と TCRolloutButtons

### 4.1 TCRolloutButton（`TCollectionItem`）

| プロパティ | 型 | 既定値 | 中身 |
|---|---|---|---|
| `ImageIndex` | `TImageIndex` | -1 | `Rollout.Images` の中の番号。-1 なら何も描かない（枠は残り、押せる） |
| `Hint` | `string` | '' | ヒントの文字 |
| `DropDownMenu` | `TPopupMenu` | nil | 押したときに出すメニュー |
| `Enabled` | `Boolean` | True | False でアイコンが灰色になり、押せない |
| `Visible` | `Boolean` | True | False で出さない（下のボタンが詰まる） |

- `GetDisplayName`：`Hint` が空でなければ `Hint`、空なら `Button <Index>`（コレクションエディタの表示）。
- どのプロパティも、変わったら `Changed(False)`。`SetDropDownMenu` は、新しいものがあれば `Rollout.FreeNotification` を呼ぶ（`Rollout` は `Collection.Owner`）。

### 4.2 TCRolloutButtons（`TOwnedCollection`）

- `Create(AOwner: TPersistent)` は `inherited Create(AOwner, TCRolloutButton)`。`Owner` は TCRollout。
- `Items[Index]: TCRolloutButton` を公開する。
- `Update(Item)` で `Rollout.ButtonsChanged`（再描画。見出しの文字の範囲が変わる）。

## 5. TCRollout

### 5.1 宣言

```pascal
TCRollout = class(TCustomControl)
private
  FExpanded: Boolean;
  FHeaderPosition: TCRolloutHeaderPosition;
  FHeaderSize: Integer;
  FExpandedSize: Integer;
  FFill: Boolean;
  FShowArrow: Boolean;
  FImages: TCustomImageList;
  FImageChangeLink: TChangeLink;
  FImagesWidth: Integer;
  FButtons: TCRolloutButtons;
  FButtonsShow: TCRolloutButtonsShow;
  FAnimated: Boolean;
  FAnimationTime: Integer;
  FOpenT: Double;          // 開き具合（0 = 閉じている、1 = 開いている）。アニメーション中は途中の値
  FAnimTimer: TTimer;      // アニメーション用（必要になったときに作る）
  FAnimStart: QWord;       // アニメーション開始の時刻（GetTickCount64）
  FAnimFrom: Double;       // アニメーション開始時の FOpenT
  FSizing, FManaged: Boolean;
  FHotHeader: Boolean;
  FHotButton, FDownButton: Integer;
  FDownHeader, FMenuOpen: Boolean;
  ...
public
  constructor Create(TheOwner: TComponent); override;
  destructor Destroy; override;
  property ExpandPanel: TCExpandPanel read GetExpandPanel;
published
  property Caption;
  property Expanded: Boolean read FExpanded write SetExpanded default True;
  property HeaderPosition: TCRolloutHeaderPosition read FHeaderPosition write SetHeaderPosition default hpTop;
  property HeaderSize: Integer read FHeaderSize write SetHeaderSize default 24;
  property ExpandedSize: Integer read FExpandedSize write SetExpandedSize default 150;
  property Fill: Boolean read FFill write SetFill default False;
  property ShowArrow: Boolean read FShowArrow write SetShowArrow default True;
  property Images: TCustomImageList read FImages write SetImages;
  property ImagesWidth: Integer read FImagesWidth write SetImagesWidth default 0;
  property Buttons: TCRolloutButtons read FButtons write SetButtons;
  property ButtonsShow: TCRolloutButtonsShow read FButtonsShow write SetButtonsShow default bsAlways;
  property Animated: Boolean read FAnimated write FAnimated default True;
  property AnimationTime: Integer read FAnimationTime write SetAnimationTime default 150;
  property OnExpanding: TCRolloutExpandingEvent ...;
  property OnExpand: TNotifyEvent ...;
  property OnCollapse: TNotifyEvent ...;
  property OnButtonClick: TCRolloutButtonEvent ...;
  property Align, Anchors, BorderSpacing, Color, Constraints, Enabled, Font, ParentFont,
           ParentColor, ParentShowHint, PopupMenu, ShowHint, Visible;
end;
```

- `Fill`：入れ物の中で、開いているとき、余った場所を埋める（6.3）。単体のときは何もしない。
- `ExpandedSize`：開いているときの、伸縮する向きの大きさ（`hpTop`・`hpBottom` なら高さ、`hpLeft`・`hpRight` なら幅）。`HeaderSize` 未満にはならない。
- `HeaderSize`：タイトルバーの厚み（`hpTop`・`hpBottom` なら高さ、`hpLeft`・`hpRight` なら幅）。既定値は 24。
- `ImagesWidth`：アイコンを描く幅（100% のときの px）。0 なら `Images.Width`。
- `ButtonsShow`：`bsAlways` はボタンをいつも出す。`bsHover` はタイトルバーにマウスが乗っているときだけ出す（設計時はいつも出す。`DropDownMenu` を開いている間も出したままにする）。ボタンの場所は、出さないときも空けておく（文字が動かないように）。
- `Animated`：`True` で、開閉のとき大きさが少しずつ変わる。設計時・.lfm の読み込み中は、いつもすぐに変わる。
- `AnimationTime`：開閉にかける時間（ミリ秒。既定値 150）。0 以下ならアニメーションしない。

### 5.2 Create・Destroy

Create：

1. `FExpanded := True`、`FHeaderPosition := hpTop`、`FHeaderSize := 24`、`FExpandedSize := 150`、`FFill := False`、`FShowArrow := True`、`FImagesWidth := 0`。
2. `FImageChangeLink` を作って `OnChange := ImageListChange`。`FButtons := TCRolloutButtons.Create(Self)`。
3. `ControlStyle := ControlStyle + [csAcceptsControls, csCaptureMouse, csClickEvents]`（中身に部品を置ける）。
4. `Color := clBtnFace`、`ParentColor := False`、`Caption := ''`、`Width := 200`、`Height := 150`、`Align := alNone`。
5. `FButtonsShow := bsAlways`、`FAnimated := True`、`FAnimationTime := 150`、`FOpenT := 1`、`FAnimTimer := nil`。
6. 見出しの状態（`FHotHeader := False`・`FHotButton := -1`・`FDownButton := -1`・`FDownHeader := False`・`FMenuOpen := False`）を初期化する。

Destroy：`FAnimTimer` を止めて解放し、`FButtons` と `FImageChangeLink` を解放する（`inherited` の後）。

### 5.3 実効の向きと大きさ

| 手続き | 処理 |
|---|---|
| `EffectivePosition` | 入れ物の中（`ExpandPanel <> nil`）なら、入れ物が縦（`eoVertical`）のとき `HeaderPosition` が `hpLeft`・`hpRight` なら `hpTop`、横のとき `hpTop`・`hpBottom` なら `hpLeft`。それ以外は `HeaderPosition`。`HeaderPosition` の値は変えない |
| `IsVerticalHeader` | `EffectivePosition` が `hpLeft` か `hpRight` |
| `HeaderThickness` | `FHeaderSize` そのまま（表示スケールによる拡大は `DoAutoAdjustLayout` で値を直接拡大する） |
| `AxisSize` | `IsVerticalHeader` なら `Width`、ちがえば `Height` |
| `LayoutSize(Full)` | 開いたときの大きさ `Full` に対する、今の大きさ。`HeaderThickness + Round((Full - HeaderThickness) * FOpenT)`（`Full` が `HeaderThickness` 以下なら `HeaderThickness`） |
| `CurrentSize` | `LayoutSize(FExpandedSize)` |
| `OpenTarget` | `Expanded` なら 1、閉じていれば 0 |
| `HeaderRect` | `hpTop`：`(0, 0, ClientWidth, HeaderThickness)`、`hpBottom`：`(0, Height - HeaderThickness, Width, Height)`、`hpLeft`：`(0, 0, HeaderThickness, Height)`、`hpRight`：`(Width - HeaderThickness, 0, Width, Height)`（`Width`・`Height` は自分の大きさ） |

### 5.4 開閉

`Expanded` の書き込み（`SetExpanded(v)`）：

1. 同じなら終わる。`csLoading` 中は `FExpanded := v`、`FOpenT := OpenTarget` だけして終わる（大きさは `Loaded` で決める）。
2. 実行時（設計時でない）で `OnExpanding` があれば、`Allow := True` で呼ぶ。`Allow = False` なら終わる。
3. `FExpanded := v`。`StartOpen`（下）で `FOpenT` を動かす。入れ物の中なら `ExpandPanel.RolloutToggled(Self)`（`Multiple = False` の処理。6.4）。
4. `Invalidate`。実行時なら、開いたとき `OnExpand`、閉じたとき `OnCollapse`（アニメーションの始まりで出す。終わりを待たない）。
5. 設計時のヘッダークリックによる変更は、`OwnerFormDesignerModified(Self)` を呼ぶ（7.4）。

アニメーション：

| 手続き | 処理 |
|---|---|
| `StartOpen` | 目標 `OpenTarget`。`FOpenT` が目標と同じなら何もしない。`Animated = False`、`AnimationTime <= 0`、設計時、`csLoading`・`csDestroying` 中、`HandleAllocated` でない、`Visible` でないのどれかなら、`FOpenT := 目標` にして `OpenChanged`、終わる。ほかは `FAnimFrom := FOpenT`、`FAnimStart := GetTickCount64`、`FAnimTimer`（なければ `Interval := cAnimInterval`・`OnTimer := AnimTimerTick` で作る）を `Enabled := True` |
| `AnimTimerTick` | `Elapsed := GetTickCount64 - FAnimStart`、`Prog := Min(1, Elapsed / FAnimationTime)`。なめらかにするため `E := Prog * Prog * (3 - 2 * Prog)`。`FOpenT := FAnimFrom + (目標 - FAnimFrom) * E`。`Prog >= 1` なら `FOpenT := 目標` にして `FAnimTimer.Enabled := False`。毎回 `OpenChanged` |
| `OpenChanged` | 入れ物の中なら `ExpandPanel.LayoutChanged`、単体なら `ApplyOwnSize`。`Invalidate` |
| 途中で逆に切り替えたとき | `StartOpen` が今の `FOpenT` から `FAnimFrom` を取り直すので、その場から動きを変える |

- 開閉のとき、`FOpenT` が動いている間（`FAnimTimer` が動いている間）は、`SetBounds` が `ExpandedSize` を書き換えない（下の `SetBounds`）。

`ApplyOwnSize`（単体のとき）：`FSizing := True` にして、伸縮する向きの大きさを `CurrentSize` にする（`SetBounds` で。`hpBottom`・`hpRight` は、反対側の辺が動かないように `Top`・`Left` もずらす。`Align` が `alTop` などのときは Align に任せる）。`FSizing := False`。

大きさの管理：

| 手続き | 処理 |
|---|---|
| `SetBounds` | `inherited` の前に、`FSizing`・`FManaged`（入れ物が配置している）・`csLoading`・アニメーション中（`FAnimTimer` が動いている）のどれでもなければ、次の処理をする。開いていれば `FExpandedSize := Max(新しい軸の大きさ, HeaderThickness)`（利用者が大きさを変えたら覚える）。閉じていれば、伸縮する向きの大きさを `HeaderThickness` に直す |
| `SetBoundsManaged(L, T, W, H)` | 入れ物が呼ぶ。`FManaged := True` で `SetBounds`、`FManaged := False`。`ExpandedSize` を変えない |
| `SetButtonsShow` | 変わったら入れて `Invalidate`（出さないときも場所は空けたままなので、配置は変わらない） |
| `SetAnimationTime` | 負なら 0 にして入れる |
| `Loaded` | `inherited` のあと、`FOpenT := OpenTarget`。入れ物の外なら `ApplyOwnSize`。入れ物の中なら `ExpandPanel.LayoutChanged` |
| `SetHeaderPosition` | 変わったら入れ、入れ物の外なら `ApplyOwnSize`。`LayoutChanged`（入れ物があれば入れ物の配置、なければ `Invalidate`・`Realign`） |
| `SetHeaderSize` | 負なら 0。変わったら入れ、`ApplyOwnSize` か入れ物の `LayoutChanged` |
| `SetExpandedSize` | `HeaderSize` 未満なら `HeaderSize`。変わったら入れ、開いていれば `ApplyOwnSize` か入れ物の `LayoutChanged` |
| `SetFill` | 変わったら入れ、入れ物の `LayoutChanged` |
| `SetShowArrow` | 変わったら入れて `Invalidate` |
| `SetImages` | 前のものから `UnRegisterChanges`・`RemoveFreeNotification`。新しいものに `FreeNotification`・`RegisterChanges`。`Invalidate` |
| `SetImagesWidth` | 負なら 0。変わったら入れて `Invalidate` |
| `SetButtons` | `FButtons.Assign(v)` |
| `ImageListChange`・`ButtonsChanged` | `Invalidate` |
| `Notification` | `opRemove` で `FImages` なら nil にして `Invalidate`。`opRemove` で、ボタンの `DropDownMenu` に同じものがあれば nil にする |
| `TextChanged` | `inherited` のあと `Invalidate` |
| `DoAutoAdjustLayout` | `inherited` のあと、`lapAutoAdjustWithoutHorizontalScrolling`・`lapAutoAdjustForDPI` なら、`FHeaderSize` を `Round(FHeaderSize * 軸の倍率)`（`hpTop`・`hpBottom` は `AYProportion`、`hpLeft`・`hpRight` は `AXProportion`）。`FExpandedSize` も同じ倍率 |

### 5.5 中身の領域

`AdjustClientRect` を上書きする。`inherited` のあと、タイトルバーの分を除く。

| 実効の向き | 処理 |
|---|---|
| `hpTop` | `Top += HeaderThickness` |
| `hpBottom` | `Bottom -= HeaderThickness` |
| `hpLeft` | `Left += HeaderThickness` |
| `hpRight` | `Right -= HeaderThickness` |

右が左より、下が上より小さくならないようにする。閉じているときは、中身の領域は 0 になり、置いた部品は切れて見えない。

### 5.6 ボタンの位置

| 手続き | 処理 |
|---|---|
| `ButtonSize` | `HeaderThickness - 2 * Scale96ToFont(cButtonInset96)`（0 未満は 0）。正方形 |
| `ButtonRect(Index)` | `Buttons.Items[Index].Visible` でなければ空。見出しが横（`hpTop`・`hpBottom`）：見出しの右端から `Scale96ToFont(cEdgePad96)` 内側へ、表示するボタンを右から順に `ButtonSize` の正方形で並べる（間は `cButtonGap96`）。番号の小さいほうが左。縦の中央にそろえる。見出しが縦（`hpLeft`・`hpRight`）：矢印の下（矢印がなければ上端から `cEdgePad96`）から、表示するボタンを上から順に並べる。横の中央にそろえる |
| `ButtonsShown` | ボタンを描く・押せるか。設計時、`bsAlways`、`FHotHeader`、`FMenuOpen`、`FDownButton >= 0` のどれかなら `True`。それ以外（`bsHover` でマウスが乗っていない）は `False` |
| `ButtonAt(X, Y)` | `ButtonsShown` でなければ -1。ほかは `ButtonRect` の中にある最初のボタンの番号（なければ -1） |
| `TextRect` | 見出しの中で、矢印とボタンを除いた文字の範囲。見出しが横：左は矢印の右（`cTextPad96`）、右は一番左のボタンの左 - `cTextPad96`。見出しが縦：上は一番下のボタンの下 + `cTextPad96`、下は端 - `cEdgePad96`（`hpLeft` の文字は下から上へ、`hpRight` は上から下へ読む） |
| `ArrowRect` | `ShowArrow = False` なら空。見出しが横：左端から `cEdgePad96`、縦の中央に `cArrowSize96` の正方形。見出しが縦：上端から `cEdgePad96`、横の中央に正方形 |

## 6. TCExpandPanel

### 6.1 宣言

```pascal
TCExpandPanel = class(TCustomControl)
private
  FPanels: TFPList;
  FOrientation: TCExpandOrientation;
  FMultiple: Boolean;
  FSpacing: Integer;
  FScrollable: Boolean;
  FScrollPos: Integer;     // スクロールの位置（軸方向。0 以上）
  FContentLength: Integer; // 全パネルを並べた長さ（6.3 の合計）
public
  constructor Create(TheOwner: TComponent); override;
  destructor Destroy; override;
  procedure AddPanel(ARollout: TCRollout);
  procedure InsertPanel(Index: Integer; ARollout: TCRollout);
  procedure RemovePanel(ARollout: TCRollout);
  procedure MovePanel(CurIndex, NewIndex: Integer);
  property Panels[Index: Integer]: TCRollout read GetPanel;
  property PanelCount: Integer read GetPanelCount;
published
  property Orientation: TCExpandOrientation read FOrientation write SetOrientation default eoVertical;
  property Multiple: Boolean read FMultiple write SetMultiple default True;
  property Spacing: Integer read FSpacing write SetSpacing default 0;
  property Scrollable: Boolean read FScrollable write SetScrollable default True;
  property Align, Anchors, BorderSpacing, Color, Constraints, Enabled, Font, ParentFont,
           ParentColor, ParentShowHint, ShowHint, Visible;
end;
```

- `Scrollable`：`True` で、パネルを並べた長さが入れ物より長いとき、スクロールバー（縦なら縦、横なら横）が出て、スクロールできる。`False` なら、溢れた分は切れる。

### 6.2 パネルの一覧

| 手続き | 処理 |
|---|---|
| `AddPanel(R)` | `R` が nil なら `EArgumentException`。すでに一覧にあれば終わる。`R.Parent := Self`（`SetParent` を通って 6.5 の `AddRollout` が呼ばれ、末尾に入る） |
| `InsertPanel(i, R)` | `AddPanel(R)` したあと、`i` が範囲内なら `MovePanel(末尾, i)` |
| `RemovePanel(R)` | 一覧にあれば `R.Parent := nil`（`RemoveRollout` が呼ばれる）。`R` は解放しない |
| `MovePanel(Cur, New)` | どちらかが範囲外、または同じなら何もしない。`NewControlIndex := GetControlIndex(FPanels[New])`、`FPanels.Move(Cur, New)`、`SetControlIndex(R, NewControlIndex)`、`LayoutChanged`。`FPanels` の順と子の順（.lfm に保存される順）を同じにする |
| `GetPanel(i)` | `FPanels[i]`（範囲外は `EListError`） |
| `GetPanelCount` | `FPanels.Count` |
| `IndexOfPanel(R)` | `FPanels.IndexOf(R)`（なければ -1）。設計時のコンポーネントエディタ（8 章）が、選んでいる TCRollout の番号を知るために使う |
| `AddRollout(R)` | すでにあれば終わる。`FPanels.Add(R)`、`R.Align := alNone`。`LayoutChanged` |
| `RemoveRollout(R)` | 一覧から外し、`LayoutChanged`（壊している途中は何もしない） |
| `InsertControl(AControl, Index)` | `AControl` が `TCRollout` でなければ `EInvalidOperation(CXT(sEpErrChild))`。ほかは `inherited` |

### 6.3 配置（`AlignControls` を上書き）

`inherited` は呼ばず、次の手順で全パネルを置く。軸は `Orientation`（縦なら高さ、横なら幅。以降「軸」と呼ぶ）。

1. 表示している（`Visible`）パネルを `FPanels` の順に集める。0 個なら終わる。
2. 軸の長さ `L` = クライアント領域の軸方向の長さ。
3. `Fill` でないパネルの軸方向の大きさ `S(i)` = `LayoutSize(ExpandedSize)`（アニメーション中は途中の大きさ）。
4. `Fill` のパネル（`F` 個）：開いている、またはアニメーション中（`Expanded` か `FOpenT > 0`）のものを `k` 個とする。中身の分の余り `P := L - Σ S(i) - Σ（`Fill` のパネルの `HeaderSize`）- Spacing * (n - 1)`（`n` は表示しているパネルの数）。`k > 0` なら、中身の大きさ `B := Max(P div k, Scale96ToFont(cFillMin96))`。`Fill` のパネルの大きさは `HeaderSize + Round(B * FOpenT)`（`k` に入らないものは `HeaderSize`）。`k = 0` なら余りは空きのまま（背景を見せる）。
5. 合計 `C := Σ（全パネルの大きさ）+ Spacing * (n - 1)` を `FContentLength` に入れる。
6. スクロール（6.6）：`Scrollable` で `C > L` ならスクロールバーを出して `FScrollPos` を `0 .. C - L` に収め、それ以外はバーを消して `FScrollPos := 0`。
7. パネルを `FPanels` の順に、軸の先頭（`-FScrollPos`）から `Spacing` を空けて並べる。位置は軸方向に積み上げ、交差する向きは 0 から入れ物のクライアント領域の幅（高さ）いっぱい（スクロールバーの分は除く）。`SetBoundsManaged` を使う。
8. `Scrollable = False` で合計が `L` を超えたら、溢れた分は切れる。

`LayoutChanged`：壊している途中、`csLoading` 中は何もしない。`InvalidatePreferredSize`・`ReAlign`・`Invalidate`。

### 6.4 開閉の連動

`RolloutToggled(R)`：

1. `R` が開いて `Multiple = False` なら、ほかの開いているパネルを閉じる（`Expanded := False`。それぞれのイベントも出す）。
2. `LayoutChanged`。

### 6.5 そのほか

| 手続き | 処理 |
|---|---|
| `SetOrientation` | 変わったら入れて `LayoutChanged`。パネルは `EffectivePosition` で再描画する |
| `SetMultiple` | 変わったら入れる。`False` にして開いているパネルが 2 つ以上あれば、最初に開いているもの以外を閉じる（イベントは出す） |
| `SetSpacing` | 負なら 0。変わったら入れて `LayoutChanged` |
| `SetScrollable` | 変わったら入れて `LayoutChanged`（`False` ならバーを消して `FScrollPos := 0`） |
| `DoAutoAdjustLayout` | `inherited` のあと、`lapAutoAdjustWithoutHorizontalScrolling`・`lapAutoAdjustForDPI` なら `FSpacing` を `Round(FSpacing * 倍率)`（軸の向きの倍率） |
| `Destroy` | `inherited Destroy` のあと `FPanels` を解放する（子の `SetParent(nil)` で `RemoveRollout` が呼ばれる） |

### 6.6 スクロール

Windows 標準のスクロールバーを使う（`ShowScrollBar`・`SetScrollInfo`・`GetScrollInfo`。Windows 11 専用）。軸が縦なら `SB_VERT`、横なら `SB_HORZ`。

| 手続き | 処理 |
|---|---|
| `UpdateScrollBar(L, C)` | `Scrollable` で `C > L` なら、`SetScrollInfo`（`nMin = 0`、`nMax = C - 1`、`nPage = L`、`nPos = FScrollPos`）してバーを出す。それ以外はバーを消す。`ShowScrollBar` で出し入れするとクライアント領域の交差する向きの大きさが変わる（バーの厚み）が、軸方向の `L` は変わらないので、配置はやり直さない |
| `ScrollTo(Pos)` | `Pos` を `0 .. Max(0, FContentLength - L)` に収める。同じなら終わる。`FScrollPos := Pos`、バーの位置も更新し、各パネルを（軸方向に）ずらす（配置を最初からやり直す） |
| `WMVScroll`・`WMHScroll` | 軸に合うほうだけ処理する。`SB_LINEUP`・`SB_LINEDOWN`：`Scale96ToFont(cScrollLine96)` ずつ、`SB_PAGEUP`・`SB_PAGEDOWN`：`L` ずつ（`L` は今の軸の長さ）、`SB_TOP`・`SB_BOTTOM`：端、`SB_THUMBTRACK`・`SB_THUMBPOSITION`：`GetScrollInfo`（`SIF_TRACKPOS`）の `nTrackPos` へ。`ScrollTo` を呼ぶ |
| `DoMouseWheel`（`MouseWheel`） | `Scrollable` で、スクロールバーが出ているとき、縦の入れ物はホイールで、横の入れ物は Shift + ホイールで、`Scale96ToFont(cScrollLine96) * 3` ずつ `ScrollTo`。処理したら `Handled := True`。パネルの上の部品（TMemo など）が先にホイールを受け取るので、部品の上のホイールは動かさない |
| `Resize`・パネルの開閉 | `LayoutChanged` を通して 6.3 の配置と `UpdateScrollBar` をやり直す |
| パネルが開く（最後のパネルが伸びて見えなくなるとき） | 開閉のアニメーション中も毎回 6.3 をやり直すので、`FScrollPos` が `FContentLength - L` を超えたら収め直す（閉じたときに空白が見えないように） |

`TCRollout.SetParent(NewParent)`：同じなら終わる。前の親が `TCExpandPanel` なら `RemoveRollout(Self)`。`inherited SetParent`。新しい親が `TCExpandPanel` なら `AddRollout(Self)`。`TCRollout.GetExpandPanel`：`Parent` が `TCExpandPanel` ならそれ、ちがえば nil。

## 7. TCRollout の描画とマウス

### 7.1 描画（`Paint`）

1. 中身の領域を `Color` で塗る。
2. `HeaderRect` を `clBtnFace` で塗る。
3. 開いているとき、見出しの中身側の辺に `clBtnShadow` の 1px の線を引く。
4. 矢印（`ArrowRect`）：`clBtnText` の太さ `Scale96ToFont(1)`（最小 1）の線 2 本で山形（`>`）を描く。向きは次の表。

| 実効の向き | 開いている | 閉じている |
|---|---|---|
| `hpTop` | 下（`∨`） | 右（`>`） |
| `hpBottom` | 上（`∧`） | 右（`>`） |
| `hpLeft` | 右（`>`） | 下（`∨`） |
| `hpRight` | 左（`<`） | 下（`∨`） |

5. 文字（`TextRect`）：`Font`、`clBtnText`、上下中央・1行・末尾「…」・はみ出しを切る。`hpLeft` は `Font.Orientation := 900`、`hpRight` は `2700` にして、`TextRect` を切り取り範囲（`ClipRect`）にして描く。
6. ボタン：`ButtonsShown` のときだけ描く。表示する（`Visible`）ボタンごとに、`ButtonRect` を枠として、マウスが乗っていて（`FHotButton`）、ボタンが `Enabled` なら `clBtnHighlight` で角丸（`cButtonRadius96`）に塗る。押している間は `clBtnShadow` で塗る。`ImageIndex` が範囲内なら、枠の中央にアイコンを描く（`Res := Images.ResolutionForPPI[FImagesWidth, Font.PixelsPerInch, 1]`。`Enabled` でない、または TCRollout が `Enabled` でなければ、`Res.GetBitmap(ImageIndex, Bmp, gdeDisabled)` の灰色の画像を `Canvas.Draw`）。

### 7.2 マウス

- `MouseDown`：`inherited` のあと、左ボタンで、見出しの中なら、ボタンの上なら `FDownButton := その番号`、ほかは `FDownHeader := True`。
- `MouseMove`：`inherited` のあと、`SetHeaderHot(見出しの中か)`、`SetHot(ButtonAt(X, Y))`。
- `MouseUp`：`inherited` のあと、左ボタンでなければ終わる。`FDownButton` があれば、離した所も同じボタンで、ボタンが `Enabled` で、TCRollout が `Enabled` なら `ClickButton(番号)`。`FDownHeader` で、離した所も見出しの中（ボタンの外）なら `Expanded := not Expanded`（`Enabled` のときだけ。設計時は常に）。
- `MouseLeave`：`inherited` のあと `SetHeaderHot(False)`、`SetHot(-1)`。
- `SetHot(i)`：同じなら終わる。別のボタンに移ったら `Application.CancelHint`。入れて `Invalidate`。
- `SetHeaderHot(b)`：同じなら終わる。入れて、`ButtonsShow = bsHover` なら `Invalidate`（ボタンを出す・消す）。`bsAlways` のときは何もしない。
- 見出しの中のマウス移動は、ボタンが出ていない（`bsHover`）間も `MouseMove` で受ける。ボタンが消えた状態で見出しをクリックしたときは、ボタンではなく見出し（開閉）として扱う（`ButtonAt` が -1 を返すため）。

### 7.3 ボタンを押したとき（`ClickButton(i)`）

1. 設計時なら何もしない。
2. `OnButtonClick(Self, i)` があれば呼ぶ。
3. `Buttons.Items[i].DropDownMenu` があれば、`PopupComponent := Self` にして、ボタンの画面座標で `Popup`。見出しが横なら、ボタンの左下。縦なら、ボタンの右上。`FMenuOpen := True`（メニューを開いている間もボタンを出したままにする）。`Popup` が戻ったら（メニューが閉じたら）`FMenuOpen := False`、`FHotHeader` を今のマウス位置で取り直し、`Invalidate`。

### 7.4 設計時

- 見出しのクリックで開閉でき、`OwnerFormDesignerModified(Self)` を呼ぶ。ボタンは押しても何も起きない。
- `CMDesignHitTest`：TCSideBar の設計書 7.5 と同じ考え方で、見出しの中（ボタンを含む）なら 1、ほかは 0（中身はデザイナが処理する）。`FDesignerPressLeft` の扱いも同じ。

### 7.5 ヒント（`CMHintShow`）

`inherited` のあと、マウスの下のボタンに `Hint` があれば、`HintStr := Hint`、`CursorRect := ButtonRect(番号)`。ボタンの上でなければ、通常のヒント（`Hint`）に任せる。

## 8. 設計時（uCExpandPanelReg）

`Register`：

1. `RegisterComponents('CX', [TCExpandPanel, TCRollout])`（TCRollout は単体でも置くのでパレットに出す）。
2. `RegisterComponentEditor(TCExpandPanel, TCExpandPanelEditor)`、`RegisterComponentEditor(TCRollout, TCExpandPanelEditor)`。

`TCExpandPanelEditor = class(TComponentEditor)`：操作する入れ物は、選んでいる部品が `TCRollout` ならその `ExpandPanel`（なければ何もしない）、`TCExpandPanel` ならそれ。

| 番号 | 表示 | 処理 |
|---|---|---|
| 0 | パネルの追加 | 入れ物に、`TCRollout.Create`（Owner は入れ物の Owner）。`Name := GetDesigner.CreateUniqueComponentName(ClassName)`、`Caption := Name`、`AddPanel`、`Hook.PersistentAdded(新しいもの, True)`、`Modified` |
| 1 | パネルの削除 | 選んでいるのが TCRollout で入れ物の中にあるとき、`Hook.DeletePersistent`。ほかは何もしない |
| 2 | 上へ移動 | 選んでいる TCRollout の番号 `Cur` が 1 以上なら `MovePanel(Cur, Cur - 1)`、`Modified` |
| 3 | 下へ移動 | 同じく `Cur + 1` へ |

`GetVerbCount` は 4。表示の文字は resourcestring（`rsCExpandPanelAdd` など。IDE の上の文字は、いつも日本語）。

## 9. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| 閉じても大きさが戻らない・開いても元の大きさにならない | `SetBounds`・`ApplyOwnSize`（5.4）、`FManaged`、アニメーション中に `ExpandedSize` が書き換わっていないか |
| 開閉の動きがカクつく・止まる | `StartOpen`・`AnimTimerTick`（5.4）、`AnimationTime`、`Animated` |
| ボタンが出ない・消えない | `ButtonsShown`（5.6）、`ButtonsShow`、`FHotHeader`（7.2） |
| スクロールバーが出ない・位置が戻る | `UpdateScrollBar`・`ScrollTo`（6.6）、`Scrollable`、`FContentLength`（6.3 の 5〜6） |
| 入れ物の中で開いたパネルが余りを埋めない | `Fill`、6.3 の 3〜4 |
| `hpLeft` が縦配置の入れ物で横向きにならない | `EffectivePosition`（5.3） |
| ［…］のメニューが出ない | `ClickButton`（7.3）、`DropDownMenu`、`Notification` |
| 設計時に置いた部品がパネルに入らない | `csAcceptsControls`（5.2）、`AdjustClientRect`（5.5） |
| パネルの順番が .lfm と違う | `MovePanel` の `SetControlIndex`（6.2） |
| 表示スケールでタイトルバーの厚みがずれる | `DoAutoAdjustLayout`（5.4・6.5） |
