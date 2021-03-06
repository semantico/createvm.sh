#!/bin/bash
# Author: Bram Borggreve ( borggreve @ gmail dot com )
# Homepage: http://code.google.com/p/createvm/
# License: GPL V2 or (at your option) any later version, see: http://www.gnu.org/copyleft/gpl.txt

### Todo ###
# - Automatically register the VM with vmware server
# - Add ESX support

### Some default variables ###

# Program log_info
PROGRAM_NAME=$(basename $0)
PROGRAM_TITLE="Create VMware virtual machines from the command line"
PROGRAM_VER="0.6"
PROGRAM_COPYRIGHT="Copyright 2007-2008. \
Distributed under GPL V2 or (at your option) any later version. No warranty whatsoever, express or implied."
PROGRAM="$PROGRAM_NAME $PROGRAM_VER"
LOGFILE=createvm.log
BINARIES=(gzip tar vmware-vdiskmanager zip)
BINARY_TESTS=yes

# Default settings
DEFAULT_QUIET=no        # Don't ask for confirmations, only when critical
DEFAULT_YES=no          # Yes to al questions (warning: will overwrite existing files)
DEFAULT_ZIPIT=no        # Create .zip archive
DEFAULT_TARGZIT=no      # Create .tar.gz archive
DEFAULT_START_VM=no     # Start VM after creating it
DEFAULT_WRKPATH=.       # Location where output will be
DEFAULT_ESXI_SERVER=no  # Don't create remote vm
DEFAULT_DATASTORE="datastore1" # When using esxi use this datastore

# Default VM parameters
VM_CONF_VER=8           # VM Config version
VM_VMHW_VER=8           # VM Hardware version
VM_RAM=256              # Default RAM
VM_NVRAM=nvram          # Default bios file
VM_ETH_TYPE=static      # Default network type
VM_ETH_ADAPTER=e1000    # Default adapter to use
VM_MAC_ADDR=default     # Default MAC address
VM_DISK_SIZE=8          # Default DISK size (GB's)
VM_DISK_TYPE=SCSI       # Default DISK type
VM_USE_USB=FALSE        # Enable USB
VM_USE_SND=FALSE        # Enable sound
VM_USE_CDD=FALSE        # Enable CD drive
VM_USE_ISO=FALSE        # Enable and load ISO
VM_USE_FDD=FALSE        # Enable and load FDD
VM_VNC_PASS=FALSE       # VNC password
VM_VNC_PORT=FALSE       # VNC port
VM_NETWORK_NAME=FALSE   # Vlan network name to use
VM_NUM_CPUS=FALSE       # Number of cpus (default 1)

# This is the list of supported OS'es
SUPPORT_OS=(winVista longhorn winNetBusiness winNetEnterprise winNetStandard \
winNetWeb winXPPro winXPHome win2000AdvServ win2000Serv win2000Pro winNT winMe \
win98 win95 win31 windows winVista-64 longhorn-64 winNetEnterprise-64 \
winNetStandard-64 winXPPro-64 ubuntu redhat rhel4 rhel3 rhel2 suse sles \
mandrake nld9 sjds turbolinux other26xlinux other24xlinux linux ubuntu-64 \
rhel4-64 rhel3-64 sles-64 suse-64 other26xlinux-64 other24xlinux-64 other-64 \
otherlinux-64 solaris10-64 solaris10 solaris9 solaris8 solaris7 solaris6 \
solaris netware6 netware5 netware4 netware freeBSD-64 freeBSD darwin other)

# Some color codes
COL_EMR="\033[1;31m"    # Bold red
COL_EMG="\033[1;32m"    # Bold green
COL_EMW="\033[1;37m"    # Bold white
COL_RESET="\033[0;00m"  # Default colors

### Main functions ###

