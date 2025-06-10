/*
 * ARTICo3 Linux-based FPGA reconfiguration API
 *
 * Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date        : November 2017
 * Description : This file contains the reconfiguration functions to
 *               load full and partial bitstreams under Linux. A macro
 *               controls the type of implementation used:
 *                   1. Legacy  : xdevcfg
 *                   2. Default : fpga_manager (Linux framework)
 *
 */

#ifndef _ARTICO3_RCFG_H_
#define _ARTICO3_RCFG_H_

#include <stdint.h>
extern volatile uint32_t *artico3_rcfg;
extern volatile uint32_t *artico3_xdma_hw;

/*
 * From linux-xlnx (https://github.com/Xilinx/linux-xlnx) version
 * xilinx-v2017.1, the default reconfiguration framework to be used in
 * all FPGAs is the fpga_manager framework. This changes the use of a
 * character device (/dev/xdevcfg) for direct firmware loading from the
 * kernel (/lib/firmware).
 *
 * Zynq-7000 devices are able to work with both alternatives, whereas
 * the new Zynq UltraScale+ MPSoC devices only work with fpga_manager.
 * Legacy option is supported by compiling applications using the macro
 * A3_LEGACY_RCFG set to 1. However, its use is completely discouraged.
 *
 * NOTE: as of version xilinx-v2017.2, there is a problem in the source
 *       files for the fpga_manager framework in Zynq-7000 devices that
 *       requires modifications in the driver functions to enable partial
 *       reconfiguration. There are two options to perform them:
 *
 * [1] sed -i 's|info.flags = 0;|info.flags = mgr->flags;|' linux-xlnx/drivers/fpga/fpga-mgr.c
 * [2] sed -i 's|info->flags|mgr->flags|' linux-xlnx/drivers/fpga/zynq-fpga.c
 *
 */

#ifndef A3_LEGACY_RCFG
#define A3_LEGACY_RCFG 0
#endif

/**
 * The RW_MAX_SIZE constant represents the maximum size for read/write operations.
 * It is defined as 0x7ffff000.
 */
#ifdef AU250
#define RW_MAX_SIZE	0x7ffff000
#endif

/*
 * Main reconfiguration function
 *
 * This function creates an ARTICo3 kernel in the current application.
 *
 * @name       : name of the bitstream file to be loaded
 * @is_partial : flag to indicate whether the bitstream file is partial
 *
 * Return : 0 on success, error code otherwise
 *
 */
int fpga_load(const char *name, uint8_t is_partial);

#ifdef AU250
/*
 * Writes data from a buffer to a file descriptor.
 *
 * @param fname The name of the file to write to.
 * @param fd The file descriptor to write to.
 * @param buffer The buffer containing the data to write.
 * @param size The size of the data to write.
 * @param base The base offset of the data in the buffer.
 * @return The number of bytes written, or -1 on error.
 */
ssize_t write_from_buffer(char *fname, int fd, char *buffer, uint64_t size, uint64_t base);

/**
 * @brief Reads data from a file descriptor into a buffer.
 *
 * This function reads data from the specified file descriptor and stores it in the provided buffer.
 *
 * @param fname The name of the file being read.
 * @param fd The file descriptor to read from.
 * @param buffer The buffer to store the read data.
 * @param size The size of the buffer.
 * @param base The base offset for reading the file.
 *
 * @return The number of bytes read, or -1 if an error occurred.
 */
ssize_t read_to_buffer(char *fname, int fd, char *buffer, uint64_t size, uint64_t base);
#endif /* AU250 */

#endif /* _ARTICO3_RCFG_H_ */
