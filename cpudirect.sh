#!/usr/bin/env bash
# =============================================================================
# USB Latency Analyzer
# Count chips between your device and CPU. More chips = more latency.
#
# Shows USB topology from CPU's perspective:
#   CHIP 0 = direct to CPU
#   CHIP 1 = through chipset
#   CHIP 2+ = through hub(s)
#
# Device database sourced from Linux kernel xhci-pci.c + pci.ids repository.
# Requires: bash 4+, lspci (pciutils)
# =============================================================================

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "Error: Bash 4+ required (you have $BASH_VERSION)" >&2
    exit 1
fi

if ! command -v lspci &>/dev/null; then
    echo "Error: lspci not found. Install pciutils (e.g. sudo pacman -S pciutils)" >&2
    exit 1
fi

ESC=$'\e'
MINT="${ESC}[38;2;0;255;135m"
ORANGE="${ESC}[38;2;255;179;71m"
CORAL="${ESC}[38;2;255;107;107m"
SKY="${ESC}[38;2;135;206;235m"
DIM="${ESC}[38;2;108;108;108m"
BORDER="${ESC}[38;2;74;74;74m"
WHITE="${ESC}[97m"
BOLD="${ESC}[1m"
RESET="${ESC}[0m"

# =============================================================================
# FULL DEVICE ID DATABASE (from Linux kernel xhci-pci.c + pci.ids)
# Format: DB_<category>[<vid>:<did>]="<Name>|<Platform>|<USB>|<Year>"
# =============================================================================

declare -A INTEL_CPU_INTEGRATED=(
    ["8a13"]="Ice Lake Thunderbolt 3 USB Controller|Ice Lake (10th Gen)|USB 3.2/TB3|2019"
    ["9a13"]="Tiger Lake-LP Thunderbolt 4 USB Controller|Tiger Lake (11th Gen)|USB4/TB4|2020"
    ["9a17"]="Tiger Lake-H Thunderbolt 4 USB Controller|Tiger Lake-H (11th Gen)|USB4/TB4|2021"
    ["461e"]="Alder Lake-P Thunderbolt 4 USB Controller|Alder Lake (12th Gen)|USB4/TB4|2022"
    ["464e"]="Alder Lake-N Processor USB 3.2 xHCI Controller|Alder Lake-N|USB 3.2|2023"
    ["a71e"]="Raptor Lake-P Thunderbolt 4 USB Controller|Raptor Lake (13th Gen)|USB4/TB4|2023"
    ["7ec0"]="Meteor Lake-P Thunderbolt 4 USB Controller|Meteor Lake (Core Ultra)|USB4/TB4|2024"
    ["a831"]="Lunar Lake-M Thunderbolt 4 USB Controller|Lunar Lake|USB4/TB4|2024"
)

declare -A INTEL_PCH=(
    ["7f6e"]="800 Series PCH USB 3.1 xHCI HC|800 Series PCH|USB 3.1|2024"
    ["7a60"]="Raptor Lake USB 3.2 Gen 2x2 XHCI Host Controller|700 Series PCH|USB 3.2 Gen 2x2 (20Gbps)|2023"
    ["7a61"]="Raptor Lake USB 3.2 Gen 1x1 xDCI Device Controller|700 Series PCH|USB 3.2 Gen 1|2023"
    ["7ae0"]="Alder Lake-S PCH USB 3.2 Gen 2x2 XHCI Controller|600 Series PCH (Desktop)|USB 3.2 Gen 2x2 (20Gbps)|2021"
    ["51ed"]="Alder Lake PCH USB 3.2 xHCI Host Controller|600 Series PCH|USB 3.2|2022"
    ["54ed"]="Alder Lake-N PCH USB 3.2 Gen 2x1 xHCI Host Controller|Alder Lake-N PCH|USB 3.2 Gen 2 (10Gbps)|2023"
    ["7e7d"]="Meteor Lake-P USB 3.2 Gen 2x1 xHCI Host Controller|Meteor Lake PCH|USB 3.2 Gen 2|2024"
    ["777d"]="Arrow Lake USB 3.2 xHCI Controller|Arrow Lake|USB 3.2|2024"
    ["a87d"]="Lunar Lake-M USB 3.2 Gen 2x1 xHCI Host Controller|Lunar Lake PCH|USB 3.2 Gen 2|2024"
    ["a0ed"]="Tiger Lake-LP USB 3.2 Gen 2x1 xHCI Host Controller|500 Series PCH|USB 3.2 Gen 2 (10Gbps)|2020"
    ["43ed"]="Tiger Lake-H USB 3.2 Gen 2x1 xHCI Host Controller|500 Series PCH-H|USB 3.2 Gen 2|2021"
    ["a3af"]="Comet Lake PCH-V USB Controller|400 Series PCH|USB 3.1|2020"
    ["02ed"]="Comet Lake PCH-LP USB 3.1 xHCI Host Controller|400 Series PCH-LP|USB 3.1|2020"
    ["06ed"]="Comet Lake USB 3.1 xHCI Host Controller|400 Series PCH|USB 3.1|2020"
    ["a36d"]="Cannon Lake PCH USB 3.1 xHCI Host Controller|300 Series PCH|USB 3.1|2018"
    ["9ded"]="Cannon Point-LP USB 3.1 xHCI Controller|300 Series PCH-LP|USB 3.1|2018"
    ["a2af"]="200 Series/Z370 Chipset Family USB 3.0 xHCI Controller|200 Series PCH|USB 3.0|2017"
    ["a12f"]="100 Series/C230 Series Chipset Family USB 3.0 xHCI Controller|100 Series PCH|USB 3.0|2015"
    ["9d2f"]="Sunrise Point-LP USB 3.0 xHCI Controller|100 Series PCH-LP|USB 3.0|2015"
    ["8cb1"]="9 Series Chipset Family USB xHCI Controller|9 Series PCH|USB 3.0|2014"
    ["9cb1"]="Wildcat Point-LP USB xHCI Controller|9 Series PCH-LP|USB 3.0|2014"
    ["8c31"]="8 Series/C220 Series Chipset Family USB xHCI|8 Series PCH|USB 3.0|2013"
    ["9c31"]="8 Series USB xHCI HC|8 Series PCH-LP|USB 3.0|2013"
    ["1e31"]="7 Series/C210 Series Chipset Family USB xHCI Host Controller|7 Series PCH|USB 3.0|2012"
    ["8d31"]="C610/X99 series chipset USB xHCI Host Controller|X99/C610 (HEDT/Server)|USB 3.0|2014"
    ["a1af"]="C620 Series Chipset Family USB 3.0 xHCI Controller|C620 (Server)|USB 3.0|2017"
)

