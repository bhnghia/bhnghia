import Link from "next/link";
import { ArrowLeft, BriefcaseBusiness, UserRound } from "lucide-react";
import { ThemeToggle } from "@/components/theme-toggle";


export function WorkspaceShell({ audience, children }: { audience: "candidate" | "organization"; children: React.ReactNode }) {
  const candidate = audience === "candidate";
  return <div className="min-h-screen bg-background"><header className="border-b border-border bg-surface"><div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-5 py-4 sm:px-8"><Link href="/" className="text-lg font-black">V.E.T.T</Link><nav aria-label="Khu vực làm việc" className="flex items-center gap-2"><Link href="/safety">An toàn</Link><Link href="/community">Cộng đồng</Link><Link href="/notifications" className="rounded-lg px-3 py-2 text-sm font-medium hover:bg-muted">Thông báo</Link><Link href={candidate ? "/organization" : "/candidate"} className="rounded-lg px-3 py-2 text-sm font-medium hover:bg-muted">{candidate ? "Doanh nghiệp" : "Ứng viên"}</Link><ThemeToggle /></nav></div></header><main className="mx-auto max-w-6xl px-5 py-10 sm:px-8"><Link href="/" className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-primary"><ArrowLeft size={16} /> Trang chủ</Link><div className="mt-8 flex items-start gap-4"><div className="rounded-xl bg-muted p-3 text-primary">{candidate ? <UserRound size={25} /> : <BriefcaseBusiness size={25} />}</div><div><p className="text-sm font-semibold text-primary">Khu vực {candidate ? "ứng viên" : "doanh nghiệp"}</p><h1 className="mt-1 text-3xl font-bold tracking-tight">{candidate ? "Không gian của bạn" : "Không gian doanh nghiệp"}</h1></div></div><div className="mt-8">{children}</div></main></div>;
}
