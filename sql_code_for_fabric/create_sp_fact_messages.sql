CREATE OR ALTER PROCEDURE mart.sp_load_fact_messages
AS
BEGIN
    SET NOCOUNT ON;

    -- Initialize execution metrics
    DECLARE @start_time DATETIME2 = GETDATE();
    DECLARE @end_time DATETIME2;
    DECLARE @rows_affected INT = 0;
    DECLARE @proc_name VARCHAR(100) = 'mart.sp_load_fact_messages';

    BEGIN TRY
        -- Log pipeline start
        INSERT INTO audit.pipeline_logs (proc_name, status, start_time)
        VALUES (@proc_name, 'RUNNING', @start_time);

        -- Core transformation: Full refresh via CTAS
        TRUNCATE TABLE mart.fact_messages;


        WITH dim_users AS (
            SELECT * FROM mart.dim_users
        ),
        dim_models AS (
            SELECT * FROM mart.dim_models
        ),
        convos AS (
            SELECT * FROM AI_Lakehouse.staging.staging_conversations
        ),
        messages AS (
            SELECT * FROM AI_Lakehouse.staging.staging_messages
        ),
        message_reviews AS (
            SELECT * FROM AI_Lakehouse.staging.staging_message_reviews
        ),
        rank_message_reviews_time AS (
            SELECT
                mr.message_id,
                mr.rating,
                mr.category,
                mr.created_at,
                ROW_NUMBER() OVER(
                    PARTITION BY mr.message_id
                    ORDER BY mr.created_at DESC, mr.id DESC
                ) AS rn
            FROM message_reviews mr
            INNER JOIN messages m ON mr.message_id = m.id
            WHERE m.created_at <= mr.created_at
        ),
        cleaning_messages_logic AS (
            SELECT * FROM messages
            WHERE (is_error = 1 AND completion_tokens = 0)
               OR (is_error = 0 AND completion_tokens > 0)
        )

        
        INSERT INTO mart.fact_messages
        SELECT  
            u.user_sk,
            CAST(FORMAT(m.created_at,'yyyyMMdd') AS varchar) AS date_key,
            dm.model_sk,
            m.id,
            m.conversation_id,
            dm.model_id,
            m.prompt_tokens,
            m.completion_tokens,
            m.is_error,
            m.is_attached_file,
            m.is_ai_generated_file,
            (m.prompt_tokens * dm.prompt_price_per_1k) / 1000 AS prompt_token_prices,
            (m.completion_tokens * dm.completion_price_per_1k) / 1000 AS completion_token_prices,  
            mr.rating AS last_rating, 
            mr.category AS last_category,
            m.created_at AS message_created_at
        FROM cleaning_messages_logic m
        LEFT JOIN convos c
            ON m.conversation_id = c.id
           AND c.created_at <= m.created_at
        LEFT JOIN rank_message_reviews_time mr
            ON m.id = mr.message_id
           AND mr.rn = 1
        LEFT JOIN dim_users u 
            ON c.user_id = u.user_id
        LEFT JOIN dim_models dm
            ON m.model_id = dm.model_id
           AND m.created_at BETWEEN dm.effective_start_date AND dm.effective_end_date;

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