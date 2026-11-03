# TCSynEdit Design Document

Author: aotan083
Date: 2026-10-31
Version: 1.1

---

## 1. Purpose

Build a text editor based on TSynEdit, with the following added.

- File reading and writing (a file that has been read or written is held so that other applications cannot write to it).
- Switching of color schemes (`EditStyle`). It has the same color schemes as VS Code (TCMonacoEditor), `csVSLight` and `csVSDark`.
- Switching of the color-coding (highlighter) according to the language (`Language`). The mapping between extensions and languages is the same as in TCMonacoEditor.
- Markdown color-coding (the custom `TCSynMarkdownSyn`).
- A right-click menu similar to that of the Hidemaru editor.
- Events that report state changes (file name, insert/overwrite, caret, undo/redo, modified, selection, focus).
- File drop, and the operations Ctrl+S, Shift+F10, F12, and Ctrl+wheel.

**Operating environment**: Lazarus 5.0 or later (tested with 5.0 RC1). For Lazarus 4.8, we only make sure the cx package compiles; operation is not verified or tested (defects found on 4.8 are not fixed). There is no version-specific code (it is written with the 4.8 names and compiles unchanged on 5.0). On 5.0, `TSynHighlighterAttributes`, `TSynCustomHighlighter`, `SYN_ATTR_...`, `SetLine`, `SetRange` and so on produce "old style" warnings, but behavior is the same (they are scheduled to be removed in Lazarus 5.99; they will be rewritten then).

TCsEditor (`TCsEditor_Design.md`) holds one of this component per tab. What TCsEditor uses are the color schemes `csVSLight` and `csVSDark`, `Language`, `ApplyEditStyle` (inherited to add colors), and `CSLanguageForFile`.

## 2. Files and packages

| File | Package | Contents |
|---|---|---|
| `cSynedit.pas` (unit name `csynedit`) | cx (runtime) | Types, `TCSynEdit`, `TCSynMarkdownSyn`, function `CSLanguageForFile` |
| `uCXReg.pas` | cxdsgn (design time) | Registration on the [CX] palette (`RegisterComponents('CX', [..., TCSynEdit, ...])`). Write `cSynEdit` in uses |
| `cx_icons.lrs` | cxdsgn (design time) | Icons (`TCSynEdit`, `TCSynEdit_150`, `TCSynEdit_200`) |

- interface uses: `Classes, SysUtils, Graphics, Menus, LCLType, LCLIntf, Clipbrd, LazUTF8, Math, SynEdit, SynEditKeyCmds, SynEditHighlighter, SynEditTypes, SynGutterLineNumber, SynGutterCodeFolding, SynGutterChanges, SynEditMarkup, SynEditMarkupWordGroup, SynEditMarkupHighAll, SynHighlighterPas, SynHighlighterHTML, SynHighlighterXML, SynHighlighterCss, SynHighlighterJScript, SynHighlighterSQL, SynHighlighterIni, SynHighlighterBat, SynHighlighterPython, SynHighlighterCpp, SynHighlighterJava, SynHighlighterUNIXShellScript, SynHighlighterPHP, Registry`
- implementation uses: `TypInfo, StrUtils`, and `Windows, ShellAPI` on Windows only
- The cx package requires SynEdit (unchanged).
- There is no initialization or finalization.

## 3. Types

```pascal
TCEditStyle = (csBlack, csGray, csWhite, csThema, csVSLight, csVSDark);
TCFileEncoding = (feUTF8, feANSI_SJIS, feUTF16LE, feUTF16BE, feEUCJP);
TCLineEnding = (leCRLF, leLF, leCR);
TCSynTextChangeEvent = procedure(Sender: TObject; const AText: string) of object;
TOnFileNameChangeEvent = procedure(Sender: TObject; var sFileName: String) of object;
TOnLoadFromFileEvent = procedure(Sender: TObject; var sFileName: String) of object;
TOnSaveToFileEvent = procedure(Sender: TObject; var sFileName: String) of object;
TOnInsModeChangeEvent = procedure(Sender: TObject; var bMode: Boolean) of object;
TOnCaretChangeEvent = procedure(Sender: TObject; var iX, iY: Integer) of object;
TOnUndoRedoStateChangeEvent = procedure(Sender: TObject; var bCanUndo, bCanRedo: Boolean) of object;
TOnModifiedChangeEvent = procedure(Sender: TObject; var bModified: Boolean) of object;
TOnSelectionChangeEvent = procedure(Sender: TObject; var sSelText: String; var iStartX, iStartY, iEndX, iEndY: Integer) of object;
TOnFocusChangeEvent = procedure(Sender: TObject; var bFocused: Boolean) of object;
TOnDropFilesEvent = procedure(Sender: TObject; const AFiles: array of string) of object;

TCSynMarkdownSyn = class(TSynCustomHighlighter)   // Chapter 9
TCSynEdit = class(TSynEdit)

function CSLanguageForFile(const AFileName, ADefault: string): string;
```

- `csVSLight` and `csVSDark` are added at the end (they are saved by name in the .lfm, so reordering would not break existing .lfm files, but to be safe the order of the existing four is not changed).

**CSLanguageForFile**

Returns the language name from the extension (compared in lowercase). The table is the same as `LanguageForFile` of TCMonacoEditor (`uCmmonacoview.pas`).

| Extension | Language |
|---|---|
| .pas .pp .lpr .inc .dpr .lpk | pascal |
| .md .markdown | markdown |
| .txt | plaintext |
| .html .htm | html |
| .css | css |
| .js | javascript |
| .json | json |
| .xml | xml |
| .sql | sql |
| .ini .cfg | ini |
| .bat .cmd | bat |
| .py | python |
| .c .h .cpp .hpp | cpp |
| .cs | csharp |
| .ts .tsx | typescript |
| .java | java |
| .sh .bash | shell |
| .ps1 .psm1 .psd1 | powershell |
| .yml .yaml | yaml |
| .php | php |
| .go | go |
| Anything else | `ADefault` |

## 4. Fields

