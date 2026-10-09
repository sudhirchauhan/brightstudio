-module(bright_ready).
-export([check/0]).
check() ->
    try
        case os:getenv("DATABASE_URL") of
            false -> {error,unavailable};
            Url ->
                case os:getenv("STUDIO_HUB_ENABLED") of
                    "true" ->
                        true = valid_origin(),
                        Versions = case bright_library:enabled() of true->[2,3,4,5,6,7,8,9];false->[2,3,4,5,6,7] end,
                        bright_sql_pool:with_connection(fun(C) ->
                            case epgsql:equery(C,"SELECT count(*) FROM bright_schema_migrations WHERE version=ANY($1::bigint[])",[Versions]) of
                                {ok,_,[{Count}]} when Count=:=length(Versions) -> ok;
                                _ -> {error,unavailable}
                            end
                        end);
                    _ -> bright_db:ping(Url)
                end
        end
    catch _:_ -> {error,unavailable} end.
valid_origin() ->
    case os:getenv("BRIGHT_ORIGIN") of
        false -> false;
        Origin ->
            case uri_string:parse(Origin) of
                #{scheme := "https",host := Host}=Parsed when Host =/= "" ->
                    not maps:is_key(userinfo,Parsed) andalso not maps:is_key(query,Parsed) andalso
                    not maps:is_key(fragment,Parsed) andalso maps:get(path,Parsed,"") =:= "";
                _ -> lists:member(Origin,["http://localhost:10000","http://127.0.0.1:10000"]) andalso
                     os:getenv("BRIGHT_INSECURE_LOCAL_COOKIE") =:= "true"
            end
    end.
