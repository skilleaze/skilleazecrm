-- 35_sheet_reconcile.sql · 14 Nov 2026
-- Covers only up to and including 1 Nov 2026 (1 Nov counts with October). Nothing from 2 Nov onwards is read or changed.
-- Makes everything up to 1 Nov 2026 (the pre-CRM period) match the final agent accounts sheets exactly:
-- revenue, sales, ad spend, enquiries and agent commission per agent per month, and each agent's cash-flow balance.
-- How: adds read-only "Accounts sheet adjustment" lines (ids FIX35-…). No real order, ad day or transfer is edited or deleted,
-- except the M-cost rate of October orders for ALPHA (10%), SIGMA (20%) and SAN (20%), which the sheets now use.
-- Safe to run again: it removes its own previous FIX35 lines first and recalculates. The last result is the check table.
begin;

create temp table s_m (agent text, ym text, rev numeric, sales int, ad numeric, enq int, comm numeric) on commit drop;
insert into s_m values
('DJANDJA','2026-08',25724,48,23142.735,212,967.9744),
('DJANDJA','2026-09',10528,20,8709.855,77,681.8044),
('DJANDJA','2026-10',8538,17,8693.9737,104,-58.4902),
('KOPPA','2026-07',63303,127,49111.5555,449,5321.7917),
('KOPPA','2026-08',41105,88,29382.045,226,4396.1081),
('KOPPA','2026-09',63011,138,65844.828,581,-1062.6855),
('KOPPA','2026-10',4655,11,0,0,1745.625),
('BETA','2026-02',92500,174,27906.375,570,30681.9719),
('BETA','2026-03',154864,285,69966.4875,1446,35326.3184),
('BETA','2026-04',136700,250,79133.145,1165,24465.9134),
('BETA','2026-05',87754,163,65199.771,735,9585.5473),
('BETA','2026-06',82804,157,59785.047,656,9783.055),
('BETA','2026-07',71227,133,56012.5125,474,6085.795),
('BETA','2026-08',82100,133,57071.1488,552,10011.5405),
('BETA','2026-09',39885,74,33115.866,299,2707.6536),
('BETA','2026-10',33030,66,33546.576,386,-206.6304),
('PHI','2026-05',31215,58,21922.992,224,3484.503),
('PHI','2026-06',8145,13,0,0,3054.375),
('PHI','2026-07',30560,51,23754.297,188,2552.1386),
('PHI','2026-08',43197,74,23178.2513,218,7507.0308),
('PHI','2026-09',35124,60,28894.32,228,2336.13),
('PHI','2026-10',35610,61,28552.692,255,2646.4905),
('DIGAMMA','2026-05',9820,15,5606.328,76,1580.127),
('DIGAMMA','2026-06',115422,183,62799.786,885,19733.3303),
('DIGAMMA','2026-07',188075,295,104531.553,1025,31328.7926),
('DIGAMMA','2026-08',163593,226,109659.4538,1154,20225.0798),
('DIGAMMA','2026-09',127553,181,75192.852,732,19635.0555),
('DIGAMMA','2026-10',160919,213,84050.19,944,28825.8038),
('GANGIA','2026-08',7460,11,14513.73,0,0),
('KAI','2026-07',44280,79,38054.772,348,2334.4605),
('KAI','2026-08',31275,56,28948.92,267,872.28),
('IOTA','2026-03',63689,110,23710.575,484,14991.9094),
('IOTA','2026-04',107870,187,52867.269,859,20626.0241),
('IOTA','2026-05',73814,136,48134.814,448,9629.6948),
('IOTA','2026-06',96895,192,50925.3885,502,17238.6043),
('IOTA','2026-07',82975,148,45421.803,392,14082.4489),
('IOTA','2026-08',89609.26,163,52970.0325,417,13739.7103),
('IOTA','2026-09',71984.83,136,58410.156,591,5090.5028),
('IOTA','2026-10',30397,63,16726.542,94,5126.4218),
('KHEI','2026-08',13580,21,15937.845,117,0),
('NU','2026-04',26040,47,21853.377,347,1569.9836),
('NU','2026-05',500,1,0,1,187.5),
('KAPPA','2026-03',54892,112,19861.275,457,13136.5219),
('KAPPA','2026-04',138968,273,67898.649,1136,26651.0066),
('KAPPA','2026-05',128124,256,72347.457,774,20916.2036),
('KAPPA','2026-06',111320,215,62139.5145,545,18442.6821),
('KAPPA','2026-07',112339,202,66916.773,737,17033.3351),
('KAPPA','2026-08',89530,165,53747.3475,452,13418.4947),
('KAPPA','2026-09',100745,186,61177.872,557,14837.673),
('KAPPA','2026-10',54919,100,23631.72,194,11732.73),
('QUOPPA','2026-06',15465,31,12990.537,120,927.9236),
('QUOPPA','2026-07',6655,14,6538.077,96,43.8461),
('BACTRIAN','2026-08',6460,10,12275.9175,106,0),
('ZETA','2026-02',12880,22,11646.6,243,4000),
('TAU','2026-05',64569,115,48627.306,562,5978.1353),
('TAU','2026-06',87210,146,77083.65,824,3797.3813),
('TAU','2026-07',48960,82,47404.035,424,583.4869),
('TAU','2026-08',25510,42,26935.4663,226,-534.5498),
('TAU','2026-09',13520,23,11569.9238,111,731.2786),
('TAU','2026-10',12120,23,12724.0575,179,-226.5216),
('TSAN','2026-08',16280,29,10135.7025,120,2304.1116),
('GAMMA','2026-02',54494.4,111,30182.04,451,9117.135),
('GAMMA','2026-03',144349.6,231,68785.7625,1155,28336.4391),
('GAMMA','2026-04',175027,278,79059.435,1224,35987.8369),
('GAMMA','2026-05',121629,214,70828.485,1104,19050.1931),
('GAMMA','2026-06',112001,176,53334.855,555,21999.8044),
('GAMMA','2026-07',124629,202,83181.168,1053,15542.937),
('GAMMA','2026-08',99115,160,71068.0163,737,10517.6189),
('GAMMA','2026-09',38834,61,8434.86,93,11399.6775),
('OMICRON','2026-04',64280,126,32583.642,537,13470.9522),
('OMICRON','2026-05',104277,198,70765.422,766,14242.4207),
('OMICRON','2026-06',87392,165,66450.4155,665,8900.1734),
('OMICRON','2026-07',103508,188,64693.566,540,16496.1345),
('OMICRON','2026-08',89619,156,64185.9488,590,10809.0468),
('OMICRON','2026-09',86874,159,68830.104,536,7668.6558),
('OMICRON','2026-10',60815,113,54792.78,294,2559.4435),
('YOT','2026-07',47565,96,42547.9635,393,1881.3887),
('YOT','2026-08',33890,65,31148.6175,282,1028.0184),
('SIGMA','2026-05',84753,144,38545.143,402,19638.3392),
('SIGMA','2026-06',156535,253,68191.389,915,37546.0347),
('SIGMA','2026-07',121055,186,84860.622,835,15382.6107),
('SIGMA','2026-08',51303.76,83,34448.7413,292,7163.383),
('SIGMA','2026-09',44890,77,44228.478,396,281.1468),
('SIGMA','2026-10',33120,50,17191.4724,192,6371.411),
('XI','2026-04',53520,105,27393.639,416,11103.7034),
('XI','2026-05',90074,172,62015.499,458,11924.8629),
('XI','2026-06',9650,19,7297.0065,60,1000.0222),
('XI','2026-07',74395,128,43607.403,429,13084.7287),
('SAN','2026-06',9825,17,4427.9865,55,2293.7307),
('SAN','2026-07',63879,114,43184.421,364,7760.4671),
('SAN','2026-08',102495,177,56723.7825,546,17164.2066),
('SAN','2026-09',91057,150,53722.914,518,14000.2823),
('SAN','2026-10',52866,92,34199.0432,417,7466.7827),
('ALPHA','2026-01',153604,313,83852.244,1986,47800),
('ALPHA','2026-02',289497,565,118858.95,1989,82413.05),
('ALPHA','2026-03',316758,624,94275.825,1526,111241.0875),
('ALPHA','2026-04',402229,695,108418.947,1787,132214.5239),
('ALPHA','2026-05',476620,839,143008.866,1855,150125.0103),
('ALPHA','2026-06',404316,668,142031.232,1855,118028.1456),
('ALPHA','2026-07',382072,640,118015.947,1261,118825.2239),
('ALPHA','2026-08',340839,565,116387.1,1396,101003.355),
('ALPHA','2026-09',438391,727,134175.482,1734,136896.9831),
('ALPHA','2026-10',342523,570,87371.92,1391,114817.986),
('FAI','2026-08',22196,39,22737.33,195,0),
('STIGMA','2026-07',45242,85,42490.98,385,1031.6325),
('STIGMA','2026-08',33825,67,25128.18,218,3261.3075),
('STIGMA','2026-09',31220,61,14441.5425,137,6291.9216),
('STIGMA','2026-10',37626,67,21868.1925,196,5909.1778),
('UPSILON','2026-05',35590,66,26119.002,323,3551.6243),
('DELTA','2026-02',46700,84,28307.7375,559,8736.3247),
('DELTA','2026-03',159353,255,65643.375,1121,39512.0719),
('DELTA','2026-04',104130,175,52297.245,741,22028.9209),
('DELTA','2026-05',136290,220,69213.417,788,28507.5478),
('DELTA','2026-06',105129,168,65337.111,683,16911.5528),
('DELTA','2026-07',118989,194,79839.27,851,15659.892),
('DELTA','2026-08',106800,160,72360.75,657,13775.7),
('DELTA','2026-09',109358,183,80918.796,699,11375.6816),
('DELTA','2026-10',70287,123,41197.812,398,11635.6752),
('ETA','2026-03',40334,84,25050.9,498,5731.1625),
('ETA','2026-04',56395,101,39060.021,598,6500.6171),
('ETA','2026-05',17925,32,15704.598,179,832.6508),
('ETA','2026-06',23825,42,15496.215,114,3123.2944),
('ETA','2026-07',39773,74,33965.4105,477,2177.8461),
('ETA','2026-08',31249,56,17688.825,182,5085.0656),
('ETA','2026-09',14860,25,9911.328,88,1855.752),
('ETA','2026-10',43586,79,26315.058,257,6476.6033),
('HETA','2026-07',9100,16,9754.101,76,0),
('HETA','2026-08',0,0,3843.2625,0,0),
('OMEGA','2026-05',0,0,103.761,25,-38.9104),
('OMEGA','2026-06',0,0,0,0,0),
('LAMBDA','2026-04',104449,181,39751.53,611,24261.5513),
('LAMBDA','2026-05',94835,172,39194.61,490,20865.1463),
('LAMBDA','2026-06',235370,394,101064.915,1248,50364.4069),
('LAMBDA','2026-07',221878,390,117241.7085,1108,39238.6093),
('LAMBDA','2026-08',180701,323,116827.3838,1154,23952.6061),
('LAMBDA','2026-09',161440,294,88281.438,802,27434.4608),
('LAMBDA','2026-10',130940.54,247,62346.522,649,25722.7568),
('HORI','2026-08',4530,9,10934.0963,88,0),
('EPSILON','2026-02',15940,29,7972.3875,150,2987.8547),
('EPSILON','2026-03',125169,229,48450.3075,957,31441.3789),
('EPSILON','2026-04',157867,303,67402.062,1153,38447.5987),
('EPSILON','2026-05',261562,493,144683.184,1502,49673.4968),
('EPSILON','2026-06',203999,375,126955.269,1302,32743.5857),
('EPSILON','2026-07',88286,159,55610.226,551,13070.3096),
('SHO','2026-07',76601,134,48303.297,603,10611.6386),
('SHO','2026-08',110438,179,71396.9025,675,14640.4116),
('SHO','2026-09',112006,195,71040.585,696,15362.0306),
('SHO','2026-10',96951,168,59407.1363,564,14078.9489),
('PSI','2026-05',7070,13,7983.066,133,-342.3997),
('PSI','2026-06',75840,131,63535.752,604,4614.093),
('PSI','2026-07',126172,224,70685.9055,765,20807.2854),
('PSI','2026-08',108469,196,65104.4625,565,16261.7016),
('PSI','2026-09',73715,129,55865.586,463,6693.5303),
('PSI','2026-10',56750,102,46471.11,631,3854.5838),
('PI','2026-04',3750,5,4401.852,61,3750),
('MU','2026-04',62975,111,37560.978,555,9530.2583),
('MU','2026-05',130835,230,72144.345,804,22008.9956),
('MU','2026-06',143020,246,77881.986,1089,24426.7552),
('MU','2026-07',100629,175,94244.7555,784,2394.0917),
('MU','2026-08',48350,86,48261.0975,420,33.3384),
('MU','2026-09',10310,21,10245.9,75,24.0375),
('MU','2026-10',17180,32,18917.43,223,-651.5362),
('RHO','2026-04',14810,26,7851.48,101,2609.445),
('RHO','2026-05',10820,19,8164.065,78,995.9756),
('THETA','2026-03',48,2,124.152,79,48),
('THETA','2026-04',60,3,149.6565,48,60),
('SHAI','2026-08',15418,28,14321.4225,122,411.2166),
('LUNATE','2026-08',16820,24,13195.875,131,1359.0469),
('SAMPI','2026-06',33512,61,19280.835,276,5336.6869),
('SAMPI','2026-07',36320,101,33273.828,396,1142.3145),
('SAMPI','2026-08',32431,90,24465.21,274,2987.1713),
('SAMPI','2026-09',8310,16,8665.6763,76,-133.3786),
('SAMPI','2026-10',12484,22,5497.5112,71,2619.9333),
('WAU','2026-07',50186,85,27177.1605,290,8628.3148),
('WAU','2026-08',136713,264,112916.265,1293,8923.7756),
('WAU','2026-09',76924,153,70486.4738,660,2414.0723),
('WAU','2026-10',83996,164,65092.335,624,7088.8744);

