# Modern Node.js Development Environment
# Essential tooling for JavaScript/TypeScript development

{ pkgs }:

pkgs.mkShell {
  name = "nodejs-dev";

  buildInputs = with pkgs; [
    # Node.js runtime and package managers
    nodejs_latest
    nodePackages.npm
    nodePackages.yarn
    nodePackages.pnpm

    # TypeScript and language tools
    nodePackages.typescript
    nodePackages.typescript-language-server

    # Linting and formatting (only include packages that exist)
    nodePackages.eslint
    nodePackages.prettier

    # Build system dependencies
    python3 # For node-gyp
    gnumake
    gcc
    pkg-config

    # Additional tools
    git
    curl
    jq
  ];

  shellHook = ''
    echo "🚀 Node.js Development Environment"
    echo "Node.js version: $(node --version)"
    echo "npm version: $(npm --version)"
    echo "yarn version: $(yarn --version)"
    echo "pnpm version: $(pnpm --version)"
    echo ""
    echo "Available tools:"
    echo "  📦 Package Managers: npm, yarn, pnpm"
    echo "  🔧 TypeScript: tsc, ts-node, typescript-language-server"
    echo "  🎨 Linting: eslint, prettier, stylelint"
    echo "  🏗️  Build Tools: webpack, vite, rollup, esbuild"
    echo "  🧪 Testing: jest, mocha, cypress, playwright"
    echo "  ⚛️  React: create-react-app, storybook"
    echo "  🖖 Vue: @vue/cli"
    echo "  🅰️  Angular: @angular/cli"
    echo "  ⚡ Next.js: create-next-app"
    echo "  🔥 Svelte: svelte-language-server"
    echo ""
    echo "Quick start commands:"
    echo "  npm init                    # Initialize new project"
    echo "  npx create-react-app myapp  # Create React app"
    echo "  npx create-next-app myapp   # Create Next.js app"
    echo "  npm run dev                 # Start development server"
    echo ""
    
    # Set up Node.js environment
    export NODE_ENV=development
    export NODE_OPTIONS="--max-old-space-size=8192"
    
    # Enable corepack for package manager management
    corepack enable
    
    # Set up npm configuration for development
    npm config set fund false
    npm config set audit-level moderate
    
    # Create common project structure if not exists
    if [ ! -f package.json ] && [ ! -f .nvmrc ]; then
      echo "💡 Tip: Run 'npm init' to initialize a new Node.js project"
      echo "💡 Tip: Run 'npx create-react-app .' to create a React app in current directory"
    fi
    
    # Show current Node.js and npm configuration
    echo "📍 Current working directory: $(pwd)"
    echo "🔧 Node.js path: $(which node)"
    echo "📦 npm global prefix: $(npm config get prefix)"
  '';

  # Environment variables for Node.js development
  NODE_ENV = "development";
  NODE_OPTIONS = "--max-old-space-size=8192";
  
  # Enable experimental features
  NODE_EXPERIMENTAL_MODULES = "true";
  
  # Disable telemetry for privacy
  NEXT_TELEMETRY_DISABLED = "1";
  GATSBY_TELEMETRY_DISABLED = "1";
  
  # Performance optimizations
  UV_THREADPOOL_SIZE = "128";
  
  # Development convenience
  FORCE_COLOR = "1";
  NPM_CONFIG_COLOR = "always";
}
