# TCTabBrowser 取扱説明書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 概要とクラス

WebView2（Microsoft Edge のしくみ）を使った、タブ付きの Web ブラウザです。タブごとに別の Web ページを表示し、ページの保存（HTML・MHTML・画像・PDF）、JavaScript の実行、ダウンロードの受け取り、右クリックメニューへの項目の追加ができます。

```
+-----------+-----------+------------------------------+
| Google  × | GitHub  × |                              |
+-----------+-----------+------------------------------+
|                                                      |
|   表示中のタブの Web ページ                             |
|                                                      |
+------------------------------------------------------+
```

- タブの見出しの［×］で、そのタブを閉じる。
- タブは 0 枚にならない。最後のタブを閉じると、部品が新しいタブを 1 枚作る。
- ページが新しいウィンドウを開こうとしたときは、ウィンドウを開かずに新しいタブで開く。
- 同じアプリの中のほかの WebView2（TCMonacoEditor など）とは別のブラウザのプロセスで動くため、互いの処理で固まらない。
- WebView2 の準備は、部品が自分で行う（アプリの .lpr には何も書かない）。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |
| 実行に必要なもの | Microsoft Edge WebView2 ランタイム（Windows 11 には最初から入っている）、WebView2Loader.dll（64 ビット版）、WebView2.ini |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCTabBrowser` | `uCTabBrowser` | cx | `TPageControl` | WebView2 を使った、タブ付きの Web ブラウザ。ページの保存（HTML・MHTML・画像・PDF）、JavaScript の実行、ダウンロードの受け取り、右クリックメニューへの項目の追加ができる |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCTabPanel` | `uCTabBrowser` | タブの情報（`Panels[i]`・`ActiveTab` で取る）。4.2 |
| `TTabNewTabReason` | `uCTabBrowser` | 部品が新しいタブを作る理由。`ntrMenuNew`（右クリックメニューの「新規作成」）・`ntrLastTabClosed`（最後のタブを閉じた） |
| `TTabDocumentCompleteEvent` | `uCTabBrowser` | `procedure(Sender: TObject; ATabIndex: Integer; ASuccess: Boolean) of object`。`OnDocumentComplete` の型 |
| `TTabNewWindowRequestedEvent` | `uCTabBrowser` | `procedure(Sender: TObject; ATabIndex: Integer; var AURI: string; var AAccept: Boolean) of object`。`OnNewWindowRequested` の型 |
| `TTabBasicAuthenticationRequestedEvent` | `uCTabBrowser` | `procedure(Sender: TObject; ATabIndex: Integer; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2BasicAuthenticationRequestedEventArgs) of object`。`OnBasicAuthenticationRequested` の型 |
| `TTabDownloadStartingEvent` | `uCTabBrowser` | `procedure(Sender: TObject; ATabIndex: Integer; const AURI: string; var AFileName: string; var ACancel: Boolean) of object`。`OnDownloadStarting` の型 |
| `TTabDownloadCompletedEvent` | `uCTabBrowser` | `procedure(Sender: TObject; ATabIndex: Integer; const AFileName: string; ASuccess: Boolean) of object`。`OnDownloadCompleted` の型 |
| `TTabNewTabRequestEvent` | `uCTabBrowser` | `procedure(Sender: TObject; AReason: TTabNewTabReason; var AURL: string; var AAccept: Boolean) of object`。`OnNewTabRequest` の型 |
| `TTabScriptResultEvent` | `uCTabBrowser` | `procedure(Sender: TObject; AID: Integer; ASuccess: Boolean; const AResultJson: string) of object`。`RunScriptAsync` の結果を受け取る型 |

- フォームに置くと、uses に `uCTabBrowser` が自動で入る。
- フォームに置くと、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。
- `OnBasicAuthenticationRequested` を使うときは、uses に WebView4Delphi の `uWVTypeLibrary`（`ICoreWebView2` などの型）も書く。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCTabBrowser をフォームに置く。
2. 実行ファイル（EXE）と同じフォルダーに、WebView2Loader.dll（64 ビット版）を置く。WebView4Delphi のリポジトリ（https://github.com/salvadordf/WebView4Delphi）から入手する。
3. EXE と同じフォルダーに、WebView2.ini を置く（2.1）。
4. フォームの `OnShow` に、最初のタブを開く処理を書く（9.1）。
5. 読み込みが終わったときに処理をするときは、イベントタブの `OnDocumentComplete` をダブルクリックして処理を書く（9.2）。
6. 実行する。

