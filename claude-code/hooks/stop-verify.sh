#!/usr/bin/env bash
# stop-verify.sh —— Stop 钩子：Claude 要收工时先跑快检，没过就 exit 2 打回去继续修。
# 只在有改动时跑：自上次检查通过以来工作区没变（纯问答、只读的回合）就直接放行，不付检查成本。
# 打回时只要求修本次改动引入的问题；同一组失败只打回一次，之后改为只给你一条提示，不逼 Claude 去修范围外的旧问题。
# 快检超过约 30 秒的项目仍要精简：删掉下面慢的检查段（典型是 go build、大仓 typecheck），或干脆不挂 Stop 钩子，改为手动验证。
# 防死循环：stdin 的 stop_hook_active 为 true（本次续跑就是 stop hook 造成的）时立即放行。
# 项目类型按标志文件探测，可多栈共存：package.json → TS/JS；pyproject.toml → Python；go.mod → Go。
# 状态记在 .git 目录里（不进工作区、不进版本库）；不是 git 仓库时退回旧行为：每次收工都跑、失败就打回。
# 来源：pain-log 2026-11-06。安装与调试见 ../hooks.md：复制到目标项目 .claude/hooks/ 并 chmod +x。

set -u

INPUT="$(cat)"

# ---------- 1. 防死循环：已被本钩子打回过，这次直接放行 ----------
stop_hook_active() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    # -I 隔离模式：不从 cwd 导入模块，防项目里同名的 json.py 顶替标准库（下方 has_npm_script 同理）
    printf '%s' "$INPUT" | python3 -I -c '
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

# ---------- 2. 有没有改动：工作区指纹与上次通过时相同就放行 ----------
STATE=""
if GIT_DIR_ABS="$(git rev-parse --absolute-git-dir 2>/dev/null)"; then
  STATE="$GIT_DIR_ABS/claude-stop-verify" # 放在 .git 里：写在工作区的话，状态文件本身就会改变指纹
fi

fingerprint() { # HEAD + 已暂存与未暂存的改动 + 未跟踪文件的名字与内容：任一处变了，指纹就变
  {
    git rev-parse --verify -q HEAD
    git diff --cached --no-ext-diff --binary
    git diff --no-ext-diff --binary
    git ls-files --others --exclude-standard
    git ls-files --others --exclude-standard | git hash-object --stdin-paths
  } 2>/dev/null | git hash-object --stdin 2>/dev/null
}

FP=""
if [ -n "$STATE" ]; then
  FP="$(fingerprint)"
  if [ -n "$FP" ] && [ "$FP" = "$(cat "$STATE.pass" 2>/dev/null)" ]; then
    rm -f "$STATE.fail" # 回到了已知通过的状态：之后再出现的失败都算新的，要重新打回
    exit 0
  fi
fi

# ---------- 3. 快检 ----------
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
    python3 -I -c '
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

# ---------- 4. 结论 ----------
if [ -z "$FAILURES" ]; then
  if [ -n "$FP" ]; then
    printf '%s\n' "$FP" > "$STATE.pass" 2>/dev/null
    rm -f "$STATE.fail"
  fi
  exit 0
fi

if [ -n "$STATE" ]; then
  FH="$(printf '%s' "$FAILURES" | git hash-object --stdin 2>/dev/null)"
  if [ -n "$FH" ] && [ "$FH" = "$(cat "$STATE.fail" 2>/dev/null)" ]; then
    # 失败与上次打回时完全相同：多半是改动之前就有的问题，或上次已经报告过。只提示你，不再打回 Claude
    echo '{"systemMessage":"stop-verify：快检仍未通过，失败与上次打回时完全相同（多半是改动前就有的问题），这次不再打回。要看详情就手动跑一遍 lint 与 typecheck。"}'
    exit 0
  fi
  [ -n "$FH" ] && printf '%s\n' "$FH" > "$STATE.fail" 2>/dev/null
fi

{
  echo "stop-verify：快检未通过，不能收工。只修本次改动引入的问题；改动之前就有的错误不要顺手修（只动范围内的文件），在回复里列出来交给人决定："
  printf '%s\n' "$FAILURES"
} >&2
exit 2 # Stop 事件上 exit 2 = 阻止收工，以上 stderr 会作为原因反馈给 Claude
