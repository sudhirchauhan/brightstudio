-module(bright_studio_sup).
-behaviour(supervisor).
-export([start_link/0,init/1]).
start_link()->supervisor:start_link({local,?MODULE},?MODULE,[]).
init([])->
    SourceChildren=case os:getenv("BRIGHT_ROLE","web") of
        "web"->case os:getenv("STUDIO_WEB_EXTRACTION_ENABLED") of
            "true"->[source_worker()];
            _->[]
        end;
        "worker"->[source_worker()];
        _->error(invalid_role)
    end,
    Children=SourceChildren++case lists:member(os:getenv("BRIGHT_ROLE","web"),["web","worker"]) andalso bright_media:enabled() of true->[#{id=>bright_media_worker,start=>{bright_media_worker,start_link,[]},restart=>permanent,shutdown=>115000}];false->[] end,
    {ok,{{one_for_one,5,10},Children}}.

%% Opt-in for free staging: extraction stays asynchronous and uses the same
%% durable SQL leases as the separate worker. The web service may sleep.
source_worker()->
    #{id=>bright_source_worker,start=>{bright_source_worker,start_link,[]},restart=>permanent,shutdown=>25000}.
