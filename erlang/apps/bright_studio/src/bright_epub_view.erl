%% Declarative reflow only: publisher HTML/CSS/scripts/URLs never execute.
-module(bright_epub_view).
-export([format/3,resolve/2]).
format(Bin,Files,Path)->
 {ok,State,_}=xmerl_sax_parser:stream(Bin,[{event_fun,fun(E,_,S)->event(E,S,Files,Path) end},
  {event_state,#{body=>0,hidden=>0,stack=>[{<<"root">>,[]}]}},disallow_entities,{external_entities,none}]),
 [{_,Nodes}]=maps:get(stack,State),lists:reverse(Nodes).
event({startElement,_,"body",_,_},S,_,_)->S#{body=>1};
event({endElement,_,"body",_},S,_,_)->S#{body=>0};
event({startElement,_,Name,_,Attrs},S=#{body:=1,hidden:=0,stack:=Stack},Files,Path)->
 case lists:member(Name,["script","style","iframe","object","svg","math","form"]) of
  true->S#{hidden=>1};false->case Name of
   "img"->node(image(Attrs,Files,Path),S#{hidden=>1});
   _->Tag=case lists:member(Name,["p","div","h1","h2","h3","h4","h5","h6","em","strong","b","i","blockquote","ul","ol","li","table","thead","tbody","tr","td","th","pre","code","br","hr","sup","sub"]) of true->list_to_binary(Name);false-><<"span">> end,
      S#{stack=>[{Tag,[]}|Stack]} end end;
event({startElement,_,_,_,_},S=#{hidden:=N},_,_) when N>0->S#{hidden=>N+1};
event({endElement,_,_,_},S=#{hidden:=N},_,_) when N>0->S#{hidden=>N-1};
event({endElement,_,_,_},S=#{body:=1,stack:=[{Tag,Nodes}|Tail]},_,_)->node(#{tag=>Tag,children=>lists:reverse(Nodes)},S#{stack=>Tail});
event({characters,C},S=#{body:=1,hidden:=0},_,_)->node(#{text=>unicode:characters_to_binary(C)},S);
event({ignorableWhitespace,C},S=#{body:=1,hidden:=0},_,_)->node(#{text=>unicode:characters_to_binary(C)},S);
event(_,S,_,_)->S.
node(N,S=#{stack:=[{Tag,Nodes}|Rest]})->S#{stack=>[{Tag,[N|Nodes]}|Rest]}.
image(Attrs,Files,Path)->
 Alt=case lists:keyfind("alt",3,Attrs) of false-><<"Book illustration">>;{_,_,_,A}->unicode:characters_to_binary(A) end,
 try
  {_,_,_,Source}=lists:keyfind("src",3,Attrs),Src=uri_string:percent_decode(unicode:characters_to_binary(Source)),
  Canon=resolve(Src,Path),B=maps:get(Canon,Files),true=byte_size(B)=<1048576,
  Mime=case B of <<137,80,78,71,13,10,26,10,_/binary>>-><<"image/png">>;<<255,216,255,_/binary>>-><<"image/jpeg">> end,
  #{tag=><<"img">>,alt=>Alt,mime=>Mime,data=>base64:encode(B)}
 catch _:_ ->#{tag=><<"span">>,children=>[#{text=>Alt}]} end.
safe(B)->byte_size(B)>0 andalso binary:first(B)=/=$/ andalso binary:match(B,<<":">>)=:=nomatch andalso binary:match(B,<<"\\">>)=:=nomatch andalso not lists:member(<<"..">>,binary:split(B,<<"/">>,[global])).

%% Resolve relative book paths inside the archive; never allow escape or URLs.
resolve(Href,Base)->
 true=byte_size(Href)>0 andalso binary:first(Href)=/=$/,
 true=binary:match(Href,<<":">>)=:=nomatch andalso binary:match(Href,<<"\\">>)=:=nomatch andalso binary:match(Href,<<0>>)=:=nomatch,
 Dir=filename:dirname(binary_to_list(Base)),Prefix=case Dir of "."->[];_->binary:split(list_to_binary(Dir),<<"/">>,[global]) end,
 Parts=lists:foldl(fun
  (<<"..">>,[_|Rest])->Rest;
  (<<"..">>,[])->error(archive_escape);
  (<<".">>,Acc)->Acc;
  (<<>>,Acc)->Acc;
  (Part,Acc)->[Part|Acc]
 end,lists:reverse(Prefix),binary:split(Href,<<"/">>,[global])),
 Result=iolist_to_binary(lists:join(<<"/">>,lists:reverse(Parts))),true=safe(Result),Result.
