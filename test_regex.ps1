$tests = @(
    "ProgressTransform2DJuiceComp",
    "PropertyProgress2DJuiceEffect",
    "TestProgressTransform2D",
    "TestProgressProperty",
    "progress_transform_2d",
    "progress_property_2d",
    "ProgressTransformControlEffect"
)

foreach ($t in $tests) {
    $r = $t -creplace '(?<!Property)ProgressTransform2D', 'ProgressTransform2D'
    $r = $r -creplace '(?<!Property)ProgressTransform3D', 'ProgressTransform3D'
    $r = $r -creplace '(?<!Property)ProgressTransformControl', 'ProgressTransformControl'
    $r = $r -creplace '(?<!property_)progress_transform_2d', 'progress_transform_2d'
    $r = $r -creplace '(?<!property_)progress_transform_3d', 'progress_transform_3d'
    $r = $r -creplace '(?<!property_)progress_transform_control', 'progress_transform_control'
    Write-Host "$t -> $r"
}
