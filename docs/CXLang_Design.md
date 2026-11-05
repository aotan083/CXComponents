# CXLang（日英対応）設計書

作者: aotan083
日付: 2026-11-04
版: 1.0

---

## 1. 目的と方針

cx の部品が画面に出す文字列（メニュー・ボタン・メッセージ）を、日本語と英語で切り替えられるようにする。

| No | 方針 |
|---|---|
| 1 | 言語は cx 全体で 1 つ。部品ごとの設定は作らない |
| 2 | 言語の値は日本語（`ja`）と英語（`en`）の 2 つ |
| 3 | 言語は実行時に決める（コンパイル時には決めない） |
| 4 | 文字列は新しいユニット `uCXLang.pas` の表 1 つにまとめる。各部品は `CXT(ID)` で取る |
| 5 | 日本語の文字列は、今の文字列を一字一句変えない（日本語での表示は今と同じ） |
| 6 | 対象は画面に出る文字列だけ（8章に対象外を書く） |
| 7 | 動作・テスト済みの部品の I/F（プロパティ・メソッド・イベント）は変えない。文字列の取り方だけを変える |

## 2. 言語の決め方

### 2.1 順番

1. EXE と同じ場所の `WebView2.ini` の `[CX]` セクションにある `Language` が `ja` または `en` なら、その言語（大文字小文字は区別しない・前後の空白は除く）
2. それ以外（ini が無い・`[CX]` が無い・`Language` が無い・空・`ja` `en` 以外の値）は、Windows の表示言語に合わせる。日本語なら `ja`、それ以外は `en`

```ini
[CX]
Language=en
```

- ini の `[WebView2]` セクション（`uCXRuntime` が読む）とは別のセクション。`uCXRuntime` の読み方は変えない。
- 言語は、最初に文字列が必要になったときに 1 回だけ決める。実行中に ini を書き換えても、次の起動まで効かない（`uCXRuntime` の ini と同じ）。
- ini を読めなくても例外は出さず、2 に進む。
- Windows の表示言語は、`kernel32` の `GetUserDefaultUILanguage` の下位 10 ビットが `$11`（LANG_JAPANESE）かどうかで判定する。

### 2.2 ini が無いときの動き

- `uCXRuntime` は、ini が無いと WebView2 を起動しない（今のまま変えない）。そのときのエラーの文（`sErrIniMissing`）も、2 の言語で出る。

## 3. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCXLang.pas`（新しく作る） | cx（実行時） | 言語の決定・文字列の表・`CXT` |
| 各ユニット | cx（実行時） | 6章のとおり文字列の取り方を変える |
| `preview.html` | 実行時のファイル | 7章 |
| `editor.html` | 実行時のファイル | 変更なし |

- `uCXLang` の uses：`SysUtils, IniFiles`。`uCXRuntime` や WebView4Delphi は使わない（WebView2 を使わない部品 `TCListView` などが、WebView4Delphi を巻き込まないため）。
- `uCXLang` は `initialization`・`finalization` を持たない（`uCXRuntime` と同じ。uses に入れただけで何も動かさない）。
- cxdsgn（設計時）は変えない。IDE 用の登録ユニットの文字列は対象外（8章）。

## 4. uCXLang の作り

```pascal
type
  TCXLanguage = (cxlJa, cxlEn);
  TCXStr = (sUntitled, sUntitledTxt, ... );   // 5章の ID を、No の順にすべて並べる

function CXLanguage: TCXLanguage;   // 今の言語（最初に呼ばれたとき 2.1 の順で決め、あとは同じ値）
function CXLangCode: string;        // 'ja' または 'en'（HTML 側へ渡す値）
function CXT(AId: TCXStr): string;  // CXLanguage に合う文字列
```

- 文字列は、`TCXStr` を添字にした定数の配列（日本語と English の組）に持つ。並びは `TCXStr` と 5章の No で同じ。
- `CXT` は、`cxlJa` なら日本語、`cxlEn` なら English を返す。
- `Format` を使う文字列（`%s` `%d` を含む）は、日本語と English で並びと種類を同じにしてある。呼ぶ側は `Format(CXT(ID), [...])`。
- 改行を含む文字列は持たない。改行が要る所は、呼ぶ側が `LineEnding` でつなぐ（`sUnsavedLine1` と `sUnsavedLine2`）。
- 「: 」で終わる文字列（`sErr…`）は、後ろに空白を 1 つ含む。呼ぶ側は後ろにファイル名などをつなぐ。
- 言語を後から変える手続きは作らない。
- Windows 以外でコンパイルしたとき（確認用のテスト）は、Windows の表示言語の判定を行わず、`en` として扱う（`{$IFDEF MSWINDOWS}`）。

## 5. 文字列の表（198 項目）

- 「日本語」は今のソースの文字列そのまま。「English」が新しく付ける文字列。
- メニュー・ボタンの `&` は、同じメニュー（同じダイアログ）の中で重ならないようにしてある。
- `sErrCp932`・`sErrPreviewBinder` などの例外の文も、画面に出るので対象に入れる。
- 行番号は、この設計書を書いた時点のソースの行。

**A. 無題の名前**

| No | ID | 日本語 | English | 今ある場所（ファイル:行） |
|---|---|---|---|---|
| 1 | `sUntitled` | 無題 | Untitled | uCmmonacoview:1177, uCsEditor:1287 |
| 2 | `sUntitledTxt` | 無題.txt | Untitled.txt | cSynedit:660・718 |

**B. 標準アクション（Caption と Hint）**