declare -A INTEL_THUNDERBOLT=(
    ["5782"]="JHL9580 Thunderbolt 5 USB Controller|Barlow Ridge Host 80G|USB4/TB5 (80Gbps)|2024"
    ["5785"]="JHL9540 Thunderbolt 4 USB Controller|Barlow Ridge Host 40G|USB4/TB4 (40Gbps)|2024"
    ["5787"]="JHL9480 Thunderbolt 5 USB Controller|Barlow Ridge Hub 80G|USB4/TB5 (80Gbps)|2024"
    ["57a5"]="JHL9440 Thunderbolt 4 USB Controller|Barlow Ridge Hub 40G|USB4/TB4 (40Gbps)|2024"
    ["1138"]="Thunderbolt 4 USB Controller [Maple Ridge 4C]|Maple Ridge 4C|USB4/TB4 (40Gbps)|2020"
    ["1135"]="Thunderbolt 4 USB Controller [Maple Ridge 2C]|Maple Ridge 2C|USB4/TB4 (40Gbps)|2020"
    ["0b27"]="Thunderbolt 4 USB Controller [Goshen Ridge]|Goshen Ridge|USB4/TB4 (40Gbps)|2020"
    ["15e9"]="JHL7540 Thunderbolt 3 USB Controller [Titan Ridge 2C]|Titan Ridge 2C|USB 3.1/TB3 (40Gbps)|2018"
    ["15ec"]="JHL7540 Thunderbolt 3 USB Controller [Titan Ridge 4C]|Titan Ridge 4C|USB 3.1/TB3 (40Gbps)|2018"
    ["15f0"]="JHL7440 Thunderbolt 3 USB Controller [Titan Ridge DD]|Titan Ridge DD|USB 3.1/TB3 (40Gbps)|2018"
    ["15b5"]="DSL6340 USB 3.1 Controller [Alpine Ridge 2C]|Alpine Ridge 2C|USB 3.1/TB3 (40Gbps)|2015"
    ["15b6"]="DSL6540 USB 3.1 Controller [Alpine Ridge 4C]|Alpine Ridge 4C|USB 3.1/TB3 (40Gbps)|2015"
    ["15c1"]="JHL6240 Thunderbolt 3 USB 3.1 Controller [Alpine Ridge LP]|Alpine Ridge LP|USB 3.1/TB3|2016"
    ["15d4"]="JHL6540 Thunderbolt 3 USB Controller [Alpine Ridge 4C]|Alpine Ridge 4C C-step|USB 3.1/TB3 (40Gbps)|2016"
    ["15db"]="JHL6340 Thunderbolt 3 USB 3.1 Controller [Alpine Ridge 2C]|Alpine Ridge 2C C-step|USB 3.1/TB3 (40Gbps)|2016"
)

declare -A AMD_CPU_INTEGRATED=(
    # Raphael / Granite Ridge (Ryzen 7000/9000)
    ["15b6"]="Raphael/Granite Ridge USB 3.1 xHCI|Ryzen 7000/9000 Desktop (AM5)|USB 3.1|2022"
    ["15b7"]="Raphael/Granite Ridge USB 3.1 xHCI|Ryzen 7000/9000 Desktop (AM5)|USB 3.1|2022"
    ["15b8"]="Raphael/Granite Ridge USB 2.0 xHCI|Ryzen 7000/9000 Desktop (AM5)|USB 2.0|2022"
    # Strix Halo (Zen 5)
    ["1587"]="Strix Halo USB 3.1 xHCI|Strix Halo (Zen 5)|USB 3.1|2024"
    ["1588"]="Strix Halo USB 3.1 xHCI|Strix Halo (Zen 5)|USB 3.1|2024"
    ["1589"]="Strix Halo USB 3.1 xHCI|Strix Halo (Zen 5)|USB 3.1|2024"
    ["158b"]="Strix Halo USB 3.1 xHCI|Strix Halo (Zen 5)|USB 3.1|2024"
    ["158d"]="Strix Halo USB4 Host Router|Strix Halo (Zen 5)|USB4|2024"
    ["158e"]="Strix Halo USB4 Host Router|Strix Halo (Zen 5)|USB4|2024"
    # Rembrandt (Ryzen 6000 Mobile)
    ["161a"]="Rembrandt USB4 XHCI controller|Ryzen 6000 Mobile (Zen 3+)|USB4|2022"
    ["161b"]="Rembrandt USB4 XHCI controller|Ryzen 6000 Mobile (Zen 3+)|USB4|2022"
    ["161c"]="Rembrandt USB4 XHCI controller|Ryzen 6000 Mobile (Zen 3+)|USB4|2022"
    ["161d"]="Rembrandt USB4 XHCI controller|Ryzen 6000 Mobile (Zen 3+)|USB4|2022"
    ["161e"]="Rembrandt USB4 XHCI controller|Ryzen 6000 Mobile (Zen 3+)|USB4|2022"
    ["161f"]="Rembrandt USB4 XHCI controller|Ryzen 6000 Mobile (Zen 3+)|USB4|2022"
    ["15d6"]="Rembrandt USB4 XHCI controller|Ryzen 6000 Mobile (Zen 3+)|USB4|2022"
    ["15d7"]="Rembrandt USB4 XHCI controller|Ryzen 6000 Mobile (Zen 3+)|USB4|2022"
    ["162e"]="Rembrandt USB4/Thunderbolt NHI controller|Ryzen 6000 Mobile (Zen 3+)|USB4/TB|2022"
    ["162f"]="Rembrandt USB4/Thunderbolt NHI controller|Ryzen 6000 Mobile (Zen 3+)|USB4/TB|2022"
    # Phoenix (Ryzen 7040)
    ["15c4"]="Phoenix USB4/Thunderbolt NHI controller|Ryzen 7040 Mobile (Zen 4)|USB4/TB|2023"
    ["15c5"]="Phoenix USB4/Thunderbolt NHI controller|Ryzen 7040 Mobile (Zen 4)|USB4/TB|2023"
    ["1668"]="Pink Sardine USB4/Thunderbolt NHI controller|Pink Sardine|USB4/TB|2023"
    ["1669"]="Pink Sardine USB4/Thunderbolt NHI controller|Pink Sardine|USB4/TB|2023"
    # Renoir / Cezanne (Ryzen 4000/5000 APU)
    ["1639"]="Renoir/Cezanne USB 3.1|Ryzen 4000/5000 APU (Zen 2/3)|USB 3.1|2020"
    # Raven Ridge / Picasso (Ryzen 2000/3000 APU)
    ["15e0"]="Raven USB 3.1|Ryzen 2000 APU (Zen)|USB 3.1|2018"
    ["15e1"]="Raven USB 3.1|Ryzen 2000 APU (Zen)|USB 3.1|2018"
    ["15e5"]="Raven2 USB 3.1|Ryzen 3000 APU (Zen+)|USB 3.1|2019"
    # Matisse / Vermeer (Ryzen 3000/5000 Desktop)
    ["149c"]="Matisse USB 3.0 Host Controller|Ryzen 3000/5000 Desktop (Zen 2/3)|USB 3.0|2019"
    ["148c"]="Starship USB 3.0 Host Controller|EPYC Rome / Threadripper 3rd Gen|USB 3.0|2019"
    # Zeppelin (Ryzen 1000)
    ["145f"]="Zeppelin USB 3.0 xHCI Compliant Host Controller|Ryzen 1000 (Zen)|USB 3.0|2017"
    ["145c"]="Family 17h USB 3.0 Host Controller|Ryzen 1000 (Zen)|USB 3.0|2017"
    # Van Gogh (Steam Deck)
    ["162c"]="VanGogh USB2|Steam Deck (Van Gogh)|USB 2.0|2022"
    ["163a"]="VanGogh USB0|Steam Deck (Van Gogh)|USB 3.1|2022"
    ["163b"]="VanGogh USB1|Steam Deck (Van Gogh)|USB 3.1|2022"
    # Other
    ["15d4"]="FireFlight USB 3.1|FireFlight|USB 3.1|2020"
    ["15d5"]="FireFlight USB 3.1|FireFlight|USB 3.1|2020"
    ["13ed"]="Ariel USB 3.1 Type C (Gen2 + DP Alt)|Ariel|USB 3.1 Gen 2|2020"
    ["13ee"]="Ariel USB 3.1 Type A (Gen2 x 2 ports)|Ariel|USB 3.1 Gen 2|2020"
    ["1557"]="Turin USB 3.1 xHCI|EPYC Turin|USB 3.1|2024"
)

