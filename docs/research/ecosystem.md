> 归档调研报告，只读参考、不是规则。综合 8 份专项调研：superpowers / ui-ux-pro-max / trellis 三个点名项目、生态地图、UI-UX / 前端 / 后端实践、多 agent 协作。星数与仓库状态为 2026-11-05 GitHub API 实测；查证不到的断言在正文就地注明缺口。第 6 节全部建议待你拍板，本报告不自动改库。

# AI 辅助开发生态调研（2026-11）

## 0. TL;DR

1. 你的三个猜测都沾边，但主因是「太重」——2026 年社区共识是流程框架的价值随模型变强而贬值，真正留存的是一小组约定与工件（计划先行、验证门、delta spec、短 constitution），且它们正沉淀进原生功能而非第三方框架。
2. superpowers（312.6k★）最有力的证据是它自己的演进：82 文件→15 skill、六阶段 brainstorm→逐题对话、计划写全代码→只记决策——作者在持续证伪自己早期的仪式部分，沉淀下来的不变量是强制验证、借口表、角色隔离、规格先行。
3. ui-ux-pro-max（145.3k★）被 issue #484 的系统评测戳破：自动触发召回率仅 50%（实测，N=80）；「82% 分发文件从未被打开」为作者推算上界而非实测（见 2.2）；项目 Contributor triage 接受全部发现。官方 frontend-design skill（SKILL.md 约 1.3-1.5k 词 ≈2k token，按需加载）纯 prose 在常见场景不输它。
4. trellis（15.1k★）两个猜测同时命中：高赞 issue 原话「文档写的太不清楚了」，且精简分叉 mini-trellis 砍掉强制流程只留记忆层自测省 40% token；主仓 2026-09-29 后零提交，停滞风险真实。
5. 多 agent 写码的行业共识已收敛为「读并行、写串行、单写者」——Anthropic 自己说多数编码任务不适合并行（多代理约 15x token），Cognition 的机制论证与之一致。
6. 数十 agent 蜂群与吹牛编排器已被实证祛魅：ruflo（原 claude-flow）约 97% 工具是无后端的 stub、仓内审计证实宣传指标造假；Gas Town 高成本遭持续批评（Yegge 自述每月数千美元 API 费），2026-04 被其继任 SDK Gas City 取代、原项目趋于维护态——但 Yegge 并未放弃蜂群路线，「不适合多数编码任务」的硬证据在 5.1/5.3。
7. 有一类东西与「模型变强」反向而行：裁决器（验证门、lint、diff 门禁、迁移拦截）——AI 产量越大它们越值钱，这与你库「能被工具强制的不写成文字」完全同向，你的哲学不需要推翻，只需要补增量。
8. UI/UX 最划算的是三件套：几百 token 反默认美学规则 + 项目级 DESIGN.md 固化设计 token + 截图自查闭环，你库已有第三件的雏形，补前两件即可。
9. 后端最硬的增量是迁移纪律三条（AI 只许新增 migration 文件、禁 reset/drop、无生产凭证）+ 每请求一条 canonical log line + gitleaks/osv 双层扫描。
10. 落地动作集中在第 6 节：3 个新文件 + 4 处修改列为「建议采纳」，另有 5 项可选、6 项明确不做。

## 1. 生态地图：框架分类学与代表项目

「重量」指采纳后的总负担：常驻上下文 + 流程仪式 + 学习与维护成本。

| 类别 | 代表 | 定位 | 重量 | 现状（2026-11） |
|---|---|---|---|---|
| 技能库·方法论 | superpowers（obra，312.6k★） | 15 个 skill 编码的强制开发方法论 | 常驻轻（<1k token），全链条重 | 极活跃；进 Anthropic 官方插件市场；成立公司 Prime Radiant 商业支持 |
| 设计知识库 | ui-ux-pro-max-skill（145.3k★） | CSV 设计知识 + BM25 离线检索 | 磁盘/心理重，上下文轻 | 活跃；星数与实证口碑严重不对称 |
| SDD·重 | spec-kit（GitHub 官方，147.5k★） | constitution→specify→plan→tasks→implement | 重 | 活跃；只适合大 feature：Thoughtworks 雷达列 Assess、点名 instruction bloat 与输出冗长；社区评小改动/bug fix 场景 overkill（Reddit 用户语，经 Tessl 转述）；Scott Logic 实测比迭代 prompt 慢约 10 倍 |
| SDD·轻 | OpenSpec（74.0k★） | 变更级 delta 规范，archive 回写 living specs | 轻 | 增长最快的 SDD；无阶段门 |
| SDD·IDE | Kiro（AWS） | EARS 需求/design/tasks 三件套 IDE | 重 | 已 GA（确切日期各源冲突，未能核实）；锁 AWS+VS Code，团队溯源场景才回本 |
| 角色扮演多代理 | BMAD-METHOD（55.0k★） | PM/架构师/dev/QA 多代理敏捷 | 最重（社区估学习曲线约 2 个月） | 活跃；「模型需分角色才能分工」假设已陈旧 |
| 任务分解·仓库记忆 | Trellis（mindfold-ai，15.1k★） | .trellis/ 内 spec+PRD+journal+四阶段状态机 | 中偏重 | 停滞：2026-09-29 后零提交，70 open issues（GitHub API 含 PR 口径约 90）近 5 周无人响应 |
| 任务分解 | claude-task-master（28.3k★） | PRD→任务图 MCP | 中 | 停更（2026-04 起），安全 issue 未闭环，不建议新采用 |
| 多代理编排 | ruflo（原 claude-flow，80.9k★） | 「蜂群」编排 | — | 反面教材：社区审计认定约 97% 工具为 stub；仓内审计证实多项宣传指标系硬编码/运行时随机伪造（详见 5.3） |
| 标准注入 | Agent OS（5.6k★） | 自动发现并注入 codebase standards | 很轻 | v3（2026-01）主动砍掉自家 spec 命令，依附原生 plan mode |
| 上下文工程方法论 | HumanLayer（12-factor agents、ACE-FCA） | Research→Plan→Implement + 有意压缩 | 纯方法论 | 影响力大，无框架可装 |

三个结构性变化解释了上表的风向：

1. **规则载体标准化**：Agent Skills（SKILL.md）与 AGENTS.md 双双捐入 Agentic AI Foundation 成跨工具开放标准，Claude Code 2.1.277 起无 CLAUDE.md 时自动读 AGENTS.md——框架的「N 平台适配」卖点随之贬值。
2. **原生 plan mode 吃掉第三方 SDD 的核心场景**。标志事件：Agent OS v3 删除自家 spec 生成命令，官方称依附原生 plan mode 是「2026+ 的行业标准做法」。
3. **重编排崩塌、重流程收缩为可选件**：ruflo 被审计祛魅；spec-kit 1.0 把 bug-fix 等拆成扩展；mini-trellis、zcf 等精简/拼装套件涌现。留存的是约定与工件，框架只是打包器——打包越厚，越快被原生功能替代。

## 2. 点名项目剖析

### 2.1 superpowers：生态最大赢家，但它自己也在瘦身

**是什么**：Jesse Vincent（obra，Request Tracker 作者）2025-10 创建，MIT，312.6k★。把开发方法论编码进 15 个 skill（TDD、systematic-debugging、verification-before-completion、brainstorming、writing-plans、subagent-driven-development 等），README 自述「Mandatory workflows, not suggestions」。15 篇 SKILL.md 共 3,423 行，但按需加载。

