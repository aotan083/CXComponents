# TCCheckListBox 取扱説明書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 概要とクラス

LCL の TCheckListBox に「チェックを1つだけにする（単一チェック）」機能と、チェック中の項目をループせずに取り出すプロパティを加えた部品です。

```
+----------------------+
| [ ] Item0            |
| [v] Item1   ← CheckMode = cmSingle なら、チェックは常に1つまで
| [ ] Item2            |
+----------------------+
  CheckedIndex = 1、CheckedText = 'Item1'、HasChecked = True
```

- `CheckMode` を `cmSingle` にすると、項目をチェックしたとき、それまでのチェックが自動で外れる。
- `CheckedIndex`・`CheckedText` などで、チェック中の項目をすぐに取り出せる。
- `CheckMode` が `cmMulti`（既定値）のときは、TCheckListBox と同じ動き。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス |
|---|---|---|---|
| `TCCheckListBox` | `CCheckListBox` | cx | `TCheckListBox` |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCCheckMode` | `CCheckListBox` | チェックの方式。`cmMulti`（複数チェックできる）・`cmSingle`（チェックは1つまで） |

- フォームに置くと、uses に `CCheckListBox` が自動で入り、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

## 2. フォームに置いて動かすまで

1. パレット [CX] から TCCheckListBox をフォームに置く。
2. オブジェクトインスペクタの `Items` に項目を入れる。
3. チェックを1つだけにするときは、`CheckMode` を `cmSingle` にする。
4. チェックしたものを外せないようにする（ラジオボタンと同じにする）ときは、`AllowNoCheck` を `False` にする。
5. チェックの変化で処理をするときは、イベントタブの `OnCheckedIndexChange` をダブルクリックして処理を書く。
6. 実行する。

### 2.1 単一チェックの決まり

| 設定 | 動作 |
|---|---|
| `CheckMode = cmSingle`、`AllowNoCheck = True` | チェックは 0 か 1 つ。チェック中の項目をクリックすると外れる |
| `CheckMode = cmSingle`、`AllowNoCheck = False` | チェックは 0 か 1 つ。一度チェックした後は、チェック中の項目をクリックしても外れない（ラジオボタンと同じ） |
| `CheckMode = cmMulti` | 複数チェックできる（TCheckListBox と同じ） |

- `AllowNoCheck = False` でも、起動したときにチェックが 0 の状態はありえる。最初の1つはアプリで決めるか、ユーザーに選んでもらう。
- `AllowNoCheck` が止めるのはユーザーの操作だけ。コードからは外せる。

## 3. プロパティ

### 3.1 この部品で足したもの・動きを変えたもの

| 名前 | 型 | 読み書き | 既定値 | 中身 |
|---|---|---|---|---|
| `CheckMode` | `TCCheckMode` | 読み・書き | `cmMulti` | `cmMulti`：複数チェックできる。`cmSingle`：チェックは1つまで。`cmMulti` から `cmSingle` に変えたとき、チェックが2つ以上あれば、番号が最小の項目だけが残る。`cmSingle` から `cmMulti` に変えたときは、チェックは変わらない |
| `AllowNoCheck` | `Boolean` | 読み・書き | `True` | `cmSingle` のとき、チェック中の項目をユーザーが外せるか。`False` でもコードからは外せる |
| `CheckedIndex` | `Integer` | 読み・書き | -1 | チェック中の項目の番号（ないときは -1）。`cmMulti` では番号が最小のチェック項目。書くと、その項目だけをチェックし、ほかはすべて外す（`cmMulti` でも同じ）。-1 ですべて外す。範囲外の値は無視する。実行時だけ |
| `CheckedCount` | `Integer` | 読み | ― | チェックの数。`cmSingle` では 0 か 1。実行時だけ |
| `HasChecked` | `Boolean` | 読み | ― | チェックが1つ以上あれば `True`。実行時だけ |
| `CheckedText` | `string` | 読み | ― | チェック中の項目の文字（ないときは ''）。実行時だけ |
| `CheckedObject` | `TObject` | 読み | ― | チェック中の項目の `Items.Objects`（ないときは nil）。実行時だけ |
| `Checked[AIndex]` | `Boolean` | 読み・書き | ― | その項目がチェックされているか。グレーも `True`。`cmSingle` で `True` にすると、ほかのチェックが外れる。実行時だけ |
| `State[AIndex]` | `TCheckBoxState` | 読み・書き | ― | その項目のチェックの状態。`cmSingle` で `cbChecked` にすると、ほかのチェックが外れる。`cmSingle` で `cbGrayed` にすると、チェックなしになる。実行時だけ |

- `Checked[]` は TCheckListBox と同じく、グレーも「チェックあり」とみなす。`cmMulti` の `CheckedIndex`・`CheckedCount` も同じ。
- .lfm に複数のチェックが保存されていても、`cmSingle` なら読み込んだときに番号が最小の項目だけが残る。

### 3.2 TCheckListBox から引き継いだもの

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Align` | `TAlign` | 読み・書き | 親の中での配置 |
| `AllowGrayed` | `Boolean` | 読み・書き | グレー（3つ目の状態）を使うか。`cmSingle` ではグレーにならない |
| `Anchors` | `TAnchors` | 読み・書き | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `AnchorSideBottom` | `TAnchorSide` | 読み・書き | 下の辺を、どの部品のどこに合わせるか |
| `AnchorSideLeft` | `TAnchorSide` | 読み・書き | 左の辺を、どの部品のどこに合わせるか |
| `AnchorSideRight` | `TAnchorSide` | 読み・書き | 右の辺を、どの部品のどこに合わせるか |
| `AnchorSideTop` | `TAnchorSide` | 読み・書き | 上の辺を、どの部品のどこに合わせるか |
| `BiDiMode` | `TBiDiMode` | 読み・書き | 右から左に並べるか |
| `BorderSpacing` | `TControlBorderSpacing` | 読み・書き | 周りの余白 |
| `BorderStyle` | `TBorderStyle` | 読み・書き | 枠の線を出すか |
| `Color` | `TColor` | 読み・書き | 背景色 |
| `Columns` | `Integer` | 読み・書き | 列の数（0 で1列） |
| `Constraints` | `TSizeConstraints` | 読み・書き | 大きさの上限・下限 |
| `Cursor` | `TCursor` | 読み・書き | 上に来たときのマウスカーソル |
| `DragCursor` | `TCursor` | 読み・書き | ドラッグ中のマウスカーソル |
| `DragMode` | `TDragMode` | 読み・書き | ドラッグを自動で始めるか |
| `Enabled` | `Boolean` | 読み・書き | 使えるか |
| `ExtendedSelect` | `Boolean` | 読み・書き | `MultiSelect` のとき、Shift・Ctrl で範囲を選べるか |
| `Font` | `TFont` | 読み・書き | 文字 |
| `HeaderBackgroundColor` | `TColor` | 読み・書き | 見出しの項目の背景色 |
| `HeaderColor` | `TColor` | 読み・書き | 見出しの項目の文字色 |
| `Height` | `Integer` | 読み・書き | 高さ |
| `HelpContext` | `THelpContext` | 読み・書き | ヘルプの番号 |
| `HelpKeyword` | `string` | 読み・書き | ヘルプのキーワード |
| `HelpType` | `THelpType` | 読み・書き | ヘルプを番号で引くか（`htContext`）、キーワードで引くか（`htKeyword`） |
| `Hint` | `TTranslateString` | 読み・書き | ヒントの文字 |
| `ItemHeight` | `Integer` | 読み・書き | 項目の高さ |
| `ItemIndex` | `Integer` | 読み・書き | 選択している項目の番号。チェックとは別のもの（`CheckedIndex` を変えても `ItemIndex` は変わらない） |
| `Items` | `TStrings` | 読み・書き | 項目の一覧 |
| `Left` | `Integer` | 読み・書き | 左端の位置 |
| `MultiSelect` | `Boolean` | 読み・書き | 複数の項目を選択できるか（チェックとは別のもの） |
| `Name` | `TComponentName` | 読み・書き | 部品の名前 |
| `Options` | `TListBoxOptions` | 読み・書き | 自分で描くときにフォーカスの枠を描くか（`lboDrawFocusRect`） |
| `ParentBiDiMode` | `Boolean` | 読み・書き | 親の `BiDiMode` を使うか |
| `ParentColor` | `Boolean` | 読み・書き | 親の色を使うか |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `ParentShowHint` | `Boolean` | 読み・書き | 親の `ShowHint` を使うか |
| `PopupMenu` | `TPopupMenu` | 読み・書き | 右クリックで出すメニュー |
| `ShowHint` | `Boolean` | 読み・書き | ヒントを出すか |
| `Sorted` | `Boolean` | 読み・書き | 項目を並べ替えるか |
| `Style` | `TListBoxStyle` | 読み・書き | 描き方。`lbStandard`（既定値）・`lbOwnerDrawFixed`・`lbOwnerDrawVariable`・`lbVirtual` |
| `TabOrder` | `TTabOrder` | 読み・書き | Tab キーで移る順番 |
| `TabStop` | `Boolean` | 読み・書き | Tab キーで止まるか |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値 |
| `Top` | `Integer` | 読み・書き | 上端の位置 |
| `TopIndex` | `Integer` | 読み・書き | 一番上に見えている項目の番号 |
| `Visible` | `Boolean` | 読み・書き | 表示するか |
| `Width` | `Integer` | 読み・書き | 幅 |

