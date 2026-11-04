# TCMonacoEditor User Manual

Author: aotan083
Date: 2026-11-05
Version: 1.4

---

## 1. Overview and Classes

A fully offline editor built on WebView2 and Monaco Editor (the editing part of VS Code) that works just by dropping it on a form. Tabs, editor, preview (Markdown and code), find, replace, and printing are all built into a single component. Besides Markdown, it can also edit source code such as Pascal. All settings are made in the Object Inspector; the application does not need to write any code.

```
+---------+---------+-----+------------------------------+
| a.md  × | b.pas × |  +  |                              |
+---------+---------+-----+--+---------------------------+
| # Heading                  ‖  Heading                  |
| Body text…                 ‖  Body text…               |
|                            ‖                           |
|    Monaco editor           ‖  Preview                  |
+----------------------------+---------------------------+
```

- You can drop any number of them on one form. Each one is a self-contained editor.
- Events work even when you do not set them (when not set, the component performs its default behavior; see 6.2).
- It detects the character encoding (UTF-8, UTF-16, Shift_JIS) when reading, and saves with the same encoding.
- It determines the language from the file extension and applies syntax coloring.
- Markdown is displayed in the preview as a formatted document (tables, task lists, Mermaid diagrams). Other languages are displayed as color-highlighted code.
- Printing (saving as PDF) is done through the Edge print dialog.
- When the form is closed, it automatically checks for unsaved documents.
- The standard actions (25 of them) can be assigned to menus and buttons (Chapter 12).
- When you drag a tab outside the window, that tab opens in another window (a second instance of the same EXE is launched). When you drop it onto the editor of another window of the same EXE, it opens there as a new tab (`TabTearOff`; see 9.9).

| Item | Description |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |
| Required at runtime | Microsoft Edge WebView2 Runtime (preinstalled on Windows 11), WebView2Loader.dll (64-bit version), WebView2.ini, monaco folder, preview folder (Chapter 2) |
| Memory | About 60MB per editor (WebView2). WebView2 instances in the same application share a common base, so adding editors does not add as much as the first one did |

### 1.1 Classes and Units

| Class | Unit | Package | Ancestor class | Description |
|---|---|---|---|---|
| `TCMonacoEditor` | `uCmonacos` | cx | `TCustomPanel` | The editor itself, dropped on a form |
| `TCMPage` | `uCmonacos` | cx | `TObject` | One tab (obtained with `ed.Pages[n]`; Chapter 4). TCMonacoEditor creates and destroys it |
| `TCMFindDialog` | `CMonacoFindDlg` | cx | `TComponent` | Find/replace dialog (an invisible component). Drop it only when you want to control it yourself (Chapter 10) |
| `TCMEditorNew` and 24 others | `CMonacoActions` | cx | `TAction` | Standard actions (Chapter 12) |

| Type | Unit | Description |
|---|---|---|
| `TCMEncoding` | `uCmonacos` | Character encoding: `ceUTF8`, `ceUTF8BOM`, `ceUTF16LE`, `ceUTF16BE`, `ceCP932` |
| `TCMFindOption`, `TCMFindOptions` | `uCmonacos` | Search options: `foMatchCase` (case sensitive), `foWholeWord` (whole word), `foLoop` (wrap around from the other end when the end is reached) |
| `TCMTheme` | `uCmonacos` | Color theme: `ctAuto`, `ctLight`, `ctDark` |
| `TCMColorScheme` | `uCmonacos` | Preview color scheme: `csEditor`, `csGitHub` |
| `TCMSelectionColorStyle` | `uCmonacos` | Selection color set: `scStandard`, `scBlue`, `scAmber`, `scPurple`, `scCustom` |
| `TCMSyncScroll` | `uCmonacos` | Scroll synchronization: `ssNone`, `ssEditorToPreview`, `ssBoth` |

| Function | Unit | Description |
|---|---|---|
| `CMActiveEditor(AForm: TCustomForm): TCMonacoEditor` | `uCmonacos` | The editor that last had focus on that form. If none has been focused yet, the first editor. nil if there is none |
| `CMSplitLine(const S, Delims: string; SkipEmpty: Boolean; Quote: Char; Dest: TStrings)` | `uCmonacos` | Splits one line into words (same splitting as `LineWords`; Chapter 13). `Dest` is cleared before the words are added |
| `CMColorToHex(AColor, ADefault: TColor): string` | `uCmonacos` | Converts a color to '#RRGGBB'. Returns `ADefault` for `clDefault` or `clNone` |
| `CMToHankaku(const S: string): string` | `uCmmonacoview` | Converts full-width alphanumerics, symbols, and katakana to half-width |
| `CMToZenkakuKatakana(const S: string): string` | `uCmmonacoview` | Converts hiragana and half-width kana to full-width katakana |
| `CMToZenkakuHiragana(const S: string): string` | `uCmmonacoview` | Converts katakana and half-width kana to full-width hiragana |

- When you drop it on a form, `uCmonacos` is added to uses automatically. This is all the application's uses needs (`uCmonacos` re-exports the commonly used types).
- When you drop it on a form, cx is automatically added to the project's required packages.
- When creating it in code, write the uses entry yourself.

## 2. From Placing It on a Form to Running It

1. From the palette [CX], drop TCMonacoEditor on the form and set `Align = alClient`.
2. Place the files listed in 2.1 in the same folder as the EXE.
3. Run.

- The component prepares WebView2 by itself (creating `GlobalWebView2Loader` and calling `StartWebView2`) when the editor is first displayed. Nothing needs to be written in the application's .lpr.
- WebView2 is prepared only once within the application. It uses the same instance as the other CX WebView2 components such as TCTabBrowser.
- When WebView2.ini is missing, or WebView2 cannot be prepared, `OnError` reports it ("WebView2.ini not found: (file location)" or the WebView2 error message). The editor remains an empty frame.
- WebView2 is not started in the IDE (design time). Only a thin frame and the component name are shown.

### 2.1 Runtime Files

```
MyApp.exe
WebView2.ini                       (always required; 2.2)
WebView2Loader.dll                 (64-bit version)
WebView2Data\                      (WebView2 user data; created automatically)
monaco\
  editor.html
  vs\
    loader.js
    editor\ ...
    base\ ...
    basic-languages\ ...
preview\
  preview.html
  lib\
    marked.umd.js
    purify.min.js
    highlight.min.js
    github.min.css / github-dark.min.css
    github-markdown-light.css / github-markdown-dark.css
    THIRD_PARTY_LICENSES.txt
    mermaid.min.js / mermaid.LICENSE.txt   (Mermaid diagrams; 12.1.0)
    languages\ delphi.min.js / dos.min.js / powershell.min.js
```

