# TCMonacoEditor Design Document

Author: aotan083
Date: 2026-10-30
Version: 1.3

---

## 1. Purpose and Policy

TCMonacoEditor is a fully offline editor component built on WebView2 and Monaco Editor that works just by dropping it onto a form. Tabs, editor, preview (Markdown and code), search, replace, and printing are all built into this one component. How it behaves (what the user sees) is described in the user manual `TCMonacoEditor_Usage.md` (hereafter "the manual"); this design document describes how it is built.

| No | Policy |
|---|---|
| 1 | The user writes zero lines of code. All settings are made in the Object Inspector. The component also takes care of preparing WebView2 (Chapter 6) |
| 2 | Like TSynEdit, any number of them can be placed on one form. Each one is a self-contained editor |
| 3 | Events work even when not set (when not set, the component performs its default behavior) |
| 4 | Inner components are not exposed. Only the necessary properties and events are exposed on the outer TCMonacoEditor |
| 5 | Dialogs use the built-in ones unless set; if set, those are used. Multiple editors can choose the same dialog |
| 6 | The physical file is the single source of truth (no DB or CMS is used) |
| 7 | The back side (control of files, folders, and the system) is handled by Pascal; the front side (editing and preview display) is handled by JavaScript inside WebView2 |
| 8 | The memory cost of WebView2 (about 60MB per editor) is accepted. At most 2 WebView2 instances per editor (one for the editor, one for the preview). If the preview is never shown, only 1 |
| 9 | New features are decided by "does my application need it". Getting closer to VS Code is not a goal in itself. Features that Monaco has from the start are left in place, not disabled |

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCmonacos.pas` | cx (runtime) | `TCMonacoEditor` (the outer component), `TCMPage`, `TCMFormHook`, `TCMTabDragOutEvent`, functions `CMActiveEditor`, `CMSplitLine`, `CMColorToHex`. Tab detachment (sending and receiving; 4.11) |
| `uCmmonacoview.pas` | cx (runtime) | `TCMMonacoView` (the inner component that displays Monaco), `TCMDocument`, `TCMMenuItem`. Reading and writing character encodings, language detection, string conversion functions `CMToHankaku`, `CMToZenkakuKatakana`, `CMToZenkakuHiragana` |
| `uCmdpreview.pas` | cx (runtime) | `TCMMarkdownPreview` (preview). Printing |
| `CMonacoTabs.pas` | cx (runtime) | `TCMTabBinder` (connects the view and ATTabs; also detects a tab being dragged out) and `TCMBinderDragOutEvent` |
| `CMonacoPreview.pas` | cx (runtime) | `TCMPreviewBinder` (connects the view and the preview) and `TCMSyncScroll` |
| `CMonacoFindDlg.pas` | cx (runtime) | `TCMFindDialog` (invisible component) and `TCMFindForm` |
| `CMonacoActions.pas` | cx (runtime) | 25 standard actions (manual Chapter 12) and the base classes `TCMEditorAction` and `TCMEditorToggleAction` |
| `uCXRuntime.pas` | cx (runtime) | Function that reads WebView2.ini and `CXStartWebView2` (Chapter 6. For details see `TCTabBrowser_Design.md` Chapter 9) |
| `uCXReg.pas` | cxdsgn (design time) | `RegisterComponents('CX', [..., TCMonacoEditor, TCMFindDialog, ...])`, `RegisterActions('CX', [25 items], nil)` |
| `cx_icons.lrs` | cxdsgn (design time) | Icons (`TCMonacoEditor` and `TCMFindDialog`, and their respective `_150` and `_200`) |
| `monaco\editor.html` | Runtime file | HTML/JS that loads Monaco and communicates with Pascal (5.3) |
| `preview\preview.html` and `preview\lib\` | Runtime files | The preview HTML/JS and the set of libraries (5.3, Chapter 7) |

- Required packages for cx: `LCL`, the Lazarus package of WebView4Delphi, `atflatcontrols_package` (ATTabs).
- Actions do not appear on the palette, so they have no icons. The order follows the table in manual Chapter 12.

**Unit references** (one-directional. The outer `TCMonacoEditor` uses `CMonacoFindDlg` in its interface because of the `FindDialog` property. Placing the outer and inner components in the same unit would create a circular reference, so they are separated)

```
uCXRuntime (functions that decide locations, WebView2 preparation)
   ↑ uses (implementation)
uCmmonacoview (TCMMonacoView), uCmdpreview (TCMMarkdownPreview)
   ↑ uses
CMonacoTabs, CMonacoPreview, CMonacoFindDlg
   ↑ uses
uCmonacos (TCMonacoEditor)
   ↑ uses
CMonacoActions
```

- Uses of `uCmonacos`: `Windows, Classes, SysUtils, Controls, Forms, ExtCtrls, Graphics, Dialogs, Menus, LCLType, ActnList, Registry, ShellApi, ATTabs, ucmmonacoview, ucmdpreview, CMonacoTabs, CMonacoPreview, CMonacoFindDlg`. Implementation: `LazUTF8, StrUtils`.
- So that an application needs to use only `uCmonacos`, `TCMEncoding`, `TCMFindOption(s)`, `TCMSyncScroll`, and `TCMTabImageEvent` are re-exported as type aliases, and `ceUTF8` through `ceCP932`, `foMatchCase`, `foWholeWord`, `foLoop`, `ssNone`, `ssEditorToPreview`, and `ssBoth` are re-exported as constants.
- Inner component names all share the prefix `TCM`. The `TCustomXxx` form is not used (in Lazarus it conventionally denotes a "base class to inherit from", which does not suit components held inside).

## 3. The Outer Component (TCMonacoEditor)

### 3.1 Structure

```
TCMonacoEditor (TCustomPanel)
 ├ Tabs (TATTabs)             … top edge. Hidden when MultiDocument = False
 ├ Monaco (TCMMonacoView)     … center. Holds the text of all tabs (one Monaco "model" per tab)
 ├ Splitter (TSplitter)
 └ Preview (TCMMarkdownPreview) … right side. Shown by ShowPreview
