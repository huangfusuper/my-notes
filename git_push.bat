@echo off
git add ./
git add -u
git add -A
echo �������ύ��Ϣ........
set /p remarks=
echo ������ύ��Ϣ�� %remarks%.
git commit -m %remarks%.
git push origin master
set remarks=
pause