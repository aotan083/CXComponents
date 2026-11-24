# TCCapture Design Document

Author: aotan083
Date: 2026-11-17
Version: 1.0

---

**Operating environment**: Lazarus 5.0 or later (FPC 3.2.2). Lazarus 4.8 and earlier are not supported.

## 1. Purpose and Policy

- A component (`TCCapture`) that captures the desktop screen and saves it to an image file.
- The captured picture and the reading and writing of files use `TCImage` (`TCImage_Design.md`).
- A non-visual component (subclass of `TComponent`). Place it on a form, or create it in code.

### 1.1 Out of Scope

- Video recording.
- Capturing hidden or minimized windows.
- Continuous capture at time intervals.
- Choosing the range with the mouse on screen (coordinates are passed in).
- Linux and macOS (Windows 11 only).

## 2. Files and Packages

| File | Package | Content |
|---|---|---|
| `uCCapture.pas` | cx (run time) | `TCCapture` |
| `uCImages.pas` | cx (run time) | `TCImage` (`TCImage_Design.md`) |
| `uCXReg.pas` (`source\design`) | cxdsgn (design time) | Registration on the [CX] palette |
| `uCXLang.pas` | cx (run time) | Adds strings (chapter 7) |

- uses of `uCCapture`: `Classes, SysUtils, Types, Math, Windows, Graphics, Controls, Forms, LCLType, LCLIntf, uCImages, uCXLang`.
- To get the frame of the active window, `DwmGetWindowAttribute` (`dwmapi.dll`) is used. It is looked up at run time with `LoadLibrary`, and if absent it falls back to `GetWindowRect`.
- No initialization or finalization.
- The packages remain the two: cx and cxdsgn.

## 3. Kinds of Range

```
TCCaptureArea = (caDesktop, caActiveWindow, caRegion);
```

| Value | Range captured |
|---|---|
| `caDesktop` | The whole desktop. With several monitors, the virtual screen containing all of them (`SM_XVIRTUALSCREEN`, `SM_CXVIRTUALSCREEN` x `SM_CYVIRTUALSCREEN`) |
| `caActiveWindow` | The visible area of the active window (`GetForegroundWindow`), the frame without the shadow (`DWMWA_EXTENDED_FRAME_BOUNDS`). `GetWindowRect` if it cannot be obtained |
| `caRegion` | The specified rectangle (`X, Y, X1, Y1`), in screen (virtual screen) coordinates. `X1` and `Y1` are exclusive ends (same as `Right` and `Bottom` of `TRect`) |

- With `caRegion`, if `X > X1` or `Y > Y1`, they are swapped. If the width or height becomes 0, or it does not overlap the virtual screen at all, `ECCaptureError` is raised. A part that sticks out of the virtual screen is cut off, leaving only the part inside.
- With `caActiveWindow`, if there is no active window or it is minimized, `ECCaptureError` is raised.
- When the active window is the application's own, it can also be captured. However, if called from a button click, that form becomes the active window. To capture another application, wait with `Delay`.
- If the application is DPI-aware by manifest, capture uses real pixel coordinates. In a non-DPI-aware application, the coordinates are those converted by Windows (no conversion is done on the capture side).
- Because the name `Rect` clashes with the Windows `RECT` type, `Rect()` is not used inside `uCCapture` (the record fields are set directly).

## 4. TCCapture

### 4.1 Properties

| Name | Type | Access | Default | Content |
|---|---|---|---|---|
| `Image` | `TCImage` | Read | (owned by the component) | The captured picture. A picture read with `LoadFromFile` is also here. Created and destroyed by the component |
| `Area` | `TCCaptureArea` | Read/Write | `caDesktop` | Kind of range captured by `Capture` |
| `Region` | `TRect` | Read/Write (not shown at design time) | `(0, 0, 0, 0)` | Range used when `Area = caRegion` (`Left=X, Top=Y, Right=X1, Bottom=Y1`) |
| `RegionLeft`, `RegionTop`, `RegionRight`, `RegionBottom` | Integer | Read/Write | `0` | The 4 values of `Region` (shown at design time) |
| `IncludeCursor` | Boolean | Read/Write | `False` | `True` also draws the mouse cursor |
| `Delay` | Integer | Read/Write | `0` | Time to wait before capturing (milliseconds). Screen processing (`Application.ProcessMessages`) continues while waiting |
| `JpegQuality` | Integer | Read/Write | `90` | Quality when saving jpg (1-100). Out-of-range values are clamped |
| `FileName` | string | Read | empty | File name last used with `SaveToFile` or `LoadFromFile` |
| `Empty` | Boolean | Read | `True` | `True` if the captured picture (`Image`) is empty |

