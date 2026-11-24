# TCSearchBox 取扱説明書

作者: aotan083
日付: 2026-11-17
版: 1.0

---

**動作環境**：Lazarus 5.0 以降（FPC 3.2.2）。Lazarus 4.8 以前は対象外。

## 1. 概要とクラス

Windows エクスプローラーの検索ボックスと同じように使える部品です。TCListView（と TCTreeView）とつなぐだけで、表示しているフォルダーの中を、名前で探して、結果を一覧に出します。

```
[ 〈フォルダー名〉 の検索                         ][×][🔍]
   入力欄（薄い文字は、探すフォルダーの名前）    消す  虫眼鏡（押すとオプション）／探している間は回る印
```

- 名前を入力して `Enter` を押すと、探し始めます（入力のたびには探しません）。
- 探している間は、虫眼鏡の場所に回る印が出ます。見つかったものは、少しずつ一覧に出ます。印を押す（または `Esc`）と、探すのを止めます。
- 探し方は、虫眼鏡を押して出るメニューで選びます：部分一致（既定）、ワイルドカード、正規表現。大文字・小文字の区別、サブフォルダーの中も探すか、隠しファイルも探すか、も切り替えられます。
- 結果は、TCListView の「検索結果の表示」（`TCListView_Usage.md` 5.5）に出ます。名前と、その場所（フォルダー）が並びます。一覧と同じように、開く・コピー・削除などができます。
- 「×」（または `Esc`）で、検索を消して、元のフォルダーの表示に戻ります。一覧で別のフォルダーへ移る（ダブルクリック、戻る、ツリーで選ぶ、など）と、検索は自動で終わります。
- 探す処理は、TCFindFile（`TCFindFile_Usage.md`）です。

| 項目 | 内容 |
|---|---|
| Lazarus | 5.0RC1 以降 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCSearchBox` | `uCSearchBox` | cx | `TCustomControl` | エクスプローラーの検索ボックス |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCSearchResultEvent` | `uCSearchBox` | `procedure(Sender: TObject; const APath: string; AIsDir: Boolean) of object`。`OnSearchResult` の型 |
| `TCSearchFinishedEvent` | `uCSearchBox` | `procedure(Sender: TObject; AFound: Integer; AReason: TCFindStopReason) of object`。`OnSearchFinished` の型 |
| `TCSearchErrorEvent` | `uCSearchBox` | `procedure(Sender: TObject; const AMessage: string) of object`。`OnSearchError` の型 |

- `TCFindMatchMode`・`TCFindStopReason` は、`uCFindFile` の型です（`TCFindFile_Usage.md` 1.1）。この部品の `MatchMode` や `OnSearchFinished` を使うコードでは、uses に `uCFindFile` も書きます。
- フォームに置くと、uses に `uCSearchBox` が自動で入り、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCListView と TCTreeView をフォームに置く（`TCListView_Usage.md`・`TCTreeView_Usage.md`）。TCTreeView の `ShellListView` に、TCListView を設定する。
2. TCSearchBox をフォームに置く。
3. TCSearchBox の `ListView` に TCListView を、`TreeView` に TCTreeView を設定する。
4. アプリを動かす。入力欄に名前を入れて `Enter` を押す。

- 探すフォルダーは、`ListView` があれば表示しているフォルダー（`Root`）、なければ `TreeView` で選んでいるフォルダーです。入力欄の薄い文字に、そのフォルダーの名前が出ます。
- ツリーでクイックアクセスなどのグループ（フォルダーでないもの）を選んでいて、一覧もないときは、探せません（`OnSearchError` が届きます）。
- `ListView` を設定しなくても、探せます。そのときは、`OnSearchResult` で結果を受け取って、自分で見せます。探すフォルダーは、`TreeView` があればそのフォルダー、なければ `Finder.Root`（先にアプリが設定しておく）です。
- アドレスバー（`TCAddressBar_Usage.md`）と同じフォームに置くときは、アドレスバーを `alClient`、検索ボックスを `alRight` にして、1 つのパネルに並べると、エクスプローラーと同じ並びになります。

## 3. 操作

### 3.1 マウス