| No | ID | 日本語 | English | 今ある場所（ファイル:行） |
|---|---|---|---|---|
| 3 | `sActNewCap` | 新規(&N) | &New | CMonacoActions:321, uCsEditor:5734 |
| 4 | `sActNewHint` | 新しい文書 | New document | CMonacoActions:322, uCsEditor:5735 |
| 5 | `sActOpenCap` | 開く(&O)... | &Open... | CMonacoActions:334, uCsEditor:5747 |
| 6 | `sActOpenHint` | ファイルを開く | Open a file | CMonacoActions:335, uCsEditor:5748 |
| 7 | `sActSaveCap` | 上書き保存(&S) | &Save | CMonacoActions:372, uCsEditor:5760 |
| 8 | `sActSaveHint` | 上書き保存 | Save | CMonacoActions:373, uCsEditor:5761 |
| 9 | `sActSaveAsCap` | 名前を付けて保存(&A)... | Save &As... | CMonacoActions:385, uCsEditor:5773 |
| 10 | `sActSaveAsHint` | 名前を付けて保存 | Save as | CMonacoActions:386, uCsEditor:5774 |
| 11 | `sActCloseCap` | 閉じる(&C) | &Close | CMonacoActions:397, uCsEditor:5785 |
| 12 | `sActCloseHint` | 文書を閉じる | Close the document | CMonacoActions:398, uCsEditor:5786 |
| 13 | `sActPrintCap` | 印刷(&P)... | &Print... | CMonacoActions:411, uCsEditor:5798 |
| 14 | `sActPrintHint` | プレビューを印刷（PDF として保存もできる） | Print the preview (can also be saved as PDF) | CMonacoActions:412, uCsEditor:5799 |
| 15 | `sActSaveAllCap` | すべて保存(&L) | Save A&ll | CMonacoActions:432, uCsEditor:5816 |
| 16 | `sActSaveAllHint` | 変更のあるタブをすべて保存 | Save all modified tabs | CMonacoActions:433, uCsEditor:5817 |
| 17 | `sActCloseAllCap` | すべて閉じる(&E) | Clos&e All | CMonacoActions:457, uCsEditor:5839 |
| 18 | `sActCloseAllHint` | すべての文書を閉じる | Close all documents | CMonacoActions:458, uCsEditor:5840 |
| 19 | `sActUndoCap` | 元に戻す(&U) | &Undo | CMonacoActions:470, uCsEditor:5851 |
| 20 | `sActUndoHint` | 元に戻す | Undo | CMonacoActions:471, uCsEditor:4427・5852 |
| 21 | `sActRedoCap` | やり直し(&R) | &Redo | CMonacoActions:489, uCsEditor:5869 |
| 22 | `sActRedoHint` | やり直し | Redo | CMonacoActions:490, uCsEditor:4428・5870 |
| 23 | `sActCutCap` | 切り取り(&T) | Cu&t | CMonacoActions:508, uCsEditor:5887 |
| 24 | `sActCutHint` | 切り取り | Cut | CMonacoActions:509, uCsEditor:5888 |
| 25 | `sActCopyCap` | コピー(&C) | &Copy | CMonacoActions:527, uCsEditor:5905 |
| 26 | `sActCopyHint` | コピー | Copy | CMonacoActions:528, uCsEditor:4422・5906 |
| 27 | `sActPasteCap` | 貼り付け(&P) | &Paste | CMonacoActions:546, uCsEditor:5923 |
| 28 | `sActPasteHint` | 貼り付け | Paste | CMonacoActions:547, uCsEditor:4423・5924 |
| 29 | `sActSelectAllCap` | すべて選択(&A) | Select &All | CMonacoActions:567, uCsEditor:5942 |
| 30 | `sActSelectAllHint` | すべて選択 | Select all | CMonacoActions:568, uCsEditor:4426・5943 |
| 31 | `sActDupLineCap` | 行の複製(&D) | &Duplicate Line | CMonacoActions:581, uCsEditor:5955 |
| 32 | `sActDupLineHint` | カーソル行を複製して下へ | Duplicate the cursor line below | CMonacoActions:582, uCsEditor:5956 |
| 33 | `sActDelToEndCap` | 末尾まで削除 | Delete to End | CMonacoActions:600, uCsEditor:5973 |
| 34 | `sActDelToEndHint` | カーソル位置から文書の末尾まで削除 | Delete from the cursor to the end of the document | CMonacoActions:601, uCsEditor:5974 |
| 35 | `sActDelToStartCap` | 先頭まで削除 | Delete to Start | CMonacoActions:618, uCsEditor:5990 |
| 36 | `sActDelToStartHint` | カーソル位置から文書の先頭まで削除 | Delete from the cursor to the start of the document | CMonacoActions:619, uCsEditor:5991 |
| 37 | `sActFindCap` | 検索・置換(&F)... | &Find/Replace... | CMonacoActions:636, uCsEditor:6007 |
| 38 | `sActFindHint` | 検索・置換ダイアログを開く | Open the find/replace dialog | CMonacoActions:637, uCsEditor:6008 |
| 39 | `sActFindNextCap` | 次を検索(&N) | Find &Next | CMonacoActions:650, uCsEditor:1639・6020 |
| 40 | `sActFindNextHint` | 直前の検索語で次を検索 | Find the next match of the last search | CMonacoActions:651, uCsEditor:6021 |
| 41 | `sActFindPrevCap` | 前を検索(&V) | Find Pre&vious | CMonacoActions:664, uCsEditor:6033 |
| 42 | `sActFindPrevHint` | 直前の検索語で前を検索 | Find the previous match of the last search | CMonacoActions:665, uCsEditor:6034 |
| 43 | `sActMinimapCap` | ミニマップ(&M) | &Minimap | CMonacoActions:695, uCsEditor:6046 |
| 44 | `sActMinimapHint` | ミニマップの表示・非表示 | Show or hide the minimap | CMonacoActions:696, uCsEditor:6047 |
| 45 | `sActPreviewCap` | プレビュー(&V) | Pre&view | CMonacoActions:714, uCsEditor:6064 |
| 46 | `sActPreviewHint` | プレビューの表示・非表示 | Show or hide the preview | CMonacoActions:715, uCsEditor:6065 |
| 47 | `sActLineNumbersCap` | 行番号(&L) | &Line Numbers | CMonacoActions:733, uCsEditor:6087 |
| 48 | `sActLineNumbersHint` | 行番号の表示・非表示 | Show or hide line numbers | CMonacoActions:734, uCsEditor:6088 |
| 49 | `sActWordWrapCap` | 折り返し(&W) | &Word Wrap | CMonacoActions:752, uCsEditor:6105 |
| 50 | `sActWordWrapHint` | 折り返し表示の切り替え | Toggle word wrap | CMonacoActions:753, uCsEditor:6106 |
| 51 | `sActRemoteImagesCap` | ネットの画像を表示(&I) | Show Online &Images | CMonacoActions:770, uCsEditor:6122 |
| 52 | `sActRemoteImagesHint` | プレビューで、ネット（http）の画像を表示するか | Show online (http) images in the preview | CMonacoActions:771, uCsEditor:6123 |

