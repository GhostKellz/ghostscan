# Maintainer: GhostKellz <ckelley@ghostkellz.sh>

pkgname=ghostscan
gitname=ghostscan
gitver=0.1.0
pkgver=0.1.0
pkgrel=1
pkgdesc="Blazing-fast Rust-native TCP port scanner"
arch=('x86_64')
url="https://ghostkellz.sh"
license=('MIT')
depends=('gcc-libs')
makedepends=('git' 'rust' 'cargo')
source=("${gitname}-${pkgver}.tar.gz")
b2sums=('SKIP')

build() {
  cd "${srcdir}/${gitname}-${pkgver}/gscan"
  cargo build --release
}

package() {
  cd "${srcdir}/${gitname}-${pkgver}/gscan"
  install -Dm755 target/release/gscan "$pkgdir/usr/bin/gscan"
  install -Dm644 ../LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  install -Dm644 ../README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
}