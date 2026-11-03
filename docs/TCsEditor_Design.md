# TCsEditor 設計書

作者: aotan083
日付: 2026-11-03
版: 1.1

---

## 1. 目的と方針

TCsEditor は、TCSynEdit をタブで複数持つエディタ部品である。使い方（名前・動き・既定値）は TCMonacoEditor と同じにし、編集の部分を WebView2（Monaco）から TCSynEdit に替えて、軽く・速くする。プレビューは別の部品 TCPreview（`TCPreview_Design.md`）に分ける。検索・置換ダイアログは TCsFindDialog（8章）。

| No | 方針 |
|---|---|
| 1 | TCMonacoEditor に合わせられる所は、すべて同じにする（名前・動き・既定値）。合わせられない所は 13章 |
| 2 | 1 タブ＝1 つの TCSynEdit（`TCsSynEdit`。TCSynEdit を継承した中の部品。5章）。Undo の履歴・カーソル・スクロールはタブごとに持つ |
| 3 | TCSynEdit・TCMonacoEditor の動作確認済みのコードは変えない。TCSynEdit は 1.1 版で決めた変更だけ（`TCSynEdit_Design.md` 11章） |
| 4 | TCMonacoEditor の型・関数で、そのまま使えるものは使い回す（2.2）。同じ型・同じ関数なので、動き・既定値が同じになり、張り替えで書き方が変わらない |
| 5 | エディタを並べるときは、TCsEditor を複数貼り、アプリが TSplitter で並べる。部品の中で画面を分けない |
| 6 | 利用者が書くコードは 0 行で動く。設定はオブジェクトインスペクタ |
| 7 | 作る順番：ミニマップ（10章）は最後に作る（17章） |
| 8 | 動作環境：Lazarus 5.0 以降（テストは 5.0 RC1）。Lazarus 4.8 は cx パッケージのコンパイルが通るだけで、動作の確認・テストはしない（折り返しは 4.8 では試作版の部品になる）。この部品には版で分けるコードを持たない |

## 2. ファイルとパッケージ

### 2.1 ファイル

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCsEditor.pas`（新しく作る） | cx（実行時） | `TCsEditor`・`TCsPage`・`TCsSynEdit`・`TCsFormHook`・`TCsMinimap`・`TCsFindDialog`・`TCsFindForm`・標準アクション 25 個と元のクラス、関数 `CsActiveEditor` |
| `uCPreview.pas`（新しく作る） | cx（実行時） | `TCPreview`（`TCPreview_Design.md`） |
| `cSynedit.pas` | cx（実行時） | `TCSynEdit`（1.1 版。`TCSynEdit_Design.md`） |
| `uCXReg.pas` | cxdsgn（設計時） | 登録（12章） |
| `cseditor_icon.lrs`（新しく作る） | cxdsgn（設計時） | アイコン（12章） |
| `cx_icons.lrs` | cxdsgn（設計時） | TCMFindDialog のアイコンを外す（12章） |

- 部品ごとにファイルを増やさないため、検索・置換ダイアログ・標準アクション・ミニマップも `uCsEditor.pas` に入れる（同じユニットなので、`FindDialog` のための循環参照も起きない）。
- interface の uses：`Windows, Classes, SysUtils, Controls, Forms, ExtCtrls, StdCtrls, Graphics, Dialogs, Menus, LCLType, LCLIntf, LMessages, ActnList, Clipbrd, Registry, ShellApi, ATTabs, SynEdit, SynEditTypes, SynEditKeyCmds, SynEditMouseCmds, SynEditMarkupWordGroup, SynEditMarkupHighAll, SynEditWrappedView, csynedit, ucmmonacoview, CMonacoTabs, uCmonacos, uCPreview`
- implementation の uses：`LazUTF8, LConvEncoding, StrUtils, Math`
- cx の必要パッケージは今のまま（SynEdit・atflatcontrols_package・WebView4Delphi）。`TLazSynEditLineWrapPlugin`（`SynEditWrappedView`）は SynEdit パッケージに入っている。

### 2.2 使い回すもの

| 使うもの | 元のユニット | 使い道 |
|---|---|---|
| `TCMEncoding`（`ceUTF8`〜`ceCP932`） | `ucmmonacoview` | 文字コード |
| `TCMFindOption`・`TCMFindOptions`（`foMatchCase`・`foWholeWord`・`foLoop`） | `ucmmonacoview` | 検索のオプション |
| イベントの型（`TCMCursorEvent`・`TCMModeEvent`・`TCMSaveEvent`・`TCMFindDoneEvent`・`TCMReplaceAllDoneEvent`・`TCMNeedFileNameEvent`・`TCMErrorEvent`・`TCMDocIndexEvent`・`TCMQueryCloseEvent`・`TCMFileDropEvent`・`TCMKeyEvent`） | `ucmmonacoview` | イベント |
| `CMToHankaku`・`CMToZenkakuKatakana`・`CMToZenkakuHiragana` | `ucmmonacoview` | 右クリックの変換 |
| `TCMTabImageEvent` | `CMonacoTabs` | `OnGetTabImageIndex` |
| `TCMTheme`（`ctAuto`・`ctLight`・`ctDark`）・`TCMSelectionColorStyle`（`scStandard`〜`scCustom`）・`TCMTabDragOutEvent` | `uCmonacos` | 設定・イベント |
| `CMSplitLine`・`CMColorToHex` | `uCmonacos` | `LineWords`・色 |
| `DefHitColorLight`・`DefHitColorDark`・`DefCursorLineColorLight`・`DefCursorLineColorDark` | `uCmonacos` | 色の既定値 |

- 使い回すユニットは変えない。
- `uCmonacos` の implementation にあって使えないものは、`uCsEditor` の implementation に同じものを写す：`SelStyleLight`・`SelStyleDark`（選択の色の表）、`DefaultExtFor`（言語から保存の既定の拡張子）、内蔵のダイアログのフィルター。`ucmmonacoview` の implementation の `DecodeFileBytes`・`EncodeText`・`LoadTextFile`（文字コードの判定・変換）も写す。
- アプリが `uCsEditor` だけを uses すれば済むように、`TCMEncoding`・`TCMFindOption(s)`・`TCMTheme`・`TCMSelectionColorStyle` を型の別名で、`ceUTF8`〜`ceCP932`・`foMatchCase`・`foWholeWord`・`foLoop`・`ctAuto`・`ctLight`・`ctDark`・`scStandard`〜`scCustom` を定数で出し直す（`uCmonacos` と同じやり方）。
- 同じフォームに TCMonacoEditor と TCsEditor を置くことは想定しない（同じ名前の定数を両方のユニットが出し直すため。uses の後ろのユニットが使われる）。

**ユニットの参照**（一方向。`uCPreview` だけは implementation で `uCsEditor` を使う）

```
ucmmonacoview・ucmdpreview・CMonacoTabs・CMonacoPreview・uCmonacos・csynedit（今のまま）
   ↑ uses
uCPreview（TCPreview）  ←─ implementation で uCsEditor を使う
   ↑ uses
uCsEditor（TCsEditor）
```

## 3. 外側の部品（TCsEditor）

### 3.1 構成

```
TCsEditor（TCustomPanel）
 ├ タブ（TATTabs）            … 上端（alTop）。MultiDocument = False なら隠す
 ├ 縦のスクロールバー（TScrollBar）… 一番右（alRight）。Minimap = True のとき出す（10.5）
 ├ ミニマップ（TCsMinimap）     … 右端（alRight）。Minimap = True のとき出す（10章）
 └ 本文（TCsSynEdit × タブの数）… 残り（alClient）。見えているタブの 1 つだけ Visible
```

- 実行時だけ中の部品を作る。設計時（IDE の上）は中の部品を作らず、`Paint` で薄い枠と部品の名前を描く（TCMonacoEditor と同じ）。
- 起動直後に 1 枚、空の無題のタブを作る（`Create` の中。実行時だけ）。
- `TControl` の `Text`・`Caption` は、public で宣言し直して隠す（見えているタブの本文・タイトルにする）。`ControlStyle` から `csSetCaption` を外す。`BevelOuter := bvNone`。
- 背景色（`Color`）は `Theme` に合わせる（ダーク #1E1E1E、ライト #FFFFFF。タブが切り替わる一瞬に見える所）。
- コードで `Create` したときは、`Parent` を設定した時点でフォームの終了の確認（`TCsFormHook`）に加わる（TCMonacoEditor と同じ）。

### 3.2 API と中で呼ぶもの

`ed` は `TCsEditor`、`syn` は見えているタブの `TCsSynEdit`、`P` は `TCsPage`。動きは TCMonacoEditor の取説（`TCMonacoEditor_Usage.md`）4〜7章と同じ。違う所は 13章。

**タブの中身とファイル（`ed`・`ed.Pages[n]`）**

| 名前 | 型・引数 | 中で行うこと |
|---|---|---|
| `Text` | `string`（読み・書き） | 4.2 |
| `Lines` | `TStrings`（読み・書き） | そのタブの `syn.Lines`。書くと `Lines.Assign`（4.2） |
| `Caption` | `string`（読み） | `FileName` の名前の部分。無題なら「無題」 |
| `FileName` | `string`（読み） | `P.FFileName` |
| `Modified` | `Boolean`（読み） | `syn.Modified` |
| `Encoding` | `TCMEncoding`（読み・書き） | `P.FEncoding` |
| `Language` | `string`（読み・書き） | `P.FLanguage` → `syn.Language`（'' を書くと `DefaultLanguage`）。`OnDocumentChange` |
| `LineCount` | `Integer`（読み） | `syn.Lines.Count`（0 なら 1） |
| `SynEdit` | `TCSynEdit`（読み） | そのタブの中の部品（上級者向け。`OnChange`・`OnStatusChange`・`PopupMenu` は部品が使うので変えない） |
| `LoadFromFile` | `const AFileName: string`、戻り値 `Boolean` | 4.3 |
| `Save` | 戻り値 `Boolean` | 4.3 |
| `SaveAs` | `const AFileName: string = ''`、戻り値 `Boolean` | 4.3 |
| `Clear` | ― | 本文を空、`FFileName := ''`、`Language := DefaultLanguage`、`FEncoding := ceUTF8`、`FLineBreak := #13#10`、`syn.ClearUndo`、`Modified := False` |
| `Close` | `Force: Boolean = False`、戻り値 `Boolean` | 4.1・4.4 |

- `ed` の同じ名前のものは、見えているタブの `TCsPage` の同じ名前を呼ぶ。

**タブの集まり（`ed`）**：`OpenFile(const AFileName: string = '')`（名前を省略すると開くダイアログ）・`NewPage`・`SaveAll`・`CloseAll`・`CanCloseAll`・`FindPage`・`MovePage`・`ActiveIndex`・`PageCount`・`Pages[n]`。名前・引数・戻り値・動きは TCMonacoEditor の取説 5章と同じ。中は 4.1。

**画面の上での操作（`ed`）**

