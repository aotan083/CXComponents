# TCSplitter 取扱説明書

作者: aotan083
日付: 2026-11-06
版: 1.0

---

## 1. 概要とクラス

TSplitter と同じ使い方の分割線です。マウスを乗せたとき・ドラッグしている間、色の付いた線が出ます。標準の TSplitter では、マウスを乗せても見た目が変わりません。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス |
|---|---|---|---|
| `TCSplitter` | `uCSplitter` | cx | `TSplitter` |

- フォームに置くと、uses に `uCSplitter` が自動で入り、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

### 1.2 TSplitter との違い

| 項目 | TSplitter | TCSplitter |
|---|---|---|
| 分割の仕組み・プロパティ・イベント | あり | 同じ |
| マウスを乗せたときの見た目 | 変わらない | 色の付いた線が出る |
| ドラッグ中の見た目 | `ResizeStyle` による（`rsLine` なら黒い線） | 色の付いた線のまま |
| 線の色 | 指定できない | `HighlightColor` で指定できる |
| カーソルの指定 | `Cursor` を書いても、向きを変えると戻る | `SplitCursor` で指定できる |
| `OnMouseEnter`・`OnMouseLeave` など | オブジェクトインスペクタに出ない | 出る |

## 2. フォームに置いて動かすまで

1. フォームに、`Align = alLeft` のパネルを置く。
2. パレット [CX] から TCSplitter を、パネルの右側に置く（`Align = alLeft` のまま）。
3. もう 1 つのパネルを置いて `Align = alClient` にする。
4. 実行する。分割線にマウスを乗せると線が出て、ドラッグするとパネルの幅が変わる。

上下に分割するときは、`Align = alTop` のパネルの下に置き、TCSplitter の `Align` を `alTop` にする。

## 3. プロパティ

TSplitter のプロパティ（`Align`・`MinSize`・`ResizeStyle`・`ResizeAnchor`・`AutoSnap`・`Beveled` など）は、そのまま使える。足したものは次のとおり。

| プロパティ | 型 | 読み書き | 既定 | 中身 |
|---|---|---|---|---|
| `HighlightColor` | `TColor` | 読み書き | `clHighlight` | 線の色。既定は Windows の選択色で、テーマ・ダーク表示に合わせて変わる。固定したい色があれば、色を指定する |
| `SplitCursor` | `TCursor` | 読み書き | `crDefault` | 分割線の上のマウスカーソル。`crDefault` のときは TSplitter と同じ（左右に分割するなら横向きの矢印、上下に分割するなら縦向きの矢印）。ほかの値を入れると、そのカーソルになる |

- カーソルを変えるときは、`Cursor` ではなく `SplitCursor` に書く（`Cursor` に書いても、分割の向きを変えたときに元へ戻る）。
- 使えない（`Enabled = False`）ときは、線は出ず、カーソルも標準のままになる。

## 4. イベント

TSplitter のイベント（`OnCanOffset`・`OnCanResize`・`OnMoved`・`OnPaint` など）は、そのまま使える。

| イベント | いつ起きるか |
|---|---|
| `OnMouseEnter` | マウスが分割線の上に乗ったとき |
| `OnMouseLeave` | マウスが分割線から外れたとき |
| `OnMouseMove` | マウスが分割線の上で動いたとき |
| `OnMouseDown` | 分割線でボタンを押したとき |
| `OnMouseUp` | ボタンを離したとき |
| `OnMoved` | ドラッグが終わって、分割線が動いたとき（TSplitter と同じ） |

## 5. 使い方の例

### 5.1 線の色を変える

```pascal
CSplitter1.HighlightColor := clRed;
```

### 5.2 カーソルを変える

```pascal
CSplitter1.SplitCursor := crHandPoint;   // 手のカーソル
CSplitter1.SplitCursor := crDefault;     // 元に戻す
```

### 5.3 マウスが乗ったときに何かする

```pascal
procedure TForm1.CSplitter1MouseEnter(Sender: TObject);
begin
  StatusBar1.SimpleText := '分割線：ドラッグして幅を変えます';
end;

procedure TForm1.CSplitter1MouseLeave(Sender: TObject);
begin
  StatusBar1.SimpleText := '';
end;
```

## 6. 注意

- 設計時（フォームデザイナ）では、線は出ない（TSplitter と同じ見た目）。線が出るのは、実行したときだけ。
- 線は、分割線の真ん中に、2px（表示スケールに合わせて変わる）の太さで出る。分割線の幅が細いときは、見えにくい。幅は `Width`（左右に分割するとき）・`Height`（上下に分割するとき）で変えられる。
