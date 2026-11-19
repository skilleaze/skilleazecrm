-- Stratt HQ · team access
-- Muneez Ahmed: marketing role, super admin. Home page is Marketing; View as switches to any other person.
insert into staff_access (email, full_name, role, access_level) values
  ('marketing@stratt.ae', 'Muneez Ahmed', 'marketing', 'super_admin')
on conflict (email) do update set full_name = excluded.full_name, role = excluded.role, access_level = excluded.access_level;

-- If Muneez has already signed in once, apply it to his profile too.
update profiles set full_name = 'Muneez Ahmed', role = 'marketing', access_level = 'super_admin', active = true
where lower(email) = 'marketing@stratt.ae';

-- Check
select email, full_name, role, access_level from staff_access order by email;
