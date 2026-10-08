@echo off
rem Remove Quartus build products.
del /s *.bak
del /s *.orig
del /s *.rej
del /s *~
rmdir /s /q db
rmdir /s /q incremental_db
rmdir /s /q output_files
rmdir /s /q simulation
rmdir /s /q greybox_tmp
rmdir /s /q hc_output
rmdir /s /q .qsys_edit
rmdir /s /q hps_isw_handoff
rmdir /s /q sys\.qsys_edit
rmdir /s /q sys\vip
for /d %%i in (sys\*_sim) do rmdir /s /q "%%i"
del build_id.v
del c5_pin_model_dump.txt
del PLLJ_PLLSPE_INFO.txt
del /s *.qws
del /s *.ppf
del /s *.ddb
del *.cdf
del *.rpt
del *.smsg
del *.summary
pause
