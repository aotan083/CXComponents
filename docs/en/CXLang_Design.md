# CXLang (Japanese/English Support) Design Document

Author: aotan083
Date: 2026-11-04
Version: 1.0

---

## 1. Purpose and Policy

Make the strings that the cx components show on screen (menus, buttons, messages) switchable between Japanese and English.

| No | Policy |
|---|---|
| 1 | There is one language for all of cx. No per-component setting is made |
| 2 | The language has two values: Japanese (`ja`) and English (`en`) |
| 3 | The language is decided at run time (not at compile time) |
| 4 | The strings are gathered in one table in a new unit, `uCXLang.pas`. Each component gets them with `CXT(ID)` |
| 5 | The Japanese strings are the current strings, unchanged character for character (the Japanese display stays the same as now) |
| 6 | Only strings shown on screen are covered (chapter 8 lists what is out of scope) |
| 7 | The I/F (properties, methods, events) of components that already work and are tested is not changed. Only the way strings are obtained changes |

## 2. How the Language Is Decided

### 2.1 Order

1. If `Language` in the `[CX]` section of `WebView2.ini` in the same folder as the EXE is `ja` or `en`, use that language (case-insensitive; leading and trailing spaces are removed)
2. Otherwise (no ini, no `[CX]`, no `Language`, empty, or a value other than `ja`/`en`), follow the Windows display language: `ja` if it is Japanese, `en` otherwise

```ini
[CX]
Language=en
```

- This is a separate section from the `[WebView2]` section of the ini (read by `uCXRuntime`). The way `uCXRuntime` reads the ini is not changed.
- The language is decided only once, the first time a string is needed. Rewriting the ini while running has no effect until the next start (same as the `uCXRuntime` ini).
- If the ini cannot be read, no exception is raised; go on to step 2.
- The Windows display language is checked by whether the low 10 bits of `GetUserDefaultUILanguage` in `kernel32` are `$11` (LANG_JAPANESE).

### 2.2 Behavior When There Is No ini

- When there is no ini, `uCXRuntime` does not start WebView2 (unchanged). The error message in that case (`sErrIniMissing`) is also shown in the language decided by step 2.

## 3. Files and Packages

| File | Package | Content |
|---|---|---|
| `uCXLang.pas` (new) | cx (runtime) | Deciding the language, the string table, `CXT` |
| Each unit | cx (runtime) | Change the way strings are obtained as in chapter 6 |
| `preview.html` | Runtime file | Chapter 7 |
| `editor.html` | Runtime file | Unchanged |

- uses of `uCXLang`: `SysUtils, IniFiles`. It does not use `uCXRuntime` or WebView4Delphi (so that components that do not use WebView2, such as `TCListView`, do not pull in WebView4Delphi).
- `uCXLang` has no `initialization` or `finalization` (same as `uCXRuntime`; just adding it to uses does nothing).
- cxdsgn (design time) is not changed. Strings in the IDE registration units are out of scope (chapter 8).

## 4. Structure of uCXLang

```pascal
type
  TCXLanguage = (cxlJa, cxlEn);
  TCXStr = (sUntitled, sUntitledTxt, ... );   // all IDs of chapter 5, in No order

function CXLanguage: TCXLanguage;   // current language (decided in the 2.1 order on the first call; the same value afterwards)
function CXLangCode: string;        // 'ja' or 'en' (the value passed to the HTML side)
function CXT(AId: TCXStr): string;  // the string that matches CXLanguage
```

- The strings are held in a constant array indexed by `TCXStr` (pairs of Japanese and English). The order is the same as `TCXStr` and the No in chapter 5.
- `CXT` returns the Japanese string for `cxlJa` and the English string for `cxlEn`.
- For strings used with `Format` (containing `%s` or `%d`), the Japanese and English versions have the same order and kinds of placeholders. The caller writes `Format(CXT(ID), [...])`.
- No string contains a line break. Where a line break is needed, the caller joins strings with `LineEnding` (`sUnsavedLine1` and `sUnsavedLine2`).
- Strings that end with ": " (`sErr...`) include one trailing space. The caller appends a file name or similar after it.
- No procedure to change the language later is made.
- When compiled on something other than Windows (for checking tests), the Windows display language is not checked and the language is treated as `en` (`{$IFDEF MSWINDOWS}`).

