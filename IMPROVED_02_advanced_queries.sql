/* =========================================
   ADVANCED BUSINESS QUERIES & ANALYTICS
   ========================================= */

USE RetailDB;
GO

-- =====================================================
-- 1. CUSTOMER PURCHASE ANALYSIS (RFM Analysis)
-- =====================================================
PRINT '========== CUSTOMER PURCHASE ANALYSIS ==========';
GO

SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    c.city,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(o.final_amount) AS total_revenue,
    AVG(o.final_amount) AS avg_order_value,
    MAX(o.order_date) AS last_purchase,
    DATEDIFF(DAY, MAX(o.order_date), GETDATE()) AS days_since_purchase,
    CASE 
        WHEN DATEDIFF(DAY, MAX(o.order_date), GETDATE()) <= 30 THEN 'Active'
        WHEN DATEDIFF(DAY, MAX(o.order_date), GETDATE()) <= 90 THEN 'At Risk'
        ELSE 'Inactive'
    END AS customer_status
FROM Customers c
LEFT JOIN Orders o ON c.customer_id = o.customer_id AND o.order_status != 'CANCELLED'
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.city
ORDER BY total_revenue DESC;

GO

-- =====================================================
-- 2. TOP SELLING PRODUCTS WITH RANKING
-- =====================================================
PRINT '========== TOP SELLING PRODUCTS ==========';
GO

WITH ProductSales AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.sku,
        c.category_name,
        SUM(oi.quantity) AS total_quantity_sold,
        SUM(oi.line_total) AS total_revenue,
        COUNT(DISTINCT oi.order_id) AS number_of_orders,
        AVG(oi.unit_price) AS avg_selling_price
    FROM Products p
    JOIN Categories c ON p.category_id = c.category_id
    LEFT JOIN Order_Items oi ON p.product_id = oi.product_id
    LEFT JOIN Orders o ON oi.order_id = o.order_id AND o.order_status != 'CANCELLED'
    GROUP BY p.product_id, p.product_name, p.sku, c.category_name
),
ProductRanking AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        RANK() OVER (PARTITION BY category_name ORDER BY total_quantity_sold DESC) AS category_rank
    FROM ProductSales
)
SELECT 
    revenue_rank,
    product_id,
    product_name,
    sku,
    category_name,
    total_quantity_sold,
    total_revenue,
    number_of_orders,
    avg_selling_price,
    category_rank
FROM ProductRanking
WHERE revenue_rank <= 10
ORDER BY revenue_rank;

GO

-- =====================================================
-- 3. INVENTORY HEALTH CHECK & LOW STOCK ALERTS
-- =====================================================
PRINT '========== INVENTORY STATUS REPORT ==========';
GO

SELECT 
    p.product_id,
    p.product_name,
    p.sku,
    p.stock_quantity,
    p.reorder_level,
    c.category_name,
    s.supplier_name,
    p.price,
    (p.stock_quantity * p.price) AS inventory_value,
    CASE 
        WHEN p.stock_quantity <= 0 THEN 'OUT_OF_STOCK'
        WHEN p.stock_quantity < p.reorder_level THEN 'CRITICAL'
        WHEN p.stock_quantity < (p.reorder_level * 2) THEN 'LOW'
        ELSE 'GOOD'
    END AS stock_status,
    DATEDIFF(DAY, p.last_restocked, GETDATE()) AS days_since_restock
FROM Products p
JOIN Categories c ON p.category_id = c.category_id
JOIN Suppliers s ON p.supplier_id = s.supplier_id
WHERE p.is_active = 1
ORDER BY stock_status DESC, p.stock_quantity ASC;

GO

-- =====================================================
-- 4. ORDER FULFILLMENT PERFORMANCE
-- =====================================================
PRINT '========== ORDER FULFILLMENT METRICS ==========';
GO

WITH OrderMetrics AS (
    SELECT 
        o.order_id,
        o.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        o.order_date,
        o.required_date,
        o.shipped_date,
        o.order_status,
        COUNT(oi.order_item_id) AS items_count,
        o.final_amount AS order_value,
        DATEDIFF(DAY, o.order_date, GETDATE()) AS days_active,
        CASE 
            WHEN o.shipped_date IS NULL THEN DATEDIFF(DAY, o.order_date, GETDATE())
            ELSE DATEDIFF(DAY, o.order_date, o.shipped_date)
        END AS days_to_fulfill
    FROM Orders o
    JOIN Customers c ON o.customer_id = c.customer_id
    LEFT JOIN Order_Items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.customer_id, c.first_name, c.last_name, 
             o.order_date, o.required_date, o.shipped_date, o.order_status, o.final_amount
)
SELECT 
    order_id,
    customer_name,
    order_date,
    required_date,
    shipped_date,
    order_status,
    items_count,
    order_value,
    days_to_fulfill,
    CASE 
        WHEN shipped_date IS NULL AND order_status = 'PENDING' AND days_active > 3 THEN 'DELAYED'
        WHEN shipped_date IS NOT NULL AND shipped_date > required_date THEN 'LATE'
        WHEN shipped_date IS NOT NULL THEN 'ON_TIME'
        ELSE 'IN_PROGRESS'
    END AS fulfillment_status
