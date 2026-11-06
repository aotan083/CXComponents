# TCExpandPanel User Manual

Author: aotan083
Date: 2026-11-06
Version: 1.1

---

## 1. Overview and Classes

Components that line up VS Code Explorer-style "collapsible panels with a title bar".

```
+-----------------------------------------+
| v Open Editors                          |  <- TCRollout (1st)
|   cdb.py                                |
+-----------------------------------------+
| v Files                                 |  <- TCRollout (2nd, Fill = True)
|   (the body fills the remaining space)  |
+-----------------------------------------+
| > Outline                               |  <- a closed TCRollout
+-----------------------------------------+
| v FPC Projects         [+] [folder] [...] |  <- buttons on the right of the title bar
|   No project files found.               |
+-----------------------------------------+
  TCExpandPanel (container)
```

- **TCRollout** is a single collapsible panel. It has a title bar (arrow, Caption, buttons on the right) and a body where components can be placed. It can also be used on its own.
- **TCExpandPanel** is a container that lines up several TCRollout panels. Panels are added with `AddPanel`.
- Clicking the title bar opens or closes the panel. Opening and closing change the size smoothly.
- The buttons on the right of the title bar are registered in `Buttons` (you do not need to place components). If a TPopupMenu is set on a button, that menu opens when the button is pressed.
- The position of the title bar (top, bottom, left, right) is decided by `HeaderPosition` of TCRollout. The direction of expansion is decided by it as well.
- When the contents of the container overflow, a scroll bar appears.

| Item | Details |
|---|---|
| Lazarus | 4.8, 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Description |
|---|---|---|---|---|
| `TCRollout` | `uCExpandPanel` | cx | `TCustomControl` | A single collapsible panel |
| `TCExpandPanel` | `uCExpandPanel` | cx | `TCustomControl` | A container that lines up `TCRollout` panels |
| `TCRolloutButton` | `uCExpandPanel` | cx | `TCollectionItem` | Definition of one button on the right of the title bar |
| `TCRolloutButtons` | `uCExpandPanel` | cx | `TOwnedCollection` | List of `TCRolloutButton` |

| Type | Unit | Description |
|---|---|---|
| `TCRolloutHeaderPosition` | `uCExpandPanel` | `hpTop`, `hpBottom`, `hpLeft`, `hpRight`. Position of the title bar |
| `TCExpandOrientation` | `uCExpandPanel` | `eoVertical` (stack vertically), `eoHorizontal` (line up horizontally) |
| `TCRolloutButtonsShow` | `uCExpandPanel` | `bsAlways` (always show), `bsHover` (show only while the mouse is over the title bar) |
| `TCRolloutButtonEvent` | `uCExpandPanel` | `procedure(Sender: TObject; Index: Integer) of object`. The type of `OnButtonClick` |
| `TCRolloutExpandingEvent` | `uCExpandPanel` | `procedure(Sender: TObject; var Allow: Boolean) of object`. The type of `OnExpanding` |

- When placed on a form, `uCExpandPanel` is added to uses automatically.
- When placed on a form, cx is added to the project's required packages automatically.
- When creating them in code, write it in uses yourself.

## 2. From Placing on a Form to Running

### 2.1 Lining Up Panels in a Container

1. From the palette [CX], place TCExpandPanel on the form. Decide its size and `Align` freely.
2. Right-click TCExpandPanel and choose "Add Panel". A TCRollout is added at the end.
3. In the Object Inspector, set the panel's `Caption` (header) and `ExpandedSize` (size when open).
4. Place components (TListBox, TTreeView, etc.) on the panel. If you set `Align` to `alClient`, they fill the body.
5. Repeat steps 2 to 4 for as many panels as needed.
6. Run it. Clicking the title bar opens or closes the panel.

