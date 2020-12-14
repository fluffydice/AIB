
####################### 
# Modules and features
#######################

# Modules
'Az.ImageBuilder', 'Az.ManagedServiceIdentity' | ForEach-Object {Install-Module -Name $_ -AllowPrerelease}

# Register Azure VM builder feature
Register-AzProviderFeature -ProviderNamespace Microsoft.VirtualMachineImages -FeatureName VirtualMachineTemplatePreview

# Check AIB registration state
Get-AzProviderFeature -ProviderNamespace Microsoft.VirtualMachineImages -FeatureName VirtualMachineTemplatePreview

# Resource providers
Get-AzResourceProvider -ProviderNamespace Microsoft.Compute, Microsoft.KeyVault, Microsoft.Storage, Microsoft.VirtualMachineImages | Where-Object RegistrationState -ne Registered | Register-AzResourceProvider



############ 
# Variables
############

# Destination image resource group name
$imageResourceGroup = 'LP-IMAGEBUILDER12'

# Azure region
$location = 'NorthEurope'

# Distribution properties of the managed image upon completion
$runOutputName = 'LP-DistResults12'

# Name of the image to be created
$imageTemplateName = 'LP-WinImage12'

# Subscription
$subscriptionID = 'cc1ccb8d-18a1-4dca-aa5a-54607876c990'

# Identity
$imageRoleDefName = "Azure Image Builder Image Def LP12"
$identityName = "LPaibBuiUserId_$(Get-Date -f yyMMddHHmmss)"

# Shared image gallery
$myGalleryName = 'LPImageGallery12'
$imageDefName = 'win10Images12'
$OSstate = 'generalized'
$OSType = 'Windows'
$galpublisher = 'Lee'
$galoffer = 'Windows'
$galsku = 'Win10'

# Grab publisher, offer and sku info for source image (used by source object)
$publisher = (Get-AzVMImagePublisher -Location $location | Where-Object {$_.PublisherName -like "MicrosoftWindows*"} | Select PublisherName | Out-GridView -PassThru -Title 'Select Publisher').PublisherName
$offer = (Get-AzVMImageOffer -Location $location -PublisherName $publisher | Select Offer | Out-GridView -PassThru -Title 'Select Offer').Offer
$sku = (Get-AzVMImageSku -Location $location -PublisherName $publisher -Offer $offer | Select Skus | Out-GridView -PassThru -Title 'Select Sku').Skus




######################################### 
# RG, User Identity and Role Permissions
#########################################

# Create RG
New-AzResourceGroup -Name $imageResourceGroup -Location $location

# Create Identity
New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName
$identityNameCliId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).ClientID
$identityNameResourceId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).Id
$identityNamePrincipalId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).PrincipalId

# Download and update custom role definition
$myRoleImageCreationUrl = 'https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json'
$myRoleImageCreationPath = "C:\Scripting\Azure\AIB\LP-RoleImageCreation12.json"

Invoke-WebRequest -Uri $myRoleImageCreationUrl -OutFile $myRoleImageCreationPath -UseBasicParsing

$Content = Get-Content -Path $myRoleImageCreationPath -Raw
$Content = $Content -replace '<subscriptionID>', $subscriptionID
$Content = $Content -replace '<rgName>', $imageResourceGroup
$Content = $Content -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName
$Content | Out-File -FilePath $myRoleImageCreationPath -Force

# Role Definition
New-AzRoleDefinition -InputFile $myRoleImageCreationPath


# Grant the role definition to the image builder service principal
$RoleAssignParams = @{
    ApplicationId = $identityNameCliId
    RoleDefinitionName = $imageRoleDefName
    Scope = "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"
  }
  New-AzRoleAssignment @RoleAssignParams





###################################### 
# Shared image gallery and definition
######################################

# Create shared image gallery
New-AzGallery -GalleryName $myGalleryName -ResourceGroupName $imageResourceGroup -Location $location


# Create a gallery definition
$GalleryParams = @{
    GalleryName = $myGalleryName
    ResourceGroupName = $imageResourceGroup
    Location = $location
    Name = $imageDefName
    OsState = $OSstate
    OsType = $OSType
    Publisher = $galpublisher
    Offer = $galoffer
    Sku = $galsku
  }
  New-AzGalleryImageDefinition @GalleryParams




################ 
# Create Image
################

# Create source object
$SrcObjParams = @{
    SourceTypePlatformImage = $true
    Publisher = $publisher
    Offer = $offer
    Sku = $sku
    Version = 'latest'
  }
 $srcPlatform = New-AzImageBuilderSourceObject @SrcObjParams

# Create an Azure image builder distributor object
  $disObjParams = @{
    SharedImageDistributor = $true
    ArtifactTag = @{tag='dis-share'}
    GalleryImageId = "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup/providers/Microsoft.Compute/galleries/$myGalleryName/images/$imageDefName"
    ReplicationRegion = $location
    RunOutputName = $runOutputName
    ExcludeFromLatest = $false
  }
  $disSharedImg = New-AzImageBuilderDistributorObject @disObjParams

# Create an Azure image builder customization object
  $ImgCustomParams = @{
    PowerShellCustomizer = $true
    CustomizerName = 'settingUpMgmtAgtPath'
    RunElevated = $false
    Inline = @("mkdir c:\\buildActions", "echo Azure-Image-Builder-Was-Here  > c:\\buildActions\\buildActionsOutput.txt")
  }
  $Customizer = New-AzImageBuilderCustomizerObject @ImgCustomParams

# Create an Azure image builder template (using $srcPlatform, $disSharedImg and $Customizer from above, plus the other VARs already created)
  $ImgTemplateParams = @{
    ImageTemplateName = $imageTemplateName
    ResourceGroupName = $imageResourceGroup
    Source = $srcPlatform
    Distribute = $disSharedImg
    Customize = $Customizer
    Location = $location
    UserAssignedIdentityId = $identityNameResourceId
  }
  New-AzImageBuilderTemplate @ImgTemplateParams



# Check template creation
Get-AzImageBuilderTemplate -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup | Select-Object -Property Name, LastRunStatusRunState, LastRunStatusMessage, ProvisioningState

# Remove a template
Remove-AzImageBuilderTemplate -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup



##################################################### 
# Start the image build (submit image to AIB service)
#####################################################

# This can take up to an hour
Start-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName

# Check status
Get-AzImageBuilderTemplate -ImageTemplateName  $imageTemplateName -ResourceGroupName $imageResourceGroup | Select-Object ProvisioningState, ProvisioningErrorMessage





################################################
# Create a VM
# For creds enter local admin / password for VM
################################################
$Cred = Get-Credential

$ArtifactId = (Get-AzImageBuilderRunOutput -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup).ArtifactId
New-AzVM -ResourceGroupName $imageResourceGroup -Image $ArtifactId -Name LP0003 -Credential $Cred






################################################
# Tidy up and removal
################################################

$imageTemplateName = 'LP-WinImage12'
$imageResourceGroup = 'LP-IMAGEBUILDER12'

Get-AzImageBuilderTemplate -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup | Select-Object -Property Name, LastRunStatusRunState, LastRunStatusMessage, ProvisioningState

Remove-AzImageBuilderTemplate -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup

Remove-AzResourceGroup -Name 'LP-IMAGEBUILDER2' -Force