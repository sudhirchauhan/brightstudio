-module(bright_capture).
-export([run/2,transcription_available/0]).
transcription_available()->case {os:getenv("BRIGHT_WHISPER_EXECUTABLE"),os:getenv("BRIGHT_WHISPER_MODEL_PATH"),os:find_executable("ffmpeg")} of {false,_,_}->false;{_,false,_}->false;{_,_,false}->false;{Exe,Model,_}->filelib:is_regular(Exe) andalso filelib:is_regular(Model) end.
run(Mime,Data)->Dir=filename:join("/tmp","bright-capture-"++binary_to_list(bright_project_auth:new_id())),In=filename:join(Dir,"original"),
 try ok=file:make_dir(Dir),ok=file:change_mode(Dir,8#700),ok=file:write_file(In,Data),ok=file:change_mode(In,8#600),
 case Mime of <<"image/",_/binary>>->ocr(In,Dir);<<"audio/",_/binary>>->audio(In,Dir);_->{error,invalid_document} end
 catch _:_->{error,invalid_document}
 after case file:list_dir(Dir) of {ok,Files}->[file:delete(filename:join(Dir,F))||F<-Files];_->ok end,file:del_dir(Dir) end.
limits()->#{memory=>268435456,cpu=>20,timeout=>30000,output=>262144}.
ocr(In,Dir)->case os:find_executable("tesseract") of false->{error,tool_unavailable};Exe->Out=filename:join(Dir,"captured"),case bright_native:run(Exe,[In,Out,"-l","eng","--psm","6"],limits()) of {ok,_}->text(Out++".txt");E->E end end.
audio(In,Dir)->case transcription_available() of false->{error,transcription_unavailable};true->
 Probe=os:find_executable("ffprobe"),case probe(Probe,In) of
 false->{error,resource_limit};{error,_}=E->E;_->Wav=filename:join(Dir,"audio.wav"),case bright_native:run(os:find_executable("ffmpeg"),["-nostdin","-v","error","-protocol_whitelist","file,pipe","-i",In,"-t","121","-ac","1","-ar","16000","-f","wav",Wav],(limits())#{memory=>1073741824,output=>4194304}) of
 {ok,_}->case probe(Probe,Wav) of true->Out=filename:join(Dir,"transcript"),case bright_native:run(os:getenv("BRIGHT_WHISPER_EXECUTABLE"),["-m",os:getenv("BRIGHT_WHISPER_MODEL_PATH"),"-f",Wav,"-l","en","-t","2","-otxt","-of",Out],#{memory=>1073741824,cpu=>90,timeout=>110000,output=>262144}) of {ok,_}->text(Out++".txt");E->E end;_->{error,resource_limit} end;
 E->E end end end.
probe(Exe,In)->case bright_native:run(Exe,["-v","error","-protocol_whitelist","file,pipe","-show_entries","format=duration","-of","json",In],(limits())#{memory=>1073741824}) of {ok,J}->duration(J);E->E end.
%% MediaRecorder WebM often has no input duration. Decode only 121 seconds,
%% then verify the derived WAV duration before transcribing; never trim silently.
duration(J)->try #{<<"format">>:=#{<<"duration">>:=B}}=jsx:decode(J,[return_maps]),F=binary_to_float(B),F>0 andalso F=<120.5 catch _:_ ->unknown end.

text(Path)->case file:read_file(Path) of {ok,B}->case bright_workspace:text(B,32768,false) of true->{ok,string:trim(B)};false->{error,no_text} end;_->{error,invalid_document} end.
