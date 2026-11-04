"use client";

import { ViewFeedback } from "@/components/view-feedback";
import { Button } from "@/components/ui/button";

export default function ErrorPage({ reset }: { error: Error & { digest?: string }; reset: () => void }) { return <main className="mx-auto max-w-6xl space-y-5 px-5 py-16"><ViewFeedback state="error" /><Button onClick={reset}>Thử lại</Button></main>; }
