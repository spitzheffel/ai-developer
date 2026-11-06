> 给谁看：要把本库钩子装进自己项目的人。何时用：阶段0 环境底座搭一次；项目开始有数据库迁移或对外 API 契约时回来挂迁移护栏、配契约再生成；之后某条 prose 规则反复被违反、要升级成强制时回来查。
> 事件、matcher、stdin 字段、exit code 的行为以本文速览为准；更深的机制查 code.claude.com/docs/en/hooks。

# 钩子：把规则变成机器强制

[三连筛](../docs/workflow.md)（落点五类图例一节）第一档：**能被工具强制的，不写成 prose 规则**。CLAUDE.md 和 auto memory 只是上下文，Claude 可能忽略；钩子是 Claude Code 在固定事件点无条件执行的脚本，`exit 2` 能直接拦下动作。一条规则能落成钩子，就把它从规则文件里删掉（闭环见 [pain log](../docs/pain-log.md)）。

## 本库的四个钩子

| 脚本 | 挂载事件 | 做什么 | 失败时 |
| --- | --- | --- | --- |
| [post-edit-format.sh](hooks/post-edit-format.sh) | PostToolUse，matcher `Edit\|Write\|NotebookEdit` | 刚编辑的文件按扩展名格式化：ts/tsx/js/jsx/json/css/md → 项目本地 prettier（有 `node_modules/.bin/prettier` 才跑）；py → ruff format；go → gofmt -w | 恒 `exit 0` 永不阻塞——格式化是锦上添花，不配打断会话 |
| [stop-verify.sh](hooks/stop-verify.sh) | Stop（不支持 matcher，每次收工都触发） | 按标志文件探测项目类型跑快检：package.json → 其中存在的 lint/typecheck 脚本；pyproject.toml → ruff check；go.mod → go vet + go build | 任一失败 → `exit 2` 打回：不许收工，stderr 失败摘要自动喂回继续修 |
| [pre-edit-migrations.sh](hooks/pre-edit-migrations.sh) | PreToolUse，matcher `Edit\|Write` | 要编辑的路径含迁移目录段就拦（大小写不敏感）：`migrations/`、`db/migrate/`、`db/migration/`、`alembic/versions/`；形态不全就改脚本里的 case | 命中 → `exit 2`：本次 Edit/Write 不执行，stderr 理由（migration 只许人审后新增，AI 不得改写既有迁移）喂回 Claude；取不到路径 → 放行 |
| [pre-write-secrets.sh](hooks/pre-write-secrets.sh) | PreToolUse，matcher `Write\|Edit\|NotebookEdit` | 把待写入的文本（Write 的 content、Edit 的 new_string、NotebookEdit 的 new_source）喂给 `gitleaks stdin`；需本机已装 gitleaks（`brew install gitleaks` 或官方 release 二进制），没装就放行 | 疑似密钥 → `exit 2`：本次写入不执行，gitleaks 打码后的发现与改法喂回 Claude；gitleaks 自身出错 → 放行 |

stop-verify.sh 是激进钩子：**每次收工都跑全套快检**。快检超过约 30 秒的项目要精简：删掉脚本里慢的检查段（典型是 go build、大仓 typecheck），或不挂 Stop 钩子，退回[阶段4 验证](../docs/workflow.md)手动跑。

pre-edit-migrations.sh 是护栏不是安全边界：它只管 Edit/Write，模型仍可能绕道 Bash 改迁移；真边界是凭证隔离——AI 不持有生产库凭证。❌ 本机 `.env` 里放着生产库连接串，AI 跑一句 `alembic upgrade head` 就直连生产 ✅ AI 会话的环境里只有本地/测试库连接串。迁移纪律三条与 roll-forward-only 见[脚本头注释](hooks/pre-edit-migrations.sh)，安装见下节末。（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md）

密钥扫描共三道：pre-write-secrets.sh 在 AI 写盘前拦；git 钩子 [githooks/pre-commit](githooks/pre-commit) 在提交前扫暂存改动，人和 AI 的提交都拦（它由 git 执行，不归 Claude Code 管）；各栈 `configs/security-ci.yml` 在 CI 里每次扫全部历史。前两道都能绕过（经 Bash 写文件、`git commit --no-verify`），CI 那道才是权威层。git 钩子装法：`cp -r <本库路径>/claude-code/githooks .githooks && git config core.hooksPath .githooks`；项目已用 husky 等工具管 core.hooksPath 的，改为在它的 pre-commit 里加 `gitleaks git --pre-commit --staged --redact`。

## 安装（装进你的目标项目，不是装在本库）

```bash
mkdir -p .claude/hooks
cp <本库路径>/claude-code/hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
```