```

- At runtime, the inner components cover the whole panel.
- At design time (on the IDE), WebView2 is not started. `Paint` draws a thin frame and the component name.
- Right after startup, until WebView2 is ready, the panel's background color is visible. The background color follows `Theme` (dark #1E1E1E, light #FFFFFF).
- `Text` and `Caption` of `TControl` are redeclared in public to hide them (they refer to the text and title of the visible tab). `csSetCaption` is removed from `ControlStyle`.
- The splitter and the tabs themselves are not exposed. Only appearance settings (`SplitterResizeStyle`, `SplitterWidth`, `PreviewWidth`, `TabFlat`, `TabSeparator`) are exposed.
- When created with `Create` in code, the component joins the form's close confirmation (`TCMFormHook`) at the moment `Parent` is set.

### 3.2 API and What It Calls Internally

`ed` is a `TCMonacoEditor`, view is a `TCMMonacoView`, preview is a `TCMMarkdownPreview`, and `TCMPage` is a class of `uCmonacos`. For behavior see manual Chapters 4 to 7.

**Tab contents and files (`ed`, `ed.Pages[n]`)**

| Name | What it calls internally |
|---|---|
| `Text` | `TCMPage.GetText`, `SetText` → view `DocumentText[i]`. For `ed`, `CurPage.Text` |
| `Caption` | view `DocumentTitle[i]` |
| `FileName` | view `DocumentFileName[i]` |
| `Modified` | view `DocumentModified[i]` |
| `Encoding` | view `DocumentEncoding[i]` |
| `Language` | view `DocumentLanguage[i]` |
| `LineCount` | `TCMPage.GetLineCount` (counted from the copy in `Text`) |
| `LoadFromFile` | `PageLoad(i, FileName)` |
| `Save` | `PageSave(i)` |
| `SaveAs` | `PageSaveAs(i, FileName)` |
| `Clear` | `PageClear(i)` |
| `Close` | `PageClose(i, Force)` |

- The same-named members of `ed` call the same-named members of `CurPage` (the `TCMPage` of the visible tab).

**The collection of tabs (`ed`)**

| Name | What it calls internally |
|---|---|
| `OpenFile` | Name is '': `OpenWithDialog`. `MultiDocument = True`: view `OpenFile`. `False`: `LoadDocument` into index 0 |
| `NewPage` | `True`: view `AddDocument('')`. `False`: `ClearDocument` on index 0 |
| `SaveAll` | view `SaveAll` |
| `CloseAll` | `True`: view `CloseAll`. `False`: `PageClose(0, Force)` |
| `CanCloseAll` | For each unsaved document, the confirmation in 4.8 (does not close) |
| `FindPage` | view `FindDocument` |
| `MovePage` | view `MoveDocument` |
| `ActiveIndex` | view `ActiveIndex` |
| `PageCount` | view `DocumentCount` |
| `Pages[n]` | `GetPage(n)` |

**Operations on screen (`ed`)**

| Name | What it calls internally |
|---|---|
| `SelText` | view `GetSelectedText`, `SetSelText` (`seltext`) |
| `SelStart`, `SelLength` | view `SelStart`, `SelLength` (copies of `cursor`) |
| `CanUndo`, `CanRedo` | view `CanUndo`, `CanRedo` (copies of `canundo`) |
| `GetCursorPos`, `SetCursorPos`, `SetSelection` | the same-named members of view (`setcursor`, `setsel`) |
| `LineText` | view `CursorLineText` |
| `LineWords` | `GetLineWords` → `CMSplitLine` (4.10) |
| `LineDelimiters`, `LineSkipEmpty`, `LineQuoteChar` | `FLineDelimiters`, `FLineSkipEmpty`, `FLineQuoteChar` |
| `Undo`, `Redo`, `Cut`, `Copy`, `Paste`, `SelectAll` | the same-named members of view |
| `DeleteToEnd`, `DeleteToStart` | the same-named members of view (`delto`) |
| `DuplicateLine` | view `DuplicateLine` (`dupline`) |
| `ToggleOverwrite` | view `ToggleOverwrite` (`toggleow`) |
| `Find`, `FindNext`, `FindPrev`, `Replace`, `ReplaceAll` | the same-named members of view |
| `ShowFindDialog` | Opens the shared dialog or `FindDialog`, with this editor as the target (Chapter 9) |
| `CanPrint` | `True` if there is a tab |
| `Print` | `AsyncPrint` (7.3) |
| `SetFocus` | `QueueAsyncCall` of `AsyncSetFocus` (5.5) |
| `SearchText`, `ReplaceText`, `SearchOptions` | the same-named members of view |
| `TopLine`, `Ready` | the same-named members of view |
| `Monaco`, `Preview` | `FMonaco`, `FPreview` |

**Events**

| Name | What is connected internally |
|---|---|
| `OnReady`, `OnChange`, `OnCursorChange`, `OnModeChange`, `OnModifiedChange`, `OnActiveChange`, `OnDocListChange`, `OnDocumentChange`, `OnToggleMaximize`, `OnFontSizeChange`, `OnLineNumbersChange` | Relays the same-named events of view (replacing `Sender` with itself). In `OnActiveChange`, the captions of the preview and the find dialog are also updated |
| `OnSave` | Relays view (also remembers the folder used last) |
| `OnQueryClose` | `DoQueryClose` |
| `OnNeedFileName` | `MonacoNeedFileName`, `AskPageFileName` |
| `OnFileDrop` | `MonacoFileDrop` |
| `OnOpenMarkdown` | `PreviewOpenMarkdown` |
| `OnFindDone`, `OnReplaceAllDone` | `MonacoFindDone`, `MonacoReplaceAllDone` |
| `OnPopup` | `MonacoPopup` |
| `OnGetTabImageIndex` | `BinderGetImageIndex` |
| `OnTabDragOut` | `BinderTabDragOut` (4.11.2). Receives the binder's `OnDragOut`, decides the initial value of `TearOff`, and calls it. After that, if `TearOff`, the component detaches |
| `OnKeyDown` | `MonacoAccelKeyDown` → `KeyDown` (5.6) |
| `OnError` | `DoError` (when not set, `QueueAsyncCall(AsyncShowError)` shows `MessageDlg` only once per startup for the same message. `GShownErrors`) |

**Settings**

| Name | What is held internally / how it is passed |
|---|---|
| `MultiDocument` | `FMultiDocument`. Can be changed only at design time and from creation until first display (changes at runtime are ignored, because the handling when there are multiple tabs is undefined) |
| `ConfirmOnFormClose` | `FConfirmOnFormClose` |
| `TabTearOff` | `FTabTearOff` (default `True`). Whether to perform detachment (4.11.2, 4.11.3) and merging (4.11.6) |
| `OpenDialog`, `SaveDialog`, `FindDialog` | `FOpenDialog`, `FSaveDialog`, `FFindDialog` (`FreeNotification`) |
| `TabFlat`, `TabSeparator` | `ApplyTabShape` → ATTabs `OptShowFlat`, `OptShowFlatSepar` |
| `TabIcons`, `TabImages` | `ApplyTabIcons` |
| `WordWrap`, `LineNumbers`, `FontSize`, `TabSize`, `Folding`, `MatchBrackets`, `OccurrencesHighlight`, `Minimap`, `ReadOnly`, `JapaneseUI`, `DefaultLanguage`, `AutoLanguage`, `OpenDroppedFiles`, `QuotePrefix` | the same-named members of view (`opt`) |
| `Theme` | `FTheme` → view `Theme` (`ctAuto`→'auto', `ctLight`→'vs', `ctDark`→'vs-dark'), `ApplyThemeColors` |
| `HitColorLight`, `HitColorDark`, `CursorLineColorLight`, `CursorLineColorDark` | Held as TColor in `F…`, and passed to the same-named members of view as '#RRGGBB' via `CMColorToHex` |
| `SelectionColorStyle` | `FSelectionColorStyle`. For anything other than `scCustom`, the colors from the tables `SelStyleLight` and `SelStyleDark` are put into `FSelectionColorLight` and `FSelectionColorDark` and passed to view |
| `SelectionColorLight`, `SelectionColorDark` | Writing sets `SelectionColorStyle := scCustom` (not changed while the .lfm is being loaded). Saved to the .lfm only when `scCustom` |
| `MonacoPath` | view `ResourcePath` (Chapter 6) |
| `ShowPreview` | `UpdatePreview` |
| `PreviewWidth` | `FPreviewWidth` (the width changed with the splitter is also stored) |
| `SplitterResizeStyle`, `SplitterWidth` | `FSplitter` |
| `PreviewFontSize`, `BreakOnNewline`, `AllowRemoteImages` | the same-named members of preview |
| `ColorScheme` | `FColorScheme` → preview `ColorScheme` (`csEditor`→'editor', `csGitHub`→'github') |
| `PreviewBackColor…`, `PreviewTextColor…`, `PreviewLinkColor…` (6 items) | Held in `F…`, and passed to preview's `BackColorLight` etc. via `CMColorToHex` |
| `SyncScroll`, `PreviewDelayMs` | `TCMPreviewBinder` |
| `PreviewPath` | preview `ResourcePath` (Chapter 6) |

**Default color values** (constants in the interface of `uCmonacos`. TColor is internally in blue-green-red order)

| Constant | Value | Color |
|---|---|---|
| `DefHitColorLight` | `$0058EEFF` | #FFEE58 |
| `DefHitColorDark` | `$0008667D` | #7D6608 |
| `DefCursorLineColorLight` | `$00FFF2EA` | #EAF2FF |
| `DefCursorLineColorDark` | `$003C312C` | #2C313C |
| `DefPreviewBackColorLight` | `$00FEFFFF` | #FFFFFE |
| `DefPreviewBackColorDark` | `$001E1E1E` | #1E1E1E |
| `DefPreviewTextColorLight` | `$00000000` | #000000 |
| `DefPreviewTextColorDark` | `$00D4D4D4` | #D4D4D4 |
| `DefPreviewLinkColorLight` | `$00B16A00` | #006AB1 |
| `DefPreviewLinkColorDark` | `$00FF9437` | #3794FF |

| Selection set | Dark (`SelStyleDark`) | Light (`SelStyleLight`) |
|---|---|---|
| `scStandard` | `$00784F26` (#264F78) | `$00FFD6AD` (#ADD6FF) |
| `scBlue` | `$009E5A0E` (#0E5A9E) | `$00FFB67F` (#7FB6FF) |
| `scAmber` | `$00004E6B` (#6B4E00) | `$004FD5FF` (#FFD54F) |
| `scPurple` | `$00822D5A` (#5A2D82) | `$00FFA3C5` (#C5A3FF) |
| `scCustom` | `clNone` (not used) | `clNone` (not used) |

`CMColorToHex(color, default)`: if `clDefault` or `clNone`, the default is used. System colors (such as `clWindow`) are converted to the current actual color with `ColorToRGB` (it does not follow changes of the OS color scheme). It is rearranged into red-green-blue order and returned as '#RRGGBB'. The outer component holds the chosen TColor as is (if you choose `clWindow`, the Object Inspector also shows `clWindow`).

### 3.3 TCMPage

```pascal
TCMPage = class
private
  FOwner: TCMonacoEditor;
  FId: Integer;               // Document Id (does not change when reordered)
  function GetIndex: Integer; // IndexOfId(FId) in FOwner's view. -1 if closed
public
  constructor Create(AOwner: TCMonacoEditor; AId: Integer);
  procedure Clear;
  function LoadFromFile(const AFileName: string): Boolean;
  function Save: Boolean;
  function SaveAs(const AFileName: string = ''): Boolean;
  function Close(Force: Boolean = False): Boolean;
  property Caption, FileName, Modified, Encoding, Language, Text, LineCount;
