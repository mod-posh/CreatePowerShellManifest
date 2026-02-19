param (
    [string]$ModuleName,
    [string]$Source = "",
    [string]$Output = "",
    [string]$Imports,
    [string]$Assemblies = "",
    [string]$Debug = 'false'
)

try {
    Write-Host "::group::Starting the Create PowerShell Module task..."
    Write-Host "::group::Setting up variables"

    $Debug = [System.Convert]::ToBoolean($Debug)

    if ($Debug) {
        Write-Host "DebugMode Enabled : $Debug"
        Write-Host "Root: $PWD"
        Write-Host "Workspace: $env:GITHUB_WORKSPACE"
    }

    $sourcePath = if ([string]::IsNullOrEmpty($Source)) { $env:GITHUB_WORKSPACE } else { Join-Path $env:GITHUB_WORKSPACE $Source }
    $outputPath = if ([string]::IsNullOrEmpty($Output)) { Join-Path $env:GITHUB_WORKSPACE "output" } else { Join-Path $env:GITHUB_WORKSPACE $Output }

    $Manifest = Get-ChildItem -Path $sourcePath -Filter "$ModuleName.psd1" -Recurse
    $ManifestRoot = $Manifest.Directory.FullName
    $Destination = Join-Path $outputPath $ModuleName
    $ManifestPath = Join-Path $Destination "$ModuleName.psd1"

    if ($Debug) {
        Write-Host "ModuleName   : $ModuleName"
        Write-Host "SourcePath   : $sourcePath"
        Write-Host "OutputPath   : $outputPath"
        Write-Host "Destination  : $Destination"
        Write-Host "ManifestPath : $ManifestPath"
        Write-Host "ManifestRoot : $ManifestRoot"
        Write-Host "Imports      : $Imports"
        Write-Host "Assemblies   : $Assemblies"
    }

    $importFolders = $Imports.Split(',')
    $AssemblyDirectories = if ([string]::IsNullOrEmpty($Assemblies)) { @() } else { $Assemblies.Split(',') }

    Write-Host "::endgroup::"
    Write-Host "::group::Install BuildHelpers module"

    if (-not (Get-Module -ListAvailable -Name BuildHelpers)) {
        Install-Module -Name BuildHelpers -Scope CurrentUser -Force
    }
    Import-Module BuildHelpers

    Write-Host "::endgroup::"
    Write-Host "::group::Testing Output"

    if (Test-Path -Path $outputPath) {
        Remove-Item -Path $outputPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Destination | Out-Null

    Write-Host "::endgroup::"
    Write-Host "::group::Updating manifest at $ManifestPath"

    Copy-Item -Path (Join-Path $ManifestRoot "$ModuleName.psd1") -Destination $ManifestPath
    Write-Host "Copied module manifest to destination"

    Write-Host "::endgroup::"
    Write-Host "::group::Collecting Functions"

    $Functions = [System.Collections.Generic.List[string]]::new()

    foreach ($importFolder in $importFolders) {
        $importFolderPath = Join-Path $ManifestRoot $importFolder

        if (Test-Path -Path $importFolderPath) {
            Write-Host "Processing public functions in folder: $importFolder"

            $FileList = Get-ChildItem -Path $importFolderPath -Filter "*.ps1" |
                        Where-Object { $_.Name -notlike "*.Tests.ps1" }

            foreach ($File in $FileList) {
                $Code = Get-Content -Path $File.FullName -Raw

                $FunctionAsts = [System.Management.Automation.Language.Parser]::ParseInput(
                    $Code, [ref]$null, [ref]$null
                ).FindAll({
                    param($ast)
                    $ast -is [System.Management.Automation.Language.FunctionDefinitionAst]
                }, $true)

                foreach ($fn in $FunctionAsts) {
                    if ($Debug) { Write-Host $fn.Name }
                    $Functions.Add($fn.Name.Trim())
                }
            }
        }
        else {
            Write-Host "##[warning]Public function folder not found: $importFolder"
        }
    }

    Write-Host "::endgroup::"
    Write-Host "::group::Collecting Assemblies"

    if ($AssemblyDirectories.Count -gt 0) {
        $RequiredAssemblies = @()
        foreach ($Assembly in $AssemblyDirectories) {
            $AssemblyDestinationPath = Join-Path $outputPath "assemblies\$Assembly"
            Write-Host "Processing assemblies in directory: $Assembly"
            $AssemblyFile = Get-Item -Path (Get-ChildItem -Path $AssemblyDestinationPath -Filter "*$Assembly*.dll").FullName
            $AssemblyPath = $AssemblyFile.FullName.Replace("$outputPath\", '')
            $RequiredAssemblies += $AssemblyPath
            Write-Host "Found DLL: $AssemblyPath"
        }

        Write-Host "Updating manifest metadata"
        Update-Metadata -Path $ManifestPath -PropertyName RequiredAssemblies -Value $RequiredAssemblies
        Write-Host "Updated RequiredAssemblies in manifest"
    } else {
        Write-Host "##[warning]No assembly directories specified, skipping RequiredAssemblies update"
    }

    Write-Host "::endgroup::"
    Write-Host "::group::Updating Manifest"

    Update-Metadata -Path $ManifestPath -PropertyName FunctionsToExport -Value $Functions
    Write-Host "Updated FunctionsToExport in manifest"
    Write-Host "::endgroup::"
    Write-Host "::endgroup::"
}
catch {
    Write-Host "##[error]An error occurred: $($_.Exception.Message)"
    exit 1
}