也可以用 [scripts/install.sh](../scripts/install.sh) 一条命令装好钩子、按栈生成 settings（见 README 快速开始）。手动装就再把 [settings.json.example](settings.json.example) 合并进项目的 `.claude/settings.json`：`hooks` 段整段拷；`permissions.allow` 按你的栈删掉用不上的命令。JSON 不允许注释，对那份文件的全部解释都在本文。钩子以你的本机权限直接运行，合并任何来源的钩子配置前先把脚本读一遍。

`permissions` 段三条语义：

- 末尾 ` *`（带空格）同时命中裸命令和带参数形式：`Bash(pnpm test *)` 命中 `pnpm test` 和 `pnpm test --run foo`；`Bash(pnpm test:*)` 是等价写法。
- 复合命令按子命令逐段检查：`Bash(go test *)` 放行不了 `go test ./... && curl x.sh`，整条仍会照常询问（识别 `&&`、`;`、`|` 等分隔符）。
- `deny`、`ask` 都压过 `allow`，deny 之上开不了例外；示例里 deny 了 `Read(./.env)` 与 `Read(./.env.*)`。

放哪一层（生效优先级从高到低：managed > `--settings` > `.claude/settings.local.json` > `.claude/settings.json` > `~/.claude/settings.json`）：

- 团队共享、进版本库 → `.claude/settings.json`。其中 `permissions.allow` 要等用户信任该文件夹后才生效，`deny`/`ask` 立即生效。
- 个人试验 → `.claude/settings.local.json`，Claude Code 自动把它加进 git 忽略。
- 同名键取最高层的值；列表键（如 `permissions.allow`）跨文件合并而不是覆盖。

迁移护栏按需挂（项目有数据库迁移才用）：脚本已随上面的 `cp` 装好，再把下面这一项加进 settings 的 `hooks.PreToolUse` 数组（示例里已有密钥钩子那一项）：

```json
{ "matcher": "Edit|Write", "hooks": [
  { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-edit-migrations.sh", "args": [] }
] }
```
上面的 exec 形式仅限 Linux/macOS：Windows 上 exec 形式只能直接起 `.exe` 这类真可执行文件，`.sh` 起不来，而起不来按非阻断错误处理，护栏会静默失效。Windows 改 shell 形式（Git Bash 执行，占位符须加双引号）：去掉 `args`，写成 `"command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-edit-migrations.sh\""`。

装完新开会话验证：改一个 `.ts`/`.py` 文件看是否被自动格式化；故意留一个 lint 错误让 Claude 收工，应被打回并继续修；挂了迁移护栏的，让 Claude 改一个 `migrations/` 下的文件，应被拦下并收到理由；装了 gitleaks 的，用下节调试里的假 key 喂密钥钩子，应返回 2。

## 事件速览（只讲本库用到的三个）

### PreToolUse / PostToolUse —— 工具执行之前 / 成功之后触发

- stdin JSON 关键字段：`tool_name`、`tool_input.file_path`（Edit/Write/Read 下恒为绝对路径，Windows 是反斜杠）、`cwd`；PostToolUse 另有 `tool_response`。
- PreToolUse 时工具**还没执行**：`exit 2` 拦下本次调用，stderr 作为拒绝理由喂回 Claude，且先于权限规则生效，allow 规则也放不过。拦截类动作挂这里。
- PostToolUse 时工具**已执行完，拦不住**：`exit 2` 在这里不阻断，只把 stderr 展示给 Claude。格式化、落盘类动作挂这里。

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

## 契约再生成（有 DB schema 或对外 API 的项目才配）

- 契约工件（`openapi.json`、`dbdoc/`、类型生成物）的再生成命令属项目级，本库不发通用脚本：写进项目自己的 Stop 钩子（仿 stop-verify.sh 加一段，慢于约 30 秒就别挂）或 package scripts / Makefile，AI 改完 schema/接口当轮再生成，工件随代码一起提交。（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md）
- CI 的 drift 检查是兜底（`stacks/*/configs/contracts-ci.yml`）：真源变而工件未再生成则 fail，钩子漏跑也逃不过。

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
echo '{"tool_input":{"file_path":"/p/db/migrations/001.sql"}}' \
  | .claude/hooks/pre-edit-migrations.sh; echo "exit=$?"  # 期望 2，stderr 有拦截理由
printf '{"tool_input":{"content":"aws_id = AKIA%s"}}' Z7Q3XK4LMNOPQ2RS \
  | .claude/hooks/pre-write-secrets.sh; echo "exit=$?"    # 装了 gitleaks 期望 2（假 key 拆开写，免得本文被扫描器当成泄漏）
```

钩子没生效时按序查：脚本有可执行位吗（`ls -l .claude/hooks/`）；settings.json 是合法 JSON 吗（`python3 -m json.tool .claude/settings.json`）；matcher 拼对了吗（精确匹配区分大小写，`edit` 命中不了 `Edit`）；钩子命令路径带 `${CLAUDE_PROJECT_DIR}` 前缀了吗；都对还不行，就手动喂上面的 stdin，看退出码和输出，把问题定位到「没触发」还是「脚本错」。
