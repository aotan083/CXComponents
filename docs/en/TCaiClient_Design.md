# TCaiClient Design Document

Author: aotan083
Date: 2026-11-23
Version: 1.6

---

**Operating environment**: Lazarus 5.0 or later (FPC 3.2.2). Lazarus 4.8 and earlier are not supported.

## 1. Purpose and Policy

- TCaiClient is a non-visual component (`TComponent`) that lets an application call an AI API.
- It covers only the connection: send, receive the answer as a string, and report failures. It does not manage answer quality or cost.
- The AI to use is chosen with `AIType`: `aiGemini`, `aiClaude`, `aiChatGPT`, `aiMeta`, or `aiOllama`.
- What can be sent: (1) text only, or (2) text plus attached files.
- What is received: (1) text (no Markdown syntax) = `AskAndWaitText`, or (2) Markdown = `AskAndWaitMD`. The form of the answer is requested through an instruction sent to the AI (the system instruction). The component does not rework the answer.
- **The only way to call it is "return on completion" (synchronous).** `AskAndWaitText` and `AskAndWaitMD` do not return until the answer arrives, and return the answer as a string. On failure they return `''` and the reason goes into `LastError`. There is no asynchronous call (no event that delivers the answer).
- The screen does not freeze while waiting. The communication runs in a background thread, and the main thread waits inside the component by repeating `Application.ProcessMessages` + `Sleep(10)` (the application does not need to write `ProcessMessages`).
- The destination URL, the model name, the name of the environment variable that holds the API key, the timeout, and the retry settings are written in `WebView2.ini` (RULES 17). The API key itself is not written in the ini; it is put in an environment variable.
- Order of implementation: aiGemini → aiOllama → aiChatGPT → aiMeta → aiClaude. Anything that cannot be tested without paying comes later. aiOllama is free (local). aiChatGPT and aiMeta use the same format (Chat Completions), and by pointing at Ollama's entrance of the same format (`/v1/chat/completions`), the shape of the request and answer can be checked without paying. aiClaude has its own format and needs payment, so it comes last. All five AIs run (`ceNotSupported` is kept for the case where an AI that is not supported is added in the future).

### 1.1 Not Included

- Conversation history (multiple turns). One send is self-contained. If history is needed, the application puts the previous answer into AText and sends it.
- Streaming (showing the answer little by little). The answer is returned after it is complete.
- Function calling (tool use), image generation, and audio.
- Each vendor's file storage (such as the Gemini Files API). Attachments are included in the single request.
- Cost and token management (the usage in the answer JSON is only shown as it is in `LastUsage`).

## 2. Files and Packages

| File | Package | Contents |
|---|---|---|
| `uCaiClient.pas` (`source`) | cx (runtime) | `TCaiClient`, the communication thread, building the request for each AI and reading the answer |
| `uCXReg.pas` (`source\design`) | cxdsgn (design time) | Registration on the [CX] palette (`TCaiClient` at the end of the order) |
| `caiclient_icon.lrs` (`source\res`) | cxdsgn (design time) | Icons (`TCaiClient`, `_150`, `_200`) |
| `uCXLang.pas` | cx (runtime) | Adds 29 message strings (ja and en; from `sAiInstrText` to `sAiHintGateway`; CXLang_Design.md Chapter 5, M) |
| `cx.lpk` | cx | Adds `../source/uCaiClient.pas` (UnitName `uCaiClient`) |

- uses: `Windows, Classes, SysUtils, SyncObjs, IniFiles, Forms, fpjson, jsonparser, base64, winhttp`. The implementation part uses `uCXLang`. WebView2 is not used.
- No initialization or finalization.

### 2.1 HTTPS (WinHTTP)

