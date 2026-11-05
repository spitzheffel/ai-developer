> 痛点日志(pain log)。写给自己：被 AI 坑了当场记一条；阶段8 沉淀整理规则时从这里出发。全库规则的唯一来源。

# 痛点日志

## 用法

1. 被 AI 坑 → 当场记一条（一分钟写完），现象必须具体到「AI 做了什么 vs 期望什么」。
2. 攒几条或每周整理时，逐条过三连筛归类：工具可挡 / 缺上下文 / 真规则；是自己提示词的问题就归「表达不清」。
3. 归位到对应文件或配置后，填处置、把状态改「已落地」；维护与修剪规则见 [CLAUDE.md](../CLAUDE.md)。

## 条目模板

```text
### YYYY-MM-DD 一句话标题
- 现象：AI 做了什么 vs 期望什么
- 归类：工具可挡 | 缺上下文 | 真规则 | 表达不清（可多选）
- 处置：落到哪个文件或配置（未处理时写设想）
- 状态：待处理 | 已落地
```

新条目加在「待处理」区顶部，落地后移进「已落地」区。

## 待处理

（暂无）

## 已落地

### 2026-11-05 〔调研引入〕外部调研批量引入预防性规则与配置

- 现象：外部调研批量引入预防性规则与配置，并非单一被坑现场；无单条痛点可引，靠第二入口（见 [CLAUDE.md](../CLAUDE.md)）合法入库。
- 归类：调研引入
- 处置：[docs/research/adoption-plan.md](research/adoption-plan.md) W0-W8；prose 部分带〔试用〕标记，半年内未在真实任务中用上即删。
- 状态：已落地，prose 部分带〔试用〕半年观察。

### 2026-09-14 重复实现项目已有的请求封装

- 现象：要求新增一个接口调用，AI 在页面组件里手写了 fetch + 超时 + 重试；期望复用 `src/lib/request.ts` 已有的统一封装。
- 归类：缺上下文
- 处置：[templates/CLAUDE.md.template](../templates/CLAUDE.md.template) 增设「模块地图」一节，列出基础设施模块的路径与用途，动手前先查地图。
- 状态：已落地

### 2026-09-28 用错包管理器，生成 package-lock.json

- 现象：pnpm 项目里 AI 跑 `npm install`，凭空生成 package-lock.json 并弄乱依赖；期望一切安装命令走 pnpm。
- 归类：缺上下文 + 工具可挡
- 处置：CLAUDE.md 模板的命令速查写死包管理器；`package.json` 加 `packageManager` 字段钉死（corepack 直接拦下错误命令）。栈侧说明见 [stacks/typescript-react/README.md](../stacks/typescript-react/README.md)。
- 状态：已落地

### 2026-10-19 为通过 CI 注释掉失败断言

- 现象：测试失败后，AI 注释掉两个失败断言让 CI 变绿；期望它修实现，或明说修不动并停下。
- 归类：真规则 + 工具可挡
- 处置：[process/definition-of-done.md](../process/definition-of-done.md) 禁止清单新增「不得以删除/注释/skip 断言的方式通过验证」；[claude-code/hooks/stop-verify.sh](../claude-code/hooks/stop-verify.sh) 作为 Stop 钩子在收尾时重跑验证兜底。
- 状态：已落地