| 名前 | 中で行うこと |
|---|---|
| `SelText`（読み・書き） | 読む：`syn.SelText`。書く：`ReadOnly` なら何もしない。`syn.SelText := s`（改行は #13・#10・#13#10 のどれでも 1 つの改行。Undo 1 回）。後ろにカーソル、選択は外す |
| `SelStart`・`SelLength`（読み） | 6.5 の数え方（0 始まり、UTF-16 単位、改行はそのタブの改行コードの文字数） |
| `CanUndo`・`CanRedo` | `syn.CanUndo`・`syn.CanRedo` |
| `GetCursorPos`・`SetCursorPos`・`SetSelection` | 6.5 |
| `LineText` | `syn.Lines[行 - 1]`（行が無ければ ''） |
| `LineWords` | 4.10 |
| `LineDelimiters`・`LineSkipEmpty`・`LineQuoteChar` | `FLineDelimiters`・`FLineSkipEmpty`・`FLineQuoteChar`（既定値は TCMonacoEditor と同じ） |
| `Undo`・`Redo`・`Cut`・`Copy`・`Paste`・`SelectAll` | `syn` の同じ名前（`Cut`・`Paste` は `ReadOnly` なら何もしない） |
| `DeleteToEnd`・`DeleteToStart`・`DuplicateLine` | 6.4 |
| `ToggleOverwrite` | `syn.InsertMode := not syn.InsertMode` |
| `Find`・`FindNext`・`FindPrev`・`Replace`・`ReplaceAll`・`ShowFindDialog`・`SearchText`・`ReplaceText`・`SearchOptions` | 8章 |
| `CanPrint` | `Preview <> nil` |
| `Print` | `Preview <> nil` なら `Preview.PrintFor(Self)` |
| `SetFocus` | `QueueAsyncCall` で、今の処理が終わってから `syn.SetFocus`（見えない・使えないときは何もしない。TCMonacoEditor と同じ動き） |
| `TopLine` | `Double(syn.TopLine)` |
| `ScrollToLine` | `ALine: Double`。`syn.TopLine := Max(1, Trunc(ALine))`（TCPreview が使う） |
| `Ready` | 実行時は常に `True`（中の部品は作った時点で使える） |
| `IsDarkTheme` | 今ダークで描いているか（`ctDark` なら `True`、`ctLight` なら `False`、`ctAuto` なら OS の設定）。TCPreview が境目の色に使う。表示元が無いときのために、OS の設定を返す関数 `CsOsIsDark` も interface に置く |
| `ContextMenu` | `TPopupMenu`（読み）。部品の右クリックメニュー（7章。上級者向け） |
| `Preview` | `TCPreview`（読み・書き、published）。9章 |

**イベント**

| 名前 | 出すとき |
|---|---|
| `OnReady` | 実行時に初めて表示されたとき 1 回（`CreateWnd` から `QueueAsyncCall(AsyncReady)`。タブの分離を受けるとき（4.11）は、そのタブを作ってから） |
| `OnChange` | 見えているタブの本文が変わった（`syn.OnChange`。人の入力のほか、コードで変えたときも） |
| `OnCursorChange` | 見えているタブのカーソルが動いた（中の部品の `OnStatusChange` の `scCaretX`・`scCaretY`。前に知らせた行・桁と同じなら出さない。桁は UTF-16 単位） |
| `OnModeChange` | 挿入と上書きが切り替わった（`scInsertMode`） |
| `OnModifiedChange` | 見えているタブの ` *` が付いた・消えた（`scModified`） |
| `OnActiveChange` | 見えているタブが切り替わった |
| `OnDocListChange` | タブが増えた・減った・並び替えた |
| `OnDocumentChange` | タブの名前・言語・` *` が変わった（見えていないタブも） |
| `OnSave` | 保存した |
| `OnQueryClose`・`OnNeedFileName`・`OnFileDrop`・`OnToggleMaximize`・`OnFontSizeChange`・`OnLineNumbersChange`・`OnFindDone`・`OnReplaceAllDone`・`OnPopup`・`OnGetTabImageIndex`・`OnTabDragOut`・`OnKeyDown`・`OnError` | TCMonacoEditor と同じ（取説 6.2）。`OnKeyDown` は 6.1 |

- `Sender` は、必ずそのエディタ（TCsEditor）。
- 設定しないときの既定の動きも TCMonacoEditor と同じ（取説 6.2 の表。`OnError` の「同じメッセージは 1 回だけ」の一覧は `uCsEditor` の中に持つ）。

**設定（オブジェクトインスペクタ）**

| 名前 | 型 | 既定値 | 中で持つもの・渡し方 |
|---|---|---|---|
| `MultiDocument` | `Boolean` | `True` | `FMultiDocument`。設計時と、作ってから表示されるまでだけ変えられる（4.5） |
| `ConfirmOnFormClose` | `Boolean` | `True` | `FConfirmOnFormClose` |
| `TabTearOff` | `Boolean` | `True` | `FTabTearOff`（4.11） |
| `OpenDialog`・`SaveDialog` | `TOpenDialog`・`TSaveDialog` | nil | `FreeNotification` |
| `FindDialog` | `TCsFindDialog` | nil | `FreeNotification`（8章） |
| `TabFlat`・`TabSeparator` | `Boolean` | `True`・`False` | ATTabs の `OptShowFlat`・`OptShowFlatSepar` |
| `TabIcons`・`TabImages` | `Boolean`・`TImageList` | `True`・nil | 4.6 |
| `WordWrap` | `Boolean` | `True` | 全タブの `syn` に 5.2 |
| `LineNumbers` | `Boolean` | `False` | 全タブの `Gutter.LineNumberPart.Visible` |
| `Font` | `TFont` | BIZ UDGothic、14 ポイント、`fqCleartypeNatural` | 全タブの `syn.Font` に渡す（`FontChanged` で。5.2。文字色は渡さない） |
| `FontSize` | `Integer` | 14 | `Font.Size` と同じもの（6〜72 に収める）。`stored False`（.lfm には `Font` で保存する。張り替えた .lfm の `FontSize = 16` も読める） |
| `TabSize` | `Integer` | 4 | 全タブに 5.2（1〜16 に収める） |
| `Folding` | `Boolean` | `True` | 全タブに 5.2 |
| `MatchBrackets` | `Boolean` | `True` | 全タブに 5.2 |
| `OccurrencesHighlight` | `Boolean` | `True` | 全タブに 5.2 |
| `Minimap` | `Boolean` | `False` | `FMinimap.Visible`（10章） |
| `Theme` | `TCMTheme` | `ctAuto` | 4.7 |
| `ReadOnly` | `Boolean` | `False` | 全タブの `syn.ReadOnly` |
| `DefaultLanguage` | `string` | 'pascal' | 新しい文書と、拡張子が表にない文書の言語 |
| `AutoLanguage` | `Boolean` | `True` | 4.3 |
| `OpenDroppedFiles` | `Boolean` | `True` | 4.9 |
| `QuotePrefix` | `string` | '> ' | 7章 |
| `HitColorLight`・`HitColorDark` | `TColor` | `DefHitColorLight`・`DefHitColorDark` | 5.3 |
| `CursorLineColorLight`・`CursorLineColorDark` | `TColor` | `DefCursorLineColorLight`・`DefCursorLineColorDark` | 5.3 |
| `SelectionColorStyle` | `TCMSelectionColorStyle` | `scStandard` | TCMonacoEditor と同じ決まり（`scCustom` 以外は表の色を下の 2 つに入れる） |
| `SelectionColorLight`・`SelectionColorDark` | `TColor` | #ADD6FF・#264F78 | 書くと `SelectionColorStyle := scCustom`（.lfm の読み込み中は変えない）。.lfm には `scCustom` のときだけ保存 |
| `ShowPreview` | `Boolean` | `False` | 9章 |
| `AllowRemoteImages` | `Boolean` | `False` | 9章（TCMonacoEditor と同じ名前。つながっている TCPreview の `AllowRemoteImages` を読み書きする） |
| `Preview` | `TCPreview` | nil | 9章 |
| `Lines` | `TStrings` | 空 | 4.2（設計時の内容は 1 枚目のタブに入る） |
| `Align`・`Anchors`・`BorderSpacing`・`Constraints`・`Enabled`・`Visible`・`TabOrder`・`TabStop` | | | LCL のまま |

- 色の設定（`Color` で終わる 6 個）の決まりは TCMonacoEditor と同じ（システム色は `ColorToRGB` で今の色、`clDefault`・`clNone` は既定値）。
- 設定は、中の部品ができる前（.lfm の読み込み中）も `F…` に持ち、`Loaded` でまとめて全タブに渡す（`ApplyAllOptions`）。新しく作るタブにも、作ったときに渡す。

### 3.3 TCsPage

```pascal
TCsPage = class
private
  FOwner: TCsEditor;          // 今のエディタ（タブを別の TCsEditor へ移すと変わる。4.12）
  FSyn: TCsSynEdit;           // 中の部品。閉じたら nil
  FFileName: string;
  FEncoding: TCMEncoding;
  FLineBreak: string;         // #13#10 か #10
  FLanguage: string;
  FEmpty: TStringList;        // 閉じたページの Lines が返す空の一覧
  function GetIndex: Integer; // FOwner.FPages.IndexOf(Self)。閉じていれば -1
public
  property Caption, FileName, Modified, Encoding, Language, Text, Lines, LineCount, SynEdit;
  procedure Clear;
  function LoadFromFile(const AFileName: string): Boolean;
  function Save: Boolean;
  function SaveAs(const AFileName: string = ''): Boolean;
  function Close(Force: Boolean = False): Boolean;
end;
```

- 1 つのタブにつき 1 つ作る。エディタは、今あるタブの順に並べた `FPages` と、作ったページすべての `FAllPages` を持つ。閉じたページも `FAllPages` に残し、エディタを壊すときに解放する（取り出したページを閉じた後に使っても落ちないように）。
- 閉じたページ（`FSyn = nil`）を使ったとき、読む値は空（`Caption`・`FileName`・`Text` は ''、`Modified` は `False`、`LineCount` は 0、`Lines` は `FEmpty`、`SynEdit` は nil）、操作は何もしない（`Boolean` は `False`）。
- `Pages[n]` の番号が範囲の外なら `EListError`。

### 3.4 TCsFormHook

フォームごとに 1 つ（`TComponent`。持ち主はフォーム）。TCMonacoEditor の `TCMFormHook` と同じ作り。

| 持つもの | 中身 |
|---|---|
| `FEditors` | そのフォームの TCsEditor の一覧 |
| `FActive` | 最後にフォーカスされた TCsEditor（中の部品の `DoEnter` で `SetActive`） |
| `FFindDialog` | 共有の検索・置換ダイアログ（`SharedFindDialog` で、初めて使うときに作る） |
| `FOldCloseQuery` | フォームの元の `OnCloseQuery` |

