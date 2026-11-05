// dependency-cruiser 起步配置（TS/React 栈）：复制到项目根目录，文件名保持 .dependency-cruiser.cjs
// （Vite 项目的 package.json 是 "type": "module"，CommonJS 配置必须用 .cjs；depcruise --init 遇此情形也生成同名文件）。
// 规则文件三重身份：给人看的架构文档 + 给 AI 读的边界输入（项目 CLAUDE.md 引用本文件）+ CI 硬门禁。
// 规则保持个位数：太多会锁死架构；只看静态 import，动态 import()、依赖注入看不见。
// 按 dependency-cruiser 18.x 写（18.3 起 --baseline 取代 depcruise-baseline）。
//
// 用法（命令收进 package.json scripts，如 "lint:deps"）：
//   新项目：  npx depcruise src                 error 级违规退出码非 0 → CI 红；warn 只提示。大仓加 --cache
//   存量项目基线法（先红新增、再渐进清偿）：
//     1. npx depcruise src --baseline            生成 .dependency-cruiser-known-violations.json，提交进仓库
//     2. CI 改跑 npx depcruise src --ignore-known  基线里的旧账不报，新增违规照红（基线文件不存在会直接报错）
//     3. 清掉一批旧账后 npx depcruise src --baseline --baseline-mode shrink-only   只删已修复项，不吞新违规
//   出图（同一份配置）：
//     npx depcruise src --include-only '^src' --collapse '^src/features/[^/]+|^src/[^/]+' -T mermaid -f deps.mmd
//         → 内容贴进 PR 描述的 ```mermaid 代码块即渲染（feature 级折叠，一个 feature 一个节点）
//     npx depcruise src --include-only '^src' -T archi | dot -T svg > archi.svg
//         → 目录级总览，需本机装 graphviz；折叠粒度见下方 reporterOptions.archi。
//           两条都带 --include-only '^src'：只画自家代码；第三方包在 pnpm 下是一串 .pnpm 长路径节点，对边界图没信息量

/** @type {import('dependency-cruiser').IConfiguration} */
module.exports = {
  forbidden: [
    {
      name: 'no-circular',
      severity: 'error',
      comment: '循环依赖：用依赖倒置拆环，或把共享类型挪进 types/。生成物不归手修，排除在外。',
      from: { pathNot: '^src/api/generated/' },
      to: { circular: true },
    },
    {
      name: 'no-orphans',
      severity: 'warn', // 孤儿模块多半是改完没删的死代码；想当门禁就改 error
      comment: '孤儿模块（无人引用也不引用别人）：接上或删掉；确属入口/配置就加进 pathNot。',
      from: {
        orphan: true,
        pathNot: [
          '(^|/)[.][^/]+[.](?:js|cjs|mjs|ts|cts|mts|json)$', // dot 文件（含本文件）
          '[.]d[.]ts$', // 类型声明
          '(^|/)tsconfig[.]json$',
          '(^|/)[^/]+[.]config[.](?:js|cjs|mjs|ts|cts|mts)$', // vite/vitest/playwright/eslint/orval 等配置
          '^src/api/generated/', // 生成物里没被用到的接口是正常的
        ],
      },
      to: {},
    },
    {
      // 业务边界示例：feature 之间禁止互相 import（对应栈 README 第 3 节「按 feature 切分」）。
      // 按业务改：
      //   - 业务目录不叫 features：把两处 src/features 换成你的目录名（如 src/domains）。
      //   - 某 feature 确需对全站开放（如 auth 的会话 hook）：to.pathNot 改成数组并加白名单，
      //     如 ['^src/features/$1/', '^src/features/auth/hooks/']——白名单每加一项都是一次边界决策，写进 ADR。
      //   - 被 ≥2 个 feature 用到的东西不开白名单，升级到 src/components 或 src/lib。
      // $1 = from.path 括号里匹配到的 feature 名，to.pathNot 用它放行「同一 feature 内部」的引用。
      name: 'no-cross-feature',
      severity: 'error',
      comment: 'feature 间禁止互相依赖：共享部分升级到 src/components 或 src/lib。',
      from: { path: '^src/features/([^/]+)/' },
      to: { path: '^src/features/', pathNot: '^src/features/$1/' },
    },
    {
      name: 'shared-not-to-features',
      severity: 'error',
      comment: '依赖方向只许 feature → 共享层：src/components、src/lib 反向依赖 feature 即越界。',
      from: { path: '^src/(components|lib)/' },
      to: { path: '^src/features/' },
    },
    {
      // 机械执行栈 README 选型清单的 HTTP 行与接口类型行：唯一 HTTP 出口是 src/api/client.ts。
      // 项目用了别的 HTTP 库就加进正则；全局 fetch() 不经 import，本规则看不见，靠审查兜底。
      name: 'single-http-exit',
      severity: 'error',
      comment: 'HTTP 库只许 src/api/client.ts 引用：业务代码与生成物一律经它发请求，不开第二个出口。',
      from: { pathNot: '^src/api/client[.]ts$' },
      to: {
        path: '(^|/)node_modules/(axios|openapi-fetch)/',
        dependencyTypesNot: ['type-only'], // 只引类型（import type）不发请求，放行
      },
    },
  ],
  options: {
    doNotFollow: { path: ['node_modules'] },
    // import type 也算依赖：verbatimModuleSyntax 下类型导入编译后消失，不开这项，类型层越界就看不见
    tsPreCompilationDeps: true,
    // 路径别名靠它解析；create-vite 三件套项目改成 'tsconfig.app.json'
    tsConfig: { fileName: 'tsconfig.json' },
    enhancedResolveOptions: {
      exportsFields: ['exports'],
      conditionNames: ['import', 'require', 'node', 'default', 'types'],
      mainFields: ['module', 'main', 'types', 'typings'],
    },
    skipAnalysisNotInRules: true,
    reporterOptions: {
      archi: {
        // 一个 feature 一个节点，其余 src 顶层目录各一个节点（默认折叠会把全部 feature 压成一个 src/features）
        collapsePattern: '^src/features/[^/]+|^src/[^/]+',
      },
    },
  },
};
