> 拍板用的统一落地方案：把 [ecosystem.md](ecosystem.md) 与 [system-map.md](system-map.md) 两份报告的建议清单合并去重、裁决冲突、排好顺序。原始报告只读不动，本文件是它们的行动层；拍板后逐项实施，完成的条目就地勾选，全文件实施完毕后仅作实施记录保留。

# 调研落地统一方案（ecosystem × system-map 合并版）

两份报告分工不同：ecosystem 回答「框架生态里什么值得偷」，system-map 回答「业务→代码的活地图怎么建」。本文件只合并它们的**行动项**：同落点合并、同工具去重、冲突给出裁决；原始编号全部保留，第 6 节溯源表保证无一遗漏。

## 0. 合并结果一张表

9 个工作包，4 个波次。成本为两份报告自报口径的合并估计。

| 波次 | 工作包 | 一句话 | 一次性成本 |
|---|---|---|---|
| P0 | W0 库维护元方法 | 不做它，本批 prose 增量按现行「pain-log 唯一入口」会被当场拒收 | 半天 |
| P1 当天见效 | W1 流程文件改造 | 审查清单/完成定义/build-vs-buy，全是在现有文件上加十几行 | 半天 |
| P1 | W2 业务语义四小件 | GLOSSARY / CONTEXT-MAP / ADR / CLAUDE.md 模板升级 | 半天–1 天 |
| P1 | W3 设计系统件 | DESIGN.md 模板（反默认美学+黑名单）+ 官方 frontend-design skill | 半天 |
| P2 护栏类 | W4 边界与迁移护栏 | 三栈边界 linter + migrations 保护钩子 | 每栈约 1 小时 + 钩子半天 |
| P2 | W5 日志与调试守则 | canonical log line + 先证据后改码 | 半天–1 天 |
| P2 | W6 三栈 README 增量统筹 | 两报告全部栈文档增量一次改完 + 行数核对 | 半天 |
| P3 触发制 | W7 契约层 | tbls/oasdiff/类型生成/drift CI，真实 API 项目触发启用 | 1–2 天（按用到的层打折） |
| P3 触发制 | W8 多 agent 协议 | 开第二条并行写入线之前写 | 半天 |

另有：可选池（第 3 节，触发条件制）、不做清单落库（并入 W1）。

## 1. 工作包明细

### W0 库维护元方法（来源：E-A7）

改本库 [CLAUDE.md](../../CLAUDE.md)，三件事，压缩在 10 行内（80 行预算现余约 20 行）：

1. **第二入口条款**：外部调研引入的预防性规则，须注明调研来源、规则正文带〔试用〕标记，半年内未在真实任务中用上即删——这是本方案全部 prose 增量的合法性前提。
2. **入库前压力测试**：新 prose 规则先用无规则 fresh 会话复现失败 + 对照组（对照组不犯错就不写这条）。
3. **按失败类型选规则形态**：禁止式+「借口→反驳」表只治明知故犯；输出形状问题写正向配方；禁「除非必要」式软化语。
4. 行数预算表补一行通配：`templates/ 其余模板 各 80`（覆盖 W2/W3 新模板）。

落地节奏约定（全方案通用）：**文件/钩子/模板/配置直接落地；prose 规则一律带〔试用〕，真实项目踩过一次再转正。**

### W1 流程文件改造（来源：E-A3、E-A4、S-A5、E-U4/U5/U6、E-F3、E-F7、两报告不做清单）

- [review-checklist.md](../../process/review-checklist.md)：
  - 审查顺序改为分层：**plan（假设/边界/测试点）→ 契约 diff（schema/API/边界红灯/状态机）→ 测试 → 实现抽查**，高风险路径才逐行（S-A5；「评审对象上移」为 S 的主张，E 5.2「实现/评审分离」仅方向相近）。
  - 流程串联补一步：push 前固化跑 /code-review 与 /security-review（独立上下文第一道闸；S-A5 第三成分）。
  - 新增「UI/a11y 机检」节（约 15 行可判定条目）：SVG 禁 emoji、可点元素 cursor-pointer、对比度 ≥4.5:1（WCAG 口径）、焦点环可见、prefers-reduced-motion、375/768/1024/1440 四断点无横向滚动；可点目标 ≥24×24、Tab 可达、表单 label 与内联错误、禁 div onClick 当导航、URL 反映状态、移动端 input ≥16px、aria-live、破坏性操作须确认、只动画 transform/opacity（U4+U5）。
  - AI 味清单加一行：「列表/详情缺状态四件套（loading 同形 skeleton / error 可重试 / empty 设计过 / success）」（F3）。
