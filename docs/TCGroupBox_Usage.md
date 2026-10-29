# TCGroupBox 取扱説明書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 概要とクラス

TGroupBox と同じ見た目・使い方のグループボックスです。標準の TGroupBox では、中に置いた部品が消えることがありますが、この部品では起きません。

| 部品 | 役割 |
|---|---|
| TCGroupBox | 見出し付きの枠。TGroupBox と同じ名前のプロパティ・イベントで使える |
| TCCheckGroupBox | 見出しにチェックボックスが付いた TCGroupBox。チェックを外すと、中の部品がすべて無効になり、チェックを付けると元に戻る |

- 表示は Windows のテーマで描かれ、TGroupBox と同じ見た目になる。MetaDarkStyle のダーク表示にも合わせて変わる。
- テーマが使えない Windows では、枠は 1px の灰色の線で描かれる。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス |
|---|---|---|---|
| `TCGroupBox` | `uCGroupBox` | cx | `TCustomPanel` |
| `TCCheckGroupBox` | `uCCheckGroupBox` | cx | `TCGroupBox` |

- フォームに置くと、uses に `uCGroupBox`（TCCheckGroupBox なら `uCCheckGroupBox`）が自動で入り、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

### 1.2 TGroupBox との違い

| 項目 | TGroupBox | TCGroupBox |
|---|---|---|
| 描画 | Windows のネイティブ部品が描く | 部品が自分で描く（Windows のテーマの部品を使う） |
| 中の部品が消える不具合 | 起きることがある | 起きない |
| 見た目 | Windows のテーマ | 同じ |
| ダーク表示（MetaDarkStyle） | 追従する | 追従する |
| チェック付きの見出し | なし | TCCheckGroupBox で使える |

## 2. フォームに置いて動かすまで

### 2.1 TCGroupBox

1. パレット [CX] から TCGroupBox をフォームに置く。
2. オブジェクトインスペクタで `Caption` に見出しの文字を入れる。
3. TCGroupBox の上に、TEdit・TButton などの部品を置く。
4. 実行する。

### 2.2 TCCheckGroupBox

1. パレット [CX] から TCCheckGroupBox をフォームに置く。
2. オブジェクトインスペクタで `Caption` に見出しの文字を入れる。
3. TCCheckGroupBox の上に、部品を置く。
4. 最初にチェックを外しておくときは、`Checked` を `False` にする。
5. チェックの切り替えで処理をするときは、イベントタブの `OnChange` をダブルクリックして処理を書く。
6. 実行する。チェックを外すと中の部品が無効（灰色）になり、付けると元に戻る。アプリがコードを書く必要はない。

### 2.3 設計時（Lazarus IDE）の動き

- 設計時は、`Checked` を `False` にしても中の部品は無効にならない（チェックボックスの表示だけが変わる）。実行すると無効になる。
- 見出しのチェックボックスは、設計時に選んだり動かしたりできない。押すと TCCheckGroupBox が選ばれる。
- 見出しのチェックボックスは .lfm に保存されない。

## 3. TCGroupBox