create temp table s_a (agent text, deal numeric, rev numeric, comm numeric, tr numeric, bal numeric) on commit drop;
insert into s_a values
('DJANDJA',0.25,44790,1591.2886,43198.71,0.0014),
('KOPPA',0.25,172074,10400.8393,153861,7812.1607),
('BETA',0.15,780864,128441.1647,647838,4584.8353),
('PHI',0.25,183851,21580.6679,160942,1328.3321),
('DIGAMMA',0.25,765382,121328.189,644053.81,0.001),
('GANGIA',0.25,7460,0,7460,0),
('KAI',0.25,75555,3206.7405,72184,164.2595),
('IOTA',0.25,617234.09,100525.3163,503209,13499.7738),
('KHEI',0.25,13580,0,13580,0),
('NU',0.25,26540,1757.4836,24782.52,-0.0036),
('KAPPA',0.25,790837,136168.647,658347,-3678.647),
('QUOPPA',0.25,22120,971.7698,21148.23,0),
('BACTRIAN',0.25,6460,0,6000,460),
('ZETA',0.25,12880,4000,8880,0),
('TAU',0.25,251889,10329.2106,238352,3207.7894),
('TSAN',0.25,16280,2304.1116,12897,1078.8884),
('GAMMA',0.25,870079,151951.6419,718127.36,0),
('OMICRON',0.15,596765,74146.8267,522618.17,0.0033),
('YOT',0.25,81455,2909.4071,78535,10.5929),
('SIGMA',0.15,491656.76,86382.9254,381245,24028.8346),
('XI',0.15,227639,37113.3173,188190.19,2335.4927),
('SAN',0.25,320122,48685.4694,250886,20550.5306),
('ALPHA',0.1,3546849,1113365.365,2584880,-151396.3652),
('FAI',0.25,22196,0,22196,0),
('STIGMA',0.25,147913,16494.0394,129012,2406.9606),
('UPSILON',0.25,35590,3551.6243,32038,0.3757),
('DELTA',0.15,957036,168143.3668,788892.63,0.0032),
('ETA',0.25,267947,31782.9917,236164.01,-0.0017),
('HETA',0.25,9100,0,8550,550),
('OMEGA',0.25,0,-38.9104,38.91,0),
('LAMBDA',0.25,1129613.54,211839.5373,924231,-6456.9973),
('HORI',0.25,4530,0,0,4530),
('EPSILON',0.15,852823,168364.2244,684458.78,-0.0044),
('SHO',0.25,395996,54693.0297,341302.97,0.0003),
('PSI',0.25,448016,51888.7943,402430,-6302.7942),
('PI',0.25,3750,3750,0,0),
('MU',0.25,513299,57765.9405,453082,2451.0595),
('RHO',0.25,25630,3605.4206,22024.58,0),
('THETA',0.25,108,108,0,0),
('SHAI',0.25,15418,411.2166,12620,2386.7834),
('LUNATE',0.25,16820,1359.0469,15456,4.9531),
('SAMPI',0.25,123057,11952.7273,111104.27,0.0027),
('WAU',0.25,347819,27055.0372,314438,6325.9628);

