%% Preserve embedded text; OCR empty pages under the shared native-job lock.
-module(bright_pdf_ocr).
-export([run/1,run_locked/1]).
run(Data)->global:trans({{bright_native,node()},self()},fun()->extract(Data) end).
run_locked(Data)->extract(Data).
extract(Data)->
 Dir=filename:join("/tmp","bright-pdf-"++binary_to_list(bright_project_auth:new_id())),In=filename:join(Dir,"original.pdf"),
 try
  ok=file:make_dir(Dir),ok=file:change_mode(Dir,8#700),ok=file:write_file(In,Data),ok=file:change_mode(In,8#600),
  D=erlang:monotonic_time(millisecond)+120000,
  case command("pdftotext",["-enc","UTF-8","-layout",In,filename:join(Dir,"text.txt")],D,2097152) of
   {ok,_}->{ok,B}=file:read_file(filename:join(Dir,"text.txt")),Parts=binary:split(B,<<12>>,[global]),
    Pages=case lists:last(Parts) of <<>>->lists:droplast(Parts);_->Parts end,
    case length(Pages)>0 andalso length(Pages)=<200 of
     false->{error,resource_limit};true->case length([P||P<-Pages,string:trim(P)=:= <<>>])>12 of
      true->{error,ocr_page_limit};false->pages(Pages,1,In,Dir,D,[],0) end end;
   E->E end
 catch _:_->{error,invalid_document}
 after case file:list_dir(Dir) of {ok,Fs}->[file:delete(filename:join(Dir,F))||F<-Fs];_->ok end,file:del_dir(Dir) end.
pages([],_,_,_,_,Acc,_)->bright_extract:run(<<"text/plain">>,iolist_to_binary(lists:join(<<"\n\n">>,lists:reverse(Acc))));
pages([P|Rest],N,In,Dir,D,Acc,Size)->
 Result=case string:trim(P) of <<>>->ocr(N,In,Dir,D);_->{ok,P} end,
 case Result of
  {ok,Text} when Size+byte_size(Text)+2=<2097152->pages(Rest,N+1,In,Dir,D,[Text|Acc],Size+byte_size(Text)+2);
  {ok,_}->{error,resource_limit};E->E end.
ocr(N,In,Dir,D)->
 Prefix=filename:join(Dir,"page"),Image=Prefix++".png",Out=filename:join(Dir,"ocr"),
 try
  case command("pdftoppm",["-f",integer_to_list(N),"-l",integer_to_list(N),"-singlefile","-scale-to","2200","-gray","-png",In,Prefix],D,8388608) of
   {ok,_}->ok=file:change_mode(Image,8#600),
    case command("tesseract",[Image,Out,"-l","eng","--psm","3"],D,2097152) of
     {ok,_}->case file:read_file(Out++".txt") of {ok,B}->{ok,B};_->{error,invalid_document} end;E->E end;
   E->E end
 after file:delete(Image),file:delete(Out++".txt") end.
command(Name,Args,D,Output)->
 case {os:find_executable(Name),D-erlang:monotonic_time(millisecond)} of
  {false,_}->{error,extraction_unavailable};{_,Left} when Left=<0->{error,resource_limit};
  {Exe,Left}->bright_native:run(Exe,Args,#{memory=>268435456,cpu=>25,timeout=>min(30000,Left),output=>Output}) end.
