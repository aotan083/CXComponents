# TCSideBar Design Document

Author: aotan083
Date: 2026-10-29
Version: 1.0

---

## 1. Purpose

Build an Edge-style sidebar ("icon bar + collapsible panel + splitter") as a single component (TCSideBar). Pages (TCSideBarPage) are held as child components, so that components can be placed on top of a page in the form designer.

- TCSideBar itself draws the icon bar, the header (Caption and the [x] button), and the splitter.
- Only the open page is shown.
- TCSideBar decides its own width (when closed, only the icon bar).
- Only system colors are used (dark/light is left to the application side, e.g. MetaDarkStyle).

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCSideBar.pas` | cx (runtime) | Types, `TCSideBarPage`, `TCSideBar`, variable `CSideBarDesignSelect` |
| `uCSideBarReg.pas` | cxdsgn (design time) | Registration on the [CX] palette, component editor `TCSideBarEditor` |
| `csidebar_icon.lrs` | cxdsgn (design time) | Icons (`TCSideBar`, `TCSideBar_150`, `TCSideBar_200`). Included with `{$I csidebar_icon.lrs}` in the initialization of `uCSideBarReg` |

- `uCSideBar` uses: `Classes, SysUtils, Types, LCLType, LCLIntf, LCLProc, LMessages, Controls, Graphics, GraphType, Forms, Menus, ImgList, ExtCtrls, Themes`
- `uCSideBar` initialization: `RegisterClass(TCSideBarPage)` (so that pages can be loaded from .lfm).
- `uCSideBarReg` uses: `Classes, SysUtils, LResources, ComponentEditors, PropEdits, uCSideBar`

## 3. Types and Constants

```pascal
TCSideBarPageEvent = procedure(Sender: TObject; Index: Integer) of object;
TCSideBarChangingEvent = procedure(Sender: TObject; Index: Integer; var Allow: Boolean) of object;
TCSideBarDesignSelectProc = procedure(AComponent: TComponent);

var
  CSideBarDesignSelect: TCSideBarDesignSelectProc = nil;
```

- `CSideBarDesignSelect` is a procedure that changes which component is selected in the IDE at design time. Because a runtime package cannot use IDEIntf, the design-time package (`Register` in `uCSideBarReg`) sets it.

Sizes at 100% (in implementation; scaled with `Scale96ToFont` each time they are drawn):

| Name | Value | Meaning |
|---|---|---|
| `cHeaderHeight96` | 32 | Header height |
| `cCloseButton96` | 20 | Size of the [x] button |
| `cIconInset96` | 4 | Margin between the icon cell and the highlight |
| `cIconRadius96` | 6 | Corner radius of the highlight |
| `cTextPadding96` | 8 | Left/right padding of the header text |

resourcestring: `rsCSideBarPageParent = 'TCSideBarPage can only be placed on a TCSideBar'`

## 4. TCSideBarPage

### 4.1 Declaration

```pascal
TCSideBarPage = class(TCustomControl)
private
  FImageIndex: TImageIndex;
  FPanelWidth: Integer;
  FPageVisible: Boolean;
  FShortCut: TShortCut;
  function GetSideBar: TCSideBar;
  procedure SetImageIndex(const AValue: TImageIndex);
  procedure SetPanelWidth(AValue: Integer);
  procedure SetPageVisible(const AValue: Boolean);
  procedure SetActiveState(AActive: Boolean);
protected
  procedure SetParent(NewParent: TWinControl); override;
  procedure TextChanged; override;
  procedure CMHitTest(var Message: TCMHitTest); message CM_HITTEST;
  procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
  procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
    const AXProportion, AYProportion: Double); override;
public
  constructor Create(TheOwner: TComponent); override;
  property SideBar: TCSideBar read GetSideBar;
published
  property Caption;
  property ImageIndex: TImageIndex read FImageIndex write SetImageIndex default -1;
  property PanelWidth: Integer read FPanelWidth write SetPanelWidth default 250;
  property PageVisible: Boolean read FPageVisible write SetPageVisible default True;
  property Enabled;
  property ShortCut: TShortCut read FShortCut write FShortCut default 0;
  property Color;
  property Font;
  property ParentFont;
  property PopupMenu;
  property ShowHint;
  property ParentShowHint;
