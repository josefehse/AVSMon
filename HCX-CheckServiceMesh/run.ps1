# Load VMware PowerCLI module
Import-Module VMware.VimAutomation.Hcx

# Connect to vCenter Server
Connect-VIServer -Server vcenter_server_name

# Connect to HCX Server
Connect-HCXServer -Server hcx_server_name -User hcx_user -Password hcx_password

# Get the Service Mesh
$serviceMeshes = Get-HCXServiceMesh

# Initialize an array to hold the results
$result = @()

# Loop through each service mesh and retrieve source site details
foreach ($serviceMesh in $serviceMeshes) {
    $sourceSite = $serviceMesh.SourceSite

    $result += [PSCustomObject]@{
        ServiceMeshName = $serviceMesh.Name
        SourceSiteName = $sourceSite.Name
        SourceSiteID = $sourceSite.Id
        Location = $sourceSite.Location
        vCenter = $sourceSite.VCenter
        Networks = ($sourceSite.Networks | ForEach-Object { $_.Name }) -join ", "
        ComputeResources = ($sourceSite.ComputeResources | ForEach-Object { $_.Name }) -join ", "
        Storage = ($sourceSite.Storage | ForEach-Object { $_.Name }) -join ", "
        ConnectivityStatus = $serviceMesh.ConnectivityStatus
        Status = $serviceMesh.Status
    }
}

# Convert the result to JSON
$jsonArray = $result | ConvertTo-Json -Depth 10

# Print the output
Write-Output "JSON Array Output:"
Write-Output $jsonArray

# Export JSON to a file
$jsonArray | Set-Content -Path "HCXServiceMeshSourceSiteDetails.json"

Write-Output "Source site details of HCX Service Meshes have been listed and saved to HCXServiceMeshSourceSiteDetails.json"

# Disconnect from HCX Server
Disconnect-HCXServer -Confirm:$false

# Disconnect from vCenter Server
Disconnect-VIServer -Confirm:$false
