$replacements = @{
    'ProgressTransform2DJuiceComp' = 'ProgressTransform2DJuiceComp'
    'ProgressTransform3DJuiceComp' = 'ProgressTransform3DJuiceComp'
    'ProgressTransformControlJuiceComp' = 'ProgressTransformControlJuiceComp'
    'ProgressTransform2DJuiceEffect' = 'ProgressTransform2DJuiceEffect'
    'ProgressTransform3DJuiceEffect' = 'ProgressTransform3DJuiceEffect'
    'ProgressTransformControlJuiceEffect' = 'ProgressTransformControlJuiceEffect'
    'TestProgressTransform2D' = 'TestProgressTransform2D'
    'TestProgressTransform3D' = 'TestProgressTransform3D'
    'TestProgressTransformControl' = 'TestProgressTransformControl'
    'progress_transform_2d' = 'progress_transform_2d'
    'progress_transform_3d' = 'progress_transform_3d'
    'progress_transform_control' = 'progress_transform_control'
    'ProgressTransform2DEffect' = 'ProgressTransform2DEffect'
    'ProgressTransform3DEffect' = 'ProgressTransform3DEffect'
    'ProgressTransformControlEffect' = 'ProgressTransformControlEffect'
}

$files = Get-ChildItem -Path '.' -Recurse -File | Where-Object { 
    $_.FullName -notmatch '\\\.git\\' -and 
    $_.FullName -notmatch '\\\.godot\\' 
}

foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $changed = $false
    foreach ($key in $replacements.Keys) {
        if ($content.Contains($key)) {
            $content = $content.Replace($key, $replacements[$key])
            $changed = $true
        }
    }
    if ($changed) {
        Write-Host "Updating content: $($file.FullName)"
        [System.IO.File]::WriteAllText($file.FullName, $content, (New-Object System.Text.UTF8Encoding $false))
    }
}
