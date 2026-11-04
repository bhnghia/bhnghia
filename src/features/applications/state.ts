export const labels={submitted:'Đã nộp Profile Card',test_pending:'Cần làm Micro-test',test_submitted:'Đã nộp test, chờ chấm',under_review:'Đang xét duyệt',interview_invited:'Được mời phỏng vấn',rejected:'Không được chọn'} as const;
export type ApplicationStatus=keyof typeof labels;
export function allowedTargets(status:ApplicationStatus,actor:'hr'|'candidate'|'test_processor'):ApplicationStatus[]{
 if(actor==='hr')return status==='submitted'?['under_review']:status==='under_review'?['interview_invited','rejected']:[];
 if(actor==='test_processor')return status==='test_pending'?['test_submitted']:status==='test_submitted'?['under_review']:[];
 return [];
}
