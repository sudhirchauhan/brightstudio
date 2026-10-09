-module(bright_http_handler).
-behaviour(cowboy_handler).
-export([init/2]).
init(Req, live) -> reply(200, <<"ok">>, Req);
init(Req, ready) ->
    case os:getenv("DATABASE_URL") of
        false -> reply(503, <<"database not configured">>, Req);
        Url ->
            case bright_db:ping(Url) of
                ok -> reply(200, <<"ready">>, Req);
                {error, _} -> reply(503, <<"database unavailable">>, Req)
            end
    end;
init(Req, hub) ->
    case os:getenv("STUDIO_HUB_ENABLED", "false") of
        "true" -> reply(403, <<"owner authorization required">>, Req);
        _ -> reply(404, <<"not found">>, Req)
    end;
init(Req, Page) ->
    Title = case Page of home -> <<"Bright Studio">>; studio -> <<"Studio">> end,
    Body = <<"<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>", Title/binary, "</title></head><body><main><h1>", Title/binary, "</h1><p>Erlang application foundation</p></main></body></html>">>,
    R = cowboy_req:reply(200, #{<<"content-type">> => <<"text/html; charset=utf-8">>, <<"cache-control">> => <<"no-store">>}, Body, Req),
    {ok, R}.
reply(Status, Body, Req) ->
    R = cowboy_req:reply(Status, #{<<"content-type">> => <<"text/plain; charset=utf-8">>, <<"cache-control">> => <<"no-store">>}, Body, Req),
    {ok, R}.
