# TCImage・TCImageList 取扱説明書

作者: aotan083
日付: 2026-11-17
版: 1.0

---

**動作環境**：Lazarus 5.0 以降（FPC 3.2.2）。Lazarus 4.8 以前は対象外。

## 1. 概要とクラス

- `TCImage`：`TImage` と同じ使い方で、bmp・jpg(jpeg)・png・svg・tif(tiff)・ico を扱える画像部品です。
- `TCImageList`：`TImageList` と同じ使い方の画像リストです。画像ファイル・`TCImage`・フォルダーから、画像を足せます。

| 項目 | 内容 |
|---|---|
| Lazarus | 5.0RC1 以降 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCImage` | `uCImages` | cx | `TImage` | 6 種類の画像を扱う画像部品 |
| `TCImageList` | `uCImages` | cx | `TImageList` | 画像を足す方法が増えた画像リスト |
| `ECImageError` | `uCImages` | cx | `Exception` | 読み書きができないときの例外 |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCImageFormat` | `uCImages` | `cifNone`、`cifBmp`、`cifJpeg`、`cifPng`、`cifTiff`、`cifIcon`、`cifSvg` |

- フォームに置くと、uses に `uCImages` が自動で入り、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

### 1.2 扱える形式

| 拡張子 | 読む | 書く |
|---|---|---|
| .bmp | ○ | ○ |
| .jpg .jpeg | ○ | ○ |
| .png | ○ | ○ |
| .tif .tiff | ○ | ○ |
| .ico | ○ | ○ |
| .svg | ○ | × |

- 形式は、拡張子（大文字小文字は区別しない）で決めます。上の表にない拡張子（gif など）は、読むことも書くこともできません（`ECImageError`）。
- 書くときは、元の絵がどの形式でも、保存先の拡張子の形式に変換して書きます（例：bmp を読んで、jpg で保存）。
- 透明（png・tif・ico・svg）は、透明を持てる形式（bmp・png・tif・ico）で保存すると、そのまま残ります。jpg は透明を持てないので、透明の部分は白になります。
- ico は 256×256 まで。それより大きい絵は、縦横比を保って 256 以内に縮めて書きます。
- svg は読み込みだけです。保存先に svg を指定すると `ECImageError` になります。svg の中の文字（`<text>`）は描かれません。図形・パスは描けます。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCImage をフォームに置く。
2. オブジェクトインスペクタの `Picture` で、画像を選ぶ（bmp・jpg・png・svg・tif・ico）。
3. コードで読み込むときは、`LoadFromFile` を呼ぶ。

```pascal
CImage1.LoadFromFile('C:\temp\logo.svg');
CImage1.Stretch := True;
CImage1.Proportional := True;
```

## 3. TCImage

`TImage` の子クラスです。`TImage` のプロパティ・メソッド・イベント（`Picture`・`Stretch`・`Proportional`・`Center`・`Transparent`・`AutoSize`・`OnClick` など）は、そのまま使えます。ここでは、足したものだけを書きます。

### 3.1 プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `FileName` | `string` | 読み | 最後に `LoadFromFile`・`SaveToFile` したファイル名。`LoadFromBitmap` で絵を入れたあとは空 |
| `ImageFormat` | `TCImageFormat` | 読み | 今の絵の形式。絵がなければ `cifNone`。`SaveToFile` で別の形式に書いても、今の絵の形式は変わらない |

### 3.2 メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `LoadFromFile` | `AFileName: string` | ― | 拡張子から形式を選んで読む。読めなければ `ECImageError`（今の絵は元のまま） |
| `SaveToFile` | `AFileName: string; AJpegQuality: Integer = 90` | ― | 保存先の拡張子の形式で書く。フォルダーがなければ作る。`AJpegQuality`（1〜100）は jpg のときだけ使う。絵が空なら `ECImageError` |
| `LoadFromBitmap` | `ABitmap: TBitmap` | ― | `TBitmap` の中身を絵にする。`nil` なら絵を消す |
| `ToBitmap` | ― | `TBitmap` | 今の絵を、32 ビット（透明つき）の `TBitmap` にして返す。呼んだ側が `Free` する。絵が空なら、空の `TBitmap` |
| `IsSupportedFile`（クラスメソッド） | `AFileName: string` | `Boolean` | 拡張子が 1.2 の表にあれば `True` |
| `FormatOfFile`（クラスメソッド） | `AFileName: string` | `TCImageFormat` | 拡張子から形式を返す。なければ `cifNone` |

