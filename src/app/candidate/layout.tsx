import {requireUser} from '@/features/auth/guards';
import { WorkspaceShell } from "@/components/workspace-shell";

export default async function CandidateLayout({ children }: { children: React.ReactNode }) { await requireUser(); return <WorkspaceShell audience="candidate">{children}</WorkspaceShell>; }
