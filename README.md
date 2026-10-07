# PDFPowerConvert

Converts Microsoft Teams HTML exports to PDF using only what comes with Windows — no third-party tools, no Admin rights.

- **Modern emoji render correctly**: uses Microsoft Edge's built-in print-to-PDF instead of wkhtmltopdf.
- **Keeps PDFs small**: oversized images are scaled down and compressed by Edge while it renders the page.
- **Adjustable text size**: shrink everything so more fits per page for easier review.
- **Works on locked-down PCs**: runs even when PowerShell is restricted (Constrained Language Mode).
- **Originals untouched**: works on a temporary copy of each HTML file, with a separate throwaway Edge profile.

## Usage

Put `Convert-TeamsHtmlToPdf.ps1` in the folder with your HTML files, open PowerShell there, and run:

```powershell
.\Convert-TeamsHtmlToPdf.ps1
```

Each `chat.html` gets a matching `chat.pdf` alongside it.

Options:

```powershell
.\Convert-TeamsHtmlToPdf.ps1 -Folder "C:\Exports" -Zoom 75 -MaxWidth 900 -Quality 60
```

| Option      | Default        | Meaning                                                   |
|-------------|----------------|-----------------------------------------------------------|
| `-Folder`   | current folder | Where the `.html` files are                               |
| `-Zoom`     | `80`           | Size of text and layout, in percent (100 = browser size)  |
| `-MaxWidth` | `1200`         | Widest an image may be, in pixels                         |
| `-Quality`  | `75`           | JPEG quality 1–100 (lower = smaller files)                |

Images narrower than `-MaxWidth` (and embedded images under 500 KB) are left alone, so avatars and icons keep their quality.

## Very large exports

Exports of several hundred MB work: the file is never loaded into PowerShell's memory. Expect a few minutes per file at that size (a 470 MB test export took about 2½ minutes and produced a 10 MB PDF). Make sure there's free disk space of roughly the export's size, for the temporary copy.

## If scripts are blocked

If Windows says running scripts is disabled, try:

```powershell
powershell -ExecutionPolicy Bypass -File .\Convert-TeamsHtmlToPdf.ps1
```

## Requirements

- Windows with Microsoft Edge
- Windows PowerShell 5.1 (built in) or PowerShell 7
