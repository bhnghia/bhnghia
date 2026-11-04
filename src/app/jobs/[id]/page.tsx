import {notFound} from 'next/navigation';
import {SiteHeader} from '@/components/site-header';
import {JobCard} from '@/features/jobs/card';
import {loadPublicJobs} from '@/features/jobs/public-data';
export default async function Page({params}:{params:Promise<{id:string}>}){const {id}=await params;const job=(await loadPublicJobs()).find(j=>j.id===id);if(!job)notFound();return <><SiteHeader/><main className="mx-auto max-w-3xl px-5 py-10"><h1 className="mb-5 text-2xl font-bold">Chi tiết việc làm</h1><JobCard job={job}/></main></>;}
