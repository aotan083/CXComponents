# TCFindFile 取扱説明書

作者: aotan083
日付: 2026-11-17
版: 1.1

---

**動作環境**：Lazarus 5.0 以降（FPC 3.2.2）。Lazarus 4.8 以前は対象外。

## 1. 概要とクラス

フォルダーの中を、ファイル・フォルダーの名前で探す部品です。画面は持ちません（フォームに置くと、フォームの下の部品の欄に出ます）。

- 名前の探し方は 3 種類：部分一致、ワイルドカード（`*` `?`、`;` で複数）、正規表現。
- 探す処理は別のスレッドで動くので、探している間も画面は止まりません。見つかったものは、少しずつ（50 件か 0.1 秒ごと）まとめて、`OnFound` で届きます。
- サブフォルダーの中も探せます。ジャンクション・シンボリックリンクの中には入りません。読めないフォルダーは、静かに飛ばします。
- Windows の検索のインデックスは使いません。フォルダーを順にたどって探します。
- 検索ボックスの部品 TCSearchBox（`TCSearchBox_Usage.md`）が、この部品を使っています。単独でも使えます。

| 項目 | 内容 |
|---|---|
| Lazarus | 5.0RC1 以降 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCFindFile` | `uCFindFile` | cx | `TComponent` | 名前でファイル・フォルダーを探す |
| `TCFindMatcher` | `uCFindFile` | cx | `TObject` | 名前が合うかを調べる（1.2）。`TCFindFile` が使う。単独でも使える |
| `ECFindPattern` | `uCFindFile` | cx | `Exception` | 正規表現・ワイルドカードの式が正しくないときの例外 |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCFindMatchMode` | `uCFindFile` | `fmContains`（部分一致）、`fmWildcard`（ワイルドカード）、`fmRegex`（正規表現） |
| `TCFindStopReason` | `uCFindFile` | 終わった理由。`frDone`：最後までたどった、`frStopped`：`Stop` で止めた、`frLimit`：`MaxResults` に達した、`frError`：エラー |
| `TCFindFoundEvent` | `uCFindFile` | `procedure(Sender: TObject; const APath: string; AIsDir: Boolean) of object` |
| `TCFindProgressEvent` | `uCFindFile` | `procedure(Sender: TObject; const AFolder: string; AScanned: Int64; AFound: Integer) of object` |
| `TCFindFinishedEvent` | `uCFindFile` | `procedure(Sender: TObject; AFound: Integer; AReason: TCFindStopReason) of object` |
| `TCFindErrorEvent` | `uCFindFile` | `procedure(Sender: TObject; const AMessage: string) of object` |

- フォームに置くと、uses に `uCFindFile` が自動で入り、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

### 1.2 名前の探し方

名前の判定は、ファイル名・フォルダー名だけに対して行います（途中のフォルダーの名前は見ません）。

| `MatchMode` | `Pattern` の書き方 | 例 |
|---|---|---|
| `fmContains`（既定値） | 名前に含まれる文字 | `pas`：`a.pas`、`Pascal.txt` |
| `fmWildcard` | `*`：任意の文字列、`?`：1 文字。`;` で区切って複数 | `*.pas;*.lfm` |
| `fmRegex` | 正規表現（FPC の `RegExpr`）。名前のどこかに合えばよい。名前全体に合わせたいときは `^` と `$` を書く | `\.(pas|lfm)$`、`^テスト` |

- 大文字・小文字は、`CaseSensitive` が `False`（既定値）なら区別しません。
- 名前は UTF-8 のまま判定します。正規表現の `.` や `[ ]` は、バイト単位で働きます（日本語の文字数を指定する式は、期待どおりになりません）。`\.(pas|lfm)$` や `^テスト` のような式は使えます。
- `Pattern` の前後の空白は、そのまま比べます。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCFindFile をフォームに置く。
2. `Root`（探し始めるフォルダー）と `Pattern`（探す名前）を、オブジェクトインスペクタかコードで設定する。
3. イベントタブの `OnFound` をダブルクリックして、見つかったものを使う処理を書く。
4. コードで `Start` を呼ぶ。

## 3. プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Root` | `string` | 読み・書き | 探し始めるフォルダー |
| `Pattern` | `string` | 読み・書き | 探す名前（`MatchMode` によって書き方が変わる。1.2） |
| `MatchMode` | `TCFindMatchMode` | 読み・書き | 判定の方法（既定値は `fmContains`） |
| `CaseSensitive` | `Boolean` | 読み・書き | 大文字・小文字を区別するか（既定値は `False`） |
| `IncludeSubfolders` | `Boolean` | 読み・書き | サブフォルダーの中も探すか（既定値は `True`） |
| `IncludeFiles` | `Boolean` | 読み・書き | ファイルを結果にするか（既定値は `True`） |
| `IncludeFolders` | `Boolean` | 読み・書き | フォルダーも結果にするか（既定値は `True`。フォルダー名で判定する） |
| `SearchHidden` | `Boolean` | 読み・書き | 隠し・システム属性のものも探すか（既定値は `False`。隠しフォルダーの中にも入らない） |
| `MaxResults` | `Integer` | 読み・書き | 結果の最大数（既定値は 10000）。0 は制限なし。0 より小さい値は 0 になる。達したら探すのをやめる |
| `Active` | `Boolean` | 読み | 探している最中なら `True`。実行時だけ |
| `FoundCount` | `Integer` | 読み | 今までに見つかった数。実行時だけ |
| `ScannedCount` | `Int64` | 読み | 今までに調べた項目の数。実行時だけ |

