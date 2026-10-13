-module(bright_ai_worker).
-behaviour(gen_server).
-export([start_link/0,init/1,handle_call/3,handle_cast/2,handle_info/2,terminate/2]).
start_link()->gen_server:start_link({local,?MODULE},?MODULE,[],[]).
init([])->erlang:send_after(1000,self(),tick),{ok,undefined}.
handle_call(_,_,S)->{reply,ok,S}.
handle_cast(_,S)->{noreply,S}.
handle_info(tick,S)->try bright_assistant:process_one() catch _:_ ->ok end,erlang:send_after(1000,self(),tick),{noreply,S};
handle_info(_,S)->{noreply,S}.
terminate(_,_) ->ok.
