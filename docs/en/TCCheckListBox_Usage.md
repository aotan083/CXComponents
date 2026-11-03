# TCCheckListBox User Manual

Author: aotan083
Date: 2026-10-29
Version: 1.0

---

## 1. Overview and Class

A component that adds to the LCL TCheckListBox a "single check" feature (only one item can be checked) and properties for getting the checked item without looping.

```
+----------------------+
| [ ] Item0            |
| [v] Item1   <- With CheckMode = cmSingle, at most one item is ever checked
| [ ] Item2            |
+----------------------+
  CheckedIndex = 1, CheckedText = 'Item1', HasChecked = True
```

- When `CheckMode` is set to `cmSingle`, checking an item automatically unchecks the previously checked one.
- `CheckedIndex`, `CheckedText` and others let you get the checked item immediately.
- When `CheckMode` is `cmMulti` (the default), it behaves the same as TCheckListBox.

| Item | Details |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Class and Unit

| Class | Unit | Package | Base class |
|---|---|---|---|
| `TCCheckListBox` | `CCheckListBox` | cx | `TCheckListBox` |

| Type | Unit | Contents |
|---|---|---|
| `TCCheckMode` | `CCheckListBox` | Check mode. `cmMulti` (multiple items can be checked), `cmSingle` (at most one item is checked) |

- When placed on a form, `CCheckListBox` is added to uses automatically, and cx is automatically added to the project's required packages.
- When creating it in code, write it in uses yourself.

## 2. From Placing on a Form to Running

1. Place TCCheckListBox on the form from the [CX] palette.
2. Enter the items in `Items` in the Object Inspector.
3. To allow only one checked item, set `CheckMode` to `cmSingle`.
4. To prevent the checked item from being unchecked (same as radio buttons), set `AllowNoCheck` to `False`.
5. To run processing when the check changes, double-click `OnCheckedIndexChange` on the Events tab and write the processing.
6. Run.

### 2.1 Rules of Single Check

| Setting | Behavior |
|---|---|
| `CheckMode = cmSingle`, `AllowNoCheck = True` | 0 or 1 item is checked. Clicking the checked item unchecks it |
| `CheckMode = cmSingle`, `AllowNoCheck = False` | 0 or 1 item is checked. Once an item has been checked, clicking it does not uncheck it (same as radio buttons) |
| `CheckMode = cmMulti` | Multiple items can be checked (same as TCheckListBox) |

- Even with `AllowNoCheck = False`, it is possible for 0 items to be checked at startup. Let the application decide the first one, or have the user choose it.
- `AllowNoCheck` blocks only user operations. Code can still uncheck.

## 3. Properties

### 3.1 Added or Behavior-Changed in This Component

| Name | Type | Access | Default | Contents |
|---|---|---|---|---|
| `CheckMode` | `TCCheckMode` | Read/Write | `cmMulti` | `cmMulti`: multiple items can be checked. `cmSingle`: at most one item is checked. When changed from `cmMulti` to `cmSingle`, if two or more items are checked, only the item with the smallest index remains. When changed from `cmSingle` to `cmMulti`, the checks do not change |
| `AllowNoCheck` | `Boolean` | Read/Write | `True` | In `cmSingle`, whether the user can uncheck the checked item. Code can uncheck it even when `False` |
| `CheckedIndex` | `Integer` | Read/Write | -1 | Index of the checked item (-1 if none). In `cmMulti`, the checked item with the smallest index. Writing it checks only that item and unchecks all others (same in `cmMulti`). -1 unchecks everything. Out-of-range values are ignored. Runtime only |
| `CheckedCount` | `Integer` | Read | - | Number of checks. 0 or 1 in `cmSingle`. Runtime only |
| `HasChecked` | `Boolean` | Read | - | `True` if one or more items are checked. Runtime only |
| `CheckedText` | `string` | Read | - | Text of the checked item ('' if none). Runtime only |
| `CheckedObject` | `TObject` | Read | - | `Items.Objects` of the checked item (nil if none). Runtime only |
| `Checked[AIndex]` | `Boolean` | Read/Write | - | Whether that item is checked. Grayed is also `True`. Setting it to `True` in `cmSingle` unchecks the others. Runtime only |
| `State[AIndex]` | `TCheckBoxState` | Read/Write | - | Check state of that item. Setting `cbChecked` in `cmSingle` unchecks the others. Setting `cbGrayed` in `cmSingle` makes it unchecked. Runtime only |