- `CreateFor(フォーム)`・`FormCloseQuery`・`ActiveEditor`・`CsActiveEditor(Form)` は TCMonacoEditor の 3.4 と同じ。
- フォーム以外（フレームなど）に置かれたときは、エディタが自分の予備のダイアログを作る（同じ）。

## 4. 本文と文書

### 4.1 タブの集まり

| 操作 | 処理 |
|---|---|
| `OpenFile('')` | 開くダイアログ（`OpenDialog`、無ければ内蔵）。`MultiDocument = True` なら複数選べる。キャンセルなら -1 |
| `OpenFile(名前)` | 1. このエディタで開いていれば（`FindPage`）、そのタブに切り替えて、その番号を返す。2. 同じフォームの別の TCsEditor で開いていれば、そのエディタのそのタブに切り替え、そのエディタに `SetFocus` して -1 を返す（4.12 の「同じファイルは 1 か所だけ」）。3. `MultiDocument = True`：新しいタブ（`NewPageObj`）に読み込み（4.3）、見えるタブにして番号を返す。読めなければタブを残さずに例外。`False`：4.4 の確認のあと、0 番に `LoadFromFile` |
| `NewPage` | `True`：新しいタブを右端に足し、見えるタブにして番号を返す。`False`：4.4 の確認のあと、0 番を `Clear` |
| `Close`（`P.Close`） | `True`：4.4 の確認のあと、`FSyn.Free`・`FSyn := nil`、`FPages` から外す。見えているタブなら隣（右、無ければ左）を見えるタブにする。0 枚になったら空の無題を作る。`OnDocListChange` 1 回。`False`：4.4 の確認のあと、0 番を `Clear` |
| `CloseAll` | 右から順に `Close`。途中でキャンセルされたら `False` |
| `CanCloseAll` | 変更のあるタブごとに 4.4 の確認（閉じない） |
| `SaveAll` | 変更のあるタブを順に `Save`（無題は、そのタブに切り替えてから名前を聞く） |
| `FindPage(名前)` | `FPages` から `FileName` を大文字小文字を区別せずに比べて探す |
| `MovePage(From, To)` | `FPages.Move`、タブを作り直す。`OnDocListChange` |
| `ActiveIndex := n` | 範囲の外・同じなら何もしない。前の本文にフォーカスがあったか覚える。新しい `syn.Visible := True`、フォーカスがあったなら新しい `syn.SetFocus`（Ctrl+Tab を続けて押せるように。隠す前に移す）、前の `syn.Visible := False`、タブの `TabIndex`、`OnActiveChange`、TCPreview の `SourceSwitched`、ミニマップの描き直し、検索ダイアログの見出し |

- 起動直後の無題は `OpenFile` で使わない（必ず新しいタブ。TCMonacoEditor と同じ）。
- タブは常に 1 枚以上。

**新しいタブ（`NewPageObj`）**

1. `TCsPage` を作り、`FAllPages` に足す。
2. `FSyn := TCsSynEdit.Create(Self)`、`FSyn.FEditor := Self`、`Parent := Self`、`Align := alClient`、`Visible := False`、`BorderStyle := bsNone`、`PopupMenu := FMenu`、`HideSelection := False`。
3. `FEncoding := ceUTF8`、`FLineBreak := #13#10`、`FFileName := ''`、`Language := DefaultLanguage`。
4. 設定を渡す（5.2・`EditStyle`・`Font`）。
5. `FSyn.OnChange := InnerChange`。
6. `FPages` の右端に足し、タブを作り直す。

### 4.2 本文（Text・Lines）と改行

- 本文は中の部品（`syn.Lines`）だけが持つ。写しは持たない（TCMonacoEditor のずれは起きない）。
- そのタブの改行コード（`FLineBreak`）は、読み込んだときに決める（4.3）。新しい文書は #13#10。
- 最後が改行で終わる本文は、最後に空の行を 1 つ持つ（Monaco と同じ。`a` + 改行 は 2 行）。

| 名前 | 処理 |
|---|---|
| `Text` を読む | `syn.Lines` の各行を `FLineBreak` でつないだもの（最後の行の後ろには付けない） |
| `Text := s` | 今の `Text` と同じなら何もしない。違えば `SetBodyText(s)`、`syn.ClearUndo`、`syn.Modified := True` |
| `SetBodyText(s)` | `syn.Lines.Text := s`。`s` が改行（#13#10・#10・#13）で終わっていれば `syn.Lines.Add('')` |
| `Lines` を読む | `syn.Lines`（TStrings。`Lines.Text` は TStrings の決まりで、各行の後ろに改行が付く） |
| `Lines := L` | `syn.Lines.Assign(L)` |

- 設計時の `Lines`（.lfm に保存した内容）：設計時は `FDesignLines`（TStringList）に持つ。実行時は、.lfm を読むときに 1 枚目のタブの `syn.Lines` へ直接入る（`Create` で 1 枚目を作っているため）。読み込んだ後、そのタブは `Modified := False`・`ClearUndo`（`Loaded` で）。

### 4.3 ファイル

| 操作 | 処理 |
|---|---|
| 読む（`LoadFromFile`・`OpenFile`） | 別のタブ・別の TCsEditor（同じフォーム）で開いているファイルなら、読み込まず `False`（`OnError`）。`LoadTextFile` で文字コードを判定して読む（BOM → UTF-8 として正しいか → CP932。TCMonacoEditor と同じ）。改行コードは、最初に見つかった改行が #13#10 なら #13#10、#10 なら #10、無ければ #13#10。`SetBodyText`、`FFileName`、`FEncoding`、`AutoLanguage` なら `Language := CSLanguageForFile(名前, DefaultLanguage)`、`ClearUndo`、`Modified := False`、カーソルを先頭へ。`OnDocumentChange` |
| 書く（`Save`・`SaveAs`） | 無題なら名前を聞く（`OnNeedFileName`、無ければ保存ダイアログ）。`EncodeText(Text, FEncoding)` を `TFileStream`（`fmCreate`）で書く。CP932 で表せない文字は例外（`OnError`、`False`、` *` は残る）。書けたら `syn.Modified := False`（` *` が消える）、`syn.MarkTextAsSaved`、`OnSave`、`OnDocumentChange` |
| `SaveAs` で拡張子が変わった | `AutoLanguage` なら言語を決め直す。タブのアイコンも変わる |

- ファイルは押さえない（読み書きの間だけ開く。TCMonacoEditor と同じ。TCSynEdit の `LockFile` は使わない）。
- 中の部品の `FileName`・`LoadFromFile`・`SaveToFile`・`Save` は使わない（文字コードを変換しないため）。言語は `syn.Language` で決める。
- 内蔵のダイアログ（フィルター・保存の既定の拡張子・最初のフォルダー）は TCMonacoEditor と同じ（取説 7章の「内蔵のダイアログ」）。

### 4.4 保存していない文書の確認（DoQueryClose）

TCMonacoEditor の 4.4 と同じ（`OnQueryClose` → `ConfirmOnFormClose` の確認 → 捨てる）。確認の文も同じ。

### 4.5 MultiDocument

TCMonacoEditor の 4.5 と同じ表。`False` のときはタブ（ATTabs）を隠し、タブは常に 1 枚。

### 4.6 タブ（ATTabs）

TCMonacoEditor（`CMonacoTabs.pas`・`uCmonacos.pas`）と同じ設定・同じ見た目にする。違いは、タブと文書をつなぐ処理を `TCsEditor` の中に直接書くこと（`TCMTabBinder` は使わない）。

| 項目 | 処理 |
|---|---|
| 作り直す（`RebuildTabs`） | `FPages` の順にタブを作る。タブの `TabObject` にページを入れる。タイトルは `Caption`、変更ありなら後ろに ` *`、ヒントはフルパス |
| 1 つ更新（`UpdateTab`） | タイトル・ヒント・アイコンだけ |
| クリック | `ActiveIndex` を切り替え、本文にフォーカス |
| ［＋］ | `NewPage` |
| ［×］・中ボタン | `Close`（4.4 の確認）。ATTabs の処理の途中で閉じないよう、`QueueAsyncCall` で後から閉じる |
| ドラッグで並べ替え | `FPages.Move` |
| 外へドラッグ（`OnEndDrag`） | 4.11・4.12 |
| 見た目 | `OptShowFlat := TabFlat`、`OptShowFlatSepar := TabSeparator`、`OptShowEntireColor := True`（タブごとの色で、見えているタブ・マウスを乗せたタブを塗る）、アクセントの線は出さない、`OptMouseDragOutEnabled := False` |
| 文字 | `ParentFont := False`。TCsEditor の `Font`・`FontSize` には合わせない（タブの高さは変わらないので、大きくするとはみ出すため）。TCMonacoEditor と同じ、普通の大きさの文字（`Screen.SystemFont`）のまま |
| アイコン | `TabIcons = True` で `TabImages` が無いとき：`SHGetFileInfo`（`SHGFI_USEFILEATTRIBUTES`・小さいアイコン）で拡張子から取り、内部の画像リストに入れる（同じ拡張子は 1 回。無題は '.txt'）。`TabImages` があるとき：`OnGetTabImageIndex`（無ければ 0 番）。`False`：なし |

### 4.7 配色（Theme）

| `Theme` | 中の部品の `EditStyle` |
|---|---|
| `ctAuto` | OS がダークなら `csVSDark`、ライトなら `csVSLight`。OS の切り替えに合わせる |
| `ctLight` | `csVSLight` |
| `ctDark` | `csVSDark` |

- OS のダーク・ライトは、レジストリ `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` の `AppsUseLightTheme`（0 ならダーク。値が無ければライト）。
- OS の切り替えは、受け口のウィンドウ（4.11.4）で `WM_SETTINGCHANGE` を受け、`lParam` の文字列が 'ImmersiveColorSet' のとき、`QueueAsyncCall` で全エディタ（`GEditors`）に知らせる。各エディタは、レジストリを読み直し、`ctAuto` で前と違えば塗り直す（`ApplyTheme`）。
- `ApplyTheme`：全タブの `syn.EditStyle`、タブの色、背景色（`Color`）、ミニマップ。表示元の TCPreview には `SourceSwitched`（プレビューの配色を合わせる）。
- タブ・背景の色は TCMonacoEditor の `ApplyThemeColors` と同じ値（取説 9.4 の表）。
- スクロールバー：中の部品のスクロールバーは Windows が描く。ダークのときは `SetWindowTheme(syn.Handle, 'DarkMode_Explorer', nil)`、ライトのときは `SetWindowTheme(syn.Handle, 'Explorer', nil)` を当てる（`uxtheme.dll`）。当てるのは `ApplyTheme` と、中の部品のウィンドウを作り直したとき（`TCsSynEdit.CreateWnd`）。Windows 10 1809 より前では色は変わらない（動きは同じ）。本文とミニマップの間の縦の帯は、このスクロールバー。

### 4.8 右クリックメニュー

7章。

### 4.9 ファイルのドロップ

