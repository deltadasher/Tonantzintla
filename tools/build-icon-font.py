#!/usr/bin/env python3
"""Build-time icon subset using public HarfBuzz subset/builder APIs; no runtime dependency.
Keeps glyph IDs and hints for byte-level outline/metric comparison.
"""
import ctypes as C
import hashlib,json,re,struct
from pathlib import Path
import argparse
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'src/assets/fonts'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source',required=True,type=Path,help='Pinned Nerd Fonts 3.5.1 Iosevka Regular TTF')
parser.add_argument('--check',action='store_true',help='Verify exact regeneration without writing files')
args=parser.parse_args()
SOURCE=args.source
manifest=json.loads((BASE/'glyphs.json').read_text())
EXPECTED_SHA256=manifest['source_sha256']
hb=C.CDLL('libharfbuzz.so.0');sub=C.CDLL('libharfbuzz-subset.so.0')
P=C.c_void_p;U=C.c_uint;I=C.c_int

def api(lib,name,args,ret):
 f=getattr(lib,name);f.argtypes=args;f.restype=ret;return f
blobfile=api(hb,'hb_blob_create_from_file_or_fail',[C.c_char_p],P)
blobnew=api(hb,'hb_blob_create',[C.c_char_p,U,I,P,P],P)
blobdata=api(hb,'hb_blob_get_data',[P,C.POINTER(U)],P)
facecreate=api(hb,'hb_face_create',[P,U],P)
faceblob=api(hb,'hb_face_reference_blob',[P],P)
facetable=api(hb,'hb_face_reference_table',[P,U],P)
collect=api(hb,'hb_face_collect_unicodes',[P,P],None)
setnew=api(hb,'hb_set_create',[],P)
setadd=api(hb,'hb_set_add',[P,U],None)
setnext=api(hb,'hb_set_next',[P,C.POINTER(U)],I)
setinvert=api(hb,'hb_set_invert',[P],None)
inputnew=api(sub,'hb_subset_input_create_or_fail',[],P)
inputset=api(sub,'hb_subset_input_set',[P,U],P)
flags=api(sub,'hb_subset_input_set_flags',[P,U],None)
subset=api(sub,'hb_subset_or_fail',[P,P],P)
builder=api(hb,'hb_face_builder_create',[],P)
addtable=api(hb,'hb_face_builder_add_table',[P,U,P],I)
fontnew=api(hb,'hb_font_create',[P],P)
otfunc=api(hb,'hb_ot_font_set_funcs',[P],None)
nominal=api(hb,'hb_font_get_nominal_glyph',[P,U,C.POINTER(U)],I)

def data(blob):
 length=U();p=blobdata(blob,C.byref(length));return C.string_at(p,length.value)
def tables(raw):
 count=struct.unpack_from('>H',raw,4)[0]
 return {tag:raw[offset:offset+size] for tag,_,offset,size in (struct.unpack_from('>4sIII',raw,12+16*i) for i in range(count))}
def renamed(raw,family):
 # Source and HarfBuzz output use name format 0. Preserve all other name records.
 fmt,count,start=struct.unpack_from('>HHH',raw)
 assert fmt==0
 records=[];strings=bytearray()
 for i in range(count):
  platform,encoding,language,key,size,offset=struct.unpack_from('>6H',raw,6+12*i)
  value=raw[start+offset:start+offset+size]
  replacements={1:family,3:family+'; Regular; subset 1',4:family+' Regular',6:family.replace(' ','')+'-Regular',16:family,18:family+' Regular',21:family}
  if key in replacements:value=replacements[key].encode('utf-16-be' if platform in (0,3) else 'mac_roman')
  records.append(struct.pack('>6H',platform,encoding,language,key,len(value),len(strings)));strings.extend(value)
 return struct.pack('>HHH',0,count,6+12*count)+b''.join(records)+strings

def glyphs(table):
 loca=table[b'loca'];fmt=struct.unpack_from('>h',table[b'head'],50)[0];unit=4 if fmt else 2
 offsets=[v[0]*(1 if fmt else 2) for v in struct.iter_unpack('>I' if fmt else '>H',loca)]
 return [table[b'glyf'][a:b] for a,b in zip(offsets,offsets[1:])]
