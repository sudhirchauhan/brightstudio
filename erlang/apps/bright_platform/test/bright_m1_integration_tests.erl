-module(bright_m1_integration_tests).
-include_lib("eunit/include/eunit.hrl").
integration_test_() ->
    case os:getenv("BRIGHT_INTEGRATION_TESTS") of
        "true" -> {timeout,60,fun integration/0};
        _ -> []
    end.
integration() ->
    {ok,_} = application:ensure_all_started(bright_platform),
    {ok,_} = application:ensure_all_started(crypto),
    ?assertEqual(ok,bright_migrate:run()),
    %% sslmode=require must fail closed when this isolated PostgreSQL server offers no TLS.
    ?assertEqual({error,ssl_not_available},bright_db:connect(os:getenv("DATABASE_URL") ++ "?sslmode=require")),
    Parent = self(),
    [spawn(fun() -> Parent ! {migration,bright_migrate:run()} end) || _ <- lists:seq(1,3)],
    [receive {migration,Result} -> ?assertEqual(ok,Result) after 15000 -> error(migration_timeout) end || _ <- lists:seq(1,3)],
    ?assertEqual(ok,bright_migrate:run()),
    %% Prove the runner waits for the same advisory lock, rather than merely tolerating replay.
    {ok,LockConn} = bright_db:connect(os:getenv("DATABASE_URL")),
    {ok,_,_} = epgsql:equery(LockConn,"SELECT pg_advisory_lock($1)",[74190321]),
    spawn(fun() -> Parent ! {blocked_migration,bright_migrate:run()} end),
    receive {blocked_migration,_} -> error(lock_not_held) after 100 -> ok end,
    {ok,_,_} = epgsql:equery(LockConn,"SELECT pg_advisory_unlock($1)",[74190321]),
    receive {blocked_migration,Done} -> ?assertEqual(ok,Done) after 15000 -> error(lock_timeout) end,
    epgsql:close(LockConn),
    Email = <<(bright_project_auth:new_id())/binary,"@example.test">>,
    {ok,User,Project} = bright_session:provision(Email,<<"Integration-password-123">>,<<"Integration project">>),
    {ok,Token} = bright_session:login(Email,<<"Integration-password-123">>),
    ?assertEqual({ok,User},bright_identity:authenticate_token(Token)),
    Key = bright_project_auth:new_id(),
    Data = #{<<"title">>=><<"Persistent source">>,<<"project_id">>=>Project},
    {ok,Source} = bright_source:create(User,Key,Data),
    ?assertEqual({ok,Source},bright_source:create(User,Key,Data)),
    ?assertEqual({error,conflict},bright_source:create(User,Key,Data#{<<"title">>=><<"Different">>})),
    {ok,[Source]} = bright_source:list(User,Project),
    Id = maps:get(id,Source),
    ?assertEqual({error,not_found},bright_source:read(bright_project_auth:new_id(),Id)),
    %% Kill all pooled connections by restarting their supervisor child. Data and sessions remain SQL-backed.
    ok = supervisor:terminate_child(bright_platform_sup,bright_sql_pool),
    {ok,_} = supervisor:restart_child(bright_platform_sup,bright_sql_pool),
    ?assertEqual({ok,Source},bright_source:read(User,Id)),
    ?assertEqual({ok,User},bright_identity:authenticate_token(Token)),
    ok = bright_session:revoke(Token),
    ?assertEqual({error,unauthenticated},bright_identity:authenticate_token(Token)),
    {ok,Conn} = bright_sql_pool:checkout(),
    ?assertEqual({error,not_connection_owner},begin
        spawn(fun()-> Parent ! {checkin,bright_sql_pool:checkin(Conn)} end),
        receive {checkin,R}->R after 5000->error(timeout) end
    end),
    ok = bright_sql_pool:checkin(Conn),
    Connections = [begin {ok,C}=bright_sql_pool:checkout(),C end || _ <- lists:seq(1,5)],
    ?assertEqual({error,pool_exhausted},bright_sql_pool:checkout()),
    [ok = bright_sql_pool:checkin(C) || C <- Connections],
    Dead = hd(Connections), DeadMonitor = erlang:monitor(process,Dead), exit(Dead,kill),
    receive {'DOWN',DeadMonitor,process,Dead,_} -> ok after 5000 -> error(dead_connection_timeout) end,
    Recovered = [begin {ok,C}=bright_sql_pool:checkout(),C end || _ <- lists:seq(1,5)],
    ?assertEqual({error,pool_exhausted},bright_sql_pool:checkout()),
    [ok = bright_sql_pool:checkin(C) || C <- Recovered],
    {ok,ExpiredToken} = bright_session:login(Email,<<"Integration-password-123">>),
    bright_sql_pool:with_connection(fun(C) ->
        {ok,1} = epgsql:equery(C,"UPDATE bright_sessions SET expires_at=now()-interval '1 second' WHERE token_hash=$1",[crypto:hash(sha256,ExpiredToken)])
    end),
    ?assertEqual({error,unauthenticated},bright_identity:authenticate_token(ExpiredToken)),
    {ok,DisabledToken} = bright_session:login(Email,<<"Integration-password-123">>),
    bright_sql_pool:with_connection(fun(C) ->
        {ok,1} = epgsql:equery(C,"UPDATE bright_users SET disabled_at=now() WHERE id=$1",[User])
    end),
    ?assertEqual({error,unauthenticated},bright_identity:authenticate_token(DisabledToken)),
    ?assertEqual({error,unauthenticated},bright_session:login(Email,<<"Integration-password-123">>)).
