{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCcmd
  TCcmd：cmd.exe（や PowerShell・ssh など、コンソールのプログラム）を、Windows の ConPTY（擬似コンソール）で動かし、
  入力・出力を、フォームに置いた部品につなぐ端末（実行時パッケージ cx）。
  ・画面は、WebView2 の中の xterm.js（runtime\terminal\terminal.html）で描く。エスケープシーケンスの解釈・色・
    カーソル・全角・選択・スクロールバック・検索は、xterm.js が受け持つ。
  ・リダイレクト（> >> 2>&1）・パイプ（|）は、cmd.exe が自分で処理する。
  ・TCcmdPty：ConPTY でシェルを動かす部分（画面・WebView は何も知らない。別の OS 用に差し替えられる単位）。
  ・TCcmd：画面（WebView2 と xterm.js）と、ConPTY をつなぐ部品。
  ・RunCapture：パイプ方式で実行し、標準出力・エラー出力・終了コードを別々に受ける。
  設計書：docs\TCcmd_Design.md }
unit uCcmd;

{$mode objfpc}{$H+}

interface

uses
  Windows, ActiveX, Classes, SysUtils, Types, Math, Controls, Graphics, Forms, Menus, ExtCtrls, Clipbrd,
  LCLType, LCLIntf, LMessages, SyncObjs,
  uWVBrowser, uWVWindowParent, uWVLoader, uWVTypes, uWVTypeLibrary, uWVEvents, uWVCoreWebView2Args,
  uCmonacos;

const
  cMaxCountMin = 100;
  cMaxCountMax = 10000;
  cMaxCountDef = 1000;
  cHistoryMaxDef = 1000;
  cLogMaxSizeDef = 10240;       { KB }
  cDefaultCols = 80;
  cDefaultRows = 24;

type
  TCcmdLogMode = (lmOff, lmPlain, lmRaw);
  TCcmdCursorStyle = (ccBlock, ccUnderline, ccBar);
  TCcmdBellMode = (bmNone, bmSound, bmFlash);

  TCcmdOutputEvent = procedure(Sender: TObject; const AText: string) of object;
  TCcmdExitEvent = procedure(Sender: TObject; AExitCode: Integer) of object;
  TCcmdResizeEvent = procedure(Sender: TObject; ACols, ARows: Integer) of object;
  TCcmdErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;

  TCcmdPtyDataEvent = procedure(const AData: string) of object;
  TCcmdPtyExitEvent = procedure(AExitCode: Integer) of object;

  TCcmdPty = class;

  { TCcmdPtyReader：出力の読み取りスレッド }
  TCcmdPtyReader = class(TThread)
  private
    FOwner: TCcmdPty;
    FLock: TCriticalSection;
    FBuf: string;               { メインスレッドへ渡す前にためた出力 }
    FQueued: Boolean;
    FExitCode: Integer;
    procedure Drain;
    procedure NotifyExit;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TCcmdPty);
    destructor Destroy; override;
  end;

  { TCcmdPty：ConPTY で、シェルを動かす }
  TCcmdPty = class
  private
    FPC: THandle;
    FInWrite, FOutRead: THandle;
    FProcess, FThread, FJob: THandle;
    FReader: TCcmdPtyReader;
    FProcessId: Cardinal;
    FActive: Boolean;
    FExited: Boolean;
    FOnData: TCcmdPtyDataEvent;
    FOnExit: TCcmdPtyExitEvent;
    procedure CloseHandles;
    procedure ReleaseAfterExit;
  public
    destructor Destroy; override;
    function Start(const AShell, AParams, AWorkDir: string; AEnv: TStrings;
      ACols, ARows: Integer; out AError: string): Boolean;
    procedure Write(const AData: string);
    procedure Resize(ACols, ARows: Integer);
    procedure Stop;
    property Active: Boolean read FActive;
    property ProcessId: Cardinal read FProcessId;
    property OnData: TCcmdPtyDataEvent read FOnData write FOnData;
    property OnExit: TCcmdPtyExitEvent read FOnExit write FOnExit;
  end;

  { TCcmd }

  TCcmd = class(TCustomPanel)
  private
    FPty: TCcmdPty;
    FWindowParent: TWVWindowParent;
    FBrowser: TWVBrowser;
    FInitTimer: TTimer;
    FThemeTimer: TTimer;
    FBrowserCreated: Boolean;
    FReady: Boolean;
    FCols, FRows: Integer;
    FPendingStart: Boolean;
    FPendingSend: TStringList;
    FHistory: TStringList;
    FEnvironment: TStrings;
    FDefaultMenu: TPopupMenu;
    FLogName: string;
    FLogBytes: Int64;
    FLogFailed: Boolean;
    FHistFile: string;
    FTitle: string;
    FExitCode: Integer;
    FStripState: Integer;
    FLineBuf: string;
    FSavePath: string;
    FLastDark: Boolean;
    { プロパティの値 }
    FShell, FParams, FWorkDir: string;
    FAutoStart, FCloseOnExit, FCursorBlink, FAutoCaption, FReadOnly: Boolean;
    FMaxCount, FHistoryMax, FLogMaxSize: Integer;
    FLogMode: TCcmdLogMode;
    FLogDir, FHistoryDir, FTerminalPath: string;
    FTheme: TCMTheme;
    FCursorStyle: TCcmdCursorStyle;
    FCursorColor, FSelectionColor: TColor;
    FBellMode: TCcmdBellMode;
    FOnReady, FOnStart, FOnTitleChange, FOnBell: TNotifyEvent;
    FOnExit: TCcmdExitEvent;
    FOnOutput, FOnLine, FOnCommand, FOnBufferText: TCcmdOutputEvent;
    FOnResize: TCcmdResizeEvent;
    FOnError: TCcmdErrorEvent;

    FPendingErr: string;
    function InDesigner: Boolean;
    procedure AsyncShowError(Data: PtrInt);
    procedure DoError(const AMessage: string);
    procedure BrowserAfterCreated(Sender: TObject);
    procedure BrowserInitError(Sender: TObject; aErrorCode: HRESULT; const aErrorMessage: wvstring);
    procedure BrowserWebMessageReceived(Sender: TObject; const aWebView: ICoreWebView2;
      const aArgs: ICoreWebView2WebMessageReceivedEventArgs);
    procedure InitTimerTick(Sender: TObject);
    procedure ThemeTimerTick(Sender: TObject);
    procedure PtyOutput(const AData: string);
    procedure PtyExited(AExitCode: Integer);
    procedure HandleMessage(const AMsg: string);
    procedure SendCmd(const ACmd, AArg: string);
    procedure SendOptions;
    procedure DoStart;
    procedure OpenLog;
    procedure WriteLog(const AText: string);
    procedure AddHistory(const ACmd: string);
    function IsDark: Boolean;
    function InputAllowed: Boolean;
    function TerminalDir: string;
    function StripVT(const S: string): string;
    procedure EmitLines(const APlain: string);
    procedure MenuCopyClick(Sender: TObject);
    procedure MenuPasteClick(Sender: TObject);
    procedure MenuSelectAllClick(Sender: TObject);
    procedure MenuClearClick(Sender: TObject);
    procedure SetShell(const AValue: string);
    procedure SetEnvironment(AValue: TStrings);
    procedure SetMaxCount(AValue: Integer);
    procedure SetHistoryMax(AValue: Integer);
    procedure SetTheme(AValue: TCMTheme);
    procedure SetCursorStyle(AValue: TCcmdCursorStyle);
    procedure SetCursorBlink(AValue: Boolean);
    procedure SetCursorColor(AValue: TColor);
    procedure SetSelectionColor(AValue: TColor);
    procedure SetReadOnly(AValue: Boolean);
    procedure SetCaptionText(const AValue: string);
    procedure SetAutoCaption(AValue: Boolean);
    function GetActive: Boolean;
    function GetProcessId: Cardinal;
    function GetCaptionText: string;
  protected
    procedure CreateWnd; override;
    procedure VisibleChanged; override;
    procedure EnabledChanged; override;
    procedure FontChanged(Sender: TObject); override;
    procedure CMColorChanged(var Message: TLMessage); message CM_COLORCHANGED;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetFocus; override;

    procedure Start;
    procedure Stop;
    procedure Restart;
    procedure SendText(const AText: string);
    procedure Execute(const ALine: string);
    procedure SendKey(AKey: Word; AShift: TShiftState);
    procedure SendCtrlC;
    procedure Paste;
    procedure CopySelection;
    procedure SelectAll;
    procedure ClearScrollback;
    procedure ScrollToBottom;
    procedure FindNext(const AText: string; AMatchCase: Boolean = False);
    procedure FindPrev(const AText: string; AMatchCase: Boolean = False);
    procedure RequestBufferText;
    procedure SaveBufferTo(const AFileName: string);
    function RunCapture(const ACommandLine: string; out AStdOut, AStdErr: string;
      out AExitCode: Integer; ATimeoutMs: Integer = 0): Boolean;
    procedure OpenDevTools;

    property Active: Boolean read GetActive;
    property ExitCode: Integer read FExitCode;
    property ProcessId: Cardinal read GetProcessId;
    property Cols: Integer read FCols;
    property Rows: Integer read FRows;
    property Title: string read FTitle;
    property Ready: Boolean read FReady;
    property CmdHistory: TStringList read FHistory;
  published
    property Shell: string read FShell write SetShell;
    property Params: string read FParams write FParams;
    property WorkDir: string read FWorkDir write FWorkDir;
    property Environment: TStrings read FEnvironment write SetEnvironment;
    property AutoStart: Boolean read FAutoStart write FAutoStart default True;
    property CloseOnExit: Boolean read FCloseOnExit write FCloseOnExit default False;
    property MaxCount: Integer read FMaxCount write SetMaxCount default cMaxCountDef;
    property LogMode: TCcmdLogMode read FLogMode write FLogMode default lmPlain;
    property LogDir: string read FLogDir write FLogDir;
    property LogMaxSize: Integer read FLogMaxSize write FLogMaxSize default cLogMaxSizeDef;
    property HistoryDir: string read FHistoryDir write FHistoryDir;
    property HistoryMax: Integer read FHistoryMax write SetHistoryMax default cHistoryMaxDef;
    property Theme: TCMTheme read FTheme write SetTheme default ctAuto;
    property CursorStyle: TCcmdCursorStyle read FCursorStyle write SetCursorStyle default ccBlock;
    property CursorBlink: Boolean read FCursorBlink write SetCursorBlink default True;
    property CursorColor: TColor read FCursorColor write SetCursorColor default clDefault;
    property SelectionColor: TColor read FSelectionColor write SetSelectionColor default clDefault;
    property Caption: string read GetCaptionText write SetCaptionText;
    property AutoCaption: Boolean read FAutoCaption write SetAutoCaption default True;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property BellMode: TCcmdBellMode read FBellMode write FBellMode default bmSound;
    property TerminalPath: string read FTerminalPath write FTerminalPath;
    property OnReady: TNotifyEvent read FOnReady write FOnReady;
    property OnStart: TNotifyEvent read FOnStart write FOnStart;
    property OnExit: TCcmdExitEvent read FOnExit write FOnExit;
    property OnOutput: TCcmdOutputEvent read FOnOutput write FOnOutput;
    property OnLine: TCcmdOutputEvent read FOnLine write FOnLine;
    property OnCommand: TCcmdOutputEvent read FOnCommand write FOnCommand;
    property OnTitleChange: TNotifyEvent read FOnTitleChange write FOnTitleChange;
    property OnBell: TNotifyEvent read FOnBell write FOnBell;
    property OnResize: TCcmdResizeEvent read FOnResize write FOnResize;
    property OnBufferText: TCcmdOutputEvent read FOnBufferText write FOnBufferText;
    property OnError: TCcmdErrorEvent read FOnError write FOnError;
    property Align;
    property Anchors;
    property BorderSpacing;
    property Color default clDefault;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
  end;

