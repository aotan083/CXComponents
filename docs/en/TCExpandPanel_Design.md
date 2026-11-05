# TCExpandPanel Design Document

Author: aotan083
Date: 2026-11-05
Version: 1.0

---

## 1. Purpose

Build a VS Code Explorer-style "collapsible panel with a title bar" as two components.

- **TCRollout**: a single collapsible panel. It has a title bar (arrow, Caption, buttons on the right) and a body (an area where components can be placed). It can also be used on its own.
- **TCExpandPanel**: a container that lines up several TCRollout panels. Panels are added with `AddPanel`. The open panels share the remaining space.

```pascal
CExpandPanel1.AddPanel(CRollout1);
CExpandPanel1.AddPanel(CRollout2);
```

- TCRollout draws its own title bar. The buttons on the right are registered in `Buttons` (no components are placed).
- If a button has a `DropDownMenu` (TPopupMenu), that menu is shown when the button is pressed.
- The direction of expansion (Top / Bottom / Left / Right) is decided by the `HeaderPosition` of TCRollout.
- Opening and closing change the size smoothly (animation; can be switched off).
- Buttons can be shown always, or only while the mouse is over the title bar.
- When the contents of the container overflow, a scroll bar appears and the contents can be scrolled (can be switched off).
- Only system colors are used (dark/light is left to the application side, e.g. MetaDarkStyle).

### 1.1 Not Included in This Version

