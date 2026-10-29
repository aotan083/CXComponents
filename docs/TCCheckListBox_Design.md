# TCCheckListBox 設計書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 目的

TCheckListBox に次の2つを足す。

- 単一チェック（`CheckMode = cmSingle`）：チェックは常に 0 か 1 つ。グレーは使わない。
- チェック中の項目を、アプリがループを書かずに取り出すプロパティ（`CheckedIndex`・`CheckedCount`・`HasChecked`・`CheckedText`・`CheckedObject`）と、その変化を知らせるイベント（`OnCheckedIndexChange`）。

`cmMulti`（既定値）のときのチェックの動きは TCheckListBox と同じにする。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `CCheckListBox.pas` | cx（実行時） | `TCCheckMode`・`TCCheckListBox` |
| `uCXReg.pas` | cxdsgn（設計時） | パレット [CX] への登録（`RegisterComponents('CX', [..., TCCheckListBox, ...])`） |
| `cchecklistbox_icon.lrs` | cxdsgn（設計時） | パレットのアイコン（リソース名 `TCCheckListBox`・`TCCheckListBox_150`・`TCCheckListBox_200`。24・36・48px の PNG）。`uCXReg` の initialization で `{$I cchecklistbox_icon.lrs}` |

- uses：`Classes, SysUtils, LMessages, StdCtrls, CheckLst`（LCL だけ）。
- initialization・finalization はない。

## 3. 型

```pascal
TCCheckMode = (cmMulti, cmSingle);

TCCheckListBox = class(TCheckListBox)
```

## 4. フィールド

| 名前 | 型 | 初期値 | 中身 |
|---|---|---|---|
| `FCheckMode` | `TCCheckMode` | `cmMulti` | チェックの方式 |
| `FAllowNoCheck` | `Boolean` | `True` | `cmSingle` で、ユーザーがチェック中の項目を外せるか |
| `FCheckedIndex` | `Integer` | -1 | 最後に分かったチェック中の項目番号。読むときに正しいか確かめてから使う（6.1） |
| `FClickIndex` | `Integer` | -1 | マウスで操作された項目番号。`LM_CHANGED` の WParam から受け取る。Space キーのときは -1 のままで、`ItemIndex` を使う（7.1） |
| `FOnCheckedIndexChange` | `TNotifyEvent` | nil | イベント |

初期値は `Create` で入れる。

## 5. 宣言

### 5.1 published

```pascal
property CheckMode: TCCheckMode read FCheckMode write SetCheckMode default cmMulti;
property AllowNoCheck: Boolean read FAllowNoCheck write FAllowNoCheck default True;
property OnCheckedIndexChange: TNotifyEvent read FOnCheckedIndexChange write FOnCheckedIndexChange;
```

### 5.2 public

```pascal
constructor Create(AOwner: TComponent); override;
procedure CheckAll(AState: TCheckBoxState; aAllowGrayed: Boolean = True; aAllowDisabled: Boolean = True);
procedure Toggle(AIndex: Integer);
property Checked[AIndex: Integer]: Boolean read GetChecked write SetChecked;
property State[AIndex: Integer]: TCheckBoxState read GetState write SetState;
property CheckedIndex: Integer read GetCheckedIndex write SetCheckedIndex;
property CheckedCount: Integer read GetCheckedCount;
property HasChecked: Boolean read GetHasChecked;
property CheckedText: string read GetCheckedText;
property CheckedObject: TObject read GetCheckedObject;
```

- `CheckAll`・`Toggle`・`Checked`・`State` は、親クラスの同じ名前のものを宣言し直して隠す（override ではない。親は virtual ではないため）。そのため、`TCheckListBox` 型の変数から呼ぶと親の処理になる。これは取説 7.1 に書いてある。

### 5.3 protected

```pascal
procedure WndProc(var TheMessage: TLMessage); override;
procedure ClickCheck; override;
procedure Loaded; override;
procedure DoCheckedIndexChange; virtual;
```

### 5.4 private の手続き

| 名前 | 中身 |
|---|---|
| `BaseState(AIndex): TCheckBoxState` | `TCustomCheckListBox(Self).State[AIndex]` を返す。宣言し直した `State` を通らずに親の状態を読む |
| `SetBaseState(AIndex; AValue)` | `TCustomCheckListBox(Self).State[AIndex] := AValue`。親の状態を直接書く。イベントは出ない |
| `IsItemChecked(AIndex): Boolean` | `BaseState(AIndex) <> cbUnchecked`。グレーもチェックありとみなす（親の `Checked` と同じ） |
| `FindFirstChecked: Integer` | 0 番から順に `IsItemChecked` を調べ、最初の番号を返す。なければ -1 |
| `FirstCheckedAssuming(AIndex; AIndexChecked): Integer` | `AIndex` の項目だけを「チェックが `AIndexChecked`」とみなして、`FindFirstChecked` と同じことをする。ユーザー操作の前の `CheckedIndex` を求めるのに使う（7.2） |
| `UncheckOthers(AKeep)` | `AKeep` 以外で `cbUnchecked` でない項目を、`SetBaseState(i, cbUnchecked)` で外す。イベントは出さない |
| `NormalizeSingle` | `keep := FindFirstChecked`。`keep >= 0` なら、その項目が `cbChecked` でなければ `cbChecked` にし、`UncheckOthers(keep)`。最後に `FCheckedIndex := keep`。イベントは出さない |
| `NotifyIfChanged(AOld)` | `GetCheckedIndex <> AOld` なら `DoCheckedIndexChange` |

