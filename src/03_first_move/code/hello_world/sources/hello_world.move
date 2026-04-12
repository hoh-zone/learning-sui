/// 与本书 3.1「Hello World」对应；Move 2024 单文件模块语法。
module hello_world::hello_world;

use std::string::String;

/// 返回 "Hello, World!" 字符串
public fun hello_world(): String {
    b"Hello, World!".to_string()
}
