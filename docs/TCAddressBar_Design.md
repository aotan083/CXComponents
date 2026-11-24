# TCAddressBar 設計書

作者: aotan083
日付: 2026-11-17
版: 1.0

---

**動作環境**：Lazarus 5.0 以降（FPC 3.2.2）。Lazarus 4.8 以前は対象外。

## 1. 目的と方針

- Windows エクスプローラーのアドレスバー（戻る・進む・上へ・パンくず・パスの入力・履歴・更新）と同等の部品。TCListView・TCTreeView と連動する。
- 検索ボックスは別の部品（`TCSearchBox`。`TCSearchBox_Design.md`）。ユニットも別（`uCAddressBar.pas`）。
- LCL で描く部品（WebView2 は使わない）。`TCustomControl` を継ぐ。
- フォルダーを移る処理は、すべて TCListView の `NavigateTo` に任せる（履歴・変更の監視・ツリーとの連動は、TCListView が持っている）。この部品は、表示と入力だけを受け持つ。

### 1.1 含めないもの

- パスの入力補完（のちに）。
- お気に入りへの追加、パスのドラッグ＆ドロップ。
- ファイルのパスを入力して開くこと（入力できるのはフォルダーだけ）。
- 戻る・進む・履歴を、TCListView なしで使うこと（TCTreeView だけのときは、戻る・進む・履歴は使えない。上へ・パンくず・入力は使える）。
- Linux・macOS（Windows 11 だけ）。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCAddressBar.pas` | cx（実行時） | `TCAddressBar`、パスを分ける関数 `CABSplitPath`、入力の文字を整える関数 `CABNormalizeInput` |
| `uCXReg.pas`（`source\design`） | cxdsgn（設計時） | パレット [CX] への登録（`TCAddressBar`、`TCSearchBox`、`TCFindFile`） |
| `cnavigation_icon.lrs`（`source\res`） | cxdsgn（設計時） | アイコン（`TCAddressBar`・`TCSearchBox`・`TCFindFile` の 3 つ。それぞれ `_150`・`_200` も） |
| `uCXLang.pas` | cx（実行時） | 文字列を足す（6 章） |
| `uCListView`（`CListView.pas`） | cx（実行時） | `TCListView` に足すもの（`TCSearchBox_Design.md` 7 章。履歴の取り出し） |

- `uCAddressBar` の uses：`Classes, SysUtils, Types, Math, Windows, Controls, Graphics, Forms, Menus, StdCtrls, ExtCtrls, LCLType, LCLIntf, LMessages, uCXLang, uCTitleBar（CXSetSymbolFont・CXBlendColor）, CListView, CTreeView`。
- initialization・finalization は持たない。
- パッケージは、cx と cxdsgn の 2 つのまま。

## 3. 連動の仕組み

```
TCTreeView ──── Path ────┐
                          ├─ TCAddressBar ── 表示（パンくず）・入力・ボタン
