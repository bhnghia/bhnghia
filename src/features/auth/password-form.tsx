'use client';
import {useState} from 'react';
import {passwordAction} from './actions';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
export function PasswordForm({mode}:{mode:'forgot'|'reset'}) {
 const [message,setMessage]=useState(''); const [pending,setPending]=useState(false);
 return <form className="mx-auto max-w-md space-y-5 p-6" onSubmit={async e=>{e.preventDefault();const form=new FormData(e.currentTarget);setPending(true);try{setMessage(await passwordAction(mode,String(form.get('value'))));}catch{setMessage('Không thể thực hiện. Vui lòng thử lại.');}finally{setPending(false);}}}>
 <h1 className="text-2xl font-bold">{mode==='forgot'?'Quên mật khẩu':'Đổi mật khẩu'}</h1><label htmlFor="value">{mode==='forgot'?'Email':'Mật khẩu mới'}</label><Input id="value" name="value" type={mode==='forgot'?'email':'password'} required autoComplete={mode==='forgot'?'email':'new-password'} /><Button disabled={pending}>Tiếp tục</Button><p role="status">{message}</p></form>;
}
