# Maintainer: GhostKellz <ckelley@ghostkellz.sh>

pkgname=ghostscan
gitname=ghostscan
gitver=0.1.0
pkgver=0.1.0
pkgrel=1
pkgdesc="Blazing-fast Zig-native TCP port scanner"
arch=('x86_64')
url="https://ghostkellz.sh"
license=('MIT')
depends=('zig')
makedepends=('git' 'zig')
source=("${gitname}-${pkgver}.tar.gz")
b2sums=('SKIP')

build() {
  cd "${srcdir}/${gitname}-${pkgver}"
  zig build -Drelease-fast
}

package() {
  cd "${srcdir}/${gitname}-${pkgver}"
  install -Dm755 zig-out/bin/ghostscan "$pkgdir/usr/bin/ghostscan"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
}
