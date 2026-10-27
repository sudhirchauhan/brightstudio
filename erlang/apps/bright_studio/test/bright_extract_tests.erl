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

formatted_epub_test()->
 {ok,[First,Second]}=bright_extract:book(bright_m2_fixtures:epub()),
 ?assertNotEqual(nomatch,binary:match(maps:get(text,First),<<"First chapter">>)),
 ?assertNotEqual(nomatch,binary:match(maps:get(text,Second),<<"Second chapter">>)),
 Nodes=jsx:encode(maps:get(nodes,First)),
 ?assertNotEqual(nomatch,binary:match(Nodes,<<"h1">>)),
 ?assertEqual(nomatch,binary:match(Nodes,<<"hidden script">>)),
 ?assertEqual({error,invalid_document},bright_extract:book(bright_m2_fixtures:unsafe_epub())),
 ?assertEqual(<<"EPUB/Images/cover.png">>,bright_epub_view:resolve(<<"../Images/cover.png">>,<<"EPUB/Text/chapter.xhtml">>)),
 ?assertError(_,bright_epub_view:resolve(<<"../../outside">>,<<"EPUB/book.opf">>)),
 ?assertError(_,bright_epub_view:resolve(<<"https://example.test/image">>,<<"EPUB/book.opf">>)).
scanned_pdf_test_()->{timeout,150,fun()->
 Dir=filename:join([filename:dirname(?FILE),"fixtures"]),
 lists:foreach(fun(Name)->
  {ok,B}=file:read_file(filename:join(Dir,Name)),{ok,Text}=bright_extract:run(<<"application/pdf">>,B),
  ?assertNotEqual(nomatch,binary:match(Text,<<"Bright Studio OCR preserves useful ideas">>)),
  case Name of "mixed.pdf"->?assertNotEqual(nomatch,binary:match(Text,<<"Embedded text stays readable">>));_->ok end
 end,["scanned.pdf","mixed.pdf"])
 end}.