- WebView2 の準備（`GlobalWebView2Loader` の作成と `StartWebView2`）は、最初にタブを作るとき（`Add`・`Insert`・`Navigate`）に、部品が自分で行う。アプリの .lpr には何も書かない。
- WebView2 の準備は、アプリの中で 1 回だけ行う。TCMonacoEditor など、ほかの CX の WebView2 部品と同じものを使う。
- WebView2.ini がないとき、WebView2 の準備ができないときは、タブを作るメソッドが例外（`Exception`）を出す。メッセージは「WebView2.ini が見つかりません: （ファイルの場所）」または WebView2 のエラーの文。

### 2.1 WebView2.ini

EXE と同じフォルダーに置く。CX の WebView2 部品（TCTabBrowser・TCMonacoEditor）で共通。

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
| `UserDataFolder` | WebView2 のユーザーデータのフォルダー（TCMonacoEditor が使う。TCTabBrowser は使わない。7章） | EXE のフォルダー\WebView2Data |
| `MonacoFolder` | TCMonacoEditor の `editor.html` と `vs` があるフォルダー。TCTabBrowser の設定ファイル（7章）もここに置く | EXE のフォルダー\monaco |
| `PreviewFolder` | TCMonacoEditor の `preview.html` と `lib` があるフォルダー | EXE のフォルダー\preview |

- ファイルは必ず置く。キーの値はすべて空でもよい（すべて、空のときの場所を使う）。
- 相対パスは、EXE のフォルダーから数える。絶対パスも書ける。
- 起動してから最初に使うときに 1 回だけ読む。実行中に書き換えても、次の起動まで効かない。

**タブの動き**

| 動き | 中身 |
|---|---|
| タブの見出し | 最初は「タブ n」。ページのタイトルが決まると、タイトルに変わる |
| 見出しを隠す | `HideSingleTab = True`（既定値）なら、タブが1枚以下のときは見出しを隠す |
| ［×］ | そのタブを閉じる |
| 表示中のタブを閉じた | 右隣のタブを表示する。右隣がなければ左隣 |
| 最後のタブを閉じた | `OnNewTabRequest`（`AReason = ntrLastTabClosed`）で URL を決め、閉じたタブがその URL を表示していれば何もしない。それ以外は、タブを閉じて、その URL で新しいタブを作る（タブは0枚にならない） |
| ページが新しいウィンドウを開こうとした | ウィンドウを開かず、末尾の新しいタブで開く |
| F5 | 表示中のページを再読み込み |

## 3. プロパティ

