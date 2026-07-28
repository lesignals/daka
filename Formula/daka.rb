class Daka < Formula
  desc "macOS menu bar tracker for daily clock-in span"
  homepage "https://github.com/iBreaker/daka"
  url "https://github.com/iBreaker/daka/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "6e8ab1ea9ecb5f8cda8d87c5e926290e051f8f1058d528e77d342f31bf6b8ba0"
  license :cannot_represent
  head "https://github.com/iBreaker/daka.git", branch: "main"

  def install
    system "scripts/build-app.sh", "--output", buildpath/"Daka.app"
    libexec.install "Daka.app"
    bin.write_exec_script opt_libexec/"Daka.app/Contents/MacOS/daka"
  end

  service do
    run [opt_libexec/"Daka.app/Contents/MacOS/daka"]
    keep_alive successful_exit: false
    process_type :interactive
    log_path var/"log/daka.log"
    error_log_path var/"log/daka.log"
  end

  test do
    assert_path_exists bin/"daka"
    assert_predicate bin/"daka", :executable?
    assert_path_exists libexec/"Daka.app/Contents/Info.plist"
    bundle_id = shell_output(
      "/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' #{libexec}/Daka.app/Contents/Info.plist",
    ).strip
    assert_equal "local.daka.menu",
      bundle_id
  end
end
