# Define custom utilities
# Test for OSX with [ -n "$IS_OSX" ]

function build_wheel {
    local repo_dir=${1:-$REPO_DIR}
    if [ -z "$IS_OSX" ]; then
        build_linux_wheel $@
    else
        build_osx_wheel $@
    fi
}

function build_linux_wheel {
    source multibuild/library_builders.sh

    # Add workaround for auditwheel bug:
    # https://github.com/pypa/auditwheel/issues/29
    export CFLAGS="$CFLAGS"
    build_bdist_wheel $@
}

function build_osx_wheel {
    local repo_dir=${1:-$REPO_DIR}
    local wheelhouse=$(abspath ${WHEEL_SDIR:-wheelhouse})
    # Build dual arch wheel
    export CC=clang
    export CXX=clang++
    install_pkg_config
    # 32-bit wheel
    export CFLAGS="-arch i386"
    export CXXFLAGS="$CFLAGS"
    export FFLAGS="$CFLAGS"
    export LDFLAGS="$CFLAGS"
    # Build libraries
    source multibuild/library_builders.sh
    # Build wheel
    local py_ld_flags="-Wall -undefined dynamic_lookup -bundle"
    local wheelhouse32=${wheelhouse}32
    mkdir -p $wheelhouse32
    export LDFLAGS="$LDFLAGS $py_ld_flags"
    export LDSHARED="clang $LDFLAGS $py_ld_flags"
    build_pip_wheel "$repo_dir"
    mv ${wheelhouse}/*whl $wheelhouse32
    # 64-bit wheel
    export CFLAGS="-arch x86_64"
    export CXXFLAGS="$CFLAGS"
    export FFLAGS="$CFLAGS"
    export LDFLAGS="$CFLAGS"
    unset LDSHARED
    # Force rebuild of all libs
    rm *-stamp

    # Build wheel
    export LDFLAGS="$LDFLAGS $py_ld_flags"
    export LDSHARED="clang $LDFLAGS $py_ld_flags"
    build_pip_wheel "$repo_dir"
    # Fuse into dual arch wheel(s)
    for whl in ${wheelhouse}/*.whl; do
        delocate-fuse "$whl" "${wheelhouse32}/$(basename $whl)"
    done
}

function run_tests {
    # Runs tests on installed distribution from an empty directory
    python --version
	cd py-scrypt/
    python setup.py test
}