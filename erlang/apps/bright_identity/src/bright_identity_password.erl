%% Account lookup and password verification. Never distinguish unknown users from bad passwords.
-module(bright_identity_password).
-export([verify/2, hash/1]).

%% PBKDF2-HMAC-SHA256 with a per-password 16-byte salt and 600k iterations.
%% Stored format: pbkdf2_sha256$600000$<base64 salt>$<base64 digest>
-spec hash(binary()) -> binary().
hash(Password) when is_binary(Password), byte_size(Password) >= 12,
                     byte_size(Password) =< 1024 ->
    Salt = crypto:strong_rand_bytes(16),
    Iterations = 600000,
    Digest = crypto:pbkdf2_hmac(sha256, Password, Salt, Iterations, 32),
    <<"pbkdf2_sha256$600000$", (base64:encode(Salt))/binary, "$",
      (base64:encode(Digest))/binary>>.

-spec verify(binary(), term()) -> boolean().
verify(Password, Encoded) when is_binary(Password), is_binary(Encoded),
                               byte_size(Password) =< 1024 ->
    try
        [<<"pbkdf2_sha256">>, <<"600000">>, Salt64, Digest64] =
            binary:split(Encoded, <<"$">>, [global]),
        Salt = base64:decode(Salt64),
        Expected = base64:decode(Digest64),
        true = byte_size(Salt) =:= 16 andalso byte_size(Expected) =:= 32,
        Actual = crypto:pbkdf2_hmac(sha256, Password, Salt, 600000, 32),
        crypto:hash_equals(Actual, Expected)
    catch _:_ -> false end;
verify(_, _) -> false.