FROM OrderMetrics
ORDER BY order_date DESC;

GO

-- =====================================================
-- 5. CATEGORY PERFORMANCE ANALYSIS
-- =====================================================
PRINT '========== CATEGORY PERFORMANCE ==========';
GO

SELECT 
    c.category_id,
    c.category_name,
    COUNT(DISTINCT p.product_id) AS total_products,
    SUM(p.stock_quantity) AS total_stock,
    SUM(p.stock_quantity * p.price) AS inventory_value,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(oi.line_total), 2) AS category_revenue,
    ROUND(AVG(oi.unit_price), 2) AS avg_product_price,
    COUNT(DISTINCT o.customer_id) AS unique_customers
FROM Categories c
LEFT JOIN Products p ON c.category_id = p.category_id
LEFT JOIN Order_Items oi ON p.product_id = oi.product_id
LEFT JOIN Orders o ON oi.order_id = o.order_id AND o.order_status != 'CANCELLED'
GROUP BY c.category_id, c.category_name
ORDER BY category_revenue DESC;

GO

-- =====================================================
-- 6. SUPPLIER PERFORMANCE METRICS
-- =====================================================
PRINT '========== SUPPLIER PERFORMANCE ==========';
GO

SELECT 
    s.supplier_id,
    s.supplier_name,
    s.city,
    s.phone,
    COUNT(DISTINCT p.product_id) AS products_supplied,
    SUM(p.stock_quantity * p.price) AS current_inventory_value,
    SUM(po.total_cost) AS total_purchase_value,
    COUNT(DISTINCT po.purchase_id) AS total_purchases,
    COUNT(DISTINCT CASE WHEN po.status = 'RECEIVED' THEN po.purchase_id END) AS received_orders,
    ROUND(COUNT(DISTINCT CASE WHEN po.status = 'RECEIVED' THEN po.purchase_id END) * 100.0 / 
        NULLIF(COUNT(DISTINCT po.purchase_id), 0), 2) AS delivery_success_rate
FROM Suppliers s
LEFT JOIN Products p ON s.supplier_id = p.supplier_id
LEFT JOIN Purchase_Orders po ON s.supplier_id = po.supplier_id
GROUP BY s.supplier_id, s.supplier_name, s.city, s.phone
ORDER BY delivery_success_rate DESC;

GO

-- =====================================================
-- 7. MONTHLY SALES TREND WITH GROWTH RATE
-- =====================================================
PRINT '========== MONTHLY SALES TREND ==========';
GO

WITH MonthlySales AS (
    SELECT 
        CONVERT(VARCHAR(7), o.order_date, 120) AS month_year,
        COUNT(DISTINCT o.order_id) AS orders,
        SUM(o.final_amount) AS revenue,
        COUNT(DISTINCT o.customer_id) AS unique_customers
    FROM Orders o
    WHERE o.order_status != 'CANCELLED'
    GROUP BY CONVERT(VARCHAR(7), o.order_date, 120)
),
SalesWithGrowth AS (
    SELECT 
        month_year,
        orders,
        revenue,
        unique_customers,
        LAG(revenue) OVER (ORDER BY month_year) AS prev_month_revenue,
        ROUND((revenue - LAG(revenue) OVER (ORDER BY month_year)) * 100.0 / 
            NULLIF(LAG(revenue) OVER (ORDER BY month_year), 0), 2) AS growth_rate_percent
    FROM MonthlySales
)
SELECT 
    month_year,
    orders,
    ROUND(revenue, 2) AS revenue,
    unique_customers,
    CASE 
        WHEN growth_rate_percent IS NULL THEN 'First Month'
        WHEN growth_rate_percent > 0 THEN CONCAT('+', CAST(growth_rate_percent AS VARCHAR(10)), '%')
        ELSE CONCAT(CAST(growth_rate_percent AS VARCHAR(10)), '%')
    END AS growth_rate
