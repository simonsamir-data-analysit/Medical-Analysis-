USE healthcare_db_enhanced;
															-- SALES DASHBOARD --
-- 4. Sales by Payment Method -- 

CREATE VIEW sales_dashboard AS
SELECT DISTINCT payment_method , sum(total_amount) AS total_revenue
FROM sales 
GROUP BY payment_method
ORDER BY  total_revenue DESC ; 

-- 7. Prescription Sales -- 

SELECT is_prescription, sum(total_amount) AS total_sales,
ROUND(sum(total_amount)*100.0 / sum(sum(total_amount)) OVER (),2) AS sales_prcentage

FROM sales 
GROUP BY  is_prescription 
ORDER BY total_sales DESC; 

-- 14. Monthly Sales Trend -- 

SELECT DATE_FORMAT (sale_date, '%Y-%m') AS sales_month , SUM(total_amount) AS total_revenue, 
COUNT(DISTINCT customer_id) AS total_transactions 

FROM sales 
GROUP BY DATE_FORMAT (sale_date, '%Y-%m') 
ORDER BY sales_month DESC ; 

-- 20. Monthly Growth Analysis-- 

SELECT DATE_FORMAT (sale_date, '%Y-%m') AS sales_month , SUM(total_amount) AS total_revenue ,

LAG (SUM(total_amount)) OVER (ORDER BY DATE_FORMAT (sale_date, '%Y-%m') DESC) AS prevoius_revenue , 
SUM(total_amount) - LAG (SUM(total_amount)) OVER (ORDER BY DATE_FORMAT(sale_date, '%Y-%m')DESC) AS revenue_diff, 

ROUND(SUM(total_amount) - LAG(SUM(total_amount)) OVER (ORDER BY DATE_FORMAT (sale_date, '%Y-%m'))) *100.0 
/ LAG(SUM(total_amount)) OVER(ORDER BY DATE_FORMAT(sale_date,'%Y-%m')) AS month_growth_precentage 

FROM sales 
GROUP BY DATE_FORMAT (sale_date, '%Y-%m') 
ORDER BY sales_month DESC ; 

														-- STORES & REGION DASHBOARD --
-- 3. Store Performance -- 
CREATE VIEW stores_region AS 
	SELECT st.store_id, st.store_name, st.city, st.region, st.manager_name,  count(e.employee_id) AS total_employees
	FROM stores st 
	INNER JOIN employees e
		ON st.store_id = e.store_id
	GROUP BY st.store_id, st.store_name, st.region, st.city, st.manager_name 
    ORDER BY total_employees DESC ;
    
-- 5. Regional Revenue -- 

SELECT st.store_id, st.region, st.store_name, sum(sa.total_amount) AS total_revenue
FROM stores st 
INNER JOIN sales sa
	ON st.store_id = sa.store_id
GROUP BY st.store_id, st.region, st.store_name
ORDER BY  total_revenue DESC ;    

-- OPTION 2 -- 
SELECT st.region, sum(sa.total_amount) AS total_revenue
FROM stores st 
INNER JOIN sales sa
	ON st.store_id = sa.store_id
GROUP BY st.region
ORDER BY  total_revenue DESC ;  

-- 10. Store Revenue per Employee -- 
-- ALL Employees -- 

SELECT st.store_id, st.store_name, SUM(sa.total_amount) AS total_revenue , COUNT(DISTINCT e.employee_id) AS total_employees, 
ROUND(SUM(sa.total_amount)/COUNT(DISTINCT e.employee_id),2) AS avg_rev

FROM stores st 
INNER JOIN sales sa 	
	ON st.store_id = sa.store_id 
INNER JOIN employees e 
	ON 	sa.employee_id = e.employee_id
GROUP BY  st.store_name , st.store_id
ORDER BY avg_rev DESC ; 

-- 22. Store Performance vs Regional Average -- 

SELECT st.store_id, st.store_name, st.region, SUM(s.total_amount) AS store_revenue, 
AVG(SUM(s.total_amount)) OVER(PARTITION BY st.region) AS region_agv_revenue ,

CASE 
	WHEN SUM(s.total_amount) > AVG(SUM(s.total_amount)) OVER(PARTITION BY st.region) THEN 'Above Average'
    WHEN SUM(s.total_amount) < AVG(SUM(s.total_amount)) OVER(PARTITION BY st.region) THEN 'Below Average'
    ELSE 'Equal To Average'
    END AS performance 

FROM stores st 
INNER JOIN sales s 
	ON st.store_id = s.store_id 
GROUP BY st.store_id, st.store_name, st.region 
ORDER BY  store_revenue, st.region ;  

