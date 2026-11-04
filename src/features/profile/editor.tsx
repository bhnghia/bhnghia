'use client';
import {useState} from 'react';
import {useForm,useWatch} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {z} from 'zod';
import {profileSchema,publicCard,type CandidateProfile} from './schema';
import {saveProfile} from './actions';
import {ProfileCard} from './card';
import {Input} from '@/components/ui/input';
import {Button} from '@/components/ui/button';
const editorSchema=profileSchema.extend({discoverable:z.boolean(),avatar_visible:z.boolean()});
const defaults:CandidateProfile={full_name:'',display_name:'',school:'',study_year:'',district:'',province:'',desired_position:'',work_mode:'onsite',salary:0,salary_unit:'month',skills:[],bio:'',discoverable:false,avatar_visible:false};
export function ProfileEditor({initial}:{initial:CandidateProfile|null}){
 const [message,setMessage]=useState('');const [confirmed,setConfirmed]=useState(false);
 const {register,control,setValue,handleSubmit,formState:{errors,isSubmitting}}=useForm<CandidateProfile>({resolver:zodResolver(editorSchema),defaultValues:initial??defaults});
 const values=useWatch({control}) as CandidateProfile;
 const fields=[['full_name','Họ tên (chỉ bạn xem)'],['display_name','Tên hiển thị'],['school','Trường học (tùy chọn)'],['study_year','Năm học (tùy chọn)'],['district','Quận / huyện'],['province','Tỉnh / thành phố'],['desired_position','Vị trí mong muốn']] as const;
 return <div className="grid gap-8 lg:grid-cols-2"><form className="space-y-4" onChange={e=>{if((e.target as HTMLInputElement).name!=="confirmation")setConfirmed(false);}} onSubmit={handleSubmit(async input=>{try{const result=await saveProfile(input,confirmed);setMessage(result.error??'Đã lưu hồ sơ.');}catch{setMessage('Không thể kết nối. Vui lòng thử lại.');}})}>
 {fields.map(([key,label])=><div key={key}><label htmlFor={key}>{label}</label><Input id={key} {...register(key)}/></div>)}
 <label className="block">Hình thức làm việc<select className="block w-full rounded border p-2 bg-surface" {...register('work_mode')}><option value="onsite">Tại nơi làm việc</option><option value="remote">Từ xa</option><option value="hybrid">Kết hợp</option></select></label>
 <label className="block">Lương mong muốn (VND)<Input type="number" min="0" {...register('salary',{valueAsNumber:true})}/></label>
 <label className="block">Đơn vị lương<select className="block w-full rounded border p-2 bg-surface" {...register('salary_unit')}><option value="hour">Giờ</option><option value="shift">Ca</option><option value="month">Tháng</option></select></label>
 <label className="block">3–5 kỹ năng, phân cách bằng dấu phẩy<Input defaultValue={initial?.skills.join(', ')??''} onChange={e=>setValue('skills',e.target.value.split(',').map(s=>s.trim()).filter(Boolean),{shouldValidate:true})}/></label>
 <label className="block">Bio (tối đa 30 từ)<textarea className="block w-full rounded border bg-surface p-3" {...register('bio')}/></label>
 <label className="block"><input type="checkbox" {...register('avatar_visible')}/> Hiện ảnh đại diện chữ cái trên card</label>
 <label className="block"><input type="checkbox" {...register('discoverable')}/> Cho phép HR tìm thấy hồ sơ</label>
 <p className="text-sm text-muted-foreground">Họ tên đầy đủ và CV không nằm trên card. Điểm Micro-test không được hiển thị.</p>
 {Object.values(errors).length>0&&<p role="alert">Kiểm tra trường bắt buộc, 3–5 kỹ năng khác nhau và bio tối đa 30 từ.</p>}
 <label className="block"><input type="checkbox" name="confirmation" checked={confirmed} onChange={e=>setConfirmed(e.target.checked)} onClick={e=>e.stopPropagation()}/> Tôi đã xem và xác nhận thông tin trên card trước khi lưu.</label>
 <Button disabled={isSubmitting||!confirmed}>Lưu hồ sơ</Button><p role="status">{message}</p></form><section className="space-y-4"><h2 className="font-bold">Xem trước Profile Card</h2><ProfileCard profile={publicCard(values)}/><p>{values.discoverable?'HR có thể tìm thấy sau khi lưu.':'HR chưa được phép tìm thấy hồ sơ.'}</p><form action="/api/candidate/cv" method="post" encType="multipart/form-data" className="space-y-3 rounded-xl border border-border p-5"><h3 className="font-bold">CV riêng tư</h3><p className="text-sm">Tải PDF tối đa 5 MB. Chỉ bạn được đọc file; không tự gửi cho HR hoặc AI.</p><Input name="file" type="file" accept="application/pdf" required/><Button variant="outline">Upload CV</Button></form></section></div>;
}
