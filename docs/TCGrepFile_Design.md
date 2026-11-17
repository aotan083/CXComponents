# TCGrepFile 設計書

作者: aotan083
日付: 2026-11-17
版: 1.0

---

## 1. 目的と方針

- フォルダーの中のファイルを、**中身の文字で探す**（grep 検索）部品 `TCGrepFile`。画面を持たない `TComponent`。単独で使える。
- 利用者が置く部品は `TCGrepFile` だけ。対象のファイルを集める処理は、`uCFindFile` の `TCFindWorker`（`TCFindFile_Design.md` 3.6）を内部で使う。`TCFindFile` は変えない。
- 探す処理は別スレッド。見つかった行は、まとめてメインスレッドへ渡す。
- 結果の届け方は、利用者が指定する（`OutputMode`）。
  - `omEvent`（既定）：見つかった行を `OnFound` で届ける。
  - `omFile`：見つかった行を、ファイルへ書き出す（`OnFound` は出さない）。
- `omEvent` で探した結果は、あとから `SaveResults` でファイルへ書き出せる。
- ファイルの書式は、1 行に「パス(行番号): その行の文字」。タグジャンプ（その行へ飛ぶ）に使える形（Visual Studio・秀丸・サクラエディタの grep 結果と同じ形）。TCMonacoEditor・TCsEditor で、結果の行から、そのファイルの行へ飛ぶ機能は、別に作る（この部品には含めない）。そのために、1 行を読み戻す関数 `CGrepParseLine` を用意する（3.5）。文字コードは UTF-8（BOM なし）。既存のファイルは上書きする。

### 1.1 含めないもの

- 置き換え。
- 前後の行（コンテキスト）の表示。
- 複数行にまたがる検索（検索は 1 行ごと）。
- zip などの圧縮ファイルの中。
- UTF-16（BOM なし）・EUC-JP など、3.4 に書いた以外の文字コード。
- 検索条件の保存。
- `TCListView` への表示（`OnFound` で受けて、アプリが見せる。`TCListView` は変えない）。
- Linux・macOS（Windows 11 だけ）。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCGrepFile.pas` | cx（実行時） | `TCGrepFile`、`TCGrepMatcher`（行の判定）、`CGrepFormatLine`（出力の 1 行を作る関数）、`CGrepParseLine`（出力の 1 行を、パスと行番号に読み戻す関数）、`CGrepIsFullPath`（フルパスか）、`CGrepDecodeBytes`（バイナリの判定・文字コードの判定・変換） |
| `uCXReg.pas`（`source\design`）・`cnavigation_icon.lrs` | cxdsgn（設計時） | パレット [CX] への登録とアイコン（`cnavigation_icon.lrs` に、`TCGrepFile` の 3 つを足す） |
| `uCXLang.pas` | cx（実行時） | 文字列を足す（4.3） |

- `uCGrepFile` の uses：`Classes, SysUtils, SyncObjs, Windows, LazUTF8, LConvEncoding, RegExpr, uCXLang, uCFindFile`。
- initialization・finalization は持たない。
- パッケージは、cx と cxdsgn の 2 つのまま。

## 3. TCGrepFile

`TCGrepFile = class(TComponent)`。画面を持たない。

### 3.1 型と定数

```pascal
type
  TCGrepMatchMode = (gmContains, gmRegex);                  { 部分一致／正規表現 }
  TCGrepOutputMode = (omEvent, omFile);                     { OnFound で届ける／ファイルへ書き出す }

  TCGrepFoundEvent = procedure(Sender: TObject; const APath: string; ALine: Integer; const AText: string) of object;
  TCGrepProgressEvent = procedure(Sender: TObject; const AFile: string; AFiles: Integer; AFound: Integer) of object;
  TCGrepFinishedEvent = procedure(Sender: TObject; AFiles: Integer; AFound: Integer; AReason: TCFindStopReason) of object;
  TCGrepErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;
