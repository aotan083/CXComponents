# TCcmd 取扱説明書

作者: aotan083
日付: 2026-11-07
版: 1.0

---

## 1. 概要とクラス

コマンドプロンプト（cmd.exe）や PowerShell・ssh などを、フォームの中で動かす部品です。画面の表示とキー入力は部品が受け持つので、コンソールの窓は出ません。

- シェルは Windows の ConPTY（擬似コンソール）で動かす。リダイレクト（`>`・`>>`・`2>&1`）、パイプ（`|`）、`vi`・`ssh`・PowerShell・`python` などの対話も動く。
- 画面は、WebView2 の中の xterm.js が描く（色・カーソル・全角・選択・スクロール・検索）。
- コマンドの結果を取り込みたいときは、`RunCapture`（標準出力・エラー出力・終了コードを別々に受ける）を使う。
- 出力のログ、実行したコマンドの履歴を、ファイルに残す。
- 設定はオブジェクトインスペクタで行う。置いて実行するだけで、コマンドプロンプトとして動く。

| 項目 | 内容 |
|---|---|
| Lazarus | 5.0 以降 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット）。Linux・macOS は対象外 |
| パレット | CX |
| 実行に必要なもの | Microsoft Edge WebView2 ランタイム（Windows 11 には最初から入っている）、WebView2Loader.dll（64 ビット版）、WebView2.ini、terminal フォルダー（2章） |
| メモリ | 約 60MB（WebView2）。一度も表示しなければ WebView2 を起動しない |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCcmd` | `uCcmd` | cx | `TCustomPanel` | ターミナルの部品 |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCcmdLogMode` | `uCcmd` | ログの書き方。`lmOff`・`lmPlain`・`lmRaw` |
| `TCcmdCursorStyle` | `uCcmd` | カーソルの形。`ccBlock`・`ccUnderline`・`ccBar` |
| `TCcmdBellMode` | `uCcmd` | ベルの扱い。`bmNone`・`bmSound`・`bmFlash` |

- フォームに置くと、uses に `uCcmd` が自動で入り、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

## 2. フォームに置いて動かすまで

1. パレット [CX] から TCcmd をフォームに置き、`Align = alClient` などにする。
2. EXE と同じフォルダーに、2.1 のファイルを置く。
3. 実行する。画面の準備ができると、自動で `cmd.exe` が始まる（`AutoStart = True`）。

- IDE の上（設計時）では WebView2 もシェルも動かさない。薄い枠と部品の名前だけが出る。
- 別のシェルにするときは、`Shell` に `powershell.exe` や `ssh.exe` を、`Params` に引数を書く。

### 2.1 実行時のファイル

```
MyApp.exe
WebView2.ini                       （必ず置く。2.2）
WebView2Loader.dll                 （64 ビット版）
WebView2Data\                      （WebView2 のユーザーデータ。自動で作る）
terminal\
  terminal.html
  lib\
    xterm.js / xterm.css
    addon-fit.js / addon-search.js
    licenses\xterm-LICENSE.txt
Logs\                              （ログ。自動で作る）
History\                           （コマンド履歴。自動で作る）
```

- terminal フォルダーは `runtime\terminal`。
- WebView2Loader.dll は、WebView4Delphi のリポジトリ（https://github.com/salvadordf/WebView4Delphi）から入手する。
- WebView2 の準備は、画面が初めて表示されたときに部品が自分で行う。アプリの .lpr には何も書かない。

### 2.2 WebView2.ini

EXE と同じフォルダーに置く。CX の WebView2 部品で共通。

```ini
[WebView2]
LoaderDllPath=
UserDataFolder=
MonacoFolder=
PreviewFolder=
TerminalFolder=

[CX]
Language=
```

| キー | 中身 | 空・書かないとき |
|---|---|---|
| `LoaderDllPath` | WebView2Loader.dll のファイル | EXE のフォルダーの WebView2Loader.dll |
| `UserDataFolder` | WebView2 のユーザーデータのフォルダー | EXE のフォルダー\WebView2Data |
| `TerminalFolder` | `terminal.html` と `lib` があるフォルダー | EXE のフォルダー\terminal |
| `MonacoFolder`・`PreviewFolder` | TCcmd は使わない | ― |
| `Language`（`[CX]`） | 画面の言語 `ja`・`en` | Windows の表示言語 |