- To change the order of panels, select a panel and choose "Move Up" or "Move Down" from the right-click menu.
- To delete a panel, select it and choose "Delete Panel" from the right-click menu.
- A panel that fills the remaining space can be decided with `Fill = True` (4.1). If no panel is `Fill`, the last open panel fills the remaining space (3.3).
- The size of a panel can be changed by dragging the thin band between panels (blue at design time) with the mouse. It shares the size with the neighboring panel (3.5).
- At design time, to select a panel, click a part of the panel other than the title bar (a place where no component is put in the body), or choose it from the list at the top of the Object Inspector. Clicking the title bar opens or closes it.

### 2.2 Adding Buttons to a Panel

1. Place a TImageList on the form and add the images to be used as icons. Set that TImageList in the panel's `Images`.
2. Press [...] of the panel's `Buttons` and add buttons with [Add].
3. For each button, set `ImageIndex` (icon number) and `Hint` (hint text).
4. For a button that should show a menu, set a TPopupMenu in `DropDownMenu`.
5. Write the processing for when a button is pressed by double-clicking `OnButtonClick` on the Events tab of the panel. `Index` is the number in `Buttons`.
6. If you want the buttons to be shown only while the mouse is over the title bar, set `ButtonsShow` to `bsHover`.

### 2.3 Using a Panel on Its Own

A TCRollout can be placed directly on a form or a TPanel without putting it in a TCExpandPanel. If you set `Align` to `alTop`, `alLeft`, etc., the surrounding components move as the panel opens and closes.

- When `Align` is `alNone`, a panel with `hpBottom` or `hpRight` opens and closes without moving the side of the title bar.
- To change the size of a panel by dragging its border, you can use the standard TSplitter (when the panels are lined up with `Align = alTop` or similar).

### 2.4 Display Language (Japanese / English)

The messages that this component shows on the screen appear in Japanese or English. There is one language for all cx components, not one per component.

Write the following in WebView2.ini in the same folder as the EXE. Even for applications that do not use WebView2, place this ini (only `[CX]` needs to be written).

```ini
[CX]
Language=en
```

| Order | How it is decided |
|---|---|
| 1 | If `Language` in `[CX]` is `ja` or `en`, that language (case-insensitive) |
| 2 | Otherwise (no ini, no `[CX]`, empty, or another value), the Windows display language: `ja` for Japanese, `en` for anything else |

- It is decided only once, when text is first shown. Rewriting it while the application is running has no effect until the next start.
- The items shown in the right-click menu of the form designer in the IDE ("Add Panel" etc.) are always in Japanese.
- The `Hint` of a button is text decided by the application. It is not covered by this language setting.

## 3. TCExpandPanel

### 3.1 Properties

| Name | Type | Access | Description |
|---|---|---|---|
| `Orientation` | `TCExpandOrientation` | Read/Write | Direction in which the panels are lined up (default `eoVertical`). `eoVertical` stacks them vertically. `eoHorizontal` lines them up horizontally |
| `Multiple` | `Boolean` | Read/Write | Whether several panels can be open at the same time (default `True`). If `False`, opening one panel closes the others (accordion) |
| `AllowResize` | `Boolean` | Read/Write | Whether the borders between panels can be dragged to change sizes (default `True`). If `False`, the border bands and the gaps for them disappear |
| `Spacing` | `Integer` | Read/Write | Margin between panels (default 0) |
| `Scrollable` | `Boolean` | Read/Write | Whether a scroll bar appears when the length of the lined-up panels is longer than the container (default `True`). If `False`, the overflowing part is cut off |
| `Panels[Index]` | `TCRollout` | Read | A panel in the container (in the order they are lined up). Run time only |
| `PanelCount` | `Integer` | Read | Number of panels. Run time only |
| `Align` | `TAlign` | Read/Write | Placement in the parent |
| `Anchors` | `TAnchors` | Read/Write | Which edges follow when the size of the parent changes |
| `BorderSpacing` | `TControlBorderSpacing` | Read/Write | Surrounding margin |
| `Color` | `TColor` | Read/Write | Background color (the color of the places where no panel is lined up) |
| `Constraints` | `TSizeConstraints` | Read/Write | Upper and lower limits of the size |
| `Enabled` | `Boolean` | Read/Write | Whether it can be used |
| `Font` | `TFont` | Read/Write | Font |
| `Height` | `Integer` | Read/Write | Height |
| `Left` | `Integer` | Read/Write | Position of the left edge |
| `Name` | `TComponentName` | Read/Write | Component name |
| `ParentColor` | `Boolean` | Read/Write | Whether to use the `Color` of the parent |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the `Font` of the parent |
| `ParentShowHint` | `Boolean` | Read/Write | Whether to use the `ShowHint` of the parent |
| `ShowHint` | `Boolean` | Read/Write | Whether to show hints |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely |
| `Top` | `Integer` | Read/Write | Position of the top edge |
| `Visible` | `Boolean` | Read/Write | Whether it is shown |
| `Width` | `Integer` | Read/Write | Width |

