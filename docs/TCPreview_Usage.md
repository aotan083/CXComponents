# TCPreview 取扱説明書

作者: aotan083
日付: 2026-11-04
版: 1.1

---

## 1. 概要とクラス

TCsEditor の本文を、プレビュー（Markdown は文書、それ以外は色分けしたコード）として表示し、印刷（PDF 保存）する部品です。エディタとは別の部品なので、フォームの好きな場所に置けます。1 つの TCPreview を、複数の TCsEditor で共有できます。

```
+---------+---------+-----+-----------+------------------------------+
| a.md  × | b.pas × |  +  |           |                              |
+---------+---------+-----+-----------+‖-----------------------------+
| # 見出し                             ‖  見出し                      |
| 本文…                                ‖  本文…                       |
|                                     ‖                              |
|   TCsEditor                         ‖  TCPreview                   |
+-------------------------------------+------------------------------+
                                      ↑ TSplitter（アプリが置く）
```

- 中身は TCMonacoEditor のプレビューと同じもの（WebView2 と `preview.html`）。表示・Mermaid の図・印刷・リンク・画像の動きは TCMonacoEditor のプレビューと同じ。
- つなぎ方は、TCsEditor の `Preview` でこの部品を選ぶだけ。TCPreview の側では何も選ばない。
- 表示・非表示は、TCsEditor の `ShowPreview`（`Ctrl+Shift+V`）で切り替える。
- 表示するのは「表示元」の TCsEditor の、見えているタブ（3章）。
- エディタとプレビューのスクロールを合わせる（行単位）。
- 設定はすべてオブジェクトインスペクタで行う。コードは要らない。

| 項目 | 内容 |
|---|---|
| Lazarus | 5.0 以降 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |
| 実行に必要なもの | Microsoft Edge WebView2 ランタイム（Windows 11 には最初から入っている）、WebView2Loader.dll（64 ビット版）、WebView2.ini、preview フォルダー（2章） |
| メモリ | 約 60MB（WebView2）。一度も表示しなければ WebView2 を起動しない |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCPreview` | `uCPreview` | cx | `TCustomPanel` | プレビューの部品 |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCMColorScheme` | `uCPreview` | プレビューの配色。`csEditor`・`csGitHub`（`uCmonacos` と同じ型） |
| `TCMSyncScroll` | `uCPreview` | スクロールの同期。`ssNone`・`ssEditorToPreview`・`ssBoth`（`CMonacoPreview` と同じ型） |

- フォームに置くと、uses に `uCPreview` が自動で入る。
- フォームに置くと、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCsEditor・TSplitter・TCPreview をフォームに置く。
2. 並べ方をオブジェクトインスペクタで決める（右にプレビューを出すときの例）。

| 部品 | 設定 |
|---|---|
| TCsEditor1 | `Align = alClient`、`Preview = CPreview1` |
| Splitter1 | `Align = alRight` |
| CPreview1 | `Align = alRight`、`Splitter = Splitter1`、`Width` はプレビューの幅 |

3. 起動時にプレビューを出すかを決める。

| 起動時 | 設定 |
|---|---|
| 出さない | `CPreview1.Visible = False`（TCsEditor1 の `ShowPreview` は `False` のまま） |
| 出す | TCsEditor1 の `ShowPreview = True` |

4. EXE と同じフォルダーに、2.1 のファイルを置く。
5. 実行する。`Ctrl+Shift+V` でプレビューの表示・非表示が切り替わる。

- `Splitter` を選ばないと、表示し直したときに境目がプレビューの隣に来ないため、幅を変えられなくなる。境目の `Align` は、プレビューと同じ向き（`alRight` など）にする。`alNone` にしない。
- `CPreview1.Visible = True` のまま `ShowPreview = False` にすると、起動時はプレビューが出ているのに `ShowPreview` は `False` になる。最初の `Ctrl+Shift+V` では画面が変わらない。
- IDE の上（設計時）では WebView2 を起動しない。薄い枠と部品の名前だけが出る。

### 2.1 実行時のファイル

```
MyApp.exe
WebView2.ini                       （必ず置く。2.2）
WebView2Loader.dll                 （64 ビット版）
WebView2Data\                      （WebView2 のユーザーデータ。自動で作る）
preview\
  preview.html
  lib\
    marked.umd.js
    purify.min.js
    highlight.min.js
    github.min.css / github-dark.min.css
    github-markdown-light.css / github-markdown-dark.css
    THIRD_PARTY_LICENSES.txt
    mermaid.min.js / mermaid.LICENSE.txt   （Mermaid の図）
    languages\ delphi.min.js / dos.min.js / powershell.min.js
```