- `Image` is read-only. To capture into a `TCImage` you own, use `CopyTo`.
- Shown at design time (Object Inspector): `Area`, `RegionLeft`, `RegionTop`, `RegionRight`, `RegionBottom`, `IncludeCursor`, `Delay`, `JpegQuality` (`TRect` cannot be shown at design time, so it is split into 4 integers).

### 4.2 Methods

| Name | Content |
|---|---|
| `procedure Capture` | Captures with the `Area` setting. Waits for `Delay`, captures, and puts it in `Image` |
| `procedure CaptureDesktop` | Captures the whole desktop without changing `Area` |
| `procedure CaptureActiveWindow` | Captures the active window without changing `Area` |
| `procedure CaptureRegion(X, Y, X1, Y1: Integer)` | Captures the specified range without changing `Area` (rules in chapter 3) |
| `procedure SaveToFile(const AFileName: string)` | Saves `Image`. Creates the destination folder (including intermediate levels) if missing. Converts to the format of the extension (bmp to jpg, etc.). Raises `ECCaptureError` if `Image` is empty |
| `procedure LoadFromFile(const AFileName: string)` | Reads an image file into `Image`. Any format `TCImage` handles (bmp, jpg, png, svg, tif, ico) |
| `procedure Clear` | Empties `Image` |
| `procedure CopyTo(ATarget: TCImage)` | Copies the picture of `Image` to another `TCImage` |

- `CaptureDesktop`, `CaptureActiveWindow` and `CaptureRegion` also wait for `Delay`.
- Example:

```
Cap.LoadFromFile('c:\temp\123.bmp');
Cap.SaveToFile('c:\temp\123\123.jpg');   // creates c:\temp\123 if missing. Converts bmp to jpg
```

### 4.3 Events

| Name | Type | Called when |
|---|---|---|
| `OnCaptured` | `TNotifyEvent` | After the capture finishes and is put in `Image` |
| `OnSaved` | `TNotifyEvent` | After saving finishes |

### 4.4 Capture Procedure

1. If `Delay` is greater than 0, wait that long.
2. Decide the rectangle of the range (chapter 3). If it cannot be decided, `ECCaptureError`.
3. Copy from the DC of the whole screen (`GetDC(0)`) to a `TBitmap` (24-bit; the screen has no alpha) with `BitBlt` (`SRCCOPY or CAPTUREBLT`). `CAPTUREBLT` is to include semi-transparent windows.
4. If `IncludeCursor` is `True`, draw the visible cursor with `GetCursorInfo` and `DrawIconEx` at its position inside the range, using the hotspot from `GetIconInfo`. A cursor outside the range is not drawn.
5. Pass that `TBitmap` to `Image.LoadFromBitmap` and call `OnCaptured`.
6. Always `ReleaseDC` the DC (`try..finally`).

### 4.5 Save Procedure

1. If `Image` is empty, `ECCaptureError`.
2. If the folder of `ExtractFilePath` does not exist, create it with `ForceDirectories`. If it cannot be created, `ECCaptureError`.
3. Call `Image.SaveToFile(AFileName, JpegQuality)`. `TCImage` does the extension conversion and the writing (`JpegQuality` applies only to jpg).
4. A write failure passes through as `ECImageError`.
5. When written, update `FileName` and call `OnSaved`.

## 5. Errors

- `ECCaptureError = class(Exception)` is declared in `uCCapture`.
- Errors of `TCImage` reading and writing (`ECImageError`) are passed through as they are (not re-wrapped).

## 6. Registration

- Add `TCCapture` to `RegisterComponents('CX', [...])` in `source\design\uCXReg.pas`.
- Palette icons: in `source\res\cimage_icon.lrs`, together with `TCImage` and `TCImageList` (see `TCImage_Design.md`, chapter 7).

## 7. Strings

Identifiers follow the existing naming and start with `s`.

| Identifier | Japanese | English |
|---|---|---|
| `sCapNoWindow` | 取り込めるウィンドウがありません | There is no window to capture |
| `sCapBadRegion` | 取り込む範囲が正しくありません | The capture region is invalid |
| `sCapFailed` | 画面を取り込めません | Cannot capture the screen |
| `sCapNoFolder` | 保存先のフォルダーを作れません：%s | Cannot create the folder: %s |
| `sCapEmpty` | 保存する画像がありません | There is no image to save |
