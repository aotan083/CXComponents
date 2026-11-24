# TCTabBar 取扱説明書

作者: aotan083
日付: 2026-11-24
版: 1.0

---

**動作環境**：Lazarus 5.0 以降（FPC 3.2.2）。Lazarus 4.8 以前は対象外。

## 1. 概要とクラス

ページを持たない、タブ列だけの部品です。エディタのタブのように、画面の切り替えをアプリが行うときに使います。タブ列は TCPageControl と同じもの（自前の描画）なので、［×］・［＋］・スクロール・ドラッグでの並べ替え・タイトルバーへの載せ替え・ダーク表示ができます。

```
+---------+------------+------------+---+
| main.pas | util.pas ● | readme.md × | ＋ |
+---------+------------+------------+---+
```

- タブ 1 つ = TCTabSheet 1 枚。題名・アイコン・ヒント・変更あり・タブごとの色・アプリの値（`Tag`）を持つ。
- ［×］・［＋］は、自動では何もしない。アプリに知らせるだけで、タブを足す・消すのはアプリが決める。
- タブをドラッグして並べ替えられる。タブ列の外で離すと、アプリに知らせる（別のタブ列へ移す・アプリの外へ出す、に使える）。
- 表示中のタブの上（または下）に、線を出せる。変更のあるタブは、［×］の場所に「●」を出せる。色はプロパティで決める。
- 高さは、タブ列の高さに自動で合う。
- `TitleBar` に TCTitleBar を指定すると、タブ列がタイトルバーに載る。

| 項目 | 内容 |
|---|---|
| Lazarus | 5.0RC1 以降 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCTabBar` | `uCPageControl` | cx | `TCPageControl` | タブ列だけの部品 |
| `TCTabSheet` | `uCPageControl` | cx | `TCustomControl` | タブ 1 つ（3.3）。`TCTabBar.Tabs[i]` で取る |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCTabIndexEvent` | `uCPageControl` | `procedure(Sender: TObject; AIndex: Integer) of object`。`OnTabClick` の型 |
| `TCTabDragOutEvent` | `uCPageControl` | `procedure(Sender: TObject; AIndex: Integer; const AScreenPos: TPoint; ATarget: TControl) of object`。`OnTabDragOut` の型 |
| `TCPageCloseEvent` | `uCPageControl` | `procedure(Sender: TObject; APage: TCTabSheet; var CanClose: Boolean) of object`。`OnPageClose` の型 |
| `TCPageMovedEvent` | `uCPageControl` | `procedure(Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer) of object`。`OnPageMoved` の型 |

- フォームに置くと、uses に `uCPageControl` が自動で入る。
- フォームに置くと、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCTabBar をフォームに置く（自動で `Align = alTop`）。
2. 実行時に、`AddTab` でタブを足す（9.1）。
3. タブを押したときの切り替えは、`OnTabClick` に書く（9.2）。
4. 閉じるときは、`OnPageClose` で確認し、`CanClose := False` にして、アプリが自分で閉じる（9.3）。
5. ［＋］で新しいタブを作るときは、`OnTabPlusClick` に書く（9.1）。

- 画面の切り替え（表示する本文・エディタなど）は、アプリが行う。TCTabBar はページを持たない。
- ［＋］・［×］を出す・出さないは、`Options` で決める。

## 3. プロパティ

### 3.1 この部品で足したもの

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `TabCount` | `Integer` | 読み | タブの枚数。実行時だけ |
| `Tabs[AIndex]` | `TCTabSheet` | 読み | その番号のタブ（3.3）。実行時だけ |

### 3.2 TCPageControl から引き継いだもの

