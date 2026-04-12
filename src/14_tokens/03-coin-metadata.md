# Coin 元数据与 MetadataCap

## 导读

链上展示用的 **名称、符号、精度、图标** 存在 **`CoinMetadata`-系与 `Currency<T>`** 模型中（随 Framework 版本演进，以源码为准）。**`MetadataCap<T>`** 持有者可在规则允许下 **更新** 描述类字段。本节与 [§14.2](02-registry-otw.md) 的 `finalize` 返回值衔接。

- **前置**：[§14.2](02-registry-otw.md)  
- **后续**：[§14.4 · Treasury](04-treasury.md)  

---

## 精度 decimals

- **9**：与 SUI 类似，1 单位 = \(10^9\) 最小单位。  
- **6**：常见于法币锚定表述。  
- **0**：不可分割积分。

精度只影响**展示与乘除直觉**，不改变 `u64` 链上实际存储的是「最小单位整数」。

## 读取元数据（概念）

通过 **`CoinRegistry`** 解析 **`Currency<T>`** 后，使用 **`coin_registry`** 提供的只读 accessor（如 `decimals`、`name`、`symbol` 等，以当前 API 为准）供钱包与索引器展示。

```move
// 伪代码：读取逻辑依赖当前 coin_registry 公开函数名
// let reg = ...; // 取得 CoinRegistry 引用
// let d = coin_registry::decimals<T>(&reg);
```

## 更新元数据（示意）

持有 **`MetadataCap<T>`** 时，可调用 **`coin_registry::set_name` / `set_description` / `set_icon_url`** 等（函数名以源码为准），常用于**换官网、改描述**而不动供应逻辑。

## RegulatedCoinMetadata（受监管）

若币种为 **regulated**，链上可能另有 **`RegulatedCoinMetadata<T>`** 记录 **`DenyCap`** 关联信息，便于展示「受监管」标签——与 [§14.8](08-regulated-denylist.md) 配合理解。

## 小结

**元数据**面向人读；**供应与余额**面向验证。**`MetadataCap`** 与 **`TreasuryCap`** 权限分离，有利于把「运营文案」与「铸销权」交给不同多签。下一节讲 **Treasury 与供应策略**。
