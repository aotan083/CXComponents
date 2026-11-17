unit uCFindFile;

{ TCFindFile - ファイル・フォルダーを、名前で探す部品（画面を持たない）。
  設計書：docs\TCFindFile_Design.md
  ・自前の再帰（FindFirstFileW）で探す。別スレッドで動き、結果は、まとめてメインスレッドへ渡す。
  ・名前の判定は、部分一致・ワイルドカード（* ?、; で複数）・正規表現（RegExpr。UTF-8 のまま）。
  ・パスは UTF-8 の文字列で受け渡しする。 }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Windows, Masks, LazUTF8, RegExpr;

type
  TCFindMatchMode = (fmContains, fmWildcard, fmRegex);
  TCFindStopReason = (frDone, frStopped, frLimit, frError);

  TCFindFoundEvent = procedure(Sender: TObject; const APath: string; AIsDir: Boolean) of object;
  TCFindProgressEvent = procedure(Sender: TObject; const AFolder: string; AScanned: Int64; AFound: Integer) of object;
  TCFindFinishedEvent = procedure(Sender: TObject; AFound: Integer; AReason: TCFindStopReason) of object;
  TCFindErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;

  // 正規表現・ワイルドカードの式が正しくない
  ECFindPattern = class(Exception);

const
  cFindFlushCount = 50;     // 見つかったものを、メインスレッドへ渡す件数
  cFindFlushMs = 100;       // 同じく、時間（ミリ秒）。件数か時間の早い方
  cFindProgressMs = 200;    // OnProgress の間隔
  cFindMaxDef = 10000;      // MaxResults の既定値

