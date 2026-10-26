"""Run the actual Caddy binary and relay on ephemeral loopback fixture ports only."""
import http.client
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time


def free_port():
    with socket.socket() as s:
        s.bind(('127.0.0.1',0))
        return s.getsockname()[1]


def run():
    root=Path(__file__).resolve().parent
    backend,proxy=free_port(),free_port()
    while proxy==backend:proxy=free_port()
    with tempfile.TemporaryDirectory(prefix='lfg-proxy-fixture-') as tmp:
        state=Path(tmp)
        (state/'fixture_app.py').write_text("import sys\nsys.path.insert(0,"+repr(str(root))+")\nfrom main import app, events\nfrom fastapi import Request\nfrom security import client_ip\n@app.get('/lfg.html')\nasync def board(): return {'board':True}\n@app.get('/fixture/peer')\nasync def peer(request:Request):\n return {'ip':client_ip(request),'headers':{k:request.headers.get(k) for k in ['forwarded','x-real-ip','cf-connecting-ip']},'streams':len(events.clients)}\n")
        snippet=(root/'caddy-farever-lfg.snippet').read_text()
        # Exercise the exact production proxy header policy against a fixture-only route.
        import re
        snippet=re.sub(r'(?m)^        remote_ip .*$', '        remote_ip 127.0.0.3/32', snippet)
        snippet=snippet.replace('handle /api/lfg/*', 'handle /*').replace('127.0.0.1:8000','127.0.0.1:'+str(backend))
        conf=state/'Caddyfile'
        conf.write_text('{\n admin off\n auto_https off\n}\nhttp://127.0.0.1:'+str(proxy)+' {\n bind 127.0.0.1\n'+snippet+'\n}\n')
        env=dict(os.environ,LFG_MODERATION_DB=str(state/'moderation.sqlite'),LFG_RESTORE_FILE=str(state/'none.json'),
                 LFG_TEST_ENTRY_FILE=str(state/'no-test-entry.json'),LFG_ADMIN_KEY='a'*64,LFG_SESSIONS_MINUTE_IP='2',LFG_LISTINGS_READS_IP='2')
        env.pop('LFG_HMAC_SECRET',None)
        log=(state/'process.log').open('w+')
        validation=subprocess.run(['caddy','validate','--config',str(conf),'--adapter','caddyfile'],capture_output=True,text=True)
        assert validation.returncode==0,validation.stderr
        workers=[]
        def request(path,body=None,token=None,source='127.0.0.2',headers=None,port=None):
            c=http.client.HTTPConnection('127.0.0.1',port or proxy,timeout=4,source_address=(source,0))
            h={'Content-Type':'application/json',**(headers or {})}
            if token:h['Authorization']='Bearer '+token
            c.request('POST' if body is not None else 'GET',path,json.dumps(body) if body is not None else None,h)
            r=c.getresponse();status=r.status;raw=r.read();response_headers={k.lower():v for k,v in r.getheaders()};c.close()
            try:value=json.loads(raw)
            except ValueError:value={}
            return status,value,response_headers
        def event(token,source):
            c=http.client.HTTPConnection('127.0.0.1',proxy,timeout=4,source_address=(source,0))
            c.request('GET','/api/lfg/events',headers={'Authorization':'Bearer '+token})
            r=c.getresponse();assert r.status==200,(r.status,r.read())
            return c,r
        def next_event(r):
            kind=''
            while True:
                line=r.readline().decode().strip()
                if line.startswith('event:'):kind=line.split(':',1)[1].strip()
                if not line and kind:return kind
        try:
            workers.append(subprocess.Popen([sys.executable,'-m','uvicorn','fixture_app:app','--app-dir',str(state),'--host','127.0.0.1','--port',str(backend),'--proxy-headers','--forwarded-allow-ips=127.0.0.1,::1','--no-access-log'],cwd=root,env=env,stdout=log,stderr=log))
            workers.append(subprocess.Popen(['caddy','run','--config',str(conf),'--adapter','caddyfile'],env=dict(env,XDG_CONFIG_HOME=str(state/'config'),XDG_DATA_HOME=str(state/'data')),stdout=log,stderr=log))
            for _ in range(100):
                try:
                    if request('/fixture/peer')[0]==200:break
                except (OSError,http.client.HTTPException):pass
                time.sleep(.05)
            else:raise AssertionError('Fixture startup failed')
            forged={'X-Forwarded-For':'203.0.113.44','Forwarded':'for=203.0.113.45','X-Real-IP':'203.0.113.46','CF-Connecting-IP':'203.0.113.47'}
            _,peer,_=request('/fixture/peer',headers=forged)
            assert peer['ip']=='127.0.0.2' and all(v is None for v in peer['headers'].values()),peer
            assert request('/fixture/peer',source='127.0.0.3')[1]['ip']=='127.0.0.3'
            assert request('/fixture/peer',headers=forged,port=backend)[1]['ip']=='127.0.0.2'
            # Only the declared fixture proxy source may supply CF's visitor address.
            trusted=dict(forged,**{'CF-Connecting-IP':'198.51.100.12'})
            assert request('/fixture/peer',source='127.0.0.3',headers=trusted)[1]['ip']=='198.51.100.12'
            trusted['CF-Connecting-IP']='198.51.100.13'
            assert request('/fixture/peer',source='127.0.0.3',headers=trusted)[1]['ip']=='198.51.100.13'
            trusted['CF-Connecting-IP']='2001:db8:1::1'
            assert request('/fixture/peer',source='127.0.0.3',headers=trusted)[1]['ip']=='2001:db8:1::/64'
            trusted['CF-Connecting-IP']='2001:db8:1::99'
            assert request('/fixture/peer',source='127.0.0.3',headers=trusted)[1]['ip']=='2001:db8:1::/64'
            trusted['CF-Connecting-IP']='198.51.100.14'
            for i in range(2):assert request('/api/lfg/session',{'host':'CDN'+str(i),'steam_id':'7'},source='127.0.0.3',headers=trusted)[0]==200
            trusted['X-Forwarded-For']='192.0.2.99'
            assert request('/api/lfg/session',{'host':'CDN flood','steam_id':'7'},source='127.0.0.3',headers=trusted)[0]==429
            trusted['CF-Connecting-IP']='198.51.100.15'
            assert request('/api/lfg/session',{'host':'Another CDN client','steam_id':'8'},source='127.0.0.3',headers=trusted)[0]==200
            assert request('/lfg')[1]=={'board':True} and request('/lfg/')[1]=={'board':True}
            legacy=request('/lfg-board');assert legacy[0]==308 and legacy[2].get('location')=='/lfg',legacy
            a=request('/api/lfg/session',{'host':'Aria','steam_id':'123456'})[1]
            assert 'token' in a
            assert request('/api/lfg/session',{'host':'Alt','steam_id':'999'})[0]==200
            limited=request('/api/lfg/session',{'host':'Flood','steam_id':'999'},headers=forged)
            assert limited[0]==429 and int(limited[2].get('retry-after','0'))>0
            b=request('/api/lfg/session',{'host':'Other','steam_id':'42'},source='127.0.0.3')[1]
            assert 'token' in b
            for _ in range(2):assert request('/api/lfg/listings',headers=forged)[0]==200
            assert request('/api/lfg/listings',headers={'X-Forwarded-For':'198.51.100.88'})[0]==429
            assert request('/api/lfg/listings',source='127.0.0.3')[0]==200
            ca,ra=event(a['token'],'127.0.0.2');cb,rb=event(b['token'],'127.0.0.3')
            assert next_event(ra)==next_event(rb)=='sync'
            stamp=time.monotonic()
            assert request('/api/lfg/post',{'host':'Aria','steam_id':'123456','activity':"Crabgantua's Gorge",'undefined':3},a['token'])[0]==201
            assert next_event(ra)==next_event(rb)=='listings'
            assert request('/api/lfg/chat',{'recipient_id':b['session_id'],'message':'Private fixture hello'},a['token'])[0]==201
            assert next_event(rb)=='chat' and time.monotonic()-stamp<3
            inbox=request('/api/lfg/chat',token=b['token'],source='127.0.0.3')
            assert len(inbox[1]['messages'])==1
            ca.sock.settimeout(.2)
            try:next_event(ra);raise AssertionError('Private event broadcast to another session')
            except (TimeoutError,OSError):pass
            ra.close();rb.close();ca.close();cb.close()
            for _ in range(30):
                if request('/fixture/peer',source='127.0.0.3')[1]['streams']==0:break
                time.sleep(.1)
            else:raise AssertionError('Disconnected event queue leaked')
            c=http.client.HTTPConnection('127.0.0.1',proxy,timeout=4)
            c.request('POST','/api/lfg/session',b'x'*8193,{'Content-Type':'application/json'})
            r=c.getresponse();assert r.status==413;r.read();c.close()
            print(json.dumps({'proxy_headers':'pass','verified_CDN_chain':'pass','distinct_clients':'pass','untrusted_peer':'pass','session_churn':'pass','SSE_private_and_immediate':'pass','SSE_disconnect_cleanup':'pass','body_limit':'pass','board_shortcut':'pass','production_writes':0}))
        except Exception:
            log.flush();log.seek(0);print(log.read()[-5000:],file=sys.stderr)
            raise
        finally:
            for worker in workers:worker.terminate()
            for worker in workers:
                try:worker.wait(timeout=5)
                except subprocess.TimeoutExpired:worker.kill();worker.wait()
            log.close()


if __name__=='__main__':run()
