# Data Dictionary - Gold Layer & Audit Logs

This document provides detailed schema specifications, actual data types (inferred via Microsoft Fabric CTAS), key designations, and business rules for all tables in the Gold Layer (`mart` schema) and System Audit Logs.

---

## 1. Dimension Table: `mart.dim_models` (SCD Type 2)

* **Description**: Manages the catalog of AI models and tracks historical changes in token pricing over time.

| Column Name | Data Type | Key Type | Description & Business Rules |
| :--- | :--- | :--- | :--- |
| **`model_sk`** | `BIGINT` | **PK / SK** | Auto-incrementing Surrogate Key (`IDENTITY`), uniquely identifying each pricing version. |
| **`model_id`** | `VARCHAR(50)` | **NK** | Natural Key identifying the model from the source system (e.g., `gpt-4o`). |
| **`provider`** | `VARCHAR(100)` | - | AI service provider (e.g., `OpenAI`, `Anthropic`). |
| **`prompt_price_per_1k`** | `DECIMAL(18,6)` | - | Unit price per 1,000 Prompt Tokens (USD). |
| **`completion_price_per_1k`** | `DECIMAL(18,6)` | - | Unit price per 1,000 Completion Tokens (USD). |
| **`max_context_window`** | `INT` | - | Maximum context window size supported by the model. |
| **`effective_start_date`** | `DATE` | - | Date when the pricing version became active. |
| **`effective_end_date`** | `DATE` | - | Expiration date for the pricing version (Defaults to `9999-12-31` for current records). |
| **`is_current`** | `INT` | - | Version status flag: `1` (Active), `0` (Historical). |

---

## 2. Dimension Table: `mart.dim_users` (Current Snapshot)

* **Description**: Stores user profiles, active subscription plan details, and latest app feedback ratings.

| Column Name | Data Type | Key Type | Description & Business Rules |
| :--- | :--- | :--- | :--- |
| **`user_sk`** | `BIGINT` | **PK / SK** | Surrogate Key generated via `ROW_NUMBER() OVER (ORDER BY user_id)`. |
| **`user_id`** | `VARCHAR(8000)` | **NK** | Natural Key identifying the user from PostgreSQL source. |
| **`plan_id`** | `VARCHAR(8000)` | **FK** | Identifier for the most recent subscription plan assigned to the user. |
| **`user_last_rating`** | `VARCHAR(8000)` | - | User's most recent rating submitted for the application. |
| **`plan_type`** | `VARCHAR(8000)` | - | Categorization of the subscription tier (`Free`, `Basic`, `Ultra`). |
| **`monthly_token_limit`** | `INT` | - | Monthly allocated token limit based on plan tier. |
| **`start_time`** | `DATETIME2` | - | Effective start timestamp of the current subscription. |
| **`end_time`** | `DATETIME2` | - | Expiration timestamp (Standard duration: 3 months for `Basic`, 12 months for `Ultra`, and 18 months defaulted in this synthetic dataset for `Free` tier). |
| **`active_status`** | `VARCHAR(8000)` | - | User subscription status (`Active`, `Expired`). Accounts may be marked expired due to term end date or administrative actions (revoked/banned). |

---

## 3. Dimension Table: `mart.dim_date` (Calendar Dimension)

* **Description**: Standard calendar dimension enabling time-series aggregations, drill-down reporting, and date slicing across all fact tables.

| Column Name | Data Type | Key Type | Description & Business Rules |
| :--- | :--- | :--- | :--- |
| **`date_key`** | `VARCHAR(30)` | **PK** | Primary Key formatted as `yyyyMMdd` (e.g., `20260520`). |
| **`full_date`** | `DATE` | - | Standard calendar date value (`YYYY-MM-DD`). |
| **`year`** | `INT` | - | Four-digit calendar year (e.g., `2026`). |
| **`quarter`** | `INT` | - | Calendar quarter number (`1` to `4`). |
| **`quarter_name`** | `VARCHAR(10)` | - | Formatted quarter identifier (e.g., `Q1`, `Q2`). |
| **`month`** | `INT` | - | Calendar month number (`1` to `12`). |
| **`month_name`** | `VARCHAR(20)` | - | Full name of the calendar month (e.g., `January`, `May`). |
| **`day_of_month`** | `INT` | - | Day number within the month (`1` to `31`). |
| **`day_of_week`** | `INT` | - | Day number within the week. |
| **`day_name`** | `VARCHAR(20)` | - | Full name of the weekday (e.g., `Monday`, `Wednesday`). |
| **`is_weekend`** | `BIT` | **Flag** | Weekend indicator flag: `1` (Weekend), `0` (Weekday). |

