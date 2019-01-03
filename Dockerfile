FROM debian:latest

ENV LIBSLZ_VERSION=v1.1.0 \
	HAPROXY_MAJOR=1.8 \
    HAPROXY_VERSION=v1.8.13 \
	OPENSSL_VERSION=1.1.1

ENV DEBIAN_FRONTEND=noninteractive \
	DATA_DIR=/data \
	LIBSLZ_PATH=/opt/libslz \
	OPENSSL_PATH=/opt/openssl-${OPENSSL_VERSION} \
	SRCPATH_51DEGREES=/opt/51degrees \
	HAPROXY_PATH=/opt/haproxy

RUN apt-get update -yq && apt-get upgrade -yq \
    && apt-get install -yq --no-install-recommends inotify-tools ca-certificates build-essential git libpcre3-dev liblua5.3 liblua5.3-dev curl bzip2 libssl-dev \
	&& mkdir -p ${DATA_DIR}

# Install OpenSSL Manually for TLS 1.3
# RUN cd /opt && curl -LO https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
# 	&& tar -xzf openssl-${OPENSSL_VERSION}.tar.gz \
# 	&& cd openssl-${OPENSSL_VERSION} \
# 	&& ./config --prefix=/opt/openssl-${OPENSSL_VERSION} shared \
# 	&& make \
# 	&& make install

# Install SLZ in place of Zlib
RUN git clone --branch=${LIBSLZ_VERSION} http://git.1wt.eu/git/libslz.git ${LIBSLZ_PATH} \
	&& cd $LIBSLZ_PATH && make static

# Install 51Degrees
RUN git clone --depth=1 https://github.com/51Degrees/Device-Detection.git ${SRCPATH_51DEGREES}

# Build HAProxy
RUN git clone --branch ${HAPROXY_VERSION} http://git.haproxy.org/git/haproxy-${HAPROXY_MAJOR}.git/ ${HAPROXY_PATH} \
    && cd $HAPROXY_PATH \
	&& make TARGET=custom CPU=native USE_THREAD=1 USE_CPU_AFFINITY=1 USE_PCRE=1 USE_PCRE_JIT=1 USE_LIBCRYPT=1 USE_LINUX_SPLICE=1 USE_LINUX_TPROXY=1 USE_GETADDRINFO=1 USE_STATIC_PCRE=1 USE_TFO=1 USE_SLZ=1 SLZ_INC=${LIBSLZ_PATH}/src SLZ_LIB=${LIBSLZ_PATH} USE_OPENSSL=1 SSL_LIB=${OPENSSL_PATH}lib SSL_INC=${OPENSSL_PATH}include ADDLIB=-ldl USE_LUA=1 LUA_LIB=/usr/share/lua/5.3/ LUA_INC=/usr/include/lua5.3 USE_51DEGREES=1 51DEGREES_SRC=${SRCPATH_51DEGREES}/src/trie

FROM scratch

COPY --from=0 /opt/haproxy/haproxy /usr/sbin/haproxy
COPY --from=0 /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1
COPY --from=0 /lib/x86_64-linux-gnu/libcrypt.so.1 /lib/x86_64-linux-gnu/libcrypt.so.1
COPY --from=0 /usr/lib/x86_64-linux-gnu/libssl.so.1.1 /usr/lib/x86_64-linux-gnu/libssl.so.1.1
COPY --from=0 /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=0 /usr/lib/x86_64-linux-gnu/liblua5.3.so.0 /usr/lib/x86_64-linux-gnu/liblua5.3.so.0
COPY --from=0 /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/libm.so.6
COPY --from=0 /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/libdl.so.2
COPY --from=0 /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=0 /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

STOPSIGNAL SIGUSR1

ENTRYPOINT ["haproxy", "-f", "/data/haproxy.cfg"]
