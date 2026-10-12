-module(bright_migrate).
-export([run/0, run/1, apply_migrations/2, sort_migration_files/1]).
-define(LOCK_ID, 74190321).

%% Run only as an explicit release job, never during web/worker boot.
run() ->
    case os:getenv("DATABASE_URL") of
        false -> {error, missing_database_url};
        Url -> run(Url)
    end.

run(Url) ->
    case bright_db:connect(Url) of
        {ok, Conn} ->
            try
                case migration_files(Conn) of
                    {error, _} = Error -> Error;
                    Files -> case bright_sql:sqlite(Conn) of
                        true->apply_sqlite_migrations(Conn,Files);
                        false->apply_migrations(Conn, Files)
                    end
                end
            after bright_sql:close(Conn) end;
        Error -> Error
    end.

apply_migrations(Conn, Files) ->
    case bright_sql:equery(Conn, "SELECT pg_advisory_lock($1)", [?LOCK_ID]) of
        {ok, _, _} ->
            try
                case bright_sql:squery(Conn, "CREATE TABLE IF NOT EXISTS bright_schema_migrations (version bigint PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())") of
                    {ok, _, _} -> apply_files(Conn, Files);
                    {error, Reason} -> {error, Reason};
                    Other -> {error, {unexpected_schema_result, Other}}
                end
            after bright_sql:equery(Conn, "SELECT pg_advisory_unlock($1)", [?LOCK_ID]) end;
        {error, Reason} -> {error, Reason};
        Other -> {error, {lock_failed, Other}}
    end.

migration_files(Conn) ->
    Priv = code:priv_dir(bright_platform),
    Directory=case bright_sql:sqlite(Conn) of true->"sqlite_migrations";false->"migrations" end,
    sort_migration_files(filelib:wildcard(filename:join([Priv, Directory, "*.sql"]))).

apply_sqlite_migrations(Conn,Files)->
    case bright_sql:with_transaction(Conn,fun(C)->
        {ok,_,_}=bright_sql:squery(C,"CREATE TABLE IF NOT EXISTS bright_schema_migrations (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')) )"),
        lists:foreach(fun(Path)->
            Version=list_to_integer(filename:basename(Path,".sql")),
            case bright_sql:equery(C,"SELECT version FROM bright_schema_migrations WHERE version=$1",[Version]) of
                {ok,_,[_]}->ok;
                {ok,_,[]}->
                    {ok,Sql}=file:read_file(Path),
                    {ok,_,_}=bright_sql:squery(C,Sql),
                    {ok,1}=bright_sql:equery(C,"INSERT INTO bright_schema_migrations(version) VALUES($1)",[Version])
            end
        end,Files),ok
    end) of
        ok->ok;
        {rollback,_}->{error,sqlite_migration_failed}
    end.

%% Version order is numeric: 2.sql must run before 10.sql.
%% Reject ambiguous and malformed filenames before running any migration.
sort_migration_files(Files) ->
    Parsed = [migration_version(Path) || Path <- Files],
    case lists:all(fun({ok, _}) -> true; (_) -> false end, Parsed) of
        false -> {error, invalid_migration_filename};
        true ->
            Versions = [Version || {ok, Version} <- Parsed],
            case length(Versions) =:= length(lists:usort(Versions)) of
                false -> {error, duplicate_migration_version};
                true ->
                    [Path || {_, Path} <- lists:keysort(1, lists:zip(Versions, Files))]
            end
    end.

migration_version(Path) ->
    Base = filename:basename(Path, ".sql"),
    case string:to_integer(Base) of
        {Version, ""} when Version > 0 -> {ok, Version};
        _ -> {error, invalid_migration_filename}
    end.

apply_files(_Conn, []) -> ok;
apply_files(Conn, [Path | Rest]) ->
    Base = filename:basename(Path, ".sql"),
    case string:to_integer(Base) of
        {Version, ""} ->
            case bright_sql:equery(Conn, "SELECT version FROM bright_schema_migrations WHERE version = $1", [Version]) of
                {ok, _, [_ | _]} -> apply_files(Conn, Rest);
                {ok, _, []} ->
                    case file:read_file(Path) of
                        {ok, Sql} ->
                            case bright_sql:squery(Conn, "BEGIN") of
                                {ok, _, _} ->
                                    case bright_sql:squery(Conn, Sql) of
                                        {ok, _, _} ->
                                            case bright_sql:equery(Conn, "INSERT INTO bright_schema_migrations(version) VALUES ($1)", [Version]) of
                                                {ok, 1} ->
                                                    case bright_sql:squery(Conn, "COMMIT") of
                                                        {ok, _, _} -> apply_files(Conn, Rest);
                                                        Other -> {error, {commit_failed, Other}}
                                                    end;
                                                Other -> rollback(Conn, {record_failed, Other})
                                            end;
                                        Other -> rollback(Conn, {migration_failed, Version, Other})
                                    end;
                                Other -> {error, {begin_failed, Other}}
                            end;
                        Error -> Error
                    end;
                Other -> {error, {version_lookup_failed, Other}}
            end;
        _ -> {error, {invalid_migration_filename, Base}}
    end.

rollback(Conn, Reason) ->
    _ = bright_sql:squery(Conn, "ROLLBACK"),
    {error, Reason}.
