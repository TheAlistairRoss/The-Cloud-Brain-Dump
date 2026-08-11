"""
Generates LogAnalyticsV1TableWorkbook.json.

Run with: python build_workbook.py
This script exists only as a maintainability aid (avoids hand-escaping JSON/KQL).
The generated .json file is the actual artifact imported into Azure Workbooks.
"""
import json
import uuid

def g():
    return str(uuid.uuid4())

# ---------------------------------------------------------------------------
# Helper constructors
# ---------------------------------------------------------------------------

def text(md, name, style=None, cv=None):
    content = {"json": md}
    if style:
        content["style"] = style
    item = {"type": 1, "content": content, "name": name}
    if cv:
        item["conditionalVisibility"] = cv
    return item


def params_item(parameters, name, style="pills", query_type=0, resource_type="microsoft.operationalinsights/workspaces"):
    return {
        "type": 9,
        "content": {
            "version": "KqlParameterItem/1.0",
            "parameters": parameters,
            "style": style,
            "queryType": query_type,
            "resourceType": resource_type,
        },
        "name": name,
    }


def query_item(query, name, query_type, size=1, title=None, resource_type=None,
               cross_component=None, grid_settings=None, exported_parameters=None,
               export_field_name=None, export_parameter_name=None,
               visualization=None, no_data_message=None, show_border=True,
               time_context_param=None):
    content = {
        "version": "KqlItem/1.0",
        "query": query,
        "size": size,
        "queryType": query_type,
    }
    if title:
        content["title"] = title
    if resource_type:
        content["resourceType"] = resource_type
    if cross_component:
        content["crossComponentResources"] = cross_component
    if grid_settings:
        content["gridSettings"] = grid_settings
    if exported_parameters:
        content["exportedParameters"] = exported_parameters
    if export_field_name:
        content["exportFieldName"] = export_field_name
    if export_parameter_name:
        content["exportParameterName"] = export_parameter_name
    if visualization:
        content["visualization"] = visualization
    if no_data_message:
        content["noDataMessage"] = no_data_message
    if time_context_param:
        content["timeContextFromParameter"] = time_context_param
    item = {"type": 3, "content": content, "name": name}
    if show_border:
        item["styleSettings"] = {"showBorder": True}
    return item


def arm_template_item(label, template_uri, template_parameters, title, description, name, run_label="Deploy"):
    return {
        "type": 11,
        "content": {
            "version": "LinkItem/1.0",
            "style": "nav",
            "links": [
                {
                    "id": g(),
                    "linkTarget": "ArmTemplate",
                    "linkLabel": label,
                    "style": "primary",
                    "linkIsContextBlade": True,
                    "templateRunContext": {
                        "componentIdSource": "parameter",
                        "componentId": "ResourceGroupId",
                        "templateUriSource": "static",
                        "templateUri": template_uri,
                        "templateParameters": template_parameters,
                        "titleSource": "static",
                        "title": title,
                        "descriptionSource": "static",
                        "description": description,
                        "runLabelSource": "static",
                        "runLabel": run_label,
                    },
                }
            ],
        },
        "name": f"links - {name}",
    }


items = []

# ---------------------------------------------------------------------------
# Title
# ---------------------------------------------------------------------------
items.append(text(
    "# Log Analytics V1 (Classic) Table -> Data Collection Rule Wizard\n"
    "This workbook helps you find Log Analytics **custom tables (classic / V1, HTTP Data Collector API)** "
    "in a workspace, review their ingestion volume, and generate + deploy a **Data Collection Rule (DCR)** "
    "so you can migrate that table's ingestion to the **Logs Ingestion API** without changing the table's "
    "existing column names.\n\n"
    "It does this by:\n"
    "1. Reading the table's *current* columns (which typically have legacy type-suffixes like `Computer_s`, `EventTime_t`).\n"
    "2. Building a DCR **input stream** using *clean* column names when they are unambiguous "
    "(suffix removed, e.g. `Computer`, `EventTime`).\n"
    "3. Adding a **transformation** (`project-rename`) that renames the clean input columns back to the "
    "original suffixed names, so the **output stream** matches the table's existing schema exactly - "
    "**no destination table changes required**. If suffix removal creates duplicate names, the wizard "
    "automatically uses the original unique column names in compatibility mode.\n\n"
    "> Reference: [Custom logs migration guide](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/custom-logs-migrate) | "
    "[Data collection rule structure](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-structure) | "
    "[Data collection transformations](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-transformations)",
    "text - Title"
))

