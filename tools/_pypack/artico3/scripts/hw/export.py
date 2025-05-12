"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : August 2017
Description : Command - generates Vivado design.

------------------------------------------------------------------------

The following code is a derivative work of the code from the ReconOS
project, which is licensed GPLv2. This code therefore is also licensed
under the terms of the GNU Public License, version 2.

------------------------------------------------------------------------
"""

import sys
import re
import argparse
import tempfile
import subprocess
import logging

import artico3.utils.shutil2 as shutil2
import artico3.utils.template as template

log = logging.getLogger(__name__)

def get_cmd(prj):
    return "export_hw"

def get_call(prj):
    return export_hw_cmd

def get_parser(prj):
    parser = argparse.ArgumentParser("export_hw", description="""
        Exports the hardware project and generates all necessary files.
        """)
    parser.add_argument("-l", "--link", help="link sources instead of copying", action="store_true")
    parser.add_argument("-k", "--kernel", help="export only single kernel")
    parser.add_argument("hwdir", help="alternative export directory", nargs="?")
    return parser

def get_dict(prj):
    dictionary = {}
    dictionary["NUM_SLOTS"] = prj.shuffler.slots
    dictionary["PIPE_DEPTH"] = prj.shuffler.stages
    dictionary["CLK_BUFFER"] = "NO_BUFFER" if prj.shuffler.clkbuf == "none" else prj.shuffler.clkbuf.upper()
    dictionary["RST_BUFFER"] = "NO_BUFFER" if prj.shuffler.rstbuf == "none" else prj.shuffler.rstbuf.upper()
    dictionary["SLOTS"] = []
    for slot in prj.slots:
        if slot.kerns:
            d = {}
            d["SlotCoreName"] = slot.kerns[0].get_corename()
            d["SlotCoreVersion"] = slot.kerns[0].get_coreversion()
            d["id"] = slot.id
            dictionary["SLOTS"].append(d)
    dictionary["KERNELS"] = []
    for kernel in prj.kerns:
        d = {}
        d["KernCoreName"] = kernel.get_corename()
        d["KernCoreVersion"] = kernel.get_coreversion()
        dictionary["KERNELS"].append(d)
    return dictionary

def export_hw_cmd(args):
    if args.kernel is None:
        export_hw(args.prj, args.hwdir, args.link)
    else:
        export_hw_kernel(args.prj, args.hwdir, args.link, args.kernel)

def export_hw_kernel(prj, hwdir, link, thread):
    if prj.impl.xil[0] == "vivado":
        _export_hw_kernel(prj, hwdir, link, thread)
    else:
        log.error("Tool not supported")

def export_hw(prj, hwdir, link):
    if prj.impl.xil[0] == "vivado":
        _export_hw(prj, hwdir, link)
    else:
        log.error("Tool not supported")

def _export_hw_kernel(prj, hwdir, link, kernel):
    '''
    Generates sources for one ARTICo\u00b3 Kernel in Vivado.

    It checks whether vhdl or hls sources shall be used and generates
    the hardware accelerator from the source templates.

    hwdir gives the name of the project directory
    link boolean; if true files will be linked instead of copied
    kernel is the name of the hardware accelerator to generate
    '''

    hwdir = hwdir if hwdir is not None else prj.basedir + ".hw" + "." + kernel.lower()

    log.info("Exporting kernel " + kernel + " to directory '" + hwdir + "'")

    kerns = [_ for _ in prj.kerns if _.name == kernel]
    if (len(kerns) == 1):
        kernel = kerns[0]

        if kernel.hwsrc is None:
            log.info("No hardware source specified")
    else:
        log.error("Kernel '" + kernel  + "' not found")
        return

    if (kernel.hwsrc == "vhdl") or (kernel.hwsrc == "verilog"):
        dictionary = {}
        dictionary["NAME"] = kernel.name.lower()
        dictionary["HWSRC"] = kernel.hwsrc
        dictionary["RST_POL"] = kernel.rstpol
        dictionary["NUMREGS"] = kernel.regs
        dictionary["MEMBYTES"] = kernel.membytes
        dictionary["MEMBANKS"] = kernel.membanks
        dictionary["REGS"] = []
        for i in range(kernel.regs):
            d = {}
            d["rid"] = i
            dictionary["REGS"].append(d)
        dictionary["PORTS"] = []
        for i in range(kernel.membanks):
            d = {}
            d["pid"] = i
            dictionary["PORTS"].append(d)
        src = shutil2.join(prj.dir, "src", "a3_" + kernel.name.lower(), kernel.hwsrc)
        dictionary["SOURCES"] = [src]
        incl = shutil2.listfiles(src, True)
        dictionary["INCLUDES"] = [{"File": shutil2.trimext(_)} for _ in incl]

        log.info("Generating export files ...")
        prj.apply_template("artico3_kernel_hdl_pcore", dictionary, hwdir, link)

    elif kernel.hwsrc == "hls":
        tmp = tempfile.TemporaryDirectory()

        dictionary = {}
        dictionary["PART"] = prj.impl.part
        dictionary["NAME"] = kernel.name.lower()
        dictionary["HWSRC"] = kernel.hwsrc
        dictionary["MEMBYTES"] = kernel.membytes
        src = shutil2.join(prj.dir, "src", "a3_" + kernel.name.lower(), kernel.hwsrc)
        dictionary["SOURCES"] = [src]
        files = shutil2.listfiles(src, True)
        dictionary["FILES"] = [{"File": _} for _ in files]

        # Get info from user defined ports
        with open(shutil2.join(src, kernel.name.lower()) + ".cpp") as fp:
            data = fp.read()
        reg = r"A3_KERNEL\((?P<ports>[^\)]+)\)"
        match = re.search(reg, data)
        aux =  match.group("ports")
        aux = re.sub(r"[\n\r]", "", aux)   # Remove line breaks
        aux = re.sub(r"\s{2,}", " ", aux)  # Replace more than 2 spaces with 1
        aux = re.sub(r"a3\w+_t ", "", aux) # Remove port tags
        dictionary["ARGS"] = aux.strip()   # Remove heading and trailing spaces

        # Generate list with sorted input/output ports
        #
        # NOTE: in order to comply with bank orderings (especially
        #       relevant for DMA transfers), memory ports are sorted
        #       in alphabetical order and then arranged as C-I-IO-O.
        #
        argsC = []
        argsI = []
        argsO = []
        argsIO = []
        argsR = []
        for arg in match.group("ports").split(","):
            if "a3const_t" in arg.split():
                argsC.append(arg.split())
            if "a3in_t" in arg.split():
                argsI.append(arg.split())
            if "a3out_t" in arg.split():
                argsO.append(arg.split())
            if "a3inout_t" in arg.split():
                argsIO.append(arg.split())
            if "a3reg_t" in arg.split():
                argsR.append(arg.split())
        argsI.sort()
        argsO.sort()
        argsIO.sort()
        argsM = argsC + argsI + argsIO + argsO;
        argsR.sort()
        dictionary["REGS"] = []
        for i in range(len(argsR)):
            d = {}
            d["rname"] = argsR[i][1]
            d["rid"] = i
            dictionary["REGS"].append(d)
        dictionary["PORTS"] = []
        for i in range(len(argsM)):
            d = {}
            d["pname"] = argsM[i][1]
            d["pid"] = i
            dictionary["PORTS"].append(d)

        # Get info from register numbers and check consistency
        dictionary["NUMREGS"] = len(dictionary["REGS"])
        if dictionary["NUMREGS"] != kernel.regs:
            log.warning("Inconsistent use of Regs (.cfg) and A3_KERNEL (.cpp), will generate run-time errors")

        # Get info from the number of memory elements in each bank
        dictionary["MEMBANKS"] = len(dictionary["PORTS"])
        if dictionary["MEMBANKS"] != kernel.membanks:
            log.warning("Inconsistent use of MemBanks (.cfg) and A3_KERNEL (.cpp), will generate run-time errors")
        dictionary["MEMPOS"] = int((kernel.membytes / kernel.membanks) / 4)

        log.info("Generating temporary HLS project in " + tmp.name + " ...")
        prj.apply_template("artico3_kernel_hls_build", dictionary, tmp.name)

        #~ # Fix header file (parser generates excesive \n that need to be removed)
        #~ with open(shutil2.join(tmp.name, "artico3.h")) as fp:
            #~ data = fp.read()
        #~ def repl(match):
            #~ return ",\\\n" + match.group("data")
        #~ reg = r",\\[\n]+(?P<data>\s*uint32_t values\))"
        #~ data = re.sub(reg, repl, data, 0, re.DOTALL)
        #~ with open(shutil2.join(tmp.name, "artico3.h"), "w") as fp:
            #~ fp.write(data)

        #~ # DEBUG
        #~ with open(shutil2.join(tmp.name, "artico3.h")) as fp:
            #~ data = fp.read()
            #~ print(data)
            #~ sys.exit(1)
        #~ # END DEBUG

        log.info("Starting Vitis HLS ...")

        # NOTE: for some reason, using the subprocess module as in the
        #       original RDK does not work (does not recognize source and,
        #       therefore, Vivado is not started).
        subprocess.run("""
            bash -c "source /tools/Xilinx/Vivado/{1}/settings64.sh &&
            cd {0} &&
            vitis_hls -f csynth.tcl"
            """.format(tmp.name, prj.impl.xil[1]), shell=True, check=True)

        src = shutil2.join(tmp.name, "a3_kernel", "sol", "syn", "vhdl")
        dictionary["SOURCES"] = [src]
        incl = shutil2.listfiles(src, True)
        dictionary["INCLUDES"] = [{"File": shutil2.trimext(_)} for _ in incl]

        log.info("Generating export files ...")
        prj.apply_template("artico3_kernel_hdl_pcore", dictionary, hwdir)

        path = shutil2.join(hwdir, "a3_" + kernel.name.lower() + "_v1_00_a", "hls")
        shutil2.rmtree(path)
        shutil2.mkdir(path)
        shutil2.copytree(tmp.name, path)

def _export_hw(prj, hwdir, link):
    '''
    Generates a Vivado project using TCL scripts.

    It first compiles the configuration dictionary and then processes
    the templates according to the configuration dictionary.

    hwdir gives the name of the project directory
    link boolean; if true files will be linked instead of copied
    '''

    hwdir = hwdir if hwdir is not None else prj.basedir + ".hw"

    log.info("Export hardware to directory '" + hwdir + "'")
    dictionary = get_dict(prj)

    log.info("Generating export files...")
    tmpl = "ref_" + prj.impl.os + "_" + "_".join(prj.impl.board) + "_" + prj.impl.design + "_" + prj.impl.xil[0] + "_" + prj.impl.xil[1]
    if not shutil2.isdir(shutil2.join(prj.impl.repo, "templates", tmpl)):
        log.error("Template directory not found")
        sys.exit(1)
    print("[A3DK] Using template directory " + tmpl)
    prj.apply_template(tmpl, dictionary, hwdir, link)

    log.info("Generating ARTICo\u00b3 kernels...")
    for kernel in prj.kerns:
        export_hw_kernel(prj, shutil2.join(hwdir, "pcores"), link, kernel.name)

    print("[A3DK] Calling TCL script to generate Vivado IP Repository")
    try:

        # NOTE: for some reason, using the subprocess module as in the
        #       original RDK does not work (does not recognize source and,
        #       therefore, Vivado is not started).
        subprocess.run("""
            bash -c "source /tools/Xilinx/Vivado/{1}/settings64.sh &&
            cd {0} &&
            vivado -mode batch -notrace -nojournal -nolog -source create_ip_library.tcl"
            """.format(hwdir, prj.impl.xil[1]), shell=True, check=True)

    except:
        log.error("Generation of Vivado IP repository failed (check .cfg for unkown components)")
        sys.exit(1)

    print("[A3DK] Calling TCL script to generate ARTICo\u00b3 system in Vivado IP Integrator")
    try:

        # NOTE: for some reason, using the subprocess module as in the
        #       original RDK does not work (does not recognize source and,
        #       therefore, Vivado is not started).
        subprocess.run("""
            bash -c "source /tools/Xilinx/Vivado/{1}/settings64.sh &&
            cd {0} &&
            vivado -mode batch -notrace -nojournal -nolog -source export.tcl -tclargs -proj_name myARTICo3 -proj_path ."
            """.format(hwdir, prj.impl.xil[1]), shell=True, check=True)

    except:
        log.error("Could not generate design in Vivado IP Integrator")
        sys.exit(1)
