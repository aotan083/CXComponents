# TCCapture User Manual

Author: aotan083
Date: 2026-11-17
Version: 1.0

---

## 1. Overview and Classes

A component that captures the desktop screen and saves it to an image file. It has no screen of its own (when placed on a form, it appears in the component area below the form).

- There are 3 kinds of capture range: the whole desktop (including all monitors if there are several), the active window, and an arbitrary rectangle.
- The captured picture and the reading and writing of files use `TCImage` (`TCImage_Usage.md`). Saving is possible as bmp, jpg, png, tif and ico, converted to the format of the extension (it cannot save to svg).

| Item | Content |
|---|---|
| Lazarus | 4.8, 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Description |
|---|---|---|---|---|
| `TCCapture` | `uCCapture` | cx | `TComponent` | Captures the screen, and saves and loads it |
| `ECCaptureError` | `uCCapture` | cx | `Exception` | Exception raised when capturing or saving fails |

| Type | Unit | Description |
|---|---|---|
| `TCCaptureArea` | `uCCapture` | `caDesktop`: whole desktop, `caActiveWindow`: active window, `caRegion`: specified rectangle |

- When placed on a form, `uCCapture` is added to uses automatically, and cx is added to the project's required packages automatically.
- When creating it in code, write it in uses yourself.

### 1.2 Capture Range

| `Area` | Range captured |
|---|---|
| `caDesktop` | The whole desktop (the whole screen including all monitors) |
| `caActiveWindow` | The visible area of the currently active window (the shadow is not included) |
| `caRegion` | The rectangle set by `Region` (or the arguments of `CaptureRegion`). In screen coordinates; `X1` and `Y1` are exclusive ends |

- With `caRegion`, if left/right or top/bottom are reversed (`X > X1`, and so on), they are swapped. A part that sticks out of the screen is cut off and only the part inside is captured.
- If the width or height of the range is 0, or it does not overlap the screen at all, `ECCaptureError` is raised.
- With `caActiveWindow`, if there is no active window or it is minimized, `ECCaptureError` is raised.
- If you capture from a button click, your own form becomes the active window. To capture another application, wait with `Delay` and then capture.

## 2. Placing It on a Form

1. Place TCCapture on the form from the [CX] palette.
2. Set `Area` (the capture range).
3. Call `Capture` in code and save with `SaveToFile`.

```pascal
CCapture1.Area := caDesktop;
CCapture1.Capture;
CCapture1.SaveToFile('C:\temp\shots\desktop.png');   // creates C:\temp\shots if missing
```

## 3. Properties

| Name | Type | Access | Description |
|---|---|---|---|
| `Image` | `TCImage` | Read | The captured picture (a picture read with `LoadFromFile` is also here). Created and destroyed by the component. To display it, copy it to your own `TCImage` with `CopyTo` |
| `Area` | `TCCaptureArea` | Read/Write | Kind of range captured by `Capture` (default `caDesktop`) |
| `Region` | `TRect` | Read/Write | Range used when `Area = caRegion`. `Left=X`, `Top=Y`, `Right=X1`, `Bottom=Y1`. Run time only |
| `RegionLeft`, `RegionTop`, `RegionRight`, `RegionBottom` | `Integer` | Read/Write | The 4 values of `Region` (default 0). Can be set in the Object Inspector |
| `IncludeCursor` | `Boolean` | Read/Write | `True` also draws the mouse cursor (default `False`). A cursor outside the captured range is not drawn |
| `Delay` | `Integer` | Read/Write | Time to wait before capturing, in milliseconds (default 0). Screen processing continues while waiting. A value below 0 becomes 0 |
| `JpegQuality` | `Integer` | Read/Write | Quality when saving jpg (1-100, default 90). Out-of-range values are clamped |
| `FileName` | `string` | Read | File name last used with `SaveToFile` or `LoadFromFile`. Empty after a capture |
| `Empty` | `Boolean` | Read | `True` if the picture is empty |

## 4. Methods

| Name | Arguments | Returns | Description |
|---|---|---|---|
| `Capture` | - | - | Captures with the `Area` setting. Waits for `Delay`, then captures and puts it in `Image` |
| `CaptureDesktop` | - | - | Captures the whole desktop without changing `Area` |
| `CaptureActiveWindow` | - | - | Captures the active window without changing `Area` |
| `CaptureRegion` | `X, Y, X1, Y1: Integer` | - | Captures the specified range without changing `Area` |
| `SaveToFile` | `AFileName: string` | - | Saves `Image`. Creates the destination folder (including intermediate levels) if it does not exist. Converts to the format of the extension. Raises `ECCaptureError` if the picture is empty |
| `LoadFromFile` | `AFileName: string` | - | Reads an image file (bmp, jpg, png, svg, tif, ico) into `Image` |
| `Clear` | - | - | Empties `Image` |
| `CopyTo` | `ATarget: TCImage` | - | Copies the picture of `Image` to another `TCImage` |

- `CaptureDesktop`, `CaptureActiveWindow` and `CaptureRegion` also wait for `Delay` before capturing.
- When writing an image fails, the `TCImage` exception `ECImageError` is passed through as it is.

## 5. Events

| Name | Type | Called when |
|---|---|---|
| `OnCaptured` | `TNotifyEvent` | After a capture finishes and is put in `Image` |
| `OnSaved` | `TNotifyEvent` | After saving finishes |

## 6. Examples

### 6.1 Read and Save in Another Format

```pascal
CCapture1.LoadFromFile('C:\temp\123.bmp');
CCapture1.SaveToFile('C:\temp\123\123.jpg');   // creates the folder if missing; converts bmp to jpg
```

### 6.2 Capture a Specified Range

```pascal
CCapture1.CaptureRegion(100, 100, 500, 400);       // (100,100) to (500,400)
CCapture1.SaveToFile('C:\temp\part.png');

CCapture1.Delay := 3000;                           // wait 3 seconds, then capture the active window
CCapture1.CaptureActiveWindow;
```

### 6.3 Show the Captured Picture

```pascal
CCapture1.CaptureDesktop;
CCapture1.CopyTo(CImage1);     // CImage1 is a TCImage
CImage1.Stretch := True;
CImage1.Proportional := True;
```

### 6.4 Handle Exceptions

```pascal
try
  CCapture1.CaptureActiveWindow;
  CCapture1.SaveToFile(Edit1.Text);
except
  on E: ECCaptureError do ShowMessage(E.Message);
  on E: ECImageError do ShowMessage(E.Message);
end;
```

## 7. Notes

- If the application is not DPI-aware (not declared in the manifest), capture uses the coordinates converted by Windows.
- Windows 11 only. Hidden windows and minimized windows cannot be captured.
