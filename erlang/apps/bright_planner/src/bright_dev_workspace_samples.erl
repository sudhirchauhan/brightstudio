-module(bright_dev_workspace_samples).
-export([run/2]).
%% Private sample tasks for the explicitly disposable SQLite demo only.
run(U,P)->case bright_workspace:enabled() of false->ok;true->
    "true"=os:getenv("BRIGHT_SQLITE_DEVELOPMENT"),"sqlite:"++_=os:getenv("DATABASE_URL"),
    {{Y,M,D},_}=calendar:universal_time(),Day=iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0B",[Y,M,D])),
    {SeedDay,Done}=bright_sql_pool:with_connection(fun(C)->
        {ok,_,_}=bright_sql:squery(C,"CREATE TABLE IF NOT EXISTS bright_dev_workspace_seed_state (owner_id TEXT NOT NULL REFERENCES bright_users(id),version TEXT NOT NULL,seed_date TEXT NOT NULL,complete integer NOT NULL DEFAULT 0,PRIMARY KEY(owner_id,version))"),
        {ok,_}=bright_sql:equery(C,"INSERT INTO bright_dev_workspace_seed_state(owner_id,version,seed_date) VALUES($1,'workspace-v1',$2) ON CONFLICT DO NOTHING",[U,Day]),
        {ok,_,[{SD,Complete}]}=bright_sql:equery(C,"SELECT seed_date,complete FROM bright_dev_workspace_seed_state WHERE owner_id=$1 AND version='workspace-v1'",[U]),{SD,Complete=:=1}
    end),
    case Done of true->ok;false->
        [SY,SM,SD]=[binary_to_integer(X)||X<-binary:split(SeedDay,<<"-">>,[global])],
        {NY,NM,ND}=calendar:gregorian_days_to_date(calendar:date_to_gregorian_days({SY,SM,SD})+1),Next=iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0B",[NY,NM,ND])),
        Items=[{<<"read">>,<<"Sample: read the walkthrough">>,<<"todo">>,SeedDay,25,2},
               {<<"practice">>,<<"Sample: practice a Study lesson">>,<<"doing">>,SeedDay,45,1},
               {<<"tomorrow">>,<<"Sample: review evidence tomorrow">>,<<"todo">>,Next,25,2},
               {<<"complete">>,<<"Sample: completed task example">>,<<"done">>,SeedDay,15,3},
               {<<"idea">>,<<"Sample: an unscheduled reading idea">>,<<"todo">>,<<>>,25,2}],
        lists:foreach(fun({Label,Title,State,Date,Minutes,Priority})->
            Key=binary:encode_hex(crypto:hash(sha256,<<"bright-demo:workspace-v1:",Label/binary>>),lowercase),
            {ok,_}=bright_tasks:create(U,Key,#{<<"project_id">>=>P,<<"title">>=>Title,<<"state">>=>State,<<"scheduled_date">>=>Date,<<"due_date">>=>Date,<<"estimate_minutes">>=>Minutes,<<"priority">>=>Priority,<<"note">>=><<"Private sample task. Edit, complete, reopen or move it to try your planner.">>})
        end,Items),
        bright_sql_pool:with_connection(fun(C)->{ok,1}=bright_sql:equery(C,"UPDATE bright_dev_workspace_seed_state SET complete=1 WHERE owner_id=$1 AND version='workspace-v1'",[U]),ok end)
    end
end.
