-- Anonymous Daily ranking. Run as the Supabase database owner.
create table public.daily_scores (
  challenge_date date not null,
  installation_id uuid not null,
  best_score integer not null check (best_score between 0 and 736),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (challenge_date, installation_id)
);

create index daily_scores_rank_idx
  on public.daily_scores (challenge_date, best_score desc);

alter table public.daily_scores enable row level security;
revoke all on table public.daily_scores from public, anon, authenticated;
-- There are intentionally no client-facing RLS policies. Only the two RPCs
-- below can read or write this table through the public API.

create function public.submit_daily_score(
  p_installation_id uuid,
  p_challenge_date date,
  p_score integer
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
  if p_installation_id is null or p_challenge_date is null or p_score is null then
    raise exception 'Missing Daily score parameter' using errcode = '22023';
  end if;
  -- GameController allows 60 seconds, at least 320 ms between answers,
  -- and at most 4 points per answer. At most 188 answers yield 736 points.
  if p_score < 0 or p_score > 736 then
    raise exception 'Daily score outside game limits' using errcode = '22023';
  end if;
  -- A local date can differ from UTC by one calendar day worldwide.
  if p_challenge_date < v_utc_date - 1 or p_challenge_date > v_utc_date + 1 then
    raise exception 'Daily challenge date outside allowed window' using errcode = '22023';
  end if;

  insert into public.daily_scores as existing
    (challenge_date, installation_id, best_score)
  values (p_challenge_date, p_installation_id, p_score)
  on conflict (challenge_date, installation_id) do update
    set best_score = excluded.best_score, updated_at = now()
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

create function public.get_daily_rank(
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
    select count(*) filter (where s.best_score > mine.best_score) as higher,
           count(*) as total
    from public.daily_scores as s
    where s.challenge_date = p_challenge_date
  ) as counts
  where mine.challenge_date = p_challenge_date
    and mine.installation_id = p_installation_id;
end;
$$;

revoke execute on function public.submit_daily_score(uuid, date, integer)
  from public, anon, authenticated;
revoke execute on function public.get_daily_rank(uuid, date)
  from public, anon, authenticated;
grant execute on function public.submit_daily_score(uuid, date, integer) to anon;
grant execute on function public.get_daily_rank(uuid, date) to anon;
