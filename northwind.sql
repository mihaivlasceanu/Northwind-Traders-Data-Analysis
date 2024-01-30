/*=========================
 IMPORTING THE DATASETS
=========================*/

CREATE TABLE categories (
	category_id TEXT,
	category_name TEXT,
	description TEXT
)

-- \COPY categories FROM 'C:\Users\User\Desktop\Northwind\originals\categories.csv' WITH CSV HEADER DELIMITER ','

SELECT * FROM categories

CREATE TABLE customers (
	customer_id TEXT,
	company_name TEXT,
	contact_name TEXT,
	contact_title TEXT,
	city TEXT,
	country TEXT
)

-- \COPY customers FROM 'C:\Users\User\Desktop\Northwind\originals\customers.csv' WITH CSV HEADER DELIMITER ','

SELECT * FROM customers
LIMIT 5

CREATE TABLE employees (
	employee_id TEXT,
	employee_name TEXT,
	title TEXT,
	city TEXT,
	country TEXT,
	reports_to TEXT
)

-- \COPY employees FROM 'C:\Users\User\Desktop\Northwind\originals\employees.csv' WITH CSV HEADER DELIMITER ','

SELECT * FROM employees

CREATE TABLE order_details (
	order_id TEXT,
	product_id TEXT,
	unit_price NUMERIC,
	quantity NUMERIC,
	discount NUMERIC
)

-- \COPY order_details FROM 'C:\Users\User\Desktop\Northwind\originals\order_details.csv' WITH CSV HEADER DELIMITER ','

SELECT * FROM order_details
LIMIT 5

CREATE TABLE orders (
	order_id TEXT,
	customer_id TEXT,
	employee_id TEXT,
	order_date DATE,
	required_date DATE,
	shipped_date DATE,
	shipper_id TEXT,
	freight NUMERIC
)

-- \COPY orders FROM 'C:\Users\User\Desktop\Northwind\originals\orders.csv' WITH CSV HEADER DELIMITER ','

SELECT * FROM orders
LIMIT 5

CREATE TABLE products (
	product_id TEXT,
	product_name TEXT,
	qty_per_unit TEXT,
	unit_price NUMERIC,
	discontinued BOOLEAN,
	category_id  TEXT
)

-- \COPY products FROM 'C:\Users\User\Desktop\Northwind\originals\products.csv' WITH CSV HEADER DELIMITER ','

SELECT * FROM products
LIMIT 5

CREATE TABLE shippers (
	shipper_id TEXT,
	company_name TEXT
)

-- \COPY shippers FROM 'C:\Users\User\Desktop\Northwind\originals\shippers.csv' WITH CSV HEADER DELIMITER ','

SELECT * FROM shippers


/*=========================
 CREATING ADDITIONAL TABLES
=========================*/

-- Further down the line (subsection "Sales Overview", question 7), we will be needing a special date dimension table that will allow us 
-- to identify the dates on which there were 0 orders/sales for each country and city

SELECT
GENERATE_SERIES('2013-07-01', '2015-05-01', INTERVAL '1 month')::DATE AS date,
DATE_PART('year', GENERATE_SERIES('2013-07-01', '2015-05-01', INTERVAL '1 month')::DATE) AS year,
DATE_PART('month', GENERATE_SERIES('2013-07-01', '2015-05-01', INTERVAL '1 month')::DATE) AS month
INTO monthly_date_dimension

SELECT * FROM monthly_date_dimension

SELECT 
DISTINCT country,
city
INTO countries_only
FROM customers

SELECT * FROM countries_only
LIMIT 5

CREATE TABLE date_and_country AS
SELECT * FROM countries_only
CROSS JOIN monthly_date_dimension
ORDER BY 1,2,3

SELECT * FROM date_and_country
LIMIT 5

/*=========================
 SALES OVERVIEW
=========================*/

-- 1. Net sales by year + year-over-year change

-- Note: the comparison to the previous year is not exactly relevant as 
-- we are comparing the entirety of 2014 to a few months of 2013 (July-December, inclusive ) 
-- and similarly, a few months of 2015 (January-May, inclusive)

WITH yearly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
GROUP BY DATE_PART('year', order_date)
ORDER BY DATE_PART('year', order_date)
)

SELECT
year,
net_sales,
ROUND(LAG(net_sales) OVER (ORDER BY year),2) AS prev_year_sales,
net_sales - LAG(net_sales) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (ORDER BY year))/LAG(net_sales) OVER (ORDER BY year),2) AS pct_change
FROM yearly_sales_cte
ORDER BY 1

-- 2. Net sales by period + period-over-period change
-- (as we do not have data for the same months for 2013 and 2015, we will have to split our analysis into two periods)

-- 2.1 July-December 2014 vs July-December 2013

WITH sales_by_month_cte AS (
SELECT
o.order_id,
o.order_date,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
quantity,
unit_price,
discount
FROM order_details od
INNER JOIN orders o ON od.order_id=o.order_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
)

, period_sales_cte AS (
SELECT
year,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM sales_by_month_cte
GROUP BY year
ORDER BY year
) 

SELECT
year,
net_sales,
ROUND(LAG(net_sales) OVER (ORDER BY year),2) AS same_period_prev_year_sales,
net_sales - LAG(net_sales) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (ORDER BY year))/LAG(net_sales) OVER (ORDER BY year),2) AS pct_change
FROM period_sales_cte
ORDER BY 1

-- 2.2 January-May 2015 vs January-May 2014

WITH sales_by_month_cte AS (
SELECT
o.order_id,
o.order_date,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
quantity,
unit_price,
discount
FROM order_details od
INNER JOIN orders o ON od.order_id=o.order_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
)

, period_sales_cte AS (
SELECT
year,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM sales_by_month_cte
GROUP BY year
ORDER BY year
) 

SELECT
year,
net_sales,
ROUND(LAG(net_sales) OVER (ORDER BY year),2) AS same_period_prev_year_sales,
net_sales - LAG(net_sales) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (ORDER BY year))/LAG(net_sales) OVER (ORDER BY year),2) AS pct_change
FROM period_sales_cte
ORDER BY 1

-- 3. Net sales by month + month-over-month change

WITH monthly_sales_cte AS (
SELECT
DATE_TRUNC('month', order_date)::DATE AS month,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date)
)

SELECT
month,
net_sales,
ROUND(LAG(net_sales) OVER (ORDER BY month),2) AS prev_month_sales,
net_sales - LAG(net_sales) OVER (ORDER BY month) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (ORDER BY month))/LAG(net_sales) OVER (ORDER BY month),2) AS pct_change
FROM monthly_sales_cte
ORDER BY 1
LIMIT 10

-- 4. Net sales by month vs same month of previous year

WITH sales_by_month_cte AS (
SELECT
o.order_id,
o.order_date,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
quantity,
unit_price,
discount
FROM order_details od
INNER JOIN orders o ON od.order_id=o.order_id
)

, monthly_sales_cte AS (
SELECT
year,
month,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM sales_by_month_cte
GROUP BY year, month
ORDER BY year, month
)

SELECT
year,
month,
net_sales,
ROUND(LAG(net_sales) OVER (PARTITION BY month ORDER BY year),2) AS same_month_prev_year_sales,
net_sales - LAG(net_sales) OVER (PARTITION BY month ORDER BY year) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (PARTITION BY month ORDER BY year))/LAG(net_sales) OVER (PARTITION BY month ORDER BY year),2) AS pct_change
FROM monthly_sales_cte
ORDER BY year, month
LIMIT 15

-- 5. Net sales by country and year + year-over-year change
-- Note: simiarly as with question 1, it is not exactly relevant as we are not comparing the same periods (rather, a full year vs a few months)

WITH yearly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
country,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), country
ORDER BY DATE_PART('year', order_date), country
)

SELECT
year,
country,
net_sales,
ROUND(LAG(net_sales) OVER (PARTITION BY country ORDER BY year),2) AS prev_year_sales,
net_sales - LAG(net_sales) OVER (PARTITION BY country ORDER BY year) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (PARTITION BY country ORDER BY year))/LAG(net_sales) OVER (PARTITION BY country ORDER BY year),2) AS pct_change
FROM yearly_sales_cte
ORDER BY 1,2
LIMIT 30

-- 6. Net sales by country and period + period-over-period change
-- (solution to previous question's issue)

-- 6.1 July-December 2014 vs July-December 2013

WITH sales_by_month_cte AS (
SELECT
o.order_id,
o.order_date,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
country,
quantity,
unit_price,
discount
FROM order_details od
INNER JOIN orders o ON od.order_id=o.order_id
INNER JOIN customers c ON o.customer_id=c.customer_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
)

, period_sales_cte AS (
SELECT
year,
country,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM sales_by_month_cte
GROUP BY year, country
ORDER BY year, country
) 

SELECT
year,
country,
net_sales,
ROUND(LAG(net_sales) OVER (PARTITION BY country ORDER BY year),2) AS same_period_prev_year_sales,
net_sales - LAG(net_sales) OVER (PARTITION BY country ORDER BY year) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (PARTITION BY country ORDER BY year))/LAG(net_sales) OVER (PARTITION BY country ORDER BY year),2) AS pct_change
FROM period_sales_cte
ORDER BY 1,2

-- 6.2 January-May 2015 vs January-May 2014

WITH sales_by_month_cte AS (
SELECT
o.order_id,
o.order_date,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
country,
quantity,
unit_price,
discount
FROM order_details od
INNER JOIN orders o ON od.order_id=o.order_id
INNER JOIN customers c ON o.customer_id=c.customer_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
)

, period_sales_cte AS (
SELECT
year,
country,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM sales_by_month_cte
GROUP BY year, country
ORDER BY year, country
) 

SELECT
year,
country,
net_sales,
ROUND(LAG(net_sales) OVER (PARTITION BY country ORDER BY year),2) AS same_period_prev_year_sales,
net_sales - LAG(net_sales) OVER (PARTITION BY country ORDER BY year) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (PARTITION BY country ORDER BY year))/LAG(net_sales) OVER (PARTITION BY country ORDER BY year),2) AS pct_change
FROM period_sales_cte
ORDER BY 1,2
LIMIT 25

-- 7. Net sales by country and month + month-over-month change

-- Version 1:
-- The problem with this first version is that, because of the way window functions work, we end up skipping the months that had O sales, 
-- and thus come to conclusions that do not truly reflect reality. For example, for Brazil, we compare the months for which we have actual sales - months 9 and 11, 
-- skipping month 10 when the fact that there were 0 sales in that particular month would tell us a completeley different story than before.

WITH monthly_sales_cte AS (
SELECT
DATE_TRUNC('month', order_date)::DATE AS month,
--DATE_PART('year', order_date) AS year,
country,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_TRUNC('month', order_date), country
ORDER BY DATE_TRUNC('month', order_date), country
)

SELECT
month,
country,
net_sales,
ROUND(LAG(net_sales) OVER (PARTITION BY country ORDER BY month),2) AS prev_month_sales,
net_sales - LAG(net_sales) OVER (PARTITION BY country ORDER BY month) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (PARTITION BY country ORDER BY month))/LAG(net_sales) OVER (PARTITION BY country ORDER BY month),2) AS pct_change
FROM monthly_sales_cte
ORDER BY month, country
LIMIT 20

-- Version 2:
-- In which we find a workaround for the issues we have with Version 1, by using the previously created date dimension table

WITH net_sales_cte AS (
SELECT
order_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales_per_order
FROM order_details
GROUP BY order_id
ORDER BY 1
)

, net_sales_by_country_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
country,
net_sales_per_order
FROM net_sales_cte
INNER JOIN orders ON net_sales_cte.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
)

, monthly_sales_by_country_cte AS (
SELECT
year,
month,
country,
ROUND(SUM(net_sales_per_order), 2) AS net_sales_per_month
FROM net_sales_by_country_cte
GROUP BY 1,2,3
ORDER BY 1,2,3
)

, missing_months_added_cte AS (
SELECT DISTINCT
t1.year,
t1.month,
t1.country,
COALESCE(net_sales_per_month, 0) AS net_sales_per_month
FROM date_and_country t1
LEFT JOIN monthly_sales_by_country_cte t2 ON t1.year=t2.year AND t1.month=t2.month AND t1.country=t2.country
ORDER BY 1,2,3
)

SELECT
year,
month,
country,
net_sales_per_month,
LAG(net_sales_per_month) OVER (PARTITION BY country ORDER BY year, month) AS prev_month_net_sales,
net_sales_per_month - LAG(net_sales_per_month) OVER (PARTITION BY country ORDER BY year, month) AS abs_change,
ROUND(100.0 * (net_sales_per_month - LAG(net_sales_per_month) OVER (PARTITION BY country ORDER BY year, month)) /  NULLIF(LAG(net_sales_per_month) OVER (PARTITION BY country ORDER BY year, month), 0), 2) AS pct_change
FROM missing_months_added_cte
ORDER BY 1,2,3
LIMIT 30

-- 8. Net sales by country and month vs same month of previous year

WITH sales_by_month_cte AS (
SELECT
o.order_id,
o.order_date,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
country,
quantity,
unit_price,
discount
FROM order_details od
INNER JOIN orders o ON od.order_id=o.order_id
INNER JOIN customers c ON o.customer_id=c.customer_id
)

, monthly_sales_cte AS (
SELECT
year,
month,
country,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM sales_by_month_cte
GROUP BY year, month, country
ORDER BY year, month, country
)

SELECT
year,
month,
country,
net_sales,
ROUND(LAG(net_sales) OVER (PARTITION BY month, country ORDER BY year),2) AS same_month_prev_year_sales,
net_sales - LAG(net_sales) OVER (PARTITION BY month, country ORDER BY year) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (PARTITION BY month, country ORDER BY year))/LAG(net_sales) OVER (PARTITION BY month, country ORDER BY year),2) AS pct_change
FROM monthly_sales_cte
ORDER BY year, month, country
LIMIT 10

