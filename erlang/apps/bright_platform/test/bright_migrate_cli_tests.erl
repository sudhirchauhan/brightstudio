-module(bright_migrate_cli_tests).
-include_lib("eunit/include/eunit.hrl").

successful_migration_exit_test() ->
    ?assertEqual(0, bright_migrate_cli:status(ok)).

failed_migration_exit_test() ->
    ?assertEqual(1, bright_migrate_cli:status({error, missing_database_url})),
    ?assertEqual(1, bright_migrate_cli:status({error, connection_refused})),
    ?assertEqual(1, bright_migrate_cli:status(unexpected)).