**C. ファイル選択の絞り込み**

| No | ID | 日本語 | English | 今ある場所（ファイル:行） |
|---|---|---|---|---|
| 53 | `sFilterText` | テキスト (*.txt)\|*.txt\|すべてのファイル (*.*)\|*.* | Text (*.txt)\|*.txt\|All files (*.*)\|*.* | CMonacoActions:351, uCsEditor:790, uCmonacos:1404・1490 |

**D. 検索・置換ダイアログ**

| No | ID | 日本語 | English | 今ある場所（ファイル:行） |
|---|---|---|---|---|
| 54 | `sFindTitle` | 検索・置換 | Find/Replace | CMonacoFindDlg:97・285, uCsEditor:1618・1804 |
| 55 | `sFindLblFind` | 検索(&F): | &Find: | CMonacoFindDlg:103, uCsEditor:1624 |
| 56 | `sFindLblRepl` | 置換(&R): | &Replace: | CMonacoFindDlg:108, uCsEditor:1629 |
| 57 | `sFindChkCase` | 大文字小文字を区別する(&C) | Match &case | CMonacoFindDlg:113, uCsEditor:1634 |
| 58 | `sFindChkWord` | 単語単位で検索(&W) | &Whole word | CMonacoFindDlg:114, uCsEditor:1635 |
| 59 | `sFindChkLoop` | ループ検索(&L) | &Loop search | CMonacoFindDlg:115, uCsEditor:1636 |
| 60 | `sFindBtnNext` | 次を検索(&N) | Find &Next | CMonacoFindDlg:118, uCsEditor:1639・6020 |
| 61 | `sFindBtnPrev` | 前を検索(&P) | Find &Previous | CMonacoFindDlg:119, uCsEditor:1640 |
| 62 | `sFindBtnReplace` | 置換(&E) | R&eplace | CMonacoFindDlg:120, uCsEditor:1641 |
| 63 | `sFindBtnReplaceAll` | すべて置換(&A) | Replace &All | CMonacoFindDlg:121, uCsEditor:1642 |
| 64 | `sFindBtnClose` | 閉じる | Close | CMonacoFindDlg:122, uCsEditor:1643 |
| 65 | `sFindNotFound` | 見つかりません | Not found | CMonacoFindDlg:347, uCsEditor:1861 |
| 66 | `sFindReplaced` | %d 件置換しました | %d replaced | CMonacoFindDlg:353, uCsEditor:1867 |

**E. エディタの右クリックメニュー・プレビューの右クリックメニュー**

| No | ID | 日本語 | English | 今ある場所（ファイル:行） |
|---|---|---|---|---|
| 67 | `sMnCut` | 切り抜き | Cut | cSynedit:1732, uCmmonacoview:2033, uCsEditor:4421 |
| 68 | `sMnCopy` | コピー | Copy | cSynedit:1733, uCmmonacoview:2034, uCsEditor:4422・5906, uCmdpreview:254 |
| 69 | `sMnPaste` | 貼り付け | Paste | cSynedit:1734, uCmmonacoview:2035, uCsEditor:4423・5924 |
| 70 | `sMnSelectAll` | すべて選択 | Select All | uCmmonacoview:2038, uCsEditor:4426・5943, uCmdpreview:258 |
| 71 | `sMnUndo` | 元に戻す | Undo | uCmmonacoview:2039, uCsEditor:4427・5852 |
| 72 | `sMnRedo` | やり直し | Redo | uCmmonacoview:2040, uCsEditor:4428・5870 |
| 73 | `sMnQuoteCopy` | 引用付きコピー | Copy as Quote | cSynedit:1738, uCmmonacoview:2041, uCsEditor:4429 |
| 74 | `sMnAppendCut` | 追加切り抜き | Append Cut | cSynedit:1739, uCmmonacoview:2042, uCsEditor:4430 |
| 75 | `sMnAppendCopy` | 追加コピー | Append Copy | cSynedit:1740, uCmmonacoview:2043, uCsEditor:4431 |
| 76 | `sMnDelete` | 削除 | Delete | cSynedit:1744, uCmmonacoview:2045, uCsEditor:4433 |
| 77 | `sMnToHalfKana` | ﾊﾝｶｸに変換 | Convert to Half-width Kana | uCmmonacoview:2050, uCsEditor:4438 |
| 78 | `sMnToHalfKanaSyn` | ハンカクに変換 | Convert to Half-width Kana | cSynedit:1753 |
| 79 | `sMnToHiragana` | 全角ひらがなに変換 | Convert to Full-width Hiragana | cSynedit:1754, uCmmonacoview:2051, uCsEditor:4439 |
| 80 | `sMnToKatakana` | 全角カタカナに変換 | Convert to Full-width Katakana | cSynedit:1755, uCmmonacoview:2052, uCsEditor:4440 |
| 81 | `sMnTabToSpace` | TAB -> 空白 | Convert Tabs to Spaces | uCmmonacoview:2054, uCsEditor:4442 |
| 82 | `sMnTabToSpaceSyn` | TAB -> 空白 変換 | Convert Tabs to Spaces | cSynedit:1759 |
| 83 | `sMnSpaceToTab` | 空白 -> TAB | Convert Spaces to Tabs | uCmmonacoview:2055, uCsEditor:4443 |
| 84 | `sMnSpaceToTabSyn` | 空白 -> TAB 変換 | Convert Spaces to Tabs | cSynedit:1760 |
| 85 | `sMnIndent` | インデント | Indent | cSynedit:1764, uCmmonacoview:2057, uCsEditor:4445 |
| 86 | `sMnOutdent` | 逆インデント | Unindent | cSynedit:1765, uCmmonacoview:2058, uCsEditor:4446 |
| 87 | `sMnMinimap` | ミニマップ | Minimap | uCmonacos:2850, uCsEditor:4452 |
| 88 | `sMnPreview` | プレビュー | Preview | uCmonacos:2856, uCsEditor:4457 |
| 89 | `sMnPrint` | 印刷... | Print... | uCmdpreview:265 |