declare -A AMD_CHIPSET=(
    ["43fc"]="800 Series Chipset USB 3.x XHCI Controller|X870/B850 (AM5)|USB 3.2|2024"
    ["43fd"]="800 Series Chipset USB 3.x XHCI Controller|X870/B850 (AM5)|USB 3.2|2024"
    ["43f7"]="600 Series Chipset USB 3.2 Controller|X670/B650 (AM5)|USB 3.2|2022"
    ["43ee"]="500 Series Chipset USB 3.1 XHCI Controller|X570/B550 (AM4)|USB 3.1|2019"
    ["43ec"]="A520 Series Chipset USB 3.1 XHCI Controller|A520 (AM4)|USB 3.1|2020"
    ["43d5"]="400 Series Chipset USB 3.1 xHCI Compliant Host Controller|X470/B450 (AM4)|USB 3.1|2018"
    ["43b9"]="X370 Series Chipset USB 3.1 xHCI Controller|X370 (AM4)|USB 3.1|2017"
    ["43ba"]="X399 Series Chipset USB 3.1 xHCI Controller|X399 (Threadripper)|USB 3.1|2017"
    ["43bb"]="300 Series Chipset USB 3.1 xHCI Controller|B350 (AM4)|USB 3.1|2017"
    ["43bc"]="A320 USB 3.1 XHCI Host Controller|A320 (AM4)|USB 3.1|2017"
    ["7814"]="FCH USB XHCI Controller|Legacy FCH|USB 3.0|2013"
    ["7812"]="FCH USB XHCI Controller|Legacy FCH|USB 3.0|2012"
)

# Third-party add-in cards — key is "vid:did"
declare -A THIRD_PARTY=(
    # ASMedia (VID: 1b21)
    ["1b21:1042"]="ASM1042 SuperSpeed USB Host Controller|ASMedia|USB 3.0 (5Gbps)|2011"
    ["1b21:1142"]="ASM1042A USB 3.0 Host Controller|ASMedia|USB 3.0 (5Gbps)|2013"
    ["1b21:1242"]="ASM1142 USB 3.1 Host Controller|ASMedia|USB 3.1 Gen 2 (10Gbps)|2015"
    ["1b21:1343"]="ASM1143 USB 3.1 Host Controller|ASMedia|USB 3.1 Gen 2 (10Gbps)|2017"
    ["1b21:2142"]="ASM2142/ASM3142 USB 3.1 Host Controller|ASMedia|USB 3.1 Gen 2 (10Gbps)|2016"
    ["1b21:3042"]="ASM3042 USB 3.2 Gen 1 xHCI Controller|ASMedia|USB 3.2 Gen 1 (5Gbps)|2019"
    ["1b21:3142"]="ASM3142 USB 3.2 Gen 2x1 xHCI Controller|ASMedia|USB 3.2 Gen 2 (10Gbps)|2019"
    ["1b21:3242"]="ASM3242 USB 3.2 Host Controller|ASMedia|USB 3.2 Gen 2x2 (20Gbps)|2020"
    ["1b21:2425"]="ASM4242 USB 4 / Thunderbolt 3 Host Router|ASMedia|USB4/TB3 (40Gbps)|2022"
    ["1b21:2426"]="ASM4242 USB 3.2 xHCI Controller|ASMedia|USB 3.2|2022"
    # VIA (VID: 1106)
    ["1106:3483"]="VL805/806 xHCI USB 3.0 Controller|VIA|USB 3.0 (5Gbps)|2014"
    ["1106:3432"]="VL800/801 xHCI USB 3.0 Controller|VIA|USB 3.0 (5Gbps)|2012"
    # Fresco Logic (VID: 1b73)
    ["1b73:1000"]="FL1000G USB 3.0 Host Controller|Fresco Logic|USB 3.0 (5Gbps)|2010"
    ["1b73:1009"]="FL1009 USB 3.0 Host Controller|Fresco Logic|USB 3.0 (5Gbps)|2011"
    ["1b73:1100"]="FL1100 USB 3.0 Host Controller|Fresco Logic|USB 3.0 (5Gbps)|2012"
    ["1b73:1400"]="FL1400 USB 3.0 Host Controller|Fresco Logic|USB 3.0 (5Gbps)|2014"
    # Etron (VID: 1b6f)
    ["1b6f:7023"]="EJ168 USB 3.0 Host Controller|Etron|USB 3.0 (5Gbps)|2011"
    ["1b6f:7052"]="EJ188/EJ198 USB 3.0 Host Controller|Etron|USB 3.0 (5Gbps)|2013"
    # Renesas (VID: 1912)
    ["1912:0014"]="uPD720201 USB 3.0 Host Controller|Renesas|USB 3.0 (5Gbps)|2011"
    ["1912:0015"]="uPD720202 USB 3.0 Host Controller|Renesas|USB 3.0 (5Gbps)|2012"
)

