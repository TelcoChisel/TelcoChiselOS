// Package doctor provides unified diagnostic probing for RF transceivers,
// smart card / SIM readers, cellular modems, kernel latency parameters,
// and core telecom services.
package doctor

import (
	"fmt"
	"io"
	"os/exec"
	"path/filepath"

	"github.com/TelcoSec-Tools/telcosec-cli/pkg/sdr"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/sim"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/telemetry"
)

// ANSI Color definitions
const (
	Bold   = "\033[1m"
	Cyan   = "\033[1;36m"
	Green  = "\033[1;32m"
	Yellow = "\033[1;33m"
	Red    = "\033[1;31m"
	Dim    = "\033[2m"
	Reset  = "\033[0m"
)

// CheckItem represents a single diagnostic assertion result.
type CheckItem struct {
	Category string
	Name     string
	Status   string // "PASS", "WARN", "FAIL", "INFO"
	Details  string
}

// DoctorReport contains all aggregated system findings.
type DoctorReport struct {
	Items       []CheckItem
	PassCount   int
	WarnCount   int
	FailCount   int
	SDRDevices  []sdr.USBSDRDevice
	Readers     []sim.SmartcardReader
	SerialPorts []string
}

// RunDoctor probes the system across kernel, hardware, serial, and service domains.
func RunDoctor(w io.Writer) DoctorReport {
	report := DoctorReport{
		Items: make([]CheckItem, 0),
	}

	fmt.Fprintf(w, "%s=== TelcoChisel Unified Hardware & Environment Diagnostics ===%s\n\n", Bold+Cyan, Reset)

	// 1. Kernel & Latency Subsystem
	kver, isRT := telemetry.GetKernelVersion()
	if isRT {
		report.addItem("Kernel", "Low-Latency / Real-Time Kernel", "PASS", fmt.Sprintf("%s (1000Hz preemption)", kver))
	} else {
		report.addItem("Kernel", "Kernel Timer Profile", "WARN", fmt.Sprintf("%s (Standard generic kernel; low-latency recommended for high-rate SDR)", kver))
	}

	// Check PAM limits
	pamOk, pamDesc := telemetry.CheckPAMLimits()
	if pamOk {
		report.addItem("Kernel", "PAM Real-time & Memlock Limits", "PASS", pamDesc)
	} else {
		report.addItem("Kernel", "PAM Real-time & Memlock Limits", "WARN", "Memlock or RTPRIO limits restricted (/etc/security/limits.d/)")
	}

	// Check USBFS Memory
	usbfsMB := telemetry.GetUSBFSMemoryMB()
	if usbfsMB >= 128 {
		report.addItem("Kernel", "USBFS Memory Allocation", "PASS", fmt.Sprintf("%d MB (Sufficient for multi-channel SDR buffer)", usbfsMB))
	} else if usbfsMB > 0 {
		report.addItem("Kernel", "USBFS Memory Allocation", "WARN", fmt.Sprintf("%d MB (Recommend >= 128 MB via usbfs_memory_mb)", usbfsMB))
	} else {
		report.addItem("Kernel", "USBFS Memory Allocation", "INFO", "Not configured or running in container")
	}

	// 2. Hardware: SDR Devices
	sdrDevs := sdr.DetectUSBSDRs()
	report.SDRDevices = sdrDevs
	if len(sdrDevs) > 0 {
		for _, dev := range sdrDevs {
			report.addItem("SDR Hardware", dev.Model, "PASS", fmt.Sprintf("USB ID %s:%s (Ready for UHD/SoapySDR)", dev.VendorID, dev.ProductID))
		}
	} else {
		report.addItem("SDR Hardware", "USB SDR Transceiver", "INFO", "No USB SDR connected (Plug in HackRF, USRP, BladeRF, LimeSDR, or RTL-SDR)")
	}

	// 3. Hardware: SIM & Smartcard Readers
	readers, err := sim.ListPCScReaders()
	report.Readers = readers
	if err == nil && len(readers) > 0 {
		for _, r := range readers {
			status := "PASS"
			details := "Ready for pySim / lpac"
			if r.CardPresent {
				details += " [Card Present]"
			}
			report.addItem("SIM / Smartcard", r.Name, status, details)
		}
	} else {
		report.addItem("SIM / Smartcard", "PCSC Smartcard Readers", "INFO", "No PCSC readers detected (SIMtrace 2 / USB reader)")
	}

	// 4. Hardware: Cellular Modems & Serial AT Ports
	serialPorts := DetectSerialModems()
	report.SerialPorts = serialPorts
	if len(serialPorts) > 0 {
		for _, port := range serialPorts {
			report.addItem("Modem / Serial", port, "PASS", "Serial device node active (/dev/ttyUSB or /dev/ttyACM)")
		}
	} else {
		report.addItem("Modem / Serial", "Cellular AT Interfaces", "INFO", "No /dev/ttyUSB* or /dev/ttyACM* modems detected")
	}

	// 5. Core Services
	services := map[string]string{
		"pcscd":  "Smartcard PC/SC Daemon",
		"docker": "Container Runtime (Open5GS/RAN)",
	}

	for srv, desc := range services {
		active := isServiceActive(srv)
		if active {
			report.addItem("Services", desc, "PASS", fmt.Sprintf("%s.service active", srv))
		} else {
			report.addItem("Services", desc, "INFO", fmt.Sprintf("%s.service inactive / on-demand", srv))
		}
	}

	// Print Summary Table
	PrintDoctorReport(w, report)
	return report
}