TCPageControl の取扱説明書 3.1 と同じ。ここでは、TCTabBar で既定値が違うもの、よく使うものだけを書く。

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Align` | `TAlign` | 読み・書き | 既定値は `alTop` |
| `Options` | `TCTabControlOptions` | 読み・書き | 既定値は `[nboShowCloseButtons, nboShowAddTabButton]`。`nboShowCloseButtons`＝各タブの［×］（と中ボタンでの閉じる）、`nboShowAddTabButton`＝［＋］ |
| `ShowTabListButton` | `Boolean` | 読み・書き | ［∨］（タブの一覧）を出すか。既定値は `False` |
| `TabStop` | `Boolean` | 読み・書き | 既定値は `False`（キーボードのフォーカスを受けない） |
| `TabIndex` | `Integer` | 読み・書き | 表示中のタブの番号。書いても `OnTabClick` は出ない |
| `Color` | `TColor` | 読み・書き | タブ列の背景色 |
| `Font` | `TFont` | 読み・書き | タブの文字。タブの高さは文字では変わらない（`TabHeight`。0 なら 28 を、表示スケールで拡大した高さ） |
| `Images`・`ImagesWidth` | `TCustomImageList`・`Integer` | 読み・書き | タブのアイコン（TCImageList も使える）。番号は `TCTabSheet.ImageIndex`（または `OnGetImageIndex`） |
| `TabHeight`・`TabWidth`・`TabMaxWidth`・`TabShape` | ― | 読み・書き | タブの高さ・幅・最大の幅・形（`tsRectangle`・`tsRounded`） |
| `TitleBar` | `TCTitleBar` | 読み・書き | タブ列を入れるタイトルバー（9.7） |
| `ActiveMarkSize`・`ActiveMarkColor`・`ActiveMarkAtBottom` | ― | 読み・書き | 表示中のタブの線の太さ（0 で出さない）・色・位置（上か下） |
| `ActiveTabColor`・`ActiveTextColor`・`TabTextColor`・`ModifiedTextColor`・`HotTabColor`・`ButtonColor`・`SeparatorColor` | `TColor` | 読み・書き | 色の指定（7章） |

### 3.3 タブ 1 つ（TCTabSheet）

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Caption` | `TCaption` | 読み・書き | タブの題名 |
| `ImageIndex` | `TImageIndex` | 読み・書き | アイコンの番号。-1（既定値）ならなし |
| `Hint` | `TTranslateString` | 読み・書き | マウスを乗せたときのヒント。空なら出ない |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値（`AddTab` の `AData`。文書の番号やポインタなどを入れる） |
| `Modified` | `Boolean` | 読み・書き | 変更あり。`True` なら、［×］の場所に「●」を出す（マウスを乗せると［×］になる） |
| `TabColorActive` | `TColor` | 読み・書き | このタブだけの、表示中のときの背景色。`clDefault`（既定値）なら `ActiveTabColor` |
| `TabColorOver` | `TColor` | 読み・書き | このタブだけの、マウスを乗せたときの背景色。`clDefault`（既定値）なら `HotTabColor` |
| `TabVisible` | `Boolean` | 読み・書き | `False` でタブを隠す |
| `PageIndex` | `Integer` | 読み・書き | タブの番号。書くと、その位置へ移す |

## 4. メソッド

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `AddTab` | `const ACaption: string; AData: PtrInt = 0; AModified: Boolean = False` | `TCTabSheet` | 末尾にタブを足して返す。表示中のタブは変えない。イベントは出さない |
| `ClearTabs` | ― | ― | すべてのタブを消す。`OnPageClose` は出ない |
| `IndexOf` | `APage: TPersistent` | `Integer` | そのタブの番号。ないときは -1 |
| `IndexOfTabAt` | `X, Y: Integer` | `Integer` | その位置のタブの番号（見えているタブだけで数える）。ないときは -1 |
| `TabRect` | `AIndex: Integer` | `TRect` | そのタブの位置と大きさ |

## 5. イベント

### 5.1 この部品で足したもの

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnTabClick` | `Sender: TObject; AIndex: Integer` | タブを押した（同じタブを押したときも来る。ボタンを離す前）。`AIndex` は押したタブの番号。この時点で、そのタブは表示中になっている |
| `OnTabPlusClick` | `Sender: TObject` | ［＋］（右クリックの「新しいタブ」）を押した。タブは、アプリが `AddTab` で足す |
| `OnTabMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | タブ列の上でマウスの左ボタンを離した（タブ・［×］・［＋］の処理のあと、ドラッグの終わりのあとも）。タブを押したあとにフォーカスを戻すときに使う |
| `OnTabDragOut` | `Sender: TObject; AIndex: Integer; const AScreenPos: TPoint; ATarget: TControl` | タブをドラッグして、タブ列の外で離した。`AScreenPos` は離した画面の位置、`ATarget` はその位置の部品（アプリの外なら nil）。Esc で取り消したときは来ない |

