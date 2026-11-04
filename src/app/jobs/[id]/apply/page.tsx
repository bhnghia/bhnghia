import Link from 'next/link';
import {notFound} from 'next/navigation';
import {requireUser} from '@/features/auth/guards';
import {loadPublicJobs} from '@/features/jobs/public-data';
import {ActionForm} from '@/components/action-form';
import {Button} from '@/components/ui/button';
import {applyJob} from '@/features/jobs/actions';
import {profileSchema,publicCard} from '@/features/profile/schema';
import {ProfileCard} from '@/features/profile/card';
export default async function Page({params}:{params:Promise<{id:string}>}){const {id}=await params;const {db,user}=await requireUser();const job=(await loadPublicJobs()).find(j=>j.id===id);if(!job)notFound();const {data,error}=await db.from('candidate_profiles').select('*').eq('user_id',user.id).maybeSingle();if(error)throw new Error('Không tải được hồ sơ.');const parsed=profileSchema.safeParse(data);return <main className="mx-auto max-w-2xl space-y-5 px-5 py-10"><h1 className="text-2xl font-bold">Ứng tuyển: {job.title}</h1>{!parsed.success?<Link href="/candidate" className="text-primary underline">Hoàn thiện hồ sơ trước khi ứng tuyển</Link>:<><ProfileCard profile={publicCard(parsed.data)}/><ActionForm action={applyJob}><input type="hidden" name="job" value={id}/><label className="block"><input type="checkbox" name="confirm" required/> Tôi đồng ý gửi Profile Card này tới {job.company_name} cho tin tuyển dụng trên. Không gửi CV gốc.</label><Button>Gửi ứng tuyển</Button></ActionForm></>}</main>;}
