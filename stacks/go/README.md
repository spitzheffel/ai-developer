> 给在 Go 项目上干活的 Claude Code 与未来的自己:开工前按需加载,选型、目录、lint 的争议以本文为准。
> 七节结构沿用 [stacks/_template.md](../_template.md);新踩的坑先记 [docs/pain-log.md](../../docs/pain-log.md)。

# Go 栈

## 1. 选型清单

默认即决定:偏离任何一行,须在 plan 里写明理由并过一遍 [build-vs-buy](../../process/build-vs-buy.md)。

| 需求域 | 钉死 | 禁用 | 一句话理由 |
|---|---|---|---|
| Go 版本 | 最新稳定版(`go.mod` 的 `go` 指令跟最新) | 为"兼容"锁旧版 | 部署环境强制是锁旧版的唯一正当理由 |
| HTTP 路由 | `net/http` 标准库 ServeMux(1.22+ 方法路由:`"GET /users/{id}"` + `r.PathValue("id")`) | gin/echo 进新项目 | 标准库够用;中间件 ≥3 个或需要路由分组时才上 chi |
| 数据库 | `database/sql` + sqlc:手写 SQL,生成类型安全代码 | 新项目用 GORM | 显式 SQL 可审,AI 补全的 ORM 魔法(自动迁移/预加载/钩子)易错且难查 |
| 日志 | `log/slog` 标准库,服务用 `JSONHandler`;键值对写法 `slog.Info("msg", "k", v)` | 第三方日志库(zap/logrus/zerolog) | slog 已覆盖结构化日志,引库纯增依赖 |
| 配置 | 环境变量 + 标准库 `flag`,启动时一次读进 config struct | 小项目引 viper | 配置源真超出 env+flag 两种再议 |
| 错误处理 | `fmt.Errorf("动作 对象: %w", err)` 包装;判断用 `errors.Is/As` | panic 做常规错误处理 | panic 只留给启动期致命错误(见第 6 节第 8 条) |
| 错误响应 | 4xx/5xx 一律 RFC 9457 `application/problem+json`;对外 API 用 Huma(内建,经 humago 挂在 ServeMux 上) | 自定义错误 JSON 形状 | 错误形状从此唯一（〔试用〕来源：调研 2026-11，[docs/research/adoption-plan.md](../../docs/research/adoption-plan.md)） |
| 分页幂等 | 列表端点 cursor 分页、不返 total;有副作用的创建端点要求 `Idempotency-Key` | offset 分页 | offset 遇并发写会漏行重行;无对外 API 的项目跳过本行（〔试用〕来源：调研 2026-11，[docs/research/adoption-plan.md](../../docs/research/adoption-plan.md)） |
| 测试 | 标准 `testing`,表驱动为默认范式;结构体深比较用 go-cmp | testify | 断言 DSL 换不来信息量,还助长非表驱动的流水账测试 |
| 集成测试 | testcontainers-go 起真库/缓存,核心用户路径必有穿真库的测试 | go-sqlmock 等 mock DB | mock 只留给外部付费/不可控服务（〔试用〕来源：调研 2026-11，[docs/research/adoption-plan.md](../../docs/research/adoption-plan.md)） |
| Lint | golangci-lint(配置见 [configs/.golangci.yml](configs/.golangci.yml)) | — | — |
| 依赖边界 | `internal/`(编译器强制)+ depguard 按 import 前缀禁跨域(规则见 [configs/.golangci.yml](configs/.golangci.yml)) | — | 越界即 CI 红灯,AI 看到红自己修（〔试用〕来源：调研 2026-11，[docs/research/adoption-plan.md](../../docs/research/adoption-plan.md)） |
| 依赖审计 | govulncheck 当 PR 门禁兼每周定时 + 每周 osv-scanner 全量(见 [configs/security-ci.yml](configs/security-ci.yml));CI 的 Go 取 go.mod 的 toolchain 行 | 指望 golangci-lint/gosec 查依赖漏洞 | 只报代码真调用到的漏洞,噪声低;golangci-lint 不含它,osv-scanner 默认不扫标准库（〔试用〕来源：调研 2026-11，[docs/research/adoption-plan.md](../../docs/research/adoption-plan.md) OP1） |
| Format | gofmt/goimports;配置里以 gofumpt(gofmt 严格超集)+ goimports 落地 | 手调风格 | 风格争论全由 formatter 终结 |