- Like TCheckListBox, `Checked[]` treats Grayed as "checked". The same applies to `CheckedIndex` and `CheckedCount` in `cmMulti`.
- Even if multiple checks are saved in the .lfm, in `cmSingle` only the item with the smallest index remains after loading.

### 3.2 Inherited from TCheckListBox

| Name | Type | Access | Contents |
|---|---|---|---|
| `Align` | `TAlign` | Read/Write | Placement within the parent |
| `AllowGrayed` | `Boolean` | Read/Write | Whether to use Grayed (the third state). It does not become Grayed in `cmSingle` |
| `Anchors` | `TAnchors` | Read/Write | Which edges follow when the parent's size changes |
| `AnchorSideBottom` | `TAnchorSide` | Read/Write | Which part of which component the bottom edge is aligned to |
| `AnchorSideLeft` | `TAnchorSide` | Read/Write | Which part of which component the left edge is aligned to |
| `AnchorSideRight` | `TAnchorSide` | Read/Write | Which part of which component the right edge is aligned to |
| `AnchorSideTop` | `TAnchorSide` | Read/Write | Which part of which component the top edge is aligned to |
| `BiDiMode` | `TBiDiMode` | Read/Write | Whether to lay out right to left |
| `BorderSpacing` | `TControlBorderSpacing` | Read/Write | Surrounding margins |
| `BorderStyle` | `TBorderStyle` | Read/Write | Whether to show the border line |
| `Color` | `TColor` | Read/Write | Background color |
| `Columns` | `Integer` | Read/Write | Number of columns (0 means one column) |
| `Constraints` | `TSizeConstraints` | Read/Write | Upper and lower limits of size |
| `Cursor` | `TCursor` | Read/Write | Mouse cursor when over the component |
| `DragCursor` | `TCursor` | Read/Write | Mouse cursor while dragging |
| `DragMode` | `TDragMode` | Read/Write | Whether dragging starts automatically |
| `Enabled` | `Boolean` | Read/Write | Whether it is usable |
| `ExtendedSelect` | `Boolean` | Read/Write | With `MultiSelect`, whether a range can be selected with Shift and Ctrl |
| `Font` | `TFont` | Read/Write | Text |
| `HeaderBackgroundColor` | `TColor` | Read/Write | Background color of heading items |
| `HeaderColor` | `TColor` | Read/Write | Text color of heading items |
| `Height` | `Integer` | Read/Write | Height |
| `HelpContext` | `THelpContext` | Read/Write | Help number |
| `HelpKeyword` | `string` | Read/Write | Help keyword |
| `HelpType` | `THelpType` | Read/Write | Whether help is looked up by number (`htContext`) or keyword (`htKeyword`) |
| `Hint` | `TTranslateString` | Read/Write | Hint text |
| `ItemHeight` | `Integer` | Read/Write | Item height |
| `ItemIndex` | `Integer` | Read/Write | Index of the selected item. Separate from the check (changing `CheckedIndex` does not change `ItemIndex`) |
| `Items` | `TStrings` | Read/Write | List of items |
| `Left` | `Integer` | Read/Write | Left edge position |
| `MultiSelect` | `Boolean` | Read/Write | Whether multiple items can be selected (separate from the check) |
| `Name` | `TComponentName` | Read/Write | Component name |
| `Options` | `TListBoxOptions` | Read/Write | Whether to draw the focus rectangle when drawing yourself (`lboDrawFocusRect`) |
| `ParentBiDiMode` | `Boolean` | Read/Write | Whether to use the parent's `BiDiMode` |
| `ParentColor` | `Boolean` | Read/Write | Whether to use the parent's color |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the parent's `Font` |
| `ParentShowHint` | `Boolean` | Read/Write | Whether to use the parent's `ShowHint` |
| `PopupMenu` | `TPopupMenu` | Read/Write | Menu shown on right-click |
| `ShowHint` | `Boolean` | Read/Write | Whether to show the hint |
| `Sorted` | `Boolean` | Read/Write | Whether to sort the items |
| `Style` | `TListBoxStyle` | Read/Write | Drawing style. `lbStandard` (default), `lbOwnerDrawFixed`, `lbOwnerDrawVariable`, `lbVirtual` |
| `TabOrder` | `TTabOrder` | Read/Write | Order of focus movement with the Tab key |
| `TabStop` | `Boolean` | Read/Write | Whether the Tab key stops here |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely |
| `Top` | `Integer` | Read/Write | Top edge position |
| `TopIndex` | `Integer` | Read/Write | Index of the item visible at the top |
| `Visible` | `Boolean` | Read/Write | Whether to display it |
| `Width` | `Integer` | Read/Write | Width |

## 4. Methods

