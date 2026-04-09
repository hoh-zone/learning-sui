#!/usr/bin/env node
/**
 * 校验 theme/move-hljs.js 与 book/highlight.js（hljs 10.1.1）兼容。
 * 用法：node scripts/test-move-highlight.js
 */
const path = require('path');
const hljs = require(path.join(__dirname, '..', 'book', 'highlight.js'));
const { registerMoveLanguage } = require(path.join(__dirname, '..', 'theme', 'move-hljs.js'));

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

registerMoveLanguage(hljs);

var sample =
  '/// Sui example\n' +
  'module my_pkg::demo;\n' +
  'use sui::coin::{Self, Coin};\n' +
  'use std::string::String;\n' +
  'public struct Vault has key { id: UID }\n' +
  'public(package) fun take(_: &mut TxContext) {\n' +
  '    let c: Clock = clock::create_for_testing(ctx);\n' +
  '    assert!(true, 0);\n' +
  '}\n' +
  '#[test_only]\n' +
  'public native fun emit<T: copy + drop>(e: T);\n';

var out = hljs.highlight('move', sample, true).value;

assert(out.includes('hljs-keyword'), 'expected keyword spans');
assert(out.includes('hljs-built_in'), 'expected Sui framework / type spans');
assert(out.includes('hljs-meta'), 'expected attribute meta');
assert(out.includes('hljs-comment'), 'expected doc comment');

// 不应再依赖 Aptos prover 关键字表；普通标识符 "spec" 不应被整体标成 keyword（仍可为子串，此处只作弱检查）
var specOnly = hljs.highlight('move', 'let spec = 1u64;', true).value;
assert(!/hljs-keyword[^>]*>spec</.test(specOnly), 'word spec should not be highlighted as standalone keyword');

console.log('ok: move-hljs + highlight.js', hljs.versionString);
console.log(out.split('\n').slice(0, 4).join('\n') + '\n...');
