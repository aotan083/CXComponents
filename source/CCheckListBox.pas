{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ ============================================================================
  CCheckListBox.pas
  TCCheckListBox : TCheckListBox に「単一チェック」と、チェック中の項目を
                   ループせずに取得するプロパティを加えた部品

  設計書：docs\TCCheckListBox_Design.md
  実行時パッケージ：cx
  （パレットへの登録とアイコンは設計時パッケージ cxdsgn で行う）
  ============================================================================ }
unit CCheckListBox;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LMessages, StdCtrls, CheckLst;

type
  { チェックの方式
      cmMulti  : 複数チェックできる（TCheckListBox と同じ）
      cmSingle : チェックできるのは1つだけ }
  TCCheckMode = (cmMulti, cmSingle);

  { TCCheckListBox }

  TCCheckListBox = class(TCheckListBox)
  private
    FCheckMode: TCCheckMode;
    FAllowNoCheck: Boolean;
    // 最後に分かったチェック中の項目番号。読むときに正しいか確かめてから使う
    FCheckedIndex: Integer;
    // マウスで操作された項目番号。LM_CHANGED の WParam から受け取る。
    // スペースキーのときは -1 のままで、ItemIndex を使う
    FClickIndex: Integer;
    FOnCheckedIndexChange: TNotifyEvent;

    // 親クラス（TCustomCheckListBox）の State を直接読み書きする。
    // このクラスで State を宣言し直しているため、型変換で親のものを呼ぶ
    function BaseState(AIndex: Integer): TCheckBoxState;
    procedure SetBaseState(AIndex: Integer; AValue: TCheckBoxState);
    function IsItemChecked(AIndex: Integer): Boolean;

    // AIndex の項目だけ「チェックされているか」を AIndexChecked に置き換えて、
    // 番号が最小のチェック項目を探す。ないときは -1。
    // ユーザー操作の前の CheckedIndex を求めるのに使う
    function FirstCheckedAssuming(AIndex: Integer; AIndexChecked: Boolean): Integer;
    // 先頭から探して、番号が最小のチェック項目を返す。ないときは -1
    function FindFirstChecked: Integer;
    // AKeep 以外の項目のチェックをすべて外す（イベントは出さない）
    procedure UncheckOthers(AKeep: Integer);
    // シングルの約束（チェックは1つまで・グレーなし）に整える。
    // 番号が最小のチェック項目だけを残す。イベントは出さない
    procedure NormalizeSingle;
    // 操作の前の CheckedIndex（AOld）と今の値を比べ、違えばイベントを出す
    procedure NotifyIfChanged(AOld: Integer);

    procedure SetCheckMode(AValue: TCCheckMode);
    function GetCheckedIndex: Integer;
    procedure SetCheckedIndex(AValue: Integer);
    function GetCheckedCount: Integer;
    function GetHasChecked: Boolean;
    function GetCheckedText: string;
    function GetCheckedObject: TObject;
    function GetChecked(const AIndex: Integer): Boolean;
    procedure SetChecked(const AIndex: Integer; const AValue: Boolean);
    function GetState(AIndex: Integer): TCheckBoxState;
    procedure SetState(AIndex: Integer; AValue: TCheckBoxState);

  protected
    // マウスでチェック欄がクリックされたときに、Windows の部品から届く通知
    // （LM_CHANGED）を受け取る。項目番号を控えてから、親クラスの処理
    // （ClickCheck を呼ぶ）へ渡す
    procedure WndProc(var TheMessage: TLMessage); override;
    procedure ClickCheck; override;
    procedure Loaded; override;
    procedure DoCheckedIndexChange; virtual;
  public
    constructor Create(AOwner: TComponent); override;

    // 親クラスの同名メソッドを宣言し直し、シングルの約束を守る
    procedure CheckAll(AState: TCheckBoxState; aAllowGrayed: Boolean = True;
      aAllowDisabled: Boolean = True);
    procedure Toggle(AIndex: Integer);

    // 親クラスの同名プロパティを宣言し直し、シングルの約束を守る
    property Checked[AIndex: Integer]: Boolean read GetChecked write SetChecked;
    property State[AIndex: Integer]: TCheckBoxState read GetState write SetState;

    // チェック中の項目を、ループせずに取得する
    property CheckedIndex: Integer read GetCheckedIndex write SetCheckedIndex;
    property CheckedCount: Integer read GetCheckedCount;
    property HasChecked: Boolean read GetHasChecked;
    property CheckedText: string read GetCheckedText;
    property CheckedObject: TObject read GetCheckedObject;
  published
    property CheckMode: TCCheckMode read FCheckMode write SetCheckMode default cmMulti;
    property AllowNoCheck: Boolean read FAllowNoCheck write FAllowNoCheck default True;
    property OnCheckedIndexChange: TNotifyEvent read FOnCheckedIndexChange
      write FOnCheckedIndexChange;
  end;