## 2. 工具链与命令

| 场景 | 命令 |
|---|---|
| 构建全部 | `go build ./...` |
| 测试 | `go test ./...`;改并发代码必加 `-race`;单测 `go test -run 'TestFind' ./internal/user/` |
| 内置静态检查 | `go vet ./...`(lint 已含 govet,单独跑图个快) |
| Lint | `golangci-lint run`;自动修复 `golangci-lint run --fix` |
| 格式化 | `golangci-lint fmt`(驱动 gofumpt+goimports;`run` 对格式只报不改) |
| 依赖整理 | `go mod tidy`——增删 import 后必跑,否则 go.mod/go.sum 脏 |
| 依赖审计 | `govulncheck ./...`(先 `go install golang.org/x/vuln/cmd/govulncheck@v1.9.0`,要求 Go ≥ 1.26;exit 3 = 代码调用到了有漏洞的符号) |

改完代码的验证顺序:`go build ./...` → `go test ./...` → `golangci-lint run`,全绿才算过[完成定义](../../process/definition-of-done.md)。

## 3. 目录规范

从扁平开始,按痛点分化,不按架构图预分层:

```
cmd/<app>/main.go   # 入口:flag/env 解析、依赖组装、启动;不放业务逻辑
internal/<domain>/  # 按业务域分包:internal/order/、internal/user/;包内先扁平
go.mod              # go mod init <module> 生成
```

- ❌ 起手就建 controller/service/repository 三层样板(java 式,一个领域三个包互相透传) ✅ 一个 `internal/order/` 放下 handler+逻辑+存储,单文件超 ~500 行再按职责拆文件、再拆包
- `internal/` 是默认:编译器保证仓库外导不进,日后重构无包袱;`pkg/` 仅当代码真要被本仓库之外导入才建,"将来可能复用"不算理由。
- 包名=目录名:单数、小写、无下划线;禁 `util`/`common`/`helpers` 杂物包——放不进任何域的代码,先质疑它该不该存在。

## 4. build-vs-buy 默认值

标准库优先是本栈宪法:三个栈里自研阈值最高,引库阈值同样最高。通用判断流程见 [process/build-vs-buy.md](../../process/build-vs-buy.md),本栈默认值:

- HTTP 服务、JSON、模板、CLI flag、日志、并发原语:标准库全覆盖,这些领域引库默认驳回。
- 标准库 ≤50 行能写清的工具函数,直接写,不引库。
- 引任何第三方库,plan 里必须有一句"标准库为何不够";写不出来就是不需要。
- 绝不自研清单照常生效(见 [process/build-vs-buy.md](../../process/build-vs-buy.md)):加密、JWT、时区/历法——用 `golang.org/x/*` 或久经考验的库,不手搓。
- 本栈预先豁免:sqlc、go-cmp、chi(触发条件见第 1 节)、`golang.org/x/*`;testcontainers-go 与 Huma(对外 API)随第 1 节〔试用〕行去留。

## 5. 参照模式

新 handler、新测试照抄此骨架改名,不自由发挥(范例驱动,见 [docs/workflow.md](../../docs/workflow.md) 阶段3)。import 省略,交给 goimports 补。请求日志只走 `reqlog`:每请求收尾恰好一条 canonical log line,handler 用 `reqlog.Add` 挂字段、不另打 log（〔试用〕来源：调研 2026-11，[docs/research/adoption-plan.md](../../docs/research/adoption-plan.md)）。

