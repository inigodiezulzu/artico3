#
# ARTICo3 IP library script for Vivado
#
# Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date        : August 2017
#
# Description : This script generates a full system in Vivado using the
#               IP library created by create_ip_library.tcl by instantiating
#               the required modules and making the necessary connections.
#

<a3<artico3_preproc>a3>

variable script_file
set script_file "export.tcl"

# Help information for this script
proc help {} {

    variable script_file
    puts "\nDescription:"
    puts "This TCL script sets up all modules and connections in an IP integrator"
    puts "block design needed to create a fully functional ARTICo3 design.\n"
    puts "Syntax when called in batch mode:"
    puts "vivado -mode tcl -source $script_file -tclargs \[-proj_name <Name> -proj_path <Path>\]"
    puts "$script_file -tclargs \[--help\]\n"
    puts "Usage:"
    puts "Name                   Description"
    puts "-------------------------------------------------------------------------"
    puts "-proj_name <Name>        Optional: When given, a new project will be"
    puts "                         created with the given name"
    puts "-proj_path <path>        Path to the newly created project"
    puts "\[--help\]               Print help information for this script"
    puts "-------------------------------------------------------------------------\n"
    exit 0

}

set artico3_ip_dir [pwd]/pcores
set proj_name ""
set proj_path ""

# Parse command line arguments
if { $::argc > 0 } {
    for {set i 0} {$i < [llength $::argc]} {incr i} {
        set option [string trim [lindex $::argv $i]]
        switch -regexp -- $option {
            "-proj_name" { incr i; set proj_name  [lindex $::argv $i] }
            "-proj_path" { incr i; set proj_path  [lindex $::argv $i] }
            "-help"      { help }
            default {
                if { [regexp {^-} $option] } {
                    puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
                    return 1
                }
            }
        }
    }
}

