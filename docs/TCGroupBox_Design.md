# TCGroupBox 設計書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 目的

- 標準の TGroupBox（Windows のネイティブ部品）では、中に置いた標準部品が消えることがある。これをなくすため、LCL が描く `TCustomPanel` を元にし、枠と見出しを自分で描くグループボックス TCGroupBox を作る。見た目・プロパティ・イベントは TGroupBox に合わせる。
- 見出しにチェックボックスを持ち、チェックを外すと中の部品をすべて無効にする TCCheckGroupBox を、TCGroupBox から作る。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCGroupBox.pas` | cx（実行時） | `TCGroupBox`、寸法の定数 |
| `uCCheckGroupBox.pas` | cx（実行時） | `TCCGBSavedItem`・`TCCheckGroupBox` |
| `uCXReg.pas` | cxdsgn（設計時） | パレット [CX] への登録（`RegisterComponents('CX', [..., TCGroupBox, TCCheckGroupBox])`。並びの末尾） |
| `cgroupbox_icon.lrs` | cxdsgn（設計時） | アイコン（`TCGroupBox`・`TCGroupBox_150`・`TCGroupBox_200`）。`uCXReg` の initialization で `{$I cgroupbox_icon.lrs}` |
| `ccheckgroupbox_icon.lrs` | cxdsgn（設計時） | アイコン（`TCCheckGroupBox`・`TCCheckGroupBox_150`・`TCCheckGroupBox_200`）。`uCXReg` の initialization で `{$I ccheckgroupbox_icon.lrs}` |

- `uCGroupBox` の uses：`Classes, SysUtils, Types, Controls, ExtCtrls, Graphics, Forms, LCLType, LCLIntf, LMessages, Themes`
- `uCCheckGroupBox` の uses：`Classes, SysUtils, Types, Controls, StdCtrls, LMessages, uCGroupBox`
- `uCGroupBox` の finalization で、文字を測るための共用ビットマップ `MeasureBitmap` を `FreeAndNil` する。initialization はない。

## 3. TCGroupBox

### 3.1 定数（96dpi のときの値。使うときは `ScaleValue` で換算する）

| 名前 | 値 | 中身 |
|---|---|---|
| `CGB_CAPTION_LEFT` | 9 | 見出しの左端（枠の左端から。TGroupBox に合わせる） |
| `CGB_CAPTION_PAD` | 2 | 見出しの前後に空ける幅（この幅も枠線を切る） |
| `CGB_INNER_MARGIN` | 2 | 子の部品が使う領域の、左・右・下の余白と、見出しの下の余白 |

interface に置き、TCCheckGroupBox からも使う。

### 3.2 宣言

```pascal
TCGroupBox = class(TCustomPanel)
protected
  procedure CMTextChanged(var Message: TLMessage); message CM_TEXTCHANGED;
  procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
  procedure CMColorChanged(var Message: TLMessage); message CM_COLORCHANGED;
  function ScaleValue(AValue: Integer): Integer;
  function MeasureTextHeight(const AText: string): Integer;
  function MeasureTextWidth(const AText: string): Integer;
  function GetCaptionHeight: Integer; virtual;
  function GetCaptionGapWidth: Integer; virtual;
  procedure PaintCaption(const ARect: TRect); virtual;
  procedure DrawCaptionText(const ARect: TRect; const AText: string);
  function UseThemeDrawing: Boolean;
  function GetCaptionLeft: Integer;
  procedure Paint; override;
  procedure FontChanged(Sender: TObject); override;
public
  constructor Create(AOwner: TComponent); override;
  procedure AdjustClientRect(var ARect: TRect); override;
published
  // 取説 4.1・4.3 の一覧のとおり（TGroupBox と同じもの）