- preview フォルダーは、TCMonacoEditor と同じもの。monaco フォルダーは要らない。
- WebView2Loader.dll は、WebView4Delphi のリポジトリ（https://github.com/salvadordf/WebView4Delphi）から入手する。
- WebView2 の準備は、プレビューが初めて表示されたときに部品が自分で行う。アプリの .lpr には何も書かない。

### 2.2 WebView2.ini

EXE と同じフォルダーに置く。CX の WebView2 部品（TCMonacoEditor・TCTabBrowser・TCPreview）で共通。

```ini
[WebView2]
LoaderDllPath=
UserDataFolder=
MonacoFolder=
PreviewFolder=

[CX]
Language=
```

| キー | 中身 | 空・書かないとき |
|---|---|---|
| `LoaderDllPath` | WebView2Loader.dll のファイル | EXE のフォルダーの WebView2Loader.dll |
| `UserDataFolder` | WebView2 のユーザーデータのフォルダー | EXE のフォルダー\WebView2Data |
| `MonacoFolder` | TCPreview は使わない | ― |
| `PreviewFolder` | `preview.html` と `lib` があるフォルダー | EXE のフォルダー\preview |
| `Language`（`[CX]`） | 画面の言語 `ja`・`en`（2.4） | Windows の表示言語 |

- ファイルは必ず置く。キーの値はすべて空でもよい。
- 相対パスは、EXE のフォルダーから数える。絶対パスも書ける。
- 起動してから最初に使うときに 1 回だけ読む。実行中に書き換えても、次の起動まで効かない。

### 2.3 preview の場所の決め方

上から順に、最初に決まったものを使う。

| 順 | 決め方 |
|---|---|
| 1 | `PreviewPath` が空でなければ、その場所（相対パスは EXE のフォルダーから数える） |
| 2 | WebView2.ini の `PreviewFolder` が空でなければ、その場所 |
| 3 | EXE のフォルダーの `preview` |

- 見つからなければ `OnError`（「preview.html が見つかりません: （場所）」）。

### 2.4 画面の言語（日本語・English）

この部品が画面に出す文字（右クリックメニュー・図のボタン・エラーの文など）は、日本語か英語で出る。言語は cx の部品すべてで 1 つで、部品ごとには決めない。

WebView2.ini（2.2）に、次のように書く。

```ini
[CX]
Language=en
```

| 順 | 決め方 |
|---|---|
| 1 | `[CX]` の `Language` が `ja` または `en` なら、その言語（大文字・小文字は問わない） |
| 2 | それ以外（`[CX]` が無い・空・ほかの値）は、Windows の表示言語。日本語なら `ja`、それ以外は `en` |

- 最初に文字を出すときに 1 回だけ決める。実行中に書き換えても、次の起動まで効かない。
- この取説に書いた画面の文字は、日本語のときのもの。英語のときは英語で出る。

## 3. 表示元

TCPreview に表示するのは、「表示元」の TCsEditor の見えているタブ。表示元は、次のように自動で決まる。

| きっかけ | 表示元 | 表示 |
|---|---|---|
| TCsEditor の本文をクリックした（その TCsEditor の `Preview` がこの部品） | その TCsEditor | 表示元が変わったときは、すぐに作り直す |
| 表示元の TCsEditor でタブを切り替えた | 変わらない | すぐに作り直す |
| 表示元の TCsEditor で本文が変わった | 変わらない | `DelayMs` 待って作り直す |
| 表示元でない TCsEditor で本文が変わった・タブを切り替えた | 変わらない | 何もしない |
| エディタ以外（ボタン・ツリーなど）をクリック | 変わらない | 何もしない |
| `ShowPreview := True`・`Ctrl+Shift+V`・`Print`・`Ctrl+P` を行った TCsEditor | その TCsEditor | すぐに作り直す |
| 表示元の TCsEditor が壊された、`Preview` を外した | なし | 空にする |
| 起動直後 | `Preview` にこの部品を選んでいる TCsEditor のうち、最初に準備ができたもの | すぐに作り直す |

- 隠れている間は作り直さない。表示したときに、その時点の内容で作り直す。
- 本文は、ファイルではなくエディタから取る。保存していない編集も表示される。

