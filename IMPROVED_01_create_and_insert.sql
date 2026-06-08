/* =========================================
   RETAIL & E-COMMERCE DATABASE SYSTEM
   Enhanced Version with Professional Features
   ========================================= */

-- Drop database if exists (fresh start)
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'RetailDB')
DROP DATABASE RetailDB;
GO

CREATE DATABASE RetailDB;
GO

USE RetailDB;
GO

-- ========================
-- 1. CATEGORIES TABLE
-- ========================
CREATE TABLE Categories (
    category_id     INT PRIMARY KEY IDENTITY(1,1),
    category_name   VARCHAR(100) NOT NULL UNIQUE,
    description     VARCHAR(255),
    is_active       BIT DEFAULT 1,
    created_date    DATETIME DEFAULT GETDATE(),
    CONSTRAINT chk_category_name CHECK (LEN(category_name) > 2)
);

-- ========================
-- 2. SUPPLIERS TABLE
-- ========================
CREATE TABLE Suppliers (
    supplier_id     INT PRIMARY KEY IDENTITY(1,1),
    supplier_name   VARCHAR(150) NOT NULL UNIQUE,
    contact_email   VARCHAR(100) NOT NULL UNIQUE,
    city            VARCHAR(100),
    phone           VARCHAR(20) NOT NULL,
    country         VARCHAR(50) DEFAULT 'India',
    is_active       BIT DEFAULT 1,
    created_date    DATETIME DEFAULT GETDATE(),
    CONSTRAINT chk_supplier_email CHECK (contact_email LIKE '%@%.%'),
    CONSTRAINT chk_supplier_phone CHECK (LEN(phone) >= 10)
);

-- ========================
-- 3. CUSTOMERS TABLE
-- ========================
CREATE TABLE Customers (
    customer_id         INT PRIMARY KEY IDENTITY(1,1),
    first_name          VARCHAR(50) NOT NULL,
    last_name           VARCHAR(50) NOT NULL,
    email               VARCHAR(100) NOT NULL UNIQUE,
    phone               VARCHAR(20),
    city                VARCHAR(100),
    state               VARCHAR(50),
    pincode             VARCHAR(10),
    registration_date   DATETIME DEFAULT GETDATE(),
    last_order_date     DATETIME NULL,
    total_spent         DECIMAL(12,2) DEFAULT 0,
    is_active           BIT DEFAULT 1,
    CONSTRAINT chk_customer_email CHECK (email LIKE '%@%.%'),
    CONSTRAINT chk_customer_phone CHECK (LEN(phone) >= 10)
);

-- ========================
-- 4. PRODUCTS TABLE
-- ========================
CREATE TABLE Products (
    product_id      INT PRIMARY KEY IDENTITY(1,1),
    product_name    VARCHAR(150) NOT NULL,
    category_id     INT NOT NULL,
    supplier_id     INT NOT NULL,
    price           DECIMAL(10,2) NOT NULL,
    stock_quantity  INT DEFAULT 0,
    reorder_level   INT DEFAULT 10,
    sku             VARCHAR(50) UNIQUE NOT NULL,
    description     VARCHAR(500),
    is_active       BIT DEFAULT 1,
    created_date    DATETIME DEFAULT GETDATE(),
    last_restocked  DATETIME NULL,
    CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES Categories(category_id),
    CONSTRAINT fk_products_supplier FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id),
    CONSTRAINT chk_product_price CHECK (price > 0),
    CONSTRAINT chk_product_stock CHECK (stock_quantity >= 0)
);

-- ========================
-- 5. ORDERS TABLE
-- ========================
CREATE TABLE Orders (
    order_id        INT PRIMARY KEY IDENTITY(1,1),
    customer_id     INT NOT NULL,
    order_date      DATETIME DEFAULT GETDATE(),
    required_date   DATETIME,
    shipped_date    DATETIME NULL,
    order_status    VARCHAR(20) DEFAULT 'PENDING',
    total_amount    DECIMAL(12,2) NOT NULL,
    discount_pct    DECIMAL(5,2) DEFAULT 0,
    final_amount    DECIMAL(12,2),
    notes           VARCHAR(500),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES Customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT chk_order_status CHECK (order_status IN ('PENDING','PROCESSING','SHIPPED','DELIVERED','CANCELLED','RETURNED')),
    CONSTRAINT chk_order_amount CHECK (total_amount > 0)
);

