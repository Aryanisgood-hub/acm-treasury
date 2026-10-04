-- =====================================================================
-- Club Finance App : Supabase schema (single club, extensible later)
-- Run once in Supabase Dashboard -> SQL Editor.
-- Money is stored as integer PAISE (Rs 1,250 = 125000).
-- =====================================================================

-- ---------- TABLES ---------------------------------------------------
create table public.members (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null,
  email       text not null,
  role        text not null check (role in ('president','treasurer')),
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create table public.settings (
  id            boolean primary key default true check (id),   -- singleton row
  total_budget  bigint not null default 0 check (total_budget >= 0),
  updated_at    timestamptz not null default now()
);
insert into public.settings (id, total_budget) values (true, 0);

create table public.events (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (length(trim(name)) > 0),
  description  text,
  event_date   date,
  created_at   timestamptz not null default now(),
  created_by   uuid references public.members(id)
);

create table public.bills (
  id                        uuid primary key default gen_random_uuid(),
  event_id                  uuid not null references public.events(id),
  amount                    bigint not null check (amount > 0),
  reason                    text not null check (length(trim(reason)) > 0),
  bill_date                 date not null,
  receipt_path              text,
  receipt_type              text,
  status                    text not null default 'active' check (status in ('active','voided')),
  added_by                  uuid not null references public.members(id),
  added_by_name             text not null,
  added_by_email            text not null,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  last_modified_by          uuid references public.members(id),
  last_modified_by_name     text,
  last_modified_at          timestamptz,
  voided_by                 uuid references public.members(id),
  voided_by_name            text,
  voided_at                 timestamptz,
  void_reason               text
);
create index bills_event_idx  on public.bills(event_id);
create index bills_status_idx on public.bills(status);

create table public.bill_history (            -- append-only audit log
  id        bigint generated always as identity primary key,
  bill_id   uuid not null references public.bills(id),
  action    text not null check (action in ('created','edited','voided')),
  actor_id  uuid not null,
  actor_name text not null,
  at        timestamptz not null default now(),
  before    jsonb,
  after     jsonb
);

create table public.budget_requests (
  id                  uuid primary key default gen_random_uuid(),
  requested_by        uuid not null references public.members(id),
  requested_by_name   text not null,
  current_budget      bigint not null,
  requested_budget    bigint not null check (requested_budget > 0),
  reason              text not null check (length(trim(reason)) > 0),
  status              text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at          timestamptz not null default now(),
  reviewed_by         uuid references public.members(id),
  reviewed_by_name    text,
  reviewed_at         timestamptz
);

-- ---------- HELPERS --------------------------------------------------
-- Returns the caller's role, or NULL if not an active member.
create function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.members where id = auth.uid() and active
$$;

create function public.total_spent() returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(sum(amount), 0) from public.bills where status = 'active'
$$;

-- ---------- TRIGGERS: bills ------------------------------------------
create function public.bills_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  select * into m from public.members where id = auth.uid() and active;
  if m.id is null then raise exception 'Not an active member'; end if;
  new.added_by := m.id;  new.added_by_name := m.name;  new.added_by_email := m.email;
  new.status := 'active';
  new.created_at := now();  new.updated_at := now();
  new.last_modified_by := null; new.last_modified_by_name := null; new.last_modified_at := null;
  new.voided_by := null; new.voided_by_name := null; new.voided_at := null; new.void_reason := null;
  return new;
end $$;
create trigger bills_bi before insert on public.bills
  for each row execute function public.bills_before_insert();

create function public.bills_before_update() returns trigger
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  select * into m from public.members where id = auth.uid() and active;
  if m.id is null then raise exception 'Not an active member'; end if;
  if old.status = 'voided' then raise exception 'Voided bills are frozen'; end if;

  -- immutable audit fields
  new.id := old.id;
  new.added_by := old.added_by; new.added_by_name := old.added_by_name;
  new.added_by_email := old.added_by_email; new.created_at := old.created_at;

  new.updated_at := now();
  new.last_modified_by := m.id; new.last_modified_by_name := m.name; new.last_modified_at := now();

  if new.status = 'voided' then
    if new.void_reason is null or length(trim(new.void_reason)) < 3 then
      raise exception 'A void reason (min 3 characters) is required';
    end if;
    new.voided_by := m.id; new.voided_by_name := m.name; new.voided_at := now();
  else
    new.voided_by := null; new.voided_by_name := null; new.voided_at := null; new.void_reason := null;
  end if;
  return new;
end $$;
create trigger bills_bu before update on public.bills
  for each row execute function public.bills_before_update();

create function public.bills_audit() returns trigger
language plpgsql security definer set search_path = public as $$
declare act text; nm text;
begin
  if tg_op = 'INSERT' then act := 'created';
  elsif new.status = 'voided' then act := 'voided';
  else act := 'edited'; end if;
  select name into nm from public.members where id = auth.uid();
  insert into public.bill_history(bill_id, action, actor_id, actor_name, before, after)
  values (new.id, act, auth.uid(), nm,
          case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  return null;
end $$;
create trigger bills_audit_t after insert or update on public.bills
  for each row execute function public.bills_audit();

-- events: stamp creator
create function public.events_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin new.created_by := auth.uid(); new.created_at := now(); return new; end $$;
create trigger events_bi before insert on public.events
  for each row execute function public.events_before_insert();

-- ---------- TRIGGER: budget request creation -------------------------
create function public.budget_requests_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare m public.members; b bigint;
begin
  select * into m from public.members where id = auth.uid() and active;
  select total_budget into b from public.settings;
  if new.requested_budget = b then raise exception 'Requested budget equals current budget'; end if;
  if new.requested_budget < public.total_spent() then
    raise exception 'Requested budget cannot be below total spent';
  end if;
  new.requested_by := m.id; new.requested_by_name := m.name;
  new.current_budget := b; new.status := 'pending'; new.created_at := now();
  new.reviewed_by := null; new.reviewed_by_name := null; new.reviewed_at := null;
  return new;
end $$;
create trigger br_bi before insert on public.budget_requests
  for each row execute function public.budget_requests_before_insert();

-- ---------- APPROVAL (the ONLY way the budget changes) ----------------
create function public.review_budget_request(p_id uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
declare r public.budget_requests; m public.members; b bigint;
begin
  select * into m from public.members where id = auth.uid() and active and role = 'president';
  if m.id is null then raise exception 'Only the President can review requests'; end if;

  select * into r from public.budget_requests where id = p_id for update;
  if r.id is null then raise exception 'Request not found'; end if;
  if r.status <> 'pending' then raise exception 'Request already reviewed'; end if;

  if p_approve then
    select total_budget into b from public.settings for update;
    if b <> r.current_budget then
      raise exception 'Budget changed since this request was made; ask for a new request';
    end if;
    if r.requested_budget < public.total_spent() then
      raise exception 'Requested budget is below total spent';
    end if;
    update public.settings set total_budget = r.requested_budget, updated_at = now();
  end if;

  update public.budget_requests
     set status = case when p_approve then 'approved' else 'rejected' end,
         reviewed_by = m.id, reviewed_by_name = m.name, reviewed_at = now()
   where id = p_id;
end $$;
revoke all on function public.review_budget_request(uuid, boolean) from public, anon;
grant execute on function public.review_budget_request(uuid, boolean) to authenticated;

-- ---------- ROW LEVEL SECURITY ----------------------------------------
revoke all on all tables in schema public from anon;
alter table public.members         enable row level security;
alter table public.settings        enable row level security;
alter table public.events          enable row level security;
alter table public.bills           enable row level security;
alter table public.bill_history    enable row level security;
alter table public.budget_requests enable row level security;

-- read: any active member. (No write policy = no write, e.g. members/settings/history)
create policy read_members  on public.members         for select to authenticated using (public.my_role() is not null);
create policy read_settings on public.settings         for select to authenticated using (public.my_role() is not null);
create policy read_events   on public.events          for select to authenticated using (public.my_role() is not null);
create policy read_bills    on public.bills            for select to authenticated using (public.my_role() is not null);
create policy read_history  on public.bill_history     for select to authenticated using (public.my_role() is not null);
create policy read_requests on public.budget_requests  for select to authenticated using (public.my_role() is not null);

-- events: both roles may create/edit; nobody deletes
create policy ins_events on public.events for insert to authenticated
  with check (public.my_role() in ('president','treasurer'));
create policy upd_events on public.events for update to authenticated
  using (public.my_role() in ('president','treasurer'))
  with check (public.my_role() in ('president','treasurer'));

-- bills: ONLY treasurers insert; both roles update (void = update); nobody deletes
create policy ins_bills on public.bills for insert to authenticated
  with check (public.my_role() = 'treasurer');
create policy upd_bills on public.bills for update to authenticated
  using (public.my_role() in ('president','treasurer'))
  with check (public.my_role() in ('president','treasurer'));

-- budget requests: ONLY treasurers insert; no update policy (approval goes via the function)
create policy ins_requests on public.budget_requests for insert to authenticated
  with check (public.my_role() = 'treasurer');

-- ---------- TOTALS (views run with caller's RLS) -----------------------
create view public.club_summary with (security_invoker = true) as
select s.total_budget,
       public.total_spent()                         as total_spent,
       s.total_budget - public.total_spent()        as remaining,
       (select count(*) from public.bills where status = 'active') as active_bills
from public.settings s;

create view public.event_totals with (security_invoker = true) as
select e.id as event_id, e.name, e.event_date,
       count(b.id) filter (where b.status = 'active')                  as bill_count,
       coalesce(sum(b.amount) filter (where b.status = 'active'), 0)   as total_spent
from public.events e
left join public.bills b on b.event_id = e.id
group by e.id;

-- ---------- STORAGE (private receipts bucket) ---------------------------
-- Path convention: {event_id}/{bill_id}/{filename}
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receipts', 'receipts', false, 10485760,
        array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do nothing;

create policy receipts_read on storage.objects for select to authenticated
  using (bucket_id = 'receipts' and public.my_role() is not null);
create policy receipts_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'receipts' and public.my_role() = 'treasurer');
-- no update/delete policies: receipts are permanent

-- ---------- REALTIME ----------------------------------------------------
alter publication supabase_realtime add table public.bills, public.events,
  public.budget_requests, public.settings;

-- =====================================================================
-- AFTER creating the 3 users in Dashboard -> Authentication -> Users,
-- add them as members (replace the UUIDs/emails/names):
--
-- insert into public.members (id, name, email, role) values
--  ('<president-uid>',  'President Name',  'pres@example.com', 'president'),
--  ('<treasurer1-uid>', 'Treasurer 1',     't1@example.com',   'treasurer'),
--  ('<treasurer2-uid>', 'Treasurer 2',     't2@example.com',   'treasurer');
--
-- Set the first budget (one-time, as the SQL editor runs as admin):
-- update public.settings set total_budget = 5000000;  -- Rs 50,000
-- =====================================================================
