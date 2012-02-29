# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-boot/grub/grub-9999.ebuild,v 1.50 2012/02/29 01:52:22 floppym Exp $

EAPI=4

if [[ ${PV} == "9999" ]] ; then
	EBZR_REPO_URI="http://bzr.savannah.gnu.org/r/grub/trunk/grub/"
	LIVE_ECLASS="bzr"
	SRC_URI=""
	DO_AUTORECONF="true"
else
	MY_P=${P/_/\~}
	if [[ ${PV} == *_alpha* || ${PV} == *_beta* ]]; then
		SRC_URI="http://alpha.gnu.org/gnu/${PN}/${MY_P}.tar.xz"
	else
		SRC_URI="mirror://gnu/${PN}/${MY_P}.tar.xz
		mirror://gentoo/${MY_P}.tar.xz"
	fi
	# Masked until documentation guys consolidate the guide and approve
	# it for usage.
	#KEYWORDS="~amd64 ~mips ~x86"
	S=${WORKDIR}/${MY_P}
fi

inherit eutils flag-o-matic pax-utils toolchain-funcs ${DO_AUTORECONF:+autotools} ${LIVE_ECLASS}
unset LIVE_ECLASS

DESCRIPTION="GNU GRUB boot loader"
HOMEPAGE="http://www.gnu.org/software/grub/"

LICENSE="GPL-3"
SLOT="2"
IUSE="custom-cflags debug device-mapper efiemu mount nls static sdl truetype libzfs"

GRUB_PLATFORMS=(
	# everywhere:
	emu
	# mips only:
	qemu-mips yeeloong
	# amd64, x86, ppc, ppc64:
	ieee1275
	# amd64, x86:
	coreboot multiboot efi-32 pc qemu
	# amd64:
	efi-64
)
IUSE+=" ${GRUB_PLATFORMS[@]/#/grub_platforms_}"

# os-prober: Used on runtime to detect other OSes
# xorriso (dev-libs/libisoburn): Used on runtime for mkrescue
RDEPEND="
	dev-libs/libisoburn
	dev-libs/lzo
	sys-boot/os-prober
	>=sys-libs/ncurses-5.2-r5
	debug? (
		sdl? ( media-libs/libsdl )
	)
	device-mapper? ( >=sys-fs/lvm2-2.02.45 )
	libzfs? ( sys-fs/zfs )
	mount? ( sys-fs/fuse )
	truetype? ( media-libs/freetype >=media-fonts/unifont-5 )"
DEPEND="${RDEPEND}
	>=dev-lang/python-2.5.2
	sys-devel/flex
	virtual/yacc
	sys-apps/texinfo
"
if [[ -n ${DO_AUTORECONF} ]] ; then
	DEPEND+=" >=sys-devel/autogen-5.10 sys-apps/help2man"
else
	DEPEND+=" app-arch/xz-utils"
fi

export STRIP_MASK="*/grub/*/*.{mod,img}"

QA_EXECSTACK="
	usr/bin/grub*
	usr/sbin/grub*
	usr/lib*/grub/*/*.mod
	usr/lib*/grub/*/kernel.exec
	usr/lib*/grub/*/kernel.img
	usr/lib*/grub/*/setjmp.module
"

QA_WX_LOAD="
	usr/lib*/grub/*/kernel.exec
	usr/lib*/grub/*/kernel.img
	usr/lib*/grub/*/*.image
"

QA_PRESTRIPPED="
	usr/lib.*/grub/.*/kernel.img
"

grub_run_phase() {
	local phase=$1
	local platform=$2
	[[ -z ${phase} || -z ${platform} ]] && die "${FUNCNAME} [phase] [platform]"

	[[ -d "${WORKDIR}/build-${platform}" ]] || \
		{ mkdir "${WORKDIR}/build-${platform}" || die ; }
	pushd "${WORKDIR}/build-${platform}" > /dev/null || die

	echo ">>> Running ${phase} for platform \"${platform}\""
	echo ">>> Working in: \"${WORKDIR}/build-${platform}\""

	grub_${phase} ${platform}

	popd > /dev/null || die
}