**F. 確認・入力・エラーのメッセージ**

| No | ID | 日本語 | English | 今ある場所（ファイル:行） |
|---|---|---|---|---|
| 90 | `sUnsavedTitle` | 未保存の変更 | Unsaved changes | CMonacoTabs:306, uCmonacos:1323, uCsEditor:2882 |
| 91 | `sUnsavedLine1` | %s は変更されています。 | %s has been modified. | CMonacoTabs:307, uCmonacos:1324, uCsEditor:2883 |
| 92 | `sUnsavedLine2` | 保存しますか？（いいえ = 保存せずに閉じる） | Do you want to save it? (No = close without saving) | CMonacoTabs:308, uCmonacos:1325, uCsEditor:2884 |
| 93 | `sGoToLineTitle` | 行へ移動 | Go to Line | uCsEditor:3827 |
| 94 | `sGoToLinePrompt` | 行番号（1〜%d） | Line number (1-%d) | uCsEditor:3827 |
| 95 | `sErrCp932` | CP932(Shift_JIS)で表現できない文字が含まれています。Encoding を UTF-8 に変更してください。 | The text contains characters that cannot be represented in CP932 (Shift_JIS). Change Encoding to UTF-8. | uCmmonacoview:587, uCsEditor:899 |
| 96 | `sErrEditorHtml` | editor.html が見つかりません:  | editor.html not found:  | uCmmonacoview:948 |
| 97 | `sErrMonacoLoader` | Monaco の vs\loader.js が見つかりません:  | Monaco vs\loader.js not found:  | uCmmonacoview:953 |
| 98 | `sErrPreviewHtml` | preview.html が見つかりません:  | preview.html not found:  | uCmdpreview:366 |
| 99 | `sErrPrintDialog` | 印刷ダイアログを表示できませんでした | Could not show the print dialog | uCmdpreview:729 |
| 100 | `sErrPageRange` | Pages[%d]: ページの番号が範囲外です（ページの数 %d） | Pages[%d]: page index out of range (page count: %d) | uCmonacos:1574 |
| 101 | `sErrAlreadyOpen` | そのファイルは別のタブで開いています:  | That file is already open in another tab:  | uCmonacos:1645・1670, uCsEditor:2732・2843 |
| 102 | `sErrFileNotFound` | ファイルが見つかりません:  | File not found:  | uCmonacos:1663, uCsEditor:2727 |
| 103 | `sErrOpenOtherWindow` | 別のウィンドウで開けませんでした:  | Could not open in another window:  | uCmonacos:2154・2317, uCsEditor:5435・5519 |
| 104 | `sErrMoveOtherWindow` | ほかのウィンドウへ移せませんでした | Could not move to the other window | uCmonacos:2190, uCsEditor:5468 |
| 105 | `sErrNoPrintPage` | 印刷するページがありません | There is no page to print | uCmonacos:2495 |
| 106 | `sErrPreviewBinder` | TCMPreviewBinder.Attach: エディタまたはプレビューが nil です | TCMPreviewBinder.Attach: the editor or the preview is nil | CMonacoPreview:99 |
| 107 | `sErrTabBinder` | TCMTabBinder.Attach: エディタが nil です | TCMTabBinder.Attach: the editor is nil | CMonacoTabs:161 |
| 108 | `sErrIniMissing` | WebView2.ini が見つかりません:  | WebView2.ini not found:  | uCXRuntime:170 |
| 109 | `sErrWebView2Start` | WebView2 を起動できません | Could not start WebView2 | uCXRuntime:187 |

**G. TCTabBrowser**

| No | ID | 日本語 | English | 今ある場所（ファイル:行） |
|---|---|---|---|---|
| 110 | `sTbClose` | 閉じる | Close | uCTabBrowser:434・2009 |
| 111 | `sTbNew` | 新規作成 | New | uCTabBrowser:2008 |
| 112 | `sTbTabTitle` | タブ %d | Tab %d | uCTabBrowser:748 |

**H. TCPageControl・TCSideBar・TCTitleBar**

| No | ID | 日本語 | English | 今ある場所（ファイル:行） |
|---|---|---|---|---|
| 113 | `sPcNew` | 新しいタブ | New Tab | uCPageControl:408（resourcestring `rsCTabNew`） |
| 114 | `sPcClose` | タブを閉じる | Close Tab | uCPageControl:409（resourcestring `rsCTabClose`） |
| 115 | `sPcRename` | タブ名の変更 | Rename Tab | uCPageControl:410（resourcestring `rsCTabRename`） |
| 116 | `sPcNewPage` | 新しいタブ | New Tab | uCPageControl:411（resourcestring `rsCTabNewPageCaption`） |
| 117 | `sPcErrParent` | %s の親にできるのは TCPageControl だけです（%s は指定できません） | Only a TCPageControl can be the parent of %s (%s is not allowed) | uCPageControl:412（resourcestring `rsCTabCannotHaveParent`） |
| 118 | `sSbErrParent` | TCSideBarPage は TCSideBar の上にだけ置けます | TCSideBarPage can only be placed on a TCSideBar | uCSideBar:235（resourcestring `rsCSideBarPageParent`） |
| 119 | `sTitleErrOnlyOne` | TCTitleBar は1つのフォームに1つだけ置けます | Only one TCTitleBar can be placed on a form | uCTitleBar:162（resourcestring `rsCTitleBarOnlyOne`） |

