https://docs.microsoft.com/en-us/azure/virtual-machines/windows/image-builder
# one off Setup variables

# Install POSH modules for image builder
'Az.ImageBuilder', 'Az.ManagedServiceIdentity' | ForEach-Object {Install-Module -Name $_ -AllowPrerelease}

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

# Create resource group used specially for AIB
New-AzResourceGroup -Location $location -Name $imageResourceGroup

# Install posh module
Install-Module -Name Az.ManagedServiceIdentity -AllowPrerelease

# create user assigned identity for image builder to access the storage account where the script is located
$Manageduserident="JLaibBuiUserId$(get-date +'%s')"
New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $Manageduserident

# download preconfigured custom role definition example
(Invoke-WebRequest -Uri "https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json").content | out-file C:\scratch\aibRoleImageCreation.json

# get the user identity URI (id), needed for the custom role
$imgBuilderId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup).ID


$imageRoleDefName = "Azure Image Builder Image R1"

# update the role file definition file 
(get-content C:\scratch\aibRoleImageCreation.json -raw) -replace '<subscriptionID>',$subscriptionID -replace '<rgName>',$imageResourceGroup -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName | Set-Content C:\scratch\aibRoleImageCreation.json

# create role definitions
New-AzRoleDefinition -InputFile C:\Scratch\aibRoleImageCreation.json

# grant role definition to the user assigned identity
New-AzRoleAssignment -ApplicationId $imgBuilderCliId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"

# Get example customiser template 
(Invoke-WebRequest -Uri "https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/quickquickstarts/0_Creating_a_Custom_Windows_Managed_Image/helloImageTemplateWin.json").content | out-file C:\scratch\imgtemplate.json

# Replace text in template

(get-content C:\scratch\imgtemplate.json -raw) -replace '<subscriptionID>',$subscriptionID `
-replace 'rgName>',$imageResourceGroup `
-replace '<region>',$location `
-replace '<imageName>',$imageName `
-replace '<runOutputName>',$runOutputName `
-replace '<imgBuilderId>',$imgBuilderId `
| Set-Content C:\scratch\imgtemplate.json

##### Variables #####

# Resource group name - we are using myImageBuilderRG in this example
$imageResourceGroup="JL-IMAGEBUILDER"
# Region location 
$location="NorthEurope"
# Name for the image 
$imageName="myWinBuilderImage"
# Distribution properties of the managed image upon completion
$runOutputName="Windows10"
# name of the image to be created
$imageName="JLaibWinImage"
# Name of the image to be created
$imageTemplateName = 'JLWin10-20h2'
# Sub ID
$subscriptionID="cc1ccb8d-18a1-4dca-aa5a-54607876c990"
# Image Gallery
$myGalleryName = 'IMGGALLERYJL'
$imageDefName = 'win10Images'
$OSstate = 'generalized'
$OSType = 'Windows'
$galpublisher = 'Jamie'
$galoffer = 'Windows'
$galsku = 'Win10'
# Source Image 
$Publisher = 'MicrosoftWindowsDesktop'
$offer = 'windows-10'
$sku = '20h2-ent'

###### Execute ######

# get identity client id

$Manageduserident = 'JLaibBuiUserId'
$imgBuilderCliId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $Manageduserident).ClientID
$identityNameResourceId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $Manageduserident).Id
$identityNamePrincipalId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $Manageduserident).PrincipalId

# Create image gallery
New-AzGallery -GalleryName $myGalleryName -ResourceGroupName $imageResourceGroup -Location $location

# Create shared image gallery image definition
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

# Azure Marketplace source image definition
$SrcObjParams = @{
  SourceTypePlatformImage = $true
  Publisher = $Publisher
  Offer = $offer
  Sku = $sku
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

# Reference Image customisation object
$ImgCustomParams = @{
  PowerShellCustomizer = $true
  CustomizerName = 'JL-filesystem-mod'
  RunElevated = $false
  Inline = @("mkdir c:\\buildActions", "echo JL Azure-Image-Builder-Was-Here  > c:\\buildActions\\buildActionsOutput.txt")
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

###### Stop Execute #####
