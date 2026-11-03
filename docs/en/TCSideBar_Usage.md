# TCSideBar User Manual

Author: aotan083
Date: 2026-10-29
Version: 1.0

---

## 1. Overview and Classes

A component that combines an Edge-style sidebar ("icon bar + collapsible panel + splitter") into one.

```
+------+-----------------------+--+------------------------------+
| [A]  | Page A header     [x] |  |                              |
| [B]  +-----------------------+ ┃|   Main body of the app       |
| [C]  | Page A content        | ┃|   (Align = alClient)         |
|      | (Button, ListBox)     |  |                              |
+------+-----------------------+--+------------------------------+
 Icon bar  Panel (open page)    Splitter
```

- Clicking an icon at the left edge opens the corresponding page. Clicking it again closes it.
- The contents of a page (Button, ListBox, etc.) can be freely placed on the page in the form designer.
- Dragging the splitter changes the width of the panel.
- The width of the sidebar changes automatically as pages open and close. A component placed on the right with `Align = alClient` grows and shrinks automatically.
- You can also hide the header (`ShowHeader = False`) and build your own header for each page (8.4).

| Item | Details |
|---|---|
| Lazarus | 4.8, 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Description |
|---|---|---|---|---|
| `TCSideBar` | `uCSideBar` | cx | `TCustomControl` | Edge-style sidebar (icon bar + collapsible panel + splitter) |
| `TCSideBarPage` | `uCSideBar` | cx | `TCustomControl` | One page of the sidebar. Buttons and other components are placed on it. Can only be placed on a `TCSideBar` |

| Type | Unit | Description |
|---|---|---|
| `TCSideBarPageEvent` | `uCSideBar` | `procedure(Sender: TObject; Index: Integer) of object`. The type of `OnPageOpen` and `OnPageClose` |
| `TCSideBarChangingEvent` | `uCSideBar` | `procedure(Sender: TObject; Index: Integer; var Allow: Boolean) of object`. The type of `OnPageChanging` |

- When placed on a form, `uCSideBar` is added to uses automatically.
- When placed on a form, cx is added to the project's required packages automatically.
- When creating it in code, write it in uses yourself.

## 2. From Placing on a Form to Running

1. From the palette [CX], place TCSideBar on the form. It is placed at the left edge (`Align = alLeft`).
2. In the remaining area of the form, place the component that will be the main body (such as TMemo) and set its `Align` to `alClient`.
3. Place a TImageList on the form and add the images to be used as icons. Set that TImageList in the `Images` property of TCSideBar.
4. Right-click TCSideBar and choose "Add Page". A page is added at the end and is in the open state.
5. In the Object Inspector, set the page's `Caption` (header) and `ImageIndex` (icon number).
6. Place components such as buttons on the open page.
7. Repeat steps 4 to 6 for as many pages as needed.
8. To do something when a page is opened, double-click `OnPageOpen` on the Events tab of TCSideBar and write the handler.
9. Run it. Clicking an icon opens the page, and clicking it again closes it.

- In the form designer, clicking an icon opens that page so that you can edit it.
- To change the order of pages, use "Move Up" / "Move Down" in the right-click menu.
- The page that was open at design time is also open at startup. To start in the closed state, click the icon at design time to close it, or clear `ActivePage`.

## 3. TCSideBar

### 3.1 Properties

