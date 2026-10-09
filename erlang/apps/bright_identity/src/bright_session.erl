-module(bright_session).
-export([login/2, revoke/1, csrf/1, password_hash/2, provision/3]).
password_hash(Password, Salt) -> crypto:pbkdf2_hmac(sha256, Password, Salt, 600000, 32).
csrf(Token) -> binary:encode_hex(crypto:hash(sha256, <<"csrf:",Token/binary>>), lowercase).
login(Email, Password) when is_binary(Email), is_binary(Password), byte_size(Email) =< 254, byte_size(Password) =< 1024 ->
    bright_sql_pool:with_connection(fun(C) ->
        Result = epgsql:equery(C, "SELECT u.id,c.salt,c.password_hash FROM bright_users u JOIN bright_credentials c ON c.user_id=u.id WHERE u.email=$1 AND u.disabled_at IS NULL", [Email]),
        case Result of
            {ok, _, [{Id,Salt,Hash}]} ->
                case crypto:hash_equals(Hash, password_hash(Password,Salt)) of
                    true -> create(C,Id);
                    false -> {error, unauthenticated}
                end;
            {ok, _, []} -> _ = password_hash(Password, <<0:128>>), {error, unauthenticated};
            _ -> {error, unavailable}
        end
    end);
login(_, _) -> {error, unauthenticated}.
create(C,Id) ->
    Token = binary:encode_hex(crypto:strong_rand_bytes(32), lowercase),
    case epgsql:equery(C, "INSERT INTO bright_sessions(token_hash,user_id,expires_at) VALUES($1,$2,now()+interval '8 hours')", [crypto:hash(sha256,Token),Id]) of
        {ok,1} -> {ok,Token}; _ -> {error, unavailable}
    end.
revoke(Token) ->
    bright_sql_pool:with_connection(fun(C) ->
        case epgsql:equery(C,"UPDATE bright_sessions SET revoked_at=now() WHERE token_hash=$1",[crypto:hash(sha256,Token)]) of
            {ok,_} -> ok; _ -> {error, unavailable}
        end
    end).
%% Explicit operator provisioning; no public signup or development authentication bypass.
%% Supply credentials securely to the release process, never on its command line.
provision(Email, Password, ProjectTitle) when is_binary(Email), is_binary(Password), byte_size(Password) >= 12, byte_size(Password) =< 1024 ->
    Id = bright_project_auth:new_id(), Project = bright_project_auth:new_id(), Salt = crypto:strong_rand_bytes(16),
    Hash = password_hash(Password,Salt),
    bright_sql_pool:with_connection(fun(C) ->
        epgsql:with_transaction(C, fun(T) ->
            {ok,1} = epgsql:equery(T,"INSERT INTO bright_users(id,email) VALUES($1,$2)",[Id,Email]),
            {ok,1} = epgsql:equery(T,"INSERT INTO bright_credentials(user_id,salt,password_hash) VALUES($1,$2,$3)",[Id,Salt,Hash]),
            {ok,1} = epgsql:equery(T,"INSERT INTO bright_projects(id,owner_id,title) VALUES($1,$2,$3)",[Project,Id,ProjectTitle]),
            {ok,Id,Project}
        end)
    end).
