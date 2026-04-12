# 术语表

本附录收录 Move 和 Sui 生态系统中的核心术语，提供中英文对照和简要解释。

## A

| 术语 | 英文 | 解释 |
|------|------|------|
| 能力 | Ability | Move 类型系统中的属性标记，包括 `key`、`store`、`copy`、`drop` 四种 |
| 访问控制列表 | Access Control List (ACL) | 维护授权地址列表的权限管理模式 |
| 地址 | Address | Sui 上的 32 字节标识符，用于标识账户和对象 |
| 证明文档 | Attestation Document | TEE 签发的密码学证明，证明 enclave 运行的代码和状态 |

## B

| 术语 | 英文 | 解释 |
|------|------|------|
| Bag | Bag | 异构动态集合，可以存储不同类型的键值对 |
| BCS | Binary Canonical Serialization | Sui 使用的标准二进制序列化格式 |
| Borrow 模式 | Borrow Pattern | 使用 Hot Potato 实现的安全借用模式 |

## C

| 术语 | 英文 | 解释 |
|------|------|------|
| 能力凭证 | Capability (Cap) | 代表特权的对象，持有者可执行受保护操作 |
| Checkpoint | Checkpoint | Sui 网络确认的一批交易 |
| Clever Errors | Clever Errors | Sui 对中止信息的呈现方式：推荐用 `#[error]` 标注错误常量（通常为 `vector<u8>` 消息），CLI/GraphQL 等可解码为人类可读说明 |
| 时钟 | Clock | Sui 的系统时钟对象（地址 `0x6`），提供链上时间 |
| 币 | Coin | Sui 上的同质化代币类型 `Coin<T>` |
| 兼容性 | Compatibility | 包升级必须遵守的向后兼容规则 |
| 可组合性 | Composability | 函数设计为可在 PTB 中与其他函数组合调用 |
| 共识 | Consensus | 验证者就交易顺序和结果达成一致的过程 |
| copy 能力 | copy Ability | 允许值被复制的能力，与 `key` 互斥 |

## D

| 术语 | 英文 | 解释 |
|------|------|------|
| DeepBook | DeepBook | Sui 上的去中心化链上订单簿 |
| 拒绝列表 | DenyList | 系统对象（`0x403`），用于代币冻结 |
| 动态字段 | Dynamic Field | 运行时添加到对象的键值对，不计入对象大小限制 |
| 动态对象字段 | Dynamic Object Field | 值是对象的动态字段，保留独立的对象 ID |
| drop 能力 | drop Ability | 允许值被丢弃/忽略的能力，与 `key` 互斥 |
| Dry Run | Dry Run | 模拟交易执行而不实际上链，不消耗 gas |

## E

| 术语 | 英文 | 解释 |
|------|------|------|
| 纪元 | Epoch | Sui 网络的时间周期（约 24 小时），影响质押奖励和验证者变更 |
| 事件 | Event | 交易执行期间发射的数据，用于链下索引和通知 |
| 入口函数 | Entry Function | 可以作为交易入口点直接调用的函数 |
| 纠删码 | Erasure Coding | Walrus 使用的数据编码技术，提供冗余和可恢复性 |
| 临时密钥 | Ephemeral Key | ZKLogin 中使用的短期密钥对 |

## F

| 术语 | 英文 | 解释 |
|------|------|------|
| 快速路径 | Fast Path | 不涉及共享对象的交易可以跳过共识，快速执行 |
| 闪电贷 | Flash Loan | 在同一笔交易内借入和归还的即时贷款，利用 Hot Potato 保证归还 |
| 冻结对象 | Frozen Object | 不可变对象，只能通过不可变引用访问 |
| 全节点 | Full Node | 存储完整链状态、提供 RPC 服务但不参与共识的节点 |
| 框架 | Framework | Sui 核心库（`0x2`），提供 `object`、`transfer` 等基础模块 |

## G

| 术语 | 英文 | 解释 |
|------|------|------|
| Gas | Gas | 交易执行消耗的计算资源单位 |
| 泛型 | Generics | Move 的参数化类型系统，允许编写适用于多种类型的代码 |
| GraphQL | GraphQL | Sui 提供的灵活查询 API |
| gRPC | gRPC | Sui 的高性能远程过程调用协议，支持事件流 |

## H

| 术语 | 英文 | 解释 |
|------|------|------|
| Hot Potato | Hot Potato | 没有任何能力的结构体，必须在创建它的交易中被消费 |

## I

| 术语 | 英文 | 解释 |
|------|------|------|
| 不可变对象 | Immutable Object | 永远不能被修改的对象 |
| 索引器 | Indexer | 监听链上事件并存储到数据库的服务 |
| 初始化函数 | init Function | 包发布时自动调用一次的函数 |
| 内部类型 | Internal Type | 模块内定义的类型，字段不可从外部访问 |
| IBE | Identity-Based Encryption | 基于身份的加密，Seal 使用的核心密码学原语 |

## K