grub_src_configure() {
	local platform=$1
	local target
	local transform="grub2"
	local with_platform

	[[ -z ${platform} ]] && die "${FUNCNAME} [platform]"

	if [[ ${platform} != "guessed" ]]; then
		transform="grub2-${platform}"
	fi

	# check if we have to specify the target (EFI)
	# or just append correct --with-platform
	if [[ ${platform} == efi* ]]; then
		# EFI platform hack
		[[ ${platform/*-} == 32 ]] && target=i386
		[[ ${platform/*-} == 64 ]] && target=x86_64
		# program-prefix is required empty because otherwise it is equal to
		# target variable, which we do not want at all
		with_platform="
			--with-platform=${platform/-*}
			--target=${target}
			--program-prefix=
		"
	elif [[ ${platform} != "guessed" ]]; then
		with_platform=" --with-platform=${platform}"
	fi

	ECONF_SOURCE="${S}" \
	econf \
		--disable-werror \
		--program-transform-name="s,grub,${transform}," \
		--with-grubdir=grub2 \
		$(use_enable debug mm-debug) \
		$(use_enable debug grub-emu-usb) \
		$(use_enable device-mapper) \
		$(use_enable efiemu) \
		$(use_enable mount grub-mount) \
		$(use_enable nls) \
		$(use_enable truetype grub-mkfont) \
		$(use_enable libzfs) \
		$(use sdl && use_enable debug grub-emu-sdl) \
		${with_platform}
}

grub_src_compile() {
	default_src_compile
	pax-mark -mpes "${grub_binaries[@]}"
}

grub_src_install() {
	default_src_install
}

src_prepare() {
	local i j

	epatch_user

	# fix texinfo file name, as otherwise the grub2.info file will be
	# useless
	sed -i \
		-e '/setfilename/s:grub.info:grub2.info:' \
		-e 's:(grub):(grub2):' \
		docs/grub.texi

	# autogen.sh does more than just run autotools
	if [[ -n ${DO_AUTORECONF} ]] ; then
		sed -i -e '/^autoreconf/s:^:set +e; e:' autogen.sh || die
		(. ./autogen.sh) || die
	fi

	# install into the right dir for eselect #372735
	sed -i \
		-e '/^bashcompletiondir =/s:=.*:= $(datarootdir)/bash-completion:' \
		util/bash-completion.d/Makefile.in || die

	# get enabled platforms
	GRUB_ENABLED_PLATFORMS=""
	for i in ${GRUB_PLATFORMS[@]}; do
		use grub_platforms_${i} && GRUB_ENABLED_PLATFORMS+=" ${i}"
	done
	[[ -z ${GRUB_ENABLED_PLATFORMS} ]] && GRUB_ENABLED_PLATFORMS="guessed"
	elog "Going to build following platforms: ${GRUB_ENABLED_PLATFORMS}"
}

src_configure() {
	local i

	use custom-cflags || unset CFLAGS CPPFLAGS LDFLAGS
	use libzfs && addpredict /etc/dfs
	use static && append-ldflags -static

	for i in ${GRUB_ENABLED_PLATFORMS}; do
		grub_run_phase ${FUNCNAME} ${i}
	done
}

src_compile() {
	# Used for pax marking in grub_src_compile
	local grub_binaries=(
		grub-editenv
		grub-fstest
		grub-menulst2cfg
		grub-mkimage
		grub-mklayout
		grub-mkpasswd-pbkdf2
		grub-mkrelpath
		grub-script-check
		grub-bios-setup
		grub-ofpathname
		grub-probe
		grub-sparc64-setup
	)
	use mount && grub_binaries+=( grub-mount )
	use truetype && grub_binaries+=( grub-mkfont )

	local i

	for i in ${GRUB_ENABLED_PLATFORMS}; do
		grub_run_phase ${FUNCNAME} ${i}
	done
}

src_install() {
	local i

	for i in ${GRUB_ENABLED_PLATFORMS}; do
		grub_run_phase ${FUNCNAME} ${i}
	done

	#mv "${ED}"usr/share/info/grub{,2}.info || die

	# can't be in docs array as we use default_src_install in different builddir
	dodoc AUTHORS ChangeLog NEWS README THANKS TODO
	insinto /etc/default
	newins "${FILESDIR}"/grub.default grub
}

pkg_postinst() {
	# display the link to guide
	elog "For information on how to configure grub-2 please refer to the guide:"
	elog "    http://dev.gentoo.org/~scarabeus/grub-2-guide.xml"
}