TCListView ── Root・履歴 ─┘
```

| 項目 | 決め方 |
|---|---|
| つなぎ方 | `ListView: TCListView`、`TreeView: TCTreeView`（オブジェクトインスペクタで選ぶ。`FreeNotification`）。どちらか 1 つ、または両方 |
| 今のフォルダー（`Path`） | `ListView` があれば `ListView.Root`、なければ `TreeView.Path`、どちらもなければ、この部品が持つ `FPath` |
| 変わったことの知り方 | タイマーは使わない。フォルダーが変わったときに、TCListView・TCTreeView から知らせてもらう（3.1）。知らせが来たら、今のフォルダーと表示中のフォルダー（`FShownPath`）を比べ、変わっていれば、パンくずを作り直して描き直す |
| 移る | `ListView` があれば `ListView.NavigateTo(パス)`。`TreeView` があり `SyncTree = True` なら、続けて `TreeView.Path := パス`（ツリーも同じフォルダーにする）。`ListView` がなく `TreeView` だけなら、`TreeView.Path := パス` |
| 戻る・進む・上へ | `ListView.GoBack`・`GoForward`・`NavigateUp`。使えるかは `CanGoBack`・`CanGoForward`。上へは、親フォルダーがあるか（ドライブのルートでは使えない）で決める |
| 更新 | `ListView.UpdateView`（TShellListView の手続き）。`ListView` がなければ `TreeView.Refresh` |
| 履歴 | `ListView` の履歴（`MaxHistory`）を、`GetHistory`・`GoToHistory`（`TCSearchBox_Design.md` 7 章）で読む・移る |
| 検索結果の表示中 | `ListView.ResultsMode` が真の間は、パンくずは、検索したフォルダー（`ListView.Root`）を出す。更新は、検索結果を作り直さず、何もしない |

### 3.1 TCListView・TCTreeView への追加

動作確認済みの 2 つの部品に、「フォルダーが変わった知らせ」の受け口を足した（足しただけで、今の動きは変えていない）。ユーザーの `OnFolderChanged`・`OnChange` は上書きしない。

| 項目 | 今 | 変更後 | 変える理由 | リスク |
|---|---|---|---|---|
| TCListView | `OnFolderChanged`（利用者のイベント）だけ | `AddFolderLink(AEvent: TNotifyEvent)`・`RemoveFolderLink(AEvent)` を足す。`NotifyFolderChanged`（今、`OnFolderChanged` を呼ぶ 1 か所）で、`OnFolderChanged` のあとに、登録された受け手を順に呼ぶ | 部品どうしが、利用者のイベントを奪わずに連動するため（タイマーでの見張りをやめるため） | 足すだけ。登録がなければ、今と同じ動き |
| TCTreeView | `OnChange`（TTreeView の標準）だけ | 同じ `AddFolderLink`・`RemoveFolderLink` を足す。`DoSelectionChanged` の本体を `DoSelectionChangedCore` に移し、`DoSelectionChanged` で、それを呼んだあとに、受け手を呼ぶ（選択が変わったとき） | 同上 | 同上 |

- 受け手は、部品が壊れるとき（`Destroy`）に、必ず `RemoveFolderLink` する（`FreeNotification` と合わせる）。
- 通常のフォルダーが変わったとき（`NavigateTo`・戻る・進む・ツリーでの選択・ダブルクリック）だけ知らせる。フォルダーの中身が変わっただけ（ファイルの追加・削除）では知らせない。
- `TCSearchBox` の「検索結果の表示が終わった知らせ」も、同じ受け口を使う（`EndResults` から `NotifyFolderChanged`）。これで、`TCSearchBox_Design.md` 4.2 のタイマーも不要になる。

## 4. TCAddressBar

`TCAddressBar = class(TCustomControl)`。ユニット `uCAddressBar`。

### 4.1 型と定数

```pascal
type
  TCABNavigatingEvent = procedure(Sender: TObject; const APath: string; var Allow: Boolean) of object;
  TCABNavigatedEvent = procedure(Sender: TObject; const APath: string) of object;
  TCABErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;
