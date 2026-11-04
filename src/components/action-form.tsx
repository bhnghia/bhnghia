'use client';
import {useState} from 'react';
import {unstable_rethrow,useRouter} from 'next/navigation';
export type FormResult={error?:string;message?:string;href?:string};
export function ActionForm({action,children,className}:{action:(form:FormData)=>Promise<FormResult>;children:React.ReactNode;className?:string}){
 const [pending,setPending]=useState(false);const [message,setMessage]=useState('');const router=useRouter();
 return <form className={className??'space-y-4'} onSubmit={async e=>{e.preventDefault();const data=new FormData(e.currentTarget);setPending(true);try{const r=await action(data);setMessage(r.error??r.message??'Đã lưu.');if(r.href)router.push(r.href);router.refresh();}catch(error){unstable_rethrow(error);setMessage('Không thể thực hiện. Vui lòng thử lại.');}finally{setPending(false);}}}><fieldset disabled={pending} className="space-y-4">{children}</fieldset><p role="status" className="text-sm">{pending?'Đang xử lý…':message}</p></form>;
}
