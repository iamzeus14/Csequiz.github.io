-- =====================================================================
-- C Programming Quiz: Supabase setup
-- Run this once: Supabase dashboard > SQL Editor > New query > paste > Run
-- =====================================================================

-- 1) Table that stores every finished quiz attempt
create table if not exists public.results (
  id         bigint generated always as identity primary key,
  client_id  uuid unique,                              -- stops duplicate uploads on retry
  created_at timestamptz not null default now(),
  name       text not null check (char_length(name) between 2 and 30),
  roll       text          check (char_length(roll) <= 20),
  score      int  not null check (score >= 0),
  total      int  not null check (total between 5 and 100),
  percent    int  not null check (percent between 0 and 100),
  time_ms    int  not null check (time_ms >= 0),
  modules    jsonb,                                    -- per-module accuracy of that attempt
  constraint score_le_total check (score <= total)
);

-- 2) Row Level Security: the public (anon) key may ONLY add rows.
--    It cannot read, edit or delete the table directly.
alter table public.results enable row level security;
drop policy if exists "anyone can submit a result" on public.results;
create policy "anyone can submit a result"
  on public.results for insert to anon with check (true);

-- 3) Safe, read-only leaderboard: best attempt per student, top 50 max.
create or replace function public.get_leaderboard(lim int default 20)
returns table (name text, roll text, percent int, score int, total int, time_ms int, created_at timestamptz)
language sql security definer set search_path = public stable as $$
  select * from (
    select distinct on (lower(r.name), coalesce(r.roll, ''))
           r.name, r.roll, r.percent, r.score, r.total, r.time_ms, r.created_at
    from public.results r
    where r.total >= 10
    order by lower(r.name), coalesce(r.roll, ''), r.percent desc, r.time_ms asc
  ) t
  order by t.percent desc, t.time_ms asc
  limit least(greatest(lim, 1), 50);
$$;
revoke all on function public.get_leaderboard(int) from public;
grant execute on function public.get_leaderboard(int) to anon;

-- Teacher view: Table Editor > results (you can export CSV from there).
