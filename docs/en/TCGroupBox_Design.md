# TCGroupBox Design Document

Author: aotan083
Date: 2026-10-29
Version: 1.0

---

## 1. Purpose

- With the standard TGroupBox (a native Windows control), standard controls placed inside it can disappear. To eliminate this, TCGroupBox is built on the LCL-drawn `TCustomPanel` and draws its own frame and caption. Its appearance, properties and events match TGroupBox.
- TCCheckGroupBox, derived from TCGroupBox, has a check box in the caption, and unchecking it disables all the controls inside.

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCGroupBox.pas` | cx (runtime) | `TCGroupBox`, dimension constants |
| `uCCheckGroupBox.pas` | cx (runtime) | `TCCGBSavedItem`, `TCCheckGroupBox` |
| `uCXReg.pas` | cxdsgn (design time) | Registration on the [CX] palette (`RegisterComponents('CX', [..., TCGroupBox, TCCheckGroupBox])`; at the end of the list) |
| `cgroupbox_icon.lrs` | cxdsgn (design time) | Icons (`TCGroupBox`, `TCGroupBox_150`, `TCGroupBox_200`). Included with `{$I cgroupbox_icon.lrs}` in the initialization of `uCXReg` |
| `ccheckgroupbox_icon.lrs` | cxdsgn (design time) | Icons (`TCCheckGroupBox`, `TCCheckGroupBox_150`, `TCCheckGroupBox_200`). Included with `{$I ccheckgroupbox_icon.lrs}` in the initialization of `uCXReg` |

- uses of `uCGroupBox`: `Classes, SysUtils, Types, Controls, ExtCtrls, Graphics, Forms, LCLType, LCLIntf, LMessages, Themes`
- uses of `uCCheckGroupBox`: `Classes, SysUtils, Types, Controls, StdCtrls, LMessages, uCGroupBox`
- In the finalization of `uCGroupBox`, the shared bitmap `MeasureBitmap` used for measuring text is released with `FreeAndNil`. There is no initialization.

## 3. TCGroupBox

### 3.1 Constants (values at 96 dpi; convert with `ScaleValue` when used)

| Name | Value | Contents |
|---|---|---|
| `CGB_CAPTION_LEFT` | 9 | Left edge of the caption (from the left edge of the frame; matches TGroupBox) |
| `CGB_CAPTION_PAD` | 2 | Width left before and after the caption (the frame line is cut across this width too) |
| `CGB_INNER_MARGIN` | 2 | Left, right and bottom margins of the area used by child controls, and the margin below the caption |

Placed in the interface and also used by TCCheckGroupBox.

### 3.2 Declaration

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
  // As in the lists in sections 4.1 and 4.3 of the User Manual (same as TGroupBox)
end;
```

- The message handlers are protected so that TCCheckGroupBox can receive the same messages and call them with `inherited`.
- `GetCaptionHeight`, `GetCaptionGapWidth` and `PaintCaption` are virtual because TCCheckGroupBox replaces the caption.

Published members: `Align, Anchors, AutoSize, BidiMode, BorderSpacing, Caption, ChildSizing, ClientHeight, ClientWidth, Color, Constraints, DockSite, DoubleBuffered, DragCursor, DragKind, DragMode, Enabled, Font, ParentBackground, ParentBidiMode, ParentColor, ParentDoubleBuffered, ParentFont, ParentShowHint, PopupMenu, ShowHint, TabOrder, TabStop, Visible, OnChangeBounds, OnClick, OnContextPopup, OnDblClick, OnDragDrop, OnDockDrop, OnDockOver, OnDragOver, OnEndDock, OnEndDrag, OnEnter, OnExit, OnGetSiteInfo, OnKeyDown, OnKeyPress, OnKeyUp, OnMouseDown, OnMouseEnter, OnMouseLeave, OnMouseMove, OnMouseUp, OnMouseWheel, OnMouseWheelDown, OnMouseWheelUp, OnResize, OnStartDock, OnStartDrag, OnUnDock, OnUTF8KeyPress`

### 3.3 Create

