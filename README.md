# PDFPowerConvert

Converts Microsoft Teams HTML exports to PDF using only what comes with Windows — no third-party tools.

- **Modern emoji render correctly**: uses Microsoft Edge's built-in print-to-PDF instead of wkhtmltopdf.
- **Keeps PDFs small**: oversized images are scaled down and compressed before conversion.
- **Originals untouched**: works on a temporary copy of each HTML file.

## Usage

Put `Convert-TeamsHtmlToPdf.ps1` in the folder with your HTML files, open PowerShell there, and run:

```powershell
.\Convert-TeamsHtmlToPdf.ps1
```

Each `chat.html` gets a matching `chat.pdf` alongside it.

Options:

```powershell
.\Convert-TeamsHtmlToPdf.ps1 -Folder "C:\Exports" -MaxWidth 900 -Quality 60
```

| Option      | Default        | Meaning                                         |
|-------------|----------------|-------------------------------------------------|
| `-Folder`   | current folder | Where the `.html` files are                     |
| `-MaxWidth` | `1200`         | Widest an image may be, in pixels               |
| `-Quality`  | `75`           | JPEG quality 1–100 (lower = smaller files)      |

Images narrower than `-MaxWidth` and under 500 KB (avatars, icons) are left alone.

## If scripts are blocked

If Windows says running scripts is disabled, try:

```powershell
powershell -ExecutionPolicy Bypass -File .\Convert-TeamsHtmlToPdf.ps1
```

If your organisation blocks that too, open the `.ps1` file in Notepad, copy everything below the `param(...)` block, and paste it straight into a PowerShell window (set `$MaxWidth`, `$Quality` and `$Folder` first).

## Requirements

- Windows with Microsoft Edge
- Windows PowerShell 5.1 (built in) or PowerShell 7