| Name | Type | Access | Description |
|---|---|---|---|
| `ActivePage` | `TCSideBarPage` | Read/Write | The open page. If nil, the sidebar is closed. Writing it opens or closes |
| `ActivePageIndex` | `Integer` | Read/Write | Index of the open page (-1 when closed). Writing it opens or closes. Out-of-range values are ignored. Runtime only |
| `Pages[Index]` | `TCSideBarPage` | Read | The page. Runtime only |
| `PageCount` | `Integer` | Read | Number of pages. Pages with `PageVisible = False` are also counted. Runtime only |
| `Images` | `TCustomImageList` | Read/Write | The image list that holds the icon images |
| `ImagesWidth` | `Integer` | Read/Write | Width at which icons are drawn (px at 100% display scale). If 0 (default), the `Width` of `Images` |
| `IconBarWidth` | `Integer` | Read/Write | Width of the icon bar (default 40). The cell of one icon is a square of this width |
| `MinPanelWidth` | `Integer` | Read/Write | Lower limit of the panel width that can be set with the splitter (default 150) |
| `MaxPanelWidth` | `Integer` | Read/Write | Upper limit of the panel width that can be set with the splitter (default 600). 0 means no limit |
| `SplitterWidth` | `Integer` | Read/Write | Width of the splitter (the part you grab) (default 8) |
| `ResizeStyle` | `TResizeStyle` | Read/Write | Appearance while the splitter is being dragged. `rsLine` (default) / `rsPattern`: only a line moves, and the width changes on release. `rsUpdate`: the width changes during the drag too. `rsNone`: nothing is shown, and the width changes on release |
| `ShowHeader` | `Boolean` | Read/Write | Whether to show the header (`Caption` and [x]) (default `True`). With `False`, the page starts at the very top of the panel |
| `ShowCloseButton` | `Boolean` | Read/Write | Whether to show [x] at the right of the header (default `True`). Not shown when `ShowHeader = False` |
| `IconPopupMenu` | `TPopupMenu` | Read/Write | Menu shown when the icon bar is right-clicked |
| `Align` | `TAlign` | Read/Write | Placement within the parent (default `alLeft`) |
| `Anchors` | `TAnchors` | Read/Write | Which edges follow when the parent's size changes |
| `AnchorSideBottom` | `TAnchorSide` | Read/Write | To which part of which component the bottom edge is aligned |
| `AnchorSideLeft` | `TAnchorSide` | Read/Write | To which part of which component the left edge is aligned |
| `AnchorSideRight` | `TAnchorSide` | Read/Write | To which part of which component the right edge is aligned |
| `AnchorSideTop` | `TAnchorSide` | Read/Write | To which part of which component the top edge is aligned |
| `BorderSpacing` | `TControlBorderSpacing` | Read/Write | Surrounding margins |
| `Constraints` | `TSizeConstraints` | Read/Write | Upper and lower limits of the size |
| `Cursor` | `TCursor` | Read/Write | Mouse cursor shown when the mouse is over it |
| `Enabled` | `Boolean` | Read/Write | Whether it is usable. With `False`, the icons, [x], splitter, and shortcut keys stop working |
| `Font` | `TFont` | Read/Write | Font of the header text |
| `Height` | `Integer` | Read/Write | Height |
| `HelpContext` | `THelpContext` | Read/Write | Help number |
| `HelpKeyword` | `string` | Read/Write | Help keyword |
| `HelpType` | `THelpType` | Read/Write | Whether help is looked up by number (`htContext`) or by keyword (`htKeyword`) |
| `Hint` | `TTranslateString` | Read/Write | Hint text |
| `Left` | `Integer` | Read/Write | Position of the left edge |
| `Name` | `TComponentName` | Read/Write | Name of the component |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the parent's `Font` |
| `ParentShowHint` | `Boolean` | Read/Write | Whether to use the parent's `ShowHint` |
| `ShowHint` | `Boolean` | Read/Write | With `True`, the page's `Caption` is shown as the hint over an icon |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely |
| `Top` | `Integer` | Read/Write | Position of the top edge |
| `Visible` | `Boolean` | Read/Write | Whether it is shown |

- The index (`Index`) is the order including pages with `PageVisible = False`.
- The width is decided by the sidebar itself. When closed it is `IconBarWidth`; when open it is `IconBarWidth` + the page's `PanelWidth` + `SplitterWidth`.
- The widths read and written while running (`IconBarWidth`, `PanelWidth`, `MinPanelWidth`, `MaxPanelWidth`, `SplitterWidth`) are values after scaling by the display scale. `ImagesWidth` stays as the 100% value.

### 3.2 Methods

