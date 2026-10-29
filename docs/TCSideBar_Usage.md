# TCSideBar 取扱説明書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 概要とクラス

Microsoft Edge のサイドバーのような「アイコン列＋開閉するパネル＋スプリッター」を、1つにまとめた部品です。

```
+------+-----------------------+--+------------------------------+
| [A]  | ページ A の見出し   [×] |  |                              |
| [B]  +-----------------------+ ┃|   アプリの本体                 |
| [C]  | ページ A の中身         | ┃|   （Align = alClient で置く）  |
|      | （Button、ListBox など） |  |                              |
+------+-----------------------+--+------------------------------+
 アイコン列   パネル（開いているページ）  スプリッター
```

- 左端のアイコンを押すと、対応するページが開く。もう一度押すと閉じる。
- ページの中身（Button、ListBox など）は、フォームデザイナでページの上に自由に置ける。
- スプリッターをドラッグすると、パネルの幅を変えられる。
- サイドバーの幅は、開閉に合わせて自動で変わる。右側に `Align = alClient` で置いた部品が、自動で伸び縮みする。
- 見出しを消して（`ShowHeader = False`）、ページごとに自分で見出しを作ることもできる（8.4）。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCSideBar` | `uCSideBar` | cx | `TCustomControl` | Edge のようなサイドバー（アイコン列＋開閉するパネル＋スプリッター） |
| `TCSideBarPage` | `uCSideBar` | cx | `TCustomControl` | サイドバーの1ページ。この上にボタンなどを置く。`TCSideBar` の上にだけ置ける |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCSideBarPageEvent` | `uCSideBar` | `procedure(Sender: TObject; Index: Integer) of object`。`OnPageOpen`・`OnPageClose` の型 |
| `TCSideBarChangingEvent` | `uCSideBar` | `procedure(Sender: TObject; Index: Integer; var Allow: Boolean) of object`。`OnPageChanging` の型 |

- フォームに置くと、uses に `uCSideBar` が自動で入る。
- フォームに置くと、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCSideBar をフォームに置く。左端に置かれる（`Align = alLeft`）。
2. フォームの残りの場所に、本体にする部品（TMemo など）を置き、`Align` を `alClient` にする。
3. TImageList をフォームに置き、アイコンにする画像を入れる。TCSideBar の `Images` に、その TImageList を設定する。
4. TCSideBar を右クリックし、「ページの追加」を選ぶ。ページが末尾に追加され、開いた状態になる。
5. オブジェクトインスペクタで、ページの `Caption`（見出し）と `ImageIndex`（アイコンの番号）を設定する。
6. 開いたページの上に、ボタンなどの部品を置く。
7. 4～6 をページの数だけ繰り返す。
8. ページを開いたときに処理をするときは、TCSideBar のイベントタブの `OnPageOpen` をダブルクリックして処理を書く。
9. 実行する。アイコンを押すとページが開き、もう一度押すと閉じる。

- フォームデザイナでアイコンを押すと、そのページを開いて編集できる。
- ページの順番は、右クリックの「上へ移動」「下へ移動」で変える。
- 設計時に開いていたページが、起動したときにも開く。閉じた状態で起動するときは、設計時にアイコンを押して閉じておくか、`ActivePage` を空にする。

## 3. TCSideBar