| Name | Type | Contents |
|---|---|---|
| `FFileName` | `string` | File name |
| `FEditStyle` | `TCEditStyle` | Color scheme |
| `FLanguage` | `string` | Current language (7.2). Default 'pascal' |
| `FEncodingType` | `TCFileEncoding` | Holder for the character encoding (not used for reading/writing) |
| `FHasBOM` | `Boolean` | Holder for the presence of a BOM (not used for reading/writing) |
| `FLineEndingType` | `TCLineEnding` | Holder for the line ending (not used for reading/writing) |
| `FOnTextChange` and 11 others | each event type | Events (one-to-one with the published events in 5.1) |
| `FPopupMenu` | `TPopupMenu` | Right-click menu owned by the component |
| `FFileStream` | `TFileStream` | Stream used to hold the file |
| `FLoadingFlag` | `Boolean` | Only set to `False` in `Create` (not used elsewhere) |
| `FOldInsertMode` | `Boolean` | Previous `InsertMode` (to detect changes) |
| `FOldCaretX`, `FOldCaretY` | `Integer` | Previous caret position |
| `FOldCanUndo`, `FOldCanRedo` | `Boolean` | Previous `CanUndo`, `CanRedo` |
| `FOldModified` | `Boolean` | Previous `Modified` |
| `FOldSelText` | `string` | Previous `SelText` |
| `FMenuItemCut` and 13 others | `TMenuItem` | Menu items (to switch whether they are enabled; Chapter 8) |

## 5. Declarations

### 5.1 published

```pascal
property FileName: string read FFileName write SetFileName;
property EditStyle: TCEditStyle read FEditStyle write SetEditStyle default csGray;
property InsMode: Boolean read GetInsModeValue write SetInsModeValue default True;
property EncodingType: TCFileEncoding read FEncodingType write FEncodingType default feUTF8;
property HasBOM: Boolean read FHasBOM write FHasBOM default False;
property LineEndingType: TCLineEnding read FLineEndingType write FLineEndingType default leCRLF;
property CaretY: Integer read GetCaretYValue write SetCaretYValue;
property CaretX: Integer read GetCaretXValue write SetCaretXValue;
property OnTextChange: TCSynTextChangeEvent read FOnTextChange write FOnTextChange;
property OnFileNameChangeEvent: TOnFileNameChangeEvent read FOnFileNameChange write FOnFileNameChange;
property OnLoadFromFileEvent: TOnLoadFromFileEvent read FOnLoadFromFile write FOnLoadFromFile;
property OnSaveToFileEvent: TOnSaveToFileEvent read FOnSaveToFile write FOnSaveToFile;
property OnInsModeChangeEvent: TOnInsModeChangeEvent read FOnInsModeChange write FOnInsModeChange;
property OnCaretChangeEvent: TOnCaretChangeEvent read FOnCaretChange write FOnCaretChange;
property OnUndoRedoStateChangeEvent: TOnUndoRedoStateChangeEvent read FOnUndoRedoStateChange write FOnUndoRedoStateChange;
property OnModifiedChangeEvent: TOnModifiedChangeEvent read FOnModifiedChange write FOnModifiedChange;
property OnSelectionChangeEvent: TOnSelectionChangeEvent read FOnSelectionChange write FOnSelectionChange;
property OnFocusChangeEvent: TOnFocusChangeEvent read FOnFocusChange write FOnFocusChange;
property OnDropFilesEvent: TOnDropFilesEvent read FOnDropFiles write FOnDropFiles;
```

- `CaretX` and `CaretY` just read and write the parent's `CaretX` and `CaretY` via `inherited` (so that they appear in the Object Inspector).
- The getter of `InsMode` returns `InsertMode`.

### 5.2 public

```pascal
constructor Create(AOwner: TComponent); override;
destructor Destroy; override;
procedure LoadFromFile(const AFileName: string);
procedure SaveToFile(const AFileName: string);
procedure Save;
procedure DuplicateCurrentLine;
procedure ToggleLineNumbers;
procedure InsertTextAtCaret(const AText: string);
procedure ReplaceSelection(const AText: string);
procedure SetCaretPosition(const AX, AY: Integer);
procedure SelectLine(const ALineIndex: Integer);
procedure SelectRange(const AStartX, AStartY, AEndX, AEndY: Integer);
function SearchText(const ASearchStr: string; ACaseSensitive, AWholeWord, AForward: Boolean): Boolean;
function ReplaceText(const ASearchStr, AReplaceStr: string; ACaseSensitive, AWholeWord: Boolean): Boolean;
function ReplaceAllText(const ASearchStr, AReplaceStr: string; ACaseSensitive, AWholeWord: Boolean): Integer;
property DisplayTitle: string read GetDisplayTitle;
property Language: string read FLanguage write SetLanguage;     // 7.2
```

- `Language` is public (it is not saved in the .lfm; it is determined by the file name or by code).

### 5.3 protected

```pascal
procedure ApplyEditStyle; virtual;          // private in 1.0. Made protected virtual so that inheriting components (the component inside TCsEditor) can add colors
procedure OnFileNameChange(var sFileName: String); virtual;
procedure OnLoadFromFile(var sFileName: String); virtual;
procedure OnSaveToFile(var sFileName: String); virtual;
procedure OnInsModeChange(var bMode: Boolean); virtual;
procedure OnCaretChange(var iX, iY: Integer); virtual;
procedure OnUndoRedoStateChange(var bCanUndo, bCanRedo: Boolean); virtual;
procedure OnModifiedChange(var bModified: Boolean); virtual;
procedure OnSelectionChange(var sSelText: String; var iStartX, iStartY, iEndX, iEndY: Integer); virtual;
procedure OnFocusChange(var bFocused: Boolean); virtual;
procedure DoEnter; override;
procedure DoExit; override;
procedure StatusChanged(AChanges: TSynStatusChanges); override;
procedure KeyDown(var Key: Word; Shift: TShiftState); override;
function DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean; override;
function DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean; override;
procedure CreateWnd; override;
procedure DestroyWnd; override;
procedure DoDropFiles(const AFiles: array of string); virtual;
procedure Loaded; override;
```

The nine procedures from `OnFileNameChange` to `OnFocusChange` just call the corresponding event if one is assigned.

## 6. Create and Destroy

Create:

1. `inherited Create`, `FLoadingFlag := False`.
2. `Font.Name := 'BIZ UDGothic'`, `Font.Size := 12`, `Font.Quality := fqCleartypeNatural`.
3. `FFileName := ExtractFilePath(ParamStr(0)) + '無題.txt'`.
4. `InsertMode := True`, `FOldInsertMode := True`, `FOldCaretX := 1`, `FOldCaretY := 1`, `FOldCanUndo := False`, `FOldCanRedo := False`, `FOldModified := False`, `FOldSelText := ''`, `FFileStream := nil`.
5. `FEditStyle := csGray` (the color scheme is not applied here. It is applied in `Loaded`, `SetEditStyle`, and `SetLanguage`).
6. `FLanguage := 'pascal'`, `Highlighter := TSynPasSyn.Create(Self)`.
7. `FEncodingType := feUTF8`, `FHasBOM := False`, `FLineEndingType := leCRLF`.
8. `CreateHidemaruLikePopupMenu`, `PopupMenu := FPopupMenu`.

