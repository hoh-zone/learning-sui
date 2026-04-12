# 第十五章 · 实战练习

## 实战一：ptb-demo 跑通

1. 进入 `src/15_client/code/ptb-demo/`。
2. `npm install && npm run check && npm run demo`。
3. 设置 `export SUI_PT_DEMO_ADDRESS=<测试网有余额的地址>` 再运行，观察是否完成 `build({ client })`。
4. **验收**：无地址时打印链 id；有地址时若有余额应打出序列化字节长度。

## 实战二：读自己的对象列表

1. 用 `@mysten/sui/jsonRpc` 或 gRPC 客户端，调用 `getOwnedObjects`（或当前 SDK 等价 API），分页拉取**至少**一页。
2. 打印第一个对象的 `objectId` 与 `type`。
3. **验收**：脚本可重复运行。

## 实战三：动态字段查询

1. 任选一个带动态字段的链上对象（本书第十章动态字段示例或自建）。
2. 使用客户端 `getDynamicFields` + `getDynamicFieldObject`（名称以当前 SDK 为准）。
3. **验收**：能拿到至少一条子字段的 name/value 摘要。
