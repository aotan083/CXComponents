# TCMonacoEditor 設計書

作者: aotan083
日付: 2026-10-30
版: 1.3

---

## 1. 目的と方針

TCMonacoEditor は、フォームに貼るだけで使える、WebView2 と Monaco Editor による完全オフラインのエディタ部品である。タブ・エディタ・プレビュー（Markdown・コード）・検索・置換・印刷を 1 つの部品に内蔵する。使い方（利用者に見える動き）は取扱説明書 `TCMonacoEditor_Usage.md`（以下「取説」）にあり、この設計書は、それをどう作っているかを書く。

| No | 方針 |
|---|---|
| 1 | 利用者が書くコードは 0 行。設定はすべてオブジェクトインスペクタで行う。WebView2 の準備も部品が行う（6章） |
| 2 | TSynEdit と同じように、1 つのフォームに何個でも貼れる。1 つ 1 つが完結したエディタになる |
| 3 | イベントは、設定しなくても動く（設定しないときは部品が既定の動きをする） |
| 4 | 中の部品は見せない。外側の TCMonacoEditor に、必要なプロパティ・イベントだけを出す |
| 5 | ダイアログは、設定しなければ内蔵のもの、設定すればそれを使う。複数のエディタが同じダイアログを選べる |
| 6 | 物理ファイルを唯一の正とする（DB・CMS は使わない） |
| 7 | 裏側（ファイル・フォルダー・システムの制御）は Pascal、表側（編集・プレビューの表示）は WebView2 の中の JavaScript が受け持つ |
| 8 | WebView2 のメモリ（エディタ 1 つで約 60MB）は許す。エディタ 1 つにつき WebView2 は最大 2 つ（エディタ用・プレビュー用）。プレビューを一度も出さなければ 1 つ |
| 9 | 新しい機能は「自分のアプリに必要か」で決める。VS Code に近づけること自体は目的にしない。Monaco に最初からある機能は、止めずに残す |

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCmonacos.pas` | cx（実行時） | `TCMonacoEditor`（外側の部品）・`TCMPage`・`TCMFormHook`・`TCMTabDragOutEvent`、関数 `CMActiveEditor`・`CMSplitLine`・`CMColorToHex`。タブの分離（送る・受ける。4.11） |
| `uCmmonacoview.pas` | cx（実行時） | `TCMMonacoView`（Monaco を表示する中の部品）・`TCMDocument`・`TCMMenuItem`。文字コードの読み書き、言語の判定、文字列の変換関数 `CMToHankaku`・`CMToZenkakuKatakana`・`CMToZenkakuHiragana` |
| `uCmdpreview.pas` | cx（実行時） | `TCMMarkdownPreview`（プレビュー）。印刷 |
| `CMonacoTabs.pas` | cx（実行時） | `TCMTabBinder`（view と ATTabs をつなぐ。タブを外へ出したことの検知も行う）・`TCMBinderDragOutEvent` |
| `CMonacoPreview.pas` | cx（実行時） | `TCMPreviewBinder`（view とプレビューをつなぐ）・`TCMSyncScroll` |
| `CMonacoFindDlg.pas` | cx（実行時） | `TCMFindDialog`（非表示の部品）・`TCMFindForm` |
| `CMonacoActions.pas` | cx（実行時） | 標準アクション 25 個（取説 12章）と元のクラス `TCMEditorAction`・`TCMEditorToggleAction` |
| `uCXRuntime.pas` | cx（実行時） | WebView2.ini を読む関数と `CXStartWebView2`（6章。中身は `TCTabBrowser_Design.md` 9章） |
| `uCXReg.pas` | cxdsgn（設計時） | `RegisterComponents('CX', [..., TCMonacoEditor, TCMFindDialog, ...])`、`RegisterActions('CX', [25 個], nil)` |
| `cx_icons.lrs` | cxdsgn（設計時） | アイコン（`TCMonacoEditor`・`TCMFindDialog` と、それぞれの `_150`・`_200`） |
| `monaco\editor.html` | 実行時のファイル | Monaco を読み込み、Pascal とやり取りする HTML/JS（5.3） |
| `preview\preview.html` と `preview\lib\` | 実行時のファイル | プレビューの HTML/JS と、ライブラリ一式（5.3・7章） |

- cx の必要パッケージ：`LCL`、WebView4Delphi の Lazarus 用パッケージ、`atflatcontrols_package`（ATTabs）。
- アクションはパレットに出ないため、アイコンは持たない。並び順は取説 12章の表の順。

**ユニットの参照**（一方向。外側の `TCMonacoEditor` は `FindDialog` プロパティのために `CMonacoFindDlg` を interface で使う。外側と中の部品を同じユニットに置くと循環参照になるため分ける）

```
uCXRuntime（場所を決める関数・WebView2 の準備）
   ↑ uses（implementation）
uCmmonacoview（TCMMonacoView）・uCmdpreview（TCMMarkdownPreview）
   ↑ uses
CMonacoTabs・CMonacoPreview・CMonacoFindDlg
   ↑ uses
uCmonacos（TCMonacoEditor）
   ↑ uses
CMonacoActions
```

- `uCmonacos` の uses：`Windows, Classes, SysUtils, Controls, Forms, ExtCtrls, Graphics, Dialogs, Menus, LCLType, ActnList, Registry, ShellApi, ATTabs, ucmmonacoview, ucmdpreview, CMonacoTabs, CMonacoPreview, CMonacoFindDlg`。implementation：`LazUTF8, StrUtils`。
- アプリが `uCmonacos` だけを uses すれば済むように、`TCMEncoding`・`TCMFindOption(s)`・`TCMSyncScroll`・`TCMTabImageEvent` を型の別名で、`ceUTF8` 〜 `ceCP932`・`foMatchCase`・`foWholeWord`・`foLoop`・`ssNone`・`ssEditorToPreview`・`ssBoth` を定数で出し直す。
- 中の部品の名前は接頭辞 `TCM` をそろえる。`TCustomXxx` の形は使わない（Lazarus では「継承元の基底クラス」を表す慣例があり、中に持つ部品には合わないため）。

## 3. 外側の部品（TCMonacoEditor）

### 3.1 構成

```
TCMonacoEditor（TCustomPanel）
 ├ タブ（TATTabs）            … 上端。MultiDocument = False なら隠す
 ├ Monaco（TCMMonacoView）    … 中央。全タブの本文を持つ（タブごとに Monaco の「モデル」が 1 つ）
 ├ 境目（TSplitter）
 └ プレビュー（TCMMarkdownPreview） … 右側。ShowPreview で出す
