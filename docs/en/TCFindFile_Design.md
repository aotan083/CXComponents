# TCFindFile Design Document

Author: aotan083
Date: 2026-11-17
Version: 1.0

---

**Operating environment**: Lazarus 5.0 or later (FPC 3.2.2). Lazarus 4.8 and earlier are not supported.

## 1. Purpose and Policy

- A component (`TCFindFile`) that searches for files and folders by name. A `TComponent` without a screen of its own. It can be used on its own.
- `TCSearchBox` (`TCSearchBox_Design.md`) uses this component to search. The unit is separate (`uCFindFile.pas`).
- The only search method is its own walk (going through the folders one by one with `FindFirstFileW`). The Windows search index is not used.
- File names can be searched by contains, wildcard, or regular expression.
- The search runs in a separate thread. Results are handed to the main thread in batches.
- Not included: searching the contents of files, narrowing by date, size, or type, and Linux / macOS (Windows 11 only).

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCFindFile.pas` | cx (run time) | `TCFindFile`, `TCFindMatcher` (name matching) |
| `uCXReg.pas` (`source\design`), `cnavigation_icon.lrs` | cxdsgn (design time) | Registration in the [CX] palette and the icon (it appears in the component area below the form) |

- uses of `uCFindFile`: `Classes, SysUtils, SyncObjs, Windows, Masks, LazUTF8, RegExpr, uCXLang` (for messages). `Masks` and `LazUTF8` are units of LazUtils (UTF-8 aware wildcards). No other CX units are used.
- `RegExpr` is a standard FPC unit (no additional package is needed).
- No initialization or finalization.
- The packages remain two: cx and cxdsgn.

## 3. TCFindFile

`TCFindFile = class(TComponent)`. It has no screen of its own.

### 3.1 Types and Constants

```pascal
type
  TCFindMatchMode = (fmContains, fmWildcard, fmRegex);      { contains / wildcard (* ?, several separated by ;) / regular expression }
  TCFindStopReason = (frDone, frStopped, frLimit, frError); { walked through everything / stopped with Stop / reached MaxResults / error }

  TCFindFoundEvent = procedure(Sender: TObject; const APath: string; AIsDir: Boolean) of object;
  TCFindProgressEvent = procedure(Sender: TObject; const AFolder: string; AScanned: Int64; AFound: Integer) of object;
  TCFindFinishedEvent = procedure(Sender: TObject; AFound: Integer; AReason: TCFindStopReason) of object;
  TCFindErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;

  ECFindPattern = class(Exception);                          { the regular expression is not valid }
```

| Constant | Value | Contents |
|---|---|---|
| `cFindFlushCount` | 50 | The number of found items after which they are handed to the main thread |
| `cFindFlushMs` | 100 | The same, as time (milliseconds). Whichever of the count and the time comes first |
| `cFindProgressMs` | 200 | The interval of `OnProgress` |
| `cFindMaxDef` | 10000 | The default value of `MaxResults` |

### 3.2 Properties

| Name | Type | Default | Exposure | Contents |
|---|---|---|---|---|
| `Root` | `string` | '' | published | The folder to start searching from |
| `Pattern` | `string` | '' | published | The name to search for (its meaning changes with `MatchMode`; 3.5) |
| `MatchMode` | `TCFindMatchMode` | `fmContains` | published | The matching method |
| `CaseSensitive` | `Boolean` | `False` | published | Whether upper and lower case are distinguished |
| `IncludeSubfolders` | `Boolean` | `True` | published | Whether to search subfolders too |
| `IncludeFiles` | `Boolean` | `True` | published | Whether files are results |
| `IncludeFolders` | `Boolean` | `True` | published | Whether folders are also results (matched by folder name) |
| `SearchHidden` | `Boolean` | `False` | published | Whether to search hidden and system items too |
| `MaxResults` | `Integer` | 10000 | published | The maximum number of results. 0 means no limit. A value below 0 becomes 0 |
| `Active` | `Boolean` | - | public (read) | Whether a search is running |
| `FoundCount` | `Integer` | - | public (read) | The number found so far |
| `ScannedCount` | `Int64` | - | public (read) | The number of items examined so far |

- While a search is running (`Active`), changing the settings does not affect that search (the settings are copied and handed over at `Start`).

### 3.3 Methods

| Method | Contents |
|---|---|
| `function Start: Boolean` | Starts searching in a separate thread. `False` if already searching. If `Root` is not a folder, `Pattern` is empty, or the regular expression is not valid, it raises `OnError` and returns `False` (does not search) |
| `procedure Stop` | Stops. It does not wait for the thread to end (`OnFinished` arrives with `frStopped`) |
| `function WaitFor(ATimeoutMs: Integer): Boolean` | Waits, processing messages, until the search ends (`OnFinished` arrives). `True` if it ended in time. For checking and scripts |
| `function FindAll(AResult: TStrings): Integer` | Searches in the calling thread and puts full paths into `AResult`. Raises no events. Returns the number found. Errors are exceptions (`ECFindPattern`, `EInOutError`). For checking and scripts |
| `function CheckPattern(out AError: string): Boolean` | Whether `Pattern` can be used (not empty, and for a regular expression, whether it can be built). If it cannot be used, a message goes into `AError` |

### 3.4 Events

All are called in the main thread.

| Event | When |
|---|---|
| `OnFound(Sender, APath, AIsDir)` | When an item is found. The thread hands items over in batches every `cFindFlushCount` items or `cFindFlushMs`, and each time this handler is called in succession for every item in the batch |
| `OnProgress(Sender, AFolder, AScanned, AFound)` | While searching, every `cFindProgressMs`. The folder being walked |
| `OnFinished(Sender, AFound, AReason)` | When finished (after all `OnFound` calls) |
| `OnError(Sender, AMessage)` | When `Start` could not begin (3.3) |

### 3.5 Name Matching (`TCFindMatcher`)

One is created per thread (because `TRegExpr` cannot be used across threads).

```pascal
TCFindMatcher = class
public
  constructor Create(AMode: TCFindMatchMode; const APattern: string; ACaseSensitive: Boolean);  { ECFindPattern if not valid }
  function Match(const AName: string): Boolean;
