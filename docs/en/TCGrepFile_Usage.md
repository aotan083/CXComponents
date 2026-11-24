# TCGrepFile User Manual

Author: aotan083
Date: 2026-11-17
Version: 1.0

---

**Operating environment**: Lazarus 5.0 or later (FPC 3.2.2). Lazarus 4.8 and earlier are not supported.

## 1. Overview and Classes

A component that searches the files in a folder **by the text inside them** (grep search). It has no screen of its own (when placed on a form, it appears in the component area below the form).

- The target files are narrowed down by name (such as `*.pas;*.lfm`). Each of those files is opened in turn and searched line by line.
- Two ways to match: contains, and regular expression.
- The search runs in a separate thread, so the screen does not freeze while it searches.
- One result line has the form **"path(line number): text of the line"**. It is the same form as the grep results of Visual Studio, Hidemaru, and Sakura Editor, and can be used for tag jumping (`TagJump` of TCMonacoEditor and TCsEditor; Chapter 9).
- You choose how the results are delivered (`OutputMode`).
  - `omEvent` (default): receive the lines found with `OnFound`.
  - `omFile`: write the lines found to a file.
- The results of a search made with `omEvent` can be written to a file afterwards with `SaveResults`.
- The character encoding is detected automatically (UTF-8, UTF-16 (with BOM), CP932 (Shift-JIS)). Binary files and files that are too large are skipped.

| Item | Contents |
|---|---|
| Lazarus | 5.0RC1 or later |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Classes and Units

| Class | Unit | Package | Parent class | Contents |
|---|---|---|---|---|
| `TCGrepFile` | `uCGrepFile` | cx | `TComponent` | Searches the contents of files (grep search) |
| `TCGrepMatcher` | `uCGrepFile` | cx | `TObject` | Checks whether a line matches. Used by `TCGrepFile`. Can also be used on its own |

| Type | Unit | Contents |
|---|---|---|
| `TCGrepMatchMode` | `uCGrepFile` | `gmContains` (contains), `gmRegex` (regular expression) |
| `TCGrepOutputMode` | `uCGrepFile` | `omEvent` (deliver with `OnFound`), `omFile` (write to a file) |
| `TCGrepFoundEvent` | `uCGrepFile` | `procedure(Sender: TObject; const APath: string; ALine: Integer; const AText: string) of object` |
| `TCGrepProgressEvent` | `uCGrepFile` | `procedure(Sender: TObject; const AFile: string; AFiles: Integer; AFound: Integer) of object` |
| `TCGrepFinishedEvent` | `uCGrepFile` | `procedure(Sender: TObject; AFiles: Integer; AFound: Integer; AReason: TCFindStopReason) of object` |
| `TCGrepErrorEvent` | `uCGrepFile` | `procedure(Sender: TObject; const AMessage: string) of object` |

- `TCFindStopReason` (the reason the search ended: `frDone`, `frStopped`, `frLimit`, `frError`) is a type of `uCFindFile` (`TCFindFile_Usage.md` 1.1). In code that uses `OnFinished`, also write `uCFindFile` in uses. `frLimit` means the number of lines found reached `MaxResults`.
- When placed on a form, `uCGrepFile` is added to uses automatically, and cx is added to the project's required packages automatically.
- When creating it in code, write it in uses yourself.

### 1.2 The Form of a Result Line

```
C:\app\laz\CXComponents\source\uCFindFile.pas(123): procedure TCFindThread.Execute;
```

- One line = `path` + `(` + `line number` + `): ` + `text of the line`. Line numbers start from 1.
- Spaces at the start of the line are kept as they are. The line break at the end is not included.
- When a line is longer than 1000 bytes, it is cut at 1000 bytes and `...` is added at the end.
- When written to a file, it is UTF-8 (without BOM) and lines are separated by CRLF.
- The following two functions create a line of this form and read it back.

