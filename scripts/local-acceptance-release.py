#!/usr/bin/env python3
"""Start this project's owned container against a new disposable test database."""
import pathlib,subprocess,time,urllib.request
root=pathlib.Path(__file__).resolve().parents[1];release='_build/prod/rel/bright_studio/bin/bright_studio';container='bright-sqlite-dev'
for path in ['bin/llama-cli','bin/whisper-cli','models/assistant.gguf','models/whisper-tiny.en.bin']:
 if not (root/'erlang/_build/native-runtime'/path).is_file():raise RuntimeError('Run cloud-native-models-setup.sh before full acceptance')
subprocess.run(['docker','exec','-e','REBAR_CACHE_DIR=/app/_build/cache',container,'rebar3','as','prod','release'],check=True)
if subprocess.run(['docker','exec',container,release,'ping'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0:
 subprocess.run(['docker','exec',container,release,'stop'],check=True);time.sleep(.5)
db='sqlite:/app/_build/acceptance-'+str(time.time_ns())+'.sqlite';(root/'erlang/_build/latest-acceptance-database.txt').write_text(db)
subprocess.run(['docker','exec','-e','DATABASE_URL='+db,'-e','BRIGHT_ACCEPTANCE_SEED=true',container,'escript','scripts/seed_acceptance.escript'],check=True)
args=['docker','exec','-d','-e','DATABASE_URL='+db,'-e','BRIGHT_ORIGIN=http://127.0.0.1:10000','-e','BRIGHT_INSECURE_LOCAL_COOKIE=true']
for feature in ['HUB','LIBRARY','EVIDENCE','STUDY','FOCUS','WORKSPACE','DOCUMENTS','AI','AUDIO','OFFLINE','WEB_EXTRACTION']:args+=['-e','STUDIO_'+feature+'_ENABLED=true']
for name,value in {'BRIGHT_AI_EXECUTABLE':'/app/_build/native-runtime/bin/llama-cli','BRIGHT_AI_MODEL_PATH':'/app/_build/native-runtime/models/assistant.gguf','BRIGHT_WHISPER_EXECUTABLE':'/app/_build/native-runtime/bin/whisper-cli','BRIGHT_WHISPER_MODEL_PATH':'/app/_build/native-runtime/models/whisper-tiny.en.bin'}.items():args+=['-e',name+'='+value]
subprocess.run(args+[container,'sh','-c',release+' foreground > /tmp/bright-release.log 2>&1'],check=True)
for attempt in range(80):
 try:
  with urllib.request.urlopen('http://127.0.0.1:10000/readyz',timeout=2) as r:
   if r.status==200:break
 except Exception:time.sleep(.25)
else:raise RuntimeError('Acceptance release did not become ready')
print('Full-feature isolated acceptance release ready')
