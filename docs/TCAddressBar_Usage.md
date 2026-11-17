# TCAddressBar 取扱説明書

作者: aotan083
日付: 2026-11-17
版: 1.0

---

## 1. 概要とクラス

Windows エクスプローラーのアドレスバーと同じように使える部品です。TCListView・TCTreeView とつなぐだけで動きます。

```
[←][→][↑][更新]  [アイコン] PC > ローカル ディスク (C:) > app >            [v]
   ボタン          パンくず（クリックで移動。「>」でその下のフォルダーの一覧）  履歴
```

- パンくず：名前をクリックすると、そのフォルダーへ移る。名前の右の「>」をクリックすると、そのフォルダーの下のフォルダーの一覧が出て、選ぶと移る。
- パンくずの空いている所（またはアイコン）をクリックすると、パスを直接入力できる（入力モード）。`Enter` で移る。
- 戻る・進む・上へ・更新のボタン。右端の「v」で、最近の場所（履歴）の一覧が出る。
- 幅が足りないときは、前の部分が「...」にまとまる。「...」を押すと、隠れている部分の一覧が出る。
- 今のフォルダーが変わったときは、自動でパンくずが変わる（一覧・ツリーでフォルダーを移ったときも）。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCAddressBar` | `uCAddressBar` | cx | `TCustomControl` | エクスプローラーのアドレスバー |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCABNavigatingEvent` | `uCAddressBar` | `procedure(Sender: TObject; const APath: string; var Allow: Boolean) of object`。`OnNavigating` の型 |
| `TCABNavigatedEvent` | `uCAddressBar` | `procedure(Sender: TObject; const APath: string) of object`。`OnNavigated` の型 |
| `TCABErrorEvent` | `uCAddressBar` | `procedure(Sender: TObject; const AMessage: string) of object`。`OnError` の型 |

- フォームに置くと、uses に `uCAddressBar` が自動で入り、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCListView と TCTreeView をフォームに置く（`TCListView_Usage.md`・`TCTreeView_Usage.md`）。TCTreeView の `ShellListView` に、TCListView を設定する。
2. TCAddressBar をフォームに置く。上に置かれる（`Align = alTop`）。
3. TCAddressBar の `ListView` に TCListView を、`TreeView` に TCTreeView を設定する。
4. アプリを動かす。パンくずが、今のフォルダーを出す。

- `ListView`・`TreeView` は、どちらか 1 つだけでも使えます。ただし、戻る・進む・履歴は、TCListView が履歴を持っているので、`ListView` を設定したときだけ使えます（使えないボタンは灰色になります）。
- どちらも設定しないときは、`NavigateTo` で移ったフォルダーだけを覚えて表示します。
- 検索ボックス（`TCSearchBox_Usage.md`）と同じフォームに置くときは、アドレスバーを `alClient`、検索ボックスを `alRight` にして、1 つのパネルに並べると、エクスプローラーと同じ並びになります。

## 3. 操作

### 3.1 マウス

| 操作 | 動作 |
|---|---|
| 戻る・進む・上へ | 履歴の前後・親フォルダーへ移る。使えないときは灰色で、押せない |
| 更新 | 一覧（なければツリー）を最新の情報にする |
| パンくずの名前 | そのフォルダーへ移る。「PC」を押すと、ドライブの一覧が出る |
| パンくずの「>」 | そのフォルダーの下のフォルダーの一覧が出る。選ぶと移る。今のパンくずの次の部分は、太字で出る |
| 「...」 | 隠れている前の部分の一覧が出る |
| 「v」 | 履歴の一覧が出る（新しい順。今のフォルダーに印）。選ぶと、そこへ移る |
| アイコン・空いている所 | 入力モードにする |

- 「>」の一覧には、隠し・システム属性のフォルダーは出ません。名前順（エクスプローラーと同じ自然順）で、最大 300 個です。それを超えると、最後に「...」が出ます（選べません）。
- 読めないフォルダーの「>」は、何も出ません。

### 3.2 キー

| キー | 動作 |
|---|---|
| `Enter`・`F4`・`Ctrl+L`・`Alt+D` | 入力モードにする |
| `Alt+←`・`Alt+→`・`Alt+↑` | 戻る・進む・上へ |
| `F5` | 更新 |
| `Tab` | 次の部品へ |

- `Ctrl+L`・`Alt+D` は、フォーカスが、同じフォームの TCListView・TCTreeView の上にあるときも使えます（入力モードになります）。

### 3.3 入力モード

| 操作 | 動作 |
|---|---|
| `Enter` | 入力したパスへ移る。移れたら、入力モードを終える |
| `Esc` | 入力モードを終える（移らない） |
| ほかをクリック・フォーカスが外れた | 入力モードを終える（移らない） |

入力したパスは、次のように整えてから使います。

