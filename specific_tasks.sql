USE online_bookstore;

-- 1. List of books whose category is fiction
SELECT b.book_id, b.title, b.price, b.stock
FROM book b
JOIN category c ON b.category_id = c.category_id
WHERE c.name = 'Fiction' AND b.stock > 0;

-- 2. List the details of all customers who have purchased at least five books in the last three months.
SELECT c.customer_id, c.username, CONCAT(c.first_name,' ',c.last_name) AS name, 
       SUM(oi.quantity) AS total_books_last_3_months
FROM customer c
JOIN `order` o ON c.customer_id = o.customer_id
JOIN order_item oi ON o.order_id = oi.order_id
WHERE o.order_date >= (CURRENT_DATE - INTERVAL 3 MONTH)
GROUP BY c.customer_id
HAVING total_books_last_3_months >= 5;

-- 3. Find all orders placed in 'January 2024', including customer details, book titles, and total order value.
SELECT o.order_id, o.order_date, c.customer_id, c.username, c.email, o.total_amount,
       GROUP_CONCAT(CONCAT(b.title, ' x', oi.quantity) SEPARATOR '; ') AS items
FROM `order` o
JOIN customer c ON o.customer_id = c.customer_id
JOIN order_item oi ON o.order_id = oi.order_id
JOIN book b ON oi.book_id = b.book_id
WHERE DATE_FORMAT(o.order_date, '%Y-%m') = '2024-01'
GROUP BY o.order_id;

-- 4. Identify books with fewer than five copies left in stock and generate an alert for restocking.
SELECT book_id, title, stock FROM book WHERE stock < 5;

-- 5. List the top five best-selling books of the year based on total sales revenue.
SELECT b.book_id, b.title, IFNULL(SUM(oi.quantity * oi.unit_price),0) AS revenue
FROM book b
JOIN order_item oi ON b.book_id = oi.book_id
JOIN `order` o ON oi.order_id = o.order_id
WHERE DATE_FORMAT(o.order_date, '%Y') = DATE_FORMAT(CURRENT_DATE, '%Y')
GROUP BY b.book_id
ORDER BY revenue DESC
LIMIT 5;

-- 6. Retrieve all reviews and ratings for the book titled "The Midnight Library" along with the names of customers who posted them.
SELECT r.review_id, r.rating, r.title, r.comment, r.created_at,
       CONCAT(c.first_name,' ',COALESCE(c.last_name,'')) AS customer_name
FROM review r
JOIN book b ON r.book_id = b.book_id
JOIN customer c ON r.customer_id = c.customer_id
WHERE b.title = 'The Midnight Library';

-- 7. Generate a report showing the name, price, category, and stock level of each book.
SELECT 
    b.title AS book_name,
    b.price,
    c.name AS category,
    b.stock
FROM book b
LEFT JOIN category c ON b.category_id = c.category_id
ORDER BY b.title;

-- 8. Retrieve details of all pending orders, including the estimated delivery date and customer contact details.
SELECT 
    o.order_id,
    o.order_date,
    o.estimated_delivery,
    c.customer_id,
    CONCAT(c.first_name, ' ', COALESCE(c.last_name, '')) AS customer_name,
    c.email,
    c.phone,
    o.total_amount
FROM `order` o
JOIN customer c ON o.customer_id = c.customer_id
WHERE o.status = 'Pending'
ORDER BY o.order_date;

-- 9. Identify customers who have spent more than ₹10,000 in the bookstore in the past year.
SELECT c.customer_id, c.username, CONCAT(c.first_name,' ',c.last_name) AS name, 
       SUM(o.total_amount) AS total_spent_last_year
FROM customer c
JOIN `order` o ON c.customer_id = o.customer_id
WHERE o.order_date >= (CURRENT_DATE - INTERVAL 1 YEAR)
GROUP BY c.customer_id
HAVING total_spent_last_year > 10000;

-- 10. Find the total revenue generated from each book category, sorted from highest to lowest revenue.
SELECT 
    cat.category_id,
    cat.name AS category,
    IFNULL(SUM(oi.quantity * oi.unit_price), 0) AS total_revenue
FROM category cat
LEFT JOIN book b ON cat.category_id = b.category_id
LEFT JOIN order_item oi ON b.book_id = oi.book_id
LEFT JOIN `order` o ON oi.order_id = o.order_id
GROUP BY cat.category_id
ORDER BY total_revenue DESC;

-- 11. List the details of books that have never been purchased since being added to the inventory.
SELECT 
    b.book_id,
    b.title,
    b.stock,
    b.price
FROM book b
LEFT JOIN order_item oi ON b.book_id = oi.book_id
WHERE oi.order_item_id IS NULL;

-- 12. Find the average rating of each book, considering only books with at least 1 reviews.
SELECT 
    b.book_id,
    b.title,
    COUNT(r.review_id) AS total_reviews,
    ROUND(AVG(r.rating),2) AS avg_rating
FROM book b
JOIN review r ON b.book_id = r.book_id
GROUP BY b.book_id
HAVING total_reviews >= 1;

	
-- 13. Generate a sales report showing the total number of books sold and total revenue for each author.
SELECT 
    a.author_id,
    CONCAT(a.first_name, ' ', a.last_name) AS author_name,
    IFNULL(SUM(oi.quantity),0) AS total_books_sold,
    IFNULL(SUM(oi.quantity * oi.unit_price),0) AS total_revenue
FROM author a
LEFT JOIN book b ON a.author_id = b.author_id
LEFT JOIN order_item oi ON b.book_id = oi.book_id
GROUP BY a.author_id
ORDER BY total_revenue DESC;
    
-- 14. Develop a process to bulk-update book prices, ensuring all changes within a batch are either successful or none are
DELIMITER $$
CREATE PROCEDURE bulk_update_prices_simple()
BEGIN
    START TRANSACTION;

    UPDATE book SET price = 350 WHERE book_id = 1;
    UPDATE book SET price = 1050 WHERE book_id = 2;
    UPDATE book SET price = 450 WHERE book_id = 3;

    COMMIT;
END$$

DELIMITER ;

-- 15. Create a view that displays each customer's name, order count, and total spending.

CREATE VIEW customer_summary AS
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', COALESCE(c.last_name,'')) AS customer_name,
    COUNT(o.order_id) AS total_orders,
    IFNULL(SUM(o.total_amount),0) AS total_spent
FROM customer c
LEFT JOIN `order` o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;
