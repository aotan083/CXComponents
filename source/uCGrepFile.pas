unit uCGrepFile;

{ TCGrepFile - フォルダーの中のファイルを、中身の文字で探す（grep 検索）部品（画面を持たない）。
  設計書：docs\TCGrepFile_Design.md
  ・対象のファイルを集める処理は、uCFindFile の TCFindWorker を使う。見つかったファイルは、その場で、
    同じスレッドの中で読んで、行ごとに探す。
  ・結果の 1 行は「パス(行番号): その行の文字」（タグジャンプに使える形）。
  ・結果の届け方：omEvent（OnFound）か omFile（ファイルへ書き出す。UTF-8・BOM なし・CRLF）。
  ・パスは UTF-8 の文字列で受け渡しする。 }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Windows, LazUTF8, LConvEncoding, RegExpr, uCXLang, uCFindFile;

type
  TCGrepMatchMode = (gmContains, gmRegex);
  TCGrepOutputMode = (omEvent, omFile);

  TCGrepFoundEvent = procedure(Sender: TObject; const APath: string; ALine: Integer; const AText: string) of object;
  TCGrepProgressEvent = procedure(Sender: TObject; const AFile: string; AFiles: Integer; AFound: Integer) of object;
  TCGrepFinishedEvent = procedure(Sender: TObject; AFiles: Integer; AFound: Integer; AReason: TCFindStopReason) of object;
  TCGrepErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;

const
  cGrepFlushCount = 50;        // 見つかった行を、メインスレッドへ（またはファイルへ）渡す件数
  cGrepFlushMs = 100;          // 同じく、時間（ミリ秒）。件数か時間の早い方
  cGrepProgressMs = 200;       // OnProgress の間隔
  cGrepMaxDef = 10000;         // MaxResults の既定値
  cGrepMaxFileDef = 10485760;  // MaxFileSize の既定値（10 MB）
  cGrepMaxLine = 1000;         // 結果の 1 行の文字の最大の長さ（バイト）。超えたら、切って ... を付ける
  cGrepBinaryCheck = 8192;     // バイナリの判定に見る、先頭のバイト数

// 出力の 1 行を作る：パス(行番号): その行の文字
function CGrepFormatLine(const APath: string; ALine: Integer; const AText: string): string;
// フルパスか（ドライブ付き、または UNC）。タグジャンプは、フルパスだけを受ける
function CGrepIsFullPath(const APath: string): Boolean;
// 出力の 1 行を、パスと行番号に読み戻す（タグジャンプ用）。先頭から数えて、最初の「( 数字だけ ): 」の手前までがパス。
// 見つからなければ False
function CGrepParseLine(const S: string; out APath: string; out ALine: Integer): Boolean;
// ファイルの中身（バイト）を、UTF-8 の文字列にする。バイナリ（先頭 8192 バイトに NUL がある。BOM 付きの UTF-16 を除く）なら False。
// BOM（UTF-8・UTF-16）。なければ、正しい UTF-8 ならそのまま。そうでなければ CP932 とみなして変換する
function CGrepDecodeBytes(const ABytes: TBytes; out AText: string): Boolean;

