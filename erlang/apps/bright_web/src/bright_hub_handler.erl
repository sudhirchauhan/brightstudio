-module(bright_hub_handler).
-behaviour(cowboy_handler).
-export([init/2]).
init(Req,Route) ->
    case {os:getenv("STUDIO_HUB_ENABLED"),(library_route(Route) andalso not bright_library:enabled()) orelse (evidence_route(Route) andalso not bright_evidence:enabled()) orelse (study_route(Route) andalso not bright_study:enabled()) orelse (workspace_route(Route) andalso not bright_workspace:enabled()) orelse (focus_route(Route) andalso not bright_focus:enabled()) orelse (documents_route(Route) andalso not bright_documents:enabled()) orelse (assistant_route(Route) andalso not bright_assistant:enabled()) orelse (media_route(Route) andalso not bright_media:enabled()) orelse (offline_route(Route) andalso not bright_offline:enabled()) orelse (access_route(Route) andalso not bright_access:enabled())} of
        {"true",false} ->
            try dispatch(Req,Route)
            catch _:_ -> reply(503,#{error => unavailable},Req,Route) end;
        _ -> reply(404,#{error => not_found},Req,Route)
    end.
dispatch(Req,Route) when Route=:=recovery_page;Route=:=reset_page ->
    case cowboy_req:method(Req) of <<"GET">>->html(bright_access_view:recovery(Route=:=reset_page),Req,Route);_->reply(405,#{error=>method_not_allowed},Req,Route) end;
dispatch(Req,recovery_asset)->case cowboy_req:method(Req) of <<"GET">>->case read_assets(["offline-cleanup.js","recovery.js"]) of {ok,B}->raw(200,<<"text/javascript">>,B,Req,recovery_asset);_->reply(404,#{error=>not_found},Req,recovery_asset) end;_->reply(405,#{error=>method_not_allowed},Req,recovery_asset) end;
dispatch(Req,recovery_availability)->case cowboy_req:method(Req) of <<"GET">>->reply(200,#{available=>bright_recovery:available()},Req,recovery_availability);_->reply(405,#{error=>method_not_allowed},Req,recovery_availability) end;
dispatch(Req,Route) when Route=:=recovery_request;Route=:=recovery_reset ->
    case {cowboy_req:method(Req),same_origin(Req)} of
        {<<"POST">>,true}->case bright_login_limit:allow_recovery(cowboy_req:peer(Req)) of
            true->body(Req,fun(M,R)->case Route of
                recovery_request->case bright_mutation:keys(M,[<<"email">>]) of true->result(bright_recovery:request(maps:get(<<"email">>,M,undefined)),R,Route);false->reply(400,#{error=>invalid_input},R,Route) end;
                recovery_reset->case bright_mutation:keys(M,[<<"token">>,<<"new_password">>]) of true->result(bright_recovery:reset(maps:get(<<"token">>,M,undefined),maps:get(<<"new_password">>,M,undefined)),R,Route);false->reply(400,#{error=>invalid_input},R,Route) end
            end end,Route);
            false->reply(429,#{error=>rate_limited},Req,Route) end;
        {<<"POST">>,false}->reply(403,#{error=>forbidden},Req,Route);_->reply(405,#{error=>method_not_allowed},Req,Route) end;
dispatch(Req,{offline_public,Name,Type}) -> dispatch(Req,{public_asset,Name,Type});
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
        {ok,Profile} -> reply(200,Profile#{csrf=>bright_session:csrf(Token),library_enabled=>bright_library:enabled(),evidence_enabled=>bright_evidence:enabled(),study_enabled=>bright_study:enabled(),workspace_enabled=>bright_workspace:enabled(),focus_enabled=>bright_focus:enabled(),documents_enabled=>bright_documents:enabled(),assistant_enabled=>bright_assistant:enabled(),audio_enabled=>bright_media:enabled(),offline_enabled=>bright_offline:enabled(),access_enabled=>bright_access:enabled(),user_id=>User},Req,session);
        Error -> error_reply(Error,Req,session)
    end;
get(Req,access_page,_,_)->html(bright_access_view:render(),Req,access_page);
get(Req,access_asset,_,_)->case read_assets(["offline-cleanup.js","access.js"]) of {ok,B}->raw(200,<<"text/javascript">>,B,Req,access_asset);_->reply(404,#{error=>not_found},Req,access_asset) end;
get(Req,access_recovery,_,_)->reply(200,#{available=>bright_recovery:available()},Req,access_recovery);
get(Req,access_sessions,U,T)->result(bright_access:sessions(U,T),Req,access_sessions);
get(Req,access_workspaces,U,_)->result(bright_membership:list(U),Req,access_workspaces);
get(Req,access_workspace,U,_)->result(bright_membership:read(U,cowboy_req:binding(id,Req)),Req,access_workspace);
get(Req,workspace_page,_,_) -> html(bright_hub_view:render(),Req,workspace_page);
get(Req,{workspace_asset,Name,Type},User,Token) -> get(Req,{asset,Name,Type},User,Token);
get(Req,workspace_projects,User,_) -> result(bright_workspace:projects(User),Req,workspace_projects);
get(Req,workspace_project,User,_) -> result(bright_workspace:project(User,cowboy_req:binding(id,Req)),Req,workspace_project);
get(Req,tasks,User,_) ->
    Q=cowboy_req:parse_qs(Req),result(bright_tasks:list(User,proplists:get_value(<<"project_id">>,Q,<<>>),proplists:get_value(<<"day">>,Q,<<>>)),Req,tasks);
get(Req,task,User,_) -> result(bright_tasks:read(User,cowboy_req:binding(id,Req)),Req,task);
get(Req,account,User,_) -> result(bright_account:read(User),Req,account);
get(Req,offline_page,_,_) -> html(bright_hub_view:render(),Req,offline_page);
get(Req,{offline_asset,Name,Type},User,Token) -> get(Req,{asset,Name,Type},User,Token);
get(Req,offline_targets,User,_) -> result(bright_offline:targets(User,proplists:get_value(<<"project_id">>,cowboy_req:parse_qs(Req),<<>>)),Req,offline_targets);
get(Req,offline,User,_) -> result(bright_offline:list(User,proplists:get_value(<<"project_id">>,cowboy_req:parse_qs(Req),<<>>)),Req,offline);
get(Req,offline_package,User,_) -> result(bright_offline:read(User,cowboy_req:binding(id,Req)),Req,offline_package);
get(Req,media_page,_,_) -> html(bright_hub_view:render(),Req,media_page);
get(Req,{media_asset,Name,Type},User,Token) -> get(Req,{asset,Name,Type},User,Token);
get(Req,media,User,_) -> result(bright_media:list(User,proplists:get_value(<<"project_id">>,cowboy_req:parse_qs(Req),<<>>)),Req,media);
get(Req,media_job,User,_) -> result(bright_media:read(User,cowboy_req:binding(id,Req)),Req,media_job);
get(Req,media_original,User,_) -> case bright_media:original(User,cowboy_req:binding(id,Req)) of {ok,#{mime:=M,data:=B}}->R=cowboy_req:set_resp_header(<<"content-disposition">>,<<"attachment; filename=capture-original">>,Req),raw(200,M,B,R,media_original);E->error_reply(E,Req,media_original) end;
get(Req,assistant_page,_,_) -> html(bright_hub_view:render(),Req,assistant_page);
get(Req,{assistant_asset,Name,Type},User,Token) -> get(Req,{asset,Name,Type},User,Token);
get(Req,assistant,User,_) -> result(bright_assistant:list(User,proplists:get_value(<<"project_id">>,cowboy_req:parse_qs(Req),<<>>)),Req,assistant);
get(Req,assistant_evidence,User,_) -> result(bright_mutation:guard("STUDIO_AI_ENABLED",{User,fun()->bright_documents:evidence_owned(User,proplists:get_value(<<"project_id">>,cowboy_req:parse_qs(Req),<<>>)) end}),Req,assistant_evidence);
get(Req,assistant_attempt,User,_) -> result(bright_assistant:read(User,cowboy_req:binding(id,Req)),Req,assistant_attempt);
get(Req,documents_page,_,_) -> html(bright_hub_view:render(),Req,documents_page);
get(Req,{documents_asset,Name,Type},User,Token) -> get(Req,{asset,Name,Type},User,Token);
get(Req,documents,User,_) -> result(bright_documents:list(User,proplists:get_value(<<"project_id">>,cowboy_req:parse_qs(Req),<<>>)),Req,documents);
get(Req,documents_evidence,User,_) -> result(bright_documents:evidence(User,proplists:get_value(<<"project_id">>,cowboy_req:parse_qs(Req),<<>>)),Req,documents_evidence);
get(Req,document,User,_) -> result(bright_documents:read(User,cowboy_req:binding(id,Req),document_version(Req)),Req,document);
get(Req,document_history,User,_) -> result(bright_documents:history(User,cowboy_req:binding(id,Req)),Req,document_history);
get(Req,document_export,User,_) -> case bright_documents:export(User,cowboy_req:binding(id,Req),document_version(Req)) of
 {ok,Bytes}->R=cowboy_req:set_resp_header(<<"content-disposition">>,<<"attachment; filename=studio-document.md">>,Req),raw(200,<<"text/markdown; charset=utf-8">>,Bytes,R,document_export);
 E->error_reply(E,Req,document_export) end;
get(Req,focus_page,_,_) -> html(bright_hub_view:render(),Req,focus_page);
get(Req,{focus_asset,Name,Type},User,Token) -> get(Req,{asset,Name,Type},User,Token);
get(Req,focus_targets,User,_) -> result(bright_focus:targets(User,proplists:get_value(<<"project_id">>,cowboy_req:parse_qs(Req),<<>>)),Req,focus_targets);
get(Req,focus,User,_) -> result(bright_focus:list(User,proplists:get_value(<<"project_id">>,cowboy_req:parse_qs(Req),<<>>)),Req,focus);
get(Req,focus_session,User,_) -> result(bright_focus:read(User,cowboy_req:binding(id,Req)),Req,focus_session);
get(Req,study_page,_,_) -> html(bright_hub_view:render(),Req,study_page);
get(Req,{study_asset,Name,Type},User,Token) -> get(Req,{asset,Name,Type},User,Token);
get(Req,study,User,_) -> result(bright_study:list(User,proplists:get_value(<<"project_id">>,cowboy_req:parse_qs(Req),<<>>)),Req,study);
get(Req,study_pass,User,_) -> result(bright_study:read(User,cowboy_req:binding(id,Req)),Req,study_pass);
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
    case read_assets(asset_files(Name)) of
        {ok,Bytes} -> raw(200,Type,Bytes,Req,Route);
        _ -> reply(404,#{error=>not_found},Req,Route)
    end;
get(Req,Route,_,_) -> reply(405,#{error=>method_not_allowed},Req,Route).
asset_files("hub.js")->
    ["offline-cleanup.js","hub.js","ui.js"]++case bright_evidence:enabled() of true->["evidence.js"];false->[] end
        ++case bright_study:enabled() of true->["study.js"];false->[] end
        ++case bright_workspace:enabled() of true->["workspace.js"];false->[] end
        ++case bright_focus:enabled() of true->["focus.js"];false->[] end
        ++case bright_documents:enabled() of true->["documents.js"];false->[] end
        ++case bright_assistant:enabled() of true->["assistant.js"];false->[] end
        ++case bright_media:enabled() of true->["media.js"];false->[] end
        ++case bright_offline:enabled() of true->["offline.js"];false->[] end;
asset_files(Name)->[Name].
read_assets([])->{ok,[]};
read_assets([Name|Rest])->case file:read_file(filename:join([code:priv_dir(bright_web),"static",Name])) of
    {ok,Bytes}->case read_assets(Rest) of {ok,Tail}->{ok,[Bytes,<<"\n;\n">>|Tail]};E->E end;
    E->E end.
post(Req,access_revoke_session,U,T)->result(bright_access:revoke_session(U,T,cowboy_req:binding(id,Req)),Req,access_revoke_session);
post(Req,access_revoke_all,U,_)->result(bright_access:revoke_all(U),Req,access_revoke_all);
post(Req,access_workspaces,U,_)->body(Req,fun(M,R)->created(bright_membership:create(U,cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,access_workspaces) end,access_workspaces);
post(Req,access_workspace,U,_)->body(Req,fun(M,R)->result(bright_membership:change(U,cowboy_req:binding(id,R),cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,access_workspace) end,access_workspace);
post(Req,workspace_projects,User,_) ->
    body(Req,fun(M,R)->created(bright_workspace:create_project(User,cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,workspace_projects) end,workspace_projects);
post(Req,workspace_project,User,_) ->
    body(Req,fun(M,R)->result(bright_workspace:edit_project(User,cowboy_req:binding(id,R),cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,workspace_project) end,workspace_project);
post(Req,tasks,User,_) ->
    body(Req,fun(M,R)->created(bright_tasks:create(User,cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,tasks) end,tasks);
post(Req,task,User,_) ->
    body(Req,fun(M,R)->result(bright_tasks:edit(User,cowboy_req:binding(id,R),cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,task) end,task);
post(Req,account,User,_) ->
    body(Req,fun(M,R)->result(bright_account:edit(User,cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,account) end,account);
post(Req,account_password,User,Token) ->
    case bright_login_limit:allow_password(User) of
        false->reply(429,#{error=>rate_limited},Req,account_password);
        true->body(Req,fun(M,R)->case bright_account:change_password(User,Token,M) of
            {ok,V}->R1=cowboy_req:set_resp_cookie(<<"bright_session">>,<<>>,R,(cookie_options())#{max_age=>0}),reply(200,V,R1,account_password);
            Error->error_reply(Error,R,account_password) end end,account_password)
    end;
post(Req,offline,User,_) -> body(Req,fun(M,R)->created(bright_offline:create(User,cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,offline) end,offline);
post(Req,offline_revoke,User,_) -> result(bright_offline:revoke(User,cowboy_req:binding(id,Req),cowboy_req:header(<<"idempotency-key">>,Req,<<>>)),Req,offline_revoke);
post(Req,offline_sync,User,_) -> body(Req,fun(M,R)->result(bright_offline:sync(User,cowboy_req:binding(id,R),cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,offline_sync) end,offline_sync);
post(Req,media,User,_) ->
 Q=cowboy_req:parse_qs(Req),P=proplists:get_value(<<"project_id">>,Q,<<>>),Title=proplists:get_value(<<"title">>,Q,<<>>),
 Name=try uri_string:percent_decode(cowboy_req:header(<<"x-upload-filename">>,Req,<<>>)) catch _:_ -> <<>> end,
 Mime=hd(binary:split(cowboy_req:header(<<"content-type">>,Req,<<>>),<<";">>)),case upload_body(Req,[],0) of
 {ok,Data,R}->created(bright_media:upload(User,P,cowboy_req:header(<<"idempotency-key">>,R,<<>>),#{title=>Title,filename=>Name,mime=>Mime,data=>Data}),R,media);{too_large,R}->reply(413,#{error=>body_too_large},R,media) end;
post(Req,media_retry,User,_) -> body(Req,fun(M,R)->result(bright_media:retry(User,cowboy_req:binding(id,R),cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,media_retry) end,media_retry);
post(Req,assistant,User,_) -> body(Req,fun(M,R)->created(bright_assistant:create(User,cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,assistant) end,assistant);
post(Req,documents,User,_) -> body(Req,fun(M,R)->created(bright_documents:create(User,cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,documents) end,documents);
post(Req,document,User,_) -> body(Req,fun(M,R)->result(bright_documents:save(User,cowboy_req:binding(id,R),cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,document) end,document);
post(Req,focus,User,_) ->
    body(Req,fun(M,R)->created(bright_focus:start(User,cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,focus) end,focus);
post(Req,focus_actions,User,_) ->
    body(Req,fun(M,R)->result(bright_focus:act(User,cowboy_req:binding(id,R),cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,focus_actions) end,focus_actions);
post(Req,study,User,_) ->
    body(Req,fun(M,R)->created(bright_study:start(User,cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,study) end,study);
post(Req,study_attempts,User,_) ->
    body(Req,fun(M,R)->result(bright_study:submit(User,cowboy_req:binding(id,R),cowboy_req:header(<<"idempotency-key">>,R,<<>>),M),R,study_attempts) end,study_attempts);
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
document_version(Req)->case proplists:get_value(<<"version">>,cowboy_req:parse_qs(Req),undefined) of undefined->latest;B->try binary_to_integer(B) catch _:_ -> invalid end end.
offline_route({offline_public,_,_})->true;
offline_route({offline_asset,_,_})->true;
offline_route(Route)->lists:member(Route,[offline_page,offline,offline_targets,offline_package,offline_revoke,offline_sync]).
media_route({media_asset,_,_})->true;
media_route(Route)->lists:member(Route,[media_page,media,media_job,media_original,media_retry]).
assistant_route({assistant_asset,_,_})->true;
assistant_route(Route)->lists:member(Route,[assistant_page,assistant,assistant_attempt,assistant_evidence]).
documents_route({documents_asset,_,_})->true;
documents_route(Route)->lists:member(Route,[documents_page,documents,documents_evidence,document,document_history,document_export]).
focus_route({focus_asset,_,_})->true;
focus_route(Route)->lists:member(Route,[focus_page,focus,focus_targets,focus_session,focus_actions]).
access_route(R)->lists:member(R,[recovery_page,reset_page,recovery_asset,recovery_availability,recovery_request,recovery_reset,access_page,access_asset,access_recovery,access_sessions,access_revoke_session,access_revoke_all,access_workspaces,access_workspace]).
workspace_route({workspace_asset,_,_})->true;
workspace_route(Route)->lists:member(Route,[workspace_page,workspace_projects,workspace_project,tasks,task,account,account_password]).
study_route({study_asset,_,_})->true;
study_route(Route)->lists:member(Route,[study_page,study,study_pass,study_attempts]).
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
error_reply({error,unauthenticated},Req,Route) ->
    case cowboy_req:method(Req)=:= <<"GET">> andalso lists:member(Route,[hub,library,reader,evidence_page,study_page,workspace_page,focus_page,documents_page,assistant_page,media_page,offline_page,access_page]) of
        true->
            Path=cowboy_req:path(Req),
            Next=case cowboy_req:qs(Req) of <<>>->Path;Qs-><<Path/binary,"?",Qs/binary>> end,
            Location= <<"/studio/login/?next=",(uri_string:quote(Next))/binary>>,
            Headers=(response_headers(<<"text/html; charset=utf-8">>))#{<<"location">>=>Location},
            {ok,cowboy_req:reply(302,Headers,<<>>,Req),Route};
        false->reply(401,#{error=>unauthenticated},Req,Route)
    end;
error_reply({error,Reason},Req,Route) ->
    {Code,Public} = case Reason of
        unauthenticated -> {401,unauthenticated}; wrong_password -> {400,wrong_password}; forbidden -> {403,forbidden};
        disabled -> {404,not_found}; quota_exceeded -> {413,quota_exceeded}; not_ready -> {409,not_ready};
        not_found -> {404,not_found}; invalid_input -> {400,invalid_input}; conflict -> {409,conflict};
        _ -> {503,unavailable}
    end,
    reply(Code,#{error=>Public},Req,Route).
reply(Code,Value,Req,Route) -> raw(Code,<<"application/json; charset=utf-8">>,jsx:encode(Value),Req,Route).
html(Bytes,Req,Route) -> raw(200,<<"text/html; charset=utf-8">>,Bytes,Req,Route).
raw(Code,Type,Bytes,Req,Route) ->
    {ok,cowboy_req:reply(Code,response_headers(Type),Bytes,Req),Route}.
response_headers(Type)->
    #{<<"content-type">>=>Type,<<"cache-control">>=><<"no-store">>,
        <<"x-content-type-options">>=><<"nosniff">>,<<"referrer-policy">>=><<"same-origin">>,
        <<"content-security-policy">>=><<"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'">>}.
