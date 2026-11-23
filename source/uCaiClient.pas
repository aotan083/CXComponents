{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCaiClient - AI の API を呼ぶ非ビジュアル部品 TCaiClient（TCaiClient_Design.md）
  環境: Lazarus 4.8 / FPC 3.2.2 / Windows 11 x64

  ・呼び方は「完了復帰」（同期）だけ。AskAndWaitText・AskAndWaitMD は回答が来るまで戻らない。
    失敗したら '' を返し、理由は LastError・LastErrorKind・LastStatusCode に入る。
  ・待つ間も画面は固まらない。通信は裏のスレッド（TCaiHttpThread）で行い、
    メインスレッドは部品の中で Application.ProcessMessages＋Sleep(10) を繰り返して待つ。
  ・通信は Windows の WinHTTP（EXE と一緒に置く DLL は無い）。
  ・設定は EXE の隣の WebView2.ini の [CaiClient]（共通）と [CaiGemini] など（AI ごと）。
    API キーは ini に書かず、ApiKeyEnv で名前を指定した環境変数から読む。
  ・5 つの AI（aiGemini・aiOllama・aiChatGPT・aiMeta・aiClaude）が動く。
  ・initialization・finalization は持たない。 }
unit uCaiClient;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, SyncObjs, IniFiles, Forms,
  fpjson, jsonparser, base64, winhttp;

type
  { 使う AI }
  TCaiAIType = (aiGemini, aiClaude, aiChatGPT, aiMeta, aiOllama);

  { エラーの種類（LastErrorKind） }
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

  { 途中の知らせ（[開始]・[再送]・[完了]・[エラー]） }
  TCaiClientMessageEvent = procedure(Sender: TObject; const AMsg: string) of object;

  TCaiHttpThread = class;

  { TCaiClient }
  TCaiClient = class(TComponent)
  private
    FAIType: TCaiAIType;
    FPrompt: TStringList;
    FFiles: TStringList;
    FModel: string;
    FTimeoutSeconds: Integer;
    FRetryCount: Integer;
    FTemperature: Double;
    FMaxTokens: Integer;
    FOnMessage: TCaiClientMessageEvent;

    FBusy: Boolean;
    FLastErrorKind: TCaiErrorKind;
    FLastError: string;
    FLastStatusCode: Integer;
    FLastUsage: string;
    FLastResponse: string;

    FIni: TMemIniFile;          // WebView2.ini（最初に送るとき 1 回だけ読む）
    FIniLoaded: Boolean;
    FThread: TCaiHttpThread;    // 処理中の通信スレッド（処理中でなければ nil）
    FAlive: PBoolean;           // 待ちのループのローカル変数。破棄されたら False にする

    procedure SetAIType(AValue: TCaiAIType);
    procedure SetPrompt(AValue: TStrings);
    procedure SetFiles(AValue: TStrings);
    function GetPrompt: TStrings;
    function GetFiles: TStrings;
    { エラーを LastError* に入れる }
    procedure SetError(AKind: TCaiErrorKind; const AMsg: string; AStatus: Integer = 0);
    { OnMessage を呼ぶ（先頭に日時を付ける） }
    procedure DoMsg(const AText: string);
    { AskAndWaitText・AskAndWaitMD の本体 }
    function DoAsk(const AText: string; AMarkdown, AUseInputs: Boolean): string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Prompt の中身＋AText と Files を送り、回答（Markdown の記号を使わない文章）を返す。失敗は '' }
    function AskAndWaitText(const AText: string): string;
    { 同じく、回答を Markdown で返す。失敗は '' }
    function AskAndWaitMD(const AText: string): string;
    { 処理中を止める。AskAndWait… は '' を返し、LastErrorKind = ceCanceled }
    procedure Cancel;
    { WebView2.ini を読み直す }
    procedure ReloadSettings;
    { 「OK とだけ答えて」を送り、回答が来れば True（Prompt・Files は使わない） }
    function TestConnection: Boolean;

    property Busy: Boolean read FBusy;
    property LastErrorKind: TCaiErrorKind read FLastErrorKind;
    property LastError: string read FLastError;
    property LastStatusCode: Integer read FLastStatusCode;
    property LastUsage: string read FLastUsage;
    property LastResponse: string read FLastResponse;
  published
    property AIType: TCaiAIType read FAIType write SetAIType default aiGemini;
    property Prompt: TStrings read GetPrompt write SetPrompt;
    property Files: TStrings read GetFiles write SetFiles;
    property Model: string read FModel write FModel;
    property TimeoutSeconds: Integer read FTimeoutSeconds write FTimeoutSeconds default 0;
    property RetryCount: Integer read FRetryCount write FRetryCount default -1;
    property Temperature: Double read FTemperature write FTemperature;
    property MaxTokens: Integer read FMaxTokens write FMaxTokens default 0;
    property OnMessage: TCaiClientMessageEvent read FOnMessage write FOnMessage;
  end;

  { 通信用スレッド（部品の中だけで使う）。
    組み立て済みの URL・ヘッダー・本文を送り、回答 JSON から回答・エラーを取り出し、リトライまで行う }
  TCaiHttpThread = class(TThread)
  private
    FLock: TCriticalSection;
    FRequest: HINTERNET;        // 送信中の要求ハンドル（Cancel で閉じる）
    FCanceled: Boolean;
    FNotes: TStringList;        // 再送の知らせ（メインスレッドが取り出す）
    { 送るもの }
    FAIType: TCaiAIType;
    FUrl: UnicodeString;
    FHeaders: UnicodeString;
    FBody: RawByteString;
    FTimeoutSec: Integer;
    FRetryCount: Integer;
    FRetryWaitSec: Integer;
    { 1 回送る。成功・失敗を FRes* に入れ、やり直してよいかを返す }
    function SendOnce(out ARetryAfter: Integer): Boolean;
    procedure AddNote(const S: string);
    function WaitCancelable(AMs: Integer): Boolean;
  protected
    procedure Execute; override;
  public
    { 結果 }
    ResKind: TCaiErrorKind;
    ResStatus: Integer;
    ResAnswer: string;
    ResRaw: string;
    ResUsage: string;
    ResError: string;
    constructor Create(AAIType: TCaiAIType; const AUrl, AHeaders: string;
      const ABody: RawByteString; ATimeoutSec, ARetryCount, ARetryWaitSec: Integer);
    destructor Destroy; override;
    procedure Cancel;
    { たまった再送の知らせを取り出す（メインスレッドから呼ぶ） }
    function TakeNotes: string;
  end;

implementation

uses
  uCXLang;

const
  INI_NAME = 'WebView2.ini';
  INI_COMMON = 'CaiClient';
  { AI ごとの ini のセクション名と、表示名 }
  AI_SECTION: array[TCaiAIType] of string =
    ('CaiGemini', 'CaiClaude', 'CaiChatGPT', 'CaiMeta', 'CaiOllama');
  AI_NAME: array[TCaiAIType] of string =
    ('Gemini', 'Claude', 'ChatGPT', 'Meta', 'Ollama');

  DEF_TIMEOUT = 120;            // [CaiClient] TimeoutSeconds の既定
  DEF_RETRY = 2;                // [CaiClient] RetryCount の既定
  DEF_RETRY_WAIT = 3;           // [CaiClient] RetryWaitSeconds の既定
  MAX_ATTACH_MB = 20;           // 添付の合計の上限（Gemini の 1 要求の上限に合わせる）
  MAX_RETRY_AFTER = 60;         // Retry-After を使うときの上限（秒）
  { Claude は max_tokens が必須。MaxTokens が 0 のときに送る値。現行のモデルは、考える分も max_tokens に
    数えられるので、小さいと本文が空になる。公式の目安（非ストリーミング）は約 16000 }
  CLAUDE_DEF_MAX_TOKENS = 16000;
  CLAUDE_API_VERSION = '2026-10-21';   // anthropic-version（この版では temperature・top_p・top_k が 400 になる）

  USER_AGENT = 'CXComponents-TCaiClient/1.0';

  { WinHTTP の待ち時間を過ぎたときのエラー番号（FPC の winhttp では ERROR_WINHTTP_TIME という名前） }
  ERR_WINHTTP_TIMEOUT = 12002;

