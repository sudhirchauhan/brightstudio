-module(bright_http_handler).
-behaviour(cowboy_handler).
-export([init/2, shell/1]).
init(Req, live) -> plain(200, <<"ok">>, Req, live);
init(Req, ready) ->
    Status = case bright_ready:check() of ok -> 200; _ -> 503 end,
    plain(Status, case Status of 200 -> <<"ready">>; _ -> <<"database unavailable">> end, Req, ready);
init(Req, hub) -> plain(404, <<"not found">>, Req, hub);
init(Req, Page) ->
    R = cowboy_req:reply(200, #{<<"content-type">> => <<"text/html; charset=utf-8">>,
        <<"cache-control">> => <<"no-store">>,
        <<"content-security-policy">> => <<"default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'">>,
        <<"x-content-type-options">> => <<"nosniff">>}, shell(Page), Req),
    {ok, R, Page}.
plain(Status, Body, Req, State) ->
    R = cowboy_req:reply(Status, #{<<"content-type">> => <<"text/plain; charset=utf-8">>,
        <<"cache-control">> => <<"no-store">>}, Body, Req),
    {ok, R, State}.
shell(Page) ->
    Active = case Page of home -> <<"Overview">>; studio -> <<"Studio">> end,
    <<"<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>",
      "<title>Bright Studio · ", Active/binary, "</title>",
      "<style>*{box-sizing:border-box}body{margin:0;background:#f8f7f4;color:#242c31;font:16px system-ui,-apple-system,sans-serif}",
      ".layout{display:grid;grid-template-columns:245px 1fr;min-height:100vh}aside{background:#182b2c;color:#e9f0ed;padding:32px 22px}",
      ".brand{font-size:23px;font-weight:750;letter-spacing:-.7px;margin-bottom:44px}.brand span{color:#b9d8bb}",
      "nav a{display:block;color:#d5e3dd;text-decoration:none;padding:13px 16px;border-radius:12px;margin:6px 0}",
      "nav a:hover,nav a[aria-current]{background:#35504c;color:white}main{max-width:1120px;width:100%;padding:56px 6vw}",
      ".eyebrow{font-size:12px;letter-spacing:2px;text-transform:uppercase;color:#658174;font-weight:700}",
      "h1{font-size:clamp(34px,5vw,54px);letter-spacing:-2px;margin:12px 0}p{line-height:1.7;color:#63716f}",
      ".intro{max-width:640px}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:18px;margin-top:38px}",
      ".card{background:white;border:1px solid #e6e9e3;border-radius:18px;padding:25px;min-height:165px;box-shadow:0 8px 28px #223c2c08}",
      ".card h2{font-size:19px;margin:0 0 12px}.tag{display:inline-block;background:#f0f3ef;color:#547061;border-radius:30px;padding:6px 11px;font-size:12px}",
      ".note{margin-top:38px;padding:18px 22px;background:#eaf1ea;border-left:3px solid #668f75;border-radius:8px}",
      "@media(max-width:700px){.layout{display:block}aside{padding:18px}.brand{margin:0 0 14px}nav{display:flex;gap:8px}nav a{margin:0;padding:10px}main{padding:32px 20px}}</style></head>",
      "<body><div class='layout'><aside><div class='brand'>bright<span>studio</span></div><nav aria-label='Primary'>",
      "<a href='/'", (current(Page, home))/binary, ">Overview</a>",
      "<a href='/studio/'", (current(Page, studio))/binary, ">Studio</a>",
      "</nav></aside><main><div class='eyebrow'>Learning and planning workspace</div>",
      "<h1>", Active/binary, "</h1><p class='intro'>A calm place to organize projects, study sources and build understanding. ",
      "The Erlang foundation is running; the full product workflows are being built in stages.</p>",
      "<section class='cards' aria-label='Workspace areas'>",
      "<div class='card'><h2>Projects</h2><p>Organize work and learning around meaningful goals.</p><span class='tag'>Coming next</span></div>",
      "<div class='card'><h2>Planner</h2><p>Make room for the work that matters.</p><span class='tag'>Coming next</span></div>",
      "<div class='card'><h2>Studio library</h2><p>Read, annotate and connect your materials.</p><span class='tag'>Coming next</span></div>",
      "<div class='card'><h2>Learning hub</h2><p>Focus sessions, lessons and documents.</p><span class='tag'>Feature gated</span></div>",
      "</section><div class='note' role='status'><strong>Development preview.</strong> This shell contains no account data or live workflows. ",
      "The learning hub is disabled until authentication and owner permissions are implemented.</div>",
      "</main></div></body></html>">>.
current(Page, Page) -> <<" aria-current='page'">>;
current(_, _) -> <<>>.
