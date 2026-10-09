-module(bright_identity_password_tests).
-include_lib("eunit/include/eunit.hrl").

password_roundtrip_test() ->
    Password = <<"long-secure-test-password">>,
    Hash = bright_identity_password:hash(Password),
    ?assert(bright_identity_password:verify(Password, Hash)),
    ?assertNot(bright_identity_password:verify(<<"incorrect-password">>, Hash)),
    ?assertNot(bright_identity_password:verify(Password, <<"invalid">>)).

unique_salts_test() ->
    Password = <<"long-secure-test-password">>,
    ?assertNotEqual(bright_identity_password:hash(Password),
                    bright_identity_password:hash(Password)).
