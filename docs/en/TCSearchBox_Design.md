# TCSearchBox Design Document

Author: aotan083
Date: 2026-11-17
Version: 1.0

---

## 1. Purpose and Policy

- A component (`TCSearchBox`) equivalent to the Windows Explorer search box. It works together with TCListView and TCTreeView.
- The search itself uses a separate component, `TCFindFile` (`TCFindFile_Design.md`; unit `uCFindFile.pas`). This component holds one inside it.
- The address bar is a separate component (`TCAddressBar`; `TCAddressBar_Design.md`). The unit is separate too (`uCSearchBox.pas`).
- A search starts with `Enter` (it does not search on every keystroke).
- File names can be searched by contains, wildcard, or regular expression (the matching is done by `TCFindFile`).
- Results are shown in TCListView (a "search result view" is added to TCListView; Chapter 7).

### 1.1 Not Included

- Searching the contents of files.
- Narrowing by date, size, or type.
- Saving search conditions.
- Using the Windows search index.
- Searching on every keystroke.
- Linux / macOS (Windows 11 only).

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCSearchBox.pas` | cx (run time) | `TCSearchBox` (the input field) |
| `uCFindFile.pas` | cx (run time) | `TCFindFile` (a separate design document) |
| `CListView.pas` | cx (run time) | What is added to `TCListView` (Chapter 7) |
| `uCXReg.pas` (`source\design`), `cnavigation_icon.lrs` | cxdsgn (design time) | Registration in the [CX] palette and the icons (the same as in Chapter 2 of `TCAddressBar_Design.md`) |
| `uCXLang.pas` | cx (run time) | Strings are added (Chapter 5) |

- uses of `uCSearchBox`: `Classes, SysUtils, Types, Math, Windows, Controls, Graphics, Forms, Menus, StdCtrls, ExtCtrls, LCLType, LCLIntf, LMessages, uCXLang, uCTitleBar (CXSetSymbolFont, CXBlendColor), uCFindFile, CListView, CTreeView`.
- No initialization or finalization.
- The packages remain two: cx and cxdsgn.

## 3. How It Works Together

```
TCTreeView -- Path --+                    +- BeginResults, AddResults, EndResults -> TCListView (search result view)
                     +- TCSearchBox ------+
TCListView -- Root --+   |                +- search: TCFindFile (separate thread)
                         +- input field, options
