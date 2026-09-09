[CmdletBinding()]
param(

    # Folder containing wallpaper images
    [Parameter()]
    [string]
    $Folder = "C:\Bakgrunner",

    # Choose a random wallpaper instead of rotating sequentially
    [Parameter()]
    [switch]
    $Random

)

# Global Variables
$StateFile = Join-Path $Folder "state.txt"


# Load Windows API
function Initialize-WallpaperAPI {

    if ("Wallpaper" -as [type]) {
        return
    }

Add-Type @"
using System.Runtime.InteropServices;

public class Wallpaper
{
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SystemParametersInfo(
        int uAction,
        int uParam,
        string lpvParam,
        int fuWinIni
    );
}
"@

}

# Returns all supported wallpaper files
function Get-Wallpapers {

    param(
        [Parameter(Mandatory)]
        [string]$Folder
    )

    if (-not (Test-Path $Folder)) {
        throw "Folder '$Folder' does not exist."
    }

    $SupportedExtensions = @(
        ".jpg"
        ".jpeg"
        ".png"
        ".bmp"
        ".gif"
        ".webp"
        ".tif"
        ".tiff"
    )

    $Images = Get-ChildItem -Path $Folder -File |
        Where-Object {
            $_.Extension.ToLower() -in $SupportedExtensions
        } |
        Sort-Object Name

    if ($Images.Count -eq 0) {
        throw "No supported images found in '$Folder'."
    }

    return $Images

}

# Reads the current wallpaper index
function Get-State {

    param(
        [string]$StateFile
    )

    if (-not (Test-Path $StateFile)) {

        Set-Content `
            -Path $StateFile `
            -Value 0

        return 0
    }

    try {

        return [int](Get-Content `
            -Path $StateFile `
            -ErrorAction Stop)

    }
    catch {

        return 0

    }

}


# Saves current wallpaper index
function Save-State {

    param(

        [string]$StateFile,

        [int]$Index

    )

    Set-Content `
        -Path $StateFile `
        -Value $Index

}

# Validates wallpaper file
function Test-Wallpaper {

    param(
        [System.IO.FileInfo]$File
    )

    if ($null -eq $File) {
        return $false
    }

    if (-not (Test-Path $File.FullName)) {
        return $false
    }

    if ($File.Length -eq 0) {
        return $false
    }

    return $true

}


# Sets Windows wallpaper
function Set-Wallpaper {

    param(

        [Parameter(Mandatory)]
        [string]$Path

    )

    if (-not (Test-Path $Path)) {
        throw "Wallpaper file does not exist."
    }

    $Result = [Wallpaper]::SystemParametersInfo(
        20,
        0,
        $Path,
        3
    )

    if (-not $Result) {
        throw "Windows failed to change the wallpaper."
    }

}

# Returns next sequential wallpaper
function Get-NextWallpaper {

    param(

        [array]$Images,

        [int]$CurrentIndex

    )

    $CurrentIndex = $CurrentIndex % $Images.Count

    return @{
        Image = $Images[$CurrentIndex]
        NextIndex = ($CurrentIndex + 1) % $Images.Count
    }

}

# Returns random wallpaper
function Get-RandomWallpaper {

    param(
        [array]$Images
    )

    return $Images | Get-Random

}

# MAIN
try {

    Initialize-WallpaperAPI

    $Wallpapers = Get-Wallpapers -Folder $Folder

    if ($Random) {

        Write-Verbose "Random mode enabled."

        $Wallpaper = Get-RandomWallpaper $Wallpapers

    }
    else {

        $CurrentIndex = Get-State $StateFile

        $Result = Get-NextWallpaper `
            -Images $Wallpapers `
            -CurrentIndex $CurrentIndex

        $Wallpaper = $Result.Image

        Save-State `
            -StateFile $StateFile `
            -Index $Result.NextIndex

    }

    if (-not (Test-Wallpaper $Wallpaper)) {
        throw "Selected wallpaper is invalid."
    }

    Set-Wallpaper `
        -Path $Wallpaper.FullName

    Write-Host ""
    Write-Host "Wallpaper changed successfully." -ForegroundColor Green
    Write-Host ""
    Write-Host "File:"
    Write-Host $Wallpaper.FullName
    Write-Host ""

}
catch {

    Write-Error $_.Exception.Message
    exit 1

}
