-module(bright_assistant).
-export([enabled/0,available/0,create/3,read/2,list/2,process_one/0]).
-define(FLAG,"STUDIO_AI_ENABLED").
enabled()->bright_mutation:enabled(?FLAG).
available()->bright_ai_provider:configured().
guard(U,F)->bright_mutation:guard(?FLAG,{U,F}).
item({I,P,Mode,Engine,State,Prompt,J,Failure})->#{id=>I,project_id=>P,mode=>Mode,engine=>Engine,state=>State,prompt=>Prompt,result=>jsx:decode(J,[return_maps]),failure=>Failure}.
columns()->"id,project_id,mode,engine,state,prompt,result_json,failure".
row(C,U,Id)->case bright_sql:equery(C,"SELECT "++columns()++" FROM bright_ai_attempts WHERE id=$1 AND owner_id=$2",[Id,U]) of {ok,_,[R]}->{ok,item(R)};{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
read(U,Id)->guard(U,fun()->case bright_project_auth:uuid(Id) of false->{error,not_found};true->bright_sql_pool:with_connection(fun(C)->row(C,U,Id) end) end end).
list(U,P)->guard(U,fun()->case bright_project_auth:authorize(U,P) of ok->bright_sql_pool:with_connection(fun(C)->{ok,_,Rows}=bright_sql:equery(C,"SELECT "++columns()++" FROM bright_ai_attempts WHERE owner_id=$1 AND project_id=$2 ORDER BY created_at DESC,id LIMIT 100",[U,P]),{ok,#{generated_available=>available(),attempts=>[item(R)||R<-Rows]}} end);E->E end end).
create(U,K,M) when is_map(M)->guard(U,fun()->P=maps:get(<<"project_id">>,M,undefined),Ids=maps:get(<<"evidence_ids">>,M,undefined),Prompt=maps:get(<<"prompt">>,M,undefined),Mode=maps:get(<<"mode">>,M,undefined),Engine=maps:get(<<"engine">>,M,<<"evidence">>),
 Valid=bright_mutation:keys(M,[<<"project_id">>,<<"evidence_ids">>,<<"prompt">>,<<"mode">>,<<"engine">>]) andalso bright_workspace:text(Prompt,2000,false) andalso lists:member(Mode,[<<"explain">>,<<"compare">>,<<"feedback">>]) andalso lists:member(Engine,[<<"evidence">>,<<"generated">>]) andalso is_list(Ids) andalso length(Ids)>=1 andalso length(Ids)=<3 andalso length(lists:usort(Ids))=:=length(Ids) andalso lists:all(fun bright_project_auth:uuid/1,Ids) andalso (Mode=/= <<"compare">> orelse length(Ids)>=2),
 case Valid of false->{error,invalid_input};true->case Engine=:= <<"generated">> andalso not available() of true->{error,not_ready};false->case bright_project_auth:authorize(U,P) of
 ok->bright_mutation:run(?FLAG,<<"assistant">>,U,K,M,fun(C)->case evidence(C,U,P,Ids,[]) of {ok,Cites}->
 {ok,_,[{N}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_ai_attempts WHERE owner_id=$1",[U]),case N<1000 of false->{error,quota_exceeded};true->case reserve(C,U,Engine,Cites,Prompt) of
 ok->Id=bright_project_auth:new_id(),{State,Result}=case Engine of <<"evidence">>->{<<"ready">>,guide(Mode,Cites)};_->{<<"queued">>,#{}} end,
 {ok,1}=bright_sql:equery(C,"INSERT INTO bright_ai_attempts(id,owner_id,project_id,mode,engine,state,prompt,citations_json,result_json) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)",[Id,U,P,Mode,Engine,State,Prompt,jsx:encode(Cites),jsx:encode(Result)]),row(C,U,Id);E->E end end;E->E end end);E->E end end end end);
create(_,_,_)->{error,invalid_input}.
evidence(_,_,_,[],A)->{ok,lists:reverse(A)};
evidence(C,U,P,[Id|Rest],A)->case bright_sql:equery(C,"SELECT e.quote,e.source_id,e.revision_id,r.revision,s.title FROM bright_evidence e JOIN bright_sources s ON s.id=e.source_id AND s.owner_id=e.owner_id JOIN bright_source_revisions r ON r.id=e.revision_id AND r.owner_id=e.owner_id WHERE e.id=$1 AND e.owner_id=$2 AND s.project_id=$3",[Id,U,P]) of
 {ok,_,[{Q,S,R,V,T}]}->evidence(C,U,P,Rest,[#{id=>Id,quote=>Q,source_id=>S,revision_id=>R,revision=>V,title=>T}|A]);{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
guide(Mode,Cites)->#{kind=><<"evidence_guide">>,citations=>Cites,answer=>[#{text=>maps:get(quote,C),citation_ids=>[maps:get(id,C)]}||C<-Cites],reflection=>case Mode of <<"explain">>-><<"Put this quote in your own words. Which part answers your question?">>;<<"compare">>-><<"What do these passages agree on, and where do they differ? Keep each claim linked to its passage.">>;_-><<"Compare your answer with each passage. Mark what the quote supports and what still needs evidence.">> end}.
reserve(_,_,<<"evidence">>,_,_)->ok;
reserve(C,U,_,Cites,Prompt)->
 %% Reserve a conservative input/output allowance before any external work.
 Tokens=byte_size(jsx:encode(#{evidence=>Cites,question=>Prompt}))+4096,Date=integer_to_binary(calendar:date_to_gregorian_days(element(1,calendar:universal_time()))),
 {ok,_,Rows}=bright_sql:equery(C,"SELECT reserved_tokens FROM bright_ai_usage WHERE owner_id=$1 AND usage_day=$2",[U,Date]),Used=case Rows of []->0;[{N}]->N end,
 case Used+Tokens=<20000 of false->{error,quota_exceeded};true->case Rows of []->{ok,1}=bright_sql:equery(C,"INSERT INTO bright_ai_usage(owner_id,usage_day,reserved_tokens) VALUES($1,$2,$3)",[U,Date,Tokens]);_->{ok,1}=bright_sql:equery(C,"UPDATE bright_ai_usage SET reserved_tokens=$1 WHERE owner_id=$2 AND usage_day=$3",[Used+Tokens,U,Date]) end,ok end.
process_one()->global:trans({{bright_native,node()},self()},fun process_locked/0).
process_locked()->case enabled() andalso available() of false->ok;true->case claim() of none->ok;{ok,Id,U,Lease,Prompt,Mode,Cites}->
 Result=bright_ai_provider:answer(Mode,Prompt,Cites),finish(Id,U,Lease,Cites,Result) end end.
claim()->bright_sql_pool:with_connection(fun(C)->bright_sql:with_transaction(C,fun(T)->
 Now=erlang:system_time(millisecond),{ok,_}=bright_sql:equery(T,"UPDATE bright_ai_attempts SET state='failed',failure='interrupted' WHERE state='processing' AND lease_until_ms<$1",[Now]),
 case bright_sql:equery(T,"SELECT a.id,a.owner_id,a.prompt,a.mode,a.citations_json FROM bright_ai_attempts a JOIN bright_users u ON u.id=a.owner_id WHERE a.state='queued' AND u.disabled_at IS NULL ORDER BY a.created_at,a.id LIMIT 1 FOR UPDATE OF a SKIP LOCKED",[]) of
 {ok,_,[]}->none;{ok,_,[{Id,U,P,M,J}]}->Lease=bright_project_auth:new_id(),case bright_sql:equery(T,"UPDATE bright_ai_attempts SET state='processing',lease_token=$1,lease_until_ms=$2 WHERE id=$3 AND state='queued' RETURNING id",[Lease,Now+180000,Id]) of {ok,1,_,[_]}->{ok,Id,U,Lease,P,M,jsx:decode(J,[return_maps])};_->none end;_->none end end) end).
finish(Id,U,Lease,Cites,Result)->bright_sql_pool:with_connection(fun(C)->
 {State,Failure,J}=case Result of {ok,Answer}->{<<"ready">>,<<>>,jsx:encode(#{kind=><<"generated">>,citations=>Cites,answer=>Answer})};{error,Reason}->{<<"failed">>,atom_to_binary(Reason),<<"{}">>} end,
 bright_sql:equery(C,"UPDATE bright_ai_attempts SET state=$1,failure=$2,result_json=$3,lease_token=NULL,lease_until_ms=NULL WHERE id=$4 AND owner_id=$5 AND state='processing' AND lease_token=$6 AND lease_until_ms>=$7 AND EXISTS(SELECT 1 FROM bright_users WHERE id=$5 AND disabled_at IS NULL)",[State,Failure,J,Id,U,Lease,erlang:system_time(millisecond)]) end),ok.