```

- 実行時は、中の部品がパネルの全面を覆う。
- 設計時（IDE の上）は WebView2 を起動しない。`Paint` で薄い枠と部品の名前を描く。
- 起動直後、WebView2 の準備ができるまでの間は、パネルの背景色が見える。背景色は `Theme` に合わせる（ダーク #1E1E1E、ライト #FFFFFF）。
- `TControl` の `Text`・`Caption` は、public で宣言し直して隠す（見えているタブの本文・タイトルにする）。`ControlStyle` から `csSetCaption` を外す。
- 境目・タブそのものは出さない。見た目の設定（`SplitterResizeStyle`・`SplitterWidth`・`PreviewWidth`・`TabFlat`・`TabSeparator`）だけを出す。
- コードで `Create` したときは、`Parent` を設定した時点でフォームの終了の確認（`TCMFormHook`）に加わる。

### 3.2 API と中で呼ぶもの

`ed` は `TCMonacoEditor`、view は `TCMMonacoView`、preview は `TCMMarkdownPreview`、`TCMPage` は `uCmonacos` のクラス。動きは取説 4〜7章。

**タブの中身とファイル（`ed`・`ed.Pages[n]`）**

| 名前 | 中で呼ぶもの |
|---|---|
| `Text` | `TCMPage.GetText`・`SetText` → view `DocumentText[i]`。`ed` は `CurPage.Text` |
| `Caption` | view `DocumentTitle[i]` |
| `FileName` | view `DocumentFileName[i]` |
| `Modified` | view `DocumentModified[i]` |
| `Encoding` | view `DocumentEncoding[i]` |
| `Language` | view `DocumentLanguage[i]` |
| `LineCount` | `TCMPage.GetLineCount`（写しの `Text` から数える） |
| `LoadFromFile` | `PageLoad(i, FileName)` |
| `Save` | `PageSave(i)` |
| `SaveAs` | `PageSaveAs(i, FileName)` |
| `Clear` | `PageClear(i)` |
| `Close` | `PageClose(i, Force)` |

- `ed` の同じ名前のものは、`CurPage`（見えているタブの `TCMPage`）の同じ名前を呼ぶ。

**タブの集まり（`ed`）**

| 名前 | 中で呼ぶもの |
|---|---|
| `OpenFile` | 名前が ''：`OpenWithDialog`。`MultiDocument = True`：view `OpenFile`。`False`：0 番に `LoadDocument` |
| `NewPage` | `True`：view `AddDocument('')`。`False`：0 番を `ClearDocument` |
| `SaveAll` | view `SaveAll` |
| `CloseAll` | `True`：view `CloseAll`。`False`：`PageClose(0, Force)` |
| `CanCloseAll` | 保存していない文書ごとに 4.8 の確認（閉じない） |
| `FindPage` | view `FindDocument` |
| `MovePage` | view `MoveDocument` |
| `ActiveIndex` | view `ActiveIndex` |
| `PageCount` | view `DocumentCount` |
| `Pages[n]` | `GetPage(n)` |

**画面の上での操作（`ed`）**

| 名前 | 中で呼ぶもの |
|---|---|
| `SelText` | view `GetSelectedText`・`SetSelText`（`seltext`） |
| `SelStart`・`SelLength` | view `SelStart`・`SelLength`（`cursor` の写し） |
| `CanUndo`・`CanRedo` | view `CanUndo`・`CanRedo`（`canundo` の写し） |
| `GetCursorPos`・`SetCursorPos`・`SetSelection` | view の同じ名前（`setcursor`・`setsel`） |
| `LineText` | view `CursorLineText` |
| `LineWords` | `GetLineWords` → `CMSplitLine`（4.10） |
| `LineDelimiters`・`LineSkipEmpty`・`LineQuoteChar` | `FLineDelimiters`・`FLineSkipEmpty`・`FLineQuoteChar` |
| `Undo`・`Redo`・`Cut`・`Copy`・`Paste`・`SelectAll` | view の同じ名前 |
| `DeleteToEnd`・`DeleteToStart` | view の同じ名前（`delto`） |
| `DuplicateLine` | view `DuplicateLine`（`dupline`） |
| `ToggleOverwrite` | view `ToggleOverwrite`（`toggleow`） |
| `Find`・`FindNext`・`FindPrev`・`Replace`・`ReplaceAll` | view の同じ名前 |
| `ShowFindDialog` | 共有ダイアログか `FindDialog` を、対象をこのエディタにして開く（9章） |
| `CanPrint` | タブがあれば `True` |
| `Print` | `AsyncPrint`（7.3） |
| `SetFocus` | `AsyncSetFocus` を `QueueAsyncCall`（5.5） |
| `SearchText`・`ReplaceText`・`SearchOptions` | view の同じ名前 |
| `TopLine`・`Ready` | view の同じ名前 |
| `Monaco`・`Preview` | `FMonaco`・`FPreview` |

**イベント**

| 名前 | 中でつなぐもの |
|---|---|
| `OnReady`・`OnChange`・`OnCursorChange`・`OnModeChange`・`OnModifiedChange`・`OnActiveChange`・`OnDocListChange`・`OnDocumentChange`・`OnToggleMaximize`・`OnFontSizeChange`・`OnLineNumbersChange` | view の同じ名前を中継（`Sender` を自分に差し替える）。`OnActiveChange` ではプレビュー・検索ダイアログの見出しも更新 |
| `OnSave` | view を中継（前に使ったフォルダーも覚える） |
| `OnQueryClose` | `DoQueryClose` |
| `OnNeedFileName` | `MonacoNeedFileName`・`AskPageFileName` |
| `OnFileDrop` | `MonacoFileDrop` |
| `OnOpenMarkdown` | `PreviewOpenMarkdown` |
| `OnFindDone`・`OnReplaceAllDone` | `MonacoFindDone`・`MonacoReplaceAllDone` |
| `OnPopup` | `MonacoPopup` |
| `OnGetTabImageIndex` | `BinderGetImageIndex` |
| `OnTabDragOut` | `BinderTabDragOut`（4.11.2）。binder の `OnDragOut` を受け、`TearOff` の初めの値を決めて呼ぶ。そのあと `TearOff` なら部品が分離する |
| `OnKeyDown` | `MonacoAccelKeyDown` → `KeyDown`（5.6） |
| `OnError` | `DoError`（設定しないときは `QueueAsyncCall(AsyncShowError)` で、同じメッセージは起動中に 1 回だけ `MessageDlg`。`GShownErrors`） |

**設定**

| 名前 | 中で持つもの・渡し方 |
|---|---|
| `MultiDocument` | `FMultiDocument`。設計時と、作ってから表示されるまでだけ変えられる（実行時の変更は無視。タブが複数あるときの扱いが決まらないため） |
| `ConfirmOnFormClose` | `FConfirmOnFormClose` |
| `TabTearOff` | `FTabTearOff`（既定 `True`）。分離（4.11.2・4.11.3）・結合（4.11.6）を行うか |
| `OpenDialog`・`SaveDialog`・`FindDialog` | `FOpenDialog`・`FSaveDialog`・`FFindDialog`（`FreeNotification`） |
| `TabFlat`・`TabSeparator` | `ApplyTabShape` → ATTabs の `OptShowFlat`・`OptShowFlatSepar` |
| `TabIcons`・`TabImages` | `ApplyTabIcons` |
| `WordWrap`・`LineNumbers`・`FontSize`・`TabSize`・`Folding`・`MatchBrackets`・`OccurrencesHighlight`・`Minimap`・`ReadOnly`・`JapaneseUI`・`DefaultLanguage`・`AutoLanguage`・`OpenDroppedFiles`・`QuotePrefix` | view の同じ名前（`opt`） |
| `Theme` | `FTheme` → view `Theme`（`ctAuto`→'auto'、`ctLight`→'vs'、`ctDark`→'vs-dark'）・`ApplyThemeColors` |
| `HitColorLight`・`HitColorDark`・`CursorLineColorLight`・`CursorLineColorDark` | `F…` に TColor のまま持ち、view の同じ名前へ `CMColorToHex` で '#RRGGBB' にして渡す |
| `SelectionColorStyle` | `FSelectionColorStyle`。`scCustom` 以外は表 `SelStyleLight`・`SelStyleDark` の色を `FSelectionColorLight`・`FSelectionColorDark` に入れ、view へ渡す |
| `SelectionColorLight`・`SelectionColorDark` | 書くと `SelectionColorStyle := scCustom`（.lfm の読み込み中は変えない）。.lfm には `scCustom` のときだけ保存する |
| `MonacoPath` | view `ResourcePath`（6章） |
| `ShowPreview` | `UpdatePreview` |
| `PreviewWidth` | `FPreviewWidth`（境目で変えた幅も入れる） |
| `SplitterResizeStyle`・`SplitterWidth` | `FSplitter` |
| `PreviewFontSize`・`BreakOnNewline`・`AllowRemoteImages` | preview の同じ名前 |
| `ColorScheme` | `FColorScheme` → preview `ColorScheme`（`csEditor`→'editor'、`csGitHub`→'github'） |
| `PreviewBackColor…`・`PreviewTextColor…`・`PreviewLinkColor…`（6 個） | `F…` に持ち、preview の `BackColorLight` などへ `CMColorToHex` で渡す |
| `SyncScroll`・`PreviewDelayMs` | `TCMPreviewBinder` |
| `PreviewPath` | preview `ResourcePath`（6章） |

**色の既定値**（`uCmonacos` の interface の定数。TColor は内部が 青・緑・赤 の順）

| 定数 | 値 | 色 |
|---|---|---|
| `DefHitColorLight` | `$0058EEFF` | #FFEE58 |
| `DefHitColorDark` | `$0008667D` | #7D6608 |
| `DefCursorLineColorLight` | `$00FFF2EA` | #EAF2FF |
| `DefCursorLineColorDark` | `$003C312C` | #2C313C |
| `DefPreviewBackColorLight` | `$00FEFFFF` | #FFFFFE |
| `DefPreviewBackColorDark` | `$001E1E1E` | #1E1E1E |
| `DefPreviewTextColorLight` | `$00000000` | #000000 |
| `DefPreviewTextColorDark` | `$00D4D4D4` | #D4D4D4 |
| `DefPreviewLinkColorLight` | `$00B16A00` | #006AB1 |
| `DefPreviewLinkColorDark` | `$00FF9437` | #3794FF |

| 選択の組 | 暗（`SelStyleDark`） | 明（`SelStyleLight`） |
|---|---|---|
| `scStandard` | `$00784F26`（#264F78） | `$00FFD6AD`（#ADD6FF） |
| `scBlue` | `$009E5A0E`（#0E5A9E） | `$00FFB67F`（#7FB6FF） |
| `scAmber` | `$00004E6B`（#6B4E00） | `$004FD5FF`（#FFD54F） |
| `scPurple` | `$00822D5A`（#5A2D82） | `$00FFA3C5`（#C5A3FF） |
| `scCustom` | `clNone`（使わない） | `clNone`（使わない） |

`CMColorToHex(色, 既定)`：`clDefault`・`clNone` なら既定を使う。システム色（`clWindow` など）は `ColorToRGB` で今の実際の色にする（OS の配色を変えても追いかけない）。赤・緑・青の順に並べ替えて '#RRGGBB'。外側は選んだ TColor をそのまま持つ（`clWindow` を選べばオブジェクトインスペクタにも `clWindow` と出る）。

### 3.3 TCMPage

```pascal
TCMPage = class
private
  FOwner: TCMonacoEditor;
  FId: Integer;               // 文書の Id（並べ替えても変わらない）
  function GetIndex: Integer; // FOwner の view で IndexOfId(FId)。閉じていれば -1
public
  constructor Create(AOwner: TCMonacoEditor; AId: Integer);
  procedure Clear;
  function LoadFromFile(const AFileName: string): Boolean;
  function Save: Boolean;
  function SaveAs(const AFileName: string = ''): Boolean;
  function Close(Force: Boolean = False): Boolean;
  property Caption, FileName, Modified, Encoding, Language, Text, LineCount;
