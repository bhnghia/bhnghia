import Link from "next/link";
import { ArrowUpRight, Sprout } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/theme-toggle";

export function SiteHeader() {
  return <header className="border-b border-border bg-surface/90"><div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-5 py-4 sm:px-8"><Link href="/" className="flex items-center gap-2 text-lg font-black tracking-tight" aria-label="V.E.T.T - Trang chủ"><span className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary text-primary-foreground"><Sprout size={20} /></span>V.E.T.T</Link><nav aria-label="Điều hướng chính" className="flex items-center gap-1 sm:gap-3"><Link href="/jobs" className="rounded-lg px-2 py-2 text-sm font-semibold">Việc làm</Link><ThemeToggle /><Button asChild variant="ghost" size="sm" className="hidden sm:inline-flex"><Link href="/login">Đăng nhập</Link></Button><Button asChild size="sm"><Link href="/register">Bắt đầu <ArrowUpRight size={16} /></Link></Button></nav></div></header>;
}
