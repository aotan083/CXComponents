# TCcmd 設計書

作者: aotan083
日付: 2026-11-07
版: 1.0

---

## 1. 目的と方針

- TCcmdは、コマンドプロンプトの完全エミレータを実現するコンポーネントです。入力・出力・エラー出力を、フォームに置いた部品につなぐ。画面の表示と、キー入力は、部品が受け持ちます。
- ssh、vi、PowerShell の対話も動く。リダイレクト（`>`、`>>`、`2>&1`）やパイプ（`|`）も模倣します。
- 画面の描き方：WebView2 の中で xterm.js を動かして描く（エスケープシーケンスの解釈、色、カーソル、全角、選択、スクロールバック、検索は、xterm.js に任せる）。
- python、php、go などのスクリプトは、普通のコマンドとして実行できる。
- 結果を取り込みたい用途のために、パイプ方式の `RunCapture`（標準出力・エラー出力・終了コードを別々に受ける）を持つ。

### 1.1 含めないもの

- Linux・macOS 版（Windows 11 だけ）。シェルを動かす部分を `TCcmdPty` に分けるので、将来、別の OS 用に差し替えられる作りにはしておく。
- タブ付きのターミナル（複数の端末を並べる枠）。TCPageControl の各タブに TCcmd を 1 つずつ置いて使う。
- 標準出力とエラー出力を、端末モードで分けること。端末としては、1 本にまとまる（本物の端末と同じ）。分けたいときは `RunCapture` を使う。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCcmd.pas` | cx（実行時） | `TCcmdPty`、`TCcmd` |
| `uCXReg.pas`（`source\design`） | cxdsgn（設計時） | パレット [CX] への登録（`RegisterComponents('CX', [..., TCcmd])`。並びの末尾） |
| `ccmd_icon.lrs`（`source\res`） | cxdsgn（設計時） | アイコン（`TCcmd`・`TCcmd_150`・`TCcmd_200`）。`uCXReg` の initialization で `{$I ccmd_icon.lrs}` |
| `uCXLang.pas` | cx（実行時） | 文字列を足す（4.6） |
| `runtime\terminal\terminal.html` | 実行時に EXE と一緒に置く | 画面のページ（7 章） |
| `runtime\terminal\lib\` | 同上 | `xterm.js`、`xterm.css`、`addon-fit.js`、`addon-search.js`（xterm.js。MIT。`THIRD_PARTY_NOTICES.md` に出典とライセンスを書く） |

- `uCcmd` の uses：`Windows, Classes, SysUtils, Types, Math, Controls, Graphics, Forms, Menus, ExtCtrls, Clipbrd, LCLType, LCLIntf, LMessages, SyncObjs, uWVBrowser, uWVWindowParent, uWVLoader, uWVTypes, uWVTypeLibrary, uWVEvents, uWVCoreWebView2Args, uCmonacos`（`TCMTheme`）。実装部で `uCXLang`・`uCXRuntime` を使う。
- `uCcmd` の initialization は持たない（uCXRuntime と同じ理由）。finalization だけ持ち、表示済みのエラーメッセージの一覧を解放する。
- `WebView2.ini` の `[WebView2]` に、キー `TerminalFolder`（`terminal.html` と `lib` があるフォルダー。空なら EXE の隣の `terminal`）を足す。読み方は `MonacoFolder`・`PreviewFolder` と同じ（`uCXRuntime` の `CXResolveRuntimeDir`）。
- パッケージは、cx と cxdsgn の 2 つのまま（WebView を使う他の部品と同じ場所に入れる）。

## 3. 全体の構成

```
フォームの TCcmd（TCustomPanel）
  ├─ TCXWVWindowParent ＋ TWVBrowser    … WebView2。terminal.html（xterm.js）を表示する
  │        ▲ ③ 出力（文字）           │ ④ キー入力・大きさ・タイトル などの通知
  │        │ PostWebMessageAsString    ▼ WebMessageReceived
  └─ TCcmdPty                           … ConPTY で、シェルを動かす
          ① キー入力を書く ─▶ [擬似コンソール] ─▶ cmd.exe / powershell.exe / ssh.exe …
          ② 出力を読む（読み取りの専用スレッド）◀─
```

1. 利用者がキーを打つ → xterm.js が文字列にして Pascal へ通知（`input`）→ `TCcmdPty` が入力のパイプへ書く。
2. シェルの出力 → 読み取りスレッドが読む → メインスレッドへ渡す → ページへ送る（`out`）→ xterm.js が描く。
3. 大きさが変わる → ページが桁数・行数を通知（`resize`）→ `TCcmdPty.Resize`（`ResizePseudoConsole`）。

## 4. TCcmd

`TCcmd = class(TCustomPanel)`。ユニット `uCcmd`。

### 4.1 型と定数

```pascal
type
  TCcmdLogMode = (lmOff, lmPlain, lmRaw);                 { ログを書かない／エスケープを除いた文字／生の出力 }
  TCcmdCursorStyle = (ccBlock, ccUnderline, ccBar);
  TCcmdBellMode = (bmNone, bmSound, bmFlash);             { ベル（BEL）：何もしない／音／画面を一瞬光らせる }
  TCcmdOutputEvent = procedure(Sender: TObject; const AText: string) of object;
  TCcmdExitEvent = procedure(Sender: TObject; AExitCode: Integer) of object;
  TCcmdResizeEvent = procedure(Sender: TObject; ACols, ARows: Integer) of object;
  TCcmdErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;
