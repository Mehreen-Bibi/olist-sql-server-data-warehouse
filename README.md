# Olist Data Warehouse — Medallion ETL Pipeline

A SQL Server data warehouse built on the **Medallion architecture** (Bronze → Silver → Gold) for the [Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) public dataset. Raw CSVs are ingested, cleaned, and modeled into a star schema ready for BI reporting and ad-hoc analysis, with full batch-level and table-level ETL observability built in.

Sources (CSV) → Bronze → Silver → Gold → Consume
olist/*.csv raw cleaned star Power BI
as-is typed schema Ad-hoc SQL
enriched ML

## Architecture

| Layer | Purpose | Data Model |
|---|---|---|
| **Bronze** | Raw, unmodified landing zone. 1:1 with source CSVs. | As-is |
| **Silver** | Cleaned, standardized, deduplicated, typed. Derived business columns added. | None (flat, typed) |
| **Gold** | Business-ready dimensional model. | Star Schema |
| **etl** | Operational metadata — batch and table-level load logging. | Logging tables |

Diagrams (`/docs/diagrams`):
- `high_level_architecture_olist.drawio` — Source → Warehouse → Consume overview
- `data_integration_olist.drawio` — entity relationships across source tables
- `dataflow_olist.drawio` — table-level Bronze → Silver → Gold lineage

---

## Tech Stack

- **Database:** Microsoft SQL Server (T-SQL)
- **Ingestion:** `BULK INSERT` from local CSV files
- **Orchestration:** T-SQL stored procedures, chained via a master script
- **Monitoring:** Custom `etl` schema (`BatchLog`, `TableLoadLog`)
- **Consumption:** Power BI / ad-hoc SQL / ML-ready gold tables

---

## Project Structure

├── scripts/
│ ├── 01_create_database_schemas.sql # Database + bronze/silver/gold/etl schemas
│ ├── 02_create_etl_tables.sql # etl.BatchLog, etl.TableLoadLog
│ ├── 03_create_bronze_tables.sql # Bronze DDL (9 raw staging tables)
│ ├── 04_create_silver_tables.sql # Silver DDL (cleaned, typed, PKs, indexes)
│ ├── 05_create_gold_tables.sql # Gold DDL (star schema: 6 dims + 4 facts)
│ ├── procedures/
│ │ ├── load_bronze.sql # bronze.load_bronze
│ │ ├── load_silver.sql # silver.load_silver
│ │ └── load_gold.sql # gold.load_gold
│ └── run_pipeline.sql # Master orchestration script
├── docs/
│ └── diagrams/ # .drawio architecture & dataflow diagrams
└── README.md

---

## Data Model

### Bronze Layer (9 tables)
Raw landing tables, mostly `NVARCHAR`-typed to preserve source fidelity (including dates, kept as text to retain original format):

`olist_customers_dataset` · `olist_geolocation_dataset` · `olist_order_items_dataset` · `olist_order_payments_dataset` · `olist_order_reviews_dataset` · `olist_orders_dataset` · `olist_products_dataset` · `olist_sellers_dataset` · `product_category_name_translation`

### Silver Layer (9 tables)
Same grain as bronze, with:
- Proper data types (`DATETIME2`, `DECIMAL`, etc.) via `TRY_CAST`
- Primary keys on 8/9 tables (geolocation excluded — not uniquely keyed)
- Data cleansing: trimmed/uppercased text, junk review comments (`"???"`, `"..."`, etc.) nulled out, review text stripped of quotes/line breaks/control characters
- Derived columns: `review_sentiment`, `delivery_days`, `approval_hours`, `late_delivery_flag`, `product_volume_cm3`
- Geolocation rows filtered to valid Brazilian lat/lng bounds, with rejected-row counts logged

### Gold Layer — Star Schema

**Dimensions (6)**

| Table | Grain | Surrogate Key |
|---|---|---|
| `dim_customer` | 1 row per `customer_unique_id` (SCD Type 1) | `customer_key` |
| `dim_product` | 1 row per `product_id` | `product_key` |
| `dim_seller` | 1 row per `seller_id` (SCD Type 1) | `seller_key` |
| `dim_date` | 1 row per calendar day, auto-generated from the full order date range | `date_key` (YYYYMMDD) |
| `dim_order_status` | Distinct order status values | `order_status_key` |
| `dim_payment_method` | Distinct payment method values | `payment_method_key` |

**Facts (4)**

| Table | Grain | Notes |
|---|---|---|
| `fact_sales` | 1 row per order item | `total_item_value` computed column (price + freight) |
| `fact_delivery` | 1 row per order | Delivery timing & late-delivery metrics |
| `fact_reviews` | 1 row per review | Sentiment classification, has-comment flag |
| `fact_payments` | 1 row per payment installment | Kept separate from `fact_sales` to avoid distorting item-level revenue with installment counts |

All fact tables carry surrogate-key foreign keys back to their dimensions, indexed for fast joins.

---

## ETL Monitoring (`etl` schema)

Every layer load is fully observable:

- **`etl.BatchLog`** — one row per layer execution (`ProcessName`, `LayerName`, start/end time, duration, `Status`: `RUNNING` / `SUCCESS` / `FAILED`, error message)
- **`etl.TableLoadLog`** — one row per table loaded within a batch (rows loaded/rejected, duration, status, error message), FK'd to `BatchLog`

Example: check the most recent pipeline run

```sql
SELECT TOP 3 BatchID, ProcessName, LayerName, StartTime, Status, DurationSeconds
FROM etl.BatchLog
ORDER BY BatchID DESC;
```

Example: inspect table-level results for a batch

```sql
SELECT TableName, RowsLoaded, RowsRejected, Status, DurationSeconds
FROM etl.TableLoadLog
WHERE BatchID = <BatchID>
ORDER BY LogID;
```
---

## Setup & Execution

### Prerequisites
- SQL Server (2019+ recommended for `DATEDIFF_BIG`, `TRY_CAST` support)
- Olist CSV files available on a path accessible to the SQL Server instance (default: `A:\olist_datasets\`, configurable via `@BasePath` in `load_bronze.sql`)

### Run order

```sql
-- 1. One-time setup
:r scripts/01_create_database_schemas.sql
:r scripts/02_create_etl_tables.sql
:r scripts/03_create_bronze_tables.sql
:r scripts/04_create_silver_tables.sql
:r scripts/05_create_gold_tables.sql

-- 2. Deploy stored procedures
:r scripts/procedures/load_bronze.sql
:r scripts/procedures/load_silver.sql
:r scripts/procedures/load_gold.sql

-- 3. Run the full pipeline
:r scripts/run_pipeline.sql
```

Or trigger a full refresh directly:

```sql
EXEC bronze.load_bronze;
EXEC silver.load_silver;
EXEC gold.load_gold;
```

### Pipeline behavior
- **Bronze:** each table is loaded independently (truncate → `BULK INSERT` with `TABLOCK`) so one table's failure doesn't roll back the others; the failure is logged and re-thrown.
- **Silver:** truncate → transform → insert per table, with `TRY_CAST` guarding against bad source data.
- **Gold:** the entire load runs in a **single transaction** — dimensions are cleared and reloaded before facts, and if any table fails, the whole gold refresh rolls back to avoid partial/inconsistent reporting data.
- **Orchestration:** `run_pipeline.sql` validates all three stored procedures exist, runs Bronze → Silver → Gold in order, and stops immediately on the first failure.

---

## Known Limitations / Roadmap

- `olist_geolocation_dataset` is loaded through Bronze and Silver but is **not currently joined into the Gold layer** (no lat/lng on `dim_customer`/`dim_seller`). Planned for a future release to support map-based visualizations.
- Gold reloads are full refreshes (SCD Type 1 only) — no historical tracking of changed customer/seller attributes.


