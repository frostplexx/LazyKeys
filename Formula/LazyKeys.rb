class Hyperkey < Formula
  desc "LazyKeys - Remap capslock to something useful"
  homepage "https://github.com/frostplexx/LazyKeys"
  url "https://github.com/frostplexx/LazyKeys/releases/download/v1.0/lazykeys.tar.gz"
  sha256 "YOUR_TAR_GZ_SHA256"  # You need to replace this with the actual sha256 of your tarball.
  
  depends_on :macos # This ensures it's macOS-specific.

  def install
    bin.install "lazykeys"  # Adjust this to match the name of your compiled binary.
  end

  test do
    # Optionally, add a test to check if the binary works correctly.
    system "#{bin}/lazykeys", "--version"
  end
end
