# TCSearchBox 設計書

作者: aotan083
日付: 2026-11-17
版: 1.0

---

**動作環境**：Lazarus 5.0 以降（FPC 3.2.2）。Lazarus 4.8 以前は対象外。

## 1. 目的と方針

- Windows エクスプローラーの検索ボックスと同等の部品（`TCSearchBox`）。TCListView・TCTreeView と連動する。
- 探す処理は、別の部品 `TCFindFile`（`TCFindFile_Design.md`。ユニット `uCFindFile.pas`）を使う。この部品は、それを中に 1 つ持つ。
- アドレスバーは別の部品（`TCAddressBar`。`TCAddressBar_Design.md`）。ユニットも別（`uCSearchBox.pas`）。
- 検索は、`Enter` で始める（入力のたびには探さない）。
- ファイル名は、部分一致・ワイルドカード・正規表現で探せる（判定は `TCFindFile`）。
- 結果は TCListView に出す（TCListView に「検索結果の表示」を足す。7 章）。

### 1.1 含めないもの

- ファイルの中身での検索。
- 更新日・サイズ・種類での絞り込み。
- 検索条件の保存。
- Windows の検索のインデックスの利用。
- 入力のたびの検索。
- Linux・macOS（Windows 11 だけ）。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCSearchBox.pas` | cx（実行時） | `TCSearchBox`（入力欄） |
| `uCFindFile.pas` | cx（実行時） | `TCFindFile`（別の設計書） |
| `CListView.pas` | cx（実行時） | `TCListView` に足すもの（7 章） |
| `uCXReg.pas`（`source\design`）・`cnavigation_icon.lrs` | cxdsgn（設計時） | パレット [CX] への登録とアイコン（`TCAddressBar_Design.md` 2 章と同じもの） |
| `uCXLang.pas` | cx（実行時） | 文字列を足す（5 章） |

- `uCSearchBox` の uses：`Classes, SysUtils, Types, Math, Windows, Controls, Graphics, Forms, Menus, StdCtrls, ExtCtrls, LCLType, LCLIntf, LMessages, uCXLang, uCTitleBar（CXSetSymbolFont・CXBlendColor）, uCFindFile, CListView, CTreeView`。
- initialization・finalization は持たない。
- パッケージは、cx と cxdsgn の 2 つのまま。

## 3. 連動の仕組み

```
TCTreeView ── Path ──┐                    ┌─ BeginResults・AddResults・EndResults ─▶ TCListView（検索結果の表示）
                     ├─ TCSearchBox ──────┤
TCListView ── Root ──┘   │               └─ 探す：TCFindFile（別スレッド）
                         └─ 入力欄・オプション
