import type {PublicJob} from './schema';
export type JobFilters={industry?:string;skill?:string;area?:string;minimum?:string;unit?:string;mode?:string};
export function filterJobs(jobs:PublicJob[],f:JobFilters){
 const includes=(value:string,search?:string)=>!search||value.toLocaleLowerCase('vi').includes(search.trim().toLocaleLowerCase('vi'));
 const minimum=f.minimum?Number(f.minimum):null;
 return jobs.filter(j=>includes(j.industry,f.industry)&&(!f.skill||j.skills.some(s=>includes(s,f.skill)))&&includes(`${j.district} ${j.province}`,f.area)&&(!f.mode||j.work_mode===f.mode)&&(minimum===null||Number.isFinite(minimum)&&minimum>=0&&j.salary_unit===f.unit&&j.salary_max!==null&&j.salary_max>=minimum));
}
