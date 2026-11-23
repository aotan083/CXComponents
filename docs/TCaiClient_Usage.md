# TCaiClient 取扱説明書

作者: aotan083
日付: 2026-11-23
版: 1.4

---

## 1. 概要とクラス

アプリから AI の API を呼ぶための部品です（画面には出ない部品）。文と添付ファイルを送り、回答の文字列を受け取ります。

- 呼び方は「完了復帰」。`AskAndWaitText`・`AskAndWaitMD` は回答が来るまで戻らず、回答の文字列を返す。失敗したら `''` を返し、理由は `LastError` に入る。
- 待っている間も画面は固まらない（部品の中でメッセージを処理しながら待つ。アプリは `Application.ProcessMessages` を書かなくてよい）。
- 回答の形は、`AskAndWaitText`（Markdown の記号を使わない文章）と `AskAndWaitMD`（Markdown）の 2 つ。
- 受け持つのは疎通まで。回答の品質・費用の管理は受け持たない。
- 混雑（HTTP 503）・回数制限（HTTP 429）・通信の失敗は、自動でやり直す。

| 項目 | 内容 |
|---|---|
| Lazarus | 5.0 RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |
| 実行に必要なもの | WebView2.ini（3 章）、API キーを入れた環境変数。通信は Windows の WinHTTP を使うので、DLL は要らない |
| 使える AI | Gemini（`aiGemini`）、Ollama（`aiOllama`。自分の PC で動かす LLM）、ChatGPT（`aiChatGPT`。3.4 の注意あり）、Meta（`aiMeta`。3.5 の注意あり）、Claude（`aiClaude`。3.6 の注意あり） |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCaiClient` | `uCaiClient` | cx | `TComponent` | AI の API を呼ぶ部品 |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCaiAIType` | `uCaiClient` | 使う AI。`aiGemini`・`aiClaude`・`aiChatGPT`・`aiMeta`・`aiOllama` |
| `TCaiErrorKind` | `uCaiClient` | エラーの種類（6 章） |
| `TCaiClientMessageEvent` | `uCaiClient` | `OnMessage` の型。`procedure(Sender: TObject; const AMsg: string) of object` |

- フォームに置くと、uses に `uCaiClient` が自動で入り、プロジェクトの必要パッケージに cx が自動で追加される。
- 値の名前（`aiGemini` など）が、ほかのユニットの同じ名前とぶつかるときは、`TCaiAIType.aiGemini` のように型名を付けて書く。
- プログラム名（`.lpr` の `program 名前;`）を `tcAiClient` などにすると、大文字・小文字を区別しないため `TCaiClient` とぶつかってコンパイルできない。別の名前にする。

## 2. 置いて動かすまで

1. パレット [CX] から TCaiClient をフォームに置く。
2. EXE と同じフォルダーの `WebView2.ini` に、3 章のセクションを書く。
3. API キーを環境変数に入れる（3.2）。
4. ボタンなどから `AskAndWaitText`・`AskAndWaitMD` を呼ぶ（7 章）。

## 3. 設定

### 3.1 WebView2.ini

