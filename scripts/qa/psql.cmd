@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "REPO_ROOT=%%~fI"
set "SERVICE=%WATERMARK_QA_POSTGRES_SERVICE%"
if "%SERVICE%"=="" set "SERVICE=postgres"
set "CONTAINER=%WATERMARK_QA_POSTGRES_CONTAINER%"
set "DB_USER=%WATERMARK_QA_POSTGRES_USER%"
if "%DB_USER%"=="" set "DB_USER=petmagic_user"
set "DB_NAME=%WATERMARK_QA_POSTGRES_DB%"
if "%DB_NAME%"=="" set "DB_NAME=petmagic_db"
set "FORWARDED="
set "FILE="
set "FIRST=1"

:parse
if "%~1"=="" goto run

if "%FIRST%"=="1" (
  set "FIRST=0"
  set "FIRST_ARG=%~1"
  if /I "!FIRST_ARG:~0,13!"=="postgresql://" (
    shift
    goto parse
  )
  if /I "!FIRST_ARG:~0,11!"=="postgres://" (
    shift
    goto parse
  )
)

if "%~1"=="-f" (
  set "FILE=%~2"
  shift
  shift
  goto parse
)

set FORWARDED=!FORWARDED! "%~1"
shift
goto parse

:run
if not "%CONTAINER%"=="" (
  if not "%FILE%"=="" (
    docker exec -i "%CONTAINER%" psql -U "%DB_USER%" -d "%DB_NAME%" !FORWARDED! < "%FILE%"
  ) else (
    docker exec -i "%CONTAINER%" psql -U "%DB_USER%" -d "%DB_NAME%" !FORWARDED!
  )
  exit /b %ERRORLEVEL%
)

if not "%FILE%"=="" (
  docker compose -f "%REPO_ROOT%\docker-compose.yml" exec -T "%SERVICE%" psql -U "%DB_USER%" -d "%DB_NAME%" !FORWARDED! < "%FILE%"
) else (
  docker compose -f "%REPO_ROOT%\docker-compose.yml" exec -T "%SERVICE%" psql -U "%DB_USER%" -d "%DB_NAME%" !FORWARDED!
)
exit /b %ERRORLEVEL%