1. `inherited Create`.
2. `BevelOuter := bvNone`, `BevelInner := bvNone` (TCustomPanel's 3D bevel is not used).
3. `SetInitialBounds(0, 0, 185, 105)` (same default size as TGroupBox).
4. `ParentColor := True`.

### 3.4 Dimensions

| Procedure | Processing |
|---|---|
| `ScaleValue(v)` | If `GetParentDesignControl(Self)` exists, `MulDiv(v, its PixelsPerInch, 96)`; otherwise `MulDiv(v, Screen.PixelsPerInch, 96)` |
| `MeasureTextHeight(s)`, `MeasureTextWidth(s)` | Assigns `Font` to the Canvas of the shared bitmap (1x1; created on first use) and measures. Works even for a control without a handle |
| `GetCaptionHeight` | `MeasureTextHeight('Wg')`. Independent of the contents of Caption (same height even when empty, so the controls inside do not move) |
| `GetCaptionGapWidth` | 0 if Caption is empty, otherwise `MeasureTextWidth(Caption)`. Does not include the margins before and after |
| `GetCaptionLeft` | If `UseRightToLeftAlignment`, `Width - ScaleValue(CGB_CAPTION_LEFT) - GetCaptionGapWidth`; otherwise `ScaleValue(CGB_CAPTION_LEFT)` |

### 3.5 Area for Child Controls (AdjustClientRect)

After `inherited`, with `M := ScaleValue(CGB_INNER_MARGIN)`: `Top += GetCaptionHeight + M`, `Left += M`, `Right -= M`, `Bottom -= M`.

### 3.6 Painting (Paint)

1. Fill the whole area with `GetColorResolvingParent`.
2. `CH := GetCaptionHeight`, `LineY := CH div 2`, `Gap := GetCaptionGapWidth`, `Pad := ScaleValue(CGB_CAPTION_PAD)`, `TL := GetCaptionLeft`, `GapRect := Rect(TL - Pad, 0, TL + Gap + Pad, CH)`.
3. Frame:
   - `UseThemeDrawing` is `True`: `SaveDC` -> if `Gap > 0`, `ExcludeClipRect(GapRect)` -> draw the `tbGroupBoxNormal` element if `IsEnabled`, otherwise `tbGroupBoxDisabled`, with `ThemeServices.DrawElement(DC, Det, Rect(0, LineY, Width, Height))` -> `RestoreDC`.
   - `False`: `Rectangle(0, LineY, Width, Height)` with 1px, `clBtnShadow`, `bsClear`. If `Gap > 0`, fill `GapRect` with the background color to cut the top edge.
4. If `Gap > 0`, `PaintCaption(Rect(TL, 0, TL + Gap, CH))`.

`UseThemeDrawing`: `ThemeServices.ThemesEnabled` on Windows, `False` otherwise.

### 3.7 Caption Text (DrawCaptionText)

`PaintCaption(ARect)` simply calls `DrawCaptionText(ARect, Caption)`.

`DrawCaptionText(ARect, AText)`:

1. If `AText` is empty, finish.
2. `Canvas.Font.Assign(Font)`, `Brush.Style := bsClear`.
3. `UseThemeDrawing` and `Font.Color = clDefault`: use the `tbGroupBoxNormal` element if enabled, `tbGroupBoxDisabled` if disabled, with `ThemeServices.DrawText(Canvas, Det, AText, ARect, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX, 0)`. In dark display the MetaDarkStyle color is used.
4. Otherwise: `Font.Color` if enabled (`GetDefaultColor(dctFont)` if `clDefault`), `clGrayText` if disabled. `TextOut` centered vertically in `ARect`.

Only system colors and theme colors are used (following dark/light is left to MetaDarkStyle and the like).

### 3.8 Handling Changes

| Procedure | Processing |
|---|---|
| `FontChanged` | After `inherited`, `InvalidatePreferredSize`, `ReAlign`, `Invalidate` (the caption height changes, so child layout is redone from the start) |
| `CMTextChanged` | After `inherited`, `Invalidate` (the caption height does not depend on Caption) |
| `CMEnabledChanged` | After `inherited`, `Invalidate` (the text color changes) |
| `CMColorChanged` | After `inherited`, `Invalidate` |

## 4. TCCheckGroupBox

### 4.1 Types

```pascal
TCCGBSavedItem = record
  Control: TControl;   // The control that was disabled
  Enabled: Boolean;    // Enabled before it was disabled
end;
```

Constant (implementation): `CCGB_CHECK_SPACE = 4` (space between the check box and the caption text; value at 96 dpi).

### 4.2 Fields

| Name | Type | Contents |
|---|---|---|
| `FCheckBox` | `TCheckBox` | The check box in the caption. Owner is Self |
| `FChecked` | `Boolean` | Value of Checked (initial value `True`) |
| `FOnChange` | `TNotifyEvent` | Event |
| `FSyncing` | `Boolean` | `True` while Checked is being put into the check box (prevents re-entry) |
| `FPlacing` | `Boolean` | `True` while the check box position is being corrected (prevents re-entry) |
| `FInnerDisabled` | `Boolean` | `True` while the inner controls are disabled |
| `FDownInText` | `Boolean` | `True` while the left button is held down inside the caption text |
| `FSaved` | `array of TCCGBSavedItem` | Record of the controls that were disabled |
| `FSavedCount` | `Integer` | Number of records |

### 4.3 Declaration

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

### 4.4 Create and Destroy

Create:

1. `inherited Create`, `FChecked := True`, `FSavedCount := 0`.
2. `FCheckBox := TCheckBox.Create(Self)`. The Owner is Self (not the form), so it is not written to the .lfm.
3. Add `csNoDesignSelectable` to `ControlStyle` (cannot be selected at design time). `AutoSize := True`, `ParentFont := True`, `ParentColor := True`, `TabStop := True`, `Checked := True`, `Caption := ''` (only the box; the text is drawn by the main body, so that it is not affected by the native check box's text color in dark display).
4. `Parent := Self`, `TabOrder := 0`.
5. `OnChange := CheckBoxChange`, `OnResize := CheckBoxResize`, `OnEnter` and `OnExit := CheckBoxFocusChange`.
6. `UpdateCheckBoxBounds`.

Destroy: `FSavedCount := 0`, `SetLength(FSaved, 0)`, `inherited` (TComponent removes the FreeNotification).

### 4.5 Caption

| Procedure | Processing |
|---|---|
| `GetCaptionHeight` | The larger of the `inherited` value and `FCheckBox.Height` |
| `GetCaptionGapWidth` | `inherited` if `FCheckBox` is nil. Otherwise `FCheckBox.Width`, plus `+ ScaleValue(CCGB_CHECK_SPACE) + MeasureTextWidth(Caption)` if there is a Caption |
| `CaptionTextRect` | The text range. `CBW` = check box width, `TW` = text width (0 if empty). Left to right: `L := ScaleValue(CGB_CAPTION_LEFT) + CBW + ScaleValue(CCGB_CHECK_SPACE)`. Right to left: `L := Width - ScaleValue(CGB_CAPTION_LEFT) - CBW - ScaleValue(CCGB_CHECK_SPACE) - TW`. The result is `Rect(L, 0, L + TW, GetCaptionHeight)` |
| `PaintCaption` | If Caption is empty, finish. `R := CaptionTextRect`, `DrawCaptionText(R, Caption)`. If `FCheckBox.Focused`, `InflateRect(R, 1, 1)` and `Canvas.DrawFocusRect(R)` (a focus rectangle in place of the one the check box would draw, because it has no text) |
| `CheckBoxFocusChange` | `Invalidate` |
| `RealSetText` | After `inherited`, `UpdateCheckBoxBounds` and `Invalidate`. No text is put in the check box |

### 4.6 Check Box Position (UpdateCheckBoxBounds)

1. If `FCheckBox` is nil or `FPlacing`, finish. `FPlacing := True` (restored with try-finally).
2. `Off := ScaleValue(CGB_CAPTION_LEFT)`, `T := (GetCaptionHeight - FCheckBox.Height) div 2`.
3. Right to left: `Anchors := [akTop, akRight]`, `SetBounds(Width - Off - FCheckBox.Width, T, ...)`.
4. Left to right: `Anchors := [akTop]`, `SetBounds(Off, T, ...)`.

Anchors is set to something other than `[akLeft, akTop]` to exclude the check box from the rearrangement by `ChildSizing.Layout` (LCL rearranges only controls with `Align = alNone` and `Anchors = [akLeft, akTop]`).

Called from: `Create`, `RealSetText`, `FontChanged` (after `inherited`), `Resize` (after `inherited`; in right-to-left it is repositioned when the width changes), `CheckBoxResize` (followed by `ReAlign` and `Invalidate`), `Loaded`.

### 4.7 Checked

`SetChecked(v)`:

1. If the value is the same, finish.
2. `FChecked := v`, `SyncCheckBox`, `UpdateInnerEnabled`.
3. If not `csLoading`, `DoChange`.

| Procedure | Processing |
|---|---|
| `SyncCheckBox` | `FCheckBox.Checked := FChecked` while `FSyncing := True` (so `CheckBoxChange` does not go back to `SetChecked`) |
| `CheckBoxChange` | If `FSyncing`, finish. Otherwise `SetChecked(FCheckBox.Checked)` (when pressed on screen) |
| `DoChange` | Calls `FOnChange` if assigned |

### 4.8 Clicking the Caption Text

- `MouseDown`: after `inherited`, `FDownInText := (Button = mbLeft) and PtInRect(CaptionTextRect, Point(X, Y))`.
- `MouseUp`: after `inherited`, `Hit := FDownInText and (Button = mbLeft) and PtInRect(CaptionTextRect, Point(X, Y))`, `FDownInText := False`. Finish if any of the following holds: `Hit` is false, `FCheckBox` is nil, not `IsEnabled`, or at design time. Otherwise `FCheckBox.Checked := not FCheckBox.Checked` (via `CheckBoxChange`, `Checked`, `OnChange` and enabling/disabling of the inner controls are handled), and `SetFocus` if `CanFocus`.

### 4.9 Enabling and Disabling Inner Controls

`UpdateInnerEnabled`:

1. If `ComponentState` contains any of `csLoading`, `csDesigning`, `csDestroying`, do nothing (while loading, it is done in `Loaded`. At design time, so that `Enabled = False` does not remain in the .lfm).
2. `NeedDisable := not (Enabled and FChecked)`.
3. `NeedDisable` and `FInnerDisabled` is `False`: `FInnerDisabled := True`, `DisableTree(Self)`.
4. Not `NeedDisable` and `FInnerDisabled` is `True`: `RestoreAll`, `FInnerDisabled := False`.

| Procedure | Processing |
|---|---|
| `DisableTree(P)` | Goes through `P.Controls` in order. Skips `FCheckBox`. `DisableOne(C)`. If `C` is a `TWinControl`, is not a `TCCheckGroupBox`, and has `csAcceptsControls` (a container), recurse into it with `DisableTree(C)`. A TCCheckGroupBox is not recursed into because it handles its inside through changes of its own Enabled. A control that is not a container (a composite control) is handled as that control only |
| `DisableOne(C)` | If `IsSaved(C)`, finish. If `FSaved` is too small, `SetLength(FSaved, FSavedCount * 2 + 8)`. Records `C` and `C.Enabled`, `C.FreeNotification(Self)`, `C.Enabled := False` |
| `IsSaved(C)` | `True` if `C` is in the record |
| `RestoreAll` | Goes through the record from the back (inner controls first); if `Control` is not nil, restores `Enabled` and calls `RemoveFreeNotification(Self)`. Finally `FSavedCount := 0`, `SetLength(FSaved, 0)` |
| `CMCheckEnabledChanged` | After `inherited`, `FCheckBox.Enabled := Enabled`, `UpdateInnerEnabled` |
| `CMCheckControlChange` | After `inherited`, if `FInnerDisabled` and `Message.LParam <> 0` (added), then `C := TControl(Message.WParam)`; if it is not `FCheckBox`, `DisableOne(C)` (only controls added directly) |
| `Notification` | On `opRemove`, if `AComponent = FCheckBox`, `FCheckBox := nil`. Sets to nil the records whose `Control = AComponent` |

- Even if the application changes the `Enabled` of an inner control while it is disabled, it returns to the recorded value at `RestoreAll` (User Manual 5.4).

### 4.10 Saving and Loading

- `GetChildren`: passes to `Proc` only those of `Controls` that are not `FCheckBox` and whose `Owner = Root`. Even when the component itself is used as the starting point of a stream, the check box is not written.
- `Loaded`: after `inherited`, `SyncCheckBox`, `UpdateCheckBoxBounds`, `UpdateInnerEnabled` (synchronized after all child controls have been loaded).

## 5. Where to Look When Investigating Defects

| Symptom | Where to look |
|---|---|
| The caption position or the gap in the frame is off | `GetCaptionLeft`, `GetCaptionGapWidth`, `CaptionTextRect`, `ScaleValue` (3.4, 4.5) |
| The caption color is wrong in dark display | The branch between 3 and 4 in `DrawCaptionText` (is `Font.Color = clDefault`?) (3.7) |
| Inner controls overlap the caption | `AdjustClientRect` (3.5), `GetCaptionHeight` |
| The check box moves because of ChildSizing | Anchors in `UpdateCheckBoxBounds` (4.6) |
| Inner controls are not restored even after checking | `RestoreAll`, whether a record was set to nil in `Notification` (4.9) |
| `Enabled = False` remains in the .lfm at design time | Step 1 of `UpdateInnerEnabled` (4.9) |
| The check box is written to the .lfm | `GetChildren` (4.10) |
