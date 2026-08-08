-- Drop existing table if it exists
DROP TABLE IF EXISTS mart.dim_models;
GO

-- Create target dimension table schema for SCD Type 2 tracking
CREATE TABLE mart.dim_models (
    model_sk BIGINT IDENTITY,
    model_id VARCHAR(50) NOT NULL,
    provider VARCHAR(100),
    prompt_price_per_1k DECIMAL(18, 6),
    completion_price_per_1k DECIMAL(18, 6),
    max_context_window INT,
    effective_start_date DATE NOT NULL,
    effective_end_date DATE NOT NULL,
    is_current INT NOT NULL
);
GO

-- Populate initial baseline snapshot from staging
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
    id AS model_id,
    provider,
    prompt_price_per_1k,
    completion_price_per_1k,
    max_context_window,
    CAST(updated_at AS DATE) AS effective_start_date,
    CAST('9999-12-31' AS DATE) AS effective_end_date,
    1 AS is_current
FROM AI_Lakehouse.staging.staging_models;
GO