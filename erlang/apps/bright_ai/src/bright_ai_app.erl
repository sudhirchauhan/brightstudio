-module(bright_ai_app).
-behaviour(application).
-export([start/2,stop/1]).
start(_,_) -> bright_ai_sup:start_link().
stop(_)->ok.
