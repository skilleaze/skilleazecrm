-- Test for 50_expert_keep_assignments.sql — changes NOTHING (ends with an error on purpose, so everything rolls back).
-- Paste into Supabase → SQL Editor → Run. The error message lists each test: [expected] got.
-- Expected: 1 refuse→ERR, 2 ok, 3 ok, 4 refuse→ERR, 5 ok, 6 ok, 7 ok, 8 refuse→ERR, 9 refuse→ERR, 10 ok,
--           11 ok, 100 = HAFSATH MUYEENA (expert copy kept), 101 = (none), 102 has cv=HAFSATH MUYEENA, 103 has cv=RASEENA.
-- If all match: run 50_expert_keep_assignments.sql, then move it to supabase/50_expert_keep_assignments.sql.
do $t$ declare res text; mig text; begin
-- step 1: paste the body of 50_expert_keep_assignments.sql between the $m$ markers below
execute $m$ select 1; $m$;
create temp table r(n int, expect text, got text); grant all on r to public;
create function pg_temp.t(n int, u text, q text, ex text) returns void language plpgsql as $h$ begin
 begin
  perform set_config('request.jwt.claims', json_build_object('sub',u,'role','authenticated')::text, true);
  perform set_config('request.jwt.claim.sub',u,true);
  execute 'set local role authenticated'; execute q; execute 'reset role'; insert into r values(n,ex,'ok');
 exception when others then execute 'reset role'; insert into r values(n,ex,'ERR: '||sqlerrm); end; end $h$;
-- hafsath.muyeena (expert), thoiba (expert), alpha (agent), hashim (management), raseena (expert, KAPPA), zahir (expert)
perform pg_temp.t(1,'c5906232-d88f-460d-b72d-96430d35ecfb',$q$select patch_extra('orders','ALPHA-1795265135503','{"wx":{"cv":"THOIBA"}}'::jsonb,'{}')$q$,'refuse');
perform pg_temp.t(2,'c5906232-d88f-460d-b72d-96430d35ecfb',$q$select patch_extra('orders','ALPHA-1795265135503','{"wx":{"cv":"HAFSATH MUYEENA","linkedin":"THOIBA"},"note1":"x"}'::jsonb,'{}')$q$,'ok');
perform pg_temp.t(3,'c5906232-d88f-460d-b72d-96430d35ecfb',$q$select patch_extra('orders','ALPHA-1795433029778','{"wx":{"cv":""},"expert":""}'::jsonb,'{}')$q$,'ok');
perform pg_temp.t(4,'8faf1ccd-80fe-45d1-998c-25152b128471',$q$select patch_extra('orders','ALPHA-1795361013158','{"wx":{"cv":"THOIBA","linkedin":"THOIBA"}}'::jsonb,'{}')$q$,'refuse');
perform pg_temp.t(5,'ef8d138d-e145-4260-90fe-c6c8dbfc80ce',$q$select patch_extra('orders','ALPHA-1795272437380','{"wx":{"cv":"HAFSATH MUYEENA","linkedin":"THOIBA"},"expert":"HAFSATH MUYEENA"}'::jsonb,'{}')$q$,'ok');
perform pg_temp.t(6,'77f40bdd-4cb5-41f7-b47c-b92a8f3117f6',$q$select patch_extra('orders','KAPPA-1793962857180','{"wx":{"cv":"RASEENA","linkedin":"SHIHAB"},"expert":"RASEENA"}'::jsonb,'{}')$q$,'ok');
perform pg_temp.t(7,'25f1710e-be63-4108-b74e-c544536dc5d0',$q$select claim_order('KAPPA-1794467721091','cv'), patch_extra('orders','KAPPA-1794467721091','{"wx":{"cv":"RASEENA","linkedin":"FATHIMATH.SHIREENA"},"expert":"RASEENA"}'::jsonb,'{}')$q$,'ok');
perform pg_temp.t(8,'8faf1ccd-80fe-45d1-998c-25152b128471',$q$with u as (update order_experts set expert_code='HAFSATH MUYEENA' where order_id='ALPHA-1795361013158' and service_type='linkedin' returning 1) select 1/(select count(*) from u)::int$q$,'refuse');
perform pg_temp.t(9,'98a3b6e8-1120-4d0a-8e1d-0bb178a2eddc',$q$select patch_extra('orders','KAPPA-1793962857180','{"tst":{"cv":"PENDING"}}'::jsonb,'{}')$q$,'refuse');
perform pg_temp.t(10,'c5906232-d88f-460d-b72d-96430d35ecfb',$q$select patch_extra('orders','ALPHA-1795265135503','{"expert":"THOIBA"}'::jsonb,'{}')$q$,'ok (kept)');
perform pg_temp.t(11,'c5906232-d88f-460d-b72d-96430d35ecfb',$q$select set_task_status('ALPHA-1795265135503','CV SUBMITTED','cv',null)$q$,'ok');
select string_agg(n||' ['||expect||'] '||coalesce(got,'null'), E' | ' order by n) into res from (
 select n, expect, got from r
 union all select 100, 'T10 expert still', extra->>'expert' from orders where id='ALPHA-1795265135503'
 union all select 101, 'T3 oe cv', coalesce((select expert_code from order_experts where order_id='ALPHA-1795433029778' and service_type='cv'),'(none)')
 union all select 102, 'T5 oe', (select string_agg(service_type||'='||expert_code, ', ') from order_experts where order_id='ALPHA-1795272437380')
 union all select 103, 'T7 oe', (select string_agg(service_type||'='||expert_code, ', ') from order_experts where order_id='KAPPA-1794467721091')) z;
raise exception 'TEST RESULTS (rolled back): %', res;
end $t$;