- ファイルは必ず置く。キーの値はすべて空でもよい。
- 相対パスは、EXE のフォルダーから数える。絶対パスも書ける。
- 値の中に `%名前%` を書くと、置き換える。名前は、同じ `[WebView2]` のキー、なければ Windows の環境変数（例：`CXROOT=C:\CX\runtime` を書いて、`TerminalFolder=%CXROOT%\terminal` とする）。見つからない名前は、そのまま残る。
- 起動してから最初に使うときに 1 回だけ読む。

### 2.3 terminal の場所の決め方

上から順に、最初に決まったものを使う。

| 順 | 決め方 |
|---|---|
| 1 | `TerminalPath` が空でなければ、その場所 |
| 2 | WebView2.ini の `TerminalFolder` が空でなければ、その場所 |
| 3 | EXE のフォルダーの `terminal` |

- 見つからなければ `OnError`（「terminal.html が見つかりません：（場所）」）。

### 2.4 画面の言語

右クリックメニュー・終了のメッセージ・エラーの文は、日本語か英語で出る。言語は cx の部品すべてで 1 つ（WebView2.ini の `[CX]` の `Language`。空なら Windows の表示言語）。

## 3. 使えるキーとマウス

| 操作 | 動き |
|---|---|
| 文字・矢印・Home・End・PageUp・PageDown・F1〜F12・Ctrl+英字 | シェルへ送る |
| ドラッグ | 範囲を選ぶ |
| Ctrl+C | 選択があればコピー。なければ、実行中の処理を止める（中断） |
| Ctrl+Shift+C | 常にコピー |
| Ctrl+V・Ctrl+Shift+V・Shift+Insert | 貼り付け |
| 右クリック | メニュー（コピー・貼り付け・すべて選択・画面を消す） |
| ホイール | スクロール |
| Ctrl+ホイール | 文字の大きさを 1 ずつ変える（6〜48）。`Font.Size` が変わる |
| エクスプローラーからファイルをドロップ | ファイルの場所を、入力位置に貼り付ける（空白を含む場所は `"` で囲む。複数のファイルは空白でつなぐ）。`ReadOnly`・`Enabled = False` のときは何もしない |

- 日本語の入力（IME）は、WebView2 の標準の動きに従う。
- `ReadOnly = True` または `Enabled = False` のときは、キー入力・貼り付けを受け付けない（出力は表示し続ける）。

## 4. プロパティ

| 名前 | 型 | 既定値 | 中身 |
|---|---|---|---|
| `Shell` | `string` | `cmd.exe` | 動かすプログラム（`powershell.exe`・`ssh.exe`・フルパスも可）。空なら `cmd.exe` |
| `Params` | `string` | '' | 起動の引数（例：`-NoLogo`）。`Shell` の後ろに付ける |
| `WorkDir` | `string` | '' | 作業フォルダー。空なら EXE のフォルダー |
| `Environment` | `TStrings` | 空 | 追加・上書きする環境変数（`名前=値`）。ない分は、アプリの環境を引き継ぐ |
| `AutoStart` | `Boolean` | `True` | 画面の準備ができたら、自動で `Start` する |
| `CloseOnExit` | `Boolean` | `False` | シェルが終わったとき、画面を閉じる（`Visible := False`）か。`False` なら画面を残して「[プロセスが終了しました（コード n）]」を出す |
| `MaxCount` | `Integer` | 1000 | 画面に残す行数（スクロールバックを含む）。100〜10000 に丸める |
| `LogMode` | `TCcmdLogMode` | `lmPlain` | ログの書き方（6.1） |
| `LogDir` | `string` | '' | ログのフォルダー。空なら `EXE\Logs` |
| `LogMaxSize` | `Integer` | 10240 | ログ 1 ファイルの最大サイズ（KB）。超えたら新しいファイルに切り替える |
| `HistoryDir` | `string` | '' | コマンド履歴のフォルダー。空なら `EXE\History` |
| `HistoryMax` | `Integer` | 1000 | `CmdHistory` に残す最大件数 |
| `Font` | `TFont` | Consolas・10 | フォント。等幅にする。`Font.Color` が `clDefault` なら `Theme` の文字色 |
| `Color` | `TColor` | `clDefault` | 背景色。`clDefault` なら `Theme` の背景色 |
| `Theme` | `TCMTheme` | `ctAuto` | `ctAuto`（OS に合わせる。OS を切り替えるとその場で変わる）／`ctLight`／`ctDark` |
| `CursorStyle` | `TCcmdCursorStyle` | `ccBlock` | カーソルの形 |
| `CursorBlink` | `Boolean` | `True` | カーソルを点滅させる |
| `CursorColor` | `TColor` | `clDefault` | カーソルの色。`clDefault` なら `Theme` の色 |
| `SelectionColor` | `TColor` | `clDefault` | 選択範囲の色。`clDefault` なら `Theme` の色 |
| `Caption` | `string` | '' | タイトルの文字。`AutoCaption` が `True` のとき、シェルが設定したタイトルに追従する |
| `AutoCaption` | `Boolean` | `True` | `Caption` を、シェルのタイトルに追従させる |
| `ReadOnly` | `Boolean` | `False` | `True` なら、キー入力・貼り付けを受け付けない |
| `BellMode` | `TCcmdBellMode` | `bmSound` | ベルの扱い。`bmNone`（何もしない）／`bmSound`（音）／`bmFlash`（画面を一瞬光らせる） |
| `TerminalPath` | `string` | '' | `terminal.html` の場所（2.3） |
| `PopupMenu` | `TPopupMenu` | nil | 右クリックのメニュー。nil なら既定のメニュー |
| `Align`・`Anchors`・`BorderSpacing`・`Constraints`・`Enabled`・`Visible`・`TabOrder`・`TabStop`・`ShowHint`・`Hint` | | | 標準のもの |

