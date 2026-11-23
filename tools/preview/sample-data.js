function loadReal() {
  let seed = 7; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647, pick = a => a[Math.floor(rnd() * a.length)];
  const ags = AG.slice(0, 8).map(a => [a[0], a[1], a[2], a[3], a[4], a[5], 0, { sales: 0, revenue: 0, ad: 0, enq: 0 }]);
  const exps = [['SHAFEEDA', 'cv'], ['REEM', 'cv'], ['NAJMA', 'cv'], ['AKSHARA', 'linkedin'], ['HAFSATH MUYEENA', 'portfolio'], ['AYISHATH SABEEHA ABBAS', 'interview']];
  const FN = ['Arjun', 'Fatima', 'Rahul', 'Ameena', 'Joel', 'Sneha', 'Irfan', 'Nadia', 'Vivek', 'Sara', 'Kiran', 'Huda', 'Anand', 'Rida', 'Nikhil', 'Zainab', 'Rohan', 'Meera', 'Faisal', 'Divya'];
  const LN = ['Sample', 'Demo', 'Test', 'Example', 'Placeholder'];
  const SV = SERVICES.map(x => x[0]), ST = ['PENDING', 'DRAFT SHARED', 'CV SUBMITTED', 'REVISION', 'CLOSED', 'CLOSED', 'CLOSED'];
  const day = off => { const d = new Date(); d.setDate(d.getDate() - off); return d.toISOString().slice(0, 10); };
  const orders = [], ads = [], transfers = [], expenses = [];
  for (let i = 0; i < 260; i++) { const ag = pick(ags)[0], off = Math.floor(rnd() * 80), sv = rnd() < .7 ? ['ATS CV'] : [pick(SV), 'ATS CV'].filter((x, j, a) => a.indexOf(x) === j);
    const price = sv.reduce((t, x) => t + ((SERVICES.find(y => y[0] === x) || [0, 490])[1]), 0), part = rnd() < .08;
    orders.push({ id: 'DEMO-' + (1000 + i), date: day(off), agent: ag, name: pick(FN) + ' ' + pick(LN), phone: '+00 0000 ' + String(1000 + i), services: sv, price, paid: part ? Math.round(price / 2) : price, pay: part ? 'PARTIAL' : 'PAID', via: pick(['personal', 'inco', 'gateway', 'uae']), status: off < 4 ? pick(ST.slice(0, 4)) : pick(ST), expert: pick(exps.slice(0, 3))[0], urgent: rnd() < .05, by: ag }); }
  ags.forEach(a => { for (let k = 0; k < 60; k++) ads.push({ id: a[0] + '-' + day(k), agent: a[0], date: day(k), messages: 5 + Math.floor(rnd() * 30), aed: +(20 + rnd() * 60).toFixed(2) });
    for (let k = 0; k < 6; k++) transfers.push({ id: 'TR-' + a[0] + k, agent: a[0], date: day(k * 12 + 2), amount: 5000 + Math.floor(rnd() * 20000), note: 'Weekly transfer', status: k === 0 ? 'pending' : 'verified', proof: 'demo' }); });
  for (let k = 0; k < 25; k++) expenses.push({ id: 'EX-' + k, date: day(k * 3), type: pick(EXP_TYPES), name: pick(['Office internet', 'Canva', 'Meta ads top-up', 'Stationery', 'Electricity']), amount: 500 + Math.floor(rnd() * 9000) });
  return Promise.resolve({ v: 'real1', agents: ags, experts: exps, orders, ads, transfers, expenses, issues: [], hr: [], puttur: { staff: [], expenses: [], paid: {}, enquiries: [] } });
}
