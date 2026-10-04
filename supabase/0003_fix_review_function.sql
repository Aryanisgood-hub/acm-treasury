-- =====================================================================
-- Migration 0003: fix budget approval
-- Supabase's API session blocks any UPDATE without a WHERE clause, even
-- inside a database function. The settings update in review_budget_request()
-- had no WHERE, so approving failed. This recreates it with "where id = true".
-- Run in Supabase SQL Editor (new query tab).
-- =====================================================================

create or replace function public.review_budget_request(p_id uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
declare r public.budget_requests; m public.members; b bigint;
begin
  select * into m from public.members where id = auth.uid() and active and role = 'president';
  if m.id is null then raise exception 'Only the President can review requests'; end if;

  select * into r from public.budget_requests where id = p_id for update;
  if r.id is null then raise exception 'Request not found'; end if;
  if r.status <> 'pending' then raise exception 'Request already reviewed'; end if;

  if p_approve then
    select total_budget into b from public.settings where id = true for update;
    if b <> r.current_budget then
      raise exception 'Budget changed since this request was made; ask for a new request';
    end if;
    if r.requested_budget < public.total_spent() then
      raise exception 'Requested budget is below total spent';
    end if;
    update public.settings
       set total_budget = r.requested_budget, updated_at = now()
     where id = true;
  end if;

  update public.budget_requests
     set status = case when p_approve then 'approved' else 'rejected' end,
         reviewed_by = m.id, reviewed_by_name = m.name, reviewed_at = now()
   where id = p_id;
end $$;

revoke all on function public.review_budget_request(uuid, boolean) from public, anon;
grant execute on function public.review_budget_request(uuid, boolean) to authenticated;
