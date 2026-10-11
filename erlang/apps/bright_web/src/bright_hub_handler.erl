-module(bright_hub_handler).
-behaviour(cowboy_handler).
-export([init/2]).
init(Req,Route) ->
    case {os:getenv("STUDIO_HUB_ENABLED"),(library_route(Route) andalso not bright_library:enabled()) orelse (evidence_route(Route) andalso not bright_evidence:enabled())} of
        {"true",false} ->
            try dispatch(Req,Route)
            catch _:_ -> reply(503,#{error => unavailable},Req,Route) end;
        _ -> reply(404,#{error => not_found},Req,Route)
    end.
dispatch(Req,{public_asset,Name,Type}=Route) ->
    case cowboy_req:method(Req) of
        <<"GET">> -> case file:read_file(filename:join([code:priv_dir(bright_web),"static",Name])) of
            {ok,B} -> raw(200,Type,B,Req,Route);
            _ -> reply(404,#{error=>not_found},Req,Route)
        end;
        _ -> reply(405,#{error=>method_not_allowed},Req,Route)
    end;
dispatch(Req,login_page) ->
    case cowboy_req:method(Req) of <<"GET">> -> html(bright_hub_view:login(),Req,login_page); _ -> reply(405,#{error=>method_not_allowed},Req,login_page) end;
dispatch(Req,login) ->
    case {cowboy_req:method(Req),same_origin(Req)} of
        {<<"POST">>,true} ->
            case bright_login_limit:allow(cowboy_req:peer(Req)) of
                true -> body(Req,fun(M,R) ->
                    case bright_session:login(maps:get(<<"email">>,M,undefined),maps:get(<<"password">>,M,undefined)) of
                        {ok,Token} ->
                            R1 = cowboy_req:set_resp_cookie(<<"bright_session">>,Token,R,cookie_options()),
                            reply(200,#{csrf=>bright_session:csrf(Token)},R1,login);
                        Error -> error_reply(Error,R,login)
                    end
                end,login);
                false -> reply(429,#{error=>rate_limited},Req,login)
            end;
        {<<"POST">>,false} -> reply(403,#{error=>forbidden},Req,login);
        _ -> reply(405,#{error=>method_not_allowed},Req,login)
    end;
dispatch(Req,Route) ->
    Cookies = cowboy_req:parse_cookies(Req), Token = proplists:get_value(<<"bright_session">>,Cookies,<<>>),
    case bright_identity:authenticate_token(Token) of
        {ok,User} -> authorized(Req,Route,User,Token);
        Error -> error_reply(Error,Req,Route)
    end.
authorized(Req,Route,User,Token) ->
    Method = cowboy_req:method(Req),
    case Method of
        <<"GET">> -> get(Req,Route,User,Token);
        <<"POST">> ->
            case same_origin(Req) andalso valid_csrf(Req,Token) of
                true -> post(Req,Route,User,Token);
                false -> reply(403,#{error=>forbidden},Req,Route)
            end;
        _ -> reply(405,#{error=>method_not_allowed},Req,Route)
    end.
get(Req,session,User,Token) ->
    case bright_identity:profile(User) of
        {ok,Profile} -> reply(200,Profile#{csrf=>bright_session:csrf(Token),library_enabled=>bright_library:enabled(),evidence_enabled=>bright_evidence:enabled()},Req,session);
        Error -> error_reply(Error,Req,session)
    end;
get(Req,evidence,User,_) ->
    P=cowboy_req:parse_qs(Req),result(bright_evidence:list(User,proplists:get_value(<<"source_id">>,P,<<>>),proplists:get_value(<<"revision_id">>,P,<<>>)),Req,evidence);
get(Req,evidence_item,User,_) -> result(bright_evidence:read(User,cowboy_req:binding(id,Req)),Req,evidence_item);
get(Req,evidence_notes,User,_) -> result(bright_evidence:history(User,cowboy_req:binding(id,Req)),Req,evidence_notes);
get(Req,boards,User,_) -> result(bright_evidence:boards(User,proplists:get_value(<<"project_id">>,cowboy_req:parse_qs(Req),<<>>)),Req,boards);
get(Req,board,User,_) -> result(bright_evidence:board(User,cowboy_req:binding(id,Req)),Req,board);
get(Req,evidence_page,_,_) -> html(bright_hub_view:render(),Req,evidence_page);
get(Req,{evidence_asset,Name,Type},User,Token) -> get(Req,{asset,Name,Type},User,Token);
get(Req,projects,User,_) -> result(bright_project_auth:list(User),Req,projects);
get(Req,sources,User,_) ->
    Params = cowboy_req:parse_qs(Req), Project = proplists:get_value(<<"project_id">>,Params,<<>>),
    result(bright_source:list(User,Project),Req,sources);
get(Req,library_state,User,_) ->
    Project=proplists:get_value(<<"project_id">>,cowboy_req:parse_qs(Req),<<>>),
    result(bright_library:states(User,Project),Req,library_state);
get(Req,revisions,User,_) -> result(bright_library:revisions(User,cowboy_req:binding(id,Req)),Req,revisions);
get(Req,revision_content,User,_) -> result(bright_library:content(User,cowboy_req:binding(id,Req),cowboy_req:binding(revision,Req)),Req,revision_content);
get(Req,revision_original,User,_) ->
    case bright_library:original(User,cowboy_req:binding(id,Req),cowboy_req:binding(revision,Req)) of
        {ok,#{mime:=Mime,data:=Data}} ->
            R=cowboy_req:set_resp_header(<<"content-disposition">>,<<"attachment; filename=source-original">>,Req),
            raw(200,Mime,Data,R,revision_original);
        Error->error_reply(Error,Req,revision_original)
    end;
get(Req,source,User,_) -> result(bright_source:read(User,cowboy_req:binding(id,Req)),Req,source);
get(Req,reader,User,_) ->
    case bright_source:read(User,cowboy_req:binding(id,Req)) of
        {ok,_} -> html(bright_hub_view:render(),Req,reader);
        Error -> error_reply(Error,Req,reader)
    end;
get(Req,Page,_User,_) when Page =:= hub; Page =:= library -> html(bright_hub_view:render(),Req,Page);
get(Req,{asset,Name,Type}=Route,_User,_) ->
    case file:read_file(filename:join([code:priv_dir(bright_web),"static",Name])) of
        {ok,Bytes} -> raw(200,Type,Bytes,Req,Route);
        _ -> reply(404,#{error=>not_found},Req,Route)
    end;
get(Req,Route,_,_) -> reply(405,#{error=>method_not_allowed},Req,Route).
post(Req,evidence,User,_) ->
    body(Req,fun(M,R)->created(bright_evidence:create(User,cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,evidence) end,evidence);
post(Req,evidence_notes,User,_) ->
    body(Req,fun(M,R)->result(bright_evidence:edit(User,cowboy_req:binding(id,R),cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,evidence_notes) end,evidence_notes);
post(Req,boards,User,_) ->
    body(Req,fun(M,R)->created(bright_evidence:create_board(User,cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,boards) end,boards);
post(Req,board_links,User,_) ->
    body(Req,fun(M,R)->result(bright_evidence:link(User,cowboy_req:binding(id,R),maps:get(<<"evidence_id">>,M,undefined)),R,board_links) end,board_links);
post(Req,sources,User,_) ->
    Key = cowboy_req:header(<<"idempotency-key">>,Req,<<>>),
    body(Req,fun(M,R) ->
        case bright_source:create(User,Key,M) of
            {ok,Source} -> reply(201,Source,R,sources);
            Error -> error_reply(Error,R,sources)
        end
    end,sources);
post(Req,revisions,User,_) ->
    Mime=hd(binary:split(cowboy_req:header(<<"content-type">>,Req,<<>>),<<";">>)),
    case lists:member(Mime,[<<"text/plain">>,<<"application/pdf">>,<<"application/epub+zip">>]) of
        false->reply(415,#{error=>unsupported_type},Req,revisions);
        true->
            Name=try uri_string:percent_decode(cowboy_req:header(<<"x-upload-filename">>,Req,<<>>)) catch _:_ -> undefined end,
            Key=cowboy_req:header(<<"idempotency-key">>,Req,<<>>),
            case upload_body(Req,[],0) of
                {ok,Data,R}->case bright_library:upload(User,cowboy_req:binding(id,R),Key,#{filename=>Name,mime=>Mime,data=>Data}) of
                    {ok,Revision}->reply(201,Revision,R,revisions);
                    Error->error_reply(Error,R,revisions)
                end;
                {too_large,R}->reply(413,#{error=>body_too_large},R,revisions)
            end
    end;
post(Req,revision_retry,User,_) ->
    case bright_library:retry(User,cowboy_req:binding(id,Req),cowboy_req:binding(revision,Req)) of
        {ok,Value}->reply(202,Value,Req,revision_retry);
        Error->error_reply(Error,Req,revision_retry)
    end;
post(Req,logout,_,Token) ->
    case bright_session:revoke(Token) of
        ok -> R = cowboy_req:set_resp_cookie(<<"bright_session">>,<<>>,Req,(cookie_options())#{max_age=>0}), reply(200,#{ok=>true},R,logout);
        Error -> error_reply(Error,Req,logout)
    end;
post(Req,Route,_,_) -> reply(405,#{error=>method_not_allowed},Req,Route).
upload_body(Req,Chunks,Size) ->
    {State,Chunk,R}=cowboy_req:read_body(Req,#{length=>65536,period=>5000}),
    case Size+byte_size(Chunk)=<4194304 of
        false->{too_large,R};
        true->case State of
            ok->{ok,iolist_to_binary(lists:reverse([Chunk|Chunks])),R};
            more->upload_body(R,[Chunk|Chunks],Size+byte_size(Chunk))
        end
    end.
created({ok,Value},Req,Route)->reply(201,Value,Req,Route);
created(Error,Req,Route)->error_reply(Error,Req,Route).
evidence_route({evidence_asset,_,_})->true;
evidence_route(Route)->lists:member(Route,[evidence_page,evidence,evidence_item,evidence_notes,boards,board,board_links]).
library_route(Route)->lists:member(Route,[library_state,revisions,revision_content,revision_original,revision_retry]).
body(Req,Fun,Route) ->
    case cowboy_req:header(<<"content-type">>,Req,<<>>) of
        <<"application/json",_/binary>> ->
            case cowboy_req:read_body(Req,#{length=>32768,period=>5000}) of
                {ok,B,R} when byte_size(B)=<32768 ->
                    Decoded = try jsx:decode(B,[return_maps]) catch _:_ -> invalid end,
                    case is_map(Decoded) of true -> Fun(Decoded,R); false -> reply(400,#{error=>invalid_input},R,Route) end;
                {_,_,R} -> reply(413,#{error=>body_too_large},R,Route)
            end;
        _ -> reply(415,#{error=>content_type},Req,Route)
    end.
same_origin(Req) ->
    case os:getenv("BRIGHT_ORIGIN") of
        false -> false;
        Origin -> cowboy_req:header(<<"origin">>,Req) =:= list_to_binary(Origin)
    end.
valid_csrf(Req,Token) ->
    Given = cowboy_req:header(<<"x-csrf-token">>,Req,<<>>), Expected = bright_session:csrf(Token),
    byte_size(Given) =:= byte_size(Expected) andalso crypto:hash_equals(Given,Expected).
cookie_options() ->
    Local = lists:member(os:getenv("BRIGHT_ORIGIN"),["http://127.0.0.1:10000","http://localhost:10000"]),
    #{path=><<"/studio/">>,http_only=>true,same_site=>strict,max_age=>28800,
      secure=>not (Local andalso os:getenv("BRIGHT_INSECURE_LOCAL_COOKIE") =:= "true")}.
result({ok,Value},Req,Route) -> reply(200,Value,Req,Route);
result(Error,Req,Route) -> error_reply(Error,Req,Route).
error_reply({error,Reason},Req,Route) ->
    {Code,Public} = case Reason of
        unauthenticated -> {401,unauthenticated}; forbidden -> {403,forbidden};
        disabled -> {404,not_found}; quota_exceeded -> {413,quota_exceeded}; not_ready -> {409,not_ready};
        not_found -> {404,not_found}; invalid_input -> {400,invalid_input}; conflict -> {409,conflict};
        _ -> {503,unavailable}
    end,
    reply(Code,#{error=>Public},Req,Route).
reply(Code,Value,Req,Route) -> raw(Code,<<"application/json; charset=utf-8">>,jsx:encode(Value),Req,Route).
html(Bytes,Req,Route) -> raw(200,<<"text/html; charset=utf-8">>,Bytes,Req,Route).
raw(Code,Type,Bytes,Req,Route) ->
    Headers = #{<<"content-type">>=>Type,<<"cache-control">>=><<"no-store">>,
        <<"x-content-type-options">>=><<"nosniff">>,<<"referrer-policy">>=><<"same-origin">>,
        <<"content-security-policy">>=><<"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'">>},
    {ok,cowboy_req:reply(Code,Headers,Bytes,Req),Route}.