Destroy: `UnlockFile`, `FreeAndNil(FPopupMenu)`, `inherited`.

Loaded: `inherited`, then `ApplyEditStyle` (the color scheme is decided after loading has finished).

## 7. Processing

### 7.1 File name

`SetFileName(v)`: only when the value changes, `FFileName := v`, `OnFileNameChange(FFileName)` (changing `sFileName` inside the event changes `FFileName`, because it is passed as var), `AutoSelectHighlighter(FFileName)`.

`GetDisplayTitle`: if `FFileName` is not empty, `ExtractFileName(FFileName)`; if empty, `'無題.txt'`.

`AutoSelectHighlighter(APath)`:

1. If the extension is '' (no extension), `Language := 'pascal'`.
2. Otherwise `L := CSLanguageForFile(APath, '')`. If `L <> ''`, `Language := L`. If `L = ''` (an extension not in the table), do nothing (the previous color-coding remains).

### 7.2 Language and color-coding (SetLanguage)

`SetLanguage(v)`:

1. `v := LowerCase(v)`.
2. Decide the highlighter class to use from the language (table below).
3. If the current `Highlighter` is exactly that class (`Highlighter.ClassType = the decided class`), do not recreate it. Otherwise:
   - If the current `Highlighter` was created by the component itself (`Highlighter.Owner = Self`), do `H := Highlighter`, `Highlighter := nil`, `H.Free`. One put in by the application (Owner is not the component) is not freed.
   - If the class is nil (no color-coding), `Highlighter := nil`. Otherwise `Highlighter := class.Create(Self)`.
   - Also free any highlighter the component created itself (a `TSynCustomHighlighter` in `Components`) that is not the current `Highlighter` (one that was left over after being detached when the application put in its own highlighter).
4. `FLanguage := v`.
5. `ApplyEditStyle` (so that the color scheme is kept even when the highlighter is swapped).

| Language | Highlighter class |
|---|---|
| pascal | `TSynPasSyn` |
| markdown | `TCSynMarkdownSyn` (Chapter 9) |
| html | `TSynHTMLSyn` |
| css | `TSynCssSyn` |
| javascript, json, typescript | `TSynJScriptSyn` |
| xml | `TSynXMLSyn` |
| sql | `TSynSQLSyn` |
| ini | `TSynIniSyn` |
| bat | `TSynBatSyn` |
| python | `TSynPythonSyn` |
| cpp, csharp | `TSynCppSyn` |
| java | `TSynJavaSyn` |
| shell | `TSynUNIXShellScriptSyn` |
| php | `TSynPHPSyn` |
| plaintext, powershell, yaml, go, anything else | nil (no color-coding) |

- In the previous version, every time the highlighter was swapped a new one was created and the old one was left behind (memory grew with every file opened, and the color scheme reverted to the default colors). This version fixes that (Chapter 11, No.2).

### 7.3 Reading and writing files

| Procedure | Processing |
|---|---|
| `LoadFromFile(f)` | `UnlockFile` -> `Lines.LoadFromFile(f)` -> `FileName := f` -> `Modified := False` -> `LockFile(f)` -> `OnLoadFromFile(FFileName)` |
| `SaveToFile(f)` | `UnlockFile` -> `Lines.SaveToFile(f)` -> `FileName := f` -> `Modified := False` -> `LockFile(f)` -> `OnSaveToFile(FFileName)` |
| `Save` | `SaveToFile(FFileName)` |
| `LockFile(f)` | `UnlockFile`. If the file exists, `TFileStream.Create(f, fmOpenRead or fmShareDenyWrite)`. On failure, `FFileStream := nil` (no exception is raised) |
| `UnlockFile` | If `FFileStream` exists, `FreeAndNil` it |

- No character encoding or line ending conversion is done. `EncodingType`, `HasBOM`, and `LineEndingType` are not consulted.
- TCsEditor does not use these three (file reading and writing is done by TCsEditor).

### 7.4 Color scheme (ApplyEditStyle)

Does nothing while `csLoading`. For all color schemes, `Gutter.MarksPart.Visible := False` (the bookmark column is not shown).

Order:

1. Set the colors of the body text, the left gutter, the caret line, and so on using the table in 7.4.1.
2. Decide the "color set" of that color scheme using the table in 7.4.2.
3. As in 7.4.3, set colors on the attributes of the current highlighter (`Highlighter`). If `Highlighter` is nil, do nothing.

#### 7.4.1 Body text and left gutter

The existing four (csThema, csBlack, csGray, csWhite) are as in 1.0. Only `ChangesPart.Visible := True` is added (so that the changed-line marks do not stay hidden when switching back from `csVSLight` or `csVSDark`).

