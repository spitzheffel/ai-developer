#!/usr/bin/env python3
# check.py —— 本库自检：把 CLAUDE.md 的「行数预算」「结构约束」两节变成机器检查。
# 用法：
#   python3 scripts/check.py          手动或 CI：全部通过 exit 0，有问题 exit 1
#   python3 scripts/check.py --hook   本库的 Claude Code Stop 钩子：stdin 的 stop_hook_active 为 true 直接放行；有问题 exit 2 打回
# 规则只有一份来源：行数预算直接解析 CLAUDE.md 的预算表（改表即改检查），七节标题以 stacks/_template.md 为准。
# 检查项：行数预算；栈 README 七节；md 与模板以 > 引用块开场；表格每行列数与表头一致；相对链接指向真实文件；
#   README 目录树列出磁盘上的每个文件；安装脚本覆盖各栈 configs 的每个文件；
#   配置语法（shell、Python、JSON/JSONC、YAML、TOML、JS，以及 md 里的 ```json 代码块）与钩子脚本的可执行位。
# 只用标准库。YAML 依次尝试 PyYAML、ruby、yq，都没有就跳过并告警；TOML 需要 Python 3.11+ 或装了 tomli。

from __future__ import annotations  # 注解延迟求值：macOS 自带的 Python 3.9 也能跑

import fnmatch
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FENCE = re.compile(r"^```.*?^```[ \t]*$", re.S | re.M)
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
TEXT_SUFFIXES = (".md", ".template")
EXEC_DIRS = ("claude-code/hooks/", "claude-code/githooks/", "scripts/")
TREE_EXEMPT = {".gitignore"}

problems: list[str] = []
warnings: list[str] = []
passed: list[str] = []


def fail(kind: str, msg: str) -> None:
    problems.append(f"[{kind}] {msg}")


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def blank_fences(text: str) -> str:
    """代码块内容换成等量空行：块里的 ## 、链接、表格不参与检查，行号保持不变。"""
    return FENCE.sub(lambda m: "\n" * m.group(0).count("\n"), text)


def list_files() -> list[str]:
    try:
        out = subprocess.run(
            ["git", "-C", str(ROOT), "ls-files", "-co", "--exclude-standard"],
            capture_output=True, text=True, check=True,
        ).stdout.splitlines()
    except (OSError, subprocess.CalledProcessError):
        out = [p.relative_to(ROOT).as_posix() for p in ROOT.rglob("*") if ".git" not in p.relative_to(ROOT).parts]
    return sorted(f for f in set(out) if (ROOT / f).is_file())


# ---------- 行数预算：解析 CLAUDE.md 的预算表 ----------
def check_budgets(files: list[str]) -> None:
    m = re.search(r"^## 行数预算.*?\n(.*?)(?=^## )", read("CLAUDE.md"), re.S | re.M)
    if not m:
        fail("预算", "CLAUDE.md 里找不到「## 行数预算」节")
        return
    covered: set[str] = set()
    deferred = []
    checked = 0

    def over(f: str, limit: int, label: str) -> None:
        nonlocal checked
        checked += 1
        n = len(read(f).splitlines())
        if n > limit:
            fail("预算", f"{f} 有 {n} 行，超过「{label}」的上限 {limit}")

    for label, limit in re.findall(r"^\|([^|\n]+)\|([^|\n]+)\|[ \t]*$", m.group(1), re.M):
        label = label.strip()
        num = re.search(r"\d+", limit)
        if not num:
            continue  # 表头与分隔行
        cap = int(num.group())
        name = re.sub(r"（[^）]*）", "", label).strip()
        if name.endswith("其余模板"):  # 放到最后：排除表里已单独列出的模板
            deferred.append((label, name.split()[0], cap))
            continue
        if name.endswith("各文件"):
            d = name.split()[0]
            targets = [f for f in files if f.startswith(d) and "/" not in f[len(d):] and f.endswith(".md")]
        elif "*" in name:
            targets = [f for f in files if fnmatch.fnmatch(f, name)]
        else:
            targets = [name] if name in files else []
        if not targets:
            fail("预算", f"预算表的「{label}」匹配不到任何文件")
        for f in targets:
            covered.add(f)
            over(f, cap, label)
    for label, d, cap in deferred:
        for f in files:
            if f.startswith(d) and "/" not in f[len(d):] and f not in covered:
                covered.add(f)
                over(f, cap, label)
    for f in files:
        if f.endswith(TEXT_SUFFIXES) and f not in covered and not f.startswith("docs/research/"):
            warnings.append(f"{f} 不在 CLAUDE.md 的预算表里")
    passed.append(f"行数预算：{checked} 个文件")


# ---------- 结构：七节、> 开场、表格列数 ----------
def headings(text: str) -> list[str]:
    return [line.rstrip() for line in blank_fences(text).splitlines() if line.startswith("## ")]


