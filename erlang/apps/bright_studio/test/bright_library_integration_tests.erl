-module(bright_library_integration_tests).
-include_lib("eunit/include/eunit.hrl").
library_test_()->case os:getenv("BRIGHT_INTEGRATION_TESTS") of "true"->{timeout,90,fun library/0};_->[] end.
library()->
    Previous=os:getenv("STUDIO_LIBRARY_ENABLED"),os:putenv("STUDIO_LIBRARY_ENABLED","true"),
    try
        {ok,_}=application:ensure_all_started(bright_platform),{ok,_}=application:ensure_all_started(crypto),
        ok=bright_migrate:run(),ok=bright_migrate:run(),
        {ok,User,Project}=bright_session:provision(<<(bright_project_auth:new_id())/binary,"@example.test">>,<<"M2-integration-password">>,<<"Library project">>),
        {ok,Other,_}=bright_session:provision(<<(bright_project_auth:new_id())/binary,"@example.test">>,<<"M2-integration-password">>,<<"Other project">>),
        {ok,Source}=bright_source:create(User,bright_project_auth:new_id(),#{<<"title">>=><<"Library source">>,<<"project_id">>=>Project}),
        Id=maps:get(id,Source),Key=bright_project_auth:new_id(),Data= <<"Durable source text">>,
        Upload=#{filename=><<"text.txt">>,mime=><<"text/plain">>,data=>Data},
        {ok,Revision}=bright_library:upload(User,Id,Key,Upload),R=maps:get(id,Revision),
        ?assertEqual({ok,Revision},bright_library:upload(User,Id,Key,Upload)),
        ?assertEqual({error,conflict},bright_library:upload(User,Id,Key,Upload#{data=><<"Changed">>})),
        ?assertEqual({error,not_found},bright_library:original(Other,Id,R)),
        ?assertEqual({error,not_found},bright_library:content(Other,Id,R)),
        ?assertEqual({error,not_ready},bright_library:content(User,Id,R)),
        {ok,Job}=bright_library:claim(),?assertEqual(R,maps:get(id,Job)),
        %% Simulate a terminated worker and ensure only a fresh fencing token may commit.
        bright_sql_pool:with_connection(fun(C)->{ok,1}=epgsql:equery(C,"UPDATE bright_source_revisions SET lease_until=now()-interval '1 second' WHERE id=$1",[R]) end),
        {ok,Recovered}=bright_library:claim(),?assertNotEqual(maps:get(lease_token,Job),maps:get(lease_token,Recovered)),
        ?assertEqual({error,stale_lease},bright_library:finish(Job,ready,<<"Stale content">>)),
        ok=bright_library:finish(Recovered,ready,Data),
        ?assertEqual({ok,#{revision_id=>R,text=>Data}},bright_library:content(User,Id,R)),
        ?assertEqual({ok,#{mime=><<"text/plain">>,data=>Data}},bright_library:original(User,Id,R)),
        {ok,Version2}=bright_library:upload(User,Id,bright_project_auth:new_id(),Upload#{filename=><<"revised.txt">>,data=><<"Second revision">>}),
        ?assertEqual(2,maps:get(revision,Version2)),
        ok=bright_source_worker:process_one(),
        ?assertEqual({ok,#{revision_id=>R,text=>Data}},bright_library:content(User,Id,R)),
        {ok,[_,_]}=bright_library:revisions(User,Id),
        application:set_env(bright_studio,owner_upload_quota,1),
        ?assertEqual({error,quota_exceeded},bright_library:upload(User,Id,bright_project_auth:new_id(),Upload)),
        application:unset_env(bright_studio,owner_upload_quota),
        {ok,Bad}=bright_library:upload(User,Id,bright_project_auth:new_id(),Upload#{data=><<255>>}),
        ok=bright_source_worker:process_one(),
        BadId=maps:get(id,Bad),{ok,[Failed|_]}=bright_library:revisions(User,Id),
        ?assertEqual(<<"failed">>,maps:get(state,Failed)),
        ?assertEqual({error,not_ready},bright_library:content(User,Id,BadId)),
        {ok,_}=bright_library:retry(User,Id,BadId),ok=bright_source_worker:process_one(),
        os:putenv("STUDIO_LIBRARY_ENABLED","false"),
        ?assertEqual({error,disabled},bright_library:original(User,Id,R)),
        ?assertEqual({error,disabled},bright_library:claim())
    after
        application:unset_env(bright_studio,owner_upload_quota),
        case Previous of false->os:unsetenv("STUDIO_LIBRARY_ENABLED");V->os:putenv("STUDIO_LIBRARY_ENABLED",V) end
    end.
