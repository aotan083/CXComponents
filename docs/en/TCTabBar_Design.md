# TCTabBar Design Document

Author: aotan083
Date: 2026-11-24
Version: 1.0

---

**Operating environment**: Lazarus 5.0 or later (FPC 3.2.2). Lazarus 4.8 and earlier are not supported.

## 1. Purpose

Build a component that is only a tab strip, without pages. It is for usage where the application switches the screen itself, like the tabs of the editors (TCsEditor and TCMonacoEditor). It replaces the places that used a third-party tab component with a CX component, removing the dependency on third-party code.

- Drawing the tab strip, scrolling, reordering by dragging, [×], [+], [∨], the tab list and placement on the title bar use the tab strip of TCPageControl (`TCTabStrip`) as it is. It is not rebuilt.
- Therefore `TCTabBar` derives from `TCPageControl` and is used with a height without a page area (= the height of the tab strip). One tab = one `TCTabSheet` (the page content is not used).
- The features the editors need (modified mark, per-tab colors, color settings, the line on the visible tab, separators, hints, closing with the middle button, and notification of a drag outside the tab strip) are added to `TCPageControl` and `TCTabSheet` (all of them change nothing at the default values).
- [×] and [+] do nothing by themselves. They only notify the application (the application decides when to add or remove tabs).

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCPageControl.pas` | cx (run time) | `TCTabBar` (after `TCPageControl`), and the types `TCTabIndexEvent`, `TCTabDragOutEvent` and `TCStripColorKind`. The additions to `TCPageControl`, `TCTabSheet` and `TCTabStrip` (chapter 3) |
| `design\uCPageControl_reg.pas` | cxdsgn (design time) | Registration on the [CX] palette (`RegisterComponents('CX', [TCTitleBar, TCPageControl, TCTabBar])`). The icon is in `source\res\cpagecontrol_icon.lrs` (`TCTabBar`, `TCTabBar_150`, `TCTabBar_200`; 24, 36 and 48 px) |

- No units are added. The dependency on the package of the third-party tab component is removed from cx.

## 3. Additions to the Inherited Classes

### 3.1 TCTabSheet

| Name | Type | Default | Contents |
|---|---|---|---|
| `FModified` / `Modified` | `Boolean` | `False` | Modified. When it changes, `PageControl.PageChanged` (redraw) |
| `FTabColorActive` / `TabColorActive` | `TColor` | `clDefault` | Background color of this tab only, when it is visible |
| `FTabColorOver` / `TabColorOver` | `TColor` | `clDefault` | Background color of this tab only, when the mouse is over it |

Public (run time only). `Hint` uses the one of `TControl`.

### 3.2 TCPageControl

| Name | Contents |
|---|---|
| `FStripColors[TCStripColorKind]` | Color settings. `sckActive`, `sckActiveText`, `sckText`, `sckModifiedText`, `sckHot` and `sckButton` are `clDefault`; `sckSeparator` is `clNone`. The published `ActiveTabColor`, `ActiveTextColor`, `TabTextColor`, `ModifiedTextColor`, `HotTabColor`, `ButtonColor` and `SeparatorColor` read and write them with `index 0..6` (`GetStripColor`, `SetStripColor`). When one changes, `FStrip.Invalidate` |
| `ActiveMarkSize`, `ActiveMarkColor`, `ActiveMarkAtBottom` | The line on the visible tab. 0, `clHighlight`, `False`. When one changes, `FStrip.Invalidate` |
| `DoTabDragOut(APage, AScreenPos, ATarget)`, `DoStripMouseUp(AButton, AShift, X, Y)`, `DoStripLayouted` | protected virtual. Do nothing. `TCTabBar` overrides them (chapter 4) |

- `PageChanged` calls `DoStripLayouted` at the end.

### 3.3 TCTabStrip

| Procedure | Change |
|---|---|
| Constructor | `ParentShowHint := False`, `ShowHint := True` (to show tab hints. Nothing appears if `Hint` is empty) |
| `PaintTab` | Background: for the visible tab `clWindow` → (`ActiveTabColor`) → (`TCTabSheet.TabColorActive`). When the mouse is over it or it is pressed, the blended color → (`TabColorOver` → `HotTabColor`). The line on the visible tab (when `ActiveMarkSize > 0`, painted with `ActiveMarkColor` after the background). Text: after the existing rule, `ActiveTextColor` / `TabTextColor`, and for a modified tab `ModifiedTextColor` (except for hidden tabs at design time). [×]: `ButtonColor` (the tab's text color if not set). With `Modified`, when the mouse is not over [×], a filled circle of radius `CPC_DOT_R` (4) |
| `PaintButton` | Uses `ButtonColor` for the symbol color |
| `Paint` | When `SeparatorColor <> clNone`, a vertical line in the gap to the right of each tab (excluding 6px at the top and bottom). Not drawn if either of the tabs is the visible one |
| `MouseMove` | When the tab under the mouse changes, `Hint := the tab's Hint` ('' if not over a tab) |
| `MouseUp` | Middle button: if `nboShowCloseButtons` is set and the mouse is over a tab, `DoCloseButtonClick` (`DoStripMouseUp` is not called). Left button: `DoStripMouseUp` after the existing processing (also after the end of a drag) |
| `FinishDrag` | When released outside the tab strip, no reordering; `DoTabDragOut(page, ClientToScreen(P), FindDragTarget(screen position, True))` |

