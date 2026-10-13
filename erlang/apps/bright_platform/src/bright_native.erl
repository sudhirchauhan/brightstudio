-module(bright_native).
-export([run/3]).
%% All executables/options come from operator configuration, never shell text.
run(Executable,Args,#{memory:=Memory,cpu:=Cpu,timeout:=Timeout,output:=Max}) ->
 case os:find_executable("prlimit") of false->{error,tool_unavailable};Limiter->
 try Names=[lists:takewhile(fun(C)->C=/=$= end,E)||E<-os:getenv()],SecretNames=[Name||Name<-Names,re:run(Name,"PASSWORD|TOKEN|SECRET|API_KEY|CREDENTIAL|DATABASE_URL|COOKIE",[caseless])=/=nomatch],Env=[{Name,false}||Name<-SecretNames]++[{"OMP_THREAD_LIMIT","1"},{"MALLOC_ARENA_MAX","2"}],Port=open_port({spawn_executable,Limiter},[binary,exit_status,stderr_to_stdout,use_stdio,{env,Env},{args,["--core=0","--as="++integer_to_list(Memory),"--cpu="++integer_to_list(Cpu),"--fsize="++integer_to_list(Max),"--",Executable|Args]}]),
 await(Port,erlang:monotonic_time(millisecond)+Timeout,Max,0,[])
 catch _:_->{error,tool_unavailable} end end.
await(Port,Deadline,Max,Size,Chunks)->Left=max(0,Deadline-erlang:monotonic_time(millisecond)),receive
 {Port,{data,B}} when Size+byte_size(B)=<Max->await(Port,Deadline,Max,Size+byte_size(B),[B|Chunks]);
 {Port,{data,_}}->stop(Port),{error,resource_limit};
 {Port,{exit_status,0}}->{ok,iolist_to_binary(lists:reverse(Chunks))};
 {Port,{exit_status,N}} when N=:=137;N=:=152;N=:=153->{error,resource_limit};
 {Port,{exit_status,_}}->{error,invalid_document}
 after Left->stop(Port),{error,resource_limit} end.
stop(P)->case erlang:port_info(P,os_pid) of {os_pid,Id}->K=open_port({spawn_executable,"/bin/kill"},[exit_status,{args,["-KILL",integer_to_list(Id)]}]),receive {K,{exit_status,_}}->ok after 1000->catch port_close(K) end;_->ok end,catch port_close(P),ok.
