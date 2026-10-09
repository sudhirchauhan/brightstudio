#!/usr/bin/env escript
main([]) ->
    "true" = os:getenv("BRIGHT_ACCEPTANCE_SEED"),
    code:add_paths(filelib:wildcard("_build/prod/rel/bright_studio/lib/*/ebin")),
    application:ensure_all_started(bright_platform),
    application:ensure_all_started(crypto),
    ok = bright_migrate:run(),
    lists:foreach(fun({Email,Password}) ->
        Existing = bright_sql_pool:with_connection(fun(C) ->
            epgsql:equery(C,"SELECT id FROM bright_users WHERE email=$1",[Email])
        end),
        case Existing of
            {ok,_,[]} -> {ok,_,_} = bright_session:provision(Email,Password,<<"Acceptance project">>);
            {ok,_,[_]} -> ok
        end
    end,[{<<"owner-a@example.test">>,<<"Milestone-test-password-A">>},
          {<<"owner-b@example.test">>,<<"Milestone-test-password-B">>}]),
    io:format("Acceptance owners are available in the isolated database.~n").
