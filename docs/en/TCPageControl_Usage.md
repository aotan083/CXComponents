# TCPageControl User Manual

Author: aotan083
Date: 2026-10-29
Version: 1.0

---

## 1. Overview and Classes

A component for building a screen like a browser (Firefox, Edge, etc.), with tabs lined up where the title bar would be.

```
+-----------------------------------------------------------------------------+
| [Left comps] Caption [◀][Tab1 ×][Tab2 ×]…[▶][＋]  [∨][Right comps] [─][□][×] |  ← TCTitleBar
+-----------------------------------------------------------------------------+
|                                                                             |
|   Displayed page (TCTabSheet)                                               |
|   (Button, Memo, etc.)                                                      |
|                                                                             |
+-----------------------------------------------------------------------------+
```

| Component | Role |
|---|---|
| TCTitleBar | A panel that replaces the form's title bar. Has minimize, maximize and close buttons, and the form can be moved by dragging it |
| TCPageControl | The tab control. Can be used with properties and events that have the same names as TPageControl. Can be used on its own or combined with TCTitleBar |
| TCTabSheet | One tab's page. Components are placed on it |

- When a TCTitleBar is specified in TCPageControl's `TitleBar`, the tab strip goes inside the title bar.
- Tabs come with [×] (close), [＋] (new tab), [∨] (tab list), reordering by dragging, a right-click menu, in-place renaming, and icons.
- It works just by placing it on a form and configuring it in the Object Inspector. The only code the application writes is the processing run when a button or menu is clicked.

| Item | Details |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX (TCTitleBar and TCPageControl. TCTabSheet does not appear on the palette) |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Description |
|---|---|---|---|---|
| `TCPageControl` | `uCPageControl` | cx | `TCustomControl` | A browser-like tab control. Can be used with properties and events that have the same names as TPageControl |
| `TCTabSheet` | `uCPageControl` | cx | `TCustomControl` | One tab's page. Components are placed on it. Can be placed only on a `TCPageControl`. Does not appear on the palette |
| `TCTitleBar` | `uCTitleBar` | cx | `TCustomPanel` | A panel that replaces the form's title bar. Has minimize, maximize and close buttons |

| Type | Unit | Description |
|---|---|---|
| `TCTabShape` | `uCPageControl` | Tab shape. `tsRectangle` (square) and `tsRounded` (rounded corners) |
| `TCTabMenuItem` | `uCPageControl` | Standard items of the right-click menu. `tmiNew` (new tab), `tmiClose` (close tab), `tmiRename` (rename tab) |
| `TCTabMenuItems` | `uCPageControl` | `set of TCTabMenuItem` |
| `TCNewPageEvent` | `uCPageControl` | `procedure(Sender: TObject; APage: TCTabSheet) of object`. The type of `OnNewPage` |
| `TCPageCloseEvent` | `uCPageControl` | `procedure(Sender: TObject; APage: TCTabSheet; var CanClose: Boolean) of object`. The type of `OnPageClose` |
| `TCPageRenameEvent` | `uCPageControl` | `procedure(Sender: TObject; APage: TCTabSheet; var ACaption: string; var CanRename: Boolean) of object`. The type of `OnPageRename` |
| `TCPageMovedEvent` | `uCPageControl` | `procedure(Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer) of object`. The type of `OnPageMoved` |
| `TCTabControlOptions` | `ComCtrls` (LCL) | The type of `Options`. Values are in the table below 3.1 |
| `TTabChangingEvent` | `ComCtrls` (LCL) | `procedure(Sender: TObject; var AllowChange: Boolean) of object`. The type of `OnChanging` |
| `TTabGetImageEvent` | `ComCtrls` (LCL) | `procedure(Sender: TObject; TabIndex: Integer; var ImageIndex: Integer) of object`. The type of `OnGetImageIndex` |

- When placed on a form, `uCPageControl` and `uCTitleBar` are added to uses automatically.
- When placed on a form, cx is added automatically to the project's required packages.
- When creating in code, write them in uses yourself.

## 2. From Placing on a Form to Running

### 2.1 Lining Up Tabs on the Title Bar

1. From the palette [CX], place a TCTitleBar on the form. It is placed at the top edge (`Align = alTop`).
2. From the palette [CX], place a TCPageControl on the form and set `Align` to `alClient`.
3. In TCPageControl's `TitleBar`, select the TCTitleBar. The tab strip goes inside the title bar.
4. Set the form's `BorderStyle` to `bsSizeable` (the default) or `bsSingle`.
5. Right-click the TCPageControl and choose "New Page". A page is added at the end and becomes the displayed page.
6. In the Object Inspector, set the page's `Caption` (the tab text).
7. On the displayed page, place components such as buttons.
8. Repeat 5 to 7 for the number of pages.
9. To place components on a tab created with [＋], double-click `OnNewPage` on TCPageControl's Events tab and write the processing (10.1).
10. Run. The Windows title bar disappears and the TCTitleBar works as the title bar.

