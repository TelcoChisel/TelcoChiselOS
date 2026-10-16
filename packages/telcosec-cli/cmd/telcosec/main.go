// Command telcosec provides the unified operator CLI for TelcoChiselOS
// and standalone Linux systems.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/TelcoSec-Tools/telcosec-cli/completions"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/assets"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/cellular"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/doctor"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/docs"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/evidence"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/network"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/ntn"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/oran"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/packages"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/sbi"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/sdr"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/search"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/sim"
	"github.com/TelcoSec-Tools/telcosec-cli/pkg/telemetry"
)

var (
	// Version is populated at build time via -ldflags.
	Version   = "2026.2"
	GitCommit = "development"
	BuildDate = "unknown"
)

func printBanner() {
	fmt.Printf(`%s
  _____ _____ _     ____ ___   ____ _   _ ___ ____  _____ _     
 |_   _| ____| |   / ___/ _ \ / ___| | | |_ _/ ___|| ____| |    
   | | |  _| | |  | |  | | | | |   | |_| || |\___ \|  _| | |    
   | | | |___| |__| |__| |_| | |___|  _  || | ___) | |___| |___ 
   |_| |_____|_____\____\___/ \____|_| |_|___|____/|_____|_____|
`, telemetry.Cyan)
	fmt.Printf("%s%s          TelcoChisel Telecom Security Command Center v%s%s\n\n",
		telemetry.Reset, telemetry.Bold, Version, telemetry.Reset)
}

