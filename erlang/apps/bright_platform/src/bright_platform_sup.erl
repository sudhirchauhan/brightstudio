-module(bright_platform_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).
start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).
init([]) ->
    Pool = #{id => bright_sql_pool,
             start => {bright_sql_pool, start_link, []},
             restart => permanent,
             shutdown => 5000,
             type => worker,
             modules => [bright_sql_pool]},
    {ok, {{one_for_one, 5, 10}, [Pool]}}.