items.append(text(
    "**Legacy column suffix map** used to compute the clean input-stream column names and their DCR data types:\n\n"
    "| Suffix | Legacy meaning | DCR / KQL type |\n"
    "|---|---|---|\n"
    "| `_s` | string | `string` |\n"
    "| `_d` | number (double) | `real` |\n"
    "| `_b` | boolean | `boolean` |\n"
    "| `_g` | guid | `string` (Logs ingestion API stores/queries GUIDs as string) |\n"
    "| `_t` | datetime | `datetime` |\n\n"
    "Columns without a recognized suffix (e.g. `TimeGenerated`) are passed through unchanged. "
    "Reserved system columns (`_ResourceId`, `TenantId`, `Type`, `RawData`, etc.) are excluded automatically.",
    "text - Suffix map",
    style="info"
))

items.append(text(
    "### Workflow\n"
    "**1. Select a table**  ->  **2. Validate its schema**  ->  **3. Configure the DCR**  ->  "
    "**4. Review and deploy**\n\n"
    "This is a single, always-loaded workspace. Later sections unlock automatically as you complete each stage, "
    "so your selections remain available while you review or change earlier choices.",
    "text - workflow",
    style="info"
))

# ---------------------------------------------------------------------------
# Global parameters
# ---------------------------------------------------------------------------
global_params = [
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "ShowHelp",
        "label": "Show Help",
        "type": 10,
        "isRequired": True,
        "typeSettings": {"additionalResourceOptions": [], "showDefault": False},
        "jsonData": "[\r\n    {\"value\":\"true\", \"label\": \"Yes\", \"selected\": true},\r\n    {\"value\":\"false\", \"label\": \"No\", \"selected\": false}\r\n]",
    },
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "ApiVersion",
        "type": 1,
        "isHiddenWhenLocked": True,
        "criteriaData": [
            {"criteriaContext": {"operator": "Default", "resultValType": "static", "resultVal": "2023-09-01"}}
        ],
    },
]
items.append(params_item(global_params, "parameters - Global"))

# ---------------------------------------------------------------------------
# STEP 1: Connect + Discover V1 tables
# ---------------------------------------------------------------------------
step1_items = []

step1_items.append(text(
    "## 1. Connect & discover classic (V1) tables\n"
    "Pick a subscription and Log Analytics workspace. The grid below lists every table in the workspace, "
    "flags which ones are **Classic** (i.e. still use the legacy HTTP Data Collector API / MMA agent - "
    "`schema.tableSubType == 'Classic'`), and shows recent ingestion volume so you can prioritize which "
    "tables to migrate first.",
    "text - step1 intro", cv={"parameterName": "ShowHelp", "comparison": "isEqualTo", "value": "true"}
))

step1_params = [
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "Subscriptions", "type": 6,
        "isRequired": True, "multiSelect": True, "quote": "'", "delimiter": ",",
        "query": "resources\r\n| where type =~ \"microsoft.operationalinsights/workspaces\"\r\n| distinct subscriptionId",
        "crossComponentResources": ["value::all"],
        "typeSettings": {"additionalResourceOptions": ["value::all"]},
        "defaultValue": "value::all", "queryType": 1, "resourceType": "microsoft.resourcegraph/resources",
    },
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "Workspace", "type": 5,
        "isRequired": True,
        "query": (
            "resources\r\n| where type =~ \"microsoft.operationalinsights/workspaces\"\r\n"
            "| project id, name, subscriptionId, location\r\n"
            "| join kind = inner (\r\n"
            "    resourcecontainers\r\n"
            "    | where type == \"microsoft.resources/subscriptions\"\r\n"
            "    | project subscriptionId, subscription = strcat(name,\" (\",subscriptionId,\")\")\r\n"
            "    )\r\n"
            "on subscriptionId\r\n"
            "| project value = id, label = name, group = subscription"
        ),
        "crossComponentResources": ["{Subscriptions}"],
        "typeSettings": {"additionalResourceOptions": [], "showDefault": False},
        "queryType": 1, "resourceType": "microsoft.resourcegraph/resources",
    },
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "TimeRange", "label": "Time Range", "type": 4,
        "description": "Used to evaluate ingestion volume and last-ingested time per table",
        "isRequired": True,
        "typeSettings": {"selectableValues": [
            {"durationMs": 86400000}, {"durationMs": 259200000}, {"durationMs": 604800000},
            {"durationMs": 1209600000}, {"durationMs": 2592000000}, {"durationMs": 7776000000},
        ]},
        "value": {"durationMs": 604800000},
    },
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "ResourceGroupId", "type": 1,
        "query": "resources\r\n| where id =~ \"{Workspace}\"\r\n| project value = strcat(\"/subscriptions/\", subscriptionId, \"/resourceGroups/\", resourceGroup)",
        "crossComponentResources": ["{Subscriptions}"], "isHiddenWhenLocked": True,
        "queryType": 1, "resourceType": "microsoft.resourcegraph/resources",
    },
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "WorkspaceLocation", "type": 1,
        "query": "resources\r\n| where id =~ \"{Workspace}\"\r\n| project value = location",
        "crossComponentResources": ["{Subscriptions}"], "isHiddenWhenLocked": True,
        "queryType": 1, "resourceType": "microsoft.resourcegraph/resources",
    },
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "WorkspaceCustomerId", "type": 1,
        "query": "resources\r\n| where id =~ \"{Workspace}\"\r\n| project value = tostring(properties.customerId)",
        "crossComponentResources": ["{Subscriptions}"], "isHiddenWhenLocked": True,
        "queryType": 1, "resourceType": "microsoft.resourcegraph/resources",
    },
]
step1_items.append(params_item(step1_params, "parameters - Step1"))

