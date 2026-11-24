# TCGrepFile 取扱説明書

作者: aotan083
日付: 2026-11-17
版: 1.0

---

**動作環境**：Lazarus 5.0 以降（FPC 3.2.2）。Lazarus 4.8 以前は対象外。

## 1. 概要とクラス

フォルダーの中のファイルを、**中身の文字で探す**（grep 検索）部品です。画面は持ちません（フォームに置くと、フォームの下の部品の欄に出ます）。

- 対象のファイルは、名前（`*.pas;*.lfm` など）で絞ります。そのファイルを 1 つずつ開いて、行ごとに、文字を探します。
- 探し方は 2 種類：部分一致、正規表現。
- 探す処理は別のスレッドで動くので、探している間も画面は止まりません。
- 結果の 1 行は、**「パス(行番号): その行の文字」**の形です。Visual Studio・秀丸・サクラエディタの grep 結果と同じ形で、タグジャンプに使えます（TCMonacoEditor・TCsEditor の `TagJump`。9 章）。
- 結果の届け方は、2 種類から選びます（`OutputMode`）。
  - `omEvent`（既定）：見つかった行を `OnFound` で受け取る。
  - `omFile`：見つかった行を、ファイルへ書き出す。
- `omEvent` で探した結果は、あとから `SaveResults` でファイルへ書き出せます。
- 文字コードは自動で判定します（UTF-8、UTF-16（BOM 付き）、CP932（Shift-JIS））。バイナリのファイルと、大きすぎるファイルは、飛ばします。

| 項目 | 内容 |
|---|---|
| Lazarus | 5.0RC1 以降 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCGrepFile` | `uCGrepFile` | cx | `TComponent` | ファイルの中身を探す（grep 検索） |
| `TCGrepMatcher` | `uCGrepFile` | cx | `TObject` | 行が合うかを調べる。`TCGrepFile` が使う。単独でも使える |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCGrepMatchMode` | `uCGrepFile` | `gmContains`（部分一致）、`gmRegex`（正規表現） |
| `TCGrepOutputMode` | `uCGrepFile` | `omEvent`（`OnFound` で届ける）、`omFile`（ファイルへ書き出す） |
| `TCGrepFoundEvent` | `uCGrepFile` | `procedure(Sender: TObject; const APath: string; ALine: Integer; const AText: string) of object` |
| `TCGrepProgressEvent` | `uCGrepFile` | `procedure(Sender: TObject; const AFile: string; AFiles: Integer; AFound: Integer) of object` |
| `TCGrepFinishedEvent` | `uCGrepFile` | `procedure(Sender: TObject; AFiles: Integer; AFound: Integer; AReason: TCFindStopReason) of object` |
| `TCGrepErrorEvent` | `uCGrepFile` | `procedure(Sender: TObject; const AMessage: string) of object` |

- `TCFindStopReason`（終わった理由：`frDone`・`frStopped`・`frLimit`・`frError`）は、`uCFindFile` の型です（`TCFindFile_Usage.md` 1.1）。`OnFinished` を使うコードでは、uses に `uCFindFile` も書きます。`frLimit` は、見つかった行が `MaxResults` に達したときです。
- フォームに置くと、uses に `uCGrepFile` が自動で入り、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

### 1.2 結果の 1 行の形

```
C:\app\laz\CXComponents\source\uCFindFile.pas(123): procedure TCFindThread.Execute;
```

- 1 行 ＝ `パス` ＋ `(` ＋ `行番号` ＋ `): ` ＋ `その行の文字`。行番号は 1 から。
- 行頭の空白は、そのまま残ります。行末の改行は含みません。
- 1 行が 1000 バイトを超えるときは、1000 バイトで切って、末尾に `...` が付きます。
- ファイルに書き出すときは、UTF-8（BOM なし）、行の区切りは CRLF です。
- 次の 2 つの関数を使うと、この形の 1 行を作る・読み戻すことができます。

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `CGrepFormatLine` | `const APath: string; ALine: Integer; const AText: string` | `string` | 結果の 1 行を作る |
| `CGrepParseLine` | `const S: string; out APath: string; out ALine: Integer` | `Boolean` | 結果の 1 行を、パスと行番号に読み戻す。先頭から数えて、最初の「`(` ＋ 数字だけ ＋ `): `」の手前までをパスにする（パスの中の `(x86)` のような括弧は飛ばす）。形式でなければ `False` |

### 1.3 対象になるファイル・飛ばすファイル

