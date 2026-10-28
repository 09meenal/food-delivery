-- ============ DML: sample data (safe to re-run: clears old data first) ============
TRUNCATE payment, order_item, orders, food_item, delivery_partner, customer, restaurant, users RESTART IDENTITY CASCADE;

INSERT INTO users (name, phone, email, user_type) VALUES
('Aarav Mehta','9876500001','aarav@mail.com','Customer'),
('Diya Shah','9876500002','diya@mail.com','Customer'),
('Rohan Patil','9876500003','rohan@mail.com','Customer'),
('Meera Kulkarni','9876500004','meera@mail.com','Manager'),
('Kabir Singh','9876500005','kabir@mail.com','Manager'),
('Sanjay Pawar','9876500006','sanjay@mail.com','DeliveryPartner'),
('Imran Khan','9876500007','imran@mail.com','DeliveryPartner'),
('Neha Iyer','9876500008','neha@mail.com','Customer');

INSERT INTO restaurant (name, address, contact_details) VALUES
('Spice Route','12 MG Road, Andheri West, Mumbai','02212345601'),
('Pizza Palace','45 Linking Road, Bandra West, Mumbai','02212345602'),
('Burger Barn','7 Hill Road, Powai, Mumbai','02212345603'),
('Dosa Corner','3 Matunga East, Mumbai','02212345604'),
('Wok Express','88 Dadar West, Mumbai','02212345605');

INSERT INTO customer (name, phone, address, email) VALUES
('Aarav Mehta','9876500001','101 Sea View, Bandra','aarav@mail.com'),
('Diya Shah','9876500002','22 Green Park, Andheri','diya@mail.com'),
('Rohan Patil','9876500003','5 Lake Road, Powai','rohan@mail.com'),
('Neha Iyer','9876500008','90 Palm Heights, Juhu','neha@mail.com'),
('Kavya Nair','9876500009','14 Rose Villa, Dadar','kavya@mail.com'),
('Vikram Rao','9876500010','63 Skyline Tower, Worli','vikram@mail.com');

INSERT INTO delivery_partner (name, phone, current_status) VALUES
('Sanjay Pawar','9876500006','Available'),
('Imran Khan','9876500007','Busy'),
('Ravi Kumar','9876500011','Available'),
('Amit Jadhav','9876500012','Offline'),
('Suresh Naik','9876500013','Available');

INSERT INTO food_item (restaurant_id, item_name, price, category, type) VALUES
(1,'Paneer Tikka',220,'Starter','Veg'),(1,'Chicken Biryani',280,'Main Course','NonVeg'),
(1,'Butter Chicken',320,'Main Course','NonVeg'),(1,'Dal Makhani',190,'Main Course','Veg'),
(1,'Butter Naan',45,'Bread','Veg'),
(2,'Margherita Pizza',250,'Main Course','Veg'),(2,'Pepperoni Pizza',340,'Main Course','NonVeg'),
(2,'Farmhouse Pizza',320,'Main Course','Veg'),(2,'Garlic Bread',130,'Starter','Veg'),
(2,'Chicken Wings',260,'Starter','NonVeg'),
(3,'Veg Burger',120,'Main Course','Veg'),(3,'Chicken Burger',160,'Main Course','NonVeg'),
(3,'Cheese Fries',110,'Sides','Veg'),(3,'Chicken Wrap',150,'Main Course','NonVeg'),
(3,'Cold Coffee',90,'Beverage','Veg'),
(4,'Masala Dosa',90,'Main Course','Veg'),(4,'Paneer Plain Dosa',75,'Main Course','Veg'),
(4,'Idli Sambar',60,'Breakfast','Veg'),(4,'Medu Vada',70,'Breakfast','Veg'),
(4,'Filter Coffee',40,'Beverage','Veg'),
(5,'Veg Noodles',150,'Main Course','Veg'),(5,'Chicken Manchurian',210,'Starter','NonVeg'),
(5,'Veg Fried Rice',140,'Main Course','Veg'),(5,'Chilli Chicken',230,'Starter','NonVeg'),
(5,'Spring Rolls',120,'Starter','Veg');

INSERT INTO orders (customer_id, restaurant_id, partner_id, order_date, status) VALUES
(1,1,1,'2026-10-01','Delivered'),(2,2,2,'2026-10-02','Delivered'),
(3,3,3,'2026-10-03','Delivered'),(1,4,1,'2026-10-05','Delivered'),
(4,5,4,'2026-10-06','Delivered'),(5,1,2,'2026-10-08','Delivered'),
(2,1,3,'2026-10-10','Delivered'),(6,2,5,'2026-10-12','Delivered'),
(3,5,1,'2026-10-15','Confirmed'),(4,3,4,'2026-10-20','Confirmed'),
(5,4,NULL,'2026-10-25','Placed'),(1,2,NULL,'2026-10-26','Placed');

INSERT INTO order_item (order_id, item_id, quantity) VALUES
(1,1,2),(1,2,1),(2,6,1),(2,7,2),(3,11,2),(3,12,1),(4,16,3),(4,20,2),
(5,21,1),(5,22,1),(6,4,2),(6,5,4),(7,2,2),(8,6,2),(9,21,2),(9,22,2),
(10,12,3),(11,16,1),(12,7,1),(12,6,1);

UPDATE orders SET total_amount = (
  SELECT SUM(f.price * oi.quantity) FROM order_item oi
  JOIN food_item f ON f.item_id = oi.item_id WHERE oi.order_id = orders.order_id);

INSERT INTO payment (order_id, amount, payment_date, payment_status, payment_method, transaction_id, managed_by) VALUES
(1,0,'2026-10-01','Paid','UPI','TXN1001',4),(2,0,'2026-10-02','Paid','Card','TXN1002',4),
(3,0,'2026-10-03','Paid','COD',NULL,5),(4,0,'2026-10-05','Paid','UPI','TXN1004',4),
(5,0,'2026-10-06','Paid','Card','TXN1005',5),(6,0,'2026-10-08','Paid','COD',NULL,4),
(7,0,'2026-10-10','Paid','UPI','TXN1007',5),(8,0,'2026-10-12','Paid','COD',NULL,4),
(9,0,'2026-10-15','Paid','UPI','TXN1009',5),(10,0,'2026-10-20','Pending','COD',NULL,5),
(11,0,'2026-10-25','Pending','COD',NULL,4),(12,0,'2026-10-26','Pending','UPI','TXN1012',5);

UPDATE payment SET amount = (SELECT total_amount FROM orders o WHERE o.order_id = payment.order_id);
UPDATE payment SET cash_collected = amount WHERE payment_method='COD' AND payment_status='Paid';
