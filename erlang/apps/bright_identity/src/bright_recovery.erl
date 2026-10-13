-module(bright_recovery).
-export([available/0,request/1,reset/2]).
%% Local outbox is explicit and never permitted on a hosted origin.
available()->bright_access:enabled() andalso os:getenv("BRIGHT_RECOVERY_DELIVERY")=:= "local" andalso
 lists:member(os:getenv("BRIGHT_ORIGIN"),["http://127.0.0.1:10000","http://localhost:10000"]) andalso
 os:getenv("BRIGHT_INSECURE_LOCAL_COOKIE")=:= "true" andalso outbox()=/=false.
outbox()->case os:getenv("BRIGHT_RECOVERY_OUTBOX") of false->false;Path->case filename:pathtype(Path) of absolute->Path;_->false end end.
valid_email(B)->is_binary(B) andalso byte_size(B)>3 andalso byte_size(B)=<254 andalso re:run(B,<<"^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$">>,[{capture,none}])=:=match.
accepted()->{ok,#{accepted=>true,message=><<"If this account can be recovered, a reset link will be delivered.">>}}.
request(Email)->case available() of false->{error,not_ready};true->case valid_email(Email) of false->{error,invalid_input};true->
 bright_sql_pool:with_connection(fun(C)->case bright_sql:equery(C,"SELECT id FROM bright_users WHERE email=$1 AND disabled_at IS NULL",[Email]) of
 {ok,_,[]}->accepted();{ok,_,[{U}]}->R=bright_sql:with_transaction(C,fun(T)->
 {ok,_,[_]}=bright_sql:equery(T,"SELECT id FROM bright_users WHERE id=$1 AND disabled_at IS NULL FOR UPDATE",[U]),{ok,_,[{CredentialHash}]}=bright_sql:equery(T,"SELECT password_hash FROM bright_credentials WHERE user_id=$1",[U]),Now=erlang:system_time(millisecond),
 {ok,_}=bright_sql:equery(T,"DELETE FROM bright_password_resets WHERE user_id=$1 AND created_at_ms<$2",[U,Now-86400000]),
 {ok,_,[{Count}]}=bright_sql:equery(T,"SELECT count(*) FROM bright_password_resets WHERE user_id=$1 AND created_at_ms>$2",[U,Now-3600000]),
 case Count<5 of false->accepted();true->I=bright_project_auth:new_id(),Token=binary:encode_hex(crypto:strong_rand_bytes(32),lowercase),Expires=Now+900000,
 {ok,1}=bright_sql:equery(T,"INSERT INTO bright_password_resets(id,user_id,token_hash,password_hash,expires_at_ms,created_at_ms) VALUES($1,$2,$3,$4,$5,$6)",[I,U,crypto:hash(sha256,Token),CredentialHash,Expires,Now]),
 ok=deliver(I,Email,Token,Expires),accepted() end end),case R of {ok,_}->R;_->{error,unavailable} end;
 _->{error,unavailable} end end) end end.
deliver(I,Email,Token,Expires)->Dir=outbox(),ok=filelib:ensure_dir(filename:join(Dir,"placeholder")),ok=file:change_mode(Dir,8#700),
 Path=filename:join(Dir,binary_to_list(I)++".json"),Link=iolist_to_binary([os:getenv("BRIGHT_ORIGIN"),"/studio/reset/#token=",Token]),
 {ok,F}=file:open(Path,[write,exclusive,binary]),try ok=file:change_mode(Path,8#600),ok=file:write(F,jsx:encode(#{to=>Email,reset_url=>Link,expires_at_ms=>Expires})) after file:close(F) end.
reset(Token,New)->case bright_access:enabled() of false->{error,disabled};true->
 case is_binary(Token) andalso re:run(Token,<<"^[0-9a-f]{64}$">>,[{capture,none}])=:=match andalso is_binary(New) andalso byte_size(New)>=12 andalso byte_size(New)=<1024 of
 false->{error,invalid_input};true->Hash=crypto:hash(sha256,Token),bright_sql_pool:with_connection(fun(C)->
 case bright_sql:equery(C,"SELECT user_id FROM bright_password_resets WHERE token_hash=$1",[Hash]) of
 {ok,_,[{U}]}->R=bright_sql:with_transaction(C,fun(T)->Now=erlang:system_time(millisecond),
 case bright_sql:equery(T,"SELECT id FROM bright_users WHERE id=$1 AND disabled_at IS NULL FOR UPDATE",[U]) of
 {ok,_,[_]}->case bright_sql:equery(T,"UPDATE bright_password_resets SET consumed_at_ms=$1 WHERE user_id=$2 AND token_hash=$3 AND consumed_at_ms IS NULL AND expires_at_ms>$1 AND password_hash=(SELECT password_hash FROM bright_credentials WHERE user_id=$2) RETURNING id",[Now,U,Hash]) of
 {ok,1,_,[_]}->Salt=crypto:strong_rand_bytes(16),PasswordHash=bright_session:password_hash(New,Salt),
 {ok,1}=bright_sql:equery(T,"UPDATE bright_credentials SET salt=$1,password_hash=$2 WHERE user_id=$3",[Salt,PasswordHash,U]),
 {ok,_}=bright_sql:equery(T,"UPDATE bright_sessions SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL",[U]),
 {ok,_}=bright_sql:equery(T,"UPDATE bright_password_resets SET consumed_at_ms=$1 WHERE user_id=$2 AND consumed_at_ms IS NULL",[Now,U]),{ok,#{changed=>true,sign_in_required=>true}};
 {ok,0,_,[]}->{error,invalid_input};_ ->throw(reset_failed) end;
 _->{error,invalid_input} end end),case R of {ok,_}->R;{error,_}->R;_->{error,unavailable} end;
 {ok,_,[]}->{error,invalid_input};_->{error,unavailable} end end) end end.