## 5. String Table (180 Items)

- "Japanese" is the string in the current source, as is. "English" is the newly added string.
- The `&` in menus and buttons does not overlap within the same menu (the same dialog).
- Exception messages such as `sErrCp932` and `sErrPreviewBinder` are included because they appear on screen.
- Line numbers are the lines in the source at the time this design document was written.

**A. Untitled Names**

| No | ID | Japanese | English | Current location (file:line) |
|---|---|---|---|---|
| 1 | `sUntitled` | 無題 | Untitled | uCmmonacoview:1177, uCsEditor:1287 |
| 2 | `sUntitledTxt` | 無題.txt | Untitled.txt | cSynedit:660・718 |

**B. Standard Actions (Caption and Hint)**

| No | ID | Japanese | English | Current location (file:line) |
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

**C. File Dialog Filter**

| No | ID | Japanese | English | Current location (file:line) |
|---|---|---|---|---|
| 53 | `sFilterText` | テキスト (*.txt)\|*.txt\|すべてのファイル (*.*)\|*.* | Text (*.txt)\|*.txt\|All files (*.*)\|*.* | CMonacoActions:351, uCsEditor:790, uCmonacos:1404・1490 |

**D. Find/Replace Dialog**

| No | ID | Japanese | English | Current location (file:line) |
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

**E. Editor Context Menu and Preview Context Menu**

| No | ID | Japanese | English | Current location (file:line) |
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

**F. Confirmation, Input, and Error Messages**

| No | ID | Japanese | English | Current location (file:line) |
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

| No | ID | Japanese | English | Current location (file:line) |
|---|---|---|---|---|
| 110 | `sTbClose` | 閉じる | Close | uCTabBrowser:434・2009 |
| 111 | `sTbNew` | 新規作成 | New | uCTabBrowser:2008 |
| 112 | `sTbTabTitle` | タブ %d | Tab %d | uCTabBrowser:748 |

**H. TCPageControl, TCSideBar, TCTitleBar**

| No | ID | Japanese | English | Current location (file:line) |
|---|---|---|---|---|
| 113 | `sPcNew` | 新しいタブ | New Tab | uCPageControl:408 (resourcestring `rsCTabNew`) |
| 114 | `sPcClose` | タブを閉じる | Close Tab | uCPageControl:409 (resourcestring `rsCTabClose`) |
| 115 | `sPcRename` | タブ名の変更 | Rename Tab | uCPageControl:410 (resourcestring `rsCTabRename`) |
| 116 | `sPcNewPage` | 新しいタブ | New Tab | uCPageControl:411 (resourcestring `rsCTabNewPageCaption`) |
| 117 | `sPcErrParent` | %s の親にできるのは TCPageControl だけです（%s は指定できません） | Only a TCPageControl can be the parent of %s (%s is not allowed) | uCPageControl:412 (resourcestring `rsCTabCannotHaveParent`) |
| 118 | `sSbErrParent` | TCSideBarPage は TCSideBar の上にだけ置けます | TCSideBarPage can only be placed on a TCSideBar | uCSideBar:235 (resourcestring `rsCSideBarPageParent`) |
| 119 | `sTitleErrOnlyOne` | TCTitleBar は1つのフォームに1つだけ置けます | Only one TCTitleBar can be placed on a form | uCTitleBar:162 (resourcestring `rsCTitleBarOnlyOne`) |

**I. TCListView, TCTreeView**

| No | ID | Japanese | English | Current location (file:line) |
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

