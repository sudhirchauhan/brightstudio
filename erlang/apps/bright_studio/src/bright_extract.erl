-module(bright_extract).
-export([run/2]).
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
pdf(Data) ->
    case {os:find_executable("pdftotext"),os:find_executable("prlimit")} of
        {false,_}->{error,extraction_unavailable};
        {_,false}->{error,extraction_unavailable};
        {Converter,Limiter}->
            Dir=filename:join("/tmp","bright-extract-"++binary_to_list(bright_project_auth:new_id())),
            In=filename:join(Dir,"original.pdf"),Out=filename:join(Dir,"text.txt"),
            try
                ok=file:make_dir(Dir),ok=file:change_mode(Dir,8#700),
                ok=file:write_file(In,Data),ok=file:change_mode(In,8#600),
                Args=["--as=268435456","--cpu=10","--fsize=2097152","--",Converter,"-enc","UTF-8","-layout","-nopgbrk",In,Out],
                Port=open_port({spawn_executable,Limiter},[binary,exit_status,stderr_to_stdout,use_stdio,{args,Args}]),
                case await_port(Port,erlang:monotonic_time(millisecond)+15000,0) of
                    ok->case file:read_file(Out) of {ok,B}->text(B); _->{error,invalid_document} end;
                    Error->Error
                end
            catch _:_->{error,invalid_document}
            after file:delete(In),file:delete(Out),file:del_dir(Dir) end
    end.
await_port(Port,Deadline,Bytes) ->
    Left=max(0,Deadline-erlang:monotonic_time(millisecond)),
    receive
        {Port,{data,B}} when Bytes+byte_size(B)=<32768 -> await_port(Port,Deadline,Bytes+byte_size(B));
        {Port,{data,_}} -> stop_port(Port),{error,resource_limit};
        {Port,{exit_status,0}} -> ok;
        {Port,{exit_status,N}} when N=:=137;N=:=152;N=:=153 -> {error,resource_limit};
        {Port,{exit_status,_}} -> {error,invalid_document}
    after Left -> stop_port(Port),{error,resource_limit} end.
stop_port(Port) ->
    case erlang:port_info(Port,os_pid) of
        {os_pid,Pid}->
            Kill=open_port({spawn_executable,"/bin/kill"},[exit_status,{args,["-KILL",integer_to_list(Pid)]}]),
            receive {Kill,{exit_status,_}}->ok after 1000->catch port_close(Kill) end;
        _->ok
    end,
    catch port_close(Port),ok.
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
epub(Bin) ->
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
        Path=list_to_binary(filename:join(filename:dirname(binary_to_list(Root)),binary_to_list(Decoded))),
        %% filename:join adds ./ for root-level OPF; canonicalize only that safe prefix.
        Canonical=case Path of <<"./",P/binary>>->P;_->Path end,
        true=valid_path(Canonical),xhtml(maps:get(Canonical,Files))
    end || Id<-lists:reverse(Reversed)],
    true=Chapters=/=[],
    Result=iolist_to_binary(lists:join(<<"\n\n">>,Chapters)),text(Result).
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