```

| 定数 | 値 | 中身 |
|---|---|---|
| `cMaxCountMin` / `cMaxCountMax` / `cMaxCountDef` | 100 / 10000 / 1000 | `MaxCount` の範囲と既定値 |
| `cHistoryMaxDef` | 1000 | `HistoryMax` の既定値 |
| `cLogMaxSizeDef` | 10240 | `LogMaxSize`（KB）の既定値 |
| `cDefaultCols` / `cDefaultRows` | 80 / 24 | ページの準備ができる前の仮の大きさ |
| `cIdleMs` | 150 | 出力が止まったとみなす時間（プロンプトの位置の記録に使う。8.5） |

### 4.2 プロパティ

公開（`published`）：

| 名前 | 型 | 既定値 | 中身 |
|---|---|---|---|
| `Shell` | `string` | `cmd.exe` | 動かすプログラム（`powershell.exe`、`ssh.exe`、フルパスも可）。空なら `cmd.exe` |
| `Params` | `string` | `''` | 起動の引数（たとえば `-NoLogo`）。`Shell` の後ろに付ける |
| `WorkDir` | `string` | `''` | 作業フォルダー。空なら、EXE のフォルダー |
| `Environment` | `TStrings` | 空 | 追加・上書きする環境変数（`名前=値`）。ない分は、親（アプリ）の環境を引き継ぐ |
| `AutoStart` | `Boolean` | `True` | 実行時、画面の準備ができたら、自動で `Start` する。設計時は動かさない |
| `CloseOnExit` | `Boolean` | `False` | シェルが終わったとき、画面を閉じる（`Visible := False`）か。`False` なら、画面を残して「プロセスが終了しました（コード n）」を出す |
| `MaxCount` | `Integer` | `1000` | 画面に残す行数（スクロールバックを含む）。100〜10000 に丸める。超えたら、先頭から消える |
| `LogMode` | `TCcmdLogMode` | `lmPlain` | ログの書き方 |
| `LogDir` | `string` | `''` | ログのフォルダー。空なら `EXE\Logs`。ファイル名は `yyyymmdd_hhnnsszzz.log`（`Start` したときの時刻） |
| `LogMaxSize` | `Integer` | `10240` | ログ 1 ファイルの最大サイズ（KB）。超えたら、新しいファイルに切り替える（時刻が変わる） |
| `HistoryDir` | `string` | `''` | コマンド履歴のフォルダー。空なら `EXE\History`。ファイル名は `yyyymmdd_hhnnsszzz-CmdHistory.log` |
| `HistoryMax` | `Integer` | `1000` | `CmdHistory` に残す最大件数（超えたら、古いものから消す） |
| `Font` | `TFont` | `Consolas`、`10` | フォント。等幅が前提。`Font.Color` が `clDefault` なら、`Theme` の文字色 |
| `Color` | `TColor` | `clDefault` | 背景色。`clDefault` なら、`Theme` の背景色 |
| `Theme` | `TCMTheme` | `ctAuto` | `ctAuto`（OS に合わせる）／`ctLight`／`ctDark`。配色（9 章）を決める |
| `CursorStyle` | `TCcmdCursorStyle` | `ccBlock` | カーソルの形 |
| `CursorBlink` | `Boolean` | `True` | カーソルを点滅させる |
| `CursorColor` | `TColor` | `clDefault` | カーソルの色。`clDefault` なら `Theme` の色 |
| `SelectionColor` | `TColor` | `clDefault` | 選択範囲の色。`clDefault` なら `Theme` の色 |
| `Caption` | `string` | `''` | タイトルの文字。`AutoCaption` が真のとき、シェルが設定したタイトルに追従する |
| `AutoCaption` | `Boolean` | `True` | `Caption` を、シェルのタイトル（`ESC]0;…`）に追従させる |
| `ReadOnly` | `Boolean` | `False` | 真なら、キー入力・貼り付けを受け付けない（出力の表示だけ） |
| `BellMode` | `TCcmdBellMode` | `bmSound` | ベルの扱い |
| `TerminalPath` | `string` | `''` | `terminal.html` と `lib` のフォルダー。空なら `WebView2.ini` の `TerminalFolder`、それも無ければ EXE の隣の `terminal` |
| `PopupMenu` | `TPopupMenu` | `nil` | 右クリックのメニュー。`nil` なら、既定のメニュー（コピー・貼り付け・すべて選択・画面を消す） |
| `Align`、`Anchors`、`BorderSpacing`、`Constraints`、`Enabled`、`Visible`、`TabOrder`、`TabStop`、`ShowHint`、`Hint` | | | LCL 標準 |

実行時（公開しない）：

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Active` | `Boolean` | 読み | シェルが動いているか |
| `ExitCode` | `Integer` | 読み | シェルの終了コード（動いている間は -1） |
| `ProcessId` | `Cardinal` | 読み | シェルのプロセス番号（動いていなければ 0） |
| `Cols`、`Rows` | `Integer` | 読み | 今の桁数・行数（大きさから自動で決まる） |
| `Title` | `string` | 読み | シェルが設定したタイトル |
| `Ready` | `Boolean` | 読み | ページ（xterm.js）の準備ができたか |
| `CmdHistory` | `TStrings` | 読み | これまでに実行したコマンド（古いものが先） |

- `Enabled = False` のとき、キー入力・貼り付けは受け付けない（出力は、表示し続ける）。
- `Font`・`Color`・`Theme`・`CursorStyle`・`CursorBlink`・`CursorColor`・`SelectionColor`・`MaxCount` を変えたら、すぐにページへ送り直す（4.5 の `SendOptions`）。

