# TCListView User Manual

Author: aotan083
Date: 2026-10-31
Version: 1.1

---

## 1. Overview and Classes

A list of files and folders that works like the right-hand pane of Windows Explorer. Just placing it on a form gives you open, copy, move, delete, rename, create new folder, drag & drop, and context menu, all working the same way as in Explorer. No code is needed on the application side.

```
Name              Size      Type     Date modified
-------------------------------------------------------
images                      Folder   2026/10/19 21:30
README.md          4 kB     md       2026/10/19 22:05
sample.pas        12 kB     pas      2026/10/18 10:12
```

- There are four view styles: details, large icons, small icons, and list.
- Clicking a column header sorts (folders always come first).
- Back/forward (folder history) is supported. The mouse back/forward buttons also work.
- When files are changed by other applications or Explorer, the display is updated automatically.
- When connected to a TCTreeView (folder tree), it shows the contents of the folder selected in the tree.

| Item | Details |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Contents |
|---|---|---|---|---|
| `TCListView` | `CListView` | cx | `TShellListView` (LCL, `ShellCtrls`) | A list of files and folders that works like the right-hand pane of Windows Explorer. Open, copy, move, delete, rename, create new folder, drag & drop, and context menu all work without writing code |

| Type | Unit | Contents |
|---|---|---|
| `TCExtraMenuPosition` | `CShellMenu` | Position of items added to the context menu. `empTop` (top of the menu), `empBottom` (end of the menu) |

- When placed on a form, `CListView` is added to uses automatically.
- When placed on a form, cx is added automatically to the project's required packages.
- When creating it in code, write it in uses yourself. When assigning a value to `ExtraMenuPosition`, also write `CShellMenu` in uses.

## 2. From Placing on a Form to Running

### 2.1 Using the List Alone

1. Place TCListView on the form from the [CX] palette.
2. In the Object Inspector, enter the folder to show first in `Root` (you can also specify it at run time with `NavigateTo`).
3. To show the folder being displayed on screen, double-click `OnFolderChanged` on the Events tab and write the handler (6.1).
4. Run it. Double-click or Enter enters a folder, and BackSpace returns to the parent.

### 2.2 Connecting to TCTreeView (Folder Tree)