```go
// cmd/api/main.go —— 入口只做组装
func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	mux := http.NewServeMux()
	mux.HandleFunc("GET /users/{id}", user.HandleGet) // 1.22+ 方法路由;user = internal/user
	slog.Error("server exited", "err", http.ListenAndServe(":8080", reqlog.Wrap(mux)))
	os.Exit(1)
}

// internal/reqlog/reqlog.go —— canonical log line:每请求收尾恰好一条宽事件
type key struct{}

type line struct {
	http.ResponseWriter
	status int // 包住 ResponseWriter 记下状态码
	kv     []any
}

func (l *line) WriteHeader(code int) { l.status = code; l.ResponseWriter.WriteHeader(code) }

func Add(ctx context.Context, kv ...any) { // handler 往本请求那条 log line 挂字段,如 reqlog.Add(ctx, "err", err)
	if l, ok := ctx.Value(key{}).(*line); ok { // 没经 Wrap(如单测直调 handler)就不记
		l.kv = append(l.kv, kv...)
	}
}

func Wrap(next http.Handler) http.Handler { // 包住整个 mux:404/405 也各留一条
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start, l := time.Now(), &line{ResponseWriter: w, status: http.StatusOK, kv: []any{"request_id", rand.Text()}}
		r = r.WithContext(context.WithValue(r.Context(), key{}, l))
		next.ServeHTTP(l, r) // 返回后 r.Pattern 已由 mux 回填(1.23+)
		slog.InfoContext(r.Context(), "request", append(l.kv, "route", r.Pattern, "status", l.status,
			"duration_ms", time.Since(start).Milliseconds())...)
	})
}
```

```go
// internal/user/user.go —— 哨兵错误 + %w 包装 + handler
var ErrNotFound = errors.New("user not found")

type User struct{ ID string }

func HandleGet(w http.ResponseWriter, r *http.Request) {
	u, err := Find(r.Context(), r.PathValue("id"))
	switch {
	case errors.Is(err, ErrNotFound):
		http.Error(w, "not found", http.StatusNotFound) // 对外 API 换 Huma:错误体自动成 problem+json(第 1 节)
	case err != nil:
		reqlog.Add(r.Context(), "error_code", "internal", "err", err) // 不另打 log:挂进本请求那条 canonical log line
		http.Error(w, "internal error", http.StatusInternalServerError)
	default:
		if err := json.NewEncoder(w).Encode(u); err != nil {
			reqlog.Add(r.Context(), "err", fmt.Errorf("encode user: %w", err))
		}
	}
}

func Find(ctx context.Context, id string) (*User, error) {
	u, err := queryUser(ctx, id) // 占位:实际为 sqlc 生成的查询
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound // 存储层错误翻译成领域哨兵,不让 sql.ErrNoRows 漏到 handler
	}
	if err != nil {
		return nil, fmt.Errorf("find user %q: %w", id, err)
	}
	return u, nil
}
```

```go
// internal/user/user_test.go —— 表驱动是默认范式;深比较用 go-cmp
func TestFind(t *testing.T) {
	tests := []struct {
		name    string
		id      string
		want    *User
		wantErr error
	}{
		{name: "ok", id: "u1", want: &User{ID: "u1"}},
		{name: "missing", id: "nope", wantErr: ErrNotFound},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := Find(context.Background(), tt.id)
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("err = %v, want %v", err, tt.wantErr)
			}
			if diff := cmp.Diff(tt.want, got); diff != "" {
				t.Errorf("User mismatch (-want +got):\n%s", diff)
			}
		})
	}
}
```

## 6. 高频 AI 坑

新坑先记 [docs/pain-log.md](../../docs/pain-log.md),同一个坑第二次出现再提炼进本节。