- Panels with `Visible = False` are not counted when lining up.
- The `Align` of a TCRollout inside a container is decided by the container, so setting it has no effect.
- `Spacing` is scaled with the display scale (when `Scaled = True` on the form).

### 3.2 Methods

| Name | Arguments | Return value | Description |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | - | Creates it. Used when creating in code (8.7) |
| `AddPanel` | `ARollout: TCRollout` | - | Adds a panel at the end. Does nothing if it is already in the container. If nil, an exception (`EArgumentException`) is raised |
| `InsertPanel` | `Index: Integer; ARollout: TCRollout` | - | Adds a panel at the position `Index`. If `Index` is out of range, it is added at the end |
| `RemovePanel` | `ARollout: TCRollout` | - | Removes the panel from the container (its `Parent` becomes nil). The panel is not freed |
| `MovePanel` | `CurIndex, NewIndex: Integer` | - | Changes the order of the panels. Does nothing if out of range or the same number |
| `IndexOfPanel` | `ARollout: TCRollout` | `Integer` | The number of the panel. -1 if it is not in the container |

- Components other than `TCRollout` cannot be put in the container (setting one as `Parent` in code raises an `EInvalidOperation` exception).

### 3.3 How Panels Are Lined Up

When `Orientation = eoVertical` (stacked vertically), the panels are lined up as follows. For `eoHorizontal`, read height and width the other way around.

| Panel | Size (height when stacked vertically) |
|---|---|
| Open, `Fill = False` | `ExpandedSize` |
| Closed | `HeaderSize` (only the title bar) |
| Open, `Fill = True` | The remaining space divided equally among the open `Fill` panels (the minimum is the title bar plus about 60 px) |

- If no panel is `Fill = True`, the last one of the open panels, in the order they are lined up, fills the remaining space (it is treated the same as `Fill = True`). If no panel is open, the remaining space stays empty (the background shows).
- When `AllowResize = True`, there is a gap of 5 px (enlarged with the display scale) between panels. This is the border, and it can be dragged (3.5).
- A `HeaderPosition` that does not match the direction of lining up is read differently inside a container. When stacked vertically, `hpLeft` and `hpRight` are treated as `hpTop`. When lined up horizontally, `hpTop` and `hpBottom` are treated as `hpLeft`. The value of `HeaderPosition` itself does not change.
- The width of a panel (height when lined up horizontally) fills the container.

### 3.4 Scrolling

When the length of the lined-up panels is longer than the container and `Scrollable = True`, the standard Windows scroll bar appears (vertical when stacked vertically, horizontal when lined up horizontally).

| Operation | Behavior |
|---|---|
| Operating the scroll bar | Scrolls |
| Mouse wheel (when stacked vertically) | Scrolls vertically |
| Shift + mouse wheel (when lined up horizontally) | Scrolls horizontally |

- When the wheel is turned over a component on a panel (such as a TMemo), that component receives it.
- When a panel closes and the whole becomes shorter, the scroll position is brought back in automatically.

### 3.5 Changing Panel Sizes by Dragging a Border

When `AllowResize = True` (default), you can drag the thin band between panels with the mouse to change the sizes of the two panels before and after it. It works the same at run time and at design time (form designer).

