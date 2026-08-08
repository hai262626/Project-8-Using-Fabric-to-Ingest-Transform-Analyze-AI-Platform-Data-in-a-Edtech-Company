# Deployment & Setup Guide

This guide details the step-by-step procedure required to deploy and reproduce the **AI Platform Data Engineering & Analytics** ecosystem on Microsoft Fabric from scratch.

---

## 1. Prerequisites & Environment Setup

Before starting the deployment, ensure access to the following infrastructure components:

1. **Microsoft Fabric Workspace**: Active workspace with **Contributor** role (or higher) with full access permissions to create Lakehouses, Warehouses, Pipelines, Dataflows, Eventstreams, and Semantic Models.
2. **PostgreSQL Database (Neon DB)**: Serverless PostgreSQL OLTP instance acting as the upstream source.
3. **Microsoft Teams Webhook / Email Channel**: Notification endpoints configured to receive automated pipeline failure alerts.
4. **Repository Assets**: Local repository containing DDL scripts (`sql_code_for_fabric/`), KQL queries (`kql_code_for_fabric/`), and schema documentation.

---

## 2. Historical Batch Pipeline Deployment

### Step 2.1: Lakehouse Setup & Raw Ingestion
1. Create a Microsoft Fabric **Lakehouse** named `AI_Lakehouse`.
2. Initialize two distinct schemas within `AI_Lakehouse`:
   * `raw`: Landing zone for raw batch ingestions replicated from Neon DB.
   * `staging`: Target for cleansed and formatted intermediate datasets.
3. Ingest raw source tables directly from Neon DB into `AI_Lakehouse.raw`, preserving original source state.

### Step 2.2: Staging Transformation via Dataflow Gen2
1. Create a **Dataflow Gen2** pipeline targeting `AI_Lakehouse.raw` as source.
2. Apply data cleansing and transformation steps:
   * Strip unreferenced comment/text metadata columns.
   * Derive boolean flag fields (`is_error`, `is_attached_file`, `is_ai_generated_file`) formatted as `BIT`/`Boolean` to replace unstructured text logs.
   * Generate `dim_date` calendar entity and filter out redundant raw tables.
3. Save and load transformed staging datasets directly into `AI_Lakehouse.staging`.

### Step 2.3: Data Warehouse DDLs & Stored Procedure Deployment
1. Create a **Data Warehouse** named `AI_Warehouse`, open a new SQL Query window, and initialize schemas:
   ```sql
   CREATE SCHEMA mart;
   GO
   CREATE SCHEMA audit;
   GO
   ```
2. **Execute DDL Scripts**: Run table creation scripts from `sql_code_for_fabric/`:
   * Target Mart Tables: `mart.dim_models`, `mart.dim_users`, `mart.dim_date`, and `mart.fact_messages`.
   * Audit Logging Table: `audit.pipeline_logs`.
3. **Deploy Core Loading Stored Procedures**:
   * **Truncate + Insert Procedures**: Deploy SPs executing `TRUNCATE` and `INSERT` logic for current-snapshot dimensions (`mart.dim_users`, `mart.dim_date`) and transaction facts (`mart.fact_messages`).
   * **SCD Type 2 Procedure**: Deploy `sp_load_dim_models_scd2` executing `UPDATE` (expire old versions) + `INSERT` (activate new versions) logic for LLM token pricing in `mart.dim_models`.

> ℹ️ **Note on Audit Logging**: All deployed Stored Procedures feature built-in `TRY...CATCH` exception handling and self-logging routines that write execution start times, row counts, and runtime errors directly into `audit.pipeline_logs`. No manual log insertion or separate logging procedure is required.

### Step 2.4: Semantic Model & Executive Power BI Reporting
1. Navigate to the SQL Analytics Endpoint / Warehouse View, click **New Semantic Model**, select all 4 core tables (`mart.dim_models`, `mart.dim_users`, `mart.dim_date`, `mart.fact_messages`), and click **Create**.
2. Establish 1:N single-direction relationships within the Semantic Model View:
   * `mart.fact_messages[user_sk]` $\rightarrow$ `mart.dim_users[user_sk]`
   * `mart.fact_messages[model_sk]` $\rightarrow$ `mart.dim_models[model_sk]`
   * `mart.fact_messages[date_key]` $\rightarrow$ `mart.dim_date[date_key]`
3. Build required **DAX Measures** (e.g., Total Token Cost, Error Rate %, Daily Active Users).
4. Publish the executive Power BI report tracking platform adoption, API usage, and token expenditure.

![Data Model OLAP](images/Data%20Model%20(OLAP).png)
*Figure 1: Star Schema relationship design configured within the Semantic Model.*

![Dashboard Screenshot](images/Dashboard%20Screenshot.png)
*Figure 2: Published Power BI Executive Dashboard displaying historical analytics and financial telemetry.*

---

## 3. Real-Time Telemetry Pipeline Deployment

### Step 3.1: Streaming Setup (Eventstream & KQL Database)
1. Create a Fabric **Eventstream** connected to Neon DB via PostgreSQL CDC source. Set data event serialization format to **"Analytics-ready events & auto-updated schema"**.
2. Route the live message stream directly into an **Eventhouse / KQL Database** named `AI_Realtime_KQLDB`.

![Real-time Fabric Flow](images/Real-time%20Fabric%20Flow.png)
*Figure 3: Real-time telemetry streaming architecture utilizing Eventstream and KQL Database.*

### Step 3.2: Real-Time Dashboard & Operational Alerting
1. Execute schema creation and table mapping scripts from `kql_code_for_fabric/kql_for_event_dashboard.sql`.
2. Construct a **Real-Time Dashboard** in Microsoft Fabric. Map each individual KQL query to a dedicated visual tile monitoring live message throughput, short-term usage spikes, and system errors.
3. Configure automated **Data Alerts**: Set threshold rules to send email/Teams notifications when message error counts breach system limits (>100 errors within a 10-minute window).

![Real-time Dashboard Screenshot](images/Real-time%20Dashboard%20Screenshot.png)
*Figure 4: Real-Time Operational Dashboard tracking live telemetry and system error spikes.*

---

## 4. Pipeline Orchestration & End-to-End Execution

1. Build a master **Fabric Data Pipeline** orchestrating the sequential execution:
   * **Ingestion Activity**: Triggers replication from Neon DB to `AI_Lakehouse.raw`.
   * **Dataflow Gen2 Activity**: Transforms datasets from `raw` to `staging`.
   * **Stored Procedure Activities**: Sequentially executes `sp_load_dim_models`, `sp_load_dim_users`, `sp_load_dim_date` (optional), and `sp_load_fact_messages` with exception handling.
   * **Semantic Model Refresh Activity**: Triggers automated Power BI dataset update upon successful warehouse load.
2. Attach **On Failure** notification triggers to each activity node to dispatch execution failure alerts directly to the engineering channel.
3. Schedule daily automated pipeline execution at `04:00 UTC+7` (21:00 UTC).

![Fabric Pipeline Flow](images/Fabric%20Pipeline%20Flow.png)
*Figure 5: Master Data Pipeline orchestrating batch ingestion, transformations, warehouse loads, and failure alerts.*
