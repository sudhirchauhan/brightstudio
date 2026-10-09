-module(bright_session_tests).
-include_lib("eunit/include/eunit.hrl").
csrf_test() ->
    A = bright_session:csrf(<<"session A">>),
    ?assertEqual(64,byte_size(A)),
    ?assertNotEqual(A,bright_session:csrf(<<"session B">>)).