end;
```

- On every operation, the current index is looked up with `GetIndex`, and `TCMonacoEditor.PageXxx(index)` or view's `DocumentXxx[index]` is called. If it is -1, the value read is empty and the operation does nothing (`False` for `Boolean`).
- Exactly one is created per tab and put into the editor's `FPages`. It is freed when the editor is destroyed.
- If the index of `Pages[n]` is out of range, `EListError`.

### 3.4 TCMFormHook

One per form (`TComponent`; the owner is the form).

| Held item | Contents |
|---|---|
| `FEditors` | The list of editors on that form |
| `FActive` | The editor that was focused last (`SetActive` upon the `gotfocus` notification) |
| `FFindDialog` | The shared find/replace dialog (created on first use by `SharedFindDialog`) |
| `FOldCloseQuery` | The form's original `OnCloseQuery` |

- `CreateFor(form)`: remembers the form's `OnCloseQuery` and replaces it with `FormCloseQuery`.
- `FormCloseQuery`: calls the original `OnCloseQuery`, and if `CanClose` remains true, runs `CanCloseAll` for each editor. If even one returns `False`, it stops there (the rest are not checked).
- `ActiveEditor`: `FActive` if there is one, otherwise the first editor, otherwise nil. `CMActiveEditor(Form)` returns this.
- When an editor is placed on something other than a form (such as a frame) and cannot use the shared dialog, the editor creates its own spare (`FPrivateFindDlg`).

## 4. Text and Documents

### 4.1 Document Management

- The editor keeps a single WebView2, holds multiple documents (models) inside Monaco, and switches the displayed one. Adding tabs does not add WebView2 instances.
- For each document it holds the file name, character encoding, BOM, modified state, Undo/Redo history, cursor position, scroll position, and language (Undo, cursor, and scroll belong to the Monaco model; the rest to `TCMDocument`).
- `TCMDocument`: `Id`, `FileName`, `Encoding`, `Modified`, `Text` (copy), `Language`. They are lined up in view's `FDocs`, and `FActive` is the index of the visible one.
- The same file is never opened in two tabs. The comparison is case-insensitive.
- There is always at least one tab. Closing the last one creates an empty untitled one (`OnDocListChange` fires once).
- Right after startup there is one untitled document. `OpenFile` does not reuse it and always opens in a new tab.

### 4.2 Copy of the Text

- The master of the text is the Monaco model. The Pascal side (`TCMDocument.Text`) is a copy for reading. The reason for keeping a copy is that asking Monaco for a value from Pascal returns the answer asynchronously, so the value cannot be returned on the spot.
- When a person types, `editor.html` sends the whole text with `change` 80 milliseconds after input stops. The view updates the copy and, if it is the visible document, calls `OnChange`.
- Selection, cursor, and whether Undo/Redo is possible are received and remembered through the `cursor` and `canundo` notifications (`FSelectedText`, `FSelStart`, `FSelLength`, `FCursorLine`, `FCursorCol`, `FCanUndo`, `FCanRedo`).
- The text of the cursor line is received and remembered through `cursorline` (`FCursorLineText`, `FCursorLineSeq`; 4.10).
- `Text :=`: if it is the same as the copy, it just sends `doc.settextifdiff` to Monaco (in case the copy is stale, Monaco also compares, replaces only when different, and returns `textsync`). If it differs from the copy, it rewrites the copy and then sends `doc.reset` and `doc.dirty` (so reading right afterward returns the new value).
- When a notification comes from Monaco, the copy is always overwritten by it (aligned to Monaco).
- Anything written before `Ready` (text, settings) is held on the Pascal side and sent to Monaco at `ready`.
- For `Ctrl+S`, `editor.html` sends `save` with the latest text attached, so saving uses the latest text even right after typing. Saving from standard actions and `ed.Save` writes the copy.
- The copy and Monaco can be out of step in only two cases: (1) before `Ready`, and (2) right after typing or selecting (about 0.1 second).

### 4.3 Files

- Reading: if there is a BOM, follow the BOM. If not, check whether it is valid as UTF-8, and if not, CP932.
- Saving: write with the encoding and BOM used when it was read. Characters that cannot be represented in CP932 raise an exception (`OnError`).
- The line ending (CRLF / LF) is kept as it was when read. A new document without line breaks uses CRLF.
- Language: with `AutoLanguage`, it is decided from the extension on read and on Save As (table in manual 9.2). If unknown, `DefaultLanguage`.
- The default extension in the Save As dialog is decided from the language by `DefaultExtFor` (manual Chapter 7).
- The initial folder of the built-in dialogs is the folder of that tab. For untitled, the folder used last (remembered by `OnSave`).

### 4.4 Confirmation for Unsaved Documents (DoQueryClose)

1. If `OnQueryClose` is set, call it with `Index` and follow its `CanClose`.
2. If it is not set and `ConfirmOnFormClose = True`, show "(Title) has been modified. Save it? (No = close without saving)" (Yes, No, Cancel). On Yes, view `SaveDocument` (if it cannot be saved, do not close). On No, close. On Cancel, do not close.
3. If it is not set and `False`, discard.

- When called: closing a tab ([×], middle button, `Close`, `CloseAll`), closing the form (`CanCloseAll`), and opening or creating new with `MultiDocument = False`.

### 4.5 MultiDocument

| | `True` | `False` |
|---|---|---|
| Tabs | Shown | Hidden (`FTabs.Visible := False`) |
| Open | view `OpenFile` (new tab) | After the confirmation in 4.4, `LoadDocument` into index 0 |
| New | view `AddDocument('')` | After the confirmation in 4.4, `ClearDocument` on index 0 |
| Close | view `CloseDocument` | After the confirmation in 4.4, `ClearDocument` on index 0 (the tab count does not change, so `OnDocListChange` and `OnActiveChange` are not fired) |
| Drop | Open all | Only the first file, same as Open |

- A state where the tabs are hidden but multiple documents are held inside is not allowed (there would be no way to switch to the hidden documents).

### 4.6 Tabs (TCMTabBinder)

- The tabs are rebuilt on view's `OnDocListChange` and updated on `OnDocumentChange` and `OnActiveChange`. The title is `Caption`, followed by ` *` if modified, and the hint is the full path.
- Tab click, [+], [×] (and middle button), and reordering by drag are passed to view's `ActiveIndex`, `AddDocument`, `CloseDocument` (going through the confirmation in 4.4), and `MoveDocument`.
- In flat display (`OptShowFlat = True`), ATTabs draws the selected tab in the same color as the strip. So per-tab colors (`TabColorActive`, `TabColorOver`; `OptShowEntireColor = True`) are set on all tabs to paint the visible tab and the tab under the mouse differently.
- The accent line is not shown (to match Explorer).
- ATTabs' `OptMouseDragOutEnabled` is set to `False` (this disables the ATTabs feature of moving a tab to another ATTabs. If dropped onto the tab strip of another editor, only the tab, without a document, would move, breaking the correspondence between tabs and documents).
- A tab being dropped outside one's own application is detected with ATTabs' `OnEndDrag` (4.11).

**Icons**

- When `TabIcons = True` and there is no `TabImages`: the icon is obtained from the extension with `SHGetFileInfo` (`SHGFI_USEFILEATTRIBUTES`, small icon) and put into an internal image list. The same extension is fetched only once. Untitled uses '.txt'. It works from the extension alone even if the file does not exist. It follows the file association.
- When `TabImages` exists: `OnGetTabImageIndex` (index 0 if not set).
- `TabIcons = False`: no icons.

### 4.7 Color Scheme (ApplyThemeColors)

- The startup determination for `Theme = ctAuto` uses `AppsUseLightTheme` (0 means dark) under the registry key `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`.
- Switching while running: `editor.html` detects the change of the OS theme and notifies with `oschange`, and the component repaints the tabs, splitter, and background (per editor).
- The color values are in the table in manual 9.4 (values close to Windows 11 Explorer).

### 4.8 Right-Click Menu

- Monaco's standard menu is disabled, and `editor.html` sends `contextmenu`. The view shows the `PopupMenu` (items of `TCMMenuItem`) at the mouse position via `QueueAsyncCall(AsyncContextMenu)`.
- Just before showing it, the display, enabled state, and check of the items are decided by whether there is a selection, `ReadOnly`, `Minimap`, and `ShowPreview`, and `OnPopup` is called.
- Items (`TCMMenuCmd`): `mcCut`, `mcCopy`, `mcPaste`, `mcQuoteCopy`, `mcAppendCut`, `mcAppendCopy`, `mcDelete`, uppercase, lowercase, half-width, hiragana, katakana, tab⇔space, indent, outdent, `mcSelectAll`, `mcUndo`, `mcRedo`, minimap, preview.
- Quoted copy: prepends `QuotePrefix` to the start of each selected line and puts it on the clipboard (the last line break is kept). Append copy / append cut: adds after the current clipboard contents (cut uses `delsel`).
- Conversion: `ReplaceSelection` (`replacesel`. The replaced range remains selected, one Undo step). Tab⇔space and indent use `xform`.
- Items added by the application are lined up after `Monaco.PopupMenu.Items`.

### 4.9 File Drop

- `editor.html` sends `dropfiles`. The view, via `QueueAsyncCall(AsyncDropFiles)`, calls `OnFileDrop` (done if `Handled`) → opens if `OpenDroppedFiles` (4.5). Folders are ignored.

### 4.10 Words on the Cursor Line (CMSplitLine)

- `cursorline` is sent just before the cursor notification (`cursor`). It is sent only when "the line changed", "the text changed", or "the visible tab changed" (it is not sent when the cursor merely moved within the same line. When the text changed, it is sent even if the cursor did not move).
- Only one `ed.FLineWords: TStringList` is held. It remembers the `FCursorLineSeq` at the time of splitting and the settings (delimiters, empty words, quote character), and when `LineWords` is read, it does not re-split if all of them are the same.
- `CMSplitLine(S, Delims, SkipEmpty, Quote, Dest)`: `Dest.Clear`. It looks at one UTF-8 character at a time. For how it splits, see manual 13.3. When `Quote` is `#0`, not half-width, or contained in `Delims`, quote characters are not interpreted.

### 4.11 Moving a Tab Out (TabTearOff, OnTabDragOut)

When a tab is dragged outside the application window (to the desktop, etc.) and released, that tab is opened by launching one more instance of the same EXE (same as tab detachment in Hidemaru). When it is dropped onto an editor in another window of the same EXE, a new tab is created in that editor and opened (merging; 4.11.6).

| Setting | Behavior |
|---|---|
| `TabTearOff = True` (default) | The component does all of detaching and merging (sending, launching a new EXE, closing the original tab, receiving). Zero lines of application code |
| `TabTearOff = False` | Neither detaching nor merging is done (drops from other windows are not accepted either). `OnTabDragOut` still arrives, so the application can build its own detachment (sample in 4.11.5) |

