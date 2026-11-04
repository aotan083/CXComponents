# TCTabBrowser User Manual

Author: aotan083
Date: 2026-11-05
Version: 1.2

---

## 1. Overview and Classes

A tabbed Web browser built on WebView2 (the mechanism behind Microsoft Edge). Each tab shows a different Web page. You can save pages (HTML, MHTML, image, PDF), run JavaScript, receive downloads, and add items to the right-click menu.

```
+-----------+-----------+------------------------------+
| Google  × | GitHub  × |                              |
+-----------+-----------+------------------------------+
|                                                      |
|   Web page of the visible tab                        |
|                                                      |
+------------------------------------------------------+
```

- The [×] on a tab header closes that tab.
- The number of tabs never becomes 0. When the last tab is closed, the component creates one new tab.
- When a page tries to open a new window, it is opened in a new tab instead of a window.
- It runs in a browser process separate from other WebView2s in the same application (such as TCMonacoEditor), so they do not freeze each other.
- The component prepares WebView2 by itself (nothing needs to be written in the application's .lpr).

| Item | Details |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |
| Requirements to run | Microsoft Edge WebView2 Runtime (preinstalled on Windows 11), WebView2Loader.dll (64-bit version), WebView2.ini |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Contents |
|---|---|---|---|---|
| `TCTabBrowser` | `uCTabBrowser` | cx | `TPageControl` | A tabbed Web browser using WebView2. Can save pages (HTML, MHTML, image, PDF), run JavaScript, receive downloads, and add items to the right-click menu |

| Type | Unit | Contents |
|---|---|---|
| `TCTabPanel` | `uCTabBrowser` | Tab information (obtained via `Panels[i]` and `ActiveTab`). 4.2 |
| `TTabNewTabReason` | `uCTabBrowser` | Reason the component creates a new tab. `ntrMenuNew` ("New" in the right-click menu), `ntrLastTabClosed` (the last tab was closed) |
| `TTabDocumentCompleteEvent` | `uCTabBrowser` | `procedure(Sender: TObject; ATabIndex: Integer; ASuccess: Boolean) of object`. Type of `OnDocumentComplete` |
| `TTabNewWindowRequestedEvent` | `uCTabBrowser` | `procedure(Sender: TObject; ATabIndex: Integer; var AURI: string; var AAccept: Boolean) of object`. Type of `OnNewWindowRequested` |
| `TTabBasicAuthenticationRequestedEvent` | `uCTabBrowser` | `procedure(Sender: TObject; ATabIndex: Integer; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2BasicAuthenticationRequestedEventArgs) of object`. Type of `OnBasicAuthenticationRequested` |
| `TTabDownloadStartingEvent` | `uCTabBrowser` | `procedure(Sender: TObject; ATabIndex: Integer; const AURI: string; var AFileName: string; var ACancel: Boolean) of object`. Type of `OnDownloadStarting` |
| `TTabDownloadCompletedEvent` | `uCTabBrowser` | `procedure(Sender: TObject; ATabIndex: Integer; const AFileName: string; ASuccess: Boolean) of object`. Type of `OnDownloadCompleted` |
| `TTabNewTabRequestEvent` | `uCTabBrowser` | `procedure(Sender: TObject; AReason: TTabNewTabReason; var AURL: string; var AAccept: Boolean) of object`. Type of `OnNewTabRequest` |
| `TTabScriptResultEvent` | `uCTabBrowser` | `procedure(Sender: TObject; AID: Integer; ASuccess: Boolean; const AResultJson: string) of object`. Type that receives the result of `RunScriptAsync` |

- When placed on a form, `uCTabBrowser` is automatically added to uses.
- When placed on a form, cx is automatically added to the project's required packages.
- When creating it in code, write it in uses yourself.
- When using `OnBasicAuthenticationRequested`, also write WebView4Delphi's `uWVTypeLibrary` (types such as `ICoreWebView2`) in uses.

## 2. From Placing on a Form to Running

1. From the [CX] palette, place TCTabBrowser on the form.
2. Put WebView2Loader.dll (64-bit version) in the same folder as the executable (EXE). Obtain it from the WebView4Delphi repository (https://github.com/salvadordf/WebView4Delphi).
3. Put WebView2.ini in the same folder as the EXE (2.1).
4. In the form's `OnShow`, write the code that opens the first tab (9.1).
5. To do something when loading finishes, double-click `OnDocumentComplete` on the Events tab and write the handler (9.2).
6. Run.

- WebView2 preparation (creating `GlobalWebView2Loader` and `StartWebView2`) is done by the component itself when the first tab is created (`Add`, `Insert`, `Navigate`). Nothing needs to be written in the application's .lpr.
- WebView2 preparation is done only once per application. The same one is shared with other CX WebView2 components such as TCMonacoEditor.
- If WebView2.ini is missing, or WebView2 cannot be prepared, the method that creates the tab raises an exception (`Exception`). The message is "WebView2.ini not found: (file location)" or a WebView2 error text.

### 2.1 WebView2.ini

Place it in the same folder as the EXE. Shared by the CX WebView2 components (TCTabBrowser, TCMonacoEditor).

```ini
[WebView2]
LoaderDllPath=
UserDataFolder=
MonacoFolder=
PreviewFolder=

[CX]
Language=
```

| Key | Contents | When empty or omitted |
|---|---|---|
| `LoaderDllPath` | The WebView2Loader.dll file | WebView2Loader.dll in the EXE folder |
| `UserDataFolder` | WebView2 user data folder (used by TCMonacoEditor. Not used by TCTabBrowser. Chapter 7) | EXE folder\WebView2Data |
| `MonacoFolder` | Folder containing TCMonacoEditor's `editor.html` and `vs`. TCTabBrowser's settings file (chapter 7) is also placed here | EXE folder\monaco |
| `PreviewFolder` | Folder containing TCMonacoEditor's `preview.html` and `lib` | EXE folder\preview |
| `Language` (`[CX]`) | Screen language, `ja` or `en` (2.2) | Windows display language |

- Always place the file. All key values may be empty (the empty-case locations are then used for all).
- Relative paths are counted from the EXE folder. Absolute paths can also be written.
- It is read only once, on first use after startup. Changes made while running take effect from the next startup.

**Tab behavior**

| Behavior | Details |
|---|---|
| Tab header | Initially "Tab n". Once the page title is determined, it changes to the title |
| Hiding the header | With `HideSingleTab = True` (default), the header is hidden when there is one tab or fewer |
| [×] | Closes that tab |
| Closed the visible tab | Shows the tab on the right. If there is none, the tab on the left |
| Closed the last tab | The URL is decided via `OnNewTabRequest` (`AReason = ntrLastTabClosed`); if the closed tab is already showing that URL, nothing happens. Otherwise the tab is closed and a new tab is created with that URL (the number of tabs never becomes 0) |
| A page tried to open a new window | No window is opened; it is opened in a new tab at the end |
| F5 | Reloads the visible page |

### 2.2 Screen Language (Japanese/English)

The text this component shows on screen (tab headers, context menu, etc.) appears in Japanese or English. There is one language for all cx components; it is not set per component.

Write the following in WebView2.ini (2.1).

```ini
[CX]
Language=en
```

| Order | How it is decided |
|---|---|
| 1 | If `Language` in `[CX]` is `ja` or `en`, that language (case-insensitive) |
| 2 | Otherwise (no `[CX]`, empty, or another value), the Windows display language: `ja` if it is Japanese, `en` otherwise |

- It is decided only once, the first time text is shown. Rewriting it while running has no effect until the next startup.
- The screen text quoted in this manual (such as "Tab n" and "Close") is the English text. With `ja`, it is shown in Japanese (such as 「タブ n」 and 「閉じる」).
- The page content and the standard items of the context menu provided by WebView2 are shown in the language of Windows and WebView2.

## 3. Properties

### 3.1 Added by this component

| Name | Type | Access | Contents |
|---|---|---|---|
| `Count` | `Integer` | Read | Number of tabs. Run time only |
| `ActiveIndex` | `Integer` | Read/Write | Index of the visible tab (from 0). Writing switches tabs. Writing an out-of-range value does nothing. Run time only |
| `Panels[AIndex]` | `TCTabPanel` | Read | Information of the tab at that index (4.2). If out of range, every value is ''. Run time only |
| `ActiveTab` | `TCTabPanel` | Read | Information of the visible tab (4.2). Run time only |
| `ContextTabIndex` | `Integer` | Read | Index of the tab right-clicked last (default -1). Chapter 6. Run time only |
| `HideSingleTab` | `Boolean` | Read/Write | If `True` (default), the header is hidden when there is one tab or fewer |
| `UserAgent` | `string` | Read/Write | Reading gives the User-Agent used by the visible tab (the configured value if there are no tabs). Writing sets it on all tabs and on tabs created later. '' means WebView2's default |
| `IgnoreCertificateErrors` | `Boolean` | Read/Write | If `True` (default), pages are displayed ignoring certificate errors. Applied to all tabs and tabs created later. For applications that display general sites on the Internet, consider setting it to `False` |
| `SavePath` | `string` | Read/Write | Destination folder when the file name is omitted in `SaveScreenCapture` and `SavePDF` (default is the current folder at the time the component was created) |
| `HeaderPopupMenu` | `TPopupMenu` | Read/Write | Items to add to the right-click menu of the tab header (chapter 6) |
| `PagePopupMenu` | `TPopupMenu` | Read/Write | Items to add to the right-click menu of the Web page (chapter 6) |

### 3.2 Inherited from TPageControl

| Name | Type | Access | Contents |
|---|---|---|---|
| `ActivePage` | `TTabSheet` | Read/Write | Page of the visible tab. Writing switches tabs (same effect as `ActiveIndex`). Use at run time |
| `Align` | `TAlign` | Read/Write | Placement within the parent |
| `Anchors` | `TAnchors` | Read/Write | Which edges follow when the parent's size changes |
| `AnchorSideBottom` | `TAnchorSide` | Read/Write | Which part of which control the bottom edge is aligned to |
| `AnchorSideLeft` | `TAnchorSide` | Read/Write | Which part of which control the left edge is aligned to |
| `AnchorSideRight` | `TAnchorSide` | Read/Write | Which part of which control the right edge is aligned to |
| `AnchorSideTop` | `TAnchorSide` | Read/Write | Which part of which control the top edge is aligned to |
| `AutoSize` | `Boolean` | Read/Write | Whether to resize to fit the contents |
| `BiDiMode` | `TBiDiMode` | Read/Write | Whether to lay out right to left |
| `BorderSpacing` | `TControlBorderSpacing` | Read/Write | Surrounding margins |
| `Constraints` | `TSizeConstraints` | Read/Write | Upper and lower size limits |
| `Cursor` | `TCursor` | Read/Write | Mouse cursor when over it |
| `DragCursor` | `TCursor` | Read/Write | Mouse cursor while dragging |
| `DragKind` | `TDragKind` | Read/Write | Kind of drag (drag and drop, or docking) |
| `DragMode` | `TDragMode` | Read/Write | Whether dragging starts automatically |
| `Enabled` | `Boolean` | Read/Write | Whether usable |
| `Font` | `TFont` | Read/Write | Text of the tab headers |
| `Height` | `Integer` | Read/Write | Height |
| `HelpContext` | `THelpContext` | Read/Write | Help number |
| `HelpKeyword` | `string` | Read/Write | Help keyword |
| `HelpType` | `THelpType` | Read/Write | Whether help is looked up by number (`htContext`) or by keyword (`htKeyword`) |
| `Hint` | `TTranslateString` | Read/Write | Hint text |
| `HotTrack` | `Boolean` | Read/Write | Whether to highlight the tab under the mouse |
| `Images` | `TCustomImageList` | Read/Write | Tab icons (the index is decided in `OnGetImageIndex`) |
| `ImagesWidth` | `Integer` | Read/Write | Icon width |
| `Left` | `Integer` | Read/Write | Left edge position |
| `MultiLine` | `Boolean` | Read/Write | Whether to arrange tabs in multiple rows |
| `Name` | `TComponentName` | Read/Write | Component name |
| `Options` | `TCTabControlOptions` | Read/Write | Tab settings (default `[nboShowCloseButtons]`). Removing `nboShowCloseButtons` hides the [×] on tabs |
| `ParentBiDiMode` | `Boolean` | Read/Write | Whether to use the parent's `BiDiMode` |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the parent's `Font` |
| `ParentShowHint` | `Boolean` | Read/Write | Whether to use the parent's `ShowHint` |
| `RaggedRight` | `Boolean` | Read/Write | With multiple rows, whether not to stretch tabs to the right edge |
| `ScrollOpposite` | `Boolean` | Read/Write | With multiple rows, whether to move the selected row to the opposite side |
| `ShowHint` | `Boolean` | Read/Write | Whether to show hints |
| `Style` | `TTabStyle` | Read/Write | Tab shape (tab, button, flat button) |
| `TabHeight` | `Smallint` | Read/Write | Tab height (0 for automatic) |
| `TabIndex` | `Integer` | Read/Write | Index of the visible tab (same effect as `ActiveIndex`) |
| `TabOrder` | `TTabOrder` | Read/Write | Order of moving with the Tab key |
| `TabPosition` | `TTabPosition` | Read/Write | Tab position (top, bottom, left, right) |
| `TabStop` | `Boolean` | Read/Write | Whether the Tab key stops here |
| `TabWidth` | `Smallint` | Read/Write | Tab width (0 to fit the text) |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely |
| `Top` | `Integer` | Read/Write | Top edge position |
| `Visible` | `Boolean` | Read/Write | Whether to display |
| `Width` | `Integer` | Read/Write | Width |

## 4. Methods and TCTabPanel

### 4.1 Methods

**Tabs**

| Name | Arguments | Return value | Contents |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | - | Creates it. Used when creating in code (9.10) |
| `Add` | `const AURL: string = 'about:blank'` | `Integer` | Adds a tab at the end, opens `AURL` and shows it. Returns the index of the added tab. Does not wait for loading |
| `Insert` | `i: Integer; const AURL: string = 'about:blank'` | `Integer` | Adds a tab at index `i`, opens `AURL` and shows it. `i` is clamped to 0 .. `Count`. Returns the index of the added tab |
| `Remove` | - | - | Closes the visible tab ("Tab behavior" in chapter 2) |
| `Remove` | `i: Integer` | - | Closes the tab at index `i`. Does nothing if out of range |

- `Add` and `Insert` raise an exception if WebView2 cannot be prepared (chapter 2).
- A download in progress in a closed tab is no longer watched, without raising `OnDownloadCompleted`.
- The result of `RunScriptAsync` for a closed tab is discarded without calling `ACallback`.

**Displaying pages**

| Name | Arguments | Return value | Contents |
|---|---|---|---|
| `Navigate` | `const AURL: string` | - | Opens `AURL` in the visible tab. Does not wait for loading. If there are no tabs, adds a tab and opens it |
| `NavigateAndWait` | `const AURL: string; TimeoutMS: Integer = 60000` | `Boolean` | Opens like `Navigate` and waits until loading finishes. `True` on success. `False` on failure or when `TimeoutMS` (milliseconds) has passed |
| `Back` | - | - | Goes back to the previous page in the visible tab |
| `Next` | - | - | Goes forward to the next page in the visible tab |
| `Reload` | - | - | Reloads the visible tab (same as F5) |
| `LoadFromFile` | `const AFileName: string` | - | Opens and displays a file in the visible tab |

**Saving**

| Name | Arguments | Return value | Contents |
|---|---|---|---|
| `SaveToFile` | `sFileName: String` | - | Saves the HTML source of the visible tab. Does not save if it could not be obtained or is empty. Raises an exception if it cannot write |
| `SaveAsWebPage` | `sFileName: String` | - | Saves the whole page of the visible tab in MHTML format (one file). Does not save if it could not be obtained or is empty. Raises an exception if it cannot write |
| `SaveScreenCapture` | `const AFileName: string = ''` | - | Saves the screen of the visible tab as JPEG. If omitted, `SavePath\(page title).jpg`. An empty file may remain even if the screen could not be captured |
| `SavePDF` | `const AFileName: string = ''` | - | Saves the page of the visible tab as PDF. If omitted, `SavePath\(page title).pdf` |

- The destination folder is created if it does not exist. An existing file with the same name is overwritten.
- When the file name is omitted, characters in the title that cannot be used in file names (`\ / : * ? " < > |`) become "_". If the title is empty, "capture" is used.
- Waits until saving finishes (screen processing keeps running while waiting). There is no time limit.

**Running JavaScript**

| Name | Arguments | Return value | Contents |
|---|---|---|---|
| `RunScript` | `const AScript: string; out AResultJson: string; ATimeoutMS: Integer = 30000` | `Boolean` | Runs JavaScript in the visible tab and waits until the result returns. `True` on success. `False` if there is no tab, the browser is not ready, it failed, or it timed out. `AResultJson` receives the result as a JSON string (a string result is enclosed in `"..."`). If `ATimeoutMS` is 0 or less, there is no limit |
| `RunScriptAsync` | `ATabIndex: Integer; const AScript: string; ACallback: TTabScriptResultEvent` | `Integer` | Runs JavaScript in the tab at index `ATabIndex` and returns immediately without waiting for the result. Returns a request number (1 or more). Returns 0 if it cannot run (tab index out of range, browser not ready). The result is reported through `ACallback` |
| `CancelScriptAsync` | `AID: Integer` | - | Cancels the wait for the result of `RunScriptAsync`. After cancelling, `ACallback` is not called. If the owner of `ACallback` is destroyed before the TCTabBrowser, always call this first |

**Display adjustment**

| Name | Arguments | Return value | Contents |
|---|---|---|---|
| `SynchronizeBounds` | - | - | Fits the size of the display area of the visible tab. The component does this automatically, so normally you do not need to call it |
| `SynchronizeVisibility` | - | - | Shows only the visible tab. The component does this automatically, so normally you do not need to call it |

- Waiting methods such as `NavigateAndWait`, `RunScript` and `SaveToFile` keep screen processing running while waiting. While one is waiting, do not call another waiting method of the same TCTabBrowser.

### 4.2 TCTabPanel (tab information)

| Name | Type | Access | Contents |
|---|---|---|---|
| `Title` | `string` | Read | Page title |
| `URL` | `string` | Read | URL being displayed |
| `SourceText` | `string` | Read | HTML source at the time of reading. Waits until it can be obtained (screen processing keeps running while waiting). '' if it cannot be obtained |

## 5. Events

### 5.1 Added by this component

| Name | Arguments | Contents |
|---|---|---|
| `OnDocumentComplete` | `Sender: TObject; ATabIndex: Integer; ASuccess: Boolean` | Page loading finished. `ATabIndex` is that tab's index. `ASuccess` is `True` on success |
| `OnNewWindowRequested` | `Sender: TObject; ATabIndex: Integer; var AURI: string; var AAccept: Boolean` | A page tried to open a new window. Rewriting `AURI` opens that URL. Setting `AAccept` (initially `True`) to `False` opens nothing. If `True`, it is opened in a new tab at the end (the same when this event is not used) |
| `OnBasicAuthenticationRequested` | `Sender: TObject; ATabIndex: Integer; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2BasicAuthenticationRequestedEventArgs` | HTTP authentication (Basic authentication) was requested. Setting the user name and password, or cancelling, is done by using `AArgs` directly. When this event is not used, WebView2's standard authentication dialog appears |
| `OnDownloadStarting` | `Sender: TObject; ATabIndex: Integer; const AURI: string; var AFileName: string; var ACancel: Boolean` | A download is starting. `AFileName` is the save destination (full path; initially WebView2's standard destination), and rewriting it saves to that location. Setting `ACancel` (initially `False`) to `True` cancels. When this event is used, WebView2's standard download UI is not shown |
| `OnDownloadCompleted` | `Sender: TObject; ATabIndex: Integer; const AFileName: string; ASuccess: Boolean` | A download finished. `AFileName` is the save destination (full path). `ASuccess` is `True` if completed, `False` if interrupted or failed |
| `OnNewTabRequest` | `Sender: TObject; AReason: TTabNewTabReason; var AURL: string; var AAccept: Boolean` | Before the component creates a new tab. Rewriting `AURL` (initially about:blank) opens that URL ('' means about:blank). Setting `AAccept` (initially `True`) to `False` cancels. However, for `ntrLastTabClosed` it cannot be cancelled and about:blank is opened |

- The URL returned for `ntrLastTabClosed` in `OnNewTabRequest` must be written in the same form as the URL shown after the page is opened (such as the presence of a trailing "/"). Otherwise, the tab is recreated every time the last tab is closed.

### 5.2 Inherited from TPageControl

| Name | Arguments | Contents |
|---|---|---|
| `OnChange` | `Sender: TObject` | After the visible tab has changed |
| `OnChanging` | `Sender: TObject; var AllowChange: Boolean` | Before the visible tab changes. `AllowChange := False` cancels it |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | Dropped by an LCL drag (between controls inside the application) |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | The dragged object came over it during an LCL drag. `Accept` decides whether to accept |
| `OnEndDock` | `Sender, Target: TObject; X, Y: Integer` | Docking finished |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | The LCL drag finished |
| `OnEnter` | `Sender: TObject` | Focus entered |
| `OnExit` | `Sender: TObject` | Focus left |
| `OnGetImageIndex` | `Sender: TObject; TabIndex: Integer; var ImageIndex: Integer` | When deciding a tab's icon index (when `Images` is used) |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was pressed on a tab header |
| `OnMouseEnter` | `Sender: TObject` | The mouse entered |
| `OnMouseLeave` | `Sender: TObject` | The mouse left |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | The mouse moved over a tab header |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was released on a tab header |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | The wheel was turned |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned toward you |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned away from you |
| `OnResize` | `Sender: TObject` | The size changed |
| `OnStartDock` | `Sender: TObject; var DragObject: TDragDockObject` | A docking drag started |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | An LCL drag started |

- Mouse and key input over the Web page is received by WebView2, so these events are not raised.

## 6. Right-click Menus

| Where right-clicked | Menu shown |
|---|---|
| Tab header (on a tab) | "Close" → separator → items of `HeaderPopupMenu` |
| Tab header (where there is no tab) | Nothing is shown |
| Web page | WebView2's standard items (matching the place right-clicked) → separator → "New", "Close" → separator → items of `PagePopupMenu` |

- "Close" closes the tab that was right-clicked. "New" adds a new tab at the end and shows it (the URL is decided by `OnNewTabRequest`).
- When `HeaderPopupMenu` and `PagePopupMenu` are not set, the application's items and the separator before them are not shown.
- The same TPopupMenu can be set on both.
- Just before the menu is shown, the TPopupMenu's `OnPopup` is called. Adjust item enabled state and checks inside `OnPopup`.
- Selecting a copied item calls the original item's `Click` (`OnClick`, `Action` and `AutoCheck` work as usual). Items of `PagePopupMenu` are executed after the menu closes.

**How items of the application's TPopupMenu are copied**

| Original item | After copying |
|---|---|
| `Visible = False` | Not copied |
| `Caption = '-'` | Separator |
| `Caption` | As is (including the & access key) |
| `Enabled` | As is |
| `Checked` | As is (becomes a checkable item) |
| Has child items | Becomes a submenu, and the child items are copied by the same rules |
| Icon (`ImageIndex`, `Bitmap`) | Not copied |
| Shortcut key | `HeaderPopupMenu`: shown. `PagePopupMenu`: not shown |

**The right-clicked tab (`ContextTabIndex`)**

| When | Value stored |
|---|---|
| A tab header was right-clicked | That tab's index |
| A Web page was right-clicked | The index of that page's tab |
| When executing an item of `PagePopupMenu` | The current index of the tab that was right-clicked. -1 if the tab was closed in the meantime |

## 7. Browser Data and Settings File

| Item | Location |
|---|---|
| Data folder | EXE folder\TabBrowserData (shared by all tabs. Login state and the like are saved) |
| Settings file | The `MonacoFolder` folder of WebView2.ini\tabbrowser.json (if `MonacoFolder` is empty, EXE folder\monaco\tabbrowser.json) |

- The data folder is kept separate from WebView2.ini's `UserDataFolder`. Using a different folder makes this a separate browser process from TCMonacoEditor and others.
- The settings file is read when the component is created (not read in the IDE). If it does not exist, it is created with the content `{ "cacheSizeMB": 0 }` (the folder is also created if missing). If it cannot be created, it runs with default values without saying anything.

| Key | Contents |
|---|---|
| `cacheSizeMB` | Upper limit of the browser cache (MB). 0 means no limit. Also no limit if unreadable or less than 0 |

## 8. Notes

### 8.1 Please do not change

The following properties are used inside the component. Changing their values will make it stop working correctly.

| Name | Reason |
|---|---|
| `PopupMenu` | Used for the right-click menu of the tab header. To add items, use `HeaderPopupMenu` and `PagePopupMenu` |
| `OnContextPopup` | Used for right-clicks on the tab header |
| `OnCloseTabClicked` | Used to close tabs with [×] |
| `ShowTabs` | Switched by the component through `HideSingleTab` |

### 8.2 Other

- Windows only.
- Do not add or remove tabs (`TTabSheet`) by any method other than `Add`, `Insert` and `Remove` (the IDE's "Add page", `TTabSheet.Create`, etc.). They become tabs without a browser.
- With an old WebView2 runtime, "New", "Close" and the application's items do not appear in the Web page's right-click menu, only WebView2's standard items.
- While the Web page has focus, keys (except F5) do not reach the application. The form's `OnKeyDown` and ActionList shortcuts do not work.
- In the IDE (design time), neither tabs nor browsers are created. Only an empty frame appears.
- Even when the component's window is recreated, for example by docking or undocking with AnchorDocking, every tab keeps showing the page that was open.

## 9. Usage Examples

### 9.1 Open the first tab at startup

```pascal
procedure TForm1.FormShow(Sender: TObject);
begin
  CTabBrowser1.Add('https://www.lazarus-ide.org/');
end;
```

### 9.2 When loading finishes, show the title on the form

```pascal
procedure TForm1.CTabBrowser1DocumentComplete(Sender: TObject;
  ATabIndex: Integer; ASuccess: Boolean);
begin
  if ATabIndex = CTabBrowser1.ActiveIndex then
    Caption := CTabBrowser1.ActiveTab.Title;
end;

procedure TForm1.CTabBrowser1Change(Sender: TObject);
begin
  Caption := CTabBrowser1.ActiveTab.Title;   // Also show it when switching tabs
end;
```

### 9.3 Address bar and back/forward buttons

```pascal
procedure TForm1.btnGoClick(Sender: TObject);
begin
  CTabBrowser1.Navigate(Edit1.Text);   // Open in the visible tab
end;

procedure TForm1.btnNewTabClick(Sender: TObject);
begin
  CTabBrowser1.Add(Edit1.Text);        // Open in a new tab
end;

procedure TForm1.btnBackClick(Sender: TObject);
begin
  CTabBrowser1.Back;
end;

procedure TForm1.btnNextClick(Sender: TObject);
begin
  CTabBrowser1.Next;
end;
```

### 9.4 Open, wait until loading finishes, then get the title with JavaScript

```pascal
procedure TForm1.btnTitleClick(Sender: TObject);
var
  Json: string;
begin
  if CTabBrowser1.NavigateAndWait('https://example.com/') then
    if CTabBrowser1.RunScript('document.title', Json) then
      ShowMessage(Json);   // "Example Domain" (returned as a JSON string)
end;
```

### 9.5 Run JavaScript without waiting for the result

```pascal
procedure TForm1.btnLinksClick(Sender: TObject);
begin
  FScriptID := CTabBrowser1.RunScriptAsync(CTabBrowser1.ActiveIndex,
    'document.links.length', @LinksResult);
end;

procedure TForm1.LinksResult(Sender: TObject; AID: Integer;
  ASuccess: Boolean; const AResultJson: string);
begin
  if ASuccess then
    StatusBar1.SimpleText := 'Number of links: ' + AResultJson;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  CTabBrowser1.CancelScriptAsync(FScriptID);   // Cancel if the receiving side disappears first
end;
```

### 9.6 Save a page

```pascal
CTabBrowser1.SavePath := 'C:\Save';
CTabBrowser1.SavePDF;                                 // C:\Save\(title).pdf
CTabBrowser1.SaveScreenCapture;                       // C:\Save\(title).jpg
CTabBrowser1.SaveAsWebPage('C:\Save\page.mhtml');     // Whole page in one file
CTabBrowser1.SaveToFile('C:\Save\page.html');         // HTML source
```

### 9.7 Decide the download destination and notify when finished

```pascal
procedure TForm1.CTabBrowser1DownloadStarting(Sender: TObject; ATabIndex: Integer;
  const AURI: string; var AFileName: string; var ACancel: Boolean);
begin
  AFileName := 'C:\Download\' + ExtractFileName(AFileName);   // Change the destination folder
end;

procedure TForm1.CTabBrowser1DownloadCompleted(Sender: TObject; ATabIndex: Integer;
  const AFileName: string; ASuccess: Boolean);
begin
  if ASuccess then
    StatusBar1.SimpleText := 'Saved: ' + AFileName
  else
    StatusBar1.SimpleText := 'Download failed';
end;
```

### 9.8 Add an item that copies the URL of the right-clicked tab

1. Place a TPopupMenu on the form and create an item `mnuCopyURL` ("Copy URL").
2. Select that TPopupMenu in TCTabBrowser's `HeaderPopupMenu` and `PagePopupMenu`.
3. Write the following in the TPopupMenu's `OnPopup` and the item's `OnClick`.

```pascal
uses
  Clipbrd;

procedure TForm1.PopupMenu1Popup(Sender: TObject);
begin
  mnuCopyURL.Enabled := CTabBrowser1.ContextTabIndex >= 0;
end;

procedure TForm1.mnuCopyURLClick(Sender: TObject);
var
  i: Integer;
begin
  i := CTabBrowser1.ContextTabIndex;
  if i < 0 then Exit;   // The tab has already been closed
  Clipboard.AsText := CTabBrowser1.Panels[i].URL;
end;
```

### 9.9 Decide the page opened by right-click "New" and when the last tab is closed

```pascal
procedure TForm1.CTabBrowser1NewTabRequest(Sender: TObject;
  AReason: TTabNewTabReason; var AURL: string; var AAccept: Boolean);
begin
  AURL := 'https://www.google.com/';   // Write it in the same form as the URL shown after opening
end;
```

### 9.10 Create it in code

```pascal
uses
  uCTabBrowser;

procedure TForm1.FormCreate(Sender: TObject);
var
  B: TCTabBrowser;
begin
  B := TCTabBrowser.Create(Self);
  B.Parent := Self;
  B.Align := alClient;
  B.OnDocumentComplete := @CTabBrowser1DocumentComplete;   // Use the handler from 9.2
end;
```

### 9.11 Notify when WebView2 cannot be prepared

```pascal
procedure TForm1.FormShow(Sender: TObject);
begin
  try
    CTabBrowser1.Add('https://www.lazarus-ide.org/');
  except
    on E: Exception do
      ShowMessage('Cannot open the browser: ' + E.Message);
  end;
end;
```