-- 1. Remove the previous run's adjustment lines
delete from orders    where id like 'FIX35-%';
delete from ad_days   where id like 'FIX35-%';
delete from transfers where id like 'FIX35-%';

-- 2. October M-cost rate as in the sheets
update orders set tier = x.t, extra = jsonb_set(extra, '{t}', to_jsonb(x.t))
from (values ('ALPHA','D0.1'), ('SIGMA','D0.2'), ('SAN','D0.2')) as x(agent, t)
where orders.agent_code = x.agent and orders.branch = 'cloud' and orders.date between '2026-10-01' and '2026-11-01'
  and not orders.summary and coalesce(orders.extra->>'t', '') <> x.t;
update ad_days set tier = x.t, extra = jsonb_set(extra, '{t}', to_jsonb(x.t))
from (values ('ALPHA','D0.1'), ('SIGMA','D0.2'), ('SAN','D0.2')) as x(agent, t)
where ad_days.agent_code = x.agent and ad_days.date between '2026-10-01' and '2026-11-01'
  and not ad_days.summary and coalesce(ad_days.extra->>'t', '') <> x.t;

-- 3. What the CRM holds now, per agent / month / commission tier (same maths as the app)
create or replace temp view v_g as
with o as (
  select agent_code agent, case when date < '2026-01-01' then '2026-01' when date = '2026-11-01' then '2026-10' else to_char(date, 'YYYY-MM') end ym, coalesce(extra->>'t', '') t,
    sum(case when pay_status = 'REFUNDED' then 0 else price end) rev,
    sum(coalesce(nullif(extra->>'qty', '')::numeric, 1)) sales,
    sum(case when pay_status = 'REFUNDED' or not ('INTERVIEW TRAINING SESSION' = any(services)) then 0
             when cardinality(services) = 1 then price / 2 else 1000 * greatest(1, coalesce(nullif(extra->>'hours', '')::numeric, 1)) end) ih,
    sum(coalesce(nullif(extra->>'comm', '')::numeric, 0)) comm,
    sum(case when pay_status = 'REFUNDED' then 0 when coalesce(extra->>'via', via, 'personal') = 'personal' then paid else 0 end) recv
  from orders where branch = 'cloud' and date <= '2026-11-01' and agent_code in (select agent from s_a) group by 1, 2, 3),
