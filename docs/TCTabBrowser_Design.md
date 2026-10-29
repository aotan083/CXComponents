# TCTabBrowser 設計書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 目的

TPageControl を元に、WebView2（WebView4Delphi の `TWVBrowser`・`TWVWindowParent`）を使ったタブ付きの Web ブラウザを作る。

- 1 タブ = `TTabSheet` 1 枚 ＋ `TWVWindowParent` 1 つ ＋ `TWVBrowser` 1 つ。3 つとも `TTabSheet` が持ち主（Owner）で、タブを `Free` すると一緒に消える。
- タブは 0 枚にしない。最後のタブを閉じると、部品が新しいタブを作る。
- ページが開こうとした新しいウィンドウは、常に止めて、新しいタブで開く。
- すべてのタブで、専用のデータフォルダー（EXE\TabBrowserData）を使う。データフォルダーが違うと別のブラウザのプロセスになるため、TCMonacoEditor などがキー入力の処理で止まっている間も、このブラウザは止まらない。
- WebView2 の準備（`GlobalWebView2Loader`）は、最初にタブを作るときに `CXStartWebView2`（9章）で行う。ユニットに initialization・finalization は持たない。
- 待つメソッド（`NavigateAndWait`・`RunScript`・保存）は、`Application.ProcessMessages` で待つ。待っている間にタブが消えても落ちないように、`FreeNotification` で見張る（7.3）。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCTabBrowser.pas` | cx（実行時） | `TCTabBrowser`・`TCTabPanel` と、内部用のクラス 3 つ（3章） |
| `uCXRuntime.pas` | cx（実行時） | WebView2.ini を読む関数と `CXStartWebView2`（9章）。TCMonacoEditor と共通 |
| `uCXReg.pas` | cxdsgn（設計時） | パレット [CX] への登録（`RegisterComponents('CX', [..., TCTabBrowser, ...])`） |
| `cx_icons.lrs` | cxdsgn（設計時） | アイコン（`TCTabBrowser`・`TCTabBrowser_150`・`TCTabBrowser_200`） |

- `uCTabBrowser` の uses：`Classes, SysUtils, Controls, ComCtrls, Forms, Windows, ActiveX, Menus, Contnrs, uWVBrowser, uWVWindowParent, uWVBrowserBase, uWVLoader, uWVTypeLibrary, uWVEvents, uWVTypes, uWVCoreWebView2Args, uWVCoreWebView2DownloadOperation, uWVCoreWebView2ContextMenuItem, uWVCoreWebView2ContextMenuItemCollection, fpjson, jsonparser`
- implementation の uses：`uCXRuntime`。
- cx の必要パッケージ：`LCL`、WebView4Delphi の Lazarus 用パッケージ。
- `{$MODE Delphi}`（イベントの代入に `@` を付けない）。

## 3. 型

```pascal
TTabDocumentCompleteEvent = procedure(Sender: TObject; ATabIndex: Integer; ASuccess: Boolean) of object;
TTabNewWindowRequestedEvent = procedure(Sender: TObject; ATabIndex: Integer; var AURI: string; var AAccept: Boolean) of object;
TTabBasicAuthenticationRequestedEvent = procedure(Sender: TObject; ATabIndex: Integer; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2BasicAuthenticationRequestedEventArgs) of object;
TTabDownloadStartingEvent = procedure(Sender: TObject; ATabIndex: Integer; const AURI: string; var AFileName: string; var ACancel: Boolean) of object;
TTabDownloadCompletedEvent = procedure(Sender: TObject; ATabIndex: Integer; const AFileName: string; ASuccess: Boolean) of object;
TTabScriptResultEvent = procedure(Sender: TObject; AID: Integer; ASuccess: Boolean; const AResultJson: string) of object;
TTabNewTabReason = (ntrMenuNew, ntrLastTabClosed);
TTabNewTabRequestEvent = procedure(Sender: TObject; AReason: TTabNewTabReason; var AURL: string; var AAccept: Boolean) of object;

// 内部用：ページ部分のメニューで選ばれたときに行うこと
TCTabPageMenuAction = (pmaNone, pmaNew, pmaClose, pmaApp);

// 内部用：ページ部分に足した項目 1 件
TCTabPageMenuItem = class
public
  Item: TCoreWebView2ContextMenuItem;  // WebView2 の項目のラッパー（選択通知の登録を持つ）
  CommandId: Integer;                  // WebView2 が振った番号
  Action: TCTabPageMenuAction;
  Source: TMenuItem;                   // pmaApp のときの元の項目（参照だけ）
  Browser: TWVBrowser;                 // 右クリックされたタブの Browser
  destructor Destroy; override;        // FreeAndNil(Item)（選択通知の登録も外れる）
end;

