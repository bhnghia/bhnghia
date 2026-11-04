'use server';
import {requireUser} from '@/features/auth/guards';
import {profileSchema} from './schema';
import {revalidatePath} from 'next/cache';
export async function saveProfile(input:unknown,confirmed:boolean) {
 if(confirmed!==true)return {error:'Bạn cần xem lại và xác nhận thông tin trước khi lưu.'};
 const parsed=profileSchema.safeParse(input);
 if(!parsed.success)return {error:parsed.error.issues.map(i=>i.message).join(' ')};
 const {db,user}=await requireUser();
 const {error}=await db.from('candidate_profiles').upsert({...parsed.data,user_id:user.id,updated_at:new Date().toISOString()});
 if(error)return {error:'Không thể lưu hồ sơ. Vui lòng kiểm tra dữ liệu và thử lại.'};
 revalidatePath('/candidate'); return {success:true};
}
