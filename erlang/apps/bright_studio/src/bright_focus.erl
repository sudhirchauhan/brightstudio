-module(bright_focus).
-export([enabled/0,targets/2,start/3,read/2,list/2,act/4]).
enabled()->os:getenv("STUDIO_HUB_ENABLED")=:= "true" andalso os:getenv("STUDIO_FOCUS_ENABLED")=:= "true".
guard(U,F)->case enabled() of false->{error,disabled};true->case bright_identity:profile(U) of {ok,_}->F();E->E end end.
keys(M,Allowed)->is_map(M) andalso lists:all(fun(K)->lists:member(K,Allowed) end,maps:keys(M)).
key(K)->is_binary(K) andalso re:run(K,<<"^[!-~]{16,128}$">>,[{capture,none}])=:=match.
text(B,Min)->bright_workspace:text(B,2000,false) andalso length(unicode:characters_to_list(string:trim(B)))>=Min.
nullable_id(null)->true;nullable_id(B)->bright_project_auth:uuid(B).
columns()->"id,project_id,task_id,source_id,revision_id,target_title,source_revision,duration_ms,elapsed_ms,running_since_ms,state,checkpoint_count,summary,version,finished_at_ms".
raw({Id,P,T,S,R,Title,Rev,D,E,Since,State,N,Summary,V,Finished})->
    #{id=>Id,project_id=>P,task_id=>T,source_id=>S,revision_id=>R,target_title=>Title,revision=>Rev,duration_ms=>D,elapsed_ms=>E,running_since_ms=>Since,state=>State,checkpoint_count=>N,summary=>Summary,version=>V,finished_at_ms=>Finished}.