def check_stack_sections(files: list[str]) -> None:
    expected = headings(read("stacks/_template.md"))
    if len(expected) != 7:
        fail("结构", f"stacks/_template.md 应有 7 个 ## 节，实际 {len(expected)} 个")
    stacks = [f for f in files if fnmatch.fnmatch(f, "stacks/*/README.md")]
    for f in stacks:
        got = headings(read(f))
        if got != expected:
            diff = next((f"第 {i + 1} 节应为「{e}」，实际「{g}」" for i, (e, g) in enumerate(zip(expected, got)) if e != g),
                        f"应有 {len(expected)} 节，实际 {len(got)} 节")
            fail("结构", f"{f} 的 ## 节与 stacks/_template.md 不一致：{diff}")
    passed.append(f"七节结构：{len(stacks)} 个栈")


def check_quote_opening(files: list[str]) -> None:
    targets = [f for f in files if f.endswith(TEXT_SUFFIXES)]
    for f in targets:
        first = next((line for line in read(f).splitlines() if line.strip()), "")
        if not first.startswith(">"):
            fail("结构", f"{f} 没有以 > 引用块开场（首个非空行：{first[:40]}）")
    passed.append(f"> 开场：{len(targets)} 个文件")


def cell_count(row: str) -> int:
    s = row.strip().replace("\\|", "")
    s = re.sub(r"`[^`]*`", lambda m: m.group(0).replace("|", ""), s)
    return len(s.strip("|").split("|"))


def check_tables(files: list[str]) -> None:
    tables = 0
    for f in files:
        if not f.endswith(TEXT_SUFFIXES):
            continue
        lines = blank_fences(read(f)).splitlines()
        i = 0
        while i < len(lines):
            if lines[i].startswith("|") and i + 1 < len(lines) and re.match(r"^\|\s*:?-{3,}", lines[i + 1]):
                tables += 1
                width = cell_count(lines[i])
                j = i + 2
                while j < len(lines) and lines[j].startswith("|"):
                    if cell_count(lines[j]) != width:
                        fail("表格", f"{f}:{j + 1} 有 {cell_count(lines[j])} 列，表头是 {width} 列")
                    j += 1
                i = j
            else:
                i += 1
    passed.append(f"表格列数：{tables} 张表")


# ---------- 链接、目录树、安装脚本覆盖面 ----------
def check_links(files: list[str]) -> None:
    count = 0
    for f in files:
        if not f.endswith(TEXT_SUFFIXES):
            continue
        for m in LINK.finditer(blank_fences(read(f))):
            target = m.group(1)
            path = target.split("#")[0]
            if re.match(r"^(https?:|mailto:)", target) or not path:
                continue
            count += 1
            if not ((ROOT / f).parent / path).exists():
                fail("链接", f"{f} → {target} 指向的文件不存在")
    passed.append(f"相对链接：{count} 条")


def check_tree(files: list[str]) -> None:
    m = re.search(r"^## 目录结构\s*\n+```text\n(.*?)^```", read("README.md"), re.S | re.M)
    if not m:
        fail("目录树", "README.md 里找不到「## 目录结构」下的 ```text 代码块")
        return
    tree = m.group(1)
    for f in files:
        name = os.path.basename(f)
        if f in TREE_EXEMPT:
            continue
        if not re.search(r"(?<![\w.-])" + re.escape(name) + r"(?![\w.-])", tree):
            fail("目录树", f"{f} 没有出现在 README.md 的目录树里")
    passed.append(f"目录树：{len(files)} 个文件")


def check_install_coverage(files: list[str]) -> None:
    if "scripts/install.sh" not in files:
        return
    script = read("scripts/install.sh")
    configs = [f for f in files if fnmatch.fnmatch(f, "stacks/*/configs/*")]
    for f in configs:
        if os.path.basename(f) not in script:
            fail("安装脚本", f"scripts/install.sh 没有处理 {f}：新增或改名的配置要同步进安装脚本")
    passed.append(f"安装脚本覆盖：{len(configs)} 个配置文件")


