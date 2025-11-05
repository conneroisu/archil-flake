# Design: NixOS Module for Archil

## Context

The Archil client currently exists as a standalone Nix package that users must manually configure with systemd services, mount points, and authentication. NixOS users expect declarative configuration through modules, where infrastructure is defined in code and automatically managed by the system. This change introduces a NixOS module to bridge this gap.

**Constraints:**
- Archil CLI binary is proprietary and cannot be modified
- Authentication supports two methods: IAM roles (AWS-specific) and static tokens
- FUSE filesystems require kernel module and proper permissions
- Mounts must survive system reboots and handle network failures gracefully

**Stakeholders:**
- NixOS users deploying Archil on bare metal or cloud infrastructure
- DevOps teams managing Archil configurations declaratively
- Users needing secure credential management in multi-tenant environments

## Goals / Non-Goals

**Goals:**
- Provide declarative configuration for all Archil mount scenarios
- Support both IAM and token authentication methods
- Generate systemd services with proper dependencies and restart policies
- Validate configuration at evaluation time to catch errors early
- Enable secure credential management (no plaintext tokens in Nix store)
- Maintain backwards compatibility with standalone package usage

**Non-Goals:**
- Modify the Archil binary or wrapper behavior
- Implement Archil disk management (create/delete disks) - only mounting
- Support non-Linux platforms or non-systemd init systems
- Provide GUI or web interface for configuration
- Handle Archil account registration or billing

## Decisions

### Decision: Attribute Set for Mounts
Use `services.archil.mounts.<name>` attribute set rather than a list.

**Rationale:**
- Provides stable, semantic names for each mount (e.g., `mounts.data-disk`)
- Easier to reference and override in NixOS configuration layers
- Aligns with NixOS conventions (see `fileSystems.<name>`, `systemd.services.<name>`)
- Names are used for systemd service naming: `archil-mount-<name>.service`

**Alternatives considered:**
- List of mount configurations: Harder to override, no semantic naming
- Flat top-level options: Doesn't scale to multiple mounts

### Decision: Separate authToken and authTokenFile
Provide both `authToken` (string) and `authTokenFile` (path) options.

**Rationale:**
- `authToken` for simple cases and testing (value goes to Nix store - warn users)
- `authTokenFile` for production - references file outside Nix store
- Follows established patterns (e.g., `services.postgresql.passwordFile`)
- Enables integration with secrets management tools (agenix, sops-nix)

**Alternatives considered:**
- Only authToken: Insecure for production (plaintext in store)
- Only authTokenFile: Inconvenient for development and testing
- Automatic detection: Too implicit, error-prone

### Decision: Use systemd LoadCredential for Token Files
When `authTokenFile` is used, employ systemd's `LoadCredential` feature.

**Rationale:**
- Systemd's credential loading provides additional security isolation
- Credentials are only accessible to the specific service
- Works with systemd's encrypted credentials feature
- Standard practice for sensitive data in systemd services

**Implementation:**
```nix
serviceConfig = {
  LoadCredential = lib.optionalString (cfg.authTokenFile != null)
    "archil-token:${cfg.authTokenFile}";
};
ExecStart = if cfg.authMethod == "token" then
  "${archil}/bin/archil mount ${diskName} ${mountPoint} --region ${region} --auth-token $(cat $CREDENTIALS_DIRECTORY/archil-token)"
else
  "${archil}/bin/archil mount ${diskName} ${mountPoint} --region ${region}";
```

### Decision: ExecStartPre Creates Mount Points
Use systemd's `ExecStartPre` to create mount point directories.

**Rationale:**
- Declarative configurations shouldn't require pre-existing directories
- Prevents common "mount point doesn't exist" errors
- Aligns with NixOS philosophy (system configuration creates needed resources)

**Implementation:**
```nix
ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${mountPoint}";
```

### Decision: Graceful Unmount with Fallback
Primary unmount via `archil unmount`, fallback to `umount`.

**Rationale:**
- `archil unmount` may perform cleanup or state management
- `umount` fallback ensures unmount succeeds even if Archil client is unavailable
- Prevents stuck mount points during system shutdown

