@echo off
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v PostDeployBootstrap /t REG_SZ /d "\"%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe\" -NoProfile -ExecutionPolicy Bypass -NonInteractive -File \"%WINDIR%\Setup\Scripts\PostDeploy.ps1\"" /f
