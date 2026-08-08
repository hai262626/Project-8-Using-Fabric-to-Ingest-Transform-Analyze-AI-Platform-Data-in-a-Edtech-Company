DROP TABLE IF EXISTS mart.dim_date;
GO

CREATE TABLE mart.dim_date AS
SELECT * FROM AI_Lakehouse.staging.dim_date;