```pascal
TCMTabDragOutEvent = procedure(Sender: TObject; Index: Integer; X, Y: Integer;
  var TearOff: Boolean) of object;
```

| Argument | Contents |
|---|---|
| `Sender` | That editor (TCMonacoEditor) |
| `Index` | Index of the tab moved out (from 0) |
| `X`, `Y` | Screen position where the mouse was released (screen coordinates) |
| `TearOff` | Whether the component detaches / merges. The value on arrival is `TabTearOff` (but `False` if there is only one empty untitled tab). If set to `False`, the component neither detaches nor merges |

#### 4.11.1 Detection (`TCMTabBinder`)

ATTabs performs tab dragging with LCL drag (`BeginDrag`). When there is no LCL component at the drop destination to receive it, `OnEndDrag` is called with `Target = nil`.

1. `Attach` connects `FTabs.OnEndDrag := TabsEndDrag`.
2. `TabsEndDrag(Sender, Target, X, Y)`: the tab is regarded as moved out only when all of the following are satisfied.
   - `Target = nil`
   - `MultiDocument = True` (tabs are shown)
   - The left button has been released (`GetAsyncKeyState(VK_LBUTTON) >= 0`. If the drag was canceled with `Esc`, the button is still pressed, so that case is excluded)
   - The mouse position (`Mouse.CursorPos`) is not over a window of one's own application (`IsOutsideApp` below)
3. If satisfied, the `Id` of the document of the tab moved out (the document at `ActiveIndex`; ATTabs selects the tab on which the drag started) and the position are remembered, and `QueueAsyncCall(AsyncTabDragOut)` notifies after the drag processing is finished.
4. `AsyncTabDragOut`: looks up the current index from the remembered `Id` (does nothing if it has been closed) and calls the binder's `OnDragOut(Index, X, Y)`. The editor's `BinderTabDragOut` receives it (4.11.2).

- `IsOutsideApp(P)`: `True` if `WindowFromPoint(P)` is 0. Otherwise, the outermost window from `GetAncestor(…, GA_ROOT)` is examined with `GetWindowThreadProcessId`, and `True` if it is not one's own process (`GetCurrentProcessId`). Windows inside WebView2 are children of one's own form, so the outermost is one's own form, giving `False` (no notification when dropped over the editor or the preview). Over another form of one's own application is also `False`.
- The reason for making the notification a `QueueAsyncCall`: closing a tab in the middle of ATTabs' drag processing could make ATTabs touch the vanished tab and crash.
- During the drag, the mouse cursor takes a "cannot drop" shape outside one's own application (because windows of other applications do not receive the LCL drag). Dropping it detaches the tab.

#### 4.11.2 Sending (`TCMonacoEditor.BinderTabDragOut`)

1. Decide the initial value of `TearOff`: `TabTearOff`. However, if `PageCount = 1` and that tab is untitled with empty text, `False`.
2. Call `OnTabDragOut(Self, Index, X, Y, TearOff)` (if set).
3. If `TearOff = False`, finish.
4. If the drop destination is another window of the same EXE and it has a receiver, merge (4.11.6). Finish here.
5. Write a temporary file (in the form of 4.11.4) to `GetTempFileName(GetTempDir, 'cmt')`. The text comes from the copy (`TCMDocument.Text`).
6. Launch one's own EXE (`Application.ExeName`) with `CreateProcessW` (without waiting for it to finish). No launch parameters are added. The environment passed with `CREATE_UNICODE_ENVIRONMENT` is the current environment variables in full (`GetEnvironmentStringsW`; those starting with `CM_TEAROFF=` are excluded) plus `CM_TEAROFF=temporary file` (`TProcess` is not used so that the temp file location is reliably passed as UTF-16 even if it contains Japanese, such as in the user name).
7. If the launch fails, delete the temporary file and `DoError('Could not open in another window: ' + reason)`. The tab is not closed.
8. If the launch succeeds, `PageClose(Index, True)` (close without asking. The text remains in the temporary file).

- The environment variable is passed only to that newly launched EXE (a copy of the environment passed to `CreateProcess`). It is not written to the registry and not broadcast. The sending EXE and other applications are not affected.
- The copy may be stale right after typing (about 0.1 second; 4.2). It catches up before a person starts the drag, so it is not treated as a problem.

#### 4.11.3 Receiving (`TCMonacoEditor`)

**Determining whether launched by detachment** (function `TearOffFile` in the implementation of `uCmonacos`)

- On the first call only, it reads the environment variable `CM_TEAROFF`, remembers it in `GTearOffFile`, and immediately deletes the environment variable (`SetEnvironmentVariable('CM_TEAROFF', nil)`, so that it is not inherited even if that EXE launches yet another EXE).
- If there is a value and the file exists, it was launched by detachment. Otherwise it is a normal launch.
- `GTearOffClaimed: Boolean`: becomes `True` when any editor receives it (received only once).

**The receiving editor**

- An editor with `TabTearOff = True`, not at design time, `GTearOffClaimed = False`, and whose temporary file's `Editor` value equals its own name (`Owner.Name + '.' + Name`, e.g. `Form1.CMonacoEditor1`).
- When to judge: for an editor created from `.lfm`, at `Loaded`. For an editor created in code, when it becomes `Ready` (judged by the `Name` and `TabTearOff` at that time).
- Once received, `GTearOffClaimed := True` and `FTearOffPending := True`. The contents of the temporary file are read into `FTearOffHead` (`TStringList`) and `FTearOffBody`.

**Window position**

- The form of the receiving editor (`GetParentForm`) is set to `Position := poDesigned`, `Left := X`, `Top := Y`. If it sticks out of the work area of that monitor (`Screen.MonitorFromPoint(Point(X, Y)).WorkareaRect`), it is moved to fit inside.
- For an editor created from `.lfm` this is done in `Loaded`, so the form appears at that position from the start. For an editor created in code this is done at `Ready`, so it moves after being displayed.

