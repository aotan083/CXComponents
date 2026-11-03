# TCTreeView User Manual

Author: aotan083
Date: 2026-10-29
Version: 1.0

---

## 1. Overview and Class

A folder tree view that works like the left pane of Windows Explorer. Just by placing it on a form, copying, moving, deleting, renaming, drag and drop, and the right-click menu for folders all work the same as in Explorer. No code is needed on the application side.

```
v Quick Access
    Desktop
    Downloads
    Documents
  OneDrive
v PC
  > Local Disk (C:)
  > (D:)
v Network
    \\nas\share
> Linux
```

- At the top level, it lists Quick Access, OneDrive, PC (all drives), Network, and Linux (WSL) (same order as Explorer).
- Folders are ordered the same as in Explorer (natural order, comparing digits by numeric value).
- When a folder is changed by another app or by Explorer, the display is updated automatically.
- When connected to a TCListView (file list), the contents of the folder selected in the tree are shown in the list.

| Item | Description |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Class and Unit

| Class | Unit | Package | Base class | Description |
|---|---|---|---|---|
| `TCTreeView` | `CTreeView` | cx | `TShellTreeView` (LCL, `ShellCtrls`) | A folder tree that works like the left pane of Explorer. Copy, move, delete, rename, drag and drop, and the right-click menu work without writing code |

| Type | Unit | Description |
|---|---|---|
| `TCExtraMenuPosition` | `CShellMenu` | Position of items added to the right-click menu. `empTop` (top of the menu), `empBottom` (end of the menu) |

- When placed on a form, `CTreeView` is added to uses automatically.
- When placed on a form, cx is added to the project's required packages automatically.
- When creating it in code, add it to uses yourself. When assigning a value to `ExtraMenuPosition`, also add `CShellMenu` to uses.

## 2. From Placing It on a Form to Running

### 2.1 Using the Tree Alone

1. From the [CX] palette, place TCTreeView on the form.
2. Run it. Quick Access, OneDrive, PC (all drives), Network, and Linux (WSL) are displayed.

### 2.2 Connecting to a TCListView (File List)

