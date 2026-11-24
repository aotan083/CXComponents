# TCFindFile User Manual

Author: aotan083
Date: 2026-11-17
Version: 1.1

---

**Operating environment**: Lazarus 5.0 or later (FPC 3.2.2). Lazarus 4.8 and earlier are not supported.

## 1. Overview and Classes

A component that searches a folder for files and folders by name. It has no screen of its own (when placed on a form, it appears in the component area below the form).

- Three ways to match names: contains, wildcard (`*` `?`, several patterns separated by `;`), and regular expression.
- The search runs in a separate thread, so the screen does not freeze while it searches. Found items are delivered to `OnFound` little by little, in batches (every 50 items or 0.1 second).
- It can search the contents of subfolders. It does not enter junctions or symbolic links. Folders that cannot be read are skipped silently.
- It does not use the Windows search index. It walks through the folders one by one.
- The search box component TCSearchBox (`TCSearchBox_Usage.md`) uses this component. It can also be used on its own.

| Item | Contents |
|---|---|
| Lazarus | 5.0RC1 or later |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Classes and Units

| Class | Unit | Package | Parent class | Contents |
|---|---|---|---|---|
| `TCFindFile` | `uCFindFile` | cx | `TComponent` | Searches files and folders by name |
| `TCFindMatcher` | `uCFindFile` | cx | `TObject` | Checks whether a name matches (1.2). Used by `TCFindFile`. Can also be used on its own |
| `ECFindPattern` | `uCFindFile` | cx | `Exception` | The exception raised when a regular expression or wildcard pattern is not valid |

| Type | Unit | Contents |
|---|---|---|
| `TCFindMatchMode` | `uCFindFile` | `fmContains` (contains), `fmWildcard` (wildcard), `fmRegex` (regular expression) |
| `TCFindStopReason` | `uCFindFile` | The reason the search ended. `frDone`: walked through everything, `frStopped`: stopped with `Stop`, `frLimit`: reached `MaxResults`, `frError`: error |
| `TCFindFoundEvent` | `uCFindFile` | `procedure(Sender: TObject; const APath: string; AIsDir: Boolean) of object` |
| `TCFindProgressEvent` | `uCFindFile` | `procedure(Sender: TObject; const AFolder: string; AScanned: Int64; AFound: Integer) of object` |
| `TCFindFinishedEvent` | `uCFindFile` | `procedure(Sender: TObject; AFound: Integer; AReason: TCFindStopReason) of object` |
| `TCFindErrorEvent` | `uCFindFile` | `procedure(Sender: TObject; const AMessage: string) of object` |

- When placed on a form, `uCFindFile` is added to uses automatically, and cx is added to the project's required packages automatically.
- When creating it in code, write it in uses yourself.

### 1.2 How Names Are Matched

Matching is done only against the file name or folder name (the names of folders in the middle of the path are not checked).

| `MatchMode` | How to write `Pattern` | Example |
|---|---|---|
| `fmContains` (default) | Characters contained in the name | `pas`: `a.pas`, `Pascal.txt` |
| `fmWildcard` | `*`: any string, `?`: one character. Separate several patterns with `;` | `*.pas;*.lfm` |
| `fmRegex` | A regular expression (FPC `RegExpr`). It is enough to match anywhere in the name. To match the whole name, write `^` and `$` | `\.(pas|lfm)$`, `^test` |

- Upper and lower case are not distinguished when `CaseSensitive` is `False` (default).
- Names are matched as UTF-8. In a regular expression, `.` and `[ ]` work on bytes (an expression that specifies a number of Japanese characters does not behave as expected). Expressions such as `\.(pas|lfm)$` and `^test` work.
- Spaces at the start and end of `Pattern` are compared as they are.

## 2. From Placing on a Form to Running

1. Place TCFindFile on the form from the [CX] palette.
2. Set `Root` (the folder to start searching from) and `Pattern` (the name to search for) in the Object Inspector or in code.
3. Double-click `OnFound` on the Events tab and write the code that uses the found items.
4. Call `Start` in code.

## 3. Properties

