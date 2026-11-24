# TCGrepFile Design Document

Author: aotan083
Date: 2026-11-17
Version: 1.0

---

**Operating environment**: Lazarus 5.0 or later (FPC 3.2.2). Lazarus 4.8 and earlier are not supported.

## 1. Purpose and Policy

- A component (`TCGrepFile`) that **searches the files in a folder by the text inside them** (grep search). A `TComponent` without a screen of its own. It can be used on its own.
- The only component the user places is `TCGrepFile`. The processing that collects the target files uses `TCFindWorker` of `uCFindFile` (`TCFindFile_Design.md` 3.6) inside. `TCFindFile` is not changed.
- The search runs in a separate thread. The lines found are handed to the main thread in batches.
- How the results are delivered is specified by the user (`OutputMode`).
  - `omEvent` (default): the lines found are delivered with `OnFound`.
  - `omFile`: the lines found are written to a file (`OnFound` is not raised).
- The results of a search made with `omEvent` can be written to a file afterwards with `SaveResults`.
- The format of the file is, on each line, "path(line number): text of the line". It is a form that can be used for tag jumping (jumping to that line) (the same form as the grep results of Visual Studio, Hidemaru, and Sakura Editor). The function in TCMonacoEditor and TCsEditor that jumps from a result line to the line of that file is made separately (it is not included in this component). For that, the function `CGrepParseLine`, which reads one line back, is provided (3.5). The character encoding is UTF-8 (without BOM). An existing file is overwritten.

### 1.1 Not Included

- Replacing.
- Showing the lines before and after (context).
- A search that spans several lines (the search is line by line).
- Inside compressed files such as zip.
- Encodings other than those described in 3.4, such as UTF-16 (without BOM) and EUC-JP.
- Saving search conditions.
- Showing in `TCListView` (receive with `OnFound` and show it in the application; `TCListView` is not changed).
- Linux / macOS (Windows 11 only).

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCGrepFile.pas` | cx (run time) | `TCGrepFile`, `TCGrepMatcher` (line matching), `CGrepFormatLine` (a function that makes one output line), `CGrepParseLine` (a function that reads one output line back into a path and a line number), `CGrepIsFullPath` (whether it is a full path), `CGrepDecodeBytes` (binary detection, encoding detection, and conversion) |
| `uCXReg.pas` (`source\design`), `cnavigation_icon.lrs` | cxdsgn (design time) | Registration in the [CX] palette and the icon (three for `TCGrepFile` are added to `cnavigation_icon.lrs`) |
| `uCXLang.pas` | cx (run time) | Strings are added (4.3) |

- uses of `uCGrepFile`: `Classes, SysUtils, SyncObjs, Windows, LazUTF8, LConvEncoding, RegExpr, uCXLang, uCFindFile`.
- No initialization or finalization.
- The packages remain two: cx and cxdsgn.

## 3. TCGrepFile

`TCGrepFile = class(TComponent)`. It has no screen of its own.

### 3.1 Types and Constants

```pascal
type
  TCGrepMatchMode = (gmContains, gmRegex);                  { contains / regular expression }
  TCGrepOutputMode = (omEvent, omFile);                     { deliver with OnFound / write to a file }

  TCGrepFoundEvent = procedure(Sender: TObject; const APath: string; ALine: Integer; const AText: string) of object;
  TCGrepProgressEvent = procedure(Sender: TObject; const AFile: string; AFiles: Integer; AFound: Integer) of object;
  TCGrepFinishedEvent = procedure(Sender: TObject; AFiles: Integer; AFound: Integer; AReason: TCFindStopReason) of object;
  TCGrepErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;