| No | ID | Japanese | English | Current location (file:line) |
|---|---|---|---|---|
| 145 | `sBmMenuTextOpen` | Text開く | Open as Text | uCbookmark:361 (resourcestring `rsMenuTextOpen`) |
| 146 | `sBmMenuTextOpenNew` | Text新しいタブで開く | Open as Text in New Tab | uCbookmark:362 (resourcestring `rsMenuTextOpenNew`) |
| 147 | `sBmMenuBrowserOpen` | Browserで開く | Open in Browser | uCbookmark:363 (resourcestring `rsMenuBrowserOpen`) |
| 148 | `sBmMenuBrowserOpenNew` | Browserで新しいタブで開く | Open in Browser in New Tab | uCbookmark:364 (resourcestring `rsMenuBrowserOpenNew`) |
| 149 | `sBmMenuEdit` | ブックマークを編集 | Edit Bookmark | uCbookmark:365 (resourcestring `rsMenuEdit`) |
| 150 | `sBmMenuDelete` | ブックマークを削除 | Delete Bookmark | uCbookmark:366 (resourcestring `rsMenuDelete`) |
| 151 | `sBmMenuCut` | 切取り | Cut | uCbookmark:367 (resourcestring `rsMenuCut`) |
| 152 | `sBmMenuCopy` | コピー | Copy | uCbookmark:368 (resourcestring `rsMenuCopy`) |
| 153 | `sBmMenuPaste` | 貼り付け | Paste | uCbookmark:369 (resourcestring `rsMenuPaste`) |
| 154 | `sBmMenuAddBookmark` | ブックマークを追加 | Add Bookmark | uCbookmark:370 (resourcestring `rsMenuAddBookmark`) |
| 155 | `sBmMenuAddFolder` | フォルダーを追加 | Add Folder | uCbookmark:371 (resourcestring `rsMenuAddFolder`) |
| 156 | `sBmMenuAddSeparator` | 区切り線 | Add Separator | uCbookmark:372 (resourcestring `rsMenuAddSeparator`) |
| 157 | `sBmMenuImport` | インポート... | Import... | uCbookmark:373 (resourcestring `rsMenuImport`) |
| 158 | `sBmMenuExport` | エクスポート... | Export... | uCbookmark:374 (resourcestring `rsMenuExport`) |
| 159 | `sBmSearchHint` | ブックマークを検索 | Search bookmarks | uCbookmark:375 (resourcestring `rsSearchHint`) |
| 160 | `sBmFileMissing` | ファイルがありません：%s | File not found: %s | uCbookmark:376 (resourcestring `rsFileMissing`) |
| 161 | `sBmUnsaved` | 保存されていない変更があります。新しいタブで開きますか？ | There are unsaved changes. Open in a new tab? | uCbookmark:377 (resourcestring `rsUnsaved`) |
| 162 | `sBmDeleteFolder` | フォルダー「%s」と中の %d 件を削除しますか？ | Delete the folder "%s" and its %d item(s)? | uCbookmark:378 (resourcestring `rsDeleteFolder`) |
| 163 | `sBmTooMany` | %d 件を登録しますか？ | Add %d item(s)? | uCbookmark:379 (resourcestring `rsTooMany`) |
| 164 | `sBmSaveError` | ブックマークを保存できません：%s | Could not save the bookmarks: %s | uCbookmark:380 (resourcestring `rsSaveError`) |
| 165 | `sBmLoadError` | ブックマークを読み込めませんでした。元のファイルは %s に残しました。 | Could not load the bookmarks. The original file was kept at %s. | uCbookmark:381 (resourcestring `rsLoadError`) |
| 166 | `sBmDlgAdd` | ブックマークを追加 | Add Bookmark | uCbookmark:382 (resourcestring `rsDlgAdd`) |
| 167 | `sBmDlgEdit` | ブックマークを編集 | Edit Bookmark | uCbookmark:383 (resourcestring `rsDlgEdit`) |
| 168 | `sBmDlgAddFolder` | フォルダーを追加 | Add Folder | uCbookmark:384 (resourcestring `rsDlgAddFolder`) |
| 169 | `sBmDlgEditFolder` | フォルダー名を編集 | Edit Folder Name | uCbookmark:385 (resourcestring `rsDlgEditFolder`) |
| 170 | `sBmDlgName` | 名前 | Name | uCbookmark:386 (resourcestring `rsDlgName`) |
| 171 | `sBmDlgLocation` | URL またはファイルパス | URL or file path | uCbookmark:387 (resourcestring `rsDlgLocation`) |
| 172 | `sBmNewFolder` | 新しいフォルダー | New Folder | uCbookmark:388 (resourcestring `rsNewFolder`) |
| 173 | `sBmOK` | OK | OK | uCbookmark:389 (resourcestring `rsOK`) |
| 174 | `sBmCancel` | キャンセル | Cancel | uCbookmark:390 (resourcestring `rsCancel`) |
| 175 | `sBmImportFolder` | インポート %s | Import %s | uCbookmark:391 (resourcestring `rsImportFolder`) |
| 176 | `sBmImportNone` | ブックマークが見つかりませんでした。 | No bookmarks were found. | uCbookmark:392 (resourcestring `rsImportNone`) |
| 177 | `sBmImportError` | インポートできません：%s | Could not import: %s | uCbookmark:393 (resourcestring `rsImportError`) |
| 178 | `sBmExportError` | エクスポートできません：%s | Could not export: %s | uCbookmark:394 (resourcestring `rsExportError`) |
| 179 | `sBmOpenError` | 開けません：%s | Could not open: %s | uCbookmark:395 (resourcestring `rsOpenError`) |
| 180 | `sBmHtmlFilter` | ブックマーク HTML (*.html;*.htm)\|*.html;*.htm\|すべてのファイル (*.*)\|*.* | Bookmark HTML (*.html;*.htm)\|*.html;*.htm\|All files (*.*)\|*.* | uCbookmark:396 (resourcestring `rsHtmlFilter`) |

