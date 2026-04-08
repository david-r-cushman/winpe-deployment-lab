@echo off
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v PostDeployBootstrap /t REG_SZ /d "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%WINDIR%\Setup\Scripts\PostDeploy.ps1\"" /f
