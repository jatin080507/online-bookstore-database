
CREATE DATABASE online_bookstore;
USE online_bookstore;

-- TABLES

-- Authors
CREATE TABLE author (
    author_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100),
    bio TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Categories
CREATE TABLE category (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT
) ENGINE=InnoDB;

-- Books
CREATE TABLE book (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    author_id INT NOT NULL,
    category_id INT,
    price DECIMAL(10,2) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    isbn VARCHAR(30) UNIQUE,
    published_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (author_id) REFERENCES author(author_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (category_id) REFERENCES category(category_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Customers
CREATE TABLE customer (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(30),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL
) ENGINE=InnoDB;

-- Orders
CREATE TABLE `order` (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Pending','Processing','Paid','Shipped','Delivered','Cancelled') DEFAULT 'Pending',
    estimated_delivery DATE,
    total_amount DECIMAL(12,2) DEFAULT 0.00,
    shipping_address TEXT,
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Order items
CREATE TABLE order_item (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    book_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES `order`(order_id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES book(book_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Payments - track payments for orders
CREATE TABLE payment (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    paid_amount DECIMAL(12,2) NOT NULL,
    payment_method ENUM('Card','UPI','Wallet','COD','NetBanking') DEFAULT 'Card',
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Pending','Completed','Failed','Refunded') DEFAULT 'Pending',
    transaction_ref VARCHAR(255),
    FOREIGN KEY (order_id) REFERENCES `order`(order_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Reviews
CREATE TABLE review (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    customer_id INT NOT NULL,
    rating TINYINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title VARCHAR(255),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (book_id) REFERENCES book(book_id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Price change log
CREATE TABLE price_history (
    price_history_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    old_price DECIMAL(10,2),
    new_price DECIMAL(10,2),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    admin VARCHAR(100),
    FOREIGN KEY (book_id) REFERENCES book(book_id) ON DELETE CASCADE
) ENGINE=InnoDB;


-- Low stock alerts table 
CREATE TABLE low_stock_alert (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    current_stock INT NOT NULL,
    alert_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (book_id) REFERENCES book(book_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Price update jobs log for bulk update
CREATE TABLE bulk_price_update_job (
    job_id INT AUTO_INCREMENT PRIMARY KEY,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMP NULL,
    status ENUM('Running','Success','Failed') DEFAULT 'Running',
    notes TEXT
) ENGINE=InnoDB;

-- Admins 
CREATE TABLE admin (
    admin_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    full_name VARCHAR(200),
    email VARCHAR(255) UNIQUE
) ENGINE=InnoDB;


-- Notifications for manager
CREATE TABLE notification (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    seen BOOLEAN DEFAULT FALSE
) ENGINE=InnoDB;

-- Book sales (materialized / summary) - optionally filled by procedures
CREATE TABLE monthly_sales_summary (
    id INT AUTO_INCREMENT PRIMARY KEY,
    year_month CHAR(7) NOT NULL, -- e.g. '2025-09'
    total_books_sold INT DEFAULT 0,
    total_revenue DECIMAL(14,2) DEFAULT 0.00,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- TRIGGERS & SAFEGUARDS

-- 1) Prevent book stock becoming negative when inserting order_item.
DELIMITER $$
CREATE TRIGGER before_insert_order_item
BEFORE INSERT ON order_item
FOR EACH ROW
BEGIN
    -- Atomically decrement only if enough stock exists
    UPDATE book
    SET stock = stock - NEW.quantity
    WHERE book_id = NEW.book_id
      AND stock >= NEW.quantity;
    -- If no rows were updated, there wasn't enough stock
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock for book_id or book not found.';
    END IF;
END$$
DELIMITER ;

-- 2) If order_item insert succeeds, update the order total_amount (incremental)
DELIMITER $$
CREATE TRIGGER after_insert_order_item
AFTER INSERT ON order_item
FOR EACH ROW
BEGIN
    UPDATE `order`
    SET total_amount = COALESCE(total_amount,0) + (NEW.unit_price * NEW.quantity)
    WHERE order_id = NEW.order_id;
END$$
DELIMITER ;

-- AFTER DELETE: restore stock and update order total
DELIMITER $$
CREATE TRIGGER after_delete_order_item
AFTER DELETE ON order_item
FOR EACH ROW
BEGIN
    -- Restore stock
    UPDATE book
    SET stock = stock + OLD.quantity
    WHERE book_id = OLD.book_id;
    -- Reduce order total
    UPDATE `order`
    SET total_amount = COALESCE(total_amount,0) - (OLD.unit_price * OLD.quantity)
    WHERE order_id = OLD.order_id;
END$$
DELIMITER ;

-- BEFORE UPDATE of order_item: adjust stock by difference and order total accordingly
DELIMITER $$
CREATE TRIGGER before_update_order_item
BEFORE UPDATE ON order_item
FOR EACH ROW
BEGIN
    DECLARE qty_diff INT;
    SET qty_diff = NEW.quantity - OLD.quantity; -- positive -> need more stock
    IF qty_diff > 0 THEN
        -- Try to decrement additional stock
        UPDATE book
        SET stock = stock - qty_diff
        WHERE book_id = NEW.book_id
          AND stock >= qty_diff;
        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock (update) for this book.';
        END IF;
    ELSEIF qty_diff < 0 THEN
        -- Return stock to inventory
        UPDATE book
        SET stock = stock + ABS(qty_diff)
        WHERE book_id = NEW.book_id;
    END IF;
END$$
DELIMITER ;

-- 3) Track price changes into price_history table
DELIMITER $$
CREATE TRIGGER after_update_book_price
AFTER UPDATE ON book
FOR EACH ROW
BEGIN
    IF OLD.price <> NEW.price THEN
        INSERT INTO price_history(book_id, old_price, new_price, changed_at, admin)
        VALUES (NEW.book_id, OLD.price, NEW.price, NOW(), NULL);
    END IF;
END$$
DELIMITER ;

-- STORED PROCEDURES / FUNCTIONS

-- This procedure calculates prices from current book.price and ensures stock is decremented transactionally.
DELIMITER $$
CREATE PROCEDURE place_order(
    IN p_customer_id INT,
    IN p_shipping_address TEXT,
    IN p_order_items JSON,
    OUT p_order_id INT
)
BEGIN
    DECLARE v_total DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_book_id INT;
    DECLARE v_qty INT;
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_idx INT DEFAULT 0;
    DECLARE v_len INT;

    SET p_order_id = NULL;
    SET v_len = JSON_LENGTH(p_order_items);

    IF v_len IS NULL OR v_len = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order has no items.';
    END IF;

    START TRANSACTION;

    -- Create order
    INSERT INTO `order` (customer_id, shipping_address, status, total_amount)
    VALUES (p_customer_id, p_shipping_address, 'Pending', 0.00);

    SET p_order_id = LAST_INSERT_ID();

    -- Loop over JSON array and insert order_item rows
    WHILE v_idx < v_len DO
        SET v_book_id = JSON_EXTRACT(p_order_items, CONCAT('$[', v_idx, '].book_id'));
        SET v_qty     = JSON_EXTRACT(p_order_items, CONCAT('$[', v_idx, '].quantity'));

        -- get current price and try to decrement stock atomically
        SELECT price INTO v_price FROM book WHERE book_id = v_book_id FOR UPDATE;
        IF v_price IS NULL THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Book not found.';
        END IF;

        -- Decrement stock (using UPDATE with condition)
        UPDATE book
        SET stock = stock - v_qty
        WHERE book_id = v_book_id AND stock >= v_qty;
        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock for one of the items.';
        END IF;

        -- Insert order item
        INSERT INTO order_item(order_id, book_id, quantity, unit_price)
        VALUES (p_order_id, v_book_id, v_qty, v_price);

        SET v_total = v_total + (v_price * v_qty);

        SET v_idx = v_idx + 1;
    END WHILE;

    -- Update order total
    UPDATE `order` SET total_amount = v_total WHERE order_id = p_order_id;

    COMMIT;
END$$
DELIMITER ;

-- Procedure: mark order shipped only if payment completed and payment matches total
DELIMITER $$
CREATE PROCEDURE mark_order_shipped(IN p_order_id INT)
BEGIN
    DECLARE v_total DECIMAL(12,2);
    DECLARE v_paid DECIMAL(12,2);

    SELECT total_amount INTO v_total FROM `order` WHERE order_id = p_order_id;
    IF v_total IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order not found.';
    END IF;

    SELECT SUM(p.paid_amount) INTO v_paid
    FROM payment p
    WHERE p.order_id = p_order_id AND p.status = 'Completed';

    IF v_paid IS NULL THEN SET v_paid = 0.00; END IF;

    IF v_paid < v_total THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order cannot be shipped: incomplete payment.';
    END IF;

    UPDATE `order` SET status = 'Shipped' WHERE order_id = p_order_id;
END$$
DELIMITER ;

-- Procedure: Prevent customers placing order if previous payment pending > 30 days
-- This is a check you should call before allowing a new order; alternatively, wrap in application logic.
DELIMITER $$
CREATE PROCEDURE check_customer_pending_payments(IN p_customer_id INT)
BEGIN
    DECLARE cnt INT;
    SELECT COUNT(*) INTO cnt
    FROM `order` o
    JOIN payment p ON o.order_id = p.order_id
    WHERE o.customer_id = p_customer_id
      AND p.status = 'Pending'
      AND p.payment_date < (NOW() - INTERVAL 30 DAY);

    IF cnt > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer has pending payments older than 30 days; orders blocked.';
    END IF;
END$$
DELIMITER ;

-- Bulk update book prices in a transaction (all-or-nothing)
DELIMITER $$
CREATE PROCEDURE bulk_update_prices(IN p_updates_json JSON, IN p_admin VARCHAR(100))
BEGIN
    DECLARE v_len INT DEFAULT 0;
    DECLARE v_idx INT DEFAULT 0;
    DECLARE v_book_id INT;
    DECLARE v_new_price DECIMAL(10,2);
    DECLARE job_id INT;

    SET v_len = JSON_LENGTH(p_updates_json);
    IF v_len IS NULL OR v_len = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No updates provided.';
    END IF;

    START TRANSACTION;
    INSERT INTO bulk_price_update_job(started_at, status) VALUES (NOW(), 'Running');
    SET job_id = LAST_INSERT_ID();

    WHILE v_idx < v_len DO
        SET v_book_id = JSON_EXTRACT(p_updates_json, CONCAT('$[', v_idx, '].book_id'));
        SET v_new_price = JSON_EXTRACT(p_updates_json, CONCAT('$[', v_idx, '].new_price'));

        -- Update price (will fire price_history trigger)
        UPDATE book
        SET price = v_new_price
        WHERE book_id = v_book_id;
        IF ROW_COUNT() = 0 THEN
            -- Book not found -> rollback whole batch
            UPDATE bulk_price_update_job SET finished_at = NOW(), status = 'Failed',
                notes = CONCAT('Failed at item index ', v_idx) WHERE job_id = job_id;
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = CONCAT('Bulk update failed at index ', v_idx);
        END IF;

        SET v_idx = v_idx + 1;
    END WHILE;

    UPDATE bulk_price_update_job SET finished_at = NOW(), status = 'Success' WHERE job_id = job_id;
    COMMIT;
END$$
DELIMITER ;

-- Procedure: generate monthly sales summary (fills monthly_sales_summary table)
DELIMITER $$
CREATE PROCEDURE generate_monthly_sales_summary(IN p_year_month CHAR(7)) -- 'YYYY-MM'
BEGIN
    -- Calculate total books sold and revenue for that YYYY-MM
    INSERT INTO monthly_sales_summary(year_month, total_books_sold, total_revenue, generated_at)
    SELECT p_year_month,
           IFNULL(SUM(oi.quantity),0),
           IFNULL(SUM(oi.quantity * oi.unit_price),0),
           NOW()
    FROM order_item oi
    JOIN `order` o ON oi.order_id = o.order_id
    WHERE DATE_FORMAT(o.order_date, '%Y-%m') = p_year_month;
END$$
DELIMITER ;

