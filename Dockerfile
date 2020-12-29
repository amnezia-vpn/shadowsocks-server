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

#Install shadosocks packages
RUN set -ex \
    && if [ $(wget -qO- ipinfo.io/country) == CN ]; then echo "http://mirrors.aliyun.com/alpine/latest-stable/main/" > /etc/apk/repositories ;fi \
    && apk add --no-cache libsodium py-pip \
    && pip --no-cache-dir install https://github.com/shadowsocks/shadowsocks/archive/master.zip

RUN cp ${APP_INSTALL_PATH}/config/server.conf /etc/openvpn/server.conf

ENTRYPOINT [ "dumb-init", "./start.sh" ]
CMD [ "" ]
