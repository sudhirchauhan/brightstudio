-module(bright_identity).
-export([authenticate_token/1, authorize_workspace/3, profile/1]).

%% Tokens are opaque high-entropy values. Store only their SHA-256 hashes.
%% No session creation/login endpoint is exposed until authentication is complete.
authenticate_token(Token) when is_binary(Token), byte_size(Token) >= 32, byte_size(Token) =< 128 ->
    Hash = crypto:hash(sha256, Token),
    bright_sql_pool:with_connection(fun(Conn) ->
        case epgsql:equery(Conn,
            "SELECT u.id FROM bright_sessions s JOIN bright_users u ON u.id = s.user_id "
            "WHERE s.token_hash = $1 AND s.revoked_at IS NULL "
            "AND s.expires_at > now() AND u.disabled_at IS NULL",
            [Hash]) of
            {ok, _, [{UserId}]} -> {ok, UserId};
            {ok, _, []} -> {error, unauthenticated};
            {error, _} -> {error, unavailable};
            _ -> {error, unavailable}
        end
    end);
authenticate_token(_) -> {error, unauthenticated}.

authorize_workspace(UserId, WorkspaceId, Action) when is_binary(UserId), is_binary(WorkspaceId) ->
    bright_sql_pool:with_connection(fun(Conn) ->
        case epgsql:equery(Conn,
            "SELECT role FROM bright_memberships m JOIN bright_users u ON u.id = m.user_id "
            "WHERE m.user_id = $1::uuid AND m.workspace_id = $2::uuid "
            "AND u.disabled_at IS NULL", [UserId, WorkspaceId]) of
            {ok, _, [{Role}]} ->
                bright_identity_policy:authorize(role_atom(Role), Action);
            {ok, _, []} -> {error, forbidden};
            _ -> {error, unavailable}
        end
    end);
authorize_workspace(_, _, _) -> {error, forbidden}.

role_atom(<<"owner">>) -> owner;
role_atom(<<"admin">>) -> admin;
role_atom(<<"editor">>) -> editor;
role_atom(<<"viewer">>) -> viewer;
role_atom(_) -> unknown.

profile(User) -> bright_sql_pool:with_connection(fun(C) ->
    case epgsql:equery(C,"SELECT email FROM bright_users WHERE id=$1 AND disabled_at IS NULL",[User]) of
        {ok,_,[{Email}]} -> {ok,#{email=>Email}};
        {ok,_,[]} -> {error,unauthenticated};
        _ -> {error,unavailable}
    end
end).
