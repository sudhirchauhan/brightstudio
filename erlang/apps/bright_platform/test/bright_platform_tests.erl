-module(bright_platform_tests).
-include_lib("eunit/include/eunit.hrl").
invalid_database_url_test() ->
    ?assertMatch({error, _}, bright_db:ping("not a database URL")).
