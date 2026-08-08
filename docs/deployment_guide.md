# Deployment & Setup Guide

This guide details the step-by-step procedure required to deploy and reproduce the **AI Platform Data Engineering & Analytics** ecosystem on Microsoft Fabric from scratch.

---

## 1. Prerequisites & Environment Setup

Before starting the deployment, ensure you have access to the following components:

1. **Microsoft Fabric Workspace**: Active workspace with **Contributor** or more privileges, or at least all access to these requirements items.
2. **PostgreSQL Database (Neon DB)**: Serverless PostgreSQL instance storing the transactional OLTP source dataset.
3. **Microsoft Teams Webhook / Email Channel**: Configured notification target for automated error reporting.

---

## 2. Historical Batch Pipeline Deployment

### Step 2.1: Lakehouse Setup & Raw Ingestion
1. Create a Microsoft Fabric **Lakehouse** named `AI_Lakehouse`.
2. Initialize two distinct schemas inside `AI_Lakehouse`:
   * `raw`: Destination for raw incremental/batch ingestions from Neon DB.
   * `staging`: Destination for cleansed and typed datasets.
3. Ingest raw tables directly from Neon DB into `AI_Lakehouse.raw` preserving original source state.

### Step 2.2: Staging Transformation via Dataflow Gen2
1. Create a **Dataflow Gen2** pipeline targeting `AI_Lakehouse.raw` as source.
2. Apply cleansing logic:
   * Strip unreferenced comment/text metadata.
   * Create flag fields (`is_error`, `is_attached_file`, `is_ai_generated_file`), set it to `BIT`/`Boolean`,replacement for comment/text data
   * Create dim_date, removing `users` table.
3. Load transformed datasets directly into `AI_Lakehouse.staging`.

### Step 2.3: Data Warehouse DDLs & Stored Procedure Deployment
1. Create a **Data Warehouse** named `AI_Warehouse`, create new SQL query and initialize schemas:
   ```sql
   CREATE SCHEMA mart;
   GO
   CREATE SCHEMA audit;
   GO
   ```
2. **Execute DDL Scripts**: Run table creation scripts from `sql_code_for_fabric/`:
   * Initialize target Mart tables (`mart.dim_models`, `mart.dim_users`, `mart.dim_date`, `mart.fact_messages`).
   * Initialize audit logging table (`audit.pipeline_logs`).
   **Deploy Loading Stored Procedures**:
   * **Truncate + Insert Procedures**: Deploy SPs executing `TRUNCATE` and `INSERT` logic for current-snapshot dimensions (`mart.dim_users`) and transaction facts (`mart.fact_messages`).
   * **SCD Type 2 Procedure**: Deploy `sp_load_dim_models_scd2` executing `UPDATE` (expire old version) + `INSERT` (activate new version) logic for LLM token pricing in `mart.dim_models`.

(All created SP already have log insert, therefore, no need to insert log manually or create SP for log)


### Step 2.4: Semantic Model & Power BI Reporting
1. From Data Warehouse View, Click "Create Semantic Model", choose all 4 dim - fact tables, then Create.
2. Establish 1:N single-direction relationships in Semantic Model:
   * `mart.fact_messages[user_sk]` -> `mart.dim_users[user_sk]`
   * `mart.fact_messages[model_sk]` -> `mart.dim_models[model_sk]`
   * `mart.fact_messages[date_key]` -> `mart.dim_date[date_key]`
3. Build required **DAX Measures** (e.g., Total Token Cost, Error Rate %, Daily Active Users).
4. Publish the executive Power BI report tracking platform adoption and API expenditure.

---

## 3. Real-Time Telemetry Pipeline Deployment

### Step 3.1: Streaming Setup (Eventstream & KQL Database)
1. Create an **Eventstream** connected to PostgreSQL DB CDC. Recommend to choose the format of CDC as "Analytics-ready events & auto-updated schema"
2. Route the live message stream directly into an **Eventhouse / KQL Database** named.

### Step 3.2: Real-Time Dashboard & Alerting
1. Run table schema setup and mapping scripts from `kql_code_for_fabric/kql_for_event_dashboard.sql`.
2. Construct a **Real-Time Dashboard** displaying live message throughput, short-term usage spikes, and error rates. Each KQL query equals to 1 dashboard.
3. Configure automated **Data Alerts**: Trigger email/Teams notifications when message error counts breach system limits (>100 errors in a 10-minute window).

---

## 4. Create Pipeline Orchestration & End-to-End Execution

1. Build a master **Fabric Data Pipeline** orchestrating the sequential execution:
   * `Ingestion Activity` (Neon DB -> `AI_Lakehouse.raw`).
   * `Dataflow Gen2 Activity` (`raw` -> `staging`).
   * `Stored Procedure Activities` (Execute `sp_load_dim_models`, `sp_load_dim_users`, `sp_load_fact_messages`, `sp_load_dim_date`(optional) with exception handling).
   * `Semantic Model Refresh Activity` (Triggers Power BI dataset update).
2. Attach **On Failure** notification triggers from each activity node to dispatch execution failure logs to the engineering alert channel.
3. Schedule daily execution at `04:00 UTC +7`(Or anytime you want).
!Pipeline](Fabric Pipeline Flow.png)
