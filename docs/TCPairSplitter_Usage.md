# TCPairSplitter 取扱説明書

作者: aotan083
日付: 2026-11-08
版: 1.0

---

## 1. 概要とクラス

TPairSplitter と同じ使い方の、「2 つの側（Side1・Side2）と、その間の境目」を 1 つにまとめた部品です。境目をドラッグして、2 つの側の大きさを変えます。TPairSplitter に次のことを足しています。

- 側ごとに、隠す・出すことができる。片方を隠すと、もう片方が全体に広がる。出すと元に戻る。
- 境目に、マウスを乗せたとき・ドラッグしている間、色の付いた線（TCSplitter と同じ青い線）が出る。
- 設計時（フォームデザイナ）も、境目をドラッグして位置を変えられる。

```
+--------------------+--+------------------------------+
| Side1              |┃ | Side2                        |
| （部品を置く）        |┃ | （部品を置く）                 |
+--------------------+--+------------------------------+
                      境目（ドラッグで Position が変わる）
```

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCPairSplitter` | `uCSplitter` | cx | `TCustomControl` | 2 つの側と境目 |
| `TCPairSplitterSide` | `uCSplitter` | cx | `TCustomPanel` | 1 つの側。この上に部品を置く。`TCPairSplitter` の上にだけ置ける |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCPairSplitterType` | `uCSplitter` | 分ける向き。`cpsHorizontal`（左右に分ける）・`cpsVertical`（上下に分ける） |

- フォームに置くと、uses に `uCSplitter` が自動で入り、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

### 1.2 TPairSplitter との違い

| 項目 | TPairSplitter | TCPairSplitter |
|---|---|---|
| 2 つの側・Position・分ける向き | あり | 同じ |
| 側を隠す | 隠しても、場所が空いたままになる | もう片方が全体に広がる。出すと元に戻る |
| 両方の側を隠す | できる | できない（後から隠す側が断られる） |
| 境目の見た目 | 標準の分割線（マウスを乗せても変わらない） | マウスを乗せたとき・ドラッグ中に、青い線が出る |
| 線の色 | 指定できない | `HighlightColor` で指定できる |
| 設計時のドラッグ | 標準の動き | 境目をドラッグして Position を変えられる |
| 分ける向きの型 | `TPairSplitterType` | `TCPairSplitterType`（名前が変わっただけ） |

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCPairSplitter をフォームに置く。2 つの側（`CPairSplitterSide1`・`CPairSplitterSide2`）が自動で作られる。
2. 大きさと配置（`Align` など）を決める。
3. それぞれの側の上に、ボタンなどの部品を置く。
4. オブジェクトインスペクタで、`SplitterType`（分ける向き）と `Position`（側 1 の大きさ）を決める。または、フォームデザイナで境目をドラッグする。
5. 実行する。境目にマウスを乗せると青い線が出て、ドラッグすると 2 つの側の大きさが変わる。

- 側を選ぶには、フォームデザイナで側の上をクリックするか、オブジェクトインスペクタの一覧から選ぶ。
- 側を削除すると、新しい側が自動で作り直される（2 つの側は、いつも 2 つある）。
- 側の `Visible` は、オブジェクトインスペクタで変えられる。`False` にして保存すると、その側を隠した状態で起動する。

## 3. 側ごとに隠す・出す

| 操作 | 動作 |
|---|---|
| Side1 を隠す | Side2 が全体に広がる。境目は出ない |
| Side1 を出す | Side1 と Side2 が元に戻る（Side1 の大きさは `Position`） |
| Side2 を隠す | Side1 が全体に広がる。境目は出ない |
| Side2 を出す | Side1 と Side2 が元に戻る |
| 両方を隠す | できない。もう片方がすでに隠れているとき、隠そうとした側は隠れない |
| 全体を隠す | `TCPairSplitter.Visible := False`（側の `Visible` は変わらない） |

側の指定の仕方（`CPairSplitter1` は TCPairSplitter の名前）：

```pascal
// Side1 を隠す・出す
CPairSplitter1.Side1.Visible := False;      // CPairSplitter1.Side1.Hide; でも同じ
CPairSplitter1.Side1.Visible := True;       // CPairSplitter1.Side1.Show; でも同じ

// Side2 を隠す・出す
CPairSplitter1.Side2.Visible := False;      // CPairSplitter1.Side2.Hide;
CPairSplitter1.Side2.Visible := True;       // CPairSplitter1.Side2.Show;
```

