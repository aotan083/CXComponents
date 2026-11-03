# TCPageControl Design Document

Author: aotan083
Date: 2026-10-29
Version: 1.0

---

## 1. Purpose

Make it possible to build a screen like a browser (Firefox), with tabs lined up where the title bar would be, simply by placing components on the form and configuring them in the Object Inspector (without writing code).

- The tab control (TCPageControl) can be used on its own (the normal usage, not placed on a title bar).
- When placed on the title bar component (TCTitleBar), the tabs and the title bar look like a single unit.
- The only code the application writes is the application-specific processing run when a button or menu is clicked.

## 2. Basic Policy

| No | Policy |
|---|---|
| 1 | Split the components into two: "the title bar part (TCTitleBar)" and "the tab control (TCPageControl)" |
| 2 | Names of properties, types, events and methods follow the reference LCL component. Only functions the reference component lacks get original names, which this document marks as "Original" |
| 3 | Reference LCL components: TCTitleBar = TPanel, TCPageControl = TPageControl, TCTabSheet = TTabSheet |
| 4 | Theming is left to MetaDarkStyle. The components do not detect the theme themselves. Drawing uses system colors (`clBtnFace`, `clBtnText`, `clWindow`, etc.). If a fixed color is specified at design time, that color is used |
| 5 | Targets Windows 11 only (no Windows version check is included). On non-Windows platforms, TCTitleBar does not touch the form and behaves as a plain panel (the minimize, maximize and close buttons are not shown) |
| 6 | Division of roles with the built-in tabs of TCMonacoEditor and TCTabBrowser: "switching screens = TCPageControl; the files etc. inside = each component's built-in tabs" |

## 3. Structure

### 3.1 Classes

| Class | Base class | Unit | Palette | Role |
|---|---|---|---|---|
| `TCTitleBar` | `TCustomPanel` | `uCTitleBar` | CX | Title bar part. Removes the form's title bar and places itself in that position |
| `TCPageControl` | `TCustomControl` | `uCPageControl` | CX | The tab control itself. A tab strip plus a collection of pages |
| `TCTabSheet` | `TCustomControl` | `uCPageControl` | Not registered | One tab's page. Created from TCPageControl's design-time menu |
| `TCTabStrip` | `TCustomControl` | `uCPageControl` | Internal | Drawing and operation of the tab strip. Held inside TCPageControl |
| `TCTabListPopup` | `TCustomForm` | `uCPageControl` (implementation) | Internal | Tab list opened with [∨] |
| `TCTabListView` | `TCustomControl` | `uCPageControl` (implementation) | Internal | Contents of the tab list (draws the rows) |

**Why TCPageControl is not derived from TPageControl**: In the Windows LCL, the tabs of TPageControl are drawn by the standard Windows tab control. With the standard tab control, you cannot freely draw dark display, the [×] on each tab, [＋] and [∨], reordering by dragging, or moving onto the title bar. Therefore it is built from `TCustomControl`, matching only the names and types to TPageControl.

### 3.2 Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCTitleBar.pas` | cx (runtime) | `TCTitleBar`, the interfaces `ICTitleBarDragArea` and `ICTitleBarDesignHit`, shared functions (`CXScale96`, `CXBlendColor`, `CXSymbolFontName`, `CXSymbol`, `CXSetSymbolFont`, `CTitleBarHookChild`) |
| `uCPageControl.pas` | cx (runtime) | `TCPageControl`, `TCTabSheet`, `TCTabStrip`, `TCTabListPopup`, `TCTabListView` |
| `uCPageControl_reg.pas` | cxdsgn (design time) | `Register` (registration to the CX palette), the component editor, the processing that switches pages when the selection changes |
| `cpagecontrol_icon.lrs` | cxdsgn (design time) | Icons (9.1) |

- `uCPageControl` uses `uCTitleBar` (not the other way around).
- uses of `uCTitleBar`: `Windows` (only on Windows; written first so it does not hide `Rect` and `Point` of `Types`), `Classes, SysUtils, Types, Controls, ExtCtrls, Graphics, Forms, LCLType, LCLIntf, LMessages, LCLProc`. In implementation: `ShellApi` (on Windows), `LazUTF8`.
- uses of `uCPageControl`: `Windows` (same as above), `Classes, SysUtils, Types, Math, Controls, Graphics, Forms, StdCtrls, ExtCtrls, Menus, ComCtrls, ImgList, LCLType, LCLIntf, LMessages, LCLProc, uCTitleBar`.
- initialization of `uCPageControl`: `RegisterClass(TCTabSheet)`.
- uses of `uCPageControl_reg`: `Windows` (same as above), `Classes, SysUtils, Controls, Forms, LResources, ComponentEditors, PropEdits, uCTitleBar, uCPageControl`.

## 4. Usage Flow (Steps Without Writing Code)

1. Place a TCTitleBar on the form (`Align = alTop` is set automatically).
2. Place a TCPageControl on the form and set `Align = alClient`.
3. Set TCPageControl's `TitleBar` to the TCTitleBar → the tab strip moves into the title bar.
4. Right-click the TCPageControl and choose "New page" to create pages, then place components on them.
5. When placing a TToolBar or TSpeedButton on the title bar, place it with `Align = alLeft` or `alRight`. The tab strip fits into the remaining width between them.

When used on its own, skip steps 1 and 3. The tab strip appears above (or below) the TCPageControl.

---

## 5. TCPageControl

### 5.1 Screen Layout

```
[◀][Tab1][Tab2]…[Tabn][▶][＋]          [∨]
```

| Part | Condition for showing |
|---|---|
| [◀][▶] | Only when the total width of the tabs does not fit in the tab strip |
| [＋] | When `Options` contains `nboShowAddTabButton`. Immediately right of the last tab (right of [▶] when they do not fit) |
| [∨] | When `ShowTabListButton = True`. At the right end of the tab strip |
| [×] on each tab | When `Options` contains `nboShowCloseButtons`. Shown on all tabs |

There is only one row of tabs.

### 5.2 Properties

"LCL" column: ○ = same name, type and meaning as TPageControl; Original = original to this component.