# ---------- 配置语法与可执行位 ----------
def strip_jsonc(s: str) -> str:
    out, i, in_str = [], 0, False
    while i < len(s):
        c = s[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < len(s):
                out.append(s[i + 1])
                i += 2
                continue
            in_str = c != '"'
        elif c == '"':
            in_str = True
            out.append(c)
        elif s.startswith("//", i):
            j = s.find("\n", i)
            i = len(s) if j == -1 else j
            continue
        elif s.startswith("/*", i):
            j = s.find("*/", i + 2)
            i = len(s) if j == -1 else j + 2
            continue
        else:
            out.append(c)
        i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def run_quiet(cmd: list[str], stdin_path: Path | None = None) -> str | None:
    """跑一个校验命令：成功返回 None，失败返回报错首行。"""
    with open(stdin_path, "rb") if stdin_path else open(os.devnull, "rb") as fh:
        r = subprocess.run(cmd, stdin=fh, capture_output=True, text=True)
    if r.returncode == 0:
        return None
    return ((r.stderr or r.stdout).strip().splitlines() or ["(无输出)"])[0][:200]


def yaml_checker():
    try:
        import yaml  # type: ignore[import-untyped]

        def check(p: Path) -> str | None:
            try:
                yaml.safe_load(p.read_text(encoding="utf-8"))
                return None
            except yaml.YAMLError as e:
                return str(e).splitlines()[0]

        return check
    except ImportError:
        pass
    if shutil.which("ruby"):
        return lambda p: run_quiet(["ruby", "-ryaml", "-e", "YAML.load_file(ARGV[0])", str(p)])
    if shutil.which("yq"):
        return lambda p: run_quiet(["yq", ".", str(p)])
    return None


def shell_of(p: Path) -> str | None:
    try:
        first = p.open("rb").readline(200)
    except OSError:
        return None
    if first.startswith(b"#!"):
        interp = first.split(b"/")[-1]
        if b"bash" in interp:
            return "bash"
        if interp.strip().endswith(b"sh"):
            return "sh"
    return "bash" if p.suffix == ".sh" else None


def check_configs(files: list[str]) -> None:
    try:
        import tomllib
    except ImportError:
        try:
            import tomli as tomllib  # type: ignore[import-not-found,no-redef]
        except ImportError:
            tomllib = None  # type: ignore[assignment]
    check_yaml = yaml_checker()
    node = shutil.which("node")
    skipped: set[str] = set()
    count = 0
    for f in files:
        p = ROOT / f
        name = p.name
        err = None
        if name.endswith((".json", ".json.example")):
            text = p.read_text(encoding="utf-8")
            if name.startswith("tsconfig"):
                text = strip_jsonc(text)
            try:
                json.loads(text)
            except ValueError as e:
                err = f"不是合法 JSON：{e}"
        elif name.endswith((".yml", ".yaml")):
            if check_yaml is None:
                skipped.add("YAML（没有 PyYAML、ruby、yq）")
                continue
            err = check_yaml(p)
        elif name.endswith(".toml"):
            if tomllib is None:
                skipped.add("TOML（需要 Python 3.11+ 或 tomli）")
                continue
            try:
                tomllib.loads(p.read_text(encoding="utf-8"))
            except tomllib.TOMLDecodeError as e:
                err = f"不是合法 TOML：{e}"
        elif name.endswith((".js", ".cjs", ".mjs")):
            if node is None:
                skipped.add("JS（没有 node）")
                continue
            esm = name.endswith(".js") and re.search(r"^(import|export)\s", p.read_text(encoding="utf-8"), re.M)
            err = run_quiet([node, "--input-type=module", "--check"], p) if esm else run_quiet([node, "--check", str(p)])
        elif name.endswith(".py"):
            try:
                compile(p.read_text(encoding="utf-8"), f, "exec")
            except SyntaxError as e:
                err = f"Python 语法错误：{e}"
        else:
            sh = shell_of(p)
            if sh is None:
                continue
            if shutil.which(sh) is None:
                skipped.add(f"shell（没有 {sh}）")
                continue
            err = run_quiet([sh, "-n", str(p)])
            if not err and f.startswith(EXEC_DIRS) and os.name != "nt" and not os.access(p, os.X_OK):
                err = "缺可执行位（chmod +x）"
        count += 1
        if err:
            fail("配置", f"{f} {err}")
    for f in files:
        if f.endswith(TEXT_SUFFIXES):
            for i, block in enumerate(re.findall(r"^```json\n(.*?)^```", read(f), re.S | re.M), 1):
                count += 1
                try:
                    json.loads(block)
                except ValueError as e:
                    fail("配置", f"{f} 第 {i} 个 ```json 代码块不是合法 JSON：{e}")
    for s in sorted(skipped):
        warnings.append(f"跳过了 {s}的语法检查")
    passed.append(f"配置语法：{count} 项")


def main() -> int:
    hook = "--hook" in sys.argv[1:]
    if hook:
        raw = "" if sys.stdin.isatty() else sys.stdin.read()
        try:
            if json.loads(raw or "{}").get("stop_hook_active"):
                return 0  # 本次续跑就是被本钩子打回造成的：放行，防死循环
        except (ValueError, AttributeError):
            pass
    files = list_files()
    for check in (check_budgets, check_stack_sections, check_quote_opening, check_tables,
                  check_links, check_tree, check_install_coverage, check_configs):
        try:
            check(files)
        except Exception as e:  # 单项检查崩了也要报出来，不能让它悄悄算通过
            fail("自检脚本", f"{check.__name__} 执行出错：{e!r}")
    out = sys.stderr if hook else sys.stdout
    if not hook:
        for line in passed:
            print(f"  ✓ {line}")
        for w in warnings:
            print(f"  ! {w}")
    if problems:
        print(f"本库自检未通过：{len(problems)} 项", file=out)
        for p in problems[:40]:
            print(f"  ✗ {p}", file=out)
        if len(problems) > 40:
            print(f"  …… 另有 {len(problems) - 40} 项，跑 python3 scripts/check.py 看全部", file=out)
        if hook:
            print("修完再收工：规则见 CLAUDE.md 的「行数预算」与「结构约束」两节。", file=out)
        return 2 if hook else 1
    if not hook:
        print(f"本库自检通过：{len(files)} 个文件")
    return 0


if __name__ == "__main__":
    sys.exit(main())
