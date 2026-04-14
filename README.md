# Transcribe

En native macOS-app för tal-till-text-transkribering. Körs helt lokalt på enheten med WhisperKit och CoreML -- ingen data lämnar din dator. Optimerad för svenska med KB Whisper-modeller, men stödjer 100+ språk.

![Swift](https://img.shields.io/badge/Swift-6.1-orange)
![macOS](https://img.shields.io/badge/macOS-26+-blue)
![License](https://img.shields.io/badge/License-MIT-green)

![Huvudfönster](screenshot-main.jpg)

![Transkribering med LLM-bearbetning](screenshot-transcribe.jpg)

## Funktioner

- **Lokal transkribering** -- WhisperKit kör Whisper-modeller på Apple Silicon via CoreML. Ingen internetanslutning krävs. Stödjer ljudfiler (WAV, MP3, M4A, FLAC, AAC) och videofiler (MP4, MOV) -- ljudet extraheras automatiskt.
- **Svensk-optimerade modeller** -- KB Whisper-modeller från [KBLab](https://huggingface.co/KBLab), finjusterade för svenska.
- **Inbyggd inspelning** -- Spela in direkt i appen med live-nivåmätning och val av inmatningsenhet.
- **Systemljudsinspelning** -- Spela in allt ljud som spelas upp på din Mac (möten, media, notiser) med ScreenCaptureKit. Blanda in din mikrofon för att fånga båda sidor av ett möte. macOS ber om tillåtelse vid första användningen.
- **Sammanfatta** -- Ny skärm med mötespecifika LLM-prompter: mötesöversikt, detaljerat protokoll, deltagaranalys, beslutslogg och uppföljningsplan.
- **Textbearbetning med LLM** -- Sammanfatta, extrahera åtgärdspunkter eller kör egna prompter på transkriptioner via Ollama eller annan OpenAI-kompatibel server.
- **Integritet som standard** -- Alla inspelningar lagras i en tillfällig cache och raderas automatiskt när appen avslutas.
- **100+ språk** -- Whisper stödjer bred flerspråkig transkribering med automatisk språkdetektering.

## Krav

- macOS 26 (Tahoe) eller senare
- Apple Silicon (M1+)
- 8 GB RAM minimum (16 GB rekommenderas)

## Installation

```bash
git clone https://github.com/mickekring/Transcribe-MacOS-App.git
cd Transcribe-MacOS-App
```

### Bygg

Det finns för närvarande ett Xcode 26 beta-fel där bygge från Xcodes gränssnitt misslyckas med ett `___llvm_profile_runtime`-symbolfel. Detta beror på att `CLANG_COVERAGE_MAPPING` är aktiverat som standard, vilket lägger till täckningsinstrumentering i rena C-SPM-beroenden (yyjson, ett transitivt beroende av WhisperKit) utan att länka profileringsbiblioteket. Bygg från kommandoraden istället:

```bash
xcodebuild build -scheme Transcribe CLANG_COVERAGE_MAPPING=NO
```

### Modell -- git LFS-setup

Appen levereras med KB Whisper Large inbyggd i appbunten. För att hämta modellen innan bygge, använd git LFS:

```bash
# Installera git-lfs (macOS via Homebrew)
brew install git-lfs
git lfs install

# Ladda ner endast KB Whisper Large-varianten (~3,1 GB)
GIT_LFS_SKIP_SMUDGE=1 git clone https://huggingface.co/mickekringai/kb-whisper-coreml /tmp/kb-whisper-coreml
cd /tmp/kb-whisper-coreml
git lfs pull --include="large/*"

# Kopiera till projektet
cp -r large /sökväg/till/Transcribe-MacOS-App/Transcribe/Resources/BundledModel
```

Alternativt finns ett Python-baserat skript: `bash scripts/download_bundled_model.sh`

Efter nedladdning, lägg till modellmappen i Xcode som en mappreferens (blå mappikon):
1. Högerklicka på gruppen "Resources" → "Add Files to Transcribe…"
2. Välj mappen `BundledModel`
3. Välj "Create folder references" (blå ikon, inte gul)
4. Se till att "Transcribe"-målet är markerat → Lägg till

## Modell

**Lokal (på enheten):**

KB Whisper Large (~3,1 GB) -- högsta noggrannhet, optimerad för svenska, inbyggd i appen för helt offline-användning.

Modellen är hostad på [mickekringai/kb-whisper-coreml](https://huggingface.co/mickekringai/kb-whisper-coreml) på Hugging Face.

## Teknisk stack

- **SwiftUI** -- Native macOS-gränssnitt med mörkt/ljust läge
- **[WhisperKit](https://github.com/argmaxinc/WhisperKit)** -- Tal-till-text på enheten via CoreML
- **AVFoundation / CoreAudio** -- Ljudinspelning, uppspelning och enhetshantering
- **ScreenCaptureKit** -- Systemljudsinspelning
- **Security.framework** -- API-nycklar sparas i macOS Nyckelring

## Integritet och säkerhet

- All transkribering sker lokalt
- Inspelningar lagras i `~/Library/Caches/Transcribe/` och raderas när appen avslutas
- Kvarliggande filer från forcerad avslutning rensas vid nästa uppstart
- Ingen analys, ingen spårning, ingen telemetri

## Licens

MIT-licens -- se [LICENSE](LICENSE) för detaljer.

Baserat på ett projekt av [Micke Kring](https://mickekring.se). Byggt med [Claude Code](https://claude.ai/code).
