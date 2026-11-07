# TCPreview User Manual

Author: aotan083
Date: 2026-11-05
Version: 1.2

---

## 1. Overview and Classes

A component that displays the body text of a TCsEditor as a preview (a document for Markdown, color-coded code for everything else) and prints it (saves it as PDF). Because it is a separate component from the editor, it can be placed anywhere on a form. One TCPreview can be shared by multiple TCsEditors.

```
+---------+---------+-----+-----------+------------------------------+
| a.md  × | b.pas × |  +  |           |                              |
+---------+---------+-----+-----------+‖-----------------------------+
| # Heading                           ‖  Heading                     |
| Body...                             ‖  Body...                     |
|                                     ‖                              |
|   TCsEditor                         ‖  TCPreview                   |
+-------------------------------------+------------------------------+
                                      ↑ TSplitter (placed by the app)
```

- The content is the same as the TCMonacoEditor preview (WebView2 and `preview.html`). Display, Mermaid diagrams, printing, links, and images behave the same as in the TCMonacoEditor preview.
- The connection is made simply by selecting this component in `Preview` of TCsEditor. Nothing is selected on the TCPreview side.
- Show/hide is toggled with `ShowPreview` of TCsEditor (`Ctrl+Shift+V`).
- What is displayed is the visible tab of the "source" TCsEditor (chapter 3).
- Scrolling of the editor and the preview is synchronized (per line).
- All settings are made in the Object Inspector. No code is needed.

| Item | Details |
|---|---|
| Lazarus | 5.0 or later |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |
| Required at runtime | Microsoft Edge WebView2 Runtime (preinstalled on Windows 11), WebView2Loader.dll (64-bit), WebView2.ini, preview folder (chapter 2) |
| Memory | About 60MB (WebView2). WebView2 is not started if it is never shown |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Content |
|---|---|---|---|---|
| `TCPreview` | `uCPreview` | cx | `TCustomPanel` | The preview component |

| Type | Unit | Content |
|---|---|---|
| `TCMColorScheme` | `uCPreview` | Preview color scheme. `csEditor`, `csGitHub` (same type as in `uCmonacos`) |
| `TCMSyncScroll` | `uCPreview` | Scroll synchronization. `ssNone`, `ssEditorToPreview`, `ssBoth` (same type as in `CMonacoPreview`) |

- When placed on a form, `uCPreview` is added to uses automatically.
- When placed on a form, cx is added automatically to the project's required packages.
- When creating it in code, write it in uses yourself.

## 2. From Placing on a Form to Running

1. From the palette [CX], place TCsEditor, TSplitter, and TCPreview on the form.
2. Decide the layout in the Object Inspector (example for showing the preview on the right).

| Component | Settings |
|---|---|
| TCsEditor1 | `Align = alClient`, `Preview = CPreview1` |
| Splitter1 | `Align = alRight` |
| CPreview1 | `Align = alRight`, `Splitter = Splitter1`, `Width` is the preview width |

3. Decide whether to show the preview at startup.

| At startup | Settings |
|---|---|
| Do not show | `CPreview1.Visible = False` (leave `ShowPreview` of TCsEditor1 as `False`) |
| Show | `ShowPreview = True` of TCsEditor1 |

4. Place the files listed in 2.1 in the same folder as the EXE.
5. Run it. `Ctrl+Shift+V` toggles the preview between shown and hidden.

- If `Splitter` is not selected, the boundary will not come next to the preview when it is shown again, so the width can no longer be changed. Give the boundary an `Align` in the same direction as the preview (such as `alRight`). Do not use `alNone`.
- If you leave `CPreview1.Visible = True` and set `ShowPreview = False`, the preview is shown at startup but `ShowPreview` is `False`. The first `Ctrl+Shift+V` does not change the screen.
- WebView2 is not started inside the IDE (at design time). Only a thin frame and the component name are shown.

### 2.1 Runtime Files