| Name | Type | Access | Contents |
|---|---|---|---|
| `Root` | `string` | Read/Write | The folder to start searching from |
| `Pattern` | `string` | Read/Write | The name to search for (how to write it depends on `MatchMode`; 1.2) |
| `MatchMode` | `TCFindMatchMode` | Read/Write | The matching method (default `fmContains`) |
| `CaseSensitive` | `Boolean` | Read/Write | Whether upper and lower case are distinguished (default `False`) |
| `IncludeSubfolders` | `Boolean` | Read/Write | Whether to search inside subfolders (default `True`) |
| `IncludeFiles` | `Boolean` | Read/Write | Whether files are results (default `True`) |
| `IncludeFolders` | `Boolean` | Read/Write | Whether folders are also results (default `True`; matched by folder name) |
| `SearchHidden` | `Boolean` | Read/Write | Whether to search hidden and system items too (default `False`; hidden folders are not entered either) |
| `MaxResults` | `Integer` | Read/Write | The maximum number of results (default 10000). 0 means no limit. A value below 0 becomes 0. The search stops when it is reached |
| `Active` | `Boolean` | Read | `True` while searching. Run time only |
| `FoundCount` | `Integer` | Read | The number found so far. Run time only |
| `ScannedCount` | `Int64` | Read | The number of items examined so far. Run time only |

- Changing settings while a search is running does not affect that search (it searches with the settings at the time of `Start`).

## 4. Methods

| Name | Parameters | Return value | Contents |
|---|---|---|---|
| `Start` | - | `Boolean` | Starts searching in a separate thread. Returns `False` (without searching) after raising `OnError` if it is already searching, `Root` is not a folder, `Pattern` is empty, or the regular expression / wildcard pattern is not valid |
| `Stop` | - | - | Stops the search. It does not wait for it to stop (`OnFinished` arrives with `frStopped`) |
| `WaitFor` | `ATimeoutMs: Integer` | `Boolean` | Waits, processing messages, until the search ends (`OnFinished` arrives). Returns `True` if it ended in time. `-1` means no time limit |
| `FindAll` | `AResult: TStrings` | `Integer` | Searches in the calling thread and puts full paths into `AResult` (cleared first). Returns the number found. Raises no events. Raises `EInOutError` if `Root` is not a folder and `ECFindPattern` if the pattern is not valid. Use it for short searches and scripts |
| `CheckPattern` | `out AError: string` | `Boolean` | Whether `Pattern` can be used (not empty, and for a regular expression or wildcard, whether it can be built). If it cannot be used, the reason is put into `AError` |

## 5. Waiting Until the Search Ends: `Start` and `WaitFor`, `FindAll`

There are two ways to wait for the results.

### 5.1 `Start` and `WaitFor`

```pascal
CFindFile1.Root := 'C:\app';
CFindFile1.MatchMode := fmWildcard;
CFindFile1.Pattern := '*.pas';
if CFindFile1.Start then
  CFindFile1.WaitFor(-1);      // Wait until the search ends (-1 means no time limit)
// When execution reaches here, all of OnFound and OnFinished have been called
```

- `Start` makes a separate thread start searching. The items found are delivered in the main thread as `OnFound`.
- While it waits, `WaitFor` processes the work of the main thread (such as calling `OnFound`). That is why `OnFound` is called inside `WaitFor`. The screen does not freeze either.
- `OnFound` is not "one item at a time, immediately, each time one is found". The items found are handed over in batches, every 50 items or 0.1 second, whichever comes first, and then called one by one in succession. Delivery can be delayed by up to about 0.1 second after an item is found.
- When `Start` is `False` (no `Root`, `Pattern` is empty, and so on), it is not searching, so `WaitFor` is not needed. Enclose it in an `if` as above.
- To put a limit on the time, pass milliseconds. `WaitFor(5000)` waits 5 seconds and returns `False` if the search has not ended (the search simply continues; use `Stop` to stop it).
- While waiting, other operations of the application also work. Take care that things such as double presses of a button do not happen.

### 5.2 `FindAll`

```pascal
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    CFindFile1.Root := 'C:\app';
    CFindFile1.MatchMode := fmWildcard;
    CFindFile1.Pattern := '*.pas';
    CFindFile1.FindAll(L);        // Does not return until the search has finished
    Memo1.Lines.Assign(L);        // The full paths of what was found
  finally
    L.Free;
  end;
end;
```

- `FindAll` is a synchronous way of searching: it searches in the calling thread and does not return until the search ends. It does not use another thread.

### 5.3 The Difference Between `Start` and `FindAll`

| | `FindAll` | `Start` (and `WaitFor`) |
|---|---|---|
| Where it searches | In the calling thread (no other thread is used) | In a separate thread |
| When it returns | When the search has ended | `Start` returns at once. `WaitFor` returns when the search has ended |
| How results are received | The list passed as a parameter (full paths) | `OnFound` (the full path, and whether it is a folder) |
| Events | Not raised (no `OnFound` or `OnFinished`) | Raised |
| The screen during the search | Freezes (the screen does not move while searching) | Keeps moving |
| Stopping with `Stop` | Not possible (because it is in the calling thread) | Possible |
| Return value | The number found | For `Start`, whether it could start |
| Errors | Exceptions (`ECFindPattern`, `EInOutError`) | `OnError` and `False` |

