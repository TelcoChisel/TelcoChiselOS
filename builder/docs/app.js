// TelcoChisel Documentation Application Logic

// Complete catalog of pre-installed tools on TelcoChisel
// status: "ready"  — available straight from boot
// status: "setup"  — requires a one-time first-run install command
// categories: sdr | 2g | 4g | 5g | baseband | core | sim | mw | voip | adsl
const toolsCatalog = [
    {
            "name": "GNU Radio 3.10",
            "category": "sdr",
            "status": "ready",
            "desc": "The primary digital signal processing (DSP) framework and graphical flowchart design suite for SDR transceiver implementation.",
            "path": "Conda env (telcosec-sdr)",
            "cmd": "conda activate telcosec-sdr && gnuradio-companion"
    },
    {
            "name": "SoapySDR",
            "category": "sdr",
            "status": "ready",
            "desc": "A vendor-neutral SDR hardware abstraction layer and API, allowing software built against it to work with a wide range of transceivers.",
            "path": "Conda env (telcosec-sdr)",
            "cmd": "SoapySDRUtil --info"
    },
    {
            "name": "UHD (USRP Hardware Driver)",
            "category": "sdr",
            "status": "ready",
            "desc": "Official device driver and interface software for Ettus Research USRP software-defined radios (B210, X310, etc.), compiled from source.",
            "path": "Conda env (telcosec-sdr)",
            "cmd": "uhd_usrp_probe --args=\"type=b200\""
    },
    {
            "name": "HackRF Host Tools",
            "category": "sdr",
            "status": "ready",
            "desc": "Command-line configuration and operation tools for the Great Scott Gadgets HackRF One, including firmware flashers and receiver utilities.",
            "path": "Conda env (telcosec-sdr)",
            "cmd": "hackrf_info"
    },
    {
            "name": "gr-gsm Tools",
            "category": "sdr",
            "status": "setup",
            "desc": "Gnu Radio blocks and scripts for receiving, decoding, and analyzing the GSM air interface (2G). Includes live channel monitoring.",
            "path": "Conda env (telcosec-sdr)",
            "cmd": "grgsm_livemon"
    },
    {
            "name": "Kalibrate RTL (kal)",
            "category": "sdr",
            "status": "ready",
            "desc": "Scans for GSM base stations and uses their broadcasts to calibrate the local oscillator frequency offset on RTL-SDR dongles.",
            "path": "Conda env (telcosec-sdr)",
            "cmd": "kal -s GSM900"
    },
    {
            "name": "FirmWire Emulation",
            "category": "baseband",
            "status": "ready",
            "desc": "A baseband firmware emulation and fuzzing platform. Emulates Samsung Shannon and MediaTek modems under QEMU, enabling analysis of baseband OTA packets.",
            "path": "/opt/telcosec/firmwire/",
            "cmd": "firmwire --help"
    },
    {
            "name": "QCSuper",
            "category": "baseband",
            "status": "ready",
            "desc": "Qualcomm diagnostic protocol log parser that generates PCAP files from baseband OTA messages sniffed from a phone connected via USB.",
            "path": "System-wide (pip: qcsuper)",
            "cmd": "qcsuper --help"
    },
    {
            "name": "MTKClient",
            "category": "baseband",
            "status": "ready",
            "desc": "A powerful dump, flash, partition editor, and bootloader/BROM bypass tool for MediaTek (MTK) chipset devices.",
            "path": "System-wide python",
            "cmd": "mtk --help"
    },
    {
            "name": "Balong-Flash & Balongtool",
            "category": "baseband",
            "status": "ready",
            "desc": "Firmware compilation, modification, and direct USB flasher utilities targeting Huawei Balong-based LTE modems and routers.",
            "path": "/usr/local/bin/",
            "cmd": "balong-flash --help"
    },
    {
            "name": "Osmocom SIMtrace 2 Host",
            "category": "sim",
            "status": "ready",
            "desc": "Host-side companion daemon and sniffer utilities to inspect smartcard ISO-7816 communication between SIM readers and actual handsets.",
            "path": "System-wide binaries",
            "cmd": "simtrace2-list"
    },
    {
            "name": "Osmocom pySim",
            "category": "sim",
            "status": "ready",
            "desc": "An interactive smartcard management shell and scripting library capable of reading, writing, and configuring USIM/SIM credentials.",
            "path": "System-wide binaries",
            "cmd": "pySim-shell --help"
    },
    {
            "name": "lpac (eSIM LPA)",
            "category": "sim",
            "status": "ready",
            "desc": "An independent Local Profile Assistant (LPA) for eSIM profiles, implementing GSMA SGP.22 specifications over PC/SC readers.",
            "path": "/usr/local/bin/lpac",
            "cmd": "lpac profile list"
    },
    {
            "name": "SIMurai (swsim)",
            "category": "sim",
            "status": "ready",
            "desc": "A software SIM platform that emulates a full UICC/SIM card speaking ISO-7816 over TCP/IP, plus a virtual PC/SC IFD driver (swicc-pcsc) that exposes the emulated card to any pcscd-aware tool.",
            "path": "/usr/local/bin/simurai",
            "cmd": "simurai --help"
    },
    {
            "name": "PCSC Daemon (pcscd)",
            "category": "sim",
            "status": "ready",
            "desc": "Smartcard interface daemon facilitating reader communication between hardware card slot readers and software tools.",
            "path": "System service",
            "cmd": "systemctl status pcscd"
    },
    {
            "name": "srsRAN 4G/5G Simulator",
            "category": "core",
            "status": "setup",
            "desc": "Full open-source SDR-based 4G/5G mobile network simulator implementing gNodeB, eNodeB, and User Equipment (UE). Suitable for virtual cell testing.",
            "path": "System-wide",
            "cmd": "srsenb --help"
    },
    {
            "name": "Wireshark & TShark",
            "category": "core",
            "status": "ready",
            "desc": "World-class packet sniffer customized with layout profiles displaying GSMTAP, 5G NAS, Diameter codes, and GTP headers.",
            "path": "System desktop application",
            "cmd": "wireshark"
    },
    {
            "name": "SIPVicious",
            "category": "core",
            "status": "ready",
            "desc": "Audit toolset for SIP-based VoIP systems. Designed to scan target networks, brute-force extensions, and audit registration systems.",
            "path": "System-wide python",
            "cmd": "svmap --help"
    },
    {
            "name": "sctpscan",
            "category": "core",
            "status": "ready",
            "desc": "A fast SCTP port scanner to map host capabilities and discover ports running S1AP, NGAP, Diameter, or M3UA SIGTRAN protocols.",
            "path": "/usr/local/bin/sctpscan",
            "cmd": "sctpscan --help"
    },
    {
            "name": "SigPloit",
            "category": "core",
            "status": "ready",
            "desc": "Signaling exploitation framework targeting SS7, Diameter, and GTP protocols to audit core telecom networks for routing vulnerabilities.",
            "path": "/opt/telcosec/sigploit/",
            "cmd": "sudo sigploit"
    },
    {
            "name": "Diafuzzer",
            "category": "core",
            "status": "ready",
            "desc": "Diameter protocol fuzzer written by Orange Security, designed to test core interfaces (S6a, Gx, Gy) for vulnerability to malformed requests.",
            "path": "/opt/telcosec/diafuzzer/",
            "cmd": "diafuzzer --help"
    },
    {
            "name": "Scapy (with SS7/Diameter modules)",
            "category": "core",
            "status": "ready",
            "desc": "Interactive packet manipulation program extended to support construction of custom MAP, TCAP, M3UA, and Diameter network frames.",
            "path": "System-wide python",
            "cmd": "scapy"
    },
    {
            "name": "5Ghoul Fuzzer Wrapper",
            "category": "core",
            "status": "setup",
            "desc": "Custom launcher wrapper that simplifies executing the 5Ghoul fuzzer, automatically patching configurations for BladeRF and USRP transceivers.",
            "path": "/usr/local/bin/5ghoul-run",
            "cmd": "sudo 5ghoul-run --Attack.Name=NAS_5GS_Fuzz"
    },
    {
            "name": "Open5GS Core Network",
            "category": "core",
            "status": "setup",
            "desc": "A complete open-source implementation of 4G EPC and 5G Core Network functions (AMF, SMF, UPF, UDM, HSS) built with high performance in C.",
            "path": "/usr/local/bin/open5gs-install",
            "cmd": "cd /opt/telcosec/open5gs/docker_open5gs && sudo docker compose up -d"
    },
    {
            "name": "Docker & Docker Compose",
            "category": "core",
            "status": "ready",
            "desc": "Containerization engine pre-configured for non-root management. Used to spin up large-scale core network elements quickly.",
            "path": "System services",
            "cmd": "docker ps"
    },
    {
            "name": "Telecom Wordlists",
            "category": "core",
            "status": "ready",
            "desc": "Bundled telecom-specific wordlist collection covering carrier APNs, VoIP/SIP credentials, RAN element passwords, SIM OTA test keys, hardware defaults, PLMNs/IMSI prefixes, and protocol-level lists for 5G NAS, GTP, SS7, Diameter, SMS, and USSD. Includes telcosec-apn-permutator and telcosec-imsi-generator helper scripts on PATH.",
            "path": "/usr/share/wordlists/telecom/",
            "cmd": "ls -lR /usr/share/wordlists/telecom/"
    },
    {
            "name": "YateBTS",
            "category": "2g",
            "status": "setup",
            "desc": "Open-source GSM/UMTS BTS implementation built on the Yate telephony engine. Optimized for BladeRF A4 with a dedicated hardware config.",
            "path": "/opt/telcosec/yatebts/ (helper: yatebts-install)",
            "cmd": "sudo yatebts-install"
    },
    {
            "name": "OpenBTS",
            "category": "2g",
            "status": "setup",
            "desc": "Pioneering open-source GSM base transceiver station. Implements the Um air interface enabling rogue GSM cell and protocol audit scenarios.",
            "path": "/opt/telcosec/openbts/ (helper: openbts-install)",
            "cmd": "sudo openbts-install"
    },
    {
            "name": "Osmocom GSM Stack",
            "category": "2g",
            "status": "ready",
            "desc": "Complete Osmocom GSM network stack: OsmoBSC, OsmoMSC, OsmoHLR, OsmoBTS-TRX. Supports osmo-trx-bladerf for BladeRF A4 hardware.",
            "path": "System packages",
            "cmd": "osmo-bsc --help"
    },
    {
            "name": "Kalibrate GSM",
            "category": "2g",
            "status": "ready",
            "desc": "GSM-band frequency offset calibration tool using broadcast channel timing from live base stations. Complements kalibrate-rtl for calibrating BladeRF.",
            "path": "/usr/local/bin/kal-gsm",
            "cmd": "kal-gsm -s GSM900 -g 40"
    },
    {
            "name": "srsUE",
            "category": "4g",
            "status": "ready",
            "desc": "Software-defined LTE UE (User Equipment) that connects to real or simulated eNodeBs. Used for protocol testing, attach procedures, and downlink captures.",
            "path": "System-wide",
            "cmd": "srsue /etc/srsran/ue.conf"
    },
    {
            "name": "LTE-CellScanner",
            "category": "4g",
            "status": "setup",
            "desc": "Open-source LTE cell searcher and MIB/SIB decoder. Scans a frequency range and decodes cell IDs, bandwidth, and system information blocks.",
            "path": "/opt/telcosec/lte-cellscanner/",
            "cmd": "LTE-CellSearch -s 2650e6"
    },
    {
            "name": "LTESniffer",
            "category": "4g",
            "status": "setup",
            "desc": "Open-source LTE downlink and uplink sniffer. Decodes physical layer frames and logs RRC, NAS, and user-plane traffic to PCAP.",
            "path": "/opt/telcosec/ltesniffer/",
            "cmd": "ltesniffer -A 2 -f 2630e6 -C -m 0"
    },
    {
            "name": "SCAT",
            "category": "4g",
            "status": "ready",
            "desc": "DIAG protocol parser for Qualcomm and Samsung modems. Decodes OTA messages from USB-connected phones to PCAP with full NAS/RRC content.",
            "path": "System-wide (pip: scat)",
            "cmd": "scat -t qc -d /dev/ttyUSB0 -o capture.pcap"
    },
    {
            "name": "Modmobmap",
            "category": "4g",
            "status": "ready",
            "desc": "Maps 2G/3G/4G cells visible to a USB modem by issuing AT commands. Generates cell-tower geolocation data and signal reports.",
            "path": "/opt/telcosec/modmobmap/",
            "cmd": "modmobmap -m /dev/ttyUSB1"
    },
    {
            "name": "UERANSIM",
            "category": "5g",
            "status": "ready",
            "desc": "The most complete open-source 5G SA UE and gNB simulator. Emulates full N1/N2/N3 interfaces, compatible with Open5GS. Pre-configured for test PLMN 001/01.",
            "path": "/opt/telcosec/ueransim/",
            "cmd": "nr-gnb -c /etc/telcosec/ueransim/gnb.yaml"
    },
    {
            "name": "GTP5G Kernel Module",
            "category": "5g",
            "status": "setup",
            "desc": "Linux kernel module implementing the GTP-U encapsulation layer required by UERANSIM and free5GC for 5G user-plane forwarding.",
            "path": "/opt/telcosec/gtp5g/ (helper: gtp5g-load)",
            "cmd": "sudo gtp5g-load"
    },
    {
            "name": "OAI UE (OpenAirInterface)",
            "category": "5g",
            "status": "setup",
            "desc": "OpenAirInterface 5G NR UE implementation from EURECOM. Full PHY/MAC/RLC stack for 5G SA and NSA testing with real radio hardware.",
            "path": "Helper: oai-install (deferred build)",
            "cmd": "sudo oai-install"
    },
    {
            "name": "Heimdall (Samsung)",
            "category": "baseband",
            "status": "ready",
            "desc": "Open-source, cross-platform Samsung Odin replacement for flashing firmware on Samsung devices in Download Mode.",
            "path": "System-wide",
            "cmd": "heimdall detect"
    },
    {
            "name": "ADB & Fastboot",
            "category": "baseband",
            "status": "ready",
            "desc": "Android Debug Bridge and Fastboot tools for communicating with Android devices in normal, recovery, and bootloader modes.",
            "path": "System-wide",
            "cmd": "adb devices -l"
    },
    {
            "name": "EDL (Qualcomm Emergency Download)",
            "category": "baseband",
            "status": "ready",
            "desc": "Comprehensive Qualcomm EDL/9008 mode toolkit for reading, writing, and erasing partitions on Snapdragon devices via Sahara/Firehose protocols.",
            "path": "System-wide (pip: edl)",
            "cmd": "edl --help"
    },
    {
            "name": "SIMTester",
            "category": "baseband",
            "status": "ready",
            "desc": "Java-based SIM card security audit tool from SRLabs. Tests for roaming, OTA update vulnerabilities, and SIM application exploits.",
            "path": "/opt/telcosec/simtester/ (/usr/local/bin/simtester)",
            "cmd": "simtester"
    },
    {
            "name": "RDNSx",
            "category": "adsl",
            "status": "ready",
            "desc": "Rapid DNS Reverse Resolver for telecom network reconnaissance, PTR bulk lookups, ASN intelligence, and carrier domain enumeration.",
            "path": "/usr/local/bin/rdnsx",
            "cmd": "rdnsx --help"
    },
    {
            "name": "AT Command Console",
            "category": "baseband",
            "status": "ready",
            "desc": "Interactive AT command terminal (minicom) pre-configured for modem control. Supports querying IMEI, network registration, signal strength, and USSD.",
            "path": "/usr/local/bin/at-console",
            "cmd": "at-console /dev/ttyUSB0"
    },
    {
            "name": "Gammu",
            "category": "baseband",
            "status": "ready",
            "desc": "Universal mobile device manager supporting SMS sending/receiving, USSD queries, call management, and phonebook access via AT commands.",
            "path": "System-wide",
            "cmd": "gammu --port /dev/ttyUSB0 --connection at115200 identify"
    },
    {
            "name": "Kismet",
            "category": "core",
            "status": "ready",
            "desc": "Wireless network detector, sniffer, and intrusion detection system. Captures raw 802.11 frames on mon0 and logs device fingerprints.",
            "path": "System-wide",
            "cmd": "sudo kismet -c mon0"
    },
    {
            "name": "tcpdump",
            "category": "core",
            "status": "ready",
            "desc": "CLI packet capture tool. Used in TelcoSec scripts to capture raw traffic on the monitoring interface and pipe to Wireshark.",
            "path": "System-wide",
            "cmd": "sudo tcpdump -i mon0 -w capture.pcap"
    },
    {
            "name": "Zoiper5",
            "category": "voip",
            "status": "ready",
            "desc": "Commercial-grade VoIP softphone supporting SIP and IAX2. Used for testing SIP registrars, call flows, and intercepted credential replays.",
            "path": "System application (zoiper5)",
            "cmd": "zoiper5"
    },
    {
            "name": "SIPp",
            "category": "voip",
            "status": "ready",
            "desc": "SIP load tester and traffic generator. Sends scripted SIP scenarios (INVITE storms, registration floods) to audit VoIP infrastructure.",
            "path": "System-wide",
            "cmd": "sipp -h"
    },
    {
            "name": "atinout",
            "category": "baseband",
            "status": "ready",
            "desc": "Quick command-line tool to send AT commands to a modem and capture the output. Excellent for scripting USSD or SMS tasks.",
            "path": "/usr/local/bin/atinout",
            "cmd": "echo 'AT+CGMI' | atinout - /dev/ttyUSB0 -"
    },
    {
            "name": "ModemManager GUI",
            "category": "baseband",
            "status": "ready",
            "desc": "Graphical frontend for ModemManager, dbus, and NetworkManager. Allows sending SMS, USSD, and reading SIM contacts directly from the desktop.",
            "path": "System application",
            "cmd": "modem-manager-gui"
    },
    {
            "name": "SP Flash Tool (Helper)",
            "category": "baseband",
            "status": "setup",
            "desc": "Proprietary flash tool for MediaTek devices. The pre-installed helper script provides download links and extraction instructions.",
            "path": "/usr/local/bin/spflashtool-install",
            "cmd": "spflashtool-install"
    },
    {
            "name": "Linphone",
            "category": "voip",
            "status": "ready",
            "desc": "Open-source SIP softphone used for voice and video over IP. Useful as an alternative to Zoiper for testing PBX configurations and SIP registrars.",
            "path": "System application (linphone)",
            "cmd": "linphone"
    },
    {
            "name": "Nokia NetAct CLI",
            "category": "mw",
            "status": "ready",
            "desc": "Wrapper for connecting to Nokia NetAct OSS systems using standard telecom administrative protocols.",
            "path": "/usr/local/bin/nokia-netact-cli",
            "cmd": "nokia-netact-cli <host>"
    },
    {
            "name": "Ericsson ENM CLI",
            "category": "mw",
            "status": "ready",
            "desc": "Wrapper for connecting to Ericsson Network Manager (ENM) infrastructure via SSH.",
            "path": "/usr/local/bin/ericsson-enm-cli",
            "cmd": "ericsson-enm-cli <host>"
    },
    {
            "name": "Huawei U2000 CLI",
            "category": "mw",
            "status": "ready",
            "desc": "Wrapper for accessing Huawei U2000 management interfaces using telnet or SSH fallback.",
            "path": "/usr/local/bin/huawei-u2000-cli",
            "cmd": "huawei-u2000-cli <host>"
    },
    {
            "name": "GQRX",
            "category": "sdr",
            "status": "ready",
            "desc": "An open source software defined radio (SDR) receiver GUI and spectrum analyzer powered by GNU Radio and Qt.",
            "path": "Conda env (telcosec-sdr)",
            "cmd": "gqrx"
    },
    {
            "name": "Twinkle",
            "category": "voip",
            "status": "ready",
            "desc": "A SIP softphone for voice over IP and instant messaging communications, useful for VoIP security and signaling audits.",
            "path": "System application (twinkle)",
            "cmd": "twinkle"
    },
    {
            "name": "Baresip",
            "category": "voip",
            "status": "ready",
            "desc": "A modular, command-line based SIP user agent with audio and video support, ideal for scriptable VoIP and PBX testing.",
            "path": "System-wide",
            "cmd": "baresip"
    },
    {
            "name": "Macchanger",
            "category": "adsl",
            "status": "ready",
            "desc": "Utility for viewing/manipulating the MAC address of network interfaces to bypass sticky-MAC port security.",
            "path": "System-wide",
            "cmd": "macchanger --help"
    },
    {
            "name": "VLAN (vconfig)",
            "category": "adsl",
            "status": "ready",
            "desc": "VLAN hopping and manipulation tool for executing attacks against DSLAM and Open vSwitch configurations.",
            "path": "System-wide",
            "cmd": "vconfig"
    },
    {
            "name": "Asleap",
            "category": "adsl",
            "status": "ready",
            "desc": "Performs offline dictionary attacks against captured PPPoE MS-CHAPv2 challenge/response hashes.",
            "path": "System-wide",
            "cmd": "asleap -h"
    },
    {
            "name": "FreeRADIUS Utils",
            "category": "adsl",
            "status": "ready",
            "desc": "Includes radtest and radclient to craft malicious RADIUS Access-Request packets or test dictionary attacks.",
            "path": "System-wide",
            "cmd": "radtest -h"
    },
    {
            "name": "Hashcat",
            "category": "adsl",
            "status": "ready",
            "desc": "Advanced password recovery utility supporting multiple algorithms including RADIUS shared secrets and MS-CHAPv2.",
            "path": "System-wide",
            "cmd": "hashcat -h"
    },
    {
            "name": "John the Ripper",
            "category": "adsl",
            "status": "ready",
            "desc": "Fast password cracker, useful for intercepted RADIUS shared secrets or MS-CHAPv2 hashes.",
            "path": "System-wide",
            "cmd": "john"
    },
    {
            "name": "PPPoE Tools",
            "category": "adsl",
            "status": "ready",
            "desc": "Includes ppp and pppoe tools to establish rogue PPPoE sessions, acting as a rogue CPE.",
            "path": "System-wide",
            "cmd": "pppoe-setup"
    },
    {
            "name": "Nikto",
            "category": "adsl",
            "status": "ready",
            "desc": "Web server scanner which performs comprehensive tests against web servers for multiple items, including CPE local Web UIs.",
            "path": "System-wide",
            "cmd": "nikto -H"
    },
    {
            "name": "Gobuster",
            "category": "adsl",
            "status": "ready",
            "desc": "Directory/File, DNS and VHost busting tool written in Go, for directory enumeration on CPE or GenieACS dashboards.",
            "path": "System-wide",
            "cmd": "gobuster help"
    },
    {
            "name": "SNMP Check",
            "category": "adsl",
            "status": "ready",
            "desc": "Tool to automate the process of gathering information via SNMP protocols, exploiting intentionally weak community strings.",
            "path": "System-wide",
            "cmd": "snmpcheck -h"
    },
    {
            "name": "RouterSploit",
            "category": "adsl",
            "status": "ready",
            "desc": "Exploitation framework tailored for embedded devices like CPE routers and cable modems.",
            "path": "/usr/local/bin/routersploit",
            "cmd": "routersploit"
    },
    {
            "name": "docsis",
            "category": "adsl",
            "status": "ready",
            "desc": "Utility to compile and decompile DOCSIS binary configuration files to uncover hidden SNMP settings.",
            "path": "/usr/bin/docsis",
            "cmd": "docsis"
    },
    {
            "name": "tftpd-hpa",
            "category": "adsl",
            "status": "ready",
            "desc": "Highly configurable TFTP server and client for intercepting or spoofing cable modem provisioning downloads.",
            "path": "System Service",
            "cmd": "systemctl status tftpd-hpa"
    },
    {
            "name": "isc-dhcp-server",
            "category": "adsl",
            "status": "ready",
            "desc": "Used to set up a rogue DHCP server injecting custom DOCSIS DHCP options (like Option 122 or 54) to direct modems.",
            "path": "System Service",
            "cmd": "systemctl status isc-dhcp-server"
    },
    {
            "name": "yersinia",
            "category": "adsl",
            "status": "ready",
            "desc": "Powerful framework for exploiting Layer 2 protocols (DHCP exhaustion, STP/CDP/VTP manipulation) against the switching infrastructure.",
            "path": "/usr/bin/yersinia",
            "cmd": "yersinia"
    },
    {
            "name": "ettercap",
            "category": "adsl",
            "status": "ready",
            "desc": "Comprehensive suite for man-in-the-middle attacks on LAN (e.g. ARP spoofing) to intercept unencrypted TFTP configuration downloads.",
            "path": "System-wide",
            "cmd": "ettercap-text-only"
    },
    {
            "name": "TelcoSec Profile Switcher",
            "category": "core",
            "status": "ready",
            "desc": "Operational security profile switcher to toggle between Lab Mode (SDR low-latency, rp_filter=0) and Field Mode (hardened firewall, strict rp_filter, rate-limited SSH).",
            "path": "/usr/local/bin/telcosec-profile",
            "cmd": "sudo telcosec-profile status"
    },
    {
            "name": "my5G-RANTester",
            "category": "5g",
            "status": "ready",
            "desc": "Scalable 5G Standalone multi-UE and gNodeB simulator for load testing and traffic generation over N1, N2, and N3 interfaces.",
            "path": "/usr/local/bin/my5g-rantester",
            "cmd": "my5g-rantester --help"
    },
    {
            "name": "OsmocomBB",
            "category": "2g",
            "status": "ready",
            "desc": "Osmocom GSM Mobile Station baseband protocol stack, providing layer 1-3 mobile phone emulation and CCCH/BCCH channel scanning.",
            "path": "/usr/local/bin/osmocombb-install",
            "cmd": "sudo osmocombb-install"
    },
    {
            "name": "Inspectrum",
            "category": "sdr",
            "status": "ready",
            "desc": "Offline I/Q file visualizer and signal analyzer for measuring symbol periods, FSK frequency deviation, and preamble detection.",
            "path": "/usr/bin/inspectrum",
            "cmd": "inspectrum --help"
    },
    {
            "name": "URH (Universal Radio Hacker)",
            "category": "sdr",
            "status": "ready",
            "desc": "Complete wireless protocol reverse engineering suite supporting demodulation, bit extraction, frame parsing, and signal replay.",
            "path": "/usr/local/bin/urh",
            "cmd": "urh --help"
    },
    {
            "name": "Gpredict",
            "category": "sdr",
            "status": "ready",
            "desc": "Real-time satellite tracking and orbit prediction system for calculating Doppler frequency shifts in 3GPP NTN and satellite SDR captures.",
            "path": "/usr/bin/gpredict",
            "cmd": "gpredict --help"
    },
    {
            "name": "pcsc-tools",
            "category": "sim",
            "status": "ready",
            "desc": "Smartcard reader discovery toolset featuring pcsc_scan to monitor card insertions and decode Answer-to-Reset (ATR) strings.",
            "path": "/usr/bin/pcsc_scan",
            "cmd": "pcsc_scan -v"
    },
    {
            "name": "OpenSC",
            "category": "sim",
            "status": "ready",
            "desc": "Comprehensive smartcard and UICC management library and tools (pkcs11-tool, opensc-tool, opensc-explorer) for cryptographic tokens.",
            "path": "/usr/bin/pkcs11-tool",
            "cmd": "pkcs11-tool -L"
    },
    {
            "name": "sipsak",
            "category": "voip",
            "status": "ready",
            "desc": "SIP swiss army knife command-line tool for sending OPTIONS health checks, tracerouting SIP hops, and stress testing SIP proxies.",
            "path": "/usr/bin/sipsak",
            "cmd": "sipsak --help"
    },
    {
            "name": "voiphopper",
            "category": "voip",
            "status": "ready",
            "desc": "Security assessment tool that mimics IP phone behavior by spoofing Cisco CDP and LLDP-MED packets to hop into VoIP voice VLANs.",
            "path": "/usr/local/bin/voiphopper",
            "cmd": "voiphopper --help"
    },
    {
            "name": "rtpbleed",
            "category": "voip",
            "status": "ready",
            "desc": "Scanner and audio extractor targeting RTP Bleed vulnerabilities in media proxies and SBCs to discover leaky RTP ports.",
            "path": "/usr/local/bin/rtpbleed",
            "cmd": "rtpbleed --help"
    },
    {
            "name": "mausezahn (mz)",
            "category": "adsl",
            "status": "ready",
            "desc": "High-speed carrier Ethernet and multi-protocol packet crafter supporting 802.1Q tagged VLANs, QinQ, MPLS labels, and BPDU injection.",
            "path": "/usr/bin/mz",
            "cmd": "mz --help"
    },
    {
            "name": "mitmproxy (5G SBI)",
            "category": "5g",
            "status": "ready",
            "desc": "Interactive HTTP/2, mTLS, and WebSockets interception proxy tailored for 5G Service Based Architecture (SBI) API auditing.",
            "path": "/usr/bin/mitmproxy",
            "cmd": "mitmproxy --version"
    },
    {
            "name": "O-RAN E2 Node Simulator (e2sim)",
            "category": "5g",
            "status": "setup",
            "desc": "Open RAN E2 Node emulator and E2AP protocol tester communicating with Near-RT RICs over SCTP to assess xApp telemetry and control plane security.",
            "path": "/usr/local/bin/oran-e2sim",
            "cmd": "sudo oran-e2sim --help"
    },
    {
            "name": "O-RAN O1/A1 Security Auditor",
            "category": "5g",
            "status": "ready",
            "desc": "Automated security auditor for O-RAN O1 NETCONF/YANG management interfaces and Non-RT RIC A1 policy REST APIs.",
            "path": "/usr/local/bin/oran-o1-audit",
            "cmd": "oran-o1-audit --help"
    },
    {
            "name": "5G SBI REST API Mutator",
            "category": "5g",
            "status": "setup",
            "desc": "Mutational HTTP/2 and JSON REST fuzzer targeting 3GPP 5G Core Network Functions (NRF, AMF, UDM, AUSF, SEPP) to detect injection flaws and token bypasses.",
            "path": "/usr/local/bin/5g-sbi-fuzzer",
            "cmd": "sudo 5g-sbi-fuzzer --help"
    },
    {
            "name": "5G SBI OpenAPI Contract Validator",
            "category": "5g",
            "status": "ready",
            "desc": "Automated schema compliance validator asserting live 5G Core SBI responses against official 3GPP Release 16/17/18 OpenAPI specifications.",
            "path": "/usr/local/bin/5g-sbi-validator",
            "cmd": "5g-sbi-validator --help"
    },
    {
            "name": "gr-satellites (NTN DSP Suite)",
            "category": "sdr",
            "status": "ready",
            "desc": "GNU Radio telemetry and signal processing suite for 3GPP Rel-17 NTN satellite communications, Doppler shift compensation, and downlink decoding.",
            "path": "Conda env (telcosec-sdr)",
            "cmd": "conda activate telcosec-sdr && gr_satellites --help"
    },
    {
            "name": "gr-iridium & Iridium Toolkit",
            "category": "sdr",
            "status": "setup",
            "desc": "Real-time burst detection, L-band frame parsing, and packet extraction toolkit for Iridium satellite mobile telephony and M2M channels.",
            "path": "/usr/local/bin/iridium-parser",
            "cmd": "iridium-parser --help"
    },
    {
            "name": "Falcon (LTE Security Analyzer)",
            "category": "4g",
            "status": "setup",
            "desc": "Fast cellular over-the-air protocol analysis framework for detecting LTE rogue base stations, tracking temporary mobile identifiers, and inspecting RRC connection setups.",
            "path": "/usr/local/bin/falcon",
            "cmd": "falcon --help"
    },
    {
            "name": "TelcoSec APN Permutator",
            "category": "core",
            "status": "ready",
            "desc": "Telecom APN wordlist permutation and discovery utility for identifying hidden GGSN/PGW access point names and unauthenticated GTP-U tunnel endpoints.",
            "path": "/usr/local/bin/telcosec-apn-permutator",
            "cmd": "telcosec-apn-permutator --help"
    },
    {
            "name": "TelcoSec IMSI Generator",
            "category": "sim",
            "status": "ready",
            "desc": "International Mobile Subscriber Identity (IMSI) permutation and MCC/MNC range generator for subscriber auditing, roaming tests, and test USIM programming.",
            "path": "/usr/local/bin/telcosec-imsi-generator",
            "cmd": "telcosec-imsi-generator --help"
    },
    {
            "name": "LimeSuite (LimeUtil)",
            "category": "sdr",
            "status": "ready",
            "desc": "Device configuration utility and FPGA bitstream management CLI for LimeSDR USB, LimeSDR Mini, and PCIe cellular transceiver hardware.",
            "path": "/usr/local/bin/LimeUtil",
            "cmd": "LimeUtil --find"
    },
    {
            "name": "sdr-info",
            "category": "sdr",
            "status": "ready",
            "desc": "Unified multi-vendor Software Defined Radio hardware probe detecting USB throughput, FPGA firmware status, and RF clock synchronization across all connected transceivers.",
            "path": "/usr/local/bin/sdr-info",
            "cmd": "sdr-info"
    },
    {
            "name": "telcosec-ran-status",
            "category": "5g",
            "status": "ready",
            "desc": "Real-time cellular radio access network emission monitor and telemetry dashboard for tracking active 4G eNodeB and 5G gNodeB transmission states.",
            "path": "/usr/local/bin/telcosec-ran-status",
            "cmd": "telcosec-ran-status"
    }
];

