### Script to set snipe assets after deployment and check Intune primary user


<#
id name
-- ----
88 Sealed/New
15 BYOD
12 Lost
 9 Final Surplus
 8 Stage 2 Surplus
 7 Stage 1 Surplus
 6 Legal Hold
 5 Out for Repair
 4 Deployed
 1 Pending
 2 Ready to Deploy
 3 Archived
#>


function Set-PostNewHireDeployments {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Username
    )
    
    $User = Get-SnipeitUser -username $Username

    $Assets = Get-SnipeitAsset -user_id $User.id

    $location = Get-SnipeitLocation -id 4

    foreach ($Asset in $Assets) {
        if ($PSCmdlet.ShouldProcess($Asset.asset_tag, "Set status to Deployed and location to $($location.name)")) {
            Set-SnipeitAsset -id $Asset.id -status_id 4 -rtd_location_id 4 | Out-Null
        }
        $check = Get-SnipeitAsset -id $Asset.id
        if ($check.status.id -eq 4 -and $check.rtd_location.id -eq 4) {
            Write-Host "- '$($Asset.asset_tag)' Updated with Status '$($Asset.status.name)' and Location '$($location.name)' for user '$($Username)'" -ForegroundColor Green
        }
    }
}