- 中の部品のドロップ（`TCsSynEdit.DoDropFiles` の override）で受ける。ファイル名を `FDropFiles`（`TStringList`）に入れて `QueueAsyncCall(AsyncDropFiles)`（ウィンドウのメッセージの途中で、確認のダイアログを出さないため）。
- `AsyncDropFiles`：`OnFileDrop`（`Handled` なら終わり）→ `OpenDroppedFiles` なら開く。`MultiDocument = True` はすべて `OpenFile`（開いていればそのタブへ）。`False` は最初のファイルだけ。フォルダーは無視する（TCMonacoEditor と同じ）。
- タブの帯・ミニマップへのドロップは受けない（TCMonacoEditor と同じ）。

### 4.10 カーソル行の単語（LineWords）

- `FLineWords: TStringList` を 1 つ持つ。前に分けたときの「行の文字列・区切り文字・空の単語・引用符」を覚え、`LineWords` を読んだとき、どれも同じなら分け直さない。
- 分けるのは `CMSplitLine(LineText, FLineDelimiters, FLineSkipEmpty, FLineQuoteChar, FLineWords)`（TCMonacoEditor と同じ関数）。
- 本文は中の部品にあるので、読んだときに常に今のカーソル行で分ける（TCMonacoEditor の「入力直後の約 0.1 秒」のずれはない）。

### 4.11 タブの分離と結合（TabTearOff・OnTabDragOut）

#### 4.11.1 TCMonacoEditor と同じ所

`TCMonacoEditor_Design.md` 4.11 と同じ作り・同じ動き：外へ出したことの検知（`OnEndDrag` の `Target = nil`、左ボタン、`IsOutsideApp`、`QueueAsyncCall`）、`TearOff` の初めの値（無題・空の 1 枚なら `False`）、`OnTabDragOut`、一時ファイルを書いて同じ EXE を `CreateProcessW` で起動、環境変数の渡し方、受けるエディタの決め方（`Owner.Name + '.' + Name`）、ウィンドウの位置、結合（同じ EXE の判定、`WM_COPYDATA`、返事 0・1・2、3 秒、`AsyncMerge`）。

#### 4.11.2 違う所

| 項目 | TCMonacoEditor | TCsEditor |
|---|---|---|
| 環境変数 | `CM_TEAROFF` | `CS_TEAROFF` |
| 一時ファイルの目印（1 行目） | `CMTEAROFF1` | `CSTEAROFF1` |
| 一時ファイルの名前の頭 | `cmt` | `cst` |
| 一時ファイルの見出し | `Editor`・`FileName`・`Encoding`・`Language`・`Modified`・`X`・`Y` | 左のものに `LineBreak`（`CRLF`・`LF`）を足す |
| 本文 | 写し | `P.Text`（ずれなし） |
| 受け口のウィンドウ | クラス名 `CMTearOffReceiver`、メッセージ専用（親 `HWND_MESSAGE`） | クラス名 `CSEditorReceiver`、見えないトップレベルのウィンドウ（`WS_POPUP`、表示しない、持ち主なし）。OS のテーマの知らせ（`WM_SETTINGCHANGE`）はトップレベルのウィンドウにしか届かないため（4.7） |
| 受け口の探し方 | `FindWindowExW(HWND_MESSAGE, 前, 'CMTearOffReceiver', nil)` | `FindWindowExW(0, 前, 'CSEditorReceiver', nil)` |
| `WM_COPYDATA` の `dwData` | `$434D544F`（'CMTO'） | `$4353544F`（'CSTO'） |
| 分離を受けてタブを作る時 | `ready` の知らせで、`OnReady` の前 | `AsyncReady` の中で、`OnReady` の前 |
| 受けたタブの改行コード | ― | 見出しの `LineBreak` |

- 名前を分けるのは、同じ EXE に TCMonacoEditor があっても互いに受け取らないため。
- 受け口は、実行時のエディタが初めて `CreateWnd` を通ったときに作り、`finalization` で壊す。`GEditors: TFPList`（実行時の TCsEditor の一覧）を `CreateWnd` で加え、`Destroy` で外す。

### 4.12 同じフォームの別の TCsEditor へタブを移す

タブを、同じフォームの別の TCsEditor（並べて貼ったもの）の上へドラッグして離すと、そのタブを移す。中の部品（`TCsSynEdit`）ごと移すので、Undo の履歴・カーソル位置も残る。

**検知**（4.11.1 の `OnEndDrag` で、外へ出したかを調べる前に）

1. 離した位置（`Mouse.CursorPos`）の部品を `FindControlAtPosition(P, False)` で取り、`Parent` をたどって TCsEditor を探す。`Target` が nil でないときは、`Target` からたどる。
2. 見つかった TCsEditor が、自分ではなく、同じフォーム（`GetParentForm` が同じ）なら、移す。`QueueAsyncCall(AsyncMoveTab)` で、ドラッグの処理が終わってから行う。
3. 見つからなければ、4.11（外へ出したか）へ進む。

**移す（`AsyncMoveTab` → `MovePageTo(Index, Dest)`）**

| 状況 | 処理 |
|---|---|
| 相手が `MultiDocument = False` | 何もしない |
| 何も入っていない無題が 1 枚だけ | 何もしない |
| 相手が同じファイルをすでに開いている | 相手のそのタブに切り替え、相手にフォーカス。元のタブは残す |
| それ以外 | 下の手順 |

1. 元のエディタ：ページを `FPages`・`FAllPages` から外す（`syn` は壊さない）。見えているタブだったら隣を見えるタブにし、0 枚になったら空の無題を作る。`OnDocListChange`。
2. 中の部品：`RemoveComponent`（元）→ `InsertComponent`（相手）、`Parent := 相手`、`FEditor := 相手`、`PopupMenu := 相手の FMenu`。
3. ページ：`FOwner := 相手`。相手の `FPages` の右端・`FAllPages` に足す。
4. 相手の設定を渡す（5.2・`EditStyle`・`Font`）。
5. 相手：タブを作り直し、移したタブを見えるタブにし、フォーカス。`OnDocListChange`・`OnActiveChange`。

- 同じ EXE の別のウィンドウへは 4.11 の結合、別のフォームの TCsEditor へは移さない（何も起きない）。

**同じファイルは 1 か所だけ**

- 同じフォームの TCsEditor の間で、同じファイルを 2 か所で開かない（左右で同じファイルを同時に編集する作りにはしない）。`OpenFile`・`LoadFromFile`・`SaveAs` のときに、`TCsFormHook.FEditors` のほかのエディタの `FindPage` も調べる（4.1・4.3）。

## 5. 中の部品（TCsSynEdit）

### 5.1 作り

```pascal
TCsSynEdit = class(TCSynEdit)       // uCsEditor の implementation の前（interface）に置く。登録しない
private
  FEditor: TCsEditor;               // 今のエディタ
  FWrap: TLazSynEditLineWrapPlugin; // 折り返し。WordWrap = False なら nil
protected
  procedure KeyDown(var Key: Word; Shift: TShiftState); override;                     // 6章
  function DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean; override; // 5.4
  function DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean; override;
  procedure DoDropFiles(const AFiles: array of string); override;                     // 4.9
  procedure ApplyEditStyle; override;                                                 // 5.3
  procedure CreateWnd; override;                                                      // 4.7 のスクロールバー
  procedure DoEnter; override;                                                        // 5.3・9章
  procedure DoExit; override;
end;
```

- TCSynEdit の Ctrl+S・Shift+F10・F12・Ctrl+ホイール・ドロップ・右クリックメニューは、この部品が先に受けて、TCsEditor の動きにする（TCSynEdit 本体は変えない）。
- 中の部品の知らせは、中の部品のイベントで受ける（`StatusChanged` の override では受けない。SynEdit は書き換えの途中の知らせをためて、あとで `StatusChanged` を通らずにまとめて出すため、override では取りこぼす）。

| 中の部品のイベント | TCsEditor の処理 |
|---|---|
| `OnStatusChange` → `InnerStatus` | ` *` が付いた・消えたら（前に知らせた値と比べる）タブの ` *`（`UpdateTab`）・`OnDocumentChange`、見えているタブなら `OnModifiedChange`。見えているタブのときだけ、`OnCursorChange`（`scCaretX`・`scCaretY`）・`OnModeChange`（`scInsertMode`）、`scTopLine` で TCPreview の `SourceScrolled` とミニマップの描き直し |
| `OnChangeUpdating` → `InnerUpdating` | 書き換えの始まり・終わり。終わったときに `InnerChange` |
| `OnChange` → `InnerChange` | 書き換えの途中なら何もしない（終わってから）。本文の変更の番号（`ChangeStamp`）が前に知らせたときから進んでいれば、見えているタブのときだけ `OnChange`・TCPreview の `SourceChanged`・ミニマップの描き直し。中の部品の `OnChange` は Undo の記録ごとに来る（1 文字の入力で 2 回来ることがある）ので、1 つの変更で 1 回にそろえる |

- `TCsSynEdit` には、自分のページ（`FPage: TCsPage`）も持たせる（知らせを受けたとき、どのタブかを知るため）。

### 5.2 設定の渡し方

| TCsEditor の設定 | 中の部品 |
|---|---|
| `WordWrap` | `True`：`FWrap` が無ければ `TLazSynEditLineWrapPlugin.Create(Self)`。`False`：`FreeAndNil(FWrap)` |
| `LineNumbers` | `Gutter.LineNumberPart.Visible` |
| `Font`・`FontSize` | 中の部品の今の文字色を覚え、`Font.Assign(エディタの Font)` のあと、文字色を戻す（文字色は配色（4.7）が決める。TCsEditor の `Font.Color` は使わない） |
| `TabSize` | `TabWidth`・`BlockIndent` を同じ値、`BlockTabIndent := 0` |
| `Folding` | `Gutter.CodeFoldPart.Visible`。`False` にしたら `UnfoldAll` |
| `MatchBrackets` | `Options` の `eoBracketHighlight`、`MarkupByClass[TSynEditMarkupWordGroup].Enabled` |
| `OccurrencesHighlight` | `MarkupByClass[TSynEditMarkupHighlightAllCaret].Enabled`（`FullWord := True`、`Trim := True`、`WaitTime := 200`） |
| `ReadOnly` | `ReadOnly` |
| `Theme` | `EditStyle`（4.7） |

**作ったときに入れる設定**（どのタブも同じ）

