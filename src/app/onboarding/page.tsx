import {requireUser} from '@/features/auth/guards';
import {onboard,signOut} from '@/features/auth/actions';
import {Button} from '@/components/ui/button';
export default async function Page(){await requireUser();return <main className="mx-auto max-w-lg space-y-6 p-8"><h1 className="text-3xl font-bold">Bạn muốn bắt đầu với vai trò nào?</h1><form action={onboard} className="flex flex-wrap gap-4"><Button name="persona" value="candidate">Ứng viên</Button><Button name="persona" value="recruiter">Nhà tuyển dụng</Button></form><form action={signOut}><Button variant="outline">Đăng xuất</Button></form></main>;}