| Name | Parameters | Return value | Contents |
|---|---|---|---|
| `CGrepFormatLine` | `const APath: string; ALine: Integer; const AText: string` | `string` | Creates one result line |
| `CGrepParseLine` | `const S: string; out APath: string; out ALine: Integer` | `Boolean` | Reads one result line back into a path and a line number. Counting from the start, the part before the first "`(` + digits only + `): `" is the path (parentheses that are not digits only, such as `(x86)` in a path, are skipped). `False` if it is not in this form |

### 1.3 Files That Are Searched and Files That Are Skipped

| Item | Behavior |
|---|---|
| `FileMask` | The names of the files to search (wildcards). The default is `*` (all). Several patterns separated by `;`, such as `*.pas;*.lfm` |
| Subfolders | `IncludeSubfolders` (default `True`). Junctions and symbolic links are not entered |
| Hidden and system attributes | When `SearchHidden` (default `False`) is `False`, they are not searched (hidden folders are not entered either) |
| Binary files | Skipped (there is a NUL (0) in the first 8192 bytes; UTF-16 with a BOM is not treated as binary) |
| Large files | Files larger than `MaxFileSize` (default 10 MB) are skipped. 0 means no limit |
| Files that cannot be read | Skipped silently (not an error) |
| The output file | With `omFile`, `OutputFile` itself is not searched |

The character encoding is decided in this order.

1. If the start is a BOM (UTF-8 or UTF-16), follow it.
2. If there is no BOM, check whether the whole is valid UTF-8. If it is, UTF-8.
3. If not, it is regarded as CP932 (Shift-JIS).
4. Other encodings, such as EUC-JP and UTF-16 without a BOM, are not supported (they cannot be read correctly).

### 1.4 How Lines Are Matched

| `MatchMode` | How to write `Pattern` | Example |
|---|---|---|
| `gmContains` (default) | Characters contained in the line | `TODO` |
| `gmRegex` | A regular expression (FPC `RegExpr`). It is enough to match anywhere in the line | `^\s*begin\b` |

- Upper and lower case are not distinguished when `CaseSensitive` is `False` (default).
- Lines are matched as UTF-8. In a regular expression, `.` and `[ ]` work on bytes (an expression that specifies a number of Japanese characters does not behave as expected).
- The search is line by line. A search that spans several lines is not possible.

## 2. From Placing on a Form to Running

1. Place TCGrepFile on the form from the [CX] palette.
2. Set `Root` (the folder to start searching from), `FileMask` (the target files), and `Pattern` (the text to search for) in the Object Inspector or in code.
3. Double-click `OnFound` on the Events tab and write the code that uses the lines found.
4. Call `Start` in code.

## 3. Properties

| Name | Type | Access | Contents |
|---|---|---|---|
| `Root` | `string` | Read/Write | The folder to start searching from |
| `FileMask` | `string` | Read/Write | The names of the files to search (wildcards; several separated by `;`; default `*`). Matched by file name only |
| `Pattern` | `string` | Read/Write | The text to search for inside the files (how to write it depends on `MatchMode`; 1.4) |
| `MatchMode` | `TCGrepMatchMode` | Read/Write | The method of matching lines (default `gmContains`) |
| `CaseSensitive` | `Boolean` | Read/Write | Whether upper and lower case are distinguished (default `False`) |
| `IncludeSubfolders` | `Boolean` | Read/Write | Whether to search subfolders too (default `True`) |
| `SearchHidden` | `Boolean` | Read/Write | Whether to search files and folders with the hidden or system attribute too (default `False`) |
| `MaxResults` | `Integer` | Read/Write | The maximum number of lines found (default 10000). 0 means no limit. A value below 0 becomes 0. The search stops when it is reached (`frLimit`) |
| `MaxFileSize` | `Int64` | Read/Write | The maximum size of a file to read (in bytes; default 10485760 = 10 MB). Larger files are skipped. 0 means no limit. A value below 0 becomes 0 |
| `OutputMode` | `TCGrepOutputMode` | Read/Write | How the results are delivered (default `omEvent`) |
| `OutputFile` | `string` | Read/Write | The file to write to with `omFile`. It is recreated when the search starts (an existing file is overwritten) |
| `Active` | `Boolean` | Read | `True` while searching. Run time only |
| `FoundCount` | `Integer` | Read | The number of lines found so far. Run time only |
| `FileCount` | `Integer` | Read | The number of files examined so far (binary files, files that are too large, and files that cannot be read are not counted). Run time only |

