# TCListView Design Document

Author: aotan083
Date: 2026-10-31
Version: 1.1

---

## 1. Purpose

Based on TShellListView (LCL), build a file list that works like the right-hand pane of Windows Explorer. Just placing it on a form should give you open, copy, move, delete, rename, create new, drag & drop, context menu, automatic refresh, and back/forward.

- File operations (copy, move, delete, rename, paste, drop) are left to the shell (Windows) as much as possible. Overwrite confirmation and progress display are also handled by the shell.
- Display refresh relies on folder change notifications (the component does not re-read by itself after an operation).
- State changes (folder, selection) are reported once each, batched at idle time.

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `CListView.pas` | cx (runtime) | `TCItemInfo`, `TCListView`, `BuildRenamedPath` |
| `CShellNotify.pas` | cx (runtime) | Shell change notifications (Chapter 9) |
| `CShellMenu.pas` | cx (runtime) | Shell command execution, context menu, custom items, rename (Chapter 10) |
| `CShellDragDrop.pas` | cx (runtime) | In-app drag information, drop prohibition checks, logging (Chapter 11) |
| `CShellOleDrop.pas` | cx (runtime) | OLE drop target side (Chapter 12) |
| `CShellOleDrag.pas` | cx (runtime) | OLE drag source side (Chapter 13) |
| `uCXReg.pas` | cxdsgn (design time) | Registration on the [CX] palette (`RegisterComponents('CX', [TCTreeView, TCListView, ...])`) |
| `cx_icons.lrs` | cxdsgn (design time) | Icons (`TCListView`, `TCListView_150`, `TCListView_200`) |

- The shared parts in Chapters 9 to 13 are also used by TCTreeView. The TCTreeView design document refers to them here.
- uses of `CListView`: `Classes, SysUtils, Controls, ComCtrls, ShellCtrls, Windows, ActiveX, ShlObj, ShellAPI, Messages, Graphics, Dialogs, Forms, Clipbrd, LMessages, LazUTF8, ExtCtrls, CommCtrl, Menus, CShellNotify, CShellMenu, CShellDragDrop, CShellOleDrop, CShellOleDrag`
- For natural-order comparison, declare `StrCmpLogicalW` from `shlwapi.dll` as external and use it.
- `CListView` has no initialization or finalization.

## 3. Types

```pascal
TCItemInfo = class
public
  IsDir: Boolean;
  DateStr: string;   // Modified date/time (YYYY/MM/DD HH:NN)
end;

TCListView = class(TShellListView)

function BuildRenamedPath(const AOldPath, ADisplayName, ANewName: string): string;
```

`BuildRenamedPath`: the folder of `OldPath` (without the trailing separator) + `ANewName`. For a folder, that is the result as is. For a file that has an extension, whose display name differs from the real file name, and whose display name equals the real file name without the extension, the original extension is appended (when the setting is not to show extensions).

## 4. Fields