implementation

{ TCCheckListBox }

constructor TCCheckListBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCheckMode := cmMulti;
  FAllowNoCheck := True;
  FCheckedIndex := -1;
  FClickIndex := -1;
end;

{ ---- 親クラスの State を直接使う小さな手続き ---- }

function TCCheckListBox.BaseState(AIndex: Integer): TCheckBoxState;
begin
  Result := TCustomCheckListBox(Self).State[AIndex];
end;

procedure TCCheckListBox.SetBaseState(AIndex: Integer; AValue: TCheckBoxState);
begin
  TCustomCheckListBox(Self).State[AIndex] := AValue;
end;

function TCCheckListBox.IsItemChecked(AIndex: Integer): Boolean;
begin
  // 親クラスの Checked と同じく、グレーも「チェックあり」とみなす
  Result := BaseState(AIndex) <> cbUnchecked;
end;

{ ---- 探す・整える ---- }

function TCCheckListBox.FindFirstChecked: Integer;
var
  i: Integer;
begin
  for i := 0 to Items.Count - 1 do
    if IsItemChecked(i) then
      Exit(i);
  Result := -1;
end;

function TCCheckListBox.FirstCheckedAssuming(AIndex: Integer;
  AIndexChecked: Boolean): Integer;
var
  i: Integer;
  c: Boolean;
begin
  for i := 0 to Items.Count - 1 do
  begin
    if i = AIndex then
      c := AIndexChecked
    else
      c := IsItemChecked(i);
    if c then
      Exit(i);
  end;
  Result := -1;
end;

procedure TCCheckListBox.UncheckOthers(AKeep: Integer);
var
  i: Integer;
begin
  // 親クラスの State を直接書くので、OnClickCheck も OnCheckedIndexChange も出ない
  for i := 0 to Items.Count - 1 do
    if (i <> AKeep) and (BaseState(i) <> cbUnchecked) then
      SetBaseState(i, cbUnchecked);
end;

procedure TCCheckListBox.NormalizeSingle;
var
  keep: Integer;
begin
  keep := FindFirstChecked;
  if keep >= 0 then
  begin
    // 残す項目がグレーなら、チェックありにする（シングルではグレーを使わない）
    if BaseState(keep) <> cbChecked then
      SetBaseState(keep, cbChecked);
    UncheckOthers(keep);
  end;
  FCheckedIndex := keep;
end;

procedure TCCheckListBox.NotifyIfChanged(AOld: Integer);
begin
  if GetCheckedIndex <> AOld then
    DoCheckedIndexChange;
end;

procedure TCCheckListBox.DoCheckedIndexChange;
begin
  // .lfm 読み込み中はイベントを出さない
  if csLoading in ComponentState then
    Exit;
  if Assigned(FOnCheckedIndexChange) then
    FOnCheckedIndexChange(Self);
end;

{ ---- CheckMode ---- }

procedure TCCheckListBox.SetCheckMode(AValue: TCCheckMode);
begin
  if FCheckMode = AValue then
    Exit;
  FCheckMode := AValue;
  // 読み込み中は値を覚えるだけ。整えるのは Loaded で行う
  if csLoading in ComponentState then
    Exit;
  // マルチ → シングル：番号が最小のチェック項目だけを残す。
  // 残るのは最小の項目なので CheckedIndex は変わらず、イベントは出ない
  if AValue = cmSingle then
    NormalizeSingle;
  // シングル → マルチ：チェック状態は変えない
end;

procedure TCCheckListBox.Loaded;
begin
  inherited Loaded;
  // .lfm で複数チェックが保存されていても、シングルなら最小の項目だけを残す
  if FCheckMode = cmSingle then
    NormalizeSingle;
end;

{ ---- CheckedIndex と、そこから求めるプロパティ ---- }