```

- `TCFindStopReason`（`frDone`・`frStopped`・`frLimit`・`frError`）は、`uCFindFile` のものを使う。`frLimit` は、見つかった行が `MaxResults` に達したとき。

| 定数 | 値 | 中身 |
|---|---|---|
| `cGrepFlushCount` | 50 | 見つかった行を、メインスレッドへ（またはファイルへ）渡す件数 |
| `cGrepFlushMs` | 100 | 同じく、時間（ミリ秒）。件数か時間の早い方 |
| `cGrepProgressMs` | 200 | `OnProgress` の間隔 |
| `cGrepMaxDef` | 10000 | `MaxResults` の既定値 |
| `cGrepMaxFileDef` | 10485760 | `MaxFileSize` の既定値（10 MB） |
| `cGrepMaxLine` | 1000 | 1 行の文字の最大の長さ（バイト）。超える行は、ここで切って、末尾に `...` を付ける |
| `cGrepBinaryCheck` | 8192 | バイナリの判定に見る、先頭のバイト数 |

### 3.2 プロパティ

| 名前 | 型 | 既定値 | 公開 | 中身 |
|---|---|---|---|---|
| `Root` | `string` | '' | published | 探し始めるフォルダー |
| `FileMask` | `string` | `*` | published | 対象にするファイルの名前（ワイルドカード。`;` で複数。例 `*.pas;*.lfm`）。ファイル名だけで判定する |
| `Pattern` | `string` | '' | published | 中身で探す文字（`MatchMode` で、意味が変わる） |
| `MatchMode` | `TCGrepMatchMode` | `gmContains` | published | 行の判定の方法 |
| `CaseSensitive` | `Boolean` | `False` | published | 大文字・小文字を区別するか |
| `IncludeSubfolders` | `Boolean` | `True` | published | サブフォルダーも探すか |
| `SearchHidden` | `Boolean` | `False` | published | 隠し・システム属性のファイル・フォルダーも探すか |
| `MaxResults` | `Integer` | 10000 | published | 見つかった行の最大数。0 は制限なし。0 より小さい値は 0 |
| `MaxFileSize` | `Int64` | 10485760 | published | 読むファイルの最大の大きさ（バイト）。超えるファイルは飛ばす。0 は制限なし。0 より小さい値は 0 |
| `OutputMode` | `TCGrepOutputMode` | `omEvent` | published | 結果の届け方 |
| `OutputFile` | `string` | '' | published | `omFile` のときの、書き出すファイル（UTF-8・BOM なし。既存なら上書き） |
| `Active` | `Boolean` | ― | public（読む） | 探している最中か |
| `FoundCount` | `Integer` | ― | public（読む） | 今までに見つかった行の数 |
| `FileCount` | `Integer` | ― | public（読む） | 今までに調べたファイルの数（飛ばしたファイルは数えない） |

- 探している最中は、設定を変えても、その探しには影響しない（`Start` のときに写す）。

### 3.3 メソッド

| メソッド | 中身 |
|---|---|
| `function Start: Boolean` | 別スレッドで探し始める。すでに探していれば `False`。`Root` がフォルダーでない、`Pattern` が空、式が正しくない（正規表現・`FileMask`）、`omFile` で `OutputFile` が空・書けない、のときは、`OnError` を出して `False`（探さない）。`omFile` のときは、ここで `OutputFile` を作り直す（空にする） |
| `procedure Stop` | 止める。待たない（`OnFinished` が `frStopped` で来る） |
| `function WaitFor(ATimeoutMs: Integer): Boolean` | 探し終わる（`OnFinished` が来る）まで、メッセージを処理しながら待つ。時間内に終われば `True` |
| `function GrepAll(AResult: TStrings): Integer` | 呼んだスレッドの中で探して、`AResult` に、出力の 1 行（`CGrepFormatLine` の形）ずつを入れる。イベントは出さない。見つかった行の数を返す。エラーは例外（`ECFindPattern`・`EInOutError`）。確認用・スクリプト用 |
| `function SaveResults(const AFileName: string): Boolean` | `omEvent` で探した結果（直前の探し。メモリに残してある）を、ファイルへ書き出す（書式は 3.5。上書き）。保存先のフォルダーがなければ、自動で作る（途中のフォルダーも、すべて）。書けたら `True`。結果が 0 件でも、空のファイルを作って `True`。`OutputMode` が `omFile` のとき（結果がメモリにない）・フォルダーを作れない・書けないときは `False`（`OnError` も出す） |
| `function CheckPattern(out AError: string): Boolean` | `Pattern`・`FileMask` が使えるか（`Pattern` が空でなく、正規表現なら組み立てられ、`FileMask` が正しいか）。使えなければ `AError` に文 |

- `omEvent` のとき、見つかった行は、`MaxResults`（0 のときは無制限）まで、メモリに残す（次の `Start` で消える）。

### 3.4 ファイルの読み方

1. 対象のファイルは、`TCFindWorker` が見つける（`Mode := fmWildcard`、`Pattern := FileMask`、`IncludeFiles := True`、`IncludeFolders := False`、`MaxResults := 0`。隠し・リパースポイントの扱いは `TCFindFile_Design.md` 4.1 と同じ）。見つかるたび（`OnItem`）に、その場で、同じスレッドの中で、そのファイルを読んで探す。
2. `MaxFileSize`（0 でなければ）を超えるファイルは、飛ばす。
3. ファイルを、全部メモリへ読む（読めないファイル・開けないファイルは、静かに飛ばす）。
4. 先頭の `cGrepBinaryCheck` バイトに、NUL（0）が含まれていれば、バイナリとして飛ばす（BOM 付きの UTF-16 は、この判定の前に、BOM で見分けて、バイナリとしない）。
5. 文字コードを、次の順で決めて、UTF-8 にする。4 と 5 は、関数 `CGrepDecodeBytes(const ABytes: TBytes; out AText: string): Boolean` が行う（バイナリなら `False`。空のファイルは、`True`・空の文字）。
   1. BOM が UTF-8（EF BB BF）なら、BOM を除いて UTF-8。
   2. BOM が UTF-16LE（FF FE）・UTF-16BE（FE FF）なら、UTF-8 に変換する。
   3. BOM がなければ、全体が正しい UTF-8 かを調べる。正しければ UTF-8。
   4. 正しくなければ、CP932（Shift-JIS）とみなして、UTF-8 に変換する（`LConvEncoding.CP932ToUTF8`）。
6. 行に分ける：`CRLF`・`LF`・`CR` のどれでも、行の区切りとする。行番号は、1 から。
7. 1 行ずつ、`TCGrepMatcher.Match(行)`。合えば、見つかった行（パス・行番号・行の文字）。行の文字が `cGrepMaxLine` バイトを超えるときは、切って、末尾に `...` を付ける（UTF-8 の文字の途中では切らない）。
8. 出力先が `omFile` のファイル自身が、対象のファイルになっても、そのファイルは調べない（結果が結果を呼ばないように）。

### 3.5 出力の書式

```
C:\app\laz\CXComponents\source\uCFindFile.pas(123): procedure TCFindThread.Execute;
```

- 1 行 ＝ `パス` ＋ `(` ＋ `行番号` ＋ `): ` ＋ `その行の文字`。`CGrepFormatLine(APath, ALine, AText): string`。
- **タグジャンプ用の読み戻し**：`CGrepParseLine(const S: string; out APath: string; out ALine: Integer): Boolean`。1 行の先頭から数えて、最初の「`(` ＋ 数字だけ ＋ `): `」の、手前までを `APath`、数字を `ALine` にする。見つからなければ `False`。パスの中の `(x86)` のように、数字だけでない括弧は、飛ばす。
- 行の文字の、行頭の空白は、そのまま残す。行末の `CR`・`LF` は、含めない。
- 行の区切りは `CRLF`。UTF-8（BOM なし）。`omFile` の書き出し・`SaveResults` ・`GrepAll` の `AResult`（`CRLF` なしの 1 行ずつ）が、すべて同じ書式。

### 3.6 イベント

どれも、メインスレッドで呼ばれる。

| イベント | いつ |
|---|---|
| `OnFound(Sender, APath, ALine, AText)` | 見つかった行が 1 件あるとき（`omEvent` のときだけ）。スレッドからは、`cGrepFlushCount` 件か `cGrepFlushMs` ごとにまとめて渡し、そのたびに、まとめの中の数だけ、続けて呼ぶ |
| `OnProgress(Sender, AFile, AFiles, AFound)` | 探している最中、`cGrepProgressMs` ごと。今読んでいるファイル・調べたファイルの数・見つかった行の数 |
| `OnFinished(Sender, AFiles, AFound, AReason)` | 終わったとき（`OnFound` はすべて呼んだ後。`omFile` のときは、ファイルを閉じた後） |
| `OnError(Sender, AMessage)` | `Start` で、始められなかったとき。`omFile` で、探している最中に、書けなくなったとき（このときは、探すのを止めて、`OnFinished` は `frError`） |

### 3.7 行の判定（`TCGrepMatcher`）

スレッドごとに 1 つ作る。

```pascal
TCGrepMatcher = class
public
  constructor Create(AMode: TCGrepMatchMode; const APattern: string; ACaseSensitive: Boolean);  { 正しくなければ ECFindPattern }
  function Match(const ALine: string): Boolean;
