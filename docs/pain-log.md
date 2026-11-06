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

### 2026-11-06 改按钮文案、样式这类小改动，AI 跑一堆回归、过度防御

- 现象：只想改页面上一个按钮的文字或样式，AI 却跑全量回归、截图、加防御代码（GPT 系尤甚）；期望：按 S 级办，只做验收要求的改动和对应的快检。
- 归类：真规则（本库规则里的三处诱因 + 模型自身的加戏倾向）
- 处置：三处诱因已改：S 级的 lint/typecheck 交给 Stop 钩子、不手动重跑；文案与样式改动不新写测试，只同步改断言了旧值的现有测试；高风险升档看改动是否影响相关逻辑或数据，不看文件位置。上限规则以〔试用〕先行落地、没做压力测试：S 级默认只做验收要求的改动和 S 档检查，想多做先说理由、等同意或列成建议；用户在任务里明说的与项目 CLAUDE.md 的偏好优先。落点：[完成定义](../process/definition-of-done.md)第 1 节、[任务简述](../process/task-brief.md)、[审查清单](../process/review-checklist.md)、[CLAUDE.md 模板](../templates/CLAUDE.md.template)第 6 节第 9 条与第 7 节。
- 状态：已落地；上限规则 2026-11-20 复查看效果，半年内真实任务里用不上就按〔试用〕规则删

### 2026-11-06 验证与审查不分大小，小改动也走全套

- 现象：改一行文案也要走完成定义六条（含双视口截图）、push 前两道审查再加三遍审查；Stop 钩子每个回合都跑全套快检，纯问答也跑，还会因为改动前就有的 lint 错误把 Claude 打回去修范围外的文件；上游新披露一个漏洞，依赖审计让所有无关 PR 一起变红。期望：验证与审查的深浅跟着改动大小与风险走。
- 归类：真规则（规则过重，按档收窄适用范围）
- 处置：[完成定义](../process/definition-of-done.md)与[审查清单](../process/review-checklist.md)按[任务简述](../process/task-brief.md)的 S/M/L 分档，碰到高风险路径一律按 L 级；[CLAUDE.md 模板](../templates/CLAUDE.md.template)第 7 节的测试范围同步分档；[stop-verify.sh](../claude-code/hooks/stop-verify.sh) 工作区没变就放行、同一组失败只打回一次、只要求修本次引入的问题；TS 与 python 的 `configs/security-ci.yml` 依赖审计只在依赖清单或 lockfile 变化时卡 PR，新披露的漏洞交给每周扫描。
- 状态：已落地

### 2026-11-06 〔调研引入〕可选池 OP1 安全双层（密钥扫描 + 依赖审计）

- 现象：密钥泄漏与依赖漏洞，全库此前只有 principles 第 11 条一句 prose，没有任何机器兜底；调研可选池把它列为第一项（无前置、收益/成本比高）。
- 归类：调研引入
- 处置：[pre-write-secrets.sh](../claude-code/hooks/pre-write-secrets.sh)（写盘前）、[githooks/pre-commit](../claude-code/githooks/pre-commit)（提交前）、三栈 `configs/security-ci.yml`（gitleaks 全量 + 按栈依赖审计 + 每周 osv-scanner），python 另加 `configs/osv-scanner.toml`；与原方案的偏差见 [adoption-plan.md](research/adoption-plan.md) 第 7 节。
- 状态：已落地；2026-11-20 按可选池规则看「用没用到」决定去留。principles 第 11 条已有工具兜底，列为修剪候选。

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
