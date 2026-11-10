# TCPairSplitter Design Document

Author: aotan083
Date: 2026-11-08
Version: 1.0

---

## 1. Purpose and Policy

- A component used like TPairSplitter that combines two sides (Side1 and Side2) and the splitter in one.
- Additions: (1) each side can be hidden or shown (hiding one makes the other fill the whole area, and showing it restores both; both cannot be hidden), (2) a blue line on the splitter (the same look as TCSplitter; the color can be changed at design time), (3) dragging at design time.
- On Windows, the standard TPairSplitter uses the common LCL implementation (`WSPairSplitter`): the sides use `Align` and the splitter is an inner `TSplitter`. Because the color of the splitter and the way sides are hidden cannot be changed there, this component does not inherit from `TCustomPairSplitter` and is built from scratch.
- The position and size of the sides are decided by TCPairSplitter with `SetBounds`, without `Align` (so that the spreading and restoring when a side is hidden, and the position of the splitter, are decided by a single calculation).
- The splitter is not a child control: TCPairSplitter itself draws it and receives the mouse (so that dragging at design time works with the mechanism already verified in TCSideBar [CM_DESIGNHITTEST]).

### 1.1 Out of Scope

- More than two sides (place another TCPairSplitter inside a side).
- A method that moves only a line in a separate window during dragging (`ResizeStyle`; TCSideBar has it). While dragging, the size of the sides is changed and redrawn as it moves.
- Compatibility with `TPairSplitterType` of the standard `PairSplitter` unit (to avoid name clashes, the names are `TCPairSplitterType`, `cpsHorizontal`, and `cpsVertical`).

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCSplitter.pas` | cx (runtime) | `TCSplitter` (existing), `TCPairSplitterType`, `TCPairSplitterSide`, `TCPairSplitter`. The initialization of this unit calls `RegisterClass(TCPairSplitterSide)` (to read the sides from .lfm) |
| `uCXReg.pas` (`source\design`) | cxdsgn (design time) | Registration in the palette [CX] (`RegisterComponents('CX', [..., TCPairSplitter, ...])`) and `RegisterNoIcon([TCPairSplitterSide])` |
| `csplitter_icon.lrs` (`source\res`) | cxdsgn (design time) | Icons (`TCSplitter`, `TCSplitter_150`, `TCSplitter_200`, and `TCPairSplitter`, `TCPairSplitter_150`, `TCPairSplitter_200`). `{$I csplitter_icon.lrs}` in the initialization of `uCXReg` |

- uses of `uCSplitter`: `Classes, SysUtils, Types, Math, Controls, ExtCtrls, Graphics, LCLType, LCLIntf, LCLProc, LMessages`.
- There remain two packages, cx and cxdsgn. No `.pas` is added (it goes in the same unit as TCSplitter).

## 3. Types and Declarations

```pascal
type
  TCPairSplitterType = (cpsHorizontal, cpsVertical);

  TCPairSplitterSide = class(TCustomPanel)        { one side }
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
    FPosition: Integer;               { size of side 1. Remembered while a side is hidden }
    FSplitterWidth: Integer;          { thickness of the splitter (value at 96dpi) }
    FHighlightColor: TColor;
    FSplitCursor: TCursor;
    FOnMoved: TNotifyEvent;
    FNoCreateSides: Boolean;
    FHot, FDragging: Boolean;
    FDragStartAxis, FDragStartPos: Integer;
    FLayouting: Boolean;
    FDesignerPressLeft: Boolean;
  public
    property Sides[Index: Integer]: TCPairSplitterSide; { out of range raises EListError }
    property Side1, Side2: TCPairSplitterSide;
  published
    property Align, Anchors, BorderSpacing, Constraints, Enabled, ParentShowHint, PopupMenu, ShowHint, Visible;
    property Color default clBtnFace;
    property SplitterType: TCPairSplitterType default cpsHorizontal;
    property Position: Integer;                       { no default (always saved) }
    property SplitterWidth: Integer default 5;
    property HighlightColor: TColor default clHighlight;
    property SplitCursor: TCursor default crDefault;
    property OnMoved: TNotifyEvent;
    { OnMouse*, OnResize, OnChangeBounds }
  end;
