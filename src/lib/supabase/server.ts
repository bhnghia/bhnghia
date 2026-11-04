import 'server-only';
import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
export async function supabase() {
  const store = await cookies();
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error('Cần cấu hình Supabase trong môi trường.');
  return createServerClient(url, key, { cookies: {
    getAll: () => store.getAll(),
    setAll: (items) => { try { items.forEach(({name,value,options}) => store.set(name,value,options)); } catch { /* Server Component: proxy refreshes session. */ } },
  }});
}
