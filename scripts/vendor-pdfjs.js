// Reproduce browser assets from the exact integrity-locked dependency.
const fs=require('node:fs'),path=require('node:path');
const source=path.join(__dirname,'../node_modules/pdfjs-dist'),target=path.join(__dirname,'../erlang/apps/bright_web/priv/static/pdfjs');
if(JSON.parse(fs.readFileSync(path.join(source,'package.json'))).version!=='4.10.38')throw Error('Unexpected PDF.js version');
fs.mkdirSync(target,{recursive:true});
for(const name of ['build/pdf.mjs','build/pdf.worker.mjs','LICENSE'])fs.copyFileSync(path.join(source,name),path.join(target,path.basename(name)));
for(const name of ['standard_fonts','cmaps'])fs.cpSync(path.join(source,name),path.join(target,name),{recursive:true});
