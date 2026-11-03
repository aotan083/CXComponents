# TCGroupBox User Manual

Author: aotan083
Date: 2026-10-29
Version: 1.0

---

## 1. Overview and Classes

A group box with the same appearance and usage as TGroupBox. With the standard TGroupBox, controls placed inside it can disappear; this does not happen with this component.

| Component | Role |
|---|---|
| TCGroupBox | A frame with a caption. Can be used with the same property and event names as TGroupBox |
| TCCheckGroupBox | A TCGroupBox with a check box in the caption. Unchecking it disables all the controls inside, and checking it restores them |

- It is drawn with the Windows theme and looks the same as TGroupBox. It also changes to match the MetaDarkStyle dark display.
- On Windows where themes are unavailable, the frame is drawn as a 1px gray line.

| Item | Details |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Classes and Units

| Class | Unit | Package | Base class |
|---|---|---|---|
| `TCGroupBox` | `uCGroupBox` | cx | `TCustomPanel` |
| `TCCheckGroupBox` | `uCCheckGroupBox` | cx | `TCGroupBox` |

- When placed on a form, `uCGroupBox` (`uCCheckGroupBox` for TCCheckGroupBox) is added to uses automatically, and cx is automatically added to the project's required packages.
- When creating it in code, write it in uses yourself.

### 1.2 Differences from TGroupBox

| Item | TGroupBox | TCGroupBox |
|---|---|---|
| Drawing | Drawn by a native Windows control | The component draws itself (using Windows theme elements) |
| Bug where inner controls disappear | Can occur | Does not occur |
| Appearance | Windows theme | Same |
| Dark display (MetaDarkStyle) | Follows | Follows |
| Caption with a check box | None | Available with TCCheckGroupBox |

## 2. From Placing on a Form to Running

### 2.1 TCGroupBox

1. Place TCGroupBox on the form from the [CX] palette.
2. Enter the caption text in `Caption` in the Object Inspector.
3. Place controls such as TEdit and TButton on the TCGroupBox.
4. Run.

### 2.2 TCCheckGroupBox

1. Place TCCheckGroupBox on the form from the [CX] palette.
2. Enter the caption text in `Caption` in the Object Inspector.
3. Place controls on the TCCheckGroupBox.
4. To start with it unchecked, set `Checked` to `False`.
5. To run processing when the check is toggled, double-click `OnChange` on the Events tab and write the processing.
6. Run. Unchecking disables the controls inside (grayed out), and checking restores them. The application does not need to write any code.

### 2.3 Behavior at Design Time (Lazarus IDE)

- At design time, setting `Checked` to `False` does not disable the controls inside (only the display of the check box changes). They are disabled when you run.
- The caption's check box cannot be selected or operated at design time. Clicking it selects the TCCheckGroupBox.
- The caption's check box is not saved in the .lfm.

## 3. TCGroupBox

### 3.1 Properties

| Name | Type | Access | Contents |
|---|---|---|---|
| `Align` | `TAlign` | Read/Write | Placement within the parent |
| `Anchors` | `TAnchors` | Read/Write | Which edges follow when the parent's size changes |
| `AnchorSideBottom` | `TAnchorSide` | Read/Write | Which part of which component the bottom edge is aligned to |
| `AnchorSideLeft` | `TAnchorSide` | Read/Write | Which part of which component the left edge is aligned to |
| `AnchorSideRight` | `TAnchorSide` | Read/Write | Which part of which component the right edge is aligned to |
| `AnchorSideTop` | `TAnchorSide` | Read/Write | Which part of which component the top edge is aligned to |
| `AutoSize` | `Boolean` | Read/Write | Whether to resize to fit the inner controls |
| `BiDiMode` | `TBiDiMode` | Read/Write | `bdRightToLeft` right-aligns the caption |
| `BorderSpacing` | `TControlBorderSpacing` | Read/Write | Surrounding margins |
| `Caption` | `TCaption` | Read/Write | Caption text. The component's name is entered when it is placed. When empty, the top edge of the frame is continuous without a gap. Emptying it does not move the inner controls |
| `ChildSizing` | `TControlChildSizing` | Read/Write | How inner controls are arranged (same as TGroupBox) |
| `ClientHeight` | `Integer` | Read/Write | Inner height |
| `ClientWidth` | `Integer` | Read/Write | Inner width |
| `Color` | `TColor` | Read/Write | Background color |
| `Constraints` | `TSizeConstraints` | Read/Write | Upper and lower limits of size |
| `Cursor` | `TCursor` | Read/Write | Mouse cursor when over the component |
| `DockSite` | `Boolean` | Read/Write | Whether other controls can be docked |
| `DoubleBuffered` | `Boolean` | Read/Write | Whether to draw in a way that reduces flicker |
| `DragCursor` | `TCursor` | Read/Write | Mouse cursor while dragging |
| `DragKind` | `TDragKind` | Read/Write | Kind of drag (drag and drop, or docking) |
| `DragMode` | `TDragMode` | Read/Write | Whether dragging starts automatically |
| `Enabled` | `Boolean` | Read/Write | Whether it is usable. `False` grays out the caption |
| `Font` | `TFont` | Read/Write | Caption text. If `Font.Color` is `clDefault`, it is drawn in the theme color (the dark color in dark display) |
| `Height` | `Integer` | Read/Write | Height |
| `HelpContext` | `THelpContext` | Read/Write | Help number |
| `HelpKeyword` | `string` | Read/Write | Help keyword |
| `HelpType` | `THelpType` | Read/Write | Whether help is looked up by number (`htContext`) or keyword (`htKeyword`) |
| `Hint` | `TTranslateString` | Read/Write | Hint text |
| `Left` | `Integer` | Read/Write | Left edge position |
| `Name` | `TComponentName` | Read/Write | Component name |
| `ParentBackground` | `Boolean` | Read/Write | Whether to use the parent's background |
| `ParentBiDiMode` | `Boolean` | Read/Write | Whether to use the parent's `BiDiMode` |
| `ParentColor` | `Boolean` | Read/Write | Whether to use the parent's color (default is `True`) |
| `ParentDoubleBuffered` | `Boolean` | Read/Write | Whether to use the parent's `DoubleBuffered` |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the parent's `Font` |
| `ParentShowHint` | `Boolean` | Read/Write | Whether to use the parent's `ShowHint` |
| `PopupMenu` | `TPopupMenu` | Read/Write | Menu shown on right-click |
| `ShowHint` | `Boolean` | Read/Write | Whether to show the hint |
| `TabOrder` | `TTabOrder` | Read/Write | Order of focus movement with the Tab key |
| `TabStop` | `Boolean` | Read/Write | Whether the Tab key stops here |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely |
| `Top` | `Integer` | Read/Write | Top edge position |
| `Visible` | `Boolean` | Read/Write | Whether to display it |
| `Width` | `Integer` | Read/Write | Width |