end;
```

| `MatchMode` | Matching |
|---|---|
| `fmContains` | Whether the name contains `Pattern`. When case is not distinguished, both are made `UTF8LowerCase` and `Pos` is used |
| `fmWildcard` | `TMaskList.Create(Pattern, ';', CaseSensitive).Matches(name)` (`Masks` of LazUtils; UTF-8 aware). `*` `?`. Several separated by `;` (`*.pas;*.lfm`). If the pattern is not valid, `ECFindPattern` from `Create` |
| `fmRegex` | `TRegExpr`. `Expression := Pattern`, `ModifierI := not CaseSensitive`. `Exec(name)` (true if it matches anywhere in the name; to match the whole name, write `^...$`). If the expression is not valid, `ECFindPattern` from `Create` (the message is `TRegExpr.ErrorMsg`) |

- Matching is done only against the file name (folder name); the names of folders in the middle of the path are not checked.
- Names and expressions are handled as UTF-8. Therefore `.` and `[ ]` in a regular expression work on bytes (an expression that specifies a number of Japanese characters does not behave as expected; expressions such as `\.(pas|lfm)$` and `^test` work). This limit is written in the manual.
- Spaces at the start and end are compared as they are in `Pattern` (`TCSearchBox` removes them before handing it over).

### 3.6 Internal Parts (Declarations in the Implementation)

```pascal
TCFindWorker = class            { the body of the search; used from the thread and from the synchronous FindAll }
  Root, Pattern: string;  Mode: TCFindMatchMode;
  CaseSensitive, IncludeSubfolders, IncludeFiles, IncludeFolders, SearchHidden: Boolean;
  MaxResults: Integer;
  OnItem: procedure(const APath: string; AIsDir: Boolean) of object;   { each time one item is found }
  OnFolder: procedure(const AFolder: string) of object;                { each time the folder being examined changes }
  StopFlag: Boolean;                                                   { the stop flag; set to True from another thread }
  Found: Integer;  Scanned: Int64;
  function Run: TCFindStopReason;                                      { walk; ECFindPattern if the expression is not valid }
end;

TCFindThread = class(TThread)    { the search thread; results are collected on the thread side and handed to the main thread in batches }
  procedure RequestStop;         { sets StopFlag }
  procedure Detach;              { call before destroying; from then on nothing is handed to the owner }
end;

TCFindFile = class(TComponent)
private
  FThread: TCFindThread;         { the thread that is searching; nil when finished }
  FFoundCount: Integer;  FScannedCount: Int64;
  FDestroying: Boolean;
  procedure DeliverItems(AItems: TStrings);        { calls OnFound in the main thread (first character: D folder, F file) }
  procedure DeliverProgress(...);                  { OnProgress }
  procedure DeliverFinished(AThread, AFound, AScanned, AReason);   { cleans up the thread, then OnFinished }
  ...