-- 9. Number of orders + year-over-year change

WITH orders_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
COUNT(DISTINCT order_id) AS nr_orders,
LAG(COUNT(DISTINCT order_id)) OVER (ORDER BY DATE_PART('year', order_date)) AS prev_year_nr_orders
FROM orders 
GROUP BY DATE_PART('year', order_date)
ORDER BY DATE_PART('year', order_date)
)

SELECT
year,
nr_orders,
prev_year_nr_orders,
nr_orders - prev_year_nr_orders AS abs_change,
ROUND(100.0 * (nr_orders - prev_year_nr_orders)/ prev_year_nr_orders, 2) AS pct_change
FROM orders_count_cte

-- 10. Number of orders by period + period-over-period change

-- 10.1 July-December 2014 vs July-December 2013

WITH orders_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
COUNT(DISTINCT order_id) AS nr_orders,
LAG(COUNT(DISTINCT order_id)) OVER (ORDER BY DATE_PART('year', order_date)) AS prev_year_nr_orders
FROM orders 
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY DATE_PART('year', order_date)
ORDER BY DATE_PART('year', order_date)
)

SELECT
year,
nr_orders,
prev_year_nr_orders,
nr_orders - prev_year_nr_orders AS abs_change,
ROUND(100.0 * (nr_orders - prev_year_nr_orders)/ prev_year_nr_orders, 2) AS pct_change
FROM orders_count_cte

-- 10.2 January-May 2015 vs January-May 2014

WITH orders_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
COUNT(DISTINCT order_id) AS nr_orders,
LAG(COUNT(DISTINCT order_id)) OVER (ORDER BY DATE_PART('year', order_date)) AS prev_year_nr_orders
FROM orders 
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY DATE_PART('year', order_date)
ORDER BY DATE_PART('year', order_date)
)

SELECT
year,
nr_orders,
prev_year_nr_orders,
nr_orders - prev_year_nr_orders AS abs_change,
ROUND(100.0 * (nr_orders - prev_year_nr_orders)/ prev_year_nr_orders, 2) AS pct_change
FROM orders_count_cte

-- 11. Number of orders by month + month-over-month change

WITH orders_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
COUNT(DISTINCT order_id) AS nr_orders
FROM orders 
GROUP BY 1,2
ORDER BY 1,2
)

, monthly_orders_cte AS (
SELECT
year,
month,
nr_orders,
LAG(nr_orders) OVER (ORDER BY year, month) AS prev_month_nr_orders
FROM orders_count_cte
)

SELECT
year,
month,
nr_orders,
prev_month_nr_orders,
nr_orders - prev_month_nr_orders AS abs_change,
ROUND(100.0 * (nr_orders - prev_month_nr_orders)/ prev_month_nr_orders, 2) AS pct_change
FROM monthly_orders_cte
ORDER BY 1,2

-- 12. Number of orders by month vs same month of previous year

WITH orders_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
COUNT(DISTINCT order_id) AS nr_orders
FROM orders 
GROUP BY 1,2
ORDER BY 1,2
)

, monthly_orders_cte AS (
SELECT
year,
month,
nr_orders,
LAG(nr_orders) OVER (PARTITION BY month ORDER BY year) AS same_month_prev_year_nr_orders
FROM orders_count_cte
)

SELECT
year,
month,
nr_orders,
same_month_prev_year_nr_orders,
nr_orders - same_month_prev_year_nr_orders AS abs_change,
ROUND(100.0 * (nr_orders - same_month_prev_year_nr_orders)/ same_month_prev_year_nr_orders, 2) AS pct_change
FROM monthly_orders_cte
ORDER BY 1,2

-- 13. Number of orders by country and year + year-over-year change
-- Note: simiarly as with question 1, it is not relevant as we are not comparing the same periods (a full year vs a few months)

WITH orders_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
country,
COUNT(DISTINCT orders.order_id) AS nr_orders
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), country
ORDER BY DATE_PART('year', order_date), country
)

SELECT
year,
country,
nr_orders,
ROUND(LAG(nr_orders) OVER (PARTITION BY country ORDER BY year),2) AS prev_year_nr_orders,
nr_orders - LAG(nr_orders) OVER (PARTITION BY country ORDER BY year) AS abs_change,
ROUND(100.0 * (nr_orders - LAG(nr_orders) OVER (PARTITION BY country ORDER BY year))/LAG(nr_orders) OVER (PARTITION BY country ORDER BY year),2) AS pct_change
FROM orders_count_cte
ORDER BY 1,2
LIMIT 30

-- 14. Number of orders by country and period + period-over-period change (soluton to previous question's issue)

-- 14.1 July-December 2014 vs July-December 2013

WITH orders_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
country,
COUNT(DISTINCT orders.order_id) AS nr_orders
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY DATE_PART('year', order_date), country
ORDER BY DATE_PART('year', order_date), country
)

SELECT
year,
country,
nr_orders,
ROUND(LAG(nr_orders) OVER (PARTITION BY country ORDER BY year),2) AS prev_year_nr_orders,
nr_orders - LAG(nr_orders) OVER (PARTITION BY country ORDER BY year) AS abs_change,
ROUND(100.0 * (nr_orders - LAG(nr_orders) OVER (PARTITION BY country ORDER BY year))/LAG(nr_orders) OVER (PARTITION BY country ORDER BY year),2) AS pct_change
FROM orders_count_cte
ORDER BY 1,2

-- 14.2 January-May 2015 vs January-May 2014

WITH orders_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
country,
COUNT(DISTINCT orders.order_id) AS nr_orders
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY DATE_PART('year', order_date), country
ORDER BY DATE_PART('year', order_date), country
)

SELECT
year,
country,
nr_orders,
ROUND(LAG(nr_orders) OVER (PARTITION BY country ORDER BY year),2) AS prev_year_nr_orders,
nr_orders - LAG(nr_orders) OVER (PARTITION BY country ORDER BY year) AS abs_change,
ROUND(100.0 * (nr_orders - LAG(nr_orders) OVER (PARTITION BY country ORDER BY year))/LAG(nr_orders) OVER (PARTITION BY country ORDER BY year),2) AS pct_change
FROM orders_count_cte
ORDER BY 1,2

-- 15. Number of orders by country and month + month-over-month change

-- Version 1:
-- Just as for sales, the problem with this first version is that, because of the way window functions work, 
-- we end up skipping the months that had O orders, and thus come to conclusions that do not truly reflect reality. 
-- For example, for Brazil, we compare the months for which we have actual orders - months 9 and 11, 
-- skipping month 10 when the fact that there were 0 orders in that particular month would tell us a completeley different story than previously.

WITH monthly_orders_cte AS (
SELECT
DATE_PART('year', order_date) AS year,	
DATE_PART('month', order_date) AS month,
country,
COUNT(DISTINCT orders.order_id) AS nr_orders 
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), DATE_PART('month', order_date),  country
ORDER BY DATE_PART('year', order_date), DATE_PART('month', order_date), country
)

SELECT
year,
month,
country,
nr_orders,
ROUND(LAG(nr_orders) OVER (PARTITION BY country ORDER BY year, month),2) AS prev_month_nr_orders,
nr_orders - LAG(nr_orders) OVER (PARTITION BY country ORDER BY year, month) AS abs_change,
ROUND(100.0 * (nr_orders - LAG(nr_orders) OVER (PARTITION BY country ORDER BY year, month))/LAG(nr_orders) OVER (PARTITION BY country ORDER BY year, month),2) AS pct_change
FROM monthly_orders_cte
ORDER BY year, month, country
LIMIT 30

-- Version 2:
-- In which we find a workaround for the issues we have with Version 1, by using a data dimension table

WITH monthly_orders_cte AS (
SELECT
DATE_PART('year', order_date) AS year,	
DATE_PART('month', order_date) AS month,
country,
COUNT(DISTINCT orders.order_id) AS nr_orders 
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), DATE_PART('month', order_date),  country
ORDER BY DATE_PART('year', order_date), DATE_PART('month', order_date), country
)

, missing_months_added_cte AS (
SELECT DISTINCT
t1.year,
t1.month,
t1.country,
COALESCE(nr_orders, 0) AS nr_orders 
FROM date_and_country t1
LEFT JOIN monthly_orders_cte t2 ON t1.year=t2.year AND t1.month=t2.month AND t1.country=t2.country
ORDER BY 1,2,3
)

SELECT
year,
month,
country,
nr_orders,
LAG(nr_orders) OVER (PARTITION BY country ORDER BY year, month) AS prev_month_nr_orders,
nr_orders - LAG(nr_orders) OVER (PARTITION BY country ORDER BY year, month) AS abs_change,
ROUND(100.0 * (nr_orders - LAG(nr_orders) OVER (PARTITION BY country ORDER BY year, month)) /  NULLIF(LAG(nr_orders) OVER (PARTITION BY country ORDER BY year, month), 0), 2) AS pct_change
FROM missing_months_added_cte
ORDER BY 1,2,3
LIMIT 30

-- 16. Number of orders by country and month vs same month of previous year

WITH monthly_orders_cte AS (
SELECT
DATE_PART('year', order_date) AS year,	
DATE_PART('month', order_date) AS month,
country,
COUNT(DISTINCT orders.order_id) AS nr_orders 
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), DATE_PART('month', order_date),  country
ORDER BY DATE_PART('year', order_date), DATE_PART('month', order_date), country
)

SELECT
year,
month,
country,
nr_orders,
ROUND(LAG(nr_orders) OVER (PARTITION BY month, country ORDER BY year),2) AS same_month_prev_year_nr_orders,
nr_orders - LAG(nr_orders) OVER (PARTITION BY month, country ORDER BY year) AS abs_change,
ROUND(100.0 * (nr_orders - LAG(nr_orders) OVER (PARTITION BY month, country ORDER BY year))/LAG(nr_orders) OVER (PARTITION BY month, country ORDER BY year),2) AS pct_change
FROM monthly_orders_cte
ORDER BY year, month, country
LIMIT 10

-- 17. Discounts by year + year-over-year change

WITH yearly_discounts_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
ROUND(SUM(quantity*unit_price*discount),2) AS discount_per_year
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
GROUP BY DATE_PART('year', order_date)
ORDER BY DATE_PART('year', order_date)
)

SELECT
year,
discount_per_year,
ROUND(LAG(discount_per_year) OVER (ORDER BY year),2) AS prev_year_discount,
discount_per_year - LAG(discount_per_year) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (discount_per_year - LAG(discount_per_year) OVER (ORDER BY year))/LAG(discount_per_year) OVER (ORDER BY year),2) AS pct_change
FROM yearly_discounts_cte
ORDER BY 1

-- 18. Discounts by period + period-over-period change

-- 18.1 July-December 2014 vs July-December 2013

WITH sales_by_month_cte AS (
SELECT
o.order_id,
o.order_date,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
quantity,
unit_price,
discount
FROM order_details od
INNER JOIN orders o ON od.order_id=o.order_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
)

, period_discounts_cte AS (
SELECT
year,
ROUND(SUM(quantity*unit_price*discount),2) AS discount_per_period
FROM sales_by_month_cte
GROUP BY year
ORDER BY year
) 

SELECT
year,
discount_per_period,
ROUND(LAG(discount_per_period) OVER (ORDER BY year),2) AS same_period_prev_year_discount,
discount_per_period - LAG(discount_per_period) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (discount_per_period - LAG(discount_per_period) OVER (ORDER BY year))/LAG(discount_per_period) OVER (ORDER BY year),2) AS pct_change
FROM period_discounts_cte
ORDER BY 1

-- 18.2 January-May 2015 vs January-May 2014

WITH sales_by_month_cte AS (
SELECT
o.order_id,
o.order_date,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
quantity,
unit_price,
discount
FROM order_details od
INNER JOIN orders o ON od.order_id=o.order_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
)

, period_discounts_cte AS (
SELECT
year,
ROUND(SUM(quantity*unit_price*discount),2) AS discount_per_period
FROM sales_by_month_cte
GROUP BY year
ORDER BY year
) 

SELECT
year,
discount_per_period,
ROUND(LAG(discount_per_period) OVER (ORDER BY year),2) AS same_period_prev_year_discount,
discount_per_period - LAG(discount_per_period) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (discount_per_period - LAG(discount_per_period) OVER (ORDER BY year))/LAG(discount_per_period) OVER (ORDER BY year),2) AS pct_change
FROM period_discounts_cte
ORDER BY 1

-- 19. Discounts by month + month-over-month change

WITH monthly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
ROUND(SUM(quantity*unit_price*discount), 2) AS discount_per_month
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
GROUP BY 1,2
ORDER BY 1,2
)

SELECT
year,
month,
discount_per_month,
ROUND(LAG(discount_per_month) OVER (ORDER BY year, month),2) AS prev_month_discount,
discount_per_month - LAG(discount_per_month) OVER (ORDER BY year, month) AS abs_change,
ROUND(100.0 * (discount_per_month - LAG(discount_per_month) OVER (ORDER BY year, month))/LAG(discount_per_month) OVER (ORDER BY year, month),2) AS pct_change
FROM monthly_sales_cte
ORDER BY 1,2

-- 20. Discounts by country and month vs same month of previous year

WITH sales_by_month_cte AS (
SELECT
o.order_id,
o.order_date,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
quantity,
unit_price,
discount
FROM order_details od
INNER JOIN orders o ON od.order_id=o.order_id
)

, monthly_discounts_cte AS (
SELECT
year,
month,
ROUND(SUM(quantity*unit_price*discount),2) AS discount_per_month
FROM sales_by_month_cte
GROUP BY year, month
ORDER BY year, month
)

SELECT
year,
month,
discount_per_month,
ROUND(LAG(discount_per_month) OVER (PARTITION BY month ORDER BY year),2) AS same_month_prev_year_discount,
discount_per_month - LAG(discount_per_month) OVER (PARTITION BY month ORDER BY year) AS abs_change,
ROUND(100.0 * (discount_per_month - LAG(discount_per_month) OVER (PARTITION BY month ORDER BY year))/LAG(discount_per_month) OVER (PARTITION BY month ORDER BY year),2) AS pct_change
FROM monthly_discounts_cte
ORDER BY year, month


