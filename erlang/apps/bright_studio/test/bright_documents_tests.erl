-module(bright_documents_tests).
-include_lib("eunit/include/eunit.hrl").
documents_test_()->case os:getenv("BRIGHT_INTEGRATION_TESTS") of "true"->{timeout,90,fun documents/0};_->[] end.
documents()->
 Flags=["STUDIO_HUB_ENABLED","STUDIO_DOCUMENTS_ENABLED","STUDIO_LIBRARY_ENABLED","STUDIO_EVIDENCE_ENABLED"],Old=[{F,os:getenv(F)}||F<-Flags],lists:foreach(fun(F)->os:putenv(F,"true") end,Flags),
 try {ok,_}=application:ensure_all_started(bright_platform),ok=bright_migrate:run(),ok=bright_migrate:run(),
 {ok,U,P}=bright_session:provision(<<(bright_project_auth:new_id())/binary,"@documents.test">>,<<"Documents-test-password">>,<<"Documents">>),
 {ok,O,OP}=bright_session:provision(<<(bright_project_auth:new_id())/binary,"@documents.test">>,<<"Documents-test-password">>,<<"Other">>),
 K=bright_project_auth:new_id(),Input=#{<<"project_id">>=>P,<<"title">>=><<"A cited thought">>},{ok,D}=bright_documents:create(U,K,Input),Id=maps:get(<<"id">>,D),
 ?assertEqual({ok,D},bright_documents:create(U,K,Input)),?assertEqual({error,conflict},bright_documents:create(U,K,Input#{<<"title">>=><<"Changed">>})),
 ?assertEqual({error,forbidden},bright_documents:create(O,K,Input)),?assertEqual({error,not_found},bright_documents:read(O,Id,latest)),?assertEqual({error,not_found},bright_documents:export(O,Id,1)),
 {ok,S0}=bright_source:create(U,bright_project_auth:new_id(),#{<<"project_id">>=>P,<<"title">>=><<"Pinned source">>}),S=maps:get(id,S0),
 {ok,R0}=bright_library:upload(U,S,bright_project_auth:new_id(),#{filename=><<"doc.txt">>,mime=><<"text/plain">>,data=><<"Active recall keeps ideas grounded.">>}),R=maps:get(id,R0),ok=bright_source_worker:process_one(),
 {ok,E0}=bright_evidence:create(U,bright_project_auth:new_id(),#{<<"source_id">>=>S,<<"revision_id">>=>R,<<"start_byte">>=>0,<<"end_byte">>=>13,<<"quote">>=><<"Active recall">>}),E=maps:get(id,E0),
 B=#{<<"id">>=>bright_project_auth:new_id(),<<"kind">>=><<"evidence">>,<<"text">>=><<"My own reflection.">>,<<"evidence_id">>=>E},Text=#{<<"id">>=>bright_project_auth:new_id(),<<"kind">>=><<"paragraph">>,<<"text">>=><<"<script>alert(1)</script> [unsafe](javascript:bad)">>},
 Save=#{<<"expected_version">>=>1,<<"title">>=><<"A cited thought">>,<<"blocks">>=>[B,Text]},SK=bright_project_auth:new_id(),{ok,Saved}=bright_documents:save(U,Id,SK,Save),
 ?assertEqual({ok,Saved},bright_documents:save(U,Id,SK,Save)),?assertEqual({error,conflict},bright_documents:save(U,Id,SK,Save#{<<"title">>=><<"Changed">>})),
 ?assertEqual({error,invalid_input},bright_documents:save(U,Id,K,Save#{<<"blocks">>=>[B,B]})),?assertEqual({error,invalid_input},bright_documents:save(U,Id,K,Save#{<<"blocks">>=>[B#{<<"citation">>=>#{}}]})),
 ?assertEqual({error,not_found},bright_documents:save(O,Id,K,Save)),
 {ok,Bytes}=bright_documents:export(U,Id,2),?assertNotEqual(nomatch,binary:match(Bytes,R)),?assertNotEqual(nomatch,binary:match(Bytes,<<"Active recall">>)),?assertNotEqual(nomatch,binary:match(Bytes,<<"&lt;script&gt;">>)),?assertEqual(nomatch,binary:match(Bytes,<<"[unsafe](javascript:">>)),
 {ok,_}=bright_library:upload(U,S,bright_project_auth:new_id(),#{filename=><<"new.txt">>,mime=><<"text/plain">>,data=><<"Completely new content.">>}),ok=bright_source_worker:process_one(),?assertEqual({ok,Bytes},bright_documents:export(U,Id,2)),
 Next=Save#{<<"expected_version">>=>2,<<"blocks">>=>[Text,B]},Parent=self(),[spawn(fun()->Parent!{doc,bright_documents:save(U,Id,bright_project_auth:new_id(),Next)} end)||_<-[1,2]],Results=[receive {doc,X}->X after 10000->error(timeout) end||_<-[1,2]],?assertEqual(1,length([ok||{ok,_}<-Results])),?assertEqual(1,length([conflict||{error,conflict}<-Results])),
 ?assertEqual({ok,[3,2,1]},bright_documents:history(U,Id)),{ok,Initial}=bright_documents:read(U,Id,1),?assertEqual([],maps:get(<<"blocks">>,Initial)),?assertEqual(3,maps:get(<<"current_version">>,Initial)),
 {ok,Missing}=bright_documents:create(O,K,#{<<"project_id">>=>OP,<<"title">>=><<"Other">>}),?assertEqual({error,not_found},bright_documents:save(O,maps:get(<<"id">>,Missing),bright_project_auth:new_id(),Save)),
 os:putenv("STUDIO_LIBRARY_ENABLED","false"),os:putenv("STUDIO_EVIDENCE_ENABLED","false"),?assertEqual({ok,Bytes},bright_documents:export(U,Id,2)),
 os:putenv("STUDIO_DOCUMENTS_ENABLED","false"),?assertEqual({error,disabled},bright_documents:read(U,Id,latest)),os:putenv("STUDIO_DOCUMENTS_ENABLED","true"),?assertMatch({ok,_},bright_documents:read(U,Id,latest))
 after lists:foreach(fun({F,false})->os:unsetenv(F);({F,V})->os:putenv(F,V) end,Old) end.