| Name | Parameters | Return value | Contents |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | - | Creates it. Used when creating in code (7.6) |
| `CheckAll` | `AState: TCheckBoxState; aAllowGrayed: Boolean = True; aAllowDisabled: Boolean = True` | - | Sets all items to `AState`. In `cmSingle`, for `cbChecked` only the first eligible item is checked and the others are unchecked; for `cbUnchecked` and `cbGrayed` the eligible items are unchecked. The eligibility condition is the same as TCheckListBox. In `cmMulti`, the same as TCheckListBox |
| `Toggle` | `AIndex: Integer` | - | Toggles the check of that item. In `cmSingle`, toggles between unchecked and checked, and unchecks the others when checking. In `cmMulti`, the same as TCheckListBox |

- All other methods of TCheckListBox can be used.

## 5. Events

### 5.1 Added in This Component

| Name | Parameters | Contents |
|---|---|---|
| `OnCheckedIndexChange` | `Sender: TObject` | The value of `CheckedIndex` changed. Read the new value from `CheckedIndex` |

### 5.2 Inherited from TCheckListBox

| Name | Parameters | Contents |
|---|---|---|
| `OnChangeBounds` | `Sender: TObject` | Position or size changed |
| `OnClick` | `Sender: TObject` | Clicked |
| `OnClickCheck` | `Sender: TObject` | The user clicked the check box or pressed the Space key. Not raised for items unchecked automatically in `cmSingle` |
| `OnContextPopup` | `Sender: TObject; MousePos: TPoint; var Handled: Boolean` | Just before the right-click menu is shown. `Handled := True` suppresses it |
| `OnDblClick` | `Sender: TObject` | Double-clicked |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | Dropped |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | A dragged object came over it. `Accept` decides whether to accept |
| `OnDrawItem` | `Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState` | When drawing an item (when `Style` is set to self-drawing) |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | Dragging ended |
| `OnEnter` | `Sender: TObject` | Focus entered |
| `OnExit` | `Sender: TObject` | Focus left |
| `OnItemClick` | `Sender: TObject; Index: Integer` | An item's check box was clicked (deprecated in TCheckListBox). Also raised when the item was not unchecked because of `AllowNoCheck = False`. Use `OnClickCheck` |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A key was pressed |
| `OnKeyPress` | `Sender: TObject; var Key: Char` | A character key was pressed |
| `OnKeyUp` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A key was released |
| `OnMeasureItem` | `Control: TWinControl; Index: Integer; var AHeight: Integer` | When determining an item's height (when `Style = lbOwnerDrawVariable`) |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was pressed |
| `OnMouseEnter` | `Sender: TObject` | The mouse entered |
| `OnMouseLeave` | `Sender: TObject` | The mouse left |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | The mouse moved |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was released |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | The wheel was turned |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned toward you |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned away from you |
| `OnMouseWheelHorz` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | The horizontal wheel was turned |
| `OnMouseWheelLeft` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The horizontal wheel was turned left |
| `OnMouseWheelRight` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The horizontal wheel was turned right |
| `OnResize` | `Sender: TObject` | Size changed |
| `OnSelectionChange` | `Sender: TObject; User: Boolean` | The selection (`ItemIndex`) changed. `User` indicates whether it was a user operation |
| `OnShowHint` | `Sender: TObject; HintInfo: PHintInfo` | Just before the hint is shown |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | Dragging started |
| `OnUTF8KeyPress` | `Sender: TObject; var UTF8Key: TUTF8Char` | A character key was pressed (one UTF-8 character) |

### 5.3 Order of Calls

| Operation (`cmSingle`) | Order |
|---|---|
| The user checks an unchecked item | `OnClickCheck` -> `OnCheckedIndexChange` |
| The user unchecks the checked item (`AllowNoCheck = True`) | `OnClickCheck` -> `OnCheckedIndexChange` |
| Changing `Checked[]`, `State[]`, `CheckedIndex`, `CheckAll` or `Toggle` in code | `OnCheckedIndexChange` only |

- Reading `CheckedIndex` inside `OnCheckedIndexChange` returns the value after the change.

### 5.4 When `OnCheckedIndexChange` Is Not Raised

| Case | Details |
|---|---|
| The value does not change | The same index was set, the checked item was checked again, etc. |
| Clicking an item that cannot be unchecked | In `cmSingle` with `AllowNoCheck = False`, the checked item was clicked (`OnClickCheck` is not raised either) |
| Changes after the smallest index | In `cmMulti`, only items after the checked item with the smallest index changed |
| Adding or removing items | Adding, inserting, deleting, `Clear`, sorting items (reading `CheckedIndex` etc. afterwards returns the correct value) |
| Startup | When the .lfm is loaded |
| Switching the mode | When `CheckMode` is changed (the item with the smallest index remains, so `CheckedIndex` does not change) |

