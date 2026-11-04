import {notFound} from 'next/navigation';
import {requireUser} from '@/features/auth/guards';
import {ProfileCard} from '@/features/profile/card';
import {profileSchema,publicCard} from '@/features/profile/schema';
export default async function Page({params}:{params:Promise<{id:string}>}){const {id}=await params;const {db}=await requireUser();const {data,error}=await db.rpc('read_candidate_card',{candidate:id});if(error||!data)notFound();const parsed=profileSchema.safeParse({...data,full_name:'Ẩn',discoverable:true});if(!parsed.success)notFound();return <ProfileCard profile={publicCard(parsed.data)}/>;}
