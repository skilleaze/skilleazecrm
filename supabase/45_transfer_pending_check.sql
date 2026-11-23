-- Skilleaze HQ · find every transfer that is Not verified (any date, any agent). Read-only.
-- 1. All pending transfers on the server
select agent_code, date, amount, coalesce(extra->>'to', '') as paid_to, coalesce(note, extra->>'note', '') as note, status, created_at
from transfers where status = 'pending' order by agent_code, date;

-- 2. Digamma: every transfer of 1,950 / 870 / 2,460 with its status and date
select id, date, amount, status, coalesce(extra->>'to', '') as paid_to, coalesce(note, extra->>'note', '') as note, created_at, updated_at
from transfers where agent_code = 'DIGAMMA' and amount in (1950, 870, 2460) order by date;