/*=========================
 CUSTOMER ANALYSIS
=========================*/

-- 1. Number of customers by year + year-over-year change

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
COUNT(DISTINCT customer_id) AS nr_customers,
LAG(COUNT(DISTINCT customer_id)) OVER (ORDER BY DATE_PART('year', order_date)) AS prev_year_nr_customers
FROM orders
GROUP BY DATE_PART('year', order_date)
ORDER BY DATE_PART('year', order_date)
)

SELECT
year,
nr_customers,
prev_year_nr_customers,
nr_customers - prev_year_nr_customers AS abs_change,
ROUND(100.0 * (nr_customers - prev_year_nr_customers)/ prev_year_nr_customers, 2) AS pct_change
FROM customers_count_cte

-- 2.  Number of customers by period + period-over-period change
-- (we do not have data for the same months for 2013 and 2015 so we will have to split our analysis in two)

-- 2.1 July-December 2014 vs July-December 2013

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
COUNT(DISTINCT customer_id) AS nr_customers,
LAG(COUNT(DISTINCT customer_id)) OVER (ORDER BY DATE_PART('year', order_date)) AS same_period_prev_year_nr_customers
FROM orders
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY DATE_PART('year', order_date)
ORDER BY DATE_PART('year', order_date)
)

SELECT
year,
nr_customers,
same_period_prev_year_nr_customers,
nr_customers - same_period_prev_year_nr_customers AS abs_change,
ROUND(100.0 * (nr_customers - same_period_prev_year_nr_customers)/ same_period_prev_year_nr_customers, 2) AS pct_change
FROM customers_count_cte

-- 2.2 January-May 2015 vs January-May 2014

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
COUNT(DISTINCT customer_id) AS nr_customers,
LAG(COUNT(DISTINCT customer_id)) OVER (ORDER BY DATE_PART('year', order_date)) AS same_period_prev_year_nr_customers
FROM orders
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY DATE_PART('year', order_date)
ORDER BY DATE_PART('year', order_date)
)

SELECT
year,
nr_customers,
same_period_prev_year_nr_customers,
nr_customers - same_period_prev_year_nr_customers AS abs_change,
ROUND(100.0 * (nr_customers - same_period_prev_year_nr_customers)/ same_period_prev_year_nr_customers, 2) AS pct_change
FROM customers_count_cte

-- 3. Number of customers by month + change

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
COUNT(DISTINCT customer_id) AS nr_customers,
LAG(COUNT(DISTINCT customer_id)) OVER (ORDER BY DATE_PART('year', order_date), DATE_PART('month', order_date)) AS prev_month_nr_customers
FROM orders
GROUP BY DATE_PART('year', order_date), DATE_PART('month', order_date)
ORDER BY DATE_PART('year', order_date), DATE_PART('month', order_date)
)

SELECT
year,
month,
nr_customers,
prev_month_nr_customers,
nr_customers - prev_month_nr_customers AS abs_change,
ROUND(100.0 * (nr_customers - prev_month_nr_customers)/ prev_month_nr_customers, 2) AS pct_change
FROM customers_count_cte
LIMIT 10

-- 4. Number of customers by month vs same month of previous year

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
COUNT(DISTINCT customer_id) AS nr_customers,
LAG(COUNT(DISTINCT customer_id)) OVER (PARTITION BY DATE_PART('month', order_date) ORDER BY DATE_PART('year', order_date)) AS same_month_prev_year_nr_customers
FROM orders
GROUP BY DATE_PART('year', order_date), DATE_PART('month', order_date)
ORDER BY DATE_PART('year', order_date), DATE_PART('month', order_date)
)

SELECT
year,
month,
nr_customers,
same_month_prev_year_nr_customers,
nr_customers - same_month_prev_year_nr_customers AS abs_change,
ROUND(100.0 * (nr_customers - same_month_prev_year_nr_customers)/ same_month_prev_year_nr_customers, 2) AS pct_change
FROM customers_count_cte

-- 5. Number of customers by country and year + year-over-year change
-- Note: simiarly as with question 1, it is not relevant as we are not comparing the same periods (a full year vs a few months)

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
country,
COUNT(DISTINCT orders.customer_id) AS nr_customers,
LAG(COUNT(DISTINCT orders.customer_id)) OVER (PARTITION BY country ORDER BY DATE_PART('year', order_date)) AS prev_year_nr_customers
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), country
ORDER BY DATE_PART('year', order_date), country
)

SELECT
year,
country,
nr_customers,
prev_year_nr_customers,
nr_customers - prev_year_nr_customers AS abs_change,
ROUND(100.0 * (nr_customers - prev_year_nr_customers)/ prev_year_nr_customers, 2) AS pct_change
FROM customers_count_cte
ORDER BY year, country
LIMIT 10

-- 6. Number of customers by country and period + period-over-period change (soluton to previous question's issue)

-- 6.1 July-December 2014 vs July-December 2013

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
country,
COUNT(DISTINCT orders.customer_id) AS nr_customers,
LAG(COUNT(DISTINCT orders.customer_id)) OVER (PARTITION BY country ORDER BY DATE_PART('year', order_date)) AS same_period_prev_year_nr_customers
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY DATE_PART('year', order_date), country
ORDER BY DATE_PART('year', order_date), country
)

SELECT
year,
country,
nr_customers,
same_period_prev_year_nr_customers,
nr_customers - same_period_prev_year_nr_customers AS abs_change,
ROUND(100.0 * (nr_customers - same_period_prev_year_nr_customers)/ same_period_prev_year_nr_customers, 2) AS pct_change
FROM customers_count_cte
ORDER BY year, country
LIMIT 10

-- 6.2 January-May 2015 vs January-May 2014

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
country,
COUNT(DISTINCT orders.customer_id) AS nr_customers,
LAG(COUNT(DISTINCT orders.customer_id)) OVER (PARTITION BY country ORDER BY DATE_PART('year', order_date)) AS same_period_prev_year_nr_customers
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY DATE_PART('year', order_date), country
ORDER BY DATE_PART('year', order_date), country
)

SELECT
year,
country,
nr_customers,
same_period_prev_year_nr_customers,
nr_customers - same_period_prev_year_nr_customers AS abs_change,
ROUND(100.0 * (nr_customers - same_period_prev_year_nr_customers)/ same_period_prev_year_nr_customers, 2) AS pct_change
FROM customers_count_cte
ORDER BY year, country
LIMIT 10

-- 7. Number of customers by country and month + month_over_month change

-- Version 1:
-- The problem with this first version is that, because of the way window functions work, we end up skipping the months that had O sales, 
-- and thus come to conclusions that do not truly reflect reality. For example, for Brazil, we compare the months for which we have actual sales - months 9 and 11, 
-- skipping month 10 when the fact that there were 0 sales in that particular month would tell us a completeley different story than previously.

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
country,
COUNT(DISTINCT orders.customer_id) AS nr_customers,
LAG(COUNT(DISTINCT orders.customer_id)) OVER (PARTITION BY country ORDER BY DATE_PART('year', order_date), DATE_PART('month', order_date)) AS prev_month_nr_customers
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), DATE_PART('month', order_date), country
ORDER BY DATE_PART('year', order_date), DATE_PART('month', order_date), country
)

SELECT
year,
month,
country,
nr_customers,
prev_month_nr_customers,
nr_customers - prev_month_nr_customers AS abs_change,
ROUND(100.0 * (nr_customers - prev_month_nr_customers)/ prev_month_nr_customers, 2) AS pct_change
FROM customers_count_cte
ORDER BY year, month, country
LIMIT 10

-- Version 2:
-- In which we find a workaround for the issues we have with Version 1, by using a data dimension table

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
country,
COUNT(DISTINCT orders.customer_id) AS nr_customers
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), DATE_PART('month', order_date), country
ORDER BY DATE_PART('year', order_date), DATE_PART('month', order_date), country
)

, missing_months_added_cte AS (
SELECT DISTINCT
t1.year,
t1.month,
t1.country,
COALESCE(nr_customers, 0) AS nr_customers
FROM date_and_country t1
LEFT JOIN customers_count_cte t2 ON t1.year=t2.year AND t1.month=t2.month AND t1.country=t2.country
ORDER BY 1,2,3
)

SELECT
year,
month,
country,
nr_customers,
LAG(nr_customers) OVER (PARTITION BY country ORDER BY year, month) AS prev_month_nr_customers,
nr_customers - LAG(nr_customers) OVER (PARTITION BY country ORDER BY year, month) AS abs_change,
ROUND(100.0 * (nr_customers - LAG(nr_customers) OVER (PARTITION BY country ORDER BY year, month))/ NULLIF(LAG(nr_customers) OVER (PARTITION BY country ORDER BY year, month), 0), 2) AS pct_change
FROM missing_months_added_cte
ORDER BY year, month, country
LIMIT 10

-- 8. Number of customers by country and month vs same month of previous year

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
country,
COUNT(DISTINCT orders.customer_id) AS nr_customers,
LAG(COUNT(DISTINCT orders.customer_id)) OVER (PARTITION BY country, DATE_PART('month', order_date) ORDER BY DATE_PART('year', order_date)) AS same_month_prev_year_nr_customers
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), DATE_PART('month', order_date), country
ORDER BY DATE_PART('year', order_date), DATE_PART('month', order_date), country
)

SELECT
year,
month,
country,
nr_customers,
same_month_prev_year_nr_customers,
nr_customers - same_month_prev_year_nr_customers AS abs_change,
ROUND(100.0 * (nr_customers - same_month_prev_year_nr_customers)/ same_month_prev_year_nr_customers, 2) AS pct_change
FROM customers_count_cte
LIMIT 10

-- 9. Top 5 countries by net sales, overall

WITH yearly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
country,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), country
ORDER BY DATE_PART('year', order_date), country
)

SELECT
country,
SUM(net_sales) AS total_sales
FROM yearly_sales_cte
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5

-- 10. Top 5 countries by net sales, by year

WITH yearly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
country,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), country
ORDER BY DATE_PART('year', order_date), country
)

, yearly_sales_ranked_cte AS (
SELECT
year,
country,
net_sales,
DENSE_RANK() OVER (PARTITION BY year ORDER BY net_sales DESC) AS sales_rank
FROM yearly_sales_cte
)

SELECT
year,
country,
net_sales,
sales_rank
FROM yearly_sales_ranked_cte
WHERE sales_rank <=5

-- 11. Top 5 cities by net sales, overall

WITH yearly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
city,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), city
ORDER BY DATE_PART('year', order_date), city
)

SELECT
city,
SUM(net_sales) AS total_sales
FROM yearly_sales_cte
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5

-- 12. Top 5 cities by net sales, by year

WITH yearly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
city,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), city
ORDER BY DATE_PART('year', order_date), city
)

, yearly_sales_ranked_cte AS (
SELECT
year,
city,
net_sales,
DENSE_RANK() OVER (PARTITION BY year ORDER BY net_sales DESC) AS sales_rank
FROM yearly_sales_cte
)

SELECT
year,
city,
net_sales,
sales_rank
FROM yearly_sales_ranked_cte
WHERE sales_rank <=5

-- 13. Top 5 customers by net sales, overall

WITH yearly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
customers.customer_id,
company_name,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), customers.customer_id, company_name
ORDER BY DATE_PART('year', order_date), customers.customer_id, company_name
)

SELECT
customer_id,
company_name,
SUM(net_sales) AS total_sales
FROM yearly_sales_cte
GROUP BY 1,2
ORDER BY 3 DESC
LIMIT 5

-- 14. Top 5 customers by net sales, by year

WITH yearly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
customers.customer_id,
company_name,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), customers.customer_id, company_name
ORDER BY DATE_PART('year', order_date), customers.customer_id, company_name
)

, yearly_sales_ranked_cte AS (
SELECT
year,
customer_id,
company_name,
net_sales,
DENSE_RANK() OVER (PARTITION BY year ORDER BY net_sales DESC) AS sales_rank
FROM yearly_sales_cte
)

SELECT
year,
customer_id,
company_name,
net_sales,
sales_rank
FROM yearly_sales_ranked_cte
WHERE sales_rank <=5
LIMIT 5

-- 15. Top 5 countries by number of customers, overall

SELECT 
country,
COUNT(DISTINCT customer_id) 
FROM customers 
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5

-- 16. Top 5 countries by number of customers, by year

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
country,
COUNT(DISTINCT orders.customer_id) AS nr_customers
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), country
ORDER BY DATE_PART('year', order_date), country
)

, yearly_customers_ranked_cte AS (
SELECT
year,
country,
nr_customers,
DENSE_RANK() OVER (PARTITION BY year ORDER BY nr_customers DESC) AS rank
FROM customers_count_cte
)

SELECT
year,
country,
nr_customers,
rank
FROM yearly_customers_ranked_cte
WHERE rank <= 5
ORDER BY year
LIMIT 10

-- 17. Top 5 cities by number of customers, overall

SELECT 
city,
COUNT(DISTINCT customer_id) 
FROM customers 
GROUP BY 1
ORDER BY 2 DESC
LIMIT 6

-- 18. Top 5 cities by number of customers, by year

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
country,
city,
COUNT(DISTINCT orders.customer_id) AS nr_customers
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), country, city
ORDER BY DATE_PART('year', order_date), country, city
)

, yearly_customers_ranked_cte AS (
SELECT
year,
country,
city,
nr_customers,
DENSE_RANK() OVER (PARTITION BY year ORDER BY nr_customers DESC) AS rank
FROM customers_count_cte
)

SELECT
year,
country,
city,
nr_customers,
rank
FROM yearly_customers_ranked_cte
WHERE rank <= 5
ORDER BY year
LIMIT 10

