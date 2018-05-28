@echo off
cd %~dp0
node version_generator.js -v 1.0.1 -u http://192.168.6.137:8080/game/assets/ -s assets/ -d assets/
pause