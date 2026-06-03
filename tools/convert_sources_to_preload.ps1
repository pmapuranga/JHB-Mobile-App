param(
    [string]$SourceDir = "sources",
    [string]$PreloadDir = "assets/preload"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Convert-ToId([string]$Value) {
    $id = $Value.ToLowerInvariant() -replace "[^a-z0-9]+", "-"
    return $id.Trim("-")
}

function Get-MetaFromName([string]$FileName) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($FileName).Trim()
    $code = ""
    $title = $base
    if ($base -match "^(?<code>\d{2}-\d{4})\s*-?\s*(?<title>.+)$") {
        $code = $Matches.code
        $title = $Matches.title
    }
    $title = ($title -replace "^\s*-\s*", "" -replace "\s+", " ").Trim()
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = $base
    }
    return [pscustomobject]@{
        Code = $code
        Title = $title
        Id = Convert-ToId "$code-$title"
    }
}

function Get-DocxText([string]$Path) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $zip.GetEntry("word/document.xml")
        if ($null -eq $entry) { return "" }
        $stream = $entry.Open()
        try {
            $reader = [System.IO.StreamReader]::new($stream)
            $xmlText = $reader.ReadToEnd()
        }
        finally {
            if ($reader) { $reader.Dispose() }
            $stream.Dispose()
        }

        $xml = [xml]$xmlText
        $paragraphs = New-Object System.Collections.Generic.List[string]
        foreach ($p in $xml.SelectNodes("//*[local-name()='p']")) {
            $parts = New-Object System.Collections.Generic.List[string]
            foreach ($node in $p.SelectNodes(".//*[local-name()='t' or local-name()='tab' or local-name()='br']")) {
                if ($node.LocalName -eq "tab" -or $node.LocalName -eq "br") {
                    $parts.Add(" ")
                }
                else {
                    $parts.Add($node.InnerText)
                }
            }
            $line = (($parts -join "") -replace "\s+", " ").Trim()
            if ($line.Length -gt 0) {
                $paragraphs.Add($line)
            }
        }
        return ($paragraphs -join "`n")
    }
    finally {
        $zip.Dispose()
    }
}

function Split-SermonParagraphs([string]$Text) {
    $lines = $Text -replace "`r", "`n" -split "`n" |
        ForEach-Object { ($_ -replace "\s+", " ").Trim() } |
        Where-Object { $_.Length -gt 0 }

    $items = New-Object System.Collections.Generic.List[object]
    $currentNo = $null
    $currentText = New-Object System.Text.StringBuilder

    foreach ($line in $lines) {
        if ($line -match "^\s*(?<no>\d{1,4})[\.\)]?\s+(?<body>.+)$") {
            if ($null -ne $currentNo -and $currentText.Length -gt 0) {
                $items.Add([pscustomobject]@{
                    Number = [int]$currentNo
                    Text = $currentText.ToString().Trim()
                })
            }
            $currentNo = [int]$Matches.no
            $currentText.Clear() | Out-Null
            $currentText.Append($Matches.body.Trim()) | Out-Null
        }
        elseif ($null -ne $currentNo) {
            $currentText.Append(" ").Append($line) | Out-Null
        }
    }

    if ($null -ne $currentNo -and $currentText.Length -gt 0) {
        $items.Add([pscustomobject]@{
            Number = [int]$currentNo
            Text = $currentText.ToString().Trim()
        })
    }

    if ($items.Count -gt 0) {
        return $items
    }

    $fallback = New-Object System.Collections.Generic.List[object]
    $index = 1
    foreach ($line in $lines) {
        $fallback.Add([pscustomobject]@{
            Number = $index
            Text = $line
        })
        $index++
    }
    return $fallback
}

$resolvedSource = Resolve-Path -LiteralPath $SourceDir
$resolvedPreload = Resolve-Path -LiteralPath $PreloadDir
$pdfDir = Join-Path $resolvedPreload "pdfs"
New-Item -ItemType Directory -Force -Path $pdfDir | Out-Null

$books = New-Object System.Collections.Generic.List[object]
$entries = New-Object System.Collections.Generic.List[object]

$txtByBase = @{}
Get-ChildItem -LiteralPath $resolvedSource -Filter "*.txt" -File | ForEach-Object {
    $txtByBase[[System.IO.Path]::GetFileNameWithoutExtension($_.Name)] = $_
}

$textFiles = New-Object System.Collections.Generic.List[object]
Get-ChildItem -LiteralPath $resolvedSource -File | Where-Object {
    $_.Extension -in ".txt", ".docx"
} | Sort-Object Name | ForEach-Object {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    if ($_.Extension -eq ".docx" -and $txtByBase.ContainsKey($base)) {
        return
    }
    $textFiles.Add($_)
}

foreach ($file in $textFiles) {
    $meta = Get-MetaFromName $file.Name
    $text = if ($file.Extension -eq ".docx") {
        Get-DocxText $file.FullName
    }
    else {
        Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    }

    $paragraphs = Split-SermonParagraphs $text
    $bookId = $meta.Id
    $books.Add([ordered]@{
        id = $bookId
        title = $meta.Title
        idCode = $meta.Code
        location = "JHB, Harare"
        duration = "TIME: 0:00"
        category = "sermon"
        language = "en"
    })

    foreach ($paragraph in $paragraphs) {
        $entries.Add([ordered]@{
            bookId = "preloaded:$bookId"
            code = $meta.Code
            title = $meta.Title
            paragraph = [string]$paragraph.Number
            sortOrder = [int]$paragraph.Number
            text = $paragraph.Text
        })
    }
}

Get-ChildItem -LiteralPath $resolvedSource -Filter "*.pdf" -File | Sort-Object Name | ForEach-Object {
    $meta = Get-MetaFromName $_.Name
    $safeName = $_.Name -replace '[<>:"/\\|?*]', '_'
    $target = Join-Path $pdfDir $safeName
    Copy-Item -LiteralPath $_.FullName -Destination $target -Force
    $assetPath = "assets/preload/pdfs/$safeName"
    $bookId = $meta.Id

    $books.Add([ordered]@{
        id = $bookId
        title = $meta.Title
        asset = $assetPath
        idCode = $meta.Code
        location = "JHB, Harare"
        duration = "TIME: 0:00"
        category = "sermon"
        language = "en"
    })

    $entries.Add([ordered]@{
        bookId = "preloaded:$bookId"
        code = $meta.Code
        title = $meta.Title
        paragraph = "1"
        sortOrder = 1
        text = $meta.Title
    })
}

$booksDoc = [ordered]@{
    version = 6
    books = $books
}
$searchDoc = [ordered]@{
    version = 6
    entries = $entries
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText(
    (Join-Path $resolvedPreload "books.json"),
    ($booksDoc | ConvertTo-Json -Depth 8),
    $utf8NoBom
)
[System.IO.File]::WriteAllText(
    (Join-Path $resolvedPreload "search_index.json"),
    ($searchDoc | ConvertTo-Json -Depth 8),
    $utf8NoBom
)

Write-Host "Converted $($books.Count) sermons and $($entries.Count) searchable paragraphs."
