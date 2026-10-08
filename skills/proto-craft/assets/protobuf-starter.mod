// Starter EasyP v1 module manifest — copy to the repo root as protobuf.mod,
// set your module identity, then run `easyp mod tidy` to write protobuf.lock.
// External proto modules: well-known types, HTTP annotations, validation.
module github.com/acme/api

roots (
	api
)

require (
	github.com/googleapis/googleapis
	github.com/grpc-ecosystem/grpc-gateway
	github.com/bufbuild/protovalidate
)
