const express = require('express');
const { Pool, types } = require('pg');
types.setTypeParser(1082, v => v);              // keep DATE as plain 'YYYY-MM-DD'
const pool = new Pool({ connectionString: process.env.DATABASE_URL ||
  'postgresql://postgres:postgres@localhost:5432/food_delivery' });   // change password if needed

const PK = { users:['user_id'], restaurant:['restaurant_id'], customer:['customer_id'],
  delivery_partner:['partner_id'], food_item:['item_id'], orders:['order_id'],
  order_item:['order_id','item_id'], payment:['payment_id'] };

const app = express();
app.use(express.json(), express.static('public'));
const known = (q, s, n) => PK[q.params.t] ? n() : s.status(404).json({ error: 'Unknown table' });
const fail = (s, e) => s.status(400).json({ error: e.message });
const cols = async t => (await pool.query(
  `select column_name from information_schema.columns where table_schema='public' and table_name=$1 order by ordinal_position`, [t])).rows.map(r => r.column_name);
const retotal = oid => pool.query(
  `update orders set total_amount=(select coalesce(sum(f.price*oi.quantity),0) from order_item oi
   join food_item f on f.item_id=oi.item_id where oi.order_id=orders.order_id) where order_id=$1`, [oid]);

app.get('/api/meta', async (q, s) => { try {
  const r = await pool.query(`select table_name t, column_name c, data_type d, is_nullable n, is_identity i
    from information_schema.columns where table_schema='public' and table_name=any($1) order by table_name, ordinal_position`, [Object.keys(PK)]);
  const m = {}; Object.keys(PK).forEach(t => m[t] = { pk: PK[t], cols: [] });
  r.rows.forEach(x => m[x.t].cols.push({ name: x.c, type: x.d, required: x.n === 'NO' && x.i === 'NO', identity: x.i === 'YES' }));
  s.json(m); } catch (e) { fail(s, e); } });

app.get('/api/stats', (q, s) => pool.query(`select
  (select count(*) from orders)::int orders, (select count(*) from customer)::int customers,
  (select count(*) from restaurant)::int restaurants,
  (select coalesce(sum(amount),0) from payment where payment_status='Paid') revenue,
  (select count(*) from orders where status in ('Placed','Confirmed'))::int active`)
  .then(r => s.json(r.rows[0])).catch(e => fail(s, e)));

const REPORTS = {
  latest: `select o.order_id as order_no, c.name as customer, r.name as restaurant, coalesce(d.name,'Not assigned') as partner,
    o.order_date, o.status, o.total_amount from orders o join customer c on c.customer_id=o.customer_id
    join restaurant r on r.restaurant_id=o.restaurant_id left join delivery_partner d on d.partner_id=o.partner_id
    order by o.order_id desc limit 6`,
  top: `select f.item_name as dish, r.name as restaurant, sum(oi.quantity)::int as qty_sold
    from order_item oi join food_item f on f.item_id=oi.item_id join restaurant r on r.restaurant_id=f.restaurant_id
    group by f.item_name, r.name order by qty_sold desc limit 5`,
  restaurant: `select r.name as restaurant, count(distinct o.order_id)::int as orders, sum(oi.quantity*f.price) as revenue
    from restaurant r join orders o on o.restaurant_id=r.restaurant_id
    join order_item oi on oi.order_id=o.order_id join food_item f on f.item_id=oi.item_id
    group by r.name having sum(oi.quantity*f.price) > 200 order by revenue desc`,
  partner: `select d.name as partner, d.current_status as status, count(o.order_id)::int as deliveries
    from delivery_partner d left join orders o on o.partner_id=d.partner_id and o.status='Delivered'
    group by d.partner_id, d.name, d.current_status order by deliveries desc`
};
app.get('/api/report/:n', (q, s) => REPORTS[q.params.n]
  ? pool.query(REPORTS[q.params.n]).then(r => s.json(r.rows)).catch(e => fail(s, e))
  : s.status(404).json({ error: 'Unknown report' }));

app.get('/api/t/:t', known, async (q, s) => { try {
  const t = q.params.t, cs = await cols(t), term = q.query.q;
  const r = await pool.query(`select * from ${t} ${term ? `where concat_ws(' ',${cs}) ilike $1` : ''} order by ${PK[t]}`, term ? [`%${term}%`] : []);
  s.json(r.rows); } catch (e) { fail(s, e); } });

const fields = async (t, b, skipPk) => { const cs = await cols(t);
  return Object.entries(b).filter(([k]) => cs.includes(k) && !(skipPk && PK[t].includes(k))).map(([k, v]) => [k, v === '' ? null : v]); };

app.post('/api/t/:t', known, async (q, s) => { try {
  const t = q.params.t, e = (await fields(t, q.body)).filter(x => x[1] !== null);
  const r = await pool.query(`insert into ${t}(${e.map(x => x[0])}) values(${e.map((_, i) => '$' + (i + 1))}) returning *`, e.map(x => x[1]));
  if (t === 'order_item') await retotal(r.rows[0].order_id);
  s.json(r.rows[0]); } catch (e) { fail(s, e); } });

