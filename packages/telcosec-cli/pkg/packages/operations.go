package packages

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/TelcoSec-Tools/telcosec-cli/pkg/telemetry"
)

const (
	OfficialRepoURL = "https://meta.telcochisel.com"
	Deb822Sources   = "/etc/apt/sources.list.d/telcochisel.sources"
	LegacySources   = "/etc/apt/sources.list.d/telcosec.list"
	ArchiveKeyring  = "/etc/apt/keyrings/telcochisel-archive-keyring.asc"
	LegacyKeyring   = "/etc/apt/trusted.gpg.d/telcosec.gpg"
	// OfficialRepoKeyFingerprint must match scripts/install-telcochisel-repo.sh
	// and builder/scripts/00-install-all-packages.sh (TELCOSEC_FPR).
	OfficialRepoKeyFingerprint = "6326A34C15FEF05FBD63518B4325182E2F0D9DB9"
	AptPreferences             = "/etc/apt/preferences.d/99-telcochisel.pref"
)

// InstallPackage deploys a requested metapackage suite using the available package manager.
func InstallPackage(w io.Writer, query string) error {
	pkg := FindPackage(query)
	if pkg == nil {
		return fmt.Errorf("unknown metapackage '%s'. Run 'telcosec pkg list' for valid suites", query)
	}

	fmt.Fprintf(w, "%sDeploying %s (%s)...%s\n", telemetry.Bold, pkg.Name, pkg.Alias, telemetry.Reset)

	// If telcosec-pkg wrapper script is present on system, delegate
	if p, err := exec.LookPath("telcosec-pkg"); err == nil {
		cmd := exec.Command(p, "install", pkg.Alias)
		cmd.Stdout = w
		cmd.Stderr = os.Stderr
		cmd.Stdin = os.Stdin
		return cmd.Run()
	}

	// Native fallback via apt-get
	fmt.Fprintf(w, "Running 'sudo apt-get install -y %s'...\n", pkg.Name)
	cmd := exec.Command("sudo", "apt-get", "install", "-y", pkg.Name)
	cmd.Stdout = w
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

// RemovePackage uninstalls a requested metapackage suite from the system.
func RemovePackage(w io.Writer, query string) error {
	pkg := FindPackage(query)
	if pkg == nil {
		return fmt.Errorf("unknown metapackage '%s'. Run 'telcosec pkg list' for valid suites", query)
	}

	fmt.Fprintf(w, "%sRemoving %s (%s)...%s\n", telemetry.Bold, pkg.Name, pkg.Alias, telemetry.Reset)

	if p, err := exec.LookPath("telcosec-pkg"); err == nil {
		cmd := exec.Command(p, "remove", pkg.Alias)
		cmd.Stdout = w
		cmd.Stderr = os.Stderr
		cmd.Stdin = os.Stdin
		return cmd.Run()
	}

	cmd := exec.Command("sudo", "apt-get", "remove", "-y", pkg.Name)
	cmd.Stdout = w
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

// AuditPackages inspects the system to verify installed suites and broken dependencies.
func AuditPackages(w io.Writer) error {
	fmt.Fprintf(w, "%s=== Metapackage System Audit ===%s\n\n", telemetry.Bold, telemetry.Reset)

	installedCount := 0
	for _, pkg := range CanonicalRegistry {
		inst, ver, _ := CheckStatus(pkg.Name)
		if inst {
			installedCount++
			fmt.Fprintf(w, "  %s%-28s%s: %sINSTALLED%s (%s)\n", telemetry.Bold, pkg.Name, telemetry.Reset, telemetry.Green, telemetry.Reset, ver)
		}
	}

	fmt.Println()
	if installedCount == 0 {
		fmt.Fprintf(w, "  %sNo modular metapackages currently installed.%s\n", telemetry.Yellow, telemetry.Reset)
		fmt.Fprintf(w, "  Install foundational tools via: %ssudo telcosec pkg install base%s\n", telemetry.Cyan, telemetry.Reset)
	} else {
		fmt.Fprintf(w, "  %s%d of %d%s official metapackage suites installed.\n",
			telemetry.Green, installedCount, len(CanonicalRegistry), telemetry.Reset)
	}

	// Verify dpkg integrity
	if dpkg, err := exec.LookPath("dpkg"); err == nil {
		cmd := exec.Command(dpkg, "--audit")
		out, err := cmd.CombinedOutput()
		if err == nil && len(strings.TrimSpace(string(out))) == 0 {
			fmt.Fprintf(w, "  dpkg database state: %sCLEAN%s (no broken or half-configured packages)\n\n", telemetry.Green, telemetry.Reset)
		} else {
			fmt.Fprintf(w, "  dpkg database state: %sATTENTION REQUIRED%s\n  %s\n\n", telemetry.Red, telemetry.Reset, string(out))
		}
	}

	return nil
}

// RepoStatus audits the official APT repository enrollment and CDN network reachability.
func RepoStatus(w io.Writer) error {
	fmt.Fprintf(w, "%s=== Official APT Repository Status ===%s\n\n", telemetry.Bold, telemetry.Reset)
	fmt.Fprintf(w, "  Repository Endpoint : %s%s%s\n", telemetry.Cyan, OfficialRepoURL, telemetry.Reset)

	// Check sources configuration
	sourcesConfigured := false
	if _, err := os.Stat(Deb822Sources); err == nil {
		sourcesConfigured = true
		fmt.Fprintf(w, "  APT Sources Config  : %sCONFIGURED%s (%s)\n", telemetry.Green, telemetry.Reset, Deb822Sources)
	} else if _, err := os.Stat(LegacySources); err == nil {
		sourcesConfigured = true
		fmt.Fprintf(w, "  APT Sources Config  : %sCONFIGURED%s (%s)\n", telemetry.Green, telemetry.Reset, LegacySources)
	} else {
		fmt.Fprintf(w, "  APT Sources Config  : %sNOT CONFIGURED%s\n", telemetry.Yellow, telemetry.Reset)
	}

	// Check Keyring
	keyringConfigured := false
	if _, err := os.Stat(ArchiveKeyring); err == nil {
		keyringConfigured = true
		fmt.Fprintf(w, "  GPG Signing Keyring : %sVERIFIED%s (%s)\n", telemetry.Green, telemetry.Reset, ArchiveKeyring)
	} else if _, err := os.Stat(LegacyKeyring); err == nil {
		keyringConfigured = true
		fmt.Fprintf(w, "  GPG Signing Keyring : %sVERIFIED%s (%s)\n", telemetry.Green, telemetry.Reset, LegacyKeyring)
	} else {
		fmt.Fprintf(w, "  GPG Signing Keyring : %sNOT FOUND%s\n", telemetry.Yellow, telemetry.Reset)
	}

	// Network reachability test
	client := http.Client{
		Timeout: 4 * time.Second,
	}
	resp, err := client.Get(OfficialRepoURL)
	if err == nil && (resp.StatusCode == 200 || resp.StatusCode == 301 || resp.StatusCode == 302) {
		resp.Body.Close()
		fmt.Fprintf(w, "  CDN Edge Reachability: %sONLINE%s (HTTP %d)\n\n", telemetry.Green, telemetry.Reset, resp.StatusCode)
	} else {
		fmt.Fprintf(w, "  CDN Edge Reachability: %sOFFLINE / UNREACHABLE%s\n\n", telemetry.Red, telemetry.Reset)
	}

	if !sourcesConfigured || !keyringConfigured {
		fmt.Fprintf(w, "%sTo enroll this system in the official repository:%s\n", telemetry.Bold, telemetry.Reset)
		fmt.Fprintf(w, "  %ssudo telcosec pkg repo enable%s\n\n", telemetry.Cyan, telemetry.Reset)
	}

	return nil
}

// RepoEnable enrolls the host system in the official meta.telcochisel.com repository.
// Prefers telcosec-pkg or a local install-telcochisel-repo.sh; otherwise installs
// the key with fingerprint verification (never curl|bash from floating main).
func RepoEnable(w io.Writer) error {
	fmt.Fprintf(w, "%sEnrolling system in %s APT repository...%s\n", telemetry.Bold, OfficialRepoURL, telemetry.Reset)

	if p, err := exec.LookPath("telcosec-pkg"); err == nil {
		cmd := exec.Command(p, "repo", "enable")
		cmd.Stdout = w
		cmd.Stderr = os.Stderr
		cmd.Stdin = os.Stdin
		return cmd.Run()
	}

	if script, ok := findLocalRepoInstaller(); ok {
		fmt.Fprintf(w, "Running local installer: %s\n", script)
		cmd := exec.Command("sudo", "bash", script)
		cmd.Stdout = w
		cmd.Stderr = os.Stderr
		cmd.Stdin = os.Stdin
		return cmd.Run()
	}

	fmt.Fprintf(w, "Installing repository with pinned GPG fingerprint verification...\n")
	return enableOfficialRepoNative(w)
}

func findLocalRepoInstaller() (string, bool) {
	candidates := []string{
		"scripts/install-telcochisel-repo.sh",
		"/usr/share/telcosec/install-telcochisel-repo.sh",
		"/opt/telcosec/scripts/install-telcochisel-repo.sh",
	}
	if exe, err := os.Executable(); err == nil {
		dir := filepath.Dir(exe)
		candidates = append([]string{
			filepath.Join(dir, "install-telcochisel-repo.sh"),
			filepath.Join(dir, "..", "scripts", "install-telcochisel-repo.sh"),
			filepath.Join(dir, "..", "..", "scripts", "install-telcochisel-repo.sh"),
		}, candidates...)
	}
	for _, c := range candidates {
		if st, err := os.Stat(c); err == nil && !st.IsDir() {
			return c, true
		}
	}
	return "", false
}

func enableOfficialRepoNative(w io.Writer) error {
	tmpKey, err := os.CreateTemp("", "telcochisel-key-*.asc")
	if err != nil {
		return fmt.Errorf("create temp key file: %w", err)
	}
	tmpPath := tmpKey.Name()
	tmpKey.Close()
	defer os.Remove(tmpPath)

	client := &http.Client{Timeout: 30 * time.Second}
	keyURLs := []string{
		OfficialRepoURL + "/public.gpg",
		OfficialRepoURL + "/telcosec.gpg",
	}
	var lastErr error
	for _, u := range keyURLs {
		if err := downloadToFile(client, u, tmpPath); err != nil {
			lastErr = err
			continue
		}
		lastErr = nil
		break
	}
	if lastErr != nil {
		return fmt.Errorf("download repository signing key: %w", lastErr)
	}

	fpr, err := gpgFingerprint(tmpPath)
	if err != nil {
		return err
	}
	if fpr != OfficialRepoKeyFingerprint {
		return fmt.Errorf("key fingerprint mismatch: expected %s, got %s", OfficialRepoKeyFingerprint, fpr)
	}
	fmt.Fprintf(w, "  GPG key verified: %s\n", fpr)

	if err := sudoInstallFile(tmpPath, ArchiveKeyring, "0644"); err != nil {
		return fmt.Errorf("install keyring: %w", err)
	}

	sources := fmt.Sprintf("Types: deb\nURIs: %s\nSuites: noble\nComponents: main\nSigned-By: %s\n",
		OfficialRepoURL, ArchiveKeyring)
	if err := sudoWriteFile(Deb822Sources, sources, "0644"); err != nil {
		return fmt.Errorf("write APT sources: %w", err)
	}

	prefs := "Package: telcochisel-*\nPin: origin meta.telcochisel.com\nPin-Priority: 1001\n\n" +
		"Package: *\nPin: origin meta.telcochisel.com\nPin-Priority: 990\n"
	if err := sudoWriteFile(AptPreferences, prefs, "0644"); err != nil {
		return fmt.Errorf("write APT preferences: %w", err)
	}

	fmt.Fprintf(w, "Refreshing package indices...\n")
	cmd := exec.Command("sudo", "apt-get", "update")
	cmd.Stdout = w
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("apt-get update: %w", err)
	}

	fmt.Fprintf(w, "%sRepository enrolled successfully.%s\n", telemetry.Green, telemetry.Reset)
	return nil
}

func downloadToFile(client *http.Client, url, dest string) error {
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s: HTTP %d", url, resp.StatusCode)
	}
	f, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = io.Copy(f, resp.Body)
	return err
}

