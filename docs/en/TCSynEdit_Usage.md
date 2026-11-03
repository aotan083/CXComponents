# TCSynEdit User Manual

Author: aotan083
Date: 2026-11-03
Version: 1.1

---

## 1. Overview and classes

A text editor component based on SynEdit. All TSynEdit features remain available, and it adds file reading and writing, color scheme switching, a right-click menu similar to that of the Hidemaru editor, events that report state changes, and more.

- Automatically switches the language and color-coding (highlighter) according to the file name extension. The mapping between extensions and languages is the same as in TCMonacoEditor.
- The color scheme can be chosen from six: black, gray, white, matching the Windows theme, VS Code light, and VS Code dark.
- Has Markdown color-coding.
- Dropping a file opens it.
- Ctrl+S saves (overwrites), and Ctrl+mouse wheel changes the character size.

| Item | Details |
|---|---|
| Lazarus | 5.0 or later |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |
| External packages used | SynEdit (included with Lazarus) |

### 1.1 Classes and units

| Class | Unit | Package | Base class | Contents |
|---|---|---|---|---|
| `TCSynEdit` | `cSynEdit` | cx | `TSynEdit` (SynEdit) | A text editor based on SynEdit. Adds file reading and writing, color scheme switching, a right-click menu similar to that of the Hidemaru editor, and events that report state changes |
| `TCSynMarkdownSyn` | `cSynEdit` | cx | `TSynCustomHighlighter` (SynEdit) | Markdown color-coding. The component creates and uses it by itself with `Language := 'markdown'` (4.2) |

| Type | Unit | Contents |
|---|---|---|
| `TCEditStyle` | `cSynEdit` | Color scheme. `csBlack`, `csGray`, `csWhite`, `csThema`, `csVSLight`, `csVSDark` (Chapter 3) |
| `TCFileEncoding` | `cSynEdit` | Kind of character encoding. `feUTF8`, `feANSI_SJIS`, `feUTF16LE`, `feUTF16BE`, `feEUCJP` |
| `TCLineEnding` | `cSynEdit` | Kind of line ending. `leCRLF`, `leLF`, `leCR` |
| `TCSynTextChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; const AText: string) of object`. Type of `OnTextChange` |
| `TOnFileNameChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var sFileName: String) of object`. Type of `OnFileNameChangeEvent` |
| `TOnLoadFromFileEvent` | `cSynEdit` | `procedure(Sender: TObject; var sFileName: String) of object`. Type of `OnLoadFromFileEvent` |
| `TOnSaveToFileEvent` | `cSynEdit` | `procedure(Sender: TObject; var sFileName: String) of object`. Type of `OnSaveToFileEvent` |
| `TOnInsModeChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var bMode: Boolean) of object`. Type of `OnInsModeChangeEvent` |
| `TOnCaretChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var iX, iY: Integer) of object`. Type of `OnCaretChangeEvent` |
| `TOnUndoRedoStateChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var bCanUndo, bCanRedo: Boolean) of object`. Type of `OnUndoRedoStateChangeEvent` |
| `TOnModifiedChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var bModified: Boolean) of object`. Type of `OnModifiedChangeEvent` |
| `TOnSelectionChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var sSelText: String; var iStartX, iStartY, iEndX, iEndY: Integer) of object`. Type of `OnSelectionChangeEvent` |
| `TOnFocusChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var bFocused: Boolean) of object`. Type of `OnFocusChangeEvent` |
| `TOnDropFilesEvent` | `cSynEdit` | `procedure(Sender: TObject; const AFiles: array of string) of object`. Type of `OnDropFilesEvent` |

| Function | Unit | Contents |
|---|---|---|
| `CSLanguageForFile(const AFileName, ADefault: string): string` | `cSynEdit` | Returns the language name from the file name extension (table in 4.1). Returns `ADefault` for an extension not in the table |

- When placed on a form, `cSynEdit` is added to uses automatically.
- When placed on a form, cx is automatically added to the project's required packages.
- When creating it in code, write it in uses yourself.

## 2. From placing it on a form to running it

1. Place TCSynEdit on the form from the [CX] palette.
2. Choose the color scheme with `EditStyle` in the Object Inspector (the default is `csGray`).
3. Place a button for opening a file and write `CSynEdit1.LoadFromFile(file name)` in its `OnClick` (9.1).
4. To show the file name in the title, double-click `OnFileNameChangeEvent` in the Events tab and write the handler (9.2).
5. Run it. Dropping a file opens it, and Ctrl+S saves (overwrites).

