# TCsEditor Design Document

Author: aotan083
Date: 2026-11-03
Version: 1.1

---

## 1. Purpose and Policy

TCsEditor is an editor component that holds multiple TCSynEdit instances in tabs. Its usage (names, behavior, default values) is the same as TCMonacoEditor; the editing part is switched from WebView2 (Monaco) to TCSynEdit to make it lighter and faster. The preview is split out into a separate component, TCPreview (`TCPreview_Design.md`). The find/replace dialog is TCsFindDialog (chapter 8).

| No | Policy |
|---|---|
| 1 | Wherever it can be matched to TCMonacoEditor, make it identical (names, behavior, default values). What cannot be matched is in chapter 13 |
| 2 | 1 tab = 1 TCSynEdit (`TCsSynEdit`, an internal component that inherits from TCSynEdit; chapter 5). The Undo history, cursor and scroll position are kept per tab |
| 3 | Code of TCSynEdit and TCMonacoEditor whose operation has been verified is not changed. TCSynEdit receives only the changes decided in version 1.1 (`TCSynEdit_Design.md`, chapter 11) |
| 4 | Types and functions of TCMonacoEditor that can be used as they are are reused (2.2). Because they are the same types and the same functions, the behavior and default values are the same, and the way of writing code does not change when switching over |
| 5 | To place editors side by side, place multiple TCsEditor instances and let the application arrange them with TSplitter. The screen is not divided inside the component |
| 6 | It works with 0 lines of code written by the user. Settings are done in the Object Inspector |
| 7 | Build order: the minimap (chapter 10) is built last (chapter 17) |
| 8 | Operating environment: Lazarus 5.0 or later (tested on 5.0 RC1). With Lazarus 4.8, the cx package only compiles; operation is neither verified nor tested (word wrap becomes the prototype component in 4.8). This component has no code that branches by version |

## 2. Files and Packages

### 2.1 Files

| File | Package | Contents |
|---|---|---|
| `uCsEditor.pas` (new) | cx (runtime) | `TCsEditor`, `TCsPage`, `TCsSynEdit`, `TCsFormHook`, `TCsMinimap`, `TCsFindDialog`, `TCsFindForm`, 25 standard actions and their base classes, function `CsActiveEditor` |
| `uCPreview.pas` (new) | cx (runtime) | `TCPreview` (`TCPreview_Design.md`) |
| `cSynedit.pas` | cx (runtime) | `TCSynEdit` (version 1.1; `TCSynEdit_Design.md`) |
| `uCXReg.pas` | cxdsgn (design time) | Registration (chapter 12) |
| `cseditor_icon.lrs` (new) | cxdsgn (design time) | Icons (chapter 12) |
| `cx_icons.lrs` | cxdsgn (design time) | Remove the TCMFindDialog icon (chapter 12) |

- To avoid adding a file for each component, the find/replace dialog, standard actions and minimap are also put in `uCsEditor.pas` (since it is the same unit, no circular reference arises for `FindDialog`).
- interface uses: `Windows, Classes, SysUtils, Controls, Forms, ExtCtrls, StdCtrls, Graphics, Dialogs, Menus, LCLType, LCLIntf, LMessages, ActnList, Clipbrd, Registry, ShellApi, ATTabs, SynEdit, SynEditTypes, SynEditKeyCmds, SynEditMouseCmds, SynEditMarkupWordGroup, SynEditMarkupHighAll, SynEditWrappedView, csynedit, ucmmonacoview, CMonacoTabs, uCmonacos, uCPreview`
- implementation uses: `LazUTF8, LConvEncoding, StrUtils, Math`
- The required packages of cx stay as they are (SynEdit, atflatcontrols_package, WebView4Delphi). `TLazSynEditLineWrapPlugin` (`SynEditWrappedView`) is included in the SynEdit package.

### 2.2 Reused Items

| Item used | Original unit | Use |
|---|---|---|
| `TCMEncoding` (`ceUTF8` to `ceCP932`) | `ucmmonacoview` | Character encoding |
| `TCMFindOption`, `TCMFindOptions` (`foMatchCase`, `foWholeWord`, `foLoop`) | `ucmmonacoview` | Search options |
| Event types (`TCMCursorEvent`, `TCMModeEvent`, `TCMSaveEvent`, `TCMFindDoneEvent`, `TCMReplaceAllDoneEvent`, `TCMNeedFileNameEvent`, `TCMErrorEvent`, `TCMDocIndexEvent`, `TCMQueryCloseEvent`, `TCMFileDropEvent`, `TCMKeyEvent`) | `ucmmonacoview` | Events |
| `CMToHankaku`, `CMToZenkakuKatakana`, `CMToZenkakuHiragana` | `ucmmonacoview` | Right-click conversions |
| `TCMTabImageEvent` | `CMonacoTabs` | `OnGetTabImageIndex` |
| `TCMTheme` (`ctAuto`, `ctLight`, `ctDark`), `TCMSelectionColorStyle` (`scStandard` to `scCustom`), `TCMTabDragOutEvent` | `uCmonacos` | Settings, events |
| `CMSplitLine`, `CMColorToHex` | `uCmonacos` | `LineWords`, colors |
| `DefHitColorLight`, `DefHitColorDark`, `DefCursorLineColorLight`, `DefCursorLineColorDark` | `uCmonacos` | Default colors |

- The reused units are not changed.
- Items that exist only in the implementation of `uCmonacos` and therefore cannot be used are copied to the implementation of `uCsEditor`: `SelStyleLight`, `SelStyleDark` (selection color tables), `DefaultExtFor` (default save extension from the language), and the filters of the built-in dialogs. `DecodeFileBytes`, `EncodeText` and `LoadTextFile` (encoding detection and conversion) in the implementation of `ucmmonacoview` are also copied.
- So that an application only needs to use `uCsEditor`, `TCMEncoding`, `TCMFindOption(s)`, `TCMTheme` and `TCMSelectionColorStyle` are re-exported as type aliases, and `ceUTF8` to `ceCP932`, `foMatchCase`, `foWholeWord`, `foLoop`, `ctAuto`, `ctLight`, `ctDark`, `scStandard` to `scCustom` are re-exported as constants (same approach as `uCmonacos`).
- Placing TCMonacoEditor and TCsEditor on the same form is not supported (both units re-export constants with the same names; the unit later in the uses clause wins).

**Unit references** (one direction. Only `uCPreview` uses `uCsEditor` in its implementation)

```
ucmmonacoview, ucmdpreview, CMonacoTabs, CMonacoPreview, uCmonacos, csynedit (unchanged)
   ↑ uses
uCPreview (TCPreview)  ←─ uses uCsEditor in the implementation
   ↑ uses
uCsEditor (TCsEditor)
```

## 3. Outer Component (TCsEditor)

### 3.1 Structure

```
TCsEditor (TCustomPanel)
 ├ Tabs (TATTabs)                … top edge (alTop). Hidden when MultiDocument = False
 ├ Vertical scroll bar (TScrollBar) … rightmost (alRight). Shown when Minimap = True (10.5)
 ├ Minimap (TCsMinimap)          … right edge (alRight). Shown when Minimap = True (chapter 10)
 └ Body (TCsSynEdit × number of tabs) … remaining area (alClient). Only one, for the visible tab, is Visible
```