| 項目 | 値 | 理由（Monaco と同じ動きにするため） |
|---|---|---|
| `Options` | `[eoAutoIndent, eoGroupUndo, eoTabsToSpaces, eoKeepCaretX, eoEnhanceHomeKey, eoDragDropEditing, eoScrollPastEof, eoAltSetsColumnMode, eoShowScrollHint]` ＋ `MatchBrackets` なら `eoBracketHighlight` | 行の後ろの空白を消さない（`eoTrimTrailingSpaces` を入れない）、行の終わりより右にカーソルを置かない（`eoScrollPastEol` を入れない）、Tab で空白を入れる（Monaco の既定） |
| `Keystrokes` | 5.5 の表だけ | SynEdit の既定のキー（Ctrl+Y で行を消す など）を Monaco に合わせる |
| `MouseActions` | 既定に「Shift+Alt+左ドラッグ＝四角い範囲の選択」（`emcStartColumnSelections`）を足す | Monaco の `Shift+Alt+ドラッグ` |
| `Gutter.LineNumberPart.ShowOnlyLineNumbersMultiplesOf` | 1 | すべての行に番号 |
| `WantTabs` | `True` | Tab をエディタで使う |
| `HideSelection` | `False` | フォーカスがない間も検索で見つかった所を出す（5.3） |
| `ScrollBars` | `ssAutoBoth` | |

### 5.3 色（ApplyEditStyle の override）

1. `inherited ApplyEditStyle`（TCSynEdit の `csVSLight`・`csVSDark` の色。`TCSynEdit_Design.md` 7.4）。
2. ダークかどうか（`EditStyle = csVSDark`）で、TCsEditor の設定の色を入れる：
   - `LineHighlightColor.Background := CursorLineColorDark`（ライトなら `…Light`）。`Foreground := clNone`、`FrameColor := clNone`。
   - `SelectedColor.Background`：フォーカスがあれば `SelectionColorDark`（`…Light`）、なければ `HitColorDark`（`…Light`）。`Foreground := clNone`。
3. 色はすべて、TCMonacoEditor と同じ決まりで実際の色にする（システム色は `ColorToRGB`、`clDefault`・`clNone` は既定値）。

- `DoEnter`：`inherited`、選択の色を `SelectionColor…` にする、`TCsFormHook.SetActive(FEditor)`、TCPreview の `SetSource(FEditor)`（9章）、検索ダイアログの対象を付け替える。
- `DoExit`：`inherited`、選択の色を `HitColor…` にする（検索ダイアログを操作している間、見つかった所を目立たせる。TCMonacoEditor と同じ）。

### 5.4 マウス

| 操作 | 動き |
|---|---|
| Ctrl+ホイール | `FEditor.FontSize` を 1 上げる・下げる（6〜72）。全タブ。`OnFontSizeChange`。`True` を返す |
| ホイール | `inherited`（TCSynEdit の Ctrl の処理には届かない） |
| 右クリック | `PopupMenu`（TCsEditor の `FMenu`）を出す |

### 5.5 キーの割り当て（Keystrokes）

`Keystrokes.Clear` の後、次だけを入れる（ここにないキーはエディタでは何もしない。フォームのショートカットに回る。6.1）。

