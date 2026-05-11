set company "CIC"
set designer "Student"
set search_path      ". /home/raid7_2/course/cvsd/CBDK_IC_Contest/CIC/SynopsysDC/db ../sram_256x8 ../sram_512x8 ../sram_4096x8 $search_path ../ ./"
set target_library   "slow.db                 \
                      sram_256x8_slow_syn.db  \
                      sram_512x8_slow_syn.db  \
                      sram_4096x8_slow_syn.db \
                     "
set link_library     "* $target_library"
set symbol_library   "tsmc13.sdb generic.sdb"
set synthetic_library "dw_foundation.sldb"

set hdlin_translate_off_skip_text "TRUE"
set edifout_netlist_only "TRUE"
set verilogout_no_tri true

set hdlin_enable_presto_for_vhdl "TRUE"
set sh_enable_line_editing true
set sh_line_editing_mode emacs
history keep 100
alias h history

## PrimeTime Script
set power_enable_analysis TRUE
set power_analysis_mode time_based

read_file -format verilog  ../SYN/Netlist/SpMDV_syn.v
current_design SpMDV
link
source ../SYN/Netlist/SpMDV_syn.sdc
read_sdf -load_delay net ../SYN/Netlist/SpMDV_syn.sdf

## ===== Analysis Window =====
read_vcd  -strip_path testbed/u_SpMDV  ../GATE/SpMDV.fsdb \
          -time {248390 412280}
update_power
report_power
report_power > SpMDV.power


exit
