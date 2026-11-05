# TCExpandPanel 取扱説明書

作者: aotan083
日付: 2026-11-05
版: 1.0

---

## 1. 概要とクラス

VS Code のエクスプローラーのような、「タイトルバー付きの伸縮するパネル」を並べる部品です。

```
+-----------------------------------------+
| ∨ 開いているエディター                    |  ← TCRollout（1つ目）
|   cdb.py                                |
+-----------------------------------------+
| ∨ ファイル                               |  ← TCRollout（2つ目。Fill = True）
|   （中身は残りの場所いっぱいに広がる）      |
+-----------------------------------------+
| > アウトライン                            |  ← 閉じている TCRollout
+-----------------------------------------+
| ∨ FPC Projects          ［＋］［📁］［…］ |  ← タイトルバー右側のボタン
|   No project files found.               |
+-----------------------------------------+
  TCExpandPanel（入れ物）
```

- **TCRollout** は、伸縮する 1 つのパネルです。タイトルバー（矢印・Caption・右側のボタン）と、部品を置ける中身を持ちます。単体でも使えます。
- **TCExpandPanel** は、TCRollout を複数並べる入れ物です。`AddPanel` で追加します。
- タイトルバーをクリックすると、開閉します。開閉は、なめらかに大きさが変わります。
- タイトルバー右側のボタンは、`Buttons` に登録します（部品を貼る必要はありません）。ボタンに TPopupMenu を指定すると、押したときにそのメニューが開きます。
- タイトルバーの位置（上・下・左・右）は、TCRollout の `HeaderPosition` で決めます。伸縮する向きも、これで決まります。
- 入れ物の中身が溢れたときは、スクロールバーが出ます。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCRollout` | `uCExpandPanel` | cx | `TCustomControl` | 伸縮する 1 つのパネル |
| `TCExpandPanel` | `uCExpandPanel` | cx | `TCustomControl` | `TCRollout` を並べる入れ物 |
| `TCRolloutButton` | `uCExpandPanel` | cx | `TCollectionItem` | タイトルバー右側のボタン 1 つ分の定義 |
| `TCRolloutButtons` | `uCExpandPanel` | cx | `TOwnedCollection` | `TCRolloutButton` の一覧 |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCRolloutHeaderPosition` | `uCExpandPanel` | `hpTop`・`hpBottom`・`hpLeft`・`hpRight`。タイトルバーの位置 |
| `TCExpandOrientation` | `uCExpandPanel` | `eoVertical`（縦に並べる）・`eoHorizontal`（横に並べる） |
| `TCRolloutButtonsShow` | `uCExpandPanel` | `bsAlways`（いつも出す）・`bsHover`（タイトルバーにマウスが乗っているときだけ出す） |
| `TCRolloutButtonEvent` | `uCExpandPanel` | `procedure(Sender: TObject; Index: Integer) of object`。`OnButtonClick` の型 |
| `TCRolloutExpandingEvent` | `uCExpandPanel` | `procedure(Sender: TObject; var Allow: Boolean) of object`。`OnExpanding` の型 |

- フォームに置くと、uses に `uCExpandPanel` が自動で入ります。
- フォームに置くと、プロジェクトの必要パッケージに cx が自動で追加されます。
- コードで作るときは、uses に自分で書きます。

## 2. フォームに置いて動かすまで

### 2.1 入れ物に並べて使う

1. パレット [CX] から、TCExpandPanel をフォームに置きます。大きさと `Align` は、自由に決めます。
2. TCExpandPanel を右クリックし、「パネルの追加」を選びます。TCRollout が末尾に追加されます。
3. オブジェクトインスペクタで、パネルの `Caption`（見出し）と `ExpandedSize`（開いたときの大きさ）を設定します。
4. パネルの上に、部品（TListBox、TTreeView など）を置きます。`Align` を `alClient` にすると、中身いっぱいに広がります。
5. 2～4 をパネルの数だけ繰り返します。
6. 実行します。タイトルバーをクリックすると、開閉します。