EXE と同じフォルダーの `WebView2.ini` に書きます。読むのは最初に送るときの 1 回だけです（読み直すときは `ReloadSettings`）。

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
```

**[CaiClient]（全 AI 共通）**

| キー | 意味 |
|---|---|
| `TimeoutSeconds` | 接続・送信・受信の待ち時間（秒）。既定 120 |
| `RetryCount` | 失敗したとき、やり直す回数。既定 2（最大 3 回送る） |
| `RetryWaitSeconds` | やり直す前に待つ秒数。回数ごとに倍になる（3→6→12） |
| `LogFolder` | 空でなければ、1 回ごとに要求・回答をファイル（`CaiClient_日時.log`）に書く。相対パスは EXE 基準。API キーは書かない。添付の中身は長さだけ書く |

**[CaiGemini]（AI ごと）**

| キー | 意味 |
|---|---|
| `Url` | 送り先。`%Model%` は使うモデル名に置き換わる。例：`Model=gemini-3.8-flash` なら `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent` |
| `Model` | モデル名 |
| `ApiKeyEnv` | API キーを入れた環境変数の名前 |
| `MaxTokensParam` | （任意。ChatGPT など）`MaxTokens` を送るときの項目名。既定 `max_completion_tokens`。`max_tokens` しか知らない互換サーバー（Ollama の `/v1` など）では `max_tokens` にする |
| `WorkspaceId` | （任意。Claude）API キーが特定のワークスペースに紐づいていないときに、ヘッダー `anthropic-workspace-id` として送るワークスペースの ID（`wrkspc_…`）。空なら送らない |

- 次のときは送らずに `ceSettings` のエラーになる：`Url`・`Model`・`ApiKeyEnv` が空、`ApiKeyEnv` の環境変数が無い（値が空）、`WebView2.ini` が無い。
- 使えなくなったモデル（例：`gemini-2.5-flash`）を指定すると、`ceHttp`（HTTP 404）になる。`Model` を新しいものに直す。

### 3.2 API キー（環境変数）

API キーは ini に書きません（`WebView2.ini` は GitHub に上がるため）。ユーザー環境変数に入れます。PowerShell で：

```powershell
[Environment]::SetEnvironmentVariable('GEMINI_API_KEY', 'ここにキー', 'User')
```

- 入れたあとは、Lazarus と EXE を起動し直す（起動したときの環境変数を読むため）。
- 入ったかどうかは、新しい PowerShell で次を実行して確かめる（キーそのものは出さない）。

```powershell
if ($env:GEMINI_API_KEY) { "見えている（長さ $($env:GEMINI_API_KEY.Length)）" } else { "見えていない" }
```

### 3.3 Ollama（自分の PC で動かす LLM）を使うとき

API キーも課金も要りません。先に Ollama を入れ、モデルを取っておきます。

1. Ollama をインストールする（`https://ollama.com/download`）。入れると自動で動き、`localhost:11434` で待ち受ける。
2. モデルを取る。例：`ollama pull gemma3:4b`
3. `WebView2.ini` に、次のセクションを書く。

```ini
[CaiOllama]
Url=http://localhost:11434/api/chat
Model=gemma3:4b
ApiKeyEnv=
```

4. `AIType` を `aiOllama` にする。

- `ApiKeyEnv` は空でよい（Ollama は API キーを使わない）。
- **最初の 1 回は、Ollama がモデルをメモリに読み込むので、時間がかかる**（gemma3:4b で約 1 分の例がある。2 回目からは数秒）。PC によっては `TimeoutSeconds` を長くする。
- 画像は、画像の読めるモデル（gemma3 など）だけ。読めないモデルに画像を送ると、Ollama が HTTP 400（`Multimodal data provided, but model does not support multimodal requests.`）を返し、`ceHttp` になる（やり直さない）。PDF は送れない（`ceFile`）。
- qwen3 などが本文に入れる考えた過程（`<think>…</think>`）は、回答から除く。
- Ollama が動いていないと `ceConnect`（「Ollama に接続できません。ollama serve が動いているか確かめてください」）になる。
- 小さなモデルは、計算や細かい読み取りを間違えることがある（部品は疎通まで受け持つ。回答の品質は対象外）。
- 考えた過程を出すモデル（qwen3 など）で `MaxTokens` を小さくすると、考えている途中で上限に達して本文が空になり、`ceParse`（`done_reason=length`）になる。`MaxTokens` を大きくするか、0（指定しない）にする。

**動作を確認したモデル**（Ollama 0.40.17、Windows 11。2026-11-23）

| モデル | 大きさ | 画像 | 確認した結果 |
|---|---|---|---|
| `gemma3:4b` | 3.4 GB | 読める | 11 項目すべて OK |
| `qwen2.5:3b` | 1.9 GB | 読めない（`ceHttp` 400） | 10 項目すべて OK（画像を除く） |
| `qwen3:4b` | 2.5 GB | 読めない（`ceHttp` 400） | 10 項目すべて OK（画像を除く）。考えた過程は、回答 JSON の `message.thinking` に分かれて返り、本文（`message.content`）には入らない |
| `llama3.2:3b` | 2.0 GB | 読めない（`ceHttp` 400） | 10 項目すべて OK（画像を除く） |
| `phi4-mini` | 2.5 GB | 読めない（`ceHttp` 400） | 10 項目すべて OK（画像を除く） |