function TCCheckListBox.GetCheckedIndex: Integer;
begin
  // シングル：覚えている番号の項目が今もチェック中なら、それが答え。
  // シングルではチェック中は1つだけなので、ループせずに返せる。
  // 項目の追加・削除・並べ替えで番号がずれていたら、探し直して覚え直す
  if (FCheckMode = cmSingle) and (FCheckedIndex >= 0)
    and (FCheckedIndex < Items.Count) and IsItemChecked(FCheckedIndex) then
    Exit(FCheckedIndex);
  // マルチ、または覚えている番号が使えないとき：先頭から探す
  // （最初のチェック項目で止まる）
  FCheckedIndex := FindFirstChecked;
  Result := FCheckedIndex;
end;

procedure TCCheckListBox.SetCheckedIndex(AValue: Integer);
var
  old: Integer;
begin
  // 範囲外は何もしない（例外は出さない）
  if (AValue < -1) or (AValue >= Items.Count) then
    Exit;
  old := GetCheckedIndex;
  // 指定の項目だけをチェックし、他はすべて外す（マルチ時も同じ）。
  // -1 ならすべて外す（AllowNoCheck の制限はユーザー操作だけ）
  if AValue >= 0 then
    SetBaseState(AValue, cbChecked);
  UncheckOthers(AValue);
  FCheckedIndex := AValue;
  NotifyIfChanged(old);
end;

function TCCheckListBox.GetCheckedCount: Integer;
var
  i: Integer;
begin
  // シングル：0 か 1。ループしない
  if FCheckMode = cmSingle then
    Exit(Ord(GetHasChecked));
  // マルチ：全項目を数える
  Result := 0;
  for i := 0 to Items.Count - 1 do
    if IsItemChecked(i) then
      Inc(Result);
end;

function TCCheckListBox.GetHasChecked: Boolean;
begin
  Result := GetCheckedIndex >= 0;
end;

function TCCheckListBox.GetCheckedText: string;
var
  idx: Integer;
begin
  idx := GetCheckedIndex;
  if idx < 0 then
    Result := ''
  else
    Result := Items[idx];
end;

function TCCheckListBox.GetCheckedObject: TObject;
var
  idx: Integer;
begin
  idx := GetCheckedIndex;
  if idx < 0 then
    Result := nil
  else
    Result := Items.Objects[idx];
end;

{ ---- 宣言し直した Checked / State ---- }

function TCCheckListBox.GetChecked(const AIndex: Integer): Boolean;
begin
  Result := IsItemChecked(AIndex);
end;

procedure TCCheckListBox.SetChecked(const AIndex: Integer; const AValue: Boolean);
begin
  if AValue then
    SetState(AIndex, cbChecked)
  else
    SetState(AIndex, cbUnchecked);
end;

function TCCheckListBox.GetState(AIndex: Integer): TCheckBoxState;
begin
  Result := BaseState(AIndex);
end;

procedure TCCheckListBox.SetState(AIndex: Integer; AValue: TCheckBoxState);
var
  old: Integer;
begin
  old := GetCheckedIndex;
  if FCheckMode = cmMulti then
    // マルチ：TCheckListBox と同じ
    SetBaseState(AIndex, AValue)
  else if AValue = cbChecked then
  begin
    // シングルでチェック：先にこの項目をチェックし（番号が範囲外ならここで例外）、
    // その後で他を外す
    SetBaseState(AIndex, cbChecked);
    UncheckOthers(AIndex);
    FCheckedIndex := AIndex;
  end
  else
    // シングルで外す・グレー：どちらもチェックなしにする。
    // AllowNoCheck に関係なく外す
    SetBaseState(AIndex, cbUnchecked);
  NotifyIfChanged(old);
end;

{ ---- 宣言し直した CheckAll / Toggle ---- }

procedure TCCheckListBox.CheckAll(AState: TCheckBoxState; aAllowGrayed: Boolean;
  aAllowDisabled: Boolean);
var
  old, i, keep: Integer;
