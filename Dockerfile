FROM golang:alpine

ENV PROTOBUF_VERSION=3.17.1

WORKDIR /tmp

## download protoc
RUN set -eux && \
  apk update && \
  apk add --no-cache git curl build-base autoconf automake libtool && \
  curl -L -o /tmp/protobuf.tar.gz https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-cpp-${PROTOBUF_VERSION}.tar.gz && \
  tar xvzf protobuf.tar.gz

WORKDIR /tmp/protobuf-${PROTOBUF_VERSION}

## install protoc
RUN set -eux && \
  ./autogen.sh && \
  ./configure && \
  make -j 3 && \
  make install

## install protoc-gen-go (API v2) and protoc-gen-doc
RUN go get -u google.golang.org/protobuf/cmd/protoc-gen-go && \
    go get -u google.golang.org/grpc/cmd/protoc-gen-go-grpc && \
    go get -u github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc && \
    go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway && \
    go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger
