/// 与第四章「包 / 地址 / 账户」概念呼应的最小可编译示例（无链上 init 副作用）。
module concepts_demo::demo;

/// 仅占位类型，演示「命名地址 + 模块」在包内的组织方式。
public struct PackageMarker has drop {}
