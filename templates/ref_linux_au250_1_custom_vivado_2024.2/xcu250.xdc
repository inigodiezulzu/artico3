#----------------------------------------------------------------------------
##
## Project    : The Xilinx PCI Express DMA
## File       : xcu250.xdc
## Version    : 1.0
##-----------------------------------------------------------------------------
#
# User Configuration
# Link Width   - x16
# Link Speed   - Gen3
# Family       - virtexuplus
# Part         - xcu250
# Package      - figd2104
# Speed grade  - -2L
#
# PCIe Block INT - 1
# PCIe Block STR - X0Y1
#

# Xilinx Reference Board is AU250

set_property CONFIG_VOLTAGE 1.8 [current_design]
#set_property CONFIG_MODE SPIx4 						[current_design]
set_property BITSTREAM.CONFIG.CONFIGFALLBACK Enable [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN disable [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
#set_property BITSTREAM.CONFIG.CONFIGRATE 85.0          [current_design]                 ;# Customer can try but may not be reliable over all conditions.
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
#set_property BITSTREAM.CONFIG.SPI_OPCODE 8'h6C        [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]
set_property BITSTREAM.STARTUP.MATCH_CYCLE NOWAIT [current_design]


# Add the inserted dbg_hub cell to the appropriate design partition.
set_property HD.TANDEM_IP_PBLOCK Stage1_Main [get_cells dbg_hub]


set_property HD.TANDEM_IP_PBLOCK Stage1_IO [get_cells -quiet -hierarchical pcie_perstn_IBUF_inst]
set_property HD.TANDEM 1 [get_cells dbg_hub]

set_property HD.TANDEM 1 [get_cells -quiet -hierarchical pcie_perstn_IBUF_inst]

add_cells_to_pblock [get_pblocks system_i_xdma_0_inst_pcie4_ip_i_inst_system_xdma_0_0_pcie4_ip_Stage1_main] [get_cells -quiet -hierarchical pcie_perstn_IBUF_inst]
set_property SNAPPING_MODE ON [get_pblocks system_i_xdma_0_inst_pcie4_ip_i_inst_system_xdma_0_0_pcie4_ip_Stage1_main]

# Configure static logic
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical artico3_shuffler_0]

create_pblock artico3_shuffler_0
add_cells_to_pblock [get_pblocks artico3_shuffler_0] [get_cells -quiet [list system_i/artico3_shuffler_0]]
resize_pblock [get_pblocks artico3_shuffler_0] -add {CLOCKREGION_X3Y8:CLOCKREGION_X4Y15}


# Set IP cores as reconfigurable partitions
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_0]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_1]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_2]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_3]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_4]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_5]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_6]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_7]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_8]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_9]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_10]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_11]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_12]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_13]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_14]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_15]


#Configure LEDS

set_property PACKAGE_PIN BA20 [get_ports user_lnk_up_0]
set_property IOSTANDARD LVCMOS12 [get_ports user_lnk_up_0]
set_property DRIVE 8 [get_ports user_lnk_up_0]



# Configure slot #0

create_pblock a3_slot_0
add_cells_to_pblock [get_pblocks a3_slot_0] [get_cells -quiet [list system_i/a3_slot_0]]
resize_pblock [get_pblocks a3_slot_0] -add {CLOCKREGION_X5Y15:CLOCKREGION_X7Y15}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_0]

# Configure slot #1

create_pblock a3_slot_1
add_cells_to_pblock [get_pblocks a3_slot_1] [get_cells -quiet [list system_i/a3_slot_1]]
resize_pblock [get_pblocks a3_slot_1] -add {CLOCKREGION_X5Y14:CLOCKREGION_X7Y14}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_1]

# Configure slot #2

create_pblock a3_slot_2
add_cells_to_pblock [get_pblocks a3_slot_2] [get_cells -quiet [list system_i/a3_slot_2]]
resize_pblock [get_pblocks a3_slot_2] -add {CLOCKREGION_X5Y13:CLOCKREGION_X7Y13}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_2]

# Configure slot #3

