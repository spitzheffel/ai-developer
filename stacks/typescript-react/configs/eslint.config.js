// @ts-check
// ESLint flat config：TypeScript + React 基线（ESLint 9 flat + typescript-eslint v8）。
// 用 type-checked 预设：规则能拿到 tsc 级类型信息（no-floating-promises 依赖它），代价是 lint 变慢；
// 嫌慢的小项目可换成 tseslint.configs.recommended，并删除 parserOptions 与 no-floating-promises。
// 注意：tseslint.config(...) 在 v8 已被官方弃用，统一用 eslint/config 的 defineConfig；
// tseslint 8.x 的 peer 要求 typescript <6.1.0，lint 工程暂用 TS 6.x。
import js from '@eslint/js';
import { defineConfig, globalIgnores } from 'eslint/config';
import tseslint from 'typescript-eslint';
import reactHooks from 'eslint-plugin-react-hooks';

export default defineConfig(
  // src/api/generated 是 OpenAPI 生成物（只读）：lint 它只会诱导手改产物，contracts-ci 的逐字比对随之误报
  globalIgnores(['dist', 'coverage', 'src/api/generated']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      js.configs.recommended,
      tseslint.configs.recommendedTypeChecked, // 要更严可换 strictTypeChecked
      tseslint.configs.stylisticTypeChecked,
      reactHooks.configs.flat.recommended, // rules-of-hooks=error、exhaustive-deps=warn，v7 含 React Compiler 规则
    ],
    languageOptions: {
      parserOptions: {
        projectService: true, // v8 取代 project: true；type-checked 预设必需
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // any 是类型逃逸的第一入口；预设虽已含，显式钉死防预设升级时悄悄放宽
      '@typescript-eslint/no-explicit-any': 'error',
      // 忘 await 的 Promise 静默吞错，是取数/写库类 bug 的常客；依赖 type-checked 预设
      '@typescript-eslint/no-floating-promises': 'error',
      // == 的隐式转换规则没人背得全；全库统一 ===
      eqeqeq: ['error', 'always'],
    },
  },
);
