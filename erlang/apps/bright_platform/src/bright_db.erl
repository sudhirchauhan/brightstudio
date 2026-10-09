-module(bright_db).
-export([ping/1, connect/1]).
ping(Url) ->
    case connect(Url) of
        {ok, Conn} ->
            try
                Result = epgsql:squery(Conn, "SELECT 1"),
                case Result of {ok, _, _} -> ok; _ -> {error, query_failed} end
            after epgsql:close(Conn) end;
        Error -> Error
    end.
connect(Url) ->
    try
        Parsed = uri_string:parse(Url),
        Host = maps:get(host, Parsed, "localhost"),
        Port = maps:get(port, Parsed, 5432),
        UserInfo = maps:get(userinfo, Parsed, ""),
        [User, Password] = case string:split(UserInfo, ":", leading) of [U,P] -> [U,P]; [U] -> [U,""] end,
        Database = string:trim(maps:get(path, Parsed, "/postgres"), leading, "/"),
        epgsql:connect(Host, User, Password, [{database, Database}, {port, Port}, {timeout, 3000}])
    catch _:_ -> {error, invalid_database_configuration} end.
