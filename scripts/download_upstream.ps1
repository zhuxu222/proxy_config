$ErrorActionPreference = "Continue"
$base = "https://raw.githubusercontent.com/dler-io/Rules/main/Clash/Provider"
$dir = "rule_provider/upstream"

New-Item -ItemType Directory -Path $dir -Force | Out-Null

# General rules
$general = @(
    "AdBlock", "HTTPDNS", "Special", "Proxy", "Domestic",
    "Domestic IPs", "LAN", "Telegram", "Crypto", "Discord",
    "Steam", "TikTok", "Speedtest", "PayPal", "Microsoft",
    "AI Suite", "Apple", "Google FCM", "Scholar", "miHoYo"
)

# Media rules
$media = @(
    "Netflix", "Spotify", "YouTube", "Max", "Bilibili",
    "IQ", "IQIYI", "Letv", "Netease Music", "Tencent Video",
    "Youku", "WeTV", "ABC", "Abema TV", "Amazon",
    "Apple Music", "Apple News", "Apple TV", "Bahamut",
    "BBC iPlayer", "DAZN", "Discovery Plus", "Disney Plus",
    "DMM", "encoreTVB", "F1 TV", "Fox Now", "Fox+",
    "Hulu Japan", "Hulu", "Japonx", "JOOX", "KKBOX",
    "KKTV", "Line TV", "myTV SUPER", "Niconico", "Pandora",
    "PBS", "Pornhub", "Soundcloud", "ViuTV"
)

$success = 0
$fail = 0

foreach ($f in $general) {
    $url = "$base/$([uri]::EscapeDataString($f)).yaml"
    $filename = $f -replace ' ', '_'
    $outpath = "$dir/$filename.yaml"
    try {
        Invoke-WebRequest -Uri $url -OutFile $outpath -UseBasicParsing
        Write-Host "[OK] $f"
        $success++
    } catch {
        Write-Host "[FAIL] $f - $_"
        $fail++
    }
}

foreach ($f in $media) {
    $url = "$base/Media/$([uri]::EscapeDataString($f)).yaml"
    $filename = $f -replace ' ', '_'
    $outpath = "$dir/$filename.yaml"
    try {
        Invoke-WebRequest -Uri $url -OutFile $outpath -UseBasicParsing
        Write-Host "[OK] Media/$f"
        $success++
    } catch {
        Write-Host "[FAIL] Media/$f - $_"
        $fail++
    }
}

Write-Host "`nDone: $success success, $fail failed"
