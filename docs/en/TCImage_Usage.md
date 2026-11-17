# TCImage / TCImageList User Manual

Author: aotan083
Date: 2026-11-17
Version: 1.0

---

## 1. Overview and Classes

- `TCImage`: an image component used just like `TImage`, which handles bmp, jpg (jpeg), png, svg, tif (tiff) and ico.
- `TCImageList`: an image list used just like `TImageList`. Images can be added from image files, a `TCImage`, or a folder.

| Item | Content |
|---|---|
| Lazarus | 4.8, 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Description |
|---|---|---|---|---|
| `TCImage` | `uCImages` | cx | `TImage` | Image component that handles 6 kinds of images |
| `TCImageList` | `uCImages` | cx | `TImageList` | Image list with more ways to add images |
| `ECImageError` | `uCImages` | cx | `Exception` | Exception raised when reading or writing fails |

| Type | Unit | Description |
|---|---|---|
| `TCImageFormat` | `uCImages` | `cifNone`, `cifBmp`, `cifJpeg`, `cifPng`, `cifTiff`, `cifIcon`, `cifSvg` |

- When placed on a form, `uCImages` is added to uses automatically, and cx is added to the project's required packages automatically.
- When creating it in code, write it in uses yourself.

### 1.2 Supported Formats

| Extension | Read | Write |
|---|---|---|
| .bmp | Yes | Yes |
| .jpg .jpeg | Yes | Yes |
| .png | Yes | Yes |
| .tif .tiff | Yes | Yes |
| .ico | Yes | Yes |
| .svg | Yes | No |

- The format is decided by the extension (case-insensitive). Files with an extension not in the table (such as gif) can be neither read nor written (`ECImageError`).
- When writing, the picture is converted to the format of the destination extension, whatever the original format (example: read a bmp, save as jpg).
- Transparency (png, tif, ico, svg) is kept when saving to a format that can hold it (bmp, png, tif, ico). jpg cannot hold transparency, so transparent areas become white.
- ico is limited to 256x256. Larger pictures are shrunk to fit within 256, keeping the aspect ratio.
- svg is read-only. Specifying svg as the destination raises `ECImageError`. Text inside svg (`<text>`) is not drawn. Shapes and paths are drawn.

## 2. Placing It on a Form

1. Place TCImage on the form from the [CX] palette.
2. Choose an image in `Picture` in the Object Inspector (bmp, jpg, png, svg, tif, ico).
3. To load in code, call `LoadFromFile`.

```pascal
CImage1.LoadFromFile('C:\temp\logo.svg');
CImage1.Stretch := True;
CImage1.Proportional := True;
```

## 3. TCImage

A subclass of `TImage`. The properties, methods and events of `TImage` (`Picture`, `Stretch`, `Proportional`, `Center`, `Transparent`, `AutoSize`, `OnClick`, and so on) can be used as they are. Only the additions are described here.

### 3.1 Properties

| Name | Type | Access | Description |
|---|---|---|---|
| `FileName` | `string` | Read | The file name last used with `LoadFromFile` or `SaveToFile`. Empty after a picture is set with `LoadFromBitmap` |
| `ImageFormat` | `TCImageFormat` | Read | Format of the current picture. `cifNone` if there is no picture. Saving in another format with `SaveToFile` does not change it |

### 3.2 Methods

| Name | Arguments | Returns | Description |
|---|---|---|---|
| `LoadFromFile` | `AFileName: string` | - | Reads, choosing the format from the extension. Raises `ECImageError` if it cannot be read (the current picture stays as it was) |
| `SaveToFile` | `AFileName: string; AJpegQuality: Integer = 90` | - | Writes in the format of the destination extension. Creates the folder if it does not exist. `AJpegQuality` (1-100) is used only for jpg. Raises `ECImageError` if the picture is empty |
| `LoadFromBitmap` | `ABitmap: TBitmap` | - | Makes the contents of the `TBitmap` the picture. `nil` clears the picture |
| `ToBitmap` | - | `TBitmap` | Returns the current picture as a 32-bit `TBitmap` (with transparency). The caller must `Free` it. An empty `TBitmap` if the picture is empty |
| `IsSupportedFile` (class method) | `AFileName: string` | `Boolean` | `True` if the extension is in the table in 1.2 |
| `FormatOfFile` (class method) | `AFileName: string` | `TCImageFormat` | Returns the format from the extension. `cifNone` if none |