end;
```

- メッセージ処理を protected にするのは、TCCheckGroupBox が同じメッセージを受けて `inherited` で呼べるようにするため。
- `GetCaptionHeight`・`GetCaptionGapWidth`・`PaintCaption` を virtual にするのは、TCCheckGroupBox が見出しを差し替えるため。

published に出すもの：`Align, Anchors, AutoSize, BidiMode, BorderSpacing, Caption, ChildSizing, ClientHeight, ClientWidth, Color, Constraints, DockSite, DoubleBuffered, DragCursor, DragKind, DragMode, Enabled, Font, ParentBackground, ParentBidiMode, ParentColor, ParentDoubleBuffered, ParentFont, ParentShowHint, PopupMenu, ShowHint, TabOrder, TabStop, Visible, OnChangeBounds, OnClick, OnContextPopup, OnDblClick, OnDragDrop, OnDockDrop, OnDockOver, OnDragOver, OnEndDock, OnEndDrag, OnEnter, OnExit, OnGetSiteInfo, OnKeyDown, OnKeyPress, OnKeyUp, OnMouseDown, OnMouseEnter, OnMouseLeave, OnMouseMove, OnMouseUp, OnMouseWheel, OnMouseWheelDown, OnMouseWheelUp, OnResize, OnStartDock, OnStartDrag, OnUnDock, OnUTF8KeyPress`

### 3.3 Create

1. `inherited Create`。
2. `BevelOuter := bvNone`、`BevelInner := bvNone`（TCustomPanel の立体枠は使わない）。
3. `SetInitialBounds(0, 0, 185, 105)`（TGroupBox と同じ既定の大きさ）。
4. `ParentColor := True`。

### 3.4 寸法

| 手続き | 処理 |
|---|---|
| `ScaleValue(v)` | `GetParentDesignControl(Self)` があれば `MulDiv(v, その PixelsPerInch, 96)`、なければ `MulDiv(v, Screen.PixelsPerInch, 96)` |
| `MeasureTextHeight(s)`・`MeasureTextWidth(s)` | 共用ビットマップ（1×1。最初に使うときに作る）の Canvas に `Font` を Assign して測る。ハンドルがない部品でも測れる |
| `GetCaptionHeight` | `MeasureTextHeight('Wg')`。Caption の中身によらない（空でも同じ高さ。中の部品が動かないように） |
| `GetCaptionGapWidth` | Caption が空なら 0、それ以外は `MeasureTextWidth(Caption)`。前後の余白は含まない |
| `GetCaptionLeft` | `UseRightToLeftAlignment` なら `Width - ScaleValue(CGB_CAPTION_LEFT) - GetCaptionGapWidth`、それ以外は `ScaleValue(CGB_CAPTION_LEFT)` |

### 3.5 子の部品の領域（AdjustClientRect）

`inherited` のあと、`M := ScaleValue(CGB_INNER_MARGIN)` として、`Top += GetCaptionHeight + M`、`Left += M`、`Right -= M`、`Bottom -= M`。

### 3.6 描画（Paint）

1. 全面を `GetColorResolvingParent` で塗る。
2. `CH := GetCaptionHeight`、`LineY := CH div 2`、`Gap := GetCaptionGapWidth`、`Pad := ScaleValue(CGB_CAPTION_PAD)`、`TL := GetCaptionLeft`、`GapRect := Rect(TL - Pad, 0, TL + Gap + Pad, CH)`。
3. 枠：
   - `UseThemeDrawing` が `True`：`SaveDC` → `Gap > 0` なら `ExcludeClipRect(GapRect)` → `IsEnabled` なら `tbGroupBoxNormal`、そうでなければ `tbGroupBoxDisabled` の部品を `ThemeServices.DrawElement(DC, Det, Rect(0, LineY, Width, Height))` で描く → `RestoreDC`。
   - `False`：1px・`clBtnShadow`・`bsClear` で `Rectangle(0, LineY, Width, Height)`。`Gap > 0` なら `GapRect` を背景色で塗って上辺を切る。
4. `Gap > 0` なら `PaintCaption(Rect(TL, 0, TL + Gap, CH))`。

`UseThemeDrawing`：Windows では `ThemeServices.ThemesEnabled`、それ以外は `False`。

### 3.7 見出しの文字（DrawCaptionText）

`PaintCaption(ARect)` は `DrawCaptionText(ARect, Caption)` を呼ぶだけ。

`DrawCaptionText(ARect, AText)`：

1. `AText` が空なら終わる。
2. `Canvas.Font.Assign(Font)`、`Brush.Style := bsClear`。
3. `UseThemeDrawing` かつ `Font.Color = clDefault`：有効なら `tbGroupBoxNormal`、無効なら `tbGroupBoxDisabled` の部品で `ThemeServices.DrawText(Canvas, Det, AText, ARect, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX, 0)`。ダーク表示では MetaDarkStyle の色になる。
4. それ以外：有効なら `Font.Color`（`clDefault` なら `GetDefaultColor(dctFont)`）、無効なら `clGrayText`。`ARect` の上下中央に `TextOut`。

色はシステム色・テーマの色だけを使う（ダーク／ライトの追従は MetaDarkStyle などに任せる）。

### 3.8 変化への対応

| 手続き | 処理 |
|---|---|
| `FontChanged` | `inherited` のあと `InvalidatePreferredSize`・`ReAlign`・`Invalidate`（見出しの高さが変わるため、子の配置からやり直す） |
| `CMTextChanged` | `inherited` のあと `Invalidate`（見出しの高さは Caption によらない） |
| `CMEnabledChanged` | `inherited` のあと `Invalidate`（文字色が変わる） |
| `CMColorChanged` | `inherited` のあと `Invalidate` |

## 4. TCCheckGroupBox

### 4.1 型

```pascal
TCCGBSavedItem = record
  Control: TControl;   // 無効にした部品
  Enabled: Boolean;    // 無効にする前の Enabled