| 术语 | 英文 | 解释 |
|------|------|------|
| key 能力 | key Ability | 标记对象的能力，要求第一个字段为 `id: UID` |
| 密钥服务器 | Key Server | Seal 中持有 IBE 主密钥并派生解密密钥的链下服务 |
| Kiosk | Kiosk | Sui 的去中心化商店模式，支持交易策略和版税 |

## M

| 术语 | 英文 | 解释 |
|------|------|------|
| 主网 | Mainnet | Sui 的生产网络 |
| Move | Move | Sui 使用的智能合约编程语言 |
| 模块 | Module | Move 代码的组织单元，包含类型、函数和常量 |
| 多签 | Multisig | 多重签名，多个密钥共同控制一个地址 |
| 可变引用 | Mutable Reference (&mut) | 允许修改被引用值的引用 |

## N

| 术语 | 英文 | 解释 |
|------|------|------|
| Nautilus | Nautilus | 基于 TEE 的可验证链下计算框架 |
| NFT | Non-Fungible Token | 非同质化代币，Sui 上表现为具有 `key` 能力的对象 |

## O

| 术语 | 英文 | 解释 |
|------|------|------|
| 对象 | Object | Sui 的基本存储单元，具有全局唯一 ID |
| 对象 ID | Object ID | 对象的唯一标识符（32 字节地址） |
| 一次性见证 | One-Time Witness (OTW) | 只在 `init` 函数中创建一次的特殊类型，用于初始化 |
| Owned Object | Owned Object | 归特定地址所有的对象 |

## P

| 术语 | 英文 | 解释 |
|------|------|------|
| 包 | Package | Move 代码的部署单元，包含一个或多个模块 |
| 并行执行 | Parallel Execution | Sui 运行时并行执行交易的能力 |
| PCR | Platform Configuration Register | 标识 enclave 代码和配置的 SHA-384 哈希值 |
| PTB | Programmable Transaction Block | 可编程交易块，一笔交易中组合多个操作 |
| 幻影类型参数 | Phantom Type Parameter | 不在结构体字段中使用的类型参数，用于类型标记 |
| Publisher | Publisher | 证明包发布权的对象，通过 OTW 创建 |

## R

| 术语 | 英文 | 解释 |
|------|------|------|
| 随机数 | Random | 系统随机数对象（地址 `0x8`） |
| 引用 ID | Referent ID | 将 Capability 绑定到特定共享对象的 ID |
| RPC | Remote Procedure Call | 远程过程调用，用于与 Sui 节点通信 |

## S

| 术语 | 英文 | 解释 |
|------|------|------|
| Seal | Seal | 去中心化密钥管理服务 |
| 会话密钥 | Session Key | Seal 中的短期授权，允许 dApp 在有效期内获取解密密钥 |
| 共享对象 | Shared Object | 任何人都可以访问的对象，需要共识排序 |
| 标准库 | Standard Library | Move 标准库（`0x1`），提供基础类型和工具 |
| store 能力 | store Ability | 允许值被存储在其他对象中的能力 |
| 结构体 | Struct | Move 的自定义类型定义 |

## T

| 术语 | 英文 | 解释 |
|------|------|------|
| Table | Table | 同构动态键值集合，条目存储为动态字段 |
| TEE | Trusted Execution Environment | 可信执行环境，提供硬件级代码隔离 |
| 测试网 | Testnet | Sui 的测试网络 |
| Transfer | Transfer | 将对象所有权转移到指定地址的操作 |
| 阈值加密 | Threshold Encryption | Seal 中使用的 t-of-n 加密方案 |
| 交易摘要 | Transaction Digest | 交易的唯一标识哈希 |

## U

| 术语 | 英文 | 解释 |
|------|------|------|
| UID | Unique Identifier | 对象的唯一标识符类型，每个 `key` 对象的必需首字段 |
| UpgradeCap | Upgrade Capability | 包升级的权限凭证 |

## V

| 术语 | 英文 | 解释 |
|------|------|------|
| 验证者 | Validator | 参与共识的 Sui 网络节点 |
| VecMap | VecMap | 基于 Vector 的有序映射 |
| VecSet | VecSet | 基于 Vector 的有序集合 |
| 版本化共享对象 | Versioned Shared Object | 包含版本字段的共享对象，用于控制升级后的访问 |

## W

| 术语 | 英文 | 解释 |
|------|------|------|
| Walrus | Walrus | Sui 生态的去中心化存储协议 |
| 见证模式 | Witness Pattern | 使用类型实例作为权限证明的设计模式 |
| 封装对象 | Wrapped Object | 存储在另一个对象字段中的对象 |

## Z

| 术语 | 英文 | 解释 |
|------|------|------|
| ZKLogin | ZKLogin | 基于零知识证明的 OAuth 登录机制 |
| 零知识证明 | Zero-Knowledge Proof (ZKP) | 在不泄露信息的情况下证明某个陈述为真的密码学技术 |

## 小结

本术语表涵盖了 Move 和 Sui 开发中最常用的概念。随着 Sui 生态的发展，新的术语会不断出现。建议将本表作为快速参考，结合具体章节深入理解每个概念。
