# زيادة الذاكرة الافتراضية إلى 16GB
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ شغّل كـ Administrator!" -ForegroundColor Red
    pause; exit
}

Write-Host "`n💾 ضبط الذاكرة الافتراضية على 16GB..." -ForegroundColor Cyan

try {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $cs | Set-CimInstance -Property @{ AutomaticManagedPagefile = $false }

    Get-CimInstance -ClassName Win32_PageFileSetting | Remove-CimInstance -ErrorAction SilentlyContinue

    New-CimInstance -ClassName Win32_PageFileSetting -Property @{
        Name        = "C:\pagefile.sys"
        InitialSize = 8192
        MaximumSize = 16384
    } | Out-Null

    Write-Host "✅ تم! الذاكرة الافتراضية صارت: 8GB - 16GB" -ForegroundColor Green
    Write-Host "🔄 أعد تشغيل الجهاز حتى يأخذ مفعوله!`n" -ForegroundColor Yellow
} catch {
    Write-Host "❌ خطأ: $($_.Exception.Message)" -ForegroundColor Red
}
pause