**预期用法**：SessionStart hook 把 65 行 bootstrap（<1k token）包在 EXTREMELY_IMPORTANT 标签里注入会话，文案是「只要有一点可能适用某 skill，YOU MUST USE IT」。链条 = brainstorm（逐题对话）→ git worktree 隔离 → 计划拆到 2-5 分钟粒度（含精确文件路径与验证步骤）→ 每任务新子代理 + 规格/质量双审（或本线执行 + 一次整审）→ TDD → review → finish；verification-before-completion 横切一切「完成」声明。

**重量在哪**：不在常驻，在链条下游——每任务子代理 + 实现/审查双角色 + 最终整审，全链是裸用的数倍推理量。HN 实名批评「对简单事情啰嗦得难以置信」「比原生 plan mode 慢且费 token，我卸了」。机制全是提示词心理学，无硬 gate，部分 harness 在 compaction 后约束消失。短任务净亏、长任务可能净赚——无权威基准（调研缺口：仅一个 12 会话小样本对照声称省 14% token，未经复核）。

**值得偷（4 条）**：
1. **verification-before-completion 整篇抄**（仅 120 行自包含）：「没有本条消息内新跑的验证证据，不得声称完成」；含「subagent 说成功要自己查 VCS diff 验证」「回归测试必须经历过 red-green（revert 修复须变红）才算数」。两极评价里几乎没人否定这一篇。
2. **「借口表 + red flags」文体**：规则失效不是模型不懂，是压力下讨价还价——每条纪律规则旁列「借口→反驳」二列表（「太简单不用测→简单代码照样坏」「换个说法就不算→违反字面即违反精神」），再列触发暂停的红旗词（should、probably、先说 Great! 后验证）。迁移成本最低的一项。
3. **规则入库前先压力测试**：用无规则的 fresh subagent 复现失败（含对照组，对照组不犯错就别写这条规则）、逐字记录它的借口、写最小规则只堵这些借口、5 次以上重复验证，「方差即指标」。
4. **按失败类型选规则形态**（作者实测，反直觉）：禁止式 + 借口表只治「明知故犯」类纪律失败；对「输出形状不对」类问题，禁止式比不写还糟，要写成正向配方/契约；严禁软化语——「除非必要否则别 X」会重新打开谈判。

### 2.2 ui-ux-pro-max：架构对、数据虚、触发靠不住

**是什么**：CSV 设计知识库（79 风格 / 192 色板 / 119 UX 守则 / 192 条行业→设计映射）+ 纯标准库 Python BM25 离线检索脚本 + SKILL.md 调度。2025-11-30 创建，踩中 Skills 机制发布后的生态真空期，145.3k★。不是组件库、不改代码，官方自述「提供设计指导，不自动重写应用」。调研缺口：作者 nextlevelbuilder 身份与引爆它的社交帖均不可考，HN/Reddit 原帖检索不到，社区口碑证据以博客评测与 GitHub issues 为主。

**预期用法**：UI 任务触发 skill → 从 package.json 等探测技术栈 → `search.py --design-system` 五域并行检索生成完整设计系统 → `--persist` 固化为项目内 design-system/MASTER.md（页面级文件可覆盖全局）→ 写码 → 按交付前清单自检。

**重量在哪**：重在磁盘与心理（72 个文件、共数 MB，Python3 前置、版本漂移），不在上下文——检索在盘上做，单次完整设计任务约 2 万 token（单人样本）。真问题是**装了也没在用**：issue #484 系统评测（N=200 次 Claude Haiku 4.5 试验）里，自动触发召回率仅 50% 是直接实测（N=80，95% CI 39-61%）；「82% 分发文件从未被打开、references/ 一次没被读」则是作者的推算上界——实验宿主的权限层拒绝了全部 search.py 调用，数字经作者本地重放查询估算，其自注「upper bound, not an observation」；项目 Contributor triage 接受全部四项发现并在 3 天内合并修复；demo 被指不同行业布局几乎一样、仍逃不出被嘲的「AI 靛蓝」。数据多不等于品味好。对照组：Anthropic 官方 frontend-design 约 1300 词（≈2k token）纯 prose、零数据零脚本（官方博客的「~400 token」指文中展示的提示词版本，非 SKILL.md 本体），第三方对比在 SaaS 落地页等常见场景不输甚至更好；它的残余价值在长尾行业知识、跨 agent 统一和弱模型兜底。

**值得偷（4 条）**：
1. **每条风格/模式条目必须带负面约束**：Best For + Do Not Use For + 反模式三件套，任何设计知识条目都写一行「不要在何时用」。
2. **两段式用法（它最值钱的机制，自家 MASTER.md 即官方背书）**：探索期检索或生成一次设计系统 → 立即固化为项目内 MASTER.md / design tokens → 之后只认固化文件、不再检索。治多页面多会话风格漂移。
3. **交付前机检清单**（可原样抄）：图标用 SVG 禁 emoji；可点元素 cursor-pointer；正文对比度 ≥4.5:1；焦点态可见；respect prefers-reduced-motion；375/768/1024/1440 四断点无横向滚动。
4. **栈探测一句话规则**：「从 package.json/pubspec.yaml 探测技术栈，探测不到且有影响就问用户，绝不假设。」

### 2.3 trellis：价值在记忆层，重在强制流程，且已停滞

**是什么**：mindfold-ai/Trellis（npm @mindfoldhq/trellis，AGPL-3.0），15.1k★，2026-01 创建。把 spec、任务 PRD、journal 沉淀进仓库 .trellis/ 目录，按平台生成 22 个 coding agent 的适配文件；四阶段状态机 Plan→Implement→Verify→Finish，每回合 hook 注入 [workflow-state] 面包屑。传播集中在中文社区。调研缺口：两轮扩展搜索未见 HN/Reddit 独立深度讨论，西方基本无声量；文档站不可直读。

**预期用法**：trellis-brainstorm 一次只问一个问题写 prd.md（硬性规定 PRD 不写技术设计，prd/design/implement 三文件分离）→ implement 子代理写码且永不 commit → check 子代理对照 spec 审 diff 并跑 lint/typecheck/测试 → update-spec 把新认知沉淀回 spec → finish 归档写日志。并行模式每 feature 一个 worktree，统一以 PR 收敛。

**重量在哪**：启动注入约 8.6k 字符 + 每回合重复注入状态 + 例行小改动也要冷启动子代理。最硬的量化证据来自精简分叉 mini-trellis：砍掉相位门只留记忆层，自测省 38.4% 墙钟时间 / 40.1% token（自报数据）。issue 区同时印证你的两个猜测：高赞 issue 就叫「文档写的太不清楚了」；「简单任务让主代理直接做」的请求至今 open。另有工程风险：`trellis update` 会静默覆盖用户自定义、config.yaml 钩子以完整用户环境执行 shell（安全隐患，open）；主仓 2026-09-29 后 5 周零提交、70 open issues 无人响应（GitHub API open_issues_count 含 PR 口径约 90）；此前 8-9 月仍在正常合并社区 PR 并发版 0.6.17（2026-09-11），「弃置」只对最近 5 周成立。

