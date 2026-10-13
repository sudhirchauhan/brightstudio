# syntax=docker/dockerfile:1
FROM erlang:27@sha256:3bcaa1d1d910da84b59b3cfd192adc2228fcd78937adefda029f8b3a1477b3f5 AS native
RUN apt-get update && apt-get install -y --no-install-recommends cmake git python3 && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/setup
COPY scripts/prepare-native-models.py scripts/native-models.lock.json ./
RUN --mount=type=secret,id=cloud_ca \
    if [ -f /run/secrets/cloud_ca ]; then \
      python3 prepare-native-models.py --prefix /opt/bright-native --ca-file /run/secrets/cloud_ca; \
    else python3 prepare-native-models.py --prefix /opt/bright-native; fi
FROM erlang:27@sha256:3bcaa1d1d910da84b59b3cfd192adc2228fcd78937adefda029f8b3a1477b3f5 AS build
RUN apt-get update && apt-get install -y --no-install-recommends poppler-utils && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# The pinned image includes rebar3 3.27.0. Retain Hex checksums and TLS verification.
COPY . .
RUN --mount=type=secret,id=cloud_ca \
    if [ -f /run/secrets/cloud_ca ]; then \
      mkdir -p /root/.config/rebar3 && \
      printf '{ssl_cacerts_path, "/run/secrets/cloud_ca"}.\n' > /root/.config/rebar3/rebar.config; \
    fi && rebar3 compile && rebar3 eunit && rebar3 as prod release
FROM debian:bookworm-slim@sha256:7c7b2c966bc9ee8cedfeef67e0e279108992c77681fa595db4a9d65c06ccc587
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libtinfo6 zlib1g libstdc++6 libssl3 util-linux poppler-utils tesseract-ocr ffmpeg libgomp1 libzstd1 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build --chown=1000:1000 /app/_build/prod/rel/bright_studio /app
COPY --from=native --chown=1000:1000 /opt/bright-native/bin /opt/bright-native/bin
COPY --from=native --chown=1000:1000 /opt/bright-native/models /opt/bright-native/models
COPY --chown=1000:1000 --chmod=755 scripts/start-sqlite-dev.sh /app/bin/start-sqlite-dev
ENV PORT=10000 BRIGHT_ROLE=web \
    BRIGHT_AI_EXECUTABLE=/opt/bright-native/bin/llama-cli \
    BRIGHT_AI_MODEL_PATH=/opt/bright-native/models/assistant.gguf \
    BRIGHT_WHISPER_EXECUTABLE=/opt/bright-native/bin/whisper-cli \
    BRIGHT_WHISPER_MODEL_PATH=/opt/bright-native/models/whisper-tiny.en.bin
USER 1000:1000
EXPOSE 10000
CMD ["bin/bright_studio", "foreground"]
