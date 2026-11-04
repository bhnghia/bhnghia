'use server';
import {z} from 'zod';
import {revalidatePath} from 'next/cache';
import {requireOrganization} from '@/features/auth/guards';
export async function inviteCandidate(form:FormData){const org=z.uuid().parse(form.get('org'));const {db}=await requireOrganization(org);const {error}=await db.rpc('send_sourcing_invitation',{org,job:z.uuid().parse(form.get('job')),candidate:z.uuid().parse(form.get('candidate')),invitation_kind:z.enum(['apply','test']).parse(form.get('kind'))});if(error)return {error:'Không gửi được: kiểm tra Job, opt-in, ứng tuyển hiện có hoặc hạn mức lời mời.'};revalidatePath(`/organization/${org}/sourcing`);return {message:'Đã gửi lời mời. Gửi lại cùng loại cho cùng Job không tạo bản trùng.'};}
