#!/usr/bin/env bash
# stop-verify.sh —— Stop 钩子：Claude 要收工时先跑快检，没过就 exit 2 打回去继续修。
# ⚠️ 激进钩子：每次收工都跑全套快检。快检超过约 30 秒的项目请精简——
#    删掉下面慢的检查段（典型是 go build、大仓 typecheck），或干脆不挂 Stop 钩子，改为手动验证。
# 防死循环：stdin 的 stop_hook_active 为 true（本次续跑就是 stop hook 造成的）时立即放行。
# 项目类型按标志文件探测，可多栈共存：package.json → TS/JS；pyproject.toml → Python；go.mod → Go。
# 安装与调试见 ../hooks.md：复制到目标项目 .claude/hooks/ 并 chmod +x。

set -u

INPUT="$(cat)"

# ---------- 1. 防死循环：已被本钩子打回过，这次直接放行 ----------
stop_hook_active() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    print("true" if json.load(sys.stdin).get("stop_hook_active") else "false")
except Exception:
    print("false")
' 2>/dev/null
  else
    # 连 python3 都没有：退化为字符串探测。宁可误放行，也不能死循环。
    case "$INPUT" in
      *'"stop_hook_active":true'* | *'"stop_hook_active": true'*) echo "true" ;;
      *) echo "false" ;;
    esac
  fi
}

[ "$(stop_hook_active)" = "true" ] && exit 0

cd "${CLAUDE_PROJECT_DIR:-$PWD}" || exit 0

# ---------- 2. 快检 ----------
FAILURES=""

run_check() { # 用法: run_check <展示名> <命令及参数...>
  local name="$1" output
  shift
  if ! output="$("$@" 2>&1)"; then
    FAILURES="${FAILURES}
--- ${name} 失败（输出末尾 20 行）---
$(printf '%s\n' "$output" | tail -n 20)"
  fi
}

# TS/JS：只跑 package.json 里真实存在的 lint / typecheck 脚本
has_npm_script() {
  if command -v jq >/dev/null 2>&1; then
    jq -e --arg s "$1" '.scripts[$s]' package.json >/dev/null 2>&1
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys
try:
    ok = bool(json.load(open("package.json")).get("scripts", {}).get(sys.argv[1]))
except Exception:
    ok = False
sys.exit(0 if ok else 1)
' "$1" 2>/dev/null
  else
    return 1
  fi
}

if [ -f package.json ]; then
  PM="npm"
  [ -f yarn.lock ] && PM="yarn"
  [ -f pnpm-lock.yaml ] && PM="pnpm"
  for s in lint typecheck; do
    if has_npm_script "$s"; then
      run_check "$PM run $s" "$PM" run "$s"
    fi
  done
fi

# Python：ruff check（优先直接命令，没有就试 uv run）
if [ -f pyproject.toml ]; then
  if command -v ruff >/dev/null 2>&1; then
    run_check "ruff check" ruff check .
  elif command -v uv >/dev/null 2>&1; then
    run_check "uv run ruff check" uv run ruff check .
  fi
fi

# Go：vet + build
if [ -f go.mod ] && command -v go >/dev/null 2>&1; then
  run_check "go vet" go vet ./...
  run_check "go build" go build ./...
fi

# ---------- 3. 结论 ----------
if [ -n "$FAILURES" ]; then
  {
    echo "stop-verify：快检未通过，不能收工。先修复以下问题："
    printf '%s\n' "$FAILURES"
  } >&2
  exit 2 # Stop 事件上 exit 2 = 阻止收工，以上 stderr 会作为原因反馈给 Claude
fi

exit 0
