# Middleware & Interceptors

Wrap handlers to perform cross-cutting work (logging, recovery, auth, tracing) without touching business logic. HTTP uses `func(http.Handler) http.Handler`; gRPC uses interceptors. Both follow the same onion model.

## Standard HTTP Signature
Use `func(http.Handler) http.Handler` for compatibility with any router (`chi`, `gorilla/mux`, stdlib `http.ServeMux`).
- **Reason:** Standard signatures prevent vendor lock-in and compose cleanly.

## Recipe: Structured Logging + Status Capture
Log with `slog` (never `log.Printf`), and capture the status code and duration by wrapping `http.ResponseWriter`.
- **Reason:** Structured logs are machine-parseable; you cannot read the status code after the fact without capturing it.

```go
// statusRecorder captures the status code written by the handler.
type statusRecorder struct {
    http.ResponseWriter
    status int
}

func (r *statusRecorder) WriteHeader(code int) {
    r.status = code
    r.ResponseWriter.WriteHeader(code)
}

func LogMiddleware(log *slog.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()
            rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}

            next.ServeHTTP(rec, r)

            logger.FromContext(r.Context()).Info("request",
                slog.String("method", r.Method),
                slog.String("path", r.URL.Path),
                slog.Int("status", rec.status),
                slog.Duration("took", time.Since(start)),
            )
        })
    }
}
```

## Recipe: Panic Recovery
A panic in one handler must not crash the whole server. Recover, log, and return `500`.
- **Reason:** One bad request should degrade to a single failed response, not a process restart.

```go
func Recoverer(log *slog.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            defer func() {
                if rec := recover(); rec != nil {
                    log.Error("panic recovered",
                        slog.Any("panic", rec),
                        slog.String("stack", string(debug.Stack())),
                    )
                    http.Error(w, "internal error", http.StatusInternalServerError)
                }
            }()
            next.ServeHTTP(w, r)
        })
    }
}
```

## Recipe: Auth & Context Propagation
Validate the token at the edge, put the typed identity into the context with an **unexported key type**, and let handlers read it. Never pass raw values via string keys.

```go
type ctxKey struct{}

func SetSessionToCtx(auth Authenticator) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            session, err := auth.Auth(r.Context(), r.Header.Get("Authorization"))
            if err != nil {
                http.Error(w, "unauthorized", http.StatusUnauthorized)
                return
            }
            ctx := context.WithValue(r.Context(), ctxKey{}, session)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}

// SessionFromContext is the only way to read the session below the transport edge.
func SessionFromContext(ctx context.Context) (*Session, bool) {
    s, ok := ctx.Value(ctxKey{}).(*Session)
    return s, ok
}
```

The `struct{}{}` key type makes collisions impossible across packages. See `security/auth.md` for identity rules and `style/context.md` for context-value discipline.

## Chaining
Use the router's `Use`, or a tiny dependency-free chainer. Order matters: recovery outermost, then logging, then auth.

```go
// chi
r := chi.NewRouter()
r.Use(Recoverer(log))      // outermost: catches panics from everything inside
r.Use(LogMiddleware(log))
r.Use(SetSessionToCtx(auth))

// dependency-free equivalent
func Chain(h http.Handler, mw ...func(http.Handler) http.Handler) http.Handler {
    for i := len(mw) - 1; i >= 0; i-- { // apply in reverse so mw[0] runs first
        h = mw[i](h)
    }
    return h
}
```

## gRPC Analog: Interceptors
The same onion model for gRPC is a `grpc.UnaryServerInterceptor`. Register recovery, logging, tracing, and error conversion once on the server.

```go
func LogInterceptor(log *slog.Logger) grpc.UnaryServerInterceptor {
    return func(ctx context.Context, req any, info *grpc.UnaryServerInfo,
        handler grpc.UnaryHandler) (any, error) {

        start := time.Now()
        resp, err := handler(ctx, req)
        log.InfoContext(ctx, "rpc",
            slog.String("method", info.FullMethod),
            slog.Duration("took", time.Since(start)),
            slog.String("code", status.Code(err).String()),
        )
        return resp, err
    }
}

// Compose on the server (interceptors run in the order given):
grpc.NewServer(
    grpc.ChainUnaryInterceptor(
        recoveryInterceptor(log),
        LogInterceptor(log),
        tracingInterceptor(),
        convertErrInterceptor(), // domain error -> gRPC code; see style/errors.md
    ),
)
```

For the error-conversion interceptor and code mapping, see `style/errors.md` and `recipes/grpc-api.md`.