- 確認した項目：疎通（`TestConnection`）、`AskAndWaitText`、使用量（`LastUsage`）、`AskAndWaitMD`、Prompt のファイル＋CSV の添付、PDF の断り（`ceFile`）、無いモデル（HTTP 404）、Ollama が動いていない（`ceConnect`）、`Cancel`、`MaxTokens`。画像の添付は `gemma3:4b` だけ（ほかは読めないモデルのため、上の動きを確かめた）。
- 回答の中身（正しさ）は確認の対象外。モデルによって、計算や読み取りを間違えることがある。
- 最初の 1 回は、モデルの読み込みで 5〜40 秒かかった（この PC の例）。

### 3.4 ChatGPT（OpenAI）を使うとき

```ini
[CaiChatGPT]
Url=https://api.openai.com/v1/chat/completions
Model=gpt-4o-mini
ApiKeyEnv=OPENAI_API_KEY
```

- API キーは、OpenAI の API 用のキーを環境変数 `OPENAI_API_KEY` に入れる（3.2 と同じ方法）。API は、ChatGPT の有料プランとは別に、先払いの利用料が要る。
- `AIType` を `aiChatGPT` にする。テキスト・PDF・画像（PNG・JPEG・GIF・WebP）を送れる。
- 残高・利用枠が無いと、HTTP 429（`insufficient_quota`）が返り、`ceHttp` になる（待っても同じなので、やり直さない）。
- **本物の OpenAI との通信は、まだ確認していない。** Ollama の OpenAI 互換の入口（`http://localhost:11434/v1/chat/completions`）と、ダミーのサーバーで、要求・回答の形と、拒否・429・401 などの動きを確認した。本物で確かめるまでは、この点に注意する。
- `Url` を変えると、同じ形（Chat Completions）の互換サーバーにも使える。Ollama の `/v1` に向けるときは、`MaxTokensParam=max_tokens` にする（`max_completion_tokens` は無視されるため）。この向きでは、PDF は送れない（Ollama が HTTP 400 を返す）。

### 3.5 Meta（Meta Model API）を使うとき

```ini
[CaiMeta]
Url=https://api.meta.ai/v1/chat/completions
Model=muse-spark-1.3
ApiKeyEnv=MODEL_API_KEY
```

- API キーは、Meta の Model API のダッシュボードの「API keys」タブで作る（`LLM_` で始まる。作ったときにしか表示されないので、すぐ控える）。環境変数 `MODEL_API_KEY` に入れる（3.2 と同じ方法）。
- `AIType` を `aiMeta` にする。テキスト・PDF・画像（PNG・JPEG・GIF・WebP）を送れる。
- 課金は従量制（最低額・前払いの約束はない）。残高や支払い方法に問題があると、HTTP 402（`billing_error`）が返り、`ceHttp` になる（やり直さない）。無料枠については、公式のページに書かれていない。
- 日本で使えるかどうかは、公式のページに書かれていない（使えない地域の一覧に日本は入っていないが、モデルの提供は国によって異なる）。
- `Model`：`muse-spark-1.3` は、送った内容を Meta のモデルの学習に使わない（Standard）。**`-contributor` の付いたモデル**（例：`muse-spark-1.3-contributor`）は、安い代わりに、送った内容を学習に使うことを許可するものなので、使うときは注意する。`muse-ember-1.0` は、安いモデル。
- 思考するモデルなので、`MaxTokens` を小さくすると、考えている途中で上限に達して本文が空になり、`ceParse`（`finish_reason=length`）になる。`MaxTokens` を大きくするか、0（指定しない）にする。
- **本物の Meta との通信は、まだ確認していない。** Ollama の OpenAI 互換の入口と、ダミーのサーバーで、要求・回答の形と、拒否・402・429・401 などの動きを確認した。ここに書いた Meta の仕様は、公式のドキュメント（`dev.meta.ai`）による。

### 3.6 Claude（Anthropic）を使うとき

```ini
[CaiClaude]
Url=https://api.anthropic.com/v1/messages
Model=claude-haiku-5-5
ApiKeyEnv=CX_ANTHROPIC_API_KEY
```

