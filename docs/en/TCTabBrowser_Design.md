# TCTabBrowser Design Document

Author: aotan083
Date: 2026-10-29
Version: 1.0

---

## 1. Purpose

Based on TPageControl, build a tabbed Web browser using WebView2 (`TWVBrowser` and `TWVWindowParent` from WebView4Delphi).

- 1 tab = one `TTabSheet` + one `TWVWindowParent` + one `TWVBrowser`. All three are owned (Owner) by the `TTabSheet`, so calling `Free` on a tab removes them together.
- The number of tabs never becomes 0. When the last tab is closed, the component creates a new tab.
- A new window that a page tries to open is always blocked and opened in a new tab instead.
- All tabs use a dedicated data folder (EXE\TabBrowserData). A different data folder means a separate browser process, so this browser does not stall even while TCMonacoEditor or similar is blocked processing key input.
- WebView2 preparation (`GlobalWebView2Loader`) is done by `CXStartWebView2` (chapter 9) when the first tab is created. The unit has no initialization or finalization.
- Waiting methods (`NavigateAndWait`, `RunScript`, saving) wait using `Application.ProcessMessages`. To avoid crashing if a tab disappears while waiting, they watch it with `FreeNotification` (7.3).

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCTabBrowser.pas` | cx (runtime) | `TCTabBrowser`, `TCTabPanel`, and 3 internal classes (chapter 3) |
| `uCXRuntime.pas` | cx (runtime) | Function that reads WebView2.ini and `CXStartWebView2` (chapter 9). Shared with TCMonacoEditor |
| `uCXReg.pas` | cxdsgn (design time) | Registration on the [CX] palette (`RegisterComponents('CX', [..., TCTabBrowser, ...])`) |
| `cx_icons.lrs` | cxdsgn (design time) | Icons (`TCTabBrowser`, `TCTabBrowser_150`, `TCTabBrowser_200`) |

- `uCTabBrowser` uses: `Classes, SysUtils, Controls, ComCtrls, Forms, Windows, ActiveX, Menus, Contnrs, uWVBrowser, uWVWindowParent, uWVBrowserBase, uWVLoader, uWVTypeLibrary, uWVEvents, uWVTypes, uWVCoreWebView2Args, uWVCoreWebView2DownloadOperation, uWVCoreWebView2ContextMenuItem, uWVCoreWebView2ContextMenuItemCollection, fpjson, jsonparser`
- implementation uses: `uCXRuntime`.
- Required packages for cx: `LCL`, the Lazarus package of WebView4Delphi.
- `{$MODE Delphi}` (no `@` is needed when assigning events).

## 3. Types

```pascal
TTabDocumentCompleteEvent = procedure(Sender: TObject; ATabIndex: Integer; ASuccess: Boolean) of object;
TTabNewWindowRequestedEvent = procedure(Sender: TObject; ATabIndex: Integer; var AURI: string; var AAccept: Boolean) of object;
TTabBasicAuthenticationRequestedEvent = procedure(Sender: TObject; ATabIndex: Integer; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2BasicAuthenticationRequestedEventArgs) of object;
TTabDownloadStartingEvent = procedure(Sender: TObject; ATabIndex: Integer; const AURI: string; var AFileName: string; var ACancel: Boolean) of object;
TTabDownloadCompletedEvent = procedure(Sender: TObject; ATabIndex: Integer; const AFileName: string; ASuccess: Boolean) of object;
TTabScriptResultEvent = procedure(Sender: TObject; AID: Integer; ASuccess: Boolean; const AResultJson: string) of object;
TTabNewTabReason = (ntrMenuNew, ntrLastTabClosed);
TTabNewTabRequestEvent = procedure(Sender: TObject; AReason: TTabNewTabReason; var AURL: string; var AAccept: Boolean) of object;

// Internal: what to do when selected from the page-area menu
TCTabPageMenuAction = (pmaNone, pmaNew, pmaClose, pmaApp);

// Internal: one item added to the page area
TCTabPageMenuItem = class
public
  Item: TCoreWebView2ContextMenuItem;  // Wrapper for the WebView2 item (holds the selection-notification registration)
  CommandId: Integer;                  // Number assigned by WebView2
  Action: TCTabPageMenuAction;
  Source: TMenuItem;                   // Original item when pmaApp (reference only)
  Browser: TWVBrowser;                 // Browser of the tab that was right-clicked
  destructor Destroy; override;        // FreeAndNil(Item) (the selection-notification registration is also removed)
end;

