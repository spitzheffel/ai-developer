#!/usr/bin/env bash
# pre-edit-migrations.sh —— PreToolUse(Edit|Write) 钩子：要编辑的文件落在迁移目录就 exit 2 拦下，migration 交人审后由人落盘。
# 迁移纪律三条（来源：调研 2026-11，docs/research/adoption-plan.md W4）：
#   1. AI 只许新增 migration 文件，永不修改或删除已存在的 migration；
#   2. 禁 reset / drop / 删数据类操作，除非人类显式确认；
#   3. migration 一律人审，且在本地非空库跑过才 apply；AI 不持有生产库凭证。
#   配套 roll-forward-only：不写 down migration，错了就再写一条向前修正的新 migration。
# 本钩子只机械执行第 1 条且取最严口径（迁移目录内 Edit/Write 一律拦，新增也交人审后落盘）；第 2、3 条靠人审与凭证隔离。
# ⚠️ 清醒：hook 是护栏不是安全边界——它只管 Edit/Write，模型仍可能绕道 Bash 改迁移；真边界是凭证隔离。
# 迁移目录 = 路径含目录段 migrations/、db/migrate/、db/migration/、alembic/versions/（大小写不敏感）。
#   刻意不认裸 migrate/（Go 的 cmd/migrate/ 多是迁移执行器源码）；项目另有形态（如 Drizzle 默认的 drizzle/）就往下面 case 里加。
# 取不到路径（JSON 解析失败、jq 与 python3 都没有）一律放行：护栏宁可失效，也不误拦正常编辑。
# 安装与调试见 ../hooks.md：复制到目标项目 .claude/hooks/ 并 chmod +x，settings 片段也在那里。

set -u

INPUT="$(cat)"

# ---------- 1. 取被编辑文件的路径：优先 jq，缺 jq 用 python3 兜底，都没有就放行 ----------
extract_file_path() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    # -I 隔离模式：不从 cwd 导入模块，防项目里同名的 json.py 顶替标准库
    printf '%s' "$INPUT" | python3 -I -c '
import json, sys
try:
    sys.stdout.write((json.load(sys.stdin).get("tool_input") or {}).get("file_path") or "")
except Exception:
    pass
' 2>/dev/null
  fi
}

FILE="$(extract_file_path)"
[ -n "$FILE" ] || exit 0

# ---------- 2. 判定：先统一分隔符与大小写，再按目录段匹配 ----------
NORM="${FILE//\\//}"                                        # Windows 反斜杠 → 正斜杠，否则 */ 模式永远匹配不上
NORM="/$(printf '%s' "$NORM" | tr '[:upper:]' '[:lower:]')" # 前补 /：路径万一是相对的（migrations/x.sql）也能命中

case "$NORM" in
  */migrations/* | */db/migrate/* | */db/migration/* | */alembic/versions/*)
    {
      echo "pre-edit-migrations：已拦下对迁移目录的编辑：$FILE"
      echo "migration 只许人审后新增，AI 不得改写既有迁移；要修正就起草一条向前修正的新 migration（roll-forward-only，不写 down）。"
      echo "把草稿贴进回复交人审、由人落盘；不要改用 Bash 等方式绕过本钩子。"
    } >&2
    exit 2 # PreToolUse 上 exit 2 = 拦下本次 Edit/Write，以上 stderr 作为拒绝理由反馈给 Claude
    ;;
esac

exit 0
