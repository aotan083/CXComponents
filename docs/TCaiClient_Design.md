# TCaiClient 設計書

作者: aotan083
日付: 2026-11-23
版: 1.6

---

**動作環境**：Lazarus 5.0 以降（FPC 3.2.2）。Lazarus 4.8 以前は対象外。

## 1. 目的と方針

- TCaiClient は、アプリから AI の API を呼ぶための非ビジュアル部品（`TComponent`）。
- 受け持つのは「疎通」まで。送る → 回答の文字列を受け取る → 失敗を知らせる。回答の品質・費用の管理は受け持たない。
- 使う AI は `AIType` で 1 つ選ぶ：`aiGemini`・`aiClaude`・`aiChatGPT`・`aiMeta`・`aiOllama`。
- 送るもの：①テキストだけ、②テキスト＋添付ファイル。
- 受け取るもの：①テキスト（Markdown 記法なし）＝`AskAndWaitText`、②Markdown＝`AskAndWaitMD`。回答の形は、AI への指示文（システム指示）で頼む。部品は回答を作り直さない。
- **呼び方は「完了復帰」（同期）だけ**。`AskAndWaitText`・`AskAndWaitMD` は回答が来るまで戻らず、回答の文字列を返す。失敗したら `''` を返し、理由は `LastError` に入る。非同期の呼び方（イベントで回答を返す）は持たない。
- 待つ間も画面は固まらない。通信は裏のスレッドで行い、メインスレッドは部品の中で `Application.ProcessMessages`＋`Sleep(10)` を繰り返して待つ（アプリは `ProcessMessages` を書かなくてよい）。
- 接続先 URL・モデル名・API キーを入れた環境変数の名前・タイムアウト・リトライは `WebView2.ini` に書く（RULES 17）。API キーそのものは ini に書かず、環境変数に入れる。
- 作る順番：aiGemini → aiOllama → aiChatGPT → aiMeta → aiClaude。課金しないと試せないものを後ろにするため。aiOllama は無料（ローカル）。aiChatGPT・aiMeta は同じ形式（Chat Completions）で、Ollama の同じ形式の入口（`/v1/chat/completions`）に向ければ、課金なしで要求と回答の形を確かめられる。aiClaude は独自の形式で、課金が要るため最後にする。5 つの AI のすべてが動く（`ceNotSupported` は、将来、対応していない AI が増えたときのために残している）。

### 1.1 含めないもの

- 会話の履歴（複数回のやりとり）。1 回の送信で完結する。履歴が要るときは、アプリが前の回答を AText に入れて送る。
- ストリーミング（少しずつ受け取る表示）。回答は全部そろってから返す。
- 関数呼び出し（tool use）・画像生成・音声。
- 各社のファイル置き場（Gemini Files API など）。添付は 1 回の要求の中に入れて送る。
- 費用・トークン数の管理（回答 JSON にある使用量は、そのまま `LastUsage` で見せるだけ）。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCaiClient.pas`（`source`） | cx（実行時） | `TCaiClient`、通信用スレッド、AI ごとの要求の組み立て・回答の読み取り |
| `uCXReg.pas`（`source\design`） | cxdsgn（設計時） | パレット [CX] への登録（並びの末尾に `TCaiClient`） |
| `caiclient_icon.lrs`（`source\res`） | cxdsgn（設計時） | アイコン（`TCaiClient`・`_150`・`_200`） |
| `uCXLang.pas` | cx（実行時） | メッセージの文言 29 個を足す（ja・en。`sAiInstrText` から `sAiHintGateway`。CXLang_Design.md 5 章 M） |
| `cx.lpk` | cx | `../source/uCaiClient.pas`（UnitName `uCaiClient`）を足す |

- uses：`Windows, Classes, SysUtils, SyncObjs, IniFiles, Forms, fpjson, jsonparser, base64, winhttp`。実装部で `uCXLang`。WebView2 は使わない。
- initialization・finalization は持たない。

### 2.1 HTTPS（WinHTTP）

- 通信は Windows に入っている WinHTTP（FPC 3.2.2 の `winhttp` ユニット）で行う。EXE と一緒に置く DLL は無い。
- 使う関数：`WinHttpOpen` → `WinHttpConnect` → `WinHttpOpenRequest`（https は `WINHTTP_FLAG_SECURE`）→ `WinHttpAddRequestHeaders` → `WinHttpSendRequest` → `WinHttpReceiveResponse` → `WinHttpQueryHeaders`（ステータス・`Retry-After`）→ `WinHttpReadData` → `WinHttpCloseHandle`。
- URL の分解は `WinHttpCrackUrl`。http（Ollama の localhost）も同じ関数で送る。
- プロキシは Windows の設定に従う（`WinHttpOpen` に `WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY`。開けなければ `WINHTTP_ACCESS_TYPE_DEFAULT_PROXY`）。
- 待ち時間は `WinHttpSetTimeouts`。FPC 3.2.2 の `winhttp` ユニットは、この関数の名前を `WinHttpSetTimes` と書き誤っているので、`uCaiClient` の中で `external 'winhttp.dll'` として宣言し直す。
- 待ち時間を過ぎたときのエラー番号は 12002（`winhttp` ユニットでは `ERROR_WINHTTP_TIME`）。`uCaiClient` の定数 `ERR_WINHTTP_TIMEOUT` で持つ。
- 要求の本文は UTF-8 の JSON、回答も UTF-8 として読む。
- `ceConnect` の `LastError` には、WinHTTP のエラー番号と URL が入る（例：`接続できません（WinHTTP 12007）: https://…`）。