### 3.1 この部品で足したもの

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Count` | `Integer` | 読み | タブの枚数。実行時だけ |
| `ActiveIndex` | `Integer` | 読み・書き | 表示中のタブの番号（0 から）。書くと切り替わる。範囲の外を書いたときは何もしない。実行時だけ |
| `Panels[AIndex]` | `TCTabPanel` | 読み | その番号のタブの情報（4.2）。範囲の外のときは、どの値も ''。実行時だけ |
| `ActiveTab` | `TCTabPanel` | 読み | 表示中のタブの情報（4.2）。実行時だけ |
| `ContextTabIndex` | `Integer` | 読み | 最後に右クリックしたタブの番号（既定値は -1）。6章。実行時だけ |
| `HideSingleTab` | `Boolean` | 読み・書き | `True`（既定値）なら、タブが1枚以下のときは見出しを隠す |
| `UserAgent` | `string` | 読み・書き | 読むと、表示中のタブで使っている User-Agent（タブがないときは設定した値）。書くと、すべてのタブとこれから作るタブに設定する。'' なら WebView2 の標準 |
| `IgnoreCertificateErrors` | `Boolean` | 読み・書き | `True`（既定値）なら、証明書のエラーを無視してページを表示する。すべてのタブとこれから作るタブに設定する。インターネット上の一般のサイトを表示するアプリでは、`False` にすることを考える |
| `SavePath` | `string` | 読み・書き | `SaveScreenCapture`・`SavePDF` でファイル名を省いたときの保存先のフォルダー（既定値は、部品を作ったときのカレントフォルダー） |
| `HeaderPopupMenu` | `TPopupMenu` | 読み・書き | タブの見出しの右クリックメニューに足す項目（6章） |
| `PagePopupMenu` | `TPopupMenu` | 読み・書き | Web ページの右クリックメニューに足す項目（6章） |

### 3.2 TPageControl から引き継いだもの

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `ActivePage` | `TTabSheet` | 読み・書き | 表示中のタブのページ。書くと切り替わる（`ActiveIndex` と同じ働き）。実行時に使う |
| `Align` | `TAlign` | 読み・書き | 親の中での配置 |
| `Anchors` | `TAnchors` | 読み・書き | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `AnchorSideBottom` | `TAnchorSide` | 読み・書き | 下の辺を、どの部品のどこに合わせるか |
| `AnchorSideLeft` | `TAnchorSide` | 読み・書き | 左の辺を、どの部品のどこに合わせるか |
| `AnchorSideRight` | `TAnchorSide` | 読み・書き | 右の辺を、どの部品のどこに合わせるか |
| `AnchorSideTop` | `TAnchorSide` | 読み・書き | 上の辺を、どの部品のどこに合わせるか |
| `AutoSize` | `Boolean` | 読み・書き | 中身に合わせて大きさを変えるか |
| `BiDiMode` | `TBiDiMode` | 読み・書き | 右から左に並べるか |
| `BorderSpacing` | `TControlBorderSpacing` | 読み・書き | 周りの余白 |
| `Constraints` | `TSizeConstraints` | 読み・書き | 大きさの上限・下限 |
| `Cursor` | `TCursor` | 読み・書き | 上に来たときのマウスカーソル |
| `DragCursor` | `TCursor` | 読み・書き | ドラッグ中のマウスカーソル |
| `DragKind` | `TDragKind` | 読み・書き | ドラッグの種類（ドラッグ＆ドロップか、ドッキングか） |
| `DragMode` | `TDragMode` | 読み・書き | ドラッグを自動で始めるか |
| `Enabled` | `Boolean` | 読み・書き | 使えるか |
| `Font` | `TFont` | 読み・書き | タブの見出しの文字 |
| `Height` | `Integer` | 読み・書き | 高さ |
| `HelpContext` | `THelpContext` | 読み・書き | ヘルプの番号 |
| `HelpKeyword` | `string` | 読み・書き | ヘルプのキーワード |
| `HelpType` | `THelpType` | 読み・書き | ヘルプを番号で引くか（`htContext`）、キーワードで引くか（`htKeyword`） |
| `Hint` | `TTranslateString` | 読み・書き | ヒントの文字 |
| `HotTrack` | `Boolean` | 読み・書き | マウスを乗せたタブを強調するか |
| `Images` | `TCustomImageList` | 読み・書き | タブのアイコン（番号は `OnGetImageIndex` で決める） |
| `ImagesWidth` | `Integer` | 読み・書き | アイコンの幅 |
| `Left` | `Integer` | 読み・書き | 左端の位置 |
| `MultiLine` | `Boolean` | 読み・書き | タブを複数の段に並べるか |
| `Name` | `TComponentName` | 読み・書き | 部品の名前 |
| `Options` | `TCTabControlOptions` | 読み・書き | タブの設定（既定値は `[nboShowCloseButtons]`）。`nboShowCloseButtons` を外すと、タブの［×］が出なくなる |
| `ParentBiDiMode` | `Boolean` | 読み・書き | 親の `BiDiMode` を使うか |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `ParentShowHint` | `Boolean` | 読み・書き | 親の `ShowHint` を使うか |
| `RaggedRight` | `Boolean` | 読み・書き | 複数の段のとき、タブを右端までそろえないか |
| `ScrollOpposite` | `Boolean` | 読み・書き | 複数の段のとき、選んだ段を反対側へ動かすか |
| `ShowHint` | `Boolean` | 読み・書き | ヒントを出すか |
| `Style` | `TTabStyle` | 読み・書き | タブの形（タブ・ボタン・平らなボタン） |
| `TabHeight` | `Smallint` | 読み・書き | タブの高さ（0 で自動） |
| `TabIndex` | `Integer` | 読み・書き | 表示中のタブの番号（`ActiveIndex` と同じ働き） |
| `TabOrder` | `TTabOrder` | 読み・書き | Tab キーで移る順番 |
| `TabPosition` | `TTabPosition` | 読み・書き | タブの位置（上・下・左・右） |
| `TabStop` | `Boolean` | 読み・書き | Tab キーで止まるか |
| `TabWidth` | `Smallint` | 読み・書き | タブの幅（0 で文字に合わせる） |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値 |
| `Top` | `Integer` | 読み・書き | 上端の位置 |
| `Visible` | `Boolean` | 読み・書き | 表示するか |
| `Width` | `Integer` | 読み・書き | 幅 |

## 4. メソッドと TCTabPanel

### 4.1 メソッド

**タブ**

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | ― | 作る。コードで作るときに使う（9.10） |
| `Add` | `const AURL: string = 'about:blank'` | `Integer` | 末尾にタブを足し、`AURL` を開いて表示する。足したタブの番号を返す。読み込みは待たない |
| `Insert` | `i: Integer; const AURL: string = 'about:blank'` | `Integer` | 番号 `i` の位置にタブを足し、`AURL` を開いて表示する。`i` は 0 ～ `Count` の範囲に収める。足したタブの番号を返す |
| `Remove` | ― | ― | 表示中のタブを閉じる（2章の「タブの動き」） |
| `Remove` | `i: Integer` | ― | 番号 `i` のタブを閉じる。範囲の外なら何もしない |

- `Add`・`Insert` は、WebView2 の準備ができないときは例外を出す（2章）。
- 閉じたタブで受け取り中のダウンロードは、`OnDownloadCompleted` を出さずに見るのをやめる。
- 閉じたタブの `RunScriptAsync` の結果は、`ACallback` を呼ばずに捨てる。

**ページの表示**

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Navigate` | `const AURL: string` | ― | 表示中のタブで `AURL` を開く。読み込みは待たない。タブがなければ、タブを足して開く |
| `NavigateAndWait` | `const AURL: string; TimeoutMS: Integer = 60000` | `Boolean` | `Navigate` と同じように開き、読み込みが終わるまで待つ。成功なら `True`。失敗したとき、`TimeoutMS`（ミリ秒）を過ぎたときは `False` |
| `Back` | ― | ― | 表示中のタブで前のページに戻る |
| `Next` | ― | ― | 表示中のタブで次のページに進む |
| `Reload` | ― | ― | 表示中のタブを再読み込みする（F5 と同じ） |
| `LoadFromFile` | `const AFileName: string` | ― | 表示中のタブで、ファイルを開いて表示する |