-- 19. Top 5 countries by number of orders, overall

SELECT
country,
COUNT(DISTINCT order_id) AS nr_orders
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5

-- 20. Top 5 countries by number of orders, by year

WITH yearly_orders_cte AS (
SELECT
orders.order_id,
order_date,
country
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
INNER JOIN order_details ON orders.order_id=order_details.order_id
--LIMIT 5
)

, yearly_orders_ranked_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
country,
COUNT(DISTINCT order_id) AS nr_orders,
DENSE_RANK() OVER (PARTITION BY DATE_PART('year', order_date) ORDER BY COUNT(DISTINCT order_id) DESC) AS rank
FROM yearly_orders_cte
GROUP BY 1,2
ORDER BY 1, 3 DESC
)

SELECT
*
FROM yearly_orders_ranked_cte
WHERE rank<=5
LIMIT 5

-- 21. Top 5 cities by number of orders, overall

SELECT
city,
COUNT(DISTINCT order_id) AS nr_orders
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5

-- 22. Top 5 cities by number of orders, by year

WITH yearly_orders_cte AS (
SELECT
orders.order_id,
order_date,
city,
country
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
INNER JOIN order_details ON orders.order_id=order_details.order_id
--LIMIT 5
)

, yearly_orders_ranked_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
city,
country,
COUNT(DISTINCT order_id) AS nr_orders,
DENSE_RANK() OVER (PARTITION BY DATE_PART('year', order_date) ORDER BY COUNT(DISTINCT order_id) DESC) AS rank
FROM yearly_orders_cte
GROUP BY 1,2,3
ORDER BY 1, 4 DESC
)

SELECT
*
FROM yearly_orders_ranked_cte
WHERE rank<=5
LIMIT 10

-- 23. Top 5 customers by number of orders, overall

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
orders.customer_id,
company_name,
COUNT(DISTINCT orders.order_id) AS nr_orders
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), orders.customer_id, company_name
ORDER BY DATE_PART('year', order_date), orders.customer_id, company_name
)

SELECT
customer_id,
company_name,
SUM(nr_orders) AS total_orders
FROM customers_count_cte
GROUP BY customer_id, company_name
ORDER BY total_orders DESC
LIMIT 5

-- 24. Top 5 customers by number of orders, by year

WITH customers_count_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
orders.customer_id,
company_name,
COUNT(DISTINCT orders.order_id) AS nr_orders
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY DATE_PART('year', order_date), orders.customer_id, company_name
ORDER BY DATE_PART('year', order_date), orders.customer_id, company_name
)

, yearly_customers_ranked_cte AS (
SELECT
year,
customer_id,
company_name,
nr_orders,
DENSE_RANK() OVER (PARTITION BY year ORDER BY nr_orders DESC) AS rank
FROM customers_count_cte
)

SELECT
year,
customer_id,
company_name,
nr_orders,
rank
FROM yearly_customers_ranked_cte
WHERE rank <= 5
ORDER BY year
LIMIT 10

-- 25. Average net sales per customer by year + year-over-year change

WITH sales_by_order_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
employee_id,
customer_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales
FROM orders
INNER JOIN order_details ON orders.order_id=order_details.order_id
GROUP BY 1,2,3,4,5
--ORDER BY 1
)

, sales_by_customer_cte AS (
SELECT
customers.customer_id,
company_name,
year,
SUM(net_sales) AS net_sales_by_customer
FROM sales_by_order_cte
INNER JOIN customers ON sales_by_order_cte.customer_id=customers.customer_id
GROUP BY 1,2,3
ORDER BY 3,4 DESC
)

, avg_sales_by_year_cte AS (
SELECT
year, 
ROUND(AVG(net_sales_by_customer), 2) AS avg_net_sales_by_customer
FROM sales_by_customer_cte
GROUP BY 1
)

SELECT
year,
avg_net_sales_by_customer,
ROUND(LAG(avg_net_sales_by_customer) OVER (ORDER BY year),2) AS prev_avg_sales_by_customer,
avg_net_sales_by_customer - LAG(avg_net_sales_by_customer) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_net_sales_by_customer- LAG(avg_net_sales_by_customer) OVER (ORDER BY year))/LAG(avg_net_sales_by_customer) OVER (ORDER BY year),2) AS pct_change
FROM avg_sales_by_year_cte

-- 26. Average net sales per customer by period + period-over-period change

-- 26.1 July-December 2014 vs July-December 2013

WITH sales_by_order_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
employee_id,
customer_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales
FROM orders
INNER JOIN order_details ON orders.order_id=order_details.order_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY 1,2,3,4,5
--ORDER BY 1
)

, sales_by_customer_cte AS (
SELECT
customers.customer_id,
company_name,
year,
SUM(net_sales) AS net_sales_by_customer
FROM sales_by_order_cte
INNER JOIN customers ON sales_by_order_cte.customer_id=customers.customer_id
GROUP BY 1,2,3
ORDER BY 3,4 DESC
)

, avg_sales_by_year_cte AS (
SELECT
year, 
ROUND(AVG(net_sales_by_customer), 2) AS avg_net_sales_by_customer
FROM sales_by_customer_cte
GROUP BY 1
)

SELECT
year,
avg_net_sales_by_customer,
ROUND(LAG(avg_net_sales_by_customer) OVER (ORDER BY year),2) AS prev_avg_sales_by_customer,
avg_net_sales_by_customer - LAG(avg_net_sales_by_customer) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_net_sales_by_customer- LAG(avg_net_sales_by_customer) OVER (ORDER BY year))/LAG(avg_net_sales_by_customer) OVER (ORDER BY year),2) AS pct_change
FROM avg_sales_by_year_cte

-- 26.2 January-May 2015 vs January-May 2014

WITH sales_by_order_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
employee_id,
customer_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales
FROM orders
INNER JOIN order_details ON orders.order_id=order_details.order_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY 1,2,3,4,5
--ORDER BY 1
)

, sales_by_customer_cte AS (
SELECT
customers.customer_id,
company_name,
year,
SUM(net_sales) AS net_sales_by_customer
FROM sales_by_order_cte
INNER JOIN customers ON sales_by_order_cte.customer_id=customers.customer_id
GROUP BY 1,2,3
ORDER BY 3,4 DESC
)

, avg_sales_by_year_cte AS (
SELECT
year, 
ROUND(AVG(net_sales_by_customer), 2) AS avg_net_sales_by_customer
FROM sales_by_customer_cte
GROUP BY 1
)

SELECT
year,
avg_net_sales_by_customer,
ROUND(LAG(avg_net_sales_by_customer) OVER (ORDER BY year),2) AS prev_avg_sales_by_customer,
avg_net_sales_by_customer - LAG(avg_net_sales_by_customer) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_net_sales_by_customer- LAG(avg_net_sales_by_customer) OVER (ORDER BY year))/LAG(avg_net_sales_by_customer) OVER (ORDER BY year),2) AS pct_change
FROM avg_sales_by_year_cte

-- 27. Average number of orders per customer by year + year-over-year change

WITH nr_orders_by_customer_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
customers.customer_id,
company_name,
COUNT(DISTINCT order_id) AS nr_orders
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
GROUP BY 1,2,3
)

, avg_nr_orders_by_customer_cte AS (
SELECT
year, 
ROUND(AVG(nr_orders), 2) AS avg_nr_orders_by_customer
FROM nr_orders_by_customer_cte
GROUP BY 1
)

SELECT
year,
avg_nr_orders_by_customer,
ROUND(LAG(avg_nr_orders_by_customer) OVER (ORDER BY year),2) AS prev_avg_nr_orders_by_customer,
avg_nr_orders_by_customer - LAG(avg_nr_orders_by_customer) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_nr_orders_by_customer - LAG(avg_nr_orders_by_customer) OVER (ORDER BY year))/LAG(avg_nr_orders_by_customer) OVER (ORDER BY year),2) AS pct_change
FROM avg_nr_orders_by_customer_cte

-- 28. Average number of orders per customer by period + period-over-period change

-- 28.1 July-December 2014 vs July-December 2013

WITH nr_orders_by_customer_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
customers.customer_id,
company_name,
COUNT(DISTINCT order_id) AS nr_orders
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY 1,2,3
)

, avg_nr_orders_by_customer_cte AS (
SELECT
year, 
ROUND(AVG(nr_orders), 2) AS avg_nr_orders_by_customer
FROM nr_orders_by_customer_cte
GROUP BY 1
)

SELECT
year,
avg_nr_orders_by_customer,
ROUND(LAG(avg_nr_orders_by_customer) OVER (ORDER BY year),2) AS prev_avg_nr_orders_by_customer,
avg_nr_orders_by_customer - LAG(avg_nr_orders_by_customer) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_nr_orders_by_customer - LAG(avg_nr_orders_by_customer) OVER (ORDER BY year))/LAG(avg_nr_orders_by_customer) OVER (ORDER BY year),2) AS pct_change
FROM avg_nr_orders_by_customer_cte

-- 28.2 January-May 2015 vs January-May 2014

WITH nr_orders_by_customer_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
customers.customer_id,
company_name,
COUNT(DISTINCT order_id) AS nr_orders
FROM orders
INNER JOIN customers ON orders.customer_id=customers.customer_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY 1,2,3
)

, avg_nr_orders_by_customer_cte AS (
SELECT
year, 
ROUND(AVG(nr_orders), 2) AS avg_nr_orders_by_customer
FROM nr_orders_by_customer_cte
GROUP BY 1
)

SELECT
year,
avg_nr_orders_by_customer,
ROUND(LAG(avg_nr_orders_by_customer) OVER (ORDER BY year),2) AS prev_avg_nr_orders_by_customer,
avg_nr_orders_by_customer - LAG(avg_nr_orders_by_customer) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_nr_orders_by_customer - LAG(avg_nr_orders_by_customer) OVER (ORDER BY year))/LAG(avg_nr_orders_by_customer) OVER (ORDER BY year),2) AS pct_change
FROM avg_nr_orders_by_customer_cte

-- 29. Repeat purchase rate by year

WITH order_counts_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
customer_id,
COUNT(order_id) AS nr_of_orders
FROM orders
GROUP BY 1,2
)

, return_customers_cte AS (
SELECT
year,
COUNT(DISTINCT customer_id) AS return_customers
FROM order_counts_cte
WHERE nr_of_orders > 1
GROUP BY 1
)

, customer_counts_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
COUNT(DISTINCT customer_id) AS total_customers
FROM orders
GROUP BY 1	
)

SELECT
t1.year,
total_customers,
return_customers,
ROUND(100.0 * return_customers / total_customers, 2) AS repeat_purchase_rate
FROM customer_counts_cte t1
INNER JOIN return_customers_cte t2 ON t1.year=t2.year

-- 30. Repeat purchase rate by corresponding period

-- 30.1 July-December 2014 vs July-December 2013

WITH order_counts_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
customer_id,
COUNT(order_id) AS nr_of_orders
FROM orders
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY 1,2
)

, return_customers_cte AS (
SELECT
year,
COUNT(DISTINCT customer_id) AS return_customers
FROM order_counts_cte
WHERE nr_of_orders > 1
GROUP BY 1
)

, customer_counts_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
COUNT(DISTINCT customer_id) AS total_customers
FROM orders
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY 1	
)

SELECT
t1.year,
total_customers,
return_customers,
ROUND(100.0 * return_customers / total_customers, 2) AS repeat_purchase_rate
FROM customer_counts_cte t1
INNER JOIN return_customers_cte t2 ON t1.year=t2.year

-- 30.2 January-May 2015 vs January-May 2014

WITH order_counts_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
customer_id,
COUNT(order_id) AS nr_of_orders
FROM orders
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY 1,2
)

, return_customers_cte AS (
SELECT
year,
COUNT(DISTINCT customer_id) AS return_customers
FROM order_counts_cte
WHERE nr_of_orders > 1
GROUP BY 1
)

, customer_counts_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
COUNT(DISTINCT customer_id) AS total_customers
FROM orders
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY 1	
)

SELECT
t1.year,
total_customers,
return_customers,
ROUND(100.0 * return_customers / total_customers, 2) AS repeat_purchase_rate
FROM customer_counts_cte t1
INNER JOIN return_customers_cte t2 ON t1.year=t2.year

-- 31. Time between purchases (days)

WITH order_counts_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
customer_id,
COUNT(order_id) AS nr_orders
FROM orders
GROUP BY 1,2
)

, avg_order_counts_cte AS (
SELECT
year,
ROUND(AVG(nr_orders), 2) AS avg_nr_orders
FROM order_counts_cte
GROUP BY 1
)

, days_per_year_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
MAX(order_date) - MIN(order_date) AS duration
FROM orders
GROUP BY 1
)

SELECT
t1.year,
duration,
avg_nr_orders,
ROUND(duration / avg_nr_orders, 2) AS time_between_purchases
FROM avg_order_counts_cte t1
INNER JOIN days_per_year_cte t2 ON t1.year = t2.year


/*=========================
 PRODUCT ANALYSIS
=========================*/

-- 1. Top 5 products by net sales, overall