// 内部用：RunScriptAsync の結果待ち 1 件
TCTabScriptItem = class
public
  ID: Integer;
  Browser: TWVBrowser;
  Callback: TTabScriptResultEvent;
end;

// 内部用：見張っているダウンロード 1 件
TCTabDownloadItem = class
public
  Operation: TCoreWebView2DownloadOperation;
  Browser: TWVBrowser;
  destructor Destroy; override;        // FreeAndNil(Operation)（登録したイベントも外れる）
end;

// タブの情報への窓口。実体は持たず、TWVWindowParent を指すだけ
TCTabPanel = record
private
  FOwner: TCTabBrowser;
  FWindowParent: TWVWindowParent;      // nil なら、どの値も ''
public
  property Title: string read GetTitle;            // FOwner.GetTitleForWindowParent
  property URL: string read GetURL;                // FOwner.GetURLForWindowParent
  property SourceText: string read GetSourceText;  // FOwner.GetSourceTextForWindowParent
end;
```

## 4. フィールド

| 名前 | 型 | 初期値 | 中身 |
|---|---|---|---|
| `FHideSingleTab` | `Boolean` | `True` | `HideSingleTab` |
| `FUserAgent` | `string` | '' | `UserAgent` に書いた値 |
| `FIgnoreCertificateErrors` | `Boolean` | `True` | `IgnoreCertificateErrors` |
| `FSavePath` | `string` | `GetCurrentDir` | `SavePath` |
| `FOnDocumentComplete` ほか 6 つ | イベント | nil | 5章のイベント |
| `FWaitCompleted` | `Boolean` | `False` | 待っている処理が終わった |
| `FWaitSuccess` | `Boolean` | `False` | 待っている処理が成功した |
| `FWaitAborted` | `Boolean` | `False` | 待っている間に、見張っている Browser が消えた |
| `FWaitTargetComponent` | `TComponent` | nil | 待っている間に見張る Browser |
| `FRetrievedHTML` | `wvstring` | '' | `RetrieveHTML` の結果 |
| `FRetrievedMHTML` | `wvstring` | '' | `RetrieveMHTML` の結果 |
| `FRunScriptResult` | `wvstring` | '' | `RunScript` の結果 |
| `FRunScriptID` | `Integer` | 0 | `RunScript` が待っている実行 ID（0 = 待っていない） |
| `FScripts` | `TObjectList`（持ち主） | 空 | `TCTabScriptItem` の一覧 |
| `FScriptIDGen` | `Integer` | 0 | 実行 ID の採番 |
| `FDownloads` | `TObjectList`（持ち主） | 空 | `TCTabDownloadItem` の一覧 |
| `FDownloadIDGen` | `Integer` | 0 | ダウンロード ID の採番 |
| `FDataFolder` | `string` | EXE のフォルダー + `TabBrowserData` | 全タブのデータフォルダー |
| `FCacheSizeMB` | `Integer` | 0 | tabbrowser.json の `cacheSizeMB`（0 = 上限なし） |
| `FTabPopupMenu` | `TPopupMenu` | Create で作る | 見出しの右クリックメニュー（`PopupMenu` に入れる） |
| `FCloseMenuItem` | `TMenuItem` | Create で作る | 見出しのメニューの「閉じる」 |
| `FContextMenuTabIndex` | `Integer` | -1 | 見出しで右クリックしたタブ（「閉じる」で使う） |
| `FContextTabIndex` | `Integer` | -1 | `ContextTabIndex` |
| `FHeaderPopupMenu`・`FPagePopupMenu` | `TPopupMenu` | nil | アプリの項目 |
| `FOnNewTabRequest` | `TTabNewTabRequestEvent` | nil | イベント |
| `FPageMenuItems` | `TObjectList`（持ち主） | 空 | ページ部分に足した `TCTabPageMenuItem` |
| `FPendingAction` | `TCTabPageMenuAction` | `pmaNone` | ページ部分で選ばれ、メニューが閉じた後に行うこと |
| `FPendingItem` | `TMenuItem` | nil | そのときの元の項目 |
| `FPendingBrowser` | `TWVBrowser` | nil | そのときのタブの Browser（比べるだけ。中は触らない） |

## 5. 宣言

```pascal
protected
  procedure Resize; override;      // inherited のあと SynchronizeBounds
  procedure Change; override;      // inherited のあと SynchronizeBounds・SynchronizeVisibility
  procedure Notification(AComponent: TComponent; Operation: TOperation); override;
