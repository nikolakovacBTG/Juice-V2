$renameMap = @{
    'Progress2DJuiceComp.gd' = 'ProgressTransform2DJuiceComp.gd'
    'Progress3DJuiceComp.gd' = 'ProgressTransform3DJuiceComp.gd'
    'ProgressControlJuiceComp.gd' = 'ProgressTransformControlJuiceComp.gd'
    'Progress2DJuiceEffect.gd' = 'ProgressTransform2DJuiceEffect.gd'
    'Progress3DJuiceEffect.gd' = 'ProgressTransform3DJuiceEffect.gd'
    'ProgressControlJuiceEffect.gd' = 'ProgressTransformControlJuiceEffect.gd'
    'Progress2DJuiceEffect.gd.uid' = 'ProgressTransform2DJuiceEffect.gd.uid'
    'Progress3DJuiceEffect.gd.uid' = 'ProgressTransform3DJuiceEffect.gd.uid'
    'ProgressControlJuiceEffect.gd.uid' = 'ProgressTransformControlJuiceEffect.gd.uid'
    'TestProgress2D.gd' = 'TestProgressTransform2D.gd'
    'TestProgress3D.gd' = 'TestProgressTransform3D.gd'
    'TestProgressControl.gd' = 'TestProgressTransformControl.gd'
    'TestProgress2D.gd.uid' = 'TestProgressTransform2D.gd.uid'
    'TestProgress3D.gd.uid' = 'TestProgressTransform3D.gd.uid'
    'TestProgressControl.gd.uid' = 'TestProgressTransformControl.gd.uid'
    'progress_2d.log' = 'progress_transform_2d.log'
    'progress_3d.log' = 'progress_transform_3d.log'
    'progress_control.log' = 'progress_transform_control.log'
}

$files = Get-ChildItem -Path '.' -Recurse -File | Where-Object { 
    $_.FullName -notmatch '\\\.git\\' -and 
    $_.FullName -notmatch '\\\.godot\\' 
}

foreach ($file in $files) {
    if ($renameMap.ContainsKey($file.Name)) {
        $newName = $renameMap[$file.Name]
        $newPath = Join-Path (Split-Path $file.FullName) $newName
        Write-Host "Renaming: $($file.Name) -> $newName"
        git mv "$($file.FullName)" "$newPath"
    }
}
