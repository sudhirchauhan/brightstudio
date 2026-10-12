-module(bright_mockups_handler).
-behaviour(cowboy_handler).
-export([init/2]).
%% Public, fictional design artifacts only. No account data or API access.
init(Req,Asset)->
    Enabled=os:getenv("STUDIO_UI_MOCKS_ENABLED")=:= "true",
    Method=cowboy_req:method(Req),
    case {Enabled,Method} of
        {false,_}->reply(404,<<"text/plain">>,<<"Not found">>,Req,Asset);
        {true,M} when M=:= <<"GET">>;M=:= <<"HEAD">> ->
            {Name,Type}=asset(Asset),
            case file:read_file(filename:join([code:priv_dir(bright_web),"static","mockups",Name])) of
                {ok,B}->reply(200,Type,B,Req,Asset);
                _->reply(404,<<"text/plain">>,<<"Not found">>,Req,Asset)
            end;
        _->reply(405,<<"text/plain">>,<<"Method not allowed">>,Req,Asset)
    end.
asset(gallery)->{"index.html",<<"text/html; charset=utf-8">>};
asset(css)->{"gallery.css",<<"text/css; charset=utf-8">>};
asset(board)->{"bright-studio-design-board.jpg",<<"image/jpeg">>};
asset(workspace)->{"01-workspace.jpg",<<"image/jpeg">>};
asset(reader)->{"02-fullscreen-reader.jpg",<<"image/jpeg">>};
asset(study)->{"03-fullscreen-study.jpg",<<"image/jpeg">>};
asset(mobile)->{"04-mobile-study.jpg",<<"image/jpeg">>}.
reply(Code,Type,Body,Req,State)->
    Headers=#{<<"content-type">>=>Type,<<"cache-control">>=><<"no-store">>,<<"x-content-type-options">>=><<"nosniff">>,
      <<"referrer-policy">>=><<"same-origin">>,<<"content-security-policy">>=><<"default-src 'none'; img-src 'self'; style-src 'self'; base-uri 'none'">>},
    {ok,cowboy_req:reply(Code,Headers,Body,Req),State}.