### 3.1 プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Align` | `TAlign` | 読み・書き | 親の中での配置 |
| `Anchors` | `TAnchors` | 読み・書き | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `AnchorSideBottom` | `TAnchorSide` | 読み・書き | 下の辺を、どの部品のどこに合わせるか |
| `AnchorSideLeft` | `TAnchorSide` | 読み・書き | 左の辺を、どの部品のどこに合わせるか |
| `AnchorSideRight` | `TAnchorSide` | 読み・書き | 右の辺を、どの部品のどこに合わせるか |
| `AnchorSideTop` | `TAnchorSide` | 読み・書き | 上の辺を、どの部品のどこに合わせるか |
| `AutoSize` | `Boolean` | 読み・書き | 中の部品に合わせて大きさを変えるか |
| `BiDiMode` | `TBiDiMode` | 読み・書き | `bdRightToLeft` で見出しが右寄せになる |
| `BorderSpacing` | `TControlBorderSpacing` | 読み・書き | 周りの余白 |
| `Caption` | `TCaption` | 読み・書き | 見出しの文字。置いたときは部品の名前が入る。空のときは枠の上辺が切れずにつながる。空にしても中の部品の位置は動かない |
| `ChildSizing` | `TControlChildSizing` | 読み・書き | 中の部品の並べ方（TGroupBox と同じ） |
| `ClientHeight` | `Integer` | 読み・書き | 内側の高さ |
| `ClientWidth` | `Integer` | 読み・書き | 内側の幅 |
| `Color` | `TColor` | 読み・書き | 背景色 |
| `Constraints` | `TSizeConstraints` | 読み・書き | 大きさの上限・下限 |
| `Cursor` | `TCursor` | 読み・書き | 上に来たときのマウスカーソル |
| `DockSite` | `Boolean` | 読み・書き | ほかの部品をドッキングさせるか |
| `DoubleBuffered` | `Boolean` | 読み・書き | ちらつきを抑える描き方にするか |
| `DragCursor` | `TCursor` | 読み・書き | ドラッグ中のマウスカーソル |
| `DragKind` | `TDragKind` | 読み・書き | ドラッグの種類（ドラッグ＆ドロップか、ドッキングか） |
| `DragMode` | `TDragMode` | 読み・書き | ドラッグを自動で始めるか |
| `Enabled` | `Boolean` | 読み・書き | 使えるか。`False` で見出しが灰色になる |
| `Font` | `TFont` | 読み・書き | 見出しの文字。`Font.Color` が `clDefault` ならテーマの色（ダーク表示ではダークの色）で描く |
| `Height` | `Integer` | 読み・書き | 高さ |
| `HelpContext` | `THelpContext` | 読み・書き | ヘルプの番号 |
| `HelpKeyword` | `string` | 読み・書き | ヘルプのキーワード |
| `HelpType` | `THelpType` | 読み・書き | ヘルプを番号で引くか（`htContext`）、キーワードで引くか（`htKeyword`） |
| `Hint` | `TTranslateString` | 読み・書き | ヒントの文字 |
| `Left` | `Integer` | 読み・書き | 左端の位置 |
| `Name` | `TComponentName` | 読み・書き | 部品の名前 |
| `ParentBackground` | `Boolean` | 読み・書き | 親の背景を使うか |
| `ParentBiDiMode` | `Boolean` | 読み・書き | 親の `BiDiMode` を使うか |
| `ParentColor` | `Boolean` | 読み・書き | 親の色を使うか（既定値は `True`） |
| `ParentDoubleBuffered` | `Boolean` | 読み・書き | 親の `DoubleBuffered` を使うか |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `ParentShowHint` | `Boolean` | 読み・書き | 親の `ShowHint` を使うか |
| `PopupMenu` | `TPopupMenu` | 読み・書き | 右クリックで出すメニュー |
| `ShowHint` | `Boolean` | 読み・書き | ヒントを出すか |
| `TabOrder` | `TTabOrder` | 読み・書き | Tab キーで移る順番 |
| `TabStop` | `Boolean` | 読み・書き | Tab キーで止まるか |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値 |
| `Top` | `Integer` | 読み・書き | 上端の位置 |
| `Visible` | `Boolean` | 読み・書き | 表示するか |
| `Width` | `Integer` | 読み・書き | 幅 |

- 中の部品を置ける範囲は、見出しの下と枠の内側。`Align = alClient` の部品は、見出しの下から枠の内側いっぱいに広がる。
- 置いたときの大きさは、幅 185 × 高さ 105（TGroupBox と同じ）。

### 3.2 メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | ― | 作る。コードで作るときに使う（6.4） |

