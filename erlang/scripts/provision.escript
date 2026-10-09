#!/usr/bin/env escript
%% Operator-only account provisioning. Inject variables securely, never as CLI arguments.
main([]) ->
    code:add_paths(filelib:wildcard("_build/prod/rel/bright_studio/lib/*/ebin")),
    try
        {ok,_} = application:ensure_all_started(bright_platform),
        {ok,_} = application:ensure_all_started(crypto),
        Email = required("BRIGHT_BOOTSTRAP_EMAIL"),
        Password = required("BRIGHT_BOOTSTRAP_PASSWORD"),
        Title = required("BRIGHT_BOOTSTRAP_PROJECT"),
        {ok,_,_} = bright_session:provision(Email,Password,Title),
        io:format("Account and project provisioned.~n")
    catch _:_ -> io:format(standard_error,"Provisioning failed; verify variables, migration and account uniqueness.~n",[]),halt(1) end.
required(Name) ->
    case os:getenv(Name) of false -> error(missing_variable); Value -> list_to_binary(Value) end.
