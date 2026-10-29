# TCBookmark 取扱説明書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 概要とクラス

Firefox のブックマーク画面のような、ブックマーク管理の部品です。フォームに置き、開く先の TCTabBrowser・TCMonacoEditor をオブジェクトインスペクタで選ぶだけで動きます。アプリ側でコードを書く必要はありません。

```
┌──────────────────────┐
│ ブックマークを検索       │ ← 検索ボックス
├──────────────────────┤
│ 🌐 Qiita               │ ← URL
│ 📄 memo.md             │ ← ファイル
│ ──────────────── │ ← 区切り線
│ ▼ 📁 仕事              │ ← フォルダー
│     🌐 NotebookLM      │
└──────────────────────┘
```

- ブックマークは、URL のリンクとローカル PC のファイルのリンクの2種類。ほかにフォルダーと区切り線がある。
- URL は TCTabBrowser、ファイルは TCMonacoEditor で開く（左クリック・右クリックメニュー・Enter）。
- 追加・編集・削除・切取り・コピー・貼り付け・フォルダー・区切り線、ドラッグでの移動ができる。
- 名前と URL・ファイルパスを検索できる。
- エクスプローラーからファイル・フォルダー・.url・ショートカット（.lnk）を、ブラウザから URL をドロップして登録できる。
- デスクトップ・エクスプローラーへドラッグすると、URL は「名前.url」、ファイルはショートカットができる（ブラウザと同じ動き）。
- Chrome・Edge・Firefox と、HTML ファイルでインポート・エクスポートできる。
- 操作のたびに自動で保存する。次に起動したとき、フォルダーの開閉も含めて元どおりに表示する。
- URL はサイトのアイコン（favicon）、ファイルは Windows のアイコンで表示する。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |
| テーマ | システム色で描く（MetaDarkStyle でダークにできる） |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCBookmark` | `uCbookmark` | cx | `TCustomPanel` | ブックマーク管理の部品。検索ボックスとツリーを中に持つ |
| `TCBookmarkItem` | `uCbookmark` | cx | `TObject` | ブックマーク1件分（3.2）。作るのも消すのも TCBookmark が行う |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCBookmarkKind` | `uCbookmark` | 種類。`bkUrl`（URL）・`bkFile`（ファイル）・`bkFolder`（フォルダー）・`bkSeparator`（区切り線） |
| `TCBookmarkTarget` | `uCbookmark` | 開く先。`btBrowser`（TargetBrowser）・`btEditor`（TargetEditor） |
| `TCBookmarkDropPos` | `uCbookmark` | 落とす位置。`bdpBefore`（その前）・`bdpInside`（フォルダーの中の一番下）・`bdpAfter`（その後）。継承して使うときだけ使う |

- フォームに置くと、uses に `uCbookmark` が自動で入る。
- フォームに置くと、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCBookmark をフォームに置く（例：`Align = alLeft`）。
2. オブジェクトインスペクタで、`TargetBrowser` に TCTabBrowser を、`TargetEditor` に TCMonacoEditor を選ぶ（片方だけでもよい）。
3. 実行する。EXE のフォルダーの bookmark\bookmarks.json を読み込んで表示する。操作した内容は自動で保存される。

- 保存先を変えるときは、`BookmarkFolder`・`BookmarkFile` を設定する（7章）。
- TCTabBrowser・TCMonacoEditor を使うときは、それぞれの取扱説明書の準備（WebView2.ini など）も要る。

## 3. プロパティ

### 3.1 TCBookmark