### 4.3 メソッド

| メソッド | 中身 |
|---|---|
| `procedure Start` | シェルを起動する。すでに動いていれば、何もしない。ページの準備ができていなければ、できてから起動する（保留） |
| `procedure Stop` | シェルを終了させる（孫プロセスも、まとめて）。動いていなければ、何もしない |
| `procedure Restart` | `Stop` してから `Start` する |
| `procedure SendText(const AText: string)` | 文字列を、そのまま、シェルへ送る（`ReadOnly` や `Enabled = False` のときは、何もしない） |
| `procedure Execute(const ALine: string)` | 1 行を送って、Enter を押す。画面からコマンドを取り出す方式（8.5）は、プログラムから送った文字には使えないので、`Execute` 自身が、`AddHistory(ALine)` と `OnCommand` を行ってから、`SendText(ALine + #13)` する |
| `procedure SendKey(AKey: Word; AShift: TShiftState)` | キー（矢印、Home・End、PageUp・PageDown、F1〜F12、Delete など）を、端末の文字列に直して送る（表は 8.2） |
| `procedure SendCtrlC` | Ctrl+C（`#3`）を送る。実行中の処理を止める |
| `procedure Paste` | クリップボードの文字列を送る（`?2004` の貼り付けの枠が有効なら、枠で囲んで） |
| `procedure CopySelection` | 選択している文字列を、クリップボードへ入れる |
| `procedure SelectAll` | 全選択 |
| `procedure ClearScrollback` | 画面の上へ流れた履歴を消す（今の画面は残す） |
| `procedure ScrollToBottom` | 一番下まで動かす |
| `procedure FindNext(const AText: string; AMatchCase: Boolean = False)` | 次を探して、選択する |
| `procedure FindPrev(const AText: string; AMatchCase: Boolean = False)` | 前を探して、選択する |
| `procedure RequestBufferText` | 画面と履歴の全文をページに求める。届いたら `OnBufferText` が起きる |
| `procedure SaveBufferTo(const AFileName: string)` | `RequestBufferText` で受けた全文を、UTF-8 のファイルに書く（届いたときに書く） |
| `procedure SetFocus`（`override`） | 端末（xterm.js）へ、キーボードフォーカスを移す |
| `function RunCapture(const ACommandLine: string; out AStdOut, AStdErr: string; out AExitCode: Integer; ATimeoutMs: Integer = 0): Boolean` | `Shell` の種類によらず、`cmd.exe /c ACommandLine` を、パイプ方式で実行する。標準出力・エラー出力・終了コードを、別々に受ける。リダイレクトやパイプは、cmd.exe が処理する。`ATimeoutMs` が 0 でなければ、その時間で打ち切る（打ち切ったら `False`）。待つ間も、メッセージは処理する |
| `procedure OpenDevTools` | WebView2 の開発者ツールを開く（調べるとき用） |

### 4.4 イベント

| イベント | 型 | いつ |
|---|---|---|
| `OnReady` | `TNotifyEvent` | ページ（xterm.js）の準備ができたとき |
| `OnStart` | `TNotifyEvent` | シェルを起動したとき |
| `OnExit` | `TCcmdExitEvent` | シェルが終わったとき（`CloseOnExit` の処理より前） |
| `OnOutput` | `TCcmdOutputEvent` | 出力が来たとき。エスケープシーケンスを除いた文字（1 回の読み取りごと） |
| `OnLine` | `TCcmdOutputEvent` | 出力のうち、改行までそろった 1 行が確定したとき（エスケープ除去後） |
| `OnCommand` | `TCcmdOutputEvent` | Enter でコマンドを実行したとき（8.5 で取り出した文字列） |
| `OnTitleChange` | `TNotifyEvent` | シェルのタイトルが変わったとき |
| `OnBell` | `TNotifyEvent` | ベルが鳴ったとき（`BellMode` に関わらず起きる） |
| `OnResize` | `TCcmdResizeEvent` | 桁数・行数が変わったとき |
| `OnBufferText` | `TCcmdOutputEvent` | `RequestBufferText` の結果が届いたとき |
| `OnError` | `TCcmdErrorEvent` | 起動の失敗、ページの読み込みの失敗など。未設定なら、`ShowMessage` で出す（同じ文は 1 回だけ） |

### 4.5 宣言（private・protected）

