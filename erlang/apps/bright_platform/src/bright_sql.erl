-module(bright_sql).
-export([equery/3,squery/2,with_transaction/2,close/1,sqlite/1]).

sqlite(C) ->
    case process_info(C,dictionary) of
        {dictionary,D}->proplists:get_value(bright_sql_backend,D)=:=sqlite;
        _->false
    end.
equery(C,Sql,Args)->case sqlite(C) of
    true->gen_server:call(C,{query,Sql,Args,extended},15000);
    false->epgsql:equery(C,Sql,Args)
end.
squery(C,Sql)->case sqlite(C) of
    true->gen_server:call(C,{query,Sql,[],simple},15000);
    false->epgsql:squery(C,Sql)
end.
close(C)->case sqlite(C) of true->gen_server:stop(C);false->epgsql:close(C) end.
with_transaction(C,F)->case sqlite(C) of
    false->epgsql:with_transaction(C,F);
    true->try
        {ok,[],[]}=squery(C,"BEGIN IMMEDIATE"),
        R=F(C),
        {ok,[],[]}=squery(C,"COMMIT"),R
    catch _:Reason -> squery(C,"ROLLBACK"),{rollback,Reason} end
end.
