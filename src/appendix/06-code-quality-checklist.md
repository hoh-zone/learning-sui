# 代码质量检查清单

本附录提供一份全面的代码质量检查清单，用于在发布 Move 合约前系统性地审查代码。

## 包配置

- [ ] 使用 `edition = "2024"` 或更新
- [ ] 移除了不必要的显式框架依赖（Sui 1.45+）
- [ ] 命名地址有项目前缀，避免冲突
- [ ] `Move.toml` 中没有硬编码的非零地址（应使用 `"0x0"`）

## 模块结构

- [ ] 使用模块标签语法（不用大括号包裹）
- [ ] `use` 语句合理分组，使用 `{Self, Member}` 合并导入
- [ ] 没有多余的 `{Self}` 单独导入
- [ ] 模块内代码组织清晰：常量 → 结构体 → init → 公共函数 → 包可见函数 → 私有函数

## 命名规范

- [ ] 错误常量使用 `EPascalCase`（如 `ENotAuthorized`）
- [ ] 普通常量使用 `ALL_CAPS`（如 `MAX_SUPPLY`）
- [ ] Capability 类型以 `Cap` 结尾（如 `AdminCap`）
- [ ] 事件类型使用过去时（如 `HeroCreated`，不是 `CreateHero`）
- [ ] 动态字段键使用 `Key` 后缀和位置结构体
- [ ] Hot Potato 类型名称不包含 "Potato"
- [ ] 访问器函数直接用字段名，不加 `get_` 前缀
- [ ] 可变访问器加 `_mut` 后缀

## 函数设计

- [ ] 没有 `public entry` 函数（使用 `public` 或 `entry`）
- [ ] 公共函数设计为可组合（返回对象而非内部 transfer）
- [ ] 参数顺序：对象 → Capability → 值 → Clock → ctx
- [ ] Capability 作为第二个参数（对象之后）
- [ ] `public` 函数签名已确认不再变动（升级后不可改）
- [ ] 需要冻结的便捷函数使用 `entry`（不是 `public`）

## 现代语法

- [ ] 使用 `b"...".to_string()` 而非 `utf8(b"...")`
- [ ] 使用 `id.delete()` 而非 `object::delete(id)`
- [ ] 使用 `ctx.sender()` 而非 `tx_context::sender(ctx)`
- [ ] 使用 vector 字面量 `vector[1, 2, 3]`
- [ ] 使用方法语法 `v.length()` 而非 `vector::length(&v)`
- [ ] 使用索引语法 `v[0]` 而非 `vector::borrow(&v, 0)`
- [ ] 使用集合索引 `&map[&key]` 而非 `map.get(&key)`
- [ ] Coin 操作使用链式调用

## 宏使用

- [ ] 使用 `opt.do!(|v| ...)` 而非 if-is_some-extract
- [ ] 使用 `opt.destroy_or!(default)` 处理默认值
- [ ] 使用 `n.do!(|_| ...)` 而非 while 循环计数
- [ ] 使用 `vec.do_ref!(|e| ...)` 遍历 vector
- [ ] 使用 `vec.destroy!(|e| ...)` 消费 vector
- [ ] 使用 `vec.fold!(init, |acc, v| ...)` 折叠
- [ ] 使用 `vec.filter!(|e| ...)` 过滤
- [ ] 使用 `vector::tabulate!(n, |i| ...)` 生成 vector

## 解构

- [ ] 使用 `let Struct { field, .. } = value;` 忽略不需要的字段
- [ ] 不使用 `field_1: _, field_2: _` 逐个忽略

## 安全检查

- [ ] 所有特权操作有权限控制（Capability / ACL / 签名验证）
- [ ] Capability 绑定了 Referent ID
- [ ] Hot Potato 绑定到特定对象
- [ ] 所有用户输入经过验证（范围、长度、类型）
- [ ] 整数运算有溢出检查
- [ ] 除法前检查分母非零
- [ ] 共享对象有版本控制
- [ ] `seal_approve*` 函数是 `entry`（非 `public`），支持升级
- [ ] 无硬编码的测试密钥或地址
- [ ] 错误码唯一且有描述性

## 升级准备

- [ ] `public` 函数签名稳定，不会在未来变更
- [ ] 共享对象包含 `version` 字段
- [ ] 有 `migrate` 函数用于版本升级
- [ ] `init` 中不包含升级后需要重新执行的逻辑
- [ ] 使用动态字段存储可变配置
- [ ] UpgradeCap 安全存储（考虑多签）
- [ ] 确定升级策略（compatible / additive / immutable）

## 测试

- [ ] 所有核心功能有单元测试
- [ ] 测试覆盖正常路径和错误路径
- [ ] 使用 `#[test, expected_failure(abort_code = ...)]` 测试错误
- [ ] expected_failure 测试不做不必要的清理
- [ ] 使用 `assert_eq!` 而非 `assert!(a == b, 0)`
- [ ] 测试中不使用 abort code 参数的 `assert!`
- [ ] 使用 `tx_context::dummy()` 而非不必要的 TestScenario
- [ ] 使用 `sui::test_utils::destroy` 清理测试对象
- [ ] 测试模块中函数名不加 `test_` 前缀

## 注释

- [ ] 文档注释使用 `///`（不是 `/** */`）
- [ ] 复杂逻辑有解释性注释
- [ ] 没有多余的显而易见的注释
- [ ] TODO 和已知问题有注释标记

## 协议限制

- [ ] 单笔交易创建的对象不超过 2048 个
- [ ] 单个对象大小不超过 256KB
- [ ] 单笔交易访问的动态字段不超过 1000 个
- [ ] 单笔交易发射的事件不超过 1024 个
- [ ] 大集合使用 `Table` 而非 `vector`
- [ ] 批量操作分批处理

## 前端集成

- [ ] 合约暴露了前端需要的所有查询函数
- [ ] 事件结构清晰，便于索引和展示
- [ ] Display 标准已配置（如适用）
- [ ] 错误码有对应的前端错误消息

## 工具使用

- [ ] 使用 Move Formatter 格式化代码
- [ ] CI 中集成了格式化检查
- [ ] 使用 `sui move test` 运行完整测试套件
- [ ] 在 testnet 上完成集成测试

## 小结

这份检查清单涵盖了从代码风格到安全性的各个方面。建议在以下时机使用：

1. **代码审查前**：自查代码是否符合规范
2. **发布前**：系统性检查所有安全和兼容性要求
3. **升级前**：确认升级兼容性和迁移逻辑
4. **团队新人入职**：作为编码标准的参考文档