## 6. How Each Unit Is Changed

| File | Items | What to change |
|---|---|---|
| `uCXLang.pas` | ― | New (chapters 3 and 4) |
| `CMonacoActions.pas` | 51 | `Caption` and `Hint` of the standard actions; the file dialog filter (only the `sFilterText` part after `Markdown (*.md;*.markdown)\|…`) |
| `uCsEditor.pas` | 94 | Actions with the same content as CMonacoActions (lines 5734-6123), the find/replace dialog, the context menu, the unsaved-changes confirmation, Go to Line, error messages, the file dialog filter, Untitled |
| `cSynedit.pas` | 15 | Context menu, 無題.txt (the initial file name at line 660 and the name returned at line 718) |
| `uCmmonacoview.pas` | 21 | Context menu, Untitled, error messages, `JapaneseUI` (7.1) |
| `uCmonacos.pas` | 12 | Minimap and preview menus, the unsaved-changes confirmation, error messages, the file dialog filter |
| `CMonacoFindDlg.pas` | 13 | Find/replace dialog |
| `uCmdpreview.pas` | 5 | Preview context menu, error messages, sending `opt lang` (7.2) |
| `CMonacoTabs.pas` | 4 | Unsaved-changes confirmation, exception messages |
| `CMonacoPreview.pas` | 1 | Exception message |
| `uCXRuntime.pas` | 2 | Error messages. Add `uCXLang` to uses |
| `uCTabBrowser.pas` | 3 | Tab context menu "Close", page context menu "New" and "Close", tab name |
| `uCPageControl.pas`, `uCSideBar.pas`, `uCTitleBar.pas` | 5, 1, 1 | Remove the `resourcestring` definitions and replace their uses with `CXT(...)` |
| `CListView.pas` | 22 | Column headers, menus, messages. `ViewCaptions` and `SortCaptions` (constant arrays) are replaced with functions that return `CXT` |
| `CTreeView.pas` | 3 | "クイックアクセス" (Quick access), "ネットワーク" (Network), message |
| `uCbookmark.pas` | 36 | Remove the `resourcestring` definitions (lines 361-396) and replace their uses with `CXT(...)` |