### 3.3 イベント

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnChangeBounds` | `Sender: TObject` | 位置か大きさが変わった |
| `OnClick` | `Sender: TObject` | クリックされた |
| `OnContextPopup` | `Sender: TObject; MousePos: TPoint; var Handled: Boolean` | 右クリックメニューを出す直前。`Handled := True` で出さない |
| `OnDblClick` | `Sender: TObject` | ダブルクリックされた |
| `OnDockDrop` | `Sender: TObject; Source: TDragDockObject; X, Y: Integer` | ドッキングされた |
| `OnDockOver` | `Sender: TObject; Source: TDragDockObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | ドッキングする部品が上に来た。`Accept` で受けるかを決める |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | ドロップされた |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | ドラッグしている物が上に来た。`Accept` で受けるかを決める |
| `OnEndDock` | `Sender, Target: TObject; X, Y: Integer` | ドッキングが終わった |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | ドラッグが終わった |
| `OnEnter` | `Sender: TObject` | フォーカスが入った |
| `OnExit` | `Sender: TObject` | フォーカスが出た |
| `OnGetSiteInfo` | `Sender: TObject; DockClient: TControl; var InfluenceRect: TRect; MousePos: TPoint; var CanDock: Boolean` | ドッキングできる範囲を決めるとき |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | キーが押された |
| `OnKeyPress` | `Sender: TObject; var Key: Char` | 文字のキーが押された |
| `OnKeyUp` | `Sender: TObject; var Key: Word; Shift: TShiftState` | キーが離された |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが押された |
| `OnMouseEnter` | `Sender: TObject` | マウスが上に入った |
| `OnMouseLeave` | `Sender: TObject` | マウスが外に出た |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | マウスが動いた |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが離された |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | ホイールが回された |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが手前に回された |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが奥に回された |
| `OnResize` | `Sender: TObject` | 大きさが変わった |
| `OnStartDock` | `Sender: TObject; var DragObject: TDragDockObject` | ドッキングのドラッグを始めた |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | ドラッグを始めた |
| `OnUnDock` | `Sender: TObject; Client: TControl; NewTarget: TWinControl; var Allow: Boolean` | ドッキングした部品が外れる前。`Allow` で外すかを決める |
| `OnUTF8KeyPress` | `Sender: TObject; var UTF8Key: TUTF8Char` | 文字のキーが押された（UTF-8 の1文字） |

## 4. TCCheckGroupBox

TCGroupBox のプロパティ・メソッド・イベント（3章）をすべて持ち、次が加わる。

### 4.1 プロパティ

| 名前 | 型 | 読み書き | 既定値 | 中身 |
|---|---|---|---|---|
| `Checked` | `Boolean` | 読み・書き | `True` | 見出しのチェック。`False` で中の部品がすべて無効になり、`True` で元に戻る |

### 4.2 メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | ― | 作る。見出しのチェックボックスも一緒に作る |

