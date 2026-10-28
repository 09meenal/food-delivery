-- ============ UPDATE / DELETE demos (rolled back so data stays intact) ============
BEGIN;
UPDATE delivery_partner SET current_status = 'Busy' WHERE partner_id = 3;
UPDATE food_item SET price = price * 1.10 WHERE category = 'Beverage';
DELETE FROM order_item WHERE order_id = 12 AND item_id = 3;
DELETE FROM users WHERE user_id = 8;
ROLLBACK;

-- ============ SELECT, WHERE, ORDER BY ============
SELECT * FROM food_item WHERE type = 'Veg' AND price < 150 ORDER BY price DESC;
SELECT order_id, status, total_amount FROM orders WHERE order_date >= '2026-10-10' ORDER BY order_date;

-- ============ Aggregates, GROUP BY, HAVING ============
SELECT COUNT(*) AS orders, SUM(total_amount) AS revenue, AVG(total_amount) AS avg_order, MAX(total_amount) AS biggest FROM orders;
SELECT payment_method, COUNT(*) AS payments, SUM(amount) AS total FROM payment GROUP BY payment_method ORDER BY total DESC;
SELECT category, COUNT(*) AS items, ROUND(AVG(price),2) AS avg_price FROM food_item GROUP BY category HAVING COUNT(*) >= 2;
SELECT customer_id, COUNT(*) AS orders, SUM(total_amount) AS spent FROM orders GROUP BY customer_id HAVING SUM(total_amount) > 500 ORDER BY spent DESC;

-- ============ Joins ============
SELECT o.order_id, c.name AS customer, r.name AS restaurant, d.name AS partner, o.status, o.total_amount
FROM orders o JOIN customer c ON c.customer_id = o.customer_id
JOIN restaurant r ON r.restaurant_id = o.restaurant_id
LEFT JOIN delivery_partner d ON d.partner_id = o.partner_id ORDER BY o.order_id;

SELECT o.order_id, f.item_name, oi.quantity, f.price * oi.quantity AS line_total
FROM order_item oi JOIN orders o ON o.order_id = oi.order_id JOIN food_item f ON f.item_id = oi.item_id ORDER BY o.order_id;

SELECT r.name AS restaurant, COUNT(DISTINCT o.order_id) AS orders, SUM(oi.quantity * f.price) AS revenue
FROM restaurant r JOIN orders o ON o.restaurant_id = r.restaurant_id
JOIN order_item oi ON oi.order_id = o.order_id JOIN food_item f ON f.item_id = oi.item_id
GROUP BY r.name HAVING SUM(oi.quantity * f.price) > 200 ORDER BY revenue DESC;

-- ============ Nested queries / subqueries ============
SELECT * FROM food_item WHERE price > (SELECT AVG(price) FROM food_item);
SELECT name FROM customer WHERE customer_id IN (SELECT customer_id FROM orders WHERE status = 'Delivered');
SELECT name FROM customer c WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id AND o.status = 'Cancelled');
SELECT order_id, total_amount FROM orders WHERE total_amount = (SELECT MAX(total_amount) FROM orders);
SELECT name FROM restaurant WHERE restaurant_id NOT IN (SELECT DISTINCT restaurant_id FROM orders WHERE status = 'Placed');
