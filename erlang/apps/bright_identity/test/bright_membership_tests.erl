-module(bright_membership_tests).
-include_lib("eunit/include/eunit.hrl").
membership_test_()->case os:getenv("BRIGHT_INTEGRATION_TESTS") of "true"->{timeout,120,fun membership/0};_->[] end.
membership()->Names=["STUDIO_HUB_ENABLED","STUDIO_ACCESS_ENABLED"],Old=[{N,os:getenv(N)}||N<-Names],
 try lists:foreach(fun(N)->os:putenv(N,"true") end,Names),{ok,_}=application:ensure_all_started(bright_platform),ok=bright_migrate:run(),
 {O,_}=user(),{A,AE}=user(),{V,VE}=user(),{Stranger,_}=user(),Input=#{<<"title">>=><<"Private team">>},Key=bright_project_auth:new_id(),{ok,Created}=bright_membership:create(O,Key,Input),W=maps:get(<<"id">>,Created),
 ?assertEqual({ok,Created},bright_membership:create(O,Key,Input)),?assertEqual({error,conflict},bright_membership:create(O,Key,Input#{<<"title">>=><<"Other team">>})),?assertEqual({error,not_found},bright_membership:read(Stranger,W)),
 Admin=#{<<"action">>=><<"add">>,<<"email">>=>AE,<<"role">>=><<"admin">>,<<"expected_version">>=>1},K2=bright_project_auth:new_id(),{ok,Added}=bright_membership:change(O,W,K2,Admin),?assertEqual({ok,Added},bright_membership:change(O,W,K2,Admin)),
 ?assertEqual({error,forbidden},bright_membership:change(A,W,bright_project_auth:new_id(),#{<<"action">>=><<"remove">>,<<"user_id">>=>O,<<"expected_version">>=>2})),
 ?assertEqual({error,forbidden},bright_membership:change(O,W,bright_project_auth:new_id(),#{<<"action">>=><<"remove">>,<<"user_id">>=>string:uppercase(O),<<"expected_version">>=>2})),
 ?assertEqual({error,forbidden},bright_membership:change(A,W,bright_project_auth:new_id(),#{<<"action">>=><<"add">>,<<"email">>=>VE,<<"role">>=><<"admin">>,<<"expected_version">>=>2})),
 {ok,_}=bright_membership:change(A,W,bright_project_auth:new_id(),#{<<"action">>=><<"add">>,<<"email">>=>VE,<<"role">>=><<"viewer">>,<<"expected_version">>=>2}),
 {ok,#{can_manage:=false,members:=[]}}=bright_membership:read(V,W),?assertEqual({error,forbidden},bright_membership:change(V,W,bright_project_auth:new_id(),#{<<"action">>=><<"remove">>,<<"user_id">>=>A,<<"expected_version">>=>3})),
 ?assertEqual({error,conflict},bright_membership:change(O,W,bright_project_auth:new_id(),Admin)),
 {ok,_}=bright_membership:change(O,W,bright_project_auth:new_id(),#{<<"action">>=><<"role">>,<<"user_id">>=>V,<<"role">>=><<"editor">>,<<"expected_version">>=>3}),{ok,Before}=bright_membership:read(O,W),?assertEqual(4,maps:get(version,Before)),
 Parent=self(),[spawn(fun()->Parent!{changed,bright_membership:change(O,W,bright_project_auth:new_id(),#{<<"action">>=><<"role">>,<<"user_id">>=>V,<<"role">>=>R,<<"expected_version">>=>4})} end)||R<-[<<"viewer">>,<<"admin">>]],Replies=[receive {changed,R}->R after 10000->timeout end||_<-lists:seq(1,2)],?assertEqual(1,length([ok||{ok,_}<-Replies])),?assertEqual(1,length([ok||{error,conflict}<-Replies])),
 {ok,_}=bright_membership:change(O,W,bright_project_auth:new_id(),#{<<"action">>=><<"remove">>,<<"user_id">>=>A,<<"expected_version">>=>5}),?assertEqual({error,not_found},bright_membership:read(A,W)),?assertEqual({error,not_found},bright_membership:change(A,W,bright_project_auth:new_id(),#{<<"action">>=><<"remove">>,<<"user_id">>=>V,<<"expected_version">>=>6})),
 {ok,Final}=bright_membership:read(O,W),?assertEqual(6,maps:get(version,Final)),?assertEqual(1,length([M||M<-maps:get(members,Final),maps:get(role,M)=:= <<"owner">>])),
 %% Membership does not grant access to another user's personal projects.
 {ok,Private}=bright_project_auth:list(O),?assertEqual({error,forbidden},bright_project_auth:authorize(V,maps:get(id,hd(Private)))),
 os:putenv("STUDIO_ACCESS_ENABLED","false"),?assertEqual({error,disabled},bright_membership:read(O,W))
 after lists:foreach(fun({N,false})->os:unsetenv(N);({N,V})->os:putenv(N,V) end,Old) end.
user()->E= <<(bright_project_auth:new_id())/binary,"@membership.test">>,{ok,U,_}=bright_session:provision(E,<<"Membership-test-password">>,<<"Personal">>),{U,E}.