**Creating the tab** (on the `ready` notification, before calling the user's `OnReady`)

If `FTearOffPending`:

| Temporary file contents | Processing |
|---|---|
| `FileName` is present and that file exists | `PageLoad(0, FileName)` into index 0 (the untitled one right after startup). If `Modified = 1`, then `Text := body` (` *` is added) |
| `FileName` is empty, or the file does not exist | `Text := body` into index 0 (stays untitled. ` *` is added if there is text) |

- After that, `Encoding` and `Language` are set to the values in the temporary file.
- The temporary file is deleted and `FTearOffPending := False`.
- If the temporary file cannot be read or has the wrong form (the first line is not `CMTEAROFF1`), it is not received (normal launch. The temporary file is not deleted).
- If no editor received it (names do not match), the temporary file remains in `%TEMP%`.

#### 4.11.4 Form of the Temporary File

UTF-8. The same form is used by the component's detachment and by the sample at the end of this section.

```
CMTEAROFF1
Editor=Form1.CMonacoEditor1
FileName=C:\docs\a.md
Encoding=0
Language=markdown
Modified=1
X=800
Y=300

(From here to the end is the text)
```

- The first line is a marker. Up to the empty line is the header, and everything after it is the text (nothing breaks whatever the text contains).
- `Editor` is the name of the receiving editor (`Owner.Name + '.' + Name`). `FileName` is empty for untitled. `Encoding` is the number (`Ord`) of `TCMEncoding`.
- Carried over: text, file name, encoding, language, ` *`. Not carried over: Undo history, cursor position, scroll position.
- If the closed tab was the last one, the original editor is left with an empty untitled tab (there is always at least one tab).
- The window of the new EXE shows its content 1 to 2 seconds later, since it waits for WebView2 and Monaco to start.

#### 4.11.5 Building Detachment Yourself (Sample)

A reference example for when the application builds detachment itself without using the component's detachment (`TabTearOff = True`). Set `TabTearOff = False` and do it inside `OnTabDragOut`. In this example, the hand-over uses launch parameters (`/tearoff temporary-file`).

Sending side (the original EXE):

```pascal
uses
  Process, uCmonacos;

const
  TearOffMark = 'CMTEAROFF1';

// When a tab is moved out, open that tab in another EXE and close this tab
procedure TForm1.CMonacoEditor1TabDragOut(Sender: TObject; Index, X, Y: Integer;
  var TearOff: Boolean);
var
  E: TCMonacoEditor;
  P: TCMPage;
  FN, S: string;
  FS: TFileStream;
  Proc: TProcess;
begin
  TearOff := False;   // Do not use the component's detachment (already False if TabTearOff = False)
  E := Sender as TCMonacoEditor;
  P := E.Pages[Index];

  // If there is only one empty untitled tab, moving it out is meaningless, so do nothing
  if (E.PageCount = 1) and (P.FileName = '') and (P.Text = '') then Exit;

  // 1. Write the tab contents to a temporary file (header, empty line, text)
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

  // 2. Launch one's own EXE with the temporary file as an argument (do not wait for it to finish)
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
        DeleteFile(FN);   // If it cannot be launched, leave the tab open without closing it
        MessageDlg('Could not open in another window: ' + Ex.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
  finally
    Proc.Free;
  end;

  // 3. If launched, close this tab without asking (the text remains in the temporary file)
  P.Close(True);
end;
```

Receiving side (the new EXE. Since it is the same EXE, write it in the same form):

```pascal
// FTearFile: string;  … Put in the form's private section. The received temporary file

// Read the temporary file, split into header (Head) and body (Body)
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
        // The file exists: load it into the untitled tab right after startup (no tab is added)
        E.LoadFromFile(FN);
        if Head.Values['Modified'] = '1' then
          E.Text := Body;                          // Replace with the unsaved text (* is added)
      end
      else
        // Untitled, or the file has disappeared: put the text in, staying untitled (* is added)
        E.Text := Body;
      E.Encoding := TCMEncoding(StrToIntDef(Head.Values['Encoding'], 0));
      E.Language := Head.Values['Language'];
    end;
  finally
    Head.Free;
  end;
  DeleteFile(FTearFile);   // Delete after reading is done (even if it fails before reading, the text remains)
  FTearFile := '';
  E.SetFocus;
end;
```

- The temporary file is deleted after the new EXE has finished reading it. If the new EXE fails before reading it, it remains in `%TEMP%` as `cmt*.tmp`.

#### 4.11.6 Merging (Dropping onto Another Window of the Same EXE)

When a tab is dropped onto an editor in another window of the same EXE (one launched separately), a new tab is created in that editor and opened. As with detachment, this is done when `TabTearOff = True` and `TearOff = True`.

**Behavior by drop destination**

| Drop destination | Behavior |
|---|---|
| On an editor in another window of the same EXE (tab strip, text, preview) | Merge (new tab in that editor). The original tab is closed |
| In another window of the same EXE, but not on an editor (menu, buttons, etc.) | Nothing happens |
| The other editor has `TabTearOff = False` or `MultiDocument = False` | Nothing happens |
| The other editor already has the same file open | No merge. Switch to that tab on the other side and bring the other window to the front. The original tab is kept |
| A window that is not the same EXE, or the desktop | Detach (4.11.2) |
| Same EXE, but there is no receiver (`CMTearOffReceiver` below) (e.g. an EXE built with an old version) | Detach (4.11.2) |

**Checking whether it is the same EXE** (the beginning of `SendTearOff`)

1. Get the process ID of the outermost window at the drop position (`WindowFromPoint`, `GetAncestor(GA_ROOT)`) with `GetWindowThreadProcessId`.
2. Get the full path of that process's EXE with `OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)` and `QueryFullProcessImageNameW`. Compare it, case-insensitively, with the full path of one's own EXE (same API with `GetCurrentProcess`).
3. If they are the same, look for that process's receiver window: take them in order with `FindWindowExW(HWND_MESSAGE, previous, 'CMTearOffReceiver', nil)` and choose the one whose process ID is the same.
4. If there is a receiver, merge (next). If it is not the same EXE or there is no receiver, detach (from step 4 of 4.11.2).

**Sending (merge)**

1. Write the temporary file (in the form of 4.11.4. `Editor` is not used but is written anyway).
2. Send `WM_COPYDATA` to the receiver with `SendMessageTimeoutW` (`SMTO_ABORTIFHUNG`, 3 seconds). `dwData` is `$434D544F` ('CMTO'), and the content is a UTF-16 string "full path of the temporary file + #10 + X + #10 + Y" (X and Y are the screen position of the drop).
3. Decide by the reply.

| Reply | Meaning | Sender's processing |
|---|---|---|
| 1 | Received (the other side creates a new tab) | `PageClose(Index, True)`. The other side deletes the temporary file |
| 2 | The other side has the same file open (switched to that tab) | Delete the temporary file. Keep the original tab |
| 0 | Not accepted (not on an editor, `TabTearOff = False`, `MultiDocument = False`) | Delete the temporary file. Do nothing |
| Cannot send, or no reply in 3 seconds | The other side is hung, or sending is impossible (cannot send to an EXE running as administrator) | Delete the temporary file and `DoError('Could not move to the other window')`. Keep the original tab |

**Receiver (`CMTearOffReceiver`. In the implementation of `uCmonacos`)**

- A single invisible message-only window per process (`CreateWindowExW` with parent `HWND_MESSAGE`). The window class name is `CMTearOffReceiver` (`RegisterClassW`. The window procedure is an ordinary function `ReceiverWndProc`).
- It is created when a runtime editor first passes through `CreateWnd` (not created at design time). It is destroyed at the end of the process (`finalization`).
- `GEditors: TFPList`: the list of runtime editors. Added in `CreateWnd`, removed in `Destroy`.

`WM_COPYDATA` in `ReceiverWndProc` (only when `dwData = $434D544F`; otherwise `DefWindowProcW`):

1. Split the string into "temporary file, X, Y". Read the temporary file (`ReadTearOffFile`). If it cannot be read, 0.
2. Decide the receiving editor: among `GEditors`, one that is `Showing`, whose on-screen range contains `(X, Y)`, and for which the outermost window of `WindowFromPoint(X, Y)` is the same as the editor's form (not hidden by another window). If none, 0.
3. If that editor has `TabTearOff = False` or `MultiDocument = False`, 0.
4. If the header's `FileName` is not empty and that editor has it open (`FindPage >= 0`), make `ActiveIndex` that tab, bring the form to the front (`QueueAsyncCall`), and return 2.
5. Otherwise, add the temporary file location to the editor's `FMergeQueue` (`TStringList`), call `QueueAsyncCall(AsyncMerge)`, and return 1.
- No dialog is shown and nothing is waited for inside this (because the sender is waiting for the reply. The tab is created after the reply).

`AsyncMerge` (the receiving editor. Takes the temporary files in `FMergeQueue` in order):

| Temporary file contents | Processing |
|---|---|
| `FileName` is present and that file exists | `OpenFile(FileName)` (opens in a new tab). If `Modified = 1`, `Text := body` for that tab (` *` is added). If it cannot be opened, same as untitled below |
| `FileName` is empty, or the file does not exist | `Text := body` on the tab from `NewPage` (stays untitled) |

- After that, `Encoding` and `Language` are set to the values in the temporary file, and the temporary file is deleted. The new tab becomes the visible tab. The form is brought to the front (`Application.BringToFront`, `SetForegroundWindow`).
- If the same file was opened for another reason in the meantime (opened after the reply), `OpenFile` just switches to that tab. Even then, if `Modified = 1`, the text is replaced.

## 5. Internal Mechanisms

### 5.1 Classes and Roles

| Class | Unit | Role |
|---|---|---|
| `TCMonacoEditor` | `uCmonacos` | Creates and connects the inner components, and exposes the user-facing API and events. Relays events by replacing `Sender` with itself. Theme and colors are received as enumerations and TColor, and passed to the inner components as strings |
| `TCMPage` | `uCmonacos` | One tab (3.3) |
| `TCMFormHook` | `uCmonacos` | Per-form caretaker (3.4) |
| `TCMMonacoView` | `uCmmonacoview` | Displays `editor.html` with `TWVBrowser` and exchanges messages. The list of documents, copies, copies of selection and cursor, right-click menu |
| `TCMDocument` | `uCmmonacoview` | State of one document |
| `TCMTabBinder` | `CMonacoTabs` | Connects the view and ATTabs (4.6) |
| `TCMPreviewBinder` | `CMonacoPreview` | Connects the view and the preview. On every edit or switch, passes the copied text to the preview (edits wait `PreviewDelayMs`; switches are immediate). Synchronizes scrolling (7.4) |
| `TCMMarkdownPreview` | `uCmdpreview` | Displays `preview.html` with `TWVBrowser`. Markdown, code, Mermaid, printing |
| `TCMFindDialog` | `CMonacoFindDlg` | Find/replace dialog (Chapter 9) |
| `TCMEditorAction` and others | `CMonacoActions` | Standard actions (Chapter 8) |

### 5.2 Order in Which Events Are Chained

The view's events are chained in the following order (the one attached later is called first and calls the earlier one).

```
view.OnDocListChange etc.
  → TCMPreviewBinder (updates the preview)
    → TCMTabBinder (updates the tabs)
      → TCMonacoEditor.MonacoXxx (relays to the user's events)
```

- In `TCMonacoEditor.Create`, it first connects itself to the view's events, then chains `TCMTabBinder.Attach` and `TCMPreviewBinder.Attach` in that order.

### 5.3 Messages Between Pascal and JavaScript

- Pascal → JS: `FBrowser.PostWebMessageAsString`. The separator is `#1` (`SEP`). The first element is the command name. There is no reply.
- JS → Pascal: `chrome.webview.postMessage`. Received by the view's `BrowserWebMessageReceived` → `HandleMessage`. The first element is the notification name.
- Free-form strings such as the text are placed in the last argument (everything remaining is taken as the text, so that it does not break even if it contains `SEP`).

**Editor (Pascal → `editor.html`)**

| Command | Arguments | Processing |
|---|---|---|
| `doc.new` | Id, language, text | Create a document (model) |
| `doc.activate` | Id | Display that document (remember the view position of the previous document and restore the view position of the next one) |
| `doc.close` | Id | Delete the document |
| `doc.reset` | Id, text | Replace the content (the Undo history is also cleared) |
| `doc.lang` | Id, language | Change the syntax-highlighting language |
| `doc.dirty` | Id | Mark as modified (even if reverted with Undo, it stays modified until saved) |
| `doc.settextifdiff` | Id, text | Replace only if different from the current text, mark as modified, and return `textsync`. Do nothing if the same |
| `marksaved` | Id | Make the current state the "saved state" |
| `opt` | name, value | Settings (`wordwrap`, `linenumbers`, `fontsize`, `theme`, `readonly`, `tabsize`, `folding`, `matchbrackets`, `occurrences`, `minimap`, `colors` (6 colors: search hit light/dark, cursor line light/dark, selection light/dark)) |
| `undo`, `redo`, `selectall` | ― | Editing |
| `delsel` | ― | Delete the selection |
| `paste` | text | Paste |
| `replacesel` | text | Replace the selection and select the replaced range (for right-click conversion) |
| `seltext` | text | Replace the selection (`SelText :=`). Cursor after it |
| `delto` | `end`, `start` | Delete from the cursor to the end / start |
| `dupline` | ― | Duplicate the cursor line (selected lines) (same processing as `Shift+F10`) |
| `xform` | kind | Tab⇔space, indent |
| `scrollto` | line | Move the view position (to synchronize scrolling) |
| `focus` | ― | Place the focus |
| `toggleow` | ― | Insert and overwrite |
| `setcursor` | line, column | Move the cursor |
| `setsel` | line, column, line, column | Select |
| `find` | word, case, whole word, wrap, backward | Search → `finddone` |
| `replace` | word, replacement, case, whole word, wrap | Replace and search for the next → `finddone` |
| `replaceall` | word, replacement, case, whole word | Replace all → `replacealldone` |

**Editor (`editor.html` → Pascal)**

| Notification | Arguments | Pascal's processing |
|---|---|---|
| `ready` | ― | Ready. Send settings and documents, then `OnReady` |
| `change` | Id, text | Update the copy. If it is the visible document, `OnChange` |
| `modified` | Id, 0/1 | Update ` *`. `OnDocumentChange`, and if it is the visible document, `OnModifiedChange` |
| `cursorline` | string of the cursor line | Update `FCursorLineText` and increment `FCursorLineSeq` by 1 (no event is called) |
| `cursor` | line, column, start position, length, selected string | Update the copy of selection and cursor. `OnCursorChange` |
| `textsync` | Id, text | Replaced by `doc.settextifdiff`. Update the copy and add ` *` |
| `canundo` | Undo 0/1, Redo 0/1 | Copies of `CanUndo` and `CanRedo` |
| `mode` | 0/1 | Insert / overwrite. `OnModeChange` |
| `save` | Id, text | Update the copy and save (`Ctrl+S`) |
| `findreq` | string | Open the find dialog (`Ctrl+F`) |
| `findnext`, `findprev` | ― | `F5`, `Shift+F5` |
| `finddone` | 0/1 | `OnFindDone` |
| `replacealldone` | count | `OnReplaceAllDone` |
| `togglemax` | ― | `F12`. `OnToggleMaximize` |
| `gotfocus` | ― | Record as the last focused editor (`TCMFormHook.SetActive`) |
| `togglepreview` | ― | `Ctrl+Shift+V` |
| `oschange` | 0/1 | The OS theme changed |
| `linenumbers`, `fontsize` | value | `F11`, `Ctrl+wheel` |
| `topline` | line | The first line being displayed (to synchronize scrolling) |
| `contextmenu` | ― | Show the right-click menu |
| `dropfiles` | files | File drop |
| `error` | string | `OnError` |

**Preview (Pascal → `preview.html`)**: `render` (folder, text), `code` (language, text), `clear`, `title` (name for the PDF), `line` (line), `opt` (`theme`, `fontsize`, `layout`, `breaks`, `remote`, `colors`), `copy`, `selectall`, `prepareprint`, `printdone`

**Preview (`preview.html` → Pascal)**: `ready`, `openurl`, `openmd`, `contextmenu`, `copytext`, `scrollline`, `fontsize`, `printready`, `afterprint`, `error`

### 5.4 WebView2 Rules (Must Be Observed)

- In the middle of a WebView2 notification (`WebMessageReceived`, `AcceleratorKeyPressed`, etc.), do not show dialogs or menus, and do not wait by running the message loop (WebView2 does not accept nesting in the middle of a notification, and the notification never returns).
- Therefore, when a dialog, menu, print dialog, or execution of a form shortcut is needed inside a notification, do it after the notification ends with `Application.QueueAsyncCall` (`AsyncContextMenu`, `AsyncDropFiles`, `AsyncRunShortcut`, `AsyncPrint`, `AsyncShowPrintUI`, `AsyncOpenMarkdown`, `AsyncShowError`, `AsyncSetFocus`). The end of an ATTabs drag (`OnEndDrag`) is likewise notified later through `AsyncTabDragOut` for the same reason (4.11). For the `WM_COPYDATA` of tab merging too, the sender is waiting for the reply, so the receiver does not create the tab but creates it later with `AsyncMerge` (4.11.6).
- WebView2 is not created while invisible (it is created once `Showing`). While invisible, the initialization timer (100 milliseconds) waits.

### 5.5 Focus

- Focus is first moved to the editor's outer frame, and then WebView2's `MoveFocus` is asked to move it inside (the window inside WebView2 belongs to a separate Edge process, so it is not moved directly with Windows `SetFocus`).
- If focus is moved to WebView2 in the middle of a notification or a button click, the IME state gets disturbed and input becomes impossible (the conversion window goes off screen). Therefore `ed.SetFocus` is done after the current processing ends via `QueueAsyncCall(AsyncSetFocus)`. Nothing is done for an editor that is invisible or unusable.
- Because focus is inside WebView2, it cannot be tracked with `Form.ActiveControl`. When Monaco receives focus it notifies with `gotfocus`, and `TCMFormHook` records it.

### 5.6 Key Handling (MonacoAccelKeyDown)

Received by WebView2's `AcceleratorKeyPressed` (WebView4Delphi's `OnAcceleratorKeyPressed`). It arrives before the key reaches Monaco. Keys for shortcuts such as combinations with Ctrl and Alt, F1 to F12, and Esc arrive (ordinary character input does not).

