# Load VMware PowerCLI module
Import-Module VMware.PowerCLI

# Connect to vCenter Server
Connect-VIServer -Server vcenter_server_name

# Connect to HCX Server
Connect-HCXServer -Server hcx_server_name -User hcx_user -Password hcx_password

# Get HCX Server information
$hcxServers = Get-HCXServer

# Loop through each HCX server and check its status
foreach ($hcxServer in $hcxServers) {
    Write-Output "HCX Server: $($hcxServer.Name), Status: $($hcxServer.Status), High Availability: $($hcxServer.HighAvailability)"
}

# Disconnect from HCX Server
Disconnect-HCXServer -Confirm:$false

# Disconnect from vCenter Server
Disconnect-VIServer -Confirm:$false
