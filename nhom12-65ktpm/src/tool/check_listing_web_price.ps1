# Kiểm tra production validator sau khi biên dịch JavaScript trong Chrome thật.
$ErrorActionPreference = 'Stop'
$priceCheckDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location -LiteralPath $priceCheckDirectory
try {
    & dart compile js tool/listing_price_js_check.dart -o .dart_tool/listing-price-check.js --no-source-maps
    if ($LASTEXITCODE -ne 0) { throw 'Khong bien dich duoc kiem tra gia JavaScript.' }
    $chromePath = Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'
    if ($env:CHROME_EXECUTABLE) { $chromePath = $env:CHROME_EXECUTABLE }
    if (-not (Test-Path -LiteralPath $chromePath)) { throw 'Can Chrome hoac CHROME_EXECUTABLE.' }
    $htmlPath = Join-Path $priceCheckDirectory '.dart_tool/listing-price-check.html'
    # Chỉ ghi output của fixture, không inject vào ứng dụng hoặc sửa Flutter SDK.
    '<!doctype html><html><body><script>console.log=(...items)=>document.body.append(document.createTextNode(items.join(" ")));window.onerror=(message)=>document.body.append(document.createTextNode("FAIL "+message));</script><script src="listing-price-check.js"></script></body></html>' | Set-Content -LiteralPath $htmlPath -Encoding UTF8
    $profilePath = Join-Path $priceCheckDirectory ('.dart_tool/price-chrome-' + [Guid]::NewGuid().ToString('N'))
    $htmlUri = [Uri]::new($htmlPath).AbsoluteUri
    $outputPath = Join-Path $priceCheckDirectory '.dart_tool/listing-price-chrome-output.html'
    $errorPath = Join-Path $priceCheckDirectory '.dart_tool/listing-price-chrome-stderr.log'
    # Chrome là GUI executable trên Windows; Start-Process -Wait mới chờ đúng stdout.
    $arguments = @('--headless', '--disable-gpu', '--no-first-run', ('--user-data-dir="' + $profilePath + '"'), '--dump-dom', ('"' + $htmlUri + '"'))
    $browser = Start-Process -FilePath $chromePath -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath
    $browserExit = $browser.ExitCode
    $outputText = Get-Content -LiteralPath $outputPath -Raw
    if ($browserExit -ne 0 -or $outputText -notmatch 'PASS listing price JavaScript' -or $outputText -match '>FAIL ') {
        throw 'Kiem tra Chrome chua dat: gia bi lam tron hoac trang kiem tra khong chay.'
    }
    Write-Output 'PASS Chrome: gia JSON chinh xac; chan so lon bi lam tron, gia le va gia 0.'
} finally {
    Pop-Location
}
