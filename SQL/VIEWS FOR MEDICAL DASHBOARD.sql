USE healthcare_db_enhanced;
													
                                                    -- SALES DASHBOARD --
CREATE OR REPLACE VIEW sales_dashboard AS

WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(sale_date, '%Y-%m') AS sales_month,

        SUM(total_amount) AS total_monthly_revenue,

        COUNT(DISTINCT sale_id) AS total_transactions

    FROM sales
    GROUP BY DATE_FORMAT(sale_date, '%Y-%m')
),

monthly_growth AS (
    SELECT
        sales_month,
        total_monthly_revenue,
        total_transactions,

        LAG(total_monthly_revenue) OVER (
            ORDER BY sales_month
        ) AS previous_revenue

    FROM monthly_sales
),

sales_details AS (
    SELECT
        DATE_FORMAT(sale_date, '%Y-%m') AS sales_month,
        payment_method,
        is_prescription,

        SUM(total_amount) AS total_revenue

    FROM sales
    GROUP BY
        DATE_FORMAT(sale_date, '%Y-%m'),
        payment_method,
        is_prescription
)

SELECT
    sd.sales_month,
    sd.payment_method,
    sd.is_prescription,

    sd.total_revenue,

    ms.total_monthly_revenue,
    ms.total_transactions,

    mg.previous_revenue,

    mg.total_monthly_revenue - mg.previous_revenue
        AS revenue_diff,

    ROUND(
        (mg.total_monthly_revenue - mg.previous_revenue)
        * 100.0 / NULLIF(mg.previous_revenue, 0),
        2
    ) AS month_growth_percentage,

    ROUND(
        sd.total_revenue * 100.0 /
        NULLIF(ms.total_monthly_revenue, 0),
        2
    ) AS sales_percentage_within_month,

    ROUND(
        sd.total_revenue * 100.0 /
        NULLIF((SELECT SUM(total_amount) FROM sales), 0),
        2
    ) AS overall_sales_contribution

FROM sales_details sd

INNER JOIN monthly_sales ms
    ON sd.sales_month = ms.sales_month

INNER JOIN monthly_growth mg
    ON sd.sales_month = mg.sales_month;                                                    
                                                    
                                                    
                                                    
CREATE OR REPLACE VIEW vw_sales_monthly AS
WITH monthly_sales AS (
    SELECT DATE_FORMAT(sale_date, '%Y-%m') AS sales_month,
           MIN(DATE_FORMAT(sale_date, '%Y-%m-01')) AS month_start,
           SUM(total_amount)                AS total_monthly_revenue,
           COUNT(DISTINCT sale_id)          AS total_transactions
    FROM sales
    GROUP BY DATE_FORMAT(sale_date, '%Y-%m')
)
SELECT sales_month,
       month_start,
       total_monthly_revenue,
       total_transactions,
       LAG(total_monthly_revenue) OVER (ORDER BY sales_month) AS previous_revenue,
       total_monthly_revenue
         - LAG(total_monthly_revenue) OVER (ORDER BY sales_month) AS revenue_diff,
       ROUND((total_monthly_revenue
         - LAG(total_monthly_revenue) OVER (ORDER BY sales_month)) * 100.0
         / NULLIF(LAG(total_monthly_revenue) OVER (ORDER BY sales_month), 0), 2) AS month_growth_percentage
FROM monthly_sales;

CREATE OR REPLACE VIEW vw_sales_details AS
SELECT DATE_FORMAT(sale_date, '%Y-%m') AS sales_month,
       payment_method,
       is_prescription,
       SUM(total_amount)  AS total_revenue,
       COUNT(DISTINCT sale_id) AS transactions
FROM sales
GROUP BY DATE_FORMAT(sale_date, '%Y-%m'), payment_method, is_prescription;

SELECT * 
FROM sales_dashboard ; 

SELECT COUNT(DISTINCT sale_id), COUNT(*) FROM sales;														-- STORES & REGION DASHBOARD --

