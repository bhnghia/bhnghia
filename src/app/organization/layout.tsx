import {requireUser} from '@/features/auth/guards';
import { WorkspaceShell } from "@/components/workspace-shell";

export default async function OrganizationLayout({ children }: { children: React.ReactNode }) { await requireUser(); return <WorkspaceShell audience="organization">{children}</WorkspaceShell>; }