public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  function Add(const AURL: string = 'about:blank'): Integer;
  function Insert(i: Integer; const AURL: string = 'about:blank'): Integer;
  procedure Navigate(const AURL: string);
  function NavigateAndWait(const AURL: string; TimeoutMS: Integer = 60000): Boolean;
  procedure Back;
  procedure Next;
  procedure Reload;
  procedure LoadFromFile(const AFileName: string);
  procedure SaveToFile(sFileName: String);
  procedure SaveAsWebPage(sFileName: String);
  procedure SaveScreenCapture(const AFileName: string = '');
  procedure SavePDF(const AFileName: string = '');
  procedure Remove; overload;
  procedure Remove(i: Integer); overload;
  procedure SynchronizeBounds;
  procedure SynchronizeVisibility;
  function RunScript(const AScript: string; out AResultJson: string; ATimeoutMS: Integer = 30000): Boolean;
  function RunScriptAsync(ATabIndex: Integer; const AScript: string; ACallback: TTabScriptResultEvent): Integer;
  procedure CancelScriptAsync(AID: Integer);
  property Count: Integer read GetCount;                         // PageCount
  property ActiveIndex: Integer read GetActiveIndex write SetActiveIndex;
  property Panels[AIndex: Integer]: TCTabPanel read GetPanel;
  property ActiveTab: TCTabPanel read GetActiveTab;
  property ContextTabIndex: Integer read FContextTabIndex;
published
  property HideSingleTab: Boolean read FHideSingleTab write SetHideSingleTab default True;
  property UserAgent: string read GetUserAgent write SetUserAgent;
  property IgnoreCertificateErrors: Boolean read FIgnoreCertificateErrors write SetIgnoreCertificateErrors default True;
  property OnDocumentComplete: TTabDocumentCompleteEvent read FOnDocumentComplete write FOnDocumentComplete;
  property OnNewWindowRequested: TTabNewWindowRequestedEvent read FOnNewWindowRequested write FOnNewWindowRequested;
  property OnBasicAuthenticationRequested: TTabBasicAuthenticationRequestedEvent read FOnBasicAuthenticationRequested write FOnBasicAuthenticationRequested;
  property SavePath: string read FSavePath write FSavePath;
  property OnDownloadStarting: TTabDownloadStartingEvent read FOnDownloadStarting write FOnDownloadStarting;
  property OnDownloadCompleted: TTabDownloadCompletedEvent read FOnDownloadCompleted write FOnDownloadCompleted;
  property HeaderPopupMenu: TPopupMenu read FHeaderPopupMenu write SetHeaderPopupMenu;
  property PagePopupMenu: TPopupMenu read FPagePopupMenu write SetPagePopupMenu;
  property OnNewTabRequest: TTabNewTabRequestEvent read FOnNewTabRequest write FOnNewTabRequest;
