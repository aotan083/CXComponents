# TCBookmark Design Document

Author: aotan083
Date: 2026-11-05
Version: 1.2

---

## 1. Purpose

Build a bookmark management component like Firefox's bookmark screen. Place it on a form and just select `TargetBrowser` and `TargetEditor` (no code needed) to open bookmarks in TCTabBrowser and TCMonacoEditor.

| No | Policy |
|---|---|
| 1 | The component is a single TCBookmark. It is a composite component containing a search box (`TEdit`) and a tree (`TCBookmarkTree`) |
| 2 | The open destinations are `TargetBrowser` and `TargetEditor`. If one is not set, the menu item for that destination is grayed out |
| 3 | Data is a JSON file in the storage folder. It is saved immediately on every change (the application does not write any saving code) |
| 4 | Import and export use only the Netscape Bookmark File Format (HTML). Browsers' internal files are neither read nor written |
| 5 | Only system colors are used (MetaDarkStyle switches them for dark mode). The component does not detect the theme itself |
| 6 | TCTabBrowser, TCMonacoEditor, TCsEditor and TCSynEdit are left untouched; only their public API is used |
| 7 | Dragging does not use LCL's drag mechanism (`BeginDrag`, `OnDragOver`, `OnDragDrop`, `OnEndDrag`); it is done by the component itself with mouse notifications. With LCL's mechanism, the order and presence of notifications on release were unreliable and it sometimes did not work |
| 8 | Drops from outside are received by a small `IDropTarget` inside the unit (CShellOleDrop is not used) |
| 9 | Mouse, key and menu operations only call protected virtual methods (chapter 14). This allows a derived class to call them directly for verification |
| 10 | When a file item is dragged onto a TCSynEdit, TCsEditor or TCMonacoEditor in the same application, it is opened in that editor without the application writing any code (11.5). Dropping onto an editor is for "editing the file the bookmark points to", so URLs are not accepted. When a URL or file item is dragged onto a TCTabBrowser in the same application, it is opened in a new tab (11.5). Changing the name or location of a bookmark is done with "Edit Bookmark" (10.2) |

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCbookmark.pas` | cx (runtime) | The types and classes of chapter 3, plus saving, loading, import, export and D&D |
| `uCbookmark_reg.pas` | cxdsgn (design time) | `Register`: `RegisterComponents('CX', [TCBookmark])`. `{$I cbookmark_icon.lrs}` in initialization |
| `cbookmark_icon.lrs` | cxdsgn (design time) | Icons (resource names `tcbookmark`, `tcbookmark_150`, `tcbookmark_200` (the IDE searches case-insensitively). PNGs of 24, 36 and 48 px. A picture of a blue bookmark ribbon over white paper) |

- `uCbookmark` uses: `Windows, Classes, SysUtils, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls, Menus, Graphics, Dialogs, LCLType, ActiveX, uCmonacos, uCTabBrowser`
- implementation uses: `ShellApi, ShlObj, Clipbrd, IniFiles, fpjson, jsonparser, base64, DateUtils, Math, LazUTF8, cSynedit, uCsEditor` (`cSynedit` and `uCsEditor` are used to identify types in 11.5. They do not appear in the interface. `cSynedit` and `uCsEditor` do not use `uCbookmark`, so there is no circular reference)
- `uCbookmark_reg` uses: `Classes, LResources, uCbookmark`
- `{$mode objfpc}{$H+}`.
- Windows APIs (`OleInitialize`, `RegisterDragDrop`, `RevokeDragDrop`, `ReleaseStgMedium`, `DragQueryFileW`, `CreateIconFromResourceEx`, `MoveFileExW`, `SHDoDragDrop`, `SHCreateStdEnumFmtEtc`, `ILCreateFromPathW`, `SHBindToParent`, `CoCreateInstance`, `RegisterClipboardFormatW`, and the WinINet functions `InternetOpenW`, `InternetOpenUrlW`, `InternetReadFile`, `InternetCloseHandle`, `InternetSetOptionW`, `HttpQueryInfoW`) are declared `external` inside the unit under names prefixed with `CB`, to avoid trouble from differences in FPC declarations. `IDropTarget` (`ICBDropTarget`), `IDataObject` (`ICBDataObject`), `IShellLinkW` (`ICBShellLinkW`), `IPersistFile` (`ICBPersistFile`) and `FILEDESCRIPTORW` (`TCBFileDescriptorW`) are also declared in the same layout as the Windows definitions.

**initialization**

1. `GLiveBookmarks := TFPList.Create` (the list of living TCBookmark instances. Used to check whether the component still exists when a favicon fetch finishes).
2. `OleInitialize(nil)` (required by `RegisterDragDrop`. Does nothing if already done).
3. Register the clipboard formats: `UniformResourceLocatorW` (`GCfUrlW`), `FileGroupDescriptorW` (`GCfFileGroupW`), `FileContents` (`GCfFileContents`), `UniformResourceLocator` (`GCfUrlA`).

**finalization**: `FreeAndNil(GLiveBookmarks)`.

## 3. Types and Classes

```pascal
TCBookmarkKind = (bkUrl, bkFile, bkFolder, bkSeparator);
TCBookmarkTarget = (btBrowser, btEditor);
TCBookmarkDropPos = (bdpBefore, bdpInside, bdpAfter);
```

| Class | Base class | Exposure | Role |
|---|---|---|---|
| `TCBookmark` | `TCustomPanel` | Palette | The component itself |
| `TCBookmarkItem` | `TObject` | public | One bookmark (chapter 4) |
| `TCBookmarkTree` | `TTreeView` | Internal | The tree. Draws the position line and frame during dragging. Registers the receiver for drops from outside (6.3) |
| `TCBookmarkDropTarget` | `TInterfacedObject`, `ICBDropTarget` | Internal | Receives drops from outside (11.1) |
| `TCBookmarkFaviconThread` | `TThread` | Internal | Fetches favicons in the background (8.3) |
| `TCBookmarkUrlData` | `TInterfacedObject`, `ICBDataObject` | Internal | Data handed over when a URL is dragged out of the application (11.3) |
| `TCBControlAccess` | `TControl` | Internal | Subclass used to call `DragOver` and `DragDrop` (protected) of components in the same application |

The add/edit dialog is created on the spot with `TForm.CreateNew` (there is no dedicated class or .lfm. See 10.2).

## 4. TCBookmarkItem

```pascal
TCBookmarkItem = class
private
  FKind: TCBookmarkKind;
  FName: string;
  FLocation: string;      // URL or file path
  FExpanded: Boolean;
  FAddDate: TDateTime;    // Now in Create
  FParent: TCBookmarkItem;
  FItems: TFPList;        // Children. Created in Create only for folders
  FFileMissing: Boolean;
  FNode: TTreeNode;       // The tree row currently displayed. Reassigned on every BuildTree (nil if none)
public
  constructor Create(AKind: TCBookmarkKind);
  destructor Destroy; override;          // Frees all children, then frees FItems
  procedure InsertChild(AIndex: Integer; AItem: TCBookmarkItem);
  procedure RemoveChild(AItem: TCBookmarkItem);
  function IsDescendantOf(AItem: TCBookmarkItem): Boolean;
  function Clone: TCBookmarkItem;
  function DescendantCount: Integer;
  property Kind: TCBookmarkKind read FKind;
  property Name: string read FName write FName;
  property Location: string read FLocation write FLocation;
  property Expanded: Boolean read FExpanded write FExpanded;
  property AddDate: TDateTime read FAddDate;
  property Parent: TCBookmarkItem read FParent;
  property Count: Integer read GetCount;               // 0 if FItems = nil
  property Items[AIndex: Integer]: TCBookmarkItem read GetItem; default;
  property Index: Integer read GetIndex;               // IndexOf in the parent's FItems. -1 if there is no parent
  property FileMissing: Boolean read FFileMissing;
