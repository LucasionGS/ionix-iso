# What each Ionix system package installs. Both PKGBUILDs (./PKGBUILD for the
# ISO, packaging/aur/PKGBUILD for the AUR) only call these targets, so the two
# cannot disagree about a package's contents.

DESTDIR ?=
# Rendered assets. The PKGBUILDs point this into makepkg's $srcdir so a build
# never writes into the checkout.
BUILDDIR ?= build

.PHONY: build install-base install-desktop install-server clean

build: $(BUILDDIR)/wallpaper.png $(BUILDDIR)/grub-logo.png $(BUILDDIR)/winix-wallpaper.png $(BUILDDIR)/dockix-wallpaper.png

$(BUILDDIR)/wallpaper.png: assets/wallpaper.svg
	@mkdir -p $(BUILDDIR)
	rsvg-convert -w 3840 -h 2160 $< -o $@

$(BUILDDIR)/winix-wallpaper.png: assets/winix/wallpaper.svg
	@mkdir -p $(BUILDDIR)
	rsvg-convert -w 3840 -h 2160 $< -o $@

$(BUILDDIR)/dockix-wallpaper.png: assets/dockix/wallpaper.svg
	@mkdir -p $(BUILDDIR)
	rsvg-convert -w 3840 -h 2160 $< -o $@

$(BUILDDIR)/grub-logo.png: assets/ionix-logo.svg
	@mkdir -p $(BUILDDIR)
	rsvg-convert -w 160 -h 160 $< -o $@

install-base: build
	./install-tree.sh base "$(DESTDIR)"
	install -Dm644 assets/ionix-logo.svg "$(DESTDIR)/usr/share/ionix/ionix-logo.svg"
	install -Dm644 $(BUILDDIR)/grub-logo.png "$(DESTDIR)/usr/share/ionix/grub-theme/ionix-logo.png"

install-desktop: build
	./install-tree.sh desktop "$(DESTDIR)"
	install -Dm644 $(BUILDDIR)/wallpaper.png "$(DESTDIR)/usr/share/ionix/wallpaper.png"
	# In ionix-desktop rather than with the theme, so the server, which has no use for
	# a picture, does not carry one and its styler skips the section.
	install -Dm644 $(BUILDDIR)/winix-wallpaper.png "$(DESTDIR)/usr/share/ionix/styler/themes/winix-experimental/wallpaper/winix-bloom.png"
	install -Dm644 $(BUILDDIR)/dockix-wallpaper.png "$(DESTDIR)/usr/share/ionix/styler/themes/dockix/wallpaper/dockix-ridges.png"

install-server:
	./install-tree.sh server "$(DESTDIR)"

clean:
	rm -rf $(BUILDDIR)
