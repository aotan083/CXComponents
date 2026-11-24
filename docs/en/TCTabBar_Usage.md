# TCTabBar User Manual

Author: aotan083
Date: 2026-11-24
Version: 1.0

---

**Operating environment**: Lazarus 5.0 or later (FPC 3.2.2). Lazarus 4.8 and earlier are not supported.

## 1. Overview and Classes

A component that is only a tab strip, without pages. Use it when the application switches the screen itself, like the tabs of an editor. The tab strip is the same as that of TCPageControl (drawn by itself), so it has [×], [+], scrolling, reordering by dragging, placement on the title bar, and dark display.

```
+----------+-------------+-------------+---+
| main.pas | util.pas ●  | readme.md × | + |
+----------+-------------+-------------+---+
```

- One tab = one TCTabSheet. It holds the title, icon, hint, modified state, per-tab colors and an application value (`Tag`).
- [×] and [+] do nothing by themselves. They only notify the application, which decides when to add or remove tabs.
- Tabs can be reordered by dragging. When released outside the tab strip, the application is notified (usable to move a tab to another tab strip or out of the application).
- A line can be shown above (or below) the visible tab. A modified tab can show "●" in the place of [×]. Colors are set with properties.
- The height automatically fits the tab strip.
- When `TitleBar` is set to a TCTitleBar, the tab strip is placed on the title bar.

| Item | Details |
|---|---|
| Lazarus | 5.0RC1 or later |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Contents |
|---|---|---|---|---|
| `TCTabBar` | `uCPageControl` | cx | `TCPageControl` | A component that is only a tab strip |
| `TCTabSheet` | `uCPageControl` | cx | `TCustomControl` | One tab (3.3). Obtained with `TCTabBar.Tabs[i]` |

| Type | Unit | Contents |
|---|---|---|
| `TCTabIndexEvent` | `uCPageControl` | `procedure(Sender: TObject; AIndex: Integer) of object`. Type of `OnTabClick` |
| `TCTabDragOutEvent` | `uCPageControl` | `procedure(Sender: TObject; AIndex: Integer; const AScreenPos: TPoint; ATarget: TControl) of object`. Type of `OnTabDragOut` |
| `TCPageCloseEvent` | `uCPageControl` | `procedure(Sender: TObject; APage: TCTabSheet; var CanClose: Boolean) of object`. Type of `OnPageClose` |
| `TCPageMovedEvent` | `uCPageControl` | `procedure(Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer) of object`. Type of `OnPageMoved` |

- When placed on a form, `uCPageControl` is automatically added to uses.
- When placed on a form, cx is automatically added to the project's required packages.
- When creating it in code, write it in uses yourself.

## 2. From Placing on a Form to Running

1. Place a TCTabBar from the [CX] palette on the form (it automatically gets `Align = alTop`).
2. At run time, add tabs with `AddTab` (9.1).
3. Write the switching done when a tab is pressed in `OnTabClick` (9.2).
4. When closing, confirm in `OnPageClose`, set `CanClose := False`, and close it yourself (9.3).
5. When creating a new tab with [+], write it in `OnTabPlusClick` (9.1).

- Switching the screen (the body or editor to show) is done by the application. TCTabBar has no pages.
- Whether [+] and [×] are shown is decided by `Options`.

## 3. Properties

### 3.1 Added by this component

| Name | Type | Read/Write | Contents |
|---|---|---|---|
| `TabCount` | `Integer` | Read | Number of tabs. Run time only |
| `Tabs[AIndex]` | `TCTabSheet` | Read | The tab of that index (3.3). Run time only |

### 3.2 Inherited from TCPageControl

Same as 3.1 of the TCPageControl user manual. Only the ones with a different default and the frequently used ones are listed here.