**Implementation:**
```nix
ExecStop = pkgs.writeShellScript "unmount" ''
  ${archil}/bin/archil unmount ${mountPoint} || ${pkgs.utillinux}/bin/umount ${mountPoint}
'';
```

### Decision: Restart Policy with Backoff
Configure automatic restart with exponential backoff for mount failures.

**Rationale:**
- Network issues or Archil service outages are transient
- Exponential backoff prevents log spam and resource exhaustion
- Matches NixOS best practices for network-dependent services

**Implementation:**
```nix
serviceConfig = {
  Restart = "on-failure";
  RestartSec = "10s";
  RestartMaxDelaySec = "5min";
};
```

### Decision: FUSE Module via boot.kernelModules
Load FUSE kernel module globally rather than per-service.

**Rationale:**
- FUSE module should be available early in boot process
- Multiple services may need FUSE (not just Archil)
- `boot.kernelModules` is the NixOS standard for kernel module loading

**Implementation:**
```nix
config = lib.mkIf cfg.enable {
  boot.kernelModules = [ "fuse" ];
};
```

## Risks / Trade-offs

### Risk: Token in Nix Store
**Description:** Users providing `authToken` directly puts the token in world-readable Nix store.

**Mitigation:**
- Clear documentation warning about this behavior
- Recommend `authTokenFile` for all production deployments
- Consider adding a warning at evaluation time when authToken is used

### Risk: Mount Failures on Boot
**Description:** If Archil service or network is unavailable at boot, mounts will fail and retry.

**Mitigation:**
- Proper systemd dependencies (`network-online.target`)
- Automatic restart with exponential backoff
- Documentation on `wantedBy` vs `requiredBy` for critical vs optional mounts

### Risk: Stale Mounts After Network Changes
**Description:** Network failures may leave FUSE mounts in bad state.

**Mitigation:**
- Systemd's restart mechanism handles this for persistent failures
- Users can configure `TimeoutSec` and `RestartSec` per their needs
- Document manual recovery: `systemctl restart archil-mount-<name>`

### Trade-off: IAM Role Detection
**Behavior:** When `authMethod = "iam"`, we don't validate IAM role exists.

**Rationale:**
- IAM role availability is runtime-dependent (EC2 instance metadata)
- NixOS evaluation happens at build time, not runtime
- Failure will be caught when service starts with clear error from Archil CLI

**Documentation Needed:**
- IAM role requirements (EC2 instance profile or ECS task role)
- Testing IAM access: `archil mount ... --region ...` without --auth-token

## Migration Plan

### For New Users
1. Add flake input: `inputs.archil-flake.url = "github:conneroisu/archil-flake";`
2. Import module: `imports = [ inputs.archil-flake.nixosModules.default ];`
3. Configure mounts in `services.archil.mounts.<name>`
4. Run `nixos-rebuild switch`

### For Existing Users
No migration required - backward compatible. Users with manual systemd services can:
1. Keep existing setup (package still works standalone)
2. Gradually migrate to declarative module configuration
3. Remove manual systemd services once module configuration is tested

### Rollback
If module has issues, users can:
1. Set `services.archil.enable = false;`
2. Revert to manual mount commands or previous systemd service definitions
3. Rebuild system - no persistent state changes

## Open Questions

1. **Should we support non-systemd init systems?**
   - Initial scope: systemd only (standard for NixOS)
   - Future: Could extract mount logic for other init systems if demand exists

2. **Should we validate region format?**
   - Current: Accept any string, let Archil CLI validate
   - Alternative: Enumerate known regions and validate at eval time
   - Decision: Keep flexible - Archil may add regions, enum would require updates

3. **Should we support automatic disk discovery/listing?**
   - Would require API calls at evaluation time (impure)
   - Current design: User explicitly lists disks to mount
   - Future: Could add imperative command: `archil-list-disks`

4. **How to handle mount point conflicts?**
   - If user configures same mountPoint in multiple mounts, systemd will fail
   - Should we validate uniqueness at eval time?
   - Decision: Yes - add assertion checking all mountPoints are unique

5. **Support for read-only mounts?**
   - Archil CLI may support read-only flags (check documentation)
   - If supported, add `readOnly = lib.mkOption { type = types.bool; default = false; };`
   - Add `--read-only` flag to mount command when enabled
