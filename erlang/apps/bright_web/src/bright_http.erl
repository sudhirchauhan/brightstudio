-module(bright_http).
-export([start_link/0]).
start_link() ->
    Port = list_to_integer(os:getenv("PORT", "10000")),
    Dispatch = cowboy_router:compile([{'_', [
        {"/healthz", bright_http_handler, live},
        {"/readyz", bright_http_handler, ready},
        {"/", bright_http_handler, home},
        {"/studio/", bright_http_handler, studio},
        {"/studio/hub/", bright_http_handler, hub}
    ]}]),
    cowboy:start_clear(bright_http, [{port, Port}], #{env => #{dispatch => Dispatch}, max_connections => 1024}).