```

| Item | How it is decided |
|---|---|
| Connection | `ListView: TCListView`, `TreeView: TCTreeView` (just chosen; `FreeNotification`). It can search without a `ListView` (results are received by yourself with `OnSearchResult`; 4.3) |
| The folder to search | If there is a `ListView` and the search result view is shown, the folder searched before (`ListView.Root`). Otherwise `ListView.Root`. If none, `TreeView.Path`. If both are empty (a group such as Quick access), it does not search and reports an error (`sSbErrNoFolder`) |
| Results | After `ListView.BeginResults(folder to search)`, found items are added with `ListView.AddResults` |
| Ending the search | `x`, `Esc`, or emptying the text and pressing `Enter`: `ListView.EndResults`. When the `ListView` moved by itself (opening a folder, going back, selecting in the tree), this component learns of it through the "folder changed notification" (`AddFolderLink`) of 3.1 in `TCAddressBar_Design.md`, clears the text, and stops searching (4.2). No timer is used |

## 4. TCSearchBox

`TCSearchBox = class(TCustomControl)`. Unit `uCSearchBox`.

### 4.1 Properties, Methods, Events

| Name | Type | Default | Exposure | Contents |
|---|---|---|---|---|
| `ListView` | `TCListView` | nil | published | The list that shows the results (Chapter 3) |
| `TreeView` | `TCTreeView` | nil | published | The source of the folder to search (Chapter 3) |
| `Text` | `string` | '' | published | The text typed (the name to search for). This component has its own, separate from `TControl.Text` (reading and writing it reads and writes the text of the input field `FEdit`) |
| `TextHint` | `string` | '' | published | The faint text shown when empty. If empty, automatically "Search (folder name)" (`sSbHint`); if the folder is not known, "Search" (`sSbHintNone`) |
| `MatchMode` | `TCFindMatchMode` | `fmContains` | published | The matching method (`TCFindFile_Design.md` 3.5) |
| `CaseSensitive` | `Boolean` | `False` | published | Whether upper and lower case are distinguished |
| `IncludeSubfolders` | `Boolean` | `True` | published | Whether to search subfolders too |
| `SearchHidden` | `Boolean` | `False` | published | Whether to search hidden and system items too |
| `MaxResults` | `Integer` | 10000 | published | The maximum number of results |
| `ShowOptionsMenu` | `Boolean` | `True` | published | Whether pressing the magnifier opens the options menu |
| `Searching` | `Boolean` | - | public (read) | Whether a search is running |
| `ResultCount` | `Integer` | - | public (read) | The number found in the current search |
| `Finder` | `TCFindFile` | - | public (read) | The search component (held by this component; there is no need to use it directly) |
| `Color`, `Font`, `Align`, `Anchors`, `BorderSpacing`, `Constraints`, `Enabled`, `PopupMenu`, `ShowHint`, `TabOrder`, `TabStop`, `Visible`, `Width`, `Height` | | | published | `Color` is `clWindow` if `clDefault`. The default of `Height` is 32 (96 dpi; enlarged by the display scale) and the default of `Width` is 260 |

| Method | Contents |
|---|---|
| `procedure Search` | The same as `Enter`. Starts searching with the current `Text` (4.2) |
| `procedure StopSearch` | Stops the search if it is running (the results remain) |
| `procedure ClearSearch` | Stops searching, empties `Text`, and ends the search result view of `ListView` |
| `procedure SetFocus` (`override`) | Moves the focus to the input field and selects everything |

| Event | When |
|---|---|
| `OnChange(Sender)` | When `Text` changed (typing, writing `Text`) |
| `OnSearchStart(Sender)` | When the search started |
| `OnSearchResult(Sender, const APath, AIsDir)` | Each time one item is found. For when you want to receive items yourself, separately from adding them to `ListView` (fires even without a `ListView`) |
| `OnSearchFinished(Sender, AFound, AReason)` | When the search ended (including when stopped and when the limit was reached) |
| `OnSearchError(Sender, const AMessage)` | When it could not start (the regular expression is not valid, there is no folder to search). If not set, the frame turns red and the message becomes the hint (`Hint`) |

### 4.2 Processing

**Layout**

```
[ input field ................. ][x][magnifier / spinner]
```

| Part | Contents |
|---|---|
| Input field | A `TEdit` (without a frame) is placed inside. Text, focus, IME, copy, and paste behave as the `TEdit` does |
| "x" | Shown only when `Text` is not empty and a search is not running. Pressing it calls `ClearSearch`. Width `Scale96ToFont(28)` |
| Magnifier | When not searching. `U+E721`. Width `Scale96ToFont(32)`. If `ShowOptionsMenu` is true, pressing it shows the options menu (below) |
| Spinner | While searching. A rotating arc is drawn where the magnifier is (`FSpinTimer` advances the angle every 100 milliseconds). Pressing it calls `StopSearch` |

- The frame is a 1px `clBtnShadow`. `clHighlight` (the accent blue if too dark) when the input field has the focus. `clRed` when there is an error.

**Starting (`Search`, `Enter`)**

1. Let `S` be the text of `Text` with the spaces at the start and end removed. If `S` is empty, `ClearSearch`.
2. Decide the folder to search (Chapter 3). If it cannot be decided, `OnSearchError(sSbErrNoFolder)`.
3. Put `Root`, `Pattern := S`, `MatchMode`, `CaseSensitive`, `IncludeSubfolders`, `SearchHidden`, and `MaxResults` into `Finder` (`TCFindFile`). If `CheckPattern` is false, `OnSearchError(sSbErrRegex + message)`.
4. If a search is running, `Finder.Stop` and wait for it to end (`WaitFor`).
5. If there is a `ListView`, `ListView.BeginResults(folder to search)`. Empty `FPending`. `ResultCount := 0`.
6. `Finder.Start`. If it started, `Searching := True`, `OnSearchStart`, start the spinner, and start `FFlushTimer` (100 milliseconds; to add the found results to the list in batches).

**When found / when finished**

| Procedure | Processing |
|---|---|
| `Finder.OnFound` | Increase `ResultCount` by 1. Add the path to `FPending`. `OnSearchResult` |
| `FFlushTimer` | If `FPending` has contents, `ListView.AddResults(FPending)` and `FPending.Clear` |
| `Finder.OnFinished` | `AddResults` the `FPending` and empty it. `Searching := False`, stop the spinner and `FFlushTimer`. `OnSearchFinished`. Even if there is no `ListView` and there are 0 results, nothing is shown |

**Keys and mouse**

| Operation | Action |
|---|---|
| `Enter` | `Search` |
| `Esc` | If a search is running, `StopSearch`. Otherwise, if `Text` is not empty, `ClearSearch`. If neither, nothing |
| `Ctrl+E`, `Ctrl+F` (when the focus is on the `ListView`, `TreeView`, or this component of the same form) | Moves the focus to this component (`SetFocus`). Received with `Application.AddOnKeyDownHandler` (the same rule as 5.3 of `TCAddressBar_Design.md`) |
| Pressing the magnifier (when not searching) | The options menu (below). Nothing happens if `ShowOptionsMenu` is false |
| Pressing the spinner | `StopSearch` |
| Pressing "x" | `ClearSearch` |

**The options menu (`TPopupMenu`; built every time it is shown)**

| Item | Action |
|---|---|
| (o) Contains / (o) Wildcard (* ?) / (o) Regular expression | Changes `MatchMode` (radio) |
| - | Separator |
| [x] Match case | Toggles `CaseSensitive` |
| [x] Include subfolders | Toggles `IncludeSubfolders` |
| [x] Include hidden and system files | Toggles `SearchHidden` |

- Right after the menu is changed, it does not search automatically even if `Text` is not empty (search with `Enter`).

**The folder changed notification (`FolderLinkChanged`; received with `AddFolderLink` of `ListView` and `TreeView`; no timer)**

- If the search results were shown in `ListView` (`FResultsActive`) but `ListView.ResultsMode` has become false (the list moved by some other operation; when `EndResults` was called by this component itself, no results are being shown, so nothing is done): `Finder.Stop`, `Text := ''` (`OnChange` is fired), and clear the mark of showing results.
- The faint text of `Text` (when `TextHint` is empty) is rebuilt when the name of the folder to search changes (`ListView.Root`, `TreeView.Path`).

### 4.3 When There Is No `ListView`

Even without a `ListView`, it can search and receive the results with `OnSearchResult` (you show the results yourself). `BeginResults` and `AddResults` are not called. The folder to search is that of `TreeView` if there is one, otherwise `Finder.Root` (the application sets `Finder.Root` beforehand).

When the search was made on the folder of `ListView` or `TreeView`, `Finder.Root` is returned to empty after the search ends (so that the previous folder is not searched even if `ListView` and `TreeView` are removed afterwards). A value that the application put into `Finder.Root` beforehand is left as it is.

### 4.4 Creating and Destroying

- `Create`: `Finder := TCFindFile.Create(Self)` (the `Owner` is this component; it is not saved in the form). Connect the events. `csOpaque` in `ControlStyle`. At run time, timers (`FSpinTimer`, `FFlushTimer`; enabled only while searching; there is no timer for monitoring folders). When `ListView` and `TreeView` are set (and when they change), `AddFolderLink` (`RemoveFolderLink` when removing). `Application.AddOnKeyDownHandler`.
- `Destroy`: `RemoveOnKeyDownHandler`. `Finder.Stop` (the `Destroy` of `Finder` waits for the end). Remove `FreeNotification`.
- `Notification`: when `ListView` or `TreeView` is destroyed, set it to nil. If `ListView` is destroyed during a search, stop searching.

## 5. Strings (Added to `uCXLang`)

| ID | Japanese | English |
|---|---|---|
| `sSbHint` | %s の検索 | Search %s |
| `sSbHintNone` | 検索 | Search |
| `sSbMenuContains` | 部分一致(&P) | Contains(&P) |
| `sSbMenuWildcard` | ワイルドカード（* ?）(&W) | Wildcard (* ?)(&W) |
| `sSbMenuRegex` | 正規表現(&R) | Regular expression(&R) |
| `sSbMenuCase` | 大文字と小文字を区別する(&C) | Match case(&C) |
| `sSbMenuSub` | サブフォルダーを含める(&S) | Include subfolders(&S) |
| `sSbMenuHidden` | 隠しファイル・システムファイルを含める(&H) | Include hidden and system files(&H) |
| `sSbClear` | 検索を消す | Clear search |
| `sSbStop` | 検索を中止 | Stop search |
| `sSbErrRegex` | 正規表現が正しくありません：%s | The regular expression is not valid: %s |
| `sSbErrNoFolder` | 検索するフォルダーがありません | There is no folder to search |
| `sSbErrNoRoot` | 検索を始めるフォルダーがありません：%s | The folder to start from was not found: %s |
| `sLvColFolder` | フォルダー | Folder |

They are added at the end of the existing order (both in `TCXStr` and in `CXTable`). `sLvColFolder` is the header of the "Folder" column of TCListView (Chapter 7). They are added together with the strings of Chapter 6 of `TCAddressBar_Design.md`.

## 6. Design Time

- `TCSearchBox`: draws the frame, the faint text (`TextHint`; "Search" when automatic), and the magnifier. The search is not run at design time. It appears in the [CX] palette.
- For the design time of `TCFindFile`, see Chapter 5 of `TCFindFile_Design.md`.

## 7. Additions to TCListView

Added to `TCListView`, whose behavior has been verified. The current behavior is not changed (when it does not show search results and does not take out the history, the behavior is exactly the same).

### 7.1 Now and After the Change

| Item | Now | After the change | Reason for the change | Risk |
|---|---|---|---|---|
| Search result view | None (only the contents of the folder of `Root`) | A "search result view" (`ResultsMode`) is added (7.2) | To show the results of `TCSearchBox` in the list | The 15 calls of `GetPathFromItem` are replaced with `ItemPath` (new). In the normal view it returns the same value as `GetPathFromItem`, so behavior does not change |
| Taking out the history | Only `CanGoBack`, `GoBack`, `GoForward`. The list is not visible | `GetHistory` and `GoToHistory` are added (7.3) | For the "recent locations" of `TCAddressBar` | It only reads the existing history (`FHistory`, `FHistIndex`) (only added) |
| Sorting and columns of items | 4 columns (name, size, type, date modified) | Only in the search result view, a fifth column "Folder" is added | To show the location | In the normal view there is no fifth column (the automatic width adjustment of columns stays with four columns) |
| What is made public | - | `ResultsMode`, `BeginResults`, `AddResult`, `AddResults`, `EndResults`, `GetHistory`, `GoToHistory` | Same as above | Only added |

### 7.2 Search Result View

| Method / property | Contents |
|---|---|
| `property ResultsMode: Boolean` (read; run time only) | Whether the search results are shown |
| `procedure BeginResults(const AFolder: string)` | Switches to the search result view. 0) When not already shown, first detect the present state (if `Root` was changed just before and has not been detected yet, it would later be regarded as "`Root` was changed from outside" and the search result view would end). 1) If already shown, only clear the contents. 2) Stop monitoring folder changes (`UnregisterFolderNotify`, stop `FNotifyTimer`). 3) Clear all items (`Items.Clear`). 4) Add the "Folder" column (fifth column; the header is `CXT(sLvColFolder)`). 5) `FResultsMode := True`, `FResultFolder := AFolder` (`Root` is not changed). 6) Sorting is name ascending (the same as `SortBy(0, True)`, but without reloading) |
| `procedure AddResult(const APath: string)` | Adds one item (the same as calling `AddResults` with one item) |
| `procedure AddResults(AList: TStrings)` | Only in the search result view. After `BeginUpdate`, add an item for each path, then `EndUpdate`. Paths that do not exist or cannot be read are skipped. How items are made is in 7.2.1 |
| `procedure EndResults` | Ends the search result view. 1) Remove the fifth column. 2) `FResultsMode := False`. 3) Clear all items. 4) Rebuild the contents of the folder with `FResultFolder` as `Root` (the same reading as used by the present `NavigateTo`; monitoring is resumed). Nothing happens in the normal view |

**7.2.1 Items of the search results**

| Part | Contents |
|---|---|
| `Caption` | The file name (folder name). `ExtractFileName` |
| `Data` | `TCResultInfo` (a new class; `FullPath`, `IsDir`). It is put in a list held by `TCListView` (`FResultInfos`) and destroyed together when the item is cleared |
| Size | For a file, `GetCellText` of the base class (the same way of writing as the normal view). Empty for a folder |
| Type | For a folder, `CXT(sLvFolderType)`. For a file, the extension (the same as the normal view) |
| Date modified | The same as the present column (`YYYY/MM/DD HH:NN`) |
| Folder | `ExtractFilePath(FullPath)` without the trailing `\` |
| Icon | Added in the same way as the present list (the system icon) |

**7.2.2 Behavior in the search result view**

| Operation | Behavior |
|---|---|
| The path of an item | `ItemPath(Item)` (new; the `FullPath` of `Data` in the search result view, otherwise `GetPathFromItem(Item)`). All 15 present calls of `GetPathFromItem` are replaced with this |
| Double-click, `Enter` | For a folder, `NavigateTo` (the search result view ends). For a file, opens it as now |
| Back, forward, up, `BackSpace`, `NavigateTo` | First `EndResults`, then the present behavior (`NavigateUp` goes to the parent of `FResultFolder`) |
| Context menu | On an item: the same as now (the shell menu; the path is `ItemPath`). On an empty area: only "View" and "Sort". "New" and "Paste" are not shown (because there is no place to put them) |
| Delete, rename, copy, cut | The same as now (the path is `ItemPath`). If the delete or rename succeeded, the item is removed from the list (the folder is not reloaded) |
| Paste, drop (the receiving side) | Not done (there is no place to receive) |
| Dragging out (the sending side) | The same as now (the path is `ItemPath`) |
| Sorting | Name, size, type, date modified, folder (column 4). Whether an item is a folder is taken from `TCResultInfo`, and the others are compared from the text of each column (the disk is not asked). Folders come first, as in the normal view |
| Monitoring of changes | Not done (stopped by `BeginResults`) |
| `Root`, `Path` (working with the tree) | `Root` is not changed. When `Root` is changed from outside, for example by the tree, the search result view is ended by the detection at idle time (`CheckStateChanged`) (columns and item information are cleaned up; the contents have already been reloaded by the base class) |
| "View" and "Sort" on an empty-area right-click | A dedicated menu (`TrackPopupMenu`). It is shown separately from the menu of the normal view |
| Reloading (F5, `DoAsyncRefresh`) | Not done (so as not to erase the results) |
| `Ctrl+Shift+N` (new folder) | Not done |

### 7.3 Taking Out the History

| Method | Contents |
|---|---|
| `function GetHistory(AList: TStrings): Integer` | Puts the whole history into `AList`, newest visit first (the newest is at the top; full paths; forward history is included). Returns the index in `AList` of the current folder (-1 if there is no history). After going back, the forward history is listed before (at smaller indexes than) the current folder |
| `function GoToHistory(AIndex: Integer; const APath: string): Boolean` | Moves to the folder at index `AIndex` of the `AList` of `GetHistory`. It is the same as calling `GoBack` (when `AIndex` is larger) or `GoForward` (when smaller) in succession as many times as the difference from the current index. If folders on the way were deleted, they are removed from the history and skipped, and it advances as far as it could move. `APath` is for confirmation; if it differs from `AList[AIndex]`, nothing is done and `False`. `True` if it could move to the target folder. `False` (nothing done) if `AIndex` is out of range or the same as now |

## 8. Decisions

| Item | Decision |
|---|---|
| Search method | Only its own walk (`FindFirstFileW`). The index is not used |
| How a search starts | Only `Enter`. It does not search on every keystroke |
| Name matching | Contains, wildcard, regular expression. Only file names (folder names) are checked |
| Regular expression | FPC `RegExpr`. UTF-8 as it is. `.` works on bytes (specifying a number of Japanese characters is not possible) |
| Thread | The search runs in a separate thread. Results go to the main thread in batches (50 items or 100 ms). Additions to the list are made in batches every 100 ms |
| Not walking endlessly | Reparse points are not entered. `MaxResults` (default 10000) |
| Folders that cannot be read | Skipped silently |
| Where the results are put | The "search result view" of TCListView (Chapter 7). `Root` is not changed |
| Returning from the results | `x`, `Esc`, emptying and pressing `Enter`, or moving in the list (back, double-click, tree, and so on) |
| Setting options | The magnifier menu (`MatchMode`, `CaseSensitive`, `IncludeSubfolders`, `SearchHidden`). They can also be set with properties |
| Language | `CXT` of `uCXLang` |
| Design time | Only a sample is drawn. The search is not run |

## 9. Where to Look When Investigating Problems

| Symptom | Where to look |
|---|---|
| Pressing `Enter` does not search | Whether the folder to search is decided (Chapter 3). `OnSearchError`. The regular expression (`CheckPattern`) |
| No results at all | `MatchMode` (is it contains?). `SearchHidden`. Read permission of `Root` |
| Results appear late / it freezes | `cFindFlushCount`, `cFindFlushMs`. `BeginUpdate` of `ListView.AddResults` |
| A regular expression with Japanese does not match | That `.` works on bytes (`TCFindFile_Design.md` 3.5) |
| It does not stop although searching | Check of `StopFlag` (6 of 4.1 in `TCFindFile_Design.md`). `OnFinished` after `Stop` |
| The search result view stays and the folder does not change | `ListView.ResultsMode`. The order of `EndResults` and `NavigateTo` (7.2.2) |
| Open, delete, or copy of a result item points to a different folder | `ItemPath`. A forgotten replacement of `GetPathFromItem` (7.1) |
| The thread remains even after the form is closed | Chapter 6 of `TCFindFile_Design.md` |

## 10. Changes in This Version (New)

New components, TCSearchBox and TCFindFile, are made. The behavior of existing components is not changed (only what is added to `CListView.pas`; Chapter 7).

| File | Change |
|---|---|
| `source/uCSearchBox.pas` | New |
| `source/CListView.pas` | The additions of Chapter 7. Also `AddFolderLink` and `RemoveFolderLink` (3.1 of `TCAddressBar_Design.md`). TCTreeView gets the same entry point |
| `source/design/uCXReg.pas`, `source/res/cnavigation_icon.lrs` | Registration and icons (the same as Chapter 10 of `TCAddressBar_Design.md`; the registration of TCFindFile is in `TCFindFile_Design.md`) |
| `source/uCXLang.pas` | Strings are added (Chapter 5) |
| `packages/cx.lpk`, `cx.pas`, `cxdsgn.lpk` | `uCSearchBox` is added |
| `docs/TCSearchBox_Usage.md`, `TCSearchBox_Design.md`, and the same names in `docs/en` | The manual and the English version are made after the code is complete |
