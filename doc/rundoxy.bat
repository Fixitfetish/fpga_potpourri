:: delete previously generated files
@if exist html ( rd /s /q html > nul )
::@if exist x.chm ( del /F x.chm > nul )

"C:\FPGA\doxygen\doxygen" doxygen.cfg

@echo.
@echo.Ready to open HTML documentation ./html/index.html
@echo.

pause
