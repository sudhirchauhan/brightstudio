-module(bright_access).
-export([enabled/0,sessions/2,revoke_session/3,revoke_all/1]).
enabled()->bright_mutation:enabled("STUDIO_ACCESS_ENABLED").
guard(U,F)->bright_mutation:guard("STUDIO_ACCESS_ENABLED",{U,F}).
sessions(U,Token)->guard(U,fun()->Hash=crypto:hash(sha256,Token),bright_sql_pool:with_connection(fun(C)->
 case bright_sql:equery(C,"SELECT token_hash,created_at,expires_at FROM bright_sessions WHERE user_id=$1 AND revoked_at IS NULL AND expires_at>now() ORDER BY created_at DESC LIMIT 100",[U]) of
 {ok,_,Rows}->{ok,[#{id=>binary:encode_hex(H,lowercase),created_at=>date(A),expires_at=>date(B),current=>crypto:hash_equals(H,Hash)}||{H,A,B}<-Rows]};_->{error,unavailable} end end) end).
date(B) when is_binary(B)->B;
date({{Y,M,D},{H,N,S}})->iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0B",[Y,M,D,H,N,trunc(S)]));
date(_)-> <<"">>.
revoke_session(U,Token,Id)->guard(U,fun()->case is_binary(Id) andalso re:run(Id,<<"^[0-9a-f]{64}$">>,[{capture,none}])=:=match of
 false->{error,not_found};true->Hash=binary:decode_hex(Id),bright_workspace:transaction(U,fun(C)->
 case bright_sql:equery(C,"UPDATE bright_sessions SET revoked_at=now() WHERE user_id=$1 AND token_hash=$2 AND revoked_at IS NULL RETURNING token_hash",[U,Hash]) of
 {ok,1,_,[_]}->{ok,#{revoked=>true,sign_in_required=>crypto:hash_equals(Hash,crypto:hash(sha256,Token))}};
 {ok,0,_,[]}->case bright_sql:equery(C,"SELECT token_hash FROM bright_sessions WHERE user_id=$1 AND token_hash=$2",[U,Hash]) of {ok,_,[_]}->{ok,#{revoked=>true,sign_in_required=>crypto:hash_equals(Hash,crypto:hash(sha256,Token))}};_->{error,not_found} end;
 _->{error,unavailable} end end) end end).
revoke_all(U)->guard(U,fun()->bright_workspace:transaction(U,fun(C)->{ok,_}=bright_sql:equery(C,"UPDATE bright_sessions SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL",[U]),{ok,#{revoked=>true,sign_in_required=>true}} end) end).
