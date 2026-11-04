import {NextRequest,NextResponse} from 'next/server';
import {supabase} from '@/lib/supabase/server';
import {boundedFormData,UploadBodyError} from '@/lib/bounded-form';
export async function POST(request:NextRequest){
 if(request.headers.get('origin')!==request.nextUrl.origin)return NextResponse.json({error:'Yêu cầu không hợp lệ.'},{status:403});
 const db=await supabase();const {data:{user}}=await db.auth.getUser();if(!user?.email_confirmed_at)return NextResponse.json({error:'Cần đăng nhập.'},{status:401});
 let form:FormData;try{form=await boundedFormData(request,6*1024*1024);}catch(e){return NextResponse.json({error:'Dữ liệu upload quá lớn hoặc không hợp lệ.'},{status:e instanceof UploadBodyError?e.status:400});}const file=form.get('file');
 if(!(file instanceof File)||file.size>5242880||file.size<5||file.type!=='application/pdf')return NextResponse.json({error:'CV cần là PDF tối đa 5 MB.'},{status:400});
 const bytes=new Uint8Array(await file.arrayBuffer());if(new TextDecoder().decode(bytes.slice(0,5))!=='%PDF-')return NextResponse.json({error:'File PDF không hợp lệ.'},{status:400});
 const path=`${user.id}/${crypto.randomUUID()}.pdf`;
 const {error}=await db.storage.from('candidate-cv').upload(path,bytes,{contentType:'application/pdf',upsert:false});
 if(error)return NextResponse.json({error:'Không thể upload CV.'},{status:400});
 const {error:metadataError}=await db.from('candidate_cv_files').insert({user_id:user.id,object_path:path});
 if(metadataError){await db.storage.from('candidate-cv').remove([path]);return NextResponse.json({error:'Không thể lưu CV.'},{status:500});}
 return NextResponse.redirect(new URL('/candidate?cv=uploaded',request.url),303);
}
export async function GET(request:NextRequest){
 const db=await supabase();const {data:{user}}=await db.auth.getUser();if(!user?.email_confirmed_at)return NextResponse.json({error:'Cần đăng nhập.'},{status:401});
 const id=request.nextUrl.searchParams.get('id');const {data}=await db.from('candidate_cv_files').select('object_path').eq('user_id',user.id).eq('id',id??'').maybeSingle();
 if(!data)return NextResponse.json({error:'Không tìm thấy CV.'},{status:404});
 const {data:download,error}=await db.storage.from('candidate-cv').createSignedUrl(data.object_path,60);
 if(error||!download)return NextResponse.json({error:'Không tải được CV.'},{status:400});
 return NextResponse.redirect(download.signedUrl,{headers:{'Cache-Control':'private, no-store'}});
}