app.put('/api/t/:t/:id', known, async (q, s) => { try {
  const t = q.params.t, ids = q.params.id.split('-'), e = await fields(t, q.body, true);
  const w = PK[t].map((k, i) => `${k}=$${e.length + i + 1}`).join(' and ');
  const r = await pool.query(`update ${t} set ${e.map(([k], i) => `${k}=$${i + 1}`)} where ${w} returning *`, [...e.map(x => x[1]), ...ids]);
  if (t === 'order_item') await retotal(ids[0]);
  s.json(r.rows[0] || {}); } catch (e) { fail(s, e); } });

app.delete('/api/t/:t/:id', known, async (q, s) => { try {
  const t = q.params.t, ids = q.params.id.split('-');
  await pool.query(`delete from ${t} where ${PK[t].map((k, i) => `${k}=$${i + 1}`).join(' and ')}`, ids);
  if (t === 'order_item') await retotal(ids[0]);
  s.json({ deleted: true }); } catch (e) { fail(s, e); } });

app.post('/api/login', async (q, s) => { try {
  const name = (q.body.name || '').trim(), address = (q.body.address || '').trim();
  if (!name || !address) throw new Error('Please enter your name and address');
  let r = await pool.query('select * from customer where lower(name)=lower($1) and address=$2', [name, address]);
  if (!r.rows.length) {
    const phone = '9' + String(Math.floor(Math.random() * 1e9)).padStart(9, '0');
    r = await pool.query('insert into customer(name,phone,address,email) values($1,$2,$3,$4) returning *', [name, phone, address, 'guest' + Date.now() + '@mail.com']);
  }
  s.json(r.rows[0]); } catch (e) { fail(s, e); } });

app.get('/api/restaurants', (q, s) => pool.query(
  `select * from restaurant r where r.name ilike $1 or r.address ilike $1 or exists
   (select 1 from food_item f where f.restaurant_id=r.restaurant_id and (f.item_name ilike $1 or f.category ilike $1)) order by restaurant_id`,
  ['%' + (q.query.q || '') + '%']).then(r => s.json(r.rows)).catch(e => fail(s, e)));

app.get('/api/menu/:id', async (q, s) => { try {
  const r = await pool.query('select * from restaurant where restaurant_id=$1', [q.params.id]);
  if (!r.rows.length) throw new Error('Restaurant not found');
  const f = await pool.query('select * from food_item where restaurant_id=$1 order by item_id', [q.params.id]);
  s.json({ restaurant: r.rows[0], items: f.rows }); } catch (e) { fail(s, e); } });

app.post('/api/place-order', async (q, s) => {
  const { customer_id, restaurant_id, items, payment_method } = q.body;
  const c = await pool.connect();
  try {
    if (!customer_id || !restaurant_id || !items || !items.length || !payment_method)
      throw new Error('Choose a customer, a restaurant, at least one item and a payment method');
    await c.query('begin');
    const ids = items.map(i => i.item_id);
    const ok = await c.query('select count(*)::int n from food_item where item_id = any($1::int[]) and restaurant_id=$2', [ids, restaurant_id]);
    if (ok.rows[0].n !== ids.length) throw new Error('All items must be from the selected restaurant');
    const o = await c.query(`insert into orders(customer_id, restaurant_id, status) values($1,$2,'Placed') returning order_id`, [customer_id, restaurant_id]);
    const id = o.rows[0].order_id;
    for (const i of items) await c.query('insert into order_item(order_id,item_id,quantity) values($1,$2,$3)', [id, i.item_id, i.quantity]);
    const t = await c.query(`update orders set total_amount=(select sum(f.price*oi.quantity) from order_item oi
      join food_item f on f.item_id=oi.item_id where oi.order_id=$1) where order_id=$1 returning total_amount`, [id]);
    const total = t.rows[0].total_amount, online = payment_method !== 'COD';
    await c.query(`insert into payment(order_id, amount, payment_status, payment_method, transaction_id) values($1,$2,$3,$4,$5)`,
      [id, total, online ? 'Paid' : 'Pending', payment_method, online ? 'TXN' + id + Date.now() : null]);
    // confirm the order and assign an available delivery partner
    const p = await c.query(`select p.partner_id, p.name, p.phone from delivery_partner p where p.current_status<>'Offline' order by (p.current_status='Available') desc, (select count(*) from orders o where o.partner_id=p.partner_id and o.status='Confirmed'), p.partner_id limit 1`);
    let partner = null, partner_phone = null;
    if (p.rows.length) {
      partner = p.rows[0].name; partner_phone = p.rows[0].phone;
      await c.query(`update orders set partner_id=$1, status='Confirmed' where order_id=$2`, [p.rows[0].partner_id, id]);
      await c.query(`update delivery_partner set current_status='Busy' where partner_id=$1`, [p.rows[0].partner_id]);
    }
    await c.query('commit');
    s.json({ order_id: id, total, partner, partner_phone });
  } catch (e) { await c.query('rollback'); fail(s, e); } finally { c.release(); }
});

app.listen(3000, () => console.log('Open http://localhost:3000'));