- Dragging the border between panels inside the container to change their sizes (a container splitter). Sizes are decided by `ExpandedSize` and `Fill`. When a single TCRollout is placed with `Align = alTop` or similar, the standard TSplitter can be used.

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCExpandPanel.pas` | cx (runtime) | Types, `TCRolloutButton`, `TCRolloutButtons`, `TCRollout`, `TCExpandPanel` |
| `uCExpandPanelReg.pas` (`source\design`) | cxdsgn (design time) | Registration on the [CX] palette, component editor `TCExpandPanelEditor` |
| `cexpandpanel_icon.lrs` | cxdsgn (design time) | Icons (`TCExpandPanel` and `TCRollout`, each with `_150` and `_200`). Included with `{$I cexpandpanel_icon.lrs}` in the initialization of `uCExpandPanelReg` |

- `uCExpandPanel` uses: `Classes, SysUtils, Types, LCLType, LCLIntf, LMessages, Controls, Graphics, GraphType, Forms, Menus, ImgList, ExtCtrls, uCXLang` (`ExtCtrls` is for the `TTimer` of the animation)
- `uCExpandPanel` initialization: `RegisterClass(TCRollout)` (so that it can be loaded from .lfm).
- `uCExpandPanelReg` uses: `Classes, SysUtils, LResources, ComponentEditors, PropEdits, uCExpandPanel`
- Package updates: add `uCExpandPanel` to `cx.lpk` and `uCExpandPanelReg` to `cxdsgn.lpk` (the uses and the registration in `cx.pas` and `cxdsgn.pas` are updated in the same way).
- Messages are shown in Japanese or English through `CXT` of `uCXLang`. One string is added: `sEpErrChild` (when something other than a TCRollout is put into a TCExpandPanel). Ja `TCExpandPanel には TCRollout だけを入れられます` / En `Only a TCRollout can be placed on a TCExpandPanel` (added next to the group "H. TCPageControl, TCSideBar, TCTitleBar" in `uCXLang`).

## 3. Types and Constants

```pascal
TCRolloutHeaderPosition = (hpTop, hpBottom, hpLeft, hpRight);
TCExpandOrientation = (eoVertical, eoHorizontal);
TCRolloutButtonsShow = (bsAlways, bsHover);   // show buttons always / only while the mouse is over the title bar
TCRolloutButtonEvent = procedure(Sender: TObject; Index: Integer) of object;
TCRolloutExpandingEvent = procedure(Sender: TObject; var Allow: Boolean) of object;
```

Sizes at 100% (in the implementation; scaled with `Scale96ToFont` each time they are used):

| Name | Value | Description |
|---|---|---|
| `cButtonInset96` | 2 | Margin between the button frame and the highlight |
| `cButtonGap96` | 2 | Gap between buttons |
| `cEdgePad96` | 4 | Margin at the edge of the title bar |
| `cTextPad96` | 6 | Gap between the arrow/buttons and the text |
| `cArrowSize96` | 8 | Size of the arrow |
| `cButtonRadius96` | 4 | Corner radius of the highlight |
| `cFillMin96` | 60 | Minimum size of the body of a `Fill` panel (it does not get smaller than this; if there is not enough room, the container scrolls) |
| `cScrollLine96` | 24 | One scroll line (the amount for an arrow click; one mouse-wheel notch is 3 lines) |

The animation interval is the constant `cAnimInterval = 15` (milliseconds).

## 4. TCRolloutButton and TCRolloutButtons

### 4.1 TCRolloutButton (`TCollectionItem`)

| Property | Type | Default | Description |
|---|---|---|---|
| `ImageIndex` | `TImageIndex` | -1 | Number in `Rollout.Images`. If -1, nothing is drawn (the frame remains and can be pressed) |
| `Hint` | `string` | '' | Hint text |
| `DropDownMenu` | `TPopupMenu` | nil | Menu shown when the button is pressed |
| `Enabled` | `Boolean` | True | If False, the icon turns gray and the button cannot be pressed |
| `Visible` | `Boolean` | True | If False, the button is not shown (the following buttons move up) |

- `GetDisplayName`: `Hint` if it is not empty, otherwise `Button <Index>` (the text shown in the collection editor).
- Every property calls `Changed(False)` when it changes. `SetDropDownMenu` calls `Rollout.FreeNotification` if there is a new menu (`Rollout` is `Collection.Owner`).

### 4.2 TCRolloutButtons (`TOwnedCollection`)

- `Create(AOwner: TPersistent)` is `inherited Create(AOwner, TCRolloutButton)`. `Owner` is the TCRollout.
- `Items[Index]: TCRolloutButton` is exposed.
- `Update(Item)` calls `Rollout.ButtonsChanged` (redraw; the text range of the title bar changes).

## 5. TCRollout

### 5.1 Declaration

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
  FOpenT: Double;          // how open (0 = closed, 1 = open). An intermediate value during the animation
  FAnimTimer: TTimer;      // for the animation (created when needed)
  FAnimStart: QWord;       // time the animation started (GetTickCount64)
  FAnimFrom: Double;       // FOpenT when the animation started
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

- `Fill`: inside a container, when open, the panel fills the remaining space (6.3). It has no effect on a single panel.
- `ExpandedSize`: the size in the direction of expansion when open (height for `hpTop`/`hpBottom`, width for `hpLeft`/`hpRight`). It never becomes smaller than `HeaderSize`.
- `HeaderSize`: the thickness of the title bar (height for `hpTop`/`hpBottom`, width for `hpLeft`/`hpRight`). The default is 24.
- `ImagesWidth`: the width at which icons are drawn (px at 100%). If 0, `Images.Width`.
- `ButtonsShow`: `bsAlways` always shows the buttons. `bsHover` shows them only while the mouse is over the title bar (always shown at design time; also kept shown while a `DropDownMenu` is open). The place of the buttons is kept free even when they are not shown (so that the text does not move).
- `Animated`: if `True`, the size changes little by little when opening or closing. At design time and while the .lfm is being loaded, the size always changes immediately.
- `AnimationTime`: the time taken to open or close (milliseconds; default 150). If 0 or less, there is no animation.

### 5.2 Create and Destroy

Create:

1. `FExpanded := True`, `FHeaderPosition := hpTop`, `FHeaderSize := 24`, `FExpandedSize := 150`, `FFill := False`, `FShowArrow := True`, `FImagesWidth := 0`.
2. Create `FImageChangeLink` and set `OnChange := ImageListChange`. `FButtons := TCRolloutButtons.Create(Self)`.
3. `ControlStyle := ControlStyle + [csAcceptsControls, csCaptureMouse, csClickEvents]` (components can be placed in the body).
4. `Color := clBtnFace`, `ParentColor := False`, `Caption := ''`, `Width := 200`, `Height := 150`, `Align := alNone`.
5. `FButtonsShow := bsAlways`, `FAnimated := True`, `FAnimationTime := 150`, `FOpenT := 1`, `FAnimTimer := nil`.
6. Initialize the title bar state (`FHotHeader := False`, `FHotButton := -1`, `FDownButton := -1`, `FDownHeader := False`, `FMenuOpen := False`).

Destroy: stop and free `FAnimTimer`, then free `FButtons` and `FImageChangeLink` (after `inherited`).

### 5.3 Effective Direction and Size

| Routine | Processing |
|---|---|
| `EffectivePosition` | Inside a container (`ExpandPanel <> nil`): if the container is vertical (`eoVertical`) and `HeaderPosition` is `hpLeft` or `hpRight`, then `hpTop`; if the container is horizontal and `HeaderPosition` is `hpTop` or `hpBottom`, then `hpLeft`. Otherwise `HeaderPosition`. The value of `HeaderPosition` is not changed |
| `IsVerticalHeader` | `EffectivePosition` is `hpLeft` or `hpRight` |
| `HeaderThickness` | `FHeaderSize` as it is (scaling by display scale is done by enlarging the value directly in `DoAutoAdjustLayout`) |
| `AxisSize` | `Width` if `IsVerticalHeader`, otherwise `Height` |
| `LayoutSize(Full)` | The current size for the open size `Full`: `HeaderThickness + Round((Full - HeaderThickness) * FOpenT)` (`HeaderThickness` if `Full` is not larger than `HeaderThickness`) |
| `CurrentSize` | `LayoutSize(FExpandedSize)` |
| `OpenTarget` | 1 if `Expanded`, 0 if closed |
| `HeaderRect` | `hpTop`: `(0, 0, ClientWidth, HeaderThickness)`, `hpBottom`: `(0, Height - HeaderThickness, Width, Height)`, `hpLeft`: `(0, 0, HeaderThickness, Height)`, `hpRight`: `(Width - HeaderThickness, 0, Width, Height)` (`Width` and `Height` are the control's own size) |

### 5.4 Opening and Closing

Writing `Expanded` (`SetExpanded(v)`):

1. If it is the same, finish. While `csLoading`, only set `FExpanded := v` and `FOpenT := OpenTarget`, then finish (the size is decided in `Loaded`).
2. At run time (not design time), if there is an `OnExpanding`, call it with `Allow := True`. If `Allow = False`, finish.
3. `FExpanded := v`. Move `FOpenT` with `StartOpen` (below). Inside a container, call `ExpandPanel.RolloutToggled(Self)` (processing for `Multiple = False`; 6.4).
4. `Invalidate`. At run time, raise `OnExpand` when opened and `OnCollapse` when closed (raised at the start of the animation; it does not wait for the end).
5. A change made by clicking the header at design time calls `OwnerFormDesignerModified(Self)` (7.4).

Animation:

| Routine | Processing |
|---|---|
| `StartOpen` | The target is `OpenTarget`. If `FOpenT` equals the target, do nothing. If any of the following applies: `Animated = False`, `AnimationTime <= 0`, design time, `csLoading`/`csDestroying`, no `HandleAllocated`, not `Visible`; then set `FOpenT := target`, call `OpenChanged` and finish. Otherwise `FAnimFrom := FOpenT`, `FAnimStart := GetTickCount64`, and set `FAnimTimer` (created with `Interval := cAnimInterval` and `OnTimer := AnimTimerTick` if it does not exist) to `Enabled := True` |
| `AnimTimerTick` | `Elapsed := GetTickCount64 - FAnimStart`, `Prog := Min(1, Elapsed / FAnimationTime)`. To make the motion smooth, `E := Prog * Prog * (3 - 2 * Prog)`. `FOpenT := FAnimFrom + (target - FAnimFrom) * E`. If `Prog >= 1`, set `FOpenT := target` and `FAnimTimer.Enabled := False`. `OpenChanged` every time |
| `OpenChanged` | Inside a container, `ExpandPanel.LayoutChanged`; for a single panel, `ApplyOwnSize`. `Invalidate` |
| Switching back in the middle | `StartOpen` takes `FAnimFrom` again from the current `FOpenT`, so the motion changes direction from where it is |

- While `FOpenT` is moving (while `FAnimTimer` is running), `SetBounds` does not rewrite `ExpandedSize` (see `SetBounds` below).

`ApplyOwnSize` (for a single panel): set `FSizing := True` and make the size in the direction of expansion equal to `CurrentSize` (with `SetBounds`; for `hpBottom` and `hpRight`, `Top` and `Left` are also shifted so that the opposite side does not move; when `Align` is `alTop` or similar, leave it to Align). Then `FSizing := False`.

Size management:

| Routine | Processing |
|---|---|
| `SetBounds` | Before `inherited`, unless any of `FSizing`, `FManaged` (the container is laying it out), `csLoading`, or animation in progress (`FAnimTimer` is running) applies, do the following. If open, `FExpandedSize := Max(new size on the axis, HeaderThickness)` (remember the size when the user changes it). If closed, correct the size in the direction of expansion to `HeaderThickness` |
| `SetBoundsManaged(L, T, W, H)` | Called by the container. `SetBounds` with `FManaged := True`, then `FManaged := False`. It does not change `ExpandedSize` |
| `SetButtonsShow` | If changed, store it and `Invalidate` (the place is kept free even when buttons are hidden, so the layout does not change) |
| `SetAnimationTime` | If negative, make it 0 and store it |
| `Loaded` | After `inherited`, `FOpenT := OpenTarget`. Outside a container, `ApplyOwnSize`. Inside a container, `ExpandPanel.LayoutChanged` |
| `SetHeaderPosition` | If changed, store it; outside a container, `ApplyOwnSize`. `LayoutChanged` (the layout of the container if there is one, otherwise `Invalidate` and `Realign`) |
| `SetHeaderSize` | If negative, 0. If changed, store it, then `ApplyOwnSize` or the container's `LayoutChanged` |
| `SetExpandedSize` | If smaller than `HeaderSize`, `HeaderSize`. If changed, store it; if open, `ApplyOwnSize` or the container's `LayoutChanged` |
| `SetFill` | If changed, store it and call the container's `LayoutChanged` |
| `SetShowArrow` | If changed, store it and `Invalidate` |
| `SetImages` | From the old one, `UnRegisterChanges` and `RemoveFreeNotification`. For the new one, `FreeNotification` and `RegisterChanges`. `Invalidate` |
| `SetImagesWidth` | If negative, 0. If changed, store it and `Invalidate` |
| `SetButtons` | `FButtons.Assign(v)` |
| `ImageListChange`, `ButtonsChanged` | `Invalidate` |
| `Notification` | On `opRemove`, if it is `FImages`, set it to nil and `Invalidate`. On `opRemove`, if a button's `DropDownMenu` is the same component, set it to nil |
| `TextChanged` | After `inherited`, `Invalidate` |
| `DoAutoAdjustLayout` | After `inherited`, if `AMode` is `lapAutoAdjustWithoutHorizontalScrolling` or `lapAutoAdjustForDPI`, `FHeaderSize := Round(FHeaderSize * proportion of the axis)` (`AYProportion` for `hpTop`/`hpBottom`, `AXProportion` for `hpLeft`/`hpRight`). `FExpandedSize` is scaled by the same proportion |

### 5.5 Body Area

`AdjustClientRect` is overridden. After `inherited`, the part used by the title bar is removed.

| Effective direction | Processing |
|---|---|
| `hpTop` | `Top += HeaderThickness` |
| `hpBottom` | `Bottom -= HeaderThickness` |
| `hpLeft` | `Left += HeaderThickness` |
| `hpRight` | `Right -= HeaderThickness` |

The right is never smaller than the left, and the bottom is never smaller than the top. When closed, the body area is 0, and components placed in it are cut off and not visible.

### 5.6 Position of Title Bar Elements

| Routine | Processing |
|---|---|
| `ButtonSize` | `HeaderThickness - 2 * Scale96ToFont(cButtonInset96)` (0 if negative). A square |
| `ButtonRect(Index)` | Empty if `Buttons.Items[Index].Visible` is not True. Horizontal title bar (`hpTop`/`hpBottom`): starting `Scale96ToFont(cEdgePad96)` inside the right edge of the title bar, the visible buttons are lined up from the right as `ButtonSize` squares (gap `cButtonGap96`). The smaller number is on the left. Centered vertically. Vertical title bar (`hpLeft`/`hpRight`): the visible buttons are lined up from the top, starting below the arrow (or `cEdgePad96` from the top edge if there is no arrow). Centered horizontally |
| `ButtonsShown` | Whether buttons are drawn and can be pressed. `True` if any of the following: design time, `bsAlways`, `FHotHeader`, `FMenuOpen`, `FDownButton >= 0`. Otherwise (`bsHover` and the mouse is not over it) `False` |
| `ButtonAt(X, Y)` | -1 if not `ButtonsShown`. Otherwise the number of the first button whose `ButtonRect` contains the point (-1 if none) |
| `TextRect` | The text range in the title bar, excluding the arrow and buttons. Horizontal title bar: the left is to the right of the arrow (`cTextPad96`), the right is the left of the leftmost button minus `cTextPad96`. Vertical title bar: the top is below the lowest button plus `cTextPad96`, the bottom is the edge minus `cEdgePad96` (the text of `hpLeft` reads from bottom to top, that of `hpRight` from top to bottom) |
| `ArrowRect` | Empty if `ShowArrow = False`. Horizontal title bar: `cEdgePad96` from the left edge, a `cArrowSize96` square centered vertically. Vertical title bar: `cEdgePad96` from the top edge, a square centered horizontally |

## 6. TCExpandPanel

### 6.1 Declaration

```pascal
TCExpandPanel = class(TCustomControl)
private
  FPanels: TFPList;
  FOrientation: TCExpandOrientation;
  FMultiple: Boolean;
  FSpacing: Integer;
  FScrollable: Boolean;
  FScrollPos: Integer;     // scroll position (on the axis; 0 or more)
  FContentLength: Integer; // length of all panels lined up (the total in 6.3)
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

