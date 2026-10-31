param([string]$DeviceId = 'NU1455199M308997')
$ErrorActionPreference = 'Stop'
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
Push-Location $PSScriptRoot
try {
    $socketDirectory = Join-Path $PSScriptRoot 'android\.gradle'
    New-Item -ItemType Directory -Path $socketDirectory -Force | Out-Null
    # Avoid Windows temporary-directory socket failures in Java/Gradle.
    $env:JAVA_TOOL_OPTIONS = ($previousJavaOptions + ' "-Djdk.net.unixdomain.tmpdir=' + $socketDirectory + '"').Trim()
    flutter run -d $DeviceId
    $runExitCode = $LASTEXITCODE
} finally {
    $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
    Pop-Location
}
exit $runExitCode