end;
```

- 操作のたびに `GetIndex` で今の番号を引き、`TCMonacoEditor.PageXxx(番号)` か view の `DocumentXxx[番号]` を呼ぶ。-1 なら、読む値は空、操作は何もしない（`Boolean` は `False`）。
- 1 つのタブにつき 1 つだけ作り、エディタの `FPages` に入れる。解放はエディタを壊すとき。
- `Pages[n]` の番号が範囲の外なら `EListError`。

### 3.4 TCMFormHook

フォームごとに 1 つ（`TComponent`。持ち主はフォーム）。

| 持つもの | 中身 |
|---|---|
| `FEditors` | そのフォームのエディタの一覧 |
| `FActive` | 最後にフォーカスされたエディタ（`gotfocus` の知らせで `SetActive`） |
| `FFindDialog` | 共有の検索・置換ダイアログ（`SharedFindDialog` で、初めて使うときに作る） |
| `FOldCloseQuery` | フォームの元の `OnCloseQuery` |

- `CreateFor(フォーム)`：フォームの `OnCloseQuery` を覚えて、`FormCloseQuery` に差し替える。
- `FormCloseQuery`：元の `OnCloseQuery` を呼び、`CanClose` のままなら、エディタごとに `CanCloseAll`。1 つでも `False` なら、そこでやめる（残りは確かめない）。
- `ActiveEditor`：`FActive` があればそれ、無ければ最初のエディタ、無ければ nil。`CMActiveEditor(Form)` はこれを返す。
- エディタがフォーム以外（フレームなど）に置かれて共有ダイアログを使えないときは、エディタが自分の予備（`FPrivateFindDlg`）を作る。

## 4. 本文と文書

### 4.1 文書の管理

- エディタの WebView2 は 1 つのまま、Monaco の中に文書（モデル）を複数持ち、切り替えて表示する。タブを増やしても WebView2 は増えない。
- 文書ごとに、ファイル名・文字コード・BOM・変更の有無・Undo/Redo の履歴・カーソル位置・スクロール位置・言語を持つ（Undo・カーソル・スクロールは Monaco のモデル、それ以外は `TCMDocument`）。
- `TCMDocument`：`Id`・`FileName`・`Encoding`・`Modified`・`Text`（写し）・`Language`。view の `FDocs` に並び、`FActive` が見えている番号。
- 同じファイルは 2 つのタブで開かない。比べるときは大文字小文字を区別しない。
- タブは常に 1 枚以上。最後の 1 枚を閉じると、空の無題を作る（`OnDocListChange` は 1 回）。
- 起動直後は無題が 1 つある。`OpenFile` はこれを使わず、必ず新しいタブで開く。

### 4.2 本文の写し

- 本文の正（マスタ）は Monaco のモデル。Pascal 側（`TCMDocument.Text`）は読むための写し。写しを持つ理由は、Pascal から Monaco に値を聞くと返事が非同期になり、その場で値を返せないため。
- 人が入力すると、`editor.html` は入力が止まって 80 ミリ秒後に本文全体を `change` で送る。view は写しを更新し、見えている文書なら `OnChange` を呼ぶ。
- 選択・カーソル・Undo/Redo できるかは、`cursor`・`canundo` の知らせで受けて覚える（`FSelectedText`・`FSelStart`・`FSelLength`・`FCursorLine`・`FCursorCol`・`FCanUndo`・`FCanRedo`）。
- カーソル行の文字列は `cursorline` で受けて覚える（`FCursorLineText`・`FCursorLineSeq`。4.10）。
- `Text :=`：写しと同じなら、Monaco に `doc.settextifdiff` を送るだけ（写しが古いときに備え、Monaco 側でも比べ、違うときだけ置き換えて `textsync` を返す）。写しと違えば、写しを書き換えてから `doc.reset`・`doc.dirty` を送る（直後に読んでも新しい値が返る）。
- Monaco からの知らせが来たら、常にそちらで写しを上書きする（Monaco に合わせる）。
- `Ready` の前に書いたもの（本文・設定）は Pascal 側に預かり、`ready` のときに Monaco へ送る。
- `Ctrl+S` は、`editor.html` が最新の本文を付けて `save` で送るので、入力した直後でも最新の本文で保存される。標準アクション・`ed.Save` からの保存は写しを書く。
- 写しと Monaco がずれるのは、①`Ready` の前、②入力・選択の直後（約 0.1 秒）の 2 つだけ。

### 4.3 ファイル

- 読み込み：BOM があれば BOM に従う。無ければ UTF-8 として正しいかを調べ、正しくなければ CP932。
- 保存：読み込んだときの文字コードと BOM で書く。CP932 で表せない文字は例外（`OnError`）。
- 改行コード（CRLF / LF）は読み込んだときのものを保つ。改行のない新しい文書は CRLF。
- 言語：`AutoLanguage` なら、読み込み・名前を付けて保存のときに拡張子から決める（取説 9.2 の表）。分からなければ `DefaultLanguage`。
- 名前を付けて保存のダイアログの既定の拡張子は、言語から `DefaultExtFor` で決める（取説 7章）。
- 内蔵のダイアログの最初のフォルダーは、そのタブのフォルダー。無題なら前に使ったフォルダー（`OnSave` で覚える）。

### 4.4 保存していない文書の確認（DoQueryClose）

1. `OnQueryClose` があれば、`Index` を渡して呼び、その `CanClose` に従う。
2. 無く、`ConfirmOnFormClose = True` なら、「（タイトル） は変更されています。保存しますか？（いいえ = 保存せずに閉じる）」（はい・いいえ・キャンセル）。はいなら view `SaveDocument`（保存できなければ閉じない）。いいえなら閉じる。キャンセルなら閉じない。
3. 無く、`False` なら捨てる。

- 呼ぶとき：タブを閉じる（［×］・中ボタン・`Close`・`CloseAll`）、フォームを閉じる（`CanCloseAll`）、`MultiDocument = False` で開く・新規にする。

### 4.5 MultiDocument

| | `True` | `False` |
|---|---|---|
| タブ | 出す | 隠す（`FTabs.Visible := False`） |
| 開く | view `OpenFile`（新しいタブ） | 4.4 の確認のあと、0 番に `LoadDocument` |
| 新規 | view `AddDocument('')` | 4.4 の確認のあと、0 番を `ClearDocument` |
| 閉じる | view `CloseDocument` | 4.4 の確認のあと、0 番を `ClearDocument`（タブは増減しないので、`OnDocListChange`・`OnActiveChange` は出さない） |
| ドロップ | すべて開く | 最初のファイルだけ、開くと同じ |

- タブを隠して中で複数の文書を持つ状態は作らない（隠れた文書に切り替える手段がなくなるため）。

### 4.6 タブ（TCMTabBinder）

- view の `OnDocListChange` でタブを作り直し、`OnDocumentChange`・`OnActiveChange` で更新する。タイトルは `Caption`、変更ありなら後ろに ` *`、ヒントはフルパス。
- タブのクリック・［＋］・［×］（中ボタンも）・ドラッグでの並べ替えを、view の `ActiveIndex`・`AddDocument`・`CloseDocument`（4.4 の確認を通す）・`MoveDocument` に伝える。
- ATTabs は、フラット表示（`OptShowFlat = True`）では選ばれたタブも帯と同じ色で描く。そこで、タブごとの色（`TabColorActive`・`TabColorOver`。`OptShowEntireColor = True`）を全タブに設定して、見えているタブ・マウスを乗せたタブを塗り分ける。
- アクセントの線は出さない（エクスプローラーに合わせる）。
- ATTabs の `OptMouseDragOutEnabled` は `False` にする（ほかの ATTabs へタブを移す ATTabs の機能を止める。別のエディタのタブの帯に落とすと、文書を持たないタブだけが移り、タブと文書の対応が壊れるため）。
- タブを自分のアプリの外へ落としたことは、ATTabs の `OnEndDrag` で検知する（4.11）。

**アイコン**

- `TabIcons = True` で `TabImages` が無いとき：`SHGetFileInfo`（`SHGFI_USEFILEATTRIBUTES`・小さいアイコン）で拡張子からアイコンを取り、内部の画像リストに入れる。同じ拡張子は 1 回だけ取る。無題は '.txt'。ファイルが無くても拡張子だけで取れる。ファイルの関連付けに従う。
- `TabImages` があるとき：`OnGetTabImageIndex`（無ければ 0 番）。
- `TabIcons = False`：アイコンなし。

### 4.7 配色（ApplyThemeColors）

- `Theme = ctAuto` の起動時の判定は、レジストリ `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` の `AppsUseLightTheme`（0 ならダーク）。
- 実行中の切り替えは、`editor.html` が OS のテーマの変化を検知して `oschange` で知らせ、部品がタブ・境目・背景を塗り直す（エディタごと）。
- 色の値は取説 9.4 の表（Windows 11 のエクスプローラーに近い値）。

### 4.8 右クリックメニュー

- Monaco 標準のメニューは止め、`editor.html` が `contextmenu` を送る。view は `QueueAsyncCall(AsyncContextMenu)` で、マウスの位置に `PopupMenu`（`TCMMenuItem` の項目）を出す。
- 出す直前に、選んでいるか・`ReadOnly`・`Minimap`・`ShowPreview` で項目の表示・使える・チェックを決め、`OnPopup` を呼ぶ。
- 項目（`TCMMenuCmd`）：`mcCut`・`mcCopy`・`mcPaste`・`mcQuoteCopy`・`mcAppendCut`・`mcAppendCopy`・`mcDelete`・大文字・小文字・半角・ひらがな・カタカナ・タブ⇔空白・インデント・逆インデント・`mcSelectAll`・`mcUndo`・`mcRedo`・ミニマップ・プレビュー。
- 引用付きコピー：選択の各行の先頭に `QuotePrefix` を付けてクリップボードへ（最後の改行は保つ）。追加コピー・追加切り抜き：クリップボードの今の中身の後ろに足す（切り抜きは `delsel`）。
- 変換：`ReplaceSelection`（`replacesel`。置き換えた範囲を選んだまま、Undo 1 回）。タブ⇔空白・インデントは `xform`。
- アプリが足した項目は、`Monaco.PopupMenu.Items` の後ろに並ぶ。

### 4.9 ファイルのドロップ

- `editor.html` が `dropfiles` を送る。view は `QueueAsyncCall(AsyncDropFiles)` で、`OnFileDrop`（`Handled` なら終わり）→ `OpenDroppedFiles` なら開く（4.5）。フォルダーは無視する。

### 4.10 カーソル行の単語（CMSplitLine）

- `cursorline` は、カーソルの知らせ（`cursor`）の直前に送られる。送るのは「行が変わった」「本文が変わった」「見えるタブが変わった」ときだけ（同じ行の中で動いただけなら送らない。本文が変わったときは、カーソルが動かなくても送る）。
- `ed.FLineWords: TStringList` を 1 つだけ持つ。分けたときの `FCursorLineSeq` と設定（区切り文字・空の単語・引用符）を覚え、`LineWords` を読んだとき、どれも同じなら分け直さない。
- `CMSplitLine(S, Delims, SkipEmpty, Quote, Dest)`：`Dest.Clear`。UTF-8 の 1 文字ずつ見る。分け方は取説 13.3。`Quote` が `#0`・半角でない・`Delims` に含まれるときは、引用符を解釈しない。

### 4.11 タブを外へ出す（TabTearOff・OnTabDragOut）

タブをアプリのウィンドウの外（デスクトップなど）へドラッグして離すと、そのタブを、同じ EXE をもう 1 つ起動して開く（秀丸のタブの分離と同じ）。同じ EXE の別のウィンドウのエディタの上へ落としたときは、そのエディタに新しいタブを作って開く（結合。4.11.6）。

| 設定 | 動き |
|---|---|
| `TabTearOff = True`（既定） | 部品が分離・結合をすべて行う（送る・新しい EXE を起動する・元のタブを閉じる・受ける）。アプリのコードは 0 行 |
| `TabTearOff = False` | 分離も結合もしない（ほかのウィンドウから落とされても受けない）。`OnTabDragOut` は来るので、アプリが自前で分離を作れる（4.11.5 のサンプル） |

```pascal
TCMTabDragOutEvent = procedure(Sender: TObject; Index: Integer; X, Y: Integer;
  var TearOff: Boolean) of object;
```

| 引数 | 中身 |
|---|---|
| `Sender` | そのエディタ（TCMonacoEditor） |
| `Index` | 外へ出したタブの番号（0 から） |
| `X`・`Y` | マウスを離した画面の位置（スクリーン座標） |
| `TearOff` | 部品が分離・結合するか。来たときの値は `TabTearOff`（ただし、何も入っていない無題が 1 枚だけなら `False`）。`False` にすると部品は分離も結合もしない |

#### 4.11.1 検知（`TCMTabBinder`）

ATTabs は、タブのドラッグを LCL のドラッグ（`BeginDrag`）で行う。落とした先に受け取る LCL の部品が無いとき、`OnEndDrag` が `Target = nil` で呼ばれる。

1. `Attach` で `FTabs.OnEndDrag := TabsEndDrag` をつなぐ。
2. `TabsEndDrag(Sender, Target, X, Y)`：次をすべて満たすときだけ、外へ出したとみなす。
   - `Target = nil`
   - `MultiDocument = True`（タブが出ている）
   - 左ボタンが離されている（`GetAsyncKeyState(VK_LBUTTON) >= 0`。`Esc` でドラッグを取り消したときは、まだ押されているので除く）
   - マウスの位置（`Mouse.CursorPos`）が、自分のアプリのウィンドウの上ではない（下の `IsOutsideApp`）