1. `KeyDown` (virtual. A derived component can override it. `inherited` inside it triggers `OnKeyDown`). If `Key := 0`, it ends without passing the key to Monaco.
2. `Ctrl+P`: print (`AsyncPrint`). Takes precedence over form shortcuts.
3. `Ctrl+Shift+M`: toggle the minimap.
4. `Ctrl+Tab`, `Ctrl+Shift+Tab`: switch tabs (does nothing if `MultiDocument = False`).
5. Built-in shortcuts (`IsBuiltinKey`: the keys in manual 8.1 plus `Ctrl+Z`, `Ctrl+Y`, `Ctrl+Shift+Z`, `Ctrl+X`, `Ctrl+C`, `Ctrl+V`) go straight to Monaco.
6. If the form's menu or ActionList has the same shortcut, it is executed later with `AsyncRunShortcut` and not passed to Monaco.
7. `Ctrl+Shift+P`: blocked (WebView2's "Print using system dialog". If not blocked, the editor's screen would be printed as is).
8. Anything else goes to Monaco.

- WebView2's default behaviors (reload, developer tools, printing, etc.) are blocked.

## 6. Runtime File Locations and WebView2 Preparation

### 6.1 Locations of monaco and preview

`GetResourceDir` of view and preview:

| Unit | Processing |
|---|---|
| `uCmmonacoview` | `Result := CXResolveRuntimeDir(FResourcePath, 'MonacoFolder', 'monaco')` |
| `uCmdpreview` | `Result := CXResolveRuntimeDir(FResourcePath, 'PreviewFolder', 'preview')` |

- `CXResolveRuntimeDir`: in the order of property (`MonacoPath`, `PreviewPath`) → key in WebView2.ini → EXE folder + default name (`TCTabBrowser_Design.md` Chapter 9).
- `GetResourceDir` is called only at runtime (`BrowserAfterCreated`). The IDE never reads the ini.
- If `editor.html` or `preview.html` is missing, `DoError('editor.html not found: ' + location)` (same form for preview).

### 6.2 WebView2 Preparation (InitTimerTick)

`InitTimerTick` (100 milliseconds) of view and preview performs the following in the same form.

1. Wait at design time and while invisible (the preview stops the timer if hidden and resumes it with `VisibleChanged` when shown).
2. If there is no `GlobalWebView2Loader`, `CXStartWebView2(Err)`. If `False`, stop the timer and `DoError(Err)` (WebView2.ini is missing or WebView2 cannot be started).
3. If `GlobalWebView2Loader.InitializationError`, stop the timer and `DoError(ErrorMessage)`.
4. If `GlobalWebView2Loader.Initialized` (the default environment is ready), stop the timer and create the browser (`CreateBrowser`. Uses the default environment = `UserDataFolder` in WebView2.ini).
5. If not yet, check again at the next tick.

- `CXStartWebView2` creates the loader only the first time in the application. From the second time on, it returns the state of the existing loader (shared with TCTabBrowser and other editors). For details see `TCTabBrowser_Design.md` Chapter 9.
- WebView2 is not started at design time (`csDesigning` is checked in `CreateWnd` and `InitTimerTick`).

## 7. Preview

### 7.1 Display