func printUsage() {
	printBanner()
	fmt.Printf(`Usage: telcosec <command> [options]
       telcochisel <command> [options]

Commands:
  doctor               Unified hardware, RF, SIM, modem, and kernel diagnostic probe
  check | status       Comprehensive system, kernel, hardware, and services audit
  hardware             Enumerate and probe attached SDRs, modems, and SIM readers
  search <query>       Search installed 100 tools and desktop launchers by keyword
  docs                 Open offline documentation & operator reference in browser
  sdr [action]         SDR drivers, USB & 10GbE management (status | usb | 10g | firmware)
  usb                  Alias for 'sdr usb' (USBFS buffer tuning; bash CLI parity)
  oran [action]        O-RAN Alliance security suite (status | e2-sim | o1-scan)
  sbi [action]         5G Core Service-Based Interface auditing (status | validate | fuzz)
  ntn [action]         Non-Terrestrial Networks & Satellite telecom (status | doppler)
  10g [action]         10Gbps network SDR interface optimization (status | tune | setup | probe)
  firmware             Inspect and manage offline SDR FPGA bitstreams (BladeRF, USRP)
  update-assets [grp]  Inspect and synchronize offline FPGA images, specs, and wordlists
  bundle-evidence [tag] Package captures, crash dumps, and system telemetry into signed archive
  profile [mode]       Switch operational profiles (lab | field | status)
  pkg [action]         Official metapackage manager (list | info | install | remove | check | repo)
  sim [action]         Smartcard, SIM & eSIM auditing (status | readers | atr | trace | lpac | shell)
  5g-sa <action>       5G Standalone core & RAN manager (start | stop | status | add-sub)
  scan <protocol>      Interactive protocol assessment wizard (sctp | sip | asleap)
  academy              Access TelcoSec Academy interactive labs & credentials
  feedback             Community support channels & SourceForge review portal
  completion [shell]   Generate shell autocompletion script (bash | zsh | fish)
  version              Show TelcoChiselOS release version and kernel details

Run 'telcosec <command> --help' for command-specific options.
`)
}

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(0)
	}

	cmd := strings.ToLower(os.Args[1])
	args := os.Args[2:]

	switch cmd {
	case "doctor", "dr":
		printBanner()
		doctor.RunDoctor(os.Stdout)

	case "oran", "openran", "e2":
		action := "status"
		if len(args) > 0 {
			action = strings.ToLower(args[0])
		}
		switch action {
		case "status":
			printBanner()
			oran.PrintStatus(os.Stdout)
		case "e2-sim", "e2sim", "sim":
			printBanner()
			ricIP := "127.0.0.1"
			if len(args) > 1 {
				ricIP = args[1]
			}
			cfg := oran.E2SimConfig{
				RicIP:        ricIP,
				RicPort:      36421,
				ServiceModel: "kpm",
			}
			_ = oran.RunE2Sim(os.Stdout, cfg)
		case "o1-scan", "o1", "scan":
			printBanner()
			target := "127.0.0.1"
			if len(args) > 1 {
				target = args[1]
			}
			oran.RunO1Scan(os.Stdout, target, 830)
		default:
			fmt.Printf("Unknown O-RAN action: %s\nUsage: telcosec oran [status|e2-sim [ric_ip]|o1-scan [target]]\n", action)
			os.Exit(1)
		}

	case "sbi", "sba", "5g-sbi":
		action := "status"
		if len(args) > 0 {
			action = strings.ToLower(args[0])
		}
		switch action {
		case "status":
			printBanner()
			sbi.PrintStatus(os.Stdout)
		case "validate", "check":
			printBanner()
			endpoint := "http://127.0.0.1:7777"
			nf := "nrf"
			if len(args) > 1 {
				endpoint = args[1]
			}
			if len(args) > 2 {
				nf = args[2]
			}
			sbi.ValidateEndpoint(os.Stdout, endpoint, nf)
		case "fuzz", "mutate":
			printBanner()
			target := "http://127.0.0.1:7777"
			nf := "nrf"
			if len(args) > 1 {
				target = args[1]
			}
			if len(args) > 2 {
				nf = args[2]
			}
			_ = sbi.RunFuzzer(os.Stdout, target, nf)
		default:
			fmt.Printf("Unknown SBI action: %s\nUsage: telcosec sbi [status|validate [endpoint] [nf]|fuzz [target] [nf]]\n", action)
			os.Exit(1)
		}

	case "ntn", "sat", "satellite":
		action := "status"
		if len(args) > 0 {
			action = strings.ToLower(args[0])
		}
		switch action {
		case "status":
			printBanner()
			ntn.PrintStatus(os.Stdout)
		case "doppler", "calc":
			printBanner()
			orbit := "leo"
			if len(args) > 1 {
				orbit = args[1]
			}
			ntn.CalculateDoppler(os.Stdout, 1621.25e6, orbit)
		default:
			fmt.Printf("Unknown NTN action: %s\nUsage: telcosec ntn [status|doppler [leo|meo|geo]]\n", action)
			os.Exit(1)
		}

	case "update-assets", "assets", "update-wordlists":
		printBanner()
		if len(args) > 0 && (args[0] == "update" || args[0] == "sync" || args[0] == "download") {
			target := ""
			if len(args) > 1 {
				target = args[1]
			}
			_ = assets.UpdateAsset(os.Stdout, target)
		} else {
			statuses := assets.CheckAssets()
			assets.PrintAssetReport(os.Stdout, statuses)
			fmt.Println("Tip: Run 'telcosec update-assets update [group]' to synchronize offline assets.")
		}

	case "bundle-evidence", "evidence", "collect-evidence":
		printBanner()
		label := ""
		if len(args) > 0 {
			label = args[0]
		}
		cfg := evidence.BundleConfig{
			OutputDir:   "/var/log/telcosec/captures",
			IncludePCAP: true,
			IncludeLogs: true,
			Label:       label,
		}
		_, _ = evidence.CreateEvidenceBundle(os.Stdout, cfg)

	case "check", "status":
		printBanner()
		telemetry.RunAudit(os.Stdout)

	case "hardware", "hw", "devices":
		printBanner()
		sdr.ProbeHardware(os.Stdout)

	case "search", "find":
		if len(args) == 0 {
			fmt.Println("Usage: telcosec search <tool_name_or_keyword>")
			os.Exit(1)
		}
		query := strings.Join(args, " ")
		printBanner()
		tools, err := search.SearchTools(query, nil)
		if err != nil {
			fmt.Printf("Search failed: %v\n", err)
			os.Exit(1)
		}
		search.PrintResults(os.Stdout, query, tools)

	case "docs", "doc", "documentation":
		printBanner()
		docs.OpenDocs(os.Stdout)

	case "sdr":
		action := "status"
		if len(args) > 0 {
			action = strings.ToLower(args[0])
		}
		switch action {
		case "status":
			printBanner()
			fmt.Printf("%s=== Attached USB SDR Devices ===%s\n", telemetry.Bold, telemetry.Reset)
			devs := sdr.DetectUSBSDRs()
			if len(devs) == 0 {
				fmt.Printf("  %sNo USB SDR transceivers detected.%s\n", telemetry.Yellow, telemetry.Reset)
			} else {
				for _, d := range devs {
					fmt.Printf("  %s%-32s%s [USB ID: %s:%s]\n", telemetry.Green, d.Model, telemetry.Reset, d.VendorID, d.ProductID)
				}
			}

			fmt.Printf("\n%s=== Serial AT Cellular Modems ===%s\n", telemetry.Bold, telemetry.Reset)
			modems := sdr.DetectSerialModems()
			if len(modems) == 0 {
				fmt.Printf("  %sNo serial modems detected in /dev.%s\n", telemetry.Yellow, telemetry.Reset)
			} else {
				fmt.Printf("  %sFound %d modem(s): %s%s\n", telemetry.Green, len(modems), strings.Join(modems, " "), telemetry.Reset)
			}
			fmt.Println()

		case "usb":
			printBanner()
			mb := telemetry.GetUSBFSMemoryMB()
			fmt.Printf("%s=== USB Transceiver Buffer Tuning ===%s\n", telemetry.Bold, telemetry.Reset)
			if mb >= 500 {
				fmt.Printf("  usbfs_memory_mb = %s%d MB%s (Optimized for continuous high MSPS)\n\n", telemetry.Green, mb, telemetry.Reset)
			} else {
				fmt.Printf("  usbfs_memory_mb = %s%d MB%s (Recommends 1000 MB)\n", telemetry.Yellow, mb, telemetry.Reset)
				fmt.Println("  To optimize: sudo sh -c 'echo 1000 > /sys/module/usbcore/parameters/usbfs_memory_mb'")
				fmt.Println()
			}

		case "10g", "10gbe", "network":
			subArgs := args[1:]
			handle10GCommand(subArgs)

		case "firmware", "bitstreams":
			sdr.InspectBitstreams(os.Stdout)

		default:
			fmt.Printf("Unknown SDR action: %s\nUsage: telcosec sdr [status|usb|10g|firmware]\n", action)
			os.Exit(1)
		}

	case "usb":
		// Bash CLI parity: `telcosec usb` → same as `telcosec sdr usb`
		printBanner()
		mb := telemetry.GetUSBFSMemoryMB()
		fmt.Printf("%s=== USB Transceiver Buffer Tuning ===%s\n", telemetry.Bold, telemetry.Reset)
		if mb >= 500 {
			fmt.Printf("  usbfs_memory_mb = %s%d MB%s (Optimized for continuous high MSPS)\n\n", telemetry.Green, mb, telemetry.Reset)
		} else {
			fmt.Printf("  usbfs_memory_mb = %s%d MB%s (Recommends 1000 MB)\n", telemetry.Yellow, mb, telemetry.Reset)
			fmt.Println("  To optimize: sudo sh -c 'echo 1000 > /sys/module/usbcore/parameters/usbfs_memory_mb'")
			fmt.Println()
		}

	case "10g", "10gbe", "network":
		handle10GCommand(args)

	case "firmware":
		printBanner()
		sdr.InspectBitstreams(os.Stdout)

	case "profile":
		mode := "status"
		if len(args) > 0 {
			mode = strings.ToLower(args[0])
		}
		if p, err := exec.LookPath("telcosec-profile"); err == nil {
			cmd := exec.Command(p, args...)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			_ = cmd.Run()
		} else {
			printBanner()
			curMode, desc := telemetry.GetProfileMode()
			if mode == "status" {
				fmt.Printf("Active Profile Mode: %s\n", desc)
			} else if mode == "lab" {
				fmt.Println("Switching to Lab Mode (unrestricted packet crafting, rp_filter=0)...")
				_ = exec.Command("sudo", "sysctl", "-w", "net.ipv4.conf.all.rp_filter=0").Run()
				fmt.Printf("Profile switched: %s\n", curMode)
			} else if mode == "field" {
				fmt.Println("Switching to Field Mode (strict reverse path filtering, rp_filter=1)...")
				_ = exec.Command("sudo", "sysctl", "-w", "net.ipv4.conf.all.rp_filter=1").Run()
				fmt.Printf("Profile switched: %s\n", curMode)
			}
		}

	case "pkg", "package", "packages":
		handlePkgCommand(args)

	case "sim", "smartcard", "esim":
		handleSimCommand(args)

	case "5g", "5g-sa", "5gsa":
		action := "status"
		if len(args) > 0 {
			action = strings.ToLower(args[0])
		}
		switch action {
		case "start":
			_ = cellular.StartCore(os.Stdout)
		case "stop":
			_ = cellular.StopCore(os.Stdout)
		case "status":
			_ = cellular.StatusCore(os.Stdout)
		case "add-sub":
			imsi := ""
			k := ""
			opc := ""
			if len(args) > 1 {
				imsi = args[1]
			}
			if len(args) > 2 {
				k = args[2]
			}
			if len(args) > 3 {
				opc = args[3]
			}
			_ = cellular.AddSubscriber(os.Stdout, imsi, k, opc)
		default:
			fmt.Println("Usage: telcosec 5g-sa {start|stop|status|add-sub [imsi] [k] [opc]}")
			os.Exit(1)
		}

	case "scan":
		if len(args) == 0 {
			fmt.Println("Usage: telcosec scan {sctp|sip|asleap} [target options]")
			os.Exit(1)
		}
		proto := strings.ToLower(args[0])
		protoArgs := args[1:]
		switch proto {
		case "sctp":
			fmt.Printf("%s=== SCTP Signaling Scanner (sctpscan) ===%s\n", telemetry.Bold, telemetry.Reset)
			if bin, err := exec.LookPath("sctpscan"); err == nil {
				cmd := exec.Command(bin, protoArgs...)
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				cmd.Stdin = os.Stdin
				_ = cmd.Run()
			} else {
				fmt.Println("sctpscan not found on system.")
			}
		case "sip":
			fmt.Printf("%s=== SIP Scanner (SIPVicious) ===%s\n", telemetry.Bold, telemetry.Reset)
			bin := "sipvicious_svmap"
			if p, err := exec.LookPath("sipvicious_svmap"); err == nil {
				bin = p
			} else if p, err := exec.LookPath("svmap"); err == nil {
				bin = p
			} else {
				fmt.Println("SIPVicious svmap not found on system.")
				return
			}
			cmd := exec.Command(bin, protoArgs...)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			cmd.Stdin = os.Stdin
			_ = cmd.Run()
		case "asleap":
			fmt.Printf("%s=== Asleap PPPoE / MS-CHAPv2 Cracker ===%s\n", telemetry.Bold, telemetry.Reset)
			if bin, err := exec.LookPath("asleap"); err == nil {
				cmd := exec.Command(bin, protoArgs...)
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				cmd.Stdin = os.Stdin
				_ = cmd.Run()
			} else {
				fmt.Println("asleap not found on system.")
			}
		default:
			fmt.Println("Usage: telcosec scan {sctp|sip|asleap} [target options]")
		}

	case "academy":
		docs.OpenAcademy(os.Stdout)

	case "feedback", "review", "reviews":
		docs.OpenFeedback(os.Stdout)

	case "completion":
		shell := "bash"
		if len(args) > 0 {
			shell = args[0]
		}
		if err := completions.GenerateCompletion(shell, os.Stdout); err != nil {
			fmt.Printf("Error: %v\n", err)
			os.Exit(1)
		}

	case "version", "-v", "--version":
		kver, _ := telemetry.GetKernelVersion()
		fmt.Printf("TelcoSec Unified Operator CLI v%s (%s, built %s)\n", Version, GitCommit, BuildDate)
		fmt.Printf("Platform: Linux (%s)\n", kver)

	case "help", "-h", "--help":
		printUsage()

	default:
		fmt.Printf("Unknown command: %s\n\n", cmd)
		printUsage()
		os.Exit(1)
	}
}

