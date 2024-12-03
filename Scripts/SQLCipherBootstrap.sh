#
#  SQLCipherBootstrap.sh
#  SwiftSQLite
#
#  Created by Moshe Gottlieb on 02.12.24.
#

#!/bin/bash

set -e

VERSION=4.6.1
ARCHIVE=v${VERSION}
TARGZ=${ARCHIVE}.tar.gz
SRC_DIR="sqlcipher-${VERSION}"
SRC_URL=https://github.com/sqlcipher/sqlcipher/archive/refs/tags/${TARGZ}
CCIPHER_DIR="Sources/CSQLCipher"


function cleanup(){
    rm -f "${TARGZ}"
    rm -rf "${SRC_DIR}"
}


# cleanup

cleanup

curl -Lo "${TARGZ}" "${SRC_URL}"
tar zxf "${TARGZ}"
pushd "${SRC_DIR}"

if [ "$(file_os)" = "Darwin" ]; then
    ./configure --enable-all --with-crypto-lib=none 
else
    ./configure --enable-all
fi

make sqlite3.c
popd
cp "${SRC_DIR}/sqlite3.c" "${CCIPHER_DIR}"
cp "${SRC_DIR}/sqlite3.h" "${CCIPHER_DIR}/include"

cleanup