FROM SalesWithGrowth
ORDER BY month_year DESC;

GO

-- =====================================================
-- 8. CUSTOMER SEGMENTATION (RFM Score)
-- =====================================================
PRINT '========== CUSTOMER SEGMENTATION ==========';
GO

WITH CustomerSegments AS (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.email,
        c.city,
        COUNT(DISTINCT o.order_id) AS purchase_frequency,
        SUM(o.final_amount) AS lifetime_value,
        AVG(o.final_amount) AS avg_order_value,
        MAX(o.order_date) AS last_order_date,
        DATEDIFF(DAY, MAX(o.order_date), GETDATE()) AS recency_days
    FROM Customers c
    LEFT JOIN Orders o ON c.customer_id = o.customer_id AND o.order_status != 'CANCELLED'
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.city
)
SELECT 
    customer_id,
    customer_name,
    email,
    city,
    purchase_frequency,
    lifetime_value,
    avg_order_value,
    recency_days,
    CASE 
        WHEN purchase_frequency >= 3 AND lifetime_value >= 50000 THEN 'VIP_CUSTOMER'
        WHEN purchase_frequency >= 2 AND lifetime_value >= 20000 THEN 'LOYAL_CUSTOMER'
        WHEN purchase_frequency >= 1 AND lifetime_value >= 10000 THEN 'REGULAR_CUSTOMER'
        WHEN purchase_frequency = 0 THEN 'NO_PURCHASES'
        ELSE 'OCCASIONAL_CUSTOMER'
    END AS customer_segment
FROM CustomerSegments
WHERE purchase_frequency > 0
ORDER BY lifetime_value DESC;

GO

-- =====================================================
-- 9. SALES DASHBOARD SUMMARY
-- =====================================================
PRINT '========== SALES DASHBOARD SUMMARY ==========';
GO

SELECT 'Total Revenue' AS metric, CAST(SUM(final_amount) AS VARCHAR(20)) AS value, '₹' AS currency
FROM Orders WHERE order_status != 'CANCELLED'
UNION ALL
SELECT 'Total Orders', CAST(COUNT(*) AS VARCHAR(20)), ''
FROM Orders WHERE order_status != 'CANCELLED'
UNION ALL
SELECT 'Total Customers', CAST(COUNT(*) AS VARCHAR(20)), ''
FROM Customers WHERE customer_id IN (SELECT DISTINCT customer_id FROM Orders)
UNION ALL
SELECT 'Average Order Value', CAST(ROUND(AVG(final_amount), 2) AS VARCHAR(20)), '₹'
FROM Orders WHERE order_status != 'CANCELLED'
UNION ALL
SELECT 'Total Products', CAST(COUNT(*) AS VARCHAR(20)), ''
FROM Products WHERE is_active = 1
UNION ALL
SELECT 'Low Stock Products', CAST(COUNT(*) AS VARCHAR(20)), ''
FROM Products WHERE stock_quantity < reorder_level AND is_active = 1;

GO

-- =====================================================
-- 10. INVENTORY MOVEMENT ANALYSIS
-- =====================================================
PRINT '========== INVENTORY MOVEMENT ANALYSIS ==========';
GO

WITH InventoryFlow AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.sku,
        SUM(oi.quantity) AS total_sold,
        SUM(pi.quantity) AS total_purchased,
        p.stock_quantity AS current_stock,
        (SUM(pi.quantity) - SUM(oi.quantity)) AS net_flow
    FROM Products p
    LEFT JOIN Order_Items oi ON p.product_id = oi.product_id
    LEFT JOIN Purchase_Items pi ON p.product_id = pi.product_id
    GROUP BY p.product_id, p.product_name, p.sku, p.stock_quantity
)
SELECT 
    product_id,
    product_name,
    sku,
    ISNULL(total_sold, 0) AS total_sold,
    ISNULL(total_purchased, 0) AS total_purchased,
    current_stock,
    ISNULL(net_flow, 0) AS net_flow,
    CASE 
        WHEN ISNULL(total_sold, 0) = 0 THEN 'NO_SALES'
        WHEN ISNULL(total_sold, 0) > 50 THEN 'HIGH_DEMAND'
        WHEN ISNULL(total_sold, 0) > 10 THEN 'MEDIUM_DEMAND'
        ELSE 'LOW_DEMAND'
    END AS demand_level
FROM InventoryFlow
ORDER BY total_sold DESC;

GO

PRINT '✓ All advanced queries executed successfully!';
GO