3. 満たせば、外へ出したタブの文書の `Id`（`ActiveIndex` の文書。ATTabs はドラッグを始めたタブを選んでいる）と位置を覚え、`QueueAsyncCall(AsyncTabDragOut)` で、ドラッグの処理が終わってから知らせる。
4. `AsyncTabDragOut`：覚えた `Id` から今の番号を引き（閉じていれば何もしない）、binder の `OnDragOut(Index, X, Y)` を呼ぶ。エディタの `BinderTabDragOut` が受ける（4.11.2）。

- `IsOutsideApp(P)`：`WindowFromPoint(P)` が 0 なら `True`。そうでなければ、`GetAncestor(…, GA_ROOT)` の一番外のウィンドウを `GetWindowThreadProcessId` で調べ、自分のプロセス（`GetCurrentProcessId`）でなければ `True`。WebView2 の中のウィンドウは自分のフォームの子なので、一番外は自分のフォームになり、`False`（エディタやプレビューの上に落としたときは知らせない）。自分のアプリの別のフォームの上も `False`。
- 知らせを `QueueAsyncCall` にする理由：ATTabs のドラッグの処理の途中でタブを閉じると、ATTabs が消えたタブを触って落ちるおそれがあるため。
- ドラッグ中のマウスカーソルは、自分のアプリの外では「落とせない」形になる（ほかのアプリのウィンドウは LCL のドラッグを受け取らないため）。落とせば分離する。

#### 4.11.2 送る（`TCMonacoEditor.BinderTabDragOut`）

1. `TearOff` の初めの値を決める：`TabTearOff`。ただし、`PageCount = 1` で、そのタブが無題・本文が空なら `False`。
2. `OnTabDragOut(Self, Index, X, Y, TearOff)` を呼ぶ（設定されていれば）。
3. `TearOff = False` なら終わり。
4. 落とした先が同じ EXE の別のウィンドウで、受け口があれば、結合する（4.11.6）。ここで終わり。
5. 一時ファイル（4.11.4 の形）を `GetTempFileName(GetTempDir, 'cmt')` に書く。本文は写し（`TCMDocument.Text`）。
6. 自分の EXE（`Application.ExeName`）を `CreateProcessW` で起動する（終わるのは待たない）。起動パラメータは付けない。環境は、今の環境変数すべて（`GetEnvironmentStringsW`。`CM_TEAROFF=` で始まるものは除く）に `CM_TEAROFF=一時ファイル` を足したものを `CREATE_UNICODE_ENVIRONMENT` で渡す（`TProcess` を使わないのは、一時ファイルの場所に日本語（ユーザー名など）が入っても、確実に UTF-16 で渡すため）。
7. 起動に失敗したら、一時ファイルを消し、`DoError('別のウィンドウで開けませんでした: ' + 理由)`。タブは閉じない。
8. 起動できたら、`PageClose(Index, True)`（聞かずに閉じる。本文は一時ファイルに残っている）。

- 環境変数は、起動したその新しい EXE にだけ渡る（`CreateProcess` に渡す環境の写し）。レジストリにも書かず、ブロードキャストもしない。送る側の EXE・ほかのアプリには影響しない。
- 写しは入力の直後（約 0.1 秒）は古いことがある（4.2）。人がドラッグを始めるまでに追いつくので、問題にしない。

#### 4.11.3 受ける（`TCMonacoEditor`）

**分離で起動されたかの判定**（`uCmonacos` の implementation の関数 `TearOffFile`）

- 最初に呼ばれたとき 1 回だけ、環境変数 `CM_TEAROFF` を読み、`GTearOffFile` に覚え、すぐに環境変数を消す（`SetEnvironmentVariable('CM_TEAROFF', nil)`。その EXE がさらに別の EXE を起動しても引き継がないように）。
- 値があり、ファイルがあれば、分離で起動された。無ければ普通の起動。
- `GTearOffClaimed: Boolean`：どれかのエディタが受け取ったら `True`（1 回だけ受ける）。

**受け取るエディタ**

- `TabTearOff = True` で、設計時でなく、`GTearOffClaimed = False` で、一時ファイルの `Editor` の値が自分の名前（`Owner.Name + '.' + Name`。例：`Form1.CMonacoEditor1`）と同じエディタ。
- 判定する時：`.lfm` から作ったエディタは `Loaded`。コードで作ったエディタは、`Ready` になったとき（そのときの `Name`・`TabTearOff` で判定する）。
- 受け取ったら `GTearOffClaimed := True`、`FTearOffPending := True`。一時ファイルの中身を `FTearOffHead`（`TStringList`）・`FTearOffBody` に読んでおく。

**ウィンドウの位置**

- 受け取ったエディタのフォーム（`GetParentForm`）を、`Position := poDesigned`、`Left := X`、`Top := Y` にする。そのモニターの作業領域（`Screen.MonitorFromPoint(Point(X, Y)).WorkareaRect`）からはみ出すなら、中に収まるように寄せる。
- `.lfm` から作ったエディタは `Loaded` で行うので、フォームは最初からその位置に出る。コードで作ったエディタは `Ready` で行うので、表示の後に動く。

**タブを作る**（`ready` の知らせで、利用者の `OnReady` を呼ぶ前）

`FTearOffPending` なら：

| 一時ファイルの中身 | 処理 |
|---|---|
| `FileName` があり、そのファイルがある | 0 番（起動直後の無題）に `PageLoad(0, FileName)`。`Modified = 1` なら、続けて `Text := 本文`（` *` が付く） |
| `FileName` が空、またはファイルが無い | 0 番に `Text := 本文`（無題のまま。本文があれば ` *` が付く） |

- そのあと `Encoding`・`Language` を一時ファイルの値にする。
- 一時ファイルを消し、`FTearOffPending := False`。
- 一時ファイルが読めない・形が違うとき（1 行目が `CMTEAROFF1` でない）は、受け取らない（普通の起動。一時ファイルは消さない）。
- どのエディタも受け取らなかったとき（名前が合わない）、一時ファイルは `%TEMP%` に残る。

#### 4.11.4 一時ファイルの形

UTF-8。部品の分離と、この節の最後のサンプルで同じ形。

```
CMTEAROFF1
Editor=Form1.CMonacoEditor1
FileName=C:\docs\a.md
Encoding=0
Language=markdown
Modified=1
X=800
Y=300

（ここから最後までが本文）
```

- 1 行目は目印。空の行までが見出し、その後ろの全部が本文（本文に何が入っていても壊れない）。
- `Editor` は、受け取るエディタの名前（`Owner.Name + '.' + Name`）。`FileName` は、無題なら空。`Encoding` は `TCMEncoding` の番号（`Ord`）。
- 引き継ぐもの：本文・ファイル名・文字コード・言語・` *`。引き継がないもの：Undo の履歴・カーソル位置・スクロール位置。
- 元のエディタは、閉じたタブが最後の 1 枚なら、空の無題が残る（タブは常に 1 枚以上）。
- 新しい EXE のウィンドウは、WebView2 と Monaco の起動を待つため、1〜2 秒遅れて中身が出る。

#### 4.11.5 自前で分離を作るとき（サンプル）

部品の分離（`TabTearOff = True`）を使わずに、アプリが自分で作るときの参考例。`TabTearOff = False` にし、`OnTabDragOut` の中で行う。受け渡しは、この例では起動パラメータ（`/tearoff 一時ファイル`）にしている。

送る側（元の EXE）：

```pascal
uses
  Process, uCmonacos;

const
  TearOffMark = 'CMTEAROFF1';

// タブを外へ出したら、そのタブを別の EXE で開き、このタブを閉じる
procedure TForm1.CMonacoEditor1TabDragOut(Sender: TObject; Index, X, Y: Integer;
  var TearOff: Boolean);
var
  E: TCMonacoEditor;
  P: TCMPage;
  FN, S: string;
  FS: TFileStream;
  Proc: TProcess;
begin
  TearOff := False;   // 部品の分離は使わない（TabTearOff = False なら、もともと False）
  E := Sender as TCMonacoEditor;
  P := E.Pages[Index];

  // 何も入っていない無題が 1 枚だけのときは、出しても意味がないので何もしない
  if (E.PageCount = 1) and (P.FileName = '') and (P.Text = '') then Exit;

  // 1. タブの中身を一時ファイルに書く（見出し・空の行・本文）
  FN := GetTempFileName(GetTempDir, 'cmt');
  S := TearOffMark + LineEnding +
       'Editor=' + Name + '.' + E.Name + LineEnding +
       'FileName=' + P.FileName + LineEnding +
       'Encoding=' + IntToStr(Ord(P.Encoding)) + LineEnding +
       'Language=' + P.Language + LineEnding +
       'Modified=' + IntToStr(Ord(P.Modified)) + LineEnding +
       'X=' + IntToStr(X) + LineEnding +
       'Y=' + IntToStr(Y) + LineEnding +
       LineEnding +
       P.Text;
  FS := TFileStream.Create(FN, fmCreate);
  try
    if S <> '' then FS.WriteBuffer(S[1], Length(S));
  finally
    FS.Free;
  end;

  // 2. 自分の EXE を、一時ファイルを引数にして起動する（終わるのは待たない）
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := Application.ExeName;
    Proc.Parameters.Add('/tearoff');
    Proc.Parameters.Add(FN);
    try
      Proc.Execute;
    except
      on Ex: Exception do
      begin
        DeleteFile(FN);   // 起動できなければ、タブは閉じずに残す
        MessageDlg('別のウィンドウで開けませんでした: ' + Ex.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
  finally
    Proc.Free;
  end;

  // 3. 起動できたら、このタブを聞かずに閉じる（本文は一時ファイルに残っている）
  P.Close(True);
end;
```

受ける側（新しい EXE。同じ EXE なので、同じフォームに書く）：