**值得偷（4 条）**：
1. **「conversations get compacted, files don't」**：结论、决策、教训一律落盘为文件，不留在对话里。你库已有此原则，这句表述更锋利，值得引进原话。
2. **spec 闭环**：任务完成 = 代码合入 + 规范更新，二者同一批提交。治「文档永远落后于代码」，也是你库阶段8 沉淀的强化版。
3. **上下文清单**：为每个任务、每个角色显式圈定「该读哪些文件和规范」的白名单，子代理拿清单 + PRD 启动，而不是满仓库自己捞。显式上下文预算，单项可移植性最高。
4. **提交协议**：先读 git status 与近 5 条 log 学风格；脏文件分成「本会话 AI 改的」与「来路不明的」，后者绝不默默打包进 commit；提交计划展示一次等确认；禁 --amend、禁 push。

## 3. 诊断：为什么你不满意

**假设 A「我没用明白」——部分成立，但是次因。** 证据：trellis 文档被高赞 issue 点名不清楚；ui-ux-pro-max 自动触发召回率 50%，不显式点名经常根本没生效（你以为在用，其实在裸跑）；superpowers 专门存在一个 diagnosing-superpowers skill，其存在本身就说明「经常不按预期工作」。所以「没用明白」有真实成分——这三家的易用性都确实差。但即使完全用明白，下面的重量问题照样在。**判断：不值得再花时间去「学会」它们。**

**假设 B「它们太重」——主因，成立，且三家重的位置各不相同。** superpowers 重在链条推理量（每任务子代理+双审，HN 称 token guzzler）；trellis 重在强制相位门 + 每回合注入 + 子代理冷启动（mini-trellis 砍掉后省 40% token 是最硬的量化证据）；ui-ux-pro-max 上下文其实不重，重在磁盘与学习曲线，且估算约八成内容装了也用不上（上界推算，见 2.2）。**判断：成立。共同病根是把「约定」打包成「框架」——你为用 20% 的价值背 100% 的重量，而那 20% 全部可以按条拆走（已拆进第 2、4、5 节）。**

**假设 C「模型变强后不需要这么重了」——方向成立，但必须分两半。** 成立的一半：这批框架诞生于「模型会跳过规划、不守纪律、上下文不可靠」的 2025，而这些前提每代模型都在削弱——Agent OS v3 主动砍自家 spec 命令依附原生 plan mode；superpowers 自己 v3→v7 持续砍仪式（审查循环改行内自审、计划只记决策、v7 继续砍提问数）；Anthropic 官方亲口说「running out of context is rarely the problem anymore」，连「为省上下文拆 subagent」都已过时。**不成立的一半：裁决器与模型能力反向**——验证门、lint、diff 门禁、迁移拦截假设的是「产码者不可全信」，AI 产量越大它们越值钱（后端调研的核心结论：可判定的机器裁决规则在升值，散文式规范在贬值）。**判断：扔掉仪式、留下裁决器。你库「能被工具强制的不写成文字」正好押在升值的一边，整体策略无需推翻。**

**什么情况下重流程仍然值得**（满足其一再考虑，否则默认轻装）：

- 大 feature / 跨模块长任务：superpowers 式「规划 + 子代理 + 双审」在长任务上可能净赚（短任务净亏，无权威基准）。
- 真要并行多条写入线：此时冻结契约、文件所有权、PR 收敛等显式协调工件不是仪式而是必需（见第 5 节）。
- 不熟的领域/长尾行业：检索型知识库对「高端寿司店」式长尾风格仍有残余价值。
- 弱模型或跨 agent 统一：给 GLM 类模型兜底、多工具同仓时，外置知识与规范的价值回升。
- 需求可溯源的团队协作（Kiro/spec-kit 的回本场景）——你是单人，此条不适用。

**对照表：2026 年跨框架幸存下来的共识约定 × 你库的覆盖情况**（幸存约定取自生态地图调研的收敛清单）：

| 幸存约定 | 你的库 | 备注 |
|---|---|---|
| 分级响应：小改动直接做，整 feature 才走全流程 | 已有 | task-brief 的 S/M/L 定级即此，与 superpowers v7「按规模缩放仪式感」同向 |
| 计划先行且人签字、计划落盘归档 | 已有 | plan mode 习惯 + plan.md.template |
| 任务拆 2-5 分钟粒度、每步含文件路径与验证命令 | 部分 | plan 模板每步已必填「改哪些文件」与可执行验证命令（禁写「确认功能正常」），仅 2-5 分钟粒度未写死 |
| brainstorm 一次一问、复述确认再动工 | 已有 | task-brief「先复述，再动手」 |
| 验证门：完成必须附当场跑出的证据 | 已有 | DoD + stop-verify.sh；增量只剩 UI 双视口（A4） |
| 修 bug 先红后绿 | 已有 | DoD 修 bug 铁律 |
| 短 constitution，常驻极短、膨胀即失效 | 已有 | principles.md（50 行预算）+ 项目级 CLAUDE.md 模板（150 行硬上限、每月修剪），与 HN 教训一致 |
| 干净上下文做评审（上下文隔离） | 已有 | review-checklist 三遍审查；增量是工具白名单与 PASS/FAIL（A1） |
| 有意压缩：工件落盘接力新会话 | 已有 | session-management 落盘 + checklist 续作 |
| 完成后回写：learnings 沉淀回规范 | 部分 | pain-log 是入口，但「代码与规范同批提交」未强制（trellis spec 闭环） |
| delta spec 而非全量 spec | 缺 | 单人场景低优先，plan.md 已近似 |
| 技能优先于 MCP，能脚本解决不加 MCP | 缺 | 一行可并进 process/build-vs-buy.md——F7 的落点正是该文件，顺带加 |
| 开工前 worktree + 干净测试基线 | 缺 | 并行时才需要，归入 A1 的 multi-agent.md |
| 框架可逆、工件可手改 | 已有 | 本库本就是复制粘贴式采纳 |
| 多工具同仓标准（AGENTS.md/skills） | 观察 | 单人单工具暂不需要；Claude Code 已自动兼容 AGENTS.md |

结论：你的库与幸存共识重合度很高，不是方向错了，是缺四块增量——UI 规则、契约先行、迁移纪律、多 agent 协议，正是第 4、5 节的内容。

## 4. 各职位可提炼的增量规范

只收你现有库没有的增量（已覆盖的不重复：完成定义、修 bug 铁律、审查清单、止损、选型清单、模块地图、非目标等）。每条可判定，标注建议落点。注意：`stacks/typescript-react/` 已建档（固定七节，现 122 行，另有 3 个 configs），以下前端增量全部是对该现有 README 的修改；按你库结构约束（七节与 _template.md 一字不差、整文件 ≤200 行），落点只折进既有节，现余 78 行，足够容纳 F 系增量。

### 4.1 UI/UX

- **U1 反默认美学规则** → 落点：templates/DESIGN.md.template（新文件）
  禁用 Inter/Roboto/Open Sans/Lato/Arial 与系统默认字体，写码前先声明所选字体；字重用极端对比（100/200 对 800/900，而非 400 对 600），标题字号跳 3 倍而非 1.5 倍；颜色全走 CSS 变量，一个主导色 + 锐利强调色，优于平均分布的温吞色板；禁白底紫渐变；背景用分层渐变/几何纹理而非纯色平铺；动效集中做一次编排好的入场，胜过满屏微交互。官方 cookbook 的 frontend_aesthetics 提示词有全文，可整段抄。原理（Anthropic 官方定性）：默认丑是「分布收敛」——模型采样训练数据里的高概率安全设计，对策不是换模型，是显式反默认指令。