## 4. TCTabBar

```pascal
TCTabBar = class(TCPageControl)
private
  FOnTabClick: TCTabIndexEvent;
  FOnTabPlusClick: TNotifyEvent;
  FOnTabMouseUp: TMouseEvent;
  FOnTabDragOut: TCTabDragOutEvent;
  function GetTabCount: Integer;                 // PageCount
  function GetTab(AIndex: Integer): TCTabSheet;  // Pages[AIndex]
  procedure FitHeight;
protected
  procedure DoTabClick(APage: TCTabSheet); override;
  procedure DoAddButtonClick; override;
  procedure DoMenuNewClick; override;
  procedure DoTabDragOut(APage: TCTabSheet; const AScreenPos: TPoint; ATarget: TControl); override;
  procedure DoStripMouseUp(AButton: TMouseButton; AShift: TShiftState; X, Y: Integer); override;
  procedure DoStripLayouted; override;
  procedure Loaded; override;
public
  constructor Create(TheOwner: TComponent); override;
  function AddTab(const ACaption: string; AData: PtrInt = 0; AModified: Boolean = False): TCTabSheet;
  procedure ClearTabs;
  property TabCount: Integer read GetTabCount;
  property Tabs[AIndex: Integer]: TCTabSheet read GetTab;
published
  property Align default alTop;
  property Options default [nboShowCloseButtons, nboShowAddTabButton];
  property ShowTabListButton default False;
  property TabStop default False;
  property OnTabClick: TCTabIndexEvent read FOnTabClick write FOnTabClick;
  property OnTabPlusClick: TNotifyEvent read FOnTabPlusClick write FOnTabPlusClick;
  property OnTabMouseUp: TMouseEvent read FOnTabMouseUp write FOnTabMouseUp;
  property OnTabDragOut: TCTabDragOutEvent read FOnTabDragOut write FOnTabDragOut;
end;
```

| Procedure | Processing |
|---|---|
| `Create` | `inherited`. `Options := [nboShowCloseButtons, nboShowAddTabButton]`, `ShowTabListButton := False`, `TabStop := False`, `Align := alTop` |
| `AddTab` | Create with `AddTabSheet` (adds at the end; does not change the visible tab), set `Caption`, `Tag := AData` and `Modified`, and return it |
| `ClearTabs` | `Clear` |
| `DoTabClick(APage)` | `inherited` (makes it the visible one; `OnChanging`, `OnChange`), then `OnTabClick(Self, IndexOf(APage))` |
| `DoAddButtonClick`, `DoMenuNewClick` | Only calls `OnTabPlusClick(Self)` (no empty page is created; `OnNewPage` is not raised) |
| `DoTabDragOut` | `OnTabDragOut(Self, IndexOf(APage), AScreenPos, ATarget)` |
| `DoStripMouseUp` | `OnTabMouseUp(Self, AButton, AShift, X, Y)` |
| `DoStripLayouted`, `Loaded` | `FitHeight`: if there is no `TitleBar`, the tab strip height (`TabStrip.Height`) is greater than 0 and differs from its own `Height`, `Height := TabStrip.Height` |

- [×], the right-click "Close tab" and [×] in the tab list remain `ClosePageByUser` of TCPageControl (`OnPageClose` → `Free` if `CanClose`). The application sets `CanClose := False` and closes it itself later.
- Only the visible one of the pages (`TCTabSheet`) is shown, but since its own height equals the tab strip's height, the page area is 0.

