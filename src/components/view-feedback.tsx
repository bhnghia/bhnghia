import { AlertCircle, Inbox, LoaderCircle } from "lucide-react";
import type { ViewState } from "@/types/ui";

const content = {
  loading: { icon: LoaderCircle, title: "Đang tải dữ liệu", description: "Vui lòng chờ trong giây lát." },
  empty: { icon: Inbox, title: "Chưa có nội dung", description: "Nội dung sẽ xuất hiện tại đây khi được tạo." },
  error: { icon: AlertCircle, title: "Không thể tải dữ liệu", description: "Vui lòng thử lại sau." },
};

export function ViewFeedback({ state, title, description }: { state: Exclude<ViewState, "ready">; title?: string; description?: string }) {
  const item = content[state];
  const Icon = item.icon;
  return <div role={state === "error" ? "alert" : "status"} aria-live="polite" className="flex min-h-48 flex-col items-center justify-center rounded-2xl border border-dashed border-border bg-surface p-8 text-center"><Icon className={state === "loading" ? "mb-4 animate-spin text-primary" : "mb-4 text-primary"} size={30} /><h2 className="text-lg font-semibold">{title ?? item.title}</h2><p className="mt-2 max-w-md text-sm text-muted-foreground">{description ?? item.description}</p></div>;
}