- Communication uses WinHTTP, which is included in Windows (the `winhttp` unit of FPC 3.2.2). No DLL needs to be placed with the EXE.
- Functions used: `WinHttpOpen` → `WinHttpConnect` → `WinHttpOpenRequest` (`WINHTTP_FLAG_SECURE` for https) → `WinHttpAddRequestHeaders` → `WinHttpSendRequest` → `WinHttpReceiveResponse` → `WinHttpQueryHeaders` (status and `Retry-After`) → `WinHttpReadData` → `WinHttpCloseHandle`.
- The URL is split with `WinHttpCrackUrl`. http (Ollama on localhost) is sent with the same functions.
- The proxy follows the Windows settings (`WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY` for `WinHttpOpen`; if that cannot be opened, `WINHTTP_ACCESS_TYPE_DEFAULT_PROXY`).
- Timeouts use `WinHttpSetTimeouts`. The `winhttp` unit of FPC 3.2.2 misspells this function as `WinHttpSetTimes`, so it is declared again inside `uCaiClient` as `external 'winhttp.dll'`.
- The error number for an expired timeout is 12002 (`ERROR_WINHTTP_TIME` in the `winhttp` unit). `uCaiClient` holds it in the constant `ERR_WINHTTP_TIMEOUT`.
- The request body is JSON in UTF-8, and the answer is also read as UTF-8.
- `LastError` of `ceConnect` contains the WinHTTP error number and the URL (example: `Cannot connect (WinHTTP 12007): https://…`).

## 3. WebView2.ini

Add a section for each AI to `WebView2.ini` next to the EXE. It is read only once, when `TCaiClient` first sends (use `ReloadSettings` to read it again). The replacement of `%name%` is written in the same way as `CXExpandIniVars` of `uCXRuntime` (it refers to a key in the same section).

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

**[CaiClient] (common to all AIs)**

| Key | Meaning |
|---|---|
| `TimeoutSeconds` | Wait time for connecting, sending, and receiving (seconds). Default 120 |
| `RetryCount` | Number of times to retry after a failure. Default 2 (sends up to 3 times) |
| `RetryWaitSeconds` | Seconds to wait before retrying. Doubled each time (3 → 6 → 12) |
| `LogFolder` | If not empty, the request and answer JSON are written to a file for each call (the API key is not written; the base64 of attachments is written only as a length). For investigation |

**[CaiGemini] and the others (for each AI)**

| Key | Meaning |
|---|---|
| `Url` | Destination. `%Model%` is replaced with the `Model` of that section (or the value of the `Model` property if it has one). Example: with `Model=gemini-3.8-flash`, it becomes `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent`. A URL may also be written as it is without `%Model%` (then changing `Model` does not change the URL) |
| `Model` | Model name |
| `ApiKeyEnv` | Name of the environment variable that holds the API key |
| `MaxTokensParam` | (Optional) The item name used to send the upper limit of the answer length (the `MaxTokens` property). Used by the AIs of the Chat Completions form (aiChatGPT and aiMeta). Default `max_completion_tokens` (the name that OpenAI's newer models require). For compatible servers that know only `max_tokens` (such as Ollama's `/v1`), set it to `max_tokens` |
| `WorkspaceId` | (Optional; aiClaude) When the API key is not tied to a specific workspace, the ID of the workspace to send in the `anthropic-workspace-id` header (example: `wrkspc_…`). If empty, it is not sent |

- **API key**: it is not written in the ini (there is no key for writing it). The user puts the key in the environment variable whose name is specified by `ApiKeyEnv`. The component reads it with `GetEnvironmentVariable` every time it sends.
- **Cases that are errors** (`ceSettings`; nothing is sent):
  - `Url` or `Model` is empty
  - `ApiKeyEnv` is empty (except for aiOllama; aiOllama does not use a key, so it may be empty)
  - The environment variable of `ApiKeyEnv` does not exist or its value is empty. `LastError` is "Environment variable GEMINI_API_KEY is not set (WebView2.ini [CaiGemini] ApiKeyEnv)"
- Environment variables are read with the values from when the EXE started. After setting one, restart Lazarus and the EXE.
- Values given by the properties (4.2) `Model`, `TimeoutSeconds`, and `RetryCount` take priority over the ini (the ini is used only when they are empty, 0, or -1).

## 4. TCaiClient

`TCaiClient = class(TComponent)`. Unit `uCaiClient`.

### 4.1 Types

