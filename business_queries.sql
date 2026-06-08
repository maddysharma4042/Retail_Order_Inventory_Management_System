SELECT * FROM Products;

SELECT * FROM Orders;

SELECT
    c.first_name,
    c.last_name,
    o.order_id,
    o.total_amount
FROM Customers c
JOIN Orders o
ON c.customer_id = o.customer_id;

SELECT
    p.product_name,
    SUM(oi.quantity) AS TotalSold
FROM Products p
JOIN Order_Items oi
ON p.product_id = oi.product_id
GROUP BY p.product_name
ORDER BY TotalSold DESC;