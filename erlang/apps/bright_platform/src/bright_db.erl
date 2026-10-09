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
                case Ssl of
                    true -> [{ssl, required}, {ssl_opts, [
                        {verify, verify_peer}, {cacertfile, os:getenv("BRIGHT_DB_CA_FILE", "/etc/ssl/certs/ca-certificates.crt")},
                        {server_name_indication, Host},
                        {customize_hostname_check, [{match_fun, public_key:pkix_verify_hostname_match_fun(https)}]}
                    ]}];
                    false -> []
                end,
            safe_connect(Host, User, Password, Options);
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

%% Isolate asynchronous connection failure exits. Transfer successful socket ownership
%% only after the caller links it; close it if the caller disappears before transfer.
safe_connect(Host, User, Password, Options) ->
    Caller = self(), Tag = make_ref(),
    {Helper,Monitor} = spawn_monitor(fun() ->
        process_flag(trap_exit,true),
        OwnerMonitor = erlang:monitor(process,Caller),
        Result = try epgsql:connect(Host,User,Password,Options)
                 catch _:_ -> {error,connection_failed} end,
        Caller ! {Tag,Result},
        case Result of
            {ok,C} ->
                receive
                    {Tag,accepted} -> unlink(C);
                    {'DOWN',OwnerMonitor,process,Caller,_} -> epgsql:close(C)
                after 5000 -> epgsql:close(C) end;
            _ -> ok
        end
    end),
    receive
        {Tag,{ok,C}=Result} ->
            link(C), Helper ! {Tag,accepted}, erlang:demonitor(Monitor,[flush]), Result;
        {Tag,Error} -> erlang:demonitor(Monitor,[flush]), Error;
        {'DOWN',Monitor,process,Helper,_} -> {error,connection_failed}
    after 6000 -> exit(Helper,kill), erlang:demonitor(Monitor,[flush]), {error,connection_timeout} end.