### 3.1 プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `ActivePage` | `TCSideBarPage` | 読み・書き | 開いているページ。nil なら閉じた状態。書くと開閉する |
| `ActivePageIndex` | `Integer` | 読み・書き | 開いているページの番号（閉じているときは -1）。書くと開閉する。範囲外の値は無視する。実行時だけ |
| `Pages[Index]` | `TCSideBarPage` | 読み | ページ。実行時だけ |
| `PageCount` | `Integer` | 読み | ページの数。`PageVisible = False` のページも数える。実行時だけ |
| `Images` | `TCustomImageList` | 読み・書き | アイコンの画像を持つイメージリスト |
| `ImagesWidth` | `Integer` | 読み・書き | アイコンを描く幅（表示スケール 100% のときの px）。0（既定値）なら `Images` の `Width` |
| `IconBarWidth` | `Integer` | 読み・書き | アイコン列の幅（既定値は 40）。アイコン1つの枠は、この幅の正方形 |
| `MinPanelWidth` | `Integer` | 読み・書き | スプリッターで変えられるパネルの幅の下限（既定値は 150） |
| `MaxPanelWidth` | `Integer` | 読み・書き | スプリッターで変えられるパネルの幅の上限（既定値は 600）。0 なら上限なし |
| `SplitterWidth` | `Integer` | 読み・書き | スプリッター（つかむ部分）の幅（既定値は 8） |
| `ResizeStyle` | `TResizeStyle` | 読み・書き | スプリッターをドラッグしている間の表示。`rsLine`（既定値）・`rsPattern`：線だけを動かし、離したときに幅を変える。`rsUpdate`：ドラッグ中も幅を変える。`rsNone`：何も表示せず、離したときに幅を変える |
| `ShowHeader` | `Boolean` | 読み・書き | 見出し（`Caption` と［×］）を出すか（既定値は `True`）。`False` で、ページがパネルの一番上から始まる |
| `ShowCloseButton` | `Boolean` | 読み・書き | 見出しの右に［×］を出すか（既定値は `True`）。`ShowHeader = False` のときは出ない |
| `IconPopupMenu` | `TPopupMenu` | 読み・書き | アイコン列を右クリックしたときに出すメニュー |
| `Align` | `TAlign` | 読み・書き | 親の中での配置（既定値は `alLeft`） |
| `Anchors` | `TAnchors` | 読み・書き | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `AnchorSideBottom` | `TAnchorSide` | 読み・書き | 下の辺を、どの部品のどこに合わせるか |
| `AnchorSideLeft` | `TAnchorSide` | 読み・書き | 左の辺を、どの部品のどこに合わせるか |
| `AnchorSideRight` | `TAnchorSide` | 読み・書き | 右の辺を、どの部品のどこに合わせるか |
| `AnchorSideTop` | `TAnchorSide` | 読み・書き | 上の辺を、どの部品のどこに合わせるか |
| `BorderSpacing` | `TControlBorderSpacing` | 読み・書き | 周りの余白 |
| `Constraints` | `TSizeConstraints` | 読み・書き | 大きさの上限・下限 |
| `Cursor` | `TCursor` | 読み・書き | 上に来たときのマウスカーソル |
| `Enabled` | `Boolean` | 読み・書き | 使えるか。`False` で、アイコン・［×］・スプリッター・ショートカットキーが動かなくなる |
| `Font` | `TFont` | 読み・書き | 見出しの文字 |
| `Height` | `Integer` | 読み・書き | 高さ |
| `HelpContext` | `THelpContext` | 読み・書き | ヘルプの番号 |
| `HelpKeyword` | `string` | 読み・書き | ヘルプのキーワード |
| `HelpType` | `THelpType` | 読み・書き | ヘルプを番号で引くか（`htContext`）、キーワードで引くか（`htKeyword`） |
| `Hint` | `TTranslateString` | 読み・書き | ヒントの文字 |
| `Left` | `Integer` | 読み・書き | 左端の位置 |
| `Name` | `TComponentName` | 読み・書き | 部品の名前 |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `ParentShowHint` | `Boolean` | 読み・書き | 親の `ShowHint` を使うか |
| `ShowHint` | `Boolean` | 読み・書き | `True` で、アイコンの上でページの `Caption` をヒントに出す |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値 |
| `Top` | `Integer` | 読み・書き | 上端の位置 |
| `Visible` | `Boolean` | 読み・書き | 表示するか |

- 番号（`Index`）は、`PageVisible = False` のページも含めた順番。
- 幅はサイドバーが自分で決める。閉じているときは `IconBarWidth`、開いているときは `IconBarWidth` ＋ そのページの `PanelWidth` ＋ `SplitterWidth`。
- 実行中に読み書きする幅（`IconBarWidth`・`PanelWidth`・`MinPanelWidth`・`MaxPanelWidth`・`SplitterWidth`）は、表示スケールで拡大した後の値。`ImagesWidth` は 100% のときの値のまま。

### 3.2 メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | ― | 作る。コードで作るときに使う（8.7） |
| `OpenPage` | `Index: Integer` | ― | そのページを開く。別のページが開いていれば切り替える。範囲外なら例外（`EListError`）。`PageVisible = False`・`Enabled = False` のページは開かない |
| `ClosePage` | ― | ― | 開いているページを閉じる |
| `MovePage` | `CurIndex, NewIndex: Integer` | ― | ページの順番を変える。範囲外・同じ番号なら何もしない。イベントは出さない |