CREATE OR REPLACE VIEW vw_stores_dashboard AS
WITH store_employees AS (
    SELECT store_id, COUNT(employee_id) AS total_employees
    FROM employees
    GROUP BY store_id
),
store_sales AS (
    SELECT store_id,
           SUM(total_amount)           AS total_revenue,
           COUNT(DISTINCT employee_id) AS sales_employees
    FROM sales
    GROUP BY store_id
),
store_performance AS (
    SELECT st.store_id, st.store_name, st.city, st.region, st.manager_name,
           COALESCE(se.total_employees, 0) AS total_employees,
           COALESCE(ss.total_revenue, 0)   AS total_revenue,
           COALESCE(ss.sales_employees, 0) AS sales_employees,
           ROUND(ss.total_revenue / NULLIF(se.total_employees, 0), 2) AS revenue_per_employee,
           AVG(COALESCE(ss.total_revenue, 0)) OVER (PARTITION BY st.region) AS region_avg_revenue
    FROM stores st
    LEFT JOIN store_employees se ON st.store_id = se.store_id
    LEFT JOIN store_sales ss     ON st.store_id = ss.store_id
)
SELECT store_id, store_name, city, region, manager_name,
       total_employees, total_revenue, sales_employees, revenue_per_employee,
       ROUND(region_avg_revenue, 2) AS region_avg_revenue,
       CASE
           WHEN total_revenue > region_avg_revenue THEN 'Above Average'
           WHEN total_revenue < region_avg_revenue THEN 'Below Average'
           ELSE 'Equal To Average'
       END AS regional_performance
FROM store_performance;

CREATE OR REPLACE VIEW vw_store_top_products AS
WITH product_performance AS (
    SELECT s.store_id,
           p.product_id,
           p.product_name,
           SUM(s.total_amount) AS product_revenue,
           DENSE_RANK() OVER (
               PARTITION BY s.store_id
               ORDER BY SUM(s.total_amount) DESC
           ) AS product_rank
    FROM sales s
    INNER JOIN products p ON s.product_id = p.product_id
    GROUP BY s.store_id, p.product_id, p.product_name
)
SELECT store_id, product_id, product_name, product_revenue, product_rank
FROM product_performance
WHERE product_rank <= 5; 

SELECT store_id, COUNT(*) FROM vw_stores_dashboard GROUP BY store_id HAVING COUNT(*) > 1; 

														-- EMPLOYEE PERFORMANCE DASHBOARD --               
                                  
CREATE OR REPLACE VIEW vw_employee_performance AS

WITH employee_performance AS (
    SELECT
        e.employee_id,
        e.employee_name,
        e.salary,
        st.store_id,
        st.store_name,
        SUM(s.total_amount) AS total_revenue,
        SUM(s.quantity)     AS total_units,
        DENSE_RANK() OVER (
            PARTITION BY st.store_id
            ORDER BY SUM(s.total_amount) DESC
        ) AS employee_rank
    FROM employees e
    INNER JOIN sales s
        ON e.employee_id = s.employee_id
    INNER JOIN stores st
        ON s.store_id = st.store_id
    GROUP BY
        e.employee_id,
        e.employee_name,
        e.salary,
        st.store_id,
        st.store_name
)
SELECT
    employee_id,
    employee_name,
    salary,
    store_id,
    store_name,
    total_revenue,
    total_units,
    employee_rank,
    CASE
        WHEN employee_rank = 1 THEN 'Top Performer'
        ELSE 'Other Employee'
    END AS employee_status
FROM employee_performance;
                                  
														-- PRODUCTS CATEGORIES DASHBOARD --
CREATE OR REPLACE VIEW vw_product_dashboard AS

WITH product_sales AS (
    SELECT
        p.product_id,
        SUM(s.quantity) AS total_quantity_sold,
        SUM(s.total_amount) AS total_revenue,
        COUNT(s.sale_id) AS transaction_count,
        SUM(s.quantity * (p.unit_price - p.cost_price)) AS estimated_profit

    FROM products p
    LEFT JOIN sales s
        ON p.product_id = s.product_id

    GROUP BY p.product_id
),

category_revenue AS (
    SELECT
        c.category_id,
        SUM(s.total_amount) AS category_revenue

    FROM categories c
    JOIN products p
        ON c.category_id = p.category_id
    JOIN sales s
        ON p.product_id = s.product_id

    GROUP BY c.category_id
)

SELECT
    p.product_id,
    p.product_name,
    c.category_name,

    p.unit_price,
    p.cost_price,

    ps.total_quantity_sold,
    ps.total_revenue,
    ps.transaction_count,
    ps.estimated_profit,

    cr.category_revenue,

    ROUND(
        cr.category_revenue * 100 /
        NULLIF((SELECT SUM(total_amount) FROM sales), 0),
        2
    ) AS category_revenue_contribution

