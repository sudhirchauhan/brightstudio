-module(bright_source_tests).
-include_lib("eunit/include/eunit.hrl").
validation_test() ->
    Base = #{<<"title">>=><<" A source ">>,<<"project_id">>=><<"11111111-1111-4111-8111-111111111111">>},
    ?assertMatch({ok,#{title := <<"A source">>}},bright_source:validate(Base)),
    lists:foreach(fun(M) -> ?assertEqual({error,invalid_input},bright_source:validate(M)) end,
      [Base#{<<"title">>=><<"  ">>},Base#{<<"url">>=><<"javascript:alert(1)">>},Base#{<<"kind">>=><<"pdf">>},Base#{<<"project_id">>=><<"invalid">>},Base#{<<"title">>=>123},Base#{<<"title">>=><<255>>},Base#{<<"title">>=><<"nul",0>>}]).