- 前後の空白と、前後の `"` を除く（エクスプローラーからコピーした `"C:\My Folder"` もそのまま使える）。
- `%USERPROFILE%` などの環境変数を置き換える。
- `/` は `\` にする。
- `C:` だけなら `C:\` にする。ドライブのルート以外の、末尾の `\` は除く。
- フォルダーとして存在しなければ、移らない。`OnError` が届く（未設定なら、入力モードのまま）。ファイルのパスは受けない。

## 4. プロパティ

### 4.1 この部品で足したもの

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `ListView` | `TCListView` | 読み・書き | 連動する一覧 |
| `TreeView` | `TCTreeView` | 読み・書き | 連動するツリー |
| `SyncTree` | `Boolean` | 読み・書き | 移るとき、`TreeView` も同じフォルダーにするか（既定値は `True`） |
| `ShowNavButtons` | `Boolean` | 読み・書き | 戻る・進む・上へのボタンを出すか（既定値は `True`） |
| `ShowHistoryButton` | `Boolean` | 読み・書き | 履歴の「v」ボタンを出すか（既定値は `True`） |
| `ShowRefreshButton` | `Boolean` | 読み・書き | 更新ボタンを出すか（既定値は `True`） |
| `Path` | `string` | 読み・書き | 今のフォルダー。書くと、そのフォルダーへ移る（ないフォルダーなら何もしない）。実行時だけ |
| `Editing` | `Boolean` | 読み | 入力モードなら `True`。実行時だけ |
| `Color` | `TColor` | 読み・書き | 入力の枠の中の背景色（既定値は `clDefault`。`clWindow` と同じ） |

- 今のフォルダーは、`ListView` があればその `Root`、なければ `TreeView` の `Path`、どちらもなければ `NavigateTo` で移ったフォルダーです。
- 一覧が検索結果の表示（`TCListView_Usage.md` 5.5）のときは、パンくずは、検索したフォルダーを出します。

### 4.2 LCL から引き継いだもの

`Align`（既定値は `alTop`）、`Anchors`、`BorderSpacing`、`Constraints`、`Enabled`、`Font`、`ParentFont`、`PopupMenu`、`ShowHint`、`TabOrder`、`TabStop`（既定値は `True`）、`Visible`。

- 高さの既定値は 32（96dpi。表示の倍率で大きくなる）。

## 5. メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | ― | 作る。コードで作るときに使う（8.2） |
| `NavigateTo` | `const APath: string` | `Boolean` | そのフォルダーへ移る。`ListView` があれば、その `NavigateTo` で移り、`SyncTree` が `True` なら `TreeView` も同じフォルダーにする。`ListView` がなく `TreeView` だけのときは、`TreeView.Path` で移る。フォルダーがない・`OnNavigating` で断られたときは `False`。移ったら `OnNavigated` |
| `BeginEdit` | ― | ― | 入力モードにする（`Ctrl+L` と同じ） |
| `EndEdit` | `ACancel: Boolean` | ― | 入力モードを終える。`ACancel = False` なら、入力した文字で移ろうとする |
| `Refresh` | ― | ― | 更新する（`F5` と同じ） |

## 6. イベント

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnNavigating` | `Sender: TObject; const APath: string; var Allow: Boolean` | この部品の操作（パンくず・入力・ボタン・`NavigateTo`）で移る前。`Allow := False` で、移らない |
| `OnNavigated` | `Sender: TObject; const APath: string` | この部品の操作で移った後。一覧・ツリーの側の操作（ダブルクリックなど）で移ったときは出ない（それは、TCListView の `OnFolderChanged` で知る） |
| `OnError` | `Sender: TObject; const AMessage: string` | 入力したパスが見つからない・フォルダーでないとき。未設定なら、入力モードのまま |

## 7. 注意

- Windows 専用。
- 戻る・進む・履歴は、`ListView` を設定したときだけ使えます。
- パンくずのドライブの名前（「ローカル ディスク (C:)」など）は、Windows が付けた名前です。
- 設計時は、見本のパンくずを出すだけです。操作はできません。
- 入力モードのとき、「フォルダーが変わった」知らせが来ても、パンくずを作り直さない（入力を壊さないため）。入力モードを終えると、今のフォルダーに合う。

## 8. 使い方の例

### 8.1 移ったフォルダーを、フォームのタイトルに出す

```pascal
procedure TForm1.CAddressBar1Navigated(Sender: TObject; const APath: string);
begin
  Caption := APath;
end;
```

### 8.2 コードで作る

```pascal
uses uCAddressBar, CListView, CTreeView;

var
  AB: TCAddressBar;
begin
  AB := TCAddressBar.Create(Self);
  AB.Parent := Self;
  AB.Align := alTop;
  AB.ListView := CListView1;
  AB.TreeView := CTreeView1;
end;
```

### 8.3 特定のフォルダーより上へは行かせない

```pascal
procedure TForm1.CAddressBar1Navigating(Sender: TObject; const APath: string; var Allow: Boolean);
begin
  // C:\work の外へは移らない
  Allow := SameText(Copy(APath, 1, Length('C:\work')), 'C:\work');
end;
```
