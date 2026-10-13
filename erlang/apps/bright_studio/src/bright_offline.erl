-module(bright_offline).
-export([enabled/0,targets/2,create/3,read/2,list/2,revoke/3,sync/4]).
-define(FLAG,"STUDIO_OFFLINE_ENABLED").
enabled()->bright_mutation:enabled(?FLAG).
guard(U,F)->bright_mutation:guard(?FLAG,{U,F}).
targets(U,P)->guard(U,fun()->case bright_project_auth:authorize(U,P) of ok->bright_sql_pool:with_connection(fun(C)->
 {ok,_,S}=bright_sql:equery(C,"SELECT r.id,s.title,r.revision FROM bright_source_revisions r JOIN bright_sources s ON s.id=r.source_id AND s.owner_id=r.owner_id WHERE s.project_id=$1 AND r.owner_id=$2 AND r.state='ready' ORDER BY s.created_at DESC,r.revision DESC LIMIT 100",[P,U]),
 {ok,_,D}=bright_sql:equery(C,"SELECT id,title,version FROM bright_documents WHERE project_id=$1 AND owner_id=$2 ORDER BY created_at DESC,id LIMIT 100",[P,U]),{ok,#{sources=>[#{id=>I,title=>T,revision=>V}||{I,T,V}<-S],documents=>[#{id=>I,title=>T,version=>V}||{I,T,V}<-D]}} end);E->E end end).
row(C,U,I)->case bright_sql:equery(C,"SELECT payload_json,expires_at_ms,revoked FROM bright_offline_packages WHERE id=$1 AND owner_id=$2",[I,U]) of
 {ok,_,[{J,Expires,0}]}->case Expires>erlang:system_time(millisecond) of true->{ok,jsx:decode(J,[return_maps])};false->{error,not_ready} end;
 {ok,_,[_]}->{error,not_ready};{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
read(U,I)->guard(U,fun()->case bright_project_auth:uuid(I) of true->bright_sql_pool:with_connection(fun(C)->row(C,U,I) end);false->{error,not_found} end end).
list(U,P)->guard(U,fun()->case bright_project_auth:authorize(U,P) of ok->bright_sql_pool:with_connection(fun(C)->{ok,_,Rows}=bright_sql:equery(C,"SELECT id,expires_at_ms,revoked FROM bright_offline_packages WHERE owner_id=$1 AND project_id=$2 ORDER BY created_at DESC,id LIMIT 100",[U,P]),{ok,[#{id=>I,expires_at_ms=>E,revoked=>R=:=1}||{I,E,R}<-Rows]} end);E->E end end).
ids(L,N)->is_list(L) andalso length(L)=<N andalso length(lists:usort(L))=:=length(L) andalso lists:all(fun bright_project_auth:uuid/1,L).
create(U,K,M) when is_map(M)->guard(U,fun()->P=maps:get(<<"project_id">>,M,undefined),R=maps:get(<<"revision_ids">>,M,[]),D=maps:get(<<"document_ids">>,M,[]),
 case bright_mutation:keys(M,[<<"project_id">>,<<"revision_ids">>,<<"document_ids">>]) andalso ids(R,5) andalso ids(D,5) andalso length(R)+length(D)>0 of false->{error,invalid_input};true->case bright_project_auth:authorize(U,P) of
 ok->bright_mutation:run(?FLAG,<<"offline">>,U,K,{create,M},fun(C)->Now=erlang:system_time(millisecond),
 {ok,_}=bright_sql:equery(C,"UPDATE bright_offline_packages SET revoked=1,payload_json='{}' WHERE owner_id=$1 AND expires_at_ms<=$2 AND revoked=0",[U,Now]),
 {ok,_,[{Total}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_offline_packages WHERE owner_id=$1",[U]),{ok,_,[{Active}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_offline_packages WHERE owner_id=$1 AND revoked=0",[U]),
 case Total<1000 andalso Active<10 of false->{error,quota_exceeded};true->case package(C,U,P,R,D) of {ok,Data}->I=bright_project_auth:new_id(),E=Now+604800000,Snapshot=Data#{id=>I,owner_id=>U,project_id=>P,schema_version=>1,created_at_ms=>Now,expires_at_ms=>E},J=jsx:encode(Snapshot),
 case byte_size(J)=<1048576 of false->{error,quota_exceeded};true->{ok,1}=bright_sql:equery(C,"INSERT INTO bright_offline_packages(id,owner_id,project_id,payload_json,expires_at_ms) VALUES($1,$2,$3,$4,$5)",[I,U,P,J,E]),{ok,#{id=>I,expires_at_ms=>E,schema_version=>1,bytes=>byte_size(J)}} end;Error->Error end end end);E->E end end end);
create(_,_,_)->{error,invalid_input}.
package(C,U,P,R,D)->case sources(C,U,P,R,[]) of {ok,S}->case documents(C,U,P,D,[]) of {ok,Docs}->{ok,_,[{Title}]}=bright_sql:equery(C,"SELECT title FROM bright_projects WHERE id=$1 AND owner_id=$2",[P,U]),{ok,#{project_title=>Title,sources=>S,documents=>Docs}};E->E end;E->E end.
sources(_,_,_,[],A)->{ok,lists:reverse(A)};
sources(C,U,P,[I|Rest],A)->case bright_sql:equery(C,"SELECT r.source_id,s.title,r.revision,r.text_content FROM bright_source_revisions r JOIN bright_sources s ON s.id=r.source_id AND s.owner_id=r.owner_id WHERE r.id=$1 AND r.owner_id=$2 AND s.project_id=$3 AND r.state='ready'",[I,U,P]) of
 {ok,_,[{Source,T,V,Text}]} when byte_size(Text)=<524288->{ok,_,Rows}=bright_sql:equery(C,"SELECT id,quote,start_byte,end_byte FROM bright_evidence WHERE revision_id=$1 AND owner_id=$2 ORDER BY start_byte,id LIMIT 100",[I,U]),
 sources(C,U,P,Rest,[#{id=>Source,revision_id=>I,title=>T,revision=>V,text=>Text,evidence=>[#{id=>E,quote=>Q,start_byte=>B,end_byte=>End}||{E,Q,B,End}<-Rows]}|A]);{ok,_,[_]}->{error,quota_exceeded};{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
documents(_,_,_,[],A)->{ok,lists:reverse(A)};
documents(C,U,P,[I|Rest],A)->case bright_sql:equery(C,"SELECT v.snapshot_json FROM bright_documents d JOIN bright_document_versions v ON v.document_id=d.id AND v.owner_id=d.owner_id AND v.version=d.version WHERE d.id=$1 AND d.owner_id=$2 AND d.project_id=$3",[I,U,P]) of
 {ok,_,[{J}]}->documents(C,U,P,Rest,[jsx:decode(J,[return_maps])|A]);{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
revoke(U,I,K)->case bright_project_auth:uuid(I) of false->{error,not_found};true->bright_mutation:run(?FLAG,<<"offline">>,U,K,{revoke,I},fun(C)->case bright_sql:equery(C,"UPDATE bright_offline_packages SET revoked=1,payload_json='{}' WHERE id=$1 AND owner_id=$2",[I,U]) of {ok,1}->{ok,#{revoked=>true}};{ok,0}->{error,not_found};_->{error,unavailable} end end) end.
sync(U,I,K,M) when is_map(M)->case bright_project_auth:uuid(I) andalso bright_documents:enabled() of false->{error,not_ready};true->bright_mutation:run(?FLAG,<<"offline">>,U,K,{sync,I,M},fun(C)->case row(C,U,I) of {ok,#{<<"documents">>:=Docs}}->Id=maps:get(<<"document_id">>,M,undefined),V=maps:get(<<"expected_version">>,M,undefined),case [D||D<-Docs,maps:get(<<"id">>,D)=:=Id,maps:get(<<"version">>,D)=:=V] of
 [_]->case bright_mutation:keys(M,[<<"document_id">>,<<"expected_version">>,<<"title">>,<<"blocks">>]) of true->bright_documents:save_sql(C,U,Id,maps:remove(<<"document_id">>,M));false->{error,invalid_input} end;
 _->{error,conflict} end;E->E end end) end;
sync(_,_,_,_)->{error,invalid_input}.
