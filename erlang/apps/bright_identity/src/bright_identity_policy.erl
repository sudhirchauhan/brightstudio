-module(bright_identity_policy).
-export([allowed/2, authorize/2]).

%% Deny by default. Role must come from a trusted membership lookup,
%% never from a client-supplied request header or form field.
allowed(owner, Action) -> lists:member(Action, [read, create, update, delete, manage_members]);
allowed(admin, Action) -> lists:member(Action, [read, create, update, delete, manage_members]);
allowed(editor, Action) -> lists:member(Action, [read, create, update]);
allowed(viewer, read) -> true;
allowed(_, _) -> false.

authorize(Role, Action) ->
    case allowed(Role, Action) of
        true -> ok;
        false -> {error, forbidden}
    end.
