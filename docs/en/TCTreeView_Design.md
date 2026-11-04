# TCTreeView Design Document

Author: aotan083
Date: 2026-11-05
Version: 1.1

---

## 1. Purpose

Based on TShellTreeView (LCL), build a folder tree that works like the left pane of Windows Explorer. Just by placing it on a form, copy, move, delete, rename, drag and drop, the right-click menu, and automatic refresh all work.

- At the top level, list Quick Access, OneDrive, PC (all drives), Network, and Linux (WSL).
- File operations are left to the shell (Windows), and display updates are left to folder change notifications.
- Folders are ordered in the same natural order as Explorer.
- Even when the window is recreated, for example by docking or undocking with AnchorDocking, the expanded folders, selection and scroll position are kept as they are (chapter 6).

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `CTreeView.pas` | cx (runtime) | Types, `TCTreeNode`, `TCTreeView`, `IsDriveRootPath` |
| `CShellNotify.pas`, `CShellMenu.pas`, `CShellDragDrop.pas`, `CShellOleDrop.pas`, `CShellOleDrag.pas` | cx (runtime) | Shared parts. See chapters 9 to 13 of the TCListView Design Document |
| `uCXReg.pas` | cxdsgn (design time) | Registration to the [CX] palette (first in order) |
| `cx_icons.lrs` | cxdsgn (design time) | Icons (`TCTreeView`, `TCTreeView_150`, `TCTreeView_200`) |

- uses in interface: `Classes, SysUtils, Controls, ComCtrls, ShellCtrls, Windows, ActiveX, ShlObj, ShellAPI, Messages, Graphics, Dialogs, Forms, LMessages, ExtCtrls, Menus, CommCtrl, CShellNotify, CShellMenu, CShellDragDrop, CShellOleDrop, CShellOleDrag`
- uses in implementation: `CListView, ComObj, Variants, Registry` (`CListView` is used for Back/Forward and for moving the list when a shortcut is selected).
- Declared as external: `StrCmpLogicalW` (shlwapi), `SHGetFileInfoW`, `SHParseDisplayName`, `SHGetSpecialFolderLocation` (shell32; declared independently under their own names).
- There is no initialization or finalization.

## 3. Types and Constants

```pascal
PRenameInfo = ^TRenameInfo;
TRenameInfo = record
  OldPath: string;
  NewPath: string;
  ParentPath: string;   // Holds a path, not a pointer to a node
end;

TCNodeKind = (nkNormal, nkGroup, nkShortcut);
TCGroupKind = (gkNone, gkQuickAccess, gkPC, gkNetwork, gkLinux);

TCTreeNode = class(TShellTreeNode)
public
  Kind: TCNodeKind;
  Group: TCGroupKind;
  RealPath: string;      // Actual folder a shortcut points to (when nkShortcut)
  IconIndex: Integer;    // System icon index (valid when IconLoaded)
  IconLoaded: Boolean;
  procedure InitSpecial(AKind: TCNodeKind; AGroup: TCGroupKind; const ARealPath: string);
end;

function IsDriveRootPath(const APath: string): Boolean;
```

| Kind | Contents |
|---|---|
| `nkNormal` | An ordinary folder or drive |
| `nkGroup` | A group (Quick Access, PC, Network, Linux). Has no real path |
| `nkShortcut` | A shortcut (pinned folder, OneDrive, shared folder, WSL). Points to a real folder |