# Query A: Classic table list + schema from ARM (Tables API)
q_tables_arm = (
    "{\"version\":\"ARMEndpoint/1.0\",\"data\":null,\"headers\":[],\"method\":\"GET\","
    "\"path\":\"{Workspace}/tables?api-version={ApiVersion}\",\"urlParams\":[],\"batchDisabled\":false,"
    "\"transformers\":[{\"type\":\"jsonpath\",\"settings\":{\"tablePath\":\"$.value[?(@.properties.schema.tableSubType == 'Classic')].properties\","
    "\"columns\":["
    "{\"path\":\"$.schema.name\",\"columnid\":\"name\",\"columnType\":\"string\"},"
    "{\"path\":\"$.schema.tableSubType\",\"columnid\":\"tableSubType\",\"columnType\":\"string\"},"
    "{\"path\":\"$.plan\",\"columnid\":\"plan\",\"columnType\":\"string\"},"
    "{\"path\":\"$.retentionInDays\",\"columnid\":\"retentionInDays\",\"columnType\":\"number\"}"
    "]}}]}"
)
step1_items.append(query_item(
    q_tables_arm, "query ResourceManager - ClassicTables", query_type=12, size=0,
    title="Classic tables lookup (hidden helper)",
    grid_settings={"rowLimit": 1000}
) | {"conditionalVisibility": {"parameterName": "true", "comparison": "isEqualTo", "value": "false"}})

# Query B: usage volumes per table
q_usage = (
    "let timeStart = {TimeRange:start};\r\n"
    "let timeEnd = {TimeRange:end};\r\n"
    "let timeStep = {TimeRange:grain};\r\n"
    "Usage\r\n"
    "| where TimeGenerated between (timeStart .. timeEnd)\r\n"
    "| make-series Trend = sum(Quantity) default = 0 on TimeGenerated "
    "from timeStart to timeEnd step timeStep by DataType\r\n"
    "| extend TotalMB = array_sum(Trend)\r\n"
    "| project DataType, TotalMB, Trend\r\n"
    "| order by TotalMB desc"
)
step1_items.append(query_item(
    q_usage, "query LogAnalytics - Usage", query_type=0, size=0,
    title="Ingestion volume and trend (hidden helper)",
    resource_type="microsoft.operationalinsights/workspaces", cross_component=["{Workspace}"],
    grid_settings={"rowLimit": 1000}, time_context_param="TimeRange",
    visualization="table"
) | {"conditionalVisibility": {"parameterName": "true", "comparison": "isEqualTo", "value": "false"}})

