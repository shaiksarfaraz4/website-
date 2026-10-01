-- DATONIX: run this whole file once in Supabase > SQL Editor.
-- BEFORE RUNNING: replace YOUR_ADMIN_EMAIL@example.com (search for it below).

-- 1. Settings (from your Settings tab)
create table if not exists settings (key text primary key, value numeric not null);
insert into settings values
 ('shift_hours',8),('daily_target_hours',5.30),('working_days',26),
 ('monthly_target_hours',137.8),('tier_18k',18000),('tier_15k',15000)
on conflict (key) do nothing;

-- 2. Tables
create table if not exists employees (
  employee_id text primary key,
  auth_user_id uuid unique references auth.users(id) on delete set null,
  name text not null,
  email text unique not null,
  device text,                      -- "Phone ID" in the sheet (shared device, not unique)
  joining_date date,
  monthly_salary numeric(10,2) not null default 0,
  status text not null default 'Active',
  role_title text,                  -- "Remarks" in Employee Master
  role text not null default 'employee' check (role in ('employee','admin'))
);

create table if not exists daily_entries (
  id bigint generated always as identity primary key,
  entry_date date not null,
  employee_id text not null references employees(employee_id),
  shift text not null default 'Morning',
  productive_hours numeric(6,2) not null default 0,
  rejected_videos numeric(6,2) not null default 0,
  rejection_pct numeric(5,1) not null default 0,
  remarks text,
  unique (entry_date, employee_id, shift)
);

create table if not exists payouts (
  month text not null,              -- '2026-09'
  employee_id text not null references employees(employee_id),
  adjustment numeric(10,2) not null default 0,
  adjustment_reason text,
  payment_status text not null default 'Pending' check (payment_status in ('Pending','Paid')),
  paid_on date,
  primary key (month, employee_id)
);

-- 3. Employees from your sheet (+ one admin row)
insert into employees (employee_id,name,email,device,joining_date,monthly_salary,role_title,role) values
('EMP001','vijaylakshmi','sarfaraz1shaik+2@gmail.com','SN2','2026-08-01',18000,'Data Collection Specialist','employee'),
('EMP002','A. Dora babu','sarfaraz1shaik+4@gmail.com','SN4','2026-08-01',15000,'Data Collection Specialist','employee'),
('EMP003','shreshta','sarfaraz1shaik+3@gmail.com','SN3','2026-08-15',18000,'Data Collection Specialist','employee'),
('EMP004','G. Mounika','sarfaraz1shaik+5@gmail.com','SN5','2026-08-15',18000,'Data Collection Specialist','employee'),
('EMP007','D. Lakshmi sai sushma','sarfaraz1shaik+8@gmail.com','SN2','2026-09-01',15000,'Trainee Recorder','employee'),
('EMP008','A. Venkateswaramma','sarfaraz1shaik+9@gmail.com','SN4','2026-09-01',15000,'Trainee Recorder','employee'),
('EMP009','V. Sivaramkrishna','sarfaraz1shaik+14@gmail.com','SN1','2026-09-01',18000,'Trainee Recorder','employee'),
('EMP010','nagamani','sarfaraz1shaik+15@gmail.com','SN3','2026-09-01',18000,'Trainee Recorder','employee'),
('EMP011','Anitha','sarfaraz1shaik+13@gmail.com','SN2','2026-09-01',18000,'Trainee Recorder','employee'),
('EMP012','sk. Sahil akram','sarfaraz1shaik+20@gmail.com','SN2','2026-09-01',18000,'Trainee Recorder','employee'),
('EMP013','B. Nanda kumar','sarfaraz1shaik+28@gmail.com','SN2','2026-09-01',18000,'Trainee Recorder','employee'),
('EMP014','B. Anusha','sarfaraz1shaik+44@gmail.com','SN4','2026-09-07',18000,'Trainee Recorder','employee'),
('EMP015','k. Ravi teja','sarfaraz1shaik+48@gmail.com','SN3','2026-09-08',18000,'Trainee Recorder','employee'),
('ADMIN01','Admin','YOUR_ADMIN_EMAIL@example.com',null,null,0,'Administrator','admin')
on conflict (employee_id) do nothing;