**この部品で足したもの**

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `TargetBrowser` | `TCTabBrowser` | 読み・書き | URL を開く先（既定値は nil） |
| `TargetEditor` | `TCMonacoEditor` | 読み・書き | ファイルを開く先（既定値は nil） |
| `BookmarkFolder` | `string` | 読み・書き | 保存先のフォルダー（既定値は 'bookmark'）。7章 |
| `BookmarkFile` | `string` | 読み・書き | 保存するファイル名（既定値は 'bookmarks.json'）。'' にすると 'bookmarks.json'。7章 |
| `Root` | `TCBookmarkItem` | 読み | 一番上の入れ物（名前のないフォルダー）。画面には `Root` の子から表示する。実行時だけ |
| `Selected` | `TCBookmarkItem` | 読み | 選んでいる項目（無ければ nil）。実行時だけ |
| `SearchText` | `string` | 読み・書き | 検索ボックスの文字。書くとすぐ検索する。実行時だけ |
| `DragItem` | `TCBookmarkItem` | 読み | ドラッグ中の項目（ドラッグしていなければ nil）。同じアプリの別の部品の `OnDragOver`・`OnDragDrop` の中で使う（10.9）。実行時だけ |

**TCustomPanel から引き継いだもの**

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Align` | `TAlign` | 読み・書き | 親の中での配置 |
| `Anchors` | `TAnchors` | 読み・書き | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `BorderSpacing` | `TControlBorderSpacing` | 読み・書き | 周りの余白 |
| `Constraints` | `TSizeConstraints` | 読み・書き | 大きさの上限・下限 |
| `Enabled` | `Boolean` | 読み・書き | 使えるか |
| `Font` | `TFont` | 読み・書き | 文字 |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `ShowHint` | `Boolean` | 読み・書き | ヒントを出すか |
| `TabOrder` | `TTabOrder` | 読み・書き | Tab キーで移る順番 |
| `TabStop` | `Boolean` | 読み・書き | Tab キーで止まるか |
| `Visible` | `Boolean` | 読み・書き | 表示するか |

- 大きさを決める `Left`・`Top`・`Width`・`Height` と `Name`・`Tag` も使える（既定の大きさは 250×300）。

### 3.2 TCBookmarkItem（ブックマーク1件分）

作るのも消すのも TCBookmark が行う。アプリ側で `Create`・`Free` しない。

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Kind` | `TCBookmarkKind` | 読み | 種類 |
| `Name` | `string` | 読み・書き | 名前（区切り線は ''）。書き換えても保存されず、画面も変わらない |
| `Location` | `string` | 読み・書き | URL またはファイルパス（フォルダー・区切り線は ''）。書き換えても保存されず、画面も変わらない |
| `Expanded` | `Boolean` | 読み・書き | フォルダーが開いているか |
| `AddDate` | `TDateTime` | 読み | 登録日時 |
| `Parent` | `TCBookmarkItem` | 読み | 親のフォルダー（一番上の項目は `Root`） |
| `Count` | `Integer` | 読み | 子の数（フォルダー以外は 0） |
| `Items[AIndex]` | `TCBookmarkItem` | 読み | 子の項目（0 から）。既定のプロパティなので `CBookmark1.Root[0]` とも書ける |
| `Index` | `Integer` | 読み | 親の中での位置 |
| `FileMissing` | `Boolean` | 読み | リンク先のファイルが無い（ファイルのみ。8.2） |

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `IsDescendantOf` | `AItem: TCBookmarkItem` | `Boolean` | 自分が `AItem` の子・孫なら `True`（`AItem` 自身なら `False`） |
| `DescendantCount` | ― | `Integer` | 子・孫の数（自分は数えない） |

- 名前・場所を変えるときは、`TCBookmark` の操作（右クリックの「ブックマークを編集」など）を使う。