```

| 定数 | 値 | 中身 |
|---|---|---|
| `cMaxPopupItems` | 300 | 「>」の一覧に出すフォルダーの最大数 |
| `cHeight96` | 32 | 既定の高さ（96dpi） |

### 4.2 プロパティ

| 名前 | 型 | 既定値 | 公開 | 中身 |
|---|---|---|---|---|
| `ListView` | `TCListView` | nil | published | 連動する一覧（3 章） |
| `TreeView` | `TCTreeView` | nil | published | 連動するツリー（3 章） |
| `SyncTree` | `Boolean` | `True` | published | 移るとき、`TreeView` も同じフォルダーにするか |
| `ShowNavButtons` | `Boolean` | `True` | published | 戻る・進む・上へのボタンを出すか |
| `ShowHistoryButton` | `Boolean` | `True` | published | 最近の場所（履歴）の「v」ボタンを出すか |
| `ShowRefreshButton` | `Boolean` | `True` | published | 更新ボタンを出すか |
| `Path` | `string` | '' | public（読み・書き） | 今のフォルダー。書くと、そのフォルダーへ移る（なければ何もしない）。実行時だけ |
| `Editing` | `Boolean` | ― | public（読む） | 入力モードか |
| `Color` | `TColor` | `clDefault` | published | 入力の枠の中の背景色。`clDefault` なら `clWindow` |
| `Font` | `TFont` | 親と同じ | published | 文字。`ParentFont` も |
| `Align` | `TAlign` | `alTop` | published | 配置 |
| `Height` | `Integer` | 32 | published | 高さ（`cHeight96` を表示スケールで拡大） |
| `Anchors`・`BorderSpacing`・`Constraints`・`Enabled`・`PopupMenu`・`ShowHint`・`TabOrder`・`TabStop`・`Visible` | | | published | LCL 標準。`TabStop` の既定値は `True` |

### 4.3 メソッド

| メソッド | 中身 |
|---|---|
| `function NavigateTo(const APath: string): Boolean` | 3 章の「移る」。`OnNavigating` で断られたり、フォルダーがなければ `False`。移ったら `OnNavigated` |
| `procedure BeginEdit` | 入力モードにする（5.4） |
| `procedure EndEdit(ACancel: Boolean)` | 入力モードを終える。`ACancel = False` なら、入力した文字で移ろうとする |
| `procedure Refresh` | 3 章の「更新」 |

### 4.4 イベント

| イベント | いつ |
|---|---|
| `OnNavigating(Sender, APath, var Allow)` | この部品の操作（パンくず・入力・ボタン・一覧）で移る前。`Allow := False` で、やめる |
| `OnNavigated(Sender, APath)` | この部品の操作で移った後。`ListView` の操作（ダブルクリックなど）で移ったときは出ない |
| `OnError(Sender, AMessage)` | 入力したパスが見つからない・フォルダーでないとき。未設定なら、入力欄の下に、メッセージを赤い文字で出す（次の操作で消える） |

### 4.5 宣言（private・protected）

```pascal
TCAddressBar = class(TCustomControl)
private
  FListView: TCListView;
  FTreeView: TCTreeView;
  FSyncTree, FShowNav, FShowHistory, FShowRefresh: Boolean;
  FPath: string;                       { ListView・TreeView がないときの今のフォルダー }
  FShownPath: string;                  { 表示しているパンくずのフォルダー }
  FSegs: array of TCABSeg;             { パンくずの部分（5.2） }
  FFirstVisible: Integer;              { 先頭に出す部分（それより前は「…」にまとめる） }
  FHot: TCABHit;                       { マウスが乗っている所（5.3） }
  FDown: TCABHit;                      { 押している所 }
  FEdit: TEdit;                        { 入力モードの入力欄。入力モードのときだけ作る }
  procedure FolderLinkChanged(Sender: TObject);   { ListView・TreeView からの、フォルダーが変わった知らせ（3.1） }
  FErrorText: string;
  FKeyHandlerAdded: Boolean;
  procedure PlaceEdit;                 { 入力欄を、パンくずの場所に置く（高さは、入力欄の自然な高さ。上下は中央） }
  ...
protected
  procedure Paint; override;
  procedure Resize; override;
  procedure MouseDown / MouseMove / MouseUp / MouseLeave; override;
  procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  procedure DoEnter; override;
  procedure DoExit; override;
  procedure CMEnabledChanged, CMFontChanged, CMColorChanged; message ...
  procedure WMGetDlgCode; message LM_GETDLGCODE;       { 矢印キー・Enter を、この部品が受ける }
  procedure Notification(AComponent: TComponent; Operation: TOperation); override;
public
  constructor Create(TheOwner: TComponent); override;
  destructor Destroy; override;
  ...（4.3 のメソッド）
end;
```

## 5. 処理

### 5.1 並べ方（左から右）

```
[←][→][↑][更新]  [アイコン][パンくず・・・・・・・・・・・][v]
   ボタン          入力の枠（clWindow・1px の clBtnShadow の枠）
