-module(bright_migrate_cli).
-export([main/0, status/1]).

%% Run as: bin/bright_studio eval 'bright_migrate_cli:main().'
%% The release process must exit nonzero on any migration error.
main() ->
    Result = try bright_migrate:run()
             catch Class:Reason -> {error, {Class, Reason}} end,
    case status(Result) of
        0 ->
            io:format("Bright Studio migrations complete~n"),
            erlang:halt(0);
        1 ->
            %% Do not print the DATABASE_URL or driver connection details.
            io:format(standard_error, "Bright Studio migrations failed; check database connectivity and migration SQL~n", []),
            erlang:halt(1)
    end.

status(ok) -> 0;
status(_) -> 1.
