#!/usr/bin/env bash
# install.sh —— 把本库的模板、栈配置、钩子与 CI 模板装进一个目标项目：README「快速开始」第 1、2 步的一条命令版。
# 只复制、不删除；目标里已存在的文件默认一律跳过（--force 才覆盖），最后汇总写了什么、跳过了什么、接下来要做什么。
# 生成 .claude/settings.json 时按栈裁掉用不上的 permissions.allow，要用 python3；没有就原样复制并提示手动删。
# 兼容 macOS 自带的 bash 3.2：不用关联数组，空数组一律用 ${a[@]+"${a[@]}"} 展开。
# 各文件的取舍见 stacks/<栈>/README.md 第 7 节与 claude-code/hooks.md；新增或改名配置时同步改这里（scripts/check.py 会查）。

usage() {
  cat <<'EOF'
用法：scripts/install.sh <目标项目目录> <栈> [选项]
  栈：typescript-react | python | go
  --with-migrations  同时挂上迁移护栏钩子（项目有数据库迁移时用）
  --with-contracts   同时装契约 CI 模板（真实 API 项目开工时用）
  --dry-run          只列出将要做的事，不写任何文件
  --force            覆盖已存在的文件（默认一律跳过，绝不覆盖）
EOF
  exit "${1:-0}"
}

LIB="$(cd "$(dirname "$0")/.." && pwd -P)"
TARGET="" STACK="" WITH_MIG=0 WITH_CONTRACTS=0 DRY=0 FORCE=0
for arg in "$@"; do
  case "$arg" in
    --with-migrations) WITH_MIG=1 ;;
    --with-contracts) WITH_CONTRACTS=1 ;;
    --dry-run) DRY=1 ;;
    --force) FORCE=1 ;;
    -h | --help) usage 0 ;;
    -*) echo "未知选项：$arg" >&2; usage 2 ;;
    *)
      if [ -z "$TARGET" ]; then TARGET="$arg"
      elif [ -z "$STACK" ]; then STACK="$arg"
      else echo "多余的参数：$arg" >&2; usage 2
      fi ;;
  esac
done
[ -n "$TARGET" ] && [ -n "$STACK" ] || usage 2
case "$STACK" in
  typescript-react | python | go) ;;
  *) echo "未知的栈：$STACK（可选 typescript-react / python / go）" >&2; exit 2 ;;
esac
[ -d "$TARGET" ] || { echo "目标目录不存在：$TARGET" >&2; exit 2; }
TARGET="$(cd "$TARGET" && pwd -P)" # 一律取物理路径：macOS 的 /tmp、/var 是符号链接，git 返回的是解析后的路径
[ "$TARGET" != "$LIB" ] || { echo "目标不能是本库自身：$TARGET" >&2; exit 2; }
CFG="$LIB/stacks/$STACK/configs"

DONE=() SKIP=() TODO=()

# put <源文件> <目标相对路径>：已存在且没加 --force 就跳过（返回 1）；源文件缺失直接报错退出，免得静默漏装
put() {
  [ -f "$1" ] || { echo "本库缺少源文件：$1（安装脚本与目录不同步）" >&2; exit 1; }
  if [ -e "$TARGET/$2" ] && [ "$FORCE" -ne 1 ]; then SKIP+=("$2"); return 1; fi
  if [ "$DRY" -eq 1 ]; then DONE+=("$2（演练，未写入）"); return 0; fi
  mkdir -p "$(dirname "$TARGET/$2")" && cp "$1" "$TARGET/$2" && DONE+=("$2")
}

# put_exec：同 put，写入后补可执行位
put_exec() {
  put "$1" "$2" || return 1
  [ "$DRY" -eq 1 ] || chmod +x "$TARGET/$2"
}

echo "安装到：$TARGET（栈：$STACK）"
[ "$DRY" -eq 1 ] && echo "演练模式：只列出动作，不写任何文件。"

# ---------- 1. 项目级 CLAUDE.md ----------
put "$LIB/templates/CLAUDE.md.template" CLAUDE.md

# ---------- 2. 栈配置与 CI 模板（与 stacks/<栈>/README.md 第 7 节一致） ----------
case "$STACK" in
  typescript-react)
    for f in eslint.config.js tsconfig.json .prettierrc.json .prettierignore .dependency-cruiser.cjs; do
      put "$CFG/$f" "$f"
    done
    TODO+=("package.json 的 scripts 照 stacks/typescript-react/README.md 第 2 节补齐（lint、typecheck、lint:deps、gen:api 等），packageManager 钉到当前 pnpm 版本")
    ;;
  python)
    if ! put "$CFG/pyproject.toml" pyproject.toml; then
      TODO+=("已有 pyproject.toml，没有覆盖：若是 uv init --package 刚生成的，加 --force 重跑；存量项目对照 stacks/python/configs/pyproject.toml 手动合并")
    fi
    put "$CFG/osv-scanner.toml" osv-scanner.toml
    TODO+=("把 pyproject.toml 与 osv-scanner.toml 里的占位包名 example 改成真实包名：[project].name、root_package、containers、PackageOverrides 四处")
    TODO+=("确认 src/<包名>/__init__.py 已存在（uv init --package 会建），否则 uv sync 会报错")
    ;;
  go)
    put "$CFG/.golangci.yml" .golangci.yml
    TODO+=("应用项目在 go.mod 写 toolchain 行，与构建发布用的 Go 一致：govulncheck 按它判定标准库漏洞")
    ;;