- API キーは、Claude Console（`platform.claude.com/settings/keys`）で作る。`sk-ant-` で始まり、**作ったときにしか表示されない**ので、すぐ控える。
- **環境変数の名前は、`ANTHROPIC_API_KEY` ではなく、別の名前（上の例では `CX_ANTHROPIC_API_KEY`）にする。** `ANTHROPIC_API_KEY` は Claude Code など Anthropic の公式のツールも読むため、同じ名前にすると、それらのツールの認証・課金の経路が変わる可能性がある。入れ方は 3.2 と同じ。
- キーが特定のワークスペースに紐づいていないときは、ini の `WorkspaceId` に、ワークスペースの ID（`wrkspc_…`）を書く。
- `AIType` を `aiClaude` にする。テキスト・PDF・画像（PNG・JPEG・GIF・WebP）を送れる（PDF は 600 ページまで）。
- `Model`：`claude-haiku-5-5`（安い）、`claude-sonnet-5-5`、`claude-opus-5-5`（最上位）など。モデル名は、日付を付けず、そのまま書く。使えないモデルは、HTTP 404 になる。
- **`Temperature` は、aiClaude では送られない**（Claude の現在の API バージョンでは、`temperature` を付けると、どのモデルでも HTTP 400 になるため）。
- `MaxTokens` が 0 のときは、16000 を送る（Claude は `max_tokens` が必須）。現行の Claude は、既定で考えてから答え、**考える分も `max_tokens` に数えられる**。`MaxTokens` を小さくすると、考えている途中で上限に達して、本文が空になり、`ceParse`（`stop_reason=max_tokens`）になる。
- 安全のしくみが答えを止めたとき（`stop_reason` が `refusal`）は、`ceBlocked` になる（`LastError` に分類と説明が付く）。
- 課金・上限：残高や支払い方法に問題があると HTTP 402（`billing_error`）になる（やり直さない）。月の利用上限に達すると HTTP 429 が返り、`retry-after` が付かず、待っても直らないので、やり直さない（`LastError` に「usage limits」の文が付く）。ふつうの 429（回数制限）は、`retry-after` の秒数だけ待ってやり直す。混雑（HTTP 529）は、やり直す。待ち時間切れ（HTTP 504 と `timeout_error`）は、やり直さず、対処が付く。
- API キーの前払いや無料枠は、公式のページ（クイックスタート・API キー・レート制限）には書かれていない。Console の課金の画面で確かめる。新しい組織は、上限の低い枠から始まり、使うほど上がる。
- 日本は、Anthropic の対応する国・地域の一覧に入っている（2026-11-12 時点）。
- **本物の Claude との通信は、まだ確認していない。** Ollama の Anthropic 互換の入口（`http://localhost:11434/v1/messages`）と、ダミーのサーバーで、要求・回答の形と、拒否・529・429・402・401 などの動きを確認した。PDF は、Ollama の入口が読まずに無視するため、本物でしか確かめられない。ここに書いた Claude の仕様は、公式のドキュメントによる。

## 4. プロパティ

| 名前 | 型 | 読み書き | 意味 |
|---|---|---|---|
| `AIType` | `TCaiAIType` | 読み書き | 使う AI。既定 `aiGemini`。処理中は変えられない |
| `Prompt` | `TStrings` | 読み書き | プロンプトのファイルのフルパス（1 行に 1 つ）。中身（UTF-8）を、AText の前に付けて送る。決まった指示を使い回すときに使う |
| `Files` | `TStrings` | 読み書き | 添付ファイルのフルパス（1 行に 1 つ）。送れる形式は 4.1 |
| `Model` | `string` | 読み書き | 空なら ini の `Model` |
| `TimeoutSeconds` | `Integer` | 読み書き | 待ち時間（秒）。0 なら ini の値。既定 0 |
| `RetryCount` | `Integer` | 読み書き | やり直す回数。-1 なら ini の値。既定 -1 |
| `Temperature` | `Double` | 読み書き | 回答のばらつき（0 に近いほど毎回同じ）。-1 なら送らない（AI の既定）。既定 -1。aiClaude では、値があっても送らない |
| `MaxTokens` | `Integer` | 読み書き | 回答の長さの上限。0 なら送らない（aiClaude は必須なので、0 なら 16000 を送る）。既定 0 |
| `Busy` | `Boolean` | 読みだけ | 処理中なら True |
| `LastErrorKind` | `TCaiErrorKind` | 読みだけ | 最後のエラーの種類（成功なら `ceNone`） |
| `LastError` | `string` | 読みだけ | 最後のエラーの文（成功なら `''`） |
| `LastStatusCode` | `Integer` | 読みだけ | 最後の HTTP ステータス（送る前の失敗は 0） |
| `LastUsage` | `string` | 読みだけ | 回答 JSON の使用量（トークン数など）の部分。そのまま |
| `LastResponse` | `string` | 読みだけ | 最後の回答 JSON（生のまま。調べ物用） |

