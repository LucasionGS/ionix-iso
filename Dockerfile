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
  cmark \
  extra-cmake-modules \
  rust \
  go \
  cargo \
  base-devel \
  git \
  nodejs npm \
  gobject-introspection \
  python-pip \
  python-setuptools \
  python-gobject cairo \
  python-pillow \
  libportal \
  libportal-gtk4 \
  muparser \
  json-glib \
  libgtop \
  wayland-protocols \
  scdoc \
  dart-sass

CMD ["/bin/bash"]
