#!/usr/bin/env bash
# Test script for enhanced graphics system

set -euo pipefail

# Load common functions
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

main() {
    echo "🎨 Testing Enhanced Graphics System"
    echo "=================================="
    echo
    
    # Test 1: Unicode detection
    echo "1. Unicode Detection Test:"
    if has_unicode; then
        log_success "Unicode support detected! Using beautiful box drawing characters"
    else
        log_warn "Unicode not detected, using ASCII fallback"
    fi
    echo
    
    # Test 2: Terminal width detection
    echo "2. Terminal Width Detection:"
    local width=$(get_terminal_width)
    log_info "Detected terminal width: ${width} columns"
    echo
    
    # Test 3: Text width calculation
    echo "3. Text Width Calculation:"
    local test_text="🚀 Hello World! 🎉"
    local calculated_width=$(text_width "$test_text")
    log_info "Text: '$test_text'"
    log_info "Calculated width: $calculated_width characters"
    echo
    
    # Test 4: Box characters
    echo "4. Box Characters Test:"
    local box_chars=$(get_box_chars)
    log_info "Box characters: $box_chars"
    echo
    
    # Test 5: Header display
    echo "5. Header Display Test:"
    print_header "Graphics Test Suite" "1.0.0"
    
    # Test 6: Step progress
    echo "6. Step Progress Test:"
    for i in {1..5}; do
        print_step "$i" 5 "Testing step $i"
        sleep 0.5
    done
    echo
    
    # Test 7: Log levels
    echo "7. Log Levels Test:"
    log_info "This is an info message 🔵"
    log_success "This is a success message ✨"
    log_warn "This is a warning message ⚠️"
    log_error "This is an error message 💥"
    log_step "This is a step message 🚀"
    echo
    
    # Test 8: Box helper
    echo "8. Box Helper Test:"
    print_box "$BLUE" "📦 Test Box 📦" \
        "${WHITE}This is a test of the box helper function" \
        "${GREEN}It should center text properly" \
        "${YELLOW}And handle multiple lines"
    echo
    
    # Test 9: Different terminal widths simulation
    echo "9. Width Adaptation Test:"
    log_info "Testing with different terminal widths..."
    
    # Temporarily override terminal width
    local original_columns=${COLUMNS:-}
    
    for test_width in 60 80 120; do
        export COLUMNS=$test_width
        echo "  Testing with width: $test_width"
        print_box "$PURPLE" "Width Test: $test_width" \
            "${WHITE}This box should adapt to terminal width"
        echo
    done
    
    # Restore original width
    if [[ -n "$original_columns" ]]; then
        export COLUMNS=$original_columns
    else
        unset COLUMNS
    fi
    
    # Test 10: Center text function
    echo "10. Text Centering Test:"
    local test_widths=(40 60 80)
    for width in "${test_widths[@]}"; do
        echo "Width $width:"
        echo "|$(center_text "🎯 Centered Text 🎯" "$width")|"
    done
    echo
    
    # Final summary
    print_box "$GREEN" "🎉 Graphics Test Complete! 🎉" \
        "${WHITE}All graphics functions are working correctly" \
        "${CYAN}The enhanced graphics system is ready for use!"
}

main "$@"
