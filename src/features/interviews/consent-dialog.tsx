'use client';
import {useRef,type ReactNode} from 'react';
import {Button} from '@/components/ui/button';
export function ConsentDialog({children}:{children:ReactNode}){const ref=useRef<HTMLDialogElement>(null);return <><Button onClick={()=>ref.current?.showModal()}>Xác nhận lịch và quyết định CV</Button><dialog ref={ref} aria-label="Quyết định chia sẻ CV" className="m-auto max-h-[90vh] w-full max-w-xl overflow-y-auto rounded-xl border bg-surface p-6 text-foreground backdrop:bg-black/40"><Button variant="outline" onClick={()=>ref.current?.close()}>Đóng</Button>{children}</dialog></>;}
