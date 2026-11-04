import {requireOrganization} from '@/features/auth/guards';
import {JobEditor} from '@/features/jobs/editor';
export default async function Page({params}:{params:Promise<{id:string}>}){const {id}=await params;const {db}=await requireOrganization(id);const {data,error}=await db.from('branches').select('*').eq('organization_id',id);if(error)throw new Error('Không tải được chi nhánh.');return <JobEditor org={id} branches={data??[]} rules={[]}/>;}