# Known third-party vendor names
declare -A VENDOR_NAMES=(
    ["1b21"]="ASMedia"
    ["1106"]="VIA"
    ["1b73"]="Fresco Logic"
    ["1912"]="Renesas"
    ["1b6f"]="Etron"
    ["104c"]="Texas Instruments"
)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

parse_db_entry() {
    local entry="$1"
    IFS='|' read -r DB_NAME DB_PLATFORM DB_USB DB_YEAR <<< "$entry"
}

get_controller_info() {
    local vid="${1,,}" did="${2,,}"
    local key="${vid}:${did}"

    # Intel CPU-integrated = CHIP 0
    if [[ "$vid" == "8086" ]] && [[ -n "${INTEL_CPU_INTEGRATED[$did]+x}" ]]; then
        parse_db_entry "${INTEL_CPU_INTEGRATED[$did]}"
        CTRL_TYPE="CPU"; CTRL_CHIP=0; CTRL_NAME="$DB_NAME"; CTRL_PLATFORM="$DB_PLATFORM"; CTRL_USB="$DB_USB"
        return
    fi

    # Intel Thunderbolt = CHIP 0 (CPU-attached)
    if [[ "$vid" == "8086" ]] && [[ -n "${INTEL_THUNDERBOLT[$did]+x}" ]]; then
        parse_db_entry "${INTEL_THUNDERBOLT[$did]}"
        CTRL_TYPE="TB"; CTRL_CHIP=0; CTRL_NAME="$DB_NAME"; CTRL_PLATFORM="$DB_PLATFORM"; CTRL_USB="$DB_USB"
        return
    fi

    # Intel PCH = CHIP 1
    if [[ "$vid" == "8086" ]] && [[ -n "${INTEL_PCH[$did]+x}" ]]; then
        parse_db_entry "${INTEL_PCH[$did]}"
        CTRL_TYPE="CHIPSET"; CTRL_CHIP=1; CTRL_NAME="$DB_NAME"; CTRL_PLATFORM="$DB_PLATFORM"; CTRL_USB="$DB_USB"
        return
    fi

    # AMD CPU-integrated = CHIP 0
    if [[ "$vid" == "1022" ]] && [[ -n "${AMD_CPU_INTEGRATED[$did]+x}" ]]; then
        parse_db_entry "${AMD_CPU_INTEGRATED[$did]}"
        CTRL_TYPE="CPU"; CTRL_CHIP=0; CTRL_NAME="$DB_NAME"; CTRL_PLATFORM="$DB_PLATFORM"; CTRL_USB="$DB_USB"
        return
    fi

    # AMD Chipset = CHIP 1
    if [[ "$vid" == "1022" ]] && [[ -n "${AMD_CHIPSET[$did]+x}" ]]; then
        parse_db_entry "${AMD_CHIPSET[$did]}"
        CTRL_TYPE="CHIPSET"; CTRL_CHIP=1; CTRL_NAME="$DB_NAME"; CTRL_PLATFORM="$DB_PLATFORM"; CTRL_USB="$DB_USB"
        return
    fi

    # Third-party
    if [[ -n "${THIRD_PARTY[$key]+x}" ]]; then
        parse_db_entry "${THIRD_PARTY[$key]}"
        CTRL_TYPE="ADDON"; CTRL_CHIP=1; CTRL_NAME="$DB_NAME"; CTRL_PLATFORM="PCIe Add-in"; CTRL_USB="$DB_USB"
        return
    fi

    # Unknown third-party vendor
    if [[ -n "${VENDOR_NAMES[$vid]+x}" ]]; then
        CTRL_TYPE="ADDON"; CTRL_CHIP=1; CTRL_NAME="${VENDOR_NAMES[$vid]} Controller"
        CTRL_PLATFORM="PCIe Add-in"; CTRL_USB="USB 3.x"
        return
    fi

    # Intel unknown = assume PCH
    if [[ "$vid" == "8086" ]]; then
        CTRL_TYPE="CHIPSET"; CTRL_CHIP=1; CTRL_NAME="Intel USB Controller"
        CTRL_PLATFORM="Unknown PCH (DID:$did)"; CTRL_USB="USB 3.x"
        return
    fi

    # AMD unknown = assume chipset
    if [[ "$vid" == "1022" ]]; then
        CTRL_TYPE="CHIPSET"; CTRL_CHIP=1; CTRL_NAME="AMD USB Controller"
        CTRL_PLATFORM="Unknown Chipset (DID:$did)"; CTRL_USB="USB 3.x"
        return
    fi

    CTRL_TYPE="UNKNOWN"; CTRL_CHIP=1; CTRL_NAME="Unknown Controller"
    CTRL_PLATFORM="VID:$vid DID:$did"; CTRL_USB="?"
}

get_msi_status() {
    local pci_addr="$1"  # e.g. 0000:00:14.0
    local sysfs="/sys/bus/pci/devices/$pci_addr"

    if [[ -d "$sysfs/msi_irqs" ]]; then
        local count
        count=$(ls "$sysfs/msi_irqs" 2>/dev/null | wc -l)
        if [[ "$count" -gt 0 ]]; then
            echo "MSI"
            return
        fi
    fi

    if grep -q "$pci_addr" /proc/interrupts 2>/dev/null; then
        echo "Line-Based"
        return
    fi

    echo "Unknown"
}

