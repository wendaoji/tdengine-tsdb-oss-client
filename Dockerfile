FROM --platform=$BUILDPLATFORM alpine:3.19 AS builder

WORKDIR /opt

# cross compilation. run on $BUILDPLATFORM, building for $TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETARCH
ARG VERNUMBER
ARG TAOSADAPTER_GIT_TAG_NAME
ARG NPROC

ENV VERNUMBER=${VERNUMBER:-"3.3.7.5"}
ENV TAOSADAPTER_GIT_TAG_NAME=${TAOSADAPTER_GIT_TAG_NAME:-"ver-3.3.7.5"}
ENV NPROC=${NPROC:-4}

# Install build dependencies
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories \
  && apk update && apk add --no-cache \
  build-base \
  cmake \
  git \
  openssl-dev \
  curl-dev \
  linux-headers \
  util-linux-dev \
  coreutils \
  argp-standalone \
  libunwind-dev \
  perl \
  autoconf \
  && ln -sf /usr/bin/install /bin/install

RUN git clone --depth=1 --branch ${TAOSADAPTER_GIT_TAG_NAME} https://github.com/taosdata/TDengine.git

WORKDIR /opt/TDengine

COPY osThread.h.diff .

# The build arguments `-DBUILD_TOOLS=false -DBUILD_KEEPER=false -DBUILD_TEST=false` are set to reduce potential errors. If you need to build more components, please modify the Dockerfile accordingly.
# When compiling with multiple threads, errors can be hard to trace; use  -j1  to build single-threaded instead.
# cmake -DCPUTYPE=arm32/arm64/loongarch64/mips64/x86-64/x86
ENV TD_CPUTYPE=${TARGETARCH}
RUN if [ "$TARGETARCH" = "amd64" ]; then \
  export TD_CPUTYPE="x86-64"; \
  fi

RUN git apply --check osThread.h.diff \
  && git apply osThread.h.diff  \
  && mkdir build \
  && cd build \
  && cmake .. -DCPUTYPE=${TD_CPUTYPE} -DBUILD_TOOLS=false -DBUILD_KEEPER=false -DBUILD_TEST=false \
  && make VERBOSE=1 -j${NPROC}



FROM alpine:3.19

ARG VERNUMBER
ENV VERNUMBER=${VERNUMBER:-"3.3.7.5"}
ENV LD_LIBRARY_PATH=/opt/tdengine-tsdb-oss-client/lib \
  PATH=/opt/tdengine-tsdb-oss-client/bin:$PATH

RUN mkdir -p /opt/tdengine-tsdb-oss-client/lib \
  && mkdir -p /opt/tdengine-tsdb-oss-client/bin \
  && mkdir -p /opt/tdengine-tsdb-oss-client/etc

WORKDIR /opt/tdengine-tsdb-oss-client

COPY --from=builder /opt/TDengine/build/build/lib/libtaos.so lib/libtaos.so.${VERNUMBER}
COPY --from=builder /opt/TDengine/build/build/lib/libtaosnative.so lib/libtaosnative.so.${VERNUMBER}

# If you are using glibc-based distributions (Ubuntu/CentOS), you usually only need `libtaos.so` and `libtaosnative.so`.
# Now that we’re using musl libc (Alpine), you may also need `libunwind.so.8`, `liblzma.so.5`, `libstdc++.so.6`, and `libgcc_s.so.
#
# libunwind.so liblzma.so libstdc++.so.6 libgcc_s.so.1 . If these libraries already exist on the system, you don’t need to copy them.
COPY --from=builder /usr/lib/libunwind.so.8.* /usr/lib/liblzma.so.5.* /usr/lib/libstdc++.so.6.* /usr/lib/libgcc_s.so.1 lib/

COPY --from=builder /opt/TDengine/build/build/bin/taos bin/

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh \
  && chmod +x bin/taos \
  && ln -s /opt/tdengine-tsdb-oss-client/lib/libtaos.so.* /opt/tdengine-tsdb-oss-client/lib/libtaos.so \
  && ln -s /opt/tdengine-tsdb-oss-client/lib/libtaosnative.so.* /opt/tdengine-tsdb-oss-client/lib/libtaosnative.so \
  && ln -s /opt/tdengine-tsdb-oss-client/lib/libunwind.so.8.* /opt/tdengine-tsdb-oss-client/lib/libunwind.so.8 \
  && ln -s /opt/tdengine-tsdb-oss-client/lib/liblzma.so.5.* /opt/tdengine-tsdb-oss-client/lib/liblzma.so.5 \
  && ln -s /opt/tdengine-tsdb-oss-client/lib/libstdc++.so.6.* /opt/tdengine-tsdb-oss-client/lib/libstdc++.so.6


ENTRYPOINT ["/entrypoint.sh"]

CMD ["taos"]