```
MyApp.exe
WebView2.ini                       (always place it. 2.2)
WebView2Loader.dll                 (64-bit)
WebView2Data\                      (WebView2 user data. Created automatically)
preview\
  preview.html
  lib\
    marked.umd.js
    purify.min.js
    highlight.min.js
    github.min.css / github-dark.min.css
    github-markdown-light.css / github-markdown-dark.css
    THIRD_PARTY_LICENSES.txt
    mermaid.min.js / mermaid.LICENSE.txt   (Mermaid diagrams)
    languages\ delphi.min.js / dos.min.js / powershell.min.js
```

- The preview folder is the same as for TCMonacoEditor. The monaco folder is not needed.
- WebView2Loader.dll is obtained from the WebView4Delphi repository (https://github.com/salvadordf/WebView4Delphi).
- WebView2 preparation is done by the component itself when the preview is first shown. Nothing needs to be written in the app's .lpr.

### 2.2 WebView2.ini

Place it in the same folder as the EXE. It is shared by the CX WebView2 components (TCMonacoEditor, TCTabBrowser, TCPreview).

```ini
[WebView2]
LoaderDllPath=
UserDataFolder=
MonacoFolder=
PreviewFolder=

[CX]
Language=
```

| Key | Content | When empty or omitted |
|---|---|---|
| `LoaderDllPath` | The WebView2Loader.dll file | WebView2Loader.dll in the EXE folder |
| `UserDataFolder` | Folder for WebView2 user data | EXE folder\WebView2Data |
| `MonacoFolder` | Not used by TCPreview | - |
| `PreviewFolder` | Folder containing `preview.html` and `lib` | EXE folder\preview |
| `Language` (`[CX]`) | Screen language, `ja` or `en` (2.4) | Windows display language |

- Always place the file. All key values may be empty.
- Relative paths are counted from the EXE folder. Absolute paths can also be written.
- A `%name%` written in a value is replaced. The name is looked up as a key of the same `[WebView2]` section, then as a Windows environment variable (example: write `CXROOT=C:\CX\runtime`, then `TerminalFolder=%CXROOT%\terminal`). A name that is not found is left as it is.
- It is read only once, at first use after startup. Rewriting it while running has no effect until the next startup.

### 2.3 How the preview Location Is Decided

The first one decided, in order from the top, is used.

| Order | How it is decided |
|---|---|
| 1 | If `PreviewPath` is not empty, that location (relative paths are counted from the EXE folder) |
| 2 | If `PreviewFolder` in WebView2.ini is not empty, that location |
| 3 | `preview` in the EXE folder |

- If it is not found, `OnError` is raised ("preview.html not found: (location)").

### 2.4 Screen Language (Japanese/English)

The text this component shows on screen (context menu, diagram buttons, error messages, etc.) appears in Japanese or English. There is one language for all cx components; it is not set per component.

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
- The screen text quoted in this manual is the English text. With `ja`, it is shown in Japanese.

## 3. Source

What TCPreview displays is the visible tab of the "source" TCsEditor. The source is decided automatically as follows.

| Trigger | Source | Display |
|---|---|---|
| The body text of a TCsEditor was clicked (that TCsEditor's `Preview` is this component) | That TCsEditor | If the source changed, rebuild immediately |
| A tab was switched in the source TCsEditor | Unchanged | Rebuild immediately |
| The body text changed in the source TCsEditor | Unchanged | Wait `DelayMs`, then rebuild |
| The body text changed or a tab was switched in a TCsEditor that is not the source | Unchanged | Do nothing |
| Clicking something other than an editor (button, tree, etc.) | Unchanged | Do nothing |
| `ShowPreview := True`, `Ctrl+Shift+V`, `Print`, or `Ctrl+P` was performed on a TCsEditor | That TCsEditor | Rebuild immediately |
| The source TCsEditor was destroyed, or `Preview` was cleared | None | Empty it |
| Right after startup | The first one that became ready among the TCsEditors that have selected this component in `Preview` | Rebuild immediately |

- While hidden, it is not rebuilt. When shown, it is rebuilt with the content at that moment.
- The body text is taken from the editor, not from the file. Unsaved edits are also displayed.

## 4. Properties

| Name | Type | Default | Read/Write | Content |
|---|---|---|---|---|
| `Splitter` | `TSplitter` | nil | Read/Write | The boundary shown and hidden together with the preview (5.1) |
| `FontSize` | `Integer` | 16 | Read/Write | Text size (8-48). Turning `Ctrl+Wheel` in the preview also changes this value |
| `ColorScheme` | `TCMColorScheme` | `csEditor` | Read/Write | Color scheme. `csEditor` (same colors as the editor) / `csGitHub` (GitHub style) |
| `BackColorLight` | `TColor` | #FFFFFE | Read/Write | Background color for `csEditor` (light scheme) |
| `BackColorDark` | `TColor` | #1E1E1E | Read/Write | Same (dark scheme) |
| `TextColorLight` | `TColor` | #000000 | Read/Write | Text color (light scheme) |
| `TextColorDark` | `TColor` | #D4D4D4 | Read/Write | Same (dark scheme) |
| `LinkColorLight` | `TColor` | #006AB1 | Read/Write | Link color (light scheme) |
| `LinkColorDark` | `TColor` | #3794FF | Read/Write | Same (dark scheme) |
| `BreakOnNewline` | `Boolean` | `False` | Read/Write | Whether a single line break in Markdown is also displayed as a line break |
| `AllowRemoteImages` | `Boolean` | `False` | Read/Write | Whether to display images from the Internet (http) (6.3). Can also be read and written via `AllowRemoteImages` of TCsEditor |
| `SyncScroll` | `TCMSyncScroll` | `ssBoth` | Read/Write | Whether to synchronize scrolling of the editor and the preview (6.4) |
| `DelayMs` | `Integer` | 300 | Read/Write | Time from an edit until the preview is rebuilt (milliseconds). Immediate if 0 or less |
| `PreviewPath` | `string` | '' | Read/Write | Location of `preview.html` (2.3) |
| `Source` | `TComponent` | - | Read | The current source TCsEditor (chapter 3). nil if none. Runtime only |
| `Ready` | `Boolean` | - | Read | Whether the preview is ready. Runtime only |
| `Align` | `TAlign` | | Read/Write | Placement within the parent |
| `Anchors` | `TAnchors` | | Read/Write | Which edges it follows when the parent's size changes |
| `BorderSpacing` | `TControlBorderSpacing` | | Read/Write | Surrounding margin |
| `Constraints` | `TSizeConstraints` | | Read/Write | Upper and lower limits of size |
| `Enabled` | `Boolean` | | Read/Write | Whether it is usable |
| `Visible` | `Boolean` | | Read/Write | Whether it is shown. The same thing as `ShowPreview` of TCsEditor |
| `Width`, `Height` | `Integer` | 500, 300 | Read/Write | Size. For `alRight` and `alLeft`, `Width` is the preview width |
| `TabOrder` | `TTabOrder` | | Read/Write | Order of movement with the Tab key |
| `TabStop` | `Boolean` | | Read/Write | Whether the Tab key stops here |

**Color settings (the 6 properties whose names end in `Color`)**

- In the Object Inspector, choose from the color list or from the color dialog under "...".
- When a system color (such as `clWindow`) is chosen, it becomes the color it was at the time of setting.
- When `clDefault` or `clNone` is chosen, it becomes the default color.

**Color scheme (dark / light)**

- Follows `Theme` of the source TCsEditor (for `ctAuto`, the OS color scheme; switching the OS changes it on the spot). When there is no source, the OS color scheme.

## 5. Methods and Events

### 5.1 Show/Hide and the Boundary (Splitter)

- When `Visible` is changed (including `ShowPreview` and `Ctrl+Shift+V` of TCsEditor), `Visible` of `Splitter` becomes the same.
- Each time it is shown, the boundary is placed again next to the preview (to the left of the preview for `alRight`, to the right for `alLeft`, above for `alBottom`, below for `alTop`).
- The boundary color is set to match the color scheme of the source (dark #2B2B2B, light #E5E5E5). A color set by the application is overwritten.

### 5.2 Methods

| Name | Arguments | Return value | Content |
|---|---|---|---|
| `Print` | - | - | Prints the visible tab of the source (6.5). Does nothing if there is no source |
| `Refresh` | - | - | Rebuilds immediately with the content of the current source |

- `SetSource`, `SourceChanged`, `SourceSwitched`, `SourceScrolled`, `SourceRemoved`, and `PrintFor` are for TCsEditor to notify this component. Do not call them from the application.

### 5.3 Events

| Name | Arguments | Content | When not set |
|---|---|---|---|
| `OnOpenMarkdown` | `Sender: TObject; const AFileName: string` | A link to a `.md` file in the preview was clicked | Opens it in the source TCsEditor (follows `MultiDocument`) |
| `OnError` | `Sender: TObject; const AMessage: string` | A preview error (preview.html not found, WebView2 not ready, etc.) | Shows the message. The same message only once |

## 6. Behavior

### 6.1 What Is Displayed

| Language of the source tab | Display |
|---|---|
| markdown | A document (tables, task lists, color-coded code blocks, Mermaid diagrams) |
| Anything else | The whole text, shown as color-coded code with line numbers |

**Markdown**

- Supports tables (GFM), task lists, and color-coding of code blocks. Code blocks with no language written are not color-coded.
- With `ColorScheme = csEditor` (default), the colors are the same as the editor (`BackColor...`, `TextColor...`, `LinkColor...`). Table borders and the code block background are decided automatically from the background and text colors.
- The fonts are, in order, `Segoe UI`, `Yu Gothic UI`, `Meiryo`.
- The YAML at the top (the part enclosed by `---`) is not shown.
- Task list checkboxes are display only (clicking them does not change the body text).
- Scripts are removed, so Markdown that comes from outside does not execute when opened.

**Code (tabs other than Markdown)**

| Item | Content |
|---|---|
| Color-coding | The tab's language is mapped to a highlight.js language (e.g. pascal -> delphi, bat -> dos). Unsupported languages and plaintext are not color-coded |
| Long lines | Wrapped (the line number is attached only to the first line of the wrapped line) |
| Large files | Files over 500,000 characters are not color-coded (they are still shown with line numbers) |
| Copy | Line numbers are not copied |
| Font | Monospaced (`Consolas`, `BIZ UDゴシック`, `MS ゴシック`, in that order) |

- The color-coding of code blocks and code is made close to the editor's colors, but the editor (SynEdit) and the preview (highlight.js) use different color-coding mechanisms, so they do not become completely identical.
- Even when the component's window is recreated, for example by docking or undocking with AnchorDocking, the display remains as it is.

### 6.2 Mermaid Diagrams

If you write it in a ` ```mermaid ` code block in Markdown, it is drawn as a diagram.

| Opening line | Diagram |
|---|---|
| `graph TD`, `graph TB` | Flowchart (top to bottom) |
| `graph LR`, `flowchart LR` | Flowchart (left to right) |
| `sequenceDiagram` | Sequence diagram |
| `usecase-beta` | Use case diagram |
| `classDiagram` | Class diagram |
| `erDiagram` | ER diagram |
| `gitGraph` | Git graph |
| `journey` | User journey |
| `xychart-beta` | XY chart (bar, line) |
| `quadrantChart` | Four-quadrant chart |
| `architecture-beta` | Architecture diagram |

| Item | Content |
|---|---|
| Colors | Lines and borders are blue (dark #3794ff, light #006ab1); background and text are the same colors as the preview |
| Size | Initially fitted to the preview width. When the mouse is over a diagram, 4 buttons appear at the top right (move / zoom out / zoom in / fit to frame) |
| Printing | Printed with colors for a white background, fitted to the paper width |
| Typos | The error details are shown at that diagram's location (the rest is displayed normally) |
| Internet images inside a diagram | With `AllowRemoteImages = False` (default) they are not fetched, and "[External images are not shown]" appears below the diagram |

- The Mermaid library (about 5.5MB) is loaded only when a document containing a Mermaid diagram is displayed.

### 6.3 Links and Images

- Images are displayed whether given as a relative path (counted from the folder of the open file) or an absolute path such as `C:\...`.
- Images from the Internet (http) are not shown unless `AllowRemoteImages = True`.
- External links (`http`, `https`, `mailto`) are opened in the default browser. They do not navigate within the preview.
- A link to a `.md` file is opened in the source TCsEditor unless `OnOpenMarkdown` is set.
- A link to `#heading` scrolls within the preview.
- Links to other files are not opened, for safety.

### 6.4 Synchronizing Scrolling

| `SyncScroll` | Behavior |
|---|---|
| `ssBoth` (default) | Both directions. Moving the editor makes the preview follow, and moving the preview makes the editor follow |
| `ssEditorToPreview` | From the editor to the preview only |
| `ssNone` | Not synchronized |

- Synchronized per line (not down to a position in the middle of an editor line). The preview aligns to the start of the block for that line.
- Within a long paragraph with many wraps, there is some deviation.

### 6.5 Printing

- The same print dialog as Edge appears via `Print` or `Ctrl+P` of TCsEditor, `Print` of this component, "Print..." in the preview's context menu, or `Ctrl+P` while the preview has focus. Printer, save as PDF, pages, number of copies, and so on are all chosen in the dialog.
- What is printed is the visible tab of the source. Markdown prints as a document; anything else prints as color-coded code.
- When the preview is not shown, the preview is shown only during printing and hidden when the print dialog closes. If the closing is not reported, it stays shown (hide it with `Ctrl+Shift+V`). The first time, it takes a little while because it waits for WebView2 to start.
- Even if the screen is dark, printing comes out with a white background and black text.
- The PDF name is the visible tab's name with its extension removed (`abc.md` -> `abc.pdf`, untitled -> `無題.pdf`). The save location is chosen in the print dialog.
- If "Headers and footers" is turned on in the print dialog, an internal URL is put on each page. If you do not want it, turn off headers and footers in the dialog.

### 6.6 Context Menu

| Item | Behavior |
|---|---|
| Copy | Copies the selected text |
| Select All | Selects everything |
| Print... | Prints (6.5) |

## 7. Usage Examples

### 7.1 Placing the Preview to the Right of the Editor (No Code)

1. Place TCsEditor, TSplitter, and TCPreview on the form.
2. TCsEditor1: `Align = alClient`, `Preview = CPreview1`.
3. Splitter1: `Align = alRight`.
4. CPreview1: `Align = alRight`, `Splitter = Splitter1`, `Visible = False`.
5. Place the files listed in 2.1 in the same folder as the EXE.

`Ctrl+Shift+V` shows and hides the preview. Dragging the boundary changes the preview width.

### 7.2 Using One Preview with Two Editors

1. Place two TCsEditors (e.g. `alLeft` and `alClient`) and put a TSplitter between them.
2. At the right edge, place a TSplitter (`alRight`) and a TCPreview (`alRight`, with `Splitter` set to that boundary).
3. Select CPreview1 in `Preview` of both TCsEditors.

The preview shows the visible tab of the editor that was clicked last.

### 7.3 Changing Preview Settings

```pascal
CPreview1.FontSize := 18;
CPreview1.ColorScheme := csGitHub;      // GitHub-style color scheme
CPreview1.SyncScroll := ssEditorToPreview;
CsEditor1.Preview.DelayMs := 500;       // Reaching it through the editor works the same
```

### 7.4 Opening .md Links Yourself

```pascal
procedure TForm1.CPreview1OpenMarkdown(Sender: TObject; const AFileName: string);
begin
  CsEditor2.OpenFile(AFileName);        // Open in the right-hand editor
end;
```

### 7.5 Creating It in Code

```pascal
uses
  uCPreview;

procedure TForm1.FormCreate(Sender: TObject);
var
  S: TSplitter;
  P: TCPreview;
begin
  P := TCPreview.Create(Self);
  P.Width := 400;
  P.Align := alRight;
  P.Visible := False;
  P.Parent := Self;
  S := TSplitter.Create(Self);
  S.Align := alRight;
  S.Parent := Self;
  P.Splitter := S;
  CsEditor1.Preview := P;
end;
```
