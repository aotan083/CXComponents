# TCCapture 設計書

作者: aotan083
日付: 2026-11-17
版: 1.0

---

**動作環境**：Lazarus 5.0 以降（FPC 3.2.2）。Lazarus 4.8 以前は対象外。

## 1. 目的と方針

- デスクトップの画面を取り込み（キャプチャー）、画像ファイルに保存できる部品（`TCCapture`）。
- 取り込んだ絵と、ファイルの読み書きは、`TCImage`（`TCImage_Design.md`）を使う。
- 画面に見えない部品（`TComponent` の子）。フォームに置くか、コードで作って使う。

### 1.1 含めないもの

- 動画の録画。
- 隠れているウィンドウ・最小化されたウィンドウの取り込み。
- 時間間隔での連続取り込み。
- 範囲を画面上でマウスで選ぶ操作（座標を渡す）。
- Linux・macOS（Windows 11 だけ）。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCCapture.pas` | cx（実行時） | `TCCapture` |
| `uCImages.pas` | cx（実行時） | `TCImage`（`TCImage_Design.md`） |
| `uCXReg.pas`（`source\design`） | cxdsgn（設計時） | パレット [CX] への登録 |
| `uCXLang.pas` | cx（実行時） | 文字列を足す（7 章） |

- `uCCapture` の uses：`Classes, SysUtils, Types, Math, Windows, Graphics, Controls, Forms, LCLType, LCLIntf, uCImages, uCXLang`。
- 「アクティブなウィンドウの枠の取得」に `DwmGetWindowAttribute`（`dwmapi.dll`）を使う。`LoadLibrary` で実行時に探し、無ければ `GetWindowRect` に切り替える。
- initialization・finalization は持たない。
- パッケージは、cx と cxdsgn の 2 つのまま。

## 3. 範囲の種類

```
TCCaptureArea = (caDesktop, caActiveWindow, caRegion);
```

| 値 | 取り込む範囲 |
|---|---|
| `caDesktop` | デスクトップ全体。複数のモニターがあれば、全部を含む仮想画面（`SM_XVIRTUALSCREEN` から `SM_CXVIRTUALSCREEN`×`SM_CYVIRTUALSCREEN`） |
| `caActiveWindow` | 今アクティブなウィンドウ（`GetForegroundWindow`）の見える範囲。影を除いた枠（`DWMWA_EXTENDED_FRAME_BOUNDS`）。取れないときは `GetWindowRect` |
| `caRegion` | 指定した長方形（`X, Y, X1, Y1`）。画面（仮想画面）の座標。`X1`・`Y1` は含まない端（`TRect` の `Right`・`Bottom` と同じ） |

- `caRegion` で、`X > X1` や `Y > Y1` のときは入れ替えて受ける。幅または高さが 0 になる、または仮想画面にまったく重ならないときは、`ECCaptureError` を出す。仮想画面をはみ出す部分は、はみ出さない部分だけにする。
- `caActiveWindow` で、アクティブなウィンドウが無い・最小化されているときは、`ECCaptureError` を出す。
- アクティブなウィンドウが自分のアプリのときも、取り込める。ただし、ボタンのクリックで呼ぶと、そのフォームがアクティブなウィンドウになる。他のアプリを取り込むなら、`Delay` で待つ。
- `Rect` という名前は Windows の `RECT` 型と重なるので、`uCCapture` の中では `Rect()` を使わない（レコードの項目を直接設定する）。
- アプリがマニフェストで DPI 対応にしていれば、実際の画素の座標で取り込む。DPI 非対応のアプリでは、Windows が換算した座標になる（取り込み側では換算しない）。

## 4. TCCapture

### 4.1 プロパティ

| 名前 | 型 | 読み書き | 既定 | 中身 |
|---|---|---|---|---|
| `Image` | `TCImage` | 読み | （部品が持つ） | 取り込んだ絵。読み込み（`LoadFromFile`）した絵もここ。部品が作り、部品が壊す |
| `Area` | `TCCaptureArea` | 読み書き | `caDesktop` | `Capture` で取り込む範囲の種類 |
| `Region` | `TRect` | 読み書き（設計時には出さない） | `(0, 0, 0, 0)` | `Area = caRegion` のときの範囲（`Left=X, Top=Y, Right=X1, Bottom=Y1`） |
| `RegionLeft`・`RegionTop`・`RegionRight`・`RegionBottom` | Integer | 読み書き | `0` | `Region` の 4 つの値（設計時に出す） |
| `IncludeCursor` | Boolean | 読み書き | `False` | `True` で、マウスカーソルも描き込む |
| `Delay` | Integer | 読み書き | `0` | 取り込む前に待つ時間（ミリ秒）。待つ間も画面の処理（`Application.ProcessMessages`）は進める |
| `JpegQuality` | Integer | 読み書き | `90` | jpg で保存するときの画質（1〜100）。範囲外は丸める |
| `FileName` | string | 読み | 空 | 最後に `SaveToFile`・`LoadFromFile` したファイル名 |
| `Empty` | Boolean | 読み | `True` | 取り込んだ絵（`Image`）が空なら `True` |

- `Image` は読み取りだけ。`TCImage` を別に持っていて、そこへ取り込みたいときは、`CopyTo` を使う。
- 設計時（オブジェクトインスペクター）に出すのは `Area`・`RegionLeft`・`RegionTop`・`RegionRight`・`RegionBottom`・`IncludeCursor`・`Delay`・`JpegQuality`（`TRect` は設計時に出せないため、4 つの整数に分ける）。

### 4.2 メソッド

| 名前 | 中身 |
|---|---|
| `procedure Capture` | `Area` の設定で取り込む。`Delay` を待ってから取り込み、`Image` に入れる |
| `procedure CaptureDesktop` | `Area` を変えずに、デスクトップ全体を取り込む |
| `procedure CaptureActiveWindow` | `Area` を変えずに、アクティブなウィンドウを取り込む |
| `procedure CaptureRegion(X, Y, X1, Y1: Integer)` | `Area` を変えずに、指定の範囲を取り込む（3 章の規則） |
| `procedure SaveToFile(const AFileName: string)` | `Image` を保存する。保存先のフォルダーが無ければ作る（途中の階層も）。拡張子の形式に変換して書く（bmp → jpg など）。`Image` が空なら `ECCaptureError` |
| `procedure LoadFromFile(const AFileName: string)` | 画像ファイルを `Image` に読む。`TCImage` が扱える形式（bmp・jpg・png・svg・tif・ico） |
| `procedure Clear` | `Image` を空にする |
| `procedure CopyTo(ATarget: TCImage)` | `Image` の絵を、別の `TCImage` に写す |

- `CaptureDesktop`・`CaptureActiveWindow`・`CaptureRegion` も、`Delay` を待つ。
- 例：

```
Cap.LoadFromFile('c:\temp\123.bmp');
Cap.SaveToFile('c:\temp\123\123.jpg');   // c:\temp\123 が無ければ作る。bmp から jpg に変換
```

### 4.3 イベント

| 名前 | 型 | 呼ばれるとき |
|---|---|---|
| `OnCaptured` | `TNotifyEvent` | 取り込みが終わって `Image` に入れたあと |
| `OnSaved` | `TNotifyEvent` | 保存が終わったあと |

### 4.4 取り込みの手順

1. `Delay` が 0 より大きければ、その間待つ。
2. 範囲の長方形を決める（3 章）。決まらなければ `ECCaptureError`。
3. 画面全体の DC（`GetDC(0)`）から、画面の画像の `TBitmap`（24 ビット。画面にはアルファが無い）に `BitBlt`（`SRCCOPY or CAPTUREBLT`）で写す。`CAPTUREBLT` は、半透明のウィンドウも含めるため。
4. `IncludeCursor` が `True` なら、`GetCursorInfo` で表示中のカーソルを `DrawIconEx` で、範囲内の位置に描き込む。範囲の外のカーソルは描かない。
5. その `TBitmap` を `Image.LoadFromBitmap` で渡し、`OnCaptured` を呼ぶ。
6. DC は、必ず `ReleaseDC` する（`try..finally`）。

### 4.5 保存の手順

1. `Image` が空なら `ECCaptureError`。
2. `ExtractFilePath` のフォルダーが無ければ `ForceDirectories` で作る。作れなければ `ECCaptureError`。
3. `Image.SaveToFile(AFileName, JpegQuality)` を呼ぶ。拡張子の変換と書き込みは `TCImage` が行う（`JpegQuality` は jpg のときだけ効く）。
4. 書き込みの失敗は `ECImageError` のまま通す。
5. 書けたら `FileName` を更新し、`OnSaved` を呼ぶ。

## 5. エラー

- `ECCaptureError = class(Exception)` を `uCCapture` に宣言する。
- `TCImage` の読み書きのエラー（`ECImageError`）は、そのまま通す（包み直さない）。

## 6. 登録

- `source\design\uCXReg.pas` の `RegisterComponents('CX', [...])` に `TCCapture` を足す。
- パレットのアイコンは、`source\res\cimage_icon.lrs`（`TCImage`・`TCImageList`・`TCCapture` の 24・36・48px の PNG から `lazres` で作る。元の絵は `test\make_image_icons.ps1` で作る）。`cxdsgn.lpk` の必要ファイル（LRS）に足し、`uCXReg` の `initialization` で `{$I cimage_icon.lrs}` を読む。

## 7. 文字列

| 識別子 | 日本語 | 英語 |
|---|---|---|
| `sCapNoWindow` | 取り込めるウィンドウがありません | There is no window to capture |
| `sCapBadRegion` | 取り込む範囲が正しくありません | The capture region is invalid |
| `sCapFailed` | 画面を取り込めません | Cannot capture the screen |
| `sCapNoFolder` | 保存先のフォルダーを作れません：%s | Cannot create the folder: %s |
| `sCapEmpty` | 保存する画像がありません | There is no image to save |