### 3.3 イベント

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnPageChanging` | `Sender: TObject; Index: Integer; var Allow: Boolean` | 開く・切り替える・閉じる前。`Index` はこれから開くページの番号（閉じるときは -1）。`Allow := False` で取りやめる |
| `OnPageOpen` | `Sender: TObject; Index: Integer` | ページを開いた後。`Index` は開いたページの番号 |
| `OnPageClose` | `Sender: TObject; Index: Integer` | ページを閉じた後。`Index` は閉じたページの番号 |
| `OnPanelResize` | `Sender: TObject` | スプリッターのドラッグを終えて、幅が変わった後。新しい幅は `ActivePage.PanelWidth` で読む |

### 3.4 呼ばれる順番

| 操作 | 順番 |
|---|---|
| 閉じた状態から A を開く | `OnPageChanging`(A) → `OnPageOpen`(A) |
| A から B に切り替える | `OnPageChanging`(B) → `OnPageClose`(A) → `OnPageOpen`(B) |
| A を閉じる | `OnPageChanging`(-1) → `OnPageClose`(A) |

- アイコン・［×］・ショートカットキー・コード（`OpenPage`・`ClosePage`・`ActivePage`・`ActivePageIndex`）のどれで開閉しても、同じ順番で出る。
- `OnPageChanging` で `Allow := False` にすると、何も変わらず、後のイベントも出ない。

### 3.5 イベントが出ないとき

| とき | 中身 |
|---|---|
| 起動 | .lfm を読み込んで、設計時に開いていたページを開くとき |
| 設計時 | フォームデザイナでの操作 |
| 状態が変わらない | 開いているページを `OpenPage` する、閉じているときに `ClosePage` する |
| ページが消えた | 開いているページの `PageVisible` を `False` にした、そのページを削除したことで閉じたとき |

## 4. TCSideBarPage

### 4.1 プロパティ

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Caption` | `TCaption` | 読み・書き | 見出しの文字。アイコンのヒントにも使う。設計時に追加したページには `Name` と同じ文字が入る |
| `ImageIndex` | `TImageIndex` | 読み・書き | `Images` の中のアイコンの番号。-1（既定値）ならアイコンを描かない（枠は残り、押せる） |
| `PanelWidth` | `Integer` | 読み・書き | このページを開いたときのパネルの幅（既定値は 250）。スプリッターをドラッグすると変わる |
| `PageVisible` | `Boolean` | 読み・書き | `False` でアイコンが消え、下のアイコンが詰まる。そのページは開けない（設計時はアイコンを出したまま） |
| `Enabled` | `Boolean` | 読み・書き | `False` でアイコンが灰色になり、押せない |
| `ShortCut` | `TShortCut` | 読み・書き | 押すと、アイコンを押したのと同じ動きになるキー（既定値は 0：なし） |
| `SideBar` | `TCSideBar` | 読み | このページが入っているサイドバー。実行時だけ |
| `Color` | `TColor` | 読み・書き | ページの背景色（既定値は `clBtnFace`） |
| `Font` | `TFont` | 読み・書き | ページの上の部品が使う文字 |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `PopupMenu` | `TPopupMenu` | 読み・書き | ページの上を右クリックしたときに出すメニュー |
| `ShowHint` | `Boolean` | 読み・書き | ヒントを出すか |
| `ParentShowHint` | `Boolean` | 読み・書き | 親の `ShowHint` を使うか |
| `Cursor` | `TCursor` | 読み・書き | 上に来たときのマウスカーソル |
| `HelpContext` | `THelpContext` | 読み・書き | ヘルプの番号 |
| `HelpKeyword` | `string` | 読み・書き | ヘルプのキーワード |
| `HelpType` | `THelpType` | 読み・書き | ヘルプを番号で引くか（`htContext`）、キーワードで引くか（`htKeyword`） |
| `Hint` | `TTranslateString` | 読み・書き | ヒントの文字 |
| `Name` | `TComponentName` | 読み・書き | 部品の名前 |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値 |

