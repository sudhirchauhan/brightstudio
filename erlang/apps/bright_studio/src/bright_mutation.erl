-module(bright_mutation).
-export([enabled/1,guard/2,keys/2,run/6]).
enabled(Flag)->os:getenv("STUDIO_HUB_ENABLED")=:= "true" andalso os:getenv(Flag)=:= "true".
guard(Flag,{U,F})->case enabled(Flag) of false->{error,disabled};true->case bright_identity:profile(U) of {ok,_}->F();E->E end end.
keys(M,Allowed)->is_map(M) andalso lists:all(fun(K)->lists:member(K,Allowed) end,maps:keys(M)).
run(Flag,Feature,U,K,Payload,F)->guard(Flag,{U,fun()->
 case is_binary(K) andalso re:run(K,<<"^[!-~]{16,128}$">>,[{capture,none}])=:=match of
 false->{error,invalid_input};true->Hash=crypto:hash(sha256,term_to_binary(Payload)),
 bright_workspace:transaction(U,fun(C)->case bright_sql:equery(C,"SELECT request_hash,response_json FROM bright_mutation_receipts WHERE owner_id=$1 AND feature=$2 AND idempotency_key=$3",[U,Feature,K]) of
 {ok,_,[{Hash,Json}]}->{ok,jsx:decode(Json,[return_maps])};{ok,_,[_]}->{error,conflict};
 {ok,_,[]}->{ok,_,[{N}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_mutation_receipts WHERE owner_id=$1 AND feature=$2",[U,Feature]),
 case N<10000 of false->{error,quota_exceeded};true->case F(C) of
 {ok,V}->Json=jsx:encode(V),{ok,1}=bright_sql:equery(C,"INSERT INTO bright_mutation_receipts(owner_id,feature,idempotency_key,request_hash,response_json) VALUES($1,$2,$3,$4,$5)",[U,Feature,K,Hash,Json]),{ok,jsx:decode(Json,[return_maps])};E->E end end;
 _->{error,unavailable} end end) end end}).