elapsed(#{state:= <<"active">>,elapsed_ms:=E,running_since_ms:=Since,duration_ms:=D},Now)->min(D,E+max(0,Now-Since));
elapsed(#{elapsed_ms:=E},_)->E.
row(C,U,Id)->case bright_sql:equery(C,"SELECT "++columns()++" FROM bright_focus_sessions WHERE id=$1 AND owner_id=$2",[Id,U]) of
    {ok,_,[R]}->{ok,raw(R)};{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
public(M)->Now=erlang:system_time(millisecond),(maps:remove(running_since_ms,M))#{elapsed_ms=>elapsed(M,Now),server_now_ms=>Now}.
item(C,U,M)->
    {ok,_,Rows}=bright_sql:equery(C,"SELECT c.ordinal,c.note,c.evidence_id,c.elapsed_ms,c.created_at_ms,e.quote,e.source_id,e.revision_id FROM bright_focus_checkpoints c LEFT JOIN bright_evidence e ON e.id=c.evidence_id AND e.owner_id=c.owner_id WHERE c.session_id=$1 AND c.owner_id=$2 ORDER BY c.ordinal",[maps:get(id,M),U]),
    Checkpoints=[#{ordinal=>N,note=>Note,evidence_id=>E,elapsed_ms=>Time,created_at_ms=>At,quote=>Q,source_id=>S,revision_id=>R}||{N,Note,E,Time,At,Q,S,R}<-Rows],
    Options=case maps:get(state,M) of
        State when State=:= <<"active">>;State=:= <<"paused">>->
            {ok,_,Evidence}=bright_sql:equery(C,"SELECT e.id,e.quote,e.source_id,e.revision_id,r.revision,s.title FROM bright_evidence e JOIN bright_sources s ON s.id=e.source_id AND s.owner_id=e.owner_id JOIN bright_source_revisions r ON r.id=e.revision_id AND r.owner_id=e.owner_id WHERE e.owner_id=$1 AND s.project_id=$2 AND ($3::uuid IS NULL OR (e.source_id=$3 AND e.revision_id=$4)) ORDER BY e.created_at DESC,e.id LIMIT 100",[U,maps:get(project_id,M),maps:get(source_id,M),maps:get(revision_id,M)]),
            [#{id=>Id,quote=>Q,source_id=>S,revision_id=>R,revision=>Rev,title=>Title}||{Id,Q,S,R,Rev,Title}<-Evidence];
        _->[] end,
    (public(M))#{checkpoints=>Checkpoints,evidence_options=>Options}.
read_sql(C,U,Id)->case row(C,U,Id) of {ok,M}->{ok,item(C,U,M)};E->E end.
read(U,Id)->guard(U,fun()->case bright_project_auth:uuid(Id) of false->{error,not_found};true->bright_sql_pool:with_connection(fun(C)->read_sql(C,U,Id) end) end end).
list(U,P)->guard(U,fun()->case bright_project_auth:authorize(U,P) of
    ok->bright_sql_pool:with_connection(fun(C)->
        {ok,_,Rows}=bright_sql:equery(C,"SELECT "++columns()++" FROM bright_focus_sessions WHERE owner_id=$1 AND project_id=$2 ORDER BY created_at DESC,id LIMIT 100",[U,P]),
        {ok,_,Current}=bright_sql:equery(C,"SELECT "++columns()++" FROM bright_focus_sessions WHERE owner_id=$1 AND state IN ('active','paused')",[U]),
        {ok,#{sessions=>[public(raw(R))||R<-Rows],current=>case Current of []->null;[R]->public(raw(R)) end}}
    end);
    E->E end end).
targets(U,P)->guard(U,fun()->case bright_project_auth:authorize(U,P) of
    ok->bright_sql_pool:with_connection(fun(C)->
        {ok,_,Tasks}=bright_sql:equery(C,"SELECT id,title FROM bright_tasks WHERE owner_id=$1 AND project_id=$2 ORDER BY created_at DESC,id LIMIT 1000",[U,P]),
        {ok,_,Sources}=bright_sql:equery(C,"SELECT s.id,s.title,r.id,r.revision FROM bright_sources s JOIN bright_source_revisions r ON r.source_id=s.id AND r.owner_id=s.owner_id WHERE s.owner_id=$1 AND s.project_id=$2 AND r.state='ready' ORDER BY s.created_at DESC,s.id,r.revision DESC LIMIT 512",[U,P]),
        {ok,#{tasks=>[#{task_id=>Id,title=>Title}||{Id,Title}<-Tasks],sources=>[#{source_id=>Id,title=>Title,revision_id=>R,revision=>V}||{Id,Title,R,V}<-Sources]}}
    end);E->E end end).
mutate(U,Op,K,Payload,F)->guard(U,fun()->case key(K) of
    false->{error,invalid_input};true->Hash=crypto:hash(sha256,term_to_binary({Op,Payload})),
        bright_workspace:transaction(U,fun(C)->case bright_sql:equery(C,"SELECT request_hash,response_json FROM bright_focus_receipts WHERE owner_id=$1 AND idempotency_key=$2",[U,K]) of
            {ok,_,[{Hash,Json}]}->{ok,jsx:decode(Json,[return_maps])};
            {ok,_,[_]}->{error,conflict};
            {ok,_,[]}->{ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_focus_receipts WHERE owner_id=$1",[U]),
                case Count<10000 of false->{error,quota_exceeded};true->case F(C) of
                    {ok,Value}->Json=jsx:encode(Value),{ok,1}=bright_sql:equery(C,"INSERT INTO bright_focus_receipts(owner_id,idempotency_key,request_hash,response_json) VALUES($1,$2,$3,$4)",[U,K,Hash,Json]),{ok,jsx:decode(Json,[return_maps])};
                    E->E end end;
            _->{error,unavailable} end end)
    end end).
start(U,K,M) when is_map(M)->guard(U,fun()->
    P=maps:get(<<"project_id">>,M,undefined),T=maps:get(<<"task_id">>,M,null),S=maps:get(<<"source_id">>,M,null),R=maps:get(<<"revision_id">>,M,null),Minutes=maps:get(<<"minutes">>,M,25),
    Valid=keys(M,[<<"project_id">>,<<"task_id">>,<<"source_id">>,<<"revision_id">>,<<"minutes">>]) andalso bright_project_auth:uuid(P) andalso nullable_id(T) andalso nullable_id(S) andalso nullable_id(R)
        andalso ((T=/=null andalso S=:=null andalso R=:=null) orelse (T=:=null andalso S=/=null andalso R=/=null)) andalso is_integer(Minutes) andalso Minutes>=1 andalso Minutes=<120,
    case Valid of false->{error,invalid_input};true->case bright_project_auth:authorize(U,P) of
        ok->mutate(U,start,K,{P,T,S,R,Minutes},fun(C)->case target(C,U,P,T,S,R) of
            {ok,Title,Rev}->{ok,_,Open}=bright_sql:equery(C,"SELECT id FROM bright_focus_sessions WHERE owner_id=$1 AND state IN ('active','paused')",[U]),
                {ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_focus_sessions WHERE owner_id=$1",[U]),
                case {Open,Count<1000} of
                    {[],true}->Id=bright_project_auth:new_id(),Now=erlang:system_time(millisecond),
                        {ok,1}=bright_sql:equery(C,"INSERT INTO bright_focus_sessions(id,owner_id,project_id,task_id,source_id,revision_id,target_title,source_revision,duration_ms,running_since_ms) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)",[Id,U,P,T,S,R,Title,Rev,Minutes*60000,Now]),read_sql(C,U,Id);
                    {[],false}->{error,quota_exceeded};_->{error,conflict} end;
            E->E end end);
        E->E end end end);
start(_,_,_)->{error,invalid_input}.
target(C,U,P,T,null,null)->case bright_sql:equery(C,"SELECT title FROM bright_tasks WHERE id=$1 AND owner_id=$2 AND project_id=$3",[T,U,P]) of
    {ok,_,[{Title}]}->{ok,Title,null};{ok,_,[]}->{error,not_found};_->{error,unavailable} end;
target(C,U,P,null,S,R)->case bright_sql:equery(C,"SELECT s.title,r.revision,r.state FROM bright_sources s JOIN bright_source_revisions r ON r.source_id=s.id AND r.owner_id=s.owner_id WHERE s.id=$1 AND s.owner_id=$2 AND s.project_id=$3 AND r.id=$4",[S,U,P,R]) of
    {ok,_,[{Title,Rev,<<"ready">>}]}->{ok,Title,Rev};{ok,_,[_]}->{error,not_ready};{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
act(U,Id,K,M) when is_map(M)->case read(U,Id) of
    {ok,_}->V=maps:get(<<"expected_version">>,M,undefined),A=maps:get(<<"action">>,M,undefined),
        case valid_action(M,A) andalso bright_workspace:version(V) of
            false->{error,invalid_input};true->mutate(U,{act,Id},K,M,fun(C)->case row(C,U,Id) of
                {ok,#{version:=V}=Session}->transition(C,U,Session,A,M);{ok,_}->{error,conflict};E->E end end) end;
    E->E end;
act(_,_,_,_)->{error,invalid_input}.
valid_action(M,<<"checkpoint">>)->keys(M,[<<"action">>,<<"expected_version">>,<<"expected_checkpoint">>,<<"note">>,<<"evidence_id">>]) andalso text(maps:get(<<"note">>,M,undefined),10) andalso nullable_id(maps:get(<<"evidence_id">>,M,null)) andalso is_integer(maps:get(<<"expected_checkpoint">>,M,undefined));
valid_action(M,<<"complete">>)->keys(M,[<<"action">>,<<"expected_version">>,<<"summary">>]) andalso text(maps:get(<<"summary">>,M,undefined),20);
valid_action(M,A)->lists:member(A,[<<"pause">>,<<"resume">>,<<"cancel">>]) andalso keys(M,[<<"action">>,<<"expected_version">>]).
transition(C,U,#{id:=Id,state:=State,checkpoint_count:=N}=S,<<"checkpoint">>,M) when State=:= <<"active">>;State=:= <<"paused">>->
    case maps:get(<<"expected_checkpoint">>,M)=:=N andalso N<20 of
        false->{error,conflict};true->E=maps:get(<<"evidence_id">>,M,null),case evidence(C,U,S,E) of
            ok->Now=erlang:system_time(millisecond),Time=elapsed(S,Now),
                {ok,1}=bright_sql:equery(C,"INSERT INTO bright_focus_checkpoints(session_id,owner_id,ordinal,note,evidence_id,elapsed_ms,created_at_ms) VALUES($1,$2,$3,$4,$5,$6,$7)",[Id,U,N+1,string:trim(maps:get(<<"note">>,M)),E,Time,Now]),
                update(C,U,S,State,Time,case State of <<"active">>->Now;_->null end,N+1,<<>>,null);
            Error->Error end end;
transition(C,U,#{state:= <<"active">>}=S,<<"pause">>,_)->update(C,U,S,<<"paused">>,elapsed(S,erlang:system_time(millisecond)),null,maps:get(checkpoint_count,S),<<>>,null);
transition(C,U,#{state:= <<"paused">>}=S,<<"resume">>,_)->update(C,U,S,<<"active">>,maps:get(elapsed_ms,S),erlang:system_time(millisecond),maps:get(checkpoint_count,S),<<>>,null);
transition(C,U,#{state:=State}=S,<<"cancel">>,_) when State=:= <<"active">>;State=:= <<"paused">>->
    Now=erlang:system_time(millisecond),update(C,U,S,<<"cancelled">>,elapsed(S,Now),null,maps:get(checkpoint_count,S),<<>>,Now);
transition(C,U,#{state:=State,duration_ms:=D,checkpoint_count:=N}=S,<<"complete">>,M) when State=:= <<"active">>;State=:= <<"paused">>->
    Now=erlang:system_time(millisecond),case elapsed(S,Now)>=D andalso N>=1 of
        true->update(C,U,S,<<"completed">>,D,null,N,string:trim(maps:get(<<"summary">>,M)),Now);false->{error,not_ready} end;
transition(_,_,_,_,_)->{error,conflict}.
evidence(_,_,_,null)->ok;
evidence(C,U,#{source_id:=Source,revision_id:=Revision,project_id:=P},Id)->
    case bright_sql:equery(C,"SELECT e.source_id,e.revision_id,s.project_id FROM bright_evidence e JOIN bright_sources s ON s.id=e.source_id AND s.owner_id=e.owner_id WHERE e.id=$1 AND e.owner_id=$2",[Id,U]) of
        {ok,_,[{Source,Revision,_}]} when Source=/=null->ok;
        {ok,_,[{_,_,P}]} when Source=:=null->ok;
        {ok,_,[_]}->{error,conflict};{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
update(C,U,#{id:=Id,version:=V},State,Time,Since,N,Summary,Finished)->
    case bright_sql:equery(C,"UPDATE bright_focus_sessions SET state=$1,elapsed_ms=$2,running_since_ms=$3,checkpoint_count=$4,summary=$5,finished_at_ms=$6,version=version+1 WHERE id=$7 AND owner_id=$8 AND version=$9 RETURNING version",[State,Time,Since,N,Summary,Finished,Id,U,V]) of
        {ok,1,_,[_]}->read_sql(C,U,Id);{ok,0,_,[]}->{error,conflict};_->{error,unavailable} end.
