%% Session token primitives. Never persist or log a bearer token.
-module(bright_identity_token).
-export([new/0, digest/1, matches/2]).

-spec new() -> {binary(), binary()}.
new() ->
    Token = crypto:strong_rand_bytes(32),
    {base64:encode(Token, #{mode => urlsafe, padding => false}), digest(Token)}.

%% A digest of the decoded, canonical 32-byte bearer token.
-spec digest(binary()) -> binary().
digest(Token) when is_binary(Token) ->
    crypto:hash(sha256, Token).

%% Reject noncanonical or malformed tokens without throwing.
-spec matches(term(), term()) -> boolean().
matches(Encoded, ExpectedDigest)
  when is_binary(Encoded), is_binary(ExpectedDigest),
       byte_size(ExpectedDigest) =:= 32, byte_size(Encoded) =:= 43 ->
    try
        Raw = base64:decode(Encoded, #{mode => urlsafe, padding => false}),
        byte_size(Raw) =:= 32 andalso
            crypto:hash_equals(digest(Raw), ExpectedDigest)
    catch _:_ -> false end;
matches(_, _) -> false.
