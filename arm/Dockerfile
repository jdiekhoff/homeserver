# Custom ARM image running on pd-ripper-01 as arm-makemkv-fix:latest (built 2025-02-04).
# Base: simonmcnair's ARM fork (MakeMKV 1.17.7 fix) + Intel Quick Sync (libva, MediaSDK).
# The running image was built from this base digest:
#   simonmcnair/automatic-ripping-machine@sha256:c83db0bab8a40c596823081b92cdfac983d643d2caacae72024ddb7f656e2ba9
# Not reproducible as-is: base tag is :latest and libva/MediaSDK are cloned at HEAD.
# Rebuild: cd arm && docker compose build
FROM simonmcnair/automatic-ripping-machine:latest 
LABEL desc="ARM MakeMKV 1.17.7 fix w/ Intel Quick Sync Video Support"
RUN apt update &&\
    apt upgrade -y &&\
    apt install -y libmfx1 libmfx-tools libmfx-dev vorbis-tools wget &&\
    mkdir -p quicksync && cd quicksync &&\
    git clone https://github.com/intel/libva.git libva &&\
    cd libva &&\
    ./autogen.sh &&\
    make && make install &&\
    cd .. &&\
    wget https://github.com/Intel-Media-SDK/MediaSDK/releases/download/intel-mediasdk-21.3.5/MediaStack.tar.gz &&\
    tar -xvf MediaStack.tar.gz &&\
    cd MediaStack &&\
    bash install_media.sh &&\
    cd .. &&\
    git clone https://github.com/Intel-Media-SDK/MediaSDK msdk &&\
    cd msdk &&\
    mkdir build && cd build &&\
    cmake .. &&\
    make && make install &&\
    cd .. &&\
    rm -rf quicksync
