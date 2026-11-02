-- 카미노 온 · Camino On : Supabase 설정
-- SQL Editor에 붙여 넣고 한 번 실행하세요. 다른 서비스와 같은 프로젝트를 써도 겹치지 않게 camino_ 접두사를 붙였어요.
-- 함께 걷기(접속자 표시·위치·인사)는 Realtime 채널만 쓰므로 테이블이 필요 없어요.

create table if not exists public.camino_cairns (
  id uuid primary key default gen_random_uuid(),
  x real not null check (x between -150 and 160),
  z real not null check (z between -190 and 100),
  text text not null check (char_length(text) between 1 and 80),
  who text not null check (char_length(who) between 1 and 12),
  c text not null check (char_length(c) between 2 and 4),
  created_at timestamptz not null default now()
);
alter table public.camino_cairns enable row level security;
drop policy if exists "camino cairns read" on public.camino_cairns;
create policy "camino cairns read" on public.camino_cairns for select to anon, authenticated using (true);
drop policy if exists "camino cairns add" on public.camino_cairns;
create policy "camino cairns add" on public.camino_cairns for insert to anon, authenticated with check (true);

create table if not exists public.camino_country_requests (
  id bigint generated always as identity primary key,
  name text not null check (char_length(name) between 1 and 60),
  lang text check (char_length(lang) <= 5),
  created_at timestamptz not null default now()
);
alter table public.camino_country_requests enable row level security;
drop policy if exists "camino requests add" on public.camino_country_requests;
create policy "camino requests add" on public.camino_country_requests for insert to anon, authenticated with check (true);
-- 요청 목록은 대시보드(Table Editor)에서만 보여요. 공개 읽기 정책은 일부러 만들지 않았어요.

