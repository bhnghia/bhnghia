import {test} from 'node:test';
import assert from 'node:assert/strict';
import {canAccessOrganization} from '../src/features/auth/access.ts';
const m={user_id:'u',organization_id:'a',role:'recruiter'};
test('chưa đăng nhập',()=>assert.equal(canAccessOrganization(undefined,m,'a'),false));
test('sai quyền admin',()=>assert.equal(canAccessOrganization('u',m,'a',true),false));
test('thu hồi membership',()=>assert.equal(canAccessOrganization('u',null,'a'),false));
test('tổ chức khác',()=>assert.equal(canAccessOrganization('u',m,'b'),false));
test('membership đúng',()=>assert.equal(canAccessOrganization('u',m,'a'),true));