実行時だけ使えるもの（読み取り専用）：

| 名前 | 型 | 中身 |
|---|---|---|
| `Active` | `Boolean` | シェルが動いているか |
| `ExitCode` | `Integer` | シェルの終了コード（動いている間は -1） |
| `ProcessId` | `Cardinal` | シェルのプロセス番号（動いていなければ 0） |
| `Cols`・`Rows` | `Integer` | 今の桁数・行数（部品の大きさとフォントから自動で決まる） |
| `Title` | `string` | シェルが設定したタイトル |
| `Ready` | `Boolean` | 画面の準備ができたか |
| `CmdHistory` | `TStringList` | これまでに実行したコマンド（古いものが先） |

- `Font`・`Color`・`Theme`・`CursorStyle`・`CursorBlink`・`CursorColor`・`SelectionColor`・`MaxCount` は、変えるとすぐに画面へ反映される。
- `Shell`・`Params`・`WorkDir`・`Environment` は、次に `Start` したときから効く。

## 5. メソッドとイベント

### 5.1 メソッド

| 名前 | 中身 |
|---|---|
| `Start` | シェルを起動する。すでに動いていれば何もしない。画面の準備前なら、準備ができてから起動する |
| `Stop` | シェルを終了させる（孫プロセスもまとめて）。動いていなければ何もしない |
| `Restart` | `Stop` してから `Start` する |
| `SendText(AText)` | 文字列を、そのままシェルへ送る（`ReadOnly`・`Enabled = False` のときは何もしない） |
| `Execute(ALine)` | 1 行を送って Enter を押す。コマンド履歴にも入り、`OnCommand` が起きる |
| `SendKey(AKey, AShift)` | キー（矢印・Home・End・PageUp・PageDown・F1〜F12・Delete など）を送る |
| `SendCtrlC` | Ctrl+C を送る（実行中の処理を止める） |
| `Paste` | クリップボードの文字列を貼り付ける |
| `CopySelection` | 選択している文字列をクリップボードへ入れる |
| `SelectAll` | 全選択 |
| `ClearScrollback` | 画面の上へ流れた履歴を消す（今の画面は残す） |
| `ScrollToBottom` | 一番下までスクロールする |
| `FindNext(AText, AMatchCase)` | 次を探して選択する。`AMatchCase` の既定値は `False` |
| `FindPrev(AText, AMatchCase)` | 前を探して選択する |
| `RequestBufferText` | 画面と履歴の全文を求める。届いたら `OnBufferText` が起きる |
| `SaveBufferTo(AFileName)` | 画面と履歴の全文を、UTF-8 のファイルに書く |
| `SetFocus` | 端末へ、キーボードフォーカスを移す |
| `RunCapture(ACommandLine, AStdOut, AStdErr, AExitCode, ATimeoutMs)` | 7.3 |
| `OpenDevTools` | WebView2 の開発者ツールを開く（調べるとき用） |

### 5.2 イベント