---

## 4. Fact Table: `mart.fact_messages` (Transaction Fact)

* **Description**: Stores granular records of student-AI message interactions, calculated token costs, and corresponding user feedback.

| Column Name | Data Type | Key Type | Description & Business Rules |
| :--- | :--- | :--- | :--- |
| **`id`** | `VARCHAR(8000)` | **PK** | Unique identifier for the interaction message (Message ID). |
| **`user_sk`** | `BIGINT` | **FK / SK** | Foreign key referencing `mart.dim_users[user_sk]`. |
| **`date_key`** | `VARCHAR(30)` | **FK** | Date key formatted as `yyyyMMdd` linking to `mart.dim_date[date_key]`. |
| **`model_sk`** | `BIGINT` | **FK / SK** | Foreign key referencing `mart.dim_models[model_sk]` (SCD Type 2 join based on message creation timestamp). |
| **`conversation_id`** | `VARCHAR(8000)` | **NK / FK** | Identifier for the conversation session containing this message. |
| **`model_id`** | `VARCHAR(50)` | - | AI model identifier processing the request. |
| **`prompt_tokens`** | `INT` | **Measure** | Number of input prompt tokens consumed. |
| **`completion_tokens`** | `INT` | **Measure** | Number of output completion tokens generated by AI. |
| **`is_error`** | `BIT` | **Flag** | Error indicator flag: `1` (System Error), `0` (Successful). |
| **`is_attached_file`** | `BIT` | **Flag** | File attachment flag: `1` (User uploaded a file), `0` (None). |
| **`is_ai_generated_file`** | `BIT` | **Flag** | Output file flag: `1` (AI generated an output file), `0` (None). |
| **`prompt_token_prices`** | `DECIMAL(34,11)` | **Measure** | Calculated prompt token cost = `(prompt_tokens * prompt_price) / 1000`. |
| **`completion_token_prices`** | `DECIMAL(34,11)` | **Measure** | Calculated completion token cost = `(completion_tokens * completion_price) / 1000`. |
| **`last_rating`** | `VARCHAR(8000)` | - | Latest user feedback rating recorded for this specific message. |
| **`last_category`** | `VARCHAR(8000)` | - | Primary feedback or error category associated with the message. |
| **`message_created_at`** | `DATETIME2` | - | Timestamp when the message was sent to the system. |

---

## 5. Audit Table: `audit.pipeline_logs` (System Logging)

* **Description**: Captures Stored Procedure execution logs and pipeline activity history for operational monitoring.

| Column Name | Data Type | Key Type | Description & Business Rules |
| :--- | :--- | :--- | :--- |
| **`log_id`** | `BIGINT` | **PK** | Auto-incrementing log ID uniquely identifying each log entry. |
| **`pipeline_name`** | `VARCHAR(200)` | - | Name of the executing Fabric Data Pipeline. |
| **`procedure_name`** | `VARCHAR(200)` | - | Name of the executed Stored Procedure. |
| **`status`** | `VARCHAR(50)` | - | Execution outcome status (`SUCCESS`, `FAILED`, `RUNNING`). |
| **`rows_affected`** | `INT` | **Measure** | Total rows inserted or updated in the target table. |
| **`error_message`** | `VARCHAR(8000)` | - | Detailed error message captured from the `CATCH` block. |
| **`execution_time`** | `DATETIME2` | - | Timestamp when the log entry was recorded. |