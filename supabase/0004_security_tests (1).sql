-- =====================================================================
-- Security & finance self-test for ACM Treasury (Supabase)
-- Run in SQL Editor (new query tab). It is SAFE: every scenario runs in a
-- sub-transaction that is rolled back, so no real data is created or changed.
-- Needs at least one active 'president' and one active 'treasurer' in members.
-- Result: a table with one row per scenario. Every row should say PASS.
-- =====================================================================

create or replace function pg_temp.act_as(uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid::text, 'role', 'authenticated')::text, true);
  set local role authenticated;
end $$;

create or replace function pg_temp.run_security_tests()
returns table(t_name text, t_result text, t_detail text)
language plpgsql as $$
declare
  pres uuid := (select id from public.members where role = 'president' and active limit 1);
  trea uuid := (select id from public.members where role = 'treasurer' and active limit 1);
  ev uuid; b1 uuid; rid uuid; who uuid;
  s0 bigint; s1 bigint; r0 bigint; r1 bigint; bud0 bigint; bud1 bigint; n int; st text;
begin
  if pres is null or trea is null then
    t_name := 'Setup'; t_result := 'FAIL';
    t_detail := 'Need one active president and one active treasurer in members';
    return next; return;
  end if;
  select total_budget into bud0 from public.settings;

  -- 1. Treasurer adds Rs 1,000 bill
  t_name := '1. Treasurer adds Rs 1,000 bill: spent +1000, remaining -1000';
  begin
    insert into public.events(name) values ('ZZ test event') returning id into ev;
    s0 := public.total_spent(); select remaining into r0 from public.club_summary;
    perform pg_temp.act_as(trea);
    insert into public.bills(event_id, amount, reason, bill_date)
      values (ev, 100000, 'test bill', current_date);
    reset role;
    s1 := public.total_spent(); select remaining into r1 from public.club_summary;
    t_result := case when s1 - s0 = 100000 and r0 - r1 = 100000 then 'PASS' else 'FAIL' end;
    t_detail := 'spent change ' || (s1 - s0) || ' paise, remaining change ' || (r1 - r0);
    raise exception 'rollback' using errcode = 'P9999';
  exception
    when sqlstate 'P9999' then null;
    when others then t_result := 'FAIL'; t_detail := sqlerrm;
  end;
  return next;

  -- 2. President edits Rs 1,000 bill to Rs 1,500
  t_name := '2. President edits Rs 1,000 bill to Rs 1,500: spent +500';
  begin
    insert into public.events(name) values ('ZZ test event') returning id into ev;
    perform pg_temp.act_as(trea);
    insert into public.bills(event_id, amount, reason, bill_date)
      values (ev, 100000, 'test bill', current_date) returning id into b1;
    reset role;
    s0 := public.total_spent();
    perform pg_temp.act_as(pres);
    update public.bills set amount = 150000 where id = b1;
    get diagnostics n = row_count;
    reset role;
    s1 := public.total_spent();
    select added_by into who from public.bills where id = b1;
    t_result := case when n = 1 and s1 - s0 = 50000 and who = trea then 'PASS' else 'FAIL' end;
    t_detail := 'rows updated ' || n || ', spent change ' || (s1 - s0)
                || ', Added By still the treasurer: ' || (who = trea);
    raise exception 'rollback' using errcode = 'P9999';
  exception
    when sqlstate 'P9999' then null;
    when others then t_result := 'FAIL'; t_detail := sqlerrm;
  end;
  return next;

  -- 3. Treasurer voids Rs 1,000 bill
  t_name := '3. Treasurer voids Rs 1,000 bill: spent -1000, remaining +1000';
  begin
    insert into public.events(name) values ('ZZ test event') returning id into ev;
    perform pg_temp.act_as(trea);
    insert into public.bills(event_id, amount, reason, bill_date)
      values (ev, 100000, 'test bill', current_date) returning id into b1;
    reset role;
    s0 := public.total_spent(); select remaining into r0 from public.club_summary;
    perform pg_temp.act_as(trea);
    update public.bills set status = 'voided', void_reason = 'test void' where id = b1;
    get diagnostics n = row_count;
    reset role;
    s1 := public.total_spent(); select remaining into r1 from public.club_summary;
    t_result := case when n = 1 and s0 - s1 = 100000 and r1 - r0 = 100000 then 'PASS' else 'FAIL' end;
    t_detail := 'spent change ' || (s1 - s0) || ', remaining change ' || (r1 - r0);
    raise exception 'rollback' using errcode = 'P9999';
  exception
    when sqlstate 'P9999' then null;
    when others then t_result := 'FAIL'; t_detail := sqlerrm;
  end;
  return next;

  -- 4. Treasurer requests a budget increase: official budget unchanged
  t_name := '4. Treasurer requests a budget increase: official budget stays the same';
  begin
    perform pg_temp.act_as(trea);
    insert into public.budget_requests(requested_budget, reason)
      values (bud0 + 1000000, 'test request') returning id into rid;
    reset role;
    select total_budget into bud1 from public.settings;
    select status into st from public.budget_requests where id = rid;
    t_result := case when bud1 = bud0 and st = 'pending' then 'PASS' else 'FAIL' end;
    t_detail := 'budget before ' || bud0 || ', after ' || bud1 || ', request status ' || st;
    raise exception 'rollback' using errcode = 'P9999';
  exception
    when sqlstate 'P9999' then null;
    when others then t_result := 'FAIL'; t_detail := sqlerrm;
  end;
  return next;

  -- 5. President approves the request
  t_name := '5. President approves the request: official budget changes';
  begin
    perform pg_temp.act_as(trea);
    insert into public.budget_requests(requested_budget, reason)
      values (bud0 + 1000000, 'test request') returning id into rid;
    reset role;
    perform pg_temp.act_as(pres);
    perform public.review_budget_request(rid, true);
    reset role;
    select total_budget into bud1 from public.settings;
    select status into st from public.budget_requests where id = rid;
    t_result := case when bud1 = bud0 + 1000000 and st = 'approved' then 'PASS' else 'FAIL' end;
    t_detail := 'budget before ' || bud0 || ', after ' || bud1 || ', request status ' || st;
    raise exception 'rollback' using errcode = 'P9999';
  exception
    when sqlstate 'P9999' then null;
    when others then t_result := 'FAIL'; t_detail := sqlerrm;
  end;
  return next;

  -- 6. President tries to add a bill
  t_name := '6. President tries to add a bill: must be blocked';
  begin
    insert into public.events(name) values ('ZZ test event') returning id into ev;
    perform pg_temp.act_as(pres);
    insert into public.bills(event_id, amount, reason, bill_date)
      values (ev, 100000, 'president bill', current_date);
    t_result := 'FAIL'; t_detail := 'the insert was allowed';
    raise exception 'rollback' using errcode = 'P9999';
  exception
    when sqlstate 'P9999' then null;
    when others then
      if sqlerrm ilike '%row-level security%' then
        t_result := 'PASS'; t_detail := 'blocked by row-level security';
      else t_result := 'FAIL'; t_detail := 'unexpected error: ' || sqlerrm; end if;
  end;
  return next;

  -- 7. Treasurer tries to change the official budget directly
  t_name := '7. Treasurer changes total_budget directly: must be blocked';
  begin
    perform pg_temp.act_as(trea);
    update public.settings set total_budget = 99999900 where id = true;
    get diagnostics n = row_count;
    reset role;
    select total_budget into bud1 from public.settings;
    t_result := case when n = 0 and bud1 = bud0 then 'PASS' else 'FAIL' end;
    t_detail := 'rows changed ' || n || ', budget still ' || bud1;
    raise exception 'rollback' using errcode = 'P9999';
  exception
    when sqlstate 'P9999' then null;
    when others then
      if sqlerrm ilike '%permission denied%' or sqlerrm ilike '%row-level security%' then
        t_result := 'PASS'; t_detail := 'blocked: ' || sqlerrm;
      else t_result := 'FAIL'; t_detail := 'unexpected error: ' || sqlerrm; end if;
  end;
  return next;

  -- 8. Signed-out visitor reads bills
  t_name := '8. Signed-out visitor reads bills: must be denied';
  begin
    insert into public.events(name) values ('ZZ test event') returning id into ev;
    perform pg_temp.act_as(trea);
    insert into public.bills(event_id, amount, reason, bill_date)
      values (ev, 100000, 'test bill', current_date);
    reset role;
    set local role anon;
    select count(*) into n from public.bills;
    t_result := case when n = 0 then 'PASS' else 'FAIL' end;
    t_detail := 'rows visible to anonymous visitor: ' || n;
    raise exception 'rollback' using errcode = 'P9999';
  exception
    when sqlstate 'P9999' then null;
    when others then
      if sqlerrm ilike '%permission denied%' then
        t_result := 'PASS'; t_detail := 'access denied';
      else t_result := 'FAIL'; t_detail := 'unexpected error: ' || sqlerrm; end if;
  end;
  return next;

  -- 9. Signed-in account that is NOT a club member
  t_name := '9. Signed-in non-member reads bills: sees nothing';
  begin
    insert into public.events(name) values ('ZZ test event') returning id into ev;
    perform pg_temp.act_as(trea);
    insert into public.bills(event_id, amount, reason, bill_date)
      values (ev, 100000, 'test bill', current_date);
    reset role;
    perform pg_temp.act_as(gen_random_uuid());
    select count(*) into n from public.bills;
    t_result := case when n = 0 then 'PASS' else 'FAIL' end;
    t_detail := 'rows visible to a stranger: ' || n;
    raise exception 'rollback' using errcode = 'P9999';
  exception
    when sqlstate 'P9999' then null;
    when others then t_result := 'FAIL'; t_detail := sqlerrm;
  end;
  return next;

  -- 10. Treasurer approves their own request
  t_name := '10. Treasurer approves own request: must be blocked';
  begin
    perform pg_temp.act_as(trea);
    insert into public.budget_requests(requested_budget, reason)
      values (bud0 + 1000000, 'test request') returning id into rid;
    perform public.review_budget_request(rid, true);
    t_result := 'FAIL'; t_detail := 'the approval was allowed';
    raise exception 'rollback' using errcode = 'P9999';
  exception
    when sqlstate 'P9999' then null;
    when others then
      if sqlerrm ilike '%Only the President%' then
        t_result := 'PASS'; t_detail := 'blocked: only the President can review';
      else t_result := 'FAIL'; t_detail := 'unexpected error: ' || sqlerrm; end if;
  end;
  return next;

  -- 11. Added-by cannot be faked
  t_name := '11. Treasurer tries to fake "Added By": stored value is still the treasurer';
  begin
    insert into public.events(name) values ('ZZ test event') returning id into ev;
    perform pg_temp.act_as(trea);
    insert into public.bills(event_id, amount, reason, bill_date,
                             added_by, added_by_name, added_by_email)
      values (ev, 100000, 'test bill', current_date, pres, 'Fake Person', 'fake@example.com')
      returning id into b1;
    reset role;
    select added_by into who from public.bills where id = b1;
    t_result := case when who = trea then 'PASS' else 'FAIL' end;
    t_detail := 'stored added_by is the real treasurer: ' || (who = trea);
    raise exception 'rollback' using errcode = 'P9999';
  exception
    when sqlstate 'P9999' then null;
    when others then t_result := 'FAIL'; t_detail := sqlerrm;
  end;
  return next;

  -- 12. A voided bill cannot be edited
  t_name := '12. Editing a voided bill: must be blocked';
  begin
    insert into public.events(name) values ('ZZ test event') returning id into ev;
    perform pg_temp.act_as(trea);
    insert into public.bills(event_id, amount, reason, bill_date)
      values (ev, 100000, 'test bill', current_date) returning id into b1;
    update public.bills set status = 'voided', void_reason = 'test void' where id = b1;
    update public.bills set amount = 5 where id = b1;
    t_result := 'FAIL'; t_detail := 'the edit was allowed';
    raise exception 'rollback' using errcode = 'P9999';
  exception
    when sqlstate 'P9999' then null;
    when others then
      if sqlerrm ilike '%frozen%' then
        t_result := 'PASS'; t_detail := 'blocked: voided bills are frozen';
      else t_result := 'FAIL'; t_detail := 'unexpected error: ' || sqlerrm; end if;
  end;
  return next;

  -- 13. Bills cannot be deleted
  t_name := '13. President tries to delete a bill: must be blocked';
  begin
    insert into public.events(name) values ('ZZ test event') returning id into ev;
    perform pg_temp.act_as(trea);
    insert into public.bills(event_id, amount, reason, bill_date)
      values (ev, 100000, 'test bill', current_date) returning id into b1;
    reset role;
    perform pg_temp.act_as(pres);
    delete from public.bills where id = b1;
    get diagnostics n = row_count;
    t_result := case when n = 0 then 'PASS' else 'FAIL' end;
    t_detail := 'rows deleted: ' || n;
    raise exception 'rollback' using errcode = 'P9999';
  exception
    when sqlstate 'P9999' then null;
    when others then
      if sqlerrm ilike '%permission denied%' or sqlerrm ilike '%row-level security%' then
        t_result := 'PASS'; t_detail := 'blocked: ' || sqlerrm;
      else t_result := 'FAIL'; t_detail := 'unexpected error: ' || sqlerrm; end if;
  end;
  return next;

  reset role;
  return;
end $$;

select * from pg_temp.run_security_tests();