| Name | Type | Read/Write | Contents |
|---|---|---|---|
| `Align` | `TAlign` | Read/Write | Default is `alTop` |
| `Options` | `TCTabControlOptions` | Read/Write | Default is `[nboShowCloseButtons, nboShowAddTabButton]`. `nboShowCloseButtons` = [×] on each tab (and closing with the middle button), `nboShowAddTabButton` = [+] |
| `ShowTabListButton` | `Boolean` | Read/Write | Whether to show [∨] (tab list). Default is `False` |
| `TabStop` | `Boolean` | Read/Write | Default is `False` (does not receive keyboard focus) |
| `TabIndex` | `Integer` | Read/Write | Index of the visible tab. Writing does not raise `OnTabClick` |
| `Color` | `TColor` | Read/Write | Background color of the tab strip |
| `Font` | `TFont` | Read/Write | Text of the tabs. The tab height does not change with the text (`TabHeight`; if 0, 28 enlarged by the display scale) |
| `Images`, `ImagesWidth` | `TCustomImageList`, `Integer` | Read/Write | Tab icons (a TCImageList can also be used). The index is `TCTabSheet.ImageIndex` (or `OnGetImageIndex`) |
| `TabHeight`, `TabWidth`, `TabMaxWidth`, `TabShape` | ― | Read/Write | Tab height, width, maximum width and shape (`tsRectangle`, `tsRounded`) |
| `TitleBar` | `TCTitleBar` | Read/Write | The title bar that holds the tab strip (9.7) |
| `ActiveMarkSize`, `ActiveMarkColor`, `ActiveMarkAtBottom` | ― | Read/Write | Thickness (0 means not shown), color and position (above or below) of the line on the visible tab |
| `ActiveTabColor`, `ActiveTextColor`, `TabTextColor`, `ModifiedTextColor`, `HotTabColor`, `ButtonColor`, `SeparatorColor` | `TColor` | Read/Write | Color settings (chapter 7) |

### 3.3 One tab (TCTabSheet)

| Name | Type | Read/Write | Contents |
|---|---|---|---|
| `Caption` | `TCaption` | Read/Write | Title of the tab |
| `ImageIndex` | `TImageIndex` | Read/Write | Icon index. -1 (default) means none |
| `Hint` | `TTranslateString` | Read/Write | Hint shown when the mouse is over it. Nothing if empty |
| `Tag` | `PtrInt` | Read/Write | A number the application can use freely (`AData` of `AddTab`; put a document index or pointer in it) |
| `Modified` | `Boolean` | Read/Write | Modified. If `True`, "●" is shown in the place of [×] (it becomes [×] when the mouse is over it) |
| `TabColorActive` | `TColor` | Read/Write | Background color of this tab only, when it is visible. `clDefault` (default) means `ActiveTabColor` |
| `TabColorOver` | `TColor` | Read/Write | Background color of this tab only, when the mouse is over it. `clDefault` (default) means `HotTabColor` |
| `TabVisible` | `Boolean` | Read/Write | `False` hides the tab |
| `PageIndex` | `Integer` | Read/Write | Index of the tab. Writing moves it to that position |

## 4. Methods

| Name | Arguments | Return value | Contents |
|---|---|---|---|
| `AddTab` | `const ACaption: string; AData: PtrInt = 0; AModified: Boolean = False` | `TCTabSheet` | Adds a tab at the end and returns it. Does not change the visible tab. Raises no event |
| `ClearTabs` | ― | ― | Removes all tabs. `OnPageClose` is not raised |
| `IndexOf` | `APage: TPersistent` | `Integer` | Index of that tab. -1 if there is none |
| `IndexOfTabAt` | `X, Y: Integer` | `Integer` | Index of the tab at that position (counting only visible tabs). -1 if there is none |
| `TabRect` | `AIndex: Integer` | `TRect` | Position and size of that tab |

## 5. Events

### 5.1 Added by this component

