@echo off
setlocal enabledelayedexpansion
rem Tags and pushes every release made since the last tag, oldest first (the version bump commits on origin/main).
rem Each tag push starts .github/workflows/build.yml (Windows zip + GitHub release).
cd /d "%~dp0.."
git fetch origin --tags --quiet || goto :err
for /f %%l in ('git describe --tags --abbrev^=0 origin/main') do set LAST=%%l
set N=0
for /f %%c in ('git log --reverse --format^=%%H %LAST%..origin/main -- VERSION') do (
  for /f %%v in ('git show %%c:VERSION') do (
    set EXISTS=
    for /f %%t in ('git ls-remote --tags origin refs/tags/v%%v') do set EXISTS=%%t
    if not defined EXISTS (
      git tag -f v%%v %%c >nul && git push origin v%%v || goto :err
      echo Pushed v%%v at %%c.
      set /a N+=1
    )
  )
)
if %N%==0 echo Nothing to tag since %LAST%.
goto :end
:err
echo Failed. Check your git login and network.
:end
pause
