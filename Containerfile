FROM fedora:43


# General support programs and AMD GPUs
RUN dnf config-manager setopt max_parallel_downloads=10

RUN dnf install -y rocm hipblas-devel hip-devel rocwmma-devel rocm-opencl-devel
RUN dnf install -y rocprim-devel rocm-devel
RUN dnf install -y llvm clang llvm-devel lld hostname egrep numactl numactl-devel
RUN dnf install -y rocm-llvm-devel

# Support for AdaptiveCPP
#RUN git clone https://github.com/AdaptiveCpp/AdaptiveCpp
#WORKDIR /AdaptiveCpp
#RUN git checkout tags/v25.10.0
#RUN mkdir build
#WORKDIR /AdaptiveCpp/build
#RUN cmake -DCMAKE_INSTALL_PREFIX=/usr -DLLVM_DIR=/usr/lib64/rocm/llvm ..
#RUN make install -j12

# Support for GROMACS
RUN dnf install -y cmake lldb make curl
RUN git clone https://gitlab.com/gromacs/gromacs.git
WORKDIR /gromacs
RUN git checkout tags/v2026.2
RUN mkdir -p build
WORKDIR /gromacs/build
RUN echo 'export PATH=$PATH:/usr/lib64/rocm/llvm/bin' >> /etc/bashrc
RUN cmake .. -DGMX_BUILD_OWN_FFTW=ON -DGMX_OPENMP=OFF -DGMX_GPU=HIP -DGMX_HIP_TARGET_ARCH=gfx1100
RUN make -j12
RUN make install
RUN echo 'export PATH=$PATH:/usr/local/gromacs/bin' >> /etc/bashrc

# # PDB Processing...
RUN dnf install -y python3 python3-pip
RUN pip install pdb-tools --break-system-packages
RUN mkdir -p /runtime/
WORKDIR /runtime
COPY pdb_prepare.sh /runtime/pdb_prepare.sh
COPY mdp_runtime /runtime/mdp_runtime


# CMD ["/bin/bash", "/runtime/pdb_prepare.sh", "1AKI"]


