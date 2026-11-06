> 给在 Python 代码库里干活的 Claude Code 会话与未来的自己看：开新 Python 项目或接手存量项目动手前加载。配置不手写，整份复制 [configs/pyproject.toml](configs/pyproject.toml)。

# Python 栈

## 1. 选型清单

默认栈，新项目不讨论直接用；想换先走 [build-vs-buy](../../process/build-vs-buy.md)，换定后回来更新本表。

| 需求域 | 钉死 | 禁用 | 一句话理由 |
| --- | --- | --- | --- |
| 语言版本 | Python 3.12+（`requires-python = ">=3.12"`） | 给 `requires-python` 封上界（如 `<3.13`） | 上界徒增解析冲突，只写下界 |
| 包与环境 | uv | 新项目用 pip/poetry/conda | 单一入口：依赖只经 `uv add` / `uv remove` 进出 |
| Web 框架 | FastAPI | — | — |
| 错误响应 | RFC 9457 `application/problem+json`（`type`/`title`/`status`/`detail`，业务错误码放扩展字段）；FastAPI 不默认，自加全局 exception handler，覆盖 `StarletteHTTPException`、`RequestValidationError` 与兜底 `Exception`，handler 顺手写 `request.state.error_code`（第 5 节日志带出） | 随手自定义错误 JSON 形状（含 FastAPI 默认的 `{"detail": ...}`） | 有标准背书，错误形状从此全库唯一（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md） |
| 分页与幂等 | 列表端点默认 cursor 分页、不返回 total count；仅「创建 + 有副作用」端点要求 `Idempotency-Key`（缺 key→400，同 key 异 payload→422，同 key 重放返回原响应） | `offset`/`limit` 分页当默认 | offset 越翻越慢、翻页途中有插入会漏行或重行；无对外 API 的项目可缓（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md） |
| 数据模型与校验 | pydantic v2 | pydantic v1 语法 | v1 写法一律算 bug（见第 6 节坑 3） |
| HTTP 客户端 | httpx | 新代码引 requests | requests 无异步支持（见第 6 节坑 4、5） |
| ORM | SQLAlchemy 2.0 风格 + alembic；异步栈装 `uv add "sqlalchemy[asyncio]"`（2.1 起 greenlet 不随包默认安装，缺了 async engine 一跑就报错） | legacy 的 `session.query()` | 全库统一 `select()` 范式（见第 5 节） |
| 日志 | structlog | 调试 print 残留进提交 | — |
| CLI | typer | — | — |
| 测试 | pytest（异步用 pytest-asyncio，auto 模式已写进配置） | — | — |
| 集成测试 | testcontainers 起真 Postgres/Redis 实例（`uv add --dev "testcontainers[postgres,redis]"`） | mock 数据库/缓存，或拿 SQLite 内存库顶替 Postgres | AI 产码的失败集中在集成点，真容器只多花几秒（见第 6 节坑 10；〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md） |
| Lint + Format | ruff 全包 | black/isort/flake8 叠加 | ruff 一个工具全管 |
| 类型检查 | mypy（strict 基线，放宽只按模块在 overrides 做） | — | — |
| 依赖边界 | import-linter `layers` 契约（`uv run lint-imports`；配置见 [configs/pyproject.toml](configs/pyproject.toml) 的 `[tool.importlinter]`） | 跨层随意 import、只靠 review 肉眼守分层 | 层名即架构文档，越界即红、AI 看到红自己修（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md） |
| 依赖审计 | pyproject.toml 或 uv.lock 有变化时 `uv audit` 卡 PR（CI 钉 uv 版本），每周 osv-scanner 全量兜底新披露的漏洞（[configs/security-ci.yml](configs/security-ci.yml)） | 新项目引 pip-audit / safety | uv 内置，读 uv.lock 查 OSV，不另装工具；默认连 dev 组一起审计（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md OP1） |

## 2. 工具链与命令

所有命令带 `uv run` 前缀跑在项目环境里，不手动激活 venv、不裸调全局解释器。

| 场景 | 命令 |
| --- | --- |
| 初始化项目 | `uv init --package`（建出 `src/<package>/__init__.py`，再用 [configs/pyproject.toml](configs/pyproject.toml) 整份覆盖生成的 pyproject） |
| 按锁文件装环境 | `uv sync`（CI 用 `uv sync --locked`） |
| 加运行依赖 | `uv add fastapi`（写入 `[project.dependencies]` 并更新 uv.lock） |
| 加开发依赖 | `uv add --dev pytest`（写入 `[dependency-groups].dev`） |
| 跑测试 | `uv run pytest` |
| Lint + 自动修复 | `uv run ruff check --fix` |
| 格式化 | `uv run ruff format`（只校验不改码用 `--check`） |
| 类型检查 | `uv run mypy src/` |
| 依赖审计 | `uv audit --frozen --preview-features audit-command`（不带 --frozen/--locked 会重新解析并改写 uv.lock） |

