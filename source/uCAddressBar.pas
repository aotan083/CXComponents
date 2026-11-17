{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ ============================================================================
  uCAddressBar  -  TCAddressBar（Windows エクスプローラーのアドレスバーと同等の部品）

  設計書: docs\TCAddressBar_Design.md
  パッケージ: cx（実行時）

  ・TCListView・TCTreeView と連動する。パンくず（クリックで移動、「>」で下のフォルダーの一覧）、
    クリックしてパスを入力、戻る・進む・上へ・更新、最近の場所（履歴）。
  ・今のフォルダーの変化は、TCListView・TCTreeView の「フォルダーが変わった知らせ」（AddFolderLink）で知る。
    タイマーでの見張りはしない。
  ・パスは UTF-8 の文字列（Lazarus の既定）。
  ============================================================================ }
unit uCAddressBar;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Types, Controls, Graphics, Forms, Menus, StdCtrls, LCLType, LCLIntf,
  LMessages, ShellApi, ShlObj, ActiveX, Math, LazUTF8, uCXLang, uCTitleBar, CListView, CTreeView;

type
  TCABNavigatingEvent = procedure(Sender: TObject; const APath: string; var Allow: Boolean) of object;
  TCABNavigatedEvent = procedure(Sender: TObject; const APath: string) of object;
  TCABErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;

  // パンくずの 1 つの部分
  TCABSeg = record
    Path: string;       // フルパス（'' は「PC」）
    Caption: string;    // 表示する名前
    NameR: TRect;       // 名前の場所（クライアント座標。出していないときは空）
    ArrowR: TRect;      // 「>」の場所
  end;

  // マウスの乗っている・押している場所
  TCABHitKind = (hkNone, hkBack, hkForward, hkUp, hkRefresh, hkSeg, hkArrow, hkEllipsis, hkIcon, hkHistory, hkBox);
  TCABHit = record
    Kind: TCABHitKind;
    Index: Integer;     // hkSeg・hkArrow のとき、部分の番号
  end;

const
  cMaxPopupItems = 300;   // 「>」の一覧に出すフォルダーの最大数
  cHeight96 = 32;         // 既定の高さ（96dpi）

type
  { TCAddressBar }
  TCAddressBar = class(TCustomControl)
  private
    FListView: TCListView;
    FTreeView: TCTreeView;
    FSyncTree: Boolean;
    FShowNav: Boolean;
    FShowHistory: Boolean;
    FShowRefresh: Boolean;
    FPath: string;                       // ListView・TreeView がないときの今のフォルダー
    FShownPath: string;                  // 表示しているパンくずのフォルダー
    FSegs: array of TCABSeg;             // パンくずの部分
    FFirstVisible: Integer;              // 先頭に出す部分（それより前は「…」にまとめる）
    FEllipsisR: TRect;
    FBackR, FForwardR, FUpR, FRefreshR: TRect;
    FBoxR, FIconR, FHistoryR, FCrumbR: TRect;
    FHot: TCABHit;
    FDown: TCABHit;
    FEdit: TEdit;
    FErrorText: string;
    FKeyHandlerAdded: Boolean;
    FIcon: HICON;
    FIconPath: string;
    FIconValid: Boolean;
    FPopup: TPopupMenu;
    FPopupPaths: TStringList;
    FColor: TColor;
    FOnNavigating: TCABNavigatingEvent;
    FOnNavigated: TCABNavigatedEvent;
    FOnError: TCABErrorEvent;
    procedure SetListView(AValue: TCListView);
    procedure SetTreeView(AValue: TCTreeView);
    procedure SetSyncTree(AValue: Boolean);
    procedure SetShowNav(AValue: Boolean);
    procedure SetShowHistory(AValue: Boolean);
    procedure SetShowRefresh(AValue: Boolean);
    procedure SetColor(AValue: TColor);
    function GetPath: string;
    procedure SetPath(const AValue: string);
    function GetEditing: Boolean;
    function BoxColor: TColor;
    function Scale(ASize: Integer): Integer;
    function CurrentFolder: string;
    procedure FolderLinkChanged(Sender: TObject);
    procedure LinkTo(AView: TControl; AAdd: Boolean);
    procedure BuildSegs;
    procedure PlaceEdit;
    procedure LayoutAll;
    function HitAt(X, Y: Integer): TCABHit;
    function SameHit(const A, B: TCABHit): Boolean;
    function HitRect(const AHit: TCABHit): TRect;
    function CanBack: Boolean;
    function CanForward: Boolean;
    function ParentFolder: string;
    function CanUp: Boolean;
    procedure DoActivate(const AHit: TCABHit);
    procedure ShowSubfolderMenu(const AFolder, ANextPath: string; const AAnchor: TRect);
    procedure ShowEllipsisMenu(const AAnchor: TRect);
    procedure ShowHistoryMenu(const AAnchor: TRect);
    procedure PopupMenuItemClick(Sender: TObject);
    procedure HistoryItemClick(Sender: TObject);
    procedure ResetPopup;
    procedure ShowPopupAt(const AAnchor: TRect);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditExit(Sender: TObject);
    procedure AppKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure UpdateIcon;
    procedure FreeIcon;
    procedure DrawSymbol(const R: TRect; ACode: Cardinal; AColor: TColor);
    procedure DrawHot(const R: TRect; const AHit: TCABHit; ABack: TColor);
    function HintFor(const AHit: TCABHit): string;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
    procedure CMFontChanged(var Message: TLMessage); message CM_FONTCHANGED;
    procedure CMColorChanged(var Message: TLMessage); message CM_COLORCHANGED;
    procedure WMGetDlgCode(var Message: TLMessage); message LM_GETDLGCODE;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    // 3 章の「移る」。OnNavigating で断られた、フォルダーがない、のときは False
    function NavigateTo(const APath: string): Boolean;
    procedure BeginEdit;
    // 入力モードを終える。ACancel = False なら、入力した文字で移ろうとする
    procedure EndEdit(ACancel: Boolean);
    procedure Refresh; reintroduce;
    property Path: string read GetPath write SetPath;
    property Editing: Boolean read GetEditing;
  published
    property ListView: TCListView read FListView write SetListView;
    property TreeView: TCTreeView read FTreeView write SetTreeView;
    property SyncTree: Boolean read FSyncTree write SetSyncTree default True;
    property ShowNavButtons: Boolean read FShowNav write SetShowNav default True;
    property ShowHistoryButton: Boolean read FShowHistory write SetShowHistory default True;
    property ShowRefreshButton: Boolean read FShowRefresh write SetShowRefresh default True;
    property Color: TColor read FColor write SetColor default clDefault;
    property Align default alTop;
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
    property OnNavigating: TCABNavigatingEvent read FOnNavigating write FOnNavigating;
    property OnNavigated: TCABNavigatedEvent read FOnNavigated write FOnNavigated;
    property OnError: TCABErrorEvent read FOnError write FOnError;
  end;