## 3. WebView2.ini

EXE の隣の `WebView2.ini` に、AI ごとのセクションを足す。読むのは、`TCaiClient` が最初に送るとき 1 回だけ（`ReloadSettings` で読み直し）。`%名前%` の置き換えは `uCXRuntime` の `CXExpandIniVars` と同じ書き方（同じセクション内のキーを参照）。

```ini
[CaiClient]
TimeoutSeconds=120
RetryCount=2
RetryWaitSeconds=3
LogFolder=

[CaiGemini]
Url=https://generativelanguage.googleapis.com/v1beta/models/%Model%:generateContent
Model=gemini-3.8-flash
ApiKeyEnv=GEMINI_API_KEY

[CaiClaude]
Url=https://api.anthropic.com/v1/messages
Model=claude-haiku-5-5
ApiKeyEnv=CX_ANTHROPIC_API_KEY

[CaiChatGPT]
Url=https://api.openai.com/v1/chat/completions
Model=gpt-4o-mini
ApiKeyEnv=OPENAI_API_KEY

[CaiMeta]
Url=https://api.meta.ai/v1/chat/completions
Model=muse-spark-1.3
ApiKeyEnv=MODEL_API_KEY

[CaiOllama]
Url=http://localhost:11434/api/chat
Model=gemma3:4b
ApiKeyEnv=
```

**[CaiClient]（全 AI 共通）**

| キー | 意味 |
|---|---|
| `TimeoutSeconds` | 接続・送信・受信の待ち時間（秒）。既定 120 |
| `RetryCount` | 失敗したとき、やり直す回数。既定 2（最大 3 回送る） |
| `RetryWaitSeconds` | やり直す前に待つ秒数。回数ごとに倍にする（3→6→12） |
| `LogFolder` | 空でなければ、要求・回答の JSON を 1 回ずつファイルに書く（API キーは書かない。添付の base64 は長さだけ書く）。調べ物用 |

**[CaiGemini] など（AI ごと）**

| キー | 意味 |
|---|---|
| `Url` | 送り先。`%Model%` はそのセクションの `Model`（プロパティ `Model` に値があればその値）に置き換わる。例：`Model=gemini-3.8-flash` なら `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent`。`%Model%` を使わずに URL をそのまま書いてもよい（そのときは `Model` を変えても URL は変わらない） |
| `Model` | モデル名 |
| `ApiKeyEnv` | API キーを入れた環境変数の名前 |
| `MaxTokensParam` | （任意）回答の長さの上限（プロパティ `MaxTokens`）を送るときの項目名。Chat Completions の形の AI（aiChatGPT・aiMeta）で使う。既定 `max_completion_tokens`（OpenAI の新しいモデルが求める名前）。`max_tokens` しか知らない互換サーバー（Ollama の `/v1` など）では `max_tokens` にする |
| `WorkspaceId` | （任意。aiClaude）API キーが特定のワークスペースに紐づいていないとき、ヘッダー `anthropic-workspace-id` に送るワークスペースの ID（例：`wrkspc_…`）。空なら送らない |

- **API キー**：ini には書かない（キーを書くキーは持たない）。`ApiKeyEnv` で名前を指定した環境変数に、ユーザーがキーを入れておく。部品は送るたびに `GetEnvironmentVariable` で読む。
- **エラーにするとき**（`ceSettings`。送信はしない）：
  - `Url`・`Model` が空
  - `ApiKeyEnv` が空（aiOllama は除く。aiOllama はキーを使わないので、空でよい）
  - `ApiKeyEnv` の環境変数が無い、または値が空。`LastError` は「環境変数 GEMINI_API_KEY がありません（WebView2.ini [CaiGemini] ApiKeyEnv）」
