-module(bright_evidence).
-export([text/3,enabled/0,anchor/4,create/3,list/3,read/2,edit/4,history/2,boards/2,board/2,create_board/3,link/3]).
enabled()->bright_library:enabled() andalso os:getenv("STUDIO_EVIDENCE_ENABLED")=:= "true".
key(K)->is_binary(K) andalso re:run(K,<<"^[!-~]{16,128}$">>,[{capture,none}])=:=match.
text(B,Max,Empty) when is_binary(B),byte_size(B)=<Max*4 ->
    case unicode:characters_to_list(B) of
        L when is_list(L),length(L)=<Max -> (Empty orelse string:trim(B)=/= <<>>) andalso
            lists:all(fun(C)->C>=32 orelse lists:member(C,[9,10,13]) end,L);
        _->false
    end;
text(_,_,_)->false.
anchor(T,S,E,Q) when is_binary(T),is_integer(S),is_integer(E),S>=0,E>S,E=<byte_size(T),is_binary(Q),byte_size(Q)=<8192 ->
    text(Q,2048,false) andalso byte_size(Q)=:=E-S andalso binary:part(T,S,E-S)=:=Q
      andalso is_list(unicode:characters_to_list(binary:part(T,0,S)));
anchor(_,_,_,_)->false.
guard(User,Fun)->
    case enabled() of
        false->{error,disabled};
        true->case bright_identity:profile(User) of {ok,_}->Fun();Error->Error end
    end.