| Name | Parameters | Return value | Description |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | - | Creates it. Used when creating in code (8.7) |
| `OpenPage` | `Index: Integer` | - | Opens that page. If another page is open, switches to it. Out of range raises an exception (`EListError`). Pages with `PageVisible = False` or `Enabled = False` are not opened |
| `ClosePage` | - | - | Closes the open page |
| `MovePage` | `CurIndex, NewIndex: Integer` | - | Changes the order of pages. Does nothing if out of range or the indexes are the same. No event is fired |

### 3.3 Events

| Name | Parameters | Description |
|---|---|---|
| `OnPageChanging` | `Sender: TObject; Index: Integer; var Allow: Boolean` | Before opening, switching, or closing. `Index` is the index of the page about to be opened (-1 when closing). `Allow := False` cancels |
| `OnPageOpen` | `Sender: TObject; Index: Integer` | After a page has been opened. `Index` is the index of the opened page |
| `OnPageClose` | `Sender: TObject; Index: Integer` | After a page has been closed. `Index` is the index of the closed page |
| `OnPanelResize` | `Sender: TObject` | After a splitter drag has ended and the width has changed. Read the new width with `ActivePage.PanelWidth` |

### 3.4 Order of Calls

| Operation | Order |
|---|---|
| Open A from the closed state | `OnPageChanging`(A) -> `OnPageOpen`(A) |
| Switch from A to B | `OnPageChanging`(B) -> `OnPageClose`(A) -> `OnPageOpen`(B) |
| Close A | `OnPageChanging`(-1) -> `OnPageClose`(A) |

- The same order applies whether the page is opened or closed by an icon, [x], a shortcut key, or code (`OpenPage`, `ClosePage`, `ActivePage`, `ActivePageIndex`).
- If `Allow := False` is set in `OnPageChanging`, nothing changes and the later events are not fired.

### 3.5 When Events Are Not Fired

| When | Description |
|---|---|
| Startup | When the .lfm is loaded and the page that was open at design time is opened |
| Design time | Operations in the form designer |
| The state does not change | Calling `OpenPage` on the open page, or `ClosePage` while closed |
| The page disappeared | When the open page was closed because its `PageVisible` was set to `False` or the page was deleted |

## 4. TCSideBarPage

### 4.1 Properties

| Name | Type | Access | Description |
|---|---|---|---|
| `Caption` | `TCaption` | Read/Write | Header text. Also used for the icon hint. A page added at design time gets the same text as its `Name` |
| `ImageIndex` | `TImageIndex` | Read/Write | Index of the icon in `Images`. If -1 (default), no icon is drawn (the cell remains and can be clicked) |
| `PanelWidth` | `Integer` | Read/Write | Panel width when this page is opened (default 250). Changes when the splitter is dragged |
| `PageVisible` | `Boolean` | Read/Write | With `False`, the icon disappears and the icons below move up. The page cannot be opened (at design time the icon stays visible) |
| `Enabled` | `Boolean` | Read/Write | With `False`, the icon is grayed out and cannot be clicked |
| `ShortCut` | `TShortCut` | Read/Write | A key that behaves the same as clicking the icon (default 0: none) |
| `SideBar` | `TCSideBar` | Read | The sidebar that contains this page. Runtime only |
| `Color` | `TColor` | Read/Write | Background color of the page (default `clBtnFace`) |
| `Font` | `TFont` | Read/Write | Font used by components on the page |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the parent's `Font` |
| `PopupMenu` | `TPopupMenu` | Read/Write | Menu shown when the page is right-clicked |
| `ShowHint` | `Boolean` | Read/Write | Whether to show hints |
| `ParentShowHint` | `Boolean` | Read/Write | Whether to use the parent's `ShowHint` |
| `Cursor` | `TCursor` | Read/Write | Mouse cursor shown when the mouse is over it |
| `HelpContext` | `THelpContext` | Read/Write | Help number |
| `HelpKeyword` | `string` | Read/Write | Help keyword |
| `HelpType` | `THelpType` | Read/Write | Whether help is looked up by number (`htContext`) or by keyword (`htKeyword`) |
| `Hint` | `TTranslateString` | Read/Write | Hint text |
| `Name` | `TComponentName` | Read/Write | Name of the component |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely |

### 4.2 Methods

