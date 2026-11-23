{ tcAiClient - TCaiClient の動作確認（自動で順に試し、results.txt に書いて終わる）
  起動すると、フォームを出して FormShow から試験を順に行う。
  待っている間に画面が動くか（タイマーが進むか）も数える。 }
program tcAiClientTest;   // tcAiClient だと、大文字小文字を区別しないため TCaiClient とぶつかる

{$mode objfpc}{$H+}

uses
  Interfaces, Windows, Classes, SysUtils, Forms, StdCtrls, ExtCtrls, Controls,
  uCaiClient;

type
  TTestForm = class(TForm)
  private
    FMemo: TMemo;
    FAi: TCaiClient;
    FTick: TTimer;          // 待っている間に画面（メッセージ）が回っているかを数える
    FTicks: Integer;
    FCancelTimer: TTimer;   // Cancel を試す
    FBusyTimer: TTimer;     // 処理中の二重呼び出しを試す
    FBusyResult: string;
    FBusyKind: TCaiErrorKind;
    FLines: TStringList;
    FPass, FFail: Integer;
    procedure Log(const S: string);
    procedure Check(const AName: string; AOK: Boolean; const ADetail: string);
    procedure AiMessage(Sender: TObject; const AMsg: string);
    procedure TickTimer(Sender: TObject);
    procedure CancelTimerFire(Sender: TObject);
    procedure BusyTimerFire(Sender: TObject);
    procedure RunAll(Data: PtrInt);
    function Short(const S: string): string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DoShow; override;
  end;

const
  KIND_NAME: array[TCaiErrorKind] of string = ('ceNone', 'ceSettings', 'ceInput', 'ceFile',
    'ceConnect', 'ceTimeout', 'ceHttp', 'ceBlocked', 'ceParse', 'ceCanceled', 'ceBusy',
    'ceNotSupported');

constructor TTestForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'tcAiClient';
  Width := 900;
  Height := 600;
  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alClient;
  FMemo.ScrollBars := ssBoth;
  FAi := TCaiClient.Create(Self);
  FAi.OnMessage := @AiMessage;
  FTick := TTimer.Create(Self);
  FTick.Interval := 50;
  FTick.OnTimer := @TickTimer;
  FCancelTimer := TTimer.Create(Self);
  FCancelTimer.Enabled := False;
  FCancelTimer.OnTimer := @CancelTimerFire;
  FBusyTimer := TTimer.Create(Self);
  FBusyTimer.Enabled := False;
  FBusyTimer.OnTimer := @BusyTimerFire;
  FLines := TStringList.Create;
end;

destructor TTestForm.Destroy;
begin
  FLines.Free;
  inherited Destroy;
end;

procedure TTestForm.DoShow;
begin
  inherited DoShow;
  Application.QueueAsyncCall(@RunAll, 0);
end;

