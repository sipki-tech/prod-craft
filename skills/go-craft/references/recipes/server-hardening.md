# Hardening Network Servers

Don't run a server on defaults. Go's zero-value `http.Server` and a bare gRPC server accept connections with **no timeouts and few limits** — an open invitation to slowloris, resource exhaustion, and runaway memory.

## HTTP: Always Set Timeouts
The zero-value `http.Server` never times out a slow or idle client. A handful of slow connections can pin goroutines and file descriptors until the process falls over (the "slowloris" attack).
```go
srv := &http.Server{
    Addr:              ":8080",
    Handler:           mux,
    ReadHeaderTimeout: 5 * time.Second,  // time allowed to read request headers
    ReadTimeout:       15 * time.Second, // entire request including body
    WriteTimeout:      15 * time.Second, // start-of-read to end-of-write
    IdleTimeout:       60 * time.Second, // keep-alive idle connections
    MaxHeaderBytes:    1 << 20,          // 1 MiB header cap
}
```
- **`ReadHeaderTimeout`** is the single most important one — without it a client can hold a connection open by dribbling headers forever. Set it even if you set nothing else.
- **`ReadTimeout`/`WriteTimeout`** bound the whole request/response. If you stream large uploads/downloads or use long-poll/SSE, relax them *per handler* (below) rather than globally.
- **`IdleTimeout`** reclaims idle keep-alive connections.
- **`MaxHeaderBytes`** caps header size against header-bomb abuse.

## Per-Handler Deadlines for Slow Routes
A global `WriteTimeout` is wrong for a streaming or long-running endpoint. Keep global timeouts tight and relax specific routes with `http.TimeoutHandler` or a per-connection deadline:
```go
// bound one handler's total time; respond 503 on overrun
slow := http.TimeoutHandler(slowHandler, 30*time.Second, "request timed out")
```
For streaming endpoints (SSE, large downloads), extend the deadline on that connection with `ResponseController` (Go 1.20+) instead of loosening the whole server:
```go
rc := http.NewResponseController(w)
_ = rc.SetWriteDeadline(time.Now().Add(5 * time.Minute))
```

## Cap Request Bodies
A handler that reads an unbounded body can be OOM'd by a single request. Wrap the body:
```go
r.Body = http.MaxBytesReader(w, r.Body, 10<<20) // 10 MiB
```
Apply it in middleware for all write endpoints ([`middleware.md`](./middleware.md)); for uploads, also enforce a size cap in the storage adapter ([`file-storage.md`](./file-storage.md)).

## gRPC: Set Limits and Keepalive
A default gRPC server accepts large messages, unlimited concurrent streams, and won't shed dead connections.
```go
srv := grpc.NewServer(
    grpc.MaxRecvMsgSize(4<<20), // inbound cap (default 4 MiB)
    grpc.MaxSendMsgSize(4<<20), // outbound cap (default effectively unbounded)
    grpc.MaxConcurrentStreams(250),
    grpc.ConnectionTimeout(10*time.Second), // handshake timeout
    grpc.KeepaliveParams(keepalive.ServerParameters{
        MaxConnectionIdle: 5 * time.Minute,
        Time:              2 * time.Hour,
        Timeout:           20 * time.Second,
    }),
    grpc.KeepaliveEnforcementPolicy(keepalive.EnforcementPolicy{
        MinTime:             30 * time.Second, // reject clients that ping too aggressively
        PermitWithoutStream: false,
    }),
)
```
- **`MaxRecvMsgSize`/`MaxSendMsgSize`** — bound message size; an unbounded message allocates unbounded memory.
- **`MaxConcurrentStreams`** — cap multiplexed streams per connection.
- **`KeepaliveEnforcementPolicy`** — defend against keepalive-ping floods (a client DoS vector).
- **Deadlines** — honor client deadlines propagated via `context`; enforce a server-side ceiling in an interceptor when clients can't be trusted ([`grpc-api.md`](./grpc-api.md)).

## Behind a Reverse Proxy
Set Go-side timeouts even behind Traefik/nginx. The proxy shields you from external slow clients, but internal callers, retries, and a misbehaving proxy can still exhaust an unguarded backend. Defense in depth — never rely on the proxy alone.

## Checklist
- [ ] `http.Server` sets `ReadHeaderTimeout` (at minimum) plus `Read`/`Write`/`Idle` timeouts.
- [ ] `MaxHeaderBytes` and `http.MaxBytesReader` cap header/body size.
- [ ] Slow/streaming routes use per-handler deadlines, not loose global timeouts.
- [ ] gRPC sets message-size caps, `MaxConcurrentStreams`, keepalive + enforcement policy.
- [ ] Server-side deadline ceiling enforced even behind a proxy.
