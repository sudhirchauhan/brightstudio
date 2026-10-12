-module(bright_login_limit_tests).
-include_lib("eunit/include/eunit.hrl").
password_limit_is_scoped_to_account_test()->
    Own=whereis(bright_login_limit)=:=undefined,
    case Own of true->{ok,_}=bright_login_limit:start_link();false->ok end,
    try
        A=integer_to_binary(erlang:unique_integer([positive])),B=integer_to_binary(erlang:unique_integer([positive])),
        lists:foreach(fun(_)->?assert(bright_login_limit:allow_password(A)) end,lists:seq(1,10)),
        ?assertNot(bright_login_limit:allow_password(A)),?assert(bright_login_limit:allow_password(B)),
        ?assert(bright_login_limit:allow({{127,0,0,99},10000}))
    after case Own of true->gen_server:stop(bright_login_limit);false->ok end end.
