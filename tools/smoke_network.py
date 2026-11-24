"""Two independent clients against the actual Go executable, with isolated saves."""
from pathlib import Path
import json, socket, subprocess, tempfile, time, urllib.request, urllib.error, sys

root=Path(__file__).resolve().parents[1]
exe=root/'build/aurora-server.exe'
with socket.socket() as sock:
    sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
url=f'http://127.0.0.1:{port}'
def command(payload,token=''):
    req=urllib.request.Request(url+'/api',json.dumps(payload).encode(),{'Content-Type':'application/json','Authorization':'Bearer '+token})
    with urllib.request.urlopen(req,timeout=5) as r:return json.load(r)
with tempfile.TemporaryDirectory(prefix='aurora-network-') as tmp:
    proc=subprocess.Popen([str(exe),'-listen',f'127.0.0.1:{port}','-data',str(Path(tmp)/'world.json')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    try:
        for _ in range(50):
            try:
                with urllib.request.urlopen(url+'/health',timeout=1) as r:assert json.load(r)['tick_rate']==20
                break
            except OSError:time.sleep(.1)
        a=command({'type':'register','name':'Rede A','starter':1});b=command({'type':'register','name':'Rede B','starter':7})
        ta,tb=a['token'],b['token'];assert ta!=tb
        command({'type':'travel','area':'vila'},ta);command({'type':'travel','area':'vila'},tb)
        snap=command({'type':'poll'},ta)
        assert any(p['id']==b['player']['id'] for p in snap['players'])
        before=snap['player']['pos']['x']
        command({'type':'input','move':{'x':1,'y':0},'aim':{'x':300,'y':200}},ta);time.sleep(.2)
        after=command({'type':'poll'},ta)['player']['pos']['x'];assert after>before and after-before<25
        try:command({'type':'poll'},'invalid');raise AssertionError('invalid token accepted')
        except urllib.error.HTTPError as e:assert e.code==401
        time.sleep(2.2)
        saved=json.loads((Path(tmp)/'world.json').read_text())
        assert len(saved['players'])==2 and len(saved['sessions'])==2
        print('PASS: dois clientes TCP, identidades independentes, presença, movimento autoritativo, autorização e save real.')
        if len(sys.argv)>1:
            result=subprocess.run([sys.argv[1],'--headless','--path',str(root/'client'),'--script','qa_network.gd','--',url],capture_output=True,text=True,timeout=45,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            print(result.stdout.strip())
            if result.returncode or 'SCRIPT ERROR' in result.stderr or 'ERROR:' in result.stderr:
                raise RuntimeError(result.stderr)
    finally:
        proc.terminate();proc.wait(timeout=10)
