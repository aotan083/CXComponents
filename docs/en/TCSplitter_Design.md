# TCSplitter Design Document

Author: aotan083
Date: 2026-11-06
Version: 1.0

---

## 1. Purpose

- The standard TSplitter does not change its look when the mouse is over it, and the line while dragging is black, so it does not look like the splitter of VS Code. TCSplitter is a splitter based on TSplitter that shows a colored line when the mouse is over it and while it is dragged.
- Its usage, properties and events are the same as TSplitter; only properties for the color and the cursor are added.
- The border of TCExpandPanel (`TCExpandSash`) is given the same look (TCExpandPanel_Design.md 6.7).

### 1.1 Not Included

- The splitting mechanism of TSplitter (`ResizeAnchor`, `ResizeStyle`, `MinSize`, `AutoSnap`, `OnCanResize`, `OnMoved`, etc.) is used as it is, unchanged.
- The look at design time stays the same as TSplitter (no line is shown).

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCSplitter.pas` | cx (runtime) | `TCSplitter` |
| `uCXReg.pas` | cxdsgn (design time) | Registration on the [CX] palette (`RegisterComponents('CX', [..., TCSplitter])`; at the end of the list) |
| `csplitter_icon.lrs` | cxdsgn (design time) | Icon |

- uses of `uCSplitter`: `Classes, SysUtils, Controls, ExtCtrls, Graphics, Types, LCLType, LMessages`
- `csplitter_icon.lrs` (`source\res`, cxdsgn): the palette icon (`TCSplitter`, `TCSplitter_150`, `TCSplitter_200`; PNG of 24, 36 and 48 px). It is loaded with `{$I csplitter_icon.lrs}` in the initialization of `uCXReg`. The picture shows two gray panels with a blue splitter line between them and three white dots as a grip.

## 3. TCSplitter

The parent class is `TSplitter` (ExtCtrls).

### 3.1 Constants

| Name | Value | Contents |
|---|---|---|
| `cLineWidth96` | 2 | Thickness of the line (the value at 96 dpi; converted with `Scale96ToFont`) |

### 3.2 Declaration

```pascal
type
  TCSplitter = class(TSplitter)
  private
    FHighlightColor: TColor;
    FSplitCursor: TCursor;
    FHot: Boolean;          // the mouse is over it
    FDragging: Boolean;     // dragging with the left button pressed
    procedure SetHighlightColor(AValue: TColor);
    procedure SetSplitCursor(AValue: TCursor);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CaptureChanged; override;
    procedure UpdateCursor; override;
  public
    constructor Create(TheOwner: TComponent); override;
  published
    property HighlightColor: TColor read FHighlightColor write SetHighlightColor default clHighlight;
    property SplitCursor: TCursor read FSplitCursor write SetSplitCursor default crDefault;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseDown;
    property OnMouseUp;
  end;
```

### 3.3 Properties

- `HighlightColor`: the color of the line. The default is `clHighlight` (the selection color of Windows; it follows the theme and dark display). To use a fixed color, specify the color. When changed, `Invalidate`.
- `SplitCursor`: the mouse cursor over the splitter. The default is `crDefault` (the same as TSplitter: `crHSplit` when splitting left-right, `crVSplit` when splitting up-down). If a value other than `crDefault` is specified, that cursor is used. When changed, `UpdateCursor`.

### 3.4 Behavior

1. `Create`: after `inherited`, `FHighlightColor := clHighlight`, `FSplitCursor := crDefault`, `FHot := False`, `FDragging := False`.
2. `MouseEnter`: after `inherited`, if not at design time, `Enabled`, and no other control has the mouse capture: `FHot := True`, `Invalidate`.
3. `MouseLeave`: after `inherited`, `FHot := False`, `Invalidate`. Even while dragging, `FHot` becomes false when the mouse goes outside (`FDragging` keeps the line).
4. `MouseDown`: after `inherited`, with the left button and `Enabled`: `FDragging := True`, `Invalidate`.
5. `MouseUp`: after `inherited`, with the left button: `FDragging := False`, `Invalidate`.
6. `CaptureChanged`: after `inherited`, if `FDragging` is true and the button is no longer pressed: `FDragging := False`, `Invalidate` (a safeguard for when the mouse-up does not arrive).
7. `UpdateCursor`: if not `Enabled`, `Cursor := crDefault`. If `Enabled` and `FSplitCursor <> crDefault`, `Cursor := FSplitCursor`. Otherwise `inherited UpdateCursor`.

### 3.5 Painting (`Paint`)

1. `inherited Paint` (the look of TSplitter: `OnPaint` if there is one, otherwise the themed band and grip).
2. At design time, or if `Enabled` is false, finish here.
3. If `FHot` or `FDragging` is true, draw a line. Thickness `T := Max(1, Scale96ToFont(cLineWidth96))`. If `ResizeAnchor` is `akLeft` or `akRight` (a vertical line): width `T` in the middle horizontally, the full height. If `akTop` or `akBottom` (a horizontal line): height `T` in the middle vertically, the full width. The color is `HighlightColor`.
4. Even when there is `OnPaint`, the line is drawn on top at the end.

### 3.6 Events

- The events of TSplitter (`OnCanOffset`, `OnCanResize`, `OnMoved`, `OnPaint`, etc.) can be used as they are.
- `OnMouseEnter` (when the mouse comes over it), `OnMouseLeave` (when it leaves), `OnMouseMove`, `OnMouseDown` and `OnMouseUp` are made `published` so that they appear in the Object Inspector (they do not appear for TSplitter).
- When a drag ends, `OnMoved` is raised as before.

## 4. Registration

Add `TCSplitter` at the end of the list in `RegisterComponents('CX', [...])` of `uCXReg.Register`. Add `uCSplitter` to the uses of `uCXReg`.

## 5. Points to Check When Investigating a Defect

| Symptom | Where to look |
|---|---|
| The line does not appear | Steps 2 and 3 of `Paint`, `Enabled`, whether it is at design time |
| The line does not disappear after releasing the mouse | `MouseUp` and `CaptureChanged` (3.4, steps 5 and 6) |
| The cursor does not change | `UpdateCursor` (3.4, step 7), `SplitCursor` |
| `OnMouseEnter` is not raised | The `published` declaration (3.2), whether `MouseEnter` calls `inherited` |
