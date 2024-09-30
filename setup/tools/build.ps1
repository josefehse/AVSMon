# Builds the functions and packages them into a zip file
$currentFolder= Get-Location
$functionlist=@('AVSMon1','AVSMon2')
Set-Location $currentFolder
#Set-Location 'setup/backend/Function/code'
$DestinationPath='./setup/functions/functions.zip'
Remove-Item $DestinationPath -ErrorAction SilentlyContinue
foreach ($function in $functionlist) {
     Compress-archive "./$function/" $DestinationPath -Update
}
Compress-Archive "./*.ps1" $DestinationPath -Update
Compress-Archive "./*.psd1" $DestinationPath -Update
Compress-Archive "./host.json" $DestinationPath -Update

# creates ARM template from bicep files to allow for custom UI deployment
Set-Location $currentFolder
bicep build ./setup/avsmon.bicep