implementation

uses
  Dialogs, uCXLang, uCXRuntime, uCsEditor;

const
  SEP = #1;
  SEP2 = #2;
  VHOST = 'cmterminal.example';

  { ConPTY・ジョブオブジェクトの定数（FPC の windows ユニットに無いので、自分で宣言する） }
  PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE = $00020016;
  JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = $00002000;
  JobObjectExtendedLimitInformation = 9;
  CC_IDLE_MS = 150;

type
  TCcCoordRec = record
    X, Y: SmallInt;
  end;
  TCcStartupInfoEx = record
    StartupInfo: TStartupInfoW;
    lpAttributeList: Pointer;
  end;
  TCcIoCounters = record
    A, B, C, D, E, F: QWord;
  end;
  TCcJobBasicLimit = record
    PerProcessUserTimeLimit: Int64;
    PerJobUserTimeLimit: Int64;
    LimitFlags: DWORD;
    MinimumWorkingSetSize: PtrUInt;
    MaximumWorkingSetSize: PtrUInt;
    ActiveProcessLimit: DWORD;
    Affinity: PtrUInt;
    PriorityClass: DWORD;
    SchedulingClass: DWORD;
  end;
  TCcJobExtendedLimit = record
    BasicLimitInformation: TCcJobBasicLimit;
    IoInfo: TCcIoCounters;
    ProcessMemoryLimit: PtrUInt;
    JobMemoryLimit: PtrUInt;
    PeakProcessMemoryUsed: PtrUInt;
    PeakJobMemoryUsed: PtrUInt;
  end;

  TFnCreatePseudoConsole = function(Size: DWORD; hInput, hOutput: THandle; Flags: DWORD;
    var phPC: THandle): HRESULT; stdcall;
  TFnResizePseudoConsole = function(hPC: THandle; Size: DWORD): HRESULT; stdcall;
  TFnClosePseudoConsole = procedure(hPC: THandle); stdcall;
  TFnInitAttrList = function(List: Pointer; Count, Flags: DWORD; var Size: PtrUInt): BOOL; stdcall;
  TFnUpdateAttr = function(List: Pointer; Flags: DWORD; Attribute: PtrUInt; Value: Pointer;
    Size: PtrUInt; Prev: Pointer; RetSize: Pointer): BOOL; stdcall;
  TFnDeleteAttrList = procedure(List: Pointer); stdcall;

var
  GCreatePC: TFnCreatePseudoConsole = nil;
  GResizePC: TFnResizePseudoConsole = nil;
  GClosePC: TFnClosePseudoConsole = nil;
  GInitAttr: TFnInitAttrList = nil;
  GUpdateAttr: TFnUpdateAttr = nil;
  GDeleteAttr: TFnDeleteAttrList = nil;
  GApiChecked: Boolean = False;
  GApiOk: Boolean = False;

function CreateJobObjectW(lpJobAttributes: Pointer; lpName: PWideChar): THandle; stdcall; external 'kernel32.dll';
function SetInformationJobObject(hJob: THandle; InfoClass: DWORD; lpInfo: Pointer;
  cbLength: DWORD): BOOL; stdcall; external 'kernel32.dll';
function AssignProcessToJobObject(hJob, hProcess: THandle): BOOL; stdcall; external 'kernel32.dll';
function TerminateJobObject(hJob: THandle; uExitCode: UINT): BOOL; stdcall; external 'kernel32.dll';

{ ---------- 道具 ---------- }

function WVStr(const S: string): wvstring;
begin
  Result := UTF8Decode(S);
end;

function FromWV(const S: wvstring): string;
begin
  Result := UTF8Encode(UnicodeString(S));
end;

function ExeDir: string;
begin
  Result := ExtractFilePath(ParamStr(0));
end;

{ ConPTY の関数を、実行時に探す（古い Windows でも、アプリが起動できるように） }
function LoadConPtyApi: Boolean;
var
  H: HMODULE;
begin
  if GApiChecked then Exit(GApiOk);
  GApiChecked := True;
  H := GetModuleHandle('kernel32.dll');
  GCreatePC := TFnCreatePseudoConsole(GetProcAddress(H, 'CreatePseudoConsole'));
  GResizePC := TFnResizePseudoConsole(GetProcAddress(H, 'ResizePseudoConsole'));
  GClosePC := TFnClosePseudoConsole(GetProcAddress(H, 'ClosePseudoConsole'));
  GInitAttr := TFnInitAttrList(GetProcAddress(H, 'InitializeProcThreadAttributeList'));
  GUpdateAttr := TFnUpdateAttr(GetProcAddress(H, 'UpdateProcThreadAttribute'));
  GDeleteAttr := TFnDeleteAttrList(GetProcAddress(H, 'DeleteProcThreadAttributeList'));
  GApiOk := Assigned(GCreatePC) and Assigned(GResizePC) and Assigned(GClosePC) and
    Assigned(GInitAttr) and Assigned(GUpdateAttr) and Assigned(GDeleteAttr);
  Result := GApiOk;
end;

