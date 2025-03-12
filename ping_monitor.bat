@echo off
setlocal enabledelayedexpansion

:: Configuration
set "TARGET=1.abc.com"
set "LOG_DIR=D:\PingLogs"
set "RETENTION_DAYS=2"

:: Create log directory
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

:: Main loop
:main
  for /f "tokens=2 delims==" %%d in ('wmic os get localdatetime /value ^| findstr "Local"') do set "datetime=%%d"
  set "today=!datetime:~0,8!"
  set "logfile=%LOG_DIR%\%COMPUTERNAME%_!today!.json.log"

  if not defined last_day set "last_day=00000000"
  if "!last_day!" neq "!today!" (
    set "last_day=!today!"
    call :clean_old_logs
  )

  call :ping_and_log
  timeout 3 >nul
goto main

:clean_old_logs
  powershell -noprofile -command "$Limit=(Get-Date).AddDays(-%RETENTION_DAYS%); Get-ChildItem '%LOG_DIR%\%COMPUTERNAME%_*.json.log' | ?{ $_.LastWriteTime -lt $Limit } | Remove-Item -Force"
exit /b

:ping_and_log
  set "timestamp=!datetime:~0,4!-!datetime:~4,2!-!datetime:~6,2!T!datetime:~8,2!:!datetime:~10,2!:!datetime:~12,2!"
  ping -n 1 %TARGET% > ping_temp.txt

  set "target_ip=unknown"
  set "packet_loss=100"

  for /f "delims=" %%j in (ping_temp.txt) do (
    set "line=%%j"
    
    :: IP解析
    if "!line:正在 Ping=!" neq "!line!" (
      for /f "tokens=2 delims=[]" %%k in ("!line!") do set "target_ip=%%k"
    )

    :: 丢包率解析
    if "!line:%% 丢失)=!" neq "!line!" (
      for /f "tokens=2 delims=()" %%p in ("!line!") do (
        for /f "tokens=1 delims=%% " %%v in ("%%p") do (
          set "pl=%%v"
          set "pl=!pl: 丢失=!"
          set "pl=!pl: =!"
          if "!pl!" neq "" set "packet_loss=!pl!"
        )
      )
    )
  )

  :: 生成日志
  echo ^{"timestamp": "!timestamp!", "target": "%TARGET%", "ip": "!target_ip!", "packet_loss": !packet_loss!^}>> "%logfile%"
  del ping_temp.txt
exit /b
