/* =========================================
   DATABASE VIEWS FOR REPORTING
   ========================================= */

USE RetailDB;
GO

-- =====================================================
-- 1. CUSTOMER SUMMARY VIEW
-- =====================================================
CREATE VIEW vw_customer_summary AS
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS full_name,
    c.email,
    c.phone,
    c.city,
    c.state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ISNULL(SUM(o.final_amount), 0) AS lifetime_value,
    ISNULL(AVG(o.final_amount), 0) AS avg_order_value,
    MAX(o.order_date) AS last_purchase_date,
    CASE 
        WHEN MAX(o.order_date) IS NULL THEN 'Never Purchased'
        WHEN DATEDIFF(DAY, MAX(o.order_date), GETDATE()) <= 30 THEN 'Active'
        WHEN DATEDIFF(DAY, MAX(o.order_date), GETDATE()) <= 90 THEN 'At Risk'
        ELSE 'Inactive'
    END AS customer_status
FROM Customers c
LEFT JOIN Orders o ON c.customer_id = o.customer_id AND o.order_status != 'CANCELLED'
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.phone, c.city, c.state;
GO

-- =====================================================
-- 2. PRODUCT INVENTORY VIEW
-- =====================================================
CREATE VIEW vw_product_inventory AS
SELECT 
    p.product_id,
    p.product_name,
    p.sku,
    c.category_name,
    s.supplier_name,
    p.price,
    p.stock_quantity,
    p.reorder_level,
    (p.stock_quantity * p.price) AS inventory_value,
    CASE 
        WHEN p.stock_quantity <= 0 THEN 'OUT_OF_STOCK'
        WHEN p.stock_quantity < p.reorder_level THEN 'LOW_STOCK'
        WHEN p.stock_quantity < (p.reorder_level * 2) THEN 'MEDIUM'
        ELSE 'GOOD_STOCK'
    END AS stock_status,
    p.last_restocked,
    DATEDIFF(DAY, ISNULL(p.last_restocked, p.created_date), GETDATE()) AS days_since_restock,
    p.is_active
FROM Products p
JOIN Categories c ON p.category_id = c.category_id
JOIN Suppliers s ON p.supplier_id = s.supplier_id;
GO

-- =====================================================
-- 3. ORDER DETAILS VIEW
-- =====================================================
CREATE VIEW vw_order_details AS
SELECT 
    o.order_id,
    o.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    c.city,
    o.order_date,
    o.required_date,
    o.shipped_date,
    o.order_status,
    COUNT(oi.order_item_id) AS total_items,
    SUM(oi.quantity) AS total_quantity,
    o.total_amount AS subtotal,
    o.discount_pct,
    o.final_amount,
    CASE 
        WHEN o.shipped_date IS NULL THEN DATEDIFF(DAY, o.order_date, GETDATE())
        ELSE DATEDIFF(DAY, o.order_date, o.shipped_date)
    END AS fulfillment_days
FROM Orders o
JOIN Customers c ON o.customer_id = c.customer_id
LEFT JOIN Order_Items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.customer_id, c.first_name, c.last_name, c.email, c.city,
         o.order_date, o.required_date, o.shipped_date, o.order_status,
         o.total_amount, o.discount_pct, o.final_amount;
GO

-- =====================================================
-- 4. SALES PERFORMANCE BY CATEGORY VIEW
-- =====================================================
CREATE VIEW vw_sales_performance_by_category AS
SELECT 
    CONVERT(VARCHAR(7), o.order_date, 120) AS month_year,
    c.category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS units_sold,
    ISNULL(SUM(oi.line_total), 0) AS revenue,
    ISNULL(AVG(o.final_amount), 0) AS avg_order_value,
    COUNT(DISTINCT o.customer_id) AS unique_customers
FROM Orders o
JOIN Order_Items oi ON o.order_id = oi.order_id
JOIN Products p ON oi.product_id = p.product_id
JOIN Categories c ON p.category_id = c.category_id
WHERE o.order_status != 'CANCELLED'
GROUP BY CONVERT(VARCHAR(7), o.order_date, 120), c.category_name;
GO

