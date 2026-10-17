-- Tablas y políticas públicas para comentarios y likes sin iniciar sesión.
-- Ejecutar en Supabase > SQL Editor.

-- Eliminar primero la vista anterior para permitir actualizar su estructura.
drop view if exists public.comments_with_likes;

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  slide_number smallint not null default 1,
  parent_comment_id uuid references public.comments(id) on delete cascade,
  author_name text not null default 'Anónimo'
    check (char_length(btrim(author_name)) between 1 and 40),
  content text not null
    check (char_length(btrim(content)) between 1 and 1000),
  created_at timestamptz not null default now()
);

drop policy if exists "Authenticated users can read comments" on public.comments;
drop policy if exists "Users can add their own comments" on public.comments;
drop policy if exists "Anyone can read comments" on public.comments;
drop policy if exists "Anyone can post comments" on public.comments;

-- Migra la tabla de comentarios si se había creado con el query anterior.
alter table public.comments add column if not exists slide_number smallint not null default 1;
alter table public.comments
  add column if not exists parent_comment_id uuid
  references public.comments(id) on delete cascade;
alter table public.comments drop column if exists user_id;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.comments'::regclass
      and conname = 'comments_slide_number_range'
  ) then
    alter table public.comments
      add constraint comments_slide_number_range
      check (slide_number between 1 and 8);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.comments'::regclass
      and conname = 'comments_parent_not_self'
  ) then
    alter table public.comments
      add constraint comments_parent_not_self
      check (parent_comment_id is null or parent_comment_id <> id);
  end if;
end
$$;

create or replace function public.validate_comment_parent_slide()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.parent_comment_id is not null and not exists (
    select 1 from public.comments as parent
    where parent.id = new.parent_comment_id
      and parent.slide_number = new.slide_number
  ) then
    raise exception 'La respuesta debe pertenecer a la misma diapositiva que el comentario.';
  end if;
  return new;
end;
$$;

drop trigger if exists comments_validate_parent_slide on public.comments;
create trigger comments_validate_parent_slide
  before insert or update of parent_comment_id, slide_number
  on public.comments
  for each row execute function public.validate_comment_parent_slide();

create table if not exists public.comment_likes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  visitor_id uuid not null,
  created_at timestamptz not null default now()
);

drop policy if exists "Authenticated users can read likes" on public.comment_likes;
drop policy if exists "Authenticated users can read comment likes" on public.comment_likes;
drop policy if exists "Users can like as themselves" on public.comment_likes;
drop policy if exists "Users can like comments as themselves" on public.comment_likes;
drop policy if exists "Users can remove their own likes" on public.comment_likes;
drop policy if exists "Users can remove their own comment likes" on public.comment_likes;
drop policy if exists "Anyone can read comment likes" on public.comment_likes;
drop policy if exists "Anyone can add comment likes" on public.comment_likes;
drop policy if exists "Anyone can remove comment likes" on public.comment_likes;

-- Convierte likes creados con la versión autenticada del esquema.
alter table public.comment_likes drop constraint if exists comment_likes_pkey;
alter table public.comment_likes drop column if exists user_id;
alter table public.comment_likes add column if not exists visitor_id uuid;
update public.comment_likes set visitor_id = gen_random_uuid() where visitor_id is null;
alter table public.comment_likes alter column visitor_id set not null;
alter table public.comment_likes
  add constraint comment_likes_pkey primary key (comment_id, visitor_id);

create table if not exists public.story_likes (
  slide_number smallint not null,
  visitor_id uuid not null,
  created_at timestamptz not null default now()
);

drop policy if exists "Authenticated users can read story likes" on public.story_likes;
drop policy if exists "Users can like stories as themselves" on public.story_likes;
drop policy if exists "Users can remove their own story likes" on public.story_likes;
drop policy if exists "Anyone can read story likes" on public.story_likes;
drop policy if exists "Anyone can add story likes" on public.story_likes;
drop policy if exists "Anyone can remove story likes" on public.story_likes;

alter table public.story_likes drop constraint if exists story_likes_pkey;
alter table public.story_likes drop column if exists user_id;
alter table public.story_likes add column if not exists visitor_id uuid;
update public.story_likes set visitor_id = gen_random_uuid() where visitor_id is null;
alter table public.story_likes alter column visitor_id set not null;
alter table public.story_likes
  add constraint story_likes_pkey primary key (slide_number, visitor_id);
alter table public.story_likes
  drop constraint if exists story_likes_slide_number_check;
alter table public.story_likes
  drop constraint if exists story_likes_slide_number_range;
alter table public.story_likes
  add constraint story_likes_slide_number_range
  check (slide_number between 1 and 8);

-- Eliminar políticas de ejecuciones anteriores del query.
drop policy if exists "Authenticated users can read comments" on public.comments;
drop policy if exists "Users can add their own comments" on public.comments;
drop policy if exists "Anyone can read comments" on public.comments;
drop policy if exists "Anyone can post comments" on public.comments;

drop policy if exists "Authenticated users can read likes" on public.comment_likes;
drop policy if exists "Authenticated users can read comment likes" on public.comment_likes;
drop policy if exists "Users can like as themselves" on public.comment_likes;
drop policy if exists "Users can like comments as themselves" on public.comment_likes;
drop policy if exists "Users can remove their own likes" on public.comment_likes;
drop policy if exists "Users can remove their own comment likes" on public.comment_likes;
drop policy if exists "Anyone can read comment likes" on public.comment_likes;
drop policy if exists "Anyone can add comment likes" on public.comment_likes;
drop policy if exists "Anyone can remove comment likes" on public.comment_likes;

drop policy if exists "Authenticated users can read story likes" on public.story_likes;
drop policy if exists "Users can like stories as themselves" on public.story_likes;
drop policy if exists "Users can remove their own story likes" on public.story_likes;
drop policy if exists "Anyone can read story likes" on public.story_likes;
drop policy if exists "Anyone can add story likes" on public.story_likes;
drop policy if exists "Anyone can remove story likes" on public.story_likes;

alter table public.comments enable row level security;
alter table public.comment_likes enable row level security;
alter table public.story_likes enable row level security;

create policy "Anyone can read comments"
  on public.comments for select to anon, authenticated using (true);
create policy "Anyone can post comments"
  on public.comments for insert to anon, authenticated with check (true);

create policy "Anyone can read comment likes"
  on public.comment_likes for select to anon, authenticated using (true);
create policy "Anyone can add comment likes"
  on public.comment_likes for insert to anon, authenticated with check (visitor_id is not null);
create policy "Anyone can remove comment likes"
  on public.comment_likes for delete to anon, authenticated using (true);

create policy "Anyone can read story likes"
  on public.story_likes for select to anon, authenticated using (true);
create policy "Anyone can add story likes"
  on public.story_likes for insert to anon, authenticated with check (visitor_id is not null);
create policy "Anyone can remove story likes"
  on public.story_likes for delete to anon, authenticated using (true);

grant usage on schema public to anon, authenticated;
grant select, insert on public.comments to anon, authenticated;
grant select, insert, delete on public.comment_likes to anon, authenticated;
grant select, insert, delete on public.story_likes to anon, authenticated;

create view public.comments_with_likes
with (security_invoker = true) as
select
  c.id,
  c.slide_number,
  c.parent_comment_id,
  c.author_name,
  c.content,
  c.created_at,
  count(cl.visitor_id)::integer as likes_count
from public.comments as c
left join public.comment_likes as cl on cl.comment_id = c.id
group by c.id;

grant select on public.comments_with_likes to anon, authenticated;
