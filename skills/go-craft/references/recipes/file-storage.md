# File Storage (S3-Compatible)

Storing user files (avatars, uploads, attachments) in S3-compatible object storage (AWS S3, MinIO, etc.) behind an app-layer interface.

## The Interface (the app layer owns it)
```go
// app/contracts.go
type FileStore interface {
    // UploadFile stores a new file and returns its id.
    // Errors: unknown.
    UploadFile(ctx context.Context, f File) (uuid.UUID, error)
    // DownloadFile streams a file by id (internal use, e.g. thumbnails).
    // Errors: ErrNotFound, unknown.
    DownloadFile(ctx context.Context, id uuid.UUID) (*File, error)
    // DeleteFile removes a file by id.
    // Errors: unknown.
    DeleteFile(ctx context.Context, id uuid.UUID) error
    // GetDownloadURL returns a URL for the client to fetch the file directly.
    // Errors: unknown.
    GetDownloadURL(ctx context.Context, id uuid.UUID, kind URLKind) (*FileURL, error)
}
```

`File` is a **streaming** type — embed a reader, don't carry a `[]byte`:

```go
type File struct {
    io.ReadSeekCloser
    ID          uuid.UUID
    UserID      uuid.UUID
    Name        string
    Size        int64
    ContentType string
    ModTime     time.Time
}
```

## Stream, Don't Buffer
Treat files as streams end to end; pass the reader straight to the S3 client. Buffering a 100 MB upload into memory will OOM under load.

## Sniff the Content-Type
Never trust the client's declared `Content-Type`. Sniff the first 512 bytes, then seek back:

```go
var head [512]byte
n, _ := io.ReadFull(r, head[:])
contentType := http.DetectContentType(head[:n])
if _, err := r.Seek(0, io.SeekStart); err != nil {
    return fmt.Errorf("seek: %w", err)
}
```

Validate the sniffed type against an allowlist (`image/png`, `image/jpeg`, ...) before storing.

## Multipart Uploads
For large objects the S3 client splits the upload into parts; set a sensible part size and it handles the rest. Use an **opaque UUID** as the object key and keep the original name/owner in metadata, not the key.

```go
_, err := store.PutObject(ctx, bucket, id.String(), f, f.Size, minio.PutObjectOptions{
    ContentType: f.ContentType,
    PartSize:    16 << 20, // 16 MiB parts
    UserMetadata: map[string]string{
        "src_name": f.Name,
        "user_id":  f.UserID.String(),
    },
})
```

## Download Strategy: Presigned vs Proxied
Choose a strategy via a `URLKind` enum:

| Kind | Strategy | When |
|---|---|---|
| Public | CDN URL, or presigned GET with long TTL | public assets |
| Private | presigned GET with short TTL (minutes) | per-user private files |
| Internal | backend proxy URL (`/v1/file/{id}`) | access-controlled / transformed |

Prefer **presigned URLs** so file bytes never pass through your app (saves bandwidth and CPU). Proxy only when you must enforce per-request authorization or transform the stream.

```go
url, err := store.PresignedGetObject(ctx, bucket, id.String(), ttl, nil)
```

- **TTL:** long (~1h) for public, short (~5m) for private. **Never** presign without an expiry.
- **CDN fallback:** if a CDN base URL is configured, return `cdn/{id}`; otherwise presign.

## Presigned Uploads (optional)
For large client uploads, hand the client a presigned **PUT** URL so bytes go straight to S3, then confirm with a metadata record. Keep upload TTLs short and constrain content-type/size where the provider supports it.

## Idempotency
Make uploads idempotent with a stable key (content hash / ETag). Re-uploading identical content under the same key is a no-op, so client retries don't create duplicates.

## Buckets & Lifecycle
- **Verify the bucket at startup** (fail fast if missing/unreachable).
- **Lifecycle/expiry rules** for temp objects (uploads, exports) so storage self-cleans.
- **Separate buckets or prefixes per environment.**

## Tracing & Errors
Wrap each method in a span named `FileStore.X`; wrap provider errors with `%w`. Map "object not found" to the domain `ErrNotFound` **at this boundary** (see [`../style/errors.md`](../style/errors.md)).

```go
func (c *Client) DownloadFile(ctx context.Context, id uuid.UUID) (*app.File, error) {
    ctx, span := c.tracer.Start(ctx, "FileStore.DownloadFile")
    defer span.End()

    obj, err := c.store.GetObject(ctx, c.bucket, id.String(), minio.GetObjectOptions{})
    if err != nil {
        return nil, fmt.Errorf("get object: %w", err)
    }
    stat, err := obj.Stat()
    if err != nil {
        return nil, fmt.Errorf("stat: %w", err)
    }
    if stat.IsDeleteMarker {
        return nil, app.ErrNotFound
    }
    // ... map stat -> app.File
}
```

## Checklist
- [ ] Files streamed, never fully buffered into memory.
- [ ] Content-Type sniffed from bytes and allowlisted.
- [ ] Opaque UUID keys; filename/owner stored as metadata.
- [ ] Presigned URLs preferred over proxying; bounded TTL, never infinite.
- [ ] Bucket verified at startup; lifecycle rules for temp objects.
- [ ] Provider errors wrapped with `%w`; not-found mapped to `ErrNotFound`.
