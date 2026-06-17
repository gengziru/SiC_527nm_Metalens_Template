# 527 nm SiC Metalens Design Template

This repository contains a compact MATLAB and Ansys Lumerical FDTD workflow for a single-wavelength SiC metalens design at 527 nm. It covers unit-cell phase-library export, target phase mapping, automated FDTD model generation, far-field post-processing, and GDS layout export.

The project is intended as a public, portfolio-friendly template. It contains only generic scripts, small demonstration phase-library data, and documentation for the workflow.

## Workflow

1. Build or export a unit-cell phase library in Lumerical FDTD.
2. Map a target metalens phase profile to the nearest available nanopillar radius.
3. Generate an embedded Lumerical `.lsf` builder script for the full metalens.
4. Run far-field and focal-spot post-processing scripts.
5. Export a 2D inverse-tone GDS layout from the generated radius map.

## Repository Structure

```text
.
├── Unit/
│   ├── unit_sweep_template.lsf
│   ├── plot_unit_phase_library_template.m
│   ├── phix_527.mat
│   ├── Tx_527.mat
│   └── README_Unit模板说明.md
├── Metalens/
│   ├── generate_target_radius_template.m
│   ├── farfield_template.lsf
│   ├── focus_metrics_template.lsf
│   ├── focus_efficiency_template.lsf
│   └── README_Metalens模板说明.md
├── GDS/
│   ├── generate_gds_from_target_radius_template.m
│   └── README_GDS模板说明.md
├── docs/
│   └── 操作说明书.md
├── PUBLIC_RELEASE_CHECKLIST.md
└── .gitignore
```

## Example Design Parameters

| Parameter | Value |
| --- | --- |
| Wavelength | 527 nm |
| Material model | SiC, approximate refractive index `n = 2.67` |
| Unit-cell period | 224 nm |
| Pillar height | 600 nm |
| Radius sweep range | 44-92 nm |
| Supported phase models | Hyperbolic and quadratic |

## Quick Start

In MATLAB, enter the `Metalens` folder and run:

```matlab
generate_target_radius_template
```

This creates a target radius map and an embedded Lumerical builder script:

```text
target_radius_<project_tag>.mat
target_radius_<project_tag>_fdtd.mat
target_radius_<project_tag>.csv
structure_lens_<project_tag>.lsf
```

Then open Lumerical FDTD, run the generated `structure_lens_<project_tag>.lsf`, and run the post-processing scripts in `Metalens/` after the simulation finishes.

To export a GDS layout, enter the `GDS` folder, edit `cfg.project_tag` in `generate_gds_from_target_radius_template.m`, and run the script after the radius-map `.mat` file has been generated.

## Notes

- The included `.mat` files are small demonstration phase-library files for the template.
- Generated simulation files, large `.mat` outputs, `.fsp` projects, figures, and GDS files are ignored by default.
- The default GDS output is inverse tone: square exposure cells with protected circular nanopillar footprints.
- Before using this repository for fabrication, confirm the required tone, layer/datatype, minimum feature size, and layout rules with the fabrication platform.

## Requirements

- MATLAB
- Ansys Lumerical FDTD
- KLayout or another GDS viewer, optional

## Documentation

Chinese workflow documentation is available in [`docs/操作说明书.md`](docs/操作说明书.md).

## Public Release Notice

This folder was prepared as a clean public project template. Before uploading to GitHub, review [`PUBLIC_RELEASE_CHECKLIST.md`](PUBLIC_RELEASE_CHECKLIST.md) and confirm that no confidential, proprietary, or third-party restricted material has been added.