-- =====================================================
-- 5. TOP PRODUCTS BY SALES VIEW
-- =====================================================
CREATE VIEW vw_top_products_by_sales AS
SELECT 
    p.product_id,
    p.product_name,
    p.sku,
    c.category_name,
    COUNT(DISTINCT oi.order_id) AS orders_count,
    SUM(oi.quantity) AS total_quantity_sold,
    ROUND(SUM(oi.line_total), 2) AS total_revenue,
    ROUND(AVG(oi.unit_price), 2) AS avg_selling_price,
    p.stock_quantity AS current_stock,
    (p.stock_quantity * p.price) AS inventory_value
FROM Products p
JOIN Categories c ON p.category_id = c.category_id
LEFT JOIN Order_Items oi ON p.product_id = oi.product_id
LEFT JOIN Orders o ON oi.order_id = o.order_id AND o.order_status != 'CANCELLED'
GROUP BY p.product_id, p.product_name, p.sku, c.category_name, p.stock_quantity, p.price;
GO

-- =====================================================
-- 6. SUPPLIER PERFORMANCE VIEW
-- =====================================================
CREATE VIEW vw_supplier_performance AS
SELECT 
    s.supplier_id,
    s.supplier_name,
    s.city,
    s.phone,
    COUNT(DISTINCT p.product_id) AS products_supplied,
    SUM(p.stock_quantity * p.price) AS total_inventory_value,
    SUM(po.total_cost) AS total_purchase_value,
    COUNT(DISTINCT po.purchase_id) AS total_purchases,
    COUNT(DISTINCT CASE WHEN po.status = 'RECEIVED' THEN po.purchase_id END) AS received_orders,
    ROUND(COUNT(DISTINCT CASE WHEN po.status = 'RECEIVED' THEN po.purchase_id END) * 100.0 / 
        NULLIF(COUNT(DISTINCT po.purchase_id), 0), 2) AS delivery_success_rate
FROM Suppliers s
LEFT JOIN Products p ON s.supplier_id = p.supplier_id
LEFT JOIN Purchase_Orders po ON s.supplier_id = po.supplier_id
GROUP BY s.supplier_id, s.supplier_name, s.city, s.phone;
GO

-- =====================================================
-- 7. ORDER FULFILLMENT STATUS VIEW
-- =====================================================
CREATE VIEW vw_order_fulfillment_status AS
SELECT 
    o.order_id,
    o.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    o.order_date,
    o.required_date,
    o.shipped_date,
    o.order_status,
    o.final_amount,
    CASE 
        WHEN o.shipped_date IS NULL THEN DATEDIFF(DAY, o.order_date, GETDATE())
        ELSE DATEDIFF(DAY, o.order_date, o.shipped_date)
    END AS days_to_fulfill,
    CASE 
        WHEN o.shipped_date IS NULL AND o.order_status = 'PENDING' THEN 'Not Started'
        WHEN o.shipped_date IS NULL AND o.order_status = 'PROCESSING' THEN 'Processing'
        WHEN o.shipped_date IS NULL AND o.order_status = 'SHIPPED' THEN 'In Transit'
        WHEN o.shipped_date IS NOT NULL AND o.shipped_date <= o.required_date THEN 'On Time'
        WHEN o.shipped_date IS NOT NULL AND o.shipped_date > o.required_date THEN 'Delayed'
        WHEN o.order_status = 'DELIVERED' THEN 'Completed'
        ELSE 'Unknown'
    END AS fulfillment_status
FROM Orders o
JOIN Customers c ON o.customer_id = c.customer_id;
GO

-- =====================================================
-- 8. CATEGORY PERFORMANCE VIEW
-- =====================================================
CREATE VIEW vw_category_performance AS
SELECT 
    c.category_id,
    c.category_name,
    COUNT(DISTINCT p.product_id) AS total_products,
    SUM(p.stock_quantity) AS total_stock,
    SUM(p.stock_quantity * p.price) AS stock_value,
    COUNT(DISTINCT oi.order_id) AS orders_count,
    SUM(oi.quantity) AS total_quantity_sold,
    ROUND(SUM(oi.line_total), 2) AS category_revenue,
    ROUND(AVG(oi.unit_price), 2) AS avg_product_price,
    COUNT(DISTINCT o.customer_id) AS unique_customers