-- ========================
-- 6. ORDER ITEMS TABLE
-- ========================
CREATE TABLE Order_Items (
    order_item_id   INT PRIMARY KEY IDENTITY(1,1),
    order_id        INT NOT NULL,
    product_id      INT NOT NULL,
    quantity        INT NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,
    line_total      DECIMAL(12,2),
    CONSTRAINT fk_orderitems_order FOREIGN KEY (order_id) REFERENCES Orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_orderitems_product FOREIGN KEY (product_id) REFERENCES Products(product_id),
    CONSTRAINT chk_orderitem_qty CHECK (quantity > 0)
);

-- ========================
-- 7. PURCHASE ORDERS TABLE
-- ========================
CREATE TABLE Purchase_Orders (
    purchase_id     INT PRIMARY KEY IDENTITY(1,1),
    supplier_id     INT NOT NULL,
    purchase_date   DATETIME DEFAULT GETDATE(),
    total_cost      DECIMAL(12,2) DEFAULT 0,
    status          VARCHAR(20) CHECK (status IN ('PENDING','ORDERED','RECEIVED','CANCELLED')),
    received_date   DATETIME NULL,
    CONSTRAINT fk_purchase_supplier FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id)
);

-- ========================
-- 8. PURCHASE ITEMS TABLE
-- ========================
CREATE TABLE Purchase_Items (
    purchase_item_id    INT PRIMARY KEY IDENTITY(1,1),
    purchase_id         INT NOT NULL,
    product_id          INT NOT NULL,
    quantity            INT NOT NULL,
    unit_cost           DECIMAL(10,2) NOT NULL,
    line_cost           DECIMAL(12,2),
    CONSTRAINT fk_purchaseitems_purchase FOREIGN KEY (purchase_id) REFERENCES Purchase_Orders(purchase_id) ON DELETE CASCADE,
    CONSTRAINT fk_purchaseitems_product FOREIGN KEY (product_id) REFERENCES Products(product_id),
    CONSTRAINT chk_purchase_qty CHECK (quantity > 0)
);

-- ========================
-- 9. INVENTORY TRANSACTIONS TABLE (NEW)
-- ========================
CREATE TABLE Inventory_Transactions (
    transaction_id      INT PRIMARY KEY IDENTITY(1,1),
    product_id          INT NOT NULL,
    transaction_type    VARCHAR(20) NOT NULL,
    quantity_changed    INT NOT NULL,
    transaction_date    DATETIME DEFAULT GETDATE(),
    reference_id        INT,
    notes               VARCHAR(300),
    CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES Products(product_id),
    CONSTRAINT chk_transaction_type CHECK (transaction_type IN ('IN','OUT','ADJUSTMENT','RETURN'))
);

-- ========================
-- INDEXES FOR PERFORMANCE
-- ========================
CREATE INDEX idx_customers_email ON Customers(email);
CREATE INDEX idx_customers_city ON Customers(city);
CREATE INDEX idx_customers_phone ON Customers(phone);
CREATE INDEX idx_products_category ON Products(category_id);
CREATE INDEX idx_products_supplier ON Products(supplier_id);
CREATE INDEX idx_products_sku ON Products(sku);
CREATE INDEX idx_products_stock ON Products(stock_quantity);
CREATE INDEX idx_orders_customer ON Orders(customer_id);
CREATE INDEX idx_orders_date ON Orders(order_date);
CREATE INDEX idx_orders_status ON Orders(order_status);
CREATE INDEX idx_orderitems_order ON Order_Items(order_id);
CREATE INDEX idx_orderitems_product ON Order_Items(product_id);
CREATE INDEX idx_inventory_product ON Inventory_Transactions(product_id);
CREATE INDEX idx_inventory_date ON Inventory_Transactions(transaction_date);

PRINT '✓ All tables and indexes created successfully!';
GO

-- ========================
-- INSERT SAMPLE DATA
-- ========================

USE RetailDB;
GO

-- Categories
INSERT INTO Categories (category_name, description)
VALUES
    ('Electronics', 'Electronic Devices and Gadgets'),
    ('Clothing', 'Apparel and Fashion Products'),
    ('Home Appliances', 'Household Electrical Appliances'),
    ('Beauty & Personal Care', 'Skincare and Personal Care'),
    ('Books & Media', 'Books, DVDs, and Digital Content');

