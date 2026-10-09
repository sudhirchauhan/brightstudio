-module(bright_db_url_tests).
-include_lib("eunit/include/eunit.hrl").

valid_url_test() ->
    {ok, C} = bright_db:parse_url("postgresql://alice:p%40ss%3Aword@db.internal:5433/studio_dev?sslmode=require"),
    ?assertEqual("alice", maps:get(user, C)),
    ?assertEqual("p@ss:word", maps:get(password, C)),
    ?assertEqual("db.internal", maps:get(host, C)),
    ?assertEqual(5433, maps:get(port, C)),
    ?assertEqual("studio_dev", maps:get(database, C)),
    ?assertEqual(true, maps:get(ssl, C)).

default_port_test() ->
    {ok, C} = bright_db:parse_url(<<"postgres://a:b@localhost/dev">>),
    ?assertEqual(5432, maps:get(port, C)),
    ?assertEqual(false, maps:get(ssl, C)).

reject_invalid_urls_test() ->
    lists:foreach(fun(U) ->
        ?assertEqual({error, invalid_database_configuration}, bright_db:parse_url(U))
    end, ["not a url", "https://a:b@localhost/db",
          "postgres://a:b@localhost/", "postgres://a@localhost/db",
          "postgres://a:b@localhost/db?sslmode=verify-full", 42]).
