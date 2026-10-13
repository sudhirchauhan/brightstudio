#!/usr/bin/env escript
%% Consistent operator backup, not a public HTTP endpoint. Never overwrite live data.
main([Output]) ->
    code:add_paths(filelib:wildcard("_build/prod/rel/bright_studio/lib/*/ebin")),
    application:ensure_all_started(crypto),
    case os:getenv("DATABASE_URL") of
        "sqlite:"++Source ->
            true=filename:pathtype(Output)=:=absolute,
            true=filename:absname(Source)=/=filename:absname(Output),
            false=filelib:is_file(Output),ok=filelib:ensure_dir(Output),
            {ok,C}=bright_db:connect("sqlite:"++Source),
            try
                {ok,_}=bright_sql:equery(C,"VACUUM INTO $1",[list_to_binary(Output)]),
                ok=file:change_mode(Output,8#600)
            after bright_sql:close(C) end,
            {ok,B}=bright_db:connect("sqlite:"++Output),
            try {ok,_,[{<<"ok">>}]}=bright_sql:squery(B,"PRAGMA integrity_check"),
                {ok,_,[]}=bright_sql:squery(B,"PRAGMA foreign_key_check")
            after bright_sql:close(B) end,
            {ok,Bytes}=file:read_file(Output),
            io:format("Backup complete; bytes=~B; sha256=~s~n",[byte_size(Bytes),binary:encode_hex(crypto:hash(sha256,Bytes),lowercase)]);
        _ -> erlang:error(sqlite_backup_requires_explicit_sqlite_database)
    end;
main(_) -> erlang:error(usage_absolute_new_backup_path).