# Show version log_info
function version() {
    echo -e "${COL_EMW}$PROGRAM - $PROGRAM_TITLE${COL_RESET}"
    echo -e $PROGRAM_COPYRIGHT
}
# Print status message
function log_status() {
    echo -ne "    $1 "
}
# Print if cmd returned oke or failed
function check_status() {
    if [[ $? -ne 0 ]] ; then
        echo -e "${COL_EMR}[FAILED]${COL_RESET}"
        exit 1;
    else
        echo -e "${COL_EMG}[OK]${COL_RESET}"
    fi
}
# Print normal message
function log_message() {
    echo -e "    $1 "
}
# Print highlighted message
function log_info() {
    echo -e "${COL_EMW}    $1${COL_RESET} "
}

function _log_alert() {
    local _type=$1
    shift;
    echo -e "${COL_EMW}[$_type] ${COL_RESET}${COL_EMR}$1${COL_RESET} "
}

# Print log_alert log_message
function log_alert() {
    _log_alert '!' "$@"
}

# Print log_error log_message
function log_error() {
    _log_alert 'E' "$@"
}

function _ask_user() {
    local msg=""
    if [ "$1" = "y" ] ; then
        msg="${COL_EMG}[Yn]"
    elif [ "$1" = "n" ] ; then
        msg="${COL_EMR}[yN]"
    fi
    echo -ne "${COL_EMW}[?] Is it oke to continue?     $msg $COL_RESET"
    read YESNO
    [ -z $YESNO ] && YESNO=$1
    YESNO=$(echo $YESNO | tr A-Z a-z)
    if [ "$YESNO" = "n" ] || [ "$YESNO" = "no" ]  ; then log_alert "Stopped..."; exit 0; fi
    # If it's not yes
    [ "$YESNO" = "y" ] || [ "$YESNO" = "yes" ] && return
    _ask_user $1
}

# Ask if a user wants to continue, default to YES
function ask_oke(){
    [ ! "$DEFAULT_QUIET" = "yes" ] && _ask_user y
}

# Ask if a user wants to continue, default to NO
function ask_no_oke(){
    [ ! "$DEFAULT_YES" = "yes" ] && _ask_user n
}

### Specific funtions ###

# Print Help message
function usage() {
    echo -e "${COL_EMW}$PROGRAM - $PROGRAM_TITLE${COL_RESET}
Usage: $PROGRAM_NAME GuestOS OPTIONS

VM Options:
 -n, --name [NAME]              Friendly name of the VM       (default: <os-type>-vm)
 -r, --ram [SIZE]               RAM size in MB                (default: $VM_RAM)
 -d, --disk-size [SIZE]         HDD size in GB                (default: $VM_DISK_SIZE)
 -t, --disk-type [TYPE]         HDD Interface, SCSI or IDE    (default: $VM_DISK_TYPE)
 -e, --eth-type [TYPE]          Network Type (bridge/nat/etc) (default: $VM_ETH_TYPE)
 -m, --mac-addr [ADDR]          Use static mac address        (address: 00:50:56:xx:xx:xx)
 -ne,--network-name [NAME]      Network name (Vlan to use)    (default: none)
 -cp,--cpu [NUM]                CPUs to allocate              (default: 1)

 -c, --cdrom                    Enable CDROM Drive            (default: $VM_USE_CDD)
 -i, --iso [FILE]               Enable CDROM Iso              (default: $VM_USE_ISO)
 -f, --floppy                   Enable Floppy Drive           (default: $VM_USE_FDD)
 -a, --audio                    Enable sound card             (default: $VM_USE_SND)
 -u, --usb                      Enable USB                    (default: $VM_USE_USB)
 -b, --bios [PATH]              Path to custom bios file      (default: $VM_NVRAM)

 -vnc [PASSWD]:[PORT]           Enable vnc support for this VM

Program Options:
 -x [COMMAND]                   Start the VM with this command

 -w, --working-dir [PATH]       Path to use as Working Dir    (default: current working dir)
 -z, --zip                      Create .zip from this VM
 -g, --tar-gz                   Create .tar.gz from this VM

 -l, --list                     Generate a list of VMware Guest OS'es
 -q, --quiet                    Runs without asking questions, accept the default values
 -y, --yes                      Say YES to all questions. This overwrites existing files!!
 -B, --binary                   Disable the check on binaries
 -M, --monochrome               Don't use colors
 -es, --esxi-server [fqdn]        Esxi server to ssh to
 -da, --datastore               Datastore to use when esxi host is specified (default: $DEFAULT_DATASTORE)

 -h, --help                     This help screen
 -v, --version                  Shows version information
 -ex, --sample                  Show some examples

Dependencies:
This program needs the following binaries in its path: ${BINARIES[@]}"
}

