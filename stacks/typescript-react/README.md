> TypeScript/React 栈约定：该栈项目开工时整体加载（由项目的 CLAUDE.md 引用），Claude Code 动手写代码前按第 1、3、6 节核对。结构遵循 [栈模板](../_template.md)。

# TypeScript / React 栈

## 1. 选型清单

同一需求域，代码库里只允许“钉死”项出现；出现“禁用”项即违规，审查直接打回。要改选型先改本表，改完保持唯一。

| 需求域 | 钉死 | 禁用 | 一句话理由 |
| --- | --- | --- | --- |
| 包管理 | pnpm（package.json 写死 `"packageManager": "pnpm@12.16.1"`） | npm、yarn | 单一入口，lockfile 不打架 |
| 构建 | Vite | webpack、CRA | 与 Vitest 共用同一套配置链 |
| 语言 | TypeScript strict（见 [tsconfig](configs/tsconfig.json)） | 新增 .js 业务文件 | 类型是给 AI 的最硬护栏 |
| 组件 | React 函数组件 | class 组件 | React 19 新 API 全按函数组件设计 |
| 服务端状态 | TanStack Query | useEffect 手写取数 | 缓存/重试/竞态手写必错 |
| 客户端状态 | zustand | 新项目引 Redux/MobX | 零样板，store 即函数 |
| 表单 | react-hook-form + zod | 手写受控表单与校验 | 校验统一 zod schema，类型自动推导 |
| 样式 | Tailwind CSS + shadcn/ui | 混入第二套 UI 库（antd、MUI 等） | 两套 UI 库＝两套主题两倍坑 |
| HTTP | 统一走 src/api/client.ts 封装 | 业务代码散装 fetch/axios | 鉴权/错误/超时只处理一次 |
| 接口类型 | OpenAPI 生成：openapi-typescript + openapi-fetch；要 mock 一条龙则改 orval（二选一，开工时在项目 CLAUDE.md 注明；hey-api 为 pre-1.0，不作默认，要用必须锁精确版本）。改 API 先改 spec 再跑生成，产物放 src/api/generated 只读；生成的 client 一律经 src/api/client.ts（openapi-fetch 在此 createClient，orval 的 mutator 指向它） | 手写/手改接口类型；生成 client 另开第二个 HTTP 出口 | 手写类型必与后端漂移，spec 是前后端与多 agent 的唯一事实源（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md） |
| 日期 | date-fns | moment | moment 已停止维护且不可 tree-shake |
| 路由 | React Router（Next.js 项目改用其文件路由：二选一，开工时在项目 CLAUDE.md 注明后钉死） | 同一项目混两种路由 | 路由随框架走，但必须唯一 |
| 测试 | Vitest + React Testing Library，e2e 用 Playwright；视觉回归默认不做全站快照，仅关键页用 Playwright `toHaveScreenshot` 并 mask 动态区（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md） | 新增 jest 配置 | Vitest 直接复用 Vite 配置 |
| API mock | MSW：全局 handlers 只放成功态，错误/边界态在用例里 `server.use()` 覆盖；测试 `server.listen({ onUnhandledFrame: 'error' })`（MSW 3 键名，2.x 为 onUnhandledRequest）；handlers 从 spec 生成（orval 的 mock 产物），faker 固定 seed | 手写散装 mock（vi.mock 掉 client、组件里塞假数据） | 未 mock 的请求当场炸出来；手写 handlers 必漂移，固定 seed 让失败可复现（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md） |
| Lint/Format | ESLint 9 flat + typescript-eslint + Prettier | 与 Biome 规则级混搭 | Biome 是注明的整体替代：二选一，不混用 |
| 依赖边界 | dependency-cruiser（[规则文件](configs/.dependency-cruiser.cjs)）；存量项目先 `--baseline` 记下旧账，CI 跑 `--ignore-known` 只红新增 | 无边界规则裸跑 | 越界 CI 直接红，AI 在循环里看到红自己修；规则文件兼作架构文档与 AI 边界输入（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md） |

## 2. 工具链与命令

| 动作 | 命令 |
| --- | --- |
| 安装 | `pnpm install`（CI 用 `pnpm install --frozen-lockfile`） |
| 开发 | `pnpm dev` |
| 单测 | `pnpm test`（watch：`pnpm vitest`） |
| Lint | `pnpm lint` |
| 类型检查 | `pnpm typecheck` |
| 格式化 | `pnpm format` |
| 依赖边界 | `pnpm lint:deps`（规则见 [configs/.dependency-cruiser.cjs](configs/.dependency-cruiser.cjs)） |
| 再生成接口类型 | `pnpm gen:api`（改了 openapi.json 就跑，产物与 spec 同一提交） |

package.json 建议（命令一律收进 scripts，不在会话里手拼 CLI 参数）：

```json
{
  "packageManager": "pnpm@12.16.1",
  "scripts": {
    "dev": "vite",
    "build": "tsc --noEmit && vite build",
    "test": "vitest run",
    "lint": "eslint .",
    "lint:deps": "depcruise src",
    "gen:api": "openapi-typescript openapi.json -o src/api/generated/schema.d.ts",
    "typecheck": "tsc --noEmit",
    "format": "prettier --write ."
  }
}
```

## 3. 目录规范

按 feature 切分，不按文件类型切分（不设顶层 hooks/、utils/ 大杂烩目录）：

