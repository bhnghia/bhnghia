export function canAccessOrganization(userId: string | undefined, membership: {user_id:string;organization_id:string;role:string}|null, orgId:string, adminOnly=false) {
  return !!userId && membership?.user_id===userId && membership.organization_id===orgId && (!adminOnly || membership.role==='org_admin');
}