### 5.2 TCPageControl から引き継いだもの

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnPageClose` | `Sender: TObject; APage: TCTabSheet; var CanClose: Boolean` | ［×］・中ボタン・右クリックの「タブを閉じる」・タブ一覧の［×］でタブを閉じる前。`CanClose := False` にすると、閉じない（アプリが自分で閉じるときに使う）。何もしなければ、タブが消える |
| `OnPageMoved` | `Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer` | ドラッグでタブを動かした後（タブ列は、もう並べ替えてある） |
| `OnChanging` | `Sender: TObject; var AllowChange: Boolean` | 表示中のタブが変わる前。`AllowChange := False` で取りやめる |
| `OnChange` | `Sender: TObject` | 表示中のタブが変わった後 |
| `OnGetImageIndex` | `Sender: TObject; TabIndex: Integer; var ImageIndex: Integer` | タブを描く前。アイコンの番号を決められる |
| `OnContextPopup`・`OnMouse…`・`OnResize` など | ― | TCPageControl の取扱説明書 3.3 と同じ |

`OnNewPage`・`OnPageRename` は使わない（［＋］は `OnTabPlusClick`）。

### 5.3 呼ばれる順番

| 操作 | 順番 |
|---|---|
| タブを押す（別のタブ） | `OnChanging` → `OnChange` → `OnTabClick` →（離す）`OnTabMouseUp` |
| 表示中のタブを押す | `OnTabClick` →（離す）`OnTabMouseUp` |
| ［＋］を押して離す | `OnTabPlusClick` → `OnTabMouseUp` |
| ［×］・中ボタン | `OnPageClose`（`CanClose = True` なら、タブが消える。表示中のタブなら `OnChange`）。［×］のときは、そのあとに `OnTabMouseUp` |
| ドラッグで並べ替え | `OnPageMoved` → `OnTabMouseUp` |
| ドラッグして、タブ列の外で離す | `OnTabDragOut` → `OnTabMouseUp`（並べ替えは起きない） |

## 6. 操作

| 部分 | 操作 |
|---|---|
| タブ | 押すと、そのタブを表示中にする。ドラッグで並べ替えられる（ドラッグ中に Esc、またはタブ列の外で離すと、並べ替えは取りやめ。外で離したときは `OnTabDragOut`） |
| タブの［×］・中ボタン | `OnPageClose` を出す（［×］を出しているとき） |
| ［＋］ | `OnTabPlusClick` を出す |
| タブにマウスを乗せる | `Hint` があれば、ヒントを出す |
| ［◀］［▶］ | タブが入りきらないときだけ出る。押すと 1 枚分ずつスクロールする。タブ列の上でマウスホイールでもスクロールする |
| ［∨］ | `ShowTabListButton = True` のとき、タブの一覧を出す |
| 右クリック | `TabMenuItems`（既定値は `[tmiNew, tmiClose, tmiRename]`）の標準の項目 →`TabPopupMenu` の項目。「新しいタブ」は `OnTabPlusClick`、「タブを閉じる」は `OnPageClose`。「タブ名の変更」は、タブの上で名前を編集する（使わないときは `TabMenuItems` から外す） |

## 7. 色と見た目

色は、プロパティで決める。`clDefault`（既定値）なら、システムの色で決まる。

| プロパティ | 部分 | `clDefault` のとき |
|---|---|---|
| `Color` | タブ列の背景 | `clBtnFace` |
| `ActiveTabColor` | 表示中のタブの背景 | `clWindow` |
| `ActiveTextColor` | 表示中のタブの文字 | `clWindowText` |
| `TabTextColor` | ほかのタブの文字 | `clBtnText` |
| `ModifiedTextColor` | 変更ありのタブの文字 | ほかの文字の色 |
| `HotTabColor` | マウスを乗せたタブの背景 | 背景色に `clBtnText` を少し混ぜた色 |
| `ButtonColor` | ［×］・［◀］［▶］・［＋］・［∨］の記号 | 文字の色 |
| `SeparatorColor` | タブとタブの間の区切り線 | （`clNone` なら出さない。既定値は `clNone`） |
| `ActiveMarkColor`・`ActiveMarkSize` | 表示中のタブの線 | `clHighlight`。太さ 0 なら出さない |
| `TCTabSheet.TabColorActive`・`TabColorOver` | そのタブだけの背景 | `ActiveTabColor`・`HotTabColor` |

- タブの背景を付けない（ほかのタブは、タブ列の背景のまま）のが、既定の見た目（フラット）。角を丸くするには `TabShape := tsRounded`。
- ダーク表示にするには、上の色を暗い色に指定する（9.6）。

## 8. 注意

- ページを持たない。`Tabs[i]` の TCTabSheet は、タブの情報を入れる入れ物で、中に部品を置かない。
- ［×］・［＋］で、タブは自動では増減しない。`OnPageClose` で `CanClose := False` にしたとき、タブを消すのはアプリの仕事（`ClearTabs` で作り直すか、`Tabs[i].Free`）。
- `OnPageClose` の中で、確認のダイアログを出したり、タブを消したりしない。`Application.QueueAsyncCall` で、タブ列の処理が終わってから行う（9.3）。
- タブをドラッグして別の場所へ移す処理（`OnTabDragOut`）も、同じ理由で、中ではタブを消さず、`QueueAsyncCall` で後から行う。
- 高さは、タブ列の高さに自動で合わせる。`Height` を直接書かない（`TitleBar` を指定したときは、タイトルバーの高さに合わせる）。
- `TabIndex` に書いて表示するタブを変えても、`OnTabClick` は出ない。アプリが自分で切り替えたときの二重の処理を避けられる。
- タブを足す・消すたびに、全タブを作り直す使い方でも動く（`ClearTabs` → `AddTab` の繰り返し）。作り直している間の `OnChange` で、アプリの処理が走らないように、アプリ側で印（`FUpdating` など）を立てる。
- `NewPageCaption`・`OnNewPage`・`OnPageRename`・`tmiRename`（名前の変更）は、アプリが自分でタブを管理する使い方では、使わない。

## 9. 使い方の例

### 9.1 文書の一覧からタブを作る・［＋］で足す

```pascal
procedure TForm1.RebuildTabs;
var
  I: Integer;
  T: TCTabSheet;