- **U2 项目级 DESIGN.md** → 落点：templates/DESIGN.md.template（新文件）+ templates/CLAUDE.md.template 第 4 节加一行指针
  内容：4-6 个命名 hex 色及角色、字体族及用途、间距尺度、禁用清单。配规则「任何 UI 任务先读它，它覆盖一切默认美学」。节奏：探索期生成一次设计系统 → 立即固化进此文件 → 之后只认固化文件、不再检索或重新发明。治多页面多会话风格漂移，是 ui-ux-pro-max MASTER.md 机制的 30 行自写版。
- **U3 反模板黑名单（出现即打回）** → 落点：templates/DESIGN.md.template
  奶油底+高对比衬线+陶土橙组合；近黑底+单一酸绿/朱红强调；全大写 tracked eyebrow 小标签与「WORD — 片段」式标题；统一圆角卡片+标准灰软阴影+渐变洗；给单个标题词上色强调；无真实顺序却用编号圆点。另两条正向规则：行长 <80 字符；轮廓/分割线/标签必须承载信息而非装饰。
- **U4 UI 交付机检清单** → 落点：process/review-checklist.md 新增一节
  图标用 SVG 禁 emoji；可点元素 cursor-pointer；正文对比 ≥4.5:1（按 WCAG 2.x 口径写，APCA 只作参考——法规合规仍看 WCAG）；焦点环可见、禁 outline:none 无可见替代；prefers-reduced-motion 生效；375/768/1024/1440 四断点无横向滚动、无元素重叠。
- **U5 a11y 可判定基线** → 落点：process/review-checklist.md 同节
  可点目标 ≥24×24 CSS px（WCAG 2.2 SC 2.5.8，移动端按 44px，视觉更小则扩 hit area）；全部交互元素 Tab 可达；表单控件必有 label 且共享点击热区，错误内联在字段旁、提交后聚焦第一个错误，禁屏蔽粘贴；禁 <div onClick> 当导航；URL 反映状态（筛选/tab/分页可深链）；禁 user-scalable=no；移动端 input font-size ≥16px（防 iOS 自动缩放）；toast/内联校验用 aria-live="polite"；破坏性操作须确认或给 Undo；只动画 transform/opacity，禁 transition: all；门禁为 axe-core/Lighthouse 零 violation。
- **U6 截图自查升级为双视口 + console** → 落点：process/definition-of-done.md 第 1 节第 6 条
  UI 改动必须截 1280×800 与 375×812 两档视口并对照验收标准，browser console 零错误，否则不得声称完成。你 DoD 已有单截图，此为升级。边界要诚实：截图判得出布局/遮挡/明显错位，判不了「好看」和 1px 回归；重验收才跑 OneRedOak 式 7 阶段评审（完整浏览器会话 + 多视口截图，图片 token 贵，适合里程碑不适合日常）。
- **U7 无 Figma 的交接约定** → 落点：process/task-brief.md M 级 UI 任务附加栏
  结构先用 ASCII 线框锁定再谈视觉（frontend-design 计划阶段自身就输出 ASCII wireframe，还省 token）；风格锚用参照物——参考站链接或设计稿截图贴进任务简述；要完整 scope 就写「be ambitious：空态、错误态、保存流、键盘导航，不只是布局」（官方示例原话）。

缺口如实说明：以上做法全部没有独立定量评测，证据为官方前后对比截图 + 实践者口碑；U3 黑名单本质是「上一代模型的口癖清单」（cookbook 自己都有自相矛盾处），会随模型代际过时，建议每半年检查换血；「2-3 轮截图迭代明显变好」一句已从现行官方文档删除、原文未能复核，按传闻处理。

### 4.2 前端

- **F1 契约先行（强烈建议）** → 落点：修改现有 stacks/typescript-react/README.md「## 1. 选型清单」加行
  接口类型一律由 OpenAPI 生成，禁手写/手改；生成物放 src/api/generated 设只读；「改 API = 先改 spec 再跑 gen 命令」写进项目规则，防 agent 直接编类型——手写接口类型已被社区普遍视为 bug 源，契约还是多 agent 之间的唯一事实源。选型一行决策：要 mock 一条龙选 orval（同一份 spec 一键生成 TanStack Query hooks + MSW mock + zod）；不要 mock 选 hey-api（queryOptions 风格更贴 Query v5，但 pre-1.0 必须锁版本）；只要类型用 openapi-typescript + openapi-fetch。与现有钉死项「HTTP 统一走 src/api/client.ts」对表：生成的 client/hooks 配置成走 client.ts（orval mutator / 自定义 fetch 注入），src/api/generated 只是产物目录，不开第二个 HTTP 出口。
- **F2 MSW 三条纯规则（零成本）** → 落点：同上
  全局 handlers 只放成功态 baseline，错误/边界态在测试里 server.use() 覆盖（注意 first-match-wins 排序）；测试环境 onUnhandledRequest:'error' 让未 mock 请求当场炸出来；dev（browser worker）与测试（node 拦截）复用同一套 handlers，且 handlers 从 spec 生成防漂移——手写 handlers 必漂移。faker 数据固定 seed。
- **F3 状态四件套（强烈建议，AI 最常偷懒处）** → 落点：同上「参照模式」节 + review-checklist AI 味清单加一行
  每个 feature 的列表/详情必须显式处理四态：loading（与内容同形 skeleton，禁通用 spinner）、error（可重试）、empty（设计过的 EmptyState，与 error 严格区分）、success；抽成统一包装器（如 QueryBoundary）使缺项 lint/review 可查。空态无社区标准，自定即可，规则化收益直接。
- **F4 查询错误三分法（TanStack 官方口径）** → 落点：同上
  有缓存数据的后台刷新失败 → QueryCache 全局 onError 发 toast；无数据的加载失败 → throwOnError 抛错误边界（路由级 ErrorBoundary 包在 Suspense 外层，onReset 接 QueryErrorResetBoundary 实现重试，边界只包最小有意义单元）；表单/局部错误就地处理。
- **F5 React Compiler 1.0（2025-10 转正）** → 落点：升级现有 README「## 6. 高频 AI 坑」第 5 条
  该条现为「❌ 见 state 就包 useMemo/useCallback → ✅ 默认不加，profiler 实测出性能问题再加」，与本条部分重复；真正的增量只两点：给「默认不加」补 React Compiler 1.0 转正这一依据（并把 React.memo 纳入同条），加一句「存量手写 memo 保留勿删（官方态度保守：删除可能改变行为）」。
- **F6 视觉回归分层** → 落点：同 README「## 1. 选型清单」测试行补充
  默认不做全站像素快照——AI 高频改 UI 下，基线甄别成本大于检出收益（LLMShot 论文的问题定义）；仅少数关键页/组件用 Playwright toHaveScreenshot 或 Vitest 4 内置 toMatchScreenshot，配 mask 动态区 + 禁动画 + 容器内统一基线；主验证手段是 U6 的截图自查回路，两者互补不替代。
- **F7 Storybook 判定** → 落点：process/build-vs-buy.md 加一行默认值
  <20 组件不上（story 腐烂 + major 升级断裂，9→10 已 ESM-only；单人产品应用社区判「难回本」）；轻替代 = 项目内 /dev 路由组件画廊 + shadcn registry/MCP 当 AI 组件参照；若上则配套「共享组件无 story 则 CI 拒绝」，避免付了维护费拿不到目录。进规则库的应是「给 AI 一个可查询的组件目录」这个模式，不绑具体工具。