FROM Categories c
LEFT JOIN Products p ON c.category_id = p.category_id
LEFT JOIN Order_Items oi ON p.product_id = oi.product_id
LEFT JOIN Orders o ON oi.order_id = o.order_id AND o.order_status != 'CANCELLED'
GROUP BY c.category_id, c.category_name;
GO

-- =====================================================
-- 9. CUSTOMER SEGMENTATION VIEW (RFM)
-- =====================================================
CREATE VIEW vw_customer_segmentation_rfm AS
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    c.city,
    COUNT(DISTINCT o.order_id) AS purchase_frequency,
    ISNULL(SUM(o.final_amount), 0) AS lifetime_value,
    ISNULL(AVG(o.final_amount), 0) AS avg_order_value,
    MAX(o.order_date) AS last_purchase,
    DATEDIFF(DAY, MAX(o.order_date), GETDATE()) AS days_since_purchase,
    CASE 
        WHEN COUNT(DISTINCT o.order_id) >= 3 AND SUM(o.final_amount) >= 50000 THEN 'VIP'
        WHEN COUNT(DISTINCT o.order_id) >= 2 AND SUM(o.final_amount) >= 20000 THEN 'Loyal'
        WHEN COUNT(DISTINCT o.order_id) >= 1 THEN 'Regular'
        ELSE 'Prospect'
    END AS customer_segment
FROM Customers c
LEFT JOIN Orders o ON c.customer_id = o.customer_id AND o.order_status != 'CANCELLED'
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.city;
GO

-- =====================================================
-- 10. INVENTORY TRANSACTIONS LOG VIEW
-- =====================================================
CREATE VIEW vw_inventory_transactions_log AS
SELECT 
    it.transaction_id,
    p.product_name,
    p.sku,
    it.transaction_type,
    it.quantity_changed,
    CASE 
        WHEN it.transaction_type IN ('IN', 'RETURN') THEN 'Added'
        WHEN it.transaction_type = 'OUT' THEN 'Removed'
        ELSE 'Adjusted'
    END AS transaction_action,
    it.transaction_date,
    it.reference_id,
    it.notes,
    DATEDIFF(DAY, it.transaction_date, GETDATE()) AS days_ago
FROM Inventory_Transactions it
JOIN Products p ON it.product_id = p.product_id;
GO

-- =====================================================
-- 11. DASHBOARD KPI VIEW
-- =====================================================
CREATE VIEW vw_dashboard_kpi AS
WITH KPIData AS (
    SELECT 
        'Total Revenue' AS metric,
        CAST(ISNULL(SUM(final_amount), 0) AS VARCHAR(20)) AS value,
        'INR' AS unit
    FROM Orders
    WHERE order_status != 'CANCELLED'
    
    UNION ALL
    
    SELECT 'Total Orders', CAST(COUNT(*) AS VARCHAR(20)), ''
    FROM Orders
    WHERE order_status != 'CANCELLED'
    
    UNION ALL
    
    SELECT 'Active Customers', CAST(COUNT(DISTINCT customer_id) AS VARCHAR(20)), ''
    FROM Orders
    WHERE DATEDIFF(DAY, order_date, GETDATE()) <= 30
    
    UNION ALL
    
    SELECT 'Pending Orders', CAST(COUNT(*) AS VARCHAR(20)), ''
    FROM Orders
    WHERE order_status = 'PENDING'
    
    UNION ALL
    
    SELECT 'Low Stock Products', CAST(COUNT(*) AS VARCHAR(20)), ''
    FROM Products
    WHERE stock_quantity < reorder_level AND is_active = 1
    
    UNION ALL
    
    SELECT 'Average Order Value', CAST(ROUND(AVG(final_amount), 0) AS VARCHAR(20)), 'INR'
    FROM Orders
    WHERE order_status != 'CANCELLED'
)
SELECT * FROM KPIData;
GO

PRINT '✓ All views created successfully!';
GO

-- =====================================================
-- VERIFY VIEW CREATION
-- =====================================================
SELECT 
    TABLE_NAME AS view_name
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'dbo'
ORDER BY TABLE_NAME;
GO
