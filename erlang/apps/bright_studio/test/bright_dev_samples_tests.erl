-module(bright_dev_samples_tests).
-include_lib("eunit/include/eunit.hrl").
samples_test_()->case {os:getenv("BRIGHT_INTEGRATION_TESTS"),os:getenv("DATABASE_URL")} of
    {"true","sqlite:"++_}->{timeout,90,fun samples/0};
    _->[]
end.
samples()->
    Previous=os:getenv("BRIGHT_SQLITE_DEVELOPMENT"),
    os:putenv("BRIGHT_SQLITE_DEVELOPMENT","true"),
    try
        {ok,_}=application:ensure_all_started(bright_platform),ok=bright_migrate:run(),
        {ok,U,P}=bright_session:provision(<<(bright_project_auth:new_id())/binary,"@samples.test">>,<<"Private-local-samples-password">>,<<"Sample project">>),
        ok=bright_dev_samples:run(U,P),
        {ok,Sources}=bright_source:list(U,P),?assertEqual(7,length(Sources)),
        Revisions=lists:append([begin {ok,Rs}=bright_library:revisions(U,maps:get(id,S)),Rs end||S<-Sources]),
        ?assertEqual(7,length(Revisions)),
        ?assertEqual(6,length([R||R<-Revisions,maps:get(state,R)=:= <<"ready">>])),
        ?assertEqual(1,length([R||R<-Revisions,maps:get(state,R)=:= <<"failed">>])),
        Items=lists:append([begin {ok,Es}=bright_evidence:list(U,maps:get(id,S),<<>>),Es end||S<-Sources]),
        ?assertEqual(7,length(Items)),
        ?assert(lists:all(fun(E)->maps:get(anchor_state,E)=:=resolved end,Items)),
        {ok,Boards}=bright_evidence:boards(U,P),?assertEqual(2,length(Boards)),
        [Edited]=[E||E<-Items,maps:get(version,E)=:=2],
        Id=maps:get(id,Edited),{ok,History}=bright_evidence:history(U,Id),?assertEqual(2,length(History)),
        {ok,_}=bright_evidence:edit(U,Id,bright_project_auth:new_id(),#{<<"note">>=><<"User-edited sample note">>,<<"expected_version">>=>2}),
        ok=bright_dev_samples:run(U,P),
        {ok,After}=bright_evidence:read(U,Id),?assertEqual(<<"User-edited sample note">>,maps:get(note,After)),
        {ok,Again}=bright_source:list(U,P),?assertEqual(7,length(Again))
    after case Previous of false->os:unsetenv("BRIGHT_SQLITE_DEVELOPMENT");V->os:putenv("BRIGHT_SQLITE_DEVELOPMENT",V) end end.