end;
```

| Procedure | Processing |
|---|---|
| `InsertChild(I, It)` | Does nothing if `FItems` does not exist. If `I` is out of range, appends at the end. Inserts and sets `It.FParent := Self` |
| `RemoveChild(It)` | Removes it from `FItems` (does not free it). If the parent is itself, sets `FParent := nil` |
| `IsDescendantOf(A)` | Walks up the parents and returns `True` if `A` is found. `False` for itself and for nil |
| `Clone` | Copies kind, name, location, expanded state, registration date/time and `FFileMissing`, and also `Clone`s the children and inserts them (the parent is nil; `FNode` is not copied) |
| `DescendantCount` | For each child, 1 + the child's `DescendantCount` |

- The topmost container is `Root`, which has no name (`bkFolder`, `FExpanded = True`). The screen shows the children of `Root`.
- `TCBookmark` writes fields such as `FKind` and `FFileMissing` directly (because they are in the same unit).

## 5. Declaration and Fields of TCBookmark

### 5.1 Declaration

```pascal
protected
  procedure CreateWnd; override;
  procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  procedure DoItemClick(AItem: TCBookmarkItem); virtual;
  procedure DoMenuOpen(AItem: TCBookmarkItem; ATarget: TCBookmarkTarget; ANewTab: Boolean); virtual;
  procedure DoMenuEdit(AItem: TCBookmarkItem); virtual;
  procedure DoMenuDelete(AItem: TCBookmarkItem); virtual;
  procedure DoMenuCut(AItem: TCBookmarkItem); virtual;
  procedure DoMenuCopy(AItem: TCBookmarkItem); virtual;
  procedure DoMenuPaste(AItem: TCBookmarkItem); virtual;
  procedure DoMenuAddBookmark(AItem: TCBookmarkItem); virtual;
  procedure DoMenuAddFolder(AItem: TCBookmarkItem); virtual;
  procedure DoMenuAddSeparator(AItem: TCBookmarkItem); virtual;
  procedure DoDropItem(AItem, ATarget: TCBookmarkItem; APos: TCBookmarkDropPos); virtual;
  procedure DoDropFiles(const AFiles: TStrings; ATarget: TCBookmarkItem; APos: TCBookmarkDropPos); virtual;
  procedure DoDropUrl(const AUrl, ATitle: string; ATarget: TCBookmarkItem; APos: TCBookmarkDropPos); virtual;
public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  function ImportFromFile(const AFileName: string): Boolean;
  function ExportToFile(const AFileName: string): Boolean;
  procedure ImportWithDialog;
  procedure ExportWithDialog;
  function AddBookmark(AParent: TCBookmarkItem; AIndex: Integer; const AName, ALocation: string): TCBookmarkItem;
  function AddFolder(AParent: TCBookmarkItem; AIndex: Integer; const AName: string): TCBookmarkItem;
  function AddSeparator(AParent: TCBookmarkItem; AIndex: Integer): TCBookmarkItem;
  procedure DeleteItem(AItem: TCBookmarkItem);
  function MoveItem(AItem, ANewParent: TCBookmarkItem; ANewIndex: Integer): Boolean;
  procedure OpenItem(AItem: TCBookmarkItem; ATarget: TCBookmarkTarget; ANewTab: Boolean);
  property Root: TCBookmarkItem read FRoot;
  property Selected: TCBookmarkItem read GetSelected;          // ItemOfNode(FTree.Selected)
  property SearchText: string read GetSearchText write SetSearchText;
  property DragItem: TCBookmarkItem read FDragItem;
published
  property TargetBrowser: TCTabBrowser read FTargetBrowser write SetTargetBrowser;
  property TargetEditor: TCMonacoEditor read FTargetEditor write SetTargetEditor;
  property BookmarkFolder: string read FBookmarkFolder write SetBookmarkFolder stored IsBookmarkFolderStored;
  property BookmarkFile: string read FBookmarkFile write SetBookmarkFile stored IsBookmarkFileStored;
  property OnChange: TNotifyEvent read FOnChange write FOnChange;
  property OnSelectionChange: TNotifyEvent read FOnSelectionChange write FOnSelectionChange;
  property Align; Anchors; BorderSpacing; Constraints; Enabled; Font; ParentFont; ShowHint; TabOrder; TabStop; Visible;

// Unit functions
function CBClassifyLocation(const S: string; out AKind: TCBookmarkKind; out ALocation: string): Boolean;
function CBPathToFileUrl(const APath: string): string;
function CBFileUrlToPath(const AUrl: string): string;
function CBHostOf(const AUrl: string): string;
```

- `IsBookmarkFolderStored`: `FBookmarkFolder <> 'bookmark'`. `IsBookmarkFileStored`: `FBookmarkFile <> 'bookmarks.json'`.

### 5.2 Fields

| Name | Type | Initial value | Contents |
|---|---|---|---|
| `FSearch` | `TEdit` | Created in Create | Search box |
| `FTree` | `TCBookmarkTree` | Created in Create | Tree |
| `FImages` | `TImageList` | Created in Create | Icons (`SM_CXSMICON`×`SM_CYSMICON`) |
| `FMenu` | `TPopupMenu` | Created in Create | Right-click menu |
| `FMiTextOpen` to `FMiExport` | `TMenuItem` | Created in Create | The 14 menu items (10.1) |
| `FRoot` | `TCBookmarkItem` | Created in Create | Topmost container |
| `FTargetBrowser`, `FTargetEditor` | | nil | Open destinations |
| `FOnChange`, `FOnSelectionChange` | `TNotifyEvent` | nil | Events |
| `FLastSel` | `TCBookmarkItem` | nil | The selection last reported via `OnSelectionChange` (used only for comparison) |
| `FDataDir` | `string` | `UpdatePaths` | Storage folder (ends with `\`) |
| `FIconDir` | `string` | `UpdatePaths` | `FDataDir + 'icons\'` |
| `FBookmarkFolder` | `string` | 'bookmark' | `BookmarkFolder` |
| `FBookmarkFile` | `string` | 'bookmarks.json' | `BookmarkFile` |
| `FDataLoaded` | `Boolean` | `False` | Loaded |
| `FSaveErrorShown` | `Boolean` | `False` | A save failure has been reported (only once during a run) |
| `FUpdating` | `Boolean` | `False` | While the tree is being built or destroyed (expand/collapse and selection notifications are ignored) |
| `FSearching` | `Boolean` | `False` | Searching (the result list is displayed) |
| `FSearchKey` | `UnicodeString` | '' | Search characters (after `CBNormalize`) |
| `FSearchTimer` | `TTimer` | 300ms, stopped | Searches after input |
| `FDragItem` | `TCBookmarkItem` | nil | The item being dragged (`DragItem`) |
| `FDragStarted` | `Boolean` | `False` | Dragged after pressing (so the release is not treated as a click) |
| `FDragArmed` | `Boolean` | `False` | Left button pressed on an item (dragging starts once the threshold is exceeded) |
| `FDragActive` | `Boolean` | `False` | Dragging inside the component |
| `FDragStartPt` | `TPoint` | | Position where pressed |
| `FDownItem` | `TCBookmarkItem` | nil | Item at the pressed position |
| `FDropOk` | `Boolean` | `False` | Dropping is possible at the last checked position |
| `FDropTargetItem` | `TCBookmarkItem` | nil | Item at the last checked drop position (nil = bottom) |
| `FDropPos` | `TCBookmarkDropPos` | | The last checked drop position |
| `FDragTimer` | `TTimer` | 100ms, stopped | Auto-scroll and folder auto-open during dragging |
| `FHoverItem` | `TCBookmarkItem` | nil | Folder the pointer has paused on at an "inside" position |
| `FHoverStart` | `QWord` | | Time the pause began |
| `FExtDragging` | `Boolean` | `False` | D&D from outside in progress |
| `FAppTarget` | `TControl` | nil | Component in the same application under the mouse during dragging |
| `FAppAccept` | `Boolean` | `False` | That component's `OnDragOver` answered that it accepts |
| `FEditorTarget` | `TControl` | nil | During dragging, the open target under the mouse that TCBookmark opens the item in by itself (TCSynEdit, TCsEditor, TCMonacoEditor or TCTabBrowser; 11.5) |
| `FEditorFile` | `string` | '' | What to open in `FEditorTarget`. For an editor, a file (for a `.lnk`, its link target); for a TCTabBrowser, a URL (a file becomes `file:///…`) (11.5) |
| `FOleDragging` | `Boolean` | `False` | An OLE drag started by itself is in progress (not accepted by its own tree) |
| `FPopupItem` | `TCBookmarkItem` | nil | Item that was right-clicked (nil = empty area) |
| `FClip` | `TCBookmarkItem` | nil | Copied duplicate (owned by TCBookmark) |
| `FCutItem` | `TCBookmarkItem` | nil | Cut item (remains in its original place) |
| `FIconKeys` | `TStringList` (sorted) | Empty | File icons: key → index into `FImages` |
| `FHostIcons` | `TStringList` (sorted) | Empty | Favicons: host → index into `FImages` (-1 = none) |
| `FBaseIconsMade` | `Boolean` | `False` | The globe and folder icons have been created |
| `FGlobeIndex`, `FFolderIndex`, `FFolderOpenIndex` | `Integer` | -1 | Indexes of those icons |
| `FFetchTried` | `TStringList` (sorted) | Empty | Hosts already fetched during this run |
| `FFetchQueue` | `TStringList` | Empty | Hosts waiting in the queue |
| `FFetchRunning` | `Integer` | 0 | Number of fetches in progress |
| `FPendingFiles` | `TStringList` | Empty | Dropped files (registered later) |
| `FPendingUrl`, `FPendingTitle` | `string` | '' | Dropped URL and title |
| `FPendingTarget` | `TCBookmarkItem` | nil | Item at the drop position |
| `FPendingPos` | `TCBookmarkDropPos` | | Drop position |
| `FPendingIsUrl` | `Boolean` | `False` | What was dropped is a URL |
| `FDlgName`, `FDlgLoc` | `TEdit` | nil | Dialog input fields (only while shown) |
| `FDlgOk` | `TButton` | nil | The dialog's [OK] (only while shown) |
| `FDlgWithLoc` | `Boolean` | | The dialog has a location field |