// パスを、各部分のフルパスに分ける。先頭は常に ''（「PC」）。例：C:\app\laz → '', C:\, C:\app, C:\app\laz
procedure CABSplitPath(const APath: string; AList: TStrings);
// 入力の文字を整える（前後の空白・" を除く、環境変数の展開、/ を \ に、C: を C:\ に、末尾の \ を除く）。
// フォルダーとして存在すれば True（APath に整えたパス）
function CABNormalizeInput(const S: string; out APath: string): Boolean;

implementation

const
  // Segoe MDL2 Assets の記号
  SYM_BACK = $E72B;
  SYM_FORWARD = $E72A;
  SYM_UP = $E74A;
  SYM_REFRESH = $E72C;
  SYM_CHEVRON = $E76C;
  SYM_DOWN = $E70D;

function StrCmpLogicalW(psz1, psz2: PWideChar): Integer; stdcall; external 'shlwapi.dll';

{ ---- 長いパス・パスの部品 ---- }

function LongPathW(const AUtf8: string): UnicodeString;
var
  S: UnicodeString;
begin
  S := UTF8Decode(AUtf8);
  if Length(S) < 240 then Exit(S);
  if Copy(S, 1, 4) = '\\?\' then Exit(S);
  if Copy(S, 1, 2) = '\\' then
    Result := '\\?\UNC\' + Copy(S, 3, MaxInt)
  else
    Result := '\\?\' + S;
end;

function DirExistsLong(const APath: string): Boolean;
var
  A: DWORD;
begin
  A := GetFileAttributesW(PWideChar(LongPathW(APath)));
  Result := (A <> INVALID_FILE_ATTRIBUTES) and ((A and FILE_ATTRIBUTE_DIRECTORY) <> 0);
end;

