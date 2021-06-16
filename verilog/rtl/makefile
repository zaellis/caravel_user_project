# Makefile inspired by https://github.com/cliffordwolf/icestorm/blob/master/examples/icestick/Makefile
#
# The following license is from the icestorm project and specifically applies to this file only:
#
#  Permission to use, copy, modify, and/or distribute this software for any
#  purpose with or without fee is hereby granted, provided that the above
#  copyright notice and this permission notice appear in all copies.
#
#  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
#  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
#  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
#  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
#  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
#  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

PROJ := wb_CAN
TOP_LEVEL_FILE := $(PROJ).sv
COMPONENT_FILES := CAN_receiver.sv CRCcheck.sv edgedetect.sv flex_counter.sv flex_stp_sr.sv flex_pts_sr.sv RCU.sv timer.sv tx_timer.sv TCU.sv ECU.sv wb_slave.sv fifo.sv
TESTBENCH := tb_$(PROJ).sv

TB_MODULE := $(notdir $(basename $(TEST_BENCH)))
TOP_MODULE := $(notdir $(basename $(TOP_LEVEL_FILE)))

help:
	@echo "----------------------------------------------------------------"
	@echo "Administrative targets:"
	@echo "  clean         - removes the intermediate files"
	@echo "  veryclean     - removes all generated files"
	@echo "  print_vars    - prints the contents of the variables"
	@echo
	@echo
	@echo "Simulation targets:"
	@echo "  tbsim_source      - compiles and simulates the source version"
	@echo "                      of a full design including its top level"
	@echo "                      test bench"
	@echo "----------------------------------------------------------------"

vivado/vivado_project.xpr:
	vivado -mode batch -source vivado_manage.tcl -notrace -tclargs setup
	@rm -f *.backup.jou *.backup.log

tbsim_source: vivado/vivado_project.xpr
	vivado -mode batch -source vivado_manage.tcl -notrace -tclargs simulate $(PROJ) $(TESTBENCH) $(TOP_LEVEL_FILE) $(COMPONENT_FILES)
	@rm -f *.backup.jou *.backup.log vivado_pid* vivado.*
clean:
	@echo "Removing intermediate files"
	@rm -f vivado.*
	@rm -f *.backup.jou *.backup.log vivado_pid*
	@echo "Done"

veryclean: clean
	@echo  "Removing all generated files"
	@rm -rf mapped/*.v *_syntb.vcd vivado/* *.bin logs/*.log logs/*.rpt make_debug.txt
	@rm -rf .Xil/ vivado/
	@echo  "Done"

print_vars:
	@echo "Component Files: \n $(foreach file, $(COMPONENT_FILES), $(file)\n)"
	@echo "Top level File: $(TOP_LEVEL_FILE)"
	@echo "Testbench: $(TESTBENCH)"
	@echo "Top level module: $(TOP_MODULE)"

.SECONDARY:
.PHONY: help clean veryclean tbsim_source print_vars
