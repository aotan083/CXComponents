# TCImage / TCImageList Design Document

Author: aotan083
Date: 2026-11-17
Version: 1.0

---

## 1. Purpose and Policy

- `TCImage`: an image component used just like `TImage`, which handles bmp, jpg (jpeg), png, svg, tif (tiff) and ico.
- `TCImageList`: an image list used just like `TImageList`. Images can be made from a `TCImage` or an image file and put in it.
- `TCCapture` (`TCCapture_Design.md`) uses `TCImage` to capture and save the screen.
- The supported format is decided by the extension (case-insensitive).

### 1.1 Out of Scope

- Writing svg (read-only. Specifying svg as the destination is an error).
- Formats other than the 6 above, such as gif and webp.
- Animation.
- Linux and macOS (Windows 11 only).

## 2. Files and Packages

| File | Package | Content |
|---|---|---|
| `uCImages.pas` | cx (run time) | `TCImage`, `TCImageList` |
| `uCXReg.pas` (`source\design`) | cxdsgn (design time) | Registration on the [CX] palette |
| `fpsvg.fonts.provider.pas` | cx (run time) | Substitute unit for svg (below) |
| `uCXLang.pas` | cx (run time) | Adds error strings (chapter 6) |

- uses of `uCImages`: `Classes, SysUtils, Types, Math, Graphics, Controls, ExtCtrls, ImgList, IntfGraphics, FPImage, FPWriteTiff, GraphType, LCLType, LCLIntf, SVGImg, uCXLang`.
- svg is read with `SVGImg` (`TSVGGraphic`) and the `fcl-svg` and `fcl-css` sources that come with Lazarus. The `SVGImgLaz` package cannot be compiled with FPC 3.2.2 (`fpsvg.gdi`), so it is not made a required package. `$(LazarusDir)/components/svgimage`, `svgimage/fcl-svg` and `svgimage/fcl-css` are added to `OtherUnitFiles` of package cx and compiled together from source.
- One unit is added: `source\fpsvg.fonts.provider.pas` (a substitute unit that has no font provider; `source` is placed at the head of the search path so it is found before the same-named unit that comes with Lazarus). The freetype version is not used because the exe will not start without freetype.dll.
- As a result, "text" inside svg is not drawn. Shapes and paths are drawn.
- No initialization or finalization.
- The packages remain the two: cx and cxdsgn.

## 3. Supported Formats

| Extension | Read | Write | Class used |
|---|---|---|---|
| .bmp | Yes | Yes | `TBitmap` |
| .jpg .jpeg | Yes | Yes | `TJPEGImage` |
| .png | Yes | Yes | `TPortableNetworkGraphic` |
| .tif .tiff | Yes | Yes | `TTiffImage` |
| .ico | Yes | Yes | `TIcon` |
| .svg | Yes | No | `TSVGGraphic` |

- Reading uses the mechanism by which `TPicture` chooses by extension as it is (svg is also registered because `uCImages` uses `SVGImg`).
- Reading or writing a file whose extension is not in the table raises `ECImageError`.
- When writing, the picture is converted to the format of the destination extension, whatever the original format (bmp to jpg, etc.). The conversion first makes a `TBitmap` (32-bit, transparency kept). bmp is written with `TBitmap`, jpg with `TJPEGImage` (`Assign`). png is written directly with alpha by `TLazWriterPNG` (`UseAlpha`), and tif by `TFPWriterTiff` (because `Assign` of `TPortableNetworkGraphic` or `TTiffImage` can drop alpha or break the tag order [`fpwritetiff` of FPC 3.2.2]). ico is written with `TIcon` (`Assign`). Writing goes to memory first, then is copied to a file opened with `CXCreateFileShared`.
- jpg has no transparency, so transparent areas are painted white.
- ico is limited to 256x256. Larger pictures are shrunk to 256, keeping the aspect ratio.
- The size after reading svg is the svg `width` and `height` (or `viewBox` if absent). When drawn to fit the size of a `TCImage`, it follows the `Stretch` setting.

## 4. TCImage

A subclass of `TImage`. The properties, methods and events of `TImage` can be used as they are. The additions are as follows.

### 4.1 Properties

| Name | Type | Access | Content |
|---|---|---|---|
| `FileName` | string | Read | File name last read with `LoadFromFile`. Empty if nothing was read |
| `ImageFormat` | `TCImageFormat` | Read | Format of the current picture (`cifNone, cifBmp, cifJpeg, cifPng, cifTiff, cifIcon, cifSvg`) |

- `TCImageFormat` is declared in `uCImages`.

### 4.2 Methods

