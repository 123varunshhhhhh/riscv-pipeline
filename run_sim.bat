@echo off
REM ============================================================
REM run_sim.bat — Quick simulation launcher for Windows
REM Automatically detects standard Icarus Verilog install path
REM ============================================================

REM Check if iverilog is in PATH; if not, check default install locations
where iverilog >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    if exist "C:\iverilog\bin" set "PATH=%PATH%;C:\iverilog\bin;C:\iverilog\gtkwave\bin"
    if exist "C:\Program Files\iverilog\bin" set "PATH=%PATH%;C:\Program Files\iverilog\bin"
    if exist "%LOCALAPPDATA%\Programs\iverilog\bin" set "PATH=%PATH%;%LOCALAPPDATA%\Programs\iverilog\bin"
)

echo.
echo ==========================================
echo   RISC-V Pipeline — Quick Simulation
echo ==========================================
echo.

REM Create output directory
if not exist sim\waveforms mkdir sim\waveforms

echo [1/3] Compiling all RTL + testbench...
iverilog -g2012 ^
  -o sim\tb_top_out ^
  rtl\alu.v ^
  rtl\reg_file.v ^
  rtl\if_stage.v ^
  rtl\id_stage.v ^
  rtl\ex_stage.v ^
  rtl\mem_stage.v ^
  rtl\wb_stage.v ^
  rtl\pipeline_regs.v ^
  rtl\hazard_unit.v ^
  rtl\branch_predictor.v ^
  rtl\top.v ^
  verif\tb_top.v

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Compilation failed. Check RTL errors above.
    pause
    exit /b 1
)
echo [OK] Compilation successful.
echo.

echo [2/3] Running simulation...
vvp sim\tb_top_out
echo.

echo [3/3] Done! Waveform saved to: sim\waveforms\tb_top.vcd
echo       Open with GTKWave: gtkwave sim\waveforms\tb_top.vcd
echo.

REM Also run the ALU standalone testbench
echo --- ALU Standalone Test ---
iverilog -g2012 -o sim\alu_tb_out rtl\alu.v verif\tb_alu_standalone.v
if %ERRORLEVEL% EQU 0 (
    vvp sim\alu_tb_out
) else (
    echo [WARN] ALU testbench compilation failed.
)

echo.
echo ==========================================
echo   Simulation complete!
echo ==========================================
pause

