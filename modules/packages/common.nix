# Shared Package Collections
# Centralized package definitions to reduce duplication across modules
# This module provides reusable package collections for different use cases

{ pkgs }:

{
  # Core CLI Tools - Modern replacements for traditional Unix tools
  # Used across all profiles for enhanced command-line experience
  cliTools = with pkgs; [
    bat          # Better cat with syntax highlighting
    eza          # Better ls with colors and icons
    fd           # Better find with intuitive syntax
    ripgrep      # Better grep with speed and features
    fzf          # Fuzzy finder for interactive filtering
    zoxide       # Better cd with intelligent directory jumping
    htop         # Interactive process viewer
    btop         # Modern resource monitor
  ];

  # Essential System Tools - Basic utilities needed on all systems
  # Core tools for system administration and basic operations
  systemTools = with pkgs; [
    vim          # Text editor (fallback)
    nano         # User-friendly text editor
    git          # Version control system
    curl         # HTTP client
    wget         # File downloader
    tree         # Directory structure viewer
    file         # File type identification
    which        # Command location finder
  ];

  # System Utilities - Process and system management tools
  # Tools for monitoring and managing system resources
  systemUtilities = with pkgs; [
    lsof         # List open files
    psmisc       # Process utilities (killall, pstree, etc.)
    procps       # Process monitoring utilities
    util-linux   # Essential Linux utilities
  ];

  # Network Tools - Basic networking utilities
  # Essential tools for network diagnostics and operations
  networkTools = with pkgs; [
    inetutils    # Basic network utilities (ping, telnet, etc.)
    dnsutils     # DNS lookup utilities (dig, nslookup)
  ];

  # Archive Tools - File compression and extraction
  # Support for various archive formats
  archiveTools = with pkgs; [
    zip          # ZIP archive creation
    unzip        # ZIP archive extraction
    p7zip        # 7-Zip archive support
  ];

  # Security Tools - Basic security utilities
  # Essential tools for encryption and security
  securityTools = with pkgs; [
    gnupg        # GNU Privacy Guard
    pinentry     # PIN entry for GPG
  ];

  # Development Core Tools - Essential development utilities
  # Basic tools needed for any development work
  developmentCore = with pkgs; [
    git          # Version control (primary)
    gh           # GitHub CLI
    git-lfs      # Git Large File Storage
    git-crypt    # Git encryption
  ];

  # Build Tools - Compilation and build system tools
  # Tools for building software from source
  buildTools = with pkgs; [
    gnumake      # GNU Make build system
    cmake        # Cross-platform build system
    pkg-config   # Package configuration tool
    autoconf     # Automatic configure script builder
    automake     # Automatic Makefile generator
    libtool      # Generic library support script
    gcc          # GNU Compiler Collection
    clang        # LLVM C/C++ compiler
    llvm         # LLVM compiler infrastructure
  ];

  # Development CLI Tools - Enhanced command-line tools for development
  # Modern tools that improve development workflow
  developmentCli = with pkgs; [
    direnv       # Environment variable management
    just         # Command runner (alternative to make)
    jq           # JSON processor
    yq           # YAML processor
  ];

  # Debugging Tools - Software debugging and analysis
  # Tools for debugging and profiling applications
  debuggingTools = with pkgs; [
    gdb          # GNU Debugger
    lldb         # LLVM Debugger
    strace       # System call tracer
    ltrace       # Library call tracer
    valgrind     # Memory debugging and profiling
  ];

  # Development Network Tools - Network tools for development
  # Enhanced network utilities for development and testing
  developmentNetwork = with pkgs; [
    httpie       # User-friendly HTTP client
    netcat       # Network utility for reading/writing network connections
    socat        # Multipurpose relay tool
  ];

  # Development Archive Tools - Additional archive tools for development
  # Extended archive support for development workflows
  developmentArchive = with pkgs; [
    gnutar       # GNU tar archiver
    gzip         # GNU zip compression
  ];

  # Development Monitoring - System monitoring for development
  # Additional monitoring tools for development environments
  developmentMonitoring = with pkgs; [
    iotop        # I/O monitoring
  ];

  # Text Processing Tools - Text manipulation utilities
  # Tools for processing and manipulating text files
  textProcessing = with pkgs; [
    gnused       # GNU stream editor
    gawk         # GNU AWK text processing
    gnugrep      # GNU grep pattern matching
  ];

  # Version Control Systems - Alternative VCS tools
  # Support for version control systems other than Git
  versionControl = with pkgs; [
    mercurial    # Mercurial VCS
    subversion   # Apache Subversion VCS
  ];

  # Documentation Tools - Documentation and manual tools
  # Tools for accessing and managing documentation
  documentationTools = with pkgs; [
    man-pages         # Linux manual pages
    man-pages-posix   # POSIX manual pages
  ];

  # Desktop Applications - Essential desktop software
  # Core applications for desktop productivity
  desktopApplications = with pkgs; [
    firefox           # Web browser
    brave             # Privacy-focused browser
    libreoffice-fresh # Office suite
    thunderbird       # Email client
  ];

  # Media Applications - Multimedia software
  # Applications for media playback and editing
  mediaApplications = with pkgs; [
    vlc          # Media player
    mpv          # Lightweight media player
    gimp         # Image editor
  ];

  # Desktop Utilities - Desktop system utilities
  # Utility applications for desktop environments
  desktopUtilities = with pkgs; [
    gparted      # Partition editor
  ];

  # Image Viewers - Image viewing applications
  # Lightweight image viewing tools
  imageViewers = with pkgs; [
    feh          # Lightweight image viewer
    evince       # Document viewer (PDF, etc.)
  ];

  # Terminal Emulators - Terminal applications
  # Modern terminal emulator options
  terminalEmulators = with pkgs; [
    alacritty    # GPU-accelerated terminal
  ];

  # Multimedia Codecs - Audio/video codec support
  # GStreamer plugins for multimedia support
  multimediaCodecs = with pkgs; [
    gst_all_1.gstreamer           # GStreamer framework
    gst_all_1.gst-plugins-base    # Base plugins
    gst_all_1.gst-plugins-good    # Good quality plugins
    gst_all_1.gst-plugins-bad     # Experimental plugins
    gst_all_1.gst-plugins-ugly    # Plugins with licensing issues
    gst_all_1.gst-libav          # FFmpeg integration
  ];

  # Desktop Network Tools - Network utilities for desktop
  # Network management tools for desktop environments
  desktopNetwork = with pkgs; [
    networkmanagerapplet  # NetworkManager GUI
  ];

  # Server Container Tools - Container management for servers
  # Essential tools for container orchestration and management
  serverContainers = with pkgs; [
    docker-compose    # Docker Compose
    podman-compose    # Podman Compose
    buildah          # Container image builder
    skopeo           # Container image operations
  ];

  # Server Virtualization - Virtualization tools for servers
  # Core virtualization infrastructure
  serverVirtualization = with pkgs; [
    qemu_kvm         # QEMU with KVM support
    libvirt          # Virtualization management
  ];

  # Server Monitoring - System monitoring for servers
  # Essential monitoring tools for server environments
  serverMonitoring = with pkgs; [
    iotop            # I/O monitoring
    nethogs          # Network bandwidth monitoring
    iftop            # Network interface monitoring
  ];

  # Server Network Tools - Network tools for servers
  # Advanced networking tools for server administration
  serverNetwork = with pkgs; [
    nmap             # Network discovery and security auditing
    tcpdump          # Network packet analyzer
    iperf3           # Network performance measurement
    mtr              # Network diagnostic tool
  ];

  # Server Security - Security tools for servers
  # Security and intrusion prevention tools
  serverSecurity = with pkgs; [
    fail2ban         # Intrusion prevention system
  ];

  # Server Backup - Backup and synchronization tools
  # Tools for data backup and synchronization
  serverBackup = with pkgs; [
    rsync            # File synchronization
    borgbackup       # Deduplicating backup program
  ];

  # Server Utilities - Server administration utilities
  # Essential utilities for server management
  serverUtilities = with pkgs; [
    tmux             # Terminal multiplexer
    screen           # Terminal session manager
    strace           # System call tracer
  ];

  # Server Security Scanning - Security analysis tools
  # Tools for security scanning and vulnerability assessment
  serverSecurityScanning = with pkgs; [
    trivy            # Container security scanner
  ];

  # Machine-Specific VM Tools - Virtual machine integration
  # Tools for VM guest integration and management
  vmTools = with pkgs; [
    spice-vdagent    # SPICE guest agent
    qemu_kvm         # QEMU guest agent
  ];

  # Home Manager CLI Tools - User-level CLI tools
  # CLI tools installed at user level through Home Manager
  homeCliTools = with pkgs; [
    bat              # Better cat
    eza              # Better ls
    fd               # Better find
    ripgrep          # Better grep
    fzf              # Fuzzy finder
    zoxide           # Better cd
  ];
}
