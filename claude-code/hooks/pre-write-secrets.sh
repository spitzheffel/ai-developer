#!/usr/bin/env bash
# pre-write-secrets.sh —— PreToolUse(Write|Edit|NotebookEdit) 钩子：AI 写盘前用 gitleaks 扫待写入的文本，疑似密钥就 exit 2 拦下。
# 来源：调研 2026-11，docs/research/adoption-plan.md 可选池 OP1（安全双层的本地层之一）。
# 取文本：Write → tool_input.content；Edit → tool_input.new_string；NotebookEdit → tool_input.new_source。
# 必须 --exit-code 2：Claude Code 只认 exit 2 为拦截，gitleaks 默认的 exit 1 在这里只是一条非阻断提示。
# 豁免：确为测试假值就在该行加注释 gitleaks:allow；成批的误报写进项目根的 .gitleaks.toml allowlist（gitleaks stdin 从当前目录读它）。
# 没装 gitleaks、取不到文本（jq 与 python3 都没有、JSON 解析失败）一律放行：护栏宁可失效，也不误拦正常编辑。
# ⚠️ 清醒：它只管 Write/Edit，模型仍可能经 Bash 写文件；提交前的 git 钩子 ../githooks/pre-commit 与各栈 configs/security-ci.yml 的 CI 全量扫描兜底。
# 安装与调试见 ../hooks.md：复制到目标项目 .claude/hooks/ 并 chmod +x，settings.json.example 已挂好。

set -u

INPUT="$(cat)"

command -v gitleaks >/dev/null 2>&1 || exit 0

# ---------- 1. 取待写入的文本：优先 jq，缺 jq 用 python3 兜底，都没有就放行 ----------
extract_text() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // .tool_input.new_source // empty' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    # -I 隔离模式：不从 cwd 导入模块，防项目里同名的 json.py 顶替标准库
    printf '%s' "$INPUT" | python3 -I -c '
import json, sys
try:
    ti = json.load(sys.stdin).get("tool_input") or {}
    for key in ("content", "new_string", "new_source"):
        value = ti.get(key)
        if isinstance(value, str) and value:
            sys.stdout.write(value)
            break
except Exception:
    pass
' 2>/dev/null
  fi
}

TEXT="$(extract_text)"
[ -n "$TEXT" ] || exit 0

# ---------- 2. 扫描：在项目根执行，让 gitleaks 读到项目的 .gitleaks.toml ----------
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true

OUT="$(printf '%s\n' "$TEXT" | gitleaks stdin --redact --no-banner -v --exit-code 2 2>&1)"
RC=$?

if [ "$RC" -eq 2 ]; then
  {
    printf '%s\n' "$OUT"
    echo "pre-write-secrets：待写入的内容里有疑似密钥（上面是 gitleaks 打码后的发现），本次写入已拦下。"
    echo "真密钥：不要写进文件，改为读环境变量，.env.example 里只放占位名；确为测试假值：在该行加注释 gitleaks:allow 后重写。"
  } >&2
  exit 2 # PreToolUse 上 exit 2 = 拦下本次写入，以上 stderr 作为拒绝理由反馈给 Claude
fi

exit 0 # 0 = 无发现；其他（gitleaks 自身出错）= 放行，不误拦