```

| 部分 | 幅 | 中身 |
|---|---|---|
| 戻る・進む・上へ・更新 | 各 `Scale96ToFont(32)`（正方形に近い） | 文字は Segoe MDL2 Assets（`CXSetSymbolFont`）。戻る `U+E72B`、進む `U+E72A`、上へ `U+E74A`、更新 `U+E72C` |
| 入力の枠 | 残り全部 | 左に、今のフォルダーのアイコン（`SHGetFileInfo` の小アイコン）、その右にパンくず。枠の右端に「v」（`U+E70D`。最近の場所）を、`Scale96ToFont(32)` の幅で出す |
| 入力モード | 入力の枠の中 | パンくずの代わりに、`FEdit`（枠なし）を出す |

- 各ボタンは、`ShowNavButtons`・`ShowHistoryButton`・`ShowRefreshButton` が偽なら出さない（その分、枠が広がる）。
- 高さは、`Height` から、ボタンと枠が上下の中央に来るように置く（上下に `Scale96ToFont(3)` の余白）。

### 5.2 パンくず

**パスを分ける（`CABSplitPath(APath, AList)`。ユニットの関数）**

`AList` に、先頭から順に、各部分のフルパスを入れる（`Objects` は使わない）。

| 入力 | 結果 |
|---|---|
| '' | `''`（「PC」の 1 つだけ。パスは空） |
| `C:\` | `''`、`C:\` |
| `C:\app\laz` | `''`、`C:\`、`C:\app`、`C:\app\laz` |
| `\\server\share\x` | `''`、`\\server`、`\\server\share`、`\\server\share\x` |
| 末尾の `\` | 無視する（`C:\app\` は `C:\app` と同じ。ドライブのルート `C:\` だけは残す） |

**表示の名前**

| 部分 | 名前 |
|---|---|
| `''` | 「PC」（`CXT(sAddrPC)`） |
| ドライブのルート（`C:\`） | `SHGetFileInfoW(SHGFI_DISPLAYNAME)` の名前（「ローカル ディスク (C:)」など）。取れなければ `C:` |
| `\\server` | `\\server` |
| ほかのフォルダー | `ExtractFileName` |

**幅に収める**

1. 各部分の幅 ＝ 名前の幅 ＋ 左右の余白（`Scale96ToFont(8)`）。部分と部分の間に、「>」（`U+E76C`。幅 `Scale96ToFont(20)`）を置く。最後の部分の後ろにも「>」を置く（その下のフォルダーの一覧を出すため）。
2. 全体が、枠の中の幅（アイコン・「v」・更新を除く）に収まるなら、すべて出す。
3. 収まらなければ、後ろ（右）から数えて収まる部分だけを出し、前の部分は「…」（幅 `Scale96ToFont(28)`）の 1 つにまとめる（`FFirstVisible`）。
4. 最後の部分は、収まらなくても、必ず出す（入りきらなければ、右を切る）。

### 5.3 マウス・キー（パンくずのとき）

`FHot`・`FDown` は、押す・乗せることができる場所の種類と番号（`TCABHit`：なし／戻る／進む／上へ／部分の名前（番号）／部分の「>」（番号）／「…」／アイコン／「v」／更新／枠の空き）。

| 操作 | 動作 |
|---|---|
| 乗せる | その場所を、少し明るく（`CXBlendColor(背景, clWindowText, 12)`）塗る。押している間は 20% |
| 戻る・進む・上へ | 離したとき、同じ場所なら、3 章のとおり移る。使えないときは灰色（`clGrayText`）で、押せない |
| 部分の名前 | 離したとき、同じ場所なら、その部分のフォルダーへ移る。「PC」（パスが空）は、移らずに、ドライブの一覧（下の「>」と同じ形）を出す |
| 部分の「>」 | 離したとき、そのフォルダーの下のフォルダーの一覧（`TPopupMenu`）を、その場所の下に出す。次の部分のフォルダーには、印（`Checked`、太字）を付ける。選んだフォルダーへ移る |
| 「…」 | 隠れている前の部分の一覧を出す。選んだ部分へ移る |
| 「v」 | 履歴の一覧（`GetHistory`。新しい順。`GetHistory` が返した今の位置に印）を出す。選ぶと `GoToHistory` |
| 更新 | 3 章の「更新」 |
| アイコン・枠の空き | 入力モードにする |
| 右クリック | 何もしない（`PopupMenu` があればそれを出す） |

**「>」の一覧**

| 項目 | 内容 |
|---|---|
| 中身 | そのフォルダーの下の、フォルダーだけ。隠し・システム属性のものは出さない。名前で並べる（`StrCmpLogicalW`）。最大 `cMaxPopupItems` 個。それを超えたら、最後に「…」（選べない）を足す |
| 「PC」の下 | 固定ドライブ・ネットワークドライブ・リムーバブルドライブ（`GetLogicalDrives`）。名前は 5.2 の「ドライブのルート」と同じ |
| 読めないフォルダー | 空の一覧（メニューを出さない） |
| 取り方 | `FindFirstFileW`（TCListView と同じ長いパス対応）で、その場で読む。一覧は、出すたびに作る（覚えない） |

**キー（この部品にフォーカスがあるとき）**

| キー | 動作 |
|---|---|
| `Enter`・`F4`・`Ctrl+L`・`Alt+D` | 入力モードにする |
| `Alt+←`・`Alt+→`・`Alt+↑` | 戻る・進む・上へ |
| `F5` | 更新 |
| `Tab` | 次の部品へ |

**入力モードに入るキーを、一覧・ツリーからも受ける**

- 実行時、`Application.AddOnKeyDownHandler` で受ける（TCSideBar と同じ。フォームの `KeyPreview`・フォーカスのある部品・メニューが使わなかったキーだけが届く）。`Ctrl+L`・`Alt+D` を押したとき、フォーカスが、同じフォームの、この部品か `ListView`・`TreeView` の上にあれば、`BeginEdit`（`Key := 0`）。
- この部品が、`Enabled` で、表示されているときだけ。

### 5.4 入力モード

1. `BeginEdit`：`FEdit := TEdit.Create`（`Parent := Self`、`BorderStyle := bsNone`）。位置は、パンくずの場所（アイコンの右から「v」の左まで）。文字は今のフォルダーのフルパス（''・「PC」のときは空）。全部を選び、フォーカスを移す。`FErrorText := ''`。
2. `Enter`：`CABNormalizeInput` で整えて、`NavigateTo`。移れたら入力モードを終える。見つからなければ、`OnError`（4.4）。入力モードは続ける。
3. `Esc`：入力モードを終える（移らない）。
4. 入力欄がフォーカスを失った（クリック・別のウィンドウ）：入力モードを終える（移らない）。ただし、`OnError` のメッセージを出しているときは、メッセージを消す。
5. 入力モードを終える：`FEdit` を壊し、パンくずを描き直し、フォーカスをこの部品に戻す。
6. 入力モードの間は、知らせ（`FolderLinkChanged`）が来ても、パンくずを作り直さない（入力欄を壊さないため）。

**入力の文字を整える（`CABNormalizeInput(const S: string; out APath: string): Boolean`）**

| 順 | 処理 |
|---|---|
| 1 | 前後の空白を除く。空なら `False` |
| 2 | 前後の `"` を除く |
| 3 | `ExpandEnvironmentStringsW` で、`%USERPROFILE%` などを置き換える |
| 4 | `/` を `\` にする |
| 5 | `C:` だけなら `C:\` にする。ドライブのルート以外の、末尾の `\` を除く |
| 6 | `DirectoryExists`（長いパス対応）が真なら、`APath` にして `True`。偽なら `False` |

### 5.5 描画（`Paint`）

1. 全体を、親の背景（`clBtnFace`）で塗る。
2. ナビボタン（5.1）を描く。使えない（`Enabled` が偽・履歴がない・ルートに上がれない）ものは `clGrayText`。
3. 入力の枠を、`Color`（`clDefault` なら `clWindow`）で塗り、`clBtnShadow` の 1px の枠。入力モードでは、枠を `clHighlight`（暗すぎるときは `CXSplitLineColor` と同じ考えで、アクセントの青）にする。
4. アイコン、パンくず（名前・「>」・「…」）、「v」、更新を描く。乗せている・押している場所は、5.3 の色で塗る。
5. `FErrorText` があれば、パンくずのとき、枠の中の右寄せで、赤（`clRed`）の文字で出す。
6. 無効（`Enabled = False`）のときは、文字を `clGrayText`、操作は受けない。

### 5.6 作る・壊す

- `Create`：`ControlStyle` に `csOpaque` を付ける。`Align := alTop`、`Height := Scale96ToFont(cHeight96)`、`TabStop := True`、`SyncTree := True` など、4.2 の既定値を入れる。実行時で、`Application` があれば、`AddOnKeyDownHandler`。`ListView`・`TreeView` が決まったとき（と、変わったとき）に、`AddFolderLink(@FolderLinkChanged)`（外すときは `RemoveFolderLink`）。
- `Destroy`：`RemoveOnKeyDownHandler`。`ListView`・`TreeView` の `FreeNotification` を外す。
- `Notification`：`ListView`・`TreeView` が壊れたら、nil にして描き直す。
- 高さの既定値は、`Create` で、表示の倍率に合わせて決める（`CXScale96`）。

## 6. 文字列（`uCXLang` へ足すもの）

| ID | 日本語 | English |
|---|---|---|
| `sAddrBack` | 戻る | Back |
| `sAddrForward` | 進む | Forward |
| `sAddrUp` | 上へ | Up |
| `sAddrRefresh` | 最新の情報に更新 | Refresh |
| `sAddrRecent` | 最近の場所 | Recent locations |
| `sAddrPC` | PC | PC |
| `sAddrErrNotFound` | フォルダーが見つかりません：%s | The folder was not found: %s |

これまでの並びの末尾に足す（`TCXStr` と `CXTable` の両方）。ヒント（戻る・進む・上へ・更新・最近の場所）は、各ボタンの上に出す（`ShowHint` が真のとき）。

## 7. 設計時

- 部品を置くと、枠と、見本のパンくず（`PC > C: > app`。ボタンは灰色）を出す。実際のフォルダーの読み込みは、設計時は行わない。
- `Align = alTop` で、フォームの上に置かれる。
- パレット [CX] に出す（アイコンは `cnavigation_icon.lrs`）。

## 8. 決めていること

| 項目 | 決めたこと |
|---|---|
| 移る処理 | すべて `ListView.NavigateTo`（履歴・監視・ツリー連動を、TCListView に任せる）。`ListView` がなければ `TreeView.Path` |
| 今のフォルダーの知り方 | タイマーなし。TCListView・TCTreeView の「フォルダーが変わった知らせ」（3.1）で更新する（既存のイベントは上書きしない） |
| 入力できるもの | フォルダーだけ。ファイルのパスは受けない |
| 補完 | 作らない（のちに） |
| 戻る・進む・履歴 | `ListView` があるときだけ使える（履歴を持っているのが TCListView だから） |
| 検索結果の表示中 | パンくずは、検索したフォルダー。更新は何もしない |
| アイコンの文字 | Segoe MDL2 Assets（TCTitleBar・TCPageControl と同じ `CXSetSymbolFont`） |
| 色 | `clBtnFace`・`clWindow`・`clBtnShadow`・`clGrayText`・`CXBlendColor`。ダーク・ライトには、システム色に任せる（MetaDarkStyle など） |
| 仮想フォルダー | 「PC」だけ。クイックアクセス・OneDrive・ネットワークのグループは、パスがないので、パンくずに出さない |
| 言語 | `uCXLang` の `CXT`（日本語・English） |
| 設計時 | 見本を描くだけ。読み込みは動かさない |

## 9. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| パンくずが、移った後も古いまま | 知らせの登録（3.1）。`FShownPath` と今のフォルダーの比べ方、入力モード中は作り直さない（5.4 の 6） |
| 「>」の一覧が出ない | 読めないフォルダー（5.3）。`FindFirstFileW` の長いパス |
| 戻る・進むが灰色のまま | `ListView` が選ばれているか。`CanGoBack`・`CanGoForward` |
| `Ctrl+L` が効かない | `AddOnKeyDownHandler`（5.3）。メニュー・ActionList が同じキーを使っていないか |
| 入力して `Enter` しても移らない | `CABNormalizeInput`（5.4）。存在しないフォルダー・環境変数 |
| 一覧を移っても、ツリーが変わらない | `SyncTree`。アドレスバーからの移動だけが対象（一覧での移動は、アドレスバーでは変えない） |
| 検索結果の表示中に、パンくずが変になる | 3 章の「検索結果の表示中」 |

## 10. この版の変更（1.0。新しく作る）

新しい部品 TCAddressBar を作る。既存の部品の動きは、変えない（ただし、`CListView.pas` に足すものがある。`TCSearchBox_Design.md` 7 章）。

| ファイル | 変更 |
|---|---|
| `source/uCAddressBar.pas` | 新規 |
| `source/CTreeView.pas` | `AddFolderLink`・`RemoveFolderLink`（3.1） |
| `source/CListView.pas` | 足すもの：`AddFolderLink`・`RemoveFolderLink`（3.1）、`GetHistory`・`GoToHistory`（`TCSearchBox_Design.md` 7.3）、検索結果の表示（`TCSearchBox_Design.md` 7 章） |
| `source/design/uCXReg.pas` | 3 つの部品を登録し、`cnavigation_icon.lrs` を読み込む |
| `source/res/cnavigation_icon.lrs` | 新規 |
| `source/uCXLang.pas` | 文字列を足す（6 章。`TCSearchBox_Design.md` の分も） |
| `packages/cx.lpk`・`cx.pas`・`cxdsgn.lpk` | `uCAddressBar`・`uCSearchBox` と、アイコンを足す |
| `docs/TCAddressBar_Usage.md`・`TCAddressBar_Design.md`、`docs/en` の同名 | コードができてから、取説と英語版を作る |