- Changing settings while a search is running does not affect that search (it searches with the settings at the time of `Start`).

## 4. Methods

| Name | Parameters | Return value | Contents |
|---|---|---|---|
| `Start` | - | `Boolean` | Starts searching in a separate thread. Returns `False` (without searching) after raising `OnError` if it is already searching, `Root` is not a folder, `Pattern` is empty, the expression is not valid (regular expression or `FileMask`), or with `omFile` `OutputFile` is empty or cannot be written |
| `Stop` | - | - | Stops the search. It does not wait for it to stop (`OnFinished` arrives with `frStopped`) |
| `WaitFor` | `ATimeoutMs: Integer` | `Boolean` | Waits, processing messages, until the search ends (`OnFinished` arrives). Returns `True` if it ended in time. `-1` means no time limit |
| `GrepAll` | `AResult: TStrings` | `Integer` | Searches in the calling thread and puts each result line (the form of 1.2) into `AResult` (cleared first). Returns the number of lines found. Raises no events. Raises `EInOutError` if `Root` is not a folder, and `ECFindPattern` if `Pattern` is empty or the expression is not valid. Chapter 5 |
| `SaveResults` | `const AFileName: string` | `Boolean` | Writes the results of a search made with `omEvent` to a file. Chapter 6 |
| `CheckPattern` | `out AError: string` | `Boolean` | Before starting, checks whether `Pattern` and `FileMask` can be used. If not, returns `False` with the reason in `AError`. Chapter 7 |

## 5. Waiting Until the Search Ends: `Start` and `WaitFor`, `GrepAll`

There are two ways to wait for the results.

### 5.1 `Start` and `WaitFor`

```pascal
CGrepFile1.Root := 'C:\app';
CGrepFile1.FileMask := '*.pas';
CGrepFile1.Pattern := 'TODO';
if CGrepFile1.Start then
  CGrepFile1.WaitFor(-1);      // Wait until the search ends (-1 means no time limit)
// When execution reaches here, all of OnFound and OnFinished have been called
```

- `Start` makes a separate thread start searching. The lines found are delivered in the main thread as `OnFound`.
- While it waits, `WaitFor` processes the work of the main thread (such as calling `OnFound`). That is why `OnFound` is called inside `WaitFor`. The screen does not freeze either.
- `OnFound` is not "one item at a time, immediately, each time one is found". The lines found are handed over in batches, every 50 items or 0.1 second, whichever comes first, and then called one by one in succession. Delivery can be delayed by up to about 0.1 second after an item is found.
- When `Start` is `False` (no `Root`, `Pattern` is empty, and so on), it is not searching, so `WaitFor` is not needed. Enclose it in an `if` as above.
- To put a limit on the time, pass milliseconds. `WaitFor(5000)` waits 5 seconds and returns `False` if the search has not ended (the search simply continues; use `Stop` to stop it).
- While waiting, other operations of the application also work. Take care that things such as double presses of a button do not happen.

### 5.2 `GrepAll`

```pascal
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    CGrepFile1.Root := 'C:\app';
    CGrepFile1.FileMask := '*.pas';
    CGrepFile1.Pattern := 'TODO';
    CGrepFile1.GrepAll(L);        // Does not return until the search has finished
    Memo1.Lines.Assign(L);        // One line each: "path(line number): text"
  finally
    L.Free;
  end;
end;
```

- `GrepAll` is a synchronous way of searching: it searches in the calling thread and does not return until the search ends. It does not use another thread.

### 5.3 The Difference Between `Start` and `GrepAll`

