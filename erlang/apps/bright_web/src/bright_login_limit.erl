-module(bright_login_limit).
-behaviour(gen_server).
-export([start_link/0,allow/1,init/1,handle_call/3,handle_cast/2,handle_info/2]).
start_link() -> gen_server:start_link({local,?MODULE},?MODULE,[],[]).
allow({Ip,_Port}) -> gen_server:call(?MODULE,{allow,Ip}).
init([]) -> {ok,#{}}.
handle_call({allow,Ip},_,State) ->
    Now = erlang:monotonic_time(second),
    Recent = maps:filter(fun(_, {Start,_}) -> Now-Start < 300 end,State),
    {Start,N} = maps:get(Ip,Recent,{Now,0}),
    Allowed = N < 10 andalso map_size(Recent) < 10000,
    {reply,Allowed,Recent#{Ip=>{Start,N+1}}};
handle_call(_,_,State) -> {reply,false,State}.
handle_cast(_,State) -> {noreply,State}.
handle_info(_,State) -> {noreply,State}.
