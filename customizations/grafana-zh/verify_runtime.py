#!/usr/bin/env python3
"""Read-only end-to-end checks against a provisioned TeslaMate Grafana instance.

Only GET metadata/health and POST /api/ds/query are used. No Grafana configuration,
Dashboard, user, or PostgreSQL data is changed. Panel SQL is the provisioned SQL,
with dashboard variables expanded as Grafana would expand them in a request.

Example:
  python3 customizations/grafana-zh/verify_runtime.py --url "$GRAFANA_URL" --scenarios defaults,metric,imperial
  python3 customizations/grafana-zh/verify_runtime.py --url "$GRAFANA_URL" --car-id 1 --days 90
Authentication is optional; use --username NAME --password-env VARIABLE or
--token-env VARIABLE. Secret values are never included in the report.
"""
import argparse,base64,copy,datetime,hashlib,json,math,os,pathlib,re,sys,time
import urllib.error,urllib.parse,urllib.request

BASE=pathlib.Path(__file__).resolve().parent
REPO=BASE.parent.parent
CORE=('overview.json','drives.json','charges.json','temperatures.json',
      'internal/drive-details.json','internal/charge-details.json')
NOW=datetime.datetime.now(datetime.timezone.utc)

class CheckError(Exception):pass

class Grafana:
    def __init__(self,args):
        self.url=args.url.rstrip('/')
        if self.url.endswith('/dashboards'):self.url=self.url[:-len('/dashboards')]
        self.timeout=args.timeout;self.headers={'Accept':'application/json'}
        if args.token_env:
            token=os.environ.get(args.token_env)
            if not token:raise CheckError('Token environment variable is empty: '+args.token_env)
            self.headers['Authorization']='Bearer '+token
        elif args.username:
            password=os.environ.get(args.password_env or '', '')
            if not password:raise CheckError('Password environment variable is empty')
            self.headers['Authorization']='Basic '+base64.b64encode((args.username+':'+password).encode()).decode()
    def request(self,path,data=None):
        assert path.startswith(('/api/health','/api/search','/api/dashboards/uid/','/api/datasources/uid/','/api/ds/query'))
        if data is not None:assert path=='/api/ds/query'
        headers=dict(self.headers)
        if data is not None:headers['Content-Type']='application/json'
        req=urllib.request.Request(self.url+path,data=None if data is None else json.dumps(data).encode(),headers=headers)
        try:
            with urllib.request.urlopen(req,timeout=self.timeout) as response:return json.load(response)
        except urllib.error.HTTPError as e:
            # A failed ds/query response can still carry structured datasource errors.
            body=e.read().decode(errors='replace')
            try:payload=json.loads(body)
            except ValueError:payload={'message':body[:500]}
            if data is not None and payload.get('results'):return payload
            raise CheckError(f'HTTP {e.code} {path}: {payload.get("message", "request failed")}')
        except (urllib.error.URLError,TimeoutError) as e:raise CheckError(f'{path}: {e}')
    def query(self,sql,start_ms,end_ms,interval_ms,ref='A',target=None):
        q=copy.deepcopy(target or {})
        q.update({'refId':ref,'datasource':{'type':'grafana-postgresql-datasource','uid':'TeslaMate'},
                  'rawSql':sql,'format':q.get('format','table'),'rawQuery':True,'editorMode':'code',
                  'intervalMs':interval_ms,'maxDataPoints':1500})
        payload=self.request('/api/ds/query',{'from':str(start_ms),'to':str(end_ms),'queries':[q]})
        result=payload.get('results',{}).get(ref)
        if result is None:raise CheckError('Query result is missing '+ref)
        if result.get('error') or result.get('status',200)>=400:raise CheckError(str(result.get('error') or result.get('status')))
        rows=[];frames=result.get('frames',[])
        for frame in frames:
            fields=frame.get('schema',{}).get('fields',[]);columns=frame.get('data',{}).get('values',[])
            count=max((len(v) for v in columns),default=0)
            for i in range(count):
                rows.append({f.get('name',str(n)):columns[n][i] if n<len(columns) and i<len(columns[n]) else None for n,f in enumerate(fields)})
        return {'rows':rows,'frames':len(frames),'field_names':list(dict.fromkeys(k for row in rows for k in row))}

def panels(dashboard):
    result=[]
    def rec(items):
        for panel in items:result.append(panel);rec(panel.get('panels',[]))
    rec(dashboard.get('panels',[]));return result

def literal(value):
    if value is None:return 'NULL'
    return "'"+str(value).replace("'","''")+"'"

def text_value(value):
    return '' if value is None else str(value).replace("'","''")

