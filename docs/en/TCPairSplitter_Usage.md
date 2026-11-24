# TCPairSplitter User Manual

Author: aotan083
Date: 2026-11-08
Version: 1.0

---

**Operating environment**: Lazarus 5.0 or later (FPC 3.2.2). Lazarus 4.8 and earlier are not supported.

## 1. Overview and Classes

A component used like TPairSplitter: it combines two sides (Side1 and Side2) and the splitter between them. Dragging the splitter changes the size of the two sides. It adds the following to TPairSplitter.

- Each side can be hidden or shown. Hiding one side makes the other fill the whole area. Showing it again restores both.
- A colored line (the same blue line as TCSplitter) appears on the splitter when the mouse is over it and while it is being dragged.
- At design time (in the form designer), you can also drag the splitter to change its position.

```
+--------------------+--+------------------------------+
| Side1              |┃ | Side2                        |
| (place controls)   |┃ | (place controls)             |
+--------------------+--+------------------------------+
                      splitter (dragging changes Position)
```

| Item | Details |
|---|---|
| Lazarus | 5.0RC1 or later |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Contents |
|---|---|---|---|---|
| `TCPairSplitter` | `uCSplitter` | cx | `TCustomControl` | Two sides and the splitter |
| `TCPairSplitterSide` | `uCSplitter` | cx | `TCustomPanel` | One side. Place controls on it. It can only be placed on a `TCPairSplitter` |

| Type | Unit | Contents |
|---|---|---|
| `TCPairSplitterType` | `uCSplitter` | Direction of the split. `cpsHorizontal` (side by side) and `cpsVertical` (top and bottom) |

- When you place it on a form, `uCSplitter` is added to uses automatically, and cx is added to the project's required packages automatically.
- When creating it in code, write it in uses yourself.

### 1.2 Differences from TPairSplitter

| Item | TPairSplitter | TCPairSplitter |
|---|---|---|
| Two sides, Position, split direction | Yes | Same |
| Hiding a side | The space stays empty | The other side fills the whole area. Showing it restores both |
| Hiding both sides | Possible | Not possible (the side hidden later is refused) |
| Look of the splitter | Standard splitter (no change on mouse over) | A blue line appears on mouse over and while dragging |
| Line color | Cannot be specified | Specified with `HighlightColor` |
| Dragging at design time | Standard behavior | Drag the splitter to change Position |
| Type of the split direction | `TPairSplitterType` | `TCPairSplitterType` (only the name differs) |

## 2. From Placing on a Form to Running

1. Place TCPairSplitter from the palette [CX] on the form. Two sides (`CPairSplitterSide1` and `CPairSplitterSide2`) are created automatically.
2. Decide the size and placement (`Align`, etc.).
3. Place buttons and other controls on each side.
4. In the Object Inspector, set `SplitterType` (split direction) and `Position` (size of side 1). Or drag the splitter in the form designer.
5. Run. When the mouse is over the splitter a blue line appears, and dragging changes the size of the two sides.

- To select a side, click on it in the form designer, or pick it from the list in the Object Inspector.
- If you delete a side, a new side is created automatically (there are always two sides).
- `Visible` of a side can be changed in the Object Inspector. If you set it to `False` and save, the application starts with that side hidden.

## 3. Hiding and Showing Each Side

| Operation | Behavior |
|---|---|
| Hide Side1 | Side2 fills the whole area. The splitter is not shown |
| Show Side1 | Side1 and Side2 return to their original state (the size of Side1 is `Position`) |
| Hide Side2 | Side1 fills the whole area. The splitter is not shown |
| Show Side2 | Side1 and Side2 return to their original state |
| Hide both | Not possible. If the other side is already hidden, the side you try to hide stays visible |
| Hide the whole component | `TCPairSplitter.Visible := False` (`Visible` of the sides does not change) |

How to specify a side (`CPairSplitter1` is the name of the TCPairSplitter):

```pascal
// Hide / show Side1
CPairSplitter1.Side1.Visible := False;      // CPairSplitter1.Side1.Hide; does the same
CPairSplitter1.Side1.Visible := True;       // CPairSplitter1.Side1.Show; does the same

// Hide / show Side2
CPairSplitter1.Side2.Visible := False;      // CPairSplitter1.Side2.Hide;
CPairSplitter1.Side2.Visible := True;       // CPairSplitter1.Side2.Show;
```

