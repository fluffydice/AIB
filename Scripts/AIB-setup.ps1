https://docs.microsoft.com/en-us/azure/virtual-machines/windows/image-builder

# Install POSH modules for image builder
'Az.ImageBuilder', 'Az.ManagedServiceIdentity' | ForEach-Object {Install-Module -Name $_ -AllowPrerelease}

# Variables
# Resource group name - we are using myImageBuilderRG in this example
$imageResourceGroup="JL-IMAGEBUILDER"
# Region location 
$location="NorthEurope"
# Name for the image 
$imageName="myWinBuilderImage"
# Run output name
$runOutputName="aibWindows"
# name of the image to be created
$imageName="JLaibWinImage"
# Name of the image to be created
$imageTemplateName = 'JLaibWin10-2004'

# Distribution properties of the managed image upon completion
$runOutputName = 'myDistResults'

# Sub ID
$subscriptionID="cc1ccb8d-18a1-4dca-aa5a-54607876c990"
$myGalleryName = 'IMGGALLERYJL'
$imageDefName = 'win10Images'

# Create image gallery
New-AzGallery -GalleryName $myGalleryName -ResourceGroupName $imageResourceGroup -Location $location

#Create image gallery definition
$GalleryParams = @{
  GalleryName = $myGalleryName
  ResourceGroupName = $imageResourceGroup
  Location = $location
  Name = $imageDefName
  OsState = 'generalized'
  OsType = 'Windows'
  Publisher = 'Jamie'
  Offer = 'Windows'
  Sku = 'Win10'
}
New-AzGalleryImageDefinition @GalleryParams

# Azure Marketplace image definition
$SrcObjParams = @{
  SourceTypePlatformImage = $true
  Publisher = 'MicrosoftWindowsDesktop'
  Offer = 'office-365'
  Sku = '20h1-evd-o365pp'
  Version = 'latest'
}

$srcPlatform = New-AzImageBuilderSourceObject @SrcObjParams

# Image distributor object
$disObjParams = @{
  SharedImageDistributor = $true
  ArtifactTag = @{tag='dis-share'}
  GalleryImageId = "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup/providers/Microsoft.Compute/galleries/$myGalleryName/images/$imageDefName"
  ReplicationRegion = $location
  RunOutputName = $runOutputName
  ExcludeFromLatest = $false
}
$disSharedImg = New-AzImageBuilderDistributorObject @disObjParams

# Image customisation object
$ImgCustomParams = @{
  PowerShellCustomizer = $true
  CustomizerName = 'settingUpMgmtAgtPath'
  RunElevated = $false
  Inline = @("mkdir c:\\buildActions", "echo Azure-Image-Builder-Was-Here  > c:\\buildActions\\buildActionsOutput.txt")
}
$Customizer = New-AzImageBuilderCustomizerObject @ImgCustomParams

# Image builder template object
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


 Start-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName


# Register Azure VM builder feature
Register-AzProviderFeature -FeatureName virtualMAchinetemplatepreview

# Get feature registration status
Get-AzProviderFeature -featurename virtualmachinetemplatepreview -ProviderNamespace Microsoft.VirtualMachineimages

# Get each resource provider registration status
Get-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineimages

# Register providers if needed
Register-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
Register-AzResourceProvider -ProviderNamespace Microsoft.KeyVault
Register-AzResourceProvider -ProviderNamespace Microsoft.Compute

# Locations
East US
East US 2
West Central US
West US
West US 2
South Central US
North Europe
West Europe

# Create resource group
New-AzResourceGroup -Location $location -Name $imageResourceGroup

Create a user-assigned identity and set permissions on the resource group
Image Builder will use the user-identity provided to inject the image into the resource group. In this example, you will create an Azure role definition that has the granular actions to perform distributing the image. The role definition will then be assigned to the user-identity.

# Install posh module
Install-Module -Name Az.ManagedServiceIdentity -AllowPrerelease



New-AzGallery -GalleryName $myGalleryName -ResourceGroupName $imageResourceGroup -Location $location


# create user assigned identity for image builder to access the storage account where the script is located
$identityName="JLaibBuiUserId$(date +'%s')"
New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName

# get identity client id
$imgBuilderCliId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup).ClientID
$identityNameResourceId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).Id
$identityNamePrincipalId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).PrincipalId


# get the user identity URI (id), needed for the template
$imgBuilderId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup).ID

# download preconfigured role definition example
(Invoke-WebRequest -Uri "https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json").content | out-file C:\scratch\aibRoleImageCreation.json

$imageRoleDefName = "Azure Image Builder Image R1"

# update the definition
(get-content C:\scratch\aibRoleImageCreation.json -raw) -replace '<subscriptionID>',$subscriptionID -replace '<rgName>',$imageResourceGroup -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName | Set-Content C:\scratch\aibRoleImageCreation.json

# create role definitions
New-AzRoleDefinition -InputFile C:\Scratch\aibRoleImageCreation.json

# grant role definition to the user assigned identity
New-AzRoleAssignment -ApplicationId $imgBuilderCliId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"

# Get example template 
(Invoke-WebRequest -Uri "https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/quickquickstarts/0_Creating_a_Custom_Windows_Managed_Image/helloImageTemplateWin.json").content | out-file C:\scratch\imgtemplate.json

# Replace text in template

(get-content C:\scratch\imgtemplate.json -raw) -replace '<subscriptionID>',$subscriptionID `
-replace 'rgName>',$imageResourceGroup `
-replace '<region>',$location `
-replace '<imageName>',$imageName `
-replace '<runOutputName>',$runOutputName `
-replace '<imgBuilderId>',$imgBuilderId `
| Set-Content C:\scratch\imgtemplate.json

# Create reference image

New-AzResourceGroupDeployment \
    --resource-group $imageResourceGroup \
    --properties @helloImageTemplateWin.json \
    --is-full-object \
    --resource-type Microsoft.VirtualMachineImages/imageTemplates \
    -n helloImageTemplateWin01