**Initial state**

| Item | Value |
|---|---|
| Font | BIZ UDGothic, 12 pt |
| Color scheme (`EditStyle`) | `csGray` |
| Language / color-coding | pascal (Pascal color-coding) |
| `FileName` | Folder of the executable + "`無題.txt`" |
| Insert / overwrite | Insert |
| Right-click menu | The component's own menu (8.3) |

- The initial font is BIZ UDGothic. In an environment where it is not installed, set `Font`.

## 3. Color scheme (EditStyle)

| Value | Background | Text | Details |
|---|---|---|---|
| `csBlack` | Black | White | Black color scheme |
| `csGray` | Black | White | Black color scheme. Line numbers are shown every 5 lines (default) |
| `csWhite` | White | Black | White color scheme |
| `csThema` | System color | System color | Matches the Windows theme (dark/light). Use it in combination with MetaDarkStyle or the like |
| `csVSLight` | White | Black | Same color scheme as the light theme of VS Code (TCMonacoEditor) |
| `csVSDark` | Near-black gray | Light gray | Same color scheme as the dark theme of VS Code (TCMonacoEditor) |

- The colors for reserved words, strings, comments, numbers, and so on also change to match the color scheme (for the color-coding of any language).
- Even when the language is switched (including when a file is opened), the colors of the color scheme are kept.
- With any color scheme, the bookmark column at the left edge is not shown. The line number column is shown (toggle with F12).
- With `csVSLight` and `csVSDark`, the changed-line marks (the colored vertical line at the left edge) are not shown. Line numbers are shown for every line.

**Main colors of csVSLight and csVSDark**

| Item | csVSLight | csVSDark |
|---|---|---|
| Background | #FFFFFE | #1E1E1E |
| Text | #000000 | #D4D4D4 |
| Reserved word | #0000FF | #569CD6 |
| String | #A31515 | #CE9178 |
| Comment | #008000 | #6A9955 |
| Number | #098658 | #B5CEA8 |
| Line number | #237893 | #6E7681 |
| Line number of the caret line | #0B216F | #C6C6C6 |
| Folding mark | #424242 | #5A5A5A |
| Caret line background | #EAF2FF | #2C313C |
| Selection background | #ADD6FF | #264F78 |
- The guide line at column 80 at the right edge is not visible because it has the same color as the background.

## 4. Language and color-coding (Language)

### 4.1 Extensions and languages

When `FileName` is set (including via `LoadFromFile` and `SaveToFile`), the language is decided from the extension and put into `Language`. Writing `Language` switches the color-coding to match the language.

| Extension | Language (`Language`) | Color-coding |
|---|---|---|
| .pas .pp .lpr .inc .dpr .lpk, no extension | pascal | Pascal |
| .md .markdown | markdown | Markdown (4.2) |
| .txt | plaintext | None |
| .html .htm | html | HTML |
| .css | css | CSS |
| .js | javascript | JavaScript |
| .json | json | JavaScript |
| .xml | xml | XML |
| .sql | sql | SQL |
| .ini .cfg | ini | INI |
| .bat .cmd | bat | Batch file |
| .py | python | Python |
| .c .h .cpp .hpp | cpp | C++ |
| .cs | csharp | C++ |
| .ts .tsx | typescript | JavaScript |
| .java | java | Java |
| .sh .bash | shell | Shell script |
| .ps1 .psm1 .psd1 | powershell | None |
| .yml .yaml | yaml | None |
| .php | php | PHP |
| .go | go | None |
| Anything else | unchanged | Unchanged (the previous color-coding remains) |

- For a language whose color-coding is "None", all characters take the text color of the color scheme.
- When the application puts its own color-coding into `Highlighter`, the component does not free it. The next time the language changes, it switches to the component's color-coding.

### 4.2 Markdown color-coding

