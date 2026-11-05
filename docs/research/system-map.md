> 归档调研报告，只读参考、不是规则。回答的问题：业务建模（DDD 边界上下文）→ 数据库模型 → 代码对象（属性/行为/状态机）→ 接口 → 调用链，各层零散的可视化，能否一套元数据串起来并动态刷新？没人整合过吗？是否有价值？

# 业务到代码的「活地图」：价值判断与落地方案（2026-11）
>
> 评估准绳：一个人 + Claude Code，TS/React、Python、Go 三栈，一切以「一人+AI」的维护成本为准。
> 本报告综合 8 份专题调研（历史教训 / 派生与强制 / AI 活文档 / 契约层 / 轻量 DDD / 运行时视角 / 评审瓶颈 / 整合平台），证据与仓库活跃度截至 2026-11-05。

## 0. TL;DR

1. **整合有人做过，而且死了三波**：UML/MDA CASE 工具（Rational Rose 系 2011–2024 陆续停服）、代码地图创业公司（Sourcetrail/CodeSee/mutable.ai/stack-graphs——归档、被收购或并入巨头，详见 1.1）、企业 IDP/EA 平台（Backstage/LeanIX 活着，但靠专职工程师或架构部门预算喂养）。
2. **「一套元数据总线 + 双向同步 + 动态刷新」的单一产品至今不存在**。2025 年 arXiv《Code Digital Twin》论文把你的设想原样提出，结论：学界确认需求成立，也确认无人实现。不是你没搜到。
3. **你的设想方向对、形态错**：「一份模型多视图」理论早已成熟（Kruchten 4+1 → ISO 42010 → C4），死的从来不是理论，而是「单一总模型 + 双向同步（round-trip）」这个被历史反复证伪的实现形态——两份真相的同步成本随规模超线性，被放弃的永远是模型。正确形态：**每层一个机器可校验的真源，视图只许单向派生（窄域内模型→代码，或代码→视图按需提取），层间靠稳定标识符（上下文名/表名/operationId/模块路径）松耦合对齐**。
4. **LLM 真正改变的一环**：「从代码派生视图」和「随代码改动顺手更新小模型文件」的边际成本被打到近零——**AI 本身就是你要的刷新引擎**，不需要任何平台。巨头已下场验证赛道（DeepWiki launch 时预索引 5 万+ 热门公共仓库、公共库免费按需索引，Google Code Wiki 2025-11 公测、Greptile B 轮 $750M 估值）。
5. **但 LLM 没改变两件事**：生成图的正确性无法证明、只能抽查（blopker 对其维护的 Codebook 的 DeepWiki 页评价：内容「从令人困惑到误导到彻底错误」）；业务意图派生不出来，必须由人写成小文件（Vernon 2026：LLM 自动建领域模型「rarely better than unacceptable」）。
6. **机械派生五层（DB/API/依赖边界/状态机/调用链）今天即可全部免费落地**，三栈覆盖、每层半天内——选型见 4.0 一张表。
7. **AI 增量维护层只留四个小文件**：GLOSSARY.md（术语）、CONTEXT-MAP.md（上下文一张表）、docs/adr/（为什么）、C4 L1/L2 一张图。AI 在改代码的同一 PR 里顺手改，人审 diff——这是个人唯一可持续的「动态刷新」机制。
8. **评审瓶颈有硬数据**（Harvard/Jellyfish 72.6 万员工遥测：AI 产码 +30%、PR 合并时长 +49%；80% 公司已用 AI 评审仍无解）。解法不是更强的评审 bot，而是**评审对象上移**：先看契约 diff（schema/API/边界红灯）和 plan，实现层抽查。
9. **明确不做**：大一统平台（Backstage/EA/CAST）、任何双向同步工具、自建代码知识图谱基建（Neo4j/Glean/Sourcegraph）、把全自动逆向生成的图当真源。对个人全是纯负债。

## 1. 直接回答：有没有人做过整合？价值判断

### 1.1 有没有人做过？——做过，三波，没有一个活成你设想的样子

**第一波（1995–2014）：UML/MDA 的「总模型」。** 目标与你的设想几乎同构：一个元模型（MOF/UML 14 种图）承载业务到代码，工具负责双向同步（round-trip）。结局：

- Rational Rose 各分支自 2011 年起陆续停服，最后的 Rose RealTime 2024-10-31 正式 EOL；
- ICSE 2013 对 50 名职业开发者的访谈：35 人完全不用 UML，11 人仅选择性非正式使用，0 人无条件支持；
- OMG 自己的早期白皮书承认 round-trip 支持「不完整、属未来目标」；实践者复盘（vhanniet 2011）直指 round-trip 正是「UML 多年无法被采用的主因之一」。

**第二波（2015–2024）：代码地图 / 活文档创业。** 从代码自动生成可视化并承诺保持更新：

- Sourcetrail：2021-12 归档（官方称 2021 年底停止维护；社区 fork 2026 年已砍掉 Python 支持，对你的栈无用）；
- CodeSee：融资 $10M，2024-05 被 GitKraken 收购后独立产品与品牌消失；
- mutable.ai（Auto Wiki 鼻祖）：2024 底创始人入职 Google，技术化为 Google Code Wiki；
- Swimm（专利级文档 auto-sync）：2025 转型 COBOL 遗留系统现代化，auto-sync 实际只「标记过期」，维护仍靠人；
- GitHub stack-graphs：2025-09 归档；
- IcePanel 的「代码↔模型链接」功能「因问题太多」被官方下线。

死因一致：给人看的静态地图没人付费；全自动生成的图「1:1 准确但对人没用」（model-code gap，见 2.2）；「保持同步」最终仍是人工成本。

**第三波（2020– ）：企业端活着的两类，都改写了题目。**

- IDP/软件目录（Backstage/Port/Cortex/OpsLevel）：只串「服务级」元数据（归属/依赖/文档/评分），不下探到代码对象与业务语义。Backstage 自托管的公认成本是 ≥3 名专职工程师；目录照样腐化，社区共识解法恰恰是「元数据以 YAML 随代码入库 + CI 强制校验」——腐化是治理问题，不是工具问题。
- EA 工具（LeanIX 2023 被 SAP 收购、Ardoq）与 CAST Imaging：靠连接器 + 专职治理人员，按应用/席位计价（CAST 第三方报价 $2.1k–10.2k/应用），买方是架构部门。评审明言「连接器仍需数据管家」：自动采集只减少、不消除人工治理。

