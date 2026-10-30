# TCMonacoEditor 取扱説明書

作者: aotan083
日付: 2026-10-30
版: 1.2

---

## 1. 概要とクラス

フォームに貼るだけで使える、WebView2 と Monaco Editor（VS Code の編集部分）による、完全オフラインのエディタです。タブ・エディタ・プレビュー（Markdown・コード）・検索・置換・印刷を 1 つの部品に内蔵しています。Markdown のほか、Pascal などのソースも編集できます。設定はすべてオブジェクトインスペクタで行い、アプリ側でコードを書く必要はありません。

```
+---------+---------+-----+------------------------------+
| a.md  × | b.pas × |  +  |                              |
+---------+---------+-----+--+---------------------------+
| # 見出し                   ‖  見出し                    |
| 本文…                      ‖  本文…                     |
|                            ‖                           |
|    Monaco エディタ          ‖  プレビュー                 |
+----------------------------+---------------------------+
```

- 1 つのフォームに何個でも貼れる。貼った 1 つ 1 つが、それぞれ完結したエディタになる。
- イベントは、設定しなくても動く（設定しないときは、部品が既定の動きをする。6.2）。
- 文字コード（UTF-8・UTF-16・Shift_JIS）を判定して読み、同じ文字コードで保存する。
- 拡張子から言語を決めて色分けする。
- Markdown は、プレビューで文書として表示する（表・タスクリスト・Mermaid の図）。それ以外の言語は、色分けしたコードとして表示する。
- 印刷（PDF 保存）は Edge の印刷ダイアログで行う。
- フォームを閉じるとき、保存していない文書を自動で確認する。
- 標準アクション（25 個）をメニュー・ボタンに割り当てられる（12章）。
- タブをウィンドウの外へドラッグすると、そのタブを別のウィンドウ（同じ EXE をもう 1 つ起動）で開く。同じ EXE の別のウィンドウのエディタへ落とすと、そこに新しいタブで開く（`TabTearOff`。9.9）。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |
| 実行に必要なもの | Microsoft Edge WebView2 ランタイム（Windows 11 には最初から入っている）、WebView2Loader.dll（64 ビット版）、WebView2.ini、monaco フォルダー、preview フォルダー（2章） |
| メモリ | エディタ 1 つで約 60MB（WebView2）。同じアプリの WebView2 は土台を共有するため、エディタを増やしても 1 つ目ほどは増えない |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCMonacoEditor` | `uCmonacos` | cx | `TCustomPanel` | フォームに貼るエディタ本体 |
| `TCMPage` | `uCmonacos` | cx | `TObject` | タブ 1 枚（`ed.Pages[n]` で取る。4章）。作るのも消すのも TCMonacoEditor が行う |
| `TCMFindDialog` | `CMonacoFindDlg` | cx | `TComponent` | 検索・置換ダイアログ（非表示の部品）。自分で制御したいときだけ貼る（10章） |
| `TCMEditorNew` ほか 24 個 | `CMonacoActions` | cx | `TAction` | 標準アクション（12章） |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCMEncoding` | `uCmonacos` | 文字コード。`ceUTF8`・`ceUTF8BOM`・`ceUTF16LE`・`ceUTF16BE`・`ceCP932` |
| `TCMFindOption`・`TCMFindOptions` | `uCmonacos` | 検索のオプション。`foMatchCase`（大文字小文字を区別）・`foWholeWord`（単語単位）・`foLoop`（端まで行ったら反対側から） |
| `TCMTheme` | `uCmonacos` | 配色。`ctAuto`・`ctLight`・`ctDark` |
| `TCMColorScheme` | `uCmonacos` | プレビューの配色。`csEditor`・`csGitHub` |
| `TCMSelectionColorStyle` | `uCmonacos` | 選択範囲の色の組。`scStandard`・`scBlue`・`scAmber`・`scPurple`・`scCustom` |
| `TCMSyncScroll` | `uCmonacos` | スクロールの同期。`ssNone`・`ssEditorToPreview`・`ssBoth` |

| 関数 | ユニット | 中身 |
|---|---|---|
| `CMActiveEditor(AForm: TCustomForm): TCMonacoEditor` | `uCmonacos` | そのフォームで最後にフォーカスされたエディタ。まだどれもフォーカスされていなければ最初のエディタ。無ければ nil |
| `CMSplitLine(const S, Delims: string; SkipEmpty: Boolean; Quote: Char; Dest: TStrings)` | `uCmonacos` | 1 行を単語に分ける（`LineWords` と同じ分け方。13章）。`Dest` は空にしてから入れる |
| `CMColorToHex(AColor, ADefault: TColor): string` | `uCmonacos` | 色を '#RRGGBB' にする。`clDefault`・`clNone` なら `ADefault` |
| `CMToHankaku(const S: string): string` | `uCmmonacoview` | 全角英数字・記号・カタカナを半角にする |
| `CMToZenkakuKatakana(const S: string): string` | `uCmmonacoview` | ひらがな・半角カナを全角カタカナにする |
| `CMToZenkakuHiragana(const S: string): string` | `uCmmonacoview` | カタカナ・半角カナを全角ひらがなにする |

- フォームに置くと、uses に `uCmonacos` が自動で入る。アプリの uses は、これだけでよい（よく使う型は `uCmonacos` が出し直している）。
- フォームに置くと、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCMonacoEditor をフォームに置き、`Align = alClient` にする。
2. EXE と同じフォルダーに、2.1 のファイルを置く。
3. 実行する。

- WebView2 の準備（`GlobalWebView2Loader` の作成と `StartWebView2`）は、エディタが初めて表示されたときに、部品が自分で行う。アプリの .lpr には何も書かない。
- WebView2 の準備は、アプリの中で 1 回だけ行う。TCTabBrowser など、ほかの CX の WebView2 部品と同じものを使う。
- WebView2.ini が無いとき、WebView2 の準備ができないときは、`OnError` で知らせる（「WebView2.ini が見つかりません: （ファイルの場所）」または WebView2 のエラーの文）。エディタは空の枠のまま。
- IDE の上（設計時）では WebView2 を起動しない。薄い枠と部品の名前だけが出る。

### 2.1 実行時のファイル

```
MyApp.exe
WebView2.ini                       （必ず置く。2.2）
WebView2Loader.dll                 （64 ビット版）
WebView2Data\                      （WebView2 のユーザーデータ。自動で作る）
monaco\
  editor.html
  vs\
    loader.js
    editor\ ...
    base\ ...
    basic-languages\ ...
preview\
  preview.html
  lib\
    marked.umd.js
    purify.min.js
    highlight.min.js
    github.min.css / github-dark.min.css
    github-markdown-light.css / github-markdown-dark.css
    THIRD_PARTY_LICENSES.txt
    mermaid.min.js / mermaid.LICENSE.txt   （Mermaid の図。12.1.0）
    languages\ delphi.min.js / dos.min.js / powershell.min.js
```

- `monaco\vs` は、npm の `monaco-editor` パッケージの `min\vs` フォルダーを、丸ごとコピーする。`min-maps` は要らない。
- `preview` フォルダーのライブラリのライセンスは `lib\THIRD_PARTY_LICENSES.txt` にある。
- 日本語の表示（`editor.main.nls.ja.js`）が無いときは、`JapaneseUI := False` にする。
- WebView2Loader.dll は、WebView4Delphi のリポジトリ（https://github.com/salvadordf/WebView4Delphi）から入手する。

### 2.2 WebView2.ini

EXE と同じフォルダーに置く。CX の WebView2 部品（TCMonacoEditor・TCTabBrowser）で共通。

```ini
[WebView2]
LoaderDllPath=
UserDataFolder=
MonacoFolder=
PreviewFolder=
```

| キー | 中身 | 空・書かないとき |
|---|---|---|
| `LoaderDllPath` | WebView2Loader.dll のファイル | EXE のフォルダーの WebView2Loader.dll |
| `UserDataFolder` | WebView2 のユーザーデータのフォルダー | EXE のフォルダー\WebView2Data |
| `MonacoFolder` | `editor.html` と `vs` があるフォルダー | EXE のフォルダー\monaco |
| `PreviewFolder` | `preview.html` と `lib` があるフォルダー | EXE のフォルダー\preview |

- ファイルは必ず置く。キーの値はすべて空でもよい（すべて、空のときの場所を使う）。
- 相対パスは、EXE のフォルダーから数える。絶対パスも書ける。
- 起動してから最初に使うときに 1 回だけ読む。実行中に書き換えても、次の起動まで効かない。
- 複数のアプリで 1 か所の `monaco`・`preview` を使うときに便利（15.7）。`UserDataFolder` は、アプリごとに分ける（同じフォルダーを複数のアプリで同時に使うと、WebView2 の起動に失敗することがあるため）。

### 2.3 monaco・preview の場所の決め方

エディタごとに、上から順に、最初に決まったものを使う。

| 順 | 決め方 |
|---|---|
| 1 | `MonacoPath`・`PreviewPath` プロパティが空でなければ、その場所（相対パスは EXE のフォルダーから数える） |
| 2 | WebView2.ini の `MonacoFolder`・`PreviewFolder` が空でなければ、その場所 |
| 3 | EXE のフォルダーの `monaco`・`preview` |

