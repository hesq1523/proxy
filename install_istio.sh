#!/bin/sh
#

export CC=gcc
export CXX=g++

ISTIO_TAG=""
OPTIONS="build"
DOCKER_REPO="quay.io/fitstation"
ISTIO_CODE_DIR=$GOPATH/src/istio.io/istio
ENVOY_CODE_DIR="$(pwd)"
ISTIO_RELEASE_DIR=$GOPATH/out/linux_amd64/release
ENVOY_STABLE_SHA="$(grep PROXY_REPO_SHA $ISTIO_CODE_DIR/istio.deps -A 4 | grep lastStableSHA | cut -f 4 -d '"')"
ISTIO_ENVOY_DEBUG=$ISTIO_RELEASE_DIR/envoy
ISTIO_ENVOY_RELEASE=$ISTIO_RELEASE_DIR/envoy-$ENVOY_STABLE_SHA
ENVOY_BIN_DIR="$ENVOY_CODE_DIR/bazel-bin/src/envoy"
ISTIO_STRIP_OUTPUT="envoy-istio"
DOCKER_BUILD_DIR_PROXYV2=$ISTIO_RELEASE_DIR/docker_build/docker.proxyv2
DOCKER_BUILD_DIR_PROXY_DEBUG=$ISTIO_RELEASE_DIR/docker_build/docker.proxy_debug
DOCKER_BUILD_DIR_PROXY_TPROXY=$ISTIO_RELEASE_DIR/docker_build/docker.proxytproxy


if [ "$GOPATH" = "" ]; then
echo "GOPATH is not defined. You may not install golang. Please install golang 1.10.1 and define GOPATH."
exit 1;
fi
echo "ENVOY_CODE_DIR: " $ENVOY_CODE_DIR
echo "ISTIO_RELEASE_DIR: " $ISTIO_RELEASE_DIR
echo "ENVOY_STABLE_SHA: " $ENVOY_STABLE_SHA
echo "ISTIO_ENVOY_RELEASE: " $ISTIO_ENVOY_RELEASE

if [ $# -ge 2 ]; then
ISTIO_TAG="$2"
fi

if [ "$1" != "" ]; then
OPTIONS=$1
fi

echo "OPTIONS is: " "$OPTIONS"
echo "ISTIO_TAG is: " "$ISTIO_TAG"
if [ "$OPTIONS" != "build" ] && [ "$ISTIO_TAG" = "" ]; then
echo "Will generate docker image, but ISTIO_TAG is not specified."
exit 1;
fi

OPTION_BUILD=0
OPTION_DOCKER=0
if [ "$OPTIONS" = "build" ]; then
OPTION_BUILD=1
elif [ "$OPTIONS" = "docker" ]; then
OPTION_DOCKER=1
elif [ "$OPTIONS" = "all" ]; then
OPTION_BUILD=1
OPTION_DOCKER=1
fi

if [ $OPTION_BUILD -eq 1  ]; then
cd $ENVOY_CODE_DIR
echo 'cd' $(pwd)
echo "Build envoy."
result=`make BAZEL_BUILD_ARGS="-c opt --incompatible_bzl_disallow_load_after_statement=false"`
echo "make result: $result"
fi

cd $ENVOY_BIN_DIR
if [ -e envoy ]; then
echo 'cd' $(pwd)

echo "make dirs....."
mkdir -v -p $DOCKER_BUILD_DIR_PROXYV2
mkdir -v -p $DOCKER_BUILD_DIR_PROXY_DEBUG
mkdir -v -p $DOCKER_BUILD_DIR_PROXY_TPROXY

strip envoy -o $ISTIO_STRIP_OUTPUT && cp -v $ISTIO_STRIP_OUTPUT $ISTIO_ENVOY_RELEASE && cp -v $ISTIO_STRIP_OUTPUT $ISTIO_ENVOY_DEBUG

echo "Copy files....."
cp -v $ENVOY_CODE_DIR/src/envoy/http/jwt_auth/nats/libnats.so $ISTIO_RELEASE_DIR/docker_build/docker.proxy_debug/libnats.so
cp -v $ENVOY_CODE_DIR/src/envoy/http/jwt_auth/nats/libprotobuf-c.so $ISTIO_RELEASE_DIR/docker_build/docker.proxy_debug/libprotobuf-c.so

cp -v $ENVOY_CODE_DIR/src/envoy/http/jwt_auth/nats/libnats.so $ISTIO_RELEASE_DIR/docker_build/docker.proxytproxy/libnats.so
cp -v $ENVOY_CODE_DIR/src/envoy/http/jwt_auth/nats/libprotobuf-c.so $ISTIO_RELEASE_DIR/docker_build/docker.proxytproxy/libprotobuf-c.so

cp -v $ENVOY_CODE_DIR/src/envoy/http/jwt_auth/nats/libnats.so $ISTIO_RELEASE_DIR/docker_build/docker.proxyv2/libnats.so
cp -v $ENVOY_CODE_DIR/src/envoy/http/jwt_auth/nats/libprotobuf-c.so $ISTIO_RELEASE_DIR/docker_build/docker.proxyv2/libprotobuf-c.so
echo "End copy files....."
fi

if [ $OPTION_DOCKER -eq 1  ]; then
cd $ISTIO_CODE_DIR
echo 'cd' $(pwd)
echo "Make istio docker and push to quay."
export TAG=$ISTIO_TAG
export HUB=quay.io/fitstation
GOBUILDFLAGS=-i make && make docker && docker push $DOCKER_REPO/proxy_init:$ISTIO_TAG && docker push $DOCKER_REPO/proxyv2:$ISTIO_TAG && docker push $DOCKER_REPO/mixer:$ISTIO_TAG
fi