| Item | csThema | csBlack | csGray | csWhite | csVSLight | csVSDark |
|---|---|---|---|---|---|---|
| `Font.Color` | `clWindowText` | `clWhite` | `clWhite` | `clBlack` | #000000 | #D4D4D4 |
| `Color` | `clWindow` | `clBlack` | `clBlack` | `clWhite` | #FFFFFE | #1E1E1E |
| `BorderWidth` | 0 | 0 | unchanged | 0 | 0 | 0 |
| `RightEdge` | 80 | 80 | 80 | 80 | 80 | 80 |
| `RightEdgeColor` | `clWindow` | `clBlack` | `clBlack` | `clWhite` | #FFFFFE | #1E1E1E |
| `SelectedColor` | background `clHighlight`, text `clHighlightText` | unchanged | unchanged | unchanged | background #ADD6FF, text `clNone` | background #264F78, text `clNone` |
| `Gutter.Visible` | `True` | `True` | `True` | `True` | `True` | `True` |
| `Gutter.Color` | `clWindow` | `clBlack` | `clBlack` | `clWhite` | #FFFFFE | #1E1E1E |
| `Gutter.SeparatorPart.Visible` | `False` | `False` | `False` | `False` | `False` | `False` |
| `Gutter.ChangesPart.Visible` | `True` | `True` | `True` | `True` | `False` | `False` |
| Line number background | `clWindow` | `clBlack` | `clBlack` | `clWhite` | #FFFFFE | #1E1E1E |
| Line number text | `clGrayText` | `TColor($3B3B3B)` | `TColor($3B3B3B)` | `TColor($EEEEEE00)` | #237893 | #6E7681 |
| Line number text on the caret line (`LineNumberPart.MarkupInfoCurrentLine`) | unchanged | unchanged | unchanged | unchanged | #0B216F (background `clNone`) | #C6C6C6 (background `clNone`) |
| Line number thinning | unchanged | unchanged | `ShowOnlyLineNumbersMultiplesOf := 5` | unchanged | 1 | 1 |
| Folding column (`CodeFoldPart.MarkupInfo`) | unchanged | unchanged | unchanged | unchanged | background #FFFFFE, mark #424242 | background #1E1E1E, mark #5A5A5A |
| Caret line background | dark: `RGBToColor(38,38,38)`, light: `RGBToColor(242,242,242)` | `TColor($00101010)` | `RGB(2,20,26)` | `TColor($F2F2F2)` | #EAF2FF | #2C313C |
| Caret line text | `clNone` | `clWhite` | `clWhite` | `clBlack` | `clNone` | `clNone` |
| Caret line frame | `clNone` | `clNone` | `clNone` | `clNone` | `clNone` | `clNone` |
| Bracket matching (`BracketMatchColor`) | unchanged | unchanged | unchanged | unchanged | background and text `clNone`, frame #B9B9B9, `Style := []` | background and text `clNone`, frame #888888, `Style := []` |
| Keyword group (`MarkupByClass[TSynEditMarkupWordGroup].MarkupInfo`) | unchanged | unchanged | unchanged | unchanged | same as bracket matching | same as bracket matching |
| Same-word highlight (`MarkupByClass[TSynEditMarkupHighlightAllCaret].MarkupInfo`) | unchanged | unchanged | unchanged | unchanged | background #D5D5D5, text `clNone` | background #474747, text `clNone` |
| Folded region (`FoldedCodeColor`) | unchanged | unchanged | unchanged | unchanged | background and text `clNone`, frame #A0A0A0 | background and text `clNone`, frame #808080 |

