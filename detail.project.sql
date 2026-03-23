USE online_bookstore;

INSERT INTO author (first_name, last_name, bio)
VALUES
('Matt', 'Haig', 'Author of The Midnight Library and other works.'),
('John', 'Doe', 'Sample author for testing.'),
('Jane', 'Smith', 'Non-fiction and textbooks author.'),
('Haruki', 'Murakami', 'Japanese novelist and translator.');

INSERT INTO category (name, description)
VALUES
('Fiction', 'General fiction and literature'),
('Science & Technology', 'Books on science, technology and computing'),
('History', 'Historical books and analysis'),
('Fantasy', 'Fantasy novels and imaginative fiction');

INSERT INTO book (title, author_id, category_id, price, stock, isbn, published_date)
VALUES
('The Midnight Library',            1, 1, 299.00, 10, 'ISBN0001', '2020-08-01'),
('Intro to AI',                     3, 2, 999.00, 20, 'ISBN0002', '2023-03-10'),
('World History: A Concise Guide',  3, 3, 399.00,  3, 'ISBN0003', '2019-11-05'),
('Kafka on the Shore',              4, 1, 620.00, 20, 'ISBN0004', '2002-09-12'),
('A Beginner''s Guide to Python',   3, 2, 449.00, 30, 'ISBN0005', '2021-01-15'),
('Fantastic Beasts',                1, 4, 499.00, 15, 'ISBN0006', '2016-11-18'),
('Modern Computing Concepts',       2, 2, 799.00, 12, 'ISBN0007', '2022-07-22');

INSERT INTO customer (username, first_name, last_name, email, phone)
VALUES
('amit_sh',  'Amit',  'Sharma', 'amit.sharma@example.com',  '9876543210'),
('priya_m',  'Priya',  'Mehta', 'priya.mehta@example.com',  '9876501234'),
('rahul_s',  'Rahul',  'Singh',  'rahul.singh@example.com',  '9876123456'),
('sneha_p',  'Sneha',  'Patel',  'sneha.patel@example.com',  '9876345678');

INSERT INTO `order` (customer_id, order_date, status, estimated_delivery, total_amount, shipping_address)
VALUES
(1, '2025-09-01 10:00:00', 'Delivered', '2025-09-04', 0.00, '123 Main St, Delhi, India'),
(2, '2025-09-05 15:30:00', 'Shipped',   '2025-09-09', 0.00, '45 Park Ave, Mumbai, India'),
(3, '2025-09-07 09:15:00', 'Pending',   NULL,        0.00, '78 MG Road, Bangalore, India'),
(4, '2025-09-10 12:00:00', 'Delivered', '2025-09-14', 0.00, '9 MG Marg, Ahmedabad, India');


INSERT INTO order_item (order_id, book_id, quantity, unit_price)
VALUES
(1, 1, 2, 299.00),  -- Amit: 2 x The Midnight Library
(1, 5, 1, 449.00),  -- Amit: 1 x A Beginner's Guide to Python
(2, 7, 1, 799.00),  -- Priya: 1 x Modern Computing Concepts
(2, 6, 2, 499.00),  -- Priya: 2 x Fantastic Beasts
(3, 2, 1, 999.00),  -- Rahul: pending order for Intro to AI
(4, 4, 1, 620.00);  -- Sneha: 1 x Kafka on the Shore

INSERT INTO payment (order_id, paid_amount, payment_method, payment_date, status, transaction_ref)
VALUES
(1,  (2*299.00 + 1*449.00), 'Card',   '2025-09-01 10:05:00', 'Completed', 'TXN-A001'),
(2,  (1*799.00 + 2*499.00), 'UPI',    '2025-09-05 15:40:00', 'Completed', 'TXN-A002'),
(3,  0.00,                   'COD',    '2025-09-07 09:20:00', 'Pending',   NULL),
(4,  (1*620.00),             'Card',   '2025-09-10 12:10:00', 'Completed', 'TXN-A004');

INSERT INTO review (book_id, customer_id, rating, title, comment)
VALUES
(1, 1, 5, 'Loved it',       'A wonderful read — very uplifting.'),
(5, 1, 4, 'Useful guide',   'Great beginner guide for learning Python.'),
(7, 2, 4, 'Good textbook',  'Detailed coverage of computing topics.'),
(6, 2, 5, 'Magical tale',   'Entertaining and imaginative.'),
(4, 4, 5, 'Beautifully written', 'Deep and moving narrative.');

INSERT INTO notification (message, created_at, seen)
VALUES
('Order #1 has been delivered to the customer.', '2025-09-04 09:00:00', TRUE),
('Order #2 has been shipped (courier picked up).', '2025-09-06 08:30:00', FALSE),
('Order #3 is pending payment - reminder sent to customer.', '2025-09-08 10:00:00', FALSE),
('Low stock alert created for books below threshold.', '2025-09-15 00:00:00', FALSE);

INSERT INTO admin (username, full_name, email)
VALUES
('admin1', 'Store Admin', 'admin1@bookstore.local');

INSERT INTO low_stock_alert (book_id, current_stock)
SELECT b.book_id, b.stock FROM book b WHERE b.stock < 5;

CALL generate_monthly_sales_summary('2025-09');

-- SELECT COUNT(*) AS authors FROM author;
-- SELECT COUNT(*) AS books FROM book;
-- SELECT COUNT(*) AS customers FROM customer;
-- SELECT COUNT(*) AS orders FROM `order`;
-- SELECT SUM(total_amount) AS total_revenue FROM `order`;
