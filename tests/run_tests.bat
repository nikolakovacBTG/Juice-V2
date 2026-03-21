@echo off
:: Juice V1 Test Runner - headless Godot
:: Usage: run_tests.bat [optional suite filter]
:: Example: run_tests.bat --suite=node_properties

set GODOT="C:\Portable Software\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe"
set PROJECT="D:\Godot projekti\juice-demo"

%GODOT% --headless --path %PROJECT% res://tests/run_tests.tscn -- %*