## 4. メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | ― | 作る。コードで作るときに使う（7.6） |
| `CheckAll` | `AState: TCheckBoxState; aAllowGrayed: Boolean = True; aAllowDisabled: Boolean = True` | ― | すべての項目を `AState` にする。`cmSingle` では、`cbChecked` なら対象になる最初の項目だけをチェックし、ほかは外す。`cbUnchecked`・`cbGrayed` なら対象の項目を外す。対象の条件は TCheckListBox と同じ。`cmMulti` では TCheckListBox と同じ |
| `Toggle` | `AIndex: Integer` | ― | その項目のチェックを切り替える。`cmSingle` では、チェックなし ⇔ チェックあり で切り替え、チェックするときはほかを外す。`cmMulti` では TCheckListBox と同じ |

- TCheckListBox のほかのメソッドはすべて使える。

## 5. イベント

### 5.1 この部品で足したもの

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnCheckedIndexChange` | `Sender: TObject` | `CheckedIndex` の値が変わった。新しい値は `CheckedIndex` で読む |

### 5.2 TCheckListBox から引き継いだもの

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnChangeBounds` | `Sender: TObject` | 位置か大きさが変わった |
| `OnClick` | `Sender: TObject` | クリックされた |
| `OnClickCheck` | `Sender: TObject` | ユーザーがチェック欄をクリックしたか、Space キーを押した。`cmSingle` で自動的に外れた項目では出ない |
| `OnContextPopup` | `Sender: TObject; MousePos: TPoint; var Handled: Boolean` | 右クリックメニューを出す直前。`Handled := True` で出さない |
| `OnDblClick` | `Sender: TObject` | ダブルクリックされた |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | ドロップされた |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | ドラッグしている物が上に来た。`Accept` で受けるかを決める |
| `OnDrawItem` | `Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState` | 項目を描くとき（`Style` が自分で描く設定のとき） |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | ドラッグが終わった |
| `OnEnter` | `Sender: TObject` | フォーカスが入った |
| `OnExit` | `Sender: TObject` | フォーカスが出た |
| `OnItemClick` | `Sender: TObject; Index: Integer` | 項目のチェック欄がクリックされた（TCheckListBox で非推奨）。`AllowNoCheck = False` で外れなかったときも出る。`OnClickCheck` を使う |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | キーが押された |
| `OnKeyPress` | `Sender: TObject; var Key: Char` | 文字のキーが押された |
| `OnKeyUp` | `Sender: TObject; var Key: Word; Shift: TShiftState` | キーが離された |
| `OnMeasureItem` | `Control: TWinControl; Index: Integer; var AHeight: Integer` | 項目の高さを決めるとき（`Style = lbOwnerDrawVariable` のとき） |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが押された |
| `OnMouseEnter` | `Sender: TObject` | マウスが上に入った |
| `OnMouseLeave` | `Sender: TObject` | マウスが外に出た |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | マウスが動いた |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが離された |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | ホイールが回された |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが手前に回された |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが奥に回された |
| `OnMouseWheelHorz` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | 横のホイールが回された |
| `OnMouseWheelLeft` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | 横のホイールが左に回された |
| `OnMouseWheelRight` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | 横のホイールが右に回された |
| `OnResize` | `Sender: TObject` | 大きさが変わった |
| `OnSelectionChange` | `Sender: TObject; User: Boolean` | 選択（`ItemIndex`）が変わった。`User` はユーザーの操作か |
| `OnShowHint` | `Sender: TObject; HintInfo: PHintInfo` | ヒントを出す直前 |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | ドラッグを始めた |
| `OnUTF8KeyPress` | `Sender: TObject; var UTF8Key: TUTF8Char` | 文字のキーが押された（UTF-8 の1文字） |