| Name | Arguments | Contents |
|---|---|---|
| `OnTabClick` | `Sender: TObject; AIndex: Integer` | A tab was pressed (also raised when the same tab is pressed; before the button is released). `AIndex` is the index of the pressed tab. At this point that tab is already the visible one |
| `OnTabPlusClick` | `Sender: TObject` | [+] (or the right-click "New tab") was pressed. The application adds the tab with `AddTab` |
| `OnTabMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | The left mouse button was released over the tab strip (after the processing of a tab, [×] and [+], and also after the end of a drag). Use it to return the focus after a tab was pressed |
| `OnTabDragOut` | `Sender: TObject; AIndex: Integer; const AScreenPos: TPoint; ATarget: TControl` | A tab was dragged and released outside the tab strip. `AScreenPos` is the screen position of the release and `ATarget` is the control at that position (nil outside the application). Not raised when canceled with Esc |

### 5.2 Inherited from TCPageControl

| Name | Arguments | Contents |
|---|---|---|
| `OnPageClose` | `Sender: TObject; APage: TCTabSheet; var CanClose: Boolean` | Before a tab is closed with [×], the middle button, the right-click "Close tab" or [×] in the tab list. `CanClose := False` keeps it open (use it when the application closes it itself). If nothing is done, the tab disappears |
| `OnPageMoved` | `Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer` | After a tab was moved by dragging (the tab strip is already reordered) |
| `OnChanging` | `Sender: TObject; var AllowChange: Boolean` | Before the visible tab changes. `AllowChange := False` cancels it |
| `OnChange` | `Sender: TObject` | After the visible tab has changed |
| `OnGetImageIndex` | `Sender: TObject; TabIndex: Integer; var ImageIndex: Integer` | Before a tab is drawn. You can decide the icon index |
| `OnContextPopup`, `OnMouse…`, `OnResize`, etc. | ― | Same as 3.3 of the TCPageControl user manual |

`OnNewPage` and `OnPageRename` are not used ([+] raises `OnTabPlusClick`).

### 5.3 Order of calls

| Operation | Order |
|---|---|
| Pressing a tab (another one) | `OnChanging` → `OnChange` → `OnTabClick` → (release) `OnTabMouseUp` |
| Pressing the visible tab | `OnTabClick` → (release) `OnTabMouseUp` |
| Pressing and releasing [+] | `OnTabPlusClick` → `OnTabMouseUp` |
| [×], middle button | `OnPageClose` (if `CanClose = True`, the tab disappears; if it was the visible tab, `OnChange`). For [×], `OnTabMouseUp` follows |
| Reordering by dragging | `OnPageMoved` → `OnTabMouseUp` |
| Dragging and releasing outside the tab strip | `OnTabDragOut` → `OnTabMouseUp` (no reordering happens) |

## 6. Operations

| Part | Operation |
|---|---|
| Tab | Pressing it makes that tab the visible one. Dragging reorders (pressing Esc during the drag, or releasing outside the tab strip, cancels the reordering; releasing outside raises `OnTabDragOut`) |
| [×] of a tab, middle button | Raises `OnPageClose` (while [×] is shown) |
| [+] | Raises `OnTabPlusClick` |
| Mouse over a tab | Shows the hint if `Hint` is set |
| [◀] [▶] | Shown only when the tabs do not fit. Pressing scrolls one tab at a time. The mouse wheel over the tab strip also scrolls |
| [∨] | Shows the tab list when `ShowTabListButton = True` |
| Right-click | The standard items of `TabMenuItems` (default `[tmiNew, tmiClose, tmiRename]`) → the items of `TabPopupMenu`. "New tab" raises `OnTabPlusClick`, "Close tab" raises `OnPageClose`. "Rename tab" edits the name on the tab (remove it from `TabMenuItems` if not used) |

## 7. Colors and Appearance

Colors are decided with properties. `clDefault` (default) means the system color decides.

| Property | Part | When `clDefault` |
|---|---|---|
| `Color` | Tab strip background | `clBtnFace` |
| `ActiveTabColor` | Background of the visible tab | `clWindow` |
| `ActiveTextColor` | Text of the visible tab | `clWindowText` |
| `TabTextColor` | Text of the other tabs | `clBtnText` |
| `ModifiedTextColor` | Text of a modified tab | The color of the other text |
| `HotTabColor` | Background of the tab under the mouse | The background color mixed slightly with `clBtnText` |
| `ButtonColor` | Symbols of [×], [◀] [▶], [+] and [∨] | The text color |
| `SeparatorColor` | Separator line between tabs | (`clNone` means not shown. The default is `clNone`) |
| `ActiveMarkColor`, `ActiveMarkSize` | Line on the visible tab | `clHighlight`. Not shown if the thickness is 0 |
| `TCTabSheet.TabColorActive`, `TabColorOver` | Background of that tab only | `ActiveTabColor`, `HotTabColor` |

- The default look (flat) has no tab background (the other tabs stay in the tab strip's background). For rounded corners, set `TabShape := tsRounded`.
- For dark display, set the colors above to dark colors (9.6).

## 8. Notes

- It has no pages. The TCTabSheet of `Tabs[i]` is a container for the tab's information, and no components are placed in it.
- [×] and [+] do not add or remove tabs automatically. When `CanClose := False` is set in `OnPageClose`, removing the tab is the application's job (rebuild with `ClearTabs`, or `Tabs[i].Free`).
- Do not show a confirmation dialog or remove a tab inside `OnPageClose`. Do it with `Application.QueueAsyncCall` after the tab strip's processing is finished (9.3).
- Processing that moves a tab elsewhere (`OnTabDragOut`) is likewise done later with `QueueAsyncCall` rather than removing the tab inside the event.
- The height automatically fits the tab strip. Do not write `Height` directly (when `TitleBar` is set, it follows the title bar's height).
- Changing the visible tab by writing `TabIndex` does not raise `OnTabClick`. This avoids double processing when the application switches by itself.
- A usage that rebuilds all tabs whenever tabs are added or removed also works (repeating `ClearTabs` → `AddTab`). Set a flag on the application side (such as `FUpdating`) so that the application's processing does not run in `OnChange` while rebuilding.
- `NewPageCaption`, `OnNewPage`, `OnPageRename` and `tmiRename` (renaming) are not used when the application manages tabs itself.

## 9. Usage Examples

### 9.1 Build tabs from a list of documents, and add with [+]

```pascal
procedure TForm1.RebuildTabs;
var
  I: Integer;
  T: TCTabSheet;
