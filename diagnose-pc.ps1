# ===================================================
# فحص سرعة الجهاز - Windows Diagnostic Script
# شغّل هذا السكريبت بـ PowerShell كـ Administrator
# ===================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   تقرير فحص الجهاز" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. معلومات النظام
Write-Host "--- معلومات النظام ---" -ForegroundColor Yellow
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor
Write-Host "النظام   : $($os.Caption)"
Write-Host "المعالج  : $($cpu.Name)"
Write-Host "وقت التشغيل: $(([DateTime]::Now - $os.LastBootUpTime).Days) يوم / $(([DateTime]::Now - $os.LastBootUpTime).Hours) ساعة"

# 2. الذاكرة RAM
Write-Host "`n--- الذاكرة (RAM) ---" -ForegroundColor Yellow
$totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$freeRAM  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$usedRAM  = [math]::Round($totalRAM - $freeRAM, 1)
$ramPct   = [math]::Round(($usedRAM / $totalRAM) * 100, 0)
Write-Host "الكل    : ${totalRAM} GB"
Write-Host "مستخدم  : ${usedRAM} GB"
Write-Host "متبقي   : ${freeRAM} GB"
if ($ramPct -gt 85) {
    Write-Host "⚠️  الذاكرة ممتلئة $ramPct% — هذا سبب مباشر للبطء!" -ForegroundColor Red
} elseif ($ramPct -gt 70) {
    Write-Host "⚡ الذاكرة $ramPct% — مقبولة بس قريبة من الحد" -ForegroundColor Yellow
} else {
    Write-Host "✅ الذاكرة $ramPct% — ممتازة" -ForegroundColor Green
}

# 3. المعالج CPU
Write-Host "`n--- المعالج (CPU) ---" -ForegroundColor Yellow
$cpuLoad = (Get-CimInstance Win32_Processor).LoadPercentage
if ($cpuLoad -gt 80) {
    Write-Host "⚠️  استخدام المعالج: $cpuLoad% — مرتفع جداً!" -ForegroundColor Red
} elseif ($cpuLoad -gt 50) {
    Write-Host "⚡ استخدام المعالج: $cpuLoad% — متوسط" -ForegroundColor Yellow
} else {
    Write-Host "✅ استخدام المعالج: $cpuLoad% — طبيعي" -ForegroundColor Green
}

# 4. القرص الصلب
Write-Host "`n--- الأقراص الصلبة ---" -ForegroundColor Yellow
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
    $total = [math]::Round(($_.Used + $_.Free) / 1GB, 1)
    $used  = [math]::Round($_.Used / 1GB, 1)
    $free  = [math]::Round($_.Free / 1GB, 1)
    $pct   = [math]::Round(($_.Used / ($_.Used + $_.Free)) * 100, 0)
    if ($pct -gt 90) {
        Write-Host "⚠️  $($_.Name): ممتلئ $pct% — متبقي $free GB فقط!" -ForegroundColor Red
    } elseif ($pct -gt 75) {
        Write-Host "⚡ $($_.Name): $pct% — ابدأ تنظيف" -ForegroundColor Yellow
    } else {
        Write-Host "✅ $($_.Name): $pct% ($used GB مستخدم / $total GB كل)" -ForegroundColor Green
    }
}

# 5. أثقل البرامج على الذاكرة
Write-Host "`n--- أثقل 10 برامج على الذاكرة ---" -ForegroundColor Yellow
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 | ForEach-Object {
    $mem = [math]::Round($_.WorkingSet64 / 1MB, 0)
    Write-Host "  $($_.ProcessName.PadRight(30)) $mem MB"
}

# 6. أثقل البرامج على المعالج
Write-Host "`n--- أثقل 10 برامج على المعالج ---" -ForegroundColor Yellow
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 | ForEach-Object {
    $cpuTime = [math]::Round($_.CPU, 1)
    Write-Host "  $($_.ProcessName.PadRight(30)) $cpuTime ثانية CPU"
}

# 7. برامج الـ Startup
Write-Host "`n--- برامج تشغل عند بدء الويندوز ---" -ForegroundColor Yellow
$startupItems = Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location
if ($startupItems.Count -gt 10) {
    Write-Host "⚠️  عندك $($startupItems.Count) برنامج يشتغل عند التشغيل — كثير!" -ForegroundColor Red
} else {
    Write-Host "✅ $($startupItems.Count) برنامج فقط" -ForegroundColor Green
}
$startupItems | ForEach-Object {
    Write-Host "  - $($_.Name)"
}

# 8. درجة حرارة CPU (إن توفرت)
Write-Host "`n--- درجة الحرارة ---" -ForegroundColor Yellow
try {
    $temps = Get-CimInstance -Namespace "root/WMI" -ClassName "MSAcpi_ThermalZoneTemperature" -ErrorAction Stop
    $temps | ForEach-Object {
        $celsius = [math]::Round($_.CurrentTemperature / 10 - 273.15, 1)
        if ($celsius -gt 85) {
            Write-Host "⚠️  $celsius°C — الجهاز حار جداً! نظف المراوح" -ForegroundColor Red
        } elseif ($celsius -gt 70) {
            Write-Host "⚡ $celsius°C — حرارة متوسطة" -ForegroundColor Yellow
        } else {
            Write-Host "✅ $celsius°C — طبيعي" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "  (ما أقدر أقرأ الحرارة على هذا الجهاز)" -ForegroundColor Gray
}

# 9. ملخص التوصيات
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   التوصيات" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$freeC = (Get-PSDrive C).Free / 1GB
if ($freeC -lt 10) { Write-Host "❌ نظف القرص C — متبقي أقل من 10GB" -ForegroundColor Red }
if ($ramPct -gt 85) { Write-Host "❌ أقفل البرامج الغير ضرورية أو زد الذاكرة" -ForegroundColor Red }
if ($startupItems.Count -gt 10) { Write-Host "❌ قلل برامج الـ Startup من Task Manager > Startup" -ForegroundColor Red }
Write-Host "💡 شغّل: cleanmgr /sagerun:1  لتنظيف الملفات المؤقتة" -ForegroundColor Cyan
Write-Host "💡 شغّل: sfc /scannow          لفحص ملفات الويندوز" -ForegroundColor Cyan
Write-Host "`nانتهى الفحص ✅`n" -ForegroundColor Green