function TTestForm.Short(const S: string): string;
begin
  Result := StringReplace(StringReplace(S, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
  if Length(Result) > 160 then Result := Copy(Result, 1, 160) + '…';
end;

procedure TTestForm.Log(const S: string);
begin
  FLines.Add(S);
  FMemo.Lines.Add(S);
end;

procedure TTestForm.Check(const AName: string; AOK: Boolean; const ADetail: string);
begin
  if AOK then
  begin
    Inc(FPass);
    Log('[OK]   ' + AName + ' : ' + ADetail);
  end
  else
  begin
    Inc(FFail);
    Log('[NG]   ' + AName + ' : ' + ADetail);
  end;
end;

procedure TTestForm.AiMessage(Sender: TObject; const AMsg: string);
begin
  Log('       msg: ' + AMsg);
end;

procedure TTestForm.TickTimer(Sender: TObject);
begin
  Inc(FTicks);
end;

procedure TTestForm.CancelTimerFire(Sender: TObject);
begin
  FCancelTimer.Enabled := False;
  FAi.Cancel;
end;

procedure TTestForm.BusyTimerFire(Sender: TObject);
begin
  FBusyTimer.Enabled := False;
  FBusyResult := FAi.AskAndWaitText('二重呼び出し');
  FBusyKind := FAi.LastErrorKind;
end;

procedure TTestForm.RunAll(Data: PtrInt);
var
  S, Dir, SaveKey: string;
  T0: QWord;
  OK: Boolean;
begin
  Dir := ExtractFilePath(ParamStr(0));
  Log('=== TCaiClient test ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ===');

  { 1. 入力が空 → ceInput }
  S := FAi.AskAndWaitText('');
  Check('T01 入力が空', (S = '') and (FAi.LastErrorKind = ceInput),
    KIND_NAME[FAi.LastErrorKind] + ' ' + FAi.LastError);

  { 2. Prompt のファイルが無い → ceInput }
  FAi.Prompt.Text := Dir + 'no_such_prompt.txt';
  S := FAi.AskAndWaitText('こんにちは');
  Check('T02 Prompt のファイル無し', (S = '') and (FAi.LastErrorKind = ceInput),
    KIND_NAME[FAi.LastErrorKind] + ' ' + FAi.LastError);
  FAi.Prompt.Clear;

  { 3. 送れない形式の添付 → ceFile }
  FAi.Files.Text := Dir + 'tcAiClient.lpi';   // 拡張子 .lpi は送れない
  S := FAi.AskAndWaitText('これは何？');
  Check('T03 送れない形式', (S = '') and (FAi.LastErrorKind = ceFile),
    KIND_NAME[FAi.LastErrorKind] + ' ' + FAi.LastError);
  FAi.Files.Clear;

  { 4. まだ対応していない AI → ceNotSupported }
  FAi.AIType := aiClaude;
  S := FAi.AskAndWaitText('こんにちは');
  Check('T04 未対応の AI', (S = '') and (FAi.LastErrorKind = ceNotSupported),
    KIND_NAME[FAi.LastErrorKind] + ' ' + FAi.LastError);
  FAi.AIType := aiGemini;

  { 5. 環境変数が無い → ceSettings（このプロセスの環境変数を一時的に消す） }
  SaveKey := GetEnvironmentVariable('GEMINI_API_KEY');
  SetEnvironmentVariable('GEMINI_API_KEY', '');
  S := FAi.AskAndWaitText('こんにちは');
  Check('T05 環境変数なし', (S = '') and (FAi.LastErrorKind = ceSettings),
    KIND_NAME[FAi.LastErrorKind] + ' ' + FAi.LastError);
  SetEnvironmentVariable('GEMINI_API_KEY', PChar(SaveKey));
  if SaveKey = '' then
  begin
    Log('GEMINI_API_KEY がこのプロセスに無いため、通信の試験はしません');
    Exit;
  end;

  { 6. 疎通確認 }
  FTicks := 0;
  T0 := GetTickCount64;
  OK := FAi.TestConnection;            // 先に呼ぶ（引数の評価順で、結果より前の値を書かないように）
  Check('T06 TestConnection', OK,
    Format('%s %s ticks=%d %.1fs', [KIND_NAME[FAi.LastErrorKind], FAi.LastError, FTicks,
      (GetTickCount64 - T0) / 1000]));
  Check('T07 待つ間も画面が動く', FTicks > 5, Format('タイマーが %d 回動いた', [FTicks]));

  { 8. AskAndWaitText（Markdown の記号なし） }
  S := FAi.AskAndWaitText('日本の首都と、その人口のおおよその数を教えて。');
  Check('T08 AskAndWaitText', S <> '', Short(S) + ' / ' + FAi.LastError);
  Log('       usage: ' + FAi.LastUsage);

  { 9. AskAndWaitMD }
  S := FAi.AskAndWaitMD('Pascal の長所を3つ、見出しと箇条書きで。');
  Check('T09 AskAndWaitMD', (S <> '') and ((Pos('#', S) > 0) or (Pos('- ', S) > 0) or (Pos('* ', S) > 0)),
    Short(S) + ' / ' + FAi.LastError);

  { 10. Prompt のファイル＋CSV の添付 }
  FAi.Prompt.Text := Dir + 'prompt_rule.txt';
  FAi.Files.Text := Dir + 'sample.csv';
  S := FAi.AskAndWaitText('この表の、商品ごとの金額の合計を教えて。');
  Check('T10 Prompt＋CSV 添付', (S <> '') and ((Pos('2700', S) > 0) or (Pos('2,700', S) > 0) or (Pos('二千七百', S) > 0))
    and ((Pos('1500', S) > 0) or (Pos('1,500', S) > 0) or (Pos('千五百', S) > 0)),
    Short(S) + ' / ' + FAi.LastError);
  FAi.Prompt.Clear;

  { 11. 画像の添付（PNG） }
  FAi.Files.Text := Dir + 'icon.png';
  S := FAi.AskAndWaitText('この画像に書いてあるアルファベットを答えて。');
  Check('T11 PNG 添付', (S <> '') and (Pos('AI', UpperCase(S)) > 0), Short(S) + ' / ' + FAi.LastError);
  FAi.Files.Clear;

  { 12. 使えないモデル → ceHttp 404、やり直さない }
  FAi.Model := 'gemini-2.5-flash';
  T0 := GetTickCount64;
  S := FAi.AskAndWaitText('こんにちは');
  T0 := GetTickCount64 - T0;
  Check('T12 使えないモデル（404）', (S = '') and (FAi.LastErrorKind = ceHttp) and (FAi.LastStatusCode = 404)
    and (T0 < 3000),
    Format('%s %d %.1fs %s', [KIND_NAME[FAi.LastErrorKind], FAi.LastStatusCode,
      T0 / 1000, Short(FAi.LastError)]));
  FAi.Model := '';

  { 13. タイムアウト（1 秒・やり直しなし） }
  FAi.TimeoutSeconds := 1;
  FAi.RetryCount := 0;
  S := FAi.AskAndWaitText('1 から 200 までの数を、1行に1つずつ書いて。');
  Check('T13 タイムアウト', (S = '') and (FAi.LastErrorKind = ceTimeout),
    KIND_NAME[FAi.LastErrorKind] + ' ' + FAi.LastError);
  FAi.TimeoutSeconds := 0;
  FAi.RetryCount := -1;

  { 14. Cancel（0.5 秒後に止める） }
  FCancelTimer.Interval := 500;
  FCancelTimer.Enabled := True;
  T0 := GetTickCount64;
  S := FAi.AskAndWaitText('1 から 300 までの数を、1行に1つずつ書いて。');
  T0 := GetTickCount64 - T0;
  Check('T14 Cancel', (S = '') and (FAi.LastErrorKind = ceCanceled) and (T0 < 3000),
    Format('%s %.1fs %s', [KIND_NAME[FAi.LastErrorKind], T0 / 1000, FAi.LastError]));

  { 15. 処理中にもう一度呼ぶ → ceBusy。元の処理は続いて回答が返る }
  FBusyResult := 'x';
  FBusyKind := ceNone;
  FBusyTimer.Interval := 300;
  FBusyTimer.Enabled := True;
  S := FAi.AskAndWaitText('「はい」とだけ答えて。');
  Check('T15 処理中の二重呼び出し', (FBusyResult = '') and (FBusyKind = ceBusy) and (S <> '')
    and (FAi.LastErrorKind = ceNone) and (FAi.LastError = ''),
    Format('二重=%s 元の回答=%s %s', [KIND_NAME[FBusyKind], Short(S), FAi.LastError]));

  Log(Format('=== 結果: OK %d / NG %d ===', [FPass, FFail]));
  FLines.SaveToFile(Dir + 'results.txt');
  Close;
end;

var
  F: TTestForm;
begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TTestForm, F);
  Application.Run;
end.