**保存**

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `SaveToFile` | `sFileName: String` | ― | 表示中のタブの HTML ソースを保存する。取れなかった・中身が空のときは保存しない。書き込めないときは例外 |
| `SaveAsWebPage` | `sFileName: String` | ― | 表示中のタブのページ全体を MHTML 形式（1ファイル）で保存する。取れなかった・中身が空のときは保存しない。書き込めないときは例外 |
| `SaveScreenCapture` | `const AFileName: string = ''` | ― | 表示中のタブの画面を JPEG で保存する。省くと `SavePath\（ページのタイトル）.jpg`。画面を取れなかったときも、空のファイルが残ることがある |
| `SavePDF` | `const AFileName: string = ''` | ― | 表示中のタブのページを PDF で保存する。省くと `SavePath\（ページのタイトル）.pdf` |

- 保存先のフォルダーがなければ作る。同じ名前のファイルがあれば上書きする。
- ファイル名を省いたとき、タイトルの中のファイル名に使えない文字（`\ / : * ? " < > |`）は「_」にする。タイトルが空なら「capture」にする。
- 保存が終わるまで待つ（待つ間も画面の処理は動く）。時間の上限はない。

**JavaScript の実行**

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `RunScript` | `const AScript: string; out AResultJson: string; ATimeoutMS: Integer = 30000` | `Boolean` | 表示中のタブで JavaScript を実行し、結果が返るまで待つ。成功なら `True`。タブがない・ブラウザの準備ができていない・失敗・時間切れのときは `False`。`AResultJson` には結果が JSON の文字列で入る（文字列の結果は `"..."` で囲まれた形）。`ATimeoutMS` が 0 以下なら上限なし |
| `RunScriptAsync` | `ATabIndex: Integer; const AScript: string; ACallback: TTabScriptResultEvent` | `Integer` | 番号 `ATabIndex` のタブで JavaScript を実行し、結果を待たずにすぐ戻る。受付番号（1 以上）を返す。実行できないとき（タブの番号が範囲の外・ブラウザの準備ができていない）は 0。結果は `ACallback` で知らせる |
| `CancelScriptAsync` | `AID: Integer` | ― | `RunScriptAsync` の結果待ちを取り消す。取り消した後は `ACallback` を呼ばない。`ACallback` を持つ側が TCTabBrowser より先に破棄されるときは、必ず先に呼ぶ |