### 2.2 Using Only Tabs

1. Place only a TCPageControl on the form and set `Align` to `alClient`. Leave `TitleBar` empty.
2. Create pages in the same way as 5 to 9 in 2.1.
3. Run. The tab strip appears at the top edge of the TCPageControl (the bottom edge if `TabPosition = tpBottom`).

### 2.3 Using Only the Title Bar

1. Place only a TCTitleBar on the form.
2. Run. The caption, minimize, maximize and close buttons, and moving by dragging are available.

### 2.4 Placing Components on the Title Bar

1. On the TCTitleBar, place a TButton, TSpeedButton, TImage, TToolBar, etc.
2. Set the component's `Align` to `alLeft` or `alRight`.

```
[alLeft components…][Caption][Tab strip][alRight components…][─][□][×]
```

- If `Align` is left at `alNone`, depending on where it is placed, it may overlap the minimize, maximize and close buttons.
- With `Flat = True`, a TSpeedButton shows a border only while the mouse is over it. If it is hard to distinguish, set `Flat` to `False`, or add an icon or a `Caption`.

## 3. TCPageControl

### 3.1 Properties

| Name | Type | Access | Description |
|---|---|---|---|
| `ActivePage` | `TCTabSheet` | Read/Write | The displayed page. Writing switches to it |
| `ActivePageIndex` | `Integer` | Read/Write | Index of the displayed page (from 0; -1 when there are no pages). Writing switches to it. Runtime only |
| `TabIndex` | `Integer` | Read/Write | Same as `ActivePageIndex` |
| `PageCount` | `Integer` | Read | Number of pages. Runtime only |
| `Pages[Index]` | `TCTabSheet` | Read | A page. Runtime only |
| `PopupPage` | `TCTabSheet` | Read | The right-clicked page (nil for empty space in the tab strip). Used inside `OnClick` of an item of `TabPopupMenu`. Runtime only |
| `Images` | `TCustomImageList` | Read/Write | Tab icons |
| `ImagesWidth` | `Integer` | Read/Write | Icon width (px at a display scale of 100%). If 0 (the default), the width of `Images` |
| `TabPosition` | `TTabPosition` | Read/Write | Position of the tab strip. `tpTop` (default) or `tpBottom`. `tpLeft` and `tpRight` are the same as `tpTop`. Not used inside the title bar |
| `TabHeight` | `Smallint` | Read/Write | Tab height. Automatic if 0 (the default) |
| `TabWidth` | `Smallint` | Read/Write | Tab width. Fit to the text if 0 (the default) |
| `TabMaxWidth` | `Integer` | Read/Write | Maximum width when `TabWidth = 0` (the default is 240). Text that does not fit becomes "…" |
| `TabShape` | `TCTabShape` | Read/Write | Tab shape. `tsRectangle` (default; square) or `tsRounded` (rounded corners) |
| `Options` | `TCTabControlOptions` | Read/Write | Behavior settings (table below). The default is `[nboShowCloseButtons, nboShowAddTabButton, nboKeyboardTabSwitch]` |
| `ShowTabListButton` | `Boolean` | Read/Write | Whether to show [∨] (tab list) (the default is `True`) |
| `NewPageCaption` | `string` | Read/Write | Name of a tab created with [＋] or the menu (the default is 'New Tab') |
| `TabMenuItems` | `TCTabMenuItems` | Read/Write | Standard items shown in the right-click menu (the default is `[tmiNew, tmiClose, tmiRename]`) |
| `TabPopupMenu` | `TPopupMenu` | Read/Write | Items added to the tab's right-click menu. They appear below the standard items, separated by a separator |
| `TabListPopupMenu` | `TPopupMenu` | Read/Write | Items added above the tab list (submenus are not shown) |
| `TitleBar` | `TCTitleBar` | Read/Write | The title bar that holds the tab strip. If empty, the tab strip appears inside the TCPageControl |
| `Color` | `TColor` | Read/Write | Background color of the tab strip (when using tabs only. The default is `clBtnFace`) |
| `Align` | `TAlign` | Read/Write | Placement within the parent |
| `Anchors` | `TAnchors` | Read/Write | Which edges follow when the parent's size changes |
| `AnchorSideBottom` | `TAnchorSide` | Read/Write | Which component, and where on it, the bottom edge is aligned to |
| `AnchorSideLeft` | `TAnchorSide` | Read/Write | Which component, and where on it, the left edge is aligned to |
| `AnchorSideRight` | `TAnchorSide` | Read/Write | Which component, and where on it, the right edge is aligned to |
| `AnchorSideTop` | `TAnchorSide` | Read/Write | Which component, and where on it, the top edge is aligned to |
| `BiDiMode` | `TBiDiMode` | Read/Write | Whether to lay out right to left |
| `BorderSpacing` | `TControlBorderSpacing` | Read/Write | Margin around the control |
| `Constraints` | `TSizeConstraints` | Read/Write | Upper and lower limits of size |
| `Cursor` | `TCursor` | Read/Write | Mouse cursor when over the control |
| `DragCursor` | `TCursor` | Read/Write | Mouse cursor during a drag |
| `DragKind` | `TDragKind` | Read/Write | Kind of drag (drag and drop, or docking) |
| `DragMode` | `TDragMode` | Read/Write | Whether a drag starts automatically |
| `Enabled` | `Boolean` | Read/Write | Whether it is usable |
| `Font` | `TFont` | Read/Write | Tab text |
| `Height` | `Integer` | Read/Write | Height |
| `HelpContext` | `THelpContext` | Read/Write | Help number |
| `HelpKeyword` | `string` | Read/Write | Help keyword |
| `HelpType` | `THelpType` | Read/Write | Whether help is looked up by number (`htContext`) or by keyword (`htKeyword`) |
| `Hint` | `TTranslateString` | Read/Write | Hint text |
| `Left` | `Integer` | Read/Write | Position of the left edge |
| `Name` | `TComponentName` | Read/Write | Component name |
| `ParentBiDiMode` | `Boolean` | Read/Write | Whether to use the parent's `BiDiMode` |
| `ParentColor` | `Boolean` | Read/Write | Whether to use the parent's color (the default is `False`) |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the parent's `Font` |
| `ParentShowHint` | `Boolean` | Read/Write | Whether to use the parent's `ShowHint` |
| `PopupMenu` | `TPopupMenu` | Read/Write | Menu shown when right-clicking an empty place on a page |
| `ShowHint` | `Boolean` | Read/Write | Whether to show hints |
| `TabOrder` | `TTabOrder` | Read/Write | Order of movement with the Tab key |
| `TabStop` | `Boolean` | Read/Write | Whether the Tab key stops here |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely |
| `Top` | `Integer` | Read/Write | Position of the top edge |
| `Visible` | `Boolean` | Read/Write | Whether it is shown |
| `Width` | `Integer` | Read/Write | Width |

