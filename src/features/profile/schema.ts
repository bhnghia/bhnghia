import {z} from 'zod';
export const wordCount=(value:string)=>value.trim()?value.trim().split(/\s+/u).length:0;
export const profileSchema=z.object({
 full_name:z.string().trim().min(1).max(100), display_name:z.string().trim().min(1).max(100),
 school:z.string().trim().max(200), study_year:z.string().trim().max(50),
 district:z.string().trim().min(1).max(100), province:z.string().trim().min(1).max(100),
 desired_position:z.string().trim().min(1).max(150), work_mode:z.enum(['onsite','remote','hybrid']),
 salary:z.number().finite().nonnegative().max(1e12), salary_unit:z.enum(['hour','shift','month']),
 skills:z.array(z.string().trim().min(1).max(60)).min(3).max(5).refine(s=>new Set(s.map(x=>x.toLocaleLowerCase('vi'))).size===s.length,'Kỹ năng không được trùng.'),
 bio:z.string().trim().max(3000).refine(v=>wordCount(v)<=30,'Bio tối đa 30 từ.'),
 discoverable:z.boolean().default(false), avatar_visible:z.boolean().default(false),
});
export type CandidateProfile=z.infer<typeof profileSchema>;
export const publicCard=(p:CandidateProfile)=>({display_name:p.display_name,school:p.school,study_year:p.study_year,district:p.district,province:p.province,desired_position:p.desired_position,work_mode:p.work_mode,salary:p.salary,salary_unit:p.salary_unit,skills:p.skills,bio:p.bio,avatar_visible:p.avatar_visible});
export type ProfileCardData=ReturnType<typeof publicCard>;
export interface CvExtractionAdapter { extract(file:Uint8Array):Promise<{suggestions:Partial<CandidateProfile>;warnings:string[]}>; }
// Adapter chỉ trả gợi ý. Không được gọi save hoặc tự gửi CV sang nhà cung cấp.