```pascal
type
  TCaiAIType = (aiGemini, aiClaude, aiChatGPT, aiMeta, aiOllama);

  TCaiErrorKind = (
    ceNone,
    ceSettings,     // Url or Model missing in the ini, API key environment variable missing, etc.
    ceInput,        // AText and Prompt are both empty, or a Prompt file is missing
    ceFile,         // attachment missing, unreadable, unsendable type, or too large
    ceConnect,      // cannot connect, or the connection was lost
    ceTimeout,      // the wait time expired
    ceHttp,         // HTTP other than 2xx (the value is in LastStatusCode)
    ceBlocked,      // the AI refused to answer (safety filter, etc.)
    ceParse,        // the answer JSON cannot be read, or has no answer text
    ceCanceled,     // Cancel was called
    ceBusy,         // AskAndWait… was called again while busy
    ceNotSupported  // an AI that is not supported yet
  );

  TCaiClientMessageEvent = procedure(Sender: TObject; const AMsg: string) of object;
```

- When a value name such as `aiGemini` clashes with the same name in another unit, write it with the type name, as in `TCaiAIType.aiGemini`.

### 4.2 Properties

| Name | Type | Access | Meaning |
|---|---|---|---|
| `AIType` | `TCaiAIType` | Read/write (published) | The AI to use. Default `aiGemini`. It is not changed while `Busy` (`LastError` becomes "AIType cannot be changed while a request is in progress") |
| `Prompt` | `TStrings` | Read/write (published) | Full paths of prompt files (one per line). Their contents (UTF-8) are joined with a blank line between them and placed before AText when sending. Lines containing only whitespace are ignored |
| `Files` | `TStrings` | Read/write (published) | Full paths of attached files (one per line). If empty, only text is sent. Lines containing only whitespace are ignored |
| `Model` | `string` | Read/write (published) | If empty, `Model` of the ini |
| `TimeoutSeconds` | `Integer` | Read/write (published) | If 0, the ini value. Default 0 |
| `RetryCount` | `Integer` | Read/write (published) | If -1, the ini value. Default -1 |
| `Temperature` | `Double` | Read/write (published) | If -1, it is not sent (the AI's default). Default -1. **For aiClaude it is never sent, even with a value** (with `anthropic-version` 2026-10-21, adding `temperature` gives HTTP 400 on every model) |
| `MaxTokens` | `Integer` | Read/write (published) | Upper limit of the answer length. If 0, it is not sent (aiClaude requires it, so 16000 is sent when it is 0; current Claude models count their reasoning too, so a small value makes the body empty). Default 0 |
| `OnMessage` | `TCaiClientMessageEvent` | Read/write (published) | Progress notices (4.4) |
| `Busy` | `Boolean` | Read only | True while AskAndWait… is running |
| `LastErrorKind` | `TCaiErrorKind` | Read only | Kind of the last error (`ceNone` on success) |
| `LastError` | `string` | Read only | Text of the last error (`''` on success) |
| `LastStatusCode` | `Integer` | Read only | Last HTTP status (0 for a failure before communication) |
| `LastUsage` | `string` | Read only | The usage part of the answer JSON (as it is) |
| `LastResponse` | `string` | Read only | The last answer JSON (raw; for investigation) |

### 4.3 Methods

| Name | Meaning |
|---|---|
| `function AskAndWaitText(const AText: string): string;` | Sends the contents of Prompt + AText and Files, waits for the answer (plain prose without Markdown syntax), and returns it. `''` on failure |
| `function AskAndWaitMD(const AText: string): string;` | The same, but returns the answer in Markdown. `''` on failure |
| `procedure Cancel;` | Stops the running request (closes the WinHTTP request handle and also leaves the retry wait). AskAndWait… returns `''` and `LastErrorKind = ceCanceled` |
| `procedure ReloadSettings;` | Reads the ini again |
| `function TestConnection: Boolean;` | Sends `AskAndWaitText('Reply with just OK.')` and returns True if the answer is not `''` (for checking the connection; Prompt and Files are not used) |

### 4.4 What OnMessage Reports

| When | Example of AMsg |
|---|---|
| At the start | `2026-11-23 10:15:02 [Start] Gemini gemini-3.8-flash` |
| Before a retry | `2026-11-23 10:15:05 [Retry 1/2] HTTP 503 (in 3 s)` |
| On success | `2026-11-23 10:15:09 [Done] 7.2 s` |
| On failure | `2026-11-23 10:15:09 [Error] HTTP 400: API key not valid. ...` |

- It is called in the main thread (it is called from inside the wait loop, so it is never called directly from the thread).
- The wording is in `uCXLang` (the examples above are the English wording; in Japanese it is `[開始]`, `[再送 1/2]`, `[完了]`, `[エラー]`).

### 4.5 Flow of AskAndWait… (common to Text and MD)

1. If `Busy`, `ceBusy` (returns `''`). The running work (communication and waiting) is not touched. However, `ceBusy` and "A request is already in progress" are put into `LastErrorKind` and `LastError`. When the original work finishes, they are overwritten with its result (on success they return to `ceNone` and `''`).
2. Clear `LastError*`, `LastUsage`, and `LastResponse`, and set `Busy := True` (it is always set back to False in try…finally).
3. Check the input: if AText and Prompt (excluding blank lines) are both empty, `ceInput`. If a Prompt file does not exist, `ceInput`. If a Files file does not exist, `ceFile`.
4. Read the ini (only the first time). Decide Url and Model from the section of the AI, and read the API key from the environment variable of `ApiKeyEnv`. If anything is missing, `ceSettings` (Chapter 3).
5. Build the body: the contents of Prompt (joined by a blank line) → a blank line → AText → text attachments (4.7).
6. Read the PDF and image attachments and convert them to base64 (4.7). If a file cannot be read, has an unsendable type, or is too large, `ceFile`.
7. Build the request JSON for each AI (Chapter 5). The instruction for the form of the answer (4.6) goes into the system instruction.
8. `OnMessage` ([Start]). Start the communication thread.
9. Wait until the thread finishes by repeating `Application.ProcessMessages` + `Sleep(10)`. While waiting, if the thread has sent retry notices, pass them to `OnMessage` ([Retry]).
10. Put the result of the thread into `LastStatusCode`, `LastResponse`, and `LastUsage`. On success, set `LastErrorKind := ceNone` and `LastError := ''` (this removes a `ceBusy` that a double call during the wait put there), return the answer, and call `OnMessage` ([Done]). On failure, set `LastErrorKind` and `LastError`, return `''`, and call `OnMessage` ([Error]).
11. If the ini has `LogFolder`, write the request and answer to one file (4.10).

- If the component is destroyed while waiting (for example, the form was closed), the destructor calls `Cancel` and waits for the thread to finish before the component goes away. The wait loop watches the local variable `Alive`, leaves without touching the component (`Self`), and returns `''` (no event is called). The component remembers the address of `Alive` before the loop (`FAlive`), and the destructor sets it to `False`.
- While waiting, the processing of other buttons in the application can run. A double call to the same component is refused with `ceBusy`. Whether to stop the other buttons is up to the application (if the calling form is shown with `ShowModal` and AskAndWait… is called inside it, the form that made the call becomes inoperable).

### 4.6 Instruction for the Form of the Answer

The following one sentence goes into the system instruction (the wording is in `uCXLang` and follows the application's language).

- `AskAndWaitText`: "Write the answer as plain prose without Markdown syntax (#, *, ```, tables, etc.)."
- `AskAndWaitMD`: "Write the answer in Markdown format."

### 4.7 Attached Files

| Extension | How it is sent |
|---|---|
| `.txt .md .csv .tsv .json .xml .html .log .ini .pas .lpr .js .ts .py .sql`, etc. (text) | The contents are read (UTF-8; the BOM is removed), enclosed in `--- File: name ---`, and appended after the body (common to all AIs) |
| `.pdf` | Sent as an attachment on the AI side (base64). Gemini, Claude, and ChatGPT |
| `.png .jpg .jpeg .gif .webp` | Sent as an image on the AI side (base64). All AIs (for Ollama, only models that can read images) |
| Others (`.xlsx .docx`, etc.) | `ceFile` ("This file type cannot be sent. Convert it to CSV or PDF: name") |

- The total of the attachments sent at one time is up to 20MB (matched to the limit of one Gemini request). Above it, `ceFile`.
- When Excel data is to be aggregated, the application converts it to CSV before attaching it (the component does not read Excel).

### 4.8 Timeout and Retry

- `WinHttpSetTimeouts` sets `TimeoutSeconds × 1000` for all four: name resolution, connection, sending, and receiving. When it expires (`ERROR_WINHTTP_TIME`), `ceTimeout`.
- It retries on: connection failure, timeout, HTTP 429, and HTTP 500–599 (including Gemini's 503 overload; **except 504**).
- It does not retry on: HTTP 429 whose `error.code` is `insufficient_quota` (no balance or quota; waiting does not help), HTTP 429 whose `error.details.error_code` is `enforced_spend_limit_reached` (Claude's monthly usage cap; it also comes with no `retry-after`), HTTP 504 and anything whose `error.type` is `timeout_error` (Claude also returns it with 500; a gateway timeout: the gateway could not wait for the AI to finish, and for a heavy request, resending the same request tends to be cut off at the same point; this differs from the congestion of 503, which waiting cures; Meta's official guidance is also not to resend but to use streaming; this component has no streaming, so it does not retry and returns the error with a remedy added; 4.9), HTTP 400, 401, 402 (insufficient balance or a payment-method problem), 403, and 404 (errors in the settings or request that stay the same however many times they are sent; this includes Gemini's 404 "this model is not available"), `ceBlocked`, `ceParse`, and `ceCanceled`.
- Wait: `RetryWaitSeconds`, doubled from the second time on. For HTTP 429 with a `Retry-After` header, that number of seconds (up to 60 seconds). `Cancel` also stops it while waiting.

### 4.9 Error Text

`LastError` is "a description of the kind + the error text returned by the AI". Example: `HTTP 400: API key not valid. Please pass a valid API key.` From the AI's JSON, `error.message` (Gemini, ChatGPT, Meta, Claude) or `error` (Ollama) is taken out. If it cannot be read, the first 500 characters of the answer. For HTTP 504 and `timeout_error`, a remedy is added at the end ("The gateway timed out. Shorten the input, make MaxTokens smaller, or try another model"; `sAiHintGateway` of `uCXLang`).

### 4.10 Log (LogFolder)

- File name: `CaiClient_yyyymmdd_hhnnss_zzz.log` (one for each AskAndWait…).
- Contents: start time, AI, model, URL (the key is not included), request JSON (the base64 of attachments is replaced with `"<base64 123456 bytes>"`), HTTP status, answer JSON, elapsed seconds, and error.
- If it cannot be written, the result of AskAndWait… is not affected.

## 5. Request and Answer for Each AI

### 5.1 aiGemini (built in version 1.0)

- Destination: `POST {Url}`. Headers `x-goog-api-key: {ApiKey}` and `Content-Type: application/json` (the key is not put in the URL).
- Request:

```json
{
  "systemInstruction": { "parts": [ { "text": "instruction for the form of the answer" } ] },
  "contents": [ { "role": "user", "parts": [
      { "text": "contents of Prompt + AText + text attachments" },
      { "inline_data": { "mime_type": "application/pdf", "data": "base64..." } }
  ] } ],
  "generationConfig": { "temperature": 0.7, "maxOutputTokens": 4096 }
}
```

  Each value of `generationConfig` is included only when it is specified (if neither is specified, `generationConfig` itself is left out).
- Answer: the `candidates[0].content.parts[*].text` values joined together (parts with `"thought": true` are excluded).
- Refusal: `promptFeedback.blockReason` exists, or `candidates` is empty, or `finishReason` is `SAFETY`, `RECITATION`, or `PROHIBITED_CONTENT` → `ceBlocked` (the reason goes into `LastError`).
- Usage: `usageMetadata`.

### 5.2 aiClaude (fifth: last)

- Messages API (`https://api.anthropic.com/v1/messages`). Headers `x-api-key: {ApiKey}`, `anthropic-version: 2026-10-21`, and `content-type: application/json`. Create the key in the Claude Console (it starts with `sk-ant-` and is shown only when created).
- Use an environment variable name different from `ANTHROPIC_API_KEY`, which official tools such as Claude Code read (for example `CX_ANTHROPIC_API_KEY`); using the same name could change the authentication and billing path of those tools. When the key is not tied to a workspace, add the `anthropic-workspace-id` header with `WorkspaceId` in the ini (Chapter 3).
- Request:

```json
{
  "model": "claude-haiku-5-5",
  "max_tokens": 16000,
  "system": "instruction for the form of the answer",
  "messages": [ { "role": "user", "content": [
      { "type": "document", "source": { "type": "base64", "media_type": "application/pdf", "data": "base64..." } },
      { "type": "image", "source": { "type": "base64", "media_type": "image/png", "data": "base64..." } },
      { "type": "text", "text": "contents of Prompt + AText + text attachments" }
  ] } ]
}
```

- `max_tokens` is required. When `MaxTokens` is 0, 16000 is sent (current Claude models reason first by default, and the reasoning counts toward `max_tokens`; the official guideline for non-streaming is about 16000).
- **`Temperature` is not sent.** With `anthropic-version` 2026-10-21, adding `temperature`, `top_p`, or `top_k` gives HTTP 400 on every model.
- Attachments are placed before the `text` of the body (the official recommendation). PDF is `document`, and images are `image` (PNG, JPEG, GIF, WebP). A PDF can have up to 600 pages per request (100 pages for models whose context is under 1M tokens).
- `thinking` is not sent (the model's default is kept).
- Answer: the `text` of each item of `content[]` with `type="text"`, joined together (`thinking` parts are not included). Usage: `usage` (as it is, in `LastUsage`).
- Refusal: HTTP 200 with `stop_reason="refusal"` → `ceBlocked` (the `category` and `explanation` of `stop_details` are added to `LastError`). If the body is empty (for example, `max_tokens` was reached in the middle of reasoning) → `ceParse` (`stop_reason` goes into `LastError`).
- Errors are `{"type":"error","error":{"type","message"},"request_id"}`. 400 `invalid_request_error` (also when a usage limit you set yourself is reached), 401 `authentication_error`, 402 `billing_error` (not retried), 403, 404 `not_found_error` (the model does not exist or cannot be used), 413, 429 `rate_limit_error` (retried after waiting the `retry-after` seconds if present; the monthly usage cap has `error.details.error_code` of `enforced_spend_limit_reached`, comes with no `retry-after`, and is not retried), 500 `api_error` (retried), 529 `overloaded_error` (retried), and 504 and `timeout_error` (not retried; a remedy is added; 4.8 and 4.9).

### 5.3 aiChatGPT (third)

- A request of the same format can also be sent by setting `Url` in the ini to Ollama's `http://localhost:11434/v1/chat/completions` (any value will do for the key; use it to check the shape of the request and answer without paying).
- `POST {Url}` (Chat Completions). Header `Authorization: Bearer {ApiKey}`.
- Request: `messages` with `system` and `user`. The `content` of user is `[{"type":"text"},{"type":"image_url","image_url":{"url":"data:image/png;base64,..."}},{"type":"file","file":{"filename","file_data":"data:application/pdf;base64,..."}}]`.
- Answer: `choices[0].message.content` (a string; some compatible servers return an array of `text` parts, which are joined in that case). Usage: `usage` (as it is, in `LastUsage`).
- Refusal: `message.refusal` is not empty, or `finish_reason` is `content_filter` → `ceBlocked` (the reason goes into `LastError`). If the body is empty, `ceParse` (`finish_reason` goes into `LastError`).
- Notes on the request: `model` is the model name in use (it is not put in `Url`). `temperature` (if `Temperature` is not -1) and `MaxTokens` (if greater than 0, under the name of `MaxTokensParam`; Chapter 3) are included only when present. The `filename` of the PDF `file` is the name of the attached file. Images are PNG, JPEG, GIF, and WebP.
- When pointed at Ollama's `/v1/chat/completions`, images can be sent. A PDF `file` gets HTTP 400 (`invalid message format`) and becomes `ceHttp` (the real OpenAI accepts it). `max_completion_tokens` is ignored there, so set `MaxTokensParam=max_tokens`.

### 5.4 aiMeta (fourth)

- Meta Model API (`https://api.meta.ai/v1/chat/completions`; Chat Completions compatible with OpenAI). Header `Authorization: Bearer {ApiKey}`. The key starts with `LLM_`, and the environment variable is `MODEL_API_KEY`.
- The request, reading the answer, refusals, usage, `MaxTokensParam`, and attachments (images and PDF) are the same as 5.3 (aiChatGPT), and the same processing is used. Only `Url`, `Model`, and `ApiKeyEnv` differ. The default `max_completion_tokens` is right for the name of the length limit (`max_tokens` is also accepted as an old name, but it is not used).
- `Model`: the default is `muse-spark-1.3` (Standard, where what you send is not used to train Meta's models). Models with `-contributor` (for example `muse-spark-1.3-contributor`) are cheaper in exchange for permitting what you send to be used for training, so they are not the default.
- These are reasoning models, and the reasoning also counts toward `max_completion_tokens` and the charge. With a small `MaxTokens`, the body becomes empty and the result is `ceParse` (`finish_reason=length`).
- Errors are `{"error":{"message","type","param","code"}}`. 429 `rate_limit_exceeded` (with `Retry-After`; retried), 402 `billing_error` (insufficient balance or a payment-method problem; not retried), 401 `invalid_api_key`, 404 `model_not_found`, and 503 `service_overloaded` (`Retry-After: 60`; retried).
- 504 `gateway_timeout`: Meta's guidance is not to resend the same request but to use streaming. This component has no streaming, so it does not retry 504 and returns an error (`ceHttp`) with a remedy added (4.8 and 4.9).

### 5.5 aiOllama (second)

- `POST {Url}` (`/api/chat`). No key. `"stream": false` is always added.
- Request: `{"model","stream":false,"messages":[{"role":"system","content"},{"role":"user","content","images":["base64..."]}],"options":{"temperature","num_predict"}}`. `model` is the model name in use (it is not put in `Url`). `options` is included only when there is `Temperature` (`temperature`, if not -1) or `MaxTokens` (`num_predict`, if greater than 0).
- The only header is `Content-Type`. The API key is not used (`ApiKeyEnv` may be empty).
- Attachments: text is appended to the body (4.7). Images go into the `images` of user as base64 (only models that can read images; a model that cannot read them makes Ollama return an error, which becomes `ceHttp` as it is). PDF cannot be sent (`ceFile`; `LastError` is "This AI cannot receive this file type (text and images only): name").
- Answer: `message.content`. `<think>…</think>` (from models such as qwen3 that put their reasoning in the body) is removed from the answer. If only a `</think>` without an opening tag exists, everything before it is removed. An unclosed `<think>` is removed together with everything after it. If nothing is left, `ceParse` (`done_reason` goes into `LastError`).
- `message.thinking` (in versions of Ollama that return the reasoning in a separate item; confirmed with qwen3) is not used. It does not enter the body, so it does not appear in the answer.
- Usage: those of `prompt_eval_count`, `eval_count`, `total_duration`, and `load_duration` that exist in the answer are put into `LastUsage` as JSON (times are in nanoseconds).
- HTTP other than 2xx: the text of `{"error":"…"}` goes into `LastError` (example: for a missing model, HTTP 404 `model 'x' not found`; it is not retried).
- Models to be checked: gemma3:4b, qwen2.5:3b, qwen3:4b, llama3.2:3b, phi4-mini.
- `LastError` when it cannot connect (Ollama is not running): "Cannot connect to Ollama. Check that ollama serve is running (WinHTTP number)" (`ceConnect`; returned after the retries).
- The first request takes time because Ollama loads the model into memory (there is an example of about one minute with gemma3:4b). `TimeoutSeconds` must allow for that (default 120 seconds).

## 6. Thread

- `TCaiHttpThread = class(TThread)` (in the implementation part only). It is created inside AskAndWait…, which waits for it to finish and then calls `Free` (`FreeOnTerminate := False`).
- The thread holds only the assembled URL, headers, request JSON string, and the timeout and retry values (it does not touch the component's properties).
- Inside the thread, everything is done: sending → reading the answer → taking the answer and error out of the answer JSON → retrying.
- Retry notices are added by the thread to a string list protected by a `TCriticalSection`, and the main thread's wait loop takes them out and passes them to `OnMessage` (`Synchronize` and `Queue` are not used; the wait loop already runs with `ProcessMessages`, which is enough).
- `Cancel` closes the WinHTTP request handle held by the thread with `WinHttpCloseHandle` (the WinHTTP function that is waiting fails and returns). It also leaves the retry wait (it checks the stop signal every 100 ms).

## 7. Examples of Use (to be put in the Usage document)

```pascal
// Ask a question and put the answer into a TCMonacoEditor
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

- Writing an email: `AskAndWaitText('Write the body of an apology email with these requirements: …')`.
- Summarizing or aggregating attachments: put a PDF or CSV in `Files`, then `AskAndWaitText('Summarize this')` or `AskAndWaitMD('Total by month and make a table')`.
- Reusing fixed instructions: put a file that holds the instructions (for example `mail_rule.txt`) in `Prompt`, and pass only the content of each time as AText.
- Stop button: `CaiClient1.Cancel`.
- Showing progress: `StatusBar1.SimpleText := AMsg` in `OnMessage`.

## 8. Tests (items to be written in the separate document TCaiClient_TestSpec.md)

- No ini, no Url, no Model, no ApiKeyEnv → `ceSettings`
- The environment variable of ApiKeyEnv is missing or empty → `ceSettings` (nothing is sent)
- AText and Prompt are both empty, or a Prompt file is missing → `ceInput`
- Wrong URL → `ceConnect` / `ceHttp` (404)
- Wrong key → `ceHttp` (400/401), no retry
- A model that is no longer available (gemini-2.5-flash) → `ceHttp` (404), no retry
- `LastError` is empty after a success (when a double call happened during the wait)
- Attachments of text only, PDF, image, and CSV, with `AskAndWaitText` / `AskAndWaitMD`
- One and two Prompt files
- At a 503, [Retry] appears in OnMessage and it tries again
- aiOllama: connection check, text, Markdown, a Prompt file + CSV attachment, an image attachment, PDF (`ceFile`), a missing model (404), Ollama not running (`ceConnect`), Cancel, `MaxTokens`, and `LastUsage`
- aiChatGPT: real communication pointed at Ollama's `/v1` (connection check, text, Markdown, Prompt + CSV, an image, PDF getting 400, a missing model 404, a missing environment variable, `MaxTokensParam=max_tokens`, Cancel), and answers made by a dummy server (the shape of the request [Authorization, `max_completion_tokens`, system, the `file` part], `refusal`, `content_filter`, an array `content`, 429 `insufficient_quota` is not retried, 429 rate limit is retried, 401 is not retried, an empty body). Checking on the real OpenAI comes after paying
- aiChatGPT and aiMeta (dummy server): 504 is not retried, and the remedy text is added at the end of `LastError`. 503 is retried and succeeds
- aiClaude: real communication pointed at Ollama's `/v1/messages` (connection check, text, Markdown, Prompt + CSV, an image, a PDF can be sent as `document`, a missing model 404, a missing environment variable, `MaxTokens`, Cancel), and answers made by a dummy server (the shape of the request [`x-api-key`, `anthropic-version`, `anthropic-workspace-id`, the default `max_tokens` of 16000, `Temperature` is not sent, attachments come before the body], reasoning parts are not included, `refusal`, an empty body, 529 is retried, the 429 monthly cap is not retried, 429 waits the `retry-after` seconds, `timeout_error` [500] and 504 are not retried and get a remedy, 402 and 401 are not retried). Checking on the real Claude comes after an API key and billing are ready
- aiMeta: the same tests as aiChatGPT (Ollama's `/v1` and a dummy server). In addition, 402 is not retried, and a 429 `Retry-After` is waited for exactly that many seconds (also checked with aiChatGPT). Checking on the real Meta comes after an account and a payment method are ready
- The request and answer shapes of aiChatGPT and aiMeta are checked without paying by pointing `Url` at Ollama's `/v1/chat/completions` (checking on the real services is separate)
- Timeout (`TimeoutSeconds=1`), Cancel, calling again while busy (`ceBusy`), closing the form while busy
- The screen keeps moving while waiting (moving the window, pressing a button)
