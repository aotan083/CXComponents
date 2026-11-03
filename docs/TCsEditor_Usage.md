# TCsEditor 取扱説明書

作者: aotan083
日付: 2026-11-03
版: 1.0

---

## 1. 概要とクラス

フォームに貼るだけで使える、タブ付きのテキストエディタです。1 つのタブに 1 つの TCSynEdit（SynEdit）を持ちます。使い方（名前・動き・既定値）は TCMonacoEditor と同じで、編集の部分が WebView2 ではなく SynEdit なので、軽く・速く動きます。設定はすべてオブジェクトインスペクタで行い、アプリ側でコードを書く必要はありません。

```
+---------+---------+-----+-------------------+--+---+
| a.md  × | b.pas × |  +  |                   |  |   |
+---------+---------+-----+-------------------+--+---+
| # 見出し                                     |▒▒|   |
| 本文…                                        |▒ |   |
|                                             |▒▒| ↕ |
|    TCSynEdit（タブごとに 1 つ）               |  |   |
+---------------------------------------------+--+---+
                                    ミニマップ ↑   ↑ スクロールバー
```

- 1 つのフォームに何個でも貼れる。並べるときは、アプリが TSplitter で区切る。
- イベントは、設定しなくても動く（設定しないときは、部品が既定の動きをする。6.2）。
- 文字コード（UTF-8・UTF-16・Shift_JIS）を判定して読み、同じ文字コードで保存する。改行コード（CRLF・LF）も保つ。
- 拡張子から言語を決めて色分けする。
- プレビュー（Markdown・コード）と印刷（PDF 保存）は、別の部品 TCPreview で行う（11章）。
- フォームを閉じるとき、保存していない文書を自動で確認する。
- 標準アクション（25 個）をメニュー・ボタンに割り当てられる（12章）。
- タブをウィンドウの外へドラッグすると、別のウィンドウで開く。同じフォームの別の TCsEditor へドラッグすると、そのタブを移す（9.9・9.10）。

| 項目 | 内容 |
|---|---|
| Lazarus | 5.0 以降 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |
| 実行に必要なもの | なし（プレビューを使うときは、TCPreview の取説 2章のファイル） |
| 使う外部パッケージ | SynEdit（Lazarus に入っている）、ATFlatControls（タブ） |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCsEditor` | `uCsEditor` | cx | `TCustomPanel` | フォームに貼るエディタ本体 |
| `TCsPage` | `uCsEditor` | cx | `TObject` | タブ 1 枚（`ed.Pages[n]` で取る。4章）。作るのも消すのも TCsEditor が行う |
| `TCsFindDialog` | `uCsEditor` | cx | `TComponent` | 検索・置換ダイアログ（非表示の部品）。自分で制御したいときだけ貼る（10章） |
| `TCsEditorNew` ほか 24 個 | `uCsEditor` | cx | `TAction` | 標準アクション（12章） |
| `TCPreview` | `uCPreview` | cx | `TCustomPanel` | プレビュー（別の取説 `TCPreview_Usage.md`） |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCMEncoding` | `uCsEditor` | 文字コード。`ceUTF8`・`ceUTF8BOM`・`ceUTF16LE`・`ceUTF16BE`・`ceCP932` |
| `TCMFindOption`・`TCMFindOptions` | `uCsEditor` | 検索のオプション。`foMatchCase`（大文字小文字を区別）・`foWholeWord`（単語単位）・`foLoop`（端まで行ったら反対側から） |
| `TCMTheme` | `uCsEditor` | 配色。`ctAuto`・`ctLight`・`ctDark` |
| `TCMSelectionColorStyle` | `uCsEditor` | 選択範囲の色の組。`scStandard`・`scBlue`・`scAmber`・`scPurple`・`scCustom` |

| 関数 | ユニット | 中身 |
|---|---|---|
| `CsActiveEditor(AForm: TCustomForm): TCsEditor` | `uCsEditor` | そのフォームで最後にフォーカスされたエディタ。まだどれもフォーカスされていなければ最初のエディタ。無ければ nil |
| `CsOsIsDark: Boolean` | `uCsEditor` | OS の配色がダークか |

- フォームに置くと、uses に `uCsEditor` が自動で入る。アプリの uses は、これだけでよい（よく使う型は `uCsEditor` が出し直している）。
- フォームに置くと、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。
- 同じフォームに TCMonacoEditor と TCsEditor を一緒に置くことは想定していない。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCsEditor をフォームに置き、`Align = alClient` にする。
2. 実行する。

- 起動直後に、空の無題のタブが 1 枚ある。
- IDE の上（設計時）では中のエディタを作らない。薄い枠と部品の名前だけが出る。
- プレビューを使うときは、TCPreview を置いて `Preview` で選ぶ（11章）。

**最初の状態**

| 項目 | 値 |
|---|---|
| フォント | BIZ UDGothic、14 ポイント |
| 配色（`Theme`） | `ctAuto`（OS の配色に合わせる） |
| 言語 | `DefaultLanguage`（pascal） |
| 折り返し | あり |
| 行番号 | なし（`F11` で出す） |

- 最初のフォントは BIZ UDGothic。入っていない環境では、`Font` を設定する。

## 3. 考え方

この説明書では、フォームに貼ったエディタを `ed` と書く。

**1. 見えているタブは `ed`、裏のタブは `ed.Pages[n]`**

| 書き方 | 対象 |
|---|---|
| `ed.〜` | 見えているタブ（`ActiveIndex` のタブ）と、エディタ全体 |
| `ed.ActiveIndex := n` | 見えるタブを切り替える（画面も切り替わる）。番号は 0 から |
| `ed.Pages[n].〜` | 画面を切り替えずに、n 番のタブの中身・ファイルを触る。n が見えているタブでもよい（`ed.〜` と同じ結果） |

- `ed.Pages[n]` にあるものは、すべて `ed` にも同じ名前・同じ動きである（4章）。
- `ed` にしかないものは、タブの集まりの操作（5章）と、画面の上での操作（6.1）だけ。選択・カーソル・編集・検索・印刷は、見えているタブにしかないため。裏のタブに行うときは、先に `ActiveIndex` で切り替える。
- 名前は、TMemo・TSynEdit と同じものを使う（`Text`・`Lines`・`SelText`・`SelLength`・`Modified`・`LoadFromFile` など）。

**2. 1 つのタブ＝1 つのページ**

- ページ＝タブ 1 枚＋本文 1 つ＋ファイル名。無題（まだ保存していない）も 1 つのページ。
- 同じファイルを、2 つのタブで開くことはない。同じフォームの別の TCsEditor とも、同じファイルを同時に開かない（開こうとすると、開いている方へ切り替わる）。
- タブの番号は、左から 0、1、2…。

**3. タブは常に 1 枚以上**

- 最後の 1 枚を閉じると（`ed.Close`・`ed.CloseAll`・タブの［×］）、空の無題が 1 枚できる。
- `MultiDocument = False` のときは、タブは常に 1 枚（表示しない）。閉じると、中身が空の無題になる（9.1）。

**4. タブの表示は、ページの状態から自動で決まる**

| タブの表示 | 決まり方 |
|---|---|
| タイトル（`Caption`） | ファイル名の、名前の部分だけ（`C:\docs\a.md` → `a.md`）。無題なら「無題」 |
| 変更した印（` *`） | `Modified` が `True` のとき付く（例：`a.md *`）。`Caption` には含まない |
| アイコン | 拡張子から決まる（無題はテキストのアイコン。9.3） |
| ヒント | ファイル名のフルパス |
| 浮き上がって見えるタブ | `ActiveIndex` のタブ |

- タブの文字は、普通の大きさのまま（`Font`・`FontSize` を大きくしても変わらない）。

**5. 操作ごとの変わり方**

| 操作 | 本文 | ファイル名 | タブ | ` *` | ディスク |
|---|---|---|---|---|---|
| `ed.NewPage` | 空 | 空 | 1 つ増える（「無題」）。見えるタブになる | なし | 何もしない |
| `ed.OpenFile(名前)` | ファイルの内容 | その名前 | 1 つ増える。見えるタブになる（同じファイルを開いていれば、そのタブに切り替えるだけ） | なし | 読む |
| `ed.LoadFromFile(名前)` | ファイルの内容に入れ替わる（変更は聞かずに捨てる） | その名前に変わる | 増えない | なし | 読む |
| `ed.Clear` | 空 | 空（無題になる） | 増えない | なし | 何もしない |
| `ed.Text := s` | 置き換わる（Undo の履歴は消える）。今と同じ本文なら何もしない | 変わらない | 変わらない | 付く（今と同じ本文なら付かない） | 何もしない |
| `ed.SelText := s` | 選択部分が置き換わる（Undo 1 回で戻る） | 変わらない | 変わらない | 付く | 何もしない |
| 人が入力する | 変わる | 変わらない | 変わらない | 付く | 何もしない |
| `ed.Save` | 変わらない | 変わらない（無題なら、聞いた名前） | 変わらない（無題なら、その名前） | 消える | 書く |
| `ed.SaveAs(名前)` | 変わらない | その名前 | タイトル・アイコンが変わる | 消える | 書く（元のファイルは残る） |
| `ed.Close` | 消える | 消える | 消える（隣のタブが見えるタブになる。最後の 1 枚なら空の無題ができる） | ― | 何もしない |
| `ed.ActiveIndex := n` | n 番が表示される | ― | n 番が見えるタブになる | ― | 何もしない |

`ed.Pages[n].〜` の同じ名前の操作も、対象が n 番のタブになるだけで、変わり方は同じ（画面は切り替わらない）。

## 4. タブの中身とファイル（ed・ed.Pages[n]）

