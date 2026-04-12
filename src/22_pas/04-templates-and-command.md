# Templates 与 Command：SDK 如何解析转账

## Templates 与 PTB 接口速查

| 模块 | 函数 / 类型 | 说明 |
|------|-------------|------|
| `pas::templates` | `Templates`, `setup(namespace)` | 创建并共享 Templates（entry） |
| `pas::templates` | `set_template_command<A>(templates, permit, command)`, `unset_template_command<A>(templates, permit)` | 按审批类型 A 注册/移除 PTB Command |
| `ptb::ptb` | `move_call(package_id, module, function, arguments, type_arguments): Command` | 构造一次 Move 调用的 Command |
| `ptb::ptb` | `ext_input(name): Argument` | 占位参数，由链下解析为「request」等，name 如 `"pas:request"` |
| `ptb::ptb` | `object_by_id(id): Argument` | 按对象 ID 的占位，链下解析时填入实际对象 |
| `ptb::ptb` | `clock()`, `random()`, `display()` | 常用系统对象（0x6 Clock、0x8 Random、0xD DisplayRegistry） |

## 为什么需要 Templates

PAS 的解析逻辑在**发行方自己的包**里（例如 `approve_transfer`），钱包和 SDK 无法硬编码每个发行方的入口。因此 PAS 引入 **Templates**：发行方在链上为每种**审批类型**注册一个 **Command**（PTB 指令描述），SDK 只需根据「当前 Request 类型 + Policy 要求的审批类型」从 Templates 中取出对应 Command，即可构造「解析这一步」的 PTB，而无需理解具体 Move 逻辑。

## Templates 与 Command 的关系

- **Templates** 是一个共享对象，由 Namespace 派生，内部用动态字段存储 `TypeName -> Command` 的映射。
- **Command** 来自 `ptb::ptb` 模块，描述「如何调用某包的某函数、传哪些参数」；例如：`ptb::move_call(package_id, module_name, "approve_transfer", [request_arg, clock_arg], type_args)`。
- 发行方在 `setup`（或后续更新）中调用 `templates::set_template_command(templates, permit, command)`，将「某审批类型 A」与「用于收集 A 的 PTB Command」绑定；**Permit\<A\>** 由审批类型 A 的**定义包**提供（如 `internal::permit<TransferApproval>()`），证明调用方有权为该类型注册模板。

### set_template_command 签名

```move
public fun set_template_command<A: drop>(
    templates: &mut Templates,
    _: internal::Permit<A>,
    command: Command,
)
```

键为 `type_name::with_defining_ids<A>()`，即审批类型 A 的 TypeName；SDK 根据 Policy 的 required_approvals 查到类型名，再在 Templates 中取对应 Command。

这样，当 SDK 看到「需要 TransferApproval 才能 resolve SendFunds」时，可查询 Templates 中 `TransferApproval` 对应的 Command，把当前 Request 和所需对象 ID 填入，得到解析用的 PTB 片段。

## 发行方如何设置 Command

在发行方包的 `setup` 中（示例见 [demo_usd](https://github.com/MystenLabs/pas/blob/main/packages/testing/demo_usd/sources/demo_usd.move)）：

1. 用 `policy::new_for_currency` 创建 Policy 与 PolicyCap，并 `policy::set_required_approval<_, TransferApproval>(&cap, "send_funds")`。
2. 构造 Command：  
   - **package_id**：`type_name::with_defining_ids<DEMO_USD>().address_string().to_string()`（即本包地址字符串）。  
   - **arguments**：`vector[ptb::ext_input("pas:request"), ptb::object_by_id(clock_id)]`，其中 `"pas:request"` 表示链下解析时填入当前 PTB 中的 Request 对象；Clock 可用 `ptb::clock()` 或具体 ID。  
   - **type_arguments**：若解析函数泛型参数为代币类型，传 `vector[(*type_name.as_string()).to_string()]`。  
   ```move
   let cmd = ptb::move_call(
       type_name::with_defining_ids<DEMO_USD>().address_string().to_string(),
       "demo_usd",
       "approve_transfer",
       vector[ptb::ext_input("pas:request"), ptb::object_by_id(@0x6.to_id())],
       vector[(*type_name.as_string()).to_string()],
   );
   ```
3. 调用 `templates::set_template_command(templates, internal::permit<TransferApproval>(), cmd)`。

之后，任何客户端只要知道「SendFunds 需要 TransferApproval」，就可以从 Templates 读取该 TypeName 对应的 Command，把 `ext_input("pas:request")` 等替换成当前交易的 Request 与对象，组装出完整的 resolve PTB。

## 小结

- **Templates** 存的是「审批类型 → PTB Command」的映射，供 SDK 自动构造解析交易。
- 发行方在 **setup** 时用 **set_template_command** 注册自己包的解析入口（如 `approve_transfer`），实现「可发现、可自动化」的合规解析。
