# 第十一章实战 · Witness 草图（参考答案）

```move
module my_pkg::treasury {
    public struct WITNESS has drop {}

    public(package) fun new_witness(): WITNESS {
        WITNESS {}
    }
    // 仅 friend 或同包模块可在受控路径调用 `new_witness`，
    // 再一次性交给 `init_currency`，避免用户随意铸币。
}
```

- **`WITNESS` 仅 `drop`**：不可存储，防止链上长期伪造。
- **`public(package)`** 或 **`friend`**：限制谁能构造 witness，避免模块外 `WITNESS {}` 结构体字面量（若语言允许则需封进 `public(package)` 函数）。
