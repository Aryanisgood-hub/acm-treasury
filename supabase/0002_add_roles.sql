-- =====================================================================
-- Migration 0002: add vice_president and faculty_coordinator roles
-- Same access as president EXCEPT budget approval (stays president-only,
-- because review_budget_request() checks role = 'president').
-- Run in Supabase SQL Editor after 0001_init.sql.
-- =====================================================================

-- 1. Allow the new role values
alter table public.members drop constraint members_role_check;
alter table public.members add constraint members_role_check
  check (role in ('president','vice_president','faculty_coordinator','treasurer'));

-- 2. Roles that review/edit (everyone except nobody-new gets bill creation:
--    only treasurers may INSERT bills, unchanged)
drop policy upd_bills on public.bills;
create policy upd_bills on public.bills for update to authenticated
  using (public.my_role() in ('president','vice_president','faculty_coordinator','treasurer'))
  with check (public.my_role() in ('president','vice_president','faculty_coordinator','treasurer'));

drop policy ins_events on public.events;
create policy ins_events on public.events for insert to authenticated
  with check (public.my_role() in ('president','vice_president','faculty_coordinator','treasurer'));

drop policy upd_events on public.events;
create policy upd_events on public.events for update to authenticated
  using (public.my_role() in ('president','vice_president','faculty_coordinator','treasurer'))
  with check (public.my_role() in ('president','vice_president','faculty_coordinator','treasurer'));

-- Read policies use "my_role() is not null", so the new roles can already
-- read everything. Bill insert, budget request insert and budget approval
-- are untouched, so the new roles cannot do those.

-- 3. After creating their logins in Authentication -> Users, add them:
-- insert into public.members (id, name, email, role) values
--  ('VICE-PRESIDENT-UUID',     'VP Name',      'vp@email.com',      'vice_president'),
--  ('FACULTY-COORDINATOR-UUID','Faculty Name', 'faculty@email.com', 'faculty_coordinator');
