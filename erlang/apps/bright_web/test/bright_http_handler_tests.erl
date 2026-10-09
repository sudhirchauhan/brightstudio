-module(bright_http_handler_tests).
-include_lib("eunit/include/eunit.hrl").
home_shell_test() ->
    Html = bright_http_handler:shell(home),
    ?assertMatch({_, _}, binary:match(Html, <<"<!doctype html>">>)),
    ?assertMatch({_, _}, binary:match(Html, <<"aria-current='page'">>)),
    ?assertMatch({_, _}, binary:match(Html, <<"Overview">>)).
studio_shell_test() ->
    Html = bright_http_handler:shell(studio),
    ?assertMatch({_, _}, binary:match(Html, <<"Studio library">>)),
    ?assertMatch({_, _}, binary:match(Html, <<"Feature gated">>)),
    ?assertMatch({_, _}, binary:match(Html, <<"Development preview">>)).
no_external_scripts_test() ->
    Html = bright_http_handler:shell(home),
    ?assertEqual(nomatch, binary:match(Html, <<"<script">>)).