- 環境変数は、EXE が起動したときの値を読む。設定したあとは、Lazarus・EXE を起動し直す。
- プロパティ（4.2）の `Model`・`TimeoutSeconds`・`RetryCount` に指定した値は、ini より優先する（空・0・-1 のときだけ ini を使う）。

## 4. TCaiClient

`TCaiClient = class(TComponent)`。ユニット `uCaiClient`。

### 4.1 型

```pascal
type
  TCaiAIType = (aiGemini, aiClaude, aiChatGPT, aiMeta, aiOllama);

  TCaiErrorKind = (
    ceNone,
    ceSettings,     // ini に Url・Model が無い、API キーの環境変数が無い など
    ceInput,        // AText と Prompt の両方が空、Prompt のファイルが無い
    ceFile,         // 添付が無い・読めない・形式が送れない・大きすぎる
    ceConnect,      // 接続できない・通信が切れた
    ceTimeout,      // 待ち時間を過ぎた
    ceHttp,         // HTTP 2xx 以外（LastStatusCode に値）
    ceBlocked,      // AI が回答を拒んだ（安全フィルターなど）
    ceParse,        // 回答 JSON が読めない・回答の文字が無い
    ceCanceled,     // Cancel された
    ceBusy,         // 処理中にもう一度 AskAndWait… を呼んだ
    ceNotSupported  // まだ対応していない AI
  );

  TCaiClientMessageEvent = procedure(Sender: TObject; const AMsg: string) of object;
```

- 値の名前 `aiGemini` などが、ほかのユニットの同じ名前とぶつかるときは、`TCaiAIType.aiGemini` のように型名を付けて書く。

### 4.2 プロパティ

| 名前 | 型 | 読み書き | 意味 |
|---|---|---|---|
| `AIType` | `TCaiAIType` | 読み書き（published） | 使う AI。既定 `aiGemini`。`Busy` の間は変えない（`LastError` に「処理中のため AIType は変更できません」） |
| `Prompt` | `TStrings` | 読み書き（published） | プロンプトのファイルのフルパス（1 行 1 つ）。中身（UTF-8）を、空行をはさんでつなぎ、AText の前に付けて送る。空白だけの行は無視する |
| `Files` | `TStrings` | 読み書き（published） | 添付ファイルのフルパス（1 行 1 つ）。空ならテキストだけ。空白だけの行は無視する |
| `Model` | `string` | 読み書き（published） | 空なら ini の `Model` |
| `TimeoutSeconds` | `Integer` | 読み書き（published） | 0 なら ini の値。既定 0 |
| `RetryCount` | `Integer` | 読み書き（published） | -1 なら ini の値。既定 -1 |
| `Temperature` | `Double` | 読み書き（published） | -1 なら送らない（AI の既定）。既定 -1。**aiClaude では、値があっても送らない**（`anthropic-version` 2026-10-21 では、`temperature` を付けるとどのモデルでも 400 になるため） |
| `MaxTokens` | `Integer` | 読み書き（published） | 回答の長さの上限。0 なら送らない（aiClaude は必須のため、0 なら 16000 を送る。現行の Claude は考える分も数えるので、小さいと本文が空になる）。既定 0 |
| `OnMessage` | `TCaiClientMessageEvent` | 読み書き（published） | 途中の知らせ（4.4） |
| `Busy` | `Boolean` | 読みだけ | AskAndWait… の処理中なら True |
| `LastErrorKind` | `TCaiErrorKind` | 読みだけ | 最後のエラーの種類（成功なら `ceNone`） |
| `LastError` | `string` | 読みだけ | 最後のエラーの文（成功なら `''`） |
| `LastStatusCode` | `Integer` | 読みだけ | 最後の HTTP ステータス（通信前の失敗は 0） |
| `LastUsage` | `string` | 読みだけ | 回答 JSON の使用量の部分（そのまま） |
| `LastResponse` | `string` | 読みだけ | 最後の回答 JSON（生のまま。調べ物用） |

### 4.3 メソッド

| 名前 | 意味 |
|---|---|
| `function AskAndWaitText(const AText: string): string;` | Prompt の中身＋AText と Files を送り、回答（Markdown の記号を使わない文章）が来るまで待って返す。失敗は `''` |
| `function AskAndWaitMD(const AText: string): string;` | 同じく、回答を Markdown で返す。失敗は `''` |
| `procedure Cancel;` | 処理中を止める（WinHTTP の要求ハンドルを閉じ、リトライの待ちも抜ける）。AskAndWait… は `''` を返し、`LastErrorKind = ceCanceled` |
| `procedure ReloadSettings;` | ini を読み直す |
| `function TestConnection: Boolean;` | `AskAndWaitText('OK とだけ答えてください。')` を送り、回答が `''` でなければ True（疎通確認用。Prompt・Files は使わない） |