a as (
  select agent_code agent, case when date < '2026-01-01' then '2026-01' when date = '2026-11-01' then '2026-10' else to_char(date, 'YYYY-MM') end ym, coalesce(extra->>'t', '') t,
    sum(coalesce(nullif(extra->>'aed', '')::numeric, aed) * 29.4) ad, sum(coalesce(nullif(extra->>'messages', '')::numeric, messages)) enq
  from ad_days where date <= '2026-11-01' and agent_code in (select agent from s_a) group by 1, 2, 3)
select coalesce(o.agent, a.agent) agent, coalesce(o.ym, a.ym) ym, coalesce(o.t, a.t) t,
  coalesce(o.rev, 0) rev, coalesce(o.sales, 0) sales, coalesce(o.ih, 0) ih, coalesce(o.comm, 0) comm, coalesce(o.recv, 0) recv,
  coalesce(a.ad, 0) ad, coalesce(a.enq, 0) enq
from o full join a on o.agent = a.agent and o.ym = a.ym and o.t = a.t;

create or replace temp view v_m as
select g.agent, g.ym, sum(g.rev) rev, sum(g.sales) sales, sum(g.ad) ad, sum(g.enq) enq, sum(g.recv) recv,
  sum(case when g.t = 'L' then g.comm else (g.rev - g.ih - g.ad) * (1 - case when g.t = 'M0' then 0 when g.t like 'D%' then substr(g.t, 2)::numeric else s.deal end) / 2 end) share,
  sum(case when g.t = 'L' then 0 else (g.rev - g.ih - g.ad) * (case when g.t = 'M0' then 0 when g.t like 'D%' then substr(g.t, 2)::numeric else s.deal end) end) mcost,
  (array_agg(g.t order by (g.t = 'L'), g.rev desc))[1] main_t
