# TCFileTree User Manual

Author: aotan083
Date: 2026-11-05
Version: 1.0

---

## 1. Overview and Class

A component that shows folders and files in a single tree, rooted at a folder you specify (`RootPath`). It can be used like the Explorer of VS Code. TCListView is not needed. Just by placing it on a form and connecting the target components, copy, cut, paste, delete, rename, new folder, drag and drop, the right-click menu, and opening on double-click all work.

```
v data
    v dir1
        inner.txt
    > dir2
    > dir10
      a.txt
      b.txt
      sample.url
      日本語.txt
```

- The root folder is the single top-level item. You cannot move above the root (to see a higher folder, change `RootPath`).
- Folders come first, then files. Each group is in the same natural order as Explorer (`dir1`, `dir2`, `dir10`).
- File icons are the Windows icons for each extension.
- Double-click opens an item. `.url` goes to TargetBrowser, `.lnk` is sorted by what it points to, text goes to TargetEditor, and everything else uses the Windows file association.
- Dropping selected files onto TCMonacoEditor or TCsEditor opens them in new tabs, one per file.
- When folders or files are added or removed by other applications or Explorer, the display is updated automatically (including inside subfolders). F5 also refreshes it.

| Item | Description |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Class and Unit

| Class | Unit | Package | Base class | Description |
|---|---|---|---|---|
| `TCFileTree` | `CFileTree` | cx | `TCustomTreeView` (LCL) | A tree of folders and files rooted at a specified folder. Operations, drag and drop, the right-click menu, and opening all work without writing code |

| Type | Unit | Description |
|---|---|---|
| `TCFileNode` | `CFileTree` | A tree item. Has `IsDir` (`True` for a folder) |

- When placed on a form, `CFileTree` is added to uses automatically.
- When placed on a form, cx is added to the project's required packages automatically.
- When creating it in code, write uses yourself (10.7).

## 2. From Placing on a Form to Running

### 2.1 Using Only the Tree

