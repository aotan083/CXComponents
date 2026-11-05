# TCFileTree Design Document

Author: aotan083
Date: 2026-11-05
Version: 1.0

---

## 1. Purpose

A component that lines up folders and files in a single tree rooted at a specified folder (`RootPath`). It looks the same as the Explorer of VS Code and can be used without TCListView. Just by placing it on a form and connecting properties, the following work.

- Creating files and folders (New Folder, paste, drop from other applications), move, copy, delete, rename (mouse and keys).
- Drag and drop (inside the tree, and to and from other applications).
- Right-click menu (order in chapter 8).
- Open on double-click: `.url` goes to `TargetBrowser`; `.lnk` is sorted by what it points to, and text goes to `TargetEditor`. Other text goes to `TargetEditor`; anything that is not text uses the OS file association.
- When selected files are dragged and dropped onto TCMonacoEditor or TCsEditor, they open in new tabs, one per file (folders do nothing). This is the existing behavior of the editors, and this component adds nothing to them (7.10).
- The root is `RootPath` (default `C:\`). You cannot move to a folder above the root. To go higher, change `RootPath`.
- F5 brings the expanded folders up to date. Additions and removals made by other applications are also reflected automatically (a file created with "Save As" of an editor also appears).

Policy:

- File operations are left to the shell (Windows), and display updates are left to the monitoring of folder changes (how it is monitored: 7.5).
- There are no top-level groups (Quick Access, PC, Network, Linux). The root folder is the single top-level node.
- No code is required on the application side. The targets are set only by connecting components placed on the form with properties (no event is provided that would let the application do anything freely).
- TCTreeView and TCListView are not changed. This component is built as a separate component.

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `CFileTree.pas` | cx (runtime) | Types, `TCFileNode`, `TCFileTree` |
| `CShellMenu.pas`, `CShellDragDrop.pas`, `CShellOleDrop.pas`, `CShellOleDrag.pas` | cx (runtime) | Shared parts (existing; not changed). `CShellNotify.pas` is not used (7.5) |
| `uCFileTreeReg.pas` | cxdsgn (design time) | Registration to the [CX] palette |
| `cfiletree_icon.lrs` | cxdsgn (design time) | Icons (`TCFileTree`, `TCFileTree_150`, `TCFileTree_200`) |
| `uCXLang.pas` | cx | Added strings (chapter 10) |

- uses in interface: `Classes, SysUtils, Controls, ComCtrls, Windows, ActiveX, ShlObj, ShellAPI, Messages, Graphics, Dialogs, Forms, LMessages, ExtCtrls, Menus, CommCtrl, uCmonacos, uCsEditor, uCTabBrowser, SyncObjs, CShellMenu, CShellDragDrop, CShellOleDrop, CShellOleDrag`
- uses in implementation: `uCXLang, Clipbrd, IniFiles, LazUTF8`
- Declared as external: `StrCmpLogicalW` (shlwapi), `SHGetFileInfoW` and `SHGetSpecialFolderLocation` (shell32), `CoCreateInstance` (ole32), `ReadDirectoryChangesW` and `CancelIoEx` (kernel32). They are declared independently under their own names (not relying on the FPC declarations).
- The code that reads the target of a `.lnk` (the declarations of `IShellLinkW` and `IPersistFile`, and the same processing as `CBResolveLink`) and the code that reads the URL of a `.url` (the same processing as `CBReadUrlFile`) are written in the implementation of `CFileTree.pas` with the same content as in the implementation of `uCbookmark.pas` (`uCbookmark.pas` is not changed). The names are `FtResolveLink` and `FtReadUrlFile`. The code that makes a `file:///` URL from a file path is handled the same way (`FtPathToFileUrl`).
- There is no initialization or finalization.

## 3. Types and Constants

```pascal
TCFileNode = class(TTreeNode)
public
  IsDir: Boolean;         // True for a folder
  IconIndex: Integer;     // System icon index (valid when IconLoaded)
  IconLoaded: Boolean;
end;
```

- The `Text` of a node is the file name or folder name (without the parent's path). A node does not hold a path; it is built by following the parents in `GetPathFromNode` (so that the paths of children do not become stale after a rename).

| Constant | Value | Contents |
|---|---|---|
| `WM_CFT_WATCH` | `WM_USER + $5B3` | Notification "there was a change" from the monitoring thread to `TCFileTree` (7.5) |
| `CFtWatchBufBytes` | 65536 | Size of the monitoring buffer |
| `CFtMaxQueued` | 5000 | Upper limit of parent folders the monitoring thread keeps (if exceeded, everything is updated) |
| `CFtNewFirstId`, `CFtNewLastId` | `$8200`, `$BFFF` | Range of command IDs of "New" (does not overlap 1 to $7FFF of the item menu; 7.9) |
| `CFtMaxPending` | 200 | If update candidates exceed this, everything is updated |
| `CFtTextProbeBytes` | 8192 | Number of bytes read to check whether a file is text |
| `CFtHoverOpenMs` | 700 | Time, while dragging, to stay over the same folder before it opens automatically |
| `CFtMenuCount` | 17 | Number of right-click menu items (excluding separators) |

## 4. Fields

| Name | Type | Initial value | Contents |
|---|---|---|---|
| `FRootPath` | `string` | `C:\` | Root folder (no trailing separator; the drive root is `C:\`) |
| `FShowHidden` | `Boolean` | `False` | Show items with the hidden or system attribute |
| `FTargetEditor`, `FSideEditor` | `TControl` | nil | Target editors (`TCMonacoEditor` or `TCsEditor`) |
| `FTargetBrowser`, `FSideBrowser` | `TCTabBrowser` | nil | Target browsers |
| `FRootDirty` | `Boolean` | `False` | `RootPath` or `ShowHidden` was changed while there was no window (rebuild in the next `CreateWnd`) |
| `FIsRefreshing` | `Boolean` | `False` | Updating (do not run more than once at the same time) |
| `FWatcher` | `TCFtWatcher` | nil | Thread that monitors changes (the whole tree under the root; 7.5) |
| `FNotifyTimer` | `TTimer` | 300 ms, stopped | Thinning out notifications |
| `FPendingPaths` | `TStringList` | empty (case-insensitive, sorted, duplicates ignored) | Folders that may need an update |
| `FRefreshAll` | `Boolean` | `False` | Update all expanded folders |
| `FDragArmed`, `FDragStartPt`, `FDragButton` | | | Drag preparation (pressed button and position) |
| `FDragPaths` | `TStringList` | empty | Paths to drag (the selection at the time of the press) |
| `FClickPath` | `string` | '' | Path of an item in a multiple selection that was pressed without a modifier key (if released without moving, only that one is selected) |
| `FDropHilite` | `TTreeNode` | nil | Node around which a frame is drawn as the drop target |
| `FHoverNode`, `FHoverSince` | | | Node the mouse is over and the time it started, for opening automatically |
| `FDragTimer` | `TTimer` | 80 ms, stopped | Auto-scroll and auto-open while dragging |
| `FOleTarget` | `TCShellOleDropTarget` | nil | OLE drop target |
| `FOleDragOver` | `Boolean` | `False` | A drag from elsewhere is over this control |
| `FSysSmallImages` | `HIMAGELIST` | 0 | System small icon list |
| `FIconCache` | `TStringList` | empty (case-insensitive, sorted) | Extension to icon index (the index is put in `Objects`) |
| `FInFixSelection` | `Boolean` | `False` | While fixing the selection in `DoSelectionChanged` or restoring a multiple selection (do not re-enter) |
| `FMenu` | `TPopupMenu` | created | Right-click menu (chapter 8) |
| `FMenuItems` | `array[TCFtMenu] of TMenuItem` | created | Each item of the menu |
| `FMenuPos` | `TPoint` | | Screen position where the menu was shown (to show the `Windows Menu` at the same position) |
| `FNewFolderPath` | `string` | '' | Folder just created (to start editing its name) |

```pascal
TCFtMenu = (fmCopy, fmCut, fmPaste, fmRename, fmDelete, fmShowInExplorer, fmCopyPath,
  fmNewFolder, fmTextOpen, fmTextOpenNew, fmTextSide, fmWebOpen, fmWebOpenNew,
  fmWebSide, fmOpenProgram, fmShowHidden, fmWindowsMenu);
```

## 5. Declarations

```pascal
public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  function GetPathFromNode(ANode: TTreeNode): string;
  function IsRootNode(ANode: TTreeNode): Boolean;
  function IsDirNode(ANode: TTreeNode): Boolean;
  function SelectedPath: string;
  procedure GetSelectedPaths(APaths: TStrings);
  procedure CopySelected;
  procedure CutSelected;
  procedure PasteToSelected;
  procedure DeleteSelected(APermanent: Boolean = False);
  procedure RenameSelected;
  procedure NewFolder;
  procedure RefreshTree;
published
  property RootPath: string read FRootPath write SetRootPath;
  property ShowHidden: Boolean read FShowHidden write SetShowHidden default False;
  property TargetEditor: TControl read FTargetEditor write SetTargetEditor;
  property TargetBrowser: TCTabBrowser read FTargetBrowser write SetTargetBrowser;
  property SideEditor: TControl read FSideEditor write SetSideEditor;
  property SideBrowser: TCTabBrowser read FSideBrowser write SetSideBrowser;
protected
  procedure DoCreateNodeClass(var NewNodeClass: TTreeNodeClass); override;
  function CanExpand(Node: TTreeNode): Boolean; override;
  function CanEdit(Node: TTreeNode): Boolean; override;
  procedure DoSelectionChanged; override;
  function GetBuiltinIconSize: TSize; override;
  function DrawBuiltinIcon(ANode: TTreeNode; ARect: TRect): TSize; override;
  procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  procedure DoContextPopup(MousePos: TPoint; var Handled: Boolean); override;
  procedure DblClick; override;
  procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  procedure CreateWnd; override;
  procedure DestroyWnd; override;
  procedure WndProc(var Message: TLMessage); override;
  procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
  procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  procedure Paint; override;
```

- The base is `TCustomTreeView` (`TShellTreeView` is not used). Of the LCL standard properties and events, only the following are published.
  - Properties: `Align`, `Anchors`, `BorderSpacing`, `BorderStyle`, `Color`, `Constraints`, `Enabled`, `Font`, `Indent`, `ParentColor`, `ParentFont`, `ShowHint`, `Hint`, `TabOrder`, `TabStop`, `Visible`.
  - Events: `OnClick`, `OnDblClick`, `OnEnter`, `OnExit`, `OnKeyDown`, `OnKeyPress`, `OnKeyUp`, `OnMouseDown`, `OnMouseMove`, `OnMouseUp`, `OnMouseWheel`, `OnSelectionChanged`, `OnExpanded`, `OnCollapsed`.
  - `PopupMenu` is not published (the component has its own right-click menu).
- The component has no events of its own.
- `SelectedPath`: the path of `Selected`; '' if none. `GetSelectedPaths`: the paths of all selected items (only those in the same folder; 7.4).

## 6. Creating and Destroying

Create:

1. Add `tvoAllowMultiselect` to `Options`. `ReadOnly := False`, `ShowButtons := True`, `ShowLines := False`, `ShowRoot := True`, `RightClickSelect := False` (the selection for a right-click is done by the component itself in 7.9), `DragMode := dmManual`, `SortType := stNone` (the component does the ordering), `OnEdited := InternalOnEdited`.
2. The initial values of chapter 4 (`FRootPath := 'C:\'`). Create the two timers, `FPendingPaths`, `FIconCache`, and `FDragPaths`.
3. Create `FMenu` and line up the items of chapter 8.

Destroy: stop the timers -> `ShellDragAbandon(Self)` -> revoke the OLE drop target -> `StopWatch` -> `Application.RemoveAsyncCalls(Self)` -> free what was created -> `inherited`.

CreateWnd: after `inherited`, when not at design time:

1. Build the tree only in either of these cases: there are no items and `FRootPath` is not empty (when the window is first created), or `FRootDirty` (`FRootDirty := False`). -> `BuildTree`.
2. `StartWatch` and `OleDropRegister(Handle, OleResolveDrop, OleDropLeave, OleDropped)` (registered again every time the window is recreated; the monitoring thread's notification target is the window handle).

- In any other case (when the window is recreated by docking or undocking with AnchorDocking, etc.), the items are left untouched. The expanded state, selection, and scroll position remain (same as chapter 6 of the TCTreeView Design Document).

DestroyWnd: `StopWatch`, `OleDropRevoke`, `inherited`.

`DoCreateNodeClass`: after `inherited`, `NewNodeClass := TCFileNode`.

`Notification`: when the component set in `TargetEditor`, `TargetBrowser`, `SideEditor`, or `SideBrowser` is freed, set that property to nil.

## 7. Processing

### 7.1 Building the Tree and Changing the Root

`NormalizeRoot(P)`: '' if empty. Apply `ExpandFileName` and remove the trailing separator (the drive root `C:\` and `\\server\share` keep the separator).

| Procedure | Processing |
|---|---|
| `SetRootPath(P)` | If the `NormalizeRoot`ed value is the same as now, do nothing. Store it; if loading, at design time, or without a handle, set `FRootDirty := True` and finish (built in the next `CreateWnd`). Otherwise `BuildTree` and then `StartWatch` |
| `SetShowHidden(V)` | Store if changed. If loading or at design time, finish. Without a handle, `FRootDirty := True`. Otherwise `RefreshTree` (the expanded state and selection are kept) |
| `BuildTree` | Does nothing at design time. `Items.Clear` between `Items.BeginUpdate`. If `FRootPath` is empty or does not exist, finish as is (an empty tree). If it exists, add one root node (`IsDir := True`, `HasChildren := True`, `Text` is `ExtractFileName(FRootPath)`, or the whole path if that is empty). `Expand(False)` the root (the children are loaded in 7.2) |
| `RefreshTree` | `ApplyRefresh(nil, True)` (7.5). Brings all expanded folders up to date with the disk. Same as F5 (7.7). It also becomes up to date in places where change notifications do not arrive (such as a network) |

- You cannot move above the root: no node above the root is created in the tree. The drop target of drag and drop is also only inside the tree (an empty area is the root). To see a higher folder, change `RootPath`.
- When `RootPath` is empty or does not exist, the tree is empty (the default `C:\` exists, so it can be used as is).

### 7.2 Loading Children and Ordering

`ReadDirEntries(path, result folders, result files)`: read with `FindFirstFileW(ShellLongPathW(path + '\*'))`, excluding `.` and `..`. If `FShowHidden` is `False`, exclude those with `FILE_ATTRIBUTE_HIDDEN` or `FILE_ATTRIBUTE_SYSTEM`. Names are put in with `UTF8Encode(cFileName)`. Those with the directory attribute are folders, the rest are files. Each is sorted with `StrCmpLogicalW` (natural order). `False` if it cannot be read (access denied, etc.).

| Procedure | Processing |
|---|---|
| `CanExpand(N)` | For a folder of `TCFileNode`, when there are no children, `LoadChildren(N)`; if there are still no children, set `HasChildren := False` and return `False`. `False` for a file. Otherwise `inherited` |
| `LoadChildren(N)` | `ReadDirEntries(GetPathFromNode(N), ...)`. Between `Items.BeginUpdate`, `AddChild` in the order folders then files (folders get `IsDir := True` and `HasChildren := True`; files get `IsDir := False` and `HasChildren := False`). Exceptions are ignored |
| `MergeChildren(N)` | Match the contents of an expanded folder to the disk as it is now. Match the result of `ReadDirEntries` and the children of `N` by name (case-insensitive). Children that are not on the disk are deleted (with their descendants). Names that are missing are added. Finally, set the `Index` of each node in the order of the result (folders, then files). The remaining nodes keep their expanded state and selection as they are. If it cannot be read, delete all children and set `HasChildren := False` |
| `IsRootNode(N)` | `N <> nil` and `N.Parent = nil` |
| `IsDirNode(N)` | A `TCFileNode` with `IsDir` |

### 7.3 Paths and Search

| Procedure | Processing |
|---|---|
| `GetPathFromNode(N)` | '' for nil. The root is `FRootPath`. Otherwise the parent's path + a separator (if the parent's path does not end with one) + `N.Text` |
| `FindNodeByPath(path)` | From the root, look for each part of the path among the loaded children (case-insensitive). Levels that are not loaded cannot be found (nil) |
| `FolderPathOf(N)` | Destination folder for paste and create: for a folder, its own path; for a file, the parent's path; for nil, `FRootPath` |
| `SelectedPath` | `GetPathFromNode(Selected)` |
| `GetSelectedPaths(list)` | Put the paths of all selected nodes in visible order |

### 7.4 Selection (Only Within the Same Folder)

Only items in the same folder can be selected (because the shell's copy, move, delete, and drag and drop assume items in the same folder).

`DoSelectionChanged`: finish if `FInFixSelection`. Set `FInFixSelection := True` and deselect the selected nodes whose parent differs from that of `Selected` (when the parent of `Selected` is nil, deselect everything other than `Selected`). Restore it, then `inherited` (`OnSelectionChanged`).

### 7.5 Change Monitoring

The shell's change notification (`SHChangeNotifyRegister`) is not used. Changes directly under the root arrive, but changes inside subfolders do not (confirmed with the test application). Instead, the whole tree under the root, including subfolders, is monitored with `ReadDirectoryChangesW`.

`TCFtWatcher` (monitoring thread; `TThread`):

- `Create(root path, window handle)`: opens the root folder with `CreateFileW` (`FILE_LIST_DIRECTORY`, `FILE_SHARE_READ or WRITE or DELETE`, `FILE_FLAG_BACKUP_SEMANTICS`) and starts running immediately.
- `Execute`: until `Terminated`, repeat `ReadDirectoryChangesW(handle, 64 KB buffer, include subfolders, FILE_NOTIFY_CHANGE_FILE_NAME or FILE_NOTIFY_CHANGE_DIR_NAME)` (the wait is synchronous). Changes to file contents and dates are not received (they do not affect the display).
  - When it returns, read the `FILE_NOTIFY_INFORMATION` entries in order and keep the "parent folder" of `root + relative path` without duplicates (the place where children are added or removed). After keeping them, Post `WM_CFT_WATCH` (only once until the paths are taken).
  - When the buffer overflowed (returned with 0 bytes), the number kept exceeded `CFtMaxQueued` (5000), or reading failed 5 times in a row (the root was deleted or removed), set `FOverflow := True` (the receiving side updates everything) and Post.
- `TakePaths(list, overflow)`: takes the kept parent folders and empties the list, returning `FOverflow` (with locking).
- `Stop`: `Terminate`, cancel the pending read with `CancelIoEx`, and wait for the end of the thread (the cancel can hit before the read starts, so repeat until it ends).

`StartWatch`: stop the previous monitoring. Finish at design time, without a handle, or if `FRootPath` is empty or does not exist. `TCFtWatcher.Create(FRootPath, Handle)`. `StopWatch`: `Stop` and free.

`HandleWatch` (`WM_CFT_WATCH`):

1. `TakePaths`. If anything was missed, `FRefreshAll := True`.
2. Otherwise (if not `FRefreshAll`), add to `FPendingPaths` only those of the taken parent folders that `FindNodeByPath` finds (the loaded ones). Changes in folders that are not loaded are discarded (the latest is read when they are opened. Even if the root is large, like `C:\`, unrelated changes do not trigger updates).
3. If `CFtMaxPending` is exceeded, empty it and set `FRefreshAll := True`.
4. If there is anything, restart `FNotifyTimer`.

`NotifyTimerTick`: hold off while editing a name, during an LCL drag, while updating, during an in-application drag (`ShellDragIsActive`), or when a drag from elsewhere is over the control (so that the highlight of the drop target does not disappear). Stop the timer, take out and empty `FRefreshAll` and `FPendingPaths`, and call `ApplyRefresh(candidates, all)`.

- When a file is created in an open folder with "Save As" of an editor, that folder becomes a candidate through the monitoring and the file is shown (a closed folder reads the latest when opened). Files saved outside the root do not appear.

`ApplyRefresh(candidates, all)` (also called from `RefreshTree`; it does not hold off):

- Do nothing while updating or while being destroyed. `FIsRefreshing := True`, and between `Items.BeginUpdate`:
  - For all: collect the paths of the expanded folders from the top, and for each `FindNodeByPath` and `MergeChildren` (nodes that disappeared in an earlier update are skipped if not found). If the root does not exist, `BuildTree` (it becomes empty).
  - For candidates: `FindNodeByPath` each path, and for the folders found: if expanded, `MergeChildren`; if closed, delete the children and set `HasChildren := True` (the latest is read the next time it is opened).
- Exceptions are swallowed (they are retried by the next notification or F5). `FIsRefreshing := False`.

### 7.6 Icons

`DrawBuiltinIcon`: `inherited` if it is not a `TCFileNode`. Otherwise draw the index from `NodeIconIndex`, from `FSysSmallImages`, with `ImageList_Draw(..., ILD_TRANSPARENT)`, vertically centered in the frame. The size returns `GetBuiltinIconSize`. `GetBuiltinIconSize`: `GetSystemMetrics(SM_CXSMICON)` and `SM_CYSMICON`.

`NodeIconIndex(N)`: if already loaded, that index. Otherwise get it with `SHGetFileInfoW` (`SHGFI_SYSICONINDEX or SHGFI_SMALLICON`).

| Node | How to get it |
|---|---|
| Folder (including the root) | Name 'folder', with `FILE_ATTRIBUTE_DIRECTORY` and `SHGFI_USEFILEATTRIBUTES` (does not touch the disk). Remembered in '\folder' of `FIconCache` |
| `.exe`, `.ico`, `.lnk` | Path, attribute 0, without `SHGFI_USEFILEATTRIBUTES` (a per-file icon). Not cached |
| Other files | Look up `FIconCache` by extension ('' if none). If not found, get it with 'x' + extension, `FILE_ATTRIBUTE_NORMAL`, and `SHGFI_USEFILEATTRIBUTES`, and remember it |

If the return value (the image list handle) is not 0, put it in `FSysSmallImages` when that is 0, and use `iIcon` as the index. Remember the index and `IconLoaded := True` in the node.

### 7.7 Keys (KeyDown)

| Key | Processing |
|---|---|
| Ctrl+C, Ctrl+X, Ctrl+V | `CopySelected`, `CutSelected`, `PasteToSelected`, `Key := 0`, finish (do nothing while editing) |
| F2 | `RenameSelected`, `Key := 0` |
| Delete | `DeleteSelected(whether Shift is held)`, `Key := 0` |
| F5 | `RefreshTree` (brings all expanded folders up to date), `Key := 0` |
| Enter | If `Selected` is a file, `OpenNodeByDefault` of 7.9, `Key := 0`. A folder expands or collapses |

Finally `inherited KeyDown` (nothing if `Key = 0`). While editing a name, the keys are left to the edit box.

### 7.8 File and Folder Operations

| Procedure | Processing |
|---|---|
| `CopySelected` | Collect the paths of the selection. Finish if empty or if it includes the root. `ShellInvokeVerbOnItems(Handle, list, 'copy')` |
| `CutSelected` | The same condition, with `'cut'` |
| `PasteToSelected` | `ShellInvokeVerbOnFolder(Handle, FolderPathOf(Selected), 'paste')`. If no folder is selected, the parent of the selected file; if nothing is selected, the root |
| `DeleteSelected(permanent)` | Finish if empty or if it includes the root. `ShellInvokeVerbOnItems(Handle, list, 'delete', permanent)` (the shell shows the confirmation; goes to the Recycle Bin) |
| `RenameSelected` | If exactly one is selected and it is not the root, `Selected.EditText` |
| `CanEdit(N)` | `inherited`, and `True` if it is not the root |
| `InternalOnEdited(N, var S)` | If `S` is empty or the same as before, restore `S` and finish. If `ContainsInvalidChar(S)`, show `CXT(sFtErrBadChars)` + a line break + '\ / : * ? " < > \|' and restore. Otherwise, `New` a `TRenameInfo` (old path = `GetPathFromNode(N)`, new path = parent path + `S`, `ParentPath` = parent path) and `QueueAsyncCall(DoAsyncRename)` |
| `DoAsyncRename` | If not being destroyed, `ShellRenameItem(Handle, old, new name)`. If it fails (the shell shows the reason), add the parent to `FPendingPaths` and restart the timer to restore the display. Finally `Dispose` |
| `NewFolder` | The destination is `FolderPathOf(Selected)`. The name is `CXT(sBmNewFolder)`, with ' (2)', ' (3)' ... added until it does not exist yet. If `CreateDirectoryW(ShellLongPathW(path))` fails, show `Format(CXT(sFtErrCreateFolder), [path])` and finish. If it succeeds, `Expand(False)` the destination node, `MergeChildren`, select the created folder's node and `MakeVisible`, remember it in `FNewFolderPath`, and `QueueAsyncCall(DoAsyncEdit)` (starts editing the name) |
| `DoAsyncEdit` | Find the node of `FNewFolderPath` with `FindNodeByPath` and, if found, `EditText`. `FNewFolderPath := ''` |

`TRenameInfo` is declared separately in `CFileTree.pas` in the same form as in TCTreeView (`OldPath`, `NewPath`, `ParentPath`) (the names are `TFtRenameInfo` and `PFtRenameInfo`).

Updating the display is left to the monitoring (7.5).

### 7.9 Right-Click Menu and Opening

#### Opening with Double-Click (DblClick)

After `inherited`, if the node under the mouse (`ScreenToClient(Mouse.CursorPos)` and `GetNodeAt`) is a file, `OpenNodeByDefault`. A folder keeps the LCL expand/collapse.

`OpenNodeByDefault(N)`: path P, extension (lowercase) E.

| Condition | Action |
|---|---|
| E = '.url' | If `FtReadUrlFile(P)` is not empty, `OpenInBrowser(URL, displayed tab, TargetBrowser)` (`ShellExecuteW(P)` if `TargetBrowser` is nil). Nothing if empty |
| E = '.lnk' | `T := FtResolveLink(P)`. If it starts with 'http://' or 'https://', same as '.url'. If it is an existing text file and there is a `TargetEditor`, `OpenInEditor(T, displayed tab, TargetEditor)`. Otherwise `ShellExecuteW(P)` |
| Other | If `IsTextFile(P)` and there is a `TargetEditor`, `OpenInEditor(P, displayed tab, TargetEditor)`. Otherwise `ShellExecuteW(P)` (OS file association) |

- `ShellExecuteW(0, 'open', P, nil, working folder = parent, SW_SHOWNORMAL)`. If the return value is 32 or less, show `Format(CXT(sBmOpenError), [P + ' : ' + error number])`.
- Before opening, check `FileExists(P)`; if it does not exist, show `Format(CXT(sBmFileMissing), [P])` and do not open.

`IsTextFile(P)`: read the first `CFtTextProbeBytes` bytes of the file. `True` if the length is 0. `True` if it starts with a UTF-16 BOM (FF FE or FE FF). `False` if there is even one NUL (0x00), otherwise `True`. `False` if it cannot be read.

#### How to Open (Editor and Browser)

| Procedure | Processing |
|---|---|
| `OpenInEditor(P, new tab, E)` | `E` is a `TCMonacoEditor` or a `TCsEditor` (both have methods of the same names). Same behavior as `OpenInEditor` of TCBookmark: for a new tab, `E.OpenFile(P)` (switches to the tab if already open) and `SetFocus`. For the displayed tab: (1) if `E.FindPage(P)` is 0 or more, set `E.ActiveIndex` and `SetFocus`. (2) If `E.Modified`, ask with `CXT(sBmUnsaved)`; if Yes, `E.OpenFile(P)`; if No, do not open. (3) Otherwise `E.LoadFromFile(P)` and `SetFocus`. On exception, show `Format(CXT(sBmOpenError), [P + ' : ' + message])` |
| `OpenInBrowser(URL, new tab, B)` | For a new tab, `B.Add(URL)`; for the displayed tab, `B.Add(URL)` when `B.Count = 0`, otherwise `B.Navigate(URL)`. On exception, `sBmOpenError` likewise |

- Calling `TCMonacoEditor` and `TCsEditor` separately is done with `E is TCMonacoEditor` / `E is TCsEditor` (`FindPage`, `ActiveIndex`, `Modified`, `OpenFile`, `LoadFromFile`, and `SetFocus` are each gathered in small procedures with two branches).

#### "Target" Properties

| Procedure | Processing |
|---|---|
| `SetTargetEditor(V)`, `SetSideEditor(V)` | Store only if `V` is nil, or is a `TCMonacoEditor` or a `TCsEditor`, and (if the other of `FTargetEditor` and `FSideEditor` is not nil) is of the same class as the other (otherwise the current value stays). Swap the free notifications |
| `SetTargetBrowser(V)`, `SetSideBrowser(V)` | Store, and swap the free notifications |

- Combinations that cross editor types (Monaco and TCsEditor) are not accepted.

#### Right-Click Menu

`DoContextPopup`: `Handled := True` (`PopupMenu` is not used). If there is a node under the mouse and it is not in the selection, clear the whole selection and select only that node (if it is in the selection, the selection is left as it is). If there is no node, clear the whole selection. Remember the screen position in `FMenuPos`, `UpdateMenuState`, `FMenu.PopUp(screen position)`.

`UpdateMenuState`: decided by the number of selected nodes n, whether they include the root, and the first node F (when n = 1).

| Item | Available when |
|---|---|
| Copy, Cut | n >= 1 and the root is not included |
| Paste | The clipboard has files (`CF_HDROP`) |
| Rename | n = 1 and not the root |
| Delete | n >= 1 and the root is not included |
| Show in Explorer | n >= 1 |
| Copy Path | n >= 1 |
| New Folder | Always (when `FRootPath` exists) |
| Open as Text, Open as Text in New Tab | n = 1 and a file, `FTargetEditor` exists, `TextTargetOf(P) <> ''` |
| Open Side by Side (text) | n = 1 and a file, `FSideEditor` exists, `TextTargetOf(P) <> ''` |
| Open as Web, Open as Web in New Tab | n = 1 and a file, `FTargetBrowser` exists, `WebUrlOf(P) <> ''` |
| Open Side by Side (Web) | n = 1 and a file, `FSideBrowser` exists, `WebUrlOf(P) <> ''` |
| Open with Associated Program | n = 1 and a file |
| Show Hidden Files | Always. `UpdateMenuState` sets `Checked := FShowHidden` |
| Windows Menu | n >= 1 |

`TextTargetOf(P)` (path of the file to open; '' if none): if E is '.lnk', the path of what `FtResolveLink(P)` returns when it is an existing text file, otherwise ''. If E is '.url', ''. Otherwise P when `IsTextFile(P)`.

`WebUrlOf(P)` (URL to open; '' if none): if E is '.url', `FtReadUrlFile(P)`. If E is '.lnk', the URL when the target starts with 'http://' or 'https://', otherwise ''. Otherwise `FtPathToFileUrl(P)`.

| Item | Action |
|---|---|
| Copy, Cut, Paste, Rename | The procedures of the same names in 7.8 |
| Delete | `DeleteSelected(False)` (to the Recycle Bin; the shell shows the confirmation). To delete permanently, Shift+Delete (7.7) |
| Show in Explorer | For a folder, `ShellExecuteW(0, 'open', path)`. For a file, `ShellExecuteW(0, 'open', 'explorer.exe', '/select,"' + path + '"')`. Done with the first node of the selection |
| Copy Path | Put the paths of the selection (including the root), one per line, into `Clipboard.AsText` (separated by line breaks if several) |
| New Folder | `NewFolder` |
| Open as Text | `OpenInEditor(TextTargetOf(P), False, FTargetEditor)` |
| Open as Text in New Tab | `OpenInEditor(TextTargetOf(P), True, FTargetEditor)` |
| Open Side by Side (text) | `OpenInEditor(TextTargetOf(P), True, FSideEditor)`. Before opening, `FSideEditor.Visible := True` |
| Open as Web | `OpenInBrowser(WebUrlOf(P), False, FTargetBrowser)` |
| Open as Web in New Tab | `OpenInBrowser(WebUrlOf(P), True, FTargetBrowser)` |
| Open Side by Side (Web) | `OpenInBrowser(WebUrlOf(P), True, FSideBrowser)`. Before opening, `FSideBrowser.Visible := True` |
| Open with Associated Program | `ShellExecuteW(P)` (OS file association; for a `.lnk`, the `.lnk` itself is executed) |
| Show Hidden Files | `ShowHidden := not FShowHidden` (through `SetShowHidden`. Re-reads the displayed folders while keeping the expanded state and selection). Whether the application saves this property and uses it next time is up to the application |
| Windows Menu | `DisplayShellContextMenu(list of selected paths, FMenuPos)` |

`DisplayShellContextMenu`: shows the same menu as right-clicking that item in Explorer. The contents differ between folders and files (for a file, "Open", "Edit with Notepad", "Open with", etc.; for a folder, "Expand", "Open in new tab", etc.), and items of applications registered on the PC, such as Git, VLC, TortoiseGit, and Code, also appear. It is the traditional full menu (`CMF_NORMAL` for `QueryContextMenu`), not the short menu of Windows 11. The processing is the same as `DisplayShellContextMenu` of TCTreeView (7.11 of the TCTreeView Design Document). The differences are as follows.

- The paths are not one but all the paths of the selection (in the same folder; 7.4). From the `IShellFolder` of the parent folder, make an array of the child PIDLs and pass it to `GetUIObjectOf(IID_IContextMenu)`.
- When the root is included, only the root (the parent is the parent folder of the root).
- The processing that adds own items (`ExtraMenuInsert`, `ExtraMenuClick`) is not used.
- Only when exactly one folder (including the root) is selected, the standard "New" is inserted. The item menu (`GetUIObjectOf`) has no "New"; it exists only in the background menu of the folder (confirmed with the test application). `AddNewSubmenu(menu, folder)`:
  1. Create an `IContextMenu` with `CoCreateInstance(CLSID_NewMenu {D969A300-E7FF-11D0-A93B-00A0C90F2719})`, and tell it the destination folder with `IShellExtInit.Initialize(PIDL of the folder, nil, 0)`.
  2. `QueryContextMenu(..., CFtNewFirstId = $8200, CFtNewLastId = $BFFF, CMF_NORMAL)` on an empty menu (does not overlap 1 to $7FFF of the item menu). Take out the first item that results ("New" and its submenu).
  3. Have the shell build the contents of the submenu (Folder, Shortcut, Text Document, etc.) before it is opened, with `IContextMenu2.HandleMenuMsg(WM_INITMENUPOPUP, submenu, 0)`.
  4. `RemoveMenu` (detach without destroying the submenu), and insert "New" and a separator before the last item (Properties) of the item menu.
  If the chosen command ID is `$8200` to `$BFFF`, `ShellInvokeMenuCommand(IContextMenu of New, Handle, ID - $8200, path of the folder)`. Otherwise it is a command of the item menu.
- With multiple selection or when a file is selected, "New" is not inserted (it does not appear in Explorer either).
- Submenus whose contents the shell builds when opened, such as "Send to" and "New", also work. This is because `TrackShellContextMenu` of the shared parts passes the menu messages (`WM_INITMENUPOPUP`, `WM_DRAWITEM`, `WM_MEASUREITEM`, `WM_MENUCHAR`) to the shell through `IContextMenu2/3`. This component only passes the `IContextMenu` obtained from `QueryContextMenu` as it is, and no other processing is needed.
- What "New" creates is made inside the selected folder. Created files and folders are shown by the monitoring (7.5). It was confirmed with the test application that they are created inside the selected folder and not in the parent.
- "Send to" sends all selected items (with multiple selection, all items in the same folder are in the `IContextMenu`).
- If the command name is 'rename', `RenameSelected`; 'delete' is left to the shell (`ShellInvokeMenuCommand`); others are also `ShellInvokeMenuCommand(..., parent path)`.

### 7.10 Drag and Drop

Sender:

1. `MouseDown`:
   - With the left button, without a modifier key, when the node at the pressed position is already in the selection and two or more are selected: do not call `inherited` (to keep the selection), `SetFocus`, and remember its path in `FClickPath`.
   - Otherwise: `inherited`, `FClickPath := ''`.
   - In both cases, with the left or right button, not editing, with a node at the pressed position, and not the root: `FDragArmed := True`, remember the button and position, and put the paths of the selection in `FDragPaths` (if the pressed node is not in the selection, just that one node).
2. `MouseMove`: stop if `FDragArmed` and the button has been released. When moved by `SM_CXDRAG` or `SM_CYDRAG` or more: `FDragArmed := False`, `FClickPath := ''`, `ShellDragBegin(Self, FDragPaths)`, `ShellDoDragDrop(Handle, FDragPaths, False, Effect)`, `ShellDragEnd`, `ReleaseCapture`.
3. `MouseUp`: `FDragArmed := False`. If `FClickPath` is not empty, clear the whole selection and select just that node, `FClickPath := ''`. `inherited`.

Receiver (`OleResolveDrop`):

1. '' without a handle. `FOleDragOver := True`, start `FDragTimer`.
2. The drop target is: the path of the node under the mouse if it is a folder, the parent's path if it is a file, or `FRootPath` if there is no node.
3. For a drag started within the application, '' if `ShellDecideDropEffect(ShellDragPaths, drop target, ShellDragKeyState) = cdeNone`.
4. If there is a drop target, `SetDropHilite` of the node of that folder (the parent node if over a file, nil if over nothing).

| Procedure | Processing |
|---|---|
| `OleDropLeave` | `FOleDragOver := False`, stop the timer, `FHoverNode := nil`, remove the frame |
| `OleDropped` | Does nothing (updating the display is left to the monitoring) |
| `SetDropHilite` | Store if changed and `Invalidate` |
| `Paint` | After `inherited`, if `FDropHilite` is visible, a 2 px frame in `clHighlight` around `DisplayRect(True)` |
| `DragTimerTick` | If not dragging, stop and remove the frame. Stop if the mouse is outside (with a margin of 20 px above and below). Within 20 px of the top or bottom edge, `WM_VSCROLL` (one line). If it stays over the node of the same folder for `CFtHoverOpenMs` and it is closed and has children, open it |

- Copying and moving of dropped files and folders is done by the shell (the OLE drop target). Operations that create files and folders (drop from other applications, paste) work the same way.

Dropping onto other components and applications:

- What is dragged is data in the same form as Explorer (a list of files). The behavior at the drop target is decided by the drop target.
- When dropped on TCMonacoEditor or TCsEditor, by the editor's existing behavior (`OpenDroppedFiles = True` by default), with `MultiDocument = True`, as many new tabs as the number of selected files are opened. Files that are already open switch to their tab. Folders are ignored. This component adds nothing to the editors.
- The editor only opens them and does not move the original files (even if the drop target returns "move", this component deletes nothing).

## 8. Order of the Right-Click Menu

| No. | Item (ID) | Text (Japanese / English) |
|---|---|---|
| 1 | `fmCopy` | コピー / Copy |
| 2 | `fmCut` | 切取り / Cut |
| 3 | `fmPaste` | 貼付け / Paste |
| 4 | `fmRename` | 名前の変更 / Rename |
| 5 | `fmDelete` | 削除 / Delete |
| | - separator - | |
| 6 | `fmShowInExplorer` | エクスプローラーで表示 / Show in Explorer |
| 7 | `fmCopyPath` | パスのコピー / Copy Path |
| | - separator - | |
| 8 | `fmNewFolder` | フォルダ作成 / New Folder |
| | - separator - | |
| 9 | `fmTextOpen` | text開く / Open as Text |
| 10 | `fmTextOpenNew` | text新規タブで開く / Open as Text in New Tab |
| 11 | `fmTextSide` | 横に並べて表示 / Open Side by Side |
| | - separator - | |
| 12 | `fmWebOpen` | Web開く / Open as Web |
| 13 | `fmWebOpenNew` | Web新規タブで開く / Open as Web in New Tab |
| 14 | `fmWebSide` | 横に並べて表示 / Open Side by Side |
| | - separator - | |
| 15 | `fmOpenProgram` | プログラムで開く / Open with Associated Program |
| | - separator - | |
| 16 | `fmShowHidden` | 隠しファイルを表示 / Show Hidden Files (with a check mark) |
| | - separator - | |
| 17 | `fmWindowsMenu` | windowsメニュー / Windows Menu |

- There are 6 separators. Items that cannot be used are grayed out (table in 7.9).
- No accelerator keys (`&`) are attached to the items.

## 9. Where to Look When Investigating Problems

| Symptom | Where to look |
|---|---|
| The tree is empty | Whether `RootPath` exists, `NormalizeRoot` and `BuildTree` (7.1) |
| Files do not appear / hidden files appear | The attribute check in `ReadDirEntries`, `ShowHidden` (7.2) |
| Expanding is slow | The size of the folder `LoadChildren` reads. Whether closed folders are being read (7.2, 7.5) |
| The display does not change when changed from outside | Whether monitoring was started with `StartWatch`, whether `HandleWatch` discards it (is it a loaded folder?), the hold-off conditions of `NotifyTimerTick` (7.5) |
| The expanded state or selection disappears on update | Whether `MergeChildren` is rebuilding (7.2) |
| It returns to the initial state after docking or undocking | The build condition in `CreateWnd` (chapter 6) |
| A multiple selection goes back to one | `DoSelectionChanged` (7.4), the handling of multiple selection in `MouseDown` (7.10) |
| The selection disappears on right-click | The selection handling in `DoContextPopup`. Whether `RightClickSelect` is `False` (chapter 6, 7.9) |
| A target item is grayed out | Whether `TargetEditor` and `SideEditor` are the same kind, `IsTextFile` (7.9) |
| Cannot drop from Explorer | `OleDropRegister` in `CreateWnd`, `OleResolveDrop` (chapter 6, 7.10) |
| "Send to" or "New" of the Windows Menu is empty or does not work | Whether the `IContextMenu` is passed to `TrackShellContextMenu` (whether obtaining `IContextMenu2/3` is not blocked), the working folder of `ShellInvokeMenuCommand` (7.9). When "New" is chosen with a folder selected, whether it is created inside that folder (not in the parent) |
| Dropping onto an editor does not open it | `OpenDroppedFiles` and `OnFileDrop` of the editor, the paths passed to `ShellDoDragDrop` (7.10). Whether a drop from Explorer opens it |
| A saved file does not appear | Whether the save location is under the root, whether the monitoring arrives (`TCFtWatcher`, `HandleWatch`), the hold-off conditions of `NotifyTimerTick` (7.5). In places where it does not arrive, F5 |
| A rename goes back | A failure in `DoAsyncRename`, the checks in `InternalOnEdited` (7.8) |
| Wrong icon | The per-extension cache in `NodeIconIndex` (7.6) |
| Want to trace drag and drop | `ShellDragTrace` in chapter 11 of the TCListView Design Document |

## 10. Strings (Added to uCXLang.pas)

Add the following in this order at the end of `TCXStr` (after `sBmHtmlFilter`). Add them to `CXTable` in the same order. The order of `%` is the same in Japanese and English.

| ID | Japanese | English |
|---|---|---|
| `sFtMenuCopy` | コピー | Copy |
| `sFtMenuCut` | 切取り | Cut |
| `sFtMenuPaste` | 貼付け | Paste |
| `sFtMenuRename` | 名前の変更 | Rename |
| `sFtMenuDelete` | 削除 | Delete |
| `sFtMenuShowInExplorer` | エクスプローラーで表示 | Show in Explorer |
| `sFtMenuCopyPath` | パスのコピー | Copy Path |
| `sFtMenuNewFolder` | フォルダ作成 | New Folder |
| `sFtMenuTextOpen` | text開く | Open as Text |
| `sFtMenuTextOpenNew` | text新規タブで開く | Open as Text in New Tab |
| `sFtMenuSide` | 横に並べて表示 | Open Side by Side |
| `sFtMenuWebOpen` | Web開く | Open as Web |
| `sFtMenuWebOpenNew` | Web新規タブで開く | Open as Web in New Tab |
| `sFtMenuOpenProgram` | プログラムで開く | Open with Associated Program |
| `sFtMenuShowHidden` | 隠しファイルを表示 | Show Hidden Files |
| `sFtMenuWindowsMenu` | windowsメニュー | Windows Menu |
| `sFtErrBadChars` | ファイル名・フォルダー名に以下の文字は使用できません: | The following characters cannot be used in a file or folder name: |
| `sFtErrCreateFolder` | フォルダーを作れませんでした：%s | Could not create the folder: %s |

- Existing strings that are used: `sBmUnsaved` (confirmation of unsaved changes), `sBmOpenError` (could not open), `sBmFileMissing` (the file does not exist), `sBmNewFolder` (the name of a new folder).
- `fmTextSide` and `fmWebSide` use the same text (`sFtMenuSide`).

## 11. Files to Change

| No. | File | Change |
|---|---|---|
| 1 | `source\CFileTree.pas` | New. Chapters 2 to 7 (created) |
| 2 | `source\design\uCFileTreeReg.pas` | New. Registers `TCFileTree` on the [CX] palette. Loads the icons `cfiletree_icon.lrs` (`tcfiletree`, `tcfiletree_150`, `tcfiletree_200`) (same form as `uCbookmark_reg.pas`) (created) |
| 3 | `source\res\cfiletree_icon.lrs` | New (created; made with `lazres` from PNGs of 24, 36, and 48 px. The picture is provisional. To replace it, rebuild from PNGs of the same names) |
| 4 | `source\uCXLang.pas` | Add the strings of chapter 10 |
| 5 | `packages\cx.lpk`, `packages\cx.pas` | Add `CFileTree` (created) |
| 6 | `packages\cxdsgn.lpk`, `packages\cxdsgn.pas` | Add `uCFileTreeReg` and `cfiletree_icon.lrs` (created) |
| 7 | `docs\CXLang_Design.md` | Add the strings of chapter 10 to the table in chapter 5 |
| 8 | Other files | No change (`CTreeView.pas`, `CListView.pas`, `uCbookmark.pas`, and the shared parts are not changed) |

- The test specification is a separate document (`docs\test_docs\TCFileTree_Test.md`). The user manual is `docs\TCFileTree_Usage.md`.