// Internal: one pending result of RunScriptAsync
TCTabScriptItem = class
public
  ID: Integer;
  Browser: TWVBrowser;
  Callback: TTabScriptResultEvent;
end;

// Internal: one download being watched
TCTabDownloadItem = class
public
  Operation: TCoreWebView2DownloadOperation;
  Browser: TWVBrowser;
  destructor Destroy; override;        // FreeAndNil(Operation) (registered events are also removed)
end;

// Gateway to tab information. Holds no state of its own, only points to a TWVWindowParent
TCTabPanel = record
private
  FOwner: TCTabBrowser;
  FWindowParent: TWVWindowParent;      // If nil, every value is ''
public
  property Title: string read GetTitle;            // FOwner.GetTitleForWindowParent
  property URL: string read GetURL;                // FOwner.GetURLForWindowParent
  property SourceText: string read GetSourceText;  // FOwner.GetSourceTextForWindowParent
end;
```

## 4. Fields

| Name | Type | Initial value | Contents |
|---|---|---|---|
| `FHideSingleTab` | `Boolean` | `True` | `HideSingleTab` |
| `FUserAgent` | `string` | '' | Value written to `UserAgent` |
| `FIgnoreCertificateErrors` | `Boolean` | `True` | `IgnoreCertificateErrors` |
| `FSavePath` | `string` | `GetCurrentDir` | `SavePath` |
| `FOnDocumentComplete` and 6 others | events | nil | Events of chapter 5 |
| `FWaitCompleted` | `Boolean` | `False` | The awaited operation has finished |
| `FWaitSuccess` | `Boolean` | `False` | The awaited operation succeeded |
| `FWaitAborted` | `Boolean` | `False` | The watched Browser disappeared while waiting |
| `FWaitTargetComponent` | `TComponent` | nil | Browser watched while waiting |
| `FRetrievedHTML` | `wvstring` | '' | Result of `RetrieveHTML` |
| `FRetrievedMHTML` | `wvstring` | '' | Result of `RetrieveMHTML` |
| `FRunScriptResult` | `wvstring` | '' | Result of `RunScript` |
| `FRunScriptID` | `Integer` | 0 | Execution ID that `RunScript` is waiting for (0 = not waiting) |
| `FScripts` | `TObjectList` (owner) | empty | List of `TCTabScriptItem` |
| `FScriptIDGen` | `Integer` | 0 | Execution ID generator |
| `FDownloads` | `TObjectList` (owner) | empty | List of `TCTabDownloadItem` |
| `FDownloadIDGen` | `Integer` | 0 | Download ID generator |
| `FDataFolder` | `string` | EXE folder + `TabBrowserData` | Data folder for all tabs |
| `FCacheSizeMB` | `Integer` | 0 | `cacheSizeMB` in tabbrowser.json (0 = no limit) |
| `FTabPopupMenu` | `TPopupMenu` | Created in Create | Right-click menu of the tab header (assigned to `PopupMenu`) |
| `FCloseMenuItem` | `TMenuItem` | Created in Create | "Close" in the tab header menu |
| `FContextMenuTabIndex` | `Integer` | -1 | Tab right-clicked on the header (used by "Close") |
| `FContextTabIndex` | `Integer` | -1 | `ContextTabIndex` |
| `FHeaderPopupMenu`, `FPagePopupMenu` | `TPopupMenu` | nil | Application items |
| `FOnNewTabRequest` | `TTabNewTabRequestEvent` | nil | Event |
| `FPageMenuItems` | `TObjectList` (owner) | empty | `TCTabPageMenuItem` entries added to the page area |
| `FPendingAction` | `TCTabPageMenuAction` | `pmaNone` | What to do after the menu closes, when selected in the page area |
| `FPendingItem` | `TMenuItem` | nil | Original item at that time |
| `FPendingBrowser` | `TWVBrowser` | nil | Browser of the tab at that time (for comparison only; its contents are not touched) |

## 5. Declarations

```pascal
protected
  procedure Resize; override;      // SynchronizeBounds after inherited
  procedure Change; override;      // SynchronizeBounds and SynchronizeVisibility after inherited
  procedure Notification(AComponent: TComponent; Operation: TOperation); override;
