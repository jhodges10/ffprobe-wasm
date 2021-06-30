FROM emscripten/emsdk:2.0.11 as build

ARG FFMPEG_VERSION=4.3.1
ARG X264_VERSION=20170226-2245-stable

ARG PREFIX=/opt/ffmpeg
ARG MAKEFLAGS="-j4"

# Add crucial build deps
RUN apt-get update && apt-get install -y autoconf automake libtool build-essential yasm

# Install gnupg2 se we can add keys
RUN apt-get update && apt-get install -y gnupg2

# Add package repository for libfdk-aac
RUN sudo echo "deb http://www.deb-multimedia.org stretch main non-free" >> /etc/apt/sources.list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 5C808C2B65558117
RUN apt-get update

# Fetch and build libfdk-aac from source
# RUN mkdir ~/src && cd ~/src && git clone git://git.libav.org/libav.git

# Add audio support
RUN sudo apt-get install -y libmp3lame-dev libfdk-aac-dev

# libx264
RUN cd /tmp && \
  wget https://download.videolan.org/pub/videolan/x264/snapshots/x264-snapshot-${X264_VERSION}.tar.bz2 && \
  tar xvfj x264-snapshot-${X264_VERSION}.tar.bz2

RUN cd /tmp/x264-snapshot-${X264_VERSION} && \
  emconfigure ./configure \
  --prefix=${PREFIX} \
  --host=i686-gnu \
  --enable-static \
  --disable-cli \
  --disable-asm \
  --extra-cflags="-s USE_PTHREADS=1"

RUN cd /tmp/x264-snapshot-${X264_VERSION} && \
  emmake make && emmake make install 

# Get ffmpeg source.
RUN cd /tmp/ && \
  wget http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz && \
  tar zxf ffmpeg-${FFMPEG_VERSION}.tar.gz && rm ffmpeg-${FFMPEG_VERSION}.tar.gz

ARG CFLAGS="-s USE_PTHREADS=1 -O3 -I${PREFIX}/include"
ARG LDFLAGS="$CFLAGS -L${PREFIX}/lib -s INITIAL_MEMORY=33554432 -L/usr/local/lib/libfdk-aac -libfdk-aac"


# Compile ffmpeg.
RUN echo "Compiling ffmpeg..."
RUN cd /tmp/ffmpeg-${FFMPEG_VERSION} && \
  emconfigure ./configure \
  --prefix=${PREFIX} \
  --target-os=none \
  --arch=x86_32 \
  --enable-cross-compile \
  --disable-debug \
  --disable-x86asm \
  --disable-inline-asm \
  --disable-stripping \
  --disable-programs \
  --disable-doc \
  --disable-all \
  --enable-avcodec \
  --enable-avformat \
  --enable-avfilter \
  --enable-avdevice \
  --enable-avutil \
  --enable-swresample \
  --enable-postproc \
  --enable-swscale \
  --enable-protocol=file \
  --enable-decoder=h264,aac,pcm_s16le \
  --enable-demuxer=mov,matroska \
  --enable-muxer=mp4 \
  --enable-libx264 \
  --extra-cflags="$CFLAGS" \
  --extra-cxxflags="$CFLAGS" \
  --extra-ldflags="$LDFLAGS" \
  --enable-libmp3lame \
  --enable-libfdk-aac \
  --enable-nonfree \
  --enable-gpl \
  --nm="llvm-nm -g" \
  --ar=emar \
  --as=llvm-as \
  --ranlib=llvm-ranlib \
  --cc=emcc \
  --cxx=em++ \
  --objcc=emcc \
  --dep-cc=emcc

RUN echo "Compiled ffmpeg..."

RUN cd /tmp/ffmpeg-${FFMPEG_VERSION} && \
  emmake make -j4 && \
  emmake make install

COPY ./src/ffprobe-wasm-wrapper.cpp /build/src/ffprobe-wasm-wrapper.cpp
COPY ./Makefile /build/Makefile

WORKDIR /build

RUN make