type
  { TCFindMatcher - 名前の判定。スレッドごとに 1 つ作る（TRegExpr は、スレッドをまたいで使えないため） }
  TCFindMatcher = class
  private
    FMode: TCFindMatchMode;
    FPattern: string;       // 部分一致のときは、必要なら小文字にしたもの
    FCaseSensitive: Boolean;
    FMasks: TMaskList;
    FRegex: TRegExpr;
  public
    // 式が正しくなければ ECFindPattern
    constructor Create(AMode: TCFindMatchMode; const APattern: string; ACaseSensitive: Boolean);
    destructor Destroy; override;
    function Match(const AName: string): Boolean;
  end;

  { TCFindWorker - 探す処理の本体（スレッドからも、同期の FindAll からも使う） }
  TCFindWorker = class
  public
    Root: string;
    Pattern: string;
    Mode: TCFindMatchMode;
    CaseSensitive: Boolean;
    IncludeSubfolders: Boolean;
    IncludeFiles: Boolean;
    IncludeFolders: Boolean;
    SearchHidden: Boolean;
    MaxResults: Integer;
    // 結果が 1 件見つかるたびに呼ぶ（AIsDir：フォルダーか）
    OnItem: procedure(const APath: string; AIsDir: Boolean) of object;
    // 調べているフォルダーが変わるたびに呼ぶ
    OnFolder: procedure(const AFolder: string) of object;
    // 止める印（別スレッドから True にされる）
    StopFlag: Boolean;
    Found: Integer;
    Scanned: Int64;
    // たどって探す。理由を返す（式が正しくなければ ECFindPattern）
    function Run: TCFindStopReason;
  end;

  TCFindThread = class;

  { TCFindFile }
  TCFindFile = class(TComponent)
  private
    FRoot: string;
    FPattern: string;
    FMatchMode: TCFindMatchMode;
    FCaseSensitive: Boolean;
    FIncludeSubfolders: Boolean;
    FIncludeFiles: Boolean;
    FIncludeFolders: Boolean;
    FSearchHidden: Boolean;
    FMaxResults: Integer;
    FThread: TCFindThread;        // 探しているスレッド。終わったら nil
    FFoundCount: Integer;
    FScannedCount: Int64;
    FDestroying: Boolean;
    FOnFound: TCFindFoundEvent;
    FOnProgress: TCFindProgressEvent;
    FOnFinished: TCFindFinishedEvent;
    FOnError: TCFindErrorEvent;
    procedure SetMaxResults(AValue: Integer);
    function GetActive: Boolean;
    procedure ConfigureWorker(AWorker: TCFindWorker);
    procedure DeliverItems(AItems: TStrings);
    procedure DeliverProgress(const AFolder: string; AScanned: Int64; AFound: Integer);
    procedure DeliverFinished(AThread: TCFindThread; AFound: Integer; AScanned: Int64; AReason: TCFindStopReason);
    procedure DoError(const AMessage: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // 別スレッドで探し始める。すでに探している、Root がフォルダーでない、Pattern が空、
    // 正規表現が正しくない、のときは、OnError を出して False
    function Start: Boolean;
    // 止める（スレッドが終わるのを待たない。OnFinished が frStopped で来る）
    procedure Stop;
    // 探し終わる（OnFinished が来る）まで待つ。時間内に終われば True
    function WaitFor(ATimeoutMs: Integer): Boolean;
    // 呼んだスレッドの中で探して、AResult にフルパスを入れる。見つかった数を返す。イベントは出さない。
    // エラーは例外（ECFindPattern・EInOutError）
    function FindAll(AResult: TStrings): Integer;
    // Pattern が使えるか（空でなく、正規表現・ワイルドカードなら組み立てられるか）
    function CheckPattern(out AError: string): Boolean;
    property Active: Boolean read GetActive;
    property FoundCount: Integer read FFoundCount;
    property ScannedCount: Int64 read FScannedCount;
  published
    property Root: string read FRoot write FRoot;
    property Pattern: string read FPattern write FPattern;
    property MatchMode: TCFindMatchMode read FMatchMode write FMatchMode default fmContains;
    property CaseSensitive: Boolean read FCaseSensitive write FCaseSensitive default False;
    property IncludeSubfolders: Boolean read FIncludeSubfolders write FIncludeSubfolders default True;
    property IncludeFiles: Boolean read FIncludeFiles write FIncludeFiles default True;
    property IncludeFolders: Boolean read FIncludeFolders write FIncludeFolders default True;
    property SearchHidden: Boolean read FSearchHidden write FSearchHidden default False;
    // 結果の最大数。0 は制限なし。0 より小さい値は 0
    property MaxResults: Integer read FMaxResults write SetMaxResults default cFindMaxDef;
    property OnFound: TCFindFoundEvent read FOnFound write FOnFound;
    property OnProgress: TCFindProgressEvent read FOnProgress write FOnProgress;
    property OnFinished: TCFindFinishedEvent read FOnFinished write FOnFinished;
    property OnError: TCFindErrorEvent read FOnError write FOnError;
  end;

  { TCFindThread - 探すスレッド。結果は、スレッド側にためて、まとめてメインスレッドへ渡す }
  TCFindThread = class(TThread)
  private
    FOwner: TCFindFile;
    FWorker: TCFindWorker;
    FLock: SyncObjs.TCriticalSection;
    FBuf: TStringList;          // スレッド側のバッファ（先頭の 1 文字：D = フォルダー、F = ファイル）
    FOut: TStringList;          // メインスレッドへ渡す分
    FLastFlush: QWord;
    FLastProgress: QWord;
    FCurFolder: string;
    FProgFolder: string;
    FProgScanned: Int64;
    FProgFound: Integer;
    FReason: TCFindStopReason;
    procedure ItemFound(const APath: string; AIsDir: Boolean);
    procedure FolderChanged(const AFolder: string);
    procedure FlushBuf;
    procedure DoDeliverItems;
    procedure DoDeliverProgress;
    procedure DoDeliverFinished;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TCFindFile; AWorker: TCFindWorker);
    destructor Destroy; override;
    // 止める（Terminate は使わない：実行の始まる前に Terminate すると、Execute が呼ばれず、終わりの知らせが来ないため）
    procedure RequestStop;
    // 破棄の前に、メインスレッドから呼ぶ：もう、持ち主へは何も渡さない
    procedure Detach;
  end;

implementation

uses
  uCXLang;

{ ---- 長いパス・UTF-8 と UTF-16 の変換 ---- }

// 260 文字を超えるときは、\\?\ を前に付ける（\\server\share は \\?\UNC\server\share）
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

