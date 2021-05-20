$params = @{
    resourceGroupName     = "SoftwareInstallation" # <-- Change this value for the Resource Group Name
    storageAccountName    = "strsi01a" # <-- Change this value - must be globally unique
    location              = "australiasoutheast" # <-- Change this value to a location you want
    automationAccountName = "siaa01" # <-- Change this value for the Automation Account Name
}

New-AzResourceGroup -Name $params.resourceGroupName -Location 'australiasoutheast' -Force

Write-Host "Deploying Infrastructure" -ForegroundColor Green
New-AzResourceGroupDeployment -ResourceGroupName $params.resourceGroupName -TemplateFile .\deploy.bicep -TemplateParameterObject $params -Verbose

$ctx = (Get-AzStorageAccount -ResourceGroupName $params.resourceGroupName -StorageAccountName $params.storageAccountName).Context

$automationAccount = Get-AzAutomationAccount -ResourceGroupName $params.resourceGroupName -Name $params.automationAccountName

Write-Host "Downloading PowerShell 7-x64" -ForegroundColor Green
Invoke-WebRequest -Uri "https://github.com/PowerShell/PowerShell/releases/download/v7.1.3/PowerShell-7.1.3-win-x64.msi" -OutFile "$env:TEMP\PowerShell-7.1.3-win-x64.msi"

Write-Host "Uploading file to storage account" -ForegroundColor Green
Set-AzStorageBlobContent -File "$env:TEMP\PowerShell-7.1.3-win-x64.msi" -Blob "PowerShell-7.1.3-win-x64.msi" -Container software -Context $ctx -Force

Write-Host "Publishing runbook to automation account" -ForegroundColor Green
$automationAccount | Import-AzAutomationRunbook -Name deployPowerShell -Path .\deployPowerShell.ps1 -Type PowerShell -Force -Published

Write-Host "Generating webhook" -ForegroundColor Green
$wh = $automationAccount | New-AzAutomationWebhook -Name WH1 -ExpiryTime (Get-Date).AddYears(1) -RunbookName deployPowerShell -IsEnabled $true -Force

Write-Host "Deploying event grid subscription and software installation policy" -ForegroundColor Green
New-AzResourceGroupDeployment -ResourceGroupName $params.resourceGroupName `
    -TemplateFile .\eventgrid.bicep `
    -uri ($wh.WebhookURI | ConvertTo-SecureString -AsPlainText -Force) `
    -location $params.location `
    -topicName "PolicyStateChanges" `
    -Verbose