**I. TCListView・TCTreeView**

| No | ID | 日本語 | English | 今ある場所（ファイル:行） |
|---|---|---|---|---|
| 120 | `sLvColName` | 名前 | Name | CListView:283 |
| 121 | `sLvColSize` | サイズ | Size | CListView:284 |
| 122 | `sLvColType` | 種類 | Type | CListView:285 |
| 123 | `sLvColDate` | 更新日時 | Date modified | CListView:289 |
| 124 | `sLvFolderType` | フォルダ | Folder | CListView:1167 |
| 125 | `sLvErrOpen` | ファイルを開けませんでした。エラーコード:  | Could not open the file. Error code:  | CListView:1440 |
| 126 | `sLvErrBadChars` | ファイル名に以下の文字は使用できません: | The following characters cannot be used in a file name: | CListView:1472 |
| 127 | `sLvViewLarge` | 大アイコン(&R) | Lar&ge icons | CListView:1501 |
| 128 | `sLvViewSmall` | 小アイコン(&N) | S&mall icons | CListView:1501 |
| 129 | `sLvViewList` | 一覧(&L) | &List | CListView:1501 |
| 130 | `sLvViewDetail` | 詳細(&D) | &Details | CListView:1501 |
| 131 | `sLvSortName` | 名前(&N) | &Name | CListView:1503 |
| 132 | `sLvSortSize` | サイズ(&S) | &Size | CListView:1503 |
| 133 | `sLvSortType` | 種類(&T) | &Type | CListView:1503 |
| 134 | `sLvSortDate` | 更新日時(&D) | &Date modified | CListView:1503 |
| 135 | `sLvSortAsc` | 昇順(&A) | &Ascending | CListView:1527 |
| 136 | `sLvSortDesc` | 降順(&E) | D&escending | CListView:1530 |
| 137 | `sLvMenuView` | 表示(&V) | &View | CListView:1533 |
| 138 | `sLvMenuSort` | 並べ替え(&O) | S&ort by | CListView:1534 |
| 139 | `sLvMenuNewFolder` | 新規フォルダー(&N) | New &folder | CListView:1618 |
| 140 | `sLvMenuNewText` | 新規テキスト ドキュメント(&T) | New &text document | CListView:1619 |
| 141 | `sLvMenuPaste` | 貼り付け(&P) | &Paste | CListView:1622・1624 |
| 142 | `sTvQuickAccess` | クイックアクセス | Quick access | CTreeView:885・887 |
| 143 | `sTvNetwork` | ネットワーク | Network | CTreeView:922 |
| 144 | `sTvErrBadChars` | フォルダ名に以下の文字は使用できません: | The following characters cannot be used in a folder name: | CTreeView:1718 |

**J. TCBookmark**