end;
```

| `MatchMode` | 判定 |
|---|---|
| `gmContains` | 行に、`Pattern` が含まれるか。大文字・小文字を区別しないときは、両方を `UTF8LowerCase` にして `Pos` |
| `gmRegex` | `TRegExpr`。`Expression := Pattern`、`ModifierI := not CaseSensitive`。`Exec(行)`（行のどこかに合えば真）。式が正しくなければ、`Create` で `ECFindPattern`（文は `TRegExpr.ErrorMsg`） |

- 行は、UTF-8 のまま扱う。正規表現の `.` や `[ ]` は、バイト単位（`TCFindFile_Design.md` 3.5 と同じ）。
- `Pattern` の前後の空白は、そのまま比べる。

## 4. 処理

### 4.1 スレッド `TCGrepThread`（実装部のクラス）

1. `Start` のとき、設定を `TCFindWorker` と、行の判定の設定に写して、スレッドに渡す。`TCGrepMatcher` は、スレッドの中で作る。
2. `omFile` のときは、`Start` が作り直した `OutputFile`（`TFileStream`）を、スレッドが受け取って持つ。見つかった行は、そのスレッドが書き足し、終わったら閉じる。
3. `TCFindWorker.Run` を呼ぶ。見つかったファイルごとに、3.4 のとおり、そのファイルを読んで探す。
4. 見つかった行は、スレッドのバッファにためる。`cGrepFlushCount` 件か `cGrepFlushMs` ごとに、`omEvent` なら `Queue` でメインスレッドへ渡し、`omFile` ならファイルへ書き足す。
5. `cGrepProgressMs` ごとに、`Queue` で `OnProgress`。
6. `StopFlag`（`Stop` が立てる）を、ファイルごと・行の判定のたびに調べる。真なら、バッファを渡して、`frStopped` で終わる（`TCFindFile_Design.md` 4.1 の 6 と同じ。`Terminate` は使わない）。
7. 見つかった行が `MaxResults`（0 でなければ）に達したら、バッファを渡して、`frLimit` で終わる。
8. `omFile` のとき、終わったらファイルを閉じる。
9. 最後に `OnFinished` を `Queue`（`OnFound` が、すべて呼ばれた後）。

**内部の部品**：探す処理の本体は `TCGrepWorker`（スレッドからも、同期の `GrepAll` からも使う）。`Run` の中で、`TCGrepMatcher` と `TCFindWorker` を作る。見つかったファイルごとに（`TCFindWorker.OnItem`）、読んで、行に分けて、判定する。`Stop` は、自分の止める印と、`TCFindWorker` の止める印の両方を立てる。`SkipFile` に、調べないファイル（`omFile` の出力先）を入れる。見つかった行が `MaxResults` に達したら、止める印を立てて、理由を `frLimit` にする。

### 4.2 `Start`・`Stop`・`Destroy`

`TCFindFile_Design.md` 4.2 と同じ（`FDestroying`・`Detach`・`RemoveQueuedEvents`・`DeliverFinished` で、スレッドを片づけてから `OnFinished`）。

### 4.3 文字列（`uCXLang` へ足すもの）

| ID | 日本語 | English |
|---|---|---|
| `sGrErrEmpty` | 検索する文字を入力してください | Enter the text to search for |
| `sGrErrOutput` | 結果のファイルを書けません：%s | The result file could not be written: %s |
| `sGrErrNoResult` | 保存する結果がありません（結果を、ファイルへ直接書き出す設定です） | There are no results to save (results are being written directly to a file) |

- `Root` がないときの文は、`sSbErrNoRoot`（`TCSearchBox_Design.md` 5 章）を使う。
- 正規表現・ワイルドカードが正しくないときの文は、`TRegExpr`・`TMaskList` のエラーの文。

## 5. 設計時

- フォームの下の、部品の欄に出る（アイコンは `cnavigation_icon.lrs`）。パレット [CX] に出す。探す処理は動かさない。

## 6. 決めていること

| 項目 | 決めたこと |
|---|---|
| 部品の数 | 利用者が置くのは `TCGrepFile` だけ。ファイルを集める処理は、`uCFindFile` の `TCFindWorker` を内部で使う（`TCFindFile` は変えない） |
| 結果の届け方 | `OutputMode`：`omEvent`（既定。`OnFound`）か `omFile`（ファイルへ書き出す）の、どちらか 1 つ。両方同時は、しない |
| 保存 | `omEvent` で探した結果を、あとから `SaveResults` でファイルへ書き出せる |
| ファイルの書式 | 1 行に「パス(行番号): その行の文字」（タグジャンプに使える形）。UTF-8（BOM なし）。既存のファイルは上書き |
| タグジャンプ | この部品は、1 行を読み戻す関数（`CGrepParseLine`）までを持つ。エディタの側で、行へ飛ぶ機能は、別に作る |
| 探し方 | 部分一致・正規表現（行ごと）。複数行にまたがる検索はしない |
| 文字コード | BOM（UTF-8・UTF-16）。なければ、正しい UTF-8 か調べて、そうでなければ CP932。それ以外は扱わない |
| 飛ばすファイル | バイナリ（先頭 8192 バイトに NUL がある）、`MaxFileSize`（既定 10 MB）を超えるもの、読めないもの |
| 長い行 | 1000 バイトで切って、`...` を付ける |
| 結果の最大数 | `MaxResults`（既定 10000 行）。メモリに残すのも、この数まで |
| スレッド | 探す処理は別スレッド。ファイルを集めることと、中身を探すことは、同じスレッドで、続けて行う |
| 設計時 | 部品の欄に出る。探す処理は動かさない |

## 7. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| `Start` が `False` | `OnError` のメッセージ。`Root`・`Pattern`・`FileMask`・`OutputFile` |
| 見つかるはずの行が出ない | `FileMask`（対象のファイルか）。`MaxFileSize`・バイナリ判定（3.4 の 2・4）。文字コード（3.4 の 5） |
| 日本語が文字化けして出る | 文字コードの判定（3.4 の 5）。UTF-8 とみなされなかった CP932 でない文字コード（EUC-JP など）は、対象外 |
| 日本語の正規表現が合わない | `.` がバイト単位であること（3.7） |
| 結果のファイルに、結果のファイル自身が出る | 3.4 の 8（`OutputFile` を対象から外す） |
| 探しているのに止まらない | `StopFlag` の確認（4.1 の 6） |
| `SaveResults` が `False` | `OutputMode` が `omFile` ではないか。`OnError` のメッセージ |

## 8. エディタ側の追加（TCMonacoEditor・TCsEditor の `TagJump`）

結果の行（「パス(行番号): その行の文字」）から、そのファイルの行へ飛ぶ。`TCGrepFile` が、エディタを呼び出す仕組みは持たない（`TCGrepFile` は、エディタを知らない）。エディタ側に、メソッドを 1 つ足すだけにする。

| 項目 | 今 | 変更後 | 変える理由 | リスク |
|---|---|---|---|---|
| タグジャンプ | ない。`OpenFile(ファイル名)`・`SetCursorPos(行, 桁)`・`LineText`（カーソル行の文字）は、ある | 両方に `function TagJump(const ALine: string = ''): Boolean` を足す | 結果のファイルをエディタで開き、その行から、元のファイルの行へ飛べるようにするため | メソッドを足すだけ。今の `OpenFile`・`SetCursorPos`・キー・アクション・イベントは、変えない |

**`TagJump(ALine)` の動き**

1. `ALine` が空なら、カーソル行の文字（`LineText`）を使う。
2. `CGrepParseLine`（3.5）で、パスと行番号に分ける。分けられなければ `False`。
3. パスは、フルパスだけを受ける（`CGrepIsFullPath`。相対パスは `False`）。ファイルがなければ `False`。
4. `OpenFile(パス)`（すでに開いていれば、そのタブをアクティブにする）。開けなければ `False`。
5. `SetCursorPos(行番号, 1)` で、その行へ飛ぶ。行番号が、ファイルの行数より大きいときは、最後の行（`SetCursorPos` の今の動き）。
6. `True`。

- キー・メニュー・標準アクション（25 個）には、つながない。アプリが、好きなキー・メニュー・ボタンから `TagJump` を呼ぶ（例：エディタの `OnDblClick` ではなく、アプリのメニュー・`OnKeyDown`）。
- `TCMonacoEditor` は、WebView2 が非同期だが、`OpenFile` と `SetCursorPos` が出す命令は、順番に処理されるので、`TagJump` は、`OpenFile` のあとに続けて `SetCursorPos` を呼ぶだけでよい（読み込み後に飛ぶ予約は持たない）。`GetCursorPos`・`LineText` は、届くまで少し待つ必要がある。
- `uCsEditor`・`uCmonacos` の uses に `uCGrepFile` を足す（`CGrepParseLine` を使うため）。

## 9. この版の変更（1.0。新しく作る）

| ファイル | 変更 |
|---|---|
| `source/uCGrepFile.pas` | 新規 |
| `source/design/uCXReg.pas`・`source/res/cnavigation_icon.lrs` | 登録とアイコン（`TCGrepFile` を足す） |
| `source/uCXLang.pas` | 文字列を足す（4.3） |
| `source/uCsEditor.pas`・`source/uCmonacos.pas` | `TagJump` を足す（8 章） |
| `packages/cx.lpk`・`cx.pas` | `uCGrepFile` を足す |
| `docs/TCGrepFile_Usage.md`・`TCGrepFile_Design.md`、`docs/en` の同名 | 取説・英語版 |
| `docs/TCMonacoEditor_Usage.md`・`TCsEditor_Usage.md`、`docs/en` の同名 | `TagJump` を足す |
