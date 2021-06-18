FROM alpine

ENV PROTOBUF_VERSION=3.17.3

RUN apk update && \
    apk add --no-cache \
		ca-certificates

####
## install golang copied golang/alpine from https://hub.docker.com/_/golang
####

# set up nsswitch.conf for Go's "netgo" implementation
# - https://github.com/golang/go/blob/go1.9.1/src/net/conf.go#L194-L275
# - docker run --rm debian:stretch grep '^hosts:' /etc/nsswitch.conf
RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf

ENV PATH /usr/local/go/bin:$PATH

RUN set -eux; \
    apk add --no-cache --virtual .build-deps \
      bash \
      gcc \
      gnupg \
      go \
      musl-dev \
      openssl \
    ; \
    apkArch="$(apk --print-arch)"; \
    case "$apkArch" in \
      'x86_64') \
        export GOARCH='amd64' GOOS='linux'; \
        ;; \
      'armhf') \
        export GOARCH='arm' GOARM='6' GOOS='linux'; \
        ;; \
      'armv7') \
        export GOARCH='arm' GOARM='7' GOOS='linux'; \
        ;; \
      'aarch64') \
        export GOARCH='arm64' GOOS='linux'; \
        ;; \
      'x86') \
        export GO386='softfloat' GOARCH='386' GOOS='linux'; \
        ;; \
      'ppc64le') \
        export GOARCH='ppc64le' GOOS='linux'; \
        ;; \
      's390x') \
        export GOARCH='s390x' GOOS='linux'; \
        ;; \
      *) echo >&2 "error: unsupported architecture '$apkArch' (likely packaging update needed)"; exit 1 ;; \
    esac; \
    \
    # https://github.com/golang/go/issues/38536#issuecomment-616897960
    url='https://dl.google.com/go/go1.16.5.src.tar.gz'; \
    sha256='7bfa7e5908c7cc9e75da5ddf3066d7cbcf3fd9fa51945851325eebc17f50ba80'; \
    \
    wget -O go.tgz.asc "$url.asc"; \
    wget -O go.tgz "$url"; \
    echo "$sha256 *go.tgz" | sha256sum -c -; \
    \
    # https://github.com/golang/go/issues/14739#issuecomment-324767697
    export GNUPGHOME="$(mktemp -d)"; \
    # https://www.google.com/linuxrepositories/
    gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys 'EB4C 1BFD 4F04 2F6D DDCC EC91 7721 F63B D38B 4796'; \
    gpg --batch --verify go.tgz.asc go.tgz; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" go.tgz.asc; \
    \
    tar -C /usr/local -xzf go.tgz; \
    rm go.tgz; \
    \
    ( \
      cd /usr/local/go/src; \
    # set GOROOT_BOOTSTRAP + GOHOST* such that we can build Go successfully
      export GOROOT_BOOTSTRAP="$(go env GOROOT)" GOHOSTOS="$GOOS" GOHOSTARCH="$GOARCH"; \
      if [ "${GO386:-}" = 'softfloat' ]; then \
    # https://github.com/docker-library/golang/issues/359 -> https://github.com/golang/go/issues/44500
    # (once our Alpine base has Go 1.16, we can remove this hack)
        GO386= ./bootstrap.bash; \
        export GOROOT_BOOTSTRAP="/usr/local/go-$GOOS-$GOARCH-bootstrap"; \
        "$GOROOT_BOOTSTRAP/bin/go" version; \
      fi; \
      ./make.bash; \
      if [ "${GO386:-}" = 'softfloat' ]; then \
        rm -rf "$GOROOT_BOOTSTRAP"; \
      fi; \
    ); \
    \
    apk del --no-network .build-deps; \
    \
    # pre-compile the standard library, just like the official binary release tarballs do
    go install std; \
    # go install: -race is only supported on linux/amd64, linux/ppc64le, linux/arm64, freebsd/amd64, netbsd/amd64, darwin/amd64 and windows/amd64
    #	go install -race std; \
    \
    # remove a few intermediate / bootstrapping files the official binary release tarballs do not contain
    rm -rf \
      /usr/local/go/pkg/*/cmd \
      /usr/local/go/pkg/bootstrap \
      /usr/local/go/pkg/obj \
      /usr/local/go/pkg/tool/*/api \
      /usr/local/go/pkg/tool/*/go_bootstrap \
      /usr/local/go/src/cmd/dist/dist \
    ; \
    \
    go version

ENV GOPATH /go
ENV PATH $GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

####
## download protoc
####
WORKDIR /tmp

RUN set -eux && \
    apk add --no-cache git curl build-base autoconf automake libtool && \
    curl -L -o /tmp/protobuf.tar.gz https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-cpp-${PROTOBUF_VERSION}.tar.gz && \
    tar xvzf protobuf.tar.gz

WORKDIR /tmp/protobuf-${PROTOBUF_VERSION}

####
## install protoc
####

RUN set -eux && \
    ./autogen.sh && \
    ./configure && \
    make -j 3 && \
    make install

####
## install golang plugin of protobuf, protoc-gen-go (API v2), protoc-gen-go-grpc (API v2) and protoc-gen-doc
####
RUN go get -u google.golang.org/protobuf/cmd/protoc-gen-go && \
    go get -u google.golang.org/grpc/cmd/protoc-gen-go-grpc && \
    go get -u github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc && \
    go get -u github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway && \
    go get -u github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2

####
## install python plugin of protobuf
##
##  Tips: https://qiita.com/minarai/items/f1b699da4e5662247f45
##  install py3-pip
####
RUN apk add --no-cache python3 python3-dev py3-pip

RUN pip install protobuf

####
## install python plugin of python-grpc
## Following instruction is from https://grpc.io/docs/languages/python/quickstart/
####
RUN pip install --upgrade pip
RUN curl https://files.pythonhosted.org/packages/7e/2a/6fdcab8087bb46fa2e9c2cc814c00ad1715d0f402e4dd997770ea70cddeb/grpcio-1.38.0-cp39-cp39-manylinux2014_x86_64.whl
RUN pip install grpcio-1.38.0-cp39-cp39-manylinux2014_x86_64.whl

RUN curl https://files.pythonhosted.org/packages/b0/ba/6eef860a5e1bbbe9fdb1aeb4228833de4639c96d1dc528eeed82ff995ef7/grpcio_tools-1.38.0-cp39-cp39-manylinux2014_x86_64.whl
RUN pip install grpcio_tools-1.38.0-cp39-cp39-manylinux2014_x86_64.whl