function MakeCoord(ACols, ARows: Integer): DWORD;
begin
  Result := (DWORD(Word(ARows)) shl 16) or Word(ACols);
end;

{ 文字列の先頭から、UTF-8 として完結している長さ（末尾の不完全な 1〜3 バイトは含めない） }
function Utf8CompleteLen(const S: string): Integer;
var
  I, Need, Have: Integer;
  B: Byte;
begin
  Result := Length(S);
  I := Length(S);
  Have := 0;
  while (I >= 1) and (Have < 4) do
  begin
    B := Byte(S[I]);
    Inc(Have);
    if (B and $C0) <> $80 then
    begin
      if (B and $80) = 0 then Need := 1
      else if (B and $E0) = $C0 then Need := 2
      else if (B and $F0) = $E0 then Need := 3
      else if (B and $F8) = $F0 then Need := 4
      else Need := 1;
      if Have < Need then Result := I - 1;
      Exit;
    end;
    Dec(I);
  end;
end;

{ 環境ブロック：親の環境に、AEnv の「名前=値」を上書き・追加する }
function BuildEnvBlock(AEnv: TStrings): UnicodeString;
var
  P0, P: PWideChar;
  L: TStringList;
  S: UnicodeString;
  I, K: Integer;
  Name: string;
begin
  L := TStringList.Create;
  try
    L.CaseSensitive := False;
    P0 := GetEnvironmentStringsW;
    if P0 <> nil then
    try
      P := P0;
      while P^ <> #0 do
      begin
        S := P;
        L.Add(UTF8Encode(S));
        Inc(P, Length(S) + 1);
      end;
    finally
      FreeEnvironmentStringsW(P0);
    end;
    if AEnv <> nil then
      for I := 0 to AEnv.Count - 1 do
      begin
        K := Pos('=', AEnv[I]);
        if K <= 1 then Continue;
        Name := Copy(AEnv[I], 1, K - 1);
        { 既にあれば置き換える（名前の大文字小文字は区別しない） }
        K := 0;
        while K < L.Count do
        begin
          if SameText(Copy(L[K], 1, Length(Name) + 1), Name + '=') then Break;
          Inc(K);
        end;
        if K < L.Count then L[K] := AEnv[I] else L.Add(AEnv[I]);
      end;
    Result := '';
    for I := 0 to L.Count - 1 do
      Result := Result + UTF8Decode(L[I]) + #0;
    Result := Result + #0;
  finally
    L.Free;
  end;
end;

{ 区切り文字で分ける（string のヘルパーに頼らない） }
function SplitSep(const S: string; ASep: Char): TStringDynArray;
var
  I, Start, N: Integer;
begin
  SetLength(Result, 0);
  N := 0;
  Start := 1;
  for I := 1 to Length(S) + 1 do
    if (I > Length(S)) or (S[I] = ASep) then
    begin
      SetLength(Result, N + 1);
      Result[N] := Copy(S, Start, I - Start);
      Inc(N);
      Start := I + 1;
    end;
end;

function MatchFlag(AValue: Boolean): string;
begin
  if AValue then Result := '1' else Result := '0';
end;

function ColorToHex(AColor: TColor): string;
var
  C: Cardinal;
begin
  C := Cardinal(ColorToRGB(AColor));
  Result := '#' + IntToHex(C and $FF, 2) + IntToHex((C shr 8) and $FF, 2) + IntToHex((C shr 16) and $FF, 2);
end;

{ ---------- TCcmdPtyReader ---------- }

constructor TCcmdPtyReader.Create(AOwner: TCcmdPty);
begin
  FOwner := AOwner;
  FLock := TCriticalSection.Create;
  FExitCode := -1;
  inherited Create(False);
end;

destructor TCcmdPtyReader.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

{ メインスレッドで：ためた出力を渡す }
procedure TCcmdPtyReader.Drain;
var
  S: string;
begin
  FLock.Enter;
  try
    S := FBuf;
    FBuf := '';
    FQueued := False;
  finally
    FLock.Leave;
  end;
  if (S <> '') and Assigned(FOwner) and Assigned(FOwner.FOnData) then
    FOwner.FOnData(S);
end;

procedure TCcmdPtyReader.NotifyExit;
var
  Owner: TCcmdPty;
begin
  Owner := FOwner;
  if Owner = nil then Exit;
  Owner.FExited := True;
  Owner.FActive := False;
  Owner.ReleaseAfterExit;                { 擬似コンソールを閉じる（先に片付けてから、通知する） }
  if Assigned(Owner.FOnExit) then Owner.FOnExit(FExitCode);
end;

{ 出力を読む。ConPTY は、シェルが終わっても、出力のパイプを閉じない（ClosePseudoConsole まで開いたまま）ので、
  ReadFile で待ち続けると、終わりが分からない。パイプの中身を調べながら、シェルが終わったかを、自分で見る。 }
procedure TCcmdPtyReader.Execute;
var
  Buf: array[0..8191] of Byte;
  Got, Avail, Want: DWORD;
  Pending, Chunk: string;
  N, Cut, Idle: Integer;
  Code: DWORD;
  HRead, HProc: THandle;
  ExitSeen: Boolean;

  procedure Push(const AText: string);
  begin
    FLock.Enter;
    try
      FBuf := FBuf + AText;
      if not FQueued then
      begin
        FQueued := True;
        Queue(@Drain);
      end;
    finally
      FLock.Leave;
    end;
  end;

begin
  HRead := FOwner.FOutRead;       { 停止の途中で FOwner が空になっても使えるように、手元へ写す }
  HProc := FOwner.FProcess;
  Pending := '';
  Idle := 0;
  ExitSeen := False;
  while not Terminated do
  begin
    Avail := 0;
    if not PeekNamedPipe(HRead, nil, 0, nil, @Avail, nil) then Break;       { パイプが閉じた }
    if Avail > 0 then
    begin
      Idle := 0;
      Want := Avail;
      if Want > SizeOf(Buf) then Want := SizeOf(Buf);
      Got := 0;
      if not ReadFile(HRead, Buf, Want, Got, nil) then Break;
      if Got = 0 then Continue;
      N := Length(Pending);
      SetLength(Pending, N + Integer(Got));
      Move(Buf[0], Pending[N + 1], Got);
      Cut := Utf8CompleteLen(Pending);
      if Cut > 0 then
      begin
        Chunk := Copy(Pending, 1, Cut);
        Delete(Pending, 1, Cut);
        Push(Chunk);
      end;
    end
    else
    begin
      if ExitSeen then Break;                         { 終わった後、もう出力が無い }
      if (HProc <> 0) and (WaitForSingleObject(HProc, 0) = WAIT_OBJECT_0) then
      begin
        ExitSeen := True;                             { 最後の出力を取り切るため、少し待って、もう一度見る }
        Sleep(150);
      end
      else
      begin
        Inc(Idle);
        if Idle < 20 then Sleep(1) else Sleep(8);
      end;
    end;
  end;
  if Pending <> '' then Push(Pending);
  Code := 0;
  if HProc <> 0 then
  begin
    WaitForSingleObject(HProc, 3000);
    GetExitCodeProcess(HProc, Code);
  end;
  FExitCode := Integer(Code);
  Queue(@NotifyExit);
end;

{ ---------- TCcmdPty ---------- }

destructor TCcmdPty.Destroy;
begin
  FOnData := nil;
  FOnExit := nil;
  Stop;
  inherited Destroy;
end;

procedure TCcmdPty.CloseHandles;
begin
  if FInWrite <> 0 then begin CloseHandle(FInWrite); FInWrite := 0; end;
  if FOutRead <> 0 then begin CloseHandle(FOutRead); FOutRead := 0; end;
  if FThread <> 0 then begin CloseHandle(FThread); FThread := 0; end;
  if FProcess <> 0 then begin CloseHandle(FProcess); FProcess := 0; end;
  if FJob <> 0 then begin CloseHandle(FJob); FJob := 0; end;
end;

{ シェルが自分で終わった後：擬似コンソールと、ハンドルを閉じる（読み取りスレッドは、もう読み終えている） }
procedure TCcmdPty.ReleaseAfterExit;
begin
  if FPC <> 0 then
  begin
    GClosePC(FPC);
    FPC := 0;
  end;
  CloseHandles;
  FProcessId := 0;
end;

function TCcmdPty.Start(const AShell, AParams, AWorkDir: string; AEnv: TStrings;
  ACols, ARows: Integer; out AError: string): Boolean;
