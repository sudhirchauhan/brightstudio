-module(bright_sql_pool).
-behaviour(gen_server).
-export([start_link/0, with_connection/1, checkout/0, checkin/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).
-record(state, {idle = [], leased = #{}, max = 5, total = 0}).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
checkout() -> gen_server:call(?MODULE, checkout, 5000).
checkin(Conn) -> gen_server:call(?MODULE, {checkin, Conn}, 5000).

with_connection(Fun) when is_function(Fun, 1) ->
    case checkout() of
        {ok, Conn} ->
            try Fun(Conn)
            after checkin(Conn) end;
        Error -> Error
    end.

init([]) ->
    Max = case application:get_env(bright_platform, sql_pool_size, 5) of
        N when is_integer(N), N > 0 -> N;
        _ -> 5
    end,
    {ok, #state{max = Max}}.

handle_call(checkout, {Pid, _}, S = #state{idle = [Conn | Rest], leased = Leased}) ->
    Ref = erlang:monitor(process, Pid),
    case is_process_alive(Conn) of
        true -> {reply, {ok, Conn}, S#state{idle = Rest, leased = Leased#{Conn => {Pid, Ref}}}};
        false ->
            erlang:demonitor(Ref, [flush]),
            handle_call(checkout, {Pid, undefined}, S#state{idle = Rest, total = S#state.total - 1})
    end;
handle_call(checkout, {Pid, _}, S = #state{total = Total, max = Max, leased = Leased}) when Total < Max ->
    case os:getenv("DATABASE_URL") of
        false -> {reply, {error, missing_database_url}, S};
        Url ->
            case bright_db:connect(Url) of
                {ok, Conn} ->
                    Ref = erlang:monitor(process, Pid),
                    {reply, {ok, Conn}, S#state{total = Total + 1, leased = Leased#{Conn => {Pid, Ref}}}};
                {error, Reason} -> {reply, {error, Reason}, S}
            end
    end;
handle_call(checkout, _, S) -> {reply, {error, pool_exhausted}, S};
handle_call({checkin, Conn}, {Pid, _}, S = #state{leased = Leased, idle = Idle}) ->
    case maps:find(Conn, Leased) of
        {ok, {Pid, Ref}} ->
            erlang:demonitor(Ref, [flush]),
            Next = S#state{leased = maps:remove(Conn, Leased)},
            case is_process_alive(Conn) of
                true -> {reply, ok, Next#state{idle = [Conn | Idle]}};
                false -> {reply, ok, Next#state{total = S#state.total - 1}}
            end;
        _ -> {reply, {error, not_connection_owner}, S}
    end;
handle_call(_, _, S) -> {reply, {error, bad_request}, S}.
handle_cast(_, S) -> {noreply, S}.
handle_info({'DOWN', Ref, process, Pid, _}, S = #state{leased = Leased, total = Total}) ->
    Matches = [Conn || {Conn, {Owner, Monitor}} <- maps:to_list(Leased),
                       Owner =:= Pid, Monitor =:= Ref],
    lists:foreach(fun(Conn) -> catch epgsql:close(Conn) end, Matches),
    Next = lists:foldl(fun(Conn, Acc) -> maps:remove(Conn, Acc) end, Leased, Matches),
    {noreply, S#state{leased = Next, total = Total - length(Matches)}};
handle_info(_, S) -> {noreply, S}.
terminate(_, #state{idle = Idle, leased = Leased}) ->
    lists:foreach(fun(Conn) -> catch epgsql:close(Conn) end, Idle ++ maps:keys(Leased)),
    ok.