WITH yearly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
products.product_id,
product_name,
ROUND(SUM(quantity*order_details.unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN products ON order_details.product_id=products.product_id
GROUP BY DATE_PART('year', order_date), products.product_id, product_name
ORDER BY DATE_PART('year', order_date), products.product_id, product_name
)

SELECT
product_id,
product_name,
SUM(net_sales) AS total_sales
FROM yearly_sales_cte
GROUP BY 1,2
ORDER BY 3 DESC
LIMIT 5

-- 2. Top 5 products by net sales, by year

WITH yearly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
products.product_id,
product_name,
ROUND(SUM(quantity*order_details.unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN products ON order_details.product_id=products.product_id
GROUP BY DATE_PART('year', order_date), products.product_id, product_name
ORDER BY DATE_PART('year', order_date), products.product_id, product_name
)

, yearly_sales_ranked_cte AS (
SELECT
year,
product_id,
product_name,
net_sales,
DENSE_RANK() OVER (PARTITION BY year ORDER BY net_sales DESC) AS sales_rank
FROM yearly_sales_cte
)

SELECT
year,
product_id,
product_name,
net_sales,
sales_rank
FROM yearly_sales_ranked_cte
WHERE sales_rank <=5

-- 3. Top 5 products by number of orders, overall

WITH yearly_orders_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
products.product_id,
product_name,
COUNT(DISTINCT orders.order_id) AS nr_orders
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN products ON order_details.product_id=products.product_id
GROUP BY DATE_PART('year', order_date), products.product_id, product_name
ORDER BY DATE_PART('year', order_date), products.product_id, product_name
)

SELECT
product_id,
product_name,
SUM(nr_orders) AS total_orders
FROM yearly_orders_cte
GROUP BY 1,2
ORDER BY 3 DESC
LIMIT 5

-- 4. Top 5 products by number of orders, by year

WITH yearly_orders_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
products.product_id,
product_name,
COUNT(DISTINCT orders.order_id) AS nr_orders
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN products ON order_details.product_id=products.product_id
GROUP BY DATE_PART('year', order_date), products.product_id, product_name
ORDER BY DATE_PART('year', order_date), products.product_id, product_name
)

, yearly_orders_ranked_cte AS (
SELECT
year,
product_id,
product_name,
nr_orders,
DENSE_RANK() OVER (PARTITION BY year ORDER BY nr_orders DESC) AS rank
FROM yearly_orders_cte
)

SELECT
year,
product_id,
product_name,
nr_orders,
rank
FROM yearly_orders_ranked_cte
WHERE rank <=5

-- 5. Top 5 products by number of customers, overall

SELECT 
product_name,
COUNT(DISTINCT orders.customer_id) AS nr_customers
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN products ON order_details.product_id=products.product_id
GROUP BY 1
ORDER BY 2 DESC 
LIMIT 5

-- 6. Top 5 products by number of customers, by year

WITH yearly_customers_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
products.product_id,
product_name,
COUNT(DISTINCT orders.order_id) AS nr_customers
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN products ON order_details.product_id=products.product_id
GROUP BY DATE_PART('year', order_date), products.product_id, product_name
ORDER BY DATE_PART('year', order_date), products.product_id, product_name
)

, yearly_customers_ranked_cte AS (
SELECT
year,
product_id,
product_name,
nr_customers,
DENSE_RANK() OVER (PARTITION BY year ORDER BY nr_customers DESC) AS rank
FROM yearly_customers_cte
)

SELECT
year,
product_id,
product_name,
nr_customers,
rank
FROM yearly_customers_ranked_cte
WHERE rank <=5

-- 7. Top 5 categories by net sales, overall

WITH yearly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
products.category_id,
category_name,
ROUND(SUM(quantity*order_details.unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN products ON order_details.product_id=products.product_id
INNER JOIN categories ON products.category_id=categories.category_id
GROUP BY DATE_PART('year', order_date), products.category_id, category_name
ORDER BY DATE_PART('year', order_date), products.category_id, category_name
)

SELECT
category_id,
category_name,
SUM(net_sales) AS total_sales
FROM yearly_sales_cte
GROUP BY 1,2
ORDER BY 3 DESC
LIMIT 5

-- 8. Top 5 categories by net sales, by year

WITH yearly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
products.category_id,
category_name,
ROUND(SUM(quantity*order_details.unit_price*(1-discount)),2) AS net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN products ON order_details.product_id=products.product_id
INNER JOIN categories ON products.category_id=categories.category_id
GROUP BY DATE_PART('year', order_date), products.category_id, category_name
ORDER BY DATE_PART('year', order_date), products.category_id, category_name
)

, yearly_sales_ranked_cte AS (
SELECT
year,
category_id,
category_name,
net_sales,
DENSE_RANK() OVER (PARTITION BY year ORDER BY net_sales DESC) AS sales_rank
FROM yearly_sales_cte
)

SELECT
year,
category_id,
category_name,
net_sales,
sales_rank
FROM yearly_sales_ranked_cte
WHERE sales_rank <=5

-- 9. Top 5 categories by number of orders, overall

WITH yearly_orders_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
products.category_id,
category_name,
COUNT(DISTINCT orders.order_id) AS nr_orders
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN products ON order_details.product_id=products.product_id
INNER JOIN categories ON products.category_id=categories.category_id
GROUP BY DATE_PART('year', order_date), products.category_id, category_name
ORDER BY DATE_PART('year', order_date), products.category_id, category_name
)

SELECT
category_id,
category_name,
SUM(nr_orders) AS total_orders
FROM yearly_orders_cte
GROUP BY 1,2
ORDER BY 3 DESC
LIMIT 5

-- 10. Top 5 categories by number of orders, by year

WITH yearly_orders_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
products.category_id,
category_name,
COUNT(DISTINCT orders.order_id) AS nr_orders
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN products ON order_details.product_id=products.product_id
INNER JOIN categories ON products.category_id=categories.category_id
GROUP BY DATE_PART('year', order_date), products.category_id, category_name
ORDER BY DATE_PART('year', order_date), products.category_id, category_name
)

, yearly_orders_ranked_cte AS (
SELECT
year,
category_id,
category_name,
nr_orders,
DENSE_RANK() OVER (PARTITION BY year ORDER BY nr_orders DESC) AS rank
FROM yearly_orders_cte
)

SELECT
year,
category_id,
category_name,
nr_orders,
rank
FROM yearly_orders_ranked_cte
WHERE rank <=5

-- 11. Top 5 categories by number of customers, overall

SELECT
category_name,
COUNT(DISTINCT customer_id)
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN products ON order_details.product_id=products.product_id
INNER JOIN categories ON products.category_id=categories.category_id
GROUP BY 1
ORDER BY 2 DESC

-- 12. Top 5 categories by number of customers, by year

WITH yearly_customers_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
products.category_id,
category_name,
COUNT(DISTINCT orders.customer_id) AS nr_customers
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN products ON order_details.product_id=products.product_id
INNER JOIN categories ON products.category_id=categories.category_id
GROUP BY DATE_PART('year', order_date), products.category_id, category_name
ORDER BY DATE_PART('year', order_date), products.category_id, category_name
)

, yearly_customers_ranked_cte AS (
SELECT
year,
category_id,
category_name,
nr_customers,
DENSE_RANK() OVER (PARTITION BY year ORDER BY nr_customers DESC) AS rank
FROM yearly_customers_cte
)

SELECT
year,
category_id,
category_name,
nr_customers,
rank
FROM yearly_customers_ranked_cte
WHERE rank <=5

-- 13. Number of discontinued products out of total
 
SELECT
ROUND(100.0 * COUNT(product_id) /(SELECT
					COUNT(product_id)
					FROM products), 2) pct_of_total
FROM products
WHERE discontinued='true'

-- 14. Impact of discontinued products on yearly sales 
-- NOTE: probably not very relevant as we don't know WHEN those products were discontinued

WITH yearly_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
ROUND(SUM(quantity*order_details.unit_price*(1-discount)),2) AS total_net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
GROUP BY DATE_PART('year', order_date)
ORDER BY DATE_PART('year', order_date)
)

, dicontinued_sales_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
ROUND(SUM(quantity*order_details.unit_price*(1-discount)),2) AS discontinued_net_sales
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
INNER JOIN products ON order_details.product_id=products.product_id
WHERE discontinued='true'
GROUP BY DATE_PART('year', order_date)
ORDER BY DATE_PART('year', order_date)
)

SELECT
t1.year,
total_net_sales,
discontinued_net_sales,
ROUND(100.0*discontinued_net_sales/total_net_sales,2) AS pct_discontinued_sales
FROM yearly_sales_cte t1
INNER JOIN dicontinued_sales_cte t2 ON t1.year=t2.year
ORDER BY year

-- 15. Number of discounts offered (and percent of total products sold)

SELECT 
COUNT(product_id) AS products_sold,
COUNT(discount) FILTER (WHERE discount <> 0) AS  discounted_products_sold,
ROUND(100.0* COUNT(discount) FILTER (WHERE discount <> 0) / COUNT(product_id), 2)
FROM order_details

-- 16. Number of discounts offered (and percent of total products sold), by year

WITH products_sold_cte AS (
SELECT 
DATE_PART('year', order_date) AS year,
COUNT(product_id) AS products_sold
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
GROUP BY 1
)

, discounted_products_sold_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
COUNT(discount) AS discounted_products_sold
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
WHERE discount <> 0
GROUP BY 1
)

SELECT
t1.year,
products_sold,
discounted_products_sold,
ROUND(100.0 * discounted_products_sold/products_sold, 2) AS pct_discounted_products_sold
FROM products_sold_cte t1
INNER JOIN discounted_products_sold_cte t2 ON t1.year=t2.year
ORDER BY 1

-- 17. Number of discounts offered (and percent of total products sold), by corresponding period

-- 17.1 July-December 2014 vs July-December 2013

WITH products_sold_cte AS (
SELECT 
DATE_PART('year', order_date) AS year,
COUNT(product_id) AS products_sold
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY 1
)

, discounted_products_sold_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
COUNT(discount) AS discounted_products_sold
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
WHERE discount <> 0 AND DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY 1
)

SELECT
t1.year,
products_sold,
discounted_products_sold,
ROUND(100.0 * discounted_products_sold/products_sold, 2) AS pct_discounted_products_sold
FROM products_sold_cte t1
INNER JOIN discounted_products_sold_cte t2 ON t1.year=t2.year
ORDER BY 1

-- 17.2 January-May 2015 vs January-May 2014

WITH products_sold_cte AS (
SELECT 
DATE_PART('year', order_date) AS year,
COUNT(product_id) AS products_sold
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY 1
)

, discounted_products_sold_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
COUNT(discount) AS discounted_products_sold
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
WHERE discount <> 0 AND DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY 1
)

SELECT
t1.year,
products_sold,
discounted_products_sold,
ROUND(100.0 * discounted_products_sold/products_sold, 2) AS pct_discounted_products_sold
FROM products_sold_cte t1
INNER JOIN discounted_products_sold_cte t2 ON t1.year=t2.year
ORDER BY 1

-- 18. Most discounted products and average discount offered per product
-- NOTE 1: discounted, NOT discontinued
-- NOTE 2: products are sometimes not discounted, hence the rationale behind this metric

SELECT
DISTINCT order_details.product_id,
product_name,
COUNT(discount) AS times_discounted,
ROUND(AVG(discount), 2) AS avg_discount
FROM order_details
INNER JOIN products ON order_details.product_id=products.product_id
WHERE discount <> 0
GROUP BY order_details.product_id, product_name
ORDER BY COUNT(discount) DESC
LIMIT 10

-- 19. Most discounted categories and average discount offered per category

SELECT
DISTINCT products.category_id,
category_name,
COUNT(discount) AS times_discounted,
ROUND(AVG(discount), 2) AS avg_discount
FROM order_details
INNER JOIN products ON order_details.product_id=products.product_id
INNER JOIN categories ON products.category_id=categories.category_id
WHERE discount <> 0
GROUP BY products.category_id, category_name
ORDER BY COUNT(discount) DESC

-- 20. Average net sales per order, overall

WITH sales_per_order_cte AS (
SELECT
order_id,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales_per_order
FROM order_details
GROUP BY order_id
--ORDER BY 1
)

SELECT
ROUND(AVG(net_sales_per_order), 2) AS avg_sales_per_order
FROm sales_per_order_cte

-- 21. Average net sales per order, by year + year-over-year change

WITH sales_per_order_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales_per_order
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
GROUP BY orders.order_id, DATE_PART('year', order_date)
--ORDER BY 1
)

, avg_sales_per_order_cte AS (
SELECT
year,
ROUND(AVG(net_sales_per_order), 2) AS avg_sales_per_order
FROM sales_per_order_cte
GROUP BY year
ORDER BY year
)

SELECT
year,
avg_sales_per_order,
LAG(avg_sales_per_order) OVER (ORDER BY year) AS prev_year_avg_sales_per_order,
avg_sales_per_order - LAG(avg_sales_per_order) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_sales_per_order - LAG(avg_sales_per_order) OVER (ORDER BY year)) / LAG(avg_sales_per_order) OVER (ORDER BY year), 2) AS pct_change
FROM avg_sales_per_order_cte

-- 22. Average net sales per order, by period + period-over-period change

-- 22.1 July-December 2014 vs July-December 2013

WITH sales_per_order_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales_per_order
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY orders.order_id, DATE_PART('year', order_date)
--ORDER BY 1
)

, avg_sales_per_order_cte AS (
SELECT
year,
ROUND(AVG(net_sales_per_order), 2) AS avg_sales_per_order
FROM sales_per_order_cte
GROUP BY year
ORDER BY year
)

SELECT
year,
avg_sales_per_order,
LAG(avg_sales_per_order) OVER (ORDER BY year) AS prev_year_avg_sales_per_order,
avg_sales_per_order - LAG(avg_sales_per_order) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_sales_per_order - LAG(avg_sales_per_order) OVER (ORDER BY year)) / LAG(avg_sales_per_order) OVER (ORDER BY year), 2) AS pct_change
FROM avg_sales_per_order_cte

-- 22.2 January-May 2015 vs January-May 2014

WITH sales_per_order_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
ROUND(SUM(quantity*unit_price*(1-discount)),2) AS net_sales_per_order
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY orders.order_id, DATE_PART('year', order_date)
--ORDER BY 1
)

, avg_sales_per_order_cte AS (
SELECT
year,
ROUND(AVG(net_sales_per_order), 2) AS avg_sales_per_order
FROM sales_per_order_cte
GROUP BY year
ORDER BY year
)