```

- `TCFindStopReason` (`frDone`, `frStopped`, `frLimit`, `frError`) is the one of `uCFindFile`. `frLimit` is when the number of lines found reached `MaxResults`.

| Constant | Value | Contents |
|---|---|---|
| `cGrepFlushCount` | 50 | The number of lines found after which they are handed to the main thread (or to the file) |
| `cGrepFlushMs` | 100 | The same, as time (milliseconds). Whichever of the count and the time comes first |
| `cGrepProgressMs` | 200 | The interval of `OnProgress` |
| `cGrepMaxDef` | 10000 | The default value of `MaxResults` |
| `cGrepMaxFileDef` | 10485760 | The default value of `MaxFileSize` (10 MB) |
| `cGrepMaxLine` | 1000 | The maximum length (in bytes) of the text of a line. A longer line is cut here and `...` is added at the end |
| `cGrepBinaryCheck` | 8192 | The number of bytes at the start that are checked to detect binary |

### 3.2 Properties

| Name | Type | Default | Exposure | Contents |
|---|---|---|---|---|
| `Root` | `string` | '' | published | The folder to start searching from |
| `FileMask` | `string` | `*` | published | The names of the target files (wildcards; several separated by `;`; example `*.pas;*.lfm`). Matched by file name only |
| `Pattern` | `string` | '' | published | The text to search for inside the files (its meaning changes with `MatchMode`) |
| `MatchMode` | `TCGrepMatchMode` | `gmContains` | published | The method of matching lines |
| `CaseSensitive` | `Boolean` | `False` | published | Whether upper and lower case are distinguished |
| `IncludeSubfolders` | `Boolean` | `True` | published | Whether to search subfolders too |
| `SearchHidden` | `Boolean` | `False` | published | Whether to search files and folders with the hidden or system attribute too |
| `MaxResults` | `Integer` | 10000 | published | The maximum number of lines found. 0 means no limit. A value below 0 becomes 0 |
| `MaxFileSize` | `Int64` | 10485760 | published | The maximum size of a file to read (in bytes). Larger files are skipped. 0 means no limit. A value below 0 becomes 0 |
| `OutputMode` | `TCGrepOutputMode` | `omEvent` | published | How the results are delivered |
| `OutputFile` | `string` | '' | published | The file to write to with `omFile` (UTF-8, without BOM; overwritten if it exists) |
| `Active` | `Boolean` | - | public (read) | Whether a search is running |
| `FoundCount` | `Integer` | - | public (read) | The number of lines found so far |
| `FileCount` | `Integer` | - | public (read) | The number of files examined so far (skipped files are not counted) |

- While a search is running, changing the settings does not affect that search (they are copied at `Start`).

### 3.3 Methods

| Method | Contents |
|---|---|
| `function Start: Boolean` | Starts searching in a separate thread. `False` if already searching. If `Root` is not a folder, `Pattern` is empty, the expression is not valid (regular expression or `FileMask`), or with `omFile` `OutputFile` is empty or cannot be written, it raises `OnError` and returns `False` (does not search). With `omFile`, `OutputFile` is recreated here (made empty) |
| `procedure Stop` | Stops. It does not wait (`OnFinished` arrives with `frStopped`) |
| `function WaitFor(ATimeoutMs: Integer): Boolean` | Waits, processing messages, until the search ends (`OnFinished` arrives). `True` if it ended in time |
| `function GrepAll(AResult: TStrings): Integer` | Searches in the calling thread and puts each output line (in the form of `CGrepFormatLine`) into `AResult`. Raises no events. Returns the number of lines found. Errors are exceptions (`ECFindPattern`, `EInOutError`). For checking and scripts |
| `function SaveResults(const AFileName: string): Boolean` | Writes the results of a search made with `omEvent` (the last search; kept in memory) to a file (the format is in 3.5; overwritten). If the folder to save to does not exist, it is created automatically (including intermediate folders). `True` if it could write. Even with 0 results, it creates an empty file and returns `True`. With `omFile` (the results are not in memory), or when the folder cannot be created or the file cannot be written, `False` (and `OnError` is also raised) |
| `function CheckPattern(out AError: string): Boolean` | Whether `Pattern` and `FileMask` can be used (`Pattern` is not empty, a regular expression can be built, and `FileMask` is valid). If they cannot be used, a message goes into `AError` |

- With `omEvent`, the lines found are kept in memory up to `MaxResults` (unlimited when 0) (they are cleared at the next `Start`).

### 3.4 How Files Are Read

1. The target files are found by `TCFindWorker` (`Mode := fmWildcard`, `Pattern := FileMask`, `IncludeFiles := True`, `IncludeFolders := False`, `MaxResults := 0`; hidden items and reparse points are handled as in 4.1 of `TCFindFile_Design.md`). Each time a file is found (`OnItem`), that file is read and searched on the spot, in the same thread.
2. Files larger than `MaxFileSize` (if not 0) are skipped.
3. The file is read entirely into memory (files that cannot be read or opened are skipped silently).
4. If a NUL (0) is contained in the first `cGrepBinaryCheck` bytes, the file is skipped as binary (UTF-16 with a BOM is recognized by its BOM before this check and is not treated as binary).
5. The character encoding is decided in the following order and converted to UTF-8. Steps 4 and 5 are done by the function `CGrepDecodeBytes(const ABytes: TBytes; out AText: string): Boolean` (`False` for binary; for an empty file, `True` and empty text).
   1. If the BOM is UTF-8 (EF BB BF), remove the BOM and treat it as UTF-8.
   2. If the BOM is UTF-16LE (FF FE) or UTF-16BE (FE FF), convert to UTF-8.
   3. If there is no BOM, check whether the whole is valid UTF-8. If so, UTF-8.
   4. If not, regard it as CP932 (Shift-JIS) and convert to UTF-8 (`LConvEncoding.CP932ToUTF8`).
6. Split into lines: any of `CRLF`, `LF`, and `CR` is a line break. Line numbers start from 1.
7. Line by line, `TCGrepMatcher.Match(line)`. If it matches, it is a line found (path, line number, text of the line). When the text of a line exceeds `cGrepMaxLine` bytes, it is cut and `...` is added at the end (a UTF-8 character is not cut in the middle).
8. The file that is the output destination of `omFile` is not searched even if it becomes a target file (so that results do not generate results).

### 3.5 The Output Format

```
C:\app\laz\CXComponents\source\uCFindFile.pas(123): procedure TCFindThread.Execute;
```

- One line = `path` + `(` + `line number` + `): ` + `text of the line`. `CGrepFormatLine(APath, ALine, AText): string`.
- **Reading back for tag jumping**: `CGrepParseLine(const S: string; out APath: string; out ALine: Integer): Boolean`. Counting from the start of the line, the part before the first "`(` + digits only + `): `" becomes `APath` and the digits become `ALine`. `False` if not found. Parentheses that are not digits only, such as `(x86)` in a path, are skipped.
- Spaces at the start of the text of a line are kept as they are. `CR` and `LF` at the end of the line are not included.
- Lines are separated by `CRLF`. UTF-8 (without BOM). The writing of `omFile`, `SaveResults`, and the `AResult` of `GrepAll` (one line each, without `CRLF`) all have the same format.

### 3.6 Events

All are called in the main thread.

| Event | When |
|---|---|
| `OnFound(Sender, APath, ALine, AText)` | When one line is found (only with `omEvent`). The thread hands lines over in batches every `cGrepFlushCount` items or `cGrepFlushMs`, and each time this handler is called in succession for every line in the batch |
| `OnProgress(Sender, AFile, AFiles, AFound)` | While searching, every `cGrepProgressMs`. The file being read, the number of files examined, and the number of lines found |
| `OnFinished(Sender, AFiles, AFound, AReason)` | When finished (after all `OnFound` calls; with `omFile`, after the file is closed) |
| `OnError(Sender, AMessage)` | When `Start` could not begin. When, with `omFile`, writing became impossible during the search (the search is stopped and `OnFinished` is `frError`) |

### 3.7 Line Matching (`TCGrepMatcher`)

One is created per thread.

```pascal
TCGrepMatcher = class
public
  constructor Create(AMode: TCGrepMatchMode; const APattern: string; ACaseSensitive: Boolean);  { ECFindPattern if not valid }
  function Match(const ALine: string): Boolean;
