> 仓库门面。给第一次打开本仓库的人看：这里有什么、为什么长这样、怎么在新项目里用起来。

# AI 协作开发策略库

个人开发者的 AI 协作开发策略库：一套让 Claude Code 协助开发更可靠的 **文档 + 配置 + 模板 + 钩子** 工具包。不是教科书，不是规则大全。

## 为什么存在

三个反直觉结论，是全库的地基：

1. **规则价值与通用程度成反比**——「高内聚低耦合」这类模型已知的常识一个字不写，只写模型默认会做错、且可判定违反与否的内容。
2. **能被工具强制的不写成文字**——formatter/linter/钩子挡得住的错写成配置和钩子，prose 只留给工具够不着的地方。
3. **规则从真实痛点长出来，而非自顶向下编大全**——每条规则都能追溯到 [docs/pain-log.md](docs/pain-log.md) 里一次真实被坑。

## 目录结构

```text
.
├── README.md                      # 仓库门面（本文件）
├── CLAUDE.md                      # 在本仓库里工作时的维护规则
├── docs/
│   ├── workflow.md                # 8 阶段工作流全景（阶段0 环境底座 → 阶段8 沉淀）
│   ├── pain-log.md                # 痛点日志(pain log)：全库规则的唯一来源
│   └── research/                  # 归档调研报告：只读参考，不是规则
│       └── system-map.md          # 业务→代码「活地图」：价值判断与分层落地方案
├── universal/
│   └── principles.md              # 跨栈通用硬规则，常驻上下文，预算最紧
├── process/                       # 流程五件套，按阶段在任务中使用
│   ├── task-brief.md              # 阶段1 需求表达：任务简述、非目标
│   ├── definition-of-done.md      # 阶段4 验证：完成定义、修 bug 铁律
│   ├── build-vs-buy.md            # 阶段2 方案：轮子vs自研、绝不自研清单
│   ├── review-checklist.md        # 阶段5 审查：审查清单
│   └── session-management.md      # 阶段7 会话管理：止损、落盘
├── templates/                     # 复制进新项目再填空的模板
│   ├── CLAUDE.md.template         # 项目级 CLAUDE.md（含模块地图）
│   └── plan.md.template           # 阶段2 方案文档
├── claude-code/                   # Claude Code 本体配置
│   ├── hooks.md                   # 钩子安装与说明
│   ├── settings.json.example      # settings 示例
│   └── hooks/
│       ├── post-edit-format.sh    # 编辑后自动格式化
│       └── stop-verify.sh         # 收尾前自动验证
└── stacks/                        # 每栈一目录：README（固定七节）+ configs
    ├── _template.md               # 新栈起步骨架
    ├── typescript-react/
    │   ├── README.md
    │   └── configs/               # eslint.config.js、tsconfig.json、.prettierrc.json
    ├── python/
    │   ├── README.md
    │   └── configs/               # pyproject.toml
    └── go/
        ├── README.md
        └── configs/               # .golangci.yml
```

## 快速开始

在一个新项目里用起来，四步：

1. 复制 [templates/CLAUDE.md.template](templates/CLAUDE.md.template) 到新项目根目录，按注释填空，模块地图必填。
2. 复制对应栈的 `stacks/<栈>/configs/` 进项目，再按 [claude-code/hooks.md](claude-code/hooks.md) 安装钩子与 [settings](claude-code/settings.json.example)。
3. 让 Claude 在任务中遵循 process/ 五件套：[任务简述](process/task-brief.md) → [轮子vs自研](process/build-vs-buy.md) → [完成定义](process/definition-of-done.md) → [审查清单](process/review-checklist.md) → [会话管理](process/session-management.md)。
4. 开始记 [docs/pain-log.md](docs/pain-log.md)：每次被 AI 坑，当场记一条。

## 仓库如何生长

不自顶向下编规则，唯一入口是痛点日志：

被坑 → 记进 [docs/pain-log.md](docs/pain-log.md) → 过三连筛（能被工具强制？→ 配置/钩子；因缺上下文而犯？→ CLAUDE.md 地图/参照范例；剩下 → prose 规则）→ 归位到对应文件，条目标「已落地」。

在本仓库里增删内容前，先读 [CLAUDE.md](CLAUDE.md)：质量门槛、行数预算、术语表都在那里。

## 现状与路线

- 已填充的栈：[typescript-react](stacks/typescript-react/README.md)、[python](stacks/python/README.md)、[go](stacks/go/README.md)。
- 其余栈不预写：真要用某个栈时，复制 [stacks/_template.md](stacks/_template.md) 起步，按固定七节填。
- 完整的 8 阶段工作流见 [docs/workflow.md](docs/workflow.md)。
- 预期趋势：配置和钩子越来越多，prose 规则越删越少、越剩越硬。
