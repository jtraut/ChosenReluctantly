# TL4: kill-on-close Job Object. Dot-source this and call Add-KillOnCloseJob once, before launching Godot.
# The calling PowerShell process joins a Job Object with JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE; every child it starts afterwards (the Godot console
# binary and anything it spawns) is in the job too. The wrapper holds the only handle, so when the wrapper dies (a hard kill, Stop-Process,
# a closed terminal) Windows closes the handle and kills the whole job: no orphaned Godot. Launches stay a plain "& $godot ..." so the exit code
# is $LASTEXITCODE as before (an owned Start-Process child lost it on Windows PowerShell 5.1). Returns $true when the job is active.
# Nested jobs work on Windows 8 and later. Anywhere it can't be set up it warns and returns $false; the wrapper still runs, just unguarded.
function Add-KillOnCloseJob {
    if ($script:KillOnCloseJobActive) { return $true }
    try {
        if (-not ("CrJobGuard" -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class CrJobGuard {
    [StructLayout(LayoutKind.Sequential)] struct BasicLimits { public long PerProcessUserTimeLimit, PerJobUserTimeLimit; public uint LimitFlags; public UIntPtr MinimumWorkingSetSize, MaximumWorkingSetSize; public uint ActiveProcessLimit; public UIntPtr Affinity; public uint PriorityClass, SchedulingClass; }
    [StructLayout(LayoutKind.Sequential)] struct IoCounters { public ulong a, b, c, d, e, f; }
    [StructLayout(LayoutKind.Sequential)] struct ExtendedLimits { public BasicLimits Basic; public IoCounters Io; public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed; }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateJobObject(IntPtr attrs, string name);
    [DllImport("kernel32.dll")] static extern bool SetInformationJobObject(IntPtr job, int infoClass, ref ExtendedLimits info, int size);
    [DllImport("kernel32.dll")] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    static IntPtr handle = IntPtr.Zero; // never closed by us: the OS closes it when this process ends
    public static bool Join() {
        IntPtr job = CreateJobObject(IntPtr.Zero, null);
        if (job == IntPtr.Zero) return false;
        ExtendedLimits info = new ExtendedLimits();
        info.Basic.LimitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        if (!SetInformationJobObject(job, 9, ref info, Marshal.SizeOf(typeof(ExtendedLimits)))) return false; // 9 = JobObjectExtendedLimitInformation
        if (!AssignProcessToJobObject(job, System.Diagnostics.Process.GetCurrentProcess().Handle)) return false;
        handle = job;
        return true;
    }
}
"@
        }
        $script:KillOnCloseJobActive = [CrJobGuard]::Join()
    } catch {
        $script:KillOnCloseJobActive = $false
    }
    if (-not $script:KillOnCloseJobActive) { Write-Warning "job_guard: could not create the kill-on-close job; a hard-killed wrapper may leave Godot running." }
    return $script:KillOnCloseJobActive
}
