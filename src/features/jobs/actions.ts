'use server';
import {z} from 'zod';
import {revalidatePath} from 'next/cache';
import {requireOrganization,requireUser} from '@/features/auth/guards';
import {jobSchema} from './schema';
export async function saveJob(form:FormData){
 const org=z.uuid().parse(form.get('org'));const {db}=await requireOrganization(org);
 const parsed=jobSchema.safeParse({title:form.get('title'),branch_id:form.get('branch_id'),industry:form.get('industry'),salary_min:form.get('salary_min')===''?null:Number(form.get('salary_min')),salary_max:form.get('salary_max')===''?null:Number(form.get('salary_max')),salary_unit:form.get('salary_unit'),salary_basis:form.get('salary_basis'),work_mode:form.get('work_mode'),description:form.get('description'),requirements:form.get('requirements'),benefits:form.get('benefits'),skills:String(form.get('skills')??'').split(',').map(s=>s.trim()).filter(Boolean),safety_commitment:form.get('safety_commitment')==='on',test_enabled:form.get('test_enabled')==='on',test_written_count:Number(form.get('test_written_count'))});
 if(!parsed.success)return {error:parsed.error.issues.map(i=>i.message).join(' ')};
 const job=form.get('job')?z.uuid().parse(form.get('job')):null;
 const {data,error}=await db.rpc('save_job',{org,job,payload:parsed.data});
 if(error)return {error:'Không thể lưu. Kiểm tra quyền HR, chi nhánh và trạng thái job; job đang công khai cần tạm dừng trước khi sửa.'};
 revalidatePath(`/organization/${org}`);revalidatePath('/jobs');return {href:`/organization/${org}/jobs/${data}`,message:'Đã lưu thay đổi.'};
}
export async function transitionJob(form:FormData){
 const org=z.uuid().parse(form.get('org'));const {db}=await requireOrganization(org);
 const job=z.uuid().parse(form.get('job'));const target=z.enum(['published','paused','closed']).parse(form.get('target'));
 const {data:owned}=await db.from('jobs').select('id').eq('organization_id',org).eq('id',job).maybeSingle();if(!owned)return {error:'Không có quyền với job này.'};
 const {error}=await db.rpc('transition_job',{job,target});
 if(error)return {error:'Chưa thể chuyển trạng thái. Xuất bản cần doanh nghiệp đã được kiểm tra, chi nhánh, lương, 3 kỹ năng, JD/yêu cầu/quyền lợi và cam kết an toàn đầy đủ. Micro-test chưa đủ điều kiện xuất bản.'};
 revalidatePath('/jobs');revalidatePath(`/organization/${org}/jobs/${job}`);return {message:'Đã cập nhật trạng thái.'};
}
export async function saveBookmark(form:FormData){const {db}=await requireUser();const {error}=await db.rpc('set_saved_job',{job:z.uuid().parse(form.get('job')),saved:form.get('saved')==='true'});if(error)return {error:'Không thể lưu hoặc việc đã ngừng công khai.'};revalidatePath('/jobs/saved');return {message:form.get('saved')==='true'?'Đã lưu riêng tư.':'Đã bỏ lưu.'};}
export async function applyJob(form:FormData){if(form.get('confirm')!=='on')return {error:'Cần xác nhận chia sẻ Profile Card.'};const {db}=await requireUser();const {data,error}=await db.rpc('apply_to_job',{job:z.uuid().parse(form.get('job'))});if(error)return {error:'Chưa thể ứng tuyển. Hãy hoàn thiện Profile Card và kiểm tra tin còn công khai.'};return {href:`/applications/${data}`,message:'Đã tạo ứng tuyển. CV gốc không được chia sẻ.'};}