## 4. プロパティ

| 名前 | 型 | 既定値 | 読み書き | 中身 |
|---|---|---|---|---|
| `Splitter` | `TSplitter` | nil | 読み・書き | プレビューと一緒に表示・非表示にする境目（5.1） |
| `FontSize` | `Integer` | 16 | 読み・書き | 文字の大きさ（8〜48）。プレビューで `Ctrl+ホイール` を回すと、この値も変わる |
| `ColorScheme` | `TCMColorScheme` | `csEditor` | 読み・書き | 配色。`csEditor`（エディタと同じ配色）／`csGitHub`（GitHub 風） |
| `BackColorLight` | `TColor` | #FFFFFE | 読み・書き | `csEditor` のときの背景色（明るい配色） |
| `BackColorDark` | `TColor` | #1E1E1E | 読み・書き | 同（暗い配色） |
| `TextColorLight` | `TColor` | #000000 | 読み・書き | 文字色（明るい配色） |
| `TextColorDark` | `TColor` | #D4D4D4 | 読み・書き | 同（暗い配色） |
| `LinkColorLight` | `TColor` | #006AB1 | 読み・書き | リンクの色（明るい配色） |
| `LinkColorDark` | `TColor` | #3794FF | 読み・書き | 同（暗い配色） |
| `BreakOnNewline` | `Boolean` | `False` | 読み・書き | Markdown の 1 つの改行も改行として表示するか |
| `AllowRemoteImages` | `Boolean` | `False` | 読み・書き | ネット（http）の画像を表示するか（6.3）。TCsEditor の `AllowRemoteImages` でも読み書きできる |
| `SyncScroll` | `TCMSyncScroll` | `ssBoth` | 読み・書き | エディタとプレビューのスクロールを合わせるか（6.4） |
| `DelayMs` | `Integer` | 300 | 読み・書き | 編集してからプレビューを作り直すまでの時間（ミリ秒）。0 以下ならすぐ |
| `PreviewPath` | `string` | '' | 読み・書き | `preview.html` の場所（2.3） |
| `Source` | `TComponent` | ― | 読み | 今の表示元の TCsEditor（3章）。無ければ nil。実行時だけ |
| `Ready` | `Boolean` | ― | 読み | プレビューの準備ができたか。実行時だけ |
| `Align` | `TAlign` | | 読み・書き | 親の中での配置 |
| `Anchors` | `TAnchors` | | 読み・書き | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `BorderSpacing` | `TControlBorderSpacing` | | 読み・書き | 周りの余白 |
| `Constraints` | `TSizeConstraints` | | 読み・書き | 大きさの上限・下限 |
| `Enabled` | `Boolean` | | 読み・書き | 使えるか |
| `Visible` | `Boolean` | | 読み・書き | 表示するか。TCsEditor の `ShowPreview` と同じもの |
| `Width`・`Height` | `Integer` | 500・300 | 読み・書き | 大きさ。`alRight`・`alLeft` のときは `Width` がプレビューの幅 |
| `TabOrder` | `TTabOrder` | | 読み・書き | Tab キーで移る順番 |
| `TabStop` | `Boolean` | | 読み・書き | Tab キーで止まるか |

**色の設定（名前が `Color` で終わる 6 個）**

- オブジェクトインスペクタで、色の一覧か「...」の色ダイアログから選ぶ。
- システム色（`clWindow` など）を選んだときは、設定したときのその色になる。
- `clDefault`・`clNone` を選んだときは、既定値の色になる。

**配色（ダーク・ライト）**

- 表示元の TCsEditor の `Theme` に合わせる（`ctAuto` なら OS の配色。OS を切り替えるとその場で変わる）。表示元が無いときは OS の配色。

## 5. メソッドとイベント

### 5.1 表示・非表示と境目（Splitter）

- `Visible` を変えると（TCsEditor の `ShowPreview`・`Ctrl+Shift+V` を含む）、`Splitter` の `Visible` も同じになる。
- 表示するたびに、境目をプレビューの隣に置き直す（`alRight` ならプレビューの左、`alLeft` なら右、`alBottom` なら上、`alTop` なら下）。
- 境目の色は、表示元の配色に合わせて付ける（ダーク #2B2B2B、ライト #E5E5E5）。アプリが付けた色は上書きする。

### 5.2 メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Print` | ― | ― | 表示元の見えているタブを印刷する（6.5）。表示元が無ければ何もしない |
| `Refresh` | ― | ― | 今の表示元の内容で、すぐに作り直す |

