-module(bright_platform_app).
-behaviour(application).
-export([start/2, stop/1]).
start(_Type, _Args) -> bright_platform_sup:start_link().
stop(_State) -> ok.
