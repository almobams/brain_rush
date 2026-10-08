-- Keep one score row per installation/date and rank equal scores by the
-- completed attempt on which the stored best was first achieved.
alter table public.daily_scores add column best_attempt_no smallint;

-- Existing score-only rows have no trustworthy attempt history. Assign the
-- least favorable valid attempt instead of claiming an early success.
update public.daily_scores set best_attempt_no = 3;
alter table public.daily_scores alter column best_attempt_no set not null;
alter table public.daily_scores
  add constraint daily_scores_best_attempt_no_check
  check (best_attempt_no between 1 and 3);

create index daily_scores_rank_attempt_idx
  on public.daily_scores (challenge_date, best_score desc, best_attempt_no asc);
drop index public.daily_scores_rank_idx;

-- The old three-argument RPC cannot supply an attempt number. Remove that
-- overload so an older client fails ranking safely instead of writing a row
-- with invented attempt data. Local gameplay remains independent of ranking.
revoke execute on function public.submit_daily_score(uuid, date, integer)
  from public, anon, authenticated;
drop function public.submit_daily_score(uuid, date, integer);

create function public.submit_daily_score(
  p_installation_id uuid,
  p_challenge_date date,
  p_score integer,
  p_attempt_no integer
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_utc_date date := (now() at time zone 'UTC')::date;
  v_best integer;
begin
  if p_installation_id is null or p_challenge_date is null or
     p_score is null or p_attempt_no is null then
    raise exception 'Missing Daily score parameter' using errcode = '22023';
  end if;
  if p_score < 0 or p_score > 736 then
    raise exception 'Daily score outside game limits' using errcode = '22023';
  end if;
  if p_attempt_no < 1 or p_attempt_no > 3 then
    raise exception 'Daily attempt outside game limits' using errcode = '22023';
  end if;
  if p_challenge_date < v_utc_date - 1 or p_challenge_date > v_utc_date + 1 then
    raise exception 'Daily challenge date outside allowed window' using errcode = '22023';
  end if;

  insert into public.daily_scores as existing
    (challenge_date, installation_id, best_score, best_attempt_no)
  values (p_challenge_date, p_installation_id, p_score, p_attempt_no::smallint)
  on conflict (challenge_date, installation_id) do update
    set best_score = excluded.best_score,
        best_attempt_no = excluded.best_attempt_no,
        updated_at = now()
    where excluded.best_score > existing.best_score
  returning best_score into v_best;

  if v_best is null then
    select best_score into v_best
    from public.daily_scores
    where challenge_date = p_challenge_date
      and installation_id = p_installation_id;
  end if;
  return v_best;
end;
$$;

create or replace function public.get_daily_rank(
  p_installation_id uuid,
  p_challenge_date date
)
returns table (
  best_score integer,
  rank bigint,
  participant_count bigint,
  top_percent integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_utc_date date := (now() at time zone 'UTC')::date;
begin
  if p_installation_id is null or p_challenge_date is null then
    raise exception 'Missing Daily rank parameter' using errcode = '22023';
  end if;
  if p_challenge_date < v_utc_date - 1 or p_challenge_date > v_utc_date + 1 then
    raise exception 'Daily challenge date outside allowed window' using errcode = '22023';
  end if;

  return query
  select mine.best_score,
         counts.higher + 1,
         counts.total,
         greatest(1, least(100,
           ceil(100.0 * (counts.higher + 1) / counts.total)::integer))
  from public.daily_scores as mine
  cross join lateral (
    select count(*) filter (
             where s.best_score > mine.best_score or
                   (s.best_score = mine.best_score and
                    s.best_attempt_no < mine.best_attempt_no)
           ) as higher,
           count(*) as total
    from public.daily_scores as s
    where s.challenge_date = p_challenge_date
  ) as counts
  where mine.challenge_date = p_challenge_date
    and mine.installation_id = p_installation_id;
end;
$$;

revoke execute on function public.submit_daily_score(uuid, date, integer, integer)
  from public, anon, authenticated;
revoke execute on function public.get_daily_rank(uuid, date)
  from public, anon, authenticated;
grant execute on function public.submit_daily_score(uuid, date, integer, integer) to anon;
grant execute on function public.get_daily_rank(uuid, date) to anon;
