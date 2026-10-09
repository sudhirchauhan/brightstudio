-module(bright_m2_fixtures).
-export([pdf/0,epub/0,unsafe_epub/0,archive/1]).
pdf()->
    Stream = <<"BT /F1 12 Tf 40 700 Td (Milestone PDF reading content) Tj ET">>,
    Objects=[<<"<< /Type /Catalog /Pages 2 0 R >>">>,
             <<"<< /Type /Pages /Kids [3 0 R] /Count 1 >>">>,
             <<"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>">>,
             <<"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>">>,
             iolist_to_binary(["<< /Length ",integer_to_list(byte_size(Stream))," >>\nstream\n",Stream,"\nendstream"])],
    Header= <<"%PDF-1.4\n">>,
    {Parts,Offsets,Length,_}=lists:foldl(fun(B,{Acc,Os,Size,I})->
        Object=iolist_to_binary([integer_to_list(I)," 0 obj\n",B,"\nendobj\n"]),
        {[Object|Acc],[Size|Os],Size+byte_size(Object),I+1}
    end,{[],[],byte_size(Header),1},Objects),
    Xref=[io_lib:format("~10..0B 00000 n ~n",[N]) || N<-lists:reverse(Offsets)],
    iolist_to_binary([Header,lists:reverse(Parts),"xref\n0 6\n0000000000 65535 f \n",Xref,
                     "trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n",integer_to_list(Length),"\n%%EOF\n"]).
epub()->archive([
    {"mimetype",<<"application/epub+zip">>},
    {"META-INF/container.xml",<<"<container><rootfiles><rootfile full-path='EPUB/book.opf'/></rootfiles></container>">>},
    {"EPUB/book.opf",<<"<package><manifest><item id='two' href='two.xhtml' media-type='application/xhtml+xml'/><item id='one' href='one.xhtml' media-type='application/xhtml+xml'/></manifest><spine><itemref idref='one'/><itemref idref='two'/></spine></package>">>},
    {"EPUB/one.xhtml",<<"<html><head><title>Not body text</title></head><body><h1>First chapter</h1><p>EPUB reading &amp; learning.</p><script>hidden script</script></body></html>">>},
    {"EPUB/two.xhtml",<<"<html><body><h1>Second chapter</h1><p>Durable reading.</p></body></html>">>}
]).
unsafe_epub()->archive([
    {"mimetype",<<"application/epub+zip">>},
    {"META-INF/container.xml",<<"<!DOCTYPE container [<!ENTITY steal SYSTEM 'file:///etc/passwd'>]><container><rootfile full-path='&steal;'/></container>">>}
]).
archive(Files)->{ok,{_,B}}=zip:create("fixture.epub",Files,[memory]),B.