begin
  old := GetCheckedIndex;
  if FCheckMode = cmMulti then
    // マルチ：TCheckListBox と同じ
    inherited CheckAll(AState, aAllowGrayed, aAllowDisabled)
  else if AState = cbChecked then
  begin
    // シングルでチェック：対象になる最初の項目だけをチェックし、他は外す。
    // 対象の条件（グレー・無効項目を含めるか）は TCheckListBox と同じ
    keep := -1;
    for i := 0 to Items.Count - 1 do
      if (aAllowGrayed or (BaseState(i) <> cbGrayed))
        and (aAllowDisabled or ItemEnabled[i]) then
      begin
        keep := i;
        Break;
      end;
    if keep >= 0 then
    begin
      SetBaseState(keep, cbChecked);
      UncheckOthers(keep);
      FCheckedIndex := keep;
    end;
  end
  else
    // シングルで外す・グレー：対象の項目をチェックなしにする
    inherited CheckAll(cbUnchecked, aAllowGrayed, aAllowDisabled);
  NotifyIfChanged(old);
end;

procedure TCCheckListBox.Toggle(AIndex: Integer);
var
  old: Integer;
begin
  if FCheckMode = cmMulti then
  begin
    // マルチ：TCheckListBox と同じ
    old := GetCheckedIndex;
    inherited Toggle(AIndex);
    NotifyIfChanged(old);
  end
  else
    // シングル：なし ⇔ あり で切り替える（グレーは使わない）
    SetChecked(AIndex, not IsItemChecked(AIndex));
end;

{ ---- ユーザー操作（マウス・スペースキー） ---- }

procedure TCCheckListBox.WndProc(var TheMessage: TLMessage);
begin
  if TheMessage.Msg <> LM_CHANGED then
  begin
    inherited WndProc(TheMessage);
    Exit;
  end;
  // LM_CHANGED の WParam は、クリックされた項目番号
  FClickIndex := TheMessage.WParam;
  try
    inherited WndProc(TheMessage);   // 親クラスの処理 → ClickCheck が呼ばれる
  finally
    FClickIndex := -1;
  end;
end;

procedure TCCheckListBox.ClickCheck;
var
  idx, oldIdx: Integer;
  st: TCheckBoxState;
  beforeChecked: Boolean;
begin
  { ユーザーがチェック欄をクリック、またはスペースキーを押したときに呼ばれる。
    親クラスは、ここを呼ぶ前に Toggle で状態を切り替え済み。
    Toggle の切替：AllowGrayed=False … なし→あり→なし
                    AllowGrayed=True  … なし→グレー→あり→なし }

  // 操作された項目：マウスなら LM_CHANGED で控えた番号、スペースキーなら ItemIndex
  idx := FClickIndex;
  if idx < 0 then
    idx := ItemIndex;
  if (idx < 0) or (idx >= Items.Count) then
  begin
    inherited ClickCheck;
    Exit;
  end;
  st := BaseState(idx);

  if FCheckMode = cmMulti then
  begin
    // マルチ：チェックは変えない。CheckedIndex が変わったときだけイベントを出す。
    // 操作の前にこの項目がチェックありだったかを、Toggle の切替から逆算する
    case st of
      cbUnchecked: beforeChecked := True;          // あり（またはグレー）→ なし
      cbGrayed:    beforeChecked := False;         // なし → グレー
    else
      beforeChecked := AllowGrayed;                // グレー → あり／なし → あり
    end;
    oldIdx := FirstCheckedAssuming(idx, beforeChecked);
    inherited ClickCheck;                          // OnClickCheck
    NotifyIfChanged(oldIdx);                       // OnCheckedIndexChange
    Exit;
  end;

  // ---- シングル ----
  if st = cbUnchecked then
  begin
    // チェック中の項目を外す操作
    if not FAllowNoCheck then
    begin
      // 外すことを許さない：元に戻し、イベントは出さない
      SetBaseState(idx, cbChecked);
      FCheckedIndex := idx;
      Exit;
    end;
    FCheckedIndex := -1;
    inherited ClickCheck;                          // OnClickCheck
    NotifyIfChanged(idx);                          // 操作前は idx がチェック中
  end
  else
  begin
    // チェックなしの項目をチェックする操作。
    // グレーになっていたら、グレーを飛ばしてチェックありにする
    if st = cbGrayed then
      SetBaseState(idx, cbChecked);
    // 操作の前のチェック項目（この項目以外で、チェックありのもの）
    oldIdx := FirstCheckedAssuming(idx, False);
    UncheckOthers(idx);                            // 他を外す（イベントなし）
    FCheckedIndex := idx;
    inherited ClickCheck;                          // OnClickCheck（この項目の分だけ）
    NotifyIfChanged(oldIdx);                       // OnCheckedIndexChange
  end;
end;

end.
