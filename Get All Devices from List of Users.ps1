Write-Host "UPN's should be what's in the file. Not usernames" -ForegroundColor Yellow

$usersFile = Read-Host "Enter path of user file"
$users = Get-Content -Path $usersFile

$assets = Get-SnipeitAsset -all

$results = foreach ($user in $users) {

    $user = $user.Trim()

    $userAssets = $assets | Where-Object {
        $_.assigned_to.username -eq $user
    }

    if ($userAssets) {
        $userAssets | Select-Object `
            @{Name='User'; Expression={$_.assigned_to.name}},
            @{Name='Model'; Expression={$_.model.name}},
            @{Name='Asset Tag'; Expression={$_.asset_tag}},
            @{Name='Serial'; Expression={$_.serial}}
    }
    else {
        [PSCustomObject]@{
            User        = $user
            Model       = 'NO ASSETS'
            'Asset Tag' = 'NO ASSETS'
            Serial      = 'NO ASSETS'
        }
    }
}

$results | Export-Csv -Path "C:\Temp\userassets.csv" -NoTypeInformation

if ($?) {
    Write-Host "Results exported to C:\Temp\userassets.csv" -ForegroundColor Yellow
}
else {
    Write-Host "Export failed" -ForegroundColor Red
}
