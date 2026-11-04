import {test} from 'node:test';
import assert from 'node:assert/strict';
import {boundedFormData,UploadBodyError} from '../src/lib/bounded-form.ts';
test('multipart accepts bounded valid form',async()=>{const f=new FormData();f.set('name','CV');const data=await boundedFormData(new Request('http://local',{method:'POST',body:f}),4096);assert.equal(data.get('name'),'CV');});
test('stream cap rejects absent or false content-length',async()=>{for(const headers of [new Headers(),new Headers({'content-length':'1'})]){const req=new Request('http://local',{method:'POST',body:'x'.repeat(100),headers});await assert.rejects(()=>boundedFormData(req,10),(e:unknown)=>e instanceof UploadBodyError&&e.status===413);}});
test('oversized declaration and invalid multipart rejected',async()=>{await assert.rejects(()=>boundedFormData(new Request('http://local',{method:'POST',body:'x',headers:{'content-length':'9999'}}),100),UploadBodyError);await assert.rejects(()=>boundedFormData(new Request('http://local',{method:'POST',body:'invalid'}),100),UploadBodyError);});