1. Place TCTreeView and TCListView on the form.
2. Select the TCTreeView in the `ShellTreeView` property of TCListView.
3. Run it. When you select a folder in the tree, the list moves to that folder (moving in the list does not change the tree's selection).

## 3. Display

### 3.1 Columns (Details View)

| Column | Header | Contents |
|---|---|---|
| 0 | Name | File name or folder name (including the extension). Automatically fits the remaining width |
| 1 | Size | File size (bytes, kB, MB, GB) |
| 2 | Type | Extension. "Folder" for folders |
| 3 | Date modified | YYYY/MM/DD HH:NN |

### 3.2 View Styles

| `ViewStyle` | Display |
|---|---|
| `vsReport` | Details (default) |
| `vsIcon` | Large icons |
| `vsSmallIcon` | Small icons |
| `vsList` | List |

- The view style is not remembered per folder; there is one for the whole list.

### 3.3 Sorting

- At startup, ascending by type (by name within the same type).
- Names are sorted in natural order, the same as Explorer (numbers are compared by their magnitude).
- Folders always come first, whichever column is used for sorting.

## 4. Properties

### 4.1 Added by This Component

| Name | Type | Access | Contents |
|---|---|---|---|
| `ExtraItemMenu` | `TPopupMenu` | Read/write | Items added to the menu when right-clicking on an item |
| `ExtraBackgroundMenu` | `TPopupMenu` | Read/write | Items added to the menu when right-clicking on an empty area |
| `ExtraMenuPosition` | `TCExtraMenuPosition` | Read/write | Position of the added items. `empTop`: top of the menu. `empBottom` (default): end of the menu |
| `AutoFitNameColumn` | `Boolean` | Read/write | Whether the name column automatically fits the remaining width (default `True`). Changing a column width by hand makes it `False`. Writing `True` returns it to automatic. Run time only |
| `MaxHistory` | `Integer` | Read/write | Upper limit of the back/forward history (default 20; minimum 2). When exceeded, the oldest entries are deleted. Run time only |
| `SortColumn` | `Integer` | Read | The column being sorted (default 2). 0: Name, 1: Size, 2: Type, 3: Date modified. Run time only |
| `SortAscending` | `Boolean` | Read | `True` if ascending. Run time only |

### 4.2 Inherited from TShellListView

| Name | Type | Access | Contents |
|---|---|---|---|
| `Align` | `TAlign` | Read/write | Placement within the parent |
| `Anchors` | `TAnchors` | Read/write | Which edges follow when the parent's size changes |
| `AnchorSideBottom` | `TAnchorSide` | Read/write | Which control and which part the bottom edge is aligned to |
| `AnchorSideLeft` | `TAnchorSide` | Read/write | Which control and which part the left edge is aligned to |
| `AnchorSideRight` | `TAnchorSide` | Read/write | Which control and which part the right edge is aligned to |
| `AnchorSideTop` | `TAnchorSide` | Read/write | Which control and which part the top edge is aligned to |
| `BorderSpacing` | `TControlBorderSpacing` | Read/write | Surrounding margins |
| `BorderStyle` | `TBorderStyle` | Read/write | Whether to show the border line |
| `BorderWidth` | `TBorderWidth` | Read/write | Margin inside the border |
| `Color` | `TColor` | Read/write | Background color (default `clWindow`) |
| `Constraints` | `TSizeConstraints` | Read/write | Upper and lower limits of the size |
| `Cursor` | `TCursor` | Read/write | Mouse cursor when over the control |
| `DragCursor` | `TCursor` | Read/write | Mouse cursor during a drag |
| `Enabled` | `Boolean` | Read/write | Whether it can be used |
| `Font` | `TFont` | Read/write | Text |
| `Height` | `Integer` | Read/write | Height |
| `HelpContext` | `THelpContext` | Read/write | Help number |
| `HelpKeyword` | `string` | Read/write | Help keyword |
| `HelpType` | `THelpType` | Read/write | Whether help is looked up by number (`htContext`) or by keyword (`htKeyword`) |
| `HideSelection` | `Boolean` | Read/write | Whether to hide the selection color when there is no focus |
| `Hint` | `TTranslateString` | Read/write | Hint text |
| `LargeImages` | `TCustomImageList` | Read/write | Images for large icons |
| `LargeImagesWidth` | `Integer` | Read/write | Width of large icons |
| `Left` | `Integer` | Read/write | Position of the left edge |
| `Mask` | `string` | Read/write | Filter for the files to show (example: `*.md`) |
| `MaskCaseSensitivity` | `TMaskCaseSensitivity` | Read/write | Whether `Mask` is case-sensitive |
| `MultiSelect` | `Boolean` | Read/write | Whether multiple items can be selected (default `True`) |
| `Name` | `TComponentName` | Read/write | Name of the component |
| `ObjectTypes` | `TObjectTypes` | Read/write | Kinds of things to show (default `[otFolders, otNonFolders]`). To show hidden files too, add `otHidden` |
| `ParentColor` | `Boolean` | Read/write | Whether to use the parent's color (default `False`) |
| `ParentFont` | `Boolean` | Read/write | Whether to use the parent's `Font` |
| `ParentShowHint` | `Boolean` | Read/write | Whether to use the parent's `ShowHint` |
| `Root` | `string` | Read/write | Full path of the folder being displayed. Writing it shows that folder. It may or may not have a trailing `\`, so when comparing, normalize with `ExcludeTrailingPathDelimiter`. To move from code, use `NavigateTo` |
| `RowSelect` | `Boolean` | Read/write | Whether the selection color covers the whole row |
| `ScrollBars` | `TScrollStyle` | Read/write | How scrollbars are shown |
| `ShellTreeView` | `TCustomShellTreeView` | Read/write | The tree to connect. When a TCTreeView is selected, the folder selected in the tree is shown |
| `ShowColumnHeaders` | `Boolean` | Read/write | Whether to show the column headers |
| `ShowHint` | `Boolean` | Read/write | Whether to show hints |
| `SmallImages` | `TCustomImageList` | Read/write | Images for small icons |
| `SmallImagesWidth` | `Integer` | Read/write | Width of small icons |
| `StateImages` | `TCustomImageList` | Read/write | Icons for item states |
| `TabOrder` | `TTabOrder` | Read/write | Order of movement with the Tab key |
| `TabStop` | `Boolean` | Read/write | Whether the Tab key stops here |
| `Tag` | `PtrInt` | Read/write | A number the application can use freely |
| `ToolTips` | `Boolean` | Read/write | Whether to show the names of items that do not fit when the mouse is over them |
| `Top` | `Integer` | Read/write | Position of the top edge |
| `ViewStyle` | `TViewStyle` | Read/write | View style (3.2). Writing it is the same as `SetView` |
| `Visible` | `Boolean` | Read/write | Whether to show it |
| `Width` | `Integer` | Read/write | Width |

## 5. Methods

### 5.1 Moving Between Folders

| Name | Parameters | Return value | Contents |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | - | Creates it. Used when creating in code (10.11) |
| `NavigateTo` | `const APath: string` | `Boolean` | Shows that folder. `False` if it does not exist or is the same as the one being displayed |
| `NavigateUp` | - | `Boolean` | Shows the parent folder. Does nothing (`False`) at a drive root (such as `C:\`) |
| `GoBack` | - | `Boolean` | Goes back to the previous folder in the history. `True` if it moved. Folders that no longer exist are skipped |
| `GoForward` | - | `Boolean` | Goes forward to the next folder in the history. `True` if it moved. Folders that no longer exist are skipped |
| `CanGoBack` | - | `Boolean` | `True` if it can go back |
| `CanGoForward` | - | `Boolean` | `True` if it can go forward |
| `ClearHistory` | - | - | Clears the history (leaves only the folder being displayed) |

- If you move to a different folder after going back, the forward history is cleared (the same as Explorer).

### 5.2 File Operations

| Name | Parameters | Return value | Contents |
|---|---|---|---|
| `CopySelected` | - | - | Copies the selected items to the clipboard (same as Ctrl+C. Can be pasted into Explorer) |
| `CutSelected` | - | - | Cuts the selected items (same as Ctrl+X. Pasting makes it a move) |
| `PasteToRoot` | - | - | Pastes into the folder being displayed (same as Ctrl+V). Pasting into the same folder produces "... - Copy". The pasted items are selected |
| `DeleteSelectedFiles` | `APermanent: Boolean = False` | - | Deletes the selected items. `False`: to the Recycle Bin. `True`: delete permanently. Both show a confirmation |
| `RenameSelectedFile` | - | - | Starts renaming the selected item (same as F2). If it could not be renamed, Windows shows the reason and the name is restored |

### 5.3 View Style and Sorting

| Name | Parameters | Return value | Contents |
|---|---|---|---|
| `SetView` | `AStyle: TViewStyle` | - | Changes the view style (3.2) |
| `SortBy` | `AColumn: Integer; AAscending: Boolean` | - | Sorts. `AColumn`: 0: Name, 1: Size, 2: Type, 3: Date modified. Folders are always first |

### 5.4 Selection

| Name | Parameters | Return value | Contents |
|---|---|---|---|
| `SelectAllItems` | - | - | Selects everything (same as Ctrl+A) |
| `GetSelectedFilePath` | - | `string` | Full path of the first selected item. '' if nothing is selected |
| `GetSelectedPaths` | `AList: TStrings` | - | Puts the full paths of all selected items into `AList` (`AList` is emptied first) |
| `SelectNewItemsOnNextRefresh` | - | - | Selects newly appeared items the next time the display is refreshed. Used when the application has created a file, for example (10.9) |

### 5.5 Unit Functions

| Name | Parameters | Return value | Contents |
|---|---|---|---|
| `BuildRenamedPath` | `const AOldPath, ADisplayName, ANewName: string` | `string` | Builds the full path after a rename. Also supplies the original extension when the setting is not to show extensions |

## 6. Events

### 6.1 Added by This Component

| Name | Parameters | Contents |
|---|---|---|
| `OnFolderChanged` | `Sender: TObject` | The folder being displayed (`Root`) changed |
| `OnSelectionChanged` | `Sender: TObject` | The selected items changed |

- Both fire once per change, regardless of the reason for the change (mouse, key, tree, code). They fire when the application is idle (at idle time).
- `OnFolderChanged` fires on double-click, Enter, BackSpace, selection in the tree, `NavigateTo`, `NavigateUp`, `GoBack`, `GoForward` (including the mouse back/forward buttons), and when the folder being displayed disappears and the view moves to the parent. It does not fire on F5 or automatic refresh.
- `OnSelectionChanged` consolidates multi-selection changes by Shift, Ctrl, and Ctrl+A into one. It also fires right after moving to another folder (the selection is gone). It does not fire if the selection does not change on an automatic refresh.

### 6.2 Inherited from TShellListView

| Name | Parameters | Contents |
|---|---|---|
| `OnChange` | `Sender: TObject; Item: TListItem; Change: TItemChange` | An item changed |
| `OnClick` | `Sender: TObject` | Clicked |
| `OnContextPopup` | `Sender: TObject; MousePos: TPoint; var Handled: Boolean` | Just before the context menu is shown. `Handled := True` suppresses it |
| `OnDblClick` | `Sender: TObject` | Double-clicked. If this is set, the component's own double-click behavior (moving to a folder, opening a file) is not performed |
| `OnDeletion` | `Sender: TObject; Item: TListItem` | An item is removed from the list |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | Dropped in an LCL drag (between components inside the application) |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | In an LCL drag, the dragged object came over the control. `Accept` decides whether to accept it |
| `OnEditing` | `Sender: TObject; Item: TListItem; var AllowEdit: Boolean` | Before renaming starts. `AllowEdit := False` cancels it |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | An LCL drag ended |
| `OnFileAdded` | `Sender: TObject; Item: TListItem` | After a file has been added as an item |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A key was pressed |
| `OnKeyPress` | `Sender: TObject; var Key: Char` | A character key was pressed |
| `OnKeyUp` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A key was released |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was pressed |
| `OnMouseEnter` | `Sender: TObject` | The mouse entered the control |
| `OnMouseLeave` | `Sender: TObject` | The mouse left the control |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | The mouse moved |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was released |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | The wheel was turned |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned toward you |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned away from you |
| `OnMouseWheelHorz` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | The horizontal wheel was turned |
| `OnMouseWheelLeft` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The horizontal wheel was turned left |
| `OnMouseWheelRight` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The horizontal wheel was turned right |
| `OnResize` | `Sender: TObject` | The size changed |
| `OnSelectItem` | `Sender: TObject; Item: TListItem; Selected: Boolean` | The selection of one item changed (in a multi-selection it fires per item. To be notified all at once, use `OnSelectionChanged`) |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | An LCL drag started |
| `OnUTF8KeyPress` | `Sender: TObject; var UTF8Key: TUTF8Char` | A character key was pressed (one UTF-8 character) |

- There are no events that report copying, moving, deleting, or renaming of files. The component updates the display automatically.
- If you set the keys the component uses (Enter, BackSpace, Delete, Shift+Delete, F2, F5, Ctrl+A, Ctrl+C, Ctrl+X, Ctrl+V, Ctrl+Shift+N, Ctrl+Shift+2, 4, 5, 6) to `Key := 0` in `OnKeyDown` or in the form's `OnKeyDown` (`KeyPreview = True`), the component's behavior stops.

## 7. Operation

### 7.1 Keys

| Key | Action |
|---|---|
| Enter | Opens the selected item (folders are entered; files are opened with the associated application) |
| BackSpace | Moves to the parent folder |
| Ctrl+C | Copy |
| Ctrl+X | Cut |
| Ctrl+V | Paste into the folder being displayed |
| Ctrl+A | Select all |
| Ctrl+Shift+N | Creates a new folder and starts renaming |
| Ctrl+Shift+2 | Large icons |
| Ctrl+Shift+4 | Small icons |
| Ctrl+Shift+5 | List |
| Ctrl+Shift+6 | Details |
| Delete | Move to the Recycle Bin (with confirmation) |
| Shift+Delete | Delete permanently (with confirmation) |
| F2 | Rename |
| F5 | Refresh to the latest state (re-reads everything) |

### 7.2 Mouse

| Operation | Action |
|---|---|
| Double-click | Moves into a folder, opens a file (when `OnDblClick` is set, only that is done) |
| Click on a column header | Sorts by that column (clicking again toggles ascending/descending) |
| Drag a column border | Changes the column width (after that, automatic adjustment of the name column stops) |
| Mouse back button | To the previous folder in the history |
| Mouse forward button | To the next folder in the history |

### 7.3 Context Menu

| Location | Menu |
|---|---|
| On an item | The same menu as Explorer (Open, Send to, Cut, Copy, Delete, Rename, Properties, etc.) + the items of `ExtraItemMenu` |
| Empty area | View (large icons, small icons, list, details), Sort by (name, size, type, date modified, ascending/descending), New folder, New text document, Paste + the same menu as Explorer + the items of `ExtraBackgroundMenu` |

- The same TPopupMenu may be set to both `ExtraItemMenu` and `ExtraBackgroundMenu`.
- To change whether items are enabled just before the menu is shown, write it in the TPopupMenu's `OnPopup`.
- Choosing "Rename" starts renaming in the same way as F2.
- Applications launched from the menu are given a working folder, as in Explorer (empty area: the folder being displayed; on an item: the folder containing that item).

### 7.4 Drag & Drop

| Item | Behavior |
|---|---|
| Counterparts | Inside the application (list <-> list, list <-> tree), and in both directions with Explorer, the desktop, and other applications |
| Starting a drag | Press the button on an item and move a little. All selected items are the target |
| Copy or move | Same as Explorer. Move on the same drive, copy to a different drive. Ctrl to copy, Shift to move, Alt to create a shortcut |
| Dragging with the right button | A menu (Copy here, Move here, Create shortcut here, etc.) is shown when dropped |
| Drop target | Folder item: that folder; ZIP: add to the ZIP; empty area or file item: the folder being displayed |
| Operations that are not possible | Dropping onto itself or a folder inside itself, moving into the same folder (a copy with Ctrl held becomes "... - Copy") |
| During a drag | The drop target is highlighted with a frame, and the list auto-scrolls at the top and bottom edges |
| Cancel | Esc |

Copying, moving, overwrite confirmation, and progress display are handled by Windows, as in Explorer.

## 8. Automatic Refresh

- When the contents of the folder being displayed change in another application or in Explorer, the display is updated automatically.
- Even after an update, the selection (even multiple), focus, and scroll position are preserved. After pasting or dropping, the added items are selected.
- If the folder being displayed disappears, the remaining parent folder is shown.
- While renaming or dragging, updates wait until it finishes.

## 9. Notes

### 9.1 Do Not Change

The following properties are used inside the component. Changing their values makes it stop working correctly.

| Name | Reason |
|---|---|
| `OnEdited` | Used for renaming |
| `OnColumnClick` | Used for sorting by clicking a column header |
| `OnAddItem` | Used for sorting after loading and for the date modified |
| `DragMode` | Leave it as `dmManual` (the component performs drag & drop by itself) |
| `AutoSizeColumns` | Leave it as `False` (if `True`, the display keeps flickering when the size changes) |
| `ReadOnly` | The component switches it at the start and end of renaming |
| `PopupMenu` | Not used (it will not be shown even if set). Add to the menu with `ExtraItemMenu` and `ExtraBackgroundMenu` |

### 9.2 Other

- Windows only.
- Drag & drop is not possible between an application run as administrator and a normal application (a Windows restriction).
- On network drives, change notifications may not arrive. In that case, refresh with F5.
- Paths longer than 260 characters cannot be displayed.
- It is designed for up to about 1,000 files in one folder.
- When files are added, everything is re-read.
- When dragging from the tree to the list, the list switches to that folder at the moment the button is pressed, so it is treated as a drop onto itself and cannot be dropped.
- Moving within the list does not change the tree's selection.
## 10. Usage Examples

### 10.1 Show the Folder Being Displayed and Toggle the Back/Forward Buttons

```pascal
procedure TForm1.CListView1FolderChanged(Sender: TObject);
begin
  Edit1.Text := CListView1.Root;
  btnBack.Enabled := CListView1.CanGoBack;
  btnForward.Enabled := CListView1.CanGoForward;
end;

procedure TForm1.btnBackClick(Sender: TObject);
begin
  CListView1.GoBack;
end;

procedure TForm1.btnForwardClick(Sender: TObject);
begin
  CListView1.GoForward;
end;

procedure TForm1.btnUpClick(Sender: TObject);
begin
  CListView1.NavigateUp;
end;
```

### 10.2 Use a TEdit as an Address Bar

```pascal
uses
  LCLType;   // VK_RETURN

procedure TForm1.Edit1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    if not CListView1.NavigateTo(Edit1.Text) then
      Edit1.Text := CListView1.Root;   // If the path does not exist, restore the original
    Key := 0;
  end;
end;
```

### 10.3 Show the Selected Items in the Status Bar

```pascal
procedure TForm1.CListView1SelectionChanged(Sender: TObject);
var
  Path: string;
begin
  case CListView1.SelCount of
    0: StatusBar1.SimpleText := '';
    1: begin
         Path := CListView1.GetSelectedFilePath;
         if DirectoryExists(Path) then
           StatusBar1.SimpleText := 'Folder: ' + Path
         else
           StatusBar1.SimpleText := 'File: ' + Path;
       end;
  else
    StatusBar1.SimpleText := IntToStr(CListView1.SelCount) + ' items selected';
  end;
end;
```

### 10.4 Change the View Style and Sorting with Buttons

```pascal
procedure TForm1.btnIconClick(Sender: TObject);
begin
  CListView1.SetView(vsIcon);     // Large icons
  CListView1.SortBy(3, False);    // Newest date modified first
end;
```

### 10.5 Show Only Certain Kinds of Files

```pascal
CListView1.Mask := '*.md;*.txt';   // Only Markdown and text (separate multiple masks with ";")
```

### 10.6 Open the Double-clicked File in Your Own Application

```pascal
procedure TForm1.CListView1DblClick(Sender: TObject);
var
  Path: string;
begin
  // If OnDblClick is set, the component's own double-click behavior is not performed. Write the move into folders yourself too
  Path := CListView1.GetSelectedFilePath;
  if Path = '' then
    Exit;
  if DirectoryExists(Path) then
    CListView1.NavigateTo(Path)
  else
    Memo1.Lines.LoadFromFile(Path);
end;
```

### 10.7 View Selected Files One After Another in an Editor

Every time you move between items with a click or the arrow keys, that file is opened in a TCMonacoEditor.

```pascal
{ When one item is selected, open the file in the editor }
procedure TForm1.CListView1SelectionChanged(Sender: TObject);
var
  Path: string;
begin
  if CListView1.SelCount <> 1 then
    Exit;
  Path := CListView1.GetSelectedFilePath;
  if (Path <> '') and not DirectoryExists(Path) then
    CMonacoEditor1.OpenFile(Path);
end;

{ Prevent the associated application from opening on double-click or Enter }
procedure TForm1.CListView1DblClick(Sender: TObject);
var
  Path: string;
begin
  // If OnDblClick is set, the component's own double-click behavior (moving into folders, opening files) is not performed.
  // Write only the move into folders yourself. Files are already opened in the editor when selected, so do nothing
  Path := CListView1.GetSelectedFilePath;
  if DirectoryExists(Path) then
    CListView1.NavigateTo(Path);
end;
```

- If `OnDblClick` is not set, on double-click or Enter the same file is also opened in the associated application (such as a text editor). Opening the same file in two applications may make it impossible to save.
- If `OnDblClick` is left empty, files are no longer opened, but folders can no longer be entered either. To enter folders, write `NavigateTo` as above.
- `OpenFile` of TCMonacoEditor always opens in a new tab. Tabs increase by the number of files selected.

### 10.8 Add Application Items to the Context Menu

1. Place a TPopupMenu on the form and create an item (example: "Send").
2. In `ExtraItemMenu` of the TCListView, select that TPopupMenu.
3. Write the following in the TPopupMenu's `OnPopup` and the item's `OnClick`.

```pascal
{ Enable only when exactly one item is selected }
procedure TForm1.PopupMenu1Popup(Sender: TObject);
begin
  mnuSend.Enabled := CListView1.SelCount = 1;
end;

{ Process the selected items }
procedure TForm1.mnuSendClick(Sender: TObject);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    CListView1.GetSelectedPaths(L);
    // Process each file in L
  finally
    L.Free;
  end;
end;
```

- The target can be obtained with `GetSelectedPaths` or `GetSelectedFilePath` when on an item, and with `Root` when on an empty area.
- What is reflected in the menu is `Caption`, submenus, separators (`Caption = '-'`), `Enabled`, `Visible`, `Checked`, and the display of shortcuts. Icons are not shown.

### 10.9 Make a File Created by the Application Appear Selected in the List

```pascal
procedure TForm1.btnNewMemoClick(Sender: TObject);
var
  S: TStringList;
begin
  CListView1.SelectNewItemsOnNextRefresh;   // On the next refresh, select the newly appeared item
  S := TStringList.Create;
  try
    S.Text := 'Memo';
    S.SaveToFile(IncludeTrailingPathDelimiter(CListView1.Root) + 'memo.txt');
  finally
    S.Free;
  end;
end;
```

### 10.10 Do Not Let the User Go Above a Specified Folder

The component does not have this feature. Check `Root` inside `OnFolderChanged` and go back if it is outside the range.

```pascal
const
  TopFolder = 'C:\Work';

procedure TForm1.CListView1FolderChanged(Sender: TObject);
var
  Cur, Top: string;
begin
  Cur := ExcludeTrailingPathDelimiter(CListView1.Root);
  Top := ExcludeTrailingPathDelimiter(TopFolder);
  if SameText(Cur, Top) or SameText(Copy(Cur, 1, Length(Top) + 1), Top + PathDelim) then
    Exit;
  CListView1.NavigateTo(TopFolder);   // Go back when it leaves the range
end;
```

- The folder outside the range is displayed for a moment before returning. The folder outside the range also remains in the back/forward history.

### 10.11 Create It in Code

```pascal
uses
  CListView;

procedure TForm1.FormCreate(Sender: TObject);
var
  L: TCListView;
begin
  L := TCListView.Create(Self);
  L.Parent := Self;
  L.Align := alClient;
  L.OnFolderChanged := @CListView1FolderChanged;   // Use the handler from 10.1
  L.NavigateTo('C:\Work');
end;
```