| No | ID | 日本語 | English | 今ある場所（ファイル:行） |
|---|---|---|---|---|
| 145 | `sBmMenuTextOpen` | Text開く | Open as Text | uCbookmark:361（resourcestring `rsMenuTextOpen`） |
| 146 | `sBmMenuTextOpenNew` | Text新しいタブで開く | Open as Text in New Tab | uCbookmark:362（resourcestring `rsMenuTextOpenNew`） |
| 147 | `sBmMenuBrowserOpen` | Browserで開く | Open in Browser | uCbookmark:363（resourcestring `rsMenuBrowserOpen`） |
| 148 | `sBmMenuBrowserOpenNew` | Browserで新しいタブで開く | Open in Browser in New Tab | uCbookmark:364（resourcestring `rsMenuBrowserOpenNew`） |
| 149 | `sBmMenuEdit` | ブックマークを編集 | Edit Bookmark | uCbookmark:365（resourcestring `rsMenuEdit`） |
| 150 | `sBmMenuDelete` | ブックマークを削除 | Delete Bookmark | uCbookmark:366（resourcestring `rsMenuDelete`） |
| 151 | `sBmMenuCut` | 切取り | Cut | uCbookmark:367（resourcestring `rsMenuCut`） |
| 152 | `sBmMenuCopy` | コピー | Copy | uCbookmark:368（resourcestring `rsMenuCopy`） |
| 153 | `sBmMenuPaste` | 貼り付け | Paste | uCbookmark:369（resourcestring `rsMenuPaste`） |
| 154 | `sBmMenuAddBookmark` | ブックマークを追加 | Add Bookmark | uCbookmark:370（resourcestring `rsMenuAddBookmark`） |
| 155 | `sBmMenuAddFolder` | フォルダーを追加 | Add Folder | uCbookmark:371（resourcestring `rsMenuAddFolder`） |
| 156 | `sBmMenuAddSeparator` | 区切り線 | Add Separator | uCbookmark:372（resourcestring `rsMenuAddSeparator`） |
| 157 | `sBmMenuImport` | インポート... | Import... | uCbookmark:373（resourcestring `rsMenuImport`） |
| 158 | `sBmMenuExport` | エクスポート... | Export... | uCbookmark:374（resourcestring `rsMenuExport`） |
| 159 | `sBmSearchHint` | ブックマークを検索 | Search bookmarks | uCbookmark:375（resourcestring `rsSearchHint`） |
| 160 | `sBmFileMissing` | ファイルがありません：%s | File not found: %s | uCbookmark:376（resourcestring `rsFileMissing`） |
| 161 | `sBmUnsaved` | 保存されていない変更があります。新しいタブで開きますか？ | There are unsaved changes. Open in a new tab? | uCbookmark:377（resourcestring `rsUnsaved`） |
| 162 | `sBmDeleteFolder` | フォルダー「%s」と中の %d 件を削除しますか？ | Delete the folder "%s" and its %d item(s)? | uCbookmark:378（resourcestring `rsDeleteFolder`） |
| 163 | `sBmTooMany` | %d 件を登録しますか？ | Add %d item(s)? | uCbookmark:379（resourcestring `rsTooMany`） |
| 164 | `sBmSaveError` | ブックマークを保存できません：%s | Could not save the bookmarks: %s | uCbookmark:380（resourcestring `rsSaveError`） |
| 165 | `sBmLoadError` | ブックマークを読み込めませんでした。元のファイルは %s に残しました。 | Could not load the bookmarks. The original file was kept at %s. | uCbookmark:381（resourcestring `rsLoadError`） |
| 166 | `sBmDlgAdd` | ブックマークを追加 | Add Bookmark | uCbookmark:382（resourcestring `rsDlgAdd`） |
| 167 | `sBmDlgEdit` | ブックマークを編集 | Edit Bookmark | uCbookmark:383（resourcestring `rsDlgEdit`） |
| 168 | `sBmDlgAddFolder` | フォルダーを追加 | Add Folder | uCbookmark:384（resourcestring `rsDlgAddFolder`） |
| 169 | `sBmDlgEditFolder` | フォルダー名を編集 | Edit Folder Name | uCbookmark:385（resourcestring `rsDlgEditFolder`） |
| 170 | `sBmDlgName` | 名前 | Name | uCbookmark:386（resourcestring `rsDlgName`） |
| 171 | `sBmDlgLocation` | URL またはファイルパス | URL or file path | uCbookmark:387（resourcestring `rsDlgLocation`） |
| 172 | `sBmNewFolder` | 新しいフォルダー | New Folder | uCbookmark:388（resourcestring `rsNewFolder`） |
| 173 | `sBmOK` | OK | OK | uCbookmark:389（resourcestring `rsOK`） |
| 174 | `sBmCancel` | キャンセル | Cancel | uCbookmark:390（resourcestring `rsCancel`） |
| 175 | `sBmImportFolder` | インポート %s | Import %s | uCbookmark:391（resourcestring `rsImportFolder`） |
| 176 | `sBmImportNone` | ブックマークが見つかりませんでした。 | No bookmarks were found. | uCbookmark:392（resourcestring `rsImportNone`） |
| 177 | `sBmImportError` | インポートできません：%s | Could not import: %s | uCbookmark:393（resourcestring `rsImportError`） |
| 178 | `sBmExportError` | エクスポートできません：%s | Could not export: %s | uCbookmark:394（resourcestring `rsExportError`） |
| 179 | `sBmOpenError` | 開けません：%s | Could not open: %s | uCbookmark:395（resourcestring `rsOpenError`） |
| 180 | `sBmHtmlFilter` | ブックマーク HTML (*.html;*.htm)\|*.html;*.htm\|すべてのファイル (*.*)\|*.* | Bookmark HTML (*.html;*.htm)\|*.html;*.htm\|All files (*.*)\|*.* | uCbookmark:396（resourcestring `rsHtmlFilter`） |

**K. TCFileTree**

TCFileTree（`CFileTree.pas`）は、最初から `CXT` を使う新しい部品なので、置き換えるものはない。「使っている場所」は、行番号を `CFileTree.pas` の今の行で示す。

| No | ID | 日本語 | English | 使っている場所（ファイル:行） |
|---|---|---|---|---|
| 181 | `sFtMenuCopy` | コピー | Copy | CFileTree:1889 |
| 182 | `sFtMenuCut` | 切取り | Cut | CFileTree:1890 |
| 183 | `sFtMenuPaste` | 貼付け | Paste | CFileTree:1891 |
| 184 | `sFtMenuRename` | 名前の変更 | Rename | CFileTree:1892 |
| 185 | `sFtMenuDelete` | 削除 | Delete | CFileTree:1893 |
| 186 | `sFtMenuShowInExplorer` | エクスプローラーで表示 | Show in Explorer | CFileTree:1895 |
| 187 | `sFtMenuCopyPath` | パスのコピー | Copy Path | CFileTree:1896 |
| 188 | `sFtMenuNewFolder` | フォルダ作成 | New Folder | CFileTree:1898 |
| 189 | `sFtMenuTextOpen` | text開く | Open as Text | CFileTree:1900 |
| 190 | `sFtMenuTextOpenNew` | text新規タブで開く | Open as Text in New Tab | CFileTree:1901 |
| 191 | `sFtMenuSide` | 横に並べて表示 | Open Side by Side | CFileTree:1902・1906（text と Web の 2 項目で共用） |
| 192 | `sFtMenuWebOpen` | Web開く | Open as Web | CFileTree:1904 |
| 193 | `sFtMenuWebOpenNew` | Web新規タブで開く | Open as Web in New Tab | CFileTree:1905 |
| 194 | `sFtMenuOpenProgram` | プログラムで開く | Open with Associated Program | CFileTree:1908 |
| 195 | `sFtMenuShowHidden` | 隠しファイルを表示 | Show Hidden Files | CFileTree:1910 |
| 196 | `sFtMenuWindowsMenu` | windowsメニュー | Windows Menu | CFileTree:1912 |
| 197 | `sFtErrBadChars` | ファイル名・フォルダー名に以下の文字は使用できません: | The following characters cannot be used in a file or folder name: | CFileTree:1583 |
| 198 | `sFtErrCreateFolder` | フォルダーを作れませんでした：%s | Could not create the folder: %s | CFileTree:1649 |