# Query C: Enrich the Classic table list with usage. A left-outer merge keeps
# inactive Classic tables but cannot introduce non-Classic tables from Usage.
merge_id = g()
q_merge = (
    "{\"version\":\"Merge/1.0\",\"merges\":[{\"id\":\"" + merge_id + "\",\"mergeType\":\"leftouter\","
    "\"leftTable\":\"query ResourceManager - ClassicTables\",\"rightTable\":\"query LogAnalytics - Usage\","
    "\"leftColumn\":\"name\",\"rightColumn\":\"DataType\"}],"
    "\"projectRename\":["
    "{\"originalName\":\"[query ResourceManager - ClassicTables].name\",\"mergedName\":\"name\",\"fromId\":\"unknown\"},"
    "{\"originalName\":\"[query ResourceManager - ClassicTables].tableSubType\",\"mergedName\":\"tableSubType\",\"fromId\":\"unknown\"},"
    "{\"originalName\":\"[query ResourceManager - ClassicTables].plan\",\"mergedName\":\"plan\",\"fromId\":\"unknown\"},"
    "{\"originalName\":\"[query ResourceManager - ClassicTables].retentionInDays\",\"mergedName\":\"retentionInDays\",\"fromId\":\"unknown\"},"
    "{\"originalName\":\"[query LogAnalytics - Usage].DataType\",\"mergedName\":\"DataType\",\"fromId\":\"" + merge_id + "\"},"
    "{\"originalName\":\"[query LogAnalytics - Usage].TotalMB\",\"mergedName\":\"TotalMB\",\"fromId\":\"" + merge_id + "\"},"
    "{\"originalName\":\"[query LogAnalytics - Usage].Trend\",\"mergedName\":\"Trend\",\"fromId\":\"" + merge_id + "\"}"
    "]}"
)
step1_items.append(query_item(
    q_merge, "query Merge - ClassicTablesWithUsage", query_type=7, size=1,
    title="Classic (V1) tables in workspace - select a table to migrate",
    no_data_message="No Classic (V1) tables were found in the selected workspace.",
    grid_settings={
        "rowLimit": 1000, "filter": True,
        "formatters": [
            {"columnMatch": "tableSubType", "formatter": 18,
             "formatOptions": {"thresholdsOptions": "colors", "thresholdsGrid": [
                 {"operator": "==", "thresholdValue": "Classic", "representation": "redBright", "text": "{0}{1}"},
                 {"operator": "Default", "thresholdValue": None, "representation": "green", "text": "{0}{1}"},
             ]}},
            {"columnMatch": "TotalMB", "formatter": 4,
             "formatOptions": {"palette": "blue"},
             "numberFormat": {
                 "unit": 38,
                 "options": {"style": "decimal", "maximumFractionDigits": 2},
                 "emptyValCustomText": "0",
             }},
            {"columnMatch": "Trend", "formatter": 21,
             "formatOptions": {"palette": "blue"}},
            {"columnMatch": "DataType", "formatter": 5},
        ],
        "labelSettings": [
            {"columnId": "name", "label": "Table name"},
            {"columnId": "tableSubType", "label": "Table subtype"},
            {"columnId": "plan", "label": "Plan"},
            {"columnId": "retentionInDays", "label": "Retention (days)"},
            {"columnId": "TotalMB", "label": "Ingestion volume"},
            {"columnId": "Trend", "label": "Ingestion trend"},
        ],
    },
    exported_parameters=[
        {"fieldName": "name", "parameterName": "SelectedTableName", "parameterType": 1},
        {"fieldName": "tableSubType", "parameterName": "SelectedTableSubType", "parameterType": 1},
        {"fieldName": "plan", "parameterName": "SelectedTablePlan", "parameterType": 1},
        {"fieldName": "TotalMB", "parameterName": "SelectedTableTotalMB", "parameterType": 1},
    ]
))

step1_items.append(text(
    "**Tip:** This grid only contains **Classic** tables. The ingestion total and sparkline use the selected "
    "**Time Range**. Select a row to carry that table into Step 2.",
    "text - step1 tip", style="info", cv={"parameterName": "ShowHelp", "comparison": "isEqualTo", "value": "true"}
))

step1_items.append(text(
    "No table is selected yet - select a row in the grid above (**Step 1 result**) to continue.",
    "text - step1 noselection", style="warning",
    cv={"parameterName": "SelectedTableName", "comparison": "isEqualTo", "value": ""}
))

items.append(text(
    "# 1 | Select a V1 table\n"
    "Choose a workspace, compare its classic tables, then select the table you want to migrate.",
    "text - section 1",
    style="info"
))
items.extend(step1_items)

# ---------------------------------------------------------------------------
# STEP 2: Inspect schema, compute clean column names + collisions
# ---------------------------------------------------------------------------
step2_items = []
step2_items.append(text(
    "## 2. Inspect the table's current schema\n"
    "This reads the *live* column list for the selected table and computes:\n"
    "- **CleanName** - the column name with any legacy type-suffix removed.\n"
    "- **MappedType** - the KQL/DCR data type for that input column.\n"
    "- Whether two or more columns collapse to the same `CleanName` (a **collision**).\n"
    "- **InputName** - the actual DCR input column. If any collision exists, the workbook safely retains all "
    "original unique names instead of blocking deployment.",
    "text - step2 intro"
))