SELECT
year,
avg_sales_per_order,
LAG(avg_sales_per_order) OVER (ORDER BY year) AS prev_year_avg_sales_per_order,
avg_sales_per_order - LAG(avg_sales_per_order) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_sales_per_order - LAG(avg_sales_per_order) OVER (ORDER BY year)) / LAG(avg_sales_per_order) OVER (ORDER BY year), 2) AS pct_change
FROM avg_sales_per_order_cte

-- 23. Average number of products bought per order, overall

WITH nr_products_per_order_cte AS (
SELECT
order_id,
COUNT(product_id) AS nr_products_per_order
FROM order_details
GROUP BY 1
--ORDER BY 1
)

SELECT
ROUND(AVG(nr_products_per_order), 2) AS avg_nr_products_per_order
FROM nr_products_per_order_cte

-- 24. Average number of products bought per order, by year + year-over-year change

WITH nr_products_per_order_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
COUNT(product_id) AS nr_products_per_order
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
GROUP BY orders.order_id, DATE_PART('year', order_date)
--ORDER BY 1
)

, avg_nr_products_per_order_cte AS (
SELECT
year,
ROUND(AVG(nr_products_per_order), 2) AS avg_nr_products_per_order
FROM nr_products_per_order_cte
GROUP BY 1
ORDER BY 1
)

SELECT
year,
avg_nr_products_per_order,
LAG(avg_nr_products_per_order) OVER (ORDER BY year) AS prev_year_avg_nr_products_per_order,
avg_nr_products_per_order - LAG(avg_nr_products_per_order) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_nr_products_per_order - LAG(avg_nr_products_per_order) OVER (ORDER BY year)) / LAG(avg_nr_products_per_order) OVER (ORDER BY year), 2) AS pct_change
FROM avg_nr_products_per_order_cte
ORDER BY year

-- 25. Average number of products bought per order, by period + period-over-period change

-- 25.1 July-December 2014 vs July-December 2013

WITH nr_products_per_order_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
COUNT(product_id) AS nr_products_per_order
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY orders.order_id, DATE_PART('year', order_date)
--ORDER BY 1
)

, avg_nr_products_per_order_cte AS (
SELECT
year,
ROUND(AVG(nr_products_per_order), 2) AS avg_nr_products_per_order
FROM nr_products_per_order_cte
GROUP BY 1
ORDER BY 1
)

SELECT
year,
avg_nr_products_per_order,
LAG(avg_nr_products_per_order) OVER (ORDER BY year) AS prev_year_avg_nr_products_per_order,
avg_nr_products_per_order - LAG(avg_nr_products_per_order) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_nr_products_per_order - LAG(avg_nr_products_per_order) OVER (ORDER BY year)) / LAG(avg_nr_products_per_order) OVER (ORDER BY year), 2) AS pct_change
FROM avg_nr_products_per_order_cte
ORDER BY year

-- 25.2 January-May 2015 vs January-May 2014

WITH nr_products_per_order_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
COUNT(product_id) AS nr_products_per_order
FROM order_details
INNER JOIN orders ON order_details.order_id=orders.order_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY orders.order_id, DATE_PART('year', order_date)
--ORDER BY 1
)

, avg_nr_products_per_order_cte AS (
SELECT
year,
ROUND(AVG(nr_products_per_order), 2) AS avg_nr_products_per_order
FROM nr_products_per_order_cte
GROUP BY 1
ORDER BY 1
)

SELECT
year,
avg_nr_products_per_order,
LAG(avg_nr_products_per_order) OVER (ORDER BY year) AS prev_year_avg_nr_products_per_order,
avg_nr_products_per_order - LAG(avg_nr_products_per_order) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_nr_products_per_order - LAG(avg_nr_products_per_order) OVER (ORDER BY year)) / LAG(avg_nr_products_per_order) OVER (ORDER BY year), 2) AS pct_change
FROM avg_nr_products_per_order_cte
ORDER BY year


/*=========================
 SHIPPING ANALYSIS
=========================*/

-- 1. Freight by year + year-over-year change

WITH yearly_freight_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
ROUND(SUM(freight), 2) AS freight_per_year
FROM orders
GROUP BY DATE_PART('year', order_date)
ORDER BY DATE_PART('year', order_date)
)

SELECT
year,
freight_per_year,
ROUND(LAG(freight_per_year) OVER (ORDER BY year),2) AS prev_year_freight,
freight_per_year - LAG(freight_per_year) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (freight_per_year - LAG(freight_per_year) OVER (ORDER BY year))/LAG(freight_per_year) OVER (ORDER BY year),2) AS pct_change
FROM yearly_freight_cte
ORDER BY 1

-- 2. Freight by period + period-over-period change

-- 2.1 July-December 2014 vs July-December 2013

WITH freight_by_month_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
ROUND(SUM(freight), 2) AS freight_per_month
FROM orders
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY DATE_PART('year', order_date), DATE_PART('month', order_date)
)

SELECT
year,
ROUND(SUM(freight_per_month),2) AS freight_per_period,
ROUND(LAG(SUM(freight_per_month)) OVER (ORDER BY year),2) AS same_period_prev_year_freight,
ROUND(SUM(freight_per_month),2) - ROUND(LAG(SUM(freight_per_month)) OVER (ORDER BY year),2) AS abs_change,
ROUND(100.0 * (ROUND(SUM(freight_per_month),2) - ROUND(LAG(SUM(freight_per_month)) OVER (ORDER BY year),2))/ROUND(LAG(SUM(freight_per_month)) OVER (ORDER BY year),2)) AS pct_change
FROM freight_by_month_cte
GROUP BY year
ORDER BY year

-- 2.2 January-May 2015 vs January-May 2014

WITH freight_by_month_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
ROUND(SUM(freight), 2) AS freight_per_month
FROM orders
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY DATE_PART('year', order_date), DATE_PART('month', order_date)
)

SELECT
year,
ROUND(SUM(freight_per_month),2) AS freight_per_period,
ROUND(LAG(SUM(freight_per_month)) OVER (ORDER BY year),2) AS same_period_prev_year_freight,
ROUND(SUM(freight_per_month),2) - ROUND(LAG(SUM(freight_per_month)) OVER (ORDER BY year),2) AS abs_change,
ROUND(100.0 * (ROUND(SUM(freight_per_month),2) - ROUND(LAG(SUM(freight_per_month)) OVER (ORDER BY year),2))/ROUND(LAG(SUM(freight_per_month)) OVER (ORDER BY year),2)) AS pct_change
FROM freight_by_month_cte
GROUP BY year
ORDER BY year

-- 3. Freight by month + month-over-month change

WITH monthly_freight_cte AS (
SELECT
DATE_TRUNC('month', order_date)::DATE AS month,
ROUND(SUM(freight), 2) AS freight_per_month
FROM orders
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date)
)

SELECT
month,
freight_per_month,
ROUND(LAG(freight_per_month) OVER (ORDER BY month),2) AS prev_month_freight,
freight_per_month - LAG(freight_per_month) OVER (ORDER BY month) AS abs_change,
ROUND(100.0 * (freight_per_month - LAG(freight_per_month) OVER (ORDER BY month))/LAG(freight_per_month) OVER (ORDER BY month),2) AS pct_change
FROM monthly_freight_cte
ORDER BY 1
LIMIT 5

-- 4. Freight by month vs same month of previous year

WITH monthly_freight_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
ROUND(SUM(freight), 2) AS freight_per_month
FROM orders
GROUP BY DATE_PART('year', order_date), DATE_PART('month', order_date)
)

SELECT
year,
month,
freight_per_month,
ROUND(LAG(freight_per_month) OVER (PARTITION BY month ORDER BY year),2) AS same_month_prev_year_freight,
freight_per_month - LAG(freight_per_month) OVER (PARTITION BY month ORDER BY year) AS abs_change,
ROUND(100.0 * (freight_per_month - LAG(freight_per_month) OVER (PARTITION BY month ORDER BY year))/LAG(freight_per_month) OVER (PARTITION BY month ORDER BY year),2) AS pct_change
FROM monthly_freight_cte
ORDER BY year, month
LIMIT 15

-- 5. Average number of days it takes to ship an order + year-over-year change

WITH delivery_times_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
ROUND(AVG(shipped_date - order_date), 1) AS avg_delivery_time,
LAG(ROUND(AVG(shipped_date - order_date), 1)) OVER (ORDER BY DATE_PART('year', order_date)) AS prev_year_avg_delivery_time
FROM orders
GROUP BY DATE_PART('year', order_date) 
ORDER BY DATE_PART('year', order_date) 
)

SELECT
year,
avg_delivery_time,
prev_year_avg_delivery_time,
avg_delivery_time - prev_year_avg_delivery_time AS abs_change,
ROUND(100.0 * (avg_delivery_time - prev_year_avg_delivery_time) / prev_year_avg_delivery_time, 1) AS pct_change
FROM delivery_times_cte

-- 6. Deliveries by shipping company, absolute + percent out of total

SELECT
company_name,
COUNT(DISTINCT order_id) as nr_deliveries,
ROUND(COUNT(DISTINCT order_id) / SUM(COUNT(DISTINCT order_id)) OVER (), 2) AS pct_of_total
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
GROUP BY 1
ORDER BY 2 DESC

-- 7. Deliveries by shipping company, by year, absolute + percent out of total

SELECT
DATE_PART('year', order_date) AS year,
company_name,
COUNT(DISTINCT order_id) AS nr_deliveries,
ROUND(COUNT(DISTINCT order_id) / SUM(COUNT(DISTINCT order_id)) OVER (PARTITION BY DATE_PART('year', order_date) ), 2) AS pct_of_total
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
GROUP BY 1,2
ORDER BY 3 DESC

-- 8. Number of delayed vs on time shipments by shipping company, overall + percent out of total

WITH delays_cte AS (
SELECT
order_id,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date > 0
)

, delay_counts_cte AS (
SELECT
company_name,
COUNT(delay) AS delayed_shipments
FROM delays_cte
GROUP BY 1
)

, on_time_cte AS (
SELECT
order_id,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date <= 0
)

, on_time_counts_cte AS (
SELECT
company_name,
COUNT(delay) AS on_time_shipments
FROM on_time_cte
GROUP BY 1
)

, shipping_stats_cte AS (
SELECT
t1.company_name,
delayed_shipments + on_time_shipments AS total_shipments,
on_time_shipments,
delayed_shipments
FROM delay_counts_cte t1
INNER JOIN on_time_counts_cte t2 ON t1.company_name=t2.company_name
ORDER BY 1
)

SELECT
company_name,
total_shipments,
on_time_shipments,
delayed_shipments,
ROUND(100.0 * delayed_shipments / total_shipments, 2) AS pct_delayed
FROM shipping_stats_cte
ORDER BY 1

-- 9. Number of delayed vs on time shipments by shipping company and year + percent out of total (inconclusive)

WITH delays_cte AS (
SELECT
order_id,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date > 0
)

, delay_counts_cte AS (
SELECT
company_name,
COUNT(delay) AS delayed_shipments
FROM delays_cte
GROUP BY 1
)

, on_time_cte AS (
SELECT
order_id,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date <= 0
)

, on_time_counts_cte AS (
SELECT
company_name,
COUNT(delay) AS on_time_shipments
FROM on_time_cte
GROUP BY 1
)

, shipping_stats_cte AS (
SELECT
t1.company_name,
delayed_shipments + on_time_shipments AS total_shipments,
on_time_shipments,
delayed_shipments
FROM delay_counts_cte t1
INNER JOIN on_time_counts_cte t2 ON t1.company_name=t2.company_name
ORDER BY 1
)

SELECT
company_name,
total_shipments,
on_time_shipments,
delayed_shipments,
ROUND(100.0 * delayed_shipments / total_shipments, 2) AS pct_delayed
FROM shipping_stats_cte
ORDER BY 1

-- 10. Number of delayed vs on time shipments by shipping company and corresponding period + percent out of total

-- 10.1 July-December 2014 vs July-December 2013

WITH delays_cte AS (
SELECT
order_id,
order_date,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date > 0
AND DATE_PART('month', order_date) BETWEEN 7 AND 12
)

, delay_counts_cte AS (
SELECT
company_name,
DATE_PART('year', order_date) AS year,
COUNT(delay) AS delayed_shipments
FROM delays_cte
GROUP BY 1,2
)

, on_time_cte AS (
SELECT
order_id,
order_date,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date <= 0
AND DATE_PART('month', order_date) BETWEEN 7 AND 12
)

, on_time_counts_cte AS (
SELECT
company_name,
DATE_PART('year', order_date) AS year,
COUNT(delay) AS on_time_shipments
FROM on_time_cte
GROUP BY 1,2
)

, shipping_stats_cte AS (
SELECT
t1.year,
t1.company_name,
delayed_shipments + on_time_shipments AS total_shipments,
on_time_shipments,
delayed_shipments
FROM delay_counts_cte t1
INNER JOIN on_time_counts_cte t2 ON t1.company_name=t2.company_name
AND t1.year = t2.year
ORDER BY 1
)

SELECT
year,
company_name,
total_shipments,
on_time_shipments,
delayed_shipments,
ROUND(100.0 * delayed_shipments / total_shipments, 2) AS pct_delayed
FROM shipping_stats_cte
ORDER BY 1, 6 DESC

-- 10.2 January-May 2015 vs January-May 2014

WITH delays_cte AS (
SELECT
order_id,
order_date,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date > 0
AND DATE_PART('month', order_date) BETWEEN 1 AND 5
)

, delay_counts_cte AS (
SELECT
company_name,
DATE_PART('year', order_date) AS year,
COUNT(delay) AS delayed_shipments
FROM delays_cte
GROUP BY 1,2
)

, on_time_cte AS (
SELECT
order_id,
order_date,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date <= 0
AND DATE_PART('month', order_date) BETWEEN 1 AND 5
)

, on_time_counts_cte AS (
SELECT
company_name,
DATE_PART('year', order_date) AS year,
COUNT(delay) AS on_time_shipments
FROM on_time_cte
GROUP BY 1,2
)

