-module(bright_dev_bootstrap).
-export([main/0]).

%% Explicit, opt-in startup for disposable SQLite development instances only.
%% PostgreSQL releases continue to require operator-run migrations.
main()->
    try
        "true"=os:getenv("BRIGHT_SQLITE_DEVELOPMENT"),
        "sqlite:"++_=os:getenv("DATABASE_URL"),
        {ok,_}=application:ensure_all_started(bright_platform),
        ok=bright_migrate:run(),
        Email=required("BRIGHT_BOOTSTRAP_EMAIL"),
        Password=required("BRIGHT_BOOTSTRAP_PASSWORD"),
        Title=required("BRIGHT_BOOTSTRAP_PROJECT"),
        true=byte_size(Password)>=12 andalso byte_size(Password)=<1024,
        Existing=bright_sql_pool:with_connection(fun(C)->
            bright_sql:equery(C,"SELECT id FROM bright_users WHERE email=$1",[Email])
        end),
        case Existing of
            {ok,_,[]}->{ok,_,_}=bright_session:provision(Email,Password,Title);
            {ok,_,[_]}->ok
        end,
        io:format("SQLite development schema and account are ready.~n"),
        erlang:halt(0)
    catch _:_ ->
        io:format(standard_error,"SQLite development initialization failed; check configuration.~n",[]),
        erlang:halt(1)
    end.
required(Name)->
    case os:getenv(Name) of false->error(missing_setting);""->error(missing_setting);V->unicode:characters_to_binary(V) end.
