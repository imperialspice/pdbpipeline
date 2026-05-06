FROM alpine:latest


# General support programs
RUN apk add curl git make bash clang

# Support for GROMACS
RUN apk add cmake lldb make curl
COPY gromacs /gromacs
WORKDIR /gromacs
RUN mkdir -p build 
WORKDIR /gromacs/build
RUN cmake .. -DGMX_BUILD_OWN_FFTW=ON 

