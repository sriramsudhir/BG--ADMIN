-- Enable RLS
alter table auth.users enable row level security;

-- Create users table
create table public.users (
  id uuid references auth.users on delete cascade not null primary key,
  email text unique not null,
  name text,
  role text not null check (role in ('ADMIN', 'USER')) default 'USER',
  credits integer not null default 10,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on users table
alter table public.users enable row level security;

-- Create images table
create table public.images (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.users on delete cascade not null,
  original_url text not null,
  processed_url text,
  status text not null check (status in ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED')) default 'PENDING',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on images table
alter table public.images enable row level security;

-- Create website_content table
create table public.website_content (
  id text primary key,
  content jsonb not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on website_content table
alter table public.website_content enable row level security;

-- Create RLS policies
create policy "Users can view their own data"
  on public.users
  for select
  using (auth.uid() = id);

create policy "Admins can view all users"
  on public.users
  for select
  using (
    exists (
      select 1 from public.users
      where id = auth.uid() and role = 'ADMIN'
    )
  );

create policy "Users can view their own images"
  on public.images
  for select
  using (auth.uid() = user_id);

create policy "Admins can view all images"
  on public.images
  for select
  using (
    exists (
      select 1 from public.users
      where id = auth.uid() and role = 'ADMIN'
    )
  );

create policy "Admins can manage website content"
  on public.website_content
  for all
  using (
    exists (
      select 1 from public.users
      where id = auth.uid() and role = 'ADMIN'
    )
  );

-- Create function to handle new user registration
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, email, role)
  values (new.id, new.email, 'USER');
  return new;
end;
$$;

-- Create trigger for new user registration
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Insert initial website content
insert into public.website_content (id, content) values
('hero', '{"title": "Free Background Removal", "subtitle": "Remove backgrounds instantly with our AI tool", "cta": "Try Now - It''s Free!"}'),
('features', '[]'),
('pricing', '[]'),
('testimonials', '[]');