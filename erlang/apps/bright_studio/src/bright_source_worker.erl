-module(bright_source_worker).
-behaviour(gen_server).
-export([start_link/0, process_one/0,init/1,handle_info/2,handle_call/3,handle_cast/2]).
start_link()->gen_server:start_link({local,?MODULE},?MODULE,[],[]).
init([])->self()!tick,{ok,#{}}.
handle_info(tick,State)->
    %% SQL leases recover after exceptions or worker termination; no acknowledgement lives only here.
    try process_one() catch _:_ -> logger:warning("Source worker dependency operation failed") end,
    erlang:send_after(500,self(),tick),{noreply,State};
handle_info(_,State)->{noreply,State}.
handle_call(_,_,State)->{reply,{error,bad_request},State}.
handle_cast(_,State)->{noreply,State}.
process_one()->global:trans({{bright_native,node()},self()},fun process_locked/0).
process_locked()->
    case bright_library:claim() of
        {ok,Job=#{owner_id:=User,source_id:=Source,id:=Revision}} ->
            case bright_library:original(User,Source,Revision) of
                {ok,#{mime:=Mime,data:=Data}} ->
                    case extract(Mime,Data) of
                        {ok,Text}->bright_library:finish(Job,ready,Text);
                        {error,Reason}->bright_library:finish(Job,failed,atom_to_binary(Reason))
                    end;
                _->{error,unavailable}
            end;
        Other->Other
    end.

%% Claim only after acquiring the native slot, so queue wait cannot consume the lease.
extract(<<"application/pdf">>,Data)->bright_pdf_ocr:run_locked(Data);
extract(Mime,Data)->bright_extract:run(Mime,Data).
