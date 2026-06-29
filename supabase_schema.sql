create extension if not exists "pgcrypto";

create table if not exists clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  company_type text,
  fee_amount numeric default 0,
  fee_currency text default '$',
  archived boolean default false,
  archived_at timestamptz,
  created_at timestamptz default now()
);

create table if not exists recurring_tasks (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete cascade,
  name text not null,
  frequency text default 'mensual',
  due_day int default 25,
  start_month text,
  archived boolean default false,
  archived_at timestamptz,
  created_at timestamptz default now()
);

create table if not exists monthly_tasks (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete cascade,
  recurring_task_id uuid references recurring_tasks(id) on delete set null,
  month date not null,
  name text not null,
  due_date date,
  status text default 'pendiente',
  notes text,
  created_at timestamptz default now(),
  unique(client_id, recurring_task_id, month)
);

create table if not exists monthly_fees (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete cascade,
  month date not null,
  amount numeric default 0,
  currency text default '$',
  paid_amount numeric default 0,
  status text default 'pendiente',
  paid_at timestamptz,
  notes text,
  created_at timestamptz default now(),
  unique(client_id, month)
);

alter table clients add column if not exists archived boolean default false;
alter table clients add column if not exists archived_at timestamptz;
alter table recurring_tasks add column if not exists start_month text;
alter table recurring_tasks add column if not exists archived boolean default false;
alter table recurring_tasks add column if not exists archived_at timestamptz;
alter table monthly_fees add column if not exists paid_amount numeric default 0;
alter table monthly_fees add column if not exists paid_at timestamptz;

-- Si todavía no tienen RLS configurado, estas políticas permiten usar la app simple con la publishable key.
alter table clients enable row level security;
alter table recurring_tasks enable row level security;
alter table monthly_tasks enable row level security;
alter table monthly_fees enable row level security;

do $$ begin
  create policy "allow all clients" on clients for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "allow all recurring" on recurring_tasks for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "allow all monthly tasks" on monthly_tasks for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "allow all fees" on monthly_fees for all using (true) with check (true);
exception when duplicate_object then null; end $$;

create table if not exists deleted_monthly_tasks (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete cascade,
  recurring_task_id uuid references recurring_tasks(id) on delete cascade,
  month date not null,
  task_name text,
  deleted_at timestamptz default now(),
  unique(client_id, recurring_task_id, month)
);

alter table deleted_monthly_tasks enable row level security;
do $$ begin
  create policy "allow all deleted monthly tasks" on deleted_monthly_tasks for all using (true) with check (true);
exception when duplicate_object then null; end $$;


-- Habilitar Realtime para que los cambios aparezcan en otros dispositivos sin actualizar.
alter table clients replica identity full;
alter table recurring_tasks replica identity full;
alter table monthly_tasks replica identity full;
alter table monthly_fees replica identity full;
alter table deleted_monthly_tasks replica identity full;

do $$ begin
  alter publication supabase_realtime add table clients;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table recurring_tasks;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table monthly_tasks;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table monthly_fees;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table deleted_monthly_tasks;
exception when duplicate_object then null; end $$;


create table if not exists monthly_due_dates (
  id uuid primary key default gen_random_uuid(),
  month date not null,
  task_name text not null,
  due_date date not null,
  created_at timestamptz default now(),
  unique(month, task_name)
);

alter table monthly_due_dates enable row level security;
do $$ begin
  create policy "allow all monthly due dates" on monthly_due_dates for all using (true) with check (true);
exception when duplicate_object then null; end $$;

alter table monthly_due_dates replica identity full;
do $$ begin
  alter publication supabase_realtime add table monthly_due_dates;
exception when duplicate_object then null; end $$;


-- Mejoras v9: estados, prioridades y tareas maestras
alter table monthly_tasks add column if not exists priority text default 'media';
alter table recurring_tasks add column if not exists priority text default 'media';
alter table recurring_tasks add column if not exists initial_status text default 'pendiente';

create table if not exists master_task_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  frequency text default 'mensual',
  due_day int default 25,
  initial_status text default 'pendiente',
  priority text default 'media',
  company_type text,
  created_at timestamptz default now()
);