proc artico3_hw_setup {new_project_path new_project_name artico3_ip_dir} {

    # Create new project if "new_project_name" is given.
    # Otherwise current project will be reused.
    if { [llength $new_project_name] > 0} {
        create_project -force $new_project_name $new_project_path -part xcu250-figd2104-2L-e
        set_property board_part xilinx.com:au250:part0:1.3 [current_project]
    }

    # Save directory and project names to variables for easy reuse
    set proj_name [current_project]
    set proj_dir [get_property directory [current_project]]

    # Set project properties
    #set_property "board_part_repo_paths" -value "[file normalize "$/tools/Xilinx/Vivado/2023.1/data/xhub/boards/XilinxBoardStore/boards/Xilinx"]" $proj_name
    set_property "default_lib" "xil_defaultlib" $proj_name
    set_property "sim.ip.auto_export_scripts" "1" $proj_name
    set_property "simulator_language" "Mixed" $proj_name
    set_property "target_language" "VHDL" $proj_name
    

    # Create 'sources_1' fileset (if not found)
    if {[string equal [get_filesets -quiet sources_1] ""]} {
        create_fileset -srcset sources_1
    }

    # Create 'constrs_1' fileset (if not found)
    if {[string equal [get_filesets -quiet constrs_1] ""]} {
        create_fileset -constrset constrs_1
    }

    # Create 'sim_1' fileset (if not found)
    if {[string equal [get_filesets -quiet sim_1] ""]} {
        create_fileset -simset sim_1
    }

    # Set 'sim_1' fileset properties
    set obj [get_filesets sim_1]
    set_property "transport_int_delay" "0" $obj
    set_property "transport_path_delay" "0" $obj
    set_property "xelab.nosort" "1" $obj
    set_property "xelab.unifast" "" $obj
# VIVADO CONFIGURATION
    # Create 'synth_1' run (if not found)
	if {[string equal [get_runs -quiet synth_1] ""]} {
    create_run -name synth_1 -part xcu250-figd2104-2L-e -flow {Vivado Synthesis 2023} -strategy "Vivado Synthesis Defaults" -report_strategy {No Reports} -constrset constrs_1
	} else {
	  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
	  set_property flow "Vivado Synthesis 2023" [get_runs synth_1]
	}
# END

    # Apply custom configuration for Synthesis
    set obj [get_runs synth_1]
    set_property "steps.synth_design.args.flatten_hierarchy" "rebuilt" $obj

    # set the current synth run
    current_run -synthesis [get_runs synth_1]

	
# VIVADO CONFIGURATION
    # Create 'impl_1' run (if not found)
    if {[string equal [get_runs -quiet impl_1] ""]} {
    create_run -name impl_1 -part xcu250-figd2104-2L-e -flow {Vivado Implementation 2023} -strategy "Vivado Implementation Defaults" -report_strategy {No Reports} -constrset constrs_1 -parent_run synth_1
	} else {
	  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
	  set_property flow "Vivado Implementation 2023" [get_runs impl_1]
	}

# END

    # Apply custom configuration for Implementation
    set obj [get_runs impl_1]
    set_property "steps.write_bitstream.args.mask_file" false $obj
    set_property "steps.write_bitstream.args.bin_file" false $obj
    set_property "steps.write_bitstream.args.readback_file" false $obj
    set_property "steps.write_bitstream.args.verbose" false $obj

    # set the current impl run
    current_run -implementation [get_runs impl_1]
    #
    # Start block design
    #

    create_bd_design "system"
    update_compile_order -fileset sources_1
	# Set 'sim_1' fileset properties
	
	
    # Add artico3 repository
    set_property  ip_repo_paths $artico3_ip_dir [current_project]
    update_ip_catalog
    
	
    # Create interface ports
	set pci_express_x16 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pci_express_x16 ]

	set pcie_refclk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk ]
	set_property -dict [ list \
	CONFIG.FREQ_HZ {100000000} \
	] $pcie_refclk

	# Create ports
	set pcie_perstn [ create_bd_port -dir I -type rst pcie_perstn ]
	set_property -dict [ list \
	CONFIG.POLARITY {ACTIVE_LOW} \
	] $pcie_perstn
	
	set user_lnk_up_0 [ create_bd_port -dir O user_lnk_up_0 ]
	
	# Create instance: xdma_0, and set properties
	set xdma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:4.1 xdma_0 ]
	set_property -dict [list \
	CONFIG.PCIE_BOARD_INTERFACE {pci_express_x16} \
	CONFIG.SYS_RST_N_BOARD_INTERFACE {pcie_perstn} \
	CONFIG.axilite_master_en {true} \
	CONFIG.axilite_master_size {8} \
	CONFIG.mcap_enablement {Tandem_PCIe_with_Field_Updates} \
	CONFIG.pciebar2axibar_axil_master {0x40000000} \
	CONFIG.pf0_base_class_menu {Simple_communication_controllers} \
	CONFIG.pf0_device_id {9011} \
	CONFIG.ref_clk_freq {100_MHz} \
	CONFIG.xdma_axi_intf_mm {AXI_Memory_Mapped} \
	CONFIG.xdma_num_usr_irq {1} \
	CONFIG.xdma_rnum_chnl {4} \
	CONFIG.xdma_wnum_chnl {4} \
	] $xdma_0

	# Create instance: util_ds_buf, and set properties
	set util_ds_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf ]
	set_property -dict [list \
	CONFIG.DIFF_CLK_IN_BOARD_INTERFACE {pcie_refclk} \
	CONFIG.USE_BOARD_FLOW {true} \
	] $util_ds_buf

	# Create instance: clk_wiz_0, and set properties
	set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
	set_property -dict [list \
	CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
	CONFIG.RESET_BOARD_INTERFACE {Custom} \
	CONFIG.RESET_PORT {resetn} \
	CONFIG.RESET_TYPE {ACTIVE_LOW} \
	CONFIG.USE_BOARD_FLOW {true} \
	CONFIG.USE_LOCKED {false} \
	] $clk_wiz_0


	# Create instance: rst_clk_wiz_0_100M, and set properties
	set rst_clk_wiz_0_100M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_clk_wiz_0_100M ]
	
	# Create instance: axi_gpio_0, and set properties
	set axi_gpio_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0 ]
	set_property -dict [list \
	CONFIG.C_ALL_INPUTS_2 {1} \
	CONFIG.C_ALL_OUTPUTS {1} \
	CONFIG.C_GPIO2_WIDTH {7} \
	CONFIG.C_GPIO_WIDTH {1} \
	CONFIG.C_IS_DUAL {1} \
	] $axi_gpio_0


	# Create instance: dfx_axi_shutdown_man_0, and set properties
	set dfx_axi_shutdown_man_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_axi_shutdown_manager:1.0 dfx_axi_shutdown_man_0 ]
	set_property CONFIG.RP_IS_MASTER {false} $dfx_axi_shutdown_man_0

	  # Create instance: xlconcat_0, and set properties
	set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
	set_property CONFIG.NUM_PORTS {1} $xlconcat_0
	
	# Create instance: xlconcat_1, and set properties
	set xlconcat_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_1 ]
	set_property CONFIG.NUM_PORTS {7} $xlconcat_1


	# Create instance: dfx_decoupler_0, and set properties
	set dfx_decoupler_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_decoupler:1.0 dfx_decoupler_0 ]
	set_property -dict [list \
	CONFIG.ALL_PARAMS {INTF {intf_1 {ID 0 VLNV xilinx.com:signal:interrupt_rtl:1.0 SIGNALS {INTERRUPT {PRESENT 1 WIDTH 1}}}} HAS_AXI_LITE 0 ALWAYS_HAVE_AXI_CLK 1 IPI_PROP_COUNT 0} \
	CONFIG.GUI_INTERFACE_NAME {intf_1} \
	CONFIG.GUI_SELECT_INTERFACE {0} \
	CONFIG.GUI_SELECT_MODE {master} \
	CONFIG.GUI_SELECT_VLNV {xilinx.com:signal:interrupt_rtl:1.0} \
	] $dfx_decoupler_0


	# Create instance: dfx_axi_shutdown_man_1, and set properties
	set dfx_axi_shutdown_man_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dfx_axi_shutdown_manager:1.0 dfx_axi_shutdown_man_1 ]
	set_property -dict [list \
	CONFIG.DP_PROTOCOL {AXI4LITE} \
	CONFIG.RP_IS_MASTER {false} \
	] $dfx_axi_shutdown_man_1
	
	
