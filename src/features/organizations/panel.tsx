import Link from 'next/link';
import Image from 'next/image';
import {requireOrganization} from '@/features/auth/guards';
import {ActionForm} from '@/components/action-form';
import {Input} from '@/components/ui/input';
import {Button} from '@/components/ui/button';
import {updateOrganization,addBranch} from './actions';
export function logoUrl(path:string|null){return path?`${process.env.NEXT_PUBLIC_SUPABASE_URL}/storage/v1/object/public/organization-logos/${path}`:null;}
export async function OrganizationPanel({org}:{org:string}){
 const {db,membership}=await requireOrganization(org);const admin=membership.role==='org_admin';
 const [{data:company,error:ce},{data:branches,error:be},{data:jobs,error:je},{data:members,error:me}]=await Promise.all([db.from('organizations').select('*').eq('id',org).single(),db.from('branches').select('*').eq('organization_id',org),db.from('jobs').select('id,title,status').eq('organization_id',org).order('created_at',{ascending:false}),db.rpc('list_org_members',{org})]);
 if(ce||be||je||me)throw new Error('Không tải được dữ liệu doanh nghiệp.');
 const logo=logoUrl(company.logo_path);
 return <section className="space-y-7 rounded-xl border border-border p-5">
 {logo&&<Image src={logo} alt={`Logo ${company.name}`} width={72} height={72} unoptimized className="rounded-lg object-contain"/>}
 <p>Trạng thái xác minh: {company.verification_status==='verified'?'Đã được kiểm tra':company.verification_status==='pending'?'Chờ kiểm tra':company.verification_status==='suspended'?'Tạm đình chỉ':'Chưa được chấp thuận'}</p>
 <p>MST: {company.tax_id??'Chưa cung cấp'} · Địa chỉ: {company.address??'Chưa cung cấp'}</p>
 {admin&&<><ActionForm action={updateOrganization}><input type="hidden" name="org" value={org}/><label className="block">Tên doanh nghiệp<Input name="name" required maxLength={200} defaultValue={company.name}/></label><label className="block">MST<Input name="tax_id" required maxLength={30} defaultValue={company.tax_id??''}/></label><label className="block">Địa chỉ<Input name="address" required maxLength={500} defaultValue={company.address??''}/></label><Button>Lưu doanh nghiệp</Button></ActionForm>
 <p className="text-sm text-muted-foreground">Badge chỉ cấp sau khi người có quyền xác minh kiểm tra. Nhập MST không tự tạo badge.</p>
 <form action="/api/organization/logo" method="post" encType="multipart/form-data" className="space-y-3"><input type="hidden" name="org" value={org}/><label className="block">Logo (PNG/JPEG/WebP, tối đa 2 MB; ảnh được công khai)<Input name="file" type="file" accept="image/png,image/jpeg,image/webp" required/></label><Button variant="outline">Upload logo</Button></form></>}
 <h3 className="font-bold">Chi nhánh và khu vực tuyển dụng</h3>{!branches?.length&&<p>Chưa có chi nhánh.</p>}{branches?.map(b=><p key={b.id}>{b.name}: {b.address}, {b.district}, {b.province}</p>)}
 {admin&&<ActionForm action={addBranch}><input type="hidden" name="org" value={org}/>{[['name','Tên chi nhánh'],['address','Địa chỉ chi nhánh'],['province','Tỉnh / thành phố'],['district','Quận / huyện']].map(([key,label])=><label className="block" key={key}>{label}<Input name={key} required maxLength={key==='address'?500:100}/></label>)}<Button variant="outline">Thêm chi nhánh</Button></ActionForm>}
 {admin&&<><h3 className="font-bold">Người quản lý và thành viên</h3>{members?.map((m:{user_id:string;role:string;display_name:string})=><p key={m.user_id}>{m.display_name} · {m.role} · {m.user_id}</p>)}</>}
 <div className="flex flex-wrap items-center justify-between gap-3"><h3 className="font-bold">Tin tuyển dụng</h3><Link href={`/organization/${org}/applicants`} className="text-primary underline">Hồ sơ ứng tuyển</Link><Button asChild><Link href={`/organization/${org}/jobs/new`}>Tạo Job</Link></Button></div>
 {!jobs?.length&&<p>Chưa có tin tuyển dụng.</p>}{jobs?.map(j=><p key={j.id}><Link className="text-primary underline" href={`/organization/${org}/jobs/${j.id}`}>{j.title}</Link> · {j.status}</p>)}
 </section>;
}
