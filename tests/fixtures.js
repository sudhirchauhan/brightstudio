const zlib = require('node:zlib');
function crc32(buffer) { let crc=0xffffffff; for(const b of buffer){crc^=b;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}return (crc^0xffffffff)>>>0; }
function archive(files) {
  const locals=[], centrals=[]; let offset=0;
  for(const [name,contents] of files) {
    const filename=Buffer.from(name),data=Buffer.from(contents),compressed=zlib.deflateRawSync(data),crc=crc32(data);
    const local=Buffer.alloc(30); local.writeUInt32LE(0x04034b50);local.writeUInt16LE(20,4);local.writeUInt16LE(8,8);local.writeUInt32LE(crc,14);local.writeUInt32LE(compressed.length,18);local.writeUInt32LE(data.length,22);local.writeUInt16LE(filename.length,26);
    locals.push(local,filename,compressed);
    const central=Buffer.alloc(46);central.writeUInt32LE(0x02014b50);central.writeUInt16LE(20,4);central.writeUInt16LE(20,6);central.writeUInt16LE(8,10);central.writeUInt32LE(crc,16);central.writeUInt32LE(compressed.length,20);central.writeUInt32LE(data.length,24);central.writeUInt16LE(filename.length,28);central.writeUInt32LE(offset,42);
    centrals.push(central,filename);offset+=local.length+filename.length+compressed.length;
  }
  const directory=Buffer.concat(centrals),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(files.length,8);end.writeUInt16LE(files.length,10);end.writeUInt32LE(directory.length,12);end.writeUInt32LE(offset,16);
  return Buffer.concat([...locals,directory,end]);
}
function epub() { return archive([
  ['mimetype','application/epub+zip'],['META-INF/container.xml',"<container><rootfile full-path='EPUB/book.opf'/></container>"],
  ['EPUB/book.opf',"<package><manifest><item id='ch' href='chapter.xhtml' media-type='application/xhtml+xml'/></manifest><spine><itemref idref='ch'/></spine></package>"],
  ['EPUB/chapter.xhtml','<html><body><h1>A private EPUB chapter</h1><p>Reading durable book content.</p><script>never run this</script></body></html>']
]); }
function pdf() {
  const stream='BT /F1 12 Tf 40 700 Td (A private PDF reading page) Tj ET';
  const objects=['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R] /Count 1 >>','<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>','<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',`<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}\nendstream`];
  let document='%PDF-1.4\n';const offsets=[]; objects.forEach((object,index)=>{offsets.push(Buffer.byteLength(document));document+=`${index+1} 0 obj\n${object}\nendobj\n`;});
  const start=Buffer.byteLength(document);document+='xref\n0 6\n0000000000 65535 f \n'+offsets.map(n=>`${String(n).padStart(10,'0')} 00000 n \n`).join('');document+=`trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${start}\n%%EOF\n`;return Buffer.from(document);
}
module.exports={epub,pdf,archive};
