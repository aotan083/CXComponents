# TCSplitter 設計書

作者: aotan083
日付: 2026-11-06
版: 1.0

---

## 1. 目的

- 標準の TSplitter は、マウスを乗せても見た目が変わらず、ドラッグ中の線も黒で、VS Code のような分割線の見え方にならない。そこで、TSplitter を元にして、マウスを乗せたとき・ドラッグ中に色の付いた線を出す分割線 TCSplitter を作る。
- 使い方・プロパティ・イベントは TSplitter と同じにし、色・カーソルを指定するプロパティだけを足す。
- TCExpandPanel の境界（`TCExpandSash`）も、同じ見え方にそろえる（TCExpandPanel_Design.md 6.7）。

### 1.1 含めないもの

- TSplitter の分割の仕組み（`ResizeAnchor`・`ResizeStyle`・`MinSize`・`AutoSnap`・`OnCanResize`・`OnMoved` など）は、変えずにそのまま使う。
- 設計時の見た目は、TSplitter のままにする（線は出さない）。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCSplitter.pas` | cx（実行時） | `TCSplitter` |
| `uCXReg.pas` | cxdsgn（設計時） | パレット [CX] への登録（`RegisterComponents('CX', [..., TCSplitter])`。並びの末尾） |
| `csplitter_icon.lrs` | cxdsgn（設計時） | アイコン |

- `uCSplitter` の uses：`Classes, SysUtils, Controls, ExtCtrls, Graphics, Types, LCLType, LMessages`
- `csplitter_icon.lrs`（`source\res`、cxdsgn）：パレットのアイコン（`TCSplitter`・`TCSplitter_150`・`TCSplitter_200`。24・36・48px の PNG）。`uCXReg` の initialization で `{$I csplitter_icon.lrs}`。絵は、灰色の 2 つのパネルの間に、青い分割線とつまみの白い点を描いたもの。

## 3. TCSplitter

元のクラスは `TSplitter`（ExtCtrls）。

### 3.1 定数

| 名前 | 値 | 中身 |
|---|---|---|
| `cLineWidth96` | 2 | 線の太さ（96dpi のときの値。`Scale96ToFont` で換算する） |

### 3.2 宣言

```pascal
type
  TCSplitter = class(TSplitter)
  private
    FHighlightColor: TColor;
    FSplitCursor: TCursor;
    FHot: Boolean;          // マウスが乗っている
    FDragging: Boolean;     // 左ボタンを押して、ドラッグ中
    procedure SetHighlightColor(AValue: TColor);
    procedure SetSplitCursor(AValue: TCursor);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CaptureChanged; override;
    procedure UpdateCursor; override;
  public
    constructor Create(TheOwner: TComponent); override;
  published
    property HighlightColor: TColor read FHighlightColor write SetHighlightColor default clHighlight;
    property SplitCursor: TCursor read FSplitCursor write SetSplitCursor default crDefault;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseDown;
    property OnMouseUp;
  end;
```

### 3.3 プロパティ

- `HighlightColor`：線の色。既定は `clHighlight`（Windows の選択色。テーマ・ダーク表示に追従する）。固定の色にしたいときは、色を指定する。変わったら `Invalidate`。
- `SplitCursor`：分割線の上のマウスカーソル。既定は `crDefault`（TSplitter と同じ。横に分割するなら `crHSplit`、縦に分割するなら `crVSplit`）。`crDefault` 以外を指定すると、そのカーソルになる。変わったら `UpdateCursor`。

### 3.4 動き

1. `Create`：`inherited` のあと、`FHighlightColor := clHighlight`、`FSplitCursor := crDefault`、`FHot := False`、`FDragging := False`。
2. `MouseEnter`：`inherited` のあと、設計時でなく、`Enabled` で、マウスのキャプチャが他にないとき、`FHot := True`、`Invalidate`。
3. `MouseLeave`：`inherited` のあと、`FHot := False`、`Invalidate`。ドラッグ中も、マウスが外へ出れば `FHot` は偽になる（`FDragging` が線を保つ）。
4. `MouseDown`：`inherited` のあと、左ボタンで `Enabled` なら `FDragging := True`、`Invalidate`。
5. `MouseUp`：`inherited` のあと、左ボタンなら `FDragging := False`、`Invalidate`。
6. `CaptureChanged`：`inherited` のあと、`FDragging` が真で、ボタンがもう押されていなければ、`FDragging := False`、`Invalidate`（マウスアップが届かないときの保険）。
7. `UpdateCursor`：`Enabled` でなければ `Cursor := crDefault`。`Enabled` で `FSplitCursor <> crDefault` なら `Cursor := FSplitCursor`。それ以外は `inherited UpdateCursor`。

### 3.5 描画（`Paint`）

1. `inherited Paint`（TSplitter の見た目：`OnPaint` があればそれ、なければテーマの帯とつまみ）。
2. 設計時、または `Enabled` が偽なら、ここで終わる。
3. `FHot` か `FDragging` が真なら、線を引く。太さ `T := Max(1, Scale96ToFont(cLineWidth96))`。`ResizeAnchor` が `akLeft`・`akRight`（縦の線）なら、横の真ん中に `T` の幅、高さいっぱい。`akTop`・`akBottom`（横の線）なら、縦の真ん中に `T` の高さ、幅いっぱい。色は `HighlightColor`。
4. `OnPaint` があるときも、線は最後に重ねる。

### 3.6 イベント

- TSplitter が持つイベント（`OnCanOffset`・`OnCanResize`・`OnMoved`・`OnPaint` など）は、そのまま使える。
- `OnMouseEnter`（マウスが乗ったとき）・`OnMouseLeave`（外れたとき）・`OnMouseMove`・`OnMouseDown`・`OnMouseUp` を、`published` にして、オブジェクトインスペクタに出す（TSplitter では出ない）。
- ドラッグが終わったときは、これまでどおり `OnMoved` が起きる。

## 4. 登録

`uCXReg.Register` の `RegisterComponents('CX', [...])` の並びの末尾に `TCSplitter` を足す。`uCXReg` の uses に `uCSplitter` を足す。

## 5. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| 線が出ない | `Paint` の 2〜3、`Enabled`、設計時でないか |
| マウスを離しても線が消えない | `MouseUp`・`CaptureChanged`（3.4 の 5〜6） |
| カーソルが変わらない | `UpdateCursor`（3.4 の 7）、`SplitCursor` |
| `OnMouseEnter` が起きない | `published` の宣言（3.2）、`MouseEnter` で `inherited` を呼んでいるか |