## 6. Creation and Destruction

### 6.1 Create

1. `inherited`. Remove `csSetCaption` and `csAcceptsControls` from `ControlStyle`. `SetTextBuf('')`, `BevelOuter` and `BevelInner := bvNone`, 250×300.
2. Create `FRoot` (`FExpanded := True`). `FBookmarkFolder := 'bookmark'`, `FBookmarkFile := 'bookmarks.json'`, `UpdatePaths`.
3. Create `FIconKeys`, `FHostIcons` and `FFetchTried` as sorted lists, and `FFetchQueue` and `FPendingFiles`.
4. `FImages` (owner is Self, size is `SM_CXSMICON` and `SM_CYSMICON`).
5. `FSearch`: `csNoDesignSelectable`, `Align := alTop`, `TextHint := 'Search bookmarks'`, `OnChange := SearchChange`, `OnKeyDown := SearchKeyDown`.
6. `FTree`: `FBM := Self`, `csNoDesignSelectable`, `Align := alClient`, `BorderStyle := bsNone`, `ReadOnly := True` (renaming is done in the dialog), `RowSelect := True`, `ShowLines := False`, `ShowRoot := True`, `HideSelection := False`, `ToolTips := False`, `ScrollBars := ssAutoBoth`, `Options + [tvoNoDoubleClickExpand]` (so that a left click expands/collapses), `Images := FImages`. Events: `OnMouseDown`, `OnMouseUp`, `OnMouseMove`, `OnKeyDown`, `OnExpanded`, `OnCollapsed`, `OnAdvancedCustomDrawItem` (`TreeDrawItem`), `OnChange` (`TreeSelChange`).
7. Create the items of 10.1 in `FMenu` (`OnPopup := MenuPopup`), and set `FTree.PopupMenu := FMenu`.
8. Create `FSearchTimer` (300ms) and `FDragTimer` (100ms) in the stopped state.
9. `GLiveBookmarks.Add(Self)`.

- Create does not load data (6.2).

### 6.2 CreateWnd

`inherited`. If `FDataLoaded` is not set and it is not design time: `FDataLoaded := True`, `LoadData`, `BuildTree`.

- The loading is done when the window is first created so that it happens after `BookmarkFolder` and `BookmarkFile` have been read from the .lfm.

### 6.3 TCBookmarkTree

| Procedure | Processing |
|---|---|
| `CreateWnd` | `inherited`. At runtime, if there is no `FDropTarget`, create `TCBookmarkDropTarget.Create(FBM)` and call `RegisterDragDrop(Handle, FDropTarget)` |
| `DestroyWnd` | If `FDropTarget` exists, `RevokeDragDrop(Handle)`. `inherited` |
| `ShowIndicator(It, Pos)` | Does nothing if unchanged. Remembers it and calls `Invalidate` |
| `HideIndicator` | If shown, hides it and calls `Invalidate` |
| `Paint` | After `inherited`, if shown, draws with `clHighlight` and a thickness of 2. If `It.FNode` exists: for before, a horizontal line at the top edge of the row; for after, at the bottom edge of the row; running from 4px left of the text to the right edge. For inside, a frame around the row. If `It` is nil (bottom), a horizontal line at the bottom edge of the last visible row (y=2 if there are no rows) |

- `FDropTarget` is held as an interface (when the tree is destroyed the reference is released and it is freed).

### 6.4 Destroy

1. `GLiveBookmarks.Remove(Self)` (so that a favicon thread that has finished does not touch it).
2. `Application.RemoveAsyncCalls(Self)` (cancels the reserved drop registration).
3. `FUpdating := True` (ignores expand/collapse notifications while the tree is destroyed).
4. `FCutItem := nil`; free `FClip`, `FRoot` and the `TStringList`s of 5.2.
5. `inherited`.

### 6.5 Notification and Open Destinations

- `SetTargetBrowser`, `SetTargetEditor`: `RemoveFreeNotification` from the previous value, `FreeNotification` on the new value.
- `Notification`: when an open destination is removed with `opRemove`, set it to nil. When `FEditorTarget` is removed, `FEditorTarget := nil` and `FEditorFile := ''` (it was given `FreeNotification` in 11.5).

## 7. Data

### 7.1 Storage Location (UpdatePaths)

1. `D := Trim(FBookmarkFolder)`. If there is no drive name and it does not start with `\`, append it after the EXE's folder.
2. `FDataDir := IncludeTrailingPathDelimiter(ExpandFileName(D))`, `FIconDir := FDataDir + 'icons\'`.
3. If `Trim(FBookmarkFile) = ''`, use 'bookmarks.json'.

`SetBookmarkFolder`, `SetBookmarkFile`: if different, assign, then `UpdatePaths` and `ReloadData`.

`ReloadData`: does nothing at design time, while the .lfm is being loaded, or if nothing has been loaded yet (it loads from the new location when first displayed). If already loaded:

1. Set the fields that point to items (`FCutItem`, `FDragItem`, `FDownItem`, `FDropTargetItem`, `FPopupItem`, `FHoverItem`, `FPendingTarget`) to nil, and `FDropOk := False`.
2. `FTree.Items.Clear` during `FUpdating` (removes the rows pointing to old items first).
3. Recreate `FRoot`. Empty `FHostIcons` and `FFetchTried` (because the favicon folder also changes).
4. `LoadData`, `BuildTree`, `OnChange`, `CheckSelection`.

### 7.2 Loading (LoadData)

1. `UpdatePaths`. `F := FDataDir + FBookmarkFile`. Does nothing if it does not exist.
2. `CBReadFileText(F)` (strips the UTF-8 BOM) → `GetJSON`. Raises an exception if it is not a `TJSONObject`. If `items` is an array, `ReadJsonItems(FRoot, items)`.
3. On an exception: recreate `FRoot` empty, rename `F` to `F + '.broken-' + yyyymmddhhnnss`, and show "Could not load the bookmarks. The original file has been kept as (name)." (`mtWarning`). This avoids overwriting a broken file with empty data.
4. `RefreshMissing(FRoot, True)`.

`ReadJsonItems(parent, array)`: for each object, create an item if `type` is `url`, `file`, `folder` or `separator`; unknown `type`s are skipped. Set `name`, `location`, `expanded` and `added` (`CBIsoToDate`; `Now` if 0), and append to the parent. For `folder`, read `items` with the same procedure.

### 7.3 Saving (SaveData)

1. Does nothing at design time.
2. Convert `{"version": 1, "items": WriteJsonItems(FRoot)}` to text with `FormatJSON`.
3. `ForceDirectories(FDataDir)`. Write to `F + '.tmp'`, then `MoveFileExW(tmp, F, MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH)` (the file is not corrupted even if it stops midway). Failure raises an exception.
4. The exception is caught; unless `FSaveErrorShown` is already set, set it and show "Cannot save the bookmarks: (reason)" (`mtError`).

`WriteJsonItems`: URLs and files write `type`, `name`, `location` and `added`; folders write `type`, `name`, `expanded`, `added` and `items`; separators write only `type`. `added` is `CBDateToIso` (`yyyy-mm-ddThh:nn:ss`).

### 7.4 Common Processing After a Change (Changed)

`Changed(item to select)`: `BuildTree` → `SelectItem` → `SaveData` → `OnChange` → `CheckSelection`. Adding, editing, deleting, moving, pasting, importing and dropping all end with this.

- Expanding/collapsing a folder only does `SaveData` (`OnChange` is not fired; see 8.1).

### 7.5 Selection Notification

| Procedure | Processing |
|---|---|
| `TreeSelChange` | Does nothing if `FUpdating`. `CheckSelection` |
| `CheckSelection` | Does nothing if `FUpdating` or in the middle of destruction. Does nothing if `GetSelected` equals `FLastSel`. Otherwise remembers it and fires `OnSelectionChange` |

- No notification is made while the tree is being rebuilt; the comparison is made once after the rebuild (at the end of `Changed`, `SearchTimer` and `ReloadData`).

### 7.6 Checking Link Targets (RefreshMissing)

`RefreshMissing(It, ADeep)`: if `It` is a file, `FFileMissing := not FileExists`. If a folder, check the child files, and if `ADeep`, apply the same procedure to child folders too.

| When called | How it is called |
|---|---|
| When loaded | `RefreshMissing(FRoot, True)` |
| When a folder is expanded | `RefreshMissing(folder, False)` |
| When pasted | `RefreshMissing(duplicate, True)` |
| Registration, editing, drop | Set with `FileExists` when created |
| When opening | Rechecked in `OpenItem` |

## 8. Display

### 8.1 Tree