缺口：tkdodo 错误处理细则本次只取到二手汇总（原站不可达），采用 F4 前建议核对原文；Playwright 1.56 官方 agents（planner/generator/healer）太新、社区验证少，只观察不进库。

### 4.3 后端

后端这一年的主线值得先点破：**规则正在从提示词下沉到工具**——API 规则进 Spectral/oasdiff、迁移规则进 squawk、安全进 gitleaks/osv-scanner。AI 产码越多，机器可裁决的规则越值钱、散文式规范越贬值。这正是你库三连筛第一档的生态级验证。

- **B1 迁移纪律三条（全行业共识最硬的一条，Prisma「AGENTS.md for databases」与 Atlas AI-safe migrations 的交集）** → 落点：stacks/python、go README「## 6. 高频 AI 坑」各加一条（固定七节禁止新增节，见 A6）+ claude-code/hooks/ 新 PreToolUse 钩子
  (a) AI 可起草 migration，但只许新增文件，永不修改或删除已存在的 migration；(b) 永不执行 reset/drop/删数据类操作，除非人类显式确认；(c) migration 一律人审、且在本地非空测试库跑过才 apply，AI 无生产库凭证。机械执行：PreToolUse 匹配 Edit/Write、路径落在 migrations/ 目录即 exit 2（与你现有 stop-verify.sh 同构）。要清醒：hook 是护栏不是安全边界——模型可能绕道 Bash，真边界是凭证隔离。人审 AI 的 SQL 只能逮语法级错误，逮不住锁表/时长这类运维级问题，所以「本地非空库跑过」不可省；Postgres 另可加 squawk lint（逮锁表、缺 CONCURRENTLY）。
- **B2 roll-forward-only** → 落点：与 B1 合写进「## 6. 高频 AI 坑」同一条
  不写 down migration——它很少被测试、可能毁数据（Atlas「The Myth of Down Migrations」与 Ory 文档同一立场）；错了就再写一条向前修正的 migration。
- **B3 canonical log line（Stripe 模式，近零成本）** → 落点：go README「## 5. 参照模式」直接把现有 slog 示例改成请求收尾一条 canonical log line 的形态；python README「## 5. 参照模式」加 ≤15 行 structlog 中间件骨架（structlog 现只在其选型清单露过一行）
  每个请求/后台 job 结尾恰好一条富上下文 JSON：route/method/status/duration_ms/user_id/request_id/error_code/关键下游耗时；禁散落 printf 式 log；log level 默认安静。单人规模不上 OTel 全家桶——社区明确说对 side project 太重、单服务个位数工程师用 wide events「perfectly fine」，你已有的 slog/structlog 选型正好承接。
- **B4 API 错误信封** → 落点：stacks/python、go README「## 1. 选型清单」各加一行（需求域「错误响应」）
  所有 4xx/5xx 用 RFC 9457 application/problem+json（type/title/status/detail，业务错误码放自定义扩展字段）。FastAPI 不默认，需自加全局 exception handler；Go 的 Huma 内建。注意：采用率仍低是社区公认（无硬统计），属「超前但有标准背书」，对单人项目的实际收益是错误形状从此唯一。
- **B5 分页与幂等（Zalando 一手规则可直接抄）** → 落点：同上
  列表端点默认 cursor 分页、避免返回 total count（昂贵且 cursor 下难精确）；仅「创建 + 有副作用」端点要求 Idempotency-Key（缺 key→400，同 key 不同 payload→422，命中缓存返回原响应）。缺口与警示：Idempotency-Key 截至可查的 2025-10 仍是 IETF 草案 -07 非 RFC；Zalando 的 media-type 版本化立场是业界少数派，个人项目更优解是不版本化 + CI 禁破坏性变更，真要破坏再起 /v2。
- **B6 契约 CI 门禁（轻量桥接版，半天学习曲线拿 design-first 八成收益）** → 落点：stacks/python、go 的 configs/ 加 CI 工作流模板并在「## 7. 配置文件索引」挂行；等有真实 API 项目再启用
  code-first 导出 openapi.json 提交进 repo → CI 里 git diff 防漂移 + oasdiff 禁破坏性变更（注意 Tufin/oasdiff-action 已废弃，用 oasdiff 官方 action）+ Spectral lint；更严的现成样例是 Supabase auth 的双门禁：Spectral 管 spec 合格、Schemathesis 管服务照 spec 行事，两者回答不同问题。spec 质量规则升级了地位：每个 operation 必有 description/enum/required——这不再是文档洁癖，是 agent 正确调用（乃至生成 MCP/client）的前提。TypeSpec/Fern 全流程对单人偏重，不采。
- **B7 测试 mock 政策（写定性规则，不写比例）** → 落点：stacks/python、go README——testcontainers 补进「## 1. 选型清单」测试行、over-mock 进「## 6. 高频 AI 坑」各一条，+ review-checklist 一行
  mock 仅限外部付费/不可控服务；数据库/缓存一律 testcontainers 真实例（反方也承认真容器只多花几秒）；核心用户路径必须有穿真 DB 的集成测试；禁为覆盖率写断言琐碎的单测；AI 写测试前先喂它现有好测试当样例——HN 高赞观察：agent 测试质量「if and only if」取决于有没有好样例。论据链：AI 产码的失败集中在集成点（seams），AI 自写单测继承同模型盲点，且有系统性 over-mock 保 CI 绿的倾向（OWASP 警告）。不写比例数字——60/20/15 之类全是 vendor 拍脑袋，无实证（调研缺口）。注意这条有保鲜期：AI 自写单测的价值随模型变强在涨，一两年后可能需要放松。
- **B8 安全双层（现实做法已收敛）** → 落点：claude-code/hooks.md 补装法 + stacks configs/CI 模板
  pre-commit 跑 gitleaks 只扫 staged（快）；CI 必须再跑一遍全量——hook 可被 --no-verify 绕过、新机器可能没装；依赖审计按语言：Python 用 uv audit（uv 0.10.12+ 内置，读 uv.lock 查 OSV，第三方实测比 pip-audit 快一个量级）、Go 用 govulncheck（符号级可达性分析，噪声远低于清单比对）；weekly cron 跑 osv-scanner v2 全量——新披露的漏洞不随你的代码变更出现，只靠 PR 触发会漏。遗留仓库先 baseline，只 fail 新泄漏。

## 5. 协作与协调层：一人多 agent 的最小协议

### 5.1 铁律：读并行、写串行、单写者

这是 Anthropic 与 Cognition 罕见一致的结论。Anthropic 多代理研究系统一文：orchestrator-worker 在研究型任务上比单 Opus 高 90.2%，但多代理约是聊天的 15x token，且明确点名「需要共享完整上下文、依赖多、可并行度低」的任务不适用——**多数编码任务属于此类**。Cognition《Don't Build Multi-Agents》的机制论证：行动携带隐含决策，并行写入者的隐含决策必然冲突；例外只有只读 subagent（缺口：cognition 原文被网络策略拦截，经多个二手来源交叉验证，未核对原文措辞）。结论：并行只用于只读工作——调研、评审、竞争假设验证；写代码保持单写者。

### 5.2 最小协作协议（全部用 Claude Code 原生机制，零第三方编排框架）