{ FPC 3.2.2 の winhttp ユニットは、この関数の名前を WinHttpSetTimes と書き誤っているので、ここで宣言する }
function WinHttpSetTimeouts(hInternet: HINTERNET; nResolveTimeout, nConnectTimeout,
  nSendTimeout, nReceiveTimeout: LongInt): BOOL; stdcall; external 'winhttp.dll';

{ ============================================================================
  共通の小さな関数
  ============================================================================ }

{ 日時を付けた OnMessage 用の文 }
function Stamp(const S: string): string;
begin
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ' + S;
end;

{ ファイルをそのままバイト列で読む }
function ReadFileBytes(const AFileName: string; out AData: RawByteString): Boolean;
var
  FS: TFileStream;
begin
  Result := False;
  AData := '';
  try
    FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      SetLength(AData, FS.Size);
      if FS.Size > 0 then
        FS.ReadBuffer(AData[1], FS.Size);
      Result := True;
    finally
      FS.Free;
    end;
  except
    Result := False;
  end;
end;

{ UTF-8 のテキストファイルを読む（先頭の BOM は除く） }
function ReadUtf8File(const AFileName: string; out AText: string): Boolean;
var
  Data: RawByteString;
begin
  AText := '';
  Result := ReadFileBytes(AFileName, Data);
  if not Result then Exit;
  if (Length(Data) >= 3) and (Data[1] = #$EF) and (Data[2] = #$BB) and (Data[3] = #$BF) then
    Delete(Data, 1, 3);
  SetCodePage(Data, CP_UTF8, False);
  AText := Data;
end;

{ 空白だけの行を除いた一覧を作る }
procedure CopyNonBlank(ASrc: TStrings; ADest: TStrings);
var
  i: Integer;
begin
  ADest.Clear;
  for i := 0 to ASrc.Count - 1 do
    if Trim(ASrc[i]) <> '' then
      ADest.Add(Trim(ASrc[i]));
end;

{ 添付の種類：テキスト（本文につなぐ）・PDF／画像（base64 で送る）・送れない }
type
  TCaiAttachKind = (akText, akBinary, akUnsupported);

function AttachKindOf(const AFileName: string; out AMime: string): TCaiAttachKind;
const
  TEXT_EXT: array[0..33] of string = (
    '.txt', '.md', '.markdown', '.csv', '.tsv', '.json', '.xml', '.html', '.htm', '.log',
    '.ini', '.pas', '.pp', '.inc', '.lpr', '.lfm', '.dpr', '.js', '.ts', '.py',
    '.sql', '.yaml', '.yml', '.css', '.bat', '.cmd', '.ps1', '.c', '.h', '.cpp',
    '.java', '.go', '.php', '.sh');
var
  Ext: string;
  i: Integer;
begin
  AMime := '';
  Ext := LowerCase(ExtractFileExt(AFileName));
  for i := Low(TEXT_EXT) to High(TEXT_EXT) do
    if Ext = TEXT_EXT[i] then
    begin
      AMime := 'text/plain';
      Exit(akText);
    end;
  Result := akBinary;
  if Ext = '.pdf' then AMime := 'application/pdf'
  else if Ext = '.png' then AMime := 'image/png'
  else if (Ext = '.jpg') or (Ext = '.jpeg') then AMime := 'image/jpeg'
  else if Ext = '.gif' then AMime := 'image/gif'
  else if Ext = '.webp' then AMime := 'image/webp'
  else Result := akUnsupported;
end;

{ JSON の中の、パス（'a.b.c'）の値を返す。無ければ nil }
function JPath(ARoot: TJSONData; const APath: string): TJSONData;
begin
  Result := nil;
  if ARoot = nil then Exit;
  try
    Result := ARoot.FindPath(APath);
  except
    Result := nil;
  end;
end;

{ 回答 JSON から、AI が返したエラー文を取り出す。読めなければ回答の先頭 500 文字 }
function ApiErrorMessage(ARoot: TJSONData; const ARaw: string): string;
var
  D: TJSONData;
begin
  Result := '';
  D := JPath(ARoot, 'error.message');                // Gemini・ChatGPT・Meta・Claude
  if (D <> nil) and (D.JSONType = jtString) then
    Result := D.AsString
  else
  begin
    D := JPath(ARoot, 'error');                      // Ollama
    if (D <> nil) and (D.JSONType = jtString) then
      Result := D.AsString;
  end;
  if Result = '' then
    Result := Copy(Trim(ARaw), 1, 500);
end;

{ ============================================================================
  回答 JSON の読み取り（AI ごと）
  ============================================================================ }

{ Gemini の回答 JSON（HTTP 2xx）から回答を取り出す。成功なら ceNone }
function ParseGemini(ARoot: TJSONData; out AAnswer, AUsage, AError: string): TCaiErrorKind;
var
  D, Cand, Parts, P: TJSONData;
  Reason: string;
  i: Integer;
begin
  AAnswer := '';
  AUsage := '';
  AError := '';

  D := JPath(ARoot, 'usageMetadata');
  if D <> nil then AUsage := D.AsJSON;

  { 質問そのものが拒まれた }
  D := JPath(ARoot, 'promptFeedback.blockReason');
  if D <> nil then
  begin
    AError := Format(CXT(sAiErrBlocked), [D.AsString]);
    Exit(ceBlocked);
  end;

  { 候補が無い }
  D := JPath(ARoot, 'candidates');
  if (D = nil) or (D.JSONType <> jtArray) or (D.Count = 0) then
  begin
    AError := Format(CXT(sAiErrBlocked), ['no candidates']);
    Exit(ceBlocked);
  end;
  Cand := D.Items[0];

  { 安全フィルターなどで止まった }
  Reason := '';
  D := JPath(Cand, 'finishReason');
  if D <> nil then Reason := D.AsString;
  if (Reason = 'SAFETY') or (Reason = 'RECITATION') or (Reason = 'PROHIBITED_CONTENT')
    or (Reason = 'BLOCKLIST') or (Reason = 'SPII') then
  begin
    AError := Format(CXT(sAiErrBlocked), [Reason]);
    Exit(ceBlocked);
  end;

  { 回答の文字：parts[*].text をつなげる（考えている途中の "thought": true は除く） }
  Parts := JPath(Cand, 'content.parts');
  if (Parts <> nil) and (Parts.JSONType = jtArray) then
    for i := 0 to Parts.Count - 1 do
    begin
      P := Parts.Items[i];
      D := JPath(P, 'thought');
      if (D <> nil) and (D.JSONType = jtBoolean) and D.AsBoolean then Continue;
      D := JPath(P, 'text');
      if (D <> nil) and (D.JSONType = jtString) then
        AAnswer := AAnswer + D.AsString;
    end;

  if AAnswer = '' then
  begin
    if Reason = '' then Reason := '-';
    AError := Format(CXT(sAiErrNoText), ['finishReason=' + Reason]);
    Exit(ceParse);
  end;
  Result := ceNone;
end;

{ 回答から <think>…</think>（qwen3 などが、考えた過程を本文に入れる）を除く。
  開きの無い </think> だけのとき（チャットの型が <think> を先に入れる場合）は、その前までを除く。
  閉じの無い <think> は、そこから後ろを除く }
function StripThink(const S: string): string;
const
  TAG_OPEN = '<think>';
  TAG_CLOSE = '</think>';
var
  P1, P2: Integer;
begin
  Result := S;
  P1 := Pos(TAG_OPEN, Result);
  P2 := Pos(TAG_CLOSE, Result);
  if (P2 > 0) and ((P1 = 0) or (P2 < P1)) then
    Delete(Result, 1, P2 + Length(TAG_CLOSE) - 1);
  repeat
    P1 := Pos(TAG_OPEN, Result);
    if P1 = 0 then Break;
    P2 := Pos(TAG_CLOSE, Result);
    if P2 < P1 then
    begin
      Delete(Result, P1, MaxInt);        // 閉じが無い：考えの途中で終わっている
      Break;
    end;
    Delete(Result, P1, P2 + Length(TAG_CLOSE) - P1);
  until False;
  Result := Trim(Result);
end;

{ Ollama（/api/chat・stream=false）の回答 JSON（HTTP 2xx）から回答を取り出す。成功なら ceNone }
function ParseOllama(ARoot: TJSONData; out AAnswer, AUsage, AError: string): TCaiErrorKind;
const
  USAGE_KEYS: array[0..3] of string =
    ('prompt_eval_count', 'eval_count', 'total_duration', 'load_duration');
var
  D: TJSONData;
  U: TJSONObject;
  Reason: string;
  i: Integer;
begin
  AAnswer := '';
  AUsage := '';
  AError := '';

  { 使用量：トークン数と、かかった時間（ナノ秒）をそのまま }
  U := TJSONObject.Create;
  try
    for i := Low(USAGE_KEYS) to High(USAGE_KEYS) do
    begin
      D := JPath(ARoot, USAGE_KEYS[i]);
      if D <> nil then U.Add(USAGE_KEYS[i], D.Clone);
    end;
    if U.Count > 0 then AUsage := U.AsJSON;
  finally
    U.Free;
  end;

  { 回答の文字：message.content（考えた過程の <think>…</think> は除く） }
  D := JPath(ARoot, 'message.content');
  if (D <> nil) and (D.JSONType = jtString) then
    AAnswer := StripThink(D.AsString);

  if AAnswer = '' then
  begin
    Reason := '-';
    D := JPath(ARoot, 'done_reason');
    if (D <> nil) and (D.JSONType = jtString) then Reason := D.AsString;
    AError := Format(CXT(sAiErrNoText), ['done_reason=' + Reason]);
    Exit(ceParse);
  end;
  Result := ceNone;
end;

{ Chat Completions（ChatGPT。同じ形の互換サーバーも）の回答 JSON（HTTP 2xx）から回答を取り出す。
  成功なら ceNone }
function ParseChatCompl(ARoot: TJSONData; out AAnswer, AUsage, AError: string): TCaiErrorKind;
var
  D, Choice, Msg, Parts, P: TJSONData;
  Reason: string;
  i: Integer;
begin
  AAnswer := '';
  AUsage := '';
  AError := '';

  D := JPath(ARoot, 'usage');
  if D <> nil then AUsage := D.AsJSON;

  D := JPath(ARoot, 'choices');
  if (D = nil) or (D.JSONType <> jtArray) or (D.Count = 0) then
  begin
    AError := Format(CXT(sAiErrNoText), ['no choices']);
    Exit(ceParse);
  end;
  Choice := D.Items[0];
  Msg := JPath(Choice, 'message');

  { AI が答えを拒んだ（message.refusal）、または内容のフィルターで止まった }
  D := JPath(Msg, 'refusal');
  if (D <> nil) and (D.JSONType = jtString) and (D.AsString <> '') then
  begin
    AError := Format(CXT(sAiErrBlocked), [D.AsString]);
    Exit(ceBlocked);
  end;
  Reason := '';
  D := JPath(Choice, 'finish_reason');
  if (D <> nil) and (D.JSONType = jtString) then Reason := D.AsString;
  if Reason = 'content_filter' then
  begin
    AError := Format(CXT(sAiErrBlocked), [Reason]);
    Exit(ceBlocked);
  end;

  { 回答の文字：message.content は、文字列。配列（text の部分の並び）で返す互換サーバーもある }
  D := JPath(Msg, 'content');
  if (D <> nil) and (D.JSONType = jtString) then
    AAnswer := Trim(D.AsString)
  else if (D <> nil) and (D.JSONType = jtArray) then
  begin
    Parts := D;
    for i := 0 to Parts.Count - 1 do
    begin
      P := JPath(Parts.Items[i], 'text');
      if (P <> nil) and (P.JSONType = jtString) then
        AAnswer := AAnswer + P.AsString;
    end;
    AAnswer := Trim(AAnswer);
  end;

  if AAnswer = '' then
  begin
    if Reason = '' then Reason := '-';
    AError := Format(CXT(sAiErrNoText), ['finish_reason=' + Reason]);
    Exit(ceParse);
  end;
  Result := ceNone;
end;

{ Claude（Messages API）の回答 JSON（HTTP 2xx）から回答を取り出す。成功なら ceNone。
  content[] のうち type が text の部分をつなげる（思考の部分 thinking は含めない）。
  stop_reason が refusal（拒否）なら ceBlocked（stop_details の category・explanation を添える） }
function ParseClaude(ARoot: TJSONData; out AAnswer, AUsage, AError: string): TCaiErrorKind;
var
  D, Blocks, T: TJSONData;
  Reason, Cat, Expl, Msg: string;
  i: Integer;
begin
  AAnswer := '';
  AUsage := '';
  AError := '';

  D := JPath(ARoot, 'usage');
  if D <> nil then AUsage := D.AsJSON;

  Reason := '';
  D := JPath(ARoot, 'stop_reason');
  if (D <> nil) and (D.JSONType = jtString) then Reason := D.AsString;

  { 拒否：安全のしくみが答えを止めた（HTTP 200 で stop_reason が refusal） }
  if Reason = 'refusal' then
  begin
    Cat := '';
    Expl := '';
    D := JPath(ARoot, 'stop_details.category');
    if (D <> nil) and (D.JSONType = jtString) then Cat := D.AsString;
    D := JPath(ARoot, 'stop_details.explanation');
    if (D <> nil) and (D.JSONType = jtString) then Expl := D.AsString;
    Msg := 'refusal';
    if Cat <> '' then Msg := Msg + ' (' + Cat + ')';
    if Expl <> '' then Msg := Msg + ' ' + Expl;
    AError := Format(CXT(sAiErrBlocked), [Msg]);
    Exit(ceBlocked);
  end;

  Blocks := JPath(ARoot, 'content');
  if (Blocks <> nil) and (Blocks.JSONType = jtArray) then
    for i := 0 to Blocks.Count - 1 do
    begin
      D := JPath(Blocks.Items[i], 'type');
      if (D <> nil) and (D.JSONType = jtString) and (D.AsString = 'text') then
      begin
        T := JPath(Blocks.Items[i], 'text');
        if (T <> nil) and (T.JSONType = jtString) then
          AAnswer := AAnswer + T.AsString;
      end;
    end;
  AAnswer := Trim(AAnswer);

  { 本文が空：考える途中で max_tokens に達した、など }
  if AAnswer = '' then
  begin
    if Reason = '' then Reason := '-';
    AError := Format(CXT(sAiErrNoText), ['stop_reason=' + Reason]);
    Exit(ceParse);
  end;
  Result := ceNone;
end;

{ ============================================================================
  TCaiHttpThread
  ============================================================================ }

constructor TCaiHttpThread.Create(AAIType: TCaiAIType; const AUrl, AHeaders: string;
  const ABody: RawByteString; ATimeoutSec, ARetryCount, ARetryWaitSec: Integer);
begin
  inherited Create(True);           // 作るだけ。Start は部品が呼ぶ
  FreeOnTerminate := False;
  FLock := TCriticalSection.Create;
  FNotes := TStringList.Create;
  FAIType := AAIType;
  FUrl := UTF8Decode(AUrl);
  FHeaders := UTF8Decode(AHeaders);
  FBody := ABody;
  FTimeoutSec := ATimeoutSec;
  FRetryCount := ARetryCount;
  FRetryWaitSec := ARetryWaitSec;
  ResKind := ceNone;
end;

destructor TCaiHttpThread.Destroy;
begin
  FNotes.Free;
  FLock.Free;
  inherited Destroy;
end;

{ 止める：要求ハンドルを閉じる（待っている WinHTTP の関数が失敗して戻る）。リトライの待ちも抜ける }
procedure TCaiHttpThread.Cancel;
begin
  FLock.Enter;
  try
    FCanceled := True;
    if FRequest <> nil then
    begin
      WinHttpCloseHandle(FRequest);
      FRequest := nil;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCaiHttpThread.AddNote(const S: string);
begin
  FLock.Enter;
  try
    FNotes.Add(S);
  finally
    FLock.Leave;
  end;
end;

function TCaiHttpThread.TakeNotes: string;
begin
  FLock.Enter;
  try
    Result := FNotes.Text;
    FNotes.Clear;
  finally
    FLock.Leave;
  end;
end;

{ AMs ミリ秒待つ。100ms ごとに止める合図を見る。止められたら False }
function TCaiHttpThread.WaitCancelable(AMs: Integer): Boolean;
var
  T0: QWord;
begin
  T0 := GetTickCount64;
  while GetTickCount64 - T0 < QWord(AMs) do
  begin
    if FCanceled then Exit(False);
    Sleep(100);
  end;
  Result := not FCanceled;
end;

{ 1 回送る。結果を Res* に入れる。戻り値は「やり直してよいか」 }
function TCaiHttpThread.SendOnce(out ARetryAfter: Integer): Boolean;
var
  UC: URL_COMPONENTS;
  Host, Path: UnicodeString;
  hSession, hConnect, hReq: HINTERNET;
  Flags, Status, Size, ReadLen: DWORD;
  RA: Integer;
  RAText: UnicodeString;
  Buf: array[0..65535] of Byte;
  Raw: RawByteString;
  Root: TJSONData;
  TimeoutMs: LongInt;
  Answer, Usage, ErrMsg: string;
  Kind: TCaiErrorKind;
  Retryable, IsTimeout: Boolean;
  DCode: TJSONData;

  { WinHTTP の失敗を Res* に入れる（止められた・待ち時間切れ・接続の失敗） }
  procedure SetWinErr(ACode: DWORD);
  begin
    if FCanceled or (ACode = ERROR_WINHTTP_OPERATION_CANCELLED) then
    begin
      ResKind := ceCanceled;
      ResError := CXT(sAiErrCanceled);
    end
    else if ACode = ERR_WINHTTP_TIMEOUT then
    begin
      ResKind := ceTimeout;
      ResError := Format(CXT(sAiErrTimeout), [FTimeoutSec]);
    end
    else
    begin
      ResKind := ceConnect;
      if FAIType = aiOllama then      // Ollama が起動していないことが多いので、確かめる点を添える
        ResError := Format(CXT(sAiErrOllamaConnect), [ACode])
      else
        ResError := Format(CXT(sAiErrConnect), [ACode, UTF8Encode(FUrl)]);
    end;
  end;

begin
  Result := False;
  ARetryAfter := 0;
  ResKind := ceNone;
  ResStatus := 0;
  ResAnswer := '';
  ResRaw := '';
  ResUsage := '';
  ResError := '';

  { URL を分ける（ホスト・ポート・パス） }
  FillChar(UC, SizeOf(UC), 0);
  UC.dwStructSize := SizeOf(UC);
  UC.dwHostNameLength := DWORD(-1);
  UC.dwUrlPathLength := DWORD(-1);
  UC.dwExtraInfoLength := DWORD(-1);
  if not WinHttpCrackUrl(PWideChar(FUrl), Length(FUrl), 0, @UC) then
  begin
    ResKind := ceSettings;
    ResError := Format(CXT(sAiErrConnect), [GetLastError, UTF8Encode(FUrl)]);
    Exit(False);
  end;
  SetString(Host, UC.lpszHostName, UC.dwHostNameLength);
  SetString(Path, UC.lpszUrlPath, UC.dwUrlPathLength);
  if UC.dwExtraInfoLength > 0 then
    Path := Path + Copy(UnicodeString(UC.lpszExtraInfo), 1, UC.dwExtraInfoLength);
  Flags := 0;
  if UC.nScheme = INTERNET_SCHEME_HTTPS then
    Flags := WINHTTP_FLAG_SECURE;

  hSession := nil;
  hConnect := nil;
  hReq := nil;
  try
    { セッション（プロキシは Windows の設定に従う） }
    hSession := WinHttpOpen(PWideChar(UnicodeString(USER_AGENT)),
      WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, nil, nil, 0);
    if hSession = nil then
      hSession := WinHttpOpen(PWideChar(UnicodeString(USER_AGENT)),
        WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, nil, nil, 0);
    if hSession = nil then
    begin
      SetWinErr(GetLastError);
      Exit(True);
    end;
    TimeoutMs := FTimeoutSec * 1000;
    WinHttpSetTimeouts(hSession, TimeoutMs, TimeoutMs, TimeoutMs, TimeoutMs);

    hConnect := WinHttpConnect(hSession, PWideChar(Host), UC.nPort, 0);
    if hConnect = nil then
    begin
      SetWinErr(GetLastError);
      Exit(ResKind in [ceConnect, ceTimeout]);
    end;

    hReq := WinHttpOpenRequest(hConnect, 'POST', PWideChar(Path), nil, nil, nil, Flags);
    if hReq = nil then
    begin
      SetWinErr(GetLastError);
      Exit(ResKind in [ceConnect, ceTimeout]);
    end;

    { 要求ハンドルを Cancel から閉じられるように渡す（もう止められていたら送らない） }
    FLock.Enter;
    try
      if FCanceled then
      begin
        WinHttpCloseHandle(hReq);
        hReq := nil;
      end
      else
        FRequest := hReq;
    finally
      FLock.Leave;
    end;
    if hReq = nil then
    begin
      SetWinErr(ERROR_WINHTTP_OPERATION_CANCELLED);
      Exit(False);
    end;

    { 送る・受ける }
    if not WinHttpSendRequest(hReq, PWideChar(FHeaders), Length(FHeaders),
      PChar(FBody), Length(FBody), Length(FBody), 0) then
    begin
      SetWinErr(GetLastError);
      Exit(ResKind in [ceConnect, ceTimeout]);
    end;
    if not WinHttpReceiveResponse(hReq, nil) then
    begin
      SetWinErr(GetLastError);
      Exit(ResKind in [ceConnect, ceTimeout]);
    end;

    { HTTP ステータス }
    Status := 0;
    Size := SizeOf(Status);
    WinHttpQueryHeaders(hReq, WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER,
      nil, @Status, @Size, nil);
    ResStatus := Status;

    { Retry-After（秒の数のときだけ使う）。項目番号（WINHTTP_QUERY_RETRY_AFTER）では読めなかったので、
      ヘッダーの名前で調べて、文字を数に直す }
    SetLength(RAText, 64);
    Size := Length(RAText) * SizeOf(WideChar);
    if WinHttpQueryHeaders(hReq, WINHTTP_QUERY_CUSTOM, 'Retry-After', PWideChar(RAText), @Size, nil) then
    begin
      SetLength(RAText, Size div SizeOf(WideChar));
      RA := StrToIntDef(Trim(UTF8Encode(RAText)), 0);
      if RA > 0 then ARetryAfter := RA;
    end;

    { 回答の本文を読む }
    Raw := '';
    repeat
      ReadLen := 0;
      if not WinHttpReadData(hReq, @Buf[0], SizeOf(Buf), @ReadLen) then
      begin
        SetWinErr(GetLastError);
        Exit(ResKind in [ceConnect, ceTimeout]);
      end;
      if ReadLen > 0 then
      begin
        SetLength(Raw, Length(Raw) + Integer(ReadLen));
        Move(Buf[0], Raw[Length(Raw) - Integer(ReadLen) + 1], ReadLen);
      end;
    until ReadLen = 0;
    SetCodePage(Raw, CP_UTF8, False);
    ResRaw := Raw;
  finally
    { 要求ハンドルは、Cancel がまだ閉じていなければ、ここで閉じる }
    FLock.Enter;
    try
      if FRequest <> nil then
      begin
        WinHttpCloseHandle(FRequest);
        FRequest := nil;
      end
      else if (hReq <> nil) and not FCanceled then
        WinHttpCloseHandle(hReq);
    finally
      FLock.Leave;
    end;
    if hConnect <> nil then WinHttpCloseHandle(hConnect);
    if hSession <> nil then WinHttpCloseHandle(hSession);
  end;

  { 回答 JSON を読む }
  Root := nil;
  try
    try
      Root := GetJSON(ResRaw);
    except
      Root := nil;
    end;

    { HTTP 2xx 以外：429・5xx（504 を除く）はやり直す。それ以外（400・401・402・403・404 など）はやり直さない。
      504 は、ゲートウェイが AI の処理を待ち切れなかったもので、同じ要求を送り直しても同じところで切れやすい
      （Meta の公式も、再送せずストリーミングにするよう案内している）。やり直さずに、対処を添えて返す }
    if (ResStatus < 200) or (ResStatus > 299) then
    begin
      ResKind := ceHttp;
      ResError := Format(CXT(sAiErrHttp), [ResStatus, ApiErrorMessage(Root, ResRaw)]);
      { Claude は、待ち時間切れを error.type が timeout_error で返す（504 のほか、500 のこともある）。
        504 と同じに扱う }
      IsTimeout := ResStatus = 504;
      DCode := JPath(Root, 'error.type');
      if (DCode <> nil) and (DCode.JSONType = jtString) and (DCode.AsString = 'timeout_error') then
        IsTimeout := True;
      if IsTimeout then
        ResError := ResError + ' ' + CXT(sAiHintGateway);
      Retryable := (ResStatus = 429) or ((ResStatus >= 500) and (ResStatus <= 599) and not IsTimeout);
      { 429 でも、待っても直らないものはやり直さない：
        ・利用枠・残高が無い（OpenAI の error.code が insufficient_quota）
        ・月の利用上限に達した（Claude の error.details.error_code が enforced_spend_limit_reached。
          retry-after も付かない） }
      if ResStatus = 429 then
      begin
        DCode := JPath(Root, 'error.code');
        if (DCode <> nil) and (DCode.JSONType = jtString) and (DCode.AsString = 'insufficient_quota') then
          Retryable := False;
        DCode := JPath(Root, 'error.details.error_code');
        if (DCode <> nil) and (DCode.JSONType = jtString) and (DCode.AsString = 'enforced_spend_limit_reached') then
          Retryable := False;
      end;
      Exit(Retryable);
    end;

    if (Root = nil) or (Root.JSONType <> jtObject) then
    begin
      ResKind := ceParse;
      ResError := Format(CXT(sAiErrParse), [Copy(Trim(ResRaw), 1, 500)]);
      Exit(False);
    end;

    Answer := '';
    Usage := '';
    ErrMsg := '';
    case FAIType of
      aiGemini: Kind := ParseGemini(Root, Answer, Usage, ErrMsg);
      aiOllama: Kind := ParseOllama(Root, Answer, Usage, ErrMsg);
      aiChatGPT, aiMeta: Kind := ParseChatCompl(Root, Answer, Usage, ErrMsg);
      aiClaude: Kind := ParseClaude(Root, Answer, Usage, ErrMsg);
    else
      Kind := ceNotSupported;
      ErrMsg := Format(CXT(sAiErrNotSupported), [AI_NAME[FAIType]]);
    end;
    ResKind := Kind;
    ResUsage := Usage;
    if Kind = ceNone then
      ResAnswer := Answer
    else
      ResError := ErrMsg;
    Result := False;
  finally
    Root.Free;
  end;
end;

{ 送る → だめならリトライ（429・5xx・接続の失敗・待ち時間切れ） }
procedure TCaiHttpThread.Execute;
var
  Attempt, Wait, RetryAfter: Integer;
  CanRetry: Boolean;
  Reason: string;
begin
  Attempt := 0;
  Wait := FRetryWaitSec;
  repeat
    try
      CanRetry := SendOnce(RetryAfter);
    except
      on E: Exception do
      begin
        ResKind := ceConnect;
        ResError := E.Message;
        CanRetry := False;
      end;
    end;
    if FCanceled then
    begin
      ResKind := ceCanceled;
      ResError := CXT(sAiErrCanceled);
      Exit;
    end;
    if (ResKind = ceNone) or not CanRetry or (Attempt >= FRetryCount) then Exit;

    { やり直す：待つ秒数を決めて、メインスレッドへ知らせる }
    Inc(Attempt);
    if ResKind = ceHttp then
      Reason := 'HTTP ' + IntToStr(ResStatus)
    else
      Reason := ResError;
    if (ResStatus = 429) and (RetryAfter > 0) then
    begin
      if RetryAfter > MAX_RETRY_AFTER then RetryAfter := MAX_RETRY_AFTER;
      Wait := RetryAfter;
    end;
    AddNote(Format(CXT(sAiMsgRetry), [Attempt, FRetryCount, Reason, Wait]));
    if not WaitCancelable(Wait * 1000) then
    begin
      ResKind := ceCanceled;
      ResError := CXT(sAiErrCanceled);
      Exit;
    end;
    Wait := Wait * 2;                // 次は倍
  until False;
end;

{ ============================================================================
  TCaiClient
  ============================================================================ }

constructor TCaiClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAIType := aiGemini;
  FPrompt := TStringList.Create;
  FFiles := TStringList.Create;
  FTimeoutSeconds := 0;
  FRetryCount := -1;
  FTemperature := -1;
  FMaxTokens := 0;
end;

{ 処理中に壊されたら（フォームが閉じられた など）、通信を止め、スレッドの終わりを待ってから消える。
  待ちのループには FAlive で知らせる（ループは Self に触らずに抜ける） }
destructor TCaiClient.Destroy;
begin
  if FThread <> nil then
  begin
    FThread.Cancel;
    FThread.WaitFor;
    FThread.Free;
    FThread := nil;
  end;
  if FAlive <> nil then
    FAlive^ := False;
  FIni.Free;
  FFiles.Free;
  FPrompt.Free;
  inherited Destroy;
end;

procedure TCaiClient.SetAIType(AValue: TCaiAIType);
begin
  if FAIType = AValue then Exit;
  if FBusy then
  begin
    SetError(ceBusy, CXT(sAiErrAITypeBusy));
    Exit;
  end;
  FAIType := AValue;
end;

function TCaiClient.GetPrompt: TStrings;
begin
  Result := FPrompt;
end;

function TCaiClient.GetFiles: TStrings;
begin
  Result := FFiles;
end;

procedure TCaiClient.SetPrompt(AValue: TStrings);
begin
  FPrompt.Assign(AValue);
end;

procedure TCaiClient.SetFiles(AValue: TStrings);
begin
  FFiles.Assign(AValue);
end;

procedure TCaiClient.SetError(AKind: TCaiErrorKind; const AMsg: string; AStatus: Integer);
begin
  FLastErrorKind := AKind;
  FLastError := AMsg;
  FLastStatusCode := AStatus;
end;

procedure TCaiClient.DoMsg(const AText: string);
begin
  if Assigned(FOnMessage) then
    FOnMessage(Self, Stamp(AText));
end;

procedure TCaiClient.ReloadSettings;
begin
  FreeAndNil(FIni);
  FIniLoaded := False;
end;

procedure TCaiClient.Cancel;
begin
  if FThread <> nil then
    FThread.Cancel;
end;

function TCaiClient.AskAndWaitText(const AText: string): string;
begin
  Result := DoAsk(AText, False, True);
end;

function TCaiClient.AskAndWaitMD(const AText: string): string;
begin
  Result := DoAsk(AText, True, True);
end;

{ 疎通確認：Prompt・Files は使わずに、決まった文だけを送る }
function TCaiClient.TestConnection: Boolean;
begin
  Result := DoAsk(CXT(sAiTestPrompt), False, False) <> '';
end;

{ AskAndWaitText・AskAndWaitMD の流れ（設計書 4.5）。
  AUseInputs=False のときは Prompt・Files を使わない（TestConnection） }
function TCaiClient.DoAsk(const AText: string; AMarkdown, AUseInputs: Boolean): string;
var
  Alive: Boolean;
  Thr: TCaiHttpThread;
  UsePrompt, UseFiles, Sec: TStringList;
  Section, IniFile, Url, ModelName, EnvName, ApiKey, Body, Instr, S, Mime, Notes,
    Headers, LogFolder, LogText, MaxParam, WorkspaceId: string;
  Data: RawByteString;
  ReqBody, LogBody: RawByteString;
  Timeout, Retry, RetryWait, i, j: Integer;
  Total: Int64;
  StartTick: QWord;
  StartTime: TDateTime;
  Bins: array of record
    Name: string;
    Mime: string;
    B64: string;
    Size: Integer;
  end;

  { 失敗：LastError* を入れて、[エラー] を知らせる }
  procedure Fail(AKind: TCaiErrorKind; const AMsg: string; AStatus: Integer = 0);
  begin
    SetError(AKind, AMsg, AStatus);
    DoMsg(Format(CXT(sAiMsgError), [AMsg]));
  end;

  { Gemini の要求 JSON を作る。AWithData=False のときは、添付の base64 を長さだけにする（ログ用） }
  function BuildGemini(AWithData: Boolean): RawByteString;
  var
    Root, Sys, Content, Part, InlineData, Gen: TJSONObject;
    Parts, SysParts, Contents: TJSONArray;
    k: Integer;
  begin
    Root := TJSONObject.Create;
    try
      { システム指示：回答の形 }
      SysParts := TJSONArray.Create;
      SysParts.Add(TJSONObject.Create(['text', Instr]));
      Sys := TJSONObject.Create;
      Sys.Add('parts', SysParts);
      Root.Add('systemInstruction', Sys);

      { 本文と添付 }
      Parts := TJSONArray.Create;
      Parts.Add(TJSONObject.Create(['text', Body]));
      for k := 0 to High(Bins) do
      begin
        InlineData := TJSONObject.Create;
        InlineData.Add('mime_type', Bins[k].Mime);
        if AWithData then
          InlineData.Add('data', Bins[k].B64)
        else
          InlineData.Add('data', Format('<base64 %d bytes>', [Bins[k].Size]));
        Part := TJSONObject.Create;
        Part.Add('inline_data', InlineData);
        Parts.Add(Part);
      end;
      Content := TJSONObject.Create;
      Content.Add('role', 'user');
      Content.Add('parts', Parts);
      Contents := TJSONArray.Create;
      Contents.Add(Content);
      Root.Add('contents', Contents);

      { 指定があるときだけ generationConfig を入れる }
      if (FTemperature >= 0) or (FMaxTokens > 0) then
      begin
        Gen := TJSONObject.Create;
        if FTemperature >= 0 then Gen.Add('temperature', FTemperature);
        if FMaxTokens > 0 then Gen.Add('maxOutputTokens', FMaxTokens);
        Root.Add('generationConfig', Gen);
      end;

      Result := Root.AsJSON;
      SetCodePage(Result, CP_UTF8, False);
    finally
      Root.Free;
    end;
  end;

  { Ollama（/api/chat）の要求 JSON を作る。画像は user の images に base64 で入れる。
    AWithData=False のときは、画像の base64 を長さだけにする（ログ用） }
  function BuildOllama(AWithData: Boolean): RawByteString;
  var
    Root, Sys, Usr, Opt: TJSONObject;
    Msgs, Imgs: TJSONArray;
    k: Integer;
  begin
    Root := TJSONObject.Create;
    try
      Root.Add('model', ModelName);
      Root.Add('stream', False);            // 1 回の回答にまとめて返してもらう

      Msgs := TJSONArray.Create;
      Sys := TJSONObject.Create;
      Sys.Add('role', 'system');
      Sys.Add('content', Instr);
      Msgs.Add(Sys);

      Usr := TJSONObject.Create;
      Usr.Add('role', 'user');
      Usr.Add('content', Body);
      if Length(Bins) > 0 then
      begin
        Imgs := TJSONArray.Create;
        for k := 0 to High(Bins) do
          if AWithData then
            Imgs.Add(Bins[k].B64)
          else
            Imgs.Add(Format('<base64 %d bytes>', [Bins[k].Size]));
        Usr.Add('images', Imgs);
      end;
      Msgs.Add(Usr);
      Root.Add('messages', Msgs);

      { 指定があるときだけ options を入れる }
      if (FTemperature >= 0) or (FMaxTokens > 0) then
      begin
        Opt := TJSONObject.Create;
        if FTemperature >= 0 then Opt.Add('temperature', FTemperature);
        if FMaxTokens > 0 then Opt.Add('num_predict', FMaxTokens);
        Root.Add('options', Opt);
      end;

      Result := Root.AsJSON;
      SetCodePage(Result, CP_UTF8, False);
    finally
      Root.Free;
    end;
  end;

  { Chat Completions（ChatGPT。同じ形の互換サーバーも）の要求 JSON を作る。
    画像は image_url、PDF は file の部分に、data: の形（base64）で入れる。
    AWithData=False のときは、添付の base64 を長さだけにする（ログ用）。
    回答の長さの上限は、ini の MaxTokensParam の名前（既定 max_completion_tokens）で送る }
  function BuildChatCompl(AWithData: Boolean): RawByteString;
  var
    Root, Sys, Usr, Part, Img, Fil: TJSONObject;
    Msgs, UParts: TJSONArray;
    k: Integer;
    Data64: string;
  begin
    Root := TJSONObject.Create;
    try
      Root.Add('model', ModelName);

      Msgs := TJSONArray.Create;
      Sys := TJSONObject.Create;
      Sys.Add('role', 'system');
      Sys.Add('content', Instr);
      Msgs.Add(Sys);

      { user：本文（Prompt の中身＋AText＋テキストの添付）と、画像・PDF }
      UParts := TJSONArray.Create;
      Part := TJSONObject.Create;
      Part.Add('type', 'text');
      Part.Add('text', Body);
      UParts.Add(Part);
      for k := 0 to High(Bins) do
      begin
        if AWithData then
          Data64 := Bins[k].B64
        else
          Data64 := Format('<base64 %d bytes>', [Bins[k].Size]);
        Part := TJSONObject.Create;
        if Bins[k].Mime = 'application/pdf' then
        begin
          Fil := TJSONObject.Create;
          Fil.Add('filename', Bins[k].Name);
          Fil.Add('file_data', 'data:application/pdf;base64,' + Data64);
          Part.Add('type', 'file');
          Part.Add('file', Fil);
        end
        else
        begin
          Img := TJSONObject.Create;
          Img.Add('url', 'data:' + Bins[k].Mime + ';base64,' + Data64);
          Part.Add('type', 'image_url');
          Part.Add('image_url', Img);
        end;
        UParts.Add(Part);
      end;
      Usr := TJSONObject.Create;
      Usr.Add('role', 'user');
      Usr.Add('content', UParts);
      Msgs.Add(Usr);
      Root.Add('messages', Msgs);

      { 指定があるときだけ入れる }
      if FTemperature >= 0 then Root.Add('temperature', FTemperature);
      if FMaxTokens > 0 then Root.Add(MaxParam, FMaxTokens);

      Result := Root.AsJSON;
      SetCodePage(Result, CP_UTF8, False);
    finally
      Root.Free;
    end;
  end;

  { Claude（Messages API）の要求 JSON を作る。max_tokens は必須（MaxTokens が 0 なら CLAUDE_DEF_MAX_TOKENS）。
    画像は image、PDF は document の部分に base64 で入れ、本文（text）の前に置く（公式の勧め）。
    Temperature は送らない（anthropic-version 2026-10-21 では temperature・top_p・top_k が、どのモデルでも 400）。
    AWithData=False のときは、添付の base64 を長さだけにする（ログ用） }
  function BuildClaude(AWithData: Boolean): RawByteString;
  var
    Root, Usr, Part, Src: TJSONObject;
    Msgs, UParts: TJSONArray;
    k, MaxT: Integer;
    Data64: string;
  begin
    Root := TJSONObject.Create;
    try
      Root.Add('model', ModelName);
      if FMaxTokens > 0 then MaxT := FMaxTokens else MaxT := CLAUDE_DEF_MAX_TOKENS;
      Root.Add('max_tokens', MaxT);
      Root.Add('system', Instr);

      UParts := TJSONArray.Create;
      for k := 0 to High(Bins) do
      begin
        if AWithData then
          Data64 := Bins[k].B64
        else
          Data64 := Format('<base64 %d bytes>', [Bins[k].Size]);
        Src := TJSONObject.Create;
        Src.Add('type', 'base64');
        Src.Add('media_type', Bins[k].Mime);
        Src.Add('data', Data64);
        Part := TJSONObject.Create;
        if Bins[k].Mime = 'application/pdf' then
          Part.Add('type', 'document')
        else
          Part.Add('type', 'image');
        Part.Add('source', Src);
        UParts.Add(Part);
      end;
      Part := TJSONObject.Create;
      Part.Add('type', 'text');
      Part.Add('text', Body);
      UParts.Add(Part);

      Usr := TJSONObject.Create;
      Usr.Add('role', 'user');
      Usr.Add('content', UParts);
      Msgs := TJSONArray.Create;
      Msgs.Add(Usr);
      Root.Add('messages', Msgs);

      Result := Root.AsJSON;
      SetCodePage(Result, CP_UTF8, False);
    finally
      Root.Free;
    end;
  end;

  { ini の値の中の %キー% を、同じセクションの値に置き換える（%Model% は使うモデル名） }
  function ExpandVars(const AValue: string): string;
  var
    k: Integer;
    Key: string;
  begin
    Result := StringReplace(AValue, '%Model%', ModelName, [rfReplaceAll, rfIgnoreCase]);
    for k := 0 to Sec.Count - 1 do
    begin
      Key := Sec.Names[k];
      if (Key <> '') and not SameText(Key, 'Model') then
        Result := StringReplace(Result, '%' + Key + '%', Sec.ValueFromIndex[k],
          [rfReplaceAll, rfIgnoreCase]);
    end;
  end;

  { スレッドがためた再送の知らせを OnMessage へ出す }
  procedure FlushNotes;
  var
    SL: TStringList;
    k: Integer;
  begin
    Notes := Thr.TakeNotes;
    if Notes = '' then Exit;
    SL := TStringList.Create;
    try
      SL.Text := Notes;
      for k := 0 to SL.Count - 1 do
        DoMsg(SL[k]);
    finally
      SL.Free;
    end;
  end;

  { ログを書く（書けなくても結果には影響させない） }
  procedure WriteLog(const AText: string);
  var
    FN: string;
    SL: TStringList;
  begin
    if LogFolder = '' then Exit;
    try
      ForceDirectories(LogFolder);
      FN := IncludeTrailingPathDelimiter(LogFolder) + 'CaiClient_' +
        FormatDateTime('yyyymmdd_hhnnss_zzz', Now) + '.log';
      SL := TStringList.Create;
      try
        SL.Text := AText;
        SL.SaveToFile(FN);
      finally
        SL.Free;
      end;
    except
      { 何もしない }
    end;
  end;

begin
  Result := '';

  { 1. 処理中なら断る（今の処理には触らない） }
  if FBusy then
  begin
    FLastErrorKind := ceBusy;
    FLastError := CXT(sAiErrBusy);
    Exit;
  end;

  { 2. 前の結果を空にして、処理中にする }
  SetError(ceNone, '');
  FLastUsage := '';
  FLastResponse := '';
  FBusy := True;
  Alive := True;
  FAlive := @Alive;
  UsePrompt := TStringList.Create;
  UseFiles := TStringList.Create;
  Sec := TStringList.Create;
  try
    { 3. 入力を確かめる }
    if AUseInputs then
    begin
      CopyNonBlank(FPrompt, UsePrompt);
      CopyNonBlank(FFiles, UseFiles);
    end;
    if (Trim(AText) = '') and (UsePrompt.Count = 0) then
    begin
      Fail(ceInput, CXT(sAiErrInputEmpty));
      Exit;
    end;
    for i := 0 to UsePrompt.Count - 1 do
      if not FileExists(UsePrompt[i]) then
      begin
        Fail(ceInput, Format(CXT(sAiErrPromptMissing), [UsePrompt[i]]));
        Exit;
      end;
    for i := 0 to UseFiles.Count - 1 do
      if not FileExists(UseFiles[i]) then
      begin
        Fail(ceFile, Format(CXT(sAiErrFileMissing), [UseFiles[i]]));
        Exit;
      end;

    { 5 つの AI のどれでも動く。まだ作っていない AI が増えたときのために、確かめを残す }
    if not (FAIType in [aiGemini, aiOllama, aiChatGPT, aiMeta, aiClaude]) then
    begin
      Fail(ceNotSupported, Format(CXT(sAiErrNotSupported), [AI_NAME[FAIType]]));
      Exit;
    end;

    { 4. ini を読む（最初の 1 回）。AI のセクションから Url・Model、環境変数から API キー }
    if not FIniLoaded then
    begin
      IniFile := ExtractFilePath(ParamStr(0)) + INI_NAME;
      if not FileExists(IniFile) then
      begin
        Fail(ceSettings, CXT(sErrIniMissing) + IniFile);
        Exit;
      end;
      FIni := TMemIniFile.Create(IniFile);
      FIniLoaded := True;
    end;
    Section := AI_SECTION[FAIType];
    FIni.ReadSectionValues(Section, Sec);
    for i := 0 to Sec.Count - 1 do
      Sec.ValueFromIndex[i] := Trim(Sec.ValueFromIndex[i]);

    ModelName := Trim(FModel);
    if ModelName = '' then
      ModelName := Sec.Values['Model'];
    if ModelName = '' then
    begin
      Fail(ceSettings, Format(CXT(sAiErrIniKey), [Section, 'Model']));
      Exit;
    end;
    Url := ExpandVars(Sec.Values['Url']);
    if Url = '' then
    begin
      Fail(ceSettings, Format(CXT(sAiErrIniKey), [Section, 'Url']));
      Exit;
    end;
    { 回答の長さの上限を送る項目名（任意）。Chat Completions の新しいモデルは max_completion_tokens。
      max_tokens しか知らない互換サーバー（Ollama の /v1 など）では、ini で max_tokens にする }
    MaxParam := Sec.Values['MaxTokensParam'];
    if MaxParam = '' then MaxParam := 'max_completion_tokens';
    { ワークスペースに紐づいていない Claude のキーは、anthropic-workspace-id ヘッダーが要る（任意） }
    WorkspaceId := Sec.Values['WorkspaceId'];
    EnvName := Sec.Values['ApiKeyEnv'];
    ApiKey := '';
    if FAIType <> aiOllama then
    begin
      if EnvName = '' then
      begin
        Fail(ceSettings, Format(CXT(sAiErrIniKey), [Section, 'ApiKeyEnv']));
        Exit;
      end;
      ApiKey := Trim(GetEnvironmentVariable(EnvName));
      if ApiKey = '' then
      begin
        Fail(ceSettings, Format(CXT(sAiErrEnvMissing), [EnvName, Section]));
        Exit;
      end;
    end;

    Timeout := FTimeoutSeconds;
    if Timeout <= 0 then
      Timeout := FIni.ReadInteger(INI_COMMON, 'TimeoutSeconds', DEF_TIMEOUT);
    if Timeout <= 0 then Timeout := DEF_TIMEOUT;
    Retry := FRetryCount;
    if Retry < 0 then
      Retry := FIni.ReadInteger(INI_COMMON, 'RetryCount', DEF_RETRY);
    if Retry < 0 then Retry := 0;
    RetryWait := FIni.ReadInteger(INI_COMMON, 'RetryWaitSeconds', DEF_RETRY_WAIT);
    if RetryWait < 1 then RetryWait := 1;
    LogFolder := Trim(FIni.ReadString(INI_COMMON, 'LogFolder', ''));
    if (LogFolder <> '') and (ExtractFileDrive(LogFolder) = '') then
      LogFolder := ExtractFilePath(ParamStr(0)) + LogFolder;

    { 5. 本文：Prompt の中身（空行でつなぐ）→ 空行 → AText → テキストの添付 }
    Body := '';
    for i := 0 to UsePrompt.Count - 1 do
    begin
      if not ReadUtf8File(UsePrompt[i], S) then
      begin
        Fail(ceInput, Format(CXT(sAiErrFileRead), [UsePrompt[i]]));
        Exit;
      end;
      if Body <> '' then Body := Body + LineEnding + LineEnding;
      Body := Body + S;
    end;
    if Trim(AText) <> '' then
    begin
      if Body <> '' then Body := Body + LineEnding + LineEnding;
      Body := Body + AText;
    end;

    { 6. 添付：テキストは本文につなぎ、PDF・画像は base64 にする }
    Total := 0;
    SetLength(Bins, 0);
    for i := 0 to UseFiles.Count - 1 do
      case AttachKindOf(UseFiles[i], Mime) of
        akText:
          begin
            if not ReadUtf8File(UseFiles[i], S) then
            begin
              Fail(ceFile, Format(CXT(sAiErrFileRead), [UseFiles[i]]));
              Exit;
            end;
            Inc(Total, Length(S));
            Body := Body + LineEnding + LineEnding +
              Format(CXT(sAiFileHeader), [ExtractFileName(UseFiles[i])]) + LineEnding + S;
          end;
        akBinary:
          begin
            { Ollama は画像だけ受ける（PDF は送れない） }
            if (FAIType = aiOllama) and (Copy(Mime, 1, 6) <> 'image/') then
            begin
              Fail(ceFile, Format(CXT(sAiErrFileAI), [ExtractFileName(UseFiles[i])]));
              Exit;
            end;
            if not ReadFileBytes(UseFiles[i], Data) then
            begin
              Fail(ceFile, Format(CXT(sAiErrFileRead), [UseFiles[i]]));
              Exit;
            end;
            Inc(Total, Length(Data));
            j := Length(Bins);
            SetLength(Bins, j + 1);
            Bins[j].Name := ExtractFileName(UseFiles[i]);
            Bins[j].Mime := Mime;
            Bins[j].Size := Length(Data);
            Bins[j].B64 := EncodeStringBase64(Data);
          end;
      else
        Fail(ceFile, Format(CXT(sAiErrFileType), [ExtractFileName(UseFiles[i])]));
        Exit;
      end;
    if Total > Int64(MAX_ATTACH_MB) * 1024 * 1024 then
    begin
      Fail(ceFile, Format(CXT(sAiErrFileSize), [MAX_ATTACH_MB]));
      Exit;
    end;

    { 7. 要求を組み立てる（回答の形の指示はシステム指示へ） }
    if AMarkdown then Instr := CXT(sAiInstrMD) else Instr := CXT(sAiInstrText);
    Headers := 'Content-Type: application/json; charset=utf-8';
    LogBody := '';
    case FAIType of
      aiGemini:
        begin
          ReqBody := BuildGemini(True);
          Headers := Headers + #13#10 + 'x-goog-api-key: ' + ApiKey;
          if LogFolder <> '' then LogBody := BuildGemini(False);
        end;
      aiOllama:                               // キーは使わない
        begin
          ReqBody := BuildOllama(True);
          if LogFolder <> '' then LogBody := BuildOllama(False);
        end;
      aiClaude:
        begin
          ReqBody := BuildClaude(True);
          Headers := Headers + #13#10 + 'x-api-key: ' + ApiKey + #13#10 +
            'anthropic-version: ' + CLAUDE_API_VERSION;
          if WorkspaceId <> '' then
            Headers := Headers + #13#10 + 'anthropic-workspace-id: ' + WorkspaceId;
          if LogFolder <> '' then LogBody := BuildClaude(False);
        end;
      aiChatGPT, aiMeta:                      // どちらも Chat Completions（Authorization: Bearer）
        begin
          ReqBody := BuildChatCompl(True);
          Headers := Headers + #13#10 + 'Authorization: Bearer ' + ApiKey;
          if LogFolder <> '' then LogBody := BuildChatCompl(False);
        end;
    end;

    { 8. [開始]。通信用スレッドを起こす }
    DoMsg(Format(CXT(sAiMsgStart), [AI_NAME[FAIType], ModelName]));
    StartTick := GetTickCount64;
    StartTime := Now;
    Thr := TCaiHttpThread.Create(FAIType, Url, Headers, ReqBody, Timeout, Retry, RetryWait);
    FThread := Thr;
    Thr.Start;

    { 9. 終わるまで待つ（画面は動かす）。再送の知らせがあれば OnMessage }
    while Alive and not Thr.Finished do
    begin
      Application.ProcessMessages;
      if not Alive then Break;
      FlushNotes;
      if Alive and not Thr.Finished then
        Sleep(10);
    end;
    { 待っている間に部品が壊された：Self には触らずに抜ける（スレッドはデストラクタが片づけた） }
    if not Alive then Exit('');

    Thr.WaitFor;
    FlushNotes;

    { 10. 結果を入れる }
    FLastStatusCode := Thr.ResStatus;
    FLastResponse := Thr.ResRaw;
    FLastUsage := Thr.ResUsage;
    if Thr.ResKind = ceNone then
    begin
      { 待つ間の二重呼び出し（ceBusy）で LastError が入っていても、成功なら空に戻す }
      FLastErrorKind := ceNone;
      FLastError := '';
      Result := Thr.ResAnswer;
      DoMsg(Format(CXT(sAiMsgDone), [(GetTickCount64 - StartTick) / 1000]));
    end
    else
      Fail(Thr.ResKind, Thr.ResError, Thr.ResStatus);

    { 11. ログ（API キーは入れない。添付の base64 は長さだけ） }
    if LogFolder <> '' then
    begin
      LogText :=
        'Start   : ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', StartTime) + LineEnding +
        'AI      : ' + AI_NAME[FAIType] + LineEnding +
        'Model   : ' + ModelName + LineEnding +
        'Url     : ' + Url + LineEnding +
        'Seconds : ' + FormatFloat('0.0', (GetTickCount64 - StartTick) / 1000) + LineEnding +
        'Status  : ' + IntToStr(Thr.ResStatus) + LineEnding +
        'Error   : ' + Thr.ResError + LineEnding +
        LineEnding + '--- request ---' + LineEnding + LogBody + LineEnding +
        LineEnding + '--- response ---' + LineEnding + Thr.ResRaw + LineEnding;
      WriteLog(LogText);
    end;
  finally
    if Alive then
    begin
      if FThread <> nil then
      begin
        FThread.Free;
        FThread := nil;
      end;
      FAlive := nil;
      FBusy := False;
      Sec.Free;
      UseFiles.Free;
      UsePrompt.Free;
    end
    else
    begin
      { 部品は壊された。ローカルの一覧だけ片づける }
      Sec.Free;
      UseFiles.Free;
      UsePrompt.Free;
    end;
  end;
end;

end.