| Procedure | Processing |
|---|---|
| `BuildTree` | `MakeBaseIcons`. During `FUpdating`: `BeginUpdate`, `Clear`, `ClearNodes(FRoot)` (sets `FNode := nil` for all items). If searching, `AddMatches(FRoot)`; otherwise `AddNodes(nil, FRoot)`. `EndUpdate`. `FTree.DragMode := dmManual` |
| `AddNodes(parent row, It)` | For each child, `AddChildObject(parent row, name, child)` and `child.FNode := row`. For a folder, add its children and then `Expanded := child.FExpanded`. `SetNodeLook` |
| `AddMatches(It)` | Descend into folders. URLs and files whose `CBNormalize(name)` or `CBNormalize(location)` contains `FSearchKey` are added as a single flat list at the top level |
| `SetNodeLook(row, It)` | `ImageIndex` and `SelectedIndex := IconIndexOf(It, row.Expanded)`, `StateIndex := -1`. For a separator, `Height := Max(6, DefaultItemHeight div 2)` |
| `UpdateAllIcons` | `SetNodeLook` on all rows, `Invalidate` |
| `SelectItem(It)` | If `It.FNode` exists, select it and `MakeVisible` |
| `TreeExpanded` | Does nothing if `FUpdating` or searching. For a folder: `FExpanded := True`, `RefreshMissing(It, False)`, `SetNodeLook`, `Invalidate`, `SaveData` |
| `TreeCollapsed` | Under the same conditions: `FExpanded := False`, `SetNodeLook`, `SaveData` |

### 8.2 Self-Drawn Rows (TreeDrawItem)

Only at `cdPrePaint`.

