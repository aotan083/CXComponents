# TCTabBrowser User Manual

Author: aotan083
Date: 2026-11-24
Version: 1.5

---

**Operating environment**: Lazarus 5.0 or later (FPC 3.2.2). Lazarus 4.8 and earlier are not supported.

## 1. Overview and Classes

A tabbed Web browser built on WebView2 (the mechanism behind Microsoft Edge). Each tab shows a different Web page. You can save pages (HTML, MHTML, image, PDF), run JavaScript, receive downloads, and add items to the right-click menu.

```
+-----------+-----------+---+---------------------------+
| Google  × | GitHub  × | + |                       v |
+-----------+-----------+---+---------------------------+
|                                                      |
|   Web page of the visible tab                        |
|                                                      |
+------------------------------------------------------+
```

- The tab strip is drawn by the component itself (it is not the standard Windows tab control). Tabs are on a single row; when they do not fit, scroll with [◀] [▶]. [v] opens the tab list.
- The [×] on a tab header closes that tab. The [+] at the end adds a new tab.
- When `TitleBar` is set to a TCTitleBar, the tab strip is placed on the title bar (tabs and title bar become one row, like Firefox). The page appears where this component is placed. See 9.12 for usage.
- Tabs can be dragged to reorder them.
- **The default `SingleTab = True` is a single Web browser without tabs.** Setting `CTabBrowser1.SingleTab := False` makes it work as a **tabbed browser** (9.1 and 9.13).
- The number of tabs never becomes 0. When the last tab is closed, the component creates one new tab.
- When a page tries to open a new window, it is opened in a new tab instead of a window.
- It runs in a browser process separate from other WebView2s in the same application (such as TCMonacoEditor), so they do not freeze each other.
- The component prepares WebView2 by itself (nothing needs to be written in the application's .lpr).

| Item | Details |
|---|---|
| Lazarus | 5.0RC1 or later |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |
| Requirements to run | Microsoft Edge WebView2 Runtime (preinstalled on Windows 11), WebView2Loader.dll (64-bit version), WebView2.ini |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Contents |
|---|---|---|---|---|
| `TCTabBrowser` | `uCTabBrowser` | cx | `TCPageControl` | A tabbed Web browser using WebView2. Can save pages (HTML, MHTML, image, PDF), run JavaScript, receive downloads, and add items to the right-click menu |

| Type | Unit | Contents |
|---|---|---|
| `TCTabPanel` | `uCTabBrowser` | Tab information (obtained via `Panels[i]` and `ActiveTab`). 4.2 |
| `TTabNewTabReason` | `uCTabBrowser` | Reason the component creates a new tab. `ntrMenuNew` ([+] and "New" in the Web page's right-click menu), `ntrLastTabClosed` (the last tab was closed) |
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

1. From the [CX] palette, place TCTabBrowser on the form. To use it as a tabbed browser, set `SingleTab` to `False` in the Object Inspector (the default `True` is a single Web browser without tabs).
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
- A `%name%` written in a value is replaced. The name is looked up as a key of the same `[WebView2]` section, then as a Windows environment variable (example: write `CXROOT=C:\CX\runtime`, then `TerminalFolder=%CXROOT%\terminal`). A name that is not found is left as it is.
- It is read only once, on first use after startup. Changes made while running take effect from the next startup.

**Tab behavior**

| Behavior | Details |
|---|---|
| Tab header | Initially "Tab n". Once the page title is determined, it changes to the title |
| Hiding the tab strip | With `HideSingleTab = True` (default), the tab strip is hidden when there is one tab or fewer (when placed on a `TitleBar`, the tab strip inside the title bar disappears) |
| Fixed to one tab (`SingleTab = True`; the default) | The tab strip is always hidden. `Add`, `Insert` and a new window the page tries to open do not create a second tab, but open in the current tab. "New" and "Close" are not shown in the right-click menu of the Web page |
| [×] | Closes that tab (can be cancelled with `OnPageClose`) |
| [+] | The URL is decided via `OnNewTabRequest` (`AReason = ntrMenuNew`), and a new tab is created at the end and shown |
| Dragging a tab | Reorders the tabs. The page moves together with it |
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
| `HideSingleTab` | `Boolean` | Read/Write | If `True` (default), the tab strip is hidden when there is one tab or fewer (switched through `ShowTabs`) |
| `SingleTab` | `Boolean` | Read/Write | If `True` (default), it becomes a browser fixed to one page. Setting `False` makes it work as a tabbed browser (tab strip, several tabs, [+], and "New" and "Close" in the right-click menu). When `True`, The tab strip is always hidden, `Add` and `Insert` open in the current tab instead of creating a second one, and "New" and "Close" are not shown in the right-click menu of the page. To use several tabs, set it to `False` before adding the first tab (on a form, set it to `False` in the Object Inspector). If it is set to `True` while there are already several tabs, it only stops adding more; it does not remove them |
| `UserAgent` | `string` | Read/Write | Reading gives the User-Agent used by the visible tab (the configured value if there are no tabs). Writing sets it on all tabs and on tabs created later. '' means WebView2's default |
| `IgnoreCertificateErrors` | `Boolean` | Read/Write | If `True` (default), pages are displayed ignoring certificate errors. Applied to all tabs and tabs created later. For applications that display general sites on the Internet, consider setting it to `False` |
| `SavePath` | `string` | Read/Write | Destination folder when the file name is omitted in `SaveScreenCapture` and `SavePDF` (default is the current folder at the time the component was created) |
| `HeaderPopupMenu` | `TPopupMenu` | Read/Write | Items to add to the right-click menu of the tab header (chapter 6). Same as `TabPopupMenu` |
| `PagePopupMenu` | `TPopupMenu` | Read/Write | Items to add to the right-click menu of the Web page (chapter 6) |

### 3.2 Inherited from TCPageControl

| Name | Type | Read/Write | Contents |
|---|---|---|---|
| `ActivePage` | `TCTabSheet` | Read/Write | Page of the visible tab. Writing switches tabs (same effect as `ActiveIndex`). Use at run time |
| `Align` | `TAlign` | Read/Write | Placement inside the parent |
| `Anchors` | `TAnchors` | Read/Write | Which edges follow when the parent's size changes |
| `AnchorSideBottom` | `TAnchorSide` | Read/Write | Which control and edge the bottom edge is anchored to |
| `AnchorSideLeft` | `TAnchorSide` | Read/Write | Which control and edge the left edge is anchored to |
| `AnchorSideRight` | `TAnchorSide` | Read/Write | Which control and edge the right edge is anchored to |
| `AnchorSideTop` | `TAnchorSide` | Read/Write | Which control and edge the top edge is anchored to |
| `BiDiMode` | `TBiDiMode` | Read/Write | Whether to lay out right to left |
| `BorderSpacing` | `TControlBorderSpacing` | Read/Write | Margins around it |
| `Color` | `TColor` | Read/Write | Background color of the tab strip (when `TitleBar` is not set. Default `clBtnFace`) |
| `Constraints` | `TSizeConstraints` | Read/Write | Upper and lower limits of the size |
| `Cursor` | `TCursor` | Read/Write | Mouse cursor when over it |
| `DragCursor` | `TCursor` | Read/Write | Mouse cursor while dragging |
| `DragKind` | `TDragKind` | Read/Write | Kind of drag (drag and drop, or docking) |
| `DragMode` | `TDragMode` | Read/Write | Whether dragging starts automatically |
| `Enabled` | `Boolean` | Read/Write | Whether it is usable |
| `Font` | `TFont` | Read/Write | Text of the tab headers |
| `Height` | `Integer` | Read/Write | Height |
| `HelpContext` | `THelpContext` | Read/Write | Help number |
| `HelpKeyword` | `string` | Read/Write | Help keyword |
| `HelpType` | `THelpType` | Read/Write | Whether help is looked up by number (`htContext`) or by keyword (`htKeyword`) |
| `Hint` | `TTranslateString` | Read/Write | Hint text |
| `Images` | `TCustomImageList` | Read/Write | Tab icons (a TCImageList can also be used. The index is decided by `OnGetImageIndex`) |
| `ImagesWidth` | `Integer` | Read/Write | Icon width (px at 100% display scale). 0 (default) means the width of `Images` |
| `Left` | `Integer` | Read/Write | Left position |
| `Name` | `TComponentName` | Read/Write | Name of the component |
| `Options` | `TCTabControlOptions` | Read/Write | Tab settings (table below). Default is `[nboShowCloseButtons, nboShowAddTabButton]` |
| `ParentBiDiMode` | `Boolean` | Read/Write | Whether to use the parent's `BiDiMode` |
| `ParentColor` | `Boolean` | Read/Write | Whether to use the parent's color (default `False`) |
| `ParentFont` | `Boolean` | Read/Write | Whether to use the parent's `Font` |
| `ParentShowHint` | `Boolean` | Read/Write | Whether to use the parent's `ShowHint` |
| `PopupMenu` | `TPopupMenu` | Read/Write | Menu shown when an empty part of the page is right-clicked (not shown over the Web page, which WebView2 receives) |
| `ShowHint` | `Boolean` | Read/Write | Whether to show hints |
| `ShowTabListButton` | `Boolean` | Read/Write | Whether to show [v] (tab list) (default `True`) |
| `ShowTabs` | `Boolean` | Read/Write | Whether to show the tab strip (default `True`). Switched by `HideSingleTab`, so do not change it directly (8.1). Run time only |
| `TabHeight` | `Smallint` | Read/Write | Tab height. 0 (default) means automatic |
| `TabIndex` | `Integer` | Read/Write | Index of the visible tab (same effect as `ActiveIndex`) |
| `TabListPopupMenu` | `TPopupMenu` | Read/Write | Items to add on top of the tab list |
| `TabMaxWidth` | `Integer` | Read/Write | Maximum width when `TabWidth = 0` (default 240). Text that does not fit becomes "…" |
| `TabMenuItems` | `TCTabMenuItems` | Read/Write | Standard items in the right-click menu of the tab header. The default of this component is `[tmiClose]` (chapter 6) |
| `TabOrder` | `TTabOrder` | Read/Write | Order of moving with the Tab key |
| `TabPopupMenu` | `TPopupMenu` | Read/Write | Same as `HeaderPopupMenu` (8.1) |
| `TabPosition` | `TTabPosition` | Read/Write | Position of the tab strip. `tpTop` (default) or `tpBottom`. Not used when `TitleBar` is set |
| `TabShape` | `TCTabShape` | Read/Write | Tab shape. `tsRectangle` (default, square) or `tsRounded` |
| `TabStop` | `Boolean` | Read/Write | Whether the Tab key stops here |
| `TabWidth` | `Smallint` | Read/Write | Tab width. 0 (default) means fit to the text |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely |
| `TitleBar` | `TCTitleBar` | Read/Write | The title bar that holds the tab strip. If empty, the tab strip appears inside this component (9.12) |
| `Top` | `Integer` | Read/Write | Top position |
| `Visible` | `Boolean` | Read/Write | Whether to show it |
| `Width` | `Integer` | Read/Write | Width |

**Values of `Options`**

| Value | Contents |
|---|---|
| `nboShowCloseButtons` | Shows [×] on each tab |
| `nboShowAddTabButton` | Shows [+] |
| `nboKeyboardTabSwitch` | Switches with Ctrl+Tab and Ctrl+Shift+Tab (the keys do not arrive while the Web page has focus) |
| `nboDoChangeOnSetIndex` | Also raises `OnChanging` and `OnChange` when the visible tab is changed from code |
## 4. Methods and TCTabPanel

### 4.1 Methods

**Tabs**

| Name | Arguments | Return value | Contents |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | - | Creates it. Used when creating in code (9.10) |
| `Add` | `const AURL: string = 'about:blank'` | `Integer` | Adds a tab at the end, opens `AURL` and shows it. Returns the index of the added tab. Does not wait for loading. With `SingleTab = True` (default), if a tab already exists, no second tab is created and it opens in the current tab (the index returned is that of the current tab). To use it as a tabbed browser, set `SingleTab := False` |
| `Insert` | `i: Integer; const AURL: string = 'about:blank'` | `Integer` | Adds a tab at index `i`, opens `AURL` and shows it. `i` is clamped to 0 .. `Count`. Returns the index of the added tab. With `SingleTab = True`, if a tab already exists, the same as `Add` |
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

### 5.2 Inherited from TCPageControl

| Name | Arguments | Contents |
|---|---|---|
| `OnChange` | `Sender: TObject` | After the visible tab has changed |
| `OnChanging` | `Sender: TObject; var AllowChange: Boolean` | Before the visible tab changes. `AllowChange := False` cancels it |
| `OnContextPopup` | `Sender: TObject; MousePos: TPoint; var Handled: Boolean` | Just before a right-click menu is shown. `Handled := True` suppresses it |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | Dropped by an LCL drag (between controls inside the application) |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | The dragged object came over it during an LCL drag. `Accept` decides whether to accept |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | The LCL drag finished |
| `OnEnter` | `Sender: TObject` | Focus entered |
| `OnExit` | `Sender: TObject` | Focus left |
| `OnGetImageIndex` | `Sender: TObject; TabIndex: Integer; var ImageIndex: Integer` | Before a tab is drawn. You can set the icon index in `ImageIndex` (when `Images` is used) |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was pressed |
| `OnMouseEnter` | `Sender: TObject` | The mouse entered |
| `OnMouseLeave` | `Sender: TObject` | The mouse left |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | The mouse moved |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | A mouse button was released |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | The wheel was turned |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned toward you |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | The wheel was turned away from you |
| `OnPageClose` | `Sender: TObject; APage: TCTabSheet; var CanClose: Boolean` | Before a tab is closed with [×], the right-click "Close", or [×] in the tab list. `CanClose := False` cancels it |
| `OnPageMoved` | `Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer` | After a tab was moved by dragging |
| `OnResize` | `Sender: TObject` | The size changed |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | An LCL drag started |

- Mouse and key input over the Web page is received by WebView2, so these events are not raised.
- `OnNewPage` and `OnPageRename` are not used by this component ([+] raises `OnNewTabRequest`. 8.1).
## 6. Right-click Menus

| Where right-clicked | Menu shown |
|---|---|
| Tab header (on a tab) | "Close" → separator → items of `HeaderPopupMenu` |
| Tab header (where there is no tab) | Items of `HeaderPopupMenu` (nothing is shown if `HeaderPopupMenu` is not set) |
| Web page | WebView2's standard items (matching the place right-clicked) → separator → "New", "Close" → separator → items of `PagePopupMenu` |

- "Close" closes the tab that was right-clicked (can be cancelled with `OnPageClose`). "New" adds a new tab at the end and shows it (the URL is decided by `OnNewTabRequest`).
- With `SingleTab = True`, "New" and "Close" are not shown in the right-click menu of the Web page (only the items of `PagePopupMenu` follow WebView2's standard items).
- The standard items on the tab header are decided by `TabMenuItems` (default `[tmiClose]`). Adding `tmiNew` shows "New tab" (same as [+]). Do not add `tmiRename` (the tab name is decided by the page title).
- When `HeaderPopupMenu` and `PagePopupMenu` are not set, the application's items and the separator before them are not shown.
- The same TPopupMenu can be set on both.
- Just before the menu is shown, the TPopupMenu's `OnPopup` is called. Adjust item enabled state and checks inside `OnPopup`.
- Selecting a copied item calls the original item's `Click` (`OnClick`, `Action` and `AutoCheck` work as usual). Items of `PagePopupMenu` are executed after the menu closes.

**How items of the application's TPopupMenu are copied**

| Original item | After copying |
|---|---|
| `Visible = False` | Not shown |
| `Caption = '-'` | Separator |
| `Caption` | As is (including the & access key) |
| `Enabled` | As is |
| `Checked` | As is (becomes a checkable item) |
| Has child items | Becomes a submenu, and the child items are copied by the same rules |
| Icon (`ImageIndex`) | `HeaderPopupMenu`: shown using that TPopupMenu's `Images`. `PagePopupMenu`: not shown |
| Shortcut key | `HeaderPopupMenu`: shown. `PagePopupMenu`: not shown |

**The right-clicked tab (`ContextTabIndex`)**

| When | Value stored |
|---|---|
| A tab header was right-clicked | That tab's index (-1 where there is no tab) |
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
| `TabPopupMenu` | Same as `HeaderPopupMenu`. To add items, use `HeaderPopupMenu` |
| `ShowTabs` | Switched by the component through `HideSingleTab` and `SingleTab`. To hide the tab strip, use one of them |
| `NewPageCaption`, `OnNewPage` | [+] creates a tab with WebView2 instead of an empty page (the URL is decided by `OnNewTabRequest`), so these are not used |
| `OnPageRename`, `tmiRename` | The tab name is decided by the page title, so these are not used |

### 8.2 Other

- Windows only.
- Do not add or remove tabs (`TCTabSheet`) by any method other than `Add`, `Insert` and `Remove` (the IDE's "Add page", `TCTabSheet.Create`, etc.). They become tabs without a browser.
- With an old WebView2 runtime, "New", "Close" and the application's items do not appear in the Web page's right-click menu, only WebView2's standard items.
- While the Web page has focus, keys (except F5) do not reach the application. The form's `OnKeyDown` and ActionList shortcuts do not work.
- In the IDE (design time), neither tabs nor browsers are created. Only an empty frame appears.
- Even when the component's window is recreated, for example by docking or undocking with AnchorDocking, every tab keeps showing the page that was open.
- The tab strip is drawn by the component itself. Colors use system colors (`clBtnFace`, `clWindow`, etc.), so they follow a mechanism that makes the whole application dark (MetaDarkStyle).
## 9. Usage Examples

### 9.1 Open the first tab at startup

When using it as a tabbed browser, set `SingleTab := False` (on a form, set it to `False` in the Object Inspector).

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

### 9.9 Decide the page opened by [+], right-click "New" and when the last tab is closed

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

### 9.12 Place the tab strip on the title bar

1. Place a TCTitleBar on the form (it automatically gets `Align = alTop`).
2. Place the TCTabBrowser where the pages should appear (`Align = alClient`, etc.).
3. Set the TCTabBrowser's `TitleBar` to that TCTitleBar. The tab strip moves into the title bar, and the page stays where the TCTabBrowser is.

```pascal
uses
  uCTabBrowser, uCTitleBar;

procedure TForm1.FormCreate(Sender: TObject);
begin
  CTabBrowser1.Align := alClient;
  CTabBrowser1.TitleBar := CTitleBar1;   // can also be chosen in the IDE
end;
```

- To place buttons or other controls on the left or right of the tab strip, put them inside the TCTitleBar with `Align = alLeft` or `alRight`. The tab strip fits into the remaining width between them.
- If the tab strip disappearing while there is one tab (`HideSingleTab = True`) is a problem, set `HideSingleTab := False`.

### 9.13 Use it as a single-page Web browser, or as a tabbed browser (SingleTab)

The default of `SingleTab` is `True` (a single Web browser without tabs). **To use it as a tabbed browser, set `SingleTab := False`** (the examples that call `Add` several times, such as 9.1, assume `False`).

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  CTabBrowser1.Align := alClient;
  // SingleTab stays at its default, True (fixed to one tab)
  CTabBrowser1.Add('https://www.lazarus-ide.org/');   // the first (and only) one
end;

procedure TForm1.btnGoClick(Sender: TObject);
begin
  CTabBrowser1.Navigate(Edit1.Text);   // opens in the current tab (the same as Add)
end;
```

- The tab strip is not shown. `Add`, `Insert` and a new window the page tries to open all open in the current tab.
- "New" and "Close" are not shown in the right-click menu of the Web page.
- Go back, forward and reload with `Back`, `Next` and `Reload` (9.3).
- To make it a tabbed browser, write `CTabBrowser1.SingleTab := False;` (on a form, set `SingleTab` to `False`). Then the tab strip, [+], [×], and "New" and "Close" in the right-click menu become available.
