-- DESTRUCTIVO: elimina comentarios, likes, vistas y las políticas RLS asociadas.
-- Esto borra también todos los comentarios y likes guardados.

drop view if exists public.comments_with_likes;
drop table if exists public.comment_likes;
drop table if exists public.story_likes;
drop table if exists public.comments;
drop function if exists public.validate_comment_parent_slide();

-- Las políticas RLS se eliminan automáticamente al borrar sus tablas.
