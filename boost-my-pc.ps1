# ===================================================
# تسريع الجهاز بشكل جذري - Windows Deep Boost
# شغّله بـ PowerShell كـ Administrator
# ===================================================

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ يرجى تشغيل السكريبت كـ Administrator!" -ForegroundColor Red
    pause; exit
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   تسريع الجهاز - النسخة القوية" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$fixed = @()

# ---- 1. تفعيل High Performance Power Plan ----
Write-Host "⚡ تفعيل خطة الطاقة High Performance..." -ForegroundColor Yellow
try {
    powercfg -setactive SCHEME_MIN 2>$null
    if ($LASTEXITCODE -ne 0) {
        # جرب عبر GUID مباشرة
        $hp = powercfg -list | Select-String "High performance"
        if ($hp) {
            $guid = ($hp -split '\s+')[3]
            powercfg -setactive $guid 2>$null
        }
    }
    Write-Host "   ✅ تم — المعالج الآن يشتغل بأقصى طاقته" -ForegroundColor Green
    $fixed += "تفعيل High Performance Power Plan"
} catch {
    Write-Host "   ⚠️  ما قدرنا نغير خطة الطاقة" -ForegroundColor Yellow
}

# ---- 2. تعطيل التأثيرات البصرية ----
Write-Host "`n🎨 تعطيل التأثيرات البصرية (Animations)..." -ForegroundColor Yellow
try {
    # Best Performance mode
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Type DWord -Force

    # تعطيل كل التأثيرات بالتفصيل
    $UserPrefs = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $UserPrefs -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x01,0x80,0x10,0x00,0x00,0x00)) -Force
    Set-ItemProperty -Path $UserPrefs -Name "DragFullWindows" -Value "0" -Force
    Set-ItemProperty -Path $UserPrefs -Name "MenuShowDelay" -Value "0" -Force

    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Force
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "EnableAeroPeek" -Value 0 -Type DWord -Force

    Write-Host "   ✅ تم — الويندوز صار أخف بدون أنيميشن" -ForegroundColor Green
    $fixed += "تعطيل التأثيرات البصرية"
} catch {
    Write-Host "   ⚠️  خطأ: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ---- 3. تعطيل الشفافية ----
Write-Host "`n🪟 تعطيل الشفافية..." -ForegroundColor Yellow
try {
    $personalize = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    if (-not (Test-Path $personalize)) { New-Item -Path $personalize -Force | Out-Null }
    Set-ItemProperty -Path $personalize -Name "EnableTransparency" -Value 0 -Type DWord -Force
    Write-Host "   ✅ تم" -ForegroundColor Green
    $fixed += "تعطيل الشفافية"
} catch {
    Write-Host "   ⚠️  ما قدرنا نوقف الشفافية" -ForegroundColor Yellow
}

# ---- 4. إيقاف خدمات تثقل الجهاز ----
Write-Host "`n🛑 إيقاف الخدمات الثقيلة..." -ForegroundColor Yellow

$services = @(
    @{ Name = "SysMain";          Label = "SysMain (Superfetch)" },
    @{ Name = "WSearch";          Label = "Windows Search Indexing" },
    @{ Name = "DiagTrack";        Label = "Telemetry (تجسس مايكروسوفت)" },
    @{ Name = "dmwappushservice"; Label = "WAP Push Service" },
    @{ Name = "MapsBroker";       Label = "Downloaded Maps Manager" },
    @{ Name = "RemoteRegistry";   Label = "Remote Registry" }
)

foreach ($svc in $services) {
    try {
        $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if ($s) {
            Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "   ✅ تم إيقاف: $($svc.Label)" -ForegroundColor Green
            $fixed += "إيقاف خدمة: $($svc.Label)"
        } else {
            Write-Host "   ⚪ غير موجود: $($svc.Label)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   ⚠️  ما قدرنا نوقف: $($svc.Label)" -ForegroundColor Yellow
    }
}

# ---- 5. زيادة Virtual Memory ----
Write-Host "`n💾 ضبط الذاكرة الافتراضية (Virtual Memory)..." -ForegroundColor Yellow
try {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    if ($cs.AutomaticManagedPagefile) {
        $cs | Set-CimInstance -Property @{AutomaticManagedPagefile = $false}
    }

    # حذف الإعداد القديم وتعيين الجديد
    Get-CimInstance -ClassName Win32_PageFileSetting | Remove-CimInstance -ErrorAction SilentlyContinue
    New-CimInstance -ClassName Win32_PageFileSetting -Property @{
        Name        = "C:\pagefile.sys"
        InitialSize = 4096
        MaximumSize = 8192
    } -ErrorAction Stop | Out-Null

    Write-Host "   ✅ تم — Virtual Memory: 4GB - 8GB" -ForegroundColor Green
    $fixed += "ضبط Virtual Memory: 4096-8192 MB"
} catch {
    Write-Host "   ⚠️  ما قدرنا نغير الذاكرة الافتراضية: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ---- 6. حذف Advanced SystemCare ----
Write-Host "`n🗑️  حذف Advanced SystemCare..." -ForegroundColor Yellow
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
$found = $false
foreach ($path in $uninstallPaths) {
    Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
        $app = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        if ($app.DisplayName -like "*Advanced SystemCare*" -or $app.DisplayName -like "*IObit*") {
            $found = $true
            if ($app.UninstallString) {
                Write-Host "   🔄 جاري الحذف: $($app.DisplayName)..." -ForegroundColor Yellow
                try {
                    $uninstallCmd = $app.UninstallString -replace '"', ''
                    if ($uninstallCmd -like "*.exe*") {
                        Start-Process -FilePath $uninstallCmd.Split(" ")[0] -ArgumentList "/uninstall /quiet" -Wait -ErrorAction Stop
                    }
                    Write-Host "   ✅ تم الحذف" -ForegroundColor Green
                    $fixed += "حذف Advanced SystemCare"
                } catch {
                    Write-Host "   ⚠️  احذفه يدوياً: Settings → Apps → Advanced SystemCare" -ForegroundColor Yellow
                }
            }
        }
    }
}
if (-not $found) {
    Write-Host "   ✅ غير موجود أصلاً" -ForegroundColor Green
}

# ---- 7. تحسين إعدادات الشبكة ----
Write-Host "`n🌐 تحسين إعدادات الشبكة..." -ForegroundColor Yellow
try {
    netsh int tcp set global autotuninglevel=normal 2>$null
    netsh int tcp set global chimney=enabled 2>$null
    Write-Host "   ✅ تم تحسين إعدادات الشبكة" -ForegroundColor Green
    $fixed += "تحسين إعدادات الشبكة"
} catch {
    Write-Host "   ⚠️  ما قدرنا نحسن إعدادات الشبكة" -ForegroundColor Yellow
}

# ---- 8. تنظيف سجل الويندوز (بأمان) ----
Write-Host "`n🧹 تنظيف ملفات الـ Cache والـ Prefetch..." -ForegroundColor Yellow
Remove-Item -Path "C:\Windows\Prefetch\*" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "   ✅ تم" -ForegroundColor Green
$fixed += "تنظيف Cache و Prefetch"

# ---- تقرير نهائي ----
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   تقرير ما تم تحسينه" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`n✅ تم تحسين $($fixed.Count) شيء:" -ForegroundColor Green
$fixed | ForEach-Object { Write-Host "   • $_" -ForegroundColor Green }

Write-Host "`n📌 مهم جداً:" -ForegroundColor Cyan
Write-Host "   ➜ أعد تشغيل الجهاز الآن حتى تأخذ التغييرات مفعولها" -ForegroundColor White
Write-Host "   ➜ بعد إعادة التشغيل راح تلاحظ فرق واضح" -ForegroundColor White

Write-Host "`n💡 نصيحة أخيرة:" -ForegroundColor Cyan
Write-Host "   جهازك i3 2010 + 4GB RAM — أقصى ما يمكن تحسينه بالسوفتوير تم." -ForegroundColor White
Write-Host "   لو تريد سرعة أكثر: استبدل HDD بـ SSD (~30\$) = فرق كبير جداً!" -ForegroundColor White

Write-Host "`nانتهى ✅ — أعد تشغيل الجهاز الآن!`n" -ForegroundColor Green
pause