## 4. メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | ― | 作る。コードで作るときに使う（10.11） |
| `AddBookmark` | `AParent: TCBookmarkItem; AIndex: Integer; const AName, ALocation: string` | `TCBookmarkItem` | URL かファイルのブックマークを足す。種類は `ALocation` から決まる（4.1）。`AParent` が nil・フォルダーでないときは一番上、`AIndex = -1`（範囲の外）なら末尾。`AName` が '' なら、ファイル名（URL は URL）を名前にする。判定できない `ALocation`（about:〜 など）は nil を返し、何も足さない |
| `AddFolder` | `AParent: TCBookmarkItem; AIndex: Integer; const AName: string` | `TCBookmarkItem` | フォルダーを足す |
| `AddSeparator` | `AParent: TCBookmarkItem; AIndex: Integer` | `TCBookmarkItem` | 区切り線を足す |
| `DeleteItem` | `AItem: TCBookmarkItem` | ― | 項目を消す（フォルダーは中身ごと。確認は出さない）。ファイルの実体は消さない |
| `MoveItem` | `AItem, ANewParent: TCBookmarkItem; ANewIndex: Integer` | `Boolean` | 項目を動かす。`ANewParent = nil` なら一番上。自分の中へは動かせない（`False`） |
| `OpenItem` | `AItem: TCBookmarkItem; ATarget: TCBookmarkTarget; ANewTab: Boolean` | ― | 項目を開く（6.3）。`btBrowser` は `TargetBrowser`、`btEditor` は `TargetEditor`（ファイルのみ）。`ANewTab = True` なら新しいタブ |
| `ImportFromFile` | `const AFileName: string` | `Boolean` | HTML ファイルからインポートする（9章）。ブックマークが1件も無い・読めないときは `False` |
| `ExportToFile` | `const AFileName: string` | `Boolean` | HTML ファイルへエクスポートする（9章）。書けないときはメッセージを出して `False` |
| `ImportWithDialog` | ― | ― | ファイルを選ぶダイアログを出してインポートする（メニューと同じ） |
| `ExportWithDialog` | ― | ― | 保存先を選ぶダイアログを出してエクスポートする（メニューと同じ） |

- 足す・消す・動かす・インポートすると、自動で保存し、`OnChange` が出る。足した・動かした項目が選ばれる。

### 4.1 関数（uCbookmark）

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `CBClassifyLocation` | `const S: string; out AKind: TCBookmarkKind; out ALocation: string` | `Boolean` | 文字が URL かファイルかを決める（下の表）。決められなければ `False` |
| `CBPathToFileUrl` | `const APath: string` | `string` | ファイルパスを file:/// の URL にする（`\` → `/`、`%` → `%25`、`#` → `%23`、空白 → `%20`。日本語はそのまま。`\\server\share` は `file://server/share`） |
| `CBFileUrlToPath` | `const AUrl: string` | `string` | file:/// の URL をファイルパスにする（%xx を戻し、`/` → `\`） |
| `CBHostOf` | `const AUrl: string` | `string` | URL のホスト名（小文字。ポート番号は付いたまま）。取れなければ '' |

| 文字（前後の空白は除く） | 種類 |
|---|---|
| `file:` で始まる | ファイル（`CBFileUrlToPath` でパスにする） |
| `://` を含む（http・https など） | URL |
| `C:\`・`C:/`、`\\server\` で始まる | ファイル（`/` は `\` にする） |
| それ以外（about:・javascript: など） | 決められない |

## 5. イベント

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnChange` | `Sender: TObject` | ブックマークが変わり、保存した後（足す・編集・消す・動かす・貼り付け・インポート・ドロップ・保存先を変えたとき）。選択が変わっただけ、フォルダーを開閉しただけでは出ない |
| `OnSelectionChange` | `Sender: TObject` | 選んでいる項目（`Selected`）が変わった後。クリック・キー・右クリック・足した後や消した後の選び直し・検索の切り替えなど、理由に関係なく出る（選択が無くなったときも出る）。同じ項目を選び直しても出ない。中では `Selected` で項目を取り出す |

## 6. 操作

### 6.1 マウス