function JoinPath(const AFolder, AName: string): string;
begin
  if (AFolder <> '') and (AFolder[Length(AFolder)] = '\') then
    Result := AFolder + AName
  else
    Result := AFolder + '\' + AName;
end;

{ ---- TCFindMatcher ---- }

constructor TCFindMatcher.Create(AMode: TCFindMatchMode; const APattern: string; ACaseSensitive: Boolean);
begin
  inherited Create;
  FMode := AMode;
  FCaseSensitive := ACaseSensitive;
  FPattern := APattern;
  case AMode of
    fmContains:
      if not ACaseSensitive then FPattern := UTF8LowerCase(APattern);
    fmWildcard:
      try
        FMasks := TMaskList.Create(APattern, ';', ACaseSensitive);
      except
        on E: Exception do
          raise ECFindPattern.Create(E.Message);
      end;
    fmRegex:
      begin
        FRegex := TRegExpr.Create;
        try
          FRegex.ModifierI := not ACaseSensitive;
          FRegex.Expression := APattern;
          FRegex.Compile;     // 正しくなければ、ここで ERegExpr
        except
          on E: Exception do
          begin
            FRegex.Free;
            FRegex := nil;
            raise ECFindPattern.Create(E.Message);
          end;
        end;
      end;
  end;
end;

destructor TCFindMatcher.Destroy;
begin
  FMasks.Free;
  FRegex.Free;
  inherited Destroy;
end;

function TCFindMatcher.Match(const AName: string): Boolean;
begin
  case FMode of
    fmContains:
      if FCaseSensitive then
        Result := Pos(FPattern, AName) > 0
      else
        Result := Pos(FPattern, UTF8LowerCase(AName)) > 0;
    fmWildcard:
      Result := FMasks.Matches(AName);
    fmRegex:
      Result := FRegex.Exec(AName);
  else
    Result := False;
  end;
end;

{ ---- TCFindWorker ---- }

function TCFindWorker.Run: TCFindStopReason;
var
  Matcher: TCFindMatcher;
  Stack: TStringList;
  Folder, Name, Full: string;
  FD: TWin32FindDataW;
  H: THandle;
  IsDir, IsReparse, Hidden: Boolean;
  Attr: DWORD;
begin
  Result := frDone;
  Found := 0;
  Scanned := 0;
  Matcher := TCFindMatcher.Create(Mode, Pattern, CaseSensitive);   // 正しくなければ ECFindPattern
  Stack := TStringList.Create;
  try
    Stack.Add(ExcludeTrailingPathDelimiter(Root));
    while Stack.Count > 0 do
    begin
      if StopFlag then Exit(frStopped);
      Folder := Stack[Stack.Count - 1];
      Stack.Delete(Stack.Count - 1);
      if Assigned(OnFolder) then OnFolder(Folder);

      // フォルダーの中を調べる（読めないフォルダーは、静かに飛ばす）
      H := FindFirstFileW(PWideChar(LongPathW(Folder + '\*')), FD);
      if H = INVALID_HANDLE_VALUE then Continue;
      try
        repeat
          if StopFlag then Exit(frStopped);
          Attr := FD.dwFileAttributes;
          Name := UTF8Encode(UnicodeString(PWideChar(@FD.cFileName[0])));
          if (Name = '.') or (Name = '..') then Continue;
          Inc(Scanned);
          Hidden := (Attr and (FILE_ATTRIBUTE_HIDDEN or FILE_ATTRIBUTE_SYSTEM)) <> 0;
          if Hidden and (not SearchHidden) then Continue;
          IsDir := (Attr and FILE_ATTRIBUTE_DIRECTORY) <> 0;
          IsReparse := (Attr and FILE_ATTRIBUTE_REPARSE_POINT) <> 0;
          Full := JoinPath(Folder, Name);
          if IsDir then
          begin
            if IncludeFolders and Matcher.Match(Name) then
            begin
              Inc(Found);
              if Assigned(OnItem) then OnItem(Full, True);
              if (MaxResults > 0) and (Found >= MaxResults) then Exit(frLimit);
            end;
            // ジャンクション・シンボリックリンクの中には入らない（無限にたどるのを避ける）
            if IncludeSubfolders and (not IsReparse) then Stack.Add(Full);
          end
          else if IncludeFiles and Matcher.Match(Name) then
          begin
            Inc(Found);
            if Assigned(OnItem) then OnItem(Full, False);
            if (MaxResults > 0) and (Found >= MaxResults) then Exit(frLimit);
          end;
        until not FindNextFileW(H, FD);
      finally
        Windows.FindClose(H);
      end;
    end;
  finally
    Stack.Free;
    Matcher.Free;
  end;
end;

{ ---- TCFindThread ---- }

constructor TCFindThread.Create(AOwner: TCFindFile; AWorker: TCFindWorker);
begin
  FOwner := AOwner;
  FWorker := AWorker;
  FLock := SyncObjs.TCriticalSection.Create;
  FBuf := TStringList.Create;
  FOut := TStringList.Create;
  FWorker.OnItem := @ItemFound;
  FWorker.OnFolder := @FolderChanged;
  FReason := frDone;
  FreeOnTerminate := False;
  inherited Create(False);
end;

destructor TCFindThread.Destroy;
begin
  FWorker.Free;
  FBuf.Free;
  FOut.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TCFindThread.RequestStop;
begin
  FWorker.StopFlag := True;
end;

procedure TCFindThread.Detach;
begin
  FOwner := nil;
  FWorker.StopFlag := True;
end;

procedure TCFindThread.ItemFound(const APath: string; AIsDir: Boolean);
begin
  if AIsDir then FBuf.Add('D' + APath) else FBuf.Add('F' + APath);
  if (FBuf.Count >= cFindFlushCount) or (GetTickCount64 - FLastFlush >= cFindFlushMs) then FlushBuf;
end;

procedure TCFindThread.FolderChanged(const AFolder: string);
begin
  FCurFolder := AFolder;
  if GetTickCount64 - FLastProgress >= cFindProgressMs then
  begin
    FLastProgress := GetTickCount64;
    FLock.Enter;
    try
      FProgFolder := AFolder;
      FProgScanned := FWorker.Scanned;
      FProgFound := FWorker.Found;
    finally
      FLock.Leave;
    end;
    Queue(@DoDeliverProgress);
  end;
  if GetTickCount64 - FLastFlush >= cFindFlushMs then FlushBuf;
end;

procedure TCFindThread.FlushBuf;
begin
  FLastFlush := GetTickCount64;
  if FBuf.Count = 0 then Exit;
  FLock.Enter;
  try
    FOut.AddStrings(FBuf);
  finally
    FLock.Leave;
  end;
  FBuf.Clear;
  Queue(@DoDeliverItems);
end;

procedure TCFindThread.DoDeliverItems;
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
    if L.Count > 0 then FOwner.DeliverItems(L);
  finally
    L.Free;
  end;
end;

procedure TCFindThread.DoDeliverProgress;
var
  Fo: string;
  Sc: Int64;
  Fn: Integer;
begin
  if FOwner = nil then Exit;
  FLock.Enter;
  try
    Fo := FProgFolder;
    Sc := FProgScanned;
    Fn := FProgFound;
  finally
    FLock.Leave;
  end;
  FOwner.DeliverProgress(Fo, Sc, Fn);
end;

procedure TCFindThread.DoDeliverFinished;
begin
  if FOwner = nil then Exit;
  FOwner.DeliverFinished(Self, FWorker.Found, FWorker.Scanned, FReason);
end;

// 探す処理の本体。式が正しくない・予期しないエラーは frError
procedure TCFindThread.Execute;
begin
  try
    FReason := FWorker.Run;
  except
    FReason := frError;
  end;
  // 最後に、残りを渡して、終わりを知らせる（OnFound は、すべて OnFinished より前）
  FlushBuf;
  Queue(@DoDeliverFinished);
end;

{ ---- TCFindFile ---- }

constructor TCFindFile.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMatchMode := fmContains;
  FIncludeSubfolders := True;
  FIncludeFiles := True;
  FIncludeFolders := True;
  FMaxResults := cFindMaxDef;
end;

destructor TCFindFile.Destroy;
var
  T: TCFindThread;
begin
  FDestroying := True;
  T := FThread;
  FThread := nil;
  if T <> nil then
  begin
    T.Detach;            // 持ち主へは、もう何も渡さない
    T.WaitFor;
    TThread.RemoveQueuedEvents(T);
    T.Free;
  end;
  inherited Destroy;
end;

procedure TCFindFile.SetMaxResults(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  FMaxResults := AValue;
end;

function TCFindFile.GetActive: Boolean;
begin
  Result := FThread <> nil;
end;

procedure TCFindFile.DoError(const AMessage: string);
begin
  if Assigned(FOnError) then FOnError(Self, AMessage);
end;

function TCFindFile.CheckPattern(out AError: string): Boolean;
var
  M: TCFindMatcher;
begin
  Result := False;
  AError := '';
  if FPattern = '' then
  begin
    AError := CXT(sFfErrEmpty);
    Exit;
  end;
  try
    M := TCFindMatcher.Create(FMatchMode, FPattern, FCaseSensitive);
    M.Free;
    Result := True;
  except
    on E: Exception do AError := E.Message;
  end;
end;

procedure TCFindFile.ConfigureWorker(AWorker: TCFindWorker);
begin
  AWorker.Root := FRoot;
  AWorker.Pattern := FPattern;
  AWorker.Mode := FMatchMode;
  AWorker.CaseSensitive := FCaseSensitive;
  AWorker.IncludeSubfolders := FIncludeSubfolders;
  AWorker.IncludeFiles := FIncludeFiles;
  AWorker.IncludeFolders := FIncludeFolders;
  AWorker.SearchHidden := FSearchHidden;
  AWorker.MaxResults := FMaxResults;
end;

function TCFindFile.Start: Boolean;
var
  Err: string;
  W: TCFindWorker;
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
  FFoundCount := 0;
  FScannedCount := 0;
  W := TCFindWorker.Create;
  ConfigureWorker(W);
  FThread := TCFindThread.Create(Self, W);
  Result := True;
end;

procedure TCFindFile.Stop;
begin
  if FThread <> nil then FThread.RequestStop;
end;

function TCFindFile.WaitFor(ATimeoutMs: Integer): Boolean;
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
  // FindAll 用：見つかったものを、そのまま、一覧に入れる
  TCFindCollector = class
    List: TStrings;
    procedure Item(const APath: string; AIsDir: Boolean);
  end;

procedure TCFindCollector.Item(const APath: string; AIsDir: Boolean);
begin
  List.Add(APath);
end;

function TCFindFile.FindAll(AResult: TStrings): Integer;
var
  W: TCFindWorker;
  C: TCFindCollector;
begin
  AResult.Clear;
  if not DirectoryExists(FRoot) then
    raise EInOutError.Create(Format(CXT(sSbErrNoRoot), [FRoot]));
  W := TCFindWorker.Create;
  C := TCFindCollector.Create;
  try
    C.List := AResult;
    ConfigureWorker(W);
    W.OnItem := @C.Item;
    W.Run;               // 式が正しくなければ ECFindPattern
    Result := W.Found;
  finally
    C.Free;
    W.Free;
  end;
end;

{ メインスレッドで、スレッドから受ける }

procedure TCFindFile.DeliverItems(AItems: TStrings);
var
  I: Integer;
  S: string;
begin
  if FDestroying then Exit;
  for I := 0 to AItems.Count - 1 do
  begin
    S := AItems[I];
    Inc(FFoundCount);
    if Assigned(FOnFound) then FOnFound(Self, Copy(S, 2, MaxInt), S[1] = 'D');
  end;
end;

procedure TCFindFile.DeliverProgress(const AFolder: string; AScanned: Int64; AFound: Integer);
begin
  if FDestroying then Exit;
  FScannedCount := AScanned;
  if Assigned(FOnProgress) then FOnProgress(Self, AFolder, AScanned, AFound);
end;

procedure TCFindFile.DeliverFinished(AThread: TCFindThread; AFound: Integer; AScanned: Int64;
  AReason: TCFindStopReason);
begin
  if FDestroying then Exit;
  FScannedCount := AScanned;
  // 先にスレッドを片づけて、OnFinished の中から、もう一度 Start できるようにする
  if FThread = AThread then FThread := nil;
  AThread.Detach;
  AThread.WaitFor;
  AThread.Free;
  if Assigned(FOnFinished) then FOnFinished(Self, AFound, AReason);
end;

end.
