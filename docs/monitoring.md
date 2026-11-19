# Monitoring and alerting

- Workspace-based Application Insights collects frontend/backend/function telemetry; Azure diagnostic settings send App Service, Function, SQL, Key Vault, and Data Factory platform logs to Log Analytics.
- `workbook-<project>-<environment>` contains request-failure and exception time series. Use the workbook as the environment health overview and extend it with business and pipeline KPIs.
- High-severity metric alerts watch the frontend, backend, and Function App Health Check Status using their configured health endpoints. Scheduled query alerts cover failed API requests, Function exceptions, SQL connectivity exceptions, and Data Factory pipeline failures. If `availability_test_url` is set, a multi-region standard availability test and additional synthetic downtime alert are enabled.
- Provide one or more valid `alert_email_addresses` in each environment to configure Action Group email receivers. With an empty list, alerts are created but have no email recipient.
- KQL assumes workspace-based Application Insights tables (`AppRequests`, `AppExceptions`, `AppAvailabilityResults`) and classic `AzureDiagnostics` Data Factory logs. Verify field/table availability after the first deployment; update queries if diagnostic destination mode or app instrumentation changes.
- Retention is independently configurable for Log Analytics and Application Insights. Production currently defaults to 365 days for workspace logs and 35 days of SQL point-in-time retention; validate regulatory and cost requirements.

For private-only environments, external synthetic tests cannot reach private endpoints. Use an in-network probe (for example, an approved runner or monitoring agent) and publish its results to the workspace rather than enabling a public endpoint solely for monitoring.
