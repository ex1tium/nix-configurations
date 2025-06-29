# 🔧 Enhanced Nix Flags System

## 🌟 **Overview**

The installation scripts now use a comprehensive Nix flags system that optimizes performance, reliability, and compatibility for NixOS installations.

## 🎯 **Flag Categories**

### **Base Flags** (`get_nix_flags()`)
Essential flags used by all Nix operations:

| Flag | Value | Purpose |
|------|-------|---------|
| `--extra-experimental-features` | `nix-command` | Enable new Nix CLI |
| `--extra-experimental-features` | `flakes` | Enable flake support |
| `--option warn-dirty` | `false` | Suppress dirty git warnings during installation |
| `--option eval-cache` | `false` | Disable eval cache for fresh builds |
| `--option pure-eval` | `false` | Allow impure evaluation for installation context |
| `--option allow-import-from-derivation` | `true` | Allow IFD for complex builds |
| `--option max-jobs` | `auto` | Use all available CPU cores |
| `--option cores` | `0` | Use all available cores for building |
| `--option keep-going` | `true` | Continue building other derivations on failure |
| `--option substitute` | `true` | Enable binary cache substitution |
| `--option builders-use-substitutes` | `true` | Allow builders to use substitutes |

### **Build-Specific Flags** (`get_nix_build_flags()`)
Additional flags for build operations:

| Flag | Value | Purpose |
|------|-------|---------|
| `--option build-timeout` | `3600` | 1-hour timeout for complex builds |

### **Evaluation-Specific Flags** (`get_nix_eval_flags()`)
Additional flags for evaluation operations:

| Flag | Value | Purpose |
|------|-------|---------|
| `--option restrict-eval` | `false` | Allow unrestricted evaluation |

## 🚀 **Performance Optimizations**

### **Parallel Processing**
- **`max-jobs auto`**: Automatically detects and uses all available CPU cores
- **`cores 0`**: Uses all available cores for individual build jobs
- **Result**: Significantly faster builds on multi-core systems

### **Binary Cache Utilization**
- **`substitute true`**: Enables downloading pre-built packages
- **`builders-use-substitutes true`**: Allows remote builders to use caches
- **Result**: Faster installations by avoiding unnecessary compilation

### **Build Resilience**
- **`keep-going true`**: Continues building other packages if one fails
- **`build-timeout 3600`**: Prevents infinite hangs with 1-hour timeout
- **Result**: More reliable installations that don't fail completely on single package issues

## 🛠️ **Installation-Specific Optimizations**

### **Git Repository Handling**
- **`warn-dirty false`**: Suppresses warnings about uncommitted changes
- **Result**: Clean installation output without distracting warnings

### **Evaluation Context**
- **`pure-eval false`**: Allows access to system information during evaluation
- **`allow-import-from-derivation true`**: Enables complex build patterns
- **Result**: Supports advanced NixOS configurations and hardware detection

### **Cache Management**
- **`eval-cache false`**: Disables evaluation cache during installation
- **Result**: Ensures fresh evaluation of configurations

## 📊 **Usage Examples**

### **Configuration Validation**
```bash
# Uses get_nix_build_flags() for optimal build validation
validate_nix_build ".#nixosConfigurations.elara.config.system.build.toplevel"
```

### **User Detection**
```bash
# Uses get_nix_eval_flags() for configuration evaluation
detect_primary_user_from_flake /tmp/nix-config
```

### **Manual Usage**
```bash
# Get flags for custom operations
flags=$(get_nix_flags)
nix $flags flake check

# Build-specific operations
build_flags=$(get_nix_build_flags)
nix $build_flags build .#nixosConfigurations.machine

# Evaluation operations
eval_flags=$(get_nix_eval_flags)
nix $eval_flags eval .#globalConfig.defaultUser
```

## 🔍 **Troubleshooting**

### **Common Issues Resolved**

1. **"unrecognised flag" errors**: Fixed by proper flag formatting
2. **Slow builds**: Optimized with parallel processing flags
3. **Cache misses**: Improved with substitution flags
4. **Evaluation restrictions**: Resolved with evaluation flags
5. **Build timeouts**: Managed with timeout settings

### **Debug Information**
```bash
# View current flags
source scripts/lib/common.sh
echo "Base flags: $(get_nix_flags)"
echo "Build flags: $(get_nix_build_flags)"
echo "Eval flags: $(get_nix_eval_flags)"
```

## 🎯 **Benefits**

### **Performance Improvements**
- **Faster builds**: Multi-core utilization and binary caches
- **Reduced wait times**: Parallel processing and substitution
- **Better resource usage**: Optimal CPU and network utilization

### **Reliability Enhancements**
- **Fault tolerance**: Continue on individual package failures
- **Timeout protection**: Prevent infinite hangs
- **Clean output**: Suppress irrelevant warnings

### **Compatibility**
- **Modern Nix features**: Full flakes and new CLI support
- **Installation context**: Proper handling of installation environment
- **Complex configurations**: Support for advanced NixOS patterns

## 🔮 **Future Enhancements**

### **Planned Additions**
- **Memory optimization flags**: For low-memory systems
- **Network optimization**: For slow connections
- **Debug flags**: For troubleshooting builds
- **Profile-specific flags**: Different flags for different machine types

### **Adaptive Flags**
- **System detection**: Automatically adjust flags based on system capabilities
- **Network detection**: Optimize for connection speed
- **Resource detection**: Adjust parallelism based on available resources

The enhanced Nix flags system ensures optimal performance, reliability, and compatibility for all NixOS installation scenarios!
