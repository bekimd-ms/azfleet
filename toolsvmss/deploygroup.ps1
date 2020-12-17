Param(
    [string] $GroupName,
    [string] $Location, 
    [string] $Site = ""
)

New-AzResourceGroup -Name $GroupName -Location $Location

$templateFile = ".\templates\group.json"
$storageEndpointSuffix= ((Get-AzContext).Environment | Get-AzEnvironment).StorageEndpointSuffix

$rg = $GroupName
$dn = $rg + $vmPool

if( $Site -eq "" ) {
    New-AzResourceGroupDeployment -Name $dn -ResourceGroupName $rg `
                              -TemplateFile $templateFile `
                              -StorageEndpointSuffix $storageEndpointSuffix `
                              -verbose
}
else {
       #modify the template for edge site
       $template = get-content ($templateFile) -raw | ConvertFrom-Json -Depth 32

       $edgeSiteParam = @{
           defaultValue = ""
           metadata = @{ 
               description = "Edge site location"
           }
           type = "string"
           }
       $template.parameters | Add-Member -Name "edgeSite" -value $edgeSiteParam -MemberType NoteProperty
   
       $extendedLocation = @{  
               type = "EdgeZone" 
               name = "[parameters('edgeSite')]" 
           }
       $excludedTypes = @('Microsoft.Network/networkSecurityGroups','Microsoft.Storage/storageAccounts','Microsoft.Compute/virtualMachines/extensions')
       $template.resources | %{  if( $_.type -notin $excludedTypes) {$_ | Add-Member -Name "extendedLocation" -value $extendedLocation -MemberType NoteProperty }}
   
       $templateFile = ".\tmp\group.json"
       $template | ConvertTo-Json -depth 32 | set-content ( $templateFile )
   
       New-AzResourceGroupDeployment -Name $dn -ResourceGroupName $rg `
                                      -TemplateFile $templateFile `
                                      -StorageEndpointSuffix $storageEndpointSuffix `
                                      -edgeSite $site `
                                      -verbose
}
                              