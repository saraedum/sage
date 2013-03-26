
EAPI=5
DECRIPTION="zn_poly"
HOMEPAGE=""
SRC_URI="http://boxen.math.washington.edu/home/ohanar/sage-git/upstream/zn_poly-0.9.tar.bz2"
LICENSE=""
SLOT="0"
KEYWORDS="amd64-linux"
DEPEND="legacy-spkg/mpir
legacy-spkg/python"
RDEPEND="${DEPEND}"
S="${WORKDIR}"
src_prepare() {
        mv zn_poly-0.9 src
        cp -r ${FILESDIR}/* . || die
}
src_configure() {
        return 0
}
src_compile() {
        return 0
}
src_install() {
        SAGE_ROOT=$(cd "${EPREFIX}/.." && pwd) sage -sh -c ./spkg-install || die
}