**Values of `Options`**

| Value | Description |
|---|---|
| `nboShowCloseButtons` | Show [×] on tabs |
| `nboShowAddTabButton` | Show [＋] |
| `nboKeyboardTabSwitch` | Switch with Ctrl+Tab and Ctrl+Shift+Tab |
| `nboDoChangeOnSetIndex` | Also fire `OnChanging` and `OnChange` when the displayed page is changed in code |

### 3.2 Methods

| Name | Arguments | Return value | Description |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | ― | Creates it. Used when creating in code (10.9) |
| `AddTabSheet` | ― | `TCTabSheet` | Adds a page at the end and returns it. Does not change the displayed page. Fires no events |
| `Clear` | ― | ― | Deletes all pages. `OnPageClose` is not fired |
| `IndexOf` | `APage: TPersistent` | `Integer` | Index of that page. -1 if absent |
| `FindNextPage` | `CurPage: TCTabSheet; GoForward, CheckTabVisible: Boolean` | `TCTabSheet` | Returns the next page (the previous if `GoForward = False`). Wraps to the other side at an end. If `CheckTabVisible = True`, pages with `TabVisible = False` are skipped |
| `SelectNextPage` | `GoForward: Boolean` | ― | Displays the next (previous) page. Pages with `TabVisible = False` are skipped |
| `SelectNextPage` | `GoForward, CheckTabVisible: Boolean` | ― | Displays the next (previous) page |
| `IndexOfTabAt` | `X, Y: Integer` | `Integer` | Index of the tab at that position (counted over visible tabs only). -1 if none |
| `IndexOfTabAt` | `P: TPoint` | `Integer` | Same (position passed as a `TPoint`) |
| `IndexOfPageAt` | `X, Y: Integer` | `Integer` | Page index of the tab at that position. -1 if none |
| `IndexOfPageAt` | `P: TPoint` | `Integer` | Same (position passed as a `TPoint`) |
| `TabRect` | `AIndex: Integer` | `TRect` | Position and size of that tab |
| `EditPageCaption` | `APage: TCTabSheet` | ― | Puts that tab's name into the state of being edited on the tab |

