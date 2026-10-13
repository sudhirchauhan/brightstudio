-module(bright_media).
-export([enabled/0,capabilities/0,upload/4,list/2,read/2,original/2,retry/4,process_one/0]).
-define(FLAG,"STUDIO_AUDIO_ENABLED").
enabled()->bright_mutation:enabled(?FLAG).
guard(U,F)->bright_mutation:guard(?FLAG,{U,F}).
capabilities()->#{ocr_available=>os:find_executable("tesseract")=/=false,transcription_available=>bright_capture:transcription_available(),max_bytes=>4194304,max_audio_seconds=>120}.
columns()->"id,project_id,title,mime,state,version,attempts,error_code,source_id,revision_id".
item({I,P,T,M,S,V,A,E,Source,R})->#{id=>I,project_id=>P,title=>T,mime=>M,state=>S,version=>V,attempts=>A,error=>E,source_id=>Source,revision_id=>R}.
row(C,U,I)->case bright_sql:equery(C,"SELECT "++columns()++" FROM bright_media_jobs WHERE id=$1 AND owner_id=$2",[I,U]) of {ok,_,[R]}->{ok,item(R)};{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
read(U,I)->guard(U,fun()->case bright_project_auth:uuid(I) of true->bright_sql_pool:with_connection(fun(C)->row(C,U,I) end);false->{error,not_found} end end).
list(U,P)->guard(U,fun()->case bright_project_auth:authorize(U,P) of ok->bright_sql_pool:with_connection(fun(C)->{ok,_,Rows}=bright_sql:equery(C,"SELECT "++columns()++" FROM bright_media_jobs WHERE owner_id=$1 AND project_id=$2 ORDER BY created_at DESC,id LIMIT 100",[U,P]),{ok,#{capabilities=>capabilities(),jobs=>[item(R)||R<-Rows]}} end);E->E end end).
original(U,I)->case read(U,I) of {ok,_}->bright_sql_pool:with_connection(fun(C)->case bright_sql:equery(C,"SELECT mime,original FROM bright_media_jobs WHERE id=$1 AND owner_id=$2",[I,U]) of {ok,_,[{M,B}]}->{ok,#{mime=>M,data=>B}};_->{error,unavailable} end end);E->E end.
valid(#{title:=T,filename:=N,mime:=M,data:=B})->bright_workspace:text(T,200,false) andalso bright_workspace:text(N,255,false) andalso is_binary(B) andalso byte_size(B)>0 andalso byte_size(B)=<4194304 andalso signature(M,B);
valid(_)->false.
signature(<<"image/png">>,<<137,"PNG",13,10,26,10,_/binary>>)->true;
signature(<<"image/jpeg">>,<<255,216,255,_/binary>>)->true;
signature(<<"audio/wav">>,<<"RIFF",_:32,"WAVE",_/binary>>)->true;
signature(<<"audio/webm">>,<<26,69,223,163,_/binary>>)->true;
signature(_,_) ->false.
upload(U,P,K,M)->guard(U,fun()->case valid(M) of false->{error,invalid_input};true->case bright_project_auth:authorize(U,P) of ok->#{title:=Title,filename:=Name,mime:=Mime,data:=Data}=M,
 bright_mutation:run(?FLAG,<<"media">>,U,K,{upload,P,Title,Name,Mime,crypto:hash(sha256,Data)},fun(C)->{ok,_,[{Bytes,N}]}=bright_sql:equery(C,"SELECT COALESCE(sum(octet_length(original)),0)::bigint,count(*) FROM bright_media_jobs WHERE owner_id=$1",[U]),
 case Bytes+byte_size(Data)=<67108864 andalso N<256 of false->{error,quota_exceeded};true->I=bright_project_auth:new_id(),{ok,1}=bright_sql:equery(C,"INSERT INTO bright_media_jobs(id,owner_id,project_id,title,filename,mime,original) VALUES($1,$2,$3,$4,$5,$6,$7)",[I,U,P,string:trim(Title),Name,Mime,Data]),row(C,U,I) end end);E->E end end end).
retry(U,I,K,M) when is_map(M)->case read(U,I) of {ok,_}->V=maps:get(<<"expected_version">>,M,undefined),case bright_mutation:keys(M,[<<"expected_version">>]) andalso bright_workspace:version(V) of false->{error,invalid_input};true->bright_mutation:run(?FLAG,<<"media">>,U,K,{retry,I,M},fun(C)->case bright_sql:equery(C,"UPDATE bright_media_jobs SET state='queued',error_code='',version=version+1 WHERE id=$1 AND owner_id=$2 AND state='failed' AND attempts<3 AND version=$3 RETURNING id",[I,U,V]) of {ok,1,_,[_]}->row(C,U,I);{ok,0,_,[]}->{error,conflict};_->{error,unavailable} end end) end;E->E end;
retry(_,_,_,_)->{error,invalid_input}.
process_one()->global:trans({{bright_native,node()},self()},fun process_locked/0).
process_locked()->case enabled() of false->ok;true->case claim() of {ok,I,U,Lease,M,B}->Result=bright_capture:run(M,B),finish(I,U,Lease,Result);_->ok end end.
claim()->bright_sql_pool:with_connection(fun(C)->bright_sql:with_transaction(C,fun(T)->Now=erlang:system_time(millisecond),
 {ok,_}=bright_sql:equery(T,"UPDATE bright_media_jobs SET state='failed',error_code='worker_interrupted',version=version+1,lease_token=NULL,lease_until_ms=NULL WHERE state='processing' AND lease_until_ms<$1",[Now]),
 case bright_sql:equery(T,"SELECT j.id,j.owner_id,j.mime,j.original FROM bright_media_jobs j JOIN bright_users u ON u.id=j.owner_id WHERE j.state='queued' AND u.disabled_at IS NULL ORDER BY j.created_at,j.id LIMIT 1 FOR UPDATE OF j SKIP LOCKED",[]) of
 {ok,_,[{I,U,M,B}]}->Lease=bright_project_auth:new_id(),case bright_sql:equery(T,"UPDATE bright_media_jobs SET state='processing',version=version+1,attempts=attempts+1,lease_token=$1,lease_until_ms=$2 WHERE id=$3 AND state='queued' AND attempts<3 RETURNING id",[Lease,Now+180000,I]) of {ok,1,_,[_]}->{ok,I,U,Lease,M,B};_->none end;_->none end end) end).
finish(I,U,Lease,{ok,Text})->bright_workspace:transaction(U,fun(C)->Now=erlang:system_time(millisecond),case bright_sql:equery(C,"SELECT project_id,title FROM bright_media_jobs WHERE id=$1 AND owner_id=$2 AND state='processing' AND lease_token=$3 AND lease_until_ms>=$4",[I,U,Lease,Now]) of
 {ok,_,[{P,Title}]}->{ok,_,[{Bytes,N}]}=bright_sql:equery(C,"SELECT COALESCE(sum(octet_length(original)),0)::bigint,count(*) FROM bright_source_revisions WHERE owner_id=$1",[U]),case Bytes+byte_size(Text)=<bright_library:quota_limit() andalso N<256 of
 false->fail(C,I,U,Lease,<<"quota_exceeded">>);true->S=bright_project_auth:new_id(),R=bright_project_auth:new_id(),Hash=crypto:hash(sha256,Text),
 {ok,1}=bright_sql:equery(C,"INSERT INTO bright_sources(id,owner_id,project_id,title,kind,idempotency_key) VALUES($1,$2,$3,$4,'note',$5)",[S,U,P,Title,bright_project_auth:new_id()]),
 {ok,1}=bright_sql:equery(C,"INSERT INTO bright_source_revisions(id,source_id,owner_id,revision,filename,mime,original,sha256,idempotency_key,state,text_content,completed_at) VALUES($1,$2,$3,1,'capture.txt','text/plain',$4,$5,$6,'ready',$7,now())",[R,S,U,Text,Hash,bright_project_auth:new_id(),Text]),
 {ok,1}=bright_sql:equery(C,"UPDATE bright_media_jobs SET state='ready',version=version+1,source_id=$1,revision_id=$2,lease_token=NULL,lease_until_ms=NULL,error_code='' WHERE id=$3 AND owner_id=$4 AND lease_token=$5",[S,R,I,U,Lease]),{ok,#{source_id=>S,revision_id=>R}} end;
 _->{error,conflict} end end);
finish(I,U,Lease,{error,Reason})->bright_sql_pool:with_connection(fun(C)->fail(C,I,U,Lease,atom_to_binary(Reason)) end).
fail(C,I,U,Lease,Reason)->case bright_sql:equery(C,"UPDATE bright_media_jobs SET state='failed',version=version+1,error_code=$1,lease_token=NULL,lease_until_ms=NULL WHERE id=$2 AND owner_id=$3 AND lease_token=$4 AND state='processing'",[Reason,I,U,Lease]) of {ok,1}->{ok,#{failed=>true}};_->{error,conflict} end.
