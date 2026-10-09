-module(bright_extract_tests).
-include_lib("eunit/include/eunit.hrl").
text_test()->
    ?assertEqual({ok,<<"A reading\ntext">>},bright_extract:run(<<"text/plain">>,<<"A reading\ntext">>)),
    ?assertEqual({error,invalid_document},bright_extract:run(<<"text/plain">>,<<255>>)),
    ?assertEqual({error,invalid_document},bright_extract:run(<<"text/plain">>,<<"nul",0>>)),
    ?assertEqual({error,no_text},bright_extract:run(<<"text/plain">>,<<" \n">>)),
    ?assertEqual({error,resource_limit},bright_extract:run(<<"text/plain">>,binary:copy(<<"a">>,2097153))).
pdf_test()->
    {ok,Text}=bright_extract:run(<<"application/pdf">>,bright_m2_fixtures:pdf()),
    ?assertNotEqual(nomatch,binary:match(Text,<<"Milestone PDF reading content">>)),
    ?assertEqual({error,invalid_document},bright_extract:run(<<"application/pdf">>,<<"%PDF-not-a-document">>)).
epub_test()->
    {ok,Text}=bright_extract:run(<<"application/epub+zip">>,bright_m2_fixtures:epub()),
    {First,_}=binary:match(Text,<<"First chapter">>),{Second,_}=binary:match(Text,<<"Second chapter">>),
    ?assert(First<Second),
    ?assertNotEqual(nomatch,binary:match(Text,<<"reading & learning">>)),
    ?assertEqual(nomatch,binary:match(Text,<<"hidden script">>)).
unsafe_archive_test()->
    ?assertEqual({error,invalid_document},bright_extract:run(<<"application/epub+zip">>,bright_m2_fixtures:unsafe_epub())),
    ?assertEqual({error,invalid_document},bright_extract:run(<<"application/epub+zip">>,bright_m2_fixtures:archive([{"../escape",<<"unsafe">>}]))),
    Archive=bright_m2_fixtures:epub(),{Pos,_}=binary:match(Archive,<<"PK",1,2>>),
    <<Before:(Pos+24)/binary,_Size:32/little,After/binary>>=Archive,
    Bomb= <<Before/binary,1:32/little,After/binary>>,
    ?assertEqual({error,resource_limit},bright_extract:run(<<"application/epub+zip">>,Bomb)).