- You can also specify a side by the name it received when placed on the form (`CPairSplitterSide1`, `CPairSplitterSide2`).
- While a side is hidden, `Position` is remembered. When the side is shown, it returns to that size.
- While a side is hidden, the splitter cannot be dragged.
- To hide both, use `TCPairSplitter.Visible` instead of the sides.

## 4. TCPairSplitter

### 4.1 Properties

| Name | Type | Access | Default | Contents |
|---|---|---|---|---|
| `SplitterType` | `TCPairSplitterType` | read/write | `cpsHorizontal` | Split direction. `cpsHorizontal`: side by side (side 1 on the left); `cpsVertical`: top and bottom (side 1 on top) |
| `Position` | `Integer` | read/write | 45 | Size of side 1 (width if side by side, height if top and bottom). A value below 0 becomes 0. A value that is too large is fitted when displayed (4.3), but the value of `Position` itself does not change |
| `SplitterWidth` | `Integer` | read/write | 5 | Thickness of the splitter (px at 100% display scale). A value below 1 becomes 1 |
| `HighlightColor` | `TColor` | read/write | `clHighlight` | Color of the blue line on the splitter. The default is the Windows selection color, and follows the theme and dark mode. When the value is the default (`clHighlight`) and the Windows selection color is too dark (brightness 0-255 below 80, for example when the selection color is set to a dark gray with MetaDarkStyle), the line would be invisible on a dark background, so it is drawn in the accent blue (#0078D4) (`CXSplitLineColor` in `uCXLang`). If another color is specified, that color is used |
| `SplitCursor` | `TCursor` | read/write | `crDefault` | Mouse cursor over the splitter. With `crDefault`, a horizontal arrow if side by side, a vertical arrow if top and bottom |
| `Color` | `TColor` | read/write | `clBtnFace` | Background color of the splitter |
| `Side1` | `TCPairSplitterSide` | read | ― | Side 1. For use at run time and in code |
| `Side2` | `TCPairSplitterSide` | read | ― | Side 2 |
| `Sides[Index]` | `TCPairSplitterSide` | read | ― | A side (0 is side 1, 1 is side 2). An out-of-range index raises an exception (`EListError`) |
| `Align`, `Anchors`, `BorderSpacing`, `Constraints`, `Enabled`, `Visible`, `PopupMenu`, `ShowHint`, `ParentShowHint` | | | | Standard |

### 4.2 Events

| Name | Arguments | Contents |
|---|---|---|
| `OnMoved` | `Sender: TObject` | After the position changed by dragging the splitter (when the drag ends; not raised if nothing changed). Not raised when `Position` is changed in code |
| `OnResize`, `OnChangeBounds` | `Sender: TObject` | When the size of the whole component changes |
| `OnMouseDown`, `OnMouseUp`, `OnMouseMove`, `OnMouseEnter`, `OnMouseLeave`, `OnMouseWheel`, etc. | Standard | Operations on the splitter (operations on a side are events of the side) |

### 4.3 How the Size of the Sides Is Decided

| State | Side 1 | Side 2 |
|---|---|---|
| Both visible (side by side) | Width = `Position`, height = whole height | Left = `Position` + splitter thickness, the remaining width |
| Both visible (top and bottom) | Height = `Position`, width = whole width | Top = `Position` + splitter thickness, the remaining height |
| Only side 1 visible | Whole area | ― |
| Only side 2 visible | ― | Whole area |

- When the size of the whole component changes, the size of side 1 (`Position`) does not change and side 2 grows or shrinks.
- The size of side 1 is kept in this range: the lower limit is the `Constraints` of side 1 (minimum 1), and the upper limit is "whole − splitter thickness − the lower limit of side 2 (`Constraints`, minimum 1)".
- `Position` and `SplitterWidth` are enlarged automatically to follow the display scale (125%, 150%, etc.) (when the form's `Scaled = True`).

## 5. TCPairSplitterSide

### 5.1 Properties

| Name | Type | Access | Contents |
|---|---|---|---|
| `Visible` | `Boolean` | read/write | Whether the side is shown. Setting `False` makes the other side fill the whole area (Chapter 3). It cannot be set to `False` if the other side is already hidden |
| `Color`, `ParentColor` | | read/write | Background color of the side |
| `Splitter` | `TCPairSplitter` | read | The TCPairSplitter that holds this side. Run time only |
| `ChildSizing`, `Constraints`, `Cursor`, `Enabled`, `PopupMenu`, `ShowHint`, `ParentShowHint` | | read/write | Standard. The minimum size in `Constraints` affects the range in which the splitter can be dragged |

The position and size of a side (`Left`, `Top`, `Width`, `Height`) and `Align` are decided by TCPairSplitter. The application does not change them.

### 5.2 Methods

The standard `Show` and `Hide` can be used. They behave the same as `Visible := True` and `Visible := False`.

### 5.3 Events

Standard events such as `OnMouseDown`, `OnMouseUp`, `OnMouseMove`, `OnMouseEnter`, `OnMouseLeave`, `OnMouseWheel`, and `OnResize` can be used.

## 6. Operation

### 6.1 At Run Time

| Operation | Behavior |
|---|---|
| Mouse over the splitter | A blue line (2px, `HighlightColor`) appears. The cursor becomes `SplitCursor` (by default a horizontal arrow if side by side) |
| Drag the splitter | The size of the two sides changes with the drag. The blue line moves with it. `OnMoved` is raised on release |
| One side is hidden | The splitter is not shown. It cannot be dragged |

- If you switch to another window during a drag (Alt+Tab, etc.), the drag is stopped. The position stays as it is.

### 6.2 At Design Time (Form Designer)

| Operation | Behavior |
|---|---|
| Drag the splitter | `Position` changes. When the form is saved, the value is saved |
| Click on a side | That side is selected |
| Place a control on a side | It becomes a child of that side |

- At design time, the splitter shows a thin gray line instead of the blue line (`HighlightColor` is the color of the run-time line).
- Controls other than sides cannot be placed on a TCPairSplitter.

## 7. Appearance

| Part | Appearance |
|---|---|
| Splitter background | `Color` |
| Splitter line (normally) | A 1px `clBtnShadow` line (in the center) |
| Splitter line (mouse over / dragging, at run time) | 2px `HighlightColor` (enlarged by the display scale) |
| Sides (at design time) | A dashed frame |

## 8. Examples

### 8.1 Split side by side and hide / show Side1

```pascal
procedure TForm1.ButtonToggleClick(Sender: TObject);
begin
  CPairSplitter1.Side1.Visible := not CPairSplitter1.Side1.Visible;
end;
```

### 8.2 Save the position and restore it at the next start

```pascal
uses
  IniFiles;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  with TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini')) do
  try
    WriteInteger('Splitter', 'Position', CPairSplitter1.Position);
  finally
    Free;
  end;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  with TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini')) do
  try
    CPairSplitter1.Position := ReadInteger('Splitter', 'Position', CPairSplitter1.Position);
  finally
    Free;
  end;
end;
```

- The saved value is the value after enlargement by the display scale.

### 8.3 Process when the position changes by dragging

```pascal
procedure TForm1.CPairSplitter1Moved(Sender: TObject);
begin
  Caption := 'Position = ' + IntToStr(CPairSplitter1.Position);
end;
```

### 8.4 Split top and bottom and change the line color

```pascal
CPairSplitter1.SplitterType := cpsVertical;
CPairSplitter1.HighlightColor := clRed;
```

### 8.5 Create in code

```pascal
uses
  uCSplitter;

procedure TForm1.FormCreate(Sender: TObject);
var
  P: TCPairSplitter;
  B: TButton;
begin
  P := TCPairSplitter.Create(Self);
  P.Parent := Self;
  P.Align := alClient;
  P.Position := 200;
  B := TButton.Create(Self);
  B.Parent := P.Side1;           // two sides are already created when it is created
  B.Align := alTop;
  B.Caption := 'Side1';
end;
```

## 9. Limitations

- There are only two sides (it cannot be increased). To split into three or more, place another TCPairSplitter inside a side of the TCPairSplitter.
- While the splitter is being dragged, the size of the sides is changed and redrawn as it moves (it is not a method that moves only a line in a separate window, like TCSideBar).