# APPLICATION CONFIGURATION

    # Create instance of ARTICo3 infrastructure
    set artico3_shuffler_0 [ create_bd_cell -type ip -vlnv cei.upm.es:artico3:artico3_shuffler:1.0 artico3_shuffler_0 ]

    # Create instances of hardware kernels
<a3<generate for SLOTS>a3>
    create_bd_cell -type ip -vlnv cei.upm.es:artico3:<a3<SlotCoreName>a3>:[string range <a3<SlotCoreVersion>a3> 0 2] "a3_slot_<a3<id>a3>"
<a3<end generate>a3>

    # Required to avoid problems with AXI Interconnect
    set_property CONFIG.C_S_AXI_ID_WIDTH {12} $artico3_shuffler_0

    # Create and configure new AXI Interconnects
	set axi_a3ctrl [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_a3ctrl ]
	set_property -dict [list \
	CONFIG.NUM_MI {2} \
	CONFIG.NUM_SI {1} \
	] $axi_a3ctrl

	set axi_a3data [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_a3data ]
	set_property -dict [list \
	CONFIG.NUM_CLKS {2} \
	CONFIG.NUM_MI {1} \
	CONFIG.NUM_SI {1} \
	] $axi_a3data
	
	# Connect AXI interfaces

	# Create DFX_decoupler interface connections
	connect_bd_intf_net -intf_net axi_a3data_M00_AXI [get_bd_intf_pins axi_a3data/M00_AXI] [get_bd_intf_pins dfx_axi_shutdown_man_0/S_AXI]
	connect_bd_intf_net -intf_net axi_a3ctrl_M00_AXI [get_bd_intf_pins axi_a3ctrl/M00_AXI] [get_bd_intf_pins dfx_axi_shutdown_man_1/S_AXI]
	connect_bd_intf_net -intf_net axi_a3ctrl_M01_AXI [get_bd_intf_pins axi_a3ctrl/M01_AXI] [get_bd_intf_pins axi_gpio_0/S_AXI]
	connect_bd_intf_net -intf_net DFX_decoupler_M_AXI1 [get_bd_intf_pins artico3_shuffler_0/s00_axi] [get_bd_intf_pins dfx_axi_shutdown_man_1/M_AXI]
	connect_bd_intf_net -intf_net dfx_axi_shutdown_man_0_M_AXI [get_bd_intf_pins dfx_axi_shutdown_man_0/M_AXI] [get_bd_intf_pins artico3_shuffler_0/s01_axi]

	# XDMA
	connect_bd_intf_net -intf_net xdma_0_M_AXI [get_bd_intf_pins xdma_0/M_AXI] [get_bd_intf_pins axi_a3data/S00_AXI]
	connect_bd_intf_net -intf_net xdma_0_M_AXI_LITE [get_bd_intf_pins xdma_0/M_AXI_LITE] [get_bd_intf_pins axi_a3ctrl/S00_AXI]

	connect_bd_intf_net -intf_net xdma_0_pcie_mgt [get_bd_intf_ports pci_express_x16] [get_bd_intf_pins xdma_0/pcie_mgt]
	connect_bd_intf_net -intf_net pcie_refclk_1 [get_bd_intf_ports pcie_refclk] [get_bd_intf_pins util_ds_buf/CLK_IN_D]
	

    # Connect clocks
	connect_bd_net -net xdma_0_axi_aclk [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_a3ctrl/S00_ACLK] [get_bd_pins clk_wiz_0/clk_in1] [get_bd_pins axi_a3data/aclk1]
								   
	connect_bd_net -net clk_wiz_0_clk_out1 [get_bd_pins clk_wiz_0/clk_out1] \
						[get_bd_pins axi_a3data/aclk] \
						[get_bd_pins rst_clk_wiz_0_100M/slowest_sync_clk] \
						[get_bd_pins axi_a3ctrl/M00_ACLK] \
						[get_bd_pins axi_a3ctrl/M01_ACLK] \
						[get_bd_pins axi_a3ctrl/ACLK] \
						[get_bd_pins artico3_shuffler_0/s_axi_aclk] \
						[get_bd_pins dfx_axi_shutdown_man_0/clk] \
						[get_bd_pins axi_gpio_0/s_axi_aclk] \
						[get_bd_pins dfx_axi_shutdown_man_1/clk]
										   
	connect_bd_net -net util_ds_buf_IBUF_DS_ODIV2 [get_bd_pins util_ds_buf/IBUF_DS_ODIV2] [get_bd_pins xdma_0/sys_clk]
	
	connect_bd_net -net util_ds_buf_IBUF_OUT [get_bd_pins util_ds_buf/IBUF_OUT] [get_bd_pins xdma_0/sys_clk_gt]
	
    # Connect resets
	
	connect_bd_net -net pcie_perstn_1 [get_bd_ports pcie_perstn] [get_bd_pins xdma_0/sys_rst_n]
	
	connect_bd_net [get_bd_pins rst_clk_wiz_0_100M/peripheral_aresetn] \
						[get_bd_pins axi_a3data/aresetn] \
						[get_bd_pins axi_a3ctrl/M00_ARESETN] \
						[get_bd_pins axi_a3ctrl/M01_ARESETN] \
						[get_bd_pins axi_a3ctrl/ARESETN] \
						[get_bd_pins artico3_shuffler_0/s_axi_aresetn] \
						[get_bd_pins dfx_axi_shutdown_man_0/resetn] \
						[get_bd_pins axi_gpio_0/s_axi_aresetn] \
						[get_bd_pins dfx_axi_shutdown_man_1/resetn]
						
	connect_bd_net -net xdma_0_axi_aresetn [get_bd_pins xdma_0/axi_aresetn] \
					   [get_bd_pins axi_a3ctrl/S00_ARESETN]  \
					   [get_bd_pins clk_wiz_0/resetn] \
					   [get_bd_pins rst_clk_wiz_0_100M/ext_reset_in]
	
	# Connect GPIOs
	
	connect_bd_net -net xdma_0_user_lnk_up [get_bd_pins xdma_0/user_lnk_up] [get_bd_ports user_lnk_up_0]
	connect_bd_net -net dfx_axi_shutdown_man_0_in_shutdown [get_bd_pins dfx_axi_shutdown_man_0/in_shutdown] [get_bd_pins xlconcat_1/In1]
	connect_bd_net -net dfx_axi_shutdown_man_0_rd_in_shutdown [get_bd_pins dfx_axi_shutdown_man_0/rd_in_shutdown] [get_bd_pins xlconcat_1/In3]
	connect_bd_net -net dfx_axi_shutdown_man_0_wr_in_shutdown [get_bd_pins dfx_axi_shutdown_man_0/wr_in_shutdown] [get_bd_pins xlconcat_1/In2]
	connect_bd_net -net dfx_axi_shutdown_man_1_in_shutdown [get_bd_pins dfx_axi_shutdown_man_1/in_shutdown] [get_bd_pins xlconcat_1/In4]
	connect_bd_net -net dfx_axi_shutdown_man_1_rd_in_shutdown [get_bd_pins dfx_axi_shutdown_man_1/rd_in_shutdown] [get_bd_pins xlconcat_1/In6]
	connect_bd_net -net dfx_axi_shutdown_man_1_wr_in_shutdown [get_bd_pins dfx_axi_shutdown_man_1/wr_in_shutdown] [get_bd_pins xlconcat_1/In5]
	connect_bd_net -net dfx_decoupler_0_decouple_status [get_bd_pins dfx_decoupler_0/decouple_status] [get_bd_pins xlconcat_1/In0]
	connect_bd_net -net xlconcat_1_dout [get_bd_pins xlconcat_1/dout] [get_bd_pins axi_gpio_0/gpio2_io_i]
   	connect_bd_net -net axi_gpio_0_gpio_io_o [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_pins dfx_axi_shutdown_man_0/request_shutdown] [get_bd_pins dfx_decoupler_0/decouple] [get_bd_pins dfx_axi_shutdown_man_1/request_shutdown]

    # Connect interrupts	
    connect_bd_net -net artico3_shuffler_0_interrupt [get_bd_pins artico3_shuffler_0/interrupt] [get_bd_pins dfx_decoupler_0/rp_intf_1_INTERRUPT]
    connect_bd_net -net xlconcat_0_dout [get_bd_pins xlconcat_0/dout] [get_bd_pins xdma_0/usr_irq_req]
    connect_bd_net -net dfx_decoupler_0_s_intf_1_INTERRUPT [get_bd_pins dfx_decoupler_0/s_intf_1_INTERRUPT] [get_bd_pins xlconcat_0/In0]
	
    # Connect ARTICo3 slots
