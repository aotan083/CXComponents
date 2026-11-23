# CX Components

![コンポーネントパレット](demo/Lazarus/20261028-122432-コンポーネントパレット.jpg)

私は、delphi/lazarusが大好きで、いつも利用しています。ただ日本では、ほぼだれもlazarusを知らないし、利用している人が殆どいません。使いたいツールを探しても日本にはありません。仕方がないので、自分で作成して利用しています。
ここに上げたのは、Lazarus（Free Pascal）用の部品集です。フォームに置くだけで、エクスプローラーと同じファイル操作、タブ付きブラウザ、タブ付きエディタ（Monaco・SynEdit）、Markdown のプレビュー、ブックマーク管理などが使えます。まだWindows版しかありません。ニーズあったらLinux版も作成してみたいと思います。使い方は、Usageを参照して下さい。中の仕組みは、Designに記載しています。興味があるかたは見て下さい。英語が苦手なので、コードのコメントは日本語のままです。

作者: aotan083 ／ ライセンス: MIT

[English Documentation](README.md) | [日本語ドキュメント](README.ja.md)


* 対話型AIドキュメント（Q&amp;Aポータル） 本リポジトリの設計書・使い方ガイド全49本を学習した 
* **AIマニュアルポータル** を公開しています。 コンポーネントの組み合わせ方やプロパティの仕様について、AIに直接質問・検索できます。

 [対話型AIドキュメント] (https://notebook.google.com/notebook/56c78d45-c7c5-4f17-9a81-c83314215247)


## 部品

| 部品 | 中身 | 取扱説明書 | 設計書 |
|---|---|---|---|
| TCTreeView | エクスプローラーの左側と同じフォルダーのツリー | [Usage](docs/TCTreeView_Usage.md) | [Design](docs/TCTreeView_Design.md) |
| TCListView | エクスプローラーの右側と同じファイルの一覧 | [Usage](docs/TCListView_Usage.md) | [Design](docs/TCListView_Design.md) |
| TCAddressBar | エクスプローラーのアドレスバー（パンくず・「>」で下のフォルダーの一覧・パスの入力・戻る/進む/上へ/更新・最近の場所）。TCListView・TCTreeView とつなぐだけで動く | [Usage](docs/TCAddressBar_Usage.md) | [Design](docs/TCAddressBar_Design.md) |
| TCSearchBox | エクスプローラーの検索ボックス。Enter でフォルダーの中を名前で探し（部分一致・ワイルドカード・正規表現）、結果を TCListView に出す。TCListView・TCTreeView とつなぐだけで動く | [Usage](docs/TCSearchBox_Usage.md) | [Design](docs/TCSearchBox_Design.md) |
| TCFindFile | ファイル・フォルダーを名前で探す部品（画面なし）。別スレッドで探し、見つかったものを少しずつ届ける。TCSearchBox が使っている。単独でも使える | [Usage](docs/TCFindFile_Usage.md) | [Design](docs/TCFindFile_Design.md) |
| TCGrepFile | フォルダーの中のファイルを、中身の文字で探す（grep 検索）部品（画面なし）。ファイルの名前（`*.pas;*.lfm`）で絞り、部分一致・正規表現で行を探す。結果は「パス(行番号): 文字」の形で、`OnFound` で受け取るか、ファイルへ書き出す。TCMonacoEditor・TCsEditor の `TagJump` で、その行へ飛べる | [Usage](docs/TCGrepFile_Usage.md) | [Design](docs/TCGrepFile_Design.md) |
| TCImage | TImage と同じ使い方で、bmp・jpg・png・svg・tif・ico を扱える画像。読み込み・保存を拡張子の形式で行い、保存のときに形式を変換できる（bmp → jpg など。svg は読み込みだけ） | [Usage](docs/TCImage_Usage.md) | [Design](docs/TCImage_Design.md) |
| TCImageList | TImageList と同じ使い方の画像リスト。画像ファイル・TCImage・フォルダーから画像を足せる（svg・透明も可）。TCPageControl・TCSideBar などの `Images` にそのまま使える | [Usage](docs/TCImage_Usage.md) | [Design](docs/TCImage_Design.md) |
| TCCapture | デスクトップの画面を取り込んで、画像ファイルに保存する部品（画面なし）。範囲は、デスクトップ全体・アクティブなウィンドウ・任意の長方形。保存先のフォルダーがなければ作る | [Usage](docs/TCCapture_Usage.md) | [Design](docs/TCCapture_Design.md) |
| TCFileTree | 指定したフォルダーを根にして、フォルダーとファイルを 1 本のツリーに並べる（VS Code のエクスプローラーのように使える。TCListView は不要。TCMonacoEditor・TCsEditor・TCTabBrowser とつなぐだけで、ダブルクリックや右クリックで開ける） | [Usage](docs/TCFileTree_Usage.md) | [Design](docs/TCFileTree_Design.md) |
| TCSynEdit | TSynEdit に、ファイルの読み書き・配色（VS Code のライト・ダークを含む）・拡張子に合わせた色分け（Markdown を含む）・右クリックメニューを足したエディタ | [Usage](docs/TCSynEdit_Usage.md) | [Design](docs/TCSynEdit_Design.md) |
| TCCheckListBox | チェックを 1 つだけにできる TCheckListBox | [Usage](docs/TCCheckListBox_Usage.md) | [Design](docs/TCCheckListBox_Design.md) |
| TCGroupBox・TCCheckGroupBox | 中の部品が消えないグループボックスと、チェック付きの見出しのグループボックス | [Usage](docs/TCGroupBox_Usage.md) | [Design](docs/TCGroupBox_Design.md) |
| TCSideBar | Edge のようなアイコン列と開閉するパネル | [Usage](docs/TCSideBar_Usage.md) | [Design](docs/TCSideBar_Design.md) |
| TCExpandPanel・TCRollout | VS Code のエクスプローラーのような、タイトルバー付きの伸縮するパネル（上下左右・複数並べる・アニメーション・右側にボタンとメニュー・境界のドラッグで大きさを変える） | [Usage](docs/TCExpandPanel_Usage.md) | [Design](docs/TCExpandPanel_Design.md) |
| TCSplitter | マウスを乗せたとき・ドラッグ中に青い線が出る分割線（TSplitter と同じ使い方。色・カーソルを指定できる） | [Usage](docs/TCSplitter_Usage.md) | [Design](docs/TCSplitter_Design.md) |
| TCPairSplitter | 2 つの側を持つ TPairSplitter と同じ使い方の分割線。側ごとに隠す・出すことができる（片方を隠すともう片方が全体に広がり、出すと元に戻る）。マウスを乗せたとき・ドラッグ中に青い線が出る。設計時も境目をドラッグできる | [Usage](docs/TCPairSplitter_Usage.md) | [Design](docs/TCPairSplitter_Design.md) |
| TCPageControl・TCTitleBar | ブラウザのようなタブと、タブを並べられるタイトルバー | [Usage](docs/TCPageControl_Usage.md) | [Design](docs/TCPageControl_Design.md) |
| TCTabBrowser | WebView2 を使ったタブ付きの Web ブラウザ | [Usage](docs/TCTabBrowser_Usage.md) | [Design](docs/TCTabBrowser_Design.md) |
| TCMonacoEditor・TCMFindDialog | WebView2 と Monaco Editor によるエディタ（タブ・プレビュー・検索・印刷を内蔵）と、標準アクション 25 個 | [Usage](docs/TCMonacoEditor_Usage.md) | [Design](docs/TCMonacoEditor_Design.md) |
| TCsEditor・TCsFindDialog | TCSynEdit をタブで複数持つエディタ。使い方は TCMonacoEditor と同じ（検索・置換ダイアログ・ミニマップ・タブの分離を含む）。標準アクション 25 個 | [Usage](docs/TCsEditor_Usage.md) | [Design](docs/TCsEditor_Design.md) |
| TCPreview | TCsEditor のプレビュー（Markdown・コード）と印刷（PDF 保存）。エディタとは別の場所に置き、複数のエディタで共有できる | [Usage](docs/TCPreview_Usage.md) | [Design](docs/TCPreview_Design.md) |
| TCcmd | フォームの中のコマンドプロンプト（cmd.exe・PowerShell・ssh・vi などをエミレート。リダイレクト・パイプが使える。ログ・コマンド履歴のファイル保存、`RunCapture` でコマンドの結果の取得） | [Usage](docs/TCcmd_Usage.md) | [Design](docs/TCcmd_Design.md) |
| TCaiClient | AI の API を呼ぶ部品（画面なし）。文と添付ファイル（テキスト・CSV・PDF・画像）を送り、回答を文字列で受け取る。`AskAndWaitText`（普通の文章）・`AskAndWaitMD`（Markdown）が、回答が来るまで待って返す（待つ間も画面は固まらない）。混雑・回数制限は自動でやり直す。API キーは環境変数に入れる。Gemini・Ollama（自分の PC で動かす LLM）・ChatGPT・Meta・Claude の 5 つに対応（ChatGPT・Meta・Claude は形式を確認済みで、実サービスでの確認はこれから） | [Usage](docs/TCaiClient_Usage.md) | [Design](docs/TCaiClient_Design.md) |
| TCBookmark | Firefox のようなブックマーク管理（TCTabBrowser・TCMonacoEditor で開く） | [Usage](docs/TCBookmark_Usage.md) | [Design](docs/TCBookmark_Design.md) |
| CXLang（日英切り替え） | すべての部品の画面の文字（メニュー・ボタン・メッセージ）を、日本語と英語で切り替える。WebView2.ini の `[CX]` の `Language` で指定する（使い方は各部品の取扱説明書の 2章） | ― | [Design](docs/CXLang_Design.md) |

---
すべての部品は、パレット [CX] に出ます。

![コンポーネントパレット](demo/Lazarus/20261028-122432-コンポーネントパレット.jpg)
---
## 動作環境

| 項目 | 内容 |
|---|---|
| Lazarus | 5.0 以降（TCSynEdit・TCsEditor・TCPreview）。ほかの部品は 4.8 でも動く |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |

## フォルダー

| フォルダー | 中身 |
|---|---|
| `packages` | パッケージ `cx.lpk`（実行時。部品の中身すべて）と `cxdsgn.lpk`（設計時。パレットへの登録・アイコン） |
| `source` | 部品のソース（実行時） |
| `source\design` | 設計時のソース（パレットへの登録・コンポーネントエディタ） |
| `source\res` | パレットのアイコン（.lrs） |
| `docs` | 部品ごとの取扱説明書（`*_Usage.md`）と設計書（`*_Design.md`）、日英切り替えの設計書（`CXLang_Design.md`）。英語版は `docs\en` |
| `runtime` | WebView2 の部品が実行時に使うファイル（`monaco`・`preview`） |
| `demo` | 部品ごとのサンプル |

## インストール

1. 先に、次のパッケージを Lazarus に入れる。
   - WebView4Delphi の Lazarus 用パッケージ（https://github.com/salvadordf/WebView4Delphi）
   - ATFlatControls（`atflatcontrols_package`。オンラインパッケージマネージャーから入れる）
   - SynEdit は Lazarus に最初から入っている
2. `packages\cx.lpk` を開き、「コンパイル」する。
3. `packages\cxdsgn.lpk` を開き、「インストール」する（IDE が作り直される）。
4. 再起動後、パレット [CX] に部品が出る。

## アプリで使う

- 部品をフォームに置くと、プロジェクトの必要パッケージに `cx` が自動で追加される（`cxdsgn` はアプリには要らない）。
- .lpr には何も書かない。

TCTabBrowser・TCMonacoEditor・TCBookmark・TCPreview・TCcmd を使うアプリは、EXE と同じフォルダーに次のファイルを置く。

| ファイル | 中身 |
|---|---|
| `WebView2.ini` | 必ず置く。キーの値は空でもよい（空なら EXE のフォルダーの既定の場所を使う） |
| `WebView2Loader.dll` | 64 ビット版。WebView4Delphi のリポジトリから入手する |
| `monaco\` | TCMonacoEditor のエディタ（TCMonacoEditor だけ。`runtime\monaco`。`vs` は npm の `monaco-editor` の `min\vs`） |
| `preview\` | TCMonacoEditor・TCPreview のプレビュー（`runtime\preview`） |
| `terminal\` | TCcmd の画面（`runtime\terminal`） |

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

| キー | 中身 | 空のとき |
|---|---|---|
| `LoaderDllPath` | WebView2Loader.dll のファイル | EXE のフォルダーの WebView2Loader.dll |
| `UserDataFolder` | WebView2 のユーザーデータのフォルダー | EXE のフォルダー\WebView2Data |
| `MonacoFolder` | `editor.html` と `vs` があるフォルダー | EXE のフォルダー\monaco |
| `PreviewFolder` | `preview.html` と `lib` があるフォルダー | EXE のフォルダー\preview |
| `TerminalFolder` | `terminal.html` と `lib` があるフォルダー（TCcmd） | EXE のフォルダー\terminal |
| `Language`（`[CX]`） | 画面の言語 `ja`・`en` | Windows の表示言語（日本語なら `ja`、それ以外は `en`） |

- 値の中の `%名前%` は、同じ `[WebView2]` のキー、なければ Windows の環境変数で置き換える。たとえば `CXROOT=C:\CX\runtime` と書いて、`TerminalFolder=%CXROOT%\terminal` とする。見つからない名前は、そのまま残る。
- 相対パスは EXE のフォルダーから数える。複数のアプリで 1 か所の `monaco`・`preview` を使うこともできる（[TCMonacoEditor の取扱説明書](docs/TCMonacoEditor_Usage.md)）。
- 実行には Microsoft Edge WebView2 ランタイム（Windows 11 には最初から入っている）が要る。
- TCsEditor だけなら、実行時のファイルは要らない。TCPreview を使うときだけ置く。

### TCaiClient を使うとき

TCaiClient は WebView2 を使わない（`WebView2Loader.dll`・`monaco\` などは要らない）。EXE と同じフォルダーの `WebView2.ini` に、AI ごとのセクションを書く。通信は Windows の WinHTTP を使うので、DLL は要らない。

```ini
[CaiClient]
TimeoutSeconds=120
RetryCount=2
RetryWaitSeconds=3
LogFolder=

[CaiGemini]
Url=https://generativelanguage.googleapis.com/v1beta/models/%Model%:generateContent
Model=gemini-3.8-flash
ApiKeyEnv=GEMINI_API_KEY
```

- **API キーは ini に書かない**（`WebView2.ini` は GitHub に上がるため）。`ApiKeyEnv` に書いた名前の環境変数に、キーを入れる。環境変数が無いときは `ceSettings` のエラーになり、送信しない。
- キーの入れ方と、全キーの説明は [TCaiClient の取扱説明書](docs/TCaiClient_Usage.md) の 3 章。

### 画面の言語（日本語・English）

すべての部品の画面の文字（メニュー・ボタン・メッセージ）は、日本語か英語で出る。言語は、EXE と同じフォルダーの `WebView2.ini` の `[CX]` の `Language` で決める（`ja`・`en`）。書かないときは Windows の表示言語に合わせる。

```ini
[CX]
Language=en
```

- WebView2 を使わないアプリでも、言語を指定するときは `WebView2.ini` を置く（`[CX]` だけを書けばよい）。
- 起動してから最初に文字を出すときに 1 回だけ読む。くわしくは各部品の取扱説明書の 2章と [CXLang の設計書](docs/CXLang_Design.md)。

## ライセンス

MIT ライセンス（[LICENSE](LICENSE)）。外部のライブラリのライセンスは [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) にある。

---

> ⚡ **1分で構築！コード0行（ノーコード）でアプリにプロ品質のモダンUIを標準搭載**  
> フォームに配置してプロパティを繋ぐだけ。タブの切り離し（Tear-off）、Drag & Drop、完全なWindows Explorer機能、Markdown/Mermaidプレビューなどが、**Pascalコードを1行も書かずに**動作します。

---

## ⚡ なぜ CXComponents なのか？（RAD体験の革命）

従来のLazarus開発では、Windows Explorer同等のファイル操作やVS Code風のタブ切り離し、Markdownプレビューなどを実現するために、**数千行の複雑なコードやShell API呼び出しをガリガリ書く必要**がありました。

**CXComponents** は、すべての実体処理・イベントハンドラ・標準アクションをコンポーネント内部に完全内蔵しています。そのため、**「配置してプロパティを繋ぐだけ」の完全ノーコード**で、プロ仕様のモダンアプリケーションを即座に構築できます。

### 📊 開発効率の対比（Before / After）

| 機能・動作 | 従来のLazarus開発 | CXComponents（ノーコード） |
| :--- | :--- | :--- |
| **Windows Explorer同等のファイル操作** | Shell API呼び出し、D&D、移動/コピー処理を数千行自作 | **コード0行**（`TCTreeView` / `TCListView` を貼るだけ） |
| **アドレスバー・検索ボックス** | パンくず・フォルダーの一覧・入力・履歴、別スレッドの検索と結果の表示を自作 | **コード0行**（`TCAddressBar` / `TCSearchBox` を貼って、一覧・ツリーを選ぶだけ） |
| **タブの分離・ドッキング（Tear-off / Tear-on）** | フォーム生成、イベントハンドラ、ドッキング処理を自作 | **コード0行**（`TCSEditor` / `TCMonacoEditor` で標準動作） |
| **26言語ハイライト対応エディタ** | SynEditの個別設定やエンコーディング判別コードを記述 | **コード0行**（`TCSynEdit` / `TCSEditor` を置くだけ） |
| **Markdown & Mermaid図プレビュー** | 外部描画エンジンの組み込み・同期スクロールコードの記述 | **コード0行**（`TCPreview` を配置するだけ） |
| **WebView2ベース タブブラウザ** | WebView呼び出し、ソース取得、PDF出力処理を実装 | **コード0行**（`TCTabBrowser` を配置するだけ） |
| **タイトルバー一体型タブ & サイドバー** | ウィンドウ非クライアント領域の複雑な自作描画 | **コード0行**（`TCTitleBar` + `TCSideBar` を配置するだけ） |
| **コマンドプロンプト** | cmd.exeの完全なエミレート自作描画 | **コード0行**（`TCcmd` を配置するだけ） |



---

## ⚡ 1分でわかる！ノーコードで搭載できる機能一覧

```pascal
// 【実装コード例：0 Lines】
// Pascalコードの記述は一切不要です！
// フォームにコンポーネントを配置し、オブジェクトインスペクタで接続するだけで全機能が動作します。
```

---

### 📂 ファイル・フォルダ操作コンポーネント

#### `TCTreeView` / `TCListView`
* **見た目も動作も、完全に Windows Explorer そのもの！**
* ファイルのコピー、移動、削除、新規作成、名前変更などの**実体処理を完全内蔵**。
* エクスプローラー左ペイン（ナビゲーションウィンドウ）＆右クリックコンテキストメニュー（「新規作成」「送る」等）にフル対応。
* デスクトップや他アプリからの **Drag & Drop**、ショートカット作成、アプリ関連付けに標準対応。
* Windows Theme（ダークモード/ライトモード）に完全追従。
* ⚡ **ノーコード効果**: フォームに貼るだけで、本格的なエクスプローラー機能があなたのアプリの標準機能になります。

#### `TCAddressBar`
* エクスプローラーのアドレスバーと同じ、**パンくず**（名前をクリックで移動、「>」でその下のフォルダーの一覧）。幅が足りないときは「...」にまとまる。
* クリックして**パスを直接入力**できる（Ctrl+L・Alt+D・F4）。`"` 付き・環境変数（`%USERPROFILE%`）・`/` 区切りも受ける。
* **戻る・進む・上へ・更新**、右端の「v」で**最近の場所**（履歴）の一覧。Alt+←・Alt+→・Alt+↑・F5 に対応。
* `TCListView`・`TCTreeView` のどちらか（または両方）を選ぶだけで連動し、一覧・ツリーで移ったときも、自動で変わる。
* ⚡ **ノーコード効果**: 貼って、一覧とツリーを選ぶだけで、エクスプローラーと同じアドレスバーが付きます。

#### `TCGrepFile`
* **ファイルの中身で探す（grep 検索）**。対象のファイルを名前（`*.pas;*.lfm`）で絞り、行ごとに、部分一致・正規表現で探す。
* 文字コード（UTF-8・UTF-16・Shift-JIS）は自動で判定。バイナリと大きすぎるファイルは飛ばす。別スレッドで探すので、画面は止まらない。
* 結果は「パス(行番号): 文字」の形（タグジャンプに使える形）。`OnFound` で受け取るか、ファイルへ書き出す（`OutputMode`）。あとから `SaveResults` で保存もできる。
* `TCMonacoEditor`・`TCsEditor` の `TagJump` に、結果の 1 行を渡すと、そのファイルを開いて、その行へ飛ぶ。
* ⚡ **ノーコード効果**: 置いて、フォルダーと探す文字を決めるだけで、grep 検索が付きます。

#### `TCSearchBox` / `TCFindFile`
* エクスプローラーの検索ボックスと同じ操作。**Enter でフォルダーの中を、名前で探す**（入力のたびには探さない）。
* 探し方は、**部分一致・ワイルドカード（`*.pas;*.lfm`）・正規表現**。大文字・小文字、サブフォルダー、隠しファイルの扱いも、虫眼鏡のメニューで切り替えられる。
* 探す処理は別スレッドで動くので、画面は止まらない。見つかったものは少しずつ、`TCListView` の**検索結果の表示**（名前と場所が並ぶ）に出る。開く・コピー・削除なども、ふつうの一覧と同じようにできる。
* 探す部品 `TCFindFile` は、画面を持たない部品として単独でも使える（`OnFound`・`OnFinished`、`FindAll`）。
* ⚡ **ノーコード効果**: 貼って、一覧を選ぶだけで、エクスプローラーと同じ検索が付きます。

#### `TCImage` / `TCImageList`
* `TImage`・`TImageList` と同じ使い方で、**bmp・jpg(jpeg)・png・svg・tif(tiff)・ico** を扱える。
* `SaveToFile` は、保存先の拡張子の形式に**変換して保存**し、フォルダーがなければ作る（bmp → jpg など。svg は読み込みだけ）。
* `TCImageList` は、`AddFromFile`・`AddFromImage`・`AddFromFolder` で画像を足せる。大きさは縦横比を保って合わせ、透明も保つ。
* `TImageList` の子クラスなので、`TCPageControl`・`TCSideBar`・`TCExpandPanel` などの `Images` に、そのまま選べる。
* ⚡ **ノーコード効果**: 置いて、フォルダーを指定するだけで、アイコンの一覧が付きます。

#### `TCCapture`
* デスクトップの画面を**取り込んで、ファイルに保存**する（画面なし）。bmp・jpg・png・tif・ico で保存。
* 範囲は、**デスクトップ全体（複数モニター可）・アクティブなウィンドウ・任意の長方形（x, y, x1, y1）**。
* `SaveToFile` は、フォルダーがなければ作り、拡張子の形式に変換する。`LoadFromFile` で、画像を読むこともできる。
* マウスカーソルを含める、取り込む前に待つ（`Delay`）、jpg の画質、にも対応。

#### `TCaiClient`
* **AI の API を呼ぶ**部品（画面なし）。文と添付ファイル（テキスト・CSV・PDF・画像）を送り、回答を文字列で受け取る。
* `AskAndWaitText`（Markdown の記号を使わない文章）と `AskAndWaitMD`（Markdown）の 2 つだけ。**回答が来るまで戻る**ので、`S := CaiClient1.AskAndWaitMD(Memo1.Text);` のように書ける。待つ間も画面は固まらず、`Cancel` で止められる。
* 混雑（HTTP 503）・回数制限（429）・通信の失敗は、**自動でやり直す**。待ち時間・やり直す回数は `WebView2.ini` で指定する。
* API キーは `WebView2.ini` に書かず、**環境変数**に入れる（`ApiKeyEnv`）。通信は Windows の WinHTTP なので、DLL は要らない。
* `TCMonacoEditor` と組み合わせて、エディタの文を AI に送り、回答をエディタへ入れる、といった使い方ができる。
* Gemini・Ollama（ローカル LLM。API キーも課金も不要）・ChatGPT・Meta・Claude の 5 つに対応。ChatGPT・Meta・Claude は、Ollama の互換の入口とダミーのサーバーで形式を確認済みで、本物の OpenAI・Meta・Claude での確認はこれから。
* ⚡ **ノーコード効果**: 置いて ini に URL・モデル・環境変数の名前を書くだけで、AI への質問が 1 行で書けます。
---

### 📝 テキスト・コードエディタコンポーネント

#### `TCSynEdit`
* フォームに貼るだけで、**新規作成 / 名前を付けて保存 / 上書き保存チェック / 検索・置換** が即座に利用可能。
* 拡張子を自動判別し、**26種類のプログラミング言語・ファイル形式の構文ハイライト**に対応。
* **Markdown標準対応**、文字エンコーディング・BOMの自動判別。
* ズームイン・ズームアウト、更新箇所表示、Undo/Redo、折りたたみ・折り返し対応。
* Windows Explorerからの Drag & Drop、Windows Theme にフル対応。
* ⚡ **ノーコード効果**: 1行もコードを書かずに、プロ仕様の単体コードエディタが完成します。

#### `TCSEditor`
* `TCSynEdit` の全機能を備えた**マルチタブエディタ**。
* Tear-off（タブ切り離し）/ Tear-on（ドッキング）をコード0行で実現。
* `TCPreview` と連動したリアルタイムプレビュー対応。
* シングルエディタ / タブエディタの動的切り替え、タブのドラッグ移動・破棄・独自ポップアップメニュー追加に対応。
* `TCMonacoEditor` とイベント・プロパティの**完全互換性**を確保（コンポーネントを張り替えるだけでエディタエンジンの切り替えが可能）。
* ⚡ **ノーコード効果**: 置くだけでタブ型マルチウィンドウエディタがあなたのアプリの標準機能になります。

#### `TCMonacoEditor`
* VS Codeの核である **Monaco Editor** をLazarusアプリに組み込み。
* ミニマップ表示、Markdownプレビュー、プレビューからの**PDF印刷**に対応。
* シングル/タブ切り替え、**Tear-off / Tear-on**、新規作成・開く・全ファイル一括保存・エンコード自動判別。
* 行単位のワード編集・分割、検索・置換、Undo/Redo、クリップボード操作、**F1キーでのコマンドパレット起動**に対応。
* Windows Explorerからの Drag & Drop、Windows Theme にフル対応。
* ⚡ **ノーコード効果**: コード0行で本物のVS Code開発環境をアプリ内に再現できます。

#### `TCSEditor` / `TCMonacoEditor` の組み合わせ
* **`TCFileTree` と組み合わせる**と、ファイル編集機能付きのタブテキストエディターが、ノーコードで完成します。
* **`TCBookmark` と組み合わせる**と、ファイルのバインダ管理と、編集・プレビュー・印刷（PDF 出力）まで行えます。`TCBookmark` は元のファイルの所在を集めたリンク集として働くので、元のファイルの所在を気にする必要がありません。テキスト・HTML・Markdown のどれでも、グループごとにフォルダーで分類して管理できます。
* 折り畳み・折り返し・行番号の ON/OFF はもちろん、ハイライトと `TagJump` にも標準で対応しています。
* ⚡ **ノーコード効果**: 部品を置いてつなぐだけで、ファイル管理つきのエディタ環境が完成します。

---

### 🌐 ブラウザ & プレビューコンポーネント

#### `TCTabBrowser`
* WebView2ベースの**モダンタブブラウザ**。
* 表示中ページのHTMLソース取得、ファイル保存・読み込み機能。
* タブのドラッグ移動・破棄、右クリックポップアップメニューの独自カスタマイズ。
* **画面キャプチャ保存**機能、**PDF化保存**機能を内蔵。
* 外部JavaScriptの流し込み・実行、完了復帰時のページ切り替えに対応。
* Windows Theme にフル対応。
* ページの表示は**非同期・同期の両方**に対応しているので、任意のページを表示し終えてから、次の処理を実行できます。
* 表示したページの HTML コードの取得、`UserAgent` の指定もできます。
* ページを表示したあとで **JavaScript を実行**できるので、Web ページの解析ができます。ブラウザのデバッグ機能（開発者ツール）も呼び出せます。
* 自作アプリの中に、Web ページの解析・編集・表示の機能を作り込めます。
* ⚡ **ノーコード効果**: コード0行で高機能なWebブラウザ環境をアプリに統合できます。

#### `TCPreview`
* **Markdown & Mermaid図**に完全対応した高性能プレビューエンジン。
* **対応Mermaid図（11種類）**: フローチャート（上下/左右）、シーケンス図、ユースケース図、クラス図、ER図、Gitグラフ、ユーザージャーニー、XYグラフ（棒・折れ線）、象限図、アーキテクチャ図。
* 拡大・縮小、同期スクロール＆スクロール幅調整、外部URL画像取得のON/OFF制御。
* **PDF印刷・出力**に対応。Windows Theme にフル対応。
* ⚡ **ノーコード効果**: コード0行でドキュメントや図形のインタラクティブなプレビュー環境を実現します。

#### `TCcmd`
* **フォームの中で動くコマンドプロンプト**。cmd.exe・PowerShell・ssh・vi・python などエミレート（色・カーソル・全角・選択・検索）します。
* リダイレクト（`>`・`2>&1`）とパイプ（`|`）は cmd.exe と同じように動く。コンソールの窓は出ない。
* 出力のログとコマンド履歴をファイルに保存。`RunCapture` で、コマンドの標準出力・エラー出力・終了コードを別々に受け取れる。
* フォント・色・ライト/ダークの配色・カーソル・保持する行数を、オブジェクトインスペクタで設定できる。
* 自作アプリの中で**コマンドを実行**できます。**シェルを指定**できるので、sh・bash・csh・PowerShell などが使えます。
* ssh でサーバへ接続して、ファイルを編集したり、スクリプトをその場で出力して実行したりできます。
* `TCSEditor`・`TCMonacoEditor` と組み合わせると、コード編集＋コンソールでの git 操作、その場での Python 実行などの機能を、ほんの数行で自作アプリに組み込めます。
* ⚡ **ノーコード効果**: 置くだけで、アプリにコマンドプロンプトが付く。

---

### ⚡ UIレイアウト・ナビゲーションコンポーネント

#### `TCSideBar`
* VS Codeスタイルの**ナビゲーションサイドバー**を即座に構築。
* 表示・非表示切り替え、表示幅の可変変更など、サイドバーに必要な全機能を標準装備。
* Windows Theme にフル対応。
* ⚡ **ノーコード効果**: 貼るだけでプロフェッショナルなサイドバーレイアウトが完成します。

#### `TCExpandPanel`
* アコーディオンのように**伸縮・折りたたみが可能なPanel**。
* パネルの間の境界を**マウスでドラッグして大きさを変更**（実行時・設計時）。開いている最後のパネルが、余った場所を自動で埋める。
* Windows Theme にフル対応。

#### `TCSplitter`
* 標準 `TSplitter` と同じ使い方で、**マウスを乗せたとき・ドラッグ中に青い線が出る**分割線。線の色（`HighlightColor`）とカーソル（`SplitCursor`）を指定でき、`OnMouseEnter`・`OnMouseLeave` も使える。

#### `TCPairSplitter`
* 標準の `TPairSplitter` と同じ使い方で、2 つの側（`Side1`・`Side2`）とその間の境目を持つ。
* **側ごとに隠す・出すことができる**（`Side1.Visible := False`・`Show`・`Hide`）。片方を隠すともう片方が全体に広がり、出すと元に戻る。両方は隠せない（全体は `TCPairSplitter` の `Visible` で隠す）。
* `TCSplitter` と同じ、**マウスを乗せたとき・ドラッグ中に青い線**が出る。線の色（`HighlightColor`）は設計時に変えられ、フォームデザイナで境目をドラッグできる。
* ⚡ **ノーコード効果**: 置くだけで、隠す・出すができる 2 画面のレイアウトが完成します。

#### `TCTitleBar` + `TCPageControl`
* ウィンドウの**タイトルバー上にタブを直接配置**。
* タイトルバー内にポップアップメニュー、アイコン、スピードボタンを直接搭載可能。
* タブの移動・削除・タイトル変更・スクロール表示に対応。
* Windows Theme にフル対応。
* ⚡ **ノーコード効果**: ChromeやEdgeのようなタイトルバー一体型タブUIがコード0行で実現します。

---

### 🛠 拡張標準コントロール

#### `TCCheckListBox`
* シングルライン / マルチライン選択に対応。Windows Theme にフル対応。

#### `TCGroupBox`
* 標準 `TGroupBox` の描画不具合を改善した高品質バージョン。Windows Theme にフル対応。

#### `TCCheckGroupBox`
* GroupBoxとCheckBoxが一体化。チェック状態に応じて**子コントロールの活性/非活性をコード0行で自動連動**。
* Windows Theme にフル対応。


---
* デモアプリのキャプチャー画像

![コンポーネントパレット](demo/Lazarus/20261028-122432-コンポーネントパレット.jpg)

![TCTreeView_TCListView](demo/Lazarus/20261028-122756-TCTreeView_TCListView.jpg)

![TCsynEdit](demo/Lazarus/20261028-124621-TCsynEdit.jpg)

![tcTabBrowser01](demo/Lazarus/20261028-125612-tcTabBrowser01.jpg)

![tcTabBrowser02](demo/Lazarus/20261028-130138-tcTabBrowser02.jpg)

![tcTabBrowser03](demo/Lazarus/20261028-130217-tcTabBrowser03.jpg)

![tcTabBrowser04](demo/Lazarus/20261028-130419-tcTabBrowser04.jpg)

![tcMonacoEditor](demo/Lazarus/20261028-131941-tcMonacoEditor.jpg)

![tcSideBar](demo/Lazarus/20261029-043741-tcSideBar.jpg)

![tcSideBar02](demo/Lazarus/20261030-045432-tcSideBar02.jpg)

![tcPageControl](demo/Lazarus/20261029-084726-tcPageControl.jpg)

![tcBookmarks](demo/Lazarus/20261028-133312-tcBookmarks.jpg)

![tcExpandPanel](demo/Lazarus/20261105-140515-tcExpandPanel.jpg)

![tcFileTree](demo/Lazarus/20261105-173106-tcFileTree.jpg)

![tcCmd](demo/Lazarus/20261107-221839-tcCmd.jpg)


---
