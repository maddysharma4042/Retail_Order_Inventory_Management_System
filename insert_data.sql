USE RetailDB;
GO

INSERT INTO Categories VALUES
(1,'Electronics','Electronic Products'),
(2,'Clothing','Fashion Products'),
(3,'Home Appliances','Household Products');

INSERT INTO Customers VALUES
(1,'Manish','Sharma','manish@gmail.com','9999999999','Ghaziabad',GETDATE()),
(2,'Rahul','Kumar','rahul@gmail.com','8888888888','Delhi',GETDATE()),
(3,'Amit','Singh','amit@gmail.com','7777777777','Noida',GETDATE());

INSERT INTO Suppliers VALUES
(1,'ABC Electronics','abc@gmail.com','Delhi','9876543210'),
(2,'XYZ Traders','xyz@gmail.com','Noida','8765432109');

INSERT INTO Products VALUES
(1,'Laptop',1,50000,25,1,GETDATE()),
(2,'Smartphone',1,25000,30,1,GETDATE()),
(3,'Headphones',1,3000,50,1,GETDATE()),
(4,'T-Shirt',2,500,100,1,GETDATE()),
(5,'Jeans',2,1500,80,1,GETDATE()),
(6,'Microwave',3,12000,15,1,GETDATE()),
(7,'Refrigerator',3,35000,10,1,GETDATE()),
(8,'Air Conditioner',3,45000,5,1,GETDATE()),
(9,'Keyboard',1,1200,40,1,GETDATE()),
(10,'Mouse',1,800,60,1,GETDATE()),
(11,'Speaker',1,2500,35,1,GETDATE());
GO



INSERT INTO Orders VALUES
(1,1,'DELIVERED',GETDATE(),55000),
(2,2,'SHIPPED',GETDATE(),25000),
(3,3,'PENDING',GETDATE(),3000);
GO

INSERT INTO Order_Items
(order_item_id,order_id,product_id,quantity,unit_price)
VALUES
(1,1,1,1,50000),
(2,1,3,1,3000),
(3,2,2,1,25000),
(4,3,3,1,3000);
GO