end;
```

定数（implementation）：`CCGB_CHECK_SPACE = 4`（チェックボックスと見出しの文字の間。96dpi のときの値）。

### 4.2 フィールド

| 名前 | 型 | 中身 |
|---|---|---|
| `FCheckBox` | `TCheckBox` | 見出しのチェックボックス。Owner は Self |
| `FChecked` | `Boolean` | Checked の値（初期値 `True`） |
| `FOnChange` | `TNotifyEvent` | イベント |
| `FSyncing` | `Boolean` | Checked をチェックボックスへ入れている間 `True`（再入を防ぐ） |
| `FPlacing` | `Boolean` | チェックボックスの位置を直している間 `True`（再入を防ぐ） |
| `FInnerDisabled` | `Boolean` | 中の部品を無効にしている間 `True` |
| `FDownInText` | `Boolean` | 見出しの文字の中で左ボタンが押されている間 `True` |
| `FSaved` | `array of TCCGBSavedItem` | 無効にした部品の記録 |
| `FSavedCount` | `Integer` | 記録の数 |

### 4.3 宣言

```pascal
TCCheckGroupBox = class(TCGroupBox)
private
  procedure SetChecked(AValue: Boolean);
  procedure CheckBoxChange(Sender: TObject);
  procedure CheckBoxResize(Sender: TObject);
  procedure CheckBoxFocusChange(Sender: TObject);
  procedure SyncCheckBox;
  procedure UpdateCheckBoxBounds;
  procedure UpdateInnerEnabled;
  procedure DisableTree(AParent: TWinControl);
  procedure DisableOne(AControl: TControl);
  function IsSaved(AControl: TControl): Boolean;
  procedure RestoreAll;
  procedure CMCheckEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
  procedure CMCheckControlChange(var Message: TLMessage); message CM_CONTROLCHANGE;
protected
  function GetCaptionHeight: Integer; override;
  function GetCaptionGapWidth: Integer; override;
  procedure PaintCaption(const ARect: TRect); override;
  procedure RealSetText(const AValue: TCaption); override;
  procedure FontChanged(Sender: TObject); override;
  procedure Resize; override;
  procedure Loaded; override;
  procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
  procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  function CaptionTextRect: TRect;
  procedure DoChange; virtual;
public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
published
  property Checked: Boolean read FChecked write SetChecked default True;
  property OnChange: TNotifyEvent read FOnChange write FOnChange;
