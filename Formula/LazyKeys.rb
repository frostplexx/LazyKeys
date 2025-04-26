class Hyperkey < Formula
  desc "LazyKeys - Remap capslock to something useful"
  homepage "https://github.com/frostplexx/LazyKeys"
  url "https://github.com/frostplexx/LazyKeys/releases/download/v1.0/lazykeys.tar.gz"
  sha256 "YOUR_TAR_GZ_SHA256"
  
  depends_on :macos

  def install
    bin.install "lazykeys" 
  end

  test do
    system "#{bin}/lazykeys", "--version"
  end
end
