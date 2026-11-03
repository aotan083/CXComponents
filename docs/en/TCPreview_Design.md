# TCPreview Design Document

Author: aotan083
Date: 2026-11-03
Version: 1.1

---

## 1. Purpose and Policy

TCPreview is a component that displays the body text of a TCsEditor as a preview (a document for Markdown, color-coded code for everything else) and prints it (saves it as PDF). It is a separate component from the editor and can be placed anywhere on a form.

| No | Policy |
|---|---|
| 1 | The content uses the TCMonacoEditor preview (`TCMMarkdownPreview` / `preview\preview.html`) as is. Display, Mermaid, printing, links, and images behave the same as in TCMonacoEditor (`TCMonacoEditor_Design.md` chapter 7) |
| 2 | The connection is made by selecting this component in the `Preview` property of TCsEditor. One TCPreview can be selected from multiple TCsEditors |
| 3 | What is displayed is the visible tab of the "source" TCsEditor. The source is the most recently focused TCsEditor (chapter 3) |
| 4 | Show/hide is done with `ShowPreview` of TCsEditor (`Ctrl+Shift+V`). Changing `Visible` of TCPreview directly has the same effect |
| 5 | Setting names and default values are the same as the TCMonacoEditor preview settings. The leading `Preview` is dropped (`PreviewFontSize` -> `FontSize`, etc.) |
| 6 | TCMonacoEditor files such as `uCmdpreview.pas` and `preview.html` are not changed |
| 7 | Operating environment: Lazarus 5.0 or later (tested on 5.0 RC1, same as TCsEditor). Lazarus 4.8 only compiles the cx package; operation is not verified or tested |

## 2. Files and Packages

| File | Package | Content |
|---|---|---|
| `uCPreview.pas` (new) | cx (runtime) | `TCPreview` |
| `uCmdpreview.pas` | cx (runtime) | `TCMMarkdownPreview` (unchanged; used internally) |
| `uCXReg.pas` | cxdsgn (design time) | Add `RegisterComponents('CX', [..., TCPreview, ...])` |
| `cseditor_icon.lrs` (new) | cxdsgn (design time) | Icons (`TCPreview`, `_150`, `_200`. `TCsEditor_Design.md` chapter 12) |
| `preview\preview.html` and `preview\lib\` | Runtime files | Same as TCMonacoEditor (unchanged) |

- uses in the interface of `uCPreview`: `Classes, SysUtils, Controls, Graphics, ExtCtrls, Forms, Dialogs, ucmdpreview, CMonacoPreview, uCmonacos`
- uses in the implementation: `uCsEditor` (to treat the source as a TCsEditor; because it is used in the implementation rather than the interface, there is no circular reference)
- Reused types: `TCMColorScheme`, `CMColorToHex`, and the default color constants (`DefPreview...`) come from `uCmonacos`; `TCMSyncScroll` from `CMonacoPreview`; `TCMOpenMarkdownEvent` from `ucmdpreview` (they are the same types, so the way of writing does not change when switching over from TCMonacoEditor).
- So that an application only needs to use `uCPreview`, `TCMColorScheme` and `TCMSyncScroll` are re-exported as type aliases, and `csEditor`, `csGitHub`, `ssNone`, `ssEditorToPreview`, and `ssBoth` as constants (same approach as `uCmonacos`).
- The required packages of cx stay as they are (WebView4Delphi is already included).

## 3. Source

### 3.1 How It Is Decided

| Trigger | Source | Display |
|---|---|---|
| The editor inside a TCsEditor received focus (that TCsEditor's `Preview` is this component) | That TCsEditor | If the TCsEditor changed, rebuild immediately |
| A tab was switched in the source TCsEditor | Unchanged | Rebuild immediately |
| The body text changed in the source TCsEditor | Unchanged | Wait `DelayMs`, then rebuild |
| The body text changed or a tab was switched in a TCsEditor that is not the source | Unchanged | Do nothing |
| Clicking something other than an editor (button, tree, etc.) | Unchanged | Do nothing |
| `ShowPreview := True`, `Ctrl+Shift+V`, or `Print` was performed on a TCsEditor | That TCsEditor | Rebuild immediately |
| The source TCsEditor was destroyed, or `Preview` was cleared | None | Empty it (`Clear`) |
| There is no source yet (right after startup) | The first one to reach `OnReady` among the TCsEditors that have selected this component in `Preview` | Rebuild immediately |

### 3.2 Interaction with the Source

TCsEditor notifies this component with the following methods (public; not used by applications).

```pascal
procedure SetSource(ASource: TComponent);                   // Make it the source. If it is a different source, Refresh immediately
procedure SourceChanged(ASource: TComponent);               // The body text changed. If it is the source, Refresh after waiting DelayMs
procedure SourceSwitched(ASource: TComponent);              // A tab was switched, or the language or file name changed. If it is the source, Refresh immediately
procedure SourceScrolled(ASource: TComponent; ALine: Double); // The first visible line changed. If it is the source, see 5.3
procedure SourceRemoved(ASource: TComponent);               // Removed from the Preview of a TCsEditor. If it is the source, empty it
procedure PrintFor(ASource: TComponent);                    // Make that TCsEditor the source and print (5.4)
```

- The source is held in `FSource: TComponent`. With `FreeNotification`, when it is destroyed, `FSource := nil` and `Clear`.
- What is read from the source (read as `TCsEditor(FSource)` in the implementation): `Text`, `Language`, `FileName`, and `Caption` of the visible tab, `Theme`, and `TopLine`.
- What is requested of the source: scrolling (`TCsEditor.ScrollToLine`) and opening a file (`TCsEditor.OpenFile`).

## 4. Component (TCPreview)

### 4.1 Structure

```
TCPreview (TCustomPanel)
 └ Preview (TCMMarkdownPreview)  ... fills the whole area (alClient). Created at runtime only