- `Scrollable`: if `True`, when the length of the lined-up panels is longer than the container, a scroll bar (vertical for a vertical container, horizontal for a horizontal one) appears and the contents can be scrolled. If `False`, the overflowing part is cut off.

### 6.2 List of Panels

| Routine | Processing |
|---|---|
| `AddPanel(R)` | `EArgumentException` if `R` is nil. If already in the list, finish. `R.Parent := Self` (this goes through `SetParent`, `AddRollout` of 6.5 is called, and the panel is put at the end) |
| `InsertPanel(i, R)` | After `AddPanel(R)`, if `i` is within range, `MovePanel(last, i)` |
| `RemovePanel(R)` | If in the list, `R.Parent := nil` (`RemoveRollout` is called). `R` is not freed |
| `MovePanel(Cur, New)` | If either is out of range or they are the same, do nothing. `NewControlIndex := GetControlIndex(FPanels[New])`, `FPanels.Move(Cur, New)`, `SetControlIndex(R, NewControlIndex)`, `LayoutChanged`. The order of `FPanels` and the order of the children (the order saved in .lfm) are kept the same |
| `GetPanel(i)` | `FPanels[i]` (out of range gives `EListError`) |
| `GetPanelCount` | `FPanels.Count` |
| `IndexOfPanel(R)` | `FPanels.IndexOf(R)` (-1 if not found). Used by the design-time component editor (chapter 8) to know the number of the selected TCRollout |
| `AddRollout(R)` | If already in the list, finish. `FPanels.Add(R)`, `R.Align := alNone`. `LayoutChanged` |
| `RemoveRollout(R)` | Remove it from the list and `LayoutChanged` (do nothing while being destroyed) |
| `InsertControl(AControl, Index)` | If `AControl` is not a `TCRollout`, `EInvalidOperation(CXT(sEpErrChild))`. Otherwise `inherited` |

