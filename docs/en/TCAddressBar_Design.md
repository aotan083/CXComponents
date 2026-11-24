# TCAddressBar Design Document

Author: aotan083
Date: 2026-11-17
Version: 1.0

---

**Operating environment**: Lazarus 5.0 or later (FPC 3.2.2). Lazarus 4.8 and earlier are not supported.

## 1. Purpose and Policy

- A component equivalent to the Windows Explorer address bar (back, forward, up, breadcrumbs, path input, history, refresh). It works together with TCListView and TCTreeView.
- The search box is a separate component (`TCSearchBox`; `TCSearchBox_Design.md`). The unit is separate too (`uCAddressBar.pas`).
- A component drawn with the LCL (WebView2 is not used). It inherits from `TCustomControl`.
- All processing that moves to another folder is left to `NavigateTo` of TCListView (history, monitoring of changes, and working with the tree are held by TCListView). This component handles only display and input.

### 1.1 Not Included

- Completion of path input (later).
- Adding to favorites, drag & drop of paths.
- Typing the path of a file to open it (only folders can be typed).
- Using back, forward, and history without TCListView (with only TCTreeView, back, forward, and history cannot be used; up, breadcrumbs, and input can).
- Linux / macOS (Windows 11 only).

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCAddressBar.pas` | cx (run time) | `TCAddressBar`, the function `CABSplitPath` that splits a path, and the function `CABNormalizeInput` that tidies typed text |
| `uCXReg.pas` (`source\design`) | cxdsgn (design time) | Registration in the [CX] palette (`TCAddressBar`, `TCSearchBox`, `TCFindFile`) |
| `cnavigation_icon.lrs` (`source\res`) | cxdsgn (design time) | Icons (three: `TCAddressBar`, `TCSearchBox`, `TCFindFile`, each with `_150` and `_200`) |
| `uCXLang.pas` | cx (run time) | Strings are added (Chapter 6) |
| `uCListView` (`CListView.pas`) | cx (run time) | What is added to `TCListView` (`TCSearchBox_Design.md` Chapter 7; taking out the history) |

- uses of `uCAddressBar`: `Classes, SysUtils, Types, Math, Windows, Controls, Graphics, Forms, Menus, StdCtrls, ExtCtrls, LCLType, LCLIntf, LMessages, uCXLang, uCTitleBar (CXSetSymbolFont, CXBlendColor), CListView, CTreeView`.
- No initialization or finalization.
- The packages remain two: cx and cxdsgn.

## 3. How It Works Together

```
TCTreeView ---- Path ----+
                         +- TCAddressBar -- display (breadcrumbs), input, buttons
