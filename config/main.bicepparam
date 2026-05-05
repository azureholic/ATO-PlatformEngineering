// ============================================================================
// AI Landing Zone — custom deployment parameters
// ============================================================================
// This .bicepparam file overrides the default parameters in
//   ../bicep-ptn-aiml-landing-zone/main.parameters.json
//
// Edit the values below to match your environment, then deploy with:
//   az deployment group create \
//     --resource-group <rg> \
//     --template-file   ../bicep-ptn-aiml-landing-zone/main.bicep \
//     --parameters      ./main.bicepparam
//
// The CI workflow (.github/workflows/deploy-bicep.yml) uses this file
// automatically.
// ============================================================================

using '../bicep-ptn-aiml-landing-zone/main.bicep'

// ---------------------------------------------------------------------------
// Core (required)
// ---------------------------------------------------------------------------

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'dev')
param location        = readEnvironmentVariable('AZURE_LOCATION', 'eastus2')
param principalId     = readEnvironmentVariable('AZURE_PRINCIPAL_ID', '')
param principalType   = 'User' // 'User' | 'ServicePrincipal' | 'Group'

param deploymentTags = {
  environment: readEnvironmentVariable('AZURE_ENV_NAME', 'dev')
  workload: 'ai-landing-zone'
  managedBy: 'bicep'
}

// ---------------------------------------------------------------------------
// Regional overrides (leave '' to inherit from `location`)
// ---------------------------------------------------------------------------

param aiFoundryLocation     = readEnvironmentVariable('AZURE_AI_FOUNDRY_LOCATION', '')
param cosmosLocation        = readEnvironmentVariable('AZURE_COSMOS_LOCATION', '')
param searchServiceLocation = readEnvironmentVariable('AZURE_SEARCH_LOCATION', '')
param speechServiceLocation = readEnvironmentVariable('AZURE_SPEECH_LOCATION', '')
param psqlLocation          = readEnvironmentVariable('AZURE_PSQL_LOCATION', '')

// ---------------------------------------------------------------------------
// Networking
// ---------------------------------------------------------------------------

param networkIsolation              = bool(readEnvironmentVariable('NETWORK_ISOLATION', 'true'))
param useExistingVNet               = bool(readEnvironmentVariable('USE_EXISTING_VNET', 'false'))
param existingVnetResourceId        = readEnvironmentVariable('EXISTING_VNET_RESOURCE_ID', '')
param deploySubnets                 = bool(readEnvironmentVariable('DEPLOY_SUBNETS', 'true'))
param sideBySideDeploy              = bool(readEnvironmentVariable('SIDE_BY_SIDE', 'false'))
param privateEndpointLocation       = readEnvironmentVariable('AZURE_PE_LOCATION', '')
param privateEndpointResourceGroupName = readEnvironmentVariable('AZURE_PE_RESOURCE_GROUP_NAME', '')
param bastionAllowedSourceIPs       = []

// ---------------------------------------------------------------------------
// Feature flags — toggle the components you want to deploy
// ---------------------------------------------------------------------------

param deployAiFoundry         = true
param deployAiFoundrySubnet   = true
param deployAppConfig         = true
param deployAppInsights       = true
param deployCosmosDb          = true
param deployContainerApps     = true
param deployContainerRegistry = true
param deployContainerEnv      = true
param deployNsgs              = true
param deployAzureFirewall     = bool(readEnvironmentVariable('DEPLOY_AZURE_FIREWALL', 'false'))
param deployMcp               = true
param deployGroundingWithBing = false
param deployKeyVault          = true
param deployVmKeyVault        = bool(readEnvironmentVariable('DEPLOY_VM_KEY_VAULT', 'false'))
param deployLogAnalytics      = true
param enablePrivateLogAnalytics = bool(readEnvironmentVariable('ENABLE_PRIVATE_LOG_ANALYTICS', 'true'))
param deploySearchService     = true
param deploySpeechService     = bool(readEnvironmentVariable('DEPLOY_SPEECH_SERVICE', 'false'))
param speechServiceSku        = 'S0'
param deployStorageAccount    = true
param greenFieldDeployment    = true
param deployVM                = bool(readEnvironmentVariable('DEPLOY_VM', 'false'))
param deploySoftware          = true
param deployPostgres          = false

// ---------------------------------------------------------------------------
// Identity / auth
// ---------------------------------------------------------------------------