### 6.3 Layout (overrides `AlignControls`)

`inherited` is not called. All panels are placed with the following procedure. The axis is `Orientation` (height for vertical, width for horizontal; called the "axis" below).

1. Collect the shown (`Visible`) panels in the order of `FPanels`. If there are none, finish.
2. The axis length `L` = the length of the client area along the axis.
3. For panels that are not `Fill`, the size along the axis `S(i)` = `LayoutSize(ExpandedSize)` (an intermediate size during the animation).
4. For `Fill` panels (`F` of them): those that are open or animating (`Expanded` or `FOpenT > 0`) are `k` in number. The remainder for the bodies is `P := L - Σ S(i) - Σ (HeaderSize of the Fill panels) - Spacing * (n - 1)` (`n` is the number of shown panels). If `k > 0`, the body size is `B := Max(P div k, Scale96ToFont(cFillMin96))`. The size of a `Fill` panel is `HeaderSize + Round(B * FOpenT)` (`HeaderSize` for those not counted in `k`). If `k = 0`, the remainder stays empty (the background shows).
5. Store the total `C := Σ (sizes of all panels) + Spacing * (n - 1)` in `FContentLength`.
6. Scrolling (6.6): if `Scrollable` and `C > L`, show the scroll bar and keep `FScrollPos` within `0 .. C - L`; otherwise hide the bar and set `FScrollPos := 0`.
7. Place the panels in the order of `FPanels`, from the start of the axis (`-FScrollPos`), with `Spacing` between them. Positions are stacked along the axis; across the axis, they run from 0 and fill the width (height) of the client area of the container (excluding the scroll bar). `SetBoundsManaged` is used.
8. If `Scrollable = False` and the total exceeds `L`, the overflowing part is cut off.