- The positions of `IndexOfTabAt`, `IndexOfPageAt` and `TabRect` are positions inside the TCPageControl when using tabs only, and positions inside the TCTitleBar when in the title bar.

### 3.3 Events

| Name | Arguments | Description |
|---|---|---|
| `OnChanging` | `Sender: TObject; var AllowChange: Boolean` | Before the displayed page changes. `AllowChange := False` cancels |
| `OnChange` | `Sender: TObject` | After the displayed page has changed |
| `OnNewPage` | `Sender: TObject; APage: TCTabSheet` | After a tab is created with [＋] or the menu. `APage` is the created page |
| `OnPageClose` | `Sender: TObject; APage: TCTabSheet; var CanClose: Boolean` | Before a tab is closed with [×], the menu or the list. `CanClose := False` cancels |
| `OnPageRename` | `Sender: TObject; APage: TCTabSheet; var ACaption: string; var CanRename: Boolean` | Before a name edit is committed. `ACaption` is the new name (can be changed). `CanRename := False` cancels |
| `OnPageMoved` | `Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer` | After a tab has been moved by dragging |
| `OnGetImageIndex` | `Sender: TObject; TabIndex: Integer; var ImageIndex: Integer` | Before a tab is drawn. The icon index to use can be put into `ImageIndex` |
| `OnContextPopup` | `Sender: TObject; MousePos: TPoint; var Handled: Boolean` | Just before the right-click menu is shown. `Handled := True` suppresses it |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | Something was dropped |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | The item being dragged came over it. `Accept` decides whether to accept |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | The drag ended |
| `OnEnter` | `Sender: TObject` | Focus entered |
| `OnExit` | `Sender: TObject` | Focus left |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was pressed |
| `OnMouseEnter` | `Sender: TObject` | The mouse entered |
| `OnMouseLeave` | `Sender: TObject` | The mouse left |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | The mouse moved |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was released |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | The wheel was turned |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned toward you |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned away from you |
| `OnResize` | `Sender: TObject` | The size changed |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | A drag started |

### 3.4 Order of Calls

| Operation | Order |
|---|---|
| Switch by pressing a tab | `OnChanging` → `OnChange` |
| Create a new tab with [＋] or the menu | `OnChanging` → `OnChange` → `OnNewPage` |
| Close the displayed tab with [×] | `OnPageClose` → `OnChange` |
| Close a non-displayed tab with [×] | `OnPageClose` |
| Move a tab by dragging | `OnPageMoved` |

- When the displayed tab is closed, the tab on its right is displayed (the one on its left if there is none). The last one can also be closed, leaving 0 pages.
- If `AllowChange := False` is set in `OnChanging`, the switch does not happen and later events are not fired (with [＋], the tab is not created either).

### 3.5 When Events Are Not Fired

| When | Description |
|---|---|
| Design time | Operations in the form designer |
| Startup | When the .lfm is loaded |
| Displayed page changed in code | When writing to `ActivePage`, `ActivePageIndex` or `TabIndex`. If `nboDoChangeOnSetIndex` is put in `Options`, `OnChanging` and `OnChange` are fired |
| Page deleted or reordered in code | `APage.Free`, `APage.PageIndex := n`, `Clear`. `OnPageClose` and `OnPageMoved` are not fired |

## 4. TCTabSheet

### 4.1 Properties

| Name | Type | Access | Description |
|---|---|---|---|
| `Caption` | `TCaption` | Read/Write | Tab text |
| `ImageIndex` | `TImageIndex` | Read/Write | Icon index. No icon if -1 (the default) |
| `PageIndex` | `Integer` | Read/Write | Position of the page. Writing reorders (`OnPageMoved` is not fired) |
| `TabVisible` | `Boolean` | Read/Write | `False` hides the tab (the page remains). The default is `True` |
| `TabIndex` | `Integer` | Read | Index counted over visible tabs only. -1 if hidden. Runtime only |
| `PageControl` | `TCPageControl` | Read/Write | The TCPageControl it belongs to. Writing makes it the last page of that TCPageControl. Runtime only |
| `Color` | `TColor` | Read/Write | Page background color (the default is `clWindow`) |
| `BorderWidth` | `TBorderWidth` | Read/Write | Inner margin of the page |
| `ChildSizing` | `TControlChildSizing` | Read/Write | How the components inside are arranged |
| `ClientHeight` | `Integer` | Read/Write | Inner height |
| `ClientWidth` | `Integer` | Read/Write | Inner width |
| `Cursor` | `TCursor` | Read/Write | Mouse cursor when over the control |
| `Enabled` | `Boolean` | Read/Write | Whether it is usable |
| `Font` | `TFont` | Read/Write | Font used by components on the page |
| `HelpContext` | `THelpContext` | Read/Write | Help number |
| `HelpKeyword` | `string` | Read/Write | Help keyword |
| `HelpType` | `THelpType` | Read/Write | Whether help is looked up by number (`htContext`) or by keyword (`htKeyword`) |
| `Hint` | `TTranslateString` | Read/Write | Hint text |
| `Name` | `TComponentName` | Read/Write | Component name |
| `ParentColor` | `Boolean` | Read/Write | Whether to use the parent's color (the default is `False`) |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the parent's `Font` |
| `ParentShowHint` | `Boolean` | Read/Write | Whether to use the parent's `ShowHint` |
| `PopupMenu` | `TPopupMenu` | Read/Write | Menu shown when right-clicking on the page |
| `ShowHint` | `Boolean` | Read/Write | Whether to show hints |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely |

- A page that is not displayed becomes invisible (`Visible = False`). TCMonacoEditor starts when it is first displayed.

### 4.2 Methods

| Name | Arguments | Return value | Description |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | ― | Creates it. Setting a TCPageControl in `PageControl` makes it that control's page (10.9). Giving a parent other than a TCPageControl raises an exception |

### 4.3 Events

| Name | Arguments | Description |
|---|---|---|
| `OnShow` | `Sender: TObject` | This page was displayed |
| `OnHide` | `Sender: TObject` | This page stopped being displayed |
| `OnContextPopup` | `Sender: TObject; MousePos: TPoint; var Handled: Boolean` | Just before the right-click menu is shown. `Handled := True` suppresses it |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | Something was dropped |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | The item being dragged came over it. `Accept` decides whether to accept |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | The drag ended |
| `OnEnter` | `Sender: TObject` | Focus entered |
| `OnExit` | `Sender: TObject` | Focus left |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was pressed |
| `OnMouseEnter` | `Sender: TObject` | The mouse entered |
| `OnMouseLeave` | `Sender: TObject` | The mouse left |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | The mouse moved |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was released |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | The wheel was turned |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned toward you |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned away from you |
| `OnResize` | `Sender: TObject` | The size changed |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | A drag started |

## 5. TCTitleBar

### 5.1 Properties

| Name | Type | Access | Description |
|---|---|---|---|
| `Caption` | `TCaption` | Read/Write | Text shown on the title bar. When empty, the form's `Caption` is shown (the taskbar always shows the form's `Caption`) |
| `Hooked` | `Boolean` | Read | Whether it is working as the title bar. Runtime only |
| `Color` | `TColor` | Read/Write | Background color (the default is `clBtnFace`) |
| `BevelInner` | `TPanelBevel` | Read/Write | Inner border |
| `BevelOuter` | `TPanelBevel` | Read/Write | Outer border (the default is `bvNone`) |
| `BevelWidth` | `TBevelWidth` | Read/Write | Border thickness |
| `BorderSpacing` | `TControlBorderSpacing` | Read/Write | Margin around the control |
| `Constraints` | `TSizeConstraints` | Read/Write | Upper and lower limits of size |
| `Cursor` | `TCursor` | Read/Write | Mouse cursor when over the control |
| `Enabled` | `Boolean` | Read/Write | Whether it is usable |
| `Font` | `TFont` | Read/Write | Text of `Caption` |
| `Height` | `Integer` | Read/Write | Height (the default is 40) |
| `HelpContext` | `THelpContext` | Read/Write | Help number |
| `HelpKeyword` | `string` | Read/Write | Help keyword |
| `HelpType` | `THelpType` | Read/Write | Whether help is looked up by number (`htContext`) or by keyword (`htKeyword`) |
| `Hint` | `TTranslateString` | Read/Write | Hint text |
| `Name` | `TComponentName` | Read/Write | Component name |
| `ParentColor` | `Boolean` | Read/Write | Whether to use the parent's color (the default is `False`) |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the parent's `Font` |
| `ParentShowHint` | `Boolean` | Read/Write | Whether to use the parent's `ShowHint` |
| `PopupMenu` | `TPopupMenu` | Read/Write | Menu shown on right-click (when not working as the title bar) |
| `ShowHint` | `Boolean` | Read/Write | Whether to show hints |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely |
| `Visible` | `Boolean` | Read/Write | Whether it is shown |