1. **契约先行**：fan-out 之前由你冻结共享接口——types/schema 作为仓库内一等模块，各 agent 只 import 不得改；让各 agent 自己发明共享接口，必然在被 import 最多的文件上冲突。任务 B 依赖 A 时，给两边的第一条指令就是「先共同定下接口/DTO 签名再动手」。可见的量化佐证来自微软 Swarm Diaries 多代理实验：给 agents 加接口契约前后，质量分 28→68、分支冲突 3/6→0/4（※原文域名被拦，数字经搜索摘要，未能全文核实）。
2. **实现/评审分离**：评审者必须没见过实现过程——新会话或子代理只给 diff + 任务简述；用工具白名单强制只读（reviewer 定义里 tools: Read, Grep, Glob，由 harness 强制而非提示词自觉）；评审指令抄官方原文「对照 spec 逐条核对需求与边界用例是否有测试，只报影响正确性的缺口，skip style」——不写 skip style 的评审者永远能找出点什么，全修掉的结果是多余抽象层；输出显式 PASS/FAIL 而非自由文本。你库「三遍审查」已有骨架，增量是工具白名单与 PASS/FAIL。
3. **并行隔离**：每条写入线一个 git worktree（`claude -w`，或 subagent 加 isolation: worktree）；写入线 ≤2，外加任意只读线；按「文件所有权清单」硬分区，禁改清单外文件；一次只合一个分支、合并前 diff 对 main；警惕 worktree 不隔离的东西——共享数据库/端口/迁移、lockfile 冲突、「git 只比文本不比意图」的语义冲突；大规模机械改动用官方 /batch。
4. **计划即共享内存**：SPEC/plan 文件是你、实现者、评审者三方唯一共享物（访谈产出、含完成定义→干净上下文按 spec 实现→评审者对照同一份 spec 查缺口）；跨会话交接包固定四项——commit 哈希、变更的契约、验证目标、未决假设。
5. **审批门只放四处，其余放行**：门 1 计划后动手前（plan mode 人批）；门 2 合并/push 前——「don't push」这类口头约定会随 compaction 丢失，必须写成 deny 权限规则，PR 审查是 solo dev 唯一不可省的人审点；门 3 跨 agent 消息不作为授权——官方把 teammate 转述的「已批准」按不可信输入处理，自建编排照抄这条安全语义；门 4 放手前三问——spec 清楚吗、它能自检吗（测试/Stop hook/评审步骤）、允许它碰什么（权限规则/沙箱/worktree）。
6. **委派指令四要素**：明确目标、输出格式、建议的工具与来源、任务边界——短指令必然导致子代理重复劳动或误解（Anthropic 研究系统的教训）；简单查找 1 个 agent、直接对比 2-4 个，从 3 个起步，「3 个专注的胜过 5 个散的」。

### 5.3 哪些多代理玩法是噱头

| 玩法 | 判定 | 证据 |
|---|---|---|
| 数十 agent 蜂群 | 噱头 | 已核实证据：Anthropic 官方「多代理约 15x token、多数编码任务不适用」（5.1）、agent teams 官方自限（本表末行）、ruflo 审计（下行）。案例：Gas Town 高成本（Yegge 自述每月数千美元 API 费）与「agents 反复折腾编排系统本身而非推进应用」遭社区持续批评，2026-04 被 Yegge 的继任 SDK Gas City 取代、原项目趋于维护态——作者并未放弃蜂群路线，此案例只证成本高企，不可引为「作者都弃用了」；Codex 开发者：>2 并行子代理几乎总是 coordination tax（仅经搜索摘要，原文被拦截）；微软 Swarm Diaries 可核实的量化是契约前后对比而非单代理 vs 蜂群（已移作 5.2 第 1 条佐证） |
| 吹牛编排器（ruflo 类） | 噱头 | 社区审计「99% Theater, 1% Real」：300+ MCP 工具约 97% 是无执行后端的 stub；仓内 2026-05-29 审计证实多项宣传指标系伪造（benchmark recall 硬编码 0.99、Flash Attention 加速比由 Math.random() 运行时生成、totalTokensSaved 按次 +100 累加）；宣传的 84.8% SWE-bench 属历史营销数字，产生方式未能溯源；用户 issue 直言「退回裸 Claude Code 更有效」。通用教训：对「neural/swarm/N 倍提升」话术一律索要可复现证据 |
| 角色扮演代理团（BMAD 式 PM/架构师/QA） | 大半噱头 | 单代理 + 好计划已覆盖多数角色切换；留存价值是其文档产物结构，不是角色制 |
| 为省上下文拆 subagent | 已过时 | 官方亲自破除：fresh subagent 要重建主会话已有上下文，可能更慢；「running out of context is rarely the problem anymore」 |
| 同模型委派求更好答案 | 无效 | 官方破除：收益只有并行度和「没见过你推理的新鲜视角」 |
| agent teams 当主力 | 尚早 | 实验特性（环境变量手动开启）：不可 resume、任务状态滞后、权限提示全涌向 lead；官方自己建议入门只拿它做只读任务（评审/调研） |

真瓶颈是人：并行产出 10 个 PR 仍要你逐个审（SignalFire 对跑 150+ agents 的 CTO 访谈的一致结论）。solo dev 并行度超过「2-3 条写入线 + 若干只读线」后净收益为负。

## 6. 落地建议清单（全部待你拍板，本报告不自动实施）

### 建议采纳（7 项）

| # | 动作 | 内容要点 | 对应 |
|---|---|---|---|
| A1 | 新文件 process/multi-agent.md | 5.2 节六条协议 + 5.3 噱头表的结论版，控制在约 80 行；与 session-management.md 互链（它管单会话，这个管多会话/多 agent） | 第 5 节 |
| A2 | 新文件 templates/DESIGN.md.template | U1 反默认美学 + U2 token 固化结构 + U3 黑名单；首行写「任何 UI 任务先读本文件，它覆盖一切默认美学」；CLAUDE.md 行数预算表现无此文件，须同步补一行（建议 ≤80 行） | U1-U3 |
| A3 | 修改 process/review-checklist.md | 新增「UI/a11y 机检」节（U4+U5，约 15 行可判定条目）；AI 味清单加一行「状态四件套缺项」（F3） | U4 U5 F3 |
| A4 | 修改 process/definition-of-done.md | 第 1 节第 6 条升级：双视口截图（1280×800 + 375×812）+ console 零错误 | U6 |
| A5 | 新钩子 claude-code/hooks/pre-edit-migrations.sh | PreToolUse 匹配 Edit/Write，路径落在 migrations/ 目录即 exit 2；hooks.md 补安装说明（现 100/120 行，放得下）；B1-B2 同时写进两栈 README「## 6. 高频 AI 坑」（行数并入 A6 核对） | B1 B2 |
| A6 | 修改 stacks/python、stacks/go README（不开新节） | 栈 README 受 CLAUDE.md 结构约束：七节与 _template.md 一字不差、禁止新增节，故全部折进既有节——B4 B5 进「## 1. 选型清单」加行、B3 改/加「## 5. 参照模式」日志示例、B7 与 A5 的 B1-B2 进「## 6. 高频 AI 坑」。行数核对（上限 200）：go 现 166，余 34 行，全部增量须压在约 20 行内，超限先修剪现有条目；python 现 120，余 80 行，宽裕 | B3-B5 B7 |
| A7 | 修改本库 CLAUDE.md（维护规则） | 吸收 superpowers 两条元方法：新 prose 规则入库前用 fresh 会话压力测试 + 对照组（对照组不犯错就不写）；按失败类型选规则形态（禁止式只治明知故犯、形状问题写正向配方、禁「除非必要」式软化语）；纪律类规则旁配「借口→反驳」小表。另为「新增规则的唯一入口」增设第二入口：外部调研引入的预防性规则须注明调研来源、标〔试用〕，半年内未在真实任务中用上即删——不加这条，本报告的 prose 增量按现行「没有 pain-log 来源一律拒收」会被当场拒收 | 2.1 节 + 本节自查 |