- パネルの順番は、パネルを選んで右クリックの「上へ移動」「下へ移動」で変えます。
- パネルを削除するときは、パネルを選んで右クリックの「パネルの削除」を選びます。
- 余った場所を埋めたいパネルは、`Fill` を `True` にします（4.2）。

### 2.2 パネルにボタンを付ける

1. TImageList をフォームに置き、アイコンにする画像を入れます。パネルの `Images` に、その TImageList を設定します。
2. パネルの `Buttons` の［…］を押し、［追加］でボタンを増やします。
3. ボタンごとに、`ImageIndex`（アイコンの番号）と `Hint`（ヒントの文字）を設定します。
4. メニューを出したいボタンは、`DropDownMenu` に TPopupMenu を指定します。
5. ボタンを押したときの処理は、パネルのイベントタブの `OnButtonClick` をダブルクリックして書きます。`Index` が、`Buttons` の中の番号です。
6. ボタンを、タイトルバーにマウスが乗っているときだけ出したいときは、`ButtonsShow` を `bsHover` にします。

### 2.3 単体で使う

TCRollout は、TCExpandPanel に入れなくても、フォームや TPanel の上に直接置けます。`Align` を `alTop`・`alLeft` などにすると、パネルの開閉に合わせて、まわりの部品が動きます。

- `Align` を `alNone` にしたとき、`hpBottom`・`hpRight` のパネルは、タイトルバー側の辺を動かさずに開閉します。
- パネルの境界をドラッグして大きさを変えたいときは、標準の TSplitter を使えます（`Align = alTop` などで並べたとき）。

### 2.4 画面の言語（日本語・English）

この部品が画面に出す文字（メッセージ）は、日本語か英語で出ます。言語は cx の部品すべてで 1 つで、部品ごとには決めません。

EXE と同じフォルダーの WebView2.ini に、次のように書きます。WebView2 を使わないアプリでも、この ini を置きます（`[CX]` だけを書けばよい）。

```ini
[CX]
Language=en
```

| 順 | 決め方 |
|---|---|
| 1 | `[CX]` の `Language` が `ja` または `en` なら、その言語（大文字・小文字は問わない） |
| 2 | それ以外（ini が無い・`[CX]` が無い・空・ほかの値）は、Windows の表示言語。日本語なら `ja`、それ以外は `en` |

- 最初に文字を出すときに 1 回だけ決めます。実行中に書き換えても、次の起動まで効きません。
- IDE の上でフォームデザイナの右クリックに出る項目（「パネルの追加」など）は、いつも日本語です。
- ボタンの `Hint` は、アプリが決める文字です。この言語の設定の対象ではありません。

## 3. TCExpandPanel

### 3.1 プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Orientation` | `TCExpandOrientation` | 読み・書き | パネルを並べる向き（既定値は `eoVertical`）。`eoVertical` は縦に積む。`eoHorizontal` は横に並べる |
| `Multiple` | `Boolean` | 読み・書き | 複数のパネルを同時に開けるか（既定値は `True`）。`False` にすると、1 つのパネルを開いたとき、ほかのパネルが閉じる（アコーディオン） |
| `Spacing` | `Integer` | 読み・書き | パネルとパネルの間の余白（既定値は 0） |
| `Scrollable` | `Boolean` | 読み・書き | パネルを並べた長さが入れ物より長いとき、スクロールバーを出すか（既定値は `True`）。`False` なら、溢れた分は切れる |
| `Panels[Index]` | `TCRollout` | 読み | 入れ物の中のパネル（並んでいる順）。実行時だけ |
| `PanelCount` | `Integer` | 読み | パネルの数。実行時だけ |
| `Align` | `TAlign` | 読み・書き | 親の中での配置 |
| `Anchors` | `TAnchors` | 読み・書き | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `BorderSpacing` | `TControlBorderSpacing` | 読み・書き | 周りの余白 |
| `Color` | `TColor` | 読み・書き | 背景色（パネルが並んでいない場所の色） |
| `Constraints` | `TSizeConstraints` | 読み・書き | 大きさの上限・下限 |
| `Enabled` | `Boolean` | 読み・書き | 使えるか |
| `Font` | `TFont` | 読み・書き | 文字 |
| `Height` | `Integer` | 読み・書き | 高さ |
| `Left` | `Integer` | 読み・書き | 左端の位置 |
| `Name` | `TComponentName` | 読み・書き | 部品の名前 |
| `ParentColor` | `Boolean` | 読み・書き | 親の `Color` を使うか |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `ParentShowHint` | `Boolean` | 読み・書き | 親の `ShowHint` を使うか |
| `ShowHint` | `Boolean` | 読み・書き | ヒントを出すか |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値 |
| `Top` | `Integer` | 読み・書き | 上端の位置 |
| `Visible` | `Boolean` | 読み・書き | 表示するか |
| `Width` | `Integer` | 読み・書き | 幅 |

