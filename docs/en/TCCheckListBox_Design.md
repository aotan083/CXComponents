# TCCheckListBox Design Document

Author: aotan083
Date: 2026-10-29
Version: 1.0

---

## 1. Purpose

Add the following two things to TCheckListBox.

- Single check (`CheckMode = cmSingle`): the number of checked items is always 0 or 1. Grayed is not used.
- Properties that let the application get the checked item without writing a loop (`CheckedIndex`, `CheckedCount`, `HasChecked`, `CheckedText`, `CheckedObject`), and an event that notifies of the change (`OnCheckedIndexChange`).

When `cmMulti` (the default) is set, checking behaves the same as TCheckListBox.

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `CCheckListBox.pas` | cx (runtime) | `TCCheckMode`, `TCCheckListBox` |
| `uCXReg.pas` | cxdsgn (design time) | Registration on the [CX] palette (`RegisterComponents('CX', [..., TCCheckListBox, ...])`) |
| `cchecklistbox_icon.lrs` | cxdsgn (design time) | Palette icons (resource names `TCCheckListBox`, `TCCheckListBox_150`, `TCCheckListBox_200`; PNGs of 24, 36 and 48 px). Included with `{$I cchecklistbox_icon.lrs}` in the initialization of `uCXReg` |

- uses: `Classes, SysUtils, LMessages, StdCtrls, CheckLst` (LCL only).
- There is no initialization or finalization.

## 3. Types

```pascal
TCCheckMode = (cmMulti, cmSingle);

TCCheckListBox = class(TCheckListBox)
```

## 4. Fields

| Name | Type | Initial value | Contents |
|---|---|---|---|
| `FCheckMode` | `TCCheckMode` | `cmMulti` | Check mode |
| `FAllowNoCheck` | `Boolean` | `True` | In `cmSingle`, whether the user can uncheck the checked item |
| `FCheckedIndex` | `Integer` | -1 | Index of the checked item as last known. When read, it is verified to be correct before being used (6.1) |
| `FClickIndex` | `Integer` | -1 | Index of the item operated with the mouse. Received from the WParam of `LM_CHANGED`. For the Space key it stays -1 and `ItemIndex` is used (7.1) |
| `FOnCheckedIndexChange` | `TNotifyEvent` | nil | Event |

Initial values are set in `Create`.

## 5. Declarations

### 5.1 published

```pascal
property CheckMode: TCCheckMode read FCheckMode write SetCheckMode default cmMulti;
property AllowNoCheck: Boolean read FAllowNoCheck write FAllowNoCheck default True;
property OnCheckedIndexChange: TNotifyEvent read FOnCheckedIndexChange write FOnCheckedIndexChange;
```

### 5.2 public

```pascal
constructor Create(AOwner: TComponent); override;
procedure CheckAll(AState: TCheckBoxState; aAllowGrayed: Boolean = True; aAllowDisabled: Boolean = True);
procedure Toggle(AIndex: Integer);
property Checked[AIndex: Integer]: Boolean read GetChecked write SetChecked;
property State[AIndex: Integer]: TCheckBoxState read GetState write SetState;
property CheckedIndex: Integer read GetCheckedIndex write SetCheckedIndex;
property CheckedCount: Integer read GetCheckedCount;
property HasChecked: Boolean read GetHasChecked;
property CheckedText: string read GetCheckedText;
property CheckedObject: TObject read GetCheckedObject;
```