- `LoadFromFile` first reads into a separate place and then swaps the picture, so the current picture is not damaged when reading fails.
- `SaveToFile` first writes to memory and then copies to the file, so an existing file is not damaged when the conversion fails. When writing fails, `ECImageError` is raised.

### 3.3 Events

Only those of `TImage`. Nothing has been added.

### 3.4 Examples

```pascal
// Read a bmp, create the folder, and save as jpg (quality 80)
CImage1.LoadFromFile('C:\temp\123.bmp');
CImage1.SaveToFile('C:\temp\out\123.jpg', 80);   // creates C:\temp\out if missing

// Handle the exception
try
  CImage1.LoadFromFile(Edit1.Text);
except
  on E: ECImageError do ShowMessage(E.Message);
end;
```

## 4. TCImageList

A subclass of `TImageList`. The properties, methods and events of `TImageList` (`Width`, `Height`, `Count`, `Add`, `Draw`, `GetBitmap`, and so on) can be used as they are. Only the additions are described here.

### 4.1 Methods

| Name | Arguments | Returns | Description |
|---|---|---|---|
| `AddFromFile` | `AFileName: string` | `Integer` | Adds one image file, fitted to `Width` x `Height`. Returns the position added. Raises `ECImageError` if it cannot be read |
| `AddFromImage` | `AImage: TCImage` | `Integer` | Adds the picture of a `TCImage`, fitted to `Width` x `Height`. Returns the position added. Raises `ECImageError` if the picture is empty |
| `AddFromFolder` | `AFolder: string; ARecursive: Boolean = False` | `Integer` | Adds all files of the formats in 1.2 in the folder, in file-name order. Returns the number added. Files that cannot be read are skipped. If `ARecursive` is `True`, subfolders are included (files of the parent folder come first) |
| `SaveItemToFile` | `AIndex: Integer; AFileName: string` | - | Writes one picture to a file by the same rules as `TCImage.SaveToFile`. Raises `ECImageError` if the position is out of range |

### 4.2 Rules When Adding

- A picture whose size differs from `Width` x `Height` is shrunk (or enlarged) keeping the aspect ratio and placed in the center. The margin is transparent.
- Transparency (png alpha, ico, svg) is kept.
- svg is drawn at the target size from the start, so it does not get rough when shrunk.
- Decide `Width` and `Height` beforehand (the initial value is 16).

### 4.3 Examples

```pascal
// Make a list from the icons in a folder and use it for the tabs of a TCPageControl
CImageList1.Width := 24;
CImageList1.Height := 24;
CImageList1.AddFromFolder('C:\app\icons');
CPageControl1.Images := CImageList1;

// Add one at a time
I := CImageList1.AddFromFile('C:\app\icons\home.svg');
```

## 5. Combining with Other Components

`TCImageList` is a subclass of `TImageList`, so it can be chosen as it is for properties of type `TImageList` or `TCustomImageList` (it also appears in the Object Inspector list).

| Component | Property |
|---|---|
| `TCPageControl` | `Images` (tab icons) |
| `TCSideBar` | `Images` |
| `TCExpandPanel` (`TCRollout`) | `Images` |
| `TCMonacoEditor` | `TabImages` |
| `TCsEditor` | `TabImages` |

## 6. Notes

- Text inside svg is not drawn (shapes and paths only).
- A failure in reading or writing raises `ECImageError`. The message follows the application's language (Japanese or English).
