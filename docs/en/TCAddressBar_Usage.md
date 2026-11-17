# TCAddressBar User Manual

Author: aotan083
Date: 2026-11-17
Version: 1.0

---

## 1. Overview and Classes

A component that you can use just like the Windows Explorer address bar. It works just by connecting it to TCListView and TCTreeView.

```
[<-][->][^][Refresh]  [icon] PC > Local Disk (C:) > app >            [v]
   buttons              breadcrumbs (click to move; ">" lists the folders below)   history
```

- Breadcrumbs: click a name to move to that folder. Click the ">" to the right of a name to show the folders below that folder; choose one to move to it.
- Click an empty part of the breadcrumbs (or the icon) to type a path directly (input mode). Press `Enter` to move.
- Back, forward, up, and refresh buttons. The "v" at the right end shows the list of recent locations (history).
- When the width is not enough, the first parts are folded into "...". Click "..." to show the hidden parts.
- When the current folder changes, the breadcrumbs change automatically (also when you move to another folder in the list or the tree).

| Item | Contents |
|---|---|
| Lazarus | 4.8, 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Classes and Units

| Class | Unit | Package | Parent class | Contents |
|---|---|---|---|---|
| `TCAddressBar` | `uCAddressBar` | cx | `TCustomControl` | The Explorer address bar |

| Type | Unit | Contents |
|---|---|---|
| `TCABNavigatingEvent` | `uCAddressBar` | `procedure(Sender: TObject; const APath: string; var Allow: Boolean) of object`. The type of `OnNavigating` |
| `TCABNavigatedEvent` | `uCAddressBar` | `procedure(Sender: TObject; const APath: string) of object`. The type of `OnNavigated` |
| `TCABErrorEvent` | `uCAddressBar` | `procedure(Sender: TObject; const AMessage: string) of object`. The type of `OnError` |

- When placed on a form, `uCAddressBar` is added to uses automatically, and cx is added to the project's required packages automatically.
- When creating it in code, write it in uses yourself.

## 2. From Placing on a Form to Running

1. Place TCListView and TCTreeView on the form from the [CX] palette (`TCListView_Usage.md`, `TCTreeView_Usage.md`). Set the `ShellListView` of TCTreeView to the TCListView.
2. Place TCAddressBar on the form. It is placed at the top (`Align = alTop`).
3. Set the `ListView` of TCAddressBar to the TCListView and the `TreeView` to the TCTreeView.
4. Run the application. The breadcrumbs show the current folder.

- You can use just one of `ListView` and `TreeView`. However, back, forward, and history can be used only when `ListView` is set, because TCListView holds the history (buttons that cannot be used are grayed).
- If neither is set, only the folder moved to with `NavigateTo` is remembered and shown.
- When placing it on the same form as the search box (`TCSearchBox_Usage.md`), set the address bar to `alClient` and the search box to `alRight`, and put them side by side in one panel. The layout is then the same as in Explorer.

## 3. Operation

### 3.1 Mouse

| Operation | Action |
|---|---|
| Back / forward / up | Moves in the history or to the parent folder. When not available, the button is grayed and cannot be pressed |
| Refresh | Updates the list (or the tree if there is no list) to the latest information |
| A breadcrumb name | Moves to that folder. Clicking "PC" shows the list of drives |
| A breadcrumb ">" | Shows the folders below that folder. Choose one to move to it. The next part of the current breadcrumbs is shown in bold |
| "..." | Shows the hidden first parts |
| "v" | Shows the history list (newest first; the current folder is marked). Choose one to move there |
| The icon / an empty area | Enters input mode |

- The ">" list does not show folders with the hidden or system attribute. They are in name order (natural order, the same as Explorer), up to 300. If there are more, "..." appears at the end (it cannot be chosen).
- The ">" of a folder that cannot be read shows nothing.

### 3.2 Keys

| Key | Action |
|---|---|
| `Enter`, `F4`, `Ctrl+L`, `Alt+D` | Enters input mode |
| `Alt+Left`, `Alt+Right`, `Alt+Up` | Back, forward, up |
| `F5` | Refresh |
| `Tab` | Moves to the next control |

- `Ctrl+L` and `Alt+D` also work when the focus is on the TCListView or TCTreeView on the same form (input mode starts).

### 3.3 Input Mode

| Operation | Action |
|---|---|
| `Enter` | Moves to the path you typed. If it could move, input mode ends |
| `Esc` | Ends input mode (does not move) |
| Click elsewhere / the focus leaves | Ends input mode (does not move) |

The path you typed is tidied up as follows before it is used.

