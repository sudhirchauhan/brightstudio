-module(bright_dev_workspace_samples_tests).
-include_lib("eunit/include/eunit.hrl").
samples_test_()->case {os:getenv("BRIGHT_INTEGRATION_TESTS"),os:getenv("DATABASE_URL")} of {"true","sqlite:"++_}->{timeout,90,fun samples/0};_->[] end.
samples()->
    Prev=os:getenv("BRIGHT_SQLITE_DEVELOPMENT"),W=os:getenv("STUDIO_WORKSPACE_ENABLED"),
    os:putenv("BRIGHT_SQLITE_DEVELOPMENT","true"),os:putenv("STUDIO_WORKSPACE_ENABLED","true"),
    try
        {ok,_}=application:ensure_all_started(bright_platform),ok=bright_migrate:run(),
        {ok,U,P}=bright_session:provision(<<(bright_project_auth:new_id())/binary,"@samples.test">>,<<"Private-samples-password">>,<<"Workspace samples">>),
        ok=bright_dev_workspace_samples:run(U,P),{ok,Tasks}=bright_tasks:list(U,P,<<>>),?assertEqual(5,length(Tasks)),
        [First]=[T||T<-Tasks,maps:get(title,T)=:= <<"Sample: read the walkthrough">>],Day=maps:get(scheduled_date,First),
        {ok,Today}=bright_tasks:list(U,P,Day),?assertEqual(3,length(Today)),
        Payload=maps:from_list([{atom_to_binary(K),V}||{K,V}<-maps:to_list(First)]),
        {ok,_}=bright_tasks:edit(U,maps:get(id,First),bright_project_auth:new_id(),Payload#{<<"title">>=><<"User-edited sample task">>,<<"expected_version">>=>1}),
        ok=bright_dev_workspace_samples:run(U,P),{ok,After}=bright_tasks:read(U,maps:get(id,First)),?assertEqual(<<"User-edited sample task">>,maps:get(title,After)),
        {ok,Again}=bright_tasks:list(U,P,<<>>),?assertEqual(5,length(Again))
    after restore("BRIGHT_SQLITE_DEVELOPMENT",Prev),restore("STUDIO_WORKSPACE_ENABLED",W) end.
restore(K,false)->os:unsetenv(K);restore(K,V)->os:putenv(K,V).
