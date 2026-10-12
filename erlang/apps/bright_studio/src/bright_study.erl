-module(bright_study).
-export([enabled/0,prepare/1,start/3,read/2,list/2,submit/4]).
enabled()->bright_library:enabled() andalso os:getenv("STUDIO_STUDY_ENABLED")=:= "true".
guard(U,F)->case enabled() of false->{error,disabled};true->case bright_identity:profile(U) of {ok,_}->F();E->E end end.
key(K)->is_binary(K) andalso re:run(K,<<"^[!-~]{16,128}$">>,[{capture,none}])=:=match.
normalize(B)->unicode:characters_to_binary(string:casefold(string:trim(unicode:characters_to_list(B)))).
%% Bounded, deterministic quote-recall practice. It is not AI comprehension grading.
prepare(T)->
    Words=re:split(T,<<"\\s+">>,[unicode,{return,binary},trim]),
    chunks(Words,6,[]).
chunks([],_,Acc)->lists:reverse(Acc);
chunks(_,0,Acc)->lists:reverse(Acc);
chunks(Words,N,Acc)->
    {Part,Rest}=take_words(Words,80,2000,[]),
    Text=iolist_to_binary(lists:join(<<" ">>,Part)),
    case re:run(Text,<<"(?<![\\p{L}\\p{N}])[\\p{L}\\p{N}]{3,40}(?![\\p{L}\\p{N}])">>,[unicode,{capture,first,binary}]) of
        {match,[Answer]}->Prompt=binary:replace(Text,Answer,<<"____">>),chunks(Rest,N-1,[#{<<"text">>=>Text,<<"prompt">>=>Prompt,<<"answer">>=>Answer}|Acc]);
        _->chunks(Rest,N,Acc)
    end.
take_words([],_,_,Acc)->{lists:reverse(Acc),[]};
take_words(Words,0,_,Acc)->{lists:reverse(Acc),Words};
take_words([W|Rest]=Words,N,Budget,Acc)->
    Size=length(unicode:characters_to_list(W))+case Acc of []->0;_->1 end,
    case {Size=<Budget,Acc} of
        {true,_}->take_words(Rest,N-1,Budget-Size,[W|Acc]);
        {false,[]}->take_words(Rest,N,Budget,Acc);
        {false,_}->{lists:reverse(Acc),Words}
    end.
tx(U,F)->bright_sql_pool:with_connection(fun(C)->
    R=bright_sql:with_transaction(C,fun(T)->case bright_sql:equery(T,"SELECT id FROM bright_users WHERE id=$1 AND disabled_at IS NULL FOR UPDATE",[U]) of
        {ok,_,[_]}->F(T);{ok,_,[]}->{error,unauthenticated};_->{error,unavailable} end end),
    case R of {ok,_}->R;{error,_}->R;{rollback,study_start_quota}->{error,quota_exceeded};_->{error,unavailable} end
end).
columns()->"p.id,p.source_id,p.revision_id,p.lessons_json,p.step,p.version,p.state,p.summary,s.title,r.revision".
base()->" FROM bright_study_passes p JOIN bright_sources s ON s.id=p.source_id AND s.owner_id=p.owner_id JOIN bright_source_revisions r ON r.id=p.revision_id AND r.owner_id=p.owner_id ".
item({Id,S,R,Json,Step,V,State,Summary,Title,Rev})->
    Lessons=jsx:decode(Json,[return_maps]),
    Lesson=case State of <<"active">>->maps:without([<<"answer">>],lists:nth(Step+1,Lessons));_->null end,
    #{id=>Id,source_id=>S,revision_id=>R,source_title=>Title,revision=>Rev,step=>Step,version=>V,state=>State,summary=>Summary,total=>length(Lessons),lesson=>Lesson}.
row(C,U,Id)->case bright_sql:equery(C,"SELECT "++columns()++base()++"WHERE p.id=$1 AND p.owner_id=$2",[Id,U]) of
    {ok,_,[R]}->{ok,R};{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
read_sql(C,U,Id)->case row(C,U,Id) of {ok,R}->{ok,item(R)};E->E end.
read(U,Id)->guard(U,fun()->case bright_project_auth:uuid(Id) of
    false->{error,not_found};true->bright_sql_pool:with_connection(fun(C)->read_sql(C,U,Id) end) end end).
list(U,P)->guard(U,fun()->case bright_project_auth:authorize(U,P) of
    ok->bright_sql_pool:with_connection(fun(C)->case bright_sql:equery(C,"SELECT "++columns()++base()++"WHERE p.owner_id=$1 AND s.project_id=$2 ORDER BY p.created_at DESC,p.id LIMIT 100",[U,P]) of
        {ok,_,Rows}->{ok,[item(R)||R<-Rows]};_->{error,unavailable} end end);
    E->E end end).
start(U,K,M) when is_map(M)->guard(U,fun()->
    S=maps:get(<<"source_id">>,M,undefined),R=maps:get(<<"revision_id">>,M,undefined),
    case key(K) of false->{error,invalid_input};true->case bright_library:content(U,S,R) of
        {ok,#{text:=Text}}->Lessons=prepare(Text),case Lessons of []->{error,not_ready};_->tx(U,fun(C)->
            case bright_sql:equery(C,"SELECT p.id,p.source_id,p.revision_id FROM bright_study_starts k JOIN bright_study_passes p ON p.id=k.pass_id AND p.owner_id=k.owner_id WHERE k.owner_id=$1 AND k.idempotency_key=$2",[U,K]) of
                {ok,_,[{Id,S,R}]}->read_sql(C,U,Id);
                {ok,_,[_]}->{error,conflict};
                {ok,_,[]}->case bright_sql:equery(C,"SELECT id FROM bright_study_passes WHERE owner_id=$1 AND revision_id=$2",[U,R]) of
                    {ok,_,[{Id}]}->start_receipt(C,U,Id,K);
                    {ok,_,[]}->{ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_study_passes WHERE owner_id=$1",[U]),
                        case Count<1000 of false->{error,quota_exceeded};true->
                            Id=bright_project_auth:new_id(),
                            {ok,1}=bright_sql:equery(C,"INSERT INTO bright_study_passes(id,owner_id,source_id,revision_id,lessons_json,text_sha256,idempotency_key) VALUES($1,$2,$3,$4,$5,$6,$7)",[Id,U,S,R,jsx:encode(Lessons),crypto:hash(sha256,Text),K]),
                            start_receipt(C,U,Id,K)
                        end;
                    _->{error,unavailable} end;
                _->{error,unavailable} end
        end) end;
        E->E end end end);
start(_,_,_)->{error,invalid_input}.
start_receipt(C,U,Id,K)->
    {ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_study_starts WHERE owner_id=$1",[U]),
    case Count<10000 of false->throw(study_start_quota);true->ok end,
    {ok,1}=bright_sql:equery(C,"INSERT INTO bright_study_starts(pass_id,owner_id,idempotency_key) VALUES($1,$2,$3)",[Id,U,K]),
    read_sql(C,U,Id).
submit(U,Id,K,M) when is_map(M)->
    case read(U,Id) of {ok,_}->submit_owned(U,Id,K,M);E->E end;
submit(_,_,_,_)->{error,invalid_input}.
submit_owned(U,Id,K,M)->
    V=maps:get(<<"expected_version">>,M,undefined),Step=maps:get(<<"step">>,M,undefined),
    Answer=maps:get(<<"answer">>,M,undefined),Kind=maps:get(<<"kind">>,M,undefined),
    Valid=key(K) andalso is_integer(V) andalso V>0 andalso V<2147483647 andalso is_integer(Step) andalso Step>=0 andalso Step=<6
        andalso lists:member(Kind,[<<"answer">>,<<"summary">>]) andalso bright_evidence:text(Answer,2000,false),
    case Valid of false->{error,invalid_input};true->
        Hash=crypto:hash(sha256,term_to_binary({Id,V,Step,Answer,Kind})),
        tx(U,fun(C)->case bright_sql:equery(C,"SELECT pass_id,request_hash,response_json FROM bright_study_attempts WHERE owner_id=$1 AND idempotency_key=$2",[U,K]) of
            {ok,_,[{Id,Hash,Receipt}]}->{ok,jsx:decode(Receipt,[return_maps])};
            {ok,_,[_]}->{error,conflict};
            {ok,_,[]}->case row(C,U,Id) of
                {ok,{Id,_,_,Json,Step,V,State,_,_,_}}->Lessons=jsx:decode(Json,[return_maps]),
                    case transition(State,Kind,Step,Answer,Lessons) of
                        {error,_}=E->E;
                        {NextState,NextStep,Summary,Correct,Feedback}->
                            {ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_study_attempts WHERE owner_id=$1",[U]),
                            case Count<10000 of false->{error,quota_exceeded};true->
                            {ok,1,_,[_]}=bright_sql:equery(C,"UPDATE bright_study_passes SET step=$1,state=$2,summary=$3,version=version+1 WHERE id=$4 AND owner_id=$5 AND version=$6 RETURNING version",[NextStep,NextState,Summary,Id,U,V]),
                            {ok,Pass}=read_sql(C,U,Id),Response=#{pass=>Pass,correct=>Correct,feedback=>Feedback},
                            {ok,1}=bright_sql:equery(C,"INSERT INTO bright_study_attempts(pass_id,owner_id,idempotency_key,request_hash,step,answer,correct,response_json) VALUES($1,$2,$3,$4,$5,$6,$7,$8)",[Id,U,K,Hash,Step,Answer,Correct,jsx:encode(Response)]),
                            %% Decode consistently so a replay has exactly the same return shape.
                            {ok,jsx:decode(jsx:encode(Response),[return_maps])} end
                    end;
                {ok,_}->{error,conflict};E->E end;
            _->{error,unavailable} end end)
    end.
transition(<<"active">>,<<"answer">>,Step,Answer,Lessons)->
    Expected=maps:get(<<"answer">>,lists:nth(Step+1,Lessons)),
    case normalize(Answer)=:=normalize(Expected) of
        true->Next=Step+1,State=case Next=:=length(Lessons) of true-><<"summary">>;false-><<"active">> end,
            {State,Next,<<>>,true,<<"Correct. This chunk is saved as complete.">>};
        false->{<<"active">>,Step,<<>>,false,<<"Try again. Read the passage and enter the missing word; case and surrounding spaces do not matter.">>}
    end;
transition(<<"summary">>,<<"summary">>,Step,Answer,_)->
    Clean=string:trim(Answer),case length(unicode:characters_to_list(Clean))>=20 of
        true->{<<"completed">>,Step,Clean,true,<<"Lesson complete. Your reflection and progress are saved.">>};
        false->{error,invalid_input} end;
transition(_,_,_,_,_)->{error,conflict}.
