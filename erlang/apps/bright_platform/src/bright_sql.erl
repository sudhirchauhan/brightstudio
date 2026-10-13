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
        {ok,[],[]}=begin_sqlite(C,erlang:monotonic_time(millisecond)+5000),
        R=F(C),
        {ok,[],[]}=squery(C,"COMMIT"),R
    catch _:Reason -> squery(C,"ROLLBACK"),{rollback,Reason} end
end.

%% Yield between lock attempts; a long native busy wait can starve the writer
%% whose Erlang transaction needs a scheduler to commit. Only BEGIN is retried.
begin_sqlite(C,Deadline)->case squery(C,"BEGIN IMMEDIATE") of
 {error,sqlite_busy}=E->case erlang:monotonic_time(millisecond)<Deadline of true->timer:sleep(10),begin_sqlite(C,Deadline);false->E end;R->R end.