- #RRGGBB colors are set with `RGBToColor(R, G, B)` (because TColor is internally in blue-green-red order).
- The right-edge guide line is given the same color as the background so that it is invisible.
- Dark/light for csThema is decided by `IsOSDarkTheme` (dark if `AppsUseLightTheme` under the registry key `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` is 0; light if the value does not exist). Other colors are system colors, leaving the reinterpretation to MetaDarkStyle and the like.
- The values of `csVSLight` and `csVSDark` are the same as TCMonacoEditor (Monaco's `vs` and `vs-dark`). However, for `csVSDark` the line number text (#6E7681, same as current VS Code) and the folding mark (#5A5A5A, close to the Lazarus IDE) are made darker so that they stand out less than the body text. The caret line and selection colors are the same as the TCMonacoEditor defaults (`scStandard` of `CursorLineColor...` and `SelectionColor...`).
- When `MarkupByClass[...]` is nil, do nothing.

#### 7.4.2 Color sets

For each color scheme, the following color set is decided. The existing four are the 1.0 Pascal colors used as they are.

| Color | csThema (dark) | csThema (light) | csBlack | csGray | csWhite | csVSLight | csVSDark |
|---|---|---|---|---|---|---|---|
| Text (`Text`) | `clWindowText` | `clWindowText` | `clWhite` | `clWhite` | `clBlack` | #000000 | #D4D4D4 |
| Reserved word (`Key`) | `RGBToColor(86,156,214)` | `RGBToColor(0,0,255)` | `clWhite` | `clAqua` | `clNavy` | #0000FF | #569CD6 |
| String (`Str`) | `RGBToColor(206,145,120)` | `RGBToColor(163,21,21)` | `clYellow` | `clYellow` | `clBlue` | #A31515 | #CE9178 |
| Comment (`Comment`) | `RGBToColor(106,153,85)` | `RGBToColor(0,128,0)` | `clGray` | `clGreen` | `clGreen` | #008000 | #6A9955 |
| Number (`Number`) | `RGBToColor(181,206,168)` | `RGBToColor(9,134,88)` | `TColor($008080FF)` | `TColor($008080FF)` | `clPurple` | #098658 | #B5CEA8 |
| Symbol (`Symbol`) | same as reserved word | same as reserved word | same as reserved word | same as reserved word | same as reserved word | #000000 | #D4D4D4 |
| Tag (`Tag`) | same as reserved word | same as reserved word | same as reserved word | same as reserved word | same as reserved word | #800000 | #569CD6 |
| Tag mark (`TagMark`) | same as reserved word | same as reserved word | same as reserved word | same as reserved word | same as reserved word | #383838 | #808080 |
| Attribute name (`AttrName`) | same as text | same as text | same as text | same as text | same as text | #FF0000 | #9CDCFE |
| Attribute value (`AttrValue`) | same as string | same as string | same as string | same as string | same as string | #0000FF | #CE9178 |
| Background of each attribute (`Bg`) | `clNone` | `clNone` | `clBlack` | `clBlack` | `clWhite` | `clNone` | `clNone` |

- Giving symbols the same color as reserved words is the 1.0 convention (Pascal `:=`, `;`, and so on). `csVSLight` and `csVSDark` use the same color as text, to match Monaco.

#### 7.4.3 How colors are set on highlighter attributes

**Pascal (`TSynPasSyn`) with the existing four color schemes**: same as 1.0 (table below). Other attributes are not touched.

| Attribute | Color |
|---|---|
| `KeyAttri`, `ModifierAttri`, `SymbolAttri` | `Key` |
| `StringAttri` | `Str` |
| `CommentAttri` | `Comment` |
| `NumberAttri` | `Number` |
| `IdentifierAttri` | `Text` |
| Background of the above seven | `Bg` |
| `KeyAttri.Style`, `CommentAttri.Style`, `ModifierAttri.Style` | `[]` |

**Everything else (a highlighter other than Pascal, or `csVSLight` / `csVSDark`)**: set in the following order.

1. Set all attributes (the `Highlighter.AttrCount` items `Highlighter.Attribute[i]`) to text color `Text`, background `Bg`, and `Style := []` (so that attributes not in the table do not remain in the default colors meant for a white background).
   - However, "overlay attributes" (descendants of `TLazEditTextAttributeModifier` in Lazarus 5.0; descendants of `TSynHighlighterAttributesModifier` in 4.8) get text color, background, and frame set to `clNone` and `Style := []`. Overlay attributes are used laid on top of the color of the underlying attribute (comment, string, and so on), so setting `Text` on them would erase the underlying color (for example, Pascal's `Ansi Comment`, `Curly Comment`, and `Slash Comment` would wipe out the green of `Comment` with white, and `String_Singlequote` and others would wipe out the color of `Str`). With `clNone`, the color of the underlying attribute shows through unchanged.
   - Whether an attribute is an overlay is decided by walking up the class parents and checking whether any has the name `TLazEditTextAttributeModifier` or `TSynHighlighterAttributesModifier` (so that no version-specific code is needed).
2. Set the attributes that every highlighter has (`GetDefaultAttribute(...)`; skip if nil). `GetDefaultAttribute` is protected in the base class of highlighters, so place in the implementation a class that merely inherits, `THlAccess = class(TSynCustomHighlighter)`, and call `THlAccess(Highlighter).GetDefaultAttribute(...)`. The type of the `Highlighter` property is `TLazEditCustomHighlighter` in 5.0, so the attribute list (`AttrCount`, `Attribute[i]`) is also read after casting to `TSynCustomHighlighter(Highlighter)`.

| Attribute | Color |
|---|---|
| `SYN_ATTR_COMMENT` | `Comment` |
| `SYN_ATTR_IDENTIFIER` | `Text` |
| `SYN_ATTR_KEYWORD` | `Key` |
| `SYN_ATTR_STRING` | `Str` |
| `SYN_ATTR_SYMBOL` | `Symbol` |
| `SYN_ATTR_NUMBER` | `Number` |
| `SYN_ATTR_DIRECTIVE` | `Comment` (Monaco shows Pascal's `{$...}` in the comment color) |
| `NumberAttri` (a published attribute; look it up by name with `IsPublishedProp` and `GetObjectProp`) | `Number` (because many 5.0 highlighters do not return numbers as `SYN_ATTR_NUMBER`) |

3. Set the per-highlighter attributes (table below).

| Highlighter | Attribute | Color |
|---|---|---|
| `TSynPasSyn` | `ModifierAttri` | `Key` |
| `TSynHTMLSyn` | `KeyAttri`, `UndefKeyAttri`, `DOCTYPEAttri` | `Tag` |
| `TSynHTMLSyn` | `IdentifierAttri` | `AttrName` |
| `TSynHTMLSyn` | `ValueAttri` | `AttrValue` |
| `TSynHTMLSyn` | `SymbolAttri` | `TagMark` |
| `TSynHTMLSyn` | `AndAttri` | `Key` |
| `TSynHTMLSyn` | `TextAttri` | `Text` |
| `TSynXMLSyn` | `ElementAttri`, `ProcessingInstructionAttri`, `DocTypeAttri` | `Tag` |
| `TSynXMLSyn` | `AttributeAttri`, `NamespaceAttributeAttri` | `AttrName` |
| `TSynXMLSyn` | `AttributeValueAttri`, `NamespaceAttributeValueAttri` | `AttrValue` |
| `TSynXMLSyn` | `SymbolAttri` | `TagMark` |
| `TSynXMLSyn` | `CDATAAttri` | `Str` |
| `TSynXMLSyn` | `EntityRefAttri` | `Key` |
| `TSynCssSyn` | `SelectorAttri` | `Tag` |
| `TSynCssSyn` | `KeyAttri` (property names) | `AttrName` |
| `TCSynMarkdownSyn` | Table in 9.3 | Table in 9.3 |

- Attribute names follow the SynEdit source of Lazarus 5.0 RC1 (verify by compiling). If a name differs, set the attribute with the same meaning.

`SetEditStyle(v)`: only when the value changes, `FEditStyle := v`, `ApplyEditStyle`.

### 7.5 Insert / overwrite (SetInsModeValue)

Only when the value changes: `InsertMode := v`, `FOldInsertMode := InsertMode`, `CurMode := InsertMode`, `OnInsModeChange(CurMode)`. If `CurMode` was changed by the event, set `InsertMode` and `FOldInsertMode` to that value.

### 7.6 State changes (StatusChanged)

After `inherited StatusChanged(AChanges)`, check in the following order.

| Order | Condition | Processing |
|---|---|---|
| 1 | `AChanges <> []` | `FOnTextChange(Self, Text)` |
| 2 | `FOldInsertMode <> InsertMode` | Update `FOldInsertMode` and call `OnInsModeChange(CurMode)`. If changed, set `InsertMode` and `FOldInsertMode` |
| 3 | Caret position differs from before | `OnCaretChange(CurX, CurY)`. If changed, set `CaretX` and `CaretY`. Set `FOldCaretX` and `FOldCaretY` to `CurX` and `CurY` |
| 4 | `CanUndo` or `CanRedo` differs from before | `OnUndoRedoStateChange(CurCanUndo, CurCanRedo)`. Remember `CurCanUndo` and `CurCanRedo` as the previous values (they are not put into the component) |
| 5 | `Modified` differs from before | `OnModifiedChange(CurModified)`. If changed, set `Modified`. `FOldModified := Modified` |
| 6 | `SelText` differs from before | `FOldSelText := SelText`. `OnSelectionChange(SelText, BlockBegin.X, BlockBegin.Y, BlockEnd.X, BlockEnd.Y)` (not written back to the component) |

### 7.7 Focus

`DoEnter`: `inherited`, then `OnFocusChange(True)`. `DoExit`: `inherited`, then `OnFocusChange(False)` (both pass through a variable, and the return value is not used).

### 7.8 Keys (KeyDown)

| Key | Processing |
|---|---|
| Ctrl+S | `Save`, `Key := 0`, exit |
| Shift+F10 | `DuplicateCurrentLine`, `Key := 0`, exit |
| F12 (without Shift) | `ToggleLineNumbers`, `Key := 0`, exit |
| Others | `inherited KeyDown` |

- These three are handled before `inherited KeyDown` (in which `OnKeyDown` is called). Therefore they cannot be stopped in this component's `OnKeyDown`. To stop them, set the form's `KeyPreview = True` and set `Key := 0` in the form's `OnKeyDown` (the note in User Manual 7.2 is corrected to this form).
- TCsEditor receives keys first in `KeyDown` of the inherited component, so it never reaches the handling of these three (`TCsEditor_Design.md` 6.2).

### 7.9 Wheel

- `DoMouseWheelDown`: if Ctrl is held, decrease `Font.Size` by 1 if `Font.Size > 6`, and return `True`. Otherwise `inherited`.
- `DoMouseWheelUp`: if Ctrl is held, increase `Font.Size` by 1 if `Font.Size < 72`, and return `True`. Otherwise `inherited`.

### 7.10 Drop (Windows only)

- `CreateWnd`: `inherited`, then `DragAcceptFiles(Handle, True)`, `SetWindowSubclass(Handle, @DropSubclassProc, DROP_SUBCLASS_ID, DWORD_PTR(Self))` (`DROP_SUBCLASS_ID = 1`).
- `DestroyWnd`: if there is a handle, `RemoveWindowSubclass` and `DragAcceptFiles(Handle, False)`, then `inherited`.
- `SetWindowSubclass`, `RemoveWindowSubclass`, and `DefSubclassProc` are declared as external from `comctl32.dll`.
- `DropSubclassProc`: for `WM_DROPFILES`, get the count and each file name (UTF-16) with `DragQueryFileW`, convert them to an array of strings with `UTF8Encode`, `DragFinish`, `TCSynEdit(dwRefData).DoDropFiles(Files)`, and return 0. For `WM_NCDESTROY`, `RemoveWindowSubclass`. Otherwise `DefSubclassProc`.
- `DoDropFiles(AFiles)`: exit if empty. If `FOnDropFiles` is assigned, call it. Otherwise `LoadFromFile(AFiles[0])`.

### 7.11 Editing

| Procedure | Processing |
|---|---|
| `DuplicateCurrentLine` | Remember the caret position; if `1 <= CaretY <= Lines.Count`, `Lines.Insert(CaretY, Lines[CaretY - 1])`, and restore the caret |
| `ToggleLineNumbers` | Invert `Gutter.LineNumberPart.Visible` and set `Gutter.Visible := True` (the gutter itself is always shown) |
| `InsertTextAtCaret(s)` | If `s` is not empty, `inherited InsertTextAtCaret(s)` |
| `ReplaceSelection(s)` | `SelText := s` |
| `SetCaretPosition(x, y)` | If the line count is 0, `y := 1`; otherwise `EnsureRange(y, 1, Lines.Count)`. The column is `EnsureRange(x, 1, line length + 1)` (1 if there is no line). Assign to `CaretX` and `CaretY` |
| `SelectLine(n)` | Exit if the line count is 0. Clamp `n` to `1..Lines.Count`, `BlockBegin := (1, n)`, `BlockEnd := (line length + 1, n)` |
| `SelectRange(x1, y1, x2, y2)` | Exit if the line count is 0. Clamp lines to `1..Lines.Count` and columns to `1..line length + 1`, and assign to `BlockBegin` and `BlockEnd` |

### 7.12 Search and replace

All of them do nothing and return `False` or 0 if the search string is empty. They use `SearchReplace`.

| Procedure | Options | Return value |
|---|---|---|
| `SearchText` | `ACaseSensitive` -> `ssoMatchCase`, `AWholeWord` -> `ssoWholeWord`, `not AForward` -> `ssoBackwards` | `SearchReplace(s, '', opt) > 0` |
| `ReplaceText` | `ssoReplace` + the same case/word options as above | `SearchReplace(s, r, opt) > 0` |
| `ReplaceAllText` | `ssoReplace, ssoReplaceAll, ssoEntireScope` + the same as above | The value of `SearchReplace(s, r, opt)` (the number of replacements) |

## 8. Right-click menu

`CreateHidemaruLikePopupMenu`: free `FPopupMenu` if it exists, and create it with `TPopupMenu.Create(Self)`. `OnPopup := OnPopupMenuPopup`. The items are in the following order (a separator `'-'` between groups).

| Group | Caption | Processing | Field |
|---|---|---|---|
| 1 | `切り抜き` (Cut) | `CutToClipboard` | `FMenuItemCut` |
| 1 | `コピー` (Copy) | `CopyToClipboard` | `FMenuItemCopy` |
| 1 | `貼り付け` (Paste) | `PasteFromClipboard` | `FMenuItemPaste` |
| 2 | `引用付きコピー` (Copy with quote) | Split the selection into lines, prefix each line with `'> '`, and put it in `Clipboard.AsText` | `FMenuItemQuoteCopy` |
| 2 | `追加切り抜き` (Append cut) | `Clipboard.AsText := current clipboard + SelText`, `ClearSelection` | `FMenuItemAppendCut` |
| 2 | `追加コピー` (Append copy) | `Clipboard.AsText := current clipboard + SelText` | `FMenuItemAppendCopy` |
| 3 | `削除` (Delete) | `ClearSelection` | `FMenuItemDelete` |
| 4 | TO UPPER CASE | `SelText := UpperCase(SelText)` | `FMenuItemUpperCase` |
| 4 | to lower case | `SelText := LowerCase(SelText)` | `FMenuItemLowerCase` |
| 5 | `ハンカクに変換` (Convert to half-width) | Convert to UTF-16, apply `- $FEE0` to U+FF01 to U+FF5E, and turn U+3000 into a space | `FMenuItemToHalf` |
| 5 | `全角ひらがなに変換` (Convert to full-width hiragana) | Convert to UTF-16, apply `- $60` to U+30A1 to U+30F6 | `FMenuItemToHiragana` |
| 5 | `全角カタカナに変換` (Convert to full-width katakana) | Convert to UTF-16, apply `+ $60` to U+3041 to U+3096 | `FMenuItemToKatakana` |
| 6 | `TAB -> 空白 変換` (TAB -> space conversion) | Replace each `#9` in the selection with `TabWidth` spaces | `FMenuItemTabToSpace` |
| 6 | `空白 -> TAB 変換` (space -> TAB conversion) | Replace each run of `TabWidth` spaces in the selection with `#9` | `FMenuItemSpaceToTab` |
| 7 | `インデント` (Indent) | `ExecuteCommand(ecBlockIndent, ' ', nil)` | none |
| 7 | `逆インデント` (Unindent) | `ExecuteCommand(ecBlockUnindent, ' ', nil)` | none |

- Items that use the selection do nothing if the selection is empty.
- `OnPopupMenuPopup`: when `SelText <> ''`, enable "Cut" and "Copy" of group 1 and the items of groups 2 to 6. "Paste" is enabled when `Clipboard.HasFormat(CF_TEXT)`. Group 7 is always enabled.
- `OnMenuSelectAllClick` (`SelectAll`) is declared but not included in the menu.
- TCsEditor does not use this menu (TCsEditor installs its own menu; `TCsEditor_Design.md` Chapter 7).

## 9. Markdown color-coding (TCSynMarkdownSyn)

### 9.1 Class

- The attribute type is `TSynHighlighterAttributes` (the 4.8 name. A warning appears on 5.0, but it compiles as is). The return value of `GetTokenAttribute` is also `TSynHighlighterAttributes`.

```pascal
TCSynMarkdownSyn = class(TSynCustomHighlighter)
private
  FLine: PChar; FLineLen: Integer;           // current line
  FPos, FTokenPos: Integer;                  // current position / start of the token
  FTokenKind: TCMdTokenKind;                 // kind of the current token
  FRange: TCMdRange;                         // state at the start of the line
  FLineMode: TCMdTokenKind;                  // kind when the whole line is a single kind (mtText if none)
  FHeadingAttri, FStrongAttri, FEmphasisAttri, FCodeAttri, FQuoteAttri,
  FListAttri, FLinkAttri, FRuleAttri, FTextAttri, FSpaceAttri: TSynHighlighterAttributes;
public
  constructor Create(AOwner: TComponent); override;
  class function GetLanguageName: string; override;          // 'Markdown'
  procedure SetLine(const NewValue: string; LineNumber: Integer); override;
  procedure Next; override;
  function GetEol: Boolean; override;
  function GetToken: string; override;
  procedure GetTokenEx(out TokenStart: PChar; out TokenLength: integer); override;
  function GetTokenAttribute: TSynHighlighterAttributes; override;
  function GetTokenKind: integer; override;
  function GetTokenPos: Integer; override;
  function GetDefaultAttribute(Index: integer): TSynHighlighterAttributes; override;
  function GetRange: Pointer; override;
  procedure SetRange(Value: Pointer); override;
  procedure ResetRange; override;
published
  property HeadingAttri, StrongAttri, EmphasisAttri, CodeAttri, QuoteAttri,
    ListAttri, LinkAttri, RuleAttri, TextAttri, SpaceAttri: TSynHighlighterAttributes;
end;

TCMdRange = (mrNormal, mrFence);              // normal / inside a code block
TCMdTokenKind = (mtText, mtSpace, mtHeading, mtStrong, mtEmphasis, mtCode,
  mtQuote, mtList, mtLink, mtRule);
```

- The state (Range) is handed to SynEdit as `Pointer(PtrInt(Ord(FRange)))` (so that it can be remembered per line).
- Folding is not supported.
- `GetDefaultAttribute`: `SYN_ATTR_COMMENT` -> `FQuoteAttri`, `SYN_ATTR_IDENTIFIER` -> `FTextAttri`, `SYN_ATTR_KEYWORD` -> `FHeadingAttri`, `SYN_ATTR_STRING` -> `FCodeAttri`, `SYN_ATTR_WHITESPACE` -> `FSpaceAttri`, `SYN_ATTR_SYMBOL` -> `FListAttri`. Others are nil.

### 9.2 How text is divided

**Decided at the start of the line** (decided in `SetLine`. Up to 3 spaces of leading whitespace are allowed)

| Order | State / line form | Kind of the whole line | State of the next line |
|---|---|---|---|
| 1 | State is `mrFence` and the line starts with ` ``` ` or `~~~` | Code | `mrNormal` |
| 2 | State is `mrFence` | Code | `mrFence` |
| 3 | Starts with ` ``` ` or `~~~` | Code | `mrFence` |
| 4 | 1 to 6 consecutive `#`, followed by a space or the end of the line | Heading | `mrNormal` |
| 5 | Only one kind of `-`, `*`, or `_`, three or more of them (spaces between are allowed), and no other characters | Rule | `mrNormal` |
| 6 | Starts with `>` | Quote | `mrNormal` |
| 7 | Anything else | Divided as in "Inside the line" below | `mrNormal` |

- For 1 to 6, the whole line is made a single token (`FLineMode`).

**Inside the line** (for case 7, from the start in order)

| Form | Kind |
|---|---|
| At the start of the line (after spaces), `-`, `*`, or `+` followed by a space; or a number followed by `.` or `)` and a space | List mark (the mark and one following space) |
| A run of spaces and tabs | Space |
| Starts with `` ` `` and closes with the same number of `` ` `` (if not closed, to the end of the line) | Code |
| Starts with `**` or `__` and closes with the same symbol | Strong |
| Starts with `*` or `_` and closes with the same symbol (`_` only when the preceding character is not alphanumeric) | Emphasis |
| Starts with `[` and closes with `](` ... `)`; starts with `<http` and closes with `>` | Link |
| Anything else (up to just before the next of the symbols or spaces above) | Text |

- If the closing symbol is not on the same line, only the opening symbol is treated as text (except for code).
- Inside strong, emphasis, and links, text is not divided further.
- Tables, heading underlines (`===`, `---`), and code that starts with four spaces are not treated specially.

### 9.3 Colors (from the color set in 7.4.2)

| Attribute | Color | Style |
|---|---|---|
| `HeadingAttri` (heading) | `Key` | `[]` |
| `StrongAttri` (strong) | `Text` | `[fsBold]` |
| `EmphasisAttri` (emphasis) | `Text` | `[fsItalic]` |
| `CodeAttri` (code) | `Str` | `[]` |
| `QuoteAttri` (quote) | `Comment` | `[]` |
| `ListAttri` (list mark) | `Key` | `[]` |
| `LinkAttri` (link) | `Str` | `[]` |
| `RuleAttri` (rule) | `Key` | `[]` |
| `TextAttri`, `SpaceAttri` | `Text` | `[]` |
| Background | `Bg` | - |

- After setting `Style := []` in step 1 of 7.4.3, this table is applied (bold and italic are applied by this table).

## 10. Points to check when investigating defects

| Symptom | Where to look |
|---|---|
| The color scheme is not applied when the component is created in code | `Create` does not call `ApplyEditStyle` (Chapter 6). It is applied when `EditStyle` is set to a different value, in `Loaded`, and when `Language` is changed |
| After opening a file, the highlighter colors become the default colors | The final `ApplyEditStyle` of `SetLanguage` (7.2) |
| Memory grows every time a file is opened | Whether `SetLanguage` frees the old highlighter (only those whose Owner is the component itself; 7.2) |
| A highlighter put in by the application disappears | Whether `SetLanguage` checks the Owner (7.2). If you do not want it switched by extension, set `Highlighter` again after the file name |
| Dark-colored text appears on a black background | Step 1 of 7.4.3 (set all attributes to the text color). Whether the attribute names (table in 7.4.3) match SynEdit |
| Only part of the left gutter (folding, changed-line marks) is white | `CodeFoldPart` and `ChangesPart` in 7.4.1. Except for `csVSLight` and `csVSDark`, it is the same as 1.0, and no color is set on the folding column |
| The color-coding of the caret line disappears | Whether `LineHighlightColor.Foreground` is `clNone` (7.4.1) |
| Markdown colors are wrong | The way of dividing in 9.2. The start-of-line checks in `SetLine`, and the passing of the state (`mrFence`) |
| A file cannot be saved by another application | `LockFile` (7.3) |
| Dropping does not open the file | The subclassing in `CreateWnd`, and `DoDropFiles` (7.10) |
| Changing an event's arguments has no effect | Whether it is one of the items that are "put into the component" in the table of 7.6 |
| Ctrl+S and the like do not work or cannot be stopped | `KeyDown` (7.8). It is handled before the component's `OnKeyDown` |

## 11. Changes in this version (1.0 -> 1.1)

Steps for building the code. Not included in the user manual.

| No | Item | Now (1.0) | After the change (1.1) | Reason for the change | Risk |
|---|---|---|---|---|---|
| 1 | Color schemes | Four: `csBlack`, `csGray`, `csWhite`, `csThema` | Add `csVSLight` and `csVSDark` (7.4) | To make the TCsEditor color schemes the same as TCMonacoEditor (VS Code) | The existing four are unchanged (only `ChangesPart.Visible := True` is added) |
| 2 | Switching the highlighter | Every time `FileName` is set, a new highlighter is created and the old one is left behind. The color scheme is not reapplied | If it is the same kind, do not recreate it. If different, free the old one the component created itself and create the new one. Finally `ApplyEditStyle` (7.2) | Because the color scheme reverted to the default colors after opening, and memory grew with every file opened | A highlighter the application put in itself is not freed (the Owner is checked). Applications that relied on "default colors after opening" will look different |
| 3 | Extensions and highlighters | "Now" in the table below | Decide the language with the same table as TCMonacoEditor, and decide the highlighter from the language (`CSLanguageForFile`, `Language`; Chapter 3, 7.1, 7.2) | To decide in the same way as TCsEditor. Color-coding .md as HTML was not correct | The color-coding changes for the extensions in the table below |
| 4 | Color schemes other than Pascal | The color scheme is applied to the highlighter only for Pascal | Apply the colors of that color scheme to every highlighter (7.4.2, 7.4.3) | Because HTML and others were hard to read on a black background | The colors of non-Pascal files change |
| 5 | Markdown color-coding | None (HTML was used as a substitute) | Create `TCSynMarkdownSyn` (Chapter 9) | Because Markdown is the main thing handled | It uses a simple way of dividing (9.2), so not every Markdown syntax is distinguished |
| 6 | `ApplyEditStyle` | private | protected virtual (5.3) | So that the component inside TCsEditor can add colors such as the caret line | None (behavior does not change) |
| 7 | `Language` | None | Public property (5.2, 7.2) | So that TCsEditor can decide the language | None |
| 8 | Note in User Manual 7.2 | "Setting `Key := 0` in `OnKeyDown` stops the component's behavior" | "Stop it with the form's `KeyPreview` and `OnKeyDown`" (7.8) | Because it did not match the code's behavior (it is handled before `OnKeyDown`) | A change to the user manual only (the code is not changed) |
| 9 | Operating environment | Lazarus 4.8 and 5.0 RC1 | 5.0 or later. On 4.8, only the cx compile succeeds (Chapter 1). There is no version-specific code | Because the SynEdit of 5.0 changed | Operation of applications that use TCSynEdit on 4.8 is not guaranteed. "Old style" warnings appear on 5.0 |
| 10 | Unused highlighters of its own | Remain | Freed when the language is switched (7.2) | Because when the application put in its own highlighter, the first highlighter remained | None |
| 11 | Number color | Pascal only | Every highlighter that has `NumberAttri` (7.4.3) | Because many 5.0 highlighters do not return numbers through "an attribute that every highlighter has" | None |
| 12 | Overlay attributes | Step 1 sets the `Text` color | Set to `clNone` (step 1 of 7.4.3) | Because Pascal comments and strings turned white and were not color-coded | Parts whose color was decided by an overlay attribute, such as names in Pascal's declaration section, take the color of the underlying attribute. `csVSLight` is fixed in the same way |
| 13 | `csVSDark` line numbers and folding marks | Line numbers #858585, marks #C5C5C5 | Line numbers #6E7681, marks #5A5A5A (7.4.1) | Because they stood out more than the body text and were brighter than in the Lazarus IDE | Appearance only (other color schemes do not change) |

**Differences per extension for No.3**

| Extension | Now (1.0) | After the change (1.1) |
|---|---|---|
| .pas .pp .lpr .dpr, no extension | Pascal | Pascal |
| .inc .lpk | Not switched | Pascal |
| .txt | Pascal | None |
| .md .markdown | HTML | Markdown |
| .html .htm | HTML | HTML |
| .json | HTML | JavaScript |
| .csv | HTML | Not switched |
| .yaml .yml | HTML | None |
| .xml | XML | XML |
| .css .js .sql .ini .cfg .bat .cmd .py .c .h .cpp .hpp .cs .ts .tsx .java .sh .bash .php | Not switched | The respective highlighter (table in 7.2) |
| .ps1 .psm1 .psd1 .go | Not switched | None |

**Changes per file**

| File | Change |
|---|---|
| `cSynedit.pas` | No.1 to 7 above. Add the highlighter units listed in Chapter 2 to uses |
| `uCXReg.pas`, `cx_icons.lrs` | No change |
| User manual `TCSynEdit_Usage.md` | Chapter 3 (two color schemes), Chapter 4 (extension table), 5.1 (`Language`), the note in 7.2 (No.8). The user manual is corrected last |
