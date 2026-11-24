# TCaiClient User Manual

Author: aotan083
Date: 2026-11-23
Version: 1.4

---

**Operating environment**: Lazarus 5.0 or later (FPC 3.2.2). Lazarus 4.8 and earlier are not supported.

## 1. Overview and Classes

A component that lets an application call an AI API (a non-visual component). It sends text and attached files and receives the answer as a string.

- It is called in "return on completion" style. `AskAndWaitText` and `AskAndWaitMD` do not return until the answer arrives, and return the answer as a string. On failure they return `''` and the reason goes into `LastError`.
- The screen does not freeze while waiting (the component processes messages while it waits; the application does not need to write `Application.ProcessMessages`).
- The form of the answer is chosen by the method: `AskAndWaitText` (plain prose without Markdown syntax) or `AskAndWaitMD` (Markdown).
- It covers only the connection. It does not manage answer quality or cost.
- Congestion (HTTP 503), rate limiting (HTTP 429), and communication failures are retried automatically.

| Item | Details |
|---|---|
| Lazarus | 5.0 RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |
| Palette | CX |
| Required at runtime | WebView2.ini (Chapter 3) and an environment variable that holds the API key. Communication uses Windows WinHTTP, so no DLL is needed |
| Usable AIs | Gemini (`aiGemini`), Ollama (`aiOllama`; an LLM that runs on your own PC), ChatGPT (`aiChatGPT`; see the note in 3.4), Meta (`aiMeta`; see the note in 3.5), and Claude (`aiClaude`; see the note in 3.6) |

### 1.1 Classes and Units

| Class | Unit | Package | Base class | Contents |
|---|---|---|---|---|
| `TCaiClient` | `uCaiClient` | cx | `TComponent` | The component that calls an AI API |

| Type | Unit | Contents |
|---|---|---|
| `TCaiAIType` | `uCaiClient` | The AI to use: `aiGemini`, `aiClaude`, `aiChatGPT`, `aiMeta`, `aiOllama` |
| `TCaiErrorKind` | `uCaiClient` | Kind of error (Chapter 6) |
| `TCaiClientMessageEvent` | `uCaiClient` | Type of `OnMessage`. `procedure(Sender: TObject; const AMsg: string) of object` |

- When you place it on a form, `uCaiClient` is added to uses automatically, and cx is added automatically to the project's required packages.
- When you create it in code, write it in uses yourself.
- When a value name (such as `aiGemini`) clashes with the same name in another unit, write it with the type name, as in `TCaiAIType.aiGemini`.
- If the program name (`program Name;` in the `.lpr`) is something like `tcAiClient`, it clashes with `TCaiClient` because Pascal does not distinguish upper and lower case, and the program cannot be compiled. Use a different name.

## 2. From Placing It to Running It

1. Place TCaiClient on a form from the [CX] palette.
2. Write the sections of Chapter 3 in `WebView2.ini` in the same folder as the EXE.
3. Put the API key in an environment variable (3.2).
4. Call `AskAndWaitText` or `AskAndWaitMD` from a button or similar (Chapter 7).

## 3. Settings

### 3.1 WebView2.ini

Write it in `WebView2.ini` in the same folder as the EXE. It is read only once, when the first request is sent (use `ReloadSettings` to read it again).

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

**[CaiClient] (common to all AIs)**

| Key | Meaning |
|---|---|
| `TimeoutSeconds` | Wait time for connecting, sending, and receiving (seconds). Default 120 |
| `RetryCount` | Number of times to retry after a failure. Default 2 (sends up to 3 times) |
| `RetryWaitSeconds` | Seconds to wait before retrying. It doubles each time (3 → 6 → 12) |
| `LogFolder` | If not empty, the request and answer are written to a file (`CaiClient_datetime.log`) for each call. A relative path is counted from the EXE. The API key is not written. The contents of attachments are written only as a length |