end;
```

`TCSideBarPage` is declared before `TCSideBar`, so a forward declaration `TCSideBar = class;` is placed first. `SetActiveState` is private, but it is called from `TCSideBar` in the same unit.

### 4.2 Create

1. `FImageIndex := -1`, `FPanelWidth := 250`, `FPageVisible := True`, `FShortCut := 0`.
2. Add to `ControlStyle`: `csAcceptsControls` (components can be placed on it), `csDesignFixedBounds` (cannot be moved at design time), `csNoDesignVisible` (not shown at design time; removed when the page is opened), and `csNoFocus` (the page does not receive focus). Same as TCustomPage.
3. `Align := alClient`, `ParentColor := False`, `Color := clBtnFace`, `Caption := ''`, `Visible := False`.

### 4.3 Procedures

| Procedure | Processing |
|---|---|
| `GetSideBar` | `Parent` if it is a `TCSideBar`, otherwise nil |
| `SetImageIndex` | If the value changed, store it and call `SideBar.PageChanged(Self)` |
| `SetPanelWidth` | If negative, set to 0. If the value changed, store it and call `SideBar.PanelWidthChanged(Self)` |
| `SetPageVisible` | If the value changed, store it and call `SideBar.PageVisibleChanged(Self)` |
| `SetActiveState(True)` | Remove `csNoDesignVisible` and set `Visible := True` |
| `SetActiveState(False)` | Add `csNoDesignVisible` and set `Visible := False` |
| `SetParent(NewParent)` | Finish if unchanged. If `NewParent` is neither nil nor a `TCSideBar`, raise `EInvalidOperation(rsCSideBarPageParent)`. If the previous parent is a `TCSideBar`, call `RemovePage(Self)`. Then `inherited SetParent`. If the new parent is a `TCSideBar`, call `AddPage(Self)` |
| `TextChanged` | After `inherited`, call `SideBar.PageChanged(Self)` (Caption is used for the header and the hint) |
| `CMHitTest` | A page that is not open (`SideBar.ActivePage <> Self`) gets `Message.Result := 0` (does not receive the mouse). Otherwise `inherited` |
| `CMEnabledChanged` | After `inherited`, call `SideBar.PageChanged(Self)` (grays the icon out / restores it) |
| `DoAutoAdjustLayout` | After `inherited`, if `AMode` is `lapAutoAdjustWithoutHorizontalScrolling` or `lapAutoAdjustForDPI`, set `PanelWidth := Round(FPanelWidth * AXProportion)` |

- At design time, `SetActiveState` finally calls `UpdateControlState` (without it the display does not change at design time).
- Removing `csNoDesignVisible` only for the open page follows the same idea as LCL's `TCustomTabControl.UpdateDesignerFlags`. The designer treats a component with `csNoDesignVisible` as "not at that location", so if it were not removed, a component dropped there would go into the form instead of the page.
- When closing, set the flag first and then `Visible := False`.
- Because everything goes through `SetParent`, the .lfm load order becomes the page order as is. When a page is destroyed, its parent is also detached and `RemovePage` is called.

## 5. TCSideBar

### 5.1 Fields

| Name | Type | Initial value | Meaning |
|---|---|---|---|
| `FPages` | `TFPList` | empty | Page order |
| `FActivePage` | `TCSideBarPage` | nil | The open page |
| `FImages` | `TCustomImageList` | nil | Icon images |
| `FImageChangeLink` | `TChangeLink` | created | `OnChange := ImageListChange` |
| `FImagesWidth` | `Integer` | 0 | Icon width (kept as the 100% value) |
| `FIconBarWidth` | `Integer` | 40 | Width of the icon bar |
| `FMinPanelWidth` | `Integer` | 150 | Lower limit of the panel width |
| `FMaxPanelWidth` | `Integer` | 600 | Upper limit of the panel width (0 means no limit) |
| `FSplitterWidth` | `Integer` | 8 | Width of the splitter |
| `FResizeStyle` | `TResizeStyle` | `rsLine` | Appearance during dragging |
| `FShowHeader` | `Boolean` | `True` | Whether to show the header |
| `FShowCloseButton` | `Boolean` | `True` | Whether to show the [x] button |
| `FIconPopupMenu` | `TPopupMenu` | nil | Right-click menu of the icon bar |
| `FOnPageChanging`, `FOnPageOpen`, `FOnPageClose`, `FOnPanelResize` | event types | nil | Events |
| `FHotPage` | `TCSideBarPage` | nil | Page of the icon under the mouse |
| `FHotClose` | `Boolean` | `False` | The mouse is over the [x] button |
| `FDownPage` | `TCSideBarPage` | nil | Page of the icon on which the left button was pressed |
| `FDownClose` | `Boolean` | `False` | The left button was pressed on the [x] button |
| `FDragging` | `Boolean` | `False` | A splitter drag is in progress |
| `FDragStartX`, `FDragStartWidth`, `FDragWidth` | `Integer` | | Drag start position, width at start, current width |
| `FRubberBand` | `HWND` | 0 | The line shown during dragging (a separate window) |
| `FKeyHandlerAdded` | `Boolean` | | Whether the shortcut key handler has been registered |
| `FDesignerPressLeft` | `Boolean` | `False` | At design time, after the sidebar has handled MouseUp, the designer keeps the "pressed" state (7.5) |

### 5.2 Declaration (public parts)

```pascal
public
  constructor Create(TheOwner: TComponent); override;
  destructor Destroy; override;
  procedure OpenPage(Index: Integer);
  procedure ClosePage;
  procedure MovePage(CurIndex, NewIndex: Integer);
  property Pages[Index: Integer]: TCSideBarPage read GetPage;
  property PageCount: Integer read GetPageCount;
  property ActivePageIndex: Integer read GetActivePageIndex write SetActivePageIndex;
