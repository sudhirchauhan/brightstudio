-module(bright_workspace).
-export([enabled/0,guard/2,transaction/2,mutate/5,text/3,version/1,projects/1,project/2,create_project/3,edit_project/4]).
enabled()->os:getenv("STUDIO_HUB_ENABLED")=:= "true" andalso os:getenv("STUDIO_WORKSPACE_ENABLED")=:= "true".
guard(U,F)->case enabled() of false->{error,disabled};true->case bright_identity:profile(U) of {ok,_}->F();E->E end end.
text(B,Max,Empty) when is_binary(B),byte_size(B)=<Max*4 ->
    case unicode:characters_to_list(B) of
        L when is_list(L),length(L)=<Max->(Empty orelse string:trim(B)=/= <<>>) andalso lists:all(fun(C)->C>=32 orelse lists:member(C,[9,10,13]) end,L);
        _->false end;
text(_,_,_)->false.
version(V)->is_integer(V) andalso V>0 andalso V<2147483647.
transaction(U,F)->bright_sql_pool:with_connection(fun(C)->
    R=bright_sql:with_transaction(C,fun(T)->case bright_sql:equery(T,"SELECT id FROM bright_users WHERE id=$1 AND disabled_at IS NULL FOR UPDATE",[U]) of
        {ok,_,[_]}->case F(T) of {error,Reason}->throw({workspace_abort,Reason});Value->Value end;{ok,_,[]}->{error,unauthenticated};_->{error,unavailable} end end),
    case R of {ok,_}->R;{error,_}->R;{rollback,{workspace_abort,Reason}}->{error,Reason};_->{error,unavailable} end
end).
mutate(U,Operation,K,Payload,F)->guard(U,fun()->
    case is_binary(K) andalso re:run(K,<<"^[!-~]{16,128}$">>,[{capture,none}])=:=match of
        false->{error,invalid_input};true->Hash=crypto:hash(sha256,term_to_binary({Operation,Payload})),
            transaction(U,fun(C)->case bright_sql:equery(C,"SELECT request_hash,response_json FROM bright_workspace_receipts WHERE owner_id=$1 AND idempotency_key=$2",[U,K]) of
                {ok,_,[{Hash,Json}]}->{ok,jsx:decode(Json,[return_maps])};
                {ok,_,[_]}->{error,conflict};
                {ok,_,[]}->{ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_workspace_receipts WHERE owner_id=$1",[U]),
                    case Count<10000 of false->{error,quota_exceeded};true->case F(C) of
                        {ok,Value}->Json=jsx:encode(Value),
                            {ok,1}=bright_sql:equery(C,"INSERT INTO bright_workspace_receipts(owner_id,idempotency_key,request_hash,response_json) VALUES($1,$2,$3,$4)",[U,K,Hash,Json]),
                            {ok,jsx:decode(Json,[return_maps])};
                        E->E end end;
                _->{error,unavailable} end end)
    end end).
project_item({Id,Title,V})->#{id=>Id,title=>Title,version=>V}.
projects(U)->guard(U,fun()->bright_sql_pool:with_connection(fun(C)->case bright_sql:equery(C,"SELECT id,title,version FROM bright_projects WHERE owner_id=$1 ORDER BY created_at,id LIMIT 100",[U]) of
    {ok,_,Rows}->{ok,[project_item(R)||R<-Rows]};_->{error,unavailable} end end) end).
project_sql(C,U,Id)->case bright_sql:equery(C,"SELECT id,title,version FROM bright_projects WHERE id=$1 AND owner_id=$2",[Id,U]) of
    {ok,_,[R]}->{ok,project_item(R)};{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
project(U,Id)->guard(U,fun()->case bright_project_auth:uuid(Id) of false->{error,not_found};true->bright_sql_pool:with_connection(fun(C)->project_sql(C,U,Id) end) end end).
create_project(U,K,M) when is_map(M)->
    Title=maps:get(<<"title">>,M,undefined),case text(Title,200,false) of
        false->{error,invalid_input};true->Clean=string:trim(Title),mutate(U,create_project,K,Clean,fun(C)->
            {ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_projects WHERE owner_id=$1",[U]),
            case Count<100 of false->{error,quota_exceeded};true->Id=bright_project_auth:new_id(),
                {ok,1}=bright_sql:equery(C,"INSERT INTO bright_projects(id,owner_id,title) VALUES($1,$2,$3)",[Id,U,Clean]),project_sql(C,U,Id) end end)
    end;
create_project(_,_,_)->{error,invalid_input}.
edit_project(U,Id,K,M) when is_map(M)->case project(U,Id) of
    {ok,_}->Title=maps:get(<<"title">>,M,undefined),V=maps:get(<<"expected_version">>,M,undefined),
        case text(Title,200,false) andalso version(V) of false->{error,invalid_input};true->Clean=string:trim(Title),
            mutate(U,{edit_project,Id},K,{V,Clean},fun(C)->case bright_sql:equery(C,"UPDATE bright_projects SET title=$1,version=version+1 WHERE id=$2 AND owner_id=$3 AND version=$4 RETURNING version",[Clean,Id,U,V]) of
                {ok,1,_,[_]}->project_sql(C,U,Id);{ok,0,_,[]}->{error,conflict};_->{error,unavailable} end end)
        end;
    E->E end;
edit_project(_,_,_,_)->{error,invalid_input}.