### 4.3 イベント

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnChange` | `Sender: TObject` | `Checked` が変わった後。チェックボックス・見出しの文字・Space キー・コードのどれで変えても出る。同じ値を入れたとき、フォームを読み込むときは出ない |

### 4.4 中の部品の有効・無効

| 状態 | 中の部品 | チェックボックス |
|---|---|---|
| `Enabled = True`、`Checked = True` | それぞれ元の `Enabled` | 有効 |
| `Enabled = True`、`Checked = False` | すべて無効 | 有効 |
| `Enabled = False` | すべて無効 | 無効 |

- 「元の `Enabled`」は、無効にする直前の値。もともと無効だった部品は、元に戻しても無効のまま。
- チェックを外している間に、アプリが中の部品の `Enabled` を変えても、チェックを付けたときに、チェックを外す前の値に戻る。
- 中のパネルなど、ほかの部品を置ける部品の中の部品も、同じように無効になり、元に戻る。
- チェックを外している間に、中のパネルなどのさらに中へ追加した部品は、無効にならない（TCCheckGroupBox の直下に追加した部品は無効になる）。
- ほかの部品を置けない部品（複合部品）は、その部品の `Enabled` だけが変わる。
- TCCheckGroupBox の中に TCCheckGroupBox を置いたときは、内側の部品は内側の TCCheckGroupBox のチェックにも従う。外側のチェックを付け直しても、内側のチェックが外れていれば、内側の部品は無効のまま。

## 5. 操作（アプリを使う人の操作）

**TCCheckGroupBox**

| 操作 | 動作 |
|---|---|
| チェックボックスを押す | チェックが切り替わる |
| 見出しの文字を押す | チェックが切り替わり、チェックボックスにフォーカスが入る |
| Tab キー | チェックボックスにフォーカスが入る。見出しの文字の周りに点線の枠が出る |
| Space キー（フォーカスがあるとき） | チェックが切り替わる |

- チェックを外しても、チェックボックス自体は押せる（押して元に戻せる）。
- TCCheckGroupBox の `Enabled` が `False` のときは、チェックボックスも見出しの文字も押せない。

### 5.1 よく使う設定

| したいこと | 設定 |
|---|---|
| 見出しの文字を変える | `Caption` に入れる |
| 見出しの文字の色を変える | `Font.Color` を変える。`clDefault` のときはテーマの色（ダーク表示ではダークの色）になる |
| 背景色を変える | `Color` を変える |
| 中の部品を並べて配置する | `ChildSizing` を使う（TGroupBox と同じ） |
| 最初はチェックを外しておく（TCCheckGroupBox） | `Checked` を `False` にする |
| チェックの切り替えを知る（TCCheckGroupBox） | `OnChange` を使う |
| 見出しを右に寄せる | `BiDiMode` を `bdRightToLeft` にする |

## 6. 使い方の例

### 6.1 チェックの切り替えで処理をする

```pascal
procedure TForm1.CCheckGroupBox1Change(Sender: TObject);
begin
  if CCheckGroupBox1.Checked then
    StatusBar1.SimpleText := 'プロキシを使う'
  else
    StatusBar1.SimpleText := 'プロキシを使わない';
end;
```

### 6.2 コードでチェックを切り替える

```pascal
CCheckGroupBox1.Checked := False;   // 中の部品が無効になる。OnChange が出る
CCheckGroupBox1.Checked := True;    // 中の部品が元の状態に戻る。OnChange が出る
```

### 6.3 設定ファイルにチェックを保存して、次に起動したときに戻す

```pascal
uses
  IniFiles;

procedure TForm1.FormCreate(Sender: TObject);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini'));
  try
    CCheckGroupBox1.Checked := Ini.ReadBool('Proxy', 'Use', False);
  finally
    Ini.Free;
  end;
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ChangeFileExt(Application.ExeName, '.ini'));
  try
    Ini.WriteBool('Proxy', 'Use', CCheckGroupBox1.Checked);
  finally
    Ini.Free;
  end;
end;
```

### 6.4 コードで作る

```pascal
uses
  uCGroupBox, uCCheckGroupBox;

procedure TForm1.Button1Click(Sender: TObject);
var
  G: TCCheckGroupBox;
  E: TEdit;
begin
  G := TCCheckGroupBox.Create(Self);
  G.Parent := Self;
  G.SetBounds(16, 16, 240, 80);
  G.Caption := 'プロキシ';
  G.OnChange := @CCheckGroupBox1Change;   // 6.1 の処理を使う

  E := TEdit.Create(Self);
  E.Parent := G;                          // TCCheckGroupBox の中に置く
  E.SetBounds(8, 8, 200, 23);
end;
```

### 6.5 中の部品をいつも無効にしておく

```pascal
// 中の Edit2 を、チェックに関係なく無効にしておく
Edit2.Enabled := False;
// チェックを外して付け直しても、Edit2 は無効のまま
```

### 6.6 今ある TGroupBox を TCGroupBox に置き換える

1. Lazarus でフォームを閉じる。
2. .lfm の `TGroupBox` を `TCGroupBox` に、.pas の `TGroupBox` を `TCGroupBox` に書き換える。
3. .pas の uses に `uCGroupBox` を足す。
4. フォームを開き直す。

プロパティ・イベントは TGroupBox と同じ名前なので、そのまま引き継がれる。