```text
src/
  app/              # 入口、路由表、全局 providers（QueryClientProvider 等）
  components/       # 跨 feature 通用组件：被 ≥2 个 feature 用到才准放进来
  features/<name>/  # 一个业务域一个目录，内部自包含
    components/     #   该域专属组件
    hooks/          #   该域专属 hooks
    api/            #   该域取数 hooks（内部只调 src/api/client.ts）
    types/          #   zod schema 与推导出的类型
  api/client.ts     # 唯一 HTTP 出口：baseURL、鉴权头、错误归一化、超时
  lib/              # 纯工具函数：无 React、无 IO、可直接单测
  stores/           # zustand store，一个领域一个文件
```

新文件落点判定：先问属于哪个 feature；跨 feature 且被 ≥2 处使用，才升级到 src/components 或 src/lib。

## 4. build-vs-buy 默认值

- 本栈生态成熟，**默认用库**；要自研须在 plan 里给出可判定理由，流程见 [build-vs-buy](../../process/build-vs-buy.md)。
- **微依赖禁止**：实现不足约 50 行的包不引入，抄进 src/lib 并注明出处与许可证。
- **UI 组件用 shadcn/ui 的复制进仓库模式**，不装黑盒组件库：代码进仓库，可改、可审、坏了能修。
- 本栈“绝不自研清单”追加项：日期运算、表单校验引擎、请求缓存层、路由。

## 5. 参照模式

新 feature 一律抄这个骨架（以 user 为例）：

```text
src/features/user/
  api/useUser.ts            # 取数 hook（下方示例）
  components/UserCard.tsx   # 展示组件
  types/user.ts             # zod schema + 推导类型
```

取数 hook 的标准形状——统一经 client，响应过 zod：

```ts
// src/features/user/api/useUser.ts
import { useQuery } from '@tanstack/react-query';
import { api } from '../../../api/client'; // 唯一 HTTP 出口
import { userSchema, type User } from '../types/user';

export function useUser(id: string) {
  return useQuery({
    queryKey: ['user', id],
    queryFn: async (): Promise<User> => userSchema.parse(await api.get(`/users/${id}`)),
  });
}
```

列表/详情的状态四件套一律经统一包装器渲染，漏一态即打回（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md）：

```tsx
// src/components/QueryBoundary.tsx：四态 props 全必填，漏传一态 tsc 直接报错
import type { UseQueryResult } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { ErrorState } from './ErrorState'; // 统一错误态：说明文案 + 重试按钮

type Props<T> = { query: UseQueryResult<T>; skeleton: ReactNode; empty: ReactNode; isEmpty: (data: T) => boolean; children: (data: T) => ReactNode };
export function QueryBoundary<T>({ query, skeleton, empty, isEmpty, children }: Props<T>) {
  if (query.isPending) return skeleton; // loading：与内容同形的 skeleton，禁通用 spinner
  if (query.isError) return <ErrorState error={query.error} onRetry={() => void query.refetch()} />; // error：可重试
  if (isEmpty(query.data)) return empty; // empty：设计过的空态，与 error 严格区分
  return children(query.data); // success
}
```

## 6. 高频 AI 坑

- ❌ useEffect + useState 手写取数 → ✅ TanStack Query 的 useQuery（竞态/缓存/重试白送）
- ❌ 用 any / as any / @ts-ignore 压掉报错 → ✅ 修类型；确属上游缺陷用 @ts-expect-error 并附一行原因（no-explicit-any 已是 error）
- ❌ 组件里直接 fetch('/api/…') → ✅ 统一经 src/api/client.ts 导出的 api（鉴权与错误归一化只做一次）
- ❌ 在组件函数体内定义子组件 → ✅ 提升到模块顶层（体内定义＝每次渲染重建、子树 state 丢失）
- ❌ 见 state 就包 useMemo/useCallback、给组件套 React.memo → ✅ 新代码默认不加，profiler 实测出性能问题再加（依据：React Compiler 1.0 已于 2025-10 转正，记忆化可交给编译器自动做）；存量手写 memo 保留勿删，要删先测（官方态度保守：删除可能改变编译产物）（〔试用〕来源：调研 2026-11，docs/research/adoption-plan.md）
- ❌ React 19 仍写 forwardRef 透传 ref → ✅ 函数组件把 ref 当普通 prop 接（forwardRef 官方已宣布后续弃用并提供 codemod）
- ❌ 每个目录放 index.ts 桶文件 re-export → ✅ 直接从源文件 import（桶文件诱发循环依赖、拖慢构建与测试）

## 7. 配置文件索引

| 文件 | 说明 |
| --- | --- |
| [configs/eslint.config.js](configs/eslint.config.js) | ESLint 9 flat：typescript-eslint type-checked + react-hooks，另钉死 no-explicit-any、no-floating-promises、eqeqeq |
| [configs/tsconfig.json](configs/tsconfig.json) | strict 基线 + noUncheckedIndexedAccess + verbatimModuleSyntax，moduleResolution bundler（JSONC，含注释） |
| [configs/.prettierrc.json](configs/.prettierrc.json) | 格式四项钉死：printWidth 100 / singleQuote / semi / trailingComma all——格式不再进评审讨论 |
| [configs/.prettierignore](configs/.prettierignore) | 排除 `src/api/generated`：生成物保持原样，contracts-ci 的逐字比对才不误报（ESLint 侧同在 globalIgnores 排除） |
| [configs/.dependency-cruiser.cjs](configs/.dependency-cruiser.cjs) | 依赖边界五条：无循环 / 孤儿告警 / feature 间禁互依 / 共享层不依赖 feature / 单一 HTTP 出口；注释含 `--baseline` + `--ignore-known` 基线法与 mermaid/archi 出图命令 |
| [configs/contracts-ci.yml](configs/contracts-ci.yml) | 契约 CI 模板（有对外 API 的项目才启用）：重新生成接口类型后 git diff 防漂移 + oasdiff 对比 main 上的 spec，ERR 级破坏性变更即红 |
