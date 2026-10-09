-module(bright_http).
-export([start_link/0]).
start_link() ->
    Port = list_to_integer(os:getenv("PORT", "10000")),
    Dispatch = cowboy_router:compile([{'_', [
        {"/healthz", bright_http_handler, live},
        {"/readyz", bright_http_handler, ready},
        {"/", bright_http_handler, home},
        {"/studio/", bright_http_handler, studio},
        {"/studio/login/", bright_hub_handler, login_page},
        {"/studio/login.js", bright_hub_handler, {public_asset,"login.js",<<"text/javascript">>}},
        {"/studio/hub.css", bright_hub_handler, {public_asset,"hub.css",<<"text/css">>}},
        {"/studio/hub/hub.js", bright_hub_handler, {asset,"hub.js",<<"text/javascript">>}},
        {"/studio/hub/", bright_hub_handler, hub},
        {"/studio/hub/library/", bright_hub_handler, library},
        {"/studio/hub/sources/:id", bright_hub_handler, reader},
        {"/studio/api/session/login", bright_hub_handler, login},
        {"/studio/api/session/logout", bright_hub_handler, logout},
        {"/studio/api/session", bright_hub_handler, session},
        {"/studio/api/hub/projects", bright_hub_handler, projects},
        {"/studio/api/hub/sources", bright_hub_handler, sources},
        {"/studio/api/hub/sources/:id", bright_hub_handler, source},
        {"/studio/api/hub/library-state", bright_hub_handler, library_state},
        {"/studio/api/hub/sources/:id/revisions", bright_hub_handler, revisions},
        {"/studio/api/hub/sources/:id/revisions/:revision/content", bright_hub_handler, revision_content},
        {"/studio/api/hub/sources/:id/revisions/:revision/original", bright_hub_handler, revision_original},
        {"/studio/api/hub/sources/:id/revisions/:revision/retry", bright_hub_handler, revision_retry}
    ]}]),
    cowboy:start_clear(bright_http, [{port, Port}], #{env => #{dispatch => Dispatch}, max_connections => 1024}).
