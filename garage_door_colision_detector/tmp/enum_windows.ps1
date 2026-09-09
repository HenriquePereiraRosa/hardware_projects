Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class WinEnum {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, StringBuilder text, int count);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
}
'@

$rows = [System.Collections.Generic.List[object]]::new()
$callback = [WinEnum+EnumWindowsProc]{
  param([IntPtr]$window, [IntPtr]$state)
  $pidValue = [uint32]0
  [void][WinEnum]::GetWindowThreadProcessId($window, [ref]$pidValue)
  if ($pidValue -in @(45232,71568,73724)) {
    $title = [Text.StringBuilder]::new(1024)
    $class = [Text.StringBuilder]::new(256)
    [void][WinEnum]::GetWindowText($window, $title, $title.Capacity)
    [void][WinEnum]::GetClassName($window, $class, $class.Capacity)
    $rows.Add([pscustomobject]@{
      Handle = ('0x{0:X}' -f $window.ToInt64())
      ProcessId = $pidValue
      Visible = [WinEnum]::IsWindowVisible($window)
      Class = $class.ToString()
      Title = $title.ToString()
    })
  }
  return $true
}
[void][WinEnum]::EnumWindows($callback, [IntPtr]::Zero)
$rows | Format-Table -AutoSize
