<#
.SYNOPSIS
    Completely remove and reinstall the uni plugin for Claude Code
.DESCRIPTION
    Automates cleanup of uni plugin installation
.NOTES
    Restart VS Code after running this script
#>

$ErrorActionPreference = "Stop"

Write-Host "=== Uni Plugin Reinstall Script ===" -ForegroundColor Cyan
Write-Host ""

# Define paths
$uniDir = "$HOME\.config\uni"
$cacheDir = "$HOME\.claude\plugins\cache\uni"
$marketplaceDir = "$HOME\.claude\plugins\marketplaces\uni-marketplace"
$projectCacheDir = "$HOME\.claude\projects\C--dev-uni"
$settingsFile = "$HOME\.claude\settings.json"
$knownMarketplacesFile = "$HOME\.claude\plugins\known_marketplaces.json"
$installedPluginsFile = "$HOME\.claude\plugins\installed_plugins.json"

# Step 1: Remove uni directory
Write-Host "Step 1: Removing uni directory..." -ForegroundColor Yellow
if (Test-Path $uniDir) {
    Remove-Item -Path $uniDir -Recurse -Force
    Write-Host "  OK Removed $uniDir" -ForegroundColor Green
} else {
    Write-Host "  INFO Directory not found: $uniDir" -ForegroundColor Gray
}

# Step 2: Remove cache directory
Write-Host "Step 2: Removing plugin cache..." -ForegroundColor Yellow
if (Test-Path $cacheDir) {
    Remove-Item -Path $cacheDir -Recurse -Force
    Write-Host "  OK Removed $cacheDir" -ForegroundColor Green
} else {
    Write-Host "  INFO Cache not found: $cacheDir" -ForegroundColor Gray
}

# Step 3: Remove marketplace directory
Write-Host "Step 3: Removing marketplace directory..." -ForegroundColor Yellow
if (Test-Path $marketplaceDir) {
    Remove-Item -Path $marketplaceDir -Recurse -Force
    Write-Host "  OK Removed $marketplaceDir" -ForegroundColor Green
} else {
    Write-Host "  INFO Marketplace not found: $marketplaceDir" -ForegroundColor Gray
}

# Step 4: Remove project cache directory
Write-Host "Step 4: Removing project cache directory..." -ForegroundColor Yellow
if (Test-Path $projectCacheDir) {
    Remove-Item -Path $projectCacheDir -Recurse -Force
    Write-Host "  OK Removed $projectCacheDir" -ForegroundColor Green
} else {
    Write-Host "  INFO Project cache not found: $projectCacheDir" -ForegroundColor Gray
}

# Step 5: Update settings.json
Write-Host "Step 5: Updating settings.json..." -ForegroundColor Yellow
if (Test-Path $settingsFile) {
    try {
        $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
        
        # Remove uni from enabledPlugins if it exists
        if ($null -ne $settings.enabledPlugins) {
            $pluginRemoved = $false
            if ($settings.enabledPlugins.PSObject.Properties.Name -contains "uni@uni-marketplace") {
                $settings.enabledPlugins.PSObject.Properties.Remove("uni@uni-marketplace")
                $pluginRemoved = $true
            }
            
            if ($pluginRemoved) {
                $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
                Write-Host "  OK Removed uni from enabledPlugins" -ForegroundColor Green
            } else {
                Write-Host "  INFO uni not found in enabledPlugins" -ForegroundColor Gray
            }
        } else {
            Write-Host "  INFO No enabledPlugins section in settings.json" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  WARNING Error updating settings.json: $_" -ForegroundColor Red
        Write-Host "  You may need to manually edit: $settingsFile" -ForegroundColor Yellow
    }
} else {
    Write-Host "  INFO Settings file not found: $settingsFile" -ForegroundColor Gray
}

# Step 6: Update known_marketplaces.json
Write-Host "Step 6: Updating known_marketplaces.json..." -ForegroundColor Yellow
if (Test-Path $knownMarketplacesFile) {
    try {
        $marketplaces = Get-Content $knownMarketplacesFile -Raw | ConvertFrom-Json
        
        if ($null -ne $marketplaces.PSObject.Properties["uni-marketplace"]) {
            $marketplaces.PSObject.Properties.Remove("uni-marketplace")
            $marketplaces | ConvertTo-Json -Depth 10 | Set-Content $knownMarketplacesFile -Encoding UTF8
            Write-Host "  OK Removed uni-marketplace from known_marketplaces.json" -ForegroundColor Green
        } else {
            Write-Host "  INFO uni-marketplace not found in known_marketplaces.json" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  WARNING Error updating known_marketplaces.json: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  INFO known_marketplaces.json not found" -ForegroundColor Gray
}

# Step 7: Update installed_plugins.json
Write-Host "Step 7: Updating installed_plugins.json..." -ForegroundColor Yellow
if (Test-Path $installedPluginsFile) {
    try {
        $plugins = Get-Content $installedPluginsFile -Raw | ConvertFrom-Json
        
        if ($null -ne $plugins.PSObject.Properties["uni@uni-marketplace"]) {
            $plugins.PSObject.Properties.Remove("uni@uni-marketplace")
            $plugins | ConvertTo-Json -Depth 10 | Set-Content $installedPluginsFile -Encoding UTF8
            Write-Host "  OK Removed uni from installed_plugins.json" -ForegroundColor Green
        } else {
            Write-Host "  INFO uni not found in installed_plugins.json" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  WARNING Error updating installed_plugins.json: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  INFO installed_plugins.json not found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Cleanup Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart VS Code" -ForegroundColor White
Write-Host "2. In Claude chat, type: /plugin" -ForegroundColor White
Write-Host "3. Select 'add marketplace'" -ForegroundColor White
Write-Host "4. Enter: https://github.com/tmoxon/uni" -ForegroundColor White
Write-Host "5. Follow the installation prompts" -ForegroundColor White
Write-Host ""
