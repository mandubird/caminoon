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
