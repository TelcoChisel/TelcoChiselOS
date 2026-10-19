import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#0e121a"
    anchors.fill: parent

    // Animated background grid (telecom-style)
    Canvas {
        id: bgGrid
        anchors.fill: parent
        opacity: 0.08
        onPaint: {
            var ctx = getContext("2d");
            ctx.strokeStyle = "#00ffd5";
            ctx.lineWidth = 0.5;
            var step = 40;
            for (var x = 0; x < width; x += step) {
                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
            }
            for (var y = 0; y < height; y += step) {
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
            }
        }
    }

    // Animated glowing background orb
    Rectangle {
        id: glowOrb
        width: 360; height: 360
        radius: 180
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -30
        color: "transparent"
        border.color: "#00ffd5"
        border.width: 1
        opacity: 0.12

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 2500 }
            NumberAnimation { to: 0.08; duration: 2500 }
        }
    }

    // Carousel Data & Index
    property int currentSlide: 0

    Timer {
        interval: 7000
        running: true
        repeat: true
        onTriggered: {
            root.currentSlide = (root.currentSlide + 1) % 6;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 0

        // Header Brand Banner
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14

            Image {
                source: "logo.png"
                sourceSize.width: 44
                sourceSize.height: 44
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                spacing: 2
                Text {
                    text: "TELCOCHISEL OS"
                    color: "#00ffd5"
                    font.pixelSize: 22
                    font.bold: true
                    font.letterSpacing: 3
                }
                Text {
                    text: "Telecom Security & Cellular Red Team Workstation"
                    color: "#8b949e"
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }
            }
        }

        Item { height: 16 }

        // Separator Line
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: parent.width * 0.85
            height: 1
            color: "#21262d"
        }

        Item { Layout.fillHeight: true }

        // Slide Container with Fade Transitions
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 280

            // Slide 1: Welcome & OS Vision
            Item {
                anchors.fill: parent
                opacity: root.currentSlide === 0 ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 500 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "TelcoChisel OS 2026.2 (Noble Cellular)"
                        color: "#00ffd5"
                        font.pixelSize: 22
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Ubuntu 24.04 LTS • Linux Real-Time Kernel (1000Hz PREEMPT) • Dual Desktop (XFCE + i3 RFS Style)"
                        color: "#e6edf3"
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { height: 6 }

                    Text {
                        text: "• Curated arsenal of 100 specialized telecom security instruments across 11 domains\n• Out-of-the-box hardware integration for USRP, BladeRF, LimeSDR, HackRF, SIMtrace2 & PCSC\n• Flagship Field Edition (5.5 GB full offline) & Modular Lite Edition (1.8 GB on-demand)"
                        color: "#8b949e"
                        font.pixelSize: 12
                        lineHeight: 1.5
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // Slide 2: Software Defined Radio (SDR) & RF DSP
            Item {
                anchors.fill: parent
                opacity: root.currentSlide === 1 ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 500 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "Software Defined Radio & RF Signal Processing"
                        color: "#00ffd5"
                        font.pixelSize: 22
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "GNU Radio 3.10 • UHD • SoapySDR • LimeSuite • Gqrx • Inspectrum • URH • gr-gsm"
                        color: "#e6edf3"
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { height: 6 }

                    Text {
                        text: "• Dedicated telcosec-sdr Conda environment with ABI-shielded Python bindings\n• Real-time tuned kernel profile with 1000MB USBFS allocation and zero-drop USB\n• Pre-compiled FPGA bitstreams & automated driver udev permissions for non-root users"
                        color: "#8b949e"
                        font.pixelSize: 12
                        lineHeight: 1.5
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // Slide 3: 4G/5G RAN & Core Network Simulation
            Item {
                anchors.fill: parent
                opacity: root.currentSlide === 2 ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 500 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "4G LTE & 5G Standalone (SA) Core Simulation"
                        color: "#00ffd5"
                        font.pixelSize: 22
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Open5GS 2.7 • UERANSIM • srsRAN 4G/5G • Falcon LTE • 5Ghoul Fuzzer • my5G-RANTester"
                        color: "#e6edf3"
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { height: 6 }

                    Text {
                        text: "• End-to-end 5G Standalone (SA) core network pre-configured for instant deployment\n• High-concurrency gNodeB / UE emulation with multi-SIM traffic injection\n• Over-the-air 5G NR baseband fuzzing & Falcon LTE security analysis"
                        color: "#8b949e"
                        font.pixelSize: 12
                        lineHeight: 1.5
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // Slide 4: Baseband Emulation & SIM Smartcard Auditing
            Item {
                anchors.fill: parent
                opacity: root.currentSlide === 3 ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 500 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "Baseband Security & SIM/eSIM Auditing"
                        color: "#00ffd5"
                        font.pixelSize: 22
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "FirmWire • QCSuper • SCAT • pySim-shell • Osmocom SIMtrace 2 • lpac (eSIM)"
                        color: "#e6edf3"
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { height: 6 }

                    Text {
                        text: "• QEMU-based firmware emulation for Shannon & MediaTek modem basebands\n• Live ISO-7816 APDU trace sniffing with Sysmocom SIMtrace 2 & software UICC simulation\n• GSMA SGP.22 eSIM Local Profile Assistant (lpac) profile download and management"
                        color: "#8b949e"
                        font.pixelSize: 12
                        lineHeight: 1.5
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // Slide 5: Core Signaling & Protocol Security
            Item {
                anchors.fill: parent
                opacity: root.currentSlide === 4 ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 500 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "Signaling Protocols, Dissection & Exploitation"
                        color: "#00ffd5"
                        font.pixelSize: 22
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Wireshark 4.2+ (GSMTAP & 5G SBI) • SigPloit • DiaFuzzer • sctpscan • SIPVicious • Scapy"
                        color: "#e6edf3"
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { height: 6 }

                    Text {
                        text: "• Pre-loaded GSMTAP, GSMTAPv3, and 3GPP Release 17 OpenAPI YAML SBI dissectors\n• SS7, Diameter, GTP, SCTP, and SIP/VoIP vulnerability assessment & packet crafting\n• Specialized suites: sctpscan, SIPVicious, RTPBleed, Mausezahn & VoIP Hopper"
                        color: "#8b949e"
                        font.pixelSize: 12
                        lineHeight: 1.5
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // Slide 6: Modular Metapackages & Ecosystem
            Item {
                anchors.fill: parent
                opacity: root.currentSlide === 5 ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 500 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "Modular Metapackages & Ecosystem"
                        color: "#00ffd5"
                        font.pixelSize: 22
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "telcosec-pkg CLI • meta.telcochisel.com • 10 Metapackages • telcochisel.com"
                        color: "#e6edf3"
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { height: 6 }

                    Text {
                        text: "• Install specialized domains on-demand: 5g, sdr, sim, 4g, 2g-3g, core, voip, wireline, ue, full\n• Dedicated telcosec CLI for live SDR diagnostics, hardware probing, and 5G core control\n• Community support, documentation, and training at telcochisel.com"
                        color: "#8b949e"
                        font.pixelSize: 12
                        lineHeight: 1.5
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Slide Indicator Dots
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Repeater {
                model: 6
                Rectangle {
                    width: index === root.currentSlide ? 24 : 8
                    height: 8
                    radius: 4
                    color: index === root.currentSlide ? "#00ffd5" : "#21262d"
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
        }

        Item { height: 16 }

        // Installation Progress Message
        Text {
            id: progressMsg
            Layout.alignment: Qt.AlignHCenter
            text: "Installing TelcoChisel OS to disk..."
            color: "#e8921e"
            font.pixelSize: 13
            opacity: 0.9

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 1500 }
                NumberAnimation { to: 0.95; duration: 1500 }
            }
        }

        Item { height: 8 }
    }
}
