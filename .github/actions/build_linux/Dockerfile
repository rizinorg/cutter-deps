FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive
RUN apt update
RUN apt install -y build-essential curl wget software-properties-common
RUN apt install -y cmake libxcb1-dev libgtk-3-dev libxcb-*-dev libxkbcommon-dev \
    libxkbcommon-x11-dev libclang-10-dev llvm-10 libglib2.0-dev mesa-common-dev \
    libgl1-mesa-dev zlib1g-dev libpcre2-dev