end;
```

| `MatchMode` | Matching |
|---|---|
| `gmContains` | Whether the line contains `Pattern`. When case is not distinguished, both are made `UTF8LowerCase` and `Pos` is used |
| `gmRegex` | `TRegExpr`. `Expression := Pattern`, `ModifierI := not CaseSensitive`. `Exec(line)` (true if it matches anywhere in the line). If the expression is not valid, `ECFindPattern` from `Create` (the message is `TRegExpr.ErrorMsg`) |

- Lines are handled as UTF-8. `.` and `[ ]` in a regular expression work on bytes (the same as 3.5 of `TCFindFile_Design.md`).
- Spaces at the start and end of `Pattern` are compared as they are.

## 4. Processing

### 4.1 The Thread `TCGrepThread` (a Class in the Implementation)

1. At `Start`, the settings are copied into `TCFindWorker` and the settings for line matching, and handed to the thread. `TCGrepMatcher` is created inside the thread.
2. With `omFile`, the thread receives and holds the `OutputFile` (a `TFileStream`) that `Start` recreated. The thread appends the lines found to it and closes it when finished.
3. Call `TCFindWorker.Run`. For each file found, read and search that file as described in 3.4.
4. The lines found are collected in the thread's buffer. Every `cGrepFlushCount` items or `cGrepFlushMs`, with `omEvent` they are handed to the main thread with `Queue`, and with `omFile` they are appended to the file.
5. Every `cGrepProgressMs`, `OnProgress` with `Queue`.
6. `StopFlag` (set by `Stop`) is checked for every file and every line match. If true, the buffer is handed over and the search ends with `frStopped` (the same as 6 of 4.1 in `TCFindFile_Design.md`; `Terminate` is not used).
7. When the number of lines found reaches `MaxResults` (if not 0), the buffer is handed over and the search ends with `frLimit`.
8. With `omFile`, the file is closed when finished.
9. Finally `OnFinished` is queued (after all `OnFound` calls).

**Internal parts**: the body of the search is `TCGrepWorker` (used from the thread and from the synchronous `GrepAll`). Inside `Run`, it creates a `TCGrepMatcher` and a `TCFindWorker`. For each file found (`TCFindWorker.OnItem`), it reads the file, splits it into lines, and matches. `Stop` sets both its own stop flag and the stop flag of `TCFindWorker`. `SkipFile` holds a file that is not examined (the output destination of `omFile`). When the number of lines found reaches `MaxResults`, it sets the stop flag and makes the reason `frLimit`.

### 4.2 `Start`, `Stop`, `Destroy`

The same as 4.2 of `TCFindFile_Design.md` (the thread is cleaned up with `FDestroying`, `Detach`, `RemoveQueuedEvents`, and `DeliverFinished` before `OnFinished`).

### 4.3 Strings (Added to `uCXLang`)

| ID | Japanese | English |
|---|---|---|
| `sGrErrEmpty` | 検索する文字を入力してください | Enter the text to search for |
| `sGrErrOutput` | 結果のファイルを書けません：%s | The result file could not be written: %s |
| `sGrErrNoResult` | 保存する結果がありません（結果を、ファイルへ直接書き出す設定です） | There are no results to save (results are being written directly to a file) |

- The message when `Root` does not exist uses `sSbErrNoRoot` (Chapter 5 of `TCSearchBox_Design.md`).
- The message when a regular expression or wildcard pattern is not valid is the error message of `TRegExpr` or `TMaskList`.

## 5. Design Time

- It appears in the component area below the form (the icon is in `cnavigation_icon.lrs`). It appears in the [CX] palette. The search is not run.

## 6. Decisions

| Item | Decision |
|---|---|
| Number of components | The user places only `TCGrepFile`. The processing that collects files uses `TCFindWorker` of `uCFindFile` inside (`TCFindFile` is not changed) |
| How results are delivered | `OutputMode`: either `omEvent` (default; `OnFound`) or `omFile` (write to a file), only one. Both at the same time is not done |
| Saving | The results of a search made with `omEvent` can be written to a file afterwards with `SaveResults` |
| File format | On each line, "path(line number): text of the line" (a form usable for tag jumping). UTF-8 (without BOM). An existing file is overwritten |
| Tag jumping | This component has only up to the function that reads one line back (`CGrepParseLine`). The function that jumps to a line is made separately on the editor side |
| How to match | Contains, regular expression (line by line). A search that spans several lines is not done |
| Character encoding | BOM (UTF-8, UTF-16). Without a BOM, check whether it is valid UTF-8, and if not, CP932. Others are not handled |
| Files skipped | Binary (a NUL in the first 8192 bytes), those larger than `MaxFileSize` (default 10 MB), and those that cannot be read |
| Long lines | Cut at 1000 bytes and `...` is added |
| Maximum number of results | `MaxResults` (default 10000 lines). What is kept in memory is also up to this number |
| Thread | The search runs in a separate thread. Collecting files and searching their contents are done in the same thread, one after the other |
| Design time | Appears in the component area. The search is not run |

## 7. Where to Look When Investigating Problems

| Symptom | Where to look |
|---|---|
| `Start` is `False` | The message of `OnError`. `Root`, `Pattern`, `FileMask`, `OutputFile` |
| A line that should be found does not appear | `FileMask` (is it a target file?). `MaxFileSize` and binary detection (2 and 4 of 3.4). The character encoding (5 of 3.4) |
| Japanese text is shown garbled | The detection of the character encoding (5 of 3.4). Encodings that are neither valid UTF-8 nor CP932 (such as EUC-JP) are not supported |
| A regular expression with Japanese does not match | That `.` works on bytes (3.7) |
| The result file itself appears in the result file | 8 of 3.4 (`OutputFile` is excluded from the targets) |
| It does not stop although searching | Check of `StopFlag` (6 of 4.1) |
| `SaveResults` is `False` | Whether `OutputMode` is `omFile`. The message of `OnError` |

## 8. Additions on the Editor Side (`TagJump` of TCMonacoEditor and TCsEditor)

From a result line ("path(line number): text of the line"), jump to the line of that file. `TCGrepFile` has no mechanism to call an editor (`TCGrepFile` does not know the editors). Only one method is added on the editor side.

| Item | Now | After the change | Reason for the change | Risk |
|---|---|---|---|---|
| Tag jump | None. `OpenFile(file name)`, `SetCursorPos(line, column)`, and `LineText` (the text of the cursor line) exist | Add `function TagJump(const ALine: string = ''): Boolean` to both | So that a result file can be opened in the editor and you can jump from there to the line of the original file | Only a method is added. The present `OpenFile`, `SetCursorPos`, keys, actions, and events are not changed |

**Behavior of `TagJump(ALine)`**

1. If `ALine` is empty, the text of the cursor line (`LineText`) is used.
2. Split into a path and a line number with `CGrepParseLine` (3.5). `False` if it cannot be split.
3. Only full paths are accepted (`CGrepIsFullPath`; a relative path gives `False`). `False` if the file does not exist.
4. `OpenFile(path)` (if it is already open, that tab is made active). `False` if it cannot be opened.
5. Jump to that line with `SetCursorPos(line number, 1)`. If the line number is larger than the number of lines in the file, the last line (the present behavior of `SetCursorPos`).
6. `True`.

- It is not connected to keys, menus, or the standard actions (25). The application calls `TagJump` from any key, menu, or button it likes (for example from a menu or `OnKeyDown` of the application, not from `OnDblClick` of the editor).
- `TCMonacoEditor` is asynchronous because of WebView2, but the commands issued by `OpenFile` and `SetCursorPos` are processed in order, so `TagJump` only needs to call `SetCursorPos` right after `OpenFile` (it does not hold a reservation to jump after loading). `GetCursorPos` and `LineText` need a short wait before the values arrive.
- `uCGrepFile` is added to the uses of `uCsEditor` and `uCmonacos` (to use `CGrepParseLine`).

## 9. Changes in This Version (1.0; New)

| File | Change |
|---|---|
| `source/uCGrepFile.pas` | New |
| `source/design/uCXReg.pas`, `source/res/cnavigation_icon.lrs` | Registration and icon (`TCGrepFile` is added) |
| `source/uCXLang.pas` | Strings are added (4.3) |
| `source/uCsEditor.pas`, `source/uCmonacos.pas` | `TagJump` is added (Chapter 8) |
| `packages/cx.lpk`, `cx.pas` | `uCGrepFile` is added |
| `docs/TCGrepFile_Usage.md`, `TCGrepFile_Design.md`, and the same names in `docs/en` | The manual and the English version |
| `docs/TCMonacoEditor_Usage.md`, `TCsEditor_Usage.md`, and the same names in `docs/en` | `TagJump` is added |