### 4.4 OnMessage で知らせること

| いつ | AMsg の例 |
|---|---|
| 始めたとき | `2026-11-23 10:15:02 [開始] Gemini gemini-3.8-flash` |
| やり直す前 | `2026-11-23 10:15:05 [再送 1/2] HTTP 503（3 秒後）` |
| 成功したとき | `2026-11-23 10:15:09 [完了] 7.2 秒` |
| 失敗したとき | `2026-11-23 10:15:09 [エラー] HTTP 400: API key not valid. ...` |

- メインスレッドで呼ぶ（待ちのループの中から呼ぶので、スレッドから直接は呼ばない）。
- 文言は `uCXLang`。

### 4.5 AskAndWait… の流れ（Text・MD 共通）

1. `Busy` なら `ceBusy`（`''` を返す）。今の処理（通信・待ち）には触らない。ただし `LastErrorKind`・`LastError` には `ceBusy`・「処理中です」が入る。元の処理が終わると、その結果で上書きされる（成功なら `ceNone`・`''` に戻る）。
2. `LastError*`・`LastUsage`・`LastResponse` を空にし、`Busy := True`（終わりは try…finally で必ず False）。
3. 入力を確かめる：AText と Prompt（空白行を除く）の両方が空なら `ceInput`。Prompt のファイルが無ければ `ceInput`。Files のファイルが無ければ `ceFile`。
4. ini を読む（最初の 1 回）。AI のセクションから Url・Model を決め、`ApiKeyEnv` の環境変数から API キーを読む。足りなければ `ceSettings`（3 章）。
5. 本文を作る：Prompt の中身（空行でつなぐ）→ 空行 → AText → テキストの添付（4.7）。
6. 添付のうち PDF・画像を読み、base64 にする（4.7）。読めない・送れない形式・大きすぎるなら `ceFile`。
7. 要求の JSON を AI ごとに組み立てる（5 章）。回答の形の指示（4.6）をシステム指示に入れる。
8. `OnMessage`（[開始]）。通信用スレッドを起こす。
9. スレッドが終わるまで、`Application.ProcessMessages`＋`Sleep(10)` で待つ。待つ間に、スレッドから届いた「再送の知らせ」があれば `OnMessage`（[再送]）。
10. スレッドの結果を `LastStatusCode`・`LastResponse`・`LastUsage` に入れる。成功なら `LastErrorKind := ceNone`・`LastError := ''` に戻し（待つ間の二重呼び出しで入った `ceBusy` を消す）、回答を返して `OnMessage`（[完了]）。失敗なら `LastErrorKind`・`LastError` を入れて `''` を返し `OnMessage`（[エラー]）。
11. ini の `LogFolder` があれば、要求・回答を 1 つのファイルに書く（4.10）。

- 待っている間に部品が破棄されたら（フォームが閉じられた など）、デストラクタで `Cancel` し、スレッドの終わりを待ってから消える。待ちのループは、ローカル変数 `Alive` を見て抜け、部品（`Self`）に触らずに `''` を返す（イベントは呼ばない）。`Alive` はループの前に部品がアドレスを覚え（`FAlive`）、デストラクタが `False` にする。
- 待っている間に、アプリの別のボタンの処理が動くことがある。同じ部品の二重呼び出しは `ceBusy` で断る。ほかのボタンを止めるかどうかはアプリが決める（呼び出し用のフォームを `ShowModal` で出し、その中で AskAndWait… を呼べば、呼んだ側のフォームは操作できなくなる）。

### 4.6 回答の形の指示

システム指示に、次の 1 文を入れる（文言は `uCXLang`。アプリの言語に合わせる）。

- `AskAndWaitText`：「回答は、Markdown の記号（#、*、```、表など）を使わない、普通の文章で書いてください。」
- `AskAndWaitMD`：「回答は、Markdown 形式で書いてください。」

### 4.7 添付ファイル

| 拡張子 | 送り方 |
|---|---|
| `.txt .md .csv .tsv .json .xml .html .log .ini .pas .lpr .js .ts .py .sql` など（テキスト） | 中身を読み（UTF-8。BOM は除く）、`--- ファイル: 名前 ---` で囲んで本文の後ろにつなぐ（全 AI 共通） |
| `.pdf` | AI 側の添付として送る（base64）。Gemini・Claude・ChatGPT |
| `.png .jpg .jpeg .gif .webp` | AI 側の画像として送る（base64）。全 AI（Ollama は画像の読めるモデルだけ） |
| それ以外（`.xlsx .docx` など） | `ceFile`（「この形式は送れません。CSV・PDF にしてください: 名前」） |

