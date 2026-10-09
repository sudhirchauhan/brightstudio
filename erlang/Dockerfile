FROM erlang:27 AS build
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates wget && rm -rf /var/lib/apt/lists/*
RUN wget -q https://s3.amazonaws.com/rebar3/rebar3 -O /usr/local/bin/rebar3 && chmod +x /usr/local/bin/rebar3
COPY . .
RUN rebar3 get-deps && rebar3 compile && rebar3 eunit && rebar3 as prod release
FROM erlang:27
WORKDIR /app
COPY --from=build /app/_build/prod/rel/bright_studio /app
ENV PORT=10000 BRIGHT_ROLE=web
EXPOSE 10000
CMD ["bin/bright_studio", "foreground"]
