FROM alpine:latest

MAINTAINER Kevin Li <mlf4aiur@gmail.com>

ARG built_on="Unknown"

WORKDIR /root/mybot

RUN \
    apk add --update \
        --repository https://dl-cdn.alpinelinux.org/alpine/edge/community/ \
        nodejs \
        python \
        make \
        gcc \
        libc-dev \
        g++ \
        tini \
        ca-certificates \
    && update-ca-certificates \
    && rm -rf /tmp/* /var/cache/apk/*

ADD https://s3.amazonaws.com/amazon-ecs-cli/ecs-cli-linux-amd64-latest /usr/local/bin/ecs-cli

RUN \
    chmod +x /usr/local/bin/ecs-cli \
    && npm install -g fs-extra \
    && sed -i \
        -e 's/graceful-fs/fs-extra/' \
        -e 's/fs\.rename/fs.move/' \
        "$(npm root -g)/npm/lib/utils/rename.js" \
    && npm install -g npm \
    && mkdir -p /root/mybot/bin /root/.config/configstore/ /root/node_modules \
    && npm install -g yo generator-hubot \
    && chmod -R g+rwx /root/ \
    && yes | yo hubot \
        --owner="User <user@example.com>" \
        --name="Hubot" \
        --description="hubot" \
        --adapter="slack" \
    && npm install --save \
        hubot-ecs-cli \
        aws-sdk \
    && sed -i '1a\  "hubot-ecs-cli",' /root/mybot/external-scripts.json \
    && find /usr/lib/node_modules/npm -name test -o -name .bin -type d | xargs rm -rf \
    && rm -rf /tmp/* \
        /usr/lib/node_modules/npm/man \
        /usr/lib/node_modules/npm/doc/usr/lib/node_modules/npm/html \
        /root/node_modules \
        /root/mybot/hubot-scripts.json

VOLUME ["/root/mybot"]

LABEL build.on=$built_on

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/root/mybot/bin/hubot", "--adapter", "slack"]
