-module(bright_project_auth).
-export([list/1, authorize/2, uuid/1, new_id/0]).
uuid(Id) when is_binary(Id) ->
    case re:run(Id, <<"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$">>, [{capture, none}]) of
        match -> true; _ -> false
    end;
uuid(_) -> false.
new_id() ->
    <<A:32,B:16,_:4,C:12,_:2,D:14,E:48>> = crypto:strong_rand_bytes(16),
    iolist_to_binary(io_lib:format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", [A,B,16#4000 bor C,16#8000 bor D,E])).
list(User) ->
    bright_sql_pool:with_connection(fun(C) ->
        case epgsql:equery(C, "SELECT id,title FROM bright_projects WHERE owner_id=$1 ORDER BY created_at,id", [User]) of
            {ok, _, Rows} -> {ok, [#{id => Id, title => Title} || {Id,Title} <- Rows]};
            _ -> {error, unavailable}
        end
    end).
authorize(User, Project) ->
    case uuid(Project) of
        false -> {error, forbidden};
        true -> bright_sql_pool:with_connection(fun(C) ->
            case epgsql:equery(C, "SELECT id FROM bright_projects WHERE id=$1 AND owner_id=$2", [Project, User]) of
                {ok, _, [_]} -> ok;
                {ok, _, []} -> {error, forbidden};
                _ -> {error, unavailable}
            end
        end)
    end.