def metric(table,gid):
 count=struct.unpack_from('>H',table[b'hhea'],34)[0]
 if gid<count:return struct.unpack_from('>Hh',table[b'hmtx'],gid*4)
 return struct.unpack_from('>H',table[b'hmtx'],(count-1)*4)[0],struct.unpack_from('>h',table[b'hmtx'],count*4+(gid-count)*2)[0]

source_bytes=SOURCE.read_bytes();assert hashlib.sha256(source_bytes).hexdigest()==EXPECTED_SHA256, "Pinned font source mismatch";source_tables=tables(source_bytes)
face=facecreate(blobfile(str(SOURCE).encode()),0);available=setnew();collect(face,available)
all_codes=set();current=U(0xffffffff)
while setnext(available,C.byref(current)):all_codes.add(current.value)
font=fontnew(face);otfunc(font)
requested=set(manifest['codepoints'])
report={'source':str(SOURCE),'source_sha256':hashlib.sha256(source_bytes).hexdigest(),'source_bytes':len(source_bytes),'source_unicode_count':len(all_codes),'variants':{}}
for name,codes in [('audited',requested)]:
 chosen=(codes&all_codes)-{0xb2,0xb3,0xb9,0x3df,0x2070,0x2500};settings=inputnew()
 for value in chosen:setadd(inputset(settings,1),value)
 setinvert(inputset(settings,4));setinvert(inputset(settings,5))
 # RETAIN_GIDS | NAME_LEGACY | NOTDEF_OUTLINE | GLYPH_NAMES. Hints retained.
 flags(settings,2|8|64|128)
 result=subset(face,settings);assert result
 raw=data(faceblob(result));t=tables(raw);newface=builder()
 family=manifest['family']
 for tag,value in t.items():
  if tag==b'name':value=renamed(source_tables[b'name'],family)
  assert addtable(newface,int.from_bytes(tag,'big'),blobnew(value,len(value),0,None,None))
 output=data(faceblob(newface));path=BASE/'TonantzintlaSymbols-Regular.ttf'
 if args.check:assert path.read_bytes()==output, 'Bundled font differs from pinned regeneration'
 else:path.write_bytes(output)
 out_tables=tables(output);before=glyphs(source_tables);after=glyphs(out_tables);outfont=fontnew(newface);otfunc(outfont)
 for value in chosen:
  original=U();changed=U();assert nominal(font,value,C.byref(original));assert nominal(outfont,value,C.byref(changed))
  assert original.value==changed.value
  assert before[original.value].rstrip(b"\0")==after[changed.value].rstrip(b"\0"),(hex(value),len(before[original.value]),len(after[changed.value]))
  assert metric(source_tables,original.value)==metric(out_tables,changed.value),hex(value)
 # Ensure layout closure never pulls an unaudited patched icon collection in.
 for value in all_codes:
  if (0xe000<=value<=0xf8ff or 0xf0000<=value<=0x10fffd or value==0x2500) and value not in chosen:
   original=U();nominal(font,value,C.byref(original))
   assert original.value>=len(after) or not after[original.value].rstrip(b"\0"), 'Unreviewed closure glyph '+hex(value)
 for tag in (b'fpgm',b'prep',b'cvt '):assert source_tables[tag]==out_tables[tag]
 report['variants'][name]={'family':family,'bytes':len(output),'codepoints':len(chosen),'missing_original':sorted(codes-all_codes),'sha256':hashlib.sha256(output).hexdigest(),'outline_and_metrics_equal':True}
print(json.dumps(report,indent=2))

# Keep the runtime membership table synchronized with the reviewed manifest.
ranges=[]
for point in sorted(requested):
 if ranges and ranges[-1][1]+1==point:ranges[-1][1]=point
 else:ranges.append([point,point])
helper=ROOT/'src/quickshell/components/IconFontGlyphs.js'
old=helper.read_text()
new=re.sub(r'var ranges = .*?;', 'var ranges = '+json.dumps(ranges,separators=(',',':'))+';',old,count=1)
if args.check:assert old==new, 'Runtime glyph membership differs from manifest'
else:helper.write_text(new)
