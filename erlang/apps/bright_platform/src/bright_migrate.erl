-module(bright_migrate).
-export([run/0, run/1, apply_migrations/2]).
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
            try apply_migrations(Conn, migration_files())
            after epgsql:close(Conn) end;
        Error -> Error
    end.

apply_migrations(Conn, Files) ->
    case epgsql:equery(Conn, "SELECT pg_advisory_lock($1)", [?LOCK_ID]) of
        {ok, _, _} ->
            try
                case epgsql:squery(Conn, "CREATE TABLE IF NOT EXISTS bright_schema_migrations (version bigint PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())") of
                    {ok, _, _} -> apply_files(Conn, Files);
                    {error, Reason} -> {error, Reason};
                    Other -> {error, {unexpected_schema_result, Other}}
                end
            after epgsql:equery(Conn, "SELECT pg_advisory_unlock($1)", [?LOCK_ID]) end;
        {error, Reason} -> {error, Reason};
        Other -> {error, {lock_failed, Other}}
    end.

migration_files() ->
    Priv = code:priv_dir(bright_platform),
    lists:sort(filelib:wildcard(filename:join([Priv, "migrations", "*.sql"]))).

apply_files(_Conn, []) -> ok;
apply_files(Conn, [Path | Rest]) ->
    Base = filename:basename(Path, ".sql"),
    case string:to_integer(Base) of
        {Version, ""} ->
            case epgsql:equery(Conn, "SELECT version FROM bright_schema_migrations WHERE version = $1", [Version]) of
                {ok, _, [_ | _]} -> apply_files(Conn, Rest);
                {ok, _, []} ->
                    case file:read_file(Path) of
                        {ok, Sql} ->
                            case epgsql:squery(Conn, "BEGIN") of
                                {ok, _, _} ->
                                    case epgsql:squery(Conn, Sql) of
                                        {ok, _, _} ->
                                            case epgsql:equery(Conn, "INSERT INTO bright_schema_migrations(version) VALUES ($1)", [Version]) of
                                                {ok, 1} ->
                                                    case epgsql:squery(Conn, "COMMIT") of
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
    _ = epgsql:squery(Conn, "ROLLBACK"),
    {error, Reason}.