1. Place a TCTreeView and a TCListView on the form.
2. Set the TCListView's `ShellTreeView` to the TCTreeView.
3. Run it. When you select a folder in the tree, the list moves to that folder (moving within the list does not change the tree's selection).

### 2.3 Choosing the Items to Display

1. In the Object Inspector, use `ShowQuickAccess`, `ShowOneDrive`, `ShowNetwork`, and `ShowLinux` to decide what is shown or hidden (PC is always shown).
2. To list shared folders under "Network", write them in `NetworkFolders` in the form `\\server\sharename`, one per line.

## 3. Tree Structure

| Order | Item | Kind | When clicked | Display toggle |
|---|---|---|---|---|
| 1 | Quick Access | Group | Only expands/collapses | `ShowQuickAccess` |
| 1-1 | └ Pinned folders (Desktop, Downloads, etc.) | Shortcut | Selects that folder | (same as the group) |
| 2 | OneDrive | Shortcut | Selects the OneDrive folder | `ShowOneDrive` |
| 3 | PC | Group | Only expands/collapses | None (always shown) |
| 3-1 | └ Drives (C:, D:, etc.) | Drive | Selects that drive | - |
| 4 | Network | Group | Only expands/collapses | `ShowNetwork` |
| 4-1 | └ Shared folders (those written in `NetworkFolders`) | Shortcut | Selects that shared folder | - |
| 5 | Linux | Group | Only expands/collapses | `ShowLinux` |
| 5-1 | └ WSL distributions (`\\wsl.localhost\Ubuntu`, etc.) | Shortcut | Selects that folder | - |

- A **group** is a heading with no real folder. Selecting it does not change the list.
- A **shortcut** points to a real folder. When expanded, the subfolders of that folder are shown.
- Groups, shortcuts, and drives cannot be deleted, cut, renamed, or dragged. Shortcuts and drives can be used for copy, paste, and as drop targets.

## 4. Properties

### 4.1 Added or Changed in This Component

| Name | Type | Access | Description |
|---|---|---|---|
| `Path` | `string` | Read/Write | Full path of the selected folder. For a shortcut, the folder it points to. '' when a group is selected. Writing it expands down to that folder and selects it (nonexistent paths are ignored). Runtime only |
| `ShowQuickAccess` | `Boolean` | Read/Write | Whether to show Quick Access (default `True`). Not shown if there are no folders at all |
| `ShowOneDrive` | `Boolean` | Read/Write | Whether to show OneDrive (default `True`). Not shown if OneDrive is not installed |
| `ShowNetwork` | `Boolean` | Read/Write | Whether to show Network (default `True`). Not shown if `NetworkFolders` is empty |
| `ShowLinux` | `Boolean` | Read/Write | Whether to show Linux (WSL) (default `True`). Not shown if WSL is not installed |
| `NetworkFolders` | `TStrings` | Read/Write | Shared folders listed under "Network". Write one per line in the form `\\server\sharename` |
| `ExtraItemMenu` | `TPopupMenu` | Read/Write | Items added to the menu when right-clicking on a folder |
| `ExtraBackgroundMenu` | `TPopupMenu` | Read/Write | Items shown when right-clicking on an empty area |
| `ExtraMenuPosition` | `TCExtraMenuPosition` | Read/Write | Position of the added items. `empTop`: top of the menu. `empBottom` (default): end of the menu |

- Changes to display toggles such as `ShowQuickAccess` and to `NetworkFolders` take effect immediately, even while running. The expanded state and selection are preserved.

### 4.2 Inherited from TShellTreeView

| Name | Type | Access | Description |
|---|---|---|---|
| `Align` | `TAlign` | Read/Write | Placement within the parent |
| `Anchors` | `TAnchors` | Read/Write | Which edges follow when the parent's size changes |
| `AnchorSideBottom` | `TAnchorSide` | Read/Write | Which control and which position the bottom edge is aligned to |
| `AnchorSideLeft` | `TAnchorSide` | Read/Write | Which control and which position the left edge is aligned to |
| `AnchorSideRight` | `TAnchorSide` | Read/Write | Which control and which position the right edge is aligned to |
| `AnchorSideTop` | `TAnchorSide` | Read/Write | Which control and which position the top edge is aligned to |
| `AutoExpand` | `Boolean` | Read/Write | Whether to expand the selected item automatically |
| `BackgroundColor` | `TColor` | Read/Write | Background color |
| `BorderSpacing` | `TControlBorderSpacing` | Read/Write | Margins around the control |
| `BorderStyle` | `TBorderStyle` | Read/Write | Whether to show the border line |
| `BorderWidth` | `TBorderWidth` | Read/Write | Margin inside the border |
| `Color` | `TColor` | Read/Write | Color |
| `Constraints` | `TSizeConstraints` | Read/Write | Upper and lower limits of size |
| `Cursor` | `TCursor` | Read/Write | Mouse cursor when over the control |
| `Enabled` | `Boolean` | Read/Write | Whether it can be used |
| `ExpandCollapseMode` | `TTreeViewExpandCollapseMode` | Read/Write | Rules for expanding/collapsing on click or double-click |
| `ExpandSignColor` | `TColor` | Read/Write | Color of the expand/collapse marker |
| `ExpandSignType` | `TTreeViewExpandSignType` | Read/Write | Shape of the expand/collapse marker |
| `Font` | `TFont` | Read/Write | Text font |
| `Height` | `Integer` | Read/Write | Height |
| `HelpContext` | `THelpContext` | Read/Write | Help number |
| `HelpKeyword` | `string` | Read/Write | Help keyword |
| `HelpType` | `THelpType` | Read/Write | Whether help is looked up by number (`htContext`) or by keyword (`htKeyword`) |
| `HideSelection` | `Boolean` | Read/Write | Whether to hide the selection color when not focused |
| `Hint` | `TTranslateString` | Read/Write | Hint text |
| `HotTrack` | `Boolean` | Read/Write | Whether to highlight the item under the mouse |
| `Images` | `TCustomImageList` | Read/Write | Item icons (if empty, system icons are drawn) |
| `Indent` | `Integer` | Read/Write | Indent width per level |
| `Left` | `Integer` | Read/Write | Left edge position |
| `MultiSelectStyle` | `TMultiSelectStyle` | Read/Write | How multiple selection works (when `tvoAllowMultiselect` is put in `Options`) |
| `Name` | `TComponentName` | Read/Write | Component name |
| `ObjectTypes` | `TObjectTypes` | Read/Write | Kinds of things to display (default `[otFolders]`). To show hidden folders too, add `otHidden` |
| `Options` | `TTreeViewOptions` | Read/Write | Behavior and appearance settings. Do not include `tvoReadOnly`, and do not remove `tvoRightClickSelect` (renaming and the right-click menu would stop working correctly) |
| `ParentColor` | `Boolean` | Read/Write | Whether to use the parent's color (default `False`) |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the parent's `Font` |
| `ParentShowHint` | `Boolean` | Read/Write | Whether to use the parent's `ShowHint` |
| `RowSelect` | `Boolean` | Read/Write | Whether the selection color covers the whole row |
| `ScrollBars` | `TScrollStyle` | Read/Write | How scroll bars are shown |
| `SelectionColor` | `TColor` | Read/Write | Selection color |
| `ShellListView` | `TCustomShellListView` | Read/Write | The connected list. Normally set from the TCListView's `ShellTreeView` side |
| `ShowButtons` | `Boolean` | Read/Write | Whether to show expand/collapse markers |
| `ShowHint` | `Boolean` | Read/Write | Whether to show hints |
| `ShowLines` | `Boolean` | Read/Write | Whether to show lines |
| `ShowRoot` | `Boolean` | Read/Write | Whether to show lines and the expand/collapse marker for the topmost items too |
| `StateImages` | `TCustomImageList` | Read/Write | Item state icons |
| `TabOrder` | `TTabOrder` | Read/Write | Order of movement with the Tab key |
| `TabStop` | `Boolean` | Read/Write | Whether the Tab key stops here (default `True`) |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely |
| `ToolTips` | `Boolean` | Read/Write | Whether to show the name of an item that does not fit when the mouse is over it |
| `Top` | `Integer` | Read/Write | Top edge position |
| `TreeLineColor` | `TColor` | Read/Write | Line color |
| `TreeLinePenStyle` | `TPenStyle` | Read/Write | Line style |
| `Visible` | `Boolean` | Read/Write | Whether it is shown |
| `Width` | `Integer` | Read/Write | Width |

## 5. Methods

### 5.1 Methods of TCTreeView

| Name | Parameters | Return value | Description |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | - | Creates it. Used when creating in code (10.7) |
| `GetPathFromNode` | `ANode: TTreeNode` | `string` | Full path of an item. For a shortcut, the folder it points to; for a group, '' |
| `IsDriveNode` | `Node: TTreeNode` | `Boolean` | `True` if it is a drive (`C:\` or `\\server\share`) |
| `IsSpecialNode` | `Node: TTreeNode` | `Boolean` | `True` if it is a shortcut or a group |
| `IsShortcutNode` | `Node: TTreeNode` | `Boolean` | `True` if it is a shortcut (pinned folder, OneDrive, shared folder, WSL) |
| `IsGroupNode` | `Node: TTreeNode` | `Boolean` | `True` if it is a group (Quick Access, PC, Network, Linux) |
| `CopySelectedFolder` | - | - | Copies the selected folder to the clipboard (same as Ctrl+C) |
| `CutSelectedFolder` | - | - | Cuts the selected folder (same as Ctrl+X). Drives, shortcuts, and groups are excluded |
| `PasteToSelectedFolder` | - | - | Pastes into the selected folder (same as Ctrl+V) |
| `DeleteSelectedFolder` | `APermanent: Boolean = False` | - | Deletes the selected folder. `False`: to the Recycle Bin. `True`: deletes permanently. A confirmation is shown. Drives, shortcuts, and groups are excluded |
| `RenameSelectedFolder` | - | - | Starts renaming the selected folder (same as F2). Drives, shortcuts, and groups are excluded |

### 5.2 Unit Functions

| Name | Parameters | Return value | Description |
|---|---|---|---|
| `IsDriveRootPath` | `const APath: string` | `Boolean` | `True` if the path is the root of a drive (`C:\` or `\\server\share`) |

## 6. Events

This component adds no events. Those inherited from TShellTreeView are as follows.

| Name | Parameters | Description |
|---|---|---|
| `OnAddItem` | `Sender: TObject; const ABasePath: String; const AFileInfo: TSearchRec; var CanAdd: Boolean` | Before a folder is added as an item. Set `CanAdd := False` to skip it |
| `OnAdvancedCustomDraw` | `Sender: TCustomTreeView; const ARect: TRect; Stage: TCustomDrawStage; var DefaultDraw: Boolean` | Each stage of drawing the whole control |
| `OnAdvancedCustomDrawItem` | `Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean` | Each stage of drawing an item |
| `OnChange` | `Sender: TObject; Node: TTreeNode` | The selected folder changed (click, key, writing to `Path`, or when the displayed folder disappeared and the selection moved to its parent) |
| `OnChanging` | `Sender: TObject; Node: TTreeNode; var AllowChange: Boolean` | Before the selection changes. Set `AllowChange := False` to cancel |
| `OnClick` | `Sender: TObject` | Clicked |
| `OnCollapsed` | `Sender: TObject; Node: TTreeNode` | An item was collapsed |
| `OnCollapsing` | `Sender: TObject; Node: TTreeNode; var AllowCollapse: Boolean` | Before an item collapses. Set `AllowCollapse := False` to cancel |
| `OnCustomDraw` | `Sender: TCustomTreeView; const ARect: TRect; var DefaultDraw: Boolean` | Before drawing the whole control |
| `OnCustomDrawItem` | `Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState; var DefaultDraw: Boolean` | Before drawing an item |
| `OnDblClick` | `Sender: TObject` | Double-clicked |
| `OnEditing` | `Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean` | Before renaming starts. Set `AllowEdit := False` to cancel |
| `OnEnter` | `Sender: TObject` | Focus entered |
| `OnExit` | `Sender: TObject` | Focus left |
| `OnExpanded` | `Sender: TObject; Node: TTreeNode` | An item was expanded |
| `OnExpanding` | `Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean` | Before an item expands. Set `AllowExpansion := False` to cancel |
| `OnGetImageIndex` | `Sender: TObject; Node: TTreeNode` | When deciding an item's icon index (when using `Images`) |
| `OnGetSelectedIndex` | `Sender: TObject; Node: TTreeNode` | When deciding the icon index of the selected item (when using `Images`) |
| `OnHasChildren` | `Sender: TCustomTreeView; ANode: TTreeNode` → `Boolean` | When deciding whether to show the expand/collapse marker for an item (drives and ordinary folders) |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A key was pressed |
| `OnKeyPress` | `Sender: TObject; var Key: Char` | A character key was pressed |
| `OnKeyUp` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A key was released |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was pressed |
| `OnMouseEnter` | `Sender: TObject` | The mouse entered |
| `OnMouseLeave` | `Sender: TObject` | The mouse left |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | The mouse moved |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was released |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | The wheel was rotated |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was rotated toward you |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was rotated away from you |
| `OnMouseWheelHorz` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | The horizontal wheel was rotated |
| `OnMouseWheelLeft` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The horizontal wheel was rotated to the left |
| `OnMouseWheelRight` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The horizontal wheel was rotated to the right |
| `OnSelectionChanged` | `Sender: TObject` | The selection changed |
| `OnShowHint` | `Sender: TObject; HintInfo: PHintInfo` | Just before a hint is shown |
| `OnUTF8KeyPress` | `Sender: TObject; var UTF8Key: TUTF8Char` | A character key was pressed (one UTF-8 character) |

- When connected to a TCListView, using only the TCListView's `OnFolderChanged` is enough.
- There are no events that report folder copy, move, delete, or rename. The component updates the display automatically.
- If you set `Key := 0` in `OnKeyDown` or in the form's `OnKeyDown` (`KeyPreview = True`) for keys the component uses (Ctrl+C, Ctrl+X, Ctrl+V, Delete, Shift+Delete, F2, F5), the component's behavior stops.

## 7. Operation

### 7.1 Keys

| Key | Action |
|---|---|
| Ctrl+C | Copy the selected folder |
| Ctrl+X | Cut the selected folder (drives, shortcuts, and groups are excluded) |
| Ctrl+V | Paste into the selected folder |
| Delete | Move to the Recycle Bin (with confirmation; drives, shortcuts, and groups are excluded) |
| Shift+Delete | Delete permanently (with confirmation) |
| F2 | Rename (drives, shortcuts, and groups are excluded) |
| F5 | Refresh the expanded items to the latest state |

### 7.2 Mouse

| Operation | Action |
|---|---|
| Double-click | Expand / collapse |
| Click twice slowly | Rename |
| Mouse Back button | Go to the previous folder in the connected TCListView's history |
| Mouse Forward button | Go to the next folder in the connected TCListView's history |

- The Back and Forward buttons work only when a TCListView is connected to `ShellListView`.

### 7.3 Right-Click Menu

| Location | Menu |
|---|---|
| On a folder | The same menu as Explorer (Open, Send to, Cut, Copy, Delete, Rename, Properties, etc.) + the items of `ExtraItemMenu` |
| On an empty area | Only the items of `ExtraBackgroundMenu` (nothing appears if not set) |

- To add your own items, place a TPopupMenu on the form, create the items, and set it to `ExtraItemMenu` (or `ExtraBackgroundMenu`).
- Write the processing in each menu item's `OnClick`. The target folder can be obtained with `Path` (because the right-clicked folder is selected).
- To change whether items are enabled or disabled just before display, write it in the TPopupMenu's `OnPopup`.
- What is reflected in the menu: `Caption`, submenus, separators (`Caption = '-'`), `Enabled`, `Visible`, `Checked`, and the display of shortcuts. Icons are not displayed.
- The same TPopupMenu may be set to both `ExtraItemMenu` and `ExtraBackgroundMenu`.
- Choosing "Rename" starts the same renaming as F2.
- As in Explorer, an app launched from the menu receives the parent folder of the right-clicked folder as its working folder.

### 7.4 Drag and Drop

| Item | Action |
|---|---|
| Counterpart | Within the app (tree <-> tree, tree <-> list), and both ways with Explorer, the desktop, and other apps |
| Starting a drag | Press the button on a folder and move a little. The subject is the single folder that was pressed (not possible for drives, shortcuts, and groups) |
| Copy or move | Same as Explorer. Move on the same drive, copy to a different drive. Ctrl to copy, Shift to move, Alt to create a shortcut |
| Dragging with the right button | Shows a menu on drop (Copy here, Move here, Create shortcut, etc.) |
| Drop destination | The folder where you dropped |
| Operations not possible | Dropping onto itself or a folder inside itself, moving into the same folder |
| During a drag | The drop destination is highlighted with a frame, auto-scroll at the top and bottom edges, and it expands automatically if you pause for 0.7 seconds |
| Cancel | Esc |

As in Explorer, Windows performs the copying, moving, overwrite confirmation, and progress display.

## 8. Automatic Refresh

- When a folder is added, deleted, or renamed by another app or by Explorer, the display is updated automatically. The expanded state and selection are preserved.
- When a drive such as a USB drive is inserted or removed, the drive list is updated.
- If the selected folder disappears, the remaining parent folder is selected.
- During renaming or dragging, updates wait until it finishes.
- If the same folder is in two places (such as Desktop, which is under both Quick Access and PC), both are updated.

## 9. Notes

### 9.1 Do Not Change

The following properties are used inside the component. Changing their values will stop it from working correctly.

| Name | Reason |
|---|---|
| `Root` | Always used as an empty string (all drives). Get the selected folder with `Path` |
| `FileSortType`, `OnSortCompare` | Used for folder ordering (natural order) |
| `OnEdited` | Used for renaming |
| `DragMode` | Leave as `dmManual` (the component performs drag and drop itself) |
| `ReadOnly` | Leave as `False` (setting `True` disables renaming) |
| `RightClickSelect` | Leave as `True` (so that the right-clicked folder becomes the target of the menu) |
| `PopupMenu` | Not used (it will not appear even if set). Add menus with `ExtraItemMenu` and `ExtraBackgroundMenu` |

### 9.2 Other

- Windows only.
- Drag and drop does not work between an app run as administrator and a normal app (a Windows restriction).
- Change notifications may not arrive for shared folders on the network and for WSL folders. In that case, refresh with F5.
- Paths longer than 260 characters cannot be handled by some functions (such as display).
- Only real folders are shown as shortcuts. Home, Gallery, Recycle Bin, and so on are not shown.
- Quick Access also includes "Frequent folders" depending on Explorer's settings. Changes made to pinning are reflected when the tree is rebuilt (drive insertion/removal, toggling the display, restarting the app).
- Moving within the list does not change the tree's selection.
## 10. Usage Examples

### 10.1 Show the Selected Folder in the Form Title

```pascal
procedure TForm1.CTreeView1Change(Sender: TObject; Node: TTreeNode);
begin
  if CTreeView1.Path <> '' then
    Caption := CTreeView1.Path
  else
    Caption := 'MyApp';   // A group is selected
end;
```

### 10.2 Decide Which Items to Display

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  CTreeView1.ShowOneDrive := False;              // Do not show OneDrive
  CTreeView1.ShowLinux := False;                 // Do not show Linux
  CTreeView1.NetworkFolders.Add('\\nas\share');  // Show a shared folder under Network
end;
```

### 10.3 Expand and Select Down to a Specified Folder, and Expand Inside It

```pascal
procedure TForm1.Button1Click(Sender: TObject);
begin
  CTreeView1.Path := 'C:\Work';
  if CTreeView1.Selected <> nil then
    CTreeView1.Selected.Expand(False);
end;
```

### 10.4 Operate on Folders from Buttons and Menus

```pascal
procedure TForm1.ButtonCopyClick(Sender: TObject);
begin
  CTreeView1.CopySelectedFolder;          // Same as Ctrl+C
end;

procedure TForm1.ButtonPasteClick(Sender: TObject);
begin
  CTreeView1.PasteToSelectedFolder;       // Same as Ctrl+V
end;

procedure TForm1.ButtonDeleteClick(Sender: TObject);
begin
  CTreeView1.DeleteSelectedFolder;        // To the Recycle Bin (with confirmation)
end;

procedure TForm1.ButtonRenameClick(Sender: TObject);
begin
  CTreeView1.RenameSelectedFolder;        // Same as F2
end;
```

### 10.5 Add the App's Own Items to the Right-Click Menu

1. Place a TPopupMenu on the form and create an item (example: "Open command prompt here").
2. Set the TCTreeView's `ExtraItemMenu` to that TPopupMenu.
3. Write the following in the item's `OnClick`. The right-clicked folder is selected, so the target can be obtained with `Path`.

```pascal
uses
  Process;

procedure TForm1.MenuItemCmdClick(Sender: TObject);
begin
  if CTreeView1.Path <> '' then
    with TProcess.Create(nil) do
    try
      Executable := 'cmd.exe';
      CurrentDirectory := CTreeView1.Path;
      Execute;
    finally
      Free;
    end;
end;
```

- To change whether items are enabled or disabled just before display, write it in the TPopupMenu's `OnPopup`.
- What is reflected in the menu: `Caption`, submenus, separators (`Caption = '-'`), `Enabled`, `Visible`, `Checked`, and the display of shortcuts. Icons are not displayed.

### 10.6 Enable or Disable Buttons Depending on the Kind of the Selected Item

```pascal
procedure TForm1.CTreeView1Change(Sender: TObject; Node: TTreeNode);
var
  N: TTreeNode;
  Normal: Boolean;
begin
  N := CTreeView1.Selected;
  // Only ordinary folders (not drives, shortcuts, or groups) can be deleted or renamed
  Normal := (N <> nil) and not CTreeView1.IsSpecialNode(N) and not CTreeView1.IsDriveNode(N);
  ButtonDelete.Enabled := Normal;
  ButtonRename.Enabled := Normal;
  ButtonPaste.Enabled := (N <> nil) and not CTreeView1.IsGroupNode(N);
end;
```

### 10.7 Creating It in Code

```pascal
uses
  CTreeView, CListView;

procedure TForm1.FormCreate(Sender: TObject);
var
  T: TCTreeView;
  L: TCListView;
begin
  T := TCTreeView.Create(Self);
  T.Parent := Self;
  T.Align := alLeft;
  T.Width := 250;

  L := TCListView.Create(Self);
  L.Parent := Self;
  L.Align := alClient;
  L.ShellTreeView := T;     // Show the folder selected in the tree in the list
end;
```