TCListView -- Root, history -+
```

| Item | How it is decided |
|---|---|
| Connection | `ListView: TCListView`, `TreeView: TCTreeView` (chosen in the Object Inspector; `FreeNotification`). One of them, or both |
| The current folder (`Path`) | `ListView.Root` if there is a `ListView`, otherwise `TreeView.Path`, and if neither, `FPath` held by this component |
| How a change is learned | No timer is used. TCListView and TCTreeView notify it when the folder changes (3.1). When the notification arrives, the current folder is compared with the folder being displayed (`FShownPath`), and if it differs, the breadcrumbs are rebuilt and redrawn |
| Moving | `ListView.NavigateTo(path)` if there is a `ListView`. If there is a `TreeView` and `SyncTree = True`, then `TreeView.Path := path` (the tree is moved to the same folder). If there is only `TreeView` and no `ListView`, `TreeView.Path := path` |
| Back, forward, up | `ListView.GoBack`, `GoForward`, `NavigateUp`. Whether they can be used is decided by `CanGoBack`, `CanGoForward`. Up is decided by whether there is a parent folder (it cannot be used at a drive root) |
| Refresh | `ListView.UpdateView` (a procedure of TShellListView). `TreeView.Refresh` if there is no `ListView` |
| History | The history of `ListView` (`MaxHistory`) is read and moved with `GetHistory` and `GoToHistory` (`TCSearchBox_Design.md` Chapter 7) |
| While the search result view is shown | While `ListView.ResultsMode` is true, the breadcrumbs show the folder that was searched (`ListView.Root`). Refresh does nothing, without rebuilding the search results |

### 3.1 Additions to TCListView and TCTreeView

An entry point for the "folder changed notification" is added to the two components whose behavior has been verified (only added; the current behavior is not changed). The user's `OnFolderChanged` and `OnChange` are not overwritten.

| Item | Now | After the change | Reason for the change | Risk |
|---|---|---|---|---|
| TCListView | Only `OnFolderChanged` (the user's event) | Add `AddFolderLink(AEvent: TNotifyEvent)` and `RemoveFolderLink(AEvent)`. In `NotifyFolderChanged` (the single place that now calls `OnFolderChanged`), call the registered receivers in turn after `OnFolderChanged` | So that components can work together without taking the user's event (so that monitoring with a timer can be dropped) | Only added. If nothing is registered, behavior is the same as now |
| TCTreeView | Only `OnChange` (the standard one of TTreeView) | Add the same `AddFolderLink` and `RemoveFolderLink`. Move the body of `DoSelectionChanged` to `DoSelectionChangedCore`, and have `DoSelectionChanged` call it and then call the receivers (when the selection changes) | Same as above | Same as above |

- A receiver must always call `RemoveFolderLink` when the component is destroyed (together with `FreeNotification`).
- Notification is given only when the folder of the normal view changes (`NavigateTo`, back, forward, selecting in the tree, double-click). It is not given when only the contents of the folder change (adding or deleting a file).
- The "search result view ended" notification of `TCSearchBox` also uses the same entry point (`NotifyFolderChanged` from `EndResults`). This also makes the timer in 4.2 of `TCSearchBox_Design.md` unnecessary.

## 4. TCAddressBar

`TCAddressBar = class(TCustomControl)`. Unit `uCAddressBar`.

### 4.1 Types and Constants

```pascal
type
  TCABNavigatingEvent = procedure(Sender: TObject; const APath: string; var Allow: Boolean) of object;
  TCABNavigatedEvent = procedure(Sender: TObject; const APath: string) of object;
  TCABErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;