// ドライブのルート（C:\）か
function IsDriveRoot(const APath: string): Boolean;
begin
  Result := (Length(APath) = 3) and (APath[2] = ':') and (APath[3] = '\');
end;

// 末尾の \ を除く。ドライブのルート（C:\）だけは残す
function TrimTail(const APath: string): string;
begin
  Result := APath;
  while (Length(Result) > 0) and (Result[Length(Result)] = '\') and not IsDriveRoot(Result) do
    Delete(Result, Length(Result), 1);
end;

procedure CABSplitPath(const APath: string; AList: TStrings);
var
  P, Cur, Rest, Part: string;
  I, K: Integer;
begin
  AList.Clear;
  AList.Add('');
  P := TrimTail(APath);
  if P = '' then Exit;
  if Copy(P, 1, 2) = '\\' then
  begin
    // \\server\share\x → \\server、\\server\share、\\server\share\x
    Rest := Copy(P, 3, MaxInt);
    Cur := '\\';
    K := 0;
    while Rest <> '' do
    begin
      I := Pos('\', Rest);
      if I = 0 then
      begin
        Part := Rest;
        Rest := '';
      end
      else
      begin
        Part := Copy(Rest, 1, I - 1);
        Rest := Copy(Rest, I + 1, MaxInt);
      end;
      if Part = '' then Continue;
      if K = 0 then Cur := Cur + Part else Cur := Cur + '\' + Part;
      Inc(K);
      AList.Add(Cur);
    end;
    Exit;
  end;
  if (Length(P) >= 2) and (P[2] = ':') then
  begin
    Cur := Copy(P, 1, 2) + '\';
    AList.Add(Cur);
    Rest := Copy(P, 4, MaxInt);
  end
  else
  begin
    Cur := '';
    Rest := P;
  end;
  while Rest <> '' do
  begin
    I := Pos('\', Rest);
    if I = 0 then
    begin
      Part := Rest;
      Rest := '';
    end
    else
    begin
      Part := Copy(Rest, 1, I - 1);
      Rest := Copy(Rest, I + 1, MaxInt);
    end;
    if Part = '' then Continue;
    if (Cur = '') or (Cur[Length(Cur)] = '\') then Cur := Cur + Part else Cur := Cur + '\' + Part;
    AList.Add(Cur);
  end;
end;

function CABNormalizeInput(const S: string; out APath: string): Boolean;
var
  T: string;
  W, Buf: UnicodeString;
  N: DWORD;
begin
  Result := False;
  APath := '';
  T := Trim(S);
  if T = '' then Exit;
  if (Length(T) > 0) and (T[1] = '"') then Delete(T, 1, 1);
  if (Length(T) > 0) and (T[Length(T)] = '"') then Delete(T, Length(T), 1);
  T := Trim(T);
  if T = '' then Exit;
  // %USERPROFILE% などを置き換える
  W := UTF8Decode(T);
  SetLength(Buf, 32768);
  N := ExpandEnvironmentStringsW(PWideChar(W), PWideChar(Buf), Length(Buf));
  if (N > 0) and (N <= DWORD(Length(Buf))) then
  begin
    SetLength(Buf, N - 1);
    T := UTF8Encode(Buf);
  end;
  T := StringReplace(T, '/', '\', [rfReplaceAll]);
  if (Length(T) = 2) and (T[2] = ':') then T := T + '\';
  T := TrimTail(T);
  if T = '' then Exit;
  if not DirExistsLong(T) then Exit;
  APath := T;
  Result := True;
end;

// 部分の表示名：ドライブのルートは、シェルの名前（「ローカル ディスク (C:)」など）
function DisplayNameOf(const APath: string): string;
var
  FI: TSHFileInfoW;
begin
  if APath = '' then Exit(CXT(sAddrPC));
  if Copy(APath, 1, 2) = '\\' then
  begin
    // \\server はそのまま。共有（\\server\share）以降は、最後の名前
    if Pos('\', Copy(APath, 3, MaxInt)) = 0 then Exit(APath);
    Exit(ExtractFileName(APath));
  end;
  if IsDriveRoot(APath) then
  begin
    FI := Default(TSHFileInfoW);
    if SHGetFileInfoW(PWideChar(UTF8Decode(APath)), 0, FI, SizeOf(FI), SHGFI_DISPLAYNAME) <> 0 then
      Result := UTF8Encode(UnicodeString(PWideChar(@FI.szDisplayName[0])))
    else
      Result := Copy(APath, 1, 2);
    if Result = '' then Result := Copy(APath, 1, 2);
    Exit;
  end;
  Result := ExtractFileName(APath);
  if Result = '' then Result := APath;
end;

function JoinPathAB(const AFolder, AName: string): string;
begin
  if (AFolder <> '') and (AFolder[Length(AFolder)] = '') then
    Result := AFolder + AName
  else
    Result := AFolder + '' + AName;
end;

function IfThenColor(ACond: Boolean; const A, B: TColor): TColor;
begin
  if ACond then Result := A else Result := B;
end;

// 名前の並べ替え（エクスプローラーと同じ自然順）
function CompareNaturalNames(List: TStringList; Index1, Index2: Integer): Integer;
begin
  Result := StrCmpLogicalW(PWideChar(UTF8Decode(List[Index1])), PWideChar(UTF8Decode(List[Index2])));
end;

// フォルダーの下の、フォルダーの名前を集める（隠し・システムは除く）。読めなければ、空
procedure ReadSubfolders(const AFolder: string; AList: TStringList; out ATooMany: Boolean);
var
  FD: TWin32FindDataW;
  H: THandle;
  Name: string;
  Mask: string;
begin
  AList.Clear;
  ATooMany := False;
  Mask := AFolder;
  if (Mask <> '') and (Mask[Length(Mask)] <> '\') then Mask := Mask + '\';
  Mask := Mask + '*';
  FD := Default(TWin32FindDataW);
  H := FindFirstFileW(PWideChar(LongPathW(Mask)), FD);
  if H = INVALID_HANDLE_VALUE then Exit;
  try
    repeat
      if (FD.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then Continue;
      if (FD.dwFileAttributes and (FILE_ATTRIBUTE_HIDDEN or FILE_ATTRIBUTE_SYSTEM)) <> 0 then Continue;
      Name := UTF8Encode(UnicodeString(PWideChar(@FD.cFileName[0])));
      if (Name = '.') or (Name = '..') then Continue;
      if AList.Count >= cMaxPopupItems then
      begin
        ATooMany := True;
        Break;
      end;
      AList.Add(Name);
    until not FindNextFileW(H, FD);
  finally
    Windows.FindClose(H);
  end;
  // 名前で並べる（エクスプローラーと同じ自然順）
  AList.CustomSort(@CompareNaturalNames);
end;

{ TCAddressBar }

constructor TCAddressBar.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  ControlStyle := ControlStyle + [csOpaque] - [csSetCaption];
  FSyncTree := True;
  FShowNav := True;
  FShowHistory := True;
  FShowRefresh := True;
  FColor := clDefault;
  FPopupPaths := TStringList.Create;
  FHot.Kind := hkNone;
  FDown.Kind := hkNone;
  TabStop := True;
  Align := alTop;
  Width := 400;
  Height := CXScale96(Self, cHeight96);
  if not (csDesigning in ComponentState) then
  begin
    Application.AddOnKeyDownHandler(@AppKeyDown);
    FKeyHandlerAdded := True;
  end;
end;

destructor TCAddressBar.Destroy;
begin
  if FKeyHandlerAdded then Application.RemoveOnKeyDownHandler(@AppKeyDown);
  LinkTo(FListView, False);
  LinkTo(FTreeView, False);
  ResetPopup;
  FPopupPaths.Free;
  FreeIcon;
  inherited Destroy;
end;

function TCAddressBar.Scale(ASize: Integer): Integer;
begin
  Result := CXScale96(Self, ASize);
end;

{ ---- つなぐ ---- }

procedure TCAddressBar.LinkTo(AView: TControl; AAdd: Boolean);
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

procedure TCAddressBar.SetListView(AValue: TCListView);
begin
  if FListView = AValue then Exit;
  if FListView <> nil then
  begin
    if not (csDesigning in ComponentState) then LinkTo(FListView, False);
    FListView.RemoveFreeNotification(Self);
  end;
  FListView := AValue;
  if FListView <> nil then
  begin
    FListView.FreeNotification(Self);
    if not (csDesigning in ComponentState) then LinkTo(FListView, True);
  end;
  Invalidate;
end;

procedure TCAddressBar.SetTreeView(AValue: TCTreeView);
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
  Invalidate;
end;

procedure TCAddressBar.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FListView then
    begin
      FListView := nil;     // 壊れる部品へは、もう RemoveFolderLink を呼ばない
      Invalidate;
    end;
    if AComponent = FTreeView then
    begin
      FTreeView := nil;
      Invalidate;
    end;
  end;
end;

procedure TCAddressBar.FolderLinkChanged(Sender: TObject);
begin
  FErrorText := '';
  if Editing then Exit;     // 入力欄を壊さない
  Invalidate;
end;

procedure TCAddressBar.SetSyncTree(AValue: Boolean);
begin
  FSyncTree := AValue;
end;

procedure TCAddressBar.SetShowNav(AValue: Boolean);
begin
  if FShowNav = AValue then Exit;
  FShowNav := AValue;
  Invalidate;
end;

procedure TCAddressBar.SetShowHistory(AValue: Boolean);
begin
  if FShowHistory = AValue then Exit;
  FShowHistory := AValue;
  Invalidate;
end;

procedure TCAddressBar.SetShowRefresh(AValue: Boolean);
begin
  if FShowRefresh = AValue then Exit;
  FShowRefresh := AValue;
  Invalidate;
end;

procedure TCAddressBar.SetColor(AValue: TColor);
begin
  if FColor = AValue then Exit;
  FColor := AValue;
  Invalidate;
end;

function TCAddressBar.BoxColor: TColor;
begin
  if FColor = clDefault then Result := clWindow else Result := FColor;
end;

function TCAddressBar.GetEditing: Boolean;
begin
  Result := FEdit <> nil;
end;

{ ---- 今のフォルダー ---- }

function TCAddressBar.CurrentFolder: string;
begin
  if (FListView <> nil) and (FListView.Root <> '') then
    Result := TrimTail(FListView.Root)
  else if FTreeView <> nil then
    Result := TrimTail(FTreeView.Path)
  else
    Result := FPath;
end;

function TCAddressBar.GetPath: string;
begin
  Result := CurrentFolder;
end;

procedure TCAddressBar.SetPath(const AValue: string);
begin
  NavigateTo(AValue);
end;

function SamePathText(const A, B: string): Boolean;
begin
  Result := SameText(TrimTail(A), TrimTail(B));
end;

function TCAddressBar.NavigateTo(const APath: string): Boolean;
var
  P: string;
  Allow: Boolean;
begin
  Result := False;
  P := TrimTail(APath);
  if (P = '') or (not DirExistsLong(P)) then Exit;
  Allow := True;
  if Assigned(FOnNavigating) then FOnNavigating(Self, P, Allow);
  if not Allow then Exit;
  FErrorText := '';
  if FListView <> nil then
  begin
    if not SamePathText(FListView.Root, P) then FListView.NavigateTo(P)
    else if FListView.ResultsMode then FListView.EndResults;
    if (FTreeView <> nil) and FSyncTree then FTreeView.Path := P;
    Result := True;
  end
  else if FTreeView <> nil then
  begin
    FTreeView.Path := P;
    Result := True;
  end
  else
  begin
    FPath := P;
    Result := True;
  end;
  Invalidate;
  if Result and Assigned(FOnNavigated) then FOnNavigated(Self, P);
end;

procedure TCAddressBar.Refresh;
begin
  if FListView <> nil then
  begin
    if not FListView.ResultsMode then FListView.UpdateView;
  end
  else if FTreeView <> nil then
    FTreeView.Refresh;
  Invalidate;
end;

{ ---- 戻る・進む・上へ ---- }

function TCAddressBar.CanBack: Boolean;
begin
  Result := (FListView <> nil) and FListView.CanGoBack;
end;

function TCAddressBar.CanForward: Boolean;
begin
  Result := (FListView <> nil) and FListView.CanGoForward;
end;

function TCAddressBar.ParentFolder: string;
var
  Cur, Par: string;
begin
  Result := '';
  Cur := CurrentFolder;
  if (Cur = '') or IsDriveRoot(Cur) then Exit;
  Par := ExtractFileDir(Cur);
  if (Par = '') or SameText(TrimTail(Par), Cur) then Exit;
  if Copy(Par, 1, 2) = '\\' then
    if Pos('\', Copy(Par, 3, MaxInt)) = 0 then Exit;    // \\server は、フォルダーではない
  if (Length(Par) = 2) and (Par[2] = ':') then Par := Par + '\';
  Result := Par;
end;

function TCAddressBar.CanUp: Boolean;
begin
  Result := ParentFolder <> '';
end;

{ ---- パンくずの部品 ---- }

procedure TCAddressBar.BuildSegs;
var
  L: TStringList;
  I: Integer;
begin
  FShownPath := CurrentFolder;
  L := TStringList.Create;
  try
    CABSplitPath(FShownPath, L);
    SetLength(FSegs, L.Count);
    for I := 0 to L.Count - 1 do
    begin
      FSegs[I].Path := L[I];
      FSegs[I].Caption := DisplayNameOf(L[I]);
      FSegs[I].NameR := Rect(0, 0, 0, 0);
      FSegs[I].ArrowR := Rect(0, 0, 0, 0);
    end;
  finally
    L.Free;
  end;
  UpdateIcon;
end;

procedure TCAddressBar.FreeIcon;
begin
  if FIcon <> 0 then DestroyIcon(FIcon);
  FIcon := 0;
  FIconValid := False;
end;

// 今のフォルダーのアイコン（小）を取る。'' は「PC」のアイコン
procedure TCAddressBar.UpdateIcon;
var
  FI: TSHFileInfoW;
  PIDL: PItemIDList;
begin
  if FIconValid and (FIconPath = FShownPath) then Exit;
  FreeIcon;
  FIconPath := FShownPath;
  FI := Default(TSHFileInfoW);
  if FShownPath = '' then
  begin
    PIDL := nil;
    if SHGetSpecialFolderLocation(0, CSIDL_DRIVES, PIDL) = 0 then
    begin
      try
        if SHGetFileInfoW(PWideChar(PIDL), 0, FI, SizeOf(FI), SHGFI_PIDL or SHGFI_ICON or SHGFI_SMALLICON) <> 0 then
          FIcon := FI.hIcon;
      finally
        CoTaskMemFree(PIDL);
      end;
    end;
  end
  else if SHGetFileInfoW(PWideChar(LongPathW(FShownPath)), 0, FI, SizeOf(FI), SHGFI_ICON or SHGFI_SMALLICON) <> 0 then
    FIcon := FI.hIcon;
  FIconValid := True;
end;

procedure TCAddressBar.LayoutAll;
var
  RowTop, RowBottom, X, BtnW, I, W, NameW, ArrowW, EllW, Pad, Total, Avail, CrumbL, CrumbR: Integer;
  Widths: array of Integer;
begin
  RowTop := Scale(3);
  RowBottom := Height - Scale(3);
  BtnW := Scale(32);
  X := Scale(4);
  FBackR := Rect(0, 0, 0, 0);
  FForwardR := FBackR;
  FUpR := FBackR;
  FRefreshR := FBackR;
  if FShowNav then
  begin
    FBackR := Rect(X, RowTop, X + BtnW, RowBottom);
    Inc(X, BtnW);
    FForwardR := Rect(X, RowTop, X + BtnW, RowBottom);
    Inc(X, BtnW);
    FUpR := Rect(X, RowTop, X + BtnW, RowBottom);
    Inc(X, BtnW);
  end;
  if FShowRefresh then
  begin
    FRefreshR := Rect(X, RowTop, X + BtnW, RowBottom);
    Inc(X, BtnW);
  end;
  if X > Scale(4) then Inc(X, Scale(6));
  FBoxR := Rect(X, RowTop, Width - Scale(4), RowBottom);
  if FBoxR.Right < FBoxR.Left then FBoxR.Right := FBoxR.Left;
  // 枠の中：左にアイコン、右に「v」、その間がパンくず
  CrumbL := FBoxR.Left + Scale(2);
  FIconR := Rect(CrumbL, FBoxR.Top, CrumbL + Scale(26), FBoxR.Bottom);
  CrumbL := FIconR.Right;
  CrumbR := FBoxR.Right - Scale(2);
  FHistoryR := Rect(0, 0, 0, 0);
  if FShowHistory then
  begin
    FHistoryR := Rect(CrumbR - Scale(28), FBoxR.Top, CrumbR, FBoxR.Bottom);
    CrumbR := FHistoryR.Left;
  end;
  FCrumbR := Rect(CrumbL, FBoxR.Top, CrumbR, FBoxR.Bottom);

  // パンくずの部分の幅
  if (Length(FSegs) = 0) or (FShownPath <> CurrentFolder) then BuildSegs;
  Canvas.Font.Assign(Font);
  Pad := Scale(8);
  ArrowW := Scale(20);
  EllW := Scale(28);
  SetLength(Widths, Length(FSegs));
  Total := 0;
  for I := 0 to High(FSegs) do
  begin
    NameW := Canvas.TextWidth(FSegs[I].Caption) + 2 * Pad;
    Widths[I] := NameW;
    Inc(Total, NameW + ArrowW);
  end;
  Avail := FCrumbR.Right - FCrumbR.Left;
  FFirstVisible := 0;
  if Total > Avail then
  begin
    // 後ろから、収まる部分だけ。前の部分は「…」にまとめる。最後の部分は、必ず出す
    FFirstVisible := High(FSegs);
    W := Widths[High(FSegs)] + ArrowW + EllW;
    for I := High(FSegs) - 1 downto 0 do
    begin
      if W + Widths[I] + ArrowW > Avail then Break;
      Inc(W, Widths[I] + ArrowW);
      FFirstVisible := I;
    end;
  end;
  for I := 0 to High(FSegs) do
  begin
    FSegs[I].NameR := Rect(0, 0, 0, 0);
    FSegs[I].ArrowR := Rect(0, 0, 0, 0);
  end;
  X := FCrumbR.Left;
  FEllipsisR := Rect(0, 0, 0, 0);
  if FFirstVisible > 0 then
  begin
    FEllipsisR := Rect(X, FCrumbR.Top, X + EllW, FCrumbR.Bottom);
    Inc(X, EllW);
  end;
  for I := FFirstVisible to High(FSegs) do
  begin
    NameW := Widths[I];
    if (I = High(FSegs)) and (X + NameW + ArrowW > FCrumbR.Right) then
      NameW := FCrumbR.Right - X - ArrowW;   // 最後の部分は、入りきらなければ、右を切る
    if NameW < Scale(8) then NameW := Scale(8);
    FSegs[I].NameR := Rect(X, FCrumbR.Top + Scale(2), X + NameW, FCrumbR.Bottom - Scale(2));
    Inc(X, NameW);
    FSegs[I].ArrowR := Rect(X, FCrumbR.Top + Scale(2), X + ArrowW, FCrumbR.Bottom - Scale(2));
    Inc(X, ArrowW);
  end;
end;

{ ---- 当たり判定 ---- }

function TCAddressBar.HitAt(X, Y: Integer): TCABHit;
var
  P: TPoint;
  I: Integer;
begin
  Result.Kind := hkNone;
  Result.Index := -1;
  P := Point(X, Y);
  if FShowNav then
  begin
    if PtInRect(FBackR, P) then begin Result.Kind := hkBack; Exit; end;
    if PtInRect(FForwardR, P) then begin Result.Kind := hkForward; Exit; end;
    if PtInRect(FUpR, P) then begin Result.Kind := hkUp; Exit; end;
  end;
  if FShowRefresh and PtInRect(FRefreshR, P) then begin Result.Kind := hkRefresh; Exit; end;
  if not PtInRect(FBoxR, P) then Exit;
  if FShowHistory and PtInRect(FHistoryR, P) then begin Result.Kind := hkHistory; Exit; end;
  if PtInRect(FIconR, P) then begin Result.Kind := hkIcon; Exit; end;
  if (FFirstVisible > 0) and PtInRect(FEllipsisR, P) then begin Result.Kind := hkEllipsis; Exit; end;
  for I := FFirstVisible to High(FSegs) do
  begin
    if PtInRect(FSegs[I].NameR, P) then begin Result.Kind := hkSeg; Result.Index := I; Exit; end;
    if PtInRect(FSegs[I].ArrowR, P) then begin Result.Kind := hkArrow; Result.Index := I; Exit; end;
  end;
  Result.Kind := hkBox;
end;

function TCAddressBar.SameHit(const A, B: TCABHit): Boolean;
begin
  Result := (A.Kind = B.Kind) and (A.Index = B.Index);
end;

function TCAddressBar.HitRect(const AHit: TCABHit): TRect;
begin
  Result := Rect(0, 0, 0, 0);
  case AHit.Kind of
    hkBack: Result := FBackR;
    hkForward: Result := FForwardR;
    hkUp: Result := FUpR;
    hkRefresh: Result := FRefreshR;
    hkHistory: Result := FHistoryR;
    hkEllipsis: Result := FEllipsisR;
    hkSeg: if (AHit.Index >= 0) and (AHit.Index < Length(FSegs)) then Result := FSegs[AHit.Index].NameR;
    hkArrow: if (AHit.Index >= 0) and (AHit.Index < Length(FSegs)) then Result := FSegs[AHit.Index].ArrowR;
  end;
end;

function TCAddressBar.HintFor(const AHit: TCABHit): string;
begin
  case AHit.Kind of
    hkBack: Result := CXT(sAddrBack);
    hkForward: Result := CXT(sAddrForward);
    hkUp: Result := CXT(sAddrUp);
    hkRefresh: Result := CXT(sAddrRefresh);
    hkHistory: Result := CXT(sAddrRecent);
  else
    Result := '';
  end;
end;

{ ---- 描画 ---- }

procedure TCAddressBar.DrawSymbol(const R: TRect; ACode: Cardinal; AColor: TColor);
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
    // 記号の字がない OS：ふつうの字で代える
    Canvas.Font.Assign(Font);
    Canvas.Font.Color := AColor;
    case ACode of
      SYM_BACK: S := '<';
      SYM_FORWARD: S := '>';
      SYM_UP: S := '^';
      SYM_REFRESH: S := 'R';
      SYM_CHEVRON: S := '>';
      SYM_DOWN: S := 'v';
    else
      S := '';
    end;
  end;
  TS := Canvas.TextStyle;
  TS.Alignment := taCenter;
  TS.Layout := tlCenter;
  TS.SingleLine := True;
  TS.Opaque := False;
  TS.Clipping := True;
  Canvas.TextRect(R, R.Left, R.Top, S, TS);
end;

// 乗せている・押している場所を、少し明るく塗る
procedure TCAddressBar.DrawHot(const R: TRect; const AHit: TCABHit; ABack: TColor);
var
  Pct: Integer;
begin
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;
  Pct := 0;
  if SameHit(FDown, AHit) and SameHit(FHot, AHit) then Pct := 20
  else if SameHit(FHot, AHit) and (FDown.Kind = hkNone) then Pct := 12;
  if Pct = 0 then Exit;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := CXBlendColor(ABack, clWindowText, Pct);
  Canvas.Pen.Style := psClear;
  Canvas.Rectangle(R.Left, R.Top, R.Right + 1, R.Bottom + 1);
  Canvas.Pen.Style := psSolid;
end;

procedure TCAddressBar.Paint;
var
  I: Integer;
  TextC, DisabledC, BackC, BorderC: TColor;
  TS: TTextStyle;
  Hit: TCABHit;
  R: TRect;
  Bmp: TBitmap;
  Designing: Boolean;
begin
  Designing := csDesigning in ComponentState;
  BackC := clBtnFace;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := BackC;
  Canvas.FillRect(0, 0, Width, Height);

  if Designing then
  begin
    // 設計時：見本のパンくず
    FPath := '';
    SetLength(FSegs, 3);
    FSegs[0].Path := ''; FSegs[0].Caption := CXT(sAddrPC);
    FSegs[1].Path := 'C:\'; FSegs[1].Caption := 'C:';
    FSegs[2].Path := 'C:\app'; FSegs[2].Caption := 'app';
    FShownPath := '<design>';
  end
  else if (Length(FSegs) = 0) or (FShownPath <> CurrentFolder) then
    BuildSegs;
  LayoutAll;

  if Enabled then
  begin
    TextC := clWindowText;
    DisabledC := clGrayText;
  end
  else
  begin
    TextC := clGrayText;
    DisabledC := clGrayText;
  end;

  // ナビボタン
  if FShowNav then
  begin
    Hit.Kind := hkBack; Hit.Index := -1;
    if CanBack and Enabled and not Designing then DrawHot(FBackR, Hit, BackC);
    DrawSymbol(FBackR, SYM_BACK, IfThenColor(CanBack and Enabled, TextC, DisabledC));
    Hit.Kind := hkForward;
    if CanForward and Enabled and not Designing then DrawHot(FForwardR, Hit, BackC);
    DrawSymbol(FForwardR, SYM_FORWARD, IfThenColor(CanForward and Enabled, TextC, DisabledC));
    Hit.Kind := hkUp;
    if CanUp and Enabled and not Designing then DrawHot(FUpR, Hit, BackC);
    DrawSymbol(FUpR, SYM_UP, IfThenColor(CanUp and Enabled, TextC, DisabledC));
  end;
  if FShowRefresh then
  begin
    Hit.Kind := hkRefresh; Hit.Index := -1;
    if Enabled and not Designing then DrawHot(FRefreshR, Hit, BackC);
    DrawSymbol(FRefreshR, SYM_REFRESH, TextC);
  end;

  // 入力の枠
  if Editing and Enabled then
    BorderC := CXSplitLineColor(clHighlight)
  else
    BorderC := clBtnShadow;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := BoxColor;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Color := BorderC;
  Canvas.Rectangle(FBoxR.Left, FBoxR.Top, FBoxR.Right, FBoxR.Bottom);

  if not Editing then
  begin
    // アイコン
    if (FIcon <> 0) and not Designing then
    begin
      DrawIconEx(Canvas.Handle, FIconR.Left + (FIconR.Right - FIconR.Left - 16) div 2,
        FIconR.Top + (FIconR.Bottom - FIconR.Top - 16) div 2, FIcon, 16, 16, 0, 0, DI_NORMAL);
    end;
    // パンくず
    Canvas.Font.Assign(Font);
    Canvas.Font.Color := TextC;
    Canvas.Brush.Style := bsClear;
    TS := Canvas.TextStyle;
    TS.Alignment := taCenter;
    TS.Layout := tlCenter;
    TS.SingleLine := True;
    TS.Opaque := False;
    TS.Clipping := True;
    if FFirstVisible > 0 then
    begin
      Hit.Kind := hkEllipsis; Hit.Index := -1;
      if Enabled and not Designing then DrawHot(FEllipsisR, Hit, BoxColor);
      Canvas.Font.Color := TextC;
      Canvas.Brush.Style := bsClear;
      Canvas.TextRect(FEllipsisR, FEllipsisR.Left, FEllipsisR.Top, '...', TS);
    end;
    for I := FFirstVisible to High(FSegs) do
    begin
      Hit.Kind := hkSeg; Hit.Index := I;
      if Enabled and not Designing then DrawHot(FSegs[I].NameR, Hit, BoxColor);
      Canvas.Font.Assign(Font);
      Canvas.Font.Color := TextC;
      Canvas.Brush.Style := bsClear;
      Canvas.TextRect(FSegs[I].NameR, FSegs[I].NameR.Left, FSegs[I].NameR.Top, FSegs[I].Caption, TS);
      Hit.Kind := hkArrow;
      if Enabled and not Designing then DrawHot(FSegs[I].ArrowR, Hit, BoxColor);
      DrawSymbol(FSegs[I].ArrowR, SYM_CHEVRON, DisabledC);
    end;
    // エラー：枠の中の右寄せ
    if FErrorText <> '' then
    begin
      R := FCrumbR;
      Canvas.Font.Assign(Font);
      Canvas.Font.Color := clRed;
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := BoxColor;
      TS.Alignment := taRightJustify;
      TS.Opaque := True;
      Canvas.TextRect(R, R.Left, R.Top, FErrorText, TS);
    end;
  end
  else if FErrorText <> '' then
  begin
    // 入力モード：入力欄の右の空きに、エラーを出す
    // （入力欄は、枠の中いっぱいなので、ここでは出さない）
  end;

  if FShowHistory then
  begin
    Hit.Kind := hkHistory; Hit.Index := -1;
    if Enabled and not Designing then DrawHot(FHistoryR, Hit, BoxColor);
    DrawSymbol(FHistoryR, SYM_DOWN, TextC);
  end;

  // フォーカスの目印（入力モードでないとき）：枠を、強調の色に
  if Focused and (not Editing) and Enabled then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := CXSplitLineColor(clHighlight);
    Canvas.Rectangle(FBoxR.Left, FBoxR.Top, FBoxR.Right, FBoxR.Bottom);
  end;
  Bmp := nil;
  if Bmp <> nil then Bmp.Free;
end;

procedure TCAddressBar.Resize;
begin
  inherited Resize;
  if FEdit <> nil then
  begin
    LayoutAll;
    PlaceEdit;
  end;
  Invalidate;
end;

procedure TCAddressBar.CMEnabledChanged(var Message: TLMessage);
begin
  inherited;
  Invalidate;
end;

procedure TCAddressBar.CMFontChanged(var Message: TLMessage);
begin
  inherited;
  FShownPath := '<font>';   // 文字の幅が変わるので、作り直す
  Invalidate;
end;

procedure TCAddressBar.CMColorChanged(var Message: TLMessage);
begin
  inherited;
  Invalidate;
end;

procedure TCAddressBar.WMGetDlgCode(var Message: TLMessage);
begin
  Message.Result := DLGC_WANTARROWS or DLGC_WANTALLKEYS;
end;

procedure TCAddressBar.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TCAddressBar.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

{ ---- マウス ---- }

procedure TCAddressBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (csDesigning in ComponentState) or not Enabled then Exit;
  if CanFocus and not Focused and not Editing then SetFocus;
  if Button <> mbLeft then Exit;
  FDown := HitAt(X, Y);
  Invalidate;
end;

procedure TCAddressBar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  H: TCABHit;
begin
  inherited MouseMove(Shift, X, Y);
  if (csDesigning in ComponentState) or not Enabled then Exit;
  H := HitAt(X, Y);
  if not SameHit(H, FHot) then
  begin
    FHot := H;
    Hint := HintFor(H);
    Invalidate;
  end;
end;

procedure TCAddressBar.MouseLeave;
begin
  inherited MouseLeave;
  FHot.Kind := hkNone;
  FHot.Index := -1;
  Invalidate;
end;

procedure TCAddressBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  H, D: TCABHit;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (csDesigning in ComponentState) or not Enabled then Exit;
  if Button <> mbLeft then Exit;
  H := HitAt(X, Y);
  D := FDown;
  FDown.Kind := hkNone;
  FDown.Index := -1;
  Invalidate;
  if SameHit(H, D) then DoActivate(H);
end;

procedure TCAddressBar.DoActivate(const AHit: TCABHit);
var
  Anchor: TRect;
  Next: string;
begin
  case AHit.Kind of
    hkBack:
      if CanBack then FListView.GoBack;
    hkForward:
      if CanForward then FListView.GoForward;
    hkUp:
      if CanUp then NavigateTo(ParentFolder);
    hkRefresh:
      Refresh;
    hkSeg:
      if (AHit.Index >= 0) and (AHit.Index < Length(FSegs)) then
      begin
        if FSegs[AHit.Index].Path = '' then
          ShowSubfolderMenu('', '', FSegs[AHit.Index].NameR)    // 「PC」：ドライブの一覧
        else
          NavigateTo(FSegs[AHit.Index].Path);
      end;
    hkArrow:
      if (AHit.Index >= 0) and (AHit.Index < Length(FSegs)) then
      begin
        Anchor := FSegs[AHit.Index].ArrowR;
        if AHit.Index < High(FSegs) then Next := FSegs[AHit.Index + 1].Path else Next := '';
        ShowSubfolderMenu(FSegs[AHit.Index].Path, Next, Anchor);
      end;
    hkEllipsis:
      ShowEllipsisMenu(FEllipsisR);
    hkHistory:
      ShowHistoryMenu(FHistoryR);
    hkIcon, hkBox:
      BeginEdit;
  end;
end;

{ ---- 一覧（ポップアップ）---- }

procedure TCAddressBar.ResetPopup;
begin
  FreeAndNil(FPopup);
  FPopupPaths.Clear;
end;

procedure TCAddressBar.ShowPopupAt(const AAnchor: TRect);
var
  P: TPoint;
begin
  P := ClientToScreen(Point(AAnchor.Left, AAnchor.Bottom));
  FPopup.PopUp(P.X, P.Y);
end;

procedure TCAddressBar.PopupMenuItemClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := TMenuItem(Sender).Tag;
  if (Idx >= 0) and (Idx < FPopupPaths.Count) then NavigateTo(FPopupPaths[Idx]);
end;

procedure TCAddressBar.HistoryItemClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := TMenuItem(Sender).Tag;
  if (FListView <> nil) and (Idx >= 0) and (Idx < FPopupPaths.Count) then
    FListView.GoToHistory(Idx, FPopupPaths[Idx]);
end;

// そのフォルダーの下の、フォルダーの一覧。AFolder = '' は、ドライブの一覧
procedure TCAddressBar.ShowSubfolderMenu(const AFolder, ANextPath: string; const AAnchor: TRect);
var
  Names: TStringList;
  TooMany: Boolean;
  I: Integer;
  Item: TMenuItem;
  Bits: DWORD;
  Root: string;
  Child: string;
begin
  ResetPopup;
  FPopup := TPopupMenu.Create(nil);
  Names := TStringList.Create;
  try
    if AFolder = '' then
    begin
      Bits := GetLogicalDrives;
      for I := 0 to 25 do
        if (Bits and (DWORD(1) shl I)) <> 0 then
        begin
          Root := Chr(Ord('A') + I) + ':\';
          Item := TMenuItem.Create(FPopup);
          Item.Caption := StringReplace(DisplayNameOf(Root), '&', '&&', [rfReplaceAll]);
          Item.Tag := FPopupPaths.Add(Root);
          Item.OnClick := @PopupMenuItemClick;
          if SamePathText(Root, ANextPath) then Item.Default := True;
          FPopup.Items.Add(Item);
        end;
    end
    else
    begin
      ReadSubfolders(AFolder, Names, TooMany);
      for I := 0 to Names.Count - 1 do
      begin
        Child := JoinPathAB(AFolder, Names[I]);
        Item := TMenuItem.Create(FPopup);
        Item.Caption := StringReplace(Names[I], '&', '&&', [rfReplaceAll]);
        Item.Tag := FPopupPaths.Add(Child);
        Item.OnClick := @PopupMenuItemClick;
        if (ANextPath <> '') and SamePathText(Child, ANextPath) then
        begin
          Item.Default := True;      // 次の部分のフォルダー：太字
          Item.Checked := True;
        end;
        FPopup.Items.Add(Item);
      end;
      if TooMany then
      begin
        Item := TMenuItem.Create(FPopup);
        Item.Caption := '...';
        Item.Enabled := False;
        FPopup.Items.Add(Item);
      end;
    end;
  finally
    Names.Free;
  end;
  if FPopup.Items.Count = 0 then
  begin
    ResetPopup;
    Exit;
  end;
  ShowPopupAt(AAnchor);
end;

// 「…」に隠れている、前の部分の一覧
procedure TCAddressBar.ShowEllipsisMenu(const AAnchor: TRect);
var
  I: Integer;
  Item: TMenuItem;
begin
  ResetPopup;
  FPopup := TPopupMenu.Create(nil);
  for I := FFirstVisible - 1 downto 0 do
  begin
    Item := TMenuItem.Create(FPopup);
    Item.Caption := StringReplace(FSegs[I].Caption, '&', '&&', [rfReplaceAll]);
    Item.Tag := FPopupPaths.Add(FSegs[I].Path);
    if FSegs[I].Path = '' then
      Item.Enabled := True;
    Item.OnClick := @PopupMenuItemClick;
    FPopup.Items.Add(Item);
  end;
  if FPopup.Items.Count = 0 then
  begin
    ResetPopup;
    Exit;
  end;
  ShowPopupAt(AAnchor);
end;

procedure TCAddressBar.ShowHistoryMenu(const AAnchor: TRect);
var
  L: TStringList;
  Cur, I: Integer;
  Item: TMenuItem;
begin
  if FListView = nil then Exit;
  ResetPopup;
  L := TStringList.Create;
  try
    Cur := FListView.GetHistory(L);
    if L.Count = 0 then Exit;
    FPopup := TPopupMenu.Create(nil);
    for I := 0 to L.Count - 1 do
    begin
      Item := TMenuItem.Create(FPopup);
      Item.Caption := StringReplace(L[I], '&', '&&', [rfReplaceAll]);
      Item.Tag := FPopupPaths.Add(L[I]);
      Item.OnClick := @HistoryItemClick;
      if I = Cur then
      begin
        Item.Checked := True;
        Item.Default := True;
      end;
      FPopup.Items.Add(Item);
    end;
  finally
    L.Free;
  end;
  ShowPopupAt(AAnchor);
end;

{ ---- 入力モード ---- }

// 入力欄を、パンくずの場所に置く（高さは、入力欄の自然な高さ。上下は中央）
procedure TCAddressBar.PlaceEdit;
var
  H: Integer;
begin
  if FEdit = nil then Exit;
  H := FEdit.Height;
  FEdit.SetBounds(FCrumbR.Left + Scale(4), FCrumbR.Top + (FCrumbR.Bottom - FCrumbR.Top - H) div 2,
    Max(Scale(8), FCrumbR.Right - FCrumbR.Left - Scale(4)), H);
end;

procedure TCAddressBar.BeginEdit;
begin
  if (FEdit <> nil) or (csDesigning in ComponentState) or not Enabled then Exit;
  LayoutAll;
  FErrorText := '';
  FEdit := TEdit.Create(Self);
  FEdit.Parent := Self;
  FEdit.BorderStyle := bsNone;
  FEdit.Color := BoxColor;
  FEdit.Font.Assign(Font);
  FEdit.OnKeyDown := @EditKeyDown;
  FEdit.OnExit := @EditExit;
  PlaceEdit;
  FEdit.Text := CurrentFolder;
  FEdit.SelectAll;
  if FEdit.CanFocus then FEdit.SetFocus;
  Invalidate;
end;

procedure TCAddressBar.EndEdit(ACancel: Boolean);
var
  S, P: string;
  E: TEdit;
begin
  if FEdit = nil then Exit;
  S := FEdit.Text;
  if not ACancel then
  begin
    if CABNormalizeInput(S, P) then
    begin
      if not NavigateTo(P) then
      begin
        // OnNavigating で断られた：入力モードは続ける
        Exit;
      end;
    end
    else
    begin
      FErrorText := Format(CXT(sAddrErrNotFound), [Trim(S)]);
      if Assigned(FOnError) then
      begin
        FOnError(Self, FErrorText);
        FErrorText := '';
      end
      else
        Exit;    // 入力モードは続ける（メッセージは、パンくずに戻ったときに出る）
      Exit;
    end;
  end;
  E := FEdit;
  FEdit := nil;
  E.OnExit := nil;
  E.Free;
  Invalidate;
  if CanFocus and not (csDestroying in ComponentState) then SetFocus;
end;

procedure TCAddressBar.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    EndEdit(False);
  end
  else if Key = VK_ESCAPE then
  begin
    Key := 0;
    EndEdit(True);
  end;
end;

procedure TCAddressBar.EditExit(Sender: TObject);
begin
  // フォーカスを失った：移らずに、入力モードを終える（エラーの文は消す）
  FErrorText := '';
  if FEdit <> nil then EndEdit(True);
end;

{ ---- キー ---- }

procedure TCAddressBar.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Editing then Exit;
  if ((Key = VK_RETURN) or (Key = VK_F4)) and (Shift = []) then
  begin
    BeginEdit;
    Key := 0;
  end
  else if (Key = VK_L) and (Shift = [ssCtrl]) then
  begin
    BeginEdit;
    Key := 0;
  end
  else if (Key = VK_D) and (Shift = [ssAlt]) then
  begin
    BeginEdit;
    Key := 0;
  end
  else if (Key = VK_LEFT) and (Shift = [ssAlt]) then
  begin
    if CanBack then FListView.GoBack;
    Key := 0;
  end
  else if (Key = VK_RIGHT) and (Shift = [ssAlt]) then
  begin
    if CanForward then FListView.GoForward;
    Key := 0;
  end
  else if (Key = VK_UP) and (Shift = [ssAlt]) then
  begin
    if CanUp then NavigateTo(ParentFolder);
    Key := 0;
  end
  else if (Key = VK_F5) and (Shift = []) then
  begin
    Refresh;
    Key := 0;
  end;
end;

// 一覧・ツリーにフォーカスがあるときも、Ctrl+L・Alt+D で入力モードにする
procedure TCAddressBar.AppKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  F: TCustomForm;
  Active: TControl;
begin
  if (csDesigning in ComponentState) or (not Enabled) or (not Visible) then Exit;
  if not (((Key = VK_L) and (Shift = [ssCtrl])) or ((Key = VK_D) and (Shift = [ssAlt]))) then Exit;
  F := GetParentForm(Self);
  if (F = nil) or (Screen.ActiveForm <> F) then Exit;
  Active := F.ActiveControl;
  if Active = nil then Exit;
  if (Active = Self) or (Active = FListView) or (Active = FTreeView) then
  begin
    if Active <> Self then
    begin
      BeginEdit;
      Key := 0;
    end;
  end;
end;

end.