| 操作 | URL | ファイル | フォルダー | 区切り線 |
|---|---|---|---|---|
| 左クリック | `TargetBrowser` の表示中のタブで開く | `TargetEditor` の表示中のタブで開く | 開閉する | 何もしない |
| ［▶］［▼］ | ― | ― | 開閉する | ― |
| ドラッグ（ツリーの中） | 動かす | 動かす | 中身ごと動かす | 動かす |
| ドラッグ（ツリーの外） | 6.6 | 6.6 | 6.6 | 6.6 |
| 右クリック | 選んでからメニュー（6.2） | 同じ | 同じ | 同じ |

- 開く先が設定されていないときの左クリックは、何もしない。
- Shift・Ctrl・Alt を押しながらの左クリックは、何もしない。
- ドラッグ中は、落とす位置に横線が出る。フォルダーの行の真ん中（上下 1/4 を除いた所）に重ねると行が枠で囲まれ、そのフォルダーの中の一番下に入る。フォルダー以外の行は、上半分ならその前、下半分ならその後。何も無い所なら一番下。
- 閉じたフォルダーの中に入れる位置で 1 秒止まると、そのフォルダーが開く。ツリーの上下の端に近づくと自動でスクロールする。
- フォルダーを自分の中へは動かせない（落とせないカーソルが出る）。Esc でドラッグを取りやめる。

### 6.2 右クリックメニュー

| メニュー | URL | ファイル | フォルダー | 区切り線 | 何も無い所 |
|---|---|---|---|---|---|
| Text開く | 灰色 | `TargetEditor` の表示中のタブで開く | 灰色 | 灰色 | 灰色 |
| Text新しいタブで開く | 灰色 | `TargetEditor` の新しいタブで開く | 灰色 | 灰色 | 灰色 |
| Browserで開く | `TargetBrowser` の表示中のタブで開く | `TargetBrowser` の表示中のタブで開く（file:///） | 灰色 | 灰色 | 灰色 |
| Browserで新しいタブで開く | `TargetBrowser` の新しいタブで開く | `TargetBrowser` の新しいタブで開く（file:///） | 灰色 | 灰色 | 灰色 |
| ブックマークを編集 | 名前・URL を編集 | 名前・ファイルパスを編集 | フォルダー名を編集 | 灰色 | 灰色 |
| ブックマークを削除 | 消す | 消す（ファイルは消さない） | 中身ごと消す（確認あり） | 消す | 灰色 |
| 切取り | できる | できる | できる（中身ごと） | できる | 灰色 |
| コピー | できる | できる | できる（中身ごと） | できる | 灰色 |
| 貼り付け | その下に入れる | その下に入れる | フォルダーの中に入れる | その下に入れる | 一番下に入れる |
| ブックマークを追加 | その下に入れる | その下に入れる | フォルダーの中に入れる | その下に入れる | 一番下に入れる |
| フォルダーを追加 | その下に入れる | その下に入れる | フォルダーの中に入れる | その下に入れる | 一番下に入れる |
| 区切り線 | その下に入れる | その下に入れる | フォルダーの中に入れる | その下に入れる | 一番下に入れる |
| インポート... | できる | できる | できる | できる | できる |
| エクスポート... | できる | できる | できる | できる | できる |

- `TargetEditor` が設定されていなければ Text系、`TargetBrowser` が設定されていなければ Browser系が灰色になる。
- 「フォルダーの中に入れる」は、フォルダーの中の一番下に入れ、そのフォルダーを開く。
- 貼り付けは、切取り・コピーをしていないときは灰色。
- 何も無い所を右クリックすると、選択が外れる。

**追加・編集のダイアログ**

| 操作 | ダイアログの名前 | 入れる所 |
|---|---|---|
| ブックマークを追加 | ブックマークを追加 | 名前、URL またはファイルパス |
| ブックマークを編集（URL・ファイル） | ブックマークを編集 | 名前、URL またはファイルパス（今の値が入っている） |
| フォルダーを追加 | フォルダーを追加 | 名前（最初は「新しいフォルダー」） |
| ブックマークを編集（フォルダー） | フォルダー名を編集 | 名前 |