- [definition-of-done.md](../../process/definition-of-done.md)：UI 验证升级为**双视口截图（1280×800 + 375×812）+ browser console 零错误**（U6；边界要诚实：判得出布局错位，判不了「好看」）。
- [build-vs-buy.md](../../process/build-vs-buy.md)：
  - 加默认值两行：Storybook <20 组件不上，轻替代 = 项目内 /dev 组件画廊（F7）；「技能/脚本优先于 MCP，能脚本解决不加 MCP」。
  - 新增「反面清单」节：两报告不做项合并落库防未来心动——整装框架（superpowers/trellis/spec-kit/BMAD）、swarm 编排器（ruflo 类）、ui-ux-pro-max 整包、大一统平台（Backstage/EA/CAST）、双向同步工具、自建代码图谱基建、全站像素快照 SaaS、订阅制或停更的建模/地图工具（Context Mapper CML、oNote/Qlerify、Stately Studio Pro、AppMap 当基建、madge/Sourcetrail 系；XState 取舍已由 W7 覆盖）、测试比例数字入规、agent teams 当主力、Atlas 付费 lint（E-N1..6 + S-C1..5 去重后）。
- 备注：「禁止删/跳过测试」S 报告两处强调，universal #5 与完成定义禁止清单**已有**，无新增动作。

### W2 业务语义四小件（来源：S-A1、S-A4、E 对照表「spec 闭环」、S-4.3 证据链）

- 新模板 `templates/GLOSSARY.md.template`：条目格式 `**术语**: 一句话定义` + `_Avoid_: 禁用别名`，附三坑（不混通用编程词/多上下文分治/别名收敛 canonical）。
- 新模板 `templates/CONTEXT-MAP.md.template`：上下文 × 职责 × 对外接口 × 依赖方向一张表；目录=bounded context。
- 新文件 `process/adr.md`：五段式、append-only、三条件收敛（难逆转+未来会惊讶+真实权衡过）；预算 120 行内。
- [CLAUDE.md.template](../../templates/CLAUDE.md.template) 升级（150 行预算现余约 45 行，够）：模块地图节加两行指针（命名前先查 GLOSSARY，Reuse/Compose/Qualify 后才造词）；加「触及旧决策须引用或新增 ADR」；加「spec/文档闭环：改码引入新术语/新依赖方向/新状态/推翻旧决策，同一 PR 顺手更新对应文件」；加「PR 描述带证据链：动了哪个 context/表/operationId/状态机」；预埋多 agent 两行（共享契约先冻结、评审者只读）。
- 裁决①：S 报告原落点 `universal/` 改为 `templates/`——目录职责是「复制进新项目再填空」，universal/ 只放 principles.md；命名随既有惯例 `<目标文件名>.template`。

### W3 设计系统件（来源：E-A2、E-U1/U2/U3、E-O2、E-O3）

- 新模板 `templates/DESIGN.md.template`（≤80 行）：首行「任何 UI 任务先读本文件，它覆盖一切默认美学」；U1 反默认规则（禁 Inter/Roboto 系默认字体、字重极端对比、一主导色+锐利强调、禁白底紫渐变、动效集中一次编排）；U2 token 固化结构（4-6 命名 hex 色及角色/字体族/间距尺度/禁用清单；节奏=探索期生成一次→立即固化→之后只认固化文件）；U3 反模板黑名单（奶油底衬线陶土橙、酸绿朱红、全大写 eyebrow、圆角卡片灰阴影渐变洗、单词上色、假编号圆点；黑名单是上代模型口癖，每半年换血）。
- [task-brief.md](../../process/task-brief.md) M 级 UI 任务附加栏：ASCII 线框锁结构 + 参照物链接/截图 + 「be ambitious：空态/错误态/保存流/键盘导航」（U7/O2）。
- 安装官方 frontend-design skill（约 2k token 按需加载），与 DESIGN.md 并存：skill 管品味唤起，DESIGN.md 管项目一致性（O3）。

### W4 边界与迁移护栏（来源：S-A2、E-A5、E-B1/B2）

