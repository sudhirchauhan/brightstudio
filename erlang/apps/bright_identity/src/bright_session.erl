-module(bright_session).
-export([login/2, revoke/1, csrf/1, password_hash/2, provision/3]).
password_hash(Password, Salt) -> crypto:pbkdf2_hmac(sha256, Password, Salt, 600000, 32).
csrf(Token) -> binary:encode_hex(crypto:hash(sha256, <<"csrf:",Token/binary>>), lowercase).
login(Email, Password) when is_binary(Email), is_binary(Password), byte_size(Email) =< 254, byte_size(Password) =< 1024 ->
    bright_sql_pool:with_connection(fun(C) ->
      R=bright_sql:with_transaction(C,fun(T)->
        %% Lock first, then read credentials in a new statement snapshot.
        %% PostgreSQL can retain joined credential values read before a lock wait.
        case bright_sql:equery(T,"SELECT id FROM bright_users WHERE email=$1 AND disabled_at IS NULL FOR UPDATE",[Email]) of
            {ok,_,[{Id}]}->case bright_sql:equery(T,"SELECT salt,password_hash FROM bright_credentials WHERE user_id=$1",[Id]) of
                {ok,_,[{Salt,Hash}]}->case crypto:hash_equals(Hash,password_hash(Password,Salt)) of true->create(T,Id);false->{error,unauthenticated} end;
                {ok,_,[]}->{error,unauthenticated};_->{error,unavailable} end;
            {ok,_,[]}->_=password_hash(Password,<<0:128>>),{error,unauthenticated};
            _->{error,unavailable}
        end
      end),case R of {ok,_}->R;{error,_}->R;_->{error,unavailable} end
    end);
login(_, _) -> {error, unauthenticated}.
create(C,Id) ->
    Token = binary:encode_hex(crypto:strong_rand_bytes(32), lowercase),
    case bright_sql:equery(C, "INSERT INTO bright_sessions(token_hash,user_id,expires_at) VALUES($1,$2,now()+interval '8 hours')", [crypto:hash(sha256,Token),Id]) of
        {ok,1} -> {ok,Token}; _ -> {error, unavailable}
    end.
revoke(Token) ->
    bright_sql_pool:with_connection(fun(C) ->
        case bright_sql:equery(C,"UPDATE bright_sessions SET revoked_at=now() WHERE token_hash=$1",[crypto:hash(sha256,Token)]) of
            {ok,_} -> ok; _ -> {error, unavailable}
        end
    end).
%% Explicit operator provisioning; no public signup or development authentication bypass.
%% Supply credentials securely to the release process, never on its command line.
provision(Email, Password, ProjectTitle) when is_binary(Email), is_binary(Password), byte_size(Password) >= 12, byte_size(Password) =< 1024 ->
    Id = bright_project_auth:new_id(), Project = bright_project_auth:new_id(), Salt = crypto:strong_rand_bytes(16),
    Hash = password_hash(Password,Salt),
    bright_sql_pool:with_connection(fun(C) ->
        bright_sql:with_transaction(C, fun(T) ->
            {ok,1} = bright_sql:equery(T,"INSERT INTO bright_users(id,email) VALUES($1,$2)",[Id,Email]),
            {ok,1} = bright_sql:equery(T,"INSERT INTO bright_credentials(user_id,salt,password_hash) VALUES($1,$2,$3)",[Id,Salt,Hash]),
            {ok,1} = bright_sql:equery(T,"INSERT INTO bright_projects(id,owner_id,title) VALUES($1,$2,$3)",[Project,Id,ProjectTitle]),
            {ok,Id,Project}
        end)
    end).
