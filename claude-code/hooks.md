> 给谁看：要把本库钩子装进自己项目的人。何时用：阶段0 环境底座搭一次；之后某条 prose 规则反复被违反、要升级成强制时回来查。
> 事件、matcher、stdin 字段、exit code 的行为以本文速览为准；更深的机制查 code.claude.com/docs/en/hooks。

# 钩子：把规则变成机器强制

[三连筛](../docs/workflow.md)（落点五类图例一节）第一档：**能被工具强制的，不写成 prose 规则**。CLAUDE.md 和 auto memory 只是上下文，Claude 可能忽略；钩子是 Claude Code 在固定事件点无条件执行的脚本，`exit 2` 能直接拦下动作。一条规则能落成钩子，就把它从规则文件里删掉（闭环见 [pain log](../docs/pain-log.md)）。

## 本库的两个钩子

| 脚本 | 挂载事件 | 做什么 | 失败时 |
| --- | --- | --- | --- |
| [post-edit-format.sh](hooks/post-edit-format.sh) | PostToolUse，matcher `Edit\|Write\|NotebookEdit` | 刚编辑的文件按扩展名格式化：ts/tsx/js/jsx/json/css/md → 项目本地 prettier（有 `node_modules/.bin/prettier` 才跑）；py → ruff format；go → gofmt -w | 恒 `exit 0` 永不阻塞——格式化是锦上添花，不配打断会话 |
| [stop-verify.sh](hooks/stop-verify.sh) | Stop（不支持 matcher，每次收工都触发） | 按标志文件探测项目类型跑快检：package.json → 其中存在的 lint/typecheck 脚本；pyproject.toml → ruff check；go.mod → go vet + go build | 任一失败 → `exit 2` 打回：不许收工，stderr 失败摘要自动喂回继续修 |

stop-verify.sh 是激进钩子：**每次收工都跑全套快检**。快检超过约 30 秒的项目要精简：删掉脚本里慢的检查段（典型是 go build、大仓 typecheck），或不挂 Stop 钩子，退回[阶段4 验证](../docs/workflow.md)手动跑。

## 安装（装进你的目标项目，不是装在本库）

```bash
mkdir -p .claude/hooks
cp <本库路径>/claude-code/hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
```

再把 [settings.json.example](settings.json.example) 合并进项目的 `.claude/settings.json`：`hooks` 段整段拷；`permissions.allow` 按你的栈删掉用不上的命令。JSON 不允许注释，对那份文件的全部解释都在本文。钩子以你的本机权限直接运行，合并任何来源的钩子配置前先把脚本读一遍。

`permissions` 段三条语义：

- 末尾 ` *`（带空格）同时命中裸命令和带参数形式：`Bash(pnpm test *)` 命中 `pnpm test` 和 `pnpm test --run foo`；`Bash(pnpm test:*)` 是等价写法。
- 复合命令按子命令逐段检查：`Bash(go test *)` 放行不了 `go test ./... && curl x.sh`，整条仍会照常询问（识别 `&&`、`;`、`|` 等分隔符）。
- `deny`、`ask` 都压过 `allow`，deny 之上开不了例外；示例里 deny 了 `Read(./.env)` 与 `Read(./.env.*)`。

放哪一层（生效优先级从高到低：managed > `--settings` > `.claude/settings.local.json` > `.claude/settings.json` > `~/.claude/settings.json`）：

- 团队共享、进版本库 → `.claude/settings.json`。其中 `permissions.allow` 要等用户信任该文件夹后才生效，`deny`/`ask` 立即生效。
- 个人试验 → `.claude/settings.local.json`，Claude Code 自动把它加进 git 忽略。
- 同名键取最高层的值；列表键（如 `permissions.allow`）跨文件合并而不是覆盖。

装完新开会话验证：改一个 `.ts`/`.py` 文件看是否被自动格式化；故意留一个 lint 错误让 Claude 收工，应被打回并继续修。

## 事件速览（只讲本库用到的两个）

### PostToolUse —— 工具执行成功之后触发

- stdin JSON 关键字段：`tool_name`、`tool_input.file_path`（Edit/Write/Read 下恒为绝对路径，Windows 是反斜杠）、`tool_response`、`cwd`。
- 此时工具**已执行完，拦不住**：`exit 2` 在这里不阻断，只把 stderr 展示给 Claude。格式化、落盘类动作挂这里；要拦截动作得挂 PreToolUse。