-- Suppliers
INSERT INTO Suppliers (supplier_name, contact_email, city, phone, country)
VALUES
    ('ABC Electronics Ltd', 'contact@abcelectronics.com', 'Delhi', '9876543210', 'India'),
    ('XYZ Traders', 'xyz.traders@business.com', 'Mumbai', '8765432109', 'India'),
    ('Fashion Hub Supplies', 'fashion@hubjkt.com', 'Bangalore', '7654321098', 'India'),
    ('Home Solutions Co', 'sales@homesolutions.com', 'Hyderabad', '6543210987', 'India'),
    ('Tech Innovation Ltd', 'tech.innovation@email.com', 'Pune', '5432109876', 'India');

-- Customers
INSERT INTO Customers (first_name, last_name, email, phone, city, state, pincode)
VALUES
    ('Manish', 'Sharma', 'manish.sharma@gmail.com', '9999999999', 'Ghaziabad', 'UP', '201001'),
    ('Rahul', 'Kumar', 'rahul.kumar@gmail.com', '8888888888', 'Delhi', 'Delhi', '110001'),
    ('Amit', 'Singh', 'amit.singh@gmail.com', '7777777777', 'Noida', 'UP', '201301'),
    ('Priya', 'Verma', 'priya.verma@gmail.com', '9876543210', 'Bangalore', 'KA', '560001'),
    ('Ananya', 'Gupta', 'ananya.gupta@gmail.com', '8765432109', 'Mumbai', 'MH', '400001'),
    ('Arjun', 'Patel', 'arjun.patel@gmail.com', '7654321098', 'Ahmedabad', 'GJ', '380001'),
    ('Shreya', 'Nair', 'shreya.nair@gmail.com', '9123456789', 'Hyderabad', 'TS', '500001'),
    ('Vikram', 'Reddy', 'vikram.reddy@gmail.com', '8234567890', 'Pune', 'MH', '411001');

-- Products
INSERT INTO Products (product_name, category_id, supplier_id, price, stock_quantity, reorder_level, sku, description)
VALUES
    ('Laptop Pro 15', 1, 1, 75000, 25, 5, 'ELEC-LP-001', '15 inch Laptop with Intel i7, 16GB RAM'),
    ('Smartphone X', 1, 1, 35000, 40, 10, 'ELEC-SP-001', 'Latest smartphone with 5G support'),
    ('Wireless Headphones', 1, 1, 5000, 60, 15, 'ELEC-HP-001', 'Noise-cancelling wireless headphones'),
    ('USB-C Cable', 1, 1, 500, 200, 50, 'ELEC-CB-001', 'High-speed USB-C charging cable'),
    ('Power Bank 20000mAh', 1, 1, 2500, 80, 20, 'ELEC-PB-001', 'Portable power bank with fast charging'),
    ('Premium T-Shirt', 2, 3, 800, 150, 30, 'CLTH-TS-001', '100% Cotton Premium T-Shirt'),
    ('Formal Jeans', 2, 3, 2500, 100, 25, 'CLTH-JN-001', 'Premium Denim Formal Jeans'),
    ('Sports Shoes', 2, 3, 4500, 75, 15, 'CLTH-SH-001', 'Comfortable Sports Running Shoes'),
    ('Winter Jacket', 2, 3, 5500, 50, 10, 'CLTH-JK-001', 'Warm Winter Jacket with Wool Lining'),
    ('Microwave Oven', 3, 4, 12000, 20, 5, 'HOME-MW-001', 'Digital Microwave Oven 25L'),
    ('Refrigerator', 3, 4, 45000, 15, 3, 'HOME-RF-001', 'Double Door Frost Free Refrigerator'),
    ('Air Conditioner', 3, 4, 55000, 10, 2, 'HOME-AC-001', '1.5 Ton Split Air Conditioner');

