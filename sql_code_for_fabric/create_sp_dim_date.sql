CREATE OR ALTER PROCEDURE mart.sp_load_dim_date
AS
BEGIN
    SET NOCOUNT ON;

    -- Initialize execution metrics
    DECLARE @start_time DATETIME2 = GETDATE();
    DECLARE @end_time DATETIME2;
    DECLARE @rows_affected INT = 0;
    DECLARE @proc_name VARCHAR(100) = 'mart.sp_load_dim_date';

    BEGIN TRY
        -- Log pipeline start
        INSERT INTO audit.pipeline_logs (proc_name, status, start_time)
        VALUES (@proc_name, 'RUNNING', @start_time);

        -- Core transformation: Full refresh via CTAS
        TRUNCATE TABLE mart.dim_date;

        INSERT INTO mart.dim_date
        SELECT * FROM AI_Lakehouse.staging.dim_date;

        SET @rows_affected = @@ROWCOUNT;
        SET @end_time = GETDATE();

        -- Log pipeline success
        INSERT INTO audit.pipeline_logs (proc_name, status, start_time, end_time, rows_affected)
        VALUES (@proc_name, 'SUCCESS', @start_time, @end_time, @rows_affected);

    END TRY
    BEGIN CATCH
        SET @end_time = GETDATE();

        -- Log pipeline failure
        INSERT INTO audit.pipeline_logs (proc_name, status, start_time, end_time, error_message)
        VALUES (@proc_name, 'FAILED', @start_time, @end_time, ERROR_MESSAGE());

        THROW;
    END CATCH
END;
GO