- フォームに置いたときの名前（`CPairSplitterSide1`・`CPairSplitterSide2`）でも、同じように指定できる。
- 隠している間も、`Position` は覚えている。出すと、その大きさに戻る。
- 隠している間は、境目のドラッグはできない。
- 両方を隠したいときは、側ではなく `TCPairSplitter.Visible` を使う。

## 4. TCPairSplitter

### 4.1 プロパティ

| 名前 | 型 | 読み書き | 既定 | 中身 |
|---|---|---|---|---|
| `SplitterType` | `TCPairSplitterType` | 読み・書き | `cpsHorizontal` | 分ける向き。`cpsHorizontal`：左右に分ける（側 1 が左）、`cpsVertical`：上下に分ける（側 1 が上） |
| `Position` | `Integer` | 読み・書き | 45 | 側 1 の大きさ（左右なら幅、上下なら高さ）。0 より小さい値は 0 になる。大きすぎる値は、表示のときに収める（4.3）が、`Position` の値は変わらない |
| `SplitterWidth` | `Integer` | 読み・書き | 5 | 境目の太さ（表示スケール 100% のときの px）。1 より小さい値は 1 になる |
| `HighlightColor` | `TColor` | 読み・書き | `clHighlight` | 境目の青い線の色。既定は Windows の選択色で、テーマ・ダーク表示に合わせて変わる |
| `SplitCursor` | `TCursor` | 読み・書き | `crDefault` | 境目の上のマウスカーソル。`crDefault` のときは、左右に分けるなら横向きの矢印、上下に分けるなら縦向きの矢印 |
| `Color` | `TColor` | 読み・書き | `clBtnFace` | 境目の背景の色 |
| `Side1` | `TCPairSplitterSide` | 読み | ― | 側 1。実行時と、コードで使う |
| `Side2` | `TCPairSplitterSide` | 読み | ― | 側 2 |
| `Sides[Index]` | `TCPairSplitterSide` | 読み | ― | 側（0 が側 1、1 が側 2）。範囲外なら例外（`EListError`） |
| `Align`・`Anchors`・`BorderSpacing`・`Constraints`・`Enabled`・`Visible`・`PopupMenu`・`ShowHint`・`ParentShowHint` | | | | 標準のもの |

### 4.2 イベント

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnMoved` | `Sender: TObject` | 境目をドラッグして、位置が変わった後（ドラッグを終えたとき。変わっていなければ出ない）。コードで `Position` を変えたときは出ない |
| `OnResize`・`OnChangeBounds` | `Sender: TObject` | 全体の大きさが変わったとき |
| `OnMouseDown`・`OnMouseUp`・`OnMouseMove`・`OnMouseEnter`・`OnMouseLeave`・`OnMouseWheel` など | 標準 | 境目の上の操作（側の上の操作は、側のイベント） |

### 4.3 側の大きさの決まり方

| 状態 | 側 1 | 側 2 |
|---|---|---|
| 両方見える（左右） | 幅 = `Position`、高さ = 全体の高さ | 左 = `Position` + 境目の太さ、残りの幅 |
| 両方見える（上下） | 高さ = `Position`、幅 = 全体の幅 | 上 = `Position` + 境目の太さ、残りの高さ |
| 側 1 だけ見える | 全体 | ― |
| 側 2 だけ見える | ― | 全体 |

- 全体の大きさが変わったとき、側 1 の大きさ（`Position`）は変わらず、側 2 が伸び縮みする。
- 側 1 の大きさは、次の範囲に収める。下限は側 1 の `Constraints`（最小 1）、上限は「全体 − 境目の太さ − 側 2 の下限（`Constraints`、最小 1）」。
- 表示スケール（125%、150% など）に合わせて、`Position`・`SplitterWidth` を自動で拡大する（フォームの `Scaled = True` のとき）。

## 5. TCPairSplitterSide

### 5.1 プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Visible` | `Boolean` | 読み・書き | 側を出すか。`False` にすると、もう片方が全体に広がる（3 章）。もう片方がすでに隠れているときは、`False` にできない |
| `Color`・`ParentColor` | | 読み・書き | 側の背景色 |
| `Splitter` | `TCPairSplitter` | 読み | この側が入っている TCPairSplitter。実行時だけ |
| `ChildSizing`・`Constraints`・`Cursor`・`Enabled`・`PopupMenu`・`ShowHint`・`ParentShowHint` | | 読み・書き | 標準のもの。`Constraints` の最小の大きさは、境目をドラッグできる範囲に効く |