create_pblock a3_slot_3
add_cells_to_pblock [get_pblocks a3_slot_3] [get_cells -quiet [list system_i/a3_slot_3]]
resize_pblock [get_pblocks a3_slot_3] -add {CLOCKREGION_X5Y12:CLOCKREGION_X7Y12}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_3]

# Configure slot #4

create_pblock a3_slot_4
add_cells_to_pblock [get_pblocks a3_slot_4] [get_cells -quiet [list system_i/a3_slot_4]]
resize_pblock [get_pblocks a3_slot_4] -add {CLOCKREGION_X5Y11:CLOCKREGION_X7Y11}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_4]

# Configure slot #5

create_pblock a3_slot_5
add_cells_to_pblock [get_pblocks a3_slot_5] [get_cells -quiet [list system_i/a3_slot_5]]
resize_pblock [get_pblocks a3_slot_5] -add {CLOCKREGION_X5Y10:CLOCKREGION_X7Y10}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_5]

# Configure slot #6

create_pblock a3_slot_6
add_cells_to_pblock [get_pblocks a3_slot_6] [get_cells -quiet [list system_i/a3_slot_6]]
resize_pblock [get_pblocks a3_slot_6] -add {CLOCKREGION_X5Y9:CLOCKREGION_X7Y9}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_6]

# Configure slot #7

create_pblock a3_slot_7
add_cells_to_pblock [get_pblocks a3_slot_7] [get_cells -quiet [list system_i/a3_slot_7]]
resize_pblock [get_pblocks a3_slot_7] -add {CLOCKREGION_X5Y8:CLOCKREGION_X7Y8}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_7]

# Configure slot #8

create_pblock a3_slot_8
add_cells_to_pblock [get_pblocks a3_slot_8] [get_cells -quiet [list system_i/a3_slot_8]]
resize_pblock [get_pblocks a3_slot_8] -add {CLOCKREGION_X0Y15:CLOCKREGION_X2Y15}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_8]

# Configure slot #9

create_pblock a3_slot_9
add_cells_to_pblock [get_pblocks a3_slot_9] [get_cells -quiet [list system_i/a3_slot_9]]
resize_pblock [get_pblocks a3_slot_9] -add {CLOCKREGION_X0Y14:CLOCKREGION_X2Y14}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_9]

# Configure slot #10

create_pblock a3_slot_10
add_cells_to_pblock [get_pblocks a3_slot_10] [get_cells -quiet [list system_i/a3_slot_10]]
resize_pblock [get_pblocks a3_slot_10] -add {CLOCKREGION_X0Y13:CLOCKREGION_X2Y13}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_10]

# Configure slot #11

create_pblock a3_slot_11
add_cells_to_pblock [get_pblocks a3_slot_11] [get_cells -quiet [list system_i/a3_slot_11]]
resize_pblock [get_pblocks a3_slot_11] -add {CLOCKREGION_X0Y12:CLOCKREGION_X2Y12}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_11]

# Configure slot #12

create_pblock a3_slot_12
add_cells_to_pblock [get_pblocks a3_slot_12] [get_cells -quiet [list system_i/a3_slot_12]]
resize_pblock [get_pblocks a3_slot_12] -add {CLOCKREGION_X0Y11:CLOCKREGION_X2Y11}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_12]

# Configure slot #13

create_pblock a3_slot_13
add_cells_to_pblock [get_pblocks a3_slot_13] [get_cells -quiet [list system_i/a3_slot_13]]
resize_pblock [get_pblocks a3_slot_13] -add {CLOCKREGION_X0Y10:CLOCKREGION_X2Y10}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_13]

# Configure slot #14

create_pblock a3_slot_14
add_cells_to_pblock [get_pblocks a3_slot_14] [get_cells -quiet [list system_i/a3_slot_14]]
resize_pblock [get_pblocks a3_slot_14] -add {CLOCKREGION_X0Y9:CLOCKREGION_X2Y9}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_14]

# Configure slot #15

create_pblock a3_slot_15
add_cells_to_pblock [get_pblocks a3_slot_15] [get_cells -quiet [list system_i/a3_slot_15]]
resize_pblock [get_pblocks a3_slot_15] -add {CLOCKREGION_X0Y8:CLOCKREGION_X2Y8}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_15]


set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk]