| Panels before and after | Behavior |
|---|---|
| Neither is `Fill = True` | They share the size. As one becomes larger, the other becomes smaller (`ExpandedSize` changes) |
| One fills the remaining space (`Fill = True`, or the last panel in 3.3) | Only the size of the other changes. The panel that fills the remaining space gets the remaining size |
| Both fill the remaining space | It cannot be moved |

- A border next to a closed panel, or a border in the middle of an open/close animation, cannot be moved.
- The smallest size is the title bar plus about 60 px.
- When the mouse is over a border, the cursor becomes an arrow (up-down for vertical stacking, left-right for horizontal stacking) and a blue line (`clHighlight`) appears in the middle. The blue line stays while dragging.
- At design time, the borders that can be moved are shown as blue bands (thin bands of about 5 px). Drag the middle of a band with the mouse to change the size; `ExpandedSize` is saved in the form.
- To decide sizes without dragging a border, select the panel and write `ExpandedSize` in the Object Inspector (4.1).

## 4. TCRollout

### 4.1 Properties

| Name | Type | Access | Description |
|---|---|---|---|
| `Caption` | `TCaption` | Read/Write | Text of the title bar |
| `Expanded` | `Boolean` | Read/Write | Whether it is open (default `True`). Writing it opens or closes the panel (events are also raised) |
| `HeaderPosition` | `TCRolloutHeaderPosition` | Read/Write | Position of the title bar (default `hpTop`). The direction of expansion is decided as well (4.4) |
| `HeaderSize` | `Integer` | Read/Write | Thickness of the title bar (default 24). Height for `hpTop`/`hpBottom`, width for `hpLeft`/`hpRight` |
| `ExpandedSize` | `Integer` | Read/Write | Size in the direction of expansion when open (default 150). It does not become smaller than `HeaderSize` |
| `Fill` | `Boolean` | Read/Write | Whether, inside a container and when open, the panel fills the remaining space (default `False`). It has no effect on a single panel |
| `ShowArrow` | `Boolean` | Read/Write | Whether to show the arrow in the title bar (default `True`) |
| `Images` | `TCustomImageList` | Read/Write | Image list that holds the images of the button icons |
| `ImagesWidth` | `Integer` | Read/Write | Width at which icons are drawn (px at a display scale of 100%). If 0 (default), the `Width` of `Images` |
| `Buttons` | `TCRolloutButtons` | Read/Write | List of buttons on the right of the title bar (4.2) |
| `ButtonsShow` | `TCRolloutButtonsShow` | Read/Write | When to show the buttons (default `bsAlways`). `bsHover` shows them only while the mouse is over the title bar. They are always shown at design time. They also stay shown while a menu is open. The place of the buttons is kept free even when they are not shown |
| `Animated` | `Boolean` | Read/Write | Whether the size changes little by little when opening or closing (default `True`). At design time it always changes immediately |
| `AnimationTime` | `Integer` | Read/Write | Time taken to open or close (milliseconds; default 150). If 0 or less, it changes immediately |
| `ExpandPanel` | `TCExpandPanel` | Read | The container this panel is in. nil for a single panel. Run time only |
| `Align` | `TAlign` | Read/Write | Placement in the parent (no effect inside a container) |
| `Anchors` | `TAnchors` | Read/Write | Which edges follow when the size of the parent changes |
| `BorderSpacing` | `TControlBorderSpacing` | Read/Write | Surrounding margin |
| `Color` | `TColor` | Read/Write | Background color of the body (default `clBtnFace`) |
| `Constraints` | `TSizeConstraints` | Read/Write | Upper and lower limits of the size |
| `Enabled` | `Boolean` | Read/Write | Whether it can be used. If `False`, opening/closing and the buttons stop working, and the icons turn gray |
| `Font` | `TFont` | Read/Write | Font of the title bar |
| `Height` | `Integer` | Read/Write | Height |
| `Left` | `Integer` | Read/Write | Position of the left edge |
| `Name` | `TComponentName` | Read/Write | Component name |
| `ParentColor` | `Boolean` | Read/Write | Whether to use the `Color` of the parent |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the `Font` of the parent |
| `ParentShowHint` | `Boolean` | Read/Write | Whether to use the `ShowHint` of the parent |
| `PopupMenu` | `TPopupMenu` | Read/Write | Menu shown on right-click |
| `ShowHint` | `Boolean` | Read/Write | Whether to show hints |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely |
| `Top` | `Integer` | Read/Write | Position of the top edge |
| `Visible` | `Boolean` | Read/Write | Whether it is shown |
| `Width` | `Integer` | Read/Write | Width |