q_table_details = (
    "{\"version\":\"ARMEndpoint/1.0\",\"data\":null,\"headers\":[],\"method\":\"GET\","
    "\"path\":\"{Workspace}/tables/{SelectedTableName}?api-version={ApiVersion}\",\"urlParams\":[],"
    "\"batchDisabled\":false,\"transformers\":null}"
)
step2_items.append(params_item([
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "SelectedTableDetails",
        "type": 1,
        "query": q_table_details,
        "isHiddenWhenLocked": True,
        "queryType": 12,
    }
], "parameters - Step2 Schema"))

kql_schema_display = (
    "let tableDetails = todynamic(base64_decode_tostring(\"{SelectedTableDetails:base64}\"));\r\n"
    "let cols = tableDetails.properties.schema.columns;\r\n"
    "let reserved = dynamic([\"_ResourceId\",\"id\",\"_SubscriptionId\",\"TenantId\",\"Type\",\"UniqueId\",\"Title\",\"RawData\",\"tenant\",\"MG\",\"ManagementGroupName\",\"SourceSystem\"]);\r\n"
    "let base = print col = cols\r\n"
    "    | mv-expand col\r\n"
    "    | extend Name = tostring(col.name), Type = tostring(col.type)\r\n"
    "    | where Name !in~ (reserved)\r\n"
    "    | extend Suffix = extract(@'_(s|d|b|g|t)$', 1, Name)\r\n"
    "    | extend Base = extract(@'^(.*)_(?:s|d|b|g|t)$', 1, Name)\r\n"
    "    | extend CleanName = iif(isempty(Base), Name, Base)\r\n"
    "    | extend MappedType = case(Suffix == \"s\", \"string\", Suffix == \"d\", \"real\", Suffix == \"b\", \"boolean\", Suffix == \"g\", \"string\", Suffix == \"t\", \"datetime\", Type);\r\n"
    "let collisionCount = toscalar(base | summarize Cnt = count() by CleanName | where Cnt > 1 | summarize TotalCollisions = count());\r\n"
    "base\r\n"
    "| join kind=leftouter (\r\n"
    "    base\r\n"
    "    | summarize DuplicateCount = count() by CleanName\r\n"
    "    ) on CleanName\r\n"
    "| extend Collision = DuplicateCount > 1\r\n"
    "| extend InputName = iif(collisionCount > 0, Name, CleanName)\r\n"
    "| extend Resolution = iif(collisionCount > 0, \"Compatibility mode - original names retained\", \"Clean-name mode\")\r\n"
    "| project Name, Type, CleanName, InputName, MappedType, Collision, Resolution\r\n"
    "| order by Collision desc, CleanName asc"
)
step2_items.append(query_item(
    kql_schema_display, "query LogAnalytics - SchemaClean", query_type=0, size=1,
    title="Current columns -> DCR input-stream mapping",
    resource_type="microsoft.operationalinsights/workspaces", cross_component=["{Workspace}"],
    grid_settings={
        "rowLimit": 500, "filter": True,
        "formatters": [
            {"columnMatch": "Collision", "formatter": 18, "formatOptions": {
                "thresholdsOptions": "colors", "thresholdsGrid": [
                    {"operator": "==", "thresholdValue": "true", "representation": "redBright", "text": "{0}{1}"},
                    {"operator": "Default", "thresholdValue": None, "representation": "green", "text": "{0}{1}"},
                ]}},
        ],
    },
))

