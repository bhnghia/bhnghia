"use client";

import Link from "next/link";
import { authenticate } from "./actions";
import { zodResolver } from "@hookform/resolvers/zod";
import { ArrowRight } from "lucide-react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const schema = z.object({ email: z.email("Nhập địa chỉ email hợp lệ."), password: z.string().min(8, "Mật khẩu cần ít nhất 8 ký tự.") });
type FormValues = z.infer<typeof schema>;

export function AuthForm({ mode }: { mode: "login" | "register" }) {
  const { register, handleSubmit, formState: { errors, isSubmitted, isSubmitting }, setError } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: { email: "", password: "" } });
  const isRegister = mode === "register";

  async function onSubmit(values: FormValues) {
    try { const message=await authenticate(mode,values); setError("root",{message}); }
    catch (error) { if (error instanceof Error && error.message.includes('NEXT_REDIRECT')) throw error; setError("root",{message:"Không thể kết nối xác thực. Vui lòng thử lại."}); }
  }

  return <div className="w-full max-w-md rounded-2xl border border-border bg-surface p-6 shadow-lg shadow-primary/5 sm:p-9"><p className="text-sm font-semibold text-primary">V.E.T.T / Tài khoản</p><h1 className="mt-3 text-3xl font-bold tracking-tight">{isRegister ? "Tạo tài khoản" : "Chào mừng trở lại"}</h1><p className="mt-3 leading-7 text-muted-foreground">{isRegister ? "Bắt đầu hành trình nghề nghiệp với quyền kiểm soát dữ liệu của bạn." : "Đăng nhập để tiếp tục hành trình của bạn."}</p><form onSubmit={handleSubmit(onSubmit)} noValidate className="mt-7 space-y-5"><div className="space-y-2"><Label htmlFor="email">Email</Label><Input id="email" type="email" autoComplete="email" placeholder="ban@example.com" aria-invalid={!!errors.email} aria-describedby={errors.email ? "email-error" : undefined} {...register("email")} />{errors.email && <p id="email-error" className="text-sm text-red-700 dark:text-red-300">{errors.email.message}</p>}</div><div className="space-y-2"><Label htmlFor="password">Mật khẩu</Label><Input id="password" type="password" autoComplete={isRegister ? "new-password" : "current-password"} placeholder="Ít nhất 8 ký tự" aria-invalid={!!errors.password} aria-describedby={errors.password ? "password-error" : undefined} {...register("password")} />{errors.password && <p id="password-error" className="text-sm text-red-700 dark:text-red-300">{errors.password.message}</p>}</div>{isSubmitted && errors.root && <p role="alert" className="rounded-lg border border-red-300 bg-red-50 p-3 text-sm text-red-800">{errors.root.message}</p>}<Button className="w-full" type="submit" disabled={isSubmitting}>{isRegister ? "Tiếp tục" : "Đăng nhập"}<ArrowRight size={17} /></Button></form><Link href="/forgot-password" className="mt-4 block text-sm text-primary">Quên mật khẩu?</Link><p className="mt-7 text-center text-sm text-muted-foreground">{isRegister ? "Đã có tài khoản?" : "Chưa có tài khoản?"} <Link href={isRegister ? "/login" : "/register"} className="font-semibold text-primary underline-offset-4 hover:underline">{isRegister ? "Đăng nhập" : "Đăng ký"}</Link></p></div>;
}