```pascal
TCcmd = class(TCustomPanel)
private
  FPty: TCcmdPty;
  FWindowParent: TCXWVWindowParent;
  FBrowser: TWVBrowser;
  FReady: Boolean;                  { ページの準備ができた }
  FCols, FRows: Integer;
  FPendingStart: Boolean;           { Start を頼まれたが、まだ準備ができていない }
  FPendingSend: TStringList;        { ページの準備前に届いた出力（準備後に送る） }
  FHistory: TStringList;
  FLogFile: TFileStream;            { ログのファイル }
  FLogName: string;
  FLogBytes: Int64;
  FHistFile: string;                { 履歴のファイル名 }
  FTitle: string;
  FExitCode: Integer;
  FOnReady, FOnStart, FOnTitleChange, FOnBell: TNotifyEvent;
  FOnExit: TCcmdExitEvent;
  FOnOutput, FOnLine, FOnCommand, FOnBufferText: TCcmdOutputEvent;
  FOnResize: TCcmdResizeEvent;
  FOnError: TCcmdErrorEvent;
  ... （4.2 のプロパティの値）
  procedure BrowserAfterCreated(Sender: TObject);
  procedure BrowserInitError(Sender: TObject; aErrorCode: HRESULT; const aErrorMessage: wvstring);
  procedure BrowserWebMessageReceived(Sender: TObject; const aWebView: ICoreWebView2;
    const aArgs: ICoreWebView2WebMessageReceivedEventArgs);
  procedure PtyOutput(const AData: string);        { TCcmdPty が、メインスレッドへ渡す出力 }
  procedure PtyExited(AExitCode: Integer);
  procedure HandleMessage(const AMsg: string);     { ページからの通知を処理する（6 章） }
  procedure SendCmd(const ACmd, AArg: string);     { ページへ送る（6 章） }
  procedure SendOptions;                           { フォント・色・カーソル・MaxCount などを送る }
  procedure OpenLog;
  procedure WriteLog(const AText: string);
  procedure AddHistory(const ACmd: string);
  ...
protected
  procedure CreateWnd; override;
  procedure VisibleChanged; override;
  procedure Notification(AComponent: TComponent; Operation: TOperation); override;
public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  ...（4.3 のメソッド）
end;
```

### 4.6 文字列（`uCXLang` へ足すもの）

| ID | 日本語 | English |
|---|---|---|
| `sCcmdMenuCopy` | コピー(&C) | Copy(&C) |
| `sCcmdMenuPaste` | 貼り付け(&P) | Paste(&P) |
| `sCcmdMenuSelectAll` | すべて選択(&A) | Select All(&A) |
| `sCcmdMenuClear` | 画面を消す(&L) | Clear(&L) |
| `sCcmdExited` | [プロセスが終了しました（コード %d）] | [Process exited with code %d] |
| `sCcmdErrStart` | シェルを起動できませんでした：%s | Could not start the shell: %s |
| `sCcmdErrNoPage` | terminal.html が見つかりません：%s | terminal.html was not found: %s |
| `sCcmdErrNoPty` | この Windows には、ConPTY（擬似コンソール）がありません | This Windows does not have ConPTY (pseudo console) |

これまでの並びの末尾に足す（`TCXStr` と `CXTable` の両方）。

## 5. TCcmdPty（ConPTY の部分）

`TCcmdPty = class`。ConPTY で、シェルを動かし、入力・出力・大きさ・終了を扱う。画面や WebView は、何も知らない（将来、別の OS 用に差し替える単位）。

### 5.1 宣言

```pascal
type
  TCcmdPtyDataEvent = procedure(const AData: string) of object;    { 出力（UTF-8 のまま、文字列に入れたもの） }
  TCcmdPtyExitEvent = procedure(AExitCode: Integer) of object;

  TCcmdPty = class
  private
    FPC: THandle;                  { 擬似コンソール }
    FInWrite, FOutRead: THandle;   { 入力を書くパイプ、出力を読むパイプ }
    FProcess, FThread, FJob: THandle;
    FReader: TThread;              { 出力の読み取り }
    FProcessId: Cardinal;
    FActive: Boolean;
    FOnData: TCcmdPtyDataEvent;
    FOnExit: TCcmdPtyExitEvent;
  public
    function Start(const AShell, AParams, AWorkDir: string; AEnv: TStrings; ACols, ARows: Integer; out AError: string): Boolean;
    procedure Write(const AData: string);
    procedure Resize(ACols, ARows: Integer);
    procedure Stop;
    property Active: Boolean read FActive;
    property ProcessId: Cardinal read FProcessId;
    property OnData: TCcmdPtyDataEvent read FOnData write FOnData;
    property OnExit: TCcmdPtyExitEvent read FOnExit write FOnExit;
  end;
```

### 5.2 起動（`Start`）

1. `CreatePipe` で、入力用（シェルが読む側 `InRead`、こちらが書く側 `FInWrite`）と、出力用（シェルが書く側 `OutWrite`、こちらが読む側 `FOutRead`）を作る。
2. `CreatePseudoConsole(MakeCoord(ACols, ARows), InRead, OutWrite, 0, FPC)`。失敗（関数が無い・`HRESULT` が 0 以外）なら、`AError := CXT(sCcmdErrNoPty)` で `False`。成功したら、`InRead`・`OutWrite` を `CloseHandle`（擬似コンソールが持つ）。
3. `STARTUPINFOEXW` を作る：`cb := SizeOf`、`dwFlags := STARTF_USESTDHANDLES`（親の標準ハンドルを、子へ引き継がない。親にコンソールがないとき・パイプのとき、子の出力が、擬似コンソールへ行かない不具合の対策。試作で確認済み）。属性リストに `PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE`（値は `FPC`）を入れる。
4. 環境：親の環境を取り、`AEnv` の `名前=値` を、上書き・追加する。`CREATE_UNICODE_ENVIRONMENT`。
5. コマンドライン：`AShell` に空白があれば `"` で囲み、`AParams` を空白を空けて足す。
6. `CreateProcessW(nil, コマンドライン, nil, nil, False, EXTENDED_STARTUPINFO_PRESENT or CREATE_UNICODE_ENVIRONMENT, 環境, AWorkDir, ...)`。失敗なら、`GetLastError` の文を `AError` に入れて、`Stop` して `False`。
7. ジョブオブジェクトを作り（`JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`）、子を入れる（`Stop`・破棄のとき、孫プロセスまで確実に止めるため）。
8. 出力の読み取りスレッドを開始する。`FActive := True`。

### 5.3 出力の読み取り（スレッド）

