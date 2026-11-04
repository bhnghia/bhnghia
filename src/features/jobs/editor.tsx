import Link from 'next/link';
import {ActionForm} from '@/components/action-form';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {saveJob,transitionJob} from './actions';
import {wageAdvisory,type JobInput,type WageRule} from './schema';
type Branch={id:string;name:string;district:string;province:string;region_code:string|null};
export function JobEditor({org,id,initial,status,branches,rules}:{org:string;id?:string;initial?:JobInput;status?:string;branches:Branch[];rules:WageRule[]}){
 const j=initial;const branch=branches.find(b=>b.id===j?.branch_id);
 return <div className="space-y-7"><h1 className="text-2xl font-bold">{id?'Chỉnh sửa tin tuyển dụng':'Tạo tin tuyển dụng'}</h1>{status&&<p>Trạng thái: {status}</p>}
 <p className="text-sm text-muted-foreground">Lưu nháp có thể chưa đầy đủ. Xuất bản cần doanh nghiệp được kiểm tra và các trường bắt buộc hoàn chỉnh. Tin đang công khai cần tạm dừng trước khi sửa.</p>
 <ActionForm action={saveJob}><input type="hidden" name="org" value={org}/><input type="hidden" name="job" value={id??''}/>
 <div className="grid gap-5 md:grid-cols-2"><label>Vị trí tuyển dụng<Input name="title" required maxLength={200} defaultValue={j?.title}/></label><label>Ngành nghề<Input name="industry" maxLength={100} defaultValue={j?.industry}/></label>
 <label>Chi nhánh<select className="block w-full rounded border bg-surface p-3" name="branch_id" defaultValue={j?.branch_id??''}><option value="">Chọn chi nhánh</option>{branches.map(b=><option value={b.id} key={b.id}>{b.name} · {b.district}, {b.province}</option>)}</select></label>
 <label>Hình thức<select className="block w-full rounded border bg-surface p-3" name="work_mode" defaultValue={j?.work_mode??'onsite'}><option value="onsite">Tại nơi làm việc</option><option value="remote">Từ xa</option><option value="hybrid">Kết hợp</option></select></label>
 <label>Lương tối thiểu (VND)<Input name="salary_min" type="number" min={0} max={1e12} step="any" defaultValue={j?.salary_min??''}/></label><label>Lương tối đa (VND)<Input name="salary_max" type="number" min={0} max={1e12} step="any" defaultValue={j?.salary_max??''}/></label>
 <label>Đơn vị<select name="salary_unit" className="block w-full rounded border bg-surface p-3" defaultValue={j?.salary_unit??'month'}><option value="hour">Giờ</option><option value="shift">Ca</option><option value="month">Tháng</option></select></label><label>Cơ sở lương<select name="salary_basis" className="block w-full rounded border bg-surface p-3" defaultValue={j?.salary_basis??'gross'}><option value="gross">Gross</option><option value="net">Net</option></select></label></div>
 <label className="block">Top 3 kỹ năng (phân cách bằng dấu phẩy)<Input name="skills" defaultValue={j?.skills.join(', ')}/></label>
 {([['description','JD chi tiết'],['requirements','Yêu cầu'],['benefits','Quyền lợi']] as const).map(([key,label])=><label key={key} className="block">{label}<textarea className="block min-h-32 w-full rounded border bg-surface p-3" name={key} maxLength={key==='description'?20000:10000} defaultValue={j?.[key]}/></label>)}
 <label className="block"><input type="checkbox" name="safety_commitment" defaultChecked={j?.safety_commitment}/> Cam kết không thu phí ứng viên, không giữ giấy tờ gốc; địa điểm và thông tin tuyển dụng trung thực.</label>
 <label className="block"><input type="checkbox" name="test_enabled" defaultChecked={j?.test_enabled}/> Có Micro-test (cần ngân hàng ít nhất 10 câu trắc nghiệm)</label><label className="block">Số câu ngắn (0–3)<Input type="number" name="test_written_count" min={0} max={3} defaultValue={j?.test_written_count??0}/></label><p className="text-sm">Cấu trúc dự kiến: 3 câu trắc nghiệm tình huống, câu ngắn tối đa 300 ký tự; thời gian sẽ hiển thị trước khi làm bài.</p>
 <Button>Lưu nháp</Button></ActionForm>
 {id&&<Link className="block text-primary underline" href={`/organization/${org}/jobs/${id}/test`}>Ngân hàng câu hỏi và cấu hình Micro-test</Link>}<aside className="rounded-xl border border-border p-4"><h2 className="font-bold">Tham chiếu lương vùng của bản đã lưu</h2><p>{wageAdvisory({salary_min:j?.salary_min??null,salary_unit:j?.salary_unit??'month',salary_basis:j?.salary_basis??'gross'},branch?.region_code??null,rules,new Date().toLocaleDateString('en-CA',{timeZone:'Asia/Ho_Chi_Minh'}))}</p></aside>
 {id&&<div className="flex flex-wrap gap-4">{[['published','Xuất bản'],['paused','Tạm dừng để sửa'],['closed','Đóng Job']].map(([target,label])=><ActionForm key={target} action={transitionJob}><input type="hidden" name="org" value={org}/><input type="hidden" name="job" value={id}/><input type="hidden" name="target" value={target}/><Button variant="outline">{label}</Button></ActionForm>)}</div>}</div>;
}