- 1 回で送る添付の合計は 20MB まで（Gemini の 1 要求の上限に合わせる）。超えたら `ceFile`。
- Excel の集計に使うときは、アプリが CSV にしてから添付する（部品は Excel を読まない）。

### 4.8 タイムアウトとリトライ

- `WinHttpSetTimeouts` で、名前解決・接続・送信・受信の 4 つすべてに `TimeoutSeconds × 1000`。過ぎたら（`ERROR_WINHTTP_TIMEOUT`）`ceTimeout`。
- やり直すのは：接続の失敗・タイムアウト、HTTP 429、HTTP 500〜599（Gemini の 503 過負荷を含む。**504 を除く**）。
- やり直さないのは：HTTP 429 のうち `error.code` が `insufficient_quota`（残高・利用枠が無い。待っても同じ）、HTTP 429 のうち `error.details.error_code` が `enforced_spend_limit_reached`（Claude の月の利用上限。`retry-after` も付かない）、HTTP 504 と `error.type` が `timeout_error` のもの（Claude は 500 でも返す。ゲートウェイの待ち時間切れ。ゲートウェイが AI の処理を待ち切れなかったもので、重い要求は、同じ要求を送り直しても同じところで切れやすい。待てば直る 503 の混雑とは違う。Meta の公式も、再送せずストリーミングにするよう案内している。この部品はストリーミングを持たないので、やり直さずに、対処を添えて返す。4.9）、HTTP 400・401・402（残高不足・支払い方法の問題）・403・404（設定や要求の誤りで、何度送っても同じ。Gemini の「このモデルは使えません」の 404 を含む）、`ceBlocked`、`ceParse`、`ceCanceled`。
- 待ち：`RetryWaitSeconds`、2 回目以降は倍。HTTP 429 で `Retry-After` ヘッダーがあれば、その秒数（上限 60 秒）。待つ間も `Cancel` で止まる。

### 4.9 エラーの文

`LastError` は「種類の説明＋AI が返したエラー文」。例：`HTTP 400: API key not valid. Please pass a valid API key.`。AI の JSON の `error.message`（Gemini・ChatGPT・Meta・Claude）、`error`（Ollama）を取り出す。読めなければ回答の先頭 500 文字。HTTP 504 と `timeout_error` のときは、最後に対処を添える（「ゲートウェイの待ち時間を過ぎました。入力を短くするか、MaxTokens を小さくするか、別のモデルを試してください」。`uCXLang` の `sAiHintGateway`）。

### 4.10 ログ（LogFolder）

- ファイル名：`CaiClient_yyyymmdd_hhnnss_zzz.log`（1 回の AskAndWait… で 1 つ）。
- 中身：開始時刻・AI・モデル・URL（キーは入らない）・要求 JSON（添付の base64 は `"<base64 123456 bytes>"` に置き換え）・HTTP ステータス・回答 JSON・かかった秒数・エラー。
- 書けなくても、AskAndWait… の結果には影響させない。

## 5. AI ごとの要求と回答

### 5.1 aiGemini（版 1.0 で作る）

- 送り先：`POST {Url}`。ヘッダー `x-goog-api-key: {ApiKey}`、`Content-Type: application/json`（キーを URL に入れない）。
- 要求：

```json
{
  "systemInstruction": { "parts": [ { "text": "回答の形の指示" } ] },
  "contents": [ { "role": "user", "parts": [
      { "text": "Prompt の中身＋AText＋テキストの添付" },
      { "inline_data": { "mime_type": "application/pdf", "data": "base64..." } }
  ] } ],
  "generationConfig": { "temperature": 0.7, "maxOutputTokens": 4096 }
}
```

  `generationConfig` の各値は、指定があるときだけ入れる（どちらも無ければ `generationConfig` ごと入れない）。
- 回答：`candidates[0].content.parts[*].text` をつなげたもの（`"thought": true` の部分は除く）。
- 拒否：`promptFeedback.blockReason` がある、または `candidates` が空、または `finishReason` が `SAFETY`・`RECITATION`・`PROHIBITED_CONTENT` → `ceBlocked`（理由の文字を `LastError` に）。
- 使用量：`usageMetadata`。

### 5.2 aiClaude（5 番目：最後）

- Messages API（`https://api.anthropic.com/v1/messages`）。ヘッダー `x-api-key: {ApiKey}`、`anthropic-version: 2026-10-21`、`content-type: application/json`。キーは Claude Console で作る（`sk-ant-` で始まる。作ったときにしか表示されない）。
- 環境変数の名前は、Claude Code など公式のツールが読む `ANTHROPIC_API_KEY` とは別の名前（例：`CX_ANTHROPIC_API_KEY`）にする（同じ名前にすると、それらのツールの認証・課金の経路が変わる可能性がある）。キーがワークスペースに紐づいていないときは、ini の `WorkspaceId`（3 章）で、ヘッダー `anthropic-workspace-id` を足す。
- 要求：

