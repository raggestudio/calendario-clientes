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