published
  property ActivePage: TCSideBarPage read FActivePage write SetActivePage;
  property Images: TCustomImageList read FImages write SetImages;
  property ImagesWidth: Integer read FImagesWidth write SetImagesWidth default 0;
  property IconBarWidth: Integer read FIconBarWidth write SetIconBarWidth default 40;
  property MinPanelWidth: Integer read FMinPanelWidth write SetMinPanelWidth default 150;
  property MaxPanelWidth: Integer read FMaxPanelWidth write SetMaxPanelWidth default 600;
  property SplitterWidth: Integer read FSplitterWidth write SetSplitterWidth default 8;
  property ResizeStyle: TResizeStyle read FResizeStyle write FResizeStyle default rsLine;
  property ShowHeader: Boolean read FShowHeader write SetShowHeader default True;
  property ShowCloseButton: Boolean read FShowCloseButton write SetShowCloseButton default True;
  property IconPopupMenu: TPopupMenu read FIconPopupMenu write SetIconPopupMenu;
  property OnPageChanging: TCSideBarChangingEvent read FOnPageChanging write FOnPageChanging;
  property OnPageOpen: TCSideBarPageEvent read FOnPageOpen write FOnPageOpen;
  property OnPageClose: TCSideBarPageEvent read FOnPageClose write FOnPageClose;
  property OnPanelResize: TNotifyEvent read FOnPanelResize write FOnPanelResize;
  property Align default alLeft;
  property Anchors;
  property BorderSpacing;
  property Constraints;
  property Enabled;
  property Font;
  property ParentFont;
  property ParentShowHint;
  property ShowHint;
  property Visible;
