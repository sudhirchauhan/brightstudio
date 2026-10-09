%% Explicit, fail-closed owner authorization for domain command boundaries.
%% Callers must obtain the authenticated principal from verified session middleware.
-module(bright_identity_authorize).
-export([owner/2, owner/3]).

-spec owner(term(), term()) -> ok | {error, forbidden}.
owner(Principal, Resource) -> owner(Principal, Resource, read).

-spec owner(term(), term(), read | write | delete) -> ok | {error, forbidden}.
owner(#{id := PrincipalId, status := active}, #{owner_id := OwnerId}, Action)
  when is_binary(PrincipalId), byte_size(PrincipalId) > 0,
       is_binary(OwnerId), byte_size(OwnerId) > 0,
       (Action =:= read orelse Action =:= write orelse Action =:= delete) ->
    case PrincipalId =:= OwnerId of
        true -> ok;
        false -> {error, forbidden}
    end;
owner(_, _, _) ->
    {error, forbidden}.
