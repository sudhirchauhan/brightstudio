-module(bright_documents).
-export([enabled/0,list/2,read/3,history/2,evidence/2,evidence_owned/2,create/3,save/4,save_sql/4,export/3]).
-define(FLAG,"STUDIO_DOCUMENTS_ENABLED").
enabled()->bright_mutation:enabled(?FLAG).
guard(U,F)->bright_mutation:guard(?FLAG,{U,F}).
list(U,P)->guard(U,fun()->case bright_project_auth:authorize(U,P) of ok->bright_sql_pool:with_connection(fun(C)->
 {ok,_,Rows}=bright_sql:equery(C,"SELECT id,title,version FROM bright_documents WHERE owner_id=$1 AND project_id=$2 ORDER BY created_at DESC,id LIMIT 100",[U,P]),
 {ok,[#{id=>Id,title=>T,version=>V}||{Id,T,V}<-Rows]} end);E->E end end).
row(C,U,Id)->case bright_sql:equery(C,"SELECT project_id,version FROM bright_documents WHERE id=$1 AND owner_id=$2",[Id,U]) of {ok,_,[{P,V}]}->{ok,P,V};{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
snapshot(C,U,Id,V)->case bright_sql:equery(C,"SELECT snapshot_json FROM bright_document_versions WHERE document_id=$1 AND owner_id=$2 AND version=$3",[Id,U,V]) of
 {ok,_,[{J}]}->{ok,jsx:decode(J,[return_maps])};{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
read(U,Id,V)->guard(U,fun()->case bright_project_auth:uuid(Id) andalso (V=:=latest orelse bright_workspace:version(V)) of
 false->{error,not_found};true->bright_sql_pool:with_connection(fun(C)->case row(C,U,Id) of {ok,_,Current}->case snapshot(C,U,Id,case V of latest->Current;_->V end) of {ok,S}->{ok,S#{<<"current_version">>=>Current}};E->E end;E->E end end) end end).
history(U,Id)->guard(U,fun()->case bright_project_auth:uuid(Id) of false->{error,not_found};true->bright_sql_pool:with_connection(fun(C)->case row(C,U,Id) of
 {ok,_,_}->{ok,_,Rows}=bright_sql:equery(C,"SELECT version FROM bright_document_versions WHERE document_id=$1 AND owner_id=$2 ORDER BY version DESC LIMIT 1000",[Id,U]),{ok,[V||{V}<-Rows]};E->E end end) end end).
evidence(U,P)->guard(U,fun()->evidence_owned(U,P) end).
evidence_owned(U,P)->case bright_project_auth:authorize(U,P) of ok->bright_sql_pool:with_connection(fun(C)->
 {ok,_,Rows}=bright_sql:equery(C,"SELECT e.id,e.quote,e.source_id,e.revision_id,r.revision,s.title FROM bright_evidence e JOIN bright_sources s ON s.id=e.source_id AND s.owner_id=e.owner_id JOIN bright_source_revisions r ON r.id=e.revision_id AND r.owner_id=e.owner_id WHERE e.owner_id=$1 AND s.project_id=$2 ORDER BY e.created_at DESC,e.id LIMIT 100",[U,P]),
 {ok,[#{id=>I,quote=>Q,source_id=>S,revision_id=>R,revision=>V,title=>T}||{I,Q,S,R,V,T}<-Rows]} end);E->E end.
create(U,K,M) when is_map(M)->guard(U,fun()->P=maps:get(<<"project_id">>,M,undefined),T=maps:get(<<"title">>,M,undefined),
 case bright_mutation:keys(M,[<<"project_id">>,<<"title">>]) andalso bright_workspace:text(T,200,false) of false->{error,invalid_input};true->case bright_project_auth:authorize(U,P) of
 ok->bright_mutation:run(?FLAG,<<"documents">>,U,K,{create,M},fun(C)->
 {ok,_,[{N}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_documents WHERE owner_id=$1",[U]),case N<100 of false->{error,quota_exceeded};true->Id=bright_project_auth:new_id(),Title=string:trim(T),
 {ok,1}=bright_sql:equery(C,"INSERT INTO bright_documents(id,owner_id,project_id,title) VALUES($1,$2,$3,$4)",[Id,U,P,Title]),store(C,U,Id,P,Title,1,[]) end end);E->E end end end);
create(_,_,_)->{error,invalid_input}.
valid_blocks(B) when is_list(B),length(B)=<100->Ids=[maps:get(<<"id">>,X,undefined)||X<-B,is_map(X)],
 length(Ids)=:=length(B) andalso length(lists:usort(Ids))=:=length(Ids) andalso lists:all(fun valid_block/1,B) andalso byte_size(jsx:encode(B))=<20000;
valid_blocks(_)->false.
valid_block(M)->bright_mutation:keys(M,[<<"id">>,<<"kind">>,<<"text">>,<<"evidence_id">>]) andalso bright_project_auth:uuid(maps:get(<<"id">>,M,undefined)) andalso bright_workspace:text(maps:get(<<"text">>,M,undefined),2000,true) andalso
 case {maps:get(<<"kind">>,M,undefined),maps:get(<<"evidence_id">>,M,null)} of {<<"paragraph">>,null}->true;{<<"evidence">>,E}->bright_project_auth:uuid(E);_->false end.
save(U,Id,K,M) when is_map(M)->case read(U,Id,latest) of {ok,_}->case valid_save(M) of true->bright_mutation:run(?FLAG,<<"documents">>,U,K,{save,Id,M},fun(C)->save_sql(C,U,Id,M) end);false->{error,invalid_input} end;E->E end;
save(_,_,_,_)->{error,invalid_input}.
valid_save(M)->bright_mutation:keys(M,[<<"expected_version">>,<<"title">>,<<"blocks">>]) andalso bright_workspace:version(maps:get(<<"expected_version">>,M,undefined)) andalso bright_workspace:text(maps:get(<<"title">>,M,undefined),200,false) andalso valid_blocks(maps:get(<<"blocks">>,M,undefined)).
save_sql(C,U,Id,M)->V=maps:get(<<"expected_version">>,M,undefined),T=maps:get(<<"title">>,M,undefined),B=maps:get(<<"blocks">>,M,undefined),
 case bright_mutation:keys(M,[<<"expected_version">>,<<"title">>,<<"blocks">>]) andalso bright_workspace:version(V) andalso bright_workspace:text(T,200,false) andalso valid_blocks(B) of
 false->{error,invalid_input};true->case row(C,U,Id) of
 {ok,P,V} when V<1000->case pin(C,U,P,B,[]) of {ok,Pinned}->case bright_sql:equery(C,"UPDATE bright_documents SET title=$1,version=version+1 WHERE id=$2 AND owner_id=$3 AND version=$4 RETURNING version",[string:trim(T),Id,U,V]) of
 {ok,1,_,[_]}->store(C,U,Id,P,string:trim(T),V+1,Pinned);{ok,0,_,[]}->{error,conflict};_->{error,unavailable} end;E->E end;
 {ok,_,V}->{error,quota_exceeded};{ok,_,_}->{error,conflict};E->E end end.

pin(_,_,_,[],A)->{ok,lists:reverse(A)};
pin(C,U,P,[#{<<"kind">>:= <<"paragraph">>}=B|Rest],A)->pin(C,U,P,Rest,[B|A]);
pin(C,U,P,[#{<<"evidence_id">>:=E}=B|Rest],A)->case bright_sql:equery(C,"SELECT e.quote,e.source_id,e.revision_id,r.revision,s.title FROM bright_evidence e JOIN bright_sources s ON s.id=e.source_id AND s.owner_id=e.owner_id JOIN bright_source_revisions r ON r.id=e.revision_id AND r.owner_id=e.owner_id WHERE e.id=$1 AND e.owner_id=$2 AND s.project_id=$3",[E,U,P]) of
 {ok,_,[{Q,S,R,V,T}]}->pin(C,U,P,Rest,[B#{<<"citation">>=>#{<<"quote">>=>Q,<<"source_id">>=>S,<<"revision_id">>=>R,<<"revision">>=>V,<<"title">>=>T}}|A]);{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
store(C,U,Id,P,T,V,B)->Snapshot=#{<<"id">>=>Id,<<"project_id">>=>P,<<"title">>=>T,<<"version">>=>V,<<"blocks">>=>B},
 {ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_document_versions WHERE owner_id=$1",[U]),
 case Count<1000 andalso byte_size(jsx:encode(Snapshot))=<65536 of false->{error,quota_exceeded};true->
 {ok,1}=bright_sql:equery(C,"INSERT INTO bright_document_versions(document_id,owner_id,version,snapshot_json) VALUES($1,$2,$3,$4)",[Id,U,V,jsx:encode(Snapshot)]),{ok,Snapshot} end.
export(U,Id,V)->case read(U,Id,V) of {ok,#{<<"title">>:=T,<<"version">>:=N,<<"blocks">>:=B}}->
 {ok,iolist_to_binary(["# ",escape(T),"\n\nRevision ",integer_to_binary(N),"\n\n",[markdown(X)||X<-B]])};E->E end.
markdown(#{<<"kind">>:= <<"paragraph">>,<<"text">>:=T})->[escape(T),"\n\n"];
markdown(#{<<"text">>:=T,<<"citation">>:=#{<<"quote">>:=Q,<<"title">>:=Title,<<"source_id">>:=S,<<"revision_id">>:=R,<<"revision">>:=V}})->
 ["> ",binary:replace(escape(Q),<<"\n">>,<<"\n> ">>,[global]),"\n\n",escape(T),"\n\nSource: [",escape(Title)," - Revision ",integer_to_binary(V),"](/studio/hub/sources/",S,"?revision=",R,")\n\n"].
escape(T)->lists:foldl(fun({A,B},X)->binary:replace(X,A,B,[global]) end,T,[{<<"\\">>,<<"\\\\">>},{<<"&">>,<<"&amp;">>},{<<"<">>,<<"&lt;">>},{<<">">>,<<"&gt;">>}]++[{<<C>>,<<"\\",C>>}||C<-"`*_{}[]()#+-.!"]).