```json
{
  "model": "claude-haiku-5-5",
  "max_tokens": 16000,
  "system": "回答の形の指示",
  "messages": [ { "role": "user", "content": [
      { "type": "document", "source": { "type": "base64", "media_type": "application/pdf", "data": "base64..." } },
      { "type": "image", "source": { "type": "base64", "media_type": "image/png", "data": "base64..." } },
      { "type": "text", "text": "Prompt の中身＋AText＋テキストの添付" }
  ] } ]
}
```

- `max_tokens` は必須。`MaxTokens` が 0 のときは 16000 を送る（現行の Claude は、既定で考えてから答え、考える分も `max_tokens` に数えられる。公式の目安は、非ストリーミングで約 16000）。
- **`Temperature` は送らない。** `anthropic-version` 2026-10-21 では、`temperature`・`top_p`・`top_k` を付けると、どのモデルでも HTTP 400 になる。
- 添付は、本文の `text` の前に置く（公式の勧め）。PDF は `document`、画像は `image`（PNG・JPEG・GIF・WebP）。PDF は 1 要求で 600 ページまで（コンテキストが 1M トークン未満のモデルは 100 ページ）。
- `thinking` は送らない（モデルの既定のまま）。
- 回答：`content[]` のうち `type="text"` の `text` をつなげる（`thinking` の部分は含めない）。使用量 `usage`（そのまま `LastUsage`）。
- 拒否：HTTP 200 で `stop_reason="refusal"` → `ceBlocked`（`stop_details` の `category`・`explanation` を `LastError` に添える）。本文が空（考える途中で `max_tokens` に達した など）→ `ceParse`（`stop_reason` を `LastError` に入れる）。
- エラーは `{"type":"error","error":{"type","message"},"request_id"}`。400 `invalid_request_error`（自分で決めた利用上限に達したときも 400）、401 `authentication_error`、402 `billing_error`（やり直さない）、403、404 `not_found_error`（モデルが無い・使えない）、413、429 `rate_limit_error`（`retry-after` があれば、その秒数だけ待ってやり直す。月の利用上限は、`error.details.error_code` が `enforced_spend_limit_reached` で、`retry-after` も付かず、やり直さない）、500 `api_error`（やり直す）、529 `overloaded_error`（やり直す）、504 と `timeout_error`（やり直さず、対処を添える。4.8・4.9）。

### 5.3 aiChatGPT（3 番目）

- 同じ形式の要求は、ini の `Url` を Ollama の `http://localhost:11434/v1/chat/completions` にしても送れる（キーの値は何でもよい。課金なしで、要求と回答の形の確認に使う）。
- `POST {Url}`（Chat Completions）。ヘッダー `Authorization: Bearer {ApiKey}`。
- 要求：`messages` に `system` と `user`。user の `content` は `[{"type":"text"},{"type":"image_url","image_url":{"url":"data:image/png;base64,..."}},{"type":"file","file":{"filename","file_data":"data:application/pdf;base64,..."}}]`。
- 回答：`choices[0].message.content`（文字列。`text` の部分の配列で返す互換サーバーもあるので、その場合はつなげる）。使用量 `usage`（そのまま `LastUsage`）。
- 拒否：`message.refusal` が空でない、または `finish_reason` が `content_filter` → `ceBlocked`（理由の文字を `LastError` に）。本文が空なら `ceParse`（`finish_reason` を `LastError` に）。
- 要求の補足：`model` は使うモデル名（`Url` には入れない）。`Temperature`（-1 でなければ `temperature`）と `MaxTokens`（0 より大きければ、`MaxTokensParam` の名前。3 章）は、あるときだけ入れる。PDF の `file` の `filename` は、添付のファイル名。画像は PNG・JPEG・GIF・WebP。
- Ollama の `/v1/chat/completions` に向けたとき、画像は送れる。PDF の `file` は HTTP 400（`invalid message format`）で、`ceHttp` になる（本物の OpenAI は受ける）。`max_completion_tokens` は無視されるので、`MaxTokensParam=max_tokens` にする。

### 5.4 aiMeta（4 番目）

