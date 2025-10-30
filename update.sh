#!/usr/bin/env bash

set -euo pipefail

# Configuration
INSTALL_SCRIPT_URL="https://s3.amazonaws.com/archil-client/install"
S3_BASE_URL="https://s3.amazonaws.com/archil-client/pkg"
FLAKE_FILE="flake.nix"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
DRY_RUN=false
VERBOSE=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Show what would be updated without making changes"
            echo "  --verbose    Show detailed output"
            echo "  --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Logging functions (all output to stderr to not interfere with command substitution)
log_info() {
    echo -e "${BLUE}ℹ${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}✓${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*" >&2
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "  ${NC}$*${NC}" >&2
    fi
}

# Check if required commands are available
check_dependencies() {
    local missing_deps=()

    for cmd in curl grep sed nix-prefetch-url; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# Fetch and extract version from install script
get_latest_version() {
    log_info "Fetching latest version from install script..."
    log_verbose "URL: $INSTALL_SCRIPT_URL"

    local install_script
    install_script=$(curl -sL "$INSTALL_SCRIPT_URL")

    if [[ -z "$install_script" ]]; then
        log_error "Failed to fetch install script"
        exit 1
    fi

    # Extract version from CLIENT_VERSION="${ARCHIL_CLIENT_VERSION:-X.Y.Z-TIMESTAMP}"
    local version
    version=$(echo "$install_script" | grep -oP 'CLIENT_VERSION="\$\{ARCHIL_CLIENT_VERSION:-\K[^}]+' || true)

    if [[ -z "$version" ]]; then
        log_error "Failed to extract version from install script"
        exit 1
    fi

    # Validate version format (X.Y.Z-TIMESTAMP)
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]]; then
        log_error "Invalid version format: $version"
        exit 1
    fi

    log_verbose "Extracted version: $version"
    echo "$version"
}

# Get current version from flake.nix
get_current_version() {
    if [[ ! -f "$FLAKE_FILE" ]]; then
        log_error "flake.nix not found"
        exit 1
    fi

    local version
    version=$(grep -oP 'version = "\K[^"]+' "$FLAKE_FILE" | head -1 || true)

    if [[ -z "$version" ]]; then
        log_error "Failed to extract current version from flake.nix"
        exit 1
    fi

    echo "$version"
}

# Verify package exists on S3
verify_package() {
    local arch="$1"
    local version="$2"
    local url="${S3_BASE_URL}/archil-${version}.${arch}.rpm"

    log_verbose "Verifying package: $url"

    if curl -sI "$url" | grep -q "HTTP/[12]\.?[0-9]* 200"; then
        log_verbose "✓ Package exists: ${arch}"
        return 0
    else
        log_error "Package not found: ${arch} at $url"
        return 1
    fi
}

# Compute SHA256 hash using nix-prefetch-url
compute_hash() {
    local arch="$1"
    local version="$2"
    local url="${S3_BASE_URL}/archil-${version}.${arch}.rpm"

    log_info "Computing SHA256 hash for ${arch}..."
    log_verbose "URL: $url"

    local hash
    hash=$(nix-prefetch-url "$url" 2>/dev/null || true)

    if [[ -z "$hash" ]]; then
        log_error "Failed to compute hash for ${arch}"
        exit 1
    fi

    log_verbose "Hash: $hash"
    echo "$hash"
}

# Update flake.nix with new version and hashes
update_flake() {
    local new_version="$1"
    local hash_x86_64="$2"
    local hash_aarch64="$3"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "Dry-run mode: Would update flake.nix with:"
        echo "  Version: $new_version" >&2
        echo "  x86_64 hash: $hash_x86_64" >&2
        echo "  aarch64 hash: $hash_aarch64" >&2
        return 0
    fi

    log_info "Updating flake.nix..."

    # Create backup
    cp "$FLAKE_FILE" "${FLAKE_FILE}.backup"
    log_verbose "Created backup: ${FLAKE_FILE}.backup"

    # Update version
    sed -i "s/version = \"[^\"]*\"/version = \"${new_version}\"/" "$FLAKE_FILE"

    # Update x86_64 hash (first occurrence of sha256 in the archil package section)
    # We need to be careful to only update the hashes in the archil package, not other packages
    # Find the line number of 'pname = "archil"' and update hashes after it
    local archil_line
    archil_line=$(grep -n 'pname = "archil"' "$FLAKE_FILE" | cut -d: -f1)

    if [[ -z "$archil_line" ]]; then
        log_error "Could not find archil package definition in flake.nix"
        mv "${FLAKE_FILE}.backup" "$FLAKE_FILE"
        exit 1
    fi

    # Update hashes - we need to update the specific hashes for x86_64 and aarch64
    # The pattern is: if hostPlatform.isAarch64 then { sha256 = "..."; } else { sha256 = "..."; }
    # First hash after archil_line is x86_64 (else branch), second is aarch64 (then branch)

    # Use awk to update hashes more reliably
    awk -v start="$archil_line" -v h1="$hash_x86_64" -v h2="$hash_aarch64" '
    BEGIN { count=0; in_archil=0; }
    NR == start { in_archil=1; }
    in_archil && /sha256 = "/ {
        count++;
        if (count == 1) {
            sub(/sha256 = "[^"]*"/, "sha256 = \"" h2 "\"");
        } else if (count == 2) {
            sub(/sha256 = "[^"]*"/, "sha256 = \"" h1 "\"");
            in_archil=0;
        }
    }
    { print }
    ' "$FLAKE_FILE" > "${FLAKE_FILE}.tmp"

    mv "${FLAKE_FILE}.tmp" "$FLAKE_FILE"

    log_success "Updated flake.nix"
    log_verbose "Backup saved as ${FLAKE_FILE}.backup"
}

# Main execution
main() {
    echo "" >&2
    log_info "Archil Flake Version Updater"
    echo "" >&2

    # Check dependencies
    check_dependencies

    # Get current version
    local current_version
    current_version=$(get_current_version)
    log_info "Current version: $current_version"

    # Get latest version
    local latest_version
    latest_version=$(get_latest_version)
    log_success "Latest version: $latest_version"

    # Compare versions
    if [[ "$current_version" == "$latest_version" ]]; then
        echo "" >&2
        log_success "Already up to date!"
        exit 0
    fi

    echo "" >&2
    log_info "New version available: $current_version → $latest_version"
    echo "" >&2

    # Verify packages exist for both architectures
    log_info "Verifying packages..."
    if ! verify_package "x86_64" "$latest_version"; then
        exit 1
    fi
    if ! verify_package "aarch64" "$latest_version"; then
        exit 1
    fi
    log_success "All packages verified"
    echo "" >&2

    # Compute hashes for both architectures
    local hash_x86_64
    local hash_aarch64

    hash_x86_64=$(compute_hash "x86_64" "$latest_version")
    hash_aarch64=$(compute_hash "aarch64" "$latest_version")

    log_success "Hash computation complete"
    echo "" >&2

    # Update flake.nix
    update_flake "$latest_version" "$hash_x86_64" "$hash_aarch64"

    echo "" >&2
    log_success "Update complete!"
    echo "" >&2

    if [[ "$DRY_RUN" == false ]]; then
        log_info "Next steps:"
        echo "  1. Test the build: nix build" >&2
        echo "  2. Commit the changes: git add flake.nix && git commit -m 'Update archil to $latest_version'" >&2
        echo "" >&2
    fi
}

# Run main function
main "$@"
