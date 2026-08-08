# Architecture Decision Records (ADR)

This document details the primary technical decisions, architectural trade-offs, and engineering rationale driving the design of the **AI Platform Data Engineering & Analytics** ecosystem on Microsoft Fabric.

---

## ADR-01: Synthetic OLTP Data Generation vs. Public Datasets

* **Context**: Public datasets and online data dumps rarely provide a fully normalized, relational OLTP structure with operational telemetry (such as real-time interaction logs, token usage, and granular message-level feedback).
* **Decision**: Architected and generated a custom, fully normalized PostgreSQL OLTP database from scratch, specifically tailored to an EdTech AI Platform business context.
* **Rationale**:
  * **Business Control**: Allows explicit definition of domain-specific business rules, token consumption quotas, error distributions, and subscription behaviors.
  * **Automated Data Streaming**: Enables seamless daily incremental data generation using GitHub Actions, ensuring full control over upstream source schemas and data production schedules.

---

## ADR-02: Overwrite Strategy vs. Append Incremental Pattern

* **Context**: Choosing between complex incremental loading (Append/Merge) and full snapshot refreshment (Overwrite) for dimensions and facts within the Gold Layer.
* **Decision**: Adopted a **Full Overwrite** pattern for the majority of data warehouse tables, with the exception of `mart.dim_models`.
* **Rationale**:
  * **Scale-Appropriate Engineering**: The platform processes a modest transaction volume (~600–1,000 messages daily), resulting in lightweight total dataset sizes over time.
  * **Simplicity & Performance**: Eliminates complex delta tracking, state management, and edge-case duplicate handling, thereby shortening transformation execution windows and reducing pipeline maintenance overhead.

---

## ADR-03: SCD Type 2 Implementation for `dim_models`

* **Context**: LLM API pricing (`prompt_price_per_1k`, `completion_price_per_1k`) fluctuates frequently as providers update their model tiers (simulated at a weekly frequency in this project).
* **Decision**: Implemented **Slowly Changing Dimension (SCD) Type 2** using an Upsert (`UPDATE` + `INSERT`) pattern managed via Stored Procedures.
* **Rationale**:
  * **Historical Cost Accuracy**: Preserves historical pricing versions (`effective_start_date`, `effective_end_date`, `is_current`) to guarantee that historical token expenditures in `fact_messages` reflect the exact unit price active at the moment the message was generated.

---

## ADR-04: Dual-Track Architecture (Real-Time KQL vs. Batch Warehouse)

* **Context**: Balancing the demand for low-latency operational monitoring against high-level executive analytics.
* **Decision**: Decoupled the analytical flow into two dedicated streaming and batch processing tracks:
  1. **Real-Time Track (Eventstream $\rightarrow$ KQL Database)**: High-frequency telemetry for instantaneous error tracking, system spike alerts, and operational monitoring.
  2. **Batch Track (Dataflow Gen2 $\rightarrow$ Warehouse)**: Scheduled daily processing for executive reporting, subscriber retention, and financial aggregation presented to C-level stakeholders.
* **Rationale**: Prevents heavy analytical queries from degrading real-time alerting responsiveness and aligns computational storage/engine choices directly with operational personas.

---

## ADR-05: Adoption of Integer Surrogate Keys (SK)

* **Context**: Source systems rely on long alphanumeric string natural keys (`UUID` / `VARCHAR`), which introduce storage and join inefficiencies in columnar data engines.
* **Decision**: Generated integer-based Surrogate Keys (`BIGINT`) for dimensions (`user_sk`, `model_sk`) to serve as primary and foreign key references across the Data Mart.
* **Rationale**:
  * **Storage & Join Optimization**: Integer comparisons consume significantly less memory and process faster than multi-byte string joins.
  * **SCD Type 2 Compatibility**: Disambiguates `dim_models` versions where `model_id` is repeated across price changes, allowing `fact_messages` to bind cleanly to a unique `model_sk` for a strict 1:N relationship in Power BI.

---

## ADR-06: Separation of Dataflow Gen2 Cleaning & Warehouse Stored Procedures

* **Context**: Determining the boundaries between ETL graphical transformation tools (Dataflow Gen2) and SQL-native execution engines (Fabric Warehouse T-SQL).
* **Decision**: Enforced a strict separation of concerns: Dataflow Gen2 handles raw ingestion, data type casting, and basic cleaning into `staging`, while Warehouse Stored Procedures drive Star Schema modeling, business logic, and dimensional joins.
* **Rationale**:
  * **Resource Isolation**: Avoids infrastructure bottlenecks and memory limitations inherent in graphical Dataflow engines when executing complex joins or window functions.
  * **Maintainability**: Simplifies debugging and code maintenance by isolating schema transformations from core analytical modeling logic.