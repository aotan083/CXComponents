# TCCapture 取扱説明書

作者: aotan083
日付: 2026-11-17
版: 1.0

---

## 1. 概要とクラス

デスクトップの画面を取り込み（キャプチャー）、画像ファイルに保存できる部品です。画面は持ちません（フォームに置くと、フォームの下の部品の欄に出ます）。

- 取り込む範囲は、デスクトップ全体（モニターが複数あれば、全部を含む）、アクティブなウィンドウ、任意の長方形の 3 種類です。
- 取り込んだ絵と、ファイルの読み書きは、`TCImage`（`TCImage_Usage.md`）を使っています。bmp・jpg・png・tif・ico で保存でき、拡張子の形式に変換して書きます（svg には保存できません）。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCCapture` | `uCCapture` | cx | `TComponent` | 画面を取り込んで、保存・読み込みする |
| `ECCaptureError` | `uCCapture` | cx | `Exception` | 取り込み・保存ができないときの例外 |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCCaptureArea` | `uCCapture` | `caDesktop`：デスクトップ全体、`caActiveWindow`：アクティブなウィンドウ、`caRegion`：指定の長方形 |

- フォームに置くと、uses に `uCCapture` が自動で入り、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

### 1.2 取り込む範囲

| `Area` | 取り込む範囲 |
|---|---|
| `caDesktop` | デスクトップ全体（複数のモニターを含む画面全体） |
| `caActiveWindow` | 今アクティブなウィンドウの、見える範囲（影は含めない） |
| `caRegion` | `Region`（または `CaptureRegion` の引数）で決めた長方形。画面の座標で、`X1`・`Y1` は含まない端 |

- `caRegion` で、左右・上下が逆（`X > X1` など）のときは、入れ替えて取り込みます。画面からはみ出す部分は、はみ出さない部分だけを取り込みます。
- 範囲の幅または高さが 0 のとき、画面にまったく重ならないときは、`ECCaptureError` です。
- `caActiveWindow` で、アクティブなウィンドウがない・最小化されているときは、`ECCaptureError` です。
- ボタンのクリックで取り込むと、自分のフォームがアクティブなウィンドウになります。他のアプリを取り込むときは、`Delay` で待ってから取り込みます。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCCapture をフォームに置く。
2. `Area`（取り込む範囲）を設定する。
3. コードで `Capture` を呼び、`SaveToFile` で保存する。

```pascal
CCapture1.Area := caDesktop;
CCapture1.Capture;
CCapture1.SaveToFile('C:\temp\shots\desktop.png');   // C:\temp\shots がなければ作る
```

## 3. プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Image` | `TCImage` | 読み | 取り込んだ絵（`LoadFromFile` で読んだ絵もここ）。部品が作り、部品が壊す。表示に使うなら、`CopyTo` で自分の `TCImage` に写す |
| `Area` | `TCCaptureArea` | 読み・書き | `Capture` で取り込む範囲の種類（既定値は `caDesktop`） |
| `Region` | `TRect` | 読み・書き | `Area = caRegion` のときの範囲。`Left=X`、`Top=Y`、`Right=X1`、`Bottom=Y1`。実行時だけ |
| `RegionLeft`・`RegionTop`・`RegionRight`・`RegionBottom` | `Integer` | 読み・書き | `Region` の 4 つの値（既定値は 0）。オブジェクトインスペクタで設定できる |
| `IncludeCursor` | `Boolean` | 読み・書き | `True` で、マウスカーソルも描き込む（既定値は `False`）。取り込む範囲の外のカーソルは描かない |
| `Delay` | `Integer` | 読み・書き | 取り込む前に待つ時間（ミリ秒。既定値は 0）。待つ間も、画面の処理は進む。0 より小さい値は 0 になる |
| `JpegQuality` | `Integer` | 読み・書き | jpg で保存するときの画質（1〜100。既定値は 90）。範囲外の値は丸める |
| `FileName` | `string` | 読み | 最後に `SaveToFile`・`LoadFromFile` したファイル名。取り込んだあとは空 |
| `Empty` | `Boolean` | 読み | 絵が空なら `True` |

## 4. メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Capture` | ― | ― | `Area` の設定で取り込む。`Delay` を待ってから取り込み、`Image` に入れる |
| `CaptureDesktop` | ― | ― | `Area` を変えずに、デスクトップ全体を取り込む |
| `CaptureActiveWindow` | ― | ― | `Area` を変えずに、アクティブなウィンドウを取り込む |
| `CaptureRegion` | `X, Y, X1, Y1: Integer` | ― | `Area` を変えずに、指定の範囲を取り込む |
| `SaveToFile` | `AFileName: string` | ― | `Image` を保存する。保存先のフォルダーがなければ、途中の階層も含めて作る。拡張子の形式に変換して書く。絵が空なら `ECCaptureError` |
| `LoadFromFile` | `AFileName: string` | ― | 画像ファイル（bmp・jpg・png・svg・tif・ico）を `Image` に読む |
| `Clear` | ― | ― | `Image` を空にする |
| `CopyTo` | `ATarget: TCImage` | ― | `Image` の絵を、別の `TCImage` に写す |

- `CaptureDesktop`・`CaptureActiveWindow`・`CaptureRegion` も、`Delay` を待ってから取り込みます。
- 画像の書き込みに失敗したときは、`TCImage` の例外 `ECImageError` がそのまま届きます。

## 5. イベント

| 名前 | 型 | 呼ばれるとき |
|---|---|---|
| `OnCaptured` | `TNotifyEvent` | 取り込みが終わって、`Image` に入れたあと |
| `OnSaved` | `TNotifyEvent` | 保存が終わったあと |

## 6. 使い方の例

### 6.1 読んで、別の形式で保存する

```pascal
CCapture1.LoadFromFile('C:\temp\123.bmp');
CCapture1.SaveToFile('C:\temp\123\123.jpg');   // フォルダーがなければ作る。bmp から jpg に変換
```

### 6.2 範囲を決めて取り込む

```pascal
CCapture1.CaptureRegion(100, 100, 500, 400);       // (100,100)〜(500,400)
CCapture1.SaveToFile('C:\temp\part.png');

CCapture1.Delay := 3000;                           // 3 秒待ってから、アクティブなウィンドウを取り込む
CCapture1.CaptureActiveWindow;
```

### 6.3 取り込んだ絵を画面に出す

```pascal
CCapture1.CaptureDesktop;
CCapture1.CopyTo(CImage1);     // CImage1 は TCImage
CImage1.Stretch := True;
CImage1.Proportional := True;
```

### 6.4 例外を受ける

```pascal
try
  CCapture1.CaptureActiveWindow;
  CCapture1.SaveToFile(Edit1.Text);
except
  on E: ECCaptureError do ShowMessage(E.Message);
  on E: ECImageError do ShowMessage(E.Message);
end;
```

## 7. 注意

- アプリが DPI に対応していない（マニフェストで宣言していない）ときは、Windows が換算した座標で取り込まれます。
- Windows 11 だけが対象です。隠れているウィンドウ・最小化されたウィンドウは取り込めません。