- 探している最中に設定を変えても、その探しには影響しません（`Start` のときの設定で探します）。

## 4. メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Start` | ― | `Boolean` | 別のスレッドで探し始める。すでに探している、`Root` がフォルダーでない、`Pattern` が空、正規表現・ワイルドカードの式が正しくない、のときは、`OnError` を出して `False`（探さない） |
| `Stop` | ― | ― | 探すのを止める。止まるのを待たない（`OnFinished` が `frStopped` で届く） |
| `WaitFor` | `ATimeoutMs: Integer` | `Boolean` | 探し終わる（`OnFinished` が届く）まで、メッセージを処理しながら待つ。時間内に終われば `True`。`-1` は時間の制限なし |
| `FindAll` | `AResult: TStrings` | `Integer` | 呼んだスレッドの中で探して、`AResult` にフルパスを入れる（先に空にする）。見つかった数を返す。イベントは出さない。`Root` がフォルダーでなければ `EInOutError`、式が正しくなければ `ECFindPattern`。短い探しや、スクリプトで使う |
| `CheckPattern` | `out AError: string` | `Boolean` | `Pattern` が使えるか（空でなく、正規表現・ワイルドカードなら組み立てられるか）。使えなければ `AError` に理由が入る |

## 5. 探し終わるまで待つ：`Start` と `WaitFor`、`FindAll`

結果を待ちたいときは、2 つの方法があります。

### 5.1 `Start` と `WaitFor`

```pascal
CFindFile1.Root := 'C:\app';
CFindFile1.MatchMode := fmWildcard;
CFindFile1.Pattern := '*.pas';
if CFindFile1.Start then
  CFindFile1.WaitFor(-1);      // 探し終わるまで待つ（-1 は時間の制限なし）
// ここに来たとき、OnFound も OnFinished も、すべて呼ばれ終わっている
```

- `Start` で、別のスレッドが探し始めます。見つかったものは、メインスレッドで、`OnFound` として届きます。
- `WaitFor` は、待っている間に、メインスレッドの仕事（`OnFound` の呼び出しなど）を処理します。そのため、`WaitFor` の中で `OnFound` が呼ばれます。画面も固まりません。
- `OnFound` は、「見つかるたびに 1 件ずつ、すぐ」ではありません。見つかったものは、50 件か 0.1 秒のどちらか早いほうで、まとめて渡され、そのあと 1 件ずつ、続けて呼ばれます。見つかってから届くまで、最大 0.1 秒ほど遅れます。
- `Start` が `False` のとき（`Root` がない、`Pattern` が空など）は、探していないので、`WaitFor` は不要です。上のように `if` で囲みます。
- 時間に制限をつけるときは、ミリ秒で渡します。`WaitFor(5000)` は、5 秒待って、終わっていなければ `False` を返します（探しはそのまま続きます。止めるなら `Stop`）。
- 待っている間は、アプリのほかの操作も動きます。ボタンの二重押しなどが起きないようにします。

### 5.2 `FindAll`

```pascal
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    CFindFile1.Root := 'C:\app';
    CFindFile1.MatchMode := fmWildcard;
    CFindFile1.Pattern := '*.pas';
    CFindFile1.FindAll(L);        // 探し終わるまで戻らない
    Memo1.Lines.Assign(L);        // 見つかったものの、フルパス
  finally
    L.Free;
  end;
end;
```

- `FindAll` は、呼んだスレッドの中で探して、探し終わるまで戻らない、同期の探し方です。別のスレッドは使いません。

### 5.3 `Start` と `FindAll` の違い

| | `FindAll` | `Start`（と `WaitFor`） |
|---|---|---|
| 探す場所 | 呼んだスレッドの中（別スレッドは使わない） | 別スレッド |
| 戻るとき | 探し終わったとき | `Start` はすぐ。`WaitFor` は探し終わったとき |
| 結果の受け取り | 引数の一覧（フルパス） | `OnFound`（フルパスと、フォルダーかどうか） |
| イベント | 出さない（`OnFound`・`OnFinished` なし） | 出す |
| 途中の画面 | 固まる（探している間、画面は動かない） | 動く |
| `Stop` で止める | できない（呼んだスレッドの中なので） | できる |
| 戻り値 | 見つかった数 | `Start` は始められたか |
| エラー | 例外（`ECFindPattern`・`EInOutError`） | `OnError` と `False` |