### 5.3 呼ばれる順番

| 操作（`cmSingle`） | 順番 |
|---|---|
| ユーザーが、チェックなしの項目をチェック | `OnClickCheck` → `OnCheckedIndexChange` |
| ユーザーが、チェック中の項目を外す（`AllowNoCheck = True`） | `OnClickCheck` → `OnCheckedIndexChange` |
| コードで `Checked[]`・`State[]`・`CheckedIndex`・`CheckAll`・`Toggle` を変える | `OnCheckedIndexChange` だけ |

- `OnCheckedIndexChange` の中で `CheckedIndex` を読むと、変わった後の値が返る。

### 5.4 `OnCheckedIndexChange` が出ないとき

| とき | 中身 |
|---|---|
| 値が変わらない | 同じ番号を入れた、チェック中の項目をもう一度チェックした など |
| 外せない項目をクリック | `cmSingle`・`AllowNoCheck = False` で、チェック中の項目をクリックした（`OnClickCheck` も出ない） |
| 最小より後ろの変化 | `cmMulti` で、番号が最小のチェック項目より後ろの項目だけが変わった |
| 項目の出し入れ | 項目の追加・挿入・削除・`Clear`・並べ替え（そのあとに `CheckedIndex` などを読めば、正しい値が返る） |
| 起動 | .lfm を読み込むとき |
| 方式の切り替え | `CheckMode` を変えたとき（番号が最小の項目が残るので、`CheckedIndex` は変わらない） |