- 見つからなければ `OnError`（「editor.html が見つかりません: （場所）」「preview.html が見つかりません: （場所）」）。場所は、上で決めた絶対パス（`..` を取り除いたもの）を出す。

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
- 名前は、TMemo・TSynEdit と同じものを使う（`Text`・`SelText`・`SelLength`・`Modified`・`LoadFromFile` など）。

**2. 1 つのタブ＝1 つのページ**

- ページ＝タブ 1 枚＋本文 1 つ＋ファイル名。無題（まだ保存していない）も 1 つのページ。
- 同じファイルを、2 つのタブで開くことはない。
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
| `Text` | `string` | 読み・書き | 本文。書くと内容だけ置き換える（ファイル名はそのまま。Undo の履歴は消える。ファイルには書かない）。書くと ` *` が付き、Undo で戻しても ` *` は消えない（消えるのは保存したとき）。今と同じ本文を書いたときは、何もしない（` *` は付かない）。読む値は、人が入力してから約 0.1 秒遅れて反映される（14章） |
| `Caption` | `string` | 読み | タブのタイトル。ファイル名の名前の部分だけ。無題なら「無題」。` *` は含まない |
| `FileName` | `string` | 読み | ファイルのフルパス。無題なら ''。名前を変えるときは `SaveAs` |
| `Modified` | `Boolean` | 読み | 保存していない変更があるか（タブの ` *`） |
| `Encoding` | `TCMEncoding` | 読み・書き | 文字コード。読み込んだときに決まり、保存するときに使う |
| `Language` | `string` | 読み・書き | 色分けの言語（'pascal'、'markdown' など。9.2）。'' を書くと `DefaultLanguage` |
| `LineCount` | `Integer` | 読み | 行数。`Text` から数える。空の文書は 1。最後が改行で終わるときは、その後ろの空の行も 1 行と数える（Monaco の行番号と同じ）。#13#10・#13・#10 のどれも改行 1 つ |
| `LoadFromFile` | `const AFileName: string`、戻り値 `Boolean` | ― | 内容を捨てて、ファイルを読み込む。変更があっても聞かずに捨てる。タブは増えない。読み込めたら `True`。ファイルが無い・読めないときは、何も変えず `False`（`OnError`）。別のタブで開いているファイルなら、読み込まず `False`（`OnError`。表示も切り替えない）。そのタブで開いているファイルと同じなら、読み直す |
| `Save` | 戻り値 `Boolean` | ― | 上書き保存。無題なら名前を聞く（`OnNeedFileName`、設定しないときは保存ダイアログ。裏のタブでも切り替えずに聞く）。聞いた名前が別のタブで開いているファイルなら保存しない。保存できたら `True`。キャンセル・失敗なら `False` で、` *` は消えない。失敗は `OnError` |
| `SaveAs` | `const AFileName: string = ''`、戻り値 `Boolean` | ― | 別の名前で保存する。名前を省くと保存ダイアログで聞く（裏のタブでも切り替えずに出す）。保存したあとは、タブのタイトル・アイコンもその名前になる。元のファイルはディスクに残る。別のタブで開いているファイルの名前なら保存せず `False`（`OnError`）。名前を指定したときは、同じ名前のファイルがあれば聞かずに上書きする（ダイアログなら「上書きしますか？」と聞く） |
| `Clear` | ― | ― | 内容を空にし、ファイル名も消して無題にする。変更があっても聞かずに捨てる。タブは残る。言語は `DefaultLanguage`。ファイルには何もしない |
| `Close` | `Force: Boolean = False`、戻り値 `Boolean` | ― | 閉じる。変更があれば聞く（9.5）。`Force = True` なら聞かずに捨てる。閉じたら `True`、キャンセルなら `False`。見えているタブを閉じたら、隣のタブが見えるタブになる。最後の 1 枚なら、空の無題が残る。`MultiDocument = False` なら、閉じずに中身を空にする（9.1）。ファイル自体は消さない |

**`Pages[n]` の決め事**

- ページは、エディタが作って管理する。アプリ側で `Create`・`Free` はしない。
- 取り出したページ（例：`P := ed.Pages[2]`）は、タブを並べ替えても、同じタブを指し続ける。
- 閉じたページを使ったとき、読む値は空（`Caption`・`FileName`・`Text` は ''、`Modified` は `False`、`LineCount` は 0）、操作は何もしない（`Boolean` を返すものは `False`）。落ちない。
- `Pages[n]` の番号が範囲の外なら、例外（`EListError`）。
- `MultiDocument = False` のときは、ページは常に 1 つ（`Pages[0]`）。

## 5. タブの集まり（ed）

| 名前 | 型・引数 | 読み書き | 中身 |
|---|---|---|---|
| `OpenFile` | `const AFileName: string = ''`、戻り値 `Integer` | ― | 名前を省くと、開くダイアログ（`OpenDialog`、設定しないときは内蔵のもの）を出し、選んだファイルを開く。キャンセルなら何もせず -1。名前を指定したときは、新しいタブでファイルを読み込んで開き、見えるタブにする。文字コードを判定し、拡張子から言語を決める。同じファイルを開いていれば、そのタブに切り替えるだけ（読み直さない）。起動直後の無題のタブが 1 つだけでも、そこには読み込まない。戻り値はタブの番号。読めないファイルなら例外（タブは残さない）。`MultiDocument = False` なら 9.1 |
| `NewPage` | 戻り値 `Integer` | ― | 空の無題のタブを右に足して、見えるタブにする。戻り値はタブの番号。ファイルは読まない・作らない。`MultiDocument = False` なら 9.1 |
| `SaveAll` | ― | ― | 変更のあるタブを、すべて上書き保存する（無題は、そのタブに切り替えてから名前を聞く） |
| `CloseAll` | `Force: Boolean = False`、戻り値 `Boolean` | ― | すべて閉じる。変更があれば聞く。`Force = True` なら聞かずに捨てる。閉じ終わると、空の無題が 1 枚残る。途中でキャンセルされたら `False`（残りはそのまま） |
| `CanCloseAll` | 戻り値 `Boolean` | ― | フォームを閉じるときの確認。保存していないタブを確認するが、閉じはしない。キャンセルされたら `False` |
| `FindPage` | `const AFileName: string`、戻り値 `Integer` | ― | そのファイルを開いているタブの番号。なければ -1。大文字・小文字は区別しない。ファイルは読まない |
| `MovePage` | `AFromIndex, AToIndex: Integer` | ― | タブの並び順を変える。中身は変わらない |
| `ActiveIndex` | `Integer` | 読み・書き | 見えているタブの番号（0 から）。書くと、そのタブに切り替わる。範囲の外・同じ番号は何もしない |
| `PageCount` | `Integer` | 読み | タブの数（常に 1 以上） |
| `Pages[AIndex]` | `TCMPage` | 読み | n 番のタブ（4章）。範囲の外は例外 |

## 6. 画面の上での操作とイベント（ed）

### 6.1 プロパティ・メソッド

すべて、見えているタブが対象。

