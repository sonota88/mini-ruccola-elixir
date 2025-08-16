FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.utf8

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libncurses5-dev \
    ruby \
    unzip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ARG USER
ARG GROUP

# https://askubuntu.com/questions/1513927/ubuntu-24-04-docker-images-now-includes-user-ubuntu-with-uid-gid-1000
RUN userdel -r ubuntu

RUN groupadd ${USER} \
  && useradd ${USER} -g ${GROUP} -m

USER ${USER}

WORKDIR /home/${USER}

ENV USER=${USER}

# --------------------------------
# asdf

WORKDIR /home/${USER}/bin

RUN  curl -L https://github.com/asdf-vm/asdf/releases/download/v0.18.0/asdf-v0.18.0-linux-386.tar.gz \
       -o /tmp/asdf.tar.gz \
  && tar xzf /tmp/asdf.tar.gz \
  && rm /tmp/asdf.tar.gz
#=> ~/bin/asdf (executable)

ENV PATH="/home/${USER}/bin:${PATH}"

ENV ASDF_DATA_DIR="/home/${USER}/.asdf"
ENV PATH="${ASDF_DATA_DIR}/shims:${PATH}"

RUN asdf plugin add erlang \
  && asdf install erlang 27.3.4 \
  && asdf set --home erlang 27.3.4

RUN asdf plugin add elixir \
  && asdf install elixir 1.18.4-otp-27 \
  && asdf set --home elixir 1.18.4-otp-27

# --------------------------------

WORKDIR /home/${USER}/work

ENV IN_CONTAINER=1
