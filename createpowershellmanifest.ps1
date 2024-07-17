param (
    [string]$ModuleName,
    [string]$Source = "",
    [string]$Output = "",
    [string]$Imports,
    [string]$Assemblies = "",
    [bool]$Debug = $false
)
try
{
    Write-Host "::group::Starting the Create PowerShell Module task..."
    Write-Host "::group::Setting up variables"

    if ([string]::IsNullOrEmpty($Source))
    {
        $sourcePath = "$($env:GITHUB_WORKSPACE)"
    }
    else
    {
        $sourcePath = "$($env:GITHUB_WORKSPACE)\$($Source)"
    }

    if ([string]::IsNullOrEmpty($Output))
    {
        $outputPath = "$($env:GITHUB_WORKSPACE)\output"
    }
    else
    {
        $outputPath = "$($env:GITHUB_WORKSPACE)\$($Output)"
    }

    $modulePath = "$($outputPath)\$($ModuleName).psm1"
    $ManifestPath = "$($outputPath)\$($ModuleName).psd1"

    if ($Debug)
    {
        Write-Host "::debug::ModuleName   : $($ModuleName)"
        Write-Host "::debug::SourcePath   : $($sourcePath)"
        Write-Host "::debug::OutputPath   : $($outputPath)"
        Write-Host "::debug::ModulePath   : $($modulePath)"
        Write-Host "::debug::ManifestPath : $($ManifestPath)"
        Write-Host "::debug::Imports      : $($imports)"
        Write-Host "::debug::Assemblies   : $($Assemblies)"
    }

    $importFolders = $imports.Split(',')

    if ([string]::IsNullOrEmpty($Assemblies))
    {
        $AssemblyDirectories = @()
    }
    else
    {
        $AssemblyDirectories = $Assemblies.Split(',')
    }

    Write-Host "::endgroup::"
    Write-Host "::group::Install BuildHelpers module"
    if (-not (Get-Module -ListAvailable -Name BuildHelpers))
    {
        Install-Module -Name BuildHelpers -Scope CurrentUser -Force
    }
    Import-Module BuildHelpers
    Write-Host "::endgroup::"

    Write-Host "::group::Updating manifest at [$($ManifestPath)]"
    Copy-Item "$($sourcePath)\$($ModuleName).psd1" -Destination $outputPath -ErrorAction Stop
    Write-Host "Copied module manifest to destination"
    Write-Host "::endgroup::"

    Write-Host "::group::Collecting Functions"
    $Functions = @()

    foreach ($importFolder in $importFolders)
    {
        if (Test-Path "$($sourcePath)\$($importFolder)")
        {
            Write-Host "Processing public functions in folder: $($importFolder)"
            $FileList = Get-ChildItem "$($sourcePath)\$($importFolder)\*.ps1" -Exclude "*.Tests.ps1"
            foreach ($File in $FileList)
            {
                $Code = Get-Content -Path $File.FullName -Raw
                $Function = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$null).FindAll({
                    param($ast)
                    $ast -is [System.Management.Automation.Language.FunctionDefinitionAst]
                }, $true)
                if ($Debug)
                {
                    Write-Host "::debug::$($Function.Name)"
                }
                $Functions += $Function.Name
            }
        }
        else
        {
            Write-Host "##[warning]Public function folder not found: $($importFolder)"
        }
    }
    Write-Host "::endgroup::"

    Write-Host "::group::Collecting Assemblies"
    if ($AssemblyDirectories.Count -gt 0)
    {
        $RequiredAssemblies = @()
        foreach ($Assembly in $AssemblyDirectories)
        {
            $AssemblyDestinationPath = "$($outputPath)\assemblies\$($Assembly)"
            Write-Host "Processing assemblies in directory: $($Assembly)"
            $AssemblyFile = Get-Item -Path (((Get-ChildItem -Path "$($AssemblyDestinationPath)").GetFiles("*$($Assembly)*").FullName) | Where-Object { $_.EndsWith('dll') })
            $AssemblyPath = $AssemblyFile.FullName.Replace("$($outputPath)\", '')
            $RequiredAssemblies += $AssemblyPath
            Write-Host "Found DLL: $AssemblyPath"
        }

        Write-Host "Updating manifest metadata"
        Update-Metadata -Path $ManifestPath -PropertyName RequiredAssemblies -Value $RequiredAssemblies
        Write-Host "Updated RequiredAssemblies in manifest"
    }
    else
    {
        Write-Host "##[warning]No assembly directories specified, skipping RequiredAssemblies update"
    }
    Write-Host "::endgroup::"

    Write-Host "::group::Updating Manifest"
    Update-Metadata -Path $ManifestPath -PropertyName FunctionsToExport -Value $Functions
    Write-Host "Updated FunctionsToExport in manifest"
    Write-Host "::endgroup::"
    Write-Host "::endgroup::"
}
catch
{
    Write-Host "##[error]An error occurred: $($_.Exception.Message)"
    exit 1
}