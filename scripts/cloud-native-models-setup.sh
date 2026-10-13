#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Public tools/models only. Existing model/source caches are verified and preserved.
python3 - <<'PY'
import os,socket,subprocess,urllib.parse
url=os.environ.get('HTTPS_PROXY',os.environ.get('https_proxy'));prefix=['docker','exec','--user','0','bright-sqlite-dev','apt-get']
if url:
 u=urllib.parse.urlparse(url)
 if u.username or u.password:raise RuntimeError('Use the platform credential-free package proxy route')
 subprocess.run(['docker','exec','--user','0','-i','bright-sqlite-dev','sh','-c','cat >> /etc/hosts'],input=(socket.gethostbyname(u.hostname)+' '+u.hostname+'\n').encode(),check=True)
 proxy=urllib.parse.urlunsplit(('http',u.netloc,'','',''));prefix+=['-o','Acquire::http::Proxy='+proxy,'-o','Acquire::https::Proxy='+proxy]
subprocess.run(prefix+['update','-qq'],check=True)
subprocess.run(prefix+['install','-y','--no-install-recommends','cmake','tesseract-ocr','ffmpeg'],check=True)
PY
python3 erlang/scripts/prepare-native-models.py --prefix erlang/_build/native-runtime \
  --source-cache erlang/_build/native-sources --model-cache erlang/_build/models --docker-container bright-sqlite-dev
