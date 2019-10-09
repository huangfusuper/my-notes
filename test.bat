@echo off
git add ./
git add -u
git add -A
echo 请输入提交信息........
set /p remarks=
echo 输入的提交信息是 %remarks%.
git commit -m %remarks%.
git push origin master
set remarks=
pause