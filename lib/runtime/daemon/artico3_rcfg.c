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

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "artico3_rcfg.h"
#include "artico3_dbg.h"

#if A3_LEGACY_RCFG

/*
 * Main reconfiguration function (legacy -> xdevcfg)
 *
 * This function loads a bitstream file (either total or partial) using
 * the xdevcfg reconfiguration interface.
 *
 * @name       : name of the bitstream file to be loaded
 * @is_partial : flag to indicate whether the bitstream file is partial
 *
 * Return : 0 on success, error code otherwise
 *
 */
int fpga_load(const char *name, uint8_t is_partial) {
    int fd;
    FILE *fp;
    uint32_t buffer[1024];
    int ret;

    // Set flag when partial reconfiguration is required
    if (is_partial) {

        // Open configuration file
        fd = open("/sys/bus/platform/devices/f8007000.devcfg/is_partial_bitstream", O_RDWR);
        if (fd < 0) {
            a3_print_error("[artico3-hw] open() /sys/bus/platform/devices/f8007000.devcfg/is_partial_bitstream failed\n");
            ret = -ENODEV;
            goto err_xdevcfg;
        }

        // Enable partial reconfiguration
        write(fd, "1", strlen("1"));
        a3_print_debug("[artico3-hw] DPR enabled\n");

        // Close configuration file
        close(fd);

    }

    // Open device file
    fd = open("/dev/xdevcfg", O_RDWR);
    if (fd < 0) {
        a3_print_error("[artico3-hw] open() /dev/xdevcfg failed\n");
        ret = -ENODEV;
        goto err_xdevcfg;
    }

    // Open bitstream file
    fp = fopen(name, "rb");
    if (!fp) {
        a3_print_error("[artico3-hw] fopen() %s failed\n", name);
        ret = -ENOENT;
        goto err_bit;
    }
    a3_print_debug("[artico3-hw] opened partial bitstream file %s\n", filename);

    // Read bitstream file and write to reconfiguration engine
    while (!feof(fp)) {

        // Read from file
        ret = fread(buffer, sizeof (uint32_t), 1024, fp);

        // Write to reconfiguration engine
        if (ret > 0) {
            write(fd, buffer, ret * sizeof (uint32_t));
        }

    }

    // Close bitstream file
    fclose(fp);

    // Close device file
    close(fd);

    // Unset flag when partial reconfiguration is required
    if (is_partial) {

        // Open configuration file
        fd = open("/sys/bus/platform/devices/f8007000.devcfg/is_partial_bitstream", O_RDWR);
        if (fd < 0) {
            a3_print_error("[artico3-hw] open() /sys/bus/platform/devices/f8007000.devcfg/is_partial_bitstream failed\n");
            ret = -ENODEV;
            goto err_xdevcfg;
        }

        // Disable partial reconfiguration
        write(fd, "0", strlen("0"));
        a3_print_debug("[artico3-hw] DPR disabled\n");

        // Close configuration file
        close(fd);

    }

    return 0;

err_bit:
    close(fd);

err_xdevcfg:
    return ret;
}

#elif AU250

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
ssize_t read_to_buffer(char *fname, int fd, char *buffer, uint64_t size,
            uint64_t base)
{
    ssize_t rc;
    uint64_t count = 0;
    char *buf = buffer;
    off_t offset = base;
    int loop = 0;

    while (count < size) {
        ssize_t bytes = size - count;

        if (bytes > RW_MAX_SIZE)
            bytes = RW_MAX_SIZE;

        if (offset) {
            rc = lseek(fd, offset, SEEK_SET);
            if (rc != offset) {
                fprintf(stderr, "%s, seek off 0x%lx != 0x%lx.\n",
                    fname, rc, offset);
                perror("seek file");
                return -EIO;
            }
        }

        /* read data from file into memory buffer */
        rc = read(fd, buf, bytes);
        if (rc < 0) {
            fprintf(stderr, "%s, read 0x%lx @ 0x%lx failed %ld.\n",
                fname, bytes, offset, rc);
            perror("read file");
            return -EIO;
        }

        count += rc;
        if (rc != bytes) {
            fprintf(stderr, "%s, read underflow 0x%lx/0x%lx @ 0x%lx.\n",
                fname, rc, bytes, offset);
            break;
        }

        buf += bytes;
        offset += bytes;
        loop++;
    }

    if (count != size && loop)
        fprintf(stderr, "%s, read underflow 0x%lx/0x%lx.\n",
            fname, count, size);
    return count;
}