`LayoutChanged`: do nothing while being destroyed or while `csLoading`. `InvalidatePreferredSize`, `ReAlign`, `Invalidate`.

### 6.4 Linked Opening and Closing

`RolloutToggled(R)`:

1. If `R` was opened and `Multiple = False`, close the other open panels (`Expanded := False`; their events are also raised).
2. `LayoutChanged`.

### 6.5 Others

| Routine | Processing |
|---|---|
| `SetOrientation` | If changed, store it and `LayoutChanged`. The panels are redrawn with `EffectivePosition` |
| `SetMultiple` | If changed, store it. When set to `False` and two or more panels are open, close all but the first open one (events are raised) |
| `SetSpacing` | If negative, 0. If changed, store it and `LayoutChanged` |
| `SetScrollable` | If changed, store it and `LayoutChanged` (if `False`, hide the bar and `FScrollPos := 0`) |
| `DoAutoAdjustLayout` | After `inherited`, if `AMode` is `lapAutoAdjustWithoutHorizontalScrolling` or `lapAutoAdjustForDPI`, `FSpacing := Round(FSpacing * proportion)` (the proportion of the axis direction) |
| `Destroy` | After `inherited Destroy`, free `FPanels` (`RemoveRollout` is called by `SetParent(nil)` of each child) |