public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  function Add(const AURL: string = 'about:blank'): Integer;
  function Insert(i: Integer; const AURL: string = 'about:blank'): Integer;
  procedure Navigate(const AURL: string);
  function NavigateAndWait(const AURL: string; TimeoutMS: Integer = 60000): Boolean;
  procedure Back;
  procedure Next;
  procedure Reload;
  procedure LoadFromFile(const AFileName: string);
  procedure SaveToFile(sFileName: String);
  procedure SaveAsWebPage(sFileName: String);
  procedure SaveScreenCapture(const AFileName: string = '');
  procedure SavePDF(const AFileName: string = '');
  procedure Remove; overload;
  procedure Remove(i: Integer); overload;
  procedure SynchronizeBounds;
  procedure SynchronizeVisibility;
  function RunScript(const AScript: string; out AResultJson: string; ATimeoutMS: Integer = 30000): Boolean;
  function RunScriptAsync(ATabIndex: Integer; const AScript: string; ACallback: TTabScriptResultEvent): Integer;
  procedure CancelScriptAsync(AID: Integer);
  property Count: Integer read GetCount;                         // PageCount
  property ActiveIndex: Integer read GetActiveIndex write SetActiveIndex;
  property Panels[AIndex: Integer]: TCTabPanel read GetPanel;
  property ActiveTab: TCTabPanel read GetActiveTab;
  property ContextTabIndex: Integer read FContextTabIndex;
published
  property HideSingleTab: Boolean read FHideSingleTab write SetHideSingleTab default True;
  property UserAgent: string read GetUserAgent write SetUserAgent;
  property IgnoreCertificateErrors: Boolean read FIgnoreCertificateErrors write SetIgnoreCertificateErrors default True;
  property OnDocumentComplete: TTabDocumentCompleteEvent read FOnDocumentComplete write FOnDocumentComplete;
  property OnNewWindowRequested: TTabNewWindowRequestedEvent read FOnNewWindowRequested write FOnNewWindowRequested;
  property OnBasicAuthenticationRequested: TTabBasicAuthenticationRequestedEvent read FOnBasicAuthenticationRequested write FOnBasicAuthenticationRequested;
  property SavePath: string read FSavePath write FSavePath;
  property OnDownloadStarting: TTabDownloadStartingEvent read FOnDownloadStarting write FOnDownloadStarting;
  property OnDownloadCompleted: TTabDownloadCompletedEvent read FOnDownloadCompleted write FOnDownloadCompleted;
  property HeaderPopupMenu: TPopupMenu read FHeaderPopupMenu write SetHeaderPopupMenu;
  property PagePopupMenu: TPopupMenu read FPagePopupMenu write SetPagePopupMenu;
  property OnNewTabRequest: TTabNewTabRequestEvent read FOnNewTabRequest write FOnNewTabRequest;
