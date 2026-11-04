import { PasswordForm } from '@/features/auth/password-form';
import { requireUser } from '@/features/auth/guards';
export default async function Page(){await requireUser();return <PasswordForm mode="reset"/>;}
