# TCcmd Design Document

Author: aotan083
Date: 2026-11-07
Version: 1.0

---

## 1. Purpose and Policy

- TCcmd is a component that emulates the command prompt. Input, output, and error output are connected to a control placed on a form. The component handles screen display and keyboard input.
- Interactive use of ssh, vi, and PowerShell works. Redirection (`>`, `>>`, `2>&1`) and pipes (`|`) are also supported.
- Screen drawing: xterm.js runs inside WebView2 (escape sequence interpretation, colors, cursor, full-width characters, selection, scrollback, and search are left to xterm.js).
- Scripts such as python, php, and go run as ordinary commands.
- For uses that want to take in the result, there is a pipe-based `RunCapture` (standard output, standard error, and exit code are received separately).

### 1.1 Out of Scope

- Linux and macOS versions (Windows 11 only). The part that runs the shell is separated into `TCcmdPty`, so it can later be replaced for another OS.
- Tabbed terminals (a frame holding several terminals). Put one TCcmd on each tab of a TCPageControl.
- Separating standard output and standard error in terminal mode. As a terminal they are one stream (as in a real terminal). Use `RunCapture` to separate them.
- Transparency (`Opacity`) and `iX`/`iY` position properties.

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCcmd.pas` | cx (runtime) | `TCcmdPty`, `TCcmd` |
| `uCXReg.pas` (`source\design`) | cxdsgn (design time) | Palette [CX] registration (`RegisterComponents('CX', [..., TCcmd])`, at the end of the order) |
| `ccmd_icon.lrs` (`source\res`) | cxdsgn (design time) | Icons (`TCcmd`, `TCcmd_150`, `TCcmd_200`). `{$I ccmd_icon.lrs}` in the initialization of `uCXReg` |
| `uCXLang.pas` | cx (runtime) | Adds strings (4.6) |
| `runtime\terminal\terminal.html` | Placed with the EXE at runtime | The screen page (Chapter 7) |
| `runtime\terminal\lib\` | Same | `xterm.js`, `xterm.css`, `addon-fit.js`, `addon-search.js` (xterm.js, MIT. Source and license are written in `THIRD_PARTY_NOTICES.md`) |

- uses of `uCcmd`: `Windows, Classes, SysUtils, Types, Math, Controls, Graphics, Forms, Menus, ExtCtrls, Clipbrd, LCLType, LCLIntf, LMessages, SyncObjs, uWVBrowser, uWVWindowParent, uWVLoader, uWVTypes, uWVTypeLibrary, uWVEvents, uWVCoreWebView2Args, uCmonacos` (`TCMTheme`). `uCXLang` and `uCXRuntime` are used in the implementation section.
- `uCcmd` has no initialization or finalization of its own for the shell (same reason as uCXRuntime); only a small finalization frees the list of already-shown error messages.
- The key `TerminalFolder` is added to `[WebView2]` of `WebView2.ini` (the folder holding `terminal.html` and `lib`; if empty, `terminal` next to the EXE). It is read the same way as `MonacoFolder` and `PreviewFolder` (`CXResolveRuntimeDir` of `uCXRuntime`).
- There remain two packages, cx and cxdsgn (it goes in the same place as the other WebView components).

## 3. Overall Structure

```
TCcmd on the form (TCustomPanel)
  ├─ TCXWVWindowParent + TWVBrowser  … WebView2. Shows terminal.html (xterm.js)
  │        ▲ (3) output (text)        │ (4) notifications: key input, size, title, etc.
  │        │ PostWebMessageAsString   ▼ WebMessageReceived
  └─ TCcmdPty                          … runs the shell with ConPTY
          (1) write key input ─▶ [pseudo console] ─▶ cmd.exe / powershell.exe / ssh.exe …
          (2) read output (dedicated reader thread) ◀─
```

1. The user types a key → xterm.js turns it into a string and notifies Pascal (`input`) → `TCcmdPty` writes it to the input pipe.
2. Shell output → the reader thread reads it → hands it to the main thread → sends it to the page (`out`) → xterm.js draws it.
3. The size changes → the page notifies the number of columns and rows (`resize`) → `TCcmdPty.Resize` (`ResizePseudoConsole`).

## 4. TCcmd

`TCcmd = class(TCustomPanel)`. Unit `uCcmd`.

### 4.1 Types and Constants

```pascal
type
  TCcmdLogMode = (lmOff, lmPlain, lmRaw);                 { no log / text without escapes / raw output }
  TCcmdCursorStyle = (ccBlock, ccUnderline, ccBar);
  TCcmdBellMode = (bmNone, bmSound, bmFlash);             { bell (BEL): nothing / sound / flash the screen briefly }
  TCcmdOutputEvent = procedure(Sender: TObject; const AText: string) of object;
  TCcmdExitEvent = procedure(Sender: TObject; AExitCode: Integer) of object;
  TCcmdResizeEvent = procedure(Sender: TObject; ACols, ARows: Integer) of object;
  TCcmdErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;
