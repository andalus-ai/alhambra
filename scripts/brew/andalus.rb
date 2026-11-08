class Andalus < Formula
  desc "Autonomous Coding Agent Substrate & Gollek Neural Engine"
  homepage "https://github.com/kayys-tech/andalus-platform"
  version "0.1.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/kayys-tech/andalus-platform/releases/download/v0.1.0/andalus-macos-arm64.tar.gz"
      sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    else
      url "https://github.com/kayys-tech/andalus-platform/releases/download/v0.1.0/andalus-macos-x86_64.tar.gz"
      sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end
  end

  depends_on "openjdk@21"

  def install
    bin.install "bin/andalus"
    bin.install "bin/alhambra"
    bin.install "bin/gollek"
    prefix.install Dir["lib/*"]
  end

  def caveats
    <<~EOS
      🎉 Andalus Platform & Gollek Inference Engine installed!
      Run `andalus` or launch Alhambra Vibe Coder to start the dual-substrate environment.
    EOS
  end

  test do
    system "#{bin}/andalus", "--version"
  end
end