func (r *DoctorReport) addItem(cat, name, status, details string) {
	switch status {
	case "PASS":
		r.PassCount++
	case "WARN":
		r.WarnCount++
	case "FAIL":
		r.FailCount++
	}
	r.Items = append(r.Items, CheckItem{
		Category: cat,
		Name:     name,
		Status:   status,
		Details:  details,
	})
}

// DetectSerialModems searches for attached cellular modems or AT-capable serial devices.
func DetectSerialModems() []string {
	ports := make([]string, 0)
	matches, _ := filepath.Glob("/dev/ttyUSB*")
	ports = append(ports, matches...)
	acmMatches, _ := filepath.Glob("/dev/ttyACM*")
	ports = append(ports, acmMatches...)
	return ports
}

func isServiceActive(name string) bool {
	cmd := exec.Command("systemctl", "is-active", "--quiet", name)
	return cmd.Run() == nil
}

// PrintDoctorReport renders formatted diagnostic tables to the output writer.
func PrintDoctorReport(w io.Writer, report DoctorReport) {
	currentCat := ""
	for _, item := range report.Items {
		if item.Category != currentCat {
			currentCat = item.Category
			fmt.Fprintf(w, "\n%s[%s]%s\n", Bold, currentCat, Reset)
		}

		statusBadge := ""
		switch item.Status {
		case "PASS":
			statusBadge = fmt.Sprintf("%s[PASS]%s", Green, Reset)
		case "WARN":
			statusBadge = fmt.Sprintf("%s[WARN]%s", Yellow, Reset)
		case "FAIL":
			statusBadge = fmt.Sprintf("%s[FAIL]%s", Red, Reset)
		default:
			statusBadge = fmt.Sprintf("%s[INFO]%s", Dim, Reset)
		}

		fmt.Fprintf(w, "  %-8s %-34s %s%s%s\n", statusBadge, item.Name, Dim, item.Details, Reset)
	}

	fmt.Fprintf(w, "\n%s=== Diagnostic Summary ===%s\n", Bold, Reset)
	fmt.Fprintf(w, "  Passed: %s%d%s  |  Warnings: %s%d%s  |  Failures: %s%d%s\n\n",
		Green, report.PassCount, Reset,
		Yellow, report.WarnCount, Reset,
		Red, report.FailCount, Reset)
}