- The inner components are created only at runtime. At design time (on the IDE), inner components are not created; `Paint` draws a thin frame and the component name (same as TCMonacoEditor).
- Right after startup, one empty untitled tab is created (inside `Create`; runtime only).
- `Text` and `Caption` of `TControl` are redeclared as public to hide them (they refer to the body and title of the visible tab). `csSetCaption` is removed from `ControlStyle`. `BevelOuter := bvNone`.
- The background color (`Color`) follows `Theme` (dark #1E1E1E, light #FFFFFF; visible for a moment when tabs switch).
- When created with `Create` in code, the component joins the form's close confirmation (`TCsFormHook`) at the moment `Parent` is set (same as TCMonacoEditor).

### 3.2 API and What It Calls Internally

`ed` is `TCsEditor`, `syn` is the `TCsSynEdit` of the visible tab, and `P` is `TCsPage`. The behavior is the same as chapters 4 to 7 of the TCMonacoEditor manual (`TCMonacoEditor_Usage.md`). Differences are in chapter 13.

**Tab contents and files (`ed`, `ed.Pages[n]`)**

| Name | Type / arguments | What it does internally |
|---|---|---|
| `Text` | `string` (read/write) | 4.2 |
| `Lines` | `TStrings` (read/write) | `syn.Lines` of that tab. Writing does `Lines.Assign` (4.2) |
| `Caption` | `string` (read) | The name part of `FileName`. "Untitled" if untitled |
| `FileName` | `string` (read) | `P.FFileName` |
| `Modified` | `Boolean` (read) | `syn.Modified` |
| `Encoding` | `TCMEncoding` (read/write) | `P.FEncoding` |
| `Language` | `string` (read/write) | `P.FLanguage` → `syn.Language` (writing '' gives `DefaultLanguage`). `OnDocumentChange` |
| `LineCount` | `Integer` (read) | `syn.Lines.Count` (1 if 0) |
| `SynEdit` | `TCSynEdit` (read) | The inner component of that tab (for advanced users. `OnChange`, `OnStatusChange` and `PopupMenu` are used by the component, so do not change them) |
| `LoadFromFile` | `const AFileName: string`, returns `Boolean` | 4.3 |
| `Save` | returns `Boolean` | 4.3 |
| `SaveAs` | `const AFileName: string = ''`, returns `Boolean` | 4.3 |
| `Clear` | - | Empty the body, `FFileName := ''`, `Language := DefaultLanguage`, `FEncoding := ceUTF8`, `FLineBreak := #13#10`, `syn.ClearUndo`, `Modified := False` |
| `Close` | `Force: Boolean = False`, returns `Boolean` | 4.1, 4.4 |

- Members of `ed` with the same name call the same-named member of the `TCsPage` of the visible tab.

**Collection of tabs (`ed`)**: `OpenFile(const AFileName: string = '')` (omitting the name shows the open dialog), `NewPage`, `SaveAll`, `CloseAll`, `CanCloseAll`, `FindPage`, `MovePage`, `ActiveIndex`, `PageCount`, `Pages[n]`. Names, arguments, return values and behavior are the same as chapter 5 of the TCMonacoEditor manual. See 4.1 for the internals.

**Operations on the screen (`ed`)**

| Name | What it does internally |
|---|---|
| `SelText` (read/write) | Read: `syn.SelText`. Write: does nothing if `ReadOnly`. `syn.SelText := s` (a line break may be any of #13, #10, #13#10 and counts as one line break; one Undo step). The cursor goes after the text, and the selection is cleared |
| `SelStart`, `SelLength` (read) | Counted as in 6.5 (0-based, UTF-16 units, a line break counts as the number of characters of that tab's line break code) |
| `CanUndo`, `CanRedo` | `syn.CanUndo`, `syn.CanRedo` |
| `GetCursorPos`, `SetCursorPos`, `SetSelection` | 6.5 |
| `LineText` | `syn.Lines[line - 1]` ('' if there is no such line) |
| `LineWords` | 4.10 |
| `LineDelimiters`, `LineSkipEmpty`, `LineQuoteChar` | `FLineDelimiters`, `FLineSkipEmpty`, `FLineQuoteChar` (default values are the same as TCMonacoEditor) |
| `Undo`, `Redo`, `Cut`, `Copy`, `Paste`, `SelectAll` | Same-named members of `syn` (`Cut` and `Paste` do nothing if `ReadOnly`) |
| `DeleteToEnd`, `DeleteToStart`, `DuplicateLine` | 6.4 |
| `ToggleOverwrite` | `syn.InsertMode := not syn.InsertMode` |
| `Find`, `FindNext`, `FindPrev`, `Replace`, `ReplaceAll`, `ShowFindDialog`, `SearchText`, `ReplaceText`, `SearchOptions` | Chapter 8 |
| `CanPrint` | `Preview <> nil` |
| `Print` | If `Preview <> nil`, `Preview.PrintFor(Self)` |
| `SetFocus` | Calls `syn.SetFocus` via `QueueAsyncCall` after the current processing finishes (does nothing when not visible or not enabled; same behavior as TCMonacoEditor) |
| `TopLine` | `Double(syn.TopLine)` |
| `ScrollToLine` | `ALine: Double`. `syn.TopLine := Max(1, Trunc(ALine))` (used by TCPreview) |
| `Ready` | Always `True` at runtime (the inner component is usable as soon as it is created) |
| `IsDarkTheme` | Whether it is currently drawn dark (`True` for `ctDark`, `False` for `ctLight`, the OS setting for `ctAuto`). TCPreview uses it for the border color. For when there is no source to show, the function `CsOsIsDark`, which returns the OS setting, is also placed in the interface |
| `ContextMenu` | `TPopupMenu` (read). The component's right-click menu (chapter 7; for advanced users) |
| `Preview` | `TCPreview` (read/write, published). Chapter 9 |

**Events**

| Name | When it fires |
|---|---|
| `OnReady` | Once, when first displayed at runtime (`QueueAsyncCall(AsyncReady)` from `CreateWnd`. When receiving a detached tab (4.11), after that tab is created) |
| `OnChange` | The body of the visible tab changed (`syn.OnChange`. Fires for human input and also for changes made in code) |
| `OnCursorChange` | The cursor of the visible tab moved (`scCaretX`, `scCaretY` of the inner component's `OnStatusChange`. Not fired if the line and column are the same as last notified. The column is in UTF-16 units) |
| `OnModeChange` | Switched between insert and overwrite (`scInsertMode`) |
| `OnModifiedChange` | The ` *` of the visible tab appeared or disappeared (`scModified`) |
| `OnActiveChange` | The visible tab switched |
| `OnDocListChange` | Tabs were added, removed or reordered |
| `OnDocumentChange` | A tab's name, language or ` *` changed (also for tabs that are not visible) |
| `OnSave` | Saved |
| `OnQueryClose`, `OnNeedFileName`, `OnFileDrop`, `OnToggleMaximize`, `OnFontSizeChange`, `OnLineNumbersChange`, `OnFindDone`, `OnReplaceAllDone`, `OnPopup`, `OnGetTabImageIndex`, `OnTabDragOut`, `OnKeyDown`, `OnError` | Same as TCMonacoEditor (manual 6.2). `OnKeyDown` is in 6.1 |

- `Sender` is always that editor (TCsEditor).
- The default behavior when not set is also the same as TCMonacoEditor (table in manual 6.2. The list for `OnError`'s "same message only once" is kept inside `uCsEditor`).

**Settings (Object Inspector)**

| Name | Type | Default | What is held internally / how it is passed |
|---|---|---|---|
| `MultiDocument` | `Boolean` | `True` | `FMultiDocument`. Can be changed only at design time and between creation and first display (4.5) |
| `ConfirmOnFormClose` | `Boolean` | `True` | `FConfirmOnFormClose` |
| `TabTearOff` | `Boolean` | `True` | `FTabTearOff` (4.11) |
| `OpenDialog`, `SaveDialog` | `TOpenDialog`, `TSaveDialog` | nil | `FreeNotification` |
| `FindDialog` | `TCsFindDialog` | nil | `FreeNotification` (chapter 8) |
| `TabFlat`, `TabSeparator` | `Boolean` | `True`, `False` | `OptShowFlat`, `OptShowFlatSepar` of ATTabs |
| `TabIcons`, `TabImages` | `Boolean`, `TImageList` | `True`, nil | 4.6 |
| `WordWrap` | `Boolean` | `True` | 5.2 on `syn` of all tabs |
| `LineNumbers` | `Boolean` | `False` | `Gutter.LineNumberPart.Visible` of all tabs |
| `Font` | `TFont` | BIZ UDGothic, 14 points, `fqCleartypeNatural` | Passed to `syn.Font` of all tabs (in `FontChanged`; 5.2; the text color is not passed) |
| `FontSize` | `Integer` | 14 | Same as `Font.Size` (clamped to 6 to 72). `stored False` (saved in the .lfm as `Font`. A `FontSize = 16` in a converted .lfm can also be read) |
| `TabSize` | `Integer` | 4 | 5.2 on all tabs (clamped to 1 to 16) |
| `Folding` | `Boolean` | `True` | 5.2 on all tabs |
| `MatchBrackets` | `Boolean` | `True` | 5.2 on all tabs |
| `OccurrencesHighlight` | `Boolean` | `True` | 5.2 on all tabs |
| `Minimap` | `Boolean` | `False` | `FMinimap.Visible` (chapter 10) |
| `Theme` | `TCMTheme` | `ctAuto` | 4.7 |
| `ReadOnly` | `Boolean` | `False` | `syn.ReadOnly` of all tabs |
| `DefaultLanguage` | `string` | 'pascal' | Language of new documents and of documents whose extension is not in the table |
| `AutoLanguage` | `Boolean` | `True` | 4.3 |
| `OpenDroppedFiles` | `Boolean` | `True` | 4.9 |
| `QuotePrefix` | `string` | '> ' | Chapter 7 |
| `HitColorLight`, `HitColorDark` | `TColor` | `DefHitColorLight`, `DefHitColorDark` | 5.3 |
| `CursorLineColorLight`, `CursorLineColorDark` | `TColor` | `DefCursorLineColorLight`, `DefCursorLineColorDark` | 5.3 |
| `SelectionColorStyle` | `TCMSelectionColorStyle` | `scStandard` | Same rule as TCMonacoEditor (except for `scCustom`, the colors from the table are put into the two properties below) |
| `SelectionColorLight`, `SelectionColorDark` | `TColor` | #ADD6FF, #264F78 | Writing sets `SelectionColorStyle := scCustom` (not changed while the .lfm is being loaded). Saved in the .lfm only when `scCustom` |
| `ShowPreview` | `Boolean` | `False` | Chapter 9 |
| `AllowRemoteImages` | `Boolean` | `False` | Chapter 9 (same name as TCMonacoEditor. Reads and writes `AllowRemoteImages` of the connected TCPreview) |
| `Preview` | `TCPreview` | nil | Chapter 9 |
| `Lines` | `TStrings` | empty | 4.2 (the design-time content goes into the first tab) |
| `Align`, `Anchors`, `BorderSpacing`, `Constraints`, `Enabled`, `Visible`, `TabOrder`, `TabStop` | | | As in the LCL |

- The rules for the color settings (the 6 ending in `Color`) are the same as TCMonacoEditor (system colors become the current color via `ColorToRGB`; `clDefault` and `clNone` mean the default value).
- Settings are held in `F…` even before the inner components exist (while the .lfm is being loaded) and passed to all tabs together in `Loaded` (`ApplyAllOptions`). They are also passed to newly created tabs at creation.

### 3.3 TCsPage

```pascal
TCsPage = class
private
  FOwner: TCsEditor;          // Current editor (changes when a tab is moved to another TCsEditor. 4.12)
  FSyn: TCsSynEdit;           // Inner component. nil once closed
  FFileName: string;
  FEncoding: TCMEncoding;
  FLineBreak: string;         // #13#10 or #10
  FLanguage: string;
  FEmpty: TStringList;        // Empty list returned by Lines of a closed page
  function GetIndex: Integer; // FOwner.FPages.IndexOf(Self). -1 if closed
public
  property Caption, FileName, Modified, Encoding, Language, Text, Lines, LineCount, SynEdit;
  procedure Clear;
  function LoadFromFile(const AFileName: string): Boolean;
  function Save: Boolean;
  function SaveAs(const AFileName: string = ''): Boolean;
  function Close(Force: Boolean = False): Boolean;
end;
```

- One is created per tab. The editor holds `FPages`, arranged in the order of the current tabs, and `FAllPages`, all pages ever created. Closed pages also remain in `FAllPages` and are freed when the editor is destroyed (so that nothing crashes if a page that was taken out is used after it is closed).
- When a closed page (`FSyn = nil`) is used, the values read are empty (`Caption`, `FileName`, `Text` are '', `Modified` is `False`, `LineCount` is 0, `Lines` is `FEmpty`, `SynEdit` is nil), and operations do nothing (`Boolean` ones return `False`).
- If the index of `Pages[n]` is out of range, `EListError` is raised.

### 3.4 TCsFormHook

One per form (`TComponent`; the owner is the form). Same structure as `TCMFormHook` of TCMonacoEditor.

| Held item | Contents |
|---|---|
| `FEditors` | List of the TCsEditor instances on that form |
| `FActive` | The TCsEditor that last received focus (`SetActive` from `DoEnter` of the inner component) |
| `FFindDialog` | Shared find/replace dialog (created on first use by `SharedFindDialog`) |
| `FOldCloseQuery` | The form's original `OnCloseQuery` |

- `CreateFor(form)`, `FormCloseQuery`, `ActiveEditor` and `CsActiveEditor(Form)` are the same as 3.4 of TCMonacoEditor.
- When placed on something other than a form (such as a frame), the editor creates its own spare dialog (same).

## 4. Body and Documents

### 4.1 Collection of Tabs

| Operation | Processing |
|---|---|
| `OpenFile('')` | Open dialog (`OpenDialog`, or the built-in one if none). If `MultiDocument = True`, multiple files can be selected. -1 if canceled |
| `OpenFile(name)` | 1. If already open in this editor (`FindPage`), switch to that tab and return its index. 2. If open in another TCsEditor on the same form, switch to that tab of that editor, call `SetFocus` on that editor, and return -1 (the "same file in only one place" rule of 4.12). 3. `MultiDocument = True`: load into a new tab (`NewPageObj`) (4.3), make it the visible tab and return its index. If it cannot be read, raise an exception without leaving the tab. `False`: after the confirmation of 4.4, `LoadFromFile` into tab 0 |
| `NewPage` | `True`: add a new tab at the right end, make it the visible tab and return its index. `False`: after the confirmation of 4.4, `Clear` tab 0 |
| `Close` (`P.Close`) | `True`: after the confirmation of 4.4, `FSyn.Free`, `FSyn := nil`, remove from `FPages`. If it was the visible tab, make its neighbor (right, or left if none) the visible tab. If 0 tabs remain, create an empty untitled one. `OnDocListChange` once. `False`: after the confirmation of 4.4, `Clear` tab 0 |
| `CloseAll` | `Close` from the right in order. `False` if canceled midway |
| `CanCloseAll` | The confirmation of 4.4 for each modified tab (nothing is closed) |
| `SaveAll` | `Save` each modified tab in order (for an untitled one, switch to that tab and then ask for a name) |
| `FindPage(name)` | Search `FPages` by comparing `FileName` case-insensitively |
| `MovePage(From, To)` | `FPages.Move`, rebuild the tabs. `OnDocListChange` |
| `ActiveIndex := n` | Does nothing if out of range or unchanged. Remember whether the previous body had focus. New `syn.Visible := True`; if it had focus, new `syn.SetFocus` (so that Ctrl+Tab can be pressed repeatedly; move focus before hiding), previous `syn.Visible := False`, the tab's `TabIndex`, `OnActiveChange`, `SourceSwitched` of TCPreview, redraw of the minimap, caption of the find dialog |

- The untitled tab right after startup is not reused by `OpenFile` (always a new tab; same as TCMonacoEditor).
- There is always at least one tab.

**New tab (`NewPageObj`)**

1. Create a `TCsPage` and add it to `FAllPages`.
2. `FSyn := TCsSynEdit.Create(Self)`, `FSyn.FEditor := Self`, `Parent := Self`, `Align := alClient`, `Visible := False`, `BorderStyle := bsNone`, `PopupMenu := FMenu`, `HideSelection := False`.
3. `FEncoding := ceUTF8`, `FLineBreak := #13#10`, `FFileName := ''`, `Language := DefaultLanguage`.
4. Pass the settings (5.2, `EditStyle`, `Font`).
5. `FSyn.OnChange := InnerChange`.
6. Add to the right end of `FPages` and rebuild the tabs.

### 4.2 Body (Text, Lines) and Line Breaks

- The body is held only by the inner component (`syn.Lines`). No copy is kept (the divergence that occurs in TCMonacoEditor cannot occur).
- The line break code of a tab (`FLineBreak`) is decided when loading (4.3). A new document uses #13#10.
- A body that ends with a line break has one empty line at the end (same as Monaco; `a` + line break is 2 lines).

| Name | Processing |
|---|---|
| Reading `Text` | Each line of `syn.Lines` joined with `FLineBreak` (nothing is added after the last line) |
| `Text := s` | Does nothing if it equals the current `Text`. Otherwise `SetBodyText(s)`, `syn.ClearUndo`, `syn.Modified := True` |
| `SetBodyText(s)` | `syn.Lines.Text := s`. If `s` ends with a line break (#13#10, #10, #13), `syn.Lines.Add('')` |
| Reading `Lines` | `syn.Lines` (TStrings. `Lines.Text` follows the TStrings convention, with a line break after each line) |
| `Lines := L` | `syn.Lines.Assign(L)` |

- Design-time `Lines` (content saved in the .lfm): at design time it is held in `FDesignLines` (TStringList). At runtime, when the .lfm is read it goes directly into `syn.Lines` of the first tab (because the first tab is created in `Create`). After loading, that tab gets `Modified := False` and `ClearUndo` (in `Loaded`).

### 4.3 Files

| Operation | Processing |
|---|---|
| Read (`LoadFromFile`, `OpenFile`) | If the file is already open in another tab or another TCsEditor (same form), it is not loaded and `False` is returned (`OnError`). The encoding is detected and the file is read with `LoadTextFile` (BOM → valid as UTF-8? → CP932; same as TCMonacoEditor). Line break code: if the first line break found is #13#10 then #13#10, if #10 then #10, if none then #13#10. `SetBodyText`, `FFileName`, `FEncoding`, and if `AutoLanguage` then `Language := CSLanguageForFile(name, DefaultLanguage)`, `ClearUndo`, `Modified := False`, cursor to the start. `OnDocumentChange` |
| Write (`Save`, `SaveAs`) | If untitled, ask for a name (`OnNeedFileName`, or the save dialog if none). Write `EncodeText(Text, FEncoding)` with a `TFileStream` (`fmCreate`). Characters that cannot be represented in CP932 raise an exception (`OnError`, `False`, the ` *` remains). When written, `syn.Modified := False` (the ` *` disappears), `syn.MarkTextAsSaved`, `OnSave`, `OnDocumentChange` |
| Extension changed by `SaveAs` | If `AutoLanguage`, the language is determined again. The tab icon also changes |

- Files are not held locked (opened only during reading/writing; same as TCMonacoEditor. `LockFile` of TCSynEdit is not used).
- `FileName`, `LoadFromFile`, `SaveToFile` and `Save` of the inner component are not used (because they do not convert the encoding). The language is set with `syn.Language`.
- The built-in dialogs (filters, default save extension, initial folder) are the same as TCMonacoEditor (the "built-in dialogs" in chapter 7 of the manual).

### 4.4 Confirmation for Unsaved Documents (DoQueryClose)

Same as 4.4 of TCMonacoEditor (`OnQueryClose` → `ConfirmOnFormClose` confirmation → discard). The confirmation text is also the same.

### 4.5 MultiDocument

Same table as 4.5 of TCMonacoEditor. When `False`, the tabs (ATTabs) are hidden and there is always one tab.

### 4.6 Tabs (ATTabs)

Use the same settings and the same appearance as TCMonacoEditor (`CMonacoTabs.pas`, `uCmonacos.pas`). The difference is that the processing connecting tabs and documents is written directly inside `TCsEditor` (`TCMTabBinder` is not used).

| Item | Processing |
|---|---|
| Rebuild (`RebuildTabs`) | Create tabs in the order of `FPages`. Put the page in the tab's `TabObject`. The title is `Caption`, followed by ` *` if modified, and the hint is the full path |
| Update one (`UpdateTab`) | Title, hint and icon only |
| Click | Switch `ActiveIndex` and focus the body |
| [+] | `NewPage` |
| [x] / middle button | `Close` (confirmation of 4.4). So as not to close in the middle of ATTabs' processing, it is closed later via `QueueAsyncCall` |
| Reorder by dragging | `FPages.Move` |
| Drag outside (`OnEndDrag`) | 4.11, 4.12 |
| Appearance | `OptShowFlat := TabFlat`, `OptShowFlatSepar := TabSeparator`, `OptShowEntireColor := True` (paint the visible tab and the tab under the mouse with per-tab colors), no accent line, `OptMouseDragOutEnabled := False` |
| Text | `ParentFont := False`. Not matched to `Font` and `FontSize` of TCsEditor (the tab height does not change, so enlarging would overflow). As in TCMonacoEditor, the normal-size font (`Screen.SystemFont`) is kept |
| Icons | When `TabIcons = True` and there is no `TabImages`: get it from the extension with `SHGetFileInfo` (`SHGFI_USEFILEATTRIBUTES`, small icon) and put it in an internal image list (once per extension; untitled uses '.txt'). When `TabImages` exists: `OnGetTabImageIndex` (index 0 if not set). `False`: none |

### 4.7 Color Scheme (Theme)

| `Theme` | `EditStyle` of the inner component |
|---|---|
| `ctAuto` | `csVSDark` if the OS is dark, `csVSLight` if light. Follows OS switching |
| `ctLight` | `csVSLight` |
| `ctDark` | `csVSDark` |

- The OS dark/light setting is `AppsUseLightTheme` in the registry `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` (0 means dark; if the value does not exist, light).
- OS switching is received as `WM_SETTINGCHANGE` in the receiver window (4.11.4); when the `lParam` string is 'ImmersiveColorSet', all editors (`GEditors`) are notified via `QueueAsyncCall`. Each editor re-reads the registry and, for `ctAuto`, repaints if it differs from before (`ApplyTheme`).
- `ApplyTheme`: `syn.EditStyle` of all tabs, the tab colors, the background color (`Color`), the minimap. `SourceSwitched` is sent to the TCPreview showing this editor (to match the preview's color scheme).
- Tab and background colors use the same values as `ApplyThemeColors` of TCMonacoEditor (table in manual 9.4).
- Scroll bars: the scroll bars of the inner component are drawn by Windows. When dark, `SetWindowTheme(syn.Handle, 'DarkMode_Explorer', nil)` is applied; when light, `SetWindowTheme(syn.Handle, 'Explorer', nil)` (`uxtheme.dll`). It is applied in `ApplyTheme` and when the window of the inner component is recreated (`TCsSynEdit.CreateWnd`). Before Windows 10 1809 the color does not change (behavior is the same). The vertical strip between the body and the minimap is this scroll bar.

### 4.8 Right-Click Menu

Chapter 7.

### 4.9 File Drop

- Received by the drop handling of the inner component (override of `TCsSynEdit.DoDropFiles`). The file names are put in `FDropFiles` (`TStringList`) and `QueueAsyncCall(AsyncDropFiles)` is used (to avoid showing a confirmation dialog in the middle of a window message).
- `AsyncDropFiles`: `OnFileDrop` (finished if `Handled`) → if `OpenDroppedFiles`, open. With `MultiDocument = True`, all are opened by `OpenFile` (if already open, switch to that tab). With `False`, only the first file. Folders are ignored (same as TCMonacoEditor).
- Drops onto the tab strip and the minimap are not accepted (same as TCMonacoEditor).

### 4.10 Words on the Cursor Line (LineWords)

- One `FLineWords: TStringList` is kept. It remembers the "line string, delimiters, empty-word flag and quote character" of the previous split, and when `LineWords` is read, if all are the same it does not split again.
- The split is done with `CMSplitLine(LineText, FLineDelimiters, FLineSkipEmpty, FLineQuoteChar, FLineWords)` (the same function as TCMonacoEditor).
- Because the body is in the inner component, the split is always done on the current cursor line at read time (the "about 0.1 second right after input" divergence of TCMonacoEditor does not occur).

### 4.11 Detaching and Merging Tabs (TabTearOff, OnTabDragOut)

#### 4.11.1 Same as TCMonacoEditor

Same structure and behavior as 4.11 of `TCMonacoEditor_Design.md`: detecting dragging outside (`Target = nil` in `OnEndDrag`, left button, `IsOutsideApp`, `QueueAsyncCall`), the initial value of `TearOff` (`False` for a single empty untitled tab), `OnTabDragOut`, writing a temporary file and starting the same EXE with `CreateProcessW`, how environment variables are passed, how the receiving editor is determined (`Owner.Name + '.' + Name`), window position, and merging (judging the same EXE, `WM_COPYDATA`, replies 0, 1, 2, 3 seconds, `AsyncMerge`).

#### 4.11.2 Differences

| Item | TCMonacoEditor | TCsEditor |
|---|---|---|
| Environment variable | `CM_TEAROFF` | `CS_TEAROFF` |
| Temporary file marker (line 1) | `CMTEAROFF1` | `CSTEAROFF1` |
| Temporary file name prefix | `cmt` | `cst` |
| Temporary file headings | `Editor`, `FileName`, `Encoding`, `Language`, `Modified`, `X`, `Y` | The items at left plus `LineBreak` (`CRLF`, `LF`) |
| Body | Copy | `P.Text` (no divergence) |
| Receiver window | Class name `CMTearOffReceiver`, message-only (parent `HWND_MESSAGE`) | Class name `CSEditorReceiver`, invisible top-level window (`WS_POPUP`, not shown, no owner). Because the OS theme notification (`WM_SETTINGCHANGE`) reaches only top-level windows (4.7) |
| How to find the receiver | `FindWindowExW(HWND_MESSAGE, previous, 'CMTearOffReceiver', nil)` | `FindWindowExW(0, previous, 'CSEditorReceiver', nil)` |
| `dwData` of `WM_COPYDATA` | `$434D544F` ('CMTO') | `$4353544F` ('CSTO') |
| When creating the tab for a detached tab | On the `ready` notification, before `OnReady` | Inside `AsyncReady`, before `OnReady` |
| Line break code of the received tab | - | `LineBreak` of the heading |

- The names are separated so that, even if the same EXE contains a TCMonacoEditor, they do not receive each other's data.
- The receiver is created when a runtime editor first passes through `CreateWnd`, and destroyed in `finalization`. `GEditors: TFPList` (list of runtime TCsEditor instances) is added to in `CreateWnd` and removed from in `Destroy`.

### 4.12 Moving a Tab to Another TCsEditor on the Same Form

When a tab is dragged onto another TCsEditor on the same form (one placed side by side) and released, that tab is moved. Because the inner component (`TCsSynEdit`) is moved as it is, the Undo history and cursor position are kept.

**Detection** (in `OnEndDrag` of 4.11.1, before checking whether it was dragged outside)

1. Get the control at the release position (`Mouse.CursorPos`) with `FindControlAtPosition(P, False)` and follow `Parent` to find a TCsEditor. If `Target` is not nil, follow from `Target`.
2. If the TCsEditor found is not itself and is on the same form (same `GetParentForm`), move it. This is done with `QueueAsyncCall(AsyncMoveTab)` after the drag processing finishes.
3. If none is found, proceed to 4.11 (whether it was dragged outside).

**Move (`AsyncMoveTab` → `MovePageTo(Index, Dest)`)**

| Situation | Processing |
|---|---|
| The destination has `MultiDocument = False` | Do nothing |
| Only one untitled tab with nothing in it | Do nothing |
| The destination already has the same file open | Switch to that tab of the destination and focus the destination. The original tab is kept |
| Otherwise | The steps below |

1. Source editor: remove the page from `FPages` and `FAllPages` (`syn` is not destroyed). If it was the visible tab, make its neighbor the visible tab, and if 0 tabs remain, create an empty untitled one. `OnDocListChange`.
2. Inner component: `RemoveComponent` (source) → `InsertComponent` (destination), `Parent := destination`, `FEditor := destination`, `PopupMenu := destination's FMenu`.
3. Page: `FOwner := destination`. Add to the right end of the destination's `FPages` and to `FAllPages`.
4. Pass the destination's settings (5.2, `EditStyle`, `Font`).
5. Destination: rebuild the tabs, make the moved tab the visible tab, and focus. `OnDocListChange`, `OnActiveChange`.

- To another window of the same EXE, merging as in 4.11 is used; to a TCsEditor on another form, nothing is moved (nothing happens).

**Same file in only one place**

- The same file is not opened in two places among the TCsEditor instances of the same form (the design does not allow editing the same file on the left and right at the same time). For `OpenFile`, `LoadFromFile` and `SaveAs`, `FindPage` of the other editors in `TCsFormHook.FEditors` is also checked (4.1, 4.3).

## 5. Inner Component (TCsSynEdit)

### 5.1 Structure

```pascal
TCsSynEdit = class(TCSynEdit)       // Placed in the interface, before the implementation of uCsEditor. Not registered
private
  FEditor: TCsEditor;               // Current editor
  FWrap: TLazSynEditLineWrapPlugin; // Word wrap. nil if WordWrap = False
protected
  procedure KeyDown(var Key: Word; Shift: TShiftState); override;                     // Chapter 6
  function DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean; override; // 5.4
  function DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean; override;
  procedure DoDropFiles(const AFiles: array of string); override;                     // 4.9
  procedure ApplyEditStyle; override;                                                 // 5.3
  procedure CreateWnd; override;                                                      // Scroll bars of 4.7
  procedure DoEnter; override;                                                        // 5.3, chapter 9
  procedure DoExit; override;
end;
```

- Ctrl+S, Shift+F10, F12, Ctrl+wheel, drop and the right-click menu of TCSynEdit are received first by this component and turned into the behavior of TCsEditor (the TCSynEdit itself is not changed).
- Notifications from the inner component are received through the inner component's events (not through an override of `StatusChanged`. SynEdit accumulates notifications issued in the middle of a rewrite and emits them together later without going through `StatusChanged`, so an override would miss them).

| Inner component event | TCsEditor processing |
|---|---|
| `OnStatusChange` → `InnerStatus` | When ` *` appears or disappears (compared with the previously notified value): the tab's ` *` (`UpdateTab`) and `OnDocumentChange`, and `OnModifiedChange` if it is the visible tab. Only for the visible tab: `OnCursorChange` (`scCaretX`, `scCaretY`), `OnModeChange` (`scInsertMode`), and on `scTopLine` the `SourceScrolled` of TCPreview and a minimap redraw |
| `OnChangeUpdating` → `InnerUpdating` | Start and end of a rewrite. `InnerChange` when it ends |
| `OnChange` → `InnerChange` | Does nothing in the middle of a rewrite (waits until it ends). If the body change number (`ChangeStamp`) has advanced since the last notification, then only for the visible tab: `OnChange`, `SourceChanged` of TCPreview and a minimap redraw. The inner component's `OnChange` arrives for every Undo record (it can arrive twice for a one-character input), so it is normalized to once per change |

- `TCsSynEdit` also holds its own page (`FPage: TCsPage`) (to know which tab it is when a notification arrives).

### 5.2 How Settings Are Passed

| TCsEditor setting | Inner component |
|---|---|
| `WordWrap` | `True`: `TLazSynEditLineWrapPlugin.Create(Self)` if `FWrap` does not exist. `False`: `FreeAndNil(FWrap)` |
| `LineNumbers` | `Gutter.LineNumberPart.Visible` |
| `Font`, `FontSize` | Remember the inner component's current text color, do `Font.Assign(editor's Font)`, then restore the text color (the text color is decided by the color scheme (4.7). `Font.Color` of TCsEditor is not used) |
| `TabSize` | `TabWidth` and `BlockIndent` to the same value, `BlockTabIndent := 0` |
| `Folding` | `Gutter.CodeFoldPart.Visible`. If set to `False`, `UnfoldAll` |
| `MatchBrackets` | `eoBracketHighlight` in `Options`, `MarkupByClass[TSynEditMarkupWordGroup].Enabled` |
| `OccurrencesHighlight` | `MarkupByClass[TSynEditMarkupHighlightAllCaret].Enabled` (`FullWord := True`, `Trim := True`, `WaitTime := 200`) |
| `ReadOnly` | `ReadOnly` |
| `Theme` | `EditStyle` (4.7) |

**Settings applied at creation** (the same for every tab)

| Item | Value | Reason (to behave like Monaco) |
|---|---|---|
| `Options` | `[eoAutoIndent, eoGroupUndo, eoTabsToSpaces, eoKeepCaretX, eoEnhanceHomeKey, eoDragDropEditing, eoScrollPastEof, eoAltSetsColumnMode, eoShowScrollHint]` + `eoBracketHighlight` if `MatchBrackets` | Do not strip trailing whitespace of lines (do not include `eoTrimTrailingSpaces`), do not place the cursor beyond the end of a line (do not include `eoScrollPastEol`), insert spaces with Tab (Monaco's default) |
| `Keystrokes` | Only the table in 5.5 | Match SynEdit's default keys (such as Ctrl+Y deleting a line) to Monaco |
| `MouseActions` | Add "Shift+Alt+left drag = rectangular selection" (`emcStartColumnSelections`) to the defaults | Monaco's `Shift+Alt+drag` |
| `Gutter.LineNumberPart.ShowOnlyLineNumbersMultiplesOf` | 1 | Number every line |
| `WantTabs` | `True` | Use Tab in the editor |
| `HideSelection` | `False` | Keep showing the search hit even while focus is elsewhere (5.3) |
| `ScrollBars` | `ssAutoBoth` | |

### 5.3 Colors (override of ApplyEditStyle)

1. `inherited ApplyEditStyle` (the colors of `csVSLight` and `csVSDark` of TCSynEdit; `TCSynEdit_Design.md` 7.4).
2. Depending on whether it is dark (`EditStyle = csVSDark`), put in the colors of the TCsEditor settings:
   - `LineHighlightColor.Background := CursorLineColorDark` (`…Light` if light). `Foreground := clNone`, `FrameColor := clNone`.
   - `SelectedColor.Background`: `SelectionColorDark` (`…Light`) if focused, otherwise `HitColorDark` (`…Light`). `Foreground := clNone`.
3. All colors are turned into actual colors by the same rule as TCMonacoEditor (system colors via `ColorToRGB`, `clDefault` and `clNone` mean the default value).

- `DoEnter`: `inherited`, set the selection color to `SelectionColor…`, `TCsFormHook.SetActive(FEditor)`, `SetSource(FEditor)` of TCPreview (chapter 9), and re-point the find dialog's target.
- `DoExit`: `inherited`, set the selection color to `HitColor…` (makes the hit stand out while the find dialog is being used; same as TCMonacoEditor).

### 5.4 Mouse

| Operation | Behavior |
|---|---|
| Ctrl+wheel | Increase or decrease `FEditor.FontSize` by 1 (6 to 72). All tabs. `OnFontSizeChange`. Returns `True` |
| Wheel | `inherited` (does not reach TCSynEdit's Ctrl handling) |
| Right-click | Shows `PopupMenu` (`FMenu` of TCsEditor) |

### 5.5 Key Assignments (Keystrokes)

After `Keystrokes.Clear`, only the following are put in (keys not listed here do nothing in the editor; they go to the form's shortcuts. 6.1).

| Key | Command |
|---|---|
| Left, Right, Up, Down | `ecLeft`, `ecRight`, `ecUp`, `ecDown` |
| Shift+Left, Right, Up, Down | `ecSelLeft`, `ecSelRight`, `ecSelUp`, `ecSelDown` |
| Ctrl+Left, Right | `ecWordLeft`, `ecWordRight` |
| Ctrl+Shift+Left, Right | `ecSelWordLeft`, `ecSelWordRight` |
| Ctrl+Up, Down | `ecScrollUp`, `ecScrollDown` |
| Home, End | `ecLineStart`, `ecLineEnd` |
| Shift+Home, End | `ecSelLineStart`, `ecSelLineEnd` |
| Ctrl+Home, End | `ecEditorTop`, `ecEditorBottom` |
| Ctrl+Shift+Home, End | `ecSelEditorTop`, `ecSelEditorBottom` |
| PageUp, PageDown | `ecPageUp`, `ecPageDown` |
| Shift+PageUp, PageDown | `ecSelPageUp`, `ecSelPageDown` |
| BackSpace, Shift+BackSpace | `ecDeleteLastChar` |
| Delete | `ecDeleteChar` |
| Ctrl+BackSpace | `ecDeleteLastWord` |
| Ctrl+Delete | `ecDeleteWord` |
| Enter, Shift+Enter | `ecLineBreak` |
| Tab | `ecTab` |
| Shift+Tab | `ecShiftTab` |
| Insert | `ecToggleMode` |
| Ctrl+X, Shift+Delete | `ecCut` |
| Ctrl+C, Ctrl+Insert | `ecCopy` |
| Ctrl+V, Shift+Insert | `ecPaste` |
| Ctrl+Z | `ecUndo` |
| Ctrl+Y, Ctrl+Shift+Z | `ecRedo` |
| Ctrl+A | `ecSelectAll` |
| Ctrl+], Ctrl+[ | `ecBlockIndent`, `ecBlockUnindent` |
| Ctrl+Shift+[, Ctrl+Shift+] | `ecFoldCurrent`, `ecUnFoldCurrent` |

- The command names follow `SynEditKeyCmds` of Lazarus 5.0 RC1 (confirm by compiling).
- Keys that TCsEditor handles itself (6.2, 6.3) are not put here (they are received first in `KeyDown`).

## 6. Key Handling

### 6.1 Order (TCsSynEdit.KeyDown)

1. `FEditor.KeyDown(Key, Shift)` (a protected virtual of TCsEditor; inheriting components can override it; `inherited` inside it fires `OnKeyDown`). If `Key = 0`, finish.
2. `Ctrl+P`: `Print`, `Key := 0`.
3. `Ctrl+Shift+M`: `Minimap := not Minimap`, `Key := 0`.
4. `Ctrl+Tab`, `Ctrl+Shift+Tab`: next and previous tab (wraps to the other side at the end; does nothing if `MultiDocument = False`), `Key := 0`.
5. If it is a built-in shortcut (6.2), perform that action and `Key := 0`. However, `Ctrl+Z`, `Ctrl+Y`, `Ctrl+Shift+Z`, `Ctrl+X`, `Ctrl+C` and `Ctrl+V` do nothing here and go to step 7 (they are done by editor commands).
6. If the form's menu or ActionList has the same shortcut, execute it and `Key := 0` (the same shortcut as `ShortCut(Key, Shift)` is searched for in the form's main menu (`Menu.FindItem(…, fkShortCut)`) and in each action of the form's ActionList. For a menu, `Click`; for an action, `Update` and then `Execute` if it is enabled. Same as `FindFormShortcut` of TCMonacoEditor. LCL's `IsShortcut` reads Ctrl and Shift from the real keyboard, so it can disagree with the received key, and is not used).
7. If it is a key of 6.3, perform that action and `Key := 0`.
8. If none apply, `inherited KeyDown` (the `Keystrokes` of 5.5. Ctrl+S, Shift+F10 and F12 of TCSynEdit are already received in step 5, so they do not reach it).

- The "built-in shortcuts" and the six such as `Ctrl+Z` come before the form's shortcuts (same as TCMonacoEditor). For the other keys (6.3, the table in 5.5), the form comes first if it has the same shortcut (same as "Monaco keys: the form comes first" in TCMonacoEditor).
- When the form has `KeyPreview = True`, by LCL rules the form's `OnKeyDown` comes before this order.

### 6.2 Built-in Shortcuts (same as 8.1 of the TCMonacoEditor manual)

| Key | Action |
|---|---|
| Ctrl+S | `Save` the visible tab |
| Ctrl+F | `ShowFindDialog`. If a single-line range is selected, that string becomes the initial search term |
| F5, Shift+F5 | `FindNext`, `FindPrev` |
| Ctrl+Shift+V | Toggle `ShowPreview` (chapter 9; does nothing if there is no `Preview`) |
| Ctrl+Shift+P | Does nothing (if the form has the same shortcut, it is executed in step 6 of 6.1) |
| Shift+F10 | `DuplicateLine` |
| F11 | Toggle `LineNumbers`, `OnLineNumbersChange` |
| F12 | `OnToggleMaximize` |

- `Insert` (insert/overwrite), `Ctrl+A` (select all) and `Ctrl+wheel` behave the same as in 5.4 and 5.5.

### 6.3 Keys Native to Monaco (those marked "usable" in 8.2 of the TCMonacoEditor manual)

| Key | Action | Processing |
|---|---|---|
| `Alt+Up`, `Alt+Down` | Move lines up or down (if a selection exists, all those lines together) | `MoveLines` of 6.4 |
| `Shift+Alt+Up`, `Shift+Alt+Down` | Duplicate lines up or down | `CopyLines` of 6.4 |
| `Ctrl+]`, `Ctrl+[` | Indent, unindent | 5.5 |
| `Ctrl+/` | Toggle line comment | `ToggleComment` of 6.4 |
| `Ctrl+G` | Go to a specified line | `InputQuery('Go to line', 'Line number (1 to line count)', S)`. If it is a number, `SetCursorPos(line, 1)` |
| `Ctrl+Shift+[`, `Ctrl+Shift+]` | Fold, unfold | 5.5 |
| `Ctrl+Enter` | Insert an empty line below and move there (indentation same as the current line) | `InsertLineBelow` of 6.4 |
| `Shift+Alt+drag` | Select a rectangular range | 5.2 (`MouseActions`) |

- Multi-cursor features such as `F1` (command palette) and `Ctrl+D` are not built. `Ctrl+Shift+Enter` and `Ctrl+Shift+K` are not usable in TCMonacoEditor either, so they are not built.
- When `ReadOnly`, editing actions (move lines, duplicate, comment, insert line) do nothing.

### 6.4 Editing Operations

All are performed inside `syn.BeginUndoBlock` to `EndUndoBlock`, rewriting with `syn.TextBetweenPoints[start, end] := string` (logical positions) (one Undo restores).

| Operation | Contents |
|---|---|
| `DuplicateLine` | Insert the selected lines (or the cursor line if nothing is selected) below themselves, and move the cursor (selection) to the duplicated lines |
| `DeleteToEnd`, `DeleteToStart` | If nothing is selected, delete from the cursor to the end or start of the document. If something is selected, `DeleteToEnd` deletes from the start of the selection to the end, and `DeleteToStart` from the start to the end of the selection (the selected part is also deleted). After `SetSelection` the cursor is at the end of the selection, so measuring from the cursor would leave the part before the selected area |
| `MoveLines(up/down)` | Swap the target lines with the one line above (below), moving the cursor and selection along. Does nothing at the edge |
| `CopyLines(up/down)` | Duplicate the target lines above (below). The cursor stays at the original position for up, and goes to the duplicated lines for down |
| `ToggleComment` | The language's comment syntax (table below). If, in the target lines, all lines except empty ones start with the comment marker (after indentation), remove it. Otherwise, add it at the position of the smallest indentation among the target lines. Does nothing for a language without a syntax |
| `InsertLineBelow` | After the cursor line, insert a line break and the current line's indentation (leading spaces/tabs), and move the cursor to the end of that line |
| Right-click conversions (chapter 7) | Replace the selection with the converted string and reselect the replaced range |

| Language | Line comment |
|---|---|
| pascal, javascript, json, typescript, cpp, csharp, java, php, go | `// ` |
| python, shell, yaml, powershell | `# ` |
| sql | `-- ` |
| ini | `; ` |
| bat | `REM ` |
| html, xml, markdown | `<!-- ` before the line, ` -->` after it |
| css | `/* ` before the line, ` */` after it |
| plaintext | none |

### 6.5 How Positions Are Counted (UTF-16)

As in TCMonacoEditor, columns and positions are counted in UTF-16 units (an emoji is 2). The inner component uses UTF-8 byte positions (logical positions), so conversion is done.

| Name | Processing |
|---|---|
| UTF-8 → UTF-16 column | Length of the text from the start of the line up to just before the logical position, converted with `UTF8ToUTF16`, + 1 |
| UTF-16 → UTF-8 column | Byte position reached by advancing one character at a time from the start of the line until the UTF-16 count reaches that value, + 1 (if it exceeds the line length, the end of the line) |
| `GetCursorPos(out Line, Column)` | The line of `syn.LogicalCaretXY`, and its column converted to UTF-16 |
| `SetCursorPos(Line, Column)` | Clamp the line to 1 to the line count, convert the column to UTF-8, and set `syn.LogicalCaretXY` |
| `SetSelection(L1, C1, L2, C2)` | Convert both ends to logical positions and set `BlockBegin`, `BlockEnd`; the cursor goes to the end |
| `SelStart` | Sum of the UTF-16 lengths of each line before the selection start (or the cursor if nothing is selected) + the line break character count (`Length(FLineBreak)`), + the UTF-16 length from the start of that line |
| `SelLength` | Length of the selected string, counted in UTF-16 with line breaks as `FLineBreak` |

### 6.6 Top Line Being Displayed

- `TopLine` is `syn.TopLine` (an integer; it holds no position within a line). With word wrap too, it is the logical line at the top of the display.
- `ScrollToLine(ALine)` is `syn.TopLine := Trunc(ALine)`.

## 7. Right-Click Menu

Same items and same way of showing as 9.7 of the TCMonacoEditor manual. One menu (`FMenu: TPopupMenu`) is created per editor and put in the `PopupMenu` of the inner components of all tabs (the menu held by TCSynEdit is not used).

| Item | Processing |
|---|---|
| Cut, Copy, Paste | `Cut`, `Copy`, `Paste` |
| Copy with quote | Prepend `QuotePrefix` to each line of the selection and put it in `Clipboard.AsText` (the final line break is kept) |
| Append cut, Append copy | `Clipboard.AsText := current contents + SelText` (cutting deletes the selection) |
| Delete | Delete the selection |
| TO UPPER CASE, to lower case | Convert with `UTF8UpperCase`, `UTF8LowerCase` ("conversion" in 6.4) |
| Convert to half-width, Convert to full-width hiragana, Convert to full-width katakana | `CMToHankaku`, `CMToZenkakuHiragana`, `CMToZenkakuKatakana` (same functions as TCMonacoEditor; "conversion" in 6.4) |
| TAB -> spaces, spaces -> TAB | `#9` in the selection to `TabSize` spaces, and `TabSize` spaces to `#9` ("conversion" in 6.4) |
| Indent, Unindent | `ecBlockIndent`, `ecBlockUnindent` |
| Select all, Undo, Redo | `SelectAll`, `Undo`, `Redo` |
| Minimap  Ctrl+Shift+M | Toggle `Minimap` (with a check mark) |
| Preview  Ctrl+Shift+V | Toggle `ShowPreview` (with a check mark). Unavailable if there is no `Preview` |

- Just before showing (`FMenu.OnPopup`), the visibility, enabled state and check of items are decided from whether there is a selection, `ReadOnly`, `Minimap`, `ShowPreview` and `Preview`, and `OnPopup` is called (same table as TCMonacoEditor).
- The items follow the same idea as `TCMMenuItem` of TCMonacoEditor, and the processing is distinguished by number (`Tag`). Items added by the application with `ContextMenu.Items.Add` are placed after them.

## 8. Find/Replace (TCsFindDialog)

### 8.1 Dialog

- `TCsFindDialog = class(TComponent)`, `TCsFindForm = class(TForm)`. Copy `TCMFindDialog` and `TCMFindForm` of `CMonacoFindDlg.pas` and change the target type to `TCsEditor` (appearance, size (470×190), wording, 30 history entries, `Enter`, `Esc` and result display are the same).
- Methods and properties have the same names: `ShowFor(AEditor, InitialText)`, `CloseDialog`, `IsShowing`, `UpdateCaption`, `NotifyFindDone`, `NotifyReplaceAllDone`, `Target`, `SearchText`, `ReplaceText`, `Options`, `FindHistory`, `ReplaceHistory`.
- The caption is "Find/Replace - (name of the target's visible tab)".
- An editor with no `FindDialog` set uses one shared dialog per form (`TCsFormHook.SharedFindDialog`). The target is the editor that last received focus (re-pointed in `DoEnter` of 5.3).

### 8.2 Find/Replace in the Editor

Options for `SearchReplace`: `foMatchCase` → `ssoMatchCase`, `foWholeWord` → `ssoWholeWord`.

| Name | Processing |
|---|---|
| `Find(S, Opt, Forward)` | Does nothing if `S` is empty. `SearchText := S`, `SearchOptions := Opt`. For backward, put the cursor at the selection start (`BlockBegin`); for forward, at the selection end (`BlockEnd`), then `SearchReplace(S, '', opt)` (`ssoBackwards` for backward). If there are 0 hits and `foLoop`, move the cursor to the start (end for backward) and try once more. If found, it is selected and scrolled into view. `OnFindDone(Found)`, and `NotifyFindDone` to the dialog |
| `FindNext`, `FindPrev` | If `SearchText` is empty, open the dialog. Otherwise `Find(SearchText, SearchOptions, True/False)` |
| `Replace(S, R, Opt)` | Does nothing if `ReadOnly`. If the selection equals `S` (also case-sensitively if `foMatchCase`), `SelText := R` (one Undo step). Then `Find(S, Opt, True)` |
| `ReplaceAll(S, R, Opt)` | Does nothing if `ReadOnly`. `BeginUndoBlock`, the count from `SearchReplace(S, R, [ssoReplace, ssoReplaceAll, ssoEntireScope] + opt)`, `EndUndoBlock` (one Undo step). `OnReplaceAllDone(count)`, and `NotifyReplaceAllDone` to the dialog |
| `ShowFindDialog(InitialText)` | `ShowFor(Self, InitialText)` of `FindDialog` (the shared one if none) |

- Regular expressions are not used (same as TCMonacoEditor). Only the visible tab is searched.

## 9. Connection to the Preview (TCPreview)

| Name / trigger | Processing |
|---|---|
| `Preview := P` | If there was a previous TCPreview, `SourceRemoved(Self)` and `RemoveFreeNotification`. `FreeNotification` on the new one. At design time or while loading, only that |
| Reading `ShowPreview` | At runtime, if there is a `Preview`, `Preview.Visible`. At design time or while loading, `FShowPreview`. `False` if there is no `Preview` |
| `ShowPreview := v` | `FShowPreview := v`. At runtime, if there is a `Preview`: if `v = True`, `Preview.SetSource(Self)` and then `Preview.Visible := True`; if `False`, `Preview.Visible := False` |
| `Loaded` (runtime) | If there is a `Preview` and `FShowPreview = True`, `Preview.Visible := True`. If `False`, no change (because another editor may decide the visibility) |
| `DoEnter` of the inner component | `Preview.SetSource(Self)` |
| Body changed (`InnerChange`, visible tab) | `Preview.SourceChanged(Self)` |
| Tab switch, language change, file name change, color scheme change | `Preview.SourceSwitched(Self)` |
| The top line displayed changed (`scTopLine`) | `Preview.SourceScrolled(Self, TopLine)` |
| `Print`, `Ctrl+P` | `Preview.PrintFor(Self)` |
| `AsyncReady` | If there is a `Preview` and `Preview.Source = nil`, `Preview.SetSource(Self)` |
| `Notification` (TCPreview destroyed) | `FPreview := nil` |

- Preview settings (such as `FontSize`) are held in TCPreview (`ed.Preview.FontSize`).
- Only `AllowRemoteImages` can also be read and written through `ed.AllowRemoteImages`, as in TCMonacoEditor. Read: `Preview.AllowRemoteImages` if there is a `Preview`, otherwise `FAllowRemoteImages`. Write: remember in `FAllowRemoteImages` and also put it into `Preview` if there is one. When `Preview := P` is chosen (at runtime, after the .lfm is loaded), `FAllowRemoteImages` is put into P. When one TCPreview is used by multiple editors, the value written last wins.
- The color of the `Splitter` of TCPreview is set by TCPreview to match the Theme of the source (`TCPreview_Design.md` 4.4).
- A link to a `.md` file goes to `OpenFile` of the source editor if TCPreview's `OnOpenMarkdown` is not set.

## 10. Minimap (TCsMinimap)

Built last (chapter 17).

### 10.1 Structure

- `TCsMinimap = class(TCustomControl)`. One at the right edge (`alRight`) of TCsEditor. It draws the body of the visible tab.
- Width is 120 (at 96 dpi; scaled with `Scale96ToForm`).
- `Visible` is toggled by `Minimap` (default `False`). It is shared by all tabs. It can also be toggled by `Ctrl+Shift+M`, the right-click menu and the standard action.

### 10.2 How It Is Drawn (Monaco's "block" style)

| Item | Value (96 dpi; scaled up with the scaling factor) |
|---|---|
| Height of one line `R` | 2px |
| Width of one character | 1px (2px for full-width characters). A tab is `TabSize` characters |
| Left margin | 2px |
| Character shape | At each non-blank character, fill a rectangle of height `R − 1` and width of 1 character (the characters themselves are not drawn) |
| Color | The token color (the line's syntax coloring). If there is no coloring, the body text color |
| Background | The body background color (`syn.Color`) |
| Not drawn | Characters beyond the width |

**How token colors are obtained** (done inside `TCsSynEdit`, because it touches the protected body of the inner component)

- Set `CurrentLines` of that tab's highlighter (`Highlighter`) to that tab's body, then walk from the start of the line with `StartAtLineIndex(line − 1)` up to `GetEol` using `GetTokenEx`, `GetTokenAttribute` and `Next`. The token color is the attribute's `Foreground` (the body text color if `clNone`).

**Which lines are drawn**

- Line count `N`, number of lines that fit in the minimap `M = ClientHeight div R`, number of visible lines in the editor `V = syn.LinesInWindow`, top line of the editor `T = syn.TopLine`.
- If `N <= M`, draw from line 1 (`O = 1`).
- If `N > M`, decide the first line drawn in proportion to the editor position: `O = 1 + Round((T − 1) × (N − M) ÷ Max(1, N − V))` (clamped to `1` to `N − M + 1`).
- Only `M` lines from `O` are drawn (even for a large file, the amount drawn is only what fits on the screen).

**Marker for the visible range (slider)**

- Only while the mouse is over the minimap, overlay a semi-transparent rectangle on the editor's visible range (lines `T` to `T + V − 1`) (same as Monaco's default).
- Color: the background mixed with #797979 at 20%. 35% while the mouse is over it, 50% while dragging.

### 10.3 Operations

| Operation | Behavior |
|---|---|
| Click outside the slider | Scroll so that the clicked line comes to the middle of the editor (`TopLine := line − V div 2`) |
| Drag the slider | Scroll according to the drag amount: add `dy` pixels to `TopLine` as `dy × (N − V) ÷ Max(1, (Min(N, M) − V) × R)` lines (moving the slider from one end of the minimap to the other moves from one end of the document to the other). Does not move if `N <= V` |
| Wheel | Scrolls the same as the editor |

### 10.4 When to Redraw

- The drawn picture is kept in a `TBitmap`, and `Paint` copies it and overlays the slider.
- The picture is rebuilt on: switching the visible tab, body changes (wait 100 milliseconds and batch), editor scrolling (`scTopLine`), and changes of color scheme, `TabSize` or size.
- Word wrap is not considered (drawn by logical lines).

### 10.5 Vertical Scroll Bar (While the Minimap Is Shown)

The order is made the same as TCMonacoEditor: "body | minimap | vertical scroll bar" (so the vertical divider looks like a single line).

| Item | Processing |
|---|---|
| Component | `FVBar: TScrollBar` (`Kind := sbVertical`, `TabStop := False`). At the right edge (`alRight`) of TCsEditor. Like the minimap, created only at runtime |
| Show / hide | `Minimap = True`: `FVBar.Visible := True`, and `ScrollBars := ssAutoHorizontal` on the inner components of all tabs (hides the inner component's vertical scroll bar). `False`: `FVBar.Visible := False`, and `ScrollBars := ssAutoBoth` on all tabs (as before). The same value is also applied to new tabs and moved-in tabs (5.2) |
| Order | Two `alRight` controls are arranged in order of position, so when showing, set `FMinimap.Left := 0` and `FVBar.Left := Width` to put the scroll bar rightmost |
| Values | Matched in displayed lines (lines after word wrap and folding) of the inner component of the visible tab. `Min := 1`, `PageSize := LinesInWindow`, `Max := displayed line count + LinesInWindow − 1` (because of `eoScrollPastEof`, the last line can come to the very top; same as the inner component's scroll bar), `Position := TopView`. The displayed line count is `ViewedTextBuffer.ViewedCount` and the top displayed line is `TopView` (both are protected in the inner component; read inside `TCsSynEdit`) |
| When to resync | `scTopLine`, `scLinesInWindow` (`OnStatusChange` of the inner component), body changes (`InnerChange`), tab switches, changes of color scheme, font size or word wrap, and size changes of TCsEditor |
| When moved | `FVBar.OnScroll`: `TopView := Position` of the inner component of the visible tab. Does nothing while resyncing (`FUpdatingBar`) |
| Color | Same as the inner component's scroll bar (4.7; dark uses `DarkMode_Explorer`) |

## 11. Standard Actions

Same 25 as TCMonacoEditor (display name, default shortcut, behavior, when enabled, check state). The name prefix is `TCsEditor`.

| No | Action | Behavior |
|---|---|---|
| 1 | `TCsEditorNew` | `NewPage` |
| 2 | `TCsEditorOpen` | Choose with `OpenDialog` (the built-in one if none) and `OpenFile`. Multiple selection if tabs are available |
| 3 | `TCsEditorSave` | `Save` |
| 4 | `TCsEditorSaveAs` | `SaveAs` |
| 5 | `TCsEditorClose` | `Close` |
| 6 | `TCsEditorPrint` | `Print` (enabled when: `CanPrint`) |
| 7 | `TCsEditorSaveAll` | `SaveAll` |
| 8 | `TCsEditorCloseAll` | `CloseAll` |
| 9 | `TCsEditorUndo` | `Undo` |
| 10 | `TCsEditorRedo` | `Redo` |
| 11 | `TCsEditorCut` | `Cut` |
| 12 | `TCsEditorCopy` | `Copy` |
| 13 | `TCsEditorPaste` | `Paste` |
| 14 | `TCsEditorSelectAll` | `SelectAll` |
| 15 | `TCsEditorDuplicateLine` | `DuplicateLine` |
| 16 | `TCsEditorDeleteToEnd` | `DeleteToEnd` |
| 17 | `TCsEditorDeleteToStart` | `DeleteToStart` |
| 18 | `TCsEditorFind` | `ShowFindDialog` |
| 19 | `TCsEditorFindNext` | `FindNext` |
| 20 | `TCsEditorFindPrev` | `FindPrev` |
| 21 | `TCsEditorMinimap` | Toggles `Minimap` (checked: `Minimap`) |
| 22 | `TCsEditorPreview` | Toggles `ShowPreview` (checked: `ShowPreview`; enabled when: `Preview <> nil`) |
| 23 | `TCsEditorLineNumbers` | Toggles `LineNumbers` (checked: `LineNumbers`) |
| 24 | `TCsEditorWordWrap` | Toggles `WordWrap` (checked: `WordWrap`) |
| 25 | `TCsEditorRemoteImages` | Toggles `AllowRemoteImages` (checked: `AllowRemoteImages`; enabled when: `Preview <> nil`) |

- The base classes `TCsEditorAction` and `TCsEditorToggleAction` have the same structure as `TCMEditorAction` and `TCMEditorToggleAction` of TCMonacoEditor (`TCMonacoEditor_Design.md`, chapter 8). The target is `CsActiveEditor(form)`.
- The category in the action list editor is `CX TCsEditor` (kept separate from `CX` of TCMonacoEditor, because two identical display names side by side cannot be told apart).

## 12. Registration and Icons

**Registration (`uCXReg.pas`)**

- Add `uCsEditor` and `uCPreview` to uses.
- `RegisterComponents('CX', [..., TCsEditor, TCsFindDialog, TCPreview])`.
- `RegisterActions('CX TCsEditor', [the 25 of chapter 11], nil)` (in the order of the table in chapter 11).
- Add `{$I cseditor_icon.lrs}` to initialization.

**Icons**

Before drawing, show a sample and get confirmation.

| Component | Picture |
|---|---|
| `TCsEditor` | Two tabs on top (the left one is active); below them, a thin vertical strip on the left (line numbers) and 3 horizontal lines of different lengths on the right (lines of text) |
| `TCPreview` | A document (one thick line on top = heading, three thin lines below it), with a small eye at the lower right |
| `TCsFindDialog` | "A→B" inside a dialog frame. The arrow is green |
| `TCMFindDialog` (replacement) | "A→B" inside a dialog frame. The arrow is blue |

- A magnifying glass is not used (it is reserved for a future "search component").
- Sizes and resource names: PNGs of 24×24, 36×36 and 48×48 (32-bit, with transparency). Names are the class name (lowercase), `_150`, `_200` (e.g. `tcseditor.png`, `tcseditor_150.png`, `tcseditor_200.png`). Line thickness and colors follow the same rules as `CPageControl_Design.md` 9.1 (lines are dark gray, colored parts are blue; only the arrow of `TCsFindDialog` is green).
- Create `cseditor_icon.lrs` from the 4 × 3 PNGs (`lazres`) and add it to `cxdsgn.lpk`. The source PNGs are placed in the icons folder of cxdsgn.
- Remove `TCMFindDialog`, `TCMFindDialog_150` and `TCMFindDialog_200` from `cx_icons.lrs` (because with two resources of the same name, which one is used is undefined).

## 13. Differences from TCMonacoEditor

| Item | TCMonacoEditor | TCsEditor |
|---|---|---|
| Editing part | Monaco (WebView2) | TCSynEdit |
| How the body is held | Monaco is authoritative, Pascal holds a copy (about 0.1 second divergence) | Only the inner component (no divergence) |
| `OnChange` | About 0.1 second after input stops | Every time the body changes (also when changed in code) |
| `OnKeyDown` | Only keys used for shortcuts | Ordinary character keys also arrive |
| Form's `KeyPreview` | Has no effect while the editor has focus | Works |
| `Lines` | None | Yes (TStrings) |
| `Font` | None (only `FontSize`) | Yes. `FontSize` is the same as `Font.Size` |
| Preview | Held inside | TCPreview (a separate component). Connected via `Preview` |
| Preview settings | `ed.…` (such as `PreviewFontSize`) | `ed.Preview.…` (such as `FontSize`). Only `AllowRemoteImages` is also the same as `ed.AllowRemoteImages` |
| `Monaco`, `JapaneseUI`, `MonacoPath` | Yes | None (`SynEdit` instead) |
| `Monaco.PopupMenu` | Yes | `ContextMenu` |
| Languages with syntax coloring | All in the table of manual 9.2 | In the table, powershell, yaml and go have no coloring (SynEdit has no highlighter for them; plaintext has none in either) |
| `OnOpenMarkdown` | `ed.OnOpenMarkdown` | `OnOpenMarkdown` of TCPreview |
| `F1` command palette, multi-cursor | Yes | None |
| Scroll synchronization | Down to the position within a line | Line by line |
| Minimap | Monaco's own | Self-drawn (chapter 10; word wrap is not considered) |
| Same file | One within one editor | One among the TCsEditor instances of the same form (4.12) |
| Moving a tab to another editor on the same form | Not done | Done (4.12) |
| Category of standard actions | `CX` | `CX TCsEditor` |

## 14. Decisions

| Item | Decision |
|---|---|
| Names | The tabbed version of TCSynEdit is `TCsEditor`, the page is `TCsPage`, the find/replace dialog is `TCsFindDialog`, and the standard actions are `TCsEditor…` |
| Usage | Wherever it can be matched to TCMonacoEditor, everything is the same (names, behavior, default values). For a new document, `NewPage` |
| Tabs | ATTabs. Appearance and behavior are the same as TCMonacoEditor |
| Contents of one tab | One `TCsSynEdit`, which inherits from TCSynEdit |
| `Lines`, `Text` | Both are provided, as in TSynEdit |
| `Font`, `FontSize` | `Font` is provided, and `FontSize` is the same as `Font.Size`. Default is BIZ UDGothic, 14 points |
| Color scheme | `Theme` (`ctAuto`, `ctLight`, `ctDark`). The inner component uses `csVSLight` and `csVSDark`. Colors are the same as TCMonacoEditor (VS Code) |
| Syntax coloring | The mapping of extensions to languages is the same as TCMonacoEditor. The coloring is what TCSynEdit has (`TCSynEdit_Design.md` 7.2) |
| Bracket matching | With `MatchBrackets` alone: `( )`, `[ ]`, `{ }` (in Pascal `{ }` is a comment, so it is excluded), plus keyword pairs (such as `begin`/`end`) and tag pairs |
| Adding `end` after `begin` | Not done |
| Word wrap | `WordWrap` (`TLazSynEditLineWrapPlugin`) |
| Find/replace | The same dialog as TCMonacoEditor is built as `TCsFindDialog`. `TCMFindDialog` is neither used nor changed |
| Preview / printing | TCPreview. Shown with `ShowPreview`. Printing (and PDF saving) is done by TCPreview |
| Placing editors side by side | Place multiple TCsEditor instances. A tab can be moved to another TCsEditor on the same form by dragging. The same file in only one place |
| Minimap | Self-drawn (looks the same as Monaco). Built last |
| Character encoding | Same as TCMonacoEditor (detects UTF-8, UTF-8 BOM, UTF-16 LE/BE and CP932 when reading, and writes in the same encoding) |
| Line break code | Keep the CRLF or LF seen at load time (mixed line breaks are not preserved) |
| Holding files locked | Not done |
| TCMonacoEditor and TCsEditor on the same form | Not placed (not supported) |

**Not built**

| Item | Reason / alternative |
|---|---|
| Multi-cursor (such as `Ctrl+D`), command palette (`F1`) | Not needed |
| Automatic completion of `begin`/`end` | Not needed |
| Editing the same file simultaneously on left and right (sharing SynEdit's text) | Do not open it; switch to the one that is already open |
| Folding of Markdown headings | Not built |
| Splitting the screen inside the component | Place multiple TCsEditor instances |
| Regular expression search | Not supported, as in TCMonacoEditor |
| Dropping files onto the tab strip | Not supported, as in TCMonacoEditor |
| SynEdit printing (`TSynEditPrint`) | Printing is done by TCPreview (Printer4Lazarus is not added) |

## 15. What to Look At When Investigating Defects

| Symptom | Where to look |
|---|---|
| Ctrl+S, F12, Shift+F10 behave as in TCSynEdit (saving without encoding handling, line numbers) | Whether `TCsSynEdit.KeyDown` receives them first (6.1) |
| Form shortcuts do not work, or fire twice | The order in 6.1, the way shortcuts are searched in step 6 |
| SynEdit default keys (such as Ctrl+Y deleting a line) work | `Keystrokes.Clear` and the table in 5.5 |
| Trailing whitespace of lines is removed | Whether `eoTrimTrailingSpaces` is in `Options` (5.2) |
| Colors return to default when a file is opened | `ApplyEditStyle` in `SetLanguage` of TCSynEdit 1.1. The override of `TCsSynEdit.ApplyEditStyle` |
| Cursor line / selection colors differ from the settings | The order in 5.3 (are they set after `inherited`?) |
| The selection is invisible when focus is lost | `HideSelection := False`, `HitColor` in `DoExit` (5.3) |
| Saved encoding or line breaks are wrong | The detection in 4.3, `FLineBreak`, `EncodeText` |
| The last line break disappears or increases | `SetBodyText` in 4.2 and how `Text` is joined |
| Positions (`SelStart`, column) are off | The UTF-16 conversion in 6.5 |
| Nothing changes when the OS theme is switched | Whether the receiver window is top-level, and `'ImmersiveColorSet'` of `WM_SETTINGCHANGE` (4.7) |
| The preview keeps showing another editor's content | `SetSource` in `DoEnter` (chapter 9) |
| Moving a tab to another editor does nothing or crashes | `FindControlAtPosition` and how it is followed, and whether it is done later by `AsyncMoveTab` (4.12) |
| Menu or colors of a moved tab are wrong | Steps 2 and 4 of 4.12 |
| Detach/merge gets mixed up with TCMonacoEditor | The names in 4.11.2 (environment variable, marker, receiver class name, `dwData`) |
| Minimap colors are off | `CurrentLines` and `StartAtLineIndex` of the syntax coloring (10.2) |
| Scroll bars do not become dark | `SetWindowTheme` in 4.7. Whether it is re-applied in `CreateWnd` of the inner component |
| Tab text overflows when the font is enlarged | `FTabs.ParentFont := False` in 4.6 |
| The minimap is heavy | Whether only the screen's worth is drawn, and whether it waits 100 milliseconds on body changes (10.2, 10.4) |

## 16. Changes in This Version

Steps for building the code. Not included in the manual.

| No | File | Change |
|---|---|---|
| 1 | `uCsEditor.pas` | Create new (everything in this design document) |
| 2 | `uCPreview.pas` | Create new (`TCPreview_Design.md`) |
| 3 | `cSynedit.pas` | `TCSynEdit_Design.md` chapter 11 |
| 4 | `cx.lpk` | Add `../source/uCsEditor.pas` (UnitName `uCsEditor`) and `../source/uCPreview.pas` (UnitName `uCPreview`) |
| 5 | `source/design/uCXReg.pas` | Chapter 12 |
| 6 | `cseditor_icon.lrs` (new), `cxdsgn.lpk` | Chapter 12 |
| 7 | `cx_icons.lrs` | Remove the 3 of `TCMFindDialog` (chapter 12) |
| 8 | `uCmonacos.pas`, `uCmmonacoview.pas`, `uCmdpreview.pas`, `CMonacoTabs.pas`, `CMonacoPreview.pas`, `CMonacoFindDlg.pas`, `CMonacoActions.pas`, `preview.html` | No change |

**1.1 (2026-11-03)**: Changes made in response to the results of the confirmation tests of 1.0.

| No | Chapter | 1.0 | 1.1 | Reason |
|---|---|---|---|---|
| 1 | 5.1 | Received by overriding `StatusChanged` of the inner component | Received through the inner component's events `OnStatusChange`, `OnChangeUpdating` and `OnChange`, and `OnChange` is made once per change using `ChangeStamp` | The override misses notifications. `OnChange` arrived twice for a one-character input |
| 2 | 6.1 | Form shortcuts use `IsShortcut` | Search the menu and ActionList ourselves (same as TCMonacoEditor) | `IsShortcut` reads Ctrl and Shift from the real keyboard |
| 3 | 6.4 | `DeleteToEnd` and `DeleteToStart` ignore the selection and work from the cursor | If something is selected, from the start of the selection to the end, and from the start to the end of the selection | After `SetSelection` the cursor is at the end of the selection |
| 4 | 4.7 | Scroll bars do not change with Theme | Apply `DarkMode_Explorer` when dark | The color of the scroll bar and of the strip between it and the minimap did not change |
| 5 | 4.6 | Tab text follows `Font` | Tabs use `ParentFont := False` (normal size) | Tab text overflowed when the font was enlarged |
| 6 | 3.2, 9, 11 | `AllowRemoteImages` only via `ed.Preview` | Add `ed.AllowRemoteImages` (same as TCMonacoEditor) | To match TCMonacoEditor |
| 7 | 3.2 | `OpenFile(const AFileName: string)` | `OpenFile(const AFileName: string = '')` | The name could not be omitted (to match TCMonacoEditor) |
| 8 | `TCPreview_Design.md` 4.4 | The color of `Splitter` is not set | Set it to match the source's Theme | The color of the Splitter did not change when the Theme changed |
| 9 | 10.5 | The minimap is to the right of the inner component's vertical scroll bar | While the minimap is shown, hide the inner component's vertical scroll bar and place TCsEditor's scroll bar to the right of the minimap | The order differed from TCMonacoEditor, and the vertical divider looked like two lines |
| 10 | 4.1 | Switching tabs does not move focus | If the previous body had focus, move it to the new body before hiding the previous one (the same when closing a tab and showing its neighbor) | After Ctrl+Tab, focus was lost and a click was needed every time |
| 11 | 3.2, 5.2 | `Font.Assign` also passes the text color | The text color is not passed (the color scheme's color is kept) | Changing the font made the text black even in dark mode |

## 17. Build Order

| Order | Contents | What to check |
|---|---|---|
| 1 | TCSynEdit 1.1 (color scheme, languages, Markdown) | Whether the colors of the left-edge columns (line numbers, folding), cursor line and bracket matching stay intact when switching extensions and color schemes (where colors previously failed) |
| 2 | TCsEditor (tabs, files, encodings, keys, right-click, find, replace, standard actions) | Whether it behaves the same as the TCMonacoEditor manual |
| 3 | TCPreview | Switching the source, printing, scroll synchronization |
| 4 | Detaching and merging tabs, moving to another editor | |
| 5 | Minimap | |
| 6 | Icons, registration | Show a sample before drawing |
