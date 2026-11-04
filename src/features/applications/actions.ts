'use server';
import {z} from 'zod';
import {revalidatePath} from 'next/cache';
import {requireOrganization} from '@/features/auth/guards';
export async function reviewApplication(form:FormData){const org=z.uuid().parse(form.get('org'));const {db}=await requireOrganization(org);const id=z.uuid().parse(form.get('application'));const {data}=await db.from('applications').select('id').eq('id',id).eq('organization_id',org).maybeSingle();if(!data)return {error:'Không có quyền với hồ sơ này.'};const {error}=await db.rpc('review_application',{application:id,expected:String(form.get('expected')),target:String(form.get('target')),message:String(form.get('message')??'').slice(0,2000)});if(error)return {error:'Trạng thái đã thay đổi hoặc thao tác không được phép. Tải lại hồ sơ để kiểm tra.'};revalidatePath(`/applications/${id}`);revalidatePath(`/organization/${org}/applicants`);return {message:'Đã cập nhật kết quả xét duyệt.'};}
