-module(bright_tasks_tests).
-include_lib("eunit/include/eunit.hrl").
dates_test()->
    ?assert(bright_tasks:date(<<"2024-02-29">>)),?assert(bright_tasks:date(<<"2026-03-29">>)),?assert(bright_tasks:date(<<>>)),
    ?assertNot(bright_tasks:date(<<"2025-02-29">>)),?assertNot(bright_tasks:date(<<"2026-13-01">>)),?assertNot(bright_tasks:date(<<"1899-12-31">>)),?assertNot(bright_tasks:date(<<"2026-1-01">>)),?assertNot(bright_tasks:date(null)).
workspace_test_()->case os:getenv("BRIGHT_INTEGRATION_TESTS") of "true"->{timeout,90,fun workspace/0};_->[] end.
workspace()->
    Prev=os:getenv("STUDIO_WORKSPACE_ENABLED"),os:putenv("STUDIO_WORKSPACE_ENABLED","true"),
    try
        {ok,_}=application:ensure_all_started(bright_platform),ok=bright_migrate:run(),ok=bright_migrate:run(),
        {ok,U,P}=bright_session:provision(<<(bright_project_auth:new_id())/binary,"@example.test">>,<<"Workspace-test-password">>,<<"Workspace">>),
        {ok,O,OP}=bright_session:provision(<<(bright_project_auth:new_id())/binary,"@example.test">>,<<"Workspace-test-password">>,<<"Other">>),
        PK=bright_project_auth:new_id(),PM=#{<<"title">>=><<"New project">>},
        {ok,Project}=bright_workspace:create_project(U,PK,PM),Id=maps:get(<<"id">>,Project),
        ?assertEqual({ok,Project},bright_workspace:create_project(U,PK,PM)),
        ?assertEqual({error,conflict},bright_workspace:create_project(U,PK,PM#{<<"title">>=><<"Changed">>})),
        ?assertEqual({error,not_found},bright_workspace:project(O,Id)),
        Edit=#{<<"expected_version">>=>1,<<"title">>=><<"Renamed">>},EK=bright_project_auth:new_id(),
        {ok,Renamed}=bright_workspace:edit_project(U,Id,EK,Edit),?assertEqual(2,maps:get(<<"version">>,Renamed)),
        ?assertEqual({ok,Renamed},bright_workspace:edit_project(U,Id,EK,Edit)),?assertEqual({error,conflict},bright_workspace:edit_project(U,Id,bright_project_auth:new_id(),Edit)),
        T=#{<<"project_id">>=>P,<<"title">>=><<"Owned task">>,<<"scheduled_date">>=><<"2026-03-29">>,<<"due_date">>=><<"2026-03-30">>,<<"estimate_minutes">>=>45},K=bright_project_auth:new_id(),
        ?assertEqual({error,forbidden},bright_tasks:create(U,K,T#{<<"project_id">>=>OP})),
        ?assertEqual({error,invalid_input},bright_tasks:create(U,K,T#{<<"due_date">>=><<"2025-02-29">>})),
        {ok,Task}=bright_tasks:create(U,K,T),TaskId=maps:get(<<"id">>,Task),
        ?assertEqual({ok,Task},bright_tasks:create(U,K,T)),?assertEqual({error,conflict},bright_tasks:create(U,K,T#{<<"title">>=><<"Other">>})),
        ?assertEqual({error,not_found},bright_tasks:read(O,TaskId)),?assertEqual({error,not_found},bright_tasks:edit(O,TaskId,bright_project_auth:new_id(),T#{<<"expected_version">>=>1})),
        ?assertEqual({ok,[]},bright_tasks:list(U,P,<<"2026-03-28">>)),{ok,[_]}=bright_tasks:list(U,P,<<"2026-03-29">>),{ok,[_]}=bright_tasks:list(U,P,<<"2026-04-01">>),
        Done=T#{<<"state">>=><<"done">>,<<"expected_version">>=>1},DK=bright_project_auth:new_id(),
        {ok,Completed}=bright_tasks:edit(U,TaskId,DK,Done),?assertEqual({ok,Completed},bright_tasks:edit(U,TaskId,DK,Done)),
        ?assertEqual({error,conflict},bright_tasks:edit(U,TaskId,bright_project_auth:new_id(),Done)),?assertEqual({ok,[]},bright_tasks:list(U,P,<<"2026-04-01">>)),
        Stamp=bright_sql_pool:with_connection(fun(C)->{ok,_,[{X}]}=bright_sql:equery(C,"SELECT completed_at FROM bright_tasks WHERE id=$1",[TaskId]),X end),?assertNotEqual(null,Stamp),
        {ok,_}=bright_tasks:edit(U,TaskId,bright_project_auth:new_id(),T#{<<"state">>=><<"done">>,<<"expected_version">>=>2}),
        SameStamp=bright_sql_pool:with_connection(fun(C)->{ok,_,[{X}]}=bright_sql:equery(C,"SELECT completed_at FROM bright_tasks WHERE id=$1",[TaskId]),X end),?assertEqual(Stamp,SameStamp),
        {ok,_}=bright_tasks:edit(U,TaskId,bright_project_auth:new_id(),T#{<<"state">>=><<"todo">>,<<"project_id">>=>Id,<<"expected_version">>=>3}),
        ?assertEqual({ok,[]},bright_tasks:list(U,P,<<>>)),{ok,[_]}=bright_tasks:list(U,Id,<<"2026-03-29">>),
        NullStamp=bright_sql_pool:with_connection(fun(C)->{ok,_,[{X}]}=bright_sql:equery(C,"SELECT completed_at FROM bright_tasks WHERE id=$1",[TaskId]),X end),?assertEqual(null,NullStamp),
        %% A failed domain result after a write must roll back both data and receipt.
        ?assertEqual({error,conflict},bright_workspace:mutate(U,rollback_check,bright_project_auth:new_id(),<<>>,fun(C)->{ok,1}=bright_sql:equery(C,"UPDATE bright_tasks SET title='Must roll back' WHERE id=$1",[TaskId]),{error,conflict} end)),
        {ok,#{title:= <<"Owned task">>}}=bright_tasks:read(U,TaskId),
        os:putenv("STUDIO_WORKSPACE_ENABLED","false"),?assertEqual({error,disabled},bright_tasks:read(U,TaskId))
    after restore("STUDIO_WORKSPACE_ENABLED",Prev) end.
restore(K,false)->os:unsetenv(K);restore(K,V)->os:putenv(K,V).