- The area where inner controls can be placed is below the caption and inside the frame. A control with `Align = alClient` fills the inside of the frame from below the caption.
- The size when placed is 185 wide x 105 high (same as TGroupBox).

### 3.2 Methods

| Name | Parameters | Return value | Contents |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | - | Creates it. Used when creating in code (6.4) |

### 3.3 Events

| Name | Parameters | Contents |
|---|---|---|
| `OnChangeBounds` | `Sender: TObject` | Position or size changed |
| `OnClick` | `Sender: TObject` | Clicked |
| `OnContextPopup` | `Sender: TObject; MousePos: TPoint; var Handled: Boolean` | Just before the right-click menu is shown. `Handled := True` suppresses it |
| `OnDblClick` | `Sender: TObject` | Double-clicked |
| `OnDockDrop` | `Sender: TObject; Source: TDragDockObject; X, Y: Integer` | Docked |
| `OnDockOver` | `Sender: TObject; Source: TDragDockObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | A control to be docked came over it. `Accept` decides whether to accept |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | Dropped |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | A dragged object came over it. `Accept` decides whether to accept |
| `OnEndDock` | `Sender, Target: TObject; X, Y: Integer` | Docking ended |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | Dragging ended |
| `OnEnter` | `Sender: TObject` | Focus entered |
| `OnExit` | `Sender: TObject` | Focus left |
| `OnGetSiteInfo` | `Sender: TObject; DockClient: TControl; var InfluenceRect: TRect; MousePos: TPoint; var CanDock: Boolean` | When determining the area where docking is possible |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A key was pressed |
| `OnKeyPress` | `Sender: TObject; var Key: Char` | A character key was pressed |
| `OnKeyUp` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A key was released |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was pressed |
| `OnMouseEnter` | `Sender: TObject` | The mouse entered |
| `OnMouseLeave` | `Sender: TObject` | The mouse left |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | The mouse moved |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was released |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | The wheel was turned |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned toward you |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned away from you |
| `OnResize` | `Sender: TObject` | Size changed |
| `OnStartDock` | `Sender: TObject; var DragObject: TDragDockObject` | A docking drag started |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | Dragging started |
| `OnUnDock` | `Sender: TObject; Client: TControl; NewTarget: TWinControl; var Allow: Boolean` | Before a docked control is detached. `Allow` decides whether to allow detaching |
| `OnUTF8KeyPress` | `Sender: TObject; var UTF8Key: TUTF8Char` | A character key was pressed (one UTF-8 character) |

## 4. TCCheckGroupBox

It has all the properties, methods and events of TCGroupBox (chapter 3), plus the following.

### 4.1 Properties

| Name | Type | Access | Default | Contents |
|---|---|---|---|---|
| `Checked` | `Boolean` | Read/Write | `True` | The caption's check. `False` disables all the inner controls, and `True` restores them |

### 4.2 Methods

| Name | Parameters | Return value | Contents |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | - | Creates it. Also creates the caption's check box |

### 4.3 Events

| Name | Parameters | Contents |
|---|---|---|
| `OnChange` | `Sender: TObject` | After `Checked` has changed. Raised whether it is changed by the check box, the caption text, the Space key or code. Not raised when the same value is set or when the form is loaded |

### 4.4 Enabling and Disabling Inner Controls

| State | Inner controls | Check box |
|---|---|---|
| `Enabled = True`, `Checked = True` | Each has its original `Enabled` | Enabled |
| `Enabled = True`, `Checked = False` | All disabled | Enabled |
| `Enabled = False` | All disabled | Disabled |

- "Original `Enabled`" is the value just before the control was disabled. A control that was originally disabled remains disabled even after restoring.
- Even if the application changes the `Enabled` of an inner control while the check is off, it returns to the value from before the check was removed when the check is turned on.
- Controls inside controls that can hold other controls, such as an inner panel, are likewise disabled and restored.
- Controls added deeper inside, such as inside an inner panel, while the check is off are not disabled (controls added directly to the TCCheckGroupBox are disabled).
- For a control that cannot hold other controls (a composite control), only that control's `Enabled` changes.
- When a TCCheckGroupBox is placed inside a TCCheckGroupBox, the inner controls also follow the check of the inner TCCheckGroupBox. Even if the outer check is turned on again, if the inner check is off, the inner controls remain disabled.

## 5. Operations (by the User of the Application)

**TCCheckGroupBox**

| Operation | Behavior |
|---|---|
| Click the check box | The check toggles |
| Click the caption text | The check toggles, and focus moves to the check box |
| Tab key | Focus moves to the check box. A dotted frame appears around the caption text |
| Space key (when focused) | The check toggles |

- Even when unchecked, the check box itself can be clicked (clicking it restores the check).
- When the TCCheckGroupBox's `Enabled` is `False`, neither the check box nor the caption text can be clicked.

### 5.1 Commonly Used Settings

| What you want to do | Setting |
|---|---|
| Change the caption text | Set `Caption` |
| Change the caption text color | Change `Font.Color`. With `clDefault` it uses the theme color (the dark color in dark display) |
| Change the background color | Change `Color` |
| Arrange inner controls side by side | Use `ChildSizing` (same as TGroupBox) |
| Start with the check off (TCCheckGroupBox) | Set `Checked` to `False` |
| Be notified when the check toggles (TCCheckGroupBox) | Use `OnChange` |
| Right-align the caption | Set `BiDiMode` to `bdRightToLeft` |

## 6. Usage Examples

### 6.1 Run Processing When the Check Is Toggled

```pascal
procedure TForm1.CCheckGroupBox1Change(Sender: TObject);
begin
  if CCheckGroupBox1.Checked then
    StatusBar1.SimpleText := 'Use proxy'
  else
    StatusBar1.SimpleText := 'Do not use proxy';