owned(User,Id,Fun)->guard(User,fun()->
    case bright_project_auth:uuid(Id) of
        false->{error,not_found};
        true->bright_sql_pool:with_connection(fun(C)->
            case bright_sql:equery(C,"SELECT id FROM bright_evidence WHERE id=$1 AND owner_id=$2",[Id,User]) of
                {ok,_,[_]}->Fun(C);
                {ok,_,[]}->{error,not_found};_->{error,unavailable}
            end
        end)
    end
end).
transaction(User,Fun)->bright_sql_pool:with_connection(fun(C)->
    Result=bright_sql:with_transaction(C,fun(T)->
        case bright_sql:equery(T,"SELECT id FROM bright_users WHERE id=$1 AND disabled_at IS NULL FOR UPDATE",[User]) of
            {ok,_,[_]}->Fun(T);{ok,_,[]}->{error,unauthenticated};_->{error,unavailable}
        end
    end),
    case Result of {ok,_}->Result;{error,_}->Result;_->{error,unavailable} end
end).
create(User,Key,M) when is_map(M)->guard(User,fun()->
    Source=maps:get(<<"source_id">>,M,undefined),Revision=maps:get(<<"revision_id">>,M,undefined),
    S=maps:get(<<"start_byte">>,M,undefined),E=maps:get(<<"end_byte">>,M,undefined),
    Q=maps:get(<<"quote">>,M,undefined),Note=maps:get(<<"note">>,M,<<>>),
    case key(Key) andalso text(Note,4000,true) of
        false->{error,invalid_input};
        true->case bright_library:content(User,Source,Revision) of
            {ok,#{text:=T}}->case anchor(T,S,E,Q) of
                false->{error,invalid_input};
                true->Hash=crypto:hash(sha256,term_to_binary({Source,Revision,S,E,Q,Note})),
                    transaction(User,fun(C)->
                        case bright_sql:equery(C,"SELECT id,request_hash FROM bright_evidence WHERE owner_id=$1 AND idempotency_key=$2",[User,Key]) of
                            {ok,_,[{Id,Hash}]}->read_sql(C,User,Id);
                            {ok,_,[_]}->{error,conflict};
                            {ok,_,[]}->
                                {ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_evidence WHERE owner_id=$1",[User]),
                                case Count<1000 of
                                    false->{error,quota_exceeded};
                                    true->Id=bright_project_auth:new_id(),
                                        {ok,1}=bright_sql:equery(C,"INSERT INTO bright_evidence(id,owner_id,source_id,revision_id,start_byte,end_byte,quote,text_sha256,note,idempotency_key,request_hash) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)",[Id,User,Source,Revision,S,E,Q,crypto:hash(sha256,T),Note,Key,Hash]),
                                        {ok,1}=bright_sql:equery(C,"INSERT INTO bright_evidence_notes(evidence_id,owner_id,version,note,idempotency_key,request_hash) VALUES($1,$2,1,$3,$4,$5)",[Id,User,Note,Key,Hash]),
                                        read_sql(C,User,Id)
                                end;
                            _->{error,unavailable}
                        end
                    end)
            end;
            Error->Error
        end
    end
end);
create(_,_,_)->{error,invalid_input}.
columns()->"e.id,e.source_id,e.revision_id,e.start_byte,e.end_byte,e.quote,e.text_sha256,e.note,e.version,s.title,r.revision,(r.state='ready' AND sha256(convert_to(r.text_content,'UTF8'))=e.text_sha256 AND substring(convert_to(r.text_content,'UTF8') FROM e.start_byte+1 FOR e.end_byte-e.start_byte)=convert_to(e.quote,'UTF8'))".
joins()->" FROM bright_evidence e JOIN bright_sources s ON s.id=e.source_id AND s.owner_id=e.owner_id JOIN bright_source_revisions r ON r.id=e.revision_id AND r.owner_id=e.owner_id ".
item({Id,Source,R,S,E,Q,_H,N,V,Title,RV,Resolved})->
    #{id=>Id,source_id=>Source,revision_id=>R,start_byte=>S,end_byte=>E,quote=>Q,note=>N,version=>V,
      source_title=>Title,revision=>RV,anchor_state=>case Resolved of true->resolved;_->unresolved end}.
query(C,Sql,Args)->
    case bright_sql:sqlite(C) of
        false->case bright_sql:equery(C,Sql,Args) of
            {ok,_,Rows}->{ok,[item(R)||R<-Rows]};_->{error,unavailable} end;
        true->
            %% SQLite has no built-in SHA-256. Hash each distinct revision once
            %% without retaining whole texts; SQLite validates the byte slice.
            [Projection,Rest]=string:split(Sql,joins()),
            [Fields,_]=string:split(Projection,",(r.state='ready'"),
            QuoteCheck=",(r.state='ready' AND length(CAST(r.text_content AS BLOB))>=e.end_byte AND substr(CAST(r.text_content AS BLOB),e.start_byte+1,e.end_byte-e.start_byte)=CAST(e.quote AS BLOB))",
            case bright_sql:equery(C,Fields++QuoteCheck++joins()++Rest,Args) of
                {ok,_,Rows}->
                    Revisions=lists:usort([element(3,R)||R<-Rows]),
                    Hashes=maps:from_list([{Id,sqlite_hash(C,Id)}||Id<-Revisions]),
                    {ok,[item(setelement(12,R,element(12,R)=:=1 andalso element(7,R)=:=maps:get(element(3,R),Hashes)))||R<-Rows]};
                _->{error,unavailable}
            end
    end.
sqlite_hash(C,Id)->case bright_sql:equery(C,"SELECT text_content FROM bright_source_revisions WHERE id=$1",[Id]) of
    {ok,_,[{Text}]} when is_binary(Text)->crypto:hash(sha256,Text);
    _->undefined
end.
read_sql(C,User,Id)->case query(C,"SELECT "++columns()++joins()++"WHERE e.owner_id=$1 AND e.id=$2",[User,Id]) of
    {ok,[I]}->{ok,I};{ok,[]}->{error,not_found};Error->Error end.
read(User,Id)->owned(User,Id,fun(C)->read_sql(C,User,Id) end).
list(User,Source,Revision)->guard(User,fun()->
    case bright_library:revisions(User,Source) of
        {ok,Rs}->case Revision=:= <<>> orelse lists:any(fun(R)->maps:get(id,R)=:=Revision end,Rs) of
            false->{error,not_found};
            true->bright_sql_pool:with_connection(fun(C)->query(C,"SELECT "++columns()++joins()++"WHERE e.owner_id=$1 AND e.source_id=$2 AND ($3='' OR e.revision_id::text=$3) ORDER BY e.created_at,e.id LIMIT 1000",[User,Source,Revision]) end)
        end;
        Error->Error
    end
end).
edit(User,Id,Key,M) when is_map(M)->
    case read(User,Id) of {ok,_}->edit_authorized(User,Id,Key,M);Error->Error end;
edit(_,_,_,_)->{error,invalid_input}.
edit_authorized(User,Id,Key,M)->
    Note=maps:get(<<"note">>,M,undefined),Version=maps:get(<<"expected_version">>,M,undefined),
    case key(Key) andalso text(Note,4000,true) andalso is_integer(Version) andalso Version>0 andalso Version<2147483647 of
        false->{error,invalid_input};
        true->Hash=crypto:hash(sha256,term_to_binary({Id,Version,Note})),
            transaction(User,fun(C)->
                case bright_sql:equery(C,"SELECT evidence_id,version,note,request_hash FROM bright_evidence_notes WHERE owner_id=$1 AND idempotency_key=$2",[User,Key]) of
                    {ok,_,[{Id,V,Note,Hash}]}->{ok,#{id=>Id,version=>V,note=>Note}};
                    {ok,_,[_]}->{error,conflict};
                    {ok,_,[]}->
                        case bright_sql:equery(C,"UPDATE bright_evidence SET note=$1,version=version+1 WHERE id=$2 AND owner_id=$3 AND version=$4 RETURNING version",[Note,Id,User,Version]) of
                            {ok,1,_,[{V}]}->
                                {ok,1}=bright_sql:equery(C,"INSERT INTO bright_evidence_notes(evidence_id,owner_id,version,note,idempotency_key,request_hash) VALUES($1,$2,$3,$4,$5,$6)",[Id,User,V,Note,Key,Hash]),
                                {ok,#{id=>Id,version=>V,note=>Note}};
                            {ok,0,_,[]}->{error,conflict};_->{error,unavailable}
                        end;
                    _->{error,unavailable}
                end
            end)
    end.
history(User,Id)->owned(User,Id,fun(C)->
    case bright_sql:equery(C,"SELECT version,note FROM bright_evidence_notes WHERE evidence_id=$1 AND owner_id=$2 ORDER BY version DESC LIMIT 1000",[Id,User]) of
        {ok,_,Rows}->{ok,[#{version=>V,note=>N}||{V,N}<-Rows]};_->{error,unavailable}
    end
end).
boards(User,Project)->guard(User,fun()->case bright_project_auth:authorize(User,Project) of
    ok->bright_sql_pool:with_connection(fun(C)->case bright_sql:equery(C,"SELECT id,project_id,title FROM bright_evidence_boards WHERE owner_id=$1 AND project_id=$2 ORDER BY created_at,id LIMIT 100",[User,Project]) of
        {ok,_,Rows}->{ok,[board_map(R)||R<-Rows]};_->{error,unavailable} end end);
    Error->Error end end).
board_map({Id,P,T})->#{id=>Id,project_id=>P,title=>T}.
board(User,Id)->guard(User,fun()->case bright_project_auth:uuid(Id) of
    false->{error,not_found};
    true->bright_sql_pool:with_connection(fun(C)->
        case bright_sql:equery(C,"SELECT id,project_id,title FROM bright_evidence_boards WHERE id=$1 AND owner_id=$2",[Id,User]) of
            {ok,_,[B]}->case query(C,"SELECT "++columns()++joins()++"JOIN bright_evidence_links l ON l.evidence_id=e.id AND l.owner_id=e.owner_id WHERE l.board_id=$1 AND l.owner_id=$2 ORDER BY l.created_at,e.id LIMIT 1000",[Id,User]) of
                {ok,Items}->{ok,(board_map(B))#{items=>Items}};Error->Error end;
            {ok,_,[]}->{error,not_found};_->{error,unavailable}
        end
    end)
end end).
create_board(User,Key,M) when is_map(M)->guard(User,fun()->
    Project=maps:get(<<"project_id">>,M,undefined),Title=maps:get(<<"title">>,M,undefined),
    case key(Key) andalso text(Title,120,false) of
        false->{error,invalid_input};
        true->case bright_project_auth:authorize(User,Project) of
            ok->Clean=string:trim(Title),transaction(User,fun(C)->
                case bright_sql:equery(C,"SELECT id,project_id,title FROM bright_evidence_boards WHERE owner_id=$1 AND idempotency_key=$2",[User,Key]) of
                    {ok,_,[{_,Project,Clean}=B]}->{ok,board_map(B)};
                    {ok,_,[_]}->{error,conflict};
                    {ok,_,[]}->{ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_evidence_boards WHERE owner_id=$1",[User]),
                        case Count<100 of
                            false->{error,quota_exceeded};
                            true->Id=bright_project_auth:new_id(),{ok,1}=bright_sql:equery(C,"INSERT INTO bright_evidence_boards(id,owner_id,project_id,title,idempotency_key) VALUES($1,$2,$3,$4,$5)",[Id,User,Project,Clean,Key]),{ok,board_map({Id,Project,Clean})}
                        end;
                    _->{error,unavailable}
                end
            end);
            Error->Error
        end
    end
end);
create_board(_,_,_)->{error,invalid_input}.
link(User,Board,Evidence)->case read(User,Evidence) of
    {ok,_}->link_authorized(User,Board,Evidence);Error->Error end.
link_authorized(User,Board,Evidence)->
    case board(User,Board) of
        {ok,_}->transaction(User,fun(C)->
            {ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_evidence_links WHERE board_id=$1 AND owner_id=$2",[Board,User]),
            {ok,_,Existing}=bright_sql:equery(C,"SELECT evidence_id FROM bright_evidence_links WHERE board_id=$1 AND evidence_id=$2 AND owner_id=$3",[Board,Evidence,User]),
            case Count<1000 orelse Existing=/=[] of
                false->{error,quota_exceeded};
                true->{ok,_}=bright_sql:equery(C,"INSERT INTO bright_evidence_links(board_id,evidence_id,owner_id) VALUES($1,$2,$3) ON CONFLICT DO NOTHING",[Board,Evidence,User]),{ok,#{linked=>true}}
            end
        end);
        Error->Error
    end.