### 6.6 Scrolling

The standard Windows scroll bar is used (`ShowScrollBar`, `SetScrollInfo`, `GetScrollInfo`; Windows 11 only). `SB_VERT` if the axis is vertical, `SB_HORZ` if horizontal.

| Routine | Processing |
|---|---|
| `UpdateScrollBar(L, C)` | If `Scrollable` and `C > L`, call `SetScrollInfo` (`nMin = 0`, `nMax = C - 1`, `nPage = L`, `nPos = FScrollPos`) and show the bar. Otherwise hide the bar. Showing or hiding with `ShowScrollBar` changes the size of the client area across the axis (the thickness of the bar), but `L` along the axis does not change, so the layout is not redone |
| `ScrollTo(Pos)` | Keep `Pos` within `0 .. Max(0, FContentLength - L)`. If it is the same, finish. `FScrollPos := Pos`, update the bar position, and shift each panel (along the axis) (the layout is redone from the beginning) |
| `WMVScroll`, `WMHScroll` | Handle only the one matching the axis. `SB_LINEUP`/`SB_LINEDOWN`: by `Scale96ToFont(cScrollLine96)`; `SB_PAGEUP`/`SB_PAGEDOWN`: by `L` (`L` is the current length of the axis); `SB_TOP`/`SB_BOTTOM`: to the end; `SB_THUMBTRACK`/`SB_THUMBPOSITION`: to `nTrackPos` of `GetScrollInfo` (`SIF_TRACKPOS`). Call `ScrollTo` |
| `DoMouseWheel` (`MouseWheel`) | When `Scrollable` and the scroll bar is shown, `ScrollTo` by `Scale96ToFont(cScrollLine96) * 3` with the wheel for a vertical container, or Shift + wheel for a horizontal container. When handled, `Handled := True`. A component on a panel (such as a TMemo) receives the wheel first, so the wheel over such a component does not scroll |
| `Resize`, opening/closing a panel | Redo the layout of 6.3 and `UpdateScrollBar` through `LayoutChanged` |
| A panel opens (when the last panel grows and goes out of view) | The layout of 6.3 is redone every time during the open/close animation, so if `FScrollPos` exceeds `FContentLength - L`, it is brought back in (so that no blank is visible when closing) |