- 三栈边界 linter 进选型与 configs：TS=dependency-cruiser（`--init` 起步、存量用 `--ignore-known` 基线）、Python=import-linter（layers/forbidden 契约约 10 行）、Go=internal/（编译器强制）+ golangci depguard；规则条数 ≤15；规则文件三重身份=架构文档+AI 边界输入+CI 门禁。
- 新钩子 `claude-code/hooks/pre-edit-migrations.sh`：PreToolUse 匹配 Edit|Write，路径落在 migrations/ 即 exit 2；仿 stop-verify.sh 结构。配套三条纪律（进两栈 README 坑条，W6 统筹）：AI 只许新增 migration 文件；禁 reset/drop/删数据除非人类显式确认；migration 人审 + 本地非空库跑过，AI 无生产凭证。roll-forward-only：不写 down migration，错了再写一条向前修正（B2）。
- 清醒句照抄：hook 是护栏不是安全边界，真边界是凭证隔离。
- [hooks.md](../../claude-code/hooks.md) 补两个新钩子说明（120 行预算现余 20 行：与 W7 再生成钩子共用一段安装说明，超限把逐钩子说明压成表格）。

### W5 日志与调试守则（来源：S-A6 ⊇ E-B3）

- 调试守则进 [principles.md](../../universal/principles.md)（50 行预算现余约 26 行，加 2 行）与 CLAUDE.md 模板：**先复现 → 读运行时证据（按 request_id 过滤结构化日志 / 前端看 console）→ 才改代码 → 修完回查**；禁盲改。
- 三栈日志选型与 canonical log line：pino / structlog / slog；每请求结尾恰好一条富上下文 JSON（route/status/duration_ms/request_id/error_code/关键下游耗时），禁散落 printf；失败请求 100% 留痕。落点：go README 直接改现有 slog 参照示例、python README 参照模式加 ≤15 行 structlog 中间件骨架、ts 栈按需（W6 统筹）。
- 单人规模不上 OTel 全家桶（按需档见可选池 OP4）。

### W6 三栈 README 增量统筹（来源：E-A6、E-F1/F2/F5/F6、E-B4/B5/B7 + W4/W5 栈内行）

一次性改三个栈 README，全部折进既有七节、禁新增节。各栈增量：

- typescript-react（现 122/200，余 78，宽裕）：选型清单加契约先行行（接口类型一律 OpenAPI 生成、生成物只读、生成 client 走 client.ts mutator 不开第二 HTTP 出口；F1）+ MSW 三条（全局只放成功态、测试 onUnhandledRequest:'error'、handlers 从 spec 生成；F2）+ 测试行补视觉回归分层（默认不做全站快照，关键页才 toHaveScreenshot；F6）+ 边界 linter 行（W4）；高频 AI 坑第 5 条升级（React Compiler 1.0 依据 + 存量手写 memo 保留勿删；F5）；参照模式加状态四件套包装器示意（F3 的栈内落点）。
- python（现 120/200，余 80，宽裕）：选型清单加错误信封行（RFC 9457 problem+json，FastAPI 需自加全局 handler；B4）+ 分页幂等行（cursor 分页默认、仅创建类端点要求 Idempotency-Key；B5，无对外 API 项目可缓）+ testcontainers 测试行与 over-mock 坑条（B7）+ 边界 linter 行（W4）；坑条加迁移纪律（W4 的 B1/B2）；参照模式加 structlog 骨架（W5）。
- go（现 166/200，**余 34，紧张**）：增量同 python 结构（B4 用 Huma 内建、B5、B7 用 testcontainers-go、W4 depguard 行、B1/B2 坑条、W5 slog 示例改造）。**动笔前 wc -l 核对，全部增量压在约 20 行内，超限先修剪现有「一句话理由」列**——E-A6 与本库预算表的硬约束。
- 统一门：三栈改完逐一核对 200 行上限与七节结构（CLAUDE.md 结构约束）。

### W7 契约层（来源：S-A3、E-O4=F1/F2/B6；**两报告唯一的节奏冲突，裁决如下**）

- 裁决②：system-map 主张立即采纳，ecosystem 主张等真实 API 项目——**取两档制**：规则与模板现在入库（本工作包），**启用条件 = 下一个真实 API 项目开工**；无对外 API 的项目明确跳过 oasdiff/类型生成（成本自动减半）。
- 入库内容：`stacks/*/configs/` 加 CI 工作流模板（tbls doc+diff、FastAPI/Huma 导出 openapi.json 提交进仓、oasdiff 官方 action fail-on ERR、Spectral lint、drift 检查=真源变而工件未再生成则 fail），并在各 README 第 7 节挂行；`claude-code/hooks/` 加再生成钩子说明（AI 改 schema/接口后自动跑再生成命令）；[workflow.md](../workflow.md) 阶段4 补「产出物=代码+再生成的契约工件」一句。
- 工具去重：oasdiff 两报告同款；DB 侧统一 tbls（+alembic check），**不用 Atlas**（付费面扩大，S-C5）；TS 类型生成选型一行决策（要 mock 一条龙=orval，只要类型=openapi-typescript+openapi-fetch；hey-api 需锁版本）。
- 状态机轻量约定随本包入库：`docs/state/<实体>.md` 内嵌 Mermaid stateDiagram + 「改状态逻辑必须同步改图」约定；复杂才 XState（S-A3 的状态机部分）。