- If you change the size of an open panel in the direction of expansion (by dragging in the form designer or by setting `Height`/`Width`), that size becomes `ExpandedSize`.
- The size of a closed panel in the direction of expansion is fixed at `HeaderSize`.
- `HeaderSize` and `ExpandedSize` are scaled with the display scale (when `Scaled = True` on the form).
- To enlarge button icons, set `Scaled` of the TImageList to `True` and prepare images of different sizes.

### 4.2 Buttons (TCRolloutButton)

One item of `Buttons` is one button on the right of the title bar.

| Name | Type | Access | Description |
|---|---|---|---|
| `ImageIndex` | `TImageIndex` | Read/Write | Number of the icon in `Images`. If -1 (default), no icon is drawn (the frame remains and can be pressed) |
| `Hint` | `string` | Read/Write | Hint shown when the mouse rests on the button. When `ShowHint = True` |
| `DropDownMenu` | `TPopupMenu` | Read/Write | Menu shown when the button is pressed (4.3) |
| `Enabled` | `Boolean` | Read/Write | If `False` (default `True`), the icon turns gray and the button cannot be pressed |
| `Visible` | `Boolean` | Read/Write | If `False` (default `True`), the button is not shown. The buttons on its right move over |

- The buttons are lined up in the order of the numbers in `Buttons`, from left to right (for `hpTop`/`hpBottom`). For `hpLeft`/`hpRight`, they are lined up from top to bottom below the arrow.
- The number (`Index`) is the order including buttons with `Visible = False`.

`Buttons` is operated in the same way as a TCollection.

| Name | Description |
|---|---|
| `Add` | Adds a button at the end (it returns a `TCollectionItem`, so cast it to `TCRolloutButton(...)` to use it) |
| `Items[Index]` | A button |
| `Count` | Number of buttons |
| `Delete(Index)`, `Clear` | Delete buttons |

### 4.3 What Happens When a Button Is Pressed

1. When a button is pressed, `OnButtonClick` is called (`Index` is the number in `Buttons`).
2. If the button has a `DropDownMenu`, the menu opens next.
   - For `hpTop`/`hpBottom`, it appears at the lower left of the button.
   - For `hpLeft`/`hpRight`, it appears at the upper right of the button.
   - The `PopupComponent` of the menu is the panel (TCRollout).

- A button with `Enabled = False` and a panel with `Enabled = False` cannot be pressed.
- At design time (form designer), pressing a button does nothing.

### 4.4 Position of the Title Bar and Direction of Expansion

| `HeaderPosition` | Title bar | Direction of expansion | Size |
|---|---|---|---|
| `hpTop` (default) | Top | Extends downward | Height |
| `hpBottom` | Bottom | Extends upward | Height |
| `hpLeft` | Left | Extends to the right | Width |
| `hpRight` | Right | Extends to the left | Width |

- The arrow points toward the body when open, and sideways (`hpTop`/`hpBottom`) or downward (`hpLeft`/`hpRight`) when closed.
- The text of `hpLeft` reads from bottom to top, and that of `hpRight` from top to bottom. The part of the text of a vertical title bar that overflows is cut off.
- In a vertical title bar, the arrow and the buttons are lined up from top to bottom in the order of the arrow and the buttons, and the text appears in the remaining part.

### 4.5 Methods

TCRollout has no methods added by this component. Opening and closing are done with `Expanded`.

### 4.6 Events

