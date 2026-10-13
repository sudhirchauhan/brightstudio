-module(bright_offline_tests).
-include_lib("eunit/include/eunit.hrl").
offline_test_()->case os:getenv("BRIGHT_INTEGRATION_TESTS") of "true"->{timeout,90,fun offline/0};_->[] end.
offline()->Flags=["STUDIO_HUB_ENABLED","STUDIO_DOCUMENTS_ENABLED","STUDIO_OFFLINE_ENABLED"],Old=[{F,os:getenv(F)}||F<-Flags],lists:foreach(fun(F)->os:putenv(F,"true") end,Flags),
 try {ok,_}=application:ensure_all_started(bright_platform),ok=bright_migrate:run(),
 {ok,U,P}=bright_session:provision(<<(bright_project_auth:new_id())/binary,"@offline.test">>,<<"Offline-test-password">>,<<"Offline">>),
 {ok,O,_}=bright_session:provision(<<(bright_project_auth:new_id())/binary,"@offline.test">>,<<"Offline-test-password">>,<<"Other">>),
 {ok,D}=bright_documents:create(U,bright_project_auth:new_id(),#{<<"project_id">>=>P,<<"title">>=><<"An offline thought">>}),Id=maps:get(<<"id">>,D),
 Input=#{<<"project_id">>=>P,<<"document_ids">>=>[Id]},K=bright_project_auth:new_id(),{ok,Ack}=bright_offline:create(U,K,Input),Package=maps:get(<<"id">>,Ack),
 ?assertEqual({ok,Ack},bright_offline:create(U,K,Input)),?assertEqual({error,conflict},bright_offline:create(U,K,Input#{<<"revision_ids">>=>[]})),
 ?assertEqual({error,not_found},bright_offline:read(O,Package)),?assertEqual({error,forbidden},bright_offline:create(O,K,Input)),
 {ok,Copy}=bright_offline:read(U,Package),?assertEqual(U,maps:get(<<"owner_id">>,Copy)),?assertEqual(1,maps:get(<<"schema_version">>,Copy)),
 Save=#{<<"document_id">>=>Id,<<"expected_version">>=>1,<<"title">>=><<"An offline thought">>,<<"blocks">>=>[#{<<"id">>=>bright_project_auth:new_id(),<<"kind">>=><<"paragraph">>,<<"text">>=><<"A private offline draft.">>}]},SK=bright_project_auth:new_id(),
 {ok,Saved}=bright_offline:sync(U,Package,SK,Save),?assertEqual({ok,Saved},bright_offline:sync(U,Package,SK,Save)),?assertEqual(2,maps:get(<<"version">>,Saved)),
 ?assertEqual({error,conflict},bright_offline:sync(U,Package,bright_project_auth:new_id(),Save)),?assertEqual({error,not_found},bright_offline:sync(O,Package,SK,Save)),
 ?assertEqual({error,conflict},bright_offline:sync(U,Package,bright_project_auth:new_id(),Save#{<<"document_id">>=>bright_project_auth:new_id()})),
 ?assertEqual({error,conflict},bright_offline:sync(U,Package,bright_project_auth:new_id(),Save#{<<"expected_version">>=>2})),
 {ok,_}=bright_offline:revoke(U,Package,bright_project_auth:new_id()),?assertEqual({error,not_ready},bright_offline:read(U,Package)),?assertEqual({error,not_ready},bright_offline:sync(U,Package,bright_project_auth:new_id(),Save)),
 ?assertEqual({ok,Saved},bright_offline:sync(U,Package,SK,Save)),
 {ok,A2}=bright_offline:create(U,bright_project_auth:new_id(),Input),I2=maps:get(<<"id">>,A2),bright_sql_pool:with_connection(fun(C)->{ok,1}=bright_sql:equery(C,"UPDATE bright_offline_packages SET expires_at_ms=1 WHERE id=$1",[I2]) end),?assertEqual({error,not_ready},bright_offline:read(U,I2)),
 os:putenv("STUDIO_OFFLINE_ENABLED","false"),?assertEqual({error,disabled},bright_offline:read(U,Package)),os:putenv("STUDIO_OFFLINE_ENABLED","true"),?assertMatch({ok,_},bright_offline:list(U,P))
 after lists:foreach(fun({F,false})->os:unsetenv(F);({F,V})->os:putenv(F,V) end,Old) end.