begin
  FUpdating := True;          // a flag with which the application ignores OnChange while rebuilding
  try
    CTabBar1.ClearTabs;
    for I := 0 to FDocs.Count - 1 do
    begin
      T := CTabBar1.AddTab(FDocs[I].Name, PtrInt(FDocs[I]), FDocs[I].Modified);
      T.Hint := FDocs[I].FileName;      // hint shown when the mouse is over it
    end;
    CTabBar1.TabIndex := FCurrent;
  finally
    FUpdating := False;
  end;
end;

procedure TForm1.CTabBar1TabPlusClick(Sender: TObject);
begin
  NewDocument;                // create a document and call RebuildTabs
end;
```

### 9.2 Switch the body when a tab is pressed, and return the focus when the button is released

```pascal
procedure TForm1.CTabBar1TabClick(Sender: TObject; AIndex: Integer);
begin
  if FUpdating then Exit;
  ShowDocument(AIndex);
  FFocusOnMouseUp := True;
end;

procedure TForm1.CTabBar1TabMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if FFocusOnMouseUp then
  begin
    FFocusOnMouseUp := False;
    Application.QueueAsyncCall(@FocusEditorLater, 0);   // move the focus to the body after the mouse processing finishes
  end;
end;
```

### 9.3 Confirm before closing

```pascal
procedure TForm1.CTabBar1PageClose(Sender: TObject; APage: TCTabSheet;
  var CanClose: Boolean);
begin
  CanClose := False;          // the tab is not removed here
  Application.QueueAsyncCall(@CloseDocLater, CTabBar1.IndexOf(APage));
end;

procedure TForm1.CloseDocLater(Data: PtrInt);
begin
  if ConfirmSave(Data) then   // show the confirmation dialog outside the tab strip's processing
  begin
    FDocs.Delete(Data);
    RebuildTabs;
  end;
end;
```

### 9.4 Reorder the documents to match the reordering

```pascal
procedure TForm1.CTabBar1PageMoved(Sender: TObject; APage: TCTabSheet;
  AOldIndex, ANewIndex: Integer);
begin
  FDocs.Move(AOldIndex, ANewIndex);    // the tab strip is already reordered
end;
```

### 9.5 Move a tab to another window, or out of the application

```pascal
procedure TForm1.CTabBar1TabDragOut(Sender: TObject; AIndex: Integer;
  const AScreenPos: TPoint; ATarget: TControl);
begin
  if ATarget = nil then
    Application.QueueAsyncCall(@MakeNewWindowLater, AIndex)       // outside the application: to a new window
  else if FindOtherEditor(ATarget) <> nil then
    Application.QueueAsyncCall(@MoveToOtherEditorLater, AIndex);  // over another editor: move it there
end;
```

### 9.6 Dark display

```pascal
CTabBar1.Color := $202020;
CTabBar1.ActiveTabColor := $1E1E1E;
CTabBar1.ActiveTextColor := clWhite;
CTabBar1.TabTextColor := $A0A0A0;
CTabBar1.HotTabColor := $2B2B2B;
CTabBar1.ButtonColor := $A0A0A0;
CTabBar1.SeparatorColor := $3A3A3A;
CTabBar1.ActiveMarkSize := 2;            // line on the visible tab
CTabBar1.ActiveMarkColor := $D47800;
```

### 9.7 Place the tab strip on the title bar

1. Place a TCTitleBar on the form.
2. Set the `TitleBar` of the TCTabBar to that TCTitleBar (the tab strip moves into the title bar).

```pascal
CTabBar1.TitleBar := CTitleBar1;
```