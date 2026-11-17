# TCFindFile 設計書

作者: aotan083
日付: 2026-11-17
版: 1.0

---

## 1. 目的と方針

- ファイルとフォルダーを、名前で探す部品（`TCFindFile`）。画面を持たない `TComponent`。単独でも使える。
- `TCSearchBox`（`TCSearchBox_Design.md`）は、この部品を使って探す。ユニットは別（`uCFindFile.pas`）。
- 探す方法は、自前の再帰（`FindFirstFileW` で、フォルダーを順にたどる）だけ。Windows の検索のインデックスは使わない。
- ファイル名は、部分一致・ワイルドカード・正規表現で探せる。
- 探す処理は別スレッド。結果は、まとめてメインスレッドへ渡す。
- 含めないもの：ファイルの中身での検索、更新日・サイズ・種類での絞り込み、Linux・macOS（Windows 11 だけ）。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCFindFile.pas` | cx（実行時） | `TCFindFile`、`TCFindMatcher`（名前の判定） |
| `uCXReg.pas`（`source\design`）・`cnavigation_icon.lrs` | cxdsgn（設計時） | パレット [CX] への登録とアイコン（フォームの下の、部品の欄に出る） |

- `uCFindFile` の uses：`Classes, SysUtils, SyncObjs, Windows, Masks, LazUTF8, RegExpr, uCXLang`（メッセージ用）。`Masks`・`LazUTF8` は LazUtils のユニット（UTF-8 に対応したワイルドカード）。ほかの CX のユニットは使わない。
- `RegExpr` は FPC の標準のユニット（追加のパッケージは要らない）。
- initialization・finalization は持たない。
- パッケージは、cx と cxdsgn の 2 つのまま。

## 3. TCFindFile

`TCFindFile = class(TComponent)`。画面を持たない。

### 3.1 型と定数

```pascal
type
  TCFindMatchMode = (fmContains, fmWildcard, fmRegex);      { 部分一致／ワイルドカード（* ?、; で区切って複数）／正規表現 }
  TCFindStopReason = (frDone, frStopped, frLimit, frError); { 最後までたどった／Stop で止めた／MaxResults に達した／エラー }

  TCFindFoundEvent = procedure(Sender: TObject; const APath: string; AIsDir: Boolean) of object;
  TCFindProgressEvent = procedure(Sender: TObject; const AFolder: string; AScanned: Int64; AFound: Integer) of object;
  TCFindFinishedEvent = procedure(Sender: TObject; AFound: Integer; AReason: TCFindStopReason) of object;
  TCFindErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;

  ECFindPattern = class(Exception);                          { 正規表現が正しくない }