-- Orders with realistic data
INSERT INTO Orders (customer_id, order_date, required_date, shipped_date, order_status, total_amount, discount_pct, notes)
VALUES
    (1, DATEADD(DAY, -15, GETDATE()), DATEADD(DAY, -10, GETDATE()), DATEADD(DAY, -10, GETDATE()), 'DELIVERED', 80000, 5, 'Standard delivery'),
    (2, DATEADD(DAY, -8, GETDATE()), DATEADD(DAY, -3, GETDATE()), DATEADD(DAY, -3, GETDATE()), 'DELIVERED', 5000, 0, 'Express delivery'),
    (3, DATEADD(DAY, -5, GETDATE()), GETDATE(), NULL, 'SHIPPED', 10500, 0, 'In transit'),
    (4, DATEADD(DAY, -2, GETDATE()), DATEADD(DAY, 3, GETDATE()), NULL, 'PENDING', 7300, 10, 'Awaiting pickup'),
    (5, DATEADD(DAY, -20, GETDATE()), DATEADD(DAY, -15, GETDATE()), DATEADD(DAY, -15, GETDATE()), 'DELIVERED', 82500, 0, 'High-value order'),
    (1, DATEADD(DAY, -10, GETDATE()), DATEADD(DAY, -5, GETDATE()), DATEADD(DAY, -5, GETDATE()), 'DELIVERED', 12000, 0, 'Appliance purchase'),
    (6, DATEADD(DAY, -3, GETDATE()), DATEADD(DAY, 2, GETDATE()), NULL, 'PENDING', 4500, 0, 'Shoes and apparel'),
    (7, DATEADD(DAY, -1, GETDATE()), DATEADD(DAY, 4, GETDATE()), NULL, 'PENDING', 3000, 15, 'Promotional discount');

-- Order Items
INSERT INTO Order_Items (order_id, product_id, quantity, unit_price, line_total)
VALUES
    (1, 1, 1, 75000, 75000), (1, 3, 1, 5000, 5000),
    (2, 5, 2, 2500, 5000),
    (3, 6, 3, 800, 2400), (3, 8, 1, 4500, 4500),
    (4, 9, 1, 5500, 5500), (4, 4, 2, 500, 1000), (4, 3, 1, 5000, 5000),
    (5, 2, 1, 35000, 35000), (5, 10, 1, 12000, 12000), (5, 5, 3, 2500, 7500),
    (6, 10, 1, 12000, 12000),
    (7, 8, 1, 4500, 4500),
    (8, 6, 4, 800, 3200);

-- Update final amounts
UPDATE Orders
SET final_amount = total_amount - (total_amount * discount_pct / 100)
WHERE final_amount IS NULL;

-- Update customer stats
UPDATE Customers
SET total_spent = (
    SELECT ISNULL(SUM(final_amount), 0)
    FROM Orders
    WHERE customer_id = Customers.customer_id
)
WHERE customer_id IN (SELECT DISTINCT customer_id FROM Orders);

UPDATE Customers
SET last_order_date = (
    SELECT MAX(order_date)
    FROM Orders o
    WHERE o.customer_id = Customers.customer_id
)
WHERE customer_id IN (SELECT DISTINCT customer_id FROM Orders);

-- Purchase Orders
INSERT INTO Purchase_Orders (supplier_id, purchase_date, total_cost, status, received_date)
VALUES
    (1, DATEADD(DAY, -20, GETDATE()), 0, 'RECEIVED', DATEADD(DAY, -18, GETDATE())),
    (2, DATEADD(DAY, -10, GETDATE()), 0, 'RECEIVED', DATEADD(DAY, -8, GETDATE())),
    (3, DATEADD(DAY, -5, GETDATE()), 0, 'PENDING', NULL),
    (4, DATEADD(DAY, -2, GETDATE()), 0, 'PENDING', NULL);

-- Purchase Items
INSERT INTO Purchase_Items (purchase_id, product_id, quantity, unit_cost, line_cost)
VALUES
    (1, 1, 12, 50000, 600000), (1, 2, 8, 25000, 200000),
    (2, 6, 30, 400, 12000), (2, 7, 15, 1200, 18000),
    (3, 10, 10, 8000, 80000),
    (4, 11, 5, 35000, 175000);

-- Update purchase totals
UPDATE Purchase_Orders
SET total_cost = (
    SELECT SUM(line_cost)
    FROM Purchase_Items
    WHERE purchase_id = Purchase_Orders.purchase_id
);

PRINT '✓ Sample data inserted successfully!';
GO