alter table master_task_templates enable row level security;
do $$ begin
  create policy "allow all master templates" on master_task_templates for all using (true) with check (true);
exception when duplicate_object then null; end $$;

alter table master_task_templates replica identity full;
do $$ begin
  alter publication supabase_realtime add table master_task_templates;
exception when duplicate_object then null; end $$;

-- Mejoras v10: módulo ATERPEA, habitaciones, estudiantes, visitas y lista de espera
create table if not exists aterpea_rooms (
  id uuid primary key default gen_random_uuid(),
  room_number text not null,
  capacity int not null default 2,
  room_type text,
  floor text,
  notes text,
  created_at timestamptz default now()
);

alter table aterpea_rooms add column if not exists room_type text;

create table if not exists aterpea_students (
  id uuid primary key default gen_random_uuid(),
  first_name text,
  last_name text,
  document text,
  birth_date date,
  phone text,
  email text,
  emergency_contact text,
  nationality text,
  room_id uuid references aterpea_rooms(id) on delete set null,
  contract_start date,
  contract_end date,
  monthly_amount numeric default 0,
  deposit_amount numeric default 0,
  deposit_total numeric default 0,
  deposit_paid numeric default 0,
  contract_status text default 'no_enviado',
  status text default 'activo',
  notes text,
  created_at timestamptz default now()
);

create table if not exists aterpea_visits (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  origin text,
  career text,
  visit_at timestamptz,
  status text default 'pendiente',
  notes text,
  created_at timestamptz default now()
);

create table if not exists aterpea_waitlist (
  id uuid primary key default gen_random_uuid(),
  position int not null,
  name text not null,
  phone text,
  email text,
  origin text,
  source text default 'consulta',
  status text default 'espera',
  notes text,
  created_at timestamptz default now()
);

alter table aterpea_rooms enable row level security;
alter table aterpea_students enable row level security;
alter table aterpea_visits enable row level security;
alter table aterpea_waitlist enable row level security;

do $$ begin
  create policy "allow all aterpea rooms" on aterpea_rooms for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "allow all aterpea students" on aterpea_students for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "allow all aterpea visits" on aterpea_visits for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "allow all aterpea waitlist" on aterpea_waitlist for all using (true) with check (true);
exception when duplicate_object then null; end $$;

alter table aterpea_rooms replica identity full;
alter table aterpea_students replica identity full;
alter table aterpea_visits replica identity full;
alter table aterpea_waitlist replica identity full;

do $$ begin
  alter publication supabase_realtime add table aterpea_rooms;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table aterpea_students;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table aterpea_visits;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table aterpea_waitlist;
exception when duplicate_object then null; end $$;

-- Carga inicial / corrección de las 13 habitaciones de ATERPEA.
-- Si ya existen, actualiza capacidad y tipo según la distribución real.
insert into aterpea_rooms (room_number, capacity, room_type)
select v.room_number, v.capacity, v.room_type
from (values
  ('1',3,'Triple baño compartido'),
  ('2',2,'Doble baño compartido'),
  ('3',2,'Doble baño compartido'),
  ('4',3,'Triple baño compartido'),
  ('5',2,'Doble baño compartido'),
  ('6',2,'Doble baño compartido'),
  ('7',3,'Triple baño compartido'),
  ('8',2,'Doble baño compartido'),
  ('9',2,'Doble baño compartido'),
  ('10',2,'Doble plus con baño'),
  ('11',2,'Doble con baño privado'),
  ('12',2,'Doble con baño privado'),
  ('13',3,'Triple con baño privado')
) as v(room_number, capacity, room_type)
where not exists (select 1 from aterpea_rooms r where r.room_number=v.room_number);

update aterpea_rooms r set
  capacity = v.capacity,
  room_type = v.room_type
from (values
  ('1',3,'Triple baño compartido'),
  ('2',2,'Doble baño compartido'),
  ('3',2,'Doble baño compartido'),
  ('4',3,'Triple baño compartido'),
  ('5',2,'Doble baño compartido'),
  ('6',2,'Doble baño compartido'),
  ('7',3,'Triple baño compartido'),
  ('8',2,'Doble baño compartido'),
  ('9',2,'Doble baño compartido'),
  ('10',2,'Doble plus con baño'),
  ('11',2,'Doble con baño privado'),
  ('12',2,'Doble con baño privado'),
  ('13',3,'Triple con baño privado')
) as v(room_number, capacity, room_type)
where r.room_number = v.room_number;

