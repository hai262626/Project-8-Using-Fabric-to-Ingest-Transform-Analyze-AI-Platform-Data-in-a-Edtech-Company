CREATE OR ALTER PROCEDURE mart.sp_load_dim_models
AS
BEGIN
    SET NOCOUNT ON;

    -- Initialize execution metrics and variables
    DECLARE @start_time DATETIME2 = GETDATE();
    DECLARE @end_time DATETIME2;
    DECLARE @rows_affected INT = 0;
    DECLARE @proc_name VARCHAR(100) = 'mart.sp_load_dim_models';

    BEGIN TRY
        -- Log pipeline execution start
        INSERT INTO audit.pipeline_logs (proc_name, status, start_time)
        VALUES (@proc_name, 'RUNNING', @start_time);

        -- Expire existing records when price changes are detected
        UPDATE target
        SET 
            target.effective_end_date = DATEADD(day, -1, CAST(source.updated_at AS DATE)),
            target.is_current = 0
        FROM mart.dim_models target
        INNER JOIN AI_Lakehouse.staging.staging_models source 
            ON target.model_id = source.id
        WHERE target.is_current = 1 
          AND (
                target.prompt_price_per_1k <> source.prompt_price_per_1k OR
                target.completion_price_per_1k <> source.completion_price_per_1k
              );

        -- Insert new records for new models or price-updated models
        INSERT INTO mart.dim_models (
            model_id,
            provider,
            prompt_price_per_1k,
            completion_price_per_1k,
            max_context_window,
            effective_start_date,
            effective_end_date,
            is_current
        )
        SELECT 
            source.id AS model_id,
            source.provider,
            source.prompt_price_per_1k,
            source.completion_price_per_1k,
            source.max_context_window,
            CAST(source.updated_at AS DATE) AS effective_start_date,
            CAST('9999-12-31' AS DATE) AS effective_end_date,
            1 AS is_current
        FROM AI_Lakehouse.staging.staging_models source
        LEFT JOIN mart.dim_models target 
            ON source.id = target.model_id AND target.is_current = 1
        WHERE target.model_id IS NULL 
           OR (
                target.prompt_price_per_1k <> source.prompt_price_per_1k OR
                target.completion_price_per_1k <> source.completion_price_per_1k
              );

        SET @rows_affected = @@ROWCOUNT;
        SET @end_time = GETDATE();

        -- Log pipeline execution success
        INSERT INTO audit.pipeline_logs (proc_name, status, start_time, end_time, rows_affected)
        VALUES (@proc_name, 'SUCCESS', @start_time, @end_time, @rows_affected);

    END TRY
    BEGIN CATCH
        SET @end_time = GETDATE();

        -- Log pipeline execution failure
        INSERT INTO audit.pipeline_logs (proc_name, status, start_time, end_time, error_message)
        VALUES (@proc_name, 'FAILED', @start_time, @end_time, ERROR_MESSAGE());

        THROW;
    END CATCH
END;
GO