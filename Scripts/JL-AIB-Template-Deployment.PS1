# Variables
$ResourceGroup = "JL-IMAGEBUILDER"
$apiversion = '2019-05-01-preview'
$buildTimeoutInMinutes = 100
$TemplateFile = "C:\scratch\AIB\Templates\AIB-Gallery-Image-Template.json"
###CHANGE THIS VARIABLE IF THE TEMPLATE ALREADY EXISTS AS YOU CANNOT UPDATE EXISTING TEMPLATES###
$imageTemplateName = 'JLWin10-20h2-APPS-GALLERY'
#################################################################################################
$Azurelocation = "NorthEurope"
$subscriptionID ="cc1ccb8d-18a1-4dca-aa5a-54607876c990"
$Gallery = 'IMGGALLERYJL'
$imagename = 'Windows10-20h2'
$imageDefName = 'win10Images'
$OSstate = 'generalized'
$OSType = 'Windows'
$galpublisher = 'Jamie'
$galoffer = 'Windows'
$galsku = 'Win10'
$Name = "deploy_JL_AIBTemplate_$(Get-Date -f yyMMddHHmmss)"
# Source Image 
$Publisher = 'MicrosoftWindowsDesktop'
$offer = 'windows-10'
$sku = '20h2-ent'
# New VM parameters
$VMLocalAdminUser = "bob"
$VMLocalAdminSecurePassword = ConvertTo-SecureString "NotMouseTrap1793" -AsPlainText -Force
$VMSize = "Standard_D2s_v3"
$vmDiskSize = 127
$VMName = "MyVM"
$runOutputName = 'win1020h1ImageOut'
$Manageduserident = 'JLaibBuiUserId'
$identityNameResourceId = (Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroup -Name $Manageduserident).Id


# Execute AIB template

New-AzResourceGroupDeployment -ErrorAction STOP `
-name $name `
-location $Azurelocation `
-subscriptionID $subscriptionID `
-ResourceGroupName $resourceGroup `
-RGroupName $ResourceGroup `
-TemplateFile $TemplateFile `
-apiversion $apiversion `
-imageTemplateName $imageTemplateName `
-imagename $imageDefName `
-Publisher $Publisher `
-offer $offer `
-sku $sku `
-vmsize $VMSIZE `
-vmDiskSize $vmDiskSize `
-buildTimeoutInMinutes $buildTimeoutInMinutes `
-imageTemplateTag $imageTemplateName `
-runOutputName $runOutputName `
-identityNameResourceId $identityNameResourceId `
-Gallery $Gallery

# Create the refrence image build / Submit to the Image Builder service - could take a while
Start-AzImageBuilderTemplate -ResourceGroupName $ResourceGroup -Name $imageTemplateName

# Get status
# Get image builder template creation run state - only method to troubleshoot template creation errors
Get-AzImageBuilderTemplate -ImageTemplateName $imageTemplateName -ResourceGroupName $ResourceGroup | Select-Object -Property Name, LastRunStatusRunState, LastRunStatusMessage, ProvisioningState

# Create VM with reference image created above
$ArtifactId = (Get-AzImageBuilderRunOutput -ImageTemplateName $imageTemplateName -ResourceGroupName $ResourceGroup).ArtifactId

$cred = get-credential

New-AzVM `
-ResourceGroupName $ResourceGroup `
-Image $ArtifactId `
-Name myWinVM01 `
-Credential $Cred `
-Size $VMSize

# Run this to cleanup resources - delete the image builder template
Remove-AzImageBuilderTemplate -ResourceGroupName $ResourceGroup -Name $imageTemplateName