end;
```

### 6.2 Toggle the Check in Code

```pascal
CCheckGroupBox1.Checked := False;   // Inner controls are disabled. OnChange is raised
CCheckGroupBox1.Checked := True;    // Inner controls return to their original state. OnChange is raised
```

### 6.3 Save the Check to a Settings File and Restore It on the Next Startup

```pascal
uses
  IniFiles;

procedure TForm1.FormCreate(Sender: TObject);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini'));
  try
    CCheckGroupBox1.Checked := Ini.ReadBool('Proxy', 'Use', False);
  finally
    Ini.Free;
  end;
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini'));
  try
    Ini.WriteBool('Proxy', 'Use', CCheckGroupBox1.Checked);
  finally
    Ini.Free;
  end;
end;
```

### 6.4 Create in Code

```pascal
uses
  uCGroupBox, uCCheckGroupBox;

procedure TForm1.Button1Click(Sender: TObject);
var
  G: TCCheckGroupBox;
  E: TEdit;
begin
  G := TCCheckGroupBox.Create(Self);
  G.Parent := Self;
  G.SetBounds(16, 16, 240, 80);
  G.Caption := 'Proxy';
  G.OnChange := @CCheckGroupBox1Change;   // Use the processing from 6.1

  E := TEdit.Create(Self);
  E.Parent := G;                          // Place it inside the TCCheckGroupBox
  E.SetBounds(8, 8, 200, 23);
end;
```

### 6.5 Keep an Inner Control Always Disabled

```pascal
// Keep Edit2 inside disabled regardless of the check
Edit2.Enabled := False;
// Even if the check is turned off and on again, Edit2 stays disabled
```

### 6.6 Replace an Existing TGroupBox with TCGroupBox

1. Close the form in Lazarus.
2. Rewrite `TGroupBox` to `TCGroupBox` in the .lfm, and `TGroupBox` to `TCGroupBox` in the .pas.
3. Add `uCGroupBox` to uses in the .pas.
4. Reopen the form.

The properties and events have the same names as TGroupBox, so they carry over as they are.