| Name | Arguments | Description |
|---|---|---|
| `OnExpanding` | `Sender: TObject; var Allow: Boolean` | Before opening or closing. Set `Allow := False` to cancel. At this time `Expanded` has not changed yet |
| `OnExpand` | `Sender: TObject` | When opened. Called at the start of the animation (it does not wait for the end) |
| `OnCollapse` | `Sender: TObject` | When closed. Called at the start of the animation (it does not wait for the end) |
| `OnButtonClick` | `Sender: TObject; Index: Integer` | When a button is pressed. `Index` is the number in `Buttons` |

| Operation | Order |
|---|---|
| Open | `OnExpanding` -> `OnExpand` |
| Close | `OnExpanding` -> `OnCollapse` |
| Press a button | `OnButtonClick` -> (if there is a `DropDownMenu`) the menu opens |

- Whether it is opened or closed by clicking the title bar or by code (`Expanded := ...`), the events are raised in the same order.
- When another panel is closed in a container with `Multiple = False`, the `OnExpanding` and `OnCollapse` of that panel are also called.

#### When Events Are Not Raised

| When | Description |
|---|---|
| Startup | When the .lfm is loaded and `Expanded` is restored |
| Design time | Operations in the form designer |
| The state does not change | Setting `Expanded := True` on an open panel, or `Expanded := False` on a closed panel |

## 5. Operation

### 5.1 At Run Time

| Operation | Behavior |
|---|---|
| Click the title bar (arrow, text) | Opens or closes (with animation) |
| Click a button | `OnButtonClick`, then `DropDownMenu` |
| Put the mouse over the title bar | If `ButtonsShow = bsHover`, the buttons appear |
| Put the mouse over a button | The button is highlighted. If `ShowHint = True`, `Hint` is shown |
| While a button is held down | The highlight becomes darker |

### 5.2 Design Time (Form Designer)

| Operation | Behavior |
|---|---|
| Click the title bar | Opens or closes. Components can be placed on an open panel |
| Right-click the container -> "Add Panel" | Adds a panel at the end |
| Right-click a panel -> "Delete Panel" | Deletes a panel that is in a container |
| Right-click a panel -> "Move Up" / "Move Down" | Changes the order of the panel in the container |
| Drag the blue band between panels | Changes the sizes of the panels before and after it (3.5; it becomes `ExpandedSize`) |
| Drag the edge of a single panel | Changes the size of a single panel (it becomes `ExpandedSize`) |
| Dashed frame around the container | Shows the place and extent of the container. It does not appear at run time |

- The position and size of a panel in a container are decided by the container, so they return to the original even if you drag the edge of the panel. Decide the size by dragging the blue band between panels, or with `ExpandedSize`.

## 6. Display

### 6.1 Colors (Dark / Light)

Only system colors are used. Switching between dark and light is left to the application side, e.g. MetaDarkStyle.

| Part | Color |
|---|---|
| Background of the title bar | `clBtnFace` |
| Background of the body | `Color` (default `clBtnFace`) |
| Text and arrow | `clBtnText` |
| Line at the border of the title bar (when open) | `clBtnShadow` |
| Button under the mouse | Rounded rectangle of `clBtnHighlight` |
| Button while pressed | Rounded rectangle of `clBtnShadow` |
| Button with `Enabled = False` | Gray icon |

### 6.2 Display Scale (High DPI)

The thickness of the title bar, the size of the buttons, the size of the arrow, and the margins are enlarged automatically to match the Windows display scale (125%, 150%, etc.), when `Scaled = True` on the form.

## 7. Notes

- **Position of child components**: the `Left` and `Top` of a component placed in the body are relative to the upper left of the panel and do not include the title bar. For `hpTop`, place components below the height of the title bar (default 24). For `hpLeft`, place them to the right of the width of the title bar. Components placed with `Align` (such as `alClient`) line up avoiding the title bar.
- **The body of a closed panel**: the body of a closed panel is cut off and not visible (the components do not disappear).
- **When it overflows**: in a container with `Scrollable = False`, the overflowing part is cut off.