- `Visible = False` のパネルは、並べるとき数えません。
- 入れ物の中の TCRollout の `Align` は、入れ物が決めるので、設定しても効きません。
- `Spacing` は、表示スケールに合わせて拡大されます（フォームの `Scaled = True` のとき）。

### 3.2 メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | ― | 作る。コードで作るときに使う（8.7） |
| `AddPanel` | `ARollout: TCRollout` | ― | パネルを末尾に追加する。すでに入っていれば何もしない。nil なら例外（`EArgumentException`） |
| `InsertPanel` | `Index: Integer; ARollout: TCRollout` | ― | パネルを、`Index` の位置に追加する。`Index` が範囲外なら、末尾に追加する |
| `RemovePanel` | `ARollout: TCRollout` | ― | パネルを入れ物から外す（`Parent` が nil になる）。パネルは解放しない |
| `MovePanel` | `CurIndex, NewIndex: Integer` | ― | パネルの順番を変える。範囲外・同じ番号なら何もしない |
| `IndexOfPanel` | `ARollout: TCRollout` | `Integer` | パネルの番号。入っていなければ -1 |

- `TCRollout` 以外の部品は、入れ物に入れられません（コードで `Parent` に設定すると、例外 `EInvalidOperation` になります）。

### 3.3 並べ方

`Orientation = eoVertical`（縦に並べる）のとき、次のように並びます。`eoHorizontal` のときは、高さと幅を入れ替えて読みます。

| パネル | 大きさ（縦に並べるときの高さ） |
|---|---|
| `Fill = False` で開いている | `ExpandedSize` |
| 閉じている | `HeaderSize`（タイトルバーだけ） |
| `Fill = True` で開いている | 余った場所を、開いている `Fill` のパネルで等分した大きさ（最小は、タイトルバー＋約 60 px） |

- 開いている `Fill` のパネルが無いときは、余りは空いたままになります（背景が見えます）。
- 並べる向きに合わない `HeaderPosition` は、入れ物の中では読み替えます。縦に並べるときは、`hpLeft`・`hpRight` を `hpTop` として扱います。横に並べるときは、`hpTop`・`hpBottom` を `hpLeft` として扱います。`HeaderPosition` の値そのものは変わりません。
- パネルの幅（横に並べるときは高さ）は、入れ物いっぱいです。

### 3.4 スクロール

パネルを並べた長さが入れ物より長いとき、`Scrollable = True` なら、Windows 標準のスクロールバー（縦に並べるなら縦、横に並べるなら横）が出ます。

| 操作 | 動作 |
|---|---|
| スクロールバーの操作 | スクロールする |
| マウスホイール（縦に並べるとき） | 縦にスクロールする |
| Shift + マウスホイール（横に並べるとき） | 横にスクロールする |

- パネルの上の部品（TMemo など）の上でホイールを回したときは、その部品が受け取ります。
- パネルが閉じて全体が短くなったときは、スクロールの位置が自動で収まります。

## 4. TCRollout