| | `GrepAll` | `Start` (and `WaitFor`) |
|---|---|---|
| Where it searches | In the calling thread (no other thread is used) | In a separate thread |
| When it returns | When the search has ended | `Start` returns at once. `WaitFor` returns when the search has ended |
| How results are received | The list passed as a parameter (one line each, `path(line number): text`) | `OnFound` (path, line number, and text separately), or a file |
| Events | Not raised (no `OnFound` or `OnFinished`) | Raised |
| The screen during the search | Freezes (the screen does not move while searching) | Keeps moving |
| Stopping with `Stop` | Not possible (because it is in the calling thread) | Possible |
| Return value | The number of lines found | For `Start`, whether it could start |
| Errors | Exceptions (`ECFindPattern`, `EInOutError`) | `OnError` and `False` |
| `OutputMode` | Not used (always goes into the list) | `omEvent` or `omFile` |

**Where each is suitable**
- `GrepAll`: a small search that ends quickly; scripts and tools without a screen; tests.
- `Start`: a large folder; when you want to see partial results while the screen keeps moving; when you want to be able to stop it midway.

The maximum number of results (`MaxResults`, default 10000 lines) applies to both.

## 6. Saving the Results to a File: `SaveResults`

Call `SaveResults` after the search has ended. Calling it inside `OnFinished` is the easiest way to understand.

```pascal
procedure TForm1.CGrepFile1Finished(Sender: TObject; AFiles, AFound: Integer;
  AReason: TCFindStopReason);
begin
  Caption := Format('%d lines found', [AFound]);
  if AFound > 0 then
    CGrepFile1.SaveResults('C:\work\grep_result.txt');   // Save the results to a file
end;
```

After calling `Start`, it can also be used after waiting for the search to end.

```pascal
if CGrepFile1.Start then
  CGrepFile1.WaitFor(-1);
CGrepFile1.SaveResults('C:\work\grep_result.txt');
```

| Item | Contents |
|---|---|
| When to call it | After the search has ended (inside `OnFinished`, or after `WaitFor`). If it is called during a search, only the results so far are written |
| What is written | The results of the last search (kept in memory), up to `MaxResults` (default 10000 lines). They are cleared at the next `Start` |
| Format | The form of 1.2. UTF-8 (without BOM), CRLF. An existing file is overwritten |
| The folder to save to | If it does not exist, it is created automatically (including intermediate folders) |
| `OutputMode` | Can be used only with `omEvent`. With `omFile` it returns `False` (because the results are not in memory; `OnError` also arrives) |
| When there are 0 results | Creates an empty file and returns `True` |
| When it cannot write | `False` (`OnError` also arrives. For example, a file exists where the folder would be created, or the place cannot be written to) |

**Choosing between this and `omFile`**
- When you want to decide whether to save after searching: search with `omEvent` and call `SaveResults`.
- When you want the results in a file from the start (there are very many results, or you want to open the file midway): `omFile`. Lines are appended to the file little by little during the search, so you can open it midway.

## 7. Checking Before Searching: `CheckPattern`

`CheckPattern` checks, before the search starts, whether `Pattern` and `FileMask` can be used. It can find a regular expression that is not valid, an empty `Pattern`, and so on, before searching.

```pascal
var
  Err: string;
begin
  CGrepFile1.Root := Edit1.Text;
  CGrepFile1.MatchMode := gmRegex;
  CGrepFile1.Pattern := Edit2.Text;       // The regular expression the user typed
  if not CGrepFile1.CheckPattern(Err) then
  begin
    ShowMessage(Err);                      // The reason is in it
    Exit;
  end;
  CGrepFile1.Start;
end;
```

| Item | When it cannot be used |
|---|---|
| `Pattern` is empty | `False`. `Err` is "Enter the text to search for" |
| Regular expression (`gmRegex`) | `False` if the expression is not valid. `Err` is the error message of the regular expression |
| `FileMask` | `False` if the wildcard pattern is not valid. `Err` is the error message |

- `Start` also makes the same check before starting. If it is not valid, it raises `OnError` and returns `False`. So it works even if you do not call `CheckPattern`.
- Call `CheckPattern` first when you want to show a message at once on your own screen (such as a label under the input field) before the search starts.
- `GrepAll` raises an exception (`ECFindPattern`) if the expression is not valid. If you do not want an exception, check with `CheckPattern` first.