### 可选（5 项）

| # | 动作 | 说明 |
|---|---|---|
| O1 | templates/plan.md.template 加「交接包」四字段（commit 哈希/变更契约/验证目标/未决假设），计划正文「只记决策（签名/断言/规格值）不写全代码」 | 来自 superpowers v6 演进终点与 handoff 实践 |
| O2 | process/task-brief.md M 级 UI 任务加 ASCII 线框 + 参照物栏（U7） | 低成本，还省 token |
| O3 | 安装官方 frontend-design skill（SKILL.md 约 1.3-1.5k 词 ≈2k token，按需加载；官方博客的「~400 token」指文中展示的提示词版本）替代自建美学 prose 的一部分 | 与 A2 并存：skill 管品味唤起，DESIGN.md 管项目一致性 |
| O4 | 契约先行链（F1 F2 B6）：下一个真实 API 项目启用 orval/oasdiff/Spectral | 一次性配置成本中等，没有 API 项目时空转无意义 |
| O5 | 安全双层落地（B8）：gitleaks pre-commit + CI、uv audit/govulncheck、weekly osv-scanner 进 CI 模板 | 写一次零日常开销；三栈均已建档，落为各栈 configs/ 下的 CI 模板并在「## 7. 配置文件索引」挂行 |

### 不建议（6 项）

| # | 不做什么 | 理由 |
|---|---|---|
| N1 | 整装采用 superpowers / trellis / spec-kit / BMAD | 为 20% 价值背 100% 重量；值得的部分已按条拆进 A1-A7 与第 4 节 |
| N2 | 安装 ui-ux-pro-max 整包 | 约八成文件用不上（上界推算，见 2.2）、自动触发率 50%；用 A2 + O3（合计约 2k 余 token 且按需加载）替代；真遇长尾行业再临时检索它的 CSV |
| N3 | ruflo/claude-flow 及一切 swarm 编排器 | 实证造假 + stub 工具，见 5.3 |
| N4 | 第三方 VRT SaaS / 全站像素快照 | Lost Pixel 已归档（2026-04）、Argos 实际 SaaS 化；AI 高频改 UI 下甄别成本大于检出收益（F6 的限定范围版已够） |
| N5 | agent teams 作为主力工作流 | 实验特性、不可 resume、状态滞后；只拿来做只读评审/调研 |
| N6 | 把测试比例数字（60/20/15 之类）写进规则库 | 全部是 vendor 拍脑袋数字，无任何实证来源 |

**若采纳，建议的动手顺序**（按「一次投入、复利周期、依赖关系」排）：

1. A7（库维护元方法）最先——它改变之后每条规则的入库方式，写一次管全库。
2. A4 + A3（DoD 升级、review-checklist 增节）——都是在现有文件上加十几行，当天见效。
3. A2 + O3（DESIGN.md 模板 + 官方 frontend-design skill）——下一个带 UI 的任务开工前备好。
4. A5 + A6（迁移钩子 + 两栈 README 增量）——下一个碰数据库的任务前备好；钩子可直接仿 stop-verify.sh 的结构；README 增量只折进既有七节、不开新节，动笔前按 A6 的行数核对过一遍 200 行上限。
5. A1（multi-agent.md）——不急：你真要开第二条并行写入线的那天再写也来得及，但契约先行与只读 reviewer 两条可提前进 CLAUDE.md.template。
6. O1/O2/O4 挂在各自触发条件上（见表）；O5 无前置依赖、有空即做——均不设截止。

与库哲学的一致性自查：以上全部增量里，prose 规则只占少数（U1-U3 美学、B7 mock 政策、协作协议），其余都是配置/钩子/模板/清单——符合「能被工具强制的不写成文字」；每条都标了可判定口径，符合「规则可判定违反与否」。两处与库现行硬规则相抵，已在方案内化解、不冒充「全部符合」：(1) 结构约束——栈 README 固定七节不可新增、200 行上限，故 4.2/4.3 的增量全部折进既有节并逐文件核对行数（见第 4 节开头与 A6）；templates/DESIGN.md.template 是行数预算表没有的新文件，补预算行已并进 A2。(2) 规则入口——本批增量来源是外部调研而非 pain-log，按「唯一入口」会被当场拒收，故 A7 先为其开「外部调研〔试用〕」第二入口；落地节奏按形态分：文件/钩子/模板/配置先落地，prose 规则一律带〔试用〕标记，在真实项目里踩过一次再转正，半年没用上即删。

## 7. 来源汇总（合并去重）

带 ※ 的域名在调研会话网络白名单外，内容经搜索摘要或多个二手来源交叉验证，置信度打折。

**点名项目一手材料**
- superpowers：github.com/obra/superpowers（README、RELEASE-NOTES v2.0.0→v7.0.2、hooks/session-start 源码、全部 15 篇 SKILL.md 原文实测字数；星数经 GitHub API 核实）
- ui-ux-pro-max：github.com/nextlevelbuilder/ui-ux-pro-max-skill（README/SKILL.md/data/styles.csv/issues 直接核读）· 同仓 issues/484（召回率 50% 实测；82% 未读为作者推算上界）· github.com/hylarucoder/benchmark-skill-ui-ux-pro-max · github.com/bbylw/ui-ux-pro-max-skill-cn · github.com/tenfoldmarc/website-builder-setup · star-history.com
- trellis：github.com/mindfold-ai/Trellis（README/README_CN/.trellis/workflow.md/parallel.prompt.md/issues，GitHub API 核实）· github.com/Tiger-zzZ/mini-trellis（重量实测分叉）· github.com/langadventurellc/task-trellis-mcp · deepwiki.com/mindfold-ai/Trellis · x.com/kevinma_dev_zh ·※docs.trytrellis.app ·※v2ex.com/t/1206360 ·※cnblogs.com/dingxingdi

**Anthropic 官方**
- anthropic.com/engineering/building-effective-agents · …/multi-agent-research-system · …/effective-context-engineering-for-ai-agents
- code.claude.com/docs/en/agent-teams · …/sub-agents · …/best-practices · …/hooks
- claude.com/blog/how-anthropic-teams-use-claude-code · claude.com/blog/improving-frontend-design-through-skills
- platform.claude.com/cookbook/coding-prompting-for-frontend-aesthetics · github.com/anthropics/skills（frontend-design、web-artifacts-builder 等 19 个官方 skill）· github.com/anthropics/claude-plugins-official

