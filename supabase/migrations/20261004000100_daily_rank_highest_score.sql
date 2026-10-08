-- Add the day's global high score to the existing anonymous rank response.
-- PostgreSQL requires dropping the function when its table return shape changes.
begin;

drop function public.get_daily_rank(uuid, date);

create function public.get_daily_rank(
  p_installation_id uuid,
  p_challenge_date date
)
returns table (
  best_score integer,
  highest_score integer,
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
         counts.highest,
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
           count(*) as total,
           max(s.best_score) as highest
    from public.daily_scores as s
    where s.challenge_date = p_challenge_date
  ) as counts
  where mine.challenge_date = p_challenge_date
    and mine.installation_id = p_installation_id;
end;
$$;

revoke execute on function public.get_daily_rank(uuid, date)
  from public, anon, authenticated;
grant execute on function public.get_daily_rank(uuid, date) to anon;

commit;
