@@setlocal ENABLEDELAYEDEXPANSION
@@set POWERSHELL_BAT_ARGS=%*
@@if defined POWERSHELL_BAT_ARGS set POWERSHELL_BAT_ARGS=%POWERSHELL_BAT_ARGS:'=''%
@@if defined POWERSHELL_BAT_ARGS set POWERSHELL_BAT_ARGS=%POWERSHELL_BAT_ARGS:"=\"%
@@cd %~dp0
@@PowerShell -Command Invoke-Expression $('$args=@(^&{$args} %POWERSHELL_BAT_ARGS%);'+[String]::Join([char]10,$((Get-Content '%~f0') -notmatch '^^@@'))) & goto :EOF
# Function to compress a video
function Compress-Video {
    param (
        [string]$videoFullPath,
        [string]$outputFileName,
        [int]$targetSizeKB
    )

    # Reference: https://en.wikipedia.org/wiki/Bit_rate#Encoding_bit_rate
    $minAudioBitrate = 32000
    $maxAudioBitrate = 256000

    # Use ffprobe to get the video information
    $probe = & libs/ffprobe -v error -show_entries format=duration:stream=codec_type,bit_rate -of json $videoFullPath | ConvertFrom-Json

    # Video duration, in seconds.
    $duration = [float]$probe.format.duration
    # Audio bitrate, in bps.
    $audioStream = $probe.streams | Where-Object { $_.codec_type -eq "audio" }
    $audioBitrate = [float]$audioStream.bit_rate

    # Target total bitrate, in bps.
    $targetTotalBitrate = ($targetSizeKB * 1024 * 8) / (1.073741824 * $duration)
    # Target audio bitrate, in bps.
    if (10 * $audioBitrate -gt $targetTotalBitrate) {
        $audioBitrate = $targetTotalBitrate / 10
        if ($audioBitrate -lt $minAudioBitrate -and $minAudioBitrate -lt $targetTotalBitrate) {
            $audioBitrate = $minAudioBitrate
        } elseif ($audioBitrate -gt $maxAudioBitrate) {
            $audioBitrate = $maxAudioBitrate
        }
    }

    # Target video bitrate, in bps.
    $videoBitrate = $targetTotalBitrate - $audioBitrate

    # Compress the video using ffmpeg
    & libs/ffmpeg -i $videoFullPath -c:v libx264 -b:v $videoBitrate -c:a aac -b:a $audioBitrate -y $outputFileName
}

# Check if the script is run with an argument
if ($args.Length -eq 0) {
    Write-Host "Usage: .\compress_video.ps1 <input_video_path>"
    exit
}

# Compress the inputted video to 25MB and save as CRUSHED plus whatever the input file was called
$inputVideoPath = $args[0]
$outputFileName =  [System.IO.Path]::GetDirectoryName($inputVideoPath) + "\CRUSHED " + [System.IO.Path]::GetFileName($inputVideoPath)
Compress-Video -videoFullPath $inputVideoPath -outputFileName $outputFileName -targetSizeKB (25 * 1000)