| 名前 | 型・引数 | 読み書き | 中身 |
|---|---|---|---|
| `Text` | `string` | 読み・書き | 本文。書くと内容だけ置き換える（ファイル名はそのまま。Undo の履歴は消える。ファイルには書かない）。書くと ` *` が付く。今と同じ本文を書いたときは、何もしない。行は、そのタブの改行コードでつながる。最後が改行で終わる本文は、最後に空の行を 1 つ持つ |
| `Lines` | `TStrings` | `ed`：読み・書き。`ed.Pages[n]`：読み | 本文（行ごと）。中のエディタの `Lines` そのもの。`ed.Lines := L` で、見えているタブの本文を `L` の内容にする。オブジェクトインスペクタで入れた内容は、1 枚目のタブに入る |
| `Caption` | `string` | 読み | タブのタイトル。ファイル名の名前の部分だけ。無題なら「無題」。` *` は含まない |
| `FileName` | `string` | 読み | ファイルのフルパス。無題なら ''。名前を変えるときは `SaveAs` |
| `Modified` | `Boolean` | 読み | 保存していない変更があるか（タブの ` *`） |
| `Encoding` | `TCMEncoding` | 読み・書き | 文字コード。読み込んだときに決まり、保存するときに使う |
| `Language` | `string` | 読み・書き | 色分けの言語（'pascal'、'markdown' など。9.2）。'' を書くと `DefaultLanguage` |
| `LineCount` | `Integer` | 読み | 行数。空の文書は 1 |
| `SynEdit` | `TCSynEdit` | 読み | そのタブの中のエディタ（上級者向け。15.12）。`OnChange`・`OnStatusChange`・`PopupMenu` は部品が使うので変えない |
| `Index` | `Integer` | 読み | `ed.Pages[n]` だけ。今のタブの番号（閉じたページは -1） |
| `LoadFromFile` | `const AFileName: string`、戻り値 `Boolean` | ― | 内容を捨てて、ファイルを読み込む。変更があっても聞かずに捨てる。タブは増えない。読み込めたら `True`。ファイルが無い・読めないときは、何も変えず `False`（`OnError`）。別のタブ・同じフォームの別の TCsEditor で開いているファイルなら、読み込まず `False`（`OnError`） |
| `Save` | 戻り値 `Boolean` | ― | 上書き保存。無題なら名前を聞く（`OnNeedFileName`、設定しないときは保存ダイアログ。裏のタブでも切り替えずに聞く）。保存できたら `True`。キャンセル・失敗なら `False` で、` *` は消えない。失敗は `OnError` |
| `SaveAs` | `const AFileName: string = ''`、戻り値 `Boolean` | ― | 別の名前で保存する。名前を省くと保存ダイアログで聞く。保存したあとは、タブのタイトル・アイコン・言語もその名前に合わせる。元のファイルはディスクに残る。別のタブで開いているファイルの名前なら保存せず `False`（`OnError`）。名前を指定したときは、同じ名前のファイルがあれば聞かずに上書きする（ダイアログなら「上書きしますか？」と聞く） |
| `Clear` | ― | ― | 内容を空にし、ファイル名も消して無題にする。変更があっても聞かずに捨てる。タブは残る。言語は `DefaultLanguage`、文字コードは UTF-8、改行コードは CRLF |
| `Close` | `Force: Boolean = False`、戻り値 `Boolean` | ― | 閉じる。変更があれば聞く（9.5）。`Force = True` なら聞かずに捨てる。閉じたら `True`、キャンセルなら `False`。見えているタブを閉じたら、隣のタブが見えるタブになる。最後の 1 枚なら、空の無題が残る。`MultiDocument = False` なら、閉じずに中身を空にする（9.1）。ファイル自体は消さない |

**`Pages[n]` の決め事**

- ページは、エディタが作って管理する。アプリ側で `Create`・`Free` はしない。
- 取り出したページ（例：`P := ed.Pages[2]`）は、タブを並べ替えても、同じタブを指し続ける。
- 閉じたページを使ったとき、読む値は空（`Caption`・`FileName`・`Text` は ''、`Modified` は `False`、`LineCount` は 0、`SynEdit` は nil）、操作は何もしない（`Boolean` を返すものは `False`）。落ちない。
- `Pages[n]` の番号が範囲の外なら、例外（`EListError`）。
- `MultiDocument = False` のときは、ページは常に 1 つ（`Pages[0]`）。

## 5. タブの集まり（ed）

| 名前 | 型・引数 | 読み書き | 中身 |
|---|---|---|---|
| `OpenFile` | `const AFileName: string = ''`、戻り値 `Integer` | ― | 名前を省くと、開くダイアログ（`OpenDialog`、設定しないときは内蔵のもの）を出し、選んだファイルを開く。キャンセルなら何もせず -1。名前を指定したときは、新しいタブでファイルを読み込んで開き、見えるタブにする。文字コードを判定し、拡張子から言語を決める。同じファイルを開いていれば、そのタブに切り替えるだけ（読み直さない）。同じフォームの別の TCsEditor で開いていれば、そのエディタのそのタブに切り替えて -1。起動直後の無題のタブが 1 つだけでも、そこには読み込まない。戻り値はタブの番号。読めないファイルなら例外（タブは残さない）。`MultiDocument = False` なら 9.1 |
| `NewPage` | 戻り値 `Integer` | ― | 空の無題のタブを右に足して、見えるタブにする。戻り値はタブの番号。`MultiDocument = False` なら 9.1 |
| `SaveAll` | ― | ― | 変更のあるタブを、すべて上書き保存する（無題は、そのタブに切り替えてから名前を聞く） |
| `CloseAll` | `Force: Boolean = False`、戻り値 `Boolean` | ― | すべて閉じる。変更があれば聞く。`Force = True` なら聞かずに捨てる。閉じ終わると、空の無題が 1 枚残る。途中でキャンセルされたら `False`（残りはそのまま） |
| `CanCloseAll` | 戻り値 `Boolean` | ― | 保存していないタブを確認するが、閉じはしない。キャンセルされたら `False` |
| `FindPage` | `const AFileName: string`、戻り値 `Integer` | ― | そのファイルを開いているタブの番号。なければ -1。大文字・小文字は区別しない |
| `MovePage` | `AFromIndex, AToIndex: Integer` | ― | タブの並び順を変える。中身は変わらない |
| `ActiveIndex` | `Integer` | 読み・書き | 見えているタブの番号（0 から）。書くと、そのタブに切り替わる。範囲の外・同じ番号は何もしない。前のタブの本文にフォーカスがあったときは、新しいタブの本文にフォーカスが移る |
| `PageCount` | `Integer` | 読み | タブの数（常に 1 以上） |
| `Pages[AIndex]` | `TCsPage` | 読み | n 番のタブ（4章）。範囲の外は例外 |

## 6. 画面の上での操作とイベント（ed）

### 6.1 プロパティ・メソッド

すべて、見えているタブが対象。