## 8. Examples

### 8.1 Load the Contents When It Opens

```pascal
procedure TForm1.CRollout1Expand(Sender: TObject);
begin
  LoadFileList;
end;
```

### 8.2 Do Not Let It Close When There Is Unsaved Data

```pascal
procedure TForm1.CRollout1Expanding(Sender: TObject; var Allow: Boolean);
begin
  // Stop it only when it is open and about to close
  if (Sender as TCRollout).Expanded and FModified then
    Allow := False;
end;
```

### 8.3 Separate the Processing for Each Button

```pascal
procedure TForm1.CRollout3ButtonClick(Sender: TObject; Index: Integer);
begin
  case Index of
    0: NewProject;     // [+]
    1: OpenProject;    // [folder]
    // 2 ([...]) has a DropDownMenu, so nothing needs to be done here
  end;
end;
```

### 8.4 Open and Close in Code

```pascal
CRollout1.Expanded := False;                    // close
CRollout1.Expanded := not CRollout1.Expanded;   // toggle
CRollout1.Animated := False;                    // change immediately
```

### 8.5 Make It an Accordion (Only One Open)

```pascal
CExpandPanel1.Multiple := False;
```

### 8.6 Save the Open Panels and Restore Them at the Next Start

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
    for i := 0 to CExpandPanel1.PanelCount - 1 do
      Ini.WriteBool('Panels', 'Expanded' + IntToStr(i), CExpandPanel1.Panels[i].Expanded);
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
    for i := 0 to CExpandPanel1.PanelCount - 1 do
      with CExpandPanel1.Panels[i] do
      begin
        Animated := False;     // at startup, switch immediately without moving
        Expanded := Ini.ReadBool('Panels', 'Expanded' + IntToStr(i), Expanded);
        Animated := True;
      end;
  finally
    Ini.Free;
  end;
end;
```

### 8.7 Creating Them in Code

```pascal
uses
  uCExpandPanel;

procedure TForm1.FormCreate(Sender: TObject);
var
  EP: TCExpandPanel;
  R1, R2: TCRollout;
  B: TCRolloutButton;
  L: TListBox;
begin
  EP := TCExpandPanel.Create(Self);
  EP.Parent := Self;
  EP.Align := alLeft;
  EP.Width := 300;

  R1 := TCRollout.Create(Self);
  R1.Caption := 'Files';
  R1.Fill := True;                  // fill the remaining space
  EP.AddPanel(R1);                  // put it in the container
  L := TListBox.Create(Self);
  L.Parent := R1;                   // place it on the panel
  L.Align := alClient;

  R2 := TCRollout.Create(Self);
  R2.Caption := 'FPC Projects';
  R2.ExpandedSize := 120;
  R2.Images := ImageList1;
  R2.ShowHint := True;
  R2.ButtonsShow := bsHover;        // show buttons only while the mouse is over
  B := TCRolloutButton(R2.Buttons.Add);
  B.ImageIndex := 0;
  B.Hint := 'New';
  B := TCRolloutButton(R2.Buttons.Add);
  B.ImageIndex := 2;
  B.Hint := 'More';
  B.DropDownMenu := PopupMenu1;     // pressing [...] opens this menu
  R2.OnButtonClick := @CRollout3ButtonClick;   // use the processing of 8.3
  EP.AddPanel(R2);
end;
```

### 8.8 A Single Panel at the Bottom (Title Bar at the Bottom)

1. Place a TCRollout on the form, and set `Align` to `alBottom` and `HeaderPosition` to `hpBottom`.
2. Set `ExpandedSize` to the height when open.
3. When run, the title bar appears at the bottom edge, and clicking it expands and collapses the panel upward.

### 8.9 Replacing and Removing Panels

```pascal
CExpandPanel1.MovePanel(0, 2);               // move the first panel to the third position
CExpandPanel1.RemovePanel(CRollout2);        // remove it from the container (not freed)
CExpandPanel1.InsertPanel(0, CRollout2);     // put it back at the beginning
```
