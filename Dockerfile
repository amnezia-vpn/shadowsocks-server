FROM alpine:3.11.3

LABEL maintainer="Anton B"

ENV APP_NAME shadow_vpn
ENV APP_INSTALL_PATH /opt/${APP_NAME}
ENV APP_PERSIST_DIR /opt/${APP_NAME}_data
ENV EASYRSA_BATCH 1
ENV PATH="/usr/share/easy-rsa:${PATH}"

WORKDIR ${APP_INSTALL_PATH}

COPY scripts .
COPY config ./config

#Install openvpn required packages
RUN apk add --no-cache openvpn easy-rsa bash netcat-openbsd dumb-init

# From https://github.com/WUAmin/alpine-shadowsocks-libev/blob/master/Dockerfile
RUN apk --update upgrade --no-cache

# Install build dependencies packages
RUN apk add --no-cache --virtual .build-deps \
  git \
  gcc \
  gettext \
  automake \
  make \
  asciidoc \
  xmlto \
  autoconf \
  build-base \
  curl \
  libev-dev \
  libtool \
  linux-headers \
  libsodium-dev \
  mbedtls-dev \
  pcre-dev \
  tar \
  c-ares-dev && \
  cd /tmp && \
  git clone https://github.com/shadowsocks/shadowsocks-libev.git && \
  cd shadowsocks-libev/ && \
  git submodule update --init --recursive && \
  ./autogen.sh && ./configure --prefix=/usr --disable-documentation && \
  make install && \
  cd .. && \
  # Remove build dependencies packages
  runDeps="$( \
  scanelf --needed --nobanner /usr/bin/ss-* \
  | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
  | xargs -r apk info --installed \
  | sort -u \
  )" && \
  apk add --no-cache --virtual .run-deps $runDeps && \
  apk del .build-deps && \
  rm -rf /tmp/*
  
RUN echo -e " \n\
  fs.file-max = 51200 \n\
  \n\
  net.core.rmem_max = 67108864 \n\
  net.core.wmem_max = 67108864 \n\
  net.core.netdev_max_backlog = 250000 \n\
  net.core.somaxconn = 4096 \n\
  \n\
  net.ipv4.tcp_syncookies = 1 \n\
  net.ipv4.tcp_tw_reuse = 1 \n\
  net.ipv4.tcp_tw_recycle = 0 \n\
  net.ipv4.tcp_fin_timeout = 30 \n\
  net.ipv4.tcp_keepalive_time = 1200 \n\
  net.ipv4.ip_local_port_range = 10000 65000 \n\
  net.ipv4.tcp_max_syn_backlog = 8192 \n\
  net.ipv4.tcp_max_tw_buckets = 5000 \n\
  net.ipv4.tcp_fastopen = 3 \n\
  net.ipv4.tcp_mem = 25600 51200 102400 \n\
  net.ipv4.tcp_rmem = 4096 87380 67108864 \n\
  net.ipv4.tcp_wmem = 4096 65536 67108864 \n\
  net.ipv4.tcp_mtu_probing = 1 \n\
  net.ipv4.tcp_congestion_control = hybla \n\
  # for low-latency network, use cubic instead \n\
  # net.ipv4.tcp_congestion_control = cubic \n\
  " | sed -e 's/^\s\+//g' | tee -a /etc/sysctl.conf && \
  mkdir -p /etc/security && \
  echo -e " \n\
  * soft nofile 51200 \n\
  * hard nofile 51200 \n\
  " | sed -e 's/^\s\+//g' | tee -a /etc/security/limits.conf  

#Install shadosocks packages
#RUN set -ex \
#    && if [ $(wget -qO- ipinfo.io/country) == CN ]; then echo "http://mirrors.aliyun.com/alpine/latest-stable/main/" > /etc/apk/repositories ;fi \
#    && apk add --no-cache libsodium py-pip \
#    && pip --no-cache-dir install https://github.com/shadowsocks/shadowsocks/archive/master.zip

RUN cp ${APP_INSTALL_PATH}/config/server.conf /etc/openvpn/server.conf

ENTRYPOINT [ "dumb-init", "./start.sh" ]
CMD [ "" ]
