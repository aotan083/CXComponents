# TCSideBar 設計書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 目的

Microsoft Edge のサイドバーのような「アイコン列＋開閉するパネル＋スプリッター」を1つの部品（TCSideBar）にする。ページ（TCSideBarPage）は子の部品として持ち、フォームデザイナでページの上に部品を置けるようにする。

- アイコン列・見出し（Caption と［×］）・スプリッターは、TCSideBar が自分で描く。
- 開いているページだけを表示する。
- 幅は TCSideBar が自分で決める（閉じているときはアイコン列だけ）。
- 色はシステム色だけを使う（ダーク／ライトはアプリ側の MetaDarkStyle などに任せる）。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCSideBar.pas` | cx（実行時） | 型、`TCSideBarPage`、`TCSideBar`、変数 `CSideBarDesignSelect` |
| `uCSideBarReg.pas` | cxdsgn（設計時） | パレット [CX] への登録、コンポーネントエディタ `TCSideBarEditor` |
| `csidebar_icon.lrs` | cxdsgn（設計時） | アイコン（`TCSideBar`・`TCSideBar_150`・`TCSideBar_200`）。`uCSideBarReg` の initialization で `{$I csidebar_icon.lrs}` |

- `uCSideBar` の uses：`Classes, SysUtils, Types, LCLType, LCLIntf, LCLProc, LMessages, Controls, Graphics, GraphType, Forms, Menus, ImgList, ExtCtrls, Themes`
- `uCSideBar` の initialization：`RegisterClass(TCSideBarPage)`（.lfm からページを読み込めるようにする）。
- `uCSideBarReg` の uses：`Classes, SysUtils, LResources, ComponentEditors, PropEdits, uCSideBar`

## 3. 型と定数

```pascal
TCSideBarPageEvent = procedure(Sender: TObject; Index: Integer) of object;
TCSideBarChangingEvent = procedure(Sender: TObject; Index: Integer; var Allow: Boolean) of object;
TCSideBarDesignSelectProc = procedure(AComponent: TComponent);

var
  CSideBarDesignSelect: TCSideBarDesignSelectProc = nil;
```

- `CSideBarDesignSelect` は、設計時に IDE で選ぶ部品を変える手続き。実行時パッケージは IDEIntf を使えないため、設計時パッケージ（`uCSideBarReg` の `Register`）が設定する。

100% のときの大きさ（implementation。描くたびに `Scale96ToFont` で拡大する）：

| 名前 | 値 | 中身 |
|---|---|---|
| `cHeaderHeight96` | 32 | 見出しの高さ |
| `cCloseButton96` | 20 | ［×］の大きさ |
| `cIconInset96` | 4 | アイコンの枠と強調表示の間の余白 |
| `cIconRadius96` | 6 | 強調表示の角の丸み |
| `cTextPadding96` | 8 | 見出しの文字の左右の余白 |

resourcestring：`rsCSideBarPageParent = 'TCSideBarPage は TCSideBar の上にだけ置けます'`

## 4. TCSideBarPage

### 4.1 宣言

```pascal
TCSideBarPage = class(TCustomControl)
private
  FImageIndex: TImageIndex;
  FPanelWidth: Integer;
  FPageVisible: Boolean;
  FShortCut: TShortCut;
  function GetSideBar: TCSideBar;
  procedure SetImageIndex(const AValue: TImageIndex);
  procedure SetPanelWidth(AValue: Integer);
  procedure SetPageVisible(const AValue: Boolean);
  procedure SetActiveState(AActive: Boolean);
protected
  procedure SetParent(NewParent: TWinControl); override;
  procedure TextChanged; override;
  procedure CMHitTest(var Message: TCMHitTest); message CM_HITTEST;
  procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
  procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
    const AXProportion, AYProportion: Double); override;
public
  constructor Create(TheOwner: TComponent); override;
  property SideBar: TCSideBar read GetSideBar;
published
  property Caption;
  property ImageIndex: TImageIndex read FImageIndex write SetImageIndex default -1;
  property PanelWidth: Integer read FPanelWidth write SetPanelWidth default 250;
  property PageVisible: Boolean read FPageVisible write SetPageVisible default True;
  property Enabled;
  property ShortCut: TShortCut read FShortCut write FShortCut default 0;
  property Color;
  property Font;
  property ParentFont;
  property PopupMenu;
  property ShowHint;
  property ParentShowHint;