**Minimize, maximize and close buttons** (decided by the form's `BorderIcons`)

| `BorderIcons` | Minimize | Maximize | Close |
|---|---|---|---|
| `biSystemMenu`, `biMinimize`, `biMaximize` | Shown | Shown | Shown |
| `biSystemMenu`, `biMinimize` | Shown | Disabled | Shown |
| `biSystemMenu`, `biMaximize` | Disabled | Shown | Shown |
| `biSystemMenu` only | None | None | Shown |
| No `biSystemMenu` | None | None | None |

**Conditions for working as the title bar**

| Condition | Description |
|---|---|
| Placement | When placed directly on the form (placed on a panel etc., it is a plain panel) |
| Form border | When the form's `BorderStyle` is `bsSizeable` or `bsSingle` |
| Count | Only one per form. Trying to place a second one at design time does not place it |
| When | Runtime only (at design time it only displays the buttons) |

### 5.2 Methods

| Name | Arguments | Return value | Description |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | ― | Creates it |

### 5.3 Events

| Name | Arguments | Description |
|---|---|---|
| `OnClick` | `Sender: TObject` | Clicked |
| `OnDblClick` | `Sender: TObject` | Double-clicked |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was pressed |
| `OnMouseEnter` | `Sender: TObject` | The mouse entered |
| `OnMouseLeave` | `Sender: TObject` | The mouse left |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | The mouse moved |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was released |
| `OnResize` | `Sender: TObject` | The size changed |

- While working as the title bar, places with nothing placed on them (including the caption) are treated as the Windows title bar (move by dragging, maximize by double-click, system menu by right-click). Mouse events are not fired there.

## 6. Operation

### 6.1 At Runtime

| Part | Operation |
|---|---|
| Caption | Shows the TCTitleBar's `Caption`. When empty, shows the form's `Caption`. Long text is abbreviated with "…". Operation is the same as for empty space |
| Tab | Pressing it displays that page. It can be reordered by dragging (Esc during the drag, or releasing outside the tab strip, cancels) |
| [×] of a tab | Closes that tab |
| [＋] | Creates a new tab at the end and displays it |
| [◀][▶] | Shown only when the tabs do not fit. Pressing scrolls one tab at a time. The mouse wheel over the tab strip also scrolls |
| [∨] | Shows the tab list. Pressing a row displays that tab, and [×] in a row closes that tab |
| Minimize, maximize, close | Same as the Windows title bar. Moving the mouse over the maximize button shows the snap layout |
| Empty space | Move the form by dragging, maximize / restore by double-click, snap to screen edges, system menu by right-click |
| Top edge | Can be resized upward by dragging |
| Ctrl+Tab | Next tab (wraps to the first at the end) |
| Ctrl+Shift+Tab | Previous tab (wraps to the last at the start) |

**Right-click menu**

| Right-click location | Items shown |
|---|---|
| On a tab | New Tab, Close Tab, Rename Tab → items of `TabPopupMenu` |
| Empty part of the tab strip (standalone) | New Tab → items of `TabPopupMenu` |
| Empty part of the tab strip inside the title bar | The Windows system menu |

- A right-click does not change the displayed tab.
- "Rename Tab" edits the text directly on the tab. Enter or losing focus commits; Esc cancels. Committing while empty returns to the original name.

### 6.2 At Design Time (Form Designer)

| Operation | Behavior |
|---|---|
| Click a tab | Displays that page. The displayed page becomes selected |
| Click [◀][▶] of the tab strip | Scrolls |
| Select a page (or a component in a page) in the Object Inspector | Displays that page |
| Right-click → "New Page" | Adds a page at the end and displays it |
| Right-click → "Delete Page" | Deletes the displayed page |
| Right-click → "Next Page" / "Previous Page" | Displays the next (previous) page |
| Double-click the TCPageControl | Does nothing |

- At design time, [＋][∨][×] of the tab strip are display only and do nothing when pressed.
- At design time, the TCTitleBar does not work as the title bar (it only displays the buttons). It works when run.
- The page that was displayed at design time is also displayed at startup (because `ActivePage` is saved in the .lfm).
- The order of pages is changed with the TCTabSheet's `PageIndex`.

### 6.3 Commonly Used Settings

| What you want to do | Setting |
|---|---|
| Hide [×] on tabs | Remove `nboShowCloseButtons` from `Options` |
| Hide [＋] | Remove `nboShowAddTabButton` from `Options` |
| Do not switch with Ctrl+Tab | Remove `nboKeyboardTabSwitch` from `Options` |
| Hide [∨] | Set `ShowTabListButton` to `False` |
| Reduce the standard items of the right-click menu | Remove `tmiNew`, `tmiClose` and `tmiRename` from `TabMenuItems` |
| Add application items to the right-click menu | Place a TPopupMenu, create items, and select it in `TabPopupMenu` |
| Add application items above the tab list | Place a TPopupMenu, create items, and select it in `TabListPopupMenu` |
| Change the name of newly created tabs | Put it in `NewPageCaption` |
| Add icons to tabs | Place a TImageList, select it in `Images`, and put the index in each TCTabSheet's `ImageIndex` |
| Make the tab shape rounded | Set `TabShape` to `tsRounded` |
| Show tabs at the bottom (standalone) | Set `TabPosition` to `tpBottom` |
| Make tab widths uniform | Put the width in `TabWidth` |
| Change the title bar text | Put it in the TCTitleBar's `Caption`. If empty, the form's `Caption` is shown |
| Fire events also when the displayed page is changed in code | Put `nboDoChangeOnSetIndex` in `Options` |

## 7. Keyboard Operations

Ctrl+Tab and Ctrl+Shift+Tab arrive in the following order.

| Order | Processing |
|---|---|
| 1 | The form's `OnKeyDown` (when `KeyPreview = True`). Setting `Key := 0` prevents the tab from switching |
| 2 | TCPageControl's tab switching |

- If Enter or Esc is set to `Key := 0` in the form's `OnKeyDown` while a tab name is being edited, commit and cancel no longer work.
- When a component that uses WebView2, such as TCMonacoEditor or TCTabBrowser, has focus, that component receives the key.

## 8. Display

### 8.1 Colors (Dark / Light)

Drawn with system colors only. Switching between dark and light is left to the application's MetaDarkStyle or similar.

| Part | Color |
|---|---|
| Tab strip background | Standalone: `Color` of TCPageControl (default `clBtnFace`). Inside the title bar: `Color` of TCTitleBar (default `clBtnFace`) |
| Displayed tab | `clWindow`, text `clWindowText` |
| Non-displayed tab | Tab strip background, text `clBtnText` |
| Tab or button under the mouse | The background color blended with a little `clBtnText` |
| Page background | `Color` of TCTabSheet (default `clWindow`) |
| Page area when there are 0 pages | `clWindow` |
| Title bar text and symbols | `clBtnText` (`clGrayText` when the form is inactive) |
| When the mouse is over the close button | Red (#C42B1C), symbol white (the same in dark mode) |

Button symbols are drawn with glyphs of Segoe Fluent Icons (or Segoe MDL2 Assets if absent).

### 8.2 Display Scale (High DPI)

The sizes of tabs, buttons and the title bar are enlarged automatically to match the Windows display scale (125%, 150%, etc.) (when the form's `Scaled = True`). When moved to a monitor with a different scale, it is redrawn at the new scale.

- To enlarge icons, set the TImageList's `Scaled` to `True` and prepare images in different sizes.
- Specify `ImagesWidth` as the value at 100%.

## 9. Differences from TPageControl

| Item | TPageControl | TCPageControl |
|---|---|---|
| Tab drawing | Drawn by the standard Windows tab control | The component draws itself |
| Dark display | Becomes the display of the standard Windows tab control | Follows MetaDarkStyle (drawn with system colors) |
| Placing tabs on the title bar | Not possible | Possible in combination with TCTitleBar |
| [×] close button | Only notifies that it was pressed (`OnCloseTabClicked`). The application writes the closing code | Closes automatically when pressed. `OnPageClose` is used only when you want to cancel |
| [＋] new tab | None | Yes (creates at the end. `OnNewPage`) |
| [∨] tab list | None | Yes (each row has [×]) |
| Reordering by dragging | None | Yes (`OnPageMoved`) |
| Right-click menu | The application builds it | Standard items are built in. Application items can be added with `TabPopupMenu` |
| Renaming a tab | None | Edited in place on the tab (`OnPageRename`) |
| When there are many tabs | Multiple rows (`MultiLine`), or scrolling | One row only. Scroll with [◀▶] and the mouse wheel |
| Tab position | Top, bottom, left, right | Top and bottom only |
| Tab shape | `Style` (tab or button form) | `TabShape` (square or rounded) |
| Default of `Options` | Empty (nothing is enabled) | [×], [＋] and Ctrl+Tab are enabled from the start |
| Background color (`Color`) | Cannot be specified | Can be specified for both the tab strip and the page |
| Not provided | ― | `MultiLine`, `RaggedRight`, `ScrollOpposite`, `Style`, `HotTrack`, `ShowTabs`, `OnCloseTabClicked`, docking-related members (`DockSite`, etc.) |
| Supported OS | All OSes on which LCL runs | Windows 11 |

### 9.1 Notes

- Only one TCPageControl can be put into one TCTitleBar. If you select the same TCTitleBar in another TCPageControl's `TitleBar`, the previous TCPageControl's tab strip returns to its original position.
- If you try to place a second TCTitleBar on a form at design time, "Only one TCTitleBar can be placed on a form" is shown and it is not placed.
- TCTitleBar works even in applications that replace `Form.WindowProc`.
## 10. Usage Examples

### 10.1 Placing a TMemo on a Tab Created with [＋] or the Menu

```pascal
procedure TForm1.CPageControl1NewPage(Sender: TObject; APage: TCTabSheet);
var
  M: TMemo;
begin
  M := TMemo.Create(APage);
  M.Parent := APage;
  M.Align := alClient;
end;
```

### 10.2 Confirming Before Closing

```pascal
procedure TForm1.CPageControl1PageClose(Sender: TObject; APage: TCTabSheet;
  var CanClose: Boolean);
begin
  CanClose := MessageDlg('Close ' + APage.Caption + '?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;
```

### 10.3 Showing the Displayed Tab in the Title When It Changes

```pascal
procedure TForm1.CPageControl1Change(Sender: TObject);
begin
  if CPageControl1.ActivePage <> nil then
    CTitleBar1.Caption := CPageControl1.ActivePage.Caption + ' - MyApp'
  else
    CTitleBar1.Caption := 'MyApp';
end;
```

### 10.4 Creating, Displaying and Closing Pages in Code

```pascal
procedure TForm1.Button1Click(Sender: TObject);
var
  P: TCTabSheet;
begin
  P := CPageControl1.AddTabSheet;   // Create at the end (the displayed page does not change)
  P.Caption := 'Log';
  CPageControl1.ActivePage := P;    // Display it
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  if CPageControl1.ActivePage <> nil then
    CPageControl1.ActivePage.Free;  // Close (OnPageClose is not fired)
end;
```

### 10.5 Adding Application Items to the Right-Click Menu

1. Place a TPopupMenu on the form and create an item (e.g., "Show Name").
2. In TCPageControl's `TabPopupMenu`, select that TPopupMenu.
3. In the item's `OnClick`, write the following.

```pascal
procedure TForm1.MenuItemShowNameClick(Sender: TObject);
begin
  if CPageControl1.PopupPage <> nil then   // The right-clicked tab
    ShowMessage(CPageControl1.PopupPage.Caption);
end;
```

### 10.6 Trimming Whitespace and Rejecting Duplicate Names When Renaming

```pascal
procedure TForm1.CPageControl1PageRename(Sender: TObject; APage: TCTabSheet;
  var ACaption: string; var CanRename: Boolean);
var
  i: Integer;
begin
  ACaption := Trim(ACaption);
  for i := 0 to CPageControl1.PageCount - 1 do
    if (CPageControl1.Pages[i] <> APage) and (CPageControl1.Pages[i].Caption = ACaption) then
    begin
      ShowMessage('A tab with the same name already exists');
      CanRename := False;
      Exit;
    end;
end;
```

### 10.7 Changing the Icon of a Modified Tab

```pascal
// ImageList1: 0 = saved, 1 = modified. Select ImageList1 in CPageControl1.Images beforehand
procedure TForm1.SetPageModified(APage: TCTabSheet; AModified: Boolean);
begin
  if AModified then
    APage.ImageIndex := 1    // Writing it redraws the tab immediately
  else
    APage.ImageIndex := 0;
end;
```

### 10.8 Moving to the Next / Previous Tab by Key

```pascal
CPageControl1.SelectNextPage(True);    // Next tab (wraps to the first at the end)
CPageControl1.SelectNextPage(False);   // Previous tab (wraps to the last at the start)
```

### 10.9 Creating in Code

```pascal
uses
  uCPageControl, uCTitleBar;

procedure TForm1.FormCreate(Sender: TObject);
var
  TB: TCTitleBar;
  PC: TCPageControl;
  P: TCTabSheet;
begin
  TB := TCTitleBar.Create(Self);
  TB.Parent := Self;                   // Place directly on the form (placed at the top edge)

  PC := TCPageControl.Create(Self);
  PC.Parent := Self;
  PC.Align := alClient;
  PC.TitleBar := TB;                   // Put the tab strip inside the title bar
  PC.OnNewPage := @CPageControl1NewPage;   // Use the processing from 10.1

  P := TCTabSheet.Create(Self);
  P.Caption := 'Home';
  P.PageControl := PC;                 // Becomes the last page of PC
  PC.ActivePage := P;
end;
```
