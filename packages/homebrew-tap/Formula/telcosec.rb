# typed: false
# frozen_string_literal: true

class Telcosec < Formula
  desc "Unified CLI for Telecom Security, SDR Diagnostics, and 5G SA Operations"
  homepage "https://telcochisel.com"
  url "https://github.com/TelcoChisel/telcosec-cli/archive/refs/tags/v3.0.0.tar.gz"
  sha256 "58aa6370029671f3924aa75410e95bd01670b60b50cf5c0e7b95c55d80dcb1af"
  license "Apache-2.0"
  head "https://github.com/TelcoChisel/telcosec-cli.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    commit = build.head? ? Utils.git_short_head : "homebrew"
    build_date = time.iso8601
    ldflags = %W[
      -s -w
      -X main.Version=#{version}
      -X main.GitCommit=#{commit}
      -X main.BuildDate=#{build_date}
    ]

    system "go", "build", *std_go_args(ldflags: ldflags, output: bin/"telcosec"), "./cmd/telcosec"

    # Install symlink alias telcochisel -> telcosec
    bin.install_symlink "telcosec" => "telcochisel"

    # Install shell completions
    bash_completion.install "completions/telcosec.bash" => "telcosec"
    zsh_completion.install "completions/_telcosec" => "_telcosec"
    fish_completion.install "completions/telcosec.fish" => "telcosec.fish"

    # Install Section 1 UNIX manual pages
    man1.install "docs/man/telcosec.1"
    man1.install_symlink "telcosec.1" => "telcochisel.1"
  end

  test do
    assert_match "TelcoSec Unified Operator CLI", shell_output("#{bin}/telcosec version")
    assert_match "Usage:", shell_output("#{bin}/telcosec help")
  end
end
