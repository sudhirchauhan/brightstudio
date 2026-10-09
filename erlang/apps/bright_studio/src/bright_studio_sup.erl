-module(bright_studio_sup).
-behaviour(supervisor).
-export([start_link/0,init/1]).
start_link()->supervisor:start_link({local,?MODULE},?MODULE,[]).
init([])->
    Children=case os:getenv("BRIGHT_ROLE","web") of
        "web"->[];
        "worker"->[#{id=>bright_source_worker,start=>{bright_source_worker,start_link,[]},restart=>permanent,shutdown=>25000}];
        _->error(invalid_role)
    end,
    {ok,{{one_for_one,5,10},Children}}.
