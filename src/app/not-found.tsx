import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function NotFound() { return <main className="mx-auto flex min-h-screen max-w-lg flex-col items-center justify-center px-5 text-center"><p className="text-sm font-bold text-primary">404</p><h1 className="mt-3 text-3xl font-bold">Không tìm thấy trang</h1><p className="mt-3 text-muted-foreground">Đường dẫn này không tồn tại hoặc đã được thay đổi.</p><Button asChild className="mt-7"><Link href="/">Về trang chủ</Link></Button></main>; }