```pascal
// FTearFile: string;  … フォームの private に置く。受け取った一時ファイル

// 一時ファイルを、見出し（Head）と本文（Body）に分けて読む
function ReadTearOff(const AFile: string; Head: TStrings; out Body: string): Boolean;
var
  FS: TFileStream;
  S: string;
  p: Integer;
begin
  Result := False;
  Body := '';
  FS := TFileStream.Create(AFile, fmOpenRead or fmShareDenyNone);
  try
    SetLength(S, FS.Size);
    if S <> '' then FS.ReadBuffer(S[1], Length(S));
  finally
    FS.Free;
  end;
  p := Pos(LineEnding + LineEnding, S);          // 最初の空の行
  if p = 0 then Exit;
  Head.Text := Copy(S, 1, p - 1);
  Body := Copy(S, p + 2 * Length(LineEnding), MaxInt);
  Result := (Head.Count > 0) and (Head[0] = TearOffMark);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  Head: TStringList;
  Body: string;
begin
  FTearFile := '';
  if (ParamCount >= 2) and (ParamStr(1) = '/tearoff') and FileExists(ParamStr(2)) then
  begin
    FTearFile := ParamStr(2);
    // ウィンドウを、タブを落とした位置に出す
    Head := TStringList.Create;
    try
      if ReadTearOff(FTearFile, Head, Body) then
      begin
        Position := poDesigned;
        Left := StrToIntDef(Head.Values['X'], Left);
        Top  := StrToIntDef(Head.Values['Y'], Top);
      end;
    finally
      Head.Free;
    end;
  end;
end;

// エディタの準備ができたら、一時ファイルからタブを作る
procedure TForm1.CMonacoEditor1Ready(Sender: TObject);
var
  E: TCMonacoEditor;
  Head: TStringList;
  Body, FN: string;
begin
  if FTearFile = '' then Exit;
  E := Sender as TCMonacoEditor;
  Head := TStringList.Create;
  try
    if ReadTearOff(FTearFile, Head, Body) then
    begin
      FN := Head.Values['FileName'];
      if (FN <> '') and FileExists(FN) then
      begin
        // ファイルがある：起動直後の無題のタブに読み込む（タブは増えない）
        E.LoadFromFile(FN);
        if Head.Values['Modified'] = '1' then
          E.Text := Body;                          // 保存していない本文に置き換える（* が付く）
      end
      else
        // 無題、またはファイルが消えている：無題のまま本文を入れる（* が付く）
        E.Text := Body;
      E.Encoding := TCMEncoding(StrToIntDef(Head.Values['Encoding'], 0));
      E.Language := Head.Values['Language'];
    end;
  finally
    Head.Free;
  end;
  DeleteFile(FTearFile);   // 読み終わってから消す（読む前に失敗しても本文は残る）
  FTearFile := '';
  E.SetFocus;
end;
```

- 一時ファイルは、新しい EXE が読み終わってから消す。新しい EXE が読む前に失敗したときは、`%TEMP%` に `cmt*.tmp` として残る。

#### 4.11.6 結合（同じ EXE の別のウィンドウへ落とす）

タブを、同じ EXE のもう 1 つのウィンドウ（別に起動したもの）のエディタの上へ落とすと、そのエディタに新しいタブを作って開く。分離と同じく `TabTearOff = True` で `TearOff = True` のときに行う。

**落とした先ごとの動き**

| 落とした先 | 動き |
|---|---|
| 同じ EXE の別のウィンドウの、エディタの上（タブの帯・本文・プレビュー） | 結合する（そのエディタに新しいタブ）。元のタブは閉じる |
| 同じ EXE の別のウィンドウの、エディタではない所（メニュー・ボタンなど） | 何も起きない |
| 相手のエディタが `TabTearOff = False` または `MultiDocument = False` | 何も起きない |
| 相手のエディタが、同じファイルをすでに開いている | 結合しない。相手のそのタブに切り替え、相手のウィンドウを前に出す。元のタブは残す |
| 同じ EXE ではないウィンドウ・デスクトップ | 分離（4.11.2） |
| 同じ EXE だが、受け口（下の `CMTearOffReceiver`）が無い（古い版で作った EXE など） | 分離（4.11.2） |

**同じ EXE かを調べる**（`SendTearOff` の最初）

1. 落とした位置のウィンドウの一番外（`WindowFromPoint`・`GetAncestor(GA_ROOT)`）のプロセス ID を `GetWindowThreadProcessId` で取る。
2. そのプロセスの EXE のフルパスを、`OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)`・`QueryFullProcessImageNameW` で取る。自分の EXE のフルパス（同じ API を `GetCurrentProcess` で）と、大文字小文字を区別せずに比べる。
3. 同じなら、そのプロセスの受け口のウィンドウを探す：`FindWindowExW(HWND_MESSAGE, 前, 'CMTearOffReceiver', nil)` で順に取り、プロセス ID が同じものを選ぶ。
4. 受け口があれば結合（次）。同じ EXE でない、または受け口が無ければ分離（4.11.2 の 4 から）。

**送る（結合）**

1. 一時ファイルを書く（4.11.4 の形。`Editor` は使わないが書いておく）。
2. 受け口へ `WM_COPYDATA` を `SendMessageTimeoutW`（`SMTO_ABORTIFHUNG`、3 秒）で送る。`dwData` は `$434D544F`（'CMTO'）、中身は UTF-16 の文字列「一時ファイルのフルパス + #10 + X + #10 + Y」（X・Y は落とした画面の位置）。
3. 返事で決める。

| 返事 | 意味 | 送る側の処理 |
|---|---|---|
| 1 | 受け取った（相手が新しいタブを作る） | `PageClose(Index, True)`。一時ファイルは相手が消す |
| 2 | 相手は同じファイルを開いている（そのタブに切り替えた） | 一時ファイルを消す。元のタブは残す |
| 0 | 受け取らない（エディタの上ではない・`TabTearOff = False`・`MultiDocument = False`） | 一時ファイルを消す。何もしない |
| 送れない・3 秒で返事が無い | 相手が固まっている、または送れない（管理者として動いている EXE へは送れない） | 一時ファイルを消し、`DoError('ほかのウィンドウへ移せませんでした')`。元のタブは残す |

**受け口（`CMTearOffReceiver`。`uCmonacos` の implementation）**

- プロセスに 1 つだけの、見えないメッセージ専用のウィンドウ（`CreateWindowExW` の親を `HWND_MESSAGE`）。ウィンドウクラス名は `CMTearOffReceiver`（`RegisterClassW`。ウィンドウ手続きは普通の関数 `ReceiverWndProc`）。
- 実行時のエディタが初めて `CreateWnd` を通ったときに作る（設計時は作らない）。プロセスの終わり（`finalization`）で壊す。
- `GEditors: TFPList`：実行時のエディタの一覧。`CreateWnd` で加え、`Destroy` で外す。

`ReceiverWndProc` の `WM_COPYDATA`（`dwData = $434D544F` のときだけ。ほかは `DefWindowProcW`）：

1. 文字列を「一時ファイル・X・Y」に分ける。一時ファイルを読む（`ReadTearOffFile`）。読めなければ 0。
2. 受けるエディタを決める：`GEditors` のうち、`Showing` で、`(X, Y)` がそのエディタの画面上の範囲の中にあり、`WindowFromPoint(X, Y)` の一番外がそのエディタのフォームと同じ（ほかのウィンドウに隠れていない）もの。無ければ 0。
3. そのエディタが `TabTearOff = False` または `MultiDocument = False` なら 0。
4. 見出しの `FileName` が空でなく、そのエディタで開いている（`FindPage >= 0`）なら、`ActiveIndex` をそのタブにし、フォームを前に出して（`QueueAsyncCall`）、2。
5. それ以外は、一時ファイルの場所をエディタの `FMergeQueue`（`TStringList`）に足し、`QueueAsyncCall(AsyncMerge)` して 1。
- この中ではダイアログを出さない・待たない（送る側が返事を待っているため。タブを作るのは返事のあと）。

`AsyncMerge`（受けたエディタ。`FMergeQueue` の一時ファイルを順に）：

| 一時ファイルの中身 | 処理 |
|---|---|
| `FileName` があり、そのファイルがある | `OpenFile(FileName)`（新しいタブで開く）。`Modified = 1` なら、そのタブの `Text := 本文`（` *` が付く）。開けなければ、下の無題と同じ |
| `FileName` が空、またはファイルが無い | `NewPage` のタブに `Text := 本文`（無題のまま） |

- そのあと `Encoding`・`Language` を一時ファイルの値にし、一時ファイルを消す。新しいタブは見えるタブになる。フォームを前に出す（`Application.BringToFront`・`SetForegroundWindow`）。
- 開いている間に同じファイルを別のことで開いていた（返事のあとで開いた）ときは、`OpenFile` がそのタブに切り替えるだけになる。そのときも、`Modified = 1` なら本文を置き換える。

## 5. 中の仕組み

### 5.1 クラスと役割

| クラス | ユニット | 役割 |
|---|---|---|
| `TCMonacoEditor` | `uCmonacos` | 中の部品を作ってつなぎ、利用者向けの API とイベントを出す。イベントの `Sender` を自分に差し替えて中継する。テーマ・色は列挙型・TColor で受け、中の部品へは文字列で渡す |
| `TCMPage` | `uCmonacos` | タブ 1 枚（3.3） |
| `TCMFormHook` | `uCmonacos` | フォームごとの世話役（3.4） |
| `TCMMonacoView` | `uCmmonacoview` | `TWVBrowser` で `editor.html` を表示し、メッセージをやり取りする。文書の一覧・写し・選択とカーソルの写し・右クリックメニュー |
| `TCMDocument` | `uCmmonacoview` | 文書 1 つの状態 |
| `TCMTabBinder` | `CMonacoTabs` | view と ATTabs をつなぐ（4.6） |
| `TCMPreviewBinder` | `CMonacoPreview` | view とプレビューをつなぐ。編集・切り替えのたびに写しの本文をプレビューへ渡す（編集は `PreviewDelayMs` 待つ。切り替えはすぐ）。スクロールを合わせる（7.4） |
| `TCMMarkdownPreview` | `uCmdpreview` | `TWVBrowser` で `preview.html` を表示する。Markdown・コード・Mermaid・印刷 |
| `TCMFindDialog` | `CMonacoFindDlg` | 検索・置換ダイアログ（9章） |
| `TCMEditorAction` ほか | `CMonacoActions` | 標準アクション（8章） |

### 5.2 イベントのつながる順番

view のイベントは、次の順に連結する（後から付けたものが先に呼ばれ、前のものを呼ぶ）。

```
view.OnDocListChange など
  → TCMPreviewBinder（プレビューを更新）
    → TCMTabBinder（タブを更新）
      → TCMonacoEditor.MonacoXxx（利用者のイベントへ中継）
```

- `TCMonacoEditor.Create` で、先に自分を view のイベントにつなぎ、そのあと `TCMTabBinder.Attach`、`TCMPreviewBinder.Attach` の順に連結する。

### 5.3 Pascal と JavaScript のメッセージ

- Pascal → JS：`FBrowser.PostWebMessageAsString`。区切りは `#1`（`SEP`）。先頭が命令の名前。返事はない。
- JS → Pascal：`chrome.webview.postMessage`。view の `BrowserWebMessageReceived` → `HandleMessage` で受ける。先頭が知らせの名前。
- 本文のような自由な文字列は、最後の引数に置く（`SEP` を含んでも壊れないように、残り全部を本文とする）。