- Spaces at the start and end and `"` at the start and end are removed (`"C:\My Folder"` copied from Explorer can be used as it is).
- Environment variables such as `%USERPROFILE%` are expanded.
- `/` becomes `\`.
- `C:` alone becomes `C:\`. A trailing `\` is removed except for a drive root.
- If it does not exist as a folder, it does not move. `OnError` arrives (if it is not set, input mode continues). A path to a file is not accepted.

## 4. Properties

### 4.1 Added by This Component

| Name | Type | Access | Contents |
|---|---|---|---|
| `ListView` | `TCListView` | Read/Write | The list to work with |
| `TreeView` | `TCTreeView` | Read/Write | The tree to work with |
| `SyncTree` | `Boolean` | Read/Write | Whether `TreeView` also moves to the same folder when moving (default `True`) |
| `ShowNavButtons` | `Boolean` | Read/Write | Whether to show the back, forward, and up buttons (default `True`) |
| `ShowHistoryButton` | `Boolean` | Read/Write | Whether to show the history "v" button (default `True`) |
| `ShowRefreshButton` | `Boolean` | Read/Write | Whether to show the refresh button (default `True`) |
| `Path` | `string` | Read/Write | The current folder. Writing it moves to that folder (nothing happens if the folder does not exist). Run time only |
| `Editing` | `Boolean` | Read | `True` in input mode. Run time only |
| `Color` | `TColor` | Read/Write | The background color inside the input frame (default `clDefault`, the same as `clWindow`) |

- The current folder is the `Root` of `ListView` if there is one, otherwise the `Path` of `TreeView`, and if neither is set, the folder moved to with `NavigateTo`.
- When the list is in the search result view (`TCListView_Usage.md` 5.5), the breadcrumbs show the folder that was searched.

### 4.2 Inherited from the LCL

`Align` (default `alTop`), `Anchors`, `BorderSpacing`, `Constraints`, `Enabled`, `Font`, `ParentFont`, `PopupMenu`, `ShowHint`, `TabOrder`, `TabStop` (default `True`), `Visible`.

- The default height is 32 (at 96 dpi; it becomes larger with the display scale).

## 5. Methods

| Name | Parameters | Return value | Contents |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | - | Creates it. Use it when creating in code (8.2) |
| `NavigateTo` | `const APath: string` | `Boolean` | Moves to that folder. If there is a `ListView`, it moves with its `NavigateTo`, and if `SyncTree` is `True`, `TreeView` is also moved to the same folder. If there is only `TreeView` and no `ListView`, it moves with `TreeView.Path`. Returns `False` if the folder does not exist or `OnNavigating` refused. When it moved, `OnNavigated` fires |
| `BeginEdit` | - | - | Enters input mode (same as `Ctrl+L`) |
| `EndEdit` | `ACancel: Boolean` | - | Ends input mode. If `ACancel = False`, it tries to move using the text typed |
| `Refresh` | - | - | Refreshes (same as `F5`) |

## 6. Events

| Name | Parameters | Contents |
|---|---|---|
| `OnNavigating` | `Sender: TObject; const APath: string; var Allow: Boolean` | Before moving by an operation of this component (breadcrumbs, input, buttons, `NavigateTo`). `Allow := False` prevents the move |
| `OnNavigated` | `Sender: TObject; const APath: string` | After moving by an operation of this component. It does not fire when the move was made on the list or tree side (such as a double-click); learn of that with the `OnFolderChanged` of TCListView |
| `OnError` | `Sender: TObject; const AMessage: string` | When the path typed was not found or is not a folder. If it is not set, input mode continues |

## 7. Notes

- Windows only.
- Back, forward, and history can be used only when `ListView` is set.
- The drive names in the breadcrumbs ("Local Disk (C:)" and so on) are the names given by Windows.
- At design time, only a sample of breadcrumbs is shown. It cannot be operated.
- In input mode, the breadcrumbs are not rebuilt even if the "folder changed" notification arrives (so that what you are typing is not destroyed). When input mode ends, it matches the current folder.

## 8. Usage Examples

### 8.1 Show the Folder Moved To in the Form Title

```pascal
procedure TForm1.CAddressBar1Navigated(Sender: TObject; const APath: string);
begin
  Caption := APath;
end;
```

### 8.2 Create It in Code

```pascal
uses uCAddressBar, CListView, CTreeView;

var
  AB: TCAddressBar;
begin
  AB := TCAddressBar.Create(Self);
  AB.Parent := Self;
  AB.Align := alTop;
  AB.ListView := CListView1;
  AB.TreeView := CTreeView1;
end;
```

### 8.3 Do Not Allow Moving Above a Specific Folder

```pascal
procedure TForm1.CAddressBar1Navigating(Sender: TObject; const APath: string; var Allow: Boolean);
begin
  // Do not move outside C:\work
  Allow := SameText(Copy(APath, 1, Length('C:\work')), 'C:\work');
end;
```