## 6. 処理

### 6.1 CheckedIndex を読む（GetCheckedIndex）

1. `FCheckMode = cmSingle` で、`0 <= FCheckedIndex < Items.Count` で、`IsItemChecked(FCheckedIndex)` なら、`FCheckedIndex` を返す（ループしない）。
2. それ以外は `FCheckedIndex := FindFirstChecked` として、それを返す。

- 項目の追加・削除・並べ替えで番号がずれても、1 の確認で外れて 2 で探し直すので、正しい値が返る。そのため Items の変化を監視しない。
- `cmMulti` では毎回 2 になる。

### 6.2 CheckedIndex を書く（SetCheckedIndex）

1. `AValue < -1` か `AValue >= Items.Count` なら、何もしないで終わる（例外は出さない）。
2. `old := GetCheckedIndex`。
3. `AValue >= 0` なら `SetBaseState(AValue, cbChecked)`。
4. `UncheckOthers(AValue)`（-1 ならすべて外れる）。
5. `FCheckedIndex := AValue`。
6. `NotifyIfChanged(old)`。

- `cmMulti` でも同じ（指定の項目だけが残る）。
- `AllowNoCheck` は見ない。

### 6.3 そのほかの読み取り

| プロパティ | 処理 |
|---|---|
| `CheckedCount` | `cmSingle`：`Ord(GetHasChecked)`。`cmMulti`：`IsItemChecked` の数を数える |
| `HasChecked` | `GetCheckedIndex >= 0` |
| `CheckedText` | `idx := GetCheckedIndex`。`idx < 0` なら ''、それ以外は `Items[idx]` |
| `CheckedObject` | `idx := GetCheckedIndex`。`idx < 0` なら nil、それ以外は `Items.Objects[idx]` |
| `Checked[i]` 読み | `IsItemChecked(i)` |
| `State[i]` 読み | `BaseState(i)` |

### 6.4 Checked・State を書く

`SetChecked(i, v)` は、`v` が `True` なら `SetState(i, cbChecked)`、`False` なら `SetState(i, cbUnchecked)`。

`SetState(i, v)`：

1. `old := GetCheckedIndex`。
2. `cmMulti`：`SetBaseState(i, v)`。
3. `cmSingle` で `v = cbChecked`：先に `SetBaseState(i, cbChecked)`（番号が範囲外ならここで親が例外を出す）、次に `UncheckOthers(i)`、`FCheckedIndex := i`。
4. `cmSingle` で `v` が `cbUnchecked`・`cbGrayed`：`SetBaseState(i, cbUnchecked)`。`AllowNoCheck` は見ない。
5. `NotifyIfChanged(old)`。

### 6.5 CheckAll

1. `old := GetCheckedIndex`。
2. `cmMulti`：`inherited CheckAll(AState, aAllowGrayed, aAllowDisabled)`。
3. `cmSingle` で `AState = cbChecked`：0 番から順に、`(aAllowGrayed or (BaseState(i) <> cbGrayed)) and (aAllowDisabled or ItemEnabled[i])` を満たす最初の項目を `keep` とする。`keep >= 0` なら `SetBaseState(keep, cbChecked)`・`UncheckOthers(keep)`・`FCheckedIndex := keep`。対象がなければ何も変えない。
4. `cmSingle` で `AState` が `cbUnchecked`・`cbGrayed`：`inherited CheckAll(cbUnchecked, aAllowGrayed, aAllowDisabled)`。
5. `NotifyIfChanged(old)`。

対象の条件（3 の式）は、親の `CheckAll` と同じにする。

### 6.6 Toggle

- `cmMulti`：`old := GetCheckedIndex`、`inherited Toggle(AIndex)`、`NotifyIfChanged(old)`。
- `cmSingle`：`SetChecked(AIndex, not IsItemChecked(AIndex))`（グレーは使わない。イベントは `SetState` が出す）。

### 6.7 CheckMode を書く（SetCheckMode）

1. 同じ値なら終わる。
2. `FCheckMode := AValue`。
3. `csLoading` 中なら終わる（整えるのは `Loaded`）。
4. `AValue = cmSingle` なら `NormalizeSingle`。番号が最小の項目が残るので `CheckedIndex` は変わらず、イベントは出さない。
5. `cmMulti` にしたときは、チェックを変えない。

### 6.8 Loaded

