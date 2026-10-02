-- EDVORA V14 UPGRADE
-- Public school website reliability + first platform admin bootstrap.

-- Published school branding is intentionally public; sensitive school/student documents remain private.
update storage.buckets set public=true where id='school-branding';

create or replace function public.bootstrap_first_platform_admin()
returns boolean language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then return false; end if;
  perform pg_advisory_xact_lock(hashtextextended('edvora-platform-bootstrap',0));
  if exists(select 1 from public.platform_admins) then return false; end if;
  if not exists(select 1 from public.school_memberships where user_id=auth.uid() and role='owner' and status='active') then return false; end if;
  insert into public.platform_admins(user_id) values(auth.uid()) on conflict do nothing;
  return true;
end;
$$;
revoke all on function public.bootstrap_first_platform_admin() from public,anon;
grant execute on function public.bootstrap_first_platform_admin() to authenticated;

-- If this is an existing Edvora database with no platform admin yet, promote the oldest active school owner once.
do $$
declare first_owner uuid;
begin
  if not exists(select 1 from public.platform_admins) then
    select user_id into first_owner from public.school_memberships
    where role='owner' and status='active'
    order by created_at asc
    limit 1;
    if first_owner is not null then
      insert into public.platform_admins(user_id) values(first_owner) on conflict do nothing;
    end if;
  end if;
end;
$$;

-- Replace school creation so the first Edvora owner is bootstrapped automatically.
create or replace function public.create_school(
  school_name text,
  school_type text default 'private_school'
)
returns uuid language plpgsql security definer set search_path=public as $$
declare new_school_id uuid; base_slug text; final_slug text; n integer:=0;
begin
  if auth.uid() is null then raise exception 'You must be signed in'; end if;
  if trim(coalesce(school_name,''))='' then raise exception 'School name is required'; end if;
  base_slug:=public.slugify_school_name(school_name); if base_slug='' then base_slug:='school'; end if; final_slug:=base_slug;
  while exists(select 1 from public.schools where slug=final_slug) loop n:=n+1; final_slug:=base_slug||'-'||n; end loop;
  insert into public.schools(name,school_type,slug) values(trim(school_name),coalesce(school_type,'private_school'),final_slug) returning id into new_school_id;
  insert into public.school_memberships(school_id,user_id,role,status) values(new_school_id,auth.uid(),'owner','active');
  insert into public.school_settings(school_id) values(new_school_id) on conflict do nothing;
  insert into public.website_settings(school_id,headline,subheadline) values(new_school_id,'Welcome to '||trim(school_name),'A modern learning community built around every student.') on conflict do nothing;
  insert into public.website_pages(school_id,slug,title,body) values
    (new_school_id,'about','About us','Learn more about '||trim(school_name)||', our values and our commitment to every learner.'),
    (new_school_id,'admissions','Admissions','Contact the school for current admission requirements, dates and application information.'),
    (new_school_id,'academics','Academics','Explore the school''s learning programmes, subjects and academic approach.')
    on conflict (school_id,slug) do nothing;
  insert into public.subscriptions(school_id,plan_code,status) values(new_school_id,'starter','trialing') on conflict do nothing;
  perform public.bootstrap_first_platform_admin();
  return new_school_id;
end;
$$;
revoke all on function public.create_school(text,text) from public;
grant execute on function public.create_school(text,text) to authenticated;

drop policy if exists "platform admins read all schools" on public.schools;
create policy "platform admins read all schools" on public.schools for select to authenticated using(public.is_platform_admin() or public.is_school_member(id));

-- Ensure existing schools have a usable website configuration and starter pages.
insert into public.website_settings(school_id,headline,subheadline)
select id,'Welcome to '||name,'A modern learning community built around every student.'
from public.schools s where not exists(select 1 from public.website_settings w where w.school_id=s.id);

insert into public.website_pages(school_id,slug,title,body)
select s.id,'about','About us','Learn more about '||s.name||', our values and our commitment to every learner.'
from public.schools s where not exists(select 1 from public.website_pages p where p.school_id=s.id and p.slug='about');
insert into public.website_pages(school_id,slug,title,body)
select s.id,'admissions','Admissions','Contact the school for current admission requirements, dates and application information.'
from public.schools s where not exists(select 1 from public.website_pages p where p.school_id=s.id and p.slug='admissions');
insert into public.website_pages(school_id,slug,title,body)
select s.id,'academics','Academics','Explore the school''s learning programmes, subjects and academic approach.'
from public.schools s where not exists(select 1 from public.website_pages p where p.school_id=s.id and p.slug='academics');

-- Existing owners can claim the first platform-admin slot by creating/using their dashboard after this migration.