-- 15. Store Product Performance -- 

SELECT store_id, store_name, product_id, product_name , total_revenue, product_rank
FROM ( 
	SELECT st.store_id, st.store_name, p.product_id, p.product_name, SUM(s.total_amount) AS total_revenue ,
    DENSE_RANK() OVER(PARTITION BY store_id ORDER BY SUM(s.total_amount) DESC ) AS product_rank
    
FROM stores st  
INNER JOIN stock sc 
	ON st.store_id = sc.store_id 
INNER JOIN  products p    
	ON sc.product_id  = p.product_id
INNER JOIN sales s 
	ON p.product_id	= s.product_id 
GROUP BY   st.store_id, st.store_name, p.product_id, p.product_name ) AS rank_data
WHERE product_rank <= 5 
ORDER BY   total_revenue  DESC ; 

														-- EMPLOYEE PERFORMANCE DASHBOARD --
-- 17. Employee Sales Performance --
 
CREATE VIEW employee AS
WITH employee_performance AS (

SELECT e.employee_id, st.store_id, SUM(s.total_amount) AS total_revenue , 
DENSE_RANK() OVER(PARTITION BY st.store_id ORDER BY SUM(s.total_amount) DESC) AS employee_rank

FROM employees e 
INNER JOIN sales s 
	ON e.employee_id = s.employee_id 
INNER JOIN stores st 
	ON s.store_id = st.store_id	
GROUP BY e.employee_id, st.store_id ) 

SELECT * 
FROM employee_performance 
WHERE employee_rank = 1 
ORDER BY store_id;    


-- 18. Employee Ranking -- 

SELECT e.employee_id, e.employee_name, st.store_id, st.store_name, SUM(s.total_amount) AS total_revenue , 
DENSE_RANK() OVER(PARTITION BY st.store_id ORDER BY SUM(s.total_amount) DESC) AS emp_rank 

FROM employees e 
INNER JOIN sales s 
	ON e.employee_id = s.employee_id 
INNER JOIN stores st 
	ON s.store_id = st.store_id	
GROUP BY e.employee_id, st.store_id
ORDER BY st.store_id, emp_rank ;                  
                                      
														-- PRODUCTS CATEGORIES DASHBOARD --

-- 1. Product Catalog --
CREATE VIEW product AS

SELECT c.category_name, count(p.product_id) AS total_products
FROM categories c
LEFT JOIN products p 
	ON c.category_id = p.category_id 
GROUP BY c.category_id, c.category_name
ORDER BY total_products DESC; 

-- 8. Product Pricing -- 

SELECT product_id, product_name, unit_price 
FROM products 
ORDER BY unit_price DESC
LIMIT 20 ; 

-- ANOTHER OPTION -- 

SELECT  product_id, product_name, unit_price 
FROM(
	SELECT  product_id, product_name, unit_price , RANK() OVER (ORDER BY unit_price DESC) AS price_rank 
    
FROM products ) p
WHERE price_rank <= 20 ; 

-- 9. Category Revenue -- 

SELECT sa.quantity, c.category_name, SUM(sa.total_amount) AS total_revenue
FROM sales sa 
INNER JOIN products p 
	ON sa.product_id = p.product_id 
INNER JOIN categories c 
	ON p.category_id = 	c.category_id
GROUP BY sa.quantity, c.category_name
ORDER BY  total_revenue  DESC ;  

-- RANK -- 
 
SELECT c.category_name, SUM(sa.quantity) AS total_quantity , SUM(sa.total_amount) AS total_revenue ,
RANK () OVER(ORDER BY SUM(sa.total_amount) DESC ) AS revenue_rank 

FROM sales sa 
INNER JOIN products p 
	ON sa.product_id = p.product_id 
INNER JOIN categories c
	ON p.category_id = 	c.category_id
GROUP BY c.category_id, c.category_name 
ORDER BY revenue_rank ; 

-- 11. Product Profitabilit -- 

SELECT p.product_id, p.product_name, SUM(s.quantity) AS total_quantiy_sold, p.cost_price, p.unit_price, 
SUM(s.quantity *(p.unit_price - p.cost_price)) AS estimated_profit 

FROM products p 
INNER JOIN sales s 
	ON p.product_id = s.product_id 
GROUP BY p.product_id, p.product_name, p.cost_price, p.unit_price
ORDER BY  estimated_profit  DESC 
LIMIT 20;  

-- 19. Category Revenue Contribution -- 
-- total revenue = overall company revenue already --  (ASK)