get_usb_power_control() {
    local usbdev="$1"
    local power_file="$usbdev/power/control"

    if [[ -r "$power_file" ]]; then
        cat "$power_file" 2>/dev/null
    else
        echo "unknown"
    fi
}

get_usb_autosuspend_delay() {
    local usbdev="$1"
    local delay_file="$usbdev/power/autosuspend_delay_ms"

    if [[ -r "$delay_file" ]]; then
        cat "$delay_file" 2>/dev/null
    else
        echo "unknown"
    fi
}

get_short_name() {
    local name="$1"
    local maxlen="${2:-30}"

    name="${name#Razer }"
    name="${name#Logitech }"
    name="${name#SteelSeries }"
    name="${name#Corsair }"
    name="${name#HyperX }"

    if [[ ${#name} -gt $maxlen ]]; then
        name="${name:0:$((maxlen - 3))}..."
    fi
    echo "$name"
}

update_progress() {
    local percent="$1"
    local message="$2"
    local width=25
    local filled=$(( width * percent / 100 ))
    local empty=$(( width - filled ))

    local filled_str="" empty_str=""
    for (( i = 0; i < filled; i++ )); do filled_str+="▓"; done
    for (( i = 0; i < empty; i++ )); do empty_str+="░"; done

    printf "\r  ${MINT}%s${DIM}%s${RESET} ${DIM}%s${RESET}%-30s" \
        "$filled_str" "$empty_str" "$message" ""
}

# =============================================================================
# DATA GATHERING
# =============================================================================

declare -a CTRL_PCI_ADDRS=()      # PCI bus address
declare -a CTRL_VIDS=()           # Vendor IDs
declare -a CTRL_DIDS=()           # Device IDs
declare -a CTRL_TYPES=()          # CPU, CHIPSET, TB, ADDON, UNKNOWN
declare -a CTRL_CHIPS=()          # 0 or 1
declare -a CTRL_NAMES=()          # Human-readable name
declare -a CTRL_PLATFORMS=()      # Platform name
declare -a CTRL_USBS=()           # USB standard
declare -a CTRL_MSI_STATUSES=()   # MSI, Line-Based, Unknown
declare -a CTRL_POWER_CONTROLS=() # on, auto, unknown
declare -a CTRL_DRIVER_NAMES=()   # Kernel driver name

declare -a DEV_NAMES=()
declare -a DEV_VIDS=()
declare -a DEV_PIDS=()
declare -a DEV_USB_PATHS=()
declare -a DEV_CTRL_INDICES=()
declare -a DEV_HUB_COUNTS=()
declare -a DEV_HUB_NAMES=()
declare -a DEV_CHIP_COUNTS=()

declare -a OPT_TYPES=()
declare -a OPT_CTRL_INDICES=()
declare -a OPT_NAMES=()
declare -a OPT_DESCS=()

HAS_CHIP0=false
HAS_CHIP1=false

find_pci_parent() {
    local usbpath="$1"
    local realpath
    realpath=$(readlink -f "$usbpath" 2>/dev/null) || return 1

    local dir="$realpath"
    while [[ "$dir" != "/" ]]; do
        local basename
        basename=$(basename "$dir")
        if [[ "$basename" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; then
            echo "$basename"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

count_hubs() {
    local usbpath="$1"
    local realpath
    realpath=$(readlink -f "$usbpath" 2>/dev/null) || { echo "0|"; return; }

    local hub_count=0
    local hub_names=""
    local dir
    dir=$(dirname "$realpath")

    while [[ "$dir" != "/" ]]; do
        local basename
        basename=$(basename "$dir")

        if [[ "$basename" =~ ^usb[0-9]+$ ]]; then
            break
        fi

        local class_file="$dir/bDeviceClass"
        if [[ -r "$class_file" ]]; then
            local bclass
            bclass=$(cat "$class_file" 2>/dev/null)
            if [[ "$bclass" == "09" ]]; then
                hub_count=$((hub_count + 1))
                local product_file="$dir/product"
                local hub_name="USB Hub"
                if [[ -r "$product_file" ]]; then
                    hub_name=$(cat "$product_file" 2>/dev/null)
                fi
                if [[ -n "$hub_names" ]]; then
                    hub_names="$hub_names -> $hub_name"
                else
                    hub_names="$hub_name"
                fi
            fi
        fi

        if [[ "$basename" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; then
            break
        fi

        dir=$(dirname "$dir")
    done

    echo "$hub_count|$hub_names"
}

get_system_usb_autosuspend() {
    if [[ -r /etc/tlp.conf ]]; then
        local setting
        setting=$(grep -E '^USB_AUTOSUSPEND=' /etc/tlp.conf 2>/dev/null | tail -1)
        if [[ "$setting" == "USB_AUTOSUSPEND=1" ]]; then
            echo "enabled_tlp"
            return
        fi
    fi

    local auto_count=0
    local total_count=0
    for ctrl_file in /sys/bus/usb/devices/*/power/control; do
        [[ -r "$ctrl_file" ]] || continue
        total_count=$((total_count + 1))
        if [[ "$(cat "$ctrl_file" 2>/dev/null)" == "auto" ]]; then
            auto_count=$((auto_count + 1))
        fi
    done

    if [[ $total_count -gt 0 ]] && [[ $auto_count -gt $(( total_count / 2 )) ]]; then
        echo "mostly_auto"
    else
        echo "ok"
    fi
}

gather_usb_data() {
    update_progress 5 "Checking power settings..."

    local sys_suspend
    sys_suspend=$(get_system_usb_autosuspend)
    if [[ "$sys_suspend" == "enabled_tlp" ]]; then
        OPT_TYPES+=("SystemSuspend")
        OPT_CTRL_INDICES+=(-1)
        OPT_NAMES+=("TLP Configuration")
        OPT_DESCS+=("USB autosuspend is enabled via TLP — set USB_AUTOSUSPEND=0 in /etc/tlp.conf")
    elif [[ "$sys_suspend" == "mostly_auto" ]]; then
        OPT_TYPES+=("SystemSuspend")
        OPT_CTRL_INDICES+=(-1)
        OPT_NAMES+=("System USB Power")
        OPT_DESCS+=("Most USB devices have autosuspend enabled — may cause latency spikes")
    fi

    update_progress 15 "Scanning USB controllers..."

    local ctrl_idx=0
    for dev_path in /sys/bus/pci/devices/*; do
        [[ -r "$dev_path/class" ]] || continue
        local pci_class
        pci_class=$(cat "$dev_path/class" 2>/dev/null)

        [[ "$pci_class" == 0x0c03* ]] || continue

        local pci_addr
        pci_addr=$(basename "$dev_path")

        local vid did
        vid=$(cat "$dev_path/vendor" 2>/dev/null)
        did=$(cat "$dev_path/device" 2>/dev/null)
        vid="${vid#0x}"; vid="${vid,,}"
        did="${did#0x}"; did="${did,,}"

        get_controller_info "$vid" "$did"

        local msi_status
        msi_status=$(get_msi_status "$pci_addr")

        local power_ctrl="unknown"
        for roothub in /sys/bus/usb/devices/usb*; do
            local rh_real
            rh_real=$(readlink -f "$roothub" 2>/dev/null)
            if [[ "$rh_real" == *"$pci_addr"* ]]; then
                power_ctrl=$(get_usb_power_control "$roothub")
                break
            fi
        done

        local driver_name="unknown"
        if [[ -L "$dev_path/driver" ]]; then
            driver_name=$(basename "$(readlink -f "$dev_path/driver")" 2>/dev/null)
        fi

        CTRL_PCI_ADDRS+=("$pci_addr")
        CTRL_VIDS+=("$vid")
        CTRL_DIDS+=("$did")
        CTRL_TYPES+=("$CTRL_TYPE")
        CTRL_CHIPS+=("$CTRL_CHIP")
        CTRL_NAMES+=("$CTRL_NAME")
        CTRL_PLATFORMS+=("$CTRL_PLATFORM")
        CTRL_USBS+=("$CTRL_USB")
        CTRL_MSI_STATUSES+=("$msi_status")
        CTRL_POWER_CONTROLS+=("$power_ctrl")
        CTRL_DRIVER_NAMES+=("$driver_name")

        if [[ "$CTRL_CHIP" -eq 0 ]]; then
            HAS_CHIP0=true
        else
            HAS_CHIP1=true
        fi

        if [[ "$msi_status" == "Line-Based" ]]; then
            OPT_TYPES+=("MSI")
            OPT_CTRL_INDICES+=("$ctrl_idx")
            OPT_NAMES+=("$CTRL_NAME")
            OPT_DESCS+=("Enable MSI interrupts on $CTRL_NAME")
        fi

        if [[ "$power_ctrl" == "auto" ]]; then
            OPT_TYPES+=("Suspend")
            OPT_CTRL_INDICES+=("$ctrl_idx")
            OPT_NAMES+=("$CTRL_NAME")
            OPT_DESCS+=("Disable autosuspend on $CTRL_NAME root hub")
        fi

        ctrl_idx=$((ctrl_idx + 1))
    done

    update_progress 30 "Finding input devices..."

    declare -A seen_devs=()
    local total_devs=0
    local dev_count=0

    for intf_path in /sys/bus/usb/devices/*/bInterfaceClass; do
        [[ -r "$intf_path" ]] || continue
        local iclass
        iclass=$(cat "$intf_path" 2>/dev/null)
        [[ "$iclass" == "03" ]] || continue
        total_devs=$((total_devs + 1))
    done
    if [[ $total_devs -eq 0 ]]; then total_devs=1; fi

    for intf_path in /sys/bus/usb/devices/*/bInterfaceClass; do
        [[ -r "$intf_path" ]] || continue
        local iclass
        iclass=$(cat "$intf_path" 2>/dev/null)
        [[ "$iclass" == "03" ]] || continue

        dev_count=$((dev_count + 1))
        local pct=$(( 30 + (dev_count * 65 / total_devs) ))
        if [[ $((dev_count % 2)) -eq 0 ]]; then
            update_progress "$pct" "Tracing device $dev_count of $total_devs..."
        fi

        local intf_dir
        intf_dir=$(dirname "$intf_path")
        local usb_dev_path
        local real_intf_dir
        real_intf_dir=$(readlink -f "$intf_dir" 2>/dev/null)
        if [[ -n "$real_intf_dir" ]]; then
            usb_dev_path=$(dirname "$real_intf_dir")
        else
            local intf_base
            intf_base=$(basename "$intf_dir")
            usb_dev_path="/sys/bus/usb/devices/${intf_base%%:*}"
        fi

        local dev_vid dev_pid
        dev_vid=$(cat "$usb_dev_path/idVendor" 2>/dev/null)
        dev_pid=$(cat "$usb_dev_path/idProduct" 2>/dev/null)
        [[ -z "$dev_vid" || -z "$dev_pid" ]] && continue

        local devkey="${dev_vid}:${dev_pid}"
        [[ -n "${seen_devs[$devkey]+x}" ]] && continue
        seen_devs[$devkey]=1

        local dev_name="Unknown USB Device"
        if [[ -r "$usb_dev_path/product" ]]; then
            dev_name=$(cat "$usb_dev_path/product" 2>/dev/null)
        fi
        if [[ "$dev_name" == "Unknown USB Device" ]] && [[ -r "$usb_dev_path/manufacturer" ]]; then
            local mfr
            mfr=$(cat "$usb_dev_path/manufacturer" 2>/dev/null)
            [[ -n "$mfr" ]] && dev_name="$mfr Device"
        fi

        local pci_parent
        pci_parent=$(find_pci_parent "$usb_dev_path") || continue

        local ctrl_match=-1
        for (( i = 0; i < ${#CTRL_PCI_ADDRS[@]}; i++ )); do
            if [[ "${CTRL_PCI_ADDRS[$i]}" == "$pci_parent" ]]; then
                ctrl_match=$i
                break
            fi
        done
        [[ $ctrl_match -eq -1 ]] && continue

        local hub_info
        hub_info=$(count_hubs "$usb_dev_path")
        local hub_count hub_names
        hub_count="${hub_info%%|*}"
        hub_names="${hub_info#*|}"

        local chip_count=$(( ${CTRL_CHIPS[$ctrl_match]} + hub_count ))

        DEV_NAMES+=("$dev_name")
        DEV_VIDS+=("$dev_vid")
        DEV_PIDS+=("$dev_pid")
        DEV_USB_PATHS+=("$usb_dev_path")
        DEV_CTRL_INDICES+=("$ctrl_match")
        DEV_HUB_COUNTS+=("$hub_count")
        DEV_HUB_NAMES+=("$hub_names")
        DEV_CHIP_COUNTS+=("$chip_count")
    done
}

# =============================================================================
# DISPLAY FUNCTIONS
# =============================================================================

show_tree() {
    echo ""
    echo "  ${DIM}Count chips between your device and CPU. More chips = more latency.${RESET}"
    echo ""

    echo "  ${MINT}${BOLD}0 CHIPS${RESET}  device ${MINT}---${RESET} [CPU]"
    echo "  ${ORANGE}${BOLD}1 CHIP${RESET}   device -${ORANGE}[CHIPSET]${RESET}- [CPU]"
    echo "  ${CORAL}${BOLD}2 CHIPS${RESET}  device -${CORAL}[HUB]${RESET}-[CHIPSET]- [CPU]"
    echo ""

    echo "  ${DIM}=============================================================${RESET}"
    echo ""

    if [[ ${#DEV_NAMES[@]} -eq 0 ]]; then
        echo "  ${DIM}No USB input devices detected${RESET}"
    else
        if [[ "$HAS_CHIP0" == false ]]; then
            echo "  ${ORANGE}! This system has no direct CPU USB${RESET}"
            echo "  ${DIM}  1 chip is your best option here${RESET}"
            echo ""
        fi

        local -a chip0_indices=() chip1_indices=() chip2_indices=()
        for (( i = 0; i < ${#DEV_NAMES[@]}; i++ )); do
            case "${DEV_CHIP_COUNTS[$i]}" in
                0) chip0_indices+=("$i") ;;
                1) chip1_indices+=("$i") ;;
                *) chip2_indices+=("$i") ;;
            esac
        done

        # 0 CHIPS — Direct to CPU
        if [[ ${#chip0_indices[@]} -gt 0 ]]; then
            echo "  ${MINT}0 chips${RESET} ${DIM}- direct to CPU${RESET}"
            local count=${#chip0_indices[@]}
            local n=0
            for idx in "${chip0_indices[@]}"; do
                n=$((n + 1))
                local branch; [[ $n -eq $count ]] && branch="'-" || branch="|-"
                echo "    ${DIM}${branch}${RESET} ${MINT}${DEV_NAMES[$idx]}${RESET}"
            done
            echo ""
        fi

        # 1 CHIP — Via chipset
        if [[ ${#chip1_indices[@]} -gt 0 ]]; then
            echo "  ${ORANGE}1 chip${RESET} ${DIM}- through chipset${RESET}"
            local count=${#chip1_indices[@]}
            local n=0
            for idx in "${chip1_indices[@]}"; do
                n=$((n + 1))
                local branch; [[ $n -eq $count ]] && branch="'-" || branch="|-"
                echo "    ${DIM}${branch}${RESET} ${ORANGE}${DEV_NAMES[$idx]}${RESET}"
            done
            echo ""
        fi

        # 2+ CHIPS — Via hub
        if [[ ${#chip2_indices[@]} -gt 0 ]]; then
            echo "  ${CORAL}2+ chips${RESET} ${DIM}- through hub${RESET}"
            local count=${#chip2_indices[@]}
            local n=0
            for idx in "${chip2_indices[@]}"; do
                n=$((n + 1))
                local branch; [[ $n -eq $count ]] && branch="'-" || branch="|-"
                echo "    ${DIM}${branch}${RESET} ${CORAL}${DEV_NAMES[$idx]}${RESET}"
            done
            echo ""
        fi
    fi

    echo "  ${DIM}=============================================================${RESET}"
    echo ""
    echo "  ${DIM}Unplug and replug to test different ports${RESET}"
    echo ""
}

show_full_analysis() {
    echo "  ${WHITE}${BOLD}CONTROLLERS${RESET}"
    echo "  ${BORDER}---------------------------------------------------------------------${RESET}"

    local -a sorted_indices=()
    for (( i = 0; i < ${#CTRL_PCI_ADDRS[@]}; i++ )); do
        [[ "${CTRL_CHIPS[$i]}" -eq 0 ]] && sorted_indices+=("$i")
    done
    for (( i = 0; i < ${#CTRL_PCI_ADDRS[@]}; i++ )); do
        [[ "${CTRL_CHIPS[$i]}" -ne 0 ]] && sorted_indices+=("$i")
    done

    for ci in "${sorted_indices[@]}"; do
        local chip_color
        case "${CTRL_CHIPS[$ci]}" in
            0) chip_color="$MINT" ;;
            1) chip_color="$ORANGE" ;;
            *) chip_color="$CORAL" ;;
        esac

        local chip_label
        case "${CTRL_CHIPS[$ci]}" in
            0) chip_label="CHIP 0 - INSIDE CPU" ;;
            1) chip_label="CHIP 1 - CHIPSET" ;;
            *) chip_label="CHIP ${CTRL_CHIPS[$ci]} - HUB" ;;
        esac

        echo ""
        echo "  ${chip_color}${chip_label}${RESET}"
        echo "      ${CTRL_NAMES[$ci]}"
        echo "      ${DIM}VID:${CTRL_VIDS[$ci]} DID:${CTRL_DIDS[$ci]} | ${CTRL_PLATFORMS[$ci]}${RESET}"

        echo -n "      IRQ: "
        case "${CTRL_MSI_STATUSES[$ci]}" in
            MSI)        echo "${MINT}MSI${RESET} ${DIM}(low latency interrupts)${RESET}" ;;
            Line-Based) echo "${CORAL}Line-Based${RESET} ${DIM}(higher latency)${RESET}" ;;
            *)          echo "${DIM}${CTRL_MSI_STATUSES[$ci]}${RESET}" ;;
        esac

        if [[ "${CTRL_POWER_CONTROLS[$ci]}" == "auto" ]]; then
            echo "      ${ORANGE}! Autosuspend ENABLED${RESET} ${DIM}(causes latency spikes)${RESET}"
        fi

        echo "      ${DIM}Driver: ${CTRL_DRIVER_NAMES[$ci]}${RESET}"

        local has_devs=false
        for (( di = 0; di < ${#DEV_NAMES[@]}; di++ )); do
            if [[ "${DEV_CTRL_INDICES[$di]}" -eq "$ci" ]]; then
                if [[ "$has_devs" == false ]]; then
                    echo "      ${DIM}Devices:${RESET}"
                    has_devs=true
                fi
                local hub_info=""
                if [[ "${DEV_HUB_COUNTS[$di]}" -gt 0 ]]; then
                    hub_info=" ${CORAL}(+hub)${RESET}"
                fi

                local is_last=true
                for (( dk = di + 1; dk < ${#DEV_NAMES[@]}; dk++ )); do
                    if [[ "${DEV_CTRL_INDICES[$dk]}" -eq "$ci" ]]; then
                        is_last=false
                        break
                    fi
                done
                local branch; [[ "$is_last" == true ]] && branch="'-" || branch="|-"

                echo "        ${DIM}${branch}${RESET} ${DEV_NAMES[$di]}${hub_info}"
            fi
        done
    done

    echo ""
    echo "  ${WHITE}${BOLD}INPUT DEVICES${RESET}"
    echo "  ${BORDER}---------------------------------------------------------------------${RESET}"

    local -a dev_sorted=()
    for chip_level in 0 1 2 3 4 5 6 7 8 9 10; do
        for (( i = 0; i < ${#DEV_NAMES[@]}; i++ )); do
            [[ "${DEV_CHIP_COUNTS[$i]}" -eq "$chip_level" ]] && dev_sorted+=("$i")
        done
    done

    for di in "${dev_sorted[@]}"; do
        local chip_color
        case "${DEV_CHIP_COUNTS[$di]}" in
            0) chip_color="$MINT" ;;
            1) chip_color="$ORANGE" ;;
            *) chip_color="$CORAL" ;;
        esac

        local chip_label
        case "${DEV_CHIP_COUNTS[$di]}" in
            0) chip_label="CHIP 0 - CPU" ;;
            1) chip_label="CHIP 1 - CHIPSET" ;;
            2) chip_label="CHIP 2 - HUB" ;;
            *) chip_label="CHIP ${DEV_CHIP_COUNTS[$di]} - HUB" ;;
        esac

        echo ""
        echo "  ${WHITE}${DEV_NAMES[$di]}${RESET}"
        echo "      ${DIM}VID:${DEV_VIDS[$di]} PID:${DEV_PIDS[$di]}${RESET}"
        echo "      ${chip_color}${chip_label}${RESET}"

        if [[ -n "${DEV_HUB_NAMES[$di]}" ]]; then
            echo "      ${DIM}Hubs: ${DEV_HUB_NAMES[$di]}${RESET}"
        fi
    done

    echo ""
    echo "  ${BORDER}=====================================================================${RESET}"
    echo ""
}

show_optimizations() {
    local is_root=false
    [[ $EUID -eq 0 ]] && is_root=true

    [[ ${#OPT_TYPES[@]} -eq 0 ]] && return

    echo "  ${WHITE}${BOLD}OPTIMIZATIONS AVAILABLE${RESET}"
    echo "  ${BORDER}---------------------------------------------------------------------${RESET}"
    echo ""

    if [[ "$is_root" == false ]]; then
        echo "  ${ORANGE}! To apply optimizations: Run as root (sudo)${RESET}"
        echo ""
        local count=${#OPT_TYPES[@]}
        local i=0
        for (( idx = 0; idx < count; idx++ )); do
            i=$((i + 1))
            local branch; [[ $i -eq $count ]] && branch="'-" || branch="|-"
            echo "  ${DIM}${branch}${RESET} ${OPT_DESCS[$idx]} ${DIM}(${OPT_NAMES[$idx]})${RESET}"
        done
        echo ""
        return
    fi

    for (( idx = 0; idx < ${#OPT_TYPES[@]}; idx++ )); do
        echo "  ${SKY}[$((idx + 1))]${RESET} ${OPT_DESCS[$idx]}"
        echo "      ${DIM}${OPT_NAMES[$idx]}${RESET}"
        echo ""
    done

    if [[ -t 0 ]]; then
        echo -n "  ${DIM}Enter number to apply, or press Enter to skip:${RESET} "
        read -r choice

        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            local opt_idx=$((choice - 1))
            if [[ $opt_idx -ge 0 ]] && [[ $opt_idx -lt ${#OPT_TYPES[@]} ]]; then
                apply_optimization "$opt_idx"
            fi
        fi
    fi
}

apply_optimization() {
    local idx="$1"
    local opt_type="${OPT_TYPES[$idx]}"

    echo ""

    case "$opt_type" in
        "Suspend")
            local ci="${OPT_CTRL_INDICES[$idx]}"
            local pci_addr="${CTRL_PCI_ADDRS[$ci]}"
            local applied=false

            for roothub in /sys/bus/usb/devices/usb*; do
                local rh_real
                rh_real=$(readlink -f "$roothub" 2>/dev/null)
                if [[ "$rh_real" == *"$pci_addr"* ]]; then
                    echo "on" > "$roothub/power/control" 2>/dev/null && applied=true
                fi
            done

            if [[ "$applied" == true ]]; then
                echo "  ${MINT}[OK]${RESET} Disabled autosuspend for ${OPT_NAMES[$idx]}"
            else
                echo "  ${CORAL}[FAIL]${RESET} Could not disable autosuspend"
            fi
            ;;

        "SystemSuspend")
            echo "  ${DIM}System-wide USB autosuspend must be configured via your power manager:${RESET}"
            echo "  ${DIM}  TLP: Set USB_AUTOSUSPEND=0 in /etc/tlp.conf${RESET}"
            echo "  ${DIM}  Manual: echo 'on' > /sys/bus/usb/devices/*/power/control${RESET}"
            ;;

        "MSI")
            echo "  ${DIM}MSI interrupt mode is controlled by the kernel driver.${RESET}"
            echo "  ${DIM}Check that your kernel xhci-hcd driver is up to date.${RESET}"
            ;;
    esac

    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

clear

echo ""
echo "  ${SKY}${BOLD}USB LATENCY ANALYZER${RESET}"
echo "  ${DIM}=====================================================================${RESET}"
echo ""

gather_usb_data

printf "\r%-80s\r" ""
echo "  ${MINT}[OK]${RESET} ${DIM}Ready${RESET}"
sleep 0.15

show_tree

show_full_analysis

show_optimizations
