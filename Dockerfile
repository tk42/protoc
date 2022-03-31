####
##  alpine image fails to install python-grpc
####
FROM ubuntu:21.10

## Check at https://github.com/protocolbuffers/protobuf/releases/
ENV PROTOBUF_VERSION=3.19.4

RUN apt-get update

####
## install golang (its dependency is included gcc)
####

RUN apt-get install -y \
	ca-certificates curl golang

####
## download protoc
## https://github.com/protocolbuffers/protobuf/blob/master/src/README.md
####
WORKDIR /home

RUN set -eux && \
	apt-get install -y git curl autoconf automake libtool g++ unzip make && \
	curl -L -o /home/protobuf.tar.gz https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-cpp-${PROTOBUF_VERSION}.tar.gz && \
	tar -zxvf protobuf.tar.gz

WORKDIR /home/protobuf-${PROTOBUF_VERSION}

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
ENV GOPATH /go
ENV PATH $GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

RUN go get -u google.golang.org/protobuf/cmd/protoc-gen-go && \
	go get -u google.golang.org/grpc/cmd/protoc-gen-go-grpc && \
	go get -u github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc && \
	go get -u github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway && \
	go get -u github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2 && \
	go get -u entgo.io/contrib/entproto/cmd/protoc-gen-entgrpc

####
## install python plugin of protobuf
####
# MEMO: To avoid dialog of tzdata (a python library). https://qiita.com/yagince/items/deba267f789604643bab
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get install -y python3 python3-dev pip
RUN pip install --upgrade pip

####
## install python plugin of python-grpc
##   Following instruction is from https://grpc.io/docs/languages/python/quickstart/
## CAUTION: This way is failed on alpine.
####

RUN pip install protobuf grpcio grpcio-tools