```

| Constant | Value | Contents |
|---|---|---|
| `cMaxPopupItems` | 300 | The maximum number of folders shown in a ">" list |
| `cHeight96` | 32 | The default height (96 dpi) |

### 4.2 Properties

| Name | Type | Default | Exposure | Contents |
|---|---|---|---|---|
| `ListView` | `TCListView` | nil | published | The list to work with (Chapter 3) |
| `TreeView` | `TCTreeView` | nil | published | The tree to work with (Chapter 3) |
| `SyncTree` | `Boolean` | `True` | published | Whether `TreeView` is moved to the same folder when moving |
| `ShowNavButtons` | `Boolean` | `True` | published | Whether to show the back, forward, and up buttons |
| `ShowHistoryButton` | `Boolean` | `True` | published | Whether to show the "v" button for recent locations (history) |
| `ShowRefreshButton` | `Boolean` | `True` | published | Whether to show the refresh button |
| `Path` | `string` | '' | public (read/write) | The current folder. Writing it moves to that folder (nothing happens if it does not exist). Run time only |
| `Editing` | `Boolean` | - | public (read) | Whether in input mode |
| `Color` | `TColor` | `clDefault` | published | The background color inside the input frame. `clWindow` if `clDefault` |
| `Font` | `TFont` | same as the parent | published | The text. Also `ParentFont` |
| `Align` | `TAlign` | `alTop` | published | Alignment |
| `Height` | `Integer` | 32 | published | The height (`cHeight96` enlarged by the display scale) |
| `Anchors`, `BorderSpacing`, `Constraints`, `Enabled`, `PopupMenu`, `ShowHint`, `TabOrder`, `TabStop`, `Visible` | | | published | LCL standard. The default of `TabStop` is `True` |

### 4.3 Methods

| Method | Contents |
|---|---|
| `function NavigateTo(const APath: string): Boolean` | "Moving" in Chapter 3. `False` if `OnNavigating` refuses or the folder does not exist. `OnNavigated` when moved |
| `procedure BeginEdit` | Enters input mode (5.4) |
| `procedure EndEdit(ACancel: Boolean)` | Ends input mode. If `ACancel = False`, it tries to move using the text typed |
| `procedure Refresh` | "Refresh" in Chapter 3 |

### 4.4 Events

| Event | When |
|---|---|
| `OnNavigating(Sender, APath, var Allow)` | Before moving by an operation of this component (breadcrumbs, input, buttons, list). `Allow := False` cancels |
| `OnNavigated(Sender, APath)` | After moving by an operation of this component. It does not fire when the move was made by an operation of `ListView` (such as a double-click) |
| `OnError(Sender, AMessage)` | When the path typed was not found or is not a folder. If not set, input mode continues |

### 4.5 Declarations (private, protected)

```pascal
TCAddressBar = class(TCustomControl)
private
  FListView: TCListView;
  FTreeView: TCTreeView;
  FSyncTree, FShowNav, FShowHistory, FShowRefresh: Boolean;
  FPath: string;                       { the current folder when there is no ListView or TreeView }
  FShownPath: string;                  { the folder of the breadcrumbs being displayed }
  FSegs: array of TCABSeg;             { the parts of the breadcrumbs (5.2) }
  FFirstVisible: Integer;              { the first part shown (the ones before it are folded into "...") }
  FHot: TCABHit;                       { where the mouse is (5.3) }
  FDown: TCABHit;                      { where it is pressed }
  FEdit: TEdit;                        { the input field of input mode; created only in input mode }
  procedure FolderLinkChanged(Sender: TObject);   { the "folder changed" notification from ListView and TreeView (3.1) }
  FErrorText: string;
  FKeyHandlerAdded: Boolean;
  procedure PlaceEdit;                 { puts the input field where the breadcrumbs are (the height is the natural height of the input field; centered vertically) }
  ...
protected
  procedure Paint; override;
  procedure Resize; override;
  procedure MouseDown / MouseMove / MouseUp / MouseLeave; override;
  procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  procedure DoEnter; override;
  procedure DoExit; override;
  procedure CMEnabledChanged, CMFontChanged, CMColorChanged; message ...
  procedure WMGetDlgCode; message LM_GETDLGCODE;       { this component receives the arrow keys and Enter }
  procedure Notification(AComponent: TComponent; Operation: TOperation); override;
public
  constructor Create(TheOwner: TComponent); override;
  destructor Destroy; override;
  ...(the methods of 4.3)
end;
```

## 5. Processing

### 5.1 Layout (Left to Right)

```
[<-][->][^][Refresh]  [icon][breadcrumbs ...........][v]
    buttons             input frame (clWindow, 1px clBtnShadow frame)
```

| Part | Width | Contents |
|---|---|---|
| Back, forward, up, refresh | `Scale96ToFont(32)` each (nearly square) | The glyphs are from Segoe MDL2 Assets (`CXSetSymbolFont`). Back `U+E72B`, forward `U+E72A`, up `U+E74A`, refresh `U+E72C` |
| Input frame | All the rest | On the left, the icon of the current folder (small icon of `SHGetFileInfo`), and to its right the breadcrumbs. At the right end of the frame, "v" (`U+E70D`; recent locations) with a width of `Scale96ToFont(32)` |
| Input mode | Inside the input frame | `FEdit` (without a frame) is shown instead of the breadcrumbs |

- Each button is not shown if `ShowNavButtons`, `ShowHistoryButton`, or `ShowRefreshButton` is false (the frame widens accordingly).
- Vertically, the buttons and the frame are placed in the center of `Height` (a margin of `Scale96ToFont(3)` above and below).

### 5.2 Breadcrumbs

**Splitting a path (`CABSplitPath(APath, AList)`; a function of the unit)**

The full path of each part is put into `AList`, from the first part in order (`Objects` is not used).

| Input | Result |
|---|---|
| '' | `''` (only one, "PC"; the path is empty) |
| `C:\` | `''`, `C:\` |
| `C:\app\laz` | `''`, `C:\`, `C:\app`, `C:\app\laz` |
| `\\server\share\x` | `''`, `\\server`, `\\server\share`, `\\server\share\x` |
| A trailing `\` | Ignored (`C:\app\` is the same as `C:\app`; only the drive root `C:\` keeps it) |

**Display names**

| Part | Name |
|---|---|
| `''` | "PC" (`CXT(sAddrPC)`) |
| A drive root (`C:\`) | The name from `SHGetFileInfoW(SHGFI_DISPLAYNAME)` ("Local Disk (C:)" and so on). `C:` if it cannot be obtained |
| `\\server` | `\\server` |
| Other folders | `ExtractFileName` |

**Fitting into the width**

1. The width of each part = the width of the name + margins on both sides (`Scale96ToFont(8)`). Between parts a ">" (`U+E76C`; width `Scale96ToFont(20)`) is placed. A ">" is also placed after the last part (to show the list of folders below it).
2. If everything fits in the width inside the frame (excluding the icon, "v", and refresh), everything is shown.
3. If it does not fit, only the parts that fit, counting from the back (right), are shown, and the earlier parts are folded into one "..." (width `Scale96ToFont(28)`) (`FFirstVisible`).
4. The last part is always shown even if it does not fit (if it does not fit entirely, the right side is cut).

### 5.3 Mouse and Keys (in Breadcrumb Mode)

`FHot` and `FDown` are the kind and number of a place that can be pressed or hovered (`TCABHit`: none / back / forward / up / the name of a part (number) / the ">" of a part (number) / "..." / icon / "v" / refresh / empty area of the frame).

| Operation | Action |
|---|---|
| Hover | That place is painted a little lighter (`CXBlendColor(background, clWindowText, 12)`). 20% while pressed |
| Back, forward, up | On release, if over the same place, it moves as described in Chapter 3. When it cannot be used, it is gray (`clGrayText`) and cannot be pressed |
| The name of a part | On release, if over the same place, moves to the folder of that part. "PC" (the empty path) does not move but shows the list of drives (the same form as the ">" below) |
| The ">" of a part | On release, shows the list of folders below that folder (`TPopupMenu`) under that place. The folder of the next part is marked (`Checked`, bold). Moves to the folder chosen |
| "..." | Shows the list of the hidden earlier parts. Moves to the part chosen |
| "v" | Shows the history list (`GetHistory`; newest first; the position returned by `GetHistory` is marked). Choosing one calls `GoToHistory` |
| Refresh | "Refresh" in Chapter 3 |
| Icon, empty area of the frame | Enters input mode |
| Right-click | Does nothing (shows the `PopupMenu` if there is one) |

**The ">" list**

| Item | Contents |
|---|---|
| Contents | Only the folders below that folder. Items with the hidden or system attribute are not shown. In name order (`StrCmpLogicalW`). Up to `cMaxPopupItems`. If there are more, "..." (cannot be chosen) is added at the end |
| Below "PC" | Fixed drives, network drives, and removable drives (`GetLogicalDrives`). The names are the same as "A drive root" in 5.2 |
| A folder that cannot be read | An empty list (no menu is shown) |
| How it is obtained | Read on the spot with `FindFirstFileW` (with the same long path support as TCListView). The list is built every time it is shown (it is not remembered) |

**Keys (when this component has the focus)**

| Key | Action |
|---|---|
| `Enter`, `F4`, `Ctrl+L`, `Alt+D` | Enters input mode |
| `Alt+Left`, `Alt+Right`, `Alt+Up` | Back, forward, up |
| `F5` | Refresh |
| `Tab` | To the next control |

**The keys that enter input mode are also received from the list and the tree**

- At run time, they are received with `Application.AddOnKeyDownHandler` (the same as TCSideBar; only keys that the form's `KeyPreview`, the focused control, and menus did not use arrive). When `Ctrl+L` or `Alt+D` is pressed and the focus is on this component or on the `ListView` or `TreeView` of the same form, `BeginEdit` (`Key := 0`).
- Only when this component is `Enabled` and visible.

### 5.4 Input Mode

1. `BeginEdit`: `FEdit := TEdit.Create` (`Parent := Self`, `BorderStyle := bsNone`). Its position is where the breadcrumbs are (from the right of the icon to the left of "v"). The text is the full path of the current folder (empty for '' / "PC"). Everything is selected and the focus is moved. `FErrorText := ''`.
2. `Enter`: tidy with `CABNormalizeInput`, then `NavigateTo`. If it could move, input mode ends. If not found, `OnError` (4.4). Input mode continues.
3. `Esc`: ends input mode (does not move).
4. The input field loses the focus (click, another window): ends input mode (does not move). However, if an `OnError` message is being shown, the message is cleared.
5. Ending input mode: destroy `FEdit`, redraw the breadcrumbs, and return the focus to this component.
6. While in input mode, the breadcrumbs are not rebuilt even if the notification (`FolderLinkChanged`) arrives (so as not to destroy the input field).

**Tidying typed text (`CABNormalizeInput(const S: string; out APath: string): Boolean`)**

| Step | Processing |
|---|---|
| 1 | Remove spaces at the start and end. `False` if empty |
| 2 | Remove `"` at the start and end |
| 3 | Expand `%USERPROFILE%` and similar with `ExpandEnvironmentStringsW` |
| 4 | Change `/` to `\` |
| 5 | If it is only `C:`, make it `C:\`. Remove a trailing `\` except for a drive root |
| 6 | If `DirectoryExists` (long path aware) is true, put it in `APath` and return `True`. Otherwise `False` |

### 5.5 Drawing (`Paint`)

1. Paint everything with the parent's background (`clBtnFace`).
2. Draw the navigation buttons (5.1). Those that cannot be used (`Enabled` is false, no history, cannot go up from the root) are `clGrayText`.
3. Paint the input frame with `Color` (`clWindow` if `clDefault`) and draw a 1px `clBtnShadow` frame. In input mode, the frame is `clHighlight` (when it is too dark, the accent blue, in the same way as `CXSplitLineColor`).
4. Draw the icon, the breadcrumbs (names, ">", "..."), "v", and refresh. The places being hovered or pressed are painted with the colors in 5.3.
5. If `FErrorText` exists, in breadcrumb mode it is shown right-aligned inside the frame in red (`clRed`).
6. When disabled (`Enabled = False`), the text is `clGrayText` and no operation is accepted.

### 5.6 Creating and Destroying

- `Create`: add `csOpaque` to `ControlStyle`. Set the defaults of 4.2, such as `Align := alTop`, `TabStop := True`, `SyncTree := True`. At run time, if there is an `Application`, `AddOnKeyDownHandler`. When `ListView` and `TreeView` are set (and when they change), `AddFolderLink(@FolderLinkChanged)` (`RemoveFolderLink` when removing).
- `Destroy`: `RemoveOnKeyDownHandler`. Remove `FreeNotification` of `ListView` and `TreeView`.
- `Notification`: when `ListView` or `TreeView` is destroyed, set it to nil and redraw.
- The default height is decided in `Create` to fit the display scale (`CXScale96`).

## 6. Strings (Added to `uCXLang`)

| ID | Japanese | English |
|---|---|---|
| `sAddrBack` | 戻る | Back |
| `sAddrForward` | 進む | Forward |
| `sAddrUp` | 上へ | Up |
| `sAddrRefresh` | 最新の情報に更新 | Refresh |
| `sAddrRecent` | 最近の場所 | Recent locations |
| `sAddrPC` | PC | PC |
| `sAddrErrNotFound` | フォルダーが見つかりません：%s | The folder was not found: %s |

They are added at the end of the existing order (both in `TCXStr` and in `CXTable`). The hints (back, forward, up, refresh, recent locations) are shown over each button (when `ShowHint` is true).

## 7. Design Time

- When placed, the frame and a sample of breadcrumbs (`PC > C: > app`; the buttons are gray) are shown. Actual folders are not read at design time.
- With `Align = alTop`, it is placed at the top of the form.
- It appears in the [CX] palette (the icon is in `cnavigation_icon.lrs`).

## 8. Decisions

| Item | Decision |
|---|---|
| Moving | All through `ListView.NavigateTo` (history, monitoring, and working with the tree are left to TCListView). `TreeView.Path` if there is no `ListView` |
| How the current folder is learned | No timer. Updated by the "folder changed notification" of TCListView and TCTreeView (3.1) (existing events are not overwritten) |
| What can be typed | Only folders. Paths of files are not accepted |
| Completion | Not made (later) |
| Back, forward, history | Can be used only when there is a `ListView` (because TCListView holds the history) |
| While the search result view is shown | The breadcrumbs show the folder that was searched. Refresh does nothing |
| Icon glyphs | Segoe MDL2 Assets (`CXSetSymbolFont`, the same as TCTitleBar and TCPageControl) |
| Colors | `clBtnFace`, `clWindow`, `clBtnShadow`, `clGrayText`, `CXBlendColor`. Dark and light are left to system colors (MetaDarkStyle and so on) |
| Virtual folders | Only "PC". Groups such as Quick access, OneDrive, and Network have no path, so they are not shown in the breadcrumbs |
| Language | `CXT` of `uCXLang` (Japanese, English) |
| Design time | Only a sample is drawn. Reading is not run |

## 9. Where to Look When Investigating Problems

| Symptom | Where to look |
|---|---|
| The breadcrumbs stay old after moving | Registration of the notification (3.1). How `FShownPath` is compared with the current folder; they are not rebuilt in input mode (6 of 5.4) |
| The ">" list does not appear | Folders that cannot be read (5.3). Long paths of `FindFirstFileW` |
| Back and forward stay gray | Whether `ListView` is chosen. `CanGoBack`, `CanGoForward` |
| `Ctrl+L` does not work | `AddOnKeyDownHandler` (5.3). Whether a menu or ActionList uses the same key |
| Typing and pressing `Enter` does not move | `CABNormalizeInput` (5.4). A folder that does not exist, environment variables |
| The tree does not change when moving in the list | `SyncTree`. Only moves from the address bar are covered (moves in the list are not changed by the address bar) |
| The breadcrumbs look strange while the search result view is shown | "While the search result view is shown" in Chapter 3 |

## 10. Changes in This Version (1.0; New)

A new component, TCAddressBar, is made. The behavior of existing components is not changed (however, there are additions to `CListView.pas`; `TCSearchBox_Design.md` Chapter 7).

| File | Change |
|---|---|
| `source/uCAddressBar.pas` | New |
| `source/CTreeView.pas` | `AddFolderLink`, `RemoveFolderLink` (3.1) |
| `source/CListView.pas` | Added: `AddFolderLink`, `RemoveFolderLink` (3.1), `GetHistory`, `GoToHistory` (`TCSearchBox_Design.md` 7.3), and the search result view (`TCSearchBox_Design.md` Chapter 7) |
| `source/design/uCXReg.pas` | Registers the three components and loads `cnavigation_icon.lrs` |
| `source/res/cnavigation_icon.lrs` | New |
| `source/uCXLang.pas` | Strings are added (Chapter 6; also those of `TCSearchBox_Design.md`) |
