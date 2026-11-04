import 'server-only';
import {supabase} from '@/lib/supabase/server';
import type {PublicJob} from './schema';
export async function loadPublicJobs(){const db=await supabase();const {data,error}=await db.rpc('public_jobs');if(error)throw new Error('Không tải được danh sách việc làm.');return (data??[]) as PublicJob[];}