end;
```

`TCSideBarPage` は `TCSideBar` より前に宣言するので、先に `TCSideBar = class;` を置く。`SetActiveState` は private だが、同じユニットの `TCSideBar` から呼ぶ。

### 4.2 Create

1. `FImageIndex := -1`、`FPanelWidth := 250`、`FPageVisible := True`、`FShortCut := 0`。
2. `ControlStyle` に `csAcceptsControls`（上に部品を置ける）・`csDesignFixedBounds`（設計時に動かせない）・`csNoDesignVisible`（設計時も表示しない。開いたときに外す）・`csNoFocus`（ページはフォーカスを受けない）を足す。TCustomPage と同じ。
3. `Align := alClient`、`ParentColor := False`、`Color := clBtnFace`、`Caption := ''`、`Visible := False`。

### 4.3 手続き

| 手続き | 処理 |
|---|---|
| `GetSideBar` | `Parent` が `TCSideBar` ならそれ、ちがえば nil |
| `SetImageIndex` | 値が変わったら入れ、`SideBar.PageChanged(Self)` |
| `SetPanelWidth` | 負なら 0 にする。値が変わったら入れ、`SideBar.PanelWidthChanged(Self)` |
| `SetPageVisible` | 値が変わったら入れ、`SideBar.PageVisibleChanged(Self)` |
| `SetActiveState(True)` | `csNoDesignVisible` を外し、`Visible := True` |
| `SetActiveState(False)` | `csNoDesignVisible` を付け、`Visible := False` |
| `SetParent(NewParent)` | 同じなら終わる。`NewParent` が nil でも `TCSideBar` でもなければ `EInvalidOperation(rsCSideBarPageParent)`。前の親が `TCSideBar` なら `RemovePage(Self)`。`inherited SetParent`。新しい親が `TCSideBar` なら `AddPage(Self)` |
| `TextChanged` | `inherited` のあと `SideBar.PageChanged(Self)`（Caption は見出しとヒントに使う） |
| `CMHitTest` | 開いていないページ（`SideBar.ActivePage <> Self`）は `Message.Result := 0`（マウスを受けない）。ほかは `inherited` |
| `CMEnabledChanged` | `inherited` のあと `SideBar.PageChanged(Self)`（アイコンを灰色にする／戻す） |
| `DoAutoAdjustLayout` | `inherited` のあと、`AMode` が `lapAutoAdjustWithoutHorizontalScrolling`・`lapAutoAdjustForDPI` なら `PanelWidth := Round(FPanelWidth * AXProportion)` |

- `SetActiveState` は、設計時なら最後に `UpdateControlState` を呼ぶ（設計時はこれがないと表示が変わらない）。
- 開いているページだけ `csNoDesignVisible` を外すのは、LCL の `TCustomTabControl.UpdateDesignerFlags` と同じ考え方。デザイナは `csNoDesignVisible` のある部品を「その場所にない」と扱うので、外さないと置いた部品がページではなくフォームに入る。
- 閉じるときは、先にフラグを付けてから `Visible := False` にする。
- `SetParent` を通るので、.lfm の読み込み順がそのままページの順番になる。ページを壊すときも親が外れて `RemovePage` が呼ばれる。

## 5. TCSideBar

### 5.1 フィールド

| 名前 | 型 | 初期値 | 中身 |
|---|---|---|---|
| `FPages` | `TFPList` | 空 | ページの順番 |
| `FActivePage` | `TCSideBarPage` | nil | 開いているページ |
| `FImages` | `TCustomImageList` | nil | アイコンの画像 |
| `FImageChangeLink` | `TChangeLink` | 作る | `OnChange := ImageListChange` |
| `FImagesWidth` | `Integer` | 0 | アイコンの幅（100% の値のまま持つ） |
| `FIconBarWidth` | `Integer` | 40 | アイコン列の幅 |
| `FMinPanelWidth` | `Integer` | 150 | パネルの幅の下限 |
| `FMaxPanelWidth` | `Integer` | 600 | パネルの幅の上限（0 は上限なし） |
| `FSplitterWidth` | `Integer` | 8 | スプリッターの幅 |
| `FResizeStyle` | `TResizeStyle` | `rsLine` | ドラッグ中の表示 |
| `FShowHeader` | `Boolean` | `True` | 見出しを出すか |
| `FShowCloseButton` | `Boolean` | `True` | ［×］を出すか |
| `FIconPopupMenu` | `TPopupMenu` | nil | アイコン列の右クリックメニュー |
| `FOnPageChanging`・`FOnPageOpen`・`FOnPageClose`・`FOnPanelResize` | イベント型 | nil | イベント |
| `FHotPage` | `TCSideBarPage` | nil | マウスが乗っているアイコンのページ |
| `FHotClose` | `Boolean` | `False` | マウスが［×］に乗っている |
| `FDownPage` | `TCSideBarPage` | nil | 左ボタンを押したアイコンのページ |
| `FDownClose` | `Boolean` | `False` | 左ボタンを［×］で押した |
| `FDragging` | `Boolean` | `False` | スプリッターのドラッグ中 |
| `FDragStartX`・`FDragStartWidth`・`FDragWidth` | `Integer` | | ドラッグの開始位置・開始時の幅・今の幅 |
| `FRubberBand` | `HWND` | 0 | ドラッグ中の線（別ウィンドウ） |
| `FKeyHandlerAdded` | `Boolean` | | ショートカットキーの受け取りを登録したか |
| `FDesignerPressLeft` | `Boolean` | `False` | 設計時、サイドバーが MouseUp を処理したあと、デザイナが押下中の状態を残している（7.5） |

### 5.2 宣言（公開するもの）

```pascal
public
  constructor Create(TheOwner: TComponent); override;
  destructor Destroy; override;
  procedure OpenPage(Index: Integer);
  procedure ClosePage;
  procedure MovePage(CurIndex, NewIndex: Integer);
  property Pages[Index: Integer]: TCSideBarPage read GetPage;
  property PageCount: Integer read GetPageCount;
  property ActivePageIndex: Integer read GetActivePageIndex write SetActivePageIndex;
