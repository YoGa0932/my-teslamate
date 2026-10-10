#!/usr/bin/env python3
"""Translate upstream TeslaMate dashboards without touching queries or field identity.

Chinese is a presentation layer: targets, SQL, UIDs, variable names/values, transformations,
units and geometry remain upstream. Custom-variable label:value pairs retain original values.
Extra displayName/value-mapping overrides translate SQL result labels without renaming fields.
"""
import argparse, copy, hashlib, json, pathlib, re
BASE=pathlib.Path(__file__).resolve().parent
REPO = BASE.parent.parent
D=json.loads((BASE/'dictionary.json').read_text())
CONTEXT={'locations.json':{'States':'省州','State':'省州','state':'省州'}}
KEEP={'',' ','--','.', '❄','🆗','⁉️','TeslaMate','$car_id','$__cell_0','${__cell_0}','${__data.fields.duration_str}'}

def translation(text, strict=False, context=None):
    if context and text in context:return context[text]
    if text in D: return D[text]
    if strict and text not in KEEP and re.search('[A-Za-z]', text):
        raise ValueError('Untranslated presentation string: '+repr(text))
    return text

def presentation(k,v,parent,path):
    return isinstance(v,str) and (k in {'title','description','label','displayName','axisLabel'} or
        (k=='value' and parent.get('id')=='displayName') or
        (k=='text' and 'mappings' in path) or
        (k=='name' and 'annotations' in path) or
        (k=='content' and not v.startswith('<div style=')))

def walk_translate(obj,path=(),context=None):
    if isinstance(obj,dict):
        for k,v in obj.items():
            if presentation(k,v,obj,path): obj[k]=translation(v,True,context)
            else: walk_translate(v,path+(k,),context)
    elif isinstance(obj,list):
        for i,v in enumerate(obj):walk_translate(v,path+(i,),context)

def panel_list(dashboard):
    def rec(items):
        for p in items:
            yield p
            yield from rec(p.get('panels',[]))
    return list(rec(dashboard.get('panels',[])))

def audit_query_labels(dashboard):
    # Quoted SQL aliases are often user-visible table headers or legend labels.
    # Technical snake_case identifiers and interpolated units remain internal.
    for panel in panel_list(dashboard):
        for target in panel.get('targets',[]):
            for label in re.findall(r'\bas\s+"([^"\n]+)"',target.get('rawSql',''),re.I):
                if label in D or label in {'kWh','$length_unit'}:continue
                if re.fullmatch(r'[a-z_0-9$]+',label):continue
                translation(label,True)

def matches(matcher,name):
    if matcher['id']=='byName':return matcher['options']==name
    if matcher['id']=='byRegexp':
        try:return bool(re.search(matcher['options'].strip('/'),name))
        except re.error:return False
    return False

def display_candidates(panel):
    names=set()
    for t in panel.get('targets',[]):
        s=t.get('rawSql','')
        names.update(re.findall(r'\bas\s+"([^"\n]+)"',s,re.I))
        names.update(re.findall(r'\bas\s+([A-Za-z_][A-Za-z_0-9$]*)',s,re.I))
        # Static SQL string literals used as metric labels or action values.
        names.update(v for v in re.findall(r"'([^'\n]+)'",s) if v in D)
    for tr in panel.get('transformations',[]):
        names.update(tr.get('options',{}).get('renameByName',{}).values())
        if tr.get('options',{}).get('alias') in D:names.add(tr['options']['alias'])
    for o in panel.get('fieldConfig',{}).get('overrides',[]):
        if o.get('matcher',{}).get('id')=='byName':names.add(o['matcher']['options'])
    return names

def variable_pattern(text):
    # Field names carry expanded Grafana variables. Match the expansion, preserve variables in display text.
    pattern=re.escape(text)
    for token in re.findall(r'\$\{[^}]+\}|\$[A-Za-z_][A-Za-z_0-9]*',text):pattern=pattern.replace(re.escape(token),'.*?')
    return '^'+pattern+'$'