# Compute all DCR artifacts once as a JSON object. Hidden text parameters then
# extract each value automatically, avoiding row-selection exports.
kql_build_artifacts = (
    "let tableDetails = todynamic(base64_decode_tostring(\"{SelectedTableDetails:base64}\"));\r\n"
    "let cols = tableDetails.properties.schema.columns;\r\n"
    "let reserved = dynamic([\"_ResourceId\",\"id\",\"_SubscriptionId\",\"TenantId\",\"Type\",\"UniqueId\",\"Title\",\"RawData\",\"tenant\",\"MG\",\"ManagementGroupName\",\"SourceSystem\"]);\r\n"
    "let base = print col = cols\r\n"
    "    | mv-expand col\r\n"
    "    | extend Name = tostring(col.name), Type = tostring(col.type)\r\n"
    "    | where Name !in~ (reserved)\r\n"
    "    | extend Suffix = extract(@'_(s|d|b|g|t)$', 1, Name)\r\n"
    "    | extend Base = extract(@'^(.*)_(?:s|d|b|g|t)$', 1, Name)\r\n"
    "    | extend CleanName = iif(isempty(Base), Name, Base)\r\n"
    "    | extend MappedType = case(Suffix == \"s\", \"string\", Suffix == \"d\", \"real\", Suffix == \"b\", \"boolean\", Suffix == \"g\", \"string\", Suffix == \"t\", \"datetime\", Type);\r\n"
    "let collisionCount = toscalar(base | summarize Cnt = count() by CleanName | where Cnt > 1 | summarize TotalCollisions = count());\r\n"
    "let mapped = base | extend InputName = iif(collisionCount > 0, Name, CleanName);\r\n"
    "let inputColumnsJson = toscalar(\r\n"
    "    mapped\r\n"
    "    | extend ColJson = strcat('{\"name\":\"', InputName, '\",\"type\":\"', MappedType, '\"}')\r\n"
    "    | summarize Json = strcat(\"[\", strcat_array(make_list(ColJson), \",\"), \"]\")\r\n"
    "    | project Json);\r\n"
    "let renameText = toscalar(\r\n"
    "    mapped\r\n"
    "    | where InputName != Name\r\n"
    "    | extend RenameEntry = strcat(Name, \" = \", InputName)\r\n"
    "    | summarize Txt = strcat_array(make_list(RenameEntry), \",\\n    \")\r\n"
    "    | project Txt);\r\n"
    "let transformKql = iif(isempty(renameText), \"source\", strcat(\"source\\n| project-rename\\n    \", renameText));\r\n"
    "print value = tostring(bag_pack("
    "\"HasCollisions\", tolower(tostring(collisionCount > 0)), "
    "\"CollisionCount\", tostring(collisionCount), "
    "\"InputColumnsJson\", inputColumnsJson, "
    "\"TransformKqlText\", transformKql))"
)

def artifact_value_query(property_name):
    return (
        "let artifacts = todynamic(base64_decode_tostring(\"{DcrArtifacts:base64}\"));\r\n"
        f"print value = tostring(artifacts.{property_name})"
    )

artifact_parameters = [
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "DcrArtifacts",
        "type": 1,
        "query": kql_build_artifacts,
        "crossComponentResources": ["{Workspace}"],
        "isHiddenWhenLocked": True,
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
    },
]
for parameter_name in ("HasCollisions", "CollisionCount", "InputColumnsJson", "TransformKqlText"):
    artifact_parameters.append({
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": parameter_name,
        "type": 1,
        "query": artifact_value_query(parameter_name),
        "crossComponentResources": ["{Workspace}"],
        "isHiddenWhenLocked": True,
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
    })

step2_items.append(params_item(artifact_parameters, "parameters - DCR Artifacts"))

step2_items.append(text(
    "**Compatibility mode applied:** {CollisionCount} clean column name(s) are ambiguous (for example, "
    "`Computer_s` and `Computer_d` both become `Computer`). The source table cannot be changed, so the generated "
    "DCR input stream retains the table's original unique column names for every field. No table schema change is "
    "required, and deployment can continue. Your Logs Ingestion API payload must use the original suffixed names "
    "shown in **InputName**. To use clean names instead, resolve the ambiguity in the sending application before "
    "calling the API.",
    "text - step2 collision warning", style="warning",
    cv={"parameterName": "HasCollisions", "comparison": "isEqualTo", "value": "true"}
))

step2_visibility = {"parameterName": "SelectedTableName", "comparison": "isNotEqualTo", "value": ""}
items.append(text(
    "# 2 | Validate the schema\n"
    "Selected table: **{SelectedTableName}**. Review the proposed input mapping and any compatibility-mode guidance.",
    "text - section 2",
    style="info",
    cv=step2_visibility
))
for item in step2_items:
    if "conditionalVisibility" not in item:
        item["conditionalVisibility"] = step2_visibility
items.extend(step2_items)

