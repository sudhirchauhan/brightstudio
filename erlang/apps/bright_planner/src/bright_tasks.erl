-module(bright_tasks).
-export([date/1,validate/1,create/3,edit/4,read/2,list/3]).
date(<<>>)->true;
date(B) when is_binary(B)->case re:run(B,<<"^([0-9]{4})-([0-9]{2})-([0-9]{2})$">>,[{capture,[1,2,3],binary}]) of
    {match,[Y,M,D]}->Year=binary_to_integer(Y),Year>=1900 andalso Year=<2100 andalso calendar:valid_date({Year,binary_to_integer(M),binary_to_integer(D)});
    _->false end;
date(_)->false.
validate(M) when is_map(M)->
    P=maps:get(<<"project_id">>,M,undefined),Title=maps:get(<<"title">>,M,undefined),Note=maps:get(<<"note">>,M,<<>>),
    State=maps:get(<<"state">>,M,<<"todo">>),Due=maps:get(<<"due_date">>,M,<<>>),Day=maps:get(<<"scheduled_date">>,M,<<>>),
    Minutes=maps:get(<<"estimate_minutes">>,M,25),Priority=maps:get(<<"priority">>,M,2),
    case bright_project_auth:uuid(P) andalso bright_workspace:text(Title,200,false) andalso bright_workspace:text(Note,2000,true)
        andalso lists:member(State,[<<"todo">>,<<"doing">>,<<"done">>]) andalso date(Due) andalso date(Day)
        andalso is_integer(Minutes) andalso Minutes>=5 andalso Minutes=<480 andalso is_integer(Priority) andalso Priority>=1 andalso Priority=<3 of
        true->{ok,[P,string:trim(Title),Note,State,Due,Day,Minutes,Priority]};false->{error,invalid_input} end;
validate(_)->{error,invalid_input}.
columns()->"id,project_id,title,note,state,due_date,scheduled_date,estimate_minutes,priority,version".
item({Id,P,T,N,S,Due,Day,Minutes,Priority,V})->#{id=>Id,project_id=>P,title=>T,note=>N,state=>S,due_date=>Due,scheduled_date=>Day,estimate_minutes=>Minutes,priority=>Priority,version=>V}.
read_sql(C,U,Id)->case bright_sql:equery(C,"SELECT "++columns()++" FROM bright_tasks WHERE id=$1 AND owner_id=$2",[Id,U]) of
    {ok,_,[R]}->{ok,item(R)};{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
read(U,Id)->bright_workspace:guard(U,fun()->case bright_project_auth:uuid(Id) of false->{error,not_found};true->bright_sql_pool:with_connection(fun(C)->read_sql(C,U,Id) end) end end).
list(U,P,Day)->bright_workspace:guard(U,fun()->case date(Day) of
    false->{error,invalid_input};true->case bright_project_auth:authorize(U,P) of
        ok->bright_sql_pool:with_connection(fun(C)->case bright_sql:equery(C,"SELECT "++columns()++" FROM bright_tasks WHERE owner_id=$1 AND project_id=$2 AND ($3='' OR scheduled_date=$3 OR due_date=$3 OR (due_date<>'' AND due_date<$3 AND state<>'done')) ORDER BY CASE state WHEN 'doing' THEN 0 WHEN 'todo' THEN 1 ELSE 2 END,priority,created_at,id LIMIT 1000",[U,P,Day]) of
            {ok,_,Rows}->{ok,[item(R)||R<-Rows]};_->{error,unavailable} end end);
        E->E end end end).
project_owned(C,U,P)->case bright_sql:equery(C,"SELECT id FROM bright_projects WHERE id=$1 AND owner_id=$2",[P,U]) of
    {ok,_,[_]}->ok;{ok,_,[]}->{error,forbidden};_->{error,unavailable} end.
create(U,K,M)->case validate(M) of
    {ok,[P,_,_,_,_,_,_,_]=Values}->bright_workspace:mutate(U,create_task,K,Values,fun(C)->case project_owned(C,U,P) of
        ok->{ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_tasks WHERE owner_id=$1",[U]),
            case Count<1000 of false->{error,quota_exceeded};true->Id=bright_project_auth:new_id(),
                {ok,1}=bright_sql:equery(C,"INSERT INTO bright_tasks(id,owner_id,project_id,title,note,state,due_date,scheduled_date,estimate_minutes,priority) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)",[Id,U|Values]),
                %% Completion timestamps are server timestamps, never client supplied.
                {ok,_}=bright_sql:equery(C,"UPDATE bright_tasks SET completed_at=now() WHERE id=$1 AND owner_id=$2 AND state='done'",[Id,U]),
                read_sql(C,U,Id) end;
        E->E end end);
    E->E end.
edit(U,Id,K,M) when is_map(M)->case read(U,Id) of
    {ok,_}->V=maps:get(<<"expected_version">>,M,undefined),case {bright_workspace:version(V),validate(M)} of
        {true,{ok,[P,_,_,_,_,_,_,_]=Values}}->bright_workspace:mutate(U,{edit_task,Id},K,{V,Values},fun(C)->case project_owned(C,U,P) of
            ok->case bright_sql:equery(C,"UPDATE bright_tasks SET project_id=$1,title=$2,note=$3,state=$4,due_date=$5,scheduled_date=$6,estimate_minutes=$7,priority=$8,version=version+1,completed_at=CASE WHEN $4='done' THEN COALESCE(completed_at,now()) ELSE NULL END WHERE id=$9 AND owner_id=$10 AND version=$11 RETURNING version",Values++[Id,U,V]) of
                {ok,1,_,[_]}->read_sql(C,U,Id);{ok,0,_,[]}->{error,conflict};_->{error,unavailable} end;
            E->E end end);
        _->{error,invalid_input} end;
    E->E end;
edit(_,_,_,_)->{error,invalid_input}.
