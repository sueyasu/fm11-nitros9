#!/bin/sh
fm11_check_cpu() { case "$1" in 6809|6309) ;; *) return 1 ;; esac; }
fm11_check_media() { case "$1" in 2d|2hd|all) ;; *) return 1 ;; esac; }
fm11_level_name() { case "$1" in 1|l1|L1|level1|Level1) echo 1 ;; 2|l2|L2|level2|Level2) echo 2 ;; *) return 1 ;; esac; }
fm11_hdd_geometry()
{
    case "$1" in
        m2230b) echo "315 2" ;; m2231b) echo "157 4" ;; m2232b) echo "157 6" ;;
        m2233b) echo "315 4" ;; m2234b) echo "315 6" ;; m2235b) echo "315 8" ;;
        m2241b) echo "747 4" ;; m2242b) echo "747 7" ;; m2243b) echo "747 11" ;;
        *) return 1 ;;
    esac
}