var
  InRead, OutWrite: THandle;
  SI: TCcStartupInfoEx;
  PI: TProcessInformation;
  AttrSize: PtrUInt;
  CmdLine: UnicodeString;
  Shell: string;
  Env, WorkDir: UnicodeString;
  Lim: TCcJobExtendedLimit;
begin
  Result := False;
  AError := '';
  if FActive then Exit(True);
  Stop;                         { 前のシェルが終わった後の、残りのハンドルを片付ける }
  if not LoadConPtyApi then
  begin
    AError := CXT(sCcmdErrNoPty);
    Exit;
  end;
  FExited := False;
  InRead := 0; OutWrite := 0;
  if not CreatePipe(InRead, FInWrite, nil, 0) then
  begin
    AError := SysErrorMessage(GetLastError);
    Exit;
  end;
  if not CreatePipe(FOutRead, OutWrite, nil, 0) then
  begin
    AError := SysErrorMessage(GetLastError);
    CloseHandle(InRead);
    CloseHandles;
    Exit;
  end;
  if GCreatePC(MakeCoord(Max(ACols, 1), Max(ARows, 1)), InRead, OutWrite, 0, FPC) <> 0 then
  begin
    AError := CXT(sCcmdErrNoPty);
    CloseHandle(InRead);
    CloseHandle(OutWrite);
    CloseHandles;
    Exit;
  end;
  CloseHandle(InRead);
  CloseHandle(OutWrite);

  FillChar(SI, SizeOf(SI), 0);
  SI.StartupInfo.cb := SizeOf(SI);
  { 親の標準ハンドルを、子へ引き継がない（親にコンソールがない・パイプのときに、子の出力が擬似コンソールへ行かなくなるのを防ぐ） }
  SI.StartupInfo.dwFlags := STARTF_USESTDHANDLES;
  AttrSize := 0;
  GInitAttr(nil, 1, 0, AttrSize);
  SI.lpAttributeList := GetMem(AttrSize);
  GInitAttr(SI.lpAttributeList, 1, 0, AttrSize);
  GUpdateAttr(SI.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, Pointer(FPC), SizeOf(THandle), nil, nil);

  Shell := Trim(AShell);
  if Shell = '' then Shell := 'cmd.exe';
  if (Pos(' ', Shell) > 0) and (Shell[1] <> '"') then Shell := '"' + Shell + '"';
  CmdLine := UTF8Decode(Shell);
  if Trim(AParams) <> '' then CmdLine := CmdLine + ' ' + UTF8Decode(AParams);
  UniqueString(CmdLine);
  Env := BuildEnvBlock(AEnv);
  if AWorkDir <> '' then WorkDir := UTF8Decode(AWorkDir) else WorkDir := UTF8Decode(ExcludeTrailingPathDelimiter(ExeDir));
  FillChar(PI, SizeOf(PI), 0);
  if not CreateProcessW(nil, PWideChar(CmdLine), nil, nil, False,
       EXTENDED_STARTUPINFO_PRESENT or CREATE_UNICODE_ENVIRONMENT, PWideChar(Env), PWideChar(WorkDir),
       SI.StartupInfo, PI) then
  begin
    AError := SysErrorMessage(GetLastError);
    GDeleteAttr(SI.lpAttributeList);
    FreeMem(SI.lpAttributeList);
    GClosePC(FPC);
    FPC := 0;
    CloseHandles;
    Exit;
  end;
  GDeleteAttr(SI.lpAttributeList);
  FreeMem(SI.lpAttributeList);
  FProcess := PI.hProcess;
  FThread := PI.hThread;
  FProcessId := PI.dwProcessId;

  { ジョブオブジェクト：止めるとき・壊すときに、孫のプロセスまで、まとめて止める }
  FJob := CreateJobObjectW(nil, nil);
  if FJob <> 0 then
  begin
    FillChar(Lim, SizeOf(Lim), 0);
    Lim.BasicLimitInformation.LimitFlags := JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    SetInformationJobObject(FJob, JobObjectExtendedLimitInformation, @Lim, SizeOf(Lim));
    AssignProcessToJobObject(FJob, FProcess);
  end;

  FActive := True;
  FReader := TCcmdPtyReader.Create(Self);
  Result := True;
end;

procedure TCcmdPty.Write(const AData: string);
var
  Done, Got: DWORD;
begin
  if (not FActive) or (FInWrite = 0) or (AData = '') then Exit;
  Done := 0;
  while Done < DWORD(Length(AData)) do
  begin
    Got := 0;
    if not WriteFile(FInWrite, AData[Done + 1], DWORD(Length(AData)) - Done, Got, nil) then Exit;
    Inc(Done, Got);
  end;
end;

procedure TCcmdPty.Resize(ACols, ARows: Integer);
begin
  if FActive and (FPC <> 0) and Assigned(GResizePC) then
    GResizePC(FPC, MakeCoord(Max(ACols, 1), Max(ARows, 1)));
end;

procedure TCcmdPty.Stop;
var
  R: TCcmdPtyReader;
begin
  if (FPC = 0) and (FReader = nil) and (FProcess = 0) then Exit;
  if FJob <> 0 then TerminateJobObject(FJob, 1)
  else if FProcess <> 0 then TerminateProcess(FProcess, 1);
  if FPC <> 0 then
  begin
    { 擬似コンソールを閉じる。読み取りスレッドが、パイプが閉じるまで読み続けるので、固まらない }
    GClosePC(FPC);
    FPC := 0;
  end;
  R := FReader;
  FReader := nil;
  if R <> nil then
  begin
    R.FOwner := nil;           { これ以降、スレッドは、この部品へ通知しない }
    R.WaitFor;
    TThread.RemoveQueuedEvents(R);
    R.Free;
  end;
  FActive := False;
  CloseHandles;
  FProcessId := 0;
end;

{ ---------- TCcmd ---------- }

constructor TCcmd.Create(AOwner: TComponent);
var
  MI: TMenuItem;
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csSetCaption];
  BevelOuter := bvNone;
  BevelInner := bvNone;
  Width := 500;
  Height := 300;
  TabStop := True;
  Color := clDefault;
  ParentFont := False;
  Font.Name := 'Consolas';
  Font.Size := 10;
  Font.Color := clDefault;

  FShell := 'cmd.exe';
  FAutoStart := True;
  FMaxCount := cMaxCountDef;
  FHistoryMax := cHistoryMaxDef;
  FLogMaxSize := cLogMaxSizeDef;
  FLogMode := lmPlain;
  FTheme := ctAuto;
  FCursorStyle := ccBlock;
  FCursorBlink := True;
  FCursorColor := clDefault;
  FSelectionColor := clDefault;
  FAutoCaption := True;
  FBellMode := bmSound;
  FExitCode := -1;
  FCols := cDefaultCols;
  FRows := cDefaultRows;
  FEnvironment := TStringList.Create;
  FHistory := TStringList.Create;
  FPendingSend := TStringList.Create;

  if InDesigner then Exit;      { 設計時は、WebView2 も ConPTY も動かさない }

  FPty := TCcmdPty.Create;
  FPty.OnData := @PtyOutput;
  FPty.OnExit := @PtyExited;

  FWindowParent := TCXWVWindowParent.Create(Self);
  FWindowParent.Parent := Self;
  FWindowParent.Align := alClient;

  FBrowser := TWVBrowser.Create(Self);
  FBrowser.OnAfterCreated := @BrowserAfterCreated;
  FBrowser.OnInitializationError := @BrowserInitError;
  FBrowser.OnWebMessageReceived := @BrowserWebMessageReceived;
  FBrowser.AreBrowserAcceleratorKeysEnabled := False;
  FBrowser.ZoomControlEnabled := False;
  FBrowser.DevToolsEnabled := False;
  FBrowser.StatusBarEnabled := False;
  FWindowParent.Browser := FBrowser;

  FInitTimer := TTimer.Create(Self);
  FInitTimer.Enabled := False;
  FInitTimer.Interval := 100;
  FInitTimer.OnTimer := @InitTimerTick;

  FThemeTimer := TTimer.Create(Self);
  FThemeTimer.Enabled := False;
  FThemeTimer.Interval := 3000;
  FThemeTimer.OnTimer := @ThemeTimerTick;

  FDefaultMenu := TPopupMenu.Create(Self);
  MI := TMenuItem.Create(FDefaultMenu);
  MI.Caption := CXT(sCcmdMenuCopy);
  MI.OnClick := @MenuCopyClick;
  FDefaultMenu.Items.Add(MI);
  MI := TMenuItem.Create(FDefaultMenu);
  MI.Caption := CXT(sCcmdMenuPaste);
  MI.OnClick := @MenuPasteClick;
  FDefaultMenu.Items.Add(MI);
  MI := TMenuItem.Create(FDefaultMenu);
  MI.Caption := CXT(sCcmdMenuSelectAll);
  MI.OnClick := @MenuSelectAllClick;
  FDefaultMenu.Items.Add(MI);
  MI := TMenuItem.Create(FDefaultMenu);
  MI.Caption := '-';
  FDefaultMenu.Items.Add(MI);
  MI := TMenuItem.Create(FDefaultMenu);
  MI.Caption := CXT(sCcmdMenuClear);
  MI.OnClick := @MenuClearClick;
  FDefaultMenu.Items.Add(MI);
