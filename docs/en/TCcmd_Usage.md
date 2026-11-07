# TCcmd User Manual

Author: aotan083
Date: 2026-11-07
Version: 1.0

---

## 1. Overview and Classes

A component that runs cmd.exe, PowerShell, ssh, and similar programs inside a form. The component handles screen display and keyboard input, so no console window appears.

- The shell runs on Windows ConPTY (pseudo console). Redirection (`>`, `>>`, `2>&1`), pipes (`|`), and interactive programs such as `vi`, `ssh`, PowerShell, and `python` all work.
- The screen is drawn by xterm.js inside WebView2 (colors, cursor, full-width characters, selection, scrolling, search).
- To take in the result of a command, use `RunCapture` (standard output, standard error, and the exit code are received separately).
- Output logs and a history of executed commands are saved to files.
- All settings are made in the Object Inspector. Just place it and run it, and it works as a command prompt.

| Item | Details |
|---|---|
| Lazarus | 5.0 or later |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit). Linux and macOS are not supported |
| Palette | CX |
| Required at runtime | Microsoft Edge WebView2 Runtime (already included in Windows 11), WebView2Loader.dll (64-bit), WebView2.ini, the terminal folder (Chapter 2) |
| Memory | About 60MB (WebView2). WebView2 is not started if the screen is never shown |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Contents |
|---|---|---|---|---|
| `TCcmd` | `uCcmd` | cx | `TCustomPanel` | The terminal component |

| Type | Unit | Contents |
|---|---|---|
| `TCcmdLogMode` | `uCcmd` | How the log is written. `lmOff`, `lmPlain`, `lmRaw` |
| `TCcmdCursorStyle` | `uCcmd` | Cursor shape. `ccBlock`, `ccUnderline`, `ccBar` |
| `TCcmdBellMode` | `uCcmd` | How the bell is handled. `bmNone`, `bmSound`, `bmFlash` |

- When you place it on a form, `uCcmd` is added to uses automatically, and cx is added to the project's required packages automatically.
- When creating it in code, write it in uses yourself.

## 2. From Placing on a Form to Running

1. Place TCcmd from the palette [CX] on the form and set `Align = alClient`, for example.
2. Put the files in 2.1 in the same folder as the EXE.
3. Run. When the screen is ready, `cmd.exe` starts automatically (`AutoStart = True`).

- At design time (in the IDE), neither WebView2 nor the shell is started. Only a thin frame and the component name appear.
- To use another shell, write `powershell.exe` or `ssh.exe` in `Shell`, and arguments in `Params`.

### 2.1 Runtime Files

```
MyApp.exe
WebView2.ini                       (always required. 2.2)
WebView2Loader.dll                 (64-bit)
WebView2Data\                      (WebView2 user data. Created automatically)
terminal\
  terminal.html
  lib\
    xterm.js / xterm.css
    addon-fit.js / addon-search.js
    licenses\xterm-LICENSE.txt
Logs\                              (logs. Created automatically)
History\                           (command history. Created automatically)
```

