import SwiftUI

struct AboutView: View {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        TabView {
            appInfoTab
                .tabItem { Label("About", systemImage: "info.circle") }

            licensesTab
                .tabItem { Label("Licenses", systemImage: "doc.plaintext") }
        }
        .frame(width: 520, height: 460)
        .background(Color.surfaceBackground)
    }

    // MARK: - App Info Tab

    private var appInfoTab: some View {
        VStack(spacing: 20) {
            Spacer()

            LinearGradient.accentGradient
                .mask(
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 72))
                )
                .frame(width: 72, height: 72)

            VStack(spacing: 6) {
                Text("Transcribe")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.textPrimary)

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }

            Text("Advanced audio transcription for macOS")
                .font(.body)
                .foregroundStyle(Color.textSecondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 10) {
                featureRow("Swedish-optimized with KB Whisper")
                featureRow("Fully local — no external connections")
                featureRow("Privacy-focused design")
                featureRow("Built with Swift & SwiftUI")
            }

            Spacer()

            Text("© 2025 Transcribe. All rights reserved.")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
                .padding(.bottom, 8)
        }
        .padding()
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.primaryAccent)
                .font(.caption)
            Text(text)
                .font(.body)
                .foregroundStyle(Color.textPrimary)
        }
    }

    // MARK: - Licenses Tab

    private var licensesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Open Source Licenses")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.bottom, 4)

                Text("Transcribe is built on the following open source libraries.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)

                Divider()

                LicenseEntry(
                    name: "WhisperKit",
                    repo: "argmaxinc/WhisperKit",
                    license: """
                    MIT License

                    Copyright (c) 2023 Argmax, Inc.

                    Permission is hereby granted, free of charge, to any person obtaining a copy \
                    of this software and associated documentation files (the "Software"), to deal \
                    in the Software without restriction, including without limitation the rights \
                    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
                    copies of the Software, and to permit persons to whom the Software is \
                    furnished to do so, subject to the following conditions:

                    The above copyright notice and this permission notice shall be included in \
                    all copies or substantial portions of the Software.

                    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
                    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
                    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
                    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
                    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
                    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN \
                    THE SOFTWARE.
                    """
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.surfaceBackground)
    }
}

// MARK: - License Entry

private struct LicenseEntry: View {
    let name: String
    let repo: String
    let license: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.textPrimary)
                        Text(repo)
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Text("MIT")
                        .font(.caption.bold())
                        .foregroundStyle(Color.primaryAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primaryAccent.opacity(0.12))
                        .clipShape(Capsule())
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView {
                    Text(license)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(height: 200)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.borderLight, lineWidth: 1)
                )
            }
        }
    }
}