# ---------------------------------------------------------------------------
# STEP 3: Configure the DCR
# ---------------------------------------------------------------------------
step3_params = [
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "DcrName", "label": "Data Collection Rule name",
        "type": 1, "isRequired": True,
        "criteriaData": [{"criteriaContext": {"operator": "Default", "resultValType": "static", "resultVal": "dcr-{SelectedTableName}"}}],
        "typeSettings": {"paramValidationRules": [
            {"match": True, "regExp": "^[a-zA-Z0-9_-]{1,64}$", "message": "1-64 letters, numbers, underscores or hyphens"}
        ]},
    },
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "CreateNewDce",
        "label": "Data Collection Endpoint", "type": 10, "isRequired": True,
        "jsonData": "[\r\n    {\"value\":\"true\", \"label\": \"Create a new DCE\", \"selected\": true},\r\n    {\"value\":\"false\", \"label\": \"Use an existing DCE\", \"selected\": false}\r\n]",
    },
]
step3_params_newdce = [
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "NewDceName", "label": "New DCE name",
        "type": 1, "isRequired": True,
        "criteriaData": [{"criteriaContext": {"operator": "Default", "resultValType": "static", "resultVal": "dce-{SelectedTableName}"}}],
    },
]
step3_params_existingdce = [
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "ExistingDce", "label": "Existing DCE",
        "type": 5, "isRequired": False,
        "query": (
            "resources\r\n| where type =~ \"microsoft.insights/datacollectionendpoints\"\r\n"
            "| where id startswith \"{ResourceGroupId}\"\r\n| project value = id, label = name"
        ),
        "crossComponentResources": ["{Subscriptions}"],
        "typeSettings": {"additionalResourceOptions": [], "showDefault": False},
        "queryType": 1, "resourceType": "microsoft.resourcegraph/resources",
    },
]
step3_state_params = [
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "DceMode", "type": 1,
        "query": "print value = \"{CreateNewDce}\"",
        "crossComponentResources": ["{Workspace}"],
        "isHiddenWhenLocked": True,
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
    },
]
step3_items = [
    text(
        "## 3. Configure the Data Collection Rule\n"
        "The DCR is created in the **same resource group and region as the workspace** "
        "(`{ResourceGroupId}`, `{WorkspaceLocation}`), per Azure Monitor recommended practice. "
        "Choose a name, and either create a new Data Collection Endpoint (DCE) or reuse one that already "
        "exists in the resource group.",
        "text - step3 intro"
    ),
    params_item(step3_params, "parameters - Step3"),
    params_item(step3_state_params, "parameters - WorkflowState"),
    params_item(
        step3_params_newdce, "parameters - Step3 NewDce",
        query_type=0
    ) | {"conditionalVisibility": {"parameterName": "DceMode", "comparison": "isEqualTo", "value": "true"}},
    params_item(
        step3_params_existingdce, "parameters - Step3 ExistingDce",
        query_type=0
    ) | {"conditionalVisibility": {"parameterName": "DceMode", "comparison": "isEqualTo", "value": "false"}},
    text(
        "**New DCE** will be created: `{NewDceName}` in `{WorkspaceLocation}`.",
        "text - step3 newdce note",
        cv={"parameterName": "DceMode", "comparison": "isEqualTo", "value": "true"}
    ),
    text(
        "**Existing DCE** selected: `{ExistingDce:label}`.",
        "text - step3 existingdce note",
        cv={"parameterName": "DceMode", "comparison": "isEqualTo", "value": "false"}
    ),
    query_item(
        (
            "let cols = dynamic({InputColumnsJson});\r\n"
            "print col = cols\r\n| mv-expand col\r\n"
            "| project ['Input stream column'] = tostring(col.name), ['DCR type'] = tostring(col.type)"
        ),
        "query LogAnalytics - InputStreamPreview", query_type=0, size=1,
        title="Preview: DCR input stream columns",
        resource_type="microsoft.operationalinsights/workspaces", cross_component=["{Workspace}"],
        grid_settings={"rowLimit": 500},
    ),
    text(
        "**Transformation KQL** that will run in the DCR. In clean-name mode it restores the table's existing "
        "suffixed names; in compatibility mode it remains `source` because input names already match:\n"
        "```kusto\n{TransformKqlText}\n```",
        "text - step3 transform preview"
    ),
]
step3_visibility = {"parameterName": "InputColumnsJson", "comparison": "isNotEqualTo", "value": ""}
items.append(text(
    "# 3 | Configure the DCR\n"
    "The input schema is ready. Configure the DCR and choose whether to create or reuse a Data Collection Endpoint.",
    "text - section 3",
    style="success",
    cv=step3_visibility
))
for item in step3_items:
    if item["name"] != "parameters - WorkflowState" and "conditionalVisibility" not in item:
        item["conditionalVisibility"] = step3_visibility
items.extend(step3_items)