-- Mejoras v12 ATERPEA: precios editables, reservas y bajas
alter table aterpea_rooms add column if not exists monthly_price numeric default 0;
alter table aterpea_students add column if not exists exit_date date;
alter table aterpea_students add column if not exists deposit_total numeric default 0;
alter table aterpea_students add column if not exists deposit_paid numeric default 0;
alter table aterpea_students add column if not exists contract_status text default 'no_enviado';

-- Compatibilidad con versiones anteriores: si había garantía en deposit_amount, se toma como total.
update aterpea_students set deposit_total = deposit_amount where coalesce(deposit_total,0)=0 and coalesce(deposit_amount,0)>0;
update aterpea_students set deposit_paid = 0 where deposit_paid is null;
update aterpea_students set contract_status = 'no_enviado' where contract_status is null;

-- Precios base 2026 por tipo de habitación. Se pueden modificar luego desde la app.
update aterpea_rooms r set monthly_price = v.monthly_price
from (values
  ('Triple baño compartido',15700),
  ('Triple con baño privado',16700),
  ('Doble baño compartido',18700),
  ('Doble con baño privado',19700),
  ('Doble plus con baño',20700)
) as v(room_type, monthly_price)
where r.room_type = v.room_type and coalesce(r.monthly_price,0)=0;

-- Mejoras v14 ATERPEA: lista de espera inteligente y campos de preferencia
alter table aterpea_waitlist add column if not exists desired_year text;
alter table aterpea_waitlist add column if not exists desired_month text;
alter table aterpea_waitlist add column if not exists room_preference text;
alter table aterpea_waitlist add column if not exists priority text default 'media';

update aterpea_waitlist set desired_year = 'flexible' where desired_year is null;
update aterpea_waitlist set desired_month = 'Flexible' where desired_month is null;
update aterpea_waitlist set room_preference = 'Flexible' where room_preference is null;
update aterpea_waitlist set priority = 'media' where priority is null;

-- Mejoras v15: acceso por usuario y rol.
-- Ahora la app requiere login de Supabase Auth.
-- Roles disponibles:
--   admin   = ve todo el calendario y ATERPEA
--   aterpea = ve solamente el módulo ATERPEA

create table if not exists user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','aterpea')),
  created_at timestamptz default now()
);

alter table user_roles enable row level security;

create or replace function public.app_current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select role from public.user_roles where user_id = auth.uid()), 'admin')
$$;

-- Eliminar políticas abiertas de versiones anteriores para que el acceso restringido sea real.
drop policy if exists "allow all clients" on clients;
drop policy if exists "allow all recurring" on recurring_tasks;
drop policy if exists "allow all monthly tasks" on monthly_tasks;
drop policy if exists "allow all fees" on monthly_fees;
drop policy if exists "allow all deleted monthly tasks" on deleted_monthly_tasks;
drop policy if exists "allow all monthly due dates" on monthly_due_dates;
drop policy if exists "allow all master templates" on master_task_templates;
drop policy if exists "allow all aterpea rooms" on aterpea_rooms;
drop policy if exists "allow all aterpea students" on aterpea_students;
drop policy if exists "allow all aterpea visits" on aterpea_visits;
drop policy if exists "allow all aterpea waitlist" on aterpea_waitlist;
drop policy if exists "user roles select own" on user_roles;
drop policy if exists "user roles admin all" on user_roles;
drop policy if exists "admin all clients" on clients;
drop policy if exists "admin all recurring" on recurring_tasks;
drop policy if exists "admin all monthly tasks" on monthly_tasks;
drop policy if exists "admin all fees" on monthly_fees;
drop policy if exists "admin all deleted monthly tasks" on deleted_monthly_tasks;
drop policy if exists "admin all monthly due dates" on monthly_due_dates;
drop policy if exists "admin all master templates" on master_task_templates;
drop policy if exists "admin aterpea rooms all" on aterpea_rooms;
drop policy if exists "admin aterpea students all" on aterpea_students;
drop policy if exists "admin aterpea visits all" on aterpea_visits;
drop policy if exists "admin aterpea waitlist all" on aterpea_waitlist;
drop policy if exists "aterpea rooms access" on aterpea_rooms;
drop policy if exists "aterpea students access" on aterpea_students;
drop policy if exists "aterpea visits access" on aterpea_visits;
drop policy if exists "aterpea waitlist access" on aterpea_waitlist;