```

| 定数 | 値 | 中身 |
|---|---|---|
| `cFindFlushCount` | 50 | 見つかったものを、メインスレッドへ渡す件数 |
| `cFindFlushMs` | 100 | 同じく、時間（ミリ秒）。件数か時間の早い方 |
| `cFindProgressMs` | 200 | `OnProgress` の間隔 |
| `cFindMaxDef` | 10000 | `MaxResults` の既定値 |

### 3.2 プロパティ

| 名前 | 型 | 既定値 | 公開 | 中身 |
|---|---|---|---|---|
| `Root` | `string` | '' | published | 探し始めるフォルダー |
| `Pattern` | `string` | '' | published | 探す名前（`MatchMode` で、意味が変わる。3.5） |
| `MatchMode` | `TCFindMatchMode` | `fmContains` | published | 判定の方法 |
| `CaseSensitive` | `Boolean` | `False` | published | 大文字・小文字を区別するか |
| `IncludeSubfolders` | `Boolean` | `True` | published | サブフォルダーも探すか |
| `IncludeFiles` | `Boolean` | `True` | published | ファイルを結果にするか |
| `IncludeFolders` | `Boolean` | `True` | published | フォルダーも結果にするか（フォルダー名で判定） |
| `SearchHidden` | `Boolean` | `False` | published | 隠し・システム属性のものも探すか |
| `MaxResults` | `Integer` | 10000 | published | 結果の最大数。0 は制限なし。1 より小さい値は 0 |
| `Active` | `Boolean` | ― | public（読む） | 探している最中か |
| `FoundCount` | `Integer` | ― | public（読む） | 今までに見つかった数 |
| `ScannedCount` | `Int64` | ― | public（読む） | 今までに調べた項目の数 |

- 探している最中（`Active`）は、設定を変えても、その探しには影響しない（`Start` のときに、設定を写して渡す）。

### 3.3 メソッド

| メソッド | 中身 |
|---|---|
| `function Start: Boolean` | 別スレッドで探し始める。すでに探していれば `False`。`Root` がフォルダーでない、`Pattern` が空、正規表現が正しくない、のときは、`OnError` を出して `False`（探さない） |
| `procedure Stop` | 止める。スレッドが終わるのを待たない（`OnFinished` は、`frStopped` で来る） |
| `function WaitFor(ATimeoutMs: Integer): Boolean` | 探し終わる（`OnFinished` が来る）まで、メッセージを処理しながら待つ。時間内に終われば `True`。確認用・スクリプト用 |
| `function FindAll(AResult: TStrings): Integer` | 呼んだスレッドの中で、探して、`AResult` にフルパスを入れる。イベントは出さない。見つかった数を返す。エラーは例外（`ECFindPattern`・`EInOutError`）。確認用・スクリプト用 |
| `function CheckPattern(out AError: string): Boolean` | `Pattern` が使えるか（空でなく、正規表現なら、組み立てられるか）。使えなければ `AError` に文 |

### 3.4 イベント

どれも、メインスレッドで呼ばれる。

| イベント | いつ |
|---|---|
| `OnFound(Sender, APath, AIsDir)` | 見つかったとき。スレッドからは、`cFindFlushCount` 件か `cFindFlushMs` ごとにまとめて渡し、そのたびに、まとめの中の数だけ、この手続きを続けて呼ぶ |
| `OnProgress(Sender, AFolder, AScanned, AFound)` | 探している最中、`cFindProgressMs` ごと。今たどっているフォルダー |
| `OnFinished(Sender, AFound, AReason)` | 終わったとき（`OnFound` はすべて呼んだ後） |
| `OnError(Sender, AMessage)` | `Start` で、始められなかったとき（3.3） |

### 3.5 名前の判定（`TCFindMatcher`）

スレッドごとに 1 つ作る（`TRegExpr` は、スレッドをまたいで使えないため）。

```pascal
TCFindMatcher = class
public
  constructor Create(AMode: TCFindMatchMode; const APattern: string; ACaseSensitive: Boolean);  { 正しくなければ ECFindPattern }
  function Match(const AName: string): Boolean;
end;
```

| `MatchMode` | 判定 |
|---|---|
| `fmContains` | 名前に、`Pattern` が含まれるか。大文字・小文字を区別しないときは、両方を `UTF8LowerCase` にして `Pos` |
| `fmWildcard` | `TMaskList.Create(Pattern, ';', CaseSensitive).Matches(名前)`（LazUtils の `Masks`。UTF-8 に対応）。`*` `?`。`;` で区切って複数（`*.pas;*.lfm`）。式が正しくなければ、`Create` で `ECFindPattern` |
| `fmRegex` | `TRegExpr`。`Expression := Pattern`、`ModifierI := not CaseSensitive`。`Exec(名前)`（名前のどこかに、一致すれば真。全体に一致させたいときは、`^…$` を書く）。式が正しくなければ、`Create` で `ECFindPattern`（文は `TRegExpr.ErrorMsg`） |

- 判定は、ファイル名（フォルダー名）だけに対して行う（パスの途中のフォルダー名は見ない）。
- 名前と式は、UTF-8 のまま扱う。そのため、正規表現の `.` や `[ ]` は、バイト単位になる（日本語の文字数を指定する式は、期待どおりにならない。`\.(pas|lfm)$`・`^テスト` のような式は、使える）。この制限は、取説に書く。
- 前後の空白は、`Pattern` に含めたまま比べる（`TCSearchBox` が、前後の空白を除いてから渡す）。

### 3.6 内部の部品（実装部の宣言）

```pascal
TCFindWorker = class            { 探す処理の本体。スレッドからも、同期の FindAll からも使う }
  Root, Pattern: string;  Mode: TCFindMatchMode;
  CaseSensitive, IncludeSubfolders, IncludeFiles, IncludeFolders, SearchHidden: Boolean;
  MaxResults: Integer;
  OnItem: procedure(const APath: string; AIsDir: Boolean) of object;   { 1 件見つかるたび }
  OnFolder: procedure(const AFolder: string) of object;                { 調べるフォルダーが変わるたび }
  StopFlag: Boolean;                                                   { 止める印。別スレッドから True にされる }
  Found: Integer;  Scanned: Int64;
  function Run: TCFindStopReason;                                      { たどる。式が正しくなければ ECFindPattern }