### 4.1 プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Caption` | `TCaption` | 読み・書き | タイトルバーの文字 |
| `Expanded` | `Boolean` | 読み・書き | 開いているか（既定値は `True`）。書くと開閉する（イベントも出る） |
| `HeaderPosition` | `TCRolloutHeaderPosition` | 読み・書き | タイトルバーの位置（既定値は `hpTop`）。伸縮する向きも決まる（4.4） |
| `HeaderSize` | `Integer` | 読み・書き | タイトルバーの厚み（既定値は 24）。`hpTop`・`hpBottom` なら高さ、`hpLeft`・`hpRight` なら幅 |
| `ExpandedSize` | `Integer` | 読み・書き | 開いているときの、伸縮する向きの大きさ（既定値は 150）。`HeaderSize` より小さくならない |
| `Fill` | `Boolean` | 読み・書き | 入れ物の中で、開いているとき、余った場所を埋めるか（既定値は `False`）。単体のときは何もしない |
| `ShowArrow` | `Boolean` | 読み・書き | タイトルバーに矢印を出すか（既定値は `True`） |
| `Images` | `TCustomImageList` | 読み・書き | ボタンのアイコンの画像を持つイメージリスト |
| `ImagesWidth` | `Integer` | 読み・書き | アイコンを描く幅（表示スケール 100% のときの px）。0（既定値）なら `Images` の `Width` |
| `Buttons` | `TCRolloutButtons` | 読み・書き | タイトルバー右側のボタンの一覧（4.2） |
| `ButtonsShow` | `TCRolloutButtonsShow` | 読み・書き | ボタンを出すとき（既定値は `bsAlways`）。`bsHover` は、タイトルバーにマウスが乗っているときだけ出す。設計時は、いつも出る。メニューを開いている間も出したままになる。ボタンの場所は、出さないときも空けておく |
| `Animated` | `Boolean` | 読み・書き | 開閉のとき、大きさを少しずつ変えるか（既定値は `True`）。設計時は、いつもすぐに変わる |
| `AnimationTime` | `Integer` | 読み・書き | 開閉にかける時間（ミリ秒。既定値は 150）。0 以下なら、すぐに変わる |
| `ExpandPanel` | `TCExpandPanel` | 読み | このパネルが入っている入れ物。単体のときは nil。実行時だけ |
| `Align` | `TAlign` | 読み・書き | 親の中での配置（入れ物の中では効かない） |
| `Anchors` | `TAnchors` | 読み・書き | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `BorderSpacing` | `TControlBorderSpacing` | 読み・書き | 周りの余白 |
| `Color` | `TColor` | 読み・書き | 中身の背景色（既定値は `clBtnFace`） |
| `Constraints` | `TSizeConstraints` | 読み・書き | 大きさの上限・下限 |
| `Enabled` | `Boolean` | 読み・書き | 使えるか。`False` で、開閉とボタンが動かなくなり、アイコンが灰色になる |
| `Font` | `TFont` | 読み・書き | タイトルバーの文字 |
| `Height` | `Integer` | 読み・書き | 高さ |
| `Left` | `Integer` | 読み・書き | 左端の位置 |
| `Name` | `TComponentName` | 読み・書き | 部品の名前 |
| `ParentColor` | `Boolean` | 読み・書き | 親の `Color` を使うか |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `ParentShowHint` | `Boolean` | 読み・書き | 親の `ShowHint` を使うか |
| `PopupMenu` | `TPopupMenu` | 読み・書き | 右クリックしたときに出すメニュー |
| `ShowHint` | `Boolean` | 読み・書き | ヒントを出すか |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値 |
| `Top` | `Integer` | 読み・書き | 上端の位置 |
| `Visible` | `Boolean` | 読み・書き | 表示するか |
| `Width` | `Integer` | 読み・書き | 幅 |

- 開いているパネルの大きさ（伸縮する向き）を変えると（フォームデザイナでのドラッグ、`Height`・`Width` の設定）、その大きさが `ExpandedSize` になります。
- 閉じているパネルは、伸縮する向きの大きさが `HeaderSize` に固定されます。
- `HeaderSize`・`ExpandedSize` は、表示スケールに合わせて拡大されます（フォームの `Scaled = True` のとき）。
- ボタンのアイコンを拡大するには、TImageList の `Scaled` を `True` にし、大きさ違いの画像を用意します。