- The places where a string is replaced with `CXT` are the lines in "Current location" in chapter 5. All places with the same ID are replaced with the same ID.
- `CXT` is called at the moment the string is shown. The language does not need to be decided before the component is created (`CXLanguage` decides it on the first call).
- The comparison with "ファイル フォルダー" in `CListView.pas` (line 1166) recognizes the type name returned by Windows, so it is not put in the table. Add `File folder` to the strings compared; if the type is either `ファイル フォルダー` or `File folder`, show `sLvFolderType`.
- Strings passed to `UTF8ToUTF16('…')` in `CListView.pas` are replaced with `UTF8ToUTF16(CXT(ID))`.
- Some English strings are longer than the Japanese ones. When shown in English, the text of the labels, check boxes, and buttons of the find/replace dialog (`CMonacoFindDlg` and `uCsEditor`) must not be cut off (where it is cut off, widen that control).

### 6.1 Comparison of Changes (Now and After)

| No | Item | Current behavior / problem | After the change | Reason for the change | Risk |
|---|---|---|---|---|---|
| 1 | Where strings are kept | Japanese is written directly in each unit. The same string is duplicated in up to 3 places (`CMonacoFindDlg`, `uCsEditor`, etc.). Only `uCbookmark` and a few others use `resourcestring` | Obtained with `CXT` from one table in `uCXLang` (180 items) | When adding English, the number of places to change would triple and the methods would be inconsistent | A missed replacement (Japanese remains on the English screen). Check against the table in chapter 5 and check the English screen in testing |
| 2 | `resourcestring` (4 units) | Japanese is held under `rs…` names | Remove the definitions and replace them with `CXT(s…)` | To keep the dictionary in one place | The Japanese strings are the same, so the Japanese display does not change |
| 3 | `JapaneseUI` (`TCMonacoEditor` and its internal `uCmmonacoview.pas`) | Default `True`; the Monaco screen is always Japanese. Even if cx is set to English, only Monaco stays Japanese | Japanese only when `True` and cx is Japanese. Always English when `False` | To match the Monaco language to the cx language | If someone used Japanese Monaco on English Windows until now, it changes to English (an intended change) |
| 4 | Message when there is no ini | Fixed to Japanese | The 2.1 order (if there is no ini, the Windows display language) | To avoid Japanese errors in an English environment | None |
| 5 | Type check in `CListView` | Compares with "ファイル フォルダー" returned by Japanese Windows and changes it to "フォルダ". On English Windows it does not match and stays as is | Also compares with "File folder" and uses `sLvFolderType` | To make English Windows behave the same as Japanese Windows | None |

## 7. HTML Side

### 7.1 editor.html (Unchanged)

- With `?lang=ja`, `editor.html` shows Monaco's built-in display in Japanese (the current design; not changed).
- The place where `uCmmonacoview.pas` builds the URL (line 959) is changed to `if FJapaneseUI and (CXLanguage = cxlJa) then Url := Url + '?lang=ja';`.
- The name, default value (`True`), and publishing of `JapaneseUI` are not changed (both `TCMonacoEditor` in `uCmonacos.pas` and the internal component in `uCmmonacoview.pas`).

### 7.2 preview.html

- In Pascal, at the start of the process that sends all `opt` commands after receiving `ready` (`uCmdpreview.pas` lines 515-518), send `opt` `lang` `ja` (or `en`) (the value is `CXLangCode`). It arrives before `render` and `code`.
- `preview.html` has `state.lang` (initial value `'ja'`), a Japanese/English dictionary `I18N`, and a lookup function `t(key)`. When it receives `opt` `lang`, it changes `state.lang`.
- If `title` has never been received, `document.title` is set to `t('untitled')` when `opt` `lang` is received (the default name of the PDF when printing).
- If `opt` `lang` does not arrive, it works in Japanese as now.

| key | Japanese | English | Current location (line in preview.html) |
|---|---|---|---|
| `untitled` | 無題 | Untitled | 7, 816 |
| `extImg` | 外部画像は表示しません | External image not shown | 359, 562 (enclosed in `[` `]`; at 359, `: alt` follows if there is an alt) |
| `imgFail` | 画像を取得できませんでした | Could not fetch the image | 570 (enclosed in `[` `]`) |
| `mmLoadFail` | mermaid.js を読み込めません | Cannot load mermaid.js | 400 |
| `mmNotFound` | lib/mermaid.min.js が見つかりません | lib/mermaid.min.js not found | 401 |
| `mmDrawFail` | Mermaid の図を描けません: | Cannot draw the Mermaid diagram: | 550 (followed by a line break and the error message) |
| `tbPan` | 移動 | Pan | 490 |
| `tbZoomOut` | 縮小 | Zoom out | 491 |
| `tbZoomIn` | 拡大 | Zoom in | 492 |
| `tbFit` | 枠に合わせる | Fit to frame | 493 |

