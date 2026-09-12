# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bookworm-20260610-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.17.1-erlang-26.2.5-debian-bookworm-20260610-slim
#
ARG ELIXIR_VERSION=1.17.1
ARG OTP_VERSION=26.2.5
ARG DEBIAN_VERSION=bookworm-20260610-slim
ARG NODE_VERSION=20.20.2

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

# Official Node tarball — Debian's nodejs/npm packages pull gtk/mesa and 404 on security.debian.org
ARG NODE_VERSION
RUN apt-get update -y && apt-get install -y --no-install-recommends curl ca-certificates xz-utils \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
      | tar -xJ -C /usr/local --strip-components=1 \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Now you can run Elixir/Phoenix build steps
RUN mix deps.get
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# Verify that the server script was created from overlays
RUN ls -la /app/_build/${MIX_ENV}/rel/wololo/bin/ && \
    test -f /app/_build/${MIX_ENV}/rel/wololo/bin/server || \
    (echo "ERROR: /app/bin/server not found in release! Creating it manually..." && \
     mkdir -p /app/_build/${MIX_ENV}/rel/wololo/bin && \
     echo '#!/bin/sh' > /app/_build/${MIX_ENV}/rel/wololo/bin/server && \
     echo 'set -eu' >> /app/_build/${MIX_ENV}/rel/wololo/bin/server && \
     echo '' >> /app/_build/${MIX_ENV}/rel/wololo/bin/server && \
     echo 'cd -P -- "$(dirname -- "$0")"' >> /app/_build/${MIX_ENV}/rel/wololo/bin/server && \
     echo 'PHX_SERVER=true exec ./wololo start' >> /app/_build/${MIX_ENV}/rel/wololo/bin/server && \
     chmod +x /app/_build/${MIX_ENV}/rel/wololo/bin/server)

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
  apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates curl \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Install supercronic for cron jobs
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.29/supercronic-linux-amd64 \
    SUPERCRONIC=supercronic-linux-amd64
RUN curl -fsSLO "$SUPERCRONIC_URL" \
 && chmod +x "$SUPERCRONIC" \
 && mv "$SUPERCRONIC" /usr/local/bin/supercronic

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/wololo ./

# Copy crontab file and cron job script
COPY --chown=nobody:root crontab /app/crontab
COPY --chown=nobody:root rel/cron_job.exs /app/rel/cron_job.exs
COPY --chown=nobody:root rel/cron-runner.sh /app/bin/cron-runner
RUN find /app -type f \( -name '*.sh' -o -name 'server' -o -name 'wololo' -o -name 'cron-runner' \) \
      -exec sed -i 's/\r$//' {} + \
  && chmod +x /app/bin/server /app/bin/cron-runner /app/bin/wololo

USER nobody

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENTRYPOINT ["/tini", "--"]

CMD ["/app/bin/server"]
