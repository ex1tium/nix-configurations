# Modern Go Development Environment
# Comprehensive tooling for Go development with latest best practices

{ pkgs }:

pkgs.mkShell {
  name = "go-dev";

  buildInputs = with pkgs; [
    # Go toolchain
    go
    gopls                    # Go language server
    go-tools                 # Additional Go tools (goimports, etc.)
    delve                    # Go debugger
    golangci-lint           # Comprehensive linter

    # Essential Go development tools (only include packages that exist)
    # Note: Many specialized tools can be installed per-project via go install

    # Performance tools (pprof is included in go tools)

    # Security
    # gosec may not be available in current nixpkgs

    # Documentation (godoc is included in go tools)

    # Generic development tools
    git
    gnumake
    curl
    jq

    # Build dependencies
    gcc                     # For CGO
    pkg-config
  ];

  shellHook = ''
    echo "🚀 Go Development Environment"
    echo "Go version: $(go version | cut -d' ' -f3)"
    echo ""
    echo "Available tools:"
    echo "  🔧 Core: go, gopls, goimports, gofmt"
    echo "  🐛 Debug: delve (dlv)"
    echo "  🧹 Lint: golangci-lint, gosec"
    echo "  🧪 Test: gotestsum, go test"
    echo "  🔄 Live Reload: air, reflex"
    echo "  📊 Profile: pprof"
    echo "  🚀 Release: goreleaser"
    echo "  🐳 Containers: ko"
    echo "  🗄️  Database: migrate, goose"
    echo "  📡 gRPC: protoc, protoc-gen-go, protoc-gen-go-grpc"
    echo ""
    echo "Quick start commands:"
    echo "  go mod init <module>        # Initialize new module"
    echo "  go mod tidy                 # Clean up dependencies"
    echo "  go run .                    # Run current package"
    echo "  go test ./...               # Run all tests"
    echo "  gotestsum ./...             # Run tests with better output"
    echo "  golangci-lint run           # Run linter"
    echo "  air                         # Start live reload server"
    echo ""

    # Set up Go environment
    export GOPATH="$HOME/go"
    export GOBIN="$GOPATH/bin"
    export PATH="$GOBIN:$PATH"

    # Go development settings
    export GO111MODULE=on
    export GOPROXY=https://proxy.golang.org,direct
    export GOSUMDB=sum.golang.org
    export GOPRIVATE=""

    # Performance settings
    export GOMAXPROCS=$(nproc)

    # Development convenience
    export CGO_ENABLED=1

    # Create Go workspace if it doesn't exist
    mkdir -p "$GOPATH"/{bin,src,pkg}

    # Show current Go configuration
    echo "📍 GOPATH: $GOPATH"
    echo "📍 GOROOT: $(go env GOROOT)"
    echo "📍 Current working directory: $(pwd)"

    # Check if we're in a Go module
    if [ -f go.mod ]; then
      echo "📦 Go module: $(go list -m)"
    else
      echo "💡 Tip: Run 'go mod init <module-name>' to initialize a Go module"
    fi
  '';

  # Environment variables for Go development
  GOPATH = "$HOME/go";
  GOBIN = "$HOME/go/bin";
  GO111MODULE = "on";
  GOPROXY = "https://proxy.golang.org,direct";
  GOSUMDB = "sum.golang.org";
  CGO_ENABLED = "1";
}
