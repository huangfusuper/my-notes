@echo off
git add ./
git add -u
git add -A
echo Please enter your submission information........
set /p remarks=
echo The submitted submission information is %remarks%.
git commit -m %remarks%.
git push origin master
set remarks=
pause