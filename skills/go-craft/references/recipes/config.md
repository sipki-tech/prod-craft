# Configuration Management

Configuration should be strictly typed and validated on application startup.

## YAML-Based Config
Use YAML config files loaded into strongly typed structs. All struct tags must use `snake_case`.
- **Reason:** YAML is human-readable and supports hierarchical config. Typed structs are self-documenting and catch errors at startup, not at runtime.

```go
type config struct {
    Server    server          `yaml:"server"`
    DB        dbConfig        `yaml:"db"`
    FileStore fileStoreConfig `yaml:"file_store"`
    AuthKey   string          `yaml:"auth_key"`
    DevMode   bool            `yaml:"dev_mode"`
    Telegram  telegramConfig  `yaml:"telegram"`
    Cache     cacheConfig     `yaml:"cache"`
    OAuth     oauthConfig     `yaml:"oauth"`
    Email     emailConfig     `yaml:"email"`
}
```

## Loading Config via Flags
Use `flag.Var` with a custom `flag.Value` implementation to load the config file path. Set a `DefaultPath` and a `MaxSize` limit.
- **Reason:** Custom flag types allow validation at parse time (e.g., checking file size) and provide a clean default path for containerized deployments.

```go
func main() {
    cfgFile := &flags.File{DefaultPath: "/config.yml", MaxSize: 1024 * 1024}
    logLevel := &flags.Level{Level: slog.LevelDebug}

    flag.Var(cfgFile, "cfg", "path to config file")
    flag.Var(logLevel, "log_level", "log level")
    flag.Parse()

    // cfgFile implements io.Reader
    err := yaml.NewDecoder(cfgFile).Decode(&cfg)
}
```

## Config Struct Grouping
Group related config sub-structs in a single `type()` block at the top of `main.go`. Keep them unexported.
- **Reason:** Config types are internal to the binary and shouldn't leak into other packages.

```go
type (
    config struct { ... }
    server struct {
        Host string `yaml:"host"`
        Port ports  `yaml:"port"`
    }
    ports struct {
        GRPC   uint16 `yaml:"grpc"`
        Metric uint16 `yaml:"metric"`
        GW     uint16 `yaml:"gw"`
        Files  uint16 `yaml:"files"`
    }
    dbConfig struct {
        MigrateDir string `yaml:"migrate_dir"`
        Driver     string `yaml:"driver"`
        Postgres   string `yaml:"postgres"`
    }
)
```

## Environment Variables (`.env`)
Use `.env` files only for local development (loaded by `Taskfile.yml` via `dotenv`). In production, inject environment variables directly. Never read `os.Getenv` from business logic.
- **Reason:** Business logic should not know about the configuration source. Config is loaded once in `main.go` and passed as typed structs.

## Validate on Startup
Fail fast. If a required database URL or auth key is missing, exit immediately in `start()` rather than failing minutes later when a request arrives.
