# telegram-bot-api built from upstream source (tdlib/telegram-bot-api).
# Exists because prebuilt images (aiogram etc.) lag upstream releases by
# weeks, while Telegram cloud rolls new tdlib file_id formats ahead of
# releases — a hybrid bot (cloud getUpdates + local getFile) breaks on
# every such drift. Building master directly closes the window to hours.
#
# Runtime contract matches aiogram/telegram-bot-api (drop-in replacement):
#   env TELEGRAM_API_ID / TELEGRAM_API_HASH (read natively by the binary),
#   uid 101, --local mode, http 8081, stat 8082,
#   workdir /var/lib/telegram-bot-api.

FROM ubuntu:24.04 AS builder
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates build-essential cmake ninja-build gperf git \
      zlib1g-dev libssl-dev \
    && rm -rf /var/lib/apt/lists/*
ARG TBA_REF=master
RUN git clone https://github.com/tdlib/telegram-bot-api.git /src \
    && cd /src && git checkout "$TBA_REF" \
    && git submodule update --init --recursive
RUN cmake -S /src -B /build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /build --target install \
    && /usr/local/bin/telegram-bot-api --version

FROM ubuntu:24.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      libssl3t64 zlib1g ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -u 101 -r -s /usr/sbin/nologin telegram-bot-api \
    && mkdir -p /var/lib/telegram-bot-api /tmp/telegram-bot-api \
    && chown telegram-bot-api:telegram-bot-api /var/lib/telegram-bot-api /tmp/telegram-bot-api
COPY --from=builder /usr/local/bin/telegram-bot-api /usr/local/bin/telegram-bot-api
EXPOSE 8081 8082
# Starts as root, the binary itself drops privileges to --username (uid 101),
# same as the aiogram image — keeps existing volume ownership/ACLs valid.
ENTRYPOINT ["/usr/local/bin/telegram-bot-api", \
  "--dir=/var/lib/telegram-bot-api", "--temp-dir=/tmp/telegram-bot-api", \
  "--username=telegram-bot-api", "--groupname=telegram-bot-api", \
  "--http-port=8081", "--local", "--http-stat-port=8082"]