| 項目 | 動き |
|---|---|
| `FileMask` | 対象にするファイルの名前（ワイルドカード）。既定値は `*`（すべて）。`*.pas;*.lfm` のように、`;` で複数 |
| サブフォルダー | `IncludeSubfolders`（既定値 `True`）。ジャンクション・シンボリックリンクの中には入らない |
| 隠し・システム属性 | `SearchHidden`（既定値 `False`）が `False` なら、探さない（隠しフォルダーの中にも入らない） |
| バイナリのファイル | 飛ばす（先頭 8192 バイトに NUL（0）がある。BOM 付きの UTF-16 は、バイナリとしない） |
| 大きいファイル | `MaxFileSize`（既定値 10 MB）を超えるファイルは、飛ばす。0 で制限なし |
| 読めないファイル | 静かに飛ばす（エラーにしない） |
| 出力先のファイル | `omFile` のとき、`OutputFile` 自身は、探さない |

文字コードの判定は、次の順です。

1. 先頭が BOM（UTF-8・UTF-16）なら、それに従う。
2. BOM がなければ、全体が正しい UTF-8 かを調べる。正しければ UTF-8。
3. 正しくなければ、CP932（Shift-JIS）とみなす。
4. EUC-JP・BOM なしの UTF-16 など、これ以外の文字コードは、対象外（正しく読めません）。

### 1.4 行の探し方

| `MatchMode` | `Pattern` の書き方 | 例 |
|---|---|---|
| `gmContains`（既定値） | 行に含まれる文字 | `TODO` |
| `gmRegex` | 正規表現（FPC の `RegExpr`）。行のどこかに合えばよい | `^\s*begin\b` |

- 大文字・小文字は、`CaseSensitive` が `False`（既定値）なら区別しません。
- 行は UTF-8 のまま判定します。正規表現の `.` や `[ ]` は、バイト単位で働きます（日本語の文字数を指定する式は、期待どおりになりません）。
- 検索は 1 行ごとです。複数行にまたがる検索はできません。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCGrepFile をフォームに置く。
2. `Root`（探し始めるフォルダー）、`FileMask`（対象のファイル）、`Pattern`（探す文字）を、オブジェクトインスペクタかコードで設定する。
3. イベントタブの `OnFound` をダブルクリックして、見つかった行を使う処理を書く。
4. コードで `Start` を呼ぶ。

## 3. プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Root` | `string` | 読み・書き | 探し始めるフォルダー |
| `FileMask` | `string` | 読み・書き | 対象にするファイルの名前（ワイルドカード。`;` で複数。既定値は `*`）。ファイル名だけで判定する |
| `Pattern` | `string` | 読み・書き | 中身で探す文字（`MatchMode` で、書き方が変わる。1.4） |
| `MatchMode` | `TCGrepMatchMode` | 読み・書き | 行の判定の方法（既定値は `gmContains`） |
| `CaseSensitive` | `Boolean` | 読み・書き | 大文字・小文字を区別するか（既定値は `False`） |
| `IncludeSubfolders` | `Boolean` | 読み・書き | サブフォルダーも探すか（既定値は `True`） |
| `SearchHidden` | `Boolean` | 読み・書き | 隠し・システム属性のファイル・フォルダーも探すか（既定値は `False`） |
| `MaxResults` | `Integer` | 読み・書き | 見つかった行の最大数（既定値は 10000）。0 は制限なし。0 より小さい値は 0 になる。達したら探すのをやめる（`frLimit`） |
| `MaxFileSize` | `Int64` | 読み・書き | 読むファイルの最大の大きさ（バイト。既定値は 10485760 = 10 MB）。超えるファイルは飛ばす。0 は制限なし。0 より小さい値は 0 になる |
| `OutputMode` | `TCGrepOutputMode` | 読み・書き | 結果の届け方（既定値は `omEvent`） |
| `OutputFile` | `string` | 読み・書き | `omFile` のときの、書き出すファイル。探し始めるときに作り直す（既存のファイルは上書き） |
| `Active` | `Boolean` | 読み | 探している最中なら `True`。実行時だけ |
| `FoundCount` | `Integer` | 読み | 今までに見つかった行の数。実行時だけ |
| `FileCount` | `Integer` | 読み | 今までに調べたファイルの数（バイナリ・大きすぎる・読めないファイルは数えない）。実行時だけ |

- 探している最中に設定を変えても、その探しには影響しません（`Start` のときの設定で探します）。