end;

TCFindThread = class(TThread)    { 探すスレッド。結果は、スレッド側にためて、まとめてメインスレッドへ渡す }
  procedure RequestStop;         { StopFlag を立てる }
  procedure Detach;              { 破棄の前に呼ぶ。もう、持ち主へは何も渡さない }
end;

TCFindFile = class(TComponent)
private
  FThread: TCFindThread;         { 探しているスレッド。終わったら nil }
  FFoundCount: Integer;  FScannedCount: Int64;
  FDestroying: Boolean;
  procedure DeliverItems(AItems: TStrings);        { メインスレッドで OnFound を呼ぶ（先頭の 1 文字：D フォルダー、F ファイル） }
  procedure DeliverProgress(...);                  { OnProgress }
  procedure DeliverFinished(AThread, AFound, AScanned, AReason);   { スレッドを片づけて、OnFinished }
  ...
end;
```

- `TCFindMatcher`・`TCFindWorker`・`TCFindThread` は、`uCFindFile` の公開部にある（確認用に、直接使える）。普段は、`TCFindFile` だけを使う。

## 4. 処理

### 4.1 たどり方（スレッド `TCFindThread`。実装部のクラス）

1. `Start` のとき、設定（`Root`・`Pattern`・`MatchMode`…）を `TCFindWorker` に写して、スレッドに渡す。`TCFindMatcher` は、`Run` の中（スレッドの中）で作る（正しくなければ `ECFindPattern`。スレッドは `frError` で終わる。ただし `Start` の `CheckPattern` で先に確かめているので、通常は起きない）。
2. フォルダーの積み（スタック）に、`Root` を入れる。積みが空になるまで、1 つ取り出して、その中を調べる（再帰でなく、積みを使う）。
3. 1 つのフォルダーを調べる：`FindFirstFileW(長いパス(フォルダー + '\*'))` で、項目を順に取る。
   - `.` と `..` は飛ばす。
   - `SearchHidden` が偽のとき、隠し（`FILE_ATTRIBUTE_HIDDEN`）・システム（`FILE_ATTRIBUTE_SYSTEM`）の項目は、結果にせず、フォルダーなら、中にも入らない。
   - フォルダー：`IncludeFolders` なら、名前を `TCFindMatcher.Match`。一致すれば結果。`IncludeSubfolders` で、リパースポイント（`FILE_ATTRIBUTE_REPARSE_POINT`。ジャンクション・シンボリックリンク）でなければ、積みに入れる。リパースポイントの中には入らない（無限にたどるのを避けるため）。
   - ファイル：`IncludeFiles` なら、名前を `Match`。一致すれば結果。
   - 調べた項目ごとに、`ScannedCount` を 1 増やす。
4. 結果は、スレッドのバッファ（`TStringList`。フルパス。フォルダーは、末尾に `\` を付けずに、別の印で区別する）にためる。`cFindFlushCount` 件か `cFindFlushMs` ごとに、`Queue` で、メインスレッドへ渡す（スレッドの `DoDeliverItems`。持ち主の `DeliverItems` を呼ぶ）。
5. `cFindProgressMs` ごとに、`Queue` で `DoDeliverProgress`。
6. 項目ごとに、`StopFlag`（`Stop` が立てる）を調べる。真なら、バッファを渡して、`frStopped` で終わる。止める印に `TThread.Terminate` を使わないのは、スレッドの実行が始まる前に `Terminate` すると、`Execute` が呼ばれず、終わりの知らせが来ないため。
7. 結果が `MaxResults`（0 でなければ）に達したら、バッファを渡して、`frLimit` で終わる。
8. 読めないフォルダー（アクセス拒否など）は、静かに飛ばす（エラーにしない）。
9. 積みが空になったら、バッファを渡して、`frDone` で終わる。`OnFinished` は、最後に `Queue`（`OnFound` が、すべて呼ばれた後）。
10. パスは、長いパスに対応する（260 文字を超えるときは、`\\?\` を前に付ける。`\\server\share` なら `\\?\UNC\server\share`）。結果のパスは、付ける前の形で返す。

### 4.2 `Start`・`Stop`・`Destroy`

| 手続き | 処理 |
|---|---|
| `Start` | `FThread` があれば `False`。`CheckPattern`・`Root` の確認（`DirectoryExists`）。だめなら `OnError` して `False`。`FFoundCount := 0`、`FScannedCount := 0`。スレッドを作って開始（`FreeOnTerminate := False`）。`True` |
| `Stop` | `FThread` があれば `RequestStop`（`StopFlag` を立てる） |
| `Destroy` | `FDestroying := True`。`FThread` があれば `Detach`（もう持ち主へは渡さない。`StopFlag` を立てる）して `WaitFor`、`TThread.RemoveQueuedEvents(スレッド)` で `Queue` に残っているものを捨て、`Free` |
| `DeliverFinished` | `FThread := nil`、スレッドを `Detach`・`WaitFor`・`Free`。そのあと `OnFinished`（`OnFinished` の中から、もう一度 `Start` できる） |


### 4.3 文字列（`uCXLang` へ足すもの）

| ID | 日本語 | English |
|---|---|---|
| `sFfErrEmpty` | 検索する名前を入力してください | Enter a name to search for |
| `sSbErrNoRoot` | 検索を始めるフォルダーがありません：%s | The folder to start from was not found: %s |

`sSbErrNoRoot` は、`TCSearchBox_Design.md` 5 章の文字列と同じもの（1 つだけ足す）。`CheckPattern` が空のときの文は `sFfErrEmpty`、正規表現・ワイルドカードが正しくないときの文は、`TRegExpr`・`TMaskList` のエラーの文。

## 5. 決めていること

| 項目 | 決めたこと |
|---|---|
| 探す方法 | 自前の再帰（`FindFirstFileW`）だけ。インデックスは使わない |
| 名前の判定 | 部分一致・ワイルドカード・正規表現。ファイル名（フォルダー名）だけを見る |
| 正規表現 | FPC の `RegExpr`。UTF-8 のまま。`.` はバイト単位（日本語の文字数の指定は不可） |
| スレッド | 探す処理は別スレッド。結果は、まとめて（50 件か 100 ミリ秒）メインスレッドへ |
| 無限に回らないように | リパースポイントの中には入らない。`MaxResults`（既定 10000） |
| 読めないフォルダー | 静かに飛ばす |
| 設計時 | フォームの下の、部品の欄に出る。探す処理は動かさない |

## 6. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| `Start` が `False` | `OnError` のメッセージ。`Root`・`Pattern`・正規表現の式（`CheckPattern`） |
| 結果が 1 件も出ない | `MatchMode`（部分一致か）。`SearchHidden`。`Root` の読み取り権 |
| 結果が遅れて出る・固まる | `cFindFlushCount`・`cFindFlushMs` |
| 日本語の正規表現が合わない | `.` がバイト単位であること（3.5） |
| 探しているのに止まらない | `StopFlag` の確認（4.1 の 6）。`Stop` の後の `OnFinished` |
| フォームを閉じても、スレッドが残る | `TCFindFile.Destroy` の `WaitFor`（4.2） |

## 7. この版の変更（1.0。新しく作る）

| ファイル | 変更 |
|---|---|
| `source/uCFindFile.pas` | 新規 |
| `source/design/uCXReg.pas`・`source/res/cnavigation_icon.lrs` | 登録とアイコン |
| `packages/cx.lpk`・`cx.pas`・`cxdsgn.lpk` | `uCFindFile` を足す |
| `docs/TCFindFile_Usage.md`・`TCFindFile_Design.md`、`docs/en` の同名 | コードができてから、取説と英語版を作る |
