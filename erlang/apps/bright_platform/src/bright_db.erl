-module(bright_db).
-export([ping/1, connect/1, parse_url/1]).

ping(Url) ->
    case connect(Url) of
        {ok, Conn} ->
            try
                case epgsql:squery(Conn, "SELECT 1") of
                    {ok, _, _} -> ok;
                    Other -> {error, {query_failed, Other}}
                end
            after epgsql:close(Conn) end;
        Error -> Error
    end.

connect(Url) ->
    case parse_url(Url) of
        {ok, #{host := Host, port := Port, user := User,
               password := Password, database := Database, ssl := Ssl}} ->
            Options = [{database, Database}, {port, Port}, {timeout, 3000}] ++
                case Ssl of true -> [{ssl, true}]; false -> [] end,
            epgsql:connect(Host, User, Password, Options);
        Error -> Error
    end.

%% Never log a DATABASE_URL: it contains credentials.
parse_url(Url) when is_binary(Url) -> parse_url(binary_to_list(Url));
parse_url(Url) when is_list(Url) ->
    try
        Parsed = uri_string:parse(Url),
        Scheme = maps:get(scheme, Parsed),
        true = (Scheme =:= "postgres" orelse Scheme =:= "postgresql"),
        Host = maps:get(host, Parsed),
        true = (Host =/= ""),
        Port = maps:get(port, Parsed, 5432),
        true = is_integer(Port) andalso Port > 0 andalso Port =< 65535,
        UserInfo = maps:get(userinfo, Parsed),
        [UserRaw | PasswordParts] = string:split(UserInfo, ":", all),
        true = (UserRaw =/= "" andalso PasswordParts =/= []),
        PasswordRaw = string:join(PasswordParts, ":"),
        User = uri_string:percent_decode(UserRaw),
        Password = uri_string:percent_decode(PasswordRaw),
        "/" ++ DatabaseRaw = maps:get(path, Parsed),
        true = (DatabaseRaw =/= ""),
        Database = uri_string:percent_decode(DatabaseRaw),
        Query = maps:get(query, Parsed, ""),
        Params = uri_string:dissect_query(Query),
        SslMode = proplists:get_value("sslmode", Params, "disable"),
        true = lists:member(SslMode, ["disable", "require"]),
        {ok, #{host => Host, port => Port, user => User,
               password => Password, database => Database,
               ssl => SslMode =:= "require"}}
    catch _:_ -> {error, invalid_database_configuration} end;
parse_url(_) -> {error, invalid_database_configuration}.
