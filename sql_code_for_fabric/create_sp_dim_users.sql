CREATE OR ALTER PROCEDURE mart.sp_load_dim_users
AS
BEGIN
    SET NOCOUNT ON;

    -- Initialize execution metrics
    DECLARE @start_time DATETIME2 = GETDATE();
    DECLARE @end_time DATETIME2;
    DECLARE @rows_affected INT = 0;
    DECLARE @proc_name VARCHAR(100) = 'mart.sp_load_dim_users';

    BEGIN TRY
        -- Log pipeline start
        INSERT INTO audit.pipeline_logs (proc_name, status, start_time)
        VALUES (@proc_name, 'RUNNING', @start_time);

        -- Core transformation: Full refresh via CTAS
        TRUNCATE TABLE mart.dim_users;

        WITH users AS (
            SELECT * FROM AI_Lakehouse.staging.staging_user_subscriptions
        ),
        app_reviews AS (
            SELECT * FROM AI_Lakehouse.staging.staging_app_reviews
        ),
        plans AS (
            SELECT id, plan_type, monthly_token_limit FROM AI_Lakehouse.staging.staging_plans
        ),
        last_status_users AS (
            SELECT 
                users.*,
                ROW_NUMBER() OVER(
                    PARTITION BY user_id
                    ORDER BY start_time DESC
                ) AS rn
            FROM users
        ),
        last_app_reviews AS (
            SELECT 
                user_id,
                rating,
                ROW_NUMBER() OVER(
                    PARTITION BY user_id
                    ORDER BY created_at DESC, id DESC
                ) AS rn
            FROM app_reviews
        )

        INSERT INTO mart.dim_users
        SELECT 
            ROW_NUMBER() OVER(
                ORDER BY u.user_id
            ) AS user_sk,
            u.user_id,
            u.plan_id,
            r.rating AS user_last_rating, 
            p.plan_type,
            p.monthly_token_limit,
            u.start_time,
            u.end_time,
            u.active_status
        FROM last_status_users u
        LEFT JOIN last_app_reviews r 
            ON u.user_id = r.user_id 
           AND r.rn = 1
        LEFT JOIN plans p 
            ON u.plan_id = p.id
        WHERE u.rn = 1;

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