### 4.2 メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `TheOwner: TComponent` | ― | 作る。`Parent` に TCSideBar を入れると、そのサイドバーの末尾のページになる（8.7）。TCSideBar 以外を `Parent` にすると例外（`EInvalidOperation`） |

### 4.3 イベント

TCSideBarPage には、イベントはない。開閉は TCSideBar のイベント（3.3）で知る。

## 5. 操作

### 5.1 実行時

| 操作 | 動作 |
|---|---|
| 閉じているページのアイコンをクリック | そのページを開く（開いているページがあれば切り替える） |
| 開いているページのアイコンをクリック | 閉じる |
| ［×］をクリック | 閉じる（`ShowHeader = True`、`ShowCloseButton = True` のとき） |
| アイコンの上にマウスを置く | アイコンを強調表示する。`ShowHint = True` なら `Caption` をヒントに出す |
| アイコン列を右クリック | `IconPopupMenu` を出す（ページの開閉はしない） |
| スプリッターをドラッグ | パネルの幅を `MinPanelWidth` ～ `MaxPanelWidth` の範囲で変える |
| ページの `ShortCut` のキーを押す | そのページのアイコンをクリックしたのと同じ動き |

- ドラッグ中の線は別のウィンドウとして描かれるため、WebView2 を使う部品の上にも表示される。
- ドラッグ中に別のウィンドウへ切り替えた（Alt+Tab など）ときは、ドラッグを取りやめ、幅を元に戻す。

### 5.2 設計時（フォームデザイナ）

| 操作 | 動作 |
|---|---|
| アイコンをクリック | そのページを開く（開いているページなら閉じる）。開いたページが選ばれた状態になる |
| スプリッターをドラッグ | 開いているページの `PanelWidth` を変える |
| 右クリック →「ページの追加」 | ページを末尾に追加して開く |
| 右クリック →「ページの削除」 | 開いているページを削除する |
| 右クリック →「上へ移動」「下へ移動」 | 開いているページの順番を変える |

- 開いているページの上に、部品を置ける。`ShowHeader = False` のときは、パネルの一番上まで置ける。
- `PageVisible = False` のページも、設計時はアイコンが出て、開いて編集できる。
- 開いているページの `PageVisible` を `False` にしたとき、またはそのページを削除したときは、閉じた状態になる（イベントは出ない）。

## 6. ショートカットキー

ページの `ShortCut` は、フォームのほかの部品が使わなかったキーだけを受け取る。キーは次の順番で届き、先の処理で使われたキーはサイドバーに届かない。

| 順番 | 処理 |
|---|---|
| 1 | フォームの `OnKeyDown`（`KeyPreview = True` のとき）。`Key := 0` にすると、2 以降には届かない |
| 2 | フォーカスのある部品の `OnKeyDown` |
| 3 | メニュー・ActionList のショートカット |
| 4 | フォーカスのある部品が自分で使うキー（ComboBox の F4、Edit の Ctrl+A など） |
| 5 | TCSideBar のショートカット |

- サイドバーと同じフォームの中のキーだけが対象。サイドバーが `Enabled` かつ表示されているときだけ動く。
- WebView2 を使う部品にフォーカスがあるときは、キーがアプリに届かないため動かない。

## 7. 表示

### 7.1 色（ダーク／ライト）

システム色だけで描く。ダーク／ライトの切り替えは、アプリ側の MetaDarkStyle などに任せる。

| 部分 | 色 |
|---|---|
| アイコン列・見出しの背景 | `clBtnFace` |
| ページの背景 | `clBtnFace`（ページの `Color` で変えられる） |
| 見出しの文字 | `clBtnText` |
| マウスを置いたアイコン | `clBtnHighlight` の角丸 |
| 開いているページのアイコン | `clHighlight` の枠の角丸 |
| `Enabled = False` のアイコン | 灰色 |
| スプリッター | `clBtnShadow` の縦線 |

### 7.2 表示スケール（高 DPI）

Windows の表示スケール（125%、150% など）に合わせて、`IconBarWidth`・`PanelWidth`・`MinPanelWidth`・`MaxPanelWidth`・`SplitterWidth`、見出しの高さ、［×］の大きさを自動で拡大する（フォームの `Scaled = True` のとき）。

- アイコンを拡大するには、TImageList の `Scaled` を `True` にし、大きさ違いの画像を用意する。ちょうどの大きさの画像がないとき、125% 以下では 100% の画像がそのまま使われる（LCL の決まり）。
## 8. 使い方の例

