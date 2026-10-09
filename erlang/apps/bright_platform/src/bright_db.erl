-module(bright_db).
-export([ping/1]).
ping(Url) ->
    try
        Parsed = uri_string:parse(Url),
        Host = maps:get(host, Parsed, "localhost"),
        Port = maps:get(port, Parsed, 5432),
        UserInfo = maps:get(userinfo, Parsed, ""),
        [User, Password] = case string:split(UserInfo, ":", leading) of [U,P] -> [U,P]; [U] -> [U,""] end,
        Database = string:trim(maps:get(path, Parsed, "/postgres"), leading, "/"),
        case epgsql:connect(Host, User, Password, [{database, Database}, {port, Port}, {timeout, 3000}]) of
            {ok, Conn} ->
                Result = epgsql:squery(Conn, "SELECT 1"),
                epgsql:close(Conn),
                case Result of {ok, _, _} -> ok; _ -> {error, query_failed} end;
            {error, Reason} -> {error, Reason}
        end
    catch _:_ -> {error, invalid_database_configuration} end.