- Meta Model API（`https://api.meta.ai/v1/chat/completions`。OpenAI 互換の Chat Completions）。ヘッダー `Authorization: Bearer {ApiKey}`。キーは `LLM_` で始まり、環境変数は `MODEL_API_KEY`。
- 要求・回答の読み取り・拒否・使用量・`MaxTokensParam`・添付（画像・PDF）は 5.3（aiChatGPT）と同じで、同じ処理を使う。違うのは `Url`・`Model`・`ApiKeyEnv` だけ。上限の項目名は、既定の `max_completion_tokens` でよい（`max_tokens` も古い名前として受けるが、使わない）。
- `Model`：既定は `muse-spark-1.3`（送った内容を Meta のモデルの学習に使わない Standard）。`-contributor` の付いたモデル（例：`muse-spark-1.3-contributor`）は、安い代わりに、送った内容を学習に使うことを許可するものなので、既定にしない。
- 思考するモデルで、考える分も `max_completion_tokens` と料金に数えられる。`MaxTokens` を小さくすると本文が空になり、`ceParse`（`finish_reason=length`）になる。
- エラーは `{"error":{"message","type","param","code"}}`。429 `rate_limit_exceeded`（`Retry-After` あり。やり直す）、402 `billing_error`（残高不足・支払い方法の問題。やり直さない）、401 `invalid_api_key`、404 `model_not_found`、503 `service_overloaded`（`Retry-After: 60`。やり直す）。
- 504 `gateway_timeout`：Meta の案内は、同じ要求を再送せず、ストリーミングにする。この部品はストリーミングを持たないので、504 はやり直さず、対処を添えたエラー（`ceHttp`）にする（4.8・4.9）。

### 5.5 aiOllama（2 番目）

- `POST {Url}`（`/api/chat`）。キー無し。`"stream": false` を必ず付ける。
- 要求：`{"model","stream":false,"messages":[{"role":"system","content"},{"role":"user","content","images":["base64..."]}],"options":{"temperature","num_predict"}}`。`model` は使うモデル名（`Url` には入れない）。`options` は、`Temperature`（-1 でなければ `temperature`）・`MaxTokens`（0 より大きければ `num_predict`）があるときだけ入れる。
- ヘッダーは `Content-Type` だけ。API キーは使わない（`ApiKeyEnv` は空でよい）。
- 添付：テキストは本文につなぐ（4.7）。画像は user の `images` に base64 で入れる（画像の読めるモデルだけ。読めないモデルは Ollama がエラーを返すので、そのまま `ceHttp`）。PDF は送れない（`ceFile`。`LastError` は「この AI には、この形式は送れません（テキスト・画像だけ）: 名前」）。
- 回答：`message.content`。`<think>…</think>`（qwen3 など、考えた過程を本文に入れるモデル）は回答から除く。開きの無い `</think>` だけのときは、その前までを除く。閉じの無い `<think>` は、そこから後ろを除く。除いたあとが空なら `ceParse`（`done_reason` を `LastError` に入れる）。
- `message.thinking`（考えた過程を別の項目で返す版の Ollama。qwen3 で確認）は使わない。本文に入らないので、回答には出ない。
- 使用量：`prompt_eval_count`・`eval_count`・`total_duration`・`load_duration` のうち、回答にあるものを JSON にして `LastUsage` に入れる（時間はナノ秒）。
- HTTP 2xx 以外：`{"error":"…"}` の文を `LastError` に入れる（例：モデルが無いと HTTP 404 `model 'x' not found`。やり直さない）。
- 確かめるモデル：gemma3:4b、qwen2.5:3b、qwen3:4b、llama3.2:3b、phi4-mini。
- 接続できない（Ollama が起動していない）ときの `LastError`：「Ollama に接続できません。ollama serve が動いているか確かめてください（WinHTTP 番号）」（`ceConnect`。やり直したあとに返す）。
- 最初の 1 回は、Ollama がモデルをメモリに読み込むので、時間がかかる（gemma3:4b で約 1 分の例がある）。`TimeoutSeconds` は、その分を見込む（既定 120 秒）。

## 6. スレッド

- `TCaiHttpThread = class(TThread)`（実装部だけ）。AskAndWait… の中で作り、終わるのを待って `Free` する（`FreeOnTerminate := False`）。
- スレッドが持つのは、組み立て済みの URL・ヘッダー・要求 JSON の文字列と、タイムアウト・リトライの値だけ（部品のプロパティを触らない）。
- スレッドの中で、送信 → 回答を読む → 回答 JSON から回答・エラーを取り出す → リトライ、まで済ませる。
- 再送の知らせは、スレッドが `TCriticalSection` で守った文字列の一覧に足し、メインスレッドの待ちのループが取り出して `OnMessage` に渡す（`Synchronize`・`Queue` は使わない。待ちのループが `ProcessMessages` で回っているので、それで足りる）。
- `Cancel` は、スレッドが持つ WinHTTP の要求ハンドルを `WinHttpCloseHandle` で閉じる（待っている WinHTTP の関数が失敗して戻る）。リトライの待ち（100ms ごとに止める合図を見る）も抜ける。