| Name | Type | Default | Visibility | LCL | Description |
|---|---|---|---|---|---|
| `ActivePage` | `TCTabSheet` | nil | published | ○ | The page currently displayed |
| `ActivePageIndex` | `Integer` | -1 | public | ○ | Index of the displayed page (from 0) |
| `PageCount` | `Integer` | 0 | public (read) | ○ | Number of pages |
| `Pages[Index]` | `TCTabSheet` | ― | public (read) | ○ | A page |
| `TabIndex` | `Integer` | -1 | published | ○ | Same value as `ActivePageIndex` (both read and write are `FPageIndex` itself, as in LCL's TCustomTabControl) |
| `Images` | `TCustomImageList` | nil | published | ○ | Tab icons |
| `ImagesWidth` | `Integer` | 0 | published | ○ | Icon width (0 = the image list's width) |
| `TabPosition` | `TTabPosition` | `tpTop` | published | ○ | Only `tpTop` and `tpBottom`. `tpLeft` and `tpRight` are shown as `tpTop`. Not used when `TitleBar` is specified |
| `TabHeight` | `Smallint` | 0 | published (stored only when greater than 0) | ○ | Tab height (0 = automatic. 28 when standalone; title bar height − 6 inside the title bar; at 96dpi) |
| `TabWidth` | `Smallint` | 0 | published (stored only when greater than 0) | ○ | Tab width (0 = fit to the text. Upper limit is `TabMaxWidth`) |
| `Options` | `TCTabControlOptions` | `[nboShowCloseButtons, nboShowAddTabButton, nboKeyboardTabSwitch]` | published | ○ | See the table below. The default differs from LCL (LCL is `[]`), so that [×], [＋] and Ctrl+Tab work as soon as the control is placed |
| `TabShape` | `TCTabShape` | `tsRectangle` | published | Original | Tab shape. `tsRounded` rounds the upper corners (the lower corners when `TabPosition = tpBottom`) |
| `TabMaxWidth` | `Integer` | 240 | published | Original | Maximum tab width when `TabWidth = 0` (at 96dpi). Text beyond it becomes "…" |
| `ShowTabListButton` | `Boolean` | `True` | published | Original | Show [∨] |
| `NewPageCaption` | `string` | 'New Tab' | published (stored only when different from the default) | Original | Text of a tab created with [＋] or the menu |
| `TabMenuItems` | `TCTabMenuItems` | `[tmiNew, tmiClose, tmiRename]` | published | Original | Standard items shown in the right-click menu |
| `TabPopupMenu` | `TPopupMenu` | nil | published | Original | Application menu appended to the tab right-click menu |
| `TabListPopupMenu` | `TPopupMenu` | nil | published | Original | Application menu appended above the tab list |
| `PopupPage` | `TCTabSheet` | nil | public (read) | Original | Page of the right-clicked tab (nil for empty space) |
| `TitleBar` | `TCTitleBar` | nil | published | Original | Title bar on which the tab strip is placed |
| `TabStrip` | `TCTabStrip` | ― | public (read) | Original | The inner tab strip |
| `Color` | `TColor` | `clBtnFace` | published | Original | Background color of the tab strip (standalone). It is not published in TPageControl, but it is published here because the control draws itself |
| `ParentColor` | `Boolean` | `False` | published | ○ | |
| Others | ― | ― | published | ○ | `Align, Anchors, BorderSpacing, BiDiMode, Constraints, DragCursor, DragKind, DragMode, Enabled, Font, ParentBiDiMode, ParentFont, ParentShowHint, PopupMenu, ShowHint, TabOrder, TabStop, Visible` |

**Options (`TCTabControlOptions`. The LCL type is used as is)**

| Value | Behavior |
|---|---|
| `nboShowCloseButtons` | Show [×] on each tab |
| `nboShowAddTabButton` | Show [＋] |
| `nboKeyboardTabSwitch` | Switch tabs with Ctrl+Tab and Ctrl+Shift+Tab |
| `nboDoChangeOnSetIndex` | Also fire `OnChanging` and `OnChange` when `ActivePage`, `ActivePageIndex` or `TabIndex` is changed in code (if `OnChanging` cancels, no change is made). Without it, changes made in code do not fire them |
| `nboMultiLine` | Not used (only one row of tabs) |
| `nboHidePageListPopup` | Not used (the list is toggled with `ShowTabListButton`) |

**Types**

```pascal
TCTabShape = (tsRectangle, tsRounded);
TCTabMenuItem  = (tmiNew, tmiClose, tmiRename);
TCTabMenuItems = set of TCTabMenuItem;
TCNewPageEvent    = procedure(Sender: TObject; APage: TCTabSheet) of object;
TCPageCloseEvent  = procedure(Sender: TObject; APage: TCTabSheet; var CanClose: Boolean) of object;
TCPageRenameEvent = procedure(Sender: TObject; APage: TCTabSheet; var ACaption: string; var CanRename: Boolean) of object;
TCPageMovedEvent  = procedure(Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer) of object;
```

**Why `TabPopupMenu` is provided instead of `PopupMenu`**: LCL's `PopupMenu` appears on a right-click anywhere on the control, so the tab menu would also appear when right-clicking inside a page (an editor, etc.). A separate menu just for the tab strip is therefore provided. `PopupMenu` remains as in standard LCL.

resourcestring (interface): `rsCTabNew = 'New Tab'`, `rsCTabClose = 'Close Tab'`, `rsCTabRename = 'Rename Tab'`, `rsCTabNewPageCaption = 'New Tab'`, `rsCTabCannotHaveParent = 'Only a TCPageControl can be the parent of %s (%s cannot be specified)'`

### 5.3 Methods

| Name | LCL | Description |
|---|---|---|
| `function AddTabSheet: TCTabSheet` | ○ | Creates it with its own Owner as Owner (itself if none), sets `Caption := NewPageCaption`, `Parent := Self` (goes to the end). Does not change the displayed page (only when there were 0 pages does the first page become displayed, as in LCL). Does not fire `OnNewPage` |
| `function FindNextPage(CurPage: TCTabSheet; GoForward, CheckTabVisible: Boolean): TCTabSheet` | ○ | The next (previous) page. At an end it wraps to the other side. If `CurPage` is not found, counting starts from the beginning when going backward and from the end when going forward. nil if nothing is found after a full cycle |
| `procedure SelectNextPage(GoForward: Boolean)` | ○ | `SelectNextPage(GoForward, True)` |
| `procedure SelectNextPage(GoForward: Boolean; CheckTabVisible: Boolean)` | ○ | If the page found by `FindNextPage` differs from the current one, `ActivePage := page` |
| `function IndexOfTabAt(X, Y: Integer): Integer` / `(P: TPoint)` | ○ | Converts the coordinates to tab strip coordinates (`- FStrip.Left`, `- FStrip.Top`) and returns the `TabIndex` of the visible tab. -1 if none |
| `function IndexOfPageAt(X, Y: Integer): Integer` / `(P: TPoint)` | ○ | Likewise, the `PageIndex` of that tab |
| `function IndexOf(APage: TPersistent): Integer` | ○ | `FPages.IndexOf` (-1 if `FPages` is nil) |
| `procedure Clear` | ○ | While `FClearing := True`, `Free`s all pages from the back. `FPageIndex := -1`, `PageChanged`. If a page was displayed and it is not loading, at design time or being destroyed, calls `Change`. Does not fire `OnPageClose` |
| `function TabRect(AIndex: Integer): TRect` | ○ | `AIndex` is the page index. Returns the tab strip's `TabRectOf` shifted by the tab strip's position. Empty if not visible |
| `procedure EditPageCaption(APage: TCTabSheet)` | Original | Does nothing if the page does not exist or is hidden. If editing is in progress, commits it first. `EnsureVisible`, `BeginEdit` (5.5.4) |

- Coordinates are those of the control that holds the tab strip (TCPageControl when standalone, TCTitleBar when `TitleBar` is specified).
- As in LCL, a page is deleted with `APage.Free` and reordered with `APage.PageIndex := n`. Neither fires `OnPageClose` or `OnPageMoved` (they fire only for on-screen operations).

### 5.4 Events

| Name | Type | LCL | When fired |
|---|---|---|---|
| `OnChange` | `TNotifyEvent` | ○ | After the displayed page has changed |
| `OnChanging` | `TTabChangingEvent` | ○ | Before the displayed page changes. `AllowChange := False` cancels |
| `OnGetImageIndex` | `TTabGetImageEvent` | ○ | Before a tab is drawn (inside `GetImageIndex`). For changing the icon |
| `OnNewPage` | `TCNewPageEvent` | Original | After a tab is created with [＋] or the right-click menu |
| `OnPageClose` | `TCPageCloseEvent` | Original | Before closing with [×], the right-click menu, or [×] in the tab list. `CanClose := False` cancels |
| `OnPageRename` | `TCPageRenameEvent` | Original | Before the text is committed in in-place editing. `ACaption` can be rewritten. `CanRename := False` cancels |
| `OnPageMoved` | `TCPageMovedEvent` | Original | After a tab has been moved by dragging |
| `OnContextPopup`, `OnDragDrop`, `OnDragOver`, `OnEndDrag`, `OnEnter`, `OnExit`, `OnMouseDown`, `OnMouseEnter`, `OnMouseLeave`, `OnMouseMove`, `OnMouseUp`, `OnMouseWheel`, `OnMouseWheelDown`, `OnMouseWheelUp`, `OnResize`, `OnStartDrag` | ― | ○ | Standard |

**Why LCL's `OnCloseTabClicked` is not provided**: It only notifies that "[×] was clicked", and closing is left to the application. That does not fit the goal of using the control without writing code, so [×] closes automatically and `OnPageClose` is used only when you want to cancel. It is not provided, to avoid a design where the same thing can be done in two ways.

### 5.5 Behavior

#### 5.5.1 Creating a Tab (DoAddButtonClick)

1. If `CanChange` is `False` (canceled by `OnChanging`), nothing is created.
2. `TCTabSheet.Create` with its own Owner as Owner (itself if none), `Caption := NewPageCaption`, `Parent := Self` (goes to the end).
3. If it is not displayed, `InternalSetPageIndex(index of the new page)`.
4. `FStrip.EnsureVisible(new page)`, `Change` (`OnChange`), `OnNewPage`.

The right-click menu "New Tab" (`DoMenuNewClick`) works the same way.

#### 5.5.2 Closing a Tab (ClosePageByUser)

| Operation | Target |
|---|---|
| [×] of a tab (`DoCloseButtonClick`) | That tab (closed without switching to it) |
| Right-click "Close Tab" (`DoMenuCloseClick`) | The right-clicked tab |
| [×] in the tab list (`DoTabListCloseClick`) | The tab of that row |

Procedure: finish if there is no page → `OnPageClose` with `CanClose := True` → if `True`, `Free` the page.

- `Free` calls `RemovePage` (5.6). When the displayed tab is closed, the tab on its right (or on its left if none) is displayed and `OnChange` is fired (`OnChanging` is not fired, because the closing has already been decided).
- Having 0 pages is allowed (same as TPageControl).

#### 5.5.3 Right-Click Menu (ShowTabMenu)

| Right-click location | Items shown |
|---|---|
| On a tab | "New Tab", "Close Tab", "Rename Tab" (only those in `TabMenuItems`) → separator → items of `TabPopupMenu` |
| Empty part of the tab strip (standalone) | "New Tab" → separator → items of `TabPopupMenu` |
| Empty part of the tab strip inside the title bar | The standard Windows system menu (empty space is treated the same as the title bar. 7.5) |

Procedure:

1. `FPopupPage := APage` (nil for empty space). A right-click does not switch the tab to displayed.
2. Clear and rebuild the items of the menu `FMenu` (created if absent). Standard items follow `TabMenuItems` ("Close Tab" and "Rename Tab" only when on a tab).
3. If `TabPopupMenu` has items, call `TabPopupMenu.OnPopup` first (so the application can change item states). If there are standard items, add a separator. `FMenu.Images := TabPopupMenu.Images`, `CopyMenuItems`.
4. If there are 0 items, do not show. Set `PopupComponent := Self` and `Popup`.

`CopyMenuItems`: makes a copy of each source item, copying `Caption`, `Enabled`, `Visible`, `Checked`, `RadioItem`, `GroupIndex`, `ImageIndex`, `ShortCut`, `Hint` and `Default`. The source item is stored in `Tag`. Children are copied too. Leaf items that are not separators get `OnClick := MenuAppItemClick` (→ `DoAppMenuItemClick(source item, FPopupPage)` → `FPopupPage := APage`, `AItem.Click`. The `Sender` of `OnClick` is the source item, and the source item's `Action` is what runs).

#### 5.5.4 Renaming a Tab (In-Place Editing)

- Started by the right-click "Rename Tab" (`DoMenuRenameClick`) or by `EditPageCaption`.
- `TCTabStrip.BeginEdit(APage)`: overlays a `TEdit` (`bsSingle`, Font is TCPageControl's Font) on the tab's text area (the range excluding the icon and [×]; minimum width 40), fills in the current text, focuses it and selects all. The tab's text is not drawn.
- Enter, or focus leaving the edit box, commits (`DoEditCaptionConfirm(text of the edit box)`); Esc cancels (`DoEditCaptionCancel`).
- Commit: finish if not editing. Remember the page and `EndEdit`. If the text is empty, do nothing (stays as it was). `OnPageRename(Page, S, CanRename)` with `CanRename := True`. If `CanRename` is set and `S` is not empty, `Caption := S`.
- A left-click on the tab strip during editing also commits first.
- `EndEdit` hides the edit box and frees it later with `Application.QueueAsyncCall(FreeEditAsync)` (so that it is not freed from inside the edit box's own event).

#### 5.5.5 Moving by Dragging

- At the moment the left button is pressed on a tab, that tab becomes the displayed one (`DoTabClick`). If it is canceled and does not become displayed, no drag is started. Once displayed, the page to drag and the pressed position are remembered.
- Dragging starts when the mouse moves `Mouse.DragThreshold` or more. `Application.AddOnKeyDownBeforeHandler(DragKeyDown)` is attached and the auto-scroll timer (50ms) is started.
- During the drag, a vertical `clHighlight` line (width 2) is drawn at the drop position (`DropIndexAt`: if left of the center of a visible tab, before that tab; if none applies, the end).
- Auto-scroll: when the mouse is within `CPC_AUTOSCROLL` of the left or right end of the visible range of the tab strip, it scrolls by 10 (at 96dpi) at a time and recomputes the drop position.
- On release (`FinishDrag`): end the drag (`CancelDrag`); if outside the tab strip, do nothing. Convert the drop position to a page index (`PageCount` for the end), and subtract 1 if it is after the original index. If it is the same, do nothing. After `MovePage(page, new index)`, `OnPageMoved(page, original index, new index)`.
- Esc during a drag: `Key := 0`, `CancelDrag` (detach key reception, restore state, `MouseCapture := False`).
- This is a mechanism separate from LCL's `DragMode` and `DragKind` (drag and drop to other components).

#### 5.5.6 Scrolling

- Pressing [◀] or [▶] scrolls one tab at a time (`ScrollStep`: for [▶], align to the right edge of the first tab whose right edge exceeds the visible range; for [◀], align to the left edge of the last tab whose left edge is left of the visible range). Holding repeats (first after 400ms, then every 100ms).
- Turning the mouse wheel over the tab strip scrolls (only when the tabs do not fit; up is the same as [◀], down is the same as [▶]).
- When the displayed tab changes or the width of the tab strip changes, it scrolls until the displayed tab is visible (`EnsureVisible`).
- A button that has reached the end is shown disabled.

#### 5.5.7 Tab List ([∨])

- Pressing [∨] shows the list below the tab strip (aligned to the right end of [∨]) (`ShowTabList`. Does nothing at design time. Closes it if shown). A press right after the list closed (within 300ms) is treated as the closing operation and does not reopen it.
- From the top: items of `TabListPopupMenu` (items with children are not shown) → separator → all tabs (in order; icon + text + [×]).
- The row of the displayed tab is bold.
- Pressing a row → `DoTabListItemClick` (makes that tab the displayed one) and closes the list.
- Pressing [×] of a row → `DoTabListCloseClick` (5.5.2). The list stays open and the row is removed (so tabs can be closed consecutively).
- Pressing an item of `TabListPopupMenu` → `Click` of the source item, and the list closes.
- Pressing outside the list (the list becomes inactive), or Esc → closes the list.
- The width is 300 (at 96dpi). The height fits the number of rows (including the border). A vertical scrollbar appears only when it does not fit on the screen (`TCTabListView` is placed inside a `TScrollBox`).
- The row width is re-fitted to the inner width of the window after the window is shown (`DoShow`) and when the window size changes (`ScrollResize`) (because the window width is not yet reflected before showing on the first open).
- `TCTabListPopup` creates a `TCustomForm` with `CreateNew(nil)`: `BorderStyle := bsNone`, `ShowInTaskBar := stNever`, `FormStyle := fsStayOnTop`, `KeyPreview := True`, and the border is drawn with the form's `BorderWidth := 1` and `Color := clBtnShadow`. Inside it are a `TScrollBox` (`alClient`, no border, no horizontal scrolling, `clWindow`) and a `TCTabListView`. `CreateParams` sets `WS_POPUP` and `WS_EX_TOOLWINDOW`, and makes `WndParent` the form of the TCPageControl. `DoShow` rounds the corners by calling `DwmSetWindowAttribute(Handle, 33 {DWMWA_WINDOW_CORNER_PREFERENCE}, DWMWCP_ROUND)` from `dwmapi.dll`.
- The list is a window owned by the form, so the title bar is kept looking active even when focus moves to the list (`WM_ACTIVATE` in 7.4).

#### 5.5.8 Keyboard (KeyDownBefore)

Received through `Application.AddOnKeyDownBeforeHandler` (it arrives before the focused component).

1. Do nothing if any of these holds: `nboKeyboardTabSwitch` is absent, the key is not Tab, the Shift state is not `[ssCtrl]` or `[ssCtrl, ssShift]`, or there are 0 pages.
2. Do nothing unless `IsKeyTarget(Sender)`.
3. If the form's `KeyPreview` is `True`, call the form's `KeyDown` first. If `Key = 0` afterwards, do nothing (the application's handling takes priority).
4. Use `FindNextPage` to find the next (previous if Shift) page with `TabVisible`. `Key := 0`. If found and different from the current one, `UserSelectPage` (`OnChanging`, `OnChange`).

`IsKeyTarget(AFocused)`:

- Premises: it is visible and usable, `AFocused` is a `TControl`, and it is on the same form.
- `True` if it contains the focused component.
- `False` if another TCPageControl contains it (that one receives it).
- If no TCPageControl contains it, the first visible TCPageControl found in the form's `Components` receives it.

- When a component using WebView2 (TCMonacoEditor, TCTabBrowser, etc.) has focus, the key is received by the browser side and does not arrive.
- Enter and Esc during in-place editing also reach the form's `OnKeyDown` first when `KeyPreview = True`. If `Key := 0` is set there, commit and cancel do not work (stated in the user manual).

### 5.6 Internal Procedures

| Procedure | Processing |
|---|---|
| `Create` | Removes `csAcceptsControls` (components cannot be placed on TCPageControl itself; a placed component goes into the displayed page) and `csSetCaption` from `ControlStyle`. `FPages`, defaults, `FImageChangeLink`, `Color := clBtnFace`, `ParentColor := False`, `TabStop := True`. The tab strip `FStrip := TCTabStrip.Create(Self)`, `Align := alTop`, `Parent := Self`. Default size 300 × 200 (`GetControlClassDefaultSize`). If not at design time, `AddOnKeyDownBeforeHandler(KeyDownBefore)` |
| `Destroy` | Detaches key reception. Frees the tab list. With `FClearing := True`, `Free`s all pages from the back. Frees `FPages`. If the tab strip is on the title bar, `Parent := nil`. Frees `FImageChangeLink`. `inherited` |
| `SetActivePage(v)` | Does nothing if `v` is not a page of this component. `SetActivePageIndex(IndexOf(v))` |
| `SetActivePageIndex(v)` | Does nothing if out of range or the same. While loading, only `FPageIndex := v`. If `nboDoChangeOnSetIndex` is set and `CanChange` is `False`, does nothing. `InternalSetPageIndex(v)`. If not at design time, loading or being destroyed and `nboDoChangeOnSetIndex` is set, `Change` |
| `InternalSetPageIndex(v)` | Changes the displayed page without firing events. `FPageIndex := v`, `UpdateDesignerFlags`, and unless loading, `ShowCurrentPage(previous index)`. If a page is displayed, `LayoutTabs`, `EnsureVisible`. Redraws the tab strip and the tab list |
| `ShowCurrentPage(Old)` | Sets the new page `Visible := True`. If a component of the previous page has focus and it is runtime, moves focus to the first component of the new page (`FindNextControl`), or to itself if there is none. Sets the other pages `Visible := False`. `RefreshShowing` on all pages |
| `UpdateDesignerFlags` | Removes `csNoDesignVisible` only from the displayed page and adds it to the others (same as LCL) |
| `CanChange` | Unless at design time or being destroyed, calls `OnChanging` and returns its result |
| `Change` | Unless loading or being destroyed, `OnChange` |
| `PageChanged` | Unless being destroyed, `FStrip.LayoutTabs` and redraws the tab list (when text, icons or settings change) |
| `GetImageIndex(i)` | -1 if out of range. Sets the page's `ImageIndex` and calls `OnGetImageIndex` |
| `UserSelectPage(P)` | Displays by an on-screen operation. Does nothing if absent or the same. At design time, see chapter 9. At runtime, `CanChange` → `InternalSetPageIndex` → `Change` |
| `InsertPage(P)` | Finishes if already present. Appends to the end. If no page is displayed, makes this page the displayed one (`ShowCurrentPage` unless loading). `UpdateDesignerFlags`, `PageChanged` |
| `RemovePage(P)` | Finishes if absent. `FStrip.PageRemoved(P)` (clears mouse, drag and edit state). If `FPopupPage` is `P`, nil. Removes it from the list. If being destroyed, finishes here. Immediately `LayoutTabs` (so the tab strip does not keep drawing or inspecting a page that has disappeared). If it was the displayed page: during `Clear`, -1; otherwise `InternalSetPageIndex` with the index from `FindVisibleNear`; unless during `Clear`, loading or at design time, `Change`. If it was a page before the displayed one, decrements `FPageIndex` by 1. `UpdateDesignerFlags`, `PageChanged`, and `Invalidate` if no page is displayed |
| `FindVisibleNear(i)` | The first `TabVisible` page after `i`; if none, the last `TabVisible` page before `i`; if none, -1 |
| `MovePage(P, n)` | Clamps `n` to `0..PageCount-1`, finishes if the same. `FPages.Move`, re-aligns the index of the displayed page. `UpdateDesignerFlags`, `PageChanged`, and at design time `OwnerFormDesignerModified` |
| `SetTitleBar(v)` | Finishes if the same. Removes the notification from the previous one. If `v` already has another TCPageControl's tab strip, sets that TCPageControl's `TitleBar := nil` (only one per title bar). Attaches notification, assigns, and `UpdateStripPlace` |
| `UpdateStripPlace` | If there is a title bar, the tab strip gets `Align := alNone`, `Parent := TitleBar`, `TitleBar.ReAlign`. Otherwise `Parent := Self`, `alBottom` if `TabPosition = tpBottom`, `alTop` otherwise. If the previous parent was a title bar and has changed, `ReAlign` the previous parent. `Visible := True`, `LayoutTabs`. If the placement changed, `ReAlign` itself, `Invalidate`, `ShowCurrentPage(-1)` (so that only a frame does not remain on the TCPageControl when the title bar is removed) |
| `Notification` | On `opRemove`, for `Images` `SetImages(nil)`; for `TabPopupMenu` and `TabListPopupMenu` nil; for `TitleBar` nil and `UpdateStripPlace` |
| `GetChildren` | Passes the pages whose Owner is `Root`, in order (since `PageIndex` is not stored, the order in the .lfm becomes the order) |
| `Loaded` | `inherited`. If no page is displayed and there are pages, 0; if out of range, the end. `UpdateDesignerFlags`, `ShowCurrentPage(-1)`, `UpdateStripPlace` |
| `Paint` | Fills the whole with `clWindow` if no page is displayed, otherwise with `Color` (so that the extent of the component is visible even with 0 pages) |
| `SetImages` | Removes the change and free notifications from the previous one and attaches them to the new one. `PageChanged` |
| `SetTabHeight`, `SetTabWidth` | 0 if negative. `PageChanged` if changed |
| `SetTabMaxWidth` | 1 if less than 1. `PageChanged` if changed |
| `SetImagesWidth`, `SetOptions`, `SetShowTabListButton`, `SetTabShape` | `PageChanged` if changed |
| `SetTabPosition` | `UpdateStripPlace` if changed |
| `CMFontChanged` | `PageChanged` |
| `CMColorChanged` | Redraws the tab strip and itself |
| `DoAutoAdjustLayout` | When the display scale changes, adjusts the stored `TabHeight` and `TabWidth` to the scale (`TabMaxWidth` stays based on 96dpi). `PageChanged` |

### 5.7 Display (sizes at 96dpi. Scaled with `CXScale96`)

| Constant | Value | Description |
|---|---|---|
| `CPC_PAD` | 8 | Left and right margin of a tab |
| `CPC_ICON_GAP` | 4 | Gap between icon and text |
| `CPC_CLOSE_SIZE` | 16 | Area of [×] |
| `CPC_CLOSE_HIT` | 20 | Clickable range of [×] |
| `CPC_CLOSE_GAP` | 4 | Gap between text and [×] |
| `CPC_TAB_MIN` | 60 | Minimum tab width |
| `CPC_ARROW_W` | 24 | Width of [◀][▶] |
| `CPC_BUTTON_W` | 28 | Width of [＋][∨] |
| `CPC_TAB_GAP` | 2 | Gap between tabs |
| `CPC_RADIUS` | 6 | Corner radius |
| `CPC_TAB_H` | 28 | Default tab height when standalone |
| `CPC_TITLE_GAP` | 6 | Tab height inside the title bar = title bar height − 6 |
| `CPC_SYMBOL` | 10 | Glyph height of symbols |
| `CPC_SYMBOL_S` | 8 | Glyph height of the [×] symbol |
| `CPC_LIST_W` | 300 | Width of the tab list |
| `CPC_LIST_ROW` | 28 | Height of one row of the tab list |
| `CPC_AUTOSCROLL` | 20 | Distance from the edge at which auto-scroll during a drag begins |

Symbol glyph codes: `SYM_LEFT = $E76B`, `SYM_RIGHT = $E76C`, `SYM_ADD = $E710`, `SYM_DOWN = $E70D`, `SYM_CLOSE = $E8BB`.

### 5.8 Colors (all system colors. MetaDarkStyle switches them for dark mode)

| Part | Color |
|---|---|
| Tab strip background | Standalone: `Color` of TCPageControl. Inside the title bar: `Color` of TCTitleBar |
| Displayed tab | `clWindow`, text `clWindowText` |
| Non-displayed tab | No background (the tab strip background), text `clBtnText` |
| Tab or button under the mouse | The background color blended with 10% `clBtnText` (`CXBlendColor`) |
| While pressed | The background color blended with 20% `clBtnText` |
| When the mouse is over [×] | Only the 16 × 16 area of [×], the tab's background (the tab strip's background if none) blended with 20% `clBtnText` (the shape follows `TabShape`) |
| Hidden tab at design time | Text `clGrayText` |
| When `Font.Color` is specified | If other than `clDefault` and `clWindowText`, the text is drawn in that color |
| Vertical line during a drag | `clHighlight` |
| Disabled button | Symbol `clGrayText` |
| Page background | `Color` of TCTabSheet (default `clWindow`) |
| Page area when there are 0 pages (no displayed page) | `clWindow` |

- A `tsRounded` tab is filled with `RoundRect`, and then the corners on the page side (the lower side for an upper tab) are repainted as a rectangle.
- The button symbols (◀ ▶ ＋ ∨ ×) are drawn with glyphs of Segoe Fluent Icons (or Segoe MDL2 Assets if absent) (so they do not blur at any scale). When drawing, `CXSetSymbolFont` puts only the name and height (in pixels) into a new font setting and copies it to the Canvas (in a design that rewrites the name and height of a Canvas to which TCPageControl's Font was copied, changing the Font size does not change the symbol height, and only the middle of the large symbol is cut off and looks like a dot). If neither font exists, they are drawn with lines.

### 5.9 What TPageControl Has but TCPageControl Does Not

| Name | Reason it is not provided |
|---|---|
| `MultiLine` | Only one row of tabs |
| `RaggedRight` | It specifies the arrangement when there are multiple rows |
| `ScrollOpposite` | It specifies the arrangement when there are multiple rows |
| `Style` (`tsTabs`, `tsButtons`, `tsFlatButtons`) | The appearance is decided by `TabShape` |
| `HotTrack` | A tab under the mouse always changes color |
| `ShowTabs` | Hiding the tab strip is out of scope |
| `OnCloseTabClicked` | [×] closes automatically, and cancelling is done with `OnPageClose` (5.4) |
| `DockSite`, `OnDockDrop`, `OnDockOver`, `OnEndDock`, `OnStartDock`, `OnUnDock`, `OnGetDockCaption`, `OnGetSiteInfo` | Docking is out of scope |

### 5.10 Handling of Operations (protected, virtual)

Processing for mouse and key operations is gathered into the following methods. The tab strip (TCTabStrip) just calls these when it receives mouse or key input and holds no processing.

| Method | Operation that calls it | Processing |
|---|---|---|
| `DoTabClick(APage)` | Left-click on a tab | `UserSelectPage(APage)` |
| `DoAddButtonClick` | [＋] | 5.5.1 |
| `DoCloseButtonClick(APage)` | [×] of a tab | `ClosePageByUser` (5.5.2) |
| `DoMenuNewClick` | Right-click "New Tab" | `DoAddButtonClick` |
| `DoMenuCloseClick(APage)` | Right-click "Close Tab" | `ClosePageByUser` |
| `DoMenuRenameClick(APage)` | Right-click "Rename Tab" | `EditPageCaption(APage)` |
| `DoAppMenuItemClick(AItem, APage)` | An item of `TabPopupMenu` in the right-click menu | `PopupPage := APage`, `AItem.Click` |
| `DoTabListItemClick(APage)` | A row of the tab list | `UserSelectPage(APage)` |
| `DoTabListCloseClick(APage)` | [×] of a row of the tab list | `ClosePageByUser` |
| `DoEditCaptionConfirm(AText)` | Enter or focus lost during name editing | Commit in 5.5.4 |
| `DoEditCaptionCancel` | Esc during name editing | `EndEdit` |

---

## 6. TCTabSheet

| Name | Type | Default | Visibility | LCL | Description |
|---|---|---|---|---|---|
| `Caption` | `TCaption` | '' | published | ○ | Tab text |
| `ImageIndex` | `TImageIndex` | -1 | published | ○ | Icon index (-1 = none) |
| `PageIndex` | `Integer` | ― | published (not stored) | ○ | Position of the page. Writing it calls `MovePage`. It is not stored, same as LCL; the order is decided by the order of pages written in the .lfm |
| `TabVisible` | `Boolean` | `True` | published | ○ | `False` hides the tab (the page remains) |
| `TabIndex` | `Integer` | ― | public (read) | ○ | Index counted over visible tabs only (-1 if hidden) |
| `PageControl` | `TCPageControl` | ― | public | ○ | The TCPageControl it belongs to (writing sets `Parent := value`) |
| `Color` | `TColor` | `clWindow` | published | Original | Page background color. It is not published in TTabSheet, but it is published here because the control draws itself |
| `ParentColor` | `Boolean` | `False` | published | ○ | |
| `Left`, `Top`, `Width`, `Height` | ― | ― | published (not stored) | ○ | The size is decided by TCPageControl |
| Others | ― | ― | published | ○ | `BorderWidth, ChildSizing, ClientHeight, ClientWidth, Enabled, Font, ParentFont, ParentShowHint, PopupMenu, ShowHint, OnContextPopup, OnDragDrop, OnDragOver, OnEndDrag, OnEnter, OnExit, OnHide, OnMouseDown, OnMouseEnter, OnMouseLeave, OnMouseMove, OnMouseUp, OnMouseWheel, OnMouseWheelDown, OnMouseWheelUp, OnResize, OnShow, OnStartDrag` |

**ControlStyle (same as LCL's TCustomPage and TCustomTabControl)**

| Component | ControlStyle | Meaning |
|---|---|---|
| TCTabSheet | Adds `csAcceptsControls`, `csDesignFixedBounds`, `csNoDesignVisible`, `csNoFocus` | Components can be placed only on pages. Pages cannot be moved or resized at design time |
| TCTabSheet (displayed page) | Removes `csNoDesignVisible` (`UpdateDesignerFlags`) | Only the displayed page is shown on the design surface |
| TCPageControl | Removes `csAcceptsControls` | Components cannot be placed on TCPageControl itself |

**Procedures**

| Procedure | Processing |
|---|---|
| `Create` | The ControlStyle above, `FImageIndex := -1`, `FTabVisible := True`, `Color := clWindow`, `ParentColor := False`, `Align := alClient`, `Caption := ''`, `Visible := False` |
| `Destroy` | If the parent is a TCPageControl, `Parent := nil` (removes it from the list), `inherited` |
| `SetParent(v)` | Finishes if the same. If `v` is neither nil nor a TCPageControl, `EInvalidOperation` (`rsCTabCannotHaveParent`). `RemovePage` from the previous parent, `inherited SetParent`, `InsertPage` into the new parent |
| `GetTabIndex` | -1 if there is no parent or it is hidden. Otherwise the number of visible pages before it |
| `SetImageIndex` | `PageControl.PageChanged` if changed |
| `SetTabVisible(v)` | Assigns if changed. At runtime (not design time or loading), when the displayed page is hidden, `InternalSetPageIndex` to the page from `FindVisibleNear` and `Change` (same as LCL). When shown while no page is displayed, makes that page the displayed one and `Change`. Finally `PageChanged` |
| `IsControlVisible`, `HandleObjectShouldBeVisible` | If `inherited` is `True` and the parent is a TCPageControl, `True` only for the displayed page (same as LCL's TCustomPage; so that the form display also changes when `ActivePage` is changed at design time) |
| `RefreshShowing` | Unless being destroyed, `UpdateControlState`, `Invalidate` |
| `Paint` | Fills the whole with `Color` |
| `CMVisibleChanged` | After `inherited`, `OnShow` when it becomes visible, `OnHide` when hidden |
| `CMTextChanged` | `PageControl.PageChanged` |

**Handling of non-displayed pages** (same as LCL's `TCustomTabControl.ShowCurrentPage`)

- The displayed page gets `Visible := True` and the others `Visible := False` (`ShowCurrentPage` in 5.6).
- No original mechanism is built (such as keeping the window and placing it at an invisible position).
- TCMonacoEditor waits without creating WebView2 until it is shown (Showing), and keeps the body text etc. set until then inside the component. Therefore, even if it is placed on a non-displayed page, it starts when first displayed and works correctly.

---

## 7. TCTitleBar

### 7.1 Properties

| Name | Type | Default | Description |
|---|---|---|---|
| `Align` | `TAlign` | `alTop` | Fixed to `alTop` (other values are ignored in `SetAlign`) |
| `Height` | `Integer` | 40 (96dpi) | Title bar height (`GetControlClassDefaultSize` is 300 × 40) |
| `Color` | `TColor` | `clBtnFace` | Background color |
| `ParentColor` | `Boolean` | `False` | |
| `Caption` | `TCaption` | '' | Text shown on the title bar (7.2). If empty, the form's `Caption`. If both are empty, nothing is shown. The taskbar always shows the form's `Caption` |
| `Font` | `TFont` | ― | Text of `Caption` |
| `BevelOuter` | `TPanelBevel` | `bvNone` | Border |
| `Hooked` | `Boolean` | ― | public (read). Whether it has been built into the form |
| Others | ― | ― | `Anchors, BevelInner, BevelWidth, BorderSpacing, Constraints, Enabled, ParentFont, ParentShowHint, PopupMenu, ShowHint, Visible, OnClick, OnDblClick, OnMouseDown, OnMouseEnter, OnMouseLeave, OnMouseMove, OnMouseUp, OnResize` |

`Create`: adds `csAcceptsControls` to and removes `csSetCaption` from `ControlStyle`. `Align := alTop`, `BevelOuter := bvNone`, `Color := clBtnFace`, `ParentColor := False`, active display, `Caption := ''`, default size. `Destroy`: `Application.RemoveAsyncCalls(Self)`.

The only original property, method or event is `Hooked`. The public `FormActivated`, `FormCaptionChanged`, `FormStateChanged`, `SetMaxButtonHot`, `SetMaxButtonDown`, `MaxButtonScreenRect`, `ScreenPointInSelf` and `IsDragPointScreen` are called from the window interception processing (the application does not use them).

Whether the minimize, maximize and close buttons exist follows the form's `BorderIcons` (`ButtonState`).

| `BorderIcons` | Minimize | Maximize | Close |
|---|---|---|---|
| `biSystemMenu`, `biMinimize`, `biMaximize` | Shown | Shown | Shown |
| `biSystemMenu`, `biMinimize` | Shown | Shown disabled (cannot be pressed) | Shown |
| `biSystemMenu`, `biMaximize` | Shown disabled (cannot be pressed) | Shown | Shown |
| `biSystemMenu` only | Not shown | Not shown | Shown |
| No `biSystemMenu` | Not shown | Not shown | Not shown |

- Types: `TCTitleButton = (ctbNone, ctbMinimize, ctbMaximize, ctbClose)`, `TCTitleButtonState = (ctsHidden, ctsDisabled, ctsEnabled)`.
- A disabled button has its symbol drawn in `clGrayText` and does not change color when the mouse is over it.
- Without `biMaximize`, a double-click on empty space does not maximize, and the maximize button does not show the snap layout (same as standard Windows).

### 7.2 Screen Layout

```
[alLeft components…][Caption][Tab strip (when TitleBar is specified)][alRight components…][─][□][×]
```

- The area for the minimize, maximize and close buttons (each width 46 × the title bar height, at 96dpi) is reserved at the right end. `AdjustClientRect` removes the button area from the right, so `alRight` components line up to its left.
- The caption area is placed immediately to the right of the `alLeft` components. `AdjustClientRect` also removes the caption width from the left.
- The tab strip (TCTabStrip) becomes a child of TCTitleBar when linked through `TitleBar`. TCTitleBar decides its position inside `AlignControls` (`Align` is `alNone`; from the right of the caption to the left of the `alRight` components). TCTitleBar treats the child that has `ICTitleBarDragArea` as the tab strip. `AlignControls` is not reentrant (`FAligning`).

**Caption**

| Item | Description |
|---|---|
| Text shown (`DisplayCaption`) | `Caption` if not empty. If empty, the `Caption` of the form (`GetParentForm`). If both are empty, nothing is shown |
| Width (`CaptionWidthFor`) | Text width + left and right margin 8 (96dpi). Upper limit 200 (96dpi). Text beyond it ends with "…". Width 0 when there is no text to show |
| Position | Vertically centered, left-aligned |
| Text | `Font`. The color is `clGrayText` when the form is inactive (except at design time), `clBtnText` when `Font.Color` is `clDefault` or `clWindowText`, otherwise `Font.Color` |
| Change of the form's `Caption` | When built in, after processing the intercepted `WM_SETTEXT` as usual, `FormCaptionChanged` (recomputes the width, re-aligns and redraws). At design time, the form's `Caption` is read at every paint, and if the width has changed, re-aligns with `Application.QueueAsyncCall(AsyncRealign)` |
| Mouse | Same as empty space (7.5) |

- Why the caption is placed to the left of the tab strip: the tab strip extends to the right and [∨] is attached at its right end. Placing the caption in the center or on the right would make them overlap when tabs increase.
- Why the form's `Caption` is shown when `Caption` is empty: an application that puts a file name etc. into the form's `Caption` can show it on the title bar without writing code. It also matches the name on the taskbar.

Constants (96dpi): `CTB_BUTTON_W = 46`, `CTB_CAPTION_PAD = 8`, `CTB_CAPTION_MAX = 200`, `CTB_SYMBOL_H = 10`, `CTB_DEFAULT_H = 40`.

### 7.3 Building into the Form (Windows Only)

- Conditions for building in (`CanHookForm`): runtime (not design time), `Parent` is a form (`TCustomForm`), the form's `BorderStyle` is `bsSizeable` or `bsSingle`, the form has a handle, no other TCTitleBar directly under the form has built in yet (even if there are two in the .lfm, only the first builds in; the second is a plain panel), and `SetWindowSubclass` etc. can be loaded.
- When it is built in: when the TCTitleBar's window is created (`CreateWnd`). When the form's window is recreated its children are recreated too, so it is built in again each time.
- `CreateWnd`: after `inherited`, at runtime and if the API can be loaded, intercepts its own window (`SUBCLASS_ID_SELF = $43544253`), `HookForm`, `ReAlign`.
- `HookForm`: finishes if already built in or `CanHookForm` is `False`. Intercepts the form's window with `SetWindowSubclass` (`SUBCLASS_ID_FORM = $43544246`) (no conflict even if the application uses `Form.WindowProc`). On success, `FHooked := True`, remembers whether it is active via `GetActiveWindow`, and `FrameChanged`.
- `DestroyWnd`: `UnhookForm` (removes the interception and `FrameChanged`), also removes the interception of its own window, and `inherited`.
- `FrameChanged`: makes the frame recomputed with `SetWindowPos(SWP_FRAMECHANGED or SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE)`, then, unless minimized, the form's `InvalidateClientRectCache(True)`, sends `WM_SIZE` with the current client size (`SIZE_MAXIMIZED` when maximized, `SIZE_RESTORED` otherwise), and `ReAlign`. This is because `SWP_FRAMECHANGED` alone does not change the window size, so `WM_SIZE` does not arrive, LCL lays out components with the previous size, and a margin remains below the form. The same applies when it is removed and when the screen scale changes (`WM_DPICHANGED`).
- When it is removed: when the TCTitleBar's window is destroyed (`DestroyWnd` → `UnhookForm`). It is also removed when the form's window receives `WM_NCDESTROY`.
- It is not built in at design time. The buttons are drawn in the inactive appearance, and only the layout can be checked.
- `SetWindowSubclass`, `RemoveWindowSubclass` and `DefSubclassProc` are looked up by name in `comctl32.dll`, and by ordinal (410, 412, 413) if not found (`LoadSubclassApi`). `GetSystemMetricsForDpi` and `GetDpiForWindow` are looked up in `user32.dll` (if absent, `GetSystemMetrics` and the screen DPI are used).

**Only one per form**

- At design time (when the new parent is at design time): when a second one is about to be placed, `SetParent` raises the exception "Only one TCTitleBar can be placed on a form" (`rsCTitleBarOnlyOne`) and cancels the placement. This is checked whether the destination (`Parent`) is a form, a TCTitleBar, a panel or anything else. It traverses all components in the destination form (`GetParentForm`) (including those inside panels) (`HasOtherTitleBar`), and if there is a TCTitleBar other than itself, treats it as the second one. It is not checked while the form is loading (`csLoading`) (so that an existing .lfm containing two can still be opened).
- At runtime: as in the first condition of 7.3, only the first one builds in.

### 7.4 Intercepted Messages (the Form's Window)

| Message | Processing |
|---|---|
| `WM_NCCALCSIZE` (`wParam <> 0`) | Remembers the top value, performs the standard calculation, then restores the top (removes the title bar portion, keeps the left, right and bottom borders). When maximized, moves the top inward by the border thickness (`FrameThickness`: `SM_CYFRAME` + `SM_CXPADDEDBORDER`, scaled to DPI), and `AdjustForAutoHideTaskbar` |
| `WM_NCHITTEST` | 7.5 |
| `WM_NCMOUSEMOVE` | Reports with `SetMaxButtonHot` whether the mouse is over the maximize button (`HTMAXBUTTON`). If so, `TrackMouseEvent(TME_LEAVE or TME_NONCLIENT)` |
| `WM_NCMOUSELEAVE` | `SetMaxButtonHot(False)`, `SetMaxButtonDown(False)` |
| `WM_NCLBUTTONDOWN`, `WM_NCLBUTTONDBLCLK` (`HTMAXBUTTON`) | Not passed to standard processing (because an old-style button would be drawn). `SetMaxButtonDown(True)`, returns 0 |
| `WM_NCLBUTTONUP` (`HTMAXBUTTON`) | If it was pressed, `SetMaxButtonDown(False)`, and `PostMessage` of `SC_RESTORE` if maximized, otherwise `SC_MAXIMIZE`. Returns 0. If not `HTMAXBUTTON`, `SetMaxButtonDown(False)` |
| `WM_ACTIVATE` | After standard processing, when it became inactive: if the destination is a window owned by the form (the tab list etc.), stays active; otherwise `FormActivated` as inactive |
| `WM_SIZE` | After standard processing, `FormStateChanged` (switches the maximize button symbol on maximize and restore) |
| `WM_SETTEXT` | After standard processing, `FormCaptionChanged` |
| `WM_ERASEBKGND` | After standard processing, `FillFormRemainder`: paints the parts LCL does not paint (below the form's `Height` and right of `Width`) with the form's `Brush`. LCL paints the form background only over `Rect(0, 0, Width, Height)`, but LCL's `Height` is "window height − standard title bar and border", which is smaller than the client area by the removed title bar, so a band would remain at the bottom if not painted |
| `WM_DPICHANGED` ($02E0) | After standard processing, `FrameChanged` |
| `WM_NCDESTROY` | Removes the interception, `FHooked := False` |

`AdjustForAutoHideTaskbar`: when the taskbar is set to auto-hide (`ABS_AUTOHIDE` in `SHAppBarMessage(ABM_GETSTATE)`), for each edge of that monitor, if `ABM_GETAUTOHIDEBAREX` ($0B) reports an auto-hide taskbar, leaves 1px free on that edge (so the taskbar can be brought up while maximized).

### 7.5 Mouse Position Determination

The determination is made in order, starting from the window under the mouse.

| Location | Determination | What happens |
|---|---|---|
| Child component with a window (TButton, TToolBar, TEdit, etc.) | That component receives it normally | The component's behavior |
| Child component without a window (TImage, TLabel, TSpeedButton, etc.) | TCTitleBar returns `HTCLIENT` | The component's behavior (checked with `ControlAtPos`. `DragChildAt`) |
| Tabs and [◀▶＋∨×] of the tab strip | The tab strip returns `HTCLIENT` | The tab's behavior |
| Empty part of the tab strip | The tab strip returns `HTTRANSPARENT` (`ICTitleBarDragArea.IsDragArea` is `True`) | Same as "empty space" below |
| Minimize button, close button | TCTitleBar returns `HTCLIENT` | TCTitleBar receives the mouse and sends `SC_MINIMIZE` or `SC_CLOSE` |
| Maximize button | TCTitleBar returns `HTTRANSPARENT` → the form returns `HTMAXBUTTON` (when the maximize button is usable) | The Windows 11 snap layout appears. Pressing it maximizes / restores |
| Range of the top border thickness (except when maximized. Only for `bsSizeable`) | TCTitleBar returns `HTTRANSPARENT` → the form returns `HTTOP` (`HTTOPLEFT` within border thickness × 2 of the left end, `HTTOPRIGHT` likewise from the right end) | Resize upward |
| Caption area, other empty space | TCTitleBar returns `HTTRANSPARENT` → the form returns `HTCAPTION` | Move by dragging, maximize / restore by double-click, snap to screen edges, system menu on right-click |

- The form's `WM_NCHITTEST`: if the standard determination is anything other than `HTCLIENT` (left, right and bottom borders, etc.), it is used as is. If the mouse is outside the title bar, it is used as is. Otherwise the determination of the last three rows of the table above applies.
- The title bar's own window (`SelfSubclassProc`): when built in, `HTTRANSPARENT` if `IsDragPointScreen`, otherwise `HTCLIENT`.
- The tab strip's window (`ChildSubclassProc`. `SUBCLASS_ID_CHILD = $43544243`): when the parent is a title bar that is built in, `HTTRANSPARENT` if `IsDragArea`. `CTitleBarHookChild(Self, True/False)` is called in the tab strip's `CreateWnd` and `DestroyWnd` (does nothing at design time, without a handle, or without the API).
- On empty space, mouse events such as `OnClick` of TCTitleBar and TCPageControl are not fired (because it is treated as the Windows title bar).

**interface (defined in `uCTitleBar`)**

```pascal
ICTitleBarDragArea = interface
  ['{6B0F3D2E-8A41-4C77-9E35-2B7C1D5A9F10}']
  function IsDragArea(const P: TPoint): Boolean;   // P is in the client coordinates of that component
end;

ICTitleBarDesignHit = interface
  ['{0E7C5B61-3F2A-4D8B-A1C9-58D6E4F2B370}']
  function DesignHitTest(const P: TPoint): Boolean;
  procedure DesignMouseDown(Button: TMouseButton; Shift: TShiftState; const P: TPoint);
end;
```

TCTabStrip implements both. `IsDragArea` is `False` while dragging or editing, otherwise `True` for a place with nothing.

**Shared functions**

| Function | Description |
|---|---|
| `CXScale96(AControl, ASize)` | Computes a 96dpi-based size using the `PixelsPerInch` of the form that holds the component (`GetParentDesignControl`). When it has not yet been placed on a form (e.g., while the .lfm is loading), the screen scale is used. LCL's `Scale96ToForm` raises an exception in that case, so it is not used |
| `CXBlendColor(ABase, AMix, APercent)` | Blends two colors per RGB channel at the ratio `APercent` |
| `CXSymbolFontName` | 'Segoe Fluent Icons', or 'Segoe MDL2 Assets' if absent, or '' if neither exists (checked once and remembered) |
| `CXSymbol(ACode)` | Converts one Unicode character into a UTF-8 string |
| `CXSetSymbolFont(ACanvas, AName, AHeightPx, AColor)` | Puts only the name, height (in pixels) and color into a new `TFont` and copies it to the Canvas |
| `CTitleBarHookChild(AChild, AHook)` | As described above |

### 7.6 Drawing the Minimize, Maximize and Close Buttons

| State | Background | Symbol |
|---|---|---|
| Normal | None | `clBtnText` (`clGrayText` when inactive) |
| Mouse over (minimize, maximize) | `Color` blended with 10% `clBtnText` | `clBtnText` |
| While pressed (minimize, maximize) | `Color` blended with 20% `clBtnText` | `clBtnText` |
| Mouse over (close) | #C42B1C (`TColor($1C2BC4)`. Windows standard red, fixed) | White |
| While pressed (close) | #C42B1C at 80% brightness | White |

Symbols: minimize U+E921, maximize U+E922, restore U+E923, close U+E8BB.

- Minimize and close show the pressed state in TCTitleBar's `MouseDown` and `MouseUp`, and when released over the same button send `SC_MINIMIZE` or `SC_CLOSE`. Maximize is handled by the form interception (7.4).

### 7.7 DPI

All sizes are held on a 96dpi basis and scaled with `CXScale96`. When the scale changes by moving between monitors, the frame is recomputed (`FrameChanged`) and redrawn.

---

## 8. Cooperation between TCPageControl and TCTitleBar

| Item | Description |
|---|---|
| Linking | Specify a TCTitleBar in TCPageControl's `TitleBar` |
| Moving the tab strip | When specified, the tab strip's `Parent` becomes the TCTitleBar. When cleared (nil), it returns to the TCPageControl (`UpdateStripPlace` in 5.6) |
| Tab strip position | While `TitleBar` is specified, `TabPosition` is not used and TCPageControl shows only pages |
| TCPageControl linked to one title bar | Only one. If another TCPageControl specifies the same TCTitleBar, the previous link is removed |
| When one of them is destroyed | The link is removed through `Notification` (no exception is raised) |
| Background of the tab strip inside the title bar | `Color` of TCTitleBar |
| Tab height inside the title bar | `TabHeight` (title bar height − 6 if 0). Tabs are aligned to the bottom edge of the title bar |

---

## 9. Design Time (Lazarus IDE)

| Item | Description |
|---|---|
| Palette | CX (`RegisterComponents('CX', [TCTitleBar, TCPageControl])`, `RegisterNoIcon([TCTabSheet])`) |
| Right-click menu (`TCPageControlEditor`. Registered for both TCPageControl and TCTabSheet) | 0 "New Page", 1 "Delete Page", 2 "Next Page", 3 "Previous Page" (resourcestrings `rsCPCNewPage`, `rsCPCDelPage`, `rsCPCNextPage`, `rsCPCPrevPage`) |
| New page | `Name := CreateUniqueComponentName('TCTabSheet')` (CTabSheet1, CTabSheet2…), Owner is the TCPageControl's Owner, `Caption := Name`, `Parent := TCPageControl`, `ActivePage := new page`, `PersistentAdded`, `Modified` |
| Delete page | First select the TCPageControl (if the page to be deleted stays selected, the IDE touches the deleted component). `DeletePersistent(page)`. Do not touch the editor itself afterwards (when right-clicked on a page, the IDE destroys the editor together with the page. The IDE sets the "modified" mark. Same as LCL's TNotebookComponentEditor) |
| Next page, previous page | Make the page from `FindNextPage(ActivePage, direction, False)` the `ActivePage`, select it, and `Modified` |
| Double-click (`Edit`) | Does nothing (by default the first menu item "New Page" would run and pages would increase) |
| Tab strip at design time | [＋][∨][×] are display only and do nothing when pressed |
| Non-displayed pages at design time | Not shown on the design surface (ControlStyle in chapter 6) |
| TCTitleBar | Not built in; only displays the buttons. A second one cannot be placed on one form (7.3) |

**Clicking a tab at design time**

- The Lazarus designer finds the component under the mouse and traces back to the component owned by the form. The TCTabStrip is owned by the TCPageControl, so the component that receives the mouse is the TCPageControl when standalone and the TCTitleBar when `TitleBar` is specified.
- The designer sends `CM_DESIGNHITTEST` to that component and calls its `MouseDown`, `MouseMove` and `MouseUp` only when the result is greater than 0 (otherwise it is component selection / movement).
- Therefore both TCPageControl and TCTitleBar receive `CM_DESIGNHITTEST`, convert the coordinates to tab strip coordinates and ask the tab strip's `DesignHitTest` (1 over a tab or [◀][▶], 0 otherwise). At design time `MouseDown` is also passed to the tab strip's `DesignMouseDown` (`DoTabClick` for a tab, scrolling for [◀][▶]).
- When a page is switched with `UserSelectPage` at design time, after `InternalSetPageIndex`, the displayed page is selected with the form's `Designer.SelectOnlyThisComponent(ActivePage)`, the whole form (including children; `RedrawWindow(RDW_INVALIDATE or RDW_ERASE or RDW_ALLCHILDREN)`) is made to redraw (the selection marks are added when the designer draws the form, so that marks of the previous page's components do not remain), and `OwnerFormDesignerModified` (to save `ActivePage` in the .lfm).
- `OnChanging` and `OnChange` are not fired at design time (same as LCL).

**Switching to a page selected in the Object Inspector**

- When a component is selected in the Object Inspector, the IDE traces the parents and makes the TTabSheet / TPage displayed, but it checks by name, so it does not work for TCTabSheet.
- Therefore, at `Register` a handler that receives selection changes (`TCPageControlSelectionHandler.SetSelection`) is registered with `GlobalDesignHook.AddHandlerSetSelection`, and removed in finalization (when the IDE exits, `GlobalDesignHook` may already have been destroyed, so it is removed only if it exists).
- When received, it traces the parents from the first selected item (if it is a `TControl`, at design time and not being destroyed), and if it reaches a TCTabSheet whose parent is a TCPageControl, makes that page the `ActivePage` (for nesting, all the way to the outermost; nothing if already displayed). If a component being destroyed is met along the way, it finishes. When switched, the form is made to redraw.
- The content saved in the .lfm is not changed (no "modified" mark. Same as the IDE's switching of TPageControl).

### 9.1 Palette Icons

| Component | Image |
|---|---|
| TCTitleBar | The upper part of a window. A horizontal band with three small symbols "─ □ ×" at the right end and a short line (in place of the caption) at the left. A little of a pale rectangle representing the window contents is shown below the band |
| TCPageControl | Three tabs on top (the second from the left is the displayed one and is connected to the rectangle below), and a small "＋" to the right of the third tab. Below, a rectangle representing the page |

| Item | Description |
|---|---|
| Background | Transparent |
| Colors | Lines are dark gray; the displayed tab and band are blue (same color as the TCSideBar icon); the page rectangle is white with a dark gray border |
| Line width | 1px at 24px, 2px at 36px, 2px at 48px. Drawn for each size (not scaled down) |
| Format | PNG (32-bit, with transparency) |

| Screen scale | Size | TCTitleBar | TCPageControl |
|---|---|---|---|
| 100% | 24 × 24 | `tctitlebar.png` | `tcpagecontrol.png` |
| 150% | 36 × 36 | `tctitlebar_150.png` | `tcpagecontrol_150.png` |
| 200% | 48 × 48 | `tctitlebar_200.png` | `tcpagecontrol_200.png` |

- The resource name is the PNG file name without the extension (case-insensitive). The Lazarus palette looks for a name equal to the class name, and for the names with `_150` and `_200` appended at scales 150% and 200%.
- `cpagecontrol_icon.lrs` is created with `lazres cpagecontrol_icon.lrs tctitlebar.png tctitlebar_150.png tctitlebar_200.png tcpagecontrol.png tcpagecontrol_150.png tcpagecontrol_200.png`.
- `{$I cpagecontrol_icon.lrs}` in the initialization of `uCPageControl_reg`.

---

## 10. Points to Check When Investigating Defects

| Symptom | Where to look |
|---|---|
| A band / margin remains below the form | `FillFormRemainder` in `WM_ERASEBKGND`, `WM_SIZE` in `FrameChanged` (7.3, 7.4) |
| Cannot move or maximize with the title bar | The `WM_NCHITTEST` determination, `SelfSubclassProc` and `ChildSubclassProc` (7.5) |
| Pressing a tab at design time does not switch | Both `CM_DESIGNHITTEST`, the tab strip's `DesignHitTest` (chapter 9) |
| Selection marks of the previous page remain at design time | The redraw at design time in `UserSelectPage`, the redraw in `SetSelection` (chapter 9) |
| Access violation after deleting a page | The order in the editor's `DeleteActivePage` (chapter 9), the `LayoutTabs` immediately in `RemovePage` (5.6) |
| A placed component goes into the form instead of the page | `UpdateDesignerFlags` (5.6) |
| Ctrl+Tab does not work | `KeyDownBefore`, `IsKeyTarget` (5.5.8) |
| Symbols look like dots | `CXSetSymbolFont` (5.8) |
| Only a frame remains after removing the title bar | The end of `UpdateStripPlace` (5.6) |
| A second TCTitleBar can be placed | `HasOtherTitleBar` in `SetParent` (7.3) |
