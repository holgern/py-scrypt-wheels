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

function build_openssl {
OPENSSL_URL="https://www.openssl.org/source/"
OPENSSL_NAME="openssl-1.1.0e"
OPENSSL_SHA256="57be8618979d80c910728cfc99369bf97b2a1abd8f366ab6ebdee8975ad3874c"

function check_sha256sum {
    local fname=$1
    local sha256=$2
    echo "${sha256}  ${fname}" > ${fname}.sha256
    sha256sum -c ${fname}.sha256
    rm ${fname}.sha256
}

curl -#O ${OPENSSL_URL}/${OPENSSL_NAME}.tar.gz
check_sha256sum ${OPENSSL_NAME}.tar.gz ${OPENSSL_SHA256}
tar zxvf ${OPENSSL_NAME}.tar.gz
PATH=/opt/perl/bin:$PATH
cd ${OPENSSL_NAME}
if [[ $1 == "x86_64" ]]; then
    echo "Configuring for x86_64"
    ./Configure linux-x86_64 no-ssl2 no-comp enable-ec_nistp_64_gcc_128 shared --prefix=/usr/local --openssldir=/usr/local
else
    echo "Configuring for i686"
    ./Configure linux-generic32 no-ssl2 no-comp shared --prefix=/usr/local --openssldir=/usr/local
fi
make depend
make install
}

function build_linux_wheel {
    source multibuild/library_builders.sh
	build_openssl
    # Add workaround for auditwheel bug:
    # https://github.com/pypa/auditwheel/issues/29
    export CFLAGS="$CFLAGS -I/usr/include -I/usr/local/include"
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