`TCRollout.SetParent(NewParent)`: if it is the same, finish. If the previous parent is a `TCExpandPanel`, `RemoveRollout(Self)`. `inherited SetParent`. If the new parent is a `TCExpandPanel`, `AddRollout(Self)`. `TCRollout.GetExpandPanel`: the `Parent` if it is a `TCExpandPanel`, otherwise nil.

## 7. Painting and Mouse of TCRollout

### 7.1 Painting (`Paint`)

1. Fill the body area with `Color`.
2. Fill `HeaderRect` with `clBtnFace`.
3. When open, draw a 1px line of `clBtnShadow` on the side of the title bar facing the body.
4. Arrow (`ArrowRect`): draw a chevron (`>`) with two lines of `clBtnText`, thickness `Scale96ToFont(1)` (at least 1). The direction is given in the following table.

| Effective direction | Open | Closed |
|---|---|---|
| `hpTop` | Down (`∨`) | Right (`>`) |
| `hpBottom` | Up (`∧`) | Right (`>`) |
| `hpLeft` | Right (`>`) | Down (`∨`) |
| `hpRight` | Left (`<`) | Down (`∨`) |

5. Text (`TextRect`): `Font`, `clBtnText`, vertically centered, single line, trailing "…", clipped when it overflows. For `hpLeft`, `Font.Orientation := 900`; for `hpRight`, `2700`; and `TextRect` is used as the clip range (`ClipRect`) for drawing.
6. Buttons: drawn only when `ButtonsShown`. For each visible (`Visible`) button, using `ButtonRect` as the frame: if the mouse is over it (`FHotButton`) and the button is `Enabled`, fill with `clBtnHighlight` with rounded corners (`cButtonRadius96`). While it is pressed, fill with `clBtnShadow`. If `ImageIndex` is in range, draw the icon at the center of the frame (`Res := Images.ResolutionForPPI[FImagesWidth, Font.PixelsPerInch, 1]`. If the button is not `Enabled` or the TCRollout is not `Enabled`, draw the gray image from `Res.GetBitmap(ImageIndex, Bmp, gdeDisabled)` with `Canvas.Draw`).

### 7.2 Mouse

- `MouseDown`: after `inherited`, for the left button inside the title bar: if over a button, `FDownButton := its number`; otherwise `FDownHeader := True`.
- `MouseMove`: after `inherited`, `SetHeaderHot(whether inside the title bar)` and `SetHot(ButtonAt(X, Y))`.
- `MouseUp`: after `inherited`, finish if it is not the left button. If there is a `FDownButton`, and the release point is over the same button, the button is `Enabled` and the TCRollout is `Enabled`, `ClickButton(number)`. If `FDownHeader` is set and the release point is also inside the title bar (outside the buttons), `Expanded := not Expanded` (only when `Enabled`; always at design time).
- `MouseLeave`: after `inherited`, `SetHeaderHot(False)` and `SetHot(-1)`.
- `SetHot(i)`: if the same, finish. When moving to another button, `Application.CancelHint`. Store it and `Invalidate`.
- `SetHeaderHot(b)`: if the same, finish. Store it, and if `ButtonsShow = bsHover`, `Invalidate` (show or hide the buttons). Nothing for `bsAlways`.
- Mouse movement inside the title bar is received by `MouseMove` even while the buttons are not shown (`bsHover`). When the title bar is clicked while the buttons are hidden, it is treated as a click on the title bar (open/close), not on a button (because `ButtonAt` returns -1).