, shipping_stats_cte AS (
SELECT
t1.year,
t1.company_name,
delayed_shipments + on_time_shipments AS total_shipments,
on_time_shipments,
delayed_shipments
FROM delay_counts_cte t1
INNER JOIN on_time_counts_cte t2 ON t1.company_name=t2.company_name
AND t1.year = t2.year
ORDER BY 1
)

SELECT
year,
company_name,
total_shipments,
on_time_shipments,
delayed_shipments,
ROUND(100.0 * delayed_shipments / total_shipments, 2) AS pct_delayed
FROM shipping_stats_cte
ORDER BY 1, 6 DESC

-- 11. Average delays by year

WITH delays_cte AS (
SELECT
order_id,
order_date,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date > 0
)

SELECT
DATE_PART('year', order_date) AS year,
ROUND(AVG(delay), 1) AS avg_delay
FROM delays_cte
GROUP BY 1
ORDER BY 1

-- 12. Average delays by corresponding period

-- 12.1 July-December 2014 vs July-December 2013

WITH delays_cte AS (
SELECT
order_id,
order_date,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date > 0
AND DATE_PART('month', order_date) BETWEEN 7 AND 12
)

SELECT
DATE_PART('year', order_date) AS year,
ROUND(AVG(delay), 1) AS avg_delay
FROM delays_cte
GROUP BY 1
ORDER BY 1

-- 12.2 January-May 2015 vs January-May 2014

WITH delays_cte AS (
SELECT
order_id,
order_date,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date > 0
AND DATE_PART('month', order_date) BETWEEN 1 AND 5
)

SELECT
DATE_PART('year', order_date) AS year,
ROUND(AVG(delay), 1) AS avg_delay
FROM delays_cte
GROUP BY 1
ORDER BY 1

-- 13. Average delays by shipping company and year (inconclusive)

WITH delays_cte AS (
SELECT
order_id,
order_date,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date > 0
)

SELECT
DATE_PART('year', order_date) AS year,
company_name,
ROUND(AVG(delay), 1) AS avg_delay
FROM delays_cte
GROUP BY 1,2
ORDER BY 1,3 DESC

-- 14. Average delays by shipping company and corresponding period

-- 14.1 July-December 2014 vs July-December 2013

WITH delays_cte AS (
SELECT
order_id,
order_date,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date > 0
AND DATE_PART('month', order_date) BETWEEN 7 AND 12
)

SELECT
DATE_PART('year', order_date) AS year,
company_name,
ROUND(AVG(delay), 1) AS avg_delay
FROM delays_cte
GROUP BY 1,2
ORDER BY 1,3 DESC

-- 14.2 January-May 2015 vs January-May 2014

WITH delays_cte AS (
SELECT
order_id,
order_date,
shipped_date,
required_date,
shipped_date - required_date AS delay,
company_name
FROM orders
INNER JOIN shippers ON orders.shipper_id=shippers.shipper_id
WHERE shipped_date - required_date > 0
AND DATE_PART('month', order_date) BETWEEN 1 AND 5
)

SELECT
DATE_PART('year', order_date) AS year,
company_name,
ROUND(AVG(delay), 1) AS avg_delay
FROM delays_cte
GROUP BY 1,2
ORDER BY 1,3 DESC

-- 15. Average shipping cost per order

SELECT
ROUND(AVG(freight), 2)
FROM orders

-- 16. Average shipping cost per order, by year + change

WITH freight_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
ROUND(AVG(freight), 2) AS avg_freight
FROM orders
GROUP BY 1
ORDER BY 1
)

SELECT
year,
avg_freight,
LAG(avg_freight) OVER (ORDER BY year) AS prev_year_avg_freight,
avg_freight - LAG(avg_freight) OVER (ORDER BY year) AS abs_change,
ROUND(100.0*(avg_freight - LAG(avg_freight) OVER (ORDER BY year))/LAG(avg_freight) OVER (ORDER BY year), 2) AS pct_change
FROM freight_cte

-- 17. Average shipping cost per order, by period + period-over-period change

-- 17.1 July-December 2014 vs July-December 2013

WITH freight_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
ROUND(AVG(freight), 2) AS avg_freight
FROM orders
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY 1
ORDER BY 1
)

SELECT
year,
avg_freight,
LAG(avg_freight) OVER (ORDER BY year) AS prev_year_avg_freight,
avg_freight - LAG(avg_freight) OVER (ORDER BY year) AS abs_change,
ROUND(100.0*(avg_freight - LAG(avg_freight) OVER (ORDER BY year))/LAG(avg_freight) OVER (ORDER BY year), 2) AS pct_change
FROM freight_cte

-- 17.2 January-May 2015 vs January-May 2014

WITH freight_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
ROUND(AVG(freight), 2) AS avg_freight
FROM orders
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY 1
ORDER BY 1
)

SELECT
year,
avg_freight,
LAG(avg_freight) OVER (ORDER BY year) AS prev_year_avg_freight,
avg_freight - LAG(avg_freight) OVER (ORDER BY year) AS abs_change,
ROUND(100.0*(avg_freight - LAG(avg_freight) OVER (ORDER BY year))/LAG(avg_freight) OVER (ORDER BY year), 2) AS pct_change
FROM freight_cte

-- 18. Freight distribution

WITH freight_cte AS (
SELECT
order_id,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
CASE WHEN freight < 100 THEN '<100'
WHEN freight >= 100 AND freight < 200 THEN '100-200'
WHEN freight >= 200 AND freight < 300 THEN '200-300'
WHEN freight >= 300 AND freight < 400 THEN '300-400'
WHEN freight >= 400 AND freight < 500 THEN '400-500'
WHEN freight >= 500 AND freight < 600 THEN '500-600'
WHEN freight >= 600 AND freight < 700 THEN '600-700'
WHEN freight >= 700 AND freight < 800 THEN '700-800'
WHEN freight >= 800 AND freight < 900 THEN '800-900'
WHEN freight >= 900 THEN '>900'
END AS freight_category
FROM orders
--ORDER BY 1
)

SELECT
year, 
month,
freight_category,
COUNT(*)
FROM freight_cte
GROUP BY 1,2,3
ORDER BY 1,2,ARRAY_POSITION(ARRAY['<100','100-200','200-300','300-400','400-500','500-600','600-700','700-800','800-900','>900'], freight_category)
LIMIT 10

/*=========================
 EMPLOYEE ANALYSIS
=========================*/

-- 1. Net sales by employee, overall

WITH sales_by_employee AS (
SELECT
orders.order_id,
employee_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales
FROM orders
INNER JOIN order_details ON orders.order_id=order_details.order_id
GROUP BY 1,2
--ORDER BY 1
)

SELECT
employees.employee_id,
employee_name,
SUM(net_sales) AS net_sales_by_employee
FROM sales_by_employee
INNER JOIN employees ON sales_by_employee.employee_id=employees.employee_id
GROUP BY 1,2
ORDER BY 3 DESC

-- 2. Net sales by employee and year + year-over-year change

WITH sales_by_employee_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
employee_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales
FROM orders
INNER JOIN order_details ON orders.order_id=order_details.order_id
GROUP BY 1,2,3
--ORDER BY 1
)

, yearly_sales_by_employee_cte AS (
SELECT
year,
employees.employee_id,
employee_name,
SUM(net_sales) AS net_sales
FROM sales_by_employee_cte
INNER JOIN employees ON sales_by_employee_cte.employee_id=employees.employee_id
GROUP BY 1,2,3
--ORDER BY year, net_sales_by_employee DESC
)

SELECT
year,
employee_name,
net_sales,
LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year) AS prev_year_sales,
net_sales - LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year)) / LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year), 2) AS pct_change
FROM yearly_sales_by_employee_cte
ORDER BY year, net_sales DESC
LIMIT 12

-- 3. Net sales by employee and period + period-over-period change

-- 3.1 July-December 2014 vs July-December 2013

WITH sales_by_employee_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
employee_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales
FROM orders
INNER JOIN order_details ON orders.order_id=order_details.order_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY 1,2,3,4
--ORDER BY 1
)

, yearly_sales_by_employee_cte AS (
SELECT
year,
employees.employee_id,
employee_name,
SUM(net_sales) AS net_sales
FROM sales_by_employee_cte
INNER JOIN employees ON sales_by_employee_cte.employee_id=employees.employee_id
GROUP BY 1,2,3
--ORDER BY year, net_sales_by_employee DESC
)

SELECT
year,
employee_name,
net_sales,
LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year) AS same_period_prev_year_sales,
net_sales - LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year)) / LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year), 2) AS pct_change
FROM yearly_sales_by_employee_cte
ORDER BY year, net_sales DESC
LIMIT 10

-- 3.2 January-May 2015 vs January-May 2014

WITH sales_by_employee_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
employee_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales
FROM orders
INNER JOIN order_details ON orders.order_id=order_details.order_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND  5
GROUP BY 1,2,3,4
--ORDER BY 1
)

, yearly_sales_by_employee_cte AS (
SELECT
year,
employees.employee_id,
employee_name,
SUM(net_sales) AS net_sales
FROM sales_by_employee_cte
INNER JOIN employees ON sales_by_employee_cte.employee_id=employees.employee_id
GROUP BY 1,2,3
--ORDER BY year, net_sales_by_employee DESC
)

SELECT
year,
employee_name,
net_sales,
LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year) AS same_period_prev_year_sales,
net_sales - LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year)) / LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year), 2) AS pct_change
FROM yearly_sales_by_employee_cte
ORDER BY year, net_sales DESC
LIMIT 10

-- 4. Net sales by employee and month + month-over-month change

WITH sales_by_employee_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
employee_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales
FROM orders
INNER JOIN order_details ON orders.order_id=order_details.order_id
GROUP BY 1,2,3,4
--ORDER BY 1
)

, monthly_sales_by_employee_cte AS (
SELECT
year,
month,
employees.employee_id,
employee_name,
SUM(net_sales) AS net_sales
FROM sales_by_employee_cte
INNER JOIN employees ON sales_by_employee_cte.employee_id=employees.employee_id
GROUP BY 1,2,3,4
--ORDER BY year, net_sales_by_employee DESC
)

SELECT
year,
month,
employee_name,
net_sales,
LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year, month) AS prev_month_net_sales,
net_sales - LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year, month) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year, month)) / LAG(net_sales) OVER (PARTITION BY employee_name ORDER BY year, month), 2) AS pct_change
FROM monthly_sales_by_employee_cte
ORDER BY year, month, net_sales DESC
LIMIT 10

-- 5. Net sales by employee and month vs same month of previous year

WITH sales_by_employee_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
employee_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales
FROM orders
INNER JOIN order_details ON orders.order_id=order_details.order_id
GROUP BY 1,2,3,4
--ORDER BY 1
)

, monthly_sales_by_employee_cte AS (
SELECT
year,
month,
employees.employee_id,
employee_name,
SUM(net_sales) AS net_sales
FROM sales_by_employee_cte
INNER JOIN employees ON sales_by_employee_cte.employee_id=employees.employee_id
GROUP BY 1,2,3,4
--ORDER BY year, net_sales_by_employee DESC
)

SELECT
year,
month,
employee_name,
net_sales,
LAG(net_sales) OVER (PARTITION BY employee_name, month ORDER BY year) AS same_month_prev_year_sales,
net_sales - LAG(net_sales) OVER (PARTITION BY employee_name, month ORDER BY year) AS abs_change,
ROUND(100.0 * (net_sales - LAG(net_sales) OVER (PARTITION BY employee_name, month ORDER BY year)) / LAG(net_sales) OVER (PARTITION BY employee_name, month ORDER BY year), 2) AS pct_change
FROM monthly_sales_by_employee_cte
ORDER BY year, month, net_sales DESC
LIMIT 5

-- 6. Number of orders by employee, overall

SELECT
employee_name,
COUNT(order_id)
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
GROUP BY 1
ORDER BY 2 DESC

-- 7. Number of orders by employee and year + year-over-year change

WITH yearly_orders_by_employee_cte AS(
SELECT
DATE_PART('year', order_date) AS year,
employee_name,
COUNT(order_id) AS nr_orders
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
GROUP BY 1,2
ORDER BY 1, 3 DESC
)

SELECT
year,
employee_name,
nr_orders,
LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year) AS prev_year_nr_orders,
nr_orders - LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year) AS abs_change,
ROUND(100.0 * (nr_orders - LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year)) / LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year), 2) AS pct_change
FROM yearly_orders_by_employee_cte
ORDER BY year, nr_orders DESC
LIMIT 12

-- 8. Number of orders by employee and period + period-over-period change

-- 8.1 July-December 2014 vs July-December 2013

WITH period_orders_by_employee_cte AS(
SELECT
DATE_PART('year', order_date) AS year,
employee_name,
COUNT(order_id) AS nr_orders
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY 1,2
ORDER BY 1, 3 DESC
)

SELECT
year,
employee_name,
nr_orders,
LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year) AS same_period_prev_year_nr_orders,
nr_orders - LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year) AS abs_change,
ROUND(100.0 * (nr_orders - LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year)) / LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year), 2) AS pct_change
FROM period_orders_by_employee_cte
ORDER BY year, nr_orders DESC
LIMIT 12

-- 8.2 January-May 2015 vs January-May 2014

WITH period_orders_by_employee_cte AS(
SELECT
DATE_PART('year', order_date) AS year,
employee_name,
COUNT(order_id) AS nr_orders
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY 1,2
ORDER BY 1, 3 DESC
)

SELECT
year,
employee_name,
nr_orders,
LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year) AS same_period_prev_year_nr_orders,
nr_orders - LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year) AS abs_change,
ROUND(100.0 * (nr_orders - LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year)) / LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year), 2) AS pct_change
FROM period_orders_by_employee_cte
ORDER BY year, nr_orders DESC
LIMIT 12

-- 9. Number of orders by employee and month + month-over-month change