esac
put "$CFG/security-ci.yml" .github/workflows/security.yml
[ "$WITH_CONTRACTS" -eq 1 ] && put "$CFG/contracts-ci.yml" .github/workflows/contracts.yml

# ---------- 3. Claude Code 钩子：脚本全装，是否启用由 settings 决定 ----------
for src in "$LIB"/claude-code/hooks/*.sh; do
  put_exec "$src" ".claude/hooks/$(basename "$src")"
done

# ---------- 4. .claude/settings.json：已有就不碰 ----------
SETTINGS=.claude/settings.json
EXTRA=""
[ "$WITH_MIG" -eq 1 ] && EXTRA="，已挂迁移护栏"
if [ -e "$TARGET/$SETTINGS" ] && [ "$FORCE" -ne 1 ]; then
  SKIP+=("$SETTINGS")
  TODO+=("已有 $SETTINGS，没有改动：把 claude-code/settings.json.example 的 hooks 段合并进去（见 claude-code/hooks.md）")
  [ "$WITH_MIG" -eq 1 ] && TODO+=("迁移护栏没挂上：照 claude-code/hooks.md 把 pre-edit-migrations.sh 那一项加进 hooks.PreToolUse")
elif [ "$DRY" -eq 1 ]; then
  DONE+=("$SETTINGS（演练，未写入；按栈裁剪 permissions.allow$EXTRA）")
elif command -v python3 >/dev/null 2>&1; then
  mkdir -p "$TARGET/.claude"
  python3 -I - "$LIB/claude-code/settings.json.example" "$TARGET/$SETTINGS" "$STACK" "$WITH_MIG" <<'PY' || exit 1
import json, sys
src, dst, stack, with_mig = sys.argv[1:5]
with open(src, encoding="utf-8") as fh:
    d = json.load(fh)
keep = {"typescript-react": "Bash(pnpm ", "python": "Bash(uv ", "go": "Bash(go "}[stack]
d["permissions"]["allow"] = [r for r in d["permissions"]["allow"] if r.startswith((keep, "Bash(git "))]
if with_mig == "1":
    d["hooks"].setdefault("PreToolUse", []).append({"matcher": "Edit|Write", "hooks": [
        {"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-edit-migrations.sh", "args": []}]})
with open(dst, "w", encoding="utf-8") as fh:
    json.dump(d, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY
  DONE+=("$SETTINGS（按栈裁剪 permissions.allow$EXTRA）")
else
  mkdir -p "$TARGET/.claude" && cp "$LIB/claude-code/settings.json.example" "$TARGET/$SETTINGS"
  DONE+=("$SETTINGS（没有 python3，原样复制）")
  TODO+=("按栈删掉 $SETTINGS 里 permissions.allow 用不上的命令")
  [ "$WITH_MIG" -eq 1 ] && TODO+=("迁移护栏没挂上：照 claude-code/hooks.md 把 pre-edit-migrations.sh 那一项加进 hooks.PreToolUse")
fi

# ---------- 5. git 提交前钩子 ----------
put_exec "$LIB/claude-code/githooks/pre-commit" .githooks/pre-commit
if TOP="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)"; then
  HOOKS_PATH="$(git -C "$TARGET" config --get core.hooksPath)"
  if [ "$(cd "$TOP" && pwd -P)" != "$TARGET" ]; then
    TODO+=("目标在仓库 $TOP 的子目录里：把 .githooks 挪到仓库根，再在仓库根执行 git config core.hooksPath .githooks")
  elif [ -z "$HOOKS_PATH" ]; then
    if [ "$DRY" -eq 1 ]; then DONE+=("git config core.hooksPath .githooks（演练，未执行）")
    else git -C "$TARGET" config core.hooksPath .githooks && DONE+=("git config core.hooksPath .githooks")
    fi
  elif [ "$HOOKS_PATH" != ".githooks" ]; then
    TODO+=("core.hooksPath 已设为 $HOOKS_PATH（husky 等工具在管），没有改动：在那边的 pre-commit 里加一行 gitleaks git --pre-commit --staged --redact")
  fi
else
  TODO+=("目标还不是 git 仓库：git init 之后执行 git config core.hooksPath .githooks")
fi

# ---------- 汇总 ----------
echo
echo "已写入："
for x in ${DONE[@]+"${DONE[@]}"}; do echo "  - $x"; done
if [ "${#SKIP[@]}" -gt 0 ]; then
  echo "已存在、没有覆盖（要覆盖加 --force）："
  for x in "${SKIP[@]}"; do echo "  - $x"; done
fi
echo "接下来："
for x in ${TODO[@]+"${TODO[@]}"}; do echo "  - $x"; done
echo "  - 按注释填好 CLAUDE.md，模块地图必填，填完删掉注释"
echo "  - 本机装 gitleaks（brew install gitleaks）：两个本地密钥钩子缺它就直接放行"
echo "  - .github/workflows 里标 <占位> 的行按项目改（默认分支名等）；推上去后在 Actions 页手动跑一次 security，确认日志里扫到了 lockfile"
echo "  - 在 GitHub 仓库的 Settings → Advanced Security 打开 Dependabot alerts"
echo "  - 把 CLAUDE.md、.claude/、.githooks/、.github/ 与配置文件一起提交"