end;
```

### 4.4 Create・Destroy

Create：

1. `inherited Create`、`FChecked := True`、`FSavedCount := 0`。
2. `FCheckBox := TCheckBox.Create(Self)`。Owner が Self（フォームではない）なので .lfm に書かれない。
3. `ControlStyle` に `csNoDesignSelectable` を足す（設計時に選べない）。`AutoSize := True`、`ParentFont := True`、`ParentColor := True`、`TabStop := True`、`Checked := True`、`Caption := ''`（四角だけ。文字は本体が描く。ダーク表示でネイティブのチェックボックスの文字色に左右されないように）。
4. `Parent := Self`、`TabOrder := 0`。
5. `OnChange := CheckBoxChange`、`OnResize := CheckBoxResize`、`OnEnter`・`OnExit := CheckBoxFocusChange`。
6. `UpdateCheckBoxBounds`。

Destroy：`FSavedCount := 0`、`SetLength(FSaved, 0)`、`inherited`（FreeNotification は TComponent が外す）。

### 4.5 見出し

| 手続き | 処理 |
|---|---|
| `GetCaptionHeight` | `inherited` の値と `FCheckBox.Height` の大きいほう |
| `GetCaptionGapWidth` | `FCheckBox` が nil なら `inherited`。それ以外は `FCheckBox.Width`、Caption があれば `+ ScaleValue(CCGB_CHECK_SPACE) + MeasureTextWidth(Caption)` |
| `CaptionTextRect` | 文字の範囲。`CBW` = チェックボックスの幅、`TW` = 文字の幅（空なら 0）。左から：`L := ScaleValue(CGB_CAPTION_LEFT) + CBW + ScaleValue(CCGB_CHECK_SPACE)`。右から左：`L := Width - ScaleValue(CGB_CAPTION_LEFT) - CBW - ScaleValue(CCGB_CHECK_SPACE) - TW`。結果は `Rect(L, 0, L + TW, GetCaptionHeight)` |
| `PaintCaption` | Caption が空なら終わる。`R := CaptionTextRect`、`DrawCaptionText(R, Caption)`。`FCheckBox.Focused` なら `InflateRect(R, 1, 1)` して `Canvas.DrawFocusRect(R)`（チェックボックスに文字がないため、その代わりのフォーカス枠） |
| `CheckBoxFocusChange` | `Invalidate` |
| `RealSetText` | `inherited` のあと `UpdateCheckBoxBounds`・`Invalidate`。チェックボックスには文字を入れない |

### 4.6 チェックボックスの位置（UpdateCheckBoxBounds）

1. `FCheckBox` が nil、または `FPlacing` なら終わる。`FPlacing := True`（try〜finally で戻す）。
2. `Off := ScaleValue(CGB_CAPTION_LEFT)`、`T := (GetCaptionHeight - FCheckBox.Height) div 2`。
3. 右から左：`Anchors := [akTop, akRight]`、`SetBounds(Width - Off - FCheckBox.Width, T, ...)`。
4. 左から：`Anchors := [akTop]`、`SetBounds(Off, T, ...)`。

Anchors を `[akLeft, akTop]` 以外にするのは、`ChildSizing.Layout` の並べ替えの対象から外すため（LCL は `Align = alNone` かつ `Anchors = [akLeft, akTop]` の部品だけを並べ替える）。

呼ぶところ：`Create`・`RealSetText`・`FontChanged`（`inherited` のあと）・`Resize`（`inherited` のあと。右から左では幅が変わると置き直す）・`CheckBoxResize`（このあと `ReAlign`・`Invalidate`）・`Loaded`。

### 4.7 Checked

`SetChecked(v)`：

1. 同じ値なら終わる。
2. `FChecked := v`、`SyncCheckBox`、`UpdateInnerEnabled`。
3. `csLoading` でなければ `DoChange`。

| 手続き | 処理 |
|---|---|
| `SyncCheckBox` | `FSyncing := True` の間に `FCheckBox.Checked := FChecked`（`CheckBoxChange` から `SetChecked` へ戻らない） |
| `CheckBoxChange` | `FSyncing` なら終わる。それ以外は `SetChecked(FCheckBox.Checked)`（画面で押されたとき） |
| `DoChange` | `FOnChange` があれば呼ぶ |

### 4.8 見出しの文字のクリック

- `MouseDown`：`inherited` のあと、`FDownInText := (Button = mbLeft) and PtInRect(CaptionTextRect, Point(X, Y))`。
- `MouseUp`：`inherited` のあと、`Hit := FDownInText and (Button = mbLeft) and PtInRect(CaptionTextRect, Point(X, Y))`、`FDownInText := False`。`Hit` でない、`FCheckBox` が nil、`IsEnabled` でない、設計時、のどれかなら終わる。それ以外は `FCheckBox.Checked := not FCheckBox.Checked`（`CheckBoxChange` 経由で `Checked`・`OnChange`・中の有効／無効が処理される）、`CanFocus` なら `SetFocus`。

### 4.9 中の部品の有効・無効

`UpdateInnerEnabled`：

1. `ComponentState` に `csLoading`・`csDesigning`・`csDestroying` のどれかがあれば何もしない（読み込み中は `Loaded` で行う。設計時は .lfm に `Enabled = False` が残らないように）。
2. `NeedDisable := not (Enabled and FChecked)`。
3. `NeedDisable` で `FInnerDisabled` が `False`：`FInnerDisabled := True`、`DisableTree(Self)`。
4. `NeedDisable` でなく `FInnerDisabled` が `True`：`RestoreAll`、`FInnerDisabled := False`。

| 手続き | 処理 |
|---|---|
| `DisableTree(P)` | `P.Controls` を順に見る。`FCheckBox` は飛ばす。`DisableOne(C)`。`C` が `TWinControl` で、`TCCheckGroupBox` でなく、`csAcceptsControls` を持つ（入れ物）なら `DisableTree(C)` で中もたどる。TCCheckGroupBox は自分の Enabled の変化で中を処理するのでたどらない。入れ物でない部品（複合部品）はその部品だけ |
| `DisableOne(C)` | `IsSaved(C)` なら終わる。`FSaved` が足りなければ `SetLength(FSaved, FSavedCount * 2 + 8)`。`C` と `C.Enabled` を記録、`C.FreeNotification(Self)`、`C.Enabled := False` |
| `IsSaved(C)` | 記録に `C` があれば `True` |
| `RestoreAll` | 記録を後ろから順に（中の部品から先に）、`Control` が nil でなければ `Enabled` を戻し、`RemoveFreeNotification(Self)`。最後に `FSavedCount := 0`、`SetLength(FSaved, 0)` |
| `CMCheckEnabledChanged` | `inherited` のあと、`FCheckBox.Enabled := Enabled`、`UpdateInnerEnabled` |
| `CMCheckControlChange` | `inherited` のあと、`FInnerDisabled` で `Message.LParam <> 0`（追加）なら、`C := TControl(Message.WParam)` が `FCheckBox` でなければ `DisableOne(C)`（直下に追加された部品だけ） |
| `Notification` | `opRemove` のとき、`AComponent = FCheckBox` なら `FCheckBox := nil`。記録の中で `Control = AComponent` のものを nil にする |

- 無効にしている間にアプリが中の部品の `Enabled` を変えても、`RestoreAll` で記録した値に戻る（取説 5.4）。

### 4.10 保存と読み込み

- `GetChildren`：`Controls` のうち、`FCheckBox` でなく、`Owner = Root` のものだけを `Proc` に渡す。本体自身をストリームの起点にしたときも、チェックボックスが書かれない。
- `Loaded`：`inherited` のあと、`SyncCheckBox`・`UpdateCheckBoxBounds`・`UpdateInnerEnabled`（子の部品がすべて読み込まれてから合わせる）。

## 5. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| 見出しの位置・枠の切れ目がずれる | `GetCaptionLeft`・`GetCaptionGapWidth`・`CaptionTextRect`・`ScaleValue`（3.4、4.5） |
| ダーク表示で見出しの色が合わない | `DrawCaptionText` の 3 と 4 の分かれ目（`Font.Color = clDefault` か）（3.7） |
| 中の部品が見出しに重なる | `AdjustClientRect`（3.5）、`GetCaptionHeight` |
| チェックボックスが ChildSizing で動いてしまう | `UpdateCheckBoxBounds` の Anchors（4.6） |
| チェックを付けても中の部品が戻らない | `RestoreAll`、`Notification` で記録が nil になっていないか（4.9） |
| 設計時に .lfm に `Enabled = False` が残る | `UpdateInnerEnabled` の 1（4.9） |
| .lfm にチェックボックスが書かれる | `GetChildren`（4.10） |