| 名前 | 型・引数 | 読み書き | 中身 |
|---|---|---|---|
| `SelText` | `string` | 読み・書き | 読むと、選択中の文字列（選んでいなければ ''）。書くと、選択範囲をその文字列に置き換える。選んでいなければ、カーソル位置に入れる。'' を書くと、選択範囲を消す。改行は #13・#10・#13#10 のどれを渡しても改行として扱い、文書の改行コードにそろえて入れる。Undo 1 回で戻る。置き換えたあとは、置き換えた文字列の後ろにカーソルが来る（選択は外れる）。`ReadOnly` のときは、書いても何も起きない |
| `SelStart` | `Integer` | 読み | 選択の開始位置（選んでいなければカーソル位置）。文書の先頭から 0 始まり、UTF-16 単位（絵文字などは 2）。改行は文書の改行コードの文字数（CRLF は 2、LF は 1）。範囲を選ぶときは `SetSelection` |
| `SelLength` | `Integer` | 読み | 選択の文字数（数え方は `SelStart` と同じ）。0 なら選んでいない |
| `CanUndo` | `Boolean` | 読み | Undo できるか |
| `CanRedo` | `Boolean` | 読み | Redo（やり直し）できるか |
| `GetCursorPos` | `out ALine, AColumn: Integer` | ― | カーソルの位置。行と桁は 1 から。桁は UTF-16 単位 |
| `SetCursorPos` | `ALine, AColumn: Integer` | ― | カーソルを動かす |
| `SetSelection` | `AStartLine, AStartCol, AEndLine, AEndCol: Integer` | ― | 範囲を選ぶ |
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
| `DeleteToEnd` | ― | ― | カーソル位置から文書の末尾までを消す。選んでいても選択は無視する。Undo 1 回で戻る。`ReadOnly` なら何もしない |
| `DeleteToStart` | ― | ― | カーソル位置から文書の先頭までを消す。決め事は `DeleteToEnd` と同じ |
| `DuplicateLine` | ― | ― | カーソル行を複製して下へ移る（`Shift+F10` と同じ。複数行を選んでいれば、その行をまとめて複製）。Undo 1 回で戻る。`ReadOnly` なら何もしない |
| `ToggleOverwrite` | ― | ― | 挿入と上書きを切り替える（`Insert` キーと同じ） |
| `Find` | `const S: string; AOptions: TCMFindOptions; AForward: Boolean = True` | ― | 検索して、見つかった所を選ぶ。結果は `OnFindDone` |
| `FindNext` | ― | ― | 直前の検索語で次を検索（`F5`）。検索語がなければ検索ダイアログを開く |
| `FindPrev` | ― | ― | 直前の検索語で前を検索（`Shift+F5`） |
| `Replace` | `const S, R: string; AOptions: TCMFindOptions` | ― | 選んでいる所が S なら R に置き換え、次を検索する。`ReadOnly` なら何もしない |
| `ReplaceAll` | `const S, R: string; AOptions: TCMFindOptions` | ― | すべて置き換える。結果（件数）は `OnReplaceAllDone`。Undo 1 回で戻る。`ReadOnly` なら何もしない |
| `ShowFindDialog` | `const InitialText: string = ''` | ― | 検索・置換ダイアログを開く（`Ctrl+F` と同じ。10章） |
| `CanPrint` | 戻り値 `Boolean` | ― | 印刷できるか（タブがあれば `True`） |
| `Print` | ― | ― | 印刷ダイアログを開く（11.6）。プレビューを出していなければ、印刷の間だけ出す |
| `SetFocus` | ― | ― | エディタにカーソルを置き、入力できる状態にする。今の処理（ボタンのクリック、`OnKeyDown`・`OnReady` など）が終わってから移す（どこから呼んでもよい）。見えない・使えないエディタでは何もしない |
| `SearchText` | `string` | 読み・書き | 直前の検索語 |
| `ReplaceText` | `string` | 読み・書き | 直前の置換語 |
| `SearchOptions` | `TCMFindOptions` | 読み・書き | 直前の検索オプション |
| `TopLine` | `Double` | 読み | 表示している先頭の行（小数は行の中の位置） |
| `Ready` | `Boolean` | 読み | Monaco の準備ができたか |
| `Monaco` | `TCMMonacoView` | 読み | 中のエディタ部品（上級者向け。`Monaco.PopupMenu` に項目を足すなど。15.6） |
| `Preview` | `TCMMarkdownPreview` | 読み | 中のプレビュー部品（上級者向け） |

### 6.2 イベント

