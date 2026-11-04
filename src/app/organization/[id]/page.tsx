import Link from 'next/link';
import {OrganizationPanel} from '@/features/organizations/panel';
import {requireOrganization} from '@/features/auth/guards';
import {membershipAction} from '@/features/auth/actions';
import {Button} from '@/components/ui/button';
export default async function Page({params}:{params:Promise<{id:string}>}){
 const {id}=await params;const {db,membership}=await requireOrganization(id);
 const {data}=await db.from('organizations').select('name').eq('id',id).single();
 const {data:requests,error}=membership.role==='org_admin'?await db.from('organization_join_requests').select('user_id').eq('organization_id',id):{data:[],error:null};
 if(error)throw new Error('Không tải được yêu cầu tham gia.');
 return <div className="space-y-5"><h2 className="text-2xl font-bold">{data?.name}</h2><p>Vai trò: {membership.role}</p><nav className="flex flex-wrap gap-5"><Link href={`/organization/${id}/dashboard`}>Dashboard tuyển dụng</Link><Link href={`/organization/${id}/sourcing`}>Tìm ứng viên</Link></nav><OrganizationPanel org={id}/>{membership.role==='org_admin'&&<><h3>Yêu cầu tham gia</h3>{!requests?.length&&<p>Chưa có yêu cầu.</p>}{requests?.map(r=><form key={r.user_id} action={membershipAction} className="flex flex-wrap gap-3"><input type="hidden" name="org" value={id}/><input type="hidden" name="member" value={r.user_id}/><span>{r.user_id}</span><Button name="operation" value="approve">Duyệt</Button><Button name="operation" value="reject" variant="outline">Từ chối</Button></form>)}<form action={membershipAction} className="space-y-3"><input type="hidden" name="org" value={id}/><label htmlFor="member">Mã thành viên cần thu hồi quyền recruiter</label><input id="member" name="member" required className="rounded border p-2 text-foreground bg-surface"/><Button name="operation" value="revoke">Thu hồi</Button></form></>}</div>;
}
