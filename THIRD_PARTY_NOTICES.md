# Third-party notices

The files in `runtime/` include the following third-party libraries. They are used by TCMonacoEditor at run time.
Each library is distributed under its own license. The full license texts are included in the locations listed below.

`runtime/` フォルダーには、次の外部ライブラリが入っています（TCMonacoEditor が実行時に使います）。
各ライブラリは、それぞれのライセンスで配布されています。ライセンスの全文は、下の場所に入っています。

| Library | Version | License | Files | License text | Source |
|---|---|---|---|---|---|
| Monaco Editor | 0.52.2 | MIT | runtime/monaco/vs/ | runtime/monaco/LICENSE.txt, runtime/monaco/ThirdPartyNotices.txt | https://github.com/microsoft/monaco-editor |
| marked | 18.0.13 | MIT | runtime/preview/lib/marked.umd.js | runtime/preview/lib/licenses/marked-LICENSE.txt | https://github.com/markedjs/marked |
| DOMPurify | 3.4.15 | Apache-2.0 (dual licensed under Apache-2.0 or MPL-2.0; used under Apache-2.0) | runtime/preview/lib/purify.min.js | runtime/preview/lib/licenses/DOMPurify-LICENSE-Apache-2.0.txt, runtime/preview/lib/licenses/DOMPurify-LICENSE-MPL-2.0.txt | https://github.com/cure53/DOMPurify |
| highlight.js | 11.12.0 | BSD-3-Clause | runtime/preview/lib/highlight.min.js, runtime/preview/lib/languages/, runtime/preview/lib/github.min.css, runtime/preview/lib/github-dark.min.css | runtime/preview/lib/licenses/highlightjs-LICENSE.txt | https://github.com/highlightjs/highlight.js |
| github-markdown-css | 5.9.0 | MIT | runtime/preview/lib/github-markdown-light.css, runtime/preview/lib/github-markdown-dark.css | runtime/preview/lib/licenses/github-markdown-css-LICENSE.txt | https://github.com/sindresorhus/github-markdown-css |
| Mermaid | 12.1.0 | MIT | runtime/preview/lib/mermaid.min.js | runtime/preview/lib/licenses/mermaid-LICENSE.txt | https://github.com/mermaid-js/mermaid |

The files of these libraries are included unchanged, as distributed in their npm packages
(monaco-editor, marked, dompurify, @highlightjs/cdn-assets, github-markdown-css, mermaid).

これらのライブラリのファイルは、npm で配布されているもの（monaco-editor、marked、dompurify、@highlightjs/cdn-assets、github-markdown-css、mermaid）を変更せずに入れています。

The other files in this repository (including runtime/monaco/editor.html and runtime/preview/preview.html) are licensed under the [MIT License](LICENSE) by aotan083.

このリポジトリのほかのファイル（runtime/monaco/editor.html・runtime/preview/preview.html を含む）は、aotan083 の [MIT License](LICENSE) です。
