targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the azd environment. Used as a prefix for all resource names.')
param environmentName string

@minLength(1)
@description('Primary location for all resources.')
param location string

@description('Tags applied to every resource.')
param tags object = {
  'azd-env-name': environmentName
}

@description('Image to use for the api container app on initial deploy. azd overwrites this with the freshly built image.')
param apiImageName string = ''

var abbrs = {
  resourceGroup: 'rg'
  containerAppsEnv: 'cae'
  containerApp: 'ca'
  containerRegistry: 'cr'
  logAnalytics: 'log'
  managedIdentity: 'id'
}

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var resourceGroupName = '${abbrs.resourceGroup}-${environmentName}'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
    abbrs: abbrs
    apiImageName: apiImageName
  }
}

output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.containerRegistryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = resources.outputs.containerRegistryName
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = resources.outputs.containerAppsEnvironmentId
output SERVICE_API_NAME string = resources.outputs.apiContainerAppName
output SERVICE_API_URI string = resources.outputs.apiContainerAppUri
