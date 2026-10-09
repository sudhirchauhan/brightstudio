-module(bright_studio_app).
-behaviour(application).
-export([start/2,stop/1]).
start(_,_) -> bright_studio_sup:start_link().
stop(_)->ok.