**学术确认**：arXiv 2503.07967《Code Digital Twin》（2025-03）把「隐性知识/决策意图与代码工件持续配对、服务 LLM」原样提出——仍是愿景论文，无可用实现。DDD 侧同样空白：「图板→DSL」桥接（miro2cml）停在 2022；Context Mapper 的「从代码反推 bounded context」discovery 库只支持 Spring Boot 且 2024-08 停更；为 AI 设计的文本 EventStorming 板（kad-xyz/storm）2026 年才出现、0 star。**这是真实缺口，不是检索盲区。**

### 1.2 价值判断：部分 yes，边界如下

- **「各层可视化 + 动态刷新」——yes，有价值且现在可落地。** 每一层都有活跃的派生工具（第 4 节），LLM 把最贵的「保持更新」一环变成近零成本。四个痛点里三个半能被直接缓解（第 5 节）。
- **「一套元数据串起来」——no，如果指单一元数据库/总模型/统一平台。** 三波死亡 + Code Digital Twin 无实现 + Backstage 治理教训，证据链完整：全串方案的真实成本是一支治理团队；个人做全串必死于喂数据。
- **「串起来」——部分 yes，如果降级为「层间用稳定标识符对齐」**（做法见 4.3）。这不需要平台，需要的是命名纪律——而命名纪律恰好是 CLAUDE.md + CI 能强制的东西。
- **「或许这是不同的视角」——你的直觉是对的，且有标准背书。** ISO/IEC/IEEE 42010 的核心正是「先识别利益相关者的关注点，再选视点（viewpoint）生成视图」。视角是第一公民，总模型不是。AI 时代的新坑也在这：不先告诉 AI「这张图要回答什么问题、在哪个抽象层级」，得到的就是 2005 年逆向工程杂乱图的高清复刻。

## 2. 历史为什么失败：MDA/round-trip 的死因

### 2.1 死因不是工具不成熟，是结构性的

1. **两份真相**。模型与代码各自可改，双向保持一致的成本随系统规模超线性增长，最终总有一份被放弃——被放弃的总是模型。
2. **通用大一统元模型输给小而专的 DSL**。Whittle/Hutchinson 工业实证（450 人问卷 + 22 访谈 + 企业案例）：MDE 成功案例全是「窄域 DSL 生成系统局部」（嵌入式等），从不是整系统建模；且成败主因是组织/社会因素而非技术。
3. **「UML 当编程语言」连拥护者都认为是坏主意**（Hillel Wayne《Why UML "Really" Died》与 UML 2.0 标准化亲历者 Tratt 的自述互证）；当「设计草图」的用法也从约 2004 年起缓慢消退。

**重要校准**：「MDA 失败」≠「建模/代码生成失败」。窄域单向生成一直成功：schema→代码、protobuf、OpenAPI codegen、IaC 全是活着的「模型驱动」。红线针对的是「通用模型 + 双向同步」这个组合，别把红线画过头。

### 2.2 「一份模型多视图」理论一直活着，死的只是载体

- 理论谱系：Kruchten 4+1（1995，不同利益相关者看不同视图）→ ISO/IEC/IEEE 42010:2022（关注点→视点→视图，视图间有对应规则）→ C4（context/container/component/code 四级缩放，抽象优先）。
- 当代形态：Simon Brown「diagrams as code 2.0」——一份模型派生多视图；1.0（PlantUML/Mermaid 每图一个源文件）的病根正是多份图源互相漂移。
- 风向标：Structurizr 2026 年仓库大重组后整体转向 AI（官方 MCP server，主张「agent 从代码库生成 DSL workspace」，理由是 agent 不擅长操作 UI 但擅长生成文本）。但**模型本身始终是手写声明，官方从不承诺与代码自动同步**；Brown 一贯立场：通用逆向工程只会得到「显示一切的杂乱图」。
- 失败的学名：**model-code gap**（Fairbanks 概念，Simon Brown/IcePanel 反复引用）——代码里只有结构，架构意图与业务语义不在任何工件里，因此从代码自动生成的图「准确但无用」，C4 上两层原则上无法从代码推导。IcePanel 自己的结论：低层视图自动化、高层保持手工。

### 2.3 活下来的文档形态，和四条红线

幸存者共性：**在承重路径上**——被执行（测试/BDD）、被编译（类型/schema）、随代码进 PR 被评审（ADR/DSL）的能活；挂在 wiki 或独立建模工具里的会死。两个典型：

- **ADR**（Nygard 2011，五段式，append-only，被取代就新开一篇）：只记带日期的「为什么」，不对「现状」做会过期的断言，所以不腐。ThoughtWorks Radar 2017 Trial → 2018 Adopt。
- **Living Documentation**（Martraire）：稳定知识手写 evergreen 文档，易变知识从代码+注解派生（living glossary / living diagram）；总开关「The Default Is Don't」——只有长期有价值的知识才值得文档化。

四条红线（后文方案全部据此设计）：

1. 双向同步必死，只许单向派生；
2. 腐烂速度 = 细节层级 × 变更频率——bounded context/容器级以月计变化可手维护，组件/类/调用链随 commit 变必须按需生成、用完即弃；
3. 不在承重路径上的文档必腐；
4. 大一统元模型输给小 DSL。

## 3. LLM 改变了什么

### 3.1 变了的那一环经济学

MDA 时代有两个死结：**图要人画**、**模型与代码的同步靠人工**。LLM 把这两件事的边际成本打到近零——AI 成了廉价同步引擎，CI 成了触发器。这正是 round-trip 死后留下的唯一活路（代码→视图单向派生）第一次对个人可行。

另一个关键变化：**「给 AI 的地图」和「给人的地图」正式分叉。**

- 给 AI：aider 用 repo map（tree-sitter 抽符号 + PageRank）压缩仓库骨架塞 prompt；Cline 与 Claude Code 干脆不建索引，靠 agentic grep/读文件（Cline 官方论证：chunk-embedding 撕裂代码逻辑、索引保鲜是负担）；Cursor 走向量索引。
- 结论：强模型自己能导航代码。**可视化的真正受益者是人**——你的判断依据、评审效率、记忆外化（痛点 2/3/4）。方案设计的反直觉要点：不要为 AI 建图，要为自己建图，AI 负责维护它。

### 3.2 新物种各自做到哪一步、还差什么

