import Link from "next/link";
import { Sprout } from "lucide-react";
import { ThemeToggle } from "@/components/theme-toggle";

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return <main className="min-h-screen"><header className="mx-auto flex max-w-6xl items-center justify-between px-5 py-5 sm:px-8"><Link href="/" className="flex items-center gap-2 text-lg font-black"><Sprout size={24} className="text-primary" /> V.E.T.T</Link><ThemeToggle /></header><div className="mx-auto grid max-w-6xl gap-10 px-5 py-10 sm:px-8 lg:grid-cols-2 lg:items-center lg:py-20"><div className="hidden lg:block"><p className="text-sm font-bold uppercase tracking-widest text-primary">Không gian nghề nghiệp</p><h2 className="mt-5 max-w-md text-5xl font-black leading-tight">Bước tiếp theo bắt đầu từ đây.</h2><p className="mt-5 max-w-md text-lg leading-8 text-muted-foreground">Năng lực, cơ hội và sự tin cậy cùng hiện diện trong một trải nghiệm rõ ràng.</p></div><div className="flex justify-center lg:justify-end">{children}</div></div></main>;
}
