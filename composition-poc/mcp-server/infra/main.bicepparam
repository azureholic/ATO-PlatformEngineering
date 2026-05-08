using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'catalog-mcp')
param location        = readEnvironmentVariable('AZURE_LOCATION', 'swedencentral')
param apiImageName    = readEnvironmentVariable('SERVICE_API_IMAGE_NAME', '')