```

| Constant / default | Value | Contents |
|---|---|---|
| `cLineWidth96` (shared with TCSplitter) | 2 | Thickness of the blue line (96dpi) |
| Default size | 90 × 90 | `GetControlClassDefaultSize` (same as TPairSplitter) |
| Default `Position` | 45 | Same as TPairSplitter |
| Default `SplitterWidth` | 5 | Same as the default thickness of TSplitter |

## 4. The Side (TCPairSplitterSide)

| Item | Behavior |
|---|---|
| `Create` | Removes `csSetCaption` from `TCustomPanel` and adds `csAcceptsControls`. `BevelOuter` and `BevelInner` are `bvNone`. `Caption` is empty |
| `SetParent` | If the parent is a `TCPairSplitter`, calls `AddSide` (puts it in the list of sides). Removes it from the old parent with `RemoveSide`. However, while the parent is being destroyed or the designer is deleting (`wcfDesignerDeleting`), it is not put back (same as TPairSplitterSide) |
| `Destroy` | Before `inherited`, calls `RemoveSide(Self)` of the parent `TCPairSplitter` (so that a new side is created again when a side is deleted at design time) |
| `SetVisible(Value)` | (1) When hiding (`Value = False`), if there is a parent, it is not loading, and **the other side is already hidden** (`OtherSideHidden`), it does nothing and returns (both cannot be hidden). (2) `inherited SetVisible`. (3) Calls `ApplyLayout` of the parent (re-arranges). `Show` and `Hide` change `Visible`, so the same rule applies |
| `Paint` | At design time only, a dashed frame (`psDash`, `clGrayText`) |

## 5. The Splitter (TCPairSplitter)

### 5.1 Management of the Sides

| Procedure | Processing |
|---|---|
| `Create` | Removes `csAcceptsControls` and adds `csCaptureMouse` and `csClickEvents`. Sets default values. `Color := clBtnFace`. At run time (not design time), `CreateSides` |
| `CreateWnd` | `CreateSides`, `inherited`, `ApplyLayout` (at design time, the sides are created when the window is created; same as TPairSplitter) |
| `Loaded` | `inherited`, `CreateSides`, `ApplyLayout` |
| `CreateSides` | Does nothing while loading, while being destroyed, or if `FNoCreateSides` is set. If a side is missing, creates `TCPairSplitterSide.Create(Owner)` and sets `Parent := Self` (the Owner of a side is the Owner of the splitter, for saving and loading) |
| `AddSide` | Puts it in a free slot (`FSides[0]`, otherwise `FSides[1]`) and calls `ApplyLayout`. If both are full, `EInvalidOperation` |
| `RemoveSide` | Removes it from the list. At design time (`csDesigning`), if not being destroyed and the designer is not deleting, calls `CreateSides` (creates a new side) |
| `OtherSideHidden(ASide)` | Whether the other side exists and its `Visible` is `False` |
| `ChildClassAllowed` | Only subclasses of `TCPairSplitterSide` |
| `Destroy` | `FNoCreateSides := True`, then `inherited` (no sides are created again while being destroyed) |

### 5.2 Arrangement (`ApplyLayout`)

Does nothing if `FLayouting` (prevents re-entry) is true, the two sides are not both present, or it is loading or being destroyed.

| State | Processing |
|---|---|
| Both visible (side by side) | `P := ClampPos(FPosition)`, `B := BarSize`. Side 1: `SetBounds(0, 0, P, height)`; side 2: `SetBounds(P + B, 0, width − P − B (at least 0), height)` |
| Both visible (top and bottom) | Side 1: `SetBounds(0, 0, width, P)`; side 2: `SetBounds(0, P + B, width, height − P − B (at least 0))` |
| Only side 1 visible | Side 1: `SetBounds(0, 0, width, height)` |
| Only side 2 visible | Side 2: `SetBounds(0, 0, width, height)` |

Finally `Invalidate`. A hidden side is not touched. `FPosition` is not changed while a side is hidden or by re-arrangement (so the original size returns when the side is shown).

Called from: `Resize` (when the size of the whole component changes), `Loaded` and `CreateWnd`, `AddSide`, `SetVisible` of a side, `SetPosition`, `SetSplitterType`, `SetSplitterWidth`, `DoAutoAdjustLayout`, and while dragging.

### 5.3 Range (`ClampPos`, `BarSize`, `BarRect`)

| Function | Processing |
|---|---|
| `Total` | The size of the whole in the split direction (`ClientWidth` if side by side, `ClientHeight` if top and bottom) |
| `BarSize` | `Max(1, Scale96ToFont(FSplitterWidth))` |
| `BarShown` | Whether there are two sides and both are `Visible` |
| `ClampPos(v)` | Lower limit `Min1` = `Max(1, minimum width (height if top and bottom) of the Constraints of side 1)`; the lower limit `Min2` of side 2 is the same. Upper limit `MaxP` = `Total − BarSize − Min2`. Raises `v` to at least `Min1`, then lowers it to at most `MaxP`, and finally makes it at least 0 (the upper limit takes precedence) |
| `BarRect` | Empty unless `BarShown`. Otherwise, from `P := ClampPos(FPosition)`, a strip of `BarSize` (`Rect(P, 0, P + B, height)` if side by side, `Rect(0, P, width, P + B)` if top and bottom) |

### 5.4 Writing Properties

| Property | Processing |
|---|---|
| `Position` | 0 if below 0. Does nothing if the value is the same. Sets `FPosition` and calls `ApplyLayout`. Reading returns `FPosition` (a too-large value is returned as it is) |
| `SplitterType` | Does nothing if the value is the same. Sets it and calls `ApplyLayout` |
| `SplitterWidth` | 1 if below 1. Does nothing if the value is the same. Sets it and calls `ApplyLayout` |
| `HighlightColor` | Does nothing if the value is the same. Sets it and calls `Invalidate` |
| `SplitCursor` | Only sets it (takes effect the next time the mouse moves over the splitter) |

### 5.5 Display Scale (`DoAutoAdjustLayout`)

After `inherited`, for `lapAutoAdjustWithoutHorizontalScrolling` and `lapAutoAdjustForDPI`, `FPosition` becomes `Round(FPosition * AXProportion)` (side by side) or `Round(FPosition * AYProportion)` (top and bottom), according to the split direction, and `ApplyLayout` is called. `FSplitterWidth` is kept as the 96dpi value and enlarged by `BarSize`.

### 5.6 Drawing (`Paint`)

1. Fills the whole with `Color` (the part not covered by the sides, that is, the splitter area, is visible).
2. Finishes if `BarRect` is empty.
3. At run time, if the mouse is over the splitter (`FHot`) or it is being dragged (`FDragging`), paints a line of thickness `Max(1, Scale96ToFont(cLineWidth96))` in `CXSplitLineColor(HighlightColor)` at the center of the splitter (a vertical line if side by side, a horizontal line if top and bottom).
4. Otherwise (normally, and at design time), a 1px `clBtnShadow` line at the center of the splitter.

### 5.7 Mouse

| Procedure | Processing |
|---|---|
| `MouseDown` | With the left button over the splitter (`BarRect`): `FDragging := True`, `MouseCapture := True` (because at design time the designer calls `MouseDown` directly and the mouse is not captured), and remembers the pressed position (on the axis of the split direction) and the `ClampPos(FPosition)` at that time. `Invalidate` |
| `MouseMove` | While dragging, `NewPos := ClampPos(start position + (current position − pressed position))`. If it differs from `FPosition`, `FPosition := NewPos` and `ApplyLayout`. While not dragging, changes `FHot` according to whether the mouse is over the splitter, redraws, and changes the cursor (over it: `SplitCursor`, and with `crDefault` `crHSplit` if side by side or `crVSplit` if top and bottom; otherwise `crDefault`) |
| `MouseUp` | With the left button while dragging, ends the drag (`MouseCapture := False`), checks whether the position differs from the start, and calls `Invalidate`. At design time, if it differs, `OwnerFormDesignerModified(Self)` (to save `Position` in .lfm), and `FDesignerPressLeft := True`. At run time, if it differs, `OnMoved` |
| `MouseLeave` | If not dragging, `FHot := False`, returns the cursor to `crDefault`, and redraws |
| `CaptureChanged` | If the capture is lost while dragging and the left button is still pressed (Alt+Tab, etc.), stops the drag (the position is not changed) |

### 5.8 Mouse at Design Time (`CMDesignHitTest`)

The same rule as TCSideBar (see the explanation of CM_DESIGNHITTEST in TCSideBar_Design.md). The designer sends this message each time the mouse is pressed, moved, or released. If the result is 1, the `MouseDown`, `MouseMove`, and `MouseUp` of TCPairSplitter are called; if 0, the designer handles it itself.

| Order | Condition | Result |
|---|---|---|
| 1 | Any button is pressed | `FDesignerPressLeft := False` (newly pressed; the designer rebuilds its pressed state) |
| 2 | Dragging | 1 (anywhere, received to the end) |
| 3 | `FDesignerPressLeft` is true and no button is pressed | 1 (do not pass movement after the drag to the designer; if passed, the designer judges that "a control is being dragged" and shows a selection frame) |
| 4 | Over the splitter (`BarRect`) | 1 |
| 5 | Otherwise | 0 (the designer selects a side or the TCPairSplitter) |

## 6. Decisions

| Item | Decision |
|---|---|
| How it is built | Does not inherit `TCustomPairSplitter`. Sides use `SetBounds`; the splitter draws itself |
| Type of a side | `TCustomPanel` (color, child controls, `ChildSizing`, and popup menu are available). Does not inherit `TPairSplitterSide` |
| Hiding a side | `SetVisible` is overridden and refuses if the other side is hidden. The hidden side gives the whole area to the other (decided by re-arrangement) |
| Hiding both | Not possible. The side hidden later is refused. The whole is hidden with `TCPairSplitter.Visible` |
| While loading | Loading `Visible` of a side is not refused (so the order in .lfm does not matter) |
| `Position` | The value is not changed while a side is hidden or when it is too large (it is fitted only when displayed). When the size of the whole changes, side 1 stays and side 2 grows or shrinks |
| Number of sides | Two. If a side is deleted at design time, it is created again |
| Owner of the sides | The Owner of the splitter (so that they can be saved to and loaded from the form) |
| Line of the splitter | Normally a 1px gray line. At run time, on mouse over and while dragging, a 2px line in `HighlightColor` (same as TCSplitter). At design time it stays gray |
| Dragging | Changes the size of the sides while moving. `OnMoved` is raised once on release if the position changed |
| Dragging at design time | `CMDesignHitTest` and `OwnerFormDesignerModified` (same as TCSideBar) |
| Type names | `TCPairSplitterType`, `cpsHorizontal`, `cpsVertical`, so that they do not clash when used together with the standard `PairSplitter` |

## 7. What to Check When Investigating Problems

| Symptom | Where to look |
|---|---|
| Sides are not created (at design time) | `CreateSides` in `CreateWnd`. Whether it is loading, or the Owner is loading (5.1) |
| The other side does not spread when a side is hidden | Whether `SetVisible` of the side calls `ApplyLayout` of the parent. Whether `FLayouting` stays true |
| A side does not hide | Whether the other side is already hidden (both cannot be hidden) |
| `Position` is not the expected value | `ClampPos` (minimum of `Constraints` of the sides, lower limit of side 2). Reading `Position` returns a too-large value as it is |
| The splitter cannot be dragged | Whether one of the sides is hidden (the splitter is not shown). At design time, `CMDesignHitTest` |
| The position dragged at design time is not saved | `OwnerFormDesignerModified` in `MouseUp`. Whether the position differs from the start |
| A selection frame appears at design time after a drag | `FDesignerPressLeft` (3 of 5.8) |
| The line color does not change | `HighlightColor`. At design time the line is gray (the run-time color applies at run time) |

## 8. Changes in This Version (1.0, newly created)

A new component, TCPairSplitter, is created. The behavior of existing components does not change. The changed files are as follows.

| File | Change |
|---|---|
| `source/uCSplitter.pas` | Adds `TCPairSplitterType`, `TCPairSplitterSide`, `TCPairSplitter`, and `RegisterClass` in initialization. Adds `LCLIntf` and `LCLProc` to uses. `TCSplitter` is not changed |
| `source/design/uCXReg.pas` | Registers `TCPairSplitter` and calls `RegisterNoIcon([TCPairSplitterSide])`. Adds `PropEdits` to uses |
| `source/res/csplitter_icon.lrs` | Adds three icons (`TCPairSplitter`, `_150`, `_200`) |
| `docs/TCPairSplitter_Usage.md`, `TCPairSplitter_Design.md`, and the same names in `docs/en` | New |
| `README.md`, `README.ja.md` | Add TCPairSplitter to the component table and description (after instruction) |