## 6. Operations

| Operation (`cmSingle`) | Behavior |
|---|---|
| Click the check box of an unchecked item | Checks that item and unchecks the previous check |
| Click the check box of the checked item | Unchecks it if `AllowNoCheck = True`. Nothing changes if `False` |
| Select an item and press the Space key | Same behavior as clicking the check box |
| Click the text part of an item | Only the selection (`ItemIndex`) moves; the check does not change |

- Even with `AllowGrayed = True`, in `cmSingle` it does not become Grayed; it toggles between unchecked and checked.
- The selection (`ItemIndex`) and the check are separate. Changing `CheckedIndex` does not change `ItemIndex`, and changing `ItemIndex` does not change the check.

### 6.1 Notes

- Use `Checked[]`, `State[]`, `CheckAll` and `Toggle` through a variable of type `TCCheckListBox`. If used through a variable of type `TCheckListBox` or `TCustomCheckListBox`, TCheckListBox's behavior applies, and even in `cmSingle` two or more items may become checked. Even then, `CheckedIndex` and the others return the checked item with the smallest index.

## 7. Usage Examples

### 7.1 Check the Checked Item

```pascal
procedure TForm1.Button1Click(Sender: TObject);
begin
  if CCheckListBox1.HasChecked then
    ShowMessage(CCheckListBox1.CheckedText)
  else
    ShowMessage('Nothing selected');
end;
```

### 7.2 Update the Display When the Check Changes

```pascal
procedure TForm1.CCheckListBox1CheckedIndexChange(Sender: TObject);
begin
  if CCheckListBox1.HasChecked then
    Label1.Caption := CCheckListBox1.CheckedText
  else
    Label1.Caption := '(none)';
end;
```

### 7.3 Check and Uncheck in Code

```pascal
CCheckListBox1.CheckedIndex := 2;    // Check only item 2
CCheckListBox1.CheckedIndex := -1;   // Uncheck everything
```

### 7.4 Attach Data to Items and Get the Checked Item's Data

```pascal
type
  TColorItem = class
    Value: TColor;
    constructor Create(AValue: TColor);
  end;

constructor TColorItem.Create(AValue: TColor);
begin
  Value := AValue;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  CCheckListBox1.CheckMode := cmSingle;
  CCheckListBox1.AllowNoCheck := False;
  CCheckListBox1.Items.AddObject('Red', TColorItem.Create(clRed));
  CCheckListBox1.Items.AddObject('Green', TColorItem.Create(clGreen));
  CCheckListBox1.Items.AddObject('Blue', TColorItem.Create(clBlue));
  CCheckListBox1.CheckedIndex := 0;   // The application decides the first one
end;

procedure TForm1.CCheckListBox1CheckedIndexChange(Sender: TObject);
var
  Obj: TObject;
begin
  Obj := CCheckListBox1.CheckedObject;   // nil if nothing is checked
  if Obj <> nil then
    Shape1.Brush.Color := TColorItem(Obj).Value;
end;

procedure TForm1.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  // Objects put in Items.Objects must be freed by the application
  for i := 0 to CCheckListBox1.Items.Count - 1 do
    CCheckListBox1.Items.Objects[i].Free;
end;
```

### 7.5 Get All Checked Items in Multi-Check Mode

```pascal
procedure TForm1.Button2Click(Sender: TObject);
var
  i: Integer;
begin
  Memo1.Clear;
  Memo1.Lines.Add('Number of checks: ' + IntToStr(CCheckListBox1.CheckedCount));
  for i := 0 to CCheckListBox1.Items.Count - 1 do
    if CCheckListBox1.Checked[i] then
      Memo1.Lines.Add(CCheckListBox1.Items[i]);
end;
```

### 7.6 Create in Code

```pascal
uses
  CCheckListBox;

procedure TForm1.Button3Click(Sender: TObject);
var
  L: TCCheckListBox;
begin
  L := TCCheckListBox.Create(Self);
  L.Parent := Self;
  L.SetBounds(16, 16, 200, 120);
  L.CheckMode := cmSingle;
  L.Items.Add('Small');
  L.Items.Add('Medium');
  L.Items.Add('Large');
  L.CheckedIndex := 1;
  L.OnCheckedIndexChange := @CCheckListBox1CheckedIndexChange;
end;
```
