package packages

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"
)

func TestCanonicalRegistryIntegrity(t *testing.T) {
	if len(CanonicalRegistry) != 10 {
		t.Fatalf("expected 10 canonical metapackages, got %d", len(CanonicalRegistry))
	}

	seenNames := make(map[string]bool)
	seenAliases := make(map[string]bool)

	for _, p := range CanonicalRegistry {
		if p.Name == "" {
			t.Errorf("metapackage has empty name: %+v", p)
		}
		if seenNames[p.Name] {
			t.Errorf("duplicate package name: %s", p.Name)
		}
		seenNames[p.Name] = true

		if p.Alias == "" {
			t.Errorf("metapackage %s has empty alias", p.Name)
		}
		if seenAliases[p.Alias] {
			t.Errorf("duplicate alias: %s", p.Alias)
		}
		seenAliases[p.Alias] = true

		if p.Category == "" {
			t.Errorf("metapackage %s has empty category", p.Name)
		}
		if p.Description == "" {
			t.Errorf("metapackage %s has empty description", p.Name)
		}
		if len(p.Tools) == 0 {
			t.Errorf("metapackage %s has no tools registered", p.Name)
		}
	}
}

func TestFindPackage(t *testing.T) {
	tests := []struct {
		query    string
		expected string
	}{
		{"5g", "telcochisel-tools-5g"},
		{"telcochisel-tools-5g", "telcochisel-tools-5g"},
		{"5G", "telcochisel-tools-5g"},
		{"sdr", "telcochisel-tools-sdr"},
		{"rf", "telcochisel-tools-sdr"},
		{"dsp", "telcochisel-tools-sdr"},
		{"wireline", "telcochisel-tools-pstn-adsl"},
		{"pstn", "telcochisel-tools-pstn-adsl"},
		{"hardware", "telcochisel-hardware-sdr"},
		{"hw", "telcochisel-hardware-sdr"},
		{"sim", "telcochisel-tools-sim"},
		{"smartcard", "telcochisel-tools-sim"},
		{"full", "telcochisel-meta-full"},
		{"base", "telcochisel-base"},
		{"ue", "telcochisel-tools-ue"},
		{"baseband", "telcochisel-tools-ue"},
		{"nonexistent-suite-xyz", ""},
		{"", ""},
	}

	for _, tc := range tests {
		res := FindPackage(tc.query)
		if tc.expected == "" {
			if res != nil {
				t.Errorf("FindPackage(%q) expected nil, got %s", tc.query, res.Name)
			}
		} else {
			if res == nil {
				t.Errorf("FindPackage(%q) expected %s, got nil", tc.query, tc.expected)
			} else if res.Name != tc.expected {
				t.Errorf("FindPackage(%q) expected %s, got %s", tc.query, tc.expected, res.Name)
			}
		}
	}
}

func TestListPackages(t *testing.T) {
	// Text output
	var buf bytes.Buffer
	if err := ListPackages(&buf, false); err != nil {
		t.Fatalf("ListPackages(text) failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, "telcochisel-tools-5g") {
		t.Errorf("ListPackages text missing 5g suite")
	}
	if !strings.Contains(out, "telcochisel-base") {
		t.Errorf("ListPackages text missing base suite")
	}

	// JSON output
	var jsonBuf bytes.Buffer
	if err := ListPackages(&jsonBuf, true); err != nil {
		t.Fatalf("ListPackages(json) failed: %v", err)
	}

	var parsed []PackageStatusInfo
	if err := json.Unmarshal(jsonBuf.Bytes(), &parsed); err != nil {
		t.Fatalf("failed to unmarshal JSON output: %v", err)
	}

	if len(parsed) != 10 {
		t.Fatalf("expected 10 parsed packages in JSON, got %d", len(parsed))
	}
}

func TestShowInfo(t *testing.T) {
	var buf bytes.Buffer
	if err := ShowInfo(&buf, "5g"); err != nil {
		t.Fatalf("ShowInfo('5g') failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, "Open5GS 5G Core Network") {
		t.Errorf("ShowInfo('5g') missing tool component")
	}
	if !strings.Contains(out, "telcochisel-tools-5g") {
		t.Errorf("ShowInfo('5g') missing package name")
	}

	// Unknown query
	if err := ShowInfo(&buf, "invalid-query"); err == nil {
		t.Errorf("ShowInfo('invalid-query') expected error, got nil")
	}
}

func TestAuditPackages(t *testing.T) {
	var buf bytes.Buffer
	if err := AuditPackages(&buf); err != nil {
		t.Fatalf("AuditPackages failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, "Metapackage System Audit") {
		t.Errorf("AuditPackages output missing header")
	}
}

func TestOfficialRepoKeyFingerprintPinned(t *testing.T) {
	if OfficialRepoKeyFingerprint != "6326A34C15FEF05FBD63518B4325182E2F0D9DB9" {
		t.Fatalf("unexpected OfficialRepoKeyFingerprint: %s", OfficialRepoKeyFingerprint)
	}
	if OfficialRepoURL != "https://meta.telcosec.net" {
		t.Fatalf("unexpected OfficialRepoURL: %s", OfficialRepoURL)
	}
}

func TestParseGPGColonFingerprint(t *testing.T) {
	sample := "pub:u:4096:1:ABCDEF:...\nfpr:::::::::6326A34C15FEF05FBD63518B4325182E2F0D9DB9:\nuid:..."
	got := parseGPGColonFingerprint(sample)
	if got != OfficialRepoKeyFingerprint {
		t.Fatalf("parseGPGColonFingerprint = %q, want %q", got, OfficialRepoKeyFingerprint)
	}
	if parseGPGColonFingerprint("no fingerprint here") != "" {
		t.Fatal("expected empty fingerprint for garbage input")
	}
}