| 操作 | 動作 |
|---|---|
| 虫眼鏡（探していないとき） | オプションのメニューを出す（3.3）。`ShowOptionsMenu` が `False` なら何もしない |
| 回る印（探している間） | 探すのを止める |
| 「×」 | 検索を消す（探していれば止め、入力を空にして、検索結果の表示を終える）。入力があって、探していないときだけ出る |
| 入力欄 | 文字を入力する。コピー・貼り付け・日本語入力は、ふつうの入力欄と同じ |

### 3.2 キー

| キー | 動作 |
|---|---|
| `Enter` | 探し始める。入力が空（空白だけ）なら、検索を消す |
| `Esc` | 探している最中なら止める（結果は残る）。そうでなく入力があれば、検索を消す |
| `Ctrl+E`・`Ctrl+F` | この部品へ移る。フォーカスが、同じフォームの TCListView・TCTreeView の上にあるときも使える |

- 探している最中にもう一度 `Enter` を押すと、前の探しを止めて、やり直します。

### 3.3 オプションのメニュー

| 項目 | 動作 |
|---|---|
| 部分一致 | 名前に、入力した文字が含まれるものを探す（既定） |
| ワイルドカード（* ?） | `*`：任意の文字列、`?`：1 文字。`;` で複数（例：`*.pas;*.lfm`） |
| 正規表現 | 正規表現で探す（例：`\.(pas|lfm)$`）。式が正しくないときは、探さずに、エラーが出る |
| 大文字と小文字を区別する | 切り替え |
| サブフォルダーを含める | 切り替え（既定は含める） |
| 隠しファイル・システムファイルを含める | 切り替え（既定は含めない） |

- メニューで切り替えても、すぐには探しません（`Enter` で探します）。
- 同じことは、プロパティ（`MatchMode`・`CaseSensitive`・`IncludeSubfolders`・`SearchHidden`）でも設定できます。
- 名前の探し方の詳しい書き方は、`TCFindFile_Usage.md` 1.2 にあります。

### 3.4 エラーのとき

- 正規表現が正しくない、探すフォルダーがない、のときは、`OnSearchError` が届きます。
- `OnSearchError` が未設定なら、枠が赤くなり、マウスを乗せるとヒントに理由が出ます（次に入力を変えると消えます）。

## 4. プロパティ

### 4.1 この部品で足したもの

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `ListView` | `TCListView` | 読み・書き | 結果を出す一覧 |
| `TreeView` | `TCTreeView` | 読み・書き | 探すフォルダーの元（`ListView` がないとき、または一覧にフォルダーがないとき） |
| `Text` | `string` | 読み・書き | 入力欄の文字（探す名前）。書くと `OnChange` が出る |
| `TextHint` | `string` | 読み・書き | 入力が空のときに出す薄い文字。空にしておくと、「（フォルダー名）の検索」が自動で出る（フォルダーが分からないときは「検索」） |
| `MatchMode` | `TCFindMatchMode` | 読み・書き | 探し方（既定値は `fmContains`） |
| `CaseSensitive` | `Boolean` | 読み・書き | 大文字・小文字を区別するか（既定値は `False`） |
| `IncludeSubfolders` | `Boolean` | 読み・書き | サブフォルダーの中も探すか（既定値は `True`） |
| `SearchHidden` | `Boolean` | 読み・書き | 隠し・システム属性のものも探すか（既定値は `False`） |
| `MaxResults` | `Integer` | 読み・書き | 結果の最大数（既定値は 10000。0 は制限なし） |
| `ShowOptionsMenu` | `Boolean` | 読み・書き | 虫眼鏡を押してオプションのメニューを出せるか（既定値は `True`） |
| `Color` | `TColor` | 読み・書き | 入力の枠の中の背景色（既定値は `clDefault`。`clWindow` と同じ） |
| `Searching` | `Boolean` | 読み | 探している最中なら `True`。実行時だけ |
| `ResultCount` | `Integer` | 読み | 今の検索で、見つかった数。実行時だけ |
| `Finder` | `TCFindFile` | 読み | 探す部品（この部品が持っている）。`Finder.Root` は、`ListView`・`TreeView` がないときの探すフォルダーとして使う（探すフォルダーが `ListView`・`TreeView` から決まったときは、探し終わったら空に戻る）。実行時だけ |