## 7. 使い方の例（取説に載せるもの）

```pascal
// 質問して、回答を TCMonacoEditor に入れる
procedure TForm1.btnAskClick(Sender: TObject);
var
  S: string;
begin
  CaiClient1.Files.Clear;
  S := CaiClient1.AskAndWaitMD(MonacoEditor1.Text);
  if S <> '' then
    MonacoEditor2.Text := S
  else
    ShowMessage(CaiClient1.LastError);
end;
```

- メール文の作成：`AskAndWaitText('次の要件でお詫びメールの本文を書いて：…')`。
- 添付の要約・集計：`Files` に PDF・CSV を入れ、`AskAndWaitText('要約して')`・`AskAndWaitMD('月別に合計して表にして')`。
- 決まった指示を使い回す：`Prompt` に指示を書いたファイル（例：`mail_rule.txt`）を入れておき、AText には毎回の中身だけを渡す。
- 止めるボタン：`CaiClient1.Cancel`。
- 進み具合の表示：`OnMessage` で `StatusBar1.SimpleText := AMsg`。

## 8. テスト（別文書 TCaiClient_TestSpec.md に書く項目）

- ini 無し・Url 無し・Model 無し・ApiKeyEnv 無し → `ceSettings`
- ApiKeyEnv の環境変数が無い・空 → `ceSettings`（送信しない）
- AText・Prompt の両方が空、Prompt のファイルが無い → `ceInput`
- URL 誤り → `ceConnect`／`ceHttp`（404）
- キー誤り → `ceHttp`（400/401）、リトライしない
- 使えないモデル（gemini-2.5-flash）→ `ceHttp`（404）、リトライしない
- 成功したあとの `LastError` が空（待つ間に二重呼び出しがあったとき）
- テキストだけ・PDF・画像・CSV の添付、`AskAndWaitText`／`AskAndWaitMD`
- Prompt のファイル 1 つ・2 つ
- 503 のときに [再送] が OnMessage に出て、やり直す
- aiOllama：疎通・テキスト・Markdown・Prompt のファイル＋CSV の添付・画像の添付・PDF（`ceFile`）・無いモデル（404）・Ollama が動いていない（`ceConnect`）・Cancel・`MaxTokens`・`LastUsage`
- aiChatGPT：Ollama の `/v1` に向けた実通信（疎通・テキスト・Markdown・Prompt＋CSV・画像・PDF が 400・無いモデル 404・環境変数なし・`MaxTokensParam=max_tokens`・Cancel）と、ダミーのサーバーでの返事（要求の形〔Authorization・`max_completion_tokens`・system・`file` の部分〕・`refusal`・`content_filter`・配列の `content`・429 `insufficient_quota` はやり直さない・429 回数制限はやり直す・401 はやり直さない・本文が空）。本物の OpenAI での確認は、課金後
- aiChatGPT・aiMeta（ダミーのサーバー）：504 はやり直さず、対処の文が `LastError` の最後に付く。503 はやり直して成功する
- aiClaude：Ollama の `/v1/messages` に向けた実通信（疎通・テキスト・Markdown・Prompt＋CSV・画像・PDF が `document` で送れる・無いモデル 404・環境変数なし・`MaxTokens`・Cancel）と、ダミーのサーバーでの返事（要求の形〔`x-api-key`・`anthropic-version`・`anthropic-workspace-id`・`max_tokens` の既定 16000・`Temperature` を送らない・添付が本文の前〕、思考の部分を含めない、`refusal`、本文が空、529 はやり直す、429 の月の利用上限はやり直さない、429 は `retry-after` の秒数だけ待つ、`timeout_error`（500）と 504 はやり直さず対処を添える、402・401 はやり直さない）。本物の Claude での確認は、API キーと課金の準備ができてから
- aiMeta：aiChatGPT と同じ試験（Ollama の `/v1` とダミーのサーバー）。加えて、402 はやり直さない、429 の `Retry-After` の秒数だけ待つ（aiChatGPT でも確認）。本物の Meta での確認は、アカウントと支払い方法ができてから
- aiChatGPT・aiMeta の要求・回答の形は、`Url` を Ollama の `/v1/chat/completions` に向けて、課金なしで確かめる（本物のサービスでの確認は別）
- タイムアウト（`TimeoutSeconds=1`）、Cancel、処理中にもう一度呼ぶ（`ceBusy`）、処理中にフォームを閉じる
- 待っている間に画面が動く（ウィンドウの移動・ボタンの押下）
