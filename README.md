# Bulk File Renamer

I created this small, focused desktop utility for renaming many files at once, built with **Free Pascal** and **Lazarus (LCL)**, to help me to deal with my hundreds astrophothos files. Just needed something to point at a folder, configure a pipeline of transformations, preview the result, then commit.

No installation, no telemetry, no cloud — just a single executable that does one thing well and runs on Windows, Mac OS and Linux.

## Features

- Pick a folder (optionally recursive) and filter by file mask (`*.jpg`, `IMG_*`, etc.)
- Optional "files only" mode to skip directories
- Live **preview** column with status flags: `will rename`, `unchanged`, `DUPLICATE`, `EMPTY!`
- Transformation pipeline applied in a predictable order:
  1. Trim N characters from the start
  2. Trim N characters from the end
  3. Trim up to a start delimiter (first or last occurrence)
  4. Trim from an end delimiter onwards (first or last occurrence)
  5. Find & replace (with optional case sensitivity)
  6. Remove or replace text **between two delimiters** (e.g. strip `[brackets]`, `<tags>`, `(notes)`)
  7. Add prefix and/or suffix
  8. Insert a zero-padded sequence number, as prefix or suffix, with custom separator
- Option to include the **extension** in every transformation (otherwise it is preserved)
- Safe by default: confirms before renaming, skips duplicates, skips targets that already exist on disk, never overwrites
- UTF-8-aware renaming via `RenameFileUTF8` — works with non-ASCII paths and filenames

## Screenshots

```
docs/screenshot-main.png
```

## Usage

1. **Pick a folder** with the `Browse...` button (or type/paste a path).
2. Set a **file mask** if you only want certain files (e.g. `*.png`). Leave as `*` for everything.
3. Tick **Recursive** to include subfolders, and **Only files** to ignore directories.
4. Configure any of the transformation groups you need:
   - **Trim** — by character count or by delimiter, at the start and/or end.
   - **Between delimiters** — strip or replace whatever sits inside, for example `<...>` or `[draft]`.
   - **Find & Replace** — plain string match with optional case sensitivity.
   - **Prefix / Suffix** — added after all trimming and replacement.
   - **Numbering** — start value, zero-padding width, separator, and prefix/suffix position.
5. Click **Preview** and inspect the `New name` and `Status` columns.
6. When the preview looks right, click **Rename**.

### Status values explained

| Status              | Meaning                                                                |
| ------------------- | ---------------------------------------------------------------------- |
| `will rename`       | Target name is valid and unique; this row will be renamed.             |
| `unchanged`         | The new name is identical to the original; this row is skipped.        |
| `DUPLICATE`         | Two or more rows would produce the same target; duplicates are skipped.|
| `EMPTY!`            | Transformations stripped the name to nothing; this row is skipped.     |
| `renamed`           | Rename completed successfully (shown after committing).                |
| `skipped`           | Row was skipped (no change needed or empty target).                    |
| `skipped (dup)`     | Row was skipped because of a duplicate target.                         |
| `exists - skipped`  | A file or folder with that name already exists on disk; left untouched.|
| `FAILED`            | The OS refused the rename (permissions, lock, invalid characters, …). |


## Safety notes

- Renaming is irreversible from inside the tool — **there is no undo**. Always check the preview.
- Rows whose target already exists on disk are skipped, but consider running on a copy of important folders the first time you try a complex pipeline.
- Duplicate detection only checks within the current batch. If two transformations would produce names that collide with files **outside** the current selection, the OS-level check (`FileExists` / `DirectoryExists`) is what protects you.

## Roadmap / ideas

- Undo last batch
- Regex find & replace
- Case transforms (UPPER / lower / Title)
- Save and load named presets
- Drag-and-drop folder onto the window
- Localization

## License

This project is released under the MIT License.
