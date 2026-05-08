param location string
param tags object
@minLength(8)
param resourceToken string
param abbrs object
param apiImageName string

var placeholderImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// ---------------------------------------------------------------------------
// Log Analytics workspace (for Container Apps environment diagnostics)
// ---------------------------------------------------------------------------

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.11.2' = {
  name: 'log-analytics'
  params: {
    name: '${abbrs.logAnalytics}-${resourceToken}'
    location: location
    tags: tags
    skuName: 'PerGB2018'
    dataRetention: 30
  }
}

resource logAnalyticsExisting 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: '${abbrs.logAnalytics}-${resourceToken}'
  dependsOn: [
    logAnalytics
  ]
}

// ---------------------------------------------------------------------------
// User-assigned managed identity used by the api container app
// ---------------------------------------------------------------------------

module apiIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: 'api-identity'
  params: {
    name: '${abbrs.managedIdentity}-api-${resourceToken}'
    location: location
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Container Registry (with AcrPull granted to the api identity)
// ---------------------------------------------------------------------------

module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.1' = {
  name: 'container-registry'
  params: {
    name: '${abbrs.containerRegistry}${resourceToken}'
    location: location
    tags: tags
    acrSku: 'Basic'
    acrAdminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    roleAssignments: [
      {
        principalId: apiIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'AcrPull'
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Container Apps environment
// ---------------------------------------------------------------------------

module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.11.2' = {
  name: 'container-apps-environment'
  params: {
    name: '${abbrs.containerAppsEnv}-${resourceToken}'
    location: location
    tags: tags
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsExisting.properties.customerId
        sharedKey: logAnalyticsExisting.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
    publicNetworkAccess: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// API Container App (MCP server)
// ---------------------------------------------------------------------------

module apiContainerApp 'br/public:avm/res/app/container-app:0.18.0' = {
  name: 'api-container-app'
  params: {
    name: '${abbrs.containerApp}-api-${resourceToken}'
    location: location
    tags: union(tags, {
      'azd-service-name': 'api'
    })
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    managedIdentities: {
      systemAssigned: false
      userAssignedResourceIds: [
        apiIdentity.outputs.resourceId
      ]
    }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: apiIdentity.outputs.resourceId
      }
    ]
    ingressTargetPort: 8080
    ingressExternal: true
    ingressTransport: 'auto'
    ingressAllowInsecure: false
    scaleSettings: {
      minReplicas: 1
      maxReplicas: 3
    }
    containers: [
      {
        name: 'api'
        image: empty(apiImageName) ? placeholderImage : apiImageName
        resources: {
          cpu: json('0.5')
          memory: '1Gi'
        }
        env: [
          {
            name: 'Catalog__Source'
            value: 'GitHub'
          }
          {
            name: 'Catalog__GitHub__Owner'
            value: 'azureholic'
          }
          {
            name: 'Catalog__GitHub__Repo'
            value: 'ATO-Catalog'
          }
          {
            name: 'Catalog__GitHub__Branch'
            value: 'main'
          }
          {
            name: 'Catalog__GitHub__Path'
            value: ''
          }
          {
            name: 'ASPNETCORE_URLS'
            value: 'http://+:8080'
          }
        ]
      }
    ]
  }
}

output containerRegistryName string = containerRegistry.outputs.name
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer
output containerAppsEnvironmentId string = containerAppsEnvironment.outputs.resourceId
output apiContainerAppName string = apiContainerApp.outputs.name
output apiContainerAppUri string = 'https://${apiContainerApp.outputs.fqdn}'