- `InitSpecial`: Sets the kind and group, sets `RealPath` with the trailing separator removed, sets `IconLoaded := False`, `FFileInfo.Name := Text`, and `FFileInfo.Attr := faDirectory` (treated as a folder).
- `IsDriveRootPath(P)`: Returns `True` if P with the trailing separator removed is not empty and equals `ExtractFileDrive(P)` (`C:\`, `\\server\share`).

Constants:

| Name | Value | Contents |
|---|---|---|
| `CQuickAccessParse` | 'shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}' | Quick Access |
| `CCSIDL_NETWORK` | $0012 | Network |
| `MaxPendingPaths` | 200 | When refresh candidates exceed this, refresh everything |
| `CWM_XBUTTONUP`, `CWM_APPCOMMAND` | $020C, $0319 | Mouse Back/Forward buttons |

## 4. Fields

| Name | Type | Initial value | Contents |
|---|---|---|---|
| `FIsRefreshing` | `Boolean` | `False` | Refreshing (do not run multiple times at once) |
| `FNotifyID` | `ULONG` | 0 | Change notification registration ID (one for everything under PC) |
| `FNotifyTimer` | `TTimer` | 300ms, stopped | Throttling of notifications |
| `FPendingPaths` | `TStringList` | Empty (case-insensitive, sorted, duplicates ignored) | Folders that may need refreshing |
| `FRefreshAll` | `Boolean` | `False` | Refresh the whole tree (including the drive list) |
| `FDragArmed`, `FDragStartPt`, `FDragNodePath`, `FDragButton` | | | Drag preparation (path of the pressed node and the button) |
| `FDropHilite` | `TTreeNode` | nil | Node to draw a frame around as the drop target |
| `FHoverNode`, `FHoverSince` | | | Node being hovered and the time hovering began, for auto-expand |
| `FDragTimer` | `TTimer` | 80ms, stopped | Auto-scroll and auto-expand during drag |
| `FOleTarget` | `TCShellOleDropTarget` | nil | OLE drop target |
| `FOleDragOver` | `Boolean` | `False` | A drag from elsewhere is over this control |
| `FInXButton` | `Boolean` | `False` | `WM_XBUTTONUP` is being processed |
| `FExtraItemMenu`, `FExtraBackgroundMenu` | `TPopupMenu` | nil | Items added to the right-click menu |
| `FExtraMenuPosition` | `TCExtraMenuPosition` | `empBottom` | Position to add them |
| `FShowQuickAccess`, `FShowOneDrive`, `FShowNetwork`, `FShowLinux` | `Boolean` | `True` | Top-level display |
| `FNetworkFolders` | `TStringList` | Empty. `OnChange := NetworkFoldersChanged` | Shared folders listed under Network |
| `FSysSmallImages` | `HIMAGELIST` | 0 | System small icon list (used to draw shortcut and group icons) |
| `FTopLevelDirty` | `Boolean` | `False` | The top-level display was switched while there was no window (rebuilt by the next `CreateWnd`; chapter 6, 7.1) |

## 5. Declarations

```pascal
public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  function IsDriveNode(Node: TTreeNode): Boolean;
  procedure DeleteSelectedFolder(APermanent: Boolean = False);
  procedure CopySelectedFolder;
  procedure CutSelectedFolder;
  procedure PasteToSelectedFolder;
  procedure RenameSelectedFolder;
  function GetPathFromNode(ANode: TTreeNode): string; reintroduce;
  function IsSpecialNode(Node: TTreeNode): Boolean;
  function IsGroupNode(Node: TTreeNode): Boolean;
  function IsShortcutNode(Node: TTreeNode): Boolean;
  property Path: string read GetCPath write SetCPath;
published
  property ShowQuickAccess: Boolean read FShowQuickAccess write SetShowQuickAccess default True;
  property ShowOneDrive: Boolean read FShowOneDrive write SetShowOneDrive default True;
  property ShowNetwork: Boolean read FShowNetwork write SetShowNetwork default True;
  property ShowLinux: Boolean read FShowLinux write SetShowLinux default True;
  property NetworkFolders: TStrings read GetNetworkFolders write SetNetworkFolders;
  property ExtraItemMenu: TPopupMenu read FExtraItemMenu write SetExtraItemMenu;
  property ExtraBackgroundMenu: TPopupMenu read FExtraBackgroundMenu write SetExtraBackgroundMenu;
  property ExtraMenuPosition: TCExtraMenuPosition read FExtraMenuPosition write FExtraMenuPosition default empBottom;
protected
  procedure DoCreateNodeClass(var NewNodeClass: TTreeNodeClass); override;
  function CanExpand(Node: TTreeNode): Boolean; override;
  function NodeHasChildren(Node: TTreeNode): Boolean; override;
  procedure DoSelectionChanged; override;
  function DrawBuiltInIcon(ANode: TTreeNode; ARect: TRect): TSize; override;
  procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  procedure DoContextPopup(MousePos: TPoint; var Handled: Boolean); override;
  procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  procedure CreateWnd; override;
  procedure DestroyWnd; override;
  procedure WndProc(var Message: TLMessage); override;
  function CanEdit(Node: TTreeNode): Boolean; override;
  procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
  procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  procedure Paint; override;
```

## 6. Creating and Destroying

Create:

1. `FileSortType := fstCustom`, `OnSortCompare := CompareFolderNames` (natural order).
2. The initial values in chapter 4.
3. `ReadOnly := False` (allow renaming), `DragMode := dmManual` (dragging is started by the control itself), `ShowButtons := True`, `ShowLines := False`, `ShowRoot := True`, `RightClickSelect := True`, `OnEdited := InternalOnEdited`.
4. Create the two timers.

Destroy: Stop the timers -> `ShellDragAbandon(Self)` -> unregister the OLE drop target -> `UnregisterFolderNotify` -> `Application.RemoveAsyncCalls(Self)` (so that `DoAsyncRename` does not run later) -> free `FPendingPaths` -> `inherited` -> free `FNetworkFolders`.

CreateWnd: After `inherited`, unless at design time:

1. Build the top level (only in one of the following cases):
   - There are no items (`Items.Count = 0`; when the window is created for the first time): `Root := ''` (all drives directly under PC), `BuildTopLevel`.
   - `FTopLevelDirty` (the display was switched while there was no window): `FTopLevelDirty := False`, `RefreshKeepingState(nil, True)` (rebuild while keeping the expanded state and selection; 7.6).
2. `RegisterFolderNotify`, `OleDropRegister(Handle, OleResolveDrop, OleDropLeave, OleDropped)` (registered again every time the window is recreated; same as now).

- Otherwise (when the window is recreated by docking/undocking with AnchorDocking, changing the parent of a form, etc.), the items are left untouched. The LCL TTreeView holds its items inside the component, so the items, expanded state and selection remain even when the window is recreated.
- While the window is being recreated (from `DestroyWnd` to `CreateWnd`), change notifications do not arrive. Folders that changed in that time are corrected by the next notification or F5.

DestroyWnd: `UnregisterFolderNotify`, `OleDropRevoke`, `inherited`.

`DoCreateNodeClass`: After `inherited`, `NewNodeClass := TCTreeNode`.

## 7. Processing

### 7.1 Building the Top Level (BuildTopLevel)

Does nothing at design time. Within `Items.BeginUpdate`:

1. `PopulateWithBaseFiles` (the base processing lists the drives at the top level). Remember the resulting drive nodes.
2. Quick Access (`ShowQuickAccess`): Get names and paths with `GetQuickAccessFolders`; if there is at least one, insert "Quick Access" (`nkGroup`, `gkQuickAccess`, `HasChildren := True`) before the first drive and add shortcuts as its children.
3. OneDrive (`ShowOneDrive`): If `GetOneDrivePath` is not empty, insert "OneDrive" (`nkShortcut`) before the first drive.
4. PC: If there are drives, append "PC" (`nkGroup`, `gkPC`) at the end and move all the drive nodes under it (`MoveTo(G, naAddChild)`). Always shown.
5. Network (`ShowNetwork` and `NetworkFolders` has at least one entry): Add "Network" (`gkNetwork`) and, for each non-empty line, add a shortcut using the text with the trailing separator removed.
6. Linux (`ShowLinux`): If `GetWslDistros` returns any names, add "Linux" (`gkLinux`) and, for each name, add a shortcut to '\\wsl.localhost\' + name.
7. Quick Access and PC are left expanded (same as Explorer).

| Procedure | Processing |
|---|---|
| `GetQuickAccessFolders(names, paths)` | Iterates `CreateOleObject('Shell.Application').NameSpace(CQuickAccessParse).Items` and adds only items that are folders and have a non-empty, existing path (ZIP and virtual folders are excluded). On an exception, adds nothing (Quick Access is not shown) |
| `GetOneDrivePath` | The environment variable `OneDrive`, otherwise `OneDriveConsumer`. '' if it does not exist |
| `GetWslDistros(names)` | `DistributionName` of the subkeys of `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss`. Existence is not checked, so as not to start WSL. On an exception, adds nothing |
| `AddGroupNode(text, group)` | Appends at the end, `InitSpecial(nkGroup, group, '')`, `HasChildren := True` |
| `AddShortcutNode(parent, text, path)` | Adds as a child of the parent (top level if the parent is nil), `InitSpecial(nkShortcut, gkNone, path)`, `HasChildren := True` |
| `RebuildTopLevel` | Does nothing at design time, while loading, or while being destroyed. Without a handle, sets `FTopLevelDirty := True` and does nothing (rebuilt by the next `CreateWnd`; chapter 6). Otherwise `RefreshKeepingState(nil, True)` |
| `SetShowQuickAccess`, `SetShowOneDrive`, `SetShowNetwork`, `SetShowLinux` | If changed, store and `RebuildTopLevel` |
| `SetNetworkFolders` | `Assign` (rebuilt via `OnChange`) |
| `NetworkFoldersChanged` | If `ShowNetwork`, `RebuildTopLevel` |

### 7.2 Node Kinds and Paths

| Procedure | Processing |
|---|---|
| `IsSpecialNode` | A `TCTreeNode` with `Kind <> nkNormal` |
| `IsGroupNode`, `IsShortcutNode` | `Kind = nkGroup`, `nkShortcut` |
| `IsDriveNode` | `IsDriveRootPath(GetPathFromNode(Node))` |
| `GetPathFromNode` | '' for nil and groups. For a shortcut, `RealPath` + separator. Otherwise `inherited` |
| `NodeKey` | Key used to remember the expanded state. For a group, '#group:' + text; otherwise the path (without a trailing separator) |
| `GetPathRootNodes(list)` | Collects path origins (drives and shortcuts). Looks at the top level and the children of groups, puts shortcuts last, drives first |
| `PathRootOf(N)` | If not a group, the origin reached by following parents until the parent is a group or nil |
| `FindNodeUnder(origin, path)` | If the origin's path equals the target, the origin. If the target is not under the origin, nil. Looks at the children: returns one that matches, descends into one whose prefix matches, otherwise moves to the next sibling (levels not yet loaded are not found) |
| `FindNodesForPath(path, result)` | Runs `FindNodeUnder` from every origin and collects the results without overlap (a node may exist both under a drive and under a shortcut) |
| `FindNodeForPath(path, preferred origin)` | First pass: only the preferred origin; second pass: all origins (drives first), running `FindNodeUnder`. The first one found |
| `GetCPath` (read of `Path`) | `GetPathFromNode(Selected)` |
| `SetCPath` (write of `Path`) | Does nothing if empty. Applies `ExpandFileName`, removes the trailing separator, and does nothing if it does not exist. Chooses the origin (a non-shortcut drive that equals or contains the target if there is one; otherwise the longest matching shortcut). From the origin, expands and follows the children that equal or prefix-match the target (if not found, as far as it could follow). `Selected := node`, `MakeVisible` |

### 7.3 Expanding, Markers, and Selection

| Procedure | Processing |
|---|---|
| `CanExpand(N)` | Group: `True` if it has children (used as built, not reloaded). Shortcut: delete the children and run `PopulateTreeNodeWithFiles(N, RealPath + separator)` (exceptions such as an unreachable shared folder are ignored). If there are no children, `HasChildren := False`. Otherwise `inherited` |
| `NodeHasChildren(N)` | Group: `True` if it has children. Shortcut: `True` (does not inspect the contents until expanded, so as not to stall on shared folders and WSL). Otherwise `inherited` |
| `DoSelectionChanged` | If the selection is a shortcut: if `ShellListView` is a `TCListView`, `NavigateTo(RealPath)`; for any other list, `Root := RealPath` if it exists (exceptions are ignored). For a group, the list is not changed. In both cases, call `OnSelectionChanged` and finish (the base processing is not run). For ordinary nodes, `inherited` |
| `CanEdit(N)` | `inherited`, and `True` unless it is a drive, shortcut, or group |
| `CompareFolderNames(A, B)` | Compares names with `StrCmpLogicalW` (natural order) |
| `FolderHasSubFolders(P)` | With `FindFirstFileW` (`ShellLongPathW`), `True` if there is at least one folder other than '.' and '..'. Hidden folders are not counted unless `ObjectTypes` contains `otHidden` |

### 7.4 Icons (Shortcuts and Groups)

`DrawBuiltInIcon`: `inherited` if the node is neither a shortcut nor a group. Otherwise, draws the index from `SpecialIconIndex` out of `FSysSmallImages` with `ImageList_Draw(..., ILD_TRANSPARENT)`, vertically centered in the frame. Returns the size from `GetBuiltinIconSize`.

`SpecialIconIndex(N)`: If already loaded, that index. Otherwise:

| Node | How to get it |
|---|---|
| Shortcut starting with '\\' (shared folder, WSL) | `SHGetFileInfoW(path, FILE_ATTRIBUTE_DIRECTORY, SHGFI_SYSICONINDEX or SHGFI_SMALLICON or SHGFI_USEFILEATTRIBUTES)` (the generic folder icon, without touching the disk) |
| Other shortcuts | `SHGetFileInfoW(path, 0, SHGFI_SYSICONINDEX or SHGFI_SMALLICON)` |
| PC | `SHGFI_PIDL` with the PIDL of `SHGetSpecialFolderLocation(CSIDL_DRIVES)` |
| Network | The PIDL of `CSIDL_NETWORK` ($0012) |
| Quick Access | The PIDL of `SHParseDisplayName(CQuickAccessParse)` |
| Linux, etc. | 'folder' with `FILE_ATTRIBUTE_DIRECTORY` and `SHGFI_USEFILEATTRIBUTES` (the generic folder icon) |

If the return value (the image list handle) is not 0, store it in `FSysSmallImages` when that is 0, and use `iIcon` as the index. Free the PIDL. Remember the index and set `IconLoaded := True`.

### 7.5 Change Notifications

`RegisterFolderNotify`: Unregisters the previous registration. Ends at design time or without a handle. Registers everything under PC (`CCSIDL_DRIVES`), including subfolders, as a single registration for `MKDIR, RMDIR, RENAMEFOLDER, UPDATEDIR, DRIVEEVENTS` (unrelated paths are discarded on the receiving side).

`HandleShellNotify`:

1. `ShellNotifyDecode`. Ends if being destroyed.
2. For a drive event (`DRIVEEVENTS`), `FRefreshAll := True`.
3. Otherwise (if not `FRefreshAll`): add the parents of path 1 and path 2 to `FPendingPaths` (the place where children are added or removed). For `UPDATEDIR`, also add path 1 itself. If it exceeds 200, empty it and set `FRefreshAll := True`.
4. Re-arm `FNotifyTimer`.

`NotifyTimerTick`: Deferred while a name is being edited, during an LCL drag, while refreshing, during an in-app drag, or while a drag from elsewhere is over the control (so that the node highlighted as the drop target is not rebuilt). Stops the timer, takes out and empties `FRefreshAll` and `FPendingPaths`, and if either is set, runs `RefreshKeepingState(candidates, all)`.

### 7.6 State-Preserving Refresh (RefreshKeepingState)

Does nothing if refreshing or being destroyed. `FIsRefreshing := True`.

1. Remember the path of the selected node and the path of its origin. Visit all nodes and remember the keys (`NodeKey`) of the expanded ones.
2. Within `Items.BeginUpdate`:
   - For a full refresh, run `BuildTopLevel` and, from the top level, re-expand the nodes of the remembered keys (`RestoreExpanded`: stops there if there is no key; if there is, expands and moves on to the children).
   - For candidates, run `FindNodesForPath` for each path (searched every time, since earlier node refreshes may have rebuilt nodes; if it is in both places, both). Closed nodes are not rebuilt: if they have children, delete them and set `HasChildren := FolderHasSubFolders` (so they load the latest state the next time they are expanded). Expanded nodes get `Refresh(node)`, are re-expanded, and their children go through `RestoreExpanded`.
   - Restore the selection: if the remembered path differs from the current selection, follow from that path up to its parents and select the first node found by `FindNodeForPath(path, origin)` (if it disappeared, the remaining parent).
3. Exceptions are swallowed (it will be redone by the next notification or F5). `FIsRefreshing := False`.

### 7.7 F5 (DoRefreshVisibleNodes)

Does nothing if refreshing or being destroyed. Remember the selection, its origin, and the keys of expanded nodes; within `Items.BeginUpdate`, run `RefreshAndRestore` from the top level (if there is a key, `Refresh` and re-expand, then go to the new children; closed nodes are not touched). If the node of the remembered selection path exists, select it again. Exceptions are swallowed.

### 7.8 Back / Forward (WndProc)

`XButtonDirection` uses the same determination as TCListView (TCListView Design Document 7.4).

- `WM_APPCOMMAND`: Unless `FInXButton`, `TreeHistoryGo(direction)`. `Result := 1`.
- `WM_XBUTTONUP`: `inherited` with `FInXButton := True`, then `TreeHistoryGo(direction)`, `Result := 1`.
- `TreeHistoryGo`: If `ShellListView` is a `TCListView`, calls its `GoBack` / `GoForward`.

WndProc also receives `WM_CSHELLNOTIFY` and passes it to `HandleShellNotify`.

### 7.9 Keys (KeyDown)

| Key | Processing |
|---|---|
| Ctrl+C, Ctrl+X, Ctrl+V | `CopySelectedFolder`, `CutSelectedFolder`, `PasteToSelectedFolder`, `Key := 0`, `inherited`, then finish |
| F2 | `RenameSelectedFolder`, `Key := 0` |
| Delete | `DeleteSelectedFolder(whether Shift is held)`, `Key := 0` |
| F5 | `DoRefreshVisibleNodes`, `Key := 0` (for when notifications do not arrive, such as on the network) |

Finally, `inherited KeyDown`.

### 7.10 Folder Operations

| Procedure | Processing |
|---|---|
| `CopySelectedFolder` | If the selected node has a path, `ShellInvokeVerbOnItems(Handle, [path], 'copy')` (a drive gets a trailing separator, giving "C:\") |
| `CutSelectedFolder` | Does nothing for drives, shortcuts, and groups. `ShellInvokeVerbOnItems(..., 'cut')` |
| `PasteToSelectedFolder` | If there is a path, `ShellInvokeVerbOnFolder(Handle, path, 'paste')` |
| `DeleteSelectedFolder(permanent)` | Does nothing for drives, shortcuts, and groups. `PerformFileOperation(FO_DELETE, path, '', not permanent)` |
| `PerformFileOperation` | `SHFILEOPSTRUCTW` (the W version). Source and destination end with #0#0. `FOF_ALLOWUNDO` only when sending to the Recycle Bin. A confirmation is shown even for permanent deletion |
| `RenameSelectedFolder` | Unless it is a drive, shortcut, or group, `Selected.EditText` |
| `InternalOnEdited(N, S)` | Ends if empty. For a drive, reverts. If `ContainsInvalidChar`, shows 'The following characters cannot be used in a folder name:' + newline + '\ / : * ? " < > \|' and reverts. The old path is the node's actual path; the new path is the parent + `S`. If they differ, `New` a `TRenameInfo` and `QueueAsyncCall(DoAsyncRename)` |
| `DoAsyncRename` | Unless being destroyed, `ShellRenameItem(Handle, old, new name)`. On failure (the shell shows the reason), adds the parent to `FPendingPaths` and re-arms the timer, to restore the node's display. Finally `Dispose` |

Display updates are left to change notifications.

### 7.11 Right-Click Menu

`DoContextPopup`: If there is a node under the mouse, select it and call `DisplayShellContextMenu(path, position)`. If not, `DisplayBackgroundMenu(position)`. `Handled := True` (the component's `PopupMenu` is not used).

`DisplayShellContextMenu(P, position)`:

1. Ends if P is empty. Gets the `IShellFolder` of the parent path (P itself if there is none) and calls `GetUIObjectOf(IID_IContextMenu)` with the PIDL of P's child.
2. `QueryContextMenu(menu, 0, 1, $7FFF, CMF_NORMAL)`, `ExtraMenuInsert(..., ExtraItemMenu, ...)`, `TrackShellContextMenu`.
3. For a custom item, `ExtraMenuClick`. Otherwise, if the command name is 'rename', `RenameSelectedFolder` (since the shell's rename does not work in this view). Otherwise `ShellInvokeMenuCommand(..., parent path)` (the parent is passed as the working folder).

`DisplayBackgroundMenu`: Does nothing without `ExtraBackgroundMenu`. Runs `ExtraMenuInsert` into an empty menu and does not show it if the result is 0. `TrackShellContextMenu(..., nil, ...)`, `ExtraMenuClick`.

`SetExtraItemMenu`, `SetExtraBackgroundMenu`: Re-attach the free notification. `Notification`: sets to nil when freed.

### 7.12 Drag and Drop

Source side:

1. `MouseDown`: After `inherited`, `FDragArmed := False`. If the button is left or right, no editing is in progress, the node is not a drive, shortcut, or group, and it has a path: `FDragArmed := True`, and remember the path, button, and position.
2. `MouseMove`: If `FDragArmed` and the button has been released, cancel. If the mouse has moved by `SM_CXDRAG` / `SM_CYDRAG` or more: `FDragArmed := False`, `ShellDragBegin(Self, [path])`, `ShellDoDragDrop(Handle, [path], False, Effect)` (default drag image), `ShellDragEnd`, `ReleaseCapture`. The subject is the single folder that was pressed.
3. `MouseUp`: `FDragArmed := False`, `inherited`.

Target side (`OleResolveDrop`):

1. '' if there is no handle. `FOleDragOver := True`, run `FDragTimer`.
2. The path of the node under the mouse (groups give '') is the drop destination.
3. '' if the drag started within the app and `ShellDecideDropEffect(...) = cdeNone`.
4. `SetDropHilite` with that node if there is a destination, nil otherwise.

| Procedure | Processing |
|---|---|
| `OleDropLeave` | `FOleDragOver := False`, stop the timer, `FHoverNode := nil`, remove the frame |
| `OleDropped` | Does nothing (display updates are left to change notifications) |
| `SetDropHilite` | If changed, store and `Invalidate` |
| `Paint` | After `inherited`, if `FDropHilite` is visible, a 2px frame in `clHighlight` on `DisplayRect(True)` |
| `DragTimerTick` | If not dragging, stop and remove the frame. If the mouse is outside (with a 20px margin above and below), stop. Within 20px of the top or bottom edge, `WM_VSCROLL` (one line). If it stays over the same node for 700ms and the node is closed and has children, expand it |

## 8. What to Check When Investigating Defects

| Symptom | Where to look |
|---|---|
| Quick Access, OneDrive, or Linux does not appear | `GetQuickAccessFolders`, `GetOneDrivePath`, `GetWslDistros` (7.1) |
| Shared folders or WSL cause stalls | Whether `NodeHasChildren` and `SpecialIconIndex` touch the disk (7.3, 7.4) |
| Refresh loses the expanded state or selection | `RefreshKeepingState`, `NodeKey` (7.6, 7.2) |
| Returns to the initial state after docking/undocking | The conditions for building the top level in `CreateWnd` (`Items.Count = 0`, `FTopLevelDirty`; chapter 6) |
| `ShowNetwork` etc. changed while there was no window has no effect | Whether `RebuildTopLevel` set `FTopLevelDirty` and whether `CreateWnd` checked it (chapter 6, 7.1) |
| Setting `Path` does not select it | How `SetCPath` chooses the origin, hidden folders (7.2) |
| A rename reverts | Failure in `DoAsyncRename` (7.10) |
| Cannot drop from Explorer | `OleDropRegister` in `CreateWnd`, `OleResolveDrop` (chapter 6, 7.12) |
| Back/Forward buttons do not work | Whether a TCListView is connected to `ShellListView` (7.8) |
| Want to trace D&D behavior | `ShellDragTrace` in chapter 11 of the TCListView Design Document |

## 9. Changes in This Version (1.1)

Steps for changing the code. Not included in the user manual.

### 9.1 Now and After the Change

| No | Item | Current (1.0) behavior / problem | After the change (1.1) | Reason for the change | Risk |
|---|---|---|---|---|---|
| 1 | When the window is recreated (docking/undocking with AnchorDocking, changing the parent of a form) | `CreateWnd` rebuilds the top level with `BuildTopLevel` every time and deletes all items, so the expanded folders, selection and scroll position return to the initial state. The connected TCListView keeps showing the previous folder, so they disagree (confirmed with the AnchorDocking test application) | The top level is built only when there are no items (the first time) and when the display was switched while there was no window. Otherwise the items are left untouched (chapter 6) | So that, in an application whose functions are split into forms with AnchorDocking, the tree does not have to be expanded again after every docking/undocking | Folders that changed while the window was being recreated are not shown until the next notification or F5 |
| 2 | Switching the display while there is no window (`ShowQuickAccess`, `ShowOneDrive`, `ShowNetwork`, `ShowLinux`, `NetworkFolders`) | The rebuild is skipped and the next `CreateWnd` always rebuilds, so it is reflected | Set `FTopLevelDirty` and do `RefreshKeepingState(nil, True)` in the next `CreateWnd` (7.1) | To reflect the switch even though `CreateWnd` no longer rebuilds because of 1 | None |

### 9.2 What to Change

| No | File | Change |
|---|---|---|
| 1 | `CTreeView.pas` | Add the field `FTopLevelDirty` (chapter 4) |
| 2 | `CTreeView.pas` | Change `CreateWnd` as in chapter 6 |
| 3 | `CTreeView.pas` | In `RebuildTopLevel`, set `FTopLevelDirty := True` when there is no handle (7.1) |
| 4 | Other files | Unchanged |

- The published properties, methods and events are not changed.
