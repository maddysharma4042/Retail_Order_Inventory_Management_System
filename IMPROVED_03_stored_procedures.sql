/* =========================================
   STORED PROCEDURES & BUSINESS LOGIC
   ========================================= */

USE RetailDB;
GO

-- =====================================================
-- 1. CREATE NEW ORDER PROCEDURE
-- =====================================================
CREATE PROCEDURE sp_create_order
    @customer_id INT,
    @required_date DATETIME,
    @discount_pct DECIMAL(5,2) = 0,
    @notes NVARCHAR(500) = NULL,
    @order_id INT OUTPUT,
    @error_message NVARCHAR(500) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate customer exists
        IF NOT EXISTS (SELECT 1 FROM Customers WHERE customer_id = @customer_id)
        BEGIN
            RAISERROR('Invalid customer ID', 16, 1);
        END
        
        -- Create new order
        INSERT INTO Orders (customer_id, order_date, required_date, order_status, total_amount, discount_pct, notes)
        VALUES (@customer_id, GETDATE(), @required_date, 'PENDING', 0, @discount_pct, @notes);
        
        SET @order_id = SCOPE_IDENTITY();
        
        -- Update customer stats
        UPDATE Customers 
        SET last_order_date = GETDATE() 
        WHERE customer_id = @customer_id;
        
        COMMIT TRANSACTION;
        SET @error_message = 'Order created successfully';
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
        SET @order_id = -1;
    END CATCH
END;
GO

-- =====================================================
-- 2. ADD ITEM TO ORDER PROCEDURE
-- =====================================================
CREATE PROCEDURE sp_add_order_item
    @order_id INT,
    @product_id INT,
    @quantity INT,
    @error_message NVARCHAR(500) OUTPUT
AS
BEGIN
    BEGIN TRY
        DECLARE @unit_price DECIMAL(10,2);
        DECLARE @current_stock INT;
        DECLARE @order_total DECIMAL(12,2);
        
        -- Validate quantity
        IF @quantity <= 0
            RAISERROR('Quantity must be greater than 0', 16, 1);
        
        -- Get product price and stock
        SELECT @unit_price = price, @current_stock = stock_quantity
        FROM Products
        WHERE product_id = @product_id;
        
        IF @unit_price IS NULL
            RAISERROR('Product not found', 16, 1);
        
        IF @current_stock < @quantity
            RAISERROR('Insufficient stock available', 16, 1);
        
        BEGIN TRANSACTION;
        
        -- Insert order item
        INSERT INTO Order_Items (order_id, product_id, quantity, unit_price, line_total)
        VALUES (@order_id, @product_id, @quantity, @unit_price, @quantity * @unit_price);
        
        -- Update stock
        UPDATE Products
        SET stock_quantity = stock_quantity - @quantity
        WHERE product_id = @product_id;
        
        -- Log transaction
        INSERT INTO Inventory_Transactions (product_id, transaction_type, quantity_changed, reference_id, notes)
        VALUES (@product_id, 'OUT', @quantity, @order_id, CONCAT('Sold in Order #', @order_id));
        
        -- Recalculate order total
        SELECT @order_total = SUM(line_total)
        FROM Order_Items
        WHERE order_id = @order_id;
        
        UPDATE Orders
        SET total_amount = @order_total,
            final_amount = @order_total - (@order_total * discount_pct / 100)
        WHERE order_id = @order_id;
        
        COMMIT TRANSACTION;
        SET @error_message = 'Item added to order successfully';
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
    END CATCH
END;
GO

-- =====================================================
-- 3. UPDATE ORDER STATUS PROCEDURE
-- =====================================================
CREATE PROCEDURE sp_update_order_status
    @order_id INT,
    @new_status VARCHAR(20),
    @error_message NVARCHAR(500) OUTPUT