type
  { TCGrepMatcher - 行の判定。スレッドごとに 1 つ作る }
  TCGrepMatcher = class
  private
    FMode: TCGrepMatchMode;
    FPattern: string;
    FCaseSensitive: Boolean;
    FRegex: TRegExpr;
  public
    // 式が正しくなければ ECFindPattern
    constructor Create(AMode: TCGrepMatchMode; const APattern: string; ACaseSensitive: Boolean);
    destructor Destroy; override;
    function Match(const ALine: string): Boolean;
  end;

  { TCGrepWorker - 探す処理の本体（スレッドからも、同期の GrepAll からも使う） }
  TCGrepWorker = class
  private
    FFinder: TCFindWorker;
    FMatcher: TCGrepMatcher;
    FStop: Boolean;
    FLimit: Boolean;
    FFound: Integer;
    FFiles: Integer;
    FLastProgress: QWord;
    function ReadFile(const APath: string; out ABytes: TBytes): Boolean;
    procedure FileFound(const APath: string; AIsDir: Boolean);
    procedure GrepText(const APath, AText: string);
  public
    Root: string;
    FileMask: string;
    Pattern: string;
    Mode: TCGrepMatchMode;
    CaseSensitive: Boolean;
    IncludeSubfolders: Boolean;
    SearchHidden: Boolean;
    MaxResults: Integer;
    MaxFileSize: Int64;
    SkipFile: string;           // 調べないファイル（出力先のファイル）
    // 見つかった行ごとに呼ぶ
    OnHit: procedure(const APath: string; ALine: Integer; const AText: string) of object;
    // 読むファイルが変わるたびに、一定の間隔で呼ぶ
    OnProgress: procedure(const AFile: string) of object;
    property Found: Integer read FFound;
    property Files: Integer read FFiles;
    // 止める（別スレッドから呼んでよい）
    procedure Stop;
    // 探す。式が正しくなければ ECFindPattern
    function Run: TCFindStopReason;
  end;

  TCGrepThread = class;

  { TCGrepFile }
  TCGrepFile = class(TComponent)
  private
    FRoot: string;
    FFileMask: string;
    FPattern: string;
    FMatchMode: TCGrepMatchMode;
    FCaseSensitive: Boolean;
    FIncludeSubfolders: Boolean;
    FSearchHidden: Boolean;
    FMaxResults: Integer;
    FMaxFileSize: Int64;
    FOutputMode: TCGrepOutputMode;
    FOutputFile: string;
    FThread: TCGrepThread;
    FFoundCount: Integer;
    FFileCount: Integer;
    FResults: TStringList;        // omEvent のとき、見つかった行（出力の 1 行ずつ）
    FDestroying: Boolean;
    FOnFound: TCGrepFoundEvent;
    FOnProgress: TCGrepProgressEvent;
    FOnFinished: TCGrepFinishedEvent;
    FOnError: TCGrepErrorEvent;
    procedure SetMaxResults(AValue: Integer);
    procedure SetMaxFileSize(AValue: Int64);
    function GetActive: Boolean;
    procedure ConfigureWorker(AWorker: TCGrepWorker);
    procedure DeliverHits(AItems: TStrings);
    procedure DeliverProgress(const AFile: string; AFiles, AFound: Integer);
    procedure DeliverFinished(AThread: TCGrepThread; AFiles, AFound: Integer; AReason: TCFindStopReason;
      const AError: string);
    procedure DoError(const AMessage: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // 別スレッドで探し始める。すでに探している・Root がフォルダーでない・Pattern が空・式が正しくない・
    // omFile で OutputFile が書けない、のときは、OnError を出して False
    function Start: Boolean;
    procedure Stop;
    function WaitFor(ATimeoutMs: Integer): Boolean;
    // 呼んだスレッドの中で探して、AResult に、出力の 1 行ずつを入れる。見つかった行の数を返す。イベントは出さない
    function GrepAll(AResult: TStrings): Integer;
    // omEvent で探した結果を、ファイルへ書き出す（UTF-8・BOM なし・CRLF。上書き）。保存先のフォルダーがなければ作る
    function SaveResults(const AFileName: string): Boolean;
    function CheckPattern(out AError: string): Boolean;
    property Active: Boolean read GetActive;
    property FoundCount: Integer read FFoundCount;
    property FileCount: Integer read FFileCount;
  published
    property Root: string read FRoot write FRoot;
    property FileMask: string read FFileMask write FFileMask;
    property Pattern: string read FPattern write FPattern;
    property MatchMode: TCGrepMatchMode read FMatchMode write FMatchMode default gmContains;
    property CaseSensitive: Boolean read FCaseSensitive write FCaseSensitive default False;
    property IncludeSubfolders: Boolean read FIncludeSubfolders write FIncludeSubfolders default True;
    property SearchHidden: Boolean read FSearchHidden write FSearchHidden default False;
    property MaxResults: Integer read FMaxResults write SetMaxResults default cGrepMaxDef;
    property MaxFileSize: Int64 read FMaxFileSize write SetMaxFileSize default cGrepMaxFileDef;
    property OutputMode: TCGrepOutputMode read FOutputMode write FOutputMode default omEvent;
    property OutputFile: string read FOutputFile write FOutputFile;
    property OnFound: TCGrepFoundEvent read FOnFound write FOnFound;
    property OnProgress: TCGrepProgressEvent read FOnProgress write FOnProgress;
    property OnFinished: TCGrepFinishedEvent read FOnFinished write FOnFinished;
    property OnError: TCGrepErrorEvent read FOnError write FOnError;
  end;

  { TCGrepThread - 探すスレッド。見つかった行は、スレッド側にためて、まとめて渡す }
  TCGrepThread = class(TThread)
  private
    FOwner: TCGrepFile;
    FWorker: TCGrepWorker;
    FOutMode: TCGrepOutputMode;
    FOutStream: TFileStream;     // omFile のときの、書き出し先（スレッドが持つ）
    FLock: SyncObjs.TCriticalSection;
    FBuf: TStringList;           // スレッド側のバッファ
    FOut: TStringList;           // メインスレッドへ渡す分
    FLastFlush: QWord;
    FProgFile: string;
    FProgFound: Integer;
    FProgFiles: Integer;
    FReason: TCFindStopReason;
    FError: string;
    procedure HitFound(const APath: string; ALine: Integer; const AText: string);
    procedure ProgressTick(const AFile: string);
    procedure FlushBuf;
    procedure DoDeliverHits;
    procedure DoDeliverProgress;
    procedure DoDeliverFinished;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TCGrepFile; AWorker: TCGrepWorker; AOutMode: TCGrepOutputMode; AOutStream: TFileStream);
    destructor Destroy; override;
    procedure RequestStop;
    procedure Detach;
  end;

