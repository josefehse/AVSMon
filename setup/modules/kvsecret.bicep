param secretname string
@secure()
param secretvalue string
param Tags object
param vaultName string

resource vault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: vaultName
}

resource kvsecret1 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  name: secretname
  tags: Tags
  parent: vault
  properties: {
    attributes: {
      enabled: true
    }
    contentType: 'string'
    value: secretvalue
  }
}
