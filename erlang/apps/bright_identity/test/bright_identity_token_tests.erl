-module(bright_identity_token_tests).
-include_lib("eunit/include/eunit.hrl").

token_round_trip_test() ->
    {Encoded, Digest} = bright_identity_token:new(),
    ?assertEqual(43, byte_size(Encoded)),
    ?assertEqual(32, byte_size(Digest)),
    ?assert(bright_identity_token:matches(Encoded, Digest)),
    ?assertNot(bright_identity_token:matches(Encoded, <<0:256>>)),
    ?assertNot(bright_identity_token:matches(<<"bad">>, Digest)),
    ?assertNot(bright_identity_token:matches(Encoded, <<"bad">>)).

unique_token_test() ->
    {Token1, Digest1} = bright_identity_token:new(),
    {Token2, Digest2} = bright_identity_token:new(),
    ?assertNotEqual(Token1, Token2),
    ?assertNotEqual(Digest1, Digest2).

canonical_token_test() ->
    {Token, Digest} = bright_identity_token:new(),
    ?assertEqual({ok, Digest}, bright_identity_token:decode_digest(Token)),
    ?assertEqual(error, bright_identity_token:decode_digest(<<"bad">>)),
    ?assertEqual(error, bright_identity_token:decode_digest(<<"+", (binary:part(Token, 1, 42))/binary>>)).
