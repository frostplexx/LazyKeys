class Lazykeys < Formula
  desc "LazyKeys - Remap capslock to something useful"
  homepage "https://github.com/frostplexx/LazyKeys"
  url "https://github.com/frostplexx/LazyKeys/releases/download/v0.0.1/lazykeys.tar.gz"
  sha256 "98cb3b38d9899a6e89737bbcbb404f9f677d58687dd66ecb30945cf589795219"
  
  depends_on :macos

  def install
    bin.install "lazykeys" 
  end

  def caveats
    <<~EOS
      To use LazyKeys as a service:
        brew services start lazykeys
        
      To stop the service:
        brew services stop lazykeys
    EOS
  end

  service do
    run [opt_bin/"lazykeys"]
    keep_alive true
    log_path var/"log/lazykeys.log"
    error_log_path var/"log/lazykeys.log"
    # Ensure the service restarts after system reboots
    require_root true
  end

  test do
    system "#{bin}/lazykeys", "--version"
  end
end
