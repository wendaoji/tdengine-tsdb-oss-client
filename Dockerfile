FROM ubuntu:latest

ARG VERSION
ARG UBUNTU_REPO=""
ARG CLIENT_NAME
ARG TARGETARCH
# TDengine TSDB-OSS Client
# TDengine TSDB-OSS-Lite
ENV CLIENT_NAME=${CLIENT_NAME:-"TDengine TSDB-OSS Client"}

WORKDIR /opt

COPY entrypoint.sh /

RUN set -eux \
    && [ -n "${UBUNTU_REPO}" ] && sed -i "s#http://\(archive\|ports\)\.ubuntu\.com#${UBUNTU_REPO}#g" /etc/apt/sources.list.d/ubuntu.sources; \
    apt-get update \
    && apt-get install -y locales jq curl \
    && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
    && chmod +x /entrypoint.sh

ENV LANG=en_US.utf8

RUN set -eux \
    && if [ "$TARGETARCH" = "amd64" ]; then TD_CPUTYPE="x64"; else TD_CPUTYPE=$TARGETARCH; fi \
    && PRODUCT_DATA=$(curl -fsSL 'https://www.taosdata.com/wp-content/themes/tdengine/js/product-data.json' | jq --arg client "$CLIENT_NAME" --arg arch "$TD_CPUTYPE" '[ .[] | select (.name == $client)  | .versions | .[] | select(.platform == "Linux-Generic" and .arch == $arch and .type == "Client")]') \
    && if [ -n "${VERSION}" ]; then PRODUCT_DATA=$(jq -n "${PRODUCT_DATA}" | jq '.[] | select(.version == "'${VERSION}'")'); else  PRODUCT_DATA=$(jq -n "${PRODUCT_DATA}" | jq 'sort_by(.version) | last');fi \
    && DOWNLOAD_URL=$(jq -n "${PRODUCT_DATA}" | jq -r '."download-url"') \
    && curl -fsSLO "${DOWNLOAD_URL}" \
    && file=$(ls *.tar.gz) && tar -xzf "$file" && cd "$(tar -tzf "$file" | head -n 1 | cut -f1 -d'/')" \
    && bash ./install_client.sh \
    && cd .. \
    && rm -rf $file


ENTRYPOINT [ "/entrypoint.sh" ]

CMD [ "/usr/bin/taos","--help" ]
