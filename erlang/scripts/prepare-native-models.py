#!/usr/bin/env python3
"""Build pinned native tools and fetch SHA-256 verified public model artifacts."""
import argparse,hashlib,json,pathlib,shutil,ssl,subprocess,urllib.request,urllib.parse,os
parser=argparse.ArgumentParser();parser.add_argument('--prefix',required=True);parser.add_argument('--source-cache');parser.add_argument('--model-cache');parser.add_argument('--docker-container');parser.add_argument('--ca-file');args=parser.parse_args()
root=pathlib.Path(args.prefix).resolve();root.mkdir(parents=True,exist_ok=True);lock=json.loads(pathlib.Path(__file__).with_name('native-models.lock.json').read_text());ctx=ssl.create_default_context(cafile=args.ca_file) if args.ca_file else ssl.create_default_context();binary_dir=root/'bin';model_dir=root/'models';binary_dir.mkdir(exist_ok=True);model_dir.mkdir(exist_ok=True)
def run(argv):subprocess.run(argv,check=True)
def digest(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for chunk in iter(lambda:f.read(1048576),b''):h.update(chunk)
 return h.hexdigest()
def tool_command(argv):
 if not args.docker_container:return argv
 # Only the selected repository's Erlang directory is mounted at /app.
 project=pathlib.Path(__file__).resolve().parents[1];translated=[str(a).replace(str(project),'/app',1) if str(a).startswith(str(project)) else str(a) for a in argv]
 return ['docker','exec',args.docker_container,*translated]
for tool in lock['tools']:
 cache=pathlib.Path(args.source_cache).resolve() if args.source_cache else root/'sources';cache.mkdir(exist_ok=True)
 source=cache/tool['name'];git=['git']+(['-c','http.sslCAInfo='+args.ca_file] if args.ca_file else [])
 if source.exists():
  actual=subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()
  if actual!=tool['commit']:raise RuntimeError('Existing native source has another revision; preserve it and use a fresh cache directory.')
 else:
  source.mkdir();run(git+['-C',str(source),'init','-q']);run(git+['-C',str(source),'remote','add','origin','https://github.com/'+tool['repository']+'.git']);run(git+['-C',str(source),'fetch','--depth','1','origin',tool['commit']]);run(git+['-C',str(source),'checkout','--detach',tool['commit']])
 build=source/'build';target='llama-cli' if tool['name']=='llama.cpp' else 'whisper-cli';opts=['-DCMAKE_BUILD_TYPE=Release','-DBUILD_SHARED_LIBS=OFF','-DGGML_NATIVE=OFF'];opts+=['-DLLAMA_CURL=OFF','-DLLAMA_BUILD_TESTS=OFF'] if target=='llama-cli' else ['-DWHISPER_BUILD_TESTS=OFF']
 run(tool_command(['cmake','-S',str(source),'-B',str(build),*opts]));run(tool_command(['cmake','--build',str(build),'--target',target,'-j','3']));shutil.copy2(build/'bin'/target,binary_dir/target)
for model in lock['models']:
 dest=model_dir/model['file'];expected=model['sha256']
 if dest.exists() and digest(dest)==expected:continue
 cached=pathlib.Path(args.model_cache)/model['file'] if args.model_cache else None
 if cached and cached.exists() and digest(cached)==expected:shutil.copy2(cached,dest);continue
 url='https://huggingface.co/'+model['repo']+'/resolve/'+model['commit']+'/'+urllib.parse.quote(model['source_file']);temp=dest.with_suffix('.partial');h=hashlib.sha256();size=0
 with urllib.request.urlopen(url,context=ctx,timeout=60) as response,temp.open('wb') as output:
  while True:
   chunk=response.read(1048576)
   if not chunk:break
   size+=len(chunk)
   if size>536870912:raise RuntimeError('Unexpected model size')
   h.update(chunk);output.write(chunk)
 if h.hexdigest()!=expected:raise RuntimeError('Model SHA-256 mismatch; artifact was not installed')
 temp.replace(dest)
(root/'manifest.json').write_text(json.dumps(lock,indent=2)+'\n');print('Pinned native tools and verified local models ready')