WITH category_revenue AS (
SELECT c.category_id, c.category_name, SUM(s.total_amount) AS total_revenue , 
ROUND( SUM(s.total_amount) *100 / SUM(SUM(s.total_amount)) OVER (), 2 ) AS Percentage_contribution
FROM categories c    
INNER JOIN products p 
	ON c.category_id = p.category_id 
INNER JOIN sales s 
	ON 	p.product_id = s.product_id 
GROUP BY c.category_id, c.category_name )

SELECT * 
FROM category_revenue
WHERE Percentage_contribution > 10 
ORDER BY  Percentage_contribution ASC ;  	

CREATE VIEW product_sales AS 
SELECT p.product_id, p.product_name, c.category_name, SUM(s.quantity) AS total_quantity_sold, SUM(s.total_amount) AS total_revenue,
COUNT(*) AS transaction_count 

FROM products p 
LEFT JOIN sales s 
	ON p.product_id = s.product_id
    
INNER JOIN categories c    
	ON p.category_id = c.category_id 
GROUP BY p.product_id, p.product_name, c.category_name 
ORDER BY total_quantity_sold DESC ;

SELECT * 
FROM product_sales 
WHERE transaction_count > 50

														-- SUPPLIES & INVENTORY DASHBOARD --

-- 2. Supplier Portfolio --

CREATE VIEW supplies_inventory AS
SELECT s.supplier_id, s.supplier_name, count(p.product_id) AS products_count
FROM suppliers s 
INNER JOIN products p 
	ON s.supplier_id = p.supplier_id 
GROUP BY  s.supplier_id, s.supplier_name 
ORDER BY products_count DESC; 

-- 16. Inventory Risk -- 

SELECT st.store_id, st.store_name, p.product_name, sc.quantity, sc.reorder_level , sc.quantity - sc.reorder_level AS difference 
FROM stores st 
INNER JOIN stock sc 
	ON st.store_id = sc.store_id 
INNER JOIN products p 
	ON 	sc.product_id = p.product_id 
WHERE  sc.quantity <  sc.reorder_level 
ORDER BY difference ASC ;  

														-- CUSTOMER LOYALTY DASHBOARD --

-- 6. Customer Loyalty Distribution -- 

CREATE VIEW customer_dashboard AS
SELECT loyalty_level, count(customer_id) AS total_customers
FROM customer_loyalty
GROUP BY  loyalty_level
ORDER BY total_customers DESC ; 

-- 13. Loyalty Level Performance -- 

SELECT  c.loyalty_level, COUNT(DISTINCT c.customer_id) AS total_customer , SUM(s.total_amount) AS total_revenue ,
ROUND(SUM(s.total_amount)/ COUNT(DISTINCT c.customer_id),2) AS avg_cus_spending , AVG(c.total_points) AS avg_loyalty_points 

FROM customer_loyalty c 
INNER JOIN sales s 
	ON c.customer_id = s.customer_id 
GROUP BY c.loyalty_level 
ORDER BY avg_loyalty_points DESC ; 

-- 12. Customer Spending --

SELECT c.customer_id, SUM(s.total_amount) AS total_amount
FROM customer_loyalty c 
INNER JOIN sales s 
	ON c.customer_id = s.customer_id 
GROUP BY c.customer_id 
ORDER BY  total_amount DESC 
LIMIT 50;   

-- 21. Customer Purchase Ranking -- 

SELECT customer_id, SUM(total_amount) AS total_spending, 
DENSE_RANK() OVER(ORDER BY SUM(total_amount) DESC) AS spending_rank , 
NTILE (5) OVER(ORDER BY SUM(total_amount) DESC) AS spending_group 

FROM sales s 
GROUP BY customer_id 
ORDER BY spending_rank ASC ; 

-- 23. Customer Purchase Behavior -- 

WITH customer_region AS (

SELECT customer_id, COUNT(*) AS purchase_count, SUM(total_amount) AS total_spending, COUNT(DISTINCT store_id ) AS store_count
FROM sales  
GROUP BY customer_id ) 

SELECT * 
FROM customer_region
WHERE purchase_count > 10
AND store_count > 1 
AND total_spending > (SELECT AVG(total_spending) FROM customer_region)
ORDER BY total_spending DESC ;   

CREATE VIEW customer_payment AS 
SELECT customer_id, payment_method, MIN(sale_date) AS first_purchase, MAX(sale_date) AS last_purchase,
 SUM(total_amount) AS total_payment, COUNT(customer_id) As total_transaction 
 
FROM sales 
GROUP BY  customer_id, payment_method
ORDER BY total_payment DESC ; 

SELECT *
FROM customer_payment 
LIMIT 50 ; 