**表示の調整**

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `SynchronizeBounds` | ― | ― | 表示中のタブの表示領域の大きさを合わせる。部品が自動で行うので、ふつうは呼ばなくてよい |
| `SynchronizeVisibility` | ― | ― | 表示中のタブだけを表示する。部品が自動で行うので、ふつうは呼ばなくてよい |

- `NavigateAndWait`・`RunScript`・`SaveToFile` などの待つメソッドは、待つ間も画面の処理が動く。待っている間に、同じ TCTabBrowser のほかの待つメソッドを呼ばない。

### 4.2 TCTabPanel（タブの情報）

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Title` | `string` | 読み | ページのタイトル |
| `URL` | `string` | 読み | 表示中の URL |
| `SourceText` | `string` | 読み | 読んだときの HTML ソース。取れるまで待つ（待つ間も画面の処理は動く）。取れないときは '' |

## 5. イベント

### 5.1 この部品で足したもの

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnDocumentComplete` | `Sender: TObject; ATabIndex: Integer; ASuccess: Boolean` | ページの読み込みが終わった。`ATabIndex` はそのタブの番号。`ASuccess` は成功なら `True` |
| `OnNewWindowRequested` | `Sender: TObject; ATabIndex: Integer; var AURI: string; var AAccept: Boolean` | ページが新しいウィンドウを開こうとした。`AURI` を書き換えると、その URL を開く。`AAccept`（最初は `True`）を `False` にすると何も開かない。`True` なら末尾の新しいタブで開く（このイベントを使わないときも同じ） |
| `OnBasicAuthenticationRequested` | `Sender: TObject; ATabIndex: Integer; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2BasicAuthenticationRequestedEventArgs` | HTTP の認証（Basic 認証）を求められた。ユーザー名・パスワードの設定や中止は、`AArgs` を直接使って行う。このイベントを使わないときは、WebView2 の標準の認証画面が出る |
| `OnDownloadStarting` | `Sender: TObject; ATabIndex: Integer; const AURI: string; var AFileName: string; var ACancel: Boolean` | ダウンロードが始まる。`AFileName` は保存先（フルパス。最初は WebView2 の標準の保存先）で、書き換えるとその場所に保存する。`ACancel`（最初は `False`）を `True` にするとやめる。このイベントを使うと、WebView2 の標準のダウンロードの表示は出ない |
| `OnDownloadCompleted` | `Sender: TObject; ATabIndex: Integer; const AFileName: string; ASuccess: Boolean` | ダウンロードが終わった。`AFileName` は保存先（フルパス）。`ASuccess` は完了なら `True`、中断・失敗なら `False` |
| `OnNewTabRequest` | `Sender: TObject; AReason: TTabNewTabReason; var AURL: string; var AAccept: Boolean` | 部品が新しいタブを作る前。`AURL`（最初は about:blank）を書き換えると、その URL で開く（'' なら about:blank）。`AAccept`（最初は `True`）を `False` にするとやめる。ただし `ntrLastTabClosed` のときはやめられず、about:blank で開く |