**エディタ（Pascal → `editor.html`）**

| 命令 | 引数 | 処理 |
|---|---|---|
| `doc.new` | Id、言語、本文 | 文書（モデル）を作る |
| `doc.activate` | Id | その文書を表示する（前の文書の表示位置を覚え、次の文書の表示位置を戻す） |
| `doc.close` | Id | 文書を消す |
| `doc.reset` | Id、本文 | 中身を差し替える（Undo の履歴も消える） |
| `doc.lang` | Id、言語 | 色分けの言語を変える |
| `doc.dirty` | Id | 変更ありにする（Undo で戻しても、保存するまで変更ありのまま） |
| `doc.settextifdiff` | Id、本文 | 今の本文と違うときだけ置き換え、変更ありにして `textsync` を返す。同じなら何もしない |
| `marksaved` | Id | 今の状態を「保存した状態」にする |
| `opt` | 名前、値 | 設定（`wordwrap`・`linenumbers`・`fontsize`・`theme`・`readonly`・`tabsize`・`folding`・`matchbrackets`・`occurrences`・`minimap`・`colors`（検索ヒット 明・暗、カーソル行 明・暗、選択範囲 明・暗 の 6 色）） |
| `undo`・`redo`・`selectall` | ― | 編集 |
| `delsel` | ― | 選択を消す |
| `paste` | 本文 | 貼り付け |
| `replacesel` | 本文 | 選択を置き換え、置き換えた範囲を選ぶ（右クリックの変換用） |
| `seltext` | 本文 | 選択を置き換える（`SelText :=`）。後ろにカーソル |
| `delto` | `end`・`start` | カーソルから末尾・先頭まで消す |
| `dupline` | ― | カーソル行（選んだ行）を複製（`Shift+F10` と同じ処理） |
| `xform` | 種類 | タブ⇔空白・インデント |
| `scrollto` | 行 | 表示位置を移す（スクロールを合わせる） |
| `focus` | ― | フォーカスを置く |
| `toggleow` | ― | 挿入と上書き |
| `setcursor` | 行、桁 | カーソルを動かす |
| `setsel` | 行、桁、行、桁 | 選ぶ |
| `find` | 語、大小、単語、折り返し、前へ | 検索 → `finddone` |
| `replace` | 語、置換、大小、単語、折り返し | 置き換えて次を検索 → `finddone` |
| `replaceall` | 語、置換、大小、単語 | すべて置換 → `replacealldone` |

**エディタ（`editor.html` → Pascal）**

| 知らせ | 引数 | Pascal の処理 |
|---|---|---|
| `ready` | ― | 準備ができた。設定と文書を送り、`OnReady` |
| `change` | Id、本文 | 写しを更新。見えている文書なら `OnChange` |
| `modified` | Id、0/1 | ` *` を更新。`OnDocumentChange`、見えている文書なら `OnModifiedChange` |
| `cursorline` | カーソル行の文字列 | `FCursorLineText` を更新し、`FCursorLineSeq` を 1 増やす（イベントは呼ばない） |
| `cursor` | 行、桁、開始位置、長さ、選択の文字列 | 選択・カーソルの写しを更新。`OnCursorChange` |
| `textsync` | Id、本文 | `doc.settextifdiff` で置き換えた。写しを更新し、` *` を付ける |
| `canundo` | Undo 0/1、Redo 0/1 | `CanUndo`・`CanRedo` の写し |
| `mode` | 0/1 | 挿入・上書き。`OnModeChange` |
| `save` | Id、本文 | 写しを更新して保存（`Ctrl+S`） |
| `findreq` | 文字列 | 検索ダイアログを開く（`Ctrl+F`） |
| `findnext`・`findprev` | ― | `F5`・`Shift+F5` |
| `finddone` | 0/1 | `OnFindDone` |
| `replacealldone` | 件数 | `OnReplaceAllDone` |
| `togglemax` | ― | `F12`。`OnToggleMaximize` |
| `gotfocus` | ― | 最後にフォーカスされたエディタとして記録（`TCMFormHook.SetActive`） |
| `togglepreview` | ― | `Ctrl+Shift+V` |
| `oschange` | 0/1 | OS のテーマが変わった |
| `linenumbers`・`fontsize` | 値 | `F11`・`Ctrl+ホイール` |
| `topline` | 行 | 表示している先頭の行（スクロールを合わせる） |
| `contextmenu` | ― | 右クリックメニューを出す |
| `dropfiles` | ファイル | ファイルのドロップ |
| `error` | 文字列 | `OnError` |

**プレビュー（Pascal → `preview.html`）**：`render`（フォルダー、本文）、`code`（言語、本文）、`clear`、`title`（PDF の名前）、`line`（行）、`opt`（`theme`・`fontsize`・`layout`・`breaks`・`remote`・`colors`）、`copy`、`selectall`、`prepareprint`、`printdone`

**プレビュー（`preview.html` → Pascal）**：`ready`、`openurl`、`openmd`、`contextmenu`、`copytext`、`scrollline`、`fontsize`、`printready`、`afterprint`、`error`

### 5.4 WebView2 の決まり（必ず守る）

- WebView2 の知らせ（`WebMessageReceived`・`AcceleratorKeyPressed` など）の途中で、ダイアログやメニューを出したり、メッセージループを回して待ったりしない（WebView2 は知らせの途中の入れ子を受け付けず、知らせが戻らなくなる）。
- そのため、知らせの中でダイアログ・メニュー・印刷ダイアログ・フォームのショートカットの実行が要るときは、`Application.QueueAsyncCall` で、知らせが終わってから行う（`AsyncContextMenu`・`AsyncDropFiles`・`AsyncRunShortcut`・`AsyncPrint`・`AsyncShowPrintUI`・`AsyncOpenMarkdown`・`AsyncShowError`・`AsyncSetFocus`）。ATTabs のドラッグの終わり（`OnEndDrag`）も同じ理由で、`AsyncTabDragOut` で後から知らせる（4.11）。タブの結合の `WM_COPYDATA` も、送る側が返事を待っているので、受け口ではタブを作らず `AsyncMerge` で後から作る（4.11.6）。
- 見えない間は WebView2 を作らない（`Showing` になってから作る）。見えない間は、初期化のタイマー（100 ミリ秒）が待つ。

### 5.5 フォーカス

- フォーカスは、エディタの外枠に移してから、WebView2 の `MoveFocus` で中へ移してもらう（WebView2 の中のウィンドウは Edge の別のプロセスのものなので、Windows の `SetFocus` で直接移さない）。
- 知らせの途中やボタンのクリックの途中でフォーカスを WebView2 に移すと、IME の状態が乱れて入力できなくなる（変換の窓が画面の外に出る）。そのため `ed.SetFocus` は `QueueAsyncCall(AsyncSetFocus)` で、今の処理が終わってから行う。見えない・使えないエディタでは何もしない。
- フォーカスは WebView2 の中にあるため `Form.ActiveControl` では追えない。Monaco がフォーカスを受けたら `gotfocus` で知らせ、`TCMFormHook` が記録する。

### 5.6 キーの処理（MonacoAccelKeyDown）

WebView2 の `AcceleratorKeyPressed`（WebView4Delphi の `OnAcceleratorKeyPressed`）で受ける。キーが Monaco に届く前に来る。Ctrl・Alt との組み合わせ、F1〜F12、Esc などのショートカット用のキーが来る（普通の文字の入力は来ない）。

1. `KeyDown`（virtual。継承した部品が override できる。その中の `inherited` で `OnKeyDown`）。`Key := 0` なら、Monaco に渡さずに終わる。
2. `Ctrl+P`：印刷（`AsyncPrint`）。フォームのショートカットより先。
3. `Ctrl+Shift+M`：ミニマップの切り替え。
4. `Ctrl+Tab`・`Ctrl+Shift+Tab`：タブの切り替え（`MultiDocument = False` なら何もしない）。
5. 内蔵のショートカット（`IsBuiltinKey`：取説 8.1 のキーと `Ctrl+Z`・`Ctrl+Y`・`Ctrl+Shift+Z`・`Ctrl+X`・`Ctrl+C`・`Ctrl+V`）なら、そのまま Monaco へ。
6. フォームのメニュー・ActionList に同じショートカットがあれば、`AsyncRunShortcut` で後で実行し、Monaco には渡さない。
7. `Ctrl+Shift+P`：止める（WebView2 の「システムのダイアログで印刷」。止めないとエディタの画面がそのまま印刷される）。
8. どれでもなければ Monaco へ。

- WebView2 の既定の動き（再読み込み、開発者ツール、印刷など）は止める。

## 6. 実行時のファイルの場所と WebView2 の準備

### 6.1 monaco・preview の場所

view・preview の `GetResourceDir`：

| ユニット | 処理 |
|---|---|
| `uCmmonacoview` | `Result := CXResolveRuntimeDir(FResourcePath, 'MonacoFolder', 'monaco')` |
| `uCmdpreview` | `Result := CXResolveRuntimeDir(FResourcePath, 'PreviewFolder', 'preview')` |

- `CXResolveRuntimeDir`：プロパティ（`MonacoPath`・`PreviewPath`）→ WebView2.ini のキー → EXE のフォルダー + 既定の名前、の順（`TCTabBrowser_Design.md` 9章）。
- `GetResourceDir` は実行時（`BrowserAfterCreated`）にだけ呼ぶ。IDE が ini を読むことはない。
- `editor.html`・`preview.html` が無ければ `DoError('editor.html が見つかりません: ' + 場所)`（preview も同じ形）。

### 6.2 WebView2 の準備（InitTimerTick）

view と preview の `InitTimerTick`（100 ミリ秒）は、同じ形で次を行う。

1. 設計時・見えない間は待つ（preview は非表示ならタイマーを止め、表示されたら `VisibleChanged` で再開する）。
2. `GlobalWebView2Loader` が無ければ `CXStartWebView2(Err)`。`False` ならタイマーを止めて `DoError(Err)`（WebView2.ini が無い・WebView2 を起動できない）。
3. `GlobalWebView2Loader.InitializationError` なら、タイマーを止めて `DoError(ErrorMessage)`。
4. `GlobalWebView2Loader.Initialized`（既定の環境ができた）なら、タイマーを止めてブラウザを作る（`CreateBrowser`。既定の環境＝WebView2.ini の `UserDataFolder` を使う）。
5. まだなら、次の tick で確かめ直す。

- `CXStartWebView2` は、アプリの中で最初の 1 回だけローダーを作る。2 回目からは、できているローダーの状態を返す（TCTabBrowser・ほかのエディタと共有）。中身は `TCTabBrowser_Design.md` 9章。
- 設計時は WebView2 を起動しない（`CreateWnd`・`InitTimerTick` で `csDesigning` を見る）。

