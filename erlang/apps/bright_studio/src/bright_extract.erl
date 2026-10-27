-module(bright_extract).
-export([run/2,book/1]).
-define(MAX_TEXT,2097152).
-define(MAX_ARCHIVE,8388608).
run(<<"application/pdf">>,Data) -> pdf(Data);
run(Mime,Data) ->
    Parent=self(), Tag=make_ref(),
    {Pid,Monitor}=spawn_opt(fun()->
        Result=try extract(Mime,Data) catch throw:resource_limit->{error,resource_limit}; _:_->{error,invalid_document} end,
        Parent!{Tag,Result}
    end,[monitor,{max_heap_size,#{size=>8388608,kill=>true,error_logger=>false,include_shared_binaries=>true}}]),
    receive
        {Tag,Result}->erlang:demonitor(Monitor,[flush]),Result;
        {'DOWN',Monitor,process,Pid,_}->{error,resource_limit}
    after 20000->exit(Pid,kill),erlang:demonitor(Monitor,[flush]),{error,resource_limit} end.
extract(<<"text/plain">>,Data) -> text(Data);
extract(<<"application/epub+zip">>,Data) -> epub(Data);
extract(_,_) -> {error,invalid_document}.
text(Data) when byte_size(Data)>?MAX_TEXT -> {error,resource_limit};
text(Data) ->
    case unicode:characters_to_list(Data) of
        Chars when is_list(Chars) ->
            case lists:any(fun(C)->C=:=0 orelse (C<32 andalso not lists:member(C,[9,10,13])) end,Chars) of
                true->{error,invalid_document};
                false->case string:trim(Data) of <<>>->{error,no_text}; _->{ok,Data} end
            end;
        _->{error,invalid_document}
    end.
pdf(Data) -> bright_pdf_ocr:run(Data).
%% Parse bounded ZIP metadata, then use safeInflate's bounded output chunks.
%% Never write archive paths to disk and never trust declared sizes alone.
archive(Bin) ->
    Matches=binary:matches(Bin,<<"PK",5,6>>), {Pos,_}=lists:last(Matches),
    <<16#06054b50:32/little,0:16/little,0:16/little,Count:16/little,Count:16/little,
      Size:32/little,Offset:32/little,CommentSize:16/little,_Comment:CommentSize/binary>>=binary:part(Bin,Pos,byte_size(Bin)-Pos),
    true=Count>0 andalso Count=<200 andalso Offset+Size=:=Pos,
    Central=binary:part(Bin,Offset,Size),
    entries(Central,Count,Bin,Offset,0,#{}).
entries(<<>>,0,_,_,_,Files)->Files;
entries(Central,N,Bin,End,Total,Files) when N>0 ->
    <<16#02014b50:32/little,_Made:16/little,_Need:16/little,Flags:16/little,Method:16/little,
      _Time:16/little,_Date:16/little,CRC:32/little,Comp:32/little,Size:32/little,
      NameSize:16/little,ExtraSize:16/little,CommentSize:16/little,0:16/little,_Internal:16/little,
      _External:32/little,Start:32/little,Name:NameSize/binary,_Extra:ExtraSize/binary,
      _Comment:CommentSize/binary,Rest/binary>>=Central,
    true=Flags band 1=:=0 andalso lists:member(Method,[0,8]),
    true=valid_path(Name) andalso not maps:is_key(Name,Files),
    case Total+Size=< ?MAX_ARCHIVE of false->throw(resource_limit); true->ok end,
    <<16#04034b50:32/little,_V:16/little,LFlags:16/little,Method:16/little,
      _T:16/little,_D:16/little,_LCrc:32/little,_LCSize:32/little,_LSize:32/little,
      LN:16/little,LE:16/little,_/binary>>=binary:part(Bin,Start,End-Start),
    true=LFlags band 1=:=0,
    DataStart=Start+30+LN+LE,true=DataStart+Comp=<End,
    Name=binary:part(Bin,Start+30,LN),
    Compressed=binary:part(Bin,DataStart,Comp),
    Data=case Method of 0->Compressed;8->inflate(Compressed,Size) end,
    true=byte_size(Data)=:=Size andalso erlang:crc32(Data)=:=CRC,
    entries(Rest,N-1,Bin,End,Total+Size,Files#{Name=>Data}).
valid_path(Name) ->
    is_list(unicode:characters_to_list(Name)) andalso byte_size(Name)>0 andalso
    binary:first(Name)=/=$/ andalso binary:match(Name,<<"\\">>)=:=nomatch andalso
    binary:match(Name,<<":">>)=:=nomatch andalso binary:match(Name,<<0>>)=:=nomatch andalso
    not lists:member(<<"..">>,binary:split(Name,<<"/">>,[global])).
inflate(Bin,Limit) ->
    Z=zlib:open(),
    try
        ok=zlib:inflateInit(Z,-15),
        Output=inflate_chunks(Z,zlib:safeInflate(Z,Bin),Limit,0,[]),
        ok=zlib:inflateEnd(Z),Output
    after zlib:close(Z) end.
inflate_chunks(Z,{State,Chunk},Limit,Size,Acc) when State=:=continue;State=:=finished ->
    Next=Size+iolist_size(Chunk),
    case Next=<Limit of false->throw(resource_limit);true->ok end,
    case State of
        continue->inflate_chunks(Z,zlib:safeInflate(Z,[]),Limit,Next,[Chunk|Acc]);
        finished->iolist_to_binary(lists:reverse([Chunk|Acc]))
    end.
book(Bin)->
 Parent=self(),Tag=make_ref(),{Pid,Ref}=spawn_opt(fun()->
  Result=try {ok,book_inner(Bin)} catch throw:resource_limit->{error,resource_limit};_:_->{error,invalid_document} end,Parent!{Tag,Result}
 end,[monitor,{max_heap_size,#{size=>8388608,kill=>true,error_logger=>false,include_shared_binaries=>true}}]),
 receive {Tag,R}->erlang:demonitor(Ref,[flush]),R;{'DOWN',Ref,process,Pid,_}->{error,resource_limit}
 after 20000->exit(Pid,kill),erlang:demonitor(Ref,[flush]),{error,resource_limit} end.
epub(Bin)->Chapters=book_inner(Bin),text(iolist_to_binary(lists:join(<<"\n\n">>,[maps:get(text,C)||C<-Chapters]))).
book_inner(Bin) ->
    Files=archive(Bin),<<"application/epub+zip">>=maps:get(<<"mimetype">>,Files),
    Roots=sax(maps:get(<<"META-INF/container.xml">>,Files),fun
        ({startElement,_,"rootfile",_,Attrs},_,Acc)->[attr("full-path",Attrs)|Acc];
        (_,_,Acc)->Acc
    end,[]),
    [Root|_]=lists:reverse(Roots),true=valid_path(Root),
    {Manifest,Reversed}=sax(maps:get(Root,Files),fun
        ({startElement,_,"item",_,Attrs},_,{M,S})->
            {M#{attr("id",Attrs)=>{attr("href",Attrs),attr("media-type",Attrs)}},S};
        ({startElement,_,"itemref",_,Attrs},_,{M,S})->{M,[attr("idref",Attrs)|S]};
        (_,_,State)->State
    end,{#{},[]}),
    Chapters=[begin
        {Href,<<"application/xhtml+xml">>}=maps:get(Id,Manifest),
        [NoFragment|_]=binary:split(Href,<<"#">>),
        Decoded=uri_string:percent_decode(NoFragment),
        Canonical=bright_epub_view:resolve(Decoded,Root),
        Body=maps:get(Canonical,Files),
        #{text=>xhtml(Body),nodes=>bright_epub_view:format(Body,Files,Canonical)}
    end || Id<-lists:reverse(Reversed)],
    true=Chapters=/=[],
    Chapters.
attr(Name,Attrs) ->
    {_,_,Name,Value}=lists:keyfind(Name,3,Attrs),unicode:characters_to_binary(Value).
sax(Bin,Fun,Initial) ->
    %% SAX keeps names as strings; untrusted XML cannot exhaust the atom table.
    {ok,State,_}=xmerl_sax_parser:stream(Bin,[{event_fun,Fun},{event_state,Initial},
        disallow_entities,{external_entities,none}]),State.
xhtml(Bin) ->
    State=sax(Bin,fun html_event/3,#{body=>0,hidden=>0,size=>0,chunks=>[]}),
    iolist_to_binary(lists:reverse(maps:get(chunks,State))).
html_event({startElement,_,Name,_,_},_,S=#{hidden:=Hidden}) ->
    case {Name,Hidden} of
        {"body",0}->S#{body=>maps:get(body,S)+1};
        {_,N} when N>0->S#{hidden=>N+1};
        {"script",0}->S#{hidden=>1};
        {"style",0}->S#{hidden=>1};
        {"br",0}->append_text(<<"\n">>,S);
        _->S
    end;
html_event({endElement,_,Name,_},_,S=#{hidden:=Hidden}) ->
    case {Name,Hidden} of
        {_,N} when N>0->S#{hidden=>N-1};
        {"body",0}->S#{body=>max(0,maps:get(body,S)-1)};
        _->case lists:member(Name,["p","div","li","h1","h2","h3","h4","h5","h6"]) of true->append_text(<<"\n">>,S);false->S end
    end;
html_event({characters,Chars},_,S)->append_text(unicode:characters_to_binary(Chars),S);
html_event({ignorableWhitespace,Chars},_,S)->append_text(unicode:characters_to_binary(Chars),S);
html_event(_,_,S)->S.
append_text(B,S=#{body:=Body,hidden:=0,size:=Size,chunks:=Chunks}) when Body>0 ->
    case Size+byte_size(B)=< ?MAX_TEXT of
        true->S#{size=>Size+byte_size(B),chunks=>[B|Chunks]};false->throw(resource_limit)
    end;
append_text(_,S)->S.
