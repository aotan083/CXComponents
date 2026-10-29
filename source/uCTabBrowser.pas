{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
unit uCTabBrowser;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  Classes, SysUtils, Controls, ComCtrls, Forms, Windows, ActiveX, Menus, Contnrs,
  uWVBrowser, uWVWindowParent, uWVBrowserBase, uWVLoader,
  uWVTypeLibrary, uWVEvents, uWVTypes,
  uWVCoreWebView2Args, uWVCoreWebView2DownloadOperation,
  // 【右クリックメニュー】 ページ部分のメニューに項目を足すためのラッパー
  uWVCoreWebView2ContextMenuItem, uWVCoreWebView2ContextMenuItemCollection,
  fpjson, jsonparser;

type
  TCTabBrowser = class; // 前方宣言（TCTabPanelがTCTabBrowserを参照するため）

  // 【項番22】 ページ読み込み完了通知イベントの型
  TTabDocumentCompleteEvent = procedure(Sender: TObject; ATabIndex: Integer; ASuccess: Boolean) of object;

  // 【項番23・30】 新規ウィンドウ要求イベントの型。
  // AURIは書き換え可能。AAccept既定値はTrue（受け入れ＝自タブで開く）、
  // Falseにすればキャンセルできる。
  TTabNewWindowRequestedEvent = procedure(Sender: TObject; ATabIndex: Integer; var AURI: string; var AAccept: Boolean) of object;

  // 【項番25】 HTTP認証要求通知イベントの型（Argsをそのまま渡すため、
  // 呼び出し側でResponse.UserName/Password、Cancel等を直接操作できる）
  TTabBasicAuthenticationRequestedEvent = procedure(Sender: TObject; ATabIndex: Integer; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2BasicAuthenticationRequestedEventArgs) of object;

  // 【DL対応】 ダウンロード開始時。AFileName（保存先のフルパス）は書き換え可能。
  // 初期値はWebView2既定の保存先。ACancel := True で中止する。
  TTabDownloadStartingEvent = procedure(Sender: TObject; ATabIndex: Integer;
    const AURI: string; var AFileName: string; var ACancel: Boolean) of object;

  // 【DL対応】 ダウンロード終了時（成功・失敗・中断）
  TTabDownloadCompletedEvent = procedure(Sender: TObject; ATabIndex: Integer;
    const AFileName: string; ASuccess: Boolean) of object;

  // 【非同期スクリプト】 RunScriptAsync の結果通知。AID は RunScriptAsync の戻り値（受付番号）
  TTabScriptResultEvent = procedure(Sender: TObject; AID: Integer;
    ASuccess: Boolean; const AResultJson: string) of object;

  // 【右クリックメニュー】 部品が新しいタブを作る理由
  TTabNewTabReason = (
    ntrMenuNew,        // 右クリックメニューの「新規作成」
    ntrLastTabClosed   // 最後のタブを閉じたため、部品がタブを自動で作る
  );

  // 【右クリックメニュー】 新しいタブを作る前の通知。
  // AURL：開くURL（初期値 'about:blank'）。書き換え可能。
  // AAccept：既定 True。False で中止（ntrLastTabClosed のときは中止できず、about:blank で開く）
  TTabNewTabRequestEvent = procedure(Sender: TObject; AReason: TTabNewTabReason;
    var AURL: string; var AAccept: Boolean) of object;

  // 【右クリックメニュー】 ページ部分に足した項目が選ばれたときに行うこと（内部用）
  TCTabPageMenuAction = (
    pmaNone,   // 何もしない（区切り線・サブメニューの見出し）
    pmaNew,    // 「新規作成」
    pmaClose,  // 「閉じる」
    pmaApp     // アプリの TPopupMenu の項目（元の項目の Click を呼ぶ）
  );

  // 【右クリックメニュー】 ページ部分に足した項目1件分（内部用）。
  // WebView2 の項目のラッパーを持ち続け、選ばれたときに CommandId で探す。
  TCTabPageMenuItem = class
  public
    Item: TCoreWebView2ContextMenuItem; // WebView2 の項目（選択通知の登録を持つ）
    CommandId: Integer;                 // WebView2 が振った項目の番号
    Action: TCTabPageMenuAction;        // 選ばれたときに行うこと
    Source: TMenuItem;                  // pmaApp のときの元の項目（参照するだけ。使う前に存在を確かめる）
    Browser: TWVBrowser;                // 右クリックされたタブの Browser
    destructor Destroy; override;
  end;

  // 【非同期スクリプト】 結果待ち1件分（内部用）
  TCTabScriptItem = class
  public
    ID: Integer;
    Browser: TWVBrowser;
    Callback: TTabScriptResultEvent;
  end;

  // 【DL対応】 監視中のダウンロード1件分（内部用）
  TCTabDownloadItem = class
  public
    Operation: TCoreWebView2DownloadOperation;
    Browser: TWVBrowser;
    destructor Destroy; override;
  end;

  // タブ1枚分の情報（Title/URL/SourceText）への窓口となる軽量レコード。
  // 実体を持たず、対象のTWVWindowParentへの参照のみを保持する薄いラッパー。
  TCTabPanel = record
  private
    FOwner: TCTabBrowser;
    FWindowParent: TWVWindowParent;
    function GetTitle: string;
    function GetURL: string;
    function GetSourceText: string;
  public
    property Title: string read GetTitle;
    property URL: string read GetURL;
    property SourceText: string read GetSourceText;
  end;

  // メインコンポーネントクラス
  TCTabBrowser = class(TPageControl)
  private
    FRunScriptResult: wvstring;
    FHideSingleTab: Boolean;
    FUserAgent: string;
    FIgnoreCertificateErrors: Boolean;
    FWaitCompleted: Boolean;
    FWaitSuccess: Boolean;
    FRetrievedHTML: wvstring;
    FRetrievedMHTML: wvstring;
    FOnDocumentComplete: TTabDocumentCompleteEvent;
    FOnNewWindowRequested: TTabNewWindowRequestedEvent;
    FOnBasicAuthenticationRequested: TTabBasicAuthenticationRequestedEvent;
    FSavePath: string;
    FTabPopupMenu: TPopupMenu;
    FCloseMenuItem: TMenuItem;
    FContextMenuTabIndex: Integer;
    FWaitAborted: Boolean;
    FWaitTargetComponent: TComponent;
    // 【DL対応】
    FOnDownloadStarting: TTabDownloadStartingEvent;
    FOnDownloadCompleted: TTabDownloadCompletedEvent;
    FDownloads: TObjectList;   // TCTabDownloadItem の一覧（OwnsObjects=True）
    FDownloadIDGen: Integer;
    // 【別プロセス対応】 TabBrowser 専用のデータフォルダとキャッシュ上限
    FDataFolder: string;       // EXE\TabBrowserData
    FCacheSizeMB: Integer;     // tabbrowser.json の cacheSizeMB（0 = 上限なし）
    // 【非同期スクリプト】
    FScripts: TObjectList;     // TCTabScriptItem の一覧（OwnsObjects=True）
    FScriptIDGen: Integer;     // 実行ID（受付番号）の採番
    FRunScriptID: Integer;     // RunScript（待つ方式）が待っている実行ID（0 = 待っていない）
    // 【右クリックメニュー】
    FHeaderPopupMenu: TPopupMenu;  // 見出しのメニューに足すアプリの項目
    FPagePopupMenu: TPopupMenu;    // ページ部分のメニューに足すアプリの項目
    FContextTabIndex: Integer;     // 最後に右クリックしたタブの番号（-1 = まだ無い）
    FOnNewTabRequest: TTabNewTabRequestEvent;
    FPageMenuItems: TObjectList;   // ページ部分に足した項目（TCTabPageMenuItem、OwnsObjects=True）
    // ページ部分で選ばれた項目の、メニューが閉じた後に行う内容
    FPendingAction: TCTabPageMenuAction;
    FPendingItem: TMenuItem;       // pmaApp のときの元の項目（使う前に存在を確かめる）
    FPendingBrowser: TWVBrowser;   // 右クリックされたタブの Browser（比べるだけ。中身は触らない）

    // 【別プロセス対応】 tabbrowser.json（WebView2.ini の MonacoFolder のフォルダー）を読む（無ければ作る）
    procedure LoadSettings;

    procedure SetHideSingleTab(const AValue: Boolean);
    procedure SetUserAgent(const AValue: string);
    procedure SetIgnoreCertificateErrors(const AValue: Boolean);
    procedure UpdateTabHeaderVisibility;
    function GetCount: Integer;
    function GetActiveIndex: Integer;
    procedure SetActiveIndex(const AValue: Integer);
    function GetURLForWindowParent(AWP: TWVWindowParent): string;
    function GetTitleForWindowParent(AWP: TWVWindowParent): string;
    function GetSourceTextForWindowParent(AWP: TWVWindowParent): string;
    function GetUserAgent: string;
    function GetPanel(AIndex: Integer): TCTabPanel;
    function GetActiveTab: TCTabPanel;

    // ActiveページからTWVWindowParentを検索する
    function FindWindowParent(ATabSheet: TTabSheet): TWVWindowParent;

    // WebView2初期化完了時に呼ばれる（UpdateSize反映用）
    procedure BrowserAfterCreated(Sender: TObject);

    // NavigateAndWait用の一時的な完了検知ハンドラ
    procedure NavigateAndWaitHandler(ASender: TObject; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2NavigationCompletedEventArgs);

    // F5キー押下検知ハンドラ（Reload実行用）
    procedure BrowserAcceleratorKeyPressed(ASender: TObject; const AController: ICoreWebView2Controller; const AArgs: ICoreWebView2AcceleratorKeyPressedEventArgs);

    // 【項番22】 恒久的なOnNavigationCompletedハンドラ（OnDocumentCompleteへ橋渡し）
    procedure BrowserNavigationCompleted(ASender: TObject; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2NavigationCompletedEventArgs);

    // 【項番23】 恒久的なOnNewWindowRequestedハンドラ（OnNewWindowRequestedへ橋渡し）
    procedure BrowserNewWindowRequested(ASender: TObject; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2NewWindowRequestedEventArgs);

    // 【項番25】 恒久的なOnBasicAuthenticationRequestedハンドラ（OnBasicAuthenticationRequestedへ橋渡し）
    procedure BrowserBasicAuthenticationRequested(ASender: TObject; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2BasicAuthenticationRequestedEventArgs);

    // 【項番29】 タイトル確定時にTabSheet.Captionを自動更新する
    procedure BrowserDocumentTitleChanged(Sender: TObject);

    // 【DL対応】 恒久的なOnDownloadStartingハンドラ（OnDownloadStartingへ橋渡し）
    procedure BrowserDownloadStarting(Sender: TObject; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2DownloadStartingEventArgs);
    // 【DL対応】 恒久的なOnDownloadStateChangedハンドラ（OnDownloadCompletedへ橋渡し）
    procedure BrowserDownloadStateChanged(Sender: TObject; const ADownloadOperation: ICoreWebView2DownloadOperation; ADownloadID: Integer);
    // 【DL対応】 Browserからタブ番号を逆引きする（見つからなければ-1）
    function TabIndexOfBrowser(ABrowser: TObject): Integer;
    // 【DL対応】 指定Browserに属する監視中ダウンロードを破棄する（タブ削除前に呼ぶ）
    procedure ReleaseDownloadsOf(ABrowser: TWVBrowser);

    // 【項番33】 「×」ボタンクリック時のハンドラ（対象タブをRemoveする）
    procedure DoCloseTabClicked(Sender: TObject);

    // 【項番33】 右クリックメニュー「閉じる」用のハンドラ
    procedure HandleTabContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure CloseMenuItemClick(Sender: TObject);

    // SaveToFile用の一時的な完了検知ハンドラ
    procedure SaveToFileHandler(ASender: TObject; ASuccess: Boolean; const AHTML: wvstring);

    // SaveAsWebPage用の一時的な完了検知ハンドラ
    procedure SaveAsWebPageHandler(ASender: TObject; ASuccess: Boolean; const AMHTML: wvstring);

    // 【項番14】 SaveScreenCapture用の一時的な完了検知ハンドラ
    procedure CapturePreviewHandler(ASender: TObject; AErrorCode: HRESULT);

    // SavePDF用の一時的な完了検知ハンドラ
    procedure PrintToPdfHandler(ASender: TObject; AErrorCode: HRESULT; AIsSuccess: Boolean);

    // RunScript用の完了処理（BrowserExecuteScriptCompleted から呼ぶ）
    procedure ExecuteScriptHandler(ASender: TObject; AErrorCode: HRESULT; const AResultObjectAsJson: wvstring; AExecutionID: LongInt);

    // 【非同期スクリプト】 恒久的なOnExecuteScriptCompletedハンドラ。
    // 実行IDで RunScript の結果か、RunScriptAsync の結果かを振り分ける
    procedure BrowserExecuteScriptCompleted(ASender: TObject; AErrorCode: HRESULT; const AResultObjectAsJson: wvstring; AExecutionID: LongInt);
    // 【非同期スクリプト】 実行IDを採番する（1以上）
    function NextScriptID: Integer;
    // 【非同期スクリプト】 指定Browserの結果待ちを破棄する（タブ削除前に呼ぶ。通知はしない）
    procedure ReleaseScriptsOf(ABrowser: TWVBrowser);

    // 【右クリックメニュー】 プロパティの設定（破棄の通知を受けるため）
    procedure SetHeaderPopupMenu(const AValue: TPopupMenu);
    procedure SetPagePopupMenu(const AValue: TPopupMenu);
    // 【右クリックメニュー】 ページ部分の右クリック通知（標準メニューの後ろに項目を足す）
    procedure BrowserContextMenuRequested(Sender: TObject; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2ContextMenuRequestedEventArgs);
    // 【右クリックメニュー】 ページ部分に足した項目が選ばれたときの通知
    procedure BrowserCustomItemSelected(Sender: TObject; const AMenuItem: ICoreWebView2ContextMenuItem);
    // 【右クリックメニュー】 ページ部分で選ばれた項目を、メニューが閉じた後に実行する
    procedure DoPendingMenu(Data: PtrInt);
    // 【右クリックメニュー】 ページ部分に項目を1つ足し、一覧に記録する
    function AddPageMenuItem(const ACollection: ICoreWebView2ContextMenuItemCollection;
      ABrowser: TWVBrowser; const ALabel: string; AKind: TWVMenuItemKind;
      AAction: TCTabPageMenuAction; ASource: TMenuItem;
      AEnabled, AChecked: Boolean): TCoreWebView2ContextMenuItem;
    // 【右クリックメニュー】 アプリの項目を、ページ部分のメニューに写す（サブメニューは再帰）
    procedure CopyMenuToPage(ASrc: TMenuItem; const ACollection: ICoreWebView2ContextMenuItemCollection; ABrowser: TWVBrowser);
    // 【右クリックメニュー】 アプリの項目を、見出しのメニューに写す（サブメニューは再帰）
    procedure CopyMenuToHeader(ASrc, ADest: TMenuItem);
    // 【右クリックメニュー】 見出しに写した項目が選ばれたとき、元の項目の Click を呼ぶ
    procedure HeaderCopyItemClick(Sender: TObject);
    // 【右クリックメニュー】 ページ部分に足した項目を解放する（ABrowser=nil なら全部）
    procedure ReleasePageMenuItemsOf(ABrowser: TWVBrowser);
    // 【右クリックメニュー】 OnNewTabRequest を呼び、開くURLを返す（新規作成で中止なら空文字）
    function DoNewTabRequest(AReason: TTabNewTabReason): string;
    // 【右クリックメニュー】 「新規作成」：イベントで決めたURLで末尾にタブを追加する
    procedure NewTabMenuClick(Sender: TObject);
    // 【右クリックメニュー】 Browser のタブ番号を、ポインタを比べるだけで探す（破棄済みでも安全。無ければ -1）
    function FindTabOfBrowser(ABrowser: TWVBrowser): Integer;


  protected
    procedure Resize; override;
    procedure Change; override;
    // 待機中の対象コンポーネントが破棄された場合を検知する
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // 【項番1】 タブ追加
    function Add(const AURL: string = 'about:blank'): Integer;

    // 【項番4】 タブ挿入（iは0～PageCountの範囲にクランプされる）
    function Insert(i: Integer; const AURL: string = 'about:blank'): Integer;

    // 【項番5】 URL遷移・非同期
    procedure Navigate(const AURL: string);

    // 【項番6】 URL遷移・同期完了復帰
    function NavigateAndWait(const AURL: string; TimeoutMS: Integer = 60000): Boolean;

    // 【項番7】 前のページへ移動
    procedure Back;
    // 【項番8】 次のページへ移動
    procedure Next;

    // 【項番9】 ページの再読み込み（F5キーでも実行される）
    procedure Reload;

    // 【項番10】 テキストファイル読み込み表示
    procedure LoadFromFile(const AFileName: string);

    // 【項番11】 HTMLソーステキスト保存
    procedure SaveToFile(sFileName: String);

    // 【項番12】 Webページ全体保存（MHTML形式・1ファイル）
    procedure SaveAsWebPage(sFileName: String);

    // 【項番14】 全画面キャプチャ保存（JPEG形式）。AFileName省略時はページタイトルから自動生成
    procedure SaveScreenCapture(const AFileName: string = '');

    // PDF保存（PrintToPdfベース）。AFileName省略時はページタイトルから自動生成
    procedure SavePDF(const AFileName: string = '');

    // 【項番2】 アクティブタブ削除
    procedure Remove; overload;
    // 【項番3】 位置指定タブ削除
    procedure Remove(i: Integer); overload;

    // 現在のアクティブタブの表示領域サイズを同期する（公式UpdateSizeのみ使用）
    procedure SynchronizeBounds;

    // アクティブタブのみIsVisible=True、他タブはFalseに同期する
    procedure SynchronizeVisibility;

    // 任意のJavaScriptを実行し、完了まで待機して結果(JSON文字列)を受け取る汎用メソッド
    function RunScript(const AScript: string; out AResultJson: string; ATimeoutMS: Integer = 30000): Boolean;

    // 【非同期スクリプト】 タブ番号を指定してJavaScriptを実行し、結果を待たずにすぐ戻る。
    // 結果は ACallback で通知する。戻り値は受付番号（1以上）。実行できなければ 0。
    // 中で Application.ProcessMessages は呼ばない。
    function RunScriptAsync(ATabIndex: Integer; const AScript: string;
      ACallback: TTabScriptResultEvent): Integer;
    // 【非同期スクリプト】 結果待ちを取り消す。取り消した後は ACallback を呼ばない。
    // 呼ぶ側が先に破棄される場合は、必ず呼ぶこと。
    procedure CancelScriptAsync(AID: Integer);

    property Count: Integer read GetCount;
    property ActiveIndex: Integer read GetActiveIndex write SetActiveIndex;
    // タブ番号を指定して、そのタブのTitle/URL/SourceTextへアクセスする
    property Panels[AIndex: Integer]: TCTabPanel read GetPanel;
    // 現在表示中のタブのTitle/URL/SourceTextへアクセスする
    property ActiveTab: TCTabPanel read GetActiveTab;
    // 【右クリックメニュー】 最後に右クリックしたタブの番号（右クリックがまだ無いときは -1）。
    // アプリの TPopupMenu の OnPopup・項目の OnClick の中で使う。
    property ContextTabIndex: Integer read FContextTabIndex;
  published
    property HideSingleTab: Boolean read FHideSingleTab write SetHideSingleTab default True;
    // 【項番20】 User-Agent設定（未設定時はWebView2標準）
    property UserAgent: string read GetUserAgent write SetUserAgent;
    // 【項番32】 証明書エラー自動スキップ（既定値True。ライブラリ自体の既定はFalseのため注意）
    property IgnoreCertificateErrors: Boolean read FIgnoreCertificateErrors write SetIgnoreCertificateErrors default True;
    // 【項番22】 ページ読み込み完了通知
    property OnDocumentComplete: TTabDocumentCompleteEvent read FOnDocumentComplete write FOnDocumentComplete;
    // 【項番23・30】 新規ウィンドウ要求通知。既定（何もハンドラを書かない場合）は、
    // 要求されたURIをそのまま自タブ内に新規タブとして開く（ポップアップは開かせない）。
    // ハンドラ内でAAccept:=Falseにするとキャンセル、AURIを書き換えると別URLを開ける。
    property OnNewWindowRequested: TTabNewWindowRequestedEvent read FOnNewWindowRequested write FOnNewWindowRequested;
    // 【項番25】 HTTP認証要求通知（既定では何もしない＝WebView2標準の認証ダイアログが表示される）
    property OnBasicAuthenticationRequested: TTabBasicAuthenticationRequestedEvent read FOnBasicAuthenticationRequested write FOnBasicAuthenticationRequested;
    // 【項番14】 SaveScreenCaptureの保存先フォルダ（既定値：起動時のカレントフォルダ）
    property SavePath: string read FSavePath write FSavePath;
    // 【DL対応】 ダウンロード開始通知。ハンドラ有り：AFileNameを保存先に設定し、
    // WebView2標準のダウンロード表示は出さない。ハンドラ無し：WebView2標準の動作。
    property OnDownloadStarting: TTabDownloadStartingEvent read FOnDownloadStarting write FOnDownloadStarting;
    // 【DL対応】 ダウンロード終了通知（完了・中断・失敗）
    property OnDownloadCompleted: TTabDownloadCompletedEvent read FOnDownloadCompleted write FOnDownloadCompleted;
    // 【右クリックメニュー】 見出しのメニューで、「閉じる」の後ろに並べるアプリの項目
    property HeaderPopupMenu: TPopupMenu read FHeaderPopupMenu write SetHeaderPopupMenu;
    // 【右クリックメニュー】 ページ部分のメニューで、「閉じる」の後ろに並べるアプリの項目
    property PagePopupMenu: TPopupMenu read FPagePopupMenu write SetPagePopupMenu;
    // 【右クリックメニュー】 部品が新しいタブを作る前の通知（新規作成・最後のタブを閉じたとき）
    property OnNewTabRequest: TTabNewTabRequestEvent read FOnNewTabRequest write FOnNewTabRequest;
  end;

implementation

uses
  uCXRuntime;   { WebView2 の準備（CXStartWebView2）と、tabbrowser.json の場所（WebView2.ini の MonacoFolder） }

{ TCTabDownloadItem }

destructor TCTabDownloadItem.Destroy;
begin
  // TCoreWebView2DownloadOperationの破棄時に、登録済みのイベントも解除される
  FreeAndNil(Operation);
  inherited Destroy;
end;

{ TCTabPageMenuItem }

destructor TCTabPageMenuItem.Destroy;
begin
  // ラッパーの破棄時に、登録済みの選択通知も解除される
  FreeAndNil(Item);
  inherited Destroy;
end;

{ TCTabBrowser }

constructor TCTabBrowser.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FHideSingleTab := True;
  FUserAgent := '';
  FIgnoreCertificateErrors := True; // 【項番32】 仕様書通り既定値True
  FSavePath := GetCurrentDir; // 起動時点のカレントフォルダを既定値とする

  // 【DL対応】 監視中ダウンロードの一覧
  FDownloads := TObjectList.Create(True);
  FDownloadIDGen := 0;

  // 【非同期スクリプト】 結果待ちの一覧
  FScripts := TObjectList.Create(True);
  FScriptIDGen := 0;
  FRunScriptID := 0;

  // 【右クリックメニュー】 ページ部分に足した項目の一覧と、右クリックしたタブの番号
  FPageMenuItems := TObjectList.Create(True);
  FContextTabIndex := -1;
  FPendingAction := pmaNone;
  FPendingItem := nil;
  FPendingBrowser := nil;

  // 【別プロセス対応】 専用のデータフォルダと設定（設計時は読まない）
  FDataFolder := ExtractFilePath(ParamStr(0)) + 'TabBrowserData';
  FCacheSizeMB := 0;
  if not (csDesigning in ComponentState) then
    LoadSettings;

  // 【項番33】 各タブに「×」ボタンを表示し、クリック時にRemoveを実行する
  // （Windows環境では表示されない可能性があるため、右クリックメニューも併用する）
  Options := [nboShowCloseButtons];
  OnCloseTabClicked := DoCloseTabClicked;

  // 【項番33】 右クリックメニュー「閉じる」
  FContextMenuTabIndex := -1;
  FTabPopupMenu := TPopupMenu.Create(Self);
  FCloseMenuItem := TMenuItem.Create(FTabPopupMenu);
  FCloseMenuItem.Caption := '閉じる';
  FCloseMenuItem.OnClick := CloseMenuItemClick;
  FTabPopupMenu.Items.Add(FCloseMenuItem);
  Self.PopupMenu := FTabPopupMenu;
  Self.OnContextPopup := HandleTabContextPopup;
end;

destructor TCTabBrowser.Destroy;
begin
  // 【DL対応】 タブ（Browser）が破棄される前に、監視中ダウンロードを解放する
  FreeAndNil(FDownloads);
  // 【非同期スクリプト】 結果待ちを破棄する（通知はしない）
  FreeAndNil(FScripts);
  // 【右クリックメニュー】 メニューが閉じた後に実行する予定を取り消し、
  // ページ部分に足した項目を、タブ（Browser）が破棄される前に解放する
  if Assigned(Application) then
    Application.RemoveAsyncCalls(Self);
  FreeAndNil(FPageMenuItems);
  inherited Destroy;
end;

function TCTabBrowser.GetCount: Integer;
begin
  Result := PageCount;
end;

function TCTabBrowser.GetActiveIndex: Integer;
begin
  Result := ActivePageIndex;
end;

// 【項番17】 表示中URL
// 【項番19】 HTMLソース（呼び出した瞬間のスナップショット）
// 共通処理：指定したWindowParentからHTMLソースを取得（RetrieveHTML＋完了待ち）
function TCTabBrowser.GetSourceTextForWindowParent(AWP: TWVWindowParent): string;
var
  PrevHandler: TOnRetrieveHTMLCompletedEvent;
begin
  Result := '';

  if not Assigned(AWP) or not Assigned(AWP.Browser) then Exit;
  if not AWP.Browser.Initialized then Exit;

  PrevHandler := AWP.Browser.OnRetrieveHTMLCompleted;
  FWaitCompleted := False;
  FWaitSuccess := False;
  FWaitAborted := False;
  FRetrievedHTML := '';
  // SaveToFileと同じハンドラを再利用（FRetrievedHTMLに格納するだけの処理のため）
  AWP.Browser.OnRetrieveHTMLCompleted := SaveToFileHandler;

  FWaitTargetComponent := AWP.Browser;
  AWP.Browser.FreeNotification(Self);
  try
    if not AWP.Browser.RetrieveHTML then Exit;

    while not (FWaitCompleted or FWaitAborted) do
      Application.ProcessMessages;

    if FWaitAborted then Exit;
  finally
    if not FWaitAborted then
    begin
      AWP.Browser.RemoveFreeNotification(Self);
      AWP.Browser.OnRetrieveHTMLCompleted := PrevHandler;
    end;
    FWaitTargetComponent := nil;
  end;

  if FWaitSuccess then
    Result := string(FRetrievedHTML);
end;

// 【項番19】 HTMLソース（内部共通処理はGetSourceTextForWindowParentのまま）

// 【項番20】 User-Agent取得：アクティブタブが存在すれば、実際にブラウザが
// 使っているライブな値を返す（URL・Titleと同じ考え方）。
// タブが無ければ、次に作られるタブに使われる予定の値（FUserAgent）を返す。
function TCTabBrowser.GetUserAgent: string;
var
  WP: TWVWindowParent;
begin
  WP := FindWindowParent(ActivePage);
  if Assigned(WP) and Assigned(WP.Browser) and WP.Browser.Initialized then
    Result := string(WP.Browser.UserAgent)
  else
    Result := FUserAgent;
end;

// 共通処理：指定したWindowParentからURLを取得
function TCTabBrowser.GetURLForWindowParent(AWP: TWVWindowParent): string;
begin
  if Assigned(AWP) and Assigned(AWP.Browser) then
    Result := string(AWP.Browser.Source)
  else
    Result := '';
end;

// 共通処理：指定したWindowParentからタイトルを取得
function TCTabBrowser.GetTitleForWindowParent(AWP: TWVWindowParent): string;
begin
  if Assigned(AWP) and Assigned(AWP.Browser) then
    Result := string(AWP.Browser.DocumentTitle)
  else
    Result := '';
end;

// Panels[AIndex]の実体：対象タブのWindowParentを見つけて、
// 薄いラッパー（TCTabPanel）に詰めて返す
function TCTabBrowser.GetPanel(AIndex: Integer): TCTabPanel;
begin
  Result.FOwner := Self;
  if (AIndex >= 0) and (AIndex < PageCount) then
    Result.FWindowParent := FindWindowParent(Pages[AIndex])
  else
    Result.FWindowParent := nil;
end;

// ActiveTabの実体：現在のアクティブタブのWindowParentを詰めて返す
function TCTabBrowser.GetActiveTab: TCTabPanel;
begin
  Result.FOwner := Self;
  Result.FWindowParent := FindWindowParent(ActivePage);
end;

{ TCTabPanel }

function TCTabPanel.GetTitle: string;
begin
  if Assigned(FOwner) then
    Result := FOwner.GetTitleForWindowParent(FWindowParent)
  else
    Result := '';
end;

function TCTabPanel.GetURL: string;
begin
  if Assigned(FOwner) then
    Result := FOwner.GetURLForWindowParent(FWindowParent)
  else
    Result := '';
end;

function TCTabPanel.GetSourceText: string;
begin
  if Assigned(FOwner) then
    Result := FOwner.GetSourceTextForWindowParent(FWindowParent)
  else
    Result := '';
end;

procedure TCTabBrowser.SetActiveIndex(const AValue: Integer);
begin
  if (AValue >= 0) and (AValue < PageCount) then
  begin
    ActivePageIndex := AValue;
    SynchronizeBounds;
    SynchronizeVisibility;
  end;
end;

procedure TCTabBrowser.SetHideSingleTab(const AValue: Boolean);
begin
  if FHideSingleTab <> AValue then
  begin
    FHideSingleTab := AValue;
    UpdateTabHeaderVisibility;
  end;
end;

// 【項番21】 LCL公式のShowTabsプロパティ（TCustomTabControl由来）を利用。
// タブが1枚以下、かつHideSingleTab=Trueのときのみ非表示にする。
procedure TCTabBrowser.UpdateTabHeaderVisibility;
begin
  ShowTabs := not (FHideSingleTab and (PageCount <= 1));
end;

// 【項番20】 User-Agent設定：既存の初期化済みタブすべてに反映する
// （未初期化のタブは、初期化完了時にBrowserAfterCreated側で反映される）
procedure TCTabBrowser.SetUserAgent(const AValue: string);
var
  i: Integer;
  WP: TWVWindowParent;
begin
  if FUserAgent <> AValue then
  begin
    FUserAgent := AValue;

    for i := 0 to PageCount - 1 do
    begin
      WP := FindWindowParent(Pages[i]);
      if Assigned(WP) and Assigned(WP.Browser) and WP.Browser.Initialized then
        WP.Browser.UserAgent := wvstring(FUserAgent);
    end;
  end;
end;

// 【項番32】 証明書エラー自動スキップ：既存の初期化済みタブすべてに反映する
// （未初期化のタブは、初期化完了時にBrowserAfterCreated側で反映される）
procedure TCTabBrowser.SetIgnoreCertificateErrors(const AValue: Boolean);
var
  i: Integer;
  WP: TWVWindowParent;
begin
  if FIgnoreCertificateErrors <> AValue then
  begin
    FIgnoreCertificateErrors := AValue;

    for i := 0 to PageCount - 1 do
    begin
      WP := FindWindowParent(Pages[i]);
      if Assigned(WP) and Assigned(WP.Browser) and WP.Browser.Initialized then
        WP.Browser.IgnoreCertificateErrors := FIgnoreCertificateErrors;
    end;
  end;
end;

function TCTabBrowser.FindWindowParent(ATabSheet: TTabSheet): TWVWindowParent;
var
  i: Integer;
begin
  Result := nil;
  if not Assigned(ATabSheet) then Exit;

  for i := 0 to ATabSheet.ControlCount - 1 do
  begin
    if ATabSheet.Controls[i] is TWVWindowParent then
    begin
      Result := TWVWindowParent(ATabSheet.Controls[i]);
      Exit;
    end;
  end;
end;

procedure TCTabBrowser.BrowserAfterCreated(Sender: TObject);
begin
  // 初期化完了後、公式のUpdateSizeでサイズを反映
  // (Navigateはuses側のDefaultURL機構により自動実行される)
  SynchronizeBounds;

  // この時点で初めてIsVisibleの設定が有効になるため再同期する
  SynchronizeVisibility;

  // 【項番20】 共通のUserAgent設定を、初期化完了した本タブに反映する
  if (FUserAgent <> '') and (Sender is TWVBrowser) then
    TWVBrowser(Sender).UserAgent := wvstring(FUserAgent);

  // 【項番32】 共通のIgnoreCertificateErrors設定を、初期化完了した本タブに反映する
  if (Sender is TWVBrowser) then
    TWVBrowser(Sender).IgnoreCertificateErrors := FIgnoreCertificateErrors;
end;

// 【項番1】 Add の実装（末尾への Insert として実装）
function TCTabBrowser.Add(const AURL: string): Integer;
begin
  Result := Insert(PageCount, AURL);
end;

// 【項番4】 Insert の実装
function TCTabBrowser.Insert(i: Integer; const AURL: string): Integer;
var
  NewTabSheet: TTabSheet;
  NewWindowParent: TWVWindowParent;
  NewBrowser: TWVBrowser;
  ClampedIndex: Integer;
  Err: string;
begin
  // WebView2 の準備：ローダーが無ければ作って起動する（WebView2.ini を読む。uCXRuntime）。
  // ほかの部品が先に作っていれば、それを使う。準備できなければ、タブを作らずに例外を出す
  if not CXStartWebView2(Err) then
    raise Exception.Create(Err);

  // クランプ処理：正常範囲は 0 ～ PageCount
  ClampedIndex := i;
  if ClampedIndex < 0 then
    ClampedIndex := 0
  else if ClampedIndex > PageCount then
    ClampedIndex := PageCount;

  // 1. タブページの生成（Ownerを Self にすることで自動破棄される）
  NewTabSheet := TTabSheet.Create(Self);
  NewTabSheet.PageControl := Self;
  NewTabSheet.PageIndex := ClampedIndex; // 指定位置へ移動

  // 2. 表示領域コントロール (TWVWindowParent) の生成
  NewWindowParent := TWVWindowParent.Create(NewTabSheet);
  NewWindowParent.Parent := NewTabSheet;
  NewWindowParent.Align := alClient;

  // 3. ブラウザ本体 (TWVBrowser) の生成と紐付け
  NewBrowser := TWVBrowser.Create(NewTabSheet);
  NewBrowser.OnAfterCreated := BrowserAfterCreated;
  NewBrowser.OnAcceleratorKeyPressed := BrowserAcceleratorKeyPressed;
  // 【項番22】 恒久的なフック（NavigateAndWait等が一時的に上書きしても、
  // 処理完了後にPrevHandler経由でこのハンドラに復元される設計）
  NewBrowser.OnNavigationCompleted := BrowserNavigationCompleted;
  // 【項番23・30】 恒久的なフック（既定でポップアップを止め、自タブ内に開く）
  NewBrowser.OnNewWindowRequested := BrowserNewWindowRequested;
  // 【項番25】 恒久的なフック（既定では何もしない＝標準の認証ダイアログが表示される）
  NewBrowser.OnBasicAuthenticationRequested := BrowserBasicAuthenticationRequested;
  // 【項番29】 恒久的なフック（タイトル確定時にCaptionを自動更新）
  NewBrowser.OnDocumentTitleChanged := BrowserDocumentTitleChanged;
  // 【DL対応】 恒久的なフック（ハンドラ未設定時はWebView2標準の動作のまま）
  NewBrowser.OnDownloadStarting := BrowserDownloadStarting;
  NewBrowser.OnDownloadStateChanged := BrowserDownloadStateChanged;
  // 【非同期スクリプト】 恒久的なフック（実行IDで RunScript / RunScriptAsync に振り分ける）
  NewBrowser.OnExecuteScriptCompleted := BrowserExecuteScriptCompleted;
  // 【右クリックメニュー】 恒久的なフック（標準メニューの後ろに「新規作成」「閉じる」、アプリの項目を足す）
  NewBrowser.OnContextMenuRequested := BrowserContextMenuRequested;
  NewBrowser.OnCustomItemSelected := BrowserCustomItemSelected;
  NewBrowser.DefaultURL := wvstring(AURL);
  NewWindowParent.Browser := NewBrowser;

  Result := NewTabSheet.PageIndex;
  NewTabSheet.Caption := Format('タブ %d', [Result + 1]);

  // 4. アクティブ化
  ActivePageIndex := Result;
  SynchronizeVisibility;

  // 【項番21】 タブ枚数が変化したため、ヘッダー表示を再計算
  UpdateTabHeaderVisibility;

  // 5. WebView2初期化の起点（非同期。完了後にDefaultURLへ自動Navigateされる）
  // AllowHostInputProcessingは作成時オプションのため、CreateBrowser前に設定する
  NewBrowser.AllowHostInputProcessing := True;

  // 【別プロセス対応】 TCMonacoEditor 等とは別のブラウザのプロセスで動かす。
  // 専用のデータフォルダを使う環境を作ると、別のプロセスになる（全タブで同じフォルダ＝同じプロセス）。
  // こうすると、他の WebView2 がキー入力の処理で止まっている間も、このブラウザは止まらない。
  NewBrowser.UserDataFolder := wvstring(FDataFolder);
  if FCacheSizeMB > 0 then
    NewBrowser.AdditionalBrowserArguments :=
      wvstring('--disk-cache-size=' + IntToStr(Int64(FCacheSizeMB) * 1024 * 1024));
  NewBrowser.CreateBrowser(NewWindowParent.Handle, False);
end;

// 【項番5】 URL遷移・非同期
procedure TCTabBrowser.Navigate(const AURL: string);
var
  WP: TWVWindowParent;
begin
  // タブが1つも無い場合は、新規タブを作成して表示する
  if PageCount = 0 then
  begin
    Add(AURL);
    Exit;
  end;

  WP := FindWindowParent(ActivePage);
  if not Assigned(WP) or not Assigned(WP.Browser) then Exit;

  if WP.Browser.Initialized then
    WP.Browser.Navigate(wvstring(AURL))
  else
    WP.Browser.DefaultURL := wvstring(AURL);
end;

// NavigateAndWait用の一時的な完了検知ハンドラ
procedure TCTabBrowser.NavigateAndWaitHandler(ASender: TObject; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2NavigationCompletedEventArgs);
var
  TempIsSuccess: Integer;
begin
  FWaitCompleted := True;
  FWaitSuccess := False;

  if Assigned(AArgs) then
  begin
    // ICoreWebView2NavigationCompletedEventArgs.Get_IsSuccess は
    // 生のCOMメソッド（HResult返却、Integer out引数）
    // HResult = 0 は S_OK（成功）を意味する
    if AArgs.Get_IsSuccess(TempIsSuccess) = 0 then
      FWaitSuccess := (TempIsSuccess <> 0);
  end;
end;

// 【項番6】 URL遷移・同期完了復帰
function TCTabBrowser.NavigateAndWait(const AURL: string; TimeoutMS: Integer): Boolean;
var
  WP: TWVWindowParent;
  StartTick: QWord;
  PrevHandler: TOnNavigationCompletedEvent;
begin
  Result := False;

  // タブが無ければ作成、あれば遷移を開始（項番5のNavigateに委譲）
  Navigate(AURL);

  WP := FindWindowParent(ActivePage);
  if not Assigned(WP) or not Assigned(WP.Browser) then Exit;

  // 完了検知のため、既存のOnNavigationCompletedを退避して一時的にフック
  PrevHandler := WP.Browser.OnNavigationCompleted;
  FWaitCompleted := False;
  FWaitSuccess := False;
  FWaitAborted := False;
  WP.Browser.OnNavigationCompleted := NavigateAndWaitHandler;

  // 待機中にBrowserが破棄された場合を検知できるようにする
  FWaitTargetComponent := WP.Browser;
  WP.Browser.FreeNotification(Self);
  try
    StartTick := GetTickCount64;
    while not (FWaitCompleted or FWaitAborted) do
    begin
      Application.ProcessMessages;
      if FWaitAborted then Exit; // Browserは既に破棄中のため、以降は一切触らない
      if (GetTickCount64 - StartTick) >= QWord(TimeoutMS) then
        Exit; // タイムアウト：Resultはfalseのまま
    end;
    Result := FWaitSuccess;
  finally
    if not FWaitAborted then
    begin
      WP.Browser.RemoveFreeNotification(Self);
      WP.Browser.OnNavigationCompleted := PrevHandler;
    end;
    FWaitTargetComponent := nil;
  end;
end;

// 【項番7】 前のページへ移動
procedure TCTabBrowser.Back;
var
  WP: TWVWindowParent;
begin
  WP := FindWindowParent(ActivePage);
  if Assigned(WP) and Assigned(WP.Browser) then
    WP.Browser.GoBack;
end;

// 【項番8】 次のページへ移動
procedure TCTabBrowser.Next;
var
  WP: TWVWindowParent;
begin
  WP := FindWindowParent(ActivePage);
  if Assigned(WP) and Assigned(WP.Browser) then
    WP.Browser.GoForward;
end;

// 【項番9】 ページの再読み込み
procedure TCTabBrowser.Reload;
var
  WP: TWVWindowParent;
begin
  WP := FindWindowParent(ActivePage);
  if Assigned(WP) and Assigned(WP.Browser) then
    WP.Browser.Refresh;
end;

// F5キー押下検知ハンドラ
procedure TCTabBrowser.BrowserAcceleratorKeyPressed(ASender: TObject; const AController: ICoreWebView2Controller; const AArgs: ICoreWebView2AcceleratorKeyPressedEventArgs);
var
  TempKeyEventKind: COREWEBVIEW2_KEY_EVENT_KIND;
  TempVirtualKey: LongWord;
begin
  if not Assigned(AArgs) then Exit;

  // キー押下時のみ処理する（キー離し・自動リピート等の重複発火を避けるため、
  // KEY_DOWN以外は無視）
  if AArgs.Get_KeyEventKind(TempKeyEventKind) <> 0 then Exit;
  if TempKeyEventKind <> COREWEBVIEW2_KEY_EVENT_KIND_KEY_DOWN then Exit;

  if AArgs.Get_VirtualKey(TempVirtualKey) <> 0 then Exit;

  if TempVirtualKey = VK_F5 then
  begin
    Reload;
    AArgs.Set_Handled(1); // WebView側の既定動作（あれば）を抑止
  end;
end;

// 【項番22】 恒久的なOnNavigationCompletedハンドラ：
// どのタブ（Sender=Browserのownerから逆引き）が完了したかを判定し、
// OnDocumentCompleteとして通知する
procedure TCTabBrowser.BrowserNavigationCompleted(ASender: TObject; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2NavigationCompletedEventArgs);
var
  TabIdx: Integer;
  TempIsSuccess: Integer;
  Success: Boolean;
begin
  if not Assigned(FOnDocumentComplete) then Exit;

  TabIdx := -1;
  if (ASender is TWVBrowser) and Assigned(TWVBrowser(ASender).Owner) and
     (TWVBrowser(ASender).Owner is TTabSheet) then
    TabIdx := TTabSheet(TWVBrowser(ASender).Owner).PageIndex;

  Success := False;
  if Assigned(AArgs) then
  begin
    if AArgs.Get_IsSuccess(TempIsSuccess) = 0 then
      Success := (TempIsSuccess <> 0);
  end;

  FOnDocumentComplete(Self, TabIdx, Success);
end;

// 【項番23】 恒久的なOnNewWindowRequestedハンドラ：
// どのタブが要求元かを判定し、Argsをそのまま渡してOnNewWindowRequestedとして通知する
// 【項番23・30】 恒久的なOnNewWindowRequestedハンドラ：
// ポップアップを常に止め（Set_Handled）、要求されたURIを取得してAURIに詰める。
// ハンドラでAAccept=Trueのままなら、AURI（書き換え後の場合はその値）を
// 自タブ内に新規タブとして開く。AAccept=Falseならキャンセル（何も開かない）。
procedure TCTabBrowser.BrowserNewWindowRequested(ASender: TObject; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2NewWindowRequestedEventArgs);
var
  TabIdx: Integer;
  TempURIPtr: PWideChar;
  TempURI: string;
  Accept: Boolean;
begin
  if not Assigned(AArgs) then Exit;

  // ポップアップウィンドウとして開かれるのを常に止める
  AArgs.Set_Handled(1);

  TempURI := '';
  TempURIPtr := nil;
  if (AArgs.Get_uri(TempURIPtr) = 0) and Assigned(TempURIPtr) then
  begin
    TempURI := TempURIPtr;
    CoTaskMemFree(TempURIPtr);
  end;

  TabIdx := -1;
  if (ASender is TWVBrowser) and Assigned(TWVBrowser(ASender).Owner) and
     (TWVBrowser(ASender).Owner is TTabSheet) then
    TabIdx := TTabSheet(TWVBrowser(ASender).Owner).PageIndex;

  Accept := True; // 既定値：受け入れる（自タブで開く）
  if Assigned(FOnNewWindowRequested) then
    FOnNewWindowRequested(Self, TabIdx, TempURI, Accept);

  if Accept and (TempURI <> '') then
    Add(TempURI);
end;

// 【項番25】 恒久的なOnBasicAuthenticationRequestedハンドラ：
// どのタブが要求元かを判定し、Argsをそのまま渡してOnBasicAuthenticationRequestedとして通知する
procedure TCTabBrowser.BrowserBasicAuthenticationRequested(ASender: TObject; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2BasicAuthenticationRequestedEventArgs);
var
  TabIdx: Integer;
begin
  if not Assigned(FOnBasicAuthenticationRequested) then Exit;

  TabIdx := -1;
  if (ASender is TWVBrowser) and Assigned(TWVBrowser(ASender).Owner) and
     (TWVBrowser(ASender).Owner is TTabSheet) then
    TabIdx := TTabSheet(TWVBrowser(ASender).Owner).PageIndex;

  FOnBasicAuthenticationRequested(Self, TabIdx, AWebView, AArgs);
end;

// 【項番29】 タイトル確定時に、該当タブのTabSheet.Captionを自動更新する
procedure TCTabBrowser.BrowserDocumentTitleChanged(Sender: TObject);
var
  TabSheet: TTabSheet;
  NewTitle: string;
begin
  if not (Sender is TWVBrowser) then Exit;
  if not (Assigned(TWVBrowser(Sender).Owner) and (TWVBrowser(Sender).Owner is TTabSheet)) then Exit;

  TabSheet := TTabSheet(TWVBrowser(Sender).Owner);
  NewTitle := string(TWVBrowser(Sender).DocumentTitle);

  if NewTitle <> '' then
    TabSheet.Caption := NewTitle;
end;

// 【別プロセス対応】 tabbrowser.json を読む。場所は WebView2.ini の MonacoFolder のフォルダー
// （空なら EXE\monaco）。無ければフォルダーごと { "cacheSizeMB": 0 } で作る。
// 値が読めない場合は 0（上限なし）として扱う。
procedure TCTabBrowser.LoadSettings;
var
  Path: string;
  SL: TStringList;
  J: TJSONData;
begin
  FCacheSizeMB := 0;
  Path := CXResolveRuntimeDir('', 'MonacoFolder', 'monaco') + PathDelim + 'tabbrowser.json';
  SL := TStringList.Create;
  try
    try
      if not FileExists(Path) then
      begin
        ForceDirectories(ExtractFileDir(Path));
        SL.Text := '{ "cacheSizeMB": 0 }';
        SL.SaveToFile(Path);
        Exit;
      end;

      SL.LoadFromFile(Path);
      J := GetJSON(SL.Text);
      try
        if J is TJSONObject then
          FCacheSizeMB := TJSONObject(J).Get('cacheSizeMB', 0);
      finally
        J.Free;
      end;
      if FCacheSizeMB < 0 then FCacheSizeMB := 0;
    except
      FCacheSizeMB := 0; // 書けない・読めない場合は上限なしで動く
    end;
  finally
    SL.Free;
  end;
end;

// 【DL対応】 Browserの所有者（TTabSheet）からタブ番号を逆引きする
function TCTabBrowser.TabIndexOfBrowser(ABrowser: TObject): Integer;
begin
  Result := -1;
  if (ABrowser is TWVBrowser) and Assigned(TWVBrowser(ABrowser).Owner) and
     (TWVBrowser(ABrowser).Owner is TTabSheet) then
    Result := TTabSheet(TWVBrowser(ABrowser).Owner).PageIndex;
end;

// 【DL対応】 恒久的なOnDownloadStartingハンドラ：
// OnDownloadStartingにハンドラがある場合のみ介入する。
//   ・ハンドラのAFileNameを保存先に設定
//   ・WebView2標準のダウンロード表示を出さない（Handled）
//   ・ACancel=Trueなら中止
// ハンドラが無い場合はWebView2標準の動作のまま（今と同じ）。
// OnDownloadCompletedにハンドラがあれば、状態変化を監視して終了を通知する。
procedure TCTabBrowser.BrowserDownloadStarting(Sender: TObject; const AWebView: ICoreWebView2; const AArgs: ICoreWebView2DownloadStartingEventArgs);
var
  Args: TCoreWebView2DownloadStartingEventArgs;
  Op: TCoreWebView2DownloadOperation;
  Item: TCTabDownloadItem;
  TabIdx: Integer;
  TempURI, TempFileName: string;
  TempCancel: Boolean;
begin
  if not Assigned(AArgs) then Exit;
  if not (Assigned(FOnDownloadStarting) or Assigned(FOnDownloadCompleted)) then Exit;

  TabIdx := TabIndexOfBrowser(Sender);

  Args := TCoreWebView2DownloadStartingEventArgs.Create(AArgs);
  try
    if not Assigned(Args.DownloadOperation) then Exit;

    Inc(FDownloadIDGen);
    Op := TCoreWebView2DownloadOperation.Create(Args.DownloadOperation, FDownloadIDGen);
    try
      // 呼び出し側へ開始を通知（保存先の変更・中止の判断）
      if Assigned(FOnDownloadStarting) then
      begin
        TempURI := string(Op.URI);
        TempFileName := string(Args.ResultFilePath); // 初期値：WebView2既定の保存先
        TempCancel := False;

        FOnDownloadStarting(Self, TabIdx, TempURI, TempFileName, TempCancel);

        if TempCancel then
        begin
          Args.Cancel := True;
          FreeAndNil(Op); // 中止したので監視しない
          Exit;
        end;

        if TempFileName <> '' then
          Args.ResultFilePath := wvstring(TempFileName);
        Args.Handled := True; // WebView2標準のダウンロード表示を出さない
      end;

      // 終了通知が必要な場合のみ、状態変化を監視する
      // （AddStateChangedEventはprotectedのため、公開されているAddAllBrowserEventsを使う。
      //   進捗系イベントも登録されるが、TCTabBrowserでは使わないので影響はない）
      if Assigned(FOnDownloadCompleted) and (Sender is TWVBrowser) and
         Op.AddAllBrowserEvents(TWVBrowser(Sender)) then
      begin
        Item := TCTabDownloadItem.Create;
        Item.Operation := Op;
        Item.Browser := TWVBrowser(Sender);
        FDownloads.Add(Item);
        Op := nil; // 所有権をItemへ移した
      end;
    finally
      Op.Free; // 監視しない場合のみ解放（監視する場合はnil）
    end;
  finally
    Args.Free;
  end;
end;

// 【DL対応】 恒久的なOnDownloadStateChangedハンドラ：
// 監視中ダウンロードが完了・中断になったらOnDownloadCompletedを通知し、監視を終える
procedure TCTabBrowser.BrowserDownloadStateChanged(Sender: TObject; const ADownloadOperation: ICoreWebView2DownloadOperation; ADownloadID: Integer);
var
  i: Integer;
  Item: TCTabDownloadItem;
  State: TWVDownloadState;
  TabIdx: Integer;
  FileName: string;
begin
  if not Assigned(FDownloads) then Exit;

  for i := FDownloads.Count - 1 downto 0 do
  begin
    Item := TCTabDownloadItem(FDownloads[i]);
    if Item.Operation.DownloadID <> ADownloadID then Continue;

    State := Item.Operation.State;
    if State = COREWEBVIEW2_DOWNLOAD_STATE_IN_PROGRESS then Exit; // 進行中は何もしない

    // 完了 または 中断（失敗・キャンセル含む）
    TabIdx := TabIndexOfBrowser(Item.Browser);
    FileName := string(Item.Operation.ResultFilePath);

    // 通知の前に一覧から外す（ハンドラ内で再入されても二重通知しないため）
    FDownloads.Extract(Item);
    try
      if Assigned(FOnDownloadCompleted) then
        FOnDownloadCompleted(Self, TabIdx, FileName,
          State = COREWEBVIEW2_DOWNLOAD_STATE_COMPLETED);
    finally
      Item.Free;
    end;
    Exit;
  end;
end;

// 【DL対応】 指定Browserに属する監視中ダウンロードを解放する（通知はしない）
procedure TCTabBrowser.ReleaseDownloadsOf(ABrowser: TWVBrowser);
var
  i: Integer;
begin
  if not Assigned(FDownloads) then Exit;

  for i := FDownloads.Count - 1 downto 0 do
    if TCTabDownloadItem(FDownloads[i]).Browser = ABrowser then
      FDownloads.Delete(i); // OwnsObjects=Trueのため自動で解放される
end;

// 【項番33】 「×」ボタンクリック時のハンドラ：対象タブをRemoveする
// (Senderが実際に何を渡すかはLCLの実装本体で未確認のため、実機での確認が必要)
procedure TCTabBrowser.DoCloseTabClicked(Sender: TObject);
var
  TabSheet: TTabSheet;
begin
  TabSheet := nil;

  if Sender is TTabSheet then
    TabSheet := TTabSheet(Sender)
  else if Sender = Self then
    TabSheet := ActivePage; // Senderがコントロール自体の場合のフォールバック

  if Assigned(TabSheet) then
    Remove(TabSheet.PageIndex);
end;

// 【項番33】 右クリック時、クリックされたタブを特定して記憶する。
// タブ以外（余白部分）を右クリックした場合はメニューを出さない。
procedure TCTabBrowser.HandleTabContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var
  i: Integer;
  Sep: TMenuItem;
begin
  FContextMenuTabIndex := IndexOfTabAt(MousePos.X, MousePos.Y);
  Handled := (FContextMenuTabIndex < 0); // タブ以外なら既定のメニュー表示を抑止
  if Handled then Exit;

  // 【右クリックメニュー】 アプリが右クリックしたタブを知れるように記録する
  FContextTabIndex := FContextMenuTabIndex;

  // 【右クリックメニュー】 前回写したアプリの項目を消す（「閉じる」だけを残す）
  for i := FTabPopupMenu.Items.Count - 1 downto 0 do
    if FTabPopupMenu.Items[i] <> FCloseMenuItem then
      FTabPopupMenu.Items[i].Free;

  if not Assigned(FHeaderPopupMenu) then Exit;

  // 【右クリックメニュー】 アプリが項目の状態を合わせられるよう、先に OnPopup を呼ぶ
  if Assigned(FHeaderPopupMenu.OnPopup) then
    FHeaderPopupMenu.OnPopup(FHeaderPopupMenu);
  // OnPopup の中で HeaderPopupMenu が外されることもあるため、もう一度確かめる
  if not Assigned(FHeaderPopupMenu) then Exit;

  // 【右クリックメニュー】 「閉じる」→ 区切り線 → アプリの項目 の順に並べる。
  // 表示する項目が1つも無ければ、区切り線も入れない。
  Sep := TMenuItem.Create(FTabPopupMenu);
  Sep.Caption := '-';
  FTabPopupMenu.Items.Add(Sep);
  CopyMenuToHeader(FHeaderPopupMenu.Items, FTabPopupMenu.Items);
  if FTabPopupMenu.Items[FTabPopupMenu.Items.Count - 1] = Sep then
    Sep.Free;
end;

// 【項番33】 「閉じる」メニュー項目クリック時：記憶しておいたタブをRemoveする
procedure TCTabBrowser.CloseMenuItemClick(Sender: TObject);
begin
  if FContextMenuTabIndex >= 0 then
    Remove(FContextMenuTabIndex);
end;

// 【項番10】 テキストファイル読み込み表示
procedure TCTabBrowser.LoadFromFile(const AFileName: string);
var
  TempURL: string;
begin
  TempURL := 'file:///' + StringReplace(AFileName, '\', '/', [rfReplaceAll]);
  Navigate(TempURL);
end;

// SaveToFile用の一時的な完了検知ハンドラ
procedure TCTabBrowser.SaveToFileHandler(ASender: TObject; ASuccess: Boolean; const AHTML: wvstring);
begin
  FWaitCompleted := True;
  FWaitSuccess := ASuccess;
  FRetrievedHTML := AHTML;
end;

// 【項番11】 HTMLソーステキスト保存
procedure TCTabBrowser.SaveToFile(sFileName: String);
var
  WP: TWVWindowParent;
  PrevHandler: TOnRetrieveHTMLCompletedEvent;
  TargetDir: string;
  SS: TStringStream;
begin
  WP := FindWindowParent(ActivePage);
  if not Assigned(WP) or not Assigned(WP.Browser) then Exit;
  if not WP.Browser.Initialized then Exit;

  PrevHandler := WP.Browser.OnRetrieveHTMLCompleted;
  FWaitCompleted := False;
  FWaitSuccess := False;
  FWaitAborted := False;
  FRetrievedHTML := '';
  WP.Browser.OnRetrieveHTMLCompleted := SaveToFileHandler;

  // 待機中にBrowserが破棄された場合を検知できるようにする
  FWaitTargetComponent := WP.Browser;
  WP.Browser.FreeNotification(Self);
  try
    if not WP.Browser.RetrieveHTML then Exit;

    // タイムアウト無し：時間がかかっても完了まで待つ
    // ただし対象が破棄された場合はFWaitAbortedで安全に抜ける
    while not (FWaitCompleted or FWaitAborted) do
      Application.ProcessMessages;

    if FWaitAborted then Exit; // Browserは既に破棄中のため、以降は一切触らない
  finally
    // 破棄されていない場合のみ、後片付け（ハンドラ復元・監視解除）を行う
    if not FWaitAborted then
    begin
      WP.Browser.RemoveFreeNotification(Self);
      WP.Browser.OnRetrieveHTMLCompleted := PrevHandler;
    end;
    FWaitTargetComponent := nil;
  end;

  // HTMLソースが無い（失敗・空）場合は保存しない
  if not FWaitSuccess or (Length(FRetrievedHTML) = 0) then Exit;

  TargetDir := ExtractFileDir(sFileName);
  if (TargetDir <> '') and not DirectoryExists(TargetDir) then
    ForceDirectories(TargetDir);

  // TStringListは内部で改行単位に分解・再構築するため、
  // 巨大なデータでは無駄なオーバーヘッド（二重保持＋パース）になる。
  // TStringStreamで文字列をそのままバイト列として直接書き出す。
  SS := TStringStream.Create(string(FRetrievedHTML));
  try
    SS.SaveToFile(sFileName); // 既存ファイルは上書き。書込み失敗時は例外がそのまま発生する
  finally
    SS.Free;
  end;
end;

// SaveAsWebPage用の一時的な完了検知ハンドラ
procedure TCTabBrowser.SaveAsWebPageHandler(ASender: TObject; ASuccess: Boolean; const AMHTML: wvstring);
begin
  FWaitCompleted := True;
  FWaitSuccess := ASuccess;
  FRetrievedMHTML := AMHTML;
end;

// 【項番12】 Webページ全体保存（MHTML形式・1ファイル）
procedure TCTabBrowser.SaveAsWebPage(sFileName: String);
var
  WP: TWVWindowParent;
  PrevHandler: TOnRetrieveMHTMLCompletedEvent;
  TargetDir: string;
  SS: TStringStream;
begin
  WP := FindWindowParent(ActivePage);
  if not Assigned(WP) or not Assigned(WP.Browser) then Exit;
  if not WP.Browser.Initialized then Exit;

  PrevHandler := WP.Browser.OnRetrieveMHTMLCompleted;
  FWaitCompleted := False;
  FWaitSuccess := False;
  FWaitAborted := False;
  FRetrievedMHTML := '';
  WP.Browser.OnRetrieveMHTMLCompleted := SaveAsWebPageHandler;

  // 待機中にBrowserが破棄された場合を検知できるようにする
  FWaitTargetComponent := WP.Browser;
  WP.Browser.FreeNotification(Self);
  try
    if not WP.Browser.RetrieveMHTML then Exit;

    // タイムアウト無し：時間がかかっても完了まで待つ
    // ただし対象が破棄された場合はFWaitAbortedで安全に抜ける
    while not (FWaitCompleted or FWaitAborted) do
      Application.ProcessMessages;

    if FWaitAborted then Exit; // Browserは既に破棄中のため、以降は一切触らない
  finally
    if not FWaitAborted then
    begin
      WP.Browser.RemoveFreeNotification(Self);
      WP.Browser.OnRetrieveMHTMLCompleted := PrevHandler;
    end;
    FWaitTargetComponent := nil;
  end;

  // MHTMLソースが無い（失敗・空）場合は保存しない
  if not FWaitSuccess or (Length(FRetrievedMHTML) = 0) then Exit;

  TargetDir := ExtractFileDir(sFileName);
  if (TargetDir <> '') and not DirectoryExists(TargetDir) then
    ForceDirectories(TargetDir);

  SS := TStringStream.Create(string(FRetrievedMHTML));
  try
    SS.SaveToFile(sFileName); // 既存ファイルは上書き。書込み失敗時は例外がそのまま発生する
  finally
    SS.Free;
  end;
end;

// SaveScreenCapture用の一時的な完了検知ハンドラ
procedure TCTabBrowser.CapturePreviewHandler(ASender: TObject; AErrorCode: HRESULT);
begin
  FWaitCompleted := True;
  FWaitSuccess := (AErrorCode = 0); // 0 = S_OK
end;

// 【項番14】 全画面キャプチャ保存（JPEG形式）
procedure TCTabBrowser.SaveScreenCapture(const AFileName: string);
const
  ForbiddenChars: set of Char = ['\', '/', ':', '*', '?', '"', '<', '>', '|'];
var
  WP: TWVWindowParent;
  PrevHandler: TOnCapturePreviewCompletedEvent;
  TargetPath, TargetDir, SanitizedTitle: string;
  i: Integer;
  FS: TFileStream;
  Adapter: IStream;
begin
  WP := FindWindowParent(ActivePage);
  if not Assigned(WP) or not Assigned(WP.Browser) then Exit;
  if not WP.Browser.Initialized then Exit;

  if AFileName <> '' then
    TargetPath := AFileName
  else
  begin
    SanitizedTitle := string(WP.Browser.DocumentTitle);
    if SanitizedTitle = '' then SanitizedTitle := 'capture';
    for i := 1 to Length(SanitizedTitle) do
      if SanitizedTitle[i] in ForbiddenChars then
        SanitizedTitle[i] := '_';
    TargetPath := IncludeTrailingPathDelimiter(FSavePath) + SanitizedTitle + '.jpg';
  end;

  TargetDir := ExtractFileDir(TargetPath);
  if (TargetDir <> '') and not DirectoryExists(TargetDir) then
    ForceDirectories(TargetDir);

  PrevHandler := WP.Browser.OnCapturePreviewCompleted;
  FWaitCompleted := False;
  FWaitSuccess := False;
  FWaitAborted := False;
  WP.Browser.OnCapturePreviewCompleted := CapturePreviewHandler;

  FWaitTargetComponent := WP.Browser;
  WP.Browser.FreeNotification(Self);

  FS := TFileStream.Create(TargetPath, fmCreate);
  try
    Adapter := TStreamAdapter.Create(FS, soReference);
    try
      if not WP.Browser.CapturePreview(COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_JPEG, Adapter) then Exit;

      while not (FWaitCompleted or FWaitAborted) do
        Application.ProcessMessages;

      if FWaitAborted then Exit; // Browserは既に破棄中のため、以降は一切触らない
    finally
      if not FWaitAborted then
      begin
        WP.Browser.RemoveFreeNotification(Self);
        WP.Browser.OnCapturePreviewCompleted := PrevHandler;
      end;
      FWaitTargetComponent := nil;
    end;
  finally
    FS.Free;
  end;
end;

// SavePDF用の一時的な完了検知ハンドラ
procedure TCTabBrowser.PrintToPdfHandler(ASender: TObject; AErrorCode: HRESULT; AIsSuccess: Boolean);
begin
  FWaitCompleted := True;
  FWaitSuccess := AIsSuccess;
end;

// PDF保存（PrintToPdfベース）
procedure TCTabBrowser.SavePDF(const AFileName: string);
const
  ForbiddenChars: set of Char = ['\', '/', ':', '*', '?', '"', '<', '>', '|'];
var
  WP: TWVWindowParent;
  PrevHandler: TOnPrintToPdfCompletedEvent;
  TargetPath, TargetDir, SanitizedTitle: string;
  i: Integer;
begin
  WP := FindWindowParent(ActivePage);
  if not Assigned(WP) or not Assigned(WP.Browser) then Exit;
  if not WP.Browser.Initialized then Exit;

  if AFileName <> '' then
    TargetPath := AFileName
  else
  begin
    SanitizedTitle := string(WP.Browser.DocumentTitle);
    if SanitizedTitle = '' then SanitizedTitle := 'capture';
    for i := 1 to Length(SanitizedTitle) do
      if SanitizedTitle[i] in ForbiddenChars then
        SanitizedTitle[i] := '_';
    TargetPath := IncludeTrailingPathDelimiter(FSavePath) + SanitizedTitle + '.pdf';
  end;

  TargetDir := ExtractFileDir(TargetPath);
  if (TargetDir <> '') and not DirectoryExists(TargetDir) then
    ForceDirectories(TargetDir);

  PrevHandler := WP.Browser.OnPrintToPdfCompleted;
  FWaitCompleted := False;
  FWaitSuccess := False;
  FWaitAborted := False;
  WP.Browser.OnPrintToPdfCompleted := PrintToPdfHandler;

  FWaitTargetComponent := WP.Browser;
  WP.Browser.FreeNotification(Self);
  try
    if not WP.Browser.PrintToPdf(wvstring(TargetPath)) then Exit;

    while not (FWaitCompleted or FWaitAborted) do
      Application.ProcessMessages;

    if FWaitAborted then Exit; // Browserは既に破棄中のため、以降は一切触らない
  finally
    if not FWaitAborted then
    begin
      WP.Browser.RemoveFreeNotification(Self);
      WP.Browser.OnPrintToPdfCompleted := PrevHandler;
    end;
    FWaitTargetComponent := nil;
  end;
end;

// 【項番2】 アクティブタブ削除
procedure TCTabBrowser.Remove;
begin
  Remove(ActivePageIndex);
end;

// 【項番3】 位置指定タブ削除
procedure TCTabBrowser.Remove(i: Integer);
var
  NewActiveIndex: Integer;
  WP: TWVWindowParent;
  LastTabURL: string;
begin
  if (i < 0) or (i >= PageCount) then Exit;

  // 【右クリックメニュー】 最後の1枚を閉じるときに、部品が自動で作るタブのURL。
  // 最後の1枚のときだけ、OnNewTabRequest(ntrLastTabClosed) で決める（中止・空なら about:blank）
  LastTabURL := 'about:blank';

  // 最適化：残り1枚かつ、既に自動で作るタブと同じURLを表示中の場合は、
  // 破棄→自動生成の無駄なサイクルを避けるため何もしない
  // （URLが同じかは大文字小文字を区別せずに比べる）
  if PageCount = 1 then
  begin
    LastTabURL := DoNewTabRequest(ntrLastTabClosed);
    WP := FindWindowParent(Pages[i]);
    if Assigned(WP) and Assigned(WP.Browser) and
       SameText(string(WP.Browser.Source), LastTabURL) then
      Exit;
  end;

  NewActiveIndex := ActivePageIndex;

  // 共通仕様1番：ActiveIndexの動的補正
  if i < ActivePageIndex then
    Dec(NewActiveIndex)
  else if i = ActivePageIndex then
  begin
    // アクティブタブ削除時：削除後、同じインデックス位置（右側）へ。
    // 右側が無ければ左側(i-1)へ。
    if i < PageCount - 1 then
      NewActiveIndex := i
    else
      NewActiveIndex := i - 1;
  end;
  // i > ActivePageIndex の場合はNewActiveIndexを変更しない

  // 【DL対応】 このタブで監視中のダウンロードを、Browser破棄の前に解放する
  WP := FindWindowParent(Pages[i]);
  if Assigned(WP) and (WP.Browser is TWVBrowser) then
  begin
    ReleaseDownloadsOf(TWVBrowser(WP.Browser));
    // 【非同期スクリプト】 このタブの結果待ちも破棄する（通知はしない）
    ReleaseScriptsOf(TWVBrowser(WP.Browser));
    // 【右クリックメニュー】 このタブのページ部分に足した項目も解放する
    ReleasePageMenuItemsOf(TWVBrowser(WP.Browser));
  end;

  // タブページ破棄（Owner経由でWindowParent/Browserも連動して破棄される）
  Pages[i].Free;

  // 共通仕様3番：タブ0件時の自動保護
  // 【右クリックメニュー】 開くURLは、上で OnNewTabRequest(ntrLastTabClosed) で決めたもの
  if PageCount = 0 then
  begin
    Add(LastTabURL);
    Exit;
  end;

  if NewActiveIndex >= PageCount then
    NewActiveIndex := PageCount - 1;
  if NewActiveIndex < 0 then
    NewActiveIndex := 0;

  ActivePageIndex := NewActiveIndex;
  SynchronizeBounds;
  SynchronizeVisibility;

  // 【項番21】 タブ枚数が変化したため、ヘッダー表示を再計算
  UpdateTabHeaderVisibility;
end;

procedure TCTabBrowser.SynchronizeBounds;
var
  WP: TWVWindowParent;
begin
  WP := FindWindowParent(ActivePage);
  if Assigned(WP) then
    WP.UpdateSize;
end;

procedure TCTabBrowser.SynchronizeVisibility;
var
  i: Integer;
  WP: TWVWindowParent;
begin
  for i := 0 to PageCount - 1 do
  begin
    WP := FindWindowParent(Pages[i]);
    if Assigned(WP) and Assigned(WP.Browser) then
      WP.Browser.IsVisible := (i = ActivePageIndex);
  end;
end;

procedure TCTabBrowser.Resize;
begin
  inherited Resize;
  SynchronizeBounds;
end;

procedure TCTabBrowser.ExecuteScriptHandler(ASender: TObject; AErrorCode: HRESULT; const AResultObjectAsJson: wvstring; AExecutionID: LongInt);
begin
  FWaitCompleted := True;
  FWaitSuccess := (AErrorCode = 0); // 0 = S_OK
  FRunScriptResult := AResultObjectAsJson;
end;

function TCTabBrowser.RunScript(const AScript: string; out AResultJson: string; ATimeoutMS: Integer): Boolean;
var
  WP: TWVWindowParent;
  StartTick: DWORD;
  MyID: Integer;
begin
  Result := False;
  AResultJson := '';

  WP := FindWindowParent(ActivePage);
  if not Assigned(WP) or not Assigned(WP.Browser) then Exit;
  if not WP.Browser.Initialized then Exit;

  // 【非同期スクリプト】 ハンドラは差し替えず、実行IDで自分の結果を見分ける
  // （RunScriptAsync の結果と混ざらないようにするため）
  MyID := NextScriptID;
  FWaitCompleted := False;
  FWaitSuccess := False;
  FWaitAborted := False;
  FRunScriptResult := '';
  FRunScriptID := MyID;

  FWaitTargetComponent := WP.Browser;
  WP.Browser.FreeNotification(Self);
  try
    if not WP.Browser.ExecuteScript(wvstring(AScript), MyID) then Exit;

    StartTick := GetTickCount;
    while not (FWaitCompleted or FWaitAborted) do
    begin
      Application.ProcessMessages;
      if (ATimeoutMS > 0) and (GetTickCount - StartTick > DWORD(ATimeoutMS)) then
        Exit; // タイムアウト：Resultは False のまま返す
    end;

    if FWaitAborted then Exit;

    AResultJson := string(FRunScriptResult);
    Result := FWaitSuccess;
  finally
    FRunScriptID := 0;
    if not FWaitAborted then
      WP.Browser.RemoveFreeNotification(Self);
    FWaitTargetComponent := nil;
  end;
end;

// 【非同期スクリプト】 実行IDを採番する（1～9999 で回す）。
// WebView4Delphi は 10000 以降（WEBVIEW4DELPHI_JS_FIRST_ID）を自分の処理（RetrieveHTML 等）に
// 予約しており、その番号の結果は OnExecuteScriptCompleted に来ないため、使わない。
// 0 は「待っていない」の意味に使うため、1 から始める。
function TCTabBrowser.NextScriptID: Integer;
const
  MAX_SCRIPT_ID = 9999;
begin
  if FScriptIDGen >= MAX_SCRIPT_ID then
    FScriptIDGen := 0;
  Inc(FScriptIDGen);
  Result := FScriptIDGen;
end;

// 【非同期スクリプト】 恒久的なOnExecuteScriptCompletedハンドラ
procedure TCTabBrowser.BrowserExecuteScriptCompleted(ASender: TObject; AErrorCode: HRESULT; const AResultObjectAsJson: wvstring; AExecutionID: LongInt);
var
  i, ID: Integer;
  Item: TCTabScriptItem;
  CB: TTabScriptResultEvent;
begin
  // RunScript（待つ方式）の結果
  if (FRunScriptID <> 0) and (AExecutionID = FRunScriptID) then
  begin
    ExecuteScriptHandler(ASender, AErrorCode, AResultObjectAsJson, AExecutionID);
    Exit;
  end;

  // RunScriptAsync の結果：一覧から外してから通知する
  if not Assigned(FScripts) then Exit;
  for i := 0 to FScripts.Count - 1 do
  begin
    Item := TCTabScriptItem(FScripts[i]);
    if (Item.ID = AExecutionID) and (Item.Browser = ASender) then
    begin
      ID := Item.ID;
      CB := Item.Callback;
      FScripts.Delete(i); // OwnsObjects=Trueのため自動で解放される
      if Assigned(CB) then
        CB(Self, ID, AErrorCode = 0, string(AResultObjectAsJson));
      Exit;
    end;
  end;
  // どちらにも当たらない結果（取り消し済み等）は捨てる
end;

// 【非同期スクリプト】 結果を待たずに実行する
function TCTabBrowser.RunScriptAsync(ATabIndex: Integer; const AScript: string;
  ACallback: TTabScriptResultEvent): Integer;
var
  WP: TWVWindowParent;
  Item: TCTabScriptItem;
  ID: Integer;
begin
  Result := 0;
  if not Assigned(FScripts) then Exit;
  if (ATabIndex < 0) or (ATabIndex >= PageCount) then Exit;

  WP := FindWindowParent(Pages[ATabIndex]);
  if not Assigned(WP) or not (WP.Browser is TWVBrowser) then Exit;
  if not WP.Browser.Initialized then Exit;

  ID := NextScriptID;
  Item := TCTabScriptItem.Create;
  Item.ID := ID;
  Item.Browser := TWVBrowser(WP.Browser);
  Item.Callback := ACallback;
  FScripts.Add(Item);

  if not WP.Browser.ExecuteScript(wvstring(AScript), ID) then
  begin
    FScripts.Remove(Item); // OwnsObjects=Trueのため自動で解放される
    Exit;
  end;
  Result := ID;
end;

// 【非同期スクリプト】 結果待ちを取り消す
procedure TCTabBrowser.CancelScriptAsync(AID: Integer);
var
  i: Integer;
begin
  if not Assigned(FScripts) then Exit;
  for i := FScripts.Count - 1 downto 0 do
    if TCTabScriptItem(FScripts[i]).ID = AID then
      FScripts.Delete(i);
end;

// 【非同期スクリプト】 指定Browserの結果待ちを破棄する（通知はしない）
procedure TCTabBrowser.ReleaseScriptsOf(ABrowser: TWVBrowser);
var
  i: Integer;
begin
  if not Assigned(FScripts) then Exit;
  for i := FScripts.Count - 1 downto 0 do
    if TCTabScriptItem(FScripts[i]).Browser = ABrowser then
      FScripts.Delete(i);
end;

// 待機中（NavigateAndWait/SaveToFile）の監視対象コンポーネントが
// 破棄されようとした場合、待機ループを安全に中断させる
procedure TCTabBrowser.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);

  if (Operation = opRemove) and (AComponent = FWaitTargetComponent) then
    FWaitAborted := True;

  // 【右クリックメニュー】 アプリの TPopupMenu が破棄されたら、参照を外す
  // （元の項目は、使う前にメニューの中にまだあるかを探して確かめるため、ここでは消さない）
  if Operation = opRemove then
  begin
    if AComponent = FHeaderPopupMenu then
      FHeaderPopupMenu := nil;
    if AComponent = FPagePopupMenu then
      FPagePopupMenu := nil;
  end;
end;

// ==================================================================
// 【右クリックメニュー】 見出しとページ部分の右クリックメニュー
// ==================================================================

// 引数の項目が、メニュー（AParent 以下）の中にまだあるかを探す。
// ポインタを比べるだけなので、AItem が破棄済みでも安全。
function MenuContainsItem(AParent, AItem: TMenuItem): Boolean;
var
  i: Integer;
begin
  Result := False;
  if not Assigned(AParent) or not Assigned(AItem) then Exit;
  for i := 0 to AParent.Count - 1 do
  begin
    if (AParent.Items[i] = AItem) or MenuContainsItem(AParent.Items[i], AItem) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

// 表示する（Visible=True の）項目が1つでもあるか
function HasVisibleItem(AParent: TMenuItem): Boolean;
var
  i: Integer;
begin
  Result := False;
  if not Assigned(AParent) then Exit;
  for i := 0 to AParent.Count - 1 do
    if AParent.Items[i].Visible then
    begin
      Result := True;
      Exit;
    end;
end;

// HeaderPopupMenu の設定。同じ TPopupMenu を PagePopupMenu にも指定できるため、
// 破棄の通知の登録は、もう一方で使っていないときだけ外す
procedure TCTabBrowser.SetHeaderPopupMenu(const AValue: TPopupMenu);
begin
  if FHeaderPopupMenu = AValue then Exit;
  if Assigned(FHeaderPopupMenu) and (FHeaderPopupMenu <> FPagePopupMenu) then
    FHeaderPopupMenu.RemoveFreeNotification(Self);
  FHeaderPopupMenu := AValue;
  if Assigned(FHeaderPopupMenu) then
    FHeaderPopupMenu.FreeNotification(Self);
end;

// PagePopupMenu の設定（考え方は SetHeaderPopupMenu と同じ）
procedure TCTabBrowser.SetPagePopupMenu(const AValue: TPopupMenu);
begin
  if FPagePopupMenu = AValue then Exit;
  if Assigned(FPagePopupMenu) and (FPagePopupMenu <> FHeaderPopupMenu) then
    FPagePopupMenu.RemoveFreeNotification(Self);
  FPagePopupMenu := AValue;
  if Assigned(FPagePopupMenu) then
    FPagePopupMenu.FreeNotification(Self);
end;

// 見出しのメニューへ、ASrc の子項目を写す。
// 写した項目の Tag に元の項目を持たせ、選ばれたら元の項目の Click を呼ぶ。
procedure TCTabBrowser.CopyMenuToHeader(ASrc, ADest: TMenuItem);
var
  i: Integer;
  S, N: TMenuItem;
begin
  for i := 0 to ASrc.Count - 1 do
  begin
    S := ASrc.Items[i];
    if not S.Visible then Continue;   // 非表示の項目は写さない

    N := TMenuItem.Create(FTabPopupMenu);
    if S.IsLine then
      N.Caption := '-'                // 区切り線
    else
    begin
      N.Caption := S.Caption;         // & のアクセスキーもそのまま
      N.Enabled := S.Enabled;
      N.Checked := S.Checked;
      N.ShortCut := S.ShortCut;       // 見出しでは表示される
      N.Tag := PtrInt(S);
      if S.Count = 0 then
        N.OnClick := HeaderCopyItemClick;
    end;
    ADest.Add(N);

    // 子項目があればサブメニューにして、同じ決まりで写す
    if (not S.IsLine) and (S.Count > 0) then
      CopyMenuToHeader(S, N);
  end;
end;

// 見出しに写した項目が選ばれたとき：元の項目がまだアプリのメニューにあれば Click を呼ぶ
// （OnClick・Action・AutoCheck は LCL の通常の動作になる）
procedure TCTabBrowser.HeaderCopyItemClick(Sender: TObject);
var
  Src: TMenuItem;
begin
  if not (Sender is TMenuItem) then Exit;
  Src := TMenuItem(TMenuItem(Sender).Tag);
  if Assigned(FHeaderPopupMenu) and MenuContainsItem(FHeaderPopupMenu.Items, Src) then
    Src.Click;
end;

// ページ部分のメニューに項目を1つ足す。
// ・選択通知を登録し、一覧（FPageMenuItems）に記録する
// ・ACollection に追加できたときだけ、作った項目のラッパーを返す（失敗したら nil）
function TCTabBrowser.AddPageMenuItem(const ACollection: ICoreWebView2ContextMenuItemCollection;
  ABrowser: TWVBrowser; const ALabel: string; AKind: TWVMenuItemKind;
  AAction: TCTabPageMenuAction; ASource: TMenuItem;
  AEnabled, AChecked: Boolean): TCoreWebView2ContextMenuItem;
var
  ItemItf: ICoreWebView2ContextMenuItem;
  Coll: TCoreWebView2ContextMenuItemCollection;
  Rec: TCTabPageMenuItem;
begin
  Result := nil;
  if not Assigned(ACollection) then Exit;
  if not Assigned(ABrowser.CoreWebView2Environment) then Exit;
  // 古い WebView2 Runtime では作れない。その場合は何も足さない（エラーにしない）
  if not ABrowser.CoreWebView2Environment.CreateContextMenuItem(wvstring(ALabel), nil, AKind, ItemItf) then Exit;

  Rec := TCTabPageMenuItem.Create;
  try
    Rec.Item := TCoreWebView2ContextMenuItem.Create(ItemItf);
    Rec.CommandId := Rec.Item.CommandId;
    Rec.Action := AAction;
    Rec.Source := ASource;
    Rec.Browser := ABrowser;

    if AKind <> COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SEPARATOR then
      Rec.Item.IsEnabled := AEnabled;
    if AKind = COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_CHECK_BOX then
      Rec.Item.IsChecked := AChecked;

    // 選ばれたときに Browser.OnCustomItemSelected が呼ばれるようにする
    if AAction <> pmaNone then
      Rec.Item.AddAllBrowserEvents(ABrowser);

    Coll := TCoreWebView2ContextMenuItemCollection.Create(ACollection);
    try
      if not Coll.AppendValue(Rec.Item.BaseIntf) then
      begin
        FreeAndNil(Rec);
        Exit;
      end;
    finally
      Coll.Free;
    end;

    FPageMenuItems.Add(Rec);
    Result := Rec.Item;
    Rec := nil; // 所有権を一覧へ移した
  finally
    Rec.Free;   // 一覧へ移せなかった場合のみ解放（移した場合は nil）
  end;
end;

// ページ部分のメニューへ、ASrc の子項目を写す。
// アイコンとショートカットキーは写さない（WebView2 のメニューでは出ない）。
procedure TCTabBrowser.CopyMenuToPage(ASrc: TMenuItem;
  const ACollection: ICoreWebView2ContextMenuItemCollection; ABrowser: TWVBrowser);
var
  i: Integer;
  S: TMenuItem;
  W: TCoreWebView2ContextMenuItem;
begin
  for i := 0 to ASrc.Count - 1 do
  begin
    S := ASrc.Items[i];
    if not S.Visible then Continue;   // 非表示の項目は写さない

    if S.IsLine then
      // 区切り線
      AddPageMenuItem(ACollection, ABrowser, '',
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SEPARATOR, pmaNone, nil, True, False)
    else if S.Count > 0 then
    begin
      // 子項目あり：サブメニューにして、子項目も同じ決まりで写す
      W := AddPageMenuItem(ACollection, ABrowser, S.Caption,
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SUBMENU, pmaNone, nil, S.Enabled, False);
      if Assigned(W) then
        CopyMenuToPage(S, W.Children, ABrowser);
    end
    else if S.Checked then
      // チェックの付いた項目
      AddPageMenuItem(ACollection, ABrowser, S.Caption,
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_CHECK_BOX, pmaApp, S, S.Enabled, True)
    else
      // 通常の項目
      AddPageMenuItem(ACollection, ABrowser, S.Caption,
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_COMMAND, pmaApp, S, S.Enabled, False);
  end;
end;

// ページ部分の右クリック通知。
// 標準のメニューは止めず（Handled は設定しない）、その後ろに
// 区切り線・「新規作成」・「閉じる」・（あれば）区切り線＋アプリの項目 を足す。
procedure TCTabBrowser.BrowserContextMenuRequested(Sender: TObject;
  const AWebView: ICoreWebView2; const AArgs: ICoreWebView2ContextMenuRequestedEventArgs);
var
  Browser: TWVBrowser;
  Args: TCoreWebView2ContextMenuRequestedEventArgs;
  MenuList: ICoreWebView2ContextMenuItemCollection;
begin
  if not Assigned(AArgs) or not (Sender is TWVBrowser) then Exit;
  Browser := TWVBrowser(Sender);

  // 前回のメニューで足した項目は、もう使わないので解放する
  ReleasePageMenuItemsOf(nil);

  // アプリが右クリックしたタブを知れるように記録する
  FContextTabIndex := TabIndexOfBrowser(Browser);

  Args := TCoreWebView2ContextMenuRequestedEventArgs.Create(AArgs);
  try
    MenuList := Args.MenuItems;
    if not Assigned(MenuList) then Exit;

    // 部品の項目
    AddPageMenuItem(MenuList, Browser, '', COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SEPARATOR, pmaNone, nil, True, False);
    AddPageMenuItem(MenuList, Browser, '新規作成', COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_COMMAND, pmaNew, nil, True, False);
    AddPageMenuItem(MenuList, Browser, '閉じる', COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_COMMAND, pmaClose, nil, True, False);

    // アプリの項目（アプリが項目の状態を合わせられるよう、先に OnPopup を呼ぶ）
    if Assigned(FPagePopupMenu) then
    begin
      if Assigned(FPagePopupMenu.OnPopup) then
        FPagePopupMenu.OnPopup(FPagePopupMenu);
      // OnPopup の中で PagePopupMenu が外されることもあるため、もう一度確かめる
      if Assigned(FPagePopupMenu) and HasVisibleItem(FPagePopupMenu.Items) then
      begin
        AddPageMenuItem(MenuList, Browser, '', COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SEPARATOR, pmaNone, nil, True, False);
        CopyMenuToPage(FPagePopupMenu.Items, MenuList, Browser);
      end;
    end;
  finally
    MenuList := nil;
    Args.Free;
  end;
end;

// ページ部分に足した項目が選ばれたときの通知。
// WebView2 の通知の中でタブ（Browser）を破棄しないよう、その場では実行せず、
// 内容を記録して、メニューが閉じた後に DoPendingMenu で実行する。
procedure TCTabBrowser.BrowserCustomItemSelected(Sender: TObject; const AMenuItem: ICoreWebView2ContextMenuItem);
var
  W: TCoreWebView2ContextMenuItem;
  ID, i: Integer;
  Rec: TCTabPageMenuItem;
begin
  if not Assigned(AMenuItem) or not Assigned(FPageMenuItems) then Exit;

  W := TCoreWebView2ContextMenuItem.Create(AMenuItem);
  try
    ID := W.CommandId;
  finally
    W.Free;
  end;

  for i := 0 to FPageMenuItems.Count - 1 do
  begin
    Rec := TCTabPageMenuItem(FPageMenuItems[i]);
    if (Rec.CommandId = ID) and (Rec.Browser = Sender) then
    begin
      if Rec.Action = pmaNone then Exit;
      FPendingAction := Rec.Action;
      FPendingItem := Rec.Source;
      FPendingBrowser := Rec.Browser;
      Application.QueueAsyncCall(DoPendingMenu, 0);
      Exit;
    end;
  end;
end;

// ページ部分で選ばれた項目を、メニューが閉じた後に実行する。
// 選んでから実行までの間に、タブや TPopupMenu が破棄されていることがあるため、
// タブはポインタを比べて探し直し、元の項目はメニューの中にまだあるかを確かめる。
procedure TCTabBrowser.DoPendingMenu(Data: PtrInt);
var
  Act: TCTabPageMenuAction;
  Src: TMenuItem;
  TabIdx: Integer;
begin
  Act := FPendingAction;
  Src := FPendingItem;
  TabIdx := FindTabOfBrowser(FPendingBrowser);
  FPendingAction := pmaNone;
  FPendingItem := nil;
  FPendingBrowser := nil;

  // 右クリックしたタブの今の番号（タブが既に閉じられていれば -1）
  FContextTabIndex := TabIdx;

  case Act of
    pmaNew:
      NewTabMenuClick(nil);
    pmaClose:
      if TabIdx >= 0 then
        Remove(TabIdx);
    pmaApp:
      if Assigned(FPagePopupMenu) and MenuContainsItem(FPagePopupMenu.Items, Src) then
        Src.Click;
  end;
end;

// ページ部分に足した項目を解放する。ABrowser=nil なら全部、指定ありならそのタブの分だけ。
// （タブを破棄する前・次の右クリックのときに呼ぶ）
procedure TCTabBrowser.ReleasePageMenuItemsOf(ABrowser: TWVBrowser);
var
  i: Integer;
begin
  if not Assigned(FPageMenuItems) then Exit;
  for i := FPageMenuItems.Count - 1 downto 0 do
    if (ABrowser = nil) or (TCTabPageMenuItem(FPageMenuItems[i]).Browser = ABrowser) then
      FPageMenuItems.Delete(i); // OwnsObjects=Trueのため自動で解放される
end;

// OnNewTabRequest を呼び、開くURLを返す。
// ・初期値は about:blank
// ・中止：新規作成なら空文字を返す。最後のタブを閉じたときは中止できず about:blank
// ・URLが空なら about:blank
function TCTabBrowser.DoNewTabRequest(AReason: TTabNewTabReason): string;
var
  URL: string;
  Accept: Boolean;
begin
  URL := 'about:blank';
  Accept := True;
  if Assigned(FOnNewTabRequest) then
    FOnNewTabRequest(Self, AReason, URL, Accept);

  if not Accept then
  begin
    if AReason = ntrMenuNew then
    begin
      Result := '';
      Exit;
    end;
    URL := 'about:blank';
  end;

  if URL = '' then
    URL := 'about:blank';
  Result := URL;
end;

// 「新規作成」：イベントで決めたURLで、末尾にタブを追加してアクティブにする
procedure TCTabBrowser.NewTabMenuClick(Sender: TObject);
var
  URL: string;
begin
  URL := DoNewTabRequest(ntrMenuNew);
  if URL <> '' then
    Add(URL);
end;

// Browser のタブ番号を探す。各タブの Browser とポインタを比べるだけなので、
// ABrowser が破棄済みでも中身に触らず安全。見つからなければ -1。
function TCTabBrowser.FindTabOfBrowser(ABrowser: TWVBrowser): Integer;
var
  i: Integer;
  WP: TWVWindowParent;
begin
  Result := -1;
  if ABrowser = nil then Exit;
  for i := 0 to PageCount - 1 do
  begin
    WP := FindWindowParent(Pages[i]);
    if Assigned(WP) and (Pointer(WP.Browser) = Pointer(ABrowser)) then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

procedure TCTabBrowser.Change;
begin
  inherited Change;
  SynchronizeBounds;
  SynchronizeVisibility;
end;

end.