-- 접속을 끊은 순례자의 텐트 (마지막 위치)
create table if not exists public.camino_tents (
  id text primary key check (char_length(id) between 4 and 64),
  x real not null check (x between -150 and 160),
  z real not null check (z between -190 and 100),
  name text not null check (char_length(name) between 1 and 12),
  c text not null check (char_length(c) between 2 and 4),
  pack integer not null default 12605487 check (pack between 0 and 16777215),
  sleeping boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.camino_tents enable row level security;
drop policy if exists "camino tents read" on public.camino_tents;
create policy "camino tents read" on public.camino_tents for select to anon, authenticated using (true);
drop policy if exists "camino tents add" on public.camino_tents;
create policy "camino tents add" on public.camino_tents for insert to anon, authenticated with check (true);
drop policy if exists "camino tents move" on public.camino_tents;
create policy "camino tents move" on public.camino_tents for update to anon, authenticated using (true) with check (true);

-- 계정별 여정 저장 (게스트=익명 로그인, 구글 연결 시 같은 user_id 유지)
create table if not exists public.camino_journeys (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null check (pg_column_size(data) < 300000),
  updated_at timestamptz not null default now()
);
alter table public.camino_journeys enable row level security;
drop policy if exists "own journey read" on public.camino_journeys;
create policy "own journey read" on public.camino_journeys for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "own journey add" on public.camino_journeys;
create policy "own journey add" on public.camino_journeys for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "own journey update" on public.camino_journeys;
create policy "own journey update" on public.camino_journeys for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- ===== Analytics (anonymous behaviour only) =====
create table if not exists public.camino_events (
  id bigint generated always as identity primary key,
  cid text not null check (char_length(cid) between 4 and 64),
  sid text not null check (char_length(sid) between 4 and 40),
  ev text not null check (char_length(ev) between 1 and 32),
  v jsonb not null default '{}'::jsonb check (pg_column_size(v) < 2000),
  at timestamptz not null default now()
);
create index if not exists camino_events_at on public.camino_events(at);
alter table public.camino_events enable row level security;
drop policy if exists "camino events add" on public.camino_events;
create policy "camino events add" on public.camino_events for insert to anon, authenticated with check (true);

create or replace function public.camino_stats(n_days int default 14)
returns jsonb language sql stable security definer set search_path = public as $$
with e as (
  select cid, sid, ev, v, (at at time zone 'Asia/Seoul')::date d
  from public.camino_events
  where at > now() - make_interval(days => least(greatest(coalesce(n_days,14),1),90))
),
sess as (
  select sid, min(cid) cid, min(d) d,
    max(least(case when ev in ('beat','end') and v->>'walkSec' ~ '^[0-9]{1,6}(\.[0-9]+)?$' then (v->>'walkSec')::numeric else 0 end, 43200)) walk
  from e group by sid
),
opens as (select distinct cid, d from e where ev='open'),
dlist as (select distinct d from e),
daily as (
  select dd.d,
    (select count(distinct cid) from opens o where o.d=dd.d) visitors,
    (select count(distinct cid) from e where e.d=dd.d and ev='start') starters,
    (select count(distinct cid) from sess s where s.d=dd.d and walk>=300) walked5,
    (select round(avg(walk)/60.0,1) from sess s where s.d=dd.d and walk>0) avg_walk_min,
    (select count(distinct cid) from e where e.d=dd.d and ev='greet') greeted,
    (select count(distinct cid) from e where e.d=dd.d and ev='greet' and v->>'real'='true') greeted_real,
    (select count(distinct cid) from e where e.d=dd.d and ev='dayend') day_end,
    (select count(distinct cid) from e where e.d=dd.d and ev='share') shared,
    (select count(*) from opens o where o.d=dd.d and exists(select 1 from opens o2 where o2.cid=o.cid and o2.d=dd.d+1)) returned_next_day
  from dlist dd
)
select jsonb_build_object(
  'daily', coalesce((select jsonb_agg(to_jsonb(daily) order by d desc) from daily),'[]'::jsonb),
  'totals', jsonb_build_object(
    'visitors',(select count(distinct cid) from opens),
    'starters',(select count(distinct cid) from e where ev='start'),
    'walk5',(select count(distinct cid) from sess where walk>=300),
    'avg_walk_min',(select round(avg(walk)/60.0,1) from sess where walk>0),
    'greeted',(select count(distinct cid) from e where ev='greet'),
    'greeted_real',(select count(distinct cid) from e where ev='greet' and v->>'real'='true'),
    'shared',(select count(distinct cid) from e where ev='share'),
    'returning',(select count(*) from (select cid from opens group by cid having count(*)>1) r),
    'sessions',(select count(*) from sess)
  ),
  'countries', coalesce((select jsonb_agg(jsonb_build_object('c',c,'n',n) order by n desc) from (select v->>'c' c, count(distinct cid) n from e where ev='start' and v ? 'c' group by 1) x),'[]'::jsonb),
  'events', coalesce((select jsonb_object_agg(ev,n) from (select ev, count(*) n from e group by ev) y),'{}'::jsonb),
  'generated_at', now()
);
$$;
revoke all on function public.camino_stats(int) from public;
grant execute on function public.camino_stats(int) to anon, authenticated;

-- ===== Stages (구간별 좌표 분리) =====
alter table public.camino_cairns add column if not exists stage smallint not null default 1 check (stage between 1 and 60);
alter table public.camino_tents  add column if not exists stage smallint not null default 1 check (stage between 1 and 60);
create index if not exists camino_cairns_stage on public.camino_cairns(stage, created_at desc);

-- ===== 다음 구간 투표 =====
create table if not exists public.camino_votes (
  stage smallint not null check (stage between 1 and 60),
  voter text not null check (char_length(voter) between 4 and 64),
  lang text check (char_length(lang) <= 8),
  c text check (char_length(c) <= 8),
  at timestamptz not null default now(),
  primary key (stage, voter)
);
alter table public.camino_votes enable row level security;
drop policy if exists "camino votes add" on public.camino_votes;
create policy "camino votes add" on public.camino_votes for insert to anon, authenticated with check (true);
create or replace function public.camino_vote_count(p_stage int)
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from public.camino_votes where stage = p_stage;
$$;
grant execute on function public.camino_vote_count(int) to anon, authenticated;
