# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20240612-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.17.1-erlang-26.2.5-debian-bullseye-20240612-slim
#
ARG ELIXIR_VERSION=1.17.1
ARG OTP_VERSION=26.2.5
ARG DEBIAN_VERSION=bullseye-20240612-slim

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

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git nodejs npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# WORKDIR /app/assets
# # Install node, npm and yarn
# RUN curl -sL https://deb.nodesource.com/setup_22.x | bash
# RUN apt-get install -y nodejs
# RUN npm install

# # Switch back to main app directory for Elixir/Phoenix commands
# WORKDIR /app

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
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates curl \
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
RUN sed -i 's/\r$//' /app/bin/server /app/bin/cron-runner /app/bin/wololo \
  && chmod +x /app/bin/server /app/bin/cron-runner /app/bin/wololo

USER nobody

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENTRYPOINT ["/tini", "--"]

CMD ["/app/bin/server"]
