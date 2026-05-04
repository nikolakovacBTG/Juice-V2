$files = Get-ChildItem -Path '.' -Recurse -File | Where-Object { 
    $_.FullName -notmatch '\\\.git\\' -and 
    $_.FullName -notmatch '\\\.godot\\' 
}

foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $newContent = $content
    
    $newContent = $newContent -creplace '(?<!Property)ProgressTransform2D', 'ProgressTransform2D'
    $newContent = $newContent -creplace '(?<!Property)ProgressTransform3D', 'ProgressTransform3D'
    $newContent = $newContent -creplace '(?<!Property)ProgressTransformControl', 'ProgressTransformControl'
    $newContent = $newContent -creplace '(?<!property_)progress_transform_2d', 'progress_transform_2d'
    $newContent = $newContent -creplace '(?<!property_)progress_transform_3d', 'progress_transform_3d'
    $newContent = $newContent -creplace '(?<!property_)progress_transform_control', 'progress_transform_control'
    
    if ($newContent -cne $content) {
        Write-Host "Updating content: $($file.FullName)"
        [System.IO.File]::WriteAllText($file.FullName, $newContent, (New-Object System.Text.UTF8Encoding $false))
    }
}
