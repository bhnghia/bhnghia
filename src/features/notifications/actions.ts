'use server';
import {requireUser} from '@/features/auth/guards';
import {revalidatePath} from 'next/cache';
export async function readNotification(form:FormData){const {db}=await requireUser();const id=String(form.get('id')??'');const {error}=await db.rpc('mark_notification_read',{notification:id});if(error)return {error:'Không đánh dấu đã đọc được.'};revalidatePath('/notifications');return {message:'Đã đọc.'};}
