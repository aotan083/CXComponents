# TCSplitter User Manual

Author: aotan083
Date: 2026-11-06
Version: 1.0

---

## 1. Overview and Classes

A splitter used in the same way as TSplitter. A colored line appears when the mouse is over it and while it is being dragged. With the standard TSplitter, the look does not change when the mouse is over it.

| Item | Contents |
|---|---|
| Lazarus | 4.8, 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Classes and Units

| Class | Unit | Package | Parent class |
|---|---|---|---|
| `TCSplitter` | `uCSplitter` | cx | `TSplitter` |

- When you place it on a form, `uCSplitter` is added to uses automatically, and cx is added to the required packages of the project automatically.
- When you create it in code, write it in uses yourself.

### 1.2 Differences from TSplitter

| Item | TSplitter | TCSplitter |
|---|---|---|
| Splitting mechanism, properties, events | Yes | The same |
| Look when the mouse is over it | Does not change | A colored line appears |
| Look while dragging | Depends on `ResizeStyle` (a black line with `rsLine`) | The colored line stays |
| Color of the line | Cannot be specified | Can be specified with `HighlightColor` |
| Specifying the cursor | Writing `Cursor` is reset when the direction changes | Can be specified with `SplitCursor` |
| `OnMouseEnter`, `OnMouseLeave`, etc. | Do not appear in the Object Inspector | Appear |

## 2. From Placing on a Form to Running

1. Place a panel with `Align = alLeft` on the form.
2. Place TCSplitter from the [CX] palette to the right of the panel (keep `Align = alLeft`).
3. Place another panel and set `Align = alClient`.
4. Run. When the mouse is over the splitter, a line appears, and when you drag it, the width of the panel changes.

To split up-down, place it under a panel with `Align = alTop` and set the `Align` of TCSplitter to `alTop`.

## 3. Properties

The properties of TSplitter (`Align`, `MinSize`, `ResizeStyle`, `ResizeAnchor`, `AutoSnap`, `Beveled`, etc.) can be used as they are. The added ones are as follows.

| Property | Type | Read/Write | Default | Contents |
|---|---|---|---|---|
| `HighlightColor` | `TColor` | Read/Write | `clHighlight` | The color of the line. The default is the selection color of Windows, which changes with the theme and dark display. To fix a color, specify it |
| `SplitCursor` | `TCursor` | Read/Write | `crDefault` | The mouse cursor over the splitter. With `crDefault`, it is the same as TSplitter (a horizontal arrow when splitting left-right, a vertical arrow when splitting up-down). With any other value, that cursor is used |

- To change the cursor, write `SplitCursor`, not `Cursor` (a value written to `Cursor` returns to the original when the splitting direction is changed).
- When it is not usable (`Enabled = False`), no line appears and the cursor stays the standard one.

## 4. Events

The events of TSplitter (`OnCanOffset`, `OnCanResize`, `OnMoved`, `OnPaint`, etc.) can be used as they are.

| Event | When it is raised |
|---|---|
| `OnMouseEnter` | When the mouse comes over the splitter |
| `OnMouseLeave` | When the mouse leaves the splitter |
| `OnMouseMove` | When the mouse moves over the splitter |
| `OnMouseDown` | When a button is pressed on the splitter |
| `OnMouseUp` | When the button is released |
| `OnMoved` | When a drag ends and the splitter has moved (the same as TSplitter) |

## 5. Examples

### 5.1 Change the Color of the Line

```pascal
CSplitter1.HighlightColor := clRed;
```

### 5.2 Change the Cursor

```pascal
CSplitter1.SplitCursor := crHandPoint;   // hand cursor
CSplitter1.SplitCursor := crDefault;     // back to the original
```

### 5.3 Do Something When the Mouse Comes Over It

```pascal
procedure TForm1.CSplitter1MouseEnter(Sender: TObject);
begin
  StatusBar1.SimpleText := 'Splitter: drag to change the width';
end;

procedure TForm1.CSplitter1MouseLeave(Sender: TObject);
begin
  StatusBar1.SimpleText := '';
end;
```

## 6. Notes

- At design time (form designer), no line appears (the look is the same as TSplitter). The line appears only when the application runs.
- The line is drawn in the middle of the splitter with a thickness of 2 px (it changes with the display scale). If the splitter is thin, it is hard to see. The thickness of the splitter can be changed with `Width` (when splitting left-right) or `Height` (when splitting up-down).