**Where each is suitable**
- `FindAll`: a small search that ends quickly; scripts and tools without a screen; tests.
- `Start`: a large folder; when you want to see partial results while the screen keeps moving; when you want to be able to stop it midway.

The maximum number of results (`MaxResults`, default 10000) applies to both.

## 6. Checking Before Searching: `CheckPattern`

`CheckPattern` checks, before the search starts, whether `Pattern` can be used. It can find a regular expression that is not valid, an empty `Pattern`, and so on, before searching.

```pascal
var
  Err: string;
begin
  CFindFile1.Root := Edit1.Text;
  CFindFile1.MatchMode := fmRegex;
  CFindFile1.Pattern := Edit2.Text;       // The regular expression the user typed
  if not CFindFile1.CheckPattern(Err) then
  begin
    ShowMessage(Err);                      // The reason is in it
    Exit;
  end;
  CFindFile1.Start;
end;
```

| Item | When it cannot be used |
|---|---|
| `Pattern` is empty | `False`. `Err` is "Enter a name to search for" |
| Regular expression (`fmRegex`), wildcard (`fmWildcard`) | `False` if the pattern is not valid. `Err` is the error message |

- `Start` also makes the same check before starting. If it is not valid, it raises `OnError` and returns `False`. So it works even if you do not call `CheckPattern`.
- Call `CheckPattern` first when you want to show a message at once on your own screen (such as a label under the input field) before the search starts.
- `FindAll` raises an exception (`ECFindPattern`) if the pattern is not valid. If you do not want an exception, check with `CheckPattern` first.

```pascal
if CFindFile1.CheckPattern(Err) then
  CFindFile1.FindAll(Memo1.Lines)
else
  ShowMessage(Err);
```

## 7. Events

All of them are called in the main thread (you may touch the screen inside `OnFound`).

| Name | Parameters | Contents |
|---|---|---|
| `OnFound` | `Sender: TObject; const APath: string; AIsDir: Boolean` | When an item is found. `APath` is the full path; `AIsDir` is `True` for a folder. They arrive in batches but are called one by one |
| `OnProgress` | `Sender: TObject; const AFolder: string; AScanned: Int64; AFound: Integer` | Every 0.2 second while searching. The folder being walked, the number examined, and the number found |
| `OnFinished` | `Sender: TObject; AFound: Integer; AReason: TCFindStopReason` | When the search ended (after all `OnFound` calls). You may call `Start` again from inside it |
| `OnError` | `Sender: TObject; const AMessage: string` | When `Start` could not begin |

## 8. Notes

- Windows only.
- The order of the result paths is the order in which the folders were walked, not name order. If you want them sorted, sort them after receiving them.
- Paths longer than 260 characters can also be searched (handled in the `\\?\` form). Result paths arrive without `\\?\`.
- Network drives can take time to read. `Stop` can stop them.
- When the form is closed (the component is destroyed) during a search, the search is stopped and the component waits for the thread to end.

## 9. Usage Examples

### 9.1 Search for `*.pas` and Put the Results in a List

```pascal
procedure TForm1.FindPas(const AFolder: string);
begin
  CFindFile1.Root := AFolder;
  CFindFile1.MatchMode := fmWildcard;
  CFindFile1.Pattern := '*.pas';
  CFindFile1.Start;
end;

procedure TForm1.CFindFile1Found(Sender: TObject; const APath: string; AIsDir: Boolean);
begin
  ListBox1.Items.Add(APath);
end;

procedure TForm1.CFindFile1Finished(Sender: TObject; AFound: Integer; AReason: TCFindStopReason);
begin
  Caption := Format('%d items', [AFound]);
end;
```

### 9.2 Receive the Results at Once (a Short Search)

```pascal
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    CFindFile1.Root := 'C:\app';
    CFindFile1.Pattern := 'readme';
    CFindFile1.FindAll(L);      // Does not return until the search has finished
    Memo1.Lines.Assign(L);
  finally
    L.Free;
  end;
end;
```

### 9.3 Create It in Code

```pascal
uses uCFindFile;

var
  F: TCFindFile;
begin
  F := TCFindFile.Create(Self);
  F.Root := 'C:\app';
  F.MatchMode := fmRegex;
  F.Pattern := '\.(pas|lfm)$';
  F.OnFound := @MyFound;
  F.Start;
end;
```