| Name | Parameters | Return value | Description |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | - | Creates it. Setting a TCSideBar as `Parent` makes it the last page of that sidebar (8.7). Setting anything other than a TCSideBar as `Parent` raises an exception (`EInvalidOperation`) |

### 4.3 Events

TCSideBarPage has no events. Opening and closing are detected through the TCSideBar events (3.3).

## 5. Operation

### 5.1 At Runtime

| Operation | Behavior |
|---|---|
| Click the icon of a closed page | Opens that page (switches if another page is open) |
| Click the icon of the open page | Closes it |
| Click [x] | Closes it (when `ShowHeader = True` and `ShowCloseButton = True`) |
| Hover the mouse over an icon | The icon is highlighted. If `ShowHint = True`, `Caption` is shown as the hint |
| Right-click the icon bar | Shows `IconPopupMenu` (does not open or close a page) |
| Drag the splitter | Changes the panel width within the range `MinPanelWidth` to `MaxPanelWidth` |
| Press the `ShortCut` key of a page | Same behavior as clicking that page's icon |

- The line shown during dragging is drawn as a separate window, so it is also displayed over components that use WebView2.
- If you switch to another window during a drag (Alt+Tab, etc.), the drag is canceled and the width is restored.

### 5.2 At Design Time (Form Designer)

| Operation | Behavior |
|---|---|
| Click an icon | Opens that page (closes it if it is the open page). The opened page becomes selected |
| Drag the splitter | Changes the `PanelWidth` of the open page |
| Right-click -> "Add Page" | Adds a page at the end and opens it |
| Right-click -> "Delete Page" | Deletes the open page |
| Right-click -> "Move Up" / "Move Down" | Changes the order of the open page |

- Components can be placed on the open page. When `ShowHeader = False`, they can be placed all the way to the top of the panel.
- Pages with `PageVisible = False` also show their icon at design time and can be opened and edited.
- When `PageVisible` of the open page is set to `False`, or that page is deleted, the sidebar becomes closed (no event is fired).

## 6. Shortcut Keys

The `ShortCut` of a page receives only keys that no other component on the form used. Keys arrive in the following order, and a key used by an earlier step does not reach the sidebar.

| Order | Processing |
|---|---|
| 1 | The form's `OnKeyDown` (when `KeyPreview = True`). Setting `Key := 0` prevents it from reaching steps 2 and later |
| 2 | `OnKeyDown` of the focused component |
| 3 | Menu and ActionList shortcuts |
| 4 | Keys the focused component uses itself (F4 of a ComboBox, Ctrl+A of an Edit, etc.) |
| 5 | The TCSideBar shortcut |

- Only keys within the same form as the sidebar are handled. It works only while the sidebar is `Enabled` and visible.
- When a component that uses WebView2 has focus, keys do not reach the application, so it does not work.

## 7. Appearance

### 7.1 Colors (Dark/Light)

Drawn with system colors only. Switching between dark and light is left to the application side, e.g. MetaDarkStyle.