### 4.2 Buttons（TCRolloutButton）

`Buttons` の項目 1 つが、タイトルバー右側のボタン 1 つです。

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `ImageIndex` | `TImageIndex` | 読み・書き | `Images` の中のアイコンの番号。-1（既定値）ならアイコンを描かない（枠は残り、押せる） |
| `Hint` | `string` | 読み・書き | ボタンの上でマウスを止めたときに出すヒント。`ShowHint = True` のとき |
| `DropDownMenu` | `TPopupMenu` | 読み・書き | ボタンを押したときに出すメニュー（4.3） |
| `Enabled` | `Boolean` | 読み・書き | `False`（既定値は `True`）でアイコンが灰色になり、押せない |
| `Visible` | `Boolean` | 読み・書き | `False`（既定値は `True`）で出さない。右側のボタンが詰まる |

- ボタンの並びは、`Buttons` の番号の順に、左から右です（`hpTop`・`hpBottom` のとき）。`hpLeft`・`hpRight` のときは、矢印の下に、上から下へ並びます。
- 番号（`Index`）は、`Visible = False` のボタンも含めた順番です。

`Buttons` の操作は、TCollection と同じです。

| 名前 | 中身 |
|---|---|
| `Add` | ボタンを末尾に追加する（`TCollectionItem` が返るので、`TCRolloutButton(…)` に型変換して使う） |
| `Items[Index]` | ボタン |
| `Count` | ボタンの数 |
| `Delete(Index)`・`Clear` | ボタンを削除する |

### 4.3 ボタンを押したときの動き

1. ボタンを押すと、`OnButtonClick` が呼ばれます（`Index` は `Buttons` の番号）。
2. そのボタンに `DropDownMenu` があれば、続けてメニューが開きます。
   - `hpTop`・`hpBottom` のときは、ボタンの左下に出ます。
   - `hpLeft`・`hpRight` のときは、ボタンの右上に出ます。
   - メニューの `PopupComponent` は、そのパネル（TCRollout）です。

- `Enabled = False` のボタン、`Enabled = False` のパネルは、押せません。
- 設計時（フォームデザイナ）は、ボタンを押しても何も起きません。

### 4.4 タイトルバーの位置と伸縮する向き

| `HeaderPosition` | タイトルバー | 伸縮する向き | 大きさ |
|---|---|---|---|
| `hpTop`（既定値） | 上 | 下へ伸びる | 高さ |
| `hpBottom` | 下 | 上へ伸びる | 高さ |
| `hpLeft` | 左 | 右へ伸びる | 幅 |
| `hpRight` | 右 | 左へ伸びる | 幅 |

- 矢印は、開いているときは中身の側を向き、閉じているときは横（`hpTop`・`hpBottom`）か下（`hpLeft`・`hpRight`）を向きます。
- `hpLeft` の文字は下から上へ、`hpRight` の文字は上から下へ読みます。縦のタイトルバーの文字は、はみ出した部分が切れます。
- 縦のタイトルバーの矢印とボタンは、上から下へ、矢印、ボタンの順に並び、残りに文字が出ます。

### 4.5 メソッド

TCRollout には、この部品で追加したメソッドはありません。開閉は `Expanded` で行います。