- `Prompt`・`Files` の空白だけの行は無視する。

### 4.1 添付ファイル（Files）

| 種類 | 拡張子 | 送り方 |
|---|---|---|
| テキスト | `.txt .md .csv .tsv .json .xml .html .log .ini .pas .lpr .js .py .sql` など | 中身（UTF-8）を、`--- ファイル: 名前 ---` で囲んで本文の後ろにつなぐ |
| PDF | `.pdf` | AI に添付として送る |
| 画像 | `.png .jpg .jpeg .gif .webp` | AI に画像として送る |
| それ以外 | `.xlsx .docx` など | 送れない（`ceFile`）。CSV・PDF にしてから添付する |

- 添付の合計は 20MB まで。
- Ollama は、テキストと画像だけ受ける（PDF は `ceFile`）。

## 5. メソッドとイベント

| 名前 | 意味 |
|---|---|
| `function AskAndWaitText(const AText: string): string;` | Prompt の中身＋AText と Files を送り、回答（Markdown の記号を使わない文章）が来るまで待って返す。失敗は `''` |
| `function AskAndWaitMD(const AText: string): string;` | 同じく、回答を Markdown で返す。失敗は `''` |
| `procedure Cancel;` | 処理中を止める。AskAndWait… は `''` を返し、`LastErrorKind = ceCanceled` |
| `procedure ReloadSettings;` | WebView2.ini を読み直す |
| `function TestConnection: Boolean;` | 「OK とだけ答えて」を送り、回答が来れば True（Prompt・Files は使わない）。設定とキーの確かめに使う |

| イベント | いつ |
|---|---|
| `OnMessage` | 途中の様子を知らせる（下の表）。AMsg の先頭に日時が付く |

| AMsg の例 | いつ |
|---|---|
| `2026-11-23 10:15:02 [開始] Gemini gemini-3.8-flash` | 送り始めたとき |
| `2026-11-23 10:15:05 [再送 1/2] HTTP 503（3 秒後）` | やり直す前 |
| `2026-11-23 10:15:09 [完了] 7.2 秒` | 回答が来たとき |
| `2026-11-23 10:15:09 [エラー] HTTP 400: API key not valid. ...` | 失敗したとき |

## 6. エラーの種類（LastErrorKind）

| 値 | いつ | やり直すか |
|---|---|---|
| `ceNone` | 成功 | ― |
| `ceSettings` | ini が無い、Url・Model・ApiKeyEnv が無い、環境変数が無い | しない（送らない） |
| `ceInput` | AText と Prompt の両方が空、Prompt のファイルが無い・読めない | しない（送らない） |
| `ceFile` | 添付が無い・読めない・送れない形式・20MB を超える | しない（送らない） |
| `ceConnect` | 接続できない・通信が切れた | する |
| `ceTimeout` | 待ち時間を過ぎた | する |
| `ceHttp` | HTTP 2xx 以外。番号は `LastStatusCode` | 429 と、504 を除く 500〜599 だけする。400・401・402・403・404・504 はしない。429 でも、残高・利用枠が無い（`insufficient_quota`）ときはしない |
| `ceBlocked` | AI が回答を拒んだ（安全フィルターなど） | しない |
| `ceParse` | 回答が読めない・回答の文字が無い | しない |
| `ceCanceled` | `Cancel` された | しない |
| `ceBusy` | 処理中に、もう一度 AskAndWait… を呼んだ（元の処理はそのまま続く） | ― |
| `ceNotSupported` | 対応していない AI（今は 5 つの AI のすべてに対応しているので、返らない） | ― |

