import {requireUser} from '@/features/auth/guards';
import {SiteHeader} from '@/components/site-header';
import {JobCard} from '@/features/jobs/card';
import {loadPublicJobs} from '@/features/jobs/public-data';
import {ActionForm} from '@/components/action-form';
import {Button} from '@/components/ui/button';
import {saveBookmark} from '@/features/jobs/actions';
export default async function Page(){const {db,user}=await requireUser();const {data,error}=await db.from('saved_jobs').select('job_id').eq('candidate_id',user.id).order('created_at',{ascending:false});if(error)throw new Error('Không tải được việc đã lưu.');const jobs=await loadPublicJobs();return <><SiteHeader/><main className="mx-auto max-w-3xl space-y-5 px-5 py-10"><h1 className="text-2xl font-bold">Việc đã lưu riêng tư</h1><p>Chỉ bạn xem danh sách này. Thao tác lưu không thông báo cho doanh nghiệp.</p>{!data?.length&&<p>Bạn chưa lưu việc nào.</p>}{data?.map(s=>{const job=jobs.find(j=>j.id===s.job_id);return job?<JobCard key={job.id} job={job} saved/>:<ActionForm key={s.job_id} action={saveBookmark}><p>Tin đã ngừng công khai.</p><input type="hidden" name="job" value={s.job_id}/><input type="hidden" name="saved" value="false"/><Button variant="outline">Bỏ lưu</Button></ActionForm>;})}</main></>;}