**向いている場面**
- `FindAll`：範囲が小さくて、すぐ終わる探し。スクリプトや、画面のないツール。テスト。
- `Start`：大きいフォルダー。画面を動かしたまま、途中の結果を見たいとき。途中で止めたいとき。

結果の最大数（`MaxResults`、既定値 10000）は、どちらにも効きます。

## 6. 探す前に確かめる：`CheckPattern`

`CheckPattern` は、探し始める前に、`Pattern` が使えるかを確かめます。正規表現が正しくない、`Pattern` が空、などを、探す前に見つけられます。

```pascal
var
  Err: string;
begin
  CFindFile1.Root := Edit1.Text;
  CFindFile1.MatchMode := fmRegex;
  CFindFile1.Pattern := Edit2.Text;       // 利用者が入力した正規表現
  if not CFindFile1.CheckPattern(Err) then
  begin
    ShowMessage(Err);                      // 理由が入っている
    Exit;
  end;
  CFindFile1.Start;
end;
```

| 項目 | 使えないとき |
|---|---|
| `Pattern` が空 | `False`。`Err` に「検索する名前を入力してください」 |
| 正規表現（`fmRegex`）・ワイルドカード（`fmWildcard`） | 式が正しくなければ `False`。`Err` に、エラーの文 |

- `Start` も、始める前に、同じ確認をします。正しくなければ、`OnError` を出して `False` を返します。そのため、`CheckPattern` を呼ばなくても動きます。
- 先に `CheckPattern` を呼ぶのは、探し始める前に、自分の画面（入力欄の下のラベルなど）へ、すぐメッセージを出したいときです。
- `FindAll` は、式が正しくないと、例外（`ECFindPattern`）になります。例外にしたくないなら、先に `CheckPattern` で確かめます。

```pascal
if CFindFile1.CheckPattern(Err) then
  CFindFile1.FindAll(Memo1.Lines)
else
  ShowMessage(Err);
```

## 7. イベント

すべて、メインスレッドで呼ばれます（`OnFound` の中で、画面を触ってかまいません）。

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnFound` | `Sender: TObject; const APath: string; AIsDir: Boolean` | 見つかったとき。`APath` はフルパス、`AIsDir` はフォルダーなら `True`。まとめて届くが、1 件ずつ呼ばれる |
| `OnProgress` | `Sender: TObject; const AFolder: string; AScanned: Int64; AFound: Integer` | 探している最中、0.2 秒ごと。今たどっているフォルダー・調べた数・見つかった数 |
| `OnFinished` | `Sender: TObject; AFound: Integer; AReason: TCFindStopReason` | 終わったとき（`OnFound` は、すべて呼ばれた後）。この中から、もう一度 `Start` してもよい |
| `OnError` | `Sender: TObject; const AMessage: string` | `Start` で始められなかったとき |

## 8. 注意

- Windows 専用。
- 結果のパスの並びは、フォルダーをたどった順で、名前順ではありません。並べたいときは、受け取ってから並べる。
- 260 文字を超えるパスも探せます（`\\?\` 形式で扱う）。結果のパスは、`\\?\` を付けない形で届きます。
- ネットワークドライブは、読み込みに時間がかかることがあります。`Stop` で止められます。
- フォームを閉じる（部品を壊す）ときは、探している最中なら止めて、スレッドが終わるのを待ちます。

## 9. 使い方の例

### 9.1 `*.pas` を探して、一覧に入れる

```pascal
procedure TForm1.FindPas(const AFolder: string);
begin
  CFindFile1.Root := AFolder;
  CFindFile1.MatchMode := fmWildcard;
  CFindFile1.Pattern := '*.pas';
  CFindFile1.Start;
end;

procedure TForm1.CFindFile1Found(Sender: TObject; const APath: string; AIsDir: Boolean);
begin
  ListBox1.Items.Add(APath);
end;

procedure TForm1.CFindFile1Finished(Sender: TObject; AFound: Integer; AReason: TCFindStopReason);
begin
  Caption := Format('%d 件', [AFound]);
end;
```

### 9.2 結果を待たずに、すぐ受け取る（短い探し）

```pascal
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    CFindFile1.Root := 'C:\app';
    CFindFile1.Pattern := 'readme';
    CFindFile1.FindAll(L);      // 探し終わるまで戻らない
    Memo1.Lines.Assign(L);
  finally
    L.Free;
  end;
end;
```

### 9.3 コードで作る

```pascal
uses uCFindFile;

var
  F: TCFindFile;
begin
  F := TCFindFile.Create(Self);
  F.Root := 'C:\app';
  F.MatchMode := fmRegex;
  F.Pattern := '\.(pas|lfm)$';
  F.OnFound := @MyFound;
  F.Start;
end;
```