end;

destructor TCcmd.Destroy;
begin
  if FInitTimer <> nil then FInitTimer.Enabled := False;
  if FThemeTimer <> nil then FThemeTimer.Enabled := False;
  Application.RemoveAsyncCalls(Self);
  if FPty <> nil then
  begin
    FPty.OnData := nil;
    FPty.OnExit := nil;
    FPty.Stop;
    FreeAndNil(FPty);
  end;
  FreeAndNil(FPendingSend);
  FreeAndNil(FHistory);
  FreeAndNil(FEnvironment);
  inherited Destroy;
end;

{ 設計時かどうか（複合部品の中に入れた場合も、親をたどって判定する） }
function TCcmd.InDesigner: Boolean;
var
  C: TControl;
begin
  Result := False;
  if (csDesigning in ComponentState) or
     ((Owner <> nil) and (csDesigning in Owner.ComponentState)) then Exit(True);
  C := Parent;
  while C <> nil do
  begin
    if csDesigning in C.ComponentState then Exit(True);
    C := C.Parent;
  end;
end;

var
  GShownErrors: TStringList = nil;

procedure TCcmd.AsyncShowError(Data: PtrInt);
var
  Msg: string;
begin
  if FPendingErr = '' then Exit;
  Msg := FPendingErr;
  FPendingErr := '';
  ShowMessage(Msg);
end;

procedure TCcmd.DoError(const AMessage: string);
begin
  if Assigned(FOnError) then
  begin
    FOnError(Self, AMessage);
    Exit;
  end;
  { OnError が無いときは、同じ文を 1 回だけ、画面に出す }
  if GShownErrors = nil then GShownErrors := TStringList.Create;
  if GShownErrors.IndexOf(AMessage) >= 0 then Exit;
  GShownErrors.Add(AMessage);
  FPendingErr := AMessage;
  Application.QueueAsyncCall(@AsyncShowError, 0);
end;

function TCcmd.IsDark: Boolean;
begin
  case FTheme of
    ctDark: Result := True;
    ctLight: Result := False;
  else
    Result := CsOsIsDark;
  end;
end;

function TCcmd.InputAllowed: Boolean;
begin
  Result := Enabled and not FReadOnly;
end;

function TCcmd.TerminalDir: string;
begin
  Result := CXResolveRuntimeDir(FTerminalPath, 'TerminalFolder', 'terminal');
end;

{ ---------- WebView2 の準備 ---------- }

procedure TCcmd.CreateWnd;
begin
  inherited CreateWnd;
  if not InDesigner and not FBrowserCreated then
    FInitTimer.Enabled := True;
end;

procedure TCcmd.VisibleChanged;
begin
  inherited VisibleChanged;
  if InDesigner then Exit;
  if Visible then
  begin
    if not FBrowserCreated then
      FInitTimer.Enabled := True
    else if FReady then
    begin
      FBrowser.IsVisible := True;
      FWindowParent.UpdateSize;
      FBrowser.NotifyParentWindowPositionChanged;
    end;
  end
  else if FReady then
    FBrowser.IsVisible := False;
end;

procedure TCcmd.EnabledChanged;
begin
  inherited EnabledChanged;
  if (not InDesigner) and FReady then SendOptions;
end;

procedure TCcmd.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  if (not InDesigner) and FReady then SendOptions;
end;

procedure TCcmd.CMColorChanged(var Message: TLMessage);
begin
  inherited;
  if (not InDesigner) and FReady then SendOptions;
end;

procedure TCcmd.InitTimerTick(Sender: TObject);
var
  Err: string;
begin
  if FBrowserCreated then
  begin
    FInitTimer.Enabled := False;
    Exit;
  end;
  if not Visible then
  begin
    FInitTimer.Enabled := False;
    Exit;
  end;
  if not Showing then Exit;
  if GlobalWebView2Loader = nil then
    if not CXStartWebView2(Err) then
    begin
      FInitTimer.Enabled := False;
      DoError(Err);
      Exit;
    end;
  if GlobalWebView2Loader.InitializationError then
  begin
    FInitTimer.Enabled := False;
    DoError(FromWV(GlobalWebView2Loader.ErrorMessage));
    Exit;
  end;
  if GlobalWebView2Loader.Initialized then
  begin
    FInitTimer.Enabled := False;
    FBrowserCreated := True;
    FBrowser.CreateBrowser(FWindowParent.Handle);
  end;
end;

procedure TCcmd.BrowserAfterCreated(Sender: TObject);
var
  Dir: string;
begin
  FWindowParent.UpdateSize;
  Dir := TerminalDir;
  if not FileExists(Dir + PathDelim + 'terminal.html') then
  begin
    DoError(Format(CXT(sCcmdErrNoPage), [Dir]));
    Exit;
  end;
  FBrowser.SetVirtualHostNameToFolderMapping(WVStr(VHOST), WVStr(Dir),
    COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW);
  FBrowser.Navigate(WVStr('https://' + VHOST + '/terminal.html'));
end;

procedure TCcmd.BrowserInitError(Sender: TObject; aErrorCode: HRESULT; const aErrorMessage: wvstring);
begin
  DoError(FromWV(aErrorMessage));
end;

procedure TCcmd.BrowserWebMessageReceived(Sender: TObject; const aWebView: ICoreWebView2;
  const aArgs: ICoreWebView2WebMessageReceivedEventArgs);
var
  Args: TCoreWebView2WebMessageReceivedEventArgs;
  S, Paths: string;
  Coll: ICoreWebView2ObjectCollectionView;
  Obj: IUnknown;
  AFile: ICoreWebView2File;
  Cnt, I: SYSUINT;
  PW: PWideChar;