func handle10GCommand(args []string) {
	action := "status"
	if len(args) > 0 {
		action = strings.ToLower(args[0])
	}

	switch action {
	case "status":
		printBanner()
		network.PrintStatus(os.Stdout)

	case "tune":
		if len(args) < 2 {
			fmt.Println("Usage: telcosec 10g tune <interface_name>")
			os.Exit(1)
		}
		iface := args[1]
		_ = network.TuneInterface(os.Stdout, iface)

	case "setup":
		if len(args) < 2 {
			fmt.Println("Usage: telcosec 10g setup <interface_name> [preset: x310-0|x310-1|n310-0|n310-1]")
			os.Exit(1)
		}
		iface := args[1]
		preset := "x310-0"
		if len(args) > 2 {
			preset = args[2]
		}
		_ = network.SetupInterface(os.Stdout, iface, preset)

	case "probe":
		ip := ""
		if len(args) > 1 {
			ip = args[1]
		}
		printBanner()
		network.ProbeNetwork(os.Stdout, ip)

	default:
		fmt.Printf("Unknown 10G action: %s\nUsage: telcosec 10g [status|tune|setup|probe]\n", action)
		os.Exit(1)
	}
}

func handlePkgCommand(args []string) {
	action := "list"
	if len(args) > 0 {
		action = strings.ToLower(args[0])
	}

	switch action {
	case "list", "ls":
		jsonOutput := false
		for _, arg := range args[1:] {
			if arg == "--json" || arg == "-j" {
				jsonOutput = true
			}
		}
		if !jsonOutput {
			printBanner()
		}
		_ = packages.ListPackages(os.Stdout, jsonOutput)

	case "info", "show":
		if len(args) < 2 {
			fmt.Println("Usage: telcosec pkg info <suite_alias_or_name>")
			fmt.Println("Example: telcosec pkg info 5g")
			os.Exit(1)
		}
		printBanner()
		if err := packages.ShowInfo(os.Stdout, args[1]); err != nil {
			fmt.Printf("Error: %v\n", err)
			os.Exit(1)
		}

	case "install", "add":
		if len(args) < 2 {
			fmt.Println("Usage: telcosec pkg install <suite_alias_or_name>")
			fmt.Println("Example: telcosec pkg install 5g")
			os.Exit(1)
		}
		printBanner()
		if err := packages.InstallPackage(os.Stdout, args[1]); err != nil {
			fmt.Printf("Installation error: %v\n", err)
			os.Exit(1)
		}

	case "remove", "purge", "del", "rm":
		if len(args) < 2 {
			fmt.Println("Usage: telcosec pkg remove <suite_alias_or_name>")
			fmt.Println("Example: telcosec pkg remove 5g")
			os.Exit(1)
		}
		printBanner()
		if err := packages.RemovePackage(os.Stdout, args[1]); err != nil {
			fmt.Printf("Removal error: %v\n", err)
			os.Exit(1)
		}

	case "check", "audit", "verify":
		printBanner()
		_ = packages.AuditPackages(os.Stdout)

	case "repo":
		subAction := "status"
		if len(args) > 1 {
			subAction = strings.ToLower(args[1])
		}
		printBanner()
		switch subAction {
		case "status":
			_ = packages.RepoStatus(os.Stdout)
		case "enable":
			_ = packages.RepoEnable(os.Stdout)
		default:
			fmt.Printf("Unknown repo action: %s\nUsage: telcosec pkg repo [status|enable]\n", subAction)
			os.Exit(1)
		}

	default:
		// If argument directly matches a package alias/name, treat as info
		if p := packages.FindPackage(action); p != nil {
			printBanner()
			_ = packages.ShowInfo(os.Stdout, action)
			return
		}
		fmt.Printf("Unknown pkg action: %s\n\nUsage: telcosec pkg [list|info|install|remove|check|repo]\n", action)
		os.Exit(1)
	}
}