1. `ReadFile(FOutRead, バッファ 8KB)` を繰り返す。バイト列を、UTF-8 の途中で切れた分（末尾の不完全な 1〜3 バイト）を次回へ持ち越して、文字列（UTF-8 のバイトを、そのまま入れた `string`）にする。
2. 読んだ分は、短い時間（約 10 ms）や 64KB まで、まとめてから、`TThread.Queue`（メインスレッド）で `OnData` を呼ぶ（大量の出力で、画面が固まらないように）。
3. ConPTY は、子プロセスが終わっても、出力のパイプを閉じない。そのため、`ReadFile` で待たずに、`PeekNamedPipe` で、読めるものがあるかを見る（なければ短く待つ）。待つ間に、`WaitForSingleObject(FProcess, 0)` で、シェルの終了を見る。
4. 終了を見つけたら、150 ms 待って、残りを読み切って渡し、`GetExitCodeProcess` で終了コードを得て、`TThread.Queue` で、メインスレッドの `NotifyExit` を呼ぶ。`NotifyExit` は、`TCcmdPty.ReleaseAfterExit`（`ClosePseudoConsole` とハンドルの解放）を行い、そのあと `OnExit` を呼ぶ。
5. `ClosePseudoConsole` の前に、読み取りが済んでいるので、戻らなくなることはない。

### 5.4 そのほか

| 手続き | 処理 |
|---|---|
| `Write(AData)` | `AData`（UTF-8 のバイト列を入れた文字列）を、`WriteFile(FInWrite, …)` で書く（全部書けるまで繰り返す）。動いていなければ、何もしない |
| `Resize(C, R)` | `ResizePseudoConsole(FPC, MakeCoord(C, R))`。動いていなければ何もしない |
| `Stop` | 動いていれば、`TerminateJobObject`（孫まで）→ `ClosePseudoConsole(FPC)` → 入力のハンドルを閉じる。読み取りスレッドが終わるのを待つ（最大 2 秒）。`OnExit` は、すでに呼んだ分は、重ねて呼ばない |
| `Destroy` | `Stop` を行って、ハンドルをすべて閉じる |

## 6. TCcmd とページの通信

どちらも、`区切り文字（#1）` で、コマンド名と引数をつないだ 1 本の文字列（`TCMonacoEditor`・`TCPreview` と同じ作り）。Pascal から送るときは `PostWebMessageAsString`、ページから送るときは `window.chrome.webview.postMessage`。

### 6.1 Pascal → ページ（`SendCmd`）

| コマンド | 引数 | 中身 |
|---|---|---|
| `out` | 文字列（UTF-8 から文字列に直したもの） | 出力。xterm.js の `term.write` に渡す |
| `opt` | `名前=値` を `#2` でつないだ組 | オプションの設定（9 章）。`fontFamily`、`fontSize`、`fgColor`、`bgColor`、`cursorStyle`、`cursorBlink`、`cursorColor`、`selColor`、`scrollback`、`theme`（`light` / `dark`）、`palette`（16 色。`#rrggbb` をカンマでつなぐ。空なら、`theme` の標準）、`disabled`（入力を受け付けない） |
| `focus` | なし | `term.focus()` |
| `paste` | 文字列 | `term.paste`（貼り付けの枠の扱いを、xterm.js に任せる） |
| `selectall` | なし | `term.selectAll()` |
| `copy` | なし | 選択を取り出して、`selection` で返す |
| `clearscroll` | なし | `term.clear()` |
| `scrollbottom` | なし | `term.scrollToBottom()` |
| `find` | `次(1)/前(0)` `#2` `文字列` `#2` `大小(1/0)` | 検索アドオン |
| `gettext` | なし | 全文を `buffertext` で返す |
| `message` | 文字列 | 画面に 1 行（`sCcmdExited` など）を、色を変えて出す |
| `bell` | なし | ベルの点滅（`BellMode = bmFlash`） |

### 6.2 ページ → Pascal（`HandleMessage`）

| コマンド | 引数 | 中身と処理 |
|---|---|---|
| `ready` | なし | ページの準備ができた。`FReady := True`。`SendOptions`、保留していた出力と `Start` を処理。`OnReady` |
| `input` | 文字列 | 利用者の入力。`FPty.Write`（UTF-8 にして）。`ReadOnly`・`Enabled` が偽なら、捨てる |
| `resize` | `桁` `#2` `行` | 大きさが変わった。`FCols`・`FRows` を更新し、`FPty.Resize`。`OnResize` |
| `title` | 文字列 | シェルのタイトル。`FTitle`。`AutoCaption` なら `Caption`。`OnTitleChange` |
| `bell` | なし | `BellMode` に従う（`bmSound`：`MessageBeep`、`bmFlash`：`bell` を返す）。`OnBell` |
| `cmd` | 文字列 | Enter で実行したコマンド（8.5）。`AddHistory`。`OnCommand` |
| `selection` | 文字列 | `CopySelection` の結果。クリップボードへ |
| `buffertext` | 文字列 | `RequestBufferText` の結果。`OnBufferText`（`SaveBufferTo` 中ならファイルへ） |
| `ctrlv` | なし | ページが、Ctrl+V（または Ctrl+Shift+V）を受けた。`Paste` |
| `zoom` | `1`（拡大）／`-1`（縮小） | Ctrl+ホイール。`Font.Size` を 1 ずつ変える（6〜48）。`FontChanged` で `SendOptions` が走る |
| `drop` | なし（メッセージの付属物として、ドロップされたファイル） | エクスプローラーからのドロップ。`BrowserWebMessageReceived` が、付属物（`AdditionalObjects`）の `ICoreWebView2File.Path` を取り出し、空白を含む場所を `"` で囲み、空白でつないで、`paste` と `focus` を返す。`ReadOnly`・`Enabled = False` なら何もしない。`HandleMessage` は通らない |
| `menu` | `x` `#2` `y` | 右クリック。メニューを出す（`PopupMenu`、なければ既定） |