<a3<generate for SLOTS>a3>
    connect_bd_intf_net -intf_net artico3_slot<a3<id>a3> [get_bd_intf_pins artico3_shuffler_0/m<a3<id>a3>_artico3] [get_bd_intf_pins a3_slot_<a3<id>a3>/s_artico3]
<a3<end generate>a3>

    # Generate memory-mapped segments for custom peripherals
    assign_bd_address -offset 0x80000000 -range 0x00100000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs artico3_shuffler_0/s01_axi/reg0] -force
    assign_bd_address -offset 0x40400000 -range 0x00400000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs artico3_shuffler_0/s00_axi/reg0] -force
    assign_bd_address -offset 0x40002000 -range 0x00000400 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] [get_bd_addr_segs axi_gpio_0/S_AXI/Reg] -force
    # Create DFX_decoupler group
   	group_bd_cells DFX_decoupler [get_bd_cells dfx_axi_shutdown_man_1] [get_bd_cells axi_gpio_0] [get_bd_cells dfx_decoupler_0] [get_bd_cells dfx_axi_shutdown_man_0] [get_bd_cells xlconcat_1]


# END

    # Update layout of block design
    regenerate_bd_layout

    #make wrapper file; vivado needs it to implement design
    make_wrapper -files [get_files $proj_dir/$proj_name.srcs/sources_1/bd/system/system.bd] -top
    add_files -norecurse $proj_dir/$proj_name.gen/sources_1/bd/system/hdl/system_wrapper.vhd
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
    set_property top system_wrapper [current_fileset]
    save_bd_design