func handleSimCommand(args []string) {
	action := "status"
	if len(args) > 0 {
		action = strings.ToLower(args[0])
	}

	jsonOutput := false
	var filteredArgs []string
	for _, arg := range args {
		if arg == "--json" || arg == "-j" {
			jsonOutput = true
		} else {
			filteredArgs = append(filteredArgs, arg)
		}
	}

	switch action {
	case "status", "check":
		if !jsonOutput {
			printBanner()
		}
		_ = sim.PrintEnvironmentStatus(os.Stdout, jsonOutput)

	case "readers", "reader", "list", "ls":
		if !jsonOutput {
			printBanner()
		}
		_ = sim.PrintReaders(os.Stdout, jsonOutput)

	case "atr", "decode":
		if !jsonOutput {
			printBanner()
		}
		atrHex := ""
		if len(filteredArgs) > 1 {
			atrHex = filteredArgs[1]
		}
		if atrHex == "" {
			fmt.Printf("%sPolling active smartcard from connected PC/SC reader...%s\n\n", sim.Dim, sim.Reset)
			activeATR, err := sim.GetActiveATR()
			if err != nil {
				fmt.Printf("%sError: %v%s\n\n", sim.Yellow, err, sim.Reset)
				fmt.Println("Tip: Insert a SIM card into an attached reader, or specify an ATR hex string:")
				fmt.Printf("     %stelcosec sim atr 3B9F95801FC78031E073FE211B674A4C7380110043%s\n\n", sim.Cyan, sim.Reset)
				os.Exit(1)
			}
			atrHex = activeATR
		}

		decoded, err := sim.DecodeATR(atrHex)
		if err != nil {
			fmt.Printf("ATR Decoding error: %v\n", err)
			os.Exit(1)
		}
		_ = sim.PrintATR(os.Stdout, decoded, jsonOutput)

	case "trace", "simtrace", "simtrace2":
		subAction := "list"
		if len(filteredArgs) > 1 {
			subAction = strings.ToLower(filteredArgs[1])
		}
		switch subAction {
		case "list", "status":
			if !jsonOutput {
				printBanner()
			}
			_ = sim.PrintSIMtraceStatus(os.Stdout, jsonOutput)
		case "sniff", "capture":
			printBanner()
			sniffArgs := []string{}
			if len(filteredArgs) > 2 {
				sniffArgs = filteredArgs[2:]
			}
			if err := sim.RunSniffer(os.Stdout, sniffArgs); err != nil {
				fmt.Printf("SIMtrace sniffer error: %v\n", err)
				os.Exit(1)
			}
		default:
			fmt.Printf("Unknown trace action: %s\nUsage: telcosec sim trace [list|sniff]\n", subAction)
			os.Exit(1)
		}

	case "lpac", "esim":
		subAction := "status"
		if len(filteredArgs) > 1 {
			subAction = strings.ToLower(filteredArgs[1])
		}
		if !jsonOutput {
			printBanner()
		}
		_ = sim.PrintLPACStatus(os.Stdout, subAction, jsonOutput)

	case "shell", "pysim":
		printBanner()
		shellArgs := []string{}
		if len(filteredArgs) > 1 {
			shellArgs = filteredArgs[1:]
		}
		if err := sim.LaunchPySimShell(os.Stdout, shellArgs); err != nil {
			fmt.Printf("pySim-shell error: %v\n", err)
			os.Exit(1)
		}

	default:
		// If argument looks like an ATR hex string (starts with 3b or 3f), decode directly
		if strings.HasPrefix(action, "3b") || strings.HasPrefix(action, "3f") {
			if !jsonOutput {
				printBanner()
			}
			decoded, err := sim.DecodeATR(action)
			if err != nil {
				fmt.Printf("ATR Decoding error: %v\n", err)
				os.Exit(1)
			}
			_ = sim.PrintATR(os.Stdout, decoded, jsonOutput)
			return
		}
		fmt.Printf("Unknown sim action: %s\n\nUsage: telcosec sim [status|readers|atr [hex]|trace [list|sniff]|lpac|shell]\n", action)
		os.Exit(1)
	}
}
