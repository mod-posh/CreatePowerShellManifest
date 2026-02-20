# Changelog

All changes to this project should be reflected in this document.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [[0.0.2.1]](https://github.com/mod-posh/CreatePowerShellManifest/releases/tag/v0.0.2.1) - 2026-07-19

### BUGFIXES

**issue-4** ToBoolean() Error
> Github Actions can only accept strings

## [[0.0.2.0]](https://github.com/mod-posh/CreatePowerShellManifest/releases/tag/v0.0.2.0) - 2026-07-19

### BUGFIXES

**issue-1** Fixed-size collection
> Fix: use a growable collection like [List[string]] (or use += if you truly want to keep an array).

**issue-2** Wrong assumption about what FindAll() returns
> Fix: iterate foreach ($fn in $FunctionAsts) and add each name.

**issue-3** File exclusion reliability in Get-ChildItem (the “tests” filter)
> Fix (your preference): replace -Exclude with Where-Object { $_.Name -notlike '*.Tests.ps1' } for deterministic behavior.

## [[0.0.1.0]](https://github.com/mod-posh/CreatePowerShellManifest/releases/tag/v0.0.1.0) - 2024-07-17

This Github Action automates the creation of a PowerShell module manifest (.psd1) and optionally handles required assemblies. It collects functions from specified import folders, and updates the module manifest with the exported functions and required assemblies. Debug logging and error handling are also included to provide detailed output and manage any issues during execution.

Features:

- Installs and imports the BuildHelpers module if not already available.
- Copies the existing module manifest file to the output directory.
- Collects and processes function scripts from specified import directories, parsing and aggregating function names.
- Optionally collects and handles required assemblies, updating the manifest with their paths.
- Updates the manifest file with the exported functions and required assemblies.

This action provides a comprehensive solution for creating and updating a PowerShell module manifest, handling function scripts and required assemblies, with robust error handling and debug logging.
