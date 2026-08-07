-- Create Schema Audit
CREATE SCHEMA audit;
GO

-- Create Audit Table
CREATE TABLE audit.pipeline_logs (
    proc_name VARCHAR(100),
    status VARCHAR(20),
    start_time DATETIME2(6),
    end_time DATETIME2(6),
    rows_affected INT,
    error_message VARCHAR(MAX)
);
GO