## 7. ページ（terminal.html）

- `<meta name="color-scheme" content="light dark">`。`opt` の `theme` を受けたら、`document.documentElement.style.colorScheme` を、その値（`light` / `dark`）にする（スクロールバーの色を、OS ではなく、テーマに合わせる。TCPreview・TCMonacoEditor と同じ）。
- 画面は、1 つの `<div id="t">` に、`xterm.js` を載せる。窓いっぱい（`width:100%; height:100%`、余白なし）。
- 起動：`new Terminal({ allowProposedApi: true, scrollback: 1000, fontFamily: 'Consolas', fontSize: 14, cursorBlink: true, macOptionIsMeta: false, convertEol: false })`。`FitAddon`・`SearchAddon` を読み込む。`term.open` のあと `fit()`。
- 大きさ：`ResizeObserver` で窓の変化を見て、`fit()`。`term.onResize` で、`resize` を送る（桁と行）。最初にも 1 回送る。
- 入力：`term.onData(d => post('input', d))`。キーの取り扱い（`attachCustomKeyEventHandler`）：

| キー | 動き |
|---|---|
| Ctrl+C | 選択があれば、コピー（`selection` を送る）。なければ、`input` に `\x03` を送る（中断） |
| Ctrl+Shift+C | 常にコピー |
| Ctrl+V、Ctrl+Shift+V、Shift+Insert | `ctrlv` を送る（貼り付けは、Pascal 側で行う） |
| Ctrl+Shift+F | （何もしない。検索は、`FindNext`・`FindPrev` から） |
| その他 | xterm.js の既定のまま（矢印、F キー、Alt、Ctrl の組み合わせなど） |

- Ctrl+ホイール：`wheel`（Ctrl が押されているとき）を止めて、`zoom` を送る（`deltaY < 0` なら `1`、そうでなければ `-1`）。WebView2 の標準の拡大・縮小は効かせない。
- ドロップ：`dragover`・`drop` を止める。`drop` では、`chrome.webview.postMessageWithAdditionalObjects('drop', files)` で、ファイルを付けて Pascal へ送る（ファイルの場所は、この方法でしか取れない）。`disabled` のときは送らない。

- タイトル：`term.onTitleChange(t => post('title', t))`。
- ベル：`term.onBell(() => post('bell'))`。
- 右クリック：`contextmenu` イベントを止めて、`menu` を送る（Pascal 側のメニュー）。
- コマンドの取り出し（8.5）：出力が `cIdleMs`（150 ms）止まったとき、`term.buffer.active` のカーソルの桁・行を、プロンプトの終わりとして覚える（`pX`、`pY`）。`input` に `\r` が入ったとき、`pY` 行（折り返しがあれば、続く行も）の `pX` 桁から行の終わりまでの文字（`translateToString(true)`）を連結し、前後の空白を除いて、`cmd` として送る（空なら送らない）。
- 準備ができたら `post('ready')`。

## 8. 処理

### 8.1 起動と終了

1. `Create`：`inherited` のあと、プロパティの既定値を入れる。`ControlStyle` から `csSetCaption` を外す。`BevelOuter := bvNone`。実行時（設計時でない）だけ、`FPty`、`FHistory`、`FWindowParent`、`FBrowser` を作る。
2. `CreateWnd`（実行時、初めて表示されるとき）：`CXStartWebView2` で WebView2 を準備し（失敗したら `OnError`）、`FBrowser.CreateBrowser(FWindowParent.Handle)`。
3. `BrowserAfterCreated`：`SetVirtualHostNameToFolderMapping('cx-terminal.local', 端末のフォルダー)`、`Navigate('https://cx-terminal.local/terminal.html')`。`terminal.html` が無ければ `OnError(sCcmdErrNoPage)`。
4. `ready` を受けたら、`SendOptions`。`AutoStart` か、保留（`FPendingStart`）があれば、`Start`。
5. `Start`：ページの準備前なら、`FPendingStart := True` で終わる。準備後は、`FPty.Start(Shell, Params, WorkDir, Environment, FCols, FRows, Err)`（大きさが決まっていなければ `cDefaultCols`・`cDefaultRows`）。失敗なら `OnError(sCcmdErrStart)`。成功なら `OpenLog`、`OnStart`。
6. `PtyExited`：`FExitCode` を入れる。ログを閉じる。`message` で、`sCcmdExited` を出す（`CloseOnExit` が偽のとき）。`OnExit`。`CloseOnExit` が真なら `Visible := False`。履歴を、ファイルへ書き出す。
7. `Stop`・`Destroy`：`FPty.Stop`。ログと履歴のファイルを閉じる。`FBrowser`・`FWindowParent` を壊す。

### 8.2 入力（`SendKey` の表）

`SendKey` は、次の文字列に直して `SendText` する。