- `CheckAll`, `Toggle`, `Checked` and `State` are redeclared to hide the members of the same name in the parent class (not override, because the parent's are not virtual). Therefore, calling them through a variable of type `TCheckListBox` runs the parent's code. This is described in section 7.1 of the User Manual.

### 5.3 protected

```pascal
procedure WndProc(var TheMessage: TLMessage); override;
procedure ClickCheck; override;
procedure Loaded; override;
procedure DoCheckedIndexChange; virtual;
```

### 5.4 private procedures

| Name | Contents |
|---|---|
| `BaseState(AIndex): TCheckBoxState` | Returns `TCustomCheckListBox(Self).State[AIndex]`. Reads the parent's state without going through the redeclared `State` |
| `SetBaseState(AIndex; AValue)` | `TCustomCheckListBox(Self).State[AIndex] := AValue`. Writes the parent's state directly. No event is raised |
| `IsItemChecked(AIndex): Boolean` | `BaseState(AIndex) <> cbUnchecked`. Grayed also counts as checked (same as the parent's `Checked`) |
| `FindFirstChecked: Integer` | Checks `IsItemChecked` in order from index 0 and returns the first index. -1 if none |
| `FirstCheckedAssuming(AIndex; AIndexChecked): Integer` | Does the same as `FindFirstChecked`, but treats only the item at `AIndex` as "checked = `AIndexChecked`". Used to obtain `CheckedIndex` from before a user operation (7.2) |
| `UncheckOthers(AKeep)` | Unchecks every item other than `AKeep` that is not `cbUnchecked`, using `SetBaseState(i, cbUnchecked)`. Raises no event |
| `NormalizeSingle` | `keep := FindFirstChecked`. If `keep >= 0`, sets that item to `cbChecked` if it is not already, and calls `UncheckOthers(keep)`. Finally `FCheckedIndex := keep`. Raises no event |
| `NotifyIfChanged(AOld)` | If `GetCheckedIndex <> AOld`, calls `DoCheckedIndexChange` |

## 6. Processing

### 6.1 Reading CheckedIndex (GetCheckedIndex)

1. If `FCheckMode = cmSingle`, `0 <= FCheckedIndex < Items.Count`, and `IsItemChecked(FCheckedIndex)`, return `FCheckedIndex` (no loop).
2. Otherwise, set `FCheckedIndex := FindFirstChecked` and return it.

- Even if indexes shift because items are added, deleted or sorted, the check in step 1 fails and step 2 searches again, so the correct value is returned. Therefore changes to Items are not monitored.
- In `cmMulti`, step 2 is taken every time.

### 6.2 Writing CheckedIndex (SetCheckedIndex)

1. If `AValue < -1` or `AValue >= Items.Count`, do nothing and finish (no exception is raised).
2. `old := GetCheckedIndex`.
3. If `AValue >= 0`, `SetBaseState(AValue, cbChecked)`.
4. `UncheckOthers(AValue)` (with -1, everything is unchecked).
5. `FCheckedIndex := AValue`.
6. `NotifyIfChanged(old)`.

- The same applies to `cmMulti` (only the specified item remains).
- `AllowNoCheck` is not consulted.

### 6.3 Other reads

| Property | Processing |
|---|---|
| `CheckedCount` | `cmSingle`: `Ord(GetHasChecked)`. `cmMulti`: counts the items for which `IsItemChecked` is true |
| `HasChecked` | `GetCheckedIndex >= 0` |
| `CheckedText` | `idx := GetCheckedIndex`. '' if `idx < 0`, otherwise `Items[idx]` |
| `CheckedObject` | `idx := GetCheckedIndex`. nil if `idx < 0`, otherwise `Items.Objects[idx]` |
| `Checked[i]` read | `IsItemChecked(i)` |
| `State[i]` read | `BaseState(i)` |

### 6.4 Writing Checked and State

`SetChecked(i, v)`: if `v` is `True`, `SetState(i, cbChecked)`; if `False`, `SetState(i, cbUnchecked)`.

`SetState(i, v)`:

1. `old := GetCheckedIndex`.
2. `cmMulti`: `SetBaseState(i, v)`.
3. `cmSingle` and `v = cbChecked`: first `SetBaseState(i, cbChecked)` (if the index is out of range, the parent raises an exception here), then `UncheckOthers(i)`, `FCheckedIndex := i`.
4. `cmSingle` and `v` is `cbUnchecked` or `cbGrayed`: `SetBaseState(i, cbUnchecked)`. `AllowNoCheck` is not consulted.
5. `NotifyIfChanged(old)`.

### 6.5 CheckAll

1. `old := GetCheckedIndex`.
2. `cmMulti`: `inherited CheckAll(AState, aAllowGrayed, aAllowDisabled)`.
3. `cmSingle` and `AState = cbChecked`: going from index 0 in order, let `keep` be the first item that satisfies `(aAllowGrayed or (BaseState(i) <> cbGrayed)) and (aAllowDisabled or ItemEnabled[i])`. If `keep >= 0`, do `SetBaseState(keep, cbChecked)`, `UncheckOthers(keep)`, `FCheckedIndex := keep`. If there is no target, nothing is changed.
4. `cmSingle` and `AState` is `cbUnchecked` or `cbGrayed`: `inherited CheckAll(cbUnchecked, aAllowGrayed, aAllowDisabled)`.
5. `NotifyIfChanged(old)`.

The target condition (the expression in step 3) is the same as in the parent's `CheckAll`.

### 6.6 Toggle

- `cmMulti`: `old := GetCheckedIndex`, `inherited Toggle(AIndex)`, `NotifyIfChanged(old)`.
- `cmSingle`: `SetChecked(AIndex, not IsItemChecked(AIndex))` (Grayed is not used. The event is raised by `SetState`).

### 6.7 Writing CheckMode (SetCheckMode)

1. If the value is the same, finish.
2. `FCheckMode := AValue`.
3. If `csLoading`, finish (normalizing is done in `Loaded`).
4. If `AValue = cmSingle`, call `NormalizeSingle`. The item with the smallest index remains, so `CheckedIndex` does not change and no event is raised.
5. When switching to `cmMulti`, the checks are not changed.

### 6.8 Loaded

After `inherited Loaded`, if `FCheckMode = cmSingle`, call `NormalizeSingle`. Even if multiple checks are saved in the .lfm, only the item with the smallest index remains.

### 6.9 DoCheckedIndexChange

Does nothing while `csLoading`. Otherwise, calls `FOnCheckedIndexChange` if it is assigned.

## 7. User Operations

### 7.1 Which item was operated (WndProc)

When the check box area is clicked with the mouse, the parent (TCustomCheckListBox) receives `LM_CHANGED` (WParam = item index) from the Windows control, switches the state with `Toggle`, and then calls `ClickCheck`. For the Space key it does not pass through `LM_CHANGED`; it does the same for the item at `ItemIndex`.

```pascal
procedure TCCheckListBox.WndProc(var TheMessage: TLMessage);
begin
  if TheMessage.Msg <> LM_CHANGED then
  begin
    inherited WndProc(TheMessage);
    Exit;
  end;
  FClickIndex := TheMessage.WParam;
  try
    inherited WndProc(TheMessage);   // Parent's processing -> ClickCheck is called
  finally
    FClickIndex := -1;
  end;
end;
```

### 7.2 ClickCheck

By the time `ClickCheck` is called, the parent has already switched the state with `Toggle`. The parent's `Toggle` switches as follows.

| `AllowGrayed` | Switching |
|---|---|
| `False` | unchecked -> checked -> unchecked |
| `True` | unchecked -> grayed -> checked -> unchecked |

Steps:

1. `idx := FClickIndex`. If it is -1, `idx := ItemIndex`.
2. If `idx` is out of range, only call `inherited ClickCheck` and finish.
3. `st := BaseState(idx)` (the state after switching).
4. In `cmMulti`: the checks are not changed. Whether this item was checked before switching (`beforeChecked`) is worked out backwards using the following table.

   | State after switching `st` | Before switching | `beforeChecked` |
   |---|---|---|
   | `cbUnchecked` | checked (or grayed) | `True` |
   | `cbGrayed` | unchecked | `False` |
   | `cbChecked` | grayed if `AllowGrayed = True`, unchecked if `False` | `AllowGrayed` |

   `oldIdx := FirstCheckedAssuming(idx, beforeChecked)`, `inherited ClickCheck` (`OnClickCheck`), `NotifyIfChanged(oldIdx)`.
5. `cmSingle` and `st = cbUnchecked` (an operation that unchecks the checked item):
   - If `FAllowNoCheck = False`, do `SetBaseState(idx, cbChecked)` and `FCheckedIndex := idx`, then finish. Neither `OnClickCheck` nor `OnCheckedIndexChange` is raised.
   - If `True`, do `FCheckedIndex := -1`, `inherited ClickCheck`, `NotifyIfChanged(idx)` (before the operation, `idx` was the checked item).
6. `cmSingle` and `st` is `cbGrayed` or `cbChecked` (an operation that checks an unchecked item):
   - If `st = cbGrayed`, `SetBaseState(idx, cbChecked)` (skips Grayed).
   - `oldIdx := FirstCheckedAssuming(idx, False)` (the smallest checked index other than this item).
   - `UncheckOthers(idx)`, `FCheckedIndex := idx`, `inherited ClickCheck`, `NotifyIfChanged(oldIdx)`.

- `OnClickCheck` is not raised for items that were unchecked automatically (because `UncheckOthers` writes the parent's state directly).
- `OnItemClick` is raised by the parent and is not suppressed by this component. Therefore it is also raised in the "was not unchecked" case of step 5.

## 8. Order in Which Events Are Raised

| Operation | Order |
|---|---|
| User click or Space key | `OnClickCheck` -> `OnCheckedIndexChange` (`inherited ClickCheck` -> `NotifyIfChanged` in 7.2) |
| `Checked[]`, `State[]`, `CheckedIndex`, `CheckAll`, `Toggle` in code | `OnCheckedIndexChange` only |

`OnCheckedIndexChange` is always raised from `NotifyIfChanged`. It is not raised when the value does not change.

## 9. Where to Look When Investigating Defects

| Symptom | Where to look |
|---|---|
| Two or more items are checked even though `cmSingle` is set | Whether the caller's variable type is `TCheckListBox` or `TCustomCheckListBox` (5.2). `NormalizeSingle` in `Loaded` and `SetCheckMode` |
| `CheckedIndex` returns a stale value | The check in step 1 of `GetCheckedIndex` (6.1) |
| A different item is processed on mouse click | `FClickIndex` in `WndProc` (7.1) |
| `OnCheckedIndexChange` is not raised or is raised twice | How `old` passed to `NotifyIfChanged` is obtained (6.2 to 6.6, 7.2). Whether `csLoading` is in effect (6.9) |
| Events are off on a `cmMulti` click | The backward-calculation table in step 4 of 7.2, and the switching order of the parent's `Toggle` |