- Separator: fill the row's rectangle with `clHighlight` if selected, otherwise with the tree's color, and draw a 1px `clGrayText` line at the middle height, from the left of the icon to the right edge minus 8px (converted from 96dpi). `DefaultDraw` and `PaintImages := False`.
- File whose link target is missing: fill the row (`clHighlight` with text `clHighlightText` if selected, otherwise the tree's color with text `clGrayText`), draw the icon with `FImages.Draw`, and draw the name with `TextOut`. `DefaultDraw` and `PaintImages := False`.

- Reasons for drawing by itself: a separator changes the row height. For missing files, merely changing `Canvas.Font.Color` had no effect on the color in TTreeView's drawing.

### 8.3 Icons

| Procedure | Processing |
|---|---|
| `MakeBaseIcons` | Only once. Draws a globe picture on a `TBitmap` (background `clFuchsia`, lines in blue `$00A06A2E`; a circle, a tall ellipse and 3 horizontal lines) and calls `AddMasked`. Adds the folder icons with `AddShellIcon('folder', FILE_ATTRIBUTE_DIRECTORY, SHGFI_USEFILEATTRIBUTES)` and again with `SHGFI_OPENICON` (if the open one cannot be obtained, the closed one is used) |
| `AddShellIcon(path, attributes, flags)` | Passes the icon from `SHGetFileInfoW(SHGFI_ICON or SHGFI_SMALLICON or flags)` through a `TIcon` to `FImages.AddIcon` (the `TIcon` releases the handle). -1 if it cannot be obtained |
| `FileIconIndex(path)` | Key 'e:' + extension by extension ('.txt' if none). For .exe, .ico and .lnk where the file exists, 'p:' + path (per file). If remembered, return that. Otherwise, for 'p:' use `AddShellIcon(path, 0, 0)`, for 'e:' use `AddShellIcon('x' + extension, FILE_ATTRIBUTE_NORMAL, SHGFI_USEFILEATTRIBUTES)` |
| `HostIconFile(host)` | The .png of `FIconDir + CBHostFileKey(host)`, or the .ico if absent. '' if neither exists |
| `HostIconIndex(host)` | If remembered, return that (-1 is also remembered). If the file exists, `AddIcon` of `CBIconFromBytes(contents, FImages.Width)` |
| `IconIndexOf(It, open)` | URL: `HostIconIndex`, or the globe if -1. File: `FileIconIndex`. Folder: two icons for open/closed. Separator: -1 |

`CBIconFromBytes(contents, size)`: for PNG (starts with `89 50 4E 47`), pass the whole thing to `CreateIconFromResourceEx(…, True, $00030000, size, size, 0)`. For ICO (starts with `00 00 01 00`), pass the part of the smallest image that is at least the size (or the largest if none; a width of 0 means 256) to the same function. 0 for anything else or if out of range.

**Fetching favicons**

| Procedure | Processing |
|---|---|
| `RequestFavicon(host)` | Does nothing if the host is empty, at design time, the file exists, or it was already fetched during this run (`FFetchTried`). Adds to `FFetchTried` and `FFetchQueue`, then `StartNextFetch` |
| `StartNextFetch` | While `FFetchRunning < 4` and there are waiting hosts, take the first, `Inc(FFetchRunning)`, create a thread and `Start` it |
| `TCBookmarkFaviconThread.Execute` | `InternetOpenW('CXBookmark', PRECONFIG)`, 10-second connect/receive timeouts. Opens `https://(host)/favicon.ico` with `RELOAD, NO_UI, NO_COOKIES`, and only if the status is 200 reads 8KB at a time (discarded if it exceeds 512KB). Exceptions are caught and the result is empty. Finally `Synchronize(Done)` |
| `Done` | If the component is still in `GLiveBookmarks`, `FaviconArrived` |
| `FaviconArrived(host, contents)` | `Dec(FFetchRunning)`. If there are contents and no file yet, `SaveHostIcon` and `UpdateAllIcons`. `StartNextFetch` |
| `SaveHostIcon(host, contents)` | Discarded unless PNG or ICO. `ForceDirectories(FIconDir)`, delete the file with the other extension and write (failures exit silently). Clears the `FHostIcons` memo (forcing a re-read) |

- The thread is `FreeOnTerminate`. It does not wait even if the component is destroyed (checked in `Done`).

## 9. Creating, Inserting and Opening Items

### 9.1 Creating and Inserting

| Procedure | Processing |
|---|---|
| `NewLink(name, location)` | nil if `CBClassifyLocation` cannot decide. Creates the item; the name is `Trim(name)`, or the file name if empty (the URL for a URL). For a file, set `FFileMissing`; for a URL, `RequestFavicon(CBHostOf)` |
| `InsertPos(It, out parent, out position)` | `It` is nil or not in the tree → end of `Root`. Folder → end inside it. Otherwise → `It.Index + 1` in `It`'s parent |
| `DropDest(target, position, out parent, out position)` | Target is nil or not in the tree → end of `Root`. Before → `target.Index` in the target's parent. After → `target.Index + 1`. Inside → end of the folder if it is a folder, otherwise the same as after |
| `DoInsert(parent, position, It)` | If parent is nil, use `Root`. `InsertChild`. Unless it is `Root`, set the parent's `FExpanded := True` (expands the folder inserted into) |
| `MoveInternal(It, new parent, position)` | `False` if `It` is nil, `Root` or not in the tree, if the new parent is not a folder or not in the tree, or if the new parent is `It` itself or under it. If the position is out of range, the end. When moving from front to back within the same parent, subtract 1 from the position (for the removed one). Detach and `DoInsert`. `True` |
| `IsInTree(It)` | Whether the topmost ancestor is `FRoot` (distinguishes deleted items and duplicates) |

### 9.2 Public Methods

| Method | Processing |
|---|---|
| `AddBookmark` | `NewLink`. Returns nil if nil. If the parent is nil, not a folder, or not in the tree, `Root`. `DoInsert`, `Changed(added item)` |
| `AddFolder`, `AddSeparator` | Create and insert in the same way, then `Changed` |
| `DeleteItem(It)` | Does nothing if nil, `Root` or not in the tree. Sets `FCutItem`, `FLastSel`, `FDragItem`, `FDownItem` and `FDropTargetItem` to nil if they are `It` or under it (for `FDropTargetItem`, also `FDropOk := False`). The next item to select is the one at the same position (next) in the same parent, or the last if none, or the parent if none (nil if `Root`). Detach and `Free`, `Changed(next)` |
| `MoveItem` | If `MoveInternal` returns `True`, `Changed(It)` |
| `OpenItem(It, target, new)` | Does nothing for anything but URLs and files. For a file, recheck `FFileMissing` and `Invalidate`. If missing, show "File not found: (path)" (`mtWarning`) and exit. `btEditor` calls `OpenInEditor` only if `TargetEditor` exists and it is a file. `btBrowser`, if `TargetBrowser` exists, calls `OpenInBrowser` with a URL as is, or a file converted with `CBPathToFileUrl` |

### 9.3 Opening

`OpenInEditor(path, new)` (uses TCMonacoEditor's `OpenFile`, `FindPage`, `ActiveIndex`, `Modified`, `LoadFromFile` and `SetFocus`):

1. New tab: if `OpenFile(path) >= 0`, `SetFocus` (if already open, it only switches to that tab; this is TCMonacoEditor's rule). Done.
2. If `FindPage(path) >= 0`, make it the `ActiveIndex` and `SetFocus`. Done. This is checked first because `LoadFromFile` raises an error, without reading, for a file already open in another tab.
3. If `Modified`, ask "There are unsaved changes. Open in a new tab?" (Yes/No). If Yes, `OpenFile` and `SetFocus`. Done. This is asked here because `LoadFromFile` discards changes without checking. No option to discard the changes and load is offered.
4. If `LoadFromFile(path)` is `True`, `SetFocus`.

- Exceptions are caught and "Cannot open: (path : reason)" (`mtError`) is shown.

`OpenInBrowser(URL, new)`: for a new tab, `TargetBrowser.Add(URL)`; otherwise `Navigate(URL)` (TCTabBrowser creates a tab if there is none). Exceptions are caught and "Cannot open: (URL : reason)" is shown.

- Reason `LoadFromFile` is not used when opening a file in TCTabBrowser: there is no way to open it in a new tab, and paths containing `%` or `#` cannot be passed correctly.

### 9.4 Unit Functions

| Function | Processing |
|---|---|
| `CBClassifyLocation` | `Trim`. `False` if empty. If it starts with `file:`, `bkFile` and `CBFileUrlToPath` (`True` if non-empty). If it contains `://`, `bkUrl`. If it starts with `letter + ':' + ('\' or '/')` or `\\`, `bkFile` (`/` → `\`). `False` otherwise |
| `CBPathToFileUrl` | Character by character: `\` → `/`, `%` → `%25`, `#` → `%23`, space → `%20`. If it starts with `//`, `'file:' + S`; otherwise `'file:///' + S` |
| `CBFileUrlToPath` | Strip `file:///`. For `file://`, `//` + the rest. `CBPercentDecode` (byte by byte), `/` → `\` |
| `CBHostOf` | From after `://` up to before `/ ? # \`. If there is an `@`, what follows it. Lower case. '' if there is no `://` |
| `CBHostFileKey` | Replaces `: \ / * ? " < > \|` in the host with `_` (the icon file name) |
| `CBNormalize` | Convert to UTF-16, full-width `！` to `～` ($FF01 to $FF5E) to half-width, full-width space to half-width space, `WideLowerCase` |
| `CBHtmlEscape` | Turns `& < > "` into character references |
| `CBHtmlDecode` | Restores `&amp; &lt; &gt; &quot; &apos; &nbsp;` (space), `&#nnn;` and `&#xhh;` (up to $FFFF) |
| `CBReadUrlFile` | Opens a .url with `TIniFile` and returns the `URL` of `[InternetShortcut]`. '' if unreadable |
| `CBResolveLink` | `CoCreateInstance(CLSID_ShellLink)` → `IPersistFile.Load` → `Resolve(0, SLR_NO_UI)` → `GetPath`. '' on failure |

## 10. Operations

### 10.1 Right-Click Menu

Items (`Tag` is the number used by `MenuClick`): Text Open (1) / Text Open in New Tab (2) / ― / Open in Browser (3) / Open in Browser in New Tab (4) / ― / Edit Bookmark (5) / Delete Bookmark (6) / ― / Cut (7) / Copy (8) / Paste (9) / ― / Add Bookmark (10) / Add Folder (11) / Separator (12) / ― / Import... (13) / Export... (14). The texts are `resourcestring`s.

`TreeMouseDown` (right button): selects the pressed row (clears the selection if on an empty area). `FPopupItem := that item`.

`MenuPopup`: `FPopupItem := GetSelected` (the same when the menu is shown via the keyboard).

| Item | Enabled when |
|---|---|
| Text items | `TargetEditor` exists and it is a file |
| Browser items | `TargetBrowser` exists and it is a URL or a file |
| Edit | An item exists and is not a separator |
| Delete, Cut, Copy | An item exists |
| Paste | Not searching, and `FClip` or `FCutItem` exists |
| The 3 Add items, Import | Not searching |
| Export | Always |

`MenuClick`: if `FPopupItem` is not in the tree, set it to nil, then call the numbered processing (chapter 14, `ImportWithDialog`, `ExportWithDialog`).

### 10.2 Add/Edit Dialog (EditDialog)

`EditDialog(title, var name, var location, with location)`:

1. `TForm.CreateNew(GetParentForm(Self))`, `bsDialog`, `poOwnerFormCenter`, width 440 (converted from 96dpi; the same below).
2. A "Name" label and `FDlgName`. If with location, a "URL or file path" label and `FDlgLoc`. Both have `OnChange := DlgChange`.
3. Place [OK] (`FDlgOk`, `mrOk`, `Default`) and [Cancel] (`mrCancel`, `Cancel`) at the lower right. `ActiveControl := FDlgName`, `DlgChange(nil)`.
4. If `ShowModal = mrOk`, return the `Trim`med values and `True`.
5. In finally, `FDlgName`, `FDlgLoc` and `FDlgOk := nil`, then `Free`.

`DlgChange`: `FDlgOk.Enabled := (name is not empty) and (no location or CBClassifyLocation(location))`.

### 10.3 Keys

`TreeKeyDown`: while dragging, Esc calls `EndInternalDrag(False)`, and every key exits with `Key := 0`.

| Key | Processing |
|---|---|
| Enter | `DoItemClick(selection)` |
| Delete | `DoMenuDelete` if there is a selection |
| F2 | `DoMenuEdit` unless it is a separator |
| Ctrl+X, Ctrl+C | `DoMenuCut`, `DoMenuCopy` |
| Ctrl+V | If not searching and there is a duplicate or cut item, `DoMenuPaste(selection)` |
| Ctrl+F | `FSearch.SetFocus`, `SelectAll` |

`SearchKeyDown`: Esc → `SetSearchText('')`. Down arrow or Enter → if there are rows, select the first row if nothing is selected, and focus the tree. Both set `Key := 0`.

### 10.4 Search

| Procedure | Processing |
|---|---|
| `SearchChange` | Stops and restarts `FSearchTimer` (300ms after input) |
| `SearchTimer` | Stops it. Does nothing at design time. `K := CBNormalize(Trim(text))`. Does nothing if `K` and the searching state are the same as before. Remembers the selection, `FSearchKey := K`, `FSearching := K <> ''`, `BuildTree`, `SelectItem(remembered item)`, `CheckSelection` |
| `SetSearchText` | `FSearch.Text := value` (the timer starts via `OnChange`). Stops the timer and immediately calls `SearchTimer(nil)` |

- Operations that cannot be done while searching (paste, add, import, moving by dragging, and drops from outside) have their menu items grayed out, and the procedures of chapter 14 also exit at the start if `FSearching`. This is because the insertion position cannot be determined.

## 11. Drag and Drop

### 11.1 Drops from Outside (TCBookmarkDropTarget)

| Method | Processing |
|---|---|
| `DragEnter` | Accepts if not searching, not during its own OLE drag, and any of `CF_HDROP`, `UniformResourceLocatorW` or `CF_UNICODETEXT` (containing `://`) is present. If accepted, `FExtDragging := True`, `BeginDragTimer`, and choose the effect (link if a link is available, otherwise copy). If not accepted, no effect |
| `DragOver` | No effect if not accepted. If `CalcDrop` succeeds, `ShowIndicator` and choose the effect. Otherwise `HideIndicator` and no effect |
| `DragLeave` | `HideIndicator`, `FExtDragging := False`, `EndDragTimer`, return to the not-accepting state |
| `Drop` | After the same cleanup, no effect if `CalcDrop` fails. If `CF_HDROP` is present, put the file names into `FPendingFiles` (`DragQueryFileW`). If not, take the URL from `UniformResourceLocatorW`, or otherwise from `CF_UNICODETEXT` (the first line containing `://`), and set `FPendingIsUrl`, `FPendingUrl` and `FPendingTitle` (the first file name of `FileGroupDescriptorW` with .url removed). If there is nothing, no effect. Remember the position in `FPendingTarget` and `FPendingPos`, and `Application.QueueAsyncCall(AsyncExternalDrop)` |

- Reason registration is not done inside the drop handling: so that the confirmation message (the count in 11.2) does not block the source application (Explorer, etc.).

`AsyncExternalDrop`: sets `FPendingTarget` to nil if it is not in the tree. For a URL, `DoDropUrl`; for files, `DoDropFiles` with a copied list. Cleanup.

### 11.2 Registering Files and URLs

`DoDropFiles(files, target, position)`:

1. Does nothing if empty or searching.
2. For each file, if it is a .lnk whose target is a folder, use the target; if it is a folder, add up `CountDirEntries(folder, MaxInt div 2)`. If the total exceeds 500, ask "Register n items?". Exit if No.
3. Decide the parent and position to insert into with `DropDest`, and with an hourglass cursor insert `ItemFromPath(file, True)` for each file in order (advancing the position by 1 each time).
4. If at least one was inserted, `Changed(last inserted item)`.

`ItemFromPath(path, follow links)`:

| Path | Item created |
|---|---|
| Folder (`C:` becomes `C:\`) | A folder. The name is the folder name (the path for a drive). The contents are added with `AddDirContents` |
| .url from which a URL can be read | `NewLink(name without .url, URL)` |
| .lnk (only when following) whose target can be read | If the target is a folder, use the name of `ItemFromPath(target, False)` replaced with the name without .lnk. If a file, a file item (the name is the name without .lnk, the location is the target) |
| Anything else | A file. The name is the file name |

`AddDirContents(folder, path)`: with `FindFirst`, exclude `.` and `..`, split into folders (excluding symbolic links and junctions) and files, and sort each case-insensitively. Folders go first, with their contents added by the same procedure. Files use `ItemFromPath(…, False)` (.lnk files inside are not followed, to avoid going around the same place repeatedly).

`CountDirEntries(path, limit)`: counts excluding `.` and `..`, and also counts inside folders that are not links. Stops when the limit is exceeded.

`DoDropUrl(URL, title, target, position)`: does nothing if searching. `NewLink(title, URL)`, `DropDest`, `DoInsert`, `Changed`.

### 11.3 Dragging Inside the Component

| Procedure | Processing |
|---|---|
| `TreeMouseDown` (left) | `FDragStarted` and `FDragArmed := False`, `FDownItem := nil`. Exit if on the [▶]. `FDownItem := item of the pressed row`. If an item exists and not searching, `FDragArmed := True` and remember the position |
| `TreeMouseMove` | If dragging, `DragMoveTo`. Exit unless `FDragArmed`. If the left button has been released, `FDragArmed := False`. If moved by `SM_CXDRAG` or `SM_CYDRAG` or more from the pressed position, start only if `FDownItem` is in the tree: `FDragActive` and `FDragStarted := True`, `FDragItem := FDownItem` (the pressed item, not the selection), `FTree.MouseCapture := True` (so `MouseUp` is received even when released outside), `FAppTarget := nil`, `BeginDragTimer`, `DragMoveTo` |
| `TreeMouseUp` (left) | `FDragArmed := False`. If dragging, `EndInternalDrag(True)`. If it was dragged, exit with `FDragStarted := False` (not treated as a click). Exit if Shift, Ctrl or Alt is held. Exit if on the [▶] (TTreeView expands/collapses). Only when the item of the released row equals `FDownItem`, `DoItemClick` |
| `CalcDrop(X, Y, out target, out position)` | `False` if searching. If there is no row, target nil (bottom) and `True`. For a folder: before in the top 1/4 of the height, after in the bottom 1/4, otherwise inside. For non-folders: before in the upper half, after in the lower half |
| `CanDropItem(drag, target, position)` | `False` if the dragged item is not in the tree or the target is the dragged item itself. `False` if the parent from `DropDest` is the dragged item itself or under it |
| `UpdateInternalDrag(X, Y)` | Inside the tree, if `CalcDrop` and `CanDropItem` pass: `FDropOk := True`, remember the target and position, `ShowIndicator`, cursor `crDrag`. Otherwise `HideIndicator`, `crNoDrop` |
| `EndInternalDrag(drop)` | `FDragActive` and `FDragArmed := False`, `MouseCapture := False`, restore the cursor. If not dropping, `FDropOk := False`. If over a component in the same application, 11.4. `FinishInternalDrop` |
| `FinishInternalDrop` | `FDragItem := nil`, `HideIndicator`, `EndDragTimer`. If `FDropOk` and the target is nil or in the tree, `DoDropItem(item, target, position)` |

- On release, the item is inserted at the position where the line/frame was last shown (to match what was visible).

`DragTimer` (100ms; `BeginDragTimer` sets `FHoverItem := nil` and starts it):

1. If the mouse is within the tree's horizontal range and within 16px (converted from 96dpi) of the top edge, `WM_VSCROLL SB_LINEUP`; within 16px of the bottom edge, `SB_LINEDOWN`.
2. During a drag inside the component, if the mouse is inside the tree, `UpdateInternalDrag` (redraws the line after scrolling).
3. If `CalcDrop` points inside a closed folder, when the same folder has continued for 1000ms, `Expanded := True` (saved through the expand/collapse notification).

### 11.4 Dragging Outside

`DragMoveTo(X, Y)` (X and Y are tree coordinates):

| Mouse position | Processing |
|---|---|
| Inside the tree | `LeaveAppTarget`, `UpdateInternalDrag` |
| Same application (the process of the window from `WindowFromPoint` is its own) | `FDropOk := False`, `HideIndicator`. `C := FindDragTarget(screen position, False)` (TCBookmark and the components inside it become nil; `IsOwnPart`). If `C` exists, `TCBControlAccess(C).OnDragOver` is nil and `EditorOf(C)` (11.5) is not nil, it is "over an open target" in 11.5. If `C` is nil (a window that is not an LCL component, such as a window created by WebView2), `AppControlOf(W)` is not `IsOwnPart`, and its `EditorOf` is a TCMonacoEditor or a TCTabBrowser, it is likewise "over an open target". Otherwise, as follows (same as 1.0): if `FEditorTarget` exists, `LeaveAppTarget`. If `C` differs from before, `LeaveAppTarget` and `dsDragEnter`; if the same, `dsDragMove`. If `C` exists, `TCBControlAccess(C).DragOver(Self, X, Y, state, FAppAccept)`. `crDrag` if it accepts, otherwise `crNoDrop` |
| A window of another process, with a window of its own process among its parents (such as the WebView2 inside a TCMonacoEditor or a TCTabBrowser) | If `EditorOf(AppControlOf(W))` (11.5) is a TCMonacoEditor or a TCTabBrowser, `FDropOk := False`, `HideIndicator`, and "over an open target" in 11.5. Otherwise, the same as "Outside the application" below |
| Outside the application | `LeaveAppTarget`. If `CanOleDrag(FDragItem)` (a URL, or a file that exists), `StartOleDrag`; otherwise `crNoDrop` (the drag continues) |

`LeaveAppTarget`: if `FAppTarget` exists, detach it and notify `DragOver(…, dsDragLeave, …)`. If `FEditorTarget` exists, `RemoveFreeNotification(FEditorTarget)`, `FEditorTarget := nil`, `FEditorFile := ''` (nothing is notified to the editor).

The same-application component in `EndInternalDrag`:
- When `FEditorTarget` exists: when dropping and `FEditorFile` is not empty, take `E := FEditorTarget` and `P := FEditorFile`, then `LeaveAppTarget` and `OpenInDropEditor(E, P)` (11.5). If not dropping, `LeaveAppTarget`.
- Otherwise (same as 1.0): when dropping and `FAppAccept`, detach the component and then call `DragDrop(Self, X, Y)` (exceptions go to `Application.HandleException`). It is called before `FinishInternalDrop`, so `DragItem` can be used inside `OnDragDrop` as well. If not dropping, `LeaveAppTarget`.

`StartOleDrag`:

1. End the drag inside the component (`FDragActive`, `FDragArmed` and `FDropOk := False`, `MouseCapture := False`, `HideIndicator`, `EndDragTimer`, restore the cursor). TCBookmark's data is not changed.
2. `FOleDragging := True` (not accepted by its own tree; 11.1).
3. URL: `SHDoDragDrop(FTree.Handle, …)` with `TCBookmarkUrlData.Create(name, URL)` and effects copy and link.
4. File: `SHDoDragDrop` with `CBGetShellDataObject` (`ILCreateFromPathW` → `SHBindToParent` → `GetUIObjectOf(IDataObject)`; the same shell data as Explorer) and the link effect only (a shortcut is created; no copy or move).
5. In finally, `FOleDragging := False`, `FDragItem := nil`.

- `SHDoDragDrop` does not return until the drop or cancel. Esc and the right button are handled by the shell. No drag image is shown.
- After moving to the OLE drag, it cannot be passed to LCL components (an OLE drag does not reach LCL components).

`TCBookmarkUrlData`:

| No | Format | Contents |
|---|---|---|
| 0 | `FileGroupDescriptorW` | One file. `dwFlags := FD_LINKUI ($8000)`, the name is `CBSafeFileName(name, host) + '.url'` |
| 1 | `FileContents` (`lindex` 0 or -1) | `[InternetShortcut]` CRLF `URL=(CBUrlToAscii(URL))` CRLF (ANSI) |
| 2, 4 | `UniformResourceLocatorW`, `CF_UNICODETEXT` | URL (UTF-16, with #0) |
| 3 | `UniformResourceLocator` | `CBUrlToAscii(URL)` (with #0) |

- All are `TYMED_HGLOBAL`. `GetData` calls `GlobalAlloc` each time and hands it over (the receiver frees it). `QueryGetData` returns `S_OK` if the format exists. `EnumFormatEtc` uses `SHCreateStdEnumFmtEtc` for `DATADIR_GET` only. `GetDataHere`, `GetCanonicalFormatEtc` and `SetData` are `E_NOTIMPL`, and the `DAdvise` family is `OLE_E_ADVISENOTSUPPORTED`.
- `CBSafeFileName`: `Trim`, `\ / : * ? " < > |` and control characters become `_`, strip trailing `.` and spaces, up to 200 characters. If empty, the host's `CBHostFileKey`; if that is also empty, 'link'.
- `CBUrlToAscii`: turns bytes of 128 or more into `%XX`.

### 11.5 Dropping onto an Editor or Browser

When a file item is dropped onto a TCSynEdit, TCsEditor or TCMonacoEditor in the same application, it is opened with the same behavior as when that file is dropped from Explorer. When a URL or file item is dropped onto a TCTabBrowser in the same application, it is opened in a new tab (the same as "Open in Browser in New Tab" in the right-click menu). No application code is needed. If the application has written `OnDragOver` on the drop target, that is used instead (11.4; same as 1.0). These four components are together called "open targets".

| Function / procedure | Processing |
|---|---|
| `EditorOf(C): TControl` | Follows `Parent` from `C`. If a TCsEditor, TCMonacoEditor or TCTabBrowser is found on the way, returns it. Otherwise returns the first TCSynEdit found on the way. If none, nil. The page editors inside a TCsEditor inherit from TCSynEdit, so the TCsEditor is found first (the file is not loaded directly into an inner editor) |
| `AppControlOf(W): TControl` | Follows `GetParent` from `W` and returns the component of the first window whose `GetWindowThreadProcessId` process is its own and for which `FindControl` returns a component. If none, nil. The WebView2 windows inside a TCMonacoEditor or TCTabBrowser include windows of another process and windows that WebView2 created in its own process (not LCL components), so it climbs up to an LCL component |
| `DropFileOf(It): string` | '' if `It` is nil or its kind is not `bkFile`. `P := FLocation`. If the extension is `.lnk` (case-insensitive), `P := CBResolveLink(P)`. '' if `P` is empty, `FileExists(P)` is `False`, or `DirectoryExists(P)` is `True`. Otherwise `P` |
| `DropLocationOf(E, It): string` | What to open in the open target `E`. If `E` is a TCTabBrowser: for a URL item, `FLocation`; for a file item, `CBPathToFileUrl(DropFileOf(It))` if `DropFileOf(It)` is not empty; otherwise ''. If `E` is an editor, `DropFileOf(It)` |
| `SetEditorTarget(E)` | If `FAppTarget` exists, notify `dsDragLeave` and detach it (`FAppTarget := nil`, `FAppAccept := False`). If `E` differs from `FEditorTarget`: if there was a previous one, `RemoveFreeNotification`; `FEditorTarget := E`, `FreeNotification(E)`, `FEditorFile := DropLocationOf(E, FDragItem)`. The cursor is `crDrag` if `FEditorFile` is not empty, `crNoDrop` if it is empty |
| `OpenInDropEditor(E, P)` | The table below. Exceptions are caught and "Cannot open: (P : reason)" (`mtError`; the same message as 9.3) is shown |

How `OpenInDropEditor` opens it (for editors, the same as each component's behavior when a file is dropped from Explorer):

| Kind of `E` | Processing |
|---|---|
| TCSynEdit | If `OnDropFilesEvent` exists, `OnDropFilesEvent(E, [P])`; otherwise `LoadFromFile(P)`. Then `SetFocus` |
| TCsEditor | `L := TStringList` (one line, `P`), `Handled := False`. If `OnFileDrop` exists, `OnFileDrop(E, L, Handled)`. If not `Handled` and `OpenDroppedFiles` is `True`, `SetFocus` when `OpenFile(P) >= 0`. `L` is freed in finally |
| TCMonacoEditor | Same as TCsEditor |
| TCTabBrowser | `Add(P)` (adds a new tab at the end, opens `P` and shows that tab; the same as the new tab of `OpenInBrowser` in 9.3). Then `SetFocus` |

- Only the public properties and methods of each component are used (policy 6). The open target components are left untouched.
- It is called after the mouse button is released (inside `EndInternalDrag`; mouse capture has already been released).
- Over an editor, for a URL, folder, separator or missing file, `DropLocationOf` is '', so `crNoDrop`. Over a TCTabBrowser, a folder, separator or missing file gives ''. Nothing happens when it is dropped.
- TCSynEdit holds only one document, so if there is no `OnDropFilesEvent`, the current content is replaced (the same as when dropped from Explorer).
- Over the WebView2 of a TCMonacoEditor or TCTabBrowser, the drag does not switch to an OLE drag (11.4). Therefore "dropping a URL item onto a TCMonacoEditor opens a temporary `.url` file in a tab", which happened in 1.0, no longer happens.
- The item is opened in the component it was dropped on, regardless of the `TargetBrowser` and `TargetEditor` settings.

## 12. Import and Export

### 12.1 Import

`ImportFromFile(F)`:

1. `CBReadFileText`. If unreadable, `False` with "Cannot import: (reason)".
2. Create the folder "Import yyyy-mm-dd" (in the open state) and `ParseHtml(contents, folder)`.
3. If 0 URLs/files were inserted, free the folder and return `False`.
4. Append to the end of `Root`, `Changed(folder)`, `True`.

`ParseHtml(S, destination)`: reads from `<` to the next `>` as a single tag (a `>` inside quotes is skipped; `<!-- -->` is skipped; tag names are alphanumeric and case-insensitive). The parent to insert into is the top of the stack (the destination if empty).

| Tag | Processing |
|---|---|
| `<DL>` | Push the folder of the preceding `<H3>` if there is one, the destination if the stack is empty, otherwise the current parent. Forget the preceding folder |
| `</DL>` | Pop one from the stack |
| `<H3>` | Create a folder named with the characters up to `</h3` (tags stripped, character references restored). If `ADD_DATE` (seconds since 1970) exists, it is the registration date/time. Insert into the current parent and remember it as the preceding folder |
| `<A>` | Forget the preceding folder. Read `HREF` (character references restored), `ICON`, and the characters up to `</a`. If `ICON` is `data:…;base64,…` and that host's icon does not exist yet, first `SaveHostIcon` (so that it is not fetched). `NewLink(characters, HREF)` (skipped if it cannot be decided). If `ADD_DATE` exists, it is the registration date/time. Insert into the current parent and count it |
| `<HR>` | Forget the preceding folder. Insert a separator |

- Notation without closing tags (`<DT>`, `<p>`) is ignored as other tags.
- `CBTagAttr(tag, name)`: looks only for `name=` preceded by whitespace (so `ICON` and `ICON_URI` are not mixed up). The value is `"…"`, `'…'`, or up to whitespace or `>`.

`ImportWithDialog`: `TOpenDialog` (HTML filter, `ofFileMustExist`). If `ImportFromFile` is `False` and the file exists, "No bookmarks were found."

### 12.2 Export

`ExportToFile(F)`: writes the following to a `TStringList` (`LineBreak := CRLF`), and `CBWriteFileText` (UTF-8, no BOM). If it cannot be written, `False` with "Cannot export: (reason)".

```html
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
    (WriteLevel(Root, indent of 4 characters))
</DL><p>
```

| Kind | What is written |
|---|---|
| URL | `<DT><A HREF="URL" ADD_DATE="seconds" ICON="data:image/png;base64,…">name</A>` (ICON only if the icon file exists; .ico is `data:image/x-icon`) |
| File | `<DT><A HREF="(CBPathToFileUrl)" ADD_DATE="seconds">name</A>` |
| Separator | `<HR>` |
| Folder | `<DT><H3 ADD_DATE="seconds">name</H3>`, `<DL><p>`, contents (indent +4), `</DL><p>` |

- Name and HREF go through `CBHtmlEscape`. `ADD_DATE` is `DateTimeToUnix`.

`ExportWithDialog`: `TSaveDialog` (HTML filter, default extension html, name bookmarks.html, `ofOverwritePrompt`).

## 13. Cut, Copy and Paste

| Procedure | Processing |
|---|---|
| `DoMenuCut(It)` | Does nothing if not in the tree. Free `FClip`, `FCutItem := It` (left in its original place), `CBPutClipboardText(It)` |
| `DoMenuCopy(It)` | Free `FClip`, `FCutItem := nil`, `FClip := It.Clone` (folders with their contents), `CBPutClipboardText(It)` |
| `DoMenuPaste(It)` | Does nothing if searching. nil if `It` is not in the tree. `InsertPos`. For cut: if `FCutItem` is not in the tree, cancel and exit. Does nothing if the parent to insert into is `FCutItem` itself or under it. `FCutItem := nil`; if `MoveInternal` succeeds, `Changed`. For copy: `FClip.Clone` (a copy of the copy so it can be pasted any number of times), `RefreshMissing(duplicate, True)`, `DoInsert`, `Changed` |
| `CBPutClipboardText(It)` | Collects the locations of URLs/files (folders in order of their contents), joins them with CRLF and sets `Clipboard.AsText`. Nothing is put if there are none. Clipboard exceptions are ignored |

## 14. Processing on Receiving an Operation (protected)

Mouse, key, menu and drop operations only call the following methods.

| Method | Operation that calls it | Processing |
|---|---|---|
| `DoItemClick(It)` | Left click, Enter | Folder: if not searching and a row exists, toggle expand/collapse. URL: if `TargetBrowser` exists, `OpenItem(btBrowser, False)`. File: if `TargetEditor` exists, `OpenItem(btEditor, False)`. Separator or nil: nothing |
| `DoMenuOpen(It, target, new)` | The 4 open items | `OpenItem` |
| `DoMenuEdit(It)` | Edit, F2 | Does nothing for a separator or if not in the tree. A folder uses "Edit folder name" and edits only the name. A URL or file uses "Edit bookmark" and edits name and location. Applies `CBClassifyLocation` to the location and swaps the kind and location (the kind may change). For files, `FFileMissing`; for URLs, `RequestFavicon` if the host changed. `Changed(It)` |
| `DoMenuDelete(It)` | Delete, Delete key | Only for folders, ask "Delete folder "name" and its n items?" (`DescendantCount`). If Yes, `DeleteItem` |
| `DoMenuCut`, `DoMenuCopy`, `DoMenuPaste` | Cut, Copy, Paste | Chapter 13 |
| `DoMenuAddBookmark(It)` | Add Bookmark | Does nothing if searching. "Add bookmark" (empty). `NewLink`, `InsertPos`, `DoInsert`, `Changed` |
| `DoMenuAddFolder(It)` | Add Folder | "Add folder" (initially "New folder"). Inserted in the same way |
| `DoMenuAddSeparator(It)` | Separator | Inserts a separator in the same way |
| `DoDropItem(It, target, position)` | Dragging inside the component | Does nothing if searching or `CanDropItem` fails. `DropDest`, and if `MoveInternal` succeeds, `Changed(It)` |
| `DoDropFiles`, `DoDropUrl` | Drops from outside | 11.2 |

## 15. Points to Check When Investigating Defects

| Symptom | Where to look |
|---|---|
| Nothing appears at startup | `FDataLoaded` in `CreateWnd`, the location in `LoadData` (7.1, 7.2) |
| Not saved | `MoveFileExW` in `SaveData`, `FSaveErrorShown` (7.3). Whether the EXE's location is writable |
| bookmarks.json.broken-… is created | The exception in `LoadData` (the JSON structure) (7.2) |
| `OnSelectionChange` fires too often or not at all | `FUpdating` and where `CheckSelection` is called (7.5) |
| A missing file is not grayed out | When `RefreshMissing` is called (7.6), `TreeDrawItem` (8.2) |
| Favicon does not appear | `FFetchTried` in `RequestFavicon`, the thread's status 200 and the shape of the contents, `SaveHostIcon` (8.3) |
| Dragging does not move | The threshold in `TreeMouseMove`, `CanDropItem`, `FDropOk` in `FinishInternalDrop` (11.3) |
| Cannot drop from outside | `RegisterDragDrop` in `TCBookmarkTree.CreateWnd`, the conditions in `DragEnter` (searching, during its own OLE drag) (11.1) |
| Dropped but not registered | `AsyncExternalDrop`, whether `FPendingTarget` is in the tree (11.1) |
| Cannot drag outside | `WindowFromPoint` in `DragMoveTo`, `CanOleDrag`, `CBGetShellDataObject` (11.4) |
| Not passed to a component in the same application | `FindDragTarget` and `IsOwnPart`, the component's `OnDragOver` (11.4) |
| Not opened when dropped onto an editor or browser | Whether `EditorOf` finds it, whether the drop target's `OnDragOver` is nil (11.4), whether `DropLocationOf` is '' (a URL onto an editor, a missing file, or a `.lnk` whose link target cannot be read) (11.5) |
| Switches to an OLE drag over a TCMonacoEditor or a TCTabBrowser | Whether `AppControlOf` climbs up to an LCL component, whether its `EditorOf` is a TCMonacoEditor or a TCTabBrowser (11.4, 11.5) |
| The file is loaded directly into a page inside a TCsEditor | Whether `EditorOf` looks for the TCsEditor first (11.5) |
| A file is not opened in another tab, or an error occurs | The order in `OpenInEditor` (9.3) |
| Import count is 0 | How `ParseHtml` reads tags, HREFs that `NewLink` cannot decide (12.1) |

## 16. Changes in This Version (1.1)

Steps for changing the code. Not included in the user manual.

### 16.1 Now and After the Change

| No | Item | Current (1.0) behavior / problem | After the change (1.1) | Reason for the change | Risk |
|---|---|---|---|---|---|
| 1 | File item → TCSynEdit, TCsEditor | Not accepted (×) unless the application writes `OnDragOver` and `OnDragDrop`. For TCsEditor, code is even needed to reattach the events to each page's editor | Opened with the same behavior as when dropped from Explorer, without writing any code (11.5) | To make application code unnecessary for "editing the file the bookmark points to" | Places that used to be × now open the file (intended). TCSynEdit replaces its current content (the same as when dropped from Explorer) |
| 2 | File item → TCMonacoEditor | Over the WebView2 it counts as "outside the application" and switches to an OLE drag (link effect only). TCMonacoEditor accepts only copy, so nothing happens. It cannot be fixed with application code either | If following the parent windows shows it is a TCMonacoEditor of its own application, it does not switch to OLE and opens the file by 11.5 | Same as 1 | If identification fails, the behavior is the same as 1.0 (OLE drag) |
| 3 | URL item → TCMonacoEditor | Through the OLE drag, a temporary `.url` file (`name.download`) is opened in a tab | Not accepted (×) | Dropping onto an editor is for editing a file; URLs are not covered | None |
| 4 | Component on which the application wrote `OnDragOver` | The application code accepts it | Unchanged (the application code is used first) | Do not change a working I/F (RULES 8) | None |
| 5 | uses | implementation goes up to `… LazUTF8` | Add `cSynedit, uCsEditor` | To identify types in 11.5 | Inside the same cx package, so the package structure does not change |

### 16.2 What to Change

| No | File | Change |
|---|---|---|
| 1 | `uCbookmark.pas` | Add `cSynedit, uCsEditor` to the implementation uses (chapter 2) |
| 2 | `uCbookmark.pas` | Add the fields `FEditorTarget` and `FEditorFile` (5.2) |
| 3 | `uCbookmark.pas` | Add `EditorOf`, `AppControlOf`, `DropFileOf`, `SetEditorTarget` and `OpenInDropEditor` to private (11.5) |
| 4 | `uCbookmark.pas` | Change `DragMoveTo`, `LeaveAppTarget` and `EndInternalDrag` as in 11.4 |
| 5 | `uCbookmark.pas` | In `Notification`, set `FEditorTarget` to nil when it is removed (6.5) |
| 6 | `uCbookmark_reg.pas` and the files of other components | Unchanged |

- The published properties, methods and events are not changed.

## 17. Changes in This Version (1.2)

Steps for changing the code. Not included in the user manual.

### 17.1 Now and After the Change

| No | Item | Current (1.1) behavior / problem | After the change (1.2) | Reason for the change | Risk |
|---|---|---|---|---|---|
| 1 | URL item → TCTabBrowser | The area over the WebView2 is treated as "outside the application" or as a window that is not an LCL component, and nothing happens (confirmed with the AnchorDocking test application) | Opened in a new tab (11.5) | So that bookmarks can be dragged onto a browser and opened in an application whose functions are split into forms with AnchorDocking | If identification fails, the behavior is the same as 1.1 (nothing happens, or an OLE drag) |
| 2 | File item → TCTabBrowser | Same as 1 | Converted to `file:///…` and opened in a new tab (the same as "Open in Browser in New Tab" in the right-click menu) | Same as 1 | None |
| 3 | Identifying open targets (`EditorOf`) | TCSynEdit, TCsEditor, TCMonacoEditor | Add TCTabBrowser | For 1 and 2 | None |
| 4 | What to open (`FEditorFile`) | Always `DropFileOf` (a file) | `DropLocationOf`: a URL for a TCTabBrowser; a file for an editor, as before | Because a TCTabBrowser opens a URL | None |
| 5 | Component on which the application wrote `OnDragOver` | The application code accepts it | Unchanged | Do not change a working I/F (RULES 8) | None |

### 17.2 What to Change

| No | File | Change |
|---|---|---|
| 1 | `uCbookmark.pas` | Make `EditorOf` find a TCTabBrowser as well (11.5) |
| 2 | `uCbookmark.pas` | Add `DropLocationOf` to private and use it in `SetEditorTarget` (11.5) |
| 3 | `uCbookmark.pas` | Add how a TCTabBrowser opens it to `OpenInDropEditor` (11.5) |
| 4 | `uCbookmark.pas` | Add TCTabBrowser to the WebView2 identification in `DragMoveTo` (11.4) |
| 5 | Other files | Unchanged |

- The published properties, methods and events are not changed.