| キー | コマンド |
|---|---|
| ←・→・↑・↓ | `ecLeft`・`ecRight`・`ecUp`・`ecDown` |
| Shift＋←・→・↑・↓ | `ecSelLeft`・`ecSelRight`・`ecSelUp`・`ecSelDown` |
| Ctrl＋←・→ | `ecWordLeft`・`ecWordRight` |
| Ctrl＋Shift＋←・→ | `ecSelWordLeft`・`ecSelWordRight` |
| Ctrl＋↑・↓ | `ecScrollUp`・`ecScrollDown` |
| Home・End | `ecLineStart`・`ecLineEnd` |
| Shift＋Home・End | `ecSelLineStart`・`ecSelLineEnd` |
| Ctrl＋Home・End | `ecEditorTop`・`ecEditorBottom` |
| Ctrl＋Shift＋Home・End | `ecSelEditorTop`・`ecSelEditorBottom` |
| PageUp・PageDown | `ecPageUp`・`ecPageDown` |
| Shift＋PageUp・PageDown | `ecSelPageUp`・`ecSelPageDown` |
| BackSpace・Shift＋BackSpace | `ecDeleteLastChar` |
| Delete | `ecDeleteChar` |
| Ctrl＋BackSpace | `ecDeleteLastWord` |
| Ctrl＋Delete | `ecDeleteWord` |
| Enter・Shift＋Enter | `ecLineBreak` |
| Tab | `ecTab` |
| Shift＋Tab | `ecShiftTab` |
| Insert | `ecToggleMode` |
| Ctrl＋X・Shift＋Delete | `ecCut` |
| Ctrl＋C・Ctrl＋Insert | `ecCopy` |
| Ctrl＋V・Shift＋Insert | `ecPaste` |
| Ctrl＋Z | `ecUndo` |
| Ctrl＋Y・Ctrl＋Shift＋Z | `ecRedo` |
| Ctrl＋A | `ecSelectAll` |
| Ctrl＋]・Ctrl＋[ | `ecBlockIndent`・`ecBlockUnindent` |
| Ctrl＋Shift＋[・Ctrl＋Shift＋] | `ecFoldCurrent`・`ecUnFoldCurrent` |

- コマンドの名前は Lazarus 5.0 RC1 の `SynEditKeyCmds` に合わせる（コンパイルで確かめる）。
- TCsEditor が自分で処理するキー（6.2・6.3）は、ここには入れない（`KeyDown` で先に受ける）。

## 6. キーの処理

### 6.1 順番（TCsSynEdit.KeyDown）

1. `FEditor.KeyDown(Key, Shift)`（TCsEditor の protected virtual。継承した部品が override できる。その中の `inherited` で `OnKeyDown`）。`Key = 0` なら終わり。
2. `Ctrl+P`：`Print`、`Key := 0`。
3. `Ctrl+Shift+M`：`Minimap := not Minimap`、`Key := 0`。
4. `Ctrl+Tab`・`Ctrl+Shift+Tab`：次・前のタブ（端まで行ったら反対側。`MultiDocument = False` なら何もしない）、`Key := 0`。
5. 内蔵のショートカット（6.2）なら、その動き、`Key := 0`。ただし `Ctrl+Z`・`Ctrl+Y`・`Ctrl+Shift+Z`・`Ctrl+X`・`Ctrl+C`・`Ctrl+V` は、ここでは何もせず 7 へ（エディタのコマンドで行う）。
6. フォームのメニュー・ActionList に同じショートカットがあれば実行し、`Key := 0`（`ShortCut(Key, Shift)` と同じショートカットを、フォームのメインメニュー（`Menu.FindItem(…, fkShortCut)`）と、フォームの ActionList の各アクションから探す。メニューは `Click`、アクションは `Update` のあと使えれば `Execute`。TCMonacoEditor の `FindFormShortcut` と同じ。LCL の `IsShortcut` は Ctrl・Shift を本物のキーボードから読むので、受けたキーと食い違うことがあり、使わない）。
7. 6.3 のキーなら、その動き、`Key := 0`。
8. どれでもなければ `inherited KeyDown`（5.5 の `Keystrokes`。TCSynEdit の Ctrl+S・Shift+F10・F12 は 5 で受けているので届かない）。

- 「内蔵のショートカット」と、`Ctrl+Z` などの 6 つは、フォームのショートカットより先（TCMonacoEditor と同じ）。それ以外のキー（6.3・5.5 の表）は、フォームに同じショートカットがあればフォームが先（TCMonacoEditor の「Monaco のキーはフォームが先」と同じ）。
- フォームの `KeyPreview = True` のときは、LCL の決まりで、フォームの `OnKeyDown` がこの順番より前に来る。

### 6.2 内蔵のショートカット（TCMonacoEditor の取説 8.1 と同じ）

| キー | 動き |
|---|---|
| Ctrl+S | 見えているタブを `Save` |
| Ctrl+F | `ShowFindDialog`。1 行の範囲を選んでいれば、その文字列を最初の検索語にする |
| F5・Shift+F5 | `FindNext`・`FindPrev` |
| Ctrl+Shift+V | `ShowPreview` を切り替える（9章。`Preview` が無ければ何もしない） |
| Ctrl+Shift+P | 何もしない（フォームに同じショートカットがあれば、6.1 の 6 でそちらを実行する） |
| Shift+F10 | `DuplicateLine` |
| F11 | `LineNumbers` を切り替え、`OnLineNumbersChange` |
| F12 | `OnToggleMaximize` |

- `Insert`（挿入・上書き）、`Ctrl+A`（すべて選択）、`Ctrl+ホイール` は 5.4・5.5 で同じ動き。

### 6.3 Monaco に最初からあるキー（TCMonacoEditor の取説 8.2 で「使える」もの）

| キー | 動き | 処理 |
|---|---|---|
| `Alt+↑`・`Alt+↓` | 行を上下に動かす（選んでいれば、その行をまとめて） | 6.4 の `MoveLines` |
| `Shift+Alt+↑`・`Shift+Alt+↓` | 行を上・下に複製 | 6.4 の `CopyLines` |
| `Ctrl+]`・`Ctrl+[` | インデント・逆インデント | 5.5 |
| `Ctrl+/` | 行コメントの切り替え | 6.4 の `ToggleComment` |
| `Ctrl+G` | 指定した行へ移る | `InputQuery('行へ移動', '行番号（1〜行数）', S)`。数なら `SetCursorPos(行, 1)` |
| `Ctrl+Shift+[`・`Ctrl+Shift+]` | 折りたたむ・開く | 5.5 |
| `Ctrl+Enter` | 下に空の行を入れて、そこへ移る（字下げは今の行と同じ） | 6.4 の `InsertLineBelow` |
| `Shift+Alt+ドラッグ` | 四角い範囲を選ぶ | 5.2（`MouseActions`） |

- `F1`（コマンドパレット）・`Ctrl+D` などのマルチカーソルは作らない。`Ctrl+Shift+Enter`・`Ctrl+Shift+K` は TCMonacoEditor でも使えないので作らない。
- `ReadOnly` のときは、編集する動き（行を動かす・複製・コメント・行を入れる）は何もしない。

### 6.4 編集の処理

どれも `syn.BeginUndoBlock`〜`EndUndoBlock` の中で、`syn.TextBetweenPoints[開始, 終わり] := 文字列`（論理位置）で書き換える（Undo 1 回で戻る）。

| 処理 | 中身 |
|---|---|
| `DuplicateLine` | 選んでいる行（選んでいなければカーソル行）を、その下に入れ、カーソル（選択）を複製した行へ移す |
| `DeleteToEnd`・`DeleteToStart` | 選んでいなければ、カーソルから文書の末尾・先頭までを消す。選んでいれば、`DeleteToEnd` は選択の始まりから末尾まで、`DeleteToStart` は先頭から選択の終わりまでを消す（選んだ部分も消える）。`SetSelection` のあとカーソルは選択の終わりにあるため、カーソルからにすると、選んだ所より前が残る |
| `MoveLines(上/下)` | 対象の行と、上（下）の 1 行を入れ替え、カーソル・選択も一緒に動かす。端なら何もしない |
| `CopyLines(上/下)` | 対象の行を、上（下）に複製する。カーソルは、上なら元の位置、下なら複製した行 |
| `ToggleComment` | 言語のコメントの書き方（下の表）。対象の行で、空の行を除くすべてが（字下げの後ろが）コメントの印で始まっていれば外す。そうでなければ、対象の行の最も小さい字下げの位置に付ける。書き方の無い言語は何もしない |
| `InsertLineBelow` | カーソル行の後ろに改行と、今の行の字下げ（行の頭の空白・タブ）を入れ、カーソルをその行の終わりへ |
| 右クリックの変換（7章） | 選択を変換した文字列に置き換え、置き換えた範囲を選び直す |

| 言語 | 行コメント |
|---|---|
| pascal・javascript・json・typescript・cpp・csharp・java・php・go | `// ` |
| python・shell・yaml・powershell | `# ` |
| sql | `-- ` |
| ini | `; ` |
| bat | `REM ` |
| html・xml・markdown | 行の前に `<!-- `、後ろに ` -->` |
| css | 行の前に `/* `、後ろに ` */` |
| plaintext | なし |

### 6.5 位置の数え方（UTF-16）

TCMonacoEditor と同じく、桁と位置は UTF-16 単位で数える（絵文字は 2）。中の部品は UTF-8 のバイトの位置（論理位置）なので、変換する。

| 名前 | 処理 |
|---|---|
| UTF-8 → UTF-16 の桁 | 行の頭から論理位置の手前までを `UTF8ToUTF16` にした長さ + 1 |
| UTF-16 → UTF-8 の桁 | 行の頭から、UTF-16 の数がそこに達するまで 1 文字ずつ進めたバイトの位置 + 1（行の長さを越えたら行の終わり） |
| `GetCursorPos(out Line, Column)` | `syn.LogicalCaretXY` の行と、その桁を UTF-16 にしたもの |
| `SetCursorPos(Line, Column)` | 行を 1〜行数に収め、桁を UTF-8 にして `syn.LogicalCaretXY` |
| `SetSelection(L1, C1, L2, C2)` | 両端を論理位置にして `BlockBegin`・`BlockEnd`、カーソルは終わり |
| `SelStart` | 選択の開始（選んでいなければカーソル）より前の各行の UTF-16 の長さ + 改行の文字数（`Length(FLineBreak)`）の合計 + その行の頭からの UTF-16 の長さ |
| `SelLength` | 選択の文字列を、改行を `FLineBreak` にして UTF-16 で数えた長さ |

### 6.6 表示している先頭の行

- `TopLine` は `syn.TopLine`（整数。行の中の位置は持たない）。折り返しのときも、表示している先頭の文の行。
- `ScrollToLine(ALine)` は `syn.TopLine := Trunc(ALine)`。

## 7. 右クリックメニュー

TCMonacoEditor の取説 9.7 と同じ項目・同じ出し方。メニュー（`FMenu: TPopupMenu`）はエディタに 1 つ作り、全タブの中の部品の `PopupMenu` に入れる（TCSynEdit が持つメニューは使わない）。

| 項目 | 処理 |
|---|---|
| 切り抜き・コピー・貼り付け | `Cut`・`Copy`・`Paste` |
| 引用付きコピー | 選択の各行の先頭に `QuotePrefix` を付けて `Clipboard.AsText`（最後の改行は保つ） |
| 追加切り抜き・追加コピー | `Clipboard.AsText := 今の中身 + SelText`（切り抜きは選択を消す） |
| 削除 | 選択を消す |
| TO UPPER CASE・to lower case | `UTF8UpperCase`・`UTF8LowerCase` で変換（6.4 の「変換」） |
| ﾊﾝｶｸに変換・全角ひらがなに変換・全角カタカナに変換 | `CMToHankaku`・`CMToZenkakuHiragana`・`CMToZenkakuKatakana`（TCMonacoEditor と同じ関数。6.4 の「変換」） |
| TAB -> 空白・空白 -> TAB | 選択の中の `#9` を `TabSize` 個の空白に、`TabSize` 個の空白を `#9` に（6.4 の「変換」） |
| インデント・逆インデント | `ecBlockIndent`・`ecBlockUnindent` |
| すべて選択・元に戻す・やり直し | `SelectAll`・`Undo`・`Redo` |
| ミニマップ　Ctrl+Shift+M | `Minimap` を切り替える（チェック付き） |
| プレビュー　Ctrl+Shift+V | `ShowPreview` を切り替える（チェック付き）。`Preview` が無ければ使えない |

- 出す直前（`FMenu.OnPopup`）に、選んでいるか・`ReadOnly`・`Minimap`・`ShowPreview`・`Preview` で、項目の表示・使える・チェックを決め、`OnPopup` を呼ぶ（TCMonacoEditor と同じ表）。
- 項目は TCMonacoEditor の `TCMMenuItem` と同じ考え方で、番号（`Tag`）で処理を分ける。アプリが `ContextMenu.Items.Add` で足した項目は、後ろに並ぶ。

## 8. 検索・置換（TCsFindDialog）

### 8.1 ダイアログ

- `TCsFindDialog = class(TComponent)`、`TCsFindForm = class(TForm)`。`CMonacoFindDlg.pas` の `TCMFindDialog`・`TCMFindForm` を写し、対象の型を `TCsEditor` に替える（見た目・大きさ（470×190）・文言・履歴 30 件・`Enter`・`Esc`・結果の表示は同じ）。
- メソッド・プロパティも同じ名前：`ShowFor(AEditor, InitialText)`・`CloseDialog`・`IsShowing`・`UpdateCaption`・`NotifyFindDone`・`NotifyReplaceAllDone`・`Target`・`SearchText`・`ReplaceText`・`Options`・`FindHistory`・`ReplaceHistory`。
- 見出しは「検索・置換 - （対象の見えているタブの名前）」。
- `FindDialog` を設定しないエディタは、フォームに 1 つの共有ダイアログ（`TCsFormHook.SharedFindDialog`）を使う。対象は最後にフォーカスされたエディタ（5.3 の `DoEnter` で付け替える）。

### 8.2 エディタの検索・置換

`SearchReplace` のオプション：`foMatchCase` → `ssoMatchCase`、`foWholeWord` → `ssoWholeWord`。

| 名前 | 処理 |
|---|---|
| `Find(S, Opt, Forward)` | `S` が空なら何もしない。`SearchText := S`・`SearchOptions := Opt`。前へは、カーソルを選択の開始（`BlockBegin`）に、次へは選択の終わり（`BlockEnd`）に置いてから `SearchReplace(S, '', opt)`（前へは `ssoBackwards`）。0 件で `foLoop` なら、カーソルを先頭（前へは末尾）へ移してもう一度。見つかれば選択され、見える位置にスクロールする。`OnFindDone(Found)`、ダイアログに `NotifyFindDone` |
| `FindNext`・`FindPrev` | `SearchText` が空ならダイアログを開く。そうでなければ `Find(SearchText, SearchOptions, True/False)` |
| `Replace(S, R, Opt)` | `ReadOnly` なら何もしない。選択が `S` と同じ（`foMatchCase` なら大文字小文字も）なら `SelText := R`（Undo 1 回）。そのあと `Find(S, Opt, True)` |
| `ReplaceAll(S, R, Opt)` | `ReadOnly` なら何もしない。`BeginUndoBlock`、`SearchReplace(S, R, [ssoReplace, ssoReplaceAll, ssoEntireScope] ＋ opt)` の件数、`EndUndoBlock`（Undo 1 回）。`OnReplaceAllDone(件数)`、ダイアログに `NotifyReplaceAllDone` |
| `ShowFindDialog(InitialText)` | `FindDialog`（無ければ共有）の `ShowFor(Self, InitialText)` |

- 正規表現は使わない（TCMonacoEditor と同じ）。対象は見えているタブだけ。

## 9. プレビュー（TCPreview）とのつなぎ

| 名前・きっかけ | 処理 |
|---|---|
| `Preview := P` | 前の TCPreview があれば `SourceRemoved(Self)`・`RemoveFreeNotification`。新しいものに `FreeNotification`。設計時・読み込み中はそれだけ |
| `ShowPreview` を読む | 実行時で `Preview` があれば `Preview.Visible`。設計時・読み込み中は `FShowPreview`。`Preview` が無ければ `False` |
| `ShowPreview := v` | `FShowPreview := v`。実行時で `Preview` があれば、`v = True` なら `Preview.SetSource(Self)` のあと `Preview.Visible := True`、`False` なら `Preview.Visible := False` |
| `Loaded`（実行時） | `Preview` があり `FShowPreview = True` なら `Preview.Visible := True`。`False` なら変えない（ほかのエディタが表示を決めることがあるため） |
| 中の部品の `DoEnter` | `Preview.SetSource(Self)` |
| 本文が変わった（`InnerChange`、見えているタブ） | `Preview.SourceChanged(Self)` |
| タブの切り替え・言語・ファイル名の変更・配色の変更 | `Preview.SourceSwitched(Self)` |
| 表示している先頭の行が変わった（`scTopLine`） | `Preview.SourceScrolled(Self, TopLine)` |
| `Print`・`Ctrl+P` | `Preview.PrintFor(Self)` |
| `AsyncReady` | `Preview` があり、`Preview.Source = nil` なら `Preview.SetSource(Self)` |
| `Notification`（TCPreview が壊された） | `FPreview := nil` |

- プレビューの設定（`FontSize` など）は TCPreview に持つ（`ed.Preview.FontSize`）。
- `AllowRemoteImages` だけは、TCMonacoEditor と同じく `ed.AllowRemoteImages` でも読み書きできる。読む：`Preview` があれば `Preview.AllowRemoteImages`、無ければ `FAllowRemoteImages`。書く：`FAllowRemoteImages` に覚え、`Preview` があればそこへも入れる。`Preview := P` を選んだとき（実行時・.lfm の読み込みの後）、`FAllowRemoteImages` を P に入れる。1 つの TCPreview を複数のエディタで使うときは、あとから書いた値になる。
- TCPreview の `Splitter` の色は、TCPreview が表示元の Theme に合わせて付ける（`TCPreview_Design.md` 4.4）。
- `.md` へのリンクは、TCPreview の `OnOpenMarkdown` が無ければ、表示元のエディタの `OpenFile`。

## 10. ミニマップ（TCsMinimap）

最後に作る（17章）。

### 10.1 作り

- `TCsMinimap = class(TCustomControl)`。TCsEditor の右端（`alRight`）に 1 つ。見えているタブの本文を描く。
- 幅は 120（96dpi のとき。`Scale96ToForm` で倍率に合わせる）。
- `Minimap`（既定 `False`）で `Visible` を切り替える。全タブで共通。`Ctrl+Shift+M`・右クリックのメニュー・標準アクションでも切り替わる。

### 10.2 描き方（Monaco の「ブロック」の描き方）

| 項目 | 値（96dpi。倍率に合わせて大きくする） |
|---|---|
| 1 行の高さ `R` | 2px |
| 1 文字の幅 | 1px（全角の文字は 2px）。タブは `TabSize` 文字 |
| 左の余白 | 2px |
| 文字の形 | 空白以外の文字の所に、高さ `R − 1`・幅 1 文字の四角を塗る（文字そのものは描かない） |
| 色 | 字句の色（その行の色分け）。色分けが無ければ本文の文字色 |
| 背景 | 本文の背景色（`syn.Color`） |
| 描かない所 | 幅を越えた文字 |

**字句の色の取り方**（`TCsSynEdit` の中で行う。中の部品の protected の本文に触れるため）

- そのタブの色分け（`Highlighter`）の `CurrentLines` を、そのタブの本文にしてから、`StartAtLineIndex(行 − 1)` で行の頭から、`GetEol` まで `GetTokenEx`・`GetTokenAttribute`・`Next` でたどる。字句の色は属性の `Foreground`（`clNone` なら本文の文字色）。

**どの行を描くか**

- 行数 `N`、ミニマップに入る行数 `M = ClientHeight div R`、エディタの見えている行数 `V = syn.LinesInWindow`、エディタの先頭の行 `T = syn.TopLine`。
- `N <= M` なら、1 行目から描く（`O = 1`）。
- `N > M` なら、エディタの位置に比例して描き始めの行を決める：`O = 1 + Round((T − 1) × (N − M) ÷ Max(1, N − V))`（`1〜N − M + 1` に収める）。
- 描くのは `O` から `M` 行だけ（大きなファイルでも、描く量は画面の分だけ）。

**見えている範囲の印（スライダー）**

- マウスがミニマップの上にある間だけ、エディタの見えている範囲（`T〜T + V − 1` 行）に、半透明の四角を重ねる（Monaco の既定と同じ）。
- 色：背景に #797979 を 20% 混ぜた色。マウスを乗せているとき 35%、ドラッグ中 50%。

### 10.3 操作

| 操作 | 動き |
|---|---|
| スライダーの外をクリック | その行がエディタの真ん中に来るようにスクロール（`TopLine := 行 − V div 2`） |
| スライダーをドラッグ | ドラッグした量に合わせてスクロール：`dy` ピクセルを `dy × (N − V) ÷ Max(1, (Min(N, M) − V) × R)` 行として `TopLine` に足す（スライダーをミニマップの端から端まで動かすと、文書の端から端まで動く）。`N <= V` なら動かない |
| ホイール | エディタと同じスクロール |

### 10.4 描き直す時

- 描いた絵を `TBitmap` に覚え、`Paint` ではそれを写してスライダーを重ねる。
- 絵を作り直すのは：見えているタブの切り替え、本文の変更（100 ミリ秒待ってまとめる）、エディタのスクロール（`scTopLine`）、配色・`TabSize`・大きさの変更。
- 折り返しは考えない（文の行で描く）。

### 10.5 縦のスクロールバー（ミニマップを出している間）

並びを TCMonacoEditor と同じ「本文｜ミニマップ｜縦のスクロールバー」にする（縦の仕切りが 1 本に見える）。

| 項目 | 処理 |
|---|---|
| 部品 | `FVBar: TScrollBar`（`Kind := sbVertical`、`TabStop := False`）。TCsEditor の右端（`alRight`）。ミニマップと同じく実行時だけ作る |
| 出す・隠す | `Minimap = True`：`FVBar.Visible := True`、全タブの中の部品の `ScrollBars := ssAutoHorizontal`（中の部品の縦のスクロールバーを隠す）。`False`：`FVBar.Visible := False`、全タブの `ScrollBars := ssAutoBoth`（今まで通り）。新しいタブ・移してきたタブにも同じ値を入れる（5.2） |
| 並び | `alRight` の 2 つは位置の順に並ぶので、出すときに `FMinimap.Left := 0`・`FVBar.Left := Width` にして、スクロールバーを一番右にする |
| 値 | 見えているタブの中の部品の、表示の行（折り返し・折りたたみの後の行）で合わせる。`Min := 1`、`PageSize := LinesInWindow`、`Max := 表示の行数 + LinesInWindow − 1`（`eoScrollPastEof` があるので、最後の行が一番上まで来る。中の部品のスクロールバーと同じ）、`Position := TopView`。表示の行数は `ViewedTextBuffer.ViewedCount`、表示の先頭の行は `TopView`（どちらも中の部品の protected。`TCsSynEdit` の中で読む） |
| 合わせ直す時 | `scTopLine`・`scLinesInWindow`（中の部品の `OnStatusChange`）、本文の変更（`InnerChange`）、タブの切り替え、配色・文字の大きさ・折り返しの変更、TCsEditor の大きさの変更 |
| 動かしたとき | `FVBar.OnScroll`：見えているタブの中の部品の `TopView := Position`。合わせ直している間（`FUpdatingBar`）は何もしない |
| 色 | 中の部品のスクロールバーと同じ（4.7。ダークは `DarkMode_Explorer`） |

## 11. 標準アクション

TCMonacoEditor の 25 個と同じ（表示名・既定のショートカット・動き・使えるとき・チェック）。名前の頭を `TCsEditor` にする。

| No | アクション | 動き |
|---|---|---|
| 1 | `TCsEditorNew` | `NewPage` |
| 2 | `TCsEditorOpen` | `OpenDialog`（無ければ内蔵）で選んで `OpenFile`。タブありなら複数選べる |
| 3 | `TCsEditorSave` | `Save` |
| 4 | `TCsEditorSaveAs` | `SaveAs` |
| 5 | `TCsEditorClose` | `Close` |
| 6 | `TCsEditorPrint` | `Print`（使えるとき：`CanPrint`） |
| 7 | `TCsEditorSaveAll` | `SaveAll` |
| 8 | `TCsEditorCloseAll` | `CloseAll` |
| 9 | `TCsEditorUndo` | `Undo` |
| 10 | `TCsEditorRedo` | `Redo` |
| 11 | `TCsEditorCut` | `Cut` |
| 12 | `TCsEditorCopy` | `Copy` |
| 13 | `TCsEditorPaste` | `Paste` |
| 14 | `TCsEditorSelectAll` | `SelectAll` |
| 15 | `TCsEditorDuplicateLine` | `DuplicateLine` |
| 16 | `TCsEditorDeleteToEnd` | `DeleteToEnd` |
| 17 | `TCsEditorDeleteToStart` | `DeleteToStart` |
| 18 | `TCsEditorFind` | `ShowFindDialog` |
| 19 | `TCsEditorFindNext` | `FindNext` |
| 20 | `TCsEditorFindPrev` | `FindPrev` |
| 21 | `TCsEditorMinimap` | `Minimap` を切り替える（チェック `Minimap`） |
| 22 | `TCsEditorPreview` | `ShowPreview` を切り替える（チェック `ShowPreview`。使えるとき：`Preview <> nil`） |
| 23 | `TCsEditorLineNumbers` | `LineNumbers` を切り替える（チェック `LineNumbers`） |
| 24 | `TCsEditorWordWrap` | `WordWrap` を切り替える（チェック `WordWrap`） |
| 25 | `TCsEditorRemoteImages` | `AllowRemoteImages` を切り替える（チェック `AllowRemoteImages`。使えるとき：`Preview <> nil`） |

- 元のクラス `TCsEditorAction`・`TCsEditorToggleAction` は、TCMonacoEditor の `TCMEditorAction`・`TCMEditorToggleAction`（`TCMonacoEditor_Design.md` 8章）と同じ作り。対象は `CsActiveEditor(フォーム)`。
- アクションリストエディタのカテゴリは `CX TCsEditor`（TCMonacoEditor の `CX` と分ける。同じ表示名が 2 つ並ぶと見分けられないため）。

## 12. 登録とアイコン

**登録（`uCXReg.pas`）**

- uses に `uCsEditor`・`uCPreview` を足す。
- `RegisterComponents('CX', [..., TCsEditor, TCsFindDialog, TCPreview])`。
- `RegisterActions('CX TCsEditor', [11章の 25 個], nil)`（並びは 11章の表の順）。
- initialization に `{$I cseditor_icon.lrs}` を足す。

**アイコン**

描く前に、見本を見せて確認をもらう。

| 部品 | 絵 |
|---|---|
| `TCsEditor` | 上に 2 つのタブ（左が表示中）、その下に、左に細い縦の帯（行番号）、右に長さの違う横線 3 本（文字の行） |
| `TCPreview` | 文書（上に太い線 1 本＝見出し、その下に細い線 3 本）、右下に小さな目 |
| `TCsFindDialog` | ダイアログの枠の中に「A→B」。矢印は緑 |
| `TCMFindDialog`（差し替え） | ダイアログの枠の中に「A→B」。矢印は青 |

- 虫眼鏡は使わない（今後の「検索用の部品」のために取っておく）。
- 大きさとリソース名：24×24・36×36・48×48 の PNG（32 ビット、透明あり）。名前はクラス名（小文字）、`_150`、`_200`（例：`tcseditor.png`・`tcseditor_150.png`・`tcseditor_200.png`）。線の太さ・色は `CPageControl_Design.md` 9.1 と同じ決まり（線は濃い灰色、色の所は青。`TCsFindDialog` の矢印だけ緑）。
- 4 つ × 3 つの PNG から `cseditor_icon.lrs` を作り（`lazres`）、`cxdsgn.lpk` に足す。元の PNG は cxdsgn の icons フォルダーに置く。
- `cx_icons.lrs` から `TCMFindDialog`・`TCMFindDialog_150`・`TCMFindDialog_200` を外す（同じ名前のリソースが 2 つあると、どちらが使われるか決まらないため）。

## 13. TCMonacoEditor と違う所

| 項目 | TCMonacoEditor | TCsEditor |
|---|---|---|
| 編集の部分 | Monaco（WebView2） | TCSynEdit |
| 本文の持ち方 | Monaco が正、Pascal は写し（約 0.1 秒のずれ） | 中の部品だけ（ずれなし） |
| `OnChange` | 入力が止まって約 0.1 秒後 | 本文が変わるたび（コードで変えたときも） |
| `OnKeyDown` | ショートカット用のキーだけ | 普通の文字のキーも来る |
| フォームの `KeyPreview` | エディタにフォーカスがあると効かない | 効く |
| `Lines` | ない | ある（TStrings） |
| `Font` | ない（`FontSize` だけ） | ある。`FontSize` は `Font.Size` と同じもの |
| プレビュー | 中に持つ | TCPreview（別の部品）。`Preview` でつなぐ |
| プレビューの設定 | `ed.〜`（`PreviewFontSize` など） | `ed.Preview.〜`（`FontSize` など）。`AllowRemoteImages` だけは `ed.AllowRemoteImages` も同じ |
| `Monaco`・`JapaneseUI`・`MonacoPath` | ある | ない（代わりに `SynEdit`） |
| `Monaco.PopupMenu` | ある | `ContextMenu` |
| 色分けできる言語 | 取説 9.2 の表のすべて | 表のうち powershell・yaml・go は色分けなし（SynEdit に色分けがない。plaintext はどちらも色分けなし） |
| `OnOpenMarkdown` | `ed.OnOpenMarkdown` | TCPreview の `OnOpenMarkdown` |
| `F1` のコマンドパレット・マルチカーソル | ある | ない |
| スクロールの同期 | 行の中の位置まで | 行単位 |
| ミニマップ | Monaco のもの | 自分で描く（10章。折り返しは考えない） |
| 同じファイル | 1 つのエディタの中で 1 つ | 同じフォームの TCsEditor の間で 1 つ（4.12） |
| 同じフォームの別のエディタへタブを移す | しない | する（4.12） |
| 標準アクションのカテゴリ | `CX` | `CX TCsEditor` |

## 14. 決めていること

| 項目 | 決定 |
|---|---|
| 名前 | TCSynEdit のタブ化版は `TCsEditor`、ページは `TCsPage`、検索・置換ダイアログは `TCsFindDialog`、標準アクションは `TCsEditor…` |
| 使い方 | TCMonacoEditor に合わせられる所はすべて同じ（名前・動き・既定値）。新規は `NewPage` |
| タブ | ATTabs。見た目・動きは TCMonacoEditor と同じ |
| 1 タブの中身 | TCSynEdit を継承した `TCsSynEdit` を 1 つ |
| `Lines`・`Text` | TSynEdit と同じく両方持つ |
| `Font`・`FontSize` | `Font` を持ち、`FontSize` は `Font.Size` と同じもの。既定は BIZ UDGothic、14 ポイント |
| 配色 | `Theme`（`ctAuto`・`ctLight`・`ctDark`）。中の部品は `csVSLight`・`csVSDark`。色は TCMonacoEditor（VS Code）と同じ |
| 色分け | 拡張子と言語の対応は TCMonacoEditor と同じ。色分けは TCSynEdit が持つもの（`TCSynEdit_Design.md` 7.2） |
| 括弧の対応 | `MatchBrackets` 1 つで、`( )`・`[ ]`・`{ }`（Pascal では `{ }` はコメントなので対象外）と、キーワードの組（`begin`／`end` など）・タグの組 |
| `begin` の後ろに `end` を足す | しない |
| 折り返し | `WordWrap`（`TLazSynEditLineWrapPlugin`） |
| 検索・置換 | TCMonacoEditor と同じダイアログを `TCsFindDialog` として作る。`TCMFindDialog` は使わない・変えない |
| プレビュー・印刷 | TCPreview。`ShowPreview` で表示。印刷は TCPreview（PDF 保存も） |
| エディタを並べる | TCsEditor を複数貼る。タブは同じフォームの別の TCsEditor へドラッグで移せる。同じファイルは 1 か所だけ |
| ミニマップ | 自分で描く（Monaco と同じ見え方）。最後に作る |
| 文字コード | TCMonacoEditor と同じ（UTF-8・UTF-8 BOM・UTF-16 LE/BE・CP932 を判定して読み、同じ文字コードで書く） |
| 改行コード | 読み込んだときの CRLF・LF を保つ（混在は保たない） |
| ファイルを押さえる | しない |
| 同じフォームに TCMonacoEditor と TCsEditor | 置かない（想定しない） |

**作らないもの**

| 項目 | 理由・代わり |
|---|---|
| マルチカーソル（`Ctrl+D` など）・コマンドパレット（`F1`） | 要らない |
| `begin`／`end` の自動の補完 | 要らない |
| 左右で同じファイルを同時に編集する（SynEdit のテキストの共有） | 開かずに、開いている方へ切り替える |
| Markdown の見出しの折りたたみ | 作らない |
| 部品の中で画面を分ける | TCsEditor を複数貼る |
| 正規表現の検索 | TCMonacoEditor と同じく対応しない |
| タブの帯へのファイルのドロップ | TCMonacoEditor と同じく対応しない |
| SynEdit の印刷（`TSynEditPrint`） | 印刷は TCPreview（Printer4Lazarus を足さない） |

## 15. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| Ctrl+S・F12・Shift+F10 が TCSynEdit の動き（文字コードなしの保存・行番号）になる | `TCsSynEdit.KeyDown` で先に受けているか（6.1） |
| フォームのショートカットが効かない・二重に動く | 6.1 の順番、6 のショートカットの探し方 |
| SynEdit の既定のキー（Ctrl+Y で行が消える など）が動く | `Keystrokes.Clear` と 5.5 の表 |
| 行の後ろの空白が消える | `Options` に `eoTrimTrailingSpaces` が入っていないか（5.2） |
| ファイルを開くと色が既定に戻る | TCSynEdit 1.1 の `SetLanguage` の `ApplyEditStyle`。`TCsSynEdit.ApplyEditStyle` の override |
| カーソル行・選択の色が設定と違う | 5.3 の順番（`inherited` の後で入れているか） |
| フォーカスを外すと選択が見えない | `HideSelection := False`、`DoExit` の `HitColor`（5.3） |
| 保存した文字コード・改行がおかしい | 4.3 の判定、`FLineBreak`、`EncodeText` |
| 最後の改行が消える・増える | 4.2 の `SetBodyText` と `Text` のつなぎ方 |
| 位置（`SelStart`・桁）がずれる | 6.5 の UTF-16 の変換 |
| OS のテーマを切り替えても変わらない | 受け口のウィンドウがトップレベルか、`WM_SETTINGCHANGE` の `'ImmersiveColorSet'`（4.7） |
| プレビューが別のエディタの内容のまま | `DoEnter` の `SetSource`（9章） |
| タブを別のエディタへ移しても何も起きない・落ちる | `FindControlAtPosition` とたどり方、`AsyncMoveTab` で後から行っているか（4.12） |
| 移したタブのメニュー・色がおかしい | 4.12 の手順 2・4 |
| 分離・結合が TCMonacoEditor と混ざる | 4.11.2 の名前（環境変数・目印・受け口のクラス名・`dwData`） |
| ミニマップの色がずれる | 色分けの `CurrentLines` と `StartAtLineIndex`（10.2） |
| スクロールバーがダークにならない | 4.7 の `SetWindowTheme`。中の部品の `CreateWnd` で当て直しているか |
| フォントを大きくするとタブの文字がはみ出す | 4.6 の `FTabs.ParentFont := False` |
| ミニマップが重い | 描くのは画面の分だけか、本文の変更で 100 ミリ秒待っているか（10.2・10.4） |

## 16. この版の変更

コードを作るための手順。取説には入れない。

| No | ファイル | 変更 |
|---|---|---|
| 1 | `uCsEditor.pas` | 新しく作る（この設計書のすべて） |
| 2 | `uCPreview.pas` | 新しく作る（`TCPreview_Design.md`） |
| 3 | `cSynedit.pas` | `TCSynEdit_Design.md` 11章 |
| 4 | `cx.lpk` | `../source/uCsEditor.pas`（UnitName `uCsEditor`）・`../source/uCPreview.pas`（UnitName `uCPreview`）を足す |
| 5 | `source/design/uCXReg.pas` | 12章 |
| 6 | `cseditor_icon.lrs`（新しく作る）・`cxdsgn.lpk` | 12章 |
| 7 | `cx_icons.lrs` | `TCMFindDialog` の 3 つを外す（12章） |
| 8 | `uCmonacos.pas`・`uCmmonacoview.pas`・`uCmdpreview.pas`・`CMonacoTabs.pas`・`CMonacoPreview.pas`・`CMonacoFindDlg.pas`・`CMonacoActions.pas`・`preview.html` | 変更なし |

**1.1（2026-11-03）**：1.0 の確認テストの結果を受けた変更。

| No | 章 | 1.0 | 1.1 | 理由 |
|---|---|---|---|---|
| 1 | 5.1 | 中の部品の `StatusChanged` を override して受ける | 中の部品のイベント `OnStatusChange`・`OnChangeUpdating`・`OnChange` で受け、`OnChange` は `ChangeStamp` で 1 つの変更につき 1 回にする | override では取りこぼす。1 文字の入力で `OnChange` が 2 回来た |
| 2 | 6.1 | フォームのショートカットは `IsShortcut` | メニュー・ActionList を自分で探す（TCMonacoEditor と同じ） | `IsShortcut` は Ctrl・Shift を本物のキーボードから読む |
| 3 | 6.4 | `DeleteToEnd`・`DeleteToStart` は選択を無視してカーソルから | 選んでいれば、選択の始まりから末尾・先頭から選択の終わり | `SetSelection` のあとカーソルは選択の終わりにある |
| 4 | 4.7 | スクロールバーは Theme で変わらない | ダークのとき `DarkMode_Explorer` を当てる | スクロールバー・ミニマップとの間の帯の色が変わらなかった |
| 5 | 4.6 | タブの文字は `Font` に合わせる | タブは `ParentFont := False`（普通の大きさ） | フォントを大きくするとタブの文字がはみ出した |
| 6 | 3.2・9章・11章 | `AllowRemoteImages` は `ed.Preview` だけ | `ed.AllowRemoteImages` を足す（TCMonacoEditor と同じ） | TCMonacoEditor と同じにする |
| 7 | 3.2 | `OpenFile(const AFileName: string)` | `OpenFile(const AFileName: string = '')` | 名前を省略して書けなかった（TCMonacoEditor と同じにする） |
| 8 | `TCPreview_Design.md` 4.4 | `Splitter` の色は付けない | 表示元の Theme に合わせて付ける | Theme を変えても Splitter の色が変わらなかった |
| 9 | 10.5 | ミニマップは中の部品の縦のスクロールバーの右 | ミニマップを出している間は、中の部品の縦のスクロールバーを隠し、TCsEditor のスクロールバーをミニマップの右に置く | TCMonacoEditor と並びが違い、縦の仕切りが 2 本に見えた |
| 10 | 4.1 | タブを切り替えても、フォーカスは動かさない | 前の本文にフォーカスがあれば、新しい本文へ移してから前を隠す（タブを閉じて隣を見せるときも同じ） | Ctrl+Tab のあとフォーカスが無くなり、毎回クリックが要った |
| 11 | 3.2・5.2 | `Font.Assign` で文字色も渡す | 文字色は渡さない（配色の色のまま） | フォントを変えると、ダークでも文字が黒になった |

## 17. 作る順番

| 順 | 中身 | 確かめること |
|---|---|---|
| 1 | TCSynEdit 1.1（配色・言語・Markdown） | 拡張子と配色を切り替えても、左端の欄（行番号・折りたたみ）・カーソル行・括弧の対応の色が崩れないか（前に色がうまくいかなかった所） |
| 2 | TCsEditor（タブ・ファイル・文字コード・キー・右クリック・検索・置換・標準アクション） | TCMonacoEditor の取説の動きと同じか |
| 3 | TCPreview | 表示元の切り替え・印刷・スクロールの同期 |
| 4 | タブの分離・結合・別のエディタへ移す | |
| 5 | ミニマップ | |
| 6 | アイコン・登録 | 見本を見せてから描く |