```

- `Create`: after `inherited`, the inner `TCMMarkdownPreview` is created only if not `csDesigning` (runtime only) (`Parent := Self`, `Align := alClient`). It is not created at design time (WebView2 is not started).
- At design time, `Paint` draws a thin frame and the component name (same appearance as TCMonacoEditor).
- The WebView2 of the inner component is created when TCPreview is first shown (current behavior of `TCMMarkdownPreview`). If it is never shown, it is never created.
- `BevelOuter := bvNone`; `Caption` is not shown (remove `csSetCaption` from `ControlStyle`).
- Default size: `Width := 500` (the default of `PreviewWidth` in TCMonacoEditor), `Height := 300`.

### 4.2 Properties

| Name | Type | Default | Visibility | What is held internally / how it is passed |
|---|---|---|---|---|
| `Splitter` | `TSplitter` | nil | published | The boundary whose show/hide is synchronized (4.4). `FreeNotification` |
| `FontSize` | `Integer` | 16 | published | `FontSize` of the inner component (clamped to 8-48) |
| `ColorScheme` | `TCMColorScheme` | `csEditor` | published | `FColorScheme` -> `ColorScheme` of the inner component (`csEditor` -> 'editor', `csGitHub` -> 'github') |
| `BackColorLight` | `TColor` | `DefPreviewBackColorLight` (#FFFFFE) | published | Held as a TColor in `F...` and passed to `BackColorLight` of the inner component via `CMColorToHex` |
| `BackColorDark` | `TColor` | `DefPreviewBackColorDark` (#1E1E1E) | published | Same as above |
| `TextColorLight` | `TColor` | `DefPreviewTextColorLight` (#000000) | published | Same as above |
| `TextColorDark` | `TColor` | `DefPreviewTextColorDark` (#D4D4D4) | published | Same as above |
| `LinkColorLight` | `TColor` | `DefPreviewLinkColorLight` (#006AB1) | published | Same as above |
| `LinkColorDark` | `TColor` | `DefPreviewLinkColorDark` (#3794FF) | published | Same as above |
| `BreakOnNewline` | `Boolean` | `False` | published | Same-named property of the inner component |
| `AllowRemoteImages` | `Boolean` | `False` | published | Same-named property of the inner component |
| `SyncScroll` | `TCMSyncScroll` | `ssBoth` | published | `FSyncScroll` (5.3) |
| `DelayMs` | `Integer` | 300 | published | `FTimer.Interval` (immediate if 0 or less) |
| `PreviewPath` | `string` | '' | published | `ResourcePath` of the inner component (`TCMonacoEditor_Design.md` 6.1) |
| `Source` | `TComponent` | - | public (read) | The current source (chapter 3) |
| `Ready` | `Boolean` | - | public (read) | `Ready` of the inner component (`False` if there is no inner component) |
| `Align`, `Anchors`, `BorderSpacing`, `Constraints`, `Enabled`, `Visible`, `Width`, `Height`, `TabOrder`, `TabStop` | | | published | As in the LCL |

- Settings are held in `F...` even before the inner component exists (at design time, or while loading the .lfm), and are passed together when the inner component is created (at the end of `Create` and in `Loaded`) (`ApplyAll`).
- `Theme` of the inner component is determined from `Theme` of the source (`ctAuto` -> 'auto', `ctLight` -> 'vs', `ctDark` -> 'vs-dark'). If there is no source, 'auto'. With 'auto', `preview.html` follows OS theme changes by itself (current behavior).
- The six colors follow the same rules as TCMonacoEditor (system colors are converted to the current color with `ColorToRGB`; `clDefault` and `clNone` mean the default value).

### 4.3 Events

| Name | Arguments | Meaning | When not set |
|---|---|---|---|
| `OnOpenMarkdown` | `Sender: TObject; const AFileName: string` | A link to a `.md` file in the preview was clicked | `OpenFile(AFileName)` on the source TCsEditor (follows `MultiDocument`). If there is no source, nothing happens |
| `OnError` | `Sender: TObject; const AMessage: string` | A preview error (preview.html not found, WebView2 not ready, etc.) | Show the message. The same message is shown only once per run (same as TCMonacoEditor; the list of messages already shown is held inside `uCPreview`) |
| `OnReady`, `OnClick`, etc. | | Not exposed | - |

- `OnOpenMarkdown`, `OnError`, `OnScrollLine`, `OnReady`, `OnPrintKey`, `OnAfterPrint`, and `OnFontSizeChange` of the inner component are wired up by TCPreview.

### 4.4 Show/Hide and the Boundary (Splitter)

- When `Visible` changes (`VisibleChanged`), if there is a `Splitter`, its `Splitter.Visible` is set to the same value.
- When showing, rearrange so that the boundary sits next to the preview: if `Align` is `alRight`, `Splitter.Left := Left - Splitter.Width`; `alLeft`, `Splitter.Left := Left + Width`; `alBottom`, `Splitter.Top := Top - Splitter.Height`; `alTop`, `Splitter.Top := Top + Height` (because the LCL TSplitter determines its neighboring component by position).
- When shown, if there is a source, `Refresh` (to reflect changes made while hidden).
- `ShowPreview` of TCsEditor reads and writes `Visible` of this component (`TCsEditor_Design.md` chapter 9).
- Boundary color: the `Color` of `Splitter` is set to match the Theme of the source (same color as the boundary inside TCMonacoEditor: dark #2B2B2B, light #E5E5E5). Whether it is dark is asked of the source TCsEditor (for `ctAuto`, the OS setting). If there is no source, the OS setting. It is applied when `Splitter` is selected, when the source changes, and on `SourceSwitched` (which is also sent when the color scheme is changed). A color set by the application is overwritten.

## 5. Processing

### 5.1 Rebuild (Refresh)

Same as `TCMPreviewBinder.Refresh` of TCMonacoEditor.

1. `FTimer.Enabled := False`. If there is no inner component (design time), finish.
2. If there is no source, `Clear` and finish.
3. Match `Theme` of the inner component to the source (4.2).
4. `DocTitle`: the `Caption` of the visible tab with its extension removed (`abc.md` -> `abc`, untitled -> untitled). It becomes the name of the printed PDF.
5. If the language is 'markdown', `ShowMarkdown(Text, ExtractFilePath(FileName))`; otherwise `ShowCode(Text, Language)`.
6. `SetTopLine(TopLine of the source)`.

- While hidden (`not Visible`), do not rebuild; only set `FDirty := True`. Rebuild when shown (4.4). For printing, show it in 5.4 and then rebuild.

### 5.2 Rebuild After Waiting (SourceChanged)

- For a notification from the source: if `DelayMs > 0`, stop and restart `FTimer` (wait while typing continues). If `DelayMs <= 0`, `Refresh` immediately.
- Notifications from a TCsEditor that is not the source are ignored.

### 5.3 Synchronizing Scrolling

| Direction | Processing |
|---|---|
| Editor -> preview (`SourceScrolled`) | From the source, if `SyncScroll <> ssNone` and not in the suppression period (below), call `SetTopLine(ALine)` of the inner component |
| Preview -> editor (`OnScrollLine` of the inner component) | If `SyncScroll = ssBoth` and there is a source, call `ScrollToLine(Line)` on the source. Then suppress notifications from the editor for 300 ms (`FSuppressUntil := GetTickCount64 + 300`) |

- Reason for suppression: moving the editor makes the editor notify the preview again, and the two react to each other and wobble (same idea as TCMonacoEditor).
- The editor's line has no position within the line (`TopLine` is an integer. `TCsEditor_Design.md` 6.6). The preview aligns to the start of the block for that line.

### 5.4 Printing (PrintFor / Print)

Same flow as 7.3 of TCMonacoEditor.

1. `PrintFor(ASource)`: `SetSource(ASource)`. If there is no inner component, finish.
2. If hidden, `FShownForPrint := True` and `Visible := True` (the boundary also appears via 4.4). It is shown only during printing (because printing is not guaranteed to work correctly with a WebView2 that is not shown on screen).
3. `Refresh` (rebuild with the current body text).
4. `Print` of the inner component (the inner component waits until it is ready, creates the print-use Mermaid diagrams, and shows the print dialog).
5. In `OnAfterPrint` of the inner component, if `FShownForPrint`, `Visible := False` and `FShownForPrint := False`. If the notification does not arrive, it stays shown.

- `Print` (public; no arguments): `PrintFor` with the current source. If there is no source, nothing happens.
- `OnPrintKey` of the inner component (`Ctrl+P` while the preview has focus) and "Print..." in the preview's context menu: `Print`.
- What is printed is the visible tab of the source. Even if the screen is dark, it comes out with a white background and black text (`@media print` in `preview.html`; unchanged).

### 5.5 Opening Files and Errors

- `OnOpenMarkdown` of the inner component -> via `QueueAsyncCall`, call `OnOpenMarkdown` if set. If not set, call `OpenFile` of the source (so that no dialog is shown in the middle of a notification from the inner component. `TCMonacoEditor_Design.md` 5.4).
- `OnError` of the inner component -> call `OnError` if set. If not set, show the message via `QueueAsyncCall` (the same message only once).

### 5.6 Font

- When `Ctrl+Wheel` is turned in the preview, the inner component changes the text size and raises `OnFontSizeChange`. At that time `FFontSize` is synchronized with the inner value (so that it does not diverge from the Object Inspector value; at runtime only).

## 6. Decisions

| Item | Decision |
|---|---|
| Component shape | A component separate from the editor. Place it anywhere on the form. The boundary (TSplitter) is placed by the application and selected with `Splitter` |
| Connection | Selected with `Preview` of TCsEditor. TCPreview has no property for the connection target |
| Sharing | One TCPreview can be selected from multiple TCsEditors. What is displayed is the visible tab of the source (the most recently focused TCsEditor) |
| Show/hide | `ShowPreview` of TCsEditor. Shared among the TCsEditors that selected the same TCPreview |
| Content | Uses `TCMMarkdownPreview` and `preview.html` unchanged |
| Names | The leading `Preview` is dropped from the TCMonacoEditor preview settings. `PreviewPath` stays as is (because it pairs with `PreviewFolder` in WebView2.ini) |
| Printing | Prints the visible tab of the source with the Edge print dialog (PDF saving too). If hidden, it is shown only during printing |
| Switching over | `ShowPreview` of TCMonacoEditor is written the same way as `ShowPreview` of TCsEditor. Preview settings are `ed.Preview.~` |

**Not to be built**

| Item | Reason / alternative |
|---|---|
| `Editor` property (selecting a TCsEditor from TCPreview) | The connection is unified to `Preview` of TCsEditor |
| `PreviewWidth`, `SplitterResizeStyle`, `SplitterWidth` | `Width` of TCPreview, and the settings of the TSplitter placed by the application |
| Scroll synchronization down to the position within a line | Because `TopLine` of SynEdit is an integer |
| Connecting TCMonacoEditor | Not done this time |

## 7. Points to Check When Investigating Problems

| Symptom | Where to look |
|---|---|
| Nothing is displayed | The source (3.1). Whether this component is set in `TCsEditor.Preview`. `Visible`. The location of `preview.html` (`PreviewPath`, WebView2.ini) |
| The content of another editor does not appear | Whether `SetSource` is called from `DoEnter` of the inner editor (`TCsEditor_Design.md` chapter 9) |
| Not updated when typing | Whether `SourceChanged` arrives from the source. `DelayMs`. No rebuild while hidden (5.1) |
| The boundary remains / appears far away | The `Splitter` setting and rearrangement (4.4) |
| The boundary color does not match the color scheme | The boundary color in 4.4 (whether it is reapplied on `SourceSwitched`) |
| Scrolling wobbles | The 300 ms suppression (5.3) |
| The preview stays shown after printing | Whether `OnAfterPrint` arrived (5.4). If it does not arrive, it stays shown (same as TCMonacoEditor) |
| Freezes on a dialog | Whether a dialog is shown in the middle of a notification from the inner component (5.5) |
| WebView2 runs at design time | The `csDesigning` check in `Create` (4.1) |

## 8. Changes in This Version (1.0. New)

Steps for building the code. Not included in the user manual.

| No | File | Change |
|---|---|---|
| 1 | `uCPreview.pas` | New (everything in this document) |
| 2 | `cx.lpk` | Add `../source/uCPreview.pas` (UnitName `uCPreview`) |
| 3 | `uCXReg.pas` | Add `uCPreview` to uses and `TCPreview` to `RegisterComponents('CX', [...])` |
| 4 | `cseditor_icon.lrs`, `cxdsgn.lpk` | Icons (`TCsEditor_Design.md` chapter 12) |
| 5 | `uCmdpreview.pas`, `CMonacoPreview.pas`, `uCmonacos.pas`, `preview.html` | No change |

**1.1 (2026-11-03)**

| No | Chapter | 1.0 | 1.1 | Reason |
|---|---|---|---|---|
| 1 | 4.4 | The color of `Splitter` is not set | Set to match the Theme of the source | The boundary color did not change when the Theme was changed |
