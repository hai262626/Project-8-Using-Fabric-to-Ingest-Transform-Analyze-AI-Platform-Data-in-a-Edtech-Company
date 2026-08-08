-- Drop existing user dimension table if it exists
DROP TABLE IF EXISTS mart.dim_users;
GO

-- Recreate user dimension table using CTAS pattern
CREATE TABLE mart.dim_users AS 
WITH users AS (
    -- Fetch staging user subscription records
    SELECT * FROM AI_Lakehouse.staging.staging_user_subscriptions
),

app_reviews AS (
    -- Fetch staging app review records
    SELECT * FROM AI_Lakehouse.staging.staging_app_reviews
),

plans AS (
    -- Fetch plan types and token limits
    SELECT id, plan_type, monthly_token_limit FROM AI_Lakehouse.staging.staging_plans
),

last_status_users AS (
    -- Filter for the latest subscription status per user
    SELECT 
        users.*,
        ROW_NUMBER() OVER(
            PARTITION BY user_id
            ORDER BY start_time DESC
        ) as rn
    FROM users
),

last_app_reviews AS (
    -- Filter for the latest app review rating per user
    SELECT 
        user_id,
        rating,
        ROW_NUMBER() OVER(
            PARTITION BY user_id
            ORDER BY created_at DESC, id DESC
        ) AS rn
    FROM app_reviews
)

-- Build user dimension with latest status, plan details, and latest rating
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