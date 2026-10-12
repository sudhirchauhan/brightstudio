-module(bright_sqlite_tests).
-include_lib("eunit/include/eunit.hrl").

sqlite_test_()->case {os:getenv("BRIGHT_INTEGRATION_TESTS"),os:getenv("DATABASE_URL")} of
    {"true","sqlite:"++_}->{timeout,30,fun storage/0};
    _->[]
end.
storage()->
    {ok,C}=bright_db:connect(os:getenv("DATABASE_URL")),
    try
        ?assert(bright_sql:sqlite(C)),
        {ok,_,[{1}]}=bright_sql:squery(C,"PRAGMA foreign_keys"),
        {ok,_,[{<<"wal">>}]}=bright_sql:squery(C,"PRAGMA journal_mode"),
        Id=bright_project_auth:new_id(),
        ?assertMatch({rollback,_},bright_sql:with_transaction(C,fun(T)->
            {ok,1}=bright_sql:equery(T,"INSERT INTO bright_users(id,email) VALUES($1,$2)",[Id,<<Id/binary,"@rollback.test">>]),
            {ok,1}=bright_sql:equery(T,"INSERT INTO bright_credentials(user_id,salt,password_hash) VALUES($1,$2,$3)",[Id,<<0>>,<<0>>])
        end)),
        ?assertMatch({ok,_,[]},bright_sql:equery(C,"SELECT id FROM bright_users WHERE id=$1",[Id])),
        %% Bound blobs retain arbitrary bytes; an SQL-looking email stays data.
        Email= <<Id/binary,"' OR 1=1 --@blob.test">>,
        {ok,1}=bright_sql:equery(C,"INSERT INTO bright_users(id,email) VALUES($1,$2)",[Id,Email]),
        Salt= <<0,255,0,128,0:96>>,Hash= <<255,0,128,0,0:224>>,
        {ok,1}=bright_sql:equery(C,"INSERT INTO bright_credentials(user_id,salt,password_hash) VALUES($1,$2,$3)",[Id,Salt,Hash]),
        bright_sql:close(C),
        {ok,Reopened}=bright_db:connect(os:getenv("DATABASE_URL")),
        try ?assertMatch({ok,_,[{Salt,Hash}]},bright_sql:equery(Reopened,"SELECT salt,password_hash FROM bright_credentials WHERE user_id=$1",[Id])),
            ?assertMatch({ok,_,[{Id}]},bright_sql:equery(Reopened,"SELECT id FROM bright_users WHERE email=$1",[Email]))
        after bright_sql:close(Reopened) end
    after
        case is_process_alive(C) of true->bright_sql:close(C);false->ok end
    end.