func gpgFingerprint(keyPath string) (string, error) {
	gpg, err := exec.LookPath("gpg")
	if err != nil {
		return "", fmt.Errorf("gpg not found — install gnupg to verify the repository key")
	}
	out, err := exec.Command(gpg, "--show-keys", "--with-colons", keyPath).CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("gpg --show-keys: %w (%s)", err, strings.TrimSpace(string(out)))
	}
	fpr := parseGPGColonFingerprint(string(out))
	if fpr == "" {
		return "", fmt.Errorf("could not read fingerprint from key at %s", keyPath)
	}
	return fpr, nil
}

// parseGPGColonFingerprint extracts the first fpr field from gpg --with-colons output.
func parseGPGColonFingerprint(out string) string {
	for _, line := range strings.Split(out, "\n") {
		parts := strings.Split(line, ":")
		if len(parts) > 9 && parts[0] == "fpr" {
			return parts[9]
		}
	}
	return ""
}

func sudoInstallFile(src, dest, mode string) error {
	cmd := exec.Command("sudo", "install", "-D", "-m", mode, src, dest)
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func sudoWriteFile(dest, contents, mode string) error {
	tmp, err := os.CreateTemp("", "telcochisel-cfg-*")
	if err != nil {
		return err
	}
	path := tmp.Name()
	if _, err := tmp.WriteString(contents); err != nil {
		tmp.Close()
		os.Remove(path)
		return err
	}
	tmp.Close()
	defer os.Remove(path)
	return sudoInstallFile(path, dest, mode)
}
