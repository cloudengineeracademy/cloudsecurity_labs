#!/bin/bash

# Achievement Badge Display Library
# Source this file from other scripts: source "$(dirname "$0")/../../scripts/achievements.sh"

# Colors
BADGE_GOLD='\033[1;33m'
BADGE_GREEN='\033[1;32m'
BADGE_CYAN='\033[1;36m'
BADGE_NC='\033[0m'

show_badge() {
    local badge_name="$1"

    case "$badge_name" in
        recon)
            echo ""
            echo -e "${BADGE_CYAN}"
            echo "    ╔══════════════════════════════════════╗"
            echo "    ║                                      ║"
            echo "    ║       ◉  RECON COMPLETE  ◉           ║"
            echo "    ║                                      ║"
            echo "    ║   \"You can't fix what you can't see\" ║"
            echo "    ║                                      ║"
            echo "    ║          ┌─────────┐                 ║"
            echo "    ║          │  SCAN   │                 ║"
            echo "    ║          │ ▓▓▓▓▓▓▓ │                 ║"
            echo "    ║          │ ▓▓▓▓▓▓▓ │                 ║"
            echo "    ║          └─────────┘                 ║"
            echo "    ║                                      ║"
            echo "    ╚══════════════════════════════════════╝"
            echo -e "${BADGE_NC}"
            ;;
        cloudtrail)
            echo ""
            echo -e "${BADGE_GREEN}"
            echo "    ╔══════════════════════════════════════╗"
            echo "    ║                                      ║"
            echo "    ║   ✈  FLIGHT RECORDER ONLINE  ✈      ║"
            echo "    ║                                      ║"
            echo "    ║   \"Every API call. Every region.\"    ║"
            echo "    ║                                      ║"
            echo "    ║        ┌──────────────┐              ║"
            echo "    ║        │ ► RECORDING  │              ║"
            echo "    ║        │  CloudTrail  │              ║"
            echo "    ║        │  ■■■■■■■■■■  │              ║"
            echo "    ║        └──────────────┘              ║"
            echo "    ║                                      ║"
            echo "    ╚══════════════════════════════════════╝"
            echo -e "${BADGE_NC}"
            ;;
        guardduty)
            echo ""
            echo -e "${BADGE_GOLD}"
            echo "    ╔══════════════════════════════════════╗"
            echo "    ║                                      ║"
            echo "    ║     ◎  THREAT RADAR ACTIVE  ◎       ║"
            echo "    ║                                      ║"
            echo "    ║    \"GuardDuty is watching.\"          ║"
            echo "    ║                                      ║"
            echo "    ║          .  *  .  *  .               ║"
            echo "    ║        *  GUARDDUTY  *               ║"
            echo "    ║          ◎────────◎                  ║"
            echo "    ║        *  SEC HUB   *                ║"
            echo "    ║          .  *  .  *  .               ║"
            echo "    ║                                      ║"
            echo "    ╚══════════════════════════════════════╝"
            echo -e "${BADGE_NC}"
            ;;
        compliance)
            echo ""
            echo -e "${BADGE_CYAN}"
            echo "    ╔══════════════════════════════════════╗"
            echo "    ║                                      ║"
            echo "    ║   ⚙  COMPLIANCE ENGINE RUNNING  ⚙   ║"
            echo "    ║                                      ║"
            echo "    ║   \"From reactive to proactive.\"      ║"
            echo "    ║                                      ║"
            echo "    ║      ┌─ Config ─────── ON ─┐         ║"
            echo "    ║      │  Rules ──────── 3+  │         ║"
            echo "    ║      │  Analyzer ───── ON  │         ║"
            echo "    ║      └─────────────────────┘         ║"
            echo "    ║                                      ║"
            echo "    ╚══════════════════════════════════════╝"
            echo -e "${BADGE_NC}"
            ;;
        mission_complete)
            echo ""
            echo -e "${BADGE_GOLD}"
            echo "    ╔══════════════════════════════════════════════╗"
            echo "    ║                                              ║"
            echo "    ║   ★ ★ ★  MISSION COMPLETE  ★ ★ ★           ║"
            echo "    ║                                              ║"
            echo "    ║        ACCOUNT SECURED — 100/100            ║"
            echo "    ║                                              ║"
            echo "    ║   ┌──────────────────────────────────┐      ║"
            echo "    ║   │  Identity ......... ████████ 20  │      ║"
            echo "    ║   │  Network .......... ██████   15  │      ║"
            echo "    ║   │  Data ............. ████████ 20  │      ║"
            echo "    ║   │  Detection ........ ██████████30  │      ║"
            echo "    ║   │  Compliance ....... ██████   15  │      ║"
            echo "    ║   └──────────────────────────────────┘      ║"
            echo "    ║                                              ║"
            echo "    ║   You started at 15. You earned every point. ║"
            echo "    ║                                              ║"
            echo "    ╚══════════════════════════════════════════════╝"
            echo -e "${BADGE_NC}"
            ;;
        *)
            echo "Unknown badge: $badge_name"
            ;;
    esac
}