### Stop —— Claude 结束回复、准备收工时触发

- 不支持 matcher，每次都触发。
- stdin JSON 关键字段：`stop_hook_active`（防死循环，见下节）、`last_assistant_message`（最后一条回复全文，要判断回复内容直接用它，别解析 transcript）。
- `exit 2` = 阻止收工，stderr 作为原因喂回，Claude 带着它继续干活。等价 JSON 写法：`exit 0` 且 stdout 输出 `{"decision":"block","reason":"..."}`（`reason` 必填）。

### matcher 写法（仅工具类事件生效）

- 只含字母数字、`_`、`-`、空格、`,`、`|` → 按工具名精确匹配，`|` 或 `,` 分隔列表：`Edit|Write` 只匹配这两个工具。
- 含其他字符 → 按 JS 正则解析且**不锚定**。❌ `Edit.*`（连 `NotebookEdit` 一起命中）✅ `^(Edit|Write)$`
- MCP 工具全名是 `mcp__<server>__<tool>`。❌ `mcp__memory`（精确名，什么都命中不了）✅ `mcp__memory__.*`
- `"*"`、`""` 或省略 matcher = 匹配全部工具。

### exit code 语义（强制力的来源）

- `0`：成功。stdout 是单个 JSON 对象时按控制字段解析，否则当纯文本。
- `2`：阻断。PreToolUse 拦下工具调用、Stop 阻止收工，stderr 作为原因反馈给 Claude；PostToolUse 例外（见上）。
- 其他退出码（**含 1**）：一律非阻断，只显示一条 hook error 提示。❌ 用 `exit 1` 想强制 ✅ 要强制只有 `exit 2`

### 路径与环境变量

- settings 里钩子命令写 `${CLAUDE_PROJECT_DIR}/.claude/hooks/<名字>.sh`。该变量 = 会话启动时的项目根目录，进 worktree 也不变。❌ 相对路径（钩子执行时 cwd 不保证在项目根）✅ 恒带 `${CLAUDE_PROJECT_DIR}` 前缀
- 命令含路径占位符时官方建议 exec 形式：参数放进 `"args": []` 数组，[settings.json.example](settings.json.example) 已照此写。

## Stop 钩子防死循环（stop_hook_active）

被 `exit 2` 打回后 Claude 继续干活，下一次收工**仍会**触发 Stop 钩子；此时 stdin 的 `stop_hook_active` 为 `true`，意思是「本次续跑就是 stop hook 造成的」。

- 铁律：Stop 钩子第一步先查它，为 `true` 立即 `exit 0`。[stop-verify.sh](hooks/stop-verify.sh) 开头第一段就是这个检查。
- ❌ 不查就无条件 `exit 2`：陷入 修→收工→打回 死循环。官方另有连续续跑上限（8 次），但计数在每次工具调用后重置，修复循环每轮都调工具，几乎不会触发，不能依赖它；防死循环只靠 stop_hook_active 检查
- ✅ 查到 `true` 放行：每轮最多打回一次，没修完的留给人审，不指望钩子逼出完美

## 调试

钩子就是普通 bash 脚本，不用等 Claude Code 触发，手动喂 stdin 单测：

```bash
bash -n .claude/hooks/stop-verify.sh                   # 只验语法
echo '{"tool_input":{"file_path":"'$PWD'/src/a.ts"}}' \
  | .claude/hooks/post-edit-format.sh; echo "exit=$?"  # 期望 0，且文件被格式化
echo '{"stop_hook_active":false}' \
  | .claude/hooks/stop-verify.sh; echo "exit=$?"       # 快检全过=0；有失败=2 且 stderr 有摘要
echo '{"stop_hook_active":true}' \
  | .claude/hooks/stop-verify.sh; echo "exit=$?"       # 必须恒 0，否则防死循环失效
```

钩子没生效的排查顺序：

1. 脚本有可执行位吗：`ls -l .claude/hooks/`
2. settings.json 是合法 JSON 吗：`python3 -m json.tool .claude/settings.json`
3. matcher 拼对了吗：精确匹配区分大小写，`edit` 命中不了 `Edit`
4. 钩子命令路径带 `${CLAUDE_PROJECT_DIR}` 前缀了吗
5. 都对还不行：手动喂上面的 stdin，看退出码和输出，把问题定位到「没触发」还是「脚本错」
