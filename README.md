# Medical-Analysis-

# Home Healthcare Analytics

**Better Insights, Healthier Decisions**

A SQL and Power BI project that analyzes a healthcare retail chain: 12 stores, 10K loyalty customers, 500K transactions and 534.95M in revenue. I wrote 20+ analytical queries in MySQL, turned them into views, and built a six-page Power BI report with a custom navigation layout.

The dataset is synthetic and used for learning purposes only.
![Home page](home_page.png) 

## Key Metrics
- Revenue = 534.95M 
- Transactions = 500K 
- Profit margin = 42.63% 
- Stores and Regions = 12 and 5 
- Customers = 10K across 4 loyalty tiers
- Employees = 120 
- Suppliers = 5 

## What I Wanted to Find Out
- Where does revenue come from: products, stores, payment methods?
- Which inventory items are at risk of running out?
- Does the loyalty program actually change how much customers spend?
- How do stores and employees compare once you account for size?

## Skills Demonstrated

**SQL (MySQL)**
- Multi-table joins, CTEs, and subqueries
- Window functions: RANK, DENSE_RANK, LAG, and SUM() OVER (PARTITION BY ...)
- Month-over-month growth, revenue contribution, customer segmentation, and top-N per group
- Reusable views designed around the grain each report page needs

**Power BI**
- Data modeling with one-to-many relationships and single-direction filtering
- DAX measures for revenue, per-employee metrics, and percentage of total
- Cross page navigation, slicers, and conditional formatting

## Visualization and UI/UX
- A consistent layout across all six pages: header, KPI row, then supporting charts and tables
- A three-color palette (teal, orange and cream) with one accent color for highlights, so the eye lands on the important number first
- A persistent sidebar and a home page with button navigation, so the report works like an app instead of a stack of pages
- A short tagline on each page that states the question the page answers
- Chart choice matched to the question: bars for ranking, donuts for share of total, line and column for trends, tables for detail

## Dashboards
Each Page and Question it answers : 
**Sales** How is revenue trending, and how is it split by payment method and prescription status? 
**Products** Which categories and products drive revenue and profit? 
**Supplies & Inventory** Which items are below reorder level, and how concentrated is the supplier base? 
**Customer Loyalty** How do the four tiers compare on spending and behavior? 
**Stores & Region** Which stores beat their regional average, and how productive is each per employee? 
**Employee Performance** Who are the top performers in each store? 


## Key Findings
 1. Prescription products make up only 14.96% of revenue. About 85% comes from non-prescription items.
 2. Payment methods are evenly balanced, around 20% each, so there is no dependence on one channel.
 3. Loyalty tiers spend almost the same. Each tier contributes roughly 24% to 26% of revenue, which suggests the program isn't changing spending behavior yet.
 4. Revenue is spread evenly across product categories, with no single category dominating.
 5. Many store-product combinations sit below their reorder level, some by more than 100 units.

Because the data is synthetic, the distributions are flatter than real data would be. On a real dataset I would expect to find outliers where this one shows balance.

## Recommendations
1. Restock the items with the largest gaps below reorder level first.
2. Rework the loyalty program with tier-specific rewards, since the current tiers don't separate spending.
3. Focus promotions and supply planning on non-prescription products, which drive most of the revenue.
4. Judge regions on revenue per store, not total revenue, since regions differ in store count.

## Technical Decisions Worth Noting

**Every view is built at one grain** My first version of the stores view joined store-level revenue to a top-5-products table. 
Each store appeared five times, and the dashboard reported 2.67B instead of 534.95M. 
I split it into two views, one row per store and one row per store-product, and related them one-to-many in Power BI. 
The same fix applied to the sales view, where monthly totals were repeated across payment-method rows.

**Aggregates are computed before joining** When joining a parent table (customers) to a child table (sales), averaging a parent column after the join weights it by purchase count. I aggregate sales per customer first, then join.

**Reconciliation before publishing** I checked every dashboard total against the matching SQL result. 
That check caught the duplicated revenue, an incorrect aggregation on a card, and a text typed month column that broke the chart's sort order.

## View and Grain 
vw_sales_monthly : One row per month 
vw_sales_dashboard : Month, payment method and prescription flag 
vw_stores_dashboard : One row per store 
vw_store_top_products : Top 5 products per store 
vw_customer_dashboard : One row per customer 
vw_employee_performance : One row per employee per store 

Data Model
Source tables: sales, products, categories, suppliers, stores, employees, customer loyalty and stock.
