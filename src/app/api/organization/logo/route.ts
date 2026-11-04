import {NextRequest,NextResponse} from 'next/server';
import {supabase} from '@/lib/supabase/server';
import {z} from 'zod';
import {boundedFormData,UploadBodyError} from '@/lib/bounded-form';
export async function POST(request:NextRequest){
 if(request.headers.get('origin')!==request.nextUrl.origin)return NextResponse.json({error:'Yêu cầu không hợp lệ.'},{status:403});
 const db=await supabase();const {data:{user}}=await db.auth.getUser();if(!user?.email_confirmed_at)return NextResponse.json({error:'Cần đăng nhập.'},{status:401});
 let form:FormData;try{form=await boundedFormData(request,3*1024*1024);}catch(e){return NextResponse.json({error:'Dữ liệu upload quá lớn hoặc không hợp lệ.'},{status:e instanceof UploadBodyError?e.status:400});}const org=z.uuid().safeParse(form.get('org'));const file=form.get('file');if(!org.success)return NextResponse.json({error:'Mã tổ chức không hợp lệ.'},{status:400});
 const {data:allowed}=await db.rpc('is_org_member',{org:org.data,admin_only:true});if(!allowed)return NextResponse.json({error:'Không đủ quyền.'},{status:403});
 if(!(file instanceof File)||file.size<12||file.size>2097152)return NextResponse.json({error:'Ảnh tối đa 2 MB.'},{status:400});
 const bytes=new Uint8Array(await file.arrayBuffer());let mime='';
 if(bytes[0]===137&&bytes[1]===80&&bytes[2]===78&&bytes[3]===71)mime='image/png';
 else if(bytes[0]===255&&bytes[1]===216&&bytes[2]===255)mime='image/jpeg';
 else if(new TextDecoder().decode(bytes.slice(0,4))==='RIFF'&&new TextDecoder().decode(bytes.slice(8,12))==='WEBP')mime='image/webp';
 if(!mime)return NextResponse.json({error:'Cần ảnh PNG, JPEG hoặc WebP.'},{status:400});
 const path=`${org.data}/${crypto.randomUUID()}`;const {error}=await db.storage.from('organization-logos').upload(path,bytes,{contentType:mime});if(error)return NextResponse.json({error:'Không thể upload.'},{status:400});
 const {error:saveError}=await db.rpc('set_organization_logo',{org:org.data,path});if(saveError){await db.storage.from('organization-logos').remove([path]);return NextResponse.json({error:'Không thể lưu logo.'},{status:400});}
 return NextResponse.redirect(new URL(`/organization/${org.data}`,request.url),303);
}
