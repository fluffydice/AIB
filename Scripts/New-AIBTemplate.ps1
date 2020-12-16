

# Variables
$location = 'NorthEurope'
$subscriptionID = 'cc1ccb8d-18a1-4dca-aa5a-54607876c990'
$imageResourceGroup = 'LP-IMAGEBUILDER-001'
$ARMtemp = 'C:\Scripting\Azure\AIB\ImageTemplate.json'
$apiVersion = '2019-05-01-preview'
$imageTemplateName = 'Win2004Template01'
$imageName = 'win102004Image01'
$publisher = (Get-AzVMImagePublisher -Location $location | Where-Object {$_.PublisherName -like "MicrosoftWindows*"} | Select PublisherName | Out-GridView -PassThru -Title 'Select Publisher').PublisherName
$offer = (Get-AzVMImageOffer -Location $location -PublisherName $publisher | Select Offer | Out-GridView -PassThru -Title 'Select Offer').Offer
$sku = (Get-AzVMImageSku -Location $location -PublisherName $publisher -Offer $offer | Select Skus | Out-GridView -PassThru -Title 'Select Sku').Skus
$vmSize = 'Standard_D1_v2'
$vmDiskSize = 127
$buildTimeoutInMinutes = 100
$imageTemplateTag = 'Windows-10-2004'
$runOutputName = 'win102004ImageOut01'

$identityName = 'LPaibBuiUserId_201214130723'
$identityNameResourceId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).Id


# Set deployment name
$Name = "deploy_AIBTemplate_$(Get-Date -f yyMMddHHmmss)"


# Run deployment to submit the template
$deployment = New-AzResourceGroupDeployment -ErrorAction Stop -Name $Name `
  -location $location `
  -subscriptionID $subscriptionID `
  -resourceGroupName $imageResourceGroup `
  -TemplateFile $ARMtemp `
  -apiVersion $apiVersion `
  -imageTemplateName $imageTemplateName `
  -imageName $imageName `
  -publisher $publisher `
  -offer $offer `
  -sku $sku `
  -vmSize $vmSize `
  -vmDiskSize $vmDiskSize `
  -buildTimeoutInMinutes $buildTimeoutInMinutes `
  -imageTemplateTag $imageTemplateTag `
  -runOutputName $runOutputName `
  -identityNameResourceId $identityNameResourceId


# Build the image
# Note this cmdlet will not wait for the AIB service to complete the image build
# This can take up to an hour to complete
Invoke-AzResourceAction -ResourceName $imageTemplateName -ResourceGroupName $imageResourceGroup -ResourceType Microsoft.VirtualMachineImages/imageTemplates -ApiVersion $apiVersion -Action Run -Force

# Check status
Get-AzImageBuilderTemplate -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup | Select-Object -Property Name, LastRunStatusRunState, LastRunStatusMessage, ProvisioningState