# Show some examples
function print_examples(){
    echo -e "${COL_EMW}$PROGRAM - $PROGRAM_TITLE${COL_RESET}
Here are some examples:

 Create an Ubuntu Linux machine with a 20GB hard disk and a different name
   $ $PROGRAM_NAME ubuntu -d 20 -n \"My Ubuntu VM\"

 Silently create a SUSE Linux machine with 512MB ram, a fixed MAC address and zip it
   $ $PROGRAM_NAME suse -r 512 -q -m 00:50:56:01:25:00 -z

 Create a Windows XP machine with 512MB and audio, USB and CD enabled
   $ $PROGRAM_NAME winXPPro -r 512 -a -u -c

 Create an Ubuntu VM with 512MB and open and run it in vmware
   $ $PROGRAM_NAME ubuntu -r 512 -x \"vmware -x\""

}

function _summary_item() {
    local item=$1
    shift;
    printf "    %-26s" "$item"
    echo -e "${COL_EMW} $* ${COL_RESET}"
}

# Print a summary with some of the options on the screen
function show_summary(){
    log_info "I am about to create this Virtual Machine:"
    _summary_item "Guest OS" $VM_OS_TYPE
    _summary_item "Display name" $VM_NAME
    _summary_item "RAM (MB)" $VM_RAM
    _summary_item "HDD (Gb)" $VM_DISK_SIZE
    _summary_item "HDD interface" $VM_DISK_TYPE
    _summary_item "BIOS file" $VM_NVRAM
    _summary_item "Ethernet type" $VM_ETH_TYPE
    _summary_item "Mac address" $VM_MAC_ADDR
    _summary_item "Floppy disk" $VM_USE_FDD
    _summary_item "CD/DVD drive" $VM_USE_CDD
    _summary_item "CD/DVD image" $VM_USE_ISO
    _summary_item "USB device" $VM_USE_USB
    _summary_item "Sound Card" $VM_USE_SND
    _summary_item "VNC Port" $VM_VNC_PORT
    _summary_item "VNC Password" $VM_VNC_PASS

    ask_oke
}

function add_config_param() {
    if [ -n "$1" ] ; then
        local item=$1
        shift;
        [ -n "$1" ] && CONFIG_PARAM="$CONFIG_PARAM\n$item = \"$@\""
        return
    fi
    # if empty, then reset the config params
    CONFIG_PARAM=""
}

function print_config() {
    echo -e $CONFIG_PARAM > "$VM_VMX_FILE"
}

function detect_esxi_version(){
    if [ ! $DEFAULT_ESXI_SERVER = "no" ]; then
        esxi_version=$(ssh $DEFAULT_ESXI_SERVER -l root 'vim-cmd hostsvc/hostsummary' 2> /dev/null | grep fullName | awk '{print $5}'| cut -c1-3 )
        log_status "$esxi_version detected"
    else
        esxi_version='unused'
    fi
}