| Syntax | Color (`csVSDark`) | Color (`csVSLight`) |
|---|---|---|
| Heading (`#` to `######`), list mark (`-` `*` `+` `1.`), rule (`---`) | Blue | Blue |
| Strong (`**...**` `__...__`) | Bold in the text color | Bold in the text color |
| Emphasis (`*...*` `_..._`) | Slanted in the text color | Slanted in the text color |
| Code (`` `...` ``), code block (` ``` ` `~~~`), link (`[...](...)` `<http...>`) | Orange | Reddish brown |
| Quote (`>`) | Green | Green |

- Everything inside a code block takes the code color (`#`, `**`, and so on do not change color).
- An unclosed `**`, and `_` between alphanumeric characters (snake_case), are ordinary text.
- Tables, heading underlines (`===`), and code that starts with four spaces are not given special color-coding.

## 5. Properties

### 5.1 Added or behavior-changed in this component

| Name | Type | Access | Details |
|---|---|---|---|
| `FileName` | `string` | Read/Write | File name being edited (the default is the folder of the executable + "`無題.txt`"). Writing it raises `OnFileNameChangeEvent` and switches `Language` and the color-coding to match the extension |
| `DisplayTitle` | `string` | Read | Short name to show on a tab and the like (the file name part of `FileName`; if empty, "`無題.txt`"). Runtime only |
| `EditStyle` | `TCEditStyle` | Read/Write | Color scheme (Chapter 3). The default is `csGray` |
| `Language` | `string` | Read/Write | Language name (the lowercase name in the table in 4.1; the default is 'pascal'). Writing it switches the color-coding. Writing `FileName` decides it from the extension. Runtime only (not saved in the .lfm) |
| `InsMode` | `Boolean` | Read/Write | `True` (default): insert. `False`: overwrite |
| `CaretX` | `Integer` | Read/Write | Caret column (from 1) |
| `CaretY` | `Integer` | Read/Write | Caret line (from 1) |
| `EncodingType` | `TCFileEncoding` | Read/Write | A holder for remembering the character encoding (the default is `feUTF8`). Not used for reading or writing |
| `HasBOM` | `Boolean` | Read/Write | A holder for remembering the presence of a BOM (the default is `False`). Not used for reading or writing |
| `LineEndingType` | `TCLineEnding` | Read/Write | A holder for remembering the line ending (the default is `leCRLF`). Not used for reading or writing |

- `EncodingType`, `HasBOM`, and `LineEndingType` are for the application to remember the character encoding and line ending. `LoadFromFile` and `SaveToFile` do not look at these values (the character encoding is not converted).

### 5.2 Inherited from TSynEdit

| Name | Type | Access | Details |
|---|---|---|---|
| `Align` | `TAlign` | Read/Write | Placement within the parent |
| `Anchors` | `TAnchors` | Read/Write | Which edges follow when the parent's size changes |
| `AnchorSideBottom` | `TAnchorSide` | Read/Write | Which part of which component the bottom edge is aligned to |
| `AnchorSideLeft` | `TAnchorSide` | Read/Write | Which part of which component the left edge is aligned to |
| `AnchorSideRight` | `TAnchorSide` | Read/Write | Which part of which component the right edge is aligned to |
| `AnchorSideTop` | `TAnchorSide` | Read/Write | Which part of which component the top edge is aligned to |
| `Beautifier` | `TSynCustomBeautifier` | Read/Write | How indentation is done at a line break |
| `BlockIndent` | `Integer` | Read/Write | Width of block indentation |
| `BlockTabIndent` | `Integer` | Read/Write | Number of tabs used for block indentation |
| `BookMarkOptions` | `TSynBookMarkOpt` | Read/Write | Bookmark settings |
| `BorderSpacing` | `TControlBorderSpacing` | Read/Write | Surrounding margins |
| `BorderStyle` | `TBorderStyle` | Read/Write | Whether to show the border line (the default is `bsSingle`) |
| `BracketHighlightStyle` | `TSynEditBracketHighlightStyle` | Read/Write | How matching brackets are highlighted |
| `BracketMatchColor` | `TSynSelectedColor` | Read/Write | Color of matching brackets |
| `Color` | `TColor` | Read/Write | Background color. Changing `EditStyle` overwrites it with the color of the color scheme |
| `Constraints` | `TSizeConstraints` | Read/Write | Upper and lower limits of size |
| `Cursor` | `TCursor` | Read/Write | Mouse cursor when over the text (the default is `crIBeam`) |
| `DefaultSelectionMode` | `TSynSelectionMode` | Read/Write | Default way of selecting (normal, line, column) |
| `Enabled` | `Boolean` | Read/Write | Whether it is usable |
| `ExtraCharSpacing` | `Integer` | Read/Write | Width added between characters |
| `ExtraLineSpacing` | `Integer` | Read/Write | Width added between lines |
| `FoldedCodeColor` | `TSynSelectedColor` | Read/Write | Color of folded regions |
| `Font` | `TFont` | Read/Write | Characters (the default is BIZ UDGothic, 12 pt) |
| `Gutter` | `TSynGutter` | Read/Write | Left-edge column (line numbers and so on). Changing `EditStyle` overwrites the colors and display |
| `Height` | `Integer` | Read/Write | Height |
| `HelpContext` | `THelpContext` | Read/Write | Help number |
| `HelpKeyword` | `string` | Read/Write | Help keyword |
| `HelpType` | `THelpType` | Read/Write | Whether help is looked up by number (`htContext`) or by keyword (`htKeyword`) |
| `HideSelection` | `Boolean` | Read/Write | Whether to hide the selection color when not focused |
| `HighlightAllColor` | `TSynSelectedColor` | Read/Write | Color used when highlighting all occurrences of the same string |
| `Highlighter` | `TSynCustomHighlighter` | Read/Write | Color-coding. Setting `Language` or `FileName` switches it as described in Chapter 4 |
| `Hint` | `TTranslateString` | Read/Write | Hint text |
| `IncrementColor` | `TSynSelectedColor` | Read/Write | Color of matches found by incremental search |
| `InsertCaret` | `TSynEditCaretType` | Read/Write | Shape of the caret in insert mode |
| `InsertMode` | `Boolean` | Read/Write | Insert or overwrite (same as `InsMode`) |
| `Keystrokes` | `TSynEditKeyStrokes` | Read/Write | Assignment of keys to actions |
| `Left` | `Integer` | Read/Write | Left position |
| `LineHighlightColor` | `TSynSelectedColor` | Read/Write | Color of the caret line. Overwritten when `EditStyle` is changed |
| `Lines` | `TStrings` | Read/Write | Body text (by line) |
| `MaxLeftChar` | `Integer` | Read/Write | Maximum number of columns in one line |
| `MaxUndo` | `Integer` | Read/Write | Number of times that can be undone |
| `MouseActions` | `TSynEditMouseActions` | Read/Write | Assignment of mouse operations to actions |
| `MouseLinkColor` | `TSynSelectedColor` | Read/Write | Color of links |
| `MouseOptions` | `TSynEditorMouseOptions` | Read/Write | Settings for mouse behavior |
| `MouseSelActions` | `TSynEditMouseActions` | Read/Write | Assignment of mouse operations to actions over a selection |
| `MouseTextActions` | `TSynEditMouseActions` | Read/Write | Assignment of mouse operations to actions over text |
| `Name` | `TComponentName` | Read/Write | Component name |
| `OffTextCursor` | `TCursor` | Read/Write | Mouse cursor when outside the text (over the left-edge column and so on) |
| `Options` | `TSynEditorOptions` | Read/Write | Behavior and appearance settings |
| `Options2` | `TSynEditorOptions2` | Read/Write | Behavior and appearance settings (continued) |
| `OverwriteCaret` | `TSynEditCaretType` | Read/Write | Shape of the caret in overwrite mode |
| `ParentColor` | `Boolean` | Read/Write | Whether to use the parent's color |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the parent's `Font` |
| `ParentShowHint` | `Boolean` | Read/Write | Whether to use the parent's `ShowHint` |
| `PopupMenu` | `TPopupMenu` | Read/Write | Right-click menu. Initially the component's menu (8.3). If you put in your own menu, that one is shown |
| `ReadOnly` | `Boolean` | Read/Write | `True` makes it non-editable |
| `RightEdge` | `Integer` | Read/Write | Column of the right-edge guide line. Overwritten when `EditStyle` is changed |
| `RightEdgeColor` | `TColor` | Read/Write | Color of the right-edge guide line. Overwritten when `EditStyle` is changed |
| `RightGutter` | `TSynGutter` | Read/Write | Right-edge column |
| `ScrollBars` | `TScrollStyle` | Read/Write | How scroll bars are shown |
| `ScrollOnEditLeftOptions` | `TSynScrollOnEditOptions` | Read/Write | How scrolling works when typing moves the caret past the left edge |
| `ScrollOnEditRightOptions` | `TSynScrollOnEditOptions` | Read/Write | How scrolling works when typing moves the caret past the right edge |
| `SelectedColor` | `TSynSelectedColor` | Read/Write | Color of the selection. Overwritten when `EditStyle` is changed |
| `SelectionMode` | `TSynSelectionMode` | Read/Write | Current way of selecting (normal, line, column) |
| `ShowHint` | `Boolean` | Read/Write | Whether to show hints |
| `TabOrder` | `TTabOrder` | Read/Write | Order of movement with the Tab key |
| `TabStop` | `Boolean` | Read/Write | Whether the Tab key stops here (the default is `True`) |
| `TabWidth` | `Integer` | Read/Write | Tab width |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely |
| `Top` | `Integer` | Read/Write | Top position |
| `Visible` | `Boolean` | Read/Write | Whether it is shown |
| `VisibleSpecialChars` | `TSynVisibleSpecialChars` | Read/Write | Targets when showing spaces, tabs, and line breaks with symbols |
| `WantTabs` | `Boolean` | Read/Write | Whether the Tab key enters a tab (if `False`, it moves to the next component) |
| `Width` | `Integer` | Read/Write | Width |

## 6. Methods

### 6.1 File

| Name | Arguments | Return value | Details |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | - | Creates it. Used when creating in code (9.12) |
| `LoadFromFile` | `const AFileName: string` | - | Reads a file. Sets `FileName`, sets `Modified` to `False`, and raises `OnLoadFromFileEvent` |
| `SaveToFile` | `const AFileName: string` | - | Writes to a file. Sets `FileName`, sets `Modified` to `False`, and raises `OnSaveToFileEvent` |
| `Save` | - | - | Saves (overwrites) to `FileName` (same as Ctrl+S) |

- A file that was opened or saved is held so that other applications cannot write to it (it can still be read). It is released when another file is opened or the component is destroyed.

### 6.2 Editing

| Name | Arguments | Return value | Details |
|---|---|---|---|
| `InsertTextAtCaret` | `const AText: string` | - | Inserts a string at the caret position (does nothing for '') |
| `ReplaceSelection` | `const AText: string` | - | Replaces the selected string (inserts at the caret position if nothing is selected) |
| `SetCaretPosition` | `const AX, AY: Integer` | - | Moves the caret to that column and line (a position outside the range is moved to the nearest position) |
| `SelectLine` | `const ALineIndex: Integer` | - | Selects that line (from 1) |
| `SelectRange` | `const AStartX, AStartY, AEndX, AEndY: Integer` | - | Selects that range (columns and lines from 1) |
| `DuplicateCurrentLine` | - | - | Duplicates the caret line and inserts it below (same as Shift+F10) |
| `ToggleLineNumbers` | - | - | Toggles the display of line numbers (same as F12) |

### 6.3 Search and replace

| Name | Arguments | Return value | Details |
|---|---|---|---|
| `SearchText` | `const ASearchStr: string; ACaseSensitive, AWholeWord, AForward: Boolean` | `Boolean` | Searches and selects. `True` if found. `ACaseSensitive`: distinguish uppercase and lowercase. `AWholeWord`: whole words. `AForward`: `True` searches downward, `False` upward |
| `ReplaceText` | `const ASearchStr, AReplaceStr: string; ACaseSensitive, AWholeWord: Boolean` | `Boolean` | Replaces the next match found. `True` if replaced |
| `ReplaceAllText` | `const ASearchStr, AReplaceStr: string; ACaseSensitive, AWholeWord: Boolean` | `Integer` | Replaces all in the whole text and returns the number replaced |

### 6.4 For use by inheritance (protected)

| Name | Arguments | Return value | Details |
|---|---|---|---|
| `ApplyEditStyle` | - | - | Applies the colors of the current `EditStyle` to the body text, the left-edge column, the caret line, and the color-coding (virtual). An inheriting component can override it and add colors after `inherited` (9.11) |

## 7. Events

### 7.1 Added in this component

| Name | Arguments | Details |
|---|---|---|
| `OnTextChange` | `Sender: TObject; const AText: string` | The state of the body text, caret, selection, and so on changed. `AText` is the whole body text (for linking with a preview) |
| `OnFileNameChangeEvent` | `Sender: TObject; var sFileName: String` | `FileName` changed. If you change `sFileName`, that value becomes `FileName` |
| `OnLoadFromFileEvent` | `Sender: TObject; var sFileName: String` | `LoadFromFile` finished. If you change `sFileName`, that value becomes `FileName` |
| `OnSaveToFileEvent` | `Sender: TObject; var sFileName: String` | `SaveToFile` or `Save` finished. If you change `sFileName`, that value becomes `FileName` |
| `OnInsModeChangeEvent` | `Sender: TObject; var bMode: Boolean` | Insert/overwrite was switched (including by the Insert key). `bMode` is `True` for insert. If changed, it goes to that state |
| `OnCaretChangeEvent` | `Sender: TObject; var iX, iY: Integer` | The caret moved. `iX` is the column, `iY` is the line. If changed, the caret moves to that position |
| `OnUndoRedoStateChangeEvent` | `Sender: TObject; var bCanUndo, bCanRedo: Boolean` | Whether undo/redo is possible changed (changing the arguments is not reflected in the component) |
| `OnModifiedChangeEvent` | `Sender: TObject; var bModified: Boolean` | Modified / not modified was switched. If you change `bModified`, that value becomes `Modified` |
| `OnSelectionChangeEvent` | `Sender: TObject; var sSelText: String; var iStartX, iStartY, iEndX, iEndY: Integer` | The selected string changed (changing the arguments is not reflected in the component) |
| `OnFocusChangeEvent` | `Sender: TObject; var bFocused: Boolean` | Focus changed. `bFocused` is `True` when gained and `False` when lost (changing the argument is not reflected in the component) |
| `OnDropFilesEvent` | `Sender: TObject; const AFiles: array of string` | Files were dropped. `AFiles` holds full paths. If this is set, only the event is raised and the file is not opened (when it is not set, the first file is opened with `LoadFromFile`) |

### 7.2 Inherited from TSynEdit

| Name | Arguments | Details |
|---|---|---|
| `OnChange` | `Sender: TObject` | The body text changed |
| `OnChangeUpdating` | `ASender: TObject; AnUpdating: Boolean` | A batch of changes started or ended |
| `OnClearBookmark` | `Sender: TObject; var Mark: TSynEditMark` | Before a bookmark is cleared |
| `OnClick` | `Sender: TObject` | Clicked |
| `OnClickLink` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A link was clicked |
| `OnCommandProcessed` | `Sender: TObject; var Command: TSynEditorCommand; var AChar: TUTF8Char; Data: Pointer` | After an editing command was executed |
| `OnContextPopup` | `Sender: TObject; MousePos: TPoint; var Handled: Boolean` | Just before the right-click menu is shown. `Handled := True` prevents it from being shown |
| `OnCutCopy` | `Sender: TObject; var AText: String; var AMode: TSynSelectionMode; ALogStartPos: TPoint; var AnAction: TSynCopyPasteAction` | Before cut or copy. `AText` can be changed |
| `OnDblClick` | `Sender: TObject` | Double-clicked |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | Dropped by an LCL drag (between components inside the application) |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | During an LCL drag, the dragged object came over it. `Accept` decides whether to accept it |
| `OnEndDock` | `Sender, Target: TObject; X, Y: Integer` | Docking ended |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | An LCL drag ended |
| `OnEnter` | `Sender: TObject` | Focus entered |
| `OnExit` | `Sender: TObject` | Focus left |
| `OnGutterClick` | `Sender: TObject; X, Y, Line: Integer; Mark: TSynEditMark` | The left-edge column was clicked |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A key was pressed |
| `OnKeyPress` | `Sender: TObject; var Key: Char` | A character key was pressed |
| `OnKeyUp` | `Sender: TObject; var Key: Word; Shift: TShiftState` | A key was released |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was pressed |
| `OnMouseEnter` | `Sender: TObject` | The mouse entered |
| `OnMouseLeave` | `Sender: TObject` | The mouse left |
| `OnMouseLink` | `Sender: TObject; X, Y: Integer; var AllowMouseLink: Boolean` | When deciding whether the text under the mouse is a link |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | The mouse moved |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was released |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | The wheel was turned |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned toward you |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned away from you |
| `OnPaint` | `Sender: TObject; ACanvas: TCanvas` | After painting |
| `OnPaste` | `Sender: TObject; var AText: String; var AMode: TSynSelectionMode; ALogStartPos: TPoint; var AnAction: TSynCopyPasteAction` | Before pasting. `AText` can be changed |
| `OnPlaceBookmark` | `Sender: TObject; var Mark: TSynEditMark` | Before a bookmark is placed |
| `OnProcessCommand` | `Sender: TObject; var Command: TSynEditorCommand; var AChar: TUTF8Char; Data: Pointer` | Before an editing command is executed. `Command` can be changed |
| `OnProcessUserCommand` | `Sender: TObject; var Command: TSynEditorCommand; var AChar: TUTF8Char; Data: Pointer` | When executing a command defined by the application |
| `OnQuadClick` | `Sender: TObject` | Clicked four times in a row |
| `OnReplaceText` | `Sender: TObject; const ASearch, AReplace: string; Line, Column: Integer; var ReplaceAction: TSynReplaceAction` | When deciding whether to replace |
| `OnResize` | `Sender: TObject` | The size changed |
| `OnShowHint` | `Sender: TObject; HintInfo: PHintInfo` | Just before a hint is shown |
| `OnSpecialLineMarkup` | `Sender: TObject; Line: Integer; var Special: Boolean; Markup: TSynSelectedColor` | When deciding whether to give a line a special color |
| `OnStartDock` | `Sender: TObject; var DragObject: TDragDockObject` | A docking drag started |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | An LCL drag started |
| `OnStatusChange` | `Sender: TObject; Changes: TSynStatusChanges` | The state such as caret, selection, modified, or insert/overwrite changed |
| `OnTripleClick` | `Sender: TObject` | Clicked three times in a row |
| `OnUTF8KeyPress` | `Sender: TObject; var UTF8Key: TUTF8Char` | A character key was pressed (one UTF-8 character) |

- Keys used by the component (Ctrl+S, Shift+F10, F12) are handled before this component's `OnKeyDown`. Therefore they cannot be stopped in this component's `OnKeyDown`. To stop them, set the form's `KeyPreview` to `True` and set `Key := 0` in the form's `OnKeyDown`.

## 8. Operations

### 8.1 Keys

| Key | Action |
|---|---|
| Ctrl+S | Save (overwrite) (`Save`) |
| Shift+F10 | Duplicate the caret line |
| F12 | Show / hide line numbers |

Other keys are the same as in TSynEdit.

### 8.2 Mouse

| Operation | Action |
|---|---|
| Ctrl+wheel up | Make the characters larger (up to 72 pt) |
| Ctrl+wheel down | Make the characters smaller (down to 6 pt) |
| Drop a file | Open it (when `OnDropFilesEvent` is set, only the event is raised) |

### 8.3 Right-click menu

| Group | Item | Action | Available when |
|---|---|---|---|
| 1 | `切り抜き` (Cut) | Cut the selected string | Something is selected |
| 1 | `コピー` (Copy) | Copy the selected string | Something is selected |
| 1 | `貼り付け` (Paste) | Paste | The clipboard contains text |
| 2 | `引用付きコピー` (Copy with quote) | Copy with "> " added to the start of each line | Something is selected |
| 2 | `追加切り抜き` (Append cut) | Append to the end of the clipboard and cut | Something is selected |
| 2 | `追加コピー` (Append copy) | Append to the end of the clipboard and copy | Something is selected |
| 3 | `削除` (Delete) | Delete the selected string | Something is selected |
| 4 | TO UPPER CASE | Convert to uppercase | Something is selected |
| 4 | to lower case | Convert to lowercase | Something is selected |
| 5 | `ハンカクに変換` (Convert to half-width) | Convert full-width alphanumerics, symbols, and spaces to half-width (full-width katakana is not changed) | Something is selected |
| 5 | `全角ひらがなに変換` (Convert to full-width hiragana) | Convert katakana to hiragana | Something is selected |
| 5 | `全角カタカナに変換` (Convert to full-width katakana) | Convert hiragana to katakana | Something is selected |
| 6 | `TAB -> 空白 変換` (TAB -> space conversion) | Convert tabs to spaces (`TabWidth` of them) | Something is selected |
| 6 | `空白 -> TAB 変換` (space -> TAB conversion) | Convert spaces (`TabWidth` of them) to a tab | Something is selected |
| 7 | `インデント` (Indent) | Indent the selected lines | Always |
| 7 | `逆インデント` (Unindent) | Undo the indentation of the selected lines | Always |

## 9. Usage examples

### 9.1 Opening and saving a file

```pascal
procedure TForm1.btnOpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    CSynEdit1.LoadFromFile(OpenDialog1.FileName);
end;

procedure TForm1.btnSaveAsClick(Sender: TObject);
begin
  SaveDialog1.FileName := CSynEdit1.FileName;
  if SaveDialog1.Execute then
    CSynEdit1.SaveToFile(SaveDialog1.FileName);
end;
```

### 9.2 Showing the file name and modified state in the title

```pascal
procedure TForm1.CSynEdit1FileNameChangeEvent(Sender: TObject; var sFileName: String);
begin
  Caption := CSynEdit1.DisplayTitle;
end;

procedure TForm1.CSynEdit1ModifiedChangeEvent(Sender: TObject; var bModified: Boolean);
begin
  if bModified then
    Caption := '* ' + CSynEdit1.DisplayTitle
  else
    Caption := CSynEdit1.DisplayTitle;
end;
```

### 9.3 Showing the caret position and insert/overwrite in the status bar

```pascal
procedure TForm1.CSynEdit1CaretChangeEvent(Sender: TObject; var iX, iY: Integer);
begin
  StatusBar1.Panels[0].Text := Format('Line %d, Col %d', [iY, iX]);
end;

procedure TForm1.CSynEdit1InsModeChangeEvent(Sender: TObject; var bMode: Boolean);
begin
  if bMode then
    StatusBar1.Panels[1].Text := 'Insert'
  else
    StatusBar1.Panels[1].Text := 'Overwrite';
end;
```

### 9.4 Enabling and disabling the undo/redo buttons

```pascal
procedure TForm1.CSynEdit1UndoRedoStateChangeEvent(Sender: TObject;
  var bCanUndo, bCanRedo: Boolean);
begin
  btnUndo.Enabled := bCanUndo;
  btnRedo.Enabled := bCanRedo;
end;

procedure TForm1.btnUndoClick(Sender: TObject);
begin
  CSynEdit1.Undo;
end;

procedure TForm1.btnRedoClick(Sender: TObject);
begin
  CSynEdit1.Redo;
end;
```

### 9.5 Searching and replacing

```pascal
procedure TForm1.btnFindClick(Sender: TObject);
begin
  if not CSynEdit1.SearchText(Edit1.Text, False, False, True) then
    ShowMessage('Not found');
end;

procedure TForm1.btnReplaceAllClick(Sender: TObject);
var
  N: Integer;
begin
  N := CSynEdit1.ReplaceAllText(Edit1.Text, Edit2.Text, False, False);
  ShowMessage(IntToStr(N) + ' replaced');
end;
```

### 9.6 Inserting text at the caret and selecting a line

```pascal
CSynEdit1.InsertTextAtCaret(FormatDateTime('yyyy/mm/dd', Now));   // insert today's date
CSynEdit1.SetCaretPosition(1, 10);                                // to the start of line 10
CSynEdit1.SelectLine(10);                                         // select line 10
```

### 9.7 Opening dropped files yourself

```pascal
procedure TForm1.CSynEdit1DropFilesEvent(Sender: TObject; const AFiles: array of string);
var
  i: Integer;
begin
  // When this event is set, the component does not open the file
  for i := 0 to High(AFiles) do
    ListBox1.Items.Add(AFiles[i]);       // add the dropped files to the list
  if Length(AFiles) > 0 then
    CSynEdit1.LoadFromFile(AFiles[0]);   // open the first file
end;
```

### 9.8 Matching the color scheme to the Windows theme

```pascal
CSynEdit1.EditStyle := csThema;   // use in combination with MetaDarkStyle or the like
```

### 9.9 Using the same dark color scheme as VS Code

```pascal
CSynEdit1.EditStyle := csVSDark;
```

### 9.10 Deciding the language regardless of the extension

```pascal
CSynEdit1.Text := '# Heading' + LineEnding + 'Body';
CSynEdit1.Language := 'markdown';                       // use Markdown color-coding

Label1.Caption := CSLanguageForFile('C:.py', 'plaintext');   // 'python'
```

- If `FileName` is set later, the language changes to that of its extension.

### 9.11 Inheriting to add colors to the color scheme

```pascal
type
  TMySynEdit = class(TCSynEdit)
  protected
    procedure ApplyEditStyle; override;
  end;

procedure TMySynEdit.ApplyEditStyle;
begin
  inherited ApplyEditStyle;                 // apply the component's color scheme
  if EditStyle = csVSDark then
    LineHighlightColor.Background := RGBToColor($30, $30, $30);   // change only the caret line color
end;
```

### 9.12 Creating it in code

```pascal
uses
  cSynEdit;

procedure TForm1.FormCreate(Sender: TObject);
var
  E: TCSynEdit;
begin
  E := TCSynEdit.Create(Self);
  E.Parent := Self;
  E.Align := alClient;
  E.EditStyle := csWhite;
  E.OnFileNameChangeEvent := @CSynEdit1FileNameChangeEvent;   // use the handler from 9.2
end;
```