-- 4. The 13 daily rows I could see in your sheet (n8n loads the rest)
insert into daily_entries (entry_date,employee_id,shift,productive_hours,rejected_videos,rejection_pct,remarks) values
('2026-09-01','EMP001','Morning',2.53,0,0,'left'),
('2026-09-01','EMP002','Morning',0.97,0,1.0,'Suspended videos - 9 videos'),
('2026-09-01','EMP003','Morning',1.76,0,0,'Left'),
('2026-09-01','EMP004','Morning',2.16,0,0,'Suspended ID - 2 videos'),
('2026-09-02','EMP008','Morning',0.93,2,100,'Full target achieved'),
('2026-09-02','EMP002','Morning',2.56,2,78.1,'Acceptable target'),
('2026-09-02','EMP007','Morning',1.93,1,51.8,'Excellent recording'),
('2026-09-02','EMP004','Morning',2.16,2,92.6,'Met acceptable floor'),
('2026-09-02','EMP009','Afternoon',0.73,0.19,26.0,'Device: SN 1'),
('2026-09-02','EMP010','Afternoon',0.12,0,0,'Device: SN 3'),
('2026-09-02','EMP011','Afternoon',0.57,0,0,'Device: SN 2'),
('2026-09-03','EMP004','Morning',2.50,0.2,8.0,null),
('2026-09-03','EMP002','Morning',3.30,0,0,null)
on conflict do nothing;

-- 5. Security helpers
create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from employees where auth_user_id = auth.uid() and role = 'admin')
$$;
create or replace function my_employee_id() returns text
language sql stable security definer set search_path = public as $$
  select employee_id from employees where auth_user_id = auth.uid()
$$;

-- 6. Auto-link a new login to the employee row with the same email
create or replace function link_auth_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update employees set auth_user_id = new.id where lower(email) = lower(new.email);
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function link_auth_user();
-- link users that already exist
update employees e set auth_user_id = u.id from auth.users u
 where lower(u.email) = lower(e.email) and e.auth_user_id is null;

-- 7. Row Level Security
alter table settings      enable row level security;
alter table employees     enable row level security;
alter table daily_entries enable row level security;
alter table payouts       enable row level security;

create policy settings_read on settings for select to authenticated using (true);
create policy emp_read  on employees for select to authenticated using (auth_user_id = auth.uid() or is_admin());
create policy emp_write on employees for all    to authenticated using (is_admin()) with check (is_admin());
create policy de_read   on daily_entries for select to authenticated using (employee_id = my_employee_id() or is_admin());
create policy de_write  on daily_entries for all    to authenticated using (is_admin()) with check (is_admin());
create policy pay_read  on payouts for select to authenticated using (employee_id = my_employee_id() or is_admin());
create policy pay_write on payouts for all    to authenticated using (is_admin()) with check (is_admin());

-- 8. Calculated views (replace the spreadsheet formulas)
-- Daily earned = min(hours, target) x hourly rate x (1 - rejection%)
create or replace view v_daily with (security_invoker = true) as
select d.id, d.entry_date, d.employee_id, e.name, d.shift,
  d.productive_hours, d.rejected_videos, d.rejection_pct, d.remarks,
  round(least(d.productive_hours,(select value from settings where key='daily_target_hours'))
        / (select value from settings where key='daily_target_hours') * 100, 1) as productivity_pct,
  case when d.productive_hours >= (select value from settings where key='daily_target_hours')
       then 'Target Met' else 'Below Target' end as target_status,
  round(least(d.productive_hours,(select value from settings where key='daily_target_hours'))
        * (e.monthly_salary / (select value from settings where key='monthly_target_hours'))
        * (1 - d.rejection_pct/100), 2) as daily_earned
from daily_entries d join employees e on e.employee_id = d.employee_id;

create or replace view v_monthly with (security_invoker = true) as
with m as (
  select to_char(entry_date,'YYYY-MM') as month, employee_id,
    count(distinct entry_date) as days_present,
    sum(productive_hours) as productive_hours,
    sum(rejected_videos) as rejected_videos,
    sum(productive_hours*rejection_pct)/nullif(sum(productive_hours),0) as rejection_pct,
    sum(daily_earned) as earned
  from v_daily group by 1,2)
select m.month, m.employee_id, e.name, e.monthly_salary, m.days_present,
  m.days_present * (select value from settings where key='shift_hours') as shift_hours,
  round(m.productive_hours,2) as productive_hours,
  round(m.productive_hours/nullif(m.days_present,0),2) as avg_daily_hours,
  round(m.productive_hours/(select value from settings where key='monthly_target_hours')*100,1) as productivity_pct,
  round(m.rejected_videos,2) as rejected_videos,
  round(coalesce(m.rejection_pct,0),1) as rejection_pct,
  round(m.earned,2) as payout,
  coalesce(p.adjustment,0) as adjustment,
  round(m.earned + coalesce(p.adjustment,0),2) as final_payout,
  coalesce(p.payment_status,'Pending') as payment_status
from m join employees e on e.employee_id = m.employee_id
left join payouts p on p.month = m.month and p.employee_id = m.employee_id;
