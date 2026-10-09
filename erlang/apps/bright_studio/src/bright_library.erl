-module(bright_library).
-export([enabled/0, validate_upload/1, upload/4, revisions/2, original/3, content/3, retry/3,
         claim/0, finish/3, quota_limit/0, states/2]).
-define(MAX_FILE,4194304).
-define(MAX_TEXT,2097152).
enabled() -> os:getenv("STUDIO_HUB_ENABLED") =:= "true" andalso os:getenv("STUDIO_LIBRARY_ENABLED") =:= "true".
quota_limit() ->
    case application:get_env(bright_studio,owner_upload_quota,67108864) of
        N when is_integer(N), N>0, N=<67108864 -> N;
        _ -> 67108864
    end.
validate_upload(#{filename:=Name,mime:=Mime,data:=Data}=Upload) when is_binary(Name),is_binary(Mime),is_binary(Data),
     byte_size(Name)>0,byte_size(Name)=<1020,byte_size(Data)>0,byte_size(Data)=<?MAX_FILE ->
    GoodName = case unicode:characters_to_list(Name) of
        Chars when is_list(Chars),length(Chars)=<255 -> lists:all(fun(C)->C>=32 andalso C=/=127 end,Chars);
        _ -> false
    end,
    GoodType = case {Mime,Data} of
        {<<"text/plain">>,_} -> true;
        {<<"application/pdf">>,<<"%PDF-",_/binary>>} -> true;
        {<<"application/epub+zip">>,<<"PK",_/binary>>} -> true;
        _ -> false
    end,
    case GoodName andalso GoodType of true -> {ok,Upload}; false -> {error,invalid_input} end;
validate_upload(_) -> {error,invalid_input}.
upload(User,Source,Key,Upload) ->
    with_source(User,Source,fun() ->
        ValidKey = is_binary(Key) andalso byte_size(Key)>=16 andalso byte_size(Key)=<128 andalso
                   re:run(Key,<<"^[!-~]{16,128}$">>,[{capture,none}]) =:= match,
        case {ValidKey,validate_upload(Upload)} of
            {true,{ok,Valid}} -> store(User,Source,Key,Valid);
            _ -> {error,invalid_input}
        end
    end).
store(User,Source,Key,#{filename:=Name,mime:=Mime,data:=Data}) ->
    Hash = crypto:hash(sha256,Data),
    bright_sql_pool:with_connection(fun(C) ->
        Result = epgsql:with_transaction(C,fun(T) ->
            %% Serialize an owner's quota, revision numbers and upload key checks together.
            case epgsql:equery(T,"SELECT id FROM bright_users WHERE id=$1 AND disabled_at IS NULL FOR UPDATE",[User]) of
                {ok,_,[_]} ->
                    case epgsql:equery(T,"SELECT source_id,filename,mime,sha256,id,revision,state,error_code FROM bright_source_revisions WHERE owner_id=$1 AND idempotency_key=$2",[User,Key]) of
                        {ok,_,[{Source,Name,Mime,Hash,Id,Version,State,Error}]} ->
                            {ok,revision_map(Id,Version,State,Error,Name,Mime,Hash)};
                        {ok,_,[_]} -> {error,conflict};
                        {ok,_,[]} -> insert_revision(T,User,Source,Key,Name,Mime,Data,Hash);
                        _ -> {error,unavailable}
                    end;
                {ok,_,[]} -> {error,not_found};
                _ -> {error,unavailable}
            end
        end),
        case Result of {ok,_} -> Result; {error,_} -> Result; _ -> {error,unavailable} end
    end).
insert_revision(C,User,Source,Key,Name,Mime,Data,Hash) ->
    {ok,_,[{Bytes,Count}]} = epgsql:equery(C,"SELECT COALESCE(sum(octet_length(original)),0)::bigint,count(*) FROM bright_source_revisions WHERE owner_id=$1",[User]),
    case Bytes+byte_size(Data)=<quota_limit() andalso Count<256 of
        false -> {error,quota_exceeded};
        true ->
            {ok,_,[{Version}]} = epgsql:equery(C,"SELECT COALESCE(max(revision),0)+1 FROM bright_source_revisions WHERE source_id=$1",[Source]),
            Id = bright_project_auth:new_id(),
            {ok,1} = epgsql:equery(C,"INSERT INTO bright_source_revisions(id,source_id,owner_id,revision,filename,mime,original,sha256,idempotency_key) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)",[Id,Source,User,Version,Name,Mime,Data,Hash,Key]),
            {ok,revision_map(Id,Version,<<"queued">>,null,Name,Mime,Hash)}
    end.
revisions(User,Source) -> with_source(User,Source,fun() ->
    bright_sql_pool:with_connection(fun(C)->
        case epgsql:equery(C,"SELECT id,revision,state,error_code,filename,mime,sha256 FROM bright_source_revisions WHERE source_id=$1 AND owner_id=$2 ORDER BY revision DESC LIMIT 256",[Source,User]) of
            {ok,_,Rows} -> {ok,[revision_map(Id,V,S,E,N,M,H) || {Id,V,S,E,N,M,H}<-Rows]};
            _ -> {error,unavailable}
        end
    end)
end).
original(User,Source,Revision) -> with_revision(User,Source,Revision,fun(C)->
    case epgsql:equery(C,"SELECT mime,original FROM bright_source_revisions WHERE id=$1 AND source_id=$2 AND owner_id=$3",[Revision,Source,User]) of
        {ok,_,[{Mime,Data}]} -> {ok,#{mime=>Mime,data=>Data}};
        {ok,_,[]} -> {error,not_found}; _ -> {error,unavailable}
    end
end).
content(User,Source,Revision) -> with_revision(User,Source,Revision,fun(C)->
    case epgsql:equery(C,"SELECT state,text_content FROM bright_source_revisions WHERE id=$1 AND source_id=$2 AND owner_id=$3",[Revision,Source,User]) of
        {ok,_,[{<<"ready">>,Text}]} -> {ok,#{revision_id=>Revision,text=>Text}};
        {ok,_,[_]} -> {error,not_ready};
        {ok,_,[]} -> {error,not_found}; _ -> {error,unavailable}
    end
end).
retry(User,Source,Revision) -> with_revision(User,Source,Revision,fun(C)->
    case epgsql:equery(C,"UPDATE bright_source_revisions SET state='queued',attempts=0,error_code=NULL,lease_token=NULL,lease_until=NULL WHERE id=$1 AND source_id=$2 AND owner_id=$3 AND state='failed'",[Revision,Source,User]) of
        {ok,1} -> {ok,#{state=><<"queued">>}};
        {ok,0} ->
            case epgsql:equery(C,"SELECT id FROM bright_source_revisions WHERE id=$1 AND source_id=$2 AND owner_id=$3",[Revision,Source,User]) of
                {ok,_,[]} -> {error,not_found}; {ok,_,[_]} -> {error,conflict}; _ -> {error,unavailable}
            end;
        _ -> {error,unavailable}
    end
end).
with_source(User,Source,Fun) ->
    case enabled() of
        false -> {error,disabled};
        true -> case bright_identity:profile(User) of
            {ok,_}->case bright_source:read(User,Source) of {ok,_}->Fun(); Error->Error end;
            Error->Error
        end
    end.
with_revision(User,Source,Revision,Fun) ->
    with_source(User,Source,fun()->
        case bright_project_auth:uuid(Revision) of
            true -> bright_sql_pool:with_connection(Fun);
            false -> {error,not_found}
        end
    end).
revision_map(Id,V,S,E,N,M,H) -> #{id=>Id,revision=>V,state=>S,error=>E,filename=>N,mime=>M,sha256=>binary:encode_hex(H,lowercase)}.
claim() ->
    case enabled() of
        false -> {error,disabled};
        true -> bright_sql_pool:with_connection(fun(C)->
            epgsql:equery(C,"UPDATE bright_source_revisions SET state='failed',error_code='worker_unavailable',lease_token=NULL,lease_until=NULL WHERE state='processing' AND lease_until<now() AND attempts>=3",[]),
            Token = bright_project_auth:new_id(),
            Sql = "WITH candidate AS (SELECT r.id FROM bright_source_revisions r JOIN bright_users u ON u.id=r.owner_id WHERE u.disabled_at IS NULL AND r.attempts<3 AND (r.state='queued' OR (r.state='processing' AND r.lease_until<now())) ORDER BY r.created_at FOR UPDATE OF r SKIP LOCKED LIMIT 1) UPDATE bright_source_revisions r SET state='processing',attempts=r.attempts+1,lease_token=$1,lease_until=now()+interval '30 seconds',error_code=NULL FROM candidate c WHERE r.id=c.id RETURNING r.id,r.source_id,r.owner_id",
            case epgsql:equery(C,Sql,[Token]) of
                {ok,1,_,[{Id,Source,User}]} -> {ok,#{id=>Id,source_id=>Source,owner_id=>User,lease_token=>Token}};
                {ok,0,_,[]} -> empty;
                _ -> {error,unavailable}
            end
        end)
    end.
finish(#{id:=Id,owner_id:=User,lease_token:=Token},State,Value) ->
    case enabled() of
        false -> {error,disabled};
        true ->
            {Text,Error} = case {State,Value} of
                {ready,T} when is_binary(T),byte_size(T)>0,byte_size(T)=<?MAX_TEXT -> {T,null};
                {failed,E} when is_binary(E) -> {null,E}
            end,
            bright_sql_pool:with_connection(fun(C)->
                case epgsql:equery(C,"UPDATE bright_source_revisions SET state=$1,text_content=$2,error_code=$3,completed_at=now(),lease_token=NULL,lease_until=NULL WHERE id=$4 AND lease_token=$5 AND state='processing' AND lease_until>now() AND EXISTS (SELECT 1 FROM bright_users WHERE id=$6 AND disabled_at IS NULL)",[atom_to_binary(State),Text,Error,Id,Token,User]) of
                    {ok,1} -> ok;
                    {ok,0} -> {error,stale_lease};
                    _ -> {error,unavailable}
                end
            end)
    end.

states(User,Project) ->
    case enabled() of
        false->{error,disabled};
        true->case bright_project_auth:authorize(User,Project) of
            ok->bright_sql_pool:with_connection(fun(C)->
                case epgsql:equery(C,"SELECT DISTINCT ON(r.source_id) r.source_id,r.id,r.revision,r.state FROM bright_source_revisions r JOIN bright_sources s ON s.id=r.source_id WHERE r.owner_id=$1 AND s.project_id=$2 ORDER BY r.source_id,r.revision DESC",[User,Project]) of
                    {ok,_,Rows}->{ok,[#{source_id=>S,revision_id=>Id,revision=>V,state=>State} || {S,Id,V,State}<-Rows]};
                    _->{error,unavailable}
                end
            end);
            Error->Error
        end
    end.