TCFileTree は、このほかに、TCBookmark の `sBmUnsaved`・`sBmOpenError`・`sBmFileMissing`・`sBmNewFolder` も使う（J. の 4 項目。追加はない）。

## 6. 各ユニットの直し方

| ファイル | 項目数 | 直すところ |
|---|---|---|
| `uCXLang.pas` | ― | 新しく作る（3・4章） |
| `CMonacoActions.pas` | 51 | 標準アクションの `Caption`・`Hint`、ファイル選択の絞り込み（`Markdown (*.md;*.markdown)\|…` の後ろの `sFilterText` の部分だけ） |
| `uCsEditor.pas` | 94 | CMonacoActions と同じ内容のアクション（5734〜6123 行）、検索・置換ダイアログ、右クリックメニュー、未保存の確認、行へ移動、エラーの文、ファイル選択の絞り込み、無題 |
| `cSynedit.pas` | 15 | 右クリックメニュー、無題.txt（初期のファイル名 660 行と、名前を返す 718 行） |
| `uCmmonacoview.pas` | 21 | 右クリックメニュー、無題、エラーの文、`JapaneseUI`（7.1） |
| `uCmonacos.pas` | 12 | ミニマップ・プレビューのメニュー、未保存の確認、エラーの文、ファイル選択の絞り込み |
| `CMonacoFindDlg.pas` | 13 | 検索・置換ダイアログ |
| `uCmdpreview.pas` | 5 | プレビューの右クリックメニュー、エラーの文、`opt lang` を送る（7.2） |
| `CMonacoTabs.pas` | 4 | 未保存の確認、例外の文 |
| `CMonacoPreview.pas` | 1 | 例外の文 |
| `uCXRuntime.pas` | 2 | エラーの文。uses に `uCXLang` を足す |
| `uCTabBrowser.pas` | 3 | タブの右クリック「閉じる」、ページの右クリック「新規作成」「閉じる」、タブ名 |
| `uCPageControl.pas`・`uCSideBar.pas`・`uCTitleBar.pas` | 5・1・1 | `resourcestring` の定義を消し、使っている所を `CXT(...)` に替える |
| `CListView.pas` | 22 | 列の見出し、メニュー、メッセージ。`ViewCaptions`・`SortCaptions`（定数の配列）は、`CXT` を返す関数に替える |
| `CTreeView.pas` | 3 | 「クイックアクセス」「ネットワーク」、メッセージ |
| `uCbookmark.pas` | 36 | `resourcestring` の定義（361〜396 行）を消し、使っている所を `CXT(...)` に替える |

- 文字列を `CXT` に替える所は、5章の「今ある場所」の行。同じ ID の場所は、すべて同じ ID に替える。
- 画面に出す時点で `CXT` を呼ぶ。部品を作った時点より前に言語が決まる必要はない（`CXLanguage` が最初の呼び出しで決める）。
- `CListView.pas` の「ファイル フォルダー」との比較（1166 行）は、Windows が返す種類の名前を見分ける所なので、辞書には入れない。比較する文字列に `File folder` を足し、`ファイル フォルダー` か `File folder` のどちらかなら、表示を `sLvFolderType` にする。
- `CListView.pas` で `UTF8ToUTF16('…')` に渡している文字列は、`UTF8ToUTF16(CXT(ID))` に替える。
- 英語は日本語より長くなる文字列がある。英語で表示したとき、検索・置換ダイアログ（`CMonacoFindDlg`・`uCsEditor`）のラベル・チェックボックス・ボタンの文字が切れないようにする（切れる所は、その部品の幅を広げる）。

### 6.1 変更の対比（今と変更後）

| No | 項目 | 今の動作・問題点 | 変更後 | 変える理由 | リスク |
|---|---|---|---|---|---|
| 1 | 文字列の置き場 | 各ユニットに日本語を直接書いている。同じ文字列が最大 3 か所（`CMonacoFindDlg` と `uCsEditor` など）に重複。`uCbookmark` などだけ `resourcestring` | `uCXLang` の表 1 つ（180 項目）から `CXT` で取る | 英語を足すとき、直す場所が 3 倍になり、方法もばらばらになるため | 置き換え漏れ（英語の画面に日本語が残る）。5章の表と照合し、テストで英語の画面を確認する |
| 2 | `resourcestring`（4 ユニット） | `rs…` の名前で日本語を持つ | 定義を消し、`CXT(s…)` に替える | 辞書を 1 か所にするため | 日本語の文字列は同じなので、日本語での表示は変わらない |
| 3 | `JapaneseUI`（`TCMonacoEditor` と、その内部の `uCmmonacoview.pas`） | 既定 `True` で、いつも Monaco の画面を日本語にする。cx を英語にしても Monaco だけ日本語になる | `True` かつ cx が日本語のときだけ日本語。`False` ならいつも英語 | cx の言語と Monaco の言語を揃えるため | 英語の Windows で今まで日本語の Monaco を使っていた場合は、英語に変わる（意図した変更） |
| 4 | ini が無いときの文言 | 日本語固定 | 2.1 の順（ini が無ければ Windows の表示言語） | 英語の環境で日本語のエラーが出るのを防ぐため | なし |
| 5 | `CListView` の種類の判定 | Windows が日本語で返す「ファイル フォルダー」と比べて「フォルダ」に直す。英語の Windows では一致せず、そのまま | 「File folder」も比べて、`sLvFolderType` にする | 英語の Windows でも日本語の Windows と同じ動きにするため | なし |

## 7. HTML 側

### 7.1 editor.html（変更なし）

- `editor.html` は、`?lang=ja` が付くと Monaco 内蔵の表示を日本語にする（今の作り。変えない）。
- `uCmmonacoview.pas` の URL を作る所（959 行）を `if FJapaneseUI and (CXLanguage = cxlJa) then Url := Url + '?lang=ja';` に替える。
- `JapaneseUI` の名前・既定値（`True`）・公開の仕方は変えない（`uCmonacos.pas` の `TCMonacoEditor` と `uCmmonacoview.pas` の内部の部品の両方）。

