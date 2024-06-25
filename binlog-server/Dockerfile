FROM redhat/ubi9-minimal

RUN set -ex; \
        export GNUPGHOME="$(mktemp -d)"; \
        gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F; \
        gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
        gpg --batch --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > ${GNUPGHOME}/RPM-GPG-KEY-oracle; \
        rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona  ${GNUPGHOME}/RPM-GPG-KEY-oracle; \
        microdnf install -y findutils; \
        curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
        rpmkeys --checksig /tmp/percona-release.rpm; \
        rpm -i /tmp/percona-release.rpm; \
        rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
        rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
        percona-release enable-only tools release; \
        percona-release enable ps-80 release

RUN microdnf install -y git cmake gcc gcc-c++ percona-server-devel zlib-devel openssl-devel libcurl-devel libatomic

ENV BUILD_CONFIGURATION=Debug
ENV BUILD_CC=gcc
ENV BUILD_CXX=g++

RUN mkdir /binlog-server
WORKDIR /binlog-server

RUN git clone --recurse-submodules --jobs=8 https://github.com/boostorg/boost.git; \
    cd boost; \
    git checkout --recurse-submodules -b required_release boost-1.84.0;

RUN cmake \
        -B ./boost-build-${BUILD_CONFIGURATION} \
        -S ./boost \
        -DCMAKE_INSTALL_PREFIX=./boost-install-${BUILD_CONFIGURATION} \
        -DCMAKE_BUILD_TYPE=${BUILD_CONFIGURATION} \
        -DCMAKE_C_COMPILER=${BUILD_CC} \
        -DCMAKE_CXX_COMPILER=${BUILD_CXX} \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTING=OFF

RUN cmake --build ./boost-build-${BUILD_CONFIGURATION} --config ${BUILD_CONFIGURATION} --parallel
RUN cmake --install ./boost-build-${BUILD_CONFIGURATION} --config ${BUILD_CONFIGURATION}

RUN git clone --recurse-submodules --jobs=8 https://github.com/aws/aws-sdk-cpp; \
    cd aws-sdk-cpp; \
    git checkout --recurse-submodules -b required_release 1.11.286;


RUN cmake \
        -B ./aws-sdk-cpp-build-${BUILD_CONFIGURATION} \
        -S ./aws-sdk-cpp \
        -DCMAKE_INSTALL_PREFIX=./aws-sdk-cpp-install-${BUILD_CONFIGURATION} \
        -DCMAKE_BUILD_TYPE=${BUILD_CONFIGURATION} \
        -DCMAKE_C_COMPILER=${BUILD_CC} \
        -DCMAKE_CXX_COMPILER=${BUILD_CXX} \
        -DCPP_STANDARD=20 \
        -DENABLE_UNITY_BUILD=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DFORCE_SHARED_CRT=OFF \
        -DENABLE_TESTING=OFF \
        -DAUTORUN_UNIT_TESTS=OFF \
        -DBUILD_ONLY=s3-crt

RUN cmake --build ./aws-sdk-cpp-build-${BUILD_CONFIGURATION} --config ${BUILD_CONFIGURATION} --parallel
RUN cmake --install ./aws-sdk-cpp-build-${BUILD_CONFIGURATION} --config ${BUILD_CONFIGURATION}

RUN git clone https://github.com/Percona-Lab/percona-binlog-server.git

RUN cmake  \
  -B ./percona-binlog-server-build-${BUILD_CONFIGURATION} \
  -S ./percona-binlog-server \
  -DCMAKE_BUILD_TYPE=${BUILD_CONFIGURATION} \
  -DCMAKE_C_COMPILER=${BUILD_CC} \
  -DCMAKE_CXX_COMPILER=${BUILD_CXX} \
  -DCPP_STANDARD=20 \
  -DCMAKE_PREFIX_PATH=${PWD}/aws-sdk-cpp-install-${BUILD_CONFIGURATION} \
  -DBoost_ROOT=${PWD}/boost-install-${BUILD_CONFIGURATION}

RUN cmake --build ./percona-binlog-server-build-${BUILD_CONFIGURATION} --config ${BUILD_CONFIGURATION} --parallel

RUN cp percona-binlog-server-build-${BUILD_CONFIGURATION}/binlog_server /usr/local/bin/binlog_server


