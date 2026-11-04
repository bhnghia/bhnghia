import {test} from 'node:test';
import assert from 'node:assert/strict';
import {allowedTargets,labels,type ApplicationStatus} from '../src/features/applications/state.ts';
test('all roles and states have an explicit transition set',()=>{const expected={submitted:['under_review'],under_review:['interview_invited','rejected'],test_pending:[],test_submitted:[],interview_invited:[],rejected:[]};for(const s of Object.keys(labels) as ApplicationStatus[]){assert.deepEqual(allowedTargets(s,'candidate'),[]);assert.deepEqual(allowedTargets(s,'hr'),expected[s]);assert.deepEqual(allowedTargets(s,'test_processor'),s==='test_pending'?['test_submitted']:s==='test_submitted'?['under_review']:[]);}});