implementation

{ ---- 長いパス ---- }

function LongPathW(const AUtf8: string): UnicodeString;
var
  S: UnicodeString;
begin
  S := UTF8Decode(AUtf8);
  if Length(S) < 240 then Exit(S);
  if Copy(S, 1, 4) = '\\?\' then Exit(S);
  if Copy(S, 1, 2) = '\\' then
    Result := '\\?\UNC\' + Copy(S, 3, MaxInt)
  else
    Result := '\\?\' + S;
end;

{ ---- 出力の 1 行 ---- }

function CGrepIsFullPath(const APath: string): Boolean;
begin
  // ドライブ付き（C:\ ..）、または UNC（\server\..）
  Result := ((Length(APath) >= 3) and (APath[2] = ':') and (APath[3] in ['\', '/'])) or
    ((Length(APath) >= 3) and (Copy(APath, 1, 2) = '\\'));
end;

function CGrepFormatLine(const APath: string; ALine: Integer; const AText: string): string;
begin
  Result := APath + '(' + IntToStr(ALine) + '): ' + AText;
end;

function CGrepParseLine(const S: string; out APath: string; out ALine: Integer): Boolean;
var
  I, J, N: Integer;
begin
  Result := False;
  APath := '';
  ALine := 0;
  N := Length(S);
  I := 1;
  while I <= N do
  begin
    if S[I] = '(' then
    begin
      // ( のあとが、数字だけで、そのあとが「): 」（文字が空の行は「):」で終わってもよい）
      J := I + 1;
      while (J <= N) and (S[J] in ['0'..'9']) do Inc(J);
      if (J > I + 1) and (J < N) and (S[J] = ')') and (S[J + 1] = ':') and
         ((J + 1 = N) or (S[J + 2] = ' ')) and (I > 1) then
      begin
        APath := Copy(S, 1, I - 1);
        if TryStrToInt(Copy(S, I + 1, J - I - 1), ALine) then Exit(True);
      end;
    end;
    Inc(I);
  end;
end;

{ ---- 文字コード ---- }

function Utf16ToUtf8(const ABytes: TBytes; AStart: Integer; ABigEndian: Boolean): string;
var
  W: UnicodeString;
  I, N: Integer;
  Lo, Hi: Byte;
begin
  N := (Length(ABytes) - AStart) div 2;
  SetLength(W, N);
  for I := 0 to N - 1 do
  begin
    if ABigEndian then
    begin
      Hi := ABytes[AStart + I * 2];
      Lo := ABytes[AStart + I * 2 + 1];
    end
    else
    begin
      Lo := ABytes[AStart + I * 2];
      Hi := ABytes[AStart + I * 2 + 1];
    end;
    W[I + 1] := WideChar((Word(Hi) shl 8) or Lo);
  end;
  Result := UTF8Encode(W);
end;

function CGrepDecodeBytes(const ABytes: TBytes; out AText: string): Boolean;
var
  N, I, Check: Integer;
  Raw: string;
begin
  AText := '';
  N := Length(ABytes);
  if N = 0 then Exit(True);
  // BOM
  if (N >= 3) and (ABytes[0] = $EF) and (ABytes[1] = $BB) and (ABytes[2] = $BF) then
  begin
    SetLength(AText, N - 3);
    if N > 3 then Move(ABytes[3], AText[1], N - 3);
    Exit(True);
  end;
  if (N >= 2) and (ABytes[0] = $FF) and (ABytes[1] = $FE) then
  begin
    AText := Utf16ToUtf8(ABytes, 2, False);
    Exit(True);
  end;
  if (N >= 2) and (ABytes[0] = $FE) and (ABytes[1] = $FF) then
  begin
    AText := Utf16ToUtf8(ABytes, 2, True);
    Exit(True);
  end;
  // バイナリ
  Check := N;
  if Check > cGrepBinaryCheck then Check := cGrepBinaryCheck;
  for I := 0 to Check - 1 do
    if ABytes[I] = 0 then Exit(False);
  SetLength(Raw, N);
  Move(ABytes[0], Raw[1], N);
  if FindInvalidUTF8Codepoint(PChar(Raw), N, True) < 0 then
    AText := Raw                          // 正しい UTF-8
  else
    AText := CP932ToUTF8(Raw);            // UTF-8 でなければ、CP932
  Result := True;
end;

{ ---- TCGrepMatcher ---- }

constructor TCGrepMatcher.Create(AMode: TCGrepMatchMode; const APattern: string; ACaseSensitive: Boolean);
begin
  inherited Create;
  FMode := AMode;
  FCaseSensitive := ACaseSensitive;
  FPattern := APattern;
  if AMode = gmContains then
  begin
    if not ACaseSensitive then FPattern := UTF8LowerCase(APattern);
  end
  else
  begin
    FRegex := TRegExpr.Create;
    try
      FRegex.ModifierI := not ACaseSensitive;
      FRegex.Expression := APattern;
      FRegex.Compile;
    except
      on E: Exception do
      begin
        FreeAndNil(FRegex);
        raise ECFindPattern.Create(E.Message);
      end;
    end;
  end;
end;

destructor TCGrepMatcher.Destroy;
begin
  FRegex.Free;
  inherited Destroy;
end;

function TCGrepMatcher.Match(const ALine: string): Boolean;
begin
  if FMode = gmContains then
  begin
    if FCaseSensitive then
      Result := Pos(FPattern, ALine) > 0
    else
      Result := Pos(FPattern, UTF8LowerCase(ALine)) > 0;
  end
  else
    Result := FRegex.Exec(ALine);
end;

{ ---- TCGrepWorker ---- }

procedure TCGrepWorker.Stop;
begin
  FStop := True;
  if FFinder <> nil then FFinder.StopFlag := True;
end;

// ファイルを、全部メモリへ読む。開けない・読めない・大きすぎるときは False（静かに飛ばす）
function TCGrepWorker.ReadFile(const APath: string; out ABytes: TBytes): Boolean;
var
  H: THandle;
  Size: Int64;
  Got: DWORD;
  Pos0, Want: Int64;
  Chunk, SizeLow, SizeHigh: DWORD;
begin
  Result := False;
  SetLength(ABytes, 0);
  H := CreateFileW(PWideChar(LongPathW(APath)), GENERIC_READ,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if H = INVALID_HANDLE_VALUE then Exit;
  try
    SizeHigh := 0;
    SizeLow := GetFileSize(H, @SizeHigh);
    if (SizeLow = INVALID_FILE_SIZE) and (GetLastError <> NO_ERROR) then Exit;
    Size := (Int64(SizeHigh) shl 32) or SizeLow;
    if (MaxFileSize > 0) and (Size > MaxFileSize) then Exit;
    if Size > High(Integer) then Exit;
    SetLength(ABytes, Size);
    Pos0 := 0;
    while Pos0 < Size do
    begin
      Want := Size - Pos0;
      if Want > $100000 then Want := $100000;
      Chunk := DWORD(Want);
      if not Windows.ReadFile(H, ABytes[Pos0], Chunk, Got, nil) then Exit;
      if Got = 0 then Break;
      Inc(Pos0, Got);
    end;
    if Pos0 < Size then SetLength(ABytes, Pos0);
    Result := True;
  finally
    CloseHandle(H);
  end;
end;

// 行に分けて、1 行ずつ判定する
procedure TCGrepWorker.GrepText(const APath, AText: string);
var
  N, I, Start, LineNo, Cut: Integer;
  Line, Shown: string;

  procedure OneLine(AFrom, ATo: Integer);   // AFrom..ATo（ATo は行の最後の文字）
  begin
    Inc(LineNo);
    Line := Copy(AText, AFrom, ATo - AFrom + 1);
    if not FMatcher.Match(Line) then Exit;
    Shown := Line;
    if Length(Shown) > cGrepMaxLine then
    begin
      Cut := cGrepMaxLine;
      // UTF-8 の文字の途中では切らない
      while (Cut > 0) and ((Byte(Shown[Cut + 1]) and $C0) = $80) do Dec(Cut);
      Shown := Copy(Shown, 1, Cut) + '...';
    end;
    Inc(FFound);
    if Assigned(OnHit) then OnHit(APath, LineNo, Shown);
    if (MaxResults > 0) and (FFound >= MaxResults) then
    begin
      FLimit := True;
      Stop;
    end;
  end;

begin
  N := Length(AText);
  I := 1;
  Start := 1;
  LineNo := 0;
  while I <= N do
  begin
    if FStop then Exit;
    case AText[I] of
      #13:
        begin
          OneLine(Start, I - 1);
          if (I < N) and (AText[I + 1] = #10) then Inc(I);
          Start := I + 1;
        end;
      #10:
        begin
          OneLine(Start, I - 1);
          Start := I + 1;
        end;
    end;
    Inc(I);
  end;
  // 最後の行（改行で終わっていないとき）
  if (Start <= N) and (not FStop) then OneLine(Start, N);
end;

procedure TCGrepWorker.FileFound(const APath: string; AIsDir: Boolean);
var
  Bytes: TBytes;
  Text: string;
begin
  if FStop then Exit;
  if (SkipFile <> '') and SameText(APath, SkipFile) then Exit;
  if Assigned(OnProgress) and (GetTickCount64 - FLastProgress >= cGrepProgressMs) then
  begin
    FLastProgress := GetTickCount64;
    OnProgress(APath);
  end;
  if not ReadFile(APath, Bytes) then Exit;
  if not CGrepDecodeBytes(Bytes, Text) then Exit;     // バイナリ
  Inc(FFiles);
  GrepText(APath, Text);
end;

function TCGrepWorker.Run: TCFindStopReason;
var
  R: TCFindStopReason;
  Mask: string;
begin
  FFound := 0;
  FFiles := 0;
  FLimit := False;
  FMatcher := TCGrepMatcher.Create(Mode, Pattern, CaseSensitive);   // 正しくなければ ECFindPattern
  FFinder := TCFindWorker.Create;
  try
    Mask := FileMask;
    if Trim(Mask) = '' then Mask := '*';
    FFinder.Root := Root;
    FFinder.Pattern := Mask;
    FFinder.Mode := fmWildcard;
    FFinder.CaseSensitive := False;
    FFinder.IncludeSubfolders := IncludeSubfolders;
    FFinder.IncludeFiles := True;
    FFinder.IncludeFolders := False;
    FFinder.SearchHidden := SearchHidden;
    FFinder.MaxResults := 0;
    FFinder.StopFlag := FStop;
    FFinder.OnItem := @FileFound;
    R := FFinder.Run;
    if FLimit then Result := frLimit else Result := R;
  finally
    FreeAndNil(FFinder);
    FreeAndNil(FMatcher);
  end;
end;

{ ---- TCGrepThread ---- }

constructor TCGrepThread.Create(AOwner: TCGrepFile; AWorker: TCGrepWorker; AOutMode: TCGrepOutputMode;
  AOutStream: TFileStream);
begin
  FOwner := AOwner;
  FWorker := AWorker;
  FOutMode := AOutMode;
  FOutStream := AOutStream;
  FLock := SyncObjs.TCriticalSection.Create;
  FBuf := TStringList.Create;
  FOut := TStringList.Create;
  FWorker.OnHit := @HitFound;
  FWorker.OnProgress := @ProgressTick;
  FReason := frDone;
  FreeOnTerminate := False;
  inherited Create(False);
end;

destructor TCGrepThread.Destroy;
begin
  FOutStream.Free;
  FWorker.Free;
  FBuf.Free;
  FOut.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TCGrepThread.RequestStop;
begin
  FWorker.Stop;
end;

procedure TCGrepThread.Detach;
begin
  FOwner := nil;
  FWorker.Stop;
end;

procedure TCGrepThread.HitFound(const APath: string; ALine: Integer; const AText: string);
begin
  if FOutMode = omFile then
    FBuf.Add(CGrepFormatLine(APath, ALine, AText))
  else
    FBuf.Add(APath + #1 + IntToStr(ALine) + #1 + AText);
  if (FBuf.Count >= cGrepFlushCount) or (GetTickCount64 - FLastFlush >= cGrepFlushMs) then FlushBuf;
end;

procedure TCGrepThread.ProgressTick(const AFile: string);
begin
  FLock.Enter;
  try
    FProgFile := AFile;
    FProgFound := FWorker.Found;
    FProgFiles := FWorker.Files;
  finally
    FLock.Leave;
  end;
  Queue(@DoDeliverProgress);
  if GetTickCount64 - FLastFlush >= cGrepFlushMs then FlushBuf;
end;

procedure TCGrepThread.FlushBuf;
var
  I: Integer;
  S: string;
begin
  FLastFlush := GetTickCount64;
  if FBuf.Count = 0 then Exit;
  if FOutMode = omFile then
  begin
    // ファイルへ書き足す（UTF-8・BOM なし・CRLF）
    for I := 0 to FBuf.Count - 1 do
    begin
      S := FBuf[I] + #13#10;
      FOutStream.WriteBuffer(S[1], Length(S));
    end;
    FBuf.Clear;
    Exit;
  end;
  FLock.Enter;
  try
    FOut.AddStrings(FBuf);
  finally
    FLock.Leave;
  end;
  FBuf.Clear;
  Queue(@DoDeliverHits);
end;

procedure TCGrepThread.DoDeliverHits;
var
  L: TStringList;
begin
  if FOwner = nil then Exit;
  L := TStringList.Create;
  try
    FLock.Enter;
    try
      L.AddStrings(FOut);
      FOut.Clear;
    finally
      FLock.Leave;
    end;
    if L.Count > 0 then FOwner.DeliverHits(L);
  finally
    L.Free;
  end;
end;

procedure TCGrepThread.DoDeliverProgress;
var
  Fi: string;
  Fn, Fl: Integer;
begin
  if FOwner = nil then Exit;
  FLock.Enter;
  try
    Fi := FProgFile;
    Fn := FProgFound;
    Fl := FProgFiles;
  finally
    FLock.Leave;
  end;
  FOwner.DeliverProgress(Fi, Fl, Fn);
end;

procedure TCGrepThread.DoDeliverFinished;
begin
  if FOwner = nil then Exit;
  FOwner.DeliverFinished(Self, FWorker.Files, FWorker.Found, FReason, FError);
end;

procedure TCGrepThread.Execute;
begin
  try
    FReason := FWorker.Run;
  except
    on E: Exception do
    begin
      FReason := frError;
      FError := E.Message;
    end;
  end;
  try
    FlushBuf;
  except
    on E: Exception do
    begin
      FReason := frError;
      FError := Format(CXT(sGrErrOutput), [E.Message]);
    end;
  end;
  // 書き出し先を閉じてから、終わりを知らせる
  FreeAndNil(FOutStream);
  Queue(@DoDeliverFinished);
end;

{ ---- TCGrepFile ---- }

constructor TCGrepFile.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFileMask := '*';
  FMatchMode := gmContains;
  FIncludeSubfolders := True;
  FMaxResults := cGrepMaxDef;
  FMaxFileSize := cGrepMaxFileDef;
  FOutputMode := omEvent;
  FResults := TStringList.Create;
end;

destructor TCGrepFile.Destroy;
var
  T: TCGrepThread;
begin
  FDestroying := True;
  T := FThread;
  FThread := nil;
  if T <> nil then
  begin
    T.Detach;
    T.WaitFor;
    TThread.RemoveQueuedEvents(T);
    T.Free;
  end;
  FResults.Free;
  inherited Destroy;
end;

procedure TCGrepFile.SetMaxResults(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  FMaxResults := AValue;
end;

procedure TCGrepFile.SetMaxFileSize(AValue: Int64);
begin
  if AValue < 0 then AValue := 0;
  FMaxFileSize := AValue;
end;

function TCGrepFile.GetActive: Boolean;
begin
  Result := FThread <> nil;
end;

procedure TCGrepFile.DoError(const AMessage: string);
begin
  if Assigned(FOnError) then FOnError(Self, AMessage);
end;

function TCGrepFile.CheckPattern(out AError: string): Boolean;
var
  M: TCGrepMatcher;
  F: TCFindMatcher;
begin
  Result := False;
  AError := '';
  if FPattern = '' then
  begin
    AError := CXT(sGrErrEmpty);
    Exit;
  end;
  try
    M := TCGrepMatcher.Create(FMatchMode, FPattern, FCaseSensitive);
    M.Free;
    if Trim(FFileMask) <> '' then
    begin
      F := TCFindMatcher.Create(fmWildcard, FFileMask, False);
      F.Free;
    end;
    Result := True;
  except
    on E: Exception do AError := E.Message;
  end;
end;

procedure TCGrepFile.ConfigureWorker(AWorker: TCGrepWorker);
begin
  AWorker.Root := FRoot;
  AWorker.FileMask := FFileMask;
  AWorker.Pattern := FPattern;
  AWorker.Mode := FMatchMode;
  AWorker.CaseSensitive := FCaseSensitive;
  AWorker.IncludeSubfolders := FIncludeSubfolders;
  AWorker.SearchHidden := FSearchHidden;
  AWorker.MaxResults := FMaxResults;
  AWorker.MaxFileSize := FMaxFileSize;
  if FOutputMode = omFile then AWorker.SkipFile := ExpandFileName(FOutputFile);
end;

function TCGrepFile.Start: Boolean;
var
  Err: string;
  W: TCGrepWorker;
  Stream: TFileStream;
begin
  Result := False;
  if FThread <> nil then Exit;
  if not DirectoryExists(FRoot) then
  begin
    DoError(Format(CXT(sSbErrNoRoot), [FRoot]));
    Exit;
  end;
  if not CheckPattern(Err) then
  begin
    DoError(Err);
    Exit;
  end;
  Stream := nil;
  if FOutputMode = omFile then
  begin
    if Trim(FOutputFile) = '' then
    begin
      DoError(Format(CXT(sGrErrOutput), [FOutputFile]));
      Exit;
    end;
    try
      Stream := TFileStream.Create(FOutputFile, fmCreate);   // 作り直す（空にする）
    except
      on E: Exception do
      begin
        DoError(Format(CXT(sGrErrOutput), [FOutputFile]));
        Exit;
      end;
    end;
  end;
  FFoundCount := 0;
  FFileCount := 0;
  FResults.Clear;
  W := TCGrepWorker.Create;
  ConfigureWorker(W);
  FThread := TCGrepThread.Create(Self, W, FOutputMode, Stream);
  Result := True;
end;

procedure TCGrepFile.Stop;
begin
  if FThread <> nil then FThread.RequestStop;
end;

function TCGrepFile.WaitFor(ATimeoutMs: Integer): Boolean;
var
  T0: QWord;
begin
  T0 := GetTickCount64;
  while FThread <> nil do
  begin
    CheckSynchronize(10);
    if (ATimeoutMs >= 0) and (GetTickCount64 - T0 > QWord(ATimeoutMs)) then Break;
  end;
  Result := FThread = nil;
end;

type
  // GrepAll 用：見つかった行を、そのまま、一覧に入れる
  TCGrepCollector = class
    List: TStrings;
    procedure Hit(const APath: string; ALine: Integer; const AText: string);
  end;

procedure TCGrepCollector.Hit(const APath: string; ALine: Integer; const AText: string);
begin
  List.Add(CGrepFormatLine(APath, ALine, AText));
end;

function TCGrepFile.GrepAll(AResult: TStrings): Integer;
var
  W: TCGrepWorker;
  C: TCGrepCollector;
begin
  AResult.Clear;
  if not DirectoryExists(FRoot) then
    raise EInOutError.Create(Format(CXT(sSbErrNoRoot), [FRoot]));
  if FPattern = '' then
    raise ECFindPattern.Create(CXT(sGrErrEmpty));
  W := TCGrepWorker.Create;
  C := TCGrepCollector.Create;
  try
    C.List := AResult;
    ConfigureWorker(W);
    W.OnHit := @C.Hit;
    W.Run;
    Result := W.Found;
  finally
    C.Free;
    W.Free;
  end;
end;

function TCGrepFile.SaveResults(const AFileName: string): Boolean;
var
  S: TFileStream;
  I: Integer;
  Line: string;
  Dir: string;
begin
  Result := False;
  if FOutputMode = omFile then
  begin
    DoError(CXT(sGrErrNoResult));
    Exit;
  end;
  try
    // 保存先のフォルダーがなければ、作る（途中のフォルダーも）
    Dir := ExtractFilePath(ExpandFileName(AFileName));
    if (Dir <> '') and (not DirectoryExists(Dir)) then
      if not ForceDirectories(Dir) then
      begin
        DoError(Format(CXT(sGrErrOutput), [AFileName]));
        Exit;
      end;
    S := TFileStream.Create(AFileName, fmCreate);
    try
      for I := 0 to FResults.Count - 1 do
      begin
        Line := FResults[I] + #13#10;
        S.WriteBuffer(Line[1], Length(Line));
      end;
    finally
      S.Free;
    end;
    Result := True;
  except
    on E: Exception do
    begin
      DoError(Format(CXT(sGrErrOutput), [AFileName]));
      Result := False;
    end;
  end;
end;

{ メインスレッドで、スレッドから受ける }

procedure TCGrepFile.DeliverHits(AItems: TStrings);
var
  I, P1, P2, Ln: Integer;
  S, Path, Txt: string;
begin
  if FDestroying then Exit;
  for I := 0 to AItems.Count - 1 do
  begin
    S := AItems[I];
    P1 := Pos(#1, S);
    P2 := Pos(#1, Copy(S, P1 + 1, MaxInt)) + P1;
    Path := Copy(S, 1, P1 - 1);
    Ln := StrToIntDef(Copy(S, P1 + 1, P2 - P1 - 1), 0);
    Txt := Copy(S, P2 + 1, MaxInt);
    Inc(FFoundCount);
    FResults.Add(CGrepFormatLine(Path, Ln, Txt));
    if Assigned(FOnFound) then FOnFound(Self, Path, Ln, Txt);
  end;
end;

procedure TCGrepFile.DeliverProgress(const AFile: string; AFiles, AFound: Integer);
begin
  if FDestroying then Exit;
  FFileCount := AFiles;
  if Assigned(FOnProgress) then FOnProgress(Self, AFile, AFiles, AFound);
end;

procedure TCGrepFile.DeliverFinished(AThread: TCGrepThread; AFiles, AFound: Integer; AReason: TCFindStopReason;
  const AError: string);
begin
  if FDestroying then Exit;
  FFileCount := AFiles;
  if FOutputMode = omFile then FFoundCount := AFound;
  if FThread = AThread then FThread := nil;
  AThread.Detach;
  AThread.WaitFor;
  AThread.Free;
  if (AReason = frError) and (AError <> '') then DoError(AError);
  if Assigned(FOnFinished) then FOnFinished(Self, AFiles, AFound, AReason);
end;

end.