published
  property ActivePage: TCSideBarPage read FActivePage write SetActivePage;
  property Images: TCustomImageList read FImages write SetImages;
  property ImagesWidth: Integer read FImagesWidth write SetImagesWidth default 0;
  property IconBarWidth: Integer read FIconBarWidth write SetIconBarWidth default 40;
  property MinPanelWidth: Integer read FMinPanelWidth write SetMinPanelWidth default 150;
  property MaxPanelWidth: Integer read FMaxPanelWidth write SetMaxPanelWidth default 600;
  property SplitterWidth: Integer read FSplitterWidth write SetSplitterWidth default 8;
  property ResizeStyle: TResizeStyle read FResizeStyle write FResizeStyle default rsLine;
  property ShowHeader: Boolean read FShowHeader write SetShowHeader default True;
  property ShowCloseButton: Boolean read FShowCloseButton write SetShowCloseButton default True;
  property IconPopupMenu: TPopupMenu read FIconPopupMenu write SetIconPopupMenu;
  property OnPageChanging: TCSideBarChangingEvent read FOnPageChanging write FOnPageChanging;
  property OnPageOpen: TCSideBarPageEvent read FOnPageOpen write FOnPageOpen;
  property OnPageClose: TCSideBarPageEvent read FOnPageClose write FOnPageClose;
  property OnPanelResize: TNotifyEvent read FOnPanelResize write FOnPanelResize;
  property Align default alLeft;
  property Anchors;
  property BorderSpacing;
  property Constraints;
  property Enabled;
  property Font;
  property ParentFont;
  property ParentShowHint;
  property ShowHint;
  property Visible;
