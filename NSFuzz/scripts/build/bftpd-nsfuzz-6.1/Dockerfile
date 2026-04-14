# ============================================================
# bftpd-nsfuzz  —  bftpd 6.1  (升级自 5.7, 与 ChatAFL-Opt 对齐)
# ============================================================
# 镜像名称: bftpd-nsfuzz
# 构建命令: docker build -t bftpd-nsfuzz .
# ============================================================
FROM ubuntu:16.04

# ---------- 系统依赖 ----------
RUN apt-get -y update && \
    apt-get -y install sudo \
    apt-utils \
    build-essential \
    openssl \
    clang \
    graphviz-dev \
    git \
    autoconf \
    libgnutls-dev \
    libssl-dev \
    python-pip \
    nano \
    net-tools \
    vim \
    gdb \
    netcat \
    strace \
    wget

RUN wget https://bootstrap.pypa.io/pip/2.7/get-pip.py && \
    python get-pip.py && \
    echo "y" | pip uninstall jinja2 && \
    echo "y" | pip install jinja2

# ---------- 用户 ----------
RUN groupadd ubuntu && \
    useradd -rm -d /home/ubuntu -s /bin/bash -g ubuntu -G sudo -u 1000 ubuntu -p "$(openssl passwd -1 ubuntu)"

RUN chmod 777 /tmp
RUN pip install gcovr==4.2

# ---------- 基础环境 ----------
USER ubuntu
WORKDIR /home/ubuntu

ARG MAKE_OPT

ENV LLVM_CONFIG="llvm-config-3.8"

# ---------- aflnet + aflnwe (与原始镜像完全一致) ----------
COPY --chown=ubuntu:ubuntu collect_sv_range.patch /collect_sv_range.patch
COPY --chown=ubuntu:ubuntu affinity.patch /affinity.patch
COPY --chown=ubuntu:ubuntu affinity_aflnwe.patch /affinity_aflnwe.patch

RUN git clone https://github.com/profuzzbench/aflnet.git && \
    cd aflnet && \
    patch -p1 < /collect_sv_range.patch && \
    patch -p1 < /affinity.patch && \
    make clean all $MAKE_OPT && \
    cd llvm_mode && make $MAKE_OPT

RUN git clone https://github.com/profuzzbench/aflnwe.git && \
    cd aflnwe && \
    patch -p1 < /collect_sv_range.patch && \
    patch -p1 < /affinity_aflnwe.patch && \
    make clean all $MAKE_OPT && \
    cd llvm_mode && make $MAKE_OPT

# ---------- 环境变量 ----------
ENV WORKDIR="/home/ubuntu/experiments"
ENV AFLNET="/home/ubuntu/aflnet"
ENV PATH="${PATH}:${AFLNET}:/home/ubuntu/.local/bin:${WORKDIR}"
ENV AFL_PATH="${AFLNET}"
ENV AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 \
    AFL_SKIP_CPUFREQ=1

RUN mkdir $WORKDIR

# ---------- bftpd 补丁 ----------
COPY --chown=ubuntu:ubuntu fuzzing.patch ${WORKDIR}/fuzzing.patch
COPY --chown=ubuntu:ubuntu fuzzing_aflnet.patch ${WORKDIR}/fuzzing_aflnet.patch
COPY --chown=ubuntu:ubuntu gcov.patch ${WORKDIR}/gcov.patch
COPY --chown=ubuntu:ubuntu state_variable.patch ${WORKDIR}/state_variable.patch

# ---------- bftpd 6.1  —  aflnet 编译 (fuzzing + gcov) ----------
# ★ 这里从 5.7 升级到 6.1
# aflnet 使用 _STATE_VARIABLE() 宏 (由 aflnet/llvm_mode/afl-rt.h 提供)
# fuzzing_aflnet.patch = 网络桩 + _STATE_VARIABLE 标注
RUN cd ${WORKDIR} && \
    wget https://sourceforge.net/projects/bftpd/files/bftpd/bftpd-6.1/bftpd-6.1.tar.gz --no-check-certificate && \
    tar -zxvf bftpd-6.1.tar.gz && \
    cd bftpd && \
    patch -p1 < ${WORKDIR}/fuzzing_aflnet.patch && \
    CC=afl-clang-fast make PARSE_ANNOTATION=1 all $MAKE_OPT && \
    make clean && \
    CC=afl-clang-fast make all $MAKE_OPT