WITH monthly_orders_by_employee_cte AS(
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
employee_name,
COUNT(order_id) AS nr_orders
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
GROUP BY 1,2,3
ORDER BY 1,2,3 DESC
)

SELECT
year,
month,
employee_name,
nr_orders,
LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year, month) AS prev_month_nr_orders,
nr_orders - LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year, month) AS abs_change,
ROUND(100.0 * (nr_orders - LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year, month)) / LAG(nr_orders) OVER (PARTITION BY employee_name ORDER BY year, month), 2) AS pct_change
FROM monthly_orders_by_employee_cte
ORDER BY year, month, nr_orders DESC
LIMIT 5

-- 10. Number of orders by employee and month vs same month of previous year

WITH monthly_orders_by_employee_cte AS(
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
employee_name,
COUNT(order_id) AS nr_orders
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
GROUP BY 1,2,3
ORDER BY 1,2,3 DESC
)

SELECT
year,
month,
employee_name,
nr_orders,
LAG(nr_orders) OVER (PARTITION BY employee_name, month ORDER BY year) AS same_month_prev_year_nr_orders,
nr_orders - LAG(nr_orders) OVER (PARTITION BY employee_name, month ORDER BY year) AS abs_change,
ROUND(100.0 * (nr_orders - LAG(nr_orders) OVER (PARTITION BY employee_name, month ORDER BY year)) / LAG(nr_orders) OVER (PARTITION BY employee_name, month ORDER BY year), 2) AS pct_change
FROM monthly_orders_by_employee_cte
ORDER BY year, month, nr_orders DESC
LIMIT 5

-- 11. Average net sales by employee and year + year-over-year change

WITH sales_by_order_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
employee_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales
FROM orders
INNER JOIN order_details ON orders.order_id=order_details.order_id
GROUP BY 1,2,3
--ORDER BY 1
)

, sales_by_employee_cte AS (
SELECT
employees.employee_id,
employee_name,
year,
SUM(net_sales) AS net_sales_by_employee
FROM sales_by_order_cte
INNER JOIN employees ON sales_by_order_cte.employee_id=employees.employee_id
GROUP BY 1,2,3
ORDER BY 3,4 DESC
)

, avg_sales_by_year_cte AS (
SELECT
year, 
ROUND(AVG(net_sales_by_employee), 2) AS avg_net_sales_by_employee
FROM sales_by_employee_cte
GROUP BY 1
)

SELECT
year,
avg_net_sales_by_employee,
ROUND(LAG(avg_net_sales_by_employee) OVER (ORDER BY year),2) AS prev_avg_sales_by_employee,
avg_net_sales_by_employee - LAG(avg_net_sales_by_employee) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_net_sales_by_employee - LAG(avg_net_sales_by_employee) OVER (ORDER BY year))/LAG(avg_net_sales_by_employee) OVER (ORDER BY year),2) AS pct_change
FROM avg_sales_by_year_cte

-- 12. Average net sales by employee and period + period-over-period change

-- 12.1 July - December 2014 vs July - December 2013

WITH sales_by_order_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
employee_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales
FROM orders
INNER JOIN order_details ON orders.order_id=order_details.order_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY 1,2,3,4
--ORDER BY 1
)

, sales_by_employee_cte AS (
SELECT
employees.employee_id,
employee_name,
year,
SUM(net_sales) AS net_sales_by_employee
FROM sales_by_order_cte
INNER JOIN employees ON sales_by_order_cte.employee_id=employees.employee_id
GROUP BY 1,2,3
ORDER BY 3,4 DESC
)

, avg_sales_by_year_cte AS (
SELECT
year, 
ROUND(AVG(net_sales_by_employee), 2) AS avg_net_sales_by_employee
FROM sales_by_employee_cte
GROUP BY 1
)

SELECT
year,
avg_net_sales_by_employee,
ROUND(LAG(avg_net_sales_by_employee) OVER (ORDER BY year),2) AS prev_avg_sales_by_employee,
avg_net_sales_by_employee - LAG(avg_net_sales_by_employee) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_net_sales_by_employee - LAG(avg_net_sales_by_employee) OVER (ORDER BY year))/LAG(avg_net_sales_by_employee) OVER (ORDER BY year),2) AS pct_change
FROM avg_sales_by_year_cte

-- 12.2 January - May 2015 vs January - May 2014

WITH sales_by_order_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
employee_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales
FROM orders
INNER JOIN order_details ON orders.order_id=order_details.order_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY 1,2,3,4
--ORDER BY 1
)

, sales_by_employee_cte AS (
SELECT
employees.employee_id,
employee_name,
year,
SUM(net_sales) AS net_sales_by_employee
FROM sales_by_order_cte
INNER JOIN employees ON sales_by_order_cte.employee_id=employees.employee_id
GROUP BY 1,2,3
ORDER BY 3,4 DESC
)

, avg_sales_by_year_cte AS (
SELECT
year, 
ROUND(AVG(net_sales_by_employee), 2) AS avg_net_sales_by_employee
FROM sales_by_employee_cte
GROUP BY 1
)

SELECT
year,
avg_net_sales_by_employee,
ROUND(LAG(avg_net_sales_by_employee) OVER (ORDER BY year),2) AS prev_avg_sales_by_employee,
avg_net_sales_by_employee - LAG(avg_net_sales_by_employee) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_net_sales_by_employee - LAG(avg_net_sales_by_employee) OVER (ORDER BY year))/LAG(avg_net_sales_by_employee) OVER (ORDER BY year),2) AS pct_change
FROM avg_sales_by_year_cte

-- 13. Average number of orders by employee and year + year-over-year change

WITH nr_orders_by_employee_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
orders.employee_id,
employee_name,
COUNT(DISTINCT order_id) AS nr_orders
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
GROUP BY 1,2,3
)

, avg_nr_orders_by_employee_cte AS (
SELECT
year, 
ROUND(AVG(nr_orders), 2) AS avg_nr_orders_by_employee
FROM nr_orders_by_employee_cte
GROUP BY 1
)

SELECT
year,
avg_nr_orders_by_employee,
ROUND(LAG(avg_nr_orders_by_employee) OVER (ORDER BY year),2) AS prev_avg_nr_orders_by_employee,
avg_nr_orders_by_employee - LAG(avg_nr_orders_by_employee) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_nr_orders_by_employee - LAG(avg_nr_orders_by_employee) OVER (ORDER BY year))/LAG(avg_nr_orders_by_employee) OVER (ORDER BY year),2) AS pct_change
FROM avg_nr_orders_by_employee_cte

-- 14. Average number of orders by employee and period + period-over-period change

-- 14.1 July - December 2014 vs July - December 2013

WITH nr_orders_by_employee_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
orders.employee_id,
employee_name,
COUNT(DISTINCT order_id) AS nr_orders
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12
GROUP BY 1,2,3
)

, avg_nr_orders_by_employee_cte AS (
SELECT
year, 
ROUND(AVG(nr_orders), 2) AS avg_nr_orders_by_employee
FROM nr_orders_by_employee_cte
GROUP BY 1
)

SELECT
year,
avg_nr_orders_by_employee,
ROUND(LAG(avg_nr_orders_by_employee) OVER (ORDER BY year),2) AS prev_avg_nr_orders_by_employee,
avg_nr_orders_by_employee - LAG(avg_nr_orders_by_employee) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_nr_orders_by_employee - LAG(avg_nr_orders_by_employee) OVER (ORDER BY year))/LAG(avg_nr_orders_by_employee) OVER (ORDER BY year),2) AS pct_change
FROM avg_nr_orders_by_employee_cte

-- 14.2 January - May 2015 vs January - May 2014

WITH nr_orders_by_employee_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
orders.employee_id,
employee_name,
COUNT(DISTINCT order_id) AS nr_orders
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5
GROUP BY 1,2,3
)

, avg_nr_orders_by_employee_cte AS (
SELECT
year, 
ROUND(AVG(nr_orders), 2) AS avg_nr_orders_by_employee
FROM nr_orders_by_employee_cte
GROUP BY 1
)

SELECT
year,
avg_nr_orders_by_employee,
ROUND(LAG(avg_nr_orders_by_employee) OVER (ORDER BY year),2) AS prev_avg_nr_orders_by_employee,
avg_nr_orders_by_employee - LAG(avg_nr_orders_by_employee) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_nr_orders_by_employee - LAG(avg_nr_orders_by_employee) OVER (ORDER BY year))/LAG(avg_nr_orders_by_employee) OVER (ORDER BY year),2) AS pct_change
FROM avg_nr_orders_by_employee_cte

-- 15. Average number of customers by employee and year + year-over-year change

WITH nr_customers_by_employee_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
orders.employee_id,
employee_name,
COUNT(DISTINCT customer_id) AS nr_customers
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
GROUP BY 1,2,3
)

, avg_nr_customers_by_employee_cte AS (
SELECT
year, 
ROUND(AVG(nr_customers), 2) AS avg_nr_customers_by_employee
FROM nr_customers_by_employee_cte
GROUP BY 1
)

SELECT
year,
avg_nr_customers_by_employee,
ROUND(LAG(avg_nr_customers_by_employee) OVER (ORDER BY year),2) AS prev_avg_nr_customers_by_employee,
avg_nr_customers_by_employee - LAG(avg_nr_customers_by_employee) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_nr_customers_by_employee - LAG(avg_nr_customers_by_employee) OVER (ORDER BY year))/LAG(avg_nr_customers_by_employee) OVER (ORDER BY year),2) AS pct_change
FROM avg_nr_customers_by_employee_cte

-- 16. Average number of customers by employee and period + period-over-period change

-- 16.1 July - December 2014 vs July - December 2013

WITH nr_customers_by_employee_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
orders.employee_id,
employee_name,
COUNT(DISTINCT customer_id) AS nr_customers
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
WHERE DATE_PART('month', order_date) BETWEEN 7 AND 12	
GROUP BY 1,2,3
)

, avg_nr_customers_by_employee_cte AS (
SELECT
year, 
ROUND(AVG(nr_customers), 2) AS avg_nr_customers_by_employee
FROM nr_customers_by_employee_cte
GROUP BY 1
)

SELECT
year,
avg_nr_customers_by_employee,
ROUND(LAG(avg_nr_customers_by_employee) OVER (ORDER BY year),2) AS prev_avg_nr_customers_by_employee,
avg_nr_customers_by_employee - LAG(avg_nr_customers_by_employee) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_nr_customers_by_employee - LAG(avg_nr_customers_by_employee) OVER (ORDER BY year))/LAG(avg_nr_customers_by_employee) OVER (ORDER BY year),2) AS pct_change
FROM avg_nr_customers_by_employee_cte

-- 16.2 January - May 2015 vs January - May 2014

WITH nr_customers_by_employee_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
orders.employee_id,
employee_name,
COUNT(DISTINCT customer_id) AS nr_customers
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
WHERE DATE_PART('month', order_date) BETWEEN 1 AND 5	
GROUP BY 1,2,3
)

, avg_nr_customers_by_employee_cte AS (
SELECT
year, 
ROUND(AVG(nr_customers), 2) AS avg_nr_customers_by_employee
FROM nr_customers_by_employee_cte
GROUP BY 1
)

SELECT
year,
avg_nr_customers_by_employee,
ROUND(LAG(avg_nr_customers_by_employee) OVER (ORDER BY year),2) AS prev_avg_nr_customers_by_employee,
avg_nr_customers_by_employee - LAG(avg_nr_customers_by_employee) OVER (ORDER BY year) AS abs_change,
ROUND(100.0 * (avg_nr_customers_by_employee - LAG(avg_nr_customers_by_employee) OVER (ORDER BY year))/LAG(avg_nr_customers_by_employee) OVER (ORDER BY year),2) AS pct_change
FROM avg_nr_customers_by_employee_cte

-- 17. Employee rank by net sales by month

WITH sales_by_order_cte AS (
SELECT
orders.order_id,
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
employee_id,
ROUND(SUM(quantity*unit_price*(1-discount)), 2) AS net_sales
FROM orders
INNER JOIN order_details ON orders.order_id=order_details.order_id
GROUP BY 1,2,3,4
--ORDER BY 1
)

, sales_by_employee_cte AS (
SELECT
year,
month,
employees.employee_id,
employee_name,
SUM(net_sales) AS net_sales_by_employee
FROM sales_by_order_cte
INNER JOIN employees ON sales_by_order_cte.employee_id=employees.employee_id
GROUP BY 1,2,3,4
ORDER BY 1,2,4 DESC
)

SELECT
year,
month,
employee_name,
net_sales_by_employee,
DENSE_RANK() OVER (PARTITION BY year,month ORDER BY net_sales_by_employee DESC) AS employee_sales_rank
FROM sales_by_employee_cte
ORDER BY 1,2  
LIMIT 5

-- 18. Employee rank by nr orders by month

WITH nr_orders_by_employee_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
orders.employee_id,
employee_name,
COUNT(DISTINCT order_id) AS nr_orders
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
GROUP BY 1,2,3,4
)

SELECT
year, 
month,
employee_name,
nr_orders,
DENSE_RANK() OVER (PARTITION BY year,month ORDER BY nr_orders DESC) AS employee_nr_orders_rank
FROM nr_orders_by_employee_cte
ORDER BY 1,2
LIMIT 5

-- 19. Employee rank by nr customers by month

WITH nr_customers_by_employee_cte AS (
SELECT
DATE_PART('year', order_date) AS year,
DATE_PART('month', order_date) AS month,
orders.employee_id,
employee_name,
COUNT(DISTINCT customer_id) AS nr_customers
FROM orders
INNER JOIN employees ON orders.employee_id=employees.employee_id
GROUP BY 1,2,3,4
)

SELECT
year, 
month,
employee_name,
nr_customers,
DENSE_RANK() OVER (PARTITION BY year,month ORDER BY nr_customers DESC) AS employee_nr_customers_rank
FROM nr_customers_by_employee_cte
ORDER BY 1,2
LIMIT 5