```

| Constant | Value | Contents |
|---|---|---|
| `cMaxCountMin` / `cMaxCountMax` / `cMaxCountDef` | 100 / 10000 / 1000 | Range and default of `MaxCount` |
| `cHistoryMaxDef` | 1000 | Default of `HistoryMax` |
| `cLogMaxSizeDef` | 10240 | Default of `LogMaxSize` (KB) |
| `cDefaultCols` / `cDefaultRows` | 80 / 24 | Temporary size before the page is ready |
| `cIdleMs` | 150 | Time after which output is considered stopped (used to record the prompt position. 8.5) |

### 4.2 Properties

Published:

| Name | Type | Default | Contents |
|---|---|---|---|
| `Shell` | `string` | `cmd.exe` | Program to run (`powershell.exe`, `ssh.exe`, full path allowed). If empty, `cmd.exe` |
| `Params` | `string` | `''` | Startup arguments (e.g. `-NoLogo`). Appended after `Shell` |
| `WorkDir` | `string` | `''` | Working folder. If empty, the EXE's folder |
| `Environment` | `TStrings` | empty | Environment variables to add or override (`name=value`). Others are inherited from the parent (application) |
| `AutoStart` | `Boolean` | `True` | At runtime, `Start` automatically when the screen is ready. Not run at design time |
| `CloseOnExit` | `Boolean` | `False` | Whether to close the screen (`Visible := False`) when the shell ends. If `False`, the screen stays and "[Process exited with code n]" is shown |
| `MaxCount` | `Integer` | `1000` | Lines kept on screen (including scrollback). Clamped to 100–10000. When exceeded, lines are removed from the top |
| `LogMode` | `TCcmdLogMode` | `lmPlain` | How the log is written |
| `LogDir` | `string` | `''` | Log folder. If empty, `EXE\Logs`. File name `yyyymmdd_hhnnsszzz.log` (time of `Start`) |
| `LogMaxSize` | `Integer` | `10240` | Maximum size of one log file (KB). When exceeded, switches to a new file (the time changes) |
| `HistoryDir` | `string` | `''` | Command history folder. If empty, `EXE\History`. File name `yyyymmdd_hhnnsszzz-CmdHistory.log` |
| `HistoryMax` | `Integer` | `1000` | Maximum entries kept in `CmdHistory` (oldest removed first) |
| `Font` | `TFont` | `Consolas`, `10` | Font. Fixed-width is assumed. If `Font.Color` is `clDefault`, the text color of `Theme` |
| `Color` | `TColor` | `clDefault` | Background color. If `clDefault`, the background color of `Theme` |
| `Theme` | `TCMTheme` | `ctAuto` | `ctAuto` (follows the OS) / `ctLight` / `ctDark`. Decides the color scheme (Chapter 9) |
| `CursorStyle` | `TCcmdCursorStyle` | `ccBlock` | Cursor shape |
| `CursorBlink` | `Boolean` | `True` | Blink the cursor |
| `CursorColor` | `TColor` | `clDefault` | Cursor color. If `clDefault`, the color of `Theme` |
| `SelectionColor` | `TColor` | `clDefault` | Selection color. If `clDefault`, the color of `Theme` |
| `Caption` | `string` | `''` | Title text. While `AutoCaption` is true, follows the title set by the shell |
| `AutoCaption` | `Boolean` | `True` | Make `Caption` follow the shell title (`ESC]0;…`) |
| `ReadOnly` | `Boolean` | `False` | If true, key input and pasting are not accepted (display of output only) |
| `BellMode` | `TCcmdBellMode` | `bmSound` | Bell handling |
| `TerminalPath` | `string` | `''` | Folder of `terminal.html` and `lib`. If empty, `TerminalFolder` of `WebView2.ini`; if that is absent too, `terminal` next to the EXE |
| `PopupMenu` | `TPopupMenu` | `nil` | Right-click menu. If `nil`, the default menu (Copy, Paste, Select All, Clear) |
| `Align`, `Anchors`, `BorderSpacing`, `Constraints`, `Enabled`, `Visible`, `TabOrder`, `TabStop`, `ShowHint`, `Hint` | | | Standard LCL |

Runtime (not published):

| Name | Type | Access | Contents |
|---|---|---|---|
| `Active` | `Boolean` | read | Whether the shell is running |
| `ExitCode` | `Integer` | read | Exit code of the shell (-1 while running) |
| `ProcessId` | `Cardinal` | read | Process ID of the shell (0 if not running) |
| `Cols`, `Rows` | `Integer` | read | Current number of columns and rows (decided automatically from the size) |
| `Title` | `string` | read | Title set by the shell |
| `Ready` | `Boolean` | read | Whether the page (xterm.js) is ready |
| `CmdHistory` | `TStringList` | read | Commands executed so far (oldest first) |

- When `Enabled = False`, key input and pasting are not accepted (output continues to be displayed).
- When `Font`, `Color`, `Theme`, `CursorStyle`, `CursorBlink`, `CursorColor`, `SelectionColor`, or `MaxCount` is changed, it is sent to the page again immediately (`SendOptions` in 4.5).

### 4.3 Methods

| Method | Contents |
|---|---|
| `procedure Start` | Starts the shell. Does nothing if already running. If the page is not ready, starts once it is ready (pending) |
| `procedure Stop` | Ends the shell (including grandchild processes). Does nothing if not running |
| `procedure Restart` | `Stop`, then `Start` |
| `procedure SendText(const AText: string)` | Sends a string to the shell as is (does nothing when `ReadOnly` or `Enabled = False`) |
| `procedure Execute(const ALine: string)` | Sends one line and presses Enter. The method of taking commands from the screen (8.5) cannot be used for characters sent by a program, so `Execute` itself performs `AddHistory(ALine)` and `OnCommand`, then `SendText(ALine + #13)` |
| `procedure SendKey(AKey: Word; AShift: TShiftState)` | Converts a key (arrows, Home/End, PageUp/PageDown, F1–F12, Delete, etc.) to a terminal string and sends it (table in 8.2) |
| `procedure SendCtrlC` | Sends Ctrl+C (`#3`). Stops the running process |
| `procedure Paste` | Sends the clipboard string (enclosed in the paste brackets if `?2004` is enabled) |
| `procedure CopySelection` | Puts the selected string on the clipboard |
| `procedure SelectAll` | Select all |
| `procedure ClearScrollback` | Clears the history scrolled off the top (the current screen stays) |
| `procedure ScrollToBottom` | Moves to the bottom |
| `procedure FindNext(const AText: string; AMatchCase: Boolean = False)` | Finds the next match and selects it |
| `procedure FindPrev(const AText: string; AMatchCase: Boolean = False)` | Finds the previous match and selects it |
| `procedure RequestBufferText` | Requests the full text of the screen and history from the page. `OnBufferText` is raised when it arrives |
| `procedure SaveBufferTo(const AFileName: string)` | Writes the full text received by `RequestBufferText` to a UTF-8 file (written when it arrives) |
| `procedure SetFocus` (`override`) | Moves keyboard focus to the terminal (xterm.js) |
| `function RunCapture(const ACommandLine: string; out AStdOut, AStdErr: string; out AExitCode: Integer; ATimeoutMs: Integer = 0): Boolean` | Regardless of the kind of `Shell`, runs `cmd.exe /c ACommandLine` in pipe mode. Standard output, standard error, and exit code are received separately. Redirection and pipes are handled by cmd.exe. If `ATimeoutMs` is not 0, it is cut off at that time (returns `False`). Messages are processed while waiting |
| `procedure OpenDevTools` | Opens the WebView2 developer tools (for investigation) |

### 4.4 Events

| Event | Type | When |
|---|---|---|
| `OnReady` | `TNotifyEvent` | When the page (xterm.js) is ready |
| `OnStart` | `TNotifyEvent` | When the shell has started |
| `OnExit` | `TCcmdExitEvent` | When the shell has ended (before `CloseOnExit` is processed) |
| `OnOutput` | `TCcmdOutputEvent` | When output arrives. Text with escape sequences removed (per read) |
| `OnLine` | `TCcmdOutputEvent` | When one line of output, complete up to its line break, is fixed (after escape removal) |
| `OnCommand` | `TCcmdOutputEvent` | When a command is executed with Enter (the string taken in 8.5) |
| `OnTitleChange` | `TNotifyEvent` | When the shell's title changes |
| `OnBell` | `TNotifyEvent` | When the bell rings (raised regardless of `BellMode`) |
| `OnResize` | `TCcmdResizeEvent` | When the number of columns or rows changes |
| `OnBufferText` | `TCcmdOutputEvent` | When the result of `RequestBufferText` arrives |
| `OnError` | `TCcmdErrorEvent` | Startup failure, page loading failure, etc. If not set, shown with `ShowMessage` (the same message only once) |

### 4.5 Declarations (private and protected)

The private part holds: the `TCcmdPty`, the `TCXWVWindowParent` and `TWVBrowser`, the ready flag, the current columns and rows, the pending-start flag, a list of output received before the page was ready, the history list, the log file stream and its name and byte count, the history file name, the title, the exit code, and the event fields. Its handlers are:

- `BrowserAfterCreated`, `BrowserInitError`, `BrowserWebMessageReceived`
- `PtyOutput(const AData: string)` (output handed to the main thread by `TCcmdPty`), `PtyExited(AExitCode: Integer)`
- `HandleMessage(const AMsg: string)` (processes notifications from the page; Chapter 6), `SendCmd(const ACmd, AArg: string)` (sends to the page; Chapter 6), `SendOptions` (sends font, colors, cursor, MaxCount, etc.)
- `OpenLog`, `WriteLog`, `AddHistory`, `StripVT` (removes escape sequences), `EmitLines`
- the popup-menu handlers

Protected: `CreateWnd`, `VisibleChanged`, `EnabledChanged`, `FontChanged`, `CMColorChanged`, `Paint`. Public: the constructor, the destructor, `SetFocus`, and the methods of 4.3.

### 4.6 Strings (added to `uCXLang`)

| ID | Japanese | English |
|---|---|---|
| `sCcmdMenuCopy` | コピー(&C) | Copy(&C) |
| `sCcmdMenuPaste` | 貼り付け(&P) | Paste(&P) |
| `sCcmdMenuSelectAll` | すべて選択(&A) | Select All(&A) |
| `sCcmdMenuClear` | 画面を消す(&L) | Clear(&L) |
| `sCcmdExited` | [プロセスが終了しました（コード %d）] | [Process exited with code %d] |
| `sCcmdErrStart` | シェルを起動できませんでした：%s | Could not start the shell: %s |
| `sCcmdErrNoPage` | terminal.html が見つかりません：%s | terminal.html was not found: %s |
| `sCcmdErrNoPty` | この Windows には、ConPTY（擬似コンソール）がありません | This Windows does not have ConPTY (pseudo console) |

They are added to the end of the existing order (both `TCXStr` and `CXTable`).

## 5. TCcmdPty (the ConPTY part)

`TCcmdPty = class`. Runs the shell with ConPTY and handles input, output, size, and exit. It knows nothing about the screen or WebView (the unit to replace for another OS in the future).

### 5.1 Declaration

```pascal
type
  TCcmdPtyDataEvent = procedure(const AData: string) of object;    { output (UTF-8 bytes placed in a string) }
  TCcmdPtyExitEvent = procedure(AExitCode: Integer) of object;

  TCcmdPty = class
  public
    function Start(const AShell, AParams, AWorkDir: string; AEnv: TStrings; ACols, ARows: Integer; out AError: string): Boolean;
    procedure Write(const AData: string);
    procedure Resize(ACols, ARows: Integer);
    procedure Stop;
    property Active: Boolean;
    property ProcessId: Cardinal;
    property OnData: TCcmdPtyDataEvent;
    property OnExit: TCcmdPtyExitEvent;
  end;
```

Internally it holds the pseudo console handle, the input write pipe and output read pipe, the process, thread, and job handles, and the reader thread (`TCcmdPtyReader`).

### 5.2 Start

1. With `CreatePipe`, create the input pipe (read side `InRead` for the shell, write side `FInWrite` for us) and the output pipe (write side `OutWrite` for the shell, read side `FOutRead` for us).
2. `CreatePseudoConsole(MakeCoord(ACols, ARows), InRead, OutWrite, 0, FPC)`. On failure (function missing or non-zero `HRESULT`), return `False` with `AError := CXT(sCcmdErrNoPty)`. On success, `CloseHandle` `InRead` and `OutWrite` (the pseudo console holds them).
3. Create `STARTUPINFOEXW`: `cb := SizeOf`, `dwFlags := STARTF_USESTDHANDLES` (do not let the child inherit the parent's standard handles; a countermeasure for the problem where the child's output does not go to the pseudo console when the parent has no console or its handles are pipes; confirmed in a prototype). Put `PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE` (value `FPC`) in the attribute list.
4. Environment: take the parent's environment and override or add the `name=value` entries of `AEnv`. `CREATE_UNICODE_ENVIRONMENT`.
5. Command line: enclose `AShell` in `"` if it contains spaces, and append `AParams` after a space.
6. `CreateProcessW(nil, command line, nil, nil, False, EXTENDED_STARTUPINFO_PRESENT or CREATE_UNICODE_ENVIRONMENT, environment, AWorkDir, ...)`. On failure, put the text of `GetLastError` in `AError`, call `Stop`, and return `False`.
7. Create a job object (`JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`) and put the child in it (to make sure grandchild processes are also stopped on `Stop` and destruction).
8. Start the output reader thread. `FActive := True`.

`Start` begins with `Stop` to clean up the handles of any previous run.

### 5.3 Output Reading (thread)

1. Read output into an 8KB buffer repeatedly. A partial UTF-8 sequence cut at the end (an incomplete 1–3 bytes) is carried over to the next read, and the bytes are made into a string (UTF-8 bytes placed as they are in a `string`).
2. Data read is collected for a short time (about 10 ms) or up to 64KB, then `OnData` is called via `TThread.Queue` (main thread), so that a large amount of output does not freeze the screen.
3. ConPTY does not close the output pipe even after the child process ends. Therefore the thread does not wait in `ReadFile`; it uses `PeekNamedPipe` to check whether anything can be read (waiting briefly if not). During the wait it checks for the end of the shell with `WaitForSingleObject(FProcess, 0)`.
4. When the end is found, it waits 150 ms, reads everything remaining and hands it over, gets the exit code with `GetExitCodeProcess`, and calls `NotifyExit` on the main thread via `TThread.Queue`. `NotifyExit` performs `TCcmdPty.ReleaseAfterExit` (`ClosePseudoConsole` and releasing handles), then calls `OnExit`.
5. Because reading is finished before `ClosePseudoConsole`, it cannot hang.

### 5.4 Other

| Procedure | Processing |
|---|---|
| `Write(AData)` | Writes `AData` (a string holding UTF-8 bytes) with `WriteFile(FInWrite, …)` (repeating until everything is written). Does nothing if not running |
| `Resize(C, R)` | `ResizePseudoConsole(FPC, MakeCoord(C, R))`. Does nothing if not running |
| `Stop` | If running, `TerminateJobObject` (including grandchildren) → `ClosePseudoConsole(FPC)` → close the input handle. Waits for the reader thread to finish (up to 2 seconds). `OnExit` is not called again if it has already been called |
| `Destroy` | Performs `Stop` and closes all handles |

## 6. Communication Between TCcmd and the Page

Both directions use a single string joining the command name and arguments with a separator (`#1`) (the same design as `TCMonacoEditor` and `TCPreview`). From Pascal it is sent with `PostWebMessageAsString`; from the page with `window.chrome.webview.postMessage`. The sub-separator is `#2`.

### 6.1 Pascal → Page (`SendCmd`)

| Command | Argument | Contents |
|---|---|---|
| `out` | string (converted from UTF-8) | Output. Passed to `term.write` of xterm.js |
| `opt` | `name=value` pairs joined with `#2` | Option settings (Chapter 9): `fontFamily`, `fontSize`, `fgColor`, `bgColor`, `cursorStyle`, `cursorBlink`, `cursorColor`, `selColor`, `scrollback`, `theme` (`light` / `dark`), `palette` (16 colors as `#rrggbb` joined by commas; if empty, the standard of `theme`), `disabled` (input not accepted) |
| `focus` | none | `term.focus()` |
| `paste` | string | `term.paste` (the handling of paste brackets is left to xterm.js) |
| `selectall` | none | `term.selectAll()` |
| `copy` | none | Takes the selection and returns it with `selection` |
| `clearscroll` | none | `term.clear()` |
| `scrollbottom` | none | `term.scrollToBottom()` |
| `find` | next(1)/previous(0) `#2` string `#2` case(1/0) | Search addon |
| `gettext` | none | Returns the full text with `buffertext` |
| `message` | string | Shows one line (such as `sCcmdExited`) on the screen in a different color |
| `bell` | none | Bell flash (`BellMode = bmFlash`) |

### 6.2 Page → Pascal (`HandleMessage`)

| Command | Argument | Contents and processing |
|---|---|---|
| `ready` | none | The page is ready. `FReady := True`. `SendOptions`, then process pending output and `Start`. `OnReady` |
| `input` | string | The user's input. `FPty.Write` (as UTF-8). Discarded if `ReadOnly` is true or `Enabled` is false |
| `resize` | cols `#2` rows | The size changed. Update `FCols`, `FRows` and call `FPty.Resize`. `OnResize` |
| `title` | string | Shell title. `FTitle`. If `AutoCaption`, `Caption`. `OnTitleChange` |
| `bell` | none | Follows `BellMode` (`bmSound`: `MessageBeep`; `bmFlash`: send back `bell`). `OnBell` |
| `cmd` | string | Command executed with Enter (8.5). `AddHistory`. `OnCommand` |
| `selection` | string | Result of `CopySelection`. To the clipboard |
| `buffertext` | string | Result of `RequestBufferText`. `OnBufferText` (to a file if during `SaveBufferTo`) |
| `ctrlv` | none | The page received Ctrl+V (or Ctrl+Shift+V). `Paste` |
| `zoom` | `1` (enlarge) / `-1` (shrink) | Ctrl+Wheel. Changes `Font.Size` by 1 (6–48). `SendOptions` runs through `FontChanged` |
| `drop` | none (the dropped files are attached to the message) | Drop from Explorer. `BrowserWebMessageReceived` takes `ICoreWebView2File.Path` from the attached objects (`AdditionalObjects`), encloses paths containing spaces in `"`, joins them with spaces, and sends back `paste` and `focus`. Does nothing when `ReadOnly` or `Enabled = False`. It does not go through `HandleMessage` |
| `menu` | x `#2` y | Right-click. Show the menu (`PopupMenu`, otherwise the default) |

## 7. The Page (terminal.html)

- `<meta name="color-scheme" content="light dark">`. When `theme` of `opt` is received, `document.documentElement.style.colorScheme` is set to that value (`light` / `dark`), so the scrollbar color follows the theme and not the OS (same as TCPreview and TCMonacoEditor).
- The screen is xterm.js on one `<div id="t">`, filling the window (`width:100%; height:100%`, no margin).
- Startup: `new Terminal({ allowProposedApi: true, scrollback: 1000, fontFamily: 'Consolas', fontSize: 14, cursorBlink: true, convertEol: false })`. `FitAddon` and `SearchAddon` are loaded. `fit()` after `term.open`.
- Size: `ResizeObserver` watches window changes and calls `fit()`. A `resize` (columns and rows) is sent when the size changes, and once at the start.
- Input: `term.onData(d => post('input', d))`. Key handling (`attachCustomKeyEventHandler`):

| Key | Behavior |
|---|---|
| Ctrl+C | If there is a selection, copy (send `selection`). Otherwise send `\x03` with `input` (interrupt) |
| Ctrl+Shift+C | Always copy |
| Ctrl+V, Ctrl+Shift+V, Shift+Insert | Send `ctrlv` (pasting is done on the Pascal side) |
| Other | xterm.js default (arrows, F keys, Alt, Ctrl combinations, etc.) |

- Ctrl+Wheel: a `wheel` event with Ctrl pressed is stopped and `zoom` is sent (`1` if `deltaY < 0`, otherwise `-1`). The standard WebView2 zoom is not used.
- Drop: `dragover` and `drop` are stopped. On `drop`, the files are sent to Pascal with `chrome.webview.postMessageWithAdditionalObjects('drop', files)` (this is the only way to get the file paths). Not sent while `disabled`.

- Title: `term.onTitleChange(t => post('title', t))`.
- Bell: `term.onBell(() => post('bell'))`.
- Right-click: the `contextmenu` event is stopped and `menu` is sent (the Pascal-side menu).
- Taking the command (8.5): when output has stopped for `cIdleMs` (150 ms), the cursor column and row of `term.buffer.active` are remembered as the end of the prompt (`pX`, `pY`). When `\r` is included in `input`, the characters from column `pX` of row `pY` (and following rows if wrapped) to the end of the row (`translateToString(true)`) are joined, leading and trailing spaces are removed, and the result is sent as `cmd` (not sent if empty).
- When ready, `post('ready')`.

## 8. Processing

### 8.1 Start and End

1. `Create`: after `inherited`, set default values of the properties. Remove `csSetCaption` from `ControlStyle`. `BevelOuter := bvNone`. Only at runtime (not at design time), create `FPty`, `FHistory`, `FWindowParent`, and `FBrowser`.
2. `CreateWnd` (at runtime, when first shown): prepare WebView2 with `CXStartWebView2` (call `OnError` on failure) and `FBrowser.CreateBrowser(FWindowParent.Handle)`.
3. `BrowserAfterCreated`: `SetVirtualHostNameToFolderMapping('cx-terminal.local', terminal folder)`, `Navigate('https://cx-terminal.local/terminal.html')`. If `terminal.html` is missing, `OnError(sCcmdErrNoPage)`.
4. When `ready` is received, `SendOptions`. If `AutoStart` or pending (`FPendingStart`), `Start`.
5. `Start`: if the page is not ready, set `FPendingStart := True` and finish. When ready, `FPty.Start(Shell, Params, WorkDir, Environment, FCols, FRows, Err)` (if the size is not decided, `cDefaultCols` and `cDefaultRows`). On failure `OnError(sCcmdErrStart)`. On success `OpenLog`, `OnStart`.
6. `PtyExited`: set `FExitCode`. Close the log. Show `sCcmdExited` with `message` (when `CloseOnExit` is false). `OnExit`. If `CloseOnExit` is true, `Visible := False`.
7. `Stop` and `Destroy`: `FPty.Stop`. Close the log and history files. Free `FBrowser` and `FWindowParent`.

### 8.2 Input (table for `SendKey`)

`SendKey` converts to the following strings and calls `SendText`.

| Key | String sent |
|---|---|
| ↑ ↓ → ← | `ESC[A` `ESC[B` `ESC[C` `ESC[D` (with a modifier, `ESC[1;m` + letter. m: Shift=2, Alt=3, Ctrl=5) |
| Home, End | `ESC[H`, `ESC[F` |
| Insert, Delete | `ESC[2~`, `ESC[3~` |
| PageUp, PageDown | `ESC[5~`, `ESC[6~` |
| F1–F4 | `ESC OP` – `ESC OS` |
| F5–F12 | `ESC[15~`, `17~`, `18~`, `19~`, `20~`, `21~`, `23~`, `24~` |
| Tab, Enter, Backspace, Esc | `#9`, `#13`, `#127`, `#27` |
| Ctrl + letter | `#1` – `#26` |

Characters are converted to UTF-8 before being passed to `FPty.Write`.

### 8.3 Output (`PtyOutput`)

1. If the page is not ready, store it in `FPendingSend` (sent together after it is ready).
2. Send `out` to the page (converted from UTF-8).
3. For `lmRaw`, `WriteLog` as it is. For `lmPlain`, `WriteLog` the text with escape sequences removed (`ESC[…` and `ESC]…BEL/ST` are removed; a carriage return alone is kept as is; `BS` goes back one character).
4. If `OnOutput` is assigned, pass the text with escapes removed. `OnLine` splits the removed text into lines and passes the fixed lines (the remainder without a line break is carried over to the next output).

### 8.4 Log

- `OpenLog`: does nothing for `lmOff`. Creates `LogDir` (if empty, `EXE\Logs`) and opens `yyyymmdd_hhnnsszzz.log` with sharing (`CXCreateFileShared`).
- `WriteLog`: writes in UTF-8. When `LogMaxSize` (KB) is exceeded, closes it and opens a file with a new time.
- A write failure (for example the folder cannot be created) is told to `OnError` only once, and later logging is stopped (the terminal keeps running).

### 8.5 Command History

- When `cmd` is received, `AddHistory`: append to the end of `FHistory` (not added if the same as the previous one). If `HistoryMax` is exceeded, remove from the top.
- `OnCommand`.
- History file: `yyyymmdd_hhnnsszzz-CmdHistory.log` in `HistoryDir` (if empty, `EXE\History`) (time of `Start`). Appended one line at a time whenever commands increase (UTF-8, with sharing).
- How commands are taken is as in Chapter 7. Because they are taken from the characters on screen, recall by arrow keys and completion are also taken correctly. If the prompt does not fit on one line (multi-line prompt), the last line is used.

### 8.6 Size and Focus

- `Resize` (LCL): stretch `FWindowParent` to fill the component. The size of WebView2 is matched with `FBrowser.UpdateSize`. `fit()` on the xterm.js side decides the columns and rows.
- `Enter` (focus): `FBrowser.Focus` (gives the keyboard to WebView2).

### 8.7 RunCapture (pipe mode)

1. Create three `CreatePipe`s (the child's standard input is empty). Standard output and standard error are connected to separate pipes.
2. `CreateProcessW('cmd.exe /c ' + ACommandLine, ..., STARTF_USESTDHANDLES, CREATE_NO_WINDOW or CREATE_UNICODE_ENVIRONMENT)` (using `WorkDir` and `Environment`). No window is created.
3. Read the two pipes alternately with `PeekNamedPipe` and `ReadFile` (so that neither gets stuck). `Application.ProcessMessages` between loop iterations.
4. Get the exit code and close the handles. The output character encoding is taken to be the code page at startup (932 on a Japanese Windows) and converted to UTF-8. If `ATimeoutMs` is exceeded, stop the process and return `False`.

## 9. Colors and Fonts

- Font: `Font.Name` (a list of `Consolas`, `BIZ UDGothic`, `MS Gothic`, `monospace` is appended to the page's `fontFamily` as fallbacks) and `Font.Size` (pt) converted to px (`pt × 96 / 72`) and sent.
- Text color: `Font.Color`. If `clDefault`, the standard of `Theme`.
- Background color: `Color`. If `clDefault`, the standard of `Theme`.
- `Theme`: `ctAuto` is decided by `CsOsIsDark` (OS dark mode). Following OS changes is the same as the other components (matching the mechanism of `uCsEditor`). The standard color schemes are as follows (matching the VS Code terminal).

| Item | Dark | Light |
|---|---|---|
| Background / text | `#1E1E1E` / `#CCCCCC` | `#FFFFFF` / `#333333` |
| Cursor | `#AEAFAD` | `#000000` |
| Selection | `#264F78` | `#ADD6FF` |
| Black / Red / Green / Yellow | `#000000` `#CD3131` `#0DBC79` `#E5E510` | `#000000` `#CD3131` `#00BC00` `#949800` |
| Blue / Magenta / Cyan / White | `#2472C8` `#BC3FBC` `#11A8CD` `#E5E5E5` | `#0451A5` `#BC05BC` `#0598BC` `#555555` |
| Bright Black / Red / Green / Yellow | `#666666` `#F14C4C` `#23D18B` `#F5F543` | `#666666` `#CD3131` `#14CE14` `#B5BA00` |
| Bright Blue / Magenta / Cyan / White | `#3B8EEA` `#D670D6` `#29B8DB` `#E5E5E5` | `#0451A5` `#BC05BC` `#0598BC` `#A5A5A5` |

- When `Color` is other than `clDefault`, the area around the background (the margin of `TCcmd` and the background of `FWindowParent`) is painted in the same color.

## 10. Design Time

- When placed, it shows a frame and the component name (`Name : TCcmd`) as a `TCustomPanel` (same appearance as TCPreview). WebView2 and ConPTY are not run at design time.
- `AutoStart` does nothing at design time.
- It appears in the palette [CX] (icon: `ccmd_icon.lrs`).

## 11. Decisions

| Item | Decision |
|---|---|
| How it runs | ConPTY (Windows 11 only). The shell defaults to `cmd.exe` |
| Screen | xterm.js inside WebView2 |
| Character encoding | Communication with the terminal is UTF-8 (`input`, `out`). The internal code page of cmd.exe is converted by ConPTY |
| Output batching | The reader thread batches about 10 ms or 64KB and hands it to the main thread |
| Start order | The shell is started after the page is ready (`ready`), so the correct columns and rows are passed from the beginning |
| End | A job object stops even grandchild processes. The end of the shell is detected by the reader thread itself (ConPTY does not close the pipe) |
| Log format | Default is text with escapes removed. Full-screen updates such as vi are hard to read in the log (`lmRaw` keeps them raw) |
| Command history | Taken from the characters on screen (decided by the end of the prompt and the moment of Enter) |
| Standard output and standard error | One stream in terminal mode. Use `RunCapture` to separate them |
| Pasting | Ctrl+V, Ctrl+Shift+V, Shift+Insert, and the right-click menu. Multiple lines are enclosed in paste brackets (`?2004`) if the shell has enabled them (`paste` of xterm.js) |
| Scrollbar | Standard xterm.js scrollbar (follows `color-scheme`) |
| IME | Left to the standard behavior of the xterm.js input area (conversion and confirmation must work in WebView2) |
| Design time | WebView2 and ConPTY are not run |
| Relation to other components | Uses `Theme` (`TCMTheme`) of other components, `uCXLang` (strings), and `CXCreateFileShared` (writing with sharing) |

## 12. What to Check When Investigating Problems

| Symptom | Where to look |
|---|---|
| The screen is blank and nothing appears | The location of `terminal.html` (`TerminalPath`, `TerminalFolder` of `WebView2.ini`), `OnError`, `OpenDevTools` |
| Started but nothing appears | Whether `ready` has arrived (`Ready`), `FPendingStart`, 3 of 5.2 (`STARTF_USESTDHANDLES`) |
| Garbled characters | UTF-8 carry-over in 5.3, RunCapture in 8.7 (code page) |
| Columns do not change when the window is resized | The `resize` notification, `ResizePseudoConsole`, `ResizeObserver` |
| The process remains after exit | The job object (7 of 5.2), `Stop` |
| Hangs in `ClosePseudoConsole` | Whether reading was finished before calling (4 and 5 of 5.3) |
| `OnExit` does not come when the shell ends | Exit detection of the reader thread (3 of 5.3) |
| Display of vi or PowerShell breaks | The xterm.js version, `scrollback` and font in `opt` (width of full-width characters) |
| Log or history is not written | `LogMode`, `LogDir` and `HistoryDir` (write permission), failure handling in 8.4 |
| Command history is empty or shifted | Recording of the "end of the prompt" in Chapter 7 (`cIdleMs`), multi-line prompts |
| Scrollbar color does not match the OS | `color-scheme` in Chapter 7 |

## 13. Changes in This Version (1.0, newly created)

A new component, TCcmd, is created. The behavior of existing components does not change. The changed files are as follows.

| File | Change |
|---|---|
| `source/uCcmd.pas` | New |
| `source/design/uCXReg.pas` | Registers `TCcmd`, adds `uCcmd` to uses. Loads `ccmd_icon.lrs` |
| `source/res/ccmd_icon.lrs` | New |
| `source/uCXLang.pas` | Adds 8 strings (4.6) |
| `source/uCXRuntime.pas` | No change (`TerminalFolder` can be read with the existing `CXResolveRuntimeDir`) |
| `packages/cx.lpk`, `cx.pas`, `cxdsgn.lpk` | Add `uCcmd` and the icon |
| `runtime/terminal/` | New (`terminal.html`, `lib/`) |
| `THIRD_PARTY_NOTICES.md` | Adds the source and license of xterm.js (3 rows) |
| `docs/TCcmd_Usage.md`, `docs/en/TCcmd_Design.md`, `TCcmd_Usage.md` | Created after the code was completed |
| `README.md`, `README.ja.md` | Add TCcmd to the component table and description |
