#!/usr/bin/env python3
"""Compare a live disposable SQLite database with its independent backup copy."""
import argparse,hashlib,pathlib,sqlite3,subprocess,time,json
p=argparse.ArgumentParser();p.add_argument('--database',required=True);a=p.parse_args();root=pathlib.Path(__file__).resolve().parents[1]
if not a.database.startswith('sqlite:/app/_build/acceptance-'):raise RuntimeError('Drills must use an explicit disposable acceptance database')
source=root/'erlang'/a.database.removeprefix('sqlite:/app/');target=root/'erlang/_build'/('restore-drill-'+str(time.time_ns())+'.sqlite');remote='/app/'+str(target.relative_to(root/'erlang'))
subprocess.run(['docker','exec','-e','DATABASE_URL='+a.database,'bright-sqlite-dev','escript','scripts/sqlite-backup.escript',remote],check=True)
with sqlite3.connect(source) as original,sqlite3.connect(target) as copy:
 tables=[r[0] for r in original.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")];counts={}
 for table in tables:
  if not table.replace('_','').isalnum():raise RuntimeError('Unexpected table identifier')
  # Full row comparison exercises blob originals, citations, versions and receipt bytes.
  left=original.execute('SELECT * FROM '+table).fetchall();right=copy.execute('SELECT * FROM '+table).fetchall()
  digest=lambda rows:sorted(hashlib.sha256(repr(row).encode()).digest() for row in rows)
  if digest(left)!=digest(right):raise RuntimeError('Snapshot changed during drill; stop test mutations and repeat against a new copy')
  counts[table]=len(left)
 assert copy.execute('PRAGMA integrity_check').fetchone()[0]=='ok';assert copy.execute('PRAGMA foreign_key_check').fetchall()==[]
print(json.dumps({'restored_tables':len(tables),'total_rows':sum(counts.values()),'source_preserved':True,'backup_mode':oct(target.stat().st_mode&0o777)}))