- 名前が空、または URL・ファイルパスが決められない（4.1）ときは、［OK］を押せない。
- 編集で、URL をファイルに（ファイルを URL に）変えてもよい。

**切取り・コピー・貼り付け**

- 部品の中で写しを持つ。コピーは何度でも貼れる。切取りは、貼り付けたときに元の場所から動かす（貼り付けるまでは元の場所に残る）。
- 切り取ったフォルダーを、自分の中へは貼れない（何も起きない）。
- 切り取った項目（またはそれを含むフォルダー）を消すと、切取りは取り消される。
- コピー・切取りをすると、URL・ファイルパスの文字も Windows のクリップボードに入る（フォルダーは中の URL・パスを1行に1つずつ。区切り線だけのときは入れない）。Windows のクリップボードから貼り付けることはできない。

### 6.3 開くときの動き

| 場面 | 動き |
|---|---|
| ファイルを「表示中のタブで開く」（左クリック・Text開く）で、そのファイルがどこかのタブで開いている | そのタブに切り替える |
| ファイルを「表示中のタブで開く」で、表示中のタブに保存していない変更がある | 「保存されていない変更があります。新しいタブで開きますか？」と聞く。はい＝新しいタブで開く、いいえ＝開かない（変更は残る） |
| ファイルを「新しいタブで開く」で、そのファイルがどこかのタブで開いている | そのタブに切り替える |
| リンク先のファイルが無い | 「ファイルがありません：（パス）」と知らせ、開かない |
| TCTabBrowser にタブが1枚も無い | 新しいタブを作って開く |
| 開けなかった（TCTabBrowser・TCMonacoEditor が例外を出した） | 「開けません：（場所 : 理由）」と知らせる |

- 開いた後、エディタで開いたときはエディタにフォーカスが移る。

### 6.4 キー

| キー | 動作 |
|---|---|
| Enter | 左クリックと同じ |
| Delete | 消す（フォルダーは確認あり） |
| F2 | 編集（区切り線は何もしない） |
| Ctrl+X | 切取り |
| Ctrl+C | コピー |
| Ctrl+V | 貼り付け（検索中は何もしない） |
| Ctrl+F | 検索ボックスへ移る |
| Esc（ドラッグ中） | ドラッグを取りやめる |
| 検索ボックスで Esc | 検索をやめ、元のツリーに戻る |
| 検索ボックスで ↓・Enter | ツリーへ移る（何も選んでいなければ、最初の項目を選ぶ） |

### 6.5 検索

- 検索ボックスに文字を入れて 0.3 秒たつと、名前か URL・ファイルパスにその文字を含む URL・ファイルを、フォルダーに関係なく1列の一覧で表示する。大文字・小文字、全角・半角の英数字と空白は区別しない。
- 検索中にできるのは、開く・編集・消す・切取り・コピー・エクスポート。貼り付け・追加・区切り線・インポート・ドラッグでの移動・外からのドロップはできない（入れる位置が決まらないため）。
- 文字を消すと、元のツリー（フォルダーの開閉も元どおり）に戻る。

### 6.6 外へのドラッグ

ツリーの項目を、ツリーの外へドラッグできる。マウスの位置によって動きが変わる。

| ドラッグした先 | URL | ファイル | フォルダー・区切り線 |
|---|---|---|---|
| デスクトップ・エクスプローラー | 「名前.url」のインターネットショートカットができる | 元のファイルへのショートカット（.lnk）ができる（元のファイルはコピー・移動されない） | 落とせない |
| メモ帳など文字を受けるアプリ | URL の文字が入る | 受けるアプリ次第 | 落とせない |
| ブラウザ | その URL を開く | 受けるブラウザ次第 | 落とせない |
| 同じアプリの別の部品 | その部品の `OnDragOver` で受けると答えたら、`OnDragDrop` が呼ばれる（10.9） | 同じ | 同じ |

