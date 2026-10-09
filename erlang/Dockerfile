# syntax=docker/dockerfile:1
FROM erlang:27@sha256:3bcaa1d1d910da84b59b3cfd192adc2228fcd78937adefda029f8b3a1477b3f5 AS build
WORKDIR /app
# The pinned image includes rebar3 3.27.0. Retain Hex checksums and TLS verification.
COPY . .
RUN --mount=type=secret,id=cloud_ca \
    if [ -f /run/secrets/cloud_ca ]; then \
      mkdir -p /root/.config/rebar3 && \
      printf '{ssl_cacerts_path, "/run/secrets/cloud_ca"}.\n' > /root/.config/rebar3/rebar.config; \
    fi && rebar3 compile && rebar3 eunit && rebar3 as prod release
FROM erlang:27@sha256:3bcaa1d1d910da84b59b3cfd192adc2228fcd78937adefda029f8b3a1477b3f5
WORKDIR /app
COPY --from=build --chown=1000:1000 /app/_build/prod/rel/bright_studio /app
ENV PORT=10000 BRIGHT_ROLE=web
USER 1000:1000
EXPOSE 10000
CMD ["bin/bright_studio", "foreground"]