# Create the .vmx file
function create_conf(){
    log_status "Creating config file...   "

    if [ $esxi_version = '4.1' ] || [ $esxi_version = '4.0' ];then
        VM_VMHW_VER=7
    fi

    if [ $esxi_version = '5.1' ] ;then
        VM_VMHW_VER=9
    fi


    if [ ! $VM_NUM_CPUS = "FALSE" ]; then
        add_config_param numvcpus $VM_NUM_CPUS
        if [ $esxi_version != '4.0' ];then
            add_config_param cpuid.coresPerSocket $VM_NUM_CPUS
        fi
    fi

    add_config_param config.version $VM_CONF_VER
    add_config_param virtualHW.version $VM_VMHW_VER

    add_config_param displayName $VM_NAME
    add_config_param guestOS $VM_OS_TYPE
    add_config_param memsize $VM_RAM

    if [ ! $VM_NVRAM = "nvram" ]; then
        FILENAME=$(basename $VM_NVRAM)
        cp $VM_NVRAM "$WORKING_DIR/$FILENAME"
        add_config_param nvram $FILENAME
    else
        add_config_param nvram $VM_NVRAM
    fi

    add_config_param ethernet0.present TRUE

    add_config_param ethernet0.connectionType $VM_ETH_TYPE
    add_config_param ethernet0.virtualDev $VM_ETH_ADAPTER


    if [ ! $VM_MAC_ADDR = "default" ]; then
        add_config_param ethernet0.addressType static
        add_config_param ethernet0.address $VM_MAC_ADDR
    else
        add_config_param ethernet0.addressType generated
    fi

    if [ ! $VM_NETWORK_NAME = "FALSE" ]; then
        add_config_param ethernet0.networkName $VM_NETWORK_NAME
    fi

    if [ ! $VM_DISK_TYPE = "IDE" ]; then
        add_config_param scsi0.present TRUE
        add_config_param scsi0.sharedBus none
        add_config_param scsi0.virtualDev lsilogic
        add_config_param scsi0:0.deviceType scsi-hardDisk
        add_config_param scsi0:0.present TRUE
        add_config_param scsi0:0.fileName $VM_DISK_NAME
        add_config_param virtualHW.productCompatibility hosted
    else
        add_config_param ide0:0.present TRUE
        add_config_param ide0:0.fileName $VM_DISK_NAME
    fi

    if [ ! $VM_USE_USB = "FALSE" ]; then
        add_config_param usb.present TRUE
        add_config_param usb.generic.autoconnect FALSE
    fi

    if [ ! $VM_USE_SND = "FALSE" ]; then
        add_config_param sound.present TRUE
        add_config_param sound.fileName -1
        add_config_param sound.autodetect TRUE
        add_config_param sound.startConnected FALSE
    fi

    if [ ! $VM_USE_FDD = "FALSE" ]; then
        add_config_param floppy0.present TRUE
        add_config_param floppy0.startConnected FALSE
    else
        add_config_param floppy0.present FALSE
    fi

    if [ ! $VM_USE_CDD = "FALSE" ]; then
        add_config_param ide0:1.present TRUE
        add_config_param ide0:1.fileName auto detect
        add_config_param ide0:1.autodetect TRUE
        add_config_param ide0:1.deviceType cdrom-raw
        add_config_param ide0:1.startConnected FALSE
    fi

    if [ ! $VM_USE_ISO = "FALSE" ]; then
        add_config_param ide1:0.present TRUE
        add_config_param ide1:0.fileName $VM_USE_ISO
        add_config_param ide1:0.deviceType cdrom-image
        add_config_param ide1:0.startConnected TRUE
        add_config_param ide1:0.mode persistent
    fi

    if [ ! $VM_VNC_PASS = "FALSE" ]; then
        add_config_param remotedisplay.vnc.enabled TRUE
        add_config_param remotedisplay.vnc.port $VM_VNC_PORT
        add_config_param remotedisplay.vnc.password $VM_VNC_PASS

    fi



    add_config_param annotation "This VM is created by $PROGRAM"

    print_config
    check_status
}

