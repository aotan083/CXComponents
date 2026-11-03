# CX Components

![コンポーネントパレット](demo/Lazarus/20261028-122432-コンポーネントパレット.jpg)

私は、delphi/lazarusが大好きで、いつも利用しています。ただ日本では、ほぼだれもlazarusを知らないし、利用している人が殆どいません。使いたいツールを探しても日本にはありません。仕方がないので、自分で作成して利用しています。
ここに上げたのは、Lazarus（Free Pascal）用の部品集です。フォームに置くだけで、エクスプローラーと同じファイル操作、タブ付きブラウザ、タブ付きエディタ（Monaco・SynEdit）、Markdown のプレビュー、ブックマーク管理などが使えます。まだWindows版しかありません。ニーズあったらLinux版も作成してみたいと思います。使い方は、Usageを参照して下さい。中の仕組みは、Designに記載しています。興味があるかたは見て下さい。英語が苦手なので、コードのコメントは日本語のままです。

作者: aotan083 ／ ライセンス: MIT

[English Documentation](README.md) | [日本語ドキュメント](README.ja.md)

## 部品

| 部品 | 中身 | 取扱説明書 | 設計書 |
|---|---|---|---|
| TCTreeView | エクスプローラーの左側と同じフォルダーのツリー | [Usage](docs/TCTreeView_Usage.md) | [Design](docs/TCTreeView_Design.md) |
| TCListView | エクスプローラーの右側と同じファイルの一覧 | [Usage](docs/TCListView_Usage.md) | [Design](docs/TCListView_Design.md) |
| TCSynEdit | TSynEdit に、ファイルの読み書き・配色（VS Code のライト・ダークを含む）・拡張子に合わせた色分け（Markdown を含む）・右クリックメニューを足したエディタ | [Usage](docs/TCSynEdit_Usage.md) | [Design](docs/TCSynEdit_Design.md) |
| TCCheckListBox | チェックを 1 つだけにできる TCheckListBox | [Usage](docs/TCCheckListBox_Usage.md) | [Design](docs/TCCheckListBox_Design.md) |
| TCGroupBox・TCCheckGroupBox | 中の部品が消えないグループボックスと、チェック付きの見出しのグループボックス | [Usage](docs/TCGroupBox_Usage.md) | [Design](docs/TCGroupBox_Design.md) |
| TCSideBar | Edge のようなアイコン列と開閉するパネル | [Usage](docs/TCSideBar_Usage.md) | [Design](docs/TCSideBar_Design.md) |
| TCPageControl・TCTitleBar | ブラウザのようなタブと、タブを並べられるタイトルバー | [Usage](docs/TCPageControl_Usage.md) | [Design](docs/TCPageControl_Design.md) |
| TCTabBrowser | WebView2 を使ったタブ付きの Web ブラウザ | [Usage](docs/TCTabBrowser_Usage.md) | [Design](docs/TCTabBrowser_Design.md) |
| TCMonacoEditor・TCMFindDialog | WebView2 と Monaco Editor によるエディタ（タブ・プレビュー・検索・印刷を内蔵）と、標準アクション 25 個 | [Usage](docs/TCMonacoEditor_Usage.md) | [Design](docs/TCMonacoEditor_Design.md) |
| TCsEditor・TCsFindDialog | TCSynEdit をタブで複数持つエディタ。使い方は TCMonacoEditor と同じ（検索・置換ダイアログ・ミニマップ・タブの分離を含む）。標準アクション 25 個 | [Usage](docs/TCsEditor_Usage.md) | [Design](docs/TCsEditor_Design.md) |
| TCPreview | TCsEditor のプレビュー（Markdown・コード）と印刷（PDF 保存）。エディタとは別の場所に置き、複数のエディタで共有できる | [Usage](docs/TCPreview_Usage.md) | [Design](docs/TCPreview_Design.md) |
| TCBookmark | Firefox のようなブックマーク管理（TCTabBrowser・TCMonacoEditor で開く） | [Usage](docs/TCBookmark_Usage.md) | [Design](docs/TCBookmark_Design.md) |

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
| `docs` | 部品ごとの取扱説明書（`*_Usage.md`）と設計書（`*_Design.md`） |
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

TCTabBrowser・TCMonacoEditor・TCBookmark・TCPreview を使うアプリは、EXE と同じフォルダーに次のファイルを置く。

| ファイル | 中身 |
|---|---|
| `WebView2.ini` | 必ず置く。キーの値は空でもよい（空なら EXE のフォルダーの既定の場所を使う） |
| `WebView2Loader.dll` | 64 ビット版。WebView4Delphi のリポジトリから入手する |
| `monaco\` | TCMonacoEditor のエディタ（TCMonacoEditor だけ。`runtime\monaco`。`vs` は npm の `monaco-editor` の `min\vs`） |
| `preview\` | TCMonacoEditor・TCPreview のプレビュー（`runtime\preview`） |

```ini
[WebView2]
LoaderDllPath=
UserDataFolder=
MonacoFolder=
PreviewFolder=
```

| キー | 中身 | 空のとき |
|---|---|---|
| `LoaderDllPath` | WebView2Loader.dll のファイル | EXE のフォルダーの WebView2Loader.dll |
| `UserDataFolder` | WebView2 のユーザーデータのフォルダー | EXE のフォルダー\WebView2Data |
| `MonacoFolder` | `editor.html` と `vs` があるフォルダー | EXE のフォルダー\monaco |
| `PreviewFolder` | `preview.html` と `lib` があるフォルダー | EXE のフォルダー\preview |

- 相対パスは EXE のフォルダーから数える。複数のアプリで 1 か所の `monaco`・`preview` を使うこともできる（[TCMonacoEditor の取扱説明書](docs/TCMonacoEditor_Usage.md)）。
- 実行には Microsoft Edge WebView2 ランタイム（Windows 11 には最初から入っている）が要る。
- TCsEditor だけなら、実行時のファイルは要らない。TCPreview を使うときだけ置く。

## ライセンス

MIT ライセンス（[LICENSE](LICENSE)）。外部のライブラリのライセンスは [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) にある。

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

---