- `OnNewTabRequest` の `ntrLastTabClosed` で返す URL は、ページを開いた後に表示される URL と同じ書き方にする（末尾の「/」の有無など）。違うと、最後のタブを閉じるたびにタブが作り直される。

### 5.2 TPageControl から引き継いだもの

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnChange` | `Sender: TObject` | 表示中のタブが変わった後 |
| `OnChanging` | `Sender: TObject; var AllowChange: Boolean` | 表示中のタブが変わる前。`AllowChange := False` で取りやめる |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | LCL のドラッグ（アプリの中の部品どうし）でドロップされた |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | LCL のドラッグで、ドラッグしている物が上に来た。`Accept` で受けるかを決める |
| `OnEndDock` | `Sender, Target: TObject; X, Y: Integer` | ドッキングが終わった |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | LCL のドラッグが終わった |
| `OnEnter` | `Sender: TObject` | フォーカスが入った |
| `OnExit` | `Sender: TObject` | フォーカスが出た |
| `OnGetImageIndex` | `Sender: TObject; TabIndex: Integer; var ImageIndex: Integer` | タブのアイコンの番号を決めるとき（`Images` を使うとき） |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | タブの見出しでマウスのボタンが押された |
| `OnMouseEnter` | `Sender: TObject` | マウスが上に入った |
| `OnMouseLeave` | `Sender: TObject` | マウスが外に出た |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | タブの見出しでマウスが動いた |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | タブの見出しでマウスのボタンが離された |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | ホイールが回された |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが手前に回された |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが奥に回された |
| `OnResize` | `Sender: TObject` | 大きさが変わった |
| `OnStartDock` | `Sender: TObject; var DragObject: TDragDockObject` | ドッキングのドラッグを始めた |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | LCL のドラッグを始めた |

- Web ページの上のマウス・キーは、WebView2 が受けるため、これらのイベントは出ない。

## 6. 右クリックメニュー

| 右クリックした場所 | 出るメニュー |
|---|---|
| タブの見出し（タブの上） | 「閉じる」→ 区切り線 → `HeaderPopupMenu` の項目 |
| タブの見出し（タブのない所） | 何も出ない |
| Web ページ | WebView2 の標準の項目（右クリックした場所に合ったもの）→ 区切り線 →「新規作成」「閉じる」→ 区切り線 → `PagePopupMenu` の項目 |

- 「閉じる」は、右クリックしたタブを閉じる。「新規作成」は、末尾に新しいタブを足して表示する（URL は `OnNewTabRequest` で決める）。
- `HeaderPopupMenu`・`PagePopupMenu` を設定しないときは、アプリの項目と、その前の区切り線は出ない。
- 両方に同じ TPopupMenu を設定できる。
- メニューを出す直前に、TPopupMenu の `OnPopup` を呼ぶ。項目の有効・無効やチェックは、`OnPopup` の中で合わせる。
- 写した項目を選ぶと、元の項目の `Click` を呼ぶ（`OnClick`・`Action`・`AutoCheck` はいつもどおり動く）。`PagePopupMenu` の項目は、メニューが閉じた後に実行される。

**アプリの TPopupMenu の項目の写し方**

| 元の項目 | 写した後 |
|---|---|
| `Visible = False` | 写さない |
| `Caption = '-'` | 区切り線 |
| `Caption` | そのまま（& のアクセスキーも含む） |
| `Enabled` | そのまま |
| `Checked` | そのまま（チェック付きの項目になる） |
| 子の項目あり | サブメニューになり、子の項目も同じ決まりで写す |
| アイコン（`ImageIndex`・`Bitmap`） | 写さない |
| ショートカットキー | `HeaderPopupMenu`：表示される。`PagePopupMenu`：表示されない |

**右クリックしたタブ（`ContextTabIndex`）**

| とき | 入る値 |
|---|---|
| タブの見出しを右クリックした | そのタブの番号 |
| Web ページを右クリックした | そのページのタブの番号 |
| `PagePopupMenu` の項目を実行するとき | 右クリックしたタブの今の番号。その間にタブが閉じられていれば -1 |

## 7. ブラウザのデータと設定ファイル

| 項目 | 場所 |
|---|---|
| データフォルダー | EXE のフォルダー\TabBrowserData（すべてのタブで共通。ログインの状態などが保存される） |
| 設定ファイル | WebView2.ini の `MonacoFolder` のフォルダー\tabbrowser.json（`MonacoFolder` が空なら EXE のフォルダー\monaco\tabbrowser.json） |

- データフォルダーは、WebView2.ini の `UserDataFolder` とは別にしている。別のフォルダーを使うと、TCMonacoEditor などとは別のブラウザのプロセスになる。
- 設定ファイルは、部品を作ったときに読む（IDE の上では読まない）。なければ `{ "cacheSizeMB": 0 }` の内容で作る（フォルダーがなければフォルダーも作る）。作れないときは、何も言わずに既定値で動く。

| キー | 中身 |
|---|---|
| `cacheSizeMB` | ブラウザのキャッシュの上限（MB）。0 は上限なし。読めない・0 未満のときも上限なし |

## 8. 注意

### 8.1 変えないでください

次のプロパティは部品の中で使っている。値を変えると、正しく動かなくなる。

| 名前 | 理由 |
|---|---|
| `PopupMenu` | タブの見出しの右クリックメニューに使っている。項目を足すときは `HeaderPopupMenu`・`PagePopupMenu` を使う |
| `OnContextPopup` | タブの見出しの右クリックに使っている |
| `OnCloseTabClicked` | ［×］でタブを閉じるのに使っている |
| `ShowTabs` | `HideSingleTab` で部品が切り替える |

### 8.2 そのほか

- Windows 専用。
- タブ（`TTabSheet`）を、`Add`・`Insert`・`Remove` 以外の方法（IDE の「ページを追加」、`TTabSheet.Create` など）で足したり消したりしない。ブラウザのないタブになる。
- 古い WebView2 ランタイムでは、Web ページの右クリックメニューに「新規作成」「閉じる」とアプリの項目が出ず、WebView2 の標準の項目だけになる。
- Web ページにフォーカスがあるときは、キー（F5 を除く）がアプリに届かない。フォームの `OnKeyDown` や ActionList のショートカットは動かない。
- IDE の上（設計時）では、タブもブラウザも作らない。空の枠だけが出る。

## 9. 使い方の例

### 9.1 起動したときに最初のタブを開く

```pascal
procedure TForm1.FormShow(Sender: TObject);
begin
  CTabBrowser1.Add('https://www.lazarus-ide.org/');
