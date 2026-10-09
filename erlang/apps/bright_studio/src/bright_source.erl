-module(bright_source).
-export([validate/1, create/3, list/2, read/2]).
validate(M) when is_map(M) ->
    Title = maps:get(<<"title">>,M,<<>>), Url = maps:get(<<"url">>,M,<<>>),
    Kind = maps:get(<<"kind">>,M,<<"note">>), Project = maps:get(<<"project_id">>,M,<<>>),
    case is_binary(Title) andalso is_binary(Url) andalso is_binary(Kind) andalso
         byte_size(Title) =< 800 andalso byte_size(Url) =< 2048 andalso
         valid_text(Title) andalso string:length(string:trim(Title)) >= 1 andalso
         string:length(string:trim(Title)) =< 200 andalso valid_url(Url) andalso
         lists:member(Kind,[<<"link">>,<<"book">>,<<"article">>,<<"note">>]) andalso bright_project_auth:uuid(Project) of
        true -> {ok,#{title => string:trim(Title),url => Url,kind => Kind,project_id => string:lowercase(Project)}};
        false -> {error, invalid_input}
    end;
validate(_) -> {error, invalid_input}.
valid_text(B) ->
    case unicode:characters_to_list(B) of
        Chars when is_list(Chars) -> lists:all(fun(C) -> C >= 32 andalso C =/= 127 end,Chars);
        _ -> false
    end.
valid_url(<<>>) -> true;
valid_url(U) ->
    try
        #{scheme := Scheme,host := Host} = uri_string:parse(U),
        (Scheme =:= <<"https">> orelse Scheme =:= <<"http">>) andalso byte_size(Host)>0 andalso valid_text(U)
    catch _:_ -> false end.
create(User,Key,M) when is_binary(Key), byte_size(Key)>=16, byte_size(Key)=<128 ->
    case re:run(Key,<<"^[!-~]{16,128}$">>,[{capture,none}]) of
        match -> create_valid_key(User,Key,M);
        _ -> {error,invalid_input}
    end;
create(_,_,_) -> {error,invalid_input}.
create_valid_key(User,Key,M) ->
    case validate(M) of
        {ok, #{project_id := Project}=Data} ->
            case bright_project_auth:authorize(User,Project) of
                ok -> insert(User,Key,Data);
                Error -> Error
            end;
        Error -> Error
    end.
insert(User,Key,#{title := Title,url := Url,kind := Kind,project_id := Project}) ->
    bright_sql_pool:with_connection(fun(C) ->
        Id = bright_project_auth:new_id(),
        case epgsql:equery(C,"INSERT INTO bright_sources(id,owner_id,project_id,title,url,kind,idempotency_key) VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT(owner_id,idempotency_key) DO NOTHING RETURNING id",[Id,User,Project,Title,Url,Kind,Key]) of
            {ok,1,_,[{Id}]} -> {ok,#{id=>Id,title=>Title,url=>Url,kind=>Kind,project_id=>Project}};
            {ok,0,_,[]} ->
                case epgsql:equery(C,"SELECT id,project_id,title,url,kind FROM bright_sources WHERE owner_id=$1 AND idempotency_key=$2",[User,Key]) of
                    {ok,_,[{Existing,Project,Title,Url,Kind}]} -> {ok,#{id=>Existing,title=>Title,url=>Url,kind=>Kind,project_id=>Project}};
                    {ok,_,[_]} -> {error,conflict};
                    _ -> {error,unavailable}
                end;
            _ -> {error,unavailable}
        end
    end).
list(User,Project) ->
    case bright_project_auth:authorize(User,Project) of
        ok -> query("SELECT id,project_id,title,url,kind FROM bright_sources WHERE owner_id=$1 AND project_id=$2 ORDER BY created_at DESC,id LIMIT 200",[User,Project],list);
        Error -> Error
    end.
read(User,Id) ->
    case bright_project_auth:uuid(Id) of
        true -> query("SELECT id,project_id,title,url,kind FROM bright_sources WHERE owner_id=$1 AND id=$2",[User,Id],read);
        false -> {error,not_found}
    end.
query(Sql,Params,Mode) -> bright_sql_pool:with_connection(fun(C) ->
    case epgsql:equery(C,Sql,Params) of
        {ok,_,Rows} ->
            Items = [#{id=>Id,project_id=>Project,title=>Title,url=>Url,kind=>Kind} || {Id,Project,Title,Url,Kind} <- Rows],
            case {Mode,Items} of {read,[Item]} -> {ok,Item}; {read,[]} -> {error,not_found}; {list,_} -> {ok,Items} end;
        _ -> {error,unavailable}
    end
end).
