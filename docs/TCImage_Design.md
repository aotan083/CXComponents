# TCImage・TCImageList 設計書

作者: aotan083
日付: 2026-11-17
版: 1.0

---

**動作環境**：Lazarus 5.0 以降（FPC 3.2.2）。Lazarus 4.8 以前は対象外。

## 1. 目的と方針

- `TCImage`：`TImage` と同じ使い方で、bmp・jpg(jpeg)・png・svg・tif(tiff)・ico を扱える画像部品。
- `TCImageList`：`TImageList` と同じ使い方の画像リスト。`TCImage`・画像ファイルから画像を作って入れられる。
- `TCCapture`（`TCCapture_Design.md`）が、画面の取り込みと保存に `TCImage` を使う。
- 扱える形式の判定は、拡張子（大文字小文字は区別しない）で行う。

### 1.1 含めないもの

- svg の書き出し（読み込みだけ。保存先に svg を指定したらエラー）。
- gif・webp など上の 6 種以外の形式。
- アニメーション。
- Linux・macOS（Windows 11 だけ）。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCImages.pas` | cx（実行時） | `TCImage`・`TCImageList` |
| `uCXReg.pas`（`source\design`） | cxdsgn（設計時） | パレット [CX] への登録 |
| `fpsvg.fonts.provider.pas` | cx（実行時） | svg 用の代替ユニット（下記） |
| `uCXLang.pas` | cx（実行時） | エラー文字列を足す（6 章） |

- `uCImages` の uses：`Classes, SysUtils, Types, Math, Graphics, Controls, ExtCtrls, ImgList, IntfGraphics, FPImage, FPWriteTiff, GraphType, LCLType, LCLIntf, SVGImg, uCXLang`。
- svg は、Lazarus 付属の `SVGImg`（`TSVGGraphic`）と `fcl-svg`・`fcl-css` のソースで読む。`SVGImgLaz` パッケージは、FPC 3.2.2 でコンパイルできない（`fpsvg.gdi`）ので、必須パッケージにしない。パッケージ cx の `OtherUnitFiles` に、`$(LazarusDir)/components/svgimage`・`svgimage/fcl-svg`・`svgimage/fcl-css` を足して、ソースから一緒にコンパイルする。
- `source\fpsvg.fonts.provider.pas`（フォントの提供元を持たない代替ユニット。付属の同名ユニットより先に見つかるよう、`source` を検索パスの先頭に置く）を、1 つ足す。freetype 版は freetype.dll が無いと exe が起動しないので使わない。
- そのため、svg の中の「文字」は描かれない。図形・パスは描ける。
- initialization・finalization は持たない。
- パッケージは、cx と cxdsgn の 2 つのまま。

## 3. 扱える形式

| 拡張子 | 読む | 書く | 使うクラス |
|---|---|---|---|
| .bmp | ○ | ○ | `TBitmap` |
| .jpg .jpeg | ○ | ○ | `TJPEGImage` |
| .png | ○ | ○ | `TPortableNetworkGraphic` |
| .tif .tiff | ○ | ○ | `TTiffImage` |
| .ico | ○ | ○ | `TIcon` |
| .svg | ○ | × | `TSVGGraphic` |

- 読み込みは、`TPicture` が拡張子から選ぶ仕組みをそのまま使う（`uCImages` が `SVGImg` を uses することで svg も登録される）。
- 拡張子が上の表に無いファイルを読んだり書いたりしたら、`ECImageError` を出す。
- 書くときは、元の絵の形式に関係なく、保存先の拡張子の形式に変換する（bmp → jpg など）。変換は、いったん `TBitmap`（32 ビット・透明を保つ）にしてから行う。bmp は `TBitmap`、jpg は `TJPEGImage`（`Assign`）で書く。png は `TLazWriterPNG`（`UseAlpha`）、tif は `TFPWriterTiff` で、アルファ付きのまま直接書く（`TPortableNetworkGraphic`・`TTiffImage` の `Assign` は、アルファを落とす・タグの順序が崩れる〔FPC 3.2.2 の `fpwritetiff`〕ことがあるため）。ico は `TIcon`（`Assign`）で書く。書き込みは、いったんメモリに書いてから、`CXCreateFileShared` で開いたファイルに写す。
- jpg には透明が無いので、透明の部分は白で塗る。
- ico は 256×256 まで。それより大きい絵は、縦横比を保って 256 に縮めて書く。
- svg を読んだあとの大きさは、svg の `width`・`height`（無ければ `viewBox`）。`TCImage` の大きさに合わせて描くときは、`Stretch` の設定に従う。

## 4. TCImage

`TImage` の子クラス。`TImage` のプロパティ・メソッド・イベントはそのまま使える。足すのは次のとおり。

### 4.1 プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `FileName` | string | 読み | 最後に `LoadFromFile` したファイル名。読んでいなければ空 |
| `ImageFormat` | `TCImageFormat` | 読み | 今の絵の形式（`cifNone, cifBmp, cifJpeg, cifPng, cifTiff, cifIcon, cifSvg`） |

- `TCImageFormat` は `uCImages` に宣言する。

### 4.2 メソッド

| 名前 | 中身 |
|---|---|
| `procedure LoadFromFile(const AFileName: string)` | 拡張子から形式を選んで読む。`Picture.LoadFromFile` と同じだが、形式の判定（3 章）をして `FileName` を覚える |
| `procedure SaveToFile(const AFileName: string; AJpegQuality: Integer = 90)` | `AJpegQuality`（1〜100）は jpg のときだけ使う。保存先の拡張子の形式で書く（3 章）。保存先のフォルダーが無ければ作る。絵が空なら `ECImageError` |
| `procedure LoadFromBitmap(ABitmap: TBitmap)` | `TBitmap` の中身を絵にする（`TCCapture` が使う） |
| `function ToBitmap: TBitmap` | 今の絵を 32 ビットの `TBitmap` にして返す。呼んだ側が `Free` する |
| `class function IsSupportedFile(const AFileName: string): Boolean` | 拡張子が 3 章の表にあれば `True` |
| `class function FormatOfFile(const AFileName: string): TCImageFormat` | 拡張子から形式を返す。無ければ `cifNone` |

### 4.3 イベント

`TImage` のものだけ。足すものは無い。

### 4.4 動作

- `Picture`・`Stretch`・`Proportional`・`Center`・`Transparent`・`AutoSize` などは `TImage` と同じ動作。
- `LoadFromFile` で読めなかったとき、絵は元のまま残し、`ECImageError` を出す。
- `SaveToFile` が書き込みに失敗したとき（書き込み禁止など）、書きかけのファイルは削除して `ECImageError` を出す。

## 5. TCImageList

`TImageList` の子クラス。`TImageList` のプロパティ・メソッド・イベントはそのまま使える。足すのは次のとおり。

### 5.1 メソッド

| 名前 | 中身 |
|---|---|
| `function AddFromFile(const AFileName: string): Integer` | 画像ファイルを 1 枚読み、`Width`×`Height` に合わせて足す。足した位置を返す |
| `function AddFromImage(AImage: TCImage): Integer` | `TCImage` の絵を、`Width`×`Height` に合わせて足す。足した位置を返す |
| `function AddFromFolder(const AFolder: string; ARecursive: Boolean = False): Integer` | フォルダーの中の 3 章の形式のファイルを、ファイル名順にすべて足す。足した数を返す |
| `procedure SaveItemToFile(AIndex: Integer; const AFileName: string)` | 指定の 1 枚を、`TCImage.SaveToFile` と同じ規則で書く |

### 5.2 動作

- 足すとき、`Width`×`Height` と大きさが違う絵は、縦横比を保って縮小（拡大）し、中央に置く。余白は透明。
- 透明（png のアルファ・ico・svg）は保つ。bmp など透明が無い絵は、`TImageList` と同じく、絵全体を不透明で足す。
- `Width`・`Height` が初期値（16）のままなら、そのまま 16×16 にする。呼ぶ側が先に決めておく。
- 読めないファイルがあったとき、`AddFromFile` は `ECImageError` を出す。`AddFromFolder` は、読めないファイルを飛ばして続ける（足した数だけが返る）。

### 5.3 既存部品との組み合わせ

- `TCImageList` は `TImageList` の子クラスなので、`TImageList`・`TCustomImageList` 型のプロパティに、そのまま選んで使える（オブジェクトインスペクターの一覧にも出る）。既存部品のコードは変えない。

| 部品 | プロパティ | 型 |
|---|---|---|
| `TCPageControl` | `Images` | `TCustomImageList` |
| `TCSideBar` | `Images` | `TCustomImageList` |
| `TCExpandPanel`（`TCRollout`） | `Images` | `TCustomImageList` |
| `TCMonacoEditor` | `TabImages` | `TImageList` |
| `TCsEditor` | `TabImages` | `TImageList` |

- 確認方法：テスト用アプリ（`test\` の下）で、`TCPageControl` と `TCSideBar` に `TCImageList` を割り当て、アイコンが出ることを確かめる。
- 使い方の例は、取説（`TCImage_Usage.md`）に載せる。

## 6. エラーと文字列

- `ECImageError = class(Exception)` を `uCImages` に宣言する。
- 画面に出る・例外に入る文字列は、`uCXLang` に日英を足す（識別子は既存の命名に合わせ、`s` で始める）。

| 識別子 | 日本語 | 英語 |
|---|---|---|
| `sImgUnsupported` | 扱えない画像形式です：%s | Unsupported image format: %s |
| `sImgLoadFailed` | 画像を読めません：%s | Cannot load image: %s |
| `sImgSaveFailed` | 画像を保存できません：%s | Cannot save image: %s |
| `sImgEmpty` | 保存する画像がありません | There is no image to save |
| `sImgSvgWrite` | svg は保存できません | SVG cannot be saved |

## 7. 登録

- `source\design\uCXReg.pas` の `RegisterComponents('CX', [...])` に `TCImage`・`TCImageList` を足す。
- パレットのアイコンは、`source\res\cimage_icon.lrs`（`TCImage`・`TCImageList`・`TCCapture` の 24・36・48px の PNG から `lazres` で作る。元の絵は `test\make_image_icons.ps1` で作る）。`cxdsgn.lpk` の必要ファイル（LRS）に足し、`uCXReg` の `initialization` で `{$I cimage_icon.lrs}` を読む。
