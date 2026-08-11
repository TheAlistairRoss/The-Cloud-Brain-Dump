# Log Analytics V1 Table Workbook

An Azure Workbook that finds Log Analytics **custom tables (classic / V1, HTTP Data Collector API)** in a
workspace, shows their ingestion volume, and provides a guided wizard to generate and deploy a
**Data Collection Rule (DCR)** that migrates ingestion to the **Logs Ingestion API** — without changing
the destination table's existing column names.

## Why

The [HTTP Data Collector API is being retired](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/custom-logs-migrate)
(legacy API support ends **September 14, 2026**). Tables ingested via that API ("classic"/V1 tables, or
tables fed by the legacy MMA agent) typically have columns with legacy type-suffixes, e.g. `Computer_s`,
`EventTime_t`, `BytesSent_d`. Migrating to the DCR-based Logs Ingestion API normally means either
changing your client to send data shaped like the *existing* table schema, or accepting a schema change.

This workbook builds a DCR whose **input stream** accepts data using *clean* column names when those names
are unique (no suffix — e.g. `Computer`, `EventTime`, `BytesSent`). A KQL **transformation** renames those
clean names back to the table's original suffixed names before they land in the table. If suffix removal
would create duplicate input names, the workbook automatically uses the original unique column names in
compatibility mode. The **output stream** always targets the table's existing, unmodified schema.

## What it does

The workbook uses a **single, always-loaded canvas** rather than expandable/collapsible groups. Each section
unlocks automatically when the preceding stage has produced valid input. This preserves the selected table
and generated parameters while users move back through the workflow to review or change a choice.

1. **Step 1 — Discover & monitor**: Lists all tables in the selected workspace via the
   [Tables API](https://learn.microsoft.com/en-us/rest/api/loganalytics/tables), filters the result to
   `Classic` (V1) tables, and shows total ingestion volume plus an ingestion-trend sparkline for the
   selected time range so you can prioritize which tables to migrate.
2. **Step 2 — Inspect schema**: Reads the selected table's live columns, strips known legacy suffixes to
   compute clean input-stream names and DCR data types, and detects **collisions** (two+ columns that
   would collapse to the same clean name, e.g. `Computer_s` and `Computer_d`). If a collision is found,
   compatibility mode retains all original column names so the input stream remains unique and the wizard
   can continue without changing the table schema. The table resource is retrieved
   automatically by hidden text parameters; schema and DCR artifact helpers require no row selection.
   Collision state is normalized to lowercase `true`/`false` for consistent conditional visibility.
3. **Step 3 — Configure the DCR**: Pick a DCR name and either create a new Data Collection Endpoint (DCE)
   or reuse an existing one in the resource group. The DCR/DCE are always created in the same resource
   group and region as the workspace. Shows a preview of the computed input-stream columns and the
   generated transformation KQL. The DCE choice dynamically reveals either the new-DCE name or the
   existing-DCE picker. The multiline transformation is passed safely to the hosted ARM template as a
   typed string parameter.
4. **Step 4 — Review & deploy**: Opens Azure's native ARM deployment experience using the hosted
   [azuredeploy.json](./azuredeploy.json) template. Workbook values are passed as typed deployment parameters,
   including the generated input-column array and transformation. Select **View template** in the deployment
   blade to inspect everything before deployment.

## Legacy column suffix → DCR type map

| Suffix | Legacy meaning  | DCR / KQL type |
|--------|-----------------|----------------|
| `_s`   | string          | `string`       |
| `_d`   | number (double) | `real`         |
| `_b`   | boolean         | `boolean`      |
| `_g`   | guid            | `string`       |
| `_t`   | datetime        | `datetime`     |

Columns with no recognized suffix (e.g. `TimeGenerated`) pass through unchanged. Reserved/system columns
(`_ResourceId`, `_SubscriptionId`, `TenantId`, `Type`, `UniqueId`, `Title`, `RawData`, `tenant`, `MG`,
`ManagementGroupName`, `SourceSystem`) are excluded from the generated input stream automatically.

Source: [Custom logs migration guide](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/custom-logs-migrate),
[HTTP Data Collector API reference](https://learn.microsoft.com/en-us/previous-versions/azure/azure-monitor/logs/data-collector-api).

## Import into Azure

1. In the Azure portal, go to **Monitor > Workbooks > New**.
2. Select the **Advanced Editor** (`</>` icon) and switch to editing the full JSON gallery template.
3. Paste the contents of [LogAnalyticsV1TableWorkbook.json](./LogAnalyticsV1TableWorkbook.json) and apply.
4. Save the workbook to your subscription/resource group of choice.

The deployment button expects the workbook files to be published at:
`Toolshed/Log Analytics V1 Table Workbook` in the `main` branch of
`TheAlistairRoss/The-Cloud-Brain-Dump`. The workbook loads the template from the corresponding raw GitHub URL.

## Required permissions to deploy a DCR from the workbook

| Action | Built-in role |
|---|---|
| Create/modify a Data Collection Endpoint | Monitoring Contributor (`Microsoft.Insights/dataCollectionEndpoints/write`) |
| Create/modify a Data Collection Rule | Monitoring Contributor (`Microsoft.Insights/DataCollectionRules/write`) |
| Deploy via `Microsoft.Resources/deployments` (used by the workbook's Deploy button) | Contributor, or any role with `Microsoft.Resources/deployments/write` on the resource group |

## Known limitations / notes

- This workbook generates the DCR/DCE for **one table at a time**. Run the wizard again for additional
  tables.
- The workflow has no collapsible groups. To restart or change direction, select another table in Step 1;
  the downstream schema, DCR preview, and template refresh automatically.
- If source columns collide after suffix removal, the entire input stream uses original column names for
  consistency and uniqueness. Logs Ingestion API payloads must use those original suffixed names. If clean
  payload names are required, resolve the ambiguity in the sending application before ingestion.
- The wizard does not modify the destination table schema, and does not migrate the table from V1 to V2
  (`az monitor log-analytics workspace table migrate`) — do that separately per the
  [migration guide](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/custom-logs-migrate) if
  you also want to enable DCR-based features on the table itself.
- Because this workbook deploys live Azure resources, validate it in a test workspace/resource group before
  using it against production tables, and use **View template** in the deployment blade before running it.