## 6. 操作

| 操作（`cmSingle`） | 動作 |
|---|---|
| チェックなしの項目のチェック欄をクリック | その項目をチェックし、それまでのチェックを外す |
| チェック中の項目のチェック欄をクリック | `AllowNoCheck = True` なら外す。`False` なら何も変わらない |
| 項目を選んで Space キー | チェック欄をクリックしたのと同じ動き |
| 項目の文字の部分をクリック | 選択（`ItemIndex`）だけが動き、チェックは変わらない |

- `AllowGrayed = True` でも、`cmSingle` ではグレーにならず、チェックなし ⇔ チェックあり で切り替わる。
- 選択（`ItemIndex`）とチェックは別のもの。`CheckedIndex` を変えても `ItemIndex` は変わらず、`ItemIndex` を変えてもチェックは変わらない。

### 6.1 注意

- `Checked[]`・`State[]`・`CheckAll`・`Toggle` は、`TCCheckListBox` 型の変数から使う。`TCheckListBox` 型・`TCustomCheckListBox` 型の変数から使うと TCheckListBox の動きになり、`cmSingle` でもチェックが2つ以上になることがある。その場合も、`CheckedIndex` などは番号が最小のチェック項目を返す。

## 7. 使い方の例

### 7.1 チェック中の項目を調べる

```pascal
procedure TForm1.Button1Click(Sender: TObject);
begin
  if CCheckListBox1.HasChecked then
    ShowMessage(CCheckListBox1.CheckedText)
  else
    ShowMessage('未選択');
end;
```

### 7.2 チェックが変わったら表示を更新する

```pascal
procedure TForm1.CCheckListBox1CheckedIndexChange(Sender: TObject);
begin
  if CCheckListBox1.HasChecked then
    Label1.Caption := CCheckListBox1.CheckedText
  else
    Label1.Caption := '（なし）';
end;
```

### 7.3 コードでチェックする・外す

```pascal
CCheckListBox1.CheckedIndex := 2;    // 2 番の項目だけをチェック
CCheckListBox1.CheckedIndex := -1;   // すべて外す
```

### 7.4 項目にデータを持たせて、チェック中のデータを取り出す

```pascal
type
  TColorItem = class
    Value: TColor;
    constructor Create(AValue: TColor);
  end;

constructor TColorItem.Create(AValue: TColor);
begin
  Value := AValue;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  CCheckListBox1.CheckMode := cmSingle;
  CCheckListBox1.AllowNoCheck := False;
  CCheckListBox1.Items.AddObject('赤', TColorItem.Create(clRed));
  CCheckListBox1.Items.AddObject('緑', TColorItem.Create(clGreen));
  CCheckListBox1.Items.AddObject('青', TColorItem.Create(clBlue));
  CCheckListBox1.CheckedIndex := 0;   // 最初の1つはアプリで決める
end;

procedure TForm1.CCheckListBox1CheckedIndexChange(Sender: TObject);
var
  Obj: TObject;
begin
  Obj := CCheckListBox1.CheckedObject;   // チェックがなければ nil
  if Obj <> nil then
    Shape1.Brush.Color := TColorItem(Obj).Value;
end;

procedure TForm1.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  // Items.Objects に入れたものは、アプリで解放する
  for i := 0 to CCheckListBox1.Items.Count - 1 do
    CCheckListBox1.Items.Objects[i].Free;
end;
```

### 7.5 複数チェックのとき、チェック中の項目をすべて取り出す

```pascal
procedure TForm1.Button2Click(Sender: TObject);
var
  i: Integer;
begin
  Memo1.Clear;
  Memo1.Lines.Add('チェックの数：' + IntToStr(CCheckListBox1.CheckedCount));
  for i := 0 to CCheckListBox1.Items.Count - 1 do
    if CCheckListBox1.Checked[i] then
      Memo1.Lines.Add(CCheckListBox1.Items[i]);
end;
```

### 7.6 コードで作る

```pascal
uses
  CCheckListBox;

procedure TForm1.Button3Click(Sender: TObject);
var
  L: TCCheckListBox;
begin
  L := TCCheckListBox.Create(Self);
  L.Parent := Self;
  L.SetBounds(16, 16, 200, 120);
  L.CheckMode := cmSingle;
  L.Items.Add('小');
  L.Items.Add('中');
  L.Items.Add('大');
  L.CheckedIndex := 1;
  L.OnCheckedIndexChange := @CCheckListBox1CheckedIndexChange;
end;
```
