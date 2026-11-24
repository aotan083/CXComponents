# TCSearchBox User Manual

Author: aotan083
Date: 2026-11-17
Version: 1.0

---

**Operating environment**: Lazarus 5.0 or later (FPC 3.2.2). Lazarus 4.8 and earlier are not supported.

## 1. Overview and Classes

A component that you can use just like the Windows Explorer search box. Just connect it to TCListView (and TCTreeView), and it searches the folder being displayed by name and shows the result in the list.

```
[ Search <folder name>                           ][x][magnifier]
   Input field (the faint text is the name of the folder to be searched)   clear   magnifier (opens options) / a spinner while searching
```

- Type a name and press `Enter` to start searching (it does not search on every keystroke).
- While searching, a spinner appears where the magnifier is. Found items appear little by little in the list. Pressing the spinner (or `Esc`) stops the search.
- Choose the search method from the menu that opens when you press the magnifier: contains (default), wildcard, or regular expression. You can also switch case sensitivity, whether to search inside subfolders, and whether to search hidden files.
- The results appear in the "search result view" of TCListView (`TCListView_Usage.md` 5.5). The name and its location (folder) are listed. You can open, copy, delete, and so on just as in a normal list.
- "x" (or `Esc`) clears the search and returns to the display of the original folder. When you move to another folder in the list (double-click, back, selecting in the tree, and so on), the search ends automatically.
- The search itself is done by TCFindFile (`TCFindFile_Usage.md`).

| Item | Contents |
|---|---|
| Lazarus | 5.0RC1 or later |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Classes and Units

| Class | Unit | Package | Parent class | Contents |
|---|---|---|---|---|
| `TCSearchBox` | `uCSearchBox` | cx | `TCustomControl` | The Explorer search box |

| Type | Unit | Contents |
|---|---|---|
| `TCSearchResultEvent` | `uCSearchBox` | `procedure(Sender: TObject; const APath: string; AIsDir: Boolean) of object`. The type of `OnSearchResult` |
| `TCSearchFinishedEvent` | `uCSearchBox` | `procedure(Sender: TObject; AFound: Integer; AReason: TCFindStopReason) of object`. The type of `OnSearchFinished` |
| `TCSearchErrorEvent` | `uCSearchBox` | `procedure(Sender: TObject; const AMessage: string) of object`. The type of `OnSearchError` |

- `TCFindMatchMode` and `TCFindStopReason` are types of `uCFindFile` (`TCFindFile_Usage.md` 1.1). In code that uses `MatchMode` or `OnSearchFinished` of this component, also write `uCFindFile` in uses.
- When placed on a form, `uCSearchBox` is added to uses automatically, and cx is added to the project's required packages automatically.
- When creating it in code, write it in uses yourself.

## 2. From Placing on a Form to Running

1. Place TCListView and TCTreeView on the form from the [CX] palette (`TCListView_Usage.md`, `TCTreeView_Usage.md`). Set the `ShellListView` of TCTreeView to the TCListView.
2. Place TCSearchBox on the form.
3. Set the `ListView` of TCSearchBox to the TCListView and the `TreeView` to the TCTreeView.
4. Run the application. Enter a name in the input field and press `Enter`.

- The folder to be searched is the folder being displayed (`Root`) if there is a `ListView`, otherwise the folder selected in `TreeView`. The faint text in the input field shows the name of that folder.
- If a group that is not a folder (such as Quick access) is selected in the tree and there is no list, the search is not possible (`OnSearchError` arrives).
- It can also search without setting `ListView`. In that case, receive the results with `OnSearchResult` and show them yourself. The folder to be searched is the folder of `TreeView` if there is one, otherwise `Finder.Root` (set by the application beforehand).
- When placing it on the same form as the address bar (`TCAddressBar_Usage.md`), set the address bar to `alClient` and the search box to `alRight`, and put them side by side in one panel. The layout is then the same as in Explorer.

## 3. Operation

### 3.1 Mouse

| Operation | Action |
|---|---|
| The magnifier (when not searching) | Shows the options menu (3.3). Nothing happens if `ShowOptionsMenu` is `False` |
| The spinner (while searching) | Stops the search |
| "x" | Clears the search (stops it if it is running, empties the input, and ends the search result view). It is shown only when there is input and the search is not running |
| The input field | Type text. Copy, paste, and Japanese input are the same as in an ordinary input field |

### 3.2 Keys

| Key | Action |
|---|---|
| `Enter` | Starts searching. If the input is empty (or only spaces), clears the search |
| `Esc` | If a search is running, stops it (the results remain). Otherwise, if there is input, clears the search |
| `Ctrl+E`, `Ctrl+F` | Moves to this component. Also works when the focus is on the TCListView or TCTreeView on the same form |

- If you press `Enter` again while searching, the previous search is stopped and started over.

### 3.3 The Options Menu

| Item | Action |
|---|---|
| Contains | Searches for names that contain the text typed (default) |
| Wildcard (* ?) | `*`: any string, `?`: one character. Several patterns with `;` (for example `*.pas;*.lfm`) |
| Regular expression | Searches with a regular expression (for example `\.(pas|lfm)$`). If the expression is not valid, it does not search and an error is shown |
| Match case | Toggle |
| Include subfolders | Toggle (included by default) |
| Include hidden and system files | Toggle (not included by default) |

- Switching in the menu does not search immediately (press `Enter` to search).
- The same settings can also be made with the properties (`MatchMode`, `CaseSensitive`, `IncludeSubfolders`, `SearchHidden`).
- How to write the patterns in detail is in `TCFindFile_Usage.md` 1.2.

### 3.4 When There Is an Error