## 7. プレビュー

### 7.1 表示

- プレビューの WebView2 は、初めて表示したときに作る。
- 表示する本文は、view の写しを `TCMPreviewBinder` が渡す。言語が markdown なら `render`（フォルダー、本文）、それ以外は `code`（言語、本文）。
- Markdown：marked（GFM）→ DOMPurify → highlight.js。各ブロックに元の行番号を付ける（見出し・段落・リストの項目・引用・表の行・コードブロックの中身の行）。先頭の YAML は外す。
- コード：highlight.js で色分け。言語の読み替え（例：pascal → delphi、bat → dos）。対応しない言語・plaintext は色分けしない。50 万文字を超えたら色分けしない（行番号付きの表示はする）。行番号はコピーされないよう、本文と分けて描く。長い行は折り返す。
- 画像：開いているファイルのフォルダーから数える相対パスと、`C:\...` の絶対パスを表示する。各ドライブを仮想ホスト（`cmdrive-c.example` など）に割り当てる。`AllowRemoteImages = False` なら http の画像は取りに行かない。
- リンク：`http`・`https`・`mailto` は `openurl` → 既定のブラウザ（LCL の `OpenURL`。ほかで始まる URL は開かない）。プレビューの中の移動は止める。`.md` は `openmd` → `AsyncOpenMarkdown` → `OnOpenMarkdown`（無ければそのエディタで開く）。`#見出し` はプレビューの中でスクロール。ほかのファイルへのリンクは開かない。
- 文字：本文は `Segoe UI`、`Yu Gothic UI`、`Meiryo` の順。コードは `Consolas`、`BIZ UDゴシック`、`MS ゴシック` の順。
- 配色：`ColorScheme = csEditor` なら、`PreviewBackColor…`・`PreviewTextColor…`・`PreviewLinkColor…` を使い、表の罫線・コードブロックの背景は背景色と文字色から決める。コードの色分けは Monaco の `vs`・`vs-dark` に近い色にする。`csGitHub` なら github-markdown-css と highlight.js の github の配色。

### 7.2 Mermaid

