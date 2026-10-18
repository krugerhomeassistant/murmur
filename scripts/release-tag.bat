@echo off
rem Tags and pushes the release for the VERSION on origin/main, if not yet tagged.
rem The tag push starts .github/workflows/build.yml (Windows zip + GitHub release).
cd /d "%~dp0.."
git fetch origin --tags --quiet || goto :err
for /f %%v in ('git show origin/main:VERSION') do set V=%%v
for /f %%c in ('git log -1 --format^=%%H origin/main -- VERSION') do set C=%%c
for /f %%t in ('git ls-remote --tags origin refs/tags/v%V%') do set EXISTS=%%t
if defined EXISTS (echo v%V% is already on GitHub. Nothing to do.& goto :end)
git tag -f v%V% %C% || goto :err
git push origin v%V% || goto :err
echo Pushed v%V% at %C%. The release build has started.
goto :end
:err
echo Failed. Check your git login and network.
:end
pause
