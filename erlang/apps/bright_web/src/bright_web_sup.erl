-module(bright_web_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).
start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).
init([]) ->
    Role = os:getenv("BRIGHT_ROLE", "web"),
    Children = case Role of
        "web" -> [#{id => bright_login_limit, start => {bright_login_limit, start_link, []}},#{id => bright_http, start => {bright_http, start_link, []}, restart => permanent, shutdown => 5000, type => worker, modules => [bright_http]}];
        "worker" -> [];
        _ -> erlang:error({invalid_role, Role})
    end,
    {ok, {{one_for_one, 5, 10}, Children}}.
