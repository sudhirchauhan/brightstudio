-module(bright_sql_pool_tests).
-include_lib("eunit/include/eunit.hrl").

pool_configuration_test() ->
    {ok, State} = bright_sql_pool:init([]),
    ?assertEqual(5, element(4, State)).

pool_exhaustion_test() ->
    %% Exercise capacity without a live PostgreSQL server.
    {ok, State} = bright_sql_pool:init([]),
    Full = setelement(5, State, element(4, State)),
    {reply, {error, pool_exhausted}, _} =
        bright_sql_pool:handle_call(checkout, {self(), make_ref()}, Full).

unauthorized_checkin_test() ->
    {ok, State} = bright_sql_pool:init([]),
    {reply, {error, not_connection_owner}, _} =
        bright_sql_pool:handle_call({checkin, self()}, {self(), make_ref()}, State).

missing_database_url_test() ->
    Previous = os:getenv("DATABASE_URL"),
    os:unsetenv("DATABASE_URL"),
    try
        {ok, State} = bright_sql_pool:init([]),
        {reply, {error, missing_database_url}, _} =
            bright_sql_pool:handle_call(checkout, {self(), make_ref()}, State)
    after
        case Previous of
            false -> os:unsetenv("DATABASE_URL");
            Value -> os:putenv("DATABASE_URL", Value)
        end
    end.