## 8. Out of Scope

| Item | Reason / handling |
|---|---|
| Names actually created on disk ("新しいフォルダー", "新しいフォルダー (n)", "新規テキスト ドキュメント", "新規テキスト ドキュメント (n)" in `CListView`) | Once created they remain even if the language is changed, and Japanese and English names would be mixed. They stay Japanese as now |
| IDE registration units (such as "ページの追加" in `uCPageControl_reg` and `uCSideBarReg`) | They belong to cxdsgn (design time). They stay Japanese as now |
| Windows and LCL standard dialogs (open/save file, `MessageDlg` buttons) | They follow the language of the OS and LCL |
| Full-width spaces and Japanese commas used as delimiters (`FLineDelimiters`) | Not shown on screen |
| Source comments, `.md` documents | Not shown on screen |
| Monaco's built-in display | Monaco's own language switching (7.1) |

## 9. Decisions

| Item | Decision |
|---|---|
| Unit of language | One for all of cx |
| Language values | `ja`, `en` |
| Setting | `Language` in `[CX]` of `WebView2.ini` |
| No setting / no ini | Windows display language (`ja` if Japanese, `en` otherwise) |
| When it is decided | At run time. Once, the first time a string is needed |
| Where strings are kept | One table in `uCXLang.pas`. Obtained with `CXT(ID)` |
| Japanese | The current strings are used as is |
| HTML | `editor.html` is not changed. `preview.html` uses `opt lang` and a dictionary |

**Not Made**

| Item | Reason / alternative |
|---|---|
| Per-component language property | One language for all of cx |
| Switching the language while running | The ini is read only once at startup |
| Languages other than Japanese and English | Only two |
| External dictionary files (such as `.po`) | There is one user and one maintainer. One table is enough |

## 10. Points to Check When Investigating Problems

| Symptom | Where to look |
|---|---|
| Japanese remains after switching to English | Whether the "Current location" entries in the chapter 5 table have been replaced with `CXT` |
| Still Japanese even with `Language=en` in the ini | The location of the ini (same as the EXE), the section name `[CX]`, the spelling of the value (2.1) |
| Only the Monaco display is Japanese | The value of `JapaneseUI` and `CXLanguage` (7.1) |
| Only the preview diagram buttons and errors are Japanese | Whether `opt lang` is sent before `render` (7.2) |
| On English Windows the list type stays "File folder" | The comparison in `CListView` (chapter 6) |
| Text is cut off in English | The width of the find/replace dialog (chapter 6) |
| The initial text of a component placed on a form in the IDE becomes English | The display language of the Windows the IDE runs on (there is no ini, so step 2 of 2.1 applies). Text saved to the .lfm at design time is in the language at that time |

## 11. Changes in This Version (1.0. New)

Steps for writing the code. Not included in the usage guide.

| No | File | Change |
|---|---|---|
| 1 | `uCXLang.pas` | New (chapters 3, 4, and 5) |
| 2 | `cx.lpk` | Add `../source/uCXLang.pas` (UnitName `uCXLang`) |
| 3 | `uCXRuntime.pas` | Add `uCXLang` to uses and replace the 2 error messages with `CXT` |
| 4 | Units listed in chapter 6 | Replace strings with `CXT` as in the chapter 5 table. Remove the definitions in the 4 `resourcestring` units |
| 5 | `uCmmonacoview.pas` | The `JapaneseUI` condition (7.1) |
| 6 | `uCmdpreview.pas` | Send `opt lang` (7.2) |
| 7 | `preview.html` | `I18N`, `t(key)`, and `lang` in `opt` (7.2) |
| 8 | `editor.html`, `cxdsgn.lpk`, IDE registration units | Unchanged |
