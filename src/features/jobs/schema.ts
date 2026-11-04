import {z} from 'zod';
const amount=z.number().finite().min(0).max(1e12).nullable();
export const jobSchema=z.object({
 title:z.string().trim().min(1,'Cần nhập vị trí tuyển dụng.').max(200),
 branch_id:z.union([z.uuid(),z.literal('')]),industry:z.string().trim().max(100),
 salary_min:amount,salary_max:amount,salary_unit:z.enum(['hour','shift','month']),salary_basis:z.enum(['gross','net']),
 work_mode:z.enum(['onsite','remote','hybrid']),description:z.string().trim().max(20000),requirements:z.string().trim().max(10000),benefits:z.string().trim().max(10000),
 skills:z.array(z.string().trim().min(1).max(60)).max(3).refine(s=>new Set(s.map(x=>x.toLocaleLowerCase('vi'))).size===s.length,'Kỹ năng phải khác nhau.'),
 safety_commitment:z.boolean(),test_enabled:z.boolean(),test_written_count:z.number().int().min(0).max(3),
}).refine(j=>j.salary_min===null||j.salary_max===null||j.salary_max>=j.salary_min,'Lương tối đa phải lớn hơn hoặc bằng lương tối thiểu.');
export type JobInput=z.infer<typeof jobSchema>;
export type PublicJob=JobInput&{id:string;organization_id:string;company_name:string;logo_path:string|null;verified:boolean;province:string;district:string;branch_address:string};
export type WageRule={region_code:string;valid_from:string;valid_until:string|null;unit:string;basis:string;currency:string;amount:number;source_reference:string};
export function wageAdvisory(job:Pick<JobInput,'salary_min'|'salary_unit'|'salary_basis'>,region:string|null,rules:WageRule[],date:string){
 const matches=rules.filter(r=>r.region_code===region&&r.currency==='VND'&&r.unit===job.salary_unit&&r.basis===job.salary_basis&&r.valid_from<=date&&(!r.valid_until||date<r.valid_until));
 if(matches.length!==1||job.salary_min===null)return 'Chưa đủ dữ liệu hoặc cấu hình còn chồng lấn để so sánh lương tối thiểu vùng.';
 return job.salary_min<matches[0].amount?`Lương thấp hơn mức tham chiếu trong ${matches[0].source_reference}. Cần rà soát thêm; đây không phải kết luận pháp lý.`:'Không thấp hơn mức tham chiếu theo cấu hình hiện tại. So sánh này không xác nhận tuân thủ pháp luật.';
}