```

protected で、ページから呼ばれる `AddPage`・`RemovePage`・`PageChanged`・`PageVisibleChanged`・`PanelWidthChanged` と、LCL の上書き（`Loaded`・`Notification`・`AdjustClientRect`・`CalculatePreferredSize`・`DoAutoAdjustLayout`・`Paint`・`MouseDown`・`MouseMove`・`MouseUp`・`MouseLeave`・`CaptureChanged`・`DoContextPopup`・`CMHintShow`・`CMDesignHitTest`・`CMEnabledChanged`）を持つ。

### 5.3 Create・Destroy

Create：

1. `FPages := TFPList.Create`、`FImageChangeLink` を作って `OnChange := ImageListChange`。
2. 5.1 の初期値を入れる。`FRubberBand := 0`。
3. `ControlStyle := ControlStyle - [csAcceptsControls] + [csCaptureMouse, csClickEvents]`（部品はページの上にだけ置ける。ドラッグ中に外へ出てもマウスを受け取る）。
4. `Color := clBtnFace`、`Align := alLeft`、`AutoSize := True`（幅は自分で決める。AutoSize は公開しない）。
5. 設計時でなく `Application` があれば、`Application.AddOnKeyDownHandler(@AppKeyDown, False)`、`FKeyHandlerAdded := True`。

Destroy：

1. `FKeyHandlerAdded` なら `Application.RemoveOnKeyDownHandler(@AppKeyDown)`。
2. `FRubberBand <> 0` なら `DestroyRubberBand`。
3. `inherited Destroy`（この中で子のページの親が外れ、`RemovePage` が呼ばれる）。
4. そのあとで `FImageChangeLink`・`FPages` を解放する。

### 5.4 判定

| 手続き | 処理 |
|---|---|
| `EventsEnabled` | `ComponentState` に `csLoading`・`csReading`・`csDesigning`・`csDestroying` がなければ `True` |
| `IconShown(P)` | `P` が nil でなく、設計時か `P.PageVisible` なら `True`（設計時は `PageVisible` に関係なく出す） |
| `CanOpenPage(P)` | nil なら `False`。設計時は `True`。実行時は `P.PageVisible and P.Enabled` |

### 5.5 大きさと位置

| 手続き | 処理 |
|---|---|
| `HeaderHeight` | `Scale96ToFont(cHeaderHeight96)` |
| `CloseButtonSize` | `Scale96ToFont(cCloseButton96)` |
| `HeaderRect` | 閉じているか `ShowHeader = False` なら空。それ以外は `Rect(FIconBarWidth, 0, ClientWidth - FSplitterWidth, HeaderHeight)`（右が左より小さければ左にそろえる） |
| `CloseButtonRect` | 閉じている、`ShowHeader = False`、`ShowCloseButton = False` のどれかなら空。それ以外は見出しの右端に、縦の中央にそろえた `CloseButtonSize` の正方形（余白 `M := (見出しの高さ - S) div 2`）。左端が見出しの左より小さければそろえる |
| `SplitterRect` | 閉じていれば空。それ以外は `Rect(ClientWidth - FSplitterWidth, 0, ClientWidth, ClientHeight)` |
| `IconRect(P)` | `IconShown(P)` でなければ空。`FPages` を順に見て、`IconShown` のものだけ数え、`P` の行 `Row` で `Rect(0, Row * FIconBarWidth, FIconBarWidth, (Row + 1) * FIconBarWidth)` |
| `PageAtIcon(X, Y)` | `FIconBarWidth <= 0`、`X` がアイコン列の外、`Y < 0` なら nil。`Y div FIconBarWidth` 行目の、`IconShown` のページ |
| `InCloseButton`・`InSplitter` | `CloseButtonRect`・`SplitterRect` の中か |
| `ClampPanelWidth(v)` | `v < FMinPanelWidth` なら下限。`FMaxPanelWidth > 0` で上限を超えれば上限。負なら 0 |

### 5.6 プロパティの読み書き

| 手続き | 処理 |
|---|---|
| `GetPage(i)` | `FPages[i]`（範囲外は TFPList が `EListError`） |
| `GetPageCount` | `FPages.Count` |
| `GetActivePageIndex` | 閉じていれば -1、それ以外は `FPages.IndexOf(FActivePage)` |
| `SetActivePageIndex(v)` | `v < -1` か `v >= Count` なら何もしない。-1 なら `ChangeActivePage(nil)`、それ以外は `ChangeActivePage(FPages[v])` |
| `SetActivePage(v)` | `csLoading` 中は `FActivePage := v` だけ（表示は `Loaded` で決める）。`v` がこのサイドバーのページでなければ何もしない。それ以外は `ChangeActivePage(v)` |
| `SetIconBarWidth`・`SetSplitterWidth` | 負なら 0。変わったら入れて `LayoutChanged` |
| `SetMinPanelWidth`・`SetMaxPanelWidth` | 負なら 0 にして入れる（描き直さない） |
| `SetImagesWidth` | 負なら 0。変わったら入れて `Invalidate` |
| `SetImages` | 前のものから `UnRegisterChanges`・`RemoveFreeNotification`。新しいものに `FreeNotification`・`RegisterChanges`。`Invalidate` |
| `SetIconPopupMenu` | 前のものから `RemoveFreeNotification`、新しいものに `FreeNotification` |
| `SetShowHeader` | 変わったら入れ、`FHotClose := False`、`FDownClose := False`、`LayoutChanged`（クライアント領域の上端が変わる。幅は変わらず、イベントも出さない） |
| `SetShowCloseButton` | 変わったら入れて `Invalidate` |
| `ImageListChange` | `Invalidate` |
| `Notification` | `opRemove` で `FImages` なら nil にして `Invalidate`。`FIconPopupMenu` なら nil |

### 5.7 ページ一覧

| 手続き | 処理 |
|---|---|
| `AddPage(P)` | すでにあれば終わる。`FPages.Add(P)`、`P.SetActiveState(P = FActivePage)`。読み込み中でなければ `Invalidate` |
| `RemovePage(P)` | `FPages` が nil か、`P` がなければ終わる。一覧から外し、`FHotPage`・`FDownPage` が `P` なら nil。`P` が開いているページなら `FActivePage := nil`（イベントは出さない）、ドラッグ中ならやめて線を消す。壊している途中でなければ `LayoutChanged` |
| `PageChanged` | `Invalidate` |
| `PageVisibleChanged(P)` | 実行時に、開いているページが隠されたら `SetActivePageSilently(nil)`。ほかは `Invalidate` |
| `PanelWidthChanged(P)` | 開いているページなら `LayoutChanged` |
| `MovePage(Cur, New)` | どちらかが範囲外、または同じなら何もしない。`NewControlIndex := GetControlIndex(FPages[New])`、`FPages.Move(Cur, New)`、`SetControlIndex(P, NewControlIndex)`、`Invalidate`。`FPages` の順と子の順（.lfm に保存される順）を同じにする。イベントは出さない |

### 5.8 開閉

`ChangeActivePage(NewPage): Boolean`（状態が変わったら `True`）：

1. `NewPage = FActivePage` なら `False` で終わる。`NewPage` が nil でなく `CanOpenPage` でなければ `False` で終わる。
2. `EventsEnabled` でなければ `SetActivePageSilently(NewPage)` して `True` で終わる。
3. `Allow := True`。`FOnPageChanging` があれば、閉じるときは -1、開くときは `NewPage` の番号で呼ぶ。`Allow = False` なら終わる。
4. イベントの中で状態が変えられていたら（`NewPage = FActivePage`、または `NewPage` が一覧にない）終わる。
5. `DisableAutoSizing`（開閉の途中で幅が2回変わらないように）。
6. 開いていたページがあれば：番号を覚え、`FActivePage := nil`、`SetActiveState(False)`、`FOnPageClose(番号)`。
7. `NewPage` が一覧にあり、`FActivePage = nil` なら：`FActivePage := NewPage`、`SetActiveState(True)`、`LayoutChanged`、`FOnPageOpen(番号)`。
8. `LayoutChanged`、`EnableAutoSizing`（finally）。`True` を返す。

| 手続き | 処理 |
|---|---|
| `SetActivePageSilently(P)` | 同じなら終わる。`DisableAutoSizing` の間に、前のページを `SetActiveState(False)`、`FActivePage := P`、`SetActiveState(True)`、`LayoutChanged` |
| `UserTogglePage(P)` | 開いているページなら `ChangeActivePage(nil)`、ほかは `ChangeActivePage(P)`。変わって設計時なら `OwnerFormDesignerModified(Self)`、`CSideBarDesignSelect` があれば、開いたページ（閉じたらサイドバー）を選ぶ（隠れたページの部品の選択枠が残って見えないように） |
| `UpdatePageVisibility` | 全ページに `SetActiveState(P = FActivePage)` |
| `LayoutChanged` | 壊している途中なら何もしない。`InvalidatePreferredSize`・`AdjustSize`・`ReAlign`・`Invalidate` |
| `OpenPage(i)` | `ChangeActivePage(FPages[i])`（範囲外は `EListError`） |
| `ClosePage` | `ChangeActivePage(nil)` |

### 5.9 LCL の上書き

| 手続き | 処理 |
|---|---|
| `Loaded` | `inherited` のあと、`FActivePage` が一覧にないか `CanOpenPage` でなければ nil。`UpdatePageVisibility`、`LayoutChanged`。イベントは出さない |
| `AdjustClientRect` | `inherited` のあと、`Left += FIconBarWidth`。開いていれば、`ShowHeader` なら `Top += HeaderHeight`、`Right -= FSplitterWidth`。右が左より、下が上より小さくならないようにする。ページは `alClient` なので残りいっぱいに置かれる |
| `CalculatePreferredSize` | 幅 = `FIconBarWidth`、開いていれば `+ FActivePage.PanelWidth + FSplitterWidth`。0 以下なら 1（0 以下は「指定なし」と扱われるため）。高さ 0（Align に任せる）。`ShowHeader` は関係しない |
| `DoAutoAdjustLayout` | `inherited` のあと、`lapAutoAdjustWithoutHorizontalScrolling`・`lapAutoAdjustForDPI` なら、`FIconBarWidth`・`FMinPanelWidth`・`FMaxPanelWidth`（0 でなければ）・`FSplitterWidth` を `Round(値 * AXProportion)` にして `LayoutChanged`。`PanelWidth` はページ側、`ImagesWidth` は ImageList 側で扱う |
| `CMEnabledChanged` | `inherited` のあと `Invalidate` |

## 6. 描画

`Paint`：全体を `clBtnFace` で塗る → `PaintIcons` → 開いていれば、`ShowHeader` なら `PaintHeader`、`PaintSplitter`。

`PaintIcons`：

1. `FIconBarWidth <= 0` なら終わる。`Inset := Scale96ToFont(cIconInset96)`、`Radius := Scale96ToFont(cIconRadius96)`。
2. `Images` があれば `Res := FImages.ResolutionForPPI[FImagesWidth, Font.PixelsPerInch, 1]`（100% の幅から、表示スケールに合う画像を ImageList が選ぶ）。
3. `IconShown` のページごとに、`R := IconRect(P)`、`HR` = `R` を `Inset` だけ内側にしたもの。
   - マウスが乗っていて、サイドバーもページも使えるとき：`clBtnHighlight` で `RoundRect(HR, Radius, Radius)` を塗る。
   - 開いているページ：`clHighlight` の1px の線で `RoundRect(HR, Radius, Radius)`（塗らない）。
   - `ImageIndex` が範囲内なら、枠の中央にアイコンを描く。サイドバーもページも使えるなら `Res.Draw(Canvas, IX, IY, ImageIndex, True)`。使えないなら `Res.GetBitmap(ImageIndex, Bmp, gdeDisabled)` で灰色の画像を作って `Canvas.Draw`（`Res.Draw(..., False)` は Windows では画像の形式によって色が変わらないため）。

`PaintHeader`：

1. `HeaderRect` を `clBtnFace` で塗る。
2. 文字の範囲 `TR` = 見出しの左右から `Scale96ToFont(cTextPadding96)` 内側。［×］があれば、右端を `［×］の左 - Pad div 2` にする。
3. `Font`、文字色 `clBtnText`、上下中央・1行・末尾を「…」・はみ出しを切る、で `FActivePage.Caption` を描く。
4. ［×］：マウスが乗っていれば `clBtnHighlight` で塗る。`M := ［×］の幅 div 4` として、`clBtnText`・太さ `Scale96ToFont(1)`（最小 1）の線を2本引いて「×」にする。

`PaintSplitter`：`SplitterRect` の中央に `clBtnShadow` の1px の縦線。

## 7. マウス

### 7.1 MouseDown・MouseMove・MouseUp・MouseLeave

- `MouseDown`：`inherited` のあと、左ボタンなら、`FDownPage := nil`、`FDownClose := False`。スプリッターの上なら `BeginSplitterDrag(X)`、［×］の上なら `FDownClose := True`、ほかは `FDownPage := PageAtIcon(X, Y)`。
- `MouseMove`：`inherited` のあと、ドラッグ中なら `MoveSplitterDrag(X)` して終わる。ほかは `SetHot(PageAtIcon(X, Y), InCloseButton(X, Y))`、スプリッターの上なら `Cursor := crHSplit`、ほかは `crDefault`。
- `MouseUp`：`inherited` のあと、左ボタンでなければ終わる。
  1. ドラッグ中なら `EndSplitterDrag(X)`、設計時なら `FDesignerPressLeft := True`、終わる。
  2. `FDownClose` なら戻して、［×］の上で離し、開いていれば `ChangeActivePage(nil)`、終わる。
  3. `P := FDownPage`、`FDownPage := nil`。設計時なら `FDesignerPressLeft := True`。
  4. `P` があり、離した所も `P` のアイコンで、サイドバーが使え、設計時か `P.Enabled` なら `UserTogglePage(P)`。
- `MouseLeave`：`inherited` のあと、ドラッグ中でなければ `SetHot(nil, False)`、`Cursor := crDefault`。
- `SetHot(P, AClose)`：同じなら終わる。別のアイコンに移ったら `Application.CancelHint`（ヒントを出し直せるように）。入れて `Invalidate`。

### 7.2 右クリック（DoContextPopup）

`inherited` で `Handled` なら終わる。`Handled := True`（アイコン列以外では何も出さない）。マウスの位置がアイコン列の中（`0 <= X < FIconBarWidth`、`Y >= 0`）で `IconPopupMenu` があれば、`PopupComponent := Self` にして画面の座標で `Popup`。キーボードのメニューキー（`X = -1`）では何も出さない。

### 7.3 ヒント（CMHintShow）

`inherited` のあと、マウスの下のアイコンのページの `Caption` が空でなければ、`HintStr := Caption`、`CursorRect := IconRect(P)`（枠の外へ出たら LCL が出し直す）。それ以外は `HintStr := ''`。

### 7.4 スプリッターのドラッグ

| 手続き | 処理 |
|---|---|
| `BeginSplitterDrag(X)` | 閉じていれば終わる。前の線が残っていたら消す。`FDragging := True`、`MouseCapture := True`（設計時はデザイナが MouseDown を直接呼ぶのでキャプチャされない。しないと、離したときに線のウィンドウが MouseUp を受けて線が残る）。開始位置・開始時の幅を覚える。`rsLine` なら黒（`GetStockObject(BLACK_BRUSH)`）、`rsPattern` なら `ThemeServices.DottedBrush` で、`SplitterRect` の画面座標に `CreateRubberband` |
| `MoveSplitterDrag(X)` | `FDragWidth := ClampPanelWidth(開始時の幅 + (X - 開始位置))`。`rsUpdate` なら `PanelWidth := FDragWidth`、`rsLine`・`rsPattern` なら `UpdateRubberBand`、`rsNone` は何もしない |
| `UpdateRubberBand` | `SplitterRect` を `FDragWidth - 開始時の幅` だけ右にずらし、画面座標で `SetRubberBandRect` |
| `EndSplitterDrag(X)` | `FDragging := False`、`MouseCapture := False`、線を消す。閉じていれば終わる。`PanelWidth := ClampPanelWidth(...)`。幅が変わっていれば、設計時は `OwnerFormDesignerModified(Self)`、実行時は `EventsEnabled` なら `FOnPanelResize` |
| `CancelSplitterDrag` | ドラッグ中でなければ終わる。`FDragging := False`、線を消し、`PanelWidth` が開始時と違えば戻す。`OnPanelResize` は出さない |
| `CaptureChanged` | `inherited` のあと、ドラッグ中で、キャプチャが外れ、左ボタンがまだ押されている（`GetKeyState(VK_LBUTTON) < 0`）なら `CancelSplitterDrag`（Alt+Tab などで外れたとき。ボタンを離したときは、このあとの MouseUp で終える） |

- 線は別ウィンドウ（`CreateRubberband`）なので、WebView2 の上にも出る（TSplitter と同じ）。

### 7.5 設計時のマウス（CMDesignHitTest）

デザイナは、マウスが押された・動いた・離されたたびにこのメッセージを送る。1 を返すとサイドバーの MouseDown・MouseMove・MouseUp が呼ばれ、0 ならデザイナが処理する（部品を選ぶ）。

Lazarus のデザイナには、(1) サイドバーが MouseUp を処理するとデザイナが押下中の部品を忘れない、(2) マウスが動いたときボタンを押していなくても「左ボタンが押されている」と扱う、という動きがある。この2つが重なると、アイコンをクリックした後にマウスを動かしただけで範囲選択の枠が出る。これを防ぐため、次の値を返す。

1. `ButtonsDown := (Keys and (MK_LBUTTON or MK_RBUTTON or MK_MBUTTON)) <> 0`。押されていれば `FDesignerPressLeft := False`。
2. ドラッグ中、または `FDownPage` があれば 1。
3. `FDesignerPressLeft` で、ボタンが押されていなければ 1。
4. アイコンの上、またはスプリッターの上なら 1。
5. それ以外は 0。

## 8. ショートカットキー（AppKeyDown）

`Application.AddOnKeyDownHandler` で受け取る。フォームの `OnKeyDown`（`KeyPreview`）、フォーカスのある部品、メニュー・ActionList のショートカットで使われなかったキーだけが届く。

1. `Key = 0`、または `EventsEnabled` でなければ終わる。
2. `Sender` が `TControl` でなければ終わる。`GetParentForm(Self)` と `GetParentForm(Sender)` が違えば終わる（同じフォームのキーだけ）。
3. サイドバーが `Enabled` かつ `IsVisible` でなければ終わる。
4. `SC := Menus.ShortCut(Key, Shift * [ssShift, ssAlt, ssCtrl])`。0 なら終わる。
5. ページを順に見て、`ShortCut = SC` の最初のページで：`PageVisible` かつ `Enabled` なら `UserTogglePage(P)`、`Key := 0`。どちらでも、そこで終わる。

## 9. 設計時（uCSideBarReg）

`Register`：

1. `CSideBarDesignSelect := @DesignSelect`（`GlobalDesignHook.SelectOnlyThis(AComponent)` を呼ぶ手続き）。
2. `RegisterComponents('CX', [TCSideBar])`。
3. `RegisterNoIcon([TCSideBarPage])`（ページはパレットに出さない）。
4. `RegisterComponentEditor(TCSideBar, TCSideBarEditor)`、`RegisterComponentEditor(TCSideBarPage, TCSideBarEditor)`（ページを選んだ状態でも同じメニューを出す）。

`TCSideBarEditor = class(TComponentEditor)`：操作するサイドバーは、選んでいる部品が `TCSideBarPage` ならその `SideBar`、ほかはその部品。

| 番号 | 表示 | 処理 |
|---|---|---|
| 0 | ページの追加 | `GetHook` できなければ終わる。Owner はサイドバーの Owner（なければサイドバー）で `TCSideBarPage.Create`。`Name := GetDesigner.CreateUniqueComponentName(ClassName)`、`Caption := Name`、`Parent := サイドバー`（一覧の末尾に入る）、`ActivePage := 新しいページ`（設計時なのでイベントは出ない）、`Hook.PersistentAdded(新しいページ, True)`、`Modified` |
| 1 | ページの削除 | 開いているページがなければ終わる。`Hook.DeletePersistent(ページ)`。このあとエディタ自身が解放されることがあるので、何もしない |
| 2 | 上へ移動 | 開いているページの番号 `Cur` が 0 以上で、`Cur - 1` が範囲内なら `MovePage(Cur, Cur - 1)`、`Modified` |
| 3 | 下へ移動 | 同じく `Cur + 1` へ |

`GetVerbCount` は 4。表示の文字は resourcestring（`rsCSideBarAddPage` など）。

## 10. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| 設計時に置いた部品がページでなくフォームに入る | `SetActiveState` の `csNoDesignVisible`（4.3） |
| 設計時、アイコンをクリックしたあと範囲選択の枠が出る | `CMDesignHitTest`・`FDesignerPressLeft`（7.5） |
| ドラッグの線が残る | `BeginSplitterDrag` の `MouseCapture`、`CaptureChanged`（7.4） |
| 起動時に開くページが違う・イベントが出る | `SetActivePage` の `csLoading`、`Loaded`（5.6、5.9） |
| 幅が2回変わってちらつく | `ChangeActivePage` の `DisableAutoSizing`（5.8） |
| ショートカットキーが効かない | `AppKeyDown` の 1〜3（8章）。メニュー・ActionList・部品がキーを使っていないか |
| ページの順番が .lfm と違う | `SetParent`（4.3）、`MovePage` の `SetControlIndex`（5.7） |
| 表示スケールで幅がずれる | 両方の `DoAutoAdjustLayout`（4.3、5.9） |
