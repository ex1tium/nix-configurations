# Modern Python Development Environment
# Comprehensive tooling for Python development with latest best practices

{ pkgs }:

pkgs.mkShell {
  name = "python-dev";
  
  buildInputs = with pkgs; [
    # Python runtime and tools
    python3
    python3Packages.pip
    python3Packages.setuptools
    python3Packages.wheel
    
    # Virtual environment management
    python3Packages.virtualenv
    poetry  # Poetry is now a top-level package
    
    # Essential development tools (only include packages that exist)
    python3Packages.black
    python3Packages.pytest
    # Note: Many Python packages can be installed per-project via pip/poetry
    # Build dependencies
    gcc
    pkg-config

    # Additional tools
    git
    curl
    jq


    gnumake
    curl
    jq
    
    # System dependencies for common packages
    gcc
    pkg-config
    openssl
    libffi
    zlib
    
    # Database clients
    postgresql
    sqlite
    redis
  ];

  shellHook = ''
    echo "🐍 Python Development Environment"
    echo "Python version: $(python --version)"
    echo "pip version: $(pip --version | cut -d' ' -f2)"
    echo ""
    echo "Available tools:"
    echo "  🔧 Core: python3, pip, setuptools, wheel"
    echo "  🏠 Virtual Envs: virtualenv, pipenv, poetry"
    echo "  🎨 Formatting: black, isort, autopep8"
    echo "  🧹 Linting: flake8, pylint, bandit"
    echo "  🔍 Type Checking: mypy, pyright"
    echo "  🧪 Testing: pytest, tox, coverage"
    echo "  📊 Data Science: pandas, numpy, matplotlib, jupyter"
    echo "  🌐 Web: django, flask, fastapi"
    echo "  🗄️  Database: sqlalchemy, alembic"
    echo "  📚 Documentation: sphinx, mkdocs"
    echo ""
    echo "Quick start commands:"
    echo "  python -m venv venv         # Create virtual environment"
    echo "  source venv/bin/activate    # Activate virtual environment"
    echo "  pip install -r requirements.txt  # Install dependencies"
    echo "  poetry init                 # Initialize Poetry project"
    echo "  poetry install              # Install Poetry dependencies"
    echo "  pytest                      # Run tests"
    echo "  black .                     # Format code"
    echo "  flake8 .                    # Lint code"
    echo "  mypy .                      # Type check"
    echo "  jupyter lab                 # Start Jupyter Lab"
    echo ""
    
    # Set up Python environment
    export PYTHONPATH="$PWD:$PYTHONPATH"
    export PIP_REQUIRE_VIRTUALENV=false
    export PIP_DISABLE_PIP_VERSION_CHECK=1
    export PYTHONDONTWRITEBYTECODE=1
    export PYTHONUNBUFFERED=1
    
    # Development settings
    export DJANGO_SETTINGS_MODULE=settings.development
    export FLASK_ENV=development
    export FLASK_DEBUG=1
    
    # Jupyter settings
    export JUPYTER_CONFIG_DIR="$HOME/.jupyter"
    
    # Create common directories
    mkdir -p .pytest_cache
    mkdir -p htmlcov
    
    # Show current Python configuration
    echo "📍 Python path: $(which python)"
    echo "📍 Current working directory: $(pwd)"
    
    # Check for common Python project files
    if [ -f requirements.txt ]; then
      echo "📦 Found requirements.txt"
    fi
    
    if [ -f pyproject.toml ]; then
      echo "📦 Found pyproject.toml (Poetry/PEP 518 project)"
    fi
    
    if [ -f setup.py ]; then
      echo "📦 Found setup.py"
    fi
    
    if [ -f Pipfile ]; then
      echo "📦 Found Pipfile (Pipenv project)"
    fi
    
    if [ -f manage.py ]; then
      echo "🌐 Django project detected"
    fi
    
    if [ -f app.py ] || [ -f main.py ]; then
      echo "🌐 Flask/FastAPI project detected"
    fi
    
    if [ ! -f requirements.txt ] && [ ! -f pyproject.toml ] && [ ! -f Pipfile ]; then
      echo "💡 Tip: Create requirements.txt or use 'poetry init' to manage dependencies"
    fi
  '';

  # Environment variables for Python development
  PYTHONPATH = "$PWD";
  PIP_REQUIRE_VIRTUALENV = "false";
  PIP_DISABLE_PIP_VERSION_CHECK = "1";
  PYTHONDONTWRITEBYTECODE = "1";
  PYTHONUNBUFFERED = "1";
  
  # Development convenience
  DJANGO_SETTINGS_MODULE = "settings.development";
  FLASK_ENV = "development";
  FLASK_DEBUG = "1";
}
