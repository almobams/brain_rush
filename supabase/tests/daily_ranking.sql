-- Run on a fresh disposable Supabase database after both migrations. This transaction
-- rolls back its test rows. Do not run against a live production project.
begin;

do $$
declare
  d date := (now() at time zone 'UTC')::date;
  a uuid := '00000000-0000-4000-8000-000000000001';
  b uuid := '00000000-0000-4000-8000-000000000002';
  c uuid := '00000000-0000-4000-8000-000000000003';
  e uuid := '00000000-0000-4000-8000-000000000005';
  f uuid := '00000000-0000-4000-8000-000000000006';
  r record;
begin
  if has_table_privilege('anon', 'public.daily_scores', 'INSERT') or
     has_table_privilege('anon', 'public.daily_scores', 'UPDATE') or
     has_table_privilege('anon', 'public.daily_scores', 'DELETE') or
     has_table_privilege('anon', 'public.daily_scores', 'SELECT') then
    raise exception 'anon has direct table access';
  end if;
  if not has_function_privilege('anon', 'public.submit_daily_score(uuid,date,integer,integer)', 'EXECUTE') or
     not has_function_privilege('anon', 'public.get_daily_rank(uuid,date)', 'EXECUTE') then
    raise exception 'anon lacks RPC access';
  end if;
  if to_regprocedure('public.submit_daily_score(uuid,date,integer)') is not null then
    raise exception 'old three-argument RPC is still available';
  end if;

  if public.submit_daily_score(a, d, 80, 1) <> 80 then
    raise exception 'attempt 1 score did not insert';
  end if;
  if public.submit_daily_score(a, d, 70, 2) <> 80 or
     public.submit_daily_score(a, d, 80, 2) <> 80 then
    raise exception 'lower or tied score changed best';
  end if;
  select best_score, best_attempt_no into r
  from public.daily_scores where challenge_date = d and installation_id = a;
  if r.best_score <> 80 or r.best_attempt_no <> 1 then
    raise exception 'lower/equal retry changed the stored attempt';
  end if;
  if public.submit_daily_score(a, d, 81, 3) <> 81 then
    raise exception 'attempt 3 higher score did not update best';
  end if;
  select best_score, best_attempt_no into r
  from public.daily_scores where challenge_date = d and installation_id = a;
  if r.best_score <> 81 or r.best_attempt_no <> 3 then
    raise exception 'higher retry did not update both best fields';
  end if;

  perform public.submit_daily_score(b, d, 80, 1);
  perform public.submit_daily_score(c, d, 80, 2);
  perform public.submit_daily_score(e, d, 80, 2);
  perform public.submit_daily_score(f, d, 79, 1);
  if (select count(*) from public.daily_scores
      where challenge_date = d and installation_id = a) <> 1 then
    raise exception 'duplicate installation/date row';
  end if;

  select * into r from public.get_daily_rank(a, d);
  if r.best_score <> 81 or r.highest_score <> 81 or
     r.rank <> 1 or r.participant_count <> 5 or r.top_percent <> 20 then
    raise exception 'incorrect first-place rank/count/percent';
  end if;
  if to_jsonb(r) ? 'installation_id' or to_jsonb(r) ? 'best_attempt_no' then
    raise exception 'rank response exposes another installation field';
  end if;
  select * into r from public.get_daily_rank(b, d);
  if r.best_score <> 80 or r.highest_score <> 81 or r.rank <> 2 then
    raise exception 'global high score or first-attempt tie break failed';
  end if;
  select * into r from public.get_daily_rank(c, d);
  if r.rank <> 3 or r.top_percent <> 60 then
    raise exception 'second-attempt tie break failed';
  end if;
  select * into r from public.get_daily_rank(e, d);
  if r.rank <> 3 then raise exception 'equal score and attempt did not tie'; end if;
  select * into r from public.get_daily_rank(f, d);
  if r.rank <> 5 or r.top_percent <> 100 then
    raise exception 'lower score outranked a higher score';
  end if;

  -- Equal high scores still rank by the attempt that achieved them.
  perform public.submit_daily_score(b, d, 81, 1);
  select * into r from public.get_daily_rank(a, d);
  if r.best_score <> 81 or r.highest_score <> 81 or r.rank <> 2 then
    raise exception 'highest score and second-place attempt tie break failed';
  end if;
  select * into r from public.get_daily_rank(b, d);
  if r.best_score <> 81 or r.highest_score <> 81 or r.rank <> 1 then
    raise exception 'first-attempt high score did not rank first';
  end if;

  begin
    perform public.submit_daily_score(a, d, -1, 1);
    raise exception 'negative score accepted';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.submit_daily_score(a, d, 737, 1);
    raise exception 'score over game limit accepted';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.submit_daily_score(a, d + 2, 10, 1);
    raise exception 'far future date accepted';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.submit_daily_score(a, d - 2, 10, 1);
    raise exception 'far past date accepted';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.submit_daily_score(a, d, 10, 0);
    raise exception 'attempt zero accepted';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.submit_daily_score(a, d, 10, 4);
    raise exception 'attempt four accepted';
  exception when sqlstate '22023' then null;
  end;
end;
$$;

rollback;