### W8 多 agent 协议（来源：E-A1、E-O1；触发=真要开第二条并行写入线）

- 新文件 `process/multi-agent.md`（≤120 行，process 预算内）：六条协议（契约先冻结、实现/评审分离+评审者工具白名单只读+PASS/FAIL、每写入线一个 worktree 且 ≤2 条、计划即共享内存、审批门四处、委派指令四要素）+ 噱头表结论版（读并行写串行单写者；蜂群/吹牛编排器/角色扮演团/为省上下文拆 subagent 的判定）。与 [session-management.md](../../process/session-management.md) 互链：它管单会话，这个管多会话。
- [plan.md.template](../../templates/plan.md.template) 加「交接包」四字段：commit 哈希/变更的契约/验证目标/未决假设；计划正文只记决策不写全代码（O1；60 行预算实测现余 5 行，字段压成一行注释）。
- 不急：两条预埋行已在 W2 进 CLAUDE.md 模板，真开并行线那天再写本文件也来得及（ecosystem 动手顺序原话）。

## 2. 裁决汇总（两报告冲突与重叠的处理）

| # | 冲突/重叠 | 裁决 |
|---|---|---|
| ① | GLOSSARY/CONTEXT-MAP 落点：S 报告写 universal/ | 改 templates/，命名 `<文件名>.template`，与目录职责一致 |
| ② | 契约层节奏：S 立即 vs E 触发制 | 两档制：模板规则入库，启用挂真实 API 项目 |
| ③ | canonical log line：S-A6 与 E-B3 同主张 | 合并，落点取 E 的更细方案（改 go slog 示例/加 python structlog 骨架） |
| ④ | 审查顺序：分层审查为 S-A5 独有主张（E 5.2「实现/评审分离」仅方向相近） | 单源采纳，进 W1 一次改完 |
| ⑤ | 「禁删测试」S 报告两处提出 | 已有（universal #5 + 完成定义），零动作 |
| ⑥ | 工具重叠仅 oasdiff 是双报告同款 | oasdiff 去重；tbls（仅 S）、testcontainers（仅 E）各自单源采纳 |
| ⑦ | E 对照表「任务拆 2-5 分钟粒度」 | 不采纳：plan 模板现有「每步文件+验证命令」已够，粒度数字属仪式 |
| ⑧ | E 对照表「delta spec」 | 不采纳：单人场景 plan.md 已近似，低优先 |
| ⑨ | F4 查询错误三分法 | 降级进可选池：E 自注 tkdodo 原文未核对，核对后再入 ts README |
| ⑩ | Chrome DevTools MCP 在 S 出现两处、E 的 U6 需要 console | 保持可选（OP3）；U6 的 console 检查不依赖它 |

## 3. 可选池（触发条件制，每次只引入一个，两周后按「用没用到」去留）

| # | 项 | 触发条件 | 来源 |
|---|---|---|---|
| OP1 | 安全双层：gitleaks pre-commit+CI 全量、uv audit / govulncheck、weekly osv-scanner | 无前置，收益/成本比高，建议最先从本池取用 | E-O5/B8 |
| OP2 | CodeBoarding 进 CI（架构图增量刷新+PR 贴位置） | 想要「动态刷新代码地图」现成品时，先试一个仓库 | S-B1 |
| OP3 | Chrome DevTools MCP（独立浏览器 profile） | TS/React 项目调前端 bug 频繁时 | S-B3 |
| OP4 | OTel 最低限（只插桩 HTTP/DB/外呼）+ otel-desktop-viewer | 调性能/串流程时临时开 | S-B4 |
| OP5 | DeepWiki MCP：读第三方库先查 wiki；私库 deepwiki-open 自托管 | 高频读陌生库时；注意烧自己 key+运维面 | S-B2 |
| OP6 | C4 从 Mermaid 升级 LikeC4/Structurizr DSL | 图超过 2-3 张、要一模型多视图时 | S-B5 |
| OP7 | PR 兜底评审（CodeRabbit 免费层/claude-code-action 自跑），关 nitpick 降噪 | 开始走 PR 流程后 | S-B6 |
| OP8 | F4 查询错误三分法进 ts README | 核对 tkdodo 原文后 | E-F4 |
| OP9 | code-graph-rag 类 MCP | 仅当 Claude Code 在仓库反复 grep 低效；默认不做 | S-B7 |