### 4.6 イベント

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnExpanding` | `Sender: TObject; var Allow: Boolean` | 開く・閉じる前。`Allow := False` で取りやめる。このとき `Expanded` は、まだ変わっていない |
| `OnExpand` | `Sender: TObject` | 開いたとき。アニメーションの始まりで呼ぶ（終わりを待たない） |
| `OnCollapse` | `Sender: TObject` | 閉じたとき。アニメーションの始まりで呼ぶ（終わりを待たない） |
| `OnButtonClick` | `Sender: TObject; Index: Integer` | ボタンを押したとき。`Index` は `Buttons` の番号 |

| 操作 | 順番 |
|---|---|
| 開く | `OnExpanding` → `OnExpand` |
| 閉じる | `OnExpanding` → `OnCollapse` |
| ボタンを押す | `OnButtonClick` → （`DropDownMenu` があれば）メニューが開く |

- タイトルバーのクリック・コード（`Expanded := …`）のどちらで開閉しても、同じ順番で出ます。
- `Multiple = False` の入れ物で、ほかのパネルが閉じられたときは、そのパネルの `OnExpanding`・`OnCollapse` も呼ばれます。

#### イベントが出ないとき

| とき | 中身 |
|---|---|
| 起動 | .lfm を読み込んで、`Expanded` を復元するとき |
| 設計時 | フォームデザイナでの操作 |
| 状態が変わらない | 開いているパネルに `Expanded := True` を設定する、閉じているパネルに `Expanded := False` を設定する |

## 5. 操作

### 5.1 実行時

| 操作 | 動作 |
|---|---|
| タイトルバー（矢印・文字の部分）をクリック | 開閉する（アニメーションあり） |
| ボタンをクリック | `OnButtonClick`、続けて `DropDownMenu` |
| タイトルバーにマウスを置く | `ButtonsShow = bsHover` なら、ボタンが出る |
| ボタンにマウスを置く | ボタンを強調表示する。`ShowHint = True` なら `Hint` を出す |
| ボタンを押している間 | 強調表示が濃くなる |

### 5.2 設計時（フォームデザイナ）

| 操作 | 動作 |
|---|---|
| タイトルバーをクリック | 開閉する。開いたパネルの上に部品を置ける |
| 入れ物を右クリック →「パネルの追加」 | パネルを末尾に追加する |
| パネルを右クリック →「パネルの削除」 | 入れ物の中にあるパネルを削除する |
| パネルを右クリック →「上へ移動」「下へ移動」 | 入れ物の中でパネルの順番を変える |
| パネルの縁をドラッグ | 単体のパネルの大きさを変える（`ExpandedSize` になる） |

- 入れ物の中のパネルの位置と大きさは、入れ物が決めるので、ドラッグで動かしても元に戻ります。大きさは `ExpandedSize` で決めます。

## 6. 表示

### 6.1 色（ダーク／ライト）

システム色だけで描きます。ダーク／ライトの切り替えは、アプリ側の MetaDarkStyle などに任せます。

| 部分 | 色 |
|---|---|
| タイトルバーの背景 | `clBtnFace` |
| 中身の背景 | `Color`（既定値は `clBtnFace`） |
| 文字・矢印 | `clBtnText` |
| タイトルバーの境界の線（開いているとき） | `clBtnShadow` |
| マウスを置いたボタン | `clBtnHighlight` の角丸 |
| 押している間のボタン | `clBtnShadow` の角丸 |
| `Enabled = False` のボタン | 灰色のアイコン |

### 6.2 表示スケール（高 DPI）

Windows の表示スケール（125%、150% など）に合わせて、タイトルバーの厚み、ボタンの大きさ、矢印の大きさ、余白を自動で拡大します（フォームの `Scaled = True` のとき）。

## 7. 注意

- **子の部品の位置**：中身に置いた部品の `Left`・`Top` は、パネルの左上が基準で、タイトルバーの分は含まれません。`hpTop` なら、タイトルバーの高さ（既定値は 24）より下に置いてください。`hpLeft` なら、タイトルバーの幅より右に置いてください。`Align`（`alClient` など）で置いた部品は、タイトルバーを避けて並びます。
- **閉じたパネルの中身**：閉じているパネルの中身は、切れて見えません（部品は消えません）。
- **溢れたとき**：`Scrollable = False` の入れ物では、溢れた分が切れます。

## 8. 使い方の例

### 8.1 開いたときに、中身を読み込む

```pascal
procedure TForm1.CRollout1Expand(Sender: TObject);
begin
  LoadFileList;
end;
```

### 8.2 保存していないデータがあるときは、閉じさせない

```pascal
procedure TForm1.CRollout1Expanding(Sender: TObject; var Allow: Boolean);
begin
  // 開いている → 閉じようとしている場合だけ止める
  if (Sender as TCRollout).Expanded and FModified then
    Allow := False;