- 外へドラッグしても、TCBookmark のブックマークは変わらない（動かさない・消さない）。
- リンク先が無いファイルは、アプリの外へは出せない。
- 「名前.url」の名前は、ブックマークの名前の、ファイル名に使えない文字を「_」にしたもの（前後の空白と末尾の「.」は除く。200 文字まで。空ならホスト名）。
- 一度アプリの外へ出すと、アプリの中へ戻しても、同じアプリの部品へは渡せない。自分のツリーへ戻して離しても、ブックマークは増えない。
- ドラッグ中の絵は出ない（カーソルだけ）。

### 6.7 外からのドロップ

| ドロップしたもの | 登録のされ方 |
|---|---|
| ブラウザの URL（アドレスバー・ページの中のリンク） | URL。名前はページのタイトル（取れなければ URL） |
| URL の文字（`://` を含む1行目） | URL。名前は URL |
| ファイル（拡張子の制限なし） | ファイル。名前はファイル名 |
| .url ファイル | 中の URL。名前は .url を除いたファイル名 |
| ショートカット（.lnk） | リンク先のファイル。名前は .lnk を除いたファイル名。リンク先がフォルダーなら、次の行と同じ |
| フォルダー | 同じ名前のフォルダーを作り、中身を同じ構造で登録する（サブフォルダーが先、ファイルが後。それぞれ名前順） |

- 落とす位置は 6.1 と同じ（前・後・フォルダーの中・一番下）。
- 複数まとめてドロップすると、ドロップした順に並ぶ。
- フォルダーの中身が全部で 500 件を超えるときは、「n 件を登録しますか？」と確認が出る。
- フォルダーの中の .url は URL として、.lnk はその .lnk ファイルとして登録する。ジャンクション・シンボリックリンクのフォルダーはたどらない。
- 登録は、ドロップの処理が終わってから行う（確認のメッセージでエクスプローラーなどを止めないため）。

## 7. 保存先

| ファイル | 中身 |
|---|---|
| `BookmarkFolder`\\`BookmarkFile` | すべてのブックマーク（JSON、UTF-8）。既定は EXE のフォルダー\bookmark\bookmarks.json |
| `BookmarkFolder`\icons\ | サイトのアイコン（ホスト名.png または .ico。ホスト名の「:」は「_」） |

- `BookmarkFolder` が相対パス（'' を含む）なら EXE のフォルダーから数える。絶対パス（C:\〜、\\server\〜）ならそのまま。
- 足す・編集・消す・動かす・貼り付け・フォルダーの開閉・インポート・ドロップのたびに、すぐ保存する。
- 保存は、一度 .tmp に書いてから置き換える（書いている途中で止まっても、ファイルが壊れない）。フォルダーが無ければ作る。
- 保存先に書き込めないと保存できない。メッセージ「ブックマークを保存できません」は、起動中に1回だけ出る。EXE を Program Files などに置くときは、`BookmarkFolder` で書き込める場所を指定する。
- ファイルが壊れていて読めないときは、bookmarks.json.broken-（年月日時分秒）に名前を変えて残し、空の状態で始める（知らせが出る）。
- 実行中に `BookmarkFolder`・`BookmarkFile` を変えると、新しい場所から読み直し、`OnChange` が出る（それまでの内容は前の場所に保存済み。切取りは取り消される）。
- 読み込むのは、部品が初めて表示されたとき。IDE の上（設計時）では、読み込み・保存をしない。

**bookmarks.json の形**

```json
{
  "version" : 1,
  "items" : [
    { "type" : "url", "name" : "Qiita", "location" : "https://qiita.com/", "added" : "2026-10-27T23:40:00" },
    { "type" : "file", "name" : "memo.md", "location" : "C:\\work\\memo.md", "added" : "2026-10-27T23:41:00" },
    { "type" : "separator" },
    { "type" : "folder", "name" : "仕事", "expanded" : true, "added" : "2026-10-27T23:42:00", "items" : [] }
  ]
}
```