def localize_fields(source,out,context=None):
    sources={p['id']:p for p in panel_list(source)}
    additions=0
    for p in panel_list(out):
        original=sources[p['id']]
        names=display_candidates(original)
        # Grafana's Dashboard data source can reuse a different panel's SQL results.
        for target in original.get('targets',[]):
            if target.get('panelId') in sources:names|=display_candidates(sources[target['panelId']])
        fc=p.setdefault('fieldConfig',{}) if original.get('fieldConfig') else None
        if fc is None: continue
        overrides=fc.setdefault('overrides',[])
        for name in sorted(names):
            if name not in D:continue
            if any(matches(o.get('matcher',{}),name) and any(v['id']=='displayName' for v in o['properties']) for o in overrides):continue
            matcher={'id':'byRegexp','options':variable_pattern(name)} if '$' in name else {'id':'byName','options':name}
            overrides.append({'matcher':matcher,'properties':[{'id':'displayName','value':translation(name,context=context)}]});additions+=1
        # SQL-backed text values are mapped instead of editing the SQL or internal filters.
        if source.get('uid')=='SUBgwtigz' and original['type']=='table':
            action_map={name:{'text':D[name]} for name in ['🚗 Driving','🔋 Charging','🅿️ Parking','❓ Missing','💾 Updating']}
            overrides.append({'matcher':{'id':'byName','options':'Action'},'properties':[{'id':'mappings','value':[{'type':'value','options':action_map}]}]});additions+=1
    return additions

def custom_variables(source,out):
    changes=0
    for before,v in zip(source.get('templating',{}).get('list',[]),out.get('templating',{}).get('list',[])):
        if v.get('type')!='custom':continue
        raw=before.get('query',''); pairs=[]; labels={}
        for item in raw.split(','):
            split=item.split(' : ',1); label=split[0].strip(); value=split[1].strip() if len(split)==2 else label
            translated=translation(label,True)
            labels[value]=translated
            pairs.append(translated+' : '+value if translated!=label or len(split)==2 else label)
        if any(labels[val]!=label.strip() for label,val in [(x.split(' : ',1)[0],x.split(' : ',1)[1].strip() if ' : ' in x else x.strip()) for x in raw.split(',')]):
            v['query']=', '.join(pairs);changes+=1
            cur=v.get('current',{})
            if isinstance(cur.get('value'),list):cur['text']=[labels.get(x,x) for x in cur['value']]
            elif cur.get('value') in labels:cur['text']=labels[cur['value']]
            for opt in v.get('options',[]):
                if opt.get('value') in labels:opt['text']=labels[opt['value']]
        if before.get('includeAll'):
            v['allValue']=before.get('allValue') if 'allValue' in before else None
            if v['allValue'] is None:v.pop('allValue',None)
    return changes

def scalar_diffs(a,b,path=()):
    if type(a)!=type(b):yield path,a,b;return
    if isinstance(a,dict):
        for k in a.keys()|b.keys():
            if k not in a:yield path+(k,),None,b[k]
            elif k not in b:yield path+(k,),a[k],None
            else:yield from scalar_diffs(a[k],b[k],path+(k,))
    elif isinstance(a,list):
        for i in range(max(len(a),len(b))):
            if i>=len(a):yield path+(i,),None,b[i]
            elif i>=len(b):yield path+(i,),a[i],None
            else:yield from scalar_diffs(a[i],b[i],path+(i,))
    elif a!=b:yield path,a,b

def at(obj,path):
    for x in path:obj=obj[x]
    return obj

def approved(source,out,path,a,b):
    if a is not None:
        parent=at(source,path[:-1])
        if isinstance(parent,dict) and presentation(path[-1],a,parent,path[:-1]):return True
        if path[:2]==('templating','list'):
            variable=source['templating']['list'][path[2]]
            if variable.get('type')=='custom' and (path[-1]=='text' or path[-1]=='query'):return True
    if 'fieldConfig' in path and 'overrides' in path:
        # Appended overrides have original field matchers and only presentation properties.
        oi=path.index('overrides'); original=at(source,path[:oi])
        if oi+1==len(path):
            return a is None and all(all(x['id'] in ('displayName','mappings') for x in o['properties']) for o in b)
        if isinstance(path[oi+1],int) and path[oi+1]>=len(original.get('overrides',[])):
            override=at(out,path[:oi+2])
            return all(x['id'] in ('displayName','mappings') for x in override['properties'])
    return False