| キー | 送る文字列 |
|---|---|
| ↑ ↓ → ← | `ESC[A` `ESC[B` `ESC[C` `ESC[D`（修飾キーがあれば `ESC[1;m` + 文字。m：Shift=2、Alt=3、Ctrl=5） |
| Home、End | `ESC[H`、`ESC[F` |
| Insert、Delete | `ESC[2~`、`ESC[3~` |
| PageUp、PageDown | `ESC[5~`、`ESC[6~` |
| F1〜F4 | `ESC OP`〜`ESC OS` |
| F5〜F12 | `ESC[15~`、`17~`、`18~`、`19~`、`20~`、`21~`、`23~`、`24~` |
| Tab、Enter、Backspace、Esc | `#9`、`#13`、`#127`、`#27` |
| Ctrl + 英字 | `#1`〜`#26` |

文字を送るときは、UTF-8 にしてから、`FPty.Write` へ渡す。

### 8.3 出力（`PtyOutput`）

1. ページの準備前なら、`FPendingSend` に貯める（準備後に、まとめて送る）。
2. ページへ `out`（UTF-8 から文字列に直して）。
3. `lmRaw` なら、そのまま `WriteLog`。`lmPlain` なら、エスケープシーケンスを除いた文字を `WriteLog`（`ESC[…` と `ESC]…BEL/ST` を取り除き、`CR` だけの行頭戻しはそのまま、`BS` は 1 文字戻す）。
4. `OnOutput` が付いていれば、エスケープを除いた文字を渡す。`OnLine` は、除いた文字を行ごとに分けて、確定した行を渡す（改行を含まない残りは、次の出力まで持ち越す）。

### 8.4 ログ

- `OpenLog`：`LogMode` が `lmOff` なら何もしない。`LogDir`（空なら `EXE\Logs`）を作り、`yyyymmdd_hhnnsszzz.log` を、共有付きで開く（`CXCreateFileShared`）。
- `WriteLog`：UTF-8 で書く。`LogMaxSize`（KB）を超えたら、閉じて、新しい時刻のファイルを開く。
- 書き込みの失敗（フォルダーが作れない、など）は、`OnError` に 1 回だけ伝えて、その後のログは、止める（端末の動きは、続ける）。

### 8.5 コマンド履歴

- `cmd` を受けたら、`AddHistory`：`FHistory` の末尾に足す（直前と同じなら、足さない）。`HistoryMax` を超えたら、先頭を消す。
- `OnCommand`。
- 履歴のファイル：`HistoryDir`（空なら `EXE\History`）の `yyyymmdd_hhnnsszzz-CmdHistory.log`（`Start` したときの時刻）。コマンドが増えるたびに、1 行ずつ追記する（UTF-8、共有付き）。
- 取り出し方は、7 章のとおり。矢印キーでの呼び出しや、補完でも、画面の文字から取るので、正しく取れる。プロンプトが 1 行に収まらない（複数行のプロンプト）場合は、最後の行を使う。

### 8.6 大きさ・フォーカス

- `Resize`（LCL）：`FWindowParent` を、部品いっぱいに広げる。WebView2 の大きさは、`FBrowser.UpdateSize` で合わせる。xterm.js 側の `fit()` が、桁数・行数を決める。
- `Enter`（フォーカス）：`FBrowser.Focus`（WebView2 にキーボードを渡す）。

### 8.7 RunCapture（パイプ方式）

1. `CreatePipe` を 3 本作る（子の標準入力は、空にする）。標準出力・標準エラー出力を、別々のパイプにつなぐ。
2. `CreateProcessW('cmd.exe /c ' + ACommandLine, ..., STARTF_USESTDHANDLES, CREATE_NO_WINDOW or CREATE_UNICODE_ENVIRONMENT)`（`WorkDir`、`Environment` を使う）。窓は作らない。
3. 2 本のパイプを、`PeekNamedPipe` と `ReadFile` で交互に読む（片方が詰まらないように）。ループの間に `Application.ProcessMessages`。
4. 終了コードを得て、ハンドルを閉じる。出力の文字コードは、起動時のコードページ（日本語の Windows では 932）として、UTF-8 に直す。`ATimeoutMs` を超えたら、プロセスを止めて、`False`。

## 9. 配色・フォント

- フォント：`Font.Name`（ない場合は、`Consolas`、`BIZ UDGothic`、`MS Gothic`、`monospace` の順に、ページの `fontFamily` へ並べて送る）、`Font.Size`（pt）を、px に直して送る（`pt × 96 / 72`、表示スケールを掛ける）。
- 文字色：`Font.Color`。`clDefault` なら `Theme` の標準。
- 背景色：`Color`。`clDefault` なら `Theme` の標準。
- `Theme`：`ctAuto` は、`CsOsIsDark`（OS のダーク）で決める。OS が変わったときの追従は、他の部品と同じ（`uCsEditor` の仕組みに合わせる）。標準の配色は、次のとおり（VS Code の端末に合わせる）。

| 項目 | ダーク | ライト |
|---|---|---|
| 背景・文字 | `#1E1E1E`・`#CCCCCC` | `#FFFFFF`・`#333333` |
| カーソル | `#AEAFAD` | `#000000` |
| 選択 | `#264F78` | `#ADD6FF` |
| 黒 / 赤 / 緑 / 黄 | `#000000` `#CD3131` `#0DBC79` `#E5E510` | `#000000` `#CD3131` `#00BC00` `#949800` |
| 青 / 紫 / 水色 / 白 | `#2472C8` `#BC3FBC` `#11A8CD` `#E5E5E5` | `#0451A5` `#BC05BC` `#0598BC` `#555555` |
| 明るい 黒 / 赤 / 緑 / 黄 | `#666666` `#F14C4C` `#23D18B` `#F5F543` | `#666666` `#CD3131` `#14CE14` `#B5BA00` |
| 明るい 青 / 紫 / 水色 / 白 | `#3B8EEA` `#D670D6` `#29B8DB` `#E5E5E5` | `#0451A5` `#BC05BC` `#0598BC` `#A5A5A5` |