end;
```

### 9.2 読み込みが終わったら、タイトルをフォームに出す

```pascal
procedure TForm1.CTabBrowser1DocumentComplete(Sender: TObject;
  ATabIndex: Integer; ASuccess: Boolean);
begin
  if ATabIndex = CTabBrowser1.ActiveIndex then
    Caption := CTabBrowser1.ActiveTab.Title;
end;

procedure TForm1.CTabBrowser1Change(Sender: TObject);
begin
  Caption := CTabBrowser1.ActiveTab.Title;   // タブを切り替えたときも出す
end;
```

### 9.3 アドレスバーと戻る・進むボタン

```pascal
procedure TForm1.btnGoClick(Sender: TObject);
begin
  CTabBrowser1.Navigate(Edit1.Text);   // 表示中のタブで開く
end;

procedure TForm1.btnNewTabClick(Sender: TObject);
begin
  CTabBrowser1.Add(Edit1.Text);        // 新しいタブで開く
end;

procedure TForm1.btnBackClick(Sender: TObject);
begin
  CTabBrowser1.Back;
end;

procedure TForm1.btnNextClick(Sender: TObject);
begin
  CTabBrowser1.Next;
end;
```

### 9.4 開いて、読み込みが終わるまで待ってから、JavaScript でタイトルを取る

```pascal
procedure TForm1.btnTitleClick(Sender: TObject);
var
  Json: string;
begin
  if CTabBrowser1.NavigateAndWait('https://example.com/') then
    if CTabBrowser1.RunScript('document.title', Json) then
      ShowMessage(Json);   // "Example Domain"（JSON の文字列として返る）
