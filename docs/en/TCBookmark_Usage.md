# TCBookmark User Manual

Author: aotan083
Date: 2026-10-29
Version: 1.0

---

## 1. Overview and Classes

A bookmark management component like Firefox's bookmark screen. Place it on a form and just select the TCTabBrowser and TCMonacoEditor to open into in the Object Inspector, and it works. The application does not need to write any code.

```
┌──────────────────────┐
│ Search bookmarks       │ ← Search box
├──────────────────────┤
│ 🌐 Qiita               │ ← URL
│ 📄 memo.md             │ ← File
│ ──────────────── │ ← Separator
│ ▼ 📁 Work              │ ← Folder
│     🌐 NotebookLM      │
└──────────────────────┘
```

- There are two kinds of bookmarks: links to URLs and links to files on the local PC. There are also folders and separators.
- URLs are opened in TCTabBrowser and files in TCMonacoEditor (left click, right-click menu, Enter).
- You can add, edit, delete, cut, copy, paste, make folders and separators, and move by dragging.
- You can search names and URLs/file paths.
- You can register by dropping files, folders, .url files and shortcuts (.lnk) from Explorer, and URLs from a browser.
- Dragging to the desktop or Explorer creates "name.url" for a URL and a shortcut for a file (the same behavior as browsers).
- You can import and export Chrome, Edge and Firefox bookmarks, and HTML files.
- It saves automatically after every operation. On the next start, it is displayed as it was, including the expanded/collapsed state of folders.
- URLs are shown with the site's icon (favicon), and files with the Windows icon.

| Item | Details |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |
| Theme | Drawn with system colors (dark mode is possible with MetaDarkStyle) |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Description |
|---|---|---|---|---|
| `TCBookmark` | `uCbookmark` | cx | `TCustomPanel` | The bookmark management component. Contains a search box and a tree |
| `TCBookmarkItem` | `uCbookmark` | cx | `TObject` | One bookmark (3.2). TCBookmark does both the creating and the deleting |

| Type | Unit | Description |
|---|---|---|
| `TCBookmarkKind` | `uCbookmark` | Kind. `bkUrl` (URL), `bkFile` (file), `bkFolder` (folder), `bkSeparator` (separator) |
| `TCBookmarkTarget` | `uCbookmark` | Open destination. `btBrowser` (TargetBrowser), `btEditor` (TargetEditor) |
| `TCBookmarkDropPos` | `uCbookmark` | Drop position. `bdpBefore` (before it), `bdpInside` (the bottom of the folder), `bdpAfter` (after it). Used only when inheriting |

- When placed on a form, `uCbookmark` is added to uses automatically.
- When placed on a form, cx is automatically added to the project's required packages.
- When creating it in code, write it in uses yourself.

## 2. From Placing on a Form to Running

1. From the palette [CX], place TCBookmark on the form (example: `Align = alLeft`).
2. In the Object Inspector, select a TCTabBrowser for `TargetBrowser` and a TCMonacoEditor for `TargetEditor` (either one alone is fine).
3. Run it. It loads and displays bookmark\bookmarks.json in the EXE's folder. Your operations are saved automatically.

- To change the storage location, set `BookmarkFolder` and `BookmarkFile` (chapter 7).
- When using TCTabBrowser and TCMonacoEditor, the preparation in their respective user manuals (WebView2.ini, etc.) is also required.

## 3. Properties

### 3.1 TCBookmark

**Added by this component**

| Name | Type | Read/Write | Description |
|---|---|---|---|
| `TargetBrowser` | `TCTabBrowser` | Read/Write | Where URLs are opened (default is nil) |
| `TargetEditor` | `TCMonacoEditor` | Read/Write | Where files are opened (default is nil) |
| `BookmarkFolder` | `string` | Read/Write | Storage folder (default is 'bookmark'). Chapter 7 |
| `BookmarkFile` | `string` | Read/Write | File name to save to (default is 'bookmarks.json'). Setting '' makes it 'bookmarks.json'. Chapter 7 |
| `Root` | `TCBookmarkItem` | Read | The topmost container (a folder with no name). The screen shows the children of `Root`. Runtime only |
| `Selected` | `TCBookmarkItem` | Read | The selected item (nil if none). Runtime only |
| `SearchText` | `string` | Read/Write | The text of the search box. Writing it searches immediately. Runtime only |
| `DragItem` | `TCBookmarkItem` | Read | The item being dragged (nil if not dragging). Used inside `OnDragOver` and `OnDragDrop` of another component in the same application (10.9). Runtime only |