/**
 * Writes data from a buffer to a file descriptor.
 *
 * @param fname The name of the file to write to.
 * @param fd The file descriptor to write to.
 * @param buffer The buffer containing the data to write.
 * @param size The size of the data to write.
 * @param base The base offset of the data in the buffer.
 * @return The number of bytes written, or -1 on error.
 */
ssize_t write_from_buffer(char *fname, int fd, char *buffer, uint64_t size,
            uint64_t base)
{
    ssize_t rc;
    uint64_t count = 0;
    char *buf = buffer;
    off_t offset = base;
    int loop = 0;

    while (count < size) {
        ssize_t bytes = size - count;

        if (bytes > RW_MAX_SIZE)
            bytes = RW_MAX_SIZE;

        if (offset) {
            rc = lseek(fd, offset, SEEK_SET);
            if (rc != offset) {
                fprintf(stderr, "%s, seek off 0x%lx != 0x%lx.\n",
                    fname, rc, offset);
                perror("seek file");
                return -EIO;
            }
        }

        /* write data to file from memory buffer */
        rc = write(fd, buf, bytes);
        if (rc < 0) {
            fprintf(stderr, "%s, write 0x%lx @ 0x%lx failed %ld.\n",
                fname, bytes, offset, rc);
            perror("write file");
            return -EIO;
        }

        count += rc;
        if (rc != bytes) {
            fprintf(stderr, "%s, write underflow 0x%lx/0x%lx @ 0x%lx.\n",
                fname, rc, bytes, offset);
            break;
        }
        buf += bytes;
        offset += bytes;

        loop++;
    }	

    if (count != size && loop)
        fprintf(stderr, "%s, write underflow 0x%lx/0x%lx.\n",
            fname, count, size);

    return count;
}
/*
 * Main reconfiguration function (default -> hbicap)
 *
 * This function loads a bitstream file (either total or partial) using
 * the hbicap reconfiguration interface.
 *
 * @name       : name of the bitstream file to be loaded
 * @is_partial : flag to indicate whether the bitstream file is partial
 *
 * Return : 0 on success, error code otherwise
 *
 */
int fpga_load(const char *name, uint8_t is_partial) {


    int fpga_fd;
    char *device = NULL;
    uint64_t rcfg_addr = 0x40000000; // HBICAP base address for partial reconfiguration

    // Read the bitstream file
    FILE *file = fopen(name, "rb"); // Modo binario
    a3_print_debug("Loading bitstream file: %s\n", name);
    if (file == NULL) {
        perror("Error al abrir el archivo");
        return 1;
    }

    // Obtener tamaño del archivo
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    rewind(file); // Regresar al inicio

    // Reservar buffer para el archivo
    unsigned char *buffer = (unsigned char *)malloc(file_size);
    if (buffer == NULL) {
        a3_print_error("Error to allocate memory for the buffer\n");
        fclose(file);
        return 1;
    }

    // Leer archivo en el buffer
    size_t bytes_read = fread(buffer, 1, file_size, file);
    a3_print_debug("Bytes leidos: %zu\n", bytes_read);
    if (bytes_read != file_size) {
        a3_print_error("No se pudo leer el archivo completo");
        free(buffer);
        fclose(file);
        return 1;
    }

    // Configure HBICAP for partial reconfiguration
    
    volatile uint32_t *HBICAP_SIZE = (artico3_rcfg + 0x42);
    volatile uint32_t *HBICAP_CTRL = (artico3_rcfg + 0x43);
    volatile uint32_t *HBICAP_STATUS = (artico3_rcfg + 0x44);
    unsigned int NWords=bytes_read/4;

    *HBICAP_CTRL = 12;
    *HBICAP_SIZE = NWords;

    //DMA transfer parameters
    device = "/dev/xdma0_h2c_2";

    fpga_fd = open(device, O_RDWR);
    if (fpga_fd < 0) {
            a3_print_error(stderr, "unable to open device %s, %d.\n",
                    device, fpga_fd);
            return -1;
    }

    

    // Write the buffer to HBICAP
    a3_print_debug("dev %s, addr 0x%lx,size 0x%lx, offset 0x%lx\n",device, buffer , bytes_read, rcfg_addr);
    write_from_buffer(device, fpga_fd, buffer, bytes_read, rcfg_addr);

    // Wait for HBICAP to finish reconfiguration
    while((*HBICAP_STATUS & 0x1) == 0);
    a3_print_info("HBICAP reconfiguration completed successfully.\n");

    // Free the buffer and close the file
    free(buffer);
    fclose(file);
    close(fpga_fd);

    return 0;
}
#else