end;
```

### 9.5 JavaScript を、結果を待たずに実行する

```pascal
procedure TForm1.btnLinksClick(Sender: TObject);
begin
  FScriptID := CTabBrowser1.RunScriptAsync(CTabBrowser1.ActiveIndex,
    'document.links.length', @LinksResult);
end;

procedure TForm1.LinksResult(Sender: TObject; AID: Integer;
  ASuccess: Boolean; const AResultJson: string);
begin
  if ASuccess then
    StatusBar1.SimpleText := 'リンクの数：' + AResultJson;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  CTabBrowser1.CancelScriptAsync(FScriptID);   // 結果を受け取る側が先に消えるときは取り消す
end;
```

### 9.6 ページを保存する

```pascal
CTabBrowser1.SavePath := 'C:\Save';
CTabBrowser1.SavePDF;                                 // C:\Save\（タイトル）.pdf
CTabBrowser1.SaveScreenCapture;                       // C:\Save\（タイトル）.jpg
CTabBrowser1.SaveAsWebPage('C:\Save\page.mhtml');     // ページ全体を1ファイルで
CTabBrowser1.SaveToFile('C:\Save\page.html');         // HTML ソース
```

### 9.7 ダウンロードの保存先を決め、終わったら知らせる

```pascal
procedure TForm1.CTabBrowser1DownloadStarting(Sender: TObject; ATabIndex: Integer;
  const AURI: string; var AFileName: string; var ACancel: Boolean);
begin
  AFileName := 'C:\Download\' + ExtractFileName(AFileName);   // 保存先のフォルダーを変える
end;

procedure TForm1.CTabBrowser1DownloadCompleted(Sender: TObject; ATabIndex: Integer;
  const AFileName: string; ASuccess: Boolean);
begin
  if ASuccess then
    StatusBar1.SimpleText := '保存しました：' + AFileName
  else
    StatusBar1.SimpleText := 'ダウンロードできませんでした';
end;
```

### 9.8 右クリックしたタブの URL をコピーする項目を足す

1. TPopupMenu をフォームに置き、項目 `mnuCopyURL`（「URL をコピー」）を作る。
2. TCTabBrowser の `HeaderPopupMenu` と `PagePopupMenu` に、その TPopupMenu を選ぶ。
3. TPopupMenu の `OnPopup` と、項目の `OnClick` に、次の処理を書く。

```pascal
uses
  Clipbrd;

procedure TForm1.PopupMenu1Popup(Sender: TObject);
begin
  mnuCopyURL.Enabled := CTabBrowser1.ContextTabIndex >= 0;
end;

procedure TForm1.mnuCopyURLClick(Sender: TObject);
var
  i: Integer;
begin
  i := CTabBrowser1.ContextTabIndex;
  if i < 0 then Exit;   // タブがもう閉じられている
  Clipboard.AsText := CTabBrowser1.Panels[i].URL;
end;
```

### 9.9 右クリックの「新規作成」と最後のタブを閉じたときに開くページを決める

```pascal
procedure TForm1.CTabBrowser1NewTabRequest(Sender: TObject;
  AReason: TTabNewTabReason; var AURL: string; var AAccept: Boolean);
begin
  AURL := 'https://www.google.com/';   // 開いた後に表示される URL と同じ書き方にする
end;
```

### 9.10 コードで作る

```pascal
uses
  uCTabBrowser;

procedure TForm1.FormCreate(Sender: TObject);
var
  B: TCTabBrowser;
begin
  B := TCTabBrowser.Create(Self);
  B.Parent := Self;
  B.Align := alClient;
  B.OnDocumentComplete := @CTabBrowser1DocumentComplete;   // 9.2 の処理を使う
end;
```

### 9.11 WebView2 の準備ができないときに知らせる

```pascal
procedure TForm1.FormShow(Sender: TObject);
begin
  try
    CTabBrowser1.Add('https://www.lazarus-ide.org/');
  except
    on E: Exception do
      ShowMessage('ブラウザを開けません：' + E.Message);
  end;
end;
```