# ---------------------------------------------------------------------------
# STEP 4: Review and deploy
# ---------------------------------------------------------------------------
template_uri = (
    "https://raw.githubusercontent.com/TheAlistairRoss/The-Cloud-Brain-Dump/main/"
    "Toolshed/Log%20Analytics%20V1%20Table%20Workbook/azuredeploy.json"
)

deployment_parameters = [
    {"name": "location", "source": "parameter", "value": "WorkspaceLocation", "kind": "stringValue"},
    {"name": "createNewDce", "source": "parameter", "value": "CreateNewDce", "kind": "boolValue"},
    {"name": "newDceName", "source": "parameter", "value": "NewDceName", "kind": "stringValue"},
    {"name": "existingDceResourceId", "source": "parameter", "value": "ExistingDce", "kind": "stringValue"},
    {"name": "dcrName", "source": "parameter", "value": "DcrName", "kind": "stringValue"},
    {"name": "tableName", "source": "parameter", "value": "SelectedTableName", "kind": "stringValue"},
    {"name": "workspaceResourceId", "source": "parameter", "value": "Workspace", "kind": "stringValue"},
    {"name": "inputColumns", "source": "parameter", "value": "InputColumnsJson", "kind": "arrayValue"},
    {"name": "transformKql", "source": "parameter", "value": "TransformKqlText", "kind": "stringValue"},
]

step4_items = [
    text(
        "## 4. Review & deploy\n"
        "Use **Review and Deploy Data Collection Rule** to open Azure's native ARM deployment experience. Select "
        "**View template** to inspect the hosted template and substituted parameters before deploying the Data "
        "Collection Rule and, if selected, a new Data Collection Endpoint.",
        "text - step4 intro"
    ),
    params_item([
        {
            "id": g(),
            "version": "KqlParameterItem/1.0",
            "name": "DeploymentReady",
            "type": 1,
            "query": (
                "let createNew = tolower(\"{CreateNewDce}\") == \"true\";\r\n"
                "let dceReady = iif(createNew, isnotempty(\"{NewDceName}\"), isnotempty(\"{ExistingDce}\"));\r\n"
                "print value = tolower(tostring(isnotempty(\"{DcrName}\") and dceReady))"
            ),
            "crossComponentResources": ["{Workspace}"],
            "isHiddenWhenLocked": True,
            "queryType": 0,
            "resourceType": "microsoft.operationalinsights/workspaces",
        }
    ], "parameters - Deployment Readiness"),
    arm_template_item(
        label="Review and Deploy Data Collection Rule",
        template_uri=template_uri,
        template_parameters=deployment_parameters,
        title="Deploy Data Collection Rule and Endpoint",
        description=(
            "The template deploys **{DcrName}** and, when requested, **{NewDceName}** into `{ResourceGroupId}`. "
            "Use **View template** to inspect the resources and parameter values before deployment. No changes are "
            "made to the destination schema for `{SelectedTableName}`."
        ),
        name="DeployDcr",
    ) | {"conditionalVisibility": {"parameterName": "DeploymentReady", "comparison": "isEqualTo", "value": "true"}},
    text(
        "**Note:** You need `Microsoft.Insights/dataCollectionRules/write` (and, if creating a new DCE, "
        "`Microsoft.Insights/dataCollectionEndpoints/write`) permission on the resource group to deploy - "
        "for example via the **Monitoring Contributor** built-in role. After deployment, update your ingestion "
        "client to call the [Logs ingestion API](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-ingestion-api-overview) "
        "against this DCR instead of the legacy HTTP Data Collector API.",
        "text - step4 permissions note", style="info",
        cv={"parameterName": "DeploymentReady", "comparison": "isEqualTo", "value": "true"}
    ),
]
step4_visibility = {"parameterName": "InputColumnsJson", "comparison": "isNotEqualTo", "value": ""}
items.append(text(
    "# 4 | Review and deploy\n"
    "Open the native ARM deployment to review the hosted template before deploying **{DcrName}**.",
    "text - section 4",
    style="success",
    cv=step4_visibility
))
for item in step4_items:
    if "conditionalVisibility" not in item:
        item["conditionalVisibility"] = step4_visibility
items.extend(step4_items)

workbook = {
    "version": "Notebook/1.0",
    "items": items,
    "styleSettings": {},
    "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json",
}

with open("LogAnalyticsV1TableWorkbook.json", "w", encoding="utf-8") as f:
    json.dump(workbook, f, indent=2)

print("Wrote LogAnalyticsV1TableWorkbook.json")