def protected_snapshot(j):
    out={k:j.get(k) for k in ('uid','schemaVersion','tags','time','timezone','refresh','version','id')}
    out['panels']=[{k:p.get(k) for k in ('id','type','gridPos','datasource','targets','repeat','repeatDirection','libraryPanel','transformations')} for p in panel_list(j)]
    out['variables']=[{k:v.get(k) for k in ('name','type','datasource','definition','regex','allValue','multi','includeAll','hide')} | {'value':v.get('current',{}).get('value'),'option_values':[o.get('value') for o in v.get('options',[])]} for v in j.get('templating',{}).get('list',[])]
    out['urls']=[]
    def scan(x):
        if isinstance(x,dict):
            for k,v in x.items():
                if k=='url':out['urls'].append(v)
                scan(v)
        elif isinstance(x,list):
            for v in x:scan(v)
    scan(j)
    return out

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source',type=pathlib.Path,default=REPO/'grafana/dashboards')
    ap.add_argument('--output',type=pathlib.Path,default=REPO/'grafana/dashboards-zh')
    ap.add_argument('--report',type=pathlib.Path,help='Optional JSON verification report')
    args=ap.parse_args()
    files=sorted(args.source.rglob('*.json'))
    if not files:ap.error('Source directory contains no dashboard JSON files')
    if args.source.resolve()==args.output.resolve():ap.error('Source and output directories must differ')
    report={'dashboard_count':0,'presentation_changes':0,'display_overrides_added':0,'custom_variable_queries_localized':0,'checks':[],'files':[]}
    pending=[]
    uids=set()
    # Complete translation and validation before writing any dashboard. An unknown UI
    # string fails the run, leaving the previous generated files available for review.
    for f in files:
        source=json.loads(f.read_text());out=copy.deepcopy(source)
        audit_query_labels(source)
        if source['uid'] in uids:raise ValueError('Duplicate official dashboard UID: '+source['uid'])
        uids.add(source['uid'])
        context=CONTEXT.get(f.name,{})
        walk_translate(out,context=context);n=localize_fields(source,out,context);v=custom_variables(source,out)
        diffs=list(scalar_diffs(source,out))
        bad=[p for p,a,b in diffs if not approved(source,out,p,a,b)]
        if bad:raise ValueError(f'{f.name}: unapproved differences {bad[:5]}')
        assert protected_snapshot(source)==protected_snapshot(out), f'{f.name}: protected upstream structure changed'
        encoded=(json.dumps(out,ensure_ascii=False,indent=2)+'\n').encode()
        relative=f.relative_to(args.source);pending.append((relative,encoded))
        report['dashboard_count']+=1;report['presentation_changes']+=len(diffs);report['display_overrides_added']+=n;report['custom_variable_queries_localized']+=v
        report['files'].append({'file':str(relative),'uid':source['uid'],'title':out['title'],'source_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'translated_sha256':hashlib.sha256(encoded).hexdigest(),'presentation_differences':len(diffs)})
    report['checks']=[f"All {report['dashboard_count']} official dashboard JSONs included",'All direct authored UI strings translated or explicitly retained as brand/symbol/variable','SQL targets and aliases byte-identical','Datasource UIDs and dashboard UIDs preserved','Panel IDs, types, geometry and repeats preserved','Units and original transformations preserved','Original variable names, current values, option values and SQL queries preserved','Dashboard and data-link URLs preserved','Every semantic difference restricted to an approved presentation path','Custom variable label:value changes preserve selectable values']
    for relative,encoded in pending:
        path=args.output/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(encoded)
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='files'},ensure_ascii=False,indent=2))
if __name__=='__main__':main()
