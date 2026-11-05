#!/usr/bin/env bash
# post-edit-format.sh —— PostToolUse(Edit|Write|NotebookEdit) 钩子：刚编辑的文件立即按扩展名格式化。
#   ts/tsx/js/jsx/json/css/md → 项目本地 prettier（存在 node_modules/.bin/prettier 且可执行才跑）
#   py                        → ruff format（命令存在才跑）
#   go                        → gofmt -w（命令存在才跑）
# 原则：格式化失败、工具缺失、JSON 解析失败一律不阻塞 —— 本脚本所有路径都 exit 0。
# （PostToolUse 阶段工具已执行完，本就拦不住；在这里报错只会制造噪音。）
# 安装与调试见 ../hooks.md：复制到目标项目 .claude/hooks/ 并 chmod +x。

set -u

INPUT="$(cat)"

# 从 stdin JSON 提取被编辑文件的绝对路径：优先 jq，缺 jq 用 python3 兜底，都没有就放弃
extract_file_path() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    # -I 隔离模式：不从 cwd 导入模块，防项目里同名的 json.py 顶替标准库
    printf '%s' "$INPUT" | python3 -I -c '
import json, sys
try:
    ti = json.load(sys.stdin).get("tool_input") or {}
    sys.stdout.write(ti.get("file_path") or ti.get("notebook_path") or "")
except Exception:
    pass
' 2>/dev/null
  fi
}

FILE="$(extract_file_path)"
[ -n "$FILE" ] && [ -f "$FILE" ] || exit 0

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

case "$FILE" in
  *.ts | *.tsx | *.js | *.jsx | *.json | *.css | *.md)
    PRETTIER="$PROJECT_ROOT/node_modules/.bin/prettier"
    if [ -x "$PRETTIER" ]; then
      "$PRETTIER" --write "$FILE" >/dev/null 2>&1 || true
    fi
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      ruff format "$FILE" >/dev/null 2>&1 || true
    fi
    ;;
  *.go)
    if command -v gofmt >/dev/null 2>&1; then
      gofmt -w "$FILE" >/dev/null 2>&1 || true
    fi
    ;;
  *)
    : # 无匹配扩展名：静默退出
    ;;
esac

exit 0
