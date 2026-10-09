%% Persistent session validation. Fail closed on missing DB or invalid tokens.
-module(bright_identity_session).
-export([authenticate/1, revoke/1]).

-spec authenticate(term()) -> {ok, map()} | {error, term()}.
authenticate(Token) when is_binary(Token) ->
    case bright_identity_token:decode_digest(Token) of
        {ok, Digest} ->
            bright_sql_pool:with_connection(fun(Conn) ->
                case epgsql:equery(Conn,
                  "SELECT a.id::text FROM bright_sessions s "
                  "JOIN bright_accounts a ON a.id = s.account_id "
                  "WHERE s.token_digest = $1 AND s.revoked_at IS NULL "
                  "AND s.expires_at > now() AND a.status = 'active'",
                  [Digest]) of
                    {ok, _, [{AccountId}]} -> {ok, #{id => AccountId, status => active}};
                    {ok, _, []} -> {error, unauthorized};
                    {error, _} -> {error, unavailable};
                    _ -> {error, unavailable}
                end
            end);
        error -> {error, unauthorized}
    end;
authenticate(_) -> {error, unauthorized}.

%% Revocation is idempotent. Call only after CSRF validation on mutating HTTP requests.
-spec revoke(term()) -> ok | {error, term()}.
revoke(Token) when is_binary(Token) ->
    case bright_identity_token:decode_digest(Token) of
        {ok, Digest} ->
            bright_sql_pool:with_connection(fun(Conn) ->
                case epgsql:equery(Conn,
                    "UPDATE bright_sessions SET revoked_at = now() "
                    "WHERE token_digest = $1 AND revoked_at IS NULL",
                    [Digest]) of
                    {ok, _} -> ok;
                    {error, _} -> {error, unavailable};
                    _ -> {error, unavailable}
                end
            end);
        error -> {error, unauthorized}
    end;
revoke(_) -> {error, unauthorized}.
