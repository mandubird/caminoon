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