def format_value(value,fmt,variable):
    values=value if isinstance(value,list) else [value]
    if fmt=='pipe':return '|'.join(text_value(v) for v in values)
    if fmt in ('sqlstring','singlequote'):return ','.join(literal(v) for v in values)
    if fmt in ('csv','raw'):return ','.join(str(v) for v in values)
    if fmt=='text':return variable.get('text',str(value))
    if isinstance(value,list):
        # PostgreSQL Grafana variables use SQL quoting for multi-value variables.
        return ','.join(str(v) if isinstance(v,(int,float)) or re.fullmatch(r'-?\d+(?:\.\d+)?',str(v)) else literal(v) for v in values)
    return text_value(value)

TOKEN=re.compile(r'\$\{([A-Za-z_][A-Za-z_0-9]*)(?::([^}]+))?\}|\$([A-Za-z_][A-Za-z_0-9]*)')

def interpolate(sql,values,start_ms,end_ms,interval_ms):
    # Grafana itself expands PostgreSQL $__time... macros. Only built-in template values
    # and dashboard variables are expanded here, preserving the original query logic.
    builtin={'__from':start_ms,'__to':end_ms,'__timezone':'UTC','__interval_ms':interval_ms,
             '__interval':str(max(1,interval_ms//1000))+'s'}
    def repl(match):
        name=match.group(1) or match.group(3);fmt=match.group(2)
        if name in ('__from','__to') and fmt=='date:seconds':return str(builtin[name]//1000)
        if name=='__interval':return literal(builtin[name])
        if name in builtin:return str(builtin[name])
        if name.startswith('__'):return match.group(0)
        if name not in values:raise CheckError('Unresolved dashboard variable '+name)
        return format_value(values[name]['value'],fmt,values[name])
    return TOKEN.sub(repl,sql)

def query_scalar(rows):
    if not rows:raise CheckError('Variable query returned no rows')
    row=rows[0]
    if '__value' in row:return row['__value'],row.get('__text',str(row['__value']))
    if not row:raise CheckError('Variable query returned no fields')
    val=next(iter(row.values()));return val,str(val) if val is not None else ''

def custom_options(query):
    result=[]
    for entry in query.split(','):
        pieces=entry.split(' : ',1);label=pieces[0].strip();value=pieces[-1].strip()
        result.append((value,label))
    return result

def variable_defaults(grafana,dashboard,overrides,start_ms,end_ms,interval_ms):
    values={name:{'value':val,'text':str(val)} for name,val in overrides.items()}
    remaining=[];executed=[]
    for variable in dashboard.get('templating',{}).get('list',[]):
        name=variable['name']
        if name in values:continue
        kind=variable['type'];current=variable.get('current',{})
        if kind=='query':remaining.append(variable);continue
        if kind=='custom':
            options=custom_options(variable.get('query',''))
            if variable.get('includeAll') and variable.get('multi'):
                val=variable.get('allValue') if variable.get('allValue') is not None else [v for v,l in options]
                text='全部'
            else:
                val=current.get('value')
                if val is None:val=options[0][0] if options else ''
                text=dict(options).get(val,current.get('text',str(val)))
        elif kind=='interval':val=current.get('value') or variable.get('query','1h').split(',')[0];text=val
        elif kind in ('textbox','constant'):
            val=current.get('value',variable.get('query',''));text=current.get('text',str(val))
        else:val=current.get('value','');text=current.get('text',str(val))
        values[name]={'value':val,'text':text}
    for _ in range(len(remaining)+1):
        deferred=[];progress=False
        for variable in remaining:
            name=variable['name'];query=variable.get('query',variable.get('definition',''))
            if isinstance(query,dict):query=query.get('query','')
            try:sql=interpolate(query,values,start_ms,end_ms,interval_ms)
            except CheckError as e:
                if 'Unresolved dashboard variable' in str(e):deferred.append(variable);continue
                raise
            result=grafana.query(sql,start_ms,end_ms,interval_ms)
            if variable.get('includeAll') and variable.get('allValue') is not None:
                val=variable['allValue'];text='全部'
            else:val,text=query_scalar(result['rows'])
            values[name]={'value':val,'text':text};executed.append(name);progress=True
        remaining=deferred
        if not remaining:break
        if not progress:raise CheckError('Unresolved variable dependency cycle: '+', '.join(v['name'] for v in remaining))
    return values,executed

def utc_ms(value):return int(value)

def write_report(path,report):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')

def run(args):
    grafana=Grafana(args);end_ms=int(NOW.timestamp()*1000);start_ms=end_ms-int(args.days*86400000)
    report={'started_at_UTC':NOW.isoformat(),'url':grafana.url,'read_only':True,'range_days':args.days,
            'checks':[],'failures':[],'warnings':[],'queries':[],'variables':[]}
    def fail(stage,error):report['failures'].append({'stage':stage,'error':str(error)});print('FAIL',stage,str(error),flush=True)
    def checkpoint():write_report(args.report,report)
    try:
        health=grafana.request('/api/health')
        if health.get('database')!='ok':raise CheckError('Grafana database health is not ok')
        report['checks'].append({'check':'Grafana health','status':'PASS','version':health.get('version')})
    except CheckError as e:fail('Grafana health',e);checkpoint();return report
    expected={j['uid']:(f,j) for f in sorted(args.dashboards.rglob('*.json')) for j in [json.loads(f.read_text())]}
    if not expected:fail('local dashboard inventory','No dashboard UIDs found in the configured directory')
    try:
        search=grafana.request('/api/search?type=dash-db&limit=1000')
        by_uid={entry['uid']:entry for entry in search}
    except CheckError as e:fail('Grafana dashboard search',e);by_uid={}
    remote={}
    for uid,(f,local) in expected.items():
        try:
            if uid not in by_uid:raise CheckError('Official UID absent from search results')
            response=grafana.request('/api/dashboards/uid/'+urllib.parse.quote(uid,safe=''))
            dashboard=response['dashboard']
            if dashboard['title']!=local['title']:raise CheckError('Chinese dashboard title does not match the generated title')
            if not re.search(r'[\u4e00-\u9fff]',dashboard['title']):raise CheckError('Title is not Chinese')
            # Every original PostgreSQL target must match the provisioned translation file.
            lp,rp=panels(local),panels(dashboard)
            a={(p['id'],t.get('refId')):t.get('rawSql') for p in lp for t in p.get('targets',[]) if t.get('rawSql')}
            b={(p['id'],t.get('refId')):t.get('rawSql') for p in rp for t in p.get('targets',[]) if t.get('rawSql')}
            if a!=b:raise CheckError('Provisioned SQL targets differ from the translated file')
            remote[str(f.relative_to(args.dashboards)).removeprefix('public/')]=dashboard
            report['checks'].append({'check':'Chinese provisioned dashboard','uid':uid,'title':dashboard['title'],'status':'PASS'})
        except (CheckError,KeyError) as e:fail('dashboard '+str(f.relative_to(args.dashboards)),e)
    try:
        health=grafana.request('/api/datasources/uid/TeslaMate/health')
        if health.get('status') not in ('OK','ok','success'):raise CheckError(health.get('message','Datasource health is not OK'))
        report['checks'].append({'check':'TeslaMate datasource health API','status':'PASS','message':health.get('message')})
    except CheckError as e:
        # Anonymous viewers can execute datasource queries even when the health route
        # requires elevated Grafana permissions. The SELECT probe is authoritative.
        report['warnings'].append({'check':'Datasource health API','message':str(e)})
    try:
        probe=grafana.query('SELECT 1 AS connection_ok',start_ms,end_ms,args.interval_ms)
        if not probe['rows'] or probe['rows'][0].get('connection_ok')!=1:raise CheckError('Database probe did not return 1')
        report['checks'].append({'check':'TeslaMate datasource SELECT probe','status':'PASS'})
        car=grafana.query('SELECT id AS car_id FROM cars ORDER BY display_priority ASC, name ASC, vin ASC LIMIT 1',start_ms,end_ms,args.interval_ms)
        car_id=args.car_id if args.car_id is not None else int(car['rows'][0]['car_id'])
        report['car_id']=car_id
    except (CheckError,IndexError,ValueError) as e:fail('TeslaMate database connection or vehicle discovery',e);checkpoint();return report
    details={}
    for name,table,kind in [('drive_id','drives','internal/drive-details.json'),('charging_process_id','charging_processes','internal/charge-details.json')]:
        sql=f'SELECT id, extract(epoch FROM start_date)*1000 AS start_ms, extract(epoch FROM end_date)*1000 AS end_ms FROM {table} WHERE car_id = {car_id} AND start_date IS NOT NULL AND end_date IS NOT NULL ORDER BY end_date DESC LIMIT 1'
        try:
            rows=grafana.query(sql,start_ms,end_ms,args.interval_ms)['rows']
            if rows:details[kind]={'name':name,'id':int(rows[0]['id']),'start_ms':utc_ms(rows[0]['start_ms']),'end_ms':utc_ms(rows[0]['end_ms'])}
            else:report['warnings'].append({'check':name+' discovery','message':'No completed record available; detail dashboard queries will be skipped'})
        except (CheckError,ValueError,TypeError) as e:fail(name+' discovery',e)
    report['selected_detail_records']=details
    selected=tuple(remote) if args.all_dashboards else CORE
    scenarios=[v.strip() for v in args.scenarios.split(',')]
    for scenario in scenarios:
        for filename in selected:
            if filename not in remote:continue
            dashboard=remote[filename];window_start,window_end=start_ms,end_ms
            override={'car_id':car_id}
            if filename in ('internal/drive-details.json','internal/charge-details.json'):
                if filename not in details:continue
                detail=details[filename];override[detail['name']]=detail['id']
                window_start=detail['start_ms']-1000;window_end=max(detail['end_ms']+1000,window_start+2000)
            if scenario=='metric':override.update({'length_unit':'km','temp_unit':'C','pressure_unit':'bar','alternative_length_unit':'m','speed_unit':'km/h'})
            elif scenario=='imperial':override.update({'length_unit':'mi','temp_unit':'F','pressure_unit':'psi','alternative_length_unit':'ft','speed_unit':'mph'})
            elif scenario!='defaults':fail('scenario',f'Unknown scenario: {scenario}');continue
            try:
                values,variable_queries=variable_defaults(grafana,dashboard,override,window_start,window_end,args.interval_ms)
                # Record units, filter choices and evaluated variable names, not URLs or arbitrary returned strings.
                report['variables'].append({'dashboard':filename,'scenario':scenario,'query_variables_evaluated':variable_queries,
                                           'safe_defaults':{name:value['value'] for name,value in values.items() if name in ('car_id','length_unit','temp_unit','pressure_unit','preferred_range','alternative_length_unit','drive_id','charging_process_id','min_dist','min_speed','min_duration_min','geofence','charge_type','efficiency')}})
            except CheckError as e:fail(filename+' '+scenario+' variable defaults',e);checkpoint();continue
            for panel in panels(dashboard):
                for target in panel.get('targets',[]):
                    if target.get('hide') or not target.get('rawSql'):continue
                    datasource=target.get('datasource',panel.get('datasource',{}))
                    if isinstance(datasource,dict) and datasource.get('uid') not in ('TeslaMate',None):continue
                    label=f'{filename} [{scenario}] panel {panel["id"]} {target.get("refId","A")}'
                    result={'dashboard':filename,'scenario':scenario,'panel_id':panel['id'],'panel_title':panel.get('title'),'ref_id':target.get('refId','A')}
                    before=time.monotonic()
                    try:
                        sql=interpolate(target['rawSql'],values,window_start,window_end,args.interval_ms)
                        data=grafana.query(sql,window_start,window_end,args.interval_ms,target.get('refId','A'),target)
                        result.update({'status':'PASS','rows':len(data['rows']),'frames':data['frames'],'field_names':data['field_names'],'sql_sha256':hashlib.sha256(sql.encode()).hexdigest()})
                        print('PASS',label,'rows='+str(result['rows']),flush=True)
                    except CheckError as e:result.update({'status':'FAIL','error':str(e)});fail(label,e)
                    result['elapsed_seconds']=round(time.monotonic()-before,3);report['queries'].append(result);checkpoint()
    report['finished_at_UTC']=datetime.datetime.now(datetime.timezone.utc).isoformat()
    report['summary']={'status':'PASS' if not report['failures'] else 'FAIL','provisioned_dashboard_count':len(remote),
                       'SQL_queries_passed':sum(q['status']=='PASS' for q in report['queries']),
                       'SQL_queries_failed':sum(q['status']=='FAIL' for q in report['queries']),
                       'SQL_queries_with_rows':sum(q.get('rows',0)>0 for q in report['queries']),
                       'warnings':len(report['warnings'])}
    if not report['queries']:fail('dashboard runtime queries','No dashboard SQL query was exercised');report['summary']['status']='FAIL'
    checkpoint();return report

def main():
    parser=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--url',required=True,help='Grafana base URL without /dashboards')
    parser.add_argument('--dashboards',type=pathlib.Path,default=REPO/'grafana/dashboards-zh')
    parser.add_argument('--report',type=pathlib.Path,required=True,help='Output report path; keep runtime reports outside version control')
    parser.add_argument('--car-id',type=int);parser.add_argument('--days',type=int,default=90)
    parser.add_argument('--interval-ms',type=int,default=3600000);parser.add_argument('--timeout',type=int,default=90)
    parser.add_argument('--scenarios',default='defaults',help='Comma-separated defaults,metric,imperial')
    parser.add_argument('--all-dashboards',action='store_true',help='Exercise every dashboard, including heavier statistics queries')
    parser.add_argument('--username');parser.add_argument('--password-env');parser.add_argument('--token-env')
    args=parser.parse_args()
    if args.days<=0 or args.interval_ms<=0:parser.error('--days and --interval-ms must be positive')
    try:report=run(args)
    except CheckError as e:print('FAIL',e,file=sys.stderr);return 1
    print(json.dumps(report.get('summary',{'status':'FAIL','errors':report['failures']}),ensure_ascii=False,indent=2))
    return 1 if report['failures'] else 0
if __name__=='__main__':sys.exit(main())