end;
```

- `TCFindMatcher`, `TCFindWorker`, and `TCFindThread` are in the public part of `uCFindFile` (they can be used directly for checking). Normally only `TCFindFile` is used.

## 4. Processing

### 4.1 How the Walk Is Done (Thread `TCFindThread`; a Class in the Implementation)

1. At `Start`, the settings (`Root`, `Pattern`, `MatchMode`, ...) are copied to `TCFindWorker` and handed to the thread. `TCFindMatcher` is created inside `Run` (inside the thread) (`ECFindPattern` if it is not valid; the thread ends with `frError`. However, `CheckPattern` of `Start` checks it first, so this normally does not happen).
2. `Root` is put onto a stack of folders. One is taken out at a time and its contents are examined until the stack is empty (a stack is used, not recursion).
3. Examining one folder: items are taken in turn with `FindFirstFileW(long path(folder + '\*'))`.
   - `.` and `..` are skipped.
   - When `SearchHidden` is false, hidden (`FILE_ATTRIBUTE_HIDDEN`) and system (`FILE_ATTRIBUTE_SYSTEM`) items are not made results, and if they are folders, they are not entered.
   - Folder: if `IncludeFolders`, the name is checked with `TCFindMatcher.Match`; a match is a result. If `IncludeSubfolders` and it is not a reparse point (`FILE_ATTRIBUTE_REPARSE_POINT`; junctions and symbolic links), it is put on the stack. Reparse points are not entered (to avoid walking endlessly).
   - File: if `IncludeFiles`, the name is checked with `Match`; a match is a result.
   - For every item examined, `ScannedCount` increases by 1.
4. Results are collected in the thread's buffer (`TStringList`; full paths; folders are distinguished by a separate mark, without adding a trailing `\`). Every `cFindFlushCount` items or `cFindFlushMs`, they are handed to the main thread with `Queue` (`DoDeliverItems` of the thread, which calls `DeliverItems` of the owner).
5. Every `cFindProgressMs`, `DoDeliverProgress` with `Queue`.
6. For every item, `StopFlag` (set by `Stop`) is checked. If true, the buffer is handed over and the search ends with `frStopped`. `TThread.Terminate` is not used as the stop flag because, if `Terminate` is called before the thread starts running, `Execute` is not called and the notification of the end never arrives.
7. When the number of results reaches `MaxResults` (if not 0), the buffer is handed over and the search ends with `frLimit`.
8. Folders that cannot be read (access denied, etc.) are skipped silently (not an error).
9. When the stack is empty, the buffer is handed over and the search ends with `frDone`. `OnFinished` is queued last (after all `OnFound` calls).
10. Long paths are supported (when longer than 260 characters, `\\?\` is added in front; for `\\server\share`, `\\?\UNC\server\share`). Result paths are returned in the form without it.

### 4.2 `Start`, `Stop`, `Destroy`

| Procedure | Processing |
|---|---|
| `Start` | `False` if `FThread` exists. Check `CheckPattern` and `Root` (`DirectoryExists`). If not valid, `OnError` and `False`. `FFoundCount := 0`, `FScannedCount := 0`. Create the thread and start it (`FreeOnTerminate := False`). `True` |
| `Stop` | If `FThread` exists, `RequestStop` (sets `StopFlag`) |
| `Destroy` | `FDestroying := True`. If `FThread` exists, `Detach` (nothing is handed to the owner any more; sets `StopFlag`), `WaitFor`, discard what remains in `Queue` with `TThread.RemoveQueuedEvents(thread)`, and `Free` |
| `DeliverFinished` | `FThread := nil`; `Detach`, `WaitFor`, `Free` the thread. Then `OnFinished` (`Start` can be called again from inside `OnFinished`) |

### 4.3 Strings (Added to `uCXLang`)

| ID | Japanese | English |
|---|---|---|
| `sFfErrEmpty` | 検索する名前を入力してください | Enter a name to search for |
| `sSbErrNoRoot` | 検索を始めるフォルダーがありません：%s | The folder to start from was not found: %s |

`sSbErrNoRoot` is the same string as in Chapter 5 of `TCSearchBox_Design.md` (only one is added). The message when `CheckPattern` finds the pattern empty is `sFfErrEmpty`; the message when a regular expression or wildcard is not valid is the error message of `TRegExpr` or `TMaskList`.

## 5. Decisions

| Item | Decision |
|---|---|
| Search method | Only its own walk (`FindFirstFileW`). The index is not used |
| Name matching | Contains, wildcard, regular expression. Only file names (folder names) are checked |
| Regular expression | FPC `RegExpr`. UTF-8 as it is. `.` works on bytes (specifying a number of Japanese characters is not possible) |
| Thread | The search runs in a separate thread. Results go to the main thread in batches (50 items or 100 ms) |
| Not walking endlessly | Reparse points are not entered. `MaxResults` (default 10000) |
| Folders that cannot be read | Skipped silently |
| Design time | Appears in the component area below the form. The search is not run |

## 6. Where to Look When Investigating Problems

| Symptom | Where to look |
|---|---|
| `Start` is `False` | The message of `OnError`. `Root`, `Pattern`, the regular expression (`CheckPattern`) |
| No results at all | `MatchMode` (is it contains?). `SearchHidden`. Read permission of `Root` |
| Results appear late / it freezes | `cFindFlushCount`, `cFindFlushMs` |
| A regular expression with Japanese does not match | That `.` works on bytes (3.5) |
| It does not stop although searching | Check of `StopFlag` (6 of 4.1). `OnFinished` after `Stop` |
| The thread remains even after the form is closed | `WaitFor` in `TCFindFile.Destroy` (4.2) |

## 7. Changes in This Version (1.0; New)

| File | Change |
|---|---|
| `source/uCFindFile.pas` | New |
| `source/design/uCXReg.pas`, `source/res/cnavigation_icon.lrs` | Registration and icon |
| `packages/cx.lpk`, `cx.pas`, `cxdsgn.lpk` | Add `uCFindFile` |
| `docs/TCFindFile_Usage.md`, `TCFindFile_Design.md`, and the same names in `docs/en` | The manual and the English version are made after the code is complete |