| 物种 | 代表（活跃度） | 做到了 | 还差 |
|---|---|---|---|
| AI 仓库 wiki | DeepWiki（launch 预索引 5 万+ 热门公共库/约 40 亿行代码，公共库免费按需索引，无公开当前总量）、Google Code Wiki（2025-11 公测）、deepwiki-open（18.4k★ 自托管） | repo→架构 wiki+图+带源码引用的问答；用「按需再生成」替代「持续维护」 | 正确性无验证（有实锤误判）；私库付费或烧自己 key；滞后于未 push 代码 |
| CI 刷新架构图 | CodeBoarding（2.7k★，MIT，静态分析+LLM 分层出图，GitHub Action 增量刷新，PR 贴「改动落在架构图哪里」） | 最接近你设想的「动态刷新代码地图」现成品；覆盖 Py/TS/Go | 增量刷新 0.14 刚加入，成熟度未知；图仍需抽查 |
| 代码知识图谱 | code-graph-rag（5.3k★，MCP）、CodexGraph（NAACL 2025）、Codebase-Memory（tree-sitter+SQLite） | 结构感知检索可行；嵌入式存储免部署 | 未成主流；主流代理靠 grep 已够；个人自建图库必亏 |
| 运行时证据给 AI | Sentry MCP+Seer、Logfire MCP、Chrome DevTools MCP（Chrome 官方）、otel-desktop-viewer（自带 agent skill） | 「AI 吃运行时证据而非盲检索代码」成产品形态，接口收敛到 MCP | root cause 质量全是厂商自述；Go 无成熟自动插桩 |
| 评审上下文 | Greptile（全库图索引评审，B 轮 $50M、估值 $750M）、CodeRabbit Change Stack（preview 功能：PR 切层+自动配时序图/类图/ERD） | 「评审需要系统级上下文而非 diff」成行业共识 | Harvard 数据：80% 公司用 AI 评审，合并时长照涨 49%——瓶颈在人对业务意图的判断 |
| 业务意图留痕 | GitHub spec-kit（147k★）、AWS Kiro、AGENTS.md（>2 万仓库） | spec/constitution 进仓库是目前唯一可行的「业务→代码」载体 | spec-as-source（spec 为唯一可编辑工件）无任何工具实现（Böckeler 判断）；被批产出大量难审 markdown |
| 建模工具转 AI | Structurizr MCP、Stately Agent、kad-xyz/storm | as-code 模型天然适合 agent 读写 | 模型仍须人设计；storm 太新（0★） |

### 3.3 没变的（也是方案要绕开的）

1. 生成内容正确性只能抽查无法证明——错图比没图更误导；生成物一旦被手改，立即重新掉进双真相陷阱。
2. 业务意图没有结构化双向载体：业务→代码仍是单向生成，不是 MDA 梦想的双向追溯。
3. 「生成容易、被读难」没人解决——没有流程让人真的去看图（本方案用「评审首屏=契约 diff」解决一半）。
4. 赛道死亡率依旧高：两三年内 CodeSee（2024-05 被收购）与 mutable.ai（2024-12 并入 Google）相继消失，Swimm 转向（2025）、aider 停更（2025-08 后无 release）。**选型铁律：产出物必须是仓库内的 markdown/Mermaid/文本——工具死了，产物还在。**

## 4. 分层方案

总原则（由 2.3 四条红线 + 幸存者形态推出）：

> 每层一个机器可校验的真源 → 视图全部派生、永不手改 → CI 做 drift 检查（真源变而工件未再生成则 fail）→ 层间靠稳定标识符对齐 → 只有「业务意图」层由人（+AI 代笔）维护为小文件。

### 4.0 全景一张表