1. **goroutine 泄漏**——起协程不接 context,调用方早退了它还挂着。 ❌ `go worker()` ✅ `go worker(ctx)`,循环里 `select { case <-ctx.Done(): return }`
2. **吞错误**——errcheck 会抓,但常被先写出来再返工。 ❌ `n, _ := strconv.Atoi(s)` ✅ `n, err := strconv.Atoi(s)`,err 非 nil 就带上下文 `%w` 包装返回
3. **过早 interface**——单一实现也配接口,java 味 Go。 ❌ 定义 `UserServiceInterface` + 唯一实现 ✅ 先写具体类型;要测试替身时,在**使用方**定义最小接口
4. **包名 stutter**——包名已经是命名空间,类型名别再重复它。 ❌ `user.UserService` ✅ `user.Service`
5. **init() 滥用**——隐式执行顺序、藏副作用、没法注入依赖。 ❌ `func init() { db = mustConnect() }` ✅ 在 `main` 里显式构造,依赖作参数传入
6. **循环体内 defer**——defer 到函数返回才执行,句柄在循环里堆到耗尽。 ❌ `for _, p := range paths { f, _ := os.Open(p); defer f.Close() }` ✅ 循环体抽成函数,或循环内显式 `Close`
7. **map/slice 并发写**——map 并发读写直接 panic,slice 则静默丢数据。 ❌ 多个 goroutine 裸写同一 map ✅ `sync.Mutex` 包住,或 channel 汇聚到单一写者;`go test -race` 兜底
8. **panic 当错误处理**——panic 只留给启动期致命错误和"程序写错了"类 bug。 ❌ `if err != nil { panic(err) }` ✅ `return fmt.Errorf("load config: %w", err)`
9. **迁移纪律**——只许新增 migration,不改不删已有的、不写 down(错了再加一条向前修);reset/drop/删数据须人类显式确认;人审 + 本地非空库跑过才 apply,AI 不持生产凭证。 ❌ 改已合入的 `0007_add_email.sql` ✅ 起草 `0008_fix_email.sql` 向前修正,贴进回复交人审、由人落盘(拦截编辑 migrations/ 的钩子见 [claude-code/hooks.md](../../claude-code/hooks.md);hook 是护栏不是安全边界，真边界是凭证隔离)（〔试用〕来源：调研 2026-11，[docs/research/adoption-plan.md](../../docs/research/adoption-plan.md)）
10. **over-mock**——为让 CI 变绿把 DB/内部包 mock 掉,测试只证明 mock 被调用了。 ❌ go-sqlmock 预设 SQL 再断言调用 ✅ testcontainers-go 起真库测核心路径,mock 只留给外部付费/不可控服务（〔试用〕来源：调研 2026-11，[docs/research/adoption-plan.md](../../docs/research/adoption-plan.md)）

## 7. 配置文件索引

| 文件 | 内容 | 用法 |
|---|---|---|
| [configs/.golangci.yml](configs/.golangci.yml) | golangci-lint v2:standard 组(errcheck/govet/ineffassign/staticcheck/unused)+ gocritic/revive/misspell + depguard(依赖边界示例规则);formatters 用 gofumpt+goimports | 复制到项目根 → `golangci-lint run` / `run --fix`;depguard 规则按自己的业务域改名 |
| [configs/contracts-ci.yml](configs/contracts-ci.yml) | GitHub Actions 契约门禁:tbls diff 卡 `dbdoc/` 漂移;再生成的 `api/openapi.json` 未提交即 fail + oasdiff `fail-on: ERR` + Spectral lint;proto 项目换 buf breaking | 下一个真实 API 项目开工时复制到 `.github/workflows/`,按文件头注释删掉用不到的 job |
| [configs/security-ci.yml](configs/security-ci.yml) | 安全门禁:gitleaks 每次扫全部历史;govulncheck 卡 PR 兼每周定时(osv-scanner 默认不扫标准库);每周 osv-scanner 全量 | 直接启用:复制为 `.github/workflows/security.yml`;本地两个钩子见 [claude-code/hooks.md](../../claude-code/hooks.md) |

`go.mod`/`go.sum` 由 `go mod init` 与 `go mod tidy` 生成维护,不提供模板。保存后自动格式化、停止前跑验证的钩子接法见 [claude-code/hooks.md](../../claude-code/hooks.md)。
