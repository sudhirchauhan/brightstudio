-module(bright_account_tests).
-include_lib("eunit/include/eunit.hrl").
timezones_test()->?assert(lists:member(<<"Europe/Zurich">>,bright_account:timezones())),?assertNot(lists:member(<<"Invented/Zone">>,bright_account:timezones())).
account_test_()->case os:getenv("BRIGHT_INTEGRATION_TESTS") of "true"->{timeout,90,fun account/0};_->[] end.
account()->
    Prev=os:getenv("STUDIO_WORKSPACE_ENABLED"),os:putenv("STUDIO_WORKSPACE_ENABLED","true"),
    try
        {ok,_}=application:ensure_all_started(bright_platform),ok=bright_migrate:run(),
        Email= <<(bright_project_auth:new_id())/binary,"@example.test">>,Old= <<"Account-test-password">>,New= <<"Changed-account-password">>,
        {ok,U,_}=bright_session:provision(Email,Old,<<"Account">>),{ok,A}=bright_session:login(Email,Old),{ok,B}=bright_session:login(Email,Old),
        {ok,Profile}=bright_account:read(U),?assertEqual(<<"Etc/UTC">>,maps:get(timezone,Profile)),
        M=#{<<"display_name">>=><<"Reader">>,<<"timezone">>=><<"Europe/Zurich">>,<<"expected_version">>=>1},K=bright_project_auth:new_id(),
        ?assertEqual({error,invalid_input},bright_account:edit(U,K,M#{<<"timezone">>=><<"Invented/Zone">>})),
        {ok,Edited}=bright_account:edit(U,K,M),?assertEqual({ok,Edited},bright_account:edit(U,K,M)),?assertEqual({error,conflict},bright_account:edit(U,bright_project_auth:new_id(),M)),
        ?assertEqual({error,wrong_password},bright_account:change_password(U,A,#{<<"current_password">>=><<"wrong">>,<<"new_password">>=>New})),
        ?assertEqual({error,invalid_input},bright_account:change_password(U,A,#{<<"current_password">>=>Old,<<"new_password">>=><<"short">>})),
        {ok,_}=bright_account:change_password(U,A,#{<<"current_password">>=>Old,<<"new_password">>=>New}),
        ?assertEqual({error,unauthenticated},bright_identity:authenticate_token(A)),?assertEqual({error,unauthenticated},bright_identity:authenticate_token(B)),
        ?assertEqual({error,unauthenticated},bright_session:login(Email,Old)),{ok,C}=bright_session:login(Email,New),
        ?assertEqual({ok,U},bright_identity:authenticate_token(C)),
        ?assertEqual({error,unauthenticated},bright_account:change_password(U,A,#{<<"current_password">>=>New,<<"new_password">>=>Old})),
        {ok,After}=bright_account:read(U),?assertEqual(<<"Reader">>,maps:get(display_name,After)),?assertEqual(<<"Europe/Zurich">>,maps:get(timezone,After))
    after restore("STUDIO_WORKSPACE_ENABLED",Prev) end.
restore(K,false)->os:unsetenv(K);restore(K,V)->os:putenv(K,V).