- `LoadFromFile` は、いったん別の場所に読んでから絵を入れ替えます。読めなかったときに、今の絵は壊れません。
- `SaveToFile` は、いったんメモリに書いてからファイルに写します。変換に失敗しても、すでにあるファイルは壊れません。書き込みに失敗したときは `ECImageError` です。

### 3.3 イベント

`TImage` のものだけです。足したものはありません。

### 3.4 使い方の例

```pascal
// bmp を読んで、フォルダーを作って jpg（画質 80）で保存する
CImage1.LoadFromFile('C:\temp\123.bmp');
CImage1.SaveToFile('C:\temp\out\123.jpg', 80);   // C:\temp\out がなければ作る

// 例外を受ける
try
  CImage1.LoadFromFile(Edit1.Text);
except
  on E: ECImageError do ShowMessage(E.Message);
end;
```

## 4. TCImageList

`TImageList` の子クラスです。`TImageList` のプロパティ・メソッド・イベント（`Width`・`Height`・`Count`・`Add`・`Draw`・`GetBitmap` など）は、そのまま使えます。ここでは、足したものだけを書きます。

### 4.1 メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `AddFromFile` | `AFileName: string` | `Integer` | 画像ファイルを 1 枚、`Width`×`Height` に合わせて足す。足した位置を返す。読めなければ `ECImageError` |
| `AddFromImage` | `AImage: TCImage` | `Integer` | `TCImage` の絵を、`Width`×`Height` に合わせて足す。足した位置を返す。絵が空なら `ECImageError` |
| `AddFromFolder` | `AFolder: string; ARecursive: Boolean = False` | `Integer` | フォルダーの中の 1.2 の形式のファイルを、ファイル名順にすべて足す。足した数を返す。読めないファイルは飛ばす。`ARecursive` が `True` なら、サブフォルダーの中も足す（親のフォルダーのファイルが先） |
| `SaveItemToFile` | `AIndex: Integer; AFileName: string` | ― | 指定の 1 枚を、`TCImage.SaveToFile` と同じ規則でファイルに書く。位置が範囲外なら `ECImageError` |

### 4.2 足すときの規則

- 絵が `Width`×`Height` と大きさが違うときは、縦横比を保って縮小（拡大）し、中央に置きます。余白は透明です。
- 透明（png のアルファ・ico・svg）は、保たれます。
- svg は、最初から目的の大きさで描くので、縮小しても荒れません。
- `Width`・`Height` は、先に決めておきます（初期値は 16）。

### 4.3 使い方の例

```pascal
// フォルダーの中のアイコンを一覧にして、TCPageControl のタブに使う
CImageList1.Width := 24;
CImageList1.Height := 24;
CImageList1.AddFromFolder('C:\app\icons');
CPageControl1.Images := CImageList1;

// 1 枚ずつ足す
I := CImageList1.AddFromFile('C:\app\icons\home.svg');
```

## 5. ほかの部品との組み合わせ

`TCImageList` は `TImageList` の子クラスなので、`TImageList`・`TCustomImageList` 型のプロパティに、そのまま選んで使えます（オブジェクトインスペクタの一覧にも出ます）。

| 部品 | プロパティ |
|---|---|
| `TCPageControl` | `Images`（タブのアイコン） |
| `TCSideBar` | `Images` |
| `TCExpandPanel`（`TCRollout`） | `Images` |
| `TCMonacoEditor` | `TabImages` |
| `TCsEditor` | `TabImages` |

## 6. 注意

- svg の中の文字は描かれません（図形・パスだけ）。
- 読み書きの失敗は、`ECImageError` です。メッセージは、アプリの言語（日本語・英語）に合わせて出ます。
