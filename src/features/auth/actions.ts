'use server';
import { z } from 'zod';
import { redirect } from 'next/navigation';
import { supabase } from '@/lib/supabase/server';
import { requireUser } from './guards';
const email=z.email();
export async function authenticate(mode:string, values:{email:string;password:string}) {
  if (!email.safeParse(values.email).success || !z.string().min(8).max(128).safeParse(values.password).success) return 'Kiểm tra email và mật khẩu (8–128 ký tự).';
  const db=await supabase();
  if(mode==='register') {
    const {error}=await db.auth.signUp({email:values.email,password:values.password});
    return error ? 'Không thể đăng ký. Vui lòng thử lại sau.' : 'Vui lòng kiểm tra email để xác minh tài khoản.';
  }
  if(mode!=='login') return 'Yêu cầu không hợp lệ.';
  const {data,error}=await db.auth.signInWithPassword(values);
  if(error || !data.user.email_confirmed_at) return 'Email hoặc mật khẩu không hợp lệ, hoặc email chưa xác minh.';
  redirect('/onboarding');
}
export async function signOut() { const db=await supabase(); const {error}=await db.auth.signOut(); if(error) throw new Error('Không thể đăng xuất.'); redirect('/login'); }
export async function passwordAction(mode:'forgot'|'reset', value:string) {
  const db=await supabase();
  if(mode==='forgot') {
    if(!email.safeParse(value).success) return 'Email không hợp lệ.';
    await db.auth.resetPasswordForEmail(value);
    return 'Nếu email đã đăng ký, hướng dẫn khôi phục sẽ được gửi.';
  }
  await requireUser();
  if(!z.string().min(8).max(128).safeParse(value).success) return 'Mật khẩu cần 8–128 ký tự.';
  const {error}=await db.auth.updateUser({password:value});
  return error ? 'Không thể đổi mật khẩu. Hãy yêu cầu liên kết mới.' : 'Đã đổi mật khẩu.';
}
export async function onboard(form:FormData) {
  const {db}=await requireUser();
  const choice=form.get('persona');
  if(choice!=='candidate' && choice!=='recruiter') throw new Error('Lựa chọn không hợp lệ.');
  const {error}=await db.rpc('set_persona',{choice});
  if(error) throw new Error('Không thể lưu lựa chọn.');
  redirect(choice==='candidate'?'/candidate':'/organization');
}
export async function organizationAction(form:FormData) {
  const {db}=await requireUser();
  if(form.get('operation')==='create') {
    const name=z.string().trim().min(1).max(200).parse(form.get('name'));
    const {data,error}=await db.rpc('create_organization',{org_name:name});
    if(error) throw new Error('Không thể tạo tổ chức.');
    redirect(`/organization/${data}`);
  }
  const org=z.uuid().parse(form.get('organization_id'));
  const {error}=await db.rpc('request_membership',{org});
  if(error) throw new Error('Không thể gửi yêu cầu.');
  redirect('/organization?requested=1');
}
export async function membershipAction(form:FormData) {
  const {db}=await requireUser();
  const org=z.uuid().parse(form.get('org'));
  const member=z.uuid().parse(form.get('member'));
  const operation=form.get('operation');
  const result=operation==='revoke' ? await db.rpc('revoke_membership',{org,member}) : await db.rpc('decide_membership',{org,member,approve:operation==='approve'});
  if(result.error) throw new Error('Không đủ quyền hoặc yêu cầu không còn hợp lệ.');
  redirect(`/organization/${org}`);
}
