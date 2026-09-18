# Get all disabled users from Snipe-IT
$list = @()

$disabledusers = Get-SnipeitUser -all | Where-Object {$_.activated -eq $false}

$list = $disabledusers

Write-Host "There are"$($disabledusers).count"disabled users." -ForegroundColor Magenta


# Ask if the user wants to see the disabled users list
$question = Read-Host "Expand users list?"

$displayList = @()

if ($question -like "y") {
    Write-Host ""
    $psc = 1

    # Build a simplified list of users for display
    foreach ($user in $list) {
        $row = [PSCustomObject]@{
            "Instance #"        = $psc
            "Snipe ID"          = $user.id # Snipe-IT's internal user ID
            Name                = $user.name
            #Email              = $user.email
            Manager             = $user.manager.name
            #Department         = $user.department.name
            "# of Assets"       = $user.assets_count
            "# of Accessories"  = $user.accessories_count
            "Zeroed"            = if ($user.assets_count -eq 0 -and $user.accessories_count -eq 0) { $true } else { $false }
            Notes               = $user.notes
        }
        $displayList += $row
        $psc++
    }

    # use switch to sort based on properties below
    $sort = Read-Host "Choose sorting property (Name, Email, Manager, Assets, Accessories, Zeroed, Notes, Instance #, Snipe ID)"

    switch ($sort.ToLower()) {
        "name"        { $displayList | Sort-Object Name | Format-Table }
        "email"       { $displayList | Sort-Object Email | Format-Table }
        "manager"     { $displayList | Sort-Object Manager | Format-Table }
        "assets"      { $displayList | Sort-Object "# of Assets" | Format-Table }
        "accessories" { $displayList | Sort-Object "# of Accessories" | Format-Table }
        "zeroed"      { $displayList | Sort-Object "Zeroed" | Format-Table }
        "notes"       { $displayList | Sort-Object Notes | Format-Table }
        "instance #"  { $displayList | Sort-Object "Instance #" | Format-Table }
        "snipe id"    { $displayList | Sort-Object "Snipe ID" | Format-Table }
        default       { Write-Host "Invalid sort option." -ForegroundColor Red }
    }

    # Display users sorted by their notes
    # $displayList | Sort-Object Notes -Descending | Format-Table
}


# Get the instance number of the user to expand
do {
    $input = Read-Host "Type Instance # to view assets/accessories"
} while ($input -notmatch '^\d+$')

[int]$question2 = $input

Write-Host ""


# Find the selected user from the displayed list
$selectedUser = $displayList | Where-Object { $_.'Instance #' -eq [int]$question2 }


# Get and display assets assigned to the selected user
if ($selectedUser) {
    $assets = Get-SnipeitAsset -search $selectedUser.Name

    foreach ($asset in $assets) {
        [PSCustomObject]@{
            #User            = $asset.assigned_to.name
            Category        = $asset.category.name
            Model           = $asset.model.name
            "Asset Tag"     = $asset.asset_tag
            "Serial Number" = $asset.serial
        }
    }
}


# Get and display accessories assigned to the selected user
if ($selectedUser) {
    $accessories = Get-SnipeitAccessory -user_id $selectedUser.'Snipe ID'

    foreach ($accessory in $accessories) {
        $accessoriesobject = [PSCustomObject]@{
            #User                = $selectedUser.Name
            "Accessory Item(s)" = $accessory.name
        }
    }
}

$accessoriesobject | Format-Table -AutoSize

# Display instructions for adding a note to the user's profile
Write-Host "To add a note to the users profile run this command 'Set-SnipeitUser -id xxxx -notes'`n " -ForegroundColor Yellow