| Part | Color |
|---|---|
| Background of the icon bar and header | `clBtnFace` |
| Background of the page | `clBtnFace` (can be changed with the page's `Color`) |
| Header text | `clBtnText` |
| Icon under the mouse | Rounded rectangle of `clBtnHighlight` |
| Icon of the open page | Rounded outline of `clHighlight` |
| Icon with `Enabled = False` | Gray |
| Splitter | Vertical line of `clBtnShadow` |

### 7.2 Display Scale (High DPI)

According to the Windows display scale (125%, 150%, etc.), `IconBarWidth`, `PanelWidth`, `MinPanelWidth`, `MaxPanelWidth`, `SplitterWidth`, the header height, and the size of [x] are scaled up automatically (when the form's `Scaled = True`).

- To enlarge the icons, set the TImageList's `Scaled` to `True` and prepare images in different sizes. When there is no image of the exact size, at 125% or below the 100% image is used as is (an LCL rule).
## 8. Usage Examples

### 8.1 Show the header in the form title when a page is opened

```pascal
procedure TForm1.CSideBar1PageOpen(Sender: TObject; Index: Integer);
begin
  Caption := CSideBar1.Pages[Index].Caption;
end;
```

### 8.2 Do not let a page be closed while there is unsaved data

```pascal
procedure TForm1.CSideBar1PageChanging(Sender: TObject; Index: Integer;
  var Allow: Boolean);
begin
  if (Index = -1) and FModified then
    Allow := False;
end;
```

### 8.3 Open and close from code

```pascal
CSideBar1.OpenPage(0);           // Open the first page
CSideBar1.ClosePage;             // Close the open page
CSideBar1.ActivePage := PageFind;   // Open a page specified by name
```

### 8.4 Build a header for each page (ShowHeader = False)

1. Set `ShowHeader` of TCSideBar to `False`.
2. Open a page, place a TPanel on it, and set its `Align` to `alTop`.
3. On the TPanel, place a label and a close button.
4. Write the following in the `OnClick` of the close button.

```pascal
procedure TForm1.PageACloseButtonClick(Sender: TObject);
begin
  CSideBar1.ClosePage;
end;
```

### 8.5 Save the panel widths and the open page, and restore them at the next startup

```pascal
uses
  IniFiles;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  Ini: TIniFile;
  i: Integer;
begin
  Ini := TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini'));
  try
    Ini.WriteInteger('SideBar', 'Active', CSideBar1.ActivePageIndex);
    for i := 0 to CSideBar1.PageCount - 1 do
      Ini.WriteInteger('SideBar', 'Width' + IntToStr(i), CSideBar1.Pages[i].PanelWidth);
  finally
    Ini.Free;
  end;
end;

procedure TForm1.FormShow(Sender: TObject);
var
  Ini: TIniFile;
  i: Integer;
begin
  Ini := TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini'));
  try
    for i := 0 to CSideBar1.PageCount - 1 do
      CSideBar1.Pages[i].PanelWidth :=
        Ini.ReadInteger('SideBar', 'Width' + IntToStr(i), CSideBar1.Pages[i].PanelWidth);
    CSideBar1.ActivePageIndex := Ini.ReadInteger('SideBar', 'Active', -1);
  finally
    Ini.Free;
  end;
end;
```

- The saved widths are values after scaling by the display scale. If you start with a different display scale, the apparent widths change.

### 8.6 Open and close pages with shortcut keys

```pascal
uses
  LCLType,   // VK_F1, etc.
  Menus;     // ShortCut function

procedure TForm1.FormCreate(Sender: TObject);
begin
  CSideBar1.Pages[0].ShortCut := ShortCut(VK_F1, [ssCtrl]);   // Ctrl+F1 for the first page
  CSideBar1.Pages[1].ShortCut := ShortCut(VK_F2, [ssCtrl]);   // Ctrl+F2 for the second page
end;
```

- If you use the same key as a menu or ActionList, that one takes effect. Choose keys that do not overlap.
- Keys used by the focused component, and keys pressed while a component that uses WebView2 has focus, do not reach the sidebar.

### 8.7 Create in code

```pascal
uses
  uCSideBar;

procedure TForm1.FormCreate(Sender: TObject);
var
  SB: TCSideBar;
  P: TCSideBarPage;
  L: TListBox;
begin
  SB := TCSideBar.Create(Self);
  SB.Parent := Self;                  // Placed at the left edge (Align = alLeft)
  SB.Images := ImageList1;
  SB.OnPageOpen := @CSideBar1PageOpen;   // Use the handler from 8.1

  P := TCSideBarPage.Create(Self);
  P.Caption := 'History';
  P.ImageIndex := 0;
  P.Parent := SB;                     // Becomes the last page of the sidebar

  L := TListBox.Create(Self);
  L.Parent := P;                      // Place it on the page
  L.Align := alClient;

  Memo1.Align := alClient;            // Stretch the main body to fill the remaining area
end;
```

### 8.8 Hide a page / make it unusable

```pascal
CSideBar1.Pages[2].PageVisible := False;   // Remove the icon (the icons below move up)
CSideBar1.Pages[3].Enabled := False;       // Gray out the icon and make it unclickable
```
