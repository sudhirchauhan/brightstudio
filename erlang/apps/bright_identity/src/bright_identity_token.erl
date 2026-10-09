%% Session token primitives. Never persist or log a bearer token.
-module(bright_identity_token).
-export([new/0, digest/1, decode_digest/1, matches/2]).

-spec new() -> {binary(), binary()}.
new() ->
    Token = crypto:strong_rand_bytes(32),
    {base64:encode(Token, #{mode => urlsafe, padding => false}), digest(Token)}.

%% A digest of the decoded, canonical 32-byte bearer token.
-spec digest(binary()) -> binary().
digest(Token) when is_binary(Token) ->
    crypto:hash(sha256, Token).

%% Decode only canonical URL-safe, unpadded tokens.\n-spec decode_digest(term()) -> {ok, binary()} | error.\ndecode_digest(Encoded) when is_binary(Encoded), byte_size(Encoded) =:= 43 ->\n    try\n        Raw = base64:decode(Encoded, #{mode => urlsafe, padding => false}),\n        case byte_size(Raw) =:= 32 andalso\n             base64:encode(Raw, #{mode => urlsafe, padding => false}) =:= Encoded of\n            true -> {ok, digest(Raw)};\n            false -> error\n        end\n    catch _:_ -> error end;\ndecode_digest(_) -> error.\n\n%% Reject noncanonical or malformed tokens without throwing.
-spec matches(term(), term()) -> boolean().
matches(Encoded, ExpectedDigest)
  when is_binary(Encoded), is_binary(ExpectedDigest),
       byte_size(ExpectedDigest) =:= 32, byte_size(Encoded) =:= 43 ->
    case decode_digest(Encoded) of
        {ok, ActualDigest} -> crypto:hash_equals(ActualDigest, ExpectedDigest);
        error -> false
    end;
matches(_, _) -> false.