- 上は中身の形を示したもの。実際のファイルは、項目ごとに改行と字下げが入る。
- 知らない `type` の項目は読み飛ばす。

## 8. 表示

### 8.1 アイコン

| 種類 | アイコン |
|---|---|
| URL | サイトの favicon。無ければ地球儀の絵 |
| ファイル | Windows のアイコン |
| フォルダー | Windows のフォルダーのアイコン（Windows 11 では開閉で同じ絵。開閉は［▶］［▼］で分かる） |
| 区切り線 | なし（半分の高さの行に、灰色の横線） |

- favicon は、URL を登録したとき（追加・編集・ドロップ・インポート）に、そのサイトのアイコンがまだ無ければ、部品が裏で `https://（ホスト名）/favicon.ico` を取りに行く。取れなければ地球儀の絵のまま。
- 同じサイトは、起動中に1回だけ取りに行く。同時に取りに行くのは 4 件まで。待つのは 10 秒、大きさは 512KB まで。PNG・ICO 以外（無いページの HTML など）は捨てる。
- Firefox からインポートしたときは、HTML の中のアイコンを使う（取りに行かない）。
- アイコンの大きさは、Windows の小さいアイコンの大きさ（96dpi で 16×16）。

### 8.2 リンク先が無いファイル

- 名前が灰色になる。
- 確かめるのは、読み込んだとき、フォルダーを開いたとき、登録・編集・貼り付けしたとき、開こうとしたとき。描くたびには確かめない（ネットワークのパスで遅くならないように）。
- 自動では消さない。

### 8.3 色

| 部分 | 色 |
|---|---|
| 背景 | `clWindow` |
| 文字 | `clWindowText` |
| 選んでいる行 | `clHighlight`、文字は `clHighlightText` |
| リンク先が無いファイル | 文字が `clGrayText` |
| 区切り線 | `clGrayText` |
| ドラッグ中の位置の線・枠 | `clHighlight` |

- スクロールバーは、スクロールが要らないときは出ない。

## 9. インポート・エクスポート

右クリックメニューの「インポート...」「エクスポート...」（または `ImportWithDialog`・`ExportWithDialog`・`ImportFromFile`・`ExportToFile`）で、ブラウザのブックマークの書き出し形式（Netscape Bookmark File Format の HTML）を読み書きする。

| ブラウザ | TCBookmark に取り込む | ブラウザへ渡す |
|---|---|---|
| Firefox | フォルダー・区切り線・アイコンとも入る | フォルダー・区切り線・アイコンとも入る |
| Chrome・Edge | フォルダーが入る。アイコンは後から取りに行く | フォルダーが入る。区切り線・アイコンは消える |

- インポートした項目は、一番下に作る「インポート yyyy-mm-dd」フォルダーの中に入る。同じブックマークがあっても確かめない。
- インポートでは、javascript:・place:・about: などの、URL・ファイルと決められないリンクは読み飛ばす。
- ブックマークが1件も無いファイルは、「ブックマークが見つかりませんでした。」と知らせ、何も足さない。
- エクスポートは UTF-8・改行 CRLF。ファイルのブックマークは file:/// の URL として書く。サイトのアイコンがあれば、HTML の中に入れる。

## 10. 使い方の例

### 10.1 フォームに置いて動かす

1. フォームに TCTabBrowser・TCMonacoEditor・TCBookmark を置く。
2. TCBookmark の `TargetBrowser`・`TargetEditor` を選ぶ。
3. 実行し、ブラウザのアドレスバーの URL や、エクスプローラーのファイルを TCBookmark にドロップする。

### 10.2 コードでブックマークを追加する

```pascal
procedure TForm1.Button1Click(Sender: TObject);
var
  F: TCBookmarkItem;
begin
  F := CBookmark1.AddFolder(nil, -1, '仕事');
  CBookmark1.AddBookmark(F, -1, 'Qiita', 'https://qiita.com/');
  CBookmark1.AddBookmark(F, -1, '', 'C:\work\memo.md');   // 名前は memo.md
  CBookmark1.AddSeparator(nil, -1);
end;
```