-- Rol del usuario: cada usuario lee su propio rol; el admin puede administrar roles.
create policy "user roles select own" on user_roles
for select using (user_id = auth.uid() or public.app_current_role() = 'admin');
create policy "user roles admin all" on user_roles
for all using (public.app_current_role() = 'admin') with check (public.app_current_role() = 'admin');

-- Tablas del calendario contable: sólo administradores.
create policy "admin all clients" on clients for all using (public.app_current_role() = 'admin') with check (public.app_current_role() = 'admin');
create policy "admin all recurring" on recurring_tasks for all using (public.app_current_role() = 'admin') with check (public.app_current_role() = 'admin');
create policy "admin all monthly tasks" on monthly_tasks for all using (public.app_current_role() = 'admin') with check (public.app_current_role() = 'admin');
create policy "admin all fees" on monthly_fees for all using (public.app_current_role() = 'admin') with check (public.app_current_role() = 'admin');
create policy "admin all deleted monthly tasks" on deleted_monthly_tasks for all using (public.app_current_role() = 'admin') with check (public.app_current_role() = 'admin');
create policy "admin all monthly due dates" on monthly_due_dates for all using (public.app_current_role() = 'admin') with check (public.app_current_role() = 'admin');
create policy "admin all master templates" on master_task_templates for all using (public.app_current_role() = 'admin') with check (public.app_current_role() = 'admin');

-- Tablas de ATERPEA: administradores y usuarios con rol aterpea.
create policy "aterpea rooms access" on aterpea_rooms for all
using (public.app_current_role() in ('admin','aterpea'))
with check (public.app_current_role() in ('admin','aterpea'));
create policy "aterpea students access" on aterpea_students for all
using (public.app_current_role() in ('admin','aterpea'))
with check (public.app_current_role() in ('admin','aterpea'));
create policy "aterpea visits access" on aterpea_visits for all
using (public.app_current_role() in ('admin','aterpea'))
with check (public.app_current_role() in ('admin','aterpea'));
create policy "aterpea waitlist access" on aterpea_waitlist for all
using (public.app_current_role() in ('admin','aterpea'))
with check (public.app_current_role() in ('admin','aterpea'));

-- Para asignar un usuario sólo a ATERPEA:
-- 1) Crearlo en Supabase > Authentication > Users.
-- 2) Copiar su id.
-- 3) Ejecutar:
-- insert into user_roles (user_id, role) values ('PEGAR_UUID_DEL_USUARIO', 'aterpea')
-- on conflict (user_id) do update set role = 'aterpea';
--
-- Para convertir un usuario en administrador:
-- insert into user_roles (user_id, role) values ('PEGAR_UUID_DEL_USUARIO', 'admin')
-- on conflict (user_id) do update set role = 'admin';


-- =========================================================
-- ACCESOS SIMPLES
-- =========================================================
-- La app usa SOLO dos roles:
--   admin   = ve todo
--   aterpea = ve solamente ATERPEA
--
-- Para asignar tu usuario como administrador, cambiá el email si hace falta y ejecutá:
-- insert into public.user_roles (user_id, role)
-- select id, 'admin' from auth.users where email = 'alegriot@gmail.com'
-- on conflict (user_id) do update set role = 'admin';
--
-- Para asignar a la empleada acceso sólo a ATERPEA:
-- 1) Primero creá su usuario en Authentication > Users.
-- 2) Después cambiá el email de abajo por el de ella y ejecutá:
-- insert into public.user_roles (user_id, role)
-- select id, 'aterpea' from auth.users where email = 'email-de-la-empleada@ejemplo.com'
-- on conflict (user_id) do update set role = 'aterpea';
--
-- Para revisar los roles cargados:
-- select u.email, r.role
-- from auth.users u
-- left join public.user_roles r on r.user_id = u.id
-- order by u.email;