**生态与框架**
- github.com/github/spec-kit · github.com/Fission-AI/OpenSpec · github.com/bmad-code-org/BMAD-METHOD/releases · blog.bmadcode.com/changelog · github.com/buildermethods/agent-os/discussions/310（v3 公告）· github.com/eyaltoledano/claude-task-master/releases
- ruflo 审计：github.com/ruvnet/ruflo/discussions/1513 · 同仓 docs/reviews/intelligence-system-audit-2026-05-29.md · 同仓 issues/958 · alphasignalai.substack.com
- SDD 批评：※instil.co（spec-driven-development-is-dead）· martinelli.ch · hiddedesmet.com · tessl.io/blog（spec-kit 评测）· dev.to/krlz（SDD in 2026）· medium.com/it-chronicles
- Kiro：infoq.com/news/2025/08/aws-kiro-spec-driven-agent · petermcaree.com · gilricardo.com
- 标准化：thenewstack.io（Agent Skills 捐基金会）· claude-world.com · developersdigest.tech · news.ycombinator.com/item?id=49760187（Claude Code 读 AGENTS.md）
- 方法论与轻量派：github.com/humanlayer/12-factor-agents · github.com/humanlayer/advanced-context-engineering-for-coding-agents · humanlayer.dev/blog/skill-issue · lucumr.pocoo.org（2025/7/30、2025/11/21、2026/1/31 三篇）

**superpowers 口碑与解读**
- ※news.ycombinator.com：45547344（发布帖）· 45550550（人读费解）· 48015397（我卸了）· 48739459（v6 省 token 获证实）· 47623101 · 47418177（均经搜索摘要）
- ※blog.fsck.com/2025/10/09/superpowers ·※simonwillison.net/2025/Oct/10/superpowers（core <2k tokens）· oreilly.com/radar/superpowers-for-humans · mlops.community 访谈 · heavybit.com ep-36 · larridin.com（Specs are the thing that matters now）· dev.to/tumf ·※mcp.directory（bloated, not wrong）· datacamp.com、trevorlasn.com 教程 · joanmedia.dev · rulesell.com

**UI/UX 实践**
- github.com/vercel-labs/web-interface-guidelines（约 100 条 MUST/SHOULD/NEVER）· github.com/OneRedOak/claude-code-workflows（design-review 7 阶段 + CLAUDE.md snippet）
- w3.org/WAI/WCAG22/Understanding/target-size-minimum（SC 2.5.8）· deque.com（自动化覆盖 57% 自报口径）
- medium.com/@calufa（ASCII-driven development）· medium.com/@rotbart（DOM 测量替代像素 diff）· claudeskills.info ·※skiln.co ·※note.com/ai_smallbiz_lab（frontend-design 对比评测）·※daily.dev（demo 千篇一律批评）·※cnblogs.com/warrenwt（2 万 token 实测）·※juejin.cn/post/7656025505837875243 ·※snyk.io ·※theneurondaily.com

**前端实践**
- 契约先行：github.com/hey-api/openapi-ts · github.com/orval-labs/orval · dev.to/nyaomaru（codegen 四方对比）· saschb2b.com · registry.npmjs.org/@hey-api/openapi-ts
- MSW：qaskills.sh · stevekinney.com/courses/enterprise-ui · medium.com/devsphere（MSW+OpenAPI）
- Storybook/组件目录：storybook.js.org/docs/ai · storybook.js.org/announce/sb9 · github.com/storybookjs/mcp · ui.shadcn.com/docs/mcp · polprog.pl（Ladle 对比）· alternativeto.net（SB10）· yashveerlabs ·※blog.logrocket.com
- 测试与 VRT：github.com/vitest-dev/vitest/releases/tag/v4.0.0 · infoq.com（Vitest 4 浏览器模式）·※voidzero.dev · css-tricks.com（Playwright VRT）· testquality.com · desplega.ai · arxiv.org/html/2507.10062v2（LLMShot）· cloudzy.com（Argos/Lost Pixel 对比）· dev.to/playwright（1.56 agents）· testdino.com
- 错误/状态：tanstack.com/query（QueryErrorResetBoundary、suspense 文档）·※tkdodo.eu（经 skills.lc 二手）· nextjs.org/docs（loading 约定）· stackpractices.com
- React Compiler：react.dev/blog（compiler RC→1.0）· infoq.com（Meta 部署）
- AGENTS.md：iuriio.com field guide · blog.buildbetter.ai · ap7i.com、qaskills.sh、daily.dev（截图自查回路三篇）

**后端实践**
- API 标准：github.com/zalando/restful-api-guidelines（pagination/compatibility 章节原文已读）· github.com/OAI/OpenAPI-Specification（3.2.0 正式文本）· datatracker.ietf.org（Idempotency-Key I-D -07）· swagger.io、redocly.com、codecentric.de（RFC 9457）
- 契约门禁：github.com/oasdiff/oasdiff（及 action）· github.com/supabase/auth/pull/2547（Spectral+Schemathesis 双门禁样例）· scalar.com（Spectral rules）· dev.to/doctave（FastAPI 导出 spec）· github.com/danielgtaylor/huma · github.com/oapi-codegen/oapi-codegen · devblogs.microsoft.com（TypeSpec）· sookocheff.com · dev.to/jeff_pdc（API-first 2026）
- 迁移：※atlasgo.io（ai-safe-migrations、The Myth of Down Migrations）·※prisma.io/blog（AGENTS.md for databases）· github.com/sbdchd/squawk ·※dev.to/yureki_lab · claude-code-examples.vercel.app（PreToolUse hook 教程）
- 可观测：charity.wtf（wide events）· blog.alcazarsec.com · karanftd.com（canonical vs structured）· redlib.hbubli.cc/r/golang（OTel 对 side project 太重）
- 安全：github.com/gitleaks/gitleaks · kunalganglani.com（双层扫描）· oneuptime.com（osv-scanner v2 用法）· pydevtools.com ·※dev.to（uv audit vs pip-audit 实测）
- 测试调整：※news.ycombinator.com 45958225、46424200、49394427、39531536（Testcontainers）· qatechtools.com（AI over-mock）· bug0.com · shiplight.ai

**多 agent 协作**
- ※cognition.ai/blog/dont-build-multi-agents ·※cognition.com/blog/multi-agents-working（均经二手交叉验证）
- steve-yegge.medium.com（Gas Town、Welcome to Gas City）· producthunt.com/p/gas-city（Gas City 1.0 发布页，自述为 Gas Town successor）· ericfode.github.io/agent-harness-wiki（Gas Town 趋于 maintenance mode）· paddo.dev · rywalker.com ·※techcommunity.microsoft.com（Swarm Diaries，域名被拦仅搜索摘要）· signalfire.com（CTO 访谈）·※the-decoder.com（Codex 开发者 coordination tax，仅搜索摘要）
- trigger.dev/blog（worktree 不隔离运行时共享态）· dev.to/kolodziejczykamil、understandingdata.com、dev.to/kgjohnson（契约先行/交接包）· builder.io、alexop.dev（agent teams 实测）·※news.ycombinator.com 46902368、50284255（后台 agent token 开销 + 官方回应）、46990733

**本次调研的总体查证缺口**：BMAD v7 是否正式发布、Kiro 确切 GA 日期（各源冲突）、superpowers 全链 token 经济性（无权威基准）、测试金字塔比例（无实证）、Idempotency-Key 草案 2026 年进展、ui-ux-pro-max 作者身份与引爆帖、trellis 的西方社区声量（基本不存在）、ruflo 宣传过的 84.8% SWE-bench 的产生方式、微软 Swarm Diaries 原文全文（域名被拦，仅搜索摘要）——均未能定论，正文已就地标注。