param useUAI                  = bool(readEnvironmentVariable('USE_UAI', 'true'))
param useCAppAPIKey           = bool(readEnvironmentVariable('USE_CAPP_API_KEY', 'false'))
param useZoneRedundancy       = false
param enableAgenticRetrieval  = bool(readEnvironmentVariable('ENABLE_AGENTIC_RETRIEVAL', 'true'))
param useCMK                  = false

// ---------------------------------------------------------------------------
// Existing resource references (leave null to provision new)
// ---------------------------------------------------------------------------

param aiSearchResourceId                = null
param aiFoundryStorageAccountResourceId = null
param aiFoundryCosmosDBAccountResourceId = null

// ---------------------------------------------------------------------------
// Resource names (leave null for auto-generated names)
// ---------------------------------------------------------------------------

param aiFoundryAccountName          = null
param aiFoundryProjectName          = null
param aiFoundryProjectDisplayName   = null
param aiFoundryProjectDescription   = null
param aiFoundryStorageAccountName   = null
param aiFoundryStorageSku           = 'Standard_LRS'
param aiFoundrySearchServiceName    = null
param aiFoundryCosmosDbName         = null
param bingSearchName                = null
param appConfigName                 = null
param appInsightsName               = null
param containerEnvName              = null
param containerRegistryName         = null
param conversationContainerName     = null
param dataIngestContainerAppName    = null
param datasourcesContainerName      = null
param dbAccountName                 = null
param dbDatabaseName                = null
param frontEndContainerAppName      = null
param keyVaultName                  = null
param logAnalyticsWorkspaceName     = null
param searchServiceName             = null
param speechServiceName             = null
param solutionStorageAccountName    = null

// ---------------------------------------------------------------------------
// VM
// ---------------------------------------------------------------------------

param vmAdminPassword = readEnvironmentVariable('VM_ADMIN_PASSWORD', '')
param vmSize          = readEnvironmentVariable('AZURE_VM_SIZE', 'Standard_D2s_v3')

// ---------------------------------------------------------------------------
// AI model deployments
// ---------------------------------------------------------------------------

param modelDeploymentList = [
  {
    name: 'chat'
    model: {
      format: 'OpenAI'
      name: 'gpt-5-nano'
      version: '2025-08-07'
    }
    sku: {
      name: 'GlobalStandard'
      capacity: 40
    }
    canonical_name: 'CHAT_DEPLOYMENT_NAME'
    apiVersion: '2025-12-01-preview'
  }
  {
    name: 'text-embedding'
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-large'
      version: '1'
    }
    sku: {
      name: 'Standard'
      capacity: 10
    }
    canonical_name: 'EMBEDDING_DEPLOYMENT_NAME'
    apiVersion: '2025-12-01-preview'
  }
]

// ---------------------------------------------------------------------------
// Container Apps
// ---------------------------------------------------------------------------

param workloadProfiles = [
  {
    name: 'Consumption'
    workloadProfileType: 'Consumption'
  }
  {
    workloadProfileType: 'D4'
    name: 'main'
    minimumCount: 0
    maximumCount: 1
  }
]

param storageAccountContainersList = [
  {
    name: 'documents'
    canonical_name: 'DOCUMENTS_STORAGE_CONTAINER'
  }
]

param databaseContainersList = [
  {
    name: 'conversations'
    canonical_name: 'CONVERSATIONS_DATABASE_CONTAINER'
    partitionKey: '/principal_id'
    indexingPolicy: {
      compositeIndexes: [
        [
          { path: '/isDeleted', order: 'Ascending' }
          { path: '/_ts', order: 'Descending' }
        ]
        [
          { path: '/isDeleted', order: 'Ascending' }
          { path: '/name', order: 'Ascending' }
          { path: '/_ts', order: 'Descending' }
        ]
      ]
    }
  }
]

param containerAppsList = [
  {
    name: null
    external: true
    target_port: 8080
    service_name: 'orchestrator'
    profile_name: 'main'
    min_replicas: 1
    max_replicas: 1
    cpu: '1.0'
    memory: '2.0Gi'
    canonical_name: 'ORCHESTRATOR_APP'
    roles: [
      'AppConfigurationDataReader'
      'CognitiveServicesUser'
      'CognitiveServicesOpenAIUser'
      'AcrPull'
      'CosmosDBBuiltInDataContributor'
      'SearchIndexDataReader'
      'StorageBlobDataReader'
      'KeyVaultSecretsUser'
    ]
  }
]
