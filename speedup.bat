@echo off
if not exist "%~p1\out" mkdir "%~p1\out"
    echo "%~p1\out"
for %%p in (%1) do  (
    echo %%~pp\out
"C:\Program Files (x86)\sox-14-4-0\sox.exe" --show-progress --volume 1.1 "%%p" "%%~pp\out\%%~np.ogg" tempo 1.5
)
