## ```protoc``` IS DEPRECATED, TRY TO USE A NEW TOOL ```buf``` in [buf.build](https://buf.build/)

---

# protoc
[![Docker Image CI](https://github.com/tk42/protoc/actions/workflows/action.yml/badge.svg)](https://github.com/tk42/protoc/actions/workflows/action.yml)

This repository supports for a Docker image that wraps ```protoc```, ```grpc``` and ```protoc-gen-go``` (API v2)

## How to use
```
docker pull ghcr.io/tk42/protoc
```

## How does it work
Open ```docker-compose.yml```, then specify your ```.proto```.

Finally,
```
docker compose up protoc
```

you'll find ```*.pb.go``` in the path specified at ```go_package``` in the proto file.

## Reference
[Quick start](https://grpc.io/docs/languages/go/quickstart/)
[iamrajiv/helloworld-grpc-gateway](https://github.com/iamrajiv/helloworld-grpc-gateway)
