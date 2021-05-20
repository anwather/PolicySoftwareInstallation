Param([object]$WebhookData)

$eventData = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)

if ($eventData.subject -match 'microsoft.compute/virtualmachines') {
    $vmName = $eventData.subject.Split('/')[8]
    $vmResourceGroupName = $eventData.subject.Split('/')[4]

    Connect-AzAccount -Identity

    $storageAccountName = Get-AutomationVariable "StorageAccountName"
    $resourceGroupName = Get-AutomationVariable "ResourceGroupName"

    $ctx = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName).Context

    $sasUri = New-AzStorageBlobSASToken -Blob 'PowerShell-7.1.3-win-x64.msi' -Container software -Permission r -ExpiryTime (Get-Date).AddMinutes(30) -Context $ctx -FullUri


    $scriptBlock = @'
$sasUri = "VALUE"

Invoke-WebRequest -Uri $sasUri -OutFile "$env:TEMP\PowerShell-7.1.3-win-x64.msi" -Verbose

Start-Process "$env:Temp\PowerShell-7.1.3-win-x64.msi" -ArgumentList "/quiet /norestart" -Verbose
'@

    $scriptBlock | Out-File $env:Temp\script.ps1

    (Get-Content $env:Temp\script.ps1 -Raw) -replace "VALUE", $sasUri | Set-Content $env:Temp\script.ps1 -Force

    Invoke-AzVMRunCommand -ResourceGroupName $vmResourceGroupName -VMName $vmName -ScriptPath $env:Temp\script.ps1 -CommandId 'RunPowerShellScript' -Verbose
}
else {
    Write-Output "Event subject does not match microsoft.compute"
}