## 4. 预算与结构冲突核对单（实施时的硬门）

- go README 余 34 行：W4/W5/W6 增量合计压 ≤20 行，超限先修剪（候选：选型清单理由列压缩）。
- 本库 CLAUDE.md 余约 20 行：W0 全部内容压 ≤10 行 + 预算通配行 1 行。
- hooks.md 余 20 行：W4+W7 两钩子说明合写、共用安装段。
- plan.md.template 余 5 行：交接包四字段压一行注释。
- principles.md 余约 26 行：W5 调试守则加 ≤2 行（带 ❌/✅）。
- 全部新 md：`>` 引用块开场、术语表用词、相对链接指向真实文件；新模板补进预算表（W0 第 4 条）。
- 全部新 prose 规则：带〔试用〕标记 + 注明「来源：调研 2026-11（docs/research/）」，在 [pain-log](../pain-log.md) 登记一条〔调研引入〕条目。

## 5. 动手顺序

1. **W0**（先改规则的规则，写一次管全库）→ 2. **W1**（十几行当天见效）→ 3. **W2 + W3**（可并行，下一个带 UI 的任务前备好）→ 4. **W4 + W5**（下一个碰数据库/后端的任务前备好）→ 5. **W6**（随 W4/W5 动栈文件时一并统筹，过行数门）→ 6. **W7/W8 挂触发条件**，不设截止 → 可选池按触发条件逐个取用。

## 6. 溯源对照表（两报告全部编号的去向）

| 原编号 | 去向 | 说明 |
|---|---|---|
| E-A1 | W8 | multi-agent.md |
| E-A2 / E-U1 / E-U2 / E-U3 | W3 | DESIGN.md.template |
| E-A3 / E-U4 / E-U5 | W1 | review-checklist UI/a11y 节 |
| E-A4 / E-U6 | W1 | DoD 双视口+console |
| E-A5 / E-B1 / E-B2 | W4 | 迁移钩子+纪律（坑条经 W6 落栈） |
| E-A6 / E-B4 / E-B5 / E-B7 | W6 | 两栈 README 增量（B5 标注可缓） |
| E-A7 | W0 | 元方法+试用入口 |
| E-O1 | W8 | plan 模板交接包 |
| E-O2 / E-U7 | W3 | task-brief UI 附加栏 |
| E-O3 | W3 | frontend-design skill |
| E-O4 / E-F1 / E-F2 / E-B6 | W7 | 契约层（F1/F2 的栈内行经 W6） |
| E-O5 / E-B8 | OP1 | 安全双层 |
| E-F3 | W1+W6 | 清单行+参照模式 |
| E-F4 | OP8 | 待核对原文 |
| E-F5 / E-F6 | W6 | ts README 坑条/测试行 |
| E-F7 | W1 | build-vs-buy 两行 |
| E-B3 | W5 | 并入 S-A6（裁决③） |
| E-N1–N6 | W1 | 反面清单落库 |
| E 对照表「spec 闭环」、S-4.3「证据链」 | W2 | CLAUDE.md 模板约定 |
| E 对照表「2-5 分钟粒度」「delta spec」 | 不采纳 | 裁决⑦⑧ |
| E 对照表「AGENTS.md 多工具」 | 观察 | Claude Code 已自动兼容，零动作 |
| S-A1 | W2 | 落点改 templates/（裁决①） |
| S-A2 | W4 | 边界 linter（选型行经 W6） |
| S-A3 | W7 | 契约三件套+drift CI+状态机约定 |
| S-A4 | W2 | process/adr.md |
| S-A5 | W1 | 分层审查 + push 前 /code-review、/security-review 步骤（裁决④；禁删测试=裁决⑤零动作） |
| S-A6 | W5 | 调试守则+日志（吸收 E-B3） |
| S-B1–B7 | OP2–OP7、OP9 | 逐项映射见第 3 节 |
| S-C1–C5 | W1 | 反面清单落库（与 E-N 去重） |
