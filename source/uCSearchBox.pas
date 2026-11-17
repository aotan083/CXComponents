{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ ============================================================================
  uCSearchBox  -  TCSearchBox（Windows エクスプローラーの検索ボックスと同等の部品）

  設計書: docs\TCSearchBox_Design.md
  パッケージ: cx（実行時）

  ・Enter で、フォルダーの中を、名前で探す（部分一致・ワイルドカード・正規表現。探す処理は uCFindFile の TCFindFile）。
  ・結果は、TCListView の「検索結果の表示」に出す。
  ・一覧・ツリーが、ほかの操作でフォルダーを移ったら、検索の表示は終わる
    （TCListView・TCTreeView の「フォルダーが変わった知らせ」で知る。タイマーでの見張りはしない）。
  ============================================================================ }
unit uCSearchBox;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Types, Math, Controls, Graphics, Forms, Menus, StdCtrls, ExtCtrls, LCLType,
  LCLIntf, LMessages, uCXLang, uCTitleBar, uCFindFile, CListView, CTreeView;

type
  TCSearchResultEvent = procedure(Sender: TObject; const APath: string; AIsDir: Boolean) of object;
  TCSearchFinishedEvent = procedure(Sender: TObject; AFound: Integer; AReason: TCFindStopReason) of object;
  TCSearchErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;

  { TCSearchBox }
  TCSearchBox = class(TCustomControl)
  private
    FListView: TCListView;
    FTreeView: TCTreeView;
    FEdit: TEdit;
    FFinder: TCFindFile;
    FTextHint: string;
    FMatchMode: TCFindMatchMode;
    FCaseSensitive: Boolean;
    FIncludeSubfolders: Boolean;
    FSearchHidden: Boolean;
    FMaxResults: Integer;
    FShowOptionsMenu: Boolean;
    FSearching: Boolean;
    FResultCount: Integer;
    FResultsActive: Boolean;          // 検索結果を、ListView に出している
    FSearchFolder: string;            // 探したフォルダー
    FRootIsAuto: Boolean;             // Finder.Root は、ListView・TreeView のフォルダーから、この部品が入れたもの
    FPending: TStringList;            // まだ ListView に足していない結果
    FSpinTimer: TTimer;
    FFlushTimer: TTimer;
    FSpinAngle: Integer;
    FErrorText: string;
    FKeyHandlerAdded: Boolean;
    FColor: TColor;
    FMenu: TPopupMenu;
    FHotClear, FHotAction: Boolean;
    FClearR, FActionR, FBoxR: TRect;
    FInSetText: Boolean;
    FOnChange: TNotifyEvent;
    FOnSearchStart: TNotifyEvent;
    FOnSearchResult: TCSearchResultEvent;
    FOnSearchFinished: TCSearchFinishedEvent;
    FOnSearchError: TCSearchErrorEvent;
    procedure SetListView(AValue: TCListView);
    procedure SetTreeView(AValue: TCTreeView);
    procedure SetTextHint(const AValue: string);
    procedure SetColor(AValue: TColor);
    function GetSearchText: string;
    procedure SetSearchText(const AValue: string);
    function Scale(ASize: Integer): Integer;
    function BoxColor: TColor;
    procedure LayoutAll;
    procedure LinkTo(AView: TControl; AAdd: Boolean);
    procedure FolderLinkChanged(Sender: TObject);
    function SearchFolder: string;
    function EffectiveHint: string;
    procedure UpdateHint;
    procedure ReportError(const AMessage: string);
    procedure FlushPending;
    procedure FinderFound(Sender: TObject; const APath: string; AIsDir: Boolean);
    procedure FinderFinished(Sender: TObject; AFound: Integer; AReason: TCFindStopReason);
    procedure SpinTick(Sender: TObject);
    procedure FlushTick(Sender: TObject);
    procedure EditChange(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditEnter(Sender: TObject);
    procedure EditExit(Sender: TObject);
    procedure AppKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ShowOptions;
    procedure OptionModeClick(Sender: TObject);
    procedure OptionCaseClick(Sender: TObject);
    procedure OptionSubClick(Sender: TObject);
    procedure OptionHiddenClick(Sender: TObject);
    procedure DrawSymbol(const R: TRect; ACode: Cardinal; AColor: TColor);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
    procedure CMFontChanged(var Message: TLMessage); message CM_FONTCHANGED;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    // Enter と同じ。今の Text で、探し始める
    procedure Search;
    // 探している最中なら止める（結果は残す）
    procedure StopSearch;
    // 探すのを止め、Text を空にし、検索結果の表示を終える
    procedure ClearSearch;
    procedure SetFocus; override;
    property Searching: Boolean read FSearching;
    property ResultCount: Integer read FResultCount;
    property Finder: TCFindFile read FFinder;
  published
    property ListView: TCListView read FListView write SetListView;
    property TreeView: TCTreeView read FTreeView write SetTreeView;
    property Text: string read GetSearchText write SetSearchText;
    property TextHint: string read FTextHint write SetTextHint;
    property MatchMode: TCFindMatchMode read FMatchMode write FMatchMode default fmContains;
    property CaseSensitive: Boolean read FCaseSensitive write FCaseSensitive default False;
    property IncludeSubfolders: Boolean read FIncludeSubfolders write FIncludeSubfolders default True;
    property SearchHidden: Boolean read FSearchHidden write FSearchHidden default False;
    property MaxResults: Integer read FMaxResults write FMaxResults default cFindMaxDef;
    property ShowOptionsMenu: Boolean read FShowOptionsMenu write FShowOptionsMenu default True;
    property Color: TColor read FColor write SetColor default clDefault;
    property Align;
    property Anchors;
    property BorderSpacing;
    property Constraints;
    property Enabled;
    property Font;
    property ParentFont;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default True;
    property Visible;
    property Width default 260;
    property Height default 32;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnSearchStart: TNotifyEvent read FOnSearchStart write FOnSearchStart;
    property OnSearchResult: TCSearchResultEvent read FOnSearchResult write FOnSearchResult;
    property OnSearchFinished: TCSearchFinishedEvent read FOnSearchFinished write FOnSearchFinished;
    property OnSearchError: TCSearchErrorEvent read FOnSearchError write FOnSearchError;
  end;

implementation

const
  // Segoe MDL2 Assets の記号
  SYM_SEARCH = $E721;
  SYM_CLEAR = $E711;

{ TCSearchBox }

constructor TCSearchBox.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  ControlStyle := ControlStyle + [csOpaque] - [csSetCaption];
  FColor := clDefault;
  FMatchMode := fmContains;
  FIncludeSubfolders := True;
  FMaxResults := cFindMaxDef;
  FShowOptionsMenu := True;
  FPending := TStringList.Create;
  TabStop := True;
  Width := 260;
  Height := CXScale96(Self, 32);

  FFinder := TCFindFile.Create(Self);
  FFinder.OnFound := @FinderFound;
  FFinder.OnFinished := @FinderFinished;

  FEdit := TEdit.Create(Self);
  FEdit.Parent := Self;
  FEdit.BorderStyle := bsNone;
  FEdit.OnChange := @EditChange;
  FEdit.OnKeyDown := @EditKeyDown;
  FEdit.OnEnter := @EditEnter;
  FEdit.OnExit := @EditExit;
  if csDesigning in ComponentState then FEdit.Enabled := False;

  if not (csDesigning in ComponentState) then
  begin
    FSpinTimer := TTimer.Create(Self);
    FSpinTimer.Enabled := False;
    FSpinTimer.Interval := 100;
    FSpinTimer.OnTimer := @SpinTick;
    FFlushTimer := TTimer.Create(Self);
    FFlushTimer.Enabled := False;
    FFlushTimer.Interval := 100;
    FFlushTimer.OnTimer := @FlushTick;
    Application.AddOnKeyDownHandler(@AppKeyDown);
    FKeyHandlerAdded := True;
  end;
  UpdateHint;
end;

destructor TCSearchBox.Destroy;
begin
  if FKeyHandlerAdded then Application.RemoveOnKeyDownHandler(@AppKeyDown);
  if FFinder <> nil then
  begin
    FFinder.OnFound := nil;
    FFinder.OnFinished := nil;
    FFinder.Stop;
  end;
  LinkTo(FListView, False);
  LinkTo(FTreeView, False);
  FreeAndNil(FMenu);
  FPending.Free;
  inherited Destroy;
end;

function TCSearchBox.Scale(ASize: Integer): Integer;
begin
  Result := CXScale96(Self, ASize);
end;

function TCSearchBox.BoxColor: TColor;
begin
  if FColor = clDefault then Result := clWindow else Result := FColor;
end;

procedure TCSearchBox.SetColor(AValue: TColor);
begin
  if FColor = AValue then Exit;
  FColor := AValue;
  if FEdit <> nil then FEdit.Color := BoxColor;
  Invalidate;
end;

{ ---- つなぐ ---- }

procedure TCSearchBox.LinkTo(AView: TControl; AAdd: Boolean);
begin
  if AView = nil then Exit;
  if AView is TCListView then
  begin
    if AAdd then TCListView(AView).AddFolderLink(@FolderLinkChanged)
    else TCListView(AView).RemoveFolderLink(@FolderLinkChanged);
  end
  else if AView is TCTreeView then
  begin
    if AAdd then TCTreeView(AView).AddFolderLink(@FolderLinkChanged)
    else TCTreeView(AView).RemoveFolderLink(@FolderLinkChanged);
  end;
end;

procedure TCSearchBox.SetListView(AValue: TCListView);
begin
  if FListView = AValue then Exit;
  if FListView <> nil then
  begin
    if not (csDesigning in ComponentState) then LinkTo(FListView, False);
    FListView.RemoveFreeNotification(Self);
  end;
  FListView := AValue;
  FResultsActive := False;
  if FListView <> nil then
  begin
    FListView.FreeNotification(Self);
    if not (csDesigning in ComponentState) then LinkTo(FListView, True);
  end;
  UpdateHint;
end;

procedure TCSearchBox.SetTreeView(AValue: TCTreeView);
begin
  if FTreeView = AValue then Exit;
  if FTreeView <> nil then
  begin
    if not (csDesigning in ComponentState) then LinkTo(FTreeView, False);
    FTreeView.RemoveFreeNotification(Self);
  end;
  FTreeView := AValue;
  if FTreeView <> nil then
  begin
    FTreeView.FreeNotification(Self);
    if not (csDesigning in ComponentState) then LinkTo(FTreeView, True);
  end;
  UpdateHint;
end;

procedure TCSearchBox.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FListView then
    begin
      FListView := nil;       // 壊れる部品へは、もう RemoveFolderLink を呼ばない
      FResultsActive := False;
      FPending.Clear;
      if FSearching and (FFinder <> nil) then FFinder.Stop;
      UpdateHint;
    end;
    if AComponent = FTreeView then
    begin
      FTreeView := nil;
      UpdateHint;
    end;
  end;
end;

// 探すフォルダー：検索結果を出しているあいだは、探したフォルダー。なければ ListView の Root、TreeView の Path、Finder.Root の順
function TCSearchBox.SearchFolder: string;
begin
  Result := '';
  if (FListView <> nil) and FListView.ResultsMode and FResultsActive and (FSearchFolder <> '') then
    Exit(FSearchFolder);
  if (FListView <> nil) and (FListView.Root <> '') then
    Exit(ExcludeTrailingPathDelimiter(FListView.Root));
  if FTreeView <> nil then
  begin
    Result := ExcludeTrailingPathDelimiter(FTreeView.Path);
    Exit;
  end;
  Result := ExcludeTrailingPathDelimiter(FFinder.Root);
end;

function TCSearchBox.EffectiveHint: string;
var
  F, N: string;
begin
  if FTextHint <> '' then Exit(FTextHint);
  F := '';
  if not (csDesigning in ComponentState) then F := SearchFolder;
  if F = '' then Exit(CXT(sSbHintNone));
  N := ExtractFileName(F);
  if N = '' then N := F;          // ドライブのルート
  Result := Format(CXT(sSbHint), [N]);
end;

procedure TCSearchBox.UpdateHint;
begin
  if FEdit <> nil then FEdit.TextHint := EffectiveHint;
end;

procedure TCSearchBox.FolderLinkChanged(Sender: TObject);
begin
  // 検索結果を出していたのに、一覧が、ほかの操作で移った：探すのを止めて、文字を消す
  if FResultsActive and (FListView <> nil) and (not FListView.ResultsMode) then
  begin
    FResultsActive := False;
    FPending.Clear;
    if FSearching then FFinder.Stop;
    SetSearchText('');
  end;
  UpdateHint;
end;

{ ---- 文字 ---- }

function TCSearchBox.GetSearchText: string;
begin
  if FEdit <> nil then Result := FEdit.Text else Result := '';
end;

procedure TCSearchBox.SetSearchText(const AValue: string);
begin
  if FEdit = nil then Exit;
  if FEdit.Text = AValue then Exit;
  FEdit.Text := AValue;     // OnChange は、EditChange から出る
end;

procedure TCSearchBox.EditChange(Sender: TObject);
begin
  FErrorText := '';
  Hint := '';
  Invalidate;
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TCSearchBox.SetTextHint(const AValue: string);
begin
  if FTextHint = AValue then Exit;
  FTextHint := AValue;
  UpdateHint;
end;

{ ---- 探す ---- }

procedure TCSearchBox.ReportError(const AMessage: string);
begin
  if Assigned(FOnSearchError) then
    FOnSearchError(Self, AMessage)
  else
  begin
    FErrorText := AMessage;
    Hint := AMessage;
    Invalidate;
  end;
end;

procedure TCSearchBox.Search;
var
  S, Folder, Err: string;
begin
  S := Trim(GetSearchText);
  if S = '' then
  begin
    ClearSearch;
    Exit;
  end;
  FErrorText := '';
  Folder := SearchFolder;
  if Folder = '' then
  begin
    ReportError(CXT(sSbErrNoFolder));
    Exit;
  end;
  if not DirectoryExists(Folder) then
  begin
    ReportError(Format(CXT(sSbErrNoRoot), [Folder]));
    Exit;
  end;
  if FSearching then
  begin
    // 前の探しを止めて、終わるのを待つ
    FFinder.Stop;
    FFinder.WaitFor(10000);
  end;
  // ListView・TreeView がないときは、アプリが先に入れた Finder.Root を使う。そうでないときの Finder.Root は、
  // 探し終わったら空に戻す（次に ListView・TreeView を外したとき、前のフォルダーを探さないように）
  FRootIsAuto := (FListView <> nil) or (FTreeView <> nil);
  FFinder.Root := Folder;
  FFinder.Pattern := S;
  FFinder.MatchMode := FMatchMode;
  FFinder.CaseSensitive := FCaseSensitive;
  FFinder.IncludeSubfolders := FIncludeSubfolders;
  FFinder.SearchHidden := FSearchHidden;
  FFinder.MaxResults := FMaxResults;
  if not FFinder.CheckPattern(Err) then
  begin
    ReportError(Format(CXT(sSbErrRegex), [Err]));
    Exit;
  end;
  FPending.Clear;
  FResultCount := 0;
  if FListView <> nil then
  begin
    FListView.BeginResults(Folder);
    FResultsActive := True;
    FSearchFolder := Folder;
  end;
  if FFinder.Start then
  begin
    FSearching := True;
    FSpinAngle := 0;
    if FSpinTimer <> nil then FSpinTimer.Enabled := True;
    if FFlushTimer <> nil then FFlushTimer.Enabled := True;
    if Assigned(FOnSearchStart) then FOnSearchStart(Self);
    Invalidate;
  end;
end;

procedure TCSearchBox.StopSearch;
begin
  if FSearching then FFinder.Stop;
end;

procedure TCSearchBox.ClearSearch;
begin
  if FSearching then FFinder.Stop;
  FPending.Clear;
  FErrorText := '';
  if FResultsActive then
  begin
    FResultsActive := False;      // EndResults が出す「フォルダーが変わった知らせ」で、自分が反応しないように
    if FListView <> nil then FListView.EndResults;
  end;
  SetSearchText('');
  Invalidate;
end;

procedure TCSearchBox.FinderFound(Sender: TObject; const APath: string; AIsDir: Boolean);
begin
  Inc(FResultCount);
  if FResultsActive and (FListView <> nil) then FPending.Add(APath);
  if Assigned(FOnSearchResult) then FOnSearchResult(Self, APath, AIsDir);
end;

// まとめて、一覧へ足す
procedure TCSearchBox.FlushPending;
begin
  if FPending.Count = 0 then Exit;
  if FResultsActive and (FListView <> nil) and FListView.ResultsMode then
    FListView.AddResults(FPending);
  FPending.Clear;
end;

procedure TCSearchBox.FlushTick(Sender: TObject);
begin
  FlushPending;
end;

procedure TCSearchBox.SpinTick(Sender: TObject);
begin
  FSpinAngle := (FSpinAngle + 30) mod 360;
  Invalidate;
end;

procedure TCSearchBox.FinderFinished(Sender: TObject; AFound: Integer; AReason: TCFindStopReason);
begin
  FlushPending;
  FSearching := False;
  if FRootIsAuto then
  begin
    FFinder.Root := '';
    FRootIsAuto := False;
  end;
  if FSpinTimer <> nil then FSpinTimer.Enabled := False;
  if FFlushTimer <> nil then FFlushTimer.Enabled := False;
  Invalidate;
  if Assigned(FOnSearchFinished) then FOnSearchFinished(Self, AFound, AReason);
end;

procedure TCSearchBox.SetFocus;
begin
  if (FEdit <> nil) and FEdit.CanFocus then
  begin
    FEdit.SetFocus;
    FEdit.SelectAll;
  end
  else
    inherited SetFocus;
end;

{ ---- キー ---- }

procedure TCSearchBox.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    Key := 0;
    Search;
  end
  else if (Key = VK_ESCAPE) and (Shift = []) then
  begin
    if FSearching then
    begin
      StopSearch;
      Key := 0;
    end
    else if GetSearchText <> '' then
    begin
      ClearSearch;
      Key := 0;
    end;
  end;
end;

// 一覧・ツリーにフォーカスがあるとき、Ctrl+E・Ctrl+F でこの部品へ
procedure TCSearchBox.AppKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  F: TCustomForm;
  Active: TControl;
begin
  if (csDesigning in ComponentState) or (not Enabled) or (not Visible) then Exit;
  if not (((Key = VK_E) or (Key = VK_F)) and (Shift = [ssCtrl])) then Exit;
  F := GetParentForm(Self);
  if (F = nil) or (Screen.ActiveForm <> F) then Exit;
  Active := F.ActiveControl;
  if Active = nil then Exit;
  if (Active = FListView) or (Active = FTreeView) or (Active = FEdit) or (Active = Self) then
  begin
    SetFocus;
    Key := 0;
  end;
end;

procedure TCSearchBox.EditEnter(Sender: TObject);
begin
  Invalidate;
end;

procedure TCSearchBox.EditExit(Sender: TObject);
begin
  Invalidate;
end;

{ ---- オプションのメニュー ---- }

procedure TCSearchBox.OptionModeClick(Sender: TObject);
begin
  FMatchMode := TCFindMatchMode(TMenuItem(Sender).Tag);
end;

procedure TCSearchBox.OptionCaseClick(Sender: TObject);
begin
  FCaseSensitive := not FCaseSensitive;
end;

procedure TCSearchBox.OptionSubClick(Sender: TObject);
begin
  FIncludeSubfolders := not FIncludeSubfolders;
end;

procedure TCSearchBox.OptionHiddenClick(Sender: TObject);
begin
  FSearchHidden := not FSearchHidden;
end;

procedure TCSearchBox.ShowOptions;
var
  Item: TMenuItem;
  P: TPoint;
  I: Integer;
  Caps: array[0..2] of string;
begin
  FreeAndNil(FMenu);
  FMenu := TPopupMenu.Create(nil);
  Caps[0] := CXT(sSbMenuContains);
  Caps[1] := CXT(sSbMenuWildcard);
  Caps[2] := CXT(sSbMenuRegex);
  for I := 0 to 2 do
  begin
    Item := TMenuItem.Create(FMenu);
    Item.Caption := Caps[I];
    Item.RadioItem := True;
    Item.GroupIndex := 1;
    Item.Tag := I;
    Item.Checked := Ord(FMatchMode) = I;
    Item.OnClick := @OptionModeClick;
    FMenu.Items.Add(Item);
  end;
  Item := TMenuItem.Create(FMenu);
  Item.Caption := '-';
  FMenu.Items.Add(Item);
  Item := TMenuItem.Create(FMenu);
  Item.Caption := CXT(sSbMenuCase);
  Item.Checked := FCaseSensitive;
  Item.OnClick := @OptionCaseClick;
  FMenu.Items.Add(Item);
  Item := TMenuItem.Create(FMenu);
  Item.Caption := CXT(sSbMenuSub);
  Item.Checked := FIncludeSubfolders;
  Item.OnClick := @OptionSubClick;
  FMenu.Items.Add(Item);
  Item := TMenuItem.Create(FMenu);
  Item.Caption := CXT(sSbMenuHidden);
  Item.Checked := FSearchHidden;
  Item.OnClick := @OptionHiddenClick;
  FMenu.Items.Add(Item);
  P := ClientToScreen(Point(FActionR.Left, FActionR.Bottom));
  FMenu.PopUp(P.X, P.Y);
end;

{ ---- 描画・マウス ---- }

procedure TCSearchBox.LayoutAll;
var
  X: Integer;
begin
  FBoxR := Rect(Scale(2), Scale(3), Width - Scale(2), Height - Scale(3));
  X := FBoxR.Right - 1;
  FActionR := Rect(X - Scale(32), FBoxR.Top + 1, X, FBoxR.Bottom - 1);
  X := FActionR.Left;
  if (not FSearching) and (GetSearchText <> '') then
    FClearR := Rect(X - Scale(28), FBoxR.Top + 1, X, FBoxR.Bottom - 1)
  else
    FClearR := Rect(X, FBoxR.Top + 1, X, FBoxR.Bottom - 1);
  if FEdit <> nil then
    FEdit.SetBounds(FBoxR.Left + Scale(8), FBoxR.Top + (FBoxR.Bottom - FBoxR.Top - FEdit.Height) div 2,
      Max(Scale(8), FClearR.Left - FBoxR.Left - Scale(10)), FEdit.Height);   { 高さは、入力欄の自然な高さ }
end;

procedure TCSearchBox.Resize;
begin
  inherited Resize;
  LayoutAll;
  Invalidate;
end;

procedure TCSearchBox.CMEnabledChanged(var Message: TLMessage);
begin
  inherited;
  if FEdit <> nil then FEdit.Enabled := Enabled and not (csDesigning in ComponentState);
  Invalidate;
end;

procedure TCSearchBox.CMFontChanged(var Message: TLMessage);
begin
  inherited;
  if FEdit <> nil then FEdit.Font.Assign(Font);
  Invalidate;
end;

procedure TCSearchBox.DrawSymbol(const R: TRect; ACode: Cardinal; AColor: TColor);
var
  FontName: string;
  TS: TTextStyle;
  S: string;
begin
  FontName := CXSymbolFontName;
  Canvas.Brush.Style := bsClear;
  if FontName <> '' then
  begin
    CXSetSymbolFont(Canvas, FontName, Scale(14), AColor);
    S := CXSymbol(ACode);
  end
  else
  begin
    Canvas.Font.Assign(Font);
    Canvas.Font.Color := AColor;
    if ACode = SYM_CLEAR then S := 'x' else S := '?';
  end;
  TS := Canvas.TextStyle;
  TS.Alignment := taCenter;
  TS.Layout := tlCenter;
  TS.SingleLine := True;
  TS.Opaque := False;
  TS.Clipping := True;
  Canvas.TextRect(R, R.Left, R.Top, S, TS);
end;

procedure TCSearchBox.Paint;
var
  BorderC, TextC: TColor;
  CX, CY, Rad: Integer;
  A: Double;
begin
  LayoutAll;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(0, 0, Width, Height);

  if (FErrorText <> '') or ((FEdit <> nil) and False) then
    BorderC := clRed
  else if (FEdit <> nil) and FEdit.Focused and Enabled then
    BorderC := CXSplitLineColor(clHighlight)
  else
    BorderC := clBtnShadow;
  if Enabled then TextC := clWindowText else TextC := clGrayText;

  Canvas.Brush.Color := BoxColor;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Color := BorderC;
  Canvas.Rectangle(FBoxR.Left, FBoxR.Top, FBoxR.Right, FBoxR.Bottom);

  // 「×」
  if FClearR.Right > FClearR.Left then
  begin
    if FHotClear then
    begin
      Canvas.Brush.Color := CXBlendColor(BoxColor, clWindowText, 12);
      Canvas.Pen.Style := psClear;
      Canvas.Rectangle(FClearR.Left, FClearR.Top, FClearR.Right + 1, FClearR.Bottom + 1);
      Canvas.Pen.Style := psSolid;
    end;
    DrawSymbol(FClearR, SYM_CLEAR, TextC);
  end;

  // 虫眼鏡・回る印
  if FHotAction and Enabled and not (csDesigning in ComponentState) then
  begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := CXBlendColor(BoxColor, clWindowText, 12);
    Canvas.Pen.Style := psClear;
    Canvas.Rectangle(FActionR.Left, FActionR.Top, FActionR.Right + 1, FActionR.Bottom + 1);
    Canvas.Pen.Style := psSolid;
  end;
  if FSearching then
  begin
    CX := (FActionR.Left + FActionR.Right) div 2;
    CY := (FActionR.Top + FActionR.Bottom) div 2;
    Rad := Scale(7);
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := CXSplitLineColor(clHighlight);
    Canvas.Pen.Width := Max(2, Scale(2));
    A := FSpinAngle * Pi / 180;
    // 円弧（270 度分）
    Canvas.Arc(CX - Rad, CY - Rad, CX + Rad, CY + Rad,
      CX + Round(Rad * Cos(A)), CY - Round(Rad * Sin(A)),
      CX + Round(Rad * Cos(A + Pi / 2)), CY - Round(Rad * Sin(A + Pi / 2)));
    Canvas.Pen.Width := 1;
  end
  else
    DrawSymbol(FActionR, SYM_SEARCH, TextC);
end;

procedure TCSearchBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (csDesigning in ComponentState) or not Enabled or (Button <> mbLeft) then Exit;
  P := Point(X, Y);
  if PtInRect(FClearR, P) and (FClearR.Right > FClearR.Left) then
    ClearSearch
  else if PtInRect(FActionR, P) then
  begin
    if FSearching then
      StopSearch
    else if FShowOptionsMenu then
      ShowOptions;
  end
  else
    SetFocus;
end;

procedure TCSearchBox.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  C, A: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  if csDesigning in ComponentState then Exit;
  C := PtInRect(FClearR, Point(X, Y)) and (FClearR.Right > FClearR.Left);
  A := PtInRect(FActionR, Point(X, Y));
  if (C <> FHotClear) or (A <> FHotAction) then
  begin
    FHotClear := C;
    FHotAction := A;
    if A then
    begin
      if FSearching then Hint := CXT(sSbStop) else Hint := '';
    end
    else if C then
      Hint := CXT(sSbClear)
    else
      Hint := FErrorText;
    Invalidate;
  end;
end;

procedure TCSearchBox.MouseLeave;
begin
  inherited MouseLeave;
  if FHotClear or FHotAction then
  begin
    FHotClear := False;
    FHotAction := False;
    Invalidate;
  end;
end;

end.
