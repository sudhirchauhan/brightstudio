-module(bright_evidence_tests).
-include_lib("eunit/include/eunit.hrl").
anchor_unicode_test()->
    Text=unicode:characters_to_binary([16#1f600,32,$c,$a,$f,16#e9,32,$c,$a,$f,16#e9]),
    Quote=unicode:characters_to_binary([$c,$a,$f,16#e9]),
    ?assert(bright_evidence:anchor(Text,5,10,Quote)),
    ?assert(bright_evidence:anchor(Text,11,16,Quote)),
    ?assertNot(bright_evidence:anchor(Text,1,6,binary:part(Text,1,5))),
    ?assertNot(bright_evidence:anchor(Text,5,9,Quote)),
    ?assertNot(bright_evidence:anchor(Text,5,10,<<"wrong">>)),
    ?assertNot(bright_evidence:anchor(Text,0,999,Quote)),
    ?assertNot(bright_evidence:anchor(Text,0,0,<<>>)).
evidence_test_()->case os:getenv("BRIGHT_INTEGRATION_TESTS") of "true"->{timeout,90,fun evidence/0};_->[] end.
evidence()->
    Prev=os:getenv("STUDIO_EVIDENCE_ENABLED"),Lib=os:getenv("STUDIO_LIBRARY_ENABLED"),
    os:putenv("STUDIO_EVIDENCE_ENABLED","true"),os:putenv("STUDIO_LIBRARY_ENABLED","true"),
    try
        {ok,_}=application:ensure_all_started(bright_platform),ok=bright_migrate:run(),ok=bright_migrate:run(),
        {ok,U,P}=bright_session:provision(<<(bright_project_auth:new_id())/binary,"@example.test">>,<<"M3-test-password">>,<<"Evidence project">>),
        {ok,O,OP}=bright_session:provision(<<(bright_project_auth:new_id())/binary,"@example.test">>,<<"M3-test-password">>,<<"Other project">>),
        {ok,Source}=bright_source:create(U,bright_project_auth:new_id(),#{<<"title">>=><<"Evidence source">>,<<"project_id">>=>P}),S=maps:get(id,Source),
        T=unicode:characters_to_binary([16#1f600,32,$c,$a,$f,16#e9,32,$c,$a,$f,16#e9]),Q=unicode:characters_to_binary([$c,$a,$f,16#e9]),
        {ok,R}=bright_library:upload(U,S,bright_project_auth:new_id(),#{filename=><<"text.txt">>,mime=><<"text/plain">>,data=>T}),
        M=#{<<"source_id">>=>S,<<"revision_id">>=>maps:get(id,R),<<"start_byte">>=>11,<<"end_byte">>=>16,<<"quote">>=>Q,<<"note">>=><<"Original note">>},
        ?assertEqual({error,not_ready},bright_evidence:create(U,bright_project_auth:new_id(),M)),
        ok=bright_source_worker:process_one(),K=bright_project_auth:new_id(),
        {ok,E}=bright_evidence:create(U,K,M),Id=maps:get(id,E),
        ?assertEqual(resolved,maps:get(anchor_state,E)),?assertEqual({ok,E},bright_evidence:create(U,K,M)),
        ?assertEqual({error,invalid_input},bright_evidence:create(U,bright_project_auth:new_id(),M#{<<"quote">>=><<"Invented quote">>})),
        ?assertEqual({error,conflict},bright_evidence:create(U,K,M#{<<"note">>=><<"Different">>})),
        ?assertEqual({error,not_found},bright_evidence:read(O,Id)),
        ?assertEqual({error,not_found},bright_evidence:history(O,Id)),
        ?assertEqual({error,not_found},bright_evidence:edit(O,Id,bright_project_auth:new_id(),#{<<"note">>=><<"Intruder">>,<<"expected_version">>=>1})),
        EditKey=bright_project_auth:new_id(),Edit=#{<<"note">>=><<"Updated note">>,<<"expected_version">>=>1},
        {ok,Receipt}=bright_evidence:edit(U,Id,EditKey,Edit),?assertEqual(2,maps:get(version,Receipt)),
        ?assertEqual({ok,Receipt},bright_evidence:edit(U,Id,EditKey,Edit)),
        ?assertEqual({error,conflict},bright_evidence:edit(U,Id,bright_project_auth:new_id(),Edit)),
        {ok,[#{version:=2},#{version:=1}]}=bright_evidence:history(U,Id),
        {ok,B}=bright_evidence:create_board(U,bright_project_auth:new_id(),#{<<"project_id">>=>P,<<"title">>=><<"Research">>}),BId=maps:get(id,B),
        {ok,OB}=bright_evidence:create_board(O,bright_project_auth:new_id(),#{<<"project_id">>=>OP,<<"title">>=><<"Other board">>}),
        ?assertEqual({error,not_found},bright_evidence:link(U,maps:get(id,OB),Id)),
        ?assertEqual({error,not_found},bright_evidence:link(O,maps:get(id,OB),Id)),
        ?assertEqual({error,not_found},bright_evidence:board(O,BId)),
        {ok,_}=bright_evidence:link(U,BId,Id),{ok,_}=bright_evidence:link(U,BId,Id),{ok,#{items:=[_]}}=bright_evidence:board(U,BId),
        P2=bright_project_auth:new_id(),bright_sql_pool:with_connection(fun(C)->{ok,1}=bright_sql:equery(C,"INSERT INTO bright_projects(id,owner_id,title) VALUES($1,$2,'Related project')",[P2,U]) end),
        {ok,Related}=bright_evidence:create_board(U,bright_project_auth:new_id(),#{<<"project_id">>=>P2,<<"title">>=><<"Related board">>}),
        {ok,_}=bright_evidence:link(U,maps:get(id,Related),Id),{ok,#{items:=[#{source_id:=S}]}}=bright_evidence:board(U,maps:get(id,Related)),
        %% Composite owner keys also reject unauthorized links below the domain layer.
        bright_sql_pool:with_connection(fun(C)->?assertMatch({error,_},bright_sql:equery(C,"INSERT INTO bright_evidence_links(board_id,evidence_id,owner_id) VALUES($1,$2,$3)",[maps:get(id,OB),Id,O])) end),
        {ok,_}=bright_library:upload(U,S,bright_project_auth:new_id(),#{filename=><<"v2.txt">>,mime=><<"text/plain">>,data=><<"Entirely new text">>}),ok=bright_source_worker:process_one(),
        {ok,[Old]}=bright_evidence:list(U,S,<<>>),?assertEqual(maps:get(id,R),maps:get(revision_id,Old)),
        %% Simulate damaged derived text. Never relocate to matching text in another revision.
        bright_sql_pool:with_connection(fun(C)->{ok,1}=bright_sql:equery(C,"UPDATE bright_source_revisions SET text_content='damaged' WHERE id=$1",[maps:get(id,R)]) end),
        {ok,Unresolved}=bright_evidence:read(U,Id),?assertEqual(unresolved,maps:get(anchor_state,Unresolved)),
        os:putenv("STUDIO_EVIDENCE_ENABLED","false"),?assertEqual({error,disabled},bright_evidence:read(U,Id))
    after
        restore("STUDIO_EVIDENCE_ENABLED",Prev),restore("STUDIO_LIBRARY_ENABLED",Lib)
    end.
restore(Key,false)->os:unsetenv(Key);restore(Key,V)->os:putenv(Key,V).