| 名前 | 型・引数 | 読み書き | 中身 |
|---|---|---|---|
| `SelText` | `string` | 読み・書き | 読むと、選択中の文字列（選んでいなければ ''）。書くと、選択範囲をその文字列に置き換える。選んでいなければ、カーソル位置に入れる。'' を書くと、選択範囲を消す。改行は #13・#10・#13#10 のどれを渡しても改行として扱う。Undo 1 回で戻る。置き換えたあとは、置き換えた文字列の後ろにカーソルが来る（選択は外れる）。`ReadOnly` のときは、書いても何も起きない |
| `SelStart` | `Integer` | 読み | 選択の開始位置（選んでいなければカーソル位置）。文書の先頭から 0 始まり、UTF-16 単位（絵文字などは 2）。改行は文書の改行コードの文字数（CRLF は 2、LF は 1）。範囲を選ぶときは `SetSelection` |
| `SelLength` | `Integer` | 読み | 選択の文字数（数え方は `SelStart` と同じ）。0 なら選んでいない |
| `CanUndo` | `Boolean` | 読み | Undo できるか |
| `CanRedo` | `Boolean` | 読み | Redo（やり直し）できるか |
| `GetCursorPos` | `out ALine, AColumn: Integer` | ― | カーソルの位置。行と桁は 1 から。桁は UTF-16 単位 |
| `SetCursorPos` | `ALine, AColumn: Integer` | ― | カーソルを動かす |
| `SetSelection` | `ALine1, AColumn1, ALine2, AColumn2: Integer` | ― | 範囲を選ぶ。カーソルは終わりの位置 |
| `LineText` | `string` | 読み | カーソル行の文字列（改行は含まない）。13章 |
| `LineWords` | `TStrings` | 読み | カーソル行を単語に分けた一覧（0 から数える）。`Free` しない。13章 |
| `LineDelimiters` | `string` | 読み・書き | `LineWords` の区切り文字。コードで設定する。13章 |
| `LineSkipEmpty` | `Boolean` | 読み・書き | `LineWords` に空の単語を入れないか。コードで設定する。13章 |
| `LineQuoteChar` | `Char` | 読み・書き | `LineWords` の引用符。コードで設定する。13章 |
| `Undo` | ― | ― | 元に戻す |
| `Redo` | ― | ― | やり直し |
| `Cut` | ― | ― | 切り取り（クリップボード）。`ReadOnly` なら何もしない |
| `Copy` | ― | ― | コピー（クリップボード） |
| `Paste` | ― | ― | 貼り付け（クリップボード）。`ReadOnly` なら何もしない |
| `SelectAll` | ― | ― | すべて選ぶ |
| `DeleteToEnd` | ― | ― | 選んでいなければ、カーソル位置から文書の末尾までを消す。選んでいれば、選択の始まりから末尾までを消す（選んだ部分も消える）。Undo 1 回で戻る。`ReadOnly` なら何もしない |
| `DeleteToStart` | ― | ― | 選んでいなければ、文書の先頭からカーソル位置までを消す。選んでいれば、先頭から選択の終わりまでを消す。決め事は `DeleteToEnd` と同じ |
| `DuplicateLine` | ― | ― | カーソル行を複製して下へ移る（`Shift+F10` と同じ。複数行を選んでいれば、その行をまとめて複製）。Undo 1 回で戻る。`ReadOnly` なら何もしない |
| `ToggleOverwrite` | ― | ― | 挿入と上書きを切り替える（`Insert` キーと同じ） |
| `Find` | `const S: string; AOptions: TCMFindOptions; AForward: Boolean = True` | ― | 検索して、見つかった所を選ぶ。結果は `OnFindDone` |
| `FindNext` | ― | ― | 直前の検索語で次を検索（`F5`）。検索語がなければ検索ダイアログを開く |
| `FindPrev` | ― | ― | 直前の検索語で前を検索（`Shift+F5`） |
| `Replace` | `const S, R: string; AOptions: TCMFindOptions` | ― | 選んでいる所が S なら R に置き換え、次を検索する。`ReadOnly` なら何もしない |
| `ReplaceAll` | `const S, R: string; AOptions: TCMFindOptions` | ― | すべて置き換える。結果（件数）は `OnReplaceAllDone`。Undo 1 回で戻る。`ReadOnly` なら何もしない |
| `ShowFindDialog` | `const InitialText: string = ''` | ― | 検索・置換ダイアログを開く（`Ctrl+F` と同じ。10章） |
| `SearchText` | `string` | 読み・書き | 直前の検索語 |
| `ReplaceText` | `string` | 読み・書き | 直前の置換語 |
| `SearchOptions` | `TCMFindOptions` | 読み・書き | 直前の検索オプション |
| `CanPrint` | 戻り値 `Boolean` | ― | 印刷できるか（`Preview` を選んでいれば `True`） |
| `Print` | ― | ― | 印刷ダイアログを開く（TCPreview の取説 6.5）。プレビューを出していなければ、印刷の間だけ出す。`Preview` が無ければ何もしない |
| `SetFocus` | ― | ― | エディタにカーソルを置き、入力できる状態にする。今の処理（ボタンのクリック、`OnKeyDown`・`OnReady` など）が終わってから移す（どこから呼んでもよい）。見えない・使えないエディタでは何もしない |
| `TopLine` | 戻り値 `Double` | ― | 表示している先頭の行（整数の値） |
| `ScrollToLine` | `ALine: Double` | ― | その行が先頭に来るようにスクロールする |
| `IsDarkTheme` | 戻り値 `Boolean` | ― | 今ダークの配色で描いているか（`ctAuto` なら OS の配色） |
| `Ready` | `Boolean` | 読み | 実行時は常に `True` |
| `ContextMenu` | `TPopupMenu` | 読み | 部品の右クリックメニュー（上級者向け。自分の項目を足すとき。15.6） |
| `Color` | `TColor` | 読み | 背景色（`Theme` で決まる。タブが切り替わる一瞬に見える所） |

### 6.2 イベント

