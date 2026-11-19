# Networking and private connectivity

- `snet-app-integration` is delegated to `Microsoft.Web/serverFarms` for Regional VNet Integration. It is shared by the frontend, backend, and Function App; size it for the expected scale-out and do not deploy private endpoints into it.
- `snet-private-endpoints` hosts private endpoints. Add NSGs/route tables only after validating required platform traffic and Azure Private Link behavior.
- Private DNS zones are linked to the VNet for `azurewebsites.net`, `vaultcore.azure.net`, `database.windows.net`, the required Storage endpoints, and Data Factory. On-premises clients need conditional forwarders to Azure DNS through a resolver/forwarding service.
- SQL, Key Vault, Storage, App Services, Functions, and Data Factory public endpoints are disabled by default. App Service public endpoints deny traffic except `public_app_ip_rules`; Storage denies all public traffic except `public_storage_ip_rules`. Change the corresponding `enable_public_*_access` input only with a reviewed network policy.
- App Service VNet Integration is outbound connectivity; private endpoints are inbound connectivity. Both are provisioned. Connect client networks to the VNet (VPN/ExpressRoute) to reach private app hostnames.
- Data Factory managed private endpoints are distinct from the VNet private endpoints. Their target resource owners may need to approve the connection. Integration Runtime outbound rules for third-party data sources should be explicitly managed in Data Factory.
- Availability tests originate outside the VNet. Set `availability_test_url` only when the endpoint is intentionally public. For private services, use an approved in-network synthetic probe and forward its telemetry to the workspace.

## Address planning

Defaults are `10.40.0.0/16`, `10.40.1.0/24` for integration, and `10.40.2.0/24` for private endpoints. Supply non-overlapping ranges before peering or connecting to corporate networks.