begin
  Paths := '';
  Args := TCoreWebView2WebMessageReceivedEventArgs.Create(aArgs);
  try
    S := FromWV(Args.WebMessageAsString);
    if S = 'drop' then
    begin
      { Explorer からのドロップ：ファイルの場所を取り出し、空白があれば " で囲んで、空白でつなぐ }
      Coll := Args.AdditionalObjects;
      if (Coll <> nil) and Succeeded(Coll.Get_Count(Cnt)) then
        for I := 0 to Cnt - 1 do
        begin
          Obj := nil;
          if Succeeded(Coll.GetValueAtIndex(I, Obj)) and (Obj <> nil) and
             Succeeded(Obj.QueryInterface(ICoreWebView2File, AFile)) and
             Succeeded(AFile.Get_Path(PW)) and (PW <> nil) then
          begin
            S := FromWV(PW);
            CoTaskMemFree(PW);
            if Pos(' ', S) > 0 then S := '"' + S + '"';
            if Paths <> '' then Paths := Paths + ' ';
            Paths := Paths + S;
          end;
        end;
      if (Paths <> '') and InputAllowed then
      begin
        SendCmd('paste', Paths);
        SendCmd('focus', '');
      end;
      Exit;
    end;
  finally
    Args.Free;
  end;
  HandleMessage(S);
end;

procedure TCcmd.SendCmd(const ACmd, AArg: string);
begin
  if FReady then
    FBrowser.PostWebMessageAsString(WVStr(ACmd + SEP + AArg));
end;

procedure TCcmd.SendOptions;
var
  FamilyName, Fam, Opts: string;
  PxSize: Integer;
  Fg, Bg: string;

  procedure Add(const AName, AValue: string);
  begin
    if Opts <> '' then Opts := Opts + SEP2;
    Opts := Opts + AName + '=' + AValue;
  end;

begin
  if not FReady then Exit;
  FamilyName := StringReplace(Font.Name, '"', '', [rfReplaceAll]);
  Fam := '"' + FamilyName + '", Consolas, "BIZ UDGothic", "MS Gothic", monospace';
  if Font.Size > 0 then PxSize := Round(Font.Size * 96 / 72) else PxSize := 13;
  if (Font.Color = clDefault) or (Font.Color = clWindowText) then Fg := '' else Fg := ColorToHex(Font.Color);
  if Color = clDefault then Bg := '' else Bg := ColorToHex(Color);
  Opts := '';
  Add('fontFamily', Fam);
  Add('fontSize', IntToStr(PxSize));
  Add('fgColor', Fg);
  Add('bgColor', Bg);
  if FCursorColor = clDefault then Add('cursorColor', '') else Add('cursorColor', ColorToHex(FCursorColor));
  if FSelectionColor = clDefault then Add('selColor', '') else Add('selColor', ColorToHex(FSelectionColor));
  if IsDark then Add('theme', 'dark') else Add('theme', 'light');
  case FCursorStyle of
    ccUnderline: Add('cursorStyle', 'underline');
    ccBar: Add('cursorStyle', 'bar');
  else
    Add('cursorStyle', 'block');
  end;
  if FCursorBlink then Add('cursorBlink', '1') else Add('cursorBlink', '0');
  Add('scrollback', IntToStr(FMaxCount));
  if InputAllowed then Add('disabled', '0') else Add('disabled', '1');
  SendCmd('opt', Opts);
  FLastDark := IsDark;
  { 背景のまわり（この部品の余白）も、同じ色にする }
  if Color <> clDefault then FWindowParent.Color := Color;
end;

procedure TCcmd.ThemeTimerTick(Sender: TObject);
begin
  if (FTheme = ctAuto) and FReady and Visible and (IsDark <> FLastDark) then SendOptions;
end;

{ ---------- ページからの通知 ---------- }

procedure TCcmd.HandleMessage(const AMsg: string);
var
  P: Integer;
  Cmd, Raw: string;
  Parts: TStringDynArray;
  Pt: TPoint;
  C, R: Integer;
begin
  P := Pos(SEP, AMsg);
  if P = 0 then
  begin
    Cmd := AMsg;
    Raw := '';
  end
  else
  begin
    Cmd := Copy(AMsg, 1, P - 1);
    Raw := Copy(AMsg, P + 1, MaxInt);
  end;

  if Cmd = 'ready' then
  begin
    FReady := True;
    FThemeTimer.Enabled := True;
    SendOptions;
    while FPendingSend.Count > 0 do
    begin
      SendCmd('out', FPendingSend[0]);
      FPendingSend.Delete(0);
    end;
    if Assigned(FOnReady) then FOnReady(Self);
    if FAutoStart or FPendingStart then
    begin
      FPendingStart := False;
      DoStart;
    end;
  end
  else if Cmd = 'input' then
  begin
    if InputAllowed then FPty.Write(Raw);
  end
  else if Cmd = 'resize' then
  begin
    Parts := SplitSep(Raw, SEP);
    if Length(Parts) >= 2 then
    begin
      C := StrToIntDef(Parts[0], FCols);
      R := StrToIntDef(Parts[1], FRows);
      if (C <> FCols) or (R <> FRows) then
      begin
        FCols := C;
        FRows := R;
        FPty.Resize(C, R);
        if Assigned(FOnResize) then FOnResize(Self, C, R);
      end;
    end;
  end
  else if Cmd = 'title' then
  begin
    FTitle := Raw;
    if FAutoCaption then inherited Caption := Raw;
    if Assigned(FOnTitleChange) then FOnTitleChange(Self);
  end
  else if Cmd = 'bell' then
  begin
    case FBellMode of
      bmSound: MessageBeep(MB_OK);
      bmFlash: SendCmd('bell', '');
    end;
    if Assigned(FOnBell) then FOnBell(Self);
  end
  else if Cmd = 'cmd' then
  begin
    AddHistory(Raw);
    if Assigned(FOnCommand) then FOnCommand(Self, Raw);
  end
  else if Cmd = 'selection' then
  begin
    if Raw <> '' then Clipboard.AsText := Raw;
  end
  else if Cmd = 'buffertext' then
  begin
    if FSavePath <> '' then
    begin
      try
        with TStringList.Create do
        try
          Text := Raw;
          SaveToFile(FSavePath);
        finally
          Free;
        end;
      except
        on E: Exception do DoError(FSavePath + ': ' + E.Message);
      end;
      FSavePath := '';
    end;
    if Assigned(FOnBufferText) then FOnBufferText(Self, Raw);
  end
  else if Cmd = 'zoom' then
  begin
    { Ctrl+ホイール：文字の大きさを 1 ずつ変える（6〜48） }
    C := Font.Size;
    if C <= 0 then C := 10;
    if StrToIntDef(Raw, 0) > 0 then Inc(C) else Dec(C);
    if C < 6 then C := 6;
    if C > 48 then C := 48;
    if C <> Font.Size then Font.Size := C;
  end
  else if Cmd = 'ctrlv' then
    Paste
  else if Cmd = 'menu' then
  begin
    Parts := SplitSep(Raw, SEP);
    if Length(Parts) >= 2 then
    begin
      Pt := FWindowParent.ClientToScreen(Point(StrToIntDef(Parts[0], 0), StrToIntDef(Parts[1], 0)));
      if PopupMenu <> nil then PopupMenu.PopUp(Pt.X, Pt.Y)
      else FDefaultMenu.PopUp(Pt.X, Pt.Y);
    end;
  end;
end;

{ ---------- シェルの起動と出力 ---------- }

procedure TCcmd.Start;
begin
  if InDesigner then Exit;
  if FPty.Active then Exit;
  if not FReady then
  begin
    FPendingStart := True;
    if (not FBrowserCreated) and Visible then FInitTimer.Enabled := True;
    Exit;
  end;
  DoStart;
end;

procedure TCcmd.DoStart;
var
  Err: string;
begin
  if FPty.Active then Exit;
  FStripState := 0;
  FLineBuf := '';
  if not FPty.Start(FShell, FParams, FWorkDir, FEnvironment, FCols, FRows, Err) then
  begin
    DoError(Format(CXT(sCcmdErrStart), [Err]));
    Exit;
  end;
  FExitCode := -1;
  OpenLog;
  FHistFile := '';
  if Assigned(FOnStart) then FOnStart(Self);
end;

procedure TCcmd.Stop;
begin
  if FPty <> nil then FPty.Stop;
end;

procedure TCcmd.Restart;
begin
  Stop;
  Start;
end;

procedure TCcmd.PtyOutput(const AData: string);
var
  Plain: string;
begin
  if FReady then
    SendCmd('out', AData)
  else
    FPendingSend.Add(AData);
  if FLogMode = lmRaw then WriteLog(AData);
  if (FLogMode = lmPlain) or Assigned(FOnOutput) or Assigned(FOnLine) then
  begin
    Plain := StripVT(AData);
    if FLogMode = lmPlain then WriteLog(Plain);
    if (Plain <> '') and Assigned(FOnOutput) then FOnOutput(Self, Plain);
    if Assigned(FOnLine) then EmitLines(Plain);
  end;
end;

procedure TCcmd.PtyExited(AExitCode: Integer);
begin
  FExitCode := AExitCode;
  if FLineBuf <> '' then
  begin
    if Assigned(FOnLine) then FOnLine(Self, FLineBuf);
    FLineBuf := '';
  end;
  FLogName := '';
  if FReady and not FCloseOnExit then
    SendCmd('message', Format(CXT(sCcmdExited), [AExitCode]));
  if Assigned(FOnExit) then FOnExit(Self, AExitCode);
  if FCloseOnExit then Visible := False;
end;

{ エスケープシーケンス（CSI・OSC・その他の ESC）を取り除く。出力が途中で切れても、状態を持ち越す }
function TCcmd.StripVT(const S: string): string;
var
  I: Integer;
  Ch: Char;
  Outp: string;
begin
  Outp := '';
  for I := 1 to Length(S) do
  begin
    Ch := S[I];
    case FStripState of
      0: { 通常 }
        if Ch = #27 then FStripState := 1
        else if Ch = #8 then
        begin
          if (Outp <> '') and not (Outp[Length(Outp)] in [#10, #13]) then Delete(Outp, Length(Outp), 1);
        end
        else if (Ch = #7) then { ベルは、ログに入れない }
        else Outp := Outp + Ch;
      1: { ESC の次 }
        if Ch = '[' then FStripState := 2
        else if Ch = ']' then FStripState := 3
        else FStripState := 0;           { ESC 1 文字の命令（ESC= ESC> など） }
      2: { CSI：最後の文字（@ から ~）まで }
        if (Ch >= '@') and (Ch <= '~') then FStripState := 0;
      3: { OSC：BEL か ESC \ まで }
        if Ch = #7 then FStripState := 0
        else if Ch = #27 then FStripState := 4;
      4:
        FStripState := 0;
    end;
  end;
  Result := Outp;
end;

procedure TCcmd.EmitLines(const APlain: string);
var
  I: Integer;
  Ch: Char;
begin
  for I := 1 to Length(APlain) do
  begin
    Ch := APlain[I];
    if Ch = #10 then
    begin
      if Assigned(FOnLine) then FOnLine(Self, FLineBuf);
      FLineBuf := '';
    end
    else if Ch <> #13 then
      FLineBuf := FLineBuf + Ch;
  end;
end;

{ ---------- ログ・履歴 ---------- }

procedure AppendUtf8(const AFileName, AText: string);
var
  FS: TFileStream;
begin
  if AText = '' then Exit;
  if FileExists(AFileName) then
  begin
    FS := TFileStream.Create(AFileName, fmOpenReadWrite or fmShareDenyNone);
    FS.Seek(0, soEnd);
  end
  else
    FS := CXCreateFileShared(AFileName);
  try
    FS.WriteBuffer(AText[1], Length(AText));
  finally
    FS.Free;
  end;
end;

procedure TCcmd.OpenLog;
var
  Dir: string;
begin
  FLogBytes := 0;
  FLogFailed := False;
  FLogName := '';
  if FLogMode = lmOff then Exit;
  Dir := FLogDir;
  if Dir = '' then Dir := ExeDir + 'Logs';
  try
    ForceDirectories(Dir);
    FLogName := IncludeTrailingPathDelimiter(Dir) + FormatDateTime('yyyymmdd_hhnnsszzz', Now) + '.log';
  except
    on E: Exception do
    begin
      FLogFailed := True;
      DoError(Dir + ': ' + E.Message);
    end;
  end;
end;

procedure TCcmd.WriteLog(const AText: string);
begin
  if (FLogMode = lmOff) or FLogFailed or (AText = '') or (FLogName = '') then Exit;
  try
    AppendUtf8(FLogName, AText);
    Inc(FLogBytes, Length(AText));
    if (FLogMaxSize > 0) and (FLogBytes > Int64(FLogMaxSize) * 1024) then
    begin
      { 大きくなったら、新しい時刻のファイルへ切り替える }
      FLogName := ExtractFilePath(FLogName) + FormatDateTime('yyyymmdd_hhnnsszzz', Now + 1 / 86400000) + '.log';
      FLogBytes := 0;
    end;
  except
    on E: Exception do
    begin
      FLogFailed := True;
      DoError(FLogName + ': ' + E.Message);
    end;
  end;
end;

procedure TCcmd.AddHistory(const ACmd: string);
var
  Dir: string;
begin
  if ACmd = '' then Exit;
  if (FHistory.Count > 0) and (FHistory[FHistory.Count - 1] = ACmd) then Exit;
  FHistory.Add(ACmd);
  while (FHistoryMax > 0) and (FHistory.Count > FHistoryMax) do FHistory.Delete(0);
  if FHistFile = '' then
  begin
    Dir := FHistoryDir;
    if Dir = '' then Dir := ExeDir + 'History';
    try
      ForceDirectories(Dir);
      FHistFile := IncludeTrailingPathDelimiter(Dir) + FormatDateTime('yyyymmdd_hhnnsszzz', Now) + '-CmdHistory.log';
    except
      FHistFile := '';
      Exit;
    end;
  end;
  try
    AppendUtf8(FHistFile, ACmd + #13#10);
  except
    on E: Exception do DoError(FHistFile + ': ' + E.Message);
  end;
end;

{ ---------- 入力 ---------- }

procedure TCcmd.SendText(const AText: string);
begin
  if (FPty <> nil) and InputAllowed then FPty.Write(AText);
end;

procedure TCcmd.Execute(const ALine: string);
begin
  if not InputAllowed then Exit;
  { プログラムから送るコマンドは、画面の文字からは取れない（シェルが書き戻す前だから）ので、ここで履歴に入れる }
  if Trim(ALine) <> '' then
  begin
    AddHistory(Trim(ALine));
    if Assigned(FOnCommand) then FOnCommand(Self, Trim(ALine));
  end;
  SendText(ALine + #13);
end;

procedure TCcmd.SendCtrlC;
begin
  SendText(#3);
end;

function KeySequence(AKey: Word; AShift: TShiftState): string;
var
  M: Integer;
  Pre: string;

  function Csi(const AFinal: string): string;
  begin
    if M > 1 then Result := #27 + '[1;' + IntToStr(M) + AFinal else Result := #27 + '[' + AFinal;
  end;

  function Tilde(ANum: Integer): string;
  begin
    if M > 1 then Result := #27 + '[' + IntToStr(ANum) + ';' + IntToStr(M) + '~'
    else Result := #27 + '[' + IntToStr(ANum) + '~';
  end;

begin
  M := 1;
  if ssShift in AShift then M := M + 1;
  if ssAlt in AShift then M := M + 2;
  if ssCtrl in AShift then M := M + 4;
  Pre := '';
  case AKey of
    VK_UP: Result := Csi('A');
    VK_DOWN: Result := Csi('B');
    VK_RIGHT: Result := Csi('C');
    VK_LEFT: Result := Csi('D');
    VK_HOME: Result := Csi('H');
    VK_END: Result := Csi('F');
    VK_INSERT: Result := Tilde(2);
    VK_DELETE: Result := Tilde(3);
    VK_PRIOR: Result := Tilde(5);
    VK_NEXT: Result := Tilde(6);
    VK_F1: Result := #27 + 'OP';
    VK_F2: Result := #27 + 'OQ';
    VK_F3: Result := #27 + 'OR';
    VK_F4: Result := #27 + 'OS';
    VK_F5: Result := Tilde(15);
    VK_F6: Result := Tilde(17);
    VK_F7: Result := Tilde(18);
    VK_F8: Result := Tilde(19);
    VK_F9: Result := Tilde(20);
    VK_F10: Result := Tilde(21);
    VK_F11: Result := Tilde(23);
    VK_F12: Result := Tilde(24);
    VK_TAB: Result := #9;
    VK_RETURN: Result := #13;
    VK_BACK: Result := #127;
    VK_ESCAPE: Result := #27;
    Ord('A')..Ord('Z'):
      if ssCtrl in AShift then Result := Chr(AKey - Ord('A') + 1) else Result := '';
  else
    Result := '';
  end;
end;

procedure TCcmd.SendKey(AKey: Word; AShift: TShiftState);
var
  S: string;
begin
  S := KeySequence(AKey, AShift);
  if S <> '' then SendText(S);
end;

procedure TCcmd.Paste;
begin
  if (not InputAllowed) or (not FReady) then Exit;
  SendCmd('paste', Clipboard.AsText);
end;

procedure TCcmd.CopySelection;
begin
  SendCmd('copy', '');
end;

procedure TCcmd.SelectAll;
begin
  SendCmd('selectall', '');
end;

procedure TCcmd.ClearScrollback;
begin
  SendCmd('clearscroll', '');
end;

procedure TCcmd.ScrollToBottom;
begin
  SendCmd('scrollbottom', '');
end;

procedure TCcmd.FindNext(const AText: string; AMatchCase: Boolean);
begin
  SendCmd('find', '1' + SEP2 + AText + SEP2 + MatchFlag(AMatchCase));
end;

procedure TCcmd.FindPrev(const AText: string; AMatchCase: Boolean);
begin
  SendCmd('find', '0' + SEP2 + AText + SEP2 + MatchFlag(AMatchCase));
end;

procedure TCcmd.RequestBufferText;
begin
  SendCmd('gettext', '');
end;

procedure TCcmd.SaveBufferTo(const AFileName: string);
begin
  FSavePath := AFileName;
  RequestBufferText;
end;

procedure TCcmd.SetFocus;
begin
  if (not InDesigner) and FReady then
  begin
    if FWindowParent.CanFocus then FWindowParent.SetFocus;
    FBrowser.SetFocus;
    SendCmd('focus', '');
  end
  else
    inherited SetFocus;
end;

procedure TCcmd.OpenDevTools;
begin
  if FBrowser = nil then Exit;
  FBrowser.DevToolsEnabled := True;
  FBrowser.OpenDevToolsWindow;
end;

{ ---------- RunCapture（パイプ方式） ---------- }

function TCcmd.RunCapture(const ACommandLine: string; out AStdOut, AStdErr: string;
  out AExitCode: Integer; ATimeoutMs: Integer): Boolean;
var
  SA: TSecurityAttributes;
  OutR, OutW, ErrR, ErrW, InR, InW: THandle;
  SI: TStartupInfoW;
  PI: TProcessInformation;
  CmdLine, WDir: UnicodeString;
  Env: UnicodeString;
  T0: QWord;
  Avail, Got: DWORD;
  Buf: array[0..8191] of Byte;
  Code: DWORD;
  Busy, TimedOut: Boolean;
  S: string;

  function Drain(H: THandle; var Dest: string): Boolean;
  begin
    Result := False;
    Avail := 0;
    if PeekNamedPipe(H, nil, 0, nil, @Avail, nil) and (Avail > 0) then
    begin
      Got := 0;
      if ReadFile(H, Buf, SizeOf(Buf), Got, nil) and (Got > 0) then
      begin
        SetLength(S, Got);
        Move(Buf[0], S[1], Got);
        Dest := Dest + S;
        Result := True;
      end;
    end;
  end;

  function ToUtf8(const ARaw: string): string;
  var
    Wide: UnicodeString;
    N: Integer;
  begin
    if ARaw = '' then Exit('');
    N := MultiByteToWideChar(CP_OEMCP, 0, PChar(ARaw), Length(ARaw), nil, 0);
    SetLength(Wide, N);
    if N > 0 then MultiByteToWideChar(CP_OEMCP, 0, PChar(ARaw), Length(ARaw), PWideChar(Wide), N);
    Result := UTF8Encode(Wide);
  end;

var
  RawOut, RawErr: string;
begin
  Result := False;
  AStdOut := '';
  AStdErr := '';
  AExitCode := -1;
  RawOut := '';
  RawErr := '';
  FillChar(SA, SizeOf(SA), 0);
  SA.nLength := SizeOf(SA);
  SA.bInheritHandle := True;
  if not CreatePipe(OutR, OutW, @SA, 0) then Exit;
  if not CreatePipe(ErrR, ErrW, @SA, 0) then begin CloseHandle(OutR); CloseHandle(OutW); Exit; end;
  if not CreatePipe(InR, InW, @SA, 0) then
  begin
    CloseHandle(OutR); CloseHandle(OutW); CloseHandle(ErrR); CloseHandle(ErrW);
    Exit;
  end;
  SetHandleInformation(OutR, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(ErrR, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(InW, HANDLE_FLAG_INHERIT, 0);
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESTDHANDLES;
  SI.hStdInput := InR;
  SI.hStdOutput := OutW;
  SI.hStdError := ErrW;
  CmdLine := 'cmd.exe /c ' + UTF8Decode(ACommandLine);
  UniqueString(CmdLine);
  Env := BuildEnvBlock(FEnvironment);
  if FWorkDir <> '' then WDir := UTF8Decode(FWorkDir) else WDir := UTF8Decode(ExcludeTrailingPathDelimiter(ExeDir));
  FillChar(PI, SizeOf(PI), 0);
  if not CreateProcessW(nil, PWideChar(CmdLine), nil, nil, True,
       CREATE_NO_WINDOW or CREATE_UNICODE_ENVIRONMENT, PWideChar(Env), PWideChar(WDir), SI, PI) then
  begin
    CloseHandle(OutR); CloseHandle(OutW); CloseHandle(ErrR); CloseHandle(ErrW);
    CloseHandle(InR); CloseHandle(InW);
    Exit;
  end;
  CloseHandle(OutW);
  CloseHandle(ErrW);
  CloseHandle(InR);
  CloseHandle(InW);
  T0 := GetTickCount64;
  TimedOut := False;
  repeat
    Busy := Drain(OutR, RawOut);
    if Drain(ErrR, RawErr) then Busy := True;
    if not Busy then
    begin
      if WaitForSingleObject(PI.hProcess, 20) = WAIT_OBJECT_0 then
      begin
        { 終わった：残りを読み切る }
        while Drain(OutR, RawOut) do ;
        while Drain(ErrR, RawErr) do ;
        Break;
      end;
      Application.ProcessMessages;
    end;
    if (ATimeoutMs > 0) and (GetTickCount64 - T0 > QWord(ATimeoutMs)) then
    begin
      TimedOut := True;
      TerminateProcess(PI.hProcess, 1);
      Break;
    end;
  until False;
  Code := 0;
  GetExitCodeProcess(PI.hProcess, Code);
  AExitCode := Integer(Code);
  CloseHandle(PI.hProcess);
  CloseHandle(PI.hThread);
  CloseHandle(OutR);
  CloseHandle(ErrR);
  AStdOut := ToUtf8(RawOut);
  AStdErr := ToUtf8(RawErr);
  Result := not TimedOut;
end;

{ ---------- メニュー ---------- }

procedure TCcmd.MenuCopyClick(Sender: TObject);
begin
  CopySelection;
end;

procedure TCcmd.MenuPasteClick(Sender: TObject);
begin
  Paste;
end;

procedure TCcmd.MenuSelectAllClick(Sender: TObject);
begin
  SelectAll;
end;

procedure TCcmd.MenuClearClick(Sender: TObject);
begin
  ClearScrollback;
end;

{ ---------- プロパティ ---------- }

procedure TCcmd.SetShell(const AValue: string);
begin
  FShell := Trim(AValue);
  if FShell = '' then FShell := 'cmd.exe';
end;

procedure TCcmd.SetEnvironment(AValue: TStrings);
begin
  FEnvironment.Assign(AValue);
end;

procedure TCcmd.SetMaxCount(AValue: Integer);
begin
  AValue := EnsureRange(AValue, cMaxCountMin, cMaxCountMax);
  if FMaxCount = AValue then Exit;
  FMaxCount := AValue;
  SendOptions;
end;

procedure TCcmd.SetHistoryMax(AValue: Integer);
begin
  if AValue < 1 then AValue := 1;
  FHistoryMax := AValue;
  while (FHistory <> nil) and (FHistory.Count > FHistoryMax) do FHistory.Delete(0);
end;

procedure TCcmd.SetTheme(AValue: TCMTheme);
begin
  if FTheme = AValue then Exit;
  FTheme := AValue;
  SendOptions;
  Invalidate;
end;

procedure TCcmd.SetCursorStyle(AValue: TCcmdCursorStyle);
begin
  if FCursorStyle = AValue then Exit;
  FCursorStyle := AValue;
  SendOptions;
end;

procedure TCcmd.SetCursorBlink(AValue: Boolean);
begin
  if FCursorBlink = AValue then Exit;
  FCursorBlink := AValue;
  SendOptions;
end;

procedure TCcmd.SetCursorColor(AValue: TColor);
begin
  if FCursorColor = AValue then Exit;
  FCursorColor := AValue;
  SendOptions;
end;

procedure TCcmd.SetSelectionColor(AValue: TColor);
begin
  if FSelectionColor = AValue then Exit;
  FSelectionColor := AValue;
  SendOptions;
end;

procedure TCcmd.SetReadOnly(AValue: Boolean);
begin
  if FReadOnly = AValue then Exit;
  FReadOnly := AValue;
  SendOptions;
end;

function TCcmd.GetCaptionText: string;
begin
  Result := inherited Caption;
end;

procedure TCcmd.SetCaptionText(const AValue: string);
begin
  inherited Caption := AValue;
end;

procedure TCcmd.SetAutoCaption(AValue: Boolean);
begin
  if FAutoCaption = AValue then Exit;
  FAutoCaption := AValue;
  if FAutoCaption and (FTitle <> '') then inherited Caption := FTitle;
end;

function TCcmd.GetActive: Boolean;
begin
  Result := (FPty <> nil) and FPty.Active;
end;

function TCcmd.GetProcessId: Cardinal;
begin
  if FPty <> nil then Result := FPty.ProcessId else Result := 0;
end;

{ ---------- 設計時の見た目 ---------- }

procedure TCcmd.Paint;
begin
  inherited Paint;
  if not InDesigner then Exit;
  { 設計時：薄い枠と部品の名前（TCPreview と同じ見た目） }
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := clGrayText;
  Canvas.Pen.Style := psDash;
  Canvas.Rectangle(0, 0, Width, Height);
  Canvas.Font.Color := clGrayText;
  Canvas.TextOut(8, 8, Name + ' : TCcmd');
end;


finalization
  FreeAndNil(GShownErrors);

end.
