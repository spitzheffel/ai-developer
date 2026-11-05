> 给在 Python 代码库里干活的 Claude Code 会话与未来的自己看：开新 Python 项目或接手存量项目动手前加载。配置不手写，整份复制 [configs/pyproject.toml](configs/pyproject.toml)。

# Python 栈

## 1. 选型清单

默认栈，新项目不讨论直接用；想换先走 [build-vs-buy](../../process/build-vs-buy.md)，换定后回来更新本表。

| 需求域 | 钉死 | 禁用 | 一句话理由 |
| --- | --- | --- | --- |
| 语言版本 | Python 3.12+（`requires-python = ">=3.12"`） | 给 `requires-python` 封上界（如 `<3.13`） | 上界徒增解析冲突，只写下界 |
| 包与环境 | uv | 新项目用 pip/poetry/conda | 单一入口：依赖只经 `uv add` / `uv remove` 进出 |
| Web 框架 | FastAPI | — | — |
| 数据模型与校验 | pydantic v2 | pydantic v1 语法 | v1 写法一律算 bug（见第 6 节坑 3） |
| HTTP 客户端 | httpx | 新代码引 requests | requests 无异步支持（见第 6 节坑 4、5） |
| ORM | SQLAlchemy 2.0 风格 + alembic | legacy 的 `session.query()` | 全库统一 `select()` 范式（见第 5 节） |
| 日志 | structlog | 调试 print 残留进提交 | — |
| CLI | typer | — | — |
| 测试 | pytest（异步用 pytest-asyncio，auto 模式已写进配置） | — | — |
| Lint + Format | ruff 全包 | black/isort/flake8 叠加 | ruff 一个工具全管 |
| 类型检查 | mypy（strict 基线，放宽只按模块在 overrides 做） | — | — |

## 2. 工具链与命令

所有命令带 `uv run` 前缀跑在项目环境里，不手动激活 venv、不裸调全局解释器。

| 场景 | 命令 |
| --- | --- |
| 初始化项目 | `uv init` |
| 按锁文件装环境 | `uv sync`（CI 用 `uv sync --locked`） |
| 加运行依赖 | `uv add fastapi`（写入 `[project.dependencies]` 并更新 uv.lock） |
| 加开发依赖 | `uv add --dev pytest`（写入 `[dependency-groups].dev`） |
| 跑测试 | `uv run pytest` |
| Lint + 自动修复 | `uv run ruff check --fix` |
| 格式化 | `uv run ruff format`（只校验不改码用 `--check`） |
| 类型检查 | `uv run mypy src/` |

- 提交前全套：`uv run ruff check --fix && uv run ruff format && uv run mypy src/ && uv run pytest`。
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

## 7. 配置文件索引

| 文件 | 内容 | 用法 |
| --- | --- | --- |
| [configs/pyproject.toml](configs/pyproject.toml) | `[project]` 骨架 + ruff（lint/format）+ pytest（含 asyncio auto）+ mypy strict 基线 | 新项目整份复制，改 `name` 与依赖后 `uv sync` |

ruff/mypy 报错默认改代码不改配置。确要放宽：ruff 动 `[tool.ruff.lint]`，mypy 加 `[[tool.mypy.overrides]]` 按模块放，并在提交说明里写原因；禁无注释的行内 `# noqa` / `# type: ignore`。
