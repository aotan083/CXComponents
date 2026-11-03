# TCsEditor User Manual

Author: aotan083
Date: 2026-11-03
Version: 1.0

---

## 1. Overview and Classes

A tabbed text editor that works simply by dropping it on a form. Each tab holds one TCSynEdit (SynEdit). Usage (names, behavior, default values) is the same as TCMonacoEditor, but the editing part is SynEdit rather than WebView2, so it runs lighter and faster. All settings are made in the Object Inspector; the application does not need to write any code.

```
+---------+---------+-----+-------------------+--+---+
| a.md  × | b.pas × |  +  |                   |  |   |
+---------+---------+-----+-------------------+--+---+
| # Heading                                    |▒▒|   |
| Body text...                                 |▒ |   |
|                                             |▒▒| ↕ |
|    TCSynEdit (one per tab)                   |  |   |
+---------------------------------------------+--+---+
                                    Minimap ↑   ↑ Scrollbar
```

- Any number can be placed on one form. When placing them side by side, the application separates them with a TSplitter.
- Events work even if you do not set them (when not set, the component performs its default behavior; 6.2).
- It detects the character encoding (UTF-8, UTF-16, Shift_JIS) when reading, and saves with the same encoding. The line ending (CRLF, LF) is also preserved.
- The language is determined from the file extension and syntax highlighting is applied.
- Preview (Markdown, code) and printing (save as PDF) are handled by a separate component, TCPreview (chapter 11).
- When the form is closed, unsaved documents are checked automatically.
- Standard actions (25) can be assigned to menus and buttons (chapter 12).
- Dragging a tab outside the window opens it in a separate window. Dragging it to another TCsEditor on the same form moves that tab (9.9, 9.10).

| Item | Details |
|---|---|
| Lazarus | 5.0 or later |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |
| Required at runtime | None (when using the preview, the files described in TCPreview manual chapter 2) |
| External packages used | SynEdit (included with Lazarus), ATFlatControls (tabs) |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Description |
|---|---|---|---|---|
| `TCsEditor` | `uCsEditor` | cx | `TCustomPanel` | The editor itself, placed on a form |
| `TCsPage` | `uCsEditor` | cx | `TObject` | One tab (obtained with `ed.Pages[n]`; chapter 4). TCsEditor creates and removes it |
| `TCsFindDialog` | `uCsEditor` | cx | `TComponent` | Find/replace dialog (non-visual component). Place it only when you want to control it yourself (chapter 10) |
| `TCsEditorNew` and 24 others | `uCsEditor` | cx | `TAction` | Standard actions (chapter 12) |
| `TCPreview` | `uCPreview` | cx | `TCustomPanel` | Preview (separate manual `TCPreview_Usage.md`) |

| Type | Unit | Description |
|---|---|---|
| `TCMEncoding` | `uCsEditor` | Character encoding. `ceUTF8`, `ceUTF8BOM`, `ceUTF16LE`, `ceUTF16BE`, `ceCP932` |
| `TCMFindOption`, `TCMFindOptions` | `uCsEditor` | Search options. `foMatchCase` (case-sensitive), `foWholeWord` (whole word), `foLoop` (wrap around to the opposite end) |
| `TCMTheme` | `uCsEditor` | Color theme. `ctAuto`, `ctLight`, `ctDark` |
| `TCMSelectionColorStyle` | `uCsEditor` | Color set for the selection. `scStandard`, `scBlue`, `scAmber`, `scPurple`, `scCustom` |

| Function | Unit | Description |
|---|---|---|
| `CsActiveEditor(AForm: TCustomForm): TCsEditor` | `uCsEditor` | The editor that last had focus on that form. If none has had focus yet, the first editor. nil if there is none |
| `CsOsIsDark: Boolean` | `uCsEditor` | Whether the OS color scheme is dark |

- When placed on a form, `uCsEditor` is added to uses automatically. This is all the application needs in its uses (commonly used types are re-exported by `uCsEditor`).
- When placed on a form, cx is automatically added to the project's required packages.
- When creating it in code, write it in uses yourself.
- Placing TCMonacoEditor and TCsEditor together on the same form is not supported.

## 2. From Placing on a Form to Running

1. From the [CX] palette, place TCsEditor on the form and set `Align = alClient`.
2. Run it.

- Right after startup, there is one empty untitled tab.
- At design time in the IDE, the inner editor is not created. Only a thin frame and the component name are shown.
- When using the preview, place a TCPreview and select it with `Preview` (chapter 11).

**Initial state**

| Item | Value |
|---|---|
| Font | BIZ UDGothic, 14 pt |
| Color theme (`Theme`) | `ctAuto` (follows the OS color scheme) |
| Language | `DefaultLanguage` (pascal) |
| Word wrap | On |
| Line numbers | Off (show with `F11`) |

- The initial font is BIZ UDGothic. In environments where it is not installed, set `Font`.

## 3. Concepts

In this manual, an editor placed on a form is written as `ed`.

**1. The visible tab is `ed`; background tabs are `ed.Pages[n]`**

| Notation | Target |
|---|---|
| `ed.…` | The visible tab (the tab at `ActiveIndex`) and the editor as a whole |
| `ed.ActiveIndex := n` | Switches the visible tab (the screen switches too). Numbers start at 0 |
| `ed.Pages[n].…` | Touches the contents and file of tab n without switching the screen. n may be the visible tab (same result as `ed.…`) |

- Everything in `ed.Pages[n]` has the same name and the same behavior in `ed` (chapter 4).
- Only the operations on the collection of tabs (chapter 5) and the operations on the screen (6.1) exist only in `ed`. This is because selection, cursor, editing, search and printing exist only for the visible tab. To perform them on a background tab, first switch with `ActiveIndex`.
- Names are the same as in TMemo and TSynEdit (`Text`, `Lines`, `SelText`, `SelLength`, `Modified`, `LoadFromFile`, etc.).

**2. One tab = one page**

- Page = one tab + one body + a file name. An untitled document (not yet saved) is also one page.
- The same file is never opened in two tabs. A file is also not opened simultaneously in another TCsEditor on the same form (trying to open it switches to the editor that already has it open).
- Tab numbers are 0, 1, 2... from the left.

**3. There is always at least one tab**

