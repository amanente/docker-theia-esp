FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive

#Common deps
RUN apt-get update && apt-get -y install curl xz-utils wget gpg  gcc git wget make libncurses-dev flex bison gperf \
                                         python python-serial cmake ninja-build nano vim ccache picocom  unrar-free \ 
                                         autoconf automake libtool libtool-bin g++ texinfo gawk ncurses-dev libexpat-dev \
                                         sed  unzip bash help2man  bzip2


#Install node and yarn
#From: https://github.com/nodejs/docker-node/blob/6b8d86d6ad59e0d1e7a94cec2e909cad137a028f/8/Dockerfile

# gpg keys listed at https://github.com/nodejs/node#release-keys
RUN set -ex \
    && for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    ; do \
    gpg --batch --keyserver ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver pgp.mit.edu --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.pgp.com --recv-keys "$key" || \
    gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
    done


ENV NODE_VERSION 8.14.1

RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
    && case "${dpkgArch##*-}" in \
    amd64) ARCH='x64';; \
    ppc64el) ARCH='ppc64le';; \
    s390x) ARCH='s390x';; \
    arm64) ARCH='arm64';; \
    armhf) ARCH='armv7l';; \
    i386) ARCH='x86';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
    && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
    && curl -SLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs

ENV YARN_VERSION 1.13.0

RUN set -ex \
    && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
    ; do \
    gpg --batch --keyserver ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver pgp.mit.edu --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.pgp.com --recv-keys "$key" || \
    gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
    done \
    && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
    && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
    && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
    && mkdir -p /opt/yarn \
    && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/yarn --strip-components=1 \
    && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
    && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarnpkg \
    && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz

#Developer tools

## Git and sudo (sudo needed for user override)
RUN apt-get -y install git sudo




#C/C++
# public LLVM PPA, development version of LLVM
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    echo "deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic main" > /etc/apt/sources.list.d/llvm.list && \
    apt-get update && apt-get install -y clang-tools-9 && \
    ln -s /usr/bin/clangd-9 /usr/bin/clangd

#Python 2
RUN apt-get update && apt-get install -y python python-pip && \
    pip install python-language-server;


## User account
RUN adduser --disabled-password --gecos '' theia && \
    adduser theia sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers;

RUN chmod g+rw /home && \
    mkdir -p /home/project && \
    chown -R theia:theia /home/theia && \
    chown -R theia:theia /home/project;

#Theia
##Needed for node-gyp, nsfw build
RUN apt-get update && apt-get install -y python build-essential



ENV ESP_TCHAIN_BASEDIR /opt/local/espressif

RUN mkdir -p $ESP_TCHAIN_BASEDIR \
    && wget -O $ESP_TCHAIN_BASEDIR/esp32-toolchain.tar.gz \
            https://dl.espressif.com/dl/xtensa-esp32-elf-linux64-1.22.0-80-g6c4433a-5.2.0.tar.gz \
    && tar -xzf $ESP_TCHAIN_BASEDIR/esp32-toolchain.tar.gz \
           -C $ESP_TCHAIN_BASEDIR/ \
    && rm $ESP_TCHAIN_BASEDIR/esp32-toolchain.tar.gz

RUN mkdir -p $ESP_TCHAIN_BASEDIR \
    && wget -O $ESP_TCHAIN_BASEDIR/esp32ulp-toolchain.tar.gz \
            https://dl.espressif.com/dl/esp32ulp-elf-binutils-linux64-d2ae637d.tar.gz \
    && tar -xzf $ESP_TCHAIN_BASEDIR/esp32ulp-toolchain.tar.gz \
           -C $ESP_TCHAIN_BASEDIR/ \
    && rm $ESP_TCHAIN_BASEDIR/esp32ulp-toolchain.tar.gz

# Setup IDF_PATH
ENV IDF_PATH /esp/esp-idf
RUN mkdir -p $IDF_PATH

ENV PATH $ESP_TCHAIN_BASEDIR/xtensa-esp32-elf/bin:$ESP_TCHAIN_BASEDIR/esp32ulp-elf-binutils/bin:$IDF_PATH/tools:$PATH

RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


ENV RTOS_PATH /esp/esp-open-rtos
RUN mkdir -p $RTOS_PATH 
RUN chown -R theia:theia $RTOS_PATH

ENV ESP_SDK_PATH /esp/esp-opensdk
RUN mkdir -p $ESP_SDK_PATH 
RUN chown -R theia:theia $ESP_SDK_PATH


USER theia

WORKDIR $RTOS_PATH
RUN git clone --recursive https://github.com/Superhouse/esp-open-rtos.git .

WORKDIR $ESP_SDK_PATH 
RUN git clone --recursive https://github.com/pfalcon/esp-open-sdk.git .

RUN make STANDALONE=y

USER root 

ENV PATH $ESP_SDK_PATH/xtensa-lx106-elf/bin:$PATH


ARG version=latest
WORKDIR /home/theia
ADD $version.package.json ./package.json
ARG GITHUB_TOKEN
# using "NODE_OPTIONS=..." to avoid out-of-memory problem in CI
RUN yarn --cache-folder ./ycache && rm -rf ./ycache && \
    NODE_OPTIONS="--max_old_space_size=4096" yarn theia build
EXPOSE 3000
ENV SHELL /bin/bash

ENTRYPOINT [ "yarn", "theia", "start", "/home/project", "--hostname=0.0.0.0" ]