from v_g g join s_a s using (agent) group by 1, 2;

-- 4. Differences, and the tier each adjustment line uses (the month's own rate when that explains the commission, else a fixed-commission line)
create temp table d_m on commit drop as
select coalesce(s.agent, l.agent) agent, coalesce(s.ym, l.ym) ym,
  coalesce(s.rev, 0) - coalesce(l.rev, 0) d_rev, coalesce(s.sales, 0) - coalesce(l.sales, 0) d_sales,
  coalesce(s.ad, 0) - coalesce(l.ad, 0) d_ad, coalesce(s.enq, 0) - coalesce(l.enq, 0) d_enq,
  coalesce(s.comm, 0) - coalesce(l.share, 0) d_share, coalesce(l.main_t, '') main_t
from s_m s full join v_m l on s.agent = l.agent and s.ym = l.ym;
alter table d_m add column t text, add column dl numeric;
update d_m d set dl = case when d.main_t = 'M0' then 0 when d.main_t like 'D%' then substr(d.main_t, 2)::numeric when d.main_t = '' then s.deal else null end
from s_a s where s.agent = d.agent;
update d_m set t = case when dl is not null and abs((d_rev - d_ad) * (1 - dl) / 2 - d_share) < 1 then main_t else 'L' end;

-- 5. Adjustment lines (the order guard would otherwise re-date them to today when run from the SQL editor)
alter table orders disable trigger trg_guard_orders;
insert into orders (id, branch, agent_code, date, name, phone, services, price, paid, pay_status, via, status, urgent, summary, qty, tier, extra)
select x.id, 'cloud', d.agent, x.dt, 'Accounts sheet adjustment', '', '{ATS CV}', round(d.d_rev, 2), round(d.d_rev, 2), 'PAID', 'personal', 'CLOSED', false, true, d.d_sales, d.t,
  jsonb_build_object('id', x.id, 'agent', d.agent, 'date', x.dt, 'name', 'Accounts sheet adjustment', 'phone', '', 'services', jsonb_build_array('ATS CV'),
    'price', round(d.d_rev, 2), 'paid', round(d.d_rev, 2), 'qty', d.d_sales, 'expert', '', 'pay', 'PAID', 'status', 'CLOSED', 'via', 'personal', 'summary', true,
    't', d.t, 'comm', case when d.t = 'L' then round(d.d_share, 4) else 0 end, 'payAt', (extract(epoch from x.dt::timestamp) * 1000)::bigint)
from d_m d, lateral (select 'FIX35-' || d.agent || '-' || d.ym || '-' || to_char(now(), 'YYYYMMDDHH24MISS') id,
  ((d.ym || '-01')::date + interval '1 month' - interval '1 day')::date dt) x
where abs(d.d_rev) >= 0.5 or d.d_sales <> 0 or (d.t = 'L' and abs(d.d_share) >= 0.5);
alter table orders enable trigger trg_guard_orders;

insert into ad_days (id, agent_code, date, messages, aed, summary, tier, extra)
select x.id, d.agent, x.dt, d.d_enq, d.d_ad / 29.4, true, d.t,
  jsonb_build_object('id', x.id, 'agent', d.agent, 'date', x.dt, 'messages', d.d_enq, 'aed', d.d_ad / 29.4, 'inr', round(d.d_ad, 2), 'aedPaid', 0, 'summary', true, 't', d.t)
from d_m d, lateral (select 'FIX35-' || d.agent || '-' || d.ym || '-' || to_char(now(), 'YYYYMMDDHH24MISS') id,
  ((d.ym || '-01')::date + interval '1 month' - interval '1 day')::date dt) x
where abs(d.d_ad) >= 0.5 or d.d_enq <> 0;

-- 6. Cash flow: one closing transfer line per agent so the balance on 1 Nov equals the sheet
alter table transfers disable trigger trg_guard_transfers;
insert into transfers (id, agent_code, date, amount, note, status, imported, verified_at, extra)
select x.id, s.agent, '2026-11-01', round(s.tr - coalesce(t.sum, 0), 2), 'Accounts sheet correction (before CRM)', 'verified', true, now(),
  jsonb_build_object('id', x.id, 'agent', s.agent, 'date', '2026-11-01', 'amount', round(s.tr - coalesce(t.sum, 0), 2), 'to', '', 'note', 'Accounts sheet correction (before CRM)', 'status', 'verified', 'imported', true, 'summary', true)
from s_a s
left join (select agent_code, sum(amount) sum from transfers where date < '2026-11-02' and status <> 'rejected' group by 1) t on t.agent_code = s.agent,
lateral (select 'FIX35-TR-' || s.agent || '-' || to_char(now(), 'YYYYMMDDHH24MISS') id) x
where abs(s.tr - coalesce(t.sum, 0)) >= 0.5;
alter table transfers enable trigger trg_guard_transfers;

-- 7. Check: every agent, sheet vs CRM (all differences should be 0)
select s.agent,
  round(s.rev) sheet_revenue, round(sum(m.rev)) crm_revenue,
  round(s.comm) sheet_commission, round(sum(m.share)) crm_commission,
  round(s.tr) sheet_transferred, round(coalesce(t.sum, 0)) crm_transferred,
  round(s.bal) sheet_balance, round(sum(m.recv) - sum(m.share) - coalesce(t.sum, 0)) crm_balance,
  round(sum(m.rev) - s.rev) d_revenue, round(sum(m.share) - s.comm) d_commission,
  round((select sum(ad) from s_m where agent = s.agent) - sum(m.ad)) d_ad, (select sum(sales) from s_m where agent = s.agent) - sum(m.sales) d_sales,
  round(sum(m.recv) - sum(m.share) - coalesce(t.sum, 0) - s.bal) d_balance,
  (select count(*) from s_m x full join v_m y on x.agent = y.agent and x.ym = y.ym where coalesce(x.agent, y.agent) = s.agent
     and (abs(coalesce(x.rev, 0) - coalesce(y.rev, 0)) >= 1 or abs(coalesce(x.comm, 0) - coalesce(y.share, 0)) >= 1 or abs(coalesce(x.ad, 0) - coalesce(y.ad, 0)) >= 1
       or coalesce(x.sales, 0) <> coalesce(y.sales, 0) or coalesce(x.enq, 0) <> coalesce(y.enq, 0))) months_off
from s_a s join v_m m on m.agent = s.agent
left join (select agent_code, sum(amount) sum from transfers where date < '2026-11-02' and status <> 'rejected' group by 1) t on t.agent_code = s.agent
group by s.agent, s.rev, s.comm, s.tr, s.bal, t.sum
order by abs(round(sum(m.recv) - sum(m.share) - coalesce(t.sum, 0) - s.bal)) desc, s.agent;

commit;
