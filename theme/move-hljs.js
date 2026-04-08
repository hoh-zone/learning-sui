/**
 * Sui Move 2024 语法高亮（Highlight.js 10，与 mdBook 内置版本兼容）。
 *
 * 与 Aptos / 旧版 Move 高亮习惯的区别：
 * - 不包含 Move Prover / Aptos 规范语言关键字（spec、schema、invariant、ensures、requires）。
 * - 面向 Sui：常见框架模块路径（sui::、transfer:: 等）与链上常用类型（UID、TxContext 等）单独着色。
 * - 保留 `native`（Sui 标准库中仍有 `public native fun` 等声明）。
 *
 * 在 mdBook 首次高亮之后，对 ```move 代码块用本规则重新渲染。
 */
function registerMoveLanguage(hljs) {
  hljs.registerLanguage('move', function (hljs) {
    // 常见 Sui 框架根模块（:: 前一段）
    var SUI_ROOT =
      /\b(?:sui|std|move_stdlib|sui_system|deepbook|bridge|kiosk|token|table|bag|vec_map|vec_set|linked_table|object|transfer|coin|balance|tx_context|event|clock|random|bcs|dynamic_field|dynamic_object_field|url|display|package|zklogin|versioned|deny_list)::/;
    // 文档与示例中高频出现的 Sui / std 类型名
    var SUI_TYPES =
      /\b(?:UID|ID|TxContext|Clock|Random|RNG|Option|TypeName|String|Url|VecMap|VecSet|Receiving|Table|Bag|Kiosk|Balance|Coin|Object|SUI)\b/;

    return {
      name: 'Move',
      aliases: ['move'],
      // Move 2024 / Sui：无 Aptos prover 关键字
      keywords:
        'module public struct enum fun native use const let mut return if else while loop match break continue ' +
        'abort as has copy drop key store assert entry friend package phantom Self true false ' +
        'vector address bool u8 u16 u32 u64 u128 u256 signer type macro',
      contains: [
        {
          className: 'keyword',
          begin: /\bpublic\s*\(\s*package\s*\)/,
          relevance: 5,
        },
        hljs.C_LINE_COMMENT_MODE,
        hljs.C_BLOCK_COMMENT_MODE,
        {
          className: 'string',
          begin: /b"/,
          end: /"/,
          contains: [{ begin: /\\./ }],
        },
        {
          className: 'string',
          begin: /"/,
          end: /"/,
          contains: [{ begin: /\\./ }],
          relevance: 0,
        },
        {
          className: 'built_in',
          begin: SUI_ROOT,
          relevance: 3,
        },
        {
          className: 'built_in',
          begin: SUI_TYPES,
          relevance: 2,
        },
        {
          className: 'number',
          begin:
            /\b0x[0-9a-fA-F][0-9a-fA-F_]*\b|\b[0-9][0-9_]*(u8|u16|u32|u64|u128|u256)?\b/,
        },
        {
          className: 'meta',
          begin: /#\[/,
          end: /\]/,
          relevance: 5,
        },
      ],
    };
  });
}

function rehighlightMoveBlocks() {
  if (typeof hljs === 'undefined') return;
  registerMoveLanguage(hljs);
  document.querySelectorAll('pre code.language-move').forEach(function (el) {
    try {
      var text = el.textContent;
      var result = hljs.highlight('move', text, true);
      el.innerHTML = result.value;
      el.classList.add('hljs');
    } catch (e) {
      console.warn('Move highlight failed', e);
    }
  });
}

if (typeof document !== 'undefined') {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', rehighlightMoveBlocks);
  } else {
    rehighlightMoveBlocks();
  }
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { registerMoveLanguage };
}
