# ==============================================================================
# UDP Filter Project - Top-Level Setup Script
# ==============================================================================
# This wrapper script sources the auto-generated create_project.tcl
# It sets the origin directory so create_project.tcl finds all source files
# Target: Xilinx Versal VCK190 with 1G Ethernet
# ==============================================================================

puts "=========================================="
puts " UDP Packet Filter - Project Setup"
puts "=========================================="

# Get script directory (sources_1/new/)
set script_dir [file dirname [file normalize [info script]]]
puts "Script location: $script_dir"

# ==============================================================================
# STEP 1: Verify create_project.tcl Exists
# ==============================================================================
set create_project_script [file join $script_dir "create_project.tcl"]

if {![file exists $create_project_script]} {
    puts "\n[ERROR] create_project.tcl not found!"
    puts "Expected location: $create_project_script"
    return -code error "Missing create_project.tcl"
}

puts "[INFO] Found create_project.tcl"

# ==============================================================================
# STEP 2: Set Origin Directory for create_project.tcl
# ==============================================================================
# The auto-generated create_project.tcl expects files in specific locations.
# We need to navigate up to the udp_filter.srcs directory so paths resolve correctly.

# Current: D:/HFT training/udp_filter/udp_filter.srcs/sources_1/new
# Need:    D:/HFT training/udp_filter/udp_filter.srcs

set origin_dir [file normalize [file join $script_dir ".." ".."]]
puts "[INFO] Setting origin_dir to: $origin_dir"

# Make origin_dir available to create_project.tcl
set ::origin_dir_loc $origin_dir

# ==============================================================================
# STEP 3: Verify Required Source Files
# ==============================================================================
puts "\n[STEP 3] Verifying source files in new/ directory..."

set required_files [list \
    "udp_filter.v" \
    "init_ethernet.v" \
    "packet_parser.v" \
    "fifomem.v" \
    "wptr_full.v" \
    "rptr_empty.v" \
    "sync_w2r.v" \
    "sync_r2w.v" \
    "bin2gray.v" \
    "gray2bin.v" \
    "tb_udp_filter.v" \
    "tb_design_1.v" \
]

set all_files_present 1
foreach file $required_files {
    set filepath [file join $script_dir $file]
    if {[file exists $filepath]} {
        puts "  ✓ Found: $file"
    } else {
        puts "  ✗ MISSING: $file"
        set all_files_present 0
    }
}

if {!$all_files_present} {
    puts "\n[ERROR] Some required files are missing!"
    puts "Please ensure all source files are copied to: $script_dir"
    puts "Run this command first:"
    puts "  Copy-Item sources_1/imports/**/*.v sources_1/new/"
    puts "  Copy-Item sim_1/new/*.v sources_1/new/"
    return -code error "Missing required source files"
}

puts "[SUCCESS] All source files present!"

# ==============================================================================
# STEP 4: Source the Auto-Generated create_project.tcl
# ==============================================================================
puts "\n[STEP 4] Sourcing create_project.tcl..."
puts "=========================================="

# Change directory to script location so relative paths work
cd $script_dir

# Source the main project creation script
source $create_project_script

# ==============================================================================
# COMPLETION
# ==============================================================================
puts "\n=========================================="
puts " Project Setup Complete!"
puts "=========================================="
puts ""
puts "The project has been created using create_project.tcl"
puts ""
puts "Next Steps:"
puts "  1. Open project:"
puts "     open_project udp_filter/udp_filter.xpr"
puts ""
puts "  2. Run simulation:"
puts "     launch_simulation"
puts "     run 2000ns"
puts ""
puts "  3. Run synthesis:"
puts "     launch_runs synth_1"
puts "     wait_on_run synth_1"
puts ""
puts "=========================================="
puts "[SUCCESS] Ready to use!"
puts "=========================================="