# Create the working dir
function create_working_dir(){
    log_info "Creating Virtual Machine..."
    log_status "Creating working dir...   "
    mkdir -p "$WORKING_DIR" 1> /dev/null
    check_status
}
function transfer_conf(){
    if [[ "$DEFAULT_ESXI_SERVER" != "no" ]];then
        log_info "transfering conf to $DEFAULT_ESXI_SERVER ..."
        log_status "transfering conf to $DEFAULT_ESXI_SERVER ..."
        ssh root@$DEFAULT_ESXI_SERVER mkdir /vmfs/volumes/${DEFAULT_DATASTORE}/${VM_NAME}
        scp $VM_VMX_FILE root@$DEFAULT_ESXI_SERVER:/vmfs/volumes/${DEFAULT_DATASTORE}/${VM_NAME}/
        check_status
    fi
}

# Create the virtual disk
function create_virtual_disk(){
    log_status "Creating virtual disk...  "
    local adapter=buslogic
    [ "$VM_DISK_TYPE" = "IDE" ] && adapter=ide
    if [[ "$DEFAULT_ESXI_SERVER" != "no" ]];then
        adapter=lsilogic
        ssh root@$DEFAULT_ESXI_SERVER "vmkfstools /vmfs/volumes/${DEFAULT_DATASTORE}/$VM_NAME/$VM_DISK_NAME -U"
        ssh root@$DEFAULT_ESXI_SERVER "vmkfstools -c $VM_DISK_SIZE /vmfs/volumes/${DEFAULT_DATASTORE}/$VM_NAME/$VM_DISK_NAME"
    else
        vmware-vdiskmanager -c -a $adapter -t 1 -s $VM_DISK_SIZE "$WORKING_DIR/$VM_DISK_NAME" &> $LOGFILE
        check_status
    fi
}
# Generate a zip or tar.gz archive
function create_archive(){
    if [ "$DEFAULT_ZIPIT" = "yes" ]; then
        # Generate zipfile
        log_status "Generate zip file...      "
        cd "$DEFAULT_WRKPATH"
        zip -q -r "$VM_OUTP_FILE_ZIP" "$VM_NAME" 1> /dev/null
        check_status
    fi
    if [ "$DEFAULT_TARGZIT" = "yes" ]; then
        # Generate tar.gz file
        log_status "Generate tar.gz file...   "
        cd "$DEFAULT_WRKPATH"
        tar cvzf "$VM_OUTP_FILE_TAR" "$VM_NAME" 1> /dev/null
        check_status
    fi
}
# Print OS list.
function list_guest_os() {
    echo "List of Guest Operating Systems:"

    local max="${#SUPPORT_OS[@]}"
    for ((i=0;i < max; i=i+3)) ; do
        printf "%-25s %-25s %-25s\n" ${SUPPORT_OS[$i]} ${SUPPORT_OS[$((i + 1))]} ${SUPPORT_OS[$((i + 2))]}
    done
}
# Check if selected OS is in the OS list
function run_os_test(){
    local OS
    for OS in ${SUPPORT_OS[@]} ; do
        # Everything OK, no need to continue
        [ $OS = "$VM_OS_TYPE" ] && return
    done
    log_error "Guest OS \"$VM_OS_TYPE\" is unknown..."
    log_message "Run \"$PROGRAM_NAME -l\" for a list of Guest OS'es..."
    log_message "Run \"$PROGRAM_NAME -h\" for help..."
    log_message "Run \"$PROGRAM_NAME -ex\" for examples..."
    exit 1
}
# Check for binaries and existance of previously created VM's
function run_tests(){
    # Check for needed binaries
    if [ "$BINARY_TESTS" = "yes" ]; then
        log_info "Checking binaries..."
        local app
        for app in ${BINARIES[@]} ; do
            log_status ""
            printf " - %-22s " "$app..."
            which $app 1> /dev/null
            check_status
        done
    fi
    # Check if working dir file exists
    log_info "Checking files and directories..."
    if [ -e "$WORKING_DIR" ]; then
        log_alert "Working dir already exists, i will trash it!"
        ask_no_oke
        log_status "Trashing working dir...   "
        rm -rf "$WORKING_DIR" 1>/dev/null
        check_status
    fi
    # Check if zip file exists
    if [ "$DEFAULT_ZIPIT" = "yes" ]; then
        if [ -e "$VM_OUTP_FILE_ZIP" ]; then
            log_alert "zip file already exists, i will trash it!"
            ask_no_oke
            log_status "Trashing zip file...      "
            rm "$VM_OUTP_FILE_ZIP" 1>/dev/null
            check_status
        fi
    fi
    # Check if tar.gz file exists
    if [ "$DEFAULT_TARGZIT" = "yes" ]; then
        if [ -e "$VM_OUTP_FILE_TAR" ]; then
            log_alert "tar.gz file already exists, i will trash it!"
            ask_no_oke
            log_status "Trashing tar.gz file...   "
            rm "$VM_OUTP_FILE_TAR" 1>/dev/null
            check_status
        fi
    fi
}
# Clean up working dir
function clean_up(){
    # Back to base dir...
    cd - &> /dev/null
    # Clean up if zipped or tar-gzipped, and announce file location
    if [ "$DEFAULT_ZIPIT" = "yes" ]; then
        CLEANUP='yes'
        VMLOCATION="$VM_OUTP_FILE_ZIP $VMLOCATION"
    fi
    if [ "$DEFAULT_TARGZIT" = "yes" ]; then
        CLEANUP='yes'
        VMLOCATION="$VM_OUTP_FILE_TAR $VMLOCATION"
    fi
    if [ "$CLEANUP" = "yes" ]; then
        log_status "Cleaning up workingdir... "
        rm -rf "$WORKING_DIR"
        check_status
    else
        VMLOCATION="$VM_VMX_FILE"
    fi
    log_info "Grab you VM here: $VMLOCATION"
}
# Start VM if asked for
function start_vm(){
    if [ "$DEFAULT_START_VM" = "yes" ]; then
        if [[ "$DEFAULT_ESXI_SERVER" != "no" ]];then
            vimid=`ssh root@$DEFAULT_ESXI_SERVER "vim-cmd vmsvc/getallvms 2>&1 |grep ${VM_NAME} | awk '{print $1}'"`
            if [[ $vimid >1 ]];then
                ssh root@$DEFAULT_ESXI_SERVER "vim-cmd vmsvc/reload $vimid"
                log_info "Reloaded $vimid"
            else
                log_info "Registered $vimid"
                ssh root@$DEFAULT_ESXI_SERVER "vim-cmd solo/registervm /vmfs/volumes/${DEFAULT_DATASTORE}/${VM_VMX_FILE}"
            fi
            vimid=`ssh root@$DEFAULT_ESXI_SERVER "vim-cmd vmsvc/getallvms 2>&1 |grep ${VM_NAME} | awk '{print $1}'"`
            log_info "Powering on $vimid"
            ssh root@$DEFAULT_ESXI_SERVER "vim-cmd vmsvc/power.on $vimid"
        else
        log_info "Starting Virtual Machine..."
            $VMW_BIN $VM_VMX_FILE
        fi
    fi
}