| Name | Type | Initial value | Contents |
|---|---|---|---|
| `FOnFolderChanged`, `FOnSelectionChanged` | `TNotifyEvent` | nil | Events |
| `FLastRoot` | `string` | '' | `Root` at the time of the previous notification |
| `FSelectionDirty` | `Boolean` | `False` | Waiting to report a selection change |
| `FSortColumn` | `Integer` | 2 | Sort column (0 Name, 1 Size, 2 Type, 3 Date modified) |
| `FSortAscending` | `Boolean` | `True` | Ascending |
| `FInResize` | `Boolean` | `False` | Column widths are being adjusted |
| `FColumnResizePending` | `Boolean` | `False` | Column width adjustment is already scheduled |
| `FSortPending` | `Boolean` | `False` | Sorting is already scheduled |
| `FLastColWidths` | `array[0..3] of Integer` | -1 | Column widths last set by auto-fit (used to detect manual changes) |
| `FUserSizedColumns` | `Boolean` | `False` | The user changed column widths by hand |
| `FNotifyRootID`, `FNotifyParentID` | `ULONG` | 0 | Change notification registration IDs (directly under `Root`, parent of `Root`) |
| `FNotifyRoot` | `string` | '' | The `Root` for which notifications are registered |
| `FNotifyTimer` | `TTimer` | 300ms, stopped | Throttling of notifications |
| `FSelectNewItems` | `Boolean` | `False` | Select newly appeared items on the next re-read |
| `FDragArmed` | `Boolean` | `False` | A button was pressed on an item |
| `FDragButton` | `TMouseButton` | | The button that started the drag |
| `FDragStartPt` | `TPoint` | | Position where the button was pressed |
| `FDropHilite` | `TListItem` | nil | Item drawn with a frame as the drop target |
| `FDragTimer` | `TTimer` | 80ms, stopped | Auto-scroll during a drag |
| `FOleTarget` | `TCShellOleDropTarget` | nil | OLE drop target |
| `FOleDragOver` | `Boolean` | `False` | A drag from elsewhere is over the control |
| `FPendingChanges` | `TStringList` | empty | Changes applied row by row (string = path 1 + #1 + path 2, Objects = event) |
| `FNeedFullRefresh` | `Boolean` | `False` | There was a change that cannot be applied row by row |
| `FItemInfo` | `TStringList` | empty (case-insensitive, duplicates ignored, holds Objects) | Name -> `TCItemInfo` |
| `FItemInfoRoot` | `string` | '' | `Root` at the time `FItemInfo` was built |
| `FHistory` | `TStringList` | empty | Folder history (oldest first) |
| `FHistIndex` | `Integer` | -1 | Current position in the history |
| `FHistSkip` | `string` | '' | Folder being moved to by back/forward (not added to the history) |
| `FMaxHistory` | `Integer` | 20 | History limit |
| `FInXButton` | `Boolean` | `False` | `WM_XBUTTONUP` is being processed |
| `FExtraItemMenu`, `FExtraBackgroundMenu` | `TPopupMenu` | nil | Items added to the context menu |
| `FExtraMenuPosition` | `TCExtraMenuPosition` | `empBottom` | Position of the added items |
| `FLastViewStyle` | `TViewStyle` | `vsReport` | The view style checked last time |

## 5. Declarations

```pascal
public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  function NavigateTo(const APath: string): Boolean;
  function NavigateUp: Boolean;
  procedure DeleteSelectedFiles(APermanent: Boolean = False);
  procedure CopySelected;
  procedure CutSelected;
  procedure PasteToRoot;
  procedure SelectAllItems;
  procedure RenameSelectedFile;
  function GetSelectedFilePath: string;
  procedure GetSelectedPaths(AList: TStrings);
  property AutoFitNameColumn: Boolean read GetAutoFitNameColumn write SetAutoFitNameColumn;
  procedure SelectNewItemsOnNextRefresh;
  function GoBack: Boolean;
  function GoForward: Boolean;
  function CanGoBack: Boolean;
  function CanGoForward: Boolean;
  procedure ClearHistory;
  procedure SetView(AStyle: TViewStyle);
  procedure SortBy(AColumn: Integer; AAscending: Boolean);
  property SortColumn: Integer read FSortColumn;
  property SortAscending: Boolean read FSortAscending;
  property MaxHistory: Integer read FMaxHistory write SetMaxHistory;
published
  property ExtraItemMenu: TPopupMenu read FExtraItemMenu write SetExtraItemMenu;
  property ExtraBackgroundMenu: TPopupMenu read FExtraBackgroundMenu write SetExtraBackgroundMenu;
  property ExtraMenuPosition: TCExtraMenuPosition read FExtraMenuPosition write FExtraMenuPosition default empBottom;
  property OnFolderChanged: TNotifyEvent read FOnFolderChanged write FOnFolderChanged;
  property OnSelectionChanged: TNotifyEvent read FOnSelectionChanged write FOnSelectionChanged;
protected
  procedure DoContextPopup(MousePos: TPoint; var Handled: Boolean); override;
  procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  procedure DblClick; override;
  procedure Resize; override;
  procedure DoSelectItem(AItem: TListItem; ASelected: Boolean); override;
  procedure CreateWnd; override;
  procedure DestroyWnd; override;
  procedure WndProc(var Message: TLMessage); override;
  procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
  procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
```

## 6. Creation and Destruction

Create:

1. `ReadOnly := True`, `DragMode := dmManual` (the component starts drags itself), `ViewStyle := vsReport`, `MultiSelect := True`.
2. `AutoSizeColumns := False` (stops the base class's automatic column width adjustment. On every Resize the base class resets the column widths using a width that includes the scrollbar, so when a vertical scrollbar is present the horizontal scrollbar appears and disappears, Resize loops, and it also fights with our own adjustment, causing flicker).
3. `ObjectTypes := [otFolders, otNonFolders]`, `OnEdited := InternalOnEdited`, `OnColumnClick := DoColumnClick`, `OnAddItem := DoAddItemHandler`.
4. `FSortColumn := 2`, `FSortAscending := True`, `FLastViewStyle := vsReport`, `IconOptions.AutoArrange := True`.
5. Columns: set the headings of 0 to 2 to "Name", "Size", "Type", and add a fourth, "Date modified" (width 140, left-aligned).
6. Create the fields from Chapter 4 and set their initial values.
7. `Application.AddOnIdleHandler(InternalAppIdle)` (writes to `Root` are not virtualized in the base class, so changes are detected at idle time).

Destroy: stop the timers -> `ShellDragAbandon(Self)` -> unregister the OLE drop target -> `UnregisterFolderNotify` -> `Application.RemoveAsyncCalls(Self)` -> `RemoveOnIdleHandler` -> `inherited` -> free `FItemInfo`, `FPendingChanges`, `FHistory`.

CreateWnd: after `inherited`, enable `LVS_EX_DOUBLEBUFFER` ($00010000) with `LVM_SETEXTENDEDLISTVIEWSTYLE` (using the Windows list view's own mechanism, not LCL's `DoubleBuffered`). `RegisterFolderNotify`. Unless at design time, `OleDropRegister(Handle, OleResolveDrop, OleDropLeave, OleDropped)`.

DestroyWnd: `UnregisterFolderNotify`, `OleDropRevoke`, `inherited`.

## 7. Processing

### 7.1 Reporting State Changes (CheckStateChanged)

Called from `InternalAppIdle` (`Done` is not changed). Does nothing at design time or while being destroyed.

1. `Root` differs from `FLastRoot` (trailing separator ignored): `FLastRoot := Root`, `RecordHistory(Root)`, `FSelectionDirty := True`, stop `FNotifyTimer` and `RegisterFolderNotify` (move the watch to the new folder), `OnFolderChanged`.
2. `ViewStyle` differs from `FLastViewStyle`: remember it again, `QueueAsyncCall(DoAsyncRefresh)` (rebuild because the icon size changes). If it became the report view, also schedule a column width adjustment.
3. If `FSelectionDirty`, reset it and call `OnSelectionChanged`.

- `DoSelectItem`: after `inherited`, `FSelectionDirty := True` (it is called once per item in a multi-selection, so only a flag is raised).

### 7.2 Navigation

| Procedure | Processing |
|---|---|
| `NavigateTo(P)` | `False` if `P` is empty, does not exist, or is the same as the current one. `Root := P`, `True` (events are in 7.1) |
| `NavigateUp` | The parent of `Root`. `False` if it is a drive root. `NavigateTo(parent)` |
| `NavigateToExistingParent` | Walk up from `Root` to its parents and `NavigateTo` the first existing folder. Does nothing if none can be reached |

### 7.3 History

| Procedure | Processing |
|---|---|
| `RecordHistory(P)` | Remove the trailing separator. Finish if empty. If equal to `FHistSkip`, clear it and finish (the move was made by back/forward). Finish if equal to the current position. Discard everything after the current position, append to the end, delete from the start if the limit is exceeded, and set `FHistIndex` to the end |
| `HistoryGo(d)` | Search from `i := FHistIndex + d` in the direction of `d`. If a folder exists and differs from the current one: `FHistIndex := i`, `FHistSkip := that folder`, `Root := that folder`, `True`. Entries that do not exist or are the same as the current one are removed from the history and the search continues (when going back, `FHistIndex` is also decreased by 1) |
| `GoBack`, `GoForward` | `HistoryGo(-1)`, `HistoryGo(+1)` |
| `CanGoBack` | `FHistIndex > 0` |
| `CanGoForward` | `0 <= FHistIndex < FHistory.Count - 1` |
| `ClearHistory` | Empty it, then `RecordHistory(Root)` |
| `SetMaxHistory(v)` | 2 if less than 2. Delete the excess from the start and adjust `FHistIndex` |

### 7.4 Mouse Back/Forward Buttons (WndProc)

`XButtonDirection(Msg, WParam, LParam)`: for `WM_XBUTTONUP` ($020C), -1 if the high word of WParam is 1 or `MK_XBUTTON1` ($20), +1 if it is 2 or `MK_XBUTTON2` ($40). For `WM_APPCOMMAND` ($0319), the high word of LParam `and $0FFF` gives -1 for `APPCOMMAND_BROWSER_BACKWARD` (1) and +1 for `APPCOMMAND_BROWSER_FORWARD` (2).

- `WM_APPCOMMAND`: unless `FInXButton`, `GoBack`/`GoForward`. `Result := 1`.
- `WM_XBUTTONUP`: call `inherited` with `FInXButton := True` (the default processing sends `WM_APPCOMMAND`, so this avoids doing it twice), then `GoBack`/`GoForward`, `Result := 1`.

In addition, WndProc handles `CM_CSTARTDRAG` (`WM_USER + $5A2`) with `StartOleDrag`, `WM_PAINT` with `inherited` followed by `DrawDropFrame` if there is an `FDropHilite`, and `WM_CSHELLNOTIFY` with `HandleShellNotify`.

### 7.5 Change Notifications

`RegisterFolderNotify`: unregister the previous registration. Finish at design time, with no handle, or if `Root` is empty or does not exist. `FNotifyRoot := Root`.

- Register directly under `Root` (subfolders not included) for `CREATE, DELETE, MKDIR, RMDIR, RENAMEITEM, RENAMEFOLDER, UPDATEDIR, UPDATEITEM, ATTRIBUTES`.
- Deletion or renaming of `Root` itself arrives as a change of its parent, so register the parent (if it is not a root) for `RMDIR, RENAMEFOLDER, DELETE`.

`HandleShellNotify`:

1. Extract the event and the two paths with `ShellNotifyDecode`. Finish if being destroyed.
2. Discard it if neither path is `Root` itself or directly under `Root`.
3. For deletion, rename, or content update (`DELETE, RMDIR, RENAMEITEM, RENAMEFOLDER, UPDATEITEM, ATTRIBUTES`): if path 1 is `Root` itself, `FNeedFullRefresh := True`; otherwise add it to `FPendingChanges`. For any other event (such as creation), `FNeedFullRefresh := True`.
4. If `FPendingChanges` exceeds 100, `FNeedFullRefresh := True`.
5. Restart `FNotifyTimer` (fires once, 300ms after the last notification).

`NotifyTimerTick`:

1. While a name is being edited, during an LCL drag, during an in-app drag, or while a drag from elsewhere is over the control, defer (do not stop the timer; judge again on the next cycle).
2. Stop the timer. Finish if being destroyed.
3. If `Root` no longer exists, discard the pending items and `NavigateToExistingParent`.
4. If `FNeedFullRefresh`, discard the pending items and `DoAsyncRefresh(0)`.
5. If there are `FPendingChanges`, `ApplyPendingChanges`.

`ApplyPendingChanges` (within `Items.BeginUpdate`, process the pending items in order):

| Event | Processing |
|---|---|
| Delete (`DELETE`, `RMDIR`) | If path 1 is directly under `Root`, delete the row with that name (set `FDropHilite` to nil if it is that row) |
| Rename, both directly under `Root` | If a row with the old name exists and no row with the new name exists, change `Caption`; if the new one exists, re-read everything. If there is no row with the old name and also none with the new name, re-read everything (if one exists, it was already changed by a name edit, so do nothing) |
| Rename, only path 1 directly under `Root` | Moved elsewhere (including the Recycle Bin): delete that row |
| Rename, came from elsewhere | Re-read everything (icons and so on must be created) |
| Content update (`UPDATEITEM`, `ATTRIBUTES`) | If path 1 is directly under `Root` and the row exists, get the size again with `FindFirstFileW` and put it in `SubItems[0]` (except for folders). If there is no row, re-read everything |
| Other | Re-read everything |

When a full re-read is needed, stop there and call `DoAsyncRefresh(0)`. If it reaches the end, `PopulateFileDateTimes`, `ApplySort`, `FSelectionDirty := True`.

- The row search `FindItemByName` compares `Caption` case-insensitively.
- The size notation `FormatShellSize`: '%d bytes' below 1024, '%d kB' below 1MB, '%d MB' below 1GB, otherwise '%.1n GB' (same format as TShellListView).

### 7.6 Re-reading (DoAsyncRefresh)

Does nothing if there is no handle or while being destroyed.

1. Take out `SelectNew := FSelectNewItems` and reset it. Discard the pending items. Remember the current `FSelectionDirty`.
2. Remember the paths of all selected items, the path of the focused item, and the path of the item visible at the top (`TopItem`). If `SelectNew`, also remember the paths of all current items.
3. Within `WM_SETREDRAW(False)`, empty `Root` and then restore it to re-read (`Refresh` if `Root` is empty). `PopulateFileDateTimes`, `ApplySort`.
4. If `SelectNew`, replace the paths to select with "items that did not exist before", and empty the focus path.
5. Select the items at the paths to select and restore the focused item (if `SelectNew`, focus the first item selected).
6. If not `SelectNew` and the number restored is the same as before, restore `FSelectionDirty` to the remembered value (do not raise `OnSelectionChanged` if the selection did not change).
7. Scroll position: if `SelectNew`, make the focused item visible. Otherwise, first make the end visible and then make the previous top item visible (so that item comes to the top).
8. `WM_SETREDRAW(True)`, `RedrawWindow(RDW_INVALIDATE or RDW_ALLCHILDREN or RDW_UPDATENOW)`.

### 7.7 Item Information and Sorting

| Procedure | Processing |
|---|---|
| `RebuildItemInfo` | Empty `FItemInfo` and set `FItemInfoRoot := Root`. Enumerate `Root` just once with `FindFirstFileW` (long paths supported through `ShellLongPathW`), skip '.' and '..', and put whether it is a folder and the modified date/time (local time, '%.4d/%.2d/%.2d %.2d:%.2d') into a `TCItemInfo`. Finally `Sorted := True` (so binary search works) |
| `FindItemInfo(name)` | Rebuild if `FItemInfoRoot` differs from the current `Root`. Search by name and return it; nil if not found |
| `PopulateFileDateTimes` | After `RebuildItemInfo`, make `SubItems` of every item at least 3 entries long; if there is information, then for a folder whose type is empty or 'ファイル フォルダー', set it to 'フォルダ', and re-enter the modified date/time if it differs |
| `CompareItems(A, B)` | Folders first, by whether it is a folder (`DirectoryExists` if there is no information). For column 0, compare names with `StrCmpLogicalW`. Otherwise compare `SubItems[column - 1]` with `StrCmpLogicalW`, and by name if equal. Reverse the sign for descending |
| `ApplySort` | `CustomSort(SortCompareProc, Self)` (`SortCompareProc` calls `CompareItems`) |
| `DoAddItemHandler` | `CanAdd := True`. Schedule sorting if not already scheduled (`QueueAsyncCall(DoAsyncSort)`; so as not to sort per item) |
| `DoAsyncSort` | Reset the schedule flag, `PopulateFileDateTimes`, `ApplySort` |
| `DoColumnClick(column)` | If the same column, toggle ascending/descending; if a different column, ascending on that column. `ApplySort` |
| `SortBy(column, ascending)` | Does nothing unless the column is 0 to 3. Store them and `ApplySort` |
| `SetView(v)` | Does nothing if the same. `ViewStyle := v` (the rebuild is in 7.1) |

### 7.8 Column Widths

- `Resize`: after `inherited`, if not at design time, there are 4 or more columns, the view is the report view, and nothing is already scheduled, `QueueAsyncCall(DoAsyncColumnResize)` (doing it synchronously conflicts with the Windows header's internal processing and interferes with resizing during a TSplitter drag. Even if Resize continues because scrollbars appear and disappear, it is consolidated into one).
- `DoAsyncColumnResize`: reset the schedule flag. Does nothing if adjusting, fewer than 4 columns, being destroyed, not the report view, or `FUserSizedColumns`. If even one of the previously set column widths (`FLastColWidths`) differs from the current width, treat it as changed by the user, set `FUserSizedColumns := True`, and finish. Name column width = `ClientWidth - (column 1 + column 2 + column 3) - 4` (leave 4, because an exact fit makes a horizontal scrollbar appear and loops. Minimum 60). Set it only if different, and remember the widths of the 4 columns in `FLastColWidths`.
- `AutoFitNameColumn` reads as `not FUserSizedColumns`. Writing `True` resets `FLastColWidths` to -1 and, if there is a handle, schedules an adjustment.

### 7.9 Open, Rename, Create New

| Procedure | Processing |
|---|---|
| `DblClick` | If there is an `OnDblClick`, only `inherited`. Otherwise, for the focused item (or the item under the mouse if none): `NavigateTo` if a folder, `ShellExecuteW('open')` if a file. If the return value is 32 or less, show 'Could not open the file. Error code: %d'. Finally `inherited` |
| `RenameSelectedFile` | If there is a selection, `ReadOnly := False`, `EditCaption` |
| `InternalOnEdited` | `ReadOnly := True`. Finish if empty. If `ContainsInvalidChar`, show 'The following characters cannot be used in a file name:' + line break + '\ / : * ? " < > \|' and revert. The old path is the item's actual path (not the display name), and the new path is from `BuildRenamedPath`. If they differ, create a `TListRenameJob` (old path, new name) and `QueueAsyncCall(DoAsyncRename)` (so it does not conflict with the end-of-name-editing processing) |
| `DoAsyncRename` | Unless being destroyed, `ShellRenameItem`. On failure (the shell shows the reason), `DoAsyncRefresh(0)` to restore the display. Updating the display on success is left to change notifications |
| `CreateNewFolderInRoot` | `CreateDir` in `Root` with the first free name among 'New folder', 'New folder (2)', (3)... Returns the path created |
| `CreateNewFileInRoot(extension)` | Likewise, creates an empty file named 'New Text Document' + extension (with ' (n)' if needed) |
| `FocusAndRenamePath(P)` | Re-read with `DoAsyncRefresh(0)`, select the item for `P`, focus it, make it visible, `ReadOnly := False`, `EditCaption` |

### 7.10 Keys (KeyDown)

| Key | Processing |
|---|---|
| BackSpace (without Shift) | If `NavigateUp` is `True`, `Key := 0` |
| Enter (without Shift) | `DblClick`, `Key := 0` |
| Ctrl+Shift+N | `CreateNewFolderInRoot`, then `FocusAndRenamePath` if created, `Key := 0` |
| Ctrl+Shift+2, 4, 5, 6 | `SetView(vsIcon, vsSmallIcon, vsList, vsReport)`, `Key := 0` |
| Ctrl+A | `SelectAllItems`, `Key := 0` |
| Ctrl+C, Ctrl+X, Ctrl+V | `CopySelected`, `CutSelected`, `PasteToRoot`, `Key := 0` |
| F5 | `QueueAsyncCall(DoAsyncRefresh)`, `Key := 0` |
| F2 | `RenameSelectedFile`, `Key := 0` |
| Delete | `DeleteSelectedFiles(whether Shift is held)`, `Key := 0` |

Finally `inherited KeyDown`.

### 7.11 File Operations

| Procedure | Processing |
|---|---|
| `CopySelected`, `CutSelected` | If `GetSelectedPaths` has entries, `ShellInvokeVerbOnItems(Handle, list, 'copy' / 'cut')` |
| `PasteToRoot` | If there is a `Root`, `SelectNewItemsOnNextRefresh`, `ShellInvokeVerbOnFolder(Handle, Root, 'paste')` (for the same folder the shell makes it "... - Copy") |
| `DeleteSelectedFiles(permanent)` | Join all selected paths with #0 and call `PerformFileOperation(FO_DELETE, ..., '', not permanent)` |
| `PerformFileOperation` | `SHFILEOPSTRUCTW` (the W version, for Japanese paths). Source and destination end with #0#0. `FOF_RENAMEONCOLLISION`, and also `FOF_ALLOWUNDO` when sending to the Recycle Bin. A confirmation is shown even for permanent deletion |
| `SelectAllItems` | Select all items |
| `GetSelectedFilePath` | Path of the first selected item ('' if none) |
| `GetSelectedPaths(L)` | Empty `L` and put in the paths of all selected items |
| `SelectNewItemsOnNextRefresh` | `FSelectNewItems := True` |

All display refreshing is left to change notifications.

### 7.12 Context Menu

`DoContextPopup`: if there is an item under the mouse, select it and call `DisplayShellContextMenu(that item's path, position, False)`. If not, `DisplayShellContextMenu(Root, position, True)`. `Handled := True` (the component's `PopupMenu` is not used).

`DisplayShellContextMenu(P, position, empty area)`:

1. Working folder `TargetDir`: `P` for the empty area, the folder of `P` for an item.
2. Get the `IShellFolder` of `TargetDir`. For the empty area, `CreateViewObject(IID_IContextMenu)`; for an item, `GetUIObjectOf(1 item, IID_IContextMenu)`.
3. `QueryContextMenu(menu, 0, 1, $7FFF, CMF_NORMAL)`. The low word of the return value + 1 becomes `CmdNewFolder`, the next `CmdNewFile`, and the next `CmdPaste`.
4. For the empty area, insert at the top "New &Folder", "New &Text Document", "&Paste" (grayed out if the clipboard has no `CF_HDROP`) and a separator, and then further above that "&View", "S&ort by" and a separator (`AddViewSortMenus(menu, CmdPaste + 1)`).
5. `ExtraMenuInsert` (`ExtraBackgroundMenu` for the empty area, `ExtraItemMenu` for an item).
6. Show with `TrackShellContextMenu`.
7. What was chosen: nothing happens for 0. For a custom item, `ExtraMenuClick`. For `CmdNewFolder` or `CmdNewFile`, create it and `FocusAndRenamePath`. For `CmdPaste`, `PasteToRoot`. For `CmdPaste + 1` to `+ 10` in the empty area, see the table in 7.12. Others are shell items: if the command name is 'rename', `RenameSelectedFile` (because the shell's rename does not work on this control); if 'paste', `SelectNewItemsOnNextRefresh` and then execute with `ShellInvokeMenuCommand(..., TargetDir)`.

Items of `AddViewSortMenus` (numbers from `ABaseID`):

| Number | Display | Processing |
|---|---|---|
| +0 | Lar&ge icons | `SetView(vsIcon)` |
| +1 | Small ico&ns | `SetView(vsSmallIcon)` |
| +2 | &List | `SetView(vsList)` |
| +3 | &Details | `SetView(vsReport)` |
| +4 to +7 | &Name, &Size, &Type, &Date modified | `SortBy(column, current ascending/descending)` |
| +8 | &Ascending | `SortBy(current column, True)` |
| +9 | D&escending | `SortBy(current column, False)` |

The current view style, column, and ascending/descending are checked. A separator between the "Sort by" columns and Ascending.

### 7.13 Drag & Drop

Source side:

1. `MouseDown`: after `inherited`, for the left or right button, when not editing and over an item, `FDragArmed := True` and remember the button and position (a right drag is a drop with a menu).
2. `MouseMove`: if `FDragArmed` and that button has been released, give up. If the mouse moved by `SM_CXDRAG`/`SM_CYDRAG` or more, `FDragArmed := False` and `PostMessage(CM_CSTARTDRAG)` (if started inside mouse processing, the list view keeps capturing the mouse and the drop target does not switch, so start after the processing ends).
3. `StartOleDrag`: does nothing if there is no handle, if being destroyed, or if the button has already been released. Finish if there are no selected paths. `ReleaseCapture`, `ShellDragBegin(Self, paths)`, `ShellDoDragDrop(Handle, paths, True, Effect)` (let the list view itself create the drag image), `ShellDragEnd`, `ReleaseCapture`. The copy or move is done by the drop target, and refreshing the display is left to change notifications.
4. `MouseUp`: `FDragArmed := False`, `inherited`.

Target side (`OleResolveDrop`. Called from Chapter 12):

1. If `Root` is empty or there is no handle, ''. `FOleDragOver := True`, start `FDragTimer`.
2. If the item under the mouse is a folder or a ZIP, its path is the drop target and a frame is drawn on that item. Otherwise `Root` (no frame).
3. For a drag started within the app, if `ShellDecideDropEffect(ShellDragPaths, target, ShellDragKeyState) = cdeNone`, then '' (no frame).
4. `SetDropHilite`.

| Procedure | Processing |
|---|---|
| `OleDropLeave` | `FOleDragOver := False`, stop the timer, remove the frame |
| `OleDropped(target)` | If the target is `Root`, `SelectNewItemsOnNextRefresh` |
| `SetDropHilite` | Store it if changed and `Invalidate` |
| `DrawDropFrame` | After `WM_PAINT`, draw a 2px `clHighlight` frame around `DisplayRect(drBounds)` of `FDropHilite` using `GetDC` |
| `DragTimerTick` | If not dragging, stop and remove the frame. If the mouse is outside (with a 20px margin above and below), stop. Within 20px of the top or bottom edge, `WM_VSCROLL` (`SB_LINEUP`, `SB_LINEDOWN`) |

## 8. Using Back/Forward with the Tree

When the mouse back/forward button is pressed over a TCTreeView, the TCTreeView calls `GoBack`/`GoForward` of the connected TCListView (TCTreeView design document).

---

## 9. Shared Part: CShellNotify (Change Notifications)

```pascal
const
  WM_CSHELLNOTIFY = WM_USER + $5A1;
  CSHCNE_RENAMEITEM = $00000001;  CSHCNE_CREATE = $00000002;  CSHCNE_DELETE = $00000004;
  CSHCNE_MKDIR = $00000008;       CSHCNE_RMDIR = $00000010;   CSHCNE_MEDIAINSERTED = $00000020;
  CSHCNE_MEDIAREMOVED = $00000040; CSHCNE_DRIVEREMOVED = $00000080; CSHCNE_DRIVEADD = $00000100;
  CSHCNE_ATTRIBUTES = $00000800;  CSHCNE_UPDATEDIR = $00001000; CSHCNE_UPDATEITEM = $00002000;
  CSHCNE_RENAMEFOLDER = $00020000;
  CSHCNE_DRIVEEVENTS = CSHCNE_MEDIAINSERTED or CSHCNE_MEDIAREMOVED or CSHCNE_DRIVEREMOVED or CSHCNE_DRIVEADD;
  CCSIDL_DRIVES = $0011;

function ShellNotifyRegisterPath(AWnd: HWND; const APath: string; ARecursive: Boolean; AEvents: LongInt): ULONG;
function ShellNotifyRegisterSpecial(AWnd: HWND; ACSIDL: Integer; ARecursive: Boolean; AEvents: LongInt): ULONG;
procedure ShellNotifyDeregister(var AID: ULONG);
function ShellNotifyDecode(AWParam: WPARAM; ALParam: LPARAM; out AEvent: LongInt; out APath1, APath2: string): Boolean;
```

- Registration is `SHChangeNotifyRegister(AWnd, SHCNRF_InterruptLevel or SHCNRF_ShellLevel or SHCNRF_NewDelivery, AEvents, WM_CSHELLNOTIFY, 1, entry)`. Changes made by other applications are also received, via shared memory. Always register one at a time (registering several at once makes deregistration not work correctly).
- Paths are converted to a PIDL with `ILCreateFromPathW`, and special folders with `SHGetSpecialFolderLocation`; free it after registering (it is duplicated at registration).
- `ShellNotifyDeregister`: if the ID is not 0, call `SHChangeNotifyDeregister` and set it to 0.
- `ShellNotifyDecode`: take the event and two PIDLs with `SHChangeNotification_Lock`, turn them into paths with `SHGetPathFromIDListEx` (a 32768-character buffer; supports long paths), then `Unlock`. Items that cannot be turned into a path are ''.
- The shell32 functions are declared independently with explicit names so they do not clash with FPC's declarations.

## 10. Shared Part: CShellMenu (Commands and Menus)

```pascal
type
  TCExtraMenuPosition = (empTop, empBottom);
const
  CEXTRA_MENU_FIRST_ID = $8100;   // First command ID for custom items (does not overlap the shell's 1 to $7FFF)

function ShellInvokeVerbOnItems(AWnd: HWND; APaths: TStrings; const AVerb: string; AShift: Boolean = False): Boolean;
function ShellInvokeVerbOnFolder(AWnd: HWND; const AFolder, AVerb: string): Boolean;
function TrackShellContextMenu(AWnd: HWND; AMenu: HMENU; ACM: IContextMenu; AScreenX, AScreenY: Integer): UINT;
function ShellMenuVerb(ACM: IContextMenu; ACmdOffset: UINT): string;
function ContainsInvalidChar(const AText: string): Boolean;
function ShellRenameItem(AWnd: HWND; const APath, ANewName: string): Boolean;
function ShellLongPathW(const APath: string): UnicodeString;
function ExtraMenuInsert(AMenu: HMENU; APopup: TPopupMenu; APosition: TCExtraMenuPosition; AComponent: TComponent; AItems: TList): Integer;
function ExtraMenuClick(AItems: TList; ACmd: UINT): Boolean;
function ShellInvokeMenuCommand(ACM: IContextMenu; AWnd: HWND; ACmdOffset: UINT; const ADirectory: string): Boolean;
```

| Function | Processing |
|---|---|
| `ShellInvokeVerbOnItems` | Make a PIDL of each path with `ILCreateFromPathW`. Get the parent of the first with `SHBindToParent` (assuming all items have the same parent), and call `GetUIObjectOf(IID_IContextMenu)` with the child PIDLs (`ILFindLastID` from the second on). `InvokeVerb`: call `QueryContextMenu` first (some implementations do not work otherwise), then `InvokeCommand` with the command name (AnsiString) in `lpVerb`, and `CMIC_MASK_SHIFT_DOWN` ($10000000) if `AShift` |
| `ShellInvokeVerbOnFolder` | Treats the folder itself as an item ("C:" becomes "C:\". The parent of a drive root is "PC"). `ShellInvokeVerbOnItems` |
| `TrackShellContextMenu` | If `ACM` is not nil, replace the window procedure of `AWnd` with `SetWindowLongPtrW(GWLP_WNDPROC)` only while the menu is shown (when `ACM` is nil, that is, a menu with only custom items, it is not replaced). The replaced procedure (`MenuHookProc`) works as follows. 1. `WM_INITMENUPOPUP`, `WM_MENUCHAR`, the menu's `WM_DRAWITEM` and `WM_MEASUREITEM` are passed to `HandleMenuMsg2` if `ACM` has `IContextMenu3`, or to `HandleMenuMsg` (except `WM_MENUCHAR`) if it has `IContextMenu2` (for submenus whose contents are built when opened, such as "Send to" and "New"; exceptions are swallowed). If the shell handled it, return that result and finish. 2. For those the shell did not handle in 1, when it has neither interface, and for `WM_MENUSELECT`, do not pass to LCL's original procedure but only `DefWindowProcW` (LCL reads the value attached to a menu item as a `TMenuItem`, so items into which the shell put a value (such as "New") cause an exception). 3. Other messages are passed to the original procedure. Returns the ID chosen by `TrackPopupMenu(TPM_LEFTALIGN or TPM_RIGHTBUTTON or TPM_RETURNCMD)` (0 means nothing was chosen). Finally restore. `Application.Hint` is not updated while the menu is shown |
| `ShellMenuVerb` | Up to 256 characters with `GetCommandString(relative ID, GCS_VERBW)`. Exceptions and failures give '' |
| `ContainsInvalidChar` | `True` if any of `\ / : * ? " < > \|` is present |
| `ShellRenameItem` | Get the parent with `SHBindToParent` and call `SetNameOf(AWnd, child, new name, SHGDN_INFOLDER or SHGDN_FORPARSING)` (handled as the actual name including the extension). `True` on success (the shell shows the reason for failure) |
| `ShellLongPathW` | If 248 characters or more and there is no `\\?\`: if it starts with `\\`, `\\?\UNC\` + the path without its first 2 characters; otherwise `\\?\` + path |
| `ExtraMenuInsert` | `APopup.PopupComponent := AComponent`, and call `OnPopup` if present (so the app can change the state of items). When adding at the end, if there are original items, insert a separator first and then add. `AddExtraItems`: for the visible items in order, separators as they are, text items with `Caption` (with #9 + `ShortCutToText` if there is a shortcut), grayed out if disabled, checked if `Checked`. If there are children, build a submenu and add the contents. Items without children are added with ID `CEXTRA_MENU_FIRST_ID + AItems.Count` and put into `AItems`. Returns the number added. If 0, remove the separator that was inserted. When adding at the top, if there are original items, put a separator in between. Icons are not shown |
| `ExtraMenuClick` | If the ID is `CEXTRA_MENU_FIRST_ID` or more and within the range of `AItems`, call that item's `Click` and return `True` |
| `ShellInvokeMenuCommand` | Declares and uses `CMINVOKECOMMANDINFOEX` independently (to pass Unicode paths). `fMask := CMIC_MASK_UNICODE`, put the relative ID in `lpVerb` and `lpVerbW`, put the working folder ("C:" becomes "C:\") in `lpDirectory` (ANSI) and `lpDirectoryW`, and call `InvokeCommand`. `False` on exception |

## 11. Shared Part: CShellDragDrop (Drag Information and Prohibition Check)

```pascal
type
  TCDropEffect = (cdeNone, cdeCopy, cdeMove);
var
  ShellDragTrace: Boolean = False;
procedure ShellDragLog(const AMsg: string);
procedure ShellDragBegin(ASource: TControl; APaths: TStrings);
procedure ShellDragEnd;
procedure ShellDragAbandon(ASource: TControl);
function ShellDragIsActive: Boolean;
function ShellDragPaths: TStrings;
function ShellDragKeyState: TShiftState;
function ShellDecideDropEffect(APaths: TStrings; const ATargetFolder: string; AShift: TShiftState): TCDropEffect;
```

- All hand-over of drags is done through OLE (Chapters 12 and 13). This unit is only responsible for holding the information of drags started within the app (the drag source and the item paths) and for the prohibition check (the decision of whether to draw a frame).
- `ShellDragLog`: only when `ShellDragTrace` is `True`, appends 'hh:nn:ss.zzz ' + the statement to `%TEMP%\cshell_dd.log` (for investigating problems; failures do not stop anything).
- `ShellDragBegin`: clears the previous information and holds the drag source and a copy of the paths. `ShellDragEnd`: clears it. `ShellDragAbandon(source)`: clears it if that control is the drag source (when the drag source is destroyed).
- `ShellDragIsActive`: there is a drag source and one or more paths.
- `ShellDragKeyState`: Ctrl and Shift via `GetKeyState`.
- `ShellDecideDropEffect`:
  1. `cdeNone` if there are no paths or the target is empty. `cdeNone` unless the target is a folder or an existing .zip (adding to a ZIP).
  2. Copy if Ctrl, move if Shift; if neither, move if the first path and the target are on the same drive, otherwise copy.
  3. Prohibited: `cdeNone` if any path is a drive root, the same as the target, or under itself. Unless it is a ZIP, if all are in the same folder as the target and it is a move, `cdeNone` (a copy is fine because it becomes "... - Copy").
- In finalization, free the list of paths.

## 12. Shared Part: CShellOleDrop (OLE Drop Target Side)

```pascal
type
  TOleResolveDropFunc = function(const AScreenPt: TPoint): string of object;  // Drop target ('' means not possible)
  TOleDropLeaveProc = procedure of object;
  TOleDroppedProc = procedure(const AFolder: string) of object;
  ICDropTarget = interface(IUnknown) ['{00000122-0000-0000-C000-000000000046}'] ... end;
  TCShellOleDropTarget = class(TInterfacedObject, ICDropTarget)
function OleDropRegister(AWnd: HWND; AOnResolve: TOleResolveDropFunc; AOnLeave: TOleDropLeaveProc; AOnDropped: TOleDroppedProc): TCShellOleDropTarget;
procedure OleDropRevoke(AWnd: HWND; var ATarget: TCShellOleDropTarget);
```

How it works: make the component's window a drop target with `RegisterDragDrop`, ask the component for the drop target at the mouse position (a folder or ZIP), obtain the drop target (`IDropTarget`) the shell has for that folder, and pass the processing straight to it. The copy/move decision, the right-drag menu, overwrite confirmation, and adding to a ZIP all become the same as in Explorer. The drag image is shown with `IDropTargetHelper` (CLSID `{4657278A-411B-11D2-839A-00C04FD918D0}`) (it works even if it cannot be created). The OLE interfaces and APIs are declared independently to avoid clashing with FPC's declarations.

| Procedure | Processing |
|---|---|
| `GetShellDropTarget(AWnd, P)` | "C:" becomes "C:\". Get the parent with `SHBindToParent` and call `GetUIObjectOf(IID_ICDropTarget)` |
| `SwitchTarget(target, ...)` | If the target differs from before, call `DragLeave` on the previous shell drop target and discard it, then get the new target's one and call `DragEnter` (no effect on failure). If the target is '' or cannot be obtained, no effect. If over the same target, `DragOver` with the effects the drag source allowed |
| `DragEnter` | Hold the data, ask for the target and `SwitchTarget`, then the helper's `DragEnter`. If the drag source allows nothing, no effect |
| `DragOver` | Ask for the target and `SwitchTarget`, then the helper's `DragOver` |
| `DragLeave` | Discard the shell drop target, the helper's `DragLeave`, discard the data, and the component's `OnLeave` |
| `Drop` | The helper's `Drop`, the component's `OnLeave` (removes the frame). Take out the shell drop target and target and empty them (once `Drop` is passed on, `DragLeave` is not sent). If present, call the component's `OnDropped(target)` and then pass to the shell's `Drop`. If absent, no effect |
| `Detach` | Detach the component's procedures and discard the shell drop target and the data (when destroying the component or its handle. The component is not called afterwards) |
| `OleDropRegister` | nil if the handle is 0. Create it and `_AddRef` (because the component also holds a reference), then `RegisterDragDrop`. On failure, `Detach`, `_Release`, and nil |
| `OleDropRevoke` | Does nothing if nil. `Detach`, `RevokeDragDrop` if there is a handle (the system's reference is released), `_Release`, and set to nil |

- No procedure lets an exception escape (they return no effect or `E_UNEXPECTED`).
- In initialization, `OleInitialize(nil)` (if it succeeds, `OleUninitialize` in finalization).

## 13. Shared Part: CShellOleDrag (OLE Drag Source Side)

```pascal
const
  CDROPEFFECT_NONE = 0; CDROPEFFECT_COPY = 1; CDROPEFFECT_MOVE = 2; CDROPEFFECT_LINK = 4;
function ShellDoDragDrop(AWnd: HWND; APaths: TStrings; AUseWindowImage: Boolean; out ADropEffect: DWORD): Boolean;
```

1. Get the item data (`IDataObject`) from the shell: make a PIDL of each path (without the trailing separator), `SHBindToParent` for the first one's parent (assuming all items have the same parent), and `GetUIObjectOf(IID_IDataObject)`. `False` if it cannot be obtained.
2. If `AUseWindowImage`, have the window (the list view) create the drag image with `InitializeFromWindow(AWnd, cursor position, data)` of `IDragSourceHelper` (declared independently). Otherwise `SHDoDragDrop` creates the default image.
3. `SHDoDragDrop(AWnd, data, nil, COPY or MOVE or LINK, effect)`. Waits until the drop. The source-side `IDropSource` is the default one (handles the left/right buttons and Esc). If `DRAGDROP_S_DROP` ($00040100), it was dropped and returns `True`.
4. Even for a move, it is the drop target (the shell) that removes the original item. The source side does nothing.

## 14. Points to Check When Investigating Problems

| Symptom | Where to look |
|---|---|
| `OnFolderChanged` or `OnSelectionChanged` does not fire or fires too often | `CheckStateChanged` (7.1), step 6 of `DoAsyncRefresh` (7.6) |
| Not updated when changed by another application | `RegisterFolderNotify`, step 2 of `HandleShellNotify` (7.5). Notifications may not arrive for network drives |
| The selection disappears or the scroll position returns on refresh | `DoAsyncRefresh` (7.6) |
| Sorting is slow | Whether `FindItemInfo` keeps rebuilding (7.7) |
| Flicker when resizing | `AutoSizeColumns`, the margin in `DoAsyncColumnResize` (Chapter 6, 7.8) |
| Cannot drop into Explorer | `PostMessage(CM_CSTARTDRAG)` in `MouseMove`, `ReleaseCapture` in `StartOleDrag` (7.13) |
| The "Send to" submenu is empty | The replacement in `TrackShellContextMenu` (Chapter 10) |
| In the context menu, an exception stops execution when the cursor is placed on an item (such as "New") | Whether menu-related messages are flowing to LCL in the replacement in `TrackShellContextMenu` (Chapter 10) |
| Fails with Japanese paths | Whether the W versions of the APIs are used (`PerformFileOperation`, `ShellInvokeMenuCommand`) |
| Want to trace the behavior of D&D | Set `ShellDragTrace := True` and look at `%TEMP%\cshell_dd.log` (Chapter 11) |