AS
BEGIN
    BEGIN TRY
        DECLARE @current_status VARCHAR(20);
        
        -- Validate status
        IF @new_status NOT IN ('PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'RETURNED')
            RAISERROR('Invalid order status', 16, 1);
        
        SELECT @current_status = order_status
        FROM Orders
        WHERE order_id = @order_id;
        
        IF @current_status IS NULL
            RAISERROR('Order not found', 16, 1);
        
        -- Prevent status downgrade
        IF @current_status = 'DELIVERED' AND @new_status != 'DELIVERED'
            RAISERROR('Cannot change status of delivered order', 16, 1);
        
        BEGIN TRANSACTION;
        
        UPDATE Orders
        SET order_status = @new_status,
            shipped_date = CASE WHEN @new_status IN ('SHIPPED', 'DELIVERED') THEN GETDATE() ELSE shipped_date END
        WHERE order_id = @order_id;
        
        COMMIT TRANSACTION;
        SET @error_message = CONCAT('Order status updated to ', @new_status);
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
    END CATCH
END;
GO

-- =====================================================
-- 4. RESTOCK PRODUCT PROCEDURE
-- =====================================================
CREATE PROCEDURE sp_restock_product
    @product_id INT,
    @quantity INT,
    @error_message NVARCHAR(500) OUTPUT
AS
BEGIN
    BEGIN TRY
        DECLARE @product_name VARCHAR(150);
        
        IF @quantity <= 0
            RAISERROR('Restock quantity must be positive', 16, 1);
        
        SELECT @product_name = product_name
        FROM Products
        WHERE product_id = @product_id;
        
        IF @product_name IS NULL
            RAISERROR('Product not found', 16, 1);
        
        BEGIN TRANSACTION;
        
        -- Update stock
        UPDATE Products
        SET stock_quantity = stock_quantity + @quantity,
            last_restocked = GETDATE()
        WHERE product_id = @product_id;
        
        -- Log transaction
        INSERT INTO Inventory_Transactions (product_id, transaction_type, quantity_changed, notes)
        VALUES (@product_id, 'IN', @quantity, CONCAT('Restocked - ', @quantity, ' units added'));
        
        COMMIT TRANSACTION;
        SET @error_message = CONCAT('Product restocked: ', @product_name, ' (+', @quantity, ' units)');
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
    END CATCH
END;
GO

-- =====================================================
-- 5. GET CUSTOMER ORDER HISTORY
-- =====================================================
CREATE PROCEDURE sp_get_customer_orders
    @customer_id INT
AS
BEGIN
    SELECT 
        o.order_id,
        o.order_date,
        o.order_status,
        o.total_amount,
        o.discount_pct,
        o.final_amount,
        COUNT(oi.order_item_id) AS items_count,
        DATEDIFF(DAY, o.order_date, GETDATE()) AS days_ago
    FROM Orders o
    LEFT JOIN Order_Items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = @customer_id
    GROUP BY o.order_id, o.order_date, o.order_status, o.total_amount, o.discount_pct, o.final_amount
    ORDER BY o.order_date DESC;
END;
GO

-- =====================================================
-- 6. GET LOW STOCK ALERTS
-- =====================================================
CREATE PROCEDURE sp_get_low_stock_alerts
    @alert_count INT OUTPUT
AS
BEGIN
    SELECT 
        p.product_id,
        p.product_name,
        p.sku,
        p.stock_quantity,
        p.reorder_level,
        s.supplier_name,
        s.contact_email,
        s.phone
    FROM Products p
    JOIN Suppliers s ON p.supplier_id = s.supplier_id
    WHERE p.stock_quantity < p.reorder_level
    AND p.is_active = 1
    ORDER BY p.stock_quantity ASC;
    
    SET @alert_count = @@ROWCOUNT;
END;
GO

-- =====================================================
-- 7. CALCULATE CUSTOMER LIFETIME VALUE
-- =====================================================
CREATE PROCEDURE sp_get_customer_lifetime_value
    @customer_id INT,
    @total_spent DECIMAL(12,2) OUTPUT,
    @order_count INT OUTPUT,
    @avg_order_value DECIMAL(12,2) OUTPUT
AS
BEGIN
    SELECT 
        @total_spent = ISNULL(SUM(final_amount), 0),
        @order_count = COUNT(*),
        @avg_order_value = ISNULL(AVG(final_amount), 0)
    FROM Orders
    WHERE customer_id = @customer_id
    AND order_status != 'CANCELLED';
END;
GO

-- =====================================================
-- 8. CANCEL ORDER WITH STOCK RESTORATION
-- =====================================================
CREATE PROCEDURE sp_cancel_order
    @order_id INT,
    @error_message NVARCHAR(500) OUTPUT
AS
BEGIN
    BEGIN TRY
        DECLARE @order_status VARCHAR(20);
        
        SELECT @order_status = order_status FROM Orders WHERE order_id = @order_id;
        
        IF @order_status IS NULL
            RAISERROR('Order not found', 16, 1);
        
        IF @order_status NOT IN ('PENDING', 'PROCESSING', 'SHIPPED')
            RAISERROR('Only PENDING/PROCESSING/SHIPPED orders can be cancelled', 16, 1);
        
        BEGIN TRANSACTION;
        
        -- Restore stock
        INSERT INTO Inventory_Transactions (product_id, transaction_type, quantity_changed, reference_id, notes)
        SELECT product_id, 'RETURN', quantity, @order_id, CONCAT('Returned from cancelled Order #', @order_id)
        FROM Order_Items
        WHERE order_id = @order_id;
        
        UPDATE Products
        SET stock_quantity = stock_quantity + oi.quantity
        FROM Products p
        JOIN Order_Items oi ON p.product_id = oi.product_id
        WHERE oi.order_id = @order_id;
        
        -- Update order status
        UPDATE Orders
        SET order_status = 'CANCELLED'
        WHERE order_id = @order_id;
        
        COMMIT TRANSACTION;
        SET @error_message = 'Order cancelled and inventory restored successfully';
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
    END CATCH
END;
GO

-- =====================================================
-- 9. GET CATEGORY SALES PERFORMANCE
-- =====================================================
CREATE PROCEDURE sp_get_category_performance
    @category_id INT = NULL
AS
BEGIN
    SELECT 
        c.category_id,
        c.category_name,
        COUNT(DISTINCT p.product_id) AS total_products,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.quantity) AS total_units_sold,
        ROUND(SUM(oi.line_total), 2) AS total_revenue,
        ROUND(AVG(oi.unit_price), 2) AS avg_product_price,
        COUNT(DISTINCT o.customer_id) AS unique_customers
    FROM Categories c
    LEFT JOIN Products p ON c.category_id = p.category_id
    LEFT JOIN Order_Items oi ON p.product_id = oi.product_id
    LEFT JOIN Orders o ON oi.order_id = o.order_id AND o.order_status != 'CANCELLED'
    WHERE (@category_id IS NULL OR c.category_id = @category_id)
    GROUP BY c.category_id, c.category_name
    ORDER BY total_revenue DESC;
END;
GO

-- =====================================================
-- 10. BULK UPDATE PRODUCT PRICES
-- =====================================================
CREATE PROCEDURE sp_update_product_prices
    @category_id INT,
    @percentage_change DECIMAL(5,2),
    @error_message NVARCHAR(500) OUTPUT
AS
BEGIN
    BEGIN TRY
        DECLARE @updated_count INT;
        
        IF ABS(@percentage_change) > 50
            RAISERROR('Price change cannot exceed 50%', 16, 1);
        
        BEGIN TRANSACTION;
        
        UPDATE Products
        SET price = price * (1 + @percentage_change / 100)
        WHERE category_id = @category_id
        AND is_active = 1;
        
        SET @updated_count = @@ROWCOUNT;
        
        COMMIT TRANSACTION;
        SET @error_message = CONCAT('Updated prices for ', @updated_count, ' products');
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @error_message = ERROR_MESSAGE();
    END CATCH
END;
GO

PRINT '✓ All stored procedures created successfully!';
GO