- `SetSource`・`SourceChanged`・`SourceSwitched`・`SourceScrolled`・`SourceRemoved`・`PrintFor` は、TCsEditor がこの部品に知らせるためのもの。アプリからは呼ばない。

### 5.3 イベント

| 名前 | 引数 | 中身 | 設定しないとき |
|---|---|---|---|
| `OnOpenMarkdown` | `Sender: TObject; const AFileName: string` | プレビューの `.md` へのリンクが押された | 表示元の TCsEditor で開く（`MultiDocument` に従う） |
| `OnError` | `Sender: TObject; const AMessage: string` | プレビューのエラー（preview.html が見つからない、WebView2 の準備ができない など） | メッセージを表示する。同じメッセージは 1 回だけ |

## 6. 動き

### 6.1 表示するもの

| 表示元のタブの言語 | 表示 |
|---|---|
| markdown | 文書（表・タスクリスト・コードブロックの色分け・Mermaid の図） |
| それ以外 | 本文全体を、行番号付きの色分けしたコードとして出す |

**Markdown**

- 表（GFM）、タスクリスト、コードブロックの色分けに対応する。言語を書いていないコードブロックは、色分けしない。
- `ColorScheme = csEditor`（既定値）では、エディタと同じ配色（`BackColor…`・`TextColor…`・`LinkColor…`）。表の罫線、コードブロックの背景は、背景色と文字色から自動で決める。
- 文字は `Segoe UI`、`Yu Gothic UI`、`Meiryo` の順。
- 先頭の YAML（`---` で囲んだ部分）は表示しない。
- タスクリストのチェックボックスは、表示だけ（クリックしても本文は変わらない）。
- スクリプトは取り除くので、外から来た Markdown を開いても動かない。

**コード（Markdown 以外のタブ）**

| 項目 | 中身 |
|---|---|
| 色分け | タブの言語を highlight.js の言語に読み替える（例：pascal → delphi、bat → dos）。対応しない言語と plaintext は、色分けしない |
| 長い行 | 折り返す（行番号は、折り返した先頭の行にだけ付く） |
| 大きなファイル | 50 万文字を超えるファイルは、色分けしない（行番号付きの表示はする） |
| コピー | 行番号はコピーされない |
| 文字 | 等幅（`Consolas`、`BIZ UDゴシック`、`MS ゴシック` の順） |

- コードブロックとコードの色分けは、エディタの色に近づけているが、エディタ（SynEdit）とプレビュー（highlight.js）は色分けのしくみが違うので、完全には同じにならない。

### 6.2 Mermaid の図

Markdown の ` ```mermaid ` のコードブロックに書くと、図として描く。

| 書き出し | 図 |
|---|---|
| `graph TD`・`graph TB` | フローチャート（上から下） |
| `graph LR`・`flowchart LR` | フローチャート（左から右） |
| `sequenceDiagram` | シーケンス図 |
| `usecase-beta` | ユースケース図 |
| `classDiagram` | クラス図 |
| `erDiagram` | ER 図 |
| `gitGraph` | git のグラフ |
| `journey` | ユーザージャーニー |
| `xychart-beta` | XY グラフ（棒・折れ線） |
| `quadrantChart` | 4 象限の図 |
| `architecture-beta` | アーキテクチャ図 |

| 項目 | 中身 |
|---|---|
| 色 | 線・枠は青（ダーク #3794ff、ライト #006ab1）、背景・文字はプレビューと同じ色 |
| 大きさ | 最初はプレビューの幅に合わせる。図にマウスを乗せると、右上に 4 つのボタン（移動／縮小／拡大／枠に合わせる）が出る |
| 印刷 | 白い背景用の色で、紙の幅に合わせて印刷する |
| 書き間違い | その図の場所にエラーの内容を出す（ほかの部分は普通に出る） |
| 図の中のネットの画像 | `AllowRemoteImages = False`（既定値）なら取りに行かず、図の下に「[外部画像は表示しません]」 |

- Mermaid のライブラリ（約 5.5MB）は、Mermaid の図がある文書を表示したときだけ読み込む。

### 6.3 リンクと画像

- 画像は、相対パス（開いているファイルのフォルダーから数える）でも、`C:\...` のような絶対パスでも表示する。
- ネット（http）の画像は、`AllowRemoteImages = True` でなければ表示しない。
- 外へのリンク（`http`、`https`、`mailto`）は、既定のブラウザで開く。プレビューの中では移動しない。
- `.md` へのリンクは、`OnOpenMarkdown` を設定していなければ、表示元の TCsEditor で開く。
- `#見出し` へのリンクは、プレビューの中でスクロールする。
- そのほかのファイルへのリンクは、安全のため開かない。