## 4. メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Start` | ― | `Boolean` | 別のスレッドで探し始める。すでに探している、`Root` がフォルダーでない、`Pattern` が空、式が正しくない（正規表現・`FileMask`）、`omFile` で `OutputFile` が空・書けない、のときは、`OnError` を出して `False`（探さない） |
| `Stop` | ― | ― | 探すのを止める。止まるのを待たない（`OnFinished` が `frStopped` で届く） |
| `WaitFor` | `ATimeoutMs: Integer` | `Boolean` | 探し終わる（`OnFinished` が届く）まで、メッセージを処理しながら待つ。時間内に終われば `True`。`-1` は時間の制限なし |
| `GrepAll` | `AResult: TStrings` | `Integer` | 呼んだスレッドの中で探して、`AResult` に結果の 1 行ずつ（1.2 の形）を入れる（先に空にする）。見つかった行の数を返す。イベントは出さない。`Root` がフォルダーでなければ `EInOutError`、`Pattern` が空・式が正しくなければ `ECFindPattern`。5 章 |
| `SaveResults` | `const AFileName: string` | `Boolean` | `omEvent` で探した結果を、ファイルへ書き出す。6 章 |
| `CheckPattern` | `out AError: string` | `Boolean` | 探し始める前に、`Pattern`・`FileMask` が使えるかを確かめる。使えなければ `False` で、理由が `AError` に入る。7 章 |

## 5. 探し終わるまで待つ：`Start` と `WaitFor`、`GrepAll`

結果を待ちたいときは、2 つの方法があります。

### 5.1 `Start` と `WaitFor`

```pascal
CGrepFile1.Root := 'C:\app';
CGrepFile1.FileMask := '*.pas';
CGrepFile1.Pattern := 'TODO';
if CGrepFile1.Start then
  CGrepFile1.WaitFor(-1);      // 探し終わるまで待つ（-1 は時間の制限なし）
// ここに来たとき、OnFound も OnFinished も、すべて呼ばれ終わっている
```

- `Start` で、別のスレッドが探し始めます。見つかった行は、メインスレッドで、`OnFound` として届きます。
- `WaitFor` は、待っている間に、メインスレッドの仕事（`OnFound` の呼び出しなど）を処理します。そのため、`WaitFor` の中で `OnFound` が呼ばれます。画面も固まりません。
- `OnFound` は、「見つかるたびに 1 件ずつ、すぐ」ではありません。見つかった行は、50 件か 0.1 秒のどちらか早いほうで、まとめて渡され、そのあと 1 件ずつ、続けて呼ばれます。見つかってから届くまで、最大 0.1 秒ほど遅れます。
- `Start` が `False` のとき（`Root` がない、`Pattern` が空など）は、探していないので、`WaitFor` は不要です。上のように `if` で囲みます。
- 時間に制限をつけるときは、ミリ秒で渡します。`WaitFor(5000)` は、5 秒待って、終わっていなければ `False` を返します（探しはそのまま続きます。止めるなら `Stop`）。
- 待っている間は、アプリのほかの操作も動きます。ボタンの二重押しなどが起きないようにします。

### 5.2 `GrepAll`

```pascal
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    CGrepFile1.Root := 'C:\app';
    CGrepFile1.FileMask := '*.pas';
    CGrepFile1.Pattern := 'TODO';
    CGrepFile1.GrepAll(L);        // 探し終わるまで戻らない
    Memo1.Lines.Assign(L);        // 1 行ずつ「パス(行番号): 文字」
  finally
    L.Free;
  end;
end;
```

- `GrepAll` は、呼んだスレッドの中で探して、探し終わるまで戻らない、同期の探し方です。別のスレッドは使いません。

### 5.3 `Start` と `GrepAll` の違い

| | `GrepAll` | `Start`（と `WaitFor`） |
|---|---|---|
| 探す場所 | 呼んだスレッドの中（別スレッドは使わない） | 別スレッド |
| 戻るとき | 探し終わったとき | `Start` はすぐ。`WaitFor` は探し終わったとき |
| 結果の受け取り | 引数の一覧（1 行ずつ、`パス(行番号): 文字`） | `OnFound`（パス・行番号・文字を別々に）。または、ファイル |
| イベント | 出さない（`OnFound`・`OnFinished` なし） | 出す |
| 途中の画面 | 固まる（探している間、画面は動かない） | 動く |
| `Stop` で止める | できない（呼んだスレッドの中なので） | できる |
| 戻り値 | 見つかった行の数 | `Start` は始められたか |
| エラー | 例外（`ECFindPattern`・`EInOutError`） | `OnError` と `False` |
| `OutputMode` | 使わない（いつも一覧に入れる） | `omEvent` か `omFile` |