end;
```

### 8.3 ボタンごとに処理を分ける

```pascal
procedure TForm1.CRollout3ButtonClick(Sender: TObject; Index: Integer);
begin
  case Index of
    0: NewProject;     // ［＋］
    1: OpenProject;    // ［📁］
    // 2（［…］）は DropDownMenu があるので、ここでは何もしなくてよい
  end;
end;
```

### 8.4 コードで開閉する

```pascal
CRollout1.Expanded := False;               // 閉じる
CRollout1.Expanded := not CRollout1.Expanded;   // 切り替える
CRollout1.Animated := False;               // すぐに変わるようにする
```

### 8.5 アコーディオン（1 つだけ開く）にする

```pascal
CExpandPanel1.Multiple := False;
```

### 8.6 開いているパネルを保存して、次に起動したときに戻す

```pascal
uses
  IniFiles;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  Ini: TIniFile;
  i: Integer;
begin
  Ini := TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini'));
  try
    for i := 0 to CExpandPanel1.PanelCount - 1 do
      Ini.WriteBool('Panels', 'Expanded' + IntToStr(i), CExpandPanel1.Panels[i].Expanded);
  finally
    Ini.Free;
  end;
end;

procedure TForm1.FormShow(Sender: TObject);
var
  Ini: TIniFile;
  i: Integer;
begin
  Ini := TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini'));
  try
    for i := 0 to CExpandPanel1.PanelCount - 1 do
      with CExpandPanel1.Panels[i] do
      begin
        Animated := False;     // 起動時は、動かさずにすぐ切り替える
        Expanded := Ini.ReadBool('Panels', 'Expanded' + IntToStr(i), Expanded);
        Animated := True;
      end;
  finally
    Ini.Free;
  end;
end;
```

### 8.7 コードで作る

```pascal
uses
  uCExpandPanel;

procedure TForm1.FormCreate(Sender: TObject);
var
  EP: TCExpandPanel;
  R1, R2: TCRollout;
  B: TCRolloutButton;
  L: TListBox;
begin
  EP := TCExpandPanel.Create(Self);
  EP.Parent := Self;
  EP.Align := alLeft;
  EP.Width := 300;

  R1 := TCRollout.Create(Self);
  R1.Caption := 'ファイル';
  R1.Fill := True;                  // 余った場所を埋める
  EP.AddPanel(R1);                  // 入れ物に入れる
  L := TListBox.Create(Self);
  L.Parent := R1;                   // パネルの上に置く
  L.Align := alClient;

  R2 := TCRollout.Create(Self);
  R2.Caption := 'FPC Projects';
  R2.ExpandedSize := 120;
  R2.Images := ImageList1;
  R2.ShowHint := True;
  R2.ButtonsShow := bsHover;        // マウスが乗ったときだけボタンを出す
  B := TCRolloutButton(R2.Buttons.Add);
  B.ImageIndex := 0;
  B.Hint := '新規';
  B := TCRolloutButton(R2.Buttons.Add);
  B.ImageIndex := 2;
  B.Hint := 'その他';
  B.DropDownMenu := PopupMenu1;     // ［…］を押すと、このメニューが開く
  R2.OnButtonClick := @CRollout3ButtonClick;   // 8.3 の処理を使う
  EP.AddPanel(R2);
end;
```

### 8.8 単体のパネルを、下に置く（タイトルバーが下）

1. TCRollout をフォームに置き、`Align` を `alBottom`、`HeaderPosition` を `hpBottom` にします。
2. `ExpandedSize` を、開いたときの高さにします。
3. 実行すると、タイトルバーが下端に出て、クリックすると上へ伸び縮みします。

### 8.9 パネルを入れ替える・外す

```pascal
CExpandPanel1.MovePanel(0, 2);               // 先頭のパネルを、3 番目へ
CExpandPanel1.RemovePanel(CRollout2);        // 入れ物から外す（解放はしない）
CExpandPanel1.InsertPanel(0, CRollout2);     // 先頭に入れ直す
```