```

The protected section has `AddPage`, `RemovePage`, `PageChanged`, `PageVisibleChanged`, and `PanelWidthChanged`, which are called from pages, and the LCL overrides (`Loaded`, `Notification`, `AdjustClientRect`, `CalculatePreferredSize`, `DoAutoAdjustLayout`, `Paint`, `MouseDown`, `MouseMove`, `MouseUp`, `MouseLeave`, `CaptureChanged`, `DoContextPopup`, `CMHintShow`, `CMDesignHitTest`, `CMEnabledChanged`).

### 5.3 Create and Destroy

Create:

1. `FPages := TFPList.Create`; create `FImageChangeLink` and set `OnChange := ImageListChange`.
2. Set the initial values of 5.1. `FRubberBand := 0`.
3. `ControlStyle := ControlStyle - [csAcceptsControls] + [csCaptureMouse, csClickEvents]` (components can only be placed on a page; the mouse is still received when it leaves the control during a drag).
4. `Color := clBtnFace`, `Align := alLeft`, `AutoSize := True` (the width is decided by the component itself; AutoSize is not published).
5. If not at design time and `Application` exists, `Application.AddOnKeyDownHandler(@AppKeyDown, False)` and `FKeyHandlerAdded := True`.

Destroy:

1. If `FKeyHandlerAdded`, call `Application.RemoveOnKeyDownHandler(@AppKeyDown)`.
2. If `FRubberBand <> 0`, call `DestroyRubberBand`.
3. `inherited Destroy` (inside this, the parents of the child pages are detached and `RemovePage` is called).
4. After that, free `FImageChangeLink` and `FPages`.

### 5.4 Predicates

| Procedure | Processing |
|---|---|
| `EventsEnabled` | `True` if `ComponentState` contains none of `csLoading`, `csReading`, `csDesigning`, `csDestroying` |
| `IconShown(P)` | `True` if `P` is not nil and (at design time, or `P.PageVisible`) (at design time the icon is shown regardless of `PageVisible`) |
| `CanOpenPage(P)` | `False` if nil. `True` at design time. At runtime, `P.PageVisible and P.Enabled` |

### 5.5 Sizes and Positions

| Procedure | Processing |
|---|---|
| `HeaderHeight` | `Scale96ToFont(cHeaderHeight96)` |
| `CloseButtonSize` | `Scale96ToFont(cCloseButton96)` |
| `HeaderRect` | Empty if closed or `ShowHeader = False`. Otherwise `Rect(FIconBarWidth, 0, ClientWidth - FSplitterWidth, HeaderHeight)` (if the right is less than the left, align it to the left) |
| `CloseButtonRect` | Empty if any of: closed, `ShowHeader = False`, `ShowCloseButton = False`. Otherwise a `CloseButtonSize` square at the right end of the header, vertically centered (margin `M := (header height - S) div 2`). If the left edge is less than the header's left, align it |
| `SplitterRect` | Empty if closed. Otherwise `Rect(ClientWidth - FSplitterWidth, 0, ClientWidth, ClientHeight)` |
| `IconRect(P)` | Empty unless `IconShown(P)`. Walk `FPages` in order, count only those where `IconShown` is true, and for the row `Row` of `P` return `Rect(0, Row * FIconBarWidth, FIconBarWidth, (Row + 1) * FIconBarWidth)` |
| `PageAtIcon(X, Y)` | nil if `FIconBarWidth <= 0`, `X` is outside the icon bar, or `Y < 0`. Otherwise the `IconShown` page at row `Y div FIconBarWidth` |
| `InCloseButton`, `InSplitter` | Whether the point is inside `CloseButtonRect` / `SplitterRect` |
| `ClampPanelWidth(v)` | The lower limit if `v < FMinPanelWidth`. If `FMaxPanelWidth > 0` and the upper limit is exceeded, the upper limit. 0 if negative |

### 5.6 Property Reads and Writes

| Procedure | Processing |
|---|---|
| `GetPage(i)` | `FPages[i]` (out of range raises `EListError` from TFPList) |
| `GetPageCount` | `FPages.Count` |
| `GetActivePageIndex` | -1 if closed, otherwise `FPages.IndexOf(FActivePage)` |
| `SetActivePageIndex(v)` | Do nothing if `v < -1` or `v >= Count`. If -1, `ChangeActivePage(nil)`; otherwise `ChangeActivePage(FPages[v])` |
| `SetActivePage(v)` | While `csLoading`, only `FActivePage := v` (the display is decided in `Loaded`). If `v` is not a page of this sidebar, do nothing. Otherwise `ChangeActivePage(v)` |
| `SetIconBarWidth`, `SetSplitterWidth` | 0 if negative. If changed, store and call `LayoutChanged` |
| `SetMinPanelWidth`, `SetMaxPanelWidth` | Store, with 0 if negative (no repaint) |
| `SetImagesWidth` | 0 if negative. If changed, store and call `Invalidate` |
| `SetImages` | For the previous one, `UnRegisterChanges` and `RemoveFreeNotification`. For the new one, `FreeNotification` and `RegisterChanges`. `Invalidate` |
| `SetIconPopupMenu` | `RemoveFreeNotification` for the previous one, `FreeNotification` for the new one |
| `SetShowHeader` | If changed, store, `FHotClose := False`, `FDownClose := False`, `LayoutChanged` (the top of the client area changes; the width does not change and no event is fired) |
| `SetShowCloseButton` | If changed, store and call `Invalidate` |
| `ImageListChange` | `Invalidate` |
| `Notification` | On `opRemove`, if it is `FImages` set it to nil and call `Invalidate`. If it is `FIconPopupMenu`, set it to nil |

### 5.7 Page List

| Procedure | Processing |
|---|---|
| `AddPage(P)` | Finish if already present. `FPages.Add(P)`, `P.SetActiveState(P = FActivePage)`. If not loading, `Invalidate` |
| `RemovePage(P)` | Finish if `FPages` is nil or `P` is not in it. Remove it from the list; if `FHotPage` or `FDownPage` is `P`, set it to nil. If `P` is the open page, `FActivePage := nil` (no event); if dragging, cancel and erase the line. Unless being destroyed, `LayoutChanged` |
| `PageChanged` | `Invalidate` |
| `PageVisibleChanged(P)` | At runtime, if the open page was hidden, `SetActivePageSilently(nil)`. Otherwise `Invalidate` |
| `PanelWidthChanged(P)` | If it is the open page, `LayoutChanged` |
| `MovePage(Cur, New)` | Do nothing if either is out of range or they are the same. `NewControlIndex := GetControlIndex(FPages[New])`, `FPages.Move(Cur, New)`, `SetControlIndex(P, NewControlIndex)`, `Invalidate`. Makes the order of `FPages` and the order of children (the order saved to .lfm) the same. No event is fired |

### 5.8 Open and Close

`ChangeActivePage(NewPage): Boolean` (returns `True` if the state changed):

1. If `NewPage = FActivePage`, finish with `False`. If `NewPage` is not nil and not `CanOpenPage`, finish with `False`.
2. If not `EventsEnabled`, call `SetActivePageSilently(NewPage)` and finish with `True`.
3. `Allow := True`. If `FOnPageChanging` exists, call it with -1 when closing, or with the index of `NewPage` when opening. Finish if `Allow = False`.
4. If the state was changed inside the event (`NewPage = FActivePage`, or `NewPage` is not in the list), finish.
5. `DisableAutoSizing` (so that the width does not change twice during an open/close).
6. If there was an open page: remember its index, `FActivePage := nil`, `SetActiveState(False)`, `FOnPageClose(index)`.
7. If `NewPage` is in the list and `FActivePage = nil`: `FActivePage := NewPage`, `SetActiveState(True)`, `LayoutChanged`, `FOnPageOpen(index)`.
8. `LayoutChanged`, `EnableAutoSizing` (in finally). Return `True`.

| Procedure | Processing |
|---|---|
| `SetActivePageSilently(P)` | Finish if the same. Within `DisableAutoSizing`: `SetActiveState(False)` on the previous page, `FActivePage := P`, `SetActiveState(True)`, `LayoutChanged` |
| `UserTogglePage(P)` | If it is the open page, `ChangeActivePage(nil)`; otherwise `ChangeActivePage(P)`. If it changed and at design time, `OwnerFormDesignerModified(Self)`, and if `CSideBarDesignSelect` exists, select the opened page (or the sidebar if closed) (so that the selection frame of a component on a hidden page does not remain invisibly) |
| `UpdatePageVisibility` | `SetActiveState(P = FActivePage)` on all pages |
| `LayoutChanged` | Do nothing if being destroyed. `InvalidatePreferredSize`, `AdjustSize`, `ReAlign`, `Invalidate` |
| `OpenPage(i)` | `ChangeActivePage(FPages[i])` (out of range raises `EListError`) |
| `ClosePage` | `ChangeActivePage(nil)` |

### 5.9 LCL Overrides

| Procedure | Processing |
|---|---|
| `Loaded` | After `inherited`, set `FActivePage` to nil if it is not in the list or not `CanOpenPage`. `UpdatePageVisibility`, `LayoutChanged`. No event is fired |
| `AdjustClientRect` | After `inherited`, `Left += FIconBarWidth`. If open: with `ShowHeader`, `Top += HeaderHeight`, and `Right -= FSplitterWidth`. Make sure the right does not become less than the left and the bottom less than the top. Since the page is `alClient`, it is placed filling the remainder |
| `CalculatePreferredSize` | Width = `FIconBarWidth`; if open, `+ FActivePage.PanelWidth + FSplitterWidth`. 1 if 0 or less (0 or less is treated as "unspecified"). Height 0 (left to Align). `ShowHeader` is irrelevant |
| `DoAutoAdjustLayout` | After `inherited`, if `lapAutoAdjustWithoutHorizontalScrolling` or `lapAutoAdjustForDPI`, set `FIconBarWidth`, `FMinPanelWidth`, `FMaxPanelWidth` (if not 0), and `FSplitterWidth` to `Round(value * AXProportion)` and call `LayoutChanged`. `PanelWidth` is handled on the page side, and `ImagesWidth` on the ImageList side |
| `CMEnabledChanged` | After `inherited`, `Invalidate` |

## 6. Drawing

`Paint`: fill everything with `clBtnFace` -> `PaintIcons` -> if open, `PaintHeader` when `ShowHeader`, then `PaintSplitter`.

`PaintIcons`:

1. Finish if `FIconBarWidth <= 0`. `Inset := Scale96ToFont(cIconInset96)`, `Radius := Scale96ToFont(cIconRadius96)`.
2. If `Images` exists, `Res := FImages.ResolutionForPPI[FImagesWidth, Font.PixelsPerInch, 1]` (from the 100% width, the ImageList chooses the image that matches the display scale).
3. For each `IconShown` page: `R := IconRect(P)`, `HR` = `R` shrunk inward by `Inset`.
   - When the mouse is over it and both the sidebar and the page are usable: fill `RoundRect(HR, Radius, Radius)` with `clBtnHighlight`.
   - For the open page: `RoundRect(HR, Radius, Radius)` with a 1px line of `clHighlight` (not filled).
   - If `ImageIndex` is in range, draw the icon at the center of the frame. If both the sidebar and the page are usable, `Res.Draw(Canvas, IX, IY, ImageIndex, True)`. If not, create a gray image with `Res.GetBitmap(ImageIndex, Bmp, gdeDisabled)` and use `Canvas.Draw` (because `Res.Draw(..., False)` does not change the color on Windows depending on the image format).

`PaintHeader`:

1. Fill `HeaderRect` with `clBtnFace`.
2. Text area `TR` = the header's left and right shrunk inward by `Scale96ToFont(cTextPadding96)`. If there is an [x] button, the right end becomes `left of [x] - Pad div 2`.
3. Draw `FActivePage.Caption` with `Font`, text color `clBtnText`, vertically centered, single line, end ellipsis ("..."), clipped on overflow.
4. [x]: if the mouse is over it, fill with `clBtnHighlight`. With `M := width of [x] div 4`, draw two lines of `clBtnText` with thickness `Scale96ToFont(1)` (minimum 1) to form the "x".

`PaintSplitter`: a 1px vertical line of `clBtnShadow` in the center of `SplitterRect`.

## 7. Mouse

### 7.1 MouseDown, MouseMove, MouseUp, MouseLeave

- `MouseDown`: after `inherited`, for the left button: `FDownPage := nil`, `FDownClose := False`. If over the splitter, `BeginSplitterDrag(X)`; if over [x], `FDownClose := True`; otherwise `FDownPage := PageAtIcon(X, Y)`.
- `MouseMove`: after `inherited`, if dragging, `MoveSplitterDrag(X)` and finish. Otherwise `SetHot(PageAtIcon(X, Y), InCloseButton(X, Y))`; if over the splitter `Cursor := crHSplit`, otherwise `crDefault`.
- `MouseUp`: after `inherited`, finish if not the left button.
  1. If dragging, `EndSplitterDrag(X)`; at design time `FDesignerPressLeft := True`; finish.
  2. If `FDownClose`, reset it; if released over [x] and open, `ChangeActivePage(nil)`; finish.
  3. `P := FDownPage`, `FDownPage := nil`. At design time, `FDesignerPressLeft := True`.
  4. If `P` exists, the release point is also on the icon of `P`, the sidebar is usable, and (design time or `P.Enabled`), `UserTogglePage(P)`.
- `MouseLeave`: after `inherited`, if not dragging, `SetHot(nil, False)` and `Cursor := crDefault`.
- `SetHot(P, AClose)`: finish if the same. When moving to a different icon, `Application.CancelHint` (so that the hint can be shown again). Store and `Invalidate`.

### 7.2 Right-click (DoContextPopup)

If `inherited` sets `Handled`, finish. `Handled := True` (nothing is shown outside the icon bar). If the mouse position is inside the icon bar (`0 <= X < FIconBarWidth`, `Y >= 0`) and `IconPopupMenu` exists, set `PopupComponent := Self` and `Popup` at screen coordinates. Nothing is shown for the keyboard menu key (`X = -1`).

### 7.3 Hint (CMHintShow)

After `inherited`, if the `Caption` of the page of the icon under the mouse is not empty, `HintStr := Caption` and `CursorRect := IconRect(P)` (LCL shows the hint again when the mouse leaves that rectangle). Otherwise `HintStr := ''`.

### 7.4 Splitter Drag

| Procedure | Processing |
|---|---|
| `BeginSplitterDrag(X)` | Finish if closed. Erase any leftover previous line. `FDragging := True`, `MouseCapture := True` (at design time the designer calls MouseDown directly, so there is no capture; without this, the line's window would receive MouseUp on release and the line would remain). Remember the start position and the width at start. `CreateRubberband` at the screen coordinates of `SplitterRect`, black (`GetStockObject(BLACK_BRUSH)`) for `rsLine`, `ThemeServices.DottedBrush` for `rsPattern` |
| `MoveSplitterDrag(X)` | `FDragWidth := ClampPanelWidth(width at start + (X - start position))`. For `rsUpdate`, `PanelWidth := FDragWidth`; for `rsLine` and `rsPattern`, `UpdateRubberBand`; `rsNone` does nothing |
| `UpdateRubberBand` | Shift `SplitterRect` to the right by `FDragWidth - width at start` and `SetRubberBandRect` in screen coordinates |
| `EndSplitterDrag(X)` | `FDragging := False`, `MouseCapture := False`, erase the line. Finish if closed. `PanelWidth := ClampPanelWidth(...)`. If the width changed: at design time `OwnerFormDesignerModified(Self)`; at runtime, if `EventsEnabled`, `FOnPanelResize` |
| `CancelSplitterDrag` | Finish if not dragging. `FDragging := False`, erase the line, and restore `PanelWidth` if it differs from the start. `OnPanelResize` is not fired |
| `CaptureChanged` | After `inherited`, if dragging, the capture was lost, and the left button is still pressed (`GetKeyState(VK_LBUTTON) < 0`), `CancelSplitterDrag` (when lost via Alt+Tab etc.; if the button was released, the drag is ended by the MouseUp that follows) |

- The line is a separate window (`CreateRubberband`), so it also appears above a WebView2 (same as TSplitter).

### 7.5 Design-time Mouse (CMDesignHitTest)

The designer sends this message every time the mouse is pressed, moved, or released. Returning 1 causes the sidebar's MouseDown, MouseMove, and MouseUp to be called; returning 0 lets the designer handle it (selecting the component).

The Lazarus designer has the following behaviors: (1) when the sidebar handles MouseUp, the designer does not forget the component that was being pressed, and (2) when the mouse moves, it treats the state as "left button pressed" even if no button is pressed. When these two overlap, merely moving the mouse after clicking an icon shows a rubber-band selection frame. To prevent this, the following values are returned.

1. `ButtonsDown := (Keys and (MK_LBUTTON or MK_RBUTTON or MK_MBUTTON)) <> 0`. If any is pressed, `FDesignerPressLeft := False`.
2. 1 while dragging or if `FDownPage` exists.
3. 1 if `FDesignerPressLeft` and no button is pressed.
4. 1 if over an icon or over the splitter.
5. Otherwise 0.

## 8. Shortcut Keys (AppKeyDown)

Received through `Application.AddOnKeyDownHandler`. Only keys that were not used by the form's `OnKeyDown` (`KeyPreview`), the focused component, or menu/ActionList shortcuts arrive here.

1. Finish if `Key = 0` or not `EventsEnabled`.
2. Finish if `Sender` is not a `TControl`. Finish if `GetParentForm(Self)` and `GetParentForm(Sender)` differ (only keys of the same form).
3. Finish unless the sidebar is `Enabled` and `IsVisible`.
4. `SC := Menus.ShortCut(Key, Shift * [ssShift, ssAlt, ssCtrl])`. Finish if 0.
5. Walk the pages; at the first page with `ShortCut = SC`: if `PageVisible` and `Enabled`, `UserTogglePage(P)` and `Key := 0`. Either way, finish there.

## 9. Design Time (uCSideBarReg)

`Register`:

1. `CSideBarDesignSelect := @DesignSelect` (a procedure that calls `GlobalDesignHook.SelectOnlyThis(AComponent)`).
2. `RegisterComponents('CX', [TCSideBar])`.
3. `RegisterNoIcon([TCSideBarPage])` (pages are not shown on the palette).
4. `RegisterComponentEditor(TCSideBar, TCSideBarEditor)`, `RegisterComponentEditor(TCSideBarPage, TCSideBarEditor)` (the same menu is shown even when a page is selected).

`TCSideBarEditor = class(TComponentEditor)`: the sidebar being operated is the `SideBar` of the selected component if it is a `TCSideBarPage`, otherwise the selected component itself.

| No. | Label | Processing |
|---|---|---|
| 0 | Add Page | Finish if `GetHook` fails. Call `TCSideBarPage.Create` with the sidebar's Owner as Owner (the sidebar if none). `Name := GetDesigner.CreateUniqueComponentName(ClassName)`, `Caption := Name`, `Parent := sidebar` (goes to the end of the list), `ActivePage := new page` (no event because it is design time), `Hook.PersistentAdded(new page, True)`, `Modified` |
| 1 | Delete Page | Finish if there is no open page. `Hook.DeletePersistent(page)`. The editor itself may be freed after this, so do nothing else |
| 2 | Move Up | If the index `Cur` of the open page is 0 or more and `Cur - 1` is in range, `MovePage(Cur, Cur - 1)` and `Modified` |
| 3 | Move Down | Likewise, toward `Cur + 1` |

`GetVerbCount` is 4. The label strings are resourcestrings (`rsCSideBarAddPage`, etc.).

## 10. Points to Check When Investigating Bugs

| Symptom | Where to look |
|---|---|
| A component dropped at design time goes into the form instead of the page | `csNoDesignVisible` in `SetActiveState` (4.3) |
| At design time, a rubber-band selection frame appears after clicking an icon | `CMDesignHitTest`, `FDesignerPressLeft` (7.5) |
| The drag line remains | `MouseCapture` in `BeginSplitterDrag`, `CaptureChanged` (7.4) |
| The wrong page is open at startup, or events are fired | `csLoading` in `SetActivePage`, `Loaded` (5.6, 5.9) |
| The width changes twice and flickers | `DisableAutoSizing` in `ChangeActivePage` (5.8) |
| Shortcut keys do not work | Steps 1-3 of `AppKeyDown` (chapter 8). Check whether a menu, ActionList, or component is using the key |
| The page order differs from the .lfm | `SetParent` (4.3), `SetControlIndex` in `MovePage` (5.7) |
| The width is off at a different display scale | `DoAutoAdjustLayout` in both (4.3, 5.9) |