begin
  FUpdating := True;          // 作り直している間の OnChange を、アプリが無視する印
  try
    CTabBar1.ClearTabs;
    for I := 0 to FDocs.Count - 1 do
    begin
      T := CTabBar1.AddTab(FDocs[I].Name, PtrInt(FDocs[I]), FDocs[I].Modified);
      T.Hint := FDocs[I].FileName;      // マウスを乗せたときのヒント
    end;
    CTabBar1.TabIndex := FCurrent;
  finally
    FUpdating := False;
  end;
end;

procedure TForm1.CTabBar1TabPlusClick(Sender: TObject);
begin
  NewDocument;                // 文書を作って、RebuildTabs を呼ぶ
end;
```

### 9.2 タブを押したら本文を切り替える・ボタンを離したらフォーカスを戻す

```pascal
procedure TForm1.CTabBar1TabClick(Sender: TObject; AIndex: Integer);
begin
  if FUpdating then Exit;
  ShowDocument(AIndex);
  FFocusOnMouseUp := True;
end;

procedure TForm1.CTabBar1TabMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if FFocusOnMouseUp then
  begin
    FFocusOnMouseUp := False;
    Application.QueueAsyncCall(@FocusEditorLater, 0);   // マウス処理が終わってから、本文へフォーカスを移す
  end;
end;
```

### 9.3 閉じる前に確認する

```pascal
procedure TForm1.CTabBar1PageClose(Sender: TObject; APage: TCTabSheet;
  var CanClose: Boolean);
begin
  CanClose := False;          // タブは、ここでは消さない
  Application.QueueAsyncCall(@CloseDocLater, CTabBar1.IndexOf(APage));
end;

procedure TForm1.CloseDocLater(Data: PtrInt);
begin
  if ConfirmSave(Data) then   // 確認のダイアログは、タブ列の処理の外で出す
  begin
    FDocs.Delete(Data);
    RebuildTabs;
  end;
end;
```

### 9.4 並べ替えに合わせて、文書の並びを入れ替える

```pascal
procedure TForm1.CTabBar1PageMoved(Sender: TObject; APage: TCTabSheet;
  AOldIndex, ANewIndex: Integer);
begin
  FDocs.Move(AOldIndex, ANewIndex);    // タブ列は、もう並べ替えてある
end;
```

### 9.5 タブを別のウィンドウへ移す・アプリの外へ出す

```pascal
procedure TForm1.CTabBar1TabDragOut(Sender: TObject; AIndex: Integer;
  const AScreenPos: TPoint; ATarget: TControl);
begin
  if ATarget = nil then
    Application.QueueAsyncCall(@MakeNewWindowLater, AIndex)       // アプリの外：新しいウィンドウへ
  else if FindOtherEditor(ATarget) <> nil then
    Application.QueueAsyncCall(@MoveToOtherEditorLater, AIndex);  // 別のエディタの上：そちらへ
end;
```

### 9.6 ダーク表示にする

```pascal
CTabBar1.Color := $202020;
CTabBar1.ActiveTabColor := $1E1E1E;
CTabBar1.ActiveTextColor := clWhite;
CTabBar1.TabTextColor := $A0A0A0;
CTabBar1.HotTabColor := $2B2B2B;
CTabBar1.ButtonColor := $A0A0A0;
CTabBar1.SeparatorColor := $3A3A3A;
CTabBar1.ActiveMarkSize := 2;            // 表示中のタブの上の線
CTabBar1.ActiveMarkColor := $D47800;
```

### 9.7 タブ列をタイトルバーに載せる

1. TCTitleBar をフォームに置く。
2. TCTabBar の `TitleBar` に、その TCTitleBar を選ぶ（タブ列がタイトルバーの中に移る）。

```pascal
CTabBar1.TitleBar := CTitleBar1;
```