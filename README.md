# CX Components

A set of components for Lazarus (Free Pascal). Drop them on a form to get Explorer-style file handling, a tabbed browser, a Monaco editor, bookmark management and more.

Author: aotan083 / License: MIT

## Components

| Component | Description | Manual (Japanese) | Design (Japanese) |
|---|---|---|---|
| TCTreeView | Folder tree that works like the left pane of Windows Explorer | [Usage](docs/TCTreeView_Usage.md) | [Design](docs/TCTreeView_Design.md) |
| TCListView | File list that works like the right pane of Windows Explorer | [Usage](docs/TCListView_Usage.md) | [Design](docs/TCListView_Design.md) |
| TCSynEdit | TSynEdit with file loading/saving, encodings, color styles and a context menu | [Usage](docs/TCSynEdit_Usage.md) | [Design](docs/TCSynEdit_Design.md) |
| TCCheckListBox | TCheckListBox that can be limited to a single check | [Usage](docs/TCCheckListBox_Usage.md) | [Design](docs/TCCheckListBox_Design.md) |
| TCGroupBox / TCCheckGroupBox | Group box whose child controls never disappear, and a group box with a check box in its caption | [Usage](docs/TCGroupBox_Usage.md) | [Design](docs/TCGroupBox_Design.md) |
| TCSideBar | Edge-style icon bar with a collapsible panel | [Usage](docs/TCSideBar_Usage.md) | [Design](docs/TCSideBar_Design.md) |
| TCPageControl / TCTitleBar | Browser-style tabs, and a title bar that can host the tabs | [Usage](docs/TCPageControl_Usage.md) | [Design](docs/TCPageControl_Design.md) |
| TCTabBrowser | Tabbed web browser based on WebView2 | [Usage](docs/TCTabBrowser_Usage.md) | [Design](docs/TCTabBrowser_Design.md) |
| TCMonacoEditor / TCMFindDialog | Editor based on WebView2 and Monaco Editor (tabs, preview, search and printing built in), plus 25 standard actions | [Usage](docs/TCMonacoEditor_Usage.md) | [Design](docs/TCMonacoEditor_Design.md) |
| TCBookmark | Firefox-style bookmark manager (opens items in TCTabBrowser / TCMonacoEditor) | [Usage](docs/TCBookmark_Usage.md) | [Design](docs/TCBookmark_Design.md) |

All components appear on the [CX] palette page. The manuals and design documents are written in Japanese.

## Requirements

| Item | Version |
|---|---|
| Lazarus | 4.8 / 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11 (64-bit) |

## Folders

| Folder | Contents |
|---|---|
| `packages` | `cx.lpk` (run-time package: all components) and `cxdsgn.lpk` (design-time package: palette registration and icons) |
| `source` | Component sources (run-time) |
| `source\design` | Design-time sources (palette registration, component editors) |
| `source\res` | Palette icons (.lrs) |
| `docs` | Manual (`*_Usage.md`) and design document (`*_Design.md`) for each component |
| `runtime` | Files used at run time by the WebView2 components (`monaco`, `preview`) |
| `demo` | Sample programs |

## Installation

1. Install these packages into Lazarus first:
   - WebView4Delphi Lazarus package (https://github.com/salvadordf/WebView4Delphi)
   - ATFlatControls (`atflatcontrols_package`, from the Online Package Manager)
   - SynEdit is included with Lazarus
2. Open `packages\cx.lpk` and click "Compile".
3. Open `packages\cxdsgn.lpk` and click "Install" (the IDE is rebuilt).
4. After the restart, the components appear on the [CX] palette page.

## Using the components in an application

- When you drop a component on a form, `cx` is added to the project's required packages automatically (`cxdsgn` is not needed by applications).
- Nothing needs to be added to the .lpr file.

Applications that use TCTabBrowser, TCMonacoEditor or TCBookmark need these files in the EXE folder:

| File | Description |
|---|---|
| `WebView2.ini` | Required. The values may be empty (empty means the default location in the EXE folder) |
| `WebView2Loader.dll` | 64-bit version, from the WebView4Delphi repository |
| `monaco\` | Editor files for TCMonacoEditor (`runtime\monaco`; `vs` is `min\vs` of the npm package `monaco-editor`) |
| `preview\` | Preview files for TCMonacoEditor (`runtime\preview`) |

```ini
[WebView2]
LoaderDllPath=
UserDataFolder=
MonacoFolder=
PreviewFolder=
```

| Key | Meaning | When empty |
|---|---|---|
| `LoaderDllPath` | WebView2Loader.dll file | WebView2Loader.dll in the EXE folder |
| `UserDataFolder` | WebView2 user data folder | WebView2Data in the EXE folder |
| `MonacoFolder` | Folder containing `editor.html` and `vs` | monaco in the EXE folder |
| `PreviewFolder` | Folder containing `preview.html` and `lib` | preview in the EXE folder |

- Relative paths are relative to the EXE folder. Several applications can share one `monaco` / `preview` folder.
- The Microsoft Edge WebView2 Runtime is required (it is preinstalled on Windows 11).

## License

MIT License (see [LICENSE](LICENSE)). Licenses of third-party libraries are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