- 提交前全套：`uv run ruff check --fix && uv run ruff format && uv run mypy src/ && uv run lint-imports && uv run pytest`。
- 编辑后自动跑 `ruff format` 的钩子接法见 [claude-code/hooks.md](../../claude-code/hooks.md)。
- 禁手改 uv.lock；项目内脚本、CI、文档统一走 uv，禁再出现 `pip install`。

## 3. 目录规范

src layout：包代码一律放 `src/` 下，避免「测试 import 到当前目录的包」这类假通过。

```text
src/<package>/
    api/        # FastAPI router：只做 HTTP 入出参与状态码翻译，不写业务逻辑
    core/       # 配置、日志初始化、依赖注入等横切设施，不 import 业务模块
    models/     # SQLAlchemy 模型 + pydantic schema：持久化形态与传输形态
    services/   # 业务逻辑：被 api 调用，不感知 HTTP
tests/          # 镜像 src/<package>/ 结构：services/user.py ↔ tests/services/test_user.py
```

import 方向单向：api → services → models/core。想反向 import 时先回头改分层（见第 6 节坑 8）。

## 4. build-vs-buy 默认值

通用判断见 [process/build-vs-buy.md](../../process/build-vs-buy.md)。Python 标准库强大，本栈整体居中偏用库；以下直接查表不再讨论：

- 时间处理钉死：datetime 一律 timezone-aware——`datetime.now(tz=ZoneInfo("UTC"))`（标准库 zoneinfo）；naive datetime 禁进持久层与 API 边界。
- 路径一律 `pathlib.Path`，函数签名收 `Path` 不收 `str`。
- 绝不自研清单（Python 追加项）：密码散列与 JWT、重试退避（用 tenacity）、环境变量配置解析（用 pydantic-settings）、cron 表达式解析。
- 够标准库就不引包：`json` / `csv` / `itertools` / `functools` / `tempfile` / `zoneinfo` 覆盖的场景不加第三方依赖。

## 5. 参照模式

范例驱动：新端点照抄此骨架改名，不自由发挥。三层职责见第 3 节；领域异常在 router 统一翻译成 HTTP 状态码。

```python
# models/schemas.py —— 传输形态（pydantic v2）
class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)  # 允许直接从 ORM 对象构造
    id: int
    email: str

# services/user.py —— 业务逻辑，不感知 HTTP
async def get_user(session: AsyncSession, user_id: int) -> User:
    user = await session.get(User, user_id)   # 按主键取对象用 session.get()
    if user is None:
        raise UserNotFoundError(user_id)      # 抛领域异常，不在 service 抛 HTTPException
    return user

# api/users.py —— router 只做入出参翻译
router = APIRouter(prefix="/users", tags=["users"])

@router.get("/{user_id}", response_model=UserOut)
async def read_user(user_id: int, session: SessionDep) -> UserOut:  # SessionDep 定义在 core/
    try:
        return UserOut.model_validate(await user_service.get_user(session, user_id))
    except UserNotFoundError:
        raise HTTPException(status_code=404, detail="user not found") from None
```

查询用 `select()` 范式：`(await session.scalars(select(User).where(User.email == email))).all()`；单行标量用 `.scalar_one()`。

日志范例（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md）：每请求收尾恰好一条宽字段 canonical log line，失败请求 100% 留痕，排障按 request_id 一 grep 即见全貌；禁散落 `print`/info 碎日志。下游要往这一条里补字段就写 `request.state.<字段>`——下游 bind 的 contextvars 传不回 `@app.middleware`。structlog 在 core/ 初始化时末位 processor 用 `JSONRenderer()`（默认的 ConsoleRenderer 不出 JSON）。

```python
@app.middleware("http")  # main.py —— 每请求收尾恰好一条 canonical log line
async def canonical_log_line(request: Request, call_next: RequestResponseEndpoint) -> Response:
    clear_contextvars()  # structlog.contextvars：先清后绑，本请求内所有日志自动带 request_id
    bind_contextvars(request_id=request.headers.get("x-request-id") or uuid4().hex)
    start, status = time.perf_counter(), 500  # 异常冒泡、未成响应时按 500 记
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:  # 成败都落、且只落这一条：失败请求 100% 留痕
        logger.info("request", method=request.method, status=status,
                    route=getattr(request.scope.get("route"), "path", request.url.path),
                    error_code=getattr(request.state, "error_code", None),  # problem+json handler 写入
                    duration_ms=round((time.perf_counter() - start) * 1000, 1))
```

## 6. 高频 AI 坑

模型默认写法与本栈冲突的点，review 逐条对照；新坑先记[痛点日志](../../docs/pain-log.md)（pain log），复发再入本表。