**Inherited from TCustomPanel**

| Name | Type | Read/Write | Description |
|---|---|---|---|
| `Align` | `TAlign` | Read/Write | Placement within the parent |
| `Anchors` | `TAnchors` | Read/Write | Which edges it follows when the parent's size changes |
| `BorderSpacing` | `TControlBorderSpacing` | Read/Write | Surrounding margins |
| `Constraints` | `TSizeConstraints` | Read/Write | Upper and lower size limits |
| `Enabled` | `Boolean` | Read/Write | Whether it is usable |
| `Font` | `TFont` | Read/Write | Text |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the parent's `Font` |
| `ShowHint` | `Boolean` | Read/Write | Whether to show hints |
| `TabOrder` | `TTabOrder` | Read/Write | Order of movement with the Tab key |
| `TabStop` | `Boolean` | Read/Write | Whether the Tab key stops here |
| `Visible` | `Boolean` | Read/Write | Whether it is displayed |

- `Left`, `Top`, `Width` and `Height`, which determine the size, as well as `Name` and `Tag`, can also be used (the default size is 250×300).

### 3.2 TCBookmarkItem (One Bookmark)

TCBookmark does both the creating and the deleting. The application does not `Create` or `Free` it.

| Name | Type | Read/Write | Description |
|---|---|---|---|
| `Kind` | `TCBookmarkKind` | Read | Kind |
| `Name` | `string` | Read/Write | Name ('' for a separator). Rewriting it is not saved and the screen does not change |
| `Location` | `string` | Read/Write | URL or file path ('' for folders and separators). Rewriting it is not saved and the screen does not change |
| `Expanded` | `Boolean` | Read/Write | Whether the folder is expanded |
| `AddDate` | `TDateTime` | Read | Registration date and time |
| `Parent` | `TCBookmarkItem` | Read | The parent folder (the topmost item's is `Root`) |
| `Count` | `Integer` | Read | Number of children (0 for non-folders) |
| `Items[AIndex]` | `TCBookmarkItem` | Read | Child item (from 0). Because it is the default property, it can also be written `CBookmark1.Root[0]` |
| `Index` | `Integer` | Read | Position within the parent |
| `FileMissing` | `Boolean` | Read | The linked file does not exist (files only; 8.2) |

| Name | Arguments | Return value | Description |
|---|---|---|---|
| `IsDescendantOf` | `AItem: TCBookmarkItem` | `Boolean` | `True` if this is a child or grandchild of `AItem` (`False` if it is `AItem` itself) |
| `DescendantCount` | ― | `Integer` | Number of children and grandchildren (does not count itself) |

- To change a name or location, use `TCBookmark`'s operations (such as "Edit Bookmark" from the right-click menu).

## 4. Methods

| Name | Arguments | Return value | Description |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | ― | Creates it. Used when creating in code (10.11) |
| `AddBookmark` | `AParent: TCBookmarkItem; AIndex: Integer; const AName, ALocation: string` | `TCBookmarkItem` | Adds a URL or file bookmark. The kind is determined from `ALocation` (4.1). If `AParent` is nil or not a folder, the top level; if `AIndex = -1` (out of range), the end. If `AName` is '', the file name (the URL for a URL) is used as the name. An `ALocation` that cannot be classified (such as about:...) returns nil and adds nothing |
| `AddFolder` | `AParent: TCBookmarkItem; AIndex: Integer; const AName: string` | `TCBookmarkItem` | Adds a folder |
| `AddSeparator` | `AParent: TCBookmarkItem; AIndex: Integer` | `TCBookmarkItem` | Adds a separator |
| `DeleteItem` | `AItem: TCBookmarkItem` | ― | Deletes an item (a folder with its contents; no confirmation is shown). The file itself is not deleted |
| `MoveItem` | `AItem, ANewParent: TCBookmarkItem; ANewIndex: Integer` | `Boolean` | Moves an item. If `ANewParent = nil`, the top level. It cannot be moved into itself (`False`) |
| `OpenItem` | `AItem: TCBookmarkItem; ATarget: TCBookmarkTarget; ANewTab: Boolean` | ― | Opens an item (6.3). `btBrowser` uses `TargetBrowser`, `btEditor` uses `TargetEditor` (files only). If `ANewTab = True`, a new tab |
| `ImportFromFile` | `const AFileName: string` | `Boolean` | Imports from an HTML file (chapter 9). `False` if there are no bookmarks or it cannot be read |
| `ExportToFile` | `const AFileName: string` | `Boolean` | Exports to an HTML file (chapter 9). If it cannot be written, shows a message and returns `False` |
| `ImportWithDialog` | ― | ― | Shows a dialog for choosing a file and imports (same as the menu) |
| `ExportWithDialog` | ― | ― | Shows a dialog for choosing the save destination and exports (same as the menu) |

- Adding, deleting, moving and importing save automatically and fire `OnChange`. The added or moved item becomes selected.

### 4.1 Functions (uCbookmark)

| Name | Arguments | Return value | Description |
|---|---|---|---|
| `CBClassifyLocation` | `const S: string; out AKind: TCBookmarkKind; out ALocation: string` | `Boolean` | Decides whether a string is a URL or a file (table below). `False` if it cannot be decided |
| `CBPathToFileUrl` | `const APath: string` | `string` | Converts a file path to a file:/// URL (`\` → `/`, `%` → `%25`, `#` → `%23`, space → `%20`. Japanese characters are left as is. `\\server\share` becomes `file://server/share`) |
| `CBFileUrlToPath` | `const AUrl: string` | `string` | Converts a file:/// URL to a file path (restores %xx, `/` → `\`) |
| `CBHostOf` | `const AUrl: string` | `string` | The host name of the URL (lower case. The port number stays attached). '' if it cannot be obtained |

| String (leading and trailing whitespace removed) | Kind |
|---|---|
| Starts with `file:` | File (converted to a path with `CBFileUrlToPath`) |
| Contains `://` (http, https, etc.) | URL |
| Starts with `C:\`, `C:/` or `\\server\` | File (`/` becomes `\`) |
| Anything else (about:, javascript:, etc.) | Cannot be decided |

## 5. Events

| Name | Arguments | Description |
|---|---|---|
| `OnChange` | `Sender: TObject` | After the bookmarks change and are saved (on add, edit, delete, move, paste, import, drop, and when the storage location is changed). Not fired when only the selection changes or a folder is merely expanded/collapsed |
| `OnSelectionChange` | `Sender: TObject` | After the selected item (`Selected`) changes. Fired regardless of the reason: click, key, right click, reselection after adding or deleting, switching the search, etc. (also fired when the selection disappears). Not fired when the same item is selected again. Inside it, get the item with `Selected` |

## 6. Operations

### 6.1 Mouse

| Operation | URL | File | Folder | Separator |
|---|---|---|---|---|
| Left click | Opens in the displayed tab of `TargetBrowser` | Opens in the displayed tab of `TargetEditor` | Expands/collapses | Does nothing |
| [▶] [▼] | ― | ― | Expands/collapses | ― |
| Drag (inside the tree) | Moves | Moves | Moves with its contents | Moves |
| Drag (outside the tree) | 6.6 | 6.6 | 6.6 | 6.6 |
| Right click | Select, then menu (6.2) | Same | Same | Same |

- A left click when the open destination is not set does nothing.
- A left click while holding Shift, Ctrl or Alt does nothing.
- While dragging, a horizontal line appears at the drop position. Hovering over the middle of a folder row (excluding the top and bottom 1/4) surrounds the row with a frame, and the item goes to the bottom of that folder. For rows that are not folders, the upper half means before it and the lower half means after it. On an empty area, the very bottom.
- Pausing for 1 second at a position that would go inside a closed folder opens that folder. Approaching the top or bottom edge of the tree scrolls automatically.
- A folder cannot be moved into itself (a no-drop cursor appears). Esc cancels the drag.

### 6.2 Right-Click Menu

| Menu | URL | File | Folder | Separator | Empty area |
|---|---|---|---|---|---|
| Text Open | Grayed out | Opens in the displayed tab of `TargetEditor` | Grayed out | Grayed out | Grayed out |
| Text Open in New Tab | Grayed out | Opens in a new tab of `TargetEditor` | Grayed out | Grayed out | Grayed out |
| Open in Browser | Opens in the displayed tab of `TargetBrowser` | Opens in the displayed tab of `TargetBrowser` (file:///) | Grayed out | Grayed out | Grayed out |
| Open in Browser in New Tab | Opens in a new tab of `TargetBrowser` | Opens in a new tab of `TargetBrowser` (file:///) | Grayed out | Grayed out | Grayed out |
| Edit Bookmark | Edit name and URL | Edit name and file path | Edit folder name | Grayed out | Grayed out |
| Delete Bookmark | Deletes | Deletes (the file is not deleted) | Deletes with its contents (with confirmation) | Deletes | Grayed out |
| Cut | Possible | Possible | Possible (with contents) | Possible | Grayed out |
| Copy | Possible | Possible | Possible (with contents) | Possible | Grayed out |
| Paste | Inserts below it | Inserts below it | Inserts inside the folder | Inserts below it | Inserts at the bottom |
| Add Bookmark | Inserts below it | Inserts below it | Inserts inside the folder | Inserts below it | Inserts at the bottom |
| Add Folder | Inserts below it | Inserts below it | Inserts inside the folder | Inserts below it | Inserts at the bottom |
| Separator | Inserts below it | Inserts below it | Inserts inside the folder | Inserts below it | Inserts at the bottom |
| Import... | Possible | Possible | Possible | Possible | Possible |
| Export... | Possible | Possible | Possible | Possible | Possible |

- If `TargetEditor` is not set, the Text items are grayed out; if `TargetBrowser` is not set, the Browser items are grayed out.
- "Inserts inside the folder" means inserting at the bottom of the folder and expanding that folder.
- Paste is grayed out when nothing has been cut or copied.
- Right-clicking an empty area clears the selection.

**Add/Edit dialogs**

| Operation | Dialog title | Fields |
|---|---|---|
| Add Bookmark | Add Bookmark | Name, URL or file path |
| Edit Bookmark (URL, file) | Edit Bookmark | Name, URL or file path (current values filled in) |
| Add Folder | Add Folder | Name (initially "New folder") |
| Edit Bookmark (folder) | Edit Folder Name | Name |

- [OK] cannot be pressed if the name is empty or the URL/file path cannot be classified (4.1).
- When editing, a URL may be changed to a file (or a file to a URL).

**Cut, copy and paste**

- The component keeps its own copy. A copy can be pasted any number of times. A cut moves the item from its original place when pasted (it stays in its original place until pasted).
- A cut folder cannot be pasted into itself (nothing happens).
- If you delete a cut item (or a folder containing it), the cut is canceled.
- On copy or cut, the URL/file path text is also placed on the Windows clipboard (for folders, one URL/path per line from the contents; nothing is placed if only separators). You cannot paste from the Windows clipboard.

### 6.3 What Happens When Opening

| Situation | Behavior |
|---|---|
| A file is opened with "open in the displayed tab" (left click, Text Open), and that file is already open in some tab | Switches to that tab |
| A file is opened with "open in the displayed tab", and the displayed tab has unsaved changes | Asks "There are unsaved changes. Open in a new tab?" Yes = opens in a new tab, No = does not open (the changes remain) |
| A file is opened with "open in a new tab", and that file is already open in some tab | Switches to that tab |
| The linked file does not exist | Notifies "File not found: (path)" and does not open |
| TCTabBrowser has no tabs at all | Creates a new tab and opens there |
| Could not open (TCTabBrowser or TCMonacoEditor raised an exception) | Notifies "Cannot open: (location : reason)" |

- After opening, when opened in the editor, focus moves to the editor.

### 6.4 Keys

| Key | Action |
|---|---|
| Enter | Same as left click |
| Delete | Deletes (folders with confirmation) |
| F2 | Edit (does nothing for a separator) |
| Ctrl+X | Cut |
| Ctrl+C | Copy |
| Ctrl+V | Paste (does nothing while searching) |
| Ctrl+F | Moves to the search box |
| Esc (while dragging) | Cancels the drag |
| Esc in the search box | Ends the search and returns to the original tree |
| Down arrow or Enter in the search box | Moves to the tree (selects the first item if nothing is selected) |

### 6.5 Search

- When you type in the search box and 0.3 seconds pass, URLs and files whose name or URL/file path contains the text are shown as a single flat list regardless of folders. Upper/lower case, full-width/half-width alphanumerics and spaces are not distinguished.
- While searching, you can open, edit, delete, cut, copy and export. You cannot paste, add, add separators, import, move by dragging, or drop from outside (because the insertion position cannot be determined).
- Clearing the text returns to the original tree (with folders expanded/collapsed as before).

### 6.6 Dragging Outside

Items in the tree can be dragged outside the tree. The behavior changes depending on the mouse position.

| Dragged to | URL | File | Folder, separator |
|---|---|---|---|
| Desktop, Explorer | An Internet shortcut "name.url" is created | A shortcut (.lnk) to the original file is created (the original file is not copied or moved) | Cannot be dropped |
| Apps that accept text, such as Notepad | The URL text is entered | Depends on the receiving app | Cannot be dropped |
| Browser | Opens that URL | Depends on the receiving browser | Cannot be dropped |
| Another component in the same application | If that component's `OnDragOver` answers that it accepts, `OnDragDrop` is called (10.9) | Same | Same |

- Even if you drag outside, TCBookmark's bookmarks do not change (nothing is moved or deleted).
- A file whose link target does not exist cannot be taken outside the application.
- The "name" of "name.url" is the bookmark's name with characters unusable in file names replaced by "_" (leading/trailing whitespace and a trailing "." are removed; up to 200 characters; the host name if empty).
- Once taken outside the application, it cannot be passed to a component in the same application even if brought back inside. Returning to your own tree and releasing does not add a bookmark.
- No drag image is shown during the drag (only the cursor).

### 6.7 Drops from Outside

| What was dropped | How it is registered |
|---|---|
| A browser URL (address bar, a link in a page) | URL. The name is the page title (the URL if unobtainable) |
| URL text (first line containing `://`) | URL. The name is the URL |
| A file (no restriction on extension) | File. The name is the file name |
| A .url file | The URL inside. The name is the file name without .url |
| A shortcut (.lnk) | The linked file. The name is the file name without .lnk. If the target is a folder, same as the next row |
| A folder | Creates a folder with the same name and registers the contents in the same structure (subfolders first, then files; each in name order) |

- The drop position is the same as 6.1 (before, after, inside a folder, the very bottom).
- If you drop several at once, they are lined up in the order dropped.
- If the contents of a folder total more than 500 items, a confirmation "Register n items?" appears.
- A .url inside a folder is registered as a URL, and a .lnk is registered as that .lnk file. Folders that are junctions or symbolic links are not followed.
- Registration is done after the drop handling has finished (so that the confirmation message does not block Explorer, etc.).

## 7. Storage Location

| File | Description |
|---|---|
| `BookmarkFolder`\\`BookmarkFile` | All bookmarks (JSON, UTF-8). The default is EXE folder\bookmark\bookmarks.json |
| `BookmarkFolder`\icons\ | Site icons (host name.png or .ico. The ":" in a host name becomes "_") |

- If `BookmarkFolder` is a relative path (including ''), it is counted from the EXE's folder. An absolute path (C:\..., \\server\...) is used as is.
- It saves immediately on every add, edit, delete, move, paste, folder expand/collapse, import and drop.
- Saving writes to a .tmp first and then replaces (so the file is not corrupted even if it stops midway). The folder is created if it does not exist.
- If the storage location cannot be written to, saving is impossible. The message "Cannot save the bookmarks" appears only once during a run. When placing the EXE in Program Files or similar, specify a writable location with `BookmarkFolder`.
- If the file is corrupted and cannot be read, it is renamed to bookmarks.json.broken-(year month day hour minute second) and kept, and it starts in an empty state (a notice appears).
- If you change `BookmarkFolder` or `BookmarkFile` during execution, it reloads from the new location and `OnChange` fires (the previous contents have already been saved in the previous location. A cut is canceled).
- Loading happens when the component is first displayed. In the IDE (design time), it neither loads nor saves.

**Format of bookmarks.json**

```json
{
  "version" : 1,
  "items" : [
    { "type" : "url", "name" : "Qiita", "location" : "https://qiita.com/", "added" : "2026-10-27T23:40:00" },
    { "type" : "file", "name" : "memo.md", "location" : "C:\\work\\memo.md", "added" : "2026-10-27T23:41:00" },
    { "type" : "separator" },
    { "type" : "folder", "name" : "Work", "expanded" : true, "added" : "2026-10-27T23:42:00", "items" : [] }
  ]
}
```

- The above shows the shape of the contents. The actual file has line breaks and indentation for each item.
- Items with an unknown `type` are skipped.

## 8. Display

### 8.1 Icons

| Kind | Icon |
|---|---|
| URL | The site's favicon. A globe picture if none |
| File | The Windows icon |
| Folder | The Windows folder icon (in Windows 11 the same picture for open and closed. Open/closed is indicated by [▶] [▼]) |
| Separator | None (a half-height row with a gray horizontal line) |

- For favicons, when a URL is registered (add, edit, drop, import) and that site's icon does not exist yet, the component fetches `https://(host name)/favicon.ico` in the background. If it cannot be fetched, the globe picture remains.
- The same site is fetched only once during a run. At most 4 are fetched at the same time. The wait is 10 seconds and the size is up to 512KB. Anything other than PNG or ICO (such as the HTML of a nonexistent page) is discarded.
- When importing from Firefox, the icons inside the HTML are used (not fetched).
- The icon size is the size of Windows' small icon (16×16 at 96dpi).

### 8.2 Files Whose Link Target Is Missing

- The name turns gray.
- It is checked when loaded, when a folder is expanded, when registered, edited or pasted, and when an attempt is made to open it. It is not checked on every paint (so that network paths do not make it slow).
- It is not deleted automatically.

### 8.3 Colors

| Part | Color |
|---|---|
| Background | `clWindow` |
| Text | `clWindowText` |
| Selected row | `clHighlight`, text `clHighlightText` |
| File whose link target is missing | Text `clGrayText` |
| Separator | `clGrayText` |
| Line/frame at the drag position | `clHighlight` |

- The scroll bar does not appear when scrolling is unnecessary.

## 9. Import and Export

With "Import..." and "Export..." in the right-click menu (or `ImportWithDialog`, `ExportWithDialog`, `ImportFromFile` and `ExportToFile`), the browser bookmark export format (Netscape Bookmark File Format HTML) is read and written.

| Browser | Importing into TCBookmark | Handing over to the browser |
|---|---|---|
| Firefox | Folders, separators and icons are all included | Folders, separators and icons are all included |
| Chrome, Edge | Folders are included. Icons are fetched later | Folders are included. Separators and icons are lost |

- Imported items go into an "Import yyyy-mm-dd" folder created at the very bottom. Duplicate bookmarks are not checked for.
- Import skips links that cannot be classified as a URL or file, such as javascript:, place: and about:.
- A file with no bookmarks at all notifies "No bookmarks were found." and adds nothing.
- Export is UTF-8 with CRLF line breaks. File bookmarks are written as file:/// URLs. If a site icon exists, it is included in the HTML.

## 10. Usage Examples

### 10.1 Place on a Form and Run

1. Place TCTabBrowser, TCMonacoEditor and TCBookmark on the form.
2. Select `TargetBrowser` and `TargetEditor` of TCBookmark.
3. Run, and drop a URL from the browser's address bar or a file from Explorer onto TCBookmark.

### 10.2 Add Bookmarks in Code

```pascal
procedure TForm1.Button1Click(Sender: TObject);
var
  F: TCBookmarkItem;
begin
  F := CBookmark1.AddFolder(nil, -1, 'Work');
  CBookmark1.AddBookmark(F, -1, 'Qiita', 'https://qiita.com/');
  CBookmark1.AddBookmark(F, -1, '', 'C:\work\memo.md');   // The name is memo.md
  CBookmark1.AddSeparator(nil, -1);
end;
```

### 10.3 Add the Displayed Page to the Bookmarks

```pascal
procedure TForm1.AddPageClick(Sender: TObject);
begin
  if CTabBrowser1.Count = 0 then Exit;
  CBookmark1.AddBookmark(nil, -1, CTabBrowser1.ActiveTab.Title, CTabBrowser1.ActiveTab.URL);
end;
```

### 10.4 Look at the Selected Item

```pascal
procedure TForm1.ShowSelectedClick(Sender: TObject);
var
  It: TCBookmarkItem;
begin
  It := CBookmark1.Selected;
  if It = nil then Exit;
  ShowMessage(It.Name + LineEnding + It.Location);
end;
```

### 10.5 Extract All URLs

```pascal
procedure TForm1.CollectUrls(AParent: TCBookmarkItem; AList: TStrings);
var
  I: Integer;
begin
  for I := 0 to AParent.Count - 1 do
    case AParent.Items[I].Kind of
      bkUrl: AList.Add(AParent.Items[I].Location);
      bkFolder: CollectUrls(AParent.Items[I], AList);
    end;
end;

// Usage: CollectUrls(CBookmark1.Root, Memo1.Lines);
```

### 10.6 Change the Storage Location

```pascal
// Design time: set BookmarkFolder in the Object Inspector to something like 'data\bm' (counted from the EXE's folder)
// Runtime: changing it reloads from that location
CBookmark1.BookmarkFolder := GetEnvironmentVariable('APPDATA') + '\MyApp\bookmark';
```

### 10.7 Import and Export from a Menu or Button

```pascal
procedure TForm1.MenuImportClick(Sender: TObject);
begin
  CBookmark1.ImportWithDialog;
end;

procedure TForm1.MenuExportClick(Sender: TObject);
begin
  CBookmark1.ExportToFile(ExtractFilePath(ParamStr(0)) + 'bookmarks.html');
end;
```

### 10.8 Show the Count in the Status Bar When Changed

```pascal
procedure TForm1.CBookmark1Change(Sender: TObject);
begin
  StatusBar1.SimpleText := Format('%d items', [CBookmark1.Root.Count]);
end;
```

### 10.9 Receive a Drag in Another Component in the Same Application

Write it in `OnDragOver` and `OnDragDrop` of the receiving component (example: TCCheckListBox, TListBox). `Source` is the TCBookmark.

```pascal
procedure TForm1.CheckListBox1DragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  { Accept only file bookmarks }
  Accept := (Source is TCBookmark) and (TCBookmark(Source).DragItem <> nil)
    and (TCBookmark(Source).DragItem.Kind = bkFile);
end;

procedure TForm1.CheckListBox1DragDrop(Sender, Source: TObject; X, Y: Integer);
begin
  CheckListBox1.Items.Add(TCBookmark(Source).DragItem.Location);   { Full path }
end;
```

### 10.10 Show the File Name When the Selection Changes

```pascal
procedure TForm1.CBookmark1SelectionChange(Sender: TObject);
var
  It: TCBookmarkItem;
begin
  It := CBookmark1.Selected;
  if (It <> nil) and (It.Kind = bkFile) then
    Label1.Caption := It.Location          { Full path }
  else
    Label1.Caption := '';
end;
```

### 10.11 Create in Code

```pascal
uses
  uCbookmark;

procedure TForm1.FormCreate(Sender: TObject);
var
  B: TCBookmark;
begin
  B := TCBookmark.Create(Self);
  B.Parent := Self;
  B.Align := alLeft;
  B.TargetBrowser := CTabBrowser1;
  B.TargetEditor := CMonacoEditor1;
end;
```