- Copy the `min\vs` folder of the npm `monaco-editor` package into `monaco\vs` as a whole. `min-maps` is not needed.
- The licenses of the libraries in the `preview` folder are in `lib\THIRD_PARTY_LICENSES.txt`.
- If the Japanese UI (`editor.main.nls.ja.js`) is missing, set `JapaneseUI := False`.
- Obtain WebView2Loader.dll from the WebView4Delphi repository (https://github.com/salvadordf/WebView4Delphi).

### 2.2 WebView2.ini

Place it in the same folder as the EXE. It is shared by the CX WebView2 components (TCMonacoEditor and TCTabBrowser).

```ini
[WebView2]
LoaderDllPath=
UserDataFolder=
MonacoFolder=
PreviewFolder=

[CX]
Language=
```

| Key | Description | When empty or omitted |
|---|---|---|
| `LoaderDllPath` | The WebView2Loader.dll file | WebView2Loader.dll in the EXE folder |
| `UserDataFolder` | WebView2 user data folder | EXE folder\WebView2Data |
| `MonacoFolder` | Folder containing `editor.html` and `vs` | EXE folder\monaco |
| `PreviewFolder` | Folder containing `preview.html` and `lib` | EXE folder\preview |
| `Language` (`[CX]`) | Screen language, `ja` or `en` (2.4) | Windows display language |

- The file must always be present. All key values may be empty (in that case, the locations used for empty values apply).
- Relative paths are counted from the EXE folder. Absolute paths can also be written.
- It is read only once, the first time it is used after startup. Rewriting it while the application is running has no effect until the next startup.
- Convenient when several applications share a single `monaco` and `preview` (15.7). Keep `UserDataFolder` separate for each application (using the same folder from several applications at the same time can cause WebView2 startup to fail).

### 2.3 How the Locations of monaco and preview Are Determined

For each editor, the first one that is determined, in the order below, is used.

| Order | How it is determined |
|---|---|
| 1 | If the `MonacoPath` / `PreviewPath` property is not empty, that location (relative paths are counted from the EXE folder) |
| 2 | If `MonacoFolder` / `PreviewFolder` in WebView2.ini is not empty, that location |
| 3 | `monaco` / `preview` in the EXE folder |

- If it is not found, `OnError` is raised ("editor.html not found: (location)", "preview.html not found: (location)"). The location shown is the absolute path determined above (with `..` removed).

### 2.4 Screen Language (Japanese/English)

The text this component shows on screen (menus, buttons, messages, etc.) appears in Japanese or English. There is one language for all cx components; it is not set per component.

Write the following in WebView2.ini (2.2).

```ini
[CX]
Language=en
```

| Order | How it is decided |
|---|---|
| 1 | If `Language` in `[CX]` is `ja` or `en`, that language (case-insensitive) |
| 2 | Otherwise (no `[CX]`, empty, or another value), the Windows display language: `ja` if it is Japanese, `en` otherwise |

- It is decided only once, the first time text is shown. Rewriting it while running has no effect until the next startup.
- The screen text quoted in this manual (such as "Untitled") is the English text. With `ja`, it is shown in Japanese (such as 「無題」).
- Monaco's built-in UI is Japanese only when `JapaneseUI = True` and the language is `ja`. Otherwise it is English.
- The preview (diagram buttons, error messages, etc.) is also shown in the same language.
- The open/save file dialogs and the buttons of confirmation messages are shown in the language of Windows and the LCL.
- The `Caption` and `Hint` of standard actions (chapter 12) placed on a form in the IDE are set in the display language of the Windows the IDE runs on, and are saved to the .lfm as they are.

## 3. Concepts

In this manual, an editor dropped on a form is written as `ed`.

**1. The visible tab is `ed`; background tabs are `ed.Pages[n]`**

| Notation | Target |
|---|---|
| `ed.…` | The visible tab (the tab at `ActiveIndex`) and the editor as a whole |
| `ed.ActiveIndex := n` | Switches the visible tab (the screen switches too). Numbers start at 0 |
| `ed.Pages[n].…` | Touches the contents and file of tab n without switching the screen. n may also be the visible tab (same result as `ed.…`) |

- Everything in `ed.Pages[n]` also exists in `ed` with the same name and the same behavior (Chapter 4).
- Only the operations on the collection of tabs (Chapter 5) and the on-screen operations (6.1) exist only in `ed`. Selection, cursor, editing, find, and printing exist only for the visible tab. To perform them on a background tab, switch to it first with `ActiveIndex`.
- The names are the same as in TMemo and TSynEdit (`Text`, `SelText`, `SelLength`, `Modified`, `LoadFromFile`, and so on).

**2. One tab = one page**

- A page = one tab + one body text + a file name. An untitled document (not yet saved) is also one page.
- The same file is never opened in two tabs.
- Tab numbers are 0, 1, 2… from the left.

**3. There is always at least one tab**

- When the last tab is closed (`ed.Close`, `ed.CloseAll`, or the tab's [×]), one empty untitled tab is created.
- When `MultiDocument = False`, there is always exactly one tab (not displayed). Closing it leaves an untitled document with empty contents (9.1).

**4. The tab display is determined automatically from the page state**

| Tab display | How it is determined |
|---|---|
| Title (`Caption`) | Only the name part of the file name (`C:\docs\a.md` → `a.md`). "Untitled" for an untitled document |
| Modified mark (` *`) | Added when `Modified` is `True` (example: `a.md *`). Not included in `Caption` |
| Icon | Determined from the extension (an untitled document gets the text icon; 9.3) |
| Hint | The full path of the file name |
| Tab that appears raised | The tab at `ActiveIndex` |

**5. How things change with each operation**

| Operation | Body text | File name | Tab | ` *` | Disk |
|---|---|---|---|---|---|
| `ed.NewPage` | Empty | Empty | One more ("Untitled"). Becomes the visible tab | None | Does nothing |
| `ed.OpenFile(name)` | File contents | That name | One more. Becomes the visible tab (if the same file is already open, it just switches to that tab) | None | Reads |
| `ed.LoadFromFile(name)` | Replaced with the file contents (changes are discarded without asking) | Changes to that name | No increase | None | Reads |
| `ed.Clear` | Empty | Empty (becomes untitled) | No increase | None | Does nothing |
| `ed.Text := s` | Replaced (the Undo history is cleared). Does nothing if the body text is the same as now | Unchanged | Unchanged | Added (not added if the body text is the same as now) | Does nothing |
| `ed.SelText := s` | The selected part is replaced (one Undo restores it) | Unchanged | Unchanged | Added | Does nothing |
| User input | Changes | Unchanged | Unchanged | Added | Does nothing |
| `ed.Save` | Unchanged | Unchanged (for an untitled document, the name that was asked for) | Unchanged (for an untitled document, that name) | Removed | Writes |
| `ed.SaveAs(name)` | Unchanged | That name | Title and icon change | Removed | Writes (the original file remains) |
| `ed.Close` | Gone | Gone | Gone (the neighboring tab becomes the visible tab. If it was the last one, an empty untitled tab is created) | ― | Does nothing |
| `ed.ActiveIndex := n` | Tab n is displayed | ― | Tab n becomes the visible tab | ― | Does nothing |

The same-named operations on `ed.Pages[n].…` work the same way, except that the target is tab n (the screen is not switched).

## 4. Tab Contents and Files (ed, ed.Pages[n])

| Name | Type / Arguments | Read/Write | Description |
|---|---|---|---|
| `Text` | `string` | Read/Write | Body text. Writing replaces only the contents (the file name stays as is; the Undo history is cleared; nothing is written to a file). Writing adds ` *`, and ` *` does not disappear even if you revert with Undo (it disappears only when saved). Writing the same body text as now does nothing (` *` is not added). The value read reflects user input with a delay of about 0.1 second (Chapter 14) |
| `Caption` | `string` | Read | Tab title. Only the name part of the file name. "Untitled" for an untitled document. Does not include ` *` |
| `FileName` | `string` | Read | Full path of the file. '' for an untitled document. Use `SaveAs` to change the name |
| `Modified` | `Boolean` | Read | Whether there are unsaved changes (the tab's ` *`) |
| `Encoding` | `TCMEncoding` | Read/Write | Character encoding. Determined when loaded and used when saving |
| `Language` | `string` | Read/Write | Syntax coloring language ('pascal', 'markdown', etc.; 9.2). Writing '' gives `DefaultLanguage` |
| `LineCount` | `Integer` | Read | Number of lines. Counted from `Text`. 1 for an empty document. When the text ends with a line break, the empty line after it is also counted as one line (same as Monaco's line numbers). #13#10, #13, and #10 each count as one line break |
| `LoadFromFile` | `const AFileName: string`, returns `Boolean` | ― | Discards the contents and loads the file. Changes are discarded without asking. The number of tabs does not increase. Returns `True` if loaded. If the file does not exist or cannot be read, nothing is changed and it returns `False` (`OnError`). If the file is open in another tab, it is not loaded and returns `False` (`OnError`; the display is not switched either). If it is the same file as the one open in this tab, it is reloaded |
| `Save` | returns `Boolean` | ― | Overwrite save. For an untitled document, it asks for a name (`OnNeedFileName`; when not set, a save dialog. It asks without switching even for a background tab). If the name given is a file open in another tab, it does not save. Returns `True` if saved. Returns `False` on cancel or failure, and ` *` is not removed. Failures are reported through `OnError` |
| `SaveAs` | `const AFileName: string = ''`, returns `Boolean` | ― | Saves under another name. If the name is omitted, it asks with a save dialog (shown without switching even for a background tab). After saving, the tab's title and icon also become that name. The original file remains on disk. If the name is a file open in another tab, it does not save and returns `False` (`OnError`). When a name is specified, an existing file of the same name is overwritten without asking (the dialog asks "Overwrite?") |
| `Clear` | ― | ― | Empties the contents, clears the file name, and makes it untitled. Changes are discarded without asking. The tab remains. The language becomes `DefaultLanguage`. Does nothing to files |
| `Close` | `Force: Boolean = False`, returns `Boolean` | ― | Closes. Asks if there are changes (9.5). With `Force = True`, it discards without asking. Returns `True` if closed, `False` if cancelled. When the visible tab is closed, the neighboring tab becomes the visible tab. If it was the last one, an empty untitled tab remains. With `MultiDocument = False`, it empties the contents instead of closing (9.1). The file itself is not deleted |

**Rules for `Pages[n]`**

- Pages are created and managed by the editor. The application must not call `Create` or `Free` on them.
- A page you have obtained (example: `P := ed.Pages[2]`) keeps pointing to the same tab even if the tabs are reordered.
- When a closed page is used, the values read are empty (`Caption`, `FileName`, and `Text` are '', `Modified` is `False`, `LineCount` is 0), and operations do nothing (those returning `Boolean` return `False`). It does not crash.
- If the `Pages[n]` index is out of range, an exception (`EListError`) is raised.
- When `MultiDocument = False`, there is always exactly one page (`Pages[0]`).

## 5. The Collection of Tabs (ed)

| Name | Type / Arguments | Read/Write | Description |
|---|---|---|---|
| `OpenFile` | `const AFileName: string = ''`, returns `Integer` | ― | If the name is omitted, it shows the open dialog (`OpenDialog`; the built-in one when not set) and opens the selected file. On cancel, it does nothing and returns -1. When a name is specified, it loads the file in a new tab and makes it the visible tab. It detects the character encoding and determines the language from the extension. If the same file is already open, it just switches to that tab (does not reload). Even if the only tab is the untitled one present right after startup, it does not load into that tab. The return value is the tab number. For an unreadable file, an exception is raised (no tab is left behind). For `MultiDocument = False`, see 9.1 |
| `NewPage` | returns `Integer` | ― | Adds an empty untitled tab on the right and makes it the visible tab. The return value is the tab number. No file is read or created. For `MultiDocument = False`, see 9.1 |
| `SaveAll` | ― | ― | Saves every tab that has changes (for an untitled one, it switches to that tab and then asks for a name) |
| `CloseAll` | `Force: Boolean = False`, returns `Boolean` | ― | Closes everything. Asks if there are changes. With `Force = True`, it discards without asking. When all are closed, one empty untitled tab remains. If cancelled midway, it returns `False` (the rest are left as they are) |
| `CanCloseAll` | returns `Boolean` | ― | The confirmation used when closing the form. It checks the unsaved tabs but does not close them. Returns `False` if cancelled |
| `FindPage` | `const AFileName: string`, returns `Integer` | ― | The number of the tab that has that file open. -1 if there is none. Case-insensitive. Does not read the file |
| `MovePage` | `AFromIndex, AToIndex: Integer` | ― | Changes the order of the tabs. The contents do not change |
| `ActiveIndex` | `Integer` | Read/Write | Number of the visible tab (from 0). Writing switches to that tab. An out-of-range or identical number does nothing |
| `PageCount` | `Integer` | Read | Number of tabs (always 1 or more) |
| `Pages[AIndex]` | `TCMPage` | Read | Tab n (Chapter 4). An exception is raised if out of range |

## 6. On-Screen Operations and Events (ed)

### 6.1 Properties and Methods

All of these target the visible tab.

| Name | Type / Arguments | Read/Write | Description |
|---|---|---|---|
| `SelText` | `string` | Read/Write | Reading returns the selected string ('' if nothing is selected). Writing replaces the selection with that string. If nothing is selected, it is inserted at the cursor position. Writing '' deletes the selection. Line breaks are treated as line breaks whether you pass #13, #10, or #13#10, and are inserted converted to the document's line break code. One Undo restores it. After replacing, the cursor is placed after the replaced string (the selection is cleared). When `ReadOnly`, writing does nothing |
| `SelStart` | `Integer` | Read | Start position of the selection (the cursor position if nothing is selected). 0-based from the start of the document, in UTF-16 units (emoji and similar count as 2). A line break counts as the number of characters of the document's line break code (CRLF is 2, LF is 1). To select a range, use `SetSelection` |
| `SelLength` | `Integer` | Read | Number of characters selected (counted the same way as `SelStart`). 0 means nothing is selected |
| `CanUndo` | `Boolean` | Read | Whether Undo is possible |
| `CanRedo` | `Boolean` | Read | Whether Redo is possible |
| `GetCursorPos` | `out ALine, AColumn: Integer` | ― | Cursor position. Line and column start at 1. The column is in UTF-16 units |
| `SetCursorPos` | `ALine, AColumn: Integer` | ― | Moves the cursor |
| `SetSelection` | `AStartLine, AStartCol, AEndLine, AEndCol: Integer` | ― | Selects a range |
| `LineText` | `string` | Read | String of the cursor line (without the line break). Chapter 13 |
| `LineWords` | `TStrings` | Read | List of the cursor line split into words (counted from 0). Do not `Free` it. Chapter 13 |
| `LineDelimiters` | `string` | Read/Write | Delimiter characters for `LineWords`. Set in code. Chapter 13 |
| `LineSkipEmpty` | `Boolean` | Read/Write | Whether to exclude empty words from `LineWords`. Set in code. Chapter 13 |
| `LineQuoteChar` | `Char` | Read/Write | Quote character for `LineWords`. Set in code. Chapter 13 |
| `Undo` | ― | ― | Undo |
| `Redo` | ― | ― | Redo |
| `Cut` | ― | ― | Cut (to the clipboard). Does nothing when `ReadOnly` |
| `Copy` | ― | ― | Copy (to the clipboard) |
| `Paste` | ― | ― | Paste (from the clipboard). Does nothing when `ReadOnly` |
| `SelectAll` | ― | ― | Selects all |
| `DeleteToEnd` | ― | ― | Deletes from the cursor position to the end of the document. Any selection is ignored. One Undo restores it. Does nothing when `ReadOnly` |
| `DeleteToStart` | ― | ― | Deletes from the cursor position to the start of the document. The rules are the same as `DeleteToEnd` |
| `DuplicateLine` | ― | ― | Duplicates the cursor line and moves down to it (same as `Shift+F10`; if several lines are selected, those lines are duplicated together). One Undo restores it. Does nothing when `ReadOnly` |
| `ToggleOverwrite` | ― | ― | Toggles between insert and overwrite (same as the `Insert` key) |
| `Find` | `const S: string; AOptions: TCMFindOptions; AForward: Boolean = True` | ― | Searches and selects the match. The result is reported by `OnFindDone` |
| `FindNext` | ― | ― | Searches forward using the previous search term (`F5`). If there is no search term, it opens the find dialog |
| `FindPrev` | ― | ― | Searches backward using the previous search term (`Shift+F5`) |
| `Replace` | `const S, R: string; AOptions: TCMFindOptions` | ― | If the selection is S, replaces it with R and searches for the next one. Does nothing when `ReadOnly` |
| `ReplaceAll` | `const S, R: string; AOptions: TCMFindOptions` | ― | Replaces everything. The result (the count) is reported by `OnReplaceAllDone`. One Undo restores it. Does nothing when `ReadOnly` |
| `ShowFindDialog` | `const InitialText: string = ''` | ― | Opens the find/replace dialog (same as `Ctrl+F`; Chapter 10) |
| `CanPrint` | returns `Boolean` | ― | Whether printing is possible (`True` if there is a tab) |
| `Print` | ― | ― | Opens the print dialog (11.6). If the preview is not shown, it is shown only during printing |
| `SetFocus` | ― | ― | Puts the cursor in the editor so that it can accept input. The move happens after the current processing (a button click, `OnKeyDown`, `OnReady`, etc.) finishes (it can be called from anywhere). Does nothing for an editor that is invisible or disabled |
| `SearchText` | `string` | Read/Write | The previous search term |
| `ReplaceText` | `string` | Read/Write | The previous replacement term |
| `SearchOptions` | `TCMFindOptions` | Read/Write | The previous search options |
| `TopLine` | `Double` | Read | The first line being displayed (the fractional part is the position within the line) |
| `Ready` | `Boolean` | Read | Whether Monaco is ready |
| `Monaco` | `TCMMonacoView` | Read | The inner editor component (for advanced users, e.g., adding items to `Monaco.PopupMenu`; 15.6) |
| `Preview` | `TCMMarkdownPreview` | Read | The inner preview component (for advanced users) |

### 6.2 Events

`Sender` is always that editor (TCMonacoEditor). The handling of one event can be shared by several editors (distinguish them with `Sender as TCMonacoEditor`).

| Name | Arguments | Description |
|---|---|---|
| `OnReady` | `Sender: TObject` | Monaco is ready. For an editor placed somewhere not visible (such as an unselected sheet of a `TPageControl`), preparation starts when it is first displayed (until then, the body text and so on are held inside the component) |
| `OnChange` | `Sender: TObject` | The user edited the body text of the visible tab (about 0.1 second after typing stops) |
| `OnCursorChange` | `Sender: TObject; Line, Column: Integer` | The cursor moved |
| `OnModeChange` | `Sender: TObject; IsOverwrite: Boolean` | Switched between insert and overwrite |
| `OnModifiedChange` | `Sender: TObject` | The ` *` of the visible tab appeared or disappeared |
| `OnActiveChange` | `Sender: TObject` | The visible tab changed |
| `OnDocListChange` | `Sender: TObject` | Tabs were added, removed, or reordered (also fires once when the last tab is closed and an empty untitled tab is created) |
| `OnDocumentChange` | `Sender: TObject; Index: Integer` | A tab's name, language, or ` *` changed |
| `OnSave` | `Sender: TObject; const AFileName: string` | Saved |
| `OnQueryClose` | `Sender: TObject; Index: Integer; var CanClose: Boolean` | Before closing or replacing a tab with unsaved changes (9.5) |
| `OnNeedFileName` | `Sender: TObject; var AFileName: string; var Cancel: Boolean` | Decides the name when saving an untitled document |
| `OnFileDrop` | `Sender: TObject; Files: TStrings; var Handled: Boolean` | Files were dropped. `Handled := True` stops the standard open handling |
| `OnOpenMarkdown` | `Sender: TObject; const AFileName: string` | A link to a `.md` file in the preview was clicked |
| `OnToggleMaximize` | `Sender: TObject` | `F12` was pressed (the application implements maximizing) |
| `OnFontSizeChange` | `Sender: TObject` | The font size changed with `Ctrl+Wheel` |
| `OnLineNumbersChange` | `Sender: TObject` | Line numbers were toggled with `F11` |
| `OnFindDone` | `Sender: TObject; Found: Boolean` | Result of a search (fires both for searches from the dialog and for `Find` and the like) |
| `OnReplaceAllDone` | `Sender: TObject; Count: Integer` | Result of Replace All |
| `OnPopup` | `Sender: TObject` | Just before the right-click menu is shown |
| `OnGetTabImageIndex` | `Sender: TObject; Index: Integer; const FileName: string; var ImageIndex: Integer` | When deciding a tab's icon (only when `TabImages` is set; 9.3) |
| `OnTabDragOut` | `Sender: TObject; Index, X, Y: Integer; var TearOff: Boolean` | A tab was dropped outside the application's window (9.9). `Index` is the number of that tab, and `X` and `Y` are the screen position where it was dropped. `TearOff := False` cancels the component's detach/attach handling |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A shortcut-type key was pressed (9.6). `Key := 0` stops the built-in behavior |
| `OnError` | `Sender: TObject; const AMessage: string` | All errors from the editor and the preview |

**Default behavior when not set**

| Name | When not set |
|---|---|
| `OnError` | Shows the message. The same message is shown only once (so that the same error does not appear many times at startup when several editors are dropped) |
| `OnNeedFileName` | Shows the `SaveDialog` (the built-in one when not set) |
| `OnQueryClose` | Follows `ConfirmOnFormClose` (9.5) |
| `OnOpenMarkdown` | Opens it in that editor |
| `OnFileDrop` | Performs the standard open handling |
| `OnToggleMaximize` | Does nothing |
| `OnGetTabImageIndex` | Uses item 0 of `TabImages` |
| `OnTabDragOut` | Follows `TabTearOff` (9.9) |
| Others | Does nothing (notification-only events) |

## 7. Settings (Object Inspector)

| Name | Type | Default | Description |
|---|---|---|---|
| `MultiDocument` | `Boolean` | `True` | `True` = with tabs (multiple files) / `False` = a single file only (9.1). Can be changed only at design time (and right after creating it in code). Changes at runtime are ignored |
| `ConfirmOnFormClose` | `Boolean` | `True` | When closing an unsaved document and `OnQueryClose` is not set: `True` = confirmation dialog / `False` = discard without confirming (9.5) |
| `TabTearOff` | `Boolean` | `True` | `True` = dropping a tab outside the window opens it in another window. Dropping it onto the editor of another window of the same EXE opens it there as a new tab. Tabs dropped from other windows are also accepted (9.9) |
| `OpenDialog` | `TOpenDialog` | nil | The dialog used for opening. The built-in one when not set (table below) |
| `SaveDialog` | `TSaveDialog` | nil | The dialog used for saving. The built-in one when not set |
| `FindDialog` | `TCMFindDialog` | nil | The find/replace dialog. The built-in shared dialog when not set (Chapter 10) |
| `TabFlat` | `Boolean` | `True` | `True` = rectangular / `False` = trapezoid |
| `TabSeparator` | `Boolean` | `False` | Whether to put a thin vertical line between unselected tabs. Effective only when `TabFlat = True` |
| `TabIcons` | `Boolean` | `True` | Whether to show icons on tabs (9.3) |
| `TabImages` | `TImageList` | nil | An image list of icons you prepared yourself. When not set, Windows icons are shown automatically (9.3) |
| `WordWrap` | `Boolean` | `True` | Word wrap |
| `LineNumbers` | `Boolean` | `False` | Line numbers. Also toggled with `F11` |
| `FontSize` | `Integer` | 14 | Font size (6 to 72) |
| `TabSize` | `Integer` | 4 | Tab width (1 to 16) |
| `Folding` | `Boolean` | `True` | Code folding |
| `MatchBrackets` | `Boolean` | `True` | Shows matching brackets |
| `OccurrencesHighlight` | `Boolean` | `True` | Highlights words identical to the word at the cursor position |
| `Minimap` | `Boolean` | `False` | Minimap. Also toggled with `Ctrl+Shift+M` |
| `Theme` | `TCMTheme` | `ctAuto` | Color theme. `ctAuto` (follows the OS color scheme; changes immediately when the OS is switched) / `ctLight` (fixed to the light scheme) / `ctDark` (fixed to the dark scheme). The preview follows as well |
| `ReadOnly` | `Boolean` | `False` | Read-only |
| `JapaneseUI` | `Boolean` | `True` | Monaco's Japanese UI. It is Japanese only when this is `True` and the screen language is `ja` (2.4). When `False`, it is always English (set to `False` if `editor.main.nls.ja.js` is missing) |
| `DefaultLanguage` | `string` | 'pascal' | Language for new documents and for documents whose extension is unknown |
| `AutoLanguage` | `Boolean` | `True` | Determines the language from the file name extension |
| `OpenDroppedFiles` | `Boolean` | `True` | Opens dropped files |
| `QuotePrefix` | `string` | '> ' | The symbol at the start of each line for "Copy with quote" |
| `HitColorLight` | `TColor` | #FFEE58 | Background color of the search hit (the selection while the editor does not have focus) (light scheme) |
| `HitColorDark` | `TColor` | #7D6608 | Same (dark scheme) |
| `CursorLineColorLight` | `TColor` | #EAF2FF | Background color of the cursor line (light scheme) |
| `CursorLineColorDark` | `TColor` | #2C313C | Same (dark scheme) |
| `SelectionColorStyle` | `TCMSelectionColorStyle` | `scStandard` | Selection color set. `scStandard` (dark #264F78 / light #ADD6FF; same as VS Code) / `scBlue` (dark #0E5A9E / light #7FB6FF) / `scAmber` (dark #6B4E00 / light #FFD54F) / `scPurple` (dark #5A2D82 / light #C5A3FF) / `scCustom` (the two colors below). Choosing anything other than `scCustom` changes the two colors below to that set's colors |
| `SelectionColorLight` | `TColor` | #ADD6FF | Background color of the selection (light scheme; while focused). Writing it sets `SelectionColorStyle` to `scCustom`. The color of the text inside the selection does not change |
| `SelectionColorDark` | `TColor` | #264F78 | Same (dark scheme). Writing it sets `SelectionColorStyle` to `scCustom` |
| `MonacoPath` | `string` | '' | Location of `editor.html` and `vs` (2.3) |
| `ShowPreview` | `Boolean` | `False` | Whether to show the preview (11.2). Also toggled with `Ctrl+Shift+V` |
| `PreviewWidth` | `Integer` | 500 | Width of the preview. A width changed at the splitter is also stored here |
| `SplitterResizeStyle` | `TResizeStyle` | `rsLine` | Display while dragging the splitter (same as `TSplitter.ResizeStyle`) |
| `SplitterWidth` | `Integer` | 5 | Width of the splitter |
| `PreviewFontSize` | `Integer` | 16 | Font size of the preview (8 to 48) |
| `ColorScheme` | `TCMColorScheme` | `csEditor` | Preview color scheme. `csEditor` (same colors as the editor) / `csGitHub` (GitHub style) |
| `PreviewBackColorLight` | `TColor` | #FFFFFE | Preview background color when `csEditor` (light scheme) |
| `PreviewBackColorDark` | `TColor` | #1E1E1E | Same (dark scheme) |
| `PreviewTextColorLight` | `TColor` | #000000 | Preview text color (light scheme) |
| `PreviewTextColorDark` | `TColor` | #D4D4D4 | Same (dark scheme) |
| `PreviewLinkColorLight` | `TColor` | #006AB1 | Preview link color (light scheme) |
| `PreviewLinkColorDark` | `TColor` | #3794FF | Same (dark scheme) |
| `BreakOnNewline` | `Boolean` | `False` | Whether a single line break is displayed as a line break |
| `AllowRemoteImages` | `Boolean` | `False` | Whether to display images from the Internet (http) (11.4) |
| `SyncScroll` | `TCMSyncScroll` | `ssBoth` | Whether to synchronize the scrolling of the editor and the preview (11.5) |
| `PreviewDelayMs` | `Integer` | 300 | Time from editing until the preview is updated (milliseconds) |
| `PreviewPath` | `string` | '' | Location of `preview.html` (2.3) |
| `Align` | `TAlign` | | Placement within the parent |
| `Anchors` | `TAnchors` | | Which edges it follows when the parent's size changes |
| `BorderSpacing` | `TControlBorderSpacing` | | Surrounding margins |
| `Constraints` | `TSizeConstraints` | | Upper and lower limits of the size |
| `Enabled` | `Boolean` | | Whether it is usable |
| `Visible` | `Boolean` | | Whether it is shown |
| `TabOrder` | `TTabOrder` | | Order of movement with the Tab key |
| `TabStop` | `Boolean` | | Whether the Tab key stops here |

- `LineDelimiters`, `LineSkipEmpty`, and `LineQuoteChar` do not appear in the Object Inspector. Set them in code (Chapter 13).

**Color settings (the 12 whose names end in `Color`)**

- In the Object Inspector, choose from the color list or from the "..." color dialog.
- When you choose a system color (such as `clWindow`), it becomes that color as of the time you set it. It does not change even if the OS color scheme is switched.
- When you choose `clDefault` or `clNone`, it becomes the default color.

**Built-in dialogs**

| Item | Description |
|---|---|
| Filter | Markdown (*.md; *.markdown) / Text (*.txt) / All files (*.*) |
| Default extension for saving | Determined from that tab's language (markdown→md, plaintext→txt, pascal→pas, html→html, css→css, javascript→js, json→json, xml→xml, sql→sql, ini→ini, bat→bat, python→py, cpp→cpp, csharp→cs, typescript→ts, java→java, shell→sh, powershell→ps1, yaml→yaml, php→php, go→go) |
| Initial folder | The folder of that tab. For an untitled document, the previously used folder |

**Not provided**

The contents are WebView2 (a separate process), and key input, mouse, and focus are handled inside WebView2, so the following are not exposed.

| Kind | What is not exposed, and why |
|---|---|
| Keys | `OnKeyUp`, `OnKeyPress`, `OnUTF8KeyPress` (handled inside the editor, and no notification arrives). Only `OnKeyDown` is available (9.6) |
| Focus | `OnEnter`, `OnExit`, `Focused` (focus is inside WebView2). To move focus, use `SetFocus` |
| Mouse | `OnClick`, `OnDblClick`, `OnMouseDown`, etc. (handled inside WebView2, and no notification arrives) |
| Appearance | `Color`, `Font`, `BevelOuter`, etc. (decided by `Theme`, `FontSize`, and so on) |
| Right-click menu | `PopupMenu` (the built-in menu is used. To add items, see 15.6) |
| Strings | `Caption` and `Text` as a panel caption (`Text` and `Caption` are the body text and title of the visible tab) |

## 8. Keys

### 8.1 Built-in Shortcuts

WebView2's default behaviors (reload, developer tools, printing, etc.) are disabled. Keys are received only by the editor that has focus. All of the following shortcuts can be replaced with `OnKeyDown` (9.6).

| Key | Action |
|---|---|
| `Ctrl+S` | Saves the visible tab. For an untitled document, `OnNeedFileName` (a save dialog when not set) |
| `Ctrl+F` | Opens the find/replace dialog. If a range within one line is selected, it becomes the initial search term |
| `F5` / `Shift+F5` | Searches next / previous using the previous search term. If there is no search term, opens the dialog |
| `Ctrl+Shift+V` | Toggles the preview on and off (11.2). Works on tabs of every language |
| `Ctrl+Shift+P` | Does nothing (disables WebView2's "Print using system dialog"). If the form has the same shortcut, that one is executed |
| `Ctrl+P` | Prints (same as `Print`; 11.6). Even if the form has the same shortcut (such as the standard print action), the built-in one takes precedence (the behavior is the same) |
| `Ctrl+Shift+M` | Toggles the minimap on and off (`Minimap`) |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Switches to the next tab / previous tab (wraps around to the other end). Does nothing when `MultiDocument = False` |
| `Shift+F10` | Duplicates the cursor line and moves down (same as `DuplicateLine`) |
| `F11` | Toggles line numbers on and off |
| `F12` | Raises `OnToggleMaximize` |
| `Insert` | Toggles between insert and overwrite. In overwrite mode, the cursor is a block |
| `Ctrl+Wheel` | Changes the font size |
| `Ctrl+A` | Selects all |

### 8.2 Shortcuts Built into Monaco

The result of checking the main shortcuts that Monaco has from the start. Those not listed here can also be found and run from the command palette (`F1`).

| Key | Action | Result |
|---|---|---|
| `F1` | Command palette (lists and searches all functions so you can run them) | Works |
| `Alt+↑` / `Alt+↓` | Moves the line up or down | Works |
| `Shift+Alt+↑` / `Shift+Alt+↓` | Duplicates the line upward or downward | Works |
| `Ctrl+]` / `Ctrl+[` | Indent / outdent | Works |
| `Ctrl+/` | Toggles a line comment. Uses the language's comment syntax (`//` for pascal, `<!-- -->` for markdown) | Works |
| `Ctrl+D` | Adds the same word one after another to the selection (multi-cursor). When you type, all selected places are rewritten at the same time | Works |
| `Shift+Alt+Drag` | Selects a rectangular range | Works |
| `Ctrl+G` | Jumps to a specified line | Works |
| `Ctrl+Shift+[` / `Ctrl+Shift+]` | Fold / unfold | Works |
| `Ctrl+Enter` | Inserts an empty line below | Works |
| `Ctrl+Shift+Enter` | Inserts an empty line above (in practice it is inserted below) | Does not work |
| `Ctrl+Shift+K` | Deletes the line | Does not work |

- Multi-cursor returns to a single cursor with `Esc`.

## 9. Behavior

### 9.1 MultiDocument

A single `MultiDocument` setting switches both the tab display and the behavior when opening. When you drop several on one form and handle one file in each, set `MultiDocument = False` on each editor.

| | `True` (with tabs, default) | `False` (single file only) |
|---|---|---|
| Tab display | Shown | Not shown (the editor is correspondingly larger) |
| Opening a file | Opens in a new tab | Keeps the tab and replaces the contents (asks for confirmation if unsaved) |
| New | Adds a tab | Empties the contents (asks for confirmation if unsaved) |
| Closing (`Close`, `CloseAll`) | Closes the tab (if it is the last one, an empty untitled tab remains) | Empties the contents (asks for confirmation if unsaved). The number of tabs does not change, so `OnDocListChange` and `OnActiveChange` do not fire |
| Dropping files | Opens in new tabs | Replaces the contents (first file only) |

- When tabs are hidden, the file name and ` *` are not displayed. Unsaved content is handled by the confirmation in 9.5.

**Tab operations (`MultiDocument = True`)**

| Operation | Behavior |
|---|---|
| [+] | Adds a new document |
| [×], middle-click | Closes. If unsaved, the confirmation in 9.5 is performed |
| Drag | Reorders the tabs. The order of the editor's documents is swapped as well |
| Drag outside the window | If `TabTearOff = True` (default), opens that tab in another window. Dropping it onto the editor of another window of the same EXE opens it there as a new tab (9.9). Dropping it onto another editor within the same window or the same application does nothing (the tab does not move) |
| Hover the mouse | A full-path hint is shown |

- Each document keeps its own file name, character encoding, BOM, ` *`, Undo/Redo history, cursor position, scroll position, and language. They are restored when you switch away and back.
- Right after startup, there is one untitled document. `OpenFile` does not use this untitled document; it always opens in a new tab.
- Find and replace target only the visible tab.

### 9.2 Files and Languages

- When loading, the character encoding is detected. If there is a BOM, the BOM is followed; if not, it checks whether the data is valid as UTF-8, and if not valid, treats it as CP932 (Shift_JIS).
- When saving, the character encoding and BOM from when it was loaded are used.
- If there are characters that cannot be represented in CP932, an exception occurs when saving. Change `Encoding` to UTF-8 and then save.
- The line break code (CRLF / LF) from when it was loaded is used. A new document with no line breaks uses CRLF.
- The language is determined from the extension at `LoadFromFile` and `OpenFile`. The language is also switched when the extension changes after a Save As.

| Extension | Language |
|---|---|
| .pas .pp .lpr .inc .dpr .lpk | pascal |
| .md .markdown | markdown |
| .txt | plaintext |
| .html .htm / .css / .js / .json / .xml | html / css / javascript / json / xml |
| .sql / .ini .cfg / .bat .cmd / .py / .c .h .cpp .hpp | sql / ini / bat / python / cpp |
| .cs | csharp |
| .ts .tsx | typescript |
| .java | java |
| .sh .bash | shell |
| .ps1 .psm1 .psd1 | powershell |
| .yml .yaml | yaml |
| .php | php |
| .go | go |
| Anything else | `DefaultLanguage` (default is pascal) |

- Pascal syntax coloring centers on keywords, comments, strings, and numbers, and does not distinguish Lazarus-specific syntax (it is Monaco's definition as is).

### 9.3 Tab Icons

For each file type, the same Windows icon as in Explorer is automatically shown at the left end of the tab. It appears with the defaults (`TabIcons = True`, no `TabImages`).

| Situation | Icon shown |
|---|---|
| A tab with a file opened | The icon for that file's extension |
| An untitled tab | The text icon (the .txt icon) |
| Extension changed after Save As | The icon for the new extension |

- It follows file associations (example: if .md is associated with VS Code, the VS Code icon).
- To remove the icons, set `TabIcons = False`.

**Using icons you prepared yourself**

1. Drop a `TImageList` on the form and add the icons.
2. Select that image list in `TabImages`.
3. In `OnGetTabImageIndex`, decide the index to use for each tab (`ImageIndex := -1` for no icon). When not set, index 0 is used for all tabs (15.9).

### 9.4 Color Scheme

- With `Theme = ctAuto` (default), it follows the OS dark/light setting. Even if the OS is switched while running, the editor, preview, tabs, splitter, and background are repainted immediately.
- With `ctLight` or `ctDark`, the scheme is fixed regardless of the OS.
- The tabs, splitter, and background use colors close to those of the Windows 11 File Explorer. The visible tab uses the same color as the editor background, so it looks connected to the body text.

| Part | Dark | Light |
|---|---|---|
| Tab strip and unselected tabs | #2B2B2B | #F0F0F0 |
| Tab under the mouse | #383838 | #E5E5E5 |
| Visible tab | #1E1E1E | #FFFFFF |
| Text of the visible tab | #FFFFFF | #000000 |
| Text of unselected tabs | #C5C5C5 | #5C5C5C |
| [×] and scroll arrows | #C5C5C5 | #5C5C5C |
| Separator lines and tab borders | #3A3A3A | #D9D9D9 |
| Splitter | #2B2B2B | #E5E5E5 |
| Background (briefly visible right after startup) | #1E1E1E | #FFFFFF |

- Search hits are displayed with `HitColorLight` / `HitColorDark` while the editor does not have focus (while you are working in the find dialog). When you click the editor, it returns to the normal selection color.
- The cursor line is highlighted only by background color (no border).

### 9.5 Confirmation for Unsaved Documents

When a document whose `Modified` is `True` is closed or replaced, `OnQueryClose` is raised.

**When it is raised**

- When a tab is closed ([×], middle-click, `ed.Close`, `ed.Pages[n].Close`, `CloseAll`)
- When the form is closed (the editor automatically joins the form's close confirmation)
- With `MultiDocument = False`, when opening another file or creating a new one

| Situation | Behavior |
|---|---|
| `OnQueryClose` is set | Follows the event handler (takes precedence over `ConfirmOnFormClose`) |
| Not set, `ConfirmOnFormClose = True` (default) | Shows "(Title) has been modified. Do you want to save it? (No = close without saving)". Yes = save and close (does not close if it could not be saved), No = close without saving, Cancel = do not close |
| Not set, `ConfirmOnFormClose = False` | Discards without confirming |

- Inside the event, to abort closing, set `CanClose := False`. To discard without saving, do nothing (`CanClose` stays `True`). To save, save inside the event (15.3).
- `Index` is the number of the document being closed. It is not necessarily the visible tab.
- If even one is cancelled when closing the form, the closing is aborted at that point. The remaining documents and editors are not checked.

### 9.6 Adding or Replacing Keys (OnKeyDown)

Because key input is handled inside WebView2 (a separate process), the form's `KeyPreview` and the usual key handling do not work while the editor has focus. Use `OnKeyDown` instead.

| Item | Description |
|---|---|
| Keys that are notified | Combinations with Ctrl or Alt, F1 to F12, Esc, etc. (shortcut-type keys). Ordinary character input is not notified |
| Replacing built-in behavior | Setting `Key := 0` prevents the key from reaching the editor, and the built-in behavior does not occur |
| Range that can be replaced | All of the built-in shortcuts in 8.1. Monaco operations (Ctrl+Z, Ctrl+C, etc.) can also be replaced |
| Form shortcuts | Keys not used by the built-in shortcuts are passed on to the shortcuts of the form's menus and ActionList (even when the editor has focus, menu shortcuts such as Ctrl+O work) |

**Order in which a key is processed**

1. `KeyDown` of the inherited component (if overridden)
2. `OnKeyDown`, inside `inherited`
3. If `Key <> 0` still holds at this point, a built-in shortcut key performs its built-in behavior
4. Keys not used by the built-in shortcuts are passed on to the shortcuts of the form's menus and ActionList. If one is executed, that key is not passed to the editor
5. If none applies, it reaches the editor as is

- The "built-in shortcut keys" are the keys in 8.1, plus `Ctrl+Z`, `Ctrl+Y`, `Ctrl+Shift+Z`, `Ctrl+X`, `Ctrl+C`, and `Ctrl+V`. For other Monaco keys (such as `Ctrl+D`), if the form has the same shortcut, the form takes precedence.
- Form menus and actions are executed after the key notification has finished.

**When inheriting to create your own component**

TCMonacoEditor has a protected virtual method `KeyDown(var Key: Word; Shift: TShiftState)` (the same form as the LCL's TWinControl). Calling `inherited` invokes `OnKeyDown` inside it. If you do not call it, `OnKeyDown` is not called either (15.12).

### 9.7 Right-Click Menu

| State | Items shown |
|---|---|
| A string is selected | Cut, Copy, Paste, Copy with quote, Append cut, Append copy, Delete, TO UPPER CASE, to lower case, Convert to half-width, Convert to full-width hiragana, Convert to full-width katakana, TAB -> spaces, spaces -> TAB, Indent, Outdent |
| Nothing selected | Paste, Select all, Undo, Redo |
| Always (last) | Separator, Minimap　Ctrl+Shift+M, Preview　Ctrl+Shift+V |

- Minimap and Preview toggle `Minimap` and `ShowPreview` respectively. A check mark appears when the current value is on. They are always available (even with `ReadOnly`). They apply to all tabs of the editor. The toggled state lasts only while running; on the next startup it returns to the Object Inspector value.
- When `ReadOnly`, the editing items are unavailable.
- For the conversion items, the converted string remains selected, and one Undo restores it.
- "Copy with quote" copies with `QuotePrefix` added at the start of each line. "Append cut" and "Append copy" add to the end of the clipboard's current contents.
- To add your own items, use `ed.Monaco.PopupMenu.Items.Add` (15.6). Adjust the display in `OnPopup`. Your own items are placed after the items above.
- The preview's right-click menu is Copy, Select all, Print... (11.6).

### 9.8 Dropping Files

- Dropping files onto the editor opens them. With `MultiDocument = True`, they open in new tabs (if already open, it switches to that tab), and all of multiple files are opened. With `MultiDocument = False`, the current document is replaced (the confirmation in 9.5 is performed if unsaved).
- Folders are ignored.
- Setting `OpenDroppedFiles := False`, or `Handled := True` in `OnFileDrop`, stops the standard handling.
- Dropping onto the tab strip (the upper part) is not supported.

### 9.9 Detaching and Attaching Tabs (TabTearOff)

When you drag a tab outside the application's window and release it, the result depends on where it is dropped.

| Dropped on | Behavior |
|---|---|
| The desktop, or a window of another application | Detach: launches another instance of the same EXE and opens that tab in it. The tab disappears from the original window |
| Over the editor (tab strip, body, preview) of another window of the same EXE (one launched separately) | Attach: creates a new tab in that editor and opens it. The tab disappears from the original window |
| Somewhere in another window of the same EXE that is not the editor (menu, buttons, etc.) | Nothing happens |
| Within your own application (editor, preview, another form, the tab strip of another editor) | Nothing happens |

| Setting | Behavior |
|---|---|
| `TabTearOff = True` (default) | The component performs all detaching and attaching. No application code is needed |
| `TabTearOff = False` | Neither detaches nor attaches. Tabs dropped from other windows are not accepted either. `OnTabDragOut` still fires, so you can implement detaching yourself (15.14) |

**What is carried over** (for both detaching and attaching)

| Item | Carried over |
|---|---|
| Body text | Carried over (including unsaved edits) |
| File name | Carried over |
| Character encoding and language | Carried over |
| Modified mark (` *`) | Carried over |
| Undo history, cursor position, scroll position | Not carried over |

**How it is opened** (for both detaching and attaching)

| Original tab | How it is opened |
|---|---|
| A file is open, no changes | Opens that file (no ` *`) |
| A file is open, with changes | Opens under that file name with the unsaved body text (with ` *`) |
| Untitled (not yet saved) | Opens as untitled with the body text put in (with ` *` if there is body text. Saving shows the Save As dialog) |
| Has a file name, but the file on disk has been deleted | Opens as untitled with the body text put in (with ` *`) |

**Rules for detaching**

- The new window appears at the position where the tab was dropped. If it would extend beyond the screen, it is shifted to fit.
- The contents of the new window appear 1 to 2 seconds later, because it waits for WebView2 and Monaco to start.
- The new window accepts it into an editor with the same names as the original (the form's `Name` and the editor's `Name`) and `TabTearOff = True`. Even if one form has several editors, it opens in the same editor as the original.
- For an editor dropped on a form (`.lfm`), the new window appears at the drop position from the start. For an editor created in code (15.13), it moves to the drop position after being displayed, so it appears to move briefly.
- If the new window could not be launched, the tab is left open without closing, and `OnError` reports it.
- In an application that forbids multiple instances, a new window cannot be launched, so detaching is not possible.
- The environment variable `CM_TEAROFF` is used for the handover (passed only to the new EXE being launched; command-line parameters are not used). The application must not use an environment variable of this name.

**Rules for attaching**

- The target is the editor of the other window located under the drop position. The new tab becomes that editor's visible tab, and the other window is brought to the front.
- If the other editor already has the same file open, it does not attach. It switches to that tab in the other editor and brings the other window to the front. The original tab remains.
- If the other editor has `TabTearOff = False` or `MultiDocument = False`, nothing happens.
- If the other window does not respond (3 seconds) or is running as administrator, the tab cannot be moved. The original tab is left, and `OnError` reports it.

**Common rules**

- When there is only one untitled tab with nothing in it, neither detaching nor attaching is performed (`OnTabDragOut` still fires. Its `TearOff` value arrives as `False`, so setting it to `True` makes it detach/attach).
- If the tab taken out is the last one, one empty untitled tab remains in the original window (there is always at least one tab).
- When a drag is cancelled with `Esc`, nothing happens.
- When `MultiDocument = False`, no tabs are shown, so this cannot be operated.
- While dragging, the mouse cursor takes a "cannot drop" shape outside the application's window, but releasing it detaches/attaches.

## 10. Find/Replace Dialog

- An editor without `FindDialog` set uses the built-in shared dialog, one per form. However many editors you drop, there is one dialog.
- The target is the editor where `Ctrl+F` was pressed (the editor that last had focus). If you click another editor while the dialog is open, the target switches to it.
- The target is shown in the title (example: "Find/Replace - readme.md").
- The dialog's position, search term, replacement term, history, and options are common to all editors.
- To control it yourself, drop one `TCMFindDialog` from the palette on the form and select it in each editor's `FindDialog`. Several editors can select the same dialog.

| Item | Description |
|---|---|
| Search term / replacement term | Combo boxes with history |
| Options | Match case, whole word, loop search (there is no regular expression) |
| Buttons | Find Next, Find Previous, Replace, Replace All, Close. `Enter` finds next, `Esc` closes |
| Result | "Not found" and "N replaced" are shown at the bottom of the dialog |

- Replace replaces the selected string if it is the same as the search term, and then searches for the next one. Replace All is undone with one Undo.

## 11. Preview (Markdown and Code)

### 11.1 Mechanism

- The content is taken from the editor's body text, not from the file. Unsaved edits are also displayed. It updates after waiting `PreviewDelayMs` after an edit. When tabs are switched, it updates immediately.
- All libraries are in the preview folder and work offline.

| Library | Purpose |
|---|---|
| marked | Converts Markdown to HTML (GFM tables, task lists) |
| DOMPurify | Makes the generated HTML harmless (removes scripts and the like) |
| highlight.js | Code syntax coloring (delphi, dos, and powershell have been added) |
| github-markdown-css | The basis of the appearance (light / dark) |
| mermaid | Mermaid diagrams (11.7) |

### 11.2 Showing and Hiding

- Decided by `ShowPreview` (default `False`). Toggled with `Ctrl+Shift+V`. It appears for tabs of any language.
- When tabs are switched, the content of the newly switched tab is shown (Markdown as a document, other languages as color-highlighted code).
- Whether it is Markdown is decided by the tab's language.
- The preview's WebView2 is created when it is first displayed. If it is never shown, it is not created (no memory is used).
- The width of the preview can be changed at the splitter. The changed width is stored in `PreviewWidth` and used the next time it is shown.

### 11.3 Markdown Display and Colors

- Supports tables (GFM), task lists, and syntax coloring of code blocks. Code blocks with no language specified are not colored.
- By default, it uses the same colors as the editor (`PreviewBackColor…`, `PreviewTextColor…`, `PreviewLinkColor…`). Table borders and the code block background are decided automatically from the background and text colors.
- The syntax coloring of code blocks is also brought close to the editor's colors. However, the editor (Monaco) and the preview (highlight.js) use different coloring mechanisms, so they do not become completely identical. Bracket coloring is not applied.
- Setting `ColorScheme := csGitHub` gives GitHub-style colors.
- The fonts are `Segoe UI`, `Yu Gothic UI`, and `Meiryo`, in that order.
- The leading YAML (the part enclosed by `---`) is not displayed.
- Task list checkboxes are display only (clicking them does not change the body text).
- Scripts are removed, so Markdown that comes from outside does not execute when opened.

**Code (tabs other than Markdown)**

| Item | Description |
|---|---|
| Display | The whole body text is shown as color-highlighted code with line numbers |
| Coloring | The tab's language is mapped to a highlight.js language (example: pascal → delphi, bat → dos). Unsupported languages and plaintext are not colored |
| Long lines | Wrapped (the line number is attached only to the first line of the wrapped lines) |
| Large files | Files exceeding 500,000 characters are not colored (the display with line numbers is still done). It takes about 1.5 seconds for 60,000 lines (it is processing inside the preview, so editor input does not stop) |
| Copying | Line numbers are not copied |
| Font | Monospaced (`Consolas`, `BIZ UDゴシック`, `MS ゴシック`, in that order) |

### 11.4 Links and Images

- Images are displayed whether they use a relative path (counted from the folder of the open file) or an absolute path such as `C:\...`.
- Images from the Internet (http) are not displayed unless `AllowRemoteImages = True`.
- Links to the outside (`http`, `https`, `mailto`) open in the default browser. The preview does not navigate.
- Links to `.md` files open in that editor (following `MultiDocument`) unless `OnOpenMarkdown` is set.
- Links to `#heading` scroll within the preview.
- Links to other files are not opened, for safety.

### 11.5 Synchronizing Scrolling

| `SyncScroll` | Behavior |
|---|---|
| `ssBoth` (default) | Both directions. Moving the editor moves the preview, and moving the preview moves the editor |
| `ssEditorToPreview` | Editor to preview only |
| `ssNone` | Not synchronized |

- Synchronization is by line number. Within long paragraphs with much wrapping, it drifts somewhat.
- When the height changes due to image loading and the like, it is re-synchronized.

### 11.6 Printing

- Right-click "Print..." in the preview, `Ctrl+P` (whether the editor or the preview has focus), and `Print` show the same print dialog as Edge. Printer, save as PDF, pages, number of copies, and so on are all chosen in the dialog.
- What is printed is the visible tab. Markdown prints as a document; other tabs print the code described in 11.3. To print another tab, switch to it first with `ActiveIndex`.
- When the preview is not shown, the preview is shown only during printing and hidden when the print dialog closes. If the closing is not notified, it stays shown (hide it with `Ctrl+Shift+V`). The first time, it takes a little while because it waits for the preview's WebView2 to start.
- Even if the screen is dark, printing uses a white background and black text. Markdown code blocks are all black; code tabs are colored with dark colors for printing. Long lines are wrapped.
- The PDF name is the visible tab's name without the extension (`abc.md` → `abc.pdf`, `Unit1.pas` → `Unit1.pdf`, Untitled → `Untitled.pdf`). The save location is decided in the print dialog.
- The editor (Monaco) screen itself is not printed.

### 11.7 Mermaid Diagrams

Writing in a ` ```mermaid ` code block in Markdown draws it as a diagram in the preview.

| Opening line | Diagram |
|---|---|
| `graph TD`, `graph TB` | Flowchart (top to bottom) |
| `graph LR` | Flowchart (left to right) |
| `flowchart LR` | Flowchart (left to right) |
| `sequenceDiagram` | Sequence diagram |
| `usecase-beta` | Use case diagram |
| `classDiagram` | Class diagram |
| `erDiagram` | ER diagram |
| `gitGraph` | Git graph |
| `journey` | User journey |
| `xychart-beta` | XY chart (bar, line) |
| `quadrantChart` | Four-quadrant chart |
| `architecture-beta` | Architecture diagram |

| Item | Description |
|---|---|
| Colors | Lines and borders use the editor color scheme's blue (dark #3794ff, light #006ab1), and the background and text use the same colors as the preview. It also follows theme switching. Depending on the diagram type (git graph, XY chart, etc.), some of Mermaid's standard colors remain |
| Size | Initially displayed to fit the preview's width. When you hover the mouse over a diagram, four buttons appear at the upper right: Move (when pressed, the diagram can be moved by dragging) / Zoom out / Zoom in / Fit to frame (returns to the initial size). Zooming and moving affect only that diagram. For a diagram whose content has not changed, the zoom and move state is kept even if the body text is edited |
| Printing | Printed with colors for a white background, fitted to the paper width (unrelated to the on-screen zoom and move) |
| Writing mistakes | The error content is shown in the place of that diagram (the other parts display normally) |
| Internet images inside a diagram (`img: "https://..."`) | `AllowRemoteImages = False` (default): not fetched; the diagram is drawn without the image, with "[External images are not displayed]" below the diagram. `True`: fetched and drawn. If it could not be fetched, the diagram is redrawn without the image and shows "[Could not retrieve the image]" |
| Safety | Scripts inside a diagram do not run |

- The Mermaid library (about 5.5MB) is loaded only when a document containing a Mermaid diagram is displayed.

## 12. Standard Actions

When operating from the form's menus and buttons, use the standard actions without writing code. They are used the same way as Lazarus standard actions such as "Open File".

| No | Action (class name) | Display name | Default shortcut | Behavior | Enabled when | Checked |
|---|---|---|---|---|---|---|
| 1 | `TCMEditorNew` | &New | Ctrl+N | `NewPage` | A target editor exists | ― |
| 2 | `TCMEditorOpen` | &Open... | Ctrl+O | Selects with `OpenDialog` (the built-in one when not set) and calls `OpenFile`. With tabs, multiple files can be selected | A target editor exists | ― |
| 3 | `TCMEditorSave` | &Save | Ctrl+S | `Save` (a save dialog for an untitled document) | A target editor exists | ― |
| 4 | `TCMEditorSaveAs` | Save &As... | None | `SaveAs` | A target editor exists | ― |
| 5 | `TCMEditorClose` | &Close | Ctrl+W | `Close` (performs the confirmation in 9.5). When `MultiDocument = False`, it confirms and empties the contents | A target editor exists | ― |
| 6 | `TCMEditorPrint` | &Print... | Ctrl+P | `Print` | `CanPrint` | ― |
| 7 | `TCMEditorSaveAll` | Save A&ll | Ctrl+Shift+S | `SaveAll` | There is a tab with changes | ― |
| 8 | `TCMEditorCloseAll` | Clos&e All | None | `CloseAll` (performs the confirmation in 9.5) | A target editor exists | ― |
| 9 | `TCMEditorUndo` | &Undo | Ctrl+Z | `Undo` | `CanUndo` | ― |
| 10 | `TCMEditorRedo` | &Redo | Ctrl+Y | `Redo` | `CanRedo` | ― |
| 11 | `TCMEditorCut` | Cu&t | Ctrl+X | `Cut` | Something is selected (`SelLength > 0`) and not `ReadOnly` | ― |
| 12 | `TCMEditorCopy` | &Copy | Ctrl+C | `Copy` | Something is selected (`SelLength > 0`) | ― |
| 13 | `TCMEditorPaste` | &Paste | Ctrl+V | `Paste` | The clipboard has text and not `ReadOnly` | ― |
| 14 | `TCMEditorSelectAll` | Select &All | Ctrl+A | `SelectAll` | A target editor exists | ― |
| 15 | `TCMEditorDuplicateLine` | &Duplicate Line | Shift+F10 | `DuplicateLine` | Not `ReadOnly` | ― |
| 16 | `TCMEditorDeleteToEnd` | Delete to End | None | `DeleteToEnd` | Not `ReadOnly` | ― |
| 17 | `TCMEditorDeleteToStart` | Delete to Start | None | `DeleteToStart` | Not `ReadOnly` | ― |
| 18 | `TCMEditorFind` | &Find/Replace... | Ctrl+F | `ShowFindDialog` | A target editor exists | ― |
| 19 | `TCMEditorFindNext` | Find &Next | F5 | `FindNext` | A target editor exists | ― |
| 20 | `TCMEditorFindPrev` | Find Pre&vious | Shift+F5 | `FindPrev` | A target editor exists | ― |
| 21 | `TCMEditorMinimap` | &Minimap | Ctrl+Shift+M | Toggles `Minimap` | A target editor exists | `Minimap` |
| 22 | `TCMEditorPreview` | Pre&view | Ctrl+Shift+V | Toggles `ShowPreview` | A target editor exists | `ShowPreview` |
| 23 | `TCMEditorLineNumbers` | &Line Numbers | F11 | Toggles `LineNumbers` | A target editor exists | `LineNumbers` |
| 24 | `TCMEditorWordWrap` | &Word Wrap | None | Toggles `WordWrap` | A target editor exists | `WordWrap` |
| 25 | `TCMEditorRemoteImages` | Show Internet &Images | None | Toggles `AllowRemoteImages` | A target editor exists | `AllowRemoteImages` |

- Usage: drop a `TActionList` on the form, add actions of category `CX` from "Add Standard Action" in the action list editor, and select them in the menu item's `Action`.
- The target is decided automatically as the editor that last had focus. If none has been focused yet, the first editor. To find it from code, use `CMActiveEditor(Form)`.
- When unavailable, they are grayed out. Availability and check marks are refreshed by Lazarus when the application is idle and when a menu is opened.
- An action's shortcut works even when the editor has focus (9.6). However, for keys identical to a built-in shortcut, the built-in one takes precedence (the behavior is the same). To give the action priority, replace it with `OnKeyDown`.
- The display name, hint, and shortcut may be changed in the Object Inspector after adding.
- If `OnExecute` is set, it is called in place of the standard behavior. If `OnUpdate` is set, it is called in place of the standard refresh (same as `TAction`).
- For exit, use Lazarus's standard action `TFileExit`.

## 13. Cursor-Line String and Words

### 13.1 Values Available

| Notation | What you get | In awk terms |
|---|---|---|
| `ed.LineText` | String of the cursor line (without the line break) | `$0` |
| `ed.LineWords[0]` | The first word | `$1` |
| `ed.LineWords[1]` | The second word | `$2` |
| `ed.LineWords.Count` | Number of words | `NF` |

- It can be read anywhere (inside `OnCursorChange`, buttons, menus, timers, etc.). You get the value of the cursor line at the time of reading.
- If you read inside `OnCursorChange`, you get the correct value even right after typing a character.
- If you read inside `OnKeyDown`, you get the line as it was before that key takes effect.
- The target is the cursor line of the visible tab. '' before it is ready.
- Reading `LineWords[0]` on a line with 0 words (such as an empty line) causes an out-of-range error. Check `Count` first.
- The `LineWords` list is owned by the component. Do not `Free` it. Its contents change the next time you read it, so if you want to keep them, copy them into your own `TStringList` with `Assign`.

### 13.2 Splitting Settings

| Name | Default | Description |
|---|---|---|
| `LineDelimiters` | Half-width space, full-width space, tab, comma (`,`), Japanese comma (`、`) | Delimiter characters. Each character written is a delimiter. Full-width characters can also be written. If '', the whole line is one word |
| `LineSkipEmpty` | `True` | `True`: consecutive delimiters are treated as one, and no empty words are included. Delimiters at the start and end of the line are also ignored. `False`: empty words are also included |
| `LineQuoteChar` | `"` | Quote character (one half-width character). If `#0`, quotes are not interpreted |

- None of the three appear in the Object Inspector. Set them in code (because tabs and full-width spaces cannot be seen or entered in the Object Inspector).

### 13.3 Splitting Rules

1. Looking at one character at a time from the start of the line, split at the characters in `LineDelimiters`.
2. If a word begins with a quote character, everything up to the next quote character becomes one word. It is not split at delimiters inside. The quote characters are removed.
3. Writing two consecutive quote characters inside quotes gives one quote character.
4. Characters from after the closing quote up to the next delimiter are attached to the end of the same word.
5. If there is no closing quote, everything to the end of the line becomes one word.
6. A quote character in the middle of a word is treated as an ordinary character.
7. If the quote character is also included in `LineDelimiters`, it is treated as a delimiter (not interpreted as a quote).
8. With `LineSkipEmpty = True`, empty words (where delimiters are consecutive, delimiters at the start or end of the line, `""`) are not included.
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

### 13.4 How Values Are Held

| Value | How it is held |
|---|---|
| `LineText` | Arrives from the editor and is held by the component when the cursor moves to a different line, when the content of the line changes, or when tabs are switched. Just moving within the same line does not send it (there is no need) |
| `LineWords` | Split for the first time when read. If never read, it is never split. If the line and the settings are the same as when last read, the previous result is returned without re-splitting |

- Even if one line is several MB, the splitting process does not run unless `LineWords` is read.
- Typing characters in a single line of several MB sends the entire line from the editor for every character, so it can become slow.

## 14. Notes

| Item | Description |
|---|---|
| `Text`, `SelText`, etc. right after input | If read from code right after typing or selecting (within about 0.1 second), the last few characters may be out of date (the same inside `OnKeyDown`). A value written with `Text :=` can be read back immediately |
| How `SelStart` and `SelLength` count | Emoji count as 2 |
| How the body text is held | The body text is held in two places (Monaco and the component) (memory is twice the body text) |
| Before it is ready | Body text and the like written before `Ready` is held by the component and sent to Monaco when it is ready |
| Synchronized scrolling | Within long paragraphs with much wrapping, it drifts somewhat |
| Math formulas / export to HTML | Not available |
| Docking / undocking | Even when the component's window is recreated, for example by docking or undocking with AnchorDocking, the editor body (the open documents, cursor and Undo history) and the preview display remain as they are |
## 15. Usage Examples

### 15.1 Making a Text Editor Without Writing Code

1. Drop one TCMonacoEditor on the form and set `Align = alClient`.
2. Place the files in 2.1 in the same folder as the EXE.

That alone provides the following.

| Feature | Operation |
|---|---|
| Editing | As is |
| Opening a file | Drop it |
| Show/hide line numbers | `F11` |
| Find/replace | `Ctrl+F`, `F5` / `Shift+F5` |
| Save | `Ctrl+S` (a "Save As" dialog for an untitled document) |
| Preview | `Ctrl+Shift+V` |
| Syntax coloring | Automatic from the extension |
| Printing (save as PDF) | `Ctrl+P`, or right-click the preview and choose "Print..." |
| Confirmation for unsaved documents | Automatically confirmed when the form is closed |

### 15.2 Dropping Three on One Form

1. Drop three TCMonacoEditor components and decide their placement (example: `alLeft`, `alLeft`, `alClient`). Only one can be `alClient` within the same parent.
2. Set `MultiDocument = False` on all three.

No code is needed. The find/replace dialog is a single shared one, and the editor where `Ctrl+F` was pressed becomes the target. The standard actions act on the editor that last had focus. They may also be placed on separate sheets of a `TPageControl` (an editor on a sheet that is not visible starts when it is first displayed).

### 15.3 Saving Unsaved Documents Without Asking

```pascal
procedure TForm1.CMonacoEditor1QueryClose(Sender: TObject; Index: Integer;
  var CanClose: Boolean);
var
  E: TCMonacoEditor;
begin
  E := Sender as TCMonacoEditor;
  E.Pages[Index].Save;                          // Save (a save dialog appears for an untitled document)
  CanClose := not E.Pages[Index].Modified;      // Do not close if cancelled in the save dialog
end;
```

- To share it among several editors, in the Object Inspector select the same method for the `OnQueryClose` of every editor.

### 15.4 Adding a Menu

1. Drop a `TActionList` and a `TMainMenu` on the form.
2. In the action list editor, add the CX standard actions (Chapter 12).
3. Select the action in each menu item's `Action`.

### 15.5 Using Your Own Dialogs

1. Drop `TOpenDialog`, `TSaveDialog`, and `TCMFindDialog` on the form, and set the filters and initial folder.
2. Select them in each editor's `OpenDialog`, `SaveDialog`, and `FindDialog`.

### 15.6 Adding Your Own Items to the Right-Click Menu (Advanced)

```pascal
procedure TForm1.FormCreate(Sender: TObject);
var
  MI: TMenuItem;
begin
  MI := TMenuItem.Create(Self);
  MI.Caption := 'Wrap in [ ]';
  MI.OnClick := @MyMenuClick;
  CMonacoEditor1.Monaco.PopupMenu.Items.Add(MI);
end;

procedure TForm1.MyMenuClick(Sender: TObject);
begin
  CMonacoEditor1.SelText := '[' + CMonacoEditor1.SelText + ']';
end;
```

### 15.7 Using a Single monaco and preview from Several Applications

```
C:\apps\
  monaco\
  preview\
  WebView2Loader.dll
  tcTabBrowser\
    tcTabBrowser.exe
    WebView2.ini
  MyEditor\
    MyEditor.exe
    WebView2.ini
```

Write the following in each application's WebView2.ini. The application's code and `.lfm` do not change.

```ini
[WebView2]
LoaderDllPath=..\WebView2Loader.dll
UserDataFolder=WebView2Data
MonacoFolder=..\monaco
PreviewFolder=..\preview
```

- Keep `UserDataFolder` separate for each application (2.2).

### 15.8 Replacing the Built-in Ctrl+S with Your Own Save Handling

```pascal
procedure TForm1.CMonacoEditor1KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_S) and (ssCtrl in Shift) then
  begin
    MySave(Sender as TCMonacoEditor);
    Key := 0;   // The built-in save does not run
  end;
end;
```

### 15.9 Choosing Tab Icons Yourself

```pascal
procedure TForm1.CMonacoEditor1GetTabImageIndex(Sender: TObject; Index: Integer;
  const FileName: string; var ImageIndex: Integer);
begin
  if SameText(ExtractFileExt(FileName), '.md') then
    ImageIndex := 0
  else
    ImageIndex := 1;
end;
```

### 15.10 Showing the Words of the Cursor Line

```pascal
procedure TForm1.CMonacoEditor1CursorChange(Sender: TObject; Line, Column: Integer);
var
  W: TStrings;
  i: Integer;
begin
  Label1.Caption := CMonacoEditor1.LineText;
  W := CMonacoEditor1.LineWords;
  Memo1.Lines.Clear;
  for i := 0 to W.Count - 1 do
    Memo1.Lines.Add(W[i]);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  CMonacoEditor1.LineDelimiters := ' ' + '　' + #9;   // Do not split at commas or Japanese commas
end;
```

### 15.11 Opening a File and Setting Focus on the Editor When It Is Ready

```pascal
procedure TForm1.CMonacoEditor1Ready(Sender: TObject);
begin
  CMonacoEditor1.OpenFile('C:\docs\readme.md');
  CMonacoEditor1.SetFocus;
end;
```

### 15.12 Inheriting to Create Your Own Component

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

### 15.13 Creating It in Code

```pascal
uses
  uCmonacos;

procedure TForm1.FormCreate(Sender: TObject);
var
  E: TCMonacoEditor;
begin
  E := TCMonacoEditor.Create(Self);
  E.MultiDocument := False;   // Change it before setting Parent
  E.Parent := Self;           // Joins the form's close confirmation here
  E.Align := alClient;
end;
```

### 15.14 Implementing Tab Detaching Yourself (Advanced)

An example of implementing it yourself inside `OnTabDragOut` without using the component's detaching (`TabTearOff = True`). Set `TabTearOff = False`. This example uses a startup parameter (`/tearoff temporary-file`) for the handover.

Format of the temporary file (UTF-8):

```
CMTEAROFF1
Editor=Form1.CMonacoEditor1
FileName=C:\docs\a.md
Encoding=0
Language=markdown
Modified=1
X=800
Y=300

(from here to the end is the body text)
```

- The first line is a marker. Up to the empty line is the header, and everything after it is the body text.
- `FileName` is empty for an untitled document. `Encoding` is the number (`Ord`) of `TCMEncoding`.

Sending side (the original EXE):

```pascal
uses
  Process, uCmonacos;

const
  TearOffMark = 'CMTEAROFF1';

// When a tab is taken out, open that tab in another EXE and close this tab
procedure TForm1.CMonacoEditor1TabDragOut(Sender: TObject; Index, X, Y: Integer;
  var TearOff: Boolean);
var
  E: TCMonacoEditor;
  P: TCMPage;
  FN, S: string;
  FS: TFileStream;
  Proc: TProcess;
begin
  TearOff := False;   // Do not use the component's detaching (it is already False when TabTearOff = False)
  E := Sender as TCMonacoEditor;
  P := E.Pages[Index];

  // If there is only one untitled tab with nothing in it, taking it out is meaningless, so do nothing
  if (E.PageCount = 1) and (P.FileName = '') and (P.Text = '') then Exit;

  // 1. Write the tab contents to a temporary file (header, empty line, body text)
  FN := GetTempFileName(GetTempDir, 'cmt');
  S := TearOffMark + LineEnding +
       'Editor=' + Name + '.' + E.Name + LineEnding +
       'FileName=' + P.FileName + LineEnding +
       'Encoding=' + IntToStr(Ord(P.Encoding)) + LineEnding +
       'Language=' + P.Language + LineEnding +
       'Modified=' + IntToStr(Ord(P.Modified)) + LineEnding +
       'X=' + IntToStr(X) + LineEnding +
       'Y=' + IntToStr(Y) + LineEnding +
       LineEnding +
       P.Text;
  FS := TFileStream.Create(FN, fmCreate);
  try
    if S <> '' then FS.WriteBuffer(S[1], Length(S));
  finally
    FS.Free;
  end;

  // 2. Launch your own EXE with the temporary file as an argument (do not wait for it to finish)
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := Application.ExeName;
    Proc.Parameters.Add('/tearoff');
    Proc.Parameters.Add(FN);
    try
      Proc.Execute;
    except
      on Ex: Exception do
      begin
        DeleteFile(FN);   // If it could not be launched, leave the tab open without closing it
        MessageDlg('Could not open in another window: ' + Ex.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
  finally
    Proc.Free;
  end;

  // 3. If it was launched, close this tab without asking (the body text remains in the temporary file)
  P.Close(True);
end;
```

Receiving side (the new EXE. It is the same EXE, so write it in the same form):

```pascal
// FTearFile: string;  … Put it in the form's private section. The received temporary file

// Read the temporary file, splitting it into the header (Head) and the body text (Body)
function ReadTearOff(const AFile: string; Head: TStrings; out Body: string): Boolean;
var
  FS: TFileStream;
  S: string;
  p: Integer;
begin
  Result := False;
  Body := '';
  FS := TFileStream.Create(AFile, fmOpenRead or fmShareDenyNone);
  try
    SetLength(S, FS.Size);
    if S <> '' then FS.ReadBuffer(S[1], Length(S));
  finally
    FS.Free;
  end;
  p := Pos(LineEnding + LineEnding, S);          // The first empty line
  if p = 0 then Exit;
  Head.Text := Copy(S, 1, p - 1);
  Body := Copy(S, p + 2 * Length(LineEnding), MaxInt);
  Result := (Head.Count > 0) and (Head[0] = TearOffMark);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  Head: TStringList;
  Body: string;
begin
  FTearFile := '';
  if (ParamCount >= 2) and (ParamStr(1) = '/tearoff') and FileExists(ParamStr(2)) then
  begin
    FTearFile := ParamStr(2);
    // Show the window at the position where the tab was dropped
    Head := TStringList.Create;
    try
      if ReadTearOff(FTearFile, Head, Body) then
      begin
        Position := poDesigned;
        Left := StrToIntDef(Head.Values['X'], Left);
        Top  := StrToIntDef(Head.Values['Y'], Top);
      end;
    finally
      Head.Free;
    end;
  end;
end;

// When the editor is ready, create the tab from the temporary file
procedure TForm1.CMonacoEditor1Ready(Sender: TObject);
var
  E: TCMonacoEditor;
  Head: TStringList;
  Body, FN: string;
begin
  if FTearFile = '' then Exit;
  E := Sender as TCMonacoEditor;
  Head := TStringList.Create;
  try
    if ReadTearOff(FTearFile, Head, Body) then
    begin
      FN := Head.Values['FileName'];
      if (FN <> '') and FileExists(FN) then
      begin
        // The file exists: load it into the untitled tab present right after startup (the number of tabs does not increase)
        E.LoadFromFile(FN);
        if Head.Values['Modified'] = '1' then
          E.Text := Body;                          // Replace with the unsaved body text (* is added)
      end
      else
        // Untitled, or the file has been deleted: put the body text in as untitled (* is added)
        E.Text := Body;
      E.Encoding := TCMEncoding(StrToIntDef(Head.Values['Encoding'], 0));
      E.Language := Head.Values['Language'];
    end;
  finally
    Head.Free;
  end;
  DeleteFile(FTearFile);   // Delete after reading is finished (if it fails before reading, the body text remains)
  FTearFile := '';
  E.SetFocus;
end;
```

- The temporary file is deleted after the new EXE has finished reading it. If the new EXE fails before reading it, it remains in `%TEMP%` as `cmt*.tmp`.