## 7. 使い方の例

### 7.1 質問して、回答をエディターに入れる

```pascal
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

### 7.2 メールの文を作る

```pascal
S := CaiClient1.AskAndWaitText('次の要件で、お詫びメールの本文を書いて：' + LineEnding + Memo1.Text);
```

### 7.3 添付した資料のまとめ・集計

```pascal
CaiClient1.Files.Clear;
CaiClient1.Files.Add('C:\data\report.pdf');
S := CaiClient1.AskAndWaitText('この資料を5行で要約して。');

CaiClient1.Files.Clear;
CaiClient1.Files.Add('C:\data\sales.csv');
S := CaiClient1.AskAndWaitMD('月別・商品別に合計して、表にして。');
```

### 7.4 決まった指示を使い回す（Prompt）

```pascal
// mail_rule.txt に「丁寧な日本語で、300字以内で書く」などの指示を書いておく
CaiClient1.Prompt.Text := ExtractFilePath(ParamStr(0)) + 'mail_rule.txt';
S := CaiClient1.AskAndWaitText(Memo1.Text);   // 毎回の中身だけを渡す
```

### 7.5 別のフォームを ShowModal で出して、その中で呼ぶ

呼んだ側のフォーム（Form1）は操作できなくなりますが、固まらずに描画されます。待っている間も、Form2 の「止める」ボタンは押せます。

```pascal
// Form1
procedure TForm1.btnAiClick(Sender: TObject);
begin
  Form2.QuestionText := MonacoEditor1.Text;
  if Form2.ShowModal = mrOK then
    MonacoEditor1.Text := Form2.AnswerText;
end;

// Form2：表示されてから問い合わせを始める
procedure TForm2.FormShow(Sender: TObject);
begin
  Application.QueueAsyncCall(@DoAsk, 0);   // 画面を描いてから始める
end;

procedure TForm2.DoAsk(Data: PtrInt);
begin
  AnswerText := CaiClient1.AskAndWaitMD(QuestionText);
  if AnswerText <> '' then
    ModalResult := mrOK
  else
  begin
    ShowMessage(CaiClient1.LastError);
    ModalResult := mrCancel;
  end;
end;

// 止めるボタン
procedure TForm2.btnStopClick(Sender: TObject);
begin
  CaiClient1.Cancel;
end;

// 待っている間に × で閉じられたら、止める
procedure TForm2.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if CaiClient1.Busy then
    CaiClient1.Cancel;
end;

// 進み具合を出す
procedure TForm2.CaiClient1Message(Sender: TObject; const AMsg: string);
begin
  StatusBar1.SimpleText := AMsg;
end;
```

### 7.6 設定とキーを確かめる

```pascal
if CaiClient1.TestConnection then
  ShowMessage('つながりました')
else
  ShowMessage(CaiClient1.LastError);
```

## 8. 注意

- 待っている間に、アプリのほかのボタンの処理が動くことがある。同じ部品の二重呼び出しは `ceBusy` で断り、`''` を返す。元の処理はそのまま続き、終わると `LastError` などは元の処理の結果になる。ほかのボタンを止めたいときは、7.5 のように ShowModal のフォームの中で呼ぶ。
- 待っている間にフォームが閉じられて部品が壊れたときは、通信を止めてから消える。AskAndWait… は `''` を返す。
- 混雑しているモデル（HTTP 503 が続く）は、やり直しを使い切ると `ceHttp` になる。時間をおくか、`Model` を別のもの（例：`gemini-flash-lite-latest`）にする。
- HTTP 504（ゲートウェイの待ち時間切れ）は、重い要求を同じまま送り直しても、同じところで切れやすいので、やり直さない。`LastError` の最後に、「入力を短くする、`MaxTokens` を小さくする、別のモデルを試す」という対処が付く（混雑の 503 は、待てば直るので、やり直す）。
- 履歴（前のやりとり）は持たない。続けて聞くときは、前の回答を AText に入れて送る。
