-- Stratt HQ · real figures from Financial Overview.xlsx (March to October 2026)
-- Run after schema.sql.

insert into deals (name, commission_aed, status, received_on) values
('Binghatti', 23275, 'received', '2026-03-01'),
('Imtiaz', 31051, 'received', '2026-05-01'),
('Nshama', 6835, 'received', '2026-05-01'),
('Nshama', 6835, 'received', '2026-10-01'),
('Ghazal SLS 2B', 2025, 'received', '2026-10-01'),
('Ghazal SLS 1B', 1125, 'received', '2026-10-01'),
('Majestine (Laurent claim)', 15000, 'under_review', null),
('Paramount Tower B (Laurent claim)', 16506, 'under_review', null);

insert into transactions (month, direction, category, description, amount_aed)
select received_on, 'in', 'commission', name, commission_aed from deals where status = 'received';

insert into transactions (month, direction, category, description, amount_aed) values
('2026-03-01','out','salaries','Salaries',57000),('2026-03-01','out','utilities','Utilities and communication',3300),('2026-03-01','out','marketing','Marketing',249),('2026-03-01','out','listing_portals','Bayut and Dubizzle',6300.11),('2026-03-01','out','rent_visas_admin','Rent, visas and admin',10588),('2026-03-01','out','petty_cash','Petty cash and Cafesti',574),
('2026-04-01','out','salaries','Salaries',27000),('2026-04-01','out','utilities','Utilities and communication',3873.75),('2026-04-01','out','marketing','Marketing',300),('2026-04-01','out','listing_portals','Bayut and Property Monitor',12668.5),('2026-04-01','out','rent_visas_admin','Rent, visas and admin',50131.5),('2026-04-01','out','petty_cash','Petty cash and Cafesti',876),
('2026-05-01','out','salaries','Salaries',22000),('2026-05-01','out','utilities','Utilities and communication',2207.36),('2026-05-01','out','petty_cash','Petty cash and Cafesti',949.12),
('2026-06-01','out','salaries','Salaries',10000),('2026-06-01','out','utilities','Utilities and communication',2207.36),('2026-06-01','out','petty_cash','Petty cash and Cafesti',566.55),
('2026-07-01','out','salaries','Salaries',10000),('2026-07-01','out','utilities','Utilities and communication',1834.92),('2026-07-01','out','listing_portals','Bayut',3255),('2026-07-01','out','petty_cash','Petty cash and Cafesti',376),
('2026-08-01','out','salaries','Salaries',16000),('2026-08-01','out','utilities','Utilities and communication',2427.03),('2026-08-01','out','listing_portals','Bayut',3255),('2026-08-01','out','rent_visas_admin','Rent, visas and admin',15000),('2026-08-01','out','petty_cash','Petty cash and Cafesti',937.38),
('2026-09-01','out','salaries','Salaries',26000),('2026-09-01','out','utilities','Utilities and communication',2324.28),('2026-09-01','out','listing_portals','Bayut',3255),('2026-09-01','out','rent_visas_admin','Rent, visas and admin',20000),('2026-09-01','out','petty_cash','Petty cash and Cafesti',709.97),
('2026-10-01','out','salaries','Salaries',23000),('2026-10-01','out','utilities','Utilities and communication',7739.25),('2026-10-01','out','listing_portals','Bayut',3255),('2026-10-01','out','petty_cash','Petty cash and Cafesti',1157.84);

insert into marketing_spend (item, channel, amount_aed, month) values
('Bayut and Dubizzle','listing_portal',6300.11,'2026-03-01'),('Marketing subscription','marketing',249,'2026-03-01'),
('Bayut','listing_portal',6400,'2026-04-01'),('Property Monitor, quarterly','market_data',6268.5,'2026-04-01'),('Other marketing','marketing',300,'2026-04-01'),
('Bayut','listing_portal',3255,'2026-07-01'),('Bayut','listing_portal',3255,'2026-08-01'),
('Bayut','listing_portal',3255,'2026-09-01'),('Bayut','listing_portal',3255,'2026-10-01');

insert into petty_cash (entry_date, description, category, amount_aed) values
('2026-03-01','Petty cash','petty_cash',200),('2026-03-01','Cafesti','office',374),
('2026-04-01','Petty cash','petty_cash',500),('2026-04-01','Cafesti','office',376),
('2026-05-01','Petty cash','petty_cash',573.12),('2026-05-01','Cafesti','office',376),
('2026-06-01','Petty cash','petty_cash',190.55),('2026-06-01','Cafesti','office',376),
('2026-07-01','Cafesti','office',376),
('2026-08-01','Petty cash','petty_cash',561.38),('2026-08-01','Cafesti','office',376),
('2026-09-01','Petty cash','petty_cash',333.97),('2026-09-01','Cafesti','office',376),
('2026-10-01','Petty cash','petty_cash',781.84),('2026-10-01','Cafesti','office',376);

insert into employees (full_name, status) values
('Sherra','active'),('Muneez','active'),('Ghazal','active'),('Sameera','active'),('Saifu','left'),('Lydia','left'),('Laurent','settlement_pending');

insert into payroll (employee_id, month, amount_aed)
select e.id, v.m::date, v.a from (values
('Sherra','2026-04-01',9000),('Muneez','2026-04-01',9000),('Lydia','2026-04-01',6000),('Saifu','2026-04-01',3000),
('Sherra','2026-05-01',7000),('Muneez','2026-05-01',6000),('Lydia','2026-05-01',6000),('Saifu','2026-05-01',3000),
('Saifu','2026-06-01',3000),('Sherra','2026-06-01',7000),
('Saifu','2026-07-01',3000),('Sherra','2026-07-01',7000),
('Saifu','2026-08-01',3000),('Sherra','2026-08-01',7000),('Muneez','2026-08-01',6000),
('Saifu','2026-09-01',3000),('Sherra','2026-09-01',7000),('Muneez','2026-09-01',6000),('Ghazal','2026-09-01',5000),('Sameera','2026-09-01',5000),
('Sherra','2026-10-01',7000),('Muneez','2026-10-01',6000),('Ghazal','2026-10-01',5000),('Sameera','2026-10-01',5000)
) v(n,m,a) join employees e on e.full_name = v.n;

insert into urgent_payments (payee, type, amount_aed, status) values
('MSM 1','supplier',31762.5,'overdue'),('Bayut, March','listing_portal',3200,'overdue'),('Bayut, April','listing_portal',6400,'outstanding'),
('Cafesti','office',376,'outstanding'),('Laurent, salary and end of service','salary',38328,'outstanding'),('Klimentina','salary',16145,'outstanding'),
('Hazel','salary',8000,'outstanding'),('Muneez','salary',7000,'outstanding'),('Nawsifu','salary',1000,'outstanding'),
('Laurent, Majestine','commission',15000,'under_review'),('Laurent, Paramount Tower B','commission',16506,'under_review');

insert into budget_lines (year, line, annual_aed) values
(2026,'Fixed payments',688596),(2026,'Other expenses',200000),(2026,'Quarterly and yearly payments',162413),
(2026,'Marketing campaigns',120000),(2026,'Sales head forecast',120000);
