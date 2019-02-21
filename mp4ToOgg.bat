rem echo off

echo Converting all .m4a files passed or in directories in to 1.5X .ogg files

rem echo DIR:%1
for %%p in (%*) do  (
    echo WALKING:%%p
    echo "EXT:"%%~xp
    rem recursively walk directories
    if exist %%p\  call :WALKDIR %%p
    rem manually convert any m4as that were passed
    if "%%~xp" EQU ".m4a"  call :OGGIT %%p
    if "%%~xp" EQU ".m4b"  call :OGGIT %%p
    if "%%~xp" EQU ".mp3"  call :OGGIT %%p
)
goto :EOF

:OGGIT
echo OGGING:%1,%~n1
if not exist "%~p1\out" mkdir "%~p1\out"
if not exist "\old" mkdir "\old"

C:\Users\jeremyh\Downloads\audio\ffmpeg-20120924-git-bbe9fe4-win64-static\bin\ffmpeg.exe -y -i %1 -acodec libvorbis -aq -2 "%~p1\%~n1.ogg"
"C:\Program Files (x86)\sox-14-4-0\sox.exe" --show-progress --volume 1.15 "%~p1/%~n1.ogg" "%~p1/out/%~n1.ogg" tempo 1.80
rem move away the worked versions, and keep only the new versions in the directory
move %1 "\old"
move "%~p1\%~n1.ogg" "\old"
move "%~p1\out\%~n1.ogg" "%~p1"
rmdir "%~p1\out"
goto :EOF

:WALKDIR
echo WALKDIR:%1,%~n1
for /r %1 %%G IN (*.m4a *.mp3 *.m4b) do call :OGGIT "%%G"
goto :EOF
