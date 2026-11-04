import {test} from 'node:test';
import assert from 'node:assert/strict';
import {profileSchema,publicCard} from '../src/features/profile/schema.ts';
const input={full_name:'Tên riêng',display_name:'Tên hiển thị',school:'',study_year:'',district:'Quận 1',province:'TP HCM',desired_position:'Kế toán',work_mode:'onsite',salary:10000000,salary_unit:'month',skills:['Excel','Kế toán','Giao tiếp'],bio:'Chào bạn'};
test('privacy defaults OFF',()=>{const p=profileSchema.parse(input);assert.equal(p.discoverable,false);assert.equal(p.avatar_visible,false);});
test('public projection excludes all unlisted private fields',()=>{const card=publicCard(profileSchema.parse({...input,email:'secret',cv_path:'private',test_score:10}));for(const field of ['full_name','email','cv_path','test_score','discoverable'])assert.equal(field in card,false);});
test('requires 3–5 distinct skills',()=>{for(const skills of [[],['a','b'],['a','b','c','d','e','f'],['a','A','b']])assert.equal(profileSchema.safeParse({...input,skills}).success,false);});
test('bio boundary and Vietnamese whitespace',()=>{assert.equal(profileSchema.safeParse({...input,bio:Array(30).fill('từ').join(' ')}).success,true);assert.equal(profileSchema.safeParse({...input,bio:Array(31).fill('từ').join('\n')}).success,false);});
test('reject invalid salary and missing region',()=>{assert.equal(profileSchema.safeParse({...input,salary:-1}).success,false);assert.equal(profileSchema.safeParse({...input,district:''}).success,false);});
