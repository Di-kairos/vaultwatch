class Vaultwatch < Formula
  desc "Guard an open securetrash vault on macOS (Spotlight/Time Machine/cloud)"
  homepage "https://github.com/Di-kairos/vaultwatch"
  url "https://github.com/Di-kairos/vaultwatch/archive/refs/tags/v0.1.3.tar.gz"
  sha256 "c026b42b8933c749d666714fccd31f9042d9181a0a5276624a174b95661fa1e9"
  license "MIT"

  def install
    bin.install "vaultwatch"
  end

  test do
    assert_match "vaultwatch", shell_output("#{bin}/vaultwatch version")
  end
end
