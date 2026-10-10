#!/usr/bin/env python3
"""Independent fidelity checks for the generated dashboard presentation layer."""
import argparse,hashlib,json,pathlib,re
BASE=pathlib.Path(__file__).resolve().parent
REPO=BASE.parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source',type=pathlib.Path,default=REPO/'grafana/dashboards')
parser.add_argument('--output',type=pathlib.Path,default=REPO/'grafana/dashboards-zh')
parser.add_argument('--report',type=pathlib.Path,help='Optional JSON verification report')
args=parser.parse_args()
SOURCE=args.source
OUTPUT=args.output

def panels(j):
    result=[]
    def rec(xs):
        for p in xs:result.append(p);rec(p.get('panels',[]))
    rec(j.get('panels',[]));return result

def paths(obj,path=()):
    if isinstance(obj,dict):
        for k,v in obj.items():yield from paths(v,path+(k,))
    elif isinstance(obj,list):
        for i,v in enumerate(obj):yield from paths(v,path+(i,))
    else:yield path,obj

def custom_values(query):
    return [v.split(' : ',1)[-1].strip() for v in query.split(',')]

files=list(sorted(SOURCE.rglob('*.json')))
assert files,'No official dashboard JSON files found'
source_uids=[json.loads(f.read_text())['uid'] for f in files]
assert len(source_uids)==len(set(source_uids)),'Duplicate official dashboard UIDs'
assert {str(f.relative_to(SOURCE)) for f in files}=={str(f.relative_to(OUTPUT)) for f in OUTPUT.rglob('*.json')}
queries=units=transforms=links=variables=0
for f in files:
    a=json.loads(f.read_text());b=json.loads((OUTPUT/f.relative_to(SOURCE)).read_text())
    assert a['uid']==b['uid']
    pa,pb=panels(a),panels(b);assert len(pa)==len(pb)
    for p,q in zip(pa,pb):
        for k in ['id','gridPos','type','datasource','targets','transformations','repeat','repeatDirection']:
            assert p.get(k)==q.get(k),(f,k,p.get('id'))
        queries+=sum('rawSql' in t for t in p.get('targets',[]));transforms+=len(p.get('transformations',[]))
        for k in ('unit','decimals','min','max'):
            assert p.get('fieldConfig',{}).get('defaults',{}).get(k)==q.get('fieldConfig',{}).get('defaults',{}).get(k)
        op=p.get('fieldConfig',{}).get('overrides',[]);oq=q.get('fieldConfig',{}).get('overrides',[])
        assert len(oq)>=len(op)
        for old,new in zip(op,oq):
            assert old['matcher']==new['matcher'];assert [v['id'] for v in old['properties']]==[v['id'] for v in new['properties']]
            for prop,prop2 in zip(old['properties'],new['properties']):
                if prop['id']=='unit':assert prop==prop2;units+=1
        for added in oq[len(op):]:
            assert added['matcher']['id'] in ('byName','byRegexp')
            assert all(v['id'] in ('displayName','mappings') for v in added['properties'])
    va,vb=a.get('templating',{}).get('list',[]),b.get('templating',{}).get('list',[]);assert len(va)==len(vb)
    for old,new in zip(va,vb):
        for k in ('name','definition','type','datasource','regex','allValue','hide','includeAll','multi'):
            assert old.get(k)==new.get(k),(f,k,old['name'])
        assert old.get('current',{}).get('value')==new.get('current',{}).get('value')
        assert [x.get('value') for x in old.get('options',[])]==[x.get('value') for x in new.get('options',[])]
        if old['type']=='custom':assert custom_values(old['query'])==custom_values(new['query'])
        else:assert old.get('query')==new.get('query')
        variables+=1
    al=[v for p,v in paths(a) if p[-1]=='url'];bl=[v for p,v in paths(b) if p[-1]=='url'];assert al==bl;links+=len(al)
    # All hyperlinks in descriptions/content retain the original destinations.
    def html_links(j):
        result=[]
        for p,v in paths(j):
            if isinstance(v,str) and p[-1] in ('description','content'):
                result+=re.findall(r"(?:href=[\"']|\]\()(https?://[^\"'\s)]+)",v)
        return result
    assert html_links(a)==html_links(b),(f,'description hyperlink destinations')
result={'result':'PASS','official_dashboards':len(files),'SQL_targets_verified':queries,'unit_overrides_verified':units,'original_transformations_verified':transforms,'variables_verified':variables,'link_URLs_verified':links,'output_sha256':{str(f.relative_to(OUTPUT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(OUTPUT.rglob('*.json'))}}
if args.report:
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='output_sha256'},ensure_ascii=False,indent=2))