## 5. Points to Check

| Symptom | Where to look |
|---|---|
| The height is larger or smaller than the tab strip | `FitHeight`, `DoStripLayouted`. Whether `TitleBar` is set |
| Pressing [×] does not remove the tab | Whether `CanClose := False` is set in `OnPageClose`. Whether the application closes it |
| [+] does not add a tab | Whether the application calls `AddTab` in `OnTabPlusClick` |
| Colors do not change | Whether it is still `clDefault`. The precedence of `ActiveTabColor` and `TabColorActive` (3.3) |
| "●" does not appear | `Modified` and `nboShowCloseButtons` (it does not appear unless [×] is shown) |
| The line does not appear | Whether `ActiveMarkSize > 0` |
| The hint does not appear | Whether `TCTabSheet.Hint` is not empty |
| `OnTabDragOut` does not arrive when a tab is dragged out | Whether it was canceled with Esc. Whether it was released outside the tab strip. `FinishDrag` |
| Crash when a tab is removed in the middle of the tab strip's drag | Do not remove inside `OnTabDragOut` or `OnPageClose`; remove later with `QueueAsyncCall` |

## 6. Changes in this Version (1.0)

### 6.1 Now and after the change (the tab strips of TCsEditor and TCMonacoEditor)

| No | Item | Now: behavior and problem | After (1.0) | Reason | Risk |
|---|---|---|---|---|---|
| 1 | Tab strip component | A third-party tab component. Cannot be fixed. Cannot be placed on the title bar | `TCTabBar` (a CX component. Uses the tab strip of TCPageControl) | Reduce third-party code. Match the look and operation of CX components | The look and fine behavior differ slightly from the former tab component (the table of 4.6) |
| 2 | Published types | The types of `TCMTabBinder.Tabs` and `Attach(Ed, ATabs)` are those of the third-party tab component | `TCTabBar` | For 1 | Applications that use them must fix the type |
| 3 | Processing after reordering tabs | `OnTabDropQuery` (reorders the documents before dropping) and `OnTabMove` | `OnPageMoved` (matches the order of the documents after the tab strip was reordered) | TCTabBar notifies after reordering | Check the correspondence of tabs and documents right after reordering on the real application |
| 4 | Moving a tab | `OnEndDrag` of the LCL drag (`Target`, checking the left button) | `OnTabDragOut` (the release position on the screen and the control at that position. Not raised when canceled with Esc) | Because the drag becomes its own (mouse capture) | Check moving to another editor and dragging out of the application on the real application |
| 5 | Modified mark | " *" after the title | The same (the "●" of `Modified` is not used. An application that wants it can use `Modified`) | Do not change the look | None |
| 6 | Closing | `OnTabClose` with [×] and the middle button | `OnPageClose` with [×], the middle button, the right-click "Close tab" and [×] in the tab list | They become one processing | The right-click menu and the tab list become available (features of TCPageControl) |
| 7 | Package of the third-party tab component | Required by cx | Not required (removed from cx.lpk) | Reduce third-party code | None |

### 6.2 What to change

| No | File | Change |
|---|---|---|
| 1 | `uCPageControl.pas` | The additions of chapter 3. `TCTabBar`. Closing with the middle button |
| 2 | `CMonacoTabs.pas` | The type of the third-party tab component to `TCTabBar`. The handlers to `PageClose`, `PageMoved` and `TabDragOut`. Remove `MainButtonDown` |
| 3 | `uCmonacos.pas`, `uCsEditor.pas` | The type of the third-party tab component to `TCTabBar`. The color, shape and icon settings to the new properties. The tab text is `Screen.SystemFont` (because when `ParentFont := False`, the `Font` at that moment remains) |
| 4 | `packages\cx.lpk` | Remove the package of the third-party tab component from the required packages |
| 5 | `source\design\uCPageControl_reg.pas` | Register `TCTabBar` |

- Verified (Lazarus 5.0 RC1, Windows 11): with a small test program for TCTabBar alone: colors, the line, "●", separators, scrolling, [+], [×], the middle button, reordering, and dragging outside the tab strip. With the TCsEditor demo: [+], reordering and [×]. With the TCMonacoEditor demo: [+], reordering and [×].
- Not verified: moving a tab to another TCsEditor and dragging a tab out of the application (on the real application), showing the hint, and the correspondence of documents after reordering in TCMonacoEditor.