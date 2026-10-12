-module(bright_dev_samples).
-export([run/2]).

%% Bundled, owned sample documents for disposable SQLite demos only. A marker
%% prevents replay from altering samples the user has subsequently edited.
run(User,Project)->
    "true"=os:getenv("BRIGHT_SQLITE_DEVELOPMENT"),
    "sqlite:"++_=os:getenv("DATABASE_URL"),
    {ok,Manifest}=file:read_file(filename:join(directory(),"manifest.json")),
    M=jsx:decode(Manifest,[return_maps]),Version=maps:get(<<"version">>,M),
    Done=bright_sql_pool:with_connection(fun(C)->
        {ok,_,_}=bright_sql:squery(C,"CREATE TABLE IF NOT EXISTS bright_dev_seed_state (owner_id TEXT NOT NULL REFERENCES bright_users(id), version TEXT NOT NULL, PRIMARY KEY(owner_id,version))"),
        {ok,_,Rows}=bright_sql:equery(C,"SELECT version FROM bright_dev_seed_state WHERE owner_id=$1 AND version=$2",[User,Version]),
        Rows=/=[]
    end),
    case Done of
        true->ok;
        false->
            Sources=maps:from_list([seed_source(User,Project,Version,S)||S<-maps:get(<<"sources">>,M)]),
            Evidence=maps:from_list([seed_evidence(User,Version,E,Sources)||E<-maps:get(<<"evidence">>,M)]),
            lists:foreach(fun(B)->seed_board(User,Project,Version,B,Evidence) end,maps:get(<<"boards">>,M)),
            bright_sql_pool:with_connection(fun(C)->
                {ok,_}=bright_sql:equery(C,"INSERT INTO bright_dev_seed_state(owner_id,version) VALUES($1,$2) ON CONFLICT DO NOTHING",[User,Version]),ok
            end)
    end.
directory()->filename:join(code:priv_dir(bright_studio),"development_samples").
key(Version,Kind,Label)->binary:encode_hex(crypto:hash(sha256,<<"bright-demo:",Version/binary,":",Kind/binary,":",Label/binary>>),lowercase).
seed_source(User,Project,Version,S)->
    Label=maps:get(<<"key">>,S),
    {ok,Source}=bright_source:create(User,key(Version,<<"source">>,Label),#{<<"title">>=>maps:get(<<"title">>,S),<<"project_id">>=>Project,<<"kind">>=>maps:get(<<"kind">>,S,<<"book">>)}),
    Id=maps:get(id,Source),
    Revisions=[begin
        Name=maps:get(<<"file">>,R),{ok,Data}=file:read_file(filename:join(directory(),binary_to_list(Name))),
        {ok,Revision}=bright_library:upload(User,Id,key(Version,<<"revision">>,Name),#{filename=>Name,mime=>maps:get(<<"mime">>,R),data=>Data}),
        ok=await_state(User,Id,maps:get(id,Revision),maps:get(<<"state">>,R,<<"ready">>),400),
        Revision
    end||R<-maps:get(<<"revisions">>,S)],
    {Label,#{id=>Id,revisions=>Revisions}}.
await_state(_,_,_,_,0)->error(sample_extraction_timeout);
await_state(User,Source,Id,Wanted,Remaining)->
    {ok,Revisions}=bright_library:revisions(User,Source),
    [Revision]=[R||R<-Revisions,maps:get(id,R)=:=Id],
    case maps:get(state,Revision) of
        Wanted->ok;
        <<"failed">>->error(sample_extraction_failed);
        _->bright_source_worker:process_one(),timer:sleep(100),await_state(User,Source,Id,Wanted,Remaining-1)
    end.
seed_evidence(User,Version,E,Sources)->
    Label=maps:get(<<"key">>,E),S=maps:get(maps:get(<<"source">>,E),Sources),
    R=lists:nth(maps:get(<<"revision">>,E),maps:get(revisions,S)),
    Source=maps:get(id,S),Revision=maps:get(id,R),
    {ok,#{text:=Text}}=bright_library:content(User,Source,Revision),Quote=maps:get(<<"quote">>,E),
    {Start,Length}=binary:match(Text,Quote),
    {ok,Item}=bright_evidence:create(User,key(Version,<<"evidence">>,Label),#{<<"source_id">>=>Source,<<"revision_id">>=>Revision,<<"start_byte">>=>Start,<<"end_byte">>=>Start+Length,<<"quote">>=>Quote,<<"note">>=>maps:get(<<"note">>,E)}),
    Id=maps:get(id,Item),
    case {maps:find(<<"edited_note">>,E),maps:get(version,Item)} of
        {{ok,Note},1}->{ok,_}=bright_evidence:edit(User,Id,key(Version,<<"edit">>,Label),#{<<"note">>=>Note,<<"expected_version">>=>1});
        _->ok
    end,
    {Label,Id}.
seed_board(User,Project,Version,B,Evidence)->
    {ok,Board}=bright_evidence:create_board(User,key(Version,<<"board">>,maps:get(<<"key">>,B)),#{<<"project_id">>=>Project,<<"title">>=>maps:get(<<"title">>,B)}),
    lists:foreach(fun(Label)->{ok,_}=bright_evidence:link(User,maps:get(id,Board),maps:get(Label,Evidence)) end,maps:get(<<"evidence">>,B)).