/*
 * Main reconfiguration function (default -> fpga_manager)
 *
 * This function loads a bitstream file (either total or partial) using
 * the fpga_manager reconfiguration interface. This also assumes that
 * there is only one fpga, called fpga0.
 *
 * @name       : name of the bitstream file to be loaded
 * @is_partial : flag to indicate whether the bitstream file is partial
 *
 * Return : 0 on success, error code otherwise
 *
 */
int fpga_load(const char *name, uint8_t is_partial) {
    int fd;
    int ret;
    char cwd[128];
    char filename[256];
    char state[256];

    // Remove symlink of the bitstream file in /lib/firmware
    unlink("/lib/firmware/a3_bitstream");

    // Create symlink of the bitstream file in /lib/firmware
    getcwd(cwd, sizeof(cwd));
    sprintf(filename, "%s/%s", cwd, name);
    ret = symlink(filename, "/lib/firmware/a3_bitstream");
    if (ret) {
        goto err_fpga;
    }

    // Set flag when partial reconfiguration is required
    if (is_partial) {

        // Open configuration file
        fd = open("/sys/class/fpga_manager/fpga0/flags", O_RDWR);
        if (fd < 0) {
            a3_print_error("[artico3-hw] open() /sys/class/fpga_manager/fpga0/flags failed\n");
            ret = -ENODEV;
            goto err_fpga;
        }

        // Enable partial reconfiguration
        write(fd, "1", strlen("1"));
        a3_print_debug("[artico3-hw] DPR enabled\n");

        // Close configuration file
        close(fd);

    }

    // Open firmware path file
    fd = open("/sys/class/fpga_manager/fpga0/firmware", O_WRONLY);
    if (fd < 0) {
        a3_print_error("[artico3-hw] open() /sys/class/fpga_manager/fpga0/firmware failed\n");
        ret = -ENODEV;
        goto err_fpga;
    }

    // Write firmware file path
    write(fd, "a3_bitstream", strlen("a3_bitstream"));
    a3_print_debug("[artico3-hw] Firmware written\n");

    // Close firmware path file
    close(fd);

    // Unset flag when partial reconfiguration is required
    if (is_partial) {

        // Open configuration file
        fd = open("/sys/class/fpga_manager/fpga0/flags", O_RDWR);
        if (fd < 0) {
            a3_print_error("[artico3-hw] open() /sys/class/fpga_manager/fpga0/flags failed\n");
            ret = -ENODEV;
            goto err_fpga;
        }

        // Enable partial reconfiguration
        write(fd, "0", strlen("0"));
        a3_print_debug("[artico3-hw] DPR disabled\n");

        // Close configuration file
        close(fd);

    }

    // Open FPGA Manager state
    fd = open("/sys/class/fpga_manager/fpga0/state", O_RDONLY);
    if (fd < 0) {
        a3_print_error("[artico3-hw] open() /sys/class/fpga_manager/fpga0/state failed\n");
        ret = -ENODEV;
        goto err_fpga;
    }

    // Read FPGA Manager state
    ret = read(fd, state, sizeof state);
    char *token = strtok(state, "\n");
    a3_print_debug("[artico3-hw] FPGA Manager state : %s\n", token);
    if (strcmp(token, "operating") != 0) {
        a3_print_error("[artico3-hw] FPGA Manager state error (%s)\n", token);
        ret = -EBUSY;
        goto err_state;
    }

    // Close FPGA Manager state
    close(fd);

    // Remove symlink of the bitstream file in /lib/firmware
    unlink("/lib/firmware/a3_bitstream");

    return 0;

err_state:
    // Close FPGA Manager state
    close(fd);

err_fpga:
    // Remove symlink of the bitstream file in /lib/firmware
    unlink("/lib/firmware/a3_bitstream");

    return ret;
}

#endif /* A3_LEGACY_RCFG */