| 名前 | 引数 | いつ |
|---|---|---|
| `OnReady` | `Sender` | 画面の準備ができたとき |
| `OnStart` | `Sender` | シェルを起動したとき |
| `OnExit` | `Sender; AExitCode: Integer` | シェルが終わったとき（`CloseOnExit` の処理より前） |
| `OnOutput` | `Sender; const AText: string` | 出力が来たとき。エスケープシーケンスを除いた文字 |
| `OnLine` | `Sender; const AText: string` | 出力のうち、改行までそろった 1 行が確定したとき |
| `OnCommand` | `Sender; const AText: string` | Enter でコマンドを実行したとき（打った文字列） |
| `OnTitleChange` | `Sender` | シェルのタイトルが変わったとき |
| `OnBell` | `Sender` | ベルが鳴ったとき（`BellMode` に関わらず起きる） |
| `OnResize` | `Sender; ACols, ARows: Integer` | 桁数・行数が変わったとき |
| `OnBufferText` | `Sender; const AText: string` | `RequestBufferText` の結果が届いたとき |
| `OnError` | `Sender; const AMessage: string` | 起動の失敗・画面の読み込みの失敗など。設定しないときはメッセージを表示する（同じ文は 1 回だけ） |

## 6. ログと履歴

### 6.1 ログ

`Start` したときの時刻で、`LogDir\yyyymmdd_hhnnsszzz.log` を作り、出力を書く（UTF-8）。

| `LogMode` | 書くもの |
|---|---|
| `lmOff` | ログを書かない |
| `lmPlain`（既定値） | エスケープシーケンスを除いた文字 |
| `lmRaw` | 生の出力（エスケープシーケンス付き） |

- `LogMaxSize`（KB）を超えたら、新しい時刻のファイルに切り替える。
- ほかのプログラムから開いたままでも読める（共有付きで書く）。
- `vi` のような全画面の表示は、`lmPlain` では読みにくい。
- フォルダーが作れないなど書けないときは、`OnError` に 1 回だけ知らせて、ログだけ止める（端末は動き続ける）。

### 6.2 コマンド履歴

- Enter で実行したコマンドを、`HistoryDir\yyyymmdd_hhnnsszzz-CmdHistory.log` に 1 行ずつ追記する（UTF-8）。`CmdHistory` にも入る（直前と同じものは入れない。`HistoryMax` を超えたら古いものから消す）。
- 矢印キーでの呼び出しや補完で入力したものも、画面の文字から取るので正しく入る。
- プロンプトが複数行のときは、最後の行を使う。

## 7. 使い方の例

### 7.1 コードなしで置くだけ

フォームに TCcmd を置き、`Align = alClient` にして、2.1 のファイルを EXE の隣に置く。

### 7.2 PowerShell にする

```pascal
Cmd1.Shell := 'powershell.exe';
Cmd1.Params := '-NoLogo';
Cmd1.WorkDir := 'C:\work';
Cmd1.Environment.Add('MY_VAR=abc');
Cmd1.Restart;
```

### 7.3 コマンドを実行して結果を受ける

```pascal
var
  O, E: string;
  Code: Integer;
begin
  if Cmd1.RunCapture('dir /b *.pas | sort', O, E, Code, 10000) then
    Memo1.Text := O                  // 標準出力
  else
    ShowMessage('時間切れ');
end;
```

- `RunCapture` は、`Shell` の種類によらず `cmd.exe /c` で実行する。リダイレクトやパイプは cmd.exe が処理する。窓は出ない。
- `ATimeoutMs` が 0 なら待ち続ける。時間を超えたらプロセスを止めて `False`。
- 待つ間も、フォームの操作（メッセージ）は処理する。
- 出力はこの画面には出ない。

### 7.4 画面でコマンドを実行する

```pascal
Cmd1.Execute('dir');
```

### 7.5 終了したら閉じる

```pascal
Cmd1.CloseOnExit := True;            // exit で、画面が消える
Cmd1.OnExit := @Cmd1Exit;

procedure TForm1.Cmd1Exit(Sender: TObject; AExitCode: Integer);
begin
  Caption := Format('終了しました（コード %d）', [AExitCode]);
end;
```

### 7.6 コードで作る

```pascal
uses
  uCcmd;

procedure TForm1.FormCreate(Sender: TObject);
var
  T: TCcmd;
begin
  T := TCcmd.Create(Self);
  T.Align := alClient;
  T.Theme := ctDark;
  T.Parent := Self;
end;
```

## 8. 制限

- Windows 11 だけ。
- 標準出力とエラー出力は、端末としては 1 本にまとまる（本物の端末と同じ）。分けたいときは `RunCapture`。
- 透過（半透明）には対応しない。
- 複数の端末を並べたいときは、TCPageControl の各タブに TCcmd を 1 つずつ置く。