# KERNEL LIBRARY (Xilinx Partial Reconfiguration Flow)

<a3<generate for KERNELS(KernCoreName!="a3_dummy")>a3>
    #
    # Kernel : <a3<KernCoreName>a3>
    #

    # Create submodule block design
    create_bd_design "<a3<KernCoreName>a3>"

    # Create dummy port
    create_bd_intf_port -mode Slave -vlnv cei.upm.es:artico3:artico3_rtl:1.0 s_artico3

    # Create module instance
    create_bd_cell -type ip -vlnv cei.upm.es:artico3:<a3<KernCoreName>a3>:[string range <a3<KernCoreVersion>a3> 0 2] "slot"

    # Connect ARTICo3 slot
    connect_bd_intf_net -intf_net artico3_slot [get_bd_intf_ports s_artico3] [get_bd_intf_pins slot/s_artico3]

    # Update layout of block design
    regenerate_bd_layout

    #make wrapper file; vivado needs it to implement design
    make_wrapper -files [get_files $proj_dir/$proj_name.srcs/sources_1/bd/<a3<KernCoreName>a3>/<a3<KernCoreName>a3>.bd] -top
    add_files -norecurse $proj_dir/$proj_name.gen/sources_1/bd/<a3<KernCoreName>a3>/hdl/<a3<KernCoreName>a3>_wrapper.vhd
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
    save_bd_design
<a3<end generate>a3>
# END

# LOW-LEVEL DEPENDENCIES

	# Add DPR constraints
	# TODO: Document the usage of the hardcoded constraint file and suggest parameterization for compatibility with different hardware
	add_files -fileset constrs_1 -norecurse $proj_dir/xcu250.xdc

# END

}

#
# Main script starts here
#

artico3_hw_setup $proj_path $proj_name $artico3_ip_dir
puts "\[A3DK\] project creation finished"
