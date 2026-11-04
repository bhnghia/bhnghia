import { NextRequest, NextResponse } from 'next/server';
import { supabase } from '@/lib/supabase/server';
export async function GET(request:NextRequest) {
  const token_hash=request.nextUrl.searchParams.get('token_hash');
  const type=request.nextUrl.searchParams.get('type');
  if(token_hash && (type==='signup'||type==='recovery'||type==='email')) {
    const db=await supabase();
    const {error}=await db.auth.verifyOtp({token_hash,type});
    if(!error) return NextResponse.redirect(new URL(type==='recovery'?'/reset-password':'/onboarding',request.url));
  }
  return NextResponse.redirect(new URL('/login?error=confirmation',request.url));
}
