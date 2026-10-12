-module(bright_account).
-export([read/1,edit/3,change_password/3,timezones/0]).
timezones()->{ok,B}=file:read_file(filename:join(code:priv_dir(bright_identity),"timezones.json")),jsx:decode(B).
profile_sql(C,U)->case bright_sql:equery(C,"SELECT email,display_name,timezone,profile_version FROM bright_users WHERE id=$1 AND disabled_at IS NULL",[U]) of
    {ok,_,[{Email,Name,Zone,V}]}->{ok,#{email=>Email,display_name=>Name,timezone=>Zone,version=>V}};
    {ok,_,[]}->{error,unauthenticated};_->{error,unavailable} end.
read(U)->bright_workspace:guard(U,fun()->bright_sql_pool:with_connection(fun(C)->case profile_sql(C,U) of
    {ok,P}->{ok,P#{timezones=>timezones()}};E->E end end) end).
edit(U,K,M) when is_map(M)->
    Name=maps:get(<<"display_name">>,M,undefined),Zone=maps:get(<<"timezone">>,M,undefined),V=maps:get(<<"expected_version">>,M,undefined),
    case bright_workspace:text(Name,100,true) andalso is_binary(Zone) andalso lists:member(Zone,timezones()) andalso bright_workspace:version(V) of
        false->{error,invalid_input};true->Clean=string:trim(Name),bright_workspace:mutate(U,edit_account,K,{V,Clean,Zone},fun(C)->
            case bright_sql:equery(C,"UPDATE bright_users SET display_name=$1,timezone=$2,profile_version=profile_version+1 WHERE id=$3 AND disabled_at IS NULL AND profile_version=$4 RETURNING profile_version",[Clean,Zone,U,V]) of
                {ok,1,_,[_]}->profile_sql(C,U);{ok,0,_,[]}->{error,conflict};_->{error,unavailable} end end)
    end;
edit(_,_,_)->{error,invalid_input}.
change_password(U,Token,M) when is_map(M)->bright_workspace:guard(U,fun()->
    Current=maps:get(<<"current_password">>,M,undefined),New=maps:get(<<"new_password">>,M,undefined),
    case is_binary(Current) andalso byte_size(Current)>0 andalso byte_size(Current)=<1024 andalso
        is_binary(New) andalso byte_size(New)>=12 andalso byte_size(New)=<1024 andalso New=/=Current of
        false->{error,invalid_input};true->bright_workspace:transaction(U,fun(C)->
            case bright_sql:equery(C,"SELECT c.salt,c.password_hash FROM bright_credentials c JOIN bright_sessions s ON s.user_id=c.user_id WHERE c.user_id=$1 AND s.token_hash=$2 AND s.revoked_at IS NULL AND s.expires_at>now()",[U,crypto:hash(sha256,Token)]) of
                {ok,_,[{Salt,Hash}]}->case crypto:hash_equals(Hash,bright_session:password_hash(Current,Salt)) of
                    false->{error,wrong_password};true->NewSalt=crypto:strong_rand_bytes(16),NewHash=bright_session:password_hash(New,NewSalt),
                        {ok,1}=bright_sql:equery(C,"UPDATE bright_credentials SET salt=$1,password_hash=$2 WHERE user_id=$3",[NewSalt,NewHash,U]),
                        {ok,_}=bright_sql:equery(C,"UPDATE bright_sessions SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL",[U]),
                        {ok,#{changed=>true,sign_in_required=>true}}
                end;
                {ok,_,[]}->{error,unauthenticated};_->{error,unavailable} end end)
    end end);
change_password(_,_,_)->{error,invalid_input}.
