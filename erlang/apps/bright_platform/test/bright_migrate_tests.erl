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