```

- TPageControl から引き継いだ published プロパティ・イベントは、そのまま出す（取扱説明書 3.2・5.2）。

## 6. 作る・壊す

Create：

1. `inherited`。4章の初期値を入れる。3 つの `TObjectList` は `OwnsObjects = True` で作る。
2. `FDataFolder := ExtractFilePath(ParamStr(0)) + 'TabBrowserData'`。設計時でなければ `LoadSettings`（7.11）。
3. `Options := [nboShowCloseButtons]`、`OnCloseTabClicked := DoCloseTabClicked`。
4. `FTabPopupMenu` を作り（持ち主は Self）、「閉じる」（`CloseMenuItemClick`）を 1 つ入れる。`PopupMenu := FTabPopupMenu`、`OnContextPopup := HandleTabContextPopup`。

- Create では WebView2 に触らない（IDE でも安全にするため）。

Destroy：

1. `FreeAndNil(FDownloads)`・`FreeAndNil(FScripts)`（タブの Browser が消える前に、登録したイベントを外す）。
2. `Application.RemoveAsyncCalls(Self)`（メニューが閉じた後に行う予定を取り消す）。
3. `FreeAndNil(FPageMenuItems)`。
4. `inherited`（タブ・Browser が消える）。

- `GlobalWebView2Loader` は解放しない（WebView4Delphi の `uWVLoader` の finalization が解放する）。

## 7. 処理

### 7.1 タブを作る（Add・Insert）

`Add(AURL)` は `Insert(PageCount, AURL)`。

`Insert(i, AURL)`：

1. `if not CXStartWebView2(Err) then raise Exception.Create(Err)`（9章）。
2. `i` を 0 ～ `PageCount` に収める。
3. `TTabSheet` を作り（持ち主は Self）、`PageControl := Self`、`PageIndex := i`。
4. `TWVWindowParent` を作り（持ち主はタブ）、`Parent` をタブ、`Align := alClient`。
5. `TWVBrowser` を作り（持ち主はタブ）、次のイベントをつなぐ。

   | Browser のイベント | つなぐ先 |
   |---|---|
   | `OnAfterCreated` | `BrowserAfterCreated` |
   | `OnAcceleratorKeyPressed` | `BrowserAcceleratorKeyPressed`（7.2） |
   | `OnNavigationCompleted` | `BrowserNavigationCompleted`（7.6） |
   | `OnNewWindowRequested` | `BrowserNewWindowRequested`（7.6） |
   | `OnBasicAuthenticationRequested` | `BrowserBasicAuthenticationRequested`（7.6） |
   | `OnDocumentTitleChanged` | `BrowserDocumentTitleChanged`（7.6） |
   | `OnDownloadStarting` | `BrowserDownloadStarting`（7.8） |
   | `OnDownloadStateChanged` | `BrowserDownloadStateChanged`（7.8） |
   | `OnExecuteScriptCompleted` | `BrowserExecuteScriptCompleted`（7.7） |
   | `OnContextMenuRequested` | `BrowserContextMenuRequested`（7.9） |
   | `OnCustomItemSelected` | `BrowserCustomItemSelected`（7.9） |

6. `DefaultURL := AURL`、`WindowParent.Browser := Browser`。
7. `Result := タブの PageIndex`、`Caption := 'タブ ' + (Result + 1)`。
8. `ActivePageIndex := Result`、`SynchronizeVisibility`、`UpdateTabHeaderVisibility`。
9. `AllowHostInputProcessing := True`（作る前に設定する決まりのため、`CreateBrowser` の前）。
10. `UserDataFolder := FDataFolder`。`FCacheSizeMB > 0` なら `AdditionalBrowserArguments := '--disk-cache-size=' + (FCacheSizeMB × 1024 × 1024)`（Int64 で計算）。
11. `CreateBrowser(WindowParent.Handle, False)`（False：既定の環境ではなく、`UserDataFolder` の環境を作る）。作るのは非同期。できると `BrowserAfterCreated` が呼ばれ、`DefaultURL` へ自動で移る。

`BrowserAfterCreated`：`SynchronizeBounds`、`SynchronizeVisibility`（`IsVisible` はこの時点から効く）、`FUserAgent <> ''` なら `UserAgent` を設定、`IgnoreCertificateErrors` を設定。

### 7.2 表示

| 手続き | 処理 |
|---|---|
| `FindWindowParent(Sheet)` | タブの `Controls` から最初の `TWVWindowParent` を返す。無ければ nil |
| `SynchronizeBounds` | 表示中のタブの `WindowParent.UpdateSize` |
| `SynchronizeVisibility` | 全タブの `Browser.IsVisible := (番号 = ActivePageIndex)` |
| `UpdateTabHeaderVisibility` | `ShowTabs := not (FHideSingleTab and (PageCount <= 1))` |
| `SetActiveIndex(V)` | 0 ～ `PageCount - 1` のときだけ、`ActivePageIndex := V`、`SynchronizeBounds`、`SynchronizeVisibility` |
| `SetUserAgent(V)` | 違えば覚え、`Initialized` の全タブに設定する（まだのタブは `BrowserAfterCreated` で設定） |
| `SetIgnoreCertificateErrors(V)` | 同じ考え方 |
| `GetUserAgent` | 表示中のタブが `Initialized` ならその `UserAgent`、でなければ `FUserAgent` |
| `BrowserAcceleratorKeyPressed` | `KEY_DOWN` で `VK_F5` のときだけ `Reload`、`Set_Handled(1)`（キーを離したとき・リピートは見ない） |

### 7.3 待つ方式（共通の型）

`NavigateAndWait`・`SaveToFile`・`SaveAsWebPage`・`SaveScreenCapture`・`SavePDF`・`GetSourceTextForWindowParent`・`RunScript` は、同じ型で待つ。

1. 表示中のタブの Browser を取る。無い・`Initialized` でない（`NavigateAndWait` は除く）なら何もしない。
2. Browser の完了イベントを、元のハンドラを覚えてから、待つ用のハンドラに差し替える（`RunScript` は差し替えない。7.7）。
3. `FWaitCompleted`・`FWaitSuccess`・`FWaitAborted := False`。
4. `FWaitTargetComponent := Browser`、`Browser.FreeNotification(Self)`。
5. 処理を始める。始められなければ抜ける。
6. `while not (FWaitCompleted or FWaitAborted) do Application.ProcessMessages`。
7. finally：`FWaitAborted` でなければ、`RemoveFreeNotification` とハンドラを元に戻す。`FWaitTargetComponent := nil`。

- `Notification`：`opRemove` で `AComponent = FWaitTargetComponent` なら `FWaitAborted := True`。消えた Browser には以後触らない。
- 待つ用のハンドラは、`FWaitCompleted := True` と結果を入れるだけ。
- 待つ状態は 1 つしか持たない。待っている間に、同じ部品のほかの待つメソッドを呼ぶと、状態が上書きされる（取扱説明書に書いてある決まり）。

| メソッド | 差し替えるイベント | 始める処理 | 上限 |
|---|---|---|---|
| `NavigateAndWait` | `OnNavigationCompleted` → `NavigateAndWaitHandler`（`Get_IsSuccess`） | `Navigate(AURL)`（先に呼ぶ） | `TimeoutMS`（`GetTickCount64`） |
| `SaveToFile`・`GetSourceTextForWindowParent` | `OnRetrieveHTMLCompleted` → `SaveToFileHandler` | `RetrieveHTML` | なし |
| `SaveAsWebPage` | `OnRetrieveMHTMLCompleted` → `SaveAsWebPageHandler` | `RetrieveMHTML` | なし |
| `SaveScreenCapture` | `OnCapturePreviewCompleted` → `CapturePreviewHandler`（`AErrorCode = 0`） | `CapturePreview(JPEG, IStream)` | なし |
| `SavePDF` | `OnPrintToPdfCompleted` → `PrintToPdfHandler`（`AIsSuccess`） | `PrintToPdf(パス)` | なし |
| `RunScript` | 差し替えない | `ExecuteScript(AScript, ID)` | `ATimeoutMS`（0 以下は上限なし。`GetTickCount`） |

- `NavigateAndWait` は、最初の `Navigate` でタブを作った場合も、作ったタブの Browser を見張る。

### 7.4 ページの移動

| 手続き | 処理 |
|---|---|
| `Navigate(URL)` | `PageCount = 0` なら `Add(URL)`。表示中のタブが `Initialized` なら `Browser.Navigate`、まだなら `DefaultURL := URL` |
| `Back`・`Next`・`Reload` | 表示中のタブの `GoBack`・`GoForward`・`Refresh` |
| `LoadFromFile(F)` | `Navigate('file:///' + F の '\' を '/' にしたもの)` |

### 7.5 保存

| メソッド | 処理 |
|---|---|
| `SaveToFile(F)` | 7.3 で HTML を取る。失敗・空なら保存しない。フォルダーが無ければ `ForceDirectories`。`TStringStream.SaveToFile`（上書き。書けなければ例外のまま） |
| `SaveAsWebPage(F)` | 同じ（MHTML） |
| `SaveScreenCapture(F)` | ファイル名を決め（下）、フォルダーを作り、`TFileStream.Create(パス, fmCreate)` を `TStreamAdapter`（`soReference`）で包んで `CapturePreview` に渡し、7.3 で待つ。最後に `FS.Free` |
| `SavePDF(F)` | ファイル名を決め、フォルダーを作り、`PrintToPdf` を 7.3 で待つ |

- ファイル名を省いたとき：`DocumentTitle`（空なら 'capture'）の `\ / : * ? " < > |` を '_' にし、`IncludeTrailingPathDelimiter(FSavePath) + タイトル + '.jpg'`（PDF は '.pdf'）。
- `SaveScreenCapture` は、ファイルを先に作るため、取れなかったときも空のファイルが残る。
- `TStringStream` を使う理由：`TStringList` は改行で分けて作り直すため、大きなページで無駄になる。

### 7.6 Browser のイベントの橋渡し

タブの番号は、`Sender`（`TWVBrowser`）の `Owner`（`TTabSheet`）の `PageIndex`（`TabIndexOfBrowser`。見つからなければ -1）。

| 手続き | 処理 |
|---|---|
| `BrowserNavigationCompleted` | `OnDocumentComplete` があれば、`Get_IsSuccess` を `ASuccess` にして呼ぶ |
| `BrowserNewWindowRequested` | 必ず `Set_Handled(1)`（ポップアップを開かない）。`Get_uri` で URI を取り（`CoTaskMemFree` で解放）、`Accept := True` で `OnNewWindowRequested` を呼ぶ。`Accept` で URI が空でなければ `Add(URI)` |
| `BrowserBasicAuthenticationRequested` | `OnBasicAuthenticationRequested` があれば、`AWebView`・`AArgs` をそのまま渡す。無ければ何もしない（WebView2 の標準の画面） |
| `BrowserDocumentTitleChanged` | `DocumentTitle` が空でなければ、そのタブの `Caption` にする |

### 7.7 JavaScript の実行

実行 ID：`NextScriptID` が 1 ～ 9999 で回す。10000 以上は WebView4Delphi が自分の処理（`RetrieveHTML` など）に使い、その結果は `OnExecuteScriptCompleted` に来ないため使わない。0 は「待っていない」の意味。

| 手続き | 処理 |
|---|---|
| `RunScript` | 表示中のタブが `Initialized` でなければ `False`。`FRunScriptID := NextScriptID` で 7.3 の型で待つ。終わったら `AResultJson := FRunScriptResult`、`Result := FWaitSuccess`。finally で `FRunScriptID := 0` |
| `RunScriptAsync(T, S, CB)` | `T` が範囲の外・`Initialized` でなければ 0。`TCTabScriptItem`（ID・Browser・CB）を `FScripts` に足して `ExecuteScript(S, ID)`。始められなければ外して 0。ID を返す |
| `CancelScriptAsync(ID)` | `FScripts` からその ID を消す |
| `ReleaseScriptsOf(B)` | `FScripts` から Browser が `B` のものを消す（知らせない） |
| `BrowserExecuteScriptCompleted` | `FRunScriptID <> 0` で ID が同じなら `ExecuteScriptHandler`（`FWaitCompleted := True`、成功は `AErrorCode = 0`、結果を入れる）。でなければ `FScripts` から ID と Browser が同じものを探し、一覧から消してから `CB(Self, ID, AErrorCode = 0, 結果)`。どちらにも無ければ捨てる |

- `RunScriptAsync` は `ProcessMessages` を呼ばない。

### 7.8 ダウンロード

`BrowserDownloadStarting`：`OnDownloadStarting` も `OnDownloadCompleted` も無ければ何もしない（WebView2 の標準の動き）。

1. `TCoreWebView2DownloadStartingEventArgs` で包む。`DownloadOperation` が無ければ抜ける。
2. `Inc(FDownloadIDGen)`、`TCoreWebView2DownloadOperation.Create(…, FDownloadIDGen)`。
3. `OnDownloadStarting` があれば、`URI`・`ResultFilePath`（初期値）・`Cancel = False` で呼ぶ。`Cancel` なら `Args.Cancel := True` で抜ける。ファイル名が空でなければ `ResultFilePath` に入れ、`Handled := True`（標準の表示を出さない）。
4. `OnDownloadCompleted` があり、`Op.AddAllBrowserEvents(Browser)` が成功したら、`TCTabDownloadItem` にして `FDownloads` に足す（`AddStateChangedEvent` は protected のため、公開されている `AddAllBrowserEvents` を使う。進み具合のイベントも登録されるが使わない）。足さなかった `Op` は解放する。

`BrowserDownloadStateChanged`：`FDownloads` から ID が同じものを探す。`IN_PROGRESS` なら何もしない。それ以外は、一覧から `Extract` してから（中で同じ処理が来ても 2 回知らせない）`OnDownloadCompleted(Self, タブ, ResultFilePath, State = COMPLETED)` を呼び、`Free`。

`ReleaseDownloadsOf(B)`：Browser が `B` のものを消す（知らせない）。

### 7.9 右クリックメニュー

**見出し**（`HandleTabContextPopup`）

1. `FContextMenuTabIndex := IndexOfTabAt(X, Y)`。タブが無い所なら `Handled := True`（出さない）で抜ける。
2. `FContextTabIndex := FContextMenuTabIndex`。
3. `FTabPopupMenu` から「閉じる」以外を消す。
4. `FHeaderPopupMenu` があれば、`OnPopup` を呼ぶ。呼んだ後も `FHeaderPopupMenu` があれば、区切り線を足し、`CopyMenuToHeader` で写す。最後が区切り線なら消す。

`CopyMenuToHeader(Src, Dest)`：`Visible` の項目だけ、`TMenuItem` を作る（持ち主は `FTabPopupMenu`）。区切り線は '-'。それ以外は `Caption`・`Enabled`・`Checked`・`ShortCut` を写し、`Tag := PtrInt(元の項目)`。子が無ければ `OnClick := HeaderCopyItemClick`、子があれば同じ手続きで写す。

`HeaderCopyItemClick`：`Tag` の元の項目が、まだ `FHeaderPopupMenu` の中にあれば（`MenuContainsItem`。ポインタを比べるだけ）`Click`。

`CloseMenuItemClick`：`Remove(FContextMenuTabIndex)`。`DoCloseTabClicked`：`Sender` が `TTabSheet` ならそのタブ、`Sender = Self` なら表示中のタブを `Remove`。

**ページ**（`BrowserContextMenuRequested`）

1. `ReleasePageMenuItemsOf(nil)`（前回足した項目を消す）。
2. `FContextTabIndex := TabIndexOfBrowser(Browser)`。
3. 標準の項目は止めない（`Handled` は設定しない）。その後ろに、区切り線、「新規作成」（`pmaNew`）、「閉じる」（`pmaClose`）を足す。
4. `FPagePopupMenu` があれば `OnPopup` を呼ぶ。呼んだ後も `FPagePopupMenu` があり、見える項目が 1 つでもあれば（`HasVisibleItem`）、区切り線を足して `CopyMenuToPage` で写す。

`AddPageMenuItem`：`CoreWebView2Environment.CreateContextMenuItem` で作る（古いランタイムで作れなければ何も足さない）。`TCTabPageMenuItem` に `CommandId`・`Action`・`Source`・`Browser` を入れ、区切り線以外は `IsEnabled`、チェックは `IsChecked`。`pmaNone` 以外は `AddAllBrowserEvents(Browser)`（選ばれたときに `OnCustomItemSelected` が来るようにする）。`AppendValue` に成功したら `FPageMenuItems` に足して返す。

`CopyMenuToPage`：`Visible` だけ。区切り線 → `SEPARATOR`、子あり → `SUBMENU`（子を同じ手続きで写す）、`Checked` → `CHECK_BOX`（`pmaApp`）、それ以外 → `COMMAND`（`pmaApp`）。アイコンとショートカットキーは写さない（WebView2 のメニューでは出ない）。

`BrowserCustomItemSelected`：`CommandId` と Browser が同じ項目を探し、`pmaNone` 以外なら `FPendingAction`・`FPendingItem`・`FPendingBrowser` に入れて `Application.QueueAsyncCall(DoPendingMenu, 0)`。WebView2 のイベントの中でタブ（Browser）を消さないため、その場では実行しない。

`DoPendingMenu`：`FindTabOfBrowser(FPendingBrowser)`（ポインタを比べるだけ。消えていれば -1）を `FContextTabIndex` に入れ、予定を消してから実行する。`pmaNew` → `NewTabMenuClick`、`pmaClose` → タブがあれば `Remove`、`pmaApp` → 元の項目が `FPagePopupMenu` の中にまだあれば `Click`。

**`HeaderPopupMenu`・`PagePopupMenu` の設定**：前の値が、もう一方と違うときだけ `RemoveFreeNotification`。新しい値に `FreeNotification`。`Notification` の `opRemove` で、消えたものを nil にする。

### 7.10 タブを閉じる（Remove）・新しいタブ

`Remove` は `Remove(ActivePageIndex)`。

`Remove(i)`：

1. 範囲の外なら何もしない。
2. `LastURL := 'about:blank'`。`PageCount = 1` なら `LastURL := DoNewTabRequest(ntrLastTabClosed)`。閉じるタブの `Source` が `LastURL` と同じ（大文字小文字を区別しない）なら何もしない（消して同じタブを作る無駄をしない）。
3. 閉じた後に表示するタブ：`i < 表示中` なら 1 つ前へずらす。`i = 表示中` なら、右隣があれば `i`、無ければ `i - 1`。`i > 表示中` なら変えない。
4. そのタブの Browser の `ReleaseDownloadsOf`・`ReleaseScriptsOf`・`ReleasePageMenuItemsOf`（Browser が消える前に、登録したイベントを外す）。
5. `Pages[i].Free`。
6. `PageCount = 0` なら `Add(LastURL)` で抜ける。
7. 3 の番号を範囲に収めて `ActivePageIndex` にし、`SynchronizeBounds`・`SynchronizeVisibility`・`UpdateTabHeaderVisibility`。

`DoNewTabRequest(Reason)`：`URL := 'about:blank'`、`Accept := True` で `OnNewTabRequest` を呼ぶ。`Accept = False` なら、`ntrMenuNew` は '' を返し、`ntrLastTabClosed` は 'about:blank' にする。URL が空なら 'about:blank'。

`NewTabMenuClick`：`DoNewTabRequest(ntrMenuNew)` が空でなければ `Add`。

### 7.11 設定ファイル（LoadSettings）

1. `FCacheSizeMB := 0`。
2. パス：`CXResolveRuntimeDir('', 'MonacoFolder', 'monaco') + PathDelim + 'tabbrowser.json'`（9章。WebView2.ini の `MonacoFolder`、空なら EXE\monaco）。
3. 無ければ、`ForceDirectories` でフォルダーを作り、`{ "cacheSizeMB": 0 }` を書いて抜ける。
4. あれば読み、`GetJSON` が `TJSONObject` なら `Get('cacheSizeMB', 0)`。0 未満は 0。
5. 例外はすべて受けて `FCacheSizeMB := 0`（書けない・読めないときは上限なしで動く）。

- WebView2.ini が無いときは、`CXResolveRuntimeDir` は EXE\monaco を返す（エラーにしない）。WebView2.ini が無いことは、最初の `Insert` で `CXStartWebView2` が知らせる。

## 8. TCTabPanel の値

| 手続き | 処理 |
|---|---|
| `GetPanel(i)` | 範囲の中なら `FindWindowParent(Pages[i])`、外なら nil を入れて返す |
| `GetActiveTab` | `FindWindowParent(ActivePage)` を入れて返す |
| `GetTitleForWindowParent` | Browser があれば `DocumentTitle`、無ければ '' |
| `GetURLForWindowParent` | Browser があれば `Source`、無ければ '' |
| `GetSourceTextForWindowParent` | `Initialized` でなければ ''。7.3 の型で `RetrieveHTML` を待ち、成功なら `FRetrievedHTML` |

## 9. WebView2 の準備（uCXRuntime）

CX の WebView2 部品（TCTabBrowser・TCMonacoEditor）が共通で使う。initialization・finalization は持たない（cx は IDE にも組み込まれるため、uses に入れただけでは何もしない）。

```pascal
function CXRuntimeIniValue(const AKey: string): string;
function CXFullPath(const APath: string): string;
function CXResolveRuntimeDir(const AProperty, AIniKey, ADefaultName: string): string;
function CXStartWebView2(out AError: string): Boolean;
```

| 関数 | 処理 |
|---|---|
| `CXRuntimeIniValue` | EXE のフォルダーの WebView2.ini の `[WebView2]` から `AKey` の値（前後の空白を除く）。最初の 1 回だけ ini を読み、セクションの「キー=値」を文字列で覚える。ini が無い・読めないときは、どのキーも ''（例外は出さない） |
| `CXFullPath` | '' なら ''。ドライブ名が無ければ EXE のフォルダーの後ろにつなぐ。`ExpandFileName` で '..' を取り除く |
| `CXResolveRuntimeDir` | `AProperty` が空でなければ `CXFullPath(AProperty)`。空なら ini の `AIniKey` が空でなければその `CXFullPath`。それも空なら EXE のフォルダー + `ADefaultName`。最後の '\' は取る |
| `CXStartWebView2` | 下 |

`CXStartWebView2(out AError)`：

1. `AError := ''`。
2. `GlobalWebView2Loader` があれば：`InitializationError` なら `AError := ErrorMessage`、`False`。でなければ `True`（2 回目からは何もしない。ほかの部品が先に作っていても同じ）。
3. EXE のフォルダーに WebView2.ini が無ければ、`AError := 'WebView2.ini が見つかりません: ' + パス`、`False`。
4. `GlobalWebView2Loader := TWVLoader.Create(nil)`、`ShowMessageDlg := False`（エラーはメッセージ箱を出さず、呼んだ側に返す）。
5. `LoaderDllPath`：ini の `LoaderDllPath` が空でなければ `CXFullPath` したもの（空なら設定しない。EXE のフォルダーの WebView2Loader.dll を使う）。
6. `UserDataFolder`：ini の `UserDataFolder` を `CXFullPath`。空なら EXE のフォルダー + `WebView2Data`。
7. `StartWebView2` が `False` なら、`AError := ErrorMessage`、`False`。でなければ `True`。

- `StartWebView2` は、ライブラリの読み込みとランタイムの版の確認までをその場で行い、既定の環境は非同期で作る。TCTabBrowser は既定の環境を使わず、タブごとに `CreateBrowser(…, False)` で `TabBrowserData` の環境を作る（ライブラリが読めていれば作れる）。
- `GlobalWebView2Loader` は解放しない（`uWVLoader` の finalization が解放する）。
- 失敗したローダーも残す（2 で同じエラーを返し続ける。作り直さない）。

## 10. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| タブを作ると例外 | `CXStartWebView2`（9章）。WebView2.ini、WebView2Loader.dll（64 ビット版）、WebView2 ランタイム |
| ページが出ない・大きさが合わない | `BrowserAfterCreated`、`SynchronizeBounds`（7.1・7.2） |
| 裏のタブが前に出る | `SynchronizeVisibility`、`Change`（7.2） |
| 待つメソッドが戻らない | 7.3 の差し替え。待っている間に別の待つメソッドを呼んでいないか |
| 待っている間にタブを閉じると落ちる | `Notification` と `FWaitAborted`（7.3） |
| `RunScript` の結果が来ない | 実行 ID が 10000 以上になっていないか、`FRunScriptID` の振り分け（7.7） |
| ダウンロードの終わりが来ない | `AddAllBrowserEvents` の成否、`FDownloads`（7.8） |
| ページの右クリックに項目が出ない | `CreateContextMenuItem` の成否（古いランタイム）、`HasVisibleItem`（7.9） |
| メニューで閉じると落ちる | `QueueAsyncCall(DoPendingMenu)` を通っているか（7.9） |
| 最後のタブを閉じるたびに作り直される | `OnNewTabRequest` の URL と `Source` の書き方の違い（7.10） |
| TCMonacoEditor と一緒に固まる | `UserDataFolder := FDataFolder` と `CreateBrowser(…, False)`（7.1） |
| キャッシュの上限が効かない | tabbrowser.json の場所（7.11）、`AdditionalBrowserArguments` |