**向いている場面**
- `GrepAll`：範囲が小さくて、すぐ終わる探し。スクリプトや、画面のないツール。テスト。
- `Start`：大きいフォルダー。画面を動かしたまま、途中の結果を見たいとき。途中で止めたいとき。

結果の最大数（`MaxResults`、既定値 10000 行）は、どちらにも効きます。

## 6. 結果をファイルに保存する：`SaveResults`

`SaveResults` は、探し終わってから呼びます。`OnFinished` の中で呼ぶのが、いちばん分かりやすい使い方です。

```pascal
procedure TForm1.CGrepFile1Finished(Sender: TObject; AFiles, AFound: Integer;
  AReason: TCFindStopReason);
begin
  Caption := Format('%d 行見つかりました', [AFound]);
  if AFound > 0 then
    CGrepFile1.SaveResults('C:\work\grep_result.txt');   // 結果をファイルに保存
end;
```

`Start` を呼んだあとなら、探し終わるのを待ってからでも使えます。

```pascal
if CGrepFile1.Start then
  CGrepFile1.WaitFor(-1);
CGrepFile1.SaveResults('C:\work\grep_result.txt');
```

| 項目 | 内容 |
|---|---|
| いつ呼ぶか | 探し終わったあと（`OnFinished` の中、または `WaitFor` のあと）。探している最中に呼ぶと、そこまでの結果しか書きません |
| 何が書かれるか | 直前の探しの結果（メモリに残してあるもの）。`MaxResults`（既定値 10000 行）まで。次の `Start` で消える |
| 書式 | 1.2 の形。UTF-8（BOM なし）、CRLF。既存のファイルは上書き |
| 保存先のフォルダー | なければ、自動で作る（途中のフォルダーも、すべて） |
| `OutputMode` | `omEvent` のときだけ使える。`omFile` のときは `False`（結果がメモリにないため。`OnError` も届く） |
| 結果が 0 件のとき | 空のファイルを作って `True` |
| 書けないとき | `False`（`OnError` も届く。たとえば、保存先の場所にファイルがあってフォルダーを作れない、書き込めない場所） |

**`omFile` との使い分け**
- 探したあとで、「保存するかどうか」を決めたい：`omEvent` で探して、`SaveResults`。
- 最初から、必ずファイルに出したい（結果が非常に多い、途中でも開きたい）：`omFile`。探している最中から、少しずつファイルへ書き足されるので、途中でも開けます。

## 7. 探す前に確かめる：`CheckPattern`

`CheckPattern` は、探し始める前に、`Pattern` と `FileMask` が使えるかを確かめます。正規表現が正しくない、`Pattern` が空、などを、探す前に見つけられます。

```pascal
var
  Err: string;
begin
  CGrepFile1.Root := Edit1.Text;
  CGrepFile1.MatchMode := gmRegex;
  CGrepFile1.Pattern := Edit2.Text;       // 利用者が入力した正規表現
  if not CGrepFile1.CheckPattern(Err) then
  begin
    ShowMessage(Err);                      // 理由が入っている
    Exit;
  end;
  CGrepFile1.Start;
end;
```

| 項目 | 使えないとき |
|---|---|
| `Pattern` が空 | `False`。`Err` に「検索する文字を入力してください」 |
| 正規表現（`gmRegex`） | 式が正しくなければ `False`。`Err` に、正規表現のエラーの文 |
| `FileMask` | ワイルドカードが正しくなければ `False`。`Err` にエラーの文 |

- `Start` も、始める前に、同じ確認をします。正しくなければ、`OnError` を出して `False` を返します。そのため、`CheckPattern` を呼ばなくても動きます。
- 先に `CheckPattern` を呼ぶのは、探し始める前に、自分の画面（入力欄の下のラベルなど）へ、すぐメッセージを出したいときです。
- `GrepAll` は、式が正しくないと、例外（`ECFindPattern`）になります。例外にしたくないなら、先に `CheckPattern` で確かめます。

```pascal
if CGrepFile1.CheckPattern(Err) then
  CGrepFile1.GrepAll(Memo1.Lines)
else
  ShowMessage(Err);
```

