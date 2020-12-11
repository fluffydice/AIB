# Get image builder template creation run state - only method to troubleshoot template creation errors
Get-AzImageBuilderTemplate -ImageTemplateName LP-WinImage2 -ResourceGroupName LP-IMAGEBUILDER2 | Select-Object -Property Name, LastRunStatusRunState, LastRunStatusMessage, ProvisioningState

# Get image builder template info

get-AzImageBuilderTemplate 

$managementEp = $currentAzureContext.Environment.ResourceManagerUrl

$urlBuildStatus = [System.String]::Format("{0}subscriptions/{1}/resourceGroups/$imageResourceGroup/providers/Microsoft.VirtualMachineImages/imageTemplates/{2}?api-version=2020-02-14", $managementEp, $currentAzureContext.Subscription.Id,$imageTemplateName)

$buildStatusResult = Invoke-WebRequest -Method GET  -Uri $urlBuildStatus -UseBasicParsing -Headers  @{"Authorization"= ("Bearer " + $accessToken)} -ContentType application/json 
$buildJsonStatus =$buildStatusResult.Content
$buildJsonStatus

# Cleanup commands
# Remove the Image Builder template to reset config and remove temporary AIB resource group
Remove-AzImageBuilderTemplate -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup

# Troubleshoot AIB
https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-troubleshoot