### 4.2 LCL から引き継いだもの

`Align`、`Anchors`、`BorderSpacing`、`Constraints`、`Enabled`、`Font`、`ParentFont`、`PopupMenu`、`ShowHint`、`TabOrder`、`TabStop`（既定値は `True`）、`Visible`、`Width`（既定値は 260）、`Height`（既定値は 32。96dpi）。

## 5. メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | ― | 作る。コードで作るときに使う（8.2） |
| `Search` | ― | ― | `Enter` と同じ。今の `Text` で探し始める。`Text` が空（空白だけ）なら、`ClearSearch` と同じ |
| `StopSearch` | ― | ― | 探している最中なら止める（結果は残る） |
| `ClearSearch` | ― | ― | 探すのを止め、`Text` を空にし、検索結果の表示を終える（元のフォルダーの表示に戻る） |
| `SetFocus` | ― | ― | 入力欄にフォーカスを移して、全部を選ぶ |

## 6. イベント

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnChange` | `Sender: TObject` | 入力の文字が変わった（入力・`Text` への書き込み・検索を消したとき） |
| `OnSearchStart` | `Sender: TObject` | 探し始めた |
| `OnSearchResult` | `Sender: TObject; const APath: string; AIsDir: Boolean` | 1 件見つかるたび。`ListView` に出すのとは別に、自分で受けたいときに使う（`ListView` がなくても出る） |
| `OnSearchFinished` | `Sender: TObject; AFound: Integer; AReason: TCFindStopReason` | 探し終わった（止めたとき・上限に達したときも）。`AReason`：`frDone`、`frStopped`、`frLimit`、`frError` |
| `OnSearchError` | `Sender: TObject; const AMessage: string` | 探し始められなかった（正規表現が正しくない、探すフォルダーがない）。未設定なら、枠が赤くなる（3.4） |

## 7. 注意

- Windows 専用。
- 探すのは、ファイル名・フォルダー名だけです（ファイルの中身は探しません）。
- 正規表現は、名前を UTF-8 のまま扱うため、`.` はバイト単位で働きます。日本語の文字数を指定する式は、期待どおりになりません（`TCFindFile_Usage.md` 1.2）。
- 結果は、探した順に並びます。一覧の列の見出しを押すと並べ替えられます。
- 検索結果の表示のあいだは、一覧は、フォルダーの変更を監視しません（ファイルが増えても、結果は変わりません）。
- 一覧が、ほかの操作でフォルダーを移ったときは、検索は止まり、入力は空になります。
- 設計時は、枠と薄い文字と虫眼鏡を出すだけです。探しはしません。

## 8. 使い方の例

### 8.1 検索が終わったら、件数を出す

```pascal
procedure TForm1.CSearchBox1SearchFinished(Sender: TObject; AFound: Integer; AReason: TCFindStopReason);
begin
  if AReason = frLimit then
    StatusBar1.SimpleText := Format('%d 件（上限に達しました）', [AFound])
  else
    StatusBar1.SimpleText := Format('%d 件', [AFound]);
end;
```

### 8.2 コードで作る

```pascal
uses uCSearchBox, uCFindFile, CListView, CTreeView;

var
  SB: TCSearchBox;
begin
  SB := TCSearchBox.Create(Self);
  SB.Parent := Self;
  SB.Align := alRight;
  SB.Width := 280;
  SB.ListView := CListView1;
  SB.TreeView := CTreeView1;
  SB.MatchMode := fmWildcard;      // 最初から、ワイルドカードで探す
end;
```

### 8.3 一覧を使わずに、結果を自分で受ける

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  CSearchBox1.Finder.Root := 'C:\app';           // ListView・TreeView がないので、探すフォルダーを渡す
  CSearchBox1.OnSearchResult := @OnResult;
end;

procedure TForm1.OnResult(Sender: TObject; const APath: string; AIsDir: Boolean);
begin
  ListBox1.Items.Add(APath);
end;
```