1. Place TCFileTree on a form from the [CX] palette.
2. Write the folder to use as the root in `RootPath` (default `C:\`).
3. Run. The root folder is shown expanded.

### 2.2 Connecting an Editor and a Browser

The targets for double-click and the right-click menu are set with properties. Just select components placed on the form in the Object Inspector. No code is needed.

| Property | Component to connect | What it opens |
|---|---|---|
| `TargetEditor` | TCMonacoEditor or TCsEditor | Text files (double-click, "Open as Text", "Open as Text in New Tab") |
| `TargetBrowser` | TCTabBrowser | The URL of a `.url`, and items opened as Web (double-click, "Open as Web", "Open as Web in New Tab") |
| `SideEditor` | TCMonacoEditor or TCsEditor | "Open Side by Side" (text) |
| `SideBrowser` | TCTabBrowser | "Open Side by Side" (Web) |

- Connecting only one is fine. Menu items whose target is not connected are grayed out.
- `TargetEditor` and `SideEditor` can only be connected to the same kind of editor (a combination mixing TCMonacoEditor and TCsEditor is not accepted; the one chosen later is ignored).
- "Open Side by Side" opens in a new tab of `SideEditor` or `SideBrowser`. If that component is hidden, it is made visible. Where it appears is decided by the layout on the form (place them side by side, add a splitter). Each of these can open in one component only.

### 2.3 Showing Hidden Files

1. Set `ShowHidden` to `True`. While running, you can also toggle it with "Show Hidden Files" in the right-click menu.
2. Files and folders with the hidden or system attribute are shown. The expanded state and selection are kept.

### 2.4 Display Language (Japanese / English)

The text this component shows on screen (menus and messages) appears in Japanese or English. The language is one for all cx components, not decided per component.

Write the following in WebView2.ini in the same folder as the EXE. Place this ini even in applications that do not use WebView2 (just `[CX]` is enough).

```ini
[CX]
Language=en
```

| Order | How it is decided |
|---|---|
| 1 | If `Language` in `[CX]` is `ja` or `en`, that language (case-insensitive) |
| 2 | Otherwise (no ini, no `[CX]`, empty, or another value), the Windows display language. `ja` if Japanese, otherwise `en` |

- It is decided only once, the first time text is shown. Rewriting it while running has no effect until the next start.
- The on-screen text written in this manual is the Japanese version. In English it appears in English ("Copy", "Cut", etc.).
- The contents of "Windows Menu" (Send to, Properties, etc.) appear in the Windows language.

## 3. Tree Structure

| Item | Description |
|---|---|
| Root | The folder of `RootPath`. Shows the folder name (for a drive root, the path such as `C:\`). Cannot be copied, cut, deleted, or renamed |
| Folder | Listed first. When expanded, its folders and files are loaded. An empty folder loses its expand marker when opened |
| File | Listed after the folders. No expand marker |
| Order | Folders, then files. Each in the same natural order as Explorer (digits compared by numeric value) |
| Hidden / system attribute | Not shown by default (`ShowHidden`) |

- When the root does not exist (`RootPath` is empty or does not exist), the tree is empty.
- The contents of a folder that has not been opened yet are read, up to date, when it is opened.

### 3.1 Selection

- Multiple selection is possible (Ctrl+click, Shift+click). However, only **items in the same folder** can be selected. If you try to add an item from another folder, the previous selection is released and only the new item is selected (because Windows copy, move, delete and drag assume items in the same folder).
- If you press an item that is already part of a multiple selection without a modifier key and drag it, they are moved together. If you release without moving, only that one item is selected.
- When you right-click an item that is already part of the selection, the selection stays. If it is not, only that item is selected. When you right-click an empty area, the selection is cleared.

## 4. Properties

### 4.1 Added in This Component

| Name | Type | Access | Description |
|---|---|---|---|
| `RootPath` | `string` | Read/Write | Folder to use as the root (default `C:\`). Writing it rebuilds the tree. A trailing `\` is removed (the drive root `C:\` keeps it). If it does not exist or is empty, the tree is empty |
| `ShowHidden` | `Boolean` | Read/Write | Whether to show items with the hidden or system attribute (default `False`). Toggling takes effect immediately, even while running |
| `TargetEditor` | `TControl` | Read/Write | Editor in which text is opened (TCMonacoEditor or TCsEditor; default nil) |
| `TargetBrowser` | `TCTabBrowser` | Read/Write | Browser in which Web items are opened (default nil) |
| `SideEditor` | `TControl` | Read/Write | Editor for "Open Side by Side" (text). Same kind as `TargetEditor` (default nil) |
| `SideBrowser` | `TCTabBrowser` | Read/Write | Browser for "Open Side by Side" (Web) (default nil) |

- When a target component is freed, its property becomes nil.

### 4.2 Usable LCL Standard Properties

| Name | Type | Access | Description |
|---|---|---|---|
| `Align` | `TAlign` | Read/Write | Placement within the parent |
| `Anchors` | `TAnchors` | Read/Write | Which edges follow when the parent's size changes |
| `BorderSpacing` | `TControlBorderSpacing` | Read/Write | Margins around the control |
| `BorderStyle` | `TBorderStyle` | Read/Write | Whether to show the border line |
| `Color` | `TColor` | Read/Write | Color |
| `Constraints` | `TSizeConstraints` | Read/Write | Upper and lower limits of size |
| `Enabled` | `Boolean` | Read/Write | Whether it can be used |
| `Font` | `TFont` | Read/Write | Text font |
| `Hint` | `TTranslateString` | Read/Write | Hint text |
| `Indent` | `Integer` | Read/Write | Indent width per level |
| `ParentColor` | `Boolean` | Read/Write | Whether to use the parent's color (default `False`) |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the parent's `Font` |
| `ShowHint` | `Boolean` | Read/Write | Whether to show hints |
| `TabOrder` | `TTabOrder` | Read/Write | Order in which the Tab key moves |
| `TabStop` | `Boolean` | Read/Write | Whether the Tab key stops here (default `True`) |
| `Visible` | `Boolean` | Read/Write | Whether it is shown |

| Usable at runtime | Type | Description |
|---|---|---|
| `Items` | `TTreeNodes` | The items. Only those already loaded. Nodes are `TCFileNode` |
| `Selected` | `TTreeNode` | The selected item (the last selected one for a multiple selection) |
| `SelectionCount` | `Cardinal` | Number of selected items |
| `Selections[AIndex]` | `TTreeNode` | A selected item |
| `ClearSelection` | - | Clears the whole selection |

- `PopupMenu` cannot be used (the component has its own right-click menu).

## 5. Methods

| Name | Arguments | Return value | Description |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | - | Creates it. Used when creating in code (10.7) |
| `GetPathFromNode` | `ANode: TTreeNode` | `string` | Full path of an item. The root is `RootPath` |
| `IsRootNode` | `ANode: TTreeNode` | `Boolean` | `True` for the root item |
| `IsDirNode` | `ANode: TTreeNode` | `Boolean` | `True` for a folder item |
| `SelectedPath` | - | `string` | Full path of the selected item. '' if none |
| `GetSelectedPaths` | `APaths: TStrings` | - | Puts the full paths of all selected items in visible order (only those in the same folder) |
| `CopySelected` | - | - | Copies the selected items to the clipboard (same as Ctrl+C). The root is excluded |
| `CutSelected` | - | - | Cuts the selected items (same as Ctrl+X). The root is excluded |
| `PasteToSelected` | - | - | Pastes (same as Ctrl+V). The destination is the selected folder. If a file is selected, its parent; if nothing is selected, the root |
| `DeleteSelected` | `APermanent: Boolean = False` | - | Deletes the selected items. `False`: to the Recycle Bin. `True`: permanently. The shell shows a confirmation. The root is excluded |
| `RenameSelected` | - | - | Starts renaming (same as F2). Only when exactly one item is selected and it is not the root |
| `NewFolder` | - | - | Creates a folder and starts editing its name. The destination is the selected folder (if a file is selected, its parent; if nothing is selected, the root). The name is "New Folder" (in Japanese, 「新しいフォルダー」); if the name exists, " (2)", " (3)" ... is added |
| `RefreshTree` | - | - | Brings all expanded folders up to date with the disk (same as F5). The expanded state and selection are kept |

## 6. Events

No events have been added by this component. The usable ones are as follows.

| Name | Arguments | Description |
|---|---|---|
| `OnClick` | `Sender: TObject` | Clicked |
| `OnDblClick` | `Sender: TObject` | Double-clicked (the component performs the opening first) |
| `OnEnter` | `Sender: TObject` | Focus entered |
| `OnExit` | `Sender: TObject` | Focus left |
| `OnExpanded` | `Sender: TObject; Node: TTreeNode` | An item was expanded |
| `OnCollapsed` | `Sender: TObject; Node: TTreeNode` | An item was collapsed |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A key was pressed |
| `OnKeyPress` | `Sender: TObject; var Key: Char` | A character key was pressed |
| `OnKeyUp` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A key was released |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was pressed |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | The mouse moved |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was released |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | The wheel was turned |
| `OnSelectionChanged` | `Sender: TObject` | The selection changed |

- There is no event for running "open" or "open side by side" from application code. The targets are decided with properties (2.2).
- There are no events that report copying, moving, deleting, renaming, or creating files and folders. The component updates the display automatically.
- If you set `Key := 0` for the keys the component uses (Ctrl+C, Ctrl+X, Ctrl+V, Delete, Shift+Delete, F2, F5, Enter) in `OnKeyDown` or the form's `OnKeyDown` (`KeyPreview = True`), the component's behavior stops.

## 7. Operation

### 7.1 Keys

| Key | Action |
|---|---|
| Ctrl+C | Copy the selected items (the root is excluded) |
| Ctrl+X | Cut the selected items (the root is excluded) |
| Ctrl+V | Paste (destination is the selected folder; if a file is selected, its parent) |
| Delete | Move to the Recycle Bin (with confirmation; the root is excluded) |
| Shift+Delete | Delete permanently (with confirmation) |
| F2 | Rename (the root is excluded) |
| F5 | Bring all expanded folders up to date |
| Enter | Open the selected file (same as double-click). Expand/collapse for a folder |

### 7.2 Opening with Double-Click or Enter

| Item | Action |
|---|---|
| Folder | Expand / collapse |
| `.url` | Opens the URL inside it in the displayed tab of `TargetBrowser`. If there is no `TargetBrowser`, opens with the Windows association |
| `.lnk` | Looks at what it points to. For `http://` or `https://`, `TargetBrowser`; for a text file, the displayed tab of `TargetEditor`; otherwise the `.lnk` is opened with the Windows association |
| Text file | Opens in the displayed tab of `TargetEditor`. If there is no `TargetEditor`, opens with the Windows association |
| Any other file | Opens with the Windows association |

- Whether a file is a "text file" is decided by looking at the first 8 KB. An empty file and a file starting with a UTF-16 BOM are text. If there is even one NUL (0x00), it is not text. No list of extensions is used.
- Opening in the displayed tab of `TargetEditor` behaves the same as TCBookmark. If a tab already has that file open, it switches to that tab. If the displayed tab has unsaved changes, it asks whether to open in a new tab (if No, nothing is opened). Otherwise it loads into the displayed tab.
- If the file no longer exists, a message is shown and it is not opened.

### 7.3 Right-Click Menu

It appears after selecting the item under the mouse (selection rules in 3.1). The menu belongs to the component (`PopupMenu` cannot be used).

| No. | Item | Action | Available when |
|---|---|---|---|
| 1 | Copy | Ctrl+C in 7.1 | Items are selected and the root is not included |
| 2 | Cut | Ctrl+X in 7.1 | Same |
| 3 | Paste | Ctrl+V in 7.1 | The clipboard has files |
| 4 | Rename | F2 in 7.1 | Exactly one is selected and it is not the root |
| 5 | Delete | To the Recycle Bin (with confirmation) | Items are selected and the root is not included |
| | (separator) | | |
| 6 | Show in Explorer | For a folder, opens that folder in Explorer. For a file, opens Explorer with that file selected | Items are selected |
| 7 | Copy Path | Puts the full paths of the selected items on the clipboard (one per line if several) | Items are selected |
| | (separator) | | |
| 8 | New Folder | `NewFolder` (chapter 5) | Always |
| | (separator) | | |
| 9 | Open as Text | Opens in the displayed tab of `TargetEditor` (same as 7.2) | Exactly one file is selected, it is text, and `TargetEditor` exists |
| 10 | Open as Text in New Tab | Opens in a new tab of `TargetEditor` | Same |
| 11 | Open Side by Side | Opens in a new tab of `SideEditor` (made visible if hidden) | Exactly one file is selected, it is text, and `SideEditor` exists |
| | (separator) | | |
| 12 | Open as Web | Opens in the displayed tab of `TargetBrowser` | Exactly one file is selected, it can be opened as Web, and `TargetBrowser` exists |
| 13 | Open as Web in New Tab | Opens in a new tab of `TargetBrowser` | Same |
| 14 | Open Side by Side | Opens in a new tab of `SideBrowser` (made visible if hidden) | Exactly one file is selected, it can be opened as Web, and `SideBrowser` exists |
| | (separator) | | |
| 15 | Open with Associated Program | Opens with the Windows associated program | Exactly one file is selected |
| | (separator) | | |
| 16 | Show Hidden Files | Toggles `ShowHidden` (with a check mark) | Always |
| | (separator) | | |
| 17 | Windows Menu | Shows the same menu as right-clicking that item in Explorer (7.4) | Items are selected |

- The "Open as Text" items are available only for text files (7.2). For a `.lnk`, only when what it points to is text. Not available for `.url`.
- The URL opened by the "Open as Web" items: for `.url`, the URL inside it. For `.lnk`, only when it points to `http://` or `https://`. For other files, a `file:///` address (whether it can be opened is up to WebView2).
- Items that cannot be used are grayed out.

### 7.4 Windows Menu

Choosing "Windows Menu" shows the same menu as right-clicking that item in Explorer.

- The contents differ between folders and files (for a file, "Open", "Edit with Notepad", "Open with", etc.; for a folder, "Open", "Pin to Quick access", etc.). Items of applications registered on the PC, such as Git, VLC, and TortoiseGit, also appear.
- The contents of "Send to" also appear, and the selected items can be sent. With multiple selection, they are sent together.
- When exactly one folder is selected (including the root), "New" (Folder, Shortcut, Text Document, etc.) also appears. What you create is made inside the selected folder.
- It is the traditional full menu, not the short menu of Windows 11 (the one with icons on top).
- Choosing "Rename" starts the same rename as F2.
- Applications started from the menu are given the folder that contains the item as the working folder, as in Explorer.

### 7.5 Drag and Drop

| Item | Behavior |
|---|---|
| Partner | Within the application (inside the tree, other components); both directions with Explorer, the desktop, and other applications |
| Starting a drag | Press the button on a file or folder and move a little. With multiple selection, they are moved together. The root cannot be dragged |
| Copy or move | Same as Explorer. Move within the same drive, copy to another drive. Ctrl to copy, Shift to move, Alt to create a shortcut |
| Dragging with the right button | Shows a menu on drop (Copy here, Move here, Create shortcuts here, etc.) |
| Drop target | On a folder, inside that folder. On a file, inside the folder that contains that file. On an empty area, inside the root |
| Not allowed | Dropping onto itself or a folder inside itself; moving to the same folder |
| While dragging | The target folder is highlighted with a frame, auto-scroll at the top and bottom edges, auto-expand after 0.7 seconds |
| Cancel | Esc |

As in Explorer, Windows performs copying, moving, overwrite confirmation, and progress display.

#### Dropping onto an Editor

- Dropping selected files onto TCMonacoEditor or TCsEditor opens them in new tabs by the editor's own behavior. With multiple selection, one tab per file. Files already open switch to their tab.
- Folders do nothing (only files are opened).
- It only opens them; the original files do not move.
- Setting the editor's `OpenDroppedFiles` to `False`, or `Handled := True` in `OnFileDrop`, stops this behavior.

## 8. Automatic Update

- When files or folders are added, deleted, or renamed by other applications or Explorer, the display is updated automatically. This includes changes inside subfolders. The expanded state and selection are kept.
- When a file is created in an open folder with "Save As" of an editor, it is also shown.
- The targets of the update are the folders already loaded in the tree (opened at least once). Folders that have not been loaded read the latest contents when opened.
- Changes outside the root do not affect the display.
- For places where changes are hard to detect, such as network locations, update with F5 (`RefreshTree`).
- When the selected item disappears, by the rule of LCL the selection moves to a nearby item.
- When the root folder disappears, the tree becomes empty. When the root has been recreated, write another path to `RootPath` once and then return to the original path (writing the same path does nothing).
- While renaming or dragging, updates wait until it finishes.

## 9. Notes

- The default root is `C:\`, which covers the whole drive. Opening deep levels can take time to load. Normally, specify the folder you work in as `RootPath`.
- When a folder is opened, its entire contents are read at once. A folder with tens of thousands of files takes time to open.
- Only items in the same folder can be selected at the same time (3.1).
- A name containing `\ / : * ? " < > |` cannot be given when renaming. A message appears and the original name is restored.
- Copying, moving, deleting, renaming, and creating files and folders are all done by Windows (the shell). When it fails, for example because a file is in use, Windows shows the reason.

## 10. Usage Examples

### 10.1 Connecting an Editor

1. Place TCFileTree and TCMonacoEditor on a form.
2. Select the TCMonacoEditor for `TargetEditor` of TCFileTree.
3. Write the folder you work in to `RootPath`.
4. Run, and double-click a text file. It opens in the editor.

### 10.2 Connecting Both an Editor and a Browser

1. Place TCFileTree, TCMonacoEditor, and TCTabBrowser on a form.
2. Select the TCMonacoEditor for `TargetEditor` and the TCTabBrowser for `TargetBrowser`.
3. Double-clicking a `.url` opens it in the TCTabBrowser.

### 10.3 Opening Side by Side

1. Place one more TCMonacoEditor on the form separate from the target (on the right side, etc.).
2. Select that TCMonacoEditor for `SideEditor`.
3. Right-click a file and choose "Open Side by Side". It opens in a new tab of that editor.

### 10.4 Getting the Paths of the Selected Files

```pascal
procedure TForm1.Button1Click(Sender: TObject);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    CFileTree1.GetSelectedPaths(L);   // full paths of all selected items
    ShowMessage(L.Text);
  finally
    L.Free;
  end;
end;
```

### 10.5 Switching the Folder

```pascal
CFileTree1.RootPath := 'D:\work\project1';   // rebuilds the tree
```

### 10.6 Refreshing the Display and Hidden Files

```pascal
CFileTree1.RefreshTree;               // same as F5
CFileTree1.ShowHidden := True;        // show hidden files too
```

### 10.7 Creating in Code

```pascal
uses CFileTree, uCmonacos;

var
  Tree: TCFileTree;
  Ed: TCMonacoEditor;
begin
  Ed := TCMonacoEditor.Create(Self);
  Ed.Parent := Self;
  Ed.Align := alClient;

  Tree := TCFileTree.Create(Self);
  Tree.Parent := Self;
  Tree.Align := alLeft;
  Tree.Width := 300;
  Tree.RootPath := 'C:\work';
  Tree.TargetEditor := Ed;
end;
```
