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

RUN curl -L https://github.com/asdf-vm/asdf/releases/download/v0.16.7/asdf-v0.16.7-linux-386.tar.gz -o /tmp/asdf.tar.gz \
  && tar xzf /tmp/asdf.tar.gz \
  && rm /tmp/asdf.tar.gz
#=> ~/bin/asdf (executable)

ENV PATH="/home/${USER}/bin:${PATH}"

ENV ASDF_DATA_DIR="/home/${USER}/.asdf"
ENV PATH="${ASDF_DATA_DIR}/shims:${PATH}"

RUN asdf plugin add erlang \
  && asdf install erlang 27.3.2 \
  && asdf set --home erlang 27.3.2

RUN asdf plugin add elixir \
  && asdf install elixir 1.18.3-otp-27 \
  && asdf set --home elixir 1.18.3-otp-27

# --------------------------------

RUN cat <<'SH' >> "/home/${USER}/.bashrc"

PS1_ORIG="$PS1"

export PS1='  ---------------- \[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\h:\w\n  \$ '
SH

RUN cat <<'SH' >> "/home/${USER}/.bash_history"
rake clean
rake clean build
cat test_common/
cat test_common/compile/01.mrcl 
./test.sh j 1
./test.sh l 1
./test.sh p 1
./test.sh c 27
./test.sh a
SH

WORKDIR /home/${USER}/work

ENV IN_CONTAINER=1
