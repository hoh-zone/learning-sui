/// 与本书 3.1「Hello World」对应：除字符串外，再创建一个可上链的 `Hello` 对象并转移给交易发送者。
module hello_world::hello_world;

use std::string::String;

/// 链上可拥有的问候对象；发布后调用 `mint_hello` 可在钱包 / 浏览器中看到。
public struct Hello has key, store {
    id: object::UID,
    greeting: String,
}

public fun greeting(hello: &Hello): &String {
    &hello.greeting
}

/// 构造 `Hello`（供测试或其它模块组合使用）。
public fun new_hello(ctx: &mut TxContext): Hello {
    Hello {
        id: object::new(ctx),
        greeting: b"Hello, World!".to_string(),
    }
}

/// 铸造 `Hello` 并转移给当前交易发送者（链上会产生新对象 ID，可在 `sui client object` 中查看）。
entry fun mint_hello(ctx: &mut TxContext) {
    let hello = new_hello(ctx);
    transfer::public_transfer(hello, ctx.sender());
}