**[CaiGemini] (for each AI)**

| Key | Meaning |
|---|---|
| `Url` | Destination. `%Model%` is replaced with the model name in use. Example: with `Model=gemini-3.8-flash`, it becomes `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent` |
| `Model` | Model name |
| `ApiKeyEnv` | Name of the environment variable that holds the API key |
| `MaxTokensParam` | (Optional; for ChatGPT and similar) The item name used to send `MaxTokens`. Default `max_completion_tokens`. For compatible servers that know only `max_tokens` (such as Ollama's `/v1`), set it to `max_tokens` |
| `WorkspaceId` | (Optional; Claude) When the API key is not tied to a specific workspace, the ID of the workspace (`wrkspc_…`) sent as the `anthropic-workspace-id` header. If empty, it is not sent |

- In the following cases nothing is sent and the error is `ceSettings`: `Url`, `Model`, or `ApiKeyEnv` is empty; the environment variable of `ApiKeyEnv` does not exist (or its value is empty); `WebView2.ini` does not exist.
- If you specify a model that is no longer available (for example `gemini-2.5-flash`), the result is `ceHttp` (HTTP 404). Change `Model` to a newer one.

### 3.2 API Key (Environment Variable)

The API key is not written in the ini (because `WebView2.ini` is uploaded to GitHub). Put it in a user environment variable. In PowerShell:

```powershell
[Environment]::SetEnvironmentVariable('GEMINI_API_KEY', 'your-key-here', 'User')
```

- After setting it, restart Lazarus and the EXE (the values from when they started are what they read).
- To check that it was set, run the following in a new PowerShell (it does not show the key itself).

```powershell
if ($env:GEMINI_API_KEY) { "visible (length $($env:GEMINI_API_KEY.Length))" } else { "not visible" }
```

### 3.3 When Using Ollama (an LLM That Runs on Your Own PC)

No API key and no payment are needed. Install Ollama and fetch a model first.

1. Install Ollama (`https://ollama.com/download`). After installation it runs automatically and waits on `localhost:11434`.
2. Fetch a model. Example: `ollama pull gemma3:4b`
3. Write the following section in `WebView2.ini`.

```ini
[CaiOllama]
Url=http://localhost:11434/api/chat
Model=gemma3:4b
ApiKeyEnv=
```

4. Set `AIType` to `aiOllama`.

- `ApiKeyEnv` may be empty (Ollama does not use an API key).
- **The first request takes time because Ollama loads the model into memory** (there is an example of about one minute with gemma3:4b; from the second request on, a few seconds). On some PCs, make `TimeoutSeconds` longer.
- Images work only with models that can read images (such as gemma3). If an image is sent to a model that cannot read them, Ollama returns HTTP 400 (`Multimodal data provided, but model does not support multimodal requests.`) and the result is `ceHttp` (not retried). PDF cannot be sent (`ceFile`).
- The reasoning (`<think>…</think>`) that models such as qwen3 put into the body is removed from the answer.
- If Ollama is not running, the result is `ceConnect` ("Cannot connect to Ollama. Check that ollama serve is running").
- Small models can make mistakes in calculation or fine reading (the component covers only the connection; answer quality is out of scope).
- With a model that shows its reasoning (such as qwen3), a small `MaxTokens` reaches the limit in the middle of reasoning, the body becomes empty, and the result is `ceParse` (`done_reason=length`). Make `MaxTokens` larger, or set it to 0 (not specified).

**Models whose operation was checked** (Ollama 0.40.17, Windows 11; 2026-11-23)

| Model | Size | Images | Result |
|---|---|---|---|
| `gemma3:4b` | 3.4 GB | Can read | All 11 items OK |
| `qwen2.5:3b` | 1.9 GB | Cannot (`ceHttp` 400) | All 10 items OK (excluding images) |
| `qwen3:4b` | 2.5 GB | Cannot (`ceHttp` 400) | All 10 items OK (excluding images). The reasoning is returned separately in `message.thinking` of the answer JSON and does not enter the body (`message.content`) |
| `llama3.2:3b` | 2.0 GB | Cannot (`ceHttp` 400) | All 10 items OK (excluding images) |
| `phi4-mini` | 2.5 GB | Cannot (`ceHttp` 400) | All 10 items OK (excluding images) |

- Items checked: connection check (`TestConnection`), `AskAndWaitText`, usage (`LastUsage`), `AskAndWaitMD`, a Prompt file + CSV attachment, refusing PDF (`ceFile`), a missing model (HTTP 404), Ollama not running (`ceConnect`), `Cancel`, and `MaxTokens`. The image attachment was checked only with `gemma3:4b` (the others cannot read images, so the behavior above was confirmed).
- The content of the answers (their correctness) is out of scope. Depending on the model, calculations or readings can be wrong.
- The first request took 5 to 40 seconds for loading the model (an example on this PC).

### 3.4 When Using ChatGPT (OpenAI)

```ini
[CaiChatGPT]
Url=https://api.openai.com/v1/chat/completions
Model=gpt-4o-mini
ApiKeyEnv=OPENAI_API_KEY
```

- Put an API key for the OpenAI API in the environment variable `OPENAI_API_KEY` (the same way as 3.2). The API requires prepaid usage fees, separate from a ChatGPT paid plan.
- Set `AIType` to `aiChatGPT`. Text, PDF, and images (PNG, JPEG, GIF, WebP) can be sent.
- If there is no balance or quota, HTTP 429 (`insufficient_quota`) is returned and the result is `ceHttp` (it is not retried, because waiting does not help).
- **Communication with the real OpenAI has not been checked yet.** The shape of the request and answer, and the behavior for refusals, 429, 401, and so on, were checked with Ollama's OpenAI-compatible entrance (`http://localhost:11434/v1/chat/completions`) and with a dummy server. Keep this in mind until it has been checked on the real service.
- Changing `Url` lets it also be used with compatible servers of the same form (Chat Completions). When pointing at Ollama's `/v1`, set `MaxTokensParam=max_tokens` (because `max_completion_tokens` is ignored). In that direction PDF cannot be sent (Ollama returns HTTP 400).

### 3.5 When Using Meta (Meta Model API)

```ini
[CaiMeta]
Url=https://api.meta.ai/v1/chat/completions
Model=muse-spark-1.3
ApiKeyEnv=MODEL_API_KEY
```

- Create the API key on the "API keys" tab of the Meta Model API dashboard (it starts with `LLM_`; it is shown only when created, so copy it right away). Put it in the environment variable `MODEL_API_KEY` (the same way as 3.2).
- Set `AIType` to `aiMeta`. Text, PDF, and images (PNG, JPEG, GIF, WebP) can be sent.
- Billing is pay-as-you-go (no minimum and no upfront commitment). If there is a problem with the balance or the payment method, HTTP 402 (`billing_error`) is returned and the result is `ceHttp` (not retried). Whether there is a free tier is not written on the official pages.
- Whether it can be used in Japan is not written on the official pages (Japan is not in the list of restricted territories, but the availability of models varies by country).
- `Model`: `muse-spark-1.3` does not use what you send to train Meta's models (Standard). **Models with `-contributor`** (for example `muse-spark-1.3-contributor`) are cheaper in exchange for permitting what you send to be used for training, so be careful when using them. `muse-ember-1.0` is an inexpensive model.
- These are reasoning models, so with a small `MaxTokens` the limit is reached in the middle of reasoning, the body becomes empty, and the result is `ceParse` (`finish_reason=length`). Make `MaxTokens` larger, or set it to 0 (not specified).
- **Communication with the real Meta has not been checked yet.** The shape of the request and answer, and the behavior for refusals, 402, 429, 401, and so on, were checked with Ollama's OpenAI-compatible entrance and a dummy server. The Meta specifications written here are based on the official documentation (`dev.meta.ai`).

### 3.6 When Using Claude (Anthropic)

```ini
[CaiClaude]
Url=https://api.anthropic.com/v1/messages
Model=claude-haiku-5-5
ApiKeyEnv=CX_ANTHROPIC_API_KEY
```

- Create the API key in the Claude Console (`platform.claude.com/settings/keys`). It starts with `sk-ant-` and is **shown only when created**, so copy it right away.
- **Use an environment variable name other than `ANTHROPIC_API_KEY` (the example above uses `CX_ANTHROPIC_API_KEY`).** `ANTHROPIC_API_KEY` is also read by Anthropic's official tools such as Claude Code, so using the same name could change the authentication and billing path of those tools. How to set it is the same as 3.2.
- When the key is not tied to a specific workspace, write the workspace ID (`wrkspc_…`) in `WorkspaceId` in the ini.
- Set `AIType` to `aiClaude`. Text, PDF, and images (PNG, JPEG, GIF, WebP) can be sent (PDF up to 600 pages).
- `Model`: `claude-haiku-5-5` (inexpensive), `claude-sonnet-5-5`, `claude-opus-5-5` (top tier), and so on. Write the model name as it is, without a date. A model that cannot be used gives HTTP 404.
- **`Temperature` is not sent for aiClaude** (with Claude's current API version, adding `temperature` gives HTTP 400 on every model).
- When `MaxTokens` is 0, 16000 is sent (Claude requires `max_tokens`). Current Claude models reason first by default, and **the reasoning also counts toward `max_tokens`**. With a small `MaxTokens`, the limit is reached in the middle of reasoning, the body becomes empty, and the result is `ceParse` (`stop_reason=max_tokens`).
- When the safety system stops an answer (`stop_reason` is `refusal`), the result is `ceBlocked` (the category and explanation are added to `LastError`).
- Billing and limits: a problem with the balance or payment method gives HTTP 402 (`billing_error`; not retried). Reaching the monthly usage cap gives HTTP 429 with no `retry-after`, and waiting does not help, so it is not retried (`LastError` contains the "usage limits" text). An ordinary 429 (rate limit) is retried after waiting the `retry-after` seconds. Overload (HTTP 529) is retried. A timeout (HTTP 504 and `timeout_error`) is not retried and gets a remedy.
- Prepayment and free credits are not written on the official pages (quickstart, API keys, rate limits). Check the billing screen of the Console. A new organization starts in a tier with low limits, which rise as you use it.
- Japan is in Anthropic's list of supported countries and regions (as of 2026-11-12).
- **Communication with the real Claude has not been checked yet.** The shape of the request and answer, and the behavior for refusals, 529, 429, 402, 401, and so on, were checked with Ollama's Anthropic-compatible entrance (`http://localhost:11434/v1/messages`) and with a dummy server. A PDF can be checked only on the real service, because Ollama's entrance ignores it without reading it. The Claude specifications written here are based on the official documentation.

## 4. Properties

| Name | Type | Access | Meaning |
|---|---|---|---|
| `AIType` | `TCaiAIType` | Read/write | The AI to use. Default `aiGemini`. It cannot be changed while busy |
| `Prompt` | `TStrings` | Read/write | Full paths of prompt files (one per line). Their contents (UTF-8) are placed before AText when sending. Use it to reuse fixed instructions |
| `Files` | `TStrings` | Read/write | Full paths of attached files (one per line). The sendable types are in 4.1 |
| `Model` | `string` | Read/write | If empty, `Model` of the ini |
| `TimeoutSeconds` | `Integer` | Read/write | Wait time (seconds). If 0, the ini value. Default 0 |
| `RetryCount` | `Integer` | Read/write | Number of retries. If -1, the ini value. Default -1 |
| `Temperature` | `Double` | Read/write | Variation of the answer (the closer to 0, the more the same every time). If -1, it is not sent (the AI's default). Default -1. For aiClaude it is never sent, even with a value |
| `MaxTokens` | `Integer` | Read/write | Upper limit of the answer length. If 0, it is not sent (aiClaude requires it, so 16000 is sent when it is 0). Default 0 |
| `Busy` | `Boolean` | Read only | True while a request is running |
| `LastErrorKind` | `TCaiErrorKind` | Read only | Kind of the last error (`ceNone` on success) |
| `LastError` | `string` | Read only | Text of the last error (`''` on success) |
| `LastStatusCode` | `Integer` | Read only | Last HTTP status (0 for a failure before sending) |
| `LastUsage` | `string` | Read only | The usage part (token counts, etc.) of the answer JSON, as it is |
| `LastResponse` | `string` | Read only | The last answer JSON (raw; for investigation) |

- Lines of `Prompt` and `Files` that contain only whitespace are ignored.

### 4.1 Attached Files (Files)

| Kind | Extensions | How it is sent |
|---|---|---|
| Text | `.txt .md .csv .tsv .json .xml .html .log .ini .pas .lpr .js .py .sql`, etc. | The contents (UTF-8) are enclosed in `--- File: name ---` and appended after the body |
| PDF | `.pdf` | Sent to the AI as an attachment |
| Image | `.png .jpg .jpeg .gif .webp` | Sent to the AI as an image |
| Others | `.xlsx .docx`, etc. | Cannot be sent (`ceFile`). Convert to CSV or PDF before attaching |

- The total of the attachments is up to 20MB.
- Ollama accepts only text and images (PDF gives `ceFile`).

## 5. Methods and Events

| Name | Meaning |
|---|---|
| `function AskAndWaitText(const AText: string): string;` | Sends the contents of Prompt + AText and Files, waits for the answer (plain prose without Markdown syntax), and returns it. `''` on failure |
| `function AskAndWaitMD(const AText: string): string;` | The same, but returns the answer in Markdown. `''` on failure |
| `procedure Cancel;` | Stops the running request. AskAndWait… returns `''` and `LastErrorKind = ceCanceled` |
| `procedure ReloadSettings;` | Reads WebView2.ini again |
| `function TestConnection: Boolean;` | Sends "Reply with just OK." and returns True if an answer comes (Prompt and Files are not used). Use it to check the settings and the key |

| Event | When |
|---|---|
| `OnMessage` | Reports what is going on (table below). The date and time are placed at the start of AMsg |

| Example of AMsg | When |
|---|---|
| `2026-11-23 10:15:02 [Start] Gemini gemini-3.8-flash` | When sending starts |
| `2026-11-23 10:15:05 [Retry 1/2] HTTP 503 (in 3 s)` | Before a retry |
| `2026-11-23 10:15:09 [Done] 7.2 s` | When the answer arrives |
| `2026-11-23 10:15:09 [Error] HTTP 400: API key not valid. ...` | On failure |

- The wording of these notices follows the application's language (in Japanese, `[開始]`, `[再送 1/2]`, `[完了]`, `[エラー]`).

## 6. Kinds of Error (LastErrorKind)

| Value | When | Retried? |
|---|---|---|
| `ceNone` | Success | ― |
| `ceSettings` | No ini, Url, Model, or ApiKeyEnv missing, or the environment variable is missing | No (nothing is sent) |
| `ceInput` | AText and Prompt are both empty, or a Prompt file is missing or unreadable | No (nothing is sent) |
| `ceFile` | An attachment is missing, unreadable, of an unsendable type, or over 20MB | No (nothing is sent) |
| `ceConnect` | Cannot connect, or the connection was lost | Yes |
| `ceTimeout` | The wait time expired | Yes |
| `ceHttp` | HTTP other than 2xx. The number is in `LastStatusCode` | Only 429 and 500–599 except 504. Not 400, 401, 402, 403, 404, or 504. Even for 429, not when there is no balance or quota (`insufficient_quota`) |
| `ceBlocked` | The AI refused to answer (safety filter, etc.) | No |
| `ceParse` | The answer cannot be read, or has no answer text | No |
| `ceCanceled` | `Cancel` was called | No |
| `ceBusy` | AskAndWait… was called again while busy (the original work continues as it is) | ― |
| `ceNotSupported` | An AI that is not supported (all five AIs are supported now, so it is not returned) | ― |

## 7. Examples of Use

### 7.1 Ask a Question and Put the Answer into an Editor

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

### 7.2 Write an Email

```pascal
S := CaiClient1.AskAndWaitText('Write the body of an apology email with these requirements:' + LineEnding + Memo1.Text);
```

### 7.3 Summarize or Aggregate Attached Material

```pascal
CaiClient1.Files.Clear;
CaiClient1.Files.Add('C:\data\report.pdf');
S := CaiClient1.AskAndWaitText('Summarize this document in 5 lines.');

CaiClient1.Files.Clear;
CaiClient1.Files.Add('C:\data\sales.csv');
S := CaiClient1.AskAndWaitMD('Total by month and by product, and make a table.');
```

### 7.4 Reuse Fixed Instructions (Prompt)

```pascal
// Write instructions such as "write politely in 300 characters or fewer" in mail_rule.txt
CaiClient1.Prompt.Text := ExtractFilePath(ParamStr(0)) + 'mail_rule.txt';
S := CaiClient1.AskAndWaitText(Memo1.Text);   // pass only the content of each time
```

### 7.5 Show Another Form with ShowModal and Call Inside It

The calling form (Form1) becomes inoperable, but it does not freeze and is still drawn. While waiting, the Stop button of Form2 can still be pressed.

```pascal
// Form1
procedure TForm1.btnAiClick(Sender: TObject);
begin
  Form2.QuestionText := MonacoEditor1.Text;
  if Form2.ShowModal = mrOK then
    MonacoEditor1.Text := Form2.AnswerText;
end;

// Form2: start the request after the form is shown
procedure TForm2.FormShow(Sender: TObject);
begin
  Application.QueueAsyncCall(@DoAsk, 0);   // start after the screen is drawn
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

// Stop button
procedure TForm2.btnStopClick(Sender: TObject);
begin
  CaiClient1.Cancel;
end;

// If the form is closed with × while waiting, stop
procedure TForm2.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if CaiClient1.Busy then
    CaiClient1.Cancel;
end;

// Show the progress
procedure TForm2.CaiClient1Message(Sender: TObject; const AMsg: string);
begin
  StatusBar1.SimpleText := AMsg;
end;
```

### 7.6 Check the Settings and the Key

```pascal
if CaiClient1.TestConnection then
  ShowMessage('Connected')
else
  ShowMessage(CaiClient1.LastError);
```

## 8. Notes

- While waiting, the processing of other buttons in the application can run. A double call to the same component is refused with `ceBusy` and returns `''`. The original work continues, and when it finishes, `LastError` and the others show the result of the original work. To stop the other buttons, call it inside a form shown with ShowModal, as in 7.5.
- If the form is closed while waiting and the component is destroyed, the communication is stopped before the component goes away. AskAndWait… returns `''`.
- A model that is congested (HTTP 503 continues) ends as `ceHttp` after the retries are used up. Wait a while, or change `Model` to another one (for example `gemini-flash-lite-latest`).
- HTTP 504 (a gateway timeout) is not retried, because resending a heavy request unchanged tends to be cut off at the same point. A remedy is added at the end of `LastError` ("shorten the input, make `MaxTokens` smaller, or try another model"). A congested 503 is retried, because waiting cures it.
- No history (previous exchanges) is kept. To ask a follow-up, put the previous answer into AText and send it.
