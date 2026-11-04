import 'server-only';
import { redirect, notFound } from 'next/navigation';
import { supabase } from '@/lib/supabase/server';
import { canAccessOrganization } from './access';
export async function requireUser() {
  const db=await supabase();
  const {data:{user}}=await db.auth.getUser();
  if (!user || !user.email_confirmed_at) redirect('/login');
  return {db,user};
}
export async function requireOrganization(id:string, adminOnly=false) {
  const {db,user}=await requireUser();
  const {data}=await db.from('organization_members').select('user_id,organization_id,role').eq('organization_id',id).eq('user_id',user.id).maybeSingle();
  if (!canAccessOrganization(user.id,data,id,adminOnly)) notFound();
  return {db,user,membership:data!};
}
