-module(bright_project_auth_tests).
-include_lib("eunit/include/eunit.hrl").
uuid_test() ->
    ?assert(bright_project_auth:uuid(bright_project_auth:new_id())),
    ?assertNot(bright_project_auth:uuid(<<"bad">>)),
    ?assertNot(bright_project_auth:uuid(undefined)).
