class Lazykeys < Formula
  desc "LazyKeys - Remap capslock to something useful"
  homepage "https://github.com/frostplexx/LazyKeys"
  url "https://github.com/frostplexx/LazyKeys/releases/download/v0.0.1/lazykeys.tar.gz"
  sha256 "a049b92ad7ee22ff239cbf7188a66c670c85c91bd29efb8bba2b5d1b793c19f4"
  
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