-- =========================================================
-- USUARIOS DESDE LA APP (simple)
-- =========================================================
-- Estas funciones permiten que un admin asigne rol por email desde Configuración > Usuarios.
-- Nota: el usuario debe existir primero en Authentication > Users.

create or replace function public.app_set_user_role(p_email text, p_role text)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
begin
  if public.app_current_role() <> 'admin' then
    raise exception 'Sólo un administrador puede cambiar roles';
  end if;

  if p_role not in ('admin','aterpea') then
    raise exception 'Rol inválido';
  end if;

  select id into v_user_id
  from auth.users
  where lower(email) = lower(p_email)
  limit 1;

  if v_user_id is null then
    return false;
  end if;

  insert into public.user_roles (user_id, role)
  values (v_user_id, p_role)
  on conflict (user_id) do update set role = excluded.role;

  return true;
end;
$$;

create or replace function public.app_remove_user_role(p_email text)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
begin
  if public.app_current_role() <> 'admin' then
    raise exception 'Sólo un administrador puede cambiar roles';
  end if;

  select id into v_user_id
  from auth.users
  where lower(email) = lower(p_email)
  limit 1;

  if v_user_id is null then
    return false;
  end if;

  delete from public.user_roles where user_id = v_user_id;
  return true;
end;
$$;

create or replace function public.app_list_user_roles()
returns table(email text, role text, created_at timestamptz)
language sql
security definer
set search_path = public, auth
as $$
  select u.email::text, r.role, r.created_at
  from public.user_roles r
  join auth.users u on u.id = r.user_id
  where public.app_current_role() = 'admin'
  order by u.email
$$;


-- FIX v18: columnas necesarias para estudiantes ATERPEA si la tabla ya existía de una versión anterior.
alter table public.aterpea_students add column if not exists first_name text;
alter table public.aterpea_students add column if not exists last_name text;
alter table public.aterpea_students add column if not exists document text;
alter table public.aterpea_students add column if not exists birth_date date;
alter table public.aterpea_students add column if not exists phone text;
alter table public.aterpea_students add column if not exists email text;
alter table public.aterpea_students add column if not exists emergency_contact text;
alter table public.aterpea_students add column if not exists nationality text;
alter table public.aterpea_students add column if not exists room_id uuid references public.aterpea_rooms(id) on delete set null;
alter table public.aterpea_students add column if not exists contract_start date;
alter table public.aterpea_students add column if not exists contract_end date;
alter table public.aterpea_students add column if not exists monthly_amount numeric default 0;
alter table public.aterpea_students add column if not exists deposit_amount numeric default 0;
alter table public.aterpea_students add column if not exists deposit_total numeric default 0;
alter table public.aterpea_students add column if not exists deposit_paid numeric default 0;
alter table public.aterpea_students add column if not exists contract_status text default 'no_enviado';
alter table public.aterpea_students add column if not exists status text default 'activo';
alter table public.aterpea_students add column if not exists notes text;
alter table public.aterpea_students add column if not exists created_at timestamptz default now();

-- OPCIONAL: detectar estudiantes duplicados exactos (mismo nombre, apellido, habitación, estado y fecha de inicio)
-- Ejecutar solo para revisar. No borra nada.
-- select lower(coalesce(first_name,'')) as nombre, lower(coalesce(last_name,'')) as apellido, room_id, status, contract_start, count(*)
-- from public.aterpea_students
-- group by 1,2,3,4,5
-- having count(*) > 1;

-- OPCIONAL: borrar duplicados exactos dejando el más antiguo.
-- Usar solo si confirmaste que son duplicados reales.
-- with d as (
--   select id, row_number() over (
--     partition by lower(coalesce(first_name,'')), lower(coalesce(last_name,'')), room_id, status, contract_start
--     order by created_at nulls last, id
--   ) rn
--   from public.aterpea_students
-- )
-- delete from public.aterpea_students s
-- using d
-- where s.id = d.id and d.rn > 1;