- `Color` を `clDefault` 以外にしたとき、背景のまわり（`TCcmd` の余白、`FWindowParent` の背景）も、同じ色で塗る。

## 10. 設計時

- 部品を置くと、`TCustomPanel` として、枠と、部品の名前（`Name : TCcmd`）を出す（TCPreview と同じ見た目）。WebView2・ConPTY は、設計時は動かさない。
- `AutoStart` は、設計時は、何もしない。
- パレットの [CX] に出す（アイコンは `ccmd_icon.lrs`）。

## 11. 決めていること

| 項目 | 決めたこと |
|---|---|
| 動かし方 | ConPTY（Windows 11 だけ）。シェルは、既定 `cmd.exe` |
| 画面 | WebView2 の中の xterm.js |
| 文字コード | 端末とは、UTF-8 で通信する（`input`・`out`）。cmd.exe 内部のコードページは、ConPTY が変換する |
| 出力のまとめ | 読み取りスレッドが、約 10 ms か 64KB でまとめて、メインスレッドへ渡す |
| 起動の順番 | ページの準備（`ready`）の後に、シェルを起動する（桁数・行数を、最初から、正しく渡すため） |
| 終了 | ジョブオブジェクトで、孫プロセスまで止める。シェルの終了は、読み取りスレッドが自分で見つける（ConPTY は、パイプを閉じないため） |
| ログの形式 | 既定は、エスケープを除いた文字。vi のような全画面の画面更新は、ログでは読みにくい（`lmRaw` なら、生のまま） |
| コマンド履歴 | 画面の文字から取る（プロンプトの終わりと、Enter の時点で決める） |
| 標準出力とエラー出力 | 端末モードは 1 本。分けたいときは `RunCapture` |
| 貼り付け | Ctrl+V・Ctrl+Shift+V・Shift+Insert・右クリックのメニュー。複数行は、貼り付けの枠（`?2004`）がシェルで有効なら、枠で囲む（xterm.js の `paste`） |
| スクロールバー | xterm.js の標準のスクロールバー（`color-scheme` に追従） |
| IME | xterm.js の入力欄の標準の動きに任せる（WebView2 で、変換・確定ができること） |
| 設計時 | WebView2・ConPTY は動かさない |
| ほかの部品との関係 | 他の部品の `Theme`（`TCMTheme`）、`uCXLang`（文字列）、`CXCreateFileShared`（共有付きの書き込み）を使う |

## 12. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| 画面が真っ白で、何も出ない | `terminal.html` の場所（`TerminalPath`、`WebView2.ini` の `TerminalFolder`）、`OnError`、`OpenDevTools` |
| 起動したのに、何も出ない | `ready` が来ているか（`Ready`）、`FPendingStart`、5.2 の 3（`STARTF_USESTDHANDLES`） |
| 文字が化ける | 5.3 の UTF-8 の持ち越し、8.7 の RunCapture（コードページ） |
| ウィンドウの大きさを変えても、桁数が変わらない | `resize` の通知、`ResizePseudoConsole`、`ResizeObserver` |
| 終了しても、プロセスが残る | ジョブオブジェクト（5.2 の 7）、`Stop` |
| `ClosePseudoConsole` で固まる | 読み取りが済んでから呼んでいるか（5.3 の 4・5） |
| シェルが終わっても `OnExit` が来ない | 読み取りスレッドの終了検知（5.3 の 3） |
| vi・PowerShell の表示が崩れる | xterm.js のバージョン、`opt` の `scrollback`・フォント（全角の幅） |
| ログ・履歴が書かれない | `LogMode`、`LogDir`・`HistoryDir`（書き込み権限）、8.4 の 失敗の扱い |
| コマンド履歴が空・ずれる | 7 章の「プロンプトの終わり」の記録（`cIdleMs`）、複数行のプロンプト |
| スクロールバーの色が OS と合わない | 7 章の `color-scheme` |

## 13. この版の変更（1.0。新しく作る）

新しい部品 TCcmd を作る。既存の部品の動きは、変えない。変えるファイルは、次のとおり。

| ファイル | 変更 |
|---|---|
| `source/uCcmd.pas` | 新規 |
| `source/design/uCXReg.pas` | `TCcmd` を登録し、`uCcmd` を uses に足す。`ccmd_icon.lrs` を読み込む |
| `source/res/ccmd_icon.lrs` | 新規 |
| `source/uCXLang.pas` | 文字列を 8 つ足す（4.6） |
| `source/uCXRuntime.pas` | 変更なし（`TerminalFolder` は、既存の `CXResolveRuntimeDir` で読める） |
| `packages/cx.lpk`・`cx.pas`、`cxdsgn.lpk` | `uCcmd` と、アイコンを足す |
| `runtime/terminal/` | 新規（`terminal.html`、`lib/`） |
| `THIRD_PARTY_NOTICES.md` | xterm.js の出典とライセンスを足す（3 行） |
| `docs/TCcmd_Usage.md`、`docs/en/TCcmd_Design.md`・`TCcmd_Usage.md` | 設計の確認の後、コードができてから作る |
| `README.md`・`README.ja.md` | 部品の表と説明に、TCcmd を足す |
