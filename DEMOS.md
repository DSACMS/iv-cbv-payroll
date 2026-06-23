# Document-upload → PDF transmission: conversion POCs

Throwaway proof-of-concept scripts for FFS-4411. They demonstrate the three candidate
stacks for converting uploaded documents (incl. iPhone HEIC) into a single, stamped PDF
ready to transmit to a state: merge an uploaded image + PDF into the income report and
stamp a case number + "page X of Y" on every page.

> Not meant to merge. They live at the repo root, self-install their own system libs,
> and install their gems via `bundler/inline` (nothing touches the app's Gemfile).

## Prerequisites

- Ruby (tested on 3.4).
- A package manager the bootstrap can use: **Homebrew** (macOS) or **apt** (Debian/Ubuntu).
  `demo_setup.rb` auto-installs the native libs each demo needs; on first run a demo will
  `brew install` / `apt-get install` what's missing (vips / imagemagick). No manual setup.

## The demos

| Script | Stack | Pipeline |
|---|---|---|
| `combine_pdf_demo.rb` | **Recommended:** ruby-vips + prawn + combine_pdf | HEIC →vips→ PNG →prawn→ PDF page →combine_pdf→ merge + stamp |
| `prawn_demo.rb` | **Alt:** ruby-vips + prawn + prawn-templates | HEIC →vips→ PNG →prawn (template merge + embed + stamp) |
| `rmagick_demo.rb` | **Alt:** RMagick + combine_pdf | HEIC →rmagick→ PDF page (one step) →combine_pdf→ merge + stamp |

`demo_setup.rb` is the shared bootstrap (auto-installs system libs); it is not run directly.

## Run

```sh
ruby combine_pdf_demo.rb     # recommended stack
ruby prawn_demo.rb           # prawn-templates alternative
ruby rmagick_demo.rb         # RMagick alternative
```

Each writes a combined PDF to its own output dir:

```sh
open combine_pdf_demo_out/combined_output.pdf
open prawn_demo_out/combined_output.pdf
open rmagick_demo_out/combined_output.pdf
```

Open any output to see the merged report + uploaded letter + converted HEIC photo,
each page stamped `Case … - Conf … - page X of Y`.

## What to compare

- **Output size** printed at the end — RMagick is much larger because it rasterizes the
  PDF pages it round-trips (the reason combine_pdf still does the merge in that stack).
- **License:** combine_pdf = MIT; prawn / prawn-templates = Ruby/GPL; RMagick = ImageMagick
  (Apache-2.0). All compatible with this repo's CC0. (hexapdf would be simpler but is
  AGPL — deliberately avoided.)
- **System dep:** vips (lighter, streams) vs ImageMagick (heavier, CVE surface).

## Notes

- libvips can't *write* PDF — vips only transcodes HEIC/TIFF/etc. → png/jpg; prawn (or
  RMagick) does the image → PDF step.
- prawn / RMagick embed/handle png/jpg; HEIC must be transcoded first (what vips does).
- Gems are installed on first run via `bundler/inline`, so the first invocation is slower.
