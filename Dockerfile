FROM archlinux:latest

RUN pacman-key --init \
 && pacman-key --populate archlinux \
 && pacman -Sy --noconfirm archlinux-keyring \
 && pacman-key --populate archlinux \
 && pacman -Su --noconfirm \
 && pacman -S --noconfirm --needed \
  archiso \
  base-devel \
  git \
  sudo \
  librsvg \
 && pacman -Scc --noconfirm \
 && pacman -S --needed --noconfirm \
  meson \
  python \
  cmake \
  extra-cmake-modules \
  rust \
  go \
  cargo \
  base-devel \
  git \
  nodejs npm \
  gobject-introspection \
 && pacman -S --noconfirm python-pip python-setuptools

CMD ["/bin/bash"]