### 7.3 When a Button Is Pressed (`ClickButton(i)`)

1. At design time, do nothing.
2. If there is an `OnButtonClick`, call `OnButtonClick(Self, i)`.
3. If `Buttons.Items[i].DropDownMenu` exists, set `PopupComponent := Self` and call `Popup` at the screen coordinates of the button: the lower left of the button for a horizontal title bar, the upper right for a vertical one. `FMenuOpen := True` (the buttons stay shown while the menu is open). When `Popup` returns (the menu has closed), `FMenuOpen := False`, re-obtain `FHotHeader` from the current mouse position, and `Invalidate`.

### 7.4 Design Time

- Clicking the title bar opens or closes the panel, and `OwnerFormDesignerModified(Self)` is called. Pressing a button does nothing.
- `CMDesignHitTest`: the same idea as 7.5 of the TCSideBar design document: 1 inside the title bar (including the buttons), 0 elsewhere (the body is handled by the designer). `FDesignerPressLeft` is handled in the same way.

### 7.5 Hint (`CMHintShow`)

After `inherited`, if the button under the mouse has a `Hint`, `HintStr := Hint` and `CursorRect := ButtonRect(number)`. When the mouse is not over a button, the normal hint (`Hint`) is used.

## 8. Design Time (uCExpandPanelReg)

`Register`:

1. `RegisterComponents('CX', [TCExpandPanel, TCRollout])` (TCRollout is also placed alone, so it is shown on the palette).
2. `RegisterComponentEditor(TCExpandPanel, TCExpandPanelEditor)` and `RegisterComponentEditor(TCRollout, TCExpandPanelEditor)`.

`TCExpandPanelEditor = class(TComponentEditor)`: the container to operate on is the `ExpandPanel` of the selected component if it is a `TCRollout` (do nothing if there is none), or the component itself if it is a `TCExpandPanel`.

| No. | Text | Processing |
|---|---|---|
| 0 | Add Panel | Create a `TCRollout` (the Owner is the Owner of the container). `Name := GetDesigner.CreateUniqueComponentName(ClassName)`, `Caption := Name`, `AddPanel`, `Hook.PersistentAdded(new one, True)`, `Modified` |
| 1 | Delete Panel | When the selected component is a TCRollout inside a container, `Hook.DeletePersistent`. Otherwise nothing |
| 2 | Move Up | If the number `Cur` of the selected TCRollout is 1 or more, `MovePanel(Cur, Cur - 1)` and `Modified` |
| 3 | Move Down | The same, with `Cur + 1` |

`GetVerbCount` is 4. The texts are resourcestrings (`rsCExpandPanelAdd` etc.; the texts in the IDE are always Japanese).

## 9. Points to Check When Investigating a Defect

| Symptom | Where to look |
|---|---|
| The size does not return when closing / does not return to the original size when opening | `SetBounds` and `ApplyOwnSize` (5.4), `FManaged`, whether `ExpandedSize` was rewritten during the animation |
| The open/close motion is jerky or stops | `StartOpen` and `AnimTimerTick` (5.4), `AnimationTime`, `Animated` |
| Buttons do not appear / do not disappear | `ButtonsShown` (5.6), `ButtonsShow`, `FHotHeader` (7.2) |
| The scroll bar does not appear / the position returns | `UpdateScrollBar` and `ScrollTo` (6.6), `Scrollable`, `FContentLength` (6.3, steps 5 and 6) |
| An open panel in a container does not fill the remainder | `Fill`, 6.3, steps 3 and 4 |
| `hpLeft` is not horizontal in a vertical container | `EffectivePosition` (5.3) |
| The [...] menu does not appear | `ClickButton` (7.3), `DropDownMenu`, `Notification` |
| A component placed at design time does not enter the panel | `csAcceptsControls` (5.2), `AdjustClientRect` (5.5) |
| The order of panels differs from the .lfm | `SetControlIndex` in `MovePanel` (6.2) |
| The thickness of the title bar is off with the display scale | `DoAutoAdjustLayout` (5.4 and 6.5) |