`Sender` は、必ずそのエディタ（TCMonacoEditor）。1 つのイベントの処理を、複数のエディタで共用できる（`Sender as TCMonacoEditor` で見分ける）。

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnReady` | `Sender: TObject` | Monaco の準備ができた。見えない場所（`TPageControl` の選ばれていないシートなど）に置いたエディタは、初めて表示されたときに準備を始める（それまでは、本文などは部品の中に預かる） |
| `OnChange` | `Sender: TObject` | 見えているタブの本文を、人が編集した（入力が止まって約 0.1 秒後） |
| `OnCursorChange` | `Sender: TObject; Line, Column: Integer` | カーソルが動いた |
| `OnModeChange` | `Sender: TObject; IsOverwrite: Boolean` | 挿入と上書きが切り替わった |
| `OnModifiedChange` | `Sender: TObject` | 見えているタブの ` *` が付いた・消えた |
| `OnActiveChange` | `Sender: TObject` | 見えているタブが切り替わった |
| `OnDocListChange` | `Sender: TObject` | タブが増えた・減った・並び替えた（最後の 1 枚を閉じて空の無題ができたときも 1 回） |
| `OnDocumentChange` | `Sender: TObject; Index: Integer` | タブの名前・言語・` *` が変わった |
| `OnSave` | `Sender: TObject; const AFileName: string` | 保存した |
| `OnQueryClose` | `Sender: TObject; Index: Integer; var CanClose: Boolean` | 保存していないタブを閉じる・置き換える前（9.5） |
| `OnNeedFileName` | `Sender: TObject; var AFileName: string; var Cancel: Boolean` | 無題を保存するとき、名前を決める |
| `OnFileDrop` | `Sender: TObject; Files: TStrings; var Handled: Boolean` | ファイルがドロップされた。`Handled := True` で標準の開く処理を止める |
| `OnOpenMarkdown` | `Sender: TObject; const AFileName: string` | プレビューの `.md` へのリンクが押された |
| `OnToggleMaximize` | `Sender: TObject` | `F12` が押された（最大化はアプリ側で作る） |
| `OnFontSizeChange` | `Sender: TObject` | `Ctrl+ホイール` で文字の大きさが変わった |
| `OnLineNumbersChange` | `Sender: TObject` | `F11` で行番号が切り替わった |
| `OnFindDone` | `Sender: TObject; Found: Boolean` | 検索の結果（ダイアログからの検索でも、`Find` などでも出る） |
| `OnReplaceAllDone` | `Sender: TObject; Count: Integer` | すべて置換の結果 |
| `OnPopup` | `Sender: TObject` | 右クリックメニューを出す直前 |
| `OnGetTabImageIndex` | `Sender: TObject; Index: Integer; const FileName: string; var ImageIndex: Integer` | タブのアイコンを決めるとき（`TabImages` を設定したときだけ。9.3） |
| `OnTabDragOut` | `Sender: TObject; Index, X, Y: Integer; var TearOff: Boolean` | タブがアプリのウィンドウの外へ落とされた（9.9）。`Index` はそのタブの番号、`X`・`Y` は落とした画面の位置。`TearOff := False` で部品の分離・結合をやめる |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | ショートカット用のキーが押された（9.6）。`Key := 0` で内蔵の動きを止める |
| `OnError` | `Sender: TObject; const AMessage: string` | エディタとプレビューの、すべてのエラー |

**設定しないときの既定の動き**

| 名前 | 設定しないとき |
|---|---|
| `OnError` | メッセージを表示する。同じメッセージは 1 回だけ表示する（エディタを複数貼ったとき、起動時に同じエラーが何度も出ないようにするため） |
| `OnNeedFileName` | `SaveDialog`（設定しないときは内蔵のもの）を出す |
| `OnQueryClose` | `ConfirmOnFormClose` に従う（9.5） |
| `OnOpenMarkdown` | そのエディタで開く |
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
| `FindDialog` | `TCMFindDialog` | nil | 検索・置換ダイアログ。設定しないときは内蔵の共有ダイアログ（10章） |
| `TabFlat` | `Boolean` | `True` | `True`＝四角／`False`＝台形 |
| `TabSeparator` | `Boolean` | `False` | 選んでいないタブの間に細い縦線を入れるか。`TabFlat = True` のときだけ効く |
| `TabIcons` | `Boolean` | `True` | タブにアイコンを出すか（9.3） |
| `TabImages` | `TImageList` | nil | 自分で用意したアイコンの画像リスト。設定しないときは Windows のアイコンを自動で出す（9.3） |
| `WordWrap` | `Boolean` | `True` | 折り返し |
| `LineNumbers` | `Boolean` | `False` | 行番号。`F11` でも切り替わる |
| `FontSize` | `Integer` | 14 | 文字の大きさ（6〜72） |
| `TabSize` | `Integer` | 4 | タブ幅（1〜16） |
| `Folding` | `Boolean` | `True` | 折りたたみ |
| `MatchBrackets` | `Boolean` | `True` | 括弧の対応を出す |
| `OccurrencesHighlight` | `Boolean` | `True` | カーソル位置の単語と同じ単語を強調する |
| `Minimap` | `Boolean` | `False` | ミニマップ。`Ctrl+Shift+M` でも切り替わる |
| `Theme` | `TCMTheme` | `ctAuto` | 配色。`ctAuto`（OS の配色に合わせる。OS を切り替えるとその場で変わる）／`ctLight`（明るい配色で固定）／`ctDark`（暗い配色で固定）。プレビューも合わせる |
| `ReadOnly` | `Boolean` | `False` | 読み取り専用 |
| `JapaneseUI` | `Boolean` | `True` | Monaco の日本語表示（`editor.main.nls.ja.js` が無いときは `False` にする） |
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
| `MonacoPath` | `string` | '' | `editor.html` と `vs` の場所（2.3） |
| `ShowPreview` | `Boolean` | `False` | プレビューを出すか（11.2）。`Ctrl+Shift+V` でも切り替わる |
| `PreviewWidth` | `Integer` | 500 | プレビューの幅。境目で変えた幅も、ここに入る |
| `SplitterResizeStyle` | `TResizeStyle` | `rsLine` | 境目をドラッグしている間の表示（`TSplitter.ResizeStyle` と同じ） |
| `SplitterWidth` | `Integer` | 5 | 境目の幅 |
| `PreviewFontSize` | `Integer` | 16 | プレビューの文字の大きさ（8〜48） |
| `ColorScheme` | `TCMColorScheme` | `csEditor` | プレビューの配色。`csEditor`（エディタと同じ配色）／`csGitHub`（GitHub 風） |
| `PreviewBackColorLight` | `TColor` | #FFFFFE | `csEditor` のときのプレビューの背景色（明るい配色） |
| `PreviewBackColorDark` | `TColor` | #1E1E1E | 同（暗い配色） |
| `PreviewTextColorLight` | `TColor` | #000000 | プレビューの文字色（明るい配色） |
| `PreviewTextColorDark` | `TColor` | #D4D4D4 | 同（暗い配色） |
| `PreviewLinkColorLight` | `TColor` | #006AB1 | プレビューのリンクの色（明るい配色） |
| `PreviewLinkColorDark` | `TColor` | #3794FF | 同（暗い配色） |
| `BreakOnNewline` | `Boolean` | `False` | 1 つの改行も改行として表示するか |
| `AllowRemoteImages` | `Boolean` | `False` | ネット（http）の画像を表示するか（11.4） |
| `SyncScroll` | `TCMSyncScroll` | `ssBoth` | エディタとプレビューのスクロールを合わせるか（11.5） |
| `PreviewDelayMs` | `Integer` | 300 | 編集してからプレビューを更新するまでの時間（ミリ秒） |
| `PreviewPath` | `string` | '' | `preview.html` の場所（2.3） |
| `Align` | `TAlign` | | 親の中での配置 |
| `Anchors` | `TAnchors` | | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `BorderSpacing` | `TControlBorderSpacing` | | 周りの余白 |
| `Constraints` | `TSizeConstraints` | | 大きさの上限・下限 |
| `Enabled` | `Boolean` | | 使えるか |
| `Visible` | `Boolean` | | 表示するか |
| `TabOrder` | `TTabOrder` | | Tab キーで移る順番 |
| `TabStop` | `Boolean` | | Tab キーで止まるか |

- `LineDelimiters`・`LineSkipEmpty`・`LineQuoteChar` は、オブジェクトインスペクタには出ない。コードで設定する（13章）。

**色の設定（名前が `Color` で終わる 12 個）**

- オブジェクトインスペクタで、色の一覧か「...」の色ダイアログから選ぶ。
- システム色（`clWindow` など）を選んだときは、設定したときのその色になる。OS の配色を切り替えても、その色は変わらない。
- `clDefault`・`clNone` を選んだときは、既定値の色になる。

**内蔵のダイアログ**

| 項目 | 内容 |
|---|---|
| フィルター | Markdown（*.md; *.markdown）／テキスト（*.txt）／すべてのファイル（*.*） |
| 保存の既定の拡張子 | そのタブの言語から決める（markdown→md、plaintext→txt、pascal→pas、html→html、css→css、javascript→js、json→json、xml→xml、sql→sql、ini→ini、bat→bat、python→py、cpp→cpp、csharp→cs、typescript→ts、java→java、shell→sh、powershell→ps1、yaml→yaml、php→php、go→go） |
| 最初のフォルダー | そのタブのフォルダー。無題なら、前に使ったフォルダー |

**使わないもの**

中身は WebView2（別のプロセス）で、キー入力・マウス・フォーカスは WebView2 の中で起きるため、次のものは出していない。

| 種類 | 出していないもの・理由 |
|---|---|
| キー | `OnKeyUp`・`OnKeyPress`・`OnUTF8KeyPress`（エディタの中で処理され、知らせが来ない）。`OnKeyDown` だけ使える（9.6） |
| フォーカス | `OnEnter`・`OnExit`・`Focused`（フォーカスは WebView2 の中にある）。フォーカスを移すときは `SetFocus` |
| マウス | `OnClick`・`OnDblClick`・`OnMouseDown` など（WebView2 の中で処理され、知らせが来ない） |
| 見た目 | `Color`・`Font`・`BevelOuter` など（`Theme`・`FontSize` などで決める） |
| 右クリックメニュー | `PopupMenu`（内蔵のメニューを使う。項目を足すときは 15.6） |
| 文字列 | パネルの見出しとしての `Caption`・`Text`（`Text`・`Caption` は、見えているタブの本文・タイトル） |

## 8. キー

### 8.1 内蔵のショートカット

WebView2 の既定の動き（再読み込み、開発者ツール、印刷など）は止めてある。キーは、フォーカスのあるエディタだけが受ける。次のショートカットは、すべて `OnKeyDown` で置き換えられる（9.6）。

| キー | 動作 |
|---|---|
| `Ctrl+S` | 見えているタブを保存する。無題なら `OnNeedFileName`（設定しないときは保存ダイアログ） |
| `Ctrl+F` | 検索・置換ダイアログを開く。1 行の範囲を選んでいれば、最初の検索語にする |
| `F5` / `Shift+F5` | 直前の検索語で、次を検索 / 前を検索。検索語がなければ、ダイアログを開く |
| `Ctrl+Shift+V` | プレビューの表示と非表示を切り替える（11.2）。すべての言語のタブで効く |
| `Ctrl+Shift+P` | 何もしない（WebView2 の「システムのダイアログで印刷」を止める）。フォームに同じショートカットがあれば、そちらを実行する |
| `Ctrl+P` | 印刷する（`Print` と同じ。11.6）。フォームに同じショートカット（印刷の標準アクションなど）があっても、内蔵が先（動きは同じ） |
| `Ctrl+Shift+M` | ミニマップの表示と非表示を切り替える（`Minimap`） |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | 次のタブ / 前のタブへ切り替える（端まで行ったら反対側へ戻る）。`MultiDocument = False` のときは何もしない |
| `Shift+F10` | カーソル行を複製して下へ移る（`DuplicateLine` と同じ） |
| `F11` | 行番号の表示と非表示を切り替える |
| `F12` | `OnToggleMaximize` を出す |
| `Insert` | 挿入と上書きを切り替える。上書きのときはブロックのカーソル |
| `Ctrl+ホイール` | 文字の大きさを変える |
| `Ctrl+A` | すべて選ぶ |

### 8.2 Monaco に最初からあるショートカット

Monaco に最初から入っているショートカットのうち、主なものを確かめた結果。ここにないものも、`F1` のコマンドパレットで探して実行できる。

| キー | 動作 | 結果 |
|---|---|---|
| `F1` | コマンドパレット（全機能を一覧・検索して実行できる） | 使える |
| `Alt+↑` / `Alt+↓` | 行を上下に動かす | 使える |
| `Shift+Alt+↑` / `Shift+Alt+↓` | 行を上下に複製 | 使える |
| `Ctrl+]` / `Ctrl+[` | インデント / 逆インデント | 使える |
| `Ctrl+/` | 行コメントの切り替え。言語のコメントの書き方を使う（pascal は `//`、markdown は `<!-- -->`） | 使える |
| `Ctrl+D` | 同じ単語を次々に足して選ぶ（マルチカーソル）。入力すると、選んだ所がすべて同時に書き換わる | 使える |
| `Shift+Alt+ドラッグ` | 四角い範囲を選ぶ | 使える |
| `Ctrl+G` | 指定した行へ移る | 使える |
| `Ctrl+Shift+[` / `Ctrl+Shift+]` | 折りたたむ / 開く | 使える |
| `Ctrl+Enter` | 下に空の行を入れる | 使える |
| `Ctrl+Shift+Enter` | 上に空の行を入れる（実際には下に入る） | 使えない |
| `Ctrl+Shift+K` | 行を消す | 使えない |

- マルチカーソルは、`Esc` でカーソル 1 つに戻る。

## 9. 動き

### 9.1 MultiDocument

`MultiDocument` 1 つで、タブの表示と、開くときの動きをまとめて切り替える。1 つのフォームに複数貼って、それぞれ 1 ファイルずつ扱うときは、各エディタで `MultiDocument = False` にする。

| | `True`（タブあり、既定値） | `False`（1 ファイルだけ） |
|---|---|---|
| タブの表示 | 表示する | 表示しない（その分、エディタが広くなる） |
| ファイルを開く | 新しいタブで開く | タブはそのままで、中身を入れ替える（保存していなければ確認する） |
| 新規 | タブを足す | 中身を空にする（保存していなければ確認する） |
| 閉じる（`Close`・`CloseAll`） | タブを閉じる（最後の 1 枚なら空の無題が残る） | 中身を空にする（保存していなければ確認する）。タブは増減しないので、`OnDocListChange`・`OnActiveChange` は出ない |
| ファイルのドロップ | 新しいタブで開く | 中身を入れ替える（最初のファイルだけ） |

- タブを隠すと、ファイル名と ` *` は表示されない。保存していない内容は、9.5 の確認で扱う。

**タブの操作（`MultiDocument = True`）**

| 操作 | 動き |
|---|---|
| ［＋］ | 新しい文書を足す |
| ［×］、中ボタンのクリック | 閉じる。保存していなければ 9.5 の確認をする |
| ドラッグ | タブを並べ替える。エディタの文書の順番も入れ替わる |
| ウィンドウの外へドラッグ | `TabTearOff = True`（既定値）なら、そのタブを別のウィンドウで開く。同じ EXE の別のウィンドウのエディタへ落とすと、そこに新しいタブで開く（9.9）。同じウィンドウ・同じアプリの中の別のエディタへ落としても、何も起きない（タブは移らない） |
| マウスを乗せる | フルパスのヒントが出る |

- 文書ごとに、ファイル名・文字コード・BOM・` *`・Undo/Redo の履歴・カーソル位置・スクロール位置・言語を持つ。切り替えて戻ると、それらが戻る。
- 起動直後は、無題の文書が 1 つある。`OpenFile` は、この無題を使わず、必ず新しいタブで開く。
- 検索・置換の対象は、見えているタブだけ。

### 9.2 ファイルと言語

- 読み込むときに、文字コードを判定する。BOM があれば BOM に従い、無ければ UTF-8 として正しいかを調べ、正しくなければ CP932（Shift_JIS）とする。
- 保存するときは、読み込んだときの文字コードと BOM を使う。
- CP932 で表せない文字があると、保存のときに例外になる。`Encoding` を UTF-8 に変えてから保存する。
- 改行コード（CRLF / LF）は、読み込んだときのものを使う。改行のない新しい文書は CRLF。
- 言語は、`LoadFromFile`・`OpenFile` のときに拡張子から決める。名前を付けて保存して拡張子が変わったときも、言語を切り替える。

| 拡張子 | 言語 |
|---|---|
| .pas .pp .lpr .inc .dpr .lpk | pascal |
| .md .markdown | markdown |
| .txt | plaintext |
| .html .htm / .css / .js / .json / .xml | html / css / javascript / json / xml |
| .sql / .ini .cfg / .bat .cmd / .py / .c .h .cpp .hpp | sql / ini / bat / python / cpp |
| .cs | csharp |
| .ts .tsx | typescript |
| .java | java |
| .sh .bash | shell |
| .ps1 .psm1 .psd1 | powershell |
| .yml .yaml | yaml |
| .php | php |
| .go | go |
| それ以外 | `DefaultLanguage`（既定値は pascal） |

- Pascal の色分けは、キーワード・コメント・文字列・数値が中心で、Lazarus 独自の書き方までは区別しない（Monaco の定義のまま）。

### 9.3 タブのアイコン

ファイルの種類ごとに、エクスプローラーと同じ Windows のアイコンを、タブの左端に自動で出す。既定値（`TabIcons = True`、`TabImages` なし）のままで出る。

| 場面 | 出すアイコン |
|---|---|
| ファイルを開いたタブ | そのファイルの拡張子のアイコン |
| 無題のタブ | テキストのアイコン（.txt のアイコン） |
| 名前を付けて保存して、拡張子が変わった | 新しい拡張子のアイコン |

- ファイルの関連付けに従う（例：.md を VS Code に関連付けていれば、VS Code のアイコン）。
- アイコンを消したいときは、`TabIcons = False` にする。

**自分で用意したアイコンを使う**

1. フォームに `TImageList` を貼り、アイコンを入れる。
2. `TabImages` で、その画像リストを選ぶ。
3. `OnGetTabImageIndex` で、タブごとに使う番号を決める（`ImageIndex := -1` でアイコンなし）。設定しないときは、全タブで 0 番を使う（15.9）。

### 9.4 配色

- `Theme = ctAuto`（既定値）なら、OS のダーク / ライトに従う。実行中に OS を切り替えても、エディタ・プレビュー・タブ・境目・背景がその場で塗り替わる。
- `ctLight`・`ctDark` なら、OS に関係なくその配色で固定する。
- タブ・境目・背景は、Windows 11 のエクスプローラーに近い配色にする。見えているタブは、エディタの背景と同じ色にして、本文とつながって見える。

| 部分 | ダーク | ライト |
|---|---|---|
| タブの帯・選んでいないタブ | #2B2B2B | #F0F0F0 |
| マウスを乗せたタブ | #383838 | #E5E5E5 |
| 見えているタブ | #1E1E1E | #FFFFFF |
| 見えているタブの文字 | #FFFFFF | #000000 |
| 選んでいないタブの文字 | #C5C5C5 | #5C5C5C |
| ［×］・スクロールの矢印 | #C5C5C5 | #5C5C5C |
| 区切り線・タブの枠 | #3A3A3A | #D9D9D9 |
| 境目 | #2B2B2B | #E5E5E5 |
| 背景（起動直後に一瞬見える所） | #1E1E1E | #FFFFFF |

- 検索で見つかった所は、エディタにフォーカスがない間（検索ダイアログを操作している間）、`HitColorLight`・`HitColorDark` で表示する。エディタをクリックすると、普通の選択の色に戻る。
- カーソル行は、背景の色だけで目立たせる（枠線なし）。

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
- フォームを閉じるときに 1 つでもキャンセルされたら、その時点で終了をやめる。残りの文書とエディタは確かめない。

### 9.6 キーを足す・置き換える（OnKeyDown）

キー入力は WebView2（別のプロセス）の中で処理されるため、フォームの `KeyPreview` やいつものキー処理は、エディタにフォーカスがある間は効かない。代わりに `OnKeyDown` を使う。

| 項目 | 中身 |
|---|---|
| 知らせるキー | Ctrl・Alt との組み合わせ、F1〜F12、Esc など（ショートカット用のキー）。普通の文字の入力は知らせない |
| 内蔵の動きの置き換え | `Key := 0` にすると、キーはエディタに届かず、内蔵の動きは起きない |
| 置き換えられる範囲 | 8.1 の内蔵のショートカットはすべて。Monaco の操作（Ctrl+Z、Ctrl+C など）も置き換えられる |
| フォームのショートカット | 内蔵のショートカットに使っていないキーは、フォームのメニュー・ActionList のショートカットへ回す（エディタにフォーカスがあっても、メニューの Ctrl+O などが効く） |

**キーが処理される順番**

1. 継承した部品の `KeyDown`（override していれば）
2. `inherited` の中で、`OnKeyDown`
3. ここまでで `Key <> 0` のままなら、内蔵のショートカットのキーは、内蔵の動きをする
4. 内蔵に使っていないキーは、フォームのメニュー・ActionList のショートカットへ回す。実行されたら、そのキーはエディタには渡さない
5. どれでもなければ、そのままエディタに届く

- 「内蔵のショートカットのキー」は、8.1 のキーと、`Ctrl+Z`・`Ctrl+Y`・`Ctrl+Shift+Z`・`Ctrl+X`・`Ctrl+C`・`Ctrl+V`。これ以外の Monaco のキー（`Ctrl+D` など）は、フォームに同じショートカットがあれば、フォームが先。
- フォームのメニュー・アクションは、キーの知らせが終わってから実行する。

**継承して自分の部品を作るとき**

TCMonacoEditor は、protected の virtual メソッド `KeyDown(var Key: Word; Shift: TShiftState)` を持つ（LCL の TWinControl と同じ形）。`inherited` を呼ぶと、その中で `OnKeyDown` が呼ばれる。呼ばなければ `OnKeyDown` も呼ばれない（15.12）。

### 9.7 右クリックメニュー

| 状態 | 出る項目 |
|---|---|
| 文字列を選んでいる | 切り抜き、コピー、貼り付け、引用付きコピー、追加切り抜き、追加コピー、削除、TO UPPER CASE、to lower case、ﾊﾝｶｸに変換、全角ひらがなに変換、全角カタカナに変換、TAB -> 空白、空白 -> TAB、インデント、逆インデント |
| 選んでいない | 貼り付け、すべて選択、元に戻す、やり直し |
| いつも（最後） | 区切り線、ミニマップ　Ctrl+Shift+M、プレビュー　Ctrl+Shift+V |

- ミニマップ・プレビューは、それぞれ `Minimap`・`ShowPreview` を切り替える。今の値のときにチェックが付く。いつも使える（`ReadOnly` でも）。エディタの全タブに効く。切り替えた状態は実行中だけで、次の起動ではオブジェクトインスペクタの値に戻る。
- `ReadOnly` のときは、編集の項目が使えない。
- 変換の項目は、変換した文字列が選ばれたまま残り、Undo 1 回で戻る。
- 「引用付きコピー」は、各行の先頭に `QuotePrefix` を付けてコピーする。「追加切り抜き」「追加コピー」は、クリップボードの今の中身の後ろに足す。
- 自分の項目を足すときは、`ed.Monaco.PopupMenu.Items.Add` を使う（15.6）。表示の調整は `OnPopup` で行う。自分の項目は、上の項目の後ろに並ぶ。
- プレビューの右クリックメニューは、コピー、すべて選択、印刷...（11.6）。

### 9.8 ファイルのドロップ

- エディタにファイルをドロップすると開く。`MultiDocument = True` なら新しいタブで開き（開いていればそのタブへ切り替える）、複数のファイルはすべて開く。`MultiDocument = False` なら、今の文書を入れ替える（保存していなければ 9.5 の確認をする）。
- フォルダーは無視する。
- `OpenDroppedFiles := False`、または `OnFileDrop` で `Handled := True` にすると、標準の処理を止められる。
- タブの帯（上の部分）へのドロップには、対応していない。

### 9.9 タブの分離と結合（TabTearOff）

タブを、アプリのウィンドウの外へドラッグして離すと、落とした先によって次のようになる。

| 落とした先 | 動き |
|---|---|
| デスクトップ・ほかのアプリのウィンドウの上 | 分離：同じ EXE をもう 1 つ起動して、そのタブを開く。元のウィンドウからは、そのタブが消える |
| 同じ EXE の別のウィンドウ（別に起動したもの）の、エディタの上（タブの帯・本文・プレビュー） | 結合：そのエディタに新しいタブを作って開く。元のウィンドウからは、そのタブが消える |
| 同じ EXE の別のウィンドウの、エディタではない所（メニュー・ボタンなど） | 何も起きない |
| 自分のアプリの中（エディタ・プレビュー・別のフォーム・別のエディタのタブの帯） | 何も起きない |

| 設定 | 動き |
|---|---|
| `TabTearOff = True`（既定値） | 部品が分離・結合をすべて行う。アプリのコードは要らない |
| `TabTearOff = False` | 分離も結合もしない。ほかのウィンドウから落とされたタブも受けない。`OnTabDragOut` は来るので、自分で分離を作れる（15.14） |

**引き継ぐもの**（分離・結合とも）

| 項目 | 引き継ぎ |
|---|---|
| 本文 | 引き継ぐ（保存していない編集も） |
| ファイル名 | 引き継ぐ |
| 文字コード・言語 | 引き継ぐ |
| 変更した印（` *`） | 引き継ぐ |
| Undo の履歴・カーソル位置・スクロール位置 | 引き継がない |

**開き方**（分離・結合とも）

| 元のタブ | 開き方 |
|---|---|
| ファイルを開いていて、変更なし | そのファイルを開く（` *` なし） |
| ファイルを開いていて、変更あり | そのファイル名で、保存していない本文のまま開く（` *` あり） |
| 無題（まだ保存していない） | 無題のまま、本文を入れて開く（本文があれば ` *` あり。保存すると、名前を付けて保存のダイアログが出る） |
| ファイル名はあるが、ディスクのファイルが消えている | 無題のまま、本文を入れて開く（` *` あり） |

**分離の決まり**

- 新しいウィンドウは、タブを落とした位置に出る。画面からはみ出すときは、収まるように寄せる。
- 新しいウィンドウの中身は、WebView2 と Monaco の起動を待つため、1〜2 秒遅れて出る。
- 新しいウィンドウで受けるのは、元と同じ名前（フォームの `Name` とエディタの `Name`）で、`TabTearOff = True` のエディタ。1 つのフォームにエディタが複数あっても、元と同じエディタに開く。
- フォームに貼ったエディタ（`.lfm`）は、新しいウィンドウが最初から落とした位置に出る。コードで作ったエディタ（15.13）は、表示の後で落とした位置へ動くので、一瞬動いて見える。
- 新しいウィンドウを起動できなかったときは、タブを閉じずに残し、`OnError` で知らせる。
- 二重起動を禁止しているアプリでは、新しいウィンドウを起動できないので分離できない。
- 受け渡しには、環境変数 `CM_TEAROFF` を使う（起動する新しい EXE にだけ渡す。起動パラメータは使わない）。アプリでは、この名前の環境変数を使わない。

**結合の決まり**

- 受けるのは、落とした位置の下にある、相手のウィンドウのエディタ。新しいタブは、そのエディタの見えるタブになり、相手のウィンドウが前に出る。
- 相手のエディタが、同じファイルをすでに開いているときは、結合しない。相手のそのタブに切り替えて、相手のウィンドウを前に出す。元のタブは残る。
- 相手のエディタが `TabTearOff = False` または `MultiDocument = False` のときは、何も起きない。
- 相手のウィンドウが応答しない（3 秒）・管理者として動いているときは、移せない。元のタブを残し、`OnError` で知らせる。

**共通の決まり**

- 何も入っていない無題が 1 枚だけのときは、分離も結合もしない（`OnTabDragOut` は来る。その `TearOff` の値が `False` で来るので、`True` にすれば分離・結合する）。
- 外へ出したタブが最後の 1 枚なら、元のウィンドウには空の無題が 1 枚残る（タブは常に 1 枚以上）。
- `Esc` でドラッグをやめたときは、何も起きない。
- `MultiDocument = False` のときは、タブが出ないので操作できない。
- ドラッグ中、アプリのウィンドウの外ではマウスカーソルが「落とせない」形になるが、離せば分離・結合する。

## 10. 検索・置換ダイアログ

- `FindDialog` を設定しないエディタは、フォームに 1 つだけの内蔵の共有ダイアログを使う。エディタを何個貼っても、ダイアログは 1 つ。
- 対象は、`Ctrl+F` を押したエディタ（最後にフォーカスされたエディタ）。ダイアログを開いたまま別のエディタをクリックすると、対象がそちらに切り替わる。
- タイトルに対象を出す（例：「検索・置換 - readme.md」）。
- ダイアログの位置、検索語、置換語、履歴、オプションは、全エディタで共通。
- 自分で制御するときは、パレットから `TCMFindDialog` をフォームに 1 つ貼り、各エディタの `FindDialog` で選ぶ。複数のエディタが同じダイアログを選べる。

| 項目 | 中身 |
|---|---|
| 検索語・置換語 | 履歴付きのコンボボックス |
| オプション | 大文字小文字の区別、単語単位、ループ検索（正規表現はない） |
| ボタン | 次を検索、前を検索、置換、すべて置換、閉じる。`Enter` で次を検索、`Esc` で閉じる |
| 結果 | ダイアログの下に「見つかりません」「N 件置換しました」と出す |

- 置換は、選んでいる文字列が検索語と同じなら置き換えて次を検索する。「すべて置換」は Undo 1 回で戻る。

## 11. プレビュー（Markdown・コード）

### 11.1 しくみ

- 中身は、ファイルではなくエディタの本文から取る。保存していない編集も表示される。編集の後 `PreviewDelayMs` 待ってから更新する。タブを切り替えたときは、すぐに更新する。
- ライブラリはすべて preview フォルダーにあり、オフラインで動く。

| ライブラリ | 用途 |
|---|---|
| marked | Markdown を HTML にする（GFM の表、タスクリスト） |
| DOMPurify | 作った HTML を無害にする（スクリプトなどを取り除く） |
| highlight.js | コードの色分け（delphi、dos、powershell を足している） |
| github-markdown-css | 見た目のもと（ライト / ダーク） |
| mermaid | Mermaid の図（11.7） |

### 11.2 表示する・しない

- `ShowPreview` で決める（既定値は `False`）。`Ctrl+Shift+V` で切り替わる。どの言語のタブでも出る。
- タブを切り替えると、切り替えたタブの内容を出す（Markdown は文書、それ以外は色分けしたコード）。
- Markdown かどうかは、タブの言語で決める。
- プレビューの WebView2 は、初めて表示したときに作る。一度も出さなければ作らない（メモリを使わない）。
- プレビューの幅は、境目で変えられる。変えた幅は `PreviewWidth` に入り、次に出したときも使う。

### 11.3 Markdown の表示と配色

- 表（GFM）、タスクリスト、コードブロックの色分けに対応する。言語を書いていないコードブロックは、色分けしない。
- 既定では、エディタと同じ配色にする（`PreviewBackColor…`・`PreviewTextColor…`・`PreviewLinkColor…`）。表の罫線、コードブロックの背景は、背景色と文字色から自動で決める。
- コードブロックの色分けも、エディタの色に近づける。ただし、エディタ（Monaco）とプレビュー（highlight.js）は色分けのしくみが違うので、完全には同じにならない。括弧の色分けはしない。
- `ColorScheme := csGitHub` にすると、GitHub 風の配色になる。
- 文字は `Segoe UI`、`Yu Gothic UI`、`Meiryo` の順。
- 先頭の YAML（`---` で囲んだ部分）は表示しない。
- タスクリストのチェックボックスは、表示だけ（クリックしても本文は変わらない）。
- スクリプトは取り除くので、外から来た Markdown を開いても動かない。

**コード（Markdown 以外のタブ）**

| 項目 | 中身 |
|---|---|
| 表示 | 本文全体を、行番号付きの色分けしたコードとして出す |
| 色分け | タブの言語を highlight.js の言語に読み替える（例：pascal → delphi、bat → dos）。対応しない言語と plaintext は、色分けしない |
| 長い行 | 折り返す（行番号は、折り返した先頭の行にだけ付く） |
| 大きなファイル | 50 万文字を超えるファイルは、色分けしない（行番号付きの表示はする）。6 万行で約 1.5 秒かかる（プレビューの中の処理なので、エディタの入力は止まらない） |
| コピー | 行番号はコピーされない |
| 文字 | 等幅（`Consolas`、`BIZ UDゴシック`、`MS ゴシック` の順） |

### 11.4 リンクと画像

- 画像は、相対パス（開いているファイルのフォルダーから数える）でも、`C:\...` のような絶対パスでも表示する。
- ネット（http）の画像は、`AllowRemoteImages = True` でなければ表示しない。
- 外へのリンク（`http`、`https`、`mailto`）は、既定のブラウザで開く。プレビューの中では移動しない。
- `.md` へのリンクは、`OnOpenMarkdown` を設定していなければ、そのエディタで開く（`MultiDocument` に従う）。
- `#見出し` へのリンクは、プレビューの中でスクロールする。
- そのほかのファイルへのリンクは、安全のため開かない。

### 11.5 スクロールを合わせる

| `SyncScroll` | 動き |
|---|---|
| `ssBoth`（既定値） | 両方向。エディタを動かすとプレビューが、プレビューを動かすとエディタが合わせる |
| `ssEditorToPreview` | エディタからプレビューへだけ |
| `ssNone` | 合わせない |

- 行番号で合わせる。折り返しの多い長い段落の中では、多少ずれる。
- 画像の読み込みなどで高さが変わったら、合わせ直す。

### 11.6 印刷

- プレビューの右クリックの「印刷...」、`Ctrl+P`（エディタ・プレビューのどちらにフォーカスがあっても）、`Print` で、Edge と同じ印刷ダイアログを出す。プリンター・PDF として保存・ページ・部数などは、すべてダイアログで選ぶ。
- 印刷するのは見えているタブ。Markdown は文書、それ以外は 11.3 のコードを印刷する。ほかのタブを印刷するときは、先に `ActiveIndex` で切り替える。
- プレビューを出していないときは、印刷の間だけプレビューを出し、印刷ダイアログが閉じたら隠す。閉じたことが知らされないときは、出したままになる（`Ctrl+Shift+V` で隠す）。初めてのときは、プレビューの WebView2 の起動を待つため、少し時間がかかる。
- 画面がダークでも、印刷は白い背景・黒い文字になる。Markdown のコードブロックは黒一色、コードのタブは印刷用の濃い色で色分けする。長い行は折り返す。
- PDF の名前は、見えているタブの名前から拡張子を外したもの（`abc.md` → `abc.pdf`、`Unit1.pas` → `Unit1.pdf`、無題 → `無題.pdf`）。保存先は印刷ダイアログで決める。
- エディタ（Monaco）の画面そのものは印刷しない。

### 11.7 Mermaid の図

Markdown の ` ```mermaid ` のコードブロックに書くと、プレビューに図として描く。

| 書き出し | 図 |
|---|---|
| `graph TD`・`graph TB` | フローチャート（上から下） |
| `graph LR` | フローチャート（左から右） |
| `flowchart LR` | フローチャート（左から右） |
| `sequenceDiagram` | シーケンス図 |
| `usecase-beta` | ユースケース図 |
| `classDiagram` | クラス図 |
| `erDiagram` | ER 図 |
| `gitGraph` | git のグラフ |
| `journey` | ユーザージャーニー |
| `xychart-beta` | XY グラフ（棒・折れ線） |
| `quadrantChart` | 4 象限の図 |
| `architecture-beta` | アーキテクチャ図 |

| 項目 | 中身 |
|---|---|
| 色 | 線・枠はエディタの配色の青（ダーク #3794ff、ライト #006ab1）、背景・文字はプレビューと同じ色。テーマの切り替えにも合わせる。図の種類によっては（git のグラフ、XY グラフなど）、Mermaid の標準の色が一部残る |
| 大きさ | 最初は、プレビューの幅に合わせて表示する。図にマウスを乗せると、右上にボタンが 4 つ出る：移動（押すと図をドラッグで動かせる）／縮小／拡大／枠に合わせる（最初の大きさに戻す）。拡大・移動はその図だけに効く。中身が変わっていない図は、本文を編集しても拡大・移動の状態が残る |
| 印刷 | 白い背景用の色で、紙の幅に合わせて印刷する（画面の拡大・移動には関係しない） |
| 書き間違い | その図の場所にエラーの内容を出す（ほかの部分は普通に出る） |
| 図の中のネットの画像（`img: "https://..."`） | `AllowRemoteImages = False`（既定値）：取りに行かず、画像なしで描き、図の下に「[外部画像は表示しません]」。`True`：取ってきて描く。取れなかったときは画像なしで描き直し、「[画像を取得できませんでした]」 |
| 安全 | 図の中のスクリプトは動かない |

- Mermaid のライブラリ（約 5.5MB）は、Mermaid の図がある文書を表示したときだけ読み込む。

## 12. 標準アクション

フォームのメニューやボタンから操作するときは、コードを書かずに標準アクションを使う。Lazarus の標準アクション「ファイルを開く」などと同じ使い方。

| No | アクション（クラス名） | 表示名 | 既定のショートカット | 動き | 使えるとき | チェック |
|---|---|---|---|---|---|---|
| 1 | `TCMEditorNew` | 新規(&N) | Ctrl+N | `NewPage` | 対象のエディタがある | ― |
| 2 | `TCMEditorOpen` | 開く(&O)... | Ctrl+O | `OpenDialog`（設定しないときは内蔵のもの）で選んで `OpenFile`。タブありなら複数選べる | 対象のエディタがある | ― |
| 3 | `TCMEditorSave` | 上書き保存(&S) | Ctrl+S | `Save`（無題なら保存ダイアログ） | 対象のエディタがある | ― |
| 4 | `TCMEditorSaveAs` | 名前を付けて保存(&A)... | なし | `SaveAs` | 対象のエディタがある | ― |
| 5 | `TCMEditorClose` | 閉じる(&C) | Ctrl+W | `Close`（9.5 の確認をする）。`MultiDocument = False` のときは、確認して中身を空にする | 対象のエディタがある | ― |
| 6 | `TCMEditorPrint` | 印刷(&P)... | Ctrl+P | `Print` | `CanPrint` | ― |
| 7 | `TCMEditorSaveAll` | すべて保存(&L) | Ctrl+Shift+S | `SaveAll` | 変更のあるタブがある | ― |
| 8 | `TCMEditorCloseAll` | すべて閉じる(&E) | なし | `CloseAll`（9.5 の確認をする） | 対象のエディタがある | ― |
| 9 | `TCMEditorUndo` | 元に戻す(&U) | Ctrl+Z | `Undo` | `CanUndo` | ― |
| 10 | `TCMEditorRedo` | やり直し(&R) | Ctrl+Y | `Redo` | `CanRedo` | ― |
| 11 | `TCMEditorCut` | 切り取り(&T) | Ctrl+X | `Cut` | 選んでいる（`SelLength > 0`）、かつ `ReadOnly` でない | ― |
| 12 | `TCMEditorCopy` | コピー(&C) | Ctrl+C | `Copy` | 選んでいる（`SelLength > 0`） | ― |
| 13 | `TCMEditorPaste` | 貼り付け(&P) | Ctrl+V | `Paste` | クリップボードに文字がある、かつ `ReadOnly` でない | ― |
| 14 | `TCMEditorSelectAll` | すべて選択(&A) | Ctrl+A | `SelectAll` | 対象のエディタがある | ― |
| 15 | `TCMEditorDuplicateLine` | 行の複製(&D) | Shift+F10 | `DuplicateLine` | `ReadOnly` でない | ― |
| 16 | `TCMEditorDeleteToEnd` | 末尾まで削除 | なし | `DeleteToEnd` | `ReadOnly` でない | ― |
| 17 | `TCMEditorDeleteToStart` | 先頭まで削除 | なし | `DeleteToStart` | `ReadOnly` でない | ― |
| 18 | `TCMEditorFind` | 検索・置換(&F)... | Ctrl+F | `ShowFindDialog` | 対象のエディタがある | ― |
| 19 | `TCMEditorFindNext` | 次を検索(&N) | F5 | `FindNext` | 対象のエディタがある | ― |
| 20 | `TCMEditorFindPrev` | 前を検索(&V) | Shift+F5 | `FindPrev` | 対象のエディタがある | ― |
| 21 | `TCMEditorMinimap` | ミニマップ(&M) | Ctrl+Shift+M | `Minimap` を切り替える | 対象のエディタがある | `Minimap` |
| 22 | `TCMEditorPreview` | プレビュー(&V) | Ctrl+Shift+V | `ShowPreview` を切り替える | 対象のエディタがある | `ShowPreview` |
| 23 | `TCMEditorLineNumbers` | 行番号(&L) | F11 | `LineNumbers` を切り替える | 対象のエディタがある | `LineNumbers` |
| 24 | `TCMEditorWordWrap` | 折り返し(&W) | なし | `WordWrap` を切り替える | 対象のエディタがある | `WordWrap` |
| 25 | `TCMEditorRemoteImages` | ネットの画像を表示(&I) | なし | `AllowRemoteImages` を切り替える | 対象のエディタがある | `AllowRemoteImages` |

- 使い方：フォームに `TActionList` を貼り、アクションリストエディタの「標準アクションを追加」から、カテゴリ `CX` のアクションを足し、メニュー項目の `Action` で選ぶ。
- 対象は、最後にフォーカスされたエディタに自動で決まる。まだどれもフォーカスされていなければ、最初のエディタ。コードから知りたいときは `CMActiveEditor(Form)`。
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

- どこで読んでもよい（`OnCursorChange` の中、ボタン・メニュー・タイマーなど）。読んだ時点のカーソル行の値が取れる。
- `OnCursorChange` の中で読めば、文字を入力した直後でも正しい値が取れる。
- `OnKeyDown` の中で読むと、そのキーが効く前の行になる。
- 対象は、見えているタブのカーソル行。準備ができる前は ''。
- 単語が 0 個の行（空の行など）で `LineWords[0]` を読むと、範囲の外のエラーになる。先に `Count` を確かめる。
- `LineWords` の一覧は部品が持つ。`Free` しない。次に読むと中身が変わるので、残したいときは `Assign` で自分の `TStringList` に写す。

### 13.2 分け方の設定

| 名前 | 既定値 | 中身 |
|---|---|---|
| `LineDelimiters` | 半角スペース・全角スペース・タブ・カンマ（`,`）・読点（`、`） | 区切り文字。書いた 1 文字ずつが区切りになる。全角文字も書ける。'' なら行全体が 1 つの単語 |
| `LineSkipEmpty` | `True` | `True`：区切りが続いても 1 つとして扱い、空の単語を入れない。行の先頭と最後の区切りも無視する。`False`：空の単語も入れる |
| `LineQuoteChar` | `"` | 引用符（半角 1 文字）。`#0` なら引用符を解釈しない |

- 3 つとも、オブジェクトインスペクタには出ない。コードで設定する（タブと全角スペースは、オブジェクトインスペクタでは見えず、入れられないため）。

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

### 13.4 値の持ち方

| 値 | 持ち方 |
|---|---|
| `LineText` | カーソルが別の行へ動いたとき、行の中身が変わったとき、タブを切り替えたときに、エディタから届いて部品が持つ。同じ行の中で動かしただけでは届かない（その必要がない） |
| `LineWords` | 読んだときに初めて分ける。読まなければ分けない。行と設定が前に読んだときと同じなら、分け直さずに前の結果を返す |

- 1 行が数 MB あっても、`LineWords` を読まなければ、分ける処理は動かない。
- 数 MB の 1 行の中で文字を入力すると、1 文字ごとにその行全体がエディタから届くので、重くなることがある。

## 14. 注意

| 項目 | 中身 |
|---|---|
| 入力した直後の `Text`・`SelText` など | 入力・選択した直後（約 0.1 秒以内）にコードで読むと、最後の数文字分だけ古いことがある（`OnKeyDown` の中も同じ）。`Text :=` で書いた値は、すぐ読める |
| `SelStart`・`SelLength` の数え方 | 絵文字を 2 と数える |
| 本文の持ち方 | 本文を 2 か所（Monaco と部品）に持つ（メモリは本文の 2 倍） |
| 準備ができる前 | `Ready` の前に書いた本文などは、部品が預かり、準備ができたら Monaco へ送る |
| 同期スクロール | 折り返しの多い長い段落の中は、多少ずれる |
| 数式・HTML への書き出し | ない |
## 15. 使い方の例

### 15.1 コードを書かずに、テキストエディタを作る

1. フォームに TCMonacoEditor を 1 つ貼り、`Align = alClient` にする。
2. EXE と同じフォルダーに、2.1 のファイルを置く。

これだけで、次のことができる。

| 機能 | 操作 |
|---|---|
| 編集 | そのまま |
| ファイルを開く | ドロップ |
| 行番号の表示・非表示 | `F11` |
| 検索・置換 | `Ctrl+F`、`F5` / `Shift+F5` |
| 上書き保存 | `Ctrl+S`（無題なら「名前を付けて保存」のダイアログ） |
| プレビュー | `Ctrl+Shift+V` |
| 色分け | 拡張子から自動 |
| 印刷（PDF 保存） | `Ctrl+P`、またはプレビューを右クリック →「印刷...」 |
| 保存していない文書の確認 | フォームを閉じると自動で確認 |

### 15.2 1 つのフォームに 3 つ貼る

1. TCMonacoEditor を 3 つ貼り、配置を決める（例：`alLeft`、`alLeft`、`alClient`）。同じ親の中で `alClient` にできるのは 1 つだけ。
2. 3 つとも `MultiDocument = False` にする。

コードは要らない。検索・置換ダイアログは共有の 1 つで、`Ctrl+F` を押したエディタが対象になる。標準アクションは、最後にフォーカスされたエディタに効く。`TPageControl` の別々のシートに置いてもよい（見えないシートのエディタは、初めて表示されたときに起動する）。

### 15.3 保存していない文書を、確認せずに保存する

```pascal
procedure TForm1.CMonacoEditor1QueryClose(Sender: TObject; Index: Integer;
  var CanClose: Boolean);
var
  E: TCMonacoEditor;
begin
  E := Sender as TCMonacoEditor;
  E.Pages[Index].Save;                          // 保存する（無題なら保存ダイアログが出る）
  CanClose := not E.Pages[Index].Modified;      // 保存ダイアログでキャンセルされたら閉じない
end;
```

- 複数のエディタで共用するときは、オブジェクトインスペクタで、どのエディタの `OnQueryClose` にも同じメソッドを選ぶ。

### 15.4 メニューを付ける

1. フォームに `TActionList` と `TMainMenu` を貼る。
2. アクションリストエディタで、CX の標準アクション（12章）を足す。
3. メニュー項目の `Action` で、アクションを選ぶ。

### 15.5 自分のダイアログを使う

1. フォームに `TOpenDialog`・`TSaveDialog`・`TCMFindDialog` を貼り、フィルターや最初のフォルダーを設定する。
2. 各エディタの `OpenDialog`・`SaveDialog`・`FindDialog` で選ぶ。

### 15.6 右クリックメニューに自分の項目を足す（上級者向け）

```pascal
procedure TForm1.FormCreate(Sender: TObject);
var
  MI: TMenuItem;
begin
  MI := TMenuItem.Create(Self);
  MI.Caption := '[ ] で囲む';
  MI.OnClick := @MyMenuClick;
  CMonacoEditor1.Monaco.PopupMenu.Items.Add(MI);
end;

procedure TForm1.MyMenuClick(Sender: TObject);
begin
  CMonacoEditor1.SelText := '[' + CMonacoEditor1.SelText + ']';
end;
```

### 15.7 複数のアプリで、1 か所の monaco・preview を使う

```
C:\apps\
  monaco\
  preview\
  WebView2Loader.dll
  tcTabBrowser\
    tcTabBrowser.exe
    WebView2.ini
  MyEditor\
    MyEditor.exe
    WebView2.ini
```

各アプリの WebView2.ini に、次のように書く。アプリのコード・`.lfm` は変えない。

```ini
[WebView2]
LoaderDllPath=..\WebView2Loader.dll
UserDataFolder=WebView2Data
MonacoFolder=..\monaco
PreviewFolder=..\preview
```

- `UserDataFolder` は、アプリごとに分ける（2.2）。

### 15.8 内蔵の Ctrl+S を、自分の保存処理に置き換える

```pascal
procedure TForm1.CMonacoEditor1KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_S) and (ssCtrl in Shift) then
  begin
    MySave(Sender as TCMonacoEditor);
    Key := 0;   // 内蔵の保存は動かない
  end;
end;
```

### 15.9 タブのアイコンを自分で決める

```pascal
procedure TForm1.CMonacoEditor1GetTabImageIndex(Sender: TObject; Index: Integer;
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
procedure TForm1.CMonacoEditor1CursorChange(Sender: TObject; Line, Column: Integer);
var
  W: TStrings;
  i: Integer;
begin
  Label1.Caption := CMonacoEditor1.LineText;
  W := CMonacoEditor1.LineWords;
  Memo1.Lines.Clear;
  for i := 0 to W.Count - 1 do
    Memo1.Lines.Add(W[i]);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  CMonacoEditor1.LineDelimiters := ' ' + '　' + #9;   // カンマ・読点では分けない
end;
```

### 15.11 準備ができたらファイルを開き、エディタにフォーカスを置く

```pascal
procedure TForm1.CMonacoEditor1Ready(Sender: TObject);
begin
  CMonacoEditor1.OpenFile('C:\docs\readme.md');
  CMonacoEditor1.SetFocus;
end;
```

### 15.12 継承して自分の部品を作る

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

### 15.13 コードで作る

```pascal
uses
  uCmonacos;

procedure TForm1.FormCreate(Sender: TObject);
var
  E: TCMonacoEditor;
begin
  E := TCMonacoEditor.Create(Self);
  E.MultiDocument := False;   // 変えるのは Parent を設定する前
  E.Parent := Self;           // ここでフォームの終了の確認に加わる
  E.Align := alClient;
end;
```

### 15.14 タブの分離を自分で作る（上級者向け）

部品の分離（`TabTearOff = True`）を使わずに、`OnTabDragOut` の中で自分で作るときの例。`TabTearOff = False` にする。この例では、受け渡しに起動パラメータ（`/tearoff 一時ファイル`）を使う。

一時ファイル（UTF-8）の形：

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

- 1 行目は目印。空の行までが見出し、その後ろの全部が本文。
- `FileName` は、無題なら空。`Encoding` は `TCMEncoding` の番号（`Ord`）。

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