1. 可变默认参数：❌ `def add(x, bucket: list = []):` ✅ `def add(x, bucket: list | None = None):`（函数体内 `bucket = [] if bucket is None else bucket`）
2. 裸 except 吞异常：❌ `except Exception: pass` ✅ `except ValueError:` 只接能处理的类型，接不住就 `raise`；记日志用 `logger.exception(...)`
3. pydantic v1 幻觉语法（最高发，逐项对照改成 v2）：
   - ❌ `@validator` ✅ `@field_validator`；❌ `@root_validator` ✅ `@model_validator`
   - ❌ `.dict()` / `.json()` ✅ `.model_dump()` / `.model_dump_json()`
   - ❌ `parse_obj()` / `parse_raw()` ✅ `model_validate()` / `model_validate_json()`
   - ❌ `class Config:` ✅ `model_config = ConfigDict(...)`
4. requests 肌肉记忆：❌ `import requests` ✅ 同步 `httpx.get(...)`，异步 `async with httpx.AsyncClient() as client:`
5. async 里塞同步阻塞 IO：❌ `async def f(): time.sleep(3)`（或在 async 里调 requests）✅ `await asyncio.sleep(3)` / AsyncClient；绕不开的同步库包 `await asyncio.to_thread(fn)`
6. naive datetime：❌ `datetime.now()` / `datetime.utcnow()` ✅ `datetime.now(tz=ZoneInfo("UTC"))`
7. os.path 旧习惯：❌ `os.path.join(base, "a.txt")` ✅ `Path(base) / "a.txt"`，`Path` 对象一路传到底不转回 str
8. 循环 import 靠函数内 import 糊弄：❌ 把 `from app.api import x` 挪进函数体掩盖循环依赖 ✅ 按第 3 节单向分层，共享类型下沉到 models/ 或 core/（仅 `if TYPE_CHECKING:` 下的类型引用例外）
9. 迁移纪律（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md）：alembic 目录须叫 `migrations/`（async 驱动用 `alembic init -t async migrations`，同步模板配 asyncpg/aiosqlite 必报 MissingGreenlet），护栏钩子 [pre-edit-migrations.sh](../../claude-code/hooks/pre-edit-migrations.sh) 按此路径拦截，装法见 [hooks.md](../../claude-code/hooks.md)
   - ❌ 改写/删除已有 migration，或自行跑 `alembic downgrade`/reset/drop/删数据 ✅ 起草新 migration 贴进回复交人审、由人落盘（钩子对迁移目录的 Edit/Write 一律拦，新建也拦），破坏性操作须人类显式确认；roll-forward-only：错了再写一条向前修正，不写 down（人一次性把 `migrations/script.py.mako` 的 downgrade 体改成 `raise NotImplementedError`）
   - ❌ 生成完直接 apply ✅ 人审 + 本地非空库 `alembic upgrade head` 跑过才 apply，AI 不持生产库凭证（hook 是护栏不是安全边界，真边界是凭证隔离）
10. over-mock 保 CI 绿（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md）：❌ `patch` 掉 session/repository、把数据库换成内存假实现让测试变绿 ✅ mock 仅限外部付费/不可控服务（第三方 API 等）；数据库/缓存走 testcontainers 真实例（第 1 节），核心用户路径必须有穿真 DB 的集成测试

## 7. 配置文件索引

| 文件 | 内容 | 用法 |
| --- | --- | --- |
| [configs/pyproject.toml](configs/pyproject.toml) | `[project]` 骨架 + `[build-system]`（uv_build，src layout 装 editable）+ ruff（lint/format）+ pytest（含 asyncio auto）+ mypy strict 基线 + import-linter 分层契约 | `uv init --package` 后整份覆盖，改 `name`（`[tool.importlinter]` 的 root_package、containers 同改）与依赖后 `uv sync`；`[build-system]` 必留 |
| [configs/contracts-ci.yml](configs/contracts-ci.yml) | GitHub Actions 契约门禁：迁移后 `alembic check` + `tbls diff` 防 dbdoc/ 漂移；导出 openapi.json 后 `git diff --exit-code` + oasdiff（`fail-on: ERR`）+ Spectral lint | 触发制：真实 API 项目开工才复制为 `.github/workflows/contracts.yml`，前置见文件头注释；无对外 API 删 `api-contract` job |
| [configs/security-ci.yml](configs/security-ci.yml) | 安全门禁：gitleaks 每次扫全部历史；依赖有变化时 `uv lock --check` + `uv audit` 卡 PR；每周 osv-scanner 全量 | 直接启用：复制为 `.github/workflows/security.yml`；本地两个钩子见 [claude-code/hooks.md](../../claude-code/hooks.md) |
| [configs/osv-scanner.toml](configs/osv-scanner.toml) | 排除 editable 根包（本项目自身）+ 忽略项写法 | 复制到 uv.lock 同目录，`name` 与 `[project].name` 同改 |

ruff/mypy 报错默认改代码不改配置。确要放宽：ruff 动 `[tool.ruff.lint]`，mypy 加 `[[tool.mypy.overrides]]` 按模块放，并在提交说明里写原因；禁无注释的行内 `# noqa` / `# type: ignore`。
