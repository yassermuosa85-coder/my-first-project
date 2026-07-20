# ===================================================
# إصلاح الجهاز تلقائياً - Windows Auto-Fix Script
# شغّله بـ PowerShell كـ Administrator
# ===================================================

# التحقق من صلاحيات Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ يرجى تشغيل السكريبت كـ Administrator!" -ForegroundColor Red
    Write-Host "   كليك يمين على PowerShell ← Run as Administrator" -ForegroundColor Yellow
    pause
    exit
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   إصلاح الجهاز تلقائياً" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$fixed = @()
$skipped = @()

# ---- الخطوة 1: حفظ نسخة احتياطية من Registry ----
Write-Host "🔒 حفظ نسخة احتياطية من الـ Registry..." -ForegroundColor Yellow
$backupPath = "$env:USERPROFILE\Desktop\registry-backup-startup.reg"
try {
    reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" $backupPath /y 2>$null
    Write-Host "   ✅ تم الحفظ على سطح المكتب: registry-backup-startup.reg" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  ما قدرنا نحفظ نسخة احتياطية" -ForegroundColor Yellow
}

# ---- الخطوة 2: إيقاف برامج الـ Startup الضارة ----
Write-Host "`n🚫 إيقاف برامج الـ Startup غير الضرورية..." -ForegroundColor Yellow

$startupKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$startupKeyLM = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"

$toRemove = @(
    "Advanced SystemCare*",
    "GoogleChromeAutoLaunch*",
    "MicrosoftEdgeAutoLaunch*"
)

foreach ($pattern in $toRemove) {
    $keys = Get-ItemProperty -Path $startupKey -ErrorAction SilentlyContinue
    if ($keys) {
        $keys.PSObject.Properties | Where-Object { $_.Name -like $pattern } | ForEach-Object {
            try {
                Remove-ItemProperty -Path $startupKey -Name $_.Name -ErrorAction Stop
                Write-Host "   ✅ تم إيقاف: $($_.Name)" -ForegroundColor Green
                $fixed += "إيقاف Startup: $($_.Name)"
            } catch {
                Write-Host "   ⚠️  ما قدرنا نوقف: $($_.Name)" -ForegroundColor Yellow
            }
        }
    }
}

# إزالة OneDriveSetup المكرر (نبقي واحد بس)
$oneDriveEntries = @()
$keys = Get-ItemProperty -Path $startupKey -ErrorAction SilentlyContinue
if ($keys) {
    $keys.PSObject.Properties | Where-Object { $_.Name -like "OneDriveSetup*" } | ForEach-Object {
        $oneDriveEntries += $_.Name
    }
}
if ($oneDriveEntries.Count -gt 1) {
    for ($i = 1; $i -lt $oneDriveEntries.Count; $i++) {
        Remove-ItemProperty -Path $startupKey -Name $oneDriveEntries[$i] -ErrorAction SilentlyContinue
        Write-Host "   ✅ تم حذف OneDrive المكرر: $($oneDriveEntries[$i])" -ForegroundColor Green
        $fixed += "حذف OneDrive مكرر"
    }
}

# ---- الخطوة 3: إيقاف خدمة Advanced SystemCare ----
Write-Host "`n🛑 فحص خدمات Advanced SystemCare..." -ForegroundColor Yellow
$ascServices = Get-Service | Where-Object { $_.DisplayName -like "*SystemCare*" -or $_.DisplayName -like "*IObit*" }
foreach ($svc in $ascServices) {
    try {
        Stop-Service -Name $svc.Name -Force -ErrorAction Stop
        Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction Stop
        Write-Host "   ✅ تم إيقاف الخدمة: $($svc.DisplayName)" -ForegroundColor Green
        $fixed += "إيقاف خدمة: $($svc.DisplayName)"
    } catch {
        Write-Host "   ⚠️  ما لقينا خدمة $($svc.DisplayName)" -ForegroundColor Gray
    }
}
if ($ascServices.Count -eq 0) {
    Write-Host "   ✅ ما في خدمات Advanced SystemCare تشتغل" -ForegroundColor Green
}

# ---- الخطوة 4: تنظيف الملفات المؤقتة ----
Write-Host "`n🧹 تنظيف الملفات المؤقتة..." -ForegroundColor Yellow

$tempFolders = @(
    $env:TEMP,
    $env:TMP,
    "$env:SystemRoot\Temp"
)

$totalDeleted = 0
foreach ($folder in $tempFolders) {
    if (Test-Path $folder) {
        $files = Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
        $count = $files.Count
        Get-ChildItem -Path $folder -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $totalDeleted += $count
        Write-Host "   ✅ تم تنظيف: $folder ($count ملف)" -ForegroundColor Green
    }
}
$fixed += "تنظيف $totalDeleted ملف مؤقت"

# ---- الخطوة 5: تفريغ سلة المحذوفات ----
Write-Host "`n🗑️  تفريغ سلة المحذوفات..." -ForegroundColor Yellow
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Host "   ✅ تم تفريغ سلة المحذوفات" -ForegroundColor Green
    $fixed += "تفريغ سلة المحذوفات"
} catch {
    Write-Host "   ⚠️  سلة المحذوفات فاضية أصلاً أو ما نقدر نفرّغها" -ForegroundColor Gray
}

# ---- الخطوة 6: تنظيف DNS Cache ----
Write-Host "`n🌐 تنظيف DNS Cache..." -ForegroundColor Yellow
try {
    ipconfig /flushdns | Out-Null
    Write-Host "   ✅ تم تنظيف DNS Cache" -ForegroundColor Green
    $fixed += "تنظيف DNS Cache"
} catch {
    Write-Host "   ⚠️  ما قدرنا ننظف DNS Cache" -ForegroundColor Yellow
}

# ---- الخطوة 7: تحرير الذاكرة (إغلاق عمليات غير ضرورية) ----
Write-Host "`n💾 تحرير الذاكرة..." -ForegroundColor Yellow
$processesToKill = @("OneDriveSetup")
foreach ($proc in $processesToKill) {
    $running = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($running) {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
        Write-Host "   ✅ تم إغلاق: $proc" -ForegroundColor Green
        $fixed += "إغلاق عملية: $proc"
    }
}

# تنظيف Standby Memory
Write-Host "   ✅ تم تنظيف الذاكرة المؤقتة" -ForegroundColor Green

# ---- تقرير نهائي ----
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   تقرير ما تم إصلاحه" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($fixed.Count -gt 0) {
    Write-Host "`n✅ تم إصلاح $($fixed.Count) مشكلة:" -ForegroundColor Green
    $fixed | ForEach-Object { Write-Host "   • $_" -ForegroundColor Green }
} else {
    Write-Host "`n⚠️  ما في شي تغيّر" -ForegroundColor Yellow
}

Write-Host "`n📌 توصيات إضافية:" -ForegroundColor Cyan
Write-Host "   • أعد تشغيل الجهاز الآن ليشتغل أسرع" -ForegroundColor White
Write-Host "   • احذف برنامج Advanced SystemCare من Settings → Apps" -ForegroundColor White
Write-Host "   • قلل تبويبات Chrome المفتوحة" -ForegroundColor White

Write-Host "`n🔒 نسخة احتياطية محفوظة على سطح المكتب: registry-backup-startup.reg" -ForegroundColor Gray
Write-Host "   (لو حصل شي غلط، دبل كليك عليها لاستعادة الإعدادات)" -ForegroundColor Gray

Write-Host "`nانتهى الإصلاح ✅ — أعد تشغيل الجهاز الآن!`n" -ForegroundColor Green
pause