document.addEventListener("DOMContentLoaded", () => {
    // ── Sidebar views navigation ────────────────────────────────────────────
    const navLinks = document.querySelectorAll(".nav-link");
    const sections = document.querySelectorAll(".content-section");
    const sidebar = document.querySelector(".sidebar");
    const mobileToggle = document.getElementById("mobileToggle");
    const sidebarOverlay = document.getElementById("sidebarOverlay");

    const VALID_SECTIONS = ["overview", "features", "tools", "drivers", "fuzzer", "scenarios", "prolabs", "academy", "builder", "projects"];

    function activateSection(target) {
        if (!VALID_SECTIONS.includes(target)) target = "overview";

        navLinks.forEach(l => {
            if (l.getAttribute("data-target") === target) {
                l.classList.add("active");
            } else {
                l.classList.remove("active");
            }
        });

        sections.forEach(sec => {
            if (sec.id === target) {
                sec.classList.add("active");
            } else {
                sec.classList.remove("active");
            }
        });

        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    // Activate section from URL hash on initial load
    const initialHash = window.location.hash.slice(1);
    if (initialHash) activateSection(initialHash);

    // Handle browser back / forward navigation
    window.addEventListener("popstate", () => {
        activateSection(window.location.hash.slice(1) || "overview");
    });

    navLinks.forEach(link => {
        link.addEventListener("click", (e) => {
            e.preventDefault();
            const target = link.getAttribute("data-target");

            // Update URL hash without triggering a page scroll
            history.pushState(null, "", "#" + target);
            activateSection(target);

            // Close sidebar on mobile after clicking
            if (sidebar.classList.contains("open")) {
                sidebar.classList.remove("open");
                if (sidebarOverlay) sidebarOverlay.classList.remove("active");
                mobileToggle.innerHTML = `
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="3" y1="12" x2="21" y2="12"></line>
                        <line x1="3" y1="6" x2="21" y2="6"></line>
                        <line x1="3" y1="18" x2="21" y2="18"></line>
                    </svg>
                `;
            }
        });
    });

    // ── Mobile sidebar toggle ───────────────────────────────────────────────
    if (mobileToggle) {
        mobileToggle.addEventListener("click", () => {
            const isOpen = sidebar.classList.toggle("open");
            if (sidebarOverlay) sidebarOverlay.classList.toggle("active", isOpen);
            if (isOpen) {
                mobileToggle.innerHTML = `
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="18" y1="6" x2="6" y2="18"></line>
                        <line x1="6" y1="6" x2="18" y2="18"></line>
                    </svg>
                `;
            } else {
                mobileToggle.innerHTML = `
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="3" y1="12" x2="21" y2="12"></line>
                        <line x1="3" y1="6" x2="21" y2="6"></line>
                        <line x1="3" y1="18" x2="21" y2="18"></line>
                    </svg>
                `;
            }
        });
    }

    if (sidebarOverlay) {
        sidebarOverlay.addEventListener("click", () => {
            sidebar.classList.remove("open");
            sidebarOverlay.classList.remove("active");
            if (mobileToggle) {
                mobileToggle.innerHTML = `
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="3" y1="12" x2="21" y2="12"></line>
                        <line x1="3" y1="6" x2="21" y2="6"></line>
                        <line x1="3" y1="18" x2="21" y2="18"></line>
                    </svg>
                `;
            }
        });
    }

    // ── Update filter buttons with tool counts ──────────────────────────────
    function updateFilterCounts() {
        const counts = { all: toolsCatalog.length, sdr: 0, "2g": 0, "4g": 0, "5g": 0, baseband: 0, core: 0, sim: 0, mw: 0, voip: 0, adsl: 0 };
        toolsCatalog.forEach(tool => {
            if (counts[tool.category] !== undefined) {
                counts[tool.category]++;
            }
        });

        const filterBtnsList = document.querySelectorAll(".filter-btn");
        filterBtnsList.forEach(btn => {
            const filter = btn.getAttribute("data-filter");
            const label = btn.textContent.split(" (")[0]; // Clean label
            if (counts[filter] !== undefined) {
                btn.textContent = `${label} (${counts[filter]})`;
            }
        });
    }

    // Initialize filter counts
    updateFilterCounts();

    // ── Tools directory implementation ──────────────────────────────────────
    const toolsGrid = document.getElementById("toolsGrid");
    const searchInput = document.getElementById("toolSearch");
    const filterBtns = document.querySelectorAll(".filter-btn");

    let activeFilter = "all";
    let searchQuery = "";

    function renderTools() {
        if (!toolsGrid) return;
        toolsGrid.innerHTML = "";

        const filteredTools = toolsCatalog.filter(tool => {
            const matchesCategory = activeFilter === "all" || tool.category === activeFilter;
            const matchesSearch = tool.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                tool.desc.toLowerCase().includes(searchQuery.toLowerCase()) ||
                tool.cmd.toLowerCase().includes(searchQuery.toLowerCase());
            return matchesCategory && matchesSearch;
        });

        if (filteredTools.length === 0) {
            toolsGrid.innerHTML = `
                <div style="grid-column: 1/-1; text-align: center; padding: 40px; color: var(--text-muted);">
                    <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="margin-bottom: 15px;">
                        <circle cx="11" cy="11" r="8"></circle>
                        <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
                    </svg>
                    <p>No tools match your query: "${searchQuery}"</p>
                </div>
            `;
            return;
        }

        filteredTools.forEach(tool => {
            const card = document.createElement("div");
            card.className = "card highlight-teal";

            let catTag = "";
            switch (tool.category) {
                case "sdr":      catTag = '<span class="tag tag-sdr">SDR</span>'; break;
                case "2g":       catTag = '<span class="tag tag-2g">2G / GSM</span>'; break;
                case "4g":       catTag = '<span class="tag tag-4g">LTE / 4G</span>'; break;
                case "5g":       catTag = '<span class="tag tag-5g">5G NR</span>'; break;
                case "baseband": catTag = '<span class="tag tag-baseband">Baseband & UE</span>'; break;
                case "sim":      catTag = '<span class="tag tag-sim">SIM / eSIM</span>'; break;
                case "core":     catTag = '<span class="tag tag-core">Core & Signaling</span>'; break;
                case "voip":     catTag = '<span class="tag tag-voip">VoIP</span>'; break;
                case "mw":       catTag = '<span class="tag tag-mw">MW / Vendor CLI</span>'; break;
                case "adsl":     catTag = '<span class="tag tag-adsl">ADSL / Broadband</span>'; break;
            }

            const statusTag = tool.status === "setup"
                ? '<span class="tag status-setup">Setup required</span>'
                : '<span class="tag status-ready">Ready</span>';

            card.innerHTML = `
                <div class="card-title">
                    ${tool.name}
                    ${catTag}
                    ${statusTag}
                </div>
                <p class="card-desc" style="margin-bottom: 15px;">${tool.desc}</p>
                <div style="font-size: 0.8rem; color: var(--text-muted); margin-bottom: 6px;">
                    <strong>Location:</strong> <code class="inline-code" style="color: var(--text-secondary);">${tool.path}</code>
                </div>
                <div class="terminal-block" style="margin: 10px 0 0 0;">
                    <div class="terminal-body" style="padding: 10px 15px;">
                        <code>$ ${tool.cmd}</code>
                        <button class="terminal-copy-btn" onclick="copyCommand(this, '${tool.cmd.replace(/'/g, "\\'")}')" style="top: 5px; right: 10px; padding: 3px 6px;">Copy</button>
                    </div>
                </div>
            `;

            toolsGrid.appendChild(card);
        });
    }

    if (searchInput) {
        const searchShortcut = document.getElementById("searchShortcut");
        const searchClearBtn = document.getElementById("searchClearBtn");

        // Handle shortcuts (/)
        document.addEventListener("keydown", (e) => {
            const activeTag = document.activeElement.tagName.toLowerCase();
            const isInputActive = activeTag === "input" || activeTag === "textarea";

            // '/' or 'Ctrl+K' focuses search input
            if ((e.key === "/" || ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k")) && !isInputActive) {
                e.preventDefault();
                searchInput.focus();
            }
        });

        // Hide shortcut overlay on focus
        searchInput.addEventListener("focus", () => {
            if (searchShortcut) searchShortcut.style.opacity = "0";
        });

        // Show shortcut overlay on blur if empty
        searchInput.addEventListener("blur", () => {
            if (searchShortcut && !searchInput.value) {
                searchShortcut.style.opacity = "1";
            }
        });

        searchInput.addEventListener("input", (e) => {
            searchQuery = e.target.value;
            if (searchClearBtn) {
                searchClearBtn.style.display = searchQuery ? "flex" : "none";
            }
            if (searchShortcut) {
                searchShortcut.style.opacity = searchQuery ? "0" : "1";
            }
            renderTools();
        });

        if (searchClearBtn) {
            searchClearBtn.addEventListener("click", () => {
                searchInput.value = "";
                searchQuery = "";
                searchClearBtn.style.display = "none";
                if (searchShortcut) searchShortcut.style.opacity = "1";
                searchInput.focus();
                renderTools();
            });
        }
    }

    filterBtns.forEach(btn => {
        btn.addEventListener("click", () => {
            filterBtns.forEach(b => b.classList.remove("active"));
            btn.classList.add("active");
            activeFilter = btn.getAttribute("data-filter");
            renderTools();
        });
    });

    // ── Theme toggle switch implementation ───────────────────────────────
    const themeToggleBtn = document.getElementById("themeToggleBtn");

    // Check local storage for theme preference
    const savedTheme = localStorage.getItem("theme");
    if (savedTheme === "light") {
        document.body.classList.add("light-theme");
    }

    if (themeToggleBtn) {
        themeToggleBtn.addEventListener("click", () => {
            const isLight = document.body.classList.toggle("light-theme");
            localStorage.setItem("theme", isLight ? "light" : "dark");
        });
    }

    // Initial render of tools
    renderTools();

    // ── Boot overlay (CRT scan sweep) ────────────────────────────────────────
    const bootOverlay = document.getElementById("bootOverlay");
    if (bootOverlay) {
        setTimeout(() => {
            bootOverlay.classList.add("done");
            bootOverlay.addEventListener("animationend", () => bootOverlay.remove(), { once: true });
        }, 920);
    }

    // ── Spectrum analyzer canvas ──────────────────────────────────────────────
    initSpectrum();
});

// ── Spectrum canvas — live amber frequency bars in the overview hero ─────────
function initSpectrum() {
    const canvas = document.getElementById("spectrumCanvas");
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    const COUNT = 42;
    const BAR_W = 3;
    const GAP = 2;
    const TOTAL_W = COUNT * (BAR_W + GAP);

    canvas.width = TOTAL_W;

    function resize() {
        const h = canvas.parentElement ? canvas.parentElement.offsetHeight : 140;
        canvas.height = Math.max(h, 80);
    }
    resize();
    window.addEventListener("resize", resize);

    const bars = Array.from({ length: COUNT }, () => ({
        h: Math.random() * 0.55 + 0.08,
        target: Math.random() * 0.55 + 0.08,
        speed: Math.random() * 0.035 + 0.012,
        jitter: Math.random() * 0.18 + 0.04
    }));

    function draw() {
        const H = canvas.height;
        ctx.clearRect(0, 0, canvas.width, H);

        bars.forEach((bar, i) => {
            bar.h += (bar.target - bar.h) * bar.speed;

            if (Math.random() < 0.018) {
                bar.target = Math.random() * 0.78 + 0.05;
                bar.speed = Math.random() * 0.04 + 0.01;
            }

            const jitter = (Math.random() - 0.5) * bar.jitter;
            const barH = Math.max(3, (bar.h + jitter) * H);
            const x = i * (BAR_W + GAP);
            const y = H - barH;

            const grad = ctx.createLinearGradient(0, H, 0, y);
            grad.addColorStop(0, "rgba(232, 146, 30, 0.95)");
            grad.addColorStop(0.55, "rgba(245, 170, 53, 0.72)");
            grad.addColorStop(1, "rgba(255, 210, 100, 0.35)");

            ctx.fillStyle = grad;
            ctx.fillRect(x, y, BAR_W, barH);

            // Peak pixel
            ctx.fillStyle = "rgba(255, 230, 160, 0.88)";
            ctx.fillRect(x, y, BAR_W, 1);
        });

        requestAnimationFrame(draw);
    }

    draw();
}

// Clipboard helper function (globally available)
window.copyCommand = function (button, command) {
    navigator.clipboard.writeText(command).then(() => {
        const originalText = button.textContent;
        button.textContent = "Copied!";
        button.style.borderColor = "var(--accent-teal)";
        button.style.color = "var(--accent-teal)";

        setTimeout(() => {
            button.textContent = originalText;
            button.style.borderColor = "var(--border-color)";
            button.style.color = "var(--text-secondary)";
        }, 1500);
    }).catch(err => {
        console.error('Could not copy command to clipboard: ', err);
    });
};
