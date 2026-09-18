$users = Get-Content -Path "$env:USERPROFILE\Downloads\New Text Document.txt"
$assets = Get-SnipeitAsset -all

$results = foreach ($user in $users) {

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

$results | Export-Csv -Path "C:\Temp\assets.csv" -NoTypeInformation