```

| 項目 | 決め方 |
|---|---|
| つなぎ方 | `ListView: TCListView`、`TreeView: TCTreeView`（選ぶだけ。`FreeNotification`）。`ListView` がなくても探せる（`OnSearchResult` で自分で受ける。4.3） |
| 探すフォルダー | `ListView` があり、検索結果の表示中なら、前に探したフォルダー（`ListView.Root`）。そうでなければ `ListView.Root`。なければ `TreeView.Path`。どちらも空（クイックアクセスなどのグループ）なら、探さずにエラー（`sSbErrNoFolder`） |
| 結果 | `ListView.BeginResults(探すフォルダー)` のあと、見つかったものを `ListView.AddResults` で足す |
| 検索をやめる | `×`・`Esc`・文字を空にして `Enter`：`ListView.EndResults`。`ListView` が自分で移った（フォルダーを開く、戻る、ツリーで選ぶ）ときは、`TCAddressBar_Design.md` 3.1 の「フォルダーが変わった知らせ」（`AddFolderLink`）で知り、文字を消して、探すのも止める（4.2）。タイマーは使わない |

## 4. TCSearchBox

`TCSearchBox = class(TCustomControl)`。ユニット `uCSearchBox`。

### 4.1 プロパティ・メソッド・イベント

| 名前 | 型 | 既定値 | 公開 | 中身 |
|---|---|---|---|---|
| `ListView` | `TCListView` | nil | published | 結果を出す一覧（3 章） |
| `TreeView` | `TCTreeView` | nil | published | 探すフォルダーの元（3 章） |
| `Text` | `string` | '' | published | 入力の文字（探す名前）。`TControl.Text` とは別に、この部品が持つ（読み書きは入力欄 `FEdit` の文字） |
| `TextHint` | `string` | '' | published | 空のときに出す薄い文字。空なら、自動で「（フォルダー名）の検索」（`sSbHint`）。フォルダーが分からなければ「検索」（`sSbHintNone`） |
| `MatchMode` | `TCFindMatchMode` | `fmContains` | published | 判定の方法（`TCFindFile_Design.md` 3.5） |
| `CaseSensitive` | `Boolean` | `False` | published | 大文字・小文字を区別するか |
| `IncludeSubfolders` | `Boolean` | `True` | published | サブフォルダーも探すか |
| `SearchHidden` | `Boolean` | `False` | published | 隠し・システムも探すか |
| `MaxResults` | `Integer` | 10000 | published | 結果の最大数 |
| `ShowOptionsMenu` | `Boolean` | `True` | published | 虫眼鏡を押して、オプションのメニューを出せるか |
| `Searching` | `Boolean` | ― | public（読む） | 探している最中か |
| `ResultCount` | `Integer` | ― | public（読む） | 今の検索で見つかった数 |
| `Finder` | `TCFindFile` | ― | public（読む） | 探す部品（この部品が持つ。直接使う必要はない） |
| `Color`・`Font`・`Align`・`Anchors`・`BorderSpacing`・`Constraints`・`Enabled`・`PopupMenu`・`ShowHint`・`TabOrder`・`TabStop`・`Visible`・`Width`・`Height` | | | published | `Color` は `clDefault` なら `clWindow`。`Height` の既定は 32（96dpi。表示スケールで拡大）、`Width` の既定は 260 |

| メソッド | 中身 |
|---|---|
| `procedure Search` | `Enter` と同じ。今の `Text` で、探し始める（4.2） |
| `procedure StopSearch` | 探している最中なら止める（結果は残す） |
| `procedure ClearSearch` | 探すのを止め、`Text` を空にし、`ListView` の検索結果の表示を終える |
| `procedure SetFocus`（`override`） | 入力欄にフォーカスを移して、全部を選ぶ |

| イベント | いつ |
|---|---|
| `OnChange(Sender)` | `Text` が変わったとき（入力・`Text` への書き込み） |
| `OnSearchStart(Sender)` | 探し始めたとき |
| `OnSearchResult(Sender, const APath, AIsDir)` | 1 件見つかるたび。`ListView` に足すのとは別に、自分で受けたいとき用（`ListView` がなくても出す） |
| `OnSearchFinished(Sender, AFound, AReason)` | 探し終わったとき（止めたとき・上限のときを含む） |
| `OnSearchError(Sender, const AMessage)` | 始められなかったとき（正規表現が正しくない、探すフォルダーがない）。未設定なら、枠を赤くして、メッセージをヒント（`Hint`）にする |

### 4.2 処理

**並べ方**

```
[ 入力欄・・・・・・・・・・・・・ ][×][虫眼鏡 / 回る印]
```

| 部分 | 内容 |
|---|---|
| 入力欄 | `TEdit`（枠なし）を中に置く。文字・フォーカス・IME・コピー・貼り付けは、`TEdit` の動きのまま |
| 「×」 | `Text` が空でなく、探していないときだけ出す。押すと `ClearSearch`。幅 `Scale96ToFont(28)` |
| 虫眼鏡 | 探していないとき。`U+E721`。幅 `Scale96ToFont(32)`。`ShowOptionsMenu` が真なら、押すとオプションのメニュー（下） |
| 回る印 | 探している最中。虫眼鏡の場所に、回る円弧を描く（`FSpinTimer` で 100 ミリ秒ごとに角度を進める）。押すと `StopSearch` |

- 枠は、`clBtnShadow` の 1px。入力欄にフォーカスがあれば `clHighlight`（暗すぎるときは、アクセントの青）。エラーのときは `clRed`。

**始める（`Search`・`Enter`）**

1. `Text` の前後の空白を除いた文字を `S` とする。`S` が空なら、`ClearSearch`。
2. 探すフォルダーを決める（3 章）。決まらなければ、`OnSearchError(sSbErrNoFolder)`。
3. `Finder`（`TCFindFile`）に、`Root`・`Pattern := S`・`MatchMode`・`CaseSensitive`・`IncludeSubfolders`・`SearchHidden`・`MaxResults` を入れる。`CheckPattern` が偽なら、`OnSearchError(sSbErrRegex + 文)`。
4. 探している最中なら、`Finder.Stop` して、終わるのを待つ（`WaitFor`）。
5. `ListView` があれば `ListView.BeginResults(探すフォルダー)`。`FPending` を空にする。`ResultCount := 0`。
6. `Finder.Start`。始まれば `Searching := True`、`OnSearchStart`、回る印を動かす、`FFlushTimer`（100 ミリ秒。見つかった結果を、まとめて一覧へ足すため）を動かす。

**見つかったとき・終わったとき**

| 手続き | 処理 |
|---|---|
| `Finder.OnFound` | `ResultCount` を 1 増やす。`FPending` にパスを足す。`OnSearchResult` |
| `FFlushTimer` | `FPending` に入っていれば、`ListView.AddResults(FPending)`、`FPending.Clear` |
| `Finder.OnFinished` | `FPending` を `AddResults` して空にする。`Searching := False`、回る印・`FFlushTimer` を止める。`OnSearchFinished`。`ListView` がなく、結果が 0 件でも、何も出さない |

**キー・マウス**

| 操作 | 動作 |
|---|---|
| `Enter` | `Search` |
| `Esc` | 探している最中なら `StopSearch`。そうでなく、`Text` が空でなければ `ClearSearch`。どちらでもなければ、何もしない |
| `Ctrl+E`・`Ctrl+F`（同じフォームの `ListView`・`TreeView`・この部品にフォーカスがあるとき） | この部品にフォーカスを移す（`SetFocus`）。`Application.AddOnKeyDownHandler` で受ける（`TCAddressBar_Design.md` 5.3 と同じ決まり） |
| 虫眼鏡を押す（探していないとき） | オプションのメニュー（下）。`ShowOptionsMenu` が偽なら何もしない |
| 回る印を押す | `StopSearch` |
| 「×」を押す | `ClearSearch` |

**オプションのメニュー（`TPopupMenu`。出すたびに作る）**

| 項目 | 動作 |
|---|---|
| ○ 部分一致 / ○ ワイルドカード（* ?） / ○ 正規表現 | `MatchMode` を変える（ラジオ） |
| — | 区切り |
| ☑ 大文字と小文字を区別する | `CaseSensitive` を切り替える |
| ☑ サブフォルダーを含める | `IncludeSubfolders` を切り替える |
| ☑ 隠しファイル・システムファイルを含める | `SearchHidden` を切り替える |

- メニューを変えた直後に、`Text` が空でなければ、自動では探さない（`Enter` で探す）。

**フォルダーが変わった知らせ（`FolderLinkChanged`。`ListView`・`TreeView` の `AddFolderLink` で受ける。タイマーなし）**

- 検索結果を `ListView` に出していた（`FResultsActive`）のに、`ListView.ResultsMode` が偽になっていたら（一覧が、ほかの操作で移った。`EndResults` を自分で呼んだときは、結果を出していないので、何もしない）：`Finder.Stop`、`Text := ''`（`OnChange` は出す）、結果の表示のしるしを消す。
- `Text` の薄い文字（`TextHint` が空のとき）は、探すフォルダーの名前が変わったとき（`ListView.Root`・`TreeView.Path`）に、作り直す。

### 4.3 `ListView` がないとき

`ListView` なしでも、探す・`OnSearchResult` で結果を受けることはできる（自分で、結果を見せる）。`BeginResults`・`AddResults` は呼ばない。探すフォルダーは、`TreeView` があればそれ、なければ `Finder.Root`（アプリが、先に `Finder.Root` を設定しておく）。

`ListView`・`TreeView` のフォルダーで探したときは、探し終わったら `Finder.Root` を空に戻す（そのあと `ListView`・`TreeView` を外しても、前のフォルダーを探さないため）。アプリが先に `Finder.Root` に入れたものは、そのまま残す。

### 4.4 作る・壊す

- `Create`：`Finder := TCFindFile.Create(Self)`（`Owner` はこの部品。フォームには保存されない）。イベントをつなぐ。`ControlStyle` に `csOpaque`。実行時は、タイマー（`FSpinTimer`・`FFlushTimer`。探している間だけ有効。フォルダーの見張りのタイマーはない）。`ListView`・`TreeView` が決まったとき（と、変わったとき）に `AddFolderLink`（外すときは `RemoveFolderLink`）。`Application.AddOnKeyDownHandler`。
- `Destroy`：`RemoveOnKeyDownHandler`。`Finder.Stop`（`Finder` の `Destroy` が、終わりを待つ）。`FreeNotification` を外す。
- `Notification`：`ListView`・`TreeView` が壊れたら、nil にする。探している最中に、`ListView` が壊れたら、探すのを止める。

## 5. 文字列（`uCXLang` へ足すもの）

| ID | 日本語 | English |
|---|---|---|
| `sSbHint` | %s の検索 | Search %s |
| `sSbHintNone` | 検索 | Search |
| `sSbMenuContains` | 部分一致(&P) | Contains(&P) |
| `sSbMenuWildcard` | ワイルドカード（* ?）(&W) | Wildcard (* ?)(&W) |
| `sSbMenuRegex` | 正規表現(&R) | Regular expression(&R) |
| `sSbMenuCase` | 大文字と小文字を区別する(&C) | Match case(&C) |
| `sSbMenuSub` | サブフォルダーを含める(&S) | Include subfolders(&S) |
| `sSbMenuHidden` | 隠しファイル・システムファイルを含める(&H) | Include hidden and system files(&H) |
| `sSbClear` | 検索を消す | Clear search |
| `sSbStop` | 検索を中止 | Stop search |
| `sSbErrRegex` | 正規表現が正しくありません：%s | The regular expression is not valid: %s |
| `sSbErrNoFolder` | 検索するフォルダーがありません | There is no folder to search |
| `sSbErrNoRoot` | 検索を始めるフォルダーがありません：%s | The folder to start from was not found: %s |
| `sLvColFolder` | フォルダー | Folder |

これまでの並びの末尾に足す（`TCXStr` と `CXTable` の両方）。`sLvColFolder` は TCListView の「フォルダー」の列の見出し（7 章）。`TCAddressBar_Design.md` 6 章の文字列とあわせて足す。

## 6. 設計時

- `TCSearchBox`：枠と、薄い文字（`TextHint`。自動のときは「検索」）と虫眼鏡を描く。探す処理は、設計時は動かさない。パレット [CX] に出す。
- `TCFindFile` の設計時は、`TCFindFile_Design.md` 5 章。

## 7. TCListView への追加

動作確認済みの `TCListView` に足した。今の動きは、変えていない（検索結果を出さない、履歴を取り出さないときは、まったく同じ動き）。

### 7.1 今と変更後

| 項目 | 今 | 変更後 | 変える理由 | リスク |
|---|---|---|---|---|
| 検索結果の表示 | ない（`Root` のフォルダーの中身だけ） | 「検索結果の表示」（`ResultsMode`）を足す（7.2） | `TCSearchBox` の結果を、一覧に出すため | 15 か所の `GetPathFromItem` を `ItemPath`（新規）に替える。通常の表示では、`GetPathFromItem` と同じ値を返すので、動きは変わらない |
| 履歴の取り出し | `CanGoBack`・`GoBack`・`GoForward` だけ。一覧は見えない | `GetHistory`・`GoToHistory` を足す（7.3） | `TCAddressBar` の「最近の場所」のため | 既存の履歴（`FHistory`・`FHistIndex`）を読むだけ（足すのみ） |
| 項目の並べ替え・列 | 4 列（名前・サイズ・種類・更新日時） | 検索結果の表示のときだけ、5 列目「フォルダー」を足す | 場所を見せるため | 通常の表示では、5 列目はない（列の幅の自動調整・保存の動きは、4 列のまま） |
| 公開するもの | ― | `ResultsMode`・`BeginResults`・`AddResult`・`AddResults`・`EndResults`・`GetHistory`・`GoToHistory` | 同上 | 足すだけ |

### 7.2 検索結果の表示

| メソッド・プロパティ | 中身 |
|---|---|
| `property ResultsMode: Boolean`（読む。実行時だけ） | 検索結果を出しているか |
| `procedure BeginResults(const AFolder: string)` | 検索結果の表示にする。⓪表示中でないときは、先に今の状態を検出しておく（直前に `Root` を変えていて、まだ検出されていないと、あとで「外から `Root` が変わった」と見なされて、結果の表示が終わってしまうため）。①すでに表示中なら、中身だけ消す。②フォルダーの変更の監視を止める（`UnregisterFolderNotify`、`FNotifyTimer` を止める）。③項目を全部消す（`Items.Clear`）。④「フォルダー」の列（5 列目。見出しは `CXT(sLvColFolder)`）を足す。⑤`FResultsMode := True`、`FResultFolder := AFolder`（`Root` は変えない）。⑥並べ替えは、「名前」の昇順にする（`SortBy(0, True)` と同じ。ただし、再読み込みはしない） |
| `procedure AddResult(const APath: string)` | 1 件足す（`AddResults` を 1 件で呼ぶのと同じ） |
| `procedure AddResults(AList: TStrings)` | 検索結果の表示のときだけ。`BeginUpdate` のあと、各パスの項目を足し、`EndUpdate`。ない・読めないパスは飛ばす。項目の作り方は 7.2.1 |
| `procedure EndResults` | 検索結果の表示を終える。①5 列目を消す。②`FResultsMode := False`。③項目を全部消す。④`FResultFolder` を `Root` として、フォルダーの中身を作り直す（今の `NavigateTo` が使う読み込みと同じ。監視も再開）。通常の表示のときは何もしない |

**7.2.1 検索結果の項目**

| 部分 | 内容 |
|---|---|
| `Caption` | ファイル名（フォルダー名）。`ExtractFileName`（長さのないパスは、そのまま） |
| `Data` | `TCResultInfo`（新規のクラス。`FullPath`・`IsDir`）。`TCListView` が持つ一覧（`FResultInfos`）に入れ、項目を消すときに、一緒に壊す |
| サイズ | ファイルなら、基底の `GetCellText`（通常の表示と同じ書き方）。フォルダーは空 |
| 種類 | フォルダーは `CXT(sLvFolderType)`。ファイルは拡張子（通常の表示と同じ） |
| 更新日時 | 今の列と同じ（`YYYY/MM/DD HH:NN`） |
| フォルダー | `ExtractFilePath(FullPath)` の末尾の `\` を除いたもの |
| アイコン | 今の一覧と同じ方法（システムのアイコン）で付ける |

**7.2.2 検索結果の表示のときの動き**

| 操作 | 動き |
|---|---|
| 項目のパス | `ItemPath(Item)`（新規。`FResultsMode` なら `Data` の `FullPath`、そうでなければ `GetPathFromItem(Item)`）。今の `GetPathFromItem` の呼び出し 15 か所を、すべてこれに替える |
| ダブルクリック・`Enter` | フォルダーなら `NavigateTo`（検索結果の表示は終わる）。ファイルなら、今と同じく、開く |
| 戻る・進む・上へ・`BackSpace`・`NavigateTo` | まず `EndResults` してから、今の動き（`NavigateUp` は、`FResultFolder` の親） |
| 右クリックメニュー | 項目の上：今と同じ（シェルのメニュー。パスは `ItemPath`）。空白：「表示」「並べ替え」だけ。「新規作成」「貼り付け」は出さない（`Root` が探したフォルダーなので、置き場所が不明のため） |
| 削除・名前の変更・コピー・切り取り | 今と同じ（パスは `ItemPath`）。削除・名前の変更が成功したら、その項目を一覧から外す（フォルダーの再読み込みはしない） |
| 貼り付け・ドロップ（受ける側） | しない（受け取る場所がない） |
| ドラッグして出す（送る側） | 今と同じ（パスは `ItemPath`） |
| 並べ替え | 名前・サイズ・種類・更新日時・フォルダー（列 4）。フォルダーかどうかは `TCResultInfo` から、そのほかは各列の文字から比べる（ディスクに問い合わせない）。フォルダーが先、という並べ方は、通常の表示と同じ |
| 変更の監視 | しない（`BeginResults` で止める） |
| `Root`・`Path`（ツリーとの連動） | `Root` は変えない。ツリーなどで、外から `Root` が変わったときは、アイドルのときの検出（`CheckStateChanged`）で、結果の表示をやめる（列・項目情報を片づける。中身は、基底が読み直し済み） |
| 空白の右クリックの「表示」「並べ替え」 | 専用のメニュー（`TrackPopupMenu`）。通常の表示のメニューとは別に出す |
| 読み直し（F5・`DoAsyncRefresh`） | しない（結果を消さないため） |
| `Ctrl+Shift+N`（新規フォルダー） | しない |

### 7.3 履歴の取り出し

| メソッド | 中身 |
|---|---|
| `function GetHistory(AList: TStrings): Integer` | 履歴の全部を、訪れた新しい順（いちばん新しいものが先頭）に `AList` へ入れる（フルパス。進む側の履歴も含む）。今のフォルダーの、`AList` の中の番号を返す（履歴がなければ -1）。戻った後は、今のフォルダーより前（番号が小さい側）に、進める履歴が並ぶ |
| `function GoToHistory(AIndex: Integer; const APath: string): Boolean` | `GetHistory` の `AList` の `AIndex` 番目のフォルダーへ移る。今の番号との差の回数だけ、`GoBack`（`AIndex` が大きいとき）または `GoForward`（小さいとき）を続けて呼ぶのと同じ。途中のフォルダーが消えていれば、履歴から外して飛ばし、移れた所まで進む。`APath` は確認用で、`AList[AIndex]` と違えば、何もせずに `False`。目的のフォルダーに移れたら `True`。`AIndex` が範囲外・今と同じなら `False`（何もしない） |

## 8. 決めていること

| 項目 | 決めたこと |
|---|---|
| 探す方法 | 自前の再帰（`FindFirstFileW`）だけ。インデックスは使わない |
| 検索の始め方 | `Enter` だけ。入力のたびには探さない |
| 名前の判定 | 部分一致・ワイルドカード・正規表現。ファイル名（フォルダー名）だけを見る |
| 正規表現 | FPC の `RegExpr`。UTF-8 のまま。`.` はバイト単位（日本語の文字数の指定は不可） |
| スレッド | 探す処理は別スレッド。結果は、まとめて（50 件か 100 ミリ秒）メインスレッドへ。一覧への追加は、100 ミリ秒ごとにまとめて |
| 無限に回らないように | リパースポイントの中には入らない。`MaxResults`（既定 10000） |
| 読めないフォルダー | 静かに飛ばす |
| 検索結果の置き場 | TCListView の「検索結果の表示」（7 章）。`Root` は変えない |
| 結果から戻る | `×`・`Esc`・空にして `Enter`、または一覧を移る（戻る・ダブルクリック・ツリーなど） |
| 設定のオプション | 虫眼鏡のメニュー（`MatchMode`・`CaseSensitive`・`IncludeSubfolders`・`SearchHidden`）。プロパティでも設定できる |
| 言語 | `uCXLang` の `CXT` |
| 設計時 | 見本を描くだけ。探す処理は動かさない |

## 9. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| `Enter` を押しても探さない | 探すフォルダーが決まっているか（3 章）。`OnSearchError`。正規表現の式（`CheckPattern`） |
| 結果が 1 件も出ない | `MatchMode`（部分一致か）。`SearchHidden`。`Root` の読み取り権 |
| 結果が遅れて出る・固まる | `cFindFlushCount`・`cFindFlushMs`。`ListView.AddResults` の `BeginUpdate` |
| 日本語の正規表現が合わない | `.` がバイト単位であること（`TCFindFile_Design.md` 3.5） |
| 探しているのに止まらない | `StopFlag` の確認（`TCFindFile_Design.md` 4.1 の 6）。`Stop` の後の `OnFinished` |
| 検索結果の表示のまま、フォルダーが変わらない | `ListView.ResultsMode`。`EndResults`・`NavigateTo` の順（7.2.2） |
| 結果の項目の、開く・削除・コピーが、違うフォルダーを指す | `ItemPath`。`GetPathFromItem` の替え忘れ（7.1） |
| 画面を閉じても、スレッドが残る | `TCFindFile_Design.md` 6 章 |

## 10. この版の変更（新しく作る）

新しい部品 TCSearchBox・TCFindFile を作る。既存の部品の動きは、変えない（`CListView.pas` に足すものだけ。7 章）。

| ファイル | 変更 |
|---|---|
| `source/uCSearchBox.pas` | 新規 |
| `source/CListView.pas` | 7 章の追加。あわせて `AddFolderLink`・`RemoveFolderLink`（`TCAddressBar_Design.md` 3.1）。TCTreeView にも同じ受け口 |
| `source/design/uCXReg.pas`・`source/res/cnavigation_icon.lrs` | 登録とアイコン（`TCAddressBar_Design.md` 10 章と同じもの。TCFindFile の登録は `TCFindFile_Design.md`） |
| `source/uCXLang.pas` | 文字列を足す（5 章） |
| `packages/cx.lpk`・`cx.pas`・`cxdsgn.lpk` | `uCSearchBox` を足す |
| `docs/TCSearchBox_Usage.md`・`TCSearchBox_Design.md`、`docs/en` の同名 | コードができてから、取説と英語版を作る |