```pascal
if CGrepFile1.CheckPattern(Err) then
  CGrepFile1.GrepAll(Memo1.Lines)
else
  ShowMessage(Err);
```

## 8. Events

All are called in the main thread (you may touch the screen inside `OnFound`).

| Name | Parameters | Contents |
|---|---|---|
| `OnFound` | `Sender: TObject; const APath: string; ALine: Integer; const AText: string` | When one line is found (only with `omEvent`). `APath`: the full path of the file, `ALine`: the line number (from 1), `AText`: the text of the line (cut and followed by `...` if over 1000 bytes) |
| `OnProgress` | `Sender: TObject; const AFile: string; AFiles: Integer; AFound: Integer` | Every 0.2 second while searching. The file being read, the number of files examined, and the number of lines found |
| `OnFinished` | `Sender: TObject; AFiles: Integer; AFound: Integer; AReason: TCFindStopReason` | When the search ended (after all `OnFound` calls; with `omFile`, after the file is closed). `AFiles`: the number of files examined, `AFound`: the number of lines found. You may call `SaveResults` or `Start` again from inside it |
| `OnError` | `Sender: TObject; const AMessage: string` | When `Start` could not begin; when, with `omFile`, writing became impossible during the search (the search is stopped and `OnFinished` arrives with `frError`); when `SaveResults` could not save |

## 9. Tag Jump: From a Result Line to That Line

TCMonacoEditor and TCsEditor have `TagJump`. When you pass one result line ("path(line number): text"), it opens that file and jumps to that line. `TCGrepFile` never calls an editor. The application calls `TagJump` from any key, menu, or button it likes.

```pascal
// Pass one result line and jump
MonacoEditor1.TagJump('C:\app\a.pas(123): begin');

// Open the result file (written with SaveResults) in the editor and jump using the text of the cursor line
MonacoEditor1.OpenFile('C:\work\grep_result.txt');
// (after placing the cursor on a result line)
MonacoEditor1.TagJump;
```

- Details are in the method tables of `TCMonacoEditor_Usage.md` and `TCsEditor_Usage.md`.
- Only full paths are accepted (a relative path gives `False`).

## 10. Notes

- Windows only.
- The order of the results is the order in which the folders were walked, not name order. If you want them sorted, sort them after receiving them.
- Results are limited to `MaxResults` lines (default 10000). A search that exceeds it ends with `frLimit`.
- A file is read into memory entirely before it is searched. When searching large files, pay attention to `MaxFileSize`.
- Network drives can take time to read. `Stop` can stop them.
- When the form is closed (the component is destroyed) during a search, the search is stopped and the component waits for the thread to end.
- While searching with `omFile`, if another application has `OutputFile` open, it may not be possible to write to it.

## 11. Usage Examples

### 11.1 Search for `TODO` and Show the Results in a List

```pascal
procedure TForm1.Button1Click(Sender: TObject);
begin
  ListBox1.Items.Clear;
  CGrepFile1.Root := 'C:\app';
  CGrepFile1.FileMask := '*.pas;*.lfm';
  CGrepFile1.Pattern := 'TODO';
  CGrepFile1.Start;
end;

procedure TForm1.CGrepFile1Found(Sender: TObject; const APath: string; ALine: Integer; const AText: string);
begin
  ListBox1.Items.Add(CGrepFormatLine(APath, ALine, AText));
end;
```

### 11.2 Put the Results in a File from the Start

```pascal
CGrepFile1.OutputMode := omFile;
CGrepFile1.OutputFile := 'C:\work\grep_result.txt';
CGrepFile1.Pattern := 'TODO';
CGrepFile1.Start;
```

### 11.3 Create It in Code

```pascal
uses uCGrepFile, uCFindFile;

var
  G: TCGrepFile;
begin
  G := TCGrepFile.Create(Self);
  G.Root := 'C:\app';
  G.FileMask := '*.pas';
  G.MatchMode := gmRegex;
  G.Pattern := '^\s*procedure\s+T\w+\.Execute';
  G.OnFound := @MyFound;
  G.OnFinished := @MyFinished;
  G.Start;
end;
```