### 7.2 preview.html

- Pascal は、`ready` を受けたあとに `opt` をまとめて送る処理（`uCmdpreview.pas` 515〜518 行）の先頭で、`opt` `lang` `ja`（または `en`）を送る（値は `CXLangCode`）。`render`・`code` より前に届く。
- `preview.html` は、`state.lang`（初期値 `'ja'`）と、日本語・English の辞書 `I18N`、取り出す関数 `t(key)` を持つ。`opt` の `lang` を受けたら `state.lang` を替える。
- `title` を一度も受けていないときは、`opt` `lang` を受けた時点で `document.title` を `t('untitled')` にする（印刷の PDF の名前の初期値）。
- `opt` `lang` が届かないときは、今と同じ日本語で動く。

| key | 日本語 | English | 今ある場所（preview.html の行） |
|---|---|---|---|
| `untitled` | 無題 | Untitled | 7・816 |
| `extImg` | 外部画像は表示しません | External image not shown | 359・562（前後に `[` `]` を付ける。359 は alt があれば `: alt` を続ける） |
| `imgFail` | 画像を取得できませんでした | Could not fetch the image | 570（前後に `[` `]` を付ける） |
| `mmLoadFail` | mermaid.js を読み込めません | Cannot load mermaid.js | 400 |
| `mmNotFound` | lib/mermaid.min.js が見つかりません | lib/mermaid.min.js not found | 401 |
| `mmDrawFail` | Mermaid の図を描けません: | Cannot draw the Mermaid diagram: | 550（後ろに改行とエラーの文を続ける） |
| `tbPan` | 移動 | Pan | 490 |
| `tbZoomOut` | 縮小 | Zoom out | 491 |
| `tbZoomIn` | 拡大 | Zoom in | 492 |
| `tbFit` | 枠に合わせる | Fit to frame | 493 |

## 8. 対象外

| 項目 | 理由・扱い |
|---|---|
| 実際にディスクへ作られる名前（`CListView` の「新しいフォルダー」「新しいフォルダー (n)」「新規テキスト ドキュメント」「新規テキスト ドキュメント (n)」） | 一度作ると言語を変えても残り、日本語名と英語名が混ざるため。今のまま日本語 |
| IDE 用の登録ユニット（`uCPageControl_reg`・`uCSideBarReg` の「ページの追加」など） | cxdsgn（設計時）のため。今のまま日本語 |
| Windows と LCL の標準ダイアログ（ファイルを開く・保存、`MessageDlg` のボタン） | OS・LCL が出す言語に従う |
| 区切り文字の全角空白・読点（`FLineDelimiters`） | 画面に出さない |
| ソースのコメント、`.md` の文書 | 画面に出さない |
| Monaco 内蔵の表示 | Monaco 自身の言語切り替え（7.1） |

## 9. 決めていること

| 項目 | 決定 |
|---|---|
| 言語の単位 | cx 全体で 1 つ |
| 言語の値 | `ja`・`en` |
| 指定 | `WebView2.ini` の `[CX]` の `Language` |
| 指定がない・ini がない | Windows の表示言語（日本語なら `ja`、それ以外は `en`） |
| 決める時期 | 実行時。最初に文字列が必要になったとき 1 回 |
| 文字列の置き場 | `uCXLang.pas` の表 1 つ。`CXT(ID)` で取る |
| 日本語 | 今の文字列をそのまま使う |
| HTML | `editor.html` は変えない。`preview.html` は `opt lang` と辞書 |

**作らないもの**

| 項目 | 理由・代わり |
|---|---|
| 部品ごとの言語プロパティ | cx 全体で 1 つにする |
| 実行中の言語の切り替え | ini は起動時に 1 回だけ読む |
| 日本語・英語以外の言語 | 2 つだけ |
| 辞書の外部ファイル（`.po` など） | 使う人・直す人は 1 人。表 1 つで足りる |

## 10. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| 英語にしても日本語が残る | 5章の表の「今ある場所」が `CXT` に替わっているか |
| ini に `Language=en` と書いても日本語のまま | ini の場所（EXE と同じ）・セクション名 `[CX]`・値の綴り（2.1） |
| Monaco の表示だけ日本語 | `JapaneseUI` の値と `CXLanguage`（7.1） |
| プレビューの図のボタン・エラーだけ日本語 | `opt lang` が `render` より前に送られているか（7.2） |
| 英語の Windows で一覧の種類が「File folder」のまま | `CListView` の比較（6章） |
| 英語で文字が切れる | 検索・置換ダイアログの幅（6章） |
| IDE でフォームに置いた部品の初期の文字が英語になる | IDE が動く Windows の表示言語（ini が無いため 2.1 の 2 になる）。設計時に .lfm へ保存される文字は、その時点の言語になる |

## 11. この版の変更（1.0。新しく作る）

コードを作るための手順。取説には入れない。

| No | ファイル | 変更 |
|---|---|---|
| 1 | `uCXLang.pas` | 新しく作る（3・4・5章） |
| 2 | `cx.lpk` | `../source/uCXLang.pas`（UnitName `uCXLang`）を足す |
| 3 | `uCXRuntime.pas` | uses に `uCXLang` を足し、エラーの文 2 つを `CXT` に替える |
| 4 | 6章に挙げたユニット | 5章の表のとおり、文字列を `CXT` に替える。`resourcestring` の 4 ユニットは定義を消す |
| 5 | `uCmmonacoview.pas` | `JapaneseUI` の条件（7.1） |
| 6 | `uCmdpreview.pas` | `opt lang` を送る（7.2） |
| 7 | `preview.html` | `I18N`・`t(key)`・`opt` の `lang`（7.2） |
| 8 | `editor.html`・`cxdsgn.lpk`・IDE 用の登録ユニット | 変更なし |
