import Link from 'next/link';
export function pageNumber(value?:string){const n=Number(value);return Number.isSafeInteger(n)&&n>0&&n<=100000?n:1;}
export function Pagination({page,total,base,query={}}:{page:number;total:number;base:string;query?:Record<string,string>}){const url=(n:number)=>`${base}?${new URLSearchParams({...query,page:String(n)})}`;return <nav aria-label="Phân trang" className="flex flex-wrap gap-5 py-4">{page>1&&<Link href={url(page-1)}>Trang trước</Link>}<span>Trang {page} · {total} kết quả</span>{page*20<total&&<Link href={url(page+1)}>Trang sau</Link>}</nav>;}