`inherited Loaded` のあと、`FCheckMode = cmSingle` なら `NormalizeSingle`。.lfm に複数のチェックが保存されていても、番号が最小の項目だけが残る。

### 6.9 DoCheckedIndexChange

`csLoading` 中なら何もしない。それ以外は `FOnCheckedIndexChange` があれば呼ぶ。

## 7. ユーザー操作

### 7.1 どの項目が操作されたか（WndProc）

親（TCustomCheckListBox）は、マウスでチェック欄がクリックされると、Windows の部品から `LM_CHANGED`（WParam = 項目番号）を受け取り、`Toggle` で状態を切り替えてから `ClickCheck` を呼ぶ。Space キーのときは `LM_CHANGED` を通らず、`ItemIndex` の項目について同じことをする。

```pascal
procedure TCCheckListBox.WndProc(var TheMessage: TLMessage);
begin
  if TheMessage.Msg <> LM_CHANGED then
  begin
    inherited WndProc(TheMessage);
    Exit;
  end;
  FClickIndex := TheMessage.WParam;
  try
    inherited WndProc(TheMessage);   // 親の処理 → ClickCheck が呼ばれる
  finally
    FClickIndex := -1;
  end;
end;
```

### 7.2 ClickCheck

`ClickCheck` が呼ばれた時点で、親は `Toggle` で状態を切り替え済み。親の `Toggle` の切り替えは次のとおり。

| `AllowGrayed` | 切り替え |
|---|---|
| `False` | なし → あり → なし |
| `True` | なし → グレー → あり → なし |

手順：

1. `idx := FClickIndex`。-1 なら `idx := ItemIndex`。
2. `idx` が範囲外なら `inherited ClickCheck` だけして終わる。
3. `st := BaseState(idx)`（切り替え後の状態）。
4. `cmMulti` のとき：チェックは変えない。切り替え前にこの項目がチェックありだったか（`beforeChecked`）を、次の表で逆算する。

   | 切り替え後 `st` | 切り替え前 | `beforeChecked` |
   |---|---|---|
   | `cbUnchecked` | あり（またはグレー） | `True` |
   | `cbGrayed` | なし | `False` |
   | `cbChecked` | `AllowGrayed = True` ならグレー、`False` ならなし | `AllowGrayed` |

   `oldIdx := FirstCheckedAssuming(idx, beforeChecked)`、`inherited ClickCheck`（`OnClickCheck`）、`NotifyIfChanged(oldIdx)`。
5. `cmSingle` で `st = cbUnchecked`（チェック中の項目を外す操作）：
   - `FAllowNoCheck = False` なら、`SetBaseState(idx, cbChecked)`・`FCheckedIndex := idx` として終わる。`OnClickCheck` も `OnCheckedIndexChange` も出さない。
   - `True` なら、`FCheckedIndex := -1`、`inherited ClickCheck`、`NotifyIfChanged(idx)`（操作の前は `idx` がチェック中だった）。
6. `cmSingle` で `st` が `cbGrayed`・`cbChecked`（チェックなしの項目をチェックする操作）：
   - `st = cbGrayed` なら `SetBaseState(idx, cbChecked)`（グレーを飛ばす）。
   - `oldIdx := FirstCheckedAssuming(idx, False)`（この項目以外で、チェックありの最小番号）。
   - `UncheckOthers(idx)`、`FCheckedIndex := idx`、`inherited ClickCheck`、`NotifyIfChanged(oldIdx)`。

- 自動で外した項目について `OnClickCheck` は出さない（`UncheckOthers` は親の状態を直接書くため）。
- `OnItemClick` は親が出すもので、この部品では止めない。そのため 5 の「外れなかった」ときも出る。

## 8. イベントの出る順番

| 操作 | 順番 |
|---|---|
| ユーザーのクリック・Space キー | `OnClickCheck` → `OnCheckedIndexChange`（7.2 の `inherited ClickCheck` → `NotifyIfChanged`） |
| コードで `Checked[]`・`State[]`・`CheckedIndex`・`CheckAll`・`Toggle` | `OnCheckedIndexChange` だけ |

`OnCheckedIndexChange` は、すべて `NotifyIfChanged` から出す。値が変わらないときは出さない。

## 9. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| `cmSingle` なのにチェックが2つ以上ある | 呼び出し側の変数の型が `TCheckListBox`・`TCustomCheckListBox` になっていないか（5.2）。`Loaded`・`SetCheckMode` の `NormalizeSingle` |
| `CheckedIndex` が古い値を返す | `GetCheckedIndex` の 1 の確認（6.1） |
| マウスで違う項目が処理される | `WndProc` の `FClickIndex`（7.1） |
| `OnCheckedIndexChange` が出ない・2回出る | `NotifyIfChanged` に渡す `old` の求め方（6.2〜6.6、7.2）。`csLoading` 中か（6.9） |
| `cmMulti` のクリックでイベントがずれる | 7.2 の 4 の逆算表と、親の `Toggle` の切り替え順 |