# ---------- bftpd 6.1  —  gcov 编译 ----------
RUN cd ${WORKDIR} && \
    mkdir ${WORKDIR}/bftpd-gcov && \
    tar -zxvf bftpd-6.1.tar.gz -C ${WORKDIR}/bftpd-gcov --strip-components=1 && \
    cd ${WORKDIR}/bftpd-gcov && \
    patch -p1 < ${WORKDIR}/gcov.patch && \
    make $MAKE_OPT

# ---------- 运行脚本 & 种子 ----------
COPY --chown=ubuntu:ubuntu basic.conf ${WORKDIR}/
COPY --chown=ubuntu:ubuntu in-ftp ${WORKDIR}/in-ftp
COPY --chown=ubuntu:ubuntu ftp.dict ${WORKDIR}/ftp.dict
COPY --chown=ubuntu:ubuntu run.sh ${WORKDIR}/run
COPY --chown=ubuntu:ubuntu clean.sh ${WORKDIR}/clean
COPY --chown=ubuntu:ubuntu cov_script.sh ${WORKDIR}/cov_script
COPY --chown=ubuntu:ubuntu collect_sv_range.py ${WORKDIR}/collect_sv_range.py

RUN mkdir /home/ubuntu/ftpshare && \
    chown -R ubuntu:ubuntu /home/ubuntu/ftpshare

# ---------- NSFuzz 工具链 (clang-9 + nsfuzz) ----------
USER root
WORKDIR /home/ubuntu
RUN apt-get -y install ftp

USER ubuntu
WORKDIR /home/ubuntu

# clang 9.0.0
RUN wget https://releases.llvm.org/9.0.0/clang+llvm-9.0.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz && \
    xz -d clang+llvm-9.0.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz && \
    tar -xvf clang+llvm-9.0.0-x86_64-linux-gnu-ubuntu-16.04.tar && \
    mv clang+llvm-9.0.0-x86_64-linux-gnu-ubuntu-16.04 clang-9.0.0

ENV CLANG_PATH="/home/ubuntu/clang-9.0.0"
ENV LLVM_DIR="/home/ubuntu/clang-9.0.0"
ENV NSFUZZ="/home/ubuntu/nsfuzz"
ENV AFL_PATH="/home/ubuntu/nsfuzz"
ENV CLANG="/home/ubuntu/clang-9.0.0/bin/clang"
ENV CLANGXX="/home/ubuntu/clang-9.0.0/bin/clang++"

# NSFuzz (use local vendored source to avoid private git dependency)
COPY --chown=ubuntu:ubuntu nsfuzz-source ${NSFUZZ}
RUN cd $NSFUZZ && \
    make clean all $MAKE_OPT && \
    cd llvm_mode && LLVM_CONFIG=${CLANG_PATH}/bin/llvm-config CC=${CLANG_PATH}/bin/clang CXX=${CLANG_PATH}/bin/clang++ make $MAKE_OPT

ENV AFL_CC="/home/ubuntu/clang-9.0.0/bin/clang"
ENV AFL_CXX="/home/ubuntu/clang-9.0.0/bin/clang++"

# ---------- bftpd 6.1  —  nsfuzz 编译 ----------
COPY --chown=ubuntu:ubuntu run-nsfuzz ${WORKDIR}/run-nsfuzz
COPY --chown=ubuntu:ubuntu collect_sv_range.py ${WORKDIR}/collect_sv_range.py

RUN cd ${WORKDIR} && \
    mkdir ${WORKDIR}/bftpd-nsfuzz && \
    tar -zxvf bftpd-6.1.tar.gz -C ${WORKDIR}/bftpd-nsfuzz --strip-components=1 && \
    cd ${WORKDIR}/bftpd-nsfuzz && \
    patch -p1 < ${WORKDIR}/fuzzing.patch && \
    CC=${NSFUZZ}/afl-clang-fast make NSFUZZ_PARSE_ANNOTATION=1 && \
    make clean && \
    CC=${NSFUZZ}/afl-clang-fast make NSFUZZ_TRACE_STATE=1 MANNUAL_STATE=1 MANNUAL_SYNC=1

USER root
WORKDIR /home/ubuntu
