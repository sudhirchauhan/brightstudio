-module(bright_migrate_tests).
-include_lib("eunit/include/eunit.hrl").
missing_configuration_test() ->
    Previous = os:getenv("DATABASE_URL"),
    os:unsetenv("DATABASE_URL"),
    try ?assertEqual({error, missing_database_url}, bright_migrate:run())
    after
        case Previous of
            false -> os:unsetenv("DATABASE_URL");
            Value -> os:putenv("DATABASE_URL", Value)
        end
    end.

migration_numeric_order_test() ->
    ?assertEqual(["2.sql", "10.sql"],
                 bright_migrate:sort_migration_files(["10.sql", "2.sql"])).

migration_duplicate_version_test() ->
    ?assertEqual({error, duplicate_migration_version},
                 bright_migrate:sort_migration_files(["01.sql", "1.sql"])).

migration_invalid_name_test() ->
    ?assertEqual({error, invalid_migration_filename},
                 bright_migrate:sort_migration_files(["not-a-number.sql"])).