- The terminal folder is `runtime\terminal`.
- Obtain WebView2Loader.dll from the WebView4Delphi repository (https://github.com/salvadordf/WebView4Delphi).
- WebView2 is prepared by the component itself when the screen is first shown. Nothing needs to be written in the application's .lpr.

### 2.2 WebView2.ini

Place it in the same folder as the EXE. It is shared by the CX WebView2 components.

```ini
[WebView2]
LoaderDllPath=
UserDataFolder=
MonacoFolder=
PreviewFolder=
TerminalFolder=

[CX]
Language=
```

| Key | Contents | When empty or omitted |
|---|---|---|
| `LoaderDllPath` | File path of WebView2Loader.dll | WebView2Loader.dll in the EXE's folder |
| `UserDataFolder` | WebView2 user data folder | EXE's folder\WebView2Data |
| `TerminalFolder` | Folder containing `terminal.html` and `lib` | EXE's folder\terminal |
| `MonacoFolder`, `PreviewFolder` | Not used by TCcmd | ― |
| `Language` (`[CX]`) | Display language `ja` or `en` | Windows display language |

- Always place the file. All key values may be empty.
- Relative paths are counted from the EXE's folder. Absolute paths can also be written.
- A `%name%` written in a value is replaced. The name is looked up as a key of the same `[WebView2]` section, then as a Windows environment variable (example: write `CXROOT=C:\CX\runtime`, then `TerminalFolder=%CXROOT%\terminal`). A name that is not found is left as it is.
- It is read only once, the first time it is used after startup.

### 2.3 How the Location of terminal Is Decided

The first one that applies, from the top, is used.

| Order | How it is decided |
|---|---|
| 1 | If `TerminalPath` is not empty, that location |
| 2 | If `TerminalFolder` in WebView2.ini is not empty, that location |
| 3 | `terminal` in the EXE's folder |

- If it is not found, `OnError` is raised ("terminal.html was not found: (location)").

### 2.4 Display Language

The right-click menu, the exit message, and error messages appear in Japanese or English. The language is one setting for all cx components (`Language` in `[CX]` of WebView2.ini; if empty, the Windows display language).

## 3. Keys and Mouse

| Operation | Behavior |
|---|---|
| Characters, arrows, Home, End, PageUp, PageDown, F1–F12, Ctrl+letter | Sent to the shell |
| Drag | Selects a range |
| Ctrl+C | Copies if there is a selection. Otherwise stops the running process (interrupt) |
| Ctrl+Shift+C | Always copies |
| Ctrl+V, Ctrl+Shift+V, Shift+Insert | Paste |
| Right-click | Menu (Copy, Paste, Select All, Clear) |
| Wheel | Scroll |
| Ctrl+Wheel | Changes the text size by 1 (6–48). `Font.Size` changes |
| Drop files from Explorer | Pastes the file paths at the input position (a path containing spaces is enclosed in `"`; multiple files are joined with spaces). Does nothing when `ReadOnly` or `Enabled = False` |

- Japanese input (IME) follows the standard behavior of WebView2.
- When `ReadOnly = True` or `Enabled = False`, key input and pasting are not accepted (output continues to be displayed).

## 4. Properties

| Name | Type | Default | Contents |
|---|---|---|---|
| `Shell` | `string` | `cmd.exe` | The program to run (`powershell.exe`, `ssh.exe`; a full path is also allowed). If empty, `cmd.exe` |
| `Params` | `string` | '' | Startup arguments (e.g. `-NoLogo`). Appended after `Shell` |
| `WorkDir` | `string` | '' | Working folder. If empty, the EXE's folder |
| `Environment` | `TStrings` | empty | Environment variables to add or override (`name=value`). Others are inherited from the application |
| `AutoStart` | `Boolean` | `True` | Call `Start` automatically when the screen is ready |
| `CloseOnExit` | `Boolean` | `False` | Whether to close the screen (`Visible := False`) when the shell ends. If `False`, the screen stays and "[Process exited with code n]" is shown |
| `MaxCount` | `Integer` | 1000 | Number of lines kept on screen (including scrollback). Clamped to 100–10000 |
| `LogMode` | `TCcmdLogMode` | `lmPlain` | How the log is written (6.1) |
| `LogDir` | `string` | '' | Log folder. If empty, `EXE\Logs` |
| `LogMaxSize` | `Integer` | 10240 | Maximum size of one log file (KB). When exceeded, switches to a new file |
| `HistoryDir` | `string` | '' | Command history folder. If empty, `EXE\History` |
| `HistoryMax` | `Integer` | 1000 | Maximum number of entries kept in `CmdHistory` |
| `Font` | `TFont` | Consolas, 10 | Font. Use a fixed-width font. If `Font.Color` is `clDefault`, the text color of `Theme` |
| `Color` | `TColor` | `clDefault` | Background color. If `clDefault`, the background color of `Theme` |
| `Theme` | `TCMTheme` | `ctAuto` | `ctAuto` (follows the OS; changes immediately when the OS theme changes) / `ctLight` / `ctDark` |
| `CursorStyle` | `TCcmdCursorStyle` | `ccBlock` | Cursor shape |
| `CursorBlink` | `Boolean` | `True` | Blink the cursor |
| `CursorColor` | `TColor` | `clDefault` | Cursor color. If `clDefault`, the color of `Theme` |
| `SelectionColor` | `TColor` | `clDefault` | Selection color. If `clDefault`, the color of `Theme` |
| `Caption` | `string` | '' | Title text. While `AutoCaption` is `True`, it follows the title set by the shell |
| `AutoCaption` | `Boolean` | `True` | Make `Caption` follow the shell's title |
| `ReadOnly` | `Boolean` | `False` | If `True`, key input and pasting are not accepted |
| `BellMode` | `TCcmdBellMode` | `bmSound` | Bell handling. `bmNone` (nothing) / `bmSound` (sound) / `bmFlash` (flashes the screen briefly) |
| `TerminalPath` | `string` | '' | Location of `terminal.html` (2.3) |
| `PopupMenu` | `TPopupMenu` | nil | Right-click menu. If nil, the default menu |
| `Align`, `Anchors`, `BorderSpacing`, `Constraints`, `Enabled`, `Visible`, `TabOrder`, `TabStop`, `ShowHint`, `Hint` | | | Standard |

Runtime only (read-only):

| Name | Type | Contents |
|---|---|---|
| `Active` | `Boolean` | Whether the shell is running |
| `ExitCode` | `Integer` | Exit code of the shell (-1 while running) |
| `ProcessId` | `Cardinal` | Process ID of the shell (0 if not running) |
| `Cols`, `Rows` | `Integer` | Current number of columns and rows (decided automatically from the component size and font) |
| `Title` | `string` | Title set by the shell |
| `Ready` | `Boolean` | Whether the screen is ready |
| `CmdHistory` | `TStringList` | Commands executed so far (oldest first) |

- Changes to `Font`, `Color`, `Theme`, `CursorStyle`, `CursorBlink`, `CursorColor`, `SelectionColor`, and `MaxCount` are reflected on screen immediately.
- `Shell`, `Params`, `WorkDir`, and `Environment` take effect from the next `Start`.

## 5. Methods and Events

### 5.1 Methods

| Name | Contents |
|---|---|
| `Start` | Starts the shell. Does nothing if already running. If the screen is not ready, starts once it is ready |
| `Stop` | Ends the shell (including grandchild processes). Does nothing if not running |
| `Restart` | Calls `Stop`, then `Start` |
| `SendText(AText)` | Sends a string to the shell as is (does nothing when `ReadOnly` or `Enabled = False`) |
| `Execute(ALine)` | Sends one line and presses Enter. It is also added to the command history, and `OnCommand` is raised |
| `SendKey(AKey, AShift)` | Sends a key (arrows, Home, End, PageUp, PageDown, F1–F12, Delete, etc.) |
| `SendCtrlC` | Sends Ctrl+C (stops the running process) |
| `Paste` | Pastes the clipboard text |
| `CopySelection` | Puts the selected text on the clipboard |
| `SelectAll` | Selects all |
| `ClearScrollback` | Clears the history scrolled off the top (the current screen stays) |
| `ScrollToBottom` | Scrolls to the bottom |
| `FindNext(AText, AMatchCase)` | Finds the next match and selects it. `AMatchCase` defaults to `False` |
| `FindPrev(AText, AMatchCase)` | Finds the previous match and selects it |
| `RequestBufferText` | Requests the full text of the screen and history. `OnBufferText` is raised when it arrives |
| `SaveBufferTo(AFileName)` | Writes the full text of the screen and history to a UTF-8 file |
| `SetFocus` | Moves keyboard focus to the terminal |
| `RunCapture(ACommandLine, AStdOut, AStdErr, AExitCode, ATimeoutMs)` | 7.3 |
| `OpenDevTools` | Opens the WebView2 developer tools (for investigation) |

### 5.2 Events

| Name | Arguments | When |
|---|---|---|
| `OnReady` | `Sender` | When the screen is ready |
| `OnStart` | `Sender` | When the shell has started |
| `OnExit` | `Sender; AExitCode: Integer` | When the shell has ended (before `CloseOnExit` is processed) |
| `OnOutput` | `Sender; const AText: string` | When output arrives. Text with escape sequences removed |
| `OnLine` | `Sender; const AText: string` | When one line of output, complete up to its line break, is fixed |
| `OnCommand` | `Sender; const AText: string` | When a command is executed with Enter (the typed string) |
| `OnTitleChange` | `Sender` | When the shell's title changes |
| `OnBell` | `Sender` | When the bell rings (raised regardless of `BellMode`) |
| `OnResize` | `Sender; ACols, ARows: Integer` | When the number of columns or rows changes |
| `OnBufferText` | `Sender; const AText: string` | When the result of `RequestBufferText` arrives |
| `OnError` | `Sender; const AMessage: string` | Startup failure, screen loading failure, etc. If not set, a message is shown (the same message only once) |

## 6. Log and History

### 6.1 Log

At the time of `Start`, `LogDir\yyyymmdd_hhnnsszzz.log` is created and the output is written to it (UTF-8).

| `LogMode` | What is written |
|---|---|
| `lmOff` | No log is written |
| `lmPlain` (default) | Text with escape sequences removed |
| `lmRaw` | Raw output (with escape sequences) |

- When `LogMaxSize` (KB) is exceeded, it switches to a new file with a new timestamp.
- It can be read by other programs while still open (written with sharing).
- Full-screen display such as `vi` is hard to read with `lmPlain`.
- If writing is impossible (for example the folder cannot be created), `OnError` is told only once and only the log stops (the terminal keeps running).

### 6.2 Command History

- Commands executed with Enter are appended, one per line, to `HistoryDir\yyyymmdd_hhnnsszzz-CmdHistory.log` (UTF-8). They are also added to `CmdHistory` (a command identical to the previous one is not added; when `HistoryMax` is exceeded, the oldest are removed).
- Commands entered through arrow-key recall or completion are also taken correctly, because they are read from the characters on screen.
- If the prompt spans multiple lines, the last line is used.

## 7. Examples

### 7.1 Just Place It (No Code)

Place TCcmd on the form, set `Align = alClient`, and put the files from 2.1 next to the EXE.

### 7.2 Use PowerShell

```pascal
Cmd1.Shell := 'powershell.exe';
Cmd1.Params := '-NoLogo';
Cmd1.WorkDir := 'C:\work';
Cmd1.Environment.Add('MY_VAR=abc');
Cmd1.Restart;
```

### 7.3 Run a Command and Receive the Result

```pascal
var
  O, E: string;
  Code: Integer;
begin
  if Cmd1.RunCapture('dir /b *.pas | sort', O, E, Code, 10000) then
    Memo1.Text := O                  // standard output
  else
    ShowMessage('Timed out');
end;
```

- `RunCapture` runs with `cmd.exe /c` regardless of the kind of `Shell`. Redirection and pipes are handled by cmd.exe. No window appears.
- If `ATimeoutMs` is 0, it waits indefinitely. If the time is exceeded, the process is stopped and `False` is returned.
- While waiting, form operations (messages) continue to be processed.
- The output is not shown on this screen.

### 7.4 Run a Command on the Screen

```pascal
Cmd1.Execute('dir');
```

### 7.5 Close When It Ends

```pascal
Cmd1.CloseOnExit := True;            // the screen disappears on exit
Cmd1.OnExit := @Cmd1Exit;

procedure TForm1.Cmd1Exit(Sender: TObject; AExitCode: Integer);
begin
  Caption := Format('Exited (code %d)', [AExitCode]);
end;
```

### 7.6 Create in Code

```pascal
uses
  uCcmd;

procedure TForm1.FormCreate(Sender: TObject);
var
  T: TCcmd;
begin
  T := TCcmd.Create(Self);
  T.Align := alClient;
  T.Theme := ctDark;
  T.Parent := Self;
end;
```

## 8. Limitations

- Windows 11 only.
- In terminal mode, standard output and standard error are merged into one stream (the same as a real terminal). To separate them, use `RunCapture`.
- Transparency (translucency) is not supported.
- To place multiple terminals side by side, put one TCcmd on each tab of a TCPageControl.