`Sender` は、必ずそのエディタ（TCsEditor）。1 つのイベントの処理を、複数のエディタで共用できる（`Sender as TCsEditor` で見分ける）。

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnReady` | `Sender: TObject` | 実行時に初めて表示されたとき 1 回 |
| `OnChange` | `Sender: TObject` | 見えているタブの本文が変わった（人の入力のほか、コードで変えたときも。1 つの変更につき 1 回） |
| `OnCursorChange` | `Sender: TObject; Line, Column: Integer` | 見えているタブのカーソルが動いた（行・桁は 1 から。桁は UTF-16 単位） |
| `OnModeChange` | `Sender: TObject; IsOverwrite: Boolean` | 挿入と上書きが切り替わった |
| `OnModifiedChange` | `Sender: TObject` | 見えているタブの ` *` が付いた・消えた |
| `OnActiveChange` | `Sender: TObject` | 見えているタブが切り替わった |
| `OnDocListChange` | `Sender: TObject` | タブが増えた・減った・並び替えた（最後の 1 枚を閉じて空の無題ができたときも 1 回） |
| `OnDocumentChange` | `Sender: TObject; Index: Integer` | タブの名前・言語・` *` が変わった（見えていないタブも） |
| `OnSave` | `Sender: TObject; const AFileName: string` | 保存した |
| `OnQueryClose` | `Sender: TObject; Index: Integer; var CanClose: Boolean` | 保存していないタブを閉じる・置き換える前（9.5） |
| `OnNeedFileName` | `Sender: TObject; var AFileName: string; var Cancel: Boolean` | 無題を保存するとき、名前を決める |
| `OnFileDrop` | `Sender: TObject; Files: TStrings; var Handled: Boolean` | ファイルがドロップされた。`Handled := True` で標準の開く処理を止める |
| `OnToggleMaximize` | `Sender: TObject` | `F12` が押された（最大化はアプリ側で作る） |
| `OnFontSizeChange` | `Sender: TObject` | `Ctrl+ホイール` で文字の大きさが変わった |
| `OnLineNumbersChange` | `Sender: TObject` | `F11` で行番号が切り替わった |
| `OnFindDone` | `Sender: TObject; Found: Boolean` | 検索の結果（ダイアログからの検索でも、`Find` などでも出る） |
| `OnReplaceAllDone` | `Sender: TObject; Count: Integer` | すべて置換の結果 |
| `OnPopup` | `Sender: TObject` | 右クリックメニューを出す直前 |
| `OnGetTabImageIndex` | `Sender: TObject; Index: Integer; const FileName: string; var ImageIndex: Integer` | タブのアイコンを決めるとき（`TabImages` を設定したときだけ。9.3） |
| `OnTabDragOut` | `Sender: TObject; Index, X, Y: Integer; var TearOff: Boolean` | タブがアプリのウィンドウの外へ落とされた（9.9）。`Index` はそのタブの番号、`X`・`Y` は落とした画面の位置。`TearOff := False` で部品の分離・結合をやめる |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | キーが押された（普通の文字のキーも来る。9.6）。`Key := 0` で、そのキーの動きを止める |
| `OnError` | `Sender: TObject; const AMessage: string` | エディタのすべてのエラー（読めない・書けない・同じファイルを開いている など） |

**設定しないときの既定の動き**

| 名前 | 設定しないとき |
|---|---|
| `OnError` | メッセージを表示する。同じメッセージは 1 回だけ表示する |
| `OnNeedFileName` | `SaveDialog`（設定しないときは内蔵のもの）を出す |
| `OnQueryClose` | `ConfirmOnFormClose` に従う（9.5） |
| `OnFileDrop` | 標準の開く処理をする |
| `OnToggleMaximize` | 何もしない |
| `OnGetTabImageIndex` | `TabImages` の 0 番を使う |
| `OnTabDragOut` | `TabTearOff` に従う（9.9） |
| そのほか | 何もしない（知らせるだけのイベント） |

## 7. 設定（オブジェクトインスペクタ）

| 名前 | 型 | 既定値 | 中身 |
|---|---|---|---|
| `MultiDocument` | `Boolean` | `True` | `True`＝タブあり（複数ファイル）／`False`＝1 ファイルだけ（9.1）。設計時（と、コードで作った直後）だけ変えられる。実行時に変えても無視する |
| `ConfirmOnFormClose` | `Boolean` | `True` | 保存していない文書を閉じるとき、`OnQueryClose` を設定していなければ、`True`＝確認ダイアログ／`False`＝確認せずに捨てる（9.5） |
| `TabTearOff` | `Boolean` | `True` | `True`＝タブをウィンドウの外へ落とすと、別のウィンドウで開く。同じ EXE の別のウィンドウのエディタへ落とすと、そこに新しいタブで開く。ほかのウィンドウから落とされたタブも受ける（9.9） |
| `OpenDialog` | `TOpenDialog` | nil | 開くときに使うダイアログ。設定しないときは内蔵のもの（下の表） |
| `SaveDialog` | `TSaveDialog` | nil | 保存に使うダイアログ。設定しないときは内蔵のもの |
| `FindDialog` | `TCsFindDialog` | nil | 検索・置換ダイアログ。設定しないときは内蔵の共有ダイアログ（10章） |
| `TabFlat` | `Boolean` | `True` | `True`＝四角／`False`＝台形 |
| `TabSeparator` | `Boolean` | `False` | 選んでいないタブの間に細い縦線を入れるか。`TabFlat = True` のときだけ効く |
| `TabIcons` | `Boolean` | `True` | タブにアイコンを出すか（9.3） |
| `TabImages` | `TImageList` | nil | 自分で用意したアイコンの画像リスト。設定しないときは Windows のアイコンを自動で出す（9.3） |
| `WordWrap` | `Boolean` | `True` | 折り返し |
| `LineNumbers` | `Boolean` | `False` | 行番号。`F11` でも切り替わる |
| `Font` | `TFont` | BIZ UDGothic、14 ポイント | 本文の文字（名前・大きさ・太さなど）。文字の色は `Theme` で決まり、`Font.Color` は使わない |
| `FontSize` | `Integer` | 14 | 文字の大きさ（6〜72）。`Font.Size` と同じもの |
| `TabSize` | `Integer` | 4 | タブ幅（1〜16）。Tab キーでは空白を入れる |
| `Folding` | `Boolean` | `True` | 折りたたみ |
| `MatchBrackets` | `Boolean` | `True` | 括弧（`( )`・`[ ]`・`{ }`）の対応と、キーワードの組（`begin`／`end` など）・タグの組を枠で示す |
| `OccurrencesHighlight` | `Boolean` | `True` | カーソル位置の単語と同じ単語を強調する |
| `Minimap` | `Boolean` | `False` | ミニマップ（9.11）。`Ctrl+Shift+M` でも切り替わる |
| `Theme` | `TCMTheme` | `ctAuto` | 配色。`ctAuto`（OS の配色に合わせる。OS を切り替えるとその場で変わる）／`ctLight`（明るい配色で固定）／`ctDark`（暗い配色で固定）。プレビューも合わせる |
| `ReadOnly` | `Boolean` | `False` | 読み取り専用 |
| `DefaultLanguage` | `string` | 'pascal' | 新しい文書と、拡張子が分からない文書の言語 |
| `AutoLanguage` | `Boolean` | `True` | ファイル名の拡張子から言語を決める |
| `OpenDroppedFiles` | `Boolean` | `True` | ドロップしたファイルを開く |
| `QuotePrefix` | `string` | '> ' | 「引用付きコピー」の行頭の記号 |
| `HitColorLight` | `TColor` | #FFEE58 | 検索で見つかった所（エディタにフォーカスがないときの選択）の背景色（明るい配色） |
| `HitColorDark` | `TColor` | #7D6608 | 同（暗い配色） |
| `CursorLineColorLight` | `TColor` | #EAF2FF | カーソル行の背景色（明るい配色） |
| `CursorLineColorDark` | `TColor` | #2C313C | 同（暗い配色） |
| `SelectionColorStyle` | `TCMSelectionColorStyle` | `scStandard` | 選択範囲の色の組。`scStandard`（暗 #264F78・明 #ADD6FF。VS Code と同じ）／`scBlue`（暗 #0E5A9E・明 #7FB6FF）／`scAmber`（暗 #6B4E00・明 #FFD54F）／`scPurple`（暗 #5A2D82・明 #C5A3FF）／`scCustom`（下の 2 つの色）。`scCustom` 以外を選ぶと、下の 2 つの色がその組の色に変わる |
| `SelectionColorLight` | `TColor` | #ADD6FF | 選択範囲の背景色（明るい配色。フォーカスがあるとき）。書くと `SelectionColorStyle` が `scCustom` になる。選択範囲の中の文字の色は変わらない |
| `SelectionColorDark` | `TColor` | #264F78 | 同（暗い配色）。書くと `SelectionColorStyle` が `scCustom` になる |
| `Preview` | `TCPreview` | nil | プレビューの部品（11章）。複数のエディタで同じ TCPreview を選べる |
| `ShowPreview` | `Boolean` | `False` | プレビューを出すか（11章）。`Ctrl+Shift+V` でも切り替わる。`Preview` が無ければ何もしない |
| `AllowRemoteImages` | `Boolean` | `False` | プレビューでネット（http）の画像を表示するか。`Preview` の `AllowRemoteImages` と同じもの |
| `Lines` | `TStrings` | 空 | 1 枚目のタブの最初の本文 |
| `Align` | `TAlign` | | 親の中での配置 |
| `Anchors` | `TAnchors` | | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `BorderSpacing` | `TControlBorderSpacing` | | 周りの余白 |
| `Constraints` | `TSizeConstraints` | | 大きさの上限・下限 |
| `Enabled` | `Boolean` | | 使えるか |
| `Visible` | `Boolean` | | 表示するか |
| `TabOrder` | `TTabOrder` | | Tab キーで移る順番 |
| `TabStop` | `Boolean` | | Tab キーで止まるか |

- `LineDelimiters`・`LineSkipEmpty`・`LineQuoteChar` は、オブジェクトインスペクタには出ない。コードで設定する（13章）。
- プレビューの設定（文字の大きさ・配色など）は、TCPreview の側で設定する（`ed.Preview.FontSize` など）。

**色の設定（名前が `Color` で終わる 6 個）**

- オブジェクトインスペクタで、色の一覧か「...」の色ダイアログから選ぶ。
- システム色（`clWindow` など）を選んだときは、設定したときのその色になる。OS の配色を切り替えても、その色は変わらない。
- `clDefault`・`clNone` を選んだときは、既定値の色になる。

**内蔵のダイアログ**

| 項目 | 内容 |
|---|---|
| フィルター | Markdown（*.md; *.markdown）／テキスト（*.txt）／すべてのファイル（*.*） |
| 保存の既定の拡張子 | そのタブの言語から決める（markdown→md、plaintext→txt、pascal→pas、html→html、css→css、javascript→js、json→json、xml→xml、sql→sql、ini→ini、bat→bat、python→py、cpp→cpp、csharp→cs、typescript→ts、java→java、shell→sh、powershell→ps1、yaml→yaml、php→php、go→go） |
| 最初のフォルダー | そのタブのフォルダー。無題なら、前に使ったフォルダー |

## 8. キー

### 8.1 内蔵のショートカット

キーは、フォーカスのあるエディタだけが受ける。次のショートカットは、すべて `OnKeyDown` で置き換えられる（9.6）。

| キー | 動作 |
|---|---|
| `Ctrl+S` | 見えているタブを保存する。無題なら `OnNeedFileName`（設定しないときは保存ダイアログ） |
| `Ctrl+F` | 検索・置換ダイアログを開く。1 行の範囲を選んでいれば、最初の検索語にする |
| `F5` / `Shift+F5` | 直前の検索語で、次を検索 / 前を検索。検索語がなければ、ダイアログを開く |
| `Ctrl+Shift+V` | プレビューの表示と非表示を切り替える（11章）。`Preview` が無ければ何もしない |
| `Ctrl+Shift+P` | 何もしない。フォームに同じショートカットがあれば、そちらを実行する |
| `Ctrl+P` | 印刷する（`Print` と同じ） |
| `Ctrl+Shift+M` | ミニマップの表示と非表示を切り替える（`Minimap`） |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | 次のタブ / 前のタブへ切り替える（端まで行ったら反対側へ戻る）。本文のフォーカスは新しいタブへ移るので、続けて押せる。`MultiDocument = False` のときは何もしない |
| `Shift+F10` | カーソル行を複製して下へ移る（`DuplicateLine` と同じ） |
| `F11` | 行番号の表示と非表示を切り替える |
| `F12` | `OnToggleMaximize` を出す |
| `Insert` | 挿入と上書きを切り替える |
| `Ctrl+ホイール` | 文字の大きさを変える（全タブ。`OnFontSizeChange`） |
| `Ctrl+A` | すべて選ぶ |

### 8.2 エディタのキー

| キー | 動作 |
|---|---|
| `←`・`→`・`↑`・`↓`、`Home`・`End`、`PageUp`・`PageDown` | カーソルを動かす（`Shift` を足すと選びながら） |
| `Ctrl+←`・`Ctrl+→` | 単語ごとに動く（`Shift` を足すと選びながら） |
| `Ctrl+↑`・`Ctrl+↓` | 1 行スクロールする |
| `Ctrl+Home`・`Ctrl+End` | 文書の先頭・末尾へ（`Shift` を足すと選びながら） |
| `BackSpace`・`Delete` | 1 文字消す |
| `Ctrl+BackSpace`・`Ctrl+Delete` | 単語を消す |
| `Enter` | 改行（字下げは前の行と同じ） |
| `Tab` | 次のタブ位置まで空白を入れる（`TabSize`） |
| `Shift+Tab` | 字下げを戻す |
| `Ctrl+X`・`Shift+Delete` | 切り取り |
| `Ctrl+C`・`Ctrl+Insert` | コピー |
| `Ctrl+V`・`Shift+Insert` | 貼り付け |
| `Ctrl+Z` | 元に戻す |
| `Ctrl+Y`・`Ctrl+Shift+Z` | やり直し |
| `Alt+↑`・`Alt+↓` | 行を上下に動かす（選んでいれば、その行をまとめて） |
| `Shift+Alt+↑`・`Shift+Alt+↓` | 行を上・下に複製 |
| `Ctrl+]`・`Ctrl+[` | インデント・逆インデント |
| `Ctrl+/` | 行コメントの切り替え（言語のコメントの書き方。下の表） |
| `Ctrl+G` | 指定した行へ移る（行番号を聞くダイアログを出す） |
| `Ctrl+Shift+[`・`Ctrl+Shift+]` | 折りたたむ・開く |
| `Ctrl+Enter` | 下に空の行を入れて、そこへ移る（字下げは今の行と同じ） |
| `Shift+Alt+ドラッグ` | 四角い範囲を選ぶ |

- ここにないキー（SynEdit の既定のキーなど）は、エディタでは何もしない。フォームのショートカットに回る。
- `ReadOnly` のときは、編集する動き（行を動かす・複製・コメント・行を入れる）は何もしない。

| 言語 | 行コメント |
|---|---|
| pascal・javascript・json・typescript・cpp・csharp・java・php・go | `// ` |
| python・shell・yaml・powershell | `# ` |
| sql | `-- ` |
| ini | `; ` |
| bat | `REM ` |
| html・xml・markdown | 行の前に `<!-- `、後ろに ` -->` |
| css | 行の前に `/* `、後ろに ` */` |
| plaintext | なし（何もしない） |

## 9. 動き

### 9.1 MultiDocument

`MultiDocument` 1 つで、タブの表示と、開くときの動きをまとめて切り替える。1 つのフォームに複数貼って、それぞれ 1 ファイルずつ扱うときは、各エディタで `MultiDocument = False` にする。

| | `True`（タブあり、既定値） | `False`（1 ファイルだけ） |
|---|---|---|
| タブの表示 | 表示する | 表示しない（その分、エディタが広くなる） |
| ファイルを開く | 新しいタブで開く | タブはそのままで、中身を入れ替える（保存していなければ確認する） |
| 新規 | タブを足す | 中身を空にする（保存していなければ確認する） |
| 閉じる（`Close`・`CloseAll`） | タブを閉じる（最後の 1 枚なら空の無題が残る） | 中身を空にする（保存していなければ確認する）。`OnDocListChange`・`OnActiveChange` は出ない |
| ファイルのドロップ | 新しいタブで開く | 中身を入れ替える（最初のファイルだけ） |

**タブの操作（`MultiDocument = True`）**

| 操作 | 動き |
|---|---|
| クリック | そのタブに切り替え、本文にフォーカスを置く |
| ［＋］ | 新しい文書を足す |
| ［×］、中ボタンのクリック | 閉じる。保存していなければ 9.5 の確認をする |
| ドラッグ | タブを並べ替える |
| 同じフォームの別の TCsEditor の上へドラッグ | そのタブを移す（9.10） |
| ウィンドウの外へドラッグ | 別のウィンドウで開く（9.9） |
| マウスを乗せる | フルパスのヒントが出る |

- 文書ごとに、ファイル名・文字コード・改行コード・` *`・Undo/Redo の履歴・カーソル位置・スクロール位置・言語を持つ。切り替えて戻ると、それらが戻る。
- 起動直後は、無題の文書が 1 つある。`OpenFile` は、この無題を使わず、必ず新しいタブで開く。
- 検索・置換の対象は、見えているタブだけ。

### 9.2 ファイルと言語

- 読み込むときに、文字コードを判定する。BOM があれば BOM に従い、無ければ UTF-8 として正しいかを調べ、正しくなければ CP932（Shift_JIS）とする。
- 保存するときは、読み込んだときの文字コードと BOM を使う。
- CP932 で表せない文字があると、保存に失敗する（`OnError`。` *` は残る）。`Encoding` を UTF-8 に変えてから保存する。
- 改行コード（CRLF / LF）は、読み込んだときのもの（最初に見つかった改行）を使う。改行のない文書・新しい文書は CRLF。
- 行の後ろの空白は、保存しても消えない。
- ファイルは押さえない（読み書きの間だけ開く）。
- 言語は、`LoadFromFile`・`OpenFile` のときに拡張子から決める（`AutoLanguage = True` のとき）。名前を付けて保存して拡張子が変わったときも、言語を切り替える。

| 拡張子 | 言語 | 色分け |
|---|---|---|
| .pas .pp .lpr .inc .dpr .lpk | pascal | あり |
| .md .markdown | markdown | あり（見出し・強調・コード・引用・リスト・リンク） |
| .txt | plaintext | なし |
| .html .htm / .css / .js / .json / .xml | html / css / javascript / json / xml | あり |
| .sql / .ini .cfg / .bat .cmd / .py / .c .h .cpp .hpp | sql / ini / bat / python / cpp | あり |
| .cs | csharp | あり |
| .ts .tsx | typescript | あり |
| .java | java | あり |
| .sh .bash | shell | あり |
| .ps1 .psm1 .psd1 | powershell | なし |
| .yml .yaml | yaml | なし |
| .php | php | あり |
| .go | go | なし |
| それ以外 | `DefaultLanguage`（既定値は pascal） | |

- 色分けが「なし」の言語も、行コメント（`Ctrl+/`）や保存の既定の拡張子には使われる。

### 9.3 タブのアイコン

ファイルの種類ごとに、エクスプローラーと同じ Windows のアイコンを、タブの左端に自動で出す。既定値（`TabIcons = True`、`TabImages` なし）のままで出る。

| 場面 | 出すアイコン |
|---|---|
| ファイルを開いたタブ | そのファイルの拡張子のアイコン |
| 無題のタブ | テキストのアイコン（.txt のアイコン） |
| 名前を付けて保存して、拡張子が変わった | 新しい拡張子のアイコン |

- アイコンを消したいときは、`TabIcons = False` にする。

**自分で用意したアイコンを使う**

1. フォームに `TImageList` を貼り、アイコンを入れる。
2. `TabImages` で、その画像リストを選ぶ。
3. `OnGetTabImageIndex` で、タブごとに使う番号を決める（`ImageIndex := -1` でアイコンなし）。設定しないときは、全タブで 0 番を使う（15.9）。

### 9.4 配色

- `Theme = ctAuto`（既定値）なら、OS のダーク / ライトに従う。実行中に OS を切り替えても、本文・タブ・スクロールバー・ミニマップ・背景・プレビューがその場で塗り替わる。
- `ctLight`・`ctDark` なら、OS に関係なくその配色で固定する。
- 本文の色は VS Code（TCMonacoEditor）と同じ配色（ライト・ダーク）。

| 部分 | ダーク | ライト |
|---|---|---|
| 本文の背景 | #1E1E1E | #FFFFFE |
| 本文の文字 | #D4D4D4 | #000000 |
| 予約語 | #569CD6 | #0000FF |
| 文字列 | #CE9178 | #A31515 |
| コメント | #6A9955 | #008000 |
| 数値 | #B5CEA8 | #098658 |
| 行番号 | #6E7681 | #237893 |
| カーソル行の行番号 | #C6C6C6 | #0B216F |
| 折りたたみの印 | #5A5A5A | #424242 |
| タブの帯・選んでいないタブ | #2B2B2B | #F0F0F0 |
| マウスを乗せたタブ | #383838 | #E5E5E5 |
| 見えているタブ | #1E1E1E | #FFFFFF |
| 見えているタブの文字 | #FFFFFF | #000000 |
| 選んでいないタブの文字 | #C5C5C5 | #5C5C5C |
| ［×］・スクロールの矢印 | #C5C5C5 | #5C5C5C |
| 区切り線・タブの枠 | #3A3A3A | #D9D9D9 |
| スクロールバー | Windows のダークの見た目 | Windows の普通の見た目 |

- カーソル行の背景は `CursorLineColor…`、選択の背景は `SelectionColor…`（フォーカスがないときは `HitColor…`）で決まる。
- 検索で見つかった所は、エディタにフォーカスがない間（検索ダイアログを操作している間）、`HitColorLight`・`HitColorDark` で表示する。エディタをクリックすると、普通の選択の色に戻る。
- スクロールバーのダークの見た目は、Windows 10 1809 以降。それより前の Windows では、普通の見た目のまま。

### 9.5 保存していない文書の確認

`Modified` が `True` の文書を、閉じる・置き換えるとき、`OnQueryClose` で知らせる。

**知らせるとき**

- タブを閉じるとき（［×］、中ボタンのクリック、`ed.Close`、`ed.Pages[n].Close`、`CloseAll`）
- フォームを閉じるとき（エディタが、フォームの終了の確認に自動で加わる）
- `MultiDocument = False` で、別のファイルを開くとき、新規にするとき

| 状況 | 動き |
|---|---|
| `OnQueryClose` を設定している | イベントの処理に従う（`ConfirmOnFormClose` より先） |
| 設定していない。`ConfirmOnFormClose = True`（既定値） | 「（タイトル） は変更されています。保存しますか？（いいえ = 保存せずに閉じる）」を出す。はい＝保存して閉じる（保存できなければ閉じない）、いいえ＝保存せずに閉じる、キャンセル＝閉じない |
| 設定していない。`ConfirmOnFormClose = False` | 確認せずに捨てる |

- イベントの中で、閉じるのをやめるときは `CanClose := False`。保存せずに捨てるときは何もしない（`CanClose` は `True` のまま）。保存するときはイベントの中で保存する（15.3）。
- `Index` は、閉じる文書の番号。見えているタブとは限らない。
- フォームを閉じるときに 1 つでもキャンセルされたら、その時点で終了をやめる。

### 9.6 キーを足す・置き換える（OnKeyDown）

| 項目 | 中身 |
|---|---|
| 知らせるキー | すべてのキー（普通の文字のキーも） |
| 内蔵の動きの置き換え | `Key := 0` にすると、そのキーの動き（内蔵のショートカット・エディタのキー）は起きない |
| フォームのショートカット | 内蔵のショートカットに使っていないキーは、フォームのメインメニュー・ActionList のショートカットへ回す（エディタにフォーカスがあっても、メニューの Ctrl+O などが効く） |
| フォームの `KeyPreview` | 効く（`KeyPreview = True` なら、フォームの `OnKeyDown` が一番先） |

**キーが処理される順番**

1. フォームの `OnKeyDown`（`KeyPreview = True` のとき）
2. 継承した部品の `KeyDown`（override していれば）
3. `inherited` の中で、`OnKeyDown`
4. ここまでで `Key <> 0` のままなら、`Ctrl+P`・`Ctrl+Shift+M`・`Ctrl+Tab`・`Ctrl+Shift+Tab`
5. 8.1 の内蔵のショートカット
6. フォームのメインメニュー・ActionList に同じショートカットがあれば、それを実行する（エディタには渡さない）
7. 8.2 のエディタのキー

- `Ctrl+Z`・`Ctrl+Y`・`Ctrl+Shift+Z`・`Ctrl+X`・`Ctrl+C`・`Ctrl+V` は、フォームに同じショートカットがあっても、エディタの動き（7）をする。
- それ以外の 8.2 のキーは、フォームに同じショートカットがあれば、フォームが先。

**継承して自分の部品を作るとき**

TCsEditor は、protected の virtual メソッド `KeyDown(var Key: Word; Shift: TShiftState)` を持つ（LCL の TWinControl と同じ形）。`inherited` を呼ぶと、その中で `OnKeyDown` が呼ばれる。呼ばなければ `OnKeyDown` も呼ばれない（15.13）。

### 9.7 右クリックメニュー

| 状態 | 出る項目 |
|---|---|
| 文字列を選んでいる | 切り抜き、コピー、貼り付け、引用付きコピー、追加切り抜き、追加コピー、削除、TO UPPER CASE、to lower case、ﾊﾝｶｸに変換、全角ひらがなに変換、全角カタカナに変換、TAB -> 空白、空白 -> TAB、インデント、逆インデント |
| 選んでいない | 貼り付け、すべて選択、元に戻す、やり直し |
| いつも（最後） | 区切り線、ミニマップ　Ctrl+Shift+M、プレビュー　Ctrl+Shift+V |

- ミニマップ・プレビューは、それぞれ `Minimap`・`ShowPreview` を切り替える。今の値のときにチェックが付く。エディタの全タブに効く。プレビューは `Preview` が無ければ使えない。
- `ReadOnly` のときは、編集の項目が使えない。
- 変換の項目は、変換した文字列が選ばれたまま残り、Undo 1 回で戻る。
- 「引用付きコピー」は、各行の先頭に `QuotePrefix` を付けてコピーする。「追加切り抜き」「追加コピー」は、クリップボードの今の中身の後ろに足す。
- 自分の項目を足すときは、`ed.ContextMenu.Items.Add` を使う（15.6）。表示の調整は `OnPopup` で行う。自分の項目は、上の項目の後ろに並ぶ。

### 9.8 ファイルのドロップ

- エディタにファイルをドロップすると開く。`MultiDocument = True` なら新しいタブで開き（開いていればそのタブへ切り替える）、複数のファイルはすべて開く。`MultiDocument = False` なら、今の文書を入れ替える（最初のファイルだけ。保存していなければ 9.5 の確認をする）。
- フォルダーは無視する。
- `OpenDroppedFiles := False`、または `OnFileDrop` で `Handled := True` にすると、標準の処理を止められる。
- タブの帯・ミニマップへのドロップには、対応していない。

### 9.9 タブの分離と結合（TabTearOff）

タブを、アプリのウィンドウの外へドラッグして離すと、落とした先によって次のようになる。

| 落とした先 | 動き |
|---|---|
| デスクトップ・ほかのアプリのウィンドウの上 | 分離：同じ EXE をもう 1 つ起動して、そのタブを開く。元のウィンドウからは、そのタブが消える |
| 同じ EXE の別のウィンドウ（別に起動したもの）の、エディタの上 | 結合：そのエディタに新しいタブを作って開く。元のウィンドウからは、そのタブが消える |
| 同じ EXE の別のウィンドウの、エディタではない所（メニュー・ボタンなど） | 何も起きない |
| 同じフォームの別の TCsEditor の上 | そのタブを移す（9.10） |
| 自分のアプリの中の、そのほかの所 | 何も起きない |

| 設定 | 動き |
|---|---|
| `TabTearOff = True`（既定値） | 部品が分離・結合をすべて行う。アプリのコードは要らない |
| `TabTearOff = False` | 分離も結合もしない。ほかのウィンドウから落とされたタブも受けない。`OnTabDragOut` は来る |

**引き継ぐもの**（分離・結合とも）

| 項目 | 引き継ぎ |
|---|---|
| 本文 | 引き継ぐ（保存していない編集も） |
| ファイル名 | 引き継ぐ |
| 文字コード・改行コード・言語 | 引き継ぐ |
| 変更した印（` *`） | 引き継ぐ |
| Undo の履歴・カーソル位置・スクロール位置 | 引き継がない |

**開き方**（分離・結合とも）

| 元のタブ | 開き方 |
|---|---|
| ファイルを開いていて、変更なし | そのファイルを開く（` *` なし） |
| ファイルを開いていて、変更あり | そのファイル名で、保存していない本文のまま開く（` *` あり） |
| 無題（まだ保存していない） | 無題のまま、本文を入れて開く（本文があれば ` *` あり） |
| ファイル名はあるが、ディスクのファイルが消えている | 無題のまま、本文を入れて開く（` *` あり） |

**分離の決まり**

- 新しいウィンドウは、タブを落とした位置に出る。画面からはみ出すときは、収まるように寄せる。
- 新しいウィンドウで受けるのは、元と同じ名前（フォームの `Name` とエディタの `Name`）で、`TabTearOff = True` のエディタ。
- 新しいウィンドウを起動できなかったときは、タブを閉じずに残し、`OnError` で知らせる。
- 二重起動を禁止しているアプリでは、新しいウィンドウを起動できないので分離できない。
- 受け渡しには、環境変数 `CS_TEAROFF` を使う（起動する新しい EXE にだけ渡す）。アプリでは、この名前の環境変数を使わない。

**結合の決まり**

- 受けるのは、落とした位置の下にある、相手のウィンドウのエディタ。新しいタブは、そのエディタの見えるタブになり、相手のウィンドウが前に出る。
- 相手のエディタが、同じファイルをすでに開いているときは、結合しない。相手のそのタブに切り替えて、相手のウィンドウを前に出す。元のタブは残る。
- 相手のエディタが `TabTearOff = False` または `MultiDocument = False` のときは、何も起きない。
- 相手のウィンドウが応答しない（3 秒）・管理者として動いているときは、移せない。元のタブを残し、`OnError` で知らせる。
- 同じ EXE の中の TCMonacoEditor とは、分離・結合しない（互いに受け取らない）。

**共通の決まり**

- 何も入っていない無題が 1 枚だけのときは、分離も結合もしない（`OnTabDragOut` は来る。その `TearOff` の値が `False` で来るので、`True` にすれば分離・結合する）。
- 外へ出したタブが最後の 1 枚なら、元のウィンドウには空の無題が 1 枚残る。
- `Esc` でドラッグをやめたときは、何も起きない。

### 9.10 同じフォームの別の TCsEditor へタブを移す

タブを、同じフォームの別の TCsEditor（並べて貼ったもの）の上へドラッグして離すと、そのタブを移す。

| 状況 | 動き |
|---|---|
| 普通のとき | そのタブを相手へ移し、相手の見えるタブにする。Undo の履歴・カーソル位置もそのまま移る。相手の設定（配色・文字など）になる |
| 相手が同じファイルをすでに開いている | 相手のそのタブに切り替える。元のタブは残る |
| 相手が `MultiDocument = False` | 何も起きない |
| 何も入っていない無題が 1 枚だけ | 何も起きない |

- 移したタブが最後の 1 枚なら、元のエディタには空の無題が 1 枚残る。
- 別のフォームの TCsEditor へは移さない（何も起きない）。

### 9.11 ミニマップ

`Minimap = True`（または `Ctrl+Shift+M`）で、本文の右に、見えているタブの本文の縮図を出す。

```
| 本文 | ミニマップ | スクロールバー |
```

| 項目 | 中身 |
|---|---|
| 描き方 | 1 行を 2 ピクセルの高さ、1 文字を 1 ピクセルの幅（全角は 2）の四角で描く。色は色分けの色 |
| 長い文書 | エディタの位置に合わせて、描く範囲が動く |
| 見えている範囲の印 | マウスをミニマップに乗せている間だけ、エディタで見えている範囲に半透明の四角を重ねる |
| クリック | その行がエディタの真ん中に来るようにスクロールする |
| 印をドラッグ | ドラッグした量に合わせてスクロールする |
| ホイール | エディタと同じスクロール |

- ミニマップを出している間は、縦のスクロールバーがミニマップの右に出る。
- 折り返しは考えない（ファイルの行で描く）。
- 全タブで共通（タブごとには切り替えない）。

## 10. 検索・置換ダイアログ

- `FindDialog` を設定しないエディタは、フォームに 1 つだけの内蔵の共有ダイアログを使う。エディタを何個貼っても、ダイアログは 1 つ。
- 対象は、`Ctrl+F` を押したエディタ（最後にフォーカスされたエディタ）。ダイアログを開いたまま別のエディタをクリックすると、対象がそちらに切り替わる。
- タイトルに対象を出す（例：「検索・置換 - readme.md」）。
- ダイアログの位置、検索語、置換語、履歴、オプションは、全エディタで共通。
- 自分で制御するときは、パレットから `TCsFindDialog` をフォームに 1 つ貼り、各エディタの `FindDialog` で選ぶ。複数のエディタが同じダイアログを選べる。

| 項目 | 中身 |
|---|---|
| 検索語・置換語 | 履歴付きのコンボボックス（30 件） |
| オプション | 大文字小文字の区別、単語単位、ループ検索（正規表現はない） |
| ボタン | 次を検索、前を検索、置換、すべて置換、閉じる。`Enter` で次を検索、`Esc` で閉じる |
| 結果 | ダイアログの下に「見つかりません」「N 件置換しました」と出す |

- 置換は、選んでいる文字列が検索語と同じなら置き換えて次を検索する。「すべて置換」は Undo 1 回で戻る。
- 対象は見えているタブだけ。

**TCsFindDialog のメソッド・プロパティ**

| 名前 | 型・引数 | 読み書き | 中身 |
|---|---|---|---|
| `ShowFor` | `AEditor: TCsEditor; const InitialText: string = ''` | ― | そのエディタを対象にして開く |
| `CloseDialog` | ― | ― | 閉じる |
| `IsShowing` | 戻り値 `Boolean` | ― | 開いているか |
| `Target` | `TCsEditor` | 読み・書き | 今の対象 |
| `SearchText` | `string` | 読み | 今の検索語 |
| `ReplaceText` | `string` | 読み | 今の置換語 |
| `Options` | `TCMFindOptions` | 読み | 今のオプション |
| `FindHistory`・`ReplaceHistory` | `TStringList` | 読み | 履歴（`Free` しない） |

## 11. プレビュー（TCPreview）

プレビュー（Markdown・コード）と印刷は、別の部品 TCPreview で行う。詳しくは `TCPreview_Usage.md`。

1. フォームに TSplitter と TCPreview を置く（例：どちらも `Align = alRight`）。
2. TCPreview の `Splitter` で、その TSplitter を選ぶ。
3. TCsEditor の `Preview` で、その TCPreview を選ぶ。

| 名前・操作 | 動き |
|---|---|
| `ShowPreview`・`Ctrl+Shift+V` | プレビューを出す・隠す（TCPreview の `Visible` と同じもの） |
| `Print`・`Ctrl+P` | 見えているタブを印刷する（PDF 保存も）。プレビューを出していなければ、印刷の間だけ出す |
| `AllowRemoteImages` | プレビューでネットの画像を表示するか（TCPreview の `AllowRemoteImages` と同じもの） |
| `ed.Preview.〜` | プレビューの設定（`FontSize`・`ColorScheme`・`SyncScroll`・`DelayMs` など） |

- 1 つの TCPreview を、複数の TCsEditor で選べる。プレビューには、最後にクリックしたエディタの見えているタブが出る。
- `ShowPreview` は、同じ TCPreview を選んだエディタの間で共通。
- プレビューの `.md` へのリンクは、そのエディタで開く（TCPreview の `OnOpenMarkdown` を設定していなければ）。

## 12. 標準アクション

フォームのメニューやボタンから操作するときは、コードを書かずに標準アクションを使う。Lazarus の標準アクション「ファイルを開く」などと同じ使い方。

| No | アクション（クラス名） | 表示名 | 既定のショートカット | 動き | 使えるとき | チェック |
|---|---|---|---|---|---|---|
| 1 | `TCsEditorNew` | 新規(&N) | Ctrl+N | `NewPage` | 対象のエディタがある | ― |
| 2 | `TCsEditorOpen` | 開く(&O)... | Ctrl+O | `OpenDialog`（設定しないときは内蔵のもの）で選んで `OpenFile`。タブありなら複数選べる | 対象のエディタがある | ― |
| 3 | `TCsEditorSave` | 上書き保存(&S) | Ctrl+S | `Save`（無題なら保存ダイアログ） | 対象のエディタがある | ― |
| 4 | `TCsEditorSaveAs` | 名前を付けて保存(&A)... | なし | `SaveAs` | 対象のエディタがある | ― |
| 5 | `TCsEditorClose` | 閉じる(&C) | Ctrl+W | `Close`（9.5 の確認をする）。`MultiDocument = False` のときは、確認して中身を空にする | 対象のエディタがある | ― |
| 6 | `TCsEditorPrint` | 印刷(&P)... | Ctrl+P | `Print` | `CanPrint` | ― |
| 7 | `TCsEditorSaveAll` | すべて保存(&L) | Ctrl+Shift+S | `SaveAll` | 変更のあるタブがある | ― |
| 8 | `TCsEditorCloseAll` | すべて閉じる(&E) | なし | `CloseAll`（9.5 の確認をする） | 対象のエディタがある | ― |
| 9 | `TCsEditorUndo` | 元に戻す(&U) | Ctrl+Z | `Undo` | `CanUndo` | ― |
| 10 | `TCsEditorRedo` | やり直し(&R) | Ctrl+Y | `Redo` | `CanRedo` | ― |
| 11 | `TCsEditorCut` | 切り取り(&T) | Ctrl+X | `Cut` | 選んでいる（`SelLength > 0`）、かつ `ReadOnly` でない | ― |
| 12 | `TCsEditorCopy` | コピー(&C) | Ctrl+C | `Copy` | 選んでいる（`SelLength > 0`） | ― |
| 13 | `TCsEditorPaste` | 貼り付け(&P) | Ctrl+V | `Paste` | クリップボードに文字がある、かつ `ReadOnly` でない | ― |
| 14 | `TCsEditorSelectAll` | すべて選択(&A) | Ctrl+A | `SelectAll` | 対象のエディタがある | ― |
| 15 | `TCsEditorDuplicateLine` | 行の複製(&D) | Shift+F10 | `DuplicateLine` | `ReadOnly` でない | ― |
| 16 | `TCsEditorDeleteToEnd` | 末尾まで削除 | なし | `DeleteToEnd` | `ReadOnly` でない | ― |
| 17 | `TCsEditorDeleteToStart` | 先頭まで削除 | なし | `DeleteToStart` | `ReadOnly` でない | ― |
| 18 | `TCsEditorFind` | 検索・置換(&F)... | Ctrl+F | `ShowFindDialog` | 対象のエディタがある | ― |
| 19 | `TCsEditorFindNext` | 次を検索(&N) | F5 | `FindNext` | 対象のエディタがある | ― |
| 20 | `TCsEditorFindPrev` | 前を検索(&V) | Shift+F5 | `FindPrev` | 対象のエディタがある | ― |
| 21 | `TCsEditorMinimap` | ミニマップ(&M) | Ctrl+Shift+M | `Minimap` を切り替える | 対象のエディタがある | `Minimap` |
| 22 | `TCsEditorPreview` | プレビュー(&V) | Ctrl+Shift+V | `ShowPreview` を切り替える | `Preview` がある | `ShowPreview` |
| 23 | `TCsEditorLineNumbers` | 行番号(&L) | F11 | `LineNumbers` を切り替える | 対象のエディタがある | `LineNumbers` |
| 24 | `TCsEditorWordWrap` | 折り返し(&W) | なし | `WordWrap` を切り替える | 対象のエディタがある | `WordWrap` |
| 25 | `TCsEditorRemoteImages` | ネットの画像を表示(&I) | なし | `AllowRemoteImages` を切り替える | `Preview` がある | `AllowRemoteImages` |

- 使い方：フォームに `TActionList` を貼り、アクションリストエディタの「標準アクションを追加」から、カテゴリ `CX TCsEditor` のアクションを足し、メニュー項目の `Action` で選ぶ。
- 対象は、最後にフォーカスされたエディタに自動で決まる。まだどれもフォーカスされていなければ、最初のエディタ。コードから知りたいときは `CsActiveEditor(Form)`。
- 使えないときは灰色になる。使える・使えないとチェックは、Lazarus がアプリの暇なときとメニューを開くときに付け直す。
- アクションのショートカットは、エディタにフォーカスがあっても効く（9.6）。ただし、内蔵のショートカットと同じキーは内蔵が先（動きは同じ）。アクションを先にしたいときは、`OnKeyDown` で置き換える。
- 表示名・ヒント・ショートカットは、足したあとでオブジェクトインスペクタで変えてよい。
- `OnExecute` を設定すると、標準の動きの代わりにそちらが呼ばれる。`OnUpdate` を設定すると、標準の付け直しの代わりにそちらが呼ばれる（`TAction` と同じ）。
- 終了は、Lazarus の標準アクション `TFileExit` を使う。

## 13. カーソル行の文字列と単語

### 13.1 取れる値

| 書き方 | 取れるもの | awk で言うと |
|---|---|---|
| `ed.LineText` | カーソル行の文字列（改行は含まない） | `$0` |
| `ed.LineWords[0]` | 1 つ目の単語 | `$1` |
| `ed.LineWords[1]` | 2 つ目の単語 | `$2` |
| `ed.LineWords.Count` | 単語の数 | `NF` |

- どこで読んでもよい（`OnCursorChange` の中、ボタン・メニュー・タイマーなど）。読んだ時点のカーソル行の値が取れる（文字を入力した直後でも正しい）。
- `OnKeyDown` の中で読むと、そのキーが効く前の行になる。
- 対象は、見えているタブのカーソル行。
- 単語が 0 個の行（空の行など）で `LineWords[0]` を読むと、範囲の外のエラーになる。先に `Count` を確かめる。
- `LineWords` の一覧は部品が持つ。`Free` しない。次に読むと中身が変わるので、残したいときは `Assign` で自分の `TStringList` に写す。

### 13.2 分け方の設定

| 名前 | 既定値 | 中身 |
|---|---|---|
| `LineDelimiters` | 半角スペース・全角スペース・タブ・カンマ（`,`）・読点（`、`） | 区切り文字。書いた 1 文字ずつが区切りになる。全角文字も書ける。'' なら行全体が 1 つの単語 |
| `LineSkipEmpty` | `True` | `True`：区切りが続いても 1 つとして扱い、空の単語を入れない。行の先頭と最後の区切りも無視する。`False`：空の単語も入れる |
| `LineQuoteChar` | `"` | 引用符（半角 1 文字）。`#0` なら引用符を解釈しない |

- 3 つとも、オブジェクトインスペクタには出ない。コードで設定する。

### 13.3 分け方の決まり

1. 行の先頭から 1 文字ずつ見て、`LineDelimiters` の文字のところで分ける。
2. 単語の先頭が引用符なら、次の引用符までを 1 つの単語にする。中の区切り文字では分けない。引用符は取り除く。
3. 引用符の中で引用符を 2 つ続けて書くと、引用符 1 つの文字になる。
4. 閉じる引用符のあとから次の区切りまでの文字は、同じ単語の後ろに付く。
5. 閉じる引用符がなければ、行の最後までが 1 つの単語になる。
6. 単語の途中にある引用符は、普通の文字として扱う。
7. 引用符の文字を `LineDelimiters` にも入れたときは、区切りとして扱う（引用符として解釈しない）。
8. `LineSkipEmpty = True` なら、空の単語（区切りが続いた所、行の先頭・最後の区切り、`""`）は入れない。
9. 空の行は、単語 0 個（`LineSkipEmpty` に関係なく）。

**例（`LineDelimiters = ','`、`LineSkipEmpty = True`、`LineQuoteChar = '"'`）**

| 行 | `LineWords` |
|---|---|
| `a,b,c` | `a`・`b`・`c` |
| `a,,b` | `a`・`b` |
| `,a,b,` | `a`・`b` |
| `x,"a,b",y` | `x`・`a,b`・`y` |
| `"a""b"` | `a"b` |
| `"a,b"c,d` | `a,bc`・`d` |
| `ab"c,d` | `ab"c`・`d` |
| `x,"a,b` | `x`・`a,b` |
| `x,"",y` | `x`・`y` |
| （空の行） | （0 個） |

- `LineSkipEmpty = False` にすると、`a,,b` は `a`・空・`b`（3 個）、`,a,` は 空・`a`・空（3 個）になる。
- `LineQuoteChar = #0` にすると、`x,"a,b",y` は `x`・`"a`・`b"`・`y`（4 個）になる。

**例（既定の設定）**

| 行 | `LineWords` |
|---|---|
| `  procedure   Foo;` | `procedure`・`Foo;` |
| `名前　山田　太郎`（全角スペース） | `名前`・`山田`・`太郎` |
| `say "hello world"` | `say`・`hello world` |
| `東京、神奈川,埼玉` | `東京`・`神奈川`・`埼玉` |

- `LineWords` は、読んだときに初めて分ける。行と設定が前に読んだときと同じなら、分け直さずに前の結果を返す。

## 14. 注意

| 項目 | 中身 |
|---|---|
| `SelStart`・`SelLength`・桁の数え方 | UTF-16 単位（絵文字を 2 と数える） |
| `OnChange` | コードで本文を変えたとき（`Text :=`・`SelText :=` など）も出る |
| スクロールの同期 | 行単位（行の途中の位置までは合わせない） |
| 改行コード | 1 つの文書の中に CRLF と LF が混ざっていても、保存すると、読み込んだときに決めた改行コードにそろう |
| 色分け | powershell・yaml・go・plaintext は色分けしない |
| マルチカーソル・コマンドパレット | ない |
| 正規表現の検索 | ない |
| 印刷 | TCPreview が無いと印刷できない |

## 15. 使い方の例

### 15.1 コードを書かずに、テキストエディタを作る

1. フォームに TCsEditor を 1 つ貼り、`Align = alClient` にする。

これだけで、次のことができる。

| 機能 | 操作 |
|---|---|
| 編集 | そのまま |
| ファイルを開く | ドロップ |
| タブの切り替え | `Ctrl+Tab`・`Ctrl+Shift+Tab`、タブのクリック |
| 行番号の表示・非表示 | `F11` |
| 検索・置換 | `Ctrl+F`、`F5` / `Shift+F5` |
| 上書き保存 | `Ctrl+S`（無題なら「名前を付けて保存」のダイアログ） |
| ミニマップ | `Ctrl+Shift+M` |
| 色分け | 拡張子から自動 |
| 保存していない文書の確認 | フォームを閉じると自動で確認 |

プレビューと印刷を足すときは、11章のとおり TCPreview を置く。

### 15.2 2 つ並べて、タブを行き来させる

1. TCsEditor を 2 つ貼り、左を `Align = alLeft`、右を `Align = alClient` にする。
2. 間に TSplitter（`Align = alLeft`）を置く。

コードは要らない。タブを左右のエディタの間でドラッグすると、移る（9.10）。検索・置換ダイアログは共有の 1 つで、`Ctrl+F` を押したエディタが対象になる。標準アクションは、最後にフォーカスされたエディタに効く。

### 15.3 保存していない文書を、確認せずに保存する

```pascal
procedure TForm1.CsEditor1QueryClose(Sender: TObject; Index: Integer;
  var CanClose: Boolean);
var
  E: TCsEditor;
begin
  E := Sender as TCsEditor;
  E.Pages[Index].Save;                          // 保存する（無題なら保存ダイアログが出る）
  CanClose := not E.Pages[Index].Modified;      // 保存ダイアログでキャンセルされたら閉じない
end;
```

### 15.4 メニューを付ける

1. フォームに `TActionList` と `TMainMenu` を貼る。
2. アクションリストエディタで、カテゴリ `CX TCsEditor` の標準アクション（12章）を足す。
3. メニュー項目の `Action` で、アクションを選ぶ。

### 15.5 自分のダイアログを使う

1. フォームに `TOpenDialog`・`TSaveDialog`・`TCsFindDialog` を貼り、フィルターや最初のフォルダーを設定する。
2. 各エディタの `OpenDialog`・`SaveDialog`・`FindDialog` で選ぶ。

### 15.6 右クリックメニューに自分の項目を足す

```pascal
procedure TForm1.FormCreate(Sender: TObject);
var
  MI: TMenuItem;
begin
  MI := TMenuItem.Create(Self);
  MI.Caption := '[ ] で囲む';
  MI.OnClick := @MyMenuClick;
  CsEditor1.ContextMenu.Items.Add(MI);
end;

procedure TForm1.MyMenuClick(Sender: TObject);
begin
  CsEditor1.SelText := '[' + CsEditor1.SelText + ']';
end;
```

### 15.7 本文を行ごとに読む・書く

```pascal
var
  i: Integer;
begin
  for i := 0 to CsEditor1.Lines.Count - 1 do
    Memo1.Lines.Add(CsEditor1.Lines[i]);         // 見えているタブの行

  CsEditor1.Lines := Memo1.Lines;                // 見えているタブの本文を入れ替える
  Label1.Caption := CsEditor1.Pages[1].Lines[0]; // 1 番のタブの 1 行目
end;
```

### 15.8 内蔵の Ctrl+S を、自分の保存処理に置き換える

```pascal
procedure TForm1.CsEditor1KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_S) and (ssCtrl in Shift) then
  begin
    MySave(Sender as TCsEditor);
    Key := 0;   // 内蔵の保存は動かない
  end;
end;
```

### 15.9 タブのアイコンを自分で決める

```pascal
procedure TForm1.CsEditor1GetTabImageIndex(Sender: TObject; Index: Integer;
  const FileName: string; var ImageIndex: Integer);
begin
  if SameText(ExtractFileExt(FileName), '.md') then
    ImageIndex := 0
  else
    ImageIndex := 1;
end;
```

### 15.10 カーソル行の単語を出す

```pascal
procedure TForm1.CsEditor1CursorChange(Sender: TObject; Line, Column: Integer);
var
  W: TStrings;
  i: Integer;
begin
  Label1.Caption := CsEditor1.LineText;
  W := CsEditor1.LineWords;
  Memo1.Lines.Clear;
  for i := 0 to W.Count - 1 do
    Memo1.Lines.Add(W[i]);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  CsEditor1.LineDelimiters := ' ' + '　' + #9;   // カンマ・読点では分けない
end;
```

### 15.11 起動したらファイルを開き、エディタにフォーカスを置く

```pascal
procedure TForm1.CsEditor1Ready(Sender: TObject);
begin
  CsEditor1.OpenFile('C:\docs\readme.md');
  CsEditor1.SetFocus;
end;
```

### 15.12 中のエディタ（TCSynEdit）を直接使う（上級者向け）

```pascal
// 見えているタブの中のエディタで、右端のガイド線を出す
CsEditor1.SynEdit.RightEdge := 100;
CsEditor1.SynEdit.RightEdgeColor := clGray;
```

- `OnChange`・`OnStatusChange`・`PopupMenu` は部品が使うので変えない。
- 配色・文字・タブ幅などは、TCsEditor の設定（7章）を変えたときに、中のエディタへ入れ直される。

### 15.13 継承して自分の部品を作る

```pascal
procedure TMyEditor.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_S) and (ssCtrl in Shift) then
  begin
    MySave;
    Key := 0;          // 内蔵の保存は動かない
    Exit;
  end;
  inherited KeyDown(Key, Shift);   // ここで OnKeyDown が呼ばれる
end;
```

### 15.14 コードで作る

```pascal
uses
  uCsEditor;

procedure TForm1.FormCreate(Sender: TObject);
var
  E: TCsEditor;
begin
  E := TCsEditor.Create(Self);
  E.MultiDocument := False;   // 変えるのは Parent を設定する前
  E.Parent := Self;           // ここでフォームの終了の確認に加わる
  E.Align := alClient;
end;
```

### 15.15 TCMonacoEditor から張り替える

| TCMonacoEditor | TCsEditor |
|---|---|
| `uCmonacos`・`TCMonacoEditor` | `uCsEditor`・`TCsEditor` |
| `TCMPage` | `TCsPage` |
| `TCMFindDialog` | `TCsFindDialog` |
| 標準アクション `TCMEditor…`（カテゴリ `CX`） | `TCsEditor…`（カテゴリ `CX TCsEditor`） |
| `CMActiveEditor` | `CsActiveEditor` |
| プレビューの設定 `PreviewFontSize`・`PreviewDelayMs`・`PreviewBackColor…` など | TCPreview の `FontSize`・`DelayMs`・`BackColor…` など（頭の `Preview` を外した名前） |
| `PreviewWidth`・`SplitterWidth`・`SplitterResizeStyle` | TCPreview の `Width`、アプリが置く TSplitter の設定 |
| `OnOpenMarkdown` | TCPreview の `OnOpenMarkdown` |
| `Monaco`・`Monaco.PopupMenu` | `SynEdit`・`ContextMenu` |
| `MonacoPath`・`JapaneseUI` | ない（要らない） |

- そのほかの名前・引数・既定値は同じ。