### The flow! ###

# Chatch some parameters if the first one is not the OS.
if [ "$1" = "" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then usage; exit; fi
if [ "$1" = "-v" ] || [ "$1" = "--version" ];     then version; exit; fi
if [ "$1" = "-l" ] || [ "$1" = "--list" ];     then list_guest_os; exit 1; fi
if [ "$1" = "-ex" ] || [ "$1" = "--sample" ];     then print_examples; exit 1; fi

# The first parameter is the Guest OS Type
VM_OS_TYPE="$1"

# Set default VM Name
VM_NAME="$VM_OS_TYPE-vm"

# Run OS test
run_os_test

# Shift through all parameters to search for options
shift
while [ "$1" != "" ]; do
    case $1 in
    -a | --audio )
        VM_USE_SND="TRUE"
    ;;
    -b | --bios )
        shift
        VM_NVRAM=$1
    ;;
    -B | --binary )
        BINARY_TESTS=no
    ;;
    -c | --cdrom )
        VM_USE_CDD="TRUE"
    ;;
    -cp | --cpu )
        shift
        VM_NUM_CPUS=$1
    ;;
    -d | --disk-size )
        shift
        VM_DISK_SIZE=$1
    ;;
    -da | --datastore )
        shift
        DEFAULT_DATASTORE=$1
    ;;
    -e | --eth-type )
        shift
        VM_ETH_TYPE=$1
    ;;
    -f | --floppy )
        VM_USE_FDD="TRUE"
    ;;
    -g | --tar-gz )
        DEFAULT_TARGZIT="yes"
    ;;
    -i | --iso )
        shift
        VM_USE_ISO=$1
    ;;
    -m | --mac-addr )
        shift
        VM_MAC_ADDR=$1
    ;;
    -M | --monochrome )
        COL_EMR=""
        COL_EMG=""
        COL_EMW=""
        COL_RESET=""
    ;;
    -n | --name )
        shift
        VM_NAME="$1"
    ;;
    -nn | --network-name )
        shift
        VM_NETWORK_NAME="$1"
    ;;
    -r | --ram )
        shift
        VM_RAM=$1
    ;;
    -t | --disk-type )
        shift
        VM_DISK_TYPE=$1
    ;;
    -u | --usb )
        VM_USE_USB="TRUE"
    ;;
    -q | --quiet )
        DEFAULT_QUIET="yes"
    ;;
    -v | --version )
        version
    ;;
    -vnc )
        shift
        VNC_PARAMS=$1
        VM_VNC_PASS=$(echo $VNC_PARAMS | cut -d ":" -f 1)
        VM_VNC_PORT=$(echo $VNC_PARAMS | cut -d ":" -f 2)
    ;;
    -w | --working-dir )
        shift
        DEFAULT_WRKPATH=$1
    ;;
    -es | --esxi-server )
        shift
        DEFAULT_ESXI_SERVER=$1
        BINARY_TESTS=no
    ;;
    -x  )
        shift
        DEFAULT_START_VM="yes"
        VMW_BIN="$1"
    ;;
    -y | --yes )
        DEFAULT_QUIET="yes"
        DEFAULT_YES="yes"
    ;;
    -z | --zip )
        DEFAULT_ZIPIT="yes"
    ;;
    * )
        log_error "Euhm... what do you mean by \"$*\"?"
        log_message "Run \"$PROGRAM_NAME -h\" for help"
        log_message "Run \"$PROGRAM_NAME -ex\" for examples..."
        exit 1
    esac
    shift
done

# Set the names of the output files
VM_OUTP_FILE_ZIP="$VM_NAME.zip"
VM_OUTP_FILE_TAR="$VM_NAME.tar.gz"

# The last parameters are set
WORKING_DIR="$DEFAULT_WRKPATH/$VM_NAME"
VM_VMX_FILE="$WORKING_DIR/$VM_OS_TYPE.vmx"
VM_DISK_NAME="$VM_DISK_TYPE-$VM_OS_TYPE.vmdk"
VM_DISK_SIZE="$VM_DISK_SIZE""G"

# Print banner
version
# Display summary
show_summary
# Do some tests
run_tests

# Create working environment
create_working_dir
# Detect what esxi version is running
detect_esxi_version
# Write config file
create_conf
# Transfer the config to remote server esxi server
transfer_conf

# Create virtual disk
create_virtual_disk
# Create archine
create_archive

# Clean up environment
clean_up
# Run the VM
start_vm

### The End! ###