- ` ```mermaid ` のブロックがある文書を表示したときだけ、`mermaid.min.js`（12.1.0）を読み込む。12 系なのは、`usecase-beta` などを描くため。
- `securityLevel: 'strict'` で描く。
- 色：線・枠はプレビューのリンク色の青（ダーク #3794ff、ライト #006ab1）、背景・文字はプレビューと同じ色。
- 大きさ：最初はプレビューの幅に合わせる。マウスを乗せると右上に 4 つのボタン（移動・縮小・拡大・枠に合わせる）。中身が変わっていない図は、描き直しても拡大・移動の状態を保つ。プレビューの幅が変わったら、拡大していない図は合わせ直す。
- 書き間違いは、その図の場所にエラーの内容を出す。
- 図の中の http・https の画像（`img: "..."`）：`AllowRemoteImages = False` なら画像の指定を外して描き、図の下に「[外部画像は表示しません]」。`True` なら取ってきて描き、取れなければ外して描き直して「[画像を取得できませんでした]」。うまく外せない書き方の図はエラー表示。

### 7.3 印刷

1. `Print`（`Ctrl+P`・標準アクション・プレビューの右クリックの「印刷...」）は `AsyncPrint`。
2. プレビューを出していなければ、印刷の間だけ出す（画面に出さない WebView2 では印刷が正しく動く保証がないため）。WebView2 がまだ無ければ、できるのを待つ。
3. `title`（PDF の名前：タブの名前から拡張子を外したもの。無題は「無題」）を送る（印刷ダイアログは、ページのタイトルを PDF の名前に使う）。
4. `prepareprint`：Mermaid の図を、白い背景用の色・紙の幅で、画面に出さない場所に別に描く。終わったら `printready`。
5. `printready` で `AsyncShowPrintUI`（WebView2 の印刷ダイアログ）。
6. `afterprint` で `printdone`（印刷用の図を消す）。印刷のために出したプレビューなら隠す。知らせが来なければ、出したまま。

- 印刷用の図は、CSS の `@media print` で画面用の図と入れ替える（画面は変わらないので、ダイアログを出す前の点滅がない）。描けなかった図は、画面用の図をそのまま印刷する。
- エディタ（Monaco）の画面は印刷しない（見えている行しか描かれないため）。
- `Ctrl+P`・`Ctrl+Shift+P` は、プレビューにフォーカスがあるときも同じ扱い（WebView2 の印刷を動かさない）。

`preview.html` の `<style>` の最後の印刷用の CSS：

```css
@media print {
  html, body, .markdown-body { background: #fff !important; color: #000 !important; }
  .markdown-body a { color: #0645ad !important; }
  .markdown-body pre, .markdown-body code, .hljs { background: #f6f8fa !important; color: #000 !important; }
  .hljs * { color: #000 !important; }
  .markdown-body th, .markdown-body td { border-color: #999 !important; }
  .markdown-body pre, .markdown-body table, .markdown-body img { break-inside: avoid; }
}
```

- コードのタブの印刷は、印刷用の濃い色で色分けする（上の `.hljs *` の黒一色は Markdown のコードブロック）。

### 7.4 スクロールを合わせる

- エディタは、表示している先頭の行を小数（行の中の位置）まで `topline` で知らせる。折り返しのときも行番号で合わせる。
- プレビューは、その行を含むブロックの位置に、ブロックの中の位置を比例配分してスクロールする。空の行の部分は、前後のブロックの間を補間する。
- 画像の読み込みなどで高さが変わったら、合わせ直す。
- `ssBoth` のときは、片方が動かした直後の約 0.3 秒は、反対側からの知らせを止める（互いに反応し合ってふらつかないように）。
- 折り返しの多い長い段落の中は、比例配分のため多少ずれる（直さない）。

## 8. 標準アクション（CMonacoActions）

```pascal
TCMEditorAction = class(TAction)
protected
  function TargetEditor: TCMonacoEditor;                       // 対象のエディタ
  function CanRun(AEditor: TCMonacoEditor): Boolean; virtual;  // 使えるか（既定：AEditor <> nil）
  procedure Run(AEditor: TCMonacoEditor); virtual; abstract;   // 動き
public
  constructor Create(AOwner: TComponent); override;            // DisableIfNoHandler := False
  function Execute: Boolean; override;
  function Update: Boolean; override;
end;

TCMEditorToggleAction = class(TCMEditorAction)
protected
  function GetValue(AEditor: TCMonacoEditor): Boolean; virtual; abstract;
  procedure SetValue(AEditor: TCMonacoEditor; AValue: Boolean); virtual; abstract;
  procedure Run(AEditor: TCMonacoEditor); override;            // SetValue(not GetValue)
public
  function Update: Boolean; override;
end;
```

| 手続き | 処理 |
|---|---|
| `Create` | `DisableIfNoHandler := False`（`OnExecute` が無くても標準の動きで使えるようにする）。各クラスの `Create` で `Caption`・`Hint`・`ShortCut` を入れる |
| `TargetEditor` | `ActionList` の `Owner` から、`TCustomForm` が出るまで `Owner` をたどり、`CMActiveEditor(フォーム)` |
| `Execute` | `inherited Execute` が `True`（`OnExecute` がある）なら終わり。でなければ `CanRun(TargetEditor)` のとき `Run` |
| `Update` | `inherited Update` が `True`（`OnUpdate` がある）なら終わり。でなければ `Enabled := CanRun(TargetEditor)` |
| `TCMEditorToggleAction.Update` | `inherited Update` の後、`OnUpdate` が無ければ `Checked := (対象がある) and GetValue(対象)`（キーで切り替えたときも一致する） |

- 各クラスの `CanRun`・`Run` は、取説 12章の「使えるとき」「動き」のとおり。
- `TCMEditorOpen`：`OpenDialog`（無ければ内蔵）で選ぶ。`MultiDocument = True` なら複数選べる。
- 作らないもの：終了（`TFileExit` を使う）、置換（検索・置換は同じダイアログ）、挿入・上書きの切り替え（今の状態を読むプロパティが `ed` にないため）。

## 9. 検索・置換ダイアログ（TCMFindDialog）

- `TCMFindDialog = class(TComponent)`。中に `TCMFindForm`（`TForm`。`CreateNew` でその場で作る）を持ち、初めて開くときに作る。
- 対象は view。エディタの `ShowFindDialog` が対象をそのエディタにして開く。共有ダイアログのときは、`OnActiveChange`・`gotfocus` で対象と見出し（「検索・置換 - ファイル名」）を付け替える。
- 検索語・置換語は履歴付きのコンボボックス。オプションは大文字小文字・単語単位・ループ。ボタンは次を検索・前を検索・置換・すべて置換・閉じる（`Enter` で次、`Esc` で閉じる）。
- 結果は view の `OnFindDone`・`OnReplaceAllDone` で受け、ダイアログの下に「見つかりません」「N 件置換しました」と出す。
- 位置・検索語・置換語・履歴（30 件まで）・オプションは、ダイアログ 1 つにつき 1 組（共有なら全エディタで共通）。
- 1 行の範囲を選んで `Ctrl+F` を押したときは、その文字列を最初の検索語にする（`findreq` の引数）。
- 検索でヒットした所は、エディタにフォーカスがない間、`HitColor…` の色で出す（`editor.html` が、フォーカスのないときの選択の色を変える）。

## 10. 決めていること

| 項目 | 決定 |
|---|---|
| 利用者のコード | 0 行で動く。設定はすべてオブジェクトインスペクタ。WebView2 の準備も部品が行う |
| 実行時のファイルの場所 | WebView2.ini は必ず EXE のフォルダーに置く。キーが空なら EXE のフォルダーの既定の場所。`monaco`・`preview` は `MonacoPath`・`PreviewPath` が先。相対パスは EXE のフォルダーから数える |
| 部品の形 | タブ・エディタ・プレビュー・検索・置換・印刷を内蔵する複合部品。1 つのフォームに何個でも貼れる |
| 入口 | 見えているタブは `ed`、裏のタブは `ed.Pages[n]`。`Pages[n]` にあるものは、すべて `ed` にもある |
| 同じことを 2 通りにしない | 同じ操作を、別の名前で 2 つ作らない |
| 画面の上での操作 | 選択・カーソル・編集・検索・印刷は `ed` だけ（`Pages[n]` には置かない） |
| タブの枚数 | 常に 1 枚以上 |
| 1 つのタブ＝1 つのファイル | 同じファイルを 2 つのタブで開かない |
| `OpenFile` | 必ず新しいタブで開く（起動直後の無題も使わない） |
| 本文の持ち方 | 正は Monaco。Pascal 側は読むための写し（入力直後の約 0.1 秒は古いことがある）。Monaco を 1 つにして、切り替えのたびに写しを流し込む作りにはしない（Undo の履歴が消えるため） |
| 写しをなくす作り | 行わない。`Text` などを読むたびに Monaco に聞いて待つ作りは、WebView2 の知らせ（`OnKeyDown` など）の途中では待てないため、`OnKeyDown` の中で本文を扱えなくなる。避ける仕組み・割り込みの扱い・プレビューの作り直しなど変更が大きい。今のずれ（約 0.1 秒）で困る場面はほぼない |
| `SelText` | 読み書き。'' で削除、選んでいなければ挿入。書いたあとは選択を外し、後ろにカーソル |
| `SelStart`・`SelLength` | 読むだけ。0 始まり、UTF-16 単位、改行は文書の改行コードの文字数 |
| `DeleteToEnd`・`DeleteToStart` | 選択を無視し、カーソル位置から消す |
| 選択範囲の色 | `SelectionColorStyle` で組を選ぶ（既定 `scStandard`）。`scCustom` なら `SelectionColorDark`・`SelectionColorLight` で自由に |
| テーマ・配色・色 | `Theme`（既定 `ctAuto`）・`ColorScheme` は列挙型、色は TColor。中の部品へは文字列で渡す |
| `LineText`・`LineWords` | カーソル行の文字列と単語の一覧（0 から）。単語は読んだときに分ける。区切り文字の既定は半角スペース・全角スペース・タブ・カンマ・読点。空の単語は既定で入れない。引用符（既定 `"`）の中は区切らず、引用符は取り除く |
| `Text :=` | Undo の履歴は消える。` *` は保存するまで消えない。今と同じ本文なら何もしない |
| 見えない場所での起動 | WebView2 は、表示されるまで作らない |
| `MultiDocument` | 既定 `True`。`False` は 1 ファイルだけ（中身を入れ替える）。設計時のみ変えられる |
| `WordWrap` | 既定 `True` |
| Monaco の標準機能 | 折りたたみ・括弧の対応・同じ単語の強調は既定 ON、ミニマップは既定 OFF |
| プレビュー | `ShowPreview` の既定は `False`。すべての言語のタブで出す（Markdown は文書、それ以外は色分けしたコード）。Mermaid を描く。スクロールの同期は既定 `ssBoth`。ネットの画像は既定で出さない。先頭の YAML は出さない |
| 印刷 | Edge の印刷ダイアログを出すだけ。すべての言語のタブを印刷（PDF 出力）できる。`Ctrl+P` は内蔵（フォームより先）。`Ctrl+Shift+P` は止める |
| キー | `F11` は行番号、`F12` は `OnToggleMaximize`、`Ctrl+Tab`・`Ctrl+Shift+Tab` はタブの切り替え、`Ctrl+Shift+M` はミニマップ。`OnKeyDown` の `Key := 0` で内蔵の動きを置き換えられる |
| 保存していない文書の確認 | `OnQueryClose`。設定しなければ `ConfirmOnFormClose`（既定 `True`） |
| 検索・置換ダイアログ | フォームで 1 つの共有 |
| タブの見た目 | 四角（`TabFlat = True`）、区切り線なし。ファイルの種類ごとの Windows のアイコン。配色は Windows 11 のエクスプローラーに合わせ、`ctAuto` なら OS の切り替えに合わせる |
| 標準アクション | 25 個。切り替えのアクションはチェックが自動で付く |
| タブを外へ出す | `TabTearOff = True`（既定 `True`）なら、アプリの外へタブを落とすと、部品が同じ EXE をもう 1 つ起動して、そのタブを開く（アプリのコードは 0 行）。`OnTabDragOut` の `TearOff := False` で個別にやめられる。`TabTearOff = False` でも `OnTabDragOut` は来るので、アプリが自前で作れる（4.11.5 のサンプル）。引き継ぐのは本文・ファイル名・文字コード・言語・` *`。Undo の履歴は引き継がない。無題・ファイルが消えているときは、無題＋` *` で開く。`MultiDocument = False` では知らせない |
| 分離の受け渡し | 環境変数 `CM_TEAROFF`（一時ファイルの場所）を、起動する新しい EXE にだけ渡す。起動パラメータは使わない（アプリの起動パラメータに決まりを足さないため）。WebView2.ini（全ウィンドウで共有・書けない場所のことがある）、クリップボード（利用者のコピーを消す）、DDE などのプロセス間の通信（相手の準備を待つ仕組みが要る）は使わない |
| 分離を受けるエディタ | 一時ファイルの `Editor`（`フォームの Name.エディタの Name`）と同じ名前で、`TabTearOff = True` のエディタ。1 回だけ受ける |
| タブの結合 | 同じ EXE の別のウィンドウのエディタの上へ落とすと、そのエディタに新しいタブを作る（4.11.6）。受け渡しは `WM_COPYDATA`（一時ファイルの場所）。相手がすでに同じファイルを開いていれば、そのタブに切り替えるだけ（元のタブは残す）。相手が `TabTearOff = False`・`MultiDocument = False` なら何も起きない |
| 同じ EXE の中でのタブの移動 | しない（自分のアプリの中の別のエディタへ落としても何も起きない） |
| ほかの ATTabs へタブを移す | させない（`OptMouseDragOutEnabled = False`） |
| メモリ | WebView2 のメモリ（エディタ 1 つ約 60MB）は許す |
| 作る方法 | 実行時にコードで作ってもよい |

**作らないもの**

| 項目 | 理由・代わり |
|---|---|
| `ActivePage` | 見えているタブは `ed` |
| `SelStart`・`SelLength` への書き込み | 範囲を選ぶのは `SetSelection` |
| `InsertText` | `SelText :=` で行う |
| `CaretX`・`CaretY` | `GetCursorPos`・`SetCursorPos` |
| `OnStatusChange`（状態をまとめて知らせる） | 要らない |
| `Lines`・`Pages[n].Lines`・`Pages[n].Line[n]` | `Text` を TStringList に入れて使う |
| `Pages[n].Print` | 印刷は、人が操作するもの。見えているタブを `ed.Print` |
| `SaveToFile` | `SaveAs(名前)` で同じことができる |
| `OnKeyUp`・`OnKeyPress`・マウスのイベントなど | WebView2 の中で処理され、知らせが来ない |
| `DefaultLanguage` の既定を plaintext にする、無題に番号を付ける | 今のまま |
| 数式（KaTeX）、HTML への書き出し | 要らない |
| タブの帯へのファイルのドロップ | 対応しない |
| 正規表現の検索 | 対応しない |

## 11. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| 起動しても空の枠のまま | `InitTimerTick`（6.2）。`OnError` の文。WebView2.ini、WebView2Loader.dll、WebView2 ランタイム |
| editor.html・preview.html が見つからない | `GetResourceDir`・`CXResolveRuntimeDir`（6.1）。`MonacoPath`・WebView2.ini の値 |
| 見えない場所のエディタが動かない | `Showing` の待ち（5.4）。preview は `VisibleChanged` |
| 入力した直後の `Text` が古い | 4.2 の決まりどおり（約 0.1 秒）。`OnChange` の中で読む |
| ` *` が付く・消えない | `doc.settextifdiff`・`textsync`・`doc.dirty`・`marksaved`（4.2・5.3） |
| ダイアログ・メニューで固まる | 知らせの途中で出していないか（5.4） |
| IME の窓が画面の外に出る・入力できない | `SetFocus` を知らせの途中で直接していないか（5.5） |
| フォームのショートカットが効かない・二重に動く | `MonacoAccelKeyDown` の順番、`IsBuiltinKey`（5.6） |
| 印刷でエディタの画面がそのまま出る | `Ctrl+P`・`Ctrl+Shift+P` の扱い（5.6・7.3） |
| Mermaid の図が印刷で欠ける | `prepareprint`・`printready`・`@media print`（7.3） |
| タブの色がおかしい | `OptShowEntireColor` とタブごとの色（4.6）、`ApplyThemeColors`（4.7） |
| フォームを閉じても確認が出ない | `TCMFormHook.FormCloseQuery`・`OnCloseQuery` の差し替え（3.4） |
| 標準アクションが別のエディタに効く | `gotfocus` の記録・`CMActiveEditor`（3.4・5.5） |
| スクロールがふらつく | 0.3 秒の抑え（7.4） |
| タブを外へ出しても `OnTabDragOut` が来ない・中で落としても来る | `TabsEndDrag` の条件、`IsOutsideApp`（4.11.1） |
| タブを外へ出したあとで落ちる | `AsyncTabDragOut` で後から知らせているか（4.11.1・5.4） |
| 新しいウィンドウは出るが、タブが空のまま | `CM_TEAROFF` の読み込み（`TearOffFile`）、`Editor` の名前の一致、`TabTearOff`（4.11.3） |
| 新しいウィンドウが出ない | `CreateProcessW` の起動、環境の写し（4.11.2）。`OnError` の文 |
| 別のウィンドウへ落としても結合しない・分離してしまう | EXE のパスの比較、受け口の検索（`FindWindowExW(HWND_MESSAGE)`）、`ReceiverWndProc` の受けるエディタの決め方（4.11.6） |
| 結合で送る側が固まる | `SendMessageTimeoutW` の時間、`ReceiverWndProc` の中で待っていないか（4.11.6） |

## 12. この版の変更（第 2.21 版）

コードを作るための手順。取説には入れない。

| No | ファイル | 変更 |
|---|---|---|
| 1 | `uCmonacos.pas` | `TabTearOff` の既定を `True`（`FTabTearOff := True`、`default True`）。結合（4.11.6）：送る側は `SendTearOff` の最初に、同じ EXE の受け口を探して `WM_COPYDATA` で送る処理を追加。受け口は implementation に `CMTearOffReceiver`（`RegisterClassW`・`CreateWindowExW(HWND_MESSAGE)`）・`ReceiverWndProc`・`GEditors`、`finalization` で壊す。エディタに `FMergeQueue`・`AsyncMerge`、`CreateWnd`（実行時）で `GEditors` に加えて受け口を作る、`Destroy` で外す。`QueryFullProcessImageNameW` は自分で宣言する |
| 2 | `CMonacoTabs.pas` | 変更なし |
| 3 | `uCmmonacoview.pas` | 変更なし |
| 4 | `uCmdpreview.pas` | 変更なし |
| 5 | `CMonacoPreview.pas` | 変更なし |
| 6 | `CMonacoFindDlg.pas` | 変更なし |
| 7 | `CMonacoActions.pas` | 変更なし |
| 8 | `uCXRuntime.pas` | 変更なし |
| 9 | `uCXReg.pas`・`cx_icons.lrs` | 変更なし |
| 10 | `monaco\editor.html`・`preview\preview.html` | 変更なし |