| 层 | 真源 | 派生视图 | 刷新机制 | 强制机制 | 三栈工具 | 接入成本 |
|---|---|---|---|---|---|---|
| 业务意图/术语 | GLOSSARY.md、CONTEXT-MAP.md、spec/任务简述、docs/adr/ | 即文件本身（常驻上下文） | AI 同 PR 代笔，人审 diff | CLAUDE.md 约定 + 评审清单 | 纯 markdown，三栈同 | 半天建模板，此后分钟级 |
| 架构（C4 L1/L2） | 手写 as-code 模型（Mermaid/LikeC4/Structurizr DSL） | 上下文图、容器图 | 以月计手改（AI 代笔） | 进 PR 评审 | 三栈同 | 半天 |
| 依赖边界 | 规则文件（.dependency-cruiser.cjs / .importlinter / .go-arch-lint.yml） | mermaid/目录级折叠图，CI 自动出 | 每次 CI 重新生成 | lint 红灯即越界 | dependency-cruiser / import-linter / internal/+depguard | 每栈约 1 小时 |
| DB schema | 迁移后的真库 | dbdoc/（Markdown+Mermaid ER） | CI 再生成 | tbls diff + alembic check | tbls 三栈通吃；Prisma 加 dbml generator | 半天 |
| API 契约 | openapi.json / proto | 契约文档、TS 类型 | CI dump + codegen | oasdiff ERR 卡合并 / buf breaking | FastAPI 自动出 / Huma 或 oapi-codegen / openapi-typescript | 半天–1 天 |
| 状态机 | docs/state/*.md（Mermaid stateDiagram） | GitHub 原生渲染 | AI 同 PR 改图 | CLAUDE.md 约定 + 评审扫一眼 | 三栈同；复杂才上 XState | 零工具 |
| 调用链/运行时 | 结构化日志（+可选 OTel） | canonical log line、trace 瀑布 | 运行即产生 | 失败请求 100% 留痕 | pino / structlog / slog；otel-desktop-viewer 按需 | 1 天 |

### 4.1 机械派生并 diff 的层（真源=代码/库，CI 强制，零人工维护）

**DB schema。** 工具：**tbls**（Go 单二进制，MIT，v1.96.1 活跃）。`tbls doc` 从真库生成 `dbdoc/`（纯文本可 diff，GitHub 原生渲染 Mermaid ER）；`tbls diff` 在 CI 对比「库 vs 已提交文档」防漂移；`tbls lint` 查注释/外键规范。Python 加官方 `alembic check`（内置免费，注意先 upgrade head 再 check）。坑：ER 图别落成 SVG/PNG（diff 不可读）；CI 需一个跑完迁移的真库（SQLite 最省）。不选：Atlas（migrate lint 已移出免费层，付费面持续扩大）、SchemaSpy/Azimutt（定位是一次性探索，不是 diff/CI 流）。

**API 契约。** 工具：**oasdiff + oasdiff-action**（Apache-2.0，变更分级 ERR/WARN/INFO，PR 置顶评论自动更新，`--fail-on ERR` 卡合并）。产 spec：Python=FastAPI 自动出（CI dump 提交进仓库）；Go=Huma（code-first，运行时还按 schema 校验请求）或 oapi-codegen（spec-first，需跨语言共享时）；TS 消费端=openapi-typescript + openapi-fetch（单文件、最轻；要 TanStack hooks 才考虑 Orval）。gRPC/proto 用 bufbuild/buf-action（PR 默认跑 breaking 检测）。坑：忘了「导出 spec 进仓库」这步就比不到——所以 drift 检查必须进 CI，并把再生成命令写进钩子让 AI 自动跑。

**依赖边界（bounded context 的强制层——本方案收益/成本比最高的一层）。** 规则文件的三重身份：给人看的架构文档、给 AI 读的边界输入（CLAUDE.md 引用）、CI 硬门禁。AI 产码越界时 CI 直接红，AI 在循环里自己看到红自己修——架构层评审从人肉转给机器。

- TS/React：**dependency-cruiser**（7.4k★，单一维护者但十年持续发版）。`npx depcruise --init` 生成带注释配置（预置 no-circular/no-orphans 等），按业务模块补几条 forbidden 规则；同一配置出图：`--output-type mermaid`（贴 PR 即渲染）、`archi`（折叠到目录级）。存量项目用 `--ignore-known` 基线，先红新增、再渐进清偿；大仓加 `--cache`。编辑器即时反馈可并用 eslint-plugin-boundaries。
- Python：**import-linter**（内置 layers/forbidden/independence 等五种契约，约 10 行配置，层名本身就是架构文档）；或 tach（Rust 实现、快、`tach show` 出图，但维护主体是初创团队，长期性略逊）。
- Go：**internal/ 目录**（编译器强制，免费且无法绕过）+ **golangci-lint depguard**（几行 YAML 按前缀 deny）；要显式「组件→mayDependOn」再上 go-arch-lint。
- 纪律：规则条数保持个位数到十几条（fitness function 文献警告：规则太多会锁死架构）；这些工具只看静态 import，动态 import/依赖注入看不见。
- 本质：**业务语义（层叫什么、边界划哪）机器派生不出来，必须人定一次**——但这正是把业务知识固化为 AI 可读资产的最低成本形式，之后由 CI 保证它与代码不脱节。

**状态机。** 默认轻量约定：每个有状态实体一份 `docs/state/<实体>.md` 内嵌 Mermaid stateDiagram-v2 + 不变式清单，CLAUDE.md 约定「改状态逻辑必须同步改图」，PR 里是可读文本 diff，GitHub 原生渲染。只有真复杂的状态逻辑（向导流/播放器/长事务）才值得 XState（v5，范式侵入大；Studio 私有项目收费、双向 GitHub Sync 属 Pro 向，不碰；v6 alpha 期锁 v5）。

**调用链/运行时（分档开启）。**

- 第 1 档（必做，近零成本）：JSON 结构化日志 + request_id/trace_id 贯穿（TS=pino、Python=structlog、Go=slog，中间件生成 ID 注入 logger context）+ 每请求一条 canonical log line（Stripe 模式：30–50 字段宽事件——route、status、duration、db 次数、错误码）。日志落本地文件，Claude Code 直接 grep。**这就是穷人版调用链**；bug 定位流程固化为「复现→按 request_id 过滤→证据交给 agent」。失败请求 100% 保留。
- 第 2 档（TS/React 常备）：**Chrome DevTools MCP**（Chrome 官方）。前端 bug 从「人向 AI 描述现象」变成「agent 自己开页面看 console（带 source map）和 network」。用独立浏览器 profile。
- 第 3 档（按需启动）：OTel 只插桩 HTTP/DB/外呼三层 + **otel-desktop-viewer**（单二进制，brew 装，内存型「调试镜」非存档，自带 agent skill 供 Claude 查本地 trace）。调性能/串流程时才开；请求瀑布图就是动态刷新的调用链文档。单体别为「服务图」上 tracing——图上只有一个节点。
- 不做：自托管 SigNoz/Tempo 全家桶（4GB RAM 起步、配置面大）；AppMap 只在 TS/Py 项目轻度试用（跑测试→自动时序图，Go 无 agent，小众有停摆风险），不当基建。

### 4.2 AI 增量维护的层（真源=人审过的小 markdown，AI 代笔，变更随 PR）

这一层装机器派生不出来的东西：业务语义、意图、「为什么」。防腐靠三件事：**文件小**（常驻上下文有预算）、**随代码同 PR 改**（承重路径）、**人审 diff**（AI 代笔但不代拍板）。

1. **GLOSSARY.md**（仓库根）：条目格式学 mattpocock/skills——`**术语**: 一句话定义` + `_Avoid_: 禁用别名`，外加术语关系与已解决歧义两段。CLAUDE.md 加一行「命名前先查 GLOSSARY；新术语先 Reuse/Compose/Qualify，最后才造词」。术语在对话中敲定后立刻写入。三坑：别混入通用编程词；多上下文别用一个全局大词表硬盖（分治）；别名选一个 canonical 其余进 Avoid。**全部调研里 ROI 最高的一件**。
2. **CONTEXT-MAP.md**（仓库根）：一张 markdown 表——上下文 × 职责 × 对外接口 × 依赖方向。目录=bounded context；多上下文时每目录自带子 GLOSSARY + 子 CLAUDE.md（根文件保持 80–200 行）。不用 Context Mapper CML：学习曲线对单人不划算，markdown 表 + 4.1 的边界 linter 即等效。
3. **docs/adr/**：五段式、append-only；mattpocock 三条件收敛（难逆转 + 未来读者会惊讶 + 真实权衡过才写），防膨胀。CLAUDE.md 约定「改动触及旧决策时必须引用或新增 ADR」。直接命中「AI 让人判断没依据」「知识蒸发」。
4. **C4 L1/L2 一张图**：手工 as-code（Mermaid 起步；要「一模型多视图」再上 LikeC4 6.0k★ 或 Structurizr DSL），只画系统上下文 + 容器级（以月计变化，手维护可活）。L3 组件图按需让 AI 生成、用完即弃、不入库；L4 不画。
5. **复杂实体旁的同名 .md**（可选，只给核心域）：领域行为、不变式、「聚合=事务边界」一句话；形态参考 ddd-crew aggregate-design-canvas 裁剪版。这是 HN「Domain-Driven Agents」实践的折中形态。

**刷新机制就是 Claude Code 本身**：CLAUDE.md 约定「改码若引入新术语/新依赖方向/新状态/推翻旧决策，同一 PR 顺手更新对应文件」，人审这些小文件的 diff。这是 8 份调研收敛出的、个人唯一可持续的刷新方案——刷新引擎是 AI + code review，不是任何平台。空白点如实说：GLOSSARY/CONTEXT-MAP 没有现成 CI 校验工具（真实工具空白），只能靠评审清单与钩子提示兜底。

### 4.3 层间怎么「串」：稳定标识符，不是元数据总线

各层共享四类锚点：**bounded context 名**（=顶层目录名=CONTEXT-MAP 行=边界 linter 的 group 名）、**表名**（dbdoc/ 与 GLOSSARY 条目互指）、**operationId**（openapi.json 与调用方代码共用）、**模块路径**。两条纪律让它们真的串起来：

- GLOSSARY 是命名的唯一出处：表、接口、模块命名前先查它（CLAUDE.md 强制提示）；
- PR 描述必须带证据链：让 Claude Code 在 PR 描述里写明「动了哪个 context、哪张表、哪个 operationId、状态机是否变化」——人评审时先看锚点 diff，这就是跨层追溯的个人版，成本为零。

### 4.4 明确不做

大一统平台（Backstage/Port/Cortex/EA/CAST——等于给自己雇一个不存在的治理团队）；一切双向同步（Stately GitHub Sync、任何 round-trip 承诺）；自建索引基建（Neo4j 图谱/Glean/自托管 Sourcegraph——运维负资产）；把 DeepWiki/GitDiagram 生成物当真源（只当一次性快照与问答入口，需核验幻觉）；Sourcetrail 系与 madge（停更）；订阅制建模平台（oNote/Qlerify）。

## 5. 对四个痛点的逐一回应

先给总表，再逐条展开：

| 痛点 | 主解决层 | 兜底层 | 解决程度 |
|---|---|---|---|
| 1 AI 不懂业务 | GLOSSARY + CONTEXT-MAP + 任务简述（4.2） | 边界 linter 红灯（4.1） | 命名/边界可解；深层意图仍靠人审 plan |
| 2 人无判断依据 | C4 L1/L2 + dbdoc/ + openapi + ADR | 派生工件可验证 AI 的口头回答 | 结构性判断够用；跨层追溯变快但仍需现场查 |
| 3a 知识蒸发 | 派生文档（怎么做）+ ADR（为什么）+ GLOSSARY（是什么） | DeepWiki 类问答入口 | 解得最干净；靠钩子强制写入 |
| 3b bug 定位靠 AI 盲检索 | 调用链/运行时层（4.1 分档：request_id 日志→DevTools MCP→OTel） | A6 调试守则（先证据后改码） | 运行时证据替代盲检索；Go 自动插桩仍弱 |
| 4 评审瓶颈 | 契约 diff + 边界红灯（机器先审） | plan 先审、/code-review、分层读 diff | 低级错误大幅压缩；意图判断不可外包 |

**痛点 1：AI 写码不懂业务。**
- 被哪层解决：4.2 的 GLOSSARY + CONTEXT-MAP + 任务简述（你已有）喂意图；4.1 的边界 linter 兜底强制——AI 越界 CI 直接红。
- 解决到什么程度：**命名与边界层面基本可解**。间接证据：DomainCodeBench 显示 prompt 注入领域知识平均提升约 38%（注意测的是领域库知识，外推到业务文档要谨慎）；TOSEM 2025 实证同方向。深层业务意图仍靠人审 plan——Vernon 的结论成立：**模型由人设计，AI 在指导下产码，别指望 AI 替你建模**。

**痛点 2：人做判断没依据。**
- 被哪层解决：判断时打开固定四件套——C4 L1/L2（系统长什么样）、dbdoc/（数据长什么样）、openapi.json（对外承诺什么）、docs/adr/（当年为什么这么定）。全部是派生物或人审过的小文件，可信度有保障。
- 解决到什么程度：**结构性判断够用**。跨层追溯（「这字段改了影响哪个接口」）仍要 AI 现场查，但有锚点后查得快、且结果可对着派生工件验证，而不是听 AI 空口说。

**痛点 3：知识蒸发、每次重答；bug 定位时 AI 还要盲检索代码。**
- 被哪层解决（3a 知识蒸发）：把三类知识分流落盘——「怎么实现的」→派生文档自动回答（dbdoc/openapi/依赖图/状态图，CI 每次刷新，永不过期）；「为什么这样做」→ADR；「这词什么意思/边界在哪」→GLOSSARY/CONTEXT-MAP。补充问答入口：DeepWiki（第三方库）/deepwiki-open（私库自托管）。
- 被哪层解决（3b bug 定位）：换流程，不加平台——把「人向 AI 描述现象→AI 盲检索代码猜」换成「复现→按 request_id 过滤结构化日志（前端加 Chrome DevTools MCP 直接看 console/network）→运行时证据直接交给 agent」（4.1 调用链层分档）。接入成本即 4.0 表调用链行的 1 天，守则落点为 A6。
- 解决到什么程度：**3a 是四个痛点里解得最干净的一个**；3b 让 bug 定位从「猜」变「查」，但 Go 侧无成熟自动插桩、深层逻辑 bug 仍需人缩小范围。代价：写入纪律必须钩子化（stop 钩子/评审清单强制），不能靠人记——「CI 没配 drift 检查的派生工件会烂掉」是所有调研的通病警告。

**痛点 4：人工评审跟不上 AI 产码。**
- 被哪层解决（三手组合）：
  1. 架构层评审转给机器：边界 linter 红灯、oasdiff ERR 卡合并、tbls diff——AI 在循环里自己看到红自己修，这些问题到不了你面前；
  2. 评审对象上移：先审 plan（2 分钟清单：假设/边界/测试点），再按「契约 diff → 测试 → 实现」顺序读，高风险路径才逐行（此顺序同时见于 CodeRabbit 官方指南与 Pragmatic Engineer 报道的团队实践）；
  3. push 前 Claude Code 自带 /code-review + /security-review 做第一道闸（独立会话跑评审，避免「自己批改自己」的同上下文偏置）。
- 解决到什么程度：**低级错误与越界的评审时间大幅压缩；「是否符合业务意图」的判断不可外包**。Harvard 数据（80% 公司用 AI 评审、合并时长照涨 49%）说明加 bot 不解决意图判断——解决它的是痛点 1/2 的前置图景，两者互补。个人项目的关键 nuance：你的真实对照物是「没人审」（Odoo 实验里 138 个 PR 上 AI 是唯一评审），AI 评审净收益为正，但必须降噪（关 nitpick 类评论）——噪音会训练你连真命中一起忽略。另一硬规则：**CLAUDE.md 明文禁止 agent 删/跳过测试**（Kent Beck 实测 agent 会以删测试换通过）。

## 6. 落地到你策略库的建议清单（全部待你拍板，本报告不自动实施）

与库哲学的衔接：每条都过了三道筛——**能被工具强制的进钩子/CI、不写散文**；**常驻上下文只新增 GLOSSARY/CONTEXT-MAP 两个小文件的引用**；**每条应在 docs/pain-log.md 里有对应痛点来源**（本报告第 5 节即来源）。

### 建议采纳（直接对准痛点；一次性成本除 A3 外各半天内）

| # | 动作 | 落点（你的仓库） |
|---|---|---|
| A1 | 新增 GLOSSARY.md 与 CONTEXT-MAP.md 模板（含条目格式、Reuse/Compose/Qualify 命名规则、三坑清单）；CLAUDE.md 模板的「模块地图节」升级为指向这两个文件 + 证据链 PR 描述约定（4.3） | 新增 `universal/glossary-template.md`、`universal/context-map-template.md`；修改 `CLAUDE.md` 模板相应节 |
| A2 | 三栈边界 linter 进选型与配置：TS=dependency-cruiser（含 `--ignore-known` 存量基线策略）、Python=import-linter、Go=internal/+depguard；写明规则条数上限（≤15）与「层名即文档」原则 | 修改 `stacks/typescript-react/README.md`、`stacks/python/README.md`、`stacks/go/README.md`；各 `configs/` 加示例规则文件 |
| A3 | 契约派生工件三件套进流程定义：`dbdoc/`（tbls）、`api/openapi.json`、`docs/state/*.md`；CI 三步=tbls diff、oasdiff breaking（fail-on ERR）、drift 检查（真源变而工件未再生成则 fail）；再生成命令写进钩子让 AI 改完自动跑。一次性成本 1–2 天（按项目用到的层打折：无对外 API 跳过 oasdiff 则减半） | 修改 `docs/workflow.md`（产出物定义节）；`claude-code/hooks.md` 加再生成钩子说明；各栈 configs/ 加 CI 片段 |
| A4 | ADR 规范进库：docs/adr/ 目录约定、五段式、三条件收敛、append-only；CLAUDE.md 模板加「触及旧决策须引用或新增 ADR」 | 新增 `process/adr.md`；修改 CLAUDE.md 模板 |
| A5 | 审查清单改为分层顺序：plan（假设/边界/测试点）→ 契约 diff（schema/API/边界/状态机）→ 测试 → 实现抽查；加硬规则「禁止 agent 删/跳过测试」；push 前 /code-review + /security-review 固化为步骤 | 修改 `process/review-checklist.md`、`process/task-brief.md`、`process/definition-of-done.md` |
| A6 | 调试守则：先复现→读运行时证据（request_id 过滤日志/console）→才改代码→修完回查；三栈结构化日志选型（pino/structlog/slog）+ canonical log line 字段约定 | 修改 CLAUDE.md 模板与 `universal/principles.md`（加一节）；三栈 README 各加日志选型 |

### 可选（按需开启，先在一个项目试运行再入库）

- B1 **CodeBoarding 进 CI**：架构图增量刷新 + PR 贴「本次改动落在架构图哪里」。最接近「动态刷新代码地图」的现成品；增量模式刚发布，先试一个仓库。→ 若留用，写入 `docs/workflow.md` 可选步骤。
- B2 **DeepWiki MCP**：读第三方库先查 wiki 再答，优先用 DeepWiki 的公共库免费面；私库自托管 deepwiki-open 仅在高频需要时开（烧自己 API key，且含 docker 部署与升级维护的运维面）。→ `claude-code/` 加 MCP 配置说明。
- B3 **Chrome DevTools MCP** 进 TS/React 栈配置（独立浏览器 profile）。→ `stacks/typescript-react/README.md`。
- B4 **OTel 最低限度 + otel-desktop-viewer**：只插桩 HTTP/DB/外呼，调性能/串流程时启动。→ 三栈 README 可选节。
- B5 **C4 模型从 Mermaid 升级 LikeC4 / Structurizr DSL**（一模型多视图；Structurizr MCP 属官方新方向但 vNext 未发布、接口可能变）。学习+迁移约 0.5–1 天；与被否的 Context Mapper CML（不建议清单 C4 条）不同，产物仍是仓库内纯文本、无独立工具链依赖，不触红线。
- B6 **PR 兜底评审**：CodeRabbit 免费层或 Bugbot 按量（约 $1–1.5/PR），只读 walkthrough/图不逐条看评论；或零成本 claude-code-action 自跑评审。
- B7 **code-graph-rag 类 MCP**：仅当 Claude Code 在你仓库反复 grep 低效时再加；先别上。

### 不建议（写进 `process/build-vs-buy.md` 的反面清单，防未来心动）

- C1 Backstage/Port/Cortex/EA 工具/CAST Imaging：治理成本=专职团队，个人必死。
- C2 任何承诺「模型↔代码双向同步」或「全自动逆向整库出图当文档」的工具：历史反复证伪（第 2 节）。
- C3 自建图数据库/Glean/自托管 Sourcegraph：索引器+服务+运维全是负资产；符号检索交给 LSP + Claude Code 自身。
- C4 Context Mapper CML、oNote/Qlerify、Stately Studio Pro、XState（无复杂状态逻辑时）、AppMap 当基建、madge/Sourcetrail 系：或过重、或停更、或不覆盖三栈。
- C5 Atlas migrate lint：免费面持续缩小；tbls diff + alembic check 的免费组合够用。

### 建议的落地顺序（若全部拍板采纳）

1. 第一周：A1（GLOSSARY/CONTEXT-MAP 模板 + CLAUDE.md 改动）+ A4（ADR）——纯 markdown，零依赖，当天见效于痛点 1/2/3；
2. 第二周：A2（三栈边界 linter）——先在一个现役项目跑 `--init`/基线模式验证噪音水平，再固化进 stacks/；
3. 第三周：A3（契约三件套 + drift CI）——按项目实际用到的层开启（没有对外 API 的项目跳过 oasdiff）；
4. 随后：A5/A6 改流程文件（半天）；B 列逐个试用，每次只引入一个，两周后按「用没用到」决定去留——与库哲学「规则从痛点长出来」一致；
5. 持续：每条新规则在 docs/pain-log.md 登记触发它的痛点；连续一个月没拦住任何问题的规则删掉。

## 7. 来源汇总（去重，按主题）

**历史与理论**
- Hillel Wayne, Why UML "Really" Died — https://buttondown.com/hillelwayne/archive/why-uml-really-died/
- Laurence Tratt, UML: My Part in its Downfall — https://tratt.net/laurie/blog/2022/uml_my_part_in_its_downfall.html
- Petre, UML in Practice (ICSE 2013) — https://www.ics.uci.edu/~andre/informatics223s2017/petre.pdf
- Whittle et al., The State of Practice in MDE — https://staffwww.dcs.shef.ac.uk/people/A.Simons/remodel/papers/WhittleMDE_IEEE.pdf ；Hutchinson et al. (ICSE 2011) — https://eprints.lancs.ac.uk/id/eprint/57678
- vhanniet, MDA/MDD: don't round-trip! — https://vhanniet.wordpress.com/2011/04/20/mdamdd-dont-round-trip/ ；OMG 白皮书 — https://www.omg.org/mda/mda_files/developing_in_omg.htm
- Kruchten 4+1 — https://arxiv.org/pdf/2006.04975 ；ISO 42010 概览 — https://quality.arc42.org/standards/iso-42010
- Simon Brown, Diagrams as code 2.0 — https://dev.to/simonbrown/diagrams-as-code-2-0-82k ；Structurizr /ai、/as-code — https://docs.structurizr.com/ai ；vNext 演讲 — https://www.bcs.org/events-calendar/2026/may/the-c4-model-structurizr-vnext-and-ai/
- model-code gap — https://dev.to/icepanel/the-model-code-gap-4m64 ；https://icepanel.io/blog/death-of-architecture-diagrams
- ADR — https://www.thoughtworks.com/radar/techniques/lightweight-architecture-decision-records ；https://github.com/peter-evans/lightweight-architecture-decision-records
- Living Documentation 书评 — https://www.infoq.com/articles/book-review-living-documentation/ ；原则解读 — https://hilton.org.uk/blog/living-documentation-principles
- Code Digital Twin（设想的学术原型，无实现）— https://arxiv.org/abs/2503.07967

**死亡与幸存案例**
- Rose RealTime EOL — https://community.ibm.com/community/user/wasdevops/blogs/osman-burucu/2024/07/29/rose-technical-developer-including-rose-realtime-w
- CodeSee 被收购 — https://gitkraken.com/blog/gitkraken-launches-devex-platform-acquires-codesee ；Sourcetrail 现状 — https://github.com/petermost/Sourcetrail
- stack-graphs 归档 — https://github.com/github/stack-graphs ；Sourcegraph 闭源 — https://www.linuxadictos.com/en/sourcegraph-abandons-open-source-in-favor-of-a-proprietary-license.html ；Glean — https://github.com/facebookincubator/Glean
- Swimm 转型 — https://swimm.io/ ；IcePanel 代码链接下线 — https://docs.icepanel.io/integrations/linking-to-reality
- Backstage 真实成本 — https://roadie.io/blog/the-true-cost-of-self-hosting-backstage/ ；目录腐化 — https://dev.to/danielwe/is-backstage-worth-it-the-real-question-is-whether-anyone-will-use-it-cni ；Spotify Portal — https://devclass.com/2024/05/03/spotify-previews-portal-for-backstage-as-developer-portal-with-easy-setup-plus-premium-plugins-for-all-users
- LeanIX/SAP — https://www.forrester.com/blogs/leanix-to-be-acquired-by-sap-in-q4-2023-a-vote-of-confidence-by-sap-in-enterprise-architecture ；CAST 价格 — https://www.g2.com/products/cast-imaging/pricing
- Context Mapper discovery 停更 — https://github.com/ContextMapper/context-map-discovery

**AI 新物种**
- DeepWiki — https://cognition.ai/blog/deepwiki ；MCP — https://cognition.ai/blog/deepwiki-mcp-server ；误判实例 — https://blopker.pages.dev/writing/12-deepwiki ；deepwiki-open — https://github.com/AsyncFuncAI/deepwiki-open
- Google Code Wiki — https://infoq.com/news/2025/11/google-code-wiki/
- CodeBoarding — https://github.com/CodeBoarding/CodeBoarding ；GitDiagram — https://github.com/ahmedkhaleel2004/gitdiagram ；Swark — https://github.com/swark-io/swark
- code-graph-rag — https://github.com/vitali87/code-graph-rag ；CodexGraph — https://arxiv.org/html/2408.03910v2 ；Codebase-Memory — https://arxiv.org/html/2603.27277v1
- Cline 不建索引论 — https://cline.bot/blog/why-cline-doesnt-index-your-codebase-and-why-thats-a-good-thing ；aider repo map — https://kitemetric.com/blogs/how-aider-indexes-your-codebase-for-ai-powered-code-assistance
- spec-kit — https://github.com/github/spec-kit ；Böckeler, spec-as-source 无实现 — https://www.martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html ；Spec Kit 批评 — https://tessl.io/blog/a-look-at-spec-kit-githubs-spec-driven-software-development-toolkit
- AGENTS.md 实证 — https://arxiv.org/abs/2510.21413 ；EventCatalog — https://github.com/event-catalog/eventcatalog

**派生与强制工具（三栈）**
- dependency-cruiser — https://github.com/sverweij/dependency-cruiser ；eslint-plugin-boundaries — https://github.com/javierbrea/eslint-plugin-boundaries ；Sheriff — https://github.com/softarc-consulting/sheriff ；Nx 边界 — https://nx.dev/docs/features/enforce-module-boundaries.md
- import-linter — https://github.com/seddonym/import-linter ；tach — https://github.com/tach-org/tach ；pydeps — https://github.com/thebjorn/pydeps
- go-arch-lint — https://github.com/fe3dback/go-arch-lint ；arch-go — https://github.com/arch-go/arch-go ；depguard — https://github.com/OpenPeeDeeP/depguard ；ArchUnit — https://github.com/TNG/ArchUnit
- tbls — https://github.com/k1LoW/tbls ；Atlas lint 付费墙（官方文档：v0.38 起 migrate lint 为 Pro 专属、需 atlas login）— https://atlasgo.io/versioned/lint ；第三方报道（作者系竞品开发者）— https://dev.to/mickelsamuel/atlas-paywalled-their-migration-linter-here-are-your-free-alternatives-4god ；付费面扩大旁证（高级 DB 对象登录门槛，未涉 lint）— https://github.com/ariga/atlas/discussions/2670 ；alembic check — https://dokk.org/documentation/alembic/rel_1_9_0/changelog/ ；prisma-dbml-generator — https://www.npmjs.com/package/prisma-dbml-generator ；Liam ERD — https://github.com/liam-hq/liam
- oasdiff — https://github.com/oasdiff/oasdiff ；oasdiff-action — https://github.com/oasdiff/oasdiff-action ；buf-action — https://github.com/bufbuild/buf-action
- TS codegen 对比 — https://dev.to/nyaomaru/which-openapi-codegen-should-you-choose-openapi-typescript-vs-hey-api-vs-orval-vs-kubb-100p ；Go code-first 对比 — https://oaswrap.github.io/blog/code-first-openapi-go
- XState — https://github.com/statelyai/xstate ；Stately GitHub Sync — https://stately.ai/blog/2024-01-09-introducing-bidirectional-github-sync ；Mermaid stateDiagram — https://mermaid.js.org/syntax/stateDiagram.html
- LikeC4 — https://github.com/likec4/likec4 ；SchemaSpy — https://github.com/schemaspy/schemaspy ；Azimutt — https://github.com/azimuttapp/azimutt

**DDD 与词汇层**
- threedots.tech, DDD and AI coding — https://threedots.tech/post/ddd-and-ai-coding/
- mattpocock/skills（GLOSSARY.md 格式）— https://github.com/mattpocock/skills ；ddd-crew 模板族 — https://github.com/ddd-crew/aggregate-design-canvas 、https://github.com/ddd-crew/bounded-context-canvas
- Context Mapper — https://github.com/ContextMapper/context-mapper-dsl ；kad-xyz/storm — https://github.com/kad-xyz/storm ；egon.io（diff 噪音 issue #161）— https://github.com/WPS/egon.io
- Vernon 演讲 — https://wso2.com/library/conference/2026/05/this-is-your-agent-on-domain-driven-design ；Fowler, LLM and DSLs — https://martinfowler.com/articles/llm-and-dsls.html
- DomainCodeBench（+38%）— https://arxiv.org/abs/2412.18573 ；KoCo-Bench — https://arxiv.org/html/2601.13240 ；TOSEM 2025 — https://chengcheng-wan.github.io/paper/24-TOSEM-CodeGen.pdf
- HN Domain-Driven Agents — https://news.ycombinator.com/item?id=49492584 ；DDD is Overrated 讨论 — https://news.ycombinator.com/item?id=26312652

**运行时**
- otel-desktop-viewer — https://github.com/CtrlSpice/otel-desktop-viewer ；otel-tui — https://github.com/ymtdzzz/otel-tui ；Jaeger v2 — https://jaegertracing.io/docs/next-release-v2/deployment
- canonical log lines — https://stripe.com/blog/canonical-log-lines ；wide events — https://simonwillison.net/2024/Feb/27/all-you-need-is-wide-events-not-metrics-logs-and-traces/ ；https://boristane.com/blog/observability-wide-events-101/
- Chrome DevTools MCP — https://github.com/ChromeDevTools/chrome-devtools-mcp ；Sentry MCP — https://sentry.io/cookbook/debug-with-sentry-mcp-claude-code ；Logfire MCP — https://pypi.org/project/logfire-mcp ；traceloop otel MCP — https://github.com/traceloop/opentelemetry-mcp-server ；Cloudflare local tracing — https://blog.cloudflare.com/local-tracing/
- AppMap — https://github.com/orgs/getappmap/repositories ；图能力 — https://appmap.io/docs/reference/guides/using-appmap-diagrams.html ；Tracetest 归档 — https://github.com/kubeshop
- 单体是否上 OTel — https://oneuptime.com/blog/post/2026-02-06-opentelemetry-monolith-before-microservices/view ；SigNoz 自托管门槛 — https://www.valebyte.com/en/guides/deploying-signoz-on-vps-comprehensive-application-monitoring-logs-metrics-traces/

**评审瓶颈**
- Harvard/Jellyfish 研究报道 — https://complexdiscovery.com/harvard-researchers-find-ai-coding-agents-shifted-the-bottleneck-to-code-review/ ；Faros 遥测 — https://blog.logrocket.com/ai-coding-tools-shift-bottleneck-to-review/ ；DORA 2025 — https://www.splunk.com/en_us/blog/learn/state-of-devops
- Martian 基准（各厂口径互搏，榜单月漂移）— codereview.withmartian.com ；厂商页：greptile.com / cubic.dev / qodo.ai / coderabbit.ai 新闻页
- 噪音实测 — https://dev.to/alexey-pelykh/i-ran-449-ai-code-reviews-in-9-days-then-i-almost-got-banned-17h5 ；Copilot 重评死循环 — https://github.com/orgs/community/discussions/189767
- 评审上移 — https://newsletter.pragmaticengineer.com/p/what-is-happening-with-code-reviews ；Kent Beck×agent — https://newsletter.pragmaticengineer.com/p/tdd-ai-agents-and-coding-with-kent ；Krycho 反驳抽样评审 — https://v5.chriskrycho.com/notes/yes-hallucinations-are-the-least-dangerous-exactly/
- CodeRabbit Change Stack — https://docs.coderabbit.ai/pr-reviews/change-stack.md ；SemanticDiff — https://semanticdiff.com/github ；difftastic — https://github.com/Wilfred/difftastic/releases ；PR-Agent — https://github.com/The-PR-Agent/pr-agent
- Graphite/Cursor 收购 — https://hackernoon.com/lite/cursors-graphite-deal-aims-to-close-the-loop-from-writing-code-to-merging-it ；Greptile 融资 — https://runtimewire.com/article/greptile-raises-50m-series-b-at-750m-valuation
- Claude Code 评审自动化 — https://docs.claude.com/en/docs/claude-code/github-actions

**证据质量声明**：各调研会话均受网络白名单限制——martinfowler.com、stripe.com、appmap.io、icepanel.io、arxiv.org、HN 等部分原文经搜索摘要与多源交叉验证而非直读，个别引语措辞可能不精确；GitHub 仓库活跃度（star/pushed_at）为 2026-11-05 一手核实。二手转述（已标注，采信时留余量）：Petre 的 35/11/0 分布、mutable.ai→Google、CodeSee 停服细节、Stately/CodeRabbit 定价。厂商自述（Seer root cause 质量、Greptile 捕获率、Code Wiki「每 commit 重建」、Swimm auto-sync 能力）均不作为独立结论。
