# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-libs/libgit2/libgit2-0.17.0.ebuild,v 1.2 2012/05/23 00:43:14 radhermit Exp $

EAPI=4

inherit cmake-utils multilib

if [ "${PV}" -eq 9999 ]; then
	inherit git-2
	EGIT_REPO_URI="git://github.com/libgit2/libgit2.git"
	EGIT_MASTER="development"
else
	SRC_URI="mirror://github/${PN}/${PN}/${P}.tar.gz"
	KEYWORDS="~amd64 ~x86 ~ppc-macos"
fi

DESCRIPTION="A linkable library for Git"
HOMEPAGE="http://libgit2.github.com/"

LICENSE="GPL-2-with-linking-exception"
SLOT="0"
IUSE="examples test"

RDEPEND="sys-libs/zlib"
DEPEND="${RDEPEND}"

DOCS=( README.md )

src_configure() {
	local mycmakeargs=(
		-DINSTALL_LIB="${EPREFIX}/usr/$(get_libdir)"
		$(cmake-utils_use_build test CLAR)
	)
	cmake-utils_src_configure
}

src_install() {
	cmake-utils_src_install

	if use examples ; then
		find examples -name .gitignore -delete
		dodoc -r examples
		docompress -x /usr/share/doc/${PF}/examples
	fi
}
