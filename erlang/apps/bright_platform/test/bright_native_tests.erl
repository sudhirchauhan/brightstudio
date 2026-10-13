-module(bright_native_tests).
-include_lib("eunit/include/eunit.hrl").
environment_isolation_test()->case {os:find_executable("prlimit"),os:find_executable("printenv")} of {false,_}->ok;{_,false}->ok;{_,Exe}->Name="BRIGHT_NATIVE_TEST_SECRET",Old=os:getenv(Name),os:putenv(Name,"fixture-only-value"),try ?assertEqual({error,invalid_document},bright_native:run(Exe,[Name],#{memory=>67108864,cpu=>1,timeout=>2000,output=>4096})) after case Old of false->os:unsetenv(Name);_->os:putenv(Name,Old) end end end.