### 6.4 スクロールを合わせる

| `SyncScroll` | 動き |
|---|---|
| `ssBoth`（既定値） | 両方向。エディタを動かすとプレビューが、プレビューを動かすとエディタが合わせる |
| `ssEditorToPreview` | エディタからプレビューへだけ |
| `ssNone` | 合わせない |

- 行単位で合わせる（エディタの行の途中の位置までは合わせない）。プレビューは、その行のブロックの先頭に合わせる。
- 折り返しの多い長い段落の中では、多少ずれる。

### 6.5 印刷

- TCsEditor の `Print`・`Ctrl+P`、この部品の `Print`、プレビューの右クリックの「印刷...」、プレビューにフォーカスがあるときの `Ctrl+P` で、Edge と同じ印刷ダイアログを出す。プリンター・PDF として保存・ページ・部数などは、すべてダイアログで選ぶ。
- 印刷するのは、表示元の見えているタブ。Markdown は文書、それ以外は色分けしたコードを印刷する。
- プレビューを出していないときは、印刷の間だけプレビューを出し、印刷ダイアログが閉じたら隠す。閉じたことが知らされないときは、出したままになる（`Ctrl+Shift+V` で隠す）。初めてのときは、WebView2 の起動を待つため、少し時間がかかる。
- 画面がダークでも、印刷は白い背景・黒い文字になる。
- PDF の名前は、見えているタブの名前から拡張子を外したもの（`abc.md` → `abc.pdf`、無題 → `無題.pdf`）。保存先は印刷ダイアログで決める。
- 印刷ダイアログの「ヘッダーとフッター」を入れると、各ページに内部の URL が入る。要らないときは、ダイアログでヘッダーとフッターを外す。

### 6.6 右クリックメニュー

| 項目 | 動き |
|---|---|
| コピー | 選んでいる文字列をコピー |
| すべて選択 | すべて選ぶ |
| 印刷... | 印刷する（6.5） |

## 7. 使い方の例

### 7.1 エディタの右にプレビューを置く（コードなし）

1. フォームに TCsEditor・TSplitter・TCPreview を置く。
2. TCsEditor1：`Align = alClient`、`Preview = CPreview1`。
3. Splitter1：`Align = alRight`。
4. CPreview1：`Align = alRight`、`Splitter = Splitter1`、`Visible = False`。
5. EXE と同じフォルダーに、2.1 のファイルを置く。

`Ctrl+Shift+V` でプレビューが出る・消える。境目をドラッグすると、プレビューの幅が変わる。

### 7.2 2 つのエディタで 1 つのプレビューを使う

1. TCsEditor を 2 つ貼り（例：`alLeft` と `alClient`）、間に TSplitter を置く。
2. 右端に TSplitter（`alRight`）と TCPreview（`alRight`、`Splitter` はその境目）を置く。
3. 2 つの TCsEditor の `Preview` に、どちらも CPreview1 を選ぶ。

プレビューには、最後にクリックしたエディタの見えているタブが出る。

### 7.3 プレビューの設定を変える

```pascal
CPreview1.FontSize := 18;
CPreview1.ColorScheme := csGitHub;      // GitHub 風の配色
CPreview1.SyncScroll := ssEditorToPreview;
CsEditor1.Preview.DelayMs := 500;       // エディタからたどっても同じ
```

### 7.4 .md へのリンクを自分で開く

```pascal
procedure TForm1.CPreview1OpenMarkdown(Sender: TObject; const AFileName: string);
begin
  CsEditor2.OpenFile(AFileName);        // 右のエディタで開く
end;
```

### 7.5 コードで作る

```pascal
uses
  uCPreview;

procedure TForm1.FormCreate(Sender: TObject);
var
  S: TSplitter;
  P: TCPreview;
begin
  P := TCPreview.Create(Self);
  P.Width := 400;
  P.Align := alRight;
  P.Visible := False;
  P.Parent := Self;
  S := TSplitter.Create(Self);
  S.Align := alRight;
  S.Parent := Self;
  P.Splitter := S;
  CsEditor1.Preview := P;
end;
```
