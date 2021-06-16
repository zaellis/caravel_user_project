#!/usr/bin/tclsh

if {$argc > 0} {
    set mode [lindex $argv 0]
    if {$mode == "setup"} {
        puts "Setting up Vivado Project"
        create_project vivado_project vivado/
        exit 0
    } elseif {$mode eq "simulate"} {
        set args [lreplace $argv 0 0]
        set project [lindex $args 0]
        set args [lreplace $args 0 0]
        set testbench [lindex $args 0]
        open_project vivado/vivado_project.xpr
        add_files -fileset [get_filesets sim_1] -quiet $args
        set_property TARGET_SIMULATOR XSim [current_project]
        set_property top tb_$project [get_filesets sim_1]
        set_property top_file $testbench [get_filesets sim_1]
        set_property verilog_define {SIM} [get_filesets sim_1]
        launch_simulation -simset sim_1
        restart
        start_gui
    } else {
        puts "no args"
        exit 1
    }
}