FROM products p

LEFT JOIN categories c
    ON p.category_id = c.category_id

LEFT JOIN product_sales ps
    ON p.product_id = ps.product_id

LEFT JOIN category_revenue cr
    ON c.category_id = cr.category_id;
    
SELECT *
FROM vw_product_dashboard;


														-- SUPPLIES & INVENTORY DASHBOARD --
CREATE OR REPLACE VIEW vw_supplies_inventory AS

SELECT
    s.supplier_id,
    s.supplier_name,

    p.product_id,
    p.product_name,

    supplier_products.products_count,

    st.store_id,
    st.store_name,

    sc.quantity,
    sc.reorder_level,

    sc.quantity - sc.reorder_level AS difference

FROM suppliers s

INNER JOIN products p
    ON s.supplier_id = p.supplier_id

INNER JOIN (
    SELECT
        supplier_id,
        COUNT(product_id) AS products_count
    FROM products
    GROUP BY supplier_id
) supplier_products
    ON s.supplier_id = supplier_products.supplier_id

INNER JOIN stock sc
    ON p.product_id = sc.product_id

INNER JOIN stores st
    ON sc.store_id = st.store_id

WHERE sc.quantity < sc.reorder_level;

												-- CUSTOMER LOYALTY DASHBOARD --

CREATE OR REPLACE VIEW vw_customer_dashboard AS

WITH customer_sales AS (
    SELECT
        customer_id,
        COUNT(*) AS purchase_count,
        SUM(total_amount) AS total_spending,
        COUNT(DISTINCT store_id) AS store_count,
        COUNT(DISTINCT payment_method) AS payment_methods_count,
        MIN(sale_date) AS first_purchase,
        MAX(sale_date) AS last_purchase
    FROM sales
    GROUP BY customer_id
),

customer_payments AS (
    SELECT
        customer_id,
        GROUP_CONCAT(
            DISTINCT payment_method
            ORDER BY payment_method
            SEPARATOR ', '
        ) AS payment_methods,
        SUM(total_amount) AS total_payment,
        COUNT(*) AS total_transactions
    FROM sales
    GROUP BY customer_id
),

customer_data AS (
    SELECT
        c.customer_id,
        c.loyalty_level,
        c.total_points,

        COALESCE(cs.purchase_count, 0) AS purchase_count,
        COALESCE(cs.total_spending, 0) AS total_spending,
        COALESCE(cs.store_count, 0) AS store_count,

        cs.first_purchase,
        cs.last_purchase,

        cp.payment_methods,
        COALESCE(cp.total_payment, 0) AS total_payment,
        COALESCE(cp.total_transactions, 0) AS total_transactions

    FROM customer_loyalty c

    LEFT JOIN customer_sales cs
        ON c.customer_id = cs.customer_id

    LEFT JOIN customer_payments cp
        ON c.customer_id = cp.customer_id
),

customer_ranked AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            ORDER BY total_spending DESC
        ) AS spending_rank,

        NTILE(5) OVER (
            ORDER BY total_spending DESC
        ) AS spending_group

    FROM customer_data
)

SELECT
    *,

    COUNT(customer_id) OVER (
        PARTITION BY loyalty_level
    ) AS total_customers,

    SUM(total_spending) OVER (
        PARTITION BY loyalty_level
    ) AS loyalty_total_revenue,

    ROUND(
        SUM(total_spending) OVER (
            PARTITION BY loyalty_level
        ) /
        NULLIF(
            COUNT(customer_id) OVER (
                PARTITION BY loyalty_level
            ), 0
        ),
        2
    ) AS avg_customer_spending,

    ROUND(
        AVG(total_points) OVER (
            PARTITION BY loyalty_level
        ), 2
    ) AS avg_loyalty_points,

    CASE
        WHEN purchase_count > 10
         AND store_count > 1
         AND total_spending > (
             SELECT AVG(total_spending)
             FROM customer_data
         )
        THEN 'Qualified'
        ELSE 'Not Qualified'
    END AS purchase_behavior

FROM customer_ranked;

SELECT *
FROM vw_customer_dashboard;

SELECT MAX(store_count) FROM vw_customer_dashboard;



-- must have to be equall -- 3shan ana at2aked enhom 3la mostwa l customer l wa7ed -- 
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM vw_customer_dashboard;

USE healthcare_db_enhanced;

SHOW FULL TABLES
WHERE Table_type = 'VIEW';

