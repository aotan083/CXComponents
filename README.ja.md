# CX Components

Lazarus（Free Pascal）用の部品集です。フォームに置くだけで、エクスプローラーと同じファイル操作、タブ付きブラウザ、Monaco エディタ、ブックマーク管理などが使えます。

作者: aotan083 ／ ライセンス: MIT

## 部品

| 部品 | 中身 | 取扱説明書 | 設計書 |
|---|---|---|---|
| TCTreeView | エクスプローラーの左側と同じフォルダーのツリー | [Usage](docs/TCTreeView_Usage.md) | [Design](docs/TCTreeView_Design.md) |
| TCListView | エクスプローラーの右側と同じファイルの一覧 | [Usage](docs/TCListView_Usage.md) | [Design](docs/TCListView_Design.md) |
| TCSynEdit | TSynEdit に、ファイルの読み書き・文字コード・配色・右クリックメニューを足したエディタ | [Usage](docs/TCSynEdit_Usage.md) | [Design](docs/TCSynEdit_Design.md) |
| TCCheckListBox | チェックを 1 つだけにできる TCheckListBox | [Usage](docs/TCCheckListBox_Usage.md) | [Design](docs/TCCheckListBox_Design.md) |
| TCGroupBox・TCCheckGroupBox | 中の部品が消えないグループボックスと、チェック付きの見出しのグループボックス | [Usage](docs/TCGroupBox_Usage.md) | [Design](docs/TCGroupBox_Design.md) |
| TCSideBar | Edge のようなアイコン列と開閉するパネル | [Usage](docs/TCSideBar_Usage.md) | [Design](docs/TCSideBar_Design.md) |
| TCPageControl・TCTitleBar | ブラウザのようなタブと、タブを並べられるタイトルバー | [Usage](docs/TCPageControl_Usage.md) | [Design](docs/TCPageControl_Design.md) |
| TCTabBrowser | WebView2 を使ったタブ付きの Web ブラウザ | [Usage](docs/TCTabBrowser_Usage.md) | [Design](docs/TCTabBrowser_Design.md) |
| TCMonacoEditor・TCMFindDialog | WebView2 と Monaco Editor によるエディタ（タブ・プレビュー・検索・印刷を内蔵）と、標準アクション 25 個 | [Usage](docs/TCMonacoEditor_Usage.md) | [Design](docs/TCMonacoEditor_Design.md) |
| TCBookmark | Firefox のようなブックマーク管理（TCTabBrowser・TCMonacoEditor で開く） | [Usage](docs/TCBookmark_Usage.md) | [Design](docs/TCBookmark_Design.md) |

すべての部品は、パレット [CX] に出ます。

## 動作環境

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
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
| `THIRD_PARTY` | 使っている外部ライブラリ |

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

TCTabBrowser・TCMonacoEditor・TCBookmark を使うアプリは、EXE と同じフォルダーに次のファイルを置く。

| ファイル | 中身 |
|---|---|
| `WebView2.ini` | 必ず置く。キーの値は空でもよい（空なら EXE のフォルダーの既定の場所を使う） |
| `WebView2Loader.dll` | 64 ビット版。WebView4Delphi のリポジトリから入手する |
| `monaco\` | TCMonacoEditor のエディタ（`runtime\monaco`。`vs` は npm の `monaco-editor` の `min\vs`） |
| `preview\` | TCMonacoEditor のプレビュー（`runtime\preview`） |

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

## ライセンス

MIT ライセンス（[LICENSE](LICENSE)）。外部のライブラリのライセンスは [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) にある。
