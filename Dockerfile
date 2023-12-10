FROM ubuntu:22.04

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

WORKDIR /home/${USER}/work

ARG USER
ARG GROUP

RUN groupadd ${USER} \
  && useradd ${USER} -g ${GROUP} -m

USER ${USER}

WORKDIR /home/${USER}

ENV ASDF_DIR="/home/${USER}/.asdf"

RUN git clone https://github.com/asdf-vm/asdf.git $ASDF_DIR --branch v0.13.1

RUN . "/home/${USER}/.asdf/asdf.sh" \
  && asdf plugin-add erlang \
  && asdf install erlang 26.0.2 \
  && asdf global  erlang 26.0.2

RUN . "/home/${USER}/.asdf/asdf.sh" \
  && asdf plugin-add elixir \
  && asdf install elixir 1.15.7-otp-26 \
  && asdf global  elixir 1.15.7-otp-26

ENV USER=${USER}

RUN cat <<'__EOS' >> "/home/${USER}/.bashrc"

. "/home/${USER}/.asdf/asdf.sh"

PS1_ORIG="$PS1"

export PS1='  ---------------- \[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\h:\w\n  \$ '
__EOS

RUN cat <<'__EOS' >> "/home/${USER}/.bash_history"
rake clean
rake clean build
cat test_common/
cat test_common/compile/01.mrcl 
./test.sh j 1
./test.sh l 1
./test.sh p 1
./test.sh c 27
./test.sh a
__EOS

WORKDIR /home/${USER}/work

ENV IN_CONTAINER=1
