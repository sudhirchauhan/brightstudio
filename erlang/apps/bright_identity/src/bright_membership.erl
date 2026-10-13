-module(bright_membership).
-export([list/1,read/2,create/3,change/4]).
guard(U,F)->bright_mutation:guard("STUDIO_ACCESS_ENABLED",{U,F}).
role(<<"owner">>)->owner;role(<<"admin">>)->admin;role(<<"editor">>)->editor;role(<<"viewer">>)->viewer;role(_)->unknown.
list(U)->guard(U,fun()->bright_sql_pool:with_connection(fun(C)->case bright_sql:equery(C,"SELECT w.id,w.title,w.version,m.role FROM bright_workspaces w JOIN bright_memberships m ON m.workspace_id=w.id WHERE m.user_id=$1 ORDER BY w.created_at,w.id LIMIT 100",[U]) of
 {ok,_,Rows}->{ok,[#{id=>I,title=>T,version=>V,role=>R}||{I,T,V,R}<-Rows]};_->{error,unavailable} end end) end).
workspace(C,U,W,Lock)->Suffix=case Lock of true->" FOR UPDATE OF w";false->"" end,
 case bright_sql:equery(C,"SELECT w.title,w.version,w.owner_id,m.role FROM bright_workspaces w JOIN bright_memberships m ON m.workspace_id=w.id WHERE w.id=$1 AND m.user_id=$2"++Suffix,[W,U]) of
 {ok,_,[{T,V,O,R}]}->{ok,#{id=>W,title=>T,version=>V,owner_id=>O,role=>R}};{ok,_,[]}->{error,not_found};_->{error,unavailable} end.
read(U,W)->guard(U,fun()->case bright_project_auth:uuid(W) of false->{error,not_found};true->bright_sql_pool:with_connection(fun(C)->case workspace(C,U,W,false) of
 {ok,M}->case bright_identity_policy:allowed(role(maps:get(role,M)),manage_members) of true->members(C,W,M);false->{ok,M#{members=>[],can_manage=>false}} end;E->E end end) end end).
members(C,W,M)->case bright_sql:equery(C,"SELECT u.id,u.email,u.display_name,m.role FROM bright_memberships m JOIN bright_users u ON u.id=m.user_id WHERE m.workspace_id=$1 AND u.disabled_at IS NULL ORDER BY u.email LIMIT 100",[W]) of
 {ok,_,Rows}->{ok,M#{can_manage=>true,members=>[#{id=>I,email=>E,display_name=>N,role=>R}||{I,E,N,R}<-Rows]}};_->{error,unavailable} end.
create(U,K,M) when is_map(M)->T=maps:get(<<"title">>,M,undefined),case bright_mutation:keys(M,[<<"title">>]) andalso bright_workspace:text(T,200,false) of
 false->{error,invalid_input};true->bright_mutation:run("STUDIO_ACCESS_ENABLED",<<"membership">>,U,K,{create,M},fun(C)->
 {ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_workspaces WHERE owner_id=$1",[U]),case Count<20 of false->{error,quota_exceeded};true->W=bright_project_auth:new_id(),Title=string:trim(T),
 {ok,1}=bright_sql:equery(C,"INSERT INTO bright_workspaces(id,owner_id,title) VALUES($1,$2,$3)",[W,U,Title]),{ok,1}=bright_sql:equery(C,"INSERT INTO bright_memberships(user_id,workspace_id,role) VALUES($1,$2,$3)",[U,W,<<"owner">>]),{ok,#{id=>W,title=>Title,version=>1,role=><<"owner">>}} end end) end;
create(_,_,_)->{error,invalid_input}.
change(U,W,K,M) when is_map(M)->guard(U,fun()->case bright_project_auth:uuid(W) of false->{error,not_found};true->
 case read(U,W) of {ok,#{can_manage:=true}}->bright_mutation:run("STUDIO_ACCESS_ENABLED",<<"membership">>,U,K,{change,W,M},fun(C)->
 case workspace(C,U,W,true) of {ok,Current}->case bright_identity_policy:allowed(role(maps:get(role,Current)),manage_members) of
 true->edit(C,U,W,Current,M);false->{error,forbidden} end;E->E end end);
 {ok,_}->{error,forbidden};E->E end end end);
change(_,_,_,_)->{error,invalid_input}.
edit(C,U,W,Current,M)->V=maps:get(<<"expected_version">>,M,undefined),Action=maps:get(<<"action">>,M,undefined),Target0=maps:get(<<"user_id">>,M,undefined),Target=case bright_project_auth:uuid(Target0) of true->string:lowercase(Target0);false->Target0 end,Email=maps:get(<<"email">>,M,undefined),NewRole=maps:get(<<"role">>,M,undefined),
 case {bright_workspace:version(V),V=:=maps:get(version,Current)} of {false,_}->{error,invalid_input};{true,false}->{error,conflict};{true,true}->
 case Action of
 <<"add">>->case bright_mutation:keys(M,[<<"action">>,<<"expected_version">>,<<"email">>,<<"role">>]) andalso is_binary(Email) andalso byte_size(Email)=<254 andalso lists:member(NewRole,[<<"admin">>,<<"editor">>,<<"viewer">>]) of
 false->{error,invalid_input};true->case maps:get(role,Current)=:= <<"owner">> orelse NewRole=/= <<"admin">> of false->{error,forbidden};true->
 {ok,_,[{Count}]}=bright_sql:equery(C,"SELECT count(*) FROM bright_memberships WHERE workspace_id=$1",[W]),case Count<100 of false->{error,quota_exceeded};true->
 case bright_sql:equery(C,"SELECT id FROM bright_users WHERE email=$1 AND disabled_at IS NULL",[Email]) of
 {ok,_,[{Id}]}->case bright_sql:equery(C,"SELECT role FROM bright_memberships WHERE workspace_id=$1 AND user_id=$2",[W,Id]) of
 {ok,_,[]}->{ok,1}=bright_sql:equery(C,"INSERT INTO bright_memberships(user_id,workspace_id,role) VALUES($1,$2,$3)",[Id,W,NewRole]),bump(C,W,V);
 {ok,_,[_]}->{error,conflict};_->{error,unavailable} end;
 {ok,_,[]}->{error,not_found};_->{error,unavailable} end end end end;
 A when A=:= <<"role">>;A=:= <<"remove">>->Allowed=case A of <<"role">>->[<<"action">>,<<"expected_version">>,<<"user_id">>,<<"role">>];_->[<<"action">>,<<"expected_version">>,<<"user_id">>] end,
 case bright_mutation:keys(M,Allowed) andalso bright_project_auth:uuid(Target) andalso (A=:= <<"remove">> orelse lists:member(NewRole,[<<"admin">>,<<"editor">>,<<"viewer">>])) of
 false->{error,invalid_input};true->case Target=:=maps:get(owner_id,Current) of true->{error,forbidden};false->
 case bright_sql:equery(C,"SELECT role FROM bright_memberships WHERE workspace_id=$1 AND user_id=$2",[W,Target]) of
 {ok,_,[{Existing}]}->Owner=maps:get(role,Current)=:= <<"owner">>,case Owner orelse (Existing=/= <<"admin">> andalso NewRole=/= <<"admin">> andalso Target=/=U) of
 false->{error,forbidden};true->case A of <<"remove">>->{ok,1}=bright_sql:equery(C,"DELETE FROM bright_memberships WHERE workspace_id=$1 AND user_id=$2",[W,Target]);_-> {ok,1}=bright_sql:equery(C,"UPDATE bright_memberships SET role=$1 WHERE workspace_id=$2 AND user_id=$3",[NewRole,W,Target]) end,bump(C,W,V) end;
 {ok,_,[]}->{error,not_found};_->{error,unavailable} end end end;
 _->{error,invalid_input} end end.
bump(C,W,V)->case bright_sql:equery(C,"UPDATE bright_workspaces SET version=version+1 WHERE id=$1 AND version=$2 RETURNING version",[W,V]) of {ok,1,_,[{Next}]}->{ok,#{id=>W,version=>Next}};_->{error,conflict} end.
