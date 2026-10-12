-module(bright_sqlite).
-behaviour(gen_server).
-export([start_link/1,init/1,handle_call/3,handle_cast/2,handle_info/2,terminate/2]).

start_link(Path) when Path=/=[],Path=/=":memory:" ->
    case filename:pathtype(Path) of
        absolute->gen_server:start_link(?MODULE,Path,[]);
        _->{error,sqlite_requires_absolute_path}
    end;
start_link(_)->{error,invalid_sqlite_path}.
init(Path)->
    put(bright_sql_backend,sqlite),
    case filelib:ensure_dir(Path) of
        ok->case esqlite3:open(Path) of
            {ok,Db}->
                ok=file:change_mode(Path,8#600),
                ok=esqlite3:exec(Db,"PRAGMA busy_timeout=5000; PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;"),
                {ok,Db};
            _->{stop,sqlite_open_failed}
        end;
        _->{stop,sqlite_directory_failed}
    end.
handle_call({query,Sql0,Args0,Mode},_,Db)->
    Sql=iolist_to_binary(Sql0),
    Args=bind_args(Sql,Args0),
    Translated=translate(Sql),
    Result=case esqlite3:q(Db,Translated,Args) of
        Rows when is_list(Rows)->
            Tuples=[list_to_tuple([case V of undefined->null;_->V end||V<-R])||R<-Rows],
            Select=re:run(Translated,"^\\s*(SELECT|PRAGMA)",[caseless])=/=nomatch,
            Returning=re:run(Translated,"\\bRETURNING\\b",[caseless])=/=nomatch,
            case {Select,Returning,Mode} of
                {true,_,_}->{ok,[],Tuples};
                {_,true,_}->{ok,esqlite3:changes(Db),[],Tuples};
                {_,_,simple}->{ok,[],[]};
                _->{ok,esqlite3:changes(Db)}
            end;
        {error,_}->{error,sqlite_query_failed}
    end,
    {reply,Result,Db}.
handle_cast(_,Db)->{noreply,Db}.
handle_info(_,Db)->{noreply,Db}.
terminate(_,Db)->esqlite3:close(Db).

%% Translate the small SQL dialect used by Bright Studio. All user values
%% remain bound parameters; no user input is interpolated into SQL.
translate(Sql)->
    Steps=[
        {"=ANY\\((\\$[0-9]+)::bigint\\[\\]\\)"," IN (SELECT value FROM json_each(\\1))"},
        {"::(text|uuid|bigint)",""},
        {"FOR UPDATE( OF r)?( SKIP LOCKED)?", ""},
        {"now\\(\\)([+-])interval '([0-9]+) (hours?|seconds?)'","strftime('%Y-%m-%d %H:%M:%f','now','\\1\\2 \\3')"},
        {"now\\(\\)","strftime('%Y-%m-%d %H:%M:%f','now')"},
        {"octet_length\\(([^()]+)\\)","length(CAST(\\1 AS BLOB))"},
        {"\\$([0-9]+)","?\\1"},
        {"UPDATE bright_source_revisions r SET", "UPDATE bright_source_revisions AS r SET"},
        {"RETURNING r.id,r.source_id,r.owner_id", "RETURNING id,source_id,owner_id"}
    ],
    lists:foldl(fun({Pattern,Replacement},S)->re:replace(S,Pattern,Replacement,[global,{return,binary}]) end,Sql,Steps).

bind_args(Sql,Args)->
    BlobIndexes=blob_indexes(Sql),
    [case lists:member(I,BlobIndexes) of
        true when is_binary(V)->{blob,V};
        _ when is_list(V)->jsx:encode(V);
        _->V
    end || {I,V}<-lists:zip(lists:seq(1,length(Args)),Args)].
blob_indexes(Sql)->
    Blob="(?:token_hash|salt|password_hash|original|sha256|text_sha256|request_hash)",
    Where=case re:run(Sql,Blob++"\\s*=\\s*\\$([0-9]+)",[global,{capture,[1],list}]) of
        {match,Ms}->[list_to_integer(N)||[N]<-Ms];nomatch->[] end,
    Insert=case re:run(Sql,"INSERT INTO [a-z_]+\\(([^)]+)\\) VALUES\\(([^)]+)\\)",[{capture,[1,2],list}]) of
        {match,[Columns,Values]}->
            Pairs=lists:zip(string:split(Columns,",",all),string:split(Values,",",all)),
            [list_to_integer(N)||{Col,Value}<-Pairs,
                re:run(string:trim(Col),"^"++Blob++"$")=/=nomatch,
                {match,[N]}<-[re:run(string:trim(Value),"^\\$([0-9]+)$",[{capture,[1],list}])]];
        nomatch->[]
    end,
    Where++Insert.
