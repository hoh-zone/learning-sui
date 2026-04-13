/// 第十七章：可升级包中的版本常量（发布后在测试网用 `sui client upgrade` 迭代）。
module ch17_upgrade_lab::version;

const SCHEMA_VERSION: u64 = 1;

public fun schema_version(): u64 {
    SCHEMA_VERSION
}

public fun bump_hint(): u64 {
    SCHEMA_VERSION + 1
}