### 10.3 表示中のページをブックマークに追加する

```pascal
procedure TForm1.AddPageClick(Sender: TObject);
begin
  if CTabBrowser1.Count = 0 then Exit;
  CBookmark1.AddBookmark(nil, -1, CTabBrowser1.ActiveTab.Title, CTabBrowser1.ActiveTab.URL);
end;
```

### 10.4 選んでいる項目を見る

```pascal
procedure TForm1.ShowSelectedClick(Sender: TObject);
var
  It: TCBookmarkItem;
begin
  It := CBookmark1.Selected;
  if It = nil then Exit;
  ShowMessage(It.Name + LineEnding + It.Location);
end;
```

### 10.5 すべての URL を取り出す

```pascal
procedure TForm1.CollectUrls(AParent: TCBookmarkItem; AList: TStrings);
var
  I: Integer;
begin
  for I := 0 to AParent.Count - 1 do
    case AParent.Items[I].Kind of
      bkUrl: AList.Add(AParent.Items[I].Location);
      bkFolder: CollectUrls(AParent.Items[I], AList);
    end;
end;

// 使い方：CollectUrls(CBookmark1.Root, Memo1.Lines);
```

### 10.6 保存先を変える

```pascal
// 設計時：オブジェクトインスペクタで BookmarkFolder を 'data\bm' などにする（EXE のフォルダーから数える）
// 実行時：変えると、その場所から読み直す
CBookmark1.BookmarkFolder := GetEnvironmentVariable('APPDATA') + '\MyApp\bookmark';
```

### 10.7 メニューやボタンからインポート・エクスポートする

```pascal
procedure TForm1.MenuImportClick(Sender: TObject);
begin
  CBookmark1.ImportWithDialog;
end;

procedure TForm1.MenuExportClick(Sender: TObject);
begin
  CBookmark1.ExportToFile(ExtractFilePath(ParamStr(0)) + 'bookmarks.html');
end;
```

### 10.8 変わったときにステータスバーへ件数を出す

```pascal
procedure TForm1.CBookmark1Change(Sender: TObject);
begin
  StatusBar1.SimpleText := Format('%d 件', [CBookmark1.Root.Count]);
end;
```

### 10.9 同じアプリの別の部品でドラッグを受ける

受ける部品（例：TCCheckListBox・TListBox）の `OnDragOver`・`OnDragDrop` に書く。`Source` は TCBookmark。

```pascal
procedure TForm1.CheckListBox1DragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  { ファイルのブックマークだけ受ける }
  Accept := (Source is TCBookmark) and (TCBookmark(Source).DragItem <> nil)
    and (TCBookmark(Source).DragItem.Kind = bkFile);
end;

procedure TForm1.CheckListBox1DragDrop(Sender, Source: TObject; X, Y: Integer);
begin
  CheckListBox1.Items.Add(TCBookmark(Source).DragItem.Location);   { フルパス }
end;
```

### 10.10 選択が変わったときにファイル名を出す

```pascal
procedure TForm1.CBookmark1SelectionChange(Sender: TObject);
var
  It: TCBookmarkItem;
begin
  It := CBookmark1.Selected;
  if (It <> nil) and (It.Kind = bkFile) then
    Label1.Caption := It.Location          { フルパス }
  else
    Label1.Caption := '';
end;
```

### 10.11 コードで作る

```pascal
uses
  uCbookmark;

procedure TForm1.FormCreate(Sender: TObject);
var
  B: TCBookmark;
begin
  B := TCBookmark.Create(Self);
  B.Parent := Self;
  B.Align := alLeft;
  B.TargetBrowser := CTabBrowser1;
  B.TargetEditor := CMonacoEditor1;
end;
```