- If the regular expression is not valid or there is no folder to search, `OnSearchError` arrives.
- If `OnSearchError` is not set, the frame turns red and the reason appears in the hint when you hover the mouse (it disappears when you next change the input).

## 4. Properties

### 4.1 Added by This Component

| Name | Type | Access | Contents |
|---|---|---|---|
| `ListView` | `TCListView` | Read/Write | The list that shows the results |
| `TreeView` | `TCTreeView` | Read/Write | The source of the folder to search (when there is no `ListView`, or the list has no folder) |
| `Text` | `string` | Read/Write | The text in the input field (the name to search for). Writing it fires `OnChange` |
| `TextHint` | `string` | Read/Write | The faint text shown when the input is empty. If left empty, "Search (folder name)" is shown automatically ("Search" when the folder is not known) |
| `MatchMode` | `TCFindMatchMode` | Read/Write | The search method (default `fmContains`) |
| `CaseSensitive` | `Boolean` | Read/Write | Whether upper and lower case are distinguished (default `False`) |
| `IncludeSubfolders` | `Boolean` | Read/Write | Whether to search inside subfolders (default `True`) |
| `SearchHidden` | `Boolean` | Read/Write | Whether to search hidden and system items too (default `False`) |
| `MaxResults` | `Integer` | Read/Write | The maximum number of results (default 10000; 0 means no limit) |
| `ShowOptionsMenu` | `Boolean` | Read/Write | Whether pressing the magnifier opens the options menu (default `True`) |
| `Color` | `TColor` | Read/Write | The background color inside the input frame (default `clDefault`, the same as `clWindow`) |
| `Searching` | `Boolean` | Read | `True` while searching. Run time only |
| `ResultCount` | `Integer` | Read | The number found in the current search. Run time only |
| `Finder` | `TCFindFile` | Read | The search component (held by this component). `Finder.Root` is used as the folder to search when there is no `ListView` or `TreeView` (when the folder to search was decided from `ListView` or `TreeView`, it returns to empty when the search ends). Run time only |

### 4.2 Inherited from the LCL

`Align`, `Anchors`, `BorderSpacing`, `Constraints`, `Enabled`, `Font`, `ParentFont`, `PopupMenu`, `ShowHint`, `TabOrder`, `TabStop` (default `True`), `Visible`, `Width` (default 260), `Height` (default 32; at 96 dpi).

## 5. Methods

| Name | Parameters | Return value | Contents |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | - | Creates it. Use it when creating in code (8.2) |
| `Search` | - | - | Same as `Enter`. Starts searching with the current `Text`. If `Text` is empty (or only spaces), it is the same as `ClearSearch` |
| `StopSearch` | - | - | Stops the search if it is running (the results remain) |
| `ClearSearch` | - | - | Stops searching, empties `Text`, and ends the search result view (returns to the display of the original folder) |
| `SetFocus` | - | - | Moves the focus to the input field and selects everything |

## 6. Events

| Name | Parameters | Contents |
|---|---|---|
| `OnChange` | `Sender: TObject` | The text in the input field changed (typing, writing `Text`, clearing the search) |
| `OnSearchStart` | `Sender: TObject` | The search started |
| `OnSearchResult` | `Sender: TObject; const APath: string; AIsDir: Boolean` | Each time one item is found. Use it when you want to receive items yourself, separately from showing them in `ListView` (it fires even without a `ListView`) |
| `OnSearchFinished` | `Sender: TObject; AFound: Integer; AReason: TCFindStopReason` | The search ended (also when stopped or when the limit was reached). `AReason`: `frDone`, `frStopped`, `frLimit`, `frError` |
| `OnSearchError` | `Sender: TObject; const AMessage: string` | The search could not start (the regular expression is not valid, or there is no folder to search). If it is not set, the frame turns red (3.4) |

## 7. Notes

- Windows only.
- It searches only file names and folder names (it does not search the contents of files).
- Because names are handled as UTF-8, `.` in a regular expression works on bytes. An expression that specifies a number of Japanese characters does not behave as expected (`TCFindFile_Usage.md` 1.2).
- Results are in the order found. Clicking a column header of the list sorts them.
- While the search result view is shown, the list does not monitor folder changes (results do not change even if files are added).
- When the list moves to another folder by some other operation, the search stops and the input becomes empty.
- At design time, only the frame, the faint text, and the magnifier are drawn. It does not search.

## 8. Usage Examples

### 8.1 Show the Count When the Search Finishes

```pascal
procedure TForm1.CSearchBox1SearchFinished(Sender: TObject; AFound: Integer; AReason: TCFindStopReason);
begin
  if AReason = frLimit then
    StatusBar1.SimpleText := Format('%d items (the limit was reached)', [AFound])
  else
    StatusBar1.SimpleText := Format('%d items', [AFound]);
end;
```

### 8.2 Create It in Code

```pascal
uses uCSearchBox, uCFindFile, CListView, CTreeView;

var
  SB: TCSearchBox;
begin
  SB := TCSearchBox.Create(Self);
  SB.Parent := Self;
  SB.Align := alRight;
  SB.Width := 280;
  SB.ListView := CListView1;
  SB.TreeView := CTreeView1;
  SB.MatchMode := fmWildcard;      // Search with wildcards from the start
end;
```

### 8.3 Receive the Results Yourself Without a List

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  CSearchBox1.Finder.Root := 'C:\app';           // There is no ListView or TreeView, so give the folder to search
  CSearchBox1.OnSearchResult := @OnResult;
end;

procedure TForm1.OnResult(Sender: TObject; const APath: string; AIsDir: Boolean);
begin
  ListBox1.Items.Add(APath);
end;
```
