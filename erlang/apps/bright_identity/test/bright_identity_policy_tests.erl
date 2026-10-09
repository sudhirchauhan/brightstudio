-module(bright_identity_policy_tests).
-include_lib("eunit/include/eunit.hrl").

roles_test() ->
    ?assertEqual(ok, bright_identity_policy:authorize(owner, delete)),
    ?assertEqual(ok, bright_identity_policy:authorize(admin, manage_members)),
    ?assertEqual(ok, bright_identity_policy:authorize(editor, update)),
    ?assertEqual(ok, bright_identity_policy:authorize(viewer, read)),
    ?assertEqual({error, forbidden}, bright_identity_policy:authorize(viewer, update)),
    ?assertEqual({error, forbidden}, bright_identity_policy:authorize(editor, manage_members)),
    ?assertEqual({error, forbidden}, bright_identity_policy:authorize(unknown, read)),
    ?assertEqual({error, forbidden}, bright_identity_policy:authorize(admin, unknown)).

invalid_token_test() ->
    ?assertEqual({error, unauthenticated}, bright_identity:authenticate_token(<<"short">>)),
    ?assertEqual({error, unauthenticated}, bright_identity:authenticate_token(undefined)).

invalid_workspace_test() ->
    ?assertEqual({error, forbidden}, bright_identity:authorize_workspace(undefined, undefined, read)).