```

- The published properties and events inherited from TPageControl are exposed as they are (User Manual 3.2 and 5.2).

## 6. Create and Destroy

Create:

1. `inherited`. Set the initial values from chapter 4. The 3 `TObjectList`s are created with `OwnsObjects = True`.
2. `FDataFolder := ExtractFilePath(ParamStr(0)) + 'TabBrowserData'`. Unless at design time, `LoadSettings` (7.11).
3. `Options := [nboShowCloseButtons]`, `OnCloseTabClicked := DoCloseTabClicked`.
4. Create `FTabPopupMenu` (owner is Self) and add one "Close" item (`CloseMenuItemClick`). `PopupMenu := FTabPopupMenu`, `OnContextPopup := HandleTabContextPopup`.

- Create does not touch WebView2 (to keep it safe in the IDE).

Destroy:

1. `FreeAndNil(FDownloads)`, `FreeAndNil(FScripts)` (remove the registered events before the tabs' Browsers disappear).
2. `Application.RemoveAsyncCalls(Self)` (cancel the action scheduled to run after the menu closes).
3. `FreeAndNil(FPageMenuItems)`.
4. `inherited` (the tabs and Browsers are removed).

- `GlobalWebView2Loader` is not freed (the finalization of WebView4Delphi's `uWVLoader` frees it).

## 7. Processing

### 7.1 Creating a tab (Add, Insert)

`Add(AURL)` is `Insert(PageCount, AURL)`.

`Insert(i, AURL)`:

1. `if not CXStartWebView2(Err) then raise Exception.Create(Err)` (chapter 9).
2. Clamp `i` to 0 .. `PageCount`.
3. Create a `TTabSheet` (owner is Self), `PageControl := Self`, `PageIndex := i`.
4. Create a `TWVWindowParent` (owner is the tab), `Parent` is the tab, `Align := alClient`.
5. Create a `TWVBrowser` (owner is the tab) and connect the following events.

   | Browser event | Connected to |
   |---|---|
   | `OnAfterCreated` | `BrowserAfterCreated` |
   | `OnAcceleratorKeyPressed` | `BrowserAcceleratorKeyPressed` (7.2) |
   | `OnNavigationCompleted` | `BrowserNavigationCompleted` (7.6) |
   | `OnNewWindowRequested` | `BrowserNewWindowRequested` (7.6) |
   | `OnBasicAuthenticationRequested` | `BrowserBasicAuthenticationRequested` (7.6) |
   | `OnDocumentTitleChanged` | `BrowserDocumentTitleChanged` (7.6) |
   | `OnDownloadStarting` | `BrowserDownloadStarting` (7.8) |
   | `OnDownloadStateChanged` | `BrowserDownloadStateChanged` (7.8) |
   | `OnExecuteScriptCompleted` | `BrowserExecuteScriptCompleted` (7.7) |
   | `OnContextMenuRequested` | `BrowserContextMenuRequested` (7.9) |
   | `OnCustomItemSelected` | `BrowserCustomItemSelected` (7.9) |

6. `DefaultURL := AURL`, `WindowParent.Browser := Browser`.
7. `Result := PageIndex of the tab`, `Caption := 'Tab ' + (Result + 1)`.
8. `ActivePageIndex := Result`, `SynchronizeVisibility`, `UpdateTabHeaderVisibility`.
9. `AllowHostInputProcessing := True` (it must be set before creation, so before `CreateBrowser`).
10. `UserDataFolder := FDataFolder`. If `FCacheSizeMB > 0`, `AdditionalBrowserArguments := '--disk-cache-size=' + (FCacheSizeMB × 1024 × 1024)` (computed as Int64).
11. `CreateBrowser(WindowParent.Handle, False)` (False: create an environment for `UserDataFolder`, not the default environment). Creation is asynchronous. When done, `BrowserAfterCreated` is called and it automatically navigates to `DefaultURL`.

`BrowserAfterCreated`: `SynchronizeBounds`, `SynchronizeVisibility` (`IsVisible` takes effect from this point), if `FUserAgent <> ''` set `UserAgent`, set `IgnoreCertificateErrors`.

### 7.2 Display

| Procedure | Processing |
|---|---|
| `FindWindowParent(Sheet)` | Returns the first `TWVWindowParent` among the tab's `Controls`. nil if none |
| `SynchronizeBounds` | `WindowParent.UpdateSize` of the visible tab |
| `SynchronizeVisibility` | `Browser.IsVisible := (index = ActivePageIndex)` for all tabs |
| `UpdateTabHeaderVisibility` | `ShowTabs := not (FHideSingleTab and (PageCount <= 1))` |
| `SetActiveIndex(V)` | Only when 0 .. `PageCount - 1`: `ActivePageIndex := V`, `SynchronizeBounds`, `SynchronizeVisibility` |
| `SetUserAgent(V)` | If different, remember it and set it on all `Initialized` tabs (tabs not yet ready are set in `BrowserAfterCreated`) |
| `SetIgnoreCertificateErrors(V)` | Same approach |
| `GetUserAgent` | If the visible tab is `Initialized`, its `UserAgent`; otherwise `FUserAgent` |
| `BrowserAcceleratorKeyPressed` | Only on `KEY_DOWN` with `VK_F5`: `Reload`, `Set_Handled(1)` (key release and repeats are ignored) |

### 7.3 Waiting scheme (common pattern)

`NavigateAndWait`, `SaveToFile`, `SaveAsWebPage`, `SaveScreenCapture`, `SavePDF`, `GetSourceTextForWindowParent` and `RunScript` wait in the same pattern.

1. Get the Browser of the visible tab. If there is none, or it is not `Initialized` (except for `NavigateAndWait`), do nothing.
2. Remember the Browser's original completion-event handler, then replace it with a handler for waiting (`RunScript` does not replace it. See 7.7).
3. `FWaitCompleted`, `FWaitSuccess`, `FWaitAborted := False`.
4. `FWaitTargetComponent := Browser`, `Browser.FreeNotification(Self)`.
5. Start the operation. If it cannot be started, leave.
6. `while not (FWaitCompleted or FWaitAborted) do Application.ProcessMessages`.
7. finally: unless `FWaitAborted`, call `RemoveFreeNotification` and restore the handler. `FWaitTargetComponent := nil`.

- `Notification`: on `opRemove`, if `AComponent = FWaitTargetComponent`, then `FWaitAborted := True`. The vanished Browser is not touched afterwards.
- The waiting handler only sets `FWaitCompleted := True` and stores the result.
- Only one waiting state is held. If another waiting method of the same component is called while waiting, the state is overwritten (a rule stated in the User Manual).

| Method | Replaced event | Operation started | Limit |
|---|---|---|---|
| `NavigateAndWait` | `OnNavigationCompleted` → `NavigateAndWaitHandler` (`Get_IsSuccess`) | `Navigate(AURL)` (called first) | `TimeoutMS` (`GetTickCount64`) |
| `SaveToFile`, `GetSourceTextForWindowParent` | `OnRetrieveHTMLCompleted` → `SaveToFileHandler` | `RetrieveHTML` | none |
| `SaveAsWebPage` | `OnRetrieveMHTMLCompleted` → `SaveAsWebPageHandler` | `RetrieveMHTML` | none |
| `SaveScreenCapture` | `OnCapturePreviewCompleted` → `CapturePreviewHandler` (`AErrorCode = 0`) | `CapturePreview(JPEG, IStream)` | none |
| `SavePDF` | `OnPrintToPdfCompleted` → `PrintToPdfHandler` (`AIsSuccess`) | `PrintToPdf(path)` | none |
| `RunScript` | not replaced | `ExecuteScript(AScript, ID)` | `ATimeoutMS` (0 or less means no limit. `GetTickCount`) |

- `NavigateAndWait` watches the Browser of the created tab even when the tab was created by the first `Navigate`.

### 7.4 Page navigation

| Procedure | Processing |
|---|---|
| `Navigate(URL)` | If `PageCount = 0`, `Add(URL)`. If the visible tab is `Initialized`, `Browser.Navigate`; otherwise `DefaultURL := URL` |
| `Back`, `Next`, `Reload` | `GoBack`, `GoForward`, `Refresh` of the visible tab |
| `LoadFromFile(F)` | `Navigate('file:///' + F with '\' replaced by '/')` |

### 7.5 Saving

| Method | Processing |
|---|---|
| `SaveToFile(F)` | Get the HTML by 7.3. If it failed or is empty, do not save. If the folder does not exist, `ForceDirectories`. `TStringStream.SaveToFile` (overwrites. If it cannot write, the exception propagates) |
| `SaveAsWebPage(F)` | Same (MHTML) |
| `SaveScreenCapture(F)` | Decide the file name (below), create the folder, wrap `TFileStream.Create(path, fmCreate)` in a `TStreamAdapter` (`soReference`), pass it to `CapturePreview`, and wait by 7.3. Finally `FS.Free` |
| `SavePDF(F)` | Decide the file name, create the folder, and wait for `PrintToPdf` by 7.3 |

- When the file name is omitted: replace `\ / : * ? " < > |` in `DocumentTitle` (or 'capture' if empty) with '_', giving `IncludeTrailingPathDelimiter(FSavePath) + title + '.jpg'` ('.pdf' for PDF).
- `SaveScreenCapture` creates the file first, so an empty file remains even if the capture failed.
- Reason for using `TStringStream`: `TStringList` splits and rebuilds at line breaks, which is wasteful for large pages.

### 7.6 Bridging Browser events

The tab index is the `PageIndex` of the `Owner` (`TTabSheet`) of `Sender` (`TWVBrowser`) (`TabIndexOfBrowser`. -1 if not found).

| Procedure | Processing |
|---|---|
| `BrowserNavigationCompleted` | If `OnDocumentComplete` is assigned, call it with `Get_IsSuccess` as `ASuccess` |
| `BrowserNewWindowRequested` | Always `Set_Handled(1)` (do not open the popup). Get the URI with `Get_uri` (free it with `CoTaskMemFree`), call `OnNewWindowRequested` with `Accept := True`. If `Accept` and the URI is not empty, `Add(URI)` |
| `BrowserBasicAuthenticationRequested` | If `OnBasicAuthenticationRequested` is assigned, pass `AWebView` and `AArgs` as they are. Otherwise do nothing (WebView2's standard dialog) |
| `BrowserDocumentTitleChanged` | If `DocumentTitle` is not empty, set it as that tab's `Caption` |

### 7.7 Running JavaScript

Execution ID: `NextScriptID` cycles through 1 .. 9999. IDs of 10000 and above are used by WebView4Delphi for its own processing (such as `RetrieveHTML`), and their results do not arrive in `OnExecuteScriptCompleted`, so they are not used. 0 means "not waiting".

| Procedure | Processing |
|---|---|
| `RunScript` | `False` if the visible tab is not `Initialized`. `FRunScriptID := NextScriptID` and wait by the pattern of 7.3. When finished, `AResultJson := FRunScriptResult`, `Result := FWaitSuccess`. In finally, `FRunScriptID := 0` |
| `RunScriptAsync(T, S, CB)` | 0 if `T` is out of range or not `Initialized`. Add a `TCTabScriptItem` (ID, Browser, CB) to `FScripts` and `ExecuteScript(S, ID)`. If it cannot be started, remove it and return 0. Returns the ID |
| `CancelScriptAsync(ID)` | Remove that ID from `FScripts` |
| `ReleaseScriptsOf(B)` | Remove from `FScripts` the entries whose Browser is `B` (no notification) |
| `BrowserExecuteScriptCompleted` | If `FRunScriptID <> 0` and the ID matches, `ExecuteScriptHandler` (`FWaitCompleted := True`, success is `AErrorCode = 0`, store the result). Otherwise look in `FScripts` for the entry with the same ID and Browser, remove it from the list, then `CB(Self, ID, AErrorCode = 0, result)`. If found in neither, discard |

- `RunScriptAsync` does not call `ProcessMessages`.

### 7.8 Downloads

`BrowserDownloadStarting`: if neither `OnDownloadStarting` nor `OnDownloadCompleted` is assigned, do nothing (WebView2's standard behavior).

1. Wrap in `TCoreWebView2DownloadStartingEventArgs`. If there is no `DownloadOperation`, leave.
2. `Inc(FDownloadIDGen)`, `TCoreWebView2DownloadOperation.Create(…, FDownloadIDGen)`.
3. If `OnDownloadStarting` is assigned, call it with `URI`, `ResultFilePath` (initial value) and `Cancel = False`. If `Cancel`, set `Args.Cancel := True` and leave. If the file name is not empty, put it in `ResultFilePath` and `Handled := True` (do not show the standard UI).
4. If `OnDownloadCompleted` is assigned and `Op.AddAllBrowserEvents(Browser)` succeeds, make a `TCTabDownloadItem` and add it to `FDownloads` (`AddStateChangedEvent` is protected, so the public `AddAllBrowserEvents` is used. Progress events are also registered but not used). An `Op` that was not added is freed.

`BrowserDownloadStateChanged`: look in `FDownloads` for the entry with the same ID. If `IN_PROGRESS`, do nothing. Otherwise, `Extract` it from the list first (so it is not notified twice even if the same processing arrives inside), call `OnDownloadCompleted(Self, tab, ResultFilePath, State = COMPLETED)`, then `Free`.

`ReleaseDownloadsOf(B)`: remove the entries whose Browser is `B` (no notification).

### 7.9 Right-click menus

**Tab header** (`HandleTabContextPopup`)

1. `FContextMenuTabIndex := IndexOfTabAt(X, Y)`. If there is no tab there, `Handled := True` (do not show) and leave.
2. `FContextTabIndex := FContextMenuTabIndex`.
3. Remove everything except "Close" from `FTabPopupMenu`.
4. If `FHeaderPopupMenu` exists, call its `OnPopup`. If `FHeaderPopupMenu` still exists after the call, add a separator and copy with `CopyMenuToHeader`. If the last item is a separator, remove it.

`CopyMenuToHeader(Src, Dest)`: only `Visible` items; create a `TMenuItem` (owner is `FTabPopupMenu`). A separator is '-'. Otherwise copy `Caption`, `Enabled`, `Checked` and `ShortCut`, and set `Tag := PtrInt(original item)`. If there are no children, `OnClick := HeaderCopyItemClick`; if there are children, copy them with the same procedure.

`HeaderCopyItemClick`: if the original item in `Tag` is still inside `FHeaderPopupMenu` (`MenuContainsItem`; only compares pointers), `Click`.

`CloseMenuItemClick`: `Remove(FContextMenuTabIndex)`. `DoCloseTabClicked`: if `Sender` is a `TTabSheet`, `Remove` that tab; if `Sender = Self`, `Remove` the visible tab.

**Page** (`BrowserContextMenuRequested`)

1. `ReleasePageMenuItemsOf(nil)` (remove the items added last time).
2. `FContextTabIndex := TabIndexOfBrowser(Browser)`.
3. Standard items are not suppressed (`Handled` is not set). After them, add a separator, "New" (`pmaNew`) and "Close" (`pmaClose`).
4. If `FPagePopupMenu` exists, call its `OnPopup`. If `FPagePopupMenu` still exists after the call and at least one item is visible (`HasVisibleItem`), add a separator and copy with `CopyMenuToPage`.

`AddPageMenuItem`: create with `CoreWebView2Environment.CreateContextMenuItem` (if it cannot be created on an old runtime, add nothing). Put `CommandId`, `Action`, `Source` and `Browser` in a `TCTabPageMenuItem`; except for separators set `IsEnabled`, and for checks `IsChecked`. For anything other than `pmaNone`, `AddAllBrowserEvents(Browser)` (so that `OnCustomItemSelected` arrives when selected). If `AppendValue` succeeds, add it to `FPageMenuItems` and return it.

`CopyMenuToPage`: `Visible` only. Separator → `SEPARATOR`, has children → `SUBMENU` (copy the children with the same procedure), `Checked` → `CHECK_BOX` (`pmaApp`), otherwise → `COMMAND` (`pmaApp`). Icons and shortcut keys are not copied (they are not shown in WebView2 menus).

`BrowserCustomItemSelected`: find the item with the same `CommandId` and Browser; if it is not `pmaNone`, put it in `FPendingAction`, `FPendingItem` and `FPendingBrowser` and call `Application.QueueAsyncCall(DoPendingMenu, 0)`. It is not executed on the spot so that the tab (Browser) is not removed inside a WebView2 event.

`DoPendingMenu`: put `FindTabOfBrowser(FPendingBrowser)` (only compares pointers; -1 if it has vanished) into `FContextTabIndex`, clear the pending state, then execute. `pmaNew` → `NewTabMenuClick`, `pmaClose` → `Remove` if the tab exists, `pmaApp` → `Click` if the original item is still inside `FPagePopupMenu`.

**Setting `HeaderPopupMenu` and `PagePopupMenu`**: only when the previous value differs from the other one, `RemoveFreeNotification`. `FreeNotification` on the new value. In `Notification` `opRemove`, set the vanished one to nil.

### 7.10 Closing a tab (Remove) and new tab

`Remove` is `Remove(ActivePageIndex)`.

`Remove(i)`:

1. If out of range, do nothing.
2. `LastURL := 'about:blank'`. If `PageCount = 1`, `LastURL := DoNewTabRequest(ntrLastTabClosed)`. If the `Source` of the tab being closed equals `LastURL` (case-insensitive), do nothing (avoids the waste of deleting and recreating the same tab).
3. Tab to show after closing: if `i < visible`, shift back by 1. If `i = visible`, `i` if there is a right neighbor, otherwise `i - 1`. If `i > visible`, unchanged.
4. `ReleaseDownloadsOf`, `ReleaseScriptsOf`, `ReleasePageMenuItemsOf` for that tab's Browser (remove registered events before the Browser disappears).
5. `Pages[i].Free`.
6. If `PageCount = 0`, `Add(LastURL)` and leave.
7. Clamp the index from step 3 into range and make it `ActivePageIndex`, then `SynchronizeBounds`, `SynchronizeVisibility`, `UpdateTabHeaderVisibility`.

`DoNewTabRequest(Reason)`: call `OnNewTabRequest` with `URL := 'about:blank'`, `Accept := True`. If `Accept = False`, `ntrMenuNew` returns '' and `ntrLastTabClosed` becomes 'about:blank'. If the URL is empty, 'about:blank'.

`NewTabMenuClick`: if `DoNewTabRequest(ntrMenuNew)` is not empty, `Add`.

### 7.11 Settings file (LoadSettings)

1. `FCacheSizeMB := 0`.
2. Path: `CXResolveRuntimeDir('', 'MonacoFolder', 'monaco') + PathDelim + 'tabbrowser.json'` (chapter 9. `MonacoFolder` of WebView2.ini, EXE\monaco if empty).
3. If it does not exist, create the folder with `ForceDirectories`, write `{ "cacheSizeMB": 0 }` and leave.
4. If it exists, read it; if `GetJSON` is a `TJSONObject`, `Get('cacheSizeMB', 0)`. Less than 0 becomes 0.
5. Catch all exceptions and set `FCacheSizeMB := 0` (if it cannot be written or read, it runs with no limit).

- When WebView2.ini does not exist, `CXResolveRuntimeDir` returns EXE\monaco (it is not an error). The absence of WebView2.ini is reported by `CXStartWebView2` at the first `Insert`.

## 8. TCTabPanel values

| Procedure | Processing |
|---|---|
| `GetPanel(i)` | If in range, store `FindWindowParent(Pages[i])`; if out of range, store nil, and return |
| `GetActiveTab` | Store `FindWindowParent(ActivePage)` and return |
| `GetTitleForWindowParent` | `DocumentTitle` if there is a Browser, otherwise '' |
| `GetURLForWindowParent` | `Source` if there is a Browser, otherwise '' |
| `GetSourceTextForWindowParent` | '' unless `Initialized`. Wait for `RetrieveHTML` by the pattern of 7.3; on success `FRetrievedHTML` |

## 9. WebView2 preparation (uCXRuntime)

Used in common by CX's WebView2 components (TCTabBrowser, TCMonacoEditor). It has no initialization or finalization (cx is also built into the IDE, so merely adding it to uses does nothing).

```pascal
function CXRuntimeIniValue(const AKey: string): string;
function CXFullPath(const APath: string): string;
function CXResolveRuntimeDir(const AProperty, AIniKey, ADefaultName: string): string;
function CXStartWebView2(out AError: string): Boolean;
```

| Function | Processing |
|---|---|
| `CXRuntimeIniValue` | The value (leading and trailing whitespace removed) of `AKey` from `[WebView2]` of WebView2.ini in the EXE folder. The ini is read only the first time, and the section's "key=value" pairs are kept as strings. If the ini is missing or unreadable, every key is '' (no exception) |
| `CXFullPath` | '' if ''. If there is no drive name, append to the EXE folder. Remove '..' with `ExpandFileName` |
| `CXResolveRuntimeDir` | If `AProperty` is not empty, `CXFullPath(AProperty)`. If empty, and the ini's `AIniKey` is not empty, its `CXFullPath`. If that is also empty, EXE folder + `ADefaultName`. The trailing '\' is removed |
| `CXStartWebView2` | Below |

`CXStartWebView2(out AError)`:

1. `AError := ''`.
2. If `GlobalWebView2Loader` exists: if `InitializationError`, `AError := ErrorMessage`, `False`. Otherwise `True` (does nothing from the second time on. The same applies even if another component created it first).
3. If WebView2.ini does not exist in the EXE folder, `AError := 'WebView2.ini not found: ' + path`, `False`.
4. `GlobalWebView2Loader := TWVLoader.Create(nil)`, `ShowMessageDlg := False` (errors are returned to the caller without showing a message box).
5. `LoaderDllPath`: if the ini's `LoaderDllPath` is not empty, its `CXFullPath` (if empty, not set. WebView2Loader.dll in the EXE folder is used).
6. `UserDataFolder`: `CXFullPath` of the ini's `UserDataFolder`. If empty, EXE folder + `WebView2Data`.
7. If `StartWebView2` is `False`, `AError := ErrorMessage`, `False`. Otherwise `True`.

- `StartWebView2` performs up to library loading and runtime version checking on the spot, and creates the default environment asynchronously. TCTabBrowser does not use the default environment; it creates the `TabBrowserData` environment per tab with `CreateBrowser(…, False)` (this can be created as long as the library is loaded).
- `GlobalWebView2Loader` is not freed (the finalization of `uWVLoader` frees it).
- A failed loader is also kept (step 2 keeps returning the same error. It is not recreated).

## 10. Points to check when investigating defects

| Symptom | Where to look |
|---|---|
| Exception when creating a tab | `CXStartWebView2` (chapter 9). WebView2.ini, WebView2Loader.dll (64-bit version), WebView2 runtime |
| Page does not appear / size does not fit | `BrowserAfterCreated`, `SynchronizeBounds` (7.1, 7.2) |
| Background tab comes to the front | `SynchronizeVisibility`, `Change` (7.2) |
| Waiting method does not return | The replacement in 7.3. Whether another waiting method was called while waiting |
| Crash when a tab is closed while waiting | `Notification` and `FWaitAborted` (7.3) |
| `RunScript` result does not arrive | Whether the execution ID has reached 10000 or more; the dispatch on `FRunScriptID` (7.7) |
| Download completion does not arrive | Success of `AddAllBrowserEvents`, `FDownloads` (7.8) |
| Items do not appear in the page right-click menu | Success of `CreateContextMenuItem` (old runtime), `HasVisibleItem` (7.9) |
| Crash when closing from the menu | Whether it goes through `QueueAsyncCall(DoPendingMenu)` (7.9) |
| Recreated every time the last tab is closed | Difference in how the URL of `OnNewTabRequest` and `Source` are written (7.10) |
| Freezes together with TCMonacoEditor | `UserDataFolder := FDataFolder` and `CreateBrowser(…, False)` (7.1) |
| Cache limit has no effect | Location of tabbrowser.json (7.11), `AdditionalBrowserArguments` |
