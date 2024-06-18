FROM node:16 as builder

RUN pwd
WORKDIR /web
run pwd

# 读取 VERSION 文件内容并设置环境变量
RUN echo "VERSION=$(cat ./VERSION)" > .env && \
    source .env && \
    echo "VERSION=$VERSION"

COPY ./VERSION .
COPY ./web .

WORKDIR /web/default
RUN npm install
RUN DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=${VERSION} npm run build

WORKDIR /web/berry
RUN npm install
RUN DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=${VERSION} npm run build

WORKDIR /web/air
RUN npm install
RUN DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=${VERSION} npm run build

FROM golang AS builder2

ENV GO111MODULE=on \
    CGO_ENABLED=1 \
    GOOS=linux

WORKDIR /build
ADD go.mod go.sum ./
RUN go mod download
COPY . .
COPY --from=builder /web/build ./web/build
RUN go build -ldflags "-s -w -X 'github.com/mxdlzg/one-api/common.Version=${VERSION}' -extldflags '-static'" -o one-api

FROM alpine

RUN apk update \
    && apk upgrade \
    && apk add --no-cache ca-certificates tzdata \
    && update-ca-certificates 2>/dev/null || true

COPY --from=builder2 /build/one-api /
EXPOSE 3000
WORKDIR /data
ENTRYPOINT ["/one-api"]