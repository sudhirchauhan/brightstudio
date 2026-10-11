-module(bright_studio_sup_tests).
-include_lib("eunit/include/eunit.hrl").

web_extraction_opt_in_test() ->
    Names=["BRIGHT_ROLE","STUDIO_WEB_EXTRACTION_ENABLED"],
    Saved=[{Name,os:getenv(Name)} || Name<-Names],
    try
        os:putenv("BRIGHT_ROLE","web"),
        os:unsetenv("STUDIO_WEB_EXTRACTION_ENABLED"),
        ?assertEqual([],children()),
        os:putenv("STUDIO_WEB_EXTRACTION_ENABLED","true"),
        [Worker]=children(),
        ?assertEqual({bright_source_worker,start_link,[]},maps:get(start,Worker)),
        ?assertEqual(permanent,maps:get(restart,Worker)),
        os:putenv("STUDIO_WEB_EXTRACTION_ENABLED","false"),
        ?assertEqual([],children()),
        os:putenv("BRIGHT_ROLE","worker"),
        ?assertEqual([Worker],children())
    after
        lists:foreach(fun({Name,false})->os:unsetenv(Name);
                         ({Name,Value})->os:putenv(Name,Value) end,Saved)
    end.

children()->
    {ok,{_,Children}}=bright_studio_sup:init([]),
    Children.
