# ===================================================
# تحسين أداء المعالج CPU
# شغّله بـ PowerShell كـ Administrator
# ===================================================

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ شغّل كـ Administrator!" -ForegroundColor Red
    pause; exit
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   تحسين أداء المعالج CPU" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$fixed = @()

# ---- 1. تقرير شنو يأكل المعالج الحين ----
Write-Host "🔍 أثقل البرامج على المعالج الحين:" -ForegroundColor Yellow
Get-Process | Sort-Object CPU -Descending | Select-Object -First 8 | ForEach-Object {
    $cpu = [math]::Round($_.CPU, 1)
    $mem = [math]::Round($_.WorkingSet64 / 1MB, 0)
    Write-Host ("   {0,-28} CPU:{1,8}s   RAM:{2,5}MB" -f $_.ProcessName, $cpu, $mem)
}

# ---- 2. تخفيض أولوية Windows Defender ----
Write-Host "`n🛡️  تخفيض أولوية Windows Defender..." -ForegroundColor Yellow
try {
    # تخفيض أولوية MsMpEng إلى Low
    $defender = Get-Process -Name "MsMpEng" -ErrorAction SilentlyContinue
    if ($defender) {
        $defender.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Low
        Write-Host "   ✅ Windows Defender صار يشتغل بأولوية منخفضة" -ForegroundColor Green
        $fixed += "تخفيض أولوية Windows Defender"
    }

    # تحديد CPU usage لـ Defender
    $defenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan"
    if (-not (Test-Path $defenderPath)) { New-Item -Path $defenderPath -Force | Out-Null }
    Set-ItemProperty -Path $defenderPath -Name "AvgCPULoadFactor" -Value 20 -Type DWord -Force
    Write-Host "   ✅ حد استخدام CPU لـ Defender: 20% بس" -ForegroundColor Green
    $fixed += "تحديد CPU لـ Windows Defender بـ 20%"
} catch {
    Write-Host "   ⚠️  $($_.Exception.Message)" -ForegroundColor Yellow
}

# ---- 3. إيقاف Windows Update التلقائي (مؤقتاً) ----
Write-Host "`n🔄 إيقاف Windows Update من الخلفية..." -ForegroundColor Yellow
try {
    Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
    Set-Service -Name "wuauserv" -StartupType Manual -ErrorAction SilentlyContinue
    Stop-Service -Name "UsoSvc" -Force -ErrorAction SilentlyContinue
    Set-Service -Name "UsoSvc" -StartupType Manual -ErrorAction SilentlyContinue
    Write-Host "   ✅ تم — Windows Update لن يشتغل بالخلفية" -ForegroundColor Green
    $fixed += "إيقاف Windows Update من الخلفية"
} catch {
    Write-Host "   ⚠️  ما قدرنا نوقف Windows Update" -ForegroundColor Yellow
}

# ---- 4. إيقاف Cortana ----
Write-Host "`n🔇 إيقاف Cortana..." -ForegroundColor Yellow
try {
    $cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    if (-not (Test-Path $cortanaPath)) { New-Item -Path $cortanaPath -Force | Out-Null }
    Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Type DWord -Force

    Get-Process -Name "SearchUI" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "Cortana"  -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-Host "   ✅ تم إيقاف Cortana" -ForegroundColor Green
    $fixed += "إيقاف Cortana"
} catch {
    Write-Host "   ⚠️  $($_.Exception.Message)" -ForegroundColor Yellow
}

# ---- 5. تعطيل البرامج الخلفية ----
Write-Host "`n📱 تعطيل البرامج الخلفية (Background Apps)..." -ForegroundColor Yellow
try {
    $bgPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    Set-ItemProperty -Path $bgPath -Name "GlobalUserDisabled" -Value 1 -Type DWord -Force
    Write-Host "   ✅ تم تعطيل جميع البرامج الخلفية" -ForegroundColor Green
    $fixed += "تعطيل Background Apps"
} catch {
    Write-Host "   ⚠️  $($_.Exception.Message)" -ForegroundColor Yellow
}

# ---- 6. ضبط جدولة المعالج لتفضيل البرامج ----
Write-Host "`n⚙️  ضبط المعالج ليفضّل البرامج الأمامية..." -ForegroundColor Yellow
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" `
        -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force
    Write-Host "   ✅ المعالج يعطي أولوية للبرنامج اللي تشتغل عليه" -ForegroundColor Green
    $fixed += "ضبط أولوية المعالج للبرامج الأمامية"
} catch {
    Write-Host "   ⚠️  $($_.Exception.Message)" -ForegroundColor Yellow
}

# ---- 7. إيقاف خدمات الطباعة والفاكس (لو ما تستخدمها) ----
Write-Host "`n🖨️  إيقاف خدمات غير ضرورية..." -ForegroundColor Yellow
$extras = @(
    @{ Name = "Fax";         Label = "خدمة الفاكس" },
    @{ Name = "PrintSpooler"; Label = "طابور الطباعة (لو ما عندك طابعة)" },
    @{ Name = "XblGameSave"; Label = "Xbox Game Save" },
    @{ Name = "XboxNetApiSvc"; Label = "Xbox Network" },
    @{ Name = "lfsvc";       Label = "Geolocation Service" },
    @{ Name = "RetailDemo";  Label = "Retail Demo Service" }
)
foreach ($svc in $extras) {
    $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($s -and $s.Status -eq "Running") {
        Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
        Set-Service  -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "   ✅ إيقاف: $($svc.Label)" -ForegroundColor Green
        $fixed += "إيقاف: $($svc.Label)"
    }
}

# ---- 8. إغلاق Chrome الزيادة (لو مفتوح) ----
Write-Host "`n🌐 فحص Chrome..." -ForegroundColor Yellow
$chromeProcs = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
if ($chromeProcs) {
    Write-Host "   ⚠️  عندك $($chromeProcs.Count) عملية Chrome مفتوحة!" -ForegroundColor Red
    Write-Host "   💡 نصيحة: قلل التبويبات أو استخدم Edge — أخف على الجهاز" -ForegroundColor Yellow
} else {
    Write-Host "   ✅ Chrome مو مشغّل الحين" -ForegroundColor Green
}

# ---- تقرير نهائي ----
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   النتيجة" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`n✅ تم تحسين $($fixed.Count) شيء:" -ForegroundColor Green
$fixed | ForEach-Object { Write-Host "   • $_" -ForegroundColor Green }

Write-Host "`n💡 نصائح مهمة لتخفيف المعالج:" -ForegroundColor Cyan
Write-Host "   • قلّل تبويبات Chrome (كل تبويب = عملية مستقلة)" -ForegroundColor White
Write-Host "   • لا تشغّل فيديوهات يوتيوب بـ Chrome على هذا الجهاز" -ForegroundColor White
Write-Host "   • استخدم Edge بدل Chrome — أخف بـ 30%" -ForegroundColor White
Write-Host "   • أعد تشغيل الجهاز بعد انتهاء العمل وليس Hibernate" -ForegroundColor White

Write-Host "`n🔄 أعد تشغيل الجهاز لتأخذ التغييرات مفعولها!`n" -ForegroundColor Yellow
pause