側の位置と大きさ（`Left`・`Top`・`Width`・`Height`）と `Align` は、TCPairSplitter が決める。アプリからは変えない。

### 5.2 メソッド

標準の `Show`・`Hide` が使える。`Visible := True`・`Visible := False` と同じ動き。

### 5.3 イベント

`OnMouseDown`・`OnMouseUp`・`OnMouseMove`・`OnMouseEnter`・`OnMouseLeave`・`OnMouseWheel`・`OnResize` など、標準のものが使える。

## 6. 操作

### 6.1 実行時

| 操作 | 動作 |
|---|---|
| 境目にマウスを乗せる | 青い線（2px。`HighlightColor`）が出る。カーソルが `SplitCursor`（既定は左右なら横向きの矢印）になる |
| 境目をドラッグ | 2 つの側の大きさがドラッグに合わせて変わる。青い線も一緒に動く。離すと `OnMoved` が出る |
| 片方の側が隠れているとき | 境目は出ない。ドラッグできない |

- ドラッグ中に別のウィンドウへ切り替えた（Alt+Tab など）ときは、ドラッグをやめる。位置はそのまま残る。

### 6.2 設計時（フォームデザイナ）

| 操作 | 動作 |
|---|---|
| 境目をドラッグ | `Position` が変わる。フォームを保存すると、その値が保存される |
| 側の上をクリック | その側が選ばれる |
| 側の上に部品を置く | その側の子になる |

- 設計時は、境目に青い線は出ず、細い灰色の線が出る（`HighlightColor` は実行時の線の色）。
- TCPairSplitter の上に、側以外の部品は置けない。

## 7. 表示

| 部分 | 見た目 |
|---|---|
| 境目の背景 | `Color` |
| 境目の線（ふだん） | 1px の `clBtnShadow` の線（中央） |
| 境目の線（マウスを乗せたとき・ドラッグ中。実行時） | 2px の `HighlightColor`（表示スケールで拡大） |
| 側（設計時） | 点線の枠 |

## 8. 使い方の例

### 8.1 左右に分けて、Side1 を隠す・出す

```pascal
procedure TForm1.ButtonToggleClick(Sender: TObject);
begin
  CPairSplitter1.Side1.Visible := not CPairSplitter1.Side1.Visible;
end;
```

### 8.2 位置を保存して、次に起動したときに戻す

```pascal
uses
  IniFiles;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  with TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini')) do
  try
    WriteInteger('Splitter', 'Position', CPairSplitter1.Position);
  finally
    Free;
  end;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  with TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini')) do
  try
    CPairSplitter1.Position := ReadInteger('Splitter', 'Position', CPairSplitter1.Position);
  finally
    Free;
  end;
end;
```

- 保存する値は、表示スケールで拡大した後の値。

### 8.3 ドラッグで位置が変わったときに処理する

```pascal
procedure TForm1.CPairSplitter1Moved(Sender: TObject);
begin
  Caption := 'Position = ' + IntToStr(CPairSplitter1.Position);
end;
```

### 8.4 上下に分けて、線の色を変える

```pascal
CPairSplitter1.SplitterType := cpsVertical;
CPairSplitter1.HighlightColor := clRed;
```

### 8.5 コードで作る

```pascal
uses
  uCSplitter;

procedure TForm1.FormCreate(Sender: TObject);
var
  P: TCPairSplitter;
  B: TButton;
begin
  P := TCPairSplitter.Create(Self);
  P.Parent := Self;
  P.Align := alClient;
  P.Position := 200;
  B := TButton.Create(Self);
  B.Parent := P.Side1;           // 側は、作ったときに自動で 2 つできている
  B.Align := alTop;
  B.Caption := 'Side1';
end;
```

## 9. 制限

- 側は 2 つだけ（増やせない）。3 つ以上に分けたいときは、TCPairSplitter の側の中に、別の TCPairSplitter を置く。
- 境目のドラッグ中は、側の大きさを動かしながら描き直す（TCSideBar のように、別ウィンドウの線だけを動かす方式ではない）。
