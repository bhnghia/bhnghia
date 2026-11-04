import Link from 'next/link';
import {SiteHeader} from '@/components/site-header';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {ViewFeedback} from '@/components/view-feedback';
import {loadPublicJobs} from '@/features/jobs/public-data';
import {filterJobs} from '@/features/jobs/filter';
import {JobCard} from '@/features/jobs/card';
export default async function Page({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const raw=await searchParams;const value=(key:string)=>typeof raw[key]==='string'?raw[key] as string:undefined;
 const f={industry:value('industry'),skill:value('skill'),area:value('area'),minimum:value('minimum'),unit:value('unit'),mode:value('mode')};
 const jobs=filterJobs(await loadPublicJobs(),f);
 return <><SiteHeader/><main className="mx-auto max-w-6xl space-y-7 px-5 py-10"><div className="flex flex-wrap items-center justify-between gap-4"><h1 className="text-3xl font-bold">Khám phá việc làm</h1><Link className="text-primary underline" href="/jobs/saved">Việc đã lưu riêng tư</Link></div>
 <details className="sticky top-3 z-10 rounded-2xl border border-border bg-surface p-4 shadow-lg" open><summary className="cursor-pointer font-bold">Bộ lọc việc làm</summary><form className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4" action="/jobs"><label>Ngành<Input name="industry" defaultValue={f.industry}/></label><label>Kỹ năng<Input name="skill" defaultValue={f.skill}/></label><label>Quận/huyện, tỉnh/TP<Input name="area" defaultValue={f.area}/></label><label>Hình thức<select name="mode" defaultValue={f.mode??''} className="block w-full rounded border bg-surface p-3"><option value="">Tất cả</option><option value="onsite">Tại nơi làm việc</option><option value="remote">Từ xa</option><option value="hybrid">Kết hợp</option></select></label><label>Lương mong muốn từ (VND)<Input type="number" min="0" name="minimum" defaultValue={f.minimum}/></label><label>Đơn vị lương<select name="unit" defaultValue={f.unit??'month'} className="block w-full rounded border bg-surface p-3"><option value="hour">Giờ</option><option value="shift">Ca</option><option value="month">Tháng</option></select></label><div className="flex items-end gap-3"><Button>Lọc việc</Button><Link href="/jobs" className="p-3 text-primary underline">Xóa lọc</Link></div></form></details>
 {!jobs.length?<ViewFeedback state="empty" title="Chưa tìm thấy việc phù hợp" description="Thử đổi bộ lọc hoặc quay lại sau."/>:<div className="grid gap-5 lg:grid-cols-2">{jobs.map(j=><JobCard key={j.id} job={j}/>)}</div>}</main></>;
}