- When the last tab is closed (`ed.Close`, `ed.CloseAll`, the tab's [×]), one empty untitled tab is created.
- When `MultiDocument = False`, there is always exactly one tab (not displayed). Closing it leaves an untitled tab with empty contents (9.1).

**4. The tab display is determined automatically from the page state**

| Tab display | How it is determined |
|---|---|
| Title (`Caption`) | Only the name part of the file name (`C:\docs\a.md` → `a.md`). "Untitled" if untitled |
| Modified mark (` *`) | Added when `Modified` is `True` (e.g. `a.md *`). Not included in `Caption` |
| Icon | Determined by the extension (untitled uses the text icon; 9.3) |
| Hint | Full path of the file name |
| Tab that appears raised | The tab at `ActiveIndex` |

- Tab text stays at normal size (it does not change even if `Font` or `FontSize` is made larger).

**5. How each operation changes things**

| Operation | Body | File name | Tab | ` *` | Disk |
|---|---|---|---|---|---|
| `ed.NewPage` | Empty | Empty | Increases by one ("Untitled"). Becomes the visible tab | None | Nothing |
| `ed.OpenFile(name)` | Contents of the file | That name | Increases by one. Becomes the visible tab (if the same file is already open, just switches to that tab) | None | Reads |
| `ed.LoadFromFile(name)` | Replaced by the contents of the file (changes are discarded without asking) | Changes to that name | Does not increase | None | Reads |
| `ed.Clear` | Empty | Empty (becomes untitled) | Does not increase | None | Nothing |
| `ed.Text := s` | Replaced (Undo history is cleared). Does nothing if the body is the same as now | Unchanged | Unchanged | Added (not added if the body is the same as now) | Nothing |
| `ed.SelText := s` | The selected part is replaced (one Undo reverts it) | Unchanged | Unchanged | Added | Nothing |
| A person types | Changes | Unchanged | Unchanged | Added | Nothing |
| `ed.Save` | Unchanged | Unchanged (if untitled, the name that was asked) | Unchanged (if untitled, that name) | Removed | Writes |
| `ed.SaveAs(name)` | Unchanged | That name | Title and icon change | Removed | Writes (the original file remains) |
| `ed.Close` | Removed | Removed | Removed (the neighboring tab becomes the visible tab. If it was the last one, an empty untitled tab is created) | ― | Nothing |
| `ed.ActiveIndex := n` | Tab n is displayed | ― | Tab n becomes the visible tab | ― | Nothing |

The same-named operations of `ed.Pages[n].…` behave the same way, except that the target is tab n (the screen does not switch).

## 4. Tab Contents and Files (ed, ed.Pages[n])

| Name | Type / Arguments | Access | Description |
|---|---|---|---|
| `Text` | `string` | Read/Write | The body. Writing replaces only the contents (the file name is kept; the Undo history is cleared; nothing is written to the file). Writing adds ` *`. Writing the same body as now does nothing. Lines are joined with that tab's line ending. A body that ends with a line break has one empty line at the end |
| `Lines` | `TStrings` | `ed`: Read/Write. `ed.Pages[n]`: Read | The body (by line). It is the inner editor's `Lines` itself. `ed.Lines := L` sets the body of the visible tab to the contents of `L`. Contents entered in the Object Inspector go into the first tab |
| `Caption` | `string` | Read | The tab title. Only the name part of the file name. "Untitled" if untitled. Does not include ` *` |
| `FileName` | `string` | Read | Full path of the file. '' if untitled. To change the name, use `SaveAs` |
| `Modified` | `Boolean` | Read | Whether there are unsaved changes (the tab's ` *`) |
| `Encoding` | `TCMEncoding` | Read/Write | Character encoding. Determined when reading and used when saving |
| `Language` | `string` | Read/Write | Language for syntax highlighting ('pascal', 'markdown', etc.; 9.2). Writing '' gives `DefaultLanguage` |
| `LineCount` | `Integer` | Read | Number of lines. 1 for an empty document |
| `SynEdit` | `TCSynEdit` | Read | The editor inside that tab (for advanced users; 15.12). Do not change `OnChange`, `OnStatusChange` or `PopupMenu`, because the component uses them |
| `Index` | `Integer` | Read | `ed.Pages[n]` only. The current tab number (-1 for a closed page) |
| `LoadFromFile` | `const AFileName: string`, returns `Boolean` | ― | Discards the contents and loads the file. Changes are discarded without asking. The number of tabs does not increase. Returns `True` if loaded. If the file does not exist or cannot be read, changes nothing and returns `False` (`OnError`). If the file is open in another tab or in another TCsEditor on the same form, it is not loaded and returns `False` (`OnError`) |
| `Save` | returns `Boolean` | ― | Overwrite save. If untitled, asks for a name (`OnNeedFileName`; if not set, the save dialog. Asks without switching even for a background tab). Returns `True` if saved. On cancel or failure it returns `False` and ` *` is not removed. Failures go to `OnError` |
| `SaveAs` | `const AFileName: string = ''`, returns `Boolean` | ― | Saves under a different name. If the name is omitted, asks with the save dialog. After saving, the tab's title, icon and language are also adjusted to that name. The original file remains on disk. If the name is that of a file open in another tab, it is not saved and returns `False` (`OnError`). When a name is specified, an existing file of the same name is overwritten without asking (with the dialog, it asks "Overwrite?") |
| `Clear` | ― | ― | Empties the contents, removes the file name and makes it untitled. Changes are discarded without asking. The tab remains. Language becomes `DefaultLanguage`, encoding UTF-8, line ending CRLF |
| `Close` | `Force: Boolean = False`, returns `Boolean` | ― | Closes. Asks if there are changes (9.5). With `Force = True`, discards without asking. Returns `True` if closed, `False` if canceled. When the visible tab is closed, the neighboring tab becomes the visible tab. If it was the last one, an empty untitled tab remains. With `MultiDocument = False`, it empties the contents instead of closing (9.1). The file itself is not deleted |

**Rules for `Pages[n]`**

- Pages are created and managed by the editor. The application does not `Create` or `Free` them.
- A retrieved page (e.g. `P := ed.Pages[2]`) keeps pointing to the same tab even if tabs are reordered.
- When a closed page is used, values read are empty (`Caption`, `FileName`, `Text` are '', `Modified` is `False`, `LineCount` is 0, `SynEdit` is nil), and operations do nothing (those returning `Boolean` return `False`). It does not crash.
- If the `Pages[n]` index is out of range, an exception (`EListError`) is raised.
- When `MultiDocument = False`, there is always exactly one page (`Pages[0]`).

## 5. Collection of Tabs (ed)

| Name | Type / Arguments | Access | Description |
|---|---|---|---|
| `OpenFile` | `const AFileName: string = ''`, returns `Integer` | ― | If the name is omitted, shows the open dialog (`OpenDialog`; the built-in one if not set) and opens the selected file. On cancel, does nothing and returns -1. When a name is specified, loads the file in a new tab, opens it and makes it the visible tab. Detects the character encoding and determines the language from the extension. If the same file is already open, just switches to that tab (does not reload). If it is open in another TCsEditor on the same form, switches to that tab in that editor and returns -1. Even if the only tab is the untitled one present right after startup, the file is not loaded into it. The return value is the tab number. For an unreadable file, an exception is raised (no tab is left behind). With `MultiDocument = False`, see 9.1 |
| `NewPage` | returns `Integer` | ― | Adds an empty untitled tab on the right and makes it the visible tab. The return value is the tab number. With `MultiDocument = False`, see 9.1 |
| `SaveAll` | ― | ― | Overwrite-saves all tabs with changes (for untitled ones, switches to that tab and then asks for a name) |
| `CloseAll` | `Force: Boolean = False`, returns `Boolean` | ― | Closes everything. Asks if there are changes. With `Force = True`, discards without asking. When done, one empty untitled tab remains. If canceled midway, returns `False` (the rest are left as is) |
| `CanCloseAll` | returns `Boolean` | ― | Checks the unsaved tabs but does not close. Returns `False` if canceled |
| `FindPage` | `const AFileName: string`, returns `Integer` | ― | The number of the tab that has that file open. -1 if none. Case-insensitive |
| `MovePage` | `AFromIndex, AToIndex: Integer` | ― | Changes the order of the tabs. The contents do not change |
| `ActiveIndex` | `Integer` | Read/Write | The number of the visible tab (from 0). Writing switches to that tab. Out-of-range or the same number does nothing. If the body of the previous tab had focus, focus moves to the body of the new tab |
| `PageCount` | `Integer` | Read | Number of tabs (always 1 or more) |
| `Pages[AIndex]` | `TCsPage` | Read | Tab n (chapter 4). Out of range raises an exception |

## 6. Operations on the Screen and Events (ed)

### 6.1 Properties and Methods

All of them target the visible tab.

| Name | Type / Arguments | Access | Description |
|---|---|---|---|
| `SelText` | `string` | Read/Write | Reading gives the selected string ('' if nothing is selected). Writing replaces the selection with that string. If nothing is selected, inserts at the cursor position. Writing '' deletes the selection. Line breaks passed as #13, #10 or #13#10 are all treated as a line break. One Undo reverts it. After replacing, the cursor is placed after the replaced string (the selection is cleared). When `ReadOnly`, writing does nothing |
| `SelStart` | `Integer` | Read | Start position of the selection (the cursor position if nothing is selected). 0-based from the start of the document, in UTF-16 units (emoji etc. count as 2). A line break counts as the number of characters of the document's line ending (2 for CRLF, 1 for LF). To select a range, use `SetSelection` |
| `SelLength` | `Integer` | Read | Number of characters selected (counted the same way as `SelStart`). 0 means nothing is selected |
| `CanUndo` | `Boolean` | Read | Whether Undo is possible |
| `CanRedo` | `Boolean` | Read | Whether Redo is possible |
| `GetCursorPos` | `out ALine, AColumn: Integer` | ― | The cursor position. Line and column start at 1. The column is in UTF-16 units |
| `SetCursorPos` | `ALine, AColumn: Integer` | ― | Moves the cursor |
| `SetSelection` | `ALine1, AColumn1, ALine2, AColumn2: Integer` | ― | Selects a range. The cursor is at the end position |
| `LineText` | `string` | Read | The string of the cursor line (without the line break). Chapter 13 |
| `LineWords` | `TStrings` | Read | List of the cursor line split into words (counted from 0). Do not `Free`. Chapter 13 |
| `LineDelimiters` | `string` | Read/Write | Delimiter characters for `LineWords`. Set in code. Chapter 13 |
| `LineSkipEmpty` | `Boolean` | Read/Write | Whether to leave empty words out of `LineWords`. Set in code. Chapter 13 |
| `LineQuoteChar` | `Char` | Read/Write | Quote character for `LineWords`. Set in code. Chapter 13 |
| `Undo` | ― | ― | Undoes |
| `Redo` | ― | ― | Redoes |
| `Cut` | ― | ― | Cut (clipboard). Does nothing when `ReadOnly` |
| `Copy` | ― | ― | Copy (clipboard) |
| `Paste` | ― | ― | Paste (clipboard). Does nothing when `ReadOnly` |
| `SelectAll` | ― | ― | Selects everything |
| `DeleteToEnd` | ― | ― | If nothing is selected, deletes from the cursor position to the end of the document. If something is selected, deletes from the start of the selection to the end (the selected part is also deleted). One Undo reverts it. Does nothing when `ReadOnly` |
| `DeleteToStart` | ― | ― | If nothing is selected, deletes from the start of the document to the cursor position. If something is selected, deletes from the start to the end of the selection. Rules are the same as `DeleteToEnd` |
| `DuplicateLine` | ― | ― | Duplicates the cursor line and moves down to it (same as `Shift+F10`. If multiple lines are selected, duplicates those lines together). One Undo reverts it. Does nothing when `ReadOnly` |
| `ToggleOverwrite` | ― | ― | Toggles between insert and overwrite (same as the `Insert` key) |
| `Find` | `const S: string; AOptions: TCMFindOptions; AForward: Boolean = True` | ― | Searches and selects the match found. The result goes to `OnFindDone` |
| `FindNext` | ― | ― | Searches for the next match with the last search term (`F5`). If there is no search term, opens the find dialog |
| `FindPrev` | ― | ― | Searches for the previous match with the last search term (`Shift+F5`) |
| `Replace` | `const S, R: string; AOptions: TCMFindOptions` | ― | If the selection is S, replaces it with R and searches for the next one. Does nothing when `ReadOnly` |
| `ReplaceAll` | `const S, R: string; AOptions: TCMFindOptions` | ― | Replaces all. The result (count) goes to `OnReplaceAllDone`. One Undo reverts it. Does nothing when `ReadOnly` |
| `ShowFindDialog` | `const InitialText: string = ''` | ― | Opens the find/replace dialog (same as `Ctrl+F`; chapter 10) |
| `SearchText` | `string` | Read/Write | The last search term |
| `ReplaceText` | `string` | Read/Write | The last replacement term |
| `SearchOptions` | `TCMFindOptions` | Read/Write | The last search options |
| `CanPrint` | returns `Boolean` | ― | Whether printing is possible (`True` if `Preview` is selected) |
| `Print` | ― | ― | Opens the print dialog (TCPreview manual 6.5). If the preview is not shown, shows it only during printing. Does nothing if there is no `Preview` |
| `SetFocus` | ― | ― | Puts the cursor in the editor and makes it ready for input. The move happens after the current processing (button click, `OnKeyDown`, `OnReady`, etc.) finishes (it can be called from anywhere). Does nothing for an editor that is not visible or not enabled |
| `TopLine` | returns `Double` | ― | The first line displayed (an integer value) |
| `ScrollToLine` | `ALine: Double` | ― | Scrolls so that the line is at the top |
| `IsDarkTheme` | returns `Boolean` | ― | Whether it is currently drawn in the dark color scheme (with `ctAuto`, the OS color scheme) |
| `Ready` | `Boolean` | Read | Always `True` at runtime |
| `ContextMenu` | `TPopupMenu` | Read | The component's right-click menu (for advanced users. When adding your own items; 15.6) |
| `Color` | `TColor` | Read | Background color (determined by `Theme`. Visible for a moment when tabs switch) |

### 6.2 Events

`Sender` is always that editor (TCsEditor). The handling of one event can be shared by multiple editors (distinguish them with `Sender as TCsEditor`).

| Name | Arguments | Description |
|---|---|---|
| `OnReady` | `Sender: TObject` | Once, when first displayed at runtime |
| `OnChange` | `Sender: TObject` | The body of the visible tab changed (not only from a person's typing but also when changed in code. Once per change) |
| `OnCursorChange` | `Sender: TObject; Line, Column: Integer` | The cursor of the visible tab moved (line and column start at 1. The column is in UTF-16 units) |
| `OnModeChange` | `Sender: TObject; IsOverwrite: Boolean` | Insert/overwrite was toggled |
| `OnModifiedChange` | `Sender: TObject` | The ` *` of the visible tab was added or removed |
| `OnActiveChange` | `Sender: TObject` | The visible tab was switched |
| `OnDocListChange` | `Sender: TObject` | Tabs were added, removed or reordered (also once when the last tab is closed and an empty untitled tab is created) |
| `OnDocumentChange` | `Sender: TObject; Index: Integer` | A tab's name, language or ` *` changed (including tabs that are not visible) |
| `OnSave` | `Sender: TObject; const AFileName: string` | Saved |
| `OnQueryClose` | `Sender: TObject; Index: Integer; var CanClose: Boolean` | Before closing or replacing a tab with unsaved changes (9.5) |
| `OnNeedFileName` | `Sender: TObject; var AFileName: string; var Cancel: Boolean` | Decides the name when saving an untitled document |
| `OnFileDrop` | `Sender: TObject; Files: TStrings; var Handled: Boolean` | Files were dropped. `Handled := True` stops the standard open processing |
| `OnToggleMaximize` | `Sender: TObject` | `F12` was pressed (maximizing is implemented by the application) |
| `OnFontSizeChange` | `Sender: TObject` | The text size changed with `Ctrl+Wheel` |
| `OnLineNumbersChange` | `Sender: TObject` | Line numbers were toggled with `F11` |
| `OnFindDone` | `Sender: TObject; Found: Boolean` | Result of a search (raised for searches from the dialog as well as `Find` etc.) |
| `OnReplaceAllDone` | `Sender: TObject; Count: Integer` | Result of replace all |
| `OnPopup` | `Sender: TObject` | Just before the right-click menu is shown |
| `OnGetTabImageIndex` | `Sender: TObject; Index: Integer; const FileName: string; var ImageIndex: Integer` | When deciding a tab's icon (only when `TabImages` is set; 9.3) |
| `OnTabDragOut` | `Sender: TObject; Index, X, Y: Integer; var TearOff: Boolean` | A tab was dropped outside the application's window (9.9). `Index` is the tab number, `X` and `Y` are the screen position where it was dropped. `TearOff := False` disables the component's detach/attach behavior |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A key was pressed (ordinary character keys also arrive; 9.6). `Key := 0` stops that key's action |
| `OnError` | `Sender: TObject; const AMessage: string` | All editor errors (cannot read, cannot write, same file already open, etc.) |

**Default behavior when not set**

| Name | When not set |
|---|---|
| `OnError` | Shows the message. The same message is shown only once |
| `OnNeedFileName` | Shows `SaveDialog` (the built-in one if not set) |
| `OnQueryClose` | Follows `ConfirmOnFormClose` (9.5) |
| `OnFileDrop` | Performs the standard open processing |
| `OnToggleMaximize` | Does nothing |
| `OnGetTabImageIndex` | Uses item 0 of `TabImages` |
| `OnTabDragOut` | Follows `TabTearOff` (9.9) |
| Others | Do nothing (notification-only events) |

## 7. Settings (Object Inspector)

| Name | Type | Default | Description |
|---|---|---|---|
| `MultiDocument` | `Boolean` | `True` | `True` = with tabs (multiple files) / `False` = a single file only (9.1). Can be changed only at design time (and right after creating it in code). Changing it at runtime is ignored |
| `ConfirmOnFormClose` | `Boolean` | `True` | When closing an unsaved document and `OnQueryClose` is not set: `True` = confirmation dialog / `False` = discard without asking (9.5) |
| `TabTearOff` | `Boolean` | `True` | `True` = dropping a tab outside the window opens it in a separate window. Dropping it on an editor in another window of the same EXE opens it there as a new tab. Tabs dropped from other windows are also accepted (9.9) |
| `OpenDialog` | `TOpenDialog` | nil | Dialog used for opening. The built-in one if not set (table below) |
| `SaveDialog` | `TSaveDialog` | nil | Dialog used for saving. The built-in one if not set |
| `FindDialog` | `TCsFindDialog` | nil | Find/replace dialog. The built-in shared dialog if not set (chapter 10) |
| `TabFlat` | `Boolean` | `True` | `True` = rectangular / `False` = trapezoid |
| `TabSeparator` | `Boolean` | `False` | Whether to draw a thin vertical line between unselected tabs. Effective only when `TabFlat = True` |
| `TabIcons` | `Boolean` | `True` | Whether to show icons on tabs (9.3) |
| `TabImages` | `TImageList` | nil | Image list of icons you prepared yourself. If not set, Windows icons are shown automatically (9.3) |
| `WordWrap` | `Boolean` | `True` | Word wrap |
| `LineNumbers` | `Boolean` | `False` | Line numbers. Can also be toggled with `F11` |
| `Font` | `TFont` | BIZ UDGothic, 14 pt | Body text font (name, size, weight, etc.). The text color is determined by `Theme`; `Font.Color` is not used |
| `FontSize` | `Integer` | 14 | Text size (6 to 72). Same as `Font.Size` |
| `TabSize` | `Integer` | 4 | Tab width (1 to 16). The Tab key inserts spaces |
| `Folding` | `Boolean` | `True` | Code folding |
| `MatchBrackets` | `Boolean` | `True` | Shows matching brackets (`( )`, `[ ]`, `{ }`), keyword pairs (`begin`/`end`, etc.) and tag pairs with a frame |
| `OccurrencesHighlight` | `Boolean` | `True` | Highlights words identical to the word at the cursor position |
| `Minimap` | `Boolean` | `False` | Minimap (9.11). Can also be toggled with `Ctrl+Shift+M` |
| `Theme` | `TCMTheme` | `ctAuto` | Color theme. `ctAuto` (follows the OS color scheme; changes on the spot when the OS is switched) / `ctLight` (fixed to the light theme) / `ctDark` (fixed to the dark theme). The preview follows as well |
| `ReadOnly` | `Boolean` | `False` | Read-only |
| `DefaultLanguage` | `string` | 'pascal' | Language of new documents and of documents whose extension is unknown |
| `AutoLanguage` | `Boolean` | `True` | Determines the language from the file name extension |
| `OpenDroppedFiles` | `Boolean` | `True` | Opens dropped files |
| `QuotePrefix` | `string` | '> ' | The mark at the start of each line for "copy with quotes" |
| `HitColorLight` | `TColor` | #FFEE58 | Background color of a search hit (the selection while the editor does not have focus) (light theme) |
| `HitColorDark` | `TColor` | #7D6608 | Same (dark theme) |
| `CursorLineColorLight` | `TColor` | #EAF2FF | Background color of the cursor line (light theme) |
| `CursorLineColorDark` | `TColor` | #2C313C | Same (dark theme) |
| `SelectionColorStyle` | `TCMSelectionColorStyle` | `scStandard` | Color set for the selection. `scStandard` (dark #264F78, light #ADD6FF; same as VS Code) / `scBlue` (dark #0E5A9E, light #7FB6FF) / `scAmber` (dark #6B4E00, light #FFD54F) / `scPurple` (dark #5A2D82, light #C5A3FF) / `scCustom` (the two colors below). Choosing anything other than `scCustom` changes the two colors below to that set's colors |
| `SelectionColorLight` | `TColor` | #ADD6FF | Background color of the selection (light theme; when focused). Writing it sets `SelectionColorStyle` to `scCustom`. The color of the text inside the selection does not change |
| `SelectionColorDark` | `TColor` | #264F78 | Same (dark theme). Writing it sets `SelectionColorStyle` to `scCustom` |
| `Preview` | `TCPreview` | nil | The preview component (chapter 11). Multiple editors can select the same TCPreview |
| `ShowPreview` | `Boolean` | `False` | Whether to show the preview (chapter 11). Can also be toggled with `Ctrl+Shift+V`. Does nothing if there is no `Preview` |
| `AllowRemoteImages` | `Boolean` | `False` | Whether the preview shows images from the web (http). Same as `AllowRemoteImages` of `Preview` |
| `Lines` | `TStrings` | Empty | Initial body of the first tab |
| `Align` | `TAlign` | | Placement within the parent |
| `Anchors` | `TAnchors` | | Which edges follow when the parent's size changes |
| `BorderSpacing` | `TControlBorderSpacing` | | Surrounding margins |
| `Constraints` | `TSizeConstraints` | | Upper and lower size limits |
| `Enabled` | `Boolean` | | Whether it is usable |
| `Visible` | `Boolean` | | Whether it is shown |
| `TabOrder` | `TTabOrder` | | Order of movement with the Tab key |
| `TabStop` | `Boolean` | | Whether the Tab key stops here |

- `LineDelimiters`, `LineSkipEmpty` and `LineQuoteChar` do not appear in the Object Inspector. Set them in code (chapter 13).
- Preview settings (text size, colors, etc.) are made on the TCPreview side (`ed.Preview.FontSize`, etc.).

**Color settings (the 6 whose names end in `Color`)**

- In the Object Inspector, choose from the color list or from the "..." color dialog.
- When a system color (`clWindow`, etc.) is chosen, it becomes the actual color at the time of setting. That color does not change even if the OS color scheme is switched.
- When `clDefault` or `clNone` is chosen, it becomes the default color.

**Built-in dialogs**

| Item | Details |
|---|---|
| Filter | Markdown (*.md; *.markdown) / Text (*.txt) / All files (*.*) |
| Default extension for saving | Determined from that tab's language (markdown→md, plaintext→txt, pascal→pas, html→html, css→css, javascript→js, json→json, xml→xml, sql→sql, ini→ini, bat→bat, python→py, cpp→cpp, csharp→cs, typescript→ts, java→java, shell→sh, powershell→ps1, yaml→yaml, php→php, go→go) |
| Initial folder | That tab's folder. If untitled, the folder used previously |

## 8. Keys

### 8.1 Built-in Shortcuts

Keys are received only by the editor that has focus. All of the following shortcuts can be replaced with `OnKeyDown` (9.6).

| Key | Action |
|---|---|
| `Ctrl+S` | Saves the visible tab. If untitled, `OnNeedFileName` (the save dialog if not set) |
| `Ctrl+F` | Opens the find/replace dialog. If a range within one line is selected, it becomes the initial search term |
| `F5` / `Shift+F5` | Searches next / previous with the last search term. If there is no search term, opens the dialog |
| `Ctrl+Shift+V` | Toggles the preview on and off (chapter 11). Does nothing if there is no `Preview` |
| `Ctrl+Shift+P` | Does nothing. If the form has the same shortcut, that is executed |
| `Ctrl+P` | Prints (same as `Print`) |
| `Ctrl+Shift+M` | Toggles the minimap on and off (`Minimap`) |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Switches to the next tab / previous tab (wraps around at the ends). Body focus moves to the new tab, so you can keep pressing. Does nothing when `MultiDocument = False` |
| `Shift+F10` | Duplicates the cursor line and moves down to it (same as `DuplicateLine`) |
| `F11` | Toggles line numbers on and off |
| `F12` | Raises `OnToggleMaximize` |
| `Insert` | Toggles insert/overwrite |
| `Ctrl+Wheel` | Changes the text size (all tabs; `OnFontSizeChange`) |
| `Ctrl+A` | Selects all |

### 8.2 Editor Keys

| Key | Action |
|---|---|
| `←`, `→`, `↑`, `↓`, `Home`, `End`, `PageUp`, `PageDown` | Move the cursor (adding `Shift` selects while moving) |
| `Ctrl+←`, `Ctrl+→` | Move by word (adding `Shift` selects while moving) |
| `Ctrl+↑`, `Ctrl+↓` | Scroll by one line |
| `Ctrl+Home`, `Ctrl+End` | To the start / end of the document (adding `Shift` selects while moving) |
| `BackSpace`, `Delete` | Delete one character |
| `Ctrl+BackSpace`, `Ctrl+Delete` | Delete a word |
| `Enter` | Line break (indentation is the same as the previous line) |
| `Tab` | Inserts spaces up to the next tab stop (`TabSize`) |
| `Shift+Tab` | Reduces indentation |
| `Ctrl+X`, `Shift+Delete` | Cut |
| `Ctrl+C`, `Ctrl+Insert` | Copy |
| `Ctrl+V`, `Shift+Insert` | Paste |
| `Ctrl+Z` | Undo |
| `Ctrl+Y`, `Ctrl+Shift+Z` | Redo |
| `Alt+↑`, `Alt+↓` | Move the line up/down (if lines are selected, those lines together) |
| `Shift+Alt+↑`, `Shift+Alt+↓` | Duplicate the line upward/downward |
| `Ctrl+]`, `Ctrl+[` | Indent / outdent |
| `Ctrl+/` | Toggle line comment (using the language's comment syntax; table below) |
| `Ctrl+G` | Go to a specified line (shows a dialog asking for the line number) |
| `Ctrl+Shift+[`, `Ctrl+Shift+]` | Fold / unfold |
| `Ctrl+Enter` | Inserts an empty line below and moves there (indentation is the same as the current line) |
| `Shift+Alt+Drag` | Selects a rectangular range |

- Keys not listed here (SynEdit's default keys, etc.) do nothing in the editor. They are passed on to the form's shortcuts.
- When `ReadOnly`, editing actions (moving lines, duplicating, commenting, inserting a line) do nothing.

| Language | Line comment |
|---|---|
| pascal, javascript, json, typescript, cpp, csharp, java, php, go | `// ` |
| python, shell, yaml, powershell | `# ` |
| sql | `-- ` |
| ini | `; ` |
| bat | `REM ` |
| html, xml, markdown | `<!-- ` before the line and ` -->` after it |
| css | `/* ` before the line and ` */` after it |
| plaintext | None (does nothing) |

## 9. Behavior

### 9.1 MultiDocument

A single `MultiDocument` property switches both the tab display and the behavior when opening. When placing several on one form and handling one file in each, set `MultiDocument = False` for each editor.

| | `True` (with tabs, default) | `False` (single file only) |
|---|---|---|
| Tab display | Shown | Not shown (the editor is that much larger) |
| Opening a file | Opens in a new tab | Replaces the contents, leaving the tab as is (asks if unsaved) |
| New | Adds a tab | Empties the contents (asks if unsaved) |
| Closing (`Close`, `CloseAll`) | Closes the tab (if it is the last one, an empty untitled tab remains) | Empties the contents (asks if unsaved). `OnDocListChange` and `OnActiveChange` are not raised |
| Dropping files | Opens in new tabs | Replaces the contents (first file only) |

**Tab operations (`MultiDocument = True`)**

| Operation | Behavior |
|---|---|
| Click | Switches to that tab and puts focus in the body |
| [+] | Adds a new document |
| [×], middle-click | Closes. If unsaved, the confirmation in 9.5 is shown |
| Drag | Reorders the tabs |
| Drag onto another TCsEditor on the same form | Moves that tab (9.10) |
| Drag outside the window | Opens in a separate window (9.9) |
| Hover the mouse | A hint with the full path appears |

- Each document keeps its file name, encoding, line ending, ` *`, Undo/Redo history, cursor position, scroll position and language. When you switch away and back, they are restored.
- Right after startup, there is one untitled document. `OpenFile` does not use this untitled document; it always opens in a new tab.
- Search and replace target only the visible tab.

### 9.2 Files and Languages

- When loading, the character encoding is detected. If there is a BOM, it follows the BOM; if not, it checks whether the data is valid UTF-8, and if not, treats it as CP932 (Shift_JIS).
- When saving, the encoding and BOM from when the file was loaded are used.
- If there are characters that cannot be represented in CP932, saving fails (`OnError`; ` *` remains). Change `Encoding` to UTF-8 and then save.
- The line ending (CRLF / LF) is the one from when the file was loaded (the first line break found). Documents with no line breaks and new documents use CRLF.
- Trailing whitespace on lines is not removed on save.
- The file is not locked (it is open only during reading and writing).
- The language is determined from the extension at `LoadFromFile` and `OpenFile` (when `AutoLanguage = True`). When the extension changes through Save As, the language is switched as well.

| Extension | Language | Syntax highlighting |
|---|---|---|
| .pas .pp .lpr .inc .dpr .lpk | pascal | Yes |
| .md .markdown | markdown | Yes (headings, emphasis, code, quotes, lists, links) |
| .txt | plaintext | No |
| .html .htm / .css / .js / .json / .xml | html / css / javascript / json / xml | Yes |
| .sql / .ini .cfg / .bat .cmd / .py / .c .h .cpp .hpp | sql / ini / bat / python / cpp | Yes |
| .cs | csharp | Yes |
| .ts .tsx | typescript | Yes |
| .java | java | Yes |
| .sh .bash | shell | Yes |
| .ps1 .psm1 .psd1 | powershell | No |
| .yml .yaml | yaml | No |
| .php | php | Yes |
| .go | go | No |
| Anything else | `DefaultLanguage` (default is pascal) | |

- Languages marked "No" for syntax highlighting are still used for line comments (`Ctrl+/`) and the default extension when saving.

### 9.3 Tab Icons

Depending on the file type, the same Windows icon as in Explorer is shown automatically at the left end of the tab. It appears with the defaults (`TabIcons = True`, no `TabImages`).

| Situation | Icon shown |
|---|---|
| A tab with an opened file | The icon for that file's extension |
| An untitled tab | The text icon (the .txt icon) |
| The extension changed through Save As | The icon for the new extension |

- To hide the icons, set `TabIcons = False`.

**Using icons you prepared yourself**

1. Place a `TImageList` on the form and add the icons.
2. Select that image list in `TabImages`.
3. In `OnGetTabImageIndex`, decide the index to use for each tab (`ImageIndex := -1` for no icon). If not set, index 0 is used for all tabs (15.9).

### 9.4 Color Theme

- With `Theme = ctAuto` (default), it follows the OS dark/light setting. Even if the OS is switched while running, the body, tabs, scrollbar, minimap, background and preview are repainted on the spot.
- With `ctLight` or `ctDark`, that color theme is fixed regardless of the OS.
- Body colors are the same as VS Code (TCMonacoEditor) (light and dark).

| Part | Dark | Light |
|---|---|---|
| Body background | #1E1E1E | #FFFFFE |
| Body text | #D4D4D4 | #000000 |
| Reserved words | #569CD6 | #0000FF |
| Strings | #CE9178 | #A31515 |
| Comments | #6A9955 | #008000 |
| Numbers | #B5CEA8 | #098658 |
| Line numbers | #6E7681 | #237893 |
| Line number of the cursor line | #C6C6C6 | #0B216F |
| Folding marks | #5A5A5A | #424242 |
| Tab strip and unselected tabs | #2B2B2B | #F0F0F0 |
| Tab under the mouse | #383838 | #E5E5E5 |
| Visible tab | #1E1E1E | #FFFFFF |
| Text of the visible tab | #FFFFFF | #000000 |
| Text of unselected tabs | #C5C5C5 | #5C5C5C |
| [×] and scroll arrows | #C5C5C5 | #5C5C5C |
| Separator lines and tab borders | #3A3A3A | #D9D9D9 |
| Scrollbar | Windows dark appearance | Windows normal appearance |

- The cursor line background is determined by `CursorLineColor…`, and the selection background by `SelectionColor…` (`HitColor…` when not focused).
- A search hit is displayed with `HitColorLight` / `HitColorDark` while the editor does not have focus (while operating the find dialog). Clicking the editor returns it to the normal selection color.
- The dark scrollbar appearance requires Windows 10 1809 or later. On earlier Windows versions, it stays the normal appearance.

### 9.5 Confirmation of Unsaved Documents

When a document with `Modified` set to `True` is closed or replaced, `OnQueryClose` is raised.

**When it is raised**

- When closing a tab ([×], middle-click, `ed.Close`, `ed.Pages[n].Close`, `CloseAll`)
- When closing the form (the editor automatically joins the form's close confirmation)
- With `MultiDocument = False`, when opening another file or creating a new one

| Situation | Behavior |
|---|---|
| `OnQueryClose` is set | Follows the event handler (takes precedence over `ConfirmOnFormClose`) |
| Not set. `ConfirmOnFormClose = True` (default) | Shows "(Title) has been modified. Do you want to save it? (No = close without saving)". Yes = save and close (does not close if saving fails), No = close without saving, Cancel = do not close |
| Not set. `ConfirmOnFormClose = False` | Discards without asking |

- Inside the event, to cancel closing, set `CanClose := False`. To discard without saving, do nothing (`CanClose` stays `True`). To save, save inside the event (15.3).
- `Index` is the number of the document being closed. It is not necessarily the visible tab.
- If even one is canceled when closing the form, the exit is canceled at that point.

### 9.6 Adding or Replacing Keys (OnKeyDown)

| Item | Description |
|---|---|
| Keys reported | All keys (including ordinary character keys) |
| Replacing built-in behavior | Setting `Key := 0` prevents that key's action (built-in shortcut or editor key) from happening |
| Form shortcuts | Keys not used by built-in shortcuts are passed to the shortcuts of the form's main menu and ActionList (so menu shortcuts such as Ctrl+O work even when the editor has focus) |
| Form `KeyPreview` | Works (with `KeyPreview = True`, the form's `OnKeyDown` comes first) |

**Order in which keys are processed**

1. The form's `OnKeyDown` (when `KeyPreview = True`)
2. The inherited component's `KeyDown` (if overridden)
3. `OnKeyDown`, inside `inherited`
4. If `Key <> 0` still holds at this point: `Ctrl+P`, `Ctrl+Shift+M`, `Ctrl+Tab`, `Ctrl+Shift+Tab`
5. The built-in shortcuts in 8.1
6. If the form's main menu or ActionList has the same shortcut, it is executed (not passed to the editor)
7. The editor keys in 8.2

- `Ctrl+Z`, `Ctrl+Y`, `Ctrl+Shift+Z`, `Ctrl+X`, `Ctrl+C` and `Ctrl+V` perform the editor's action (7) even if the form has the same shortcut.
- For the other keys in 8.2, if the form has the same shortcut, the form takes precedence.

**When creating your own component by inheritance**

TCsEditor has a protected virtual method `KeyDown(var Key: Word; Shift: TShiftState)` (the same form as LCL's TWinControl). Calling `inherited` calls `OnKeyDown` inside it. If you do not call it, `OnKeyDown` is not called either (15.13).

### 9.7 Right-Click Menu

| State | Items shown |
|---|---|
| Text is selected | Cut, Copy, Paste, Copy with Quotes, Append Cut, Append Copy, Delete, TO UPPER CASE, to lower case, Convert to Half-width, Convert to Full-width Hiragana, Convert to Full-width Katakana, TAB -> Spaces, Spaces -> TAB, Indent, Outdent |
| Nothing selected | Paste, Select All, Undo, Redo |
| Always (last) | Separator, Minimap　Ctrl+Shift+M, Preview　Ctrl+Shift+V |

- Minimap and Preview toggle `Minimap` and `ShowPreview` respectively. They are checked when the current value is on. They affect all tabs of the editor. Preview cannot be used without `Preview`.
- When `ReadOnly`, the editing items cannot be used.
- For the conversion items, the converted string remains selected, and one Undo reverts it.
- "Copy with Quotes" copies with `QuotePrefix` added at the start of each line. "Append Cut" and "Append Copy" add to the end of the current clipboard contents.
- To add your own items, use `ed.ContextMenu.Items.Add` (15.6). Adjust the display with `OnPopup`. Your own items are placed after the items above.

### 9.8 Dropping Files

- Dropping a file on the editor opens it. With `MultiDocument = True`, it opens in a new tab (if already open, switches to that tab), and all dropped files are opened. With `MultiDocument = False`, the current document is replaced (first file only; if unsaved, the confirmation in 9.5 is shown).
- Folders are ignored.
- Setting `OpenDroppedFiles := False`, or `Handled := True` in `OnFileDrop`, stops the standard processing.
- Dropping onto the tab strip or the minimap is not supported.

### 9.9 Detaching and Attaching Tabs (TabTearOff)

When a tab is dragged outside the application's window and released, the result depends on where it is dropped.

| Drop target | Behavior |
|---|---|
| The desktop, or over another application's window | Detach: starts one more instance of the same EXE and opens that tab in it. The tab disappears from the original window |
| Over an editor in another window of the same EXE (started separately) | Attach: creates a new tab in that editor and opens it there. The tab disappears from the original window |
| In another window of the same EXE, on something that is not an editor (menu, button, etc.) | Nothing happens |
| Over another TCsEditor on the same form | Moves that tab (9.10) |
| Anywhere else within your own application | Nothing happens |

| Setting | Behavior |
|---|---|
| `TabTearOff = True` (default) | The component does all detaching and attaching. No application code is needed |
| `TabTearOff = False` | Neither detaches nor attaches. Tabs dropped from other windows are not accepted either. `OnTabDragOut` is still raised |

**What is carried over** (both detach and attach)

| Item | Carried over |
|---|---|
| Body | Carried over (including unsaved edits) |
| File name | Carried over |
| Encoding, line ending, language | Carried over |
| Modified mark (` *`) | Carried over |
| Undo history, cursor position, scroll position | Not carried over |

**How it is opened** (both detach and attach)

| Original tab | How it is opened |
|---|---|
| Has a file open, no changes | Opens that file (no ` *`) |
| Has a file open, with changes | Opens with that file name, keeping the unsaved body (with ` *`) |
| Untitled (not yet saved) | Opens as untitled with the body put in (with ` *` if there is a body) |
| Has a file name, but the file on disk has been deleted | Opens as untitled with the body put in (with ` *`) |

**Rules for detaching**

- The new window appears at the position where the tab was dropped. If it would extend beyond the screen, it is shifted to fit.
- The new window accepts an editor with the same names as the original (the form's `Name` and the editor's `Name`) and `TabTearOff = True`.
- If the new window could not be started, the tab is left open rather than closed, and `OnError` is raised.
- In an application that prohibits multiple instances, a new window cannot be started, so detaching is not possible.
- The environment variable `CS_TEAROFF` is used for the handoff (passed only to the new EXE that is started). The application must not use an environment variable of this name.

**Rules for attaching**

- The receiver is the editor of the other window that is under the drop position. The new tab becomes the visible tab of that editor, and the other window is brought to the front.
- If the other editor already has the same file open, no attach occurs. It switches to that tab in the other editor and brings the other window to the front. The original tab remains.
- If the other editor has `TabTearOff = False` or `MultiDocument = False`, nothing happens.
- If the other window does not respond (3 seconds) or is running as administrator, the tab cannot be moved. The original tab remains, and `OnError` is raised.
- It does not detach or attach with a TCMonacoEditor in the same EXE (they do not accept each other's tabs).

**Common rules**

- When there is only one empty untitled tab, neither detaching nor attaching occurs (`OnTabDragOut` is still raised; its `TearOff` value arrives as `False`, so setting it to `True` makes it detach/attach).
- If the tab taken out was the last one, one empty untitled tab remains in the original window.
- If the drag is canceled with `Esc`, nothing happens.

### 9.10 Moving a Tab to Another TCsEditor on the Same Form

When a tab is dragged onto another TCsEditor on the same form (one placed side by side) and released, that tab is moved.

| Situation | Behavior |
|---|---|
| Normal case | Moves the tab to the target and makes it the target's visible tab. The Undo history and cursor position are carried over as they are. It takes on the target's settings (colors, font, etc.) |
| The target already has the same file open | Switches to that tab in the target. The original tab remains |
| The target has `MultiDocument = False` | Nothing happens |
| Only one empty untitled tab | Nothing happens |

- If the moved tab was the last one, one empty untitled tab remains in the original editor.
- Tabs are not moved to a TCsEditor on a different form (nothing happens).

### 9.11 Minimap

With `Minimap = True` (or `Ctrl+Shift+M`), a miniature of the visible tab's body is shown to the right of the body.

```
| Body | Minimap | Scrollbar |
```

| Item | Description |
|---|---|
| How it is drawn | Each line is drawn as a rectangle 2 pixels high, and each character 1 pixel wide (full-width characters 2). The colors are the syntax highlighting colors |
| Long documents | The drawn range moves to follow the editor's position |
| Mark of the visible range | Only while the mouse is over the minimap, a semi-transparent rectangle is overlaid on the range visible in the editor |
| Click | Scrolls so that the line is in the middle of the editor |
| Drag the mark | Scrolls by the amount dragged |
| Wheel | Scrolls the same as the editor |

- While the minimap is shown, the vertical scrollbar appears to the right of the minimap.
- Word wrap is not taken into account (it is drawn by the file's lines).
- It is common to all tabs (it is not switched per tab).

## 10. Find/Replace Dialog

- An editor without `FindDialog` set uses the built-in shared dialog, of which there is only one per form. However many editors are placed, there is only one dialog.
- The target is the editor where `Ctrl+F` was pressed (the editor that last had focus). If you click another editor while the dialog is open, the target switches to it.
- The target is shown in the title (e.g. "Find/Replace - readme.md").
- The dialog's position, search term, replacement term, history and options are common to all editors.
- To control it yourself, place one `TCsFindDialog` on the form from the palette and select it in each editor's `FindDialog`. Multiple editors can select the same dialog.

| Item | Description |
|---|---|
| Search term and replacement term | Combo boxes with history (30 entries) |
| Options | Match case, whole word, loop search (there is no regular expression) |
| Buttons | Find Next, Find Previous, Replace, Replace All, Close. `Enter` finds next, `Esc` closes |
| Result | "Not found" or "N replaced" is shown at the bottom of the dialog |

- Replace replaces the selected string and searches for the next one if it equals the search term. "Replace All" is reverted with one Undo.
- The target is only the visible tab.

**TCsFindDialog methods and properties**

| Name | Type / Arguments | Access | Description |
|---|---|---|---|
| `ShowFor` | `AEditor: TCsEditor; const InitialText: string = ''` | ― | Opens it targeting that editor |
| `CloseDialog` | ― | ― | Closes it |
| `IsShowing` | returns `Boolean` | ― | Whether it is open |
| `Target` | `TCsEditor` | Read/Write | The current target |
| `SearchText` | `string` | Read | The current search term |
| `ReplaceText` | `string` | Read | The current replacement term |
| `Options` | `TCMFindOptions` | Read | The current options |
| `FindHistory`, `ReplaceHistory` | `TStringList` | Read | History (do not `Free`) |

## 11. Preview (TCPreview)

Preview (Markdown, code) and printing are handled by a separate component, TCPreview. For details, see `TCPreview_Usage.md`.

1. Place a TSplitter and a TCPreview on the form (e.g. both with `Align = alRight`).
2. In TCPreview's `Splitter`, select that TSplitter.
3. In TCsEditor's `Preview`, select that TCPreview.

| Name / Operation | Behavior |
|---|---|
| `ShowPreview`, `Ctrl+Shift+V` | Shows / hides the preview (same as TCPreview's `Visible`) |
| `Print`, `Ctrl+P` | Prints the visible tab (including saving as PDF). If the preview is not shown, it is shown only during printing |
| `AllowRemoteImages` | Whether the preview shows images from the web (same as TCPreview's `AllowRemoteImages`) |
| `ed.Preview.…` | Preview settings (`FontSize`, `ColorScheme`, `SyncScroll`, `DelayMs`, etc.) |

- One TCPreview can be selected by multiple TCsEditors. The preview shows the visible tab of the editor that was clicked last.
- `ShowPreview` is common among the editors that selected the same TCPreview.
- A link to a `.md` file in the preview is opened in that editor (unless TCPreview's `OnOpenMarkdown` is set).

## 12. Standard Actions

When operating from the form's menus and buttons, use the standard actions without writing code. Usage is the same as Lazarus's standard actions such as "File Open".

| No | Action (class name) | Display name | Default shortcut | Behavior | Enabled when | Checked |
|---|---|---|---|---|---|---|
| 1 | `TCsEditorNew` | &New | Ctrl+N | `NewPage` | A target editor exists | ― |
| 2 | `TCsEditorOpen` | &Open... | Ctrl+O | Selects with `OpenDialog` (the built-in one if not set) and calls `OpenFile`. With tabs, multiple files can be selected | A target editor exists | ― |
| 3 | `TCsEditorSave` | &Save | Ctrl+S | `Save` (save dialog if untitled) | A target editor exists | ― |
| 4 | `TCsEditorSaveAs` | Save &As... | None | `SaveAs` | A target editor exists | ― |
| 5 | `TCsEditorClose` | &Close | Ctrl+W | `Close` (shows the confirmation in 9.5). When `MultiDocument = False`, confirms and empties the contents | A target editor exists | ― |
| 6 | `TCsEditorPrint` | &Print... | Ctrl+P | `Print` | `CanPrint` | ― |
| 7 | `TCsEditorSaveAll` | Save A&ll | Ctrl+Shift+S | `SaveAll` | There are tabs with changes | ― |
| 8 | `TCsEditorCloseAll` | Close &All | None | `CloseAll` (shows the confirmation in 9.5) | A target editor exists | ― |
| 9 | `TCsEditorUndo` | &Undo | Ctrl+Z | `Undo` | `CanUndo` | ― |
| 10 | `TCsEditorRedo` | &Redo | Ctrl+Y | `Redo` | `CanRedo` | ― |
| 11 | `TCsEditorCut` | Cu&t | Ctrl+X | `Cut` | Something is selected (`SelLength > 0`) and not `ReadOnly` | ― |
| 12 | `TCsEditorCopy` | &Copy | Ctrl+C | `Copy` | Something is selected (`SelLength > 0`) | ― |
| 13 | `TCsEditorPaste` | &Paste | Ctrl+V | `Paste` | The clipboard has text and not `ReadOnly` | ― |
| 14 | `TCsEditorSelectAll` | Select &All | Ctrl+A | `SelectAll` | A target editor exists | ― |
| 15 | `TCsEditorDuplicateLine` | &Duplicate Line | Shift+F10 | `DuplicateLine` | Not `ReadOnly` | ― |
| 16 | `TCsEditorDeleteToEnd` | Delete to End | None | `DeleteToEnd` | Not `ReadOnly` | ― |
| 17 | `TCsEditorDeleteToStart` | Delete to Start | None | `DeleteToStart` | Not `ReadOnly` | ― |
| 18 | `TCsEditorFind` | &Find/Replace... | Ctrl+F | `ShowFindDialog` | A target editor exists | ― |
| 19 | `TCsEditorFindNext` | Find &Next | F5 | `FindNext` | A target editor exists | ― |
| 20 | `TCsEditorFindPrev` | Find Pre&vious | Shift+F5 | `FindPrev` | A target editor exists | ― |
| 21 | `TCsEditorMinimap` | &Minimap | Ctrl+Shift+M | Toggles `Minimap` | A target editor exists | `Minimap` |
| 22 | `TCsEditorPreview` | Pre&view | Ctrl+Shift+V | Toggles `ShowPreview` | `Preview` exists | `ShowPreview` |
| 23 | `TCsEditorLineNumbers` | &Line Numbers | F11 | Toggles `LineNumbers` | A target editor exists | `LineNumbers` |
| 24 | `TCsEditorWordWrap` | &Word Wrap | None | Toggles `WordWrap` | A target editor exists | `WordWrap` |
| 25 | `TCsEditorRemoteImages` | Show Remote &Images | None | Toggles `AllowRemoteImages` | `Preview` exists | `AllowRemoteImages` |

- Usage: place a `TActionList` on the form, add actions of the category `CX TCsEditor` from "Add Standard Actions" in the action list editor, and select them in the menu items' `Action`.
- The target is determined automatically as the editor that last had focus. If none has had focus yet, the first editor. To find out from code, use `CsActiveEditor(Form)`.
- When unavailable, they are grayed out. Enabled/disabled state and check marks are refreshed by Lazarus when the application is idle and when a menu is opened.
- Action shortcuts work even when the editor has focus (9.6). However, for keys identical to a built-in shortcut, the built-in one comes first (the behavior is the same). To give the action priority, replace it in `OnKeyDown`.
- The display name, hint and shortcut may be changed in the Object Inspector after adding.
- If `OnExecute` is set, it is called instead of the standard behavior. If `OnUpdate` is set, it is called instead of the standard refresh (same as `TAction`).
- For exiting, use Lazarus's standard action `TFileExit`.

## 13. Cursor Line String and Words

### 13.1 Available Values

| Notation | What you get | In awk terms |
|---|---|---|
| `ed.LineText` | The string of the cursor line (without the line break) | `$0` |
| `ed.LineWords[0]` | The first word | `$1` |
| `ed.LineWords[1]` | The second word | `$2` |
| `ed.LineWords.Count` | The number of words | `NF` |

- It can be read anywhere (inside `OnCursorChange`, in buttons, menus, timers, etc.). You get the value of the cursor line at the moment of reading (correct even right after typing).
- Reading inside `OnKeyDown` gives the line before that key takes effect.
- The target is the cursor line of the visible tab.
- Reading `LineWords[0]` on a line with 0 words (such as an empty line) causes an out-of-range error. Check `Count` first.
- The `LineWords` list is owned by the component. Do not `Free` it. Its contents change the next time it is read, so to keep them, copy them into your own `TStringList` with `Assign`.

### 13.2 Split Settings

| Name | Default | Description |
|---|---|---|
| `LineDelimiters` | Half-width space, full-width space, tab, comma (`,`), Japanese comma (`、`) | Delimiter characters. Each character written becomes a delimiter. Full-width characters can also be written. If '', the whole line is one word |
| `LineSkipEmpty` | `True` | `True`: consecutive delimiters are treated as one and empty words are not included. Delimiters at the start and end of the line are also ignored. `False`: empty words are included |
| `LineQuoteChar` | `"` | Quote character (one half-width character). If `#0`, quotes are not interpreted |

- None of the three appear in the Object Inspector. Set them in code.

### 13.3 Splitting Rules

1. The line is scanned one character at a time from the start, and split at characters in `LineDelimiters`.
2. If a word begins with a quote character, everything up to the next quote character becomes one word. It is not split at delimiters inside. The quote characters are removed.
3. Writing two quote characters in a row inside quotes gives a single quote character.
4. Characters from after the closing quote to the next delimiter are attached to the end of the same word.
5. If there is no closing quote, everything to the end of the line becomes one word.
6. A quote character in the middle of a word is treated as an ordinary character.
7. If the quote character is also included in `LineDelimiters`, it is treated as a delimiter (not interpreted as a quote).
8. With `LineSkipEmpty = True`, empty words (where delimiters are consecutive, delimiters at the start and end of the line, `""`) are not included.
9. An empty line has 0 words (regardless of `LineSkipEmpty`).

**Examples (`LineDelimiters = ','`, `LineSkipEmpty = True`, `LineQuoteChar = '"'`)**

| Line | `LineWords` |
|---|---|
| `a,b,c` | `a`, `b`, `c` |
| `a,,b` | `a`, `b` |
| `,a,b,` | `a`, `b` |
| `x,"a,b",y` | `x`, `a,b`, `y` |
| `"a""b"` | `a"b` |
| `"a,b"c,d` | `a,bc`, `d` |
| `ab"c,d` | `ab"c`, `d` |
| `x,"a,b` | `x`, `a,b` |
| `x,"",y` | `x`, `y` |
| (empty line) | (0 words) |

- With `LineSkipEmpty = False`, `a,,b` becomes `a`, empty, `b` (3 words), and `,a,` becomes empty, `a`, empty (3 words).
- With `LineQuoteChar = #0`, `x,"a,b",y` becomes `x`, `"a`, `b"`, `y` (4 words).

**Examples (default settings)**

| Line | `LineWords` |
|---|---|
| `  procedure   Foo;` | `procedure`, `Foo;` |
| `Name　Yamada　Taro` (full-width spaces) | `Name`, `Yamada`, `Taro` |
| `say "hello world"` | `say`, `hello world` |
| `Tokyo、Kanagawa,Saitama` | `Tokyo`, `Kanagawa`, `Saitama` |

- `LineWords` is split only when it is read. If the line and settings are the same as at the previous read, the previous result is returned without splitting again.

## 14. Notes

| Item | Description |
|---|---|
| How `SelStart`, `SelLength` and columns are counted | In UTF-16 units (emoji count as 2) |
| `OnChange` | Also raised when the body is changed in code (`Text :=`, `SelText :=`, etc.) |
| Scroll synchronization | By line (does not match positions within a line) |
| Line ending | Even if CRLF and LF are mixed within one document, on saving they are unified to the line ending determined when it was loaded |
| Syntax highlighting | powershell, yaml, go and plaintext are not highlighted |
| Multi-cursor, command palette | Not available |
| Regular expression search | Not available |
| Printing | Cannot print without a TCPreview |

## 15. Usage Examples

### 15.1 Making a text editor without writing code

1. Place one TCsEditor on the form and set `Align = alClient`.

With just this, the following are possible.

| Feature | Operation |
|---|---|
| Editing | As is |
| Opening files | Drop |
| Switching tabs | `Ctrl+Tab`, `Ctrl+Shift+Tab`, clicking a tab |
| Showing / hiding line numbers | `F11` |
| Find / replace | `Ctrl+F`, `F5` / `Shift+F5` |
| Overwrite save | `Ctrl+S` (if untitled, the "Save As" dialog) |
| Minimap | `Ctrl+Shift+M` |
| Syntax highlighting | Automatic from the extension |
| Confirmation of unsaved documents | Checked automatically when the form is closed |

To add preview and printing, place a TCPreview as described in chapter 11.

### 15.2 Placing two side by side and moving tabs between them

1. Place two TCsEditors; set the left to `Align = alLeft` and the right to `Align = alClient`.
2. Place a TSplitter (`Align = alLeft`) between them.

No code is needed. Dragging a tab between the left and right editors moves it (9.10). The find/replace dialog is a single shared one, and the editor where `Ctrl+F` was pressed becomes the target. Standard actions act on the editor that last had focus.

### 15.3 Saving unsaved documents without asking

```pascal
procedure TForm1.CsEditor1QueryClose(Sender: TObject; Index: Integer;
  var CanClose: Boolean);
var
  E: TCsEditor;
begin
  E := Sender as TCsEditor;
  E.Pages[Index].Save;                          // Save (the save dialog appears if untitled)
  CanClose := not E.Pages[Index].Modified;      // Do not close if canceled in the save dialog
end;
```

### 15.4 Adding a menu

1. Place a `TActionList` and a `TMainMenu` on the form.
2. In the action list editor, add the standard actions of the category `CX TCsEditor` (chapter 12).
3. Select the actions in the menu items' `Action`.

### 15.5 Using your own dialogs

1. Place `TOpenDialog`, `TSaveDialog` and `TCsFindDialog` on the form, and set the filters and initial folder.
2. Select them in each editor's `OpenDialog`, `SaveDialog` and `FindDialog`.

### 15.6 Adding your own item to the right-click menu

```pascal
procedure TForm1.FormCreate(Sender: TObject);
var
  MI: TMenuItem;
begin
  MI := TMenuItem.Create(Self);
  MI.Caption := 'Enclose in [ ]';
  MI.OnClick := @MyMenuClick;
  CsEditor1.ContextMenu.Items.Add(MI);
end;

procedure TForm1.MyMenuClick(Sender: TObject);
begin
  CsEditor1.SelText := '[' + CsEditor1.SelText + ']';
end;
```

### 15.7 Reading and writing the body by line

```pascal
var
  i: Integer;
begin
  for i := 0 to CsEditor1.Lines.Count - 1 do
    Memo1.Lines.Add(CsEditor1.Lines[i]);         // Lines of the visible tab

  CsEditor1.Lines := Memo1.Lines;                // Replace the body of the visible tab
  Label1.Caption := CsEditor1.Pages[1].Lines[0]; // First line of tab 1
end;
```

### 15.8 Replacing the built-in Ctrl+S with your own save processing

```pascal
procedure TForm1.CsEditor1KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_S) and (ssCtrl in Shift) then
  begin
    MySave(Sender as TCsEditor);
    Key := 0;   // The built-in save does not run
  end;
end;
```

### 15.9 Deciding tab icons yourself

```pascal
procedure TForm1.CsEditor1GetTabImageIndex(Sender: TObject; Index: Integer;
  const FileName: string; var ImageIndex: Integer);
begin
  if SameText(ExtractFileExt(FileName), '.md') then
    ImageIndex := 0
  else
    ImageIndex := 1;
end;
```

### 15.10 Showing the words of the cursor line

```pascal
procedure TForm1.CsEditor1CursorChange(Sender: TObject; Line, Column: Integer);
var
  W: TStrings;
  i: Integer;
begin
  Label1.Caption := CsEditor1.LineText;
  W := CsEditor1.LineWords;
  Memo1.Lines.Clear;
  for i := 0 to W.Count - 1 do
    Memo1.Lines.Add(W[i]);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  CsEditor1.LineDelimiters := ' ' + '　' + #9;   // Do not split at commas or the Japanese comma
end;
```

### 15.11 Opening a file at startup and putting focus in the editor

```pascal
procedure TForm1.CsEditor1Ready(Sender: TObject);
begin
  CsEditor1.OpenFile('C:\docs\readme.md');
  CsEditor1.SetFocus;
end;
```

### 15.12 Using the inner editor (TCSynEdit) directly (for advanced users)

```pascal
// In the inner editor of the visible tab, show the right-edge guide line
CsEditor1.SynEdit.RightEdge := 100;
CsEditor1.SynEdit.RightEdgeColor := clGray;
```

- Do not change `OnChange`, `OnStatusChange` or `PopupMenu`, because the component uses them.
- Colors, font, tab width, etc. are re-applied to the inner editor when TCsEditor's settings (chapter 7) are changed.

### 15.13 Creating your own component by inheritance

```pascal
procedure TMyEditor.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_S) and (ssCtrl in Shift) then
  begin
    MySave;
    Key := 0;          // The built-in save does not run
    Exit;
  end;
  inherited KeyDown(Key, Shift);   // OnKeyDown is called here
end;
```

### 15.14 Creating it in code

```pascal
uses
  uCsEditor;

procedure TForm1.FormCreate(Sender: TObject);
var
  E: TCsEditor;
begin
  E := TCsEditor.Create(Self);
  E.MultiDocument := False;   // Change this before setting Parent
  E.Parent := Self;           // It joins the form's close confirmation here
  E.Align := alClient;
end;
```

### 15.15 Switching over from TCMonacoEditor

| TCMonacoEditor | TCsEditor |
|---|---|
| `uCmonacos`, `TCMonacoEditor` | `uCsEditor`, `TCsEditor` |
| `TCMPage` | `TCsPage` |
| `TCMFindDialog` | `TCsFindDialog` |
| Standard actions `TCMEditor…` (category `CX`) | `TCsEditor…` (category `CX TCsEditor`) |
| `CMActiveEditor` | `CsActiveEditor` |
| Preview settings `PreviewFontSize`, `PreviewDelayMs`, `PreviewBackColor…`, etc. | TCPreview's `FontSize`, `DelayMs`, `BackColor…`, etc. (the names without the leading `Preview`) |
| `PreviewWidth`, `SplitterWidth`, `SplitterResizeStyle` | TCPreview's `Width`, and the settings of the TSplitter the application places |
| `OnOpenMarkdown` | TCPreview's `OnOpenMarkdown` |
| `Monaco`, `Monaco.PopupMenu` | `SynEdit`, `ContextMenu` |
| `MonacoPath`, `JapaneseUI` | None (not needed) |

- All other names, arguments and default values are the same.
