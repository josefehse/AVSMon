Get-Folder -Name "Datacenters" | Get-Inventory | Get-VIPermission | Select-Object Entity, Principal, Role, Propagate