### 8.1 ページを開いたときに、見出しをフォームのタイトルに出す

```pascal
procedure TForm1.CSideBar1PageOpen(Sender: TObject; Index: Integer);
begin
  Caption := CSideBar1.Pages[Index].Caption;
end;
```

### 8.2 保存していないデータがあるときは、ページを閉じさせない

```pascal
procedure TForm1.CSideBar1PageChanging(Sender: TObject; Index: Integer;
  var Allow: Boolean);
begin
  if (Index = -1) and FModified then
    Allow := False;
end;
```

### 8.3 コードで開く・閉じる

```pascal
CSideBar1.OpenPage(0);           // 先頭のページを開く
CSideBar1.ClosePage;             // 開いているページを閉じる
CSideBar1.ActivePage := PageFind;   // ページを名前で指定して開く
```

### 8.4 ページごとに見出しを作る（ShowHeader = False）

1. TCSideBar の `ShowHeader` を `False` にする。
2. ページを開き、その上に TPanel を置いて `Align` を `alTop` にする。
3. TPanel の上に、ラベルと閉じるボタンを置く。
4. 閉じるボタンの `OnClick` に、次の処理を書く。

```pascal
procedure TForm1.PageACloseButtonClick(Sender: TObject);
begin
  CSideBar1.ClosePage;
end;
```

### 8.5 パネルの幅と開いているページを保存して、次に起動したときに戻す

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
    Ini.WriteInteger('SideBar', 'Active', CSideBar1.ActivePageIndex);
    for i := 0 to CSideBar1.PageCount - 1 do
      Ini.WriteInteger('SideBar', 'Width' + IntToStr(i), CSideBar1.Pages[i].PanelWidth);
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
    for i := 0 to CSideBar1.PageCount - 1 do
      CSideBar1.Pages[i].PanelWidth :=
        Ini.ReadInteger('SideBar', 'Width' + IntToStr(i), CSideBar1.Pages[i].PanelWidth);
    CSideBar1.ActivePageIndex := Ini.ReadInteger('SideBar', 'Active', -1);
  finally
    Ini.Free;
  end;
end;
```

- 保存する幅は、表示スケールで拡大した後の値。表示スケールを変えて起動すると、幅の見え方が変わる。

### 8.6 ショートカットキーでページを開閉する

```pascal
uses
  LCLType,   // VK_F1 など
  Menus;     // ShortCut 関数

procedure TForm1.FormCreate(Sender: TObject);
begin
  CSideBar1.Pages[0].ShortCut := ShortCut(VK_F1, [ssCtrl]);   // Ctrl+F1 で先頭のページ
  CSideBar1.Pages[1].ShortCut := ShortCut(VK_F2, [ssCtrl]);   // Ctrl+F2 で2つ目のページ
end;
```

- メニュー・ActionList と同じキーにすると、そちらが動く。重ならないキーを選ぶ。
- フォーカスのある部品が使うキー、WebView2 を使う部品にフォーカスがあるときのキーは、サイドバーに届かない。

### 8.7 コードで作る

```pascal
uses
  uCSideBar;

procedure TForm1.FormCreate(Sender: TObject);
var
  SB: TCSideBar;
  P: TCSideBarPage;
  L: TListBox;
begin
  SB := TCSideBar.Create(Self);
  SB.Parent := Self;                  // 左端に置かれる（Align = alLeft）
  SB.Images := ImageList1;
  SB.OnPageOpen := @CSideBar1PageOpen;   // 8.1 の処理を使う

  P := TCSideBarPage.Create(Self);
  P.Caption := '履歴';
  P.ImageIndex := 0;
  P.Parent := SB;                     // サイドバーの末尾のページになる

  L := TListBox.Create(Self);
  L.Parent := P;                      // ページの上に置く
  L.Align := alClient;

  Memo1.Align := alClient;            // 本体は残りの場所いっぱいに広げる
end;
```

### 8.8 ページを隠す・使えなくする

```pascal
CSideBar1.Pages[2].PageVisible := False;   // アイコンを消す（下のアイコンが詰まる）
CSideBar1.Pages[3].Enabled := False;       // アイコンを灰色にして、押せなくする
```
