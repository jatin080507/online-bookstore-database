## 📚 Online Bookstore Database

### About

This is a SQL project for an online bookstore system.
It manages books, authors, customers, orders, payments, and reviews.

---

### Features

* Store book and author details
* Manage customers and orders
* Track payments
* Store reviews and ratings
* Handle stock using triggers
* Use stored procedures for operations

---

### Files in this project

* `schema.sql` → database structure (tables, triggers, procedures)
* `data.sql` → sample data
* `queries.sql` → SQL queries

---

### How to run

```sql id="run01"
CREATE DATABASE online_bookstore;
USE online_bookstore;

-- run schema.sql
-- run data.sql
-- run queries.sql
```

---

### Queries included

1. List of books whose category is fiction
2. Customers who purchased at least 5 books in last 3 months
3. Orders placed in January 2024 with details
4. Books with low stock (less than 5)
5. Top 5 best-selling books of the year
6. Reviews and ratings for "The Midnight Library"
7. Book report (name, price, category, stock)
8. Pending orders with customer details
9. Customers who spent more than ₹10,000 in last year
10. Revenue generated from each category
11. Books that have never been purchased
12. Average rating of each book
13. Sales report (books sold and revenue per author)
14. Bulk update of book prices using transaction
15. Customer summary view (order count and total spending)

---

### Concepts used

* Joins
* GROUP BY and HAVING
* Aggregate functions
* Triggers
* Stored procedures
* Transactions

---

### Author

Jatin

---

###Note

This project is created for learning purposes.