- The preview's WebView2 is created when it is first shown.
- The text to display is passed from the view's copy by `TCMPreviewBinder`. If the language is markdown, `render` (folder, text); otherwise `code` (language, text).
- Markdown: marked (GFM) → DOMPurify → highlight.js. The original line number is attached to each block (headings, paragraphs, list items, quotes, table rows, and lines inside code blocks). The leading YAML is removed.
- Code: syntax highlighting with highlight.js. Language remapping (e.g. pascal → delphi, bat → dos). Unsupported languages and plaintext are not highlighted. Beyond 500,000 characters, no highlighting (the display with line numbers is still done). Line numbers are drawn separately from the text so that they are not copied. Long lines wrap.
- Images: relative paths counted from the folder of the open file and absolute paths like `C:\...` are displayed. Each drive is assigned to a virtual host (such as `cmdrive-c.example`). With `AllowRemoteImages = False`, http images are not fetched.
- Links: `http`, `https`, and `mailto` go through `openurl` → the default browser (LCL's `OpenURL`. URLs starting with anything else are not opened). Navigation within the preview is blocked. `.md` goes through `openmd` → `AsyncOpenMarkdown` → `OnOpenMarkdown` (if not set, opened in that editor). `#heading` scrolls within the preview. Links to other files are not opened.
- Fonts: body text is `Segoe UI`, `Yu Gothic UI`, `Meiryo` in that order. Code is `Consolas`, `BIZ UDGothic`, `MS Gothic` in that order.
- Color scheme: with `ColorScheme = csEditor`, `PreviewBackColor…`, `PreviewTextColor…`, and `PreviewLinkColor…` are used, and the table borders and code block background are derived from the background and text colors. Code highlighting uses colors close to Monaco's `vs` and `vs-dark`. With `csGitHub`, the github color scheme of github-markdown-css and highlight.js.

### 7.2 Mermaid

- `mermaid.min.js` (12.1.0) is loaded only when a document containing a ` ```mermaid ` block is displayed. Version 12 is used in order to draw `usecase-beta` and the like.
- Drawn with `securityLevel: 'strict'`.
- Colors: lines and borders use the preview's link color blue (dark #3794ff, light #006ab1); background and text use the same colors as the preview.
- Size: initially fitted to the preview width. When the mouse is over it, four buttons appear at the top right (move, zoom out, zoom in, fit to frame). For a diagram whose content has not changed, the zoom and move state is kept even when redrawn. When the preview width changes, diagrams that are not zoomed are re-fitted.
- A syntax error shows the content of the error in place of that diagram.
- http and https images in a diagram (`img: "..."`): with `AllowRemoteImages = False`, the image specification is removed before drawing, and "[External images are not displayed]" is shown below the diagram. With `True`, the image is fetched and drawn; if it cannot be fetched, it is removed, the diagram is redrawn, and "[Could not fetch image]" is shown. For diagrams written in a way that the images cannot be removed cleanly, an error is shown.

### 7.3 Printing

1. `Print` (`Ctrl+P`, the standard action, "Print..." in the preview's right-click menu) is `AsyncPrint`.
2. If the preview is not shown, it is shown only during printing (because printing is not guaranteed to work correctly with a WebView2 that is not on screen). If WebView2 does not exist yet, wait until it is ready.
3. Send `title` (the PDF name: the tab name without the extension. For untitled, "Untitled") (the print dialog uses the page title as the PDF name).
4. `prepareprint`: Mermaid diagrams are drawn separately, in colors for a white background and at paper width, in a place not shown on screen. When finished, `printready`.
5. On `printready`, `AsyncShowPrintUI` (WebView2's print dialog).
6. On `afterprint`, `printdone` (removes the diagrams for printing). If the preview was shown for printing, it is hidden. If the notification does not arrive, it stays shown.

- The diagrams for printing are swapped with the on-screen diagrams by CSS `@media print` (the screen does not change, so there is no flicker before the dialog appears). A diagram that could not be drawn is printed as the on-screen diagram.
- The editor (Monaco) screen is not printed (because only the visible lines are drawn).
- `Ctrl+P` and `Ctrl+Shift+P` are handled the same way when the preview has focus (WebView2's own printing is not triggered).

The print CSS at the end of `<style>` in `preview.html`:

```css
@media print {
  html, body, .markdown-body { background: #fff !important; color: #000 !important; }
  .markdown-body a { color: #0645ad !important; }
  .markdown-body pre, .markdown-body code, .hljs { background: #f6f8fa !important; color: #000 !important; }
  .hljs * { color: #000 !important; }
  .markdown-body th, .markdown-body td { border-color: #999 !important; }
  .markdown-body pre, .markdown-body table, .markdown-body img { break-inside: avoid; }
}
```

- Printing a code tab is highlighted with dark colors for printing (the all-black `.hljs *` above applies to Markdown code blocks).

### 7.4 Synchronizing Scrolling

- The editor reports the first displayed line with `topline`, down to the fraction (position within the line). Even when wrapping, it is synchronized by line number.
- The preview scrolls to the position of the block containing that line, proportionally distributing the position within the block. For empty-line portions, it interpolates between the preceding and following blocks.
- When the height changes due to image loading and the like, it re-synchronizes.
- With `ssBoth`, for about 0.3 seconds right after one side moves, notifications from the opposite side are suppressed (to prevent them from reacting to each other and jittering).
- Inside a long paragraph with many wraps, there is some misalignment because of proportional distribution (not fixed).

## 8. Standard Actions (CMonacoActions)

```pascal
TCMEditorAction = class(TAction)
protected
  function TargetEditor: TCMonacoEditor;                       // Target editor
  function CanRun(AEditor: TCMonacoEditor): Boolean; virtual;  // Whether usable (default: AEditor <> nil)
  procedure Run(AEditor: TCMonacoEditor); virtual; abstract;   // Behavior
public
  constructor Create(AOwner: TComponent); override;            // DisableIfNoHandler := False
  function Execute: Boolean; override;
  function Update: Boolean; override;
end;

TCMEditorToggleAction = class(TCMEditorAction)
protected
  function GetValue(AEditor: TCMonacoEditor): Boolean; virtual; abstract;
  procedure SetValue(AEditor: TCMonacoEditor; AValue: Boolean); virtual; abstract;
  procedure Run(AEditor: TCMonacoEditor); override;            // SetValue(not GetValue)
public
  function Update: Boolean; override;
end;
```

| Procedure | Processing |
|---|---|
| `Create` | `DisableIfNoHandler := False` (so that it can be used with the standard behavior even without `OnExecute`). Each class's `Create` sets `Caption`, `Hint`, and `ShortCut` |
| `TargetEditor` | From the `Owner` of the `ActionList`, follow `Owner` until a `TCustomForm` appears, then `CMActiveEditor(form)` |
| `Execute` | If `inherited Execute` is `True` (there is an `OnExecute`), finish. Otherwise `Run` when `CanRun(TargetEditor)` |
| `Update` | If `inherited Update` is `True` (there is an `OnUpdate`), finish. Otherwise `Enabled := CanRun(TargetEditor)` |
| `TCMEditorToggleAction.Update` | After `inherited Update`, if there is no `OnUpdate`, `Checked := (a target exists) and GetValue(target)` (so it also stays in agreement when toggled by a key) |

- `CanRun` and `Run` of each class are as in "when usable" and "behavior" in manual Chapter 12.
- `TCMEditorOpen`: chooses with `OpenDialog` (the built-in one if not set). With `MultiDocument = True`, multiple files can be selected.
- Not created: Exit (use `TFileExit`), Replace (find and replace share the same dialog), and toggling insert/overwrite (because `ed` has no property to read the current state).

## 9. Find/Replace Dialog (TCMFindDialog)

- `TCMFindDialog = class(TComponent)`. It holds a `TCMFindForm` (`TForm`; created on the spot with `CreateNew`) inside, created when first opened.
- The target is the view. The editor's `ShowFindDialog` opens it with that editor as the target. For the shared dialog, the target and the caption ("Find/Replace - file name") are swapped on `OnActiveChange` and `gotfocus`.
- The search word and replacement word are combo boxes with history. The options are match case, whole word, and loop. The buttons are Find Next, Find Previous, Replace, Replace All, and Close (`Enter` for next, `Esc` to close).
- Results are received through the view's `OnFindDone` and `OnReplaceAllDone`, and "Not found" and "N replaced" are shown at the bottom of the dialog.
- The position, search word, replacement word, history (up to 30 entries), and options are one set per dialog (common to all editors if shared).
- When a single-line range is selected and `Ctrl+F` is pressed, that string becomes the initial search word (the argument of `findreq`).
- Search hits are shown in the `HitColor…` color while the editor does not have focus (`editor.html` changes the selection color used when not focused).

## 10. Decisions

| Item | Decision |
|---|---|
| User code | Works with zero lines. All settings are in the Object Inspector. The component also takes care of preparing WebView2 |
| Runtime file locations | WebView2.ini is always placed in the EXE folder. If a key is empty, the default location in the EXE folder. For `monaco` and `preview`, `MonacoPath` and `PreviewPath` take precedence. Relative paths are counted from the EXE folder |
| Component shape | A composite component with built-in tabs, editor, preview, find, replace, and printing. Any number can be placed on one form |
| Entry point | The visible tab is `ed`; background tabs are `ed.Pages[n]`. Everything in `Pages[n]` is also in `ed` |
| Not two ways to do the same thing | The same operation is not made under two different names |
| Operations on screen | Selection, cursor, editing, search, and printing exist only in `ed` (not placed in `Pages[n]`) |
| Number of tabs | Always at least 1 |
| 1 tab = 1 file | The same file is not opened in two tabs |
| `OpenFile` | Always opens in a new tab (the untitled one right after startup is not used either) |
| How the text is held | The master is Monaco. The Pascal side is a copy for reading (it can be stale for about 0.1 second right after typing). A design with a single Monaco that has the copy poured in on every switch is not used (because the Undo history would be lost) |
| Design that eliminates the copy | Not done. A design that asks Monaco and waits every time `Text` etc. is read cannot wait in the middle of a WebView2 notification (such as `OnKeyDown`), so the text could not be handled inside `OnKeyDown`. Changes are large: mechanisms to avoid this, handling of interruptions, rebuilding the preview, etc. There are almost no situations where the present lag (about 0.1 second) causes trouble |
| `SelText` | Read/write. '' deletes; if nothing is selected, it inserts. After writing, the selection is cleared and the cursor is placed after it |
| `SelStart`, `SelLength` | Read-only. 0-based, in UTF-16 units, and a line break counts as the number of characters of the document's line ending |
| `DeleteToEnd`, `DeleteToStart` | Ignore the selection and delete from the cursor position |
| Selection color | Choose a set with `SelectionColorStyle` (default `scStandard`). With `scCustom`, free choice via `SelectionColorDark` and `SelectionColorLight` |
| Theme, color scheme, colors | `Theme` (default `ctAuto`) and `ColorScheme` are enumerations; colors are TColor. Passed to inner components as strings |
| `LineText`, `LineWords` | The string of the cursor line and the list of words (from 0). Words are split when read. The default delimiters are half-width space, full-width space, tab, comma, and the Japanese comma. Empty words are not included by default. Inside quote characters (default `"`) it does not split, and the quote characters are removed |
| `Text :=` | The Undo history is cleared. ` *` does not disappear until saved. If the text is the same as the current one, nothing is done |
| Startup in an invisible place | WebView2 is not created until it is displayed |
| `MultiDocument` | Default `True`. `False` is a single file only (the content is swapped). Can be changed only at design time |
| `WordWrap` | Default `True` |
| Monaco standard features | Folding, bracket matching, and highlighting of the same word are ON by default; the minimap is OFF by default |
| Preview | The default of `ShowPreview` is `False`. Shown for tabs of every language (a document for Markdown, highlighted code for others). Mermaid is drawn. Scroll synchronization defaults to `ssBoth`. Images from the net are not shown by default. The leading YAML is not shown |
| Printing | Only shows Edge's print dialog. Tabs of every language can be printed (PDF output). `Ctrl+P` is built in (takes precedence over the form). `Ctrl+Shift+P` is blocked |
| Keys | `F11` is line numbers, `F12` is `OnToggleMaximize`, `Ctrl+Tab` and `Ctrl+Shift+Tab` switch tabs, `Ctrl+Shift+M` is the minimap. Built-in behavior can be replaced with `Key := 0` in `OnKeyDown` |
| Confirmation for unsaved documents | `OnQueryClose`. If not set, `ConfirmOnFormClose` (default `True`) |
| Find/replace dialog | One shared per form |
| Tab appearance | Square (`TabFlat = True`), no separator lines. Windows icons per file type. Colors match Windows 11 Explorer, and with `ctAuto` follow the OS switch |
| Standard actions | 25. Toggle actions get their check state automatically |
| Moving a tab out | With `TabTearOff = True` (default `True`), dropping a tab outside the application makes the component launch one more instance of the same EXE and open that tab in it (zero lines of application code). It can be canceled individually with `TearOff := False` in `OnTabDragOut`. Even with `TabTearOff = False`, `OnTabDragOut` arrives, so the application can build its own (sample in 4.11.5). Carried over: text, file name, encoding, language, ` *`. The Undo history is not carried over. For untitled, or when the file has disappeared, it is opened as untitled + ` *`. Not notified when `MultiDocument = False` |
| Hand-over for detachment | The environment variable `CM_TEAROFF` (location of the temporary file) is passed only to the new EXE being launched. Launch parameters are not used (so as not to add rules to the application's launch parameters). Not used: WebView2.ini (shared by all windows, and may be in an unwritable place), the clipboard (would erase the user's copy), and inter-process communication such as DDE (would need a mechanism to wait for the other side to be ready) |
| Editor that receives a detachment | An editor with `TabTearOff = True` whose name equals the temporary file's `Editor` (`Form Name.Editor Name`). Received only once |
| Tab merging | Dropping onto an editor in another window of the same EXE creates a new tab in that editor (4.11.6). The hand-over uses `WM_COPYDATA` (location of the temporary file). If the other side already has the same file open, it just switches to that tab (the original tab is kept). If the other side has `TabTearOff = False` or `MultiDocument = False`, nothing happens |
| Moving a tab within the same EXE | Not done (dropping onto another editor within one's own application does nothing) |
| Moving a tab to another ATTabs | Not allowed (`OptMouseDragOutEnabled = False`) |
| Memory | WebView2 memory (about 60MB per editor) is accepted |
| How to create | It may also be created in code at runtime |

**Not created**

| Item | Reason / alternative |
|---|---|
| `ActivePage` | The visible tab is `ed` |
| Writing to `SelStart`, `SelLength` | Selecting a range is done with `SetSelection` |
| `InsertText` | Done with `SelText :=` |
| `CaretX`, `CaretY` | `GetCursorPos`, `SetCursorPos` |
| `OnStatusChange` (notifies state changes collectively) | Not needed |
| `Lines`, `Pages[n].Lines`, `Pages[n].Line[n]` | Put `Text` into a TStringList and use it |
| `Pages[n].Print` | Printing is something a person operates. Use `ed.Print` for the visible tab |
| `SaveToFile` | The same can be done with `SaveAs(name)` |
| `OnKeyUp`, `OnKeyPress`, mouse events, etc. | Handled inside WebView2, and no notification arrives |
| Making the default of `DefaultLanguage` plaintext, numbering untitled documents | Left as is |
| Math (KaTeX), export to HTML | Not needed |
| Dropping files onto the tab strip | Not supported |
| Regular expression search | Not supported |

## 11. Points to Look At When Investigating Defects

| Symptom | Where to look |
|---|---|
| Stays an empty frame even after startup | `InitTimerTick` (6.2). The message of `OnError`. WebView2.ini, WebView2Loader.dll, the WebView2 runtime |
| editor.html / preview.html not found | `GetResourceDir`, `CXResolveRuntimeDir` (6.1). `MonacoPath`, the values in WebView2.ini |
| An editor in an invisible place does not work | The `Showing` wait (5.4). The preview uses `VisibleChanged` |
| `Text` is stale right after typing | As per the rule in 4.2 (about 0.1 second). Read it inside `OnChange` |
| ` *` appears / does not disappear | `doc.settextifdiff`, `textsync`, `doc.dirty`, `marksaved` (4.2, 5.3) |
| Freezes on dialogs or menus | Whether they are shown in the middle of a notification (5.4) |
| The IME window goes off screen / input is impossible | Whether `SetFocus` is being called directly in the middle of a notification (5.5) |
| Form shortcuts do not work / run twice | The order in `MonacoAccelKeyDown`, `IsBuiltinKey` (5.6) |
| Printing outputs the editor screen as is | Handling of `Ctrl+P` and `Ctrl+Shift+P` (5.6, 7.3) |
| Mermaid diagrams are cut off in printing | `prepareprint`, `printready`, `@media print` (7.3) |
| Tab colors are wrong | `OptShowEntireColor` and per-tab colors (4.6), `ApplyThemeColors` (4.7) |
| No confirmation appears when closing the form | `TCMFormHook.FormCloseQuery`, the replacement of `OnCloseQuery` (3.4) |
| A standard action affects a different editor | Recording of `gotfocus`, `CMActiveEditor` (3.4, 5.5) |
| Scrolling jitters | The 0.3-second suppression (7.4) |
| `OnTabDragOut` does not arrive when a tab is moved out / arrives when dropped inside | Conditions in `TabsEndDrag`, `IsOutsideApp` (4.11.1) |
| Crash after moving a tab out | Whether it is notified later via `AsyncTabDragOut` (4.11.1, 5.4) |
| A new window appears but the tab stays empty | Reading of `CM_TEAROFF` (`TearOffFile`), whether the `Editor` name matches, `TabTearOff` (4.11.3) |
| No new window appears | Launch via `CreateProcessW`, the copy of the environment (4.11.2). The message of `OnError` |
| Dropping onto another window does not merge / detaches instead | Comparison of EXE paths, search for the receiver (`FindWindowExW(HWND_MESSAGE)`), how `ReceiverWndProc` decides the receiving editor (4.11.6) |
| The sender freezes during merging | The `SendMessageTimeoutW` timeout, whether `ReceiverWndProc` waits inside (4.11.6) |

## 12. Changes in This Version (Version 2.21)

Steps for creating the code. Not included in the manual.

| No | File | Change |
|---|---|---|
| 1 | `uCmonacos.pas` | Default of `TabTearOff` is `True` (`FTabTearOff := True`, `default True`). Merging (4.11.6): the sender adds processing at the beginning of `SendTearOff` that looks for the receiver of the same EXE and sends via `WM_COPYDATA`. The receiver is `CMTearOffReceiver` (`RegisterClassW`, `CreateWindowExW(HWND_MESSAGE)`), `ReceiverWndProc`, and `GEditors` in the implementation, destroyed in `finalization`. The editor gets `FMergeQueue` and `AsyncMerge`; at `CreateWnd` (runtime) it is added to `GEditors` and the receiver is created, and at `Destroy` it is removed. `QueryFullProcessImageNameW` is declared by ourselves |
| 2 | `CMonacoTabs.pas` | No change |
| 3 | `uCmmonacoview.pas` | No change |
| 4 | `uCmdpreview.pas` | No change |
| 5 | `CMonacoPreview.pas` | No change |
| 6 | `CMonacoFindDlg.pas` | No change |
| 7 | `CMonacoActions.pas` | No change |
| 8 | `uCXRuntime.pas` | No change |
| 9 | `uCXReg.pas`, `cx_icons.lrs` | No change |
| 10 | `monaco\editor.html`, `preview\preview.html` | No change |