## 8. イベント

すべて、メインスレッドで呼ばれます（`OnFound` の中で、画面を触ってかまいません）。

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnFound` | `Sender: TObject; const APath: string; ALine: Integer; const AText: string` | 見つかった行が 1 件あるとき（`omEvent` のときだけ）。`APath`：ファイルのフルパス、`ALine`：行番号（1 から）、`AText`：その行の文字（1000 バイトを超えるときは切って `...`） |
| `OnProgress` | `Sender: TObject; const AFile: string; AFiles: Integer; AFound: Integer` | 探している最中、0.2 秒ごと。今読んでいるファイル・調べたファイルの数・見つかった行の数 |
| `OnFinished` | `Sender: TObject; AFiles: Integer; AFound: Integer; AReason: TCFindStopReason` | 終わったとき（`OnFound` はすべて呼ばれた後。`omFile` のときは、ファイルを閉じた後）。`AFiles`：調べたファイルの数、`AFound`：見つかった行の数。この中から、`SaveResults` や、もう一度 `Start` を呼んでもよい |
| `OnError` | `Sender: TObject; const AMessage: string` | `Start` で始められなかったとき。`omFile` で、探している最中に書けなくなったとき（探すのを止めて、`OnFinished` は `frError`）。`SaveResults` で保存できなかったとき |

## 9. タグジャンプ：結果の行から、その行へ飛ぶ

TCMonacoEditor と TCsEditor には、`TagJump` があります。結果の 1 行（「パス(行番号): 文字」）を渡すと、そのファイルを開いて、その行へ飛びます。`TCGrepFile` が、エディタを呼び出すことはありません。アプリが、好きなキー・メニュー・ボタンから `TagJump` を呼びます。

```pascal
// 結果の 1 行を渡して、飛ぶ
MonacoEditor1.TagJump('C:\app\a.pas(123): begin');

// 結果のファイル（SaveResults で書いたもの）をエディタで開いて、カーソル行の文字で飛ぶ
MonacoEditor1.OpenFile('C:\work\grep_result.txt');
// （結果の行にカーソルを置いてから）
MonacoEditor1.TagJump;
```

- 詳しくは、`TCMonacoEditor_Usage.md`・`TCsEditor_Usage.md` のメソッドの表にあります。
- パスは、フルパスだけを受けます（相対パスは `False`）。

## 10. 注意

- Windows 専用。
- 結果の並びは、フォルダーをたどった順で、名前順ではありません。並べたいときは、受け取ってから並べます。
- 結果は、最大 `MaxResults` 行（既定値 10000）までです。それを超える探しは、`frLimit` で終わります。
- ファイルは、全部メモリに読んでから探します。大きいファイルを探すときは、`MaxFileSize` に注意してください。
- ネットワークドライブは、読み込みに時間がかかることがあります。`Stop` で止められます。
- フォームを閉じる（部品を壊す）ときは、探している最中なら止めて、スレッドが終わるのを待ちます。
- `omFile` で探している最中は、`OutputFile` を、ほかのアプリが開いていると、書けないことがあります。

## 11. 使い方の例

### 11.1 `TODO` を探して、結果を一覧に出す

```pascal
procedure TForm1.Button1Click(Sender: TObject);
begin
  ListBox1.Items.Clear;
  CGrepFile1.Root := 'C:\app';
  CGrepFile1.FileMask := '*.pas;*.lfm';
  CGrepFile1.Pattern := 'TODO';
  CGrepFile1.Start;
end;

procedure TForm1.CGrepFile1Found(Sender: TObject; const APath: string; ALine: Integer; const AText: string);
begin
  ListBox1.Items.Add(CGrepFormatLine(APath, ALine, AText));
end;
```

### 11.2 最初から、結果をファイルに出す

```pascal
CGrepFile1.OutputMode := omFile;
CGrepFile1.OutputFile := 'C:\work\grep_result.txt';
CGrepFile1.Pattern := 'TODO';
CGrepFile1.Start;
```

### 11.3 コードで作る

```pascal
uses uCGrepFile, uCFindFile;

var
  G: TCGrepFile;
begin
  G := TCGrepFile.Create(Self);
  G.Root := 'C:\app';
  G.FileMask := '*.pas';
  G.MatchMode := gmRegex;
  G.Pattern := '^\s*procedure\s+T\w+\.Execute';
  G.OnFound := @MyFound;
  G.OnFinished := @MyFinished;
  G.Start;
end;
```