| Name | Content |
|---|---|
| `procedure LoadFromFile(const AFileName: string)` | Reads, choosing the format from the extension. Same as `Picture.LoadFromFile`, but it checks the format (chapter 3) and remembers `FileName` |
| `procedure SaveToFile(const AFileName: string; AJpegQuality: Integer = 90)` | `AJpegQuality` (1-100) is used only for jpg. Writes in the format of the destination extension (chapter 3). Creates the destination folder if it does not exist. Raises `ECImageError` if the picture is empty |
| `procedure LoadFromBitmap(ABitmap: TBitmap)` | Makes the contents of the `TBitmap` the picture (used by `TCCapture`) |
| `function ToBitmap: TBitmap` | Returns the current picture as a 32-bit `TBitmap`. The caller `Free`s it |
| `class function IsSupportedFile(const AFileName: string): Boolean` | `True` if the extension is in the table in chapter 3 |
| `class function FormatOfFile(const AFileName: string): TCImageFormat` | Returns the format from the extension. `cifNone` if none |

### 4.3 Events

Only those of `TImage`. Nothing is added.

### 4.4 Behavior

- `Picture`, `Stretch`, `Proportional`, `Center`, `Transparent`, `AutoSize` and so on behave as in `TImage`.
- When `LoadFromFile` cannot read, the picture is left as it was and `ECImageError` is raised.
- When `SaveToFile` fails to write (write-protected, etc.), the half-written file is deleted and `ECImageError` is raised.

## 5. TCImageList

A subclass of `TImageList`. The properties, methods and events of `TImageList` can be used as they are. The additions are as follows.

### 5.1 Methods

| Name | Content |
|---|---|
| `function AddFromFile(const AFileName: string): Integer` | Reads one image file and adds it, fitted to `Width` x `Height`. Returns the position added |
| `function AddFromImage(AImage: TCImage): Integer` | Adds the picture of a `TCImage`, fitted to `Width` x `Height`. Returns the position added |
| `function AddFromFolder(const AFolder: string; ARecursive: Boolean = False): Integer` | Adds all files of the chapter 3 formats in the folder, in file-name order. Returns the number added |
| `procedure SaveItemToFile(AIndex: Integer; const AFileName: string)` | Writes one picture by the same rules as `TCImage.SaveToFile` |

### 5.2 Behavior

- When a picture differs in size from `Width` x `Height`, it is shrunk (or enlarged) keeping the aspect ratio and placed in the center. The margin is transparent.
- Transparency (png alpha, ico, svg) is kept. svg is drawn at the target size from the start.
- If `Width` and `Height` are still the initial value (16), the images become 16x16 as they are. The caller decides them beforehand.
- When a file cannot be read, `AddFromFile` raises `ECImageError`. `AddFromFolder` skips files that cannot be read and continues (only the number added is returned).

### 5.3 Combining with Existing Components

- `TCImageList` is a subclass of `TImageList`, so it can be chosen as it is for properties of type `TImageList` or `TCustomImageList` (it also appears in the Object Inspector list). The code of the existing components is not changed.

| Component | Property | Type |
|---|---|---|
| `TCPageControl` | `Images` | `TCustomImageList` |
| `TCSideBar` | `Images` | `TCustomImageList` |
| `TCExpandPanel` (`TCRollout`) | `Images` | `TCustomImageList` |
| `TCMonacoEditor` | `TabImages` | `TImageList` |
| `TCsEditor` | `TabImages` | `TImageList` |

- How to check: in a test application (under `test\`), assign a `TCImageList` to `TCPageControl` and `TCSideBar` and confirm that the icons appear.
- Usage examples are in the user manual (`TCImage_Usage.md`).

## 6. Errors and Strings

- `ECImageError = class(Exception)` is declared in `uCImages`.
- Strings shown on screen or put in exceptions are added to `uCXLang` in Japanese and English (identifiers follow the existing naming and start with `s`).

| Identifier | Japanese | English |
|---|---|---|
| `sImgUnsupported` | 扱えない画像形式です：%s | Unsupported image format: %s |
| `sImgLoadFailed` | 画像を読めません：%s | Cannot load image: %s |
| `sImgSaveFailed` | 画像を保存できません：%s | Cannot save image: %s |
| `sImgEmpty` | 保存する画像がありません | There is no image to save |
| `sImgSvgWrite` | svg は保存できません | SVG cannot be saved |

## 7. Registration

- Add `TCImage` and `TCImageList` to `RegisterComponents('CX', [...])` in `source\design\uCXReg.pas`.
- Palette icons: `source\res\cimage_icon.lrs` (made with `lazres` from the 24, 36 and 48 px PNGs of `TCImage`, `TCImageList` and `TCCapture`; the source pictures are made with `test\make_image_icons.ps1`). Add it to the required files (LRS) of `cxdsgn.lpk`, and read `{$I cimage_icon.lrs}` in the `